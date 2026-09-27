// Flowstate 1v1. CafeFPS (makimakima, mkos).

global function Gamemode1v1_AreCustomWeaponsAllowedForPlayer
global function Gamemode1v1_GiveWeapon
global function Gamemode1v1_TakeAll
global function Gamemode1v1_SetWeaponAmmoStackAmount
global function FS_1v1_GiveScenarioLoadout
global function FS_1v1_GiveLockedWeapon
global function FS_1v1_LockedSetSuffixForChoice
global function ValidateBlacklistedWeapons
global function ClientCommand_GiveWeapon_1v1
global function ClientCommand_SaveCurrentWeapons_1v1
global function ClientCommand_ResetSavedWeapons_1v1
global function ValidateWeaponTgiveSettings_1v1
global function LoadCustomWeapon_1v1
global function GiveWeaponsToGroup
global function SetHostInventoryAttachments

//===============================================================================
//
// WEAPON & LOADOUT MANAGEMENT
// Weapon giving and loadout management
//
//===============================================================================

void function EquipHostSetInventoryAttachments( entity player )
{
	foreach ( optic in settings.hostSetAttachments )
		SURVIVAL_AddToPlayerInventory( player, optic )
}

// Scenarios fight kit: consumables and melee always, the host's weapon pool only
// when the fight does not start empty-handed.
void function FS_1v1_GiveScenarioLoadout( entity player, bool giveWeapons )
{
	if( !IsValid( player ) )
		return

	TakeAllWeapons( player )
	Survival_SetInventoryEnabled( player, true )
	SetPlayerInventory( player, [] )

	if( giveWeapons )
	{
		EquipHostSetInventoryAttachments( player )
		GivePrimaryWeapon_1v1( player, ReturnRandomPrimaryMetagame_1v1(), WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		GivePrimaryWeapon_1v1( player, ReturnRandomSecondaryMetagame_1v1(), WEAPON_INVENTORY_SLOT_PRIMARY_1 )
	}

	player.TakeOffhandWeapon( OFFHAND_SLOT_FOR_CONSUMABLES )
	player.GiveOffhandWeapon( CONSUMABLE_WEAPON_NAME, OFFHAND_SLOT_FOR_CONSUMABLES, [] )

	if( FS_1v1_PlayerHasClient( player ) )
		Remote_CallFunction_ByRef( player, "Minimap_EnableDraw" )

	player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
	player.TakeOffhandWeapon( OFFHAND_MELEE )
	player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
	player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )
}

bool function Gamemode1v1_AreCustomWeaponsAllowedForPlayer( entity player )
{
	return !settings.customWeaponsChallengeOnly || Gamemode1v1_IsPlayerInChallenge( player )
}

void function Gamemode1v1_GiveWeapon( entity player, string weapon, int slot  ) //global exposed
{
	if ( !IsValid( player ) || FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( player ) ) )
		return
	GivePrimaryWeapon_1v1( player, weapon, slot )
}

void function Gamemode1v1_SetWeaponAmmoStackAmount( int amount )
{
	settings.give_weapon_stack_count_amount = amount
}

void function Gamemode1v1_TakeAll( entity player )
{
	if( !IsValid( player ) ) //(mk):this can fire after a player has quit, delayed.
		return

	// #if DEVELOPER
	// if( player == gp()[0] )
		// printw( "Gamemode1v1_TakeAll" )
	// #endif

	TakeUltimate( player )
	player.TakeOffhandWeapon( OFFHAND_MELEE )
	TakeAllPassives( player )
	TakeAllWeapons( player )
}

int function FS_1v1_LockStateFromToken( string token )
{
	switch ( token )
	{
		case "#FS_InputLocked":
			return 0
		case "#FS_AnyInput":
			return 1
	}
	return 2
}

string function FS_1v1_GetLockedSetChoice()
{
	return strip( GetCurrentPlaylistVarString( "fs_1v1_locked_set", "blue" ) ).tolower()
}

string function FS_1v1_LockedSetSuffixForChoice( string choice )
{
	switch ( choice )
	{
		case "white":
		case "whiteset":
			return WEAPON_LOCKEDSET_SUFFIX_WHITESET
		case "blue":
		case "blueset":
			return WEAPON_LOCKEDSET_SUFFIX_BLUESET
		case "purple":
		case "purpleset":
			return WEAPON_LOCKEDSET_SUFFIX_PURPLESET
		case "gold":
			return WEAPON_LOCKEDSET_SUFFIX_GOLD
	}
	return ""
}

string function FS_1v1_LockedSetModForChoice( string choice )
{
	switch ( choice )
	{
		case "white":
		case "whiteset":
			return WEAPON_LOCKEDSET_MOD_WHITESET
		case "blue":
		case "blueset":
			return WEAPON_LOCKEDSET_MOD_BLUESET
		case "purple":
		case "purpleset":
			return WEAPON_LOCKEDSET_MOD_PURPLESET
		case "gold":
			return WEAPON_LOCKEDSET_MOD_GOLD
	}
	return ""
}

