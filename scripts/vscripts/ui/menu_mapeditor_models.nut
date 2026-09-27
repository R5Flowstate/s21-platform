// Map editor model browser: categories, searchable model list with a
// collision filter, a live 3D preview (client PIP camera drawn by the browser
// RUI), and preview settings. Fullscreen hides the lists and keeps the hotkey
// rail, whose rows switch to the inspect keys. Every key cap is an engine
// token, so the rail shows pad glyphs while a controller is active.
// Layout numbers mirror SERE tools/gen_fs_mapedit.py.

global function InitMapEditorModelMenu
global function OpenMapEditorModelMenu
global function OpenMapEditorMapPacks
global function UI_MapEditor_SetActivePackMask
global function UI_MapEditor_OnPackRefused
global function UI_MapEditPreview_OnSlot
global function UI_MapEditPreview_OnState
global function UI_MapEditPreview_OnMessage
global function UI_MapEditor_OnSelection
global function UI_MapEditor_OnSlot
global function UI_MapEditor_OnKeys
global function UI_MapEditor_OnOpts
global function UI_MapEditor_OnFavClear
global function UI_MapEditor_OnFav
global function UI_MapEditor_OnModelInfo

const float ME_PREV_X = 1022.0
const float ME_PREV_Y = 116.0
const float ME_PREV_W = 858.0
const float ME_PREV_H = 658.0
const float ME_FULL_X = 296.0
const float ME_FULL_Y = 116.0
const float ME_FULL_W = 1584.0
const float ME_FULL_H = 924.0
const float ME_TB_BROWSE_X = 1057.5
const float ME_TB_BROWSE_Y = 692.0
const float ME_TB_FULL_X = 694.5
const float ME_TB_FULL_Y = 894.0
const float ME_TB_W = 787.0
const float ME_TOOL_H = 44.0
const float ME_TOOL_PAD = 6.0
const float ME_TOOL_GAP = 6.0
const float ME_TOOL_DIV = 13.0
const float ME_CAT_X = 296.0
const float ME_CAT_W = 256.0
const float ME_MOD_X = 572.0
const float ME_MOD_W = 430.0
const float ME_MOD_ROW_Y0 = 272.0
const float ME_MOD_ROW_STEP = 58.0
const float ME_MOD_ROW_H = 54.0
const float ME_INFO_X = 1022.0
const float ME_INFO_Y = 790.0
const float ME_SET_X = 1486.0
const float ME_SET_Y0 = 840.0
const float ME_SET_W = 372.0
const float ME_SET_ROW_H = 44.0

const int ME_RAIL_ROWS = 18
const int ME_CAT_ROWS = 18
const int ME_MOD_ROWS = 13
const int ME_SLOTS = 3
const int ME_SET_ROWS = 4

const int ME_OPT_FIT = 1
const int ME_OPT_SPIN = 2
const int ME_OPT_KEEP = 4
const int ME_OPT_FULL = 8
const int ME_OPTS_DEFAULT = 7

const int ME_FILTER_ALL = 0
const int ME_FILTER_SOLID = 1
const int ME_FILTER_GHOST = 2

const float ME_ORBIT_DEG_PER_PX = 0.4
const float ME_PAN_PER_PX = 0.0016
const float ME_STICK_DEG_PER_SEC = 160.0
const float ME_STICK_DEADZONE = 0.2
const float ME_TRIGGER_ZOOM_PER_SEC = 1.8
const float ME_TOOL_ORBIT_STEP = 45.0
const float ME_TOOL_ZOOM_STEP = 1.25
const float ME_ZOOM_MIN = 0.35
const float ME_ZOOM_MAX = 4.0
const float ME_TOAST_TIME = 1.6

const string ME_CAT_FAVORITES = "__favorites__"
const string ME_CAT_TOOLS = "__tools__"
const int ME_PACK_ROWS = 15
// A pack request the server never answers stops showing as loading after this.
const float ME_PACK_PENDING_TIME = 60.0

// row kind: 1 catalog model, 2 palette recipe, 3 layout action
struct MEBrowserRow
{
	int    kind
	int    id
	string name
	string sub
	string action
}

struct MESlotInfo
{
	int    kind
	int    id
	string label
}

struct
{
	var menu
	var browserRui
	var catsRui
	var modelsRui
	var infoRui
	var catsPanel
	var modelsPanel
	var infoPanel
	var searchEntry
	var previewArea
	var previewAreaFs

	array< var > tabButtons
	array< var > catButtons
	array< var > rowButtons
	array< var > setButtons
	table< string, var > filterButtons
	table< string, var > toolButtons
	table< string, var > toolButtonsFs
	table< string, var > infoButtons
	table< string, var > fsButtons

	bool   isOpen = false
	bool   fullscreen = false
	bool   typing = false
	bool   pad = false
	int    tier = 0
	int    filter = ME_FILTER_ALL
	array< string > categories
	string category = ""
	int    catScroll = 0
	array< MEBrowserRow > rows
	int    rowScroll = 0
	int    selKind = 0
	int    selId = 0
	string query = ""
	int    nextSlot = 0

	table< int, bool > favs
	// map bit -> UITime the load was requested
	table< int, float > packPending
	array< MEBrowserRow > packRows
	bool   openOnPacks = false
	bool   packsOpen = false
	string packsNote = ""
	var    packsPanel
	var    packsBackdrop
	var    packsClose
	array< var > packButtons
	table< int, int > collision
	table< int, vector > sizes
	array< MESlotInfo > slots
	array< string > slotKeys = [ "6", "7", "8" ]
	int    opts = ME_OPTS_DEFAULT
	int    light = 0
	bool   bounds = true

	int    pipSlot = -1
	vector previewRect = <-1, -1, 0>
	vector previewSize = <0, 0, 0>
	string previewMsg = "LOADING PREVIEW"
	vector dims = <0, 0, 0>
	float  scale = 1.0
	float  onScreenFrac = 1.0
	bool   resident = false
	float  yaw = 0.0
	float  pitch = 0.0
	float  zoom = 1.0

	string toast = ""
	float  toastUntil = 0.0
} file

// ---------------------------------------------------------------------------
// Init / open / close
// ---------------------------------------------------------------------------

void function InitMapEditorModelMenu( var menu )
{
	file.menu = menu
	file.catsPanel = Hud_GetChild( menu, "CatsRui" )
	file.modelsPanel = Hud_GetChild( menu, "ModelsRui" )
	file.infoPanel = Hud_GetChild( menu, "InfoRui" )
	file.searchEntry = Hud_GetChild( menu, "SearchEntry" )
	file.previewArea = Hud_GetChild( menu, "PreviewArea" )
	file.previewAreaFs = Hud_GetChild( menu, "PreviewAreaFs" )

	for ( int i = 0; i < 2; i++ )
		file.tabButtons.append( MEBind( Hud_GetChild( menu, "Tab" + i ), MapEditMenu_OnTabClick ) )
	for ( int i = 0; i < ME_CAT_ROWS; i++ )
		file.catButtons.append( MEBind( Hud_GetChild( menu, "Cat" + i ), MapEditMenu_OnCatClick ) )
	for ( int i = 0; i < ME_MOD_ROWS; i++ )
	{
		var b = MEBind( Hud_GetChild( menu, "Row" + i ), MapEditMenu_OnRowClick )
		Hud_AddEventHandler( b, UIE_CLICKRIGHT, MapEditMenu_OnRowRightClick )
		file.rowButtons.append( b )
	}
	for ( int i = 0; i < ME_SET_ROWS; i++ )
		file.setButtons.append( MEBind( Hud_GetChild( menu, "Set" + i ), MapEditMenu_OnSetClick ) )
	foreach ( string k in [ "all", "solid", "ghost" ] )
		file.filterButtons[k] <- MEBind( Hud_GetChild( menu, "Filter_" + k ), MapEditMenu_OnFilterClick )
	foreach ( string k in MapEditMenu_ToolKeys() )
	{
		file.toolButtons[k] <- MEBind( Hud_GetChild( menu, "Tool_" + k ), MapEditMenu_OnToolClick )
		file.toolButtonsFs[k] <- MEBind( Hud_GetChild( menu, "ToolFs_" + k ), MapEditMenu_OnToolClick )
	}
	foreach ( string k in [ "place", "fav", "full" ] )
		file.infoButtons[k] <- MEBind( Hud_GetChild( menu, "Btn_" + k ), MapEditMenu_OnInfoClick )
	foreach ( string k in [ "fsexit", "fsprev", "fsnext", "fsplace" ] )
		file.fsButtons[k] <- MEBind( Hud_GetChild( menu, "Fs_" + k ), MapEditMenu_OnFsClick )
	MEBind( Hud_GetChild( menu, "PacksButton" ), MapEditMenu_OnPacksClick )
	file.packsPanel = Hud_GetChild( menu, "PacksRui" )
	file.packsBackdrop = MEBind( Hud_GetChild( menu, "PacksBackdrop" ), MapEditMenu_OnPacksDismiss )
	file.packsClose = MEBind( Hud_GetChild( menu, "PacksClose" ), MapEditMenu_OnPacksDismiss )
	for ( int i = 0; i < ME_PACK_ROWS; i++ )
		file.packButtons.append( MEBind( Hud_GetChild( menu, "PackRow" + i ), MapEditMenu_OnPackRowClick ) )

	Hud_AddEventHandler( file.searchEntry, UIE_CHANGE, MapEditMenu_OnSearchChanged )
	Hud_AddEventHandler( file.searchEntry, UIE_GET_FOCUS, MapEditMenu_OnSearchFocus )
	Hud_AddEventHandler( file.searchEntry, UIE_LOSE_FOCUS, MapEditMenu_OnSearchBlur )

	for ( int i = 0; i < ME_SLOTS; i++ )
	{
		MESlotInfo s
		file.slots.append( s )
	}

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, MapEditMenu_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, MapEditMenu_OnClose )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, MapEditMenu_OnNavBack )
	AddUICallback_InputModeChanged( MapEditMenu_OnInputModeChanged )
}

var function MEBind( var button, void functionref( var ) handler )
{
	Hud_AddEventHandler( button, UIE_CLICK, handler )
	return button
}

void function OpenMapEditorModelMenu()
{
	CloseAllMenus()
	AdvanceMenu( file.menu )
}

// The HUD's map packs key: the browser, opened on the Map packs list.
void function OpenMapEditorMapPacks()
{
	file.openOnPacks = true
	OpenMapEditorModelMenu()
}

void function UI_MapEditor_SetActivePackMask( int mask )
{
	MapEditorCatalog_Init()
	MapEditorCatalog_SetActivePackMask( mask )
	array< int > landed
	foreach ( int bit, float t in file.packPending )
	{
		if ( ( mask & ( 1 << bit ) ) != 0 )
			landed.append( bit )
	}
	foreach ( int bit in landed )
	{
		delete file.packPending[bit]
		MapEditMenu_Toast( MapEditMenu_MapLabel( MapEditorCatalog_GetMapNameForBit( bit ) ).toupper() + " LOADED" )
	}
	if ( file.isOpen )
	{
		MapEditMenu_RebuildCategories( false )
		MapEditMenu_RefreshPacks()
	}
}

