// Map editor server: placement registry, budgets, saved layouts, and the client-command surface.

global function MapEditor_ServerInit
global function MapEditor_GetPropCount
global function MapEditor_GetPlayerPropCount
global function MapEdit_Report
global function MapEdit_Reject
global function MapEdit_IsFiniteCoord
global function MapEdit_NormalizeAngle360
global function MapEditor_IsFrozenFor
global function MapEdit_ParsePlacementArgs
global function MapEdit_TryPlaceFromClient
global function MapEdit_SV_PackReady
global function MapEdit_SV_RequestModel
global function MapEdit_PackFromConsole
global function MapEdit_IsIntToken
global function MapEdit_IsFloatToken

// Server-side freeze flag; read only via MapEditor_IsFrozenFor outside this file.
global bool g_MapEditFrozen = false

struct MapEditGroup
{
	MapEditPlacement desc
	array< entity >  ents
	entity           owner
	string           ownerId
	float            placeTime
}

struct
{
	table< int, MapEditGroup > groups
	table< entity, int > groupByEnt
	int nextGroupId = 1
	int entityCount = 0

	table< entity, array< float > > placeTimes
	table< entity, array< int > > undoStack
	table< entity, array< MapEditPlacement > > redoStack
	table< entity, bool > buildOn

	table< entity, bool > saveDirty
	table< entity, bool > restoring
	table< entity, bool > restoreChecked
	table< entity, float > lastSaveCmd
	// Saved lines this map cannot spawn (model not loaded); written back so a save never loses them.
	table< entity, array< string > > carryLines

	table< int, bool > precachedIds
	int lazyPrecached = 0
	bool lazyBudgetWarned = false
	// platform uid -> lazy precaches that player caused this map
	table< string, int > lazyPrecachedBy
	// player -> recent model request times, for the rate cap
	table< entity, array< float > > modelRequests
	int activePackMask = 0
	bool netRegistered = false
} file

void function MapEditor_ServerInit()
{
	MapEdit_RegisterNetworking()
	AddCallback_OnClientConnected( MapEdit_OnClientConnected )

	if ( !MapEditor_IsEnabled() )
		return

	PrecacheWeapon( MAPEDIT_TOOL_WEAPON )
	Bleedout_AddCallback_CleanupUtilitySlot( MapEdit_CleanupUtilitySlot )
	MapEditorCatalog_Init()

	string mapName = GetMapName()
	array< MapEditorCatalogEntry > available = MapEdit_CollectMapAvailableOrdered( mapName )
	int availableCount = available.len()
	int attempted = 0
	int verified = 0
	file.precachedIds = {}
	file.lazyPrecached = 0
	file.lazyPrecachedBy = {}
	file.activePackMask = 0
	MapEditorCatalog_SetActivePackMask( 0 )

	foreach ( MapEditorCatalogEntry entry in available )
	{
		if ( attempted >= MAPEDIT_PRECACHE_MAX )
			break

		PrecacheModel( entry.model )
		attempted++

		if ( ModelIsPrecached( entry.model ) )
		{
			file.precachedIds[ entry.id ] <- true
			verified++
		}
	}

	// Sizes and collision come from studio data, so every model the browser lists gets them.
	array< int > infoIds
	foreach ( MapEditorCatalogEntry entry in available )
		infoIds.append( entry.id )
	MapEditInfo_Add( infoIds )

	printt( format( "[MAPEDIT] server precache map=%s available=%d attempted=%d verified=%d cap=%d",
		mapName, availableCount, attempted, verified, MAPEDIT_PRECACHE_MAX ) )
	if ( attempted > 0 && verified * 2 < attempted )
		printt( format( "[MAPEDIT] server precache WARNING: verified %d is far below attempted %d",
			verified, attempted ) )

	AddClientCommandCallback( "mapedit_place", ClientCommand_MapEdit_Place )
	AddClientCommandCallback( "mapedit_delete", ClientCommand_MapEdit_Delete )
	AddClientCommandCallback( "mapedit_undo", ClientCommand_MapEdit_Undo )
	AddClientCommandCallback( "mapedit_redo", ClientCommand_MapEdit_Redo )
	AddClientCommandCallback( "mapedit_status", ClientCommand_MapEdit_Status )
	AddClientCommandCallback( "mapedit_whois", ClientCommand_MapEdit_Whois )
	AddClientCommandCallback( "mapedit_clear_mine", ClientCommand_MapEdit_ClearMine )
	AddClientCommandCallback( "mapedit_build", ClientCommand_MapEdit_Build )
	AddClientCommandCallback( "mapedit_save", ClientCommand_MapEdit_Save )
	AddClientCommandCallback( "mapedit_load", ClientCommand_MapEdit_Load )
	AddClientCommandCallback( "mapedit_slots", ClientCommand_MapEdit_Slots )
	// Admin-gated powers (same IsAdmin gate as the rest of this tree).
	AddClientCommandCallback( "mapedit_freeze", ClientCommand_MapEdit_Freeze )
	AddClientCommandCallback( "mapedit_clear_player", ClientCommand_MapEdit_ClearPlayer )
	AddClientCommandCallback( "mapedit_clear_all", ClientCommand_MapEdit_ClearAll )
	AddClientCommandCallback( "mapedit_legends", ClientCommand_MapEdit_Legends )
	AddClientCommandCallback( "mapedit_legend", ClientCommand_MapEdit_Legend )
	AddClientCommandCallback( "mapedit_pack", ClientCommand_MapEdit_Pack )

	AddCallback_OnClientDisconnected( MapEditor_OnClientDisconnected )
	AddCallback_OnPlayerRespawned( MapEdit_OnPlayerRespawned )

	MapEditor_Palette_ServerInit()
	MapEditPrefs_ServerInit()

	printt( format( "[MAPEDIT] server init, catalog=%d entries, cap=%d/%d",
		MapEditorCatalog_Count(), MAPEDIT_PROP_CAP_GLOBAL, MAPEDIT_PROP_CAP_PLAYER ) )
}

