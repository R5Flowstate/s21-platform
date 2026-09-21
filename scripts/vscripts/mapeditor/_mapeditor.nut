// Map editor server: prop registry, budgets, and client-command surface.

global function MapEditor_ServerInit
global function MapEditor_GetPropCount
global function MapEditor_GetPlayerPropCount
global function MapEditor_RegisterSpawned
global function MapEdit_Report
global function MapEdit_Reject
global function MapEdit_IsFiniteCoord
global function MapEdit_NormalizeAngle360
global function MapEditor_IsFrozenFor
global function MapEdit_SV_PackReady
global function MapEdit_PackFromConsole

// Server-side freeze flag; read only via MapEditor_IsFrozenFor outside this file.
global bool g_MapEditFrozen = false

struct MapEditorProp
{
	entity ent
	int    catalogId
	entity owner
	string ownerId
	float  placeTime
}

// Undo removes the entity; redo re-spawns from this description.
struct MapEditorUndoDesc
{
	int    catalogId
	vector origin
	vector angles
}

struct
{
	array< MapEditorProp > props
	table< entity, int > propIndexByEnt
	table< entity, array< float > > placeTimes
	table< entity, array< entity > > undoStack
	table< entity, array< MapEditorUndoDesc > > redoStack
	table< int, bool > precachedIds
	int activePackMask = 0
	bool netRegistered = false
} file

void function MapEditor_ServerInit()
{
	MapEdit_RegisterNetworking()
	AddCallback_OnClientConnected( MapEdit_OnClientConnected )

	if ( !MapEditor_IsEnabled() )
		return

	MapEditorCatalog_Init()

	string mapName = GetMapName()
	array< MapEditorCatalogEntry > available = MapEdit_CollectMapAvailableOrdered( mapName )
	int availableCount = available.len()
	int attempted = 0
	int verified = 0
	file.precachedIds = {}
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
	// Admin-gated powers (same IsAdmin gate as the rest of this tree).
	AddClientCommandCallback( "mapedit_freeze", ClientCommand_MapEdit_Freeze )
	AddClientCommandCallback( "mapedit_clear_player", ClientCommand_MapEdit_ClearPlayer )
	AddClientCommandCallback( "mapedit_clear_all", ClientCommand_MapEdit_ClearAll )
	AddClientCommandCallback( "mapedit_legends", ClientCommand_MapEdit_Legends )
	AddClientCommandCallback( "mapedit_legend", ClientCommand_MapEdit_Legend )
	AddClientCommandCallback( "mapedit_pack", ClientCommand_MapEdit_Pack )

	AddCallback_OnClientDisconnected( MapEditor_OnClientDisconnected )

	MapEditor_Palette_ServerInit()

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
		array< MapEditorCatalogEntry > entries = MapEditorCatalog_GetAvailableCategoryEntries( category, mapName )
		foreach ( MapEditorCatalogEntry entry in entries )
			buildList.append( entry )
	}

	foreach ( string category in MapEditorCatalog_GetCategoriesByTier( "extra" ) )
	{
		array< MapEditorCatalogEntry > entries = MapEditorCatalog_GetAvailableCategoryEntries( category, mapName )
		foreach ( MapEditorCatalogEntry entry in entries )
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
	return file.props.len()
}

int function MapEditor_GetPlayerPropCount( entity player )
{
	if ( !IsValid( player ) )
		return 0

	string uid = player.GetPlatformUID()
	int n = 0
	foreach ( MapEditorProp prop in file.props )
	{
		if ( prop.ownerId != "" )
		{
			if ( prop.ownerId == uid )
				n++
		}
		else if ( IsValid( prop.owner ) && prop.owner == player )
		{
			n++
		}
	}
	return n
}

void function MapEditor_OnClientDisconnected( entity player )
{
	if ( player in file.placeTimes )
		delete file.placeTimes[player]

	if ( player in file.undoStack )
		delete file.undoStack[player]

	if ( player in file.redoStack )
		delete file.redoStack[player]
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
// Helpers
// ---------------------------------------------------------------------------

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
	// Fold into [0, 360).
	while ( a < 0.0 )
		a += 360.0
	while ( a >= 360.0 )
		a -= 360.0
	return a
}