void function UI_MapEditor_OnPackRefused( int bit, int reason )
{
	if ( !( bit in file.packPending ) )
		return
	delete file.packPending[bit]
	if ( !file.isOpen )
		return
	string map = MapEditMenu_MapLabel( MapEditorCatalog_GetMapNameForBit( bit ) )
	if ( reason == ePackRefusal.ADMIN_ONLY )
		file.packsNote = "Only server admins can load map packs here."
	else if ( reason == ePackRefusal.REJECTED )
		file.packsNote = map + " was refused: three packs are already loaded, or the map is not installed."
	else
		file.packsNote = map + " failed to load."
	MapEditMenu_Toast( file.packsNote.toupper() )
	MapEditMenu_RefreshPacks()
}

void function MapEditMenu_OnOpen()
{
	file.isOpen = true
	MapEditorCatalog_Init()
	file.browserRui = Hud_GetRui( Hud_GetChild( file.menu, "BrowserRui" ) )
	file.catsRui = Hud_GetRui( file.catsPanel )
	file.modelsRui = Hud_GetRui( file.modelsPanel )
	file.infoRui = Hud_GetRui( file.infoPanel )
	file.pad = IsControllerModeActive()

	// The client's current pick (slot key, eyedropper, last place) wins over the last browse.
	file.selKind = 0
	file.selId = 0
	file.pipSlot = -1
	file.previewRect = <-1, -1, 0>
	file.previewMsg = "LOADING PREVIEW"
	file.query = ""
	Hud_SetUTF8Text( file.searchEntry, "" )
	file.fullscreen = ( file.opts & ME_OPT_FULL ) != 0

	MapEditMenu_InitColors()
	MapEditMenu_RebuildCategories( true )
	if ( file.openOnPacks )
		MapEditMenu_ShowMapPacks()
	file.openOnPacks = false
	MapEditMenu_ApplyMode()
	MapEditMenu_RegisterKeys()

	// Open the preview before the sync: the sync answers with the current pick.
	RunClientScript( "UIToClient_MapEditPreview_Open" )
	MapEditMenu_PushOptionsToClient()
	RunClientScript( "UIToClient_MapEditor_SyncUI" )

	thread MapEditMenu_Thread()
}

void function MapEditMenu_OnClose()
{
	file.isOpen = false
	MapEditMenu_SetPacksOpen( false )
	SetBlurEnabled( false )
	MapEditMenu_DeregisterKeys()
	RunClientScript( "UIToClient_MapEditPreview_Close" )
	file.pipSlot = -1
	RuiSetInt( file.browserRui, "pipSlot", -1 )
}

void function MapEditMenu_OnNavBack()
{
	if ( file.packsOpen )
	{
		MapEditMenu_SetPacksOpen( false )
		return
	}
	if ( file.fullscreen )
	{
		MapEditMenu_SetFullscreen( false )
		return
	}
	CloseActiveMenu()
}

void function MapEditMenu_OnInputModeChanged( bool controllerModeActive )
{
	file.pad = controllerModeActive
	if ( !file.isOpen )
		return
	MapEditMenu_RefreshRail()
	MapEditMenu_RefreshPreviewChrome()
}

// ---------------------------------------------------------------------------
// Client -> UI
// ---------------------------------------------------------------------------

void function UI_MapEditPreview_OnSlot( int slot )
{
	file.pipSlot = slot
	if ( slot >= 0 )
		file.previewMsg = ""
	if ( file.isOpen )
		MapEditMenu_RefreshPreviewChrome()
}

void function UI_MapEditPreview_OnMessage( string msg )
{
	file.previewMsg = msg
	if ( file.isOpen )
		MapEditMenu_RefreshPreviewChrome()
}

void function UI_MapEditPreview_OnState( float sx, float sy, float sz, float scale, float onScreenFrac, bool resident, float yaw, float pitch, float zoom )
{
	file.dims = < sx, sy, sz >
	file.scale = scale
	file.onScreenFrac = onScreenFrac
	file.resident = resident
	file.yaw = yaw
	file.pitch = pitch
	file.zoom = zoom
	if ( file.isOpen )
		MapEditMenu_RefreshPreviewChrome()
}

void function UI_MapEditor_OnSelection( int catalogId, int specialId )
{
	if ( !file.isOpen || file.selKind != 0 )
		return
	if ( specialId > 0 && specialId <= 5 )
	{
		file.selKind = 2
		file.selId = specialId
		file.tier = 0
		file.category = ME_CAT_TOOLS
		MapEditMenu_RebuildCategories( false )
	}
	else if ( catalogId > 0 )
	{
		MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( catalogId )
		if ( e == null )
			return
		MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( e )
		file.selKind = 1
		file.selId = catalogId
		file.tier = entry.tier == "extra" ? 1 : 0
		file.category = entry.category
		MapEditMenu_RebuildCategories( false )
		MapEditMenu_ScrollCategoryIntoView()
	}
	else
	{
		return
	}
	MapEditMenu_OnSelectionChanged( true )
}

void function UI_MapEditor_OnSlot( int slot, int kind, int id, string label )
{
	if ( slot < 0 || slot >= ME_SLOTS )
		return
	file.slots[slot].kind = kind
	file.slots[slot].id = id
	file.slots[slot].label = label
}

void function UI_MapEditor_OnKeys( string k0, string k1, string k2 )
{
	file.slotKeys = [ k0, k1, k2 ]
}

void function UI_MapEditor_OnOpts( int opts )
{
	file.opts = opts < 0 ? ME_OPTS_DEFAULT : ( opts & 15 )
	file.light = opts < 0 ? 0 : ( ( opts >> 4 ) & 3 ) % 3
	if ( file.isOpen )
	{
		MapEditMenu_PushOptionsToClient()
		MapEditMenu_RefreshInfo()
		MapEditMenu_RefreshPreviewChrome()
	}
}

void function UI_MapEditor_OnFavClear()
{
	file.favs = {}
}

void function UI_MapEditor_OnFav( int id )
{
	file.favs[id] <- true
	if ( file.isOpen )
		MapEditMenu_RebuildCategories( false )
}

void function UI_MapEditor_OnModelInfo( int id, int collision, float sx, float sy, float sz )
{
	file.collision[id] <- collision
	file.sizes[id] <- < sx, sy, sz >
	if ( file.isOpen && file.filter == ME_FILTER_ALL )
		MapEditMenu_RefreshRows()
}

// ---------------------------------------------------------------------------
// Catalog -> rows
// ---------------------------------------------------------------------------

bool function MapEditMenu_PassesFilter( int id )
{
	if ( file.filter == ME_FILTER_ALL )
		return true
	if ( !( id in file.collision ) )
		return false
	return file.filter == ME_FILTER_SOLID ? file.collision[id] == 1 : file.collision[id] == 0
}

array< MapEditorCatalogEntry > function MapEditMenu_Entries( string cat, string mapName )
{
	array< MapEditorCatalogEntry > out
	foreach ( MapEditorCatalogEntry e in MapEditorCatalog_GetAvailableCategoryEntries( cat, mapName ) )
	{
		if ( MapEditMenu_PassesFilter( e.id ) )
			out.append( e )
	}
	return out
}

void function MapEditMenu_RebuildCategories( bool resetSelection )
{
	string mapName = GetActiveLevel()
	file.categories = []

	// Favorites and Tools lead the Build tab so they never scroll out of sight.
	string tierName = file.tier == 0 ? "build" : "extra"
	if ( file.tier == 0 && file.favs.len() > 0 )
		file.categories.append( ME_CAT_FAVORITES )
	if ( file.tier == 0 )
		file.categories.append( ME_CAT_TOOLS )
	string firstModels = ""
	foreach ( string cat in MapEditorCatalog_GetCategoriesByTier( tierName ) )
	{
		if ( MapEditMenu_Entries( cat, mapName ).len() == 0 )
			continue
		file.categories.append( cat )
		if ( firstModels == "" )
			firstModels = cat
	}

	if ( resetSelection || !file.categories.contains( file.category ) )
	{
		file.category = firstModels != "" ? firstModels : ( file.categories.len() > 0 ? file.categories[0] : "" )
		file.catScroll = 0
		MapEditMenu_ScrollCategoryIntoView()
	}
	MapEditMenu_RebuildRows()
	MapEditMenu_RefreshCategories()
}

void function MapEditMenu_ScrollCategoryIntoView()
{
	int at = file.categories.find( file.category )
	if ( at < 0 )
		return
	if ( at < file.catScroll )
		file.catScroll = at
	else if ( at >= file.catScroll + ME_CAT_ROWS )
		file.catScroll = at - ME_CAT_ROWS + 1
	MapEditMenu_RefreshCategories()
}

void function MapEditMenu_RebuildRows()
{
	file.rows = []
	file.rowScroll = 0
	string mapName = GetActiveLevel()

	if ( file.query != "" )
	{
		string q = file.query.tolower()
		foreach ( string cat in MapEditorCatalog_GetCategories() )
		{
			foreach ( MapEditorCatalogEntry e in MapEditMenu_Entries( cat, mapName ) )
			{
				string stem = MapEditMenu_Stem( e.model )
				if ( stem.find( q ) >= 0 || cat.find( q ) >= 0 )
					file.rows.append( MapEditMenu_ModelRow( e ) )
			}
		}
	}
	else if ( file.category == ME_CAT_TOOLS )
	{
		array< string > names = [ "#MAPEDIT_TOOL_JUMPPAD", "#MAPEDIT_TOOL_DOOR", "#MAPEDIT_TOOL_DOUBLEDOOR", "#MAPEDIT_TOOL_LOOTBIN", "#MAPEDIT_TOOL_EFFECT" ]
		foreach ( int i, string n in names )
			file.rows.append( MapEditMenu_Row( 2, i + 1, Localize( n ), "Placeable", "" ) )
		for ( int slot = 1; slot <= MAPEDIT_SAVE_SLOTS; slot++ )
			file.rows.append( MapEditMenu_Row( 3, 0, Localize( "#MAPEDIT_TOOL_SAVE", string( slot ) ), "Writes your build", "save " + slot ) )
		for ( int slot = 1; slot <= MAPEDIT_SAVE_SLOTS; slot++ )
			file.rows.append( MapEditMenu_Row( 3, 0, Localize( "#MAPEDIT_TOOL_LOAD", string( slot ) ), "Replaces your build", "load " + slot ) )
		file.rows.append( MapEditMenu_Row( 3, 0, Localize( "#MAPEDIT_TOOL_LOAD_AUTO" ), "Last autosave", "load auto" ) )
		file.rows.append( MapEditMenu_Row( 3, 0, Localize( "#MAPEDIT_TOOL_CLEAR" ), "Asks first", "clear" ) )
	}
	else if ( file.category == ME_CAT_FAVORITES )
	{
		foreach ( int id, bool on in file.favs )
		{
			MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( id )
			if ( e == null )
				continue
			MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( e )
			if ( MapEditorCatalog_IsAvailableOnMap( entry, mapName ) && MapEditMenu_PassesFilter( id ) )
				file.rows.append( MapEditMenu_ModelRow( entry ) )
		}
	}
	else if ( file.category != "" )
	{
		foreach ( MapEditorCatalogEntry e in MapEditMenu_Entries( file.category, mapName ) )
			file.rows.append( MapEditMenu_ModelRow( e ) )
	}

	MapEditMenu_ScrollToSelection()
	MapEditMenu_RefreshRows()
}

