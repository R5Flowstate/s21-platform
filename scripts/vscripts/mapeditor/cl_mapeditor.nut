// Map editor client: build-mode ghost, placement math, and bind surface.

global function MapEditor_ClientInit
global function MapEditor_SetSelectedModel
global function MapEditor_IsModelOffered
global function UIToClient_MapEditor_SetModel
global function UIToClient_MapEditor_SetSpecial
global function ServerCallback_MapEdit_PackLoad
global function ServerCallback_MapEdit_PackRefused
global function ServerCallback_MapEdit_ModelReady
global function ServerCallback_MapEdit_Restored
global function MapEditor_PreviewModelFor
global function UIToClient_MapEditor_AssignSlot
global function UIToClient_MapEditor_ClearSlot
global function UIToClient_MapEditor_SetFav
global function UIToClient_MapEditor_SetOpts
global function UIToClient_MapEditor_SyncUI
global function ServerCallback_MapEdit_Hotbar
global function ServerCallback_MapEdit_Opts
global function ServerCallback_MapEdit_FavClear
global function ServerCallback_MapEdit_Fav
global function ServerCallback_MapEdit_ModelInfo
global function MapEditor_ModelBounds
global function MapEdit_SetHudSuppressed

// Editor-only verbs sit on raw keys, and a raw key fires alongside whatever
// it is bound to. So each verb takes the first key from its pool that the
// player has not bound and the movement recorder does not use.

const int   MAPEDIT_HOTBAR_SLOTS = 3
const float MAPEDIT_SLOT_SYNC_DELAY = 0.6
const float MAPEDIT_TURBO_INTERVAL = 0.12
const float MAPEDIT_TURBO_MIN_SPACING = 32.0
const vector MAPEDIT_HUD_MENU_COLOR = <0.345, 0.780, 0.855>
const vector MAPEDIT_HUD_WEAPONS_COLOR = <0.949, 0.663, 0.231>
const vector MAPEDIT_HUD_RESTORED_COLOR = <0.424, 0.753, 0.439>
const vector MAPEDIT_HUD_ACCENT = <1.0, 0.310, 0.631>
const float MAPEDIT_TOOL_SETTLE = 0.3
const vector MAPEDIT_HUD_TEXT = <0.949, 0.949, 0.949>
const vector MAPEDIT_HUD_NOTE = <0.604, 0.643, 0.671>
const float MAPEDIT_HUD_X = 48.0
const float MAPEDIT_HUD_Y = 312.0
const float MAPEDIT_HUD_W = 470.0
// Panel heights: the full build layout, and the weapons layout's single row.
const float MAPEDIT_HUD_H_BUILD = 428.0
const float MAPEDIT_HUD_H_WEAPONS = 142.0
const float MAPEDIT_HUD_TOAST_HOLD = 4.0
// Reach: surface placement never lands farther than this; Air mode holds the model here.
const float MAPEDIT_REACH_DEFAULT = 768.0
const float MAPEDIT_REACH_MIN = 64.0
const float MAPEDIT_REACH_STEP = 64.0
const float MAPEDIT_REACH_MAX = 4000.0
const float MAPEDIT_PAD_HOLD = 0.4

// kind: 0 empty, 1 catalog model, 2 palette recipe
struct MapEditSlot
{
	int    kind = 0
	int    id = 0
	vector angles = <0, 0, 0>
}

struct
{
	bool   buildMode = false
	entity ghost
	int    catalogId = 0
	bool   modelDirty = false
	float  zOffset = 0.0
	vector angleOffset = <0, 0, 0>
	int    snapIndex = 0
	vector lastOrigin = <0, 0, 0>
	vector lastAngles = <0, 0, 0>
	bool   hasPlacement = false
	// 0 = no grid snap
	array< float > snapSizes
	bool   noclipOn = false
	bool   ziplinePending = false
	bool   autoStarted = false
	// Drawn preview transform; eases toward the placement target every frame.
	vector smoothOrigin = <0, 0, 0>
	vector smoothNormal = <0, 0, 1>
	vector smoothForward = <1, 0, 0>
	bool   smoothValid = false
	// Catalog ids we PrecacheModel'd this map (client has no ModelIsPrecached).
	table< int, bool > offeredIds
	// catalog id -> Time() of the last server request / server said it is precached
	table< int, float > modelRequested
	table< int, bool > modelAcked
	int activePackMask = 0
	bool netRegistered = false

	int keyToggle = -1
	int keyNoclip = -1
	int keyYawCcw = -1
	int keyYawCw = -1
	int keyWhois = -1
	int keyPacks = -1
	// Palette recipe the next place sends instead of a catalog model; 0 = none.
	int specialId = 0

	array< MapEditSlot > slots
	int   activeSlot = -1
	bool  slotDirty = false
	// 0 pitch, 1 yaw, 2 roll
	int   rotAxis = 1
	bool  placeHeld = false
	vector lastTurboOrigin = <0, 0, 0>
	bool  prefsRequested = false
	float reach = MAPEDIT_REACH_DEFAULT
	bool  airMode = false
	int   keyAir = -1
	int   keyReachIn = -1
	int   keyReachOut = -1
	int   keyRaise = -1
	int   keyLower = -1
	// Seconds the held weapon has disagreed with build mode; a weapon swap or a
	// respawn passes through a moment with no tool in hand.
	float toolMismatchSince = -1.0
	bool  hudCharSelect = false
	float padL3Down = -1.0

	int keyCycle = -1
	int keyRot90 = -1
	int keyAxis = -1
	int keyResetRot = -1
	int keyPick = -1
	array< int > slotKeys = [ -1, -1, -1 ]
	// Letters most layouts leave free; the picker still skips any the player bound.
	array<int> letterKeys = [ KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O, KEY_P, KEY_Y, KEY_T, KEY_N, KEY_H ]
	array< array< int > > slotTriples = [ [ KEY_6, KEY_7, KEY_8 ], [ KEY_7, KEY_8, KEY_9 ], [ KEY_J, KEY_K, KEY_L ], [ KEY_U, KEY_I, KEY_O ] ]

	array<int> reservedKeys = [ KEY_F1, KEY_F2, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9 ]
	// Laptop keyboards often have no Home/End/PgUp/PgDn, so punctuation comes first.
	array<int> singleKeys = [ KEY_F10, KEY_F11, KEY_F3, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_INSERT, KEY_DELETE, KEY_HOME, KEY_END ]
	// Rotate takes a pair: counter-clockwise, clockwise.
	array<int> yawPairs = [ KEY_COMMA, KEY_PERIOD, KEY_MINUS, KEY_EQUAL, KEY_HOME, KEY_END ]
	// Raise / lower pair. 1 and 2 switch weapons now, so height has its own keys.
	array<int> heightPairs = [ KEY_PAGEUP, KEY_PAGEDOWN, KEY_UP, KEY_DOWN, KEY_9, KEY_0 ]

	// Studio bounds per catalog id, [ mins, maxs ], from the server: a client-side prop has no collision bounds to read.
	table< int, array< vector > > modelBounds

	var hudRui = null
	// A RUI draws at most 10 key caps, so the transform rows' keys get their own.
	var hudKeysRui = null
	bool hudShown = false
	bool hudSuppressed = false
	string hudToast = ""
	vector hudToastColor = <1, 1, 1>
	float hudToastUntil = 0.0
} file

void function MapEditor_ClientInit()
{
	MapEdit_ClientRegisterNetworking()

	if ( !MapEditor_IsEnabled() )
		return

	MapEditorCatalog_Init()

	file.snapSizes = [ 0.0, 1.0, 4.0, 16.0, 64.0, 128.0, 256.0 ]
	file.ghost = null
	file.buildMode = false
	file.catalogId = 0
	file.modelDirty = false
	file.zOffset = 0.0
	file.angleOffset = <0, 0, 0>
	file.snapIndex = 0
	file.hasPlacement = false
	file.autoStarted = false
	file.offeredIds = {}
	file.modelRequested = {}
	file.modelAcked = {}
	file.activePackMask = 0
	MapEditorCatalog_SetActivePackMask( 0 )
	file.smoothValid = false

	MapEditPreview_Init()
	file.slots.clear()
	for ( int i = 0; i < MAPEDIT_HOTBAR_SLOTS; i++ )
	{
		MapEditSlot s
		file.slots.append( s )
	}
	file.activeSlot = -1
	file.prefsRequested = false

	// Ghost / SetModel fallback; must always be safe for CreateClientSidePropDynamic.
	PrecacheModel( $"mdl/dev/empty_model.rmdl" )
	PrecacheModel( MAPEDIT_JUMP_PAD_MODEL )
	PrecacheModel( MAPEDIT_DOOR_MODEL )
	PrecacheModel( MAPEDIT_LOOT_BIN_MODEL )

	string mapName = GetMapName()
	array< MapEditorCatalogEntry > available = MapEdit_CollectMapAvailableOrdered_Client( mapName )
	int availableCount = available.len()
	int attempted = 0

	foreach ( MapEditorCatalogEntry entry in available )
	{
		if ( attempted >= MAPEDIT_PRECACHE_MAX )
			break

		PrecacheModel( entry.model )
		file.offeredIds[ entry.id ] <- true
		attempted++
	}

	printt( format( "[MAPEDIT] client precache map=%s available=%d attempted=%d cap=%d",
		mapName, availableCount, attempted, MAPEDIT_PRECACHE_MAX ) )

	MapEdit_SelectDefaultModel()

	RegisterSignal( "MapEdit_BuildModeOff" )

	// Permanent toggle -- not deregistered when build mode ends.
	array<int> taken = []
	file.keyToggle = MapEdit_PickKey( file.singleKeys, taken )
	RegisterButtonPressedCallback( file.keyToggle, MapEdit_OnToggleBuildModeKey )

	// Local player may not exist at init; auto-start when they respawn.
	AddCallback_OnYouRespawned( MapEdit_OnYouRespawned )
	// The build panel waits until the legend is picked.
	AddCallback_OnCharacterSelectMenuOpened( MapEdit_RefreshPanel )
	AddCallback_OnCharacterSelectMenuClosed( MapEdit_RefreshPanel )
	// If already alive (callback already fired before our register), start now.
	if ( IsValid( GetLocalClientPlayer() ) )
		MapEdit_OnYouRespawned()

	printt( format( "[MAPEDIT] client init, catalog=%d, defaultId=%d, map=%s, offered=%d",
		MapEditorCatalog_Count(), file.catalogId, mapName, attempted ) )
}

