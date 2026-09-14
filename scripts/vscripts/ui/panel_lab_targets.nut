// Lab > Targets. Practice dummies and the aim challenge.
// Everything routes through dev_aimtrainer, which binds to the caller.

global function InitLabTargetsPanel
global function LabTargets_SetState

struct
{
	var panel
	var contentPanelParent
	var contentPanel
	var scrollBar
	var scrollFrame

	table< string, var > rows

	float lastSpeedSent = 1.0
	bool lastGodSent = false

	bool applyingValues = false
} file

void function InitLabTargetsPanel( var panel )
{
	file.panel = panel

	file.contentPanelParent = Hud_GetChild( panel, "ModeOptionsPanel" )
	file.contentPanel = Hud_GetChild( file.contentPanelParent, "ContentPanel" )
	file.scrollBar = Hud_GetChild( file.contentPanelParent, "ScrollBar" )
	file.scrollFrame = Hud_GetChild( file.contentPanelParent, "ScrollFrame" )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabTargetsPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabTargetsPanel_Hide )

	LabTargets_BindRows()

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_InitPanel( file.contentPanelParent )
	ScrollPanel_InitScrollBar( file.contentPanelParent, file.scrollBar )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	Lab_AddGateListener( LabTargets_ApplyGates )
}

var function LabTargets_Row( string name )
{
	return file.rows[ name ]
}

void function LabTargets_BindRows()
{
	array<string> names = [
		"ButtonDummy", "ButtonSandbag", "ButtonStrafer", "ButtonStraferFast",
		"ButtonFakePlayer", "ButtonFakeEnemy",
		"SldStrafeSpeed", "SwitchBotHealth",
		"SwitchAimMode", "SwitchDuration", "ButtonChallengeStart", "ButtonChallengeStop",
		"SwitchReloadKill", "SwitchReloadHit", "SwitchReloadShot",
		"SwitchDynStats", "SwitchReconBars", "ButtonQuitAimTrainer"
	]

	foreach ( string name in names )
		file.rows[ name ] <- Hud_GetChild( file.contentPanel, name )

	Lab_SetupRow( LabTargets_Row( "ButtonDummy" ), "#LAB_TARGETS_DUMMY",
		"#LAB_TARGETS_DUMMY_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonSandbag" ), "#LAB_TARGETS_SANDBAG",
		"#LAB_TARGETS_SANDBAG_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonStrafer" ), "#LAB_TARGETS_STRAFER",
		"#LAB_TARGETS_STRAFER_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonStraferFast" ), "#LAB_TARGETS_STRAFERFAST",
		"#LAB_TARGETS_STRAFERFAST_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonFakePlayer" ), "#LAB_TARGETS_FAKEPLAYER",
		"#LAB_TARGETS_FAKEPLAYER_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonFakeEnemy" ), "#LAB_TARGETS_FAKEENEMY",
		"#LAB_TARGETS_FAKEENEMY_DESC" )
	LabTargets_SetupSlider( LabTargets_Row( "SldStrafeSpeed" ), "#LAB_TARGETS_STRAFESPEED" )
	Lab_SetupRow( LabTargets_Row( "SwitchBotHealth" ), "#LAB_TARGETS_BOTHEALTH",
		"#LAB_TARGETS_BOTHEALTH_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchAimMode" ), "#LAB_TARGETS_AIMMODE",
		"#LAB_TARGETS_AIMMODE_DESC", true )
	Lab_SetupRow( LabTargets_Row( "SwitchDuration" ), "#LAB_TARGETS_DURATION",
		"#LAB_TARGETS_DURATION_DESC", true )
	Lab_SetupRow( LabTargets_Row( "ButtonChallengeStart" ), "#LAB_TARGETS_CHALSTART",
		"#LAB_TARGETS_CHALSTART_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonChallengeStop" ), "#LAB_TARGETS_CHALSTOP",
		"#LAB_TARGETS_CHALSTOP_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchReloadKill" ), "#LAB_TARGETS_RELOADKILL",
		"#LAB_TARGETS_RELOADKILL_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchReloadHit" ), "#LAB_TARGETS_RELOADHIT",
		"#LAB_TARGETS_RELOADHIT_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchReloadShot" ), "#LAB_TARGETS_RELOADSHOT",
		"#LAB_TARGETS_RELOADSHOT_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchDynStats" ), "#LAB_TARGETS_DYNSTATS",
		"#LAB_TARGETS_DYNSTATS_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchReconBars" ), "#LAB_TARGETS_RECONBARS",
		"#LAB_TARGETS_RECONBARS_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonQuitAimTrainer" ), "#LAB_TARGETS_CLEAR",
		"#LAB_TARGETS_CLEAR_DESC" )

	LabTargets_BuildAimModeList()
	LabTargets_BuildDurationList()

	AddButtonEventHandler( LabTargets_Row( "ButtonDummy" ), UIE_CLICK, LabTargets_ClickDummy )
	AddButtonEventHandler( LabTargets_Row( "ButtonSandbag" ), UIE_CLICK, LabTargets_ClickSandbag )
	AddButtonEventHandler( LabTargets_Row( "ButtonStrafer" ), UIE_CLICK, LabTargets_ClickStrafer )
	AddButtonEventHandler( LabTargets_Row( "ButtonStraferFast" ), UIE_CLICK, LabTargets_ClickStraferFast )
	AddButtonEventHandler( LabTargets_Row( "ButtonFakePlayer" ), UIE_CLICK, LabTargets_ClickFakePlayer )
	AddButtonEventHandler( LabTargets_Row( "ButtonFakeEnemy" ), UIE_CLICK, LabTargets_ClickFakeEnemy )
	AddButtonEventHandler( LabTargets_Row( "ButtonChallengeStart" ), UIE_CLICK, LabTargets_ClickStart )
	AddButtonEventHandler( LabTargets_Row( "ButtonChallengeStop" ), UIE_CLICK, LabTargets_ClickStop )
	AddButtonEventHandler( LabTargets_Row( "ButtonQuitAimTrainer" ), UIE_CLICK, LabTargets_ClickQuit )

	AddButtonEventHandler( LabTargets_Row( "SldStrafeSpeed" ), UIE_CHANGE, LabTargets_OnStrafeSpeed )
	AddButtonEventHandler( LabTargets_Row( "SwitchBotHealth" ), UIE_CHANGE, LabTargets_OnBotHealth )
	AddButtonEventHandler( LabTargets_Row( "SwitchDuration" ), UIE_CHANGE, LabTargets_OnDuration )
	AddButtonEventHandler( LabTargets_Row( "SwitchReloadKill" ), UIE_CHANGE, LabTargets_OnReloadKill )
	AddButtonEventHandler( LabTargets_Row( "SwitchReloadHit" ), UIE_CHANGE, LabTargets_OnReloadHit )
	AddButtonEventHandler( LabTargets_Row( "SwitchReloadShot" ), UIE_CHANGE, LabTargets_OnReloadShot )
	AddButtonEventHandler( LabTargets_Row( "SwitchDynStats" ), UIE_CHANGE, LabTargets_OnDynStats )
	AddButtonEventHandler( LabTargets_Row( "SwitchReconBars" ), UIE_CHANGE, LabTargets_OnReconBars )
}