bool function MapEdit_IsOwner( MapEditorProp prop, entity player )
{
	if ( IsValid( prop.owner ) )
		return prop.owner == player

	if ( prop.ownerId != "" && IsValid( player ) )
		return prop.ownerId == player.GetPlatformUID()

	return false
}

bool function MapEditor_IsFrozenFor( entity player )
{
	if ( !g_MapEditFrozen )
		return false
	if ( IsValid( player ) && IsAdmin( player ) )
		return false
	return true
}

void function MapEdit_PushUndo( entity player, entity ent )
{
	if ( !( player in file.undoStack ) )
		file.undoStack[player] <- []

	array< entity > stack = file.undoStack[player]
	stack.append( ent )

	while ( stack.len() > MAPEDIT_UNDO_DEPTH )
		stack.remove( 0 )
}

void function MapEdit_PurgeUndoEnt( entity player, entity ent )
{
	if ( !( player in file.undoStack ) )
		return

	array< entity > stack = file.undoStack[player]
	for ( int i = stack.len() - 1; i >= 0; i-- )
	{
		if ( stack[i] == ent )
			stack.remove( i )
	}
}

void function MapEdit_ClearRedo( entity player )
{
	if ( player in file.redoStack )
		file.redoStack[player].clear()
}

void function MapEdit_PushRedo( entity player, MapEditorUndoDesc desc )
{
	if ( !( player in file.redoStack ) )
		file.redoStack[player] <- []

	array< MapEditorUndoDesc > stack = file.redoStack[player]
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

void function MapEdit_RemoveAtIndex( int idx )
{
	if ( idx < 0 || idx >= file.props.len() )
		return

	entity ent = file.props[idx].ent
	if ( ent in file.propIndexByEnt )
		delete file.propIndexByEnt[ent]

	int last = file.props.len() - 1
	if ( idx != last )
	{
		file.props[idx] = file.props[last]
		entity moved = file.props[idx].ent
		if ( IsValid( moved ) )
			file.propIndexByEnt[moved] <- idx
	}
	file.props.remove( last )
}

void function MapEdit_DestroyRegistered( entity ent, entity ownerForUndo )
{
	if ( !( ent in file.propIndexByEnt ) )
		return

	int idx = file.propIndexByEnt[ent]

	if ( IsValid( ownerForUndo ) )
		MapEdit_PurgeUndoEnt( ownerForUndo, ent )

	MapEdit_RemoveAtIndex( idx )

	if ( IsValid( ent ) )
		ent.Destroy()
}

// Collect first, then destroy -- never walk file.props while RemoveAtIndex swaps.
void function MapEdit_DestroyMany( array< entity > ents )
{
	foreach ( entity ent in ents )
	{
		if ( !IsValid( ent ) )
			continue
		if ( !( ent in file.propIndexByEnt ) )
			continue

		int idx = file.propIndexByEnt[ent]
		MapEditorProp rec = file.props[idx]
		entity owner = rec.owner
		MapEdit_DestroyRegistered( ent, owner )
	}
}

// Registry seam used by place + palette recipes. Budget/freeze refuse; caller destroys.
// clearRedo=false for redo restores so multi-level redo is kept.
bool function MapEditor_RegisterSpawned( entity ent, int catalogId, entity owner, bool clearRedo = true )
{
	if ( !IsValid( ent ) )
		return false

	if ( !IsValid( owner ) || !owner.IsPlayer() )
		return false

	if ( MapEditor_IsFrozenFor( owner ) )
	{
		MapEdit_Reject( owner, "placement frozen by admin" )
		return false
	}

	if ( file.props.len() >= MAPEDIT_PROP_CAP_GLOBAL )
	{
		MapEdit_Reject( owner, format( "global prop cap %d reached", MAPEDIT_PROP_CAP_GLOBAL ) )
		return false
	}

	int playerCount = MapEditor_GetPlayerPropCount( owner )
	if ( playerCount >= MAPEDIT_PROP_CAP_PLAYER )
	{
		MapEdit_Reject( owner, format( "player prop cap %d reached", MAPEDIT_PROP_CAP_PLAYER ) )
		return false
	}

	MapEditorProp rec
	rec.ent = ent
	rec.catalogId = catalogId
	rec.owner = owner
	rec.ownerId = owner.GetPlatformUID()
	rec.placeTime = Time()

	int newIdx = file.props.len()
	file.props.append( rec )
	file.propIndexByEnt[ent] <- newIdx

	MapEdit_PushUndo( owner, ent )
	if ( clearRedo )
		MapEdit_ClearRedo( owner )

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

	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "placement frozen by admin" )
		return
	}

	// 1. Arg count before any index.
	if ( args.len() != 7 )
	{
		MapEdit_Reject( player, "place needs 7 args: <id> <x> <y> <z> <pitch> <yaw> <roll>" )
		return
	}

	// 2. Catalog id only -- never a model path from the client.
	if ( !IsStringNumber( args[0] ) )
	{
		MapEdit_Reject( player, "catalog id is not a number: " + args[0] )
		return
	}

	int catalogId = args[0].tointeger()
	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( catalogId )
	if ( entryOrNull == null )
	{
		MapEdit_Reject( player, "unknown catalog id " + string( catalogId ) )
		return
	}
	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )

	// Catalog id is valid; still refuse models the server has not loaded.
	if ( !ModelIsPrecached( entry.model ) )
	{
		MapEdit_Reject( player, format( "model not precached for catalog id %d (%s)",
			catalogId, string( entry.model ) ) )
		return
	}

	// 3. Numeric sanity for origin and angles.
	if ( !IsStringNumber( args[1] ) || !IsStringNumber( args[2] ) || !IsStringNumber( args[3] ) ||
		 !IsStringNumber( args[4] ) || !IsStringNumber( args[5] ) || !IsStringNumber( args[6] ) )
	{
		MapEdit_Reject( player, "origin/angles not numeric" )
		return
	}

	float x = args[1].tofloat()
	float y = args[2].tofloat()
	float z = args[3].tofloat()
	float pitch = args[4].tofloat()
	float yaw = args[5].tofloat()
	float roll = args[6].tofloat()

	if ( !MapEdit_IsFiniteCoord( x ) || !MapEdit_IsFiniteCoord( y ) || !MapEdit_IsFiniteCoord( z ) )
	{
		MapEdit_Reject( player, "origin not finite or out of world limit" )
		return
	}

	// Angles: NaN/inf only (world limit is for coordinates).
	if ( pitch != pitch || yaw != yaw || roll != roll )
	{
		MapEdit_Reject( player, "angles contain NaN" )
		return
	}
	if ( fabs( pitch ) > MAPEDIT_ANGLE_LIMIT || fabs( yaw ) > MAPEDIT_ANGLE_LIMIT || fabs( roll ) > MAPEDIT_ANGLE_LIMIT )
	{
		MapEdit_Reject( player, "angles not finite" )
		return
	}

	vector origin = <x, y, z>

	// 4. Proximity to caller eye.
	vector eye = player.EyePosition()
	if ( Distance( eye, origin ) > MAPEDIT_MAX_PLACE_DIST )
	{
		MapEdit_Reject( player, format( "origin too far from eye (max %.0f)", MAPEDIT_MAX_PLACE_DIST ) )
		return
	}

	// 5. Normalise angles server-side.
	pitch = MapEdit_NormalizeAngle360( pitch )
	yaw   = MapEdit_NormalizeAngle360( yaw )
	roll  = MapEdit_NormalizeAngle360( roll )
	vector angles = <pitch, yaw, roll>

	// 6. Rate limit -- stamp only after a successful spawn+register.
	float now = Time()
	if ( !( player in file.placeTimes ) )
		file.placeTimes[player] <- []

	array< float > placeWindow = file.placeTimes[player]
	while ( placeWindow.len() > 0 && ( now - placeWindow[0] ) > MAPEDIT_PLACE_RATE_WINDOW )
		placeWindow.remove( 0 )

	if ( placeWindow.len() >= MAPEDIT_PLACE_RATE_MAX )
	{
		MapEdit_Reject( player, format( "place rate limit %d / %.1fs", MAPEDIT_PLACE_RATE_MAX, MAPEDIT_PLACE_RATE_WINDOW ) )
		return
	}

	entity prop = CreatePropDynamic( entry.model, origin, angles, SOLID_VPHYSICS, -1.0 )
	if ( !IsValid( prop ) )
	{
		MapEdit_Reject( player, "CreatePropDynamic failed for catalog id " + string( catalogId ) )
		return
	}

	// Non-mantleable by default (do not call AllowMantle).
	prop.SetScriptName( "mapedit_prop" )

	if ( !MapEditor_RegisterSpawned( prop, catalogId, player ) )
	{
		prop.Destroy()
		return
	}

	placeWindow.append( Time() )

	MapEdit_Report( player, format( "placed id=%d at %.0f %.0f %.0f (global %d, you %d)",
		catalogId, origin.x, origin.y, origin.z, file.props.len(), MapEditor_GetPlayerPropCount( player ) ) )

	return
}