void function FS_1v1_KeepRequestedSights( array<string> mods, array<string> requestedMods, string weaponclass )
{
	array<string> keepSights
	foreach ( string m in requestedMods )
	{
		if ( IsModTypeSight( m, weaponclass ) )
			keepSights.append( m )
	}
	if ( keepSights.len() == 0 )
		return

	for ( int i = mods.len() - 1; i >= 0; i-- )
	{
		if ( IsModTypeSight( mods[i], weaponclass ) )
			mods.remove( i )
	}
	foreach ( string s in keepSights )
		mods.append( s )
}

void function FS_1v1_StampLockedSet( entity weapon )
{
	if ( !IsValid( weapon ) )
		return

	string setMod = FS_1v1_LockedSetModForChoice( FS_1v1_GetLockedSetChoice() )
	if ( setMod == "" )
		return

	SetWeaponLockedSetFromLootTags( [ setMod ], weapon )
}

entity function FS_1v1_GiveLockedWeapon( entity player, string weaponclass, int slot, array<string> fallbackMods, string choiceOverride = "" )
{
	string classname = weaponclass
	array<string> mods
	foreach ( string m in fallbackMods )
		mods.append( m )

	string choice = choiceOverride != "" ? choiceOverride : FS_1v1_GetLockedSetChoice()
	string suffix = FS_1v1_LockedSetSuffixForChoice( choice )
	string setMod = FS_1v1_LockedSetModForChoice( choice )
	array<string> lootTags
	if ( setMod != "" )
		lootTags.append( setMod )
	bool usedKit = false

	if ( suffix != "" && SURVIVAL_Loot_IsRefValid( weaponclass ) )
	{
		LootData src = SURVIVAL_Loot_GetLootDataByRef( weaponclass )
		if ( src.lootType == eLootType.MAINWEAPON )
		{
			string base = GetBaseWeaponRef( weaponclass )
			string kitRef = base + suffix
			if ( SURVIVAL_Loot_IsRefValid( kitRef ) )
			{
				LootData ld = SURVIVAL_Loot_GetLootDataByRef( kitRef )
				if ( ld.baseWeapon != "" )
					classname = ld.baseWeapon
				else
					classname = base
				mods = []
				foreach ( string m in ld.baseMods )
				{
					if ( m != "" )
						mods.append( m )
				}
				FS_1v1_KeepRequestedSights( mods, fallbackMods, classname )
				if ( ld.lootTags.len() > 0 )
					lootTags = ld.lootTags
				usedKit = true
			}
		}
	}

	entity weaponNew = null
	try
	{
		weaponNew = player.GiveWeapon( classname, slot, mods, false )
	}
	catch ( giveErr )
	{
		printt( "[FS-1V1] locked-set give failed class=" + classname + " set=" + choice + " " + giveErr )
		weaponNew = null
	}

	if ( !IsValid( weaponNew ) && usedKit )
	{
		try
		{
			weaponNew = player.GiveWeapon( weaponclass, slot, fallbackMods, false )
		}
		catch ( giveErr2 )
		{
			weaponNew = null
		}
	}

	if ( IsValid( weaponNew ) && lootTags.len() > 0 )
		SetWeaponLockedSetFromLootTags( lootTags, weaponNew )

	return weaponNew
}

void function FS_1v1_ApplyInfiniteAmmo( entity player, entity weapon )
{
	if ( !IsValid( player ) || !IsValid( weapon ) )
		return

	if ( !player.p.infiniteGameModeAmmo )
		SetInfiniteAmmoForGameMode( player, true )

	SetInfiniteAmmoForWeapon( player, weapon, true )
}

void function GivePrimaryWeapon_1v1( entity player, string weapon, int slot ) //not global
{
	array<string> Data = split(weapon, " ")
	string weaponclass = Data[ 0 ]

	if( weaponclass == "tgive" )
		return

	array<string> Mods
	foreach( string mod in Data )
	{
		mod = strip( mod )
		if( mod != "" && mod != weaponclass )
		    Mods.append( mod )
	}

	entity weaponNew = FS_1v1_GiveLockedWeapon( player, weaponclass, slot, Mods )
	if( !IsValid( weaponNew ) )
	{
		printt( "[FS-1V1] GiveWeapon failed class=" + weaponclass + " player=" + player.GetPlayerName() )
		return
	}

	FS_1v1_ApplyInfiniteAmmo( player, weaponNew )

	player.ClearFirstDeployForAllWeapons()
	player.DeployWeapon()

	if( weaponNew.UsesClipsForAmmo() )
		weaponNew.SetWeaponPrimaryClipCount( weaponNew.GetWeaponPrimaryClipCountMax() )
}