// ---------------------------------------------------------------------------
// Model selection (menu hook)
// ---------------------------------------------------------------------------

// Offered = in the networked model table, so it may reach CreateClientSidePropDynamic.
// The client cannot add to that table: a model the map or a loaded pack provides is
// asked of the server, and becomes offered once the server's precache has arrived.
bool function MapEditor_IsModelOffered( int catalogId )
{
	if ( catalogId in file.offeredIds )
		return true
	MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( catalogId )
	if ( e == null )
		return false
	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( e )
	if ( !MapEditorCatalog_IsAvailableOnMap( entry, GetMapName() ) )
		return false

	if ( catalogId in file.modelAcked )
	{
		if ( !MapEdit_ModelIndexArrived( entry.model ) )
			return false
		delete file.modelAcked[ catalogId ]
		file.offeredIds[ catalogId ] <- true
		return true
	}

	float now = Time()
	if ( !( catalogId in file.modelRequested ) || now - file.modelRequested[ catalogId ] > MAPEDIT_MODEL_REQUEST_RETRY )
	{
		file.modelRequested[ catalogId ] <- now
		Remote_ServerCallFunction( "MapEdit_SV_RequestModel", catalogId )
	}
	return false
}

// The string table update and the server's reply travel separately; the model is
// usable once the engine can resolve its index.
bool function MapEdit_ModelIndexArrived( asset model )
{
	try
	{
		StreamModelHint( model )
	}
	catch ( err )
	{
		return false
	}
	return true
}

// slot 0 is the autosave, 1-5 the numbered save slots.
void function ServerCallback_MapEdit_Restored( int placed, int kept, int slot )
{
	string from = slot == 0 ? "autosave" : "slot " + string( slot )
	string msg = format( "Restored %d prop%s from %s", placed, placed == 1 ? "" : "s", from )
	if ( kept > 0 )
		msg += format( "  |  %d waiting for another map", kept )
	MapEdit_HudToast( msg, MAPEDIT_HUD_RESTORED_COLOR )
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) && placed + kept > 0 )
		AnnouncementMessageRight( player, "Map editor", msg, <1, 1, 1>, $"", 5.0 )
}

void function ServerCallback_MapEdit_ModelReady( int catalogId )
{
	if ( !( catalogId in file.offeredIds ) )
		file.modelAcked[ catalogId ] <- true
}

void function MapEditor_SetSelectedModel( int catalogId )
{
	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( catalogId )
	if ( entryOrNull == null )
	{
		printt( "[MAPEDIT] SetSelectedModel: unknown catalog id " + string( catalogId ) )
		return
	}

	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
	string mapName = GetMapName()
	if ( !MapEditorCatalog_IsAvailableOnMap( entry, mapName ) )
	{
		printt( format( "[MAPEDIT] SetSelectedModel: id %d not available on map %s", catalogId, mapName ) )
		entity rejectPlayer = GetLocalClientPlayer()
		if ( IsValid( rejectPlayer ) )
			AnnouncementMessageRight( rejectPlayer, format( "Model not on %s", mapName ), "", <1, 1, 1>, $"", 3.0 )
		return
	}

	if ( !MapEditor_IsModelOffered( catalogId ) )
	{
		printt( format( "[MAPEDIT] SetSelectedModel: id %d not offered (not precached)", catalogId ) )
		entity rejectPlayer = GetLocalClientPlayer()
		if ( IsValid( rejectPlayer ) )
			AnnouncementMessageRight( rejectPlayer, "Model not precached", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	file.catalogId = catalogId
	file.modelDirty = true
	MapEdit_RefreshPanel()

	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		AnnouncementMessageRight( player, format( "Model %d: %s", catalogId, entry.category ), "", <1, 1, 1>, $"", 3.0 )
}

void function UIToClient_MapEditor_SetModel( int catalogId )
{
	file.specialId = 0
	file.activeSlot = -1
	MapEditor_SetSelectedModel( catalogId )
	MapEdit_RefreshPanel()
}

// Recipe ids match the server palette: 1 jump pad, 2 door, 3 double door,
// 4 loot bin, 5 launch effect.
void function UIToClient_MapEditor_SetSpecial( int recipeId )
{
	if ( recipeId < 1 || recipeId > 5 )
		return
	file.specialId = recipeId
	file.activeSlot = -1
	file.modelDirty = true
	MapEdit_RefreshPanel()
	MapEdit_RefreshPanel()

	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		AnnouncementMessageRight( player, MapEdit_SpecialName( recipeId ), "", <1, 1, 1>, $"", 3.0 )
}

string function MapEdit_SpecialName( int recipeId )
{
	switch ( recipeId )
	{
		case 1: return Localize( "#MAPEDIT_TOOL_JUMPPAD" )
		case 2: return Localize( "#MAPEDIT_TOOL_DOOR" )
		case 3: return Localize( "#MAPEDIT_TOOL_DOUBLEDOOR" )
		case 4: return Localize( "#MAPEDIT_TOOL_LOOTBIN" )
		case 5: return Localize( "#MAPEDIT_TOOL_EFFECT" )
	}
	return ""
}

asset function MapEdit_SpecialModel( int recipeId )
{
	switch ( recipeId )
	{
		case 1: return MAPEDIT_JUMP_PAD_MODEL
		case 2:
		case 3: return MAPEDIT_DOOR_MODEL
		case 4: return MAPEDIT_LOOT_BIN_MODEL
	}
	return $"mdl/dev/empty_model.rmdl"
}

// What the preview shows: the chosen special, else the chosen catalog model.
asset function MapEdit_SelectedModel()
{
	if ( file.specialId > 0 )
		return MapEdit_SpecialModel( file.specialId )

	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
	if ( entryOrNull == null )
		return $"mdl/dev/empty_model.rmdl"

	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
	string mapName = GetMapName()
	if ( MapEditorCatalog_IsAvailableOnMap( entry, mapName ) && MapEditor_IsModelOffered( entry.id ) )
		return entry.model

	printt( format( "[MAPEDIT] id %d not offered/available on %s; using empty_model", file.catalogId, mapName ) )
	return $"mdl/dev/empty_model.rmdl"
}

void function MapEdit_SelectDefaultModel()
{
	file.catalogId = 0
	file.modelDirty = false

	string mapName = GetMapName()
	array< MapEditorCatalogEntry > ordered = MapEdit_CollectMapAvailableOrdered_Client( mapName )
	foreach ( MapEditorCatalogEntry entry in ordered )
	{
		if ( !MapEditor_IsModelOffered( entry.id ) )
			continue

		file.catalogId = entry.id
		file.modelDirty = true
		printt( format( "[MAPEDIT] default model id=%d on map %s", entry.id, mapName ) )
		return
	}

	printt( format( "[MAPEDIT] no offered catalog model on map %s; no default selected", mapName ) )
}

// Same order as server: build-tier by id, then extra-tier by id.
array< MapEditorCatalogEntry > function MapEdit_CollectMapAvailableOrdered_Client( string mapName )
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

	buildList.sort( MapEdit_CompareCatalogId_Client )
	extraList.sort( MapEdit_CompareCatalogId_Client )

	array< MapEditorCatalogEntry > result
	foreach ( MapEditorCatalogEntry entry in buildList )
		result.append( entry )
	foreach ( MapEditorCatalogEntry entry in extraList )
		result.append( entry )

	return result
}

int function MapEdit_CompareCatalogId_Client( MapEditorCatalogEntry a, MapEditorCatalogEntry b )
{
	if ( a.id < b.id )
		return -1
	if ( a.id > b.id )
		return 1
	return 0
}

// ---------------------------------------------------------------------------
// Extra map packs -- server sends a catalog bit, the name comes from our own
// catalog copy. The model browser reads availability live, so updating the
// mask is the menu refresh.
// ---------------------------------------------------------------------------

void function MapEdit_ClientRegisterNetworking()
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

void function ServerCallback_MapEdit_PackLoad( int bit )
{
	MapEditorCatalog_Init()

	if ( bit < 0 || bit > 31 )
	{
		printt( "[MAPEDIT] PackLoad: bit out of range" )
		return
	}

	string name = MapEditorCatalog_GetMapNameForBit( bit )
	if ( name == "" )
	{
		printt( format( "[MAPEDIT] PackLoad: unknown bit %d", bit ) )
		return
	}

	if ( ( file.activePackMask & ( 1 << bit ) ) != 0 )
	{
		printt( format( "[MAPEDIT] PackLoad: bit %d (%s) already active", bit, name ) )
		return
	}

	if ( !MapEdit_RequestMapPak( name ) )
	{
		printt( format( "[MAPEDIT] PackLoad: load rejected for %s", name ) )
		return
	}

	printt( format( "[MAPEDIT] PackLoad: loading %s bit=%d", name, bit ) )
	thread MapEdit_ClientPackLoadThread( bit, name )
}

void function ServerCallback_MapEdit_PackRefused( int bit, int reason )
{
	RunUIScript( "UI_MapEditor_OnPackRefused", bit, reason )
}

void function MapEdit_ClientPackLoadThread( int bit, string name )
{
	float deadline = Time() + 60.0

	while ( Time() < deadline )
	{
		int status = MapEdit_MapPakStatus( name )
		if ( status == 1 )
		{
			file.activePackMask = file.activePackMask | ( 1 << bit )
			MapEditorCatalog_SetActivePackMask( file.activePackMask )
			RunUIScript( "UI_MapEditor_SetActivePackMask", file.activePackMask )

			if ( file.catalogId == 0 )
				MapEdit_SelectDefaultModel()
			MapEdit_RefreshPanel()

			Remote_ServerCallFunction( "MapEdit_SV_PackReady", bit )

			printt( format( "[MAPEDIT] client pack loaded: %s bit=%d mask=%d", name, bit, file.activePackMask ) )
			return
		}

		if ( status == -1 )
		{
			printt( format( "[MAPEDIT] client pack load failed: %s bit=%d", name, bit ) )
			return
		}

		wait 0.25
	}

	printt( format( "[MAPEDIT] client pack load timed out: %s bit=%d", name, bit ) )
}

// ---------------------------------------------------------------------------
// Build mode toggle
// ---------------------------------------------------------------------------

void function MapEdit_OnToggleBuildMode( entity player )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	// The server swaps the tool in or out; MapEdit_ToolWatchThread follows the weapon in hand.
	player.ClientCommand( file.buildMode ? "mapedit_build 0" : "mapedit_build 1" )
}

