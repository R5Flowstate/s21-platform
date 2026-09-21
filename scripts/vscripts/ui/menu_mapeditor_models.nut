// Map editor model browser: category list + scrollable model list, mouse cursor.

global function InitMapEditorModelMenu
global function OpenMapEditorModelMenu
global function UI_MapEditor_SetActivePackMask

struct
{
	var menu
	var categoryList
	var modelList
	var titleLabel

	string activeTier = "build"
	string selectedCategory = ""

	array< string > categoryRows
	array< MapEditorCatalogEntry > modelEntries

	table< var, int > categoryButtonToIndex
	table< var, bool > categoryHandlerBound
	table< var, int > modelButtonToIndex
	table< var, bool > modelHandlerBound
} fileVM


void function InitMapEditorModelMenu( var menu )
{
	fileVM.menu = menu

	if ( Hud_HasChild( menu, "CategoryList" ) )
		fileVM.categoryList = Hud_GetChild( menu, "CategoryList" )
	else
		printt( "[MAPEDIT-UI] CategoryList missing from menu layout" )

	if ( Hud_HasChild( menu, "ModelList" ) )
		fileVM.modelList = Hud_GetChild( menu, "ModelList" )
	else
		printt( "[MAPEDIT-UI] ModelList missing from menu layout" )

	if ( Hud_HasChild( menu, "TitleLabel" ) )
		fileVM.titleLabel = Hud_GetChild( menu, "TitleLabel" )
	else
		printt( "[MAPEDIT-UI] TitleLabel missing from menu layout" )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, MapEditorModelMenu_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, MapEditorModelMenu_OnClose )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, MapEditorModelMenu_OnNavBack )

	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CLOSE", "#B_BUTTON_CLOSE" )
}


void function OpenMapEditorModelMenu()
{
	CloseAllMenus()
	AdvanceMenu( fileVM.menu )
}


void function UI_MapEditor_SetActivePackMask( int mask )
{
	MapEditorCatalog_Init()
	MapEditorCatalog_SetActivePackMask( mask )
}


void function MapEditorModelMenu_OnOpen()
{
	SetBlurEnabled( true )
	MapEditorCatalog_Init()

	fileVM.activeTier = "build"
	fileVM.selectedCategory = ""
	MapEditorModelMenu_PopulateCategories()
}


void function MapEditorModelMenu_OnClose()
{
	SetBlurEnabled( false )
}


void function MapEditorModelMenu_OnNavBack()
{
	CloseActiveMenu()
}


void function MapEditorModelMenu_PopulateCategories()
{
	if ( fileVM.categoryList == null )
	{
		printt( "[MAPEDIT-UI] PopulateCategories: CategoryList is null" )
		return
	}

	// UI VM has no GetMapName; GetActiveLevel is the existing UI map string.
	string mapName = GetActiveLevel()

	array< string > cats = MapEditorCatalog_GetCategoriesByTier( fileVM.activeTier )
	fileVM.categoryRows = []
	foreach ( string cat in cats )
	{
		array< MapEditorCatalogEntry > available = MapEditorCatalog_GetAvailableCategoryEntries( cat, mapName )
		if ( available.len() > 0 )
			fileVM.categoryRows.append( cat )
	}

	// Sentinel rows switch tier; Extra is build-only, Build returns from extra.
	if ( fileVM.activeTier == "build" )
		fileVM.categoryRows.append( "__extra__" )
	else
		fileVM.categoryRows.append( "__build__" )

	if ( !Hud_HasChild( fileVM.categoryList, "ScrollPanel" ) )
	{
		printt( "[MAPEDIT-UI] CategoryList has no ScrollPanel" )
		return
	}

	var scrollPanel = Hud_GetChild( fileVM.categoryList, "ScrollPanel" )
	Hud_InitGridButtons( fileVM.categoryList, fileVM.categoryRows.len() )
	fileVM.categoryButtonToIndex = {}

	foreach ( int idx, string catKey in fileVM.categoryRows )
	{
		if ( !Hud_HasChild( scrollPanel, "GridButton" + idx ) )
			break

		var button = Hud_GetChild( scrollPanel, "GridButton" + idx )

		string label = catKey
		if ( catKey == "__extra__" )
			label = "Extra"
		else if ( catKey == "__build__" )
			label = "Build"

		RuiSetString( Hud_GetRui( button ), "buttonText", label )
		Hud_SetEnabled( button, true )

		if ( !( button in fileVM.categoryHandlerBound ) )
		{
			Hud_AddEventHandler( button, UIE_CLICK, MapEditorModelMenu_OnCategoryClick )
			fileVM.categoryHandlerBound[button] <- true
		}
		fileVM.categoryButtonToIndex[button] <- idx
	}

	string firstCat = ""
	foreach ( string catKey in fileVM.categoryRows )
	{
		if ( catKey != "__extra__" && catKey != "__build__" )
		{
			firstCat = catKey
			break
		}
	}

	if ( firstCat == "" )
	{
		printt( format( "[MAPEDIT-UI] no available categories for tier %s on map %s",
			fileVM.activeTier, mapName ) )
		fileVM.selectedCategory = ""
		fileVM.modelEntries = []
		MapEditorModelMenu_PopulateModels()
		return
	}

	fileVM.selectedCategory = firstCat
	MapEditorModelMenu_PopulateModels()
}