void function GiveWeaponsToGroup( array<entity> players, MatchGroup groupRef )
{
	HandleOpponentInfo( groupRef )
	//printw( "giving weapons for players: ", players[0], players[1] )
	thread function () : ( players, groupRef )
	{
		foreach( player in players )
		{
			if( !IsValid( player ) )
				continue

			TakeAllWeapons( player )
			DecideToggleCollision_Rest( player, true )
		}

		// Wait for match found notification + respawn delay before giving weapons
		wait settings.matchFoundDelay + RESPAWN_DELAY_1V1

		// Guard: verify match wasn't interrupted during wait (round end, disconnect, etc.)
		foreach( player in players )
		{
			if( !IsValid( player ) )
				continue

			int state = Gamemode1v1_GetPlayerGamestate( player )
			if( state != e1v1State.SEQUENCE && state != e1v1State.IN_MATCH )
				return
		}

		if ( groupRef.p1PickPending || groupRef.p2PickPending )
		{
			waitthread FS_1v1_RunChallengePick( groupRef )

			foreach( player in players )
			{
				if( !IsValid( player ) )
					continue

				int state = Gamemode1v1_GetPlayerGamestate( player )
				if( state != e1v1State.SEQUENCE && state != e1v1State.IN_MATCH )
					return
			}
		}

		// Set MATCHING state after delay so minimap/HUD activate when match starts
		foreach( player in players )
		{
			if( !IsValid( player ) )
				continue

			Gamemode1v1_SetPlayerGamestate( player, e1v1State.IN_MATCH )
		}

		string primaryWeaponWithAttachments
		string secondaryWeaponWithAttachments
		string spawnClass = groupRef.groupLocStruct.info

		//(mk): add more classes if desired, configure spawns with spawn tool "info"
		switch( spawnClass )
		{
			case "longrange":

				if( !settings.bNoPrimaryLongrange )
					primaryWeaponWithAttachments = file.LongRangeWeapons.getrandom()

				if( !settings.bNoSecondaryLongrange )
					secondaryWeaponWithAttachments = file.LongRangeWeaponsSecondary.getrandom()
			break

			default:

				if( !settings.bNoPrimary )
					primaryWeaponWithAttachments = ReturnRandomPrimaryMetagame_1v1()

				if( !settings.bNoSecondary )
					secondaryWeaponWithAttachments = ReturnRandomSecondaryMetagame_1v1()
			break
		}

		int random_character_index = -1

		if ( FS_1v1_IsForceCharacter() )
		{
			// Per player, not per group: an admin can be forced to a different legend.
			foreach ( entity forcedPlayer in players )
			{
				if ( IsValid( forcedPlayer ) )
					AssignLegendToGroup( FS_1v1_ForcedCharacterIndex( forcedPlayer ), [ forcedPlayer ] )
			}
		}
		else if ( settings.bGiveSameRandomLegendToBothPlayers )
		{
			random_character_index = RandomIntRangeInclusive( 0, LEGEND_CHARACTER_REFS.len() - 1 )
		}

		ArrayRemoveInvalid( players ) //(mk): we waited above
		if( players.len() != 2 )
			return

		bool bInChallenge = false
		MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( players[0] )

		if( !Gamemode1v1_IsMatchValid( group ) )
			return

		if( group.IsKeep )
			bInChallenge = true

		foreach( player in players )
		{
			if ( !FS_1v1_IsForceCharacter() && settings.bGiveSameRandomLegendToBothPlayers && !bIsCoachingMode() )
				FS_1v1_ApplyCharacter( player, random_character_index )
			else
				FS_1v1_ApplyPlayerCamo( player )

			DeployAndEnableWeapons_Raw( player )

			//re-enable for inventory.
			Survival_SetInventoryEnabled( player, true )
			SetPlayerInventory( player, [] )
			EquipHostSetInventoryAttachments( player )
			Inventory_SetPlayerEquipment( player, "backpack_pickup_lv3", "backpack" )

			if ( ( settings.customWeaponsChallengeOnly && !bInChallenge ) || !( player.p.handle in weaponlist_1v1 ) )
			{
				TakeAllWeapons( player )

				if( !empty( primaryWeaponWithAttachments ) )
					GivePrimaryWeapon_1v1( player, primaryWeaponWithAttachments, WEAPON_INVENTORY_SLOT_PRIMARY_0 )

				if( !empty( secondaryWeaponWithAttachments ) )
					GivePrimaryWeapon_1v1( player, secondaryWeaponWithAttachments, WEAPON_INVENTORY_SLOT_PRIMARY_1 )
			}
			else
			{
				thread LoadCustomWeapon_1v1( player )
			}

			player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_2 )
			player.TakeOffhandWeapon( OFFHAND_MELEE )

			if ( !Flowstate_IsLGDuels() )
			{
				FS_GiveRandomMelee( player, true )
			}

			if( FS_1v1_AbilitiesAllowed( player ) )
				RechargePlayerAbilities( player )
			else
				FS_1v1_StripAbilities( player )
		}

		// Realm already locked at match create; re-assert after weapons for challenge rematches
		if( IsValid( group.player1 ) )
			FS_SetRealmForPlayer( group.player1, group.slotIndex )
		if( IsValid( group.player2 ) )
			FS_SetRealmForPlayer( group.player2, group.slotIndex )

		if( bInChallenge )
			_decideLegend( group )

		if ( IsValid( group.player1 ) && IsValid( group.player2 ) )
		{
			group.player1.SetPlayerNetEnt( "FSDM_1v1_Enemy", group.player2 )
			group.player2.SetPlayerNetEnt( "FSDM_1v1_Enemy", group.player1 )
			Gamemode1v1_StartVsHudSync( group )
		}

		// IBMM notifications and input watchdog - shown after match actually starts
		if ( !Gamemode1v1_IsMatchValid( group ) )
			return

		string ibmmLockTypeToken = ""

		if ( group.inputLocked && !group.inputWatchdogRunning )
		{
			group.inputWatchdogRunning = true
			thread InputWatchdog( group.player1, group.player2, group )
			ibmmLockTypeToken = "#FS_InputLocked"
		}
		else
		{
			ibmmLockTypeToken = "#FS_CouldNotLock"
		}

		if ( IsValid( group.player1 ) && IsValid( group.player2 ) )
		{
			string player1Token = ibmmLockTypeToken
			string player2Token = ibmmLockTypeToken

			if ( group.player1.p.IBMM_grace_period <= 0 )
				player1Token = "#FS_AnyInput"

			if ( group.player2.p.IBMM_grace_period <= 0 )
				player2Token = "#FS_AnyInput"

			group.player1.SetPlayerNetInt( "FS_1v1_LockState", FS_1v1_LockStateFromToken( player1Token ) )
			group.player2.SetPlayerNetInt( "FS_1v1_LockState", FS_1v1_LockStateFromToken( player2Token ) )

			printt( format( "[FS-1V1][IBMM] %s in=%d grace=%.1f tok=%s | %s in=%d grace=%.1f tok=%s | locked=%d",
				group.player1.GetPlayerName(), group.player1.p.input, group.player1.p.IBMM_grace_period, player1Token,
				group.player2.GetPlayerName(), group.player2.p.input, group.player2.p.IBMM_grace_period, player2Token,
				group.inputLocked ? 1 : 0 ) )

			if ( group.player1.p.enable_input_banner && !group.IsKeep )
				IBMM_Notify( group.player1, player1Token, group.player2.p.input )

			if ( group.player2.p.enable_input_banner && !group.IsKeep )
				IBMM_Notify( group.player2, player2Token, group.player1.p.input )
		}
	}()
}