// ---------------------------------------------------------------------------
// mapedit_delete -- re-trace from eye, registry-authorised remove
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
	vector forward = player.GetViewVector()
	TraceResults tr = TraceLine( eye, eye + forward * MAPEDIT_MAX_PLACE_DIST, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	if ( !IsValid( tr.hitEnt ) )
	{
		MapEdit_Reject( player, "delete: nothing hit" )
		return
	}

	entity hit = tr.hitEnt

	// Authorise by registry ownership, never by script name.
	if ( !( hit in file.propIndexByEnt ) )
	{
		MapEdit_Reject( player, "delete: not an editor prop" )
		return
	}

	int idx = file.propIndexByEnt[hit]
	MapEditorProp rec = file.props[idx]

	if ( !MapEdit_IsOwner( rec, player ) )
	{
		MapEdit_Reject( player, "delete: you do not own this prop" )
		return
	}

	MapEdit_DestroyRegistered( hit, player )
	MapEdit_Report( player, format( "deleted prop (global %d, you %d)",
		file.props.len(), MapEditor_GetPlayerPropCount( player ) ) )

	return
}

// ---------------------------------------------------------------------------
// mapedit_undo -- pop caller's undo stack, push description to redo
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

	if ( !( player in file.undoStack ) || file.undoStack[player].len() == 0 )
	{
		MapEdit_Reject( player, "undo: stack empty" )
		return
	}

	array< entity > stack = file.undoStack[player]
	entity ent = stack[stack.len() - 1]
	stack.remove( stack.len() - 1 )

	if ( !IsValid( ent ) || !( ent in file.propIndexByEnt ) )
	{
		MapEdit_Reject( player, "undo: prop already gone" )
		return
	}

	int idx = file.propIndexByEnt[ent]
	MapEditorProp rec = file.props[idx]
	if ( !MapEdit_IsOwner( rec, player ) )
	{
		MapEdit_Reject( player, "undo: not your prop" )
		return
	}

	MapEditorUndoDesc desc
	desc.catalogId = rec.catalogId
	desc.origin = ent.GetOrigin()
	desc.angles = ent.GetAngles()
	MapEdit_PushRedo( player, desc )

	// Already popped undo; destroy without purging again.
	MapEdit_RemoveAtIndex( idx )
	if ( IsValid( ent ) )
		ent.Destroy()

	MapEdit_Report( player, format( "undo ok (global %d, you %d)",
		file.props.len(), MapEditor_GetPlayerPropCount( player ) ) )

	return
}