// Map-available catalog entries: all build-tier by id, then extra-tier by id.
array< MapEditorCatalogEntry > function MapEdit_CollectMapAvailableOrdered( string mapName )
{
	array< MapEditorCatalogEntry > buildList
	array< MapEditorCatalogEntry > extraList

	foreach ( string category in MapEditorCatalog_GetCategoriesByTier( "build" ) )
	{
		foreach ( MapEditorCatalogEntry entry in MapEditorCatalog_GetAvailableCategoryEntries( category, mapName ) )
			buildList.append( entry )
	}

	foreach ( string category in MapEditorCatalog_GetCategoriesByTier( "extra" ) )
	{
		foreach ( MapEditorCatalogEntry entry in MapEditorCatalog_GetAvailableCategoryEntries( category, mapName ) )
			extraList.append( entry )
	}

	buildList.sort( MapEdit_CompareCatalogId )
	extraList.sort( MapEdit_CompareCatalogId )

	array< MapEditorCatalogEntry > result
	foreach ( MapEditorCatalogEntry entry in buildList )
		result.append( entry )
	foreach ( MapEditorCatalogEntry entry in extraList )
		result.append( entry )

	return result
}

int function MapEdit_CompareCatalogId( MapEditorCatalogEntry a, MapEditorCatalogEntry b )
{
	if ( a.id < b.id )
		return -1
	if ( a.id > b.id )
		return 1
	return 0
}

int function MapEditor_GetPropCount()
{
	return file.entityCount
}

int function MapEditor_GetPlayerPropCount( entity player )
{
	if ( !IsValid( player ) )
		return 0

	int n = 0
	foreach ( int groupId, MapEditGroup group in file.groups )
	{
		if ( MapEdit_IsOwner( group, player ) )
			n += group.ents.len()
	}
	return n
}

void function MapEditor_OnClientDisconnected( entity player )
{
	if ( player in file.modelRequests )
		delete file.modelRequests[player]
	// The only hook guaranteed to run for a leaving player.
	if ( player in file.saveDirty && file.saveDirty[player] )
		MapEdit_WriteSlot( player, "auto" )

	if ( player in file.buildOn )
		delete file.buildOn[player]
	if ( player in file.placeTimes )
		delete file.placeTimes[player]
	if ( player in file.undoStack )
		delete file.undoStack[player]
	if ( player in file.redoStack )
		delete file.redoStack[player]
	if ( player in file.saveDirty )
		delete file.saveDirty[player]
	if ( player in file.restoring )
		delete file.restoring[player]
	if ( player in file.restoreChecked )
		delete file.restoreChecked[player]
	if ( player in file.lastSaveCmd )
		delete file.lastSaveCmd[player]
	if ( player in file.carryLines )
		delete file.carryLines[player]
	MapEditPrefs_OnDisconnect( player )
	MapEditInfo_OnDisconnect( player )
}

// ---------------------------------------------------------------------------
// Client feedback + reject logging
// ---------------------------------------------------------------------------

void function MapEdit_Report( entity player, string msg )
{
	printt( "[MAPEDIT] " + msg )
	if ( IsValid( player ) )
		SendHudMessage( player, "[MAPEDIT] " + msg, -1, 0.35, 255, 200, 100, 255, 0.1, 3.0, 0.5 )
}

void function MapEdit_Reject( entity player, string reason )
{
	string who = IsValid( player ) ? player.GetPlayerName() : "null"
	printt( "[MAPEDIT] reject " + who + ": " + reason )
	if ( IsValid( player ) )
		SendHudMessage( player, "[MAPEDIT] " + reason, -1, 0.35, 255, 120, 80, 255, 0.1, 3.5, 0.5 )
}

// ---------------------------------------------------------------------------
// Numeric parsing -- validate before converting; tointeger/tofloat throw on garbage.
// ---------------------------------------------------------------------------

bool function MapEdit_IsIntToken( string s )
{
	int n = s.len()
	int start = ( n > 0 && s[0] == '-' ) ? 1 : 0
	if ( n - start < 1 || n - start > 9 )
		return false
	for ( int i = start; i < n; i++ )
	{
		if ( s[i] < '0' || s[i] > '9' )
			return false
	}
	return true
}

bool function MapEdit_IsFloatToken( string s )
{
	int n = s.len()
	if ( n < 1 || n > 24 )
		return false
	int start = ( s[0] == '-' ) ? 1 : 0
	bool dot = false
	int digits = 0
	for ( int i = start; i < n; i++ )
	{
		if ( s[i] == '.' )
		{
			if ( dot )
				return false
			dot = true
		}
		else if ( s[i] >= '0' && s[i] <= '9' )
		{
			digits++
		}
		else
		{
			return false
		}
	}
	return digits > 0
}

bool function MapEdit_IsFiniteCoord( float v )
{
	// NaN is the only float that is not equal to itself.
	if ( v != v )
		return false
	if ( fabs( v ) > MAPEDIT_WORLD_LIMIT )
		return false
	return true
}

float function MapEdit_NormalizeAngle360( float a )
{
	if ( a != a || fabs( a ) > MAPEDIT_ANGLE_LIMIT )
		return 0.0
	a = a % 360.0
	if ( a < 0.0 )
		a += 360.0
	return a
}

// Reads <id> <x> <y> <z> [<pitch> <yaw> <roll>] starting at args[first].
bool function MapEdit_ReadIdTransform( array< string > args, int first, MapEditPlacement desc )
{
	if ( args.len() != first + 7 )
		return false
	if ( !MapEdit_IsIntToken( args[first] ) )
		return false
	for ( int i = first + 1; i < first + 7; i++ )
	{
		if ( !MapEdit_IsFloatToken( args[i] ) )
			return false
	}

	desc.id = args[first].tointeger()
	desc.origin = < args[first + 1].tofloat(), args[first + 2].tofloat(), args[first + 3].tofloat() >
	desc.angles = < MapEdit_NormalizeAngle360( args[first + 4].tofloat() ),
		MapEdit_NormalizeAngle360( args[first + 5].tofloat() ),
		MapEdit_NormalizeAngle360( args[first + 6].tofloat() ) >
	return true
}

bool function MapEdit_ParsePlacementArgs( entity player, array< string > args, MapEditPlacement desc )
{
	if ( !MapEdit_ReadIdTransform( args, 0, desc ) )
	{
		MapEdit_Reject( player, "place needs <id> <x> <y> <z> <pitch> <yaw> <roll>" )
		return false
	}
	return true
}

bool function MapEdit_IsOwner( MapEditGroup group, entity player )
{
	if ( !IsValid( player ) )
		return false
	if ( IsValid( group.owner ) )
		return group.owner == player
	return group.ownerId != "" && group.ownerId == player.GetPlatformUID()
}

bool function MapEditor_IsFrozenFor( entity player )
{
	if ( !g_MapEditFrozen )
		return false
	if ( IsValid( player ) && IsAdmin( player ) )
		return false
	return true
}

// ---------------------------------------------------------------------------
// Placement validation + spawn. Every path -- client place, redo, restore --
// goes through MapEdit_ValidatePlacement and MapEdit_SpawnGroup.
// ---------------------------------------------------------------------------

