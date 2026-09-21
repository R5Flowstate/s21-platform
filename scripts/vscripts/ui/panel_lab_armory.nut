untyped

// Lab > Armory. One grid for every giveable thing in the game.
// The catalog is read from the weapon registry and the loot table at open time,
// so anything the scripts add shows up here without touching this file.

global function InitLabArmoryPanel

global function LabArmory_SetCategories
global function LabArmory_CatalogBegin
global function LabArmory_CatalogRow
global function LabArmory_CatalogEnd
global function LabArmory_SelectCategory

const int LAB_TILE_COLS = 11
const int LAB_TILE_ROWS = 10
const int LAB_WEAPON_COLS = 7
const int LAB_TILE_W = 84
const int LAB_TILE_H = 89
const int LAB_WEAPON_TILE_W = 136
const int LAB_WEAPON_TILE_H = 68

const string LAB_CAT_WEAPONS = "weapons"

struct LabItem
{
	string ref
	string display
	int    tier
	bool   isWeapon
	bool   isAkimbo
}

struct
{
	var panel
	var contentPanelParent
	var contentPanel
	var scrollBar
	var scrollFrame

	array<var> tiles
	table< var, int > tileIndex

	var switchCategory
	var switchKit
	var switchDeliver
	var buttonRefill
	var buttonStrip

	array<string> categoryKeys
	array<string> categoryLabels
	string activeCategory = ""
	string pendingCategory = ""

	array<LabItem> items
	array<LabItem> building

	string kitTier = "gold"
	int deliverSlot = 0

	bool categoriesReady = false
	bool applyingValues = false
} file

void function InitLabArmoryPanel( var panel )
{
	file.panel = panel

	file.contentPanelParent = Hud_GetChild( panel, "ModeOptionsPanel" )
	file.contentPanel = Hud_GetChild( file.contentPanelParent, "ContentPanel" )
	file.scrollBar = Hud_GetChild( file.contentPanelParent, "ScrollBar" )
	file.scrollFrame = Hud_GetChild( file.contentPanelParent, "ScrollFrame" )

	file.switchCategory = Hud_GetChild( file.contentPanel, "SwitchCategory" )
	file.switchKit = Hud_GetChild( file.contentPanel, "SwitchKit" )
	file.switchDeliver = Hud_GetChild( file.contentPanel, "SwitchDeliver" )
	file.buttonRefill = Hud_GetChild( file.contentPanel, "ButtonRefillAmmo" )
	file.buttonStrip = Hud_GetChild( file.contentPanel, "ButtonStripWeapons" )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabArmoryPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabArmoryPanel_Hide )

	Lab_SetupRow( file.switchCategory, "#LAB_ARMORY_CATEGORY", "#LAB_ARMORY_CATEGORY_DESC" )
	Lab_SetupRow( file.switchKit, "#LAB_ARMORY_KIT", "#LAB_ARMORY_KIT_DESC" )
	Lab_SetupRow( file.switchDeliver, "#LAB_ARMORY_DELIVER", "#LAB_ARMORY_DELIVER_DESC" )
	Lab_SetupRow( file.buttonRefill, "#LAB_ARMORY_REFILL", "#LAB_ARMORY_REFILL_DESC" )
	Lab_SetupRow( file.buttonStrip, "#LAB_ARMORY_STRIP", "#LAB_ARMORY_STRIP_DESC" )

	LabArmory_BuildKitList()
	LabArmory_BuildDeliverList()

	AddButtonEventHandler( file.switchCategory, UIE_CHANGE, LabArmory_OnCategoryChanged )
	AddButtonEventHandler( file.switchKit, UIE_CHANGE, LabArmory_OnKitChanged )
	AddButtonEventHandler( file.switchDeliver, UIE_CHANGE, LabArmory_OnDeliverChanged )
	AddButtonEventHandler( file.buttonRefill, UIE_CLICK, LabArmory_OnRefill )
	AddButtonEventHandler( file.buttonStrip, UIE_CLICK, LabArmory_OnStrip )

	for ( int row = 0; row < LAB_TILE_ROWS; row++ )
	{
		for ( int col = 0; col < LAB_TILE_COLS; col++ )
		{
			var tile = Hud_GetChild( file.contentPanel, format( "Tile%d_%d", row, col ) )
			file.tileIndex[ tile ] <- file.tiles.len()
			file.tiles.append( tile )

			Hud_AddEventHandler( tile, UIE_CLICK, LabArmory_OnTileClick )
			Hud_AddEventHandler( tile, UIE_GET_FOCUS, LabArmory_OnTileFocus )
		}
	}

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_InitPanel( file.contentPanelParent )
	ScrollPanel_InitScrollBar( file.contentPanelParent, file.scrollBar )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	Lab_AddGateListener( LabArmory_ApplyGates )
}

