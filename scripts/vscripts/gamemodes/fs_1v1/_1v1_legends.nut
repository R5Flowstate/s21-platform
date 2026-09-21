// Flowstate 1v1. CafeFPS (makimakima, mkos).

global function RechargePlayerAbilities
global function FS_1v1_StripAbilities
global function Gamemode1v1_IsRestEnabled
global function Gamemode1v1_SetRestEnabled
global function ReloadTactical
global function AssignLegendToGroup
global function CharacterGuidRefToIndex
global function TakeUltimate
global function _decideLegend
global function FS_1v1_GetCharacterByIndex
global function FS_1v1_ApplyCharacter
global function FS_1v1_ApplyForcedCharacter
global function FS_1v1_ApplyPlayerCamo
global function FS_1v1_ForcedCharacterIndex
global function FS_1v1_GetForcedCharacter
global function FS_1v1_ResolveCharacter
global function FS_1v1_CharacterResetOverride
global function FS_1v1_OnCharacterSlotChanged
global function FS_1v1_DumpLegendTable

// The ref -> setfile table this build actually resolves. Setfiles carry ability
// codenames, not legend names -- character_wraith is pilot_survival_closer,
// character_gibraltar is pilot_survival_gunner -- so read the pairing, not the name.
void function FS_1v1_DumpLegendTable()
{
	foreach ( int i, string ref in LEGEND_CHARACTER_REFS )
	{
		if ( !IsValidItemFlavorCharacterRef( ref ) )
		{
			printt( format( "[CHARSETUP] table %d %s -> NOT A VALID REF", i, ref ) )
			continue
		}

		ItemFlavor flavor = GetItemFlavorByCharacterRef( ref )
		printt( format( "[CHARSETUP] table %d %s -> asset=%s setfile=%s", i, ref,
			string( ItemFlavor_GetAsset( flavor ) ), string( CharacterClass_GetSetFile( flavor ) ) ) )
	}
}

// Names every writer of the character slot. The champion screen renders this
// networked value while the player wears whatever setfile was applied last, so when
// the two disagree this is the half that moved.
void function FS_1v1_OnCharacterSlotChanged( EHI playerEHI, ItemFlavor flavor )
{
	entity player = FromEHI( playerEHI )
	printt( format( "[CHARSETUP] slot changed for %s -> '%s'",
		IsValid( player ) ? player.GetPlayerName() : "<invalid>",
		ItemFlavor_GetHumanReadableRef( flavor ) ) )
}

// Loadout slot validation resets the character slot to a random legend whenever it
// judges the stored one invalid or locked -- which it always does here, because GRX
// never reports an entitlement on this server. That reset lands after the force.
ItemFlavor function FS_1v1_CharacterResetOverride( EHI playerEHI )
{
	entity player = FromEHI( playerEHI )
	ItemFlavor character = FS_1v1_GetForcedCharacter( player )

	// Only when it actually caught a stomp -- this runs on every respawn.
	if ( LoadoutSlot_IsReady( playerEHI, Loadout_Character() )
		&& LoadoutSlot_GetItemFlavor( playerEHI, Loadout_Character() ) != character )
	{
		printt( format( "[FS-1V1][LEGEND] held %s at '%s' against a reset",
			IsValid( player ) ? player.GetPlayerName() : "<invalid>",
			ItemFlavor_GetHumanReadableRef( character ) ) )
	}

	return character
}

int function FS_1v1_ForcedCharacterIndex( entity player )
{
	int chosen = FlowState_ChosenCharacter()
	if ( chosen < 0 || chosen >= LEGEND_CHARACTER_REFS.len() )
		chosen = FS_1V1_DEFAULT_LEGEND_INDEX

	if ( IsValid( player ) && FlowState_ForceAdminCharacter() && IsAdmin( player ) )
	{
		int adminChosen = FlowState_ChosenAdminCharacter()
		if ( adminChosen >= 0 && adminChosen < LEGEND_CHARACTER_REFS.len() )
			chosen = adminChosen
	}

	return chosen
}

ItemFlavor function FS_1v1_GetForcedCharacter( entity player )
{
	if ( IsValid( player ) && FlowState_ForceAdminCharacter() && IsAdmin( player ) )
		return FS_1v1_GetCharacterByIndex( FS_1v1_ForcedCharacterIndex( player ) )
	return FS_1v1_GetForcedCharacterFlavor()
}