string function ReturnRandomPrimaryMetagame_1v1()
{
	return file.Weapons.getrandom()
}

string function ReturnRandomSecondaryMetagame_1v1()
{
	return file.WeaponsSecondary.getrandom()
}

void function SetHostInventoryAttachments()
{
	array<string> attachments = []
	string attachmentList = GetCurrentPlaylistVarString( "customAttachments", "" )

	if( empty( attachmentList ) )
		return

	try
	{
		attachments = StringToArray( attachmentList )
	}
	catch( e )
	{
		sqerror( "[1v1:SetHostInventory] " + e )
	}

	int totalAttachments = attachments.len()

	#if DEVELOPER
		array<string> attachmentsClone = clone attachments
		attachmentsClone.insert( 0, "===CUSTOM INVENTORY LOADOUT===" )
		print_string_array( attachmentsClone )
	#endif

	if( totalAttachments == 0 )
		return

	for ( int i = totalAttachments - 1; i >= 0; i-- )
	{
		if( !IsValidAttachment( attachments[i] ) )
		{
			sqerror( "Attachment # " + i + " :\"" + attachments[i] + "\" was invalid and removed." )
			attachments.remove( i )
		}
	}

	settings.hostSetAttachments = attachments

	if( settings.bAllowWeaponsMenu && !isScenariosMode() )
		Loot_AddCallback_OnWeaponAttachmentChanged( OnWeaponAttachmentChanged )
}

void function ValidateBlacklistedWeapons( array<string> Weapons ) //(mk): modifies original by ref
{
	int maxIter = Weapons.len() - 1

	for( int i = maxIter; i >= 0; i-- )
	{
		int sliceIndex = Weapons[ i ].find( " " )
		if( sliceIndex > -1 )
		{
			string weaponName = Weapons[ i ].slice( 0, sliceIndex )

			if( GetBlackListedWeapons().contains( weaponName ) )
				Weapons.remove( i )
		}
		else
		{
			if( GetBlackListedWeapons().contains( Weapons[ i ] ) )
				Weapons.remove( i )
		}
	}
}