// Slider rows carry their own label/desc: a SliderControl has no SwitchButton
// RUI, so Lab_SetupRow (SetButtonRuiText on the row) does not apply. The title
// goes on the slider's BtnDropButton child; the details pane fills on focus.
void function LabTargets_SetupSlider( var slider, string title )
{
	if ( Hud_HasChild( slider, "BtnDropButton" ) )
		SetButtonRuiText( Hud_GetChild( slider, "BtnDropButton" ), title )
	Hud_AddEventHandler( slider, UIE_GET_FOCUS, LabTargets_SliderFocus )
}

void function LabTargets_SliderFocus( var slider )
{
	if ( slider == LabTargets_Row( "SldStrafeSpeed" ) )
		Lab_SetDetails( Localize( "#LAB_TARGETS_STRAFESPEED" ), Localize( "#LAB_TARGETS_STRAFESPEED_DESC" ) )
}

void function LabTargets_BuildAimModeList()
{
	var button = LabTargets_Row( "SwitchAimMode" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_MODE_TS" ), "ts" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_MODE_POPCORN" ), "popcorn" )
	Hud_SetDialogListSelectionValue( button, "ts" )
}

void function LabTargets_BuildDurationList()
{
	var button = LabTargets_Row( "SwitchDuration" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_DUR_30" ), "30" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_DUR_60" ), "60" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_DUR_90" ), "90" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_DUR_120" ), "120" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_DUR_INF" ), "999" )
	Hud_SetDialogListSelectionValue( button, "60" )
}