// ---------------------------------------------------------------------------
// mapedit_redo -- re-spawn from description via place path
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Redo( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "redo frozen by admin" )
		return
	}

	if ( !( player in file.redoStack ) || file.redoStack[player].len() == 0 )
	{
		MapEdit_Reject( player, "redo: stack empty" )
		return
	}

	array< MapEditorUndoDesc > stack = file.redoStack[player]
	MapEditorUndoDesc desc = stack[stack.len() - 1]
	stack.remove( stack.len() - 1 )

	if ( desc.catalogId <= 0 )
	{
		MapEdit_Reject( player, "redo: non-catalog entity cannot be restored" )
		return
	}

	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( desc.catalogId )
	if ( entryOrNull == null )
	{
		MapEdit_Reject( player, "redo: unknown catalog id " + string( desc.catalogId ) )
		return
	}
	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )

	vector eye = player.EyePosition()
	if ( Distance( eye, desc.origin ) > MAPEDIT_MAX_PLACE_DIST )
	{
		// Put the desc back so a later redo can still try.
		stack.append( desc )
		MapEdit_Reject( player, format( "redo: origin too far from eye (max %.0f)", MAPEDIT_MAX_PLACE_DIST ) )
		return
	}

	// Rate check without stamp; stamp only after a successful register.
	float now = Time()
	if ( !( player in file.placeTimes ) )
		file.placeTimes[player] <- []
	array< float > placeWindow = file.placeTimes[player]
	while ( placeWindow.len() > 0 && ( now - placeWindow[0] ) > MAPEDIT_PLACE_RATE_WINDOW )
		placeWindow.remove( 0 )
	if ( placeWindow.len() >= MAPEDIT_PLACE_RATE_MAX )
	{
		stack.append( desc )
		MapEdit_Reject( player, format( "place rate limit %d / %.1fs", MAPEDIT_PLACE_RATE_MAX, MAPEDIT_PLACE_RATE_WINDOW ) )
		return
	}

	entity prop = CreatePropDynamic( entry.model, desc.origin, desc.angles, SOLID_VPHYSICS, -1.0 )
	if ( !IsValid( prop ) )
	{
		stack.append( desc )
		MapEdit_Reject( player, "redo: CreatePropDynamic failed" )
		return
	}

	prop.SetScriptName( "mapedit_prop" )

	if ( !MapEditor_RegisterSpawned( prop, desc.catalogId, player, false ) )
	{
		prop.Destroy()
		stack.append( desc )
		return
	}

	placeWindow.append( Time() )

	MapEdit_Report( player, format( "redo id=%d (global %d, you %d)",
		desc.catalogId, file.props.len(), MapEditor_GetPlayerPropCount( player ) ) )

	return
}

