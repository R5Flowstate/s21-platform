global function DormantHopups_Init
global function DormantHopups_IsEnabled
global function DormantHopups_GetThresholdOfActivation
global function DormantHopups_GetTotalPointsForHopUp
global function DormantHopups_GetDormantHopupFromBaseMods
global function DormantHopups_HopupIsDormantVersion
global function DormantHopups_WeaponHasDormantHopupInBaseMods
global function DormantHopups_GetNonDormantHopupFromString
global function DormantHopups_GetLockedHopupFromModList
global function DormantHopups_GetPoints
global function DormantHopups_CanGainPoints
global function DormantHopups_IsHopupUnlocked
global function DormantHopups_WeaponHasDormantHopupOnWeapon
global function DormantHopups_GetBestDormantHopupWeapon
global function DormantHopups_GetArsenalPoints

global const string HOPUP_POINTS_PICKUP = "hopup_points_pickup"

global enum eDormantHopupPointSources
{
	DAMAGE,
	HOPUP_BOOSTER,
	ARSENAL,
	WEAPON_PICKUP,
	SLING_SWAP,
	RESPAWN,
	DEV_TESTING,
	AKIMBO_MERGE,
}

struct
{
	table<entity, int> weaponPoints
} file

struct
{
	int dormantHopupThresholdDefault = 425
	int dormantHopupThresholdOne = 300
	int dormantHopupThresholdTwo = 375
	int dormantHopupThresholdThree = 600
	int dormantHopupThresholdFour = 500
	int dormantHopupArsenalPoints = 100
	int dormantHopupPickupPoints = 100
	float rampartExtraProgressScalar = 1.5
} tuning

void function DormantHopups_Init()
{
	if ( !DormantHopups_IsEnabled() )
		return

	RegisterCustomItemPickupAction( HOPUP_POINTS_PICKUP, DormantHopups_ItemPickup )

	#if SERVER
		AddDamageByCallback( "player", DormantHopups_OnDamagedByPlayer )
		Loot_AddCallback_OnGiveMainWeapon( DormantHopups_OnGiveMainWeapon )
		Loot_AddCallback_OnWeaponDrop( DormantHopups_OnWeaponDrop )
	#endif

	printt( "[LOOT] dormant hopups enabled" )
}

bool function DormantHopups_IsEnabled()
{
	return !GetCurrentPlaylistVarBool( "disable_dormant_hopups", false )
}

int function DormantHopups_GetArsenalPoints()
{
	return tuning.dormantHopupArsenalPoints
}

int function DormantHopups_GetThresholdOfActivation( LootData weaponData, int checkVal = -1 )
{
	string perWeaponOverride = GetCurrentPlaylistVarString( weaponData.ref + "_dormant_hopup_point_override", "" )
	if ( perWeaponOverride != "" )
		return ConvertStringToInt( perWeaponOverride )

	string dormantHopup = DormantHopups_GetDormantHopupFromBaseMods( weaponData )
	string perHopupOverride = GetCurrentPlaylistVarString( dormantHopup + "_dormant_hopup_point_override", "" )
	if ( perHopupOverride != "" )
		return ConvertStringToInt( perHopupOverride )

	return DormantHopups_GetTotalPointsForHopUp( dormantHopup, checkVal )
}

int function DormantHopups_GetTotalPointsForHopUp( string dormantHopup, int checkVal = -1 )
{
	switch ( dormantHopup )
	{
		case "dormant_hopup_dual_loader":
		case "dormant_hopup_ultimate_accelerator":
			return tuning.dormantHopupThresholdOne

		case "dormant_hopup_double_tap":
		case "dormant_hopup_selectfire":
		case "dormant_hopup_gunshield":
		case "dormant_hopup_executioner":
			return tuning.dormantHopupThresholdTwo

		case "dormant_hopup_turbocharger":
		case "dormant_hopup_headshot_dmg":
			return tuning.dormantHopupThresholdThree

		case "dormant_hopup_shield_breaker":
			return tuning.dormantHopupThresholdFour

		case "dormant_hopup_unshielded_dmg":
		case "dormant_hopup_quickdraw_holster":
		case "dormant_hopup_highcal_rounds":
		case "dormant_hopup_paintball_elite":
			return tuning.dormantHopupThresholdDefault
	}

	return tuning.dormantHopupThresholdDefault
}

