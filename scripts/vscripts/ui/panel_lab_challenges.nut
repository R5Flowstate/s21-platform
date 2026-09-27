// Lab > Challenges. Timed aim runs; each mode action starts its own run.

global function InitLabChallengesPanel
global function LabChallenges_SetState

struct
{
	var panel
	var contentPanelParent
	var contentPanel
	var scrollBar
	var scrollFrame

	table< string, var > rows

	bool applyingValues = false

	// Order is the server's challenge mode index.
	array<string> modes = [ "ts", "popcorn", "strafer_challenge", "manual_challenge" ]
} file

void function InitLabChallengesPanel( var panel )
{
	file.panel = panel

	file.contentPanelParent = Hud_GetChild( panel, "ModeOptionsPanel" )
	file.contentPanel = Hud_GetChild( file.contentPanelParent, "ContentPanel" )
	file.scrollBar = Hud_GetChild( file.contentPanelParent, "ScrollBar" )
	file.scrollFrame = Hud_GetChild( file.contentPanelParent, "ScrollFrame" )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabChallengesPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabChallengesPanel_Hide )

	LabChallenges_BindRows()

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_InitPanel( file.contentPanelParent )
	ScrollPanel_InitScrollBar( file.contentPanelParent, file.scrollBar )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	Lab_AddGateListener( LabChallenges_ApplyGates )
}

var function LabChallenges_Row( string name )
{
	return file.rows[ name ]
}

void function LabChallenges_BindRows()
{
	foreach ( string name in [ "SwitchAimMode", "SwitchDuration", "ButtonChallengeStart", "ButtonChallengeStop" ] )
		file.rows[ name ] <- Hud_GetChild( file.contentPanel, name )

	Lab_SetupRow( LabChallenges_Row( "SwitchAimMode" ), "#LAB_TARGETS_AIMMODE",
		"#LAB_TARGETS_AIMMODE_DESC", true )
	Lab_SetupRow( LabChallenges_Row( "SwitchDuration" ), "#LAB_TARGETS_DURATION",
		"#LAB_TARGETS_DURATION_DESC", true )
	Lab_SetupRow( LabChallenges_Row( "ButtonChallengeStart" ), "#LAB_TARGETS_CHALSTART",
		"#LAB_TARGETS_CHALSTART_DESC" )
	Lab_SetupRow( LabChallenges_Row( "ButtonChallengeStop" ), "#LAB_TARGETS_CHALSTOP",
		"#LAB_TARGETS_CHALSTOP_DESC" )

	var modes = LabChallenges_Row( "SwitchAimMode" )
	Hud_DialogList_ClearList( modes )
	Hud_DialogList_AddListItem( modes, Localize( "#LAB_TARGETS_MODE_TS" ), "0" )
	Hud_DialogList_AddListItem( modes, Localize( "#LAB_TARGETS_MODE_POPCORN" ), "1" )
	Hud_DialogList_AddListItem( modes, Localize( "#LAB_TARGETS_MODE_STRAFER" ), "2" )
	Hud_DialogList_AddListItem( modes, Localize( "#LAB_TARGETS_MODE_MANUAL" ), "3" )
	Hud_SetDialogListSelectionValue( modes, "0" )

	var duration = LabChallenges_Row( "SwitchDuration" )
	Hud_DialogList_ClearList( duration )
	Hud_DialogList_AddListItem( duration, Localize( "#LAB_TARGETS_DUR_30" ), "30" )
	Hud_DialogList_AddListItem( duration, Localize( "#LAB_TARGETS_DUR_60" ), "60" )
	Hud_DialogList_AddListItem( duration, Localize( "#LAB_TARGETS_DUR_90" ), "90" )
	Hud_DialogList_AddListItem( duration, Localize( "#LAB_TARGETS_DUR_120" ), "120" )
	Hud_DialogList_AddListItem( duration, Localize( "#LAB_TARGETS_DUR_INF" ), "999" )
	Hud_SetDialogListSelectionValue( duration, "60" )

	AddButtonEventHandler( LabChallenges_Row( "SwitchAimMode" ), UIE_CHANGE, LabChallenges_OnMode )
	AddButtonEventHandler( LabChallenges_Row( "SwitchDuration" ), UIE_CHANGE, LabChallenges_OnDuration )
	AddButtonEventHandler( LabChallenges_Row( "ButtonChallengeStart" ), UIE_CLICK, LabChallenges_ClickStart )
	AddButtonEventHandler( LabChallenges_Row( "ButtonChallengeStop" ), UIE_CLICK, LabChallenges_ClickStop )
}

void function OnLabChallengesPanel_Show( var panel )
{
	ClientCommand( "dev_aimtrainer sync" )
	LabChallenges_ApplyGates()

	ScrollPanel_SetActive( file.contentPanelParent, true )
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

void function OnLabChallengesPanel_Hide( var panel )
{
	ScrollPanel_SetActive( file.contentPanelParent, false )
}

// Server -> UI through the Targets sync; durationSec <= 0 leaves the pick alone.
void function LabChallenges_SetState( int durationSec, int mode = -1 )
{
	if ( file.rows.len() == 0 )
		return

	file.applyingValues = true
	if ( durationSec > 0 )
		Hud_SetDialogListSelectionValue( LabChallenges_Row( "SwitchDuration" ), string( durationSec ) )
	if ( mode >= 0 && mode < file.modes.len() )
		Hud_SetDialogListSelectionValue( LabChallenges_Row( "SwitchAimMode" ), string( mode ) )
	file.applyingValues = false
}

void function LabChallenges_ApplyGates()
{
	if ( file.rows.len() == 0 )
		return

	Lab_SetRowState( LabChallenges_Row( "SwitchAimMode" ), true )
	Lab_SetRowState( LabChallenges_Row( "SwitchDuration" ), true )
	Lab_SetRowState( LabChallenges_Row( "ButtonChallengeStart" ) )
	Lab_SetRowState( LabChallenges_Row( "ButtonChallengeStop" ) )
}

bool function LabChallenges_Ignore()
{
	return file.applyingValues || !Lab_GetCheats()
}

void function LabChallenges_OnMode( var button )
{
	if ( LabChallenges_Ignore() )
		return
	ClientCommand( "dev_aimtrainer chal_mode " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabChallenges_OnDuration( var button )
{
	if ( LabChallenges_Ignore() )
		return
	ClientCommand( "dev_aimtrainer duration " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabChallenges_ClickStart( var button )
{
	if ( !Lab_GetCheats() )
		return

	int mode = int( Hud_GetDialogListSelectionValue( LabChallenges_Row( "SwitchAimMode" ) ) )
	if ( mode < 0 || mode >= file.modes.len() )
		return
	ClientCommand( "dev_aimtrainer " + file.modes[ mode ] )
	CloseAllMenus()
}

void function LabChallenges_ClickStop( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "dev_aimtrainer stop" )
}
