#if SERVER
// #if SERVER is just here to make the intelliJ VM highlight work (doesn't work if comment on same line)

// current version of MapNode only works for FreeDM

global function MapNode_Init
global function MapNode_GetAirdropLocations
global function MapNode_GetAvailableAirdropLocations
global function MapNode_GetIntroCameraPoints
global function MapNode_ResetAvailableAirDropLocations
global function MapNode_TakeAvailableAirdropLocation
global function MapNode_IsMapDataValid

struct MapNode_MapData
{
	array<entity> spawnPoints
	array<entity> airdropPoints
	array<entity> availableAirdropPoints
	array<Point>  introCameras
	entity        node
}

struct
{
	table< string, MapNode_MapData > mapNodeTable
	array<string> allMapIDs
	string currentMapID

	float lastAirdropTimestamp
} file

void function MapNode_Init()
{
	AddSpawnCallbackEditorClass( "func_brush", "func_brush_freedm_wall", SetupFuncBrushWall )

	// blocking entity spawning
	//TODO DIVY - Make checkboxes the authoritative enable/disable setting for Ziprails
	BlockMapEntityParseCreationOf( "zipline", "script_control_omit_zipline", "" )
	BlockMapEntityParseCreationOf( "script_mover_train_node", "", "script_control_omit_zipline" )
	//

	BlockMapEntityParseCreationOf( "script_skydive_launcher", "", "" )

	// blocking entity spawning <- Copied from gamemode_control (April 6th, 2023)
	BlockMapEntityParseCreationOf( "prop_dynamic", "", "script_survival_survey_beacon" )
	BlockMapEntityParseCreationOf( "zipline", "skydive_tower", "" )
	BlockMapEntityParseCreationOf( "prop_dynamic", "jump_tower", "" )
	BlockMapEntityParseCreationOf( "prop_dynamic", "jump_tower_stairs", "" )
	BlockMapEntityParseCreationOf( "prop_dynamic", "", "script_loot_marvin" )
	//

	AddSpawnCallbackEditorClass( "script_ref", "info_freedm_map_location", MapNode_OnSpawn )
	AddSpawnCallbackEditorClass( "func_brush", "func_brush_arenas_start_zone", TurnOffArenaWalls )
	AddCallback_EntitiesDidLoad( EntitiesDidLoad )
}

void function MapNode_ResetAvailableAirDropLocations()
{
	if ( file.currentMapID in file.mapNodeTable &&  file.mapNodeTable[file.currentMapID].airdropPoints.len() > 0 )
	{
		file.mapNodeTable[file.currentMapID].availableAirdropPoints.clear()
		foreach ( point in file.mapNodeTable[file.currentMapID].airdropPoints )
		{
			file.mapNodeTable[file.currentMapID].availableAirdropPoints.append( point )
		}
	}
}

void function MapNode_OnSpawn( entity mapNode )
{
	string mapID = UniqueString()

	if( mapNode.HasKey( "map_id" ) )
	{
		string id = expect string( mapNode.kv.map_id )
		if( id != "" )
			mapID = id
	}

	printf( "[FreeDM] FreeDM_OnMapNodeSpawned: %s", mapID )

	MapNode_MapData mapData
	mapData.node = mapNode
	mapData = MapNode_GatherLinks( mapData, true )

	file.mapNodeTable[ mapID ] <- mapData
	file.allMapIDs.append( mapID )

	MapNode_ResetAvailableAirDropLocations()
}

// Linked entities can spawn after the location node, so links are gathered
// again once every entity has loaded.
array<entity> function MapNode_GetLinkedEnts( entity mapNode )
{
	array<entity> linked = mapNode.GetLinkEntArray()
	if ( linked.len() > 0 )
		return linked

	array<string> guids
	for ( int i = 0; i < 256; i++ )
	{
		string key = "link_to_guid_" + i
		if ( !mapNode.HasKey( key ) )
			break
		guids.append( mapNode.GetValueForKey( key ).tolower() )
	}
	if ( guids.len() == 0 )
		return linked

	array<entity> candidates = GetEntArrayByClass_Expensive( "info_spawnpoint_human" )
	candidates.extend( GetEntArrayByClass_Expensive( "info_spawnpoint_human_start" ) )
	candidates.extend( GetEntArrayByClass_Expensive( "script_ref" ) )
	foreach ( entity ent in candidates )
	{
		if ( !ent.HasKey( "link_guid" ) )
			continue
		if ( guids.contains( ent.GetValueForKey( "link_guid" ).tolower() ) )
			linked.append( ent )
	}
	return linked
}

