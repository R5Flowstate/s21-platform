// Flowstate Scenarios: per-fight ground loot, loot bins and doors.
// The map's own bins and doors are shared by every realm, so they are recorded at
// load, removed, and re-created inside each fight's realm. Everything a fight
// spawns is stamped with its realm; loot that bins, deathboxes and drops create
// afterwards copies that realm on its own.

global function FS_Scenarios_Loot_Init
global function FS_Scenarios_Loot_OnEntitiesDidLoad
global function FS_Scenarios_Loot_SpawnForGroup
global function FS_Scenarios_Loot_DestroyForGroup
global function FS_Scenarios_Loot_OwnsLootBin
global function FS_Scenarios_Loot_GiveFightKit
global function FS_Scenarios_Loot_SweepLeftovers

struct ScenariosDoorRecord
{
	string className
	string scriptName
	asset model
	vector origin
	vector angles
	int linkIndex = -1
}

struct
{
	bool groundLoot
	bool lootBins
	bool doorsEnabled
	string lootGroup
	int groundLootPerFight
	int binItemsMin
	int binItemsMax

	array<vector> weaponLocations
	array<LocPair> binLocations
	array<ScenariosDoorRecord> doors
	table<entity, bool> ownedBins
	table<int, array<entity> > realmEnts

	array<string> kitSets
	array<string> kitWeapons
	bool kitPoolBuilt
	bool kitAkimbo
	bool goldPerFight
} file

void function FS_Scenarios_Loot_Init()
{
	file.groundLoot = GetCurrentPlaylistVarBool( "fs_scenarios_ground_loot", true )
	file.lootBins = GetCurrentPlaylistVarBool( "fs_scenarios_lootbins", true )
	file.doorsEnabled = GetCurrentPlaylistVarBool( "fs_scenarios_doors", true )
	file.lootGroup = GetCurrentPlaylistVarString( "fs_scenarios_loot_group", "Zone_High" )
	file.groundLootPerFight = GetCurrentPlaylistVarInt( "fs_scenarios_ground_loot_count", 24 )
	file.binItemsMin = GetCurrentPlaylistVarInt( "fs_scenarios_lootbin_items_min", 3 )
	file.binItemsMax = maxint( file.binItemsMin, GetCurrentPlaylistVarInt( "fs_scenarios_lootbin_items_max", 5 ) )
	file.kitAkimbo = GetCurrentPlaylistVarBool( "fs_scenarios_kit_akimbo", true )
	file.goldPerFight = GetCurrentPlaylistVarBool( "fs_scenarios_gold_weapon_per_fight", true )

	foreach ( string set in split( GetCurrentPlaylistVarString( "fs_scenarios_kit_sets", "blue purple" ), " " ) )
	{
		string choice = strip( set ).tolower()
		if ( FS_1v1_LockedSetSuffixForChoice( choice ) != "" )
			file.kitSets.append( choice )
	}

	AddSpawnCallback( "prop_death_box", FS_Scenarios_Loot_TrackRealmEnt )
	AddSpawnCallback( "prop_survival", FS_Scenarios_Loot_TrackRealmEnt )
}

void function FS_Scenarios_Loot_OnEntitiesDidLoad()
{
	// survival destroys the map's weapon locations as it records them
	file.weaponLocations = clone SURVIVAL_GetWeaponSpotLocations()

	foreach ( entity bin in GetAllLootBins() )
	{
		if ( IsValid( bin ) )
			file.binLocations.append( NewLocPair( bin.GetOrigin(), bin.GetAngles() ) )
	}
	DestroyAllLootBins()

	FS_Scenarios_Loot_RecordDoors()

}

void function FS_Scenarios_Loot_RecordDoors()
{
	array<entity> doors = GetAllCodeDoorEnts()
	table<entity, int> indexOf

	foreach ( entity door in doors )
	{
		if ( !IsValid( door ) )
			continue

		ScenariosDoorRecord record
		record.className = door.GetClassName()
		record.scriptName = door.GetScriptName()
		record.model = door.GetModelName()
		record.origin = door.GetOrigin()
		record.angles = door.GetAngles()
		indexOf[ door ] <- file.doors.len()
		file.doors.append( record )
	}

	foreach ( entity door, int index in indexOf )
	{
		entity link = door.GetLinkEnt()
		if ( IsValid( link ) && link in indexOf )
			file.doors[ index ].linkIndex = indexOf[ link ]
	}

	foreach ( entity door in doors )
	{
		if ( IsValid( door ) )
			door.Destroy()
	}
}

