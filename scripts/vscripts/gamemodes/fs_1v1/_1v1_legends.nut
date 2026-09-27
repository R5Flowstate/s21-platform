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
global function FS_1v1_AbilitiesAllowed
global function FS_1v1_ChallengeLegendsActive
global function FS_1v1_QueueChallengePick
global function FS_1v1_RunChallengePick
global function FS_1v1_RetireChallengeLegends

const float CHAL_PICK_INTRO = 1.0
const float CHAL_PICK_OUTRO = 1.0

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
	ItemFlavor character = FS_1v1_ResolveCharacter( player, -1 )

	// Only when it actually caught a stomp -- this runs on every respawn.
	if ( LoadoutSlot_IsReady( playerEHI, Loadout_Character() )
		&& LoadoutSlot_GetItemFlavor( playerEHI, Loadout_Character() ) != character )
	{
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
	// A challenge pick outranks the playlist force, but only inside that challenge.
	ItemFlavor ornull challengePick = FS_1v1_ChallengeLegend( player )
	if ( challengePick != null )
		return expect ItemFlavor( challengePick )

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
	bool giveUltimate = FS_1v1_ChallengeLegendsActive( player ) || LEGEND_GUID_ENABLED_ULTIMATES.contains( charID )

	if( giveUltimate )
	{
		ItemFlavor ultimateAbility = CharacterClass_GetUltimateAbility( character )
		player.GiveOffhandWeapon( CharacterAbility_GetWeaponClassname( ultimateAbility ), OFFHAND_ULTIMATE, [] )
	}

	entity wep = player.GetOffhandWeapon( OFFHAND_INVENTORY )

	if( !noUltimate && IsValid( wep ) )
		wep.SetWeaponPrimaryClipCount( wep.GetWeaponPrimaryClipCountMax() )

	ReloadTactical( player )
	player.Server_TurnOffhandWeaponsDisabledOff()

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

	foreach ( int i, entity player in [ group.player1, group.player2 ] )
	{
		if ( !FS_1v1_AbilitiesAllowed( player ) )
		{
			FS_1v1_StripAbilities( player )
			continue
		}

		RechargePlayerAbilities( player, i == 0 ? group.p1LegendIndex : group.p2LegendIndex )
		if ( FS_1v1_ChallengeLegendsActive( player ) )
			group.challengeLegendsGranted = true
	}
}

//////////////////////////////////////////////////////////////////////////////
// Challenge legends: an accepted challenge picks legends through the per-player
// character select and plays them with tactical and ultimate. Normal duels keep
// the playlist legend and no abilities.

bool function FS_1v1_ChallengeLegendsActive( entity player )
{
	if ( !settings.bChallengeLegends || !IsValid( player ) )
		return false

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	return Gamemode1v1_IsMatchValid( group ) && group.IsKeep
}

bool function FS_1v1_AbilitiesAllowed( entity player )
{
	return settings.bAllowAbilities || FS_1v1_ChallengeLegendsActive( player )
}

bool function FS_1v1_IsChallengePickable( ItemFlavor character )
{
	if ( ItemFlavor_GetType( character ) != eItemType.character || ItemFlavor_GetAsset( character ) == CHARACTER_RANDOM )
		return false
	return !CharacterClass_IsBlockedForCurrentPlaylist( character )
}

ItemFlavor ornull function FS_1v1_ChallengeLegend( entity player )
{
	if ( !FS_1v1_ChallengeLegendsActive( player ) )
		return null

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	int guid = player == group.player1 ? group.p1ChallengeLegend : group.p2ChallengeLegend
	if ( guid == 0 || !IsValidItemFlavorGUID( guid ) )
		return null

	ItemFlavor character = GetItemFlavorByGUID( guid )
	if ( !FS_1v1_IsChallengePickable( character ) )
		return null

	return character
}

// Returns a localization token describing why the pick was refused, or "" when queued.
string function FS_1v1_QueueChallengePick( entity player, bool onlyIfUnpicked = false )
{
	if ( !settings.bChallengeLegends )
		return "#FS_DisabledLegends"
	if ( !FS_1v1_ChallengeLegendsActive( player ) )
		return "#FS_NotInChal"

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	if ( player == group.player1 )
	{
		if ( !onlyIfUnpicked || group.p1ChallengeLegend == 0 )
			group.p1PickPending = true
	}
	else if ( player == group.player2 )
	{
		if ( !onlyIfUnpicked || group.p2ChallengeLegend == 0 )
			group.p2PickPending = true
	}

	return ""
}