// Returns "" when valid. Says nothing about the caller's reach or rate.
string function MapEdit_ValidatePlacement( MapEditPlacement desc, entity requester = null )
{
	if ( !MapEdit_IsFiniteCoord( desc.origin.x ) || !MapEdit_IsFiniteCoord( desc.origin.y ) || !MapEdit_IsFiniteCoord( desc.origin.z ) )
		return "origin not finite or out of world limit"

	if ( desc.kind == eMapEditKind.PROP )
	{
		MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( desc.id )
		if ( entryOrNull == null )
			return "unknown catalog id " + string( desc.id )
		MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
		if ( !MapEdit_EnsureModelPrecached( entry, requester ) )
			return format( "model not loaded for catalog id %d", desc.id )
		return ""
	}

	if ( desc.kind == eMapEditKind.SPECIAL )
	{
		if ( desc.id < 1 || desc.id > 5 )
			return "unknown recipe " + string( desc.id )
		return ""
	}

	if ( desc.kind == eMapEditKind.ZIPLINE )
	{
		if ( !MapEdit_IsFiniteCoord( desc.endOrigin.x ) || !MapEdit_IsFiniteCoord( desc.endOrigin.y ) || !MapEdit_IsFiniteCoord( desc.endOrigin.z ) )
			return "zipline end not finite"
		float dist = Distance( desc.origin, desc.endOrigin )
		if ( dist < 64.0 || dist > MAPEDIT_ZIPLINE_MAX_DIST )
			return "zipline length out of range"
		return ""
	}

	return "unknown placement kind"
}

string function MapEdit_CheckBudget( entity player )
{
	if ( file.entityCount >= MAPEDIT_PROP_CAP_GLOBAL )
		return format( "global prop cap %d reached", MAPEDIT_PROP_CAP_GLOBAL )
	if ( MapEditor_GetPlayerPropCount( player ) >= MAPEDIT_PROP_CAP_PLAYER )
		return format( "player prop cap %d reached", MAPEDIT_PROP_CAP_PLAYER )
	return ""
}

// Spawns and registers one placement. Returns the group id, or -1 with *err set.
int function MapEdit_SpawnGroup( entity player, MapEditPlacement desc, array< string > err )
{
	string budget = MapEdit_CheckBudget( player )
	if ( budget != "" )
	{
		err.append( budget )
		return -1
	}

	array< entity > ents
	bool ok = false
	if ( desc.kind == eMapEditKind.PROP )
	{
		MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( MapEditorCatalog_GetEntry( desc.id ) )
		entity prop = CreatePropDynamic( entry.model, desc.origin, desc.angles, SOLID_VPHYSICS, -1.0 )
		if ( IsValid( prop ) )
		{
			prop.SetScriptName( "mapedit_prop" )
			prop.AllowMantle()
			ents.append( prop )
			ok = true
		}
	}
	else if ( desc.kind == eMapEditKind.SPECIAL )
	{
		ok = MapEditPalette_SpawnSpecial( desc.id, desc.origin, desc.angles, ents )
	}
	else if ( desc.kind == eMapEditKind.ZIPLINE )
	{
		ok = MapEditPalette_SpawnZipline( desc.origin, desc.endOrigin, ents )
	}

	if ( !ok || ents.len() == 0 )
	{
		foreach ( entity e in ents )
		{
			if ( IsValid( e ) )
				e.Destroy()
		}
		err.append( "spawn failed" )
		return -1
	}

	MapEditGroup group
	group.desc.kind = desc.kind
	group.desc.id = desc.id
	group.desc.origin = desc.origin
	group.desc.angles = desc.angles
	group.desc.endOrigin = desc.endOrigin
	group.ents = ents
	group.owner = player
	group.ownerId = player.GetPlatformUID()
	group.placeTime = Time()

	int groupId = file.nextGroupId++
	file.groups[groupId] <- group
	foreach ( entity e in ents )
		file.groupByEnt[e] <- groupId
	file.entityCount += ents.len()

	return groupId
}

void function MapEdit_DestroyGroup( int groupId )
{
	if ( !( groupId in file.groups ) )
		return

	MapEditGroup group = file.groups[groupId]
	delete file.groups[groupId]

	foreach ( entity e in group.ents )
	{
		if ( e in file.groupByEnt )
			delete file.groupByEnt[e]
		if ( IsValid( e ) )
			e.Destroy()
	}
	file.entityCount -= group.ents.len()
	if ( file.entityCount < 0 )
		file.entityCount = 0
}

void function MapEdit_PushUndo( entity player, int groupId )
{
	if ( !( player in file.undoStack ) )
		file.undoStack[player] <- []

	array< int > stack = file.undoStack[player]
	stack.append( groupId )
	while ( stack.len() > MAPEDIT_UNDO_DEPTH )
		stack.remove( 0 )
}

void function MapEdit_PushRedo( entity player, MapEditPlacement desc )
{
	if ( !( player in file.redoStack ) )
		file.redoStack[player] <- []

	array< MapEditPlacement > stack = file.redoStack[player]
	stack.append( desc )
	while ( stack.len() > MAPEDIT_UNDO_DEPTH )
		stack.remove( 0 )
}

void function MapEdit_ClearPlayerStacks( entity player )
{
	if ( player in file.undoStack )
		file.undoStack[player].clear()
	if ( player in file.redoStack )
		file.redoStack[player].clear()
}

// Sliding-window rate limit; stamp only after a successful spawn.
bool function MapEdit_RateAllows( entity player )
{
	float now = Time()
	if ( !( player in file.placeTimes ) )
		file.placeTimes[player] <- []

	array< float > window = file.placeTimes[player]
	while ( window.len() > 0 && ( now - window[0] ) > MAPEDIT_PLACE_RATE_WINDOW )
		window.remove( 0 )

	return window.len() < MAPEDIT_PLACE_RATE_MAX
}

void function MapEdit_RateStamp( entity player )
{
	if ( player in file.placeTimes )
		file.placeTimes[player].append( Time() )
}

