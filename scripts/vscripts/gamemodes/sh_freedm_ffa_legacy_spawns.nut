// Legacy Flowstate POI spawns for FFA.
//
// Ports the LocationSettings spawn pools from mods_legacy/Flowstate
// (fs_tdm/sh_gamemode_fsdm.nut) into the native FreeDM spawn system.
// Set the `ffa_legacy_location` playlist var to a location name below and
// every FFA spawn comes from its authored vector pool through
// Spawn_SetSpawnPointOverride; empty var keeps native map-entity spawns.
//
// Only locations on real terrain of maps shipped on s21-full are carried.
// The DEAFPS/AyeZee skybox customs (Rust, Shoothouse, Noshahr, Dustment at
// z~2700-4100, Killyard/Nuketown at z=43000) need geometry that is not in
// our builds: real party_crasher spawns sit at z 560-1264.

global function FreeDM_Legacy_AddLocation

#if SERVER
global function FreeDM_FFA_RegisterLegacySpawns
global function FreeDM_FFA_GetLegacyPool
#endif // SERVER

struct
{
	table<string, table<string, array<array<vector> > > > locs
	entity dummy = null
} file

void function FreeDM_Legacy_AddLocation( string mapName, string locName, array<array<vector> > spawns )
{
	if ( !( mapName in file.locs ) )
		file.locs[mapName] <- {}
	file.locs[mapName][locName] <- spawns
}

#if SERVER
bool function FreeDM_FFA_LegacySpawnsAvailable()
{
	string want = GetCurrentPlaylistVarString( "ffa_legacy_location", "" )
	if ( want == "" )
		return false
	string mapName = GetMapName()
	if ( !( mapName in file.locs ) || !( want in file.locs[mapName] ) )
		return false
	return file.locs[mapName][want].len() > 0
}

entity function FreeDM_FFA_LegacySpawnOverride( entity player )
{
	string mapName = GetMapName()
	string want = GetCurrentPlaylistVarString( "ffa_legacy_location", "" )
	if ( !( mapName in file.locs ) || !( want in file.locs[mapName] ) )
		return null
	array<array<vector> > spawns = file.locs[mapName][want]
	if ( spawns.len() == 0 )
		return null

	array<entity> alive
	foreach ( entity other in GetPlayerArray_Alive() )
	{
		if ( !IsValid( other ) || other == player || other.GetTeam() == TEAM_SPECTATOR )
			continue
		alive.append( other )
	}

	vector mins = GetBoundsMin( HULL_HUMAN )
	vector maxs = GetBoundsMax( HULL_HUMAN )

	int bestIdx = -1
	float bestDist = -1.0
	for ( int k = 0; k < spawns.len(); k++ )
	{
		vector org = spawns[k][0]
		TraceResults free = TraceHull( org, org + <0,0,1>, mins, maxs, player, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )
		if ( free.startSolid || free.allSolid )
			continue
		float nearest = 999999.0
		foreach ( entity other in alive )
		{
			float d = Distance( org, other.GetOrigin() )
			if ( d < nearest )
				nearest = d
		}
		if ( nearest > bestDist )
		{
			bestDist = nearest
			bestIdx = k
		}
	}
	if ( bestIdx < 0 )
		return null

	if ( !IsValid( file.dummy ) )
	{
		file.dummy = CreateEntity( "info_target" )
		file.dummy.SetOrigin( <0,0,-10000> )
	}
	file.dummy.SetOrigin( spawns[bestIdx][0] )
	file.dummy.SetAngles( spawns[bestIdx][1] )
	return file.dummy
}

void function FreeDM_FFA_RegisterLegacySpawns()
{
	FreeDM_LegacySpawns_Register()

	if ( !FreeDM_FFA_LegacySpawnsAvailable() )
		return

	Spawn_SetSpawnPointOverride( FreeDM_FFA_LegacySpawnOverride )
	printt( "[FreeDM] FFA legacy spawns active loc=" + GetCurrentPlaylistVarString( "ffa_legacy_location", "" ) +
		" n=" + string( file.locs[GetMapName()][GetCurrentPlaylistVarString( "ffa_legacy_location", "" )].len() ) )
}