void function OnLabTargetsPanel_Show( var panel )
{
	ClientCommand( "dev_aimtrainer sync" )
	LabTargets_ApplyGates()

	ScrollPanel_SetActive( file.contentPanelParent, true )
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

void function OnLabTargetsPanel_Hide( var panel )
{
	ScrollPanel_SetActive( file.contentPanelParent, false )
}

// Server -> client -> UI: reconcile the toggle labels with server truth.
void function LabTargets_SetState( bool hit, bool shot, bool kill, bool dynStats, bool reconBars, int durationSec, bool straferGod, int strafeSpeedTenth )
{
	if ( file.rows.len() == 0 )
		return

	file.applyingValues = true
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchReloadKill" ), kill ? "1" : "0" )
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchReloadHit" ), hit ? "1" : "0" )
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchReloadShot" ), shot ? "1" : "0" )
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchDynStats" ), dynStats ? "1" : "0" )
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchReconBars" ), reconBars ? "1" : "0" )
	if ( durationSec > 0 )
		Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchDuration" ), string( durationSec ) )
	if ( strafeSpeedTenth >= 5 && strafeSpeedTenth <= 20 )
	{
		file.lastSpeedSent = float( strafeSpeedTenth ) / 10.0
		Hud_SliderControl_SetCurrentValue( LabTargets_Row( "SldStrafeSpeed" ), file.lastSpeedSent )
	}
	file.lastGodSent = straferGod
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchBotHealth" ), straferGod ? "1" : "0" )
	file.applyingValues = false
}

void function LabTargets_ApplyGates()
{
	if ( file.rows.len() == 0 )
		return

	foreach ( string name, var button in file.rows )
		Lab_SetRowState( button )
}

bool function LabTargets_Ignore()
{
	return file.applyingValues || !Lab_GetCheats()
}

void function LabTargets_Send( string action )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "dev_aimtrainer " + action )
}

void function LabTargets_ClickDummy( var button ) { LabTargets_Send( "dummy" ) }
void function LabTargets_ClickSandbag( var button ) { LabTargets_Send( "sandbag" ) }
void function LabTargets_ClickStrafer( var button ) { LabTargets_Send( "flowstate_auto" ) }
void function LabTargets_ClickStraferFast( var button ) { LabTargets_Send( "flowstate_hard_auto" ) }
void function LabTargets_ClickStop( var button ) { LabTargets_Send( "stop" ) }
void function LabTargets_ClickQuit( var button ) { LabTargets_Send( "quit" ) }

void function LabTargets_OnStrafeSpeed( var button )
{
	if ( LabTargets_Ignore() )
		return

	float speed = Hud_SliderControl_GetCurrentValue( button )
	if ( speed < 0.5 )
		speed = 0.5
	if ( speed > 2.0 )
		speed = 2.0
	if ( fabs( speed - file.lastSpeedSent ) < 0.049 )
		return
	file.lastSpeedSent = speed
	int tenth = int( speed * 10.0 + 0.5 )
	if ( tenth < 5 )
		tenth = 5
	if ( tenth > 20 )
		tenth = 20
	ClientCommand( format( "dev_aimtrainer strafe_speed %d", tenth ) )
}

void function LabTargets_OnBotHealth( var button )
{
	if ( LabTargets_Ignore() )
		return

	bool god = ( Hud_GetDialogListSelectionValue( button ) == "1" )
	if ( god == file.lastGodSent )
		return
	file.lastGodSent = god
	ClientCommand( format( "dev_aimtrainer bot_health %d", god ? 1 : 0 ) )
}

void function LabTargets_ClickFakePlayer( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "spawn_fake_player" )
}

void function LabTargets_ClickFakeEnemy( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "spawn_fake_player enemy" )
}

void function LabTargets_ClickStart( var button )
{
	if ( !Lab_GetCheats() )
		return

	string mode = Hud_GetDialogListSelectionValue( LabTargets_Row( "SwitchAimMode" ) )
	ClientCommand( "dev_aimtrainer " + mode )
	ClientCommand( "dev_aimtrainer start" )
	CloseAllMenus()
}

void function LabTargets_OnDuration( var button )
{
	if ( LabTargets_Ignore() )
		return

	int durationSec = int( Hud_GetDialogListSelectionValue( button ) )
	ClientCommand( format( "dev_aimtrainer duration %d", durationSec ) )
}

void function LabTargets_OnReloadKill( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer reload_kill" )
}

void function LabTargets_OnReloadHit( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer reload_hit" )
}

void function LabTargets_OnReloadShot( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer reload_shot" )
}

void function LabTargets_OnDynStats( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer dynstats" )
}

void function LabTargets_OnReconBars( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer healthbars" )
}