// Client-driven placement: reach, rate, freeze, validation, budget.
bool function MapEdit_TryPlaceFromClient( entity player, MapEditPlacement desc, bool clearRedo = true )
{
	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "placement frozen by admin" )
		return false
	}

	if ( player in file.restoring && file.restoring[player] )
	{
		MapEdit_Reject( player, "layout still loading" )
		return false
	}

	vector eye = player.EyePosition()
	if ( Distance( eye, desc.origin ) > MAPEDIT_MAX_PLACE_DIST ||
		( desc.kind == eMapEditKind.ZIPLINE && Distance( eye, desc.endOrigin ) > MAPEDIT_MAX_PLACE_DIST ) )
	{
		MapEdit_Reject( player, format( "too far from you (max %.0f)", MAPEDIT_MAX_PLACE_DIST ) )
		return false
	}

	if ( !MapEdit_RateAllows( player ) )
	{
		MapEdit_Reject( player, format( "place rate limit %d / %.1fs", MAPEDIT_PLACE_RATE_MAX, MAPEDIT_PLACE_RATE_WINDOW ) )
		return false
	}

	// Validation can spend the map's lazy precache budget, so it runs after the reach and rate gates.
	string invalid = MapEdit_ValidatePlacement( desc, player )
	if ( invalid != "" )
	{
		MapEdit_Reject( player, invalid )
		return false
	}

	array< string > err
	int groupId = MapEdit_SpawnGroup( player, desc, err )
	if ( groupId < 0 )
	{
		MapEdit_Reject( player, err.len() > 0 ? err[0] : "spawn failed" )
		return false
	}

	MapEdit_RateStamp( player )
	MapEdit_PushUndo( player, groupId )
	if ( clearRedo && player in file.redoStack )
		file.redoStack[player].clear()
	MapEdit_MarkDirty( player )
	return true
}

// ---------------------------------------------------------------------------
// mapedit_place <catalogId> <x> <y> <z> <pitch> <yaw> <roll>
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Place( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	MapEditPlacement desc
	desc.kind = eMapEditKind.PROP
	if ( !MapEdit_ParsePlacementArgs( player, args, desc ) )
		return

	MapEdit_TryPlaceFromClient( player, desc )
}

// ---------------------------------------------------------------------------
// mapedit_delete -- re-trace from eye, registry-authorised remove of the whole group
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Delete( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "delete frozen by admin" )
		return
	}

	vector eye = player.EyePosition()
	TraceResults tr = TraceLine( eye, eye + player.GetViewVector() * MAPEDIT_MAX_PLACE_DIST, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	if ( !IsValid( tr.hitEnt ) || !( tr.hitEnt in file.groupByEnt ) )
	{
		MapEdit_Reject( player, "delete: not an editor prop" )
		return
	}

	int groupId = file.groupByEnt[tr.hitEnt]
	MapEditGroup group = file.groups[groupId]
	if ( !MapEdit_IsOwner( group, player ) )
	{
		MapEdit_Reject( player, "delete: you do not own this prop" )
		return
	}

	MapEdit_PushRedo( player, group.desc )
	MapEdit_DestroyGroup( groupId )
	MapEdit_MarkDirty( player )
	MapEdit_Report( player, format( "deleted (you %d/%d)", MapEditor_GetPlayerPropCount( player ), MAPEDIT_PROP_CAP_PLAYER ) )
}

// ---------------------------------------------------------------------------
// mapedit_undo / mapedit_redo
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Undo( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "undo frozen by admin" )
		return
	}

	if ( !( player in file.undoStack ) )
	{
		MapEdit_Reject( player, "undo: nothing to undo" )
		return
	}

	// Skip groups already removed by delete / clear.
	array< int > stack = file.undoStack[player]
	while ( stack.len() > 0 )
	{
		int groupId = stack[stack.len() - 1]
		stack.remove( stack.len() - 1 )
		if ( !( groupId in file.groups ) )
			continue

		MapEditGroup group = file.groups[groupId]
		if ( !MapEdit_IsOwner( group, player ) )
			continue

		MapEdit_PushRedo( player, group.desc )
		MapEdit_DestroyGroup( groupId )
		MapEdit_MarkDirty( player )
		MapEdit_Report( player, format( "undo (you %d/%d)", MapEditor_GetPlayerPropCount( player ), MAPEDIT_PROP_CAP_PLAYER ) )
		return
	}

	MapEdit_Reject( player, "undo: nothing to undo" )
}

void function ClientCommand_MapEdit_Redo( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !( player in file.redoStack ) || file.redoStack[player].len() == 0 )
	{
		MapEdit_Reject( player, "redo: nothing to redo" )
		return
	}

	array< MapEditPlacement > stack = file.redoStack[player]
	MapEditPlacement desc = stack[stack.len() - 1]
	stack.remove( stack.len() - 1 )
	if ( !MapEdit_TryPlaceFromClient( player, desc, false ) )
		stack.append( desc )
}

// ---------------------------------------------------------------------------
// mapedit_whois / mapedit_status
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Whois( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	vector eye = player.EyePosition()
	TraceResults tr = TraceLine( eye, eye + player.GetViewVector() * MAPEDIT_MAX_PLACE_DIST, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	if ( !IsValid( tr.hitEnt ) || !( tr.hitEnt in file.groupByEnt ) )
	{
		MapEdit_Report( player, "whois: not an editor prop" )
		return
	}

	MapEditGroup group = file.groups[ file.groupByEnt[tr.hitEnt] ]
	string name = ""
	if ( IsValid( group.owner ) )
	{
		name = group.owner.GetPlayerName()
	}
	else
	{
		foreach ( entity p in GetPlayerArray() )
		{
			if ( IsValid( p ) && p.GetPlatformUID() == group.ownerId )
			{
				name = p.GetPlayerName()
				break
			}
		}
	}

	if ( name == "" )
		MapEdit_Report( player, format( "whois: owner left (kind %d, id %d)", group.desc.kind, group.desc.id ) )
	else
		MapEdit_Report( player, format( "whois: %s (kind %d, id %d)", name, group.desc.kind, group.desc.id ) )
}

void function ClientCommand_MapEdit_Status( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	int undoLen = ( player in file.undoStack ) ? file.undoStack[player].len() : 0
	int redoLen = ( player in file.redoStack ) ? file.redoStack[player].len() : 0

	MapEdit_Report( player, format( "status: you=%d/%d global=%d/%d undo=%d redo=%d freeze=%d packs=%s",
		MapEditor_GetPlayerPropCount( player ), MAPEDIT_PROP_CAP_PLAYER, file.entityCount, MAPEDIT_PROP_CAP_GLOBAL,
		undoLen, redoLen, g_MapEditFrozen ? 1 : 0, MapEdit_ActivePackNames() ) )
}

// ---------------------------------------------------------------------------
// Clears
// ---------------------------------------------------------------------------

array< int > function MapEdit_GroupsOwnedBy( entity player )
{
	array< int > ids
	foreach ( int groupId, MapEditGroup group in file.groups )
	{
		if ( MapEdit_IsOwner( group, player ) )
			ids.append( groupId )
	}
	return ids
}

int function MapEdit_ClearOwned( entity player )
{
	array< int > ids = MapEdit_GroupsOwnedBy( player )
	foreach ( int groupId in ids )
		MapEdit_DestroyGroup( groupId )
	MapEdit_ClearPlayerStacks( player )
	return ids.len()
}

void function ClientCommand_MapEdit_ClearMine( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( player in file.restoring && file.restoring[player] )
		return

	int n = MapEdit_ClearOwned( player )
	MapEdit_MarkDirty( player )
	MapEdit_Report( player, format( "clear_mine: removed %d (global %d)", n, file.entityCount ) )
}

// ---------------------------------------------------------------------------
// Build mode is holding the editor tool, a weapon that never fires. Tactical,
// ultimate, fists and guns stay one key away, and switching to any of them
// leaves build mode on the client.
// ---------------------------------------------------------------------------

void function MapEdit_SetBuildWeapons( entity player, bool on )
{
	file.buildOn[player] <- on
	if ( !IsAlive( player ) )
		return

	if ( on )
	{
		MapEdit_EquipTool( player )
		return
	}

	entity active = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( !IsValid( active ) || active.GetWeaponClassName() != MAPEDIT_TOOL_WEAPON )
		return
	entity latest = player.GetLatestPrimaryWeapon( eActiveInventorySlot.mainHand )
	if ( IsValid( latest ) && latest != active )
	{
		player.SetActiveWeaponByName( eActiveInventorySlot.mainHand, latest.GetWeaponClassName() )
		return
	}
	foreach ( int slot in [ WEAPON_INVENTORY_SLOT_PRIMARY_0, WEAPON_INVENTORY_SLOT_PRIMARY_1, SLING_WEAPON_SLOT ] )
	{
		if ( IsValid( player.GetNormalWeapon( slot ) ) )
		{
			player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, slot )
			return
		}
	}
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_2 )
}