// ---------------------------------------------------------------------------
// mapedit_whois -- ownership query via eye trace
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Whois( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	vector eye = player.EyePosition()
	vector forward = player.GetViewVector()
	TraceResults tr = TraceLine( eye, eye + forward * MAPEDIT_MAX_PLACE_DIST, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	if ( !IsValid( tr.hitEnt ) )
	{
		MapEdit_Reject( player, "whois: nothing hit" )
		return
	}

	entity hit = tr.hitEnt
	if ( !( hit in file.propIndexByEnt ) )
	{
		MapEdit_Report( player, "whois: not an editor prop" )
		return
	}

	int idx = file.propIndexByEnt[hit]
	MapEditorProp rec = file.props[idx]

	if ( IsValid( rec.owner ) )
	{
		MapEdit_Report( player, format( "whois: owned by %s (uid %s, catalog %d)",
			rec.owner.GetPlayerName(), rec.ownerId, rec.catalogId ) )
		return
	}

	if ( rec.ownerId != "" )
	{
		// Owner left; resolve name from still-connected players with same uid, else say so.
		string name = ""
		foreach ( entity p in GetPlayerArray() )
		{
			if ( IsValid( p ) && p.GetPlatformUID() == rec.ownerId )
			{
				name = p.GetPlayerName()
				break
			}
		}

		if ( name != "" )
			MapEdit_Report( player, format( "whois: owned by %s (uid %s, catalog %d)", name, rec.ownerId, rec.catalogId ) )
		else
			MapEdit_Report( player, format( "whois: owner left (uid %s, catalog %d)", rec.ownerId, rec.catalogId ) )
		return
	}

	MapEdit_Report( player, format( "whois: no owner recorded (catalog %d)", rec.catalogId ) )
	return
}

// ---------------------------------------------------------------------------
// mapedit_status
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Status( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	int mine = MapEditor_GetPlayerPropCount( player )
	int globalCount = file.props.len()
	int undoLen = ( player in file.undoStack ) ? file.undoStack[player].len() : 0
	int redoLen = ( player in file.redoStack ) ? file.redoStack[player].len() : 0
	string freezeStr = g_MapEditFrozen ? "1" : "0"

	MapEdit_Report( player, format( "status: you=%d/%d global=%d/%d undo=%d redo=%d freeze=%s catalog=%d packs=%s",
		mine, MAPEDIT_PROP_CAP_PLAYER, globalCount, MAPEDIT_PROP_CAP_GLOBAL, undoLen, redoLen, freezeStr, MapEditorCatalog_Count(), MapEdit_ActivePackNames() ) )

	return
}

// ---------------------------------------------------------------------------
// mapedit_clear_mine -- any player, own props only
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_ClearMine( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	// Snapshot entities first so RemoveAtIndex swap never invalidates the walk.
	array< entity > toRemove
	foreach ( MapEditorProp prop in file.props )
	{
		if ( MapEdit_IsOwner( prop, player ) && IsValid( prop.ent ) )
			toRemove.append( prop.ent )
	}

	int n = toRemove.len()
	MapEdit_DestroyMany( toRemove )
	MapEdit_ClearPlayerStacks( player )

	MapEdit_Report( player, format( "clear_mine: removed %d (global %d)", n, file.props.len() ) )
	return
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

	if ( args.len() < 1 )
	{
		MapEdit_Reject( player, "freeze needs <0|1>" )
		return
	}

	if ( !IsStringNumber( args[0] ) )
	{
		MapEdit_Reject( player, "freeze arg not a number" )
		return
	}

	int v = args[0].tointeger()
	if ( v != 0 && v != 1 )
	{
		MapEdit_Reject( player, "freeze needs <0|1>" )
		return
	}

	g_MapEditFrozen = ( v == 1 )
	MapEdit_Report( player, format( "freeze=%d", v ) )
	return
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

	// Also match by ownerId against still-registered props if the player is gone.
	string targetUid = ""
	if ( IsValid( target ) )
		targetUid = target.GetPlatformUID()

	array< entity > toRemove
	foreach ( MapEditorProp prop in file.props )
	{
		bool match = false
		if ( IsValid( target ) && MapEdit_IsOwner( prop, target ) )
			match = true
		else if ( targetUid != "" && prop.ownerId == targetUid )
			match = true
		else if ( !IsValid( target ) && prop.ownerId == "" && IsValid( prop.owner ) && prop.owner.GetPlayerName() == targetName )
			match = true

		// Name match against stored owner when entity owner is still valid.
		if ( !match && IsValid( prop.owner ) && prop.owner.GetPlayerName() == targetName )
			match = true

		if ( match && IsValid( prop.ent ) )
			toRemove.append( prop.ent )
	}

	if ( toRemove.len() == 0 && !IsValid( target ) )
	{
		// Last chance: match props whose live owner name equals the arg (already done)
		// or report not found.
		MapEdit_Reject( player, "clear_player: no props for '" + targetName + "'" )
		return
	}

	int n = toRemove.len()
	MapEdit_DestroyMany( toRemove )
	if ( IsValid( target ) )
		MapEdit_ClearPlayerStacks( target )

	MapEdit_Report( player, format( "clear_player '%s': removed %d (global %d)", targetName, n, file.props.len() ) )
	return
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

	// Snapshot every registered entity, then destroy via registry.
	array< entity > toRemove
	foreach ( MapEditorProp prop in file.props )
	{
		if ( IsValid( prop.ent ) )
			toRemove.append( prop.ent )
	}

	int n = toRemove.len()
	MapEdit_DestroyMany( toRemove )

	// Wipe every player's undo/redo -- multi-remove is where stale stacks bite.
	foreach ( entity p in GetPlayerArray() )
	{
		if ( IsValid( p ) )
			MapEdit_ClearPlayerStacks( p )
	}
	// Also drop disconnected-key tables by clearing known keys left on entities that disconnected.
	// placeTimes/undo/redo for disconnected players are already cleaned on disconnect.

	MapEdit_Report( player, format( "clear_all: removed %d", n ) )
	return
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
}

void function ClientCommand_MapEdit_Pack( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !IsAdmin( player ) && !GetCurrentPlaylistVarBool( "mapeditor_pack_open", true ) )
	{
		MapEdit_Reject( player, "pack: admin only" )
		return
	}

	if ( args.len() < 1 )
	{
		MapEdit_Reject( player, "pack needs <mapName>" )
		return
	}

	string mapName = args[0]
	if ( mapName.len() > 64 )
	{
		MapEdit_Reject( player, "pack: map name too long" )
		return
	}

	int bit = MapEditorCatalog_GetMapBit( mapName )
	if ( bit < 0 || bit > 31 )
	{
		MapEdit_Reject( player, "pack: unknown map '" + mapName + "'" )
		return
	}

	if ( mapName == GetMapName() )
	{
		MapEdit_Reject( player, "pack: already on map '" + mapName + "'" )
		return
	}

	if ( ( file.activePackMask & ( 1 << bit ) ) != 0 )
	{
		MapEdit_Reject( player, "pack: '" + mapName + "' already active" )
		return
	}

	if ( !MapEdit_RequestMapPak( mapName ) )
	{
		MapEdit_Reject( player, "pack: load rejected for '" + mapName + "'" )
		return
	}

	MapEdit_Report( player, "pack: loading '" + mapName + "'" )
	thread MapEdit_PackLoadThread( bit, mapName )
	return
}