bool function MapEdit_HoldingTool( entity player )
{
	entity active = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	return IsValid( active ) && active.GetWeaponClassName() == MAPEDIT_TOOL_WEAPON
}

// Build mode is holding the tool. Tacticals and ultimates borrow the main hand
// for a moment, so an offhand in hand changes nothing.
void function MapEdit_ToolWatchThread( entity player )
{
	player.EndSignal( "OnDestroy" )
	while ( true )
	{
		WaitFrame()
		bool charSelect = CharacterSelect_MenuIsOpen()
		if ( charSelect != file.hudCharSelect )
		{
			file.hudCharSelect = charSelect
			MapEdit_RefreshPanel()
		}
		if ( !IsAlive( player ) || file.hudSuppressed )
		{
			file.toolMismatchSince = -1.0
			continue
		}
		entity active = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
		if ( IsValid( active ) && active.IsWeaponOffhand() )
		{
			file.toolMismatchSince = -1.0
			continue
		}
		bool holding = MapEdit_HoldingTool( player )
		if ( holding == file.buildMode )
		{
			file.toolMismatchSince = -1.0
			continue
		}
		if ( file.toolMismatchSince < 0.0 )
			file.toolMismatchSince = Time()
		if ( Time() - file.toolMismatchSince < MAPEDIT_TOOL_SETTLE )
			continue
		file.toolMismatchSince = -1.0
		if ( holding )
			MapEdit_EnterBuildMode( player )
		else
			MapEdit_ExitBuildMode( player )
	}
}

// Fires when the local client player is ready (same callback as cl_spectator_mode_audio).
void function MapEdit_OnYouRespawned()
{
	if ( !MapEditor_IsEnabled() )
		return

	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	// The ghost thread ends with the old life; build mode itself carries over.
	if ( file.autoStarted )
	{
		if ( file.buildMode && !IsValid( file.ghost ) )
		{
			MapEdit_CreateGhost()
			if ( IsValid( file.ghost ) )
				thread MapEdit_GhostUpdateThread( player, file.ghost )
		}
		return
	}

	file.autoStarted = true

	if ( !file.prefsRequested )
	{
		file.prefsRequested = true
		player.ClientCommand( "mapedit_prefs_get" )
	}

	thread MapEdit_ToolWatchThread( player )
	if ( file.buildMode )
		return

	player.ClientCommand( "mapedit_build 1" )
	AnnouncementMessageRight( player, format( "Build mode auto-on (toggle: %s)", MapEdit_KeyLabel( file.keyToggle ) ),
		Localize( "#MAPEDIT_HINT_TOOLS" ), <1, 1, 1>, $"", 6.0 )
	printt( "[MAPEDIT] auto-started build mode on spawn; toggle with " + MapEdit_KeyLabel( file.keyToggle ) )
}

void function MapEdit_EnterBuildMode( entity player )
{
	if ( file.buildMode )
		return

	file.buildMode = true
	file.specialId = 0
	file.zOffset = 0.0
	file.angleOffset = <0, 0, 0>
	file.hasPlacement = false

	MapEdit_CreateGhost()
	MapEdit_RegisterBuildBinds()
	MapEdit_ShowPanel()

	if ( IsValid( player ) && IsValid( file.ghost ) )
		thread MapEdit_GhostUpdateThread( player, file.ghost )

	AnnouncementMessageRight( player, "Build mode ON", "", <1, 1, 1>, $"", 3.0 )
	printt( "[MAPEDIT] build mode on" )
}

void function MapEdit_ExitBuildMode( entity player )
{
	if ( !file.buildMode )
		return

	file.buildMode = false
	file.placeHeld = false
	MapEdit_DeregisterBuildBinds()
	MapEdit_RefreshPanel()
	if ( IsValid( player ) )
		player.ClientCommand( "mapedit_build 0" )

	// Leaving mid-zipline would strand the anchor on the server.
	if ( file.ziplinePending && IsValid( player ) )
		player.ClientCommand( "mapedit_zipline_cancel" )
	file.ziplinePending = false

	if ( IsValid( player ) )
		player.Signal( "MapEdit_BuildModeOff" )

	if ( IsValid( file.ghost ) )
	{
		file.ghost.Destroy()
		file.ghost = null
	}

	file.hasPlacement = false

	if ( IsValid( player ) )
		AnnouncementMessageRight( player, format( "Weapons out (%s to build)", MapEdit_KeyLabel( file.keyToggle ) ), "", <1, 1, 1>, $"", 3.0 )
	printt( "[MAPEDIT] build mode off" )
}

// ---------------------------------------------------------------------------
// Bind registration (symmetric with deregistration)
// ---------------------------------------------------------------------------

// Every action below is a real bindable S21 ConCommand, so it follows
// whatever the player set. The legend kit and weapon selection are
// deliberately untouched: +offhand1 (tactical), +offhand4 (ultimate), +melee,
// +scriptCommand4 (heal), +ping, +jump, +duck, +use, +speed, the weapon
// select keys and weapon cycle are never hooked, so abilities, movement and
// switching away from the tool keep working.
void function MapEdit_RegisterBuildBinds()
{
	RegisterConCommandTriggeredCallback( "+attack", MapEdit_OnPlacePress )
	RegisterConCommandTriggeredCallback( "-attack", MapEdit_OnPlaceRelease )
	RegisterConCommandTriggeredCallback( "+reload", MapEdit_OnDelete )
	// Switch fire mode: an editor has no fire modes to switch.
	RegisterConCommandTriggeredCallback( "+scriptCommand3", MapEdit_OnUndo )
	RegisterConCommandTriggeredCallback( "+use_alt", MapEdit_OnCycleSnap )
	// Gib shield toggle: cosmetic, and nothing in the editor uses it.
	RegisterConCommandTriggeredCallback( "+scriptCommand5", MapEdit_OnZiplineAnchor )
	RegisterConCommandTriggeredCallback( "weapon_inspect", MapEdit_OnOpenModelBrowser )

	// Re-picked per session so a bind changed since the last one is respected.
	MapEdit_AssignBuildKeys()
	RegisterButtonPressedCallback( file.keyNoclip, MapEdit_OnToggleNoclipKey )
	RegisterButtonPressedCallback( file.keyYawCcw, MapEdit_OnRotateYawCCWKey )
	RegisterButtonPressedCallback( file.keyYawCw, MapEdit_OnRotateYawCWKey )
	RegisterButtonPressedCallback( file.keyWhois, MapEdit_OnWhoisKey )
	RegisterButtonPressedCallback( file.keyPacks, MapEdit_OnMapPacksKey )
	RegisterButtonPressedCallback( file.keyCycle, MapEdit_OnCycleSlotKey )
	RegisterButtonPressedCallback( file.keyRot90, MapEdit_OnRot90Key )
	RegisterButtonPressedCallback( file.keyAxis, MapEdit_OnAxisKey )
	RegisterButtonPressedCallback( file.keyResetRot, MapEdit_OnResetRotKey )
	RegisterButtonPressedCallback( file.keyPick, MapEdit_OnPickKey )
	RegisterButtonPressedCallback( file.slotKeys[0], MapEdit_OnSlot0Key )
	RegisterButtonPressedCallback( file.slotKeys[1], MapEdit_OnSlot1Key )
	RegisterButtonPressedCallback( file.slotKeys[2], MapEdit_OnSlot2Key )
	RegisterButtonPressedCallback( file.keyAir, MapEdit_OnAirKey )
	RegisterButtonPressedCallback( file.keyReachIn, MapEdit_OnReachInKey )
	RegisterButtonPressedCallback( file.keyReachOut, MapEdit_OnReachOutKey )
	RegisterButtonPressedCallback( file.keyRaise, MapEdit_OnRaiseKey )
	RegisterButtonPressedCallback( file.keyLower, MapEdit_OnLowerKey )
	MapEdit_RegisterPadBinds()
}