//////////////////////////////////////////////////////////////////////////////
// Fight kit: two locked-set weapons of one rarity per player.

// Every spawnable base weapon that has a locked set in each configured rarity.
void function FS_Scenarios_Loot_BuildKitPool()
{
	file.kitPoolBuilt = true
	foreach ( LootData data in SURVIVAL_Loot_GetByType_InLevel( eLootType.MAINWEAPON ) )
	{
		string ref = data.ref
		if ( GetBaseWeaponRef( ref ) != ref || file.kitWeapons.contains( ref ) )
			continue

		bool hasEverySet = true
		foreach ( string choice in file.kitSets )
		{
			if ( !SURVIVAL_Loot_IsRefValid( ref + FS_1v1_LockedSetSuffixForChoice( choice ) ) )
			{
				hasEverySet = false
				break
			}
		}

		if ( hasEverySet )
			file.kitWeapons.append( ref )
	}

	string sets = ""
	foreach ( string choice in file.kitSets )
		sets += ( sets == "" ? "" : "," ) + choice
}

void function FS_Scenarios_Loot_GiveFightKit( entity player )
{
	if ( !file.kitPoolBuilt )
		FS_Scenarios_Loot_BuildKitPool()

	if ( file.kitWeapons.len() < 2 || file.kitSets.len() == 0 )
		return

	string choice = file.kitSets.getrandom()
	array<string> pool = clone file.kitWeapons
	pool.randomize()

	// The second weapon never shares the first one's class, so no double shotgun.
	array<string> picks = [ pool[ 0 ] ]
	string firstClass = FS_Scenarios_Loot_KitClass( pool[ 0 ] )
	foreach ( string ref in pool )
	{
		if ( FS_Scenarios_Loot_KitClass( ref ) != firstClass )
		{
			picks.append( ref )
			break
		}
	}
	if ( picks.len() < 2 )
		picks.append( pool[ 1 ] )

	// Native infinite ammo for the kit and for anything picked up later in the fight.
	SetInfiniteAmmoForGameMode( player, true )

	array<int> slots = [ WEAPON_INVENTORY_SLOT_PRIMARY_0, WEAPON_INVENTORY_SLOT_PRIMARY_1 ]
	foreach ( int i, int slot in slots )
	{
		string ref = picks[ i ]
		entity weapon = FS_1v1_GiveLockedWeapon( player, ref, slot, [], choice )
		if ( !IsValid( weapon ) )
			continue

		SetInfiniteAmmoForWeapon( player, weapon, null )
		if ( weapon.UsesClipsForAmmo() )
			weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
		if ( file.kitAkimbo )
			FS_Scenarios_Loot_GiveAkimboPartner( player, weapon )
	}

}

// Pistols that support it come as a pair; the second gun lives in the matching
// dual slot and is raised into the off hand once weapons are enabled.
void function FS_Scenarios_Loot_GiveAkimboPartner( entity player, entity weapon )
{
	string classname = weapon.GetWeaponClassName()
	if ( !CanWeaponAkimbo( classname ) )
		return

	int dualSlot = weapon.GetInventoryIndex() + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0
	player.TakeNormalWeaponByIndexNow( dualSlot )

	entity partner = null
	try
	{
		partner = player.GiveWeapon( classname, dualSlot, weapon.GetMods(), false )
	}
	catch ( giveErr )
	{
		printt( "[FS-SCN][KIT] akimbo partner give failed class=" + classname + " " + giveErr )
		return
	}
	if ( !IsValid( partner ) )
		return
	SetInfiniteAmmoForWeapon( player, partner, null )
	if ( partner.UsesClipsForAmmo() )
		partner.SetWeaponPrimaryClipCount( partner.GetWeaponPrimaryClipCountMax() )
}

string function FS_Scenarios_Loot_KitClass( string ref )
{
	if ( ref == "mp_weapon_shotgun_pistol" )
		return "shotgun"
	LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
	return data.lootTags.len() > 0 ? data.lootTags[ 0 ].tolower() : ref
}

bool function FS_Scenarios_Loot_OwnsLootBin( entity bin )
{
	return bin in file.ownedBins
}

void function FS_Scenarios_Loot_TrackRealmEnt( entity ent )
{
	thread FS_Scenarios_Loot_TrackRealmEnt_Deferred( ent )
}