void function MapEdit_PackFromConsole( string mapName )
{
	MapEditorCatalog_Init()

	if ( mapName.len() > 64 )
	{
		printt( "[MAPEDIT] pack: map name too long" )
		return
	}

	int bit = MapEditorCatalog_GetMapBit( mapName )
	if ( bit < 0 || bit > 31 )
	{
		printt( "[MAPEDIT] pack: unknown map '" + mapName + "'" )
		return
	}

	if ( mapName == GetMapName() )
	{
		printt( "[MAPEDIT] pack: already on map '" + mapName + "'" )
		return
	}

	if ( ( file.activePackMask & ( 1 << bit ) ) != 0 )
	{
		printt( "[MAPEDIT] pack: '" + mapName + "' already active" )
		return
	}

	if ( !MapEdit_RequestMapPak( mapName ) )
	{
		printt( "[MAPEDIT] pack: load rejected for '" + mapName + "'" )
		return
	}

	printt( "[MAPEDIT] pack: loading '" + mapName + "'" )
	thread MapEdit_PackLoadThread( bit, mapName )
}

void function MapEdit_PackLoadThread( int bit, string mapName )
{
	float deadline = Time() + 60.0

	while ( Time() < deadline )
	{
		int status = MapEdit_MapPakStatus( mapName )
		if ( status == 1 )
		{
			MapEdit_PrecachePack( bit )
			file.activePackMask = file.activePackMask | ( 1 << bit )
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
			return
		}

		wait 0.25
	}

	printt( format( "[MAPEDIT] pack load timed out: %s bit=%d", mapName, bit ) )
}