array<array<vector> > function FreeDM_FFA_GetLegacyPool()
{
	array<array<vector> > empty
	string want = GetCurrentPlaylistVarString( "ffa_legacy_location", "" )
	if ( want == "" )
		return empty
	string mapName = GetMapName()
	if ( !( mapName in file.locs ) || !( want in file.locs[mapName] ) )
		return empty
	return file.locs[mapName][want]
}
#endif // SERVER

// Legacy Flowstate TDM/FFA POI spawns, ported from mods_legacy/Flowstate
// (fs_tdm/sh_gamemode_fsdm.nut LocationSettings). Origins/angles untouched.
// Only locations for maps shipped on s21-full are carried here.

void function FreeDM_LegacySpawns_Register()
{
	FreeDM_Legacy_AddLocation( "mp_rr_arena_phase_runner", "Phase Runner",
		[
			[<26118.4551, 16751.2969, -1279.96875>, <0, 89.4115295, 0>],
			[<23497.5859, 20112.5137, -1151.96875>, <0, -45.1068459, 0>],
			[<25032.3184, 21795.0313, -927.96875>, <0, -13.0043278, 0>],
			[<27145.8184, 21711.4082, -927.96875>, <0, -155.027145, 0>],
			[<30564.7754, 17781.6094, -895.97345>, <0, -154.644897, 0>],
			[<24197.9258, 14329.3359, -1027.36292>, <0, -5.09298944, 0>],
			[<26418.9688, 13381.127, -1023.96875>, <0, 41.6298714, 0>],
			[<28780.25, 16014.9004, -1033.47864>, <0, 171.618332, 0>],
			[<30562.041, 13306.3379, -906.315552>, <0, 115.207245, 0>],
			[<21345.25, 13560.7031, -448.967621>, <0, 40.8450966, 0>],
			[<20491.3262, 17548.2148, -882.265808>, <0, 0.0175942089, 0>]
		] )

	FreeDM_Legacy_AddLocation( "mp_rr_aqueduct", "Overflow",
		[
			[<3863.79321, -3262.95703, 282.03125>, <0, -135.066055, 0>],
			[<4169.18262, -5555.22119, 410.03125>, <0, 146.240646, 0>],
			[<-620.375977, -6611.72803, 410.03125>, <0, 29.9391613, 0>],
			[<-1859.04651, -3355.55103, 282.03125>, <0, -51.3485374, 0>],
			[<817.221375, -3503.38354, 482.03125>, <0, 44.7887459, 0>]
		] )

	FreeDM_Legacy_AddLocation( "mp_rr_arena_composite", "Drop-Off",
		[
			[<-3592, 1081, 258>, <0, 37, 0>],
			[<3592, 1081, 258>, <0, 142, 0>],
			[<-1315, 4113, 71>, <0, -43, 0>],
			[<1315, 4113, 71>, <0, -136, 0>],
			[<-1374, 1, 259>, <0, 35, 0>],
			[<1374, 1, 259>, <0, 140, 0>],
			[<-12.9539881, 3344.23584, -34>, <0, -92.351532, 0>],
			[<1705.29504, 3284.08252, 210>, <0, -142.564148, 0>],
			[<692.371887, 1771.11829, -50>, <0, 51.6300087, 0>],
			[<-358.171814, 1723.92322, -50>, <0, 45.0872917, 0>],
			[<-912.219482, 2789.4751, 10>, <0, -53.7381134, 0>],
			[<3556, 916, 258>, <8, 76, 0>],
			[<3765, 1115, 258>, <8, 171, 0>],
			[<-2388, 2758, 259>, <0, -102.007385, 0>],
			[<-1282, 1750, 259>, <16, 50, 0>]
		] )

	FreeDM_Legacy_AddLocation( "mp_rr_party_crasher", "Party Crasher",
		[
			[<1729.17407, -3585.65137, 601.736206>, <0, 103.168709, 0>],
			[<345.111481, -3769.65674, 583.285156>, <0, 78.5349045, 0>],
			[<-1315.06567, -2856.39771, 999.132568>, <0, 39.8982162, 0>],
			[<-2242.99829, -1911.60974, 1231.47437>, <0, 35.2527733, 0>],
			[<-2805.87012, -650.600647, 1272.09473>, <0, 32.1970596, 0>],
			[<262.267334, 2781.46118, 710.572449>, <0, -139.138306, 0>],
			[<-3970.97266, 2639.4585, 583.285156>, <0, -35.2144508, 0>],
			[<-2711.53491, 4067.46069, 601.736206>, <0, -46.8964882, 0>],
			[<-934.579468, 4998.19189, 583.281555>, <0, -90.8201675, 0>],
			[<1259.38, 3572.83008, 633.238098>, <0, -112.696632, 0>],
			[<2623.1499, 2661.17822, 940.03125>, <0, -99.6138458, 0>],
			[<1981.64294, 2721.13745, 723.03125>, <0, -146.273544, 0>],
			[<3116.81201, 1577.45361, 940.03125>, <0, 169.12117, 0>],
			[<3843.68774, -595.504456, 583.002197>, <0, 172.503952, 0>],
			[<1670.724, -768.35498, 720.573608>, <0, 107.206459, 0>]
		] )

	FreeDM_Legacy_AddLocation( "mp_rr_party_crasher", "Encore",
		[
			[<4284.88037, -102.993355, 2680.03125>, <0, -179.447098, 0>],
			[<-4282.63086, -94.0586777, 2680.03125>, <0, -1.49068689, 0>],
			[<-4016.35449, -2984.96777, 2723.82983>, <0, 97.363739, 0>],
			[<-3202.32129, -3163.42432, 2863.03125>, <0, 91.0571976, 0>],
			[<11.4232283, -3441.22241, 2836.03125>, <0, 92.0147095, 0>],
			[<2008.17126, -3265.22412, 2863.03125>, <0, 114.795891, 0>],
			[<4112.67383, -2757.43213, 2717.97461>, <0, 108.537872, 0>],
			[<2756.42676, 2774.64746, 2664.18604>, <0, -106.51664, 0>],
			[<1610.47034, 3414.86646, 2786.24658>, <0, -85.7662277, 0>],
			[<-799.999512, 3280.4292, 2930.03125>, <0, -77.9509888, 0>],
			[<-1641.51526, 3283.95166, 2785.31738>, <0, -90.7040482, 0>],
			[<2215.3208, -131.611176, 2599.72876>, <0, 175.527969, 0>],
			[<-2034.16443, -41.9182587, 2599.34814>, <0, -0.69002372, 0>],
			[<3.56009603, 2732.36084, 2930.03125>, <0, -86.8429184, 0>],
			[<3.75123262, -2400.2561, 2829.96875>, <0, 92.3833466, 0>]
		] )

	FreeDM_Legacy_AddLocation( "mp_rr_desertlands_hu", "TTV Building",
		[
			[<11360, 6151, -4079>, <0, 102, 0>],
			[<11407, 6778, -4295>, <0, 88, 0>],
			[<11973, 4158, -4220>, <0, 82, 0>],
			[<9956, 3435, -4239>, <0, 0, 0>],
			[<9038, 3800, -4120>, <0, -88, 0>],
			[<7933, 6692, -4250>, <0, 76, 0>],
			[<8990, 5380, -4250>, <0, 145, 0>],
			[<8200, 5463, -3815>, <0, 0, 0>],
			[<9789, 5363, -3480>, <0, 174, 0>],
			[<9448, 5804, -4000>, <0, 0, 0>],
			[<8135, 4087, -4233>, <0, 90, 0>],
			[<9761, 5980, -4250>, <0, 135, 0>],
			[<11393, 5477, -4289>, <0, 90, 0>],
			[<12027, 7121, -4290>, <0, -120, 0>],
			[<8105, 6156, -4300>, <0, -45, 0>],
			[<9420, 5528, -4236>, <0, 90, 0>],
			[<8277, 6304, -3940>, <0, 0, 0>],
			[<8186, 5513, -3828>, <0, 0, 0>],
			[<8243, 4537, -4235>, <-13, 32, 0>],
			[<11700, 6207, -4435>, <-10, 90, 0>],
			[<11181, 5862, -3900>, <0, -180, 0>],
			[<9043, 5866, -4171>, <0, 90, 0>],
			[<11210, 4164, -4235>, <0, 90, 0>],
			[<12775, 4446, -4235>, <0, 150, 0>],
			[<9012, 5386, -4242>, <0, 90, 0>]
		] )
}