// Survival stamps the realm from the dropping player or the box's owner right
// after spawning, so read it a frame later.
void function FS_Scenarios_Loot_TrackRealmEnt_Deferred( entity ent )
{
	WaitFrame()

	if ( !IsValid( ent ) )
		return

	int realm = FS_GetEntityPrimaryRealm( ent )
	if ( realm < 1 )
		return

	if ( !( realm in file.realmEnts ) )
		file.realmEnts[ realm ] <- []
	file.realmEnts[ realm ].append( ent )
}

//////////////////////////////////////////////////////////////////////////////
// Spawning

void function FS_Scenarios_Loot_SpawnForGroup( ScenariosGroup group )
{
	int realm = group.slotIndex
	float radius = group.ringRadius

	FS_Scenarios_Loot_SweepLeftovers( realm, "arena" )

	if ( file.doorsEnabled )
		FS_Scenarios_Loot_SpawnDoors( group, realm, radius )
	int doors = group.spawnedEnts.len()
	if ( file.lootBins )
		FS_Scenarios_Loot_SpawnBins( group, realm, radius )
	int bins = group.spawnedEnts.len() - doors
	if ( file.groundLoot )
		FS_Scenarios_Loot_SpawnGround( group, realm, radius )
	int ground = group.spawnedEnts.len() - doors - bins

}

// Loot, boxes, thrown-item carriers and ground weapons in this realm that no
// player holds. Anything in every realm is a leak and goes too.
void function FS_Scenarios_Loot_SweepLeftovers( int realm, string reason )
{
	int destroyed = 0
	foreach ( string className in [ "prop_survival", "prop_death_box", "prop_physics", "weaponx" ] )
	{
		foreach ( entity ent in GetEntArrayByClass_Expensive( className ) )
		{
			if ( !IsValid( ent ) || !ent.IsInRealm( realm ) )
				continue
			entity holder = ent.GetParent()
			if ( IsValid( holder ) && ( holder.IsPlayer() || holder.IsWeaponX() ) )
				continue
			if ( FS_Scenarios_IsCarriedByPlayer( ent ) )
				continue
			if ( className == "prop_physics" && ent.GetScriptName() != THROWN_OBJECT_PHYSICS_ENT_SCRIPTNAME )
				continue
			if ( className == "weaponx" && IsValid( ent.GetOwner() ) )
				continue

			if ( ent in file.ownedBins )
				delete file.ownedBins[ ent ]
			ent.Destroy()
			destroyed++
		}
	}
	if ( destroyed > 0 )
		printt( format( "[FS-SCN][LOOT] cleared %s realm=%d stale=%d", reason, realm, destroyed ) )
}

void function FS_Scenarios_Loot_StampRealm( entity ent, int realm )
{
	ent.RemoveFromAllRealms()
	ent.AddToRealm( realm )
}

void function FS_Scenarios_Loot_SpawnDoors( ScenariosGroup group, int realm, float radius )
{
	table<int, entity> created

	foreach ( int index, ScenariosDoorRecord record in file.doors )
	{
		if ( Distance2D( record.origin, group.center ) > radius )
			continue

		entity door = CreateEntity( record.className )
		door.SetModel( record.model )
		door.SetScriptName( record.scriptName )
		door.SetOrigin( record.origin )
		door.SetAngles( record.angles )
		door.kv.solid = SOLID_VPHYSICS

		if ( record.linkIndex in created && IsValid( created[ record.linkIndex ] ) )
		{
			door.LinkToEnt( created[ record.linkIndex ] )
			created[ record.linkIndex ].LinkToEnt( door )
		}

		DispatchSpawn( door )
		FS_Scenarios_Loot_StampRealm( door, realm )
		created[ index ] <- door
		group.spawnedEnts.append( door )
	}
}

bool function FS_Scenarios_Loot_IsGroundLootRef( string ref )
{
	if ( ref == "" || ref == "blank" || !SURVIVAL_Loot_IsRefValid( ref ) )
		return false

	switch ( SURVIVAL_Loot_GetLootDataByRef( ref ).lootType )
	{
		case eLootType.AMMO:
		case eLootType.RESOURCE:
		case eLootType.DATAKNIFE:
		case eLootType.INCAPSHIELD:
		case eLootType.BACKPACK:
		case eLootType.HELMET:
		case eLootType.ARMOR:
		case eLootType.GADGET:
			return false
	}

	return true
}

string function FS_Scenarios_Loot_RollRef()
{
	for ( int attempt = 0; attempt < 16; attempt++ )
	{
		string ref = SURVIVAL_GetWeightedItemFromGroup( file.lootGroup )
		if ( FS_Scenarios_Loot_IsGroundLootRef( ref ) )
			return ref
	}
	return ""
}