// Never blocks. LoadoutSlot_WaitForItemFlavor parks until the slot publishes, and
// on a forced-legend playlist the slot the caller is waiting for is the one the
// force is about to overwrite -- so the wait is what stalls match start.
ItemFlavor function FS_1v1_ResolveCharacter( entity player, int index )
{
	if ( FS_1v1_IsForceCharacter() )
		return FS_1v1_GetForcedCharacter( player )

	if ( ValidLegendRange( index ) )
		return FS_1v1_GetCharacterByIndex( index )

	if ( IsValid( player ) )
	{
		EHI ehi = ToEHI( player )
		LoadoutEntry slot = Loadout_Character()
		if ( LoadoutSlot_IsReady( ehi, slot ) )
		{
			ItemFlavor current = LoadoutSlot_GetItemFlavor( ehi, slot )
			if ( ItemFlavor_GetType( current ) == eItemType.character )
				return current
		}
	}

	return FS_1v1_GetCharacterByIndex( FS_1V1_DEFAULT_LEGEND_INDEX )
}

ItemFlavor function FS_1v1_GetCharacterByIndex( int index )
{
	return FS_1v1_GetCharacterFlavorByIndex( index )
}

// The only writer of a player's legend. The playlist force outranks every caller's
// index, and the loadout slot the UI reads and the setfile the world renders are
// written together -- writing one without the other is what makes the two disagree.
void function FS_1v1_ApplyCharacter( entity player, int index = -1 )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	EHI ehi = ToEHI( player )
	LoadoutEntry slot = Loadout_Character()
	ItemFlavor character = FS_1v1_ResolveCharacter( player, index )

	bool changed = !LoadoutSlot_IsReady( ehi, slot ) || LoadoutSlot_GetItemFlavor( ehi, slot ) != character

	SetItemFlavorLoadoutSlot( ehi, slot, character )
	player.SetPlayerNetBool( "hasLockedInCharacter", true )

	// Connect writes the slot while dead; a later spawn must still apply the setfile.
	if ( IsAlive( player ) && ( changed || FS_1v1_IsForceCharacter() ) )
		Survival_PlayerCharacterSetup( player, character, false )

	FS_1v1_ApplyPlayerCamo( player )
}

void function FS_1v1_ApplyForcedCharacter( entity player )
{
	FS_1v1_ApplyCharacter( player, FS_1v1_ForcedCharacterIndex( player ) )
}

// Camo 0 wears the legend's own skin family; 1..8 pick a camo and 9 randomises.
// Skin family 2 only exists on the custom pilot models, so forcing it on a legend
// that never opted into a camo is what leaves the body untextured.
void function FS_1v1_ApplyPlayerCamo( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	int camo = player.p.playerCamo

	if ( camo <= 0 || camo > FS_1V1_CAMO_RANDOM )
	{
		player.SetSkin( 0 )
		player.SetCamo( 0 )
		return
	}

	player.SetSkin( 2 )
	player.SetCamo( camo == FS_1V1_CAMO_RANDOM ? RandomIntRangeInclusive( 0, 15 ) : camo )
}

void function AssignLegendToGroup( int index, array<entity> players )
{
	foreach( player in players )
	{
		if( !IsValid( player ) )
			continue

		// A custom pilot model is only reachable when the playlist is not dictating a
		// legend; otherwise the model would outrank the force.
		if( index > FS_1V1_LAST_LEGEND_INDEX && !FS_1v1_IsForceCharacter() )
		{
			SetPlayerCustomModel( player, index )
			continue
		}

		FS_1v1_ApplyCharacter( player, index )
		FS_1v1_StripAbilities( player )
		TakeUltimate( player )
	}
}

int function CharacterGuidRefToIndex( string numRef )
{
	if( numRef in characterRefMap )
		return characterRefMap[ numRef ]

	return -1
}

bool function Gamemode1v1_IsRestEnabled()
{
	return file.bRestEnabled
}

void function Gamemode1v1_SetRestEnabled( bool value = true )
{
	file.bRestEnabled = value
}

