// Flowstate Scenarios: fight locations. The spawn CSV is the source; every row
// is re-checked here with the live collision, and a map short on locations is
// topped up from its navmesh. "scenarios_dump_spawns" prints the live set as
// CSV rows for datatable/fs_spawns_fs_scenarios_<map>_set_N.csv.

global function FS_Scenarios_Spawns_Init
global function FS_Scenarios_Spawns_Validate
global function FS_Scenarios_NavPointIsSane

const float GEN_MIN_TEAM_SEPARATION = 1600.0
const float GEN_MAX_TEAM_SEPARATION = 2600.0
const float GEN_MAX_LEVEL_DIFFERENCE = 192.0
const float GEN_LOCATION_SPREAD = 2500.0
const int GEN_CANDIDATES_PER_LOCATION = 12

struct
{
	int minLocations
} file

void function FS_Scenarios_Spawns_Init()
{
	file.minLocations = GetCurrentPlaylistVarInt( "fs_scenarios_min_locations", 16 )
	AddClientCommandCallback( "scenarios_dump_spawns", ClientCommand_FS_Scenarios_DumpSpawns )
}

// Spawns one team stands on must hold a standing hull for each member's circle
// slot as well as for the team's own point.
bool function FS_Scenarios_Spawns_TeamSpotIsClear( vector origin )
{
	if ( !SpawnSystem_CheckSpawn( origin + <0, 0, 8> ) )
		return false

	int members = FS_Scenarios_GetPlayersPerTeam()
	for ( int i = 0; i < members; i++ )
	{
		float r = float( i ) / float( members ) * 2.0 * PI
		if ( !SpawnSystem_CheckSpawn( origin + 30.0 * <sin( r ), cos( r ), 0.0> + <0, 0, 8> ) )
			return false
	}
	return true
}

// The navmesh query natives can hand back unfilled entries (coordinates in the
// hundreds of millions); SetOrigin on one is a script error.
bool function FS_Scenarios_NavPointIsSane( vector point, vector center, float radius )
{
	return PositionIsInMapBounds( point ) && Distance2D( point, center ) <= radius
}

void function FS_Scenarios_Spawns_Validate()
{
	int loaded = arenaLocations.len()

	if ( SpawnSystem_GetCurrentSpawnSet().find( "trivial" ) == 0 )
	{
		Warning( "[FS-SCN][SPAWN] no spawn CSV for " + GetMapName() + "; generating every location" )
		arenaLocations.clear()
	}

	for ( int i = arenaLocations.len() - 1; i >= 0; i-- )
	{
		foreach ( LocPair spawn in arenaLocations[ i ].respawnLocations )
		{
			if ( !SpawnSystem_CheckSpawn( spawn.origin + <0, 0, 8> ) )
			{
				arenaLocations.remove( i )
				break
			}
		}
	}

	int kept = arenaLocations.len()
	if ( kept < file.minLocations )
		FS_Scenarios_Spawns_Generate( file.minLocations - kept )


	if ( arenaLocations.len() == 0 )
		Warning( "[FS-SCN][SPAWN] no usable fight locations on " + GetMapName() )
}

array<vector> function FS_Scenarios_Spawns_Anchors()
{
	array<vector> anchors
	foreach ( LocationsData loc in arenaLocations )
		anchors.append( loc.Center )

	// Loot bins sit on playable ground across the whole map.
	if ( anchors.len() == 0 )
	{
		foreach ( entity bin in GetAllLootBins() )
			anchors.append( bin.GetOrigin() )
	}

	if ( anchors.len() == 0 )
		anchors.append( Gamemode1v1_GetWaitingRoomLocation().origin )

	return anchors
}

void function FS_Scenarios_Spawns_Generate( int wanted )
{
	int teams = FS_Scenarios_GetScenariosTeamCount()
	array<vector> centers
	foreach ( LocationsData loc in arenaLocations )
		centers.append( loc.Center )

	array<vector> anchors = FS_Scenarios_Spawns_Anchors()
	int made = 0
	int noSeed = 0
	int crowdedCount = 0
	int badTeamSpot = 0

	for ( int attempt = 0; attempt < wanted * GEN_CANDIDATES_PER_LOCATION && made < wanted; attempt++ )
	{
		vector anchor = anchors.getrandom()
		array<vector> seeds = NavMesh_RandomPositions_LargeArea( anchor, HULL_HUMAN, 1, 0.0, 20000.0 )
		if ( seeds.len() == 0 || !FS_Scenarios_NavPointIsSane( seeds[ 0 ], anchor, 20000.0 ) )
		{
			noSeed++
			continue
		}

		vector center = seeds[ 0 ]
		bool crowded = false
		foreach ( vector used in centers )
		{
			if ( Distance2D( used, center ) < GEN_LOCATION_SPREAD )
			{
				crowded = true
				break
			}
		}
		if ( crowded )
		{
			crowdedCount++
			continue
		}

		float halfSeparation = RandomFloatRange( GEN_MIN_TEAM_SEPARATION, GEN_MAX_TEAM_SEPARATION ) * 0.5
		float baseYaw = RandomFloatRange( -180.0, 180.0 )

		LocationsData loc
		bool ok = true
		for ( int t = 0; t < teams && ok; t++ )
		{
			vector wantAt = center + AnglesToForward( <0, baseYaw + t * 360.0 / teams, 0> ) * halfSeparation
			vector ornull clamped = NavMesh_ClampPointForHullWithExtents( wantAt, HULL_HUMAN, <256, 256, 384> )
			if ( clamped == null )
			{
				ok = false
				break
			}

			vector spot = expect vector( clamped )
			if ( fabs( spot.z - center.z ) > GEN_MAX_LEVEL_DIFFERENCE || !FS_Scenarios_Spawns_TeamSpotIsClear( spot ) )
			{
				ok = false
				break
			}

			loc.respawnLocations.append( NewLocPair( spot, <0, VectorToAngles( FlattenVec( center - spot ) ).y, 0> ) )
		}

		if ( !ok )
		{
			badTeamSpot++
			continue
		}

		loc.Center = GetCenterOfCircle( loc.respawnLocations )
		loc.ids = "navgen_live_" + string( made )
		arenaLocations.append( loc )
		centers.append( loc.Center )
		made++
	}

}

void function ClientCommand_FS_Scenarios_DumpSpawns( entity player, array<string> args )
{
	if ( !IsValid( player ) || !GetConVarBool( "sv_cheats" ) )
		return

	int teams = FS_Scenarios_GetScenariosTeamCount()
	printl( "origin,angles,info" )
	printl( "\"< 0, 0, 0 >\",\"< 0, 0, 0>\" ,\"pakData.playlist:fs_scenarios\"" )
	printl( "\"< 0, 0, 0 >\",\"< 0, 0, 0>\" ,\"pakData.map:" + GetMapName() + "\"" )
	printl( "\"< 0, 0, 0 >\",\"< 0, 0, 0>\" ,\"pakData.spawnsCount:" + string( arenaLocations.len() * teams ) + "\"" )
	printl( "\"< 0, 0, 0 >\",\"< 0, 0, 0>\" ,\"pakData.teamCount:" + string( teams ) + "\"" )

	foreach ( int i, LocationsData loc in arenaLocations )
	{
		foreach ( int t, LocPair spawn in loc.respawnLocations )
		{
			printl( format( "\"< %.1f, %.1f, %.1f>\",\"< 0, %.1f, 0>\" ,\"loc_%d_team%d\"",
				spawn.origin.x, spawn.origin.y, spawn.origin.z, spawn.angles.y, i, t ) )
		}
	}
	printl( "vector,vector,string" )
}