void function MapEdit_PrecachePack( int bit )
{
	int flag = 1 << bit
	int attempted = 0
	int verified = 0

	foreach ( string category in MapEditorCatalog_GetCategories() )
	{
		if ( attempted >= MAPEDIT_PACK_PRECACHE_MAX )
			break

		foreach ( MapEditorCatalogEntry entry in MapEditorCatalog_GetCategoryEntries( category ) )
		{
			if ( attempted >= MAPEDIT_PACK_PRECACHE_MAX )
				break

			if ( ( entry.mapMask & flag ) == 0 )
				continue

			if ( entry.id in file.precachedIds )
				continue

			attempted++
			if ( !MapEdit_PrecacheModel( entry.model ) )
				continue

			if ( ModelIsPrecached( entry.model ) )
			{
				file.precachedIds[ entry.id ] <- true
				verified++
			}
		}
	}

	printt( format( "[MAPEDIT] pack precache bit=%d attempted=%d verified=%d cap=%d",
		bit, attempted, verified, MAPEDIT_PACK_PRECACHE_MAX ) )
}

void function MapEdit_SV_PackReady( entity player, int bit )
{
	if ( bit < 0 || bit > 31 )
	{
		printt( "[MAPEDIT] PackReady: bit out of range" )
		return
	}

	string who = IsValid( player ) ? player.GetPlayerName() : "null"
	printt( format( "[MAPEDIT] PackReady: bit=%d from %s", bit, who ) )
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
	{
		string ref = ItemFlavor_GetHumanReadableRef( characters[i] )
		printt( format( "  %d: %s", i, ref ) )
	}

	MapEdit_Report( player, format( "legends: %d entries printed to console", characters.len() ) )
	return
}

void function ClientCommand_MapEdit_Legend( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( args.len() < 1 )
	{
		MapEdit_Reject( player, "legend needs <index>" )
		return
	}

	if ( !IsStringNumber( args[0] ) )
	{
		MapEdit_Reject( player, "legend index not a number" )
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

	string ref = ItemFlavor_GetHumanReadableRef( character )
	MapEdit_Report( player, format( "legend set to %d: %s", index, ref ) )
	return
}