// Runs between a challenge round's respawn and its weapons. Both fighters are held
// still while either one picks, so a quick lock cannot shoot a player still in the menu.
void function FS_1v1_RunChallengePick( MatchGroup group )
{
	if ( !settings.bChallengeLegends || !Gamemode1v1_IsMatchValid( group ) || !group.IsKeep )
		return

	array<entity> pickers
	if ( group.p1PickPending )
		pickers.append( group.player1 )
	if ( group.p2PickPending )
		pickers.append( group.player2 )
	group.p1PickPending = false
	group.p2PickPending = false

	if ( pickers.len() == 0 )
		return

	array<entity> fighters = [ group.player1, group.player2 ]

	OnThreadEnd(
		function() : ( fighters, pickers )
		{
			foreach ( entity player in pickers )
				FS_1v1_CloseChallengePick( player )

			foreach ( entity player in fighters )
			{
				if ( !IsValid( player ) )
					continue
				player.MovementEnable()
				player.UnforceStand()
			}
		}
	)

	foreach ( entity player in fighters )
	{
		player.MovementDisable()
		player.ForceStand()
		player.Server_TurnOffhandWeaponsDisabledOn()
	}

	float pickTime = settings.challengeLegendPickTime
	float pickStart = Time() + CHAL_PICK_INTRO
	float pickEnd = pickStart + pickTime + CHAL_PICK_OUTRO

	foreach ( entity player in pickers )
	{
		player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_LOCK_STEP_PLAYER_INDEX, 0 )
		player.SetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER, false )
		player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_FOCUS_CHARACTER_GUID, -1 )
		player.SetPlayerNetInt( "characterSelectFocusSkinGUID", -1 )
		player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), -1 )
		player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( "pickLoadoutGamestateStartTime" ), pickStart )
		player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( "pickLoadoutGamestateEndTime" ), pickEnd )
		player.SetPlayerNetBool( CharSelect_PlayerStateNetVar( "characterSelectionReady" ), true )
	}


	wait CHAL_PICK_INTRO

	float stepStart = Time()
	float stepEnd = stepStart + pickTime
	foreach ( entity player in pickers )
	{
		if ( !IsValid( player ) )
			continue
		player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_START_TIME ), stepStart )
		player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_END_TIME ), stepEnd )
		player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), 0 )
	}

	while ( Time() < stepEnd )
	{
		if ( !Gamemode1v1_IsMatchValid( group ) || !group.IsKeep )
			return

		bool allLocked = true
		foreach ( entity player in pickers )
		{
			if ( IsValid( player ) && !player.GetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER ) )
				allLocked = false
		}
		if ( allLocked )
			break

		WaitFrame()
	}

	foreach ( entity player in pickers )
		FS_1v1_FinalizeChallengePick( group, player )

	foreach ( entity player in pickers )
	{
		if ( IsValid( player ) )
			player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), 1 )
	}

	wait CHAL_PICK_OUTRO
}

// A player who does not lock keeps the legend they last played in this challenge.
void function FS_1v1_FinalizeChallengePick( MatchGroup group, entity player )
{
	if ( !IsValid( player ) || !player.GetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER ) )
		return

	EHI ehi = ToEHI( player )
	if ( !LoadoutSlot_IsReady( ehi, Loadout_Character() ) )
		return

	ItemFlavor character = LoadoutSlot_GetItemFlavor( ehi, Loadout_Character() )
	if ( !FS_1v1_IsChallengePickable( character ) )
		return

	int guid = ItemFlavor_GetGUID( character )
	if ( player == group.player1 )
		group.p1ChallengeLegend = guid
	else if ( player == group.player2 )
		group.p2ChallengeLegend = guid

}

void function FS_1v1_CloseChallengePick( entity player )
{
	if ( !IsValid( player ) )
		return

	player.SetPlayerNetBool( CharSelect_PlayerStateNetVar( "characterSelectionReady" ), false )
	player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), -1 )
	player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_LOCK_STEP_PLAYER_INDEX, -1 )
	player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_FOCUS_CHARACTER_GUID, -1 )
	player.SetPlayerNetInt( "characterSelectFocusSkinGUID", -1 )
	player.SetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER, true )
}

// Called with the group already invalid, so every resolve below lands on the playlist
// legend. Clears what the challenge legends left in the fight realm.
void function FS_1v1_RetireChallengeLegends( MatchGroup group )
{
	if ( !group.challengeLegendsGranted )
		return

	group.challengeLegendsGranted = false

	foreach ( entity player in [ group.player1, group.player2 ] )
	{
		if ( !IsValid( player ) )
			continue

		FS_1v1_CloseChallengePick( player )
		_CleanupPlayerEntities( player )
		FS_1v1_StripAbilities( player )
		FS_1v1_ApplyCharacter( player )
	}

	FS_Scenarios_SweepRealm( group.slotIndex, "1v1-challenge-retire" )
}