void function RechargePlayerAbilities( entity player, int index = -1, bool noUltimate = false )
{
	if( !IsValid( player ) )
		return

	//printt( "player:", player, "index:", index )
	//mAssert( index > -1 , "RechargePlayerAbilities() was changed to use character index instead of using waitforitemflavor. Comment this assert out if you dont want to change method in scenarios." )

	ItemFlavor character

	character = FS_1v1_ResolveCharacter( player, index )

	//sqprint( format("LEGEND: %s, GUID: %d", ItemFlavor_GetHumanReadableRef( character ), ItemFlavor_GetGUID( character ) ))
	ItemFlavor tacticalAbility = CharacterClass_GetTacticalAbility( character )
	player.GiveOffhandWeapon(CharacterAbility_GetWeaponClassname( tacticalAbility ), OFFHAND_TACTICAL )

	int charID = ItemFlavor_GetGUID( character )

	if( GetCurrentPlaylistName() == "fs_scenarios" )
	{
		array<ItemFlavor> passives = CharacterClass_GetPassiveAbilities( character )
		if ( passives.len() > 0 )
			GivePassive( player, CharacterAbility_GetPassiveIndex( passives[ 0 ] ) )
	}

	//wait 0.5

	if( settings.isScenariosMode || LEGEND_GUID_ENABLED_ULTIMATES.contains( charID ) )
	{
		ItemFlavor ultimateAbility = CharacterClass_GetUltimateAbility( character )
		player.GiveOffhandWeapon( CharacterAbility_GetWeaponClassname( ultimateAbility ), OFFHAND_ULTIMATE, [] )
	}

	entity wep = player.GetOffhandWeapon( OFFHAND_INVENTORY )

	if( !noUltimate && IsValid( wep ) )
		wep.SetWeaponPrimaryClipCount( wep.GetWeaponPrimaryClipCountMax() )

	ReloadTactical( player )
	player.Server_TurnOffhandWeaponsDisabledOff()

	printt( "[FS-1V1] abilities " + player.GetPlayerName()
		+ " guid=" + string( charID )
		+ " tacticalRef=" + CharacterAbility_GetWeaponClassname( tacticalAbility )
		+ " tacticalGiven=" + string( IsValid( player.GetOffhandWeapon( OFFHAND_TACTICAL ) ) )
		+ " ultWhitelisted=" + string( LEGEND_GUID_ENABLED_ULTIMATES.contains( charID ) )
		+ " ultGiven=" + string( IsValid( player.GetOffhandWeapon( OFFHAND_ULTIMATE ) ) ) )
}

// Legend abilities off. The offhand-disabled flag is still cleared, or the
// round-transition Server_TurnOffhandWeaponsDisabledOn would also take melee
// and consumables with it.
void function FS_1v1_StripAbilities( entity player )
{
	if ( !IsValid( player ) )
		return

	player.TakeOffhandWeapon( OFFHAND_TACTICAL )
	player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
	TakeAllPassives( player )
	player.Server_TurnOffhandWeaponsDisabledOff()
}

void function ReloadTactical( entity player )
{
	entity weapon = player.GetOffhandWeapon( OFFHAND_LEFT )

	if ( IsValid( weapon ) )
	{
		int max = weapon.GetWeaponPrimaryClipCountMax()
		weapon.SetNextAttackAllowedTime( Time() - 1 )

		if ( weapon.IsChargeWeapon() )
			weapon.SetWeaponChargeFractionForced( 0 )
		else if ( max > 0 )
			weapon.SetWeaponPrimaryClipCount( max )
	}

	player.SetSuitGrapplePower( 100 )
}

void function TakeUltimate( entity player )
{
	if( IsValid( player.GetOffhandWeapon( OFFHAND_ULTIMATE ) ) )
		player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
}

bool function ValidLegendRange( int i )
{
	if ( i < 0 || i >= LEGEND_CHARACTER_REFS.len() )
		return false

	return IsValidItemFlavorCharacterRef( LEGEND_CHARACTER_REFS[ i ] )
}

void function _decideLegend( MatchGroup group )
{
	if ( !Gamemode1v1_IsMatchValid( group ) )
		return

	// A group carries index -1 until someone picks, and on a forced playlist that is
	// the whole match -- AssignLegendToGroup resolves both cases and the force wins
	// inside it, so a pick can never outrank the playlist.
	AssignLegendToGroup( group.p1LegendIndex, [ group.player1 ] )
	AssignLegendToGroup( group.p2LegendIndex, [ group.player2 ] )

	if( !settings.bAllowAbilities )
	{
		FS_1v1_StripAbilities( group.player1 )
		FS_1v1_StripAbilities( group.player2 )
	}
	else
	{
		RechargePlayerAbilities( group.player1, group.p1LegendIndex )
		RechargePlayerAbilities( group.player2, group.p2LegendIndex )
	}
}