void function MapEditorModelMenu_PopulateModels()
{
	if ( fileVM.modelList == null )
	{
		printt( "[MAPEDIT-UI] PopulateModels: ModelList is null" )
		return
	}

	string mapName = GetActiveLevel()

	fileVM.modelEntries = []
	if ( fileVM.selectedCategory != "" )
	{
		array< MapEditorCatalogEntry > entries = MapEditorCatalog_GetAvailableCategoryEntries( fileVM.selectedCategory, mapName )
		fileVM.modelEntries = entries
	}

	if ( !Hud_HasChild( fileVM.modelList, "ScrollPanel" ) )
	{
		printt( "[MAPEDIT-UI] ModelList has no ScrollPanel" )
		return
	}

	var scrollPanel = Hud_GetChild( fileVM.modelList, "ScrollPanel" )
	Hud_InitGridButtons( fileVM.modelList, fileVM.modelEntries.len() )
	fileVM.modelButtonToIndex = {}

	foreach ( int idx, MapEditorCatalogEntry entry in fileVM.modelEntries )
	{
		if ( !Hud_HasChild( scrollPanel, "GridButton" + idx ) )
			break

		var button = Hud_GetChild( scrollPanel, "GridButton" + idx )
		RuiSetString( Hud_GetRui( button ), "buttonText", MapEditorModelMenu_ModelStem( entry.model ) )
		Hud_SetEnabled( button, true )

		if ( !( button in fileVM.modelHandlerBound ) )
		{
			Hud_AddEventHandler( button, UIE_CLICK, MapEditorModelMenu_OnModelClick )
			Hud_AddEventHandler( button, UIE_GET_FOCUS, MapEditorModelMenu_OnModelFocus )
			fileVM.modelHandlerBound[button] <- true
		}
		fileVM.modelButtonToIndex[button] <- idx
	}

	MapEditorModelMenu_UpdateTitle( "" )
}


void function MapEditorModelMenu_OnCategoryClick( var button )
{
	if ( !( button in fileVM.categoryButtonToIndex ) )
		return

	int idx = fileVM.categoryButtonToIndex[button]
	if ( idx < 0 || idx >= fileVM.categoryRows.len() )
	{
		printt( "[MAPEDIT-UI] category click index out of range" )
		return
	}

	string catKey = fileVM.categoryRows[idx]
	if ( catKey == "__extra__" )
	{
		fileVM.activeTier = "extra"
		fileVM.selectedCategory = ""
		MapEditorModelMenu_PopulateCategories()
		return
	}
	if ( catKey == "__build__" )
	{
		fileVM.activeTier = "build"
		fileVM.selectedCategory = ""
		MapEditorModelMenu_PopulateCategories()
		return
	}

	fileVM.selectedCategory = catKey
	MapEditorModelMenu_PopulateModels()
}


void function MapEditorModelMenu_OnModelClick( var button )
{
	if ( !( button in fileVM.modelButtonToIndex ) )
		return

	int idx = fileVM.modelButtonToIndex[button]
	if ( idx < 0 || idx >= fileVM.modelEntries.len() )
	{
		printt( "[MAPEDIT-UI] model click index out of range" )
		return
	}

	int catalogId = fileVM.modelEntries[idx].id
	RunClientScript( "UIToClient_MapEditor_SetModel", catalogId )
	CloseActiveMenu()
}


void function MapEditorModelMenu_OnModelFocus( var button )
{
	if ( !( button in fileVM.modelButtonToIndex ) )
		return

	int idx = fileVM.modelButtonToIndex[button]
	if ( idx < 0 || idx >= fileVM.modelEntries.len() )
		return

	MapEditorModelMenu_UpdateTitle( string( fileVM.modelEntries[idx].model ) )
}


void function MapEditorModelMenu_UpdateTitle( string focusPath )
{
	if ( fileVM.titleLabel == null )
		return

	string text = fileVM.selectedCategory
	if ( text == "" )
		text = "Models"
	// Count is map-filtered (available only).
	text += "  (" + string( fileVM.modelEntries.len() ) + " available)"
	if ( focusPath != "" )
		text += "  " + focusPath

	Hud_SetText( fileVM.titleLabel, text )
}


string function MapEditorModelMenu_ModelStem( asset model )
{
	string path = string( model )
	array< string > parts = split( path, "/" )
	string stem = path
	if ( parts.len() > 0 )
		stem = parts[parts.len() - 1]

	if ( stem.len() >= 5 )
	{
		string ext = stem.slice( stem.len() - 5, stem.len() )
		if ( ext == ".rmdl" )
			stem = stem.slice( 0, stem.len() - 5 )
	}

	return stem
}