//===============================================================================
//
// WEAPON HELPER/UTILITY FUNCTIONS
// Weapon validation, tgive commands, and custom weapon loading
//
//===============================================================================

bool function _IsWeaponBlockedByRef_1v1( string weapon )
{
	// Crate variants are separate loot rows with an empty baseWeapon, so
	// GetBaseWeaponRef does not fold them and a raw compare misses them.
	string baseRef = weapon
	int crateAt = baseRef.find( "_crate" )
	if( crateAt > 0 )
		baseRef = baseRef.slice( 0, crateAt )

	switch( baseRef )
	{
		case "mp_weapon_raygun":
		case "mp_weapon_throwingknife":
		case "mp_weapon_pdw":
		case "mp_weapon_lstar":
			return true
	}

	return false
}

// Validate weapon tgive settings for 1v1 mode
bool function ValidateWeaponTgiveSettings_1v1( entity player, string weaponRef )
{
	int uiType = eMsgUI.WAVE

	// Check if player is in waiting state
	if( Gamemode1v1_IsPlayerWaiting( player ) )
	{
		LocalMsg( player, "#FS_NotAllowedWaiting", "", uiType )
		return false
	}

	// Check if custom weapons are allowed for this player
	if( !Gamemode1v1_AreCustomWeaponsAllowedForPlayer( player ) )
	{
		LocalMsg( player, "#FS_CustomWepChalOnly", "#FS_CUSTOM_WEAPON_CHAL_ONLY", uiType )
		return false
	}

	// Check tgive cooldown
	if( Time() < player.p.lastTgiveUsedTime + FlowState_TgiveDelay() )
	{
		LocalMsg( player, "#FS_TgiveCooldown", "", uiType )
		return false
	}

	// Check if weapon ref is valid
	if( !SURVIVAL_Loot_IsRefValid( weaponRef ) || _IsWeaponBlockedByRef_1v1( weaponRef ) )
	{
		LocalMsg( player, "#FS_WepNotAllowed", "", uiType )
		return false
	}

	// Check blacklisted weapons
	if( file.blacklistedWeapons.len() && file.blacklistedWeapons.find( weaponRef ) != -1 )
	{
		LocalMsg( player, "#FS_WepBlacklisted", "", uiType )
		return false
	}

	// Check blacklisted abilities
	if( file.blacklistedAbilities.len() && file.blacklistedAbilities.find( weaponRef ) != -1 )
	{
		LocalMsg( player, "FS_AbilityBlacklisted", "", uiType )
		return false
	}

	return true
}