// One row per catalog map other than this one: loading it adds that map's props.
array< MEBrowserRow > function MapEditMenu_MapPackRows( string mapName )
{
	int mask = MapEditorCatalog_GetActivePackMask()
	int here = MapEditorCatalog_GetMapBit( mapName )
	array< int > bits
	for ( int bit = 1; bit < 32; bit++ )
	{
		if ( bit != here && MapEditorCatalog_GetMapNameForBit( bit ) != "" )
			bits.append( bit )
	}

	table< int, int > adds
	foreach ( string cat in MapEditorCatalog_GetCategories() )
	{
		foreach ( MapEditorCatalogEntry e in MapEditorCatalog_GetCategoryEntries( cat ) )
		{
			if ( MapEditorCatalog_IsAvailableOnMap( e, mapName ) )
				continue
			foreach ( int bit in bits )
			{
				if ( ( e.mapMask & ( 1 << bit ) ) != 0 )
					adds[bit] <- ( bit in adds ? adds[bit] : 0 ) + 1
			}
		}
	}

	array< MEBrowserRow > rows
	foreach ( int bit in bits )
	{
		string name = MapEditorCatalog_GetMapNameForBit( bit )
		string sub
		if ( ( mask & ( 1 << bit ) ) != 0 )
			sub = "Loaded"
		else if ( bit in file.packPending && UITime() - file.packPending[bit] < ME_PACK_PENDING_TIME )
			sub = "Loading..."
		else if ( bit in adds )
			sub = format( "+%d models", adds[bit] )
		else
			continue
		rows.append( MapEditMenu_Row( 3, bit, MapEditMenu_MapLabel( name ), sub, "pack " + name ) )
	}
	return rows
}

string function MapEditMenu_MapLabel( string mapName )
{
	string stem = mapName.find( "mp_rr_" ) == 0 ? mapName.slice( 6, mapName.len() ) : mapName
	return MapEditMenu_CategoryLabel( stem )
}

MEBrowserRow function MapEditMenu_Row( int kind, int id, string name, string sub, string action )
{
	MEBrowserRow r
	r.kind = kind
	r.id = id
	r.name = name
	r.sub = sub
	r.action = action
	return r
}

MEBrowserRow function MapEditMenu_ModelRow( MapEditorCatalogEntry e )
{
	return MapEditMenu_Row( 1, e.id, MapEditMenu_Stem( e.model ), "", "" )
}

string function MapEditMenu_Stem( asset model )
{
	string path = string( model )
	array< string > parts = split( path, "/" )
	string stem = parts.len() > 0 ? parts[parts.len() - 1] : path
	if ( stem.len() > 5 && stem.slice( stem.len() - 5, stem.len() ) == ".rmdl" )
		stem = stem.slice( 0, stem.len() - 5 )
	return stem
}

string function MapEditMenu_Truncate( string s, int maxLen )
{
	if ( s.len() <= maxLen )
		return s
	return s.slice( 0, maxLen - 2 ) + ".."
}

int function MapEditMenu_SelectedRowIndex()
{
	foreach ( int i, MEBrowserRow r in file.rows )
	{
		if ( r.kind == file.selKind && r.id == file.selId && r.kind != 3 )
			return i
	}
	return -1
}

void function MapEditMenu_ScrollToSelection()
{
	int idx = MapEditMenu_SelectedRowIndex()
	if ( idx < 0 )
		return
	if ( idx < file.rowScroll )
		file.rowScroll = idx
	else if ( idx >= file.rowScroll + ME_MOD_ROWS )
		file.rowScroll = idx - ME_MOD_ROWS + 1
}

// ---------------------------------------------------------------------------
// Selection and actions
// ---------------------------------------------------------------------------

void function MapEditMenu_Select( int kind, int id )
{
	if ( kind == file.selKind && id == file.selId )
		return
	file.selKind = kind
	file.selId = id
	MapEditMenu_OnSelectionChanged( true )
}

void function MapEditMenu_OnSelectionChanged( bool tellClient )
{
	file.resident = false
	if ( tellClient )
	{
		RunClientScript( "UIToClient_MapEditPreview_SetModel", file.selKind == 1 ? file.selId : 0, file.selKind == 2 ? file.selId : 0 )
		if ( ( file.opts & ME_OPT_KEEP ) == 0 )
			RunClientScript( "UIToClient_MapEditPreview_Reset" )
	}
	MapEditMenu_ScrollToSelection()
	MapEditMenu_RefreshRows()
	MapEditMenu_RefreshInfo()
	MapEditMenu_RefreshPreviewChrome()
}

void function MapEditMenu_StepSelection( int dir )
{
	array< int > pickable
	foreach ( int i, MEBrowserRow r in file.rows )
	{
		if ( r.kind != 3 )
			pickable.append( i )
	}
	if ( pickable.len() == 0 )
		return
	int at = pickable.find( MapEditMenu_SelectedRowIndex() )
	at = at < 0 ? ( dir > 0 ? 0 : pickable.len() - 1 ) : ( at + dir + pickable.len() ) % pickable.len()
	MEBrowserRow r = file.rows[pickable[at]]
	MapEditMenu_Select( r.kind, r.id )
}

void function MapEditMenu_StepCategory( int dir )
{
	if ( file.categories.len() == 0 )
		return
	MapEditMenu_ClearSearch()
	int at = file.categories.find( file.category )
	at = ( at + dir + file.categories.len() ) % file.categories.len()
	file.category = file.categories[at]
	MapEditMenu_RebuildRows()
	MapEditMenu_ScrollCategoryIntoView()
}

void function MapEditMenu_SetTier( int tier )
{
	if ( tier == file.tier && file.query == "" )
		return
	file.tier = tier
	MapEditMenu_ClearSearch()
	MapEditMenu_RebuildCategories( true )
}

void function MapEditMenu_SetFilter( int filter )
{
	if ( filter == file.filter )
		return
	file.filter = filter
	MapEditMenu_RebuildCategories( false )
	array< string > names = [ "ALL MODELS", "SOLID ONLY", "NO COLLISION ONLY" ]
	MapEditMenu_Toast( names[filter] )
}

void function MapEditMenu_ClearSearch()
{
	if ( file.query == "" )
		return
	file.query = ""
	Hud_SetUTF8Text( file.searchEntry, "" )
}

void function MapEditMenu_PlaceSelection()
{
	if ( file.selKind == 1 )
	{
		RunClientScript( "UIToClient_MapEditor_SetModel", file.selId )
		CloseActiveMenu()
	}
	else if ( file.selKind == 2 )
	{
		RunClientScript( "UIToClient_MapEditor_SetSpecial", file.selId )
		CloseActiveMenu()
	}
	else
	{
		MapEditMenu_Toast( "PICK A MODEL FIRST" )
	}
}

void function MapEditMenu_ToggleFavorite()
{
	if ( file.selKind != 1 )
		return
	bool on = !( file.selId in file.favs )
	if ( on )
		file.favs[file.selId] <- true
	else
		delete file.favs[file.selId]
	RunClientScript( "UIToClient_MapEditor_SetFav", file.selId, on )
	MapEditMenu_Toast( on ? "ADDED TO FAVORITES" : "REMOVED FROM FAVORITES" )
	MapEditMenu_RebuildCategories( false )
	MapEditMenu_RefreshInfo()
}

void function MapEditMenu_AssignSlot( int slot )
{
	if ( slot < 0 || slot >= ME_SLOTS )
		return
	if ( file.selKind != 1 && file.selKind != 2 )
	{
		MapEditMenu_Toast( "PICK A MODEL FIRST" )
		return
	}
	RunClientScript( "UIToClient_MapEditor_AssignSlot", slot, file.selKind == 1 ? file.selId : 0, file.selKind == 2 ? file.selId : 0 )
	MapEditMenu_Toast( format( "QUICK SLOT %d SET", slot + 1 ) )
	file.nextSlot = ( slot + 1 ) % ME_SLOTS
}

void function MapEditMenu_RunAction( string action )
{
	array< string > parts = split( action, " " )
	if ( parts.len() == 0 )
		return
	if ( parts[0] == "save" || parts[0] == "load" )
	{
		ClientCommand( "mapedit_" + action )
		CloseActiveMenu()
		return
	}
	if ( parts[0] == "pack" && parts.len() == 2 )
	{
		int bit = MapEditorCatalog_GetMapBit( parts[1] )
		if ( bit < 0 || ( MapEditorCatalog_GetActivePackMask() & ( 1 << bit ) ) != 0 )
			return
		if ( bit in file.packPending && UITime() - file.packPending[bit] < ME_PACK_PENDING_TIME )
			return
		ClientCommand( "mapedit_pack " + parts[1] )
		file.packPending[bit] <- UITime()
		file.packsNote = ""
		MapEditMenu_RefreshPacks()
		return
	}
	if ( parts[0] == "clear" )
	{
		ConfirmDialogData data
		data.headerText = Localize( "#MAPEDIT_TOOL_CLEAR" )
		data.messageText = Localize( "#MAPEDIT_TOOL_CLEAR_CONFIRM" )
		data.resultCallback = void function ( int result )
		{
			if ( result == eDialogResult.YES )
				ClientCommand( "mapedit_clear_mine" )
		}
		OpenConfirmDialogFromData( data )
	}
}

// ---------------------------------------------------------------------------
// Preview options and tools
// ---------------------------------------------------------------------------

void function MapEditMenu_SetOpt( int bit, bool on )
{
	file.opts = on ? ( file.opts | bit ) : ( file.opts & ~bit )
	MapEditMenu_OptionsChanged()
}

void function MapEditMenu_OptionsChanged()
{
	MapEditMenu_PushOptionsToClient()
	RunClientScript( "UIToClient_MapEditor_SetOpts", ( file.opts & 15 ) | ( file.light << 4 ) )
	MapEditMenu_RefreshInfo()
	MapEditMenu_RefreshPreviewChrome()
}

void function MapEditMenu_PushOptionsToClient()
{
	RunClientScript( "UIToClient_MapEditPreview_SetOptions", ( file.opts & ME_OPT_SPIN ) != 0, ( file.opts & ME_OPT_FIT ) != 0, file.light )
}

void function MapEditMenu_OnPacksClick( var button )
{
	MapEditMenu_ShowMapPacks()
}

void function MapEditMenu_OnPacksDismiss( var button )
{
	MapEditMenu_SetPacksOpen( false )
}

void function MapEditMenu_OnPackRowClick( var button )
{
	int idx = file.packButtons.find( button )
	if ( idx >= 0 && idx < file.packRows.len() )
		MapEditMenu_RunAction( file.packRows[idx].action )
}

// The map packs popup: loads another map's props for everyone on the server.
void function MapEditMenu_ShowMapPacks()
{
	file.packsNote = ""
	MapEditMenu_SetPacksOpen( true )
}

void function MapEditMenu_SetPacksOpen( bool open )
{
	file.packsOpen = open
	foreach ( var panel in [ file.packsPanel, file.packsBackdrop, file.packsClose ] )
		Hud_SetVisible( panel, open )
	if ( open )
		MapEditMenu_RefreshPacks()
	else
	{
		foreach ( var b in file.packButtons )
			Hud_SetVisible( b, false )
	}
}