void function OnLabArmoryPanel_Show( var panel )
{
	if ( !file.categoriesReady )
		RunClientScript( "Lab_RequestCategories" )
	else if ( file.items.len() == 0 && file.activeCategory != "" )
		LabArmory_LoadCategory( file.activeCategory )

	LabArmory_ApplyGates()

	ScrollPanel_SetActive( file.contentPanelParent, true )
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

void function OnLabArmoryPanel_Hide( var panel )
{
	ScrollPanel_SetActive( file.contentPanelParent, false )
}

void function LabArmory_BuildKitList()
{
	Hud_DialogList_ClearList( file.switchKit )
	Hud_DialogList_AddListItem( file.switchKit, Localize( "#LAB_KIT_WHITE" ), "white" )
	Hud_DialogList_AddListItem( file.switchKit, Localize( "#LAB_KIT_BLUE" ), "blue" )
	Hud_DialogList_AddListItem( file.switchKit, Localize( "#LAB_KIT_PURPLE" ), "purple" )
	Hud_DialogList_AddListItem( file.switchKit, Localize( "#LAB_KIT_GOLD" ), "gold" )
	Hud_SetDialogListSelectionValue( file.switchKit, file.kitTier )
}

void function LabArmory_BuildDeliverList()
{
	Hud_DialogList_ClearList( file.switchDeliver )
	Hud_DialogList_AddListItem( file.switchDeliver, Localize( "#LAB_ARMORY_DELIVER_SLOT1" ), "0" )
	Hud_DialogList_AddListItem( file.switchDeliver, Localize( "#LAB_ARMORY_DELIVER_SLOT2" ), "1" )
	Hud_DialogList_AddListItem( file.switchDeliver, Localize( "#LAB_ARMORY_DELIVER_GROUND" ), "2" )
	Hud_SetDialogListSelectionValue( file.switchDeliver, "0" )
}

// Client -> UI: the loot categories this build actually has, plus our weapons entry.
void function LabArmory_SetCategories( string keysCsv, string labelsCsv )
{
	array<string> keys = split( keysCsv, "," )
	array<string> labels = split( labelsCsv, "," )

	file.categoryKeys.clear()
	file.categoryLabels.clear()

	file.categoryKeys.append( LAB_CAT_WEAPONS )
	file.categoryLabels.append( Localize( "#LAB_ARMORY_WEAPONS" ) )

	for ( int i = 0; i < keys.len(); i++ )
	{
		if ( keys[i] == "" )
			continue
		file.categoryKeys.append( keys[i] )
		file.categoryLabels.append( i < labels.len() ? labels[i] : keys[i] )
	}

	file.applyingValues = true
	Hud_DialogList_ClearList( file.switchCategory )
	for ( int i = 0; i < file.categoryKeys.len(); i++ )
		Hud_DialogList_AddListItem( file.switchCategory, file.categoryLabels[i], file.categoryKeys[i] )
	file.applyingValues = false

	file.categoriesReady = true

	string want = file.pendingCategory != "" ? file.pendingCategory : LAB_CAT_WEAPONS
	file.pendingCategory = ""
	LabArmory_SelectCategory( want )
}

void function LabArmory_SelectCategory( string categoryKey )
{
	if ( !file.categoriesReady )
	{
		file.pendingCategory = categoryKey
		return
	}

	if ( !file.categoryKeys.contains( categoryKey ) )
		categoryKey = LAB_CAT_WEAPONS

	file.applyingValues = true
	Hud_SetDialogListSelectionValue( file.switchCategory, categoryKey )
	file.applyingValues = false

	LabArmory_LoadCategory( categoryKey )
}

void function LabArmory_LoadCategory( string categoryKey )
{
	file.activeCategory = categoryKey

	if ( categoryKey == LAB_CAT_WEAPONS )
	{
		LabArmory_BuildWeaponCatalog()
		return
	}

	RunClientScript( "Lab_RequestCatalog", categoryKey )
}

// Weapons come from the registry's own category list, in its own order.
void function LabArmory_BuildWeaponCatalog()
{
	file.items.clear()

	array cats = FreeroamWeaponsMenu_GetCategoryWeapons()
	foreach ( catAny in cats )
	{
		table cat = expect table( catAny )
		array weapons = expect array( cat.weapons )
		foreach ( rowAny in weapons )
		{
			table row = expect table( rowAny )
			LabItem item
			item.ref = string( row.classname )
			item.display = string( row.display )
			item.tier = 0
			item.isWeapon = true
			item.isAkimbo = ( "akimbo" in row )
			file.items.append( item )
		}
	}

	LabArmory_RenderPage()
}

void function LabArmory_CatalogBegin( string categoryKey )
{
	file.building.clear()
}

void function LabArmory_CatalogRow( string ref, string display, int tier )
{
	LabItem item
	item.ref = ref
	item.display = display
	item.tier = tier
	item.isWeapon = false
	file.building.append( item )
}

void function LabArmory_CatalogEnd( string categoryKey )
{
	if ( categoryKey != file.activeCategory )
		return

	file.items = clone file.building
	file.building.clear()
	LabArmory_RenderPage()
}

int function LabArmory_ActiveCols()
{
	return ( file.activeCategory == LAB_CAT_WEAPONS ) ? LAB_WEAPON_COLS : LAB_TILE_COLS
}

// Tiles are laid out on an 11-wide grid; a narrower category leaves the
// trailing columns hidden so the visible tiles still read row by row.
int function LabArmory_ItemIndexForTileIndex( int tileIdx )
{
	int cols = LabArmory_ActiveCols()
	int row = tileIdx / LAB_TILE_COLS
	int col = tileIdx % LAB_TILE_COLS
	if ( col >= cols )
		return -1
	return row * cols + col
}

void function LabArmory_RenderPage()
{
	int shown = 0

	for ( int i = 0; i < file.tiles.len(); i++ )
	{
		var tile = file.tiles[i]
		int itemIdx = LabArmory_ItemIndexForTileIndex( i )

		if ( itemIdx < 0 || itemIdx >= file.items.len() )
		{
			Hud_Hide( tile )
			Hud_SetEnabled( tile, false )
			continue
		}

		LabItem item = file.items[ itemIdx ]

		Hud_Show( tile )
		Hud_SetEnabled( tile, Lab_GetCheats() )
		if ( item.isWeapon )
			Hud_SetSize( tile, ContentScaledX( LAB_WEAPON_TILE_W ), ContentScaledY( LAB_WEAPON_TILE_H ) )
		else
			Hud_SetSize( tile, ContentScaledX( LAB_TILE_W ), ContentScaledY( LAB_TILE_H ) )

		ToolTipData toolTipData
		toolTipData.titleText = item.display
		toolTipData.descText = LabArmory_ActionDescription( item )
		Hud_SetToolTipData( tile, toolTipData )

		RunClientScript( "Lab_SetTileIcon", tile, item.isWeapon ? "weapon" : "loot", item.ref, item.tier )
		shown++
	}

	LabArmory_ApplyNav( shown )

	bool weapons = ( file.activeCategory == LAB_CAT_WEAPONS )
	Hud_SetEnabled( file.switchKit, weapons && Lab_GetCheats() )
	Hud_SetEnabled( file.switchDeliver, weapons && Lab_GetCheats() )
	if ( !weapons )
	{
		file.applyingValues = true
		Hud_SetDialogListSelectionValue( file.switchDeliver, "2" )
		file.applyingValues = false
		file.deliverSlot = 2
	}

	Lab_SetDetails( LabArmory_ActiveCategoryLabel(),
		format( Localize( "#LAB_ARMORY_COUNT_FMT" ), file.items.len() ) )

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

// Hidden tiles must not swallow focus, so the last filled row closes the chain.
void function LabArmory_ApplyNav( int shown )
{
	if ( shown <= 0 )
		return

	int cols = LabArmory_ActiveCols()
	int lastRow = ( shown - 1 ) / cols

	for ( int i = 0; i < shown; i++ )
	{
		int row = i / cols
		int col = i % cols
		var tile = file.tiles[ row * LAB_TILE_COLS + col ]

		int down = i + cols
		if ( down < shown )
			Hud_SetNavDown( tile, file.tiles[ ( row + 1 ) * LAB_TILE_COLS + col ] )
		else if ( row < lastRow )
			Hud_SetNavDown( tile, file.tiles[ lastRow * LAB_TILE_COLS + ( shown - 1 ) % cols ] )
		else
			Hud_SetNavDown( tile, file.switchCategory )

		if ( col < cols - 1 && i + 1 < shown )
			Hud_SetNavRight( tile, file.tiles[ row * LAB_TILE_COLS + col + 1 ] )
	}
}

string function LabArmory_ActiveCategoryLabel()
{
	int idx = file.categoryKeys.find( file.activeCategory )
	if ( idx < 0 || idx >= file.categoryLabels.len() )
		return Localize( "#LAB_TAB_ARMORY" )
	return file.categoryLabels[ idx ]
}

string function LabArmory_ActionDescription( LabItem item )
{
	if ( item.isWeapon && file.deliverSlot < 2 )
		return format( Localize( "#LAB_ARMORY_GIVE_FMT" ), file.kitTier, file.deliverSlot + 1 )

	return Localize( "#LAB_ARMORY_GROUND_DESC" )
}

void function LabArmory_OnTileFocus( var tile )
{
	int idx = LabArmory_ItemIndexForTile( tile )
	if ( idx < 0 )
		return

	LabItem item = file.items[ idx ]
	Lab_SetDetails( item.display, LabArmory_ActionDescription( item ) )
}

int function LabArmory_ItemIndexForTile( var tile )
{
	if ( !( tile in file.tileIndex ) )
		return -1

	int idx = LabArmory_ItemIndexForTileIndex( file.tileIndex[ tile ] )
	if ( idx < 0 || idx >= file.items.len() )
		return -1

	return idx
}

void function LabArmory_OnTileClick( var tile )
{
	if ( !Lab_GetCheats() )
		return

	int idx = LabArmory_ItemIndexForTile( tile )
	if ( idx < 0 )
		return

	LabItem item = file.items[ idx ]

	if ( item.isWeapon && file.deliverSlot < 2 )
	{
		string mode = item.isAkimbo ? "akimbo" : "kit"
		ClientCommand( format( "CC_MenuGiveAimTrainerWeapon %s %d %s %s", mode, file.deliverSlot, item.ref, file.kitTier ) )
		return
	}

	ClientCommand( format( "lab_spawn %s", item.ref ) )
}

void function LabArmory_OnCategoryChanged( var button )
{
	if ( file.applyingValues )
		return

	string key = Hud_GetDialogListSelectionValue( button )
	if ( key == file.activeCategory )
		return

	LabArmory_LoadCategory( key )
}

void function LabArmory_OnKitChanged( var button )
{
	if ( file.applyingValues )
		return

	file.kitTier = Hud_GetDialogListSelectionValue( button )
	LabArmory_RenderPage()
}

void function LabArmory_OnDeliverChanged( var button )
{
	if ( file.applyingValues )
		return

	file.deliverSlot = int( Hud_GetDialogListSelectionValue( button ) )
	LabArmory_RenderPage()
}

void function LabArmory_OnRefill( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "CC_MenuGiveAimTrainerWeapon refill" )
}

void function LabArmory_OnStrip( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "CC_MenuGiveAimTrainerWeapon strip 0" )
	ClientCommand( "CC_MenuGiveAimTrainerWeapon strip 1" )
}

void function LabArmory_ApplyGates()
{
	if ( file.tiles.len() == 0 )
		return

	bool cheats = Lab_GetCheats()
	bool weapons = ( file.activeCategory == LAB_CAT_WEAPONS )

	Hud_SetEnabled( file.switchCategory, cheats )
	Hud_SetEnabled( file.switchKit, cheats && weapons )
	Hud_SetEnabled( file.switchDeliver, cheats && weapons )
	Hud_SetEnabled( file.buttonRefill, cheats )
	Hud_SetEnabled( file.buttonStrip, cheats )

	foreach ( var tile in file.tiles )
	{
		if ( Hud_IsVisible( tile ) )
			Hud_SetEnabled( tile, cheats )
	}

	if ( !cheats )
		Lab_SetDetails( Localize( "#LAB_ARMORY_CHEATS_TITLE" ), Localize( "#LAB_ARMORY_CHEATS_DESC" ) )
}