// Main tgive command handler for 1v1 mode
void function ClientCommand_GiveWeapon_1v1( entity player, array<string> args )
{
	if ( !FlowState_TgiveEnabled() )
		return

	bool bRestFlag = false

	if( !IsValid( player ) || !IsAlive( player ) || args.len() < 2 )
		return;
	int uiType = eMsgUI.DEFAULT

	// Handle wepmenu prefix
	if( args[0] == "wepmenu" )
	{
		args.remove( 0 )
		uiType = eMsgUI.WAVE

		// The len check above ran against the un-shifted array; args[1] below
		// would be out of range for a two-token 'tgive wepmenu p'.
		if( args.len() < 2 )
			return
	}

	#if DEVELOPER
		printl( "== 1v1 ClientCommand_GiveWeapon_1v1 ==" )
		print_string_array( args )
	#endif

	// 1v1-specific checks
	bRestFlag = Gamemode1v1_IsPlayerResting( player )

	if ( FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( player ) ) )
	{
		LocalMsg( player, "#FS_NotAllowedWaiting", "", uiType )
		return
	}

	// Block if custom weapons are not allowed
	if( !Gamemode1v1_AreCustomWeaponsAllowedForPlayer( player ) )
	{
		LocalMsg( player, "#FS_CustomWepChalOnly", "", uiType )
		return;	}

	// In 1v1 mode, only allow primary (p) and secondary (s) slots
	if( args[0] != "p" && args[0] != "s" )
		return;
	// Check if the provided weapon ref is either invalid or disabled
	if( !SURVIVAL_Loot_IsRefValid( args[1] ) || _IsWeaponBlockedByRef_1v1( args[1] ) )
	{
		LocalMsg( player, "#FS_WepNotAllowed", "", uiType )
		return;	}

	// Check if the weapon ref is a blacklisted weapon
	if( file.blacklistedWeapons.len() && file.blacklistedWeapons.find( args[1] ) != -1 )
	{
		LocalMsg( player, "#FS_WepBlacklisted", "", uiType )
		return;	}

	// Check if the weapon ref is a blacklisted ability
	if( file.blacklistedAbilities.len() && file.blacklistedAbilities.find( args[1] ) != -1 )
	{
		LocalMsg( player, "#FS_AbilityBlacklisted", "", uiType )
		return;	}

	// Check if the player is within the tgive usage cooldown
	if( Time() < player.p.lastTgiveUsedTime + FlowState_TgiveDelay() )
	{
		LocalMsg( player, "#FS_TgiveCooldown", "", uiType )
		return;	}

	entity weapon

	try
	{
		switch( args[0] )
		{
			case "p":
			case "primary":
				LootData data = SURVIVAL_Loot_GetLootDataByRef( args[1] )
				if( data.lootType != eLootType.MAINWEAPON )
					return;
				entity primary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
				if( IsValid( primary ) )
					player.TakeWeaponByEntNow( primary )

				weapon = player.GiveWeapon( args[1], WEAPON_INVENTORY_SLOT_PRIMARY_0 )
				break

			case "s":
			case "secondary":
				LootData data = SURVIVAL_Loot_GetLootDataByRef( args[1] )
				if( data.lootType != eLootType.MAINWEAPON )
					return;
				entity secondary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
				if( IsValid( secondary ) )
					player.TakeWeaponByEntNow( secondary )

				weapon = player.GiveWeapon( args[1], WEAPON_INVENTORY_SLOT_PRIMARY_1 )
				break
		}
	}
	catch( e420 )
	{
		#if DEVELOPER
			printt( "Invalid weapon name for tgive command." )
		#endif
	}

	// Handle weapon attachments
	if( IsValid( weapon ) && !weapon.IsWeaponOffhand() && args.len() > 2 )
	{
		for( int i = 2; i < args.len(); i++ )
		{
			string attachmentToAdd = args[i]

			if( !IsValidAttachment( attachmentToAdd ) )
				continue

			if( !SURVIVAL_Loot_IsRefValid( attachmentToAdd ) )
				continue

			string attachPoint = GetAttachPointForAttachmentOnWeapon( GetWeaponClassNameWithLockedSet( weapon ), attachmentToAdd )

			if( attachPoint == "" )
				continue

			string attachmentToRemove = GetInstalledWeaponAttachmentForPoint( weapon, attachPoint )

			// Check if there is already an attachment on the attachment point that attachmentToAdd needs
			if( SURVIVAL_Loot_IsRefValid( attachmentToRemove ) )
				weapon.RemoveMod( attachmentToRemove )

			try
			{
				weapon.AddMod( attachmentToAdd )
			}
			catch( e2 )
			{
				#if DEVELOPER
					sqerror( "[1v1:TgiveAttachment] " + e2 )
				#endif
				weapon.RemoveMod( attachmentToAdd )
			}
		}
	}

	if( IsValid( weapon ) && !weapon.IsWeaponOffhand() )
	{
		FS_1v1_StampLockedSet( weapon )
		FS_1v1_ApplyInfiniteAmmo( player, weapon )
		if ( weapon.UsesClipsForAmmo() )
			weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
		player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, GetSlotForWeapon( player, weapon ) )
		player.ClearFirstDeployForAllWeapons()
	}

	player.p.lastTgiveUsedTime = Time()

	string subToken = ""
	string sWepName = ""

	if( !Gamemode1v1_AreCustomWeaponsAllowedForPlayer( player ) )
		subToken = "#FS_CUSTOM_WEAPON_CHAL_ONLY" // Host only allows custom weapons during a challenge

	if( ClientCommand_SaveCurrentWeapons_1v1( player, ["1"] ) )
		sWepName = weapon.GetWeaponSettingString( eWeaponVar.printname )

	LocalMsg( player, "#FS_WEAPONSAVED", subToken, uiType, 5, sWepName )

	// If the player is currently resting, do not let them use the weapons until they enter a match
	if( bRestFlag )
		HolsterAndDisableWeapons_Raw( player )

	return;}