void function FS_Scenarios_Loot_SpawnBins( ScenariosGroup group, int realm, float radius )
{
	foreach ( LocPair spot in file.binLocations )
	{
		if ( Distance2D( spot.origin, group.center ) > radius )
			continue

		array<string> refs
		int count = RandomIntRangeInclusive( file.binItemsMin, file.binItemsMax )
		for ( int i = 0; i < count; i++ )
		{
			string ref = FS_Scenarios_Loot_RollRef()
			if ( ref != "" )
				refs.append( ref )
		}

		entity bin = CreateCustomLootBin( spot.origin, spot.angles, refs )
		if ( !IsValid( bin ) )
			continue

		file.ownedBins[ bin ] <- true
		FS_Scenarios_Loot_StampRealm( bin, realm )
		group.spawnedEnts.append( bin )
	}
}

array<vector> function FS_Scenarios_Loot_GroundSpots( ScenariosGroup group, float radius )
{
	array<vector> spots
	foreach ( vector origin in file.weaponLocations )
	{
		if ( Distance2D( origin, group.center ) <= radius )
			spots.append( origin )
	}

	spots.randomize()
	if ( spots.len() > file.groundLootPerFight )
		spots.resize( file.groundLootPerFight )

	return spots
}

// One ground spot per fight carries a gold weapon.
string function FS_Scenarios_Loot_RollGoldRef()
{
	if ( !file.kitPoolBuilt )
		FS_Scenarios_Loot_BuildKitPool()

	array<string> golds
	foreach ( string ref in file.kitWeapons )
	{
		string gold = ref + WEAPON_LOCKEDSET_SUFFIX_GOLD
		if ( SURVIVAL_Loot_IsRefValid( gold ) )
			golds.append( gold )
	}
	return golds.len() > 0 ? golds.getrandom() : ""
}

void function FS_Scenarios_Loot_SpawnGround( ScenariosGroup group, int realm, float radius )
{
	bool goldPending = file.goldPerFight
	foreach ( vector spot in FS_Scenarios_Loot_GroundSpots( group, radius ) )
	{
		string ref = goldPending ? FS_Scenarios_Loot_RollGoldRef() : FS_Scenarios_Loot_RollRef()
		if ( ref == "" )
			ref = FS_Scenarios_Loot_RollRef()
		if ( ref == "" )
			continue

		vector origin = OriginToGround( spot + <0, 0, 16> ) + <0, 0, 2>
		if ( !PositionIsInMapBounds( origin ) || fabs( origin.z - spot.z ) > 512.0 )
			continue

		LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )

		entity loot = SpawnGenericLoot( ref, origin, <-1, -1, -1>, data.lootType == eLootType.MAINWEAPON ? -1 : data.countPerDrop )
		if ( !IsValid( loot ) )
			continue

		FS_Scenarios_Loot_StampRealm( loot, realm )
		group.spawnedEnts.append( loot )
		goldPending = false
	}
}

//////////////////////////////////////////////////////////////////////////////
// Teardown. Keyed by realm as well as by list, so nothing a fight left behind
// survives into the next fight in the same realm.

void function FS_Scenarios_Loot_DestroyForGroup( ScenariosGroup group )
{
	int realm = group.slotIndex
	int destroyed = 0

	foreach ( entity ent in group.spawnedEnts )
	{
		if ( !IsValid( ent ) )
			continue
		if ( ent in file.ownedBins )
			delete file.ownedBins[ ent ]
		ent.Destroy()
		destroyed++
	}
	group.spawnedEnts.clear()

	if ( realm in file.realmEnts )
	{
		foreach ( entity ent in file.realmEnts[ realm ] )
		{
			if ( !IsValid( ent ) || !ent.IsInRealm( realm ) )
				continue

			entity carrier = ent.GetParent()
			if ( IsValid( carrier ) && carrier.GetClassName() == "prop_physics" )
				carrier.Destroy()
			ent.Destroy()
			destroyed++
		}
		delete file.realmEnts[ realm ]
	}

	if ( realm > 0 )
		ClearActiveProjectilesForRealm( realm )

	array<entity> staleBins
	foreach ( entity bin, bool owned in file.ownedBins )
	{
		if ( !IsValid( bin ) )
			staleBins.append( bin )
	}
	foreach ( entity bin in staleBins )
		delete file.ownedBins[ bin ]

}