// The utility slot also holds the knockdown shield, so the tool never replaces
// a different weapon there.
void function MapEdit_EquipTool( entity player )
{
	entity tool = player.GetNormalWeapon( MAPEDIT_TOOL_SLOT )
	if ( !IsValid( tool ) )
		tool = player.GiveWeapon( MAPEDIT_TOOL_WEAPON, MAPEDIT_TOOL_SLOT, [] )
	if ( !IsValid( tool ) || tool.GetWeaponClassName() != MAPEDIT_TOOL_WEAPON )
		return
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, MAPEDIT_TOOL_SLOT )
}

// Bleedout puts the knockdown shield in the utility slot.
void function MapEdit_CleanupUtilitySlot( entity player )
{
	entity tool = player.GetNormalWeapon( MAPEDIT_TOOL_SLOT )
	if ( IsValid( tool ) && tool.GetWeaponClassName() == MAPEDIT_TOOL_WEAPON )
		player.TakeWeaponByEntNow( tool )
}

void function ClientCommand_MapEdit_Build( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( args.len() != 1 || ( args[0] != "0" && args[0] != "1" ) )
		return

	bool on = args[0] == "1"
	MapEdit_SetBuildWeapons( player, on )

	if ( !on && player in file.saveDirty && file.saveDirty[player] )
		MapEdit_WriteSlot( player, "auto" )
}

// A respawn hands out a fresh loadout, so a builder gets the tool back in hand.
void function MapEdit_OnPlayerRespawned( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( player in file.buildOn && file.buildOn[player] )
		MapEdit_EquipTool( player )

	if ( !player.IsBot() && !( player in file.restoreChecked ) )
	{
		file.restoreChecked[player] <- true
		if ( MapEdit_GroupsOwnedBy( player ).len() == 0 )
			thread MapEdit_RestoreThread( player, "auto", false )
	}
}

// ---------------------------------------------------------------------------
// Saved layouts -- per player (identity from the prefs store), per map.
// Format: "v=1", "map=<name>", then one placement per line:
//   p <catalogId> x y z pitch yaw roll
//   s <recipeId>  x y z pitch yaw roll
//   z x y z ex ey ez
// ---------------------------------------------------------------------------

bool function MapEdit_IsSlotName( string slot )
{
	if ( slot == "auto" )
		return true
	if ( !MapEdit_IsIntToken( slot ) || slot[0] == '-' )
		return false
	int n = slot.tointeger()
	return n >= 1 && n <= MAPEDIT_SAVE_SLOTS
}

// Store keys cap at 32 chars; long map names fold to a hash.
string function MapEdit_SlotKey( string slot )
{
	string mapName = GetMapName()
	string key = "me_" + mapName + "_" + slot
	if ( key.len() <= 32 )
		return key

	int h = 5381
	for ( int i = 0; i < mapName.len(); i++ )
		h = ( ( h * 33 ) ^ expect int( mapName[i] ) ) & 0x7FFFFFFF
	return format( "me_%08x_%s", h, slot )
}

string function MapEdit_FormatPlacement( MapEditPlacement d )
{
	switch ( d.kind )
	{
		case eMapEditKind.PROP:
			return format( "p %d %.2f %.2f %.2f %.2f %.2f %.2f", d.id, d.origin.x, d.origin.y, d.origin.z, d.angles.x, d.angles.y, d.angles.z )
		case eMapEditKind.SPECIAL:
			return format( "s %d %.2f %.2f %.2f %.2f %.2f %.2f", d.id, d.origin.x, d.origin.y, d.origin.z, d.angles.x, d.angles.y, d.angles.z )
		case eMapEditKind.ZIPLINE:
			return format( "z %.2f %.2f %.2f %.2f %.2f %.2f", d.origin.x, d.origin.y, d.origin.z, d.endOrigin.x, d.endOrigin.y, d.endOrigin.z )
	}
	return ""
}

bool function MapEdit_ParseLine( string line, MapEditPlacement desc )
{
	array< string > tok = split( line, " " )
	if ( tok.len() < 1 )
		return false

	if ( tok[0] == "p" || tok[0] == "s" )
	{
		desc.kind = tok[0] == "p" ? eMapEditKind.PROP : eMapEditKind.SPECIAL
		return MapEdit_ReadIdTransform( tok, 1, desc )
	}

	if ( tok[0] == "z" )
	{
		if ( tok.len() != 7 )
			return false
		for ( int i = 1; i < 7; i++ )
		{
			if ( !MapEdit_IsFloatToken( tok[i] ) )
				return false
		}
		desc.kind = eMapEditKind.ZIPLINE
		desc.origin = < tok[1].tofloat(), tok[2].tofloat(), tok[3].tofloat() >
		desc.endOrigin = < tok[4].tofloat(), tok[5].tofloat(), tok[6].tofloat() >
		return true
	}

	return false
}