// Save current weapons for 1v1 mode
void function ClientCommand_SaveCurrentWeapons_1v1( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return;
	bool single_save = ( args.len() > 0 )

	entity weapon1
	entity weapon2
	string optics1
	string optics2
	array<string> mods1
	array<string> mods2
	string weaponname1
	string weaponname2

	try
	{
		weapon1 = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		weapon2 = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )

		mods1 = IsValid( weapon1 ) ? GetWeaponMods( weapon1 ) : [""]
		mods2 = IsValid( weapon2 ) ? GetWeaponMods( weapon2 ) : [""]

		foreach( mod in mods1 )
			optics1 = mod + " " + optics1
		foreach( mod in mods2 )
			optics2 = mod + " " + optics2

		if( IsValid( weapon1 ) )
		{
			weaponname1 = weapon1.GetWeaponClassName() + " " + optics1
		}
		else
		{
			#if DEVELOPER
				sqerror( "Player: " + player.GetPlatformUID() + " Weapon 1 invalid, setting to empty " )
			#endif

			weaponname1 = " "
		}

		if( IsValid( weapon2 ) )
		{
			weaponname2 = weapon2.GetWeaponClassName() + " " + optics2
		}
		else
		{
			#if DEVELOPER
				sqerror( "Player: " + player.GetPlatformUID() + " Weapon 2 invalid, setting to empty" )
			#endif

			weaponname2 = ""
		}
	}
	catch( error )
	{
		#if DEVELOPER
			sqerror( "[1v1:SaveWeapons] " + error )
		#endif
	}

	// In 1v1 mode, allow save even when resting (unlike normal DM)
	if( !Gamemode1v1_IsPlayerResting( player ) )
	{
		if( strip( weaponname1 ) == "" || strip( weaponname2 ) == "" )
		{
			#if DEVELOPER
				if( weaponname1 == "" ) { sqerror( "Player: " + player.GetPlatformUID() + " weaponname1 empty" ) }
				if( weaponname2 == "" ) { sqerror( "Player: " + player.GetPlatformUID() + " weaponname2 empty" ) }
			#endif

			LocalMsg( player, "#FS_FAILEDSAVE" )
			return;		}
	}

	#if DEVELOPER
		sqprint( "Player: " + player.GetPlatformUID() + " weaponname1: " + weaponname1 + " weaponname2: " + weaponname2 )
	#endif

	string concatenate_weps = weaponname1 + "; " + weaponname2

	if( !single_save && strip( weaponname1 ) == "" && strip( weaponname2 ) == "" )
	{
		LocalMsg( player, "#FS_FAILEDSAVE" )
		return;	}
	else if( !single_save )
	{
		string subToken = ""
		if( !Gamemode1v1_AreCustomWeaponsAllowedForPlayer( player ) )
		{
			subToken = "#FS_CUSTOM_WEAPON_CHAL_ONLY"
		}

		LocalMsg( player, "#FS_ALL_WEPS_SAVED", subToken )
	}

	weaponlist_1v1[player.p.handle] <- concatenate_weps
	SavePlayerData( player, "saved_weapons", concatenate_weps )

	return;}

// Reset saved weapons for 1v1 mode
void function ClientCommand_ResetSavedWeapons_1v1( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return;
	if( player.p.handle in weaponlist_1v1 )
	{
		delete weaponlist_1v1[player.p.handle]
	}

	SavePlayerData( player, "saved_weapons", "NA" )
	player.p.weapon_loadout = "NA"

	LocalMsg( player, "#FS_WEAPONS_RESET" )

	return;}

// Mod checker - limit mods for weapons in LoadCustomWeapon
string function _ModChecker_1v1( string weaponMods )
{
	if( strip( weaponMods ) == "" )
		return ""

	array<string> weaponMod = split( weaponMods, " " )
	array<string> rifles = ["mp_weapon_energy_ar", "mp_weapon_esaw", "mp_weapon_rspn101", "mp_weapon_vinson", "mp_weapon_lmg", "mp_weapon_g2", "mp_weapon_hemlok"]
	array<string> smgs = ["mp_weapon_r97", "mp_weapon_volt_smg", "mp_weapon_pdw"]

	// Energy weapon mod limits
	if( weaponMod.len() > 0 && ( weaponMod[0] == "mp_weapon_energy_ar" || weaponMod[0] == "mp_weapon_esaw" ) )
	{
		for( int i = 1; i < weaponMod.len(); i++ )
		{
			if( "energy_mag_l3" == weaponMod[i] )
				weaponMod[i] = "energy_mag_l2"
		}
	}

	// Rifle mod limits
	if( weaponMod.len() > 0 && rifles.contains( weaponMod[0] ) )
	{
		for( int i = 1; i < weaponMod.len(); i++ )
		{
			if( i >= weaponMod.len() )
				continue

			if( "stock_tactical_l3" == weaponMod[i] || "stock_tactical_l2" == weaponMod[i] )
				weaponMod[i] = "stock_tactical_l1"
			if( "bullets_mag_l3" == weaponMod[i] )
				weaponMod[i] = "bullets_mag_l2"
			if( "highcal_mag_l3" == weaponMod[i] || "highcal_mag_l2" == weaponMod[i] )
				weaponMod[i] = "highcal_mag_l1"
			if( "energy_mag_l3" == weaponMod[i] || "energy_mag_l2" == weaponMod[i] )
				weaponMod[i] = "energy_mag_l1"
			if( "barrel_stabilizer_l4_flash_hider" == weaponMod[i] || "barrel_stabilizer_l3" == weaponMod[i] || "barrel_stabilizer_l2" == weaponMod[i] || "barrel_stabilizer_l1" == weaponMod[i] )
			{
				weaponMod.remove( i )
				i--
				continue
			}
		}
	}

	// SMG mod limits
	if( weaponMod.len() > 0 && smgs.contains( weaponMod[0] ) )
	{
		for( int i = 1; i < weaponMod.len(); i++ )
		{
			if( i >= weaponMod.len() )
				continue

			if( "stock_tactical_l3" == weaponMod[i] || "stock_tactical_l2" == weaponMod[i] )
				weaponMod[i] = "stock_tactical_l1"
			if( "bullets_mag_l3" == weaponMod[i] )
				weaponMod[i] = "bullets_mag_l2"
			if( "highcal_mag_l3" == weaponMod[i] )
				weaponMod[i] = "highcal_mag_l2"
			if( "energy_mag_l3" == weaponMod[i] )
				weaponMod[i] = "energy_mag_l2"
			if( "barrel_stabilizer_l4_flash_hider" == weaponMod[i] || "barrel_stabilizer_l3" == weaponMod[i] || "barrel_stabilizer_l2" == weaponMod[i] || "barrel_stabilizer_l1" == weaponMod[i] )
			{
				weaponMod.remove( i )
				i--
				continue
			}
		}
	}

	weaponMod.reverse()
	string returnweapon
	foreach( i in weaponMod )
	{
		returnweapon = i + " " + returnweapon
	}

	return returnweapon
}