void function MapEdit_DeregisterBuildBinds()
{
	DeregisterConCommandTriggeredCallback( "+attack", MapEdit_OnPlacePress )
	DeregisterConCommandTriggeredCallback( "-attack", MapEdit_OnPlaceRelease )
	DeregisterConCommandTriggeredCallback( "+reload", MapEdit_OnDelete )
	DeregisterConCommandTriggeredCallback( "+scriptCommand3", MapEdit_OnUndo )
	DeregisterConCommandTriggeredCallback( "+use_alt", MapEdit_OnCycleSnap )
	DeregisterConCommandTriggeredCallback( "+scriptCommand5", MapEdit_OnZiplineAnchor )
	DeregisterConCommandTriggeredCallback( "weapon_inspect", MapEdit_OnOpenModelBrowser )

	DeregisterButtonPressedCallback( file.keyNoclip, MapEdit_OnToggleNoclipKey )
	DeregisterButtonPressedCallback( file.keyYawCcw, MapEdit_OnRotateYawCCWKey )
	DeregisterButtonPressedCallback( file.keyYawCw, MapEdit_OnRotateYawCWKey )
	DeregisterButtonPressedCallback( file.keyWhois, MapEdit_OnWhoisKey )
	DeregisterButtonPressedCallback( file.keyPacks, MapEdit_OnMapPacksKey )
	DeregisterButtonPressedCallback( file.keyCycle, MapEdit_OnCycleSlotKey )
	DeregisterButtonPressedCallback( file.keyRot90, MapEdit_OnRot90Key )
	DeregisterButtonPressedCallback( file.keyAxis, MapEdit_OnAxisKey )
	DeregisterButtonPressedCallback( file.keyResetRot, MapEdit_OnResetRotKey )
	DeregisterButtonPressedCallback( file.keyPick, MapEdit_OnPickKey )
	DeregisterButtonPressedCallback( file.slotKeys[0], MapEdit_OnSlot0Key )
	DeregisterButtonPressedCallback( file.slotKeys[1], MapEdit_OnSlot1Key )
	DeregisterButtonPressedCallback( file.slotKeys[2], MapEdit_OnSlot2Key )
	DeregisterButtonPressedCallback( file.keyAir, MapEdit_OnAirKey )
	DeregisterButtonPressedCallback( file.keyReachIn, MapEdit_OnReachInKey )
	DeregisterButtonPressedCallback( file.keyReachOut, MapEdit_OnReachOutKey )
	DeregisterButtonPressedCallback( file.keyRaise, MapEdit_OnRaiseKey )
	DeregisterButtonPressedCallback( file.keyLower, MapEdit_OnLowerKey )
	MapEdit_DeregisterPadBinds()
}

// ---------------------------------------------------------------------------
// Key choice
// ---------------------------------------------------------------------------

bool function MapEdit_KeyFree( int key, array<int> taken )
{
	if ( file.reservedKeys.contains( key ) || taken.contains( key ) )
		return false
	return GetKeyTappedBinding( key ) == "" && GetKeyHeldBinding( key ) == ""
}

// Every pool key bound: take the first one the recorder does not own and say so.
int function MapEdit_PickKey( array<int> pool, array<int> taken )
{
	foreach ( int key in pool )
	{
		if ( MapEdit_KeyFree( key, taken ) )
		{
			taken.append( key )
			return key
		}
	}
	foreach ( int key in pool )
	{
		if ( !file.reservedKeys.contains( key ) && !taken.contains( key ) )
		{
			taken.append( key )
			printt( "[MAPEDIT] no unbound key left; " + MapEdit_KeyLabel( key ) + " also runs its own bind" )
			return key
		}
	}
	return pool[0]
}

void function MapEdit_AssignBuildKeys()
{
	array<int> taken = [ file.keyToggle ]

	file.keyYawCcw = -1
	for ( int i = 0; i + 1 < file.yawPairs.len(); i += 2 )
	{
		int ccw = file.yawPairs[i]
		int cw = file.yawPairs[i + 1]
		if ( MapEdit_KeyFree( ccw, taken ) && MapEdit_KeyFree( cw, taken ) )
		{
			file.keyYawCcw = ccw
			file.keyYawCw = cw
			break
		}
	}
	if ( file.keyYawCcw < 0 )
	{
		file.keyYawCcw = MapEdit_PickKey( file.yawPairs, taken )
		file.keyYawCw = MapEdit_PickKey( file.yawPairs, taken )
	}
	else
	{
		taken.append( file.keyYawCcw )
		taken.append( file.keyYawCw )
	}

	file.keyRaise = -1
	for ( int i = 0; i + 1 < file.heightPairs.len(); i += 2 )
	{
		if ( MapEdit_KeyFree( file.heightPairs[i], taken ) && MapEdit_KeyFree( file.heightPairs[i + 1], taken ) )
		{
			file.keyRaise = file.heightPairs[i]
			file.keyLower = file.heightPairs[i + 1]
			taken.append( file.keyRaise )
			taken.append( file.keyLower )
			break
		}
	}
	if ( file.keyRaise < 0 )
	{
		file.keyRaise = MapEdit_PickKey( file.letterKeys, taken )
		file.keyLower = MapEdit_PickKey( file.letterKeys, taken )
	}

	file.keyNoclip = MapEdit_PickKey( file.singleKeys, taken )
	file.keyPacks = MapEdit_PickKey( file.singleKeys, taken )
	file.keyWhois = MapEdit_PickKey( file.singleKeys, taken )

	// Quick slots want three keys in a row; the first triple the player left free wins.
	file.slotKeys = [ -1, -1, -1 ]
	foreach ( array< int > triple in file.slotTriples )
	{
		if ( MapEdit_KeyFree( triple[0], taken ) && MapEdit_KeyFree( triple[1], taken ) && MapEdit_KeyFree( triple[2], taken ) )
		{
			file.slotKeys = [ triple[0], triple[1], triple[2] ]
			break
		}
	}
	if ( file.slotKeys[0] < 0 )
	{
		for ( int i = 0; i < MAPEDIT_HOTBAR_SLOTS; i++ )
			file.slotKeys[i] = MapEdit_PickKey( file.letterKeys, taken )
	}
	else
	{
		foreach ( int k in file.slotKeys )
			taken.append( k )
	}

	array< int > verbPool = clone file.letterKeys
	foreach ( int k in file.singleKeys )
		verbPool.append( k )
	file.keyCycle = MapEdit_PickKey( verbPool, taken )
	file.keyRot90 = MapEdit_PickKey( verbPool, taken )
	file.keyAxis = MapEdit_PickKey( verbPool, taken )
	file.keyResetRot = MapEdit_PickKey( verbPool, taken )
	file.keyPick = MapEdit_PickKey( verbPool, taken )
	file.keyAir = MapEdit_PickKey( verbPool, taken )

	// Reach wants a pair; take the first free yaw-style pair left over.
	file.keyReachIn = -1
	for ( int i = 0; i + 1 < file.yawPairs.len(); i += 2 )
	{
		if ( MapEdit_KeyFree( file.yawPairs[i], taken ) && MapEdit_KeyFree( file.yawPairs[i + 1], taken ) )
		{
			file.keyReachIn = file.yawPairs[i]
			file.keyReachOut = file.yawPairs[i + 1]
			taken.append( file.keyReachIn )
			taken.append( file.keyReachOut )
			break
		}
	}
	if ( file.keyReachIn < 0 )
	{
		file.keyReachIn = MapEdit_PickKey( verbPool, taken )
		file.keyReachOut = MapEdit_PickKey( verbPool, taken )
	}

	printt( format( "[MAPEDIT] keys: slots %s %s %s, cycle %s, rotate90 %s, axis %s, reset %s, pick %s, air %s, reach %s/%s",
		MapEdit_KeyLabel( file.slotKeys[0] ), MapEdit_KeyLabel( file.slotKeys[1] ), MapEdit_KeyLabel( file.slotKeys[2] ),
		MapEdit_KeyLabel( file.keyCycle ), MapEdit_KeyLabel( file.keyRot90 ), MapEdit_KeyLabel( file.keyAxis ),
		MapEdit_KeyLabel( file.keyResetRot ), MapEdit_KeyLabel( file.keyPick ), MapEdit_KeyLabel( file.keyAir ),
		MapEdit_KeyLabel( file.keyReachIn ), MapEdit_KeyLabel( file.keyReachOut ) ) )
	MapEdit_PushKeysToUI()

	printt( format( "[MAPEDIT] keys: toggle %s, rotate %s/%s, height %s/%s, noclip %s, map packs %s, owner %s",
		MapEdit_KeyLabel( file.keyToggle ), MapEdit_KeyLabel( file.keyYawCcw ), MapEdit_KeyLabel( file.keyYawCw ),
		MapEdit_KeyLabel( file.keyRaise ), MapEdit_KeyLabel( file.keyLower ),
		MapEdit_KeyLabel( file.keyNoclip ), MapEdit_KeyLabel( file.keyPacks ), MapEdit_KeyLabel( file.keyWhois ) ) )
}

// Bind-table names, which the HUD glyph tokens use.
string function MapEdit_KeyLabel( int key )
{
	switch ( key )
	{
		case KEY_F3: return "F3"
		case KEY_F10: return "F10"
		case KEY_F11: return "F11"
		case KEY_HOME: return "HOME"
		case KEY_END: return "END"
		case KEY_INSERT: return "INS"
		case KEY_DELETE: return "DEL"
		case KEY_PAGEUP: return "PGUP"
		case KEY_PAGEDOWN: return "PGDN"
		case KEY_COMMA: return ","
		case KEY_PERIOD: return "."
		case KEY_MINUS: return "-"
		case KEY_EQUAL: return "="
		case KEY_SEMICOLON: return ";"
		case KEY_APOSTROPHE: return "'"
		case KEY_UP: return "UPARROW"
		case KEY_DOWN: return "DOWNARROW"
		case KEY_0: return "0"
		case KEY_6: return "6"
		case KEY_7: return "7"
		case KEY_8: return "8"
		case KEY_9: return "9"
		case KEY_H: return "H"
		case KEY_I: return "I"
		case KEY_J: return "J"
		case KEY_K: return "K"
		case KEY_L: return "L"
		case KEY_N: return "N"
		case KEY_O: return "O"
		case KEY_P: return "P"
		case KEY_T: return "T"
		case KEY_U: return "U"
		case KEY_Y: return "Y"
	}
	return "?"
}

string function MapEdit_KeyGlyph( int key )
{
	return MapEdit_Glyph( "", key )
}

// ---------------------------------------------------------------------------
// Raw-key entry points (button callbacks pass the button, not the player)
// ---------------------------------------------------------------------------

void function MapEdit_OnToggleBuildModeKey( var button )
{
	MapEdit_OnToggleBuildMode( GetLocalClientPlayer() )
}

void function MapEdit_OnToggleNoclipKey( var button )
{
	MapEdit_OnToggleNoclip( GetLocalClientPlayer() )
}