string function MapEdit_Serialize( entity player )
{
	string payload = "v=1\nmap=" + GetMapName() + "\n"
	int lines = 0
	foreach ( int groupId, MapEditGroup group in file.groups )
	{
		if ( lines >= MAPEDIT_PROP_CAP_PLAYER )
			break
		if ( !MapEdit_IsOwner( group, player ) )
			continue
		payload += MapEdit_FormatPlacement( group.desc ) + "\n"
		lines++
	}

	if ( player in file.carryLines )
	{
		foreach ( string line in file.carryLines[player] )
		{
			if ( lines >= MAPEDIT_PROP_CAP_PLAYER )
				break
			payload += line + "\n"
			lines++
		}
	}
	return payload
}

bool function MapEdit_WriteSlot( entity player, string slot )
{
	if ( !IsValid( player ) || player.IsBot() )
		return false

	bool ok = player.Cafe_PlayerPrefs_Write( MapEdit_SlotKey( slot ), MapEdit_Serialize( player ) )
	if ( slot == "auto" )
		file.saveDirty[player] <- false
	if ( !ok )
		printt( format( "[MAPEDIT] save failed for %s slot=%s", player.GetPlayerName(), slot ) )
	return ok
}

// Parses a stored layout. Returns false when the blob is missing or not ours.
bool function MapEdit_ReadSlot( entity player, string slot, array< MapEditPlacement > out, array< string > rawOut )
{
	string payload = player.Cafe_PlayerPrefs_Read( MapEdit_SlotKey( slot ) )
	if ( payload == "" )
		return false

	array< string > lines = split( payload, "\n" )
	if ( lines.len() < 2 || strip( lines[0] ) != "v=1" || strip( lines[1] ) != "map=" + GetMapName() )
		return false

	for ( int i = 2; i < lines.len() && out.len() < MAPEDIT_PROP_CAP_PLAYER; i++ )
	{
		string line = strip( lines[i] )
		if ( line.len() == 0 || line.len() > 160 )
			continue

		MapEditPlacement desc
		if ( !MapEdit_ParseLine( line, desc ) )
			continue
		out.append( desc )
		rawOut.append( line )
	}
	return true
}

void function MapEdit_MarkDirty( entity player )
{
	if ( !IsValid( player ) || player.IsBot() )
		return

	bool already = ( player in file.saveDirty ) && file.saveDirty[player]
	file.saveDirty[player] <- true
	if ( !already )
		thread MapEdit_AutosaveThread( player )
}

void function MapEdit_AutosaveThread( entity player )
{
	player.EndSignal( "OnDestroy" )
	wait MAPEDIT_AUTOSAVE_DELAY

	if ( player in file.saveDirty && file.saveDirty[player] )
		MapEdit_WriteSlot( player, "auto" )
}

// Server-origin spawn: validation and budgets apply, reach and rate do not.
void function MapEdit_RestoreThread( entity player, string slot, bool replace )
{
	if ( !IsValid( player ) )
		return
	if ( player in file.restoring && file.restoring[player] )
		return

	array< MapEditPlacement > descs
	array< string > raw
	if ( !MapEdit_ReadSlot( player, slot, descs, raw ) )
	{
		if ( replace )
			MapEdit_Reject( player, "load: slot " + slot + " is empty" )
		return
	}

	file.restoring[player] <- true
	player.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function() : ( player )
		{
			if ( player in file.restoring )
				file.restoring[player] = false
		}
	)

	if ( replace )
		MapEdit_ClearOwned( player )

	array< string > carry
	int placed = 0
	int dropped = 0
	string lastErr = ""
	for ( int i = 0; i < descs.len(); i++ )
	{
		string invalid = MapEdit_ValidatePlacement( descs[i], player )
		if ( invalid != "" )
		{
			// A model this map has not loaded may load on another map or pack; keep it.
			if ( descs[i].kind == eMapEditKind.PROP && MapEditorCatalog_GetEntry( descs[i].id ) != null )
				carry.append( raw[i] )
			else
				dropped++
			continue
		}

		array< string > err
		if ( MapEdit_SpawnGroup( player, descs[i], err ) < 0 )
		{
			lastErr = err.len() > 0 ? err[0] : ""
			carry.append( raw[i] )
			continue
		}

		placed++
		if ( placed % MAPEDIT_RESTORE_PER_FRAME == 0 )
			WaitFrame()
	}

	file.carryLines[player] <- carry
	MapEdit_ClearPlayerStacks( player )

	string msg = format( "loaded %s: %d placed", slot, placed )
	if ( carry.len() > 0 )
		msg += format( ", %d kept for later", carry.len() )
	if ( dropped > 0 )
		msg += format( ", %d invalid", dropped )
	if ( lastErr != "" )
		msg += " (" + lastErr + ")"
	MapEdit_Report( player, msg )
	int slotIndex = slot == "auto" ? 0 : ( MapEdit_IsIntToken( slot ) ? ClampInt( slot.tointeger(), 1, 5 ) : 0 )
	Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_Restored", minint( placed, 4095 ), minint( carry.len(), 4095 ), slotIndex )

	// A manual load becomes the new auto layout.
	if ( replace )
		MapEdit_WriteSlot( player, "auto" )
}

bool function MapEdit_SaveCmdAllowed( entity player )
{
	float now = Time()
	if ( player in file.lastSaveCmd && now - file.lastSaveCmd[player] < MAPEDIT_SAVE_CMD_COOLDOWN )
	{
		MapEdit_Reject( player, "wait a moment before saving or loading again" )
		return false
	}
	file.lastSaveCmd[player] <- now
	return true
}

void function ClientCommand_MapEdit_Save( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return

	if ( args.len() != 1 || !MapEdit_IsSlotName( args[0] ) || args[0] == "auto" )
	{
		MapEdit_Reject( player, format( "save needs a slot 1-%d", MAPEDIT_SAVE_SLOTS ) )
		return
	}

	if ( player in file.restoring && file.restoring[player] )
		return

	if ( !MapEdit_SaveCmdAllowed( player ) )
		return

	if ( MapEdit_WriteSlot( player, args[0] ) )
		MapEdit_Report( player, format( "saved slot %s (%d objects)", args[0], MapEdit_GroupsOwnedBy( player ).len() ) )
	else
		MapEdit_Reject( player, "save failed" )
}