string function DormantHopups_GetDormantHopupFromBaseMods( LootData wData )
{
	if ( !DormantHopups_IsEnabled() )
		return ""

	foreach ( string mod in wData.baseMods )
	{
		if ( !SURVIVAL_Loot_IsRefValid( mod ) )
			continue
		if ( SURVIVAL_Loot_GetLootDataByRef( mod ).lootType != eLootType.ATTACHMENT )
			continue
		if ( SURVIVAL_Loot_GetLootDataByRef( mod ).lootTags.contains( "DormantHopup" ) )
			return mod
	}

	return ""
}

bool function DormantHopups_HopupIsDormantVersion( string hopup )
{
	if ( !DormantHopups_IsEnabled() )
		return false
	if ( !SURVIVAL_Loot_IsRefValid( hopup ) )
		return false
	if ( SURVIVAL_Loot_GetLootDataByRef( hopup ).lootType != eLootType.ATTACHMENT )
		return false

	return SURVIVAL_Loot_GetLootDataByRef( hopup ).lootTags.contains( "DormantHopup" )
}

bool function DormantHopups_WeaponHasDormantHopupInBaseMods( LootData weaponData )
{
	if ( !DormantHopups_IsEnabled() )
		return false

	return DormantHopups_GetDormantHopupFromBaseMods( weaponData ) != ""
}

string function DormantHopups_GetNonDormantHopupFromString( string dormantHopup )
{
	if ( !DormantHopups_IsEnabled() )
		return ""
	if ( dormantHopup == "" )
		return ""

	array<string> tokens = split( dormantHopup, "_" )
	if ( tokens.len() < 3 || !tokens.contains( "dormant" ) )
		return ""

	string finalString = tokens[1]
	for ( int i = 2; i < tokens.len(); i++ )
		finalString += "_" + tokens[i]

	if ( !SURVIVAL_Loot_IsRefValid( finalString ) )
		return ""

	return finalString
}

string function DormantHopups_GetLockedHopupFromModList( array<string> mods )
{
	if ( !DormantHopups_IsEnabled() )
		return ""

	string lockedHopup = ""
	foreach ( string mod in mods )
	{
		if ( !SURVIVAL_Loot_IsRefValid( mod ) )
			continue
		if ( SURVIVAL_Loot_GetLootDataByRef( mod ).lootType != eLootType.ATTACHMENT )
			continue
		if ( SURVIVAL_Loot_GetLootDataByRef( mod ).lootTags.contains( "LockedHopup" ) )
			lockedHopup = mod
	}

	return lockedHopup
}

int function DormantHopups_GetPoints( entity weapon )
{
	if ( !IsValid( weapon ) )
		return 0
	if ( !DormantHopups_IsEnabled() )
		return 0
	if ( !( weapon in file.weaponPoints ) )
		return 0

	return file.weaponPoints[weapon]
}

bool function DormantHopups_CanGainPoints( entity weapon, bool isSlingWeapon = false )
{
	if ( !IsValid( weapon ) )
		return false
	if ( !DormantHopups_IsEnabled() )
		return false

	LootData weaponData = SURVIVAL_GetLootDataFromWeapon( weapon )
	if ( !DormantHopups_WeaponHasDormantHopupInBaseMods( weaponData ) )
		return false
	if ( DormantHopups_IsHopupUnlocked( weapon, weaponData ) )
		return false

	return true
}

bool function DormantHopups_IsHopupUnlocked( entity weapon, LootData weaponData )
{
	if ( !DormantHopups_IsEnabled() )
		return false
	if ( !IsValid( weapon ) )
		return false
	if ( !DormantHopups_WeaponHasDormantHopupInBaseMods( weaponData ) )
		return false

	string hopupMod = DormantHopups_GetNonDormantHopupFromString( DormantHopups_GetDormantHopupFromBaseMods( weaponData ) )
	if ( hopupMod == "" )
		return false

	return weapon.HasMod( hopupMod )
}

bool function DormantHopups_WeaponHasDormantHopupOnWeapon( entity weapon )
{
	if ( !IsValid( weapon ) )
		return false
	if ( !DormantHopups_IsEnabled() )
		return false

	return DormantHopups_GetPoints( weapon ) > 0
}