void function MapEdit_OnRotateYawCCWKey( var button )
{
	MapEdit_RotateYaw( GetLocalClientPlayer(), -1 )
}

void function MapEdit_OnRotateYawCWKey( var button )
{
	MapEdit_RotateYaw( GetLocalClientPlayer(), 1 )
}

void function MapEdit_OnWhoisKey( var button )
{
	MapEdit_OnWhois( GetLocalClientPlayer() )
}

void function MapEdit_OnRaiseKey( var button )
{
	MapEdit_OnRaise( GetLocalClientPlayer() )
}

void function MapEdit_OnLowerKey( var button )
{
	MapEdit_OnLower( GetLocalClientPlayer() )
}

void function MapEdit_OnMapPacksKey( var button )
{
	if ( file.buildMode )
		RunUIScript( "OpenMapEditorMapPacks" )
}

// ---------------------------------------------------------------------------
// Key panel (the movement recorder's panel, in editor mode)
// ---------------------------------------------------------------------------

void function MapEdit_ShowPanel()
{
	file.hudShown = true
	MapEdit_RefreshPanel()
}

void function MapEdit_HidePanel()
{
	file.hudShown = false
	MapEdit_HudDestroy()
}

string function MapEdit_PanelModelName()
{
	if ( file.specialId > 0 )
		return MapEdit_SpecialName( file.specialId )
	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
	if ( entryOrNull == null )
		return "none"
	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
	return entry.category + " #" + string( entry.id )
}

var function MapEdit_Hud()
{
	if ( file.hudRui != null )
		return file.hudRui
	try
	{
		asset a = GetKeyValueAsAsset( { kn = "ui/fs_mapedit_hud.rpak" }, "kn" )
		file.hudRui = CreateCockpitPostFXRui( a, 0 )
		asset k = GetKeyValueAsAsset( { kn = "ui/fs_mapedit_keys.rpak" }, "kn" )
		file.hudKeysRui = CreateCockpitPostFXRui( k, 1 )
	}
	catch ( eCreate )
	{
		printt( "[MAPEDIT] build panel create failed: " + string( eCreate ) )
		MapEdit_HudDestroy()
	}
	return file.hudRui
}

void function MapEdit_HudDestroy()
{
	if ( file.hudRui != null )
		RuiDestroyIfAlive( file.hudRui )
	if ( file.hudKeysRui != null )
		RuiDestroyIfAlive( file.hudKeysRui )
	file.hudRui = null
	file.hudKeysRui = null
}

void function MapEdit_HudCol( var rui, string name, vector rgb, float a )
{
	RuiSetColorAlpha( rui, name, SrgbToLinear( rgb ), a )
}

void function MapEdit_HudRow( var rui, string row, string key, string label, string key2 = "", string label2 = "", string val = "" )
{
	var keyRui = ( row == "s3" || row == "s4" || row == "all" ) ? file.hudKeysRui : rui
	if ( keyRui != null )
	{
		RuiSetString( keyRui, row + "Key", key )
		RuiSetString( keyRui, row + "Key2", key2 )
	}
	RuiSetString( rui, row + "Label", label )
	RuiSetString( rui, row + "Label2", label2 )
	RuiSetString( rui, row + "Val", val )
	MapEdit_HudCol( rui, row + "LabelColor", MAPEDIT_HUD_TEXT, 1.0 )
	MapEdit_HudCol( rui, row + "ValBg", <1, 1, 1>, val != "" ? 0.08 : 0.0 )
}

// Header, model line and panel size shared by both layouts.
void function MapEdit_HudFrame( var rui, bool build )
{
	vector tag = build ? MAPEDIT_HUD_ACCENT : MAPEDIT_HUD_WEAPONS_COLOR
	MapEdit_HudCol( rui, "accentColor", MAPEDIT_HUD_ACCENT, 1.0 )
	MapEdit_HudCol( rui, "tagColor", tag, 1.0 )
	RuiSetString( rui, "tagText", Localize( build ? "#MAPEDIT_HUD_BUILD" : "#MAPEDIT_HUD_WEAPONS" ).toupper() )
	RuiSetString( rui, "toggleKey", MapEdit_KeyGlyph( file.keyToggle ) )
	RuiSetString( rui, "toggleText", Localize( build ? "#MAPEDIT_HUD_WEAPONS" : "#MAPEDIT_HUD_BUILDMODE" ) )
	RuiSetString( rui, "modelText", MapEdit_PanelModelName() )

	bool toast = file.hudToastUntil > Time()
	RuiSetString( rui, "noteText", toast ? file.hudToast : Localize( "#MAPEDIT_HUD_AUTOSAVE" ) )
	MapEdit_HudCol( rui, "noteColor", toast ? file.hudToastColor : MAPEDIT_HUD_NOTE, 1.0 )

	float bottom = MAPEDIT_HUD_Y + ( build ? MAPEDIT_HUD_H_BUILD : MAPEDIT_HUD_H_WEAPONS )
	RuiSetFloat2( rui, "panelBL", < MAPEDIT_HUD_X / 1920.0, bottom / 1080.0, 0 > )
	RuiSetFloat2( rui, "panelBR", < ( MAPEDIT_HUD_X + MAPEDIT_HUD_W ) / 1920.0, bottom / 1080.0, 0 > )
	RuiSetFloat2( rui, "panelBL1", < MAPEDIT_HUD_X / 1920.0, ( bottom - 1.0 ) / 1080.0, 0 > )
}

void function MapEdit_RefreshPanel()
{
	if ( !MapEditor_IsEnabled() || !file.autoStarted || !file.hudShown || file.hudSuppressed || CharacterSelect_MenuIsOpen() )
	{
		MapEdit_HudDestroy()
		return
	}
	var rui = MapEdit_Hud()
	if ( rui == null )
		return

	MapEdit_HudFrame( rui, file.buildMode )
	if ( !file.buildMode )
	{
		MapEdit_HudRow( rui, "rec", MapEdit_KeyGlyph( file.keyToggle ), Localize( "#MAPEDIT_HUD_BUILDMODE" ) )
		foreach ( string row in [ "s0", "s1", "s2", "s3", "s4", "all" ] )
			MapEdit_HudRow( rui, row, "", "" )
		RuiSetString( rui, "head0Text", "" )
		RuiSetString( rui, "head1Text", "" )
		return
	}

	float snapSize = MapEdit_GetSnapSize()
	float axisValue = file.rotAxis == 0 ? file.angleOffset.x : ( file.rotAxis == 2 ? file.angleOffset.z : file.angleOffset.y )
	string axisName = MapEdit_AxisName().slice( 0, 1 ) + MapEdit_AxisName().slice( 1 ).tolower()

	RuiSetString( rui, "head0Text", Localize( "#MAPEDIT_HUD_EDIT" ) )
	RuiSetString( rui, "head1Text", Localize( "#MAPEDIT_HUD_TRANSFORM" ) )
	MapEdit_HudRow( rui, "rec", "%attack%", Localize( "#MAPEDIT_HUD_PLACE" ) )
	MapEdit_HudRow( rui, "s0", "%weapon_inspect%", Localize( "#MAPEDIT_HUD_MENU" ), MapEdit_KeyGlyph( file.keyPacks ), Localize( "#MAPEDIT_HUD_MAPPACKS" ) )
	MapEdit_HudRow( rui, "s1", "%reload%", Localize( "#MAPEDIT_HUD_DELETE" ), "%scriptCommand5%", Localize( "#MAPEDIT_HUD_ZIPLINE" ) )
	MapEdit_HudRow( rui, "s2", "%scriptCommand3%", Localize( "#MAPEDIT_HUD_UNDO" ), "%[|LSHIFT]%%scriptCommand3%", Localize( "#MAPEDIT_HUD_REDO" ) )
	MapEdit_HudRow( rui, "s3", MapEdit_KeyGlyph( file.keyRaise ), Localize( "#MAPEDIT_HUD_RAISE" ), MapEdit_KeyGlyph( file.keyLower ), Localize( "#MAPEDIT_HUD_LOWER" ),
		format( "%+d", int( file.zOffset ) ) )
	MapEdit_HudRow( rui, "s4", MapEdit_KeyGlyph( file.keyYawCcw ), Localize( "#MAPEDIT_HUD_ROTATE" ), MapEdit_KeyGlyph( file.keyYawCw ), axisName,
		string( int( axisValue ) ) )
	MapEdit_HudRow( rui, "all", "%use_alt%", Localize( "#MAPEDIT_HUD_SNAPLABEL" ), "", "",
		snapSize > 0.0 ? string( int( snapSize ) ) : "OFF" )
}

void function MapEdit_RefreshWeaponsPanel()
{
	MapEdit_RefreshPanel()
}

// A few seconds of news on the panel's model line.
void function MapEdit_HudToast( string text, vector color )
{
	file.hudToast = text
	file.hudToastColor = color
	file.hudToastUntil = Time() + MAPEDIT_HUD_TOAST_HOLD
	MapEdit_RefreshPanel()
	thread MapEdit_HudToastExpire( file.hudToastUntil )
}

void function MapEdit_HudToastExpire( float until )
{
	wait MAPEDIT_HUD_TOAST_HOLD + 0.05
	if ( file.hudToastUntil == until )
		MapEdit_RefreshPanel()
}

// A full-screen editor menu owns the screen while it is open.
void function MapEdit_SetHudSuppressed( bool suppressed )
{
	file.hudSuppressed = suppressed
	MapEdit_RefreshPanel()
}

// ---------------------------------------------------------------------------
// Ghost
// ---------------------------------------------------------------------------