void function ClientCommand_MapEdit_Load( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return

	if ( args.len() != 1 || !MapEdit_IsSlotName( args[0] ) )
	{
		MapEdit_Reject( player, format( "load needs a slot 1-%d or auto", MAPEDIT_SAVE_SLOTS ) )
		return
	}

	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "load frozen by admin" )
		return
	}

	if ( !MapEdit_SaveCmdAllowed( player ) )
		return

	thread MapEdit_RestoreThread( player, args[0], true )
}

void function ClientCommand_MapEdit_Slots( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return

	if ( !MapEdit_SaveCmdAllowed( player ) )
		return

	string msg = "slots:"
	array< string > slots = [ "auto" ]
	for ( int i = 1; i <= MAPEDIT_SAVE_SLOTS; i++ )
		slots.append( string( i ) )

	foreach ( string slot in slots )
	{
		array< MapEditPlacement > descs
		array< string > raw
		if ( MapEdit_ReadSlot( player, slot, descs, raw ) )
			msg += format( " %s=%d", slot, descs.len() )
		else
			msg += format( " %s=-", slot )
	}
	MapEdit_Report( player, msg )
}

// ---------------------------------------------------------------------------
// Admin block -- powers are admin-gated via IsAdmin; no new path to become admin.
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Freeze( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !IsAdmin( player ) )
	{
		MapEdit_Reject( player, "freeze: admin only" )
		return
	}

	if ( args.len() != 1 || ( args[0] != "0" && args[0] != "1" ) )
	{
		MapEdit_Reject( player, "freeze needs <0|1>" )
		return
	}

	g_MapEditFrozen = args[0] == "1"
	MapEdit_Report( player, "freeze=" + args[0] )
}

void function ClientCommand_MapEdit_ClearPlayer( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !IsAdmin( player ) )
	{
		MapEdit_Reject( player, "clear_player: admin only" )
		return
	}

	if ( args.len() < 1 )
	{
		MapEdit_Reject( player, "clear_player needs <playerName>" )
		return
	}

	string targetName = args[0]
	entity target = null
	foreach ( entity p in GetPlayerArray() )
	{
		if ( IsValid( p ) && p.GetPlayerName() == targetName )
		{
			target = p
			break
		}
	}

	if ( !IsValid( target ) )
	{
		MapEdit_Reject( player, "clear_player: no player '" + targetName + "'" )
		return
	}

	int n = MapEdit_ClearOwned( target )
	MapEdit_Report( player, format( "clear_player '%s': removed %d (global %d)", targetName, n, file.entityCount ) )
}

void function ClientCommand_MapEdit_ClearAll( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !IsAdmin( player ) )
	{
		MapEdit_Reject( player, "clear_all: admin only" )
		return
	}

	array< int > ids
	foreach ( int groupId, MapEditGroup group in file.groups )
		ids.append( groupId )
	foreach ( int groupId in ids )
		MapEdit_DestroyGroup( groupId )

	foreach ( entity p in GetPlayerArray() )
	{
		if ( IsValid( p ) )
			MapEdit_ClearPlayerStacks( p )
	}

	MapEdit_Report( player, format( "clear_all: removed %d", ids.len() ) )
}

// ---------------------------------------------------------------------------
// Extra map packs -- admin loads another BR map's props via catalog map bit.
// The client never names a pak; it receives a bit and looks the name up
// in its own catalog copy.
// ---------------------------------------------------------------------------