// Load custom weapons for 1v1 mode - called on respawn
void function LoadCustomWeapon_1v1( entity player )
{
	if( !IsValid( player ) )
		return

	if( player.p.handle in weaponlist_1v1 )
	{
		array<string> weapons = split( weaponlist_1v1[player.p.handle], ";" )
		player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_PRIMARY_1 )

		// Check if weapon's mods is allowed by server
		foreach( index, weapon in weapons )
		{
			if( strip( weapon ) == "" )
				continue

			weapon = _ModChecker_1v1( weapon )
			weapons[index] = weapon
		}

		foreach( index, rweapon in weapons )
		{
			#if DEVELOPER
				sqprint( rweapon )
			#endif

			if( strip( rweapon ) == "" )
				continue

			// Saved loadouts predate the current block list, so re-check on load
			// rather than trusting whatever was persisted.
			array<string> savedParts = split( strip( rweapon ), " " )
			if( savedParts.len() > 0 && _IsWeaponBlockedByRef_1v1( savedParts[0] ) )
				continue

			int slot
			if( index == 0 )
			{
				slot = WEAPON_INVENTORY_SLOT_PRIMARY_0
			}
			else
			{
				slot = WEAPON_INVENTORY_SLOT_PRIMARY_1
			}

			_GiveWeapon_1v1( player, weapons, slot, index )
		}

		WaitFrame()

		if( !IsValid( player ) )
			return

		if( IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 ) ) )
		{
			player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		}
		else if( IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 ) ) )
		{
			player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_1 )
		}
		else
		{
			#if DEVELOPER
				sqerror( "Player: " + player.GetPlatformUID() + " has no valid weapon to set: Active" )
			#endif
		}
	}
}

// Helper function to give weapon with mods
void function _GiveWeapon_1v1( entity player, array<string> WeaponData, int slot, int select )
{
	array<string> Data = split( WeaponData[select], " " )

	if( Data.len() == 0 )
		return

	string weaponclass = Data[0]

	if( weaponclass == "tgive" )
		return

	array<string> Mods
	foreach( string mod in Data )
	{
		if( strip( mod ) != "" && strip( mod ) != weaponclass )
			Mods.append( strip( mod ) )
	}

	try
	{
		entity weaponNew
		if( IsValid( player ) )
		{
			weaponNew = FS_1v1_GiveLockedWeapon( player, weaponclass, slot, Mods )

			if( !IsValid( weaponNew ) )
				return

			FS_1v1_ApplyInfiniteAmmo( player, weaponNew )
			if ( weaponNew.UsesClipsForAmmo() )
				weaponNew.SetWeaponPrimaryClipCount( weaponNew.GetWeaponPrimaryClipCountMax() )
			player.DeployWeapon()

			// Apply weapon cosmetics
			ItemFlavor ornull weaponSkinOrNull = null
			ItemFlavor ornull weaponFlavor = GetWeaponItemFlavorByClass( weaponclass )

			if( weaponFlavor != null )
			{
				array<int> weaponLegendaryIndexMap = FS_ReturnLegendaryModelMapForWeaponFlavor( expect ItemFlavor( weaponFlavor ) )
				if( weaponLegendaryIndexMap.len() > 1 && GetCurrentPlaylistVarBool( "flowstate_giveskins_weapons", false ) )
					weaponSkinOrNull = GetItemFlavorByGUID( weaponLegendaryIndexMap[RandomIntRangeInclusive( 1, weaponLegendaryIndexMap.len() - 1 )] )
			}

			WeaponCosmetics_Apply( weaponNew, weaponSkinOrNull, null )
		}
	}
	catch( e420 )
	{
		#if DEVELOPER
			printw( "_GiveWeapon_1v1 ERROR - ", player, "failed to get weapons" )
		#endif
	}
}