void function MapEdit_CreateGhost()
{
	if ( IsValid( file.ghost ) )
	{
		file.ghost.Destroy()
		file.ghost = null
	}

	// Only offered (precached) models may reach CreateClientSidePropDynamic.
	asset model = MapEdit_SelectedModel()

	entity ghost = CreateClientSidePropDynamic( <0, 0, 0>, <0, 0, 0>, model )
	if ( !IsValid( ghost ) )
	{
		printt( "[MAPEDIT] CreateClientSidePropDynamic failed" )
		return
	}

	// Same setup the other client-side props in this tree use. A render mode is
	// deliberately not set: glow mode leaves the model invisible, and fadedist
	// must be -1 or the prop fades out at close range.
	ghost.kv.solid          = 0 // NotSolid() is SERVER-only at compile
	ghost.kv.fadedist       = -1
	ghost.kv.disableshadows = 1
	Highlight_SetNeutralHighlight( ghost, "survival_item_rare" )

	file.ghost = ghost
	file.modelDirty = false
	file.smoothValid = false
}

void function MapEdit_GhostUpdateThread( entity player, entity ghost )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MapEdit_BuildModeOff" )
	ghost.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( ghost )
		{
			if ( IsValid( ghost ) )
				ghost.Destroy()
			if ( file.ghost == ghost )
				file.ghost = null
		}
	)

	bool logged = false

	while ( file.buildMode && IsValid( ghost ) && IsValid( player ) )
	{
		MapEdit_UpdateGhost( player, ghost )

		// One line on the first tick: says where the preview actually went, so an
		// invisible preview can be told apart from one placed somewhere unexpected.
		if ( !logged )
		{
			logged = true
			printt( format( "[MAPEDIT] ghost first tick: origin %s eye %s model %s",
				string( ghost.GetOrigin() ), string( player.EyePosition() ),
				string( ghost.GetModelName() ) ) )
		}

		WaitFrame()
	}
}

void function MapEdit_UpdateGhost( entity player, entity ghost )
{
	if ( !IsValid( player ) || !IsValid( ghost ) )
		return

	// 1. Camera ray, not EyePosition/GetViewVector: those only advance on a
	// simulation tick, so a per-frame update would still step at tick rate.
	vector eye = player.CameraPosition()
	vector forward = AnglesToForward( player.CameraAngles() )
	// 2. The ray stops at the reach limit: past it (or always, in Air mode) the
	// model floats at the limit instead of snapping to whatever is far away.
	vector end = eye + forward * file.reach
	TraceResults result = TraceLine( eye, end, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	bool onSurface = result.fraction < 1.0 && !file.airMode
	// Air mode never pushes the model through a wall it is aimed at.
	vector hitPos = result.endPos
	if ( file.airMode && result.fraction < 1.0 )
		hitPos = eye + forward * max( 0.0, file.reach * result.fraction - 8.0 )
	vector origin = hitPos

	// 3. Align to the surface it rests on; floating models stay upright.
	vector normal = <0, 0, 1>
	if ( onSurface )
		normal = result.surfaceNormal

	vector angles = AnglesCompose( AnglesOnSurface( normal, forward ), file.angleOffset )

	// Model change only when selection actually changed.
	if ( file.modelDirty )
	{
		ghost.SetModel( MapEdit_SelectedModel() )
		file.modelDirty = false
		// New bbox: let the preview jump straight to the new resting spot.
		file.smoothValid = false
	}

	ghost.SetAngles( angles )

	// 4. Bbox lift so the lowest point rests on the surface; a floating model
	// hangs centred on the aim point instead.
	vector mins = ghost.GetBoundingMins()
	vector maxs = ghost.GetBoundingMaxs()
	float zLift = onSurface ? -mins.z : -( mins.z + maxs.z ) * 0.5
	origin.z += zLift
	origin.z += file.zOffset

	// 5. Grid snap after surface offset; re-apply lift + Z so snap cannot bury.
	float snapSize = MapEdit_GetSnapSize()
	if ( snapSize > 0.0 )
	{
		origin.x = MapEdit_SnapCoord( origin.x, snapSize )
		origin.y = MapEdit_SnapCoord( origin.y, snapSize )
		float snappedSurfaceZ = MapEdit_SnapCoord( hitPos.z, snapSize )
		origin.z = snappedSurfaceZ + zLift + file.zOffset
	}

	// 6. Never add a raw view vector to the origin.

	// Placement uses the raw target; only what is drawn is eased.
	file.lastOrigin = origin
	file.lastAngles = angles
	file.hasPlacement = true

	MapEdit_DrawGhostEased( ghost, origin, normal, forward )
}

// Easing the surface normal and the view forward rather than the composed
// angles keeps the preview from spinning the long way round when the trace
// crosses between two faces.
void function MapEdit_DrawGhostEased( entity ghost, vector origin, vector normal, vector forward )
{
	if ( !file.smoothValid || Distance( file.smoothOrigin, origin ) > MAPEDIT_GHOST_CUT_DIST )
	{
		file.smoothOrigin = origin
		file.smoothNormal = normal
		file.smoothForward = forward
		file.smoothValid = true
	}
	else
	{
		float frac = MapEdit_EaseFraction()
		file.smoothOrigin = file.smoothOrigin + ( origin - file.smoothOrigin ) * frac
		file.smoothNormal = MapEdit_EaseDirection( file.smoothNormal, normal, frac )
		file.smoothForward = MapEdit_EaseDirection( file.smoothForward, forward, frac )
	}

	ghost.SetOrigin( file.smoothOrigin )
	ghost.SetAngles( AnglesCompose( AnglesOnSurface( file.smoothNormal, file.smoothForward ), file.angleOffset ) )
}

float function MapEdit_EaseFraction()
{
	float dt = FrameTime()
	if ( dt <= 0.0 || MAPEDIT_GHOST_SMOOTH_TIME <= 0.0 )
		return 1.0

	float frac = dt / MAPEDIT_GHOST_SMOOTH_TIME
	if ( frac > 1.0 )
		return 1.0
	return frac
}

vector function MapEdit_EaseDirection( vector from, vector to, float frac )
{
	vector blend = from + ( to - from ) * frac
	// Exactly opposed directions cancel; take the target rather than normalize 0.
	if ( Length( blend ) < 0.001 )
		return to
	return Normalize( blend )
}

float function MapEdit_GetSnapSize()
{
	if ( file.snapIndex < 0 || file.snapIndex >= file.snapSizes.len() )
		return 0.0
	return file.snapSizes[file.snapIndex]
}

float function MapEdit_SnapCoord( float value, float grid )
{
	if ( grid <= 0.0 )
		return value
	return floor( ( value / grid ) + 0.5 ) * grid
}

// ---------------------------------------------------------------------------
// Place / delete / undo
// ---------------------------------------------------------------------------

// Holding place keeps building (Fortnite-style turbo build): another piece goes
// down each time the aim target moves a piece-width away from the last one.
void function MapEdit_OnPlacePress( entity player )
{
	if ( !file.buildMode || !IsValid( player ) || player != GetLocalClientPlayer() )
		return
	MapEdit_OnPlace( player )
	file.lastTurboOrigin = file.lastOrigin
	if ( file.placeHeld )
		return
	file.placeHeld = true
	thread MapEdit_TurboThread( player )
}

void function MapEdit_OnPlaceRelease( entity player )
{
	file.placeHeld = false
}

void function MapEdit_TurboThread( entity player )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MapEdit_BuildModeOff" )
	OnThreadEnd(
		function() : ()
		{
			file.placeHeld = false
		}
	)

	wait 0.25
	while ( file.placeHeld && file.buildMode )
	{
		// Zipline anchors and palette doors are single, deliberate placements.
		if ( file.specialId == 0 && file.hasPlacement && file.catalogId > 0 && IsValid( file.ghost ) )
		{
			vector size = file.ghost.GetBoundingMaxs() - file.ghost.GetBoundingMins()
			float spacing = max( max( MAPEDIT_TURBO_MIN_SPACING, MapEdit_GetSnapSize() ), min( size.x, size.y ) * 0.9 )
			if ( Distance( file.lastOrigin, file.lastTurboOrigin ) >= spacing )
			{
				MapEdit_OnPlace( player )
				file.lastTurboOrigin = file.lastOrigin
			}
		}
		wait MAPEDIT_TURBO_INTERVAL
	}
}