void function MapEditMenu_RefreshPacks()
{
	if ( !file.packsOpen )
		return
	var rui = Hud_GetRui( file.packsPanel )
	file.packRows = MapEditMenu_MapPackRows( GetActiveLevel() )
	string info = file.packRows.len() == 0 ? "No other map has props to add here." : "Adds another map's props for everyone on this server, up to three maps."
	RuiSetString( rui, "packsInfo", file.packsNote != "" ? file.packsNote : info )
	for ( int i = 0; i < ME_PACK_ROWS; i++ )
	{
		bool has = i < file.packRows.len()
		string state = has ? file.packRows[i].sub : ""
		vector col = state == "Loaded" ? ME_C_TEXT : ( state == "Loading..." ? ME_C_CYAN : ME_C_ACCENT )
		RuiSetString( rui, "packName" + i, has ? file.packRows[i].name : "" )
		RuiSetString( rui, "packState" + i, state.toupper() )
		MECol( rui, "packStateColor" + i, col, 1.0 )
		MECol( rui, "packRowBg" + i, ME_C_ROW, has ? 1.0 : 0.0 )
		Hud_SetVisible( file.packButtons[i], has )
	}
}

void function MapEditMenu_SetFullscreen( bool on )
{
	if ( file.fullscreen == on )
		return
	file.fullscreen = on
	MapEditMenu_ApplyMode()
}

void function MapEditMenu_ZoomTo( float target )
{
	float z = clamp( target, ME_ZOOM_MIN, ME_ZOOM_MAX )
	if ( file.zoom > 0.0 )
		RunClientScript( "UIToClient_MapEditPreview_Zoom", z / file.zoom )
	file.zoom = z
	MapEditMenu_RefreshPreviewChrome()
}

void function MapEditMenu_RunTool( string k )
{
	switch ( k )
	{
		case "rotl":
			RunClientScript( "UIToClient_MapEditPreview_Orbit", -ME_TOOL_ORBIT_STEP, 0.0 )
			break
		case "rotr":
			RunClientScript( "UIToClient_MapEditPreview_Orbit", ME_TOOL_ORBIT_STEP, 0.0 )
			break
		case "zoomout":
			MapEditMenu_ZoomTo( file.zoom / ME_TOOL_ZOOM_STEP )
			break
		case "zoomin":
			MapEditMenu_ZoomTo( file.zoom * ME_TOOL_ZOOM_STEP )
			break
		case "spin":
			MapEditMenu_SetOpt( ME_OPT_SPIN, ( file.opts & ME_OPT_SPIN ) == 0 )
			break
		case "fit":
			MapEditMenu_SetOpt( ME_OPT_FIT, ( file.opts & ME_OPT_FIT ) == 0 )
			break
		case "bounds":
			file.bounds = !file.bounds
			MapEditMenu_RefreshPreviewChrome()
			break
		case "light":
			file.light = ( file.light + 1 ) % 3
			MapEditMenu_OptionsChanged()
			array< string > lightNames = [ "STUDIO LIGHT", "BRIGHT LIGHT", "DRAMATIC LIGHT" ]
			MapEditMenu_Toast( lightNames[file.light] )
			break
		case "reset":
			RunClientScript( "UIToClient_MapEditPreview_Reset" )
			file.opts = file.opts | ME_OPT_FIT
			file.zoom = 1.0
			MapEditMenu_OptionsChanged()
			break
		case "full":
			MapEditMenu_SetFullscreen( !file.fullscreen )
			break
	}
}

// Toolbar sequence; "" marks a divider. Matches TOOLBAR in gen_fs_mapedit.py.
array< string > function MapEditMenu_ToolSeq()
{
	return [ "rotl", "rotr", "", "zoomout", "slider", "zoomin", "", "spin", "fit", "bounds", "light", "reset", "", "full" ]
}

array< float > function MapEditMenu_ToolSeqWidths()
{
	return [ 44.0, 44.0, 0.0, 44.0, 110.0, 44.0, 0.0, 70.0, 56.0, 84.0, 68.0, 70.0, 0.0, 60.0 ]
}

array< string > function MapEditMenu_ToolKeys()
{
	return [ "rotl", "rotr", "zoomout", "slider", "zoomin", "spin", "fit", "bounds", "light", "reset", "full" ]
}

// ---------------------------------------------------------------------------
// Button handlers
// ---------------------------------------------------------------------------

void function MapEditMenu_OnTabClick( var button )
{
	MapEditMenu_SetTier( file.tabButtons.find( button ) )
}

void function MapEditMenu_OnCatClick( var button )
{
	int idx = file.catScroll + file.catButtons.find( button )
	if ( idx < 0 || idx >= file.categories.len() )
		return
	file.category = file.categories[idx]
	MapEditMenu_ClearSearch()
	MapEditMenu_RebuildRows()
	MapEditMenu_RefreshCategories()
}

void function MapEditMenu_OnFilterClick( var button )
{
	if ( button == file.filterButtons["all"] )
		MapEditMenu_SetFilter( ME_FILTER_ALL )
	else if ( button == file.filterButtons["solid"] )
		MapEditMenu_SetFilter( ME_FILTER_SOLID )
	else
		MapEditMenu_SetFilter( ME_FILTER_GHOST )
}

void function MapEditMenu_OnRowClick( var button )
{
	int idx = file.rowScroll + file.rowButtons.find( button )
	if ( idx < 0 || idx >= file.rows.len() )
		return
	MEBrowserRow r = file.rows[idx]
	if ( r.kind == 3 )
	{
		MapEditMenu_RunAction( r.action )
		return
	}
	// A second click on the selected row places it.
	if ( r.kind == file.selKind && r.id == file.selId )
	{
		MapEditMenu_PlaceSelection()
		return
	}
	MapEditMenu_Select( r.kind, r.id )
}

void function MapEditMenu_OnRowRightClick( var button )
{
	int idx = file.rowScroll + file.rowButtons.find( button )
	if ( idx < 0 || idx >= file.rows.len() || file.rows[idx].kind != 1 )
		return
	MapEditMenu_Select( 1, file.rows[idx].id )
	MapEditMenu_ToggleFavorite()
}

void function MapEditMenu_OnSetClick( var button )
{
	int row = file.setButtons.find( button )
	array< int > bits = [ ME_OPT_FIT, ME_OPT_SPIN, ME_OPT_KEEP, ME_OPT_FULL ]
	if ( row < 0 || row >= bits.len() )
		return
	MapEditMenu_SetOpt( bits[row], ( file.opts & bits[row] ) == 0 )
}

void function MapEditMenu_OnToolClick( var button )
{
	foreach ( string k, var b in file.toolButtons )
	{
		if ( k == "slider" )
			continue
		if ( b == button || file.toolButtonsFs[k] == button )
		{
			MapEditMenu_RunTool( k )
			return
		}
	}
}

void function MapEditMenu_OnInfoClick( var button )
{
	if ( button == file.infoButtons["place"] )
		MapEditMenu_PlaceSelection()
	else if ( button == file.infoButtons["fav"] )
		MapEditMenu_ToggleFavorite()
	else if ( button == file.infoButtons["full"] )
		MapEditMenu_SetFullscreen( true )
}

void function MapEditMenu_OnFsClick( var button )
{
	if ( button == file.fsButtons["fsexit"] )
		MapEditMenu_SetFullscreen( false )
	else if ( button == file.fsButtons["fsprev"] )
		MapEditMenu_StepSelection( -1 )
	else if ( button == file.fsButtons["fsnext"] )
		MapEditMenu_StepSelection( 1 )
	else if ( button == file.fsButtons["fsplace"] )
		MapEditMenu_PlaceSelection()
}

void function MapEditMenu_OnSearchChanged( var entry )
{
	string q = strip( Hud_GetUTF8Text( file.searchEntry ) )
	if ( q.len() > 40 )
		q = q.slice( 0, 40 )
	MapEditMenu_RefreshSearch()
	if ( q == file.query )
		return
	file.query = q
	MapEditMenu_RebuildRows()
	MapEditMenu_RefreshCategories()
}

void function MapEditMenu_OnSearchFocus( var entry )
{
	file.typing = true
	MapEditMenu_RefreshSearch()
}

void function MapEditMenu_OnSearchBlur( var entry )
{
	file.typing = false
	MapEditMenu_RefreshSearch()
}

// ---------------------------------------------------------------------------
// Keyboard and controller
// ---------------------------------------------------------------------------