MapNode_MapData function MapNode_GatherLinks( MapNode_MapData mapData, bool atSpawn )
{
	entity mapNode = mapData.node
	if ( !IsValid( mapNode ) )
		return mapData

	mapData.spawnPoints.clear()
	mapData.airdropPoints.clear()
	mapData.introCameras.clear()

	array<entity> linked = atSpawn ? mapNode.GetLinkEntArray() : MapNode_GetLinkedEnts( mapNode )
	foreach( childNode in linked )
	{
		if ( !IsValid( childNode ) )
			continue

		string classname = childNode.GetClassName()
		if( classname == "info_spawnpoint_human" || classname == "info_spawnpoint_human_start" )
			mapData.spawnPoints.append( childNode )

		string editorClass = GetEditorClass( childNode )
		if ( editorClass == "info_freedm_airdrop_location" )
		{
			mapData.airdropPoints.append( childNode )
			if ( atSpawn )
				CreateNonExpiringAirdropBadPlace( childNode.GetOrigin(), AIR_DROP_BAD_PLACE_RADIUS )
		}

		if( editorClass == "info_freedm_intro_camera" )
		{
			Point introCamera
			introCamera.origin = childNode.GetOrigin()
			introCamera.angles = childNode.GetAngles()
			mapData.introCameras.append( introCamera )
		}
	}

	// Only use default camera as a last resort. It's not a great option, so don't always add it
	if( mapData.introCameras.len() == 0 )
	{
		vector locationOrigin = mapNode.GetOrigin()
		Point defaultCamera
		defaultCamera.origin = locationOrigin + <250, 0, 2000>
		defaultCamera.angles = VectorToAngles( locationOrigin - defaultCamera.origin )
		mapData.introCameras.append( defaultCamera )
	}

	mapData.availableAirdropPoints.clear()
	mapData.availableAirdropPoints.extend( mapData.airdropPoints )
	return mapData
}

void function TurnOffArenaWalls( entity wall )
{
	if ( GetEditorClass( wall ) == "func_brush_arenas_start_zone" )
		FS_ArenaWalls_Drop( wall )
}

void function EntitiesDidLoad()
{
	InitMapLocation()
}

void function InitMapLocation()
{
	if( file.mapNodeTable.len() == 0 || file.allMapIDs.len() == 0 )
		return

	// Ignore disabled locations and use any forced location. Otherwise random
	string disabledMapsVar = GetCurrentPlaylistVarString( "freedm_disabled_locations", "" ).tolower()
	array<string> disabledMapList = split( disabledMapsVar, WHITESPACE_CHARACTERS )
	for( int i = file.allMapIDs.len() - 1; i >= 0; --i )
	{
		if( disabledMapList.contains( file.allMapIDs[i].tolower() ) )
			file.allMapIDs.remove( i )
	}

	string mapID = ""

	if( file.allMapIDs.len() > 0 )
		mapID = file.allMapIDs.getrandom()
	else
	{
		Warning( "[FreeDM] InitMapLocation - No map locations found!" )
		// Bail so that we don't delete all spawn points and attempt to still play on this map
		return
	}

	string forcedMapsVar = GetCurrentPlaylistVarString( "freedm_forced_location", "" ).tolower()
	if( file.allMapIDs.contains( forcedMapsVar ) )
		mapID = forcedMapsVar
	else if( forcedMapsVar != "" )
		printf( "[FreeDM] Forced location (%s) not found!  Falling back to (%s)", forcedMapsVar, mapID )

	file.currentMapID = mapID
	MapNode_MapData mapData = file.mapNodeTable[ mapID ]
	if ( mapData.spawnPoints.len() == 0 )
	{
		mapData = MapNode_GatherLinks( mapData, false )
		file.mapNodeTable[ mapID ] = mapData
	}
	printf( "[FreeDM] Map location %s: %d spawn points, %d intro cameras", mapID, mapData.spawnPoints.len(), mapData.introCameras.len() )

	// Never strip the map down to nothing: keep every spawn when the location links none.
	if ( mapData.spawnPoints.len() == 0 )
	{
		Warning( "[FreeDM] Map location " + mapID + " links no spawn points -- keeping all map spawns" )
		return
	}

	// Remove all spawn points across the whole map that are not related to this location
	RemoveAllOtherSpawnpoints( mapData.spawnPoints )
}

void function SetupFuncBrushWall( entity wall )
{
	wall.kv.contents = CONTENTS_SOLID | CONTENTS_NOGRAPPLE | CONTENTS_NOCLIMB
	if ( !GetCurrentPlaylistVarBool( "freedm_wall_sticky_ents", false ) )
		wall.e.preventStickyEnts = true
}

bool function MapNode_IsMapDataValid()
{
	return file.currentMapID in file.mapNodeTable
}

array<entity> function MapNode_GetAirdropLocations( )
{
	return file.mapNodeTable[file.currentMapID].airdropPoints
}

array<entity> function MapNode_GetAvailableAirdropLocations( )
{
	return file.mapNodeTable[file.currentMapID].availableAirdropPoints
}

entity function MapNode_TakeAvailableAirdropLocation()
{
	int randomDropLocation = RandomInt( file.mapNodeTable[file.currentMapID].availableAirdropPoints.len() )
	entity airdrop = file.mapNodeTable[file.currentMapID].availableAirdropPoints[randomDropLocation]
	file.mapNodeTable[file.currentMapID].availableAirdropPoints.remove(randomDropLocation)

	return airdrop
}

array<Point> function MapNode_GetIntroCameraPoints( )
{
	return file.mapNodeTable[file.currentMapID].introCameras
}
#endif // SERVER