void function MapEdit_OnPlace( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.specialId > 0 )
	{
		MapEdit_PlaceSpecial( player )
		return
	}

	if ( file.catalogId <= 0 )
	{
		AnnouncementMessageRight( player, "No model selected", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
	if ( entryOrNull == null )
	{
		AnnouncementMessageRight( player, "Invalid model id", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	if ( !MapEditor_IsModelOffered( file.catalogId ) )
	{
		AnnouncementMessageRight( player, "Model not precached", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	if ( !file.hasPlacement )
	{
		AnnouncementMessageRight( player, "No placement yet", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	vector origin = file.lastOrigin
	vector angles = file.lastAngles
	vector eye = player.EyePosition()

	if ( Distance( eye, origin ) > MAPEDIT_MAX_PLACE_DIST )
	{
		AnnouncementMessageRight( player, "Too far to place", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	string cmd = format( "mapedit_place %d %.2f %.2f %.2f %.2f %.2f %.2f",
		file.catalogId,
		origin.x, origin.y, origin.z,
		angles.x, angles.y, angles.z )

	player.ClientCommand( cmd )
}

void function MapEdit_PlaceSpecial( entity player )
{
	if ( !file.hasPlacement )
	{
		AnnouncementMessageRight( player, "No placement yet", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	vector origin = file.lastOrigin
	vector angles = file.lastAngles
	if ( Distance( player.EyePosition(), origin ) > MAPEDIT_MAX_PLACE_DIST )
	{
		AnnouncementMessageRight( player, "Too far to place", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	player.ClientCommand( format( "mapedit_special %d %.2f %.2f %.2f %.2f %.2f %.2f",
		file.specialId, origin.x, origin.y, origin.z, angles.x, angles.y, angles.z ) )
}

void function MapEdit_OnDelete( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_delete" )
}

void function MapEdit_OnUndo( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( InputIsButtonDown( KEY_LSHIFT ) ? "mapedit_redo" : "mapedit_undo" )
}

void function MapEdit_OnRedo( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_redo" )
}

void function MapEdit_OnWhois( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_whois" )
}

void function MapEdit_OnToggleNoclip( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	// Same path as the model viewer: engine "noclip" client command.
	player.ClientCommand( "noclip" )
	file.noclipOn = !file.noclipOn

	if ( file.noclipOn )
		AnnouncementMessageRight( player, "Noclip ON", "", <1, 1, 1>, $"", 2.0 )
	else
		AnnouncementMessageRight( player, "Noclip OFF", "", <1, 1, 1>, $"", 2.0 )
}

// One action drives both ends: the server already refuses an end without a
// start anchor, so alternating here matches the state it keeps.
void function MapEdit_OnZiplineAnchor( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.ziplinePending )
	{
		player.ClientCommand( "mapedit_zipline_end" )
		file.ziplinePending = false
		AnnouncementMessageRight( player, "Zipline placed", "", <1, 1, 1>, $"", 2.0 )
	}
	else
	{
		player.ClientCommand( "mapedit_zipline_start" )
		file.ziplinePending = true
		AnnouncementMessageRight( player, "Zipline start set -- press again for the far end", "", <1, 1, 1>, $"", 3.0 )
	}
}

// ---------------------------------------------------------------------------
// Adjustments
// ---------------------------------------------------------------------------

void function MapEdit_RotateYaw( entity player, int dir )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	MapEdit_RotateAxis( float( MAPEDIT_ANGLE_STEP * dir ) )
}

// Rotates the current axis; the active quick slot remembers the result.
void function MapEdit_RotateAxis( float delta )
{
	// Squirrel: only local vector components are assignable -- reassign whole vector.
	vector a = file.angleOffset
	if ( file.rotAxis == 0 )
		a = < MapEdit_Wrap360( a.x + delta ), a.y, a.z >
	else if ( file.rotAxis == 2 )
		a = < a.x, a.y, MapEdit_Wrap360( a.z + delta ) >
	else
		a = < a.x, MapEdit_Wrap360( a.y + delta ), a.z >
	file.angleOffset = a
	MapEdit_StoreAnglesInSlot()
	MapEdit_RefreshPanel()
	MapEdit_RefreshPanel()
}

float function MapEdit_Wrap360( float v )
{
	while ( v >= 360.0 )
		v -= 360.0
	while ( v < 0.0 )
		v += 360.0
	return v
}

string function MapEdit_AxisName()
{
	if ( file.rotAxis == 0 )
		return "PITCH"
	if ( file.rotAxis == 2 )
		return "ROLL"
	return "YAW"
}

void function MapEdit_OnRot90Key( var button )
{
	if ( file.buildMode )
		MapEdit_RotateAxis( 90.0 )
}

void function MapEdit_OnAxisKey( var button )
{
	if ( !file.buildMode )
		return
	file.rotAxis = ( file.rotAxis + 1 ) % 3
	MapEdit_RefreshPanel()
	MapEdit_RefreshPanel()
}

void function MapEdit_OnResetRotKey( var button )
{
	if ( !file.buildMode )
		return
	file.angleOffset = <0, 0, 0>
	file.rotAxis = 1
	MapEdit_StoreAnglesInSlot()
	MapEdit_RefreshPanel()
	MapEdit_RefreshPanel()
}

// ---------------------------------------------------------------------------
// Quick slots
// ---------------------------------------------------------------------------

void function MapEdit_OnSlot0Key( var button )
{
	MapEdit_SelectSlot( 0 )
}

void function MapEdit_OnSlot1Key( var button )
{
	MapEdit_SelectSlot( 1 )
}

void function MapEdit_OnSlot2Key( var button )
{
	MapEdit_SelectSlot( 2 )
}

void function MapEdit_OnCycleSlotKey( var button )
{
	MapEdit_StepSlot( 1 )
}

void function MapEdit_StepSlot( int dir )
{
	if ( !file.buildMode )
		return
	int from = file.activeSlot
	if ( from < 0 )
		from = dir > 0 ? -1 : MAPEDIT_HOTBAR_SLOTS
	for ( int step = 1; step <= MAPEDIT_HOTBAR_SLOTS; step++ )
	{
		int i = ( from + step * dir + MAPEDIT_HOTBAR_SLOTS * 2 ) % MAPEDIT_HOTBAR_SLOTS
		if ( file.slots[i].kind != 0 )
		{
			MapEdit_SelectSlot( i )
			return
		}
	}
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		AnnouncementMessageRight( player, "Quick slots are empty", "Assign models in the Models menu", <1, 1, 1>, $"", 3.0 )
}

void function MapEdit_SelectSlot( int slot )
{
	if ( !file.buildMode || slot < 0 || slot >= MAPEDIT_HOTBAR_SLOTS )
		return

	MapEditSlot s = file.slots[slot]
	if ( s.kind == 0 )
	{
		entity player = GetLocalClientPlayer()
		if ( IsValid( player ) )
			AnnouncementMessageRight( player, format( "Slot %d is empty", slot + 1 ), "Assign it in the Models menu", <1, 1, 1>, $"", 2.5 )
		return
	}

	if ( s.kind == 2 )
	{
		file.specialId = s.id
	}
	else
	{
		if ( !MapEditor_IsModelOffered( s.id ) )
		{
			entity player = GetLocalClientPlayer()
			if ( IsValid( player ) )
				AnnouncementMessageRight( player, "Model not on this map", "", <1, 1, 1>, $"", 2.5 )
			return
		}
		file.specialId = 0
		file.catalogId = s.id
	}

	file.activeSlot = slot
	file.angleOffset = s.angles
	file.modelDirty = true
	MapEdit_RefreshPanel()
	MapEdit_RefreshPanel()
}

void function MapEdit_StoreAnglesInSlot()
{
	if ( file.activeSlot < 0 )
		return
	file.slots[file.activeSlot].angles = file.angleOffset
	MapEdit_QueueSlotSync()
}

// Rotating spams presses; one command per burst reaches the server.
void function MapEdit_QueueSlotSync()
{
	if ( file.slotDirty )
		return
	file.slotDirty = true
	thread MapEdit_SlotSyncThread()
}

void function MapEdit_SlotSyncThread()
{
	wait MAPEDIT_SLOT_SYNC_DELAY
	file.slotDirty = false
	for ( int i = 0; i < MAPEDIT_HOTBAR_SLOTS; i++ )
		MapEdit_SendSlot( i )
}

void function MapEdit_SendSlot( int slot )
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return
	MapEditSlot s = file.slots[slot]
	player.ClientCommand( format( "mapedit_hotbar_set %d %d %d %.1f %.1f %.1f", slot, s.kind, s.id, s.angles.x, s.angles.y, s.angles.z ) )
}

string function MapEdit_SlotLabel( MapEditSlot s )
{
	if ( s.kind == 2 )
		return MapEdit_SpecialName( s.id )
	if ( s.kind == 1 )
	{
		MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( s.id )
		if ( e != null )
			return MapEdit_ModelStem( ( expect MapEditorCatalogEntry( e ) ).model )
	}
	return ""
}

string function MapEdit_ModelStem( asset model )
{
	string path = string( model )
	array< string > parts = split( path, "/" )
	string stem = parts.len() > 0 ? parts[parts.len() - 1] : path
	if ( stem.len() > 5 && stem.slice( stem.len() - 5, stem.len() ) == ".rmdl" )
		stem = stem.slice( 0, stem.len() - 5 )
	return stem
}

string function MapEdit_Truncate( string s, int maxLen )
{
	if ( s.len() <= maxLen )
		return s
	return s.slice( 0, maxLen - 2 ) + ".."
}

// Eyedropper: take the model under the crosshair into the current selection.
void function MapEdit_OnPickKey( var button )
{
	entity player = GetLocalClientPlayer()
	if ( !file.buildMode || !IsValid( player ) )
		return

	vector eye = player.CameraPosition()
	vector end = eye + AnglesToForward( player.CameraAngles() ) * MAPEDIT_TRACE_DIST
	array< entity > ignore = [ player ]
	if ( IsValid( file.ghost ) )
		ignore.append( file.ghost )
	TraceResults tr = TraceLine( eye, end, ignore, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	entity hit = tr.hitEnt
	if ( !IsValid( hit ) )
	{
		AnnouncementMessageRight( player, "Nothing to pick", "", <1, 1, 1>, $"", 2.0 )
		return
	}

	string modelName = hit.GetModelName()
	foreach ( string category in MapEditorCatalog_GetCategories() )
	{
		foreach ( MapEditorCatalogEntry entry in MapEditorCatalog_GetCategoryEntries( category ) )
		{
			if ( string( entry.model ) != modelName )
				continue
			if ( !MapEditor_IsModelOffered( entry.id ) )
				break
			file.specialId = 0
			file.catalogId = entry.id
			file.modelDirty = true
			vector hitAngles = hit.GetAngles()
			file.angleOffset = < MapEdit_Wrap360( hitAngles.x ), MapEdit_Wrap360( hitAngles.y ), MapEdit_Wrap360( hitAngles.z ) >
			if ( file.activeSlot >= 0 )
			{
				file.slots[file.activeSlot].kind = 1
				file.slots[file.activeSlot].id = entry.id
				MapEdit_StoreAnglesInSlot()
			}
			MapEdit_RefreshPanel()
			MapEdit_RefreshPanel()
			AnnouncementMessageRight( player, "Picked " + MapEdit_ModelStem( entry.model ), "", <1, 1, 1>, $"", 2.0 )
			return
		}
	}
	AnnouncementMessageRight( player, "That model is not in the catalog", "", <1, 1, 1>, $"", 2.0 )
}

// ---------------------------------------------------------------------------
// Reach and Air mode
// ---------------------------------------------------------------------------

void function MapEdit_OnAirKey( var button )
{
	if ( !file.buildMode )
		return
	file.airMode = !file.airMode
	file.smoothValid = false
	MapEdit_RefreshPanel()
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		AnnouncementMessageRight( player, file.airMode ? "Air placement ON" : "Air placement OFF",
			file.airMode ? "Models float at your reach distance" : "Models land on the surface you aim at", <1, 1, 1>, $"", 2.5 )
}

void function MapEdit_OnReachInKey( var button )
{
	MapEdit_StepReach( -1 )
}

void function MapEdit_OnReachOutKey( var button )
{
	MapEdit_StepReach( 1 )
}

void function MapEdit_StepReach( int dir )
{
	if ( !file.buildMode )
		return
	float step = file.reach >= 1024.0 ? MAPEDIT_REACH_STEP * 4.0 : MAPEDIT_REACH_STEP
	file.reach = clamp( file.reach + step * float( dir ), MAPEDIT_REACH_MIN, MAPEDIT_REACH_MAX )
	MapEdit_RefreshPanel()
}

// ---------------------------------------------------------------------------
// Controller: D-pad left/right slots, up/down reach, L3 rotate 90 (hold: axis),
// R3 air placement. Place/delete/undo/raise ride the player's own binds.
// ---------------------------------------------------------------------------

void function MapEdit_RegisterPadBinds()
{
	RegisterButtonPressedCallback( BUTTON_DPAD_LEFT, MapEdit_OnPadLeft )
	RegisterButtonPressedCallback( BUTTON_DPAD_RIGHT, MapEdit_OnPadRight )
	RegisterButtonPressedCallback( BUTTON_DPAD_UP, MapEdit_OnReachOutKey )
	RegisterButtonPressedCallback( BUTTON_DPAD_DOWN, MapEdit_OnReachInKey )
	RegisterButtonPressedCallback( BUTTON_STICK_LEFT, MapEdit_OnPadL3Down )
	RegisterButtonReleasedCallback( BUTTON_STICK_LEFT, MapEdit_OnPadL3Up )
	RegisterButtonPressedCallback( BUTTON_STICK_RIGHT, MapEdit_OnAirKey )
}

void function MapEdit_DeregisterPadBinds()
{
	DeregisterButtonPressedCallback( BUTTON_DPAD_LEFT, MapEdit_OnPadLeft )
	DeregisterButtonPressedCallback( BUTTON_DPAD_RIGHT, MapEdit_OnPadRight )
	DeregisterButtonPressedCallback( BUTTON_DPAD_UP, MapEdit_OnReachOutKey )
	DeregisterButtonPressedCallback( BUTTON_DPAD_DOWN, MapEdit_OnReachInKey )
	DeregisterButtonPressedCallback( BUTTON_STICK_LEFT, MapEdit_OnPadL3Down )
	DeregisterButtonReleasedCallback( BUTTON_STICK_LEFT, MapEdit_OnPadL3Up )
	DeregisterButtonPressedCallback( BUTTON_STICK_RIGHT, MapEdit_OnAirKey )
}

void function MapEdit_OnPadLeft( var button )
{
	MapEdit_StepSlot( -1 )
}

void function MapEdit_OnPadRight( var button )
{
	MapEdit_StepSlot( 1 )
}

void function MapEdit_OnPadL3Down( var button )
{
	file.padL3Down = Time()
}

void function MapEdit_OnPadL3Up( var button )
{
	if ( file.padL3Down < 0.0 )
		return
	bool held = Time() - file.padL3Down >= MAPEDIT_PAD_HOLD
	file.padL3Down = -1.0
	if ( held )
		MapEdit_OnAxisKey( button )
	else
		MapEdit_OnRot90Key( button )
}

// Key cap token that follows the active input: pad glyph on a controller, key glyph otherwise.
// Keycap token: the pad button when a controller is in use, the key otherwise.
string function MapEdit_Glyph( string pad, int key )
{
	if ( key < 0 )
		return pad != "" ? "%[" + pad + "|]%" : ""
	string name = key == KEY_SEMICOLON ? "SEMICOLON" : MapEdit_KeyLabel( key )
	return "%[" + pad + "|" + name + "]%"
}

// ---------------------------------------------------------------------------
// UI bridge
// ---------------------------------------------------------------------------

asset function MapEditor_PreviewModelFor( int catalogId, int specialId )
{
	if ( specialId > 0 )
		return MapEdit_SpecialModel( specialId )
	MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( catalogId )
	if ( e == null || !MapEditor_IsModelOffered( catalogId ) )
		return $"mdl/dev/empty_model.rmdl"
	return ( expect MapEditorCatalogEntry( e ) ).model
}

void function UIToClient_MapEditor_AssignSlot( int slot, int catalogId, int specialId )
{
	if ( slot < 0 || slot >= MAPEDIT_HOTBAR_SLOTS )
		return
	if ( specialId > 0 )
	{
		if ( specialId > 5 )
			return
		file.slots[slot].kind = 2
		file.slots[slot].id = specialId
	}
	else
	{
		if ( MapEditorCatalog_GetEntry( catalogId ) == null )
			return
		file.slots[slot].kind = 1
		file.slots[slot].id = catalogId
	}
	file.slots[slot].angles = <0, 0, 0>
	MapEdit_SendSlot( slot )
	MapEdit_PushSlotToUI( slot )
	MapEdit_RefreshPanel()
}

void function UIToClient_MapEditor_ClearSlot( int slot )
{
	if ( slot < 0 || slot >= MAPEDIT_HOTBAR_SLOTS )
		return
	file.slots[slot].kind = 0
	file.slots[slot].id = 0
	file.slots[slot].angles = <0, 0, 0>
	if ( file.activeSlot == slot )
		file.activeSlot = -1
	MapEdit_SendSlot( slot )
	MapEdit_PushSlotToUI( slot )
	MapEdit_RefreshPanel()
}

void function UIToClient_MapEditor_SetFav( int catalogId, bool on )
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) || MapEditorCatalog_GetEntry( catalogId ) == null )
		return
	player.ClientCommand( format( "mapedit_fav %d %d", catalogId, on ? 1 : 0 ) )
}

void function UIToClient_MapEditor_SetOpts( int opts )
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) || opts < 0 || opts > 255 )
		return
	player.ClientCommand( "mapedit_prefs_opts " + string( opts ) )
}

// Menu open: the UI VM asks for everything the client owns.
void function UIToClient_MapEditor_SyncUI()
{
	MapEdit_PushKeysToUI()
	for ( int i = 0; i < MAPEDIT_HOTBAR_SLOTS; i++ )
		MapEdit_PushSlotToUI( i )
	RunUIScript( "UI_MapEditor_OnSelection", file.catalogId, file.specialId )
}

void function MapEdit_PushSlotToUI( int slot )
{
	MapEditSlot s = file.slots[slot]
	RunUIScript( "UI_MapEditor_OnSlot", slot, s.kind, s.id, MapEdit_SlotLabel( s ) )
}

void function MapEdit_PushKeysToUI()
{
	if ( file.slotKeys.len() < 3 )
		return
	RunUIScript( "UI_MapEditor_OnKeys", MapEdit_KeyLabel( file.slotKeys[0] ), MapEdit_KeyLabel( file.slotKeys[1] ), MapEdit_KeyLabel( file.slotKeys[2] ) )
}

void function ServerCallback_MapEdit_Hotbar( int slot, int kind, int id, vector angles )
{
	if ( slot < 0 || slot >= MAPEDIT_HOTBAR_SLOTS || kind < 0 || kind > 2 )
		return
	if ( kind == 1 && MapEditorCatalog_GetEntry( id ) == null )
		return
	file.slots[slot].kind = kind
	file.slots[slot].id = kind == 0 ? 0 : id
	file.slots[slot].angles = angles
	MapEdit_PushSlotToUI( slot )
	MapEdit_RefreshPanel()
}

void function ServerCallback_MapEdit_Opts( int opts )
{
	RunUIScript( "UI_MapEditor_OnOpts", opts )
}

void function ServerCallback_MapEdit_FavClear()
{
	RunUIScript( "UI_MapEditor_OnFavClear" )
}

void function ServerCallback_MapEdit_Fav( int id )
{
	RunUIScript( "UI_MapEditor_OnFav", id )
}

void function ServerCallback_MapEdit_ModelInfo( int id, int collision, vector size, vector center )
{
	if ( size.x > 0.0 || size.y > 0.0 || size.z > 0.0 )
	{
		array< vector > bounds = [ center - size * 0.5, center + size * 0.5 ]
		file.modelBounds[id] <- bounds
	}
	RunUIScript( "UI_MapEditor_OnModelInfo", id, collision, size.x, size.y, size.z )
}

// [ mins, maxs ] in model space, or empty until the server has sent them.
array< vector > function MapEditor_ModelBounds( int catalogId )
{
	if ( catalogId in file.modelBounds )
		return file.modelBounds[catalogId]
	return []
}

void function MapEdit_OnCycleSnap( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.snapSizes.len() == 0 )
		return

	file.snapIndex = ( file.snapIndex + 1 ) % file.snapSizes.len()
	float size = MapEdit_GetSnapSize()
	MapEdit_RefreshPanel()

	if ( size <= 0.0 )
		AnnouncementMessageRight( player, "Snap: off", "", <1, 1, 1>, $"", 3.0 )
	else
		AnnouncementMessageRight( player, format( "Snap: %d", int( size ) ), "", <1, 1, 1>, $"", 3.0 )
}

void function MapEdit_OnRaise( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	file.zOffset = clamp( file.zOffset + MAPEDIT_Z_STEP, -MAPEDIT_Z_LIMIT, MAPEDIT_Z_LIMIT )
	MapEdit_RefreshPanel()
}

void function MapEdit_OnLower( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	file.zOffset = clamp( file.zOffset - MAPEDIT_Z_STEP, -MAPEDIT_Z_LIMIT, MAPEDIT_Z_LIMIT )
	MapEdit_RefreshPanel()
}

void function MapEdit_OnOpenModelBrowser( entity player )
{
	if ( !file.buildMode )
		return

	RunUIScript( "OpenMapEditorModelMenu" )
}