void function MapEditMenu_RegisterKeys()
{
	foreach ( int k in [ KEY_W, KEY_UP, BUTTON_DPAD_UP ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyUp )
	foreach ( int k in [ KEY_S, KEY_DOWN, BUTTON_DPAD_DOWN ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyDown )
	foreach ( int k in [ KEY_A, KEY_LEFT, BUTTON_DPAD_LEFT ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyLeft )
	foreach ( int k in [ KEY_D, KEY_RIGHT, BUTTON_DPAD_RIGHT ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyRight )
	RegisterButtonPressedCallback( KEY_Q, MapEditMenu_KeyQ )
	RegisterButtonPressedCallback( KEY_E, MapEditMenu_KeyE )
	RegisterButtonPressedCallback( KEY_TAB, MapEditMenu_KeyTab )
	RegisterButtonPressedCallback( BUTTON_SHOULDER_LEFT, MapEditMenu_PadLB )
	RegisterButtonPressedCallback( BUTTON_SHOULDER_RIGHT, MapEditMenu_PadRB )
	RegisterButtonPressedCallback( KEY_ENTER, MapEditMenu_KeyEnter )
	foreach ( int k in [ KEY_F, BUTTON_Y ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyF )
	foreach ( int k in [ KEY_R, BUTTON_STICK_RIGHT ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyR )
	foreach ( int k in [ KEY_SPACE, BUTTON_STICK_LEFT ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeySpace )
	foreach ( int k in [ KEY_V, BUTTON_X ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyV )
	RegisterButtonPressedCallback( KEY_B, MapEditMenu_KeyB )
	RegisterButtonPressedCallback( KEY_L, MapEditMenu_KeyL )
	foreach ( int k in [ KEY_C, BUTTON_BACK ] )
		RegisterButtonPressedCallback( k, MapEditMenu_KeyFilter )
	RegisterButtonPressedCallback( KEY_1, MapEditMenu_Key1 )
	RegisterButtonPressedCallback( KEY_2, MapEditMenu_Key2 )
	RegisterButtonPressedCallback( KEY_3, MapEditMenu_Key3 )
	RegisterButtonPressedCallback( BUTTON_START, MapEditMenu_PadStart )
	RegisterButtonPressedCallback( MOUSE_WHEEL_UP, MapEditMenu_WheelUp )
	RegisterButtonPressedCallback( MOUSE_WHEEL_DOWN, MapEditMenu_WheelDown )
}

void function MapEditMenu_DeregisterKeys()
{
	foreach ( int k in [ KEY_W, KEY_UP, BUTTON_DPAD_UP ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyUp )
	foreach ( int k in [ KEY_S, KEY_DOWN, BUTTON_DPAD_DOWN ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyDown )
	foreach ( int k in [ KEY_A, KEY_LEFT, BUTTON_DPAD_LEFT ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyLeft )
	foreach ( int k in [ KEY_D, KEY_RIGHT, BUTTON_DPAD_RIGHT ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyRight )
	DeregisterButtonPressedCallback( KEY_Q, MapEditMenu_KeyQ )
	DeregisterButtonPressedCallback( KEY_E, MapEditMenu_KeyE )
	DeregisterButtonPressedCallback( KEY_TAB, MapEditMenu_KeyTab )
	DeregisterButtonPressedCallback( BUTTON_SHOULDER_LEFT, MapEditMenu_PadLB )
	DeregisterButtonPressedCallback( BUTTON_SHOULDER_RIGHT, MapEditMenu_PadRB )
	DeregisterButtonPressedCallback( KEY_ENTER, MapEditMenu_KeyEnter )
	foreach ( int k in [ KEY_F, BUTTON_Y ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyF )
	foreach ( int k in [ KEY_R, BUTTON_STICK_RIGHT ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyR )
	foreach ( int k in [ KEY_SPACE, BUTTON_STICK_LEFT ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeySpace )
	foreach ( int k in [ KEY_V, BUTTON_X ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyV )
	DeregisterButtonPressedCallback( KEY_B, MapEditMenu_KeyB )
	DeregisterButtonPressedCallback( KEY_L, MapEditMenu_KeyL )
	foreach ( int k in [ KEY_C, BUTTON_BACK ] )
		DeregisterButtonPressedCallback( k, MapEditMenu_KeyFilter )
	DeregisterButtonPressedCallback( KEY_1, MapEditMenu_Key1 )
	DeregisterButtonPressedCallback( KEY_2, MapEditMenu_Key2 )
	DeregisterButtonPressedCallback( KEY_3, MapEditMenu_Key3 )
	DeregisterButtonPressedCallback( BUTTON_START, MapEditMenu_PadStart )
	DeregisterButtonPressedCallback( MOUSE_WHEEL_UP, MapEditMenu_WheelUp )
	DeregisterButtonPressedCallback( MOUSE_WHEEL_DOWN, MapEditMenu_WheelDown )
}

// Letter keys belong to the search box while it has focus.
bool function MapEditMenu_KeysLive()
{
	return file.isOpen && !file.typing && !file.packsOpen && GetActiveMenu() == file.menu
}

void function MapEditMenu_KeyUp( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_StepSelection( -1 )
}

void function MapEditMenu_KeyDown( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_StepSelection( 1 )
}

// Left/right: previous/next model in fullscreen, category while browsing.
void function MapEditMenu_KeyLeft( var b )
{
	if ( !MapEditMenu_KeysLive() )
		return
	if ( file.fullscreen )
		MapEditMenu_StepSelection( -1 )
	else
		MapEditMenu_StepCategory( -1 )
}

void function MapEditMenu_KeyRight( var b )
{
	if ( !MapEditMenu_KeysLive() )
		return
	if ( file.fullscreen )
		MapEditMenu_StepSelection( 1 )
	else
		MapEditMenu_StepCategory( 1 )
}

void function MapEditMenu_KeyQ( var b )
{
	if ( MapEditMenu_KeysLive() && !file.fullscreen )
		MapEditMenu_StepCategory( -1 )
}

void function MapEditMenu_KeyE( var b )
{
	if ( MapEditMenu_KeysLive() && !file.fullscreen )
		MapEditMenu_StepCategory( 1 )
}

void function MapEditMenu_KeyTab( var b )
{
	if ( MapEditMenu_KeysLive() && !file.fullscreen )
		MapEditMenu_SetTier( ( file.tier + 1 ) % 2 )
}

void function MapEditMenu_PadLB( var b )
{
	if ( MapEditMenu_KeysLive() && !file.fullscreen )
		MapEditMenu_SetTier( 0 )
}

void function MapEditMenu_PadRB( var b )
{
	if ( MapEditMenu_KeysLive() && !file.fullscreen )
		MapEditMenu_SetTier( 1 )
}

void function MapEditMenu_KeyEnter( var b )
{
	if ( !file.isOpen || GetActiveMenu() != file.menu )
		return
	if ( file.typing )
	{
		Hud_SetFocused( file.previewArea )
		return
	}
	MapEditMenu_PlaceSelection()
}

void function MapEditMenu_KeyF( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_SetFullscreen( !file.fullscreen )
}

void function MapEditMenu_KeyR( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_RunTool( "reset" )
}

void function MapEditMenu_KeySpace( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_RunTool( "spin" )
}

void function MapEditMenu_KeyV( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_ToggleFavorite()
}

void function MapEditMenu_KeyB( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_RunTool( "bounds" )
}

void function MapEditMenu_KeyL( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_RunTool( "light" )
}

void function MapEditMenu_KeyFilter( var b )
{
	if ( MapEditMenu_KeysLive() && !file.fullscreen )
		MapEditMenu_SetFilter( ( file.filter + 1 ) % 3 )
}

void function MapEditMenu_Key1( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_AssignSlot( 0 )
}

void function MapEditMenu_Key2( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_AssignSlot( 1 )
}

void function MapEditMenu_Key3( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_AssignSlot( 2 )
}

void function MapEditMenu_PadStart( var b )
{
	if ( MapEditMenu_KeysLive() )
		MapEditMenu_AssignSlot( file.nextSlot )
}

void function MapEditMenu_WheelUp( var b )
{
	MapEditMenu_Wheel( -1 )
}

void function MapEditMenu_WheelDown( var b )
{
	MapEditMenu_Wheel( 1 )
}

// The wheel zooms over the preview and scrolls whichever list is under the cursor.
void function MapEditMenu_Wheel( int dir )
{
	// The map packs popup lists every map at once; the lists behind it stay put.
	if ( !file.isOpen || file.packsOpen || GetActiveMenu() != file.menu )
		return

	if ( file.fullscreen || MapEditMenu_CursorIn( ME_PREV_X, ME_PREV_Y, ME_PREV_W, ME_PREV_H ) )
	{
		MapEditMenu_ZoomTo( file.zoom * ( dir < 0 ? 1.12 : 1.0 / 1.12 ) )
		return
	}
	if ( MapEditMenu_CursorIn( ME_CAT_X, 116.0, ME_CAT_W, 924.0 ) )
	{
		int maxScroll = maxint( 0, file.categories.len() - ME_CAT_ROWS )
		file.catScroll = minint( maxScroll, maxint( 0, file.catScroll + dir * 3 ) )
		MapEditMenu_RefreshCategories()
		return
	}
	if ( MapEditMenu_CursorIn( ME_MOD_X, 116.0, ME_MOD_W, 924.0 ) )
	{
		int maxScroll = maxint( 0, file.rows.len() - ME_MOD_ROWS )
		file.rowScroll = minint( maxScroll, maxint( 0, file.rowScroll + dir * 3 ) )
		MapEditMenu_RefreshRows()
	}
}

bool function MapEditMenu_CursorIn( float x, float y, float w, float h )
{
	vector c = MapEditMenu_CursorAuthored()
	return c.x >= x && c.x <= x + w && c.y >= y && c.y <= y + h
}

// Cursor in the 1920x1080 authoring frame, which the .res centres horizontally.
vector function MapEditMenu_CursorAuthored()
{
	vector c = GetCursorPosition()
	UISize screen = GetScreenSize()
	float scale = float( screen.height ) / 1080.0
	float frameW = 1920.0 * scale
	float px = c.x * float( screen.width ) / 1920.0
	float py = c.y * float( screen.height ) / 1080.0
	return < ( px - ( float( screen.width ) - frameW ) * 0.5 ) / scale, py / scale, 0 >
}

// ---------------------------------------------------------------------------
// Frame thread: mouse drag orbit / pan / zoom slider, sticks, triggers, toast
// ---------------------------------------------------------------------------

void function MapEditMenu_Thread()
{
	bool dragging = false
	bool panning = false
	bool sliding = false
	vector last = <0, 0, 0>
	float lastTime = UITime()

	while ( file.isOpen )
	{
		float now = UITime()
		float dt = clamp( now - lastTime, 0.0, 0.1 )
		lastTime = now
		bool active = GetActiveMenu() == file.menu && !file.typing && !file.packsOpen
		bool orbitDown = active && ( InputIsButtonDown( MOUSE_LEFT ) || InputIsButtonDown( MOUSE_RIGHT ) )
		bool panDown = active && InputIsButtonDown( MOUSE_MIDDLE )
		vector cur = MapEditMenu_CursorAuthored()

		if ( !dragging && !panning && !sliding && ( orbitDown || panDown ) )
		{
			if ( InputIsButtonDown( MOUSE_LEFT ) && MapEditMenu_CursorOverSlider() )
			{
				sliding = true
			}
			else if ( MapEditMenu_CursorOverPreview() )
			{
				dragging = orbitDown
				panning = panDown && !orbitDown
			}
			last = cur
		}
		if ( dragging && !orbitDown )
			dragging = false
		if ( panning && !panDown )
			panning = false
		if ( sliding && !InputIsButtonDown( MOUSE_LEFT ) )
			sliding = false

		if ( sliding )
		{
			float tbX = file.fullscreen ? ME_TB_FULL_X : ME_TB_BROWSE_X
			array< float > slider = MapEditMenu_ToolRect( "slider", tbX, 0.0 )
			float t = clamp( ( cur.x - slider[0] ) / slider[2], 0.0, 1.0 )
			MapEditMenu_ZoomTo( ME_ZOOM_MIN + t * ( ME_ZOOM_MAX - ME_ZOOM_MIN ) )
		}
		else if ( dragging || panning )
		{
			vector d = cur - last
			last = cur
			if ( fabs( d.x ) + fabs( d.y ) > 0.01 )
			{
				if ( dragging )
					RunClientScript( "UIToClient_MapEditPreview_Orbit", d.x * ME_ORBIT_DEG_PER_PX, -d.y * ME_ORBIT_DEG_PER_PX )
				else
					RunClientScript( "UIToClient_MapEditPreview_Pan", -d.x * ME_PAN_PER_PX, d.y * ME_PAN_PER_PX )
			}
		}

		if ( active && file.pad )
		{
			float rx = InputGetAxis( ANALOG_RIGHT_X )
			float ry = InputGetAxis( ANALOG_RIGHT_Y )
			if ( fabs( rx ) > ME_STICK_DEADZONE || fabs( ry ) > ME_STICK_DEADZONE )
				RunClientScript( "UIToClient_MapEditPreview_Orbit", rx * ME_STICK_DEG_PER_SEC * dt, -ry * ME_STICK_DEG_PER_SEC * dt )
			float zoomDir = ( InputIsButtonDown( BUTTON_TRIGGER_RIGHT ) ? 1.0 : 0.0 ) - ( InputIsButtonDown( BUTTON_TRIGGER_LEFT ) ? 1.0 : 0.0 )
			if ( zoomDir != 0.0 )
				MapEditMenu_ZoomTo( file.zoom * pow( ME_TRIGGER_ZOOM_PER_SEC, zoomDir * dt ) )
		}

		if ( file.toast != "" && UITime() > file.toastUntil )
		{
			file.toast = ""
			MapEditMenu_RefreshToast()
		}
		WaitFrame()
	}
}

// Over the preview but not over the toolbar or the fullscreen buttons.
bool function MapEditMenu_CursorOverPreview()
{
	float x = file.fullscreen ? ME_FULL_X : ME_PREV_X
	float y = file.fullscreen ? ME_FULL_Y : ME_PREV_Y
	float w = file.fullscreen ? ME_FULL_W : ME_PREV_W
	float h = file.fullscreen ? ME_FULL_H : ME_PREV_H
	if ( !MapEditMenu_CursorIn( x, y, w, h ) )
		return false
	float tbX = file.fullscreen ? ME_TB_FULL_X : ME_TB_BROWSE_X
	float tbY = file.fullscreen ? ME_TB_FULL_Y : ME_TB_BROWSE_Y
	if ( MapEditMenu_CursorIn( tbX, tbY, ME_TB_W, ME_TOOL_H + ME_TOOL_PAD * 2.0 ) )
		return false
	return !file.fullscreen || !MapEditMenu_CursorIn( 1556.0, 962.0, 324.0, 78.0 )
}

bool function MapEditMenu_CursorOverSlider()
{
	float tbX = file.fullscreen ? ME_TB_FULL_X : ME_TB_BROWSE_X
	float tbY = file.fullscreen ? ME_TB_FULL_Y : ME_TB_BROWSE_Y
	array< float > r = MapEditMenu_ToolRect( "slider", tbX, tbY )
	return MapEditMenu_CursorIn( r[0], r[1], r[2], r[3] )
}

// [x, y, w, h] of a toolbar item for a toolbar whose backing starts at (tbX, tbY).
array< float > function MapEditMenu_ToolRect( string key, float tbX, float tbY )
{
	array< string > seq = MapEditMenu_ToolSeq()
	array< float > widths = MapEditMenu_ToolSeqWidths()
	float x = tbX + ME_TOOL_PAD
	bool prevItem = false
	foreach ( int i, string k in seq )
	{
		if ( k == "" )
		{
			x += ME_TOOL_DIV
			prevItem = false
			continue
		}
		if ( prevItem )
			x += ME_TOOL_GAP
		if ( k == key )
			return [ x, tbY + ME_TOOL_PAD, widths[i], ME_TOOL_H ]
		x += widths[i]
		prevItem = true
	}
	return [ -100.0, -100.0, 0.0, 0.0 ]
}

void function MapEditMenu_Toast( string msg )
{
	file.toast = msg
	file.toastUntil = UITime() + ME_TOAST_TIME
	MapEditMenu_RefreshToast()
}

// ---------------------------------------------------------------------------
// RUI writes
// ---------------------------------------------------------------------------

void function MESetPx( var rui, string name, float x, float y )
{
	RuiSetFloat2( rui, name, < x / 1920.0, y / 1080.0, 0 > )
}

void function MEHidePx( var rui, string name )
{
	RuiSetFloat2( rui, name, < -2.0, -2.0, 0 > )
}

void function MESetQuad( var rui, string prefix, float x, float y, float w, float h )
{
	MESetPx( rui, prefix + "TL", x, y )
	MESetPx( rui, prefix + "TR", x + w, y )
	MESetPx( rui, prefix + "BL", x, y + h )
}

void function MEHideQuad( var rui, string prefix )
{
	MEHidePx( rui, prefix + "TL" )
	MEHidePx( rui, prefix + "TR" )
	MEHidePx( rui, prefix + "BL" )
}

void function MESetOutline( var rui, string prefix, float x, float y, float w, float h, float t )
{
	MESetQuad( rui, prefix + "T", x, y, w, t )
	MESetQuad( rui, prefix + "B", x, y + h - t, w, t )
	MESetQuad( rui, prefix + "L", x, y, t, h )
	MESetQuad( rui, prefix + "R", x + w - t, y, t, h )
}

void function MEHideOutline( var rui, string prefix )
{
	foreach ( string side in [ "T", "B", "L", "R" ] )
		MEHideQuad( rui, prefix + side )
}

void function MECol( var rui, string name, vector srgb, float a )
{
	RuiSetColorAlpha( rui, name, SrgbToLinear( srgb ), a )
}

const vector ME_C_TEXT = <0.914, 0.929, 0.949>
const vector ME_C_SUB = <0.831, 0.859, 0.890>
const vector ME_C_DIM = <0.604, 0.651, 0.706>
const vector ME_C_MUTED = <0.498, 0.541, 0.596>
const vector ME_C_DARK = <0.043, 0.055, 0.071>
const vector ME_C_ACCENT = <0.949, 0.439, 0.227>
const vector ME_C_CYAN = <0.345, 0.780, 0.855>
const vector ME_C_ROW = <0.078, 0.094, 0.125>
const vector ME_C_ROW_SEL = <0.122, 0.149, 0.188>
const vector ME_C_BTN = <0.086, 0.102, 0.125>
const vector ME_C_BORDER = <0.173, 0.200, 0.239>
const vector ME_C_EDGE = <0.133, 0.157, 0.192>
const vector ME_C_CLS = <0.227, 0.267, 0.314>

void function MapEditMenu_InitColors()
{
	MECol( file.browserRui, "toastColor", ME_C_ACCENT, 0.0 )
	MECol( file.browserRui, "toastTextColor", ME_C_DARK, 0.0 )
	MapEditMenu_RefreshToast()
	MapEditMenu_RefreshSearch()
}

void function MapEditMenu_ApplyMode()
{
	bool full = file.fullscreen
	foreach ( var panel in [ file.catsPanel, file.modelsPanel, file.infoPanel, file.searchEntry, file.previewArea ] )
		Hud_SetVisible( panel, !full )
	Hud_SetVisible( file.previewAreaFs, full )
	foreach ( array< var > group in [ file.tabButtons, file.catButtons, file.rowButtons, file.setButtons ] )
	{
		foreach ( var b in group )
			Hud_SetVisible( b, !full )
	}
	foreach ( string k, var b in file.filterButtons )
		Hud_SetVisible( b, !full )
	foreach ( string k, var b in file.infoButtons )
		Hud_SetVisible( b, !full )
	foreach ( string k, var b in file.toolButtons )
		Hud_SetVisible( b, !full )
	foreach ( string k, var b in file.toolButtonsFs )
		Hud_SetVisible( b, full )
	foreach ( string k, var b in file.fsButtons )
		Hud_SetVisible( b, full )

	MapEditMenu_RefreshRail()
	MapEditMenu_RefreshPreviewChrome()
	MapEditMenu_RefreshCategories()
	MapEditMenu_RefreshRows()
	MapEditMenu_RefreshInfo()
}

// Rail rows: [ key token, label ]; a row with an empty key token is a section header.
void function MapEditMenu_RefreshRail()
{
	var rui = file.browserRui
	array< array< string > > rows
	if ( file.fullscreen && file.pad )
	{
		rows = [ [ "", "CAMERA" ], [ "%[STICK2|]%", "Orbit" ], [ "%[L_TRIGGER|]% %[R_TRIGGER|]%", "Zoom" ],
			[ "%[STICK2|]%", "Click: reset / fit" ], [ "%[STICK1|]%", "Click: auto spin" ],
			[ "", "MODEL" ], [ "%[LEFT|]% %[RIGHT|]%", "Prev / next" ], [ "%[START|]%", "Next quick slot" ],
			[ "%[A_BUTTON|]%", "Pick / place" ], [ "%[Y_BUTTON|]%", "Back to list" ], [ "%[B_BUTTON|]%", "Back to list" ] ]
	}
	else if ( file.fullscreen )
	{
		rows = [ [ "", "CAMERA" ], [ "%[|MOUSE1]%", "Drag to orbit" ], [ "%[|MOUSE3]%", "Drag to pan" ], [ "%[|MWHEELUP]%", "Zoom" ],
			[ "%[|R]%", "Reset / fit" ], [ "%[|SPACE]%", "Auto spin" ],
			[ "", "VIEW" ], [ "%[|B]%", "Bounds" ], [ "%[|L]%", "Light rig" ],
			[ "", "MODEL" ], [ "%[|A]% %[|D]%", "Prev / next" ], [ "%[|1]%%[|2]%%[|3]%", "Quick slot" ], [ "%[|ENTER]%", "Place" ], [ "%[|F]%", "Back to list" ] ]
	}
	else if ( file.pad )
	{
		rows = [ [ "", "BROWSE" ], [ "%[UP|]% %[DOWN|]%", "Select model" ], [ "%[LEFT|]% %[RIGHT|]%", "Category" ],
			[ "%[L_SHOULDER|]% %[R_SHOULDER|]%", "Build / Extra" ], [ "%[BACK|]%", "Collision filter" ],
			[ "%[A_BUTTON|]%", "Pick / place" ], [ "%[X_BUTTON|]%", "Favorite" ], [ "%[START|]%", "Next quick slot" ],
			[ "", "PREVIEW" ], [ "%[STICK2|]%", "Orbit" ], [ "%[L_TRIGGER|]% %[R_TRIGGER|]%", "Zoom" ],
			[ "%[STICK1|]%", "Click: auto spin" ], [ "%[STICK2|]%", "Click: reset view" ], [ "%[Y_BUTTON|]%", "Fullscreen" ],
			[ "", "MENU" ], [ "%[B_BUTTON|]%", "Close" ] ]
	}
	else
	{
		rows = [ [ "", "BROWSE" ], [ "%[|W]% %[|S]%", "Select model" ], [ "%[|Q]% %[|E]%", "Category" ], [ "%[|TAB]%", "Build / Extra" ],
			[ "%[|C]%", "Collision filter" ], [ "%[|ENTER]%", "Place" ], [ "%[|V]%", "Favorite" ], [ "%[|1]%%[|2]%%[|3]%", "Quick slot" ],
			[ "", "PREVIEW" ], [ "%[|MOUSE1]%", "Drag to rotate" ], [ "%[|MWHEELUP]%", "Zoom" ], [ "%[|SPACE]%", "Auto spin" ],
			[ "%[|R]%", "Reset view" ], [ "%[|F]%", "Fullscreen" ],
			[ "", "MENU" ], [ "%[|ESCAPE]%", "Close" ] ]
	}
	for ( int i = 0; i < ME_RAIL_ROWS; i++ )
	{
		bool has = i < rows.len()
		bool head = has && rows[i][0] == ""
		RuiSetString( rui, "hkKey" + i, has && !head ? rows[i][0] : "" )
		RuiSetString( rui, "hkText" + i, has && !head ? rows[i][1] : "" )
		RuiSetString( rui, "hkHead" + i, head ? rows[i][1] : "" )
		MECol( rui, "hkLine" + i, ME_C_EDGE, head ? 1.0 : 0.0 )
	}
}

// The menu canvas is 1920x1080 scaled to the screen height and centred horizontally.
void function MapEditMenu_PushPreviewRect( float x, float y, float w, float h )
{
	UISize screen = GetScreenSize()
	float sw = float( maxint( 1, screen.width ) )
	float sh = float( maxint( 1, screen.height ) )
	float k = sh / 1080.0
	vector rect = < ( sw * 0.5 + ( x - 960.0 ) * k ) / sw, y * k / sh, 0 >
	vector size = < w * k / sw, h * k / sh, 0 >
	if ( rect == file.previewRect && size == file.previewSize )
		return
	file.previewRect = rect
	file.previewSize = size
	RunClientScript( "UIToClient_MapEditPreview_SetRect", rect.x, rect.y, size.x, size.y )
}

void function MapEditMenu_RefreshPreviewChrome()
{
	var rui = file.browserRui
	bool full = file.fullscreen
	float x = full ? ME_FULL_X : ME_PREV_X
	float y = full ? ME_FULL_Y : ME_PREV_Y
	float w = full ? ME_FULL_W : ME_PREV_W
	float h = full ? ME_FULL_H : ME_PREV_H

	// Once the client's menu camera is live the model is drawn by the 3D view behind
	// this menu, so the preview rect and the screen behind it are left clear.
	bool live = file.pipSlot >= 0
	if ( live )
	{
		MEHideQuad( rui, "pvBg" )
		MEHideQuad( rui, "pvFloor" )
	}
	else
	{
		MESetQuad( rui, "pvBg", x, y, w, h )
		MESetQuad( rui, "pvFloor", x, y + h * 0.62, w, h * 0.38 )
	}
	MEHideQuad( rui, "cam" )
	RuiSetInt( rui, "pipSlot", -1 )
	Hud_SetVisible( Hud_GetChild( file.menu, "DarkenBackground" ), !live )
	foreach ( string side in [ "Top", "Bottom", "Left", "Right" ] )
	{
		Hud_SetVisible( Hud_GetChild( file.menu, "DimBrowse" + side ), live && !full )
		Hud_SetVisible( Hud_GetChild( file.menu, "DimFull" + side ), live && full )
	}
	MapEditMenu_PushPreviewRect( x, y, w, h )
	MESetQuad( rui, "pvEdgeT", x, y, w, 1.0 )
	MESetQuad( rui, "pvEdgeB", x, y + h - 1.0, w, 1.0 )
	MESetQuad( rui, "pvEdgeL", x, y, 1.0, h )
	MESetQuad( rui, "pvEdgeR", x + w - 1.0, y, 1.0, h )

	float arm = 34.0
	float t = 2.0
	float ins = 20.0
	array< vector > corners = [ < x + ins, y + ins, 0 >, < x + w - ins, y + ins, 0 >, < x + ins, y + h - ins, 0 >, < x + w - ins, y + h - ins, 0 > ]
	foreach ( int i, vector c in corners )
	{
		bool right = i == 1 || i == 3
		bool bottom = i >= 2
		MESetQuad( rui, "br" + ( i * 2 ), right ? c.x - arm : c.x, bottom ? c.y - t : c.y, arm, t )
		MESetQuad( rui, "br" + ( i * 2 + 1 ), right ? c.x - t : c.x, bottom ? c.y - arm : c.y, t, arm )
	}

	string msg = file.previewMsg
	if ( msg == "" && file.selKind == 0 )
		msg = "PICK A MODEL"
	else if ( msg == "" && file.selKind == 1 && !file.resident )
		msg = "LOADING MODEL"
	RuiSetString( rui, "msgText", msg )
	MESetPx( rui, "msgPos", x + w * 0.5, y + h * 0.5 )

	bool fit = ( file.opts & ME_OPT_FIT ) != 0
	bool offscreen = !fit && ( file.onScreenFrac > 1.15 || file.onScreenFrac < 0.02 )
	MESetQuad( rui, "fitChip", x + 36.0, y + 34.0, 104.0, 24.0 )
	MECol( rui, "fitChipColor", fit ? ME_C_CYAN : ( offscreen ? ME_C_ACCENT : ME_C_TEXT ), 1.0 )
	RuiSetString( rui, "fitText", fit ? "AUTO-FIT" : ( offscreen ? "OFF SCREEN" : "TRUE SCALE" ) )
	MESetPx( rui, "fitTextPos", x + 88.0, y + 46.0 )
	array< string > lightNames = [ "STUDIO", "BRIGHT", "DRAMATIC" ]
	RuiSetString( rui, "scaleText", file.selKind == 0 ? "" : format( "%.2fx  |  %s  |  %s", file.scale, MapEditMenu_SizeClass( file.dims ), lightNames[file.light] ) )
	MESetPx( rui, "scalePos", x + 152.0, y + 46.0 )

	bool showDims = file.bounds && file.selKind != 0 && file.resident
	RuiSetString( rui, "dimW", showDims ? format( "W %d u", int( file.dims.x + 0.5 ) ) : "" )
	RuiSetString( rui, "dimD", showDims ? format( "D %d u", int( file.dims.y + 0.5 ) ) : "" )
	RuiSetString( rui, "dimH", showDims ? format( "H %d u", int( file.dims.z + 0.5 ) ) : "" )
	MESetPx( rui, "dimWPos", x + 36.0, y + 78.0 )
	MESetPx( rui, "dimDPos", x + 36.0, y + 100.0 )
	MESetPx( rui, "dimHPos", x + 36.0, y + 122.0 )

	RuiSetString( rui, "yawText", format( "YAW %d DEG", int( file.yaw ) ) )
	RuiSetString( rui, "pitchText", format( "PITCH %d DEG", int( file.pitch ) ) )
	RuiSetString( rui, "zoomText", format( "ZOOM %d%%", int( file.zoom * 100.0 + 0.5 ) ) )
	MESetPx( rui, "yawPos", x + w - 36.0, y + 46.0 )
	MESetPx( rui, "pitchPos", x + w - 36.0, y + 68.0 )
	MESetPx( rui, "zoomPos", x + w - 36.0, y + 90.0 )

	float tbX = full ? ME_TB_FULL_X : ME_TB_BROWSE_X
	float tbY = full ? ME_TB_FULL_Y : ME_TB_BROWSE_Y
	float tbH = ME_TOOL_H + ME_TOOL_PAD * 2.0
	MESetQuad( rui, "tbEdge", tbX - 1.0, tbY - 1.0, ME_TB_W + 2.0, tbH + 2.0 )
	MESetQuad( rui, "tbBg", tbX, tbY, ME_TB_W, tbH )
	array< string > seq = MapEditMenu_ToolSeq()
	array< float > widths = MapEditMenu_ToolSeqWidths()
	float cx = tbX + ME_TOOL_PAD
	int div = 0
	bool prevItem = false
	foreach ( int i, string k in seq )
	{
		if ( k == "" )
		{
			MESetQuad( rui, "tbDiv" + div, cx + ME_TOOL_DIV * 0.5 - 0.5, tbY + ME_TOOL_PAD + 8.0, 1.0, ME_TOOL_H - 16.0 )
			div++
			cx += ME_TOOL_DIV
			prevItem = false
			continue
		}
		if ( prevItem )
			cx += ME_TOOL_GAP
		float iw = widths[i]
		float iy = tbY + ME_TOOL_PAD
		if ( k == "slider" )
		{
			float tz = clamp( ( file.zoom - ME_ZOOM_MIN ) / ( ME_ZOOM_MAX - ME_ZOOM_MIN ), 0.0, 1.0 )
			MESetQuad( rui, "slTrack", cx, iy + ME_TOOL_H * 0.5 - 2.0, iw, 4.0 )
			MESetQuad( rui, "slFill", cx, iy + ME_TOOL_H * 0.5 - 2.0, iw * tz, 4.0 )
			MESetQuad( rui, "slKnob", cx + iw * tz - 7.0, iy + ME_TOOL_H * 0.5 - 7.0, 14.0, 14.0 )
		}
		else
		{
			bool on = ( k == "spin" && ( file.opts & ME_OPT_SPIN ) != 0 ) || ( k == "fit" && fit ) || ( k == "bounds" && file.bounds )
			bool accent = k == "full"
			MESetQuad( rui, "tbLine_" + k, cx, iy, iw, ME_TOOL_H )
			MESetQuad( rui, "tb_" + k, cx + 1.0, iy + 1.0, iw - 2.0, ME_TOOL_H - 2.0 )
			MECol( rui, "tbLine_" + k, accent ? ME_C_ACCENT : ( on ? ME_C_CYAN : ME_C_BORDER ), 1.0 )
			MECol( rui, "tbFill_" + k, ME_C_BTN, 1.0 )
			MECol( rui, "tbText_" + k, accent ? ME_C_ACCENT : ( on ? ME_C_TEXT : ME_C_SUB ), 1.0 )
			MESetPx( rui, "tbPos_" + k, cx + iw * 0.5, iy + ME_TOOL_H * 0.5 )
		}
		cx += iw
		prevItem = true
	}
	RuiSetString( rui, "fullLabel", full ? "EXIT" : "FULL" )

	float fa = full ? 1.0 : 0.0
	MECol( rui, "fsColor", ME_C_TEXT, fa )
	MECol( rui, "fsSubColor", ME_C_DIM, fa )
	MECol( rui, "fsBtnColor", ME_C_BTN, fa )
	MECol( rui, "fsLineColor", ME_C_BORDER, fa )
	MECol( rui, "fsPlaceColor", ME_C_ACCENT, fa )
	MECol( rui, "fsPlaceText", ME_C_DARK, fa )
	MECol( rui, "exitColor", ME_C_BTN, fa )
	MECol( rui, "exitLine", ME_C_BORDER, fa )
	MECol( rui, "exitText", ME_C_SUB, fa )
	RuiSetString( rui, "fsName", MapEditMenu_Truncate( MapEditMenu_SelectionName(), 34 ) )
	RuiSetString( rui, "fsPath", MapEditMenu_SelectionPath() )

	int total = 0
	string mapName = GetActiveLevel()
	foreach ( string cat in MapEditorCatalog_GetCategories() )
		total += MapEditorCatalog_GetAvailableCategoryEntries( cat, mapName ).len()
	RuiSetString( rui, "headerInfo", full ? "INSPECT" : format( "%d MODELS  |  %s", total, mapName.toupper() ) )
	MESetPx( rui, "headerInfoPos", full ? 1660.0 : 1880.0, 66.0 )
}

void function MapEditMenu_RefreshToast()
{
	var rui = file.browserRui
	bool on = file.toast != ""
	RuiSetString( rui, "toastText", file.toast )
	float w = 28.0 + 13.0 * float( file.toast.len() )
	MESetQuad( rui, "toastBg", 960.0 - w * 0.5, 86.0, w, 36.0 )
	MECol( rui, "toastColor", ME_C_ACCENT, on ? 1.0 : 0.0 )
	MECol( rui, "toastTextColor", ME_C_DARK, on ? 1.0 : 0.0 )
}

void function MapEditMenu_RefreshSearch()
{
	var rui = file.modelsRui
	MECol( rui, "searchLine", file.typing ? ME_C_CYAN : ME_C_BORDER, 1.0 )
	// The RUI draws the typed text; the text entry underneath only takes the keys.
	string typed = Hud_GetUTF8Text( file.searchEntry )
	bool hint = typed == "" && !file.typing
	RuiSetString( rui, "searchHint", hint ? "barrel, sign, rock..." : typed + ( file.typing ? "_" : "" ) )
	MECol( rui, "searchHintColor", hint ? ME_C_MUTED : ME_C_TEXT, 1.0 )
	array< string > keys = [ "all", "solid", "ghost" ]
	foreach ( int i, string k in keys )
	{
		bool on = i == file.filter
		MECol( rui, "fBg_" + k, ME_C_TEXT, on ? 1.0 : 0.0 )
		MECol( rui, "fLine_" + k, on ? ME_C_TEXT : ME_C_BORDER, 1.0 )
		MECol( rui, "fText_" + k, on ? ME_C_DARK : ME_C_DIM, 1.0 )
	}
}

void function MapEditMenu_RefreshCategories()
{
	var rui = file.catsRui
	for ( int i = 0; i < 2; i++ )
	{
		bool on = i == file.tier && file.query == ""
		MECol( rui, "tabBg" + i, ME_C_TEXT, on ? 1.0 : 0.0 )
		MECol( rui, "tabLine" + i, on ? ME_C_TEXT : ME_C_BORDER, 1.0 )
		MECol( rui, "tabText" + i, on ? ME_C_DARK : ME_C_DIM, 1.0 )
	}

	string mapName = GetActiveLevel()
	for ( int i = 0; i < ME_CAT_ROWS; i++ )
	{
		int idx = file.catScroll + i
		bool has = idx < file.categories.len()
		string cat = has ? file.categories[idx] : ""
		bool on = has && cat == file.category && file.query == ""
		MECol( rui, "catBg" + i, on ? ME_C_ACCENT : ME_C_ROW, has ? 1.0 : 0.0 )
		MECol( rui, "catTextColor" + i, on ? ME_C_DARK : ME_C_SUB, 1.0 )
		MECol( rui, "catCountColor" + i, on ? ME_C_DARK : ME_C_MUTED, 1.0 )
		RuiSetString( rui, "catText" + i, has ? MapEditMenu_CategoryLabel( cat ) : "" )
		RuiSetString( rui, "catCount" + i, has ? string( MapEditMenu_CategoryCount( cat, mapName ) ) : "" )
		Hud_SetEnabled( file.catButtons[i], has )
	}
	MapEditMenu_RefreshSearch()
}

string function MapEditMenu_CategoryLabel( string cat )
{
	if ( cat == ME_CAT_FAVORITES )
		return "Favorites"
	if ( cat == ME_CAT_TOOLS )
		return "Tools"
	array< string > words = split( cat, "_" )
	string out = ""
	foreach ( string w in words )
	{
		if ( w.len() == 0 )
			continue
		out += ( out == "" ? w.slice( 0, 1 ).toupper() + w.slice( 1, w.len() ) : " " + w )
	}
	return out
}

int function MapEditMenu_CategoryCount( string cat, string mapName )
{
	if ( cat == ME_CAT_FAVORITES )
		return file.favs.len()
	if ( cat == ME_CAT_TOOLS )
		return 5 + MAPEDIT_SAVE_SLOTS * 2 + 2
	return MapEditMenu_Entries( cat, mapName ).len()
}

void function MapEditMenu_RefreshRows()
{
	var rui = file.modelsRui
	RuiSetString( rui, "listTitle", file.query != "" ? "Results for \"" + MapEditMenu_Truncate( file.query, 20 ) + "\"" : MapEditMenu_CategoryLabel( file.category ) )
	RuiSetString( rui, "listCount", file.rows.len() > ME_MOD_ROWS ? format( "%d-%d of %d", file.rowScroll + 1, minint( file.rows.len(), file.rowScroll + ME_MOD_ROWS ), file.rows.len() ) : string( file.rows.len() ) + " shown" )

	bool selShown = false
	for ( int i = 0; i < ME_MOD_ROWS; i++ )
	{
		int idx = file.rowScroll + i
		bool has = idx < file.rows.len()
		float y = ME_MOD_ROW_Y0 + float( i ) * ME_MOD_ROW_STEP
		float x0 = ME_MOD_X + 14.0
		Hud_SetEnabled( file.rowButtons[i], has )
		if ( !has )
		{
			MECol( rui, "rowBg" + i, ME_C_ROW, 0.0 )
			MECol( rui, "glyphColor" + i, ME_C_CYAN, 0.0 )
			foreach ( string q in [ "glyphOut", "glyphIn", "clsOut", "clsIn" ] )
				MEHideQuad( rui, q + i )
			foreach ( string a in [ "rowName", "rowDims", "rowClass", "rowFav" ] )
				RuiSetString( rui, a + i, "" )
			continue
		}

		MEBrowserRow r = file.rows[idx]
		bool on = r.kind == file.selKind && r.id == file.selId && r.kind != 3
		if ( on )
		{
			selShown = true
			MESetOutline( rui, "selLine", x0, y, ME_MOD_W - 28.0, ME_MOD_ROW_H, 1.0 )
		}
		MECol( rui, "rowBg" + i, on ? ME_C_ROW_SEL : ME_C_ROW, 1.0 )
		RuiSetString( rui, "rowName" + i, MapEditMenu_Truncate( r.name, 32 ) )

		bool known = r.kind == 1 && r.id in file.sizes
		vector d = known ? file.sizes[r.id] : <0, 0, 0>
		string sub = r.sub
		if ( r.kind == 1 )
		{
			sub = known ? format( "%d x %d x %d u", int( d.x + 0.5 ), int( d.y + 0.5 ), int( d.z + 0.5 ) ) : "#" + r.id
			if ( r.id in file.collision && file.collision[r.id] == 0 )
				sub += "   no collision"
		}
		RuiSetString( rui, "rowDims" + i, sub )
		RuiSetString( rui, "rowFav" + i, ( r.kind == 1 && r.id in file.favs ) ? "*" : "" )

		string cls = known ? MapEditMenu_SizeClass( d ) : ( r.kind == 2 ? "FX" : ( r.kind == 3 ? "RUN" : "" ) )
		RuiSetString( rui, "rowClass" + i, cls )
		if ( cls != "" )
		{
			float cw = 14.0 + 10.0 * float( cls.len() )
			float cxp = ME_MOD_X + ME_MOD_W - 50.0 - cw
			MESetQuad( rui, "clsOut" + i, cxp, y + 17.0, cw, 22.0 )
			MESetQuad( rui, "clsIn" + i, cxp + 1.0, y + 18.0, cw - 2.0, 20.0 )
			MESetPx( rui, "clsPos" + i, cxp + cw * 0.5, y + 28.0 )
		}
		else
		{
			MEHideQuad( rui, "clsOut" + i )
			MEHideQuad( rui, "clsIn" + i )
		}

		// side-view outline of the model, sitting on the base line
		float gw = 12.0
		float gh = 12.0
		if ( known && d.x + d.y + d.z > 0.0 )
		{
			float big = max( max( d.x, d.y ), d.z )
			gw = max( 4.0, 30.0 * max( d.x, d.y ) / big )
			gh = max( 4.0, 30.0 * d.z / big )
		}
		float gx = x0 + 29.0 - gw * 0.5
		float gy = y + 44.0 - gh
		MESetQuad( rui, "glyphOut" + i, gx, gy, gw, gh )
		MESetQuad( rui, "glyphIn" + i, gx + 1.5, gy + 1.5, max( 0.0, gw - 3.0 ), max( 0.0, gh - 3.0 ) )
		MECol( rui, "glyphColor" + i, on ? ME_C_ACCENT : ME_C_CYAN, known ? 1.0 : 0.35 )
	}
	if ( !selShown )
		MEHideOutline( rui, "selLine" )
}

string function MapEditMenu_SizeClass( vector d )
{
	float r = sqrt( d.x * d.x + d.y * d.y + d.z * d.z )
	if ( r <= 0.0 )
		return ""
	if ( r < 48.0 )
		return "S"
	if ( r < 192.0 )
		return "M"
	if ( r < 640.0 )
		return "L"
	return "XL"
}

string function MapEditMenu_SelectionName()
{
	if ( file.selKind == 2 )
	{
		array< string > names = [ "#MAPEDIT_TOOL_JUMPPAD", "#MAPEDIT_TOOL_DOOR", "#MAPEDIT_TOOL_DOUBLEDOOR", "#MAPEDIT_TOOL_LOOTBIN", "#MAPEDIT_TOOL_EFFECT" ]
		return ( file.selId >= 1 && file.selId <= 5 ) ? Localize( names[file.selId - 1] ) : ""
	}
	if ( file.selKind == 1 )
	{
		MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( file.selId )
		if ( e != null )
			return MapEditMenu_Stem( ( expect MapEditorCatalogEntry( e ) ).model )
	}
	return "No model selected"
}

string function MapEditMenu_SelectionPath()
{
	if ( file.selKind == 1 )
	{
		MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( file.selId )
		if ( e != null )
			return string( ( expect MapEditorCatalogEntry( e ) ).model )
	}
	if ( file.selKind == 2 )
		return "Placeable"
	return ""
}

void function MapEditMenu_RefreshInfo()
{
	var rui = file.infoRui
	RuiSetString( rui, "selName", MapEditMenu_Truncate( MapEditMenu_SelectionName(), 28 ) )
	RuiSetString( rui, "selPath", MapEditMenu_Truncate( MapEditMenu_SelectionPath(), 60 ) )

	array< string > chips = [ "", "", "" ]
	if ( file.selKind == 1 )
	{
		MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( file.selId )
		if ( e != null )
			chips[0] = MapEditMenu_CategoryLabel( ( expect MapEditorCatalogEntry( e ) ).category )
		if ( file.selId in file.sizes )
		{
			vector d = file.sizes[file.selId]
			chips[1] = format( "%d x %d x %d u", int( d.x + 0.5 ), int( d.y + 0.5 ), int( d.z + 0.5 ) )
		}
		if ( file.selId in file.collision )
			chips[2] = file.collision[file.selId] == 1 ? "Solid" : ( file.collision[file.selId] == 0 ? "No collision" : "" )
	}
	else if ( file.selKind == 2 )
	{
		chips[0] = "Tools"
		chips[1] = "Placeable"
	}
	float cx = ME_INFO_X + 22.0
	for ( int i = 0; i < 3; i++ )
	{
		RuiSetString( rui, "chipText" + i, chips[i] )
		if ( chips[i] == "" )
		{
			MEHideQuad( rui, "chip" + i )
			continue
		}
		float w = 22.0 + 8.2 * float( chips[i].len() )
		MESetQuad( rui, "chip" + i, cx, ME_INFO_Y + 92.0, w, 28.0 )
		MESetPx( rui, "chipPos" + i, cx + w * 0.5, ME_INFO_Y + 106.0 )
		cx += w + 8.0
	}
	RuiSetString( rui, "favLabel", ( file.selKind == 1 && file.selId in file.favs ) ? "Unfavorite" : "Favorite" )

	array< string > labels = [ "Auto-fit every model", "Auto spin", "Keep angle between models", "Open previews fullscreen" ]
	array< int > bits = [ ME_OPT_FIT, ME_OPT_SPIN, ME_OPT_KEEP, ME_OPT_FULL ]
	for ( int i = 0; i < ME_SET_ROWS; i++ )
	{
		bool on = ( file.opts & bits[i] ) != 0
		RuiSetString( rui, "setText" + i, labels[i] )
		MECol( rui, "setTrack" + i, on ? ME_C_CYAN : ME_C_CLS, 1.0 )
		float trackX = ME_SET_X + ME_SET_W - 44.0
		float rowY = ME_SET_Y0 + float( i ) * ME_SET_ROW_H
		MESetQuad( rui, "setKnob" + i, trackX + ( on ? 23.0 : 3.0 ), rowY + ME_SET_ROW_H * 0.5 - 9.0, 18.0, 18.0 )
	}
}
