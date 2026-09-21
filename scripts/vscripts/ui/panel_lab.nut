// Lab: the player-facing home for every developer tool, as a tab of the
// inventory menu. This file owns the sub-tabs, the shared details pane and the
// two gates every sub-panel reads (cheats, host seat).

global function InitLabPanel

global function Lab_SetState
global function Lab_GetCheats
global function Lab_IsHostSeat
global function Lab_RefreshState
global function Lab_AddGateListener
global function Lab_SetDetails
global function Lab_SetRowState
global function Lab_SetupRow

struct
{
	var panel
	var details

	bool cheats = false
	bool hostSeat = false
	bool stateEverReceived = false
	int activeTabIndex = 0

	array<void functionref()> gateListeners
} file

void function InitLabPanel( var panel )
{
	file.panel = panel
	file.details = Hud_GetChild( panel, "DetailsPanel" )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabPanel_Hide )

	{
		TabDef tabDef = AddTab( panel, Hud_GetChild( panel, "LabPlayerPanel" ), "#LAB_TAB_PLAYER" )
		SetTabBaseWidth( tabDef, 170 )
	}
	{
		TabDef tabDef = AddTab( panel, Hud_GetChild( panel, "LabArmoryPanel" ), "#LAB_TAB_ARMORY" )
		SetTabBaseWidth( tabDef, 170 )
	}
	{
		TabDef tabDef = AddTab( panel, Hud_GetChild( panel, "LabTargetsPanel" ), "#LAB_TAB_TARGETS" )
		SetTabBaseWidth( tabDef, 170 )
	}
	{
		TabDef tabDef = AddTab( panel, Hud_GetChild( panel, "LabRecorderPanel" ), "#LAB_TAB_RECORDER" )
		SetTabBaseWidth( tabDef, 170 )
		tabDef.new = true
	}
	{
		TabDef tabDef = AddTab( panel, Hud_GetChild( panel, "LabMatchPanel" ), "#LAB_TAB_MATCH" )
		SetTabBaseWidth( tabDef, 170 )
	}
	{
		TabDef tabDef = AddTab( panel, Hud_GetChild( panel, "LabModsPanel" ), "#LAB_TAB_MODS" )
		SetTabBaseWidth( tabDef, 170 )
	}

	TabData tabData = GetTabDataForPanel( panel )
	tabData.centerTabs = true
	SetTabDefsToSeasonal( tabData )
	SetTabBackground( tabData, Hud_GetChild( panel, "TabsBackground" ), eTabBackground.STANDARD )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )
	AddPanelFooterOption( panel, RIGHT, BUTTON_START, true, "#HINT_SYSTEM_MENU_GAMEPAD", "#HINT_SYSTEM_MENU_KB", Lab_TryOpenSystemMenu )
}

void function OnLabPanel_Show( var panel )
{
	DevHud_Apply()
	Lab_RefreshState()

	TabData tabData = GetTabDataForPanel( panel )
	DeactivateTab( tabData )
	SetTabNavigationEnabled( panel, false )
	SetTabNavigationEnabled( panel, true )

	ActivateTab( tabData, file.activeTabIndex )
}

void function OnLabPanel_Hide( var panel )
{
	TabData tabData = GetTabDataForPanel( panel )
	file.activeTabIndex = tabData.activeTabIdx
	DeactivateTab( tabData )
	DevHud_Apply()
}

void function Lab_TryOpenSystemMenu( var panel )
{
	if ( InputIsButtonDown( BUTTON_START ) )
		return

	OpenSystemMenu()
}

// Asks the client for sv_cheats and whether we hold the first player slot.
void function Lab_RefreshState()
{
	RunClientScript( "DEV_SendDevMenuStateToUI" )
}

void function Lab_AddGateListener( void functionref() listener )
{
	file.gateListeners.append( listener )
}

// Client -> UI. Both gates arrive together so a sub-panel only rebuilds once.
void function Lab_SetState( bool cheats, bool hostSeat )
{
	bool changed = ( !file.stateEverReceived || file.cheats != cheats || file.hostSeat != hostSeat )
	file.cheats = cheats
	file.hostSeat = hostSeat
	file.stateEverReceived = true

	if ( !changed )
		return

	foreach ( void functionref() listener in file.gateListeners )
		listener()
}

bool function Lab_GetCheats()
{
	return file.cheats
}

bool function Lab_IsHostSeat()
{
	return file.hostSeat
}

void function Lab_SetDetails( string title, string desc )
{
	if ( file.details == null )
		return

	var rui = Hud_GetRui( file.details )
	RuiSetArg( rui, "headerText", "" )
	RuiSetArg( rui, "selectionText", title )
	RuiSetArg( rui, "descText", desc )
	RuiSetArg( rui, "noteText", "" )
}

// Shared row wiring: label, tooltip and the details pane all come from one call.
// hostOnly drives the settings marker retail uses for leader-only rows.
void function Lab_SetupRow( var button, string name, string desc, bool hostOnly = false )
{
	SetupSettingsButton( button, name, desc, $"", false, hostOnly )
}

// A row is live only when cheats are on, and host-only rows also need the seat.
void function Lab_SetRowState( var button, bool hostOnly = false )
{
	bool live = Lab_GetCheats() && ( !hostOnly || Lab_IsHostSeat() )
	Hud_SetEnabled( button, live )
}