void function MapEdit_RegisterNetworking()
{
	if ( file.netRegistered )
		return
	file.netRegistered = true

	Remote_RegisterClientFunction( "ServerCallback_MapEdit_PackLoad", "int", 0, 31 )
	Remote_RegisterServerFunction( "MapEdit_SV_PackReady", "int", 0, 31 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_Hotbar", "int", 0, 3, "int", 0, 3, "int", 0, 65536, "vector", -360.0, 360.0, 32 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_Opts", "int", -1, 256 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_FavClear" )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_Fav", "int", 0, 65536 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_ModelInfo", "int", 0, 65536, "int", -1, 2, "vector", 0.0, 16384.0, 32, "vector", -16384.0, 16384.0, 32 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_PackRefused", "int", 0, 32, "int", 0, 4 )
	Remote_RegisterServerFunction( "MapEdit_SV_RequestModel", "int", 0, 65536 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_ModelReady", "int", 0, 65536 )
	Remote_RegisterClientFunction( "ServerCallback_MapEdit_Restored", "int", 0, 4096, "int", 0, 4096, "int", 0, 6 )
}

bool function MapEdit_PackPreflight( string mapName, entity player )
{
	if ( mapName.len() > 64 )
	{
		MapEdit_Reject( player, "pack: map name too long" )
		return false
	}

	int bit = MapEditorCatalog_GetMapBit( mapName )
	if ( bit < 0 || bit > 31 )
	{
		MapEdit_Reject( player, "pack: unknown map" )
		return false
	}

	if ( mapName == GetMapName() )
	{
		MapEdit_Reject( player, "pack: already on map '" + mapName + "'" )
		return false
	}

	if ( ( file.activePackMask & ( 1 << bit ) ) != 0 )
	{
		MapEdit_Reject( player, "pack: '" + mapName + "' already active" )
		return false
	}

	if ( !MapEdit_RequestMapPak( mapName ) )
	{
		MapEdit_Reject( player, "pack: load rejected for '" + mapName + "'" )
		return false
	}

	MapEdit_Report( player, "pack: loading '" + mapName + "'" )
	thread MapEdit_PackLoadThread( bit, mapName )
	return true
}

void function ClientCommand_MapEdit_Pack( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( args.len() < 1 )
	{
		MapEdit_Reject( player, "pack needs <mapName>" )
		return
	}

	int bit = MapEditorCatalog_GetMapBit( args[0] )
	if ( !IsAdmin( player ) && !GetCurrentPlaylistVarBool( "mapeditor_pack_open", false ) )
	{
		MapEdit_Reject( player, "pack: admin only" )
		MapEdit_PackRefused( player, bit, ePackRefusal.ADMIN_ONLY )
		return
	}

	if ( !MapEdit_PackPreflight( args[0], player ) )
		MapEdit_PackRefused( player, bit, ePackRefusal.REJECTED )
}

void function MapEdit_PackFromConsole( string mapName )
{
	MapEditorCatalog_Init()
	MapEdit_PackPreflight( mapName, null )
}

void function MapEdit_PackLoadThread( int bit, string mapName )
{
	float deadline = Time() + 60.0

	while ( Time() < deadline )
	{
		int status = MapEdit_MapPakStatus( mapName )
		if ( status == 1 )
		{
			file.activePackMask = file.activePackMask | ( 1 << bit )
			MapEdit_PackInfo( bit )
			MapEditorCatalog_SetActivePackMask( file.activePackMask )

			foreach ( entity p in GetPlayerArray() )
			{
				if ( IsValid( p ) )
					Remote_CallFunction_NonReplay( p, "ServerCallback_MapEdit_PackLoad", bit )
			}

			printt( format( "[MAPEDIT] pack loaded: %s bit=%d mask=%d", mapName, bit, file.activePackMask ) )
			return
		}

		if ( status == -1 )
		{
			printt( format( "[MAPEDIT] pack load failed: %s bit=%d", mapName, bit ) )
			MapEdit_PackRefusedAll( bit )
			return
		}

		wait 0.25
	}

	printt( format( "[MAPEDIT] pack load timed out: %s bit=%d", mapName, bit ) )
	MapEdit_PackRefusedAll( bit )
}

void function MapEdit_PackRefused( entity player, int bit, int reason )
{
	if ( IsValid( player ) && bit >= 0 && bit < 32 )
		Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_PackRefused", bit, reason )
}

void function MapEdit_PackRefusedAll( int bit )
{
	foreach ( entity p in GetPlayerArray() )
		MapEdit_PackRefused( p, bit, ePackRefusal.FAILED )
}

// A catalog model the current map or a loaded pack provides gets precached the
// first time it is placed.
bool function MapEdit_EnsureModelPrecached( MapEditorCatalogEntry entry, entity requester = null )
{
	if ( ModelIsPrecached( entry.model ) )
		return true
	if ( !MapEditorCatalog_IsAvailableOnMap( entry, GetMapName() ) )
		return false
	if ( file.lazyPrecached >= MAPEDIT_LAZY_PRECACHE_MAX )
	{
		if ( !file.lazyBudgetWarned )
			printt( format( "[MAPEDIT] lazy precache budget spent (%d); further models are refused this map", MAPEDIT_LAZY_PRECACHE_MAX ) )
		file.lazyBudgetWarned = true
		return false
	}

	// The budget is per map and never refunded, and browsing spends it too; each player gets an
	// even split among those present, never below the floor, so a solo builder keeps all of it.
	string uid = IsValid( requester ) ? requester.GetPlatformUID() : ""
	if ( uid != "" )
	{
		int share = maxint( MAPEDIT_LAZY_PRECACHE_MAX / maxint( 1, GetPlayerArray().len() ), MAPEDIT_LAZY_PRECACHE_PER_PLAYER )
		int spent = uid in file.lazyPrecachedBy ? file.lazyPrecachedBy[ uid ] : 0
		if ( spent >= share )
			return false
		file.lazyPrecachedBy[ uid ] <- spent + 1
	}
	file.lazyPrecached++
	if ( !MapEdit_PrecacheModel( entry.model ) || !ModelIsPrecached( entry.model ) )
		return false
	file.precachedIds[ entry.id ] <- true
	return true
}

// A browser pick of a model nobody has placed yet: precache it and tell the player.
void function MapEdit_SV_RequestModel( entity player, int catalogId )
{
	if ( !MapEditor_IsEnabled() || !IsValid( player ) || !player.IsPlayer() )
		return

	float now = Time()
	if ( !( player in file.modelRequests ) )
		file.modelRequests[ player ] <- []
	array< float > recent = file.modelRequests[ player ]
	while ( recent.len() > 0 && now - recent[0] > 1.0 )
		recent.remove( 0 )
	if ( recent.len() >= MAPEDIT_MODEL_REQUESTS_PER_SEC )
		return
	recent.append( now )

	MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( catalogId )
	if ( e == null )
		return
	if ( MapEdit_EnsureModelPrecached( expect MapEditorCatalogEntry( e ), player ) )
		Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_ModelReady", catalogId )
}

void function MapEdit_PackInfo( int bit )
{
	int flag = 1 << bit
	array< int > ids
	foreach ( string category in MapEditorCatalog_GetCategories() )
	{
		foreach ( MapEditorCatalogEntry entry in MapEditorCatalog_GetCategoryEntries( category ) )
		{
			if ( ( entry.mapMask & flag ) != 0 )
				ids.append( entry.id )
		}
	}
	MapEditInfo_Add( ids )
}

// The client's pack-loaded acknowledgement; nothing on the server depends on it.
void function MapEdit_SV_PackReady( entity player, int bit )
{
}

void function MapEdit_OnClientConnected( entity player )
{
	if ( !IsValid( player ) )
		return

	for ( int bit = 0; bit <= 31; bit++ )
	{
		if ( ( file.activePackMask & ( 1 << bit ) ) == 0 )
			continue

		Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_PackLoad", bit )
	}

	if ( file.activePackMask != 0 )
		printt( format( "[MAPEDIT] replayed pack mask=%d to %s", file.activePackMask, player.GetPlayerName() ) )
}

string function MapEdit_ActivePackNames()
{
	string names = ""
	for ( int bit = 0; bit <= 31; bit++ )
	{
		if ( ( file.activePackMask & ( 1 << bit ) ) == 0 )
			continue

		string packName = MapEditorCatalog_GetMapNameForBit( bit )
		if ( packName == "" )
			continue

		if ( names != "" )
			names += ","
		names += packName
	}
	return names
}

// ---------------------------------------------------------------------------
// Legend select -- in-place loadout slot only; never Die / respawn / loadouts_devset
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Legends( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	array< ItemFlavor > characters = GetAllCharacters()
	printt( format( "[MAPEDIT] legends list (%d) for %s:", characters.len(), player.GetPlayerName() ) )
	for ( int i = 0; i < characters.len(); i++ )
		printt( format( "  %d: %s", i, ItemFlavor_GetHumanReadableRef( characters[i] ) ) )

	MapEdit_Report( player, format( "legends: %d entries printed to console", characters.len() ) )
}

void function ClientCommand_MapEdit_Legend( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( args.len() < 1 || !MapEdit_IsIntToken( args[0] ) )
	{
		MapEdit_Reject( player, "legend needs <index>" )
		return
	}

	int index = args[0].tointeger()
	array< ItemFlavor > characters = GetAllCharacters()
	if ( index < 0 || index >= characters.len() )
	{
		MapEdit_Reject( player, format( "legend index out of range 0..%d", characters.len() - 1 ) )
		return
	}

	ItemFlavor character = characters[index]
	SetItemFlavorLoadoutSlot( ToEHI( player ), Loadout_Character(), character )
	MapEdit_Report( player, format( "legend set to %d: %s", index, ItemFlavor_GetHumanReadableRef( character ) ) )
}