entity function DormantHopups_GetBestDormantHopupWeapon( entity player )
{
	if ( !DormantHopups_IsEnabled() )
		return null
	if ( !IsValid( player ) )
		return null

	array<entity> playerWeapons = SURVIVAL_GetPrimaryWeapons( player )
	entity hopupWeapon
	foreach ( entity weapon in playerWeapons )
	{
		if ( !DormantHopups_CanGainPoints( weapon ) )
			continue

		hopupWeapon = weapon
		if ( player.GetActiveWeapon( eActiveInventorySlot.mainHand ) == weapon )
			break
		if ( GetSlotForWeapon( player, weapon ) == player.GetLastCycleSlot() )
			break
	}

	return hopupWeapon
}

bool function DormantHopups_ItemPickup( entity pickup, entity player, int pickupFlags, entity deathBox, int ornull desiredCount, LootData data )
{
	#if SERVER
		if ( IsValid( player ) )
		{
			entity weapon = DormantHopups_GetBestDormantHopupWeapon( player )
			if ( IsValid( weapon ) )
				DormantHopups_AddPoints( player, weapon, tuning.dormantHopupArsenalPoints, eDormantHopupPointSources.HOPUP_BOOSTER )

			PlayPickupSound( player, data.ref, pickupFlags )
		}

		if ( IsValid( pickup ) )
			pickup.SetClipCount( 0 )
	#endif

	return true
}

#if SERVER
void function DormantHopups_OnDamagedByPlayer( entity hitEnt, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return

	entity weapon = DamageInfo_GetWeapon( damageInfo )
	if ( !IsValid( weapon ) )
		weapon = attacker.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( !IsValid( weapon ) )
		return

	int dmg = int( DamageInfo_GetDamage( damageInfo ) )
	if ( dmg <= 0 )
		return

	DormantHopups_AddPoints( attacker, weapon, dmg, eDormantHopupPointSources.DAMAGE )
}

void function DormantHopups_OnGiveMainWeapon( entity player, entity pickup, entity newWeapon )
{
	if ( !IsValid( player ) || !IsValid( newWeapon ) )
		return

	if ( IsValid( pickup ) )
	{
		int stored = GetPropSurvivalExtraPropertyFromEnt( pickup )
		if ( stored > 0 )
			file.weaponPoints[newWeapon] <- stored
	}

	DormantHopups_AddPoints( player, newWeapon, tuning.dormantHopupPickupPoints, eDormantHopupPointSources.WEAPON_PICKUP )
}

void function DormantHopups_OnWeaponDrop( entity player, entity droppedProp, entity weaponToDrop )
{
	if ( !IsValid( droppedProp ) || !IsValid( weaponToDrop ) )
		return

	int points = DormantHopups_GetPoints( weaponToDrop )
	if ( weaponToDrop in file.weaponPoints )
		delete file.weaponPoints[weaponToDrop]
	if ( points <= 0 )
		return

	SetPropSurvivalExtraPropertyOnEnt( droppedProp, points )
}

void function DormantHopups_AddPoints( entity player, entity weapon, int amount, int source )
{
	if ( !DormantHopups_CanGainPoints( weapon ) )
		return

	if ( PlayerHasPassive( player, ePassives.PAS_GUNNER ) && tuning.rampartExtraProgressScalar > 1.0 )
		amount = int( amount * tuning.rampartExtraProgressScalar )

	int points = DormantHopups_GetPoints( weapon ) + amount
	file.weaponPoints[weapon] <- points

	LootData weaponData = SURVIVAL_GetLootDataFromWeapon( weapon )
	if ( points >= DormantHopups_GetThresholdOfActivation( weaponData ) )
		DormantHopups_Unlock( player, weapon, weaponData )
}

void function DormantHopups_Unlock( entity player, entity weapon, LootData weaponData )
{
	string dormantHopup = DormantHopups_GetDormantHopupFromBaseMods( weaponData )
	string hopupMod = DormantHopups_GetNonDormantHopupFromString( dormantHopup )
	if ( hopupMod == "" )
		return
	if ( weapon.HasMod( hopupMod ) )
		return

	if ( weapon.HasMod( dormantHopup ) )
		weapon.RemoveMod( dormantHopup )

	weapon.AddMod( hopupMod )

	table<string, string> toggles = GetAttachmentsWithToggleModsList()
	if ( hopupMod in toggles )
	{
		string toggleMod = toggles[hopupMod]
		if ( toggleMod != "" && !weapon.HasMod( toggleMod ) )
			weapon.AddMod( toggleMod )
	}

	printt( "[LOOT] dormant hopup unlocked=" + hopupMod + " weapon=" + weapon.GetWeaponClassName() )
}
#endif
