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

	table< var, string > sliderTitles
	table< var, string > sliderDescs
	table< string, var > rows

	float lastSpeedSent = 1.0
	bool lastGodSent = false
	int lastAimSent = -1
	int lastStrafeTimeSent = -1

	bool applyingValues = false
	bool straferListsBuilt = false
	bool straferIsLegend = true
	int straferClass = -1
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
		"ButtonStrafer", "ButtonStraferFast",
		"SwitchStraferBody", "SwitchStraferClass", "SwitchStraferLegend",
		"SldStrafeSpeed", "SwitchBotHealth", "SwitchBotFire", "SldBotAim", "SwitchStrafeTimeMin", "SwitchStrafeTimeMax", "SwitchFixedSpawn", "ButtonSetSpawn", "SwitchDummyArmor",
		"SwitchAimMode", "SwitchDuration", "ButtonChallengeStart", "ButtonChallengeStop",
		"SwitchReloadKill", "SwitchReloadHit", "SwitchReloadShot",
		"SwitchDynStats", "SwitchReconBars", "SwitchHighlight", "ButtonQuitAimTrainer"
	]

	foreach ( string name in names )
		file.rows[ name ] <- Hud_GetChild( file.contentPanel, name )

	Lab_SetupRow( LabTargets_Row( "ButtonStrafer" ), "#LAB_TARGETS_STRAFER",
		"#LAB_TARGETS_STRAFER_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonStraferFast" ), "#LAB_TARGETS_STRAFERFAST",
		"#LAB_TARGETS_STRAFERFAST_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchStraferBody" ), "#LAB_TARGETS_STRAFERBODY",
		"#LAB_TARGETS_STRAFERBODY_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchStraferClass" ), "#LAB_TARGETS_STRAFERCLASS",
		"#LAB_TARGETS_STRAFERCLASS_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchStraferLegend" ), "#LAB_TARGETS_STRAFERLEGEND",
		"#LAB_TARGETS_STRAFERLEGEND_DESC" )
	LabTargets_SetupSlider( LabTargets_Row( "SldStrafeSpeed" ), "#LAB_TARGETS_STRAFESPEED", "#LAB_TARGETS_STRAFESPEED_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchBotHealth" ), "#LAB_TARGETS_BOTHEALTH",
		"#LAB_TARGETS_BOTHEALTH_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchBotFire" ), "#LAB_TARGETS_BOTFIRE",
		"#LAB_TARGETS_BOTFIRE_DESC" )
	LabTargets_SetupSlider( LabTargets_Row( "SldBotAim" ), "#LAB_TARGETS_BOTAIM", "#LAB_TARGETS_BOTAIM_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchStrafeTimeMin" ), "#LAB_TARGETS_STRAFETIMEMIN",
		"#LAB_TARGETS_STRAFETIMEMIN_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchStrafeTimeMax" ), "#LAB_TARGETS_STRAFETIMEMAX",
		"#LAB_TARGETS_STRAFETIMEMAX_DESC" )
	LabTargets_BuildStrafeTimeList( LabTargets_Row( "SwitchStrafeTimeMin" ) )
	LabTargets_BuildStrafeTimeList( LabTargets_Row( "SwitchStrafeTimeMax" ) )
	Lab_SetupRow( LabTargets_Row( "SwitchFixedSpawn" ), "#LAB_TARGETS_FIXEDSPAWN",
		"#LAB_TARGETS_FIXEDSPAWN_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonSetSpawn" ), "#LAB_TARGETS_SETSPAWN",
		"#LAB_TARGETS_SETSPAWN_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchDummyArmor" ), "#LAB_TARGETS_ARMOR",
		"#LAB_TARGETS_ARMOR_DESC", true )
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
	Lab_SetupRow( LabTargets_Row( "SwitchHighlight" ), "#LAB_TARGETS_HIGHLIGHT",
		"#LAB_TARGETS_HIGHLIGHT_DESC" )
	Lab_SetupRow( LabTargets_Row( "SwitchReconBars" ), "#LAB_TARGETS_RECONBARS",
		"#LAB_TARGETS_RECONBARS_DESC" )
	Lab_SetupRow( LabTargets_Row( "ButtonQuitAimTrainer" ), "#LAB_TARGETS_CLEAR",
		"#LAB_TARGETS_CLEAR_DESC" )

	LabTargets_BuildAimModeList()
	LabTargets_BuildDurationList()
	LabTargets_BuildArmorList()
	LabTargets_BuildStraferBodyList()

	AddButtonEventHandler( LabTargets_Row( "ButtonStrafer" ), UIE_CLICK, LabTargets_ClickStrafer )
	AddButtonEventHandler( LabTargets_Row( "ButtonStraferFast" ), UIE_CLICK, LabTargets_ClickStraferFast )
	AddButtonEventHandler( LabTargets_Row( "ButtonChallengeStart" ), UIE_CLICK, LabTargets_ClickStart )
	AddButtonEventHandler( LabTargets_Row( "ButtonChallengeStop" ), UIE_CLICK, LabTargets_ClickStop )
	AddButtonEventHandler( LabTargets_Row( "ButtonQuitAimTrainer" ), UIE_CLICK, LabTargets_ClickQuit )

	AddButtonEventHandler( LabTargets_Row( "SldStrafeSpeed" ), UIE_CHANGE, LabTargets_OnStrafeSpeed )
	AddButtonEventHandler( LabTargets_Row( "SwitchStraferBody" ), UIE_CHANGE, LabTargets_OnStraferBody )
	AddButtonEventHandler( LabTargets_Row( "SwitchStraferClass" ), UIE_CHANGE, LabTargets_OnStraferClass )
	AddButtonEventHandler( LabTargets_Row( "SwitchStraferLegend" ), UIE_CHANGE, LabTargets_OnStraferLegend )
	AddButtonEventHandler( LabTargets_Row( "SwitchBotHealth" ), UIE_CHANGE, LabTargets_OnBotHealth )
	AddButtonEventHandler( LabTargets_Row( "SwitchBotFire" ), UIE_CHANGE, LabTargets_OnBotFire )
	AddButtonEventHandler( LabTargets_Row( "SldBotAim" ), UIE_CHANGE, LabTargets_OnBotAim )
	AddButtonEventHandler( LabTargets_Row( "SwitchStrafeTimeMin" ), UIE_CHANGE, LabTargets_OnStrafeTime )
	AddButtonEventHandler( LabTargets_Row( "SwitchStrafeTimeMax" ), UIE_CHANGE, LabTargets_OnStrafeTime )
	AddButtonEventHandler( LabTargets_Row( "SwitchFixedSpawn" ), UIE_CHANGE, LabTargets_OnFixedSpawn )
	AddButtonEventHandler( LabTargets_Row( "ButtonSetSpawn" ), UIE_CLICK, LabTargets_ClickSetSpawn )
	AddButtonEventHandler( LabTargets_Row( "SwitchDummyArmor" ), UIE_CHANGE, LabTargets_OnArmor )
	AddButtonEventHandler( LabTargets_Row( "SwitchDuration" ), UIE_CHANGE, LabTargets_OnDuration )
	AddButtonEventHandler( LabTargets_Row( "SwitchReloadKill" ), UIE_CHANGE, LabTargets_OnReloadKill )
	AddButtonEventHandler( LabTargets_Row( "SwitchReloadHit" ), UIE_CHANGE, LabTargets_OnReloadHit )
	AddButtonEventHandler( LabTargets_Row( "SwitchReloadShot" ), UIE_CHANGE, LabTargets_OnReloadShot )
	AddButtonEventHandler( LabTargets_Row( "SwitchDynStats" ), UIE_CHANGE, LabTargets_OnDynStats )
	AddButtonEventHandler( LabTargets_Row( "SwitchReconBars" ), UIE_CHANGE, LabTargets_OnReconBars )
	AddButtonEventHandler( LabTargets_Row( "SwitchHighlight" ), UIE_CHANGE, LabTargets_OnHighlight )
}

// A SliderControl has no SwitchButton RUI, so the title goes on its
// BtnDropButton child. Focus lands on that child, not the slider, so the
// details pane is fed from there.
void function LabTargets_SetupSlider( var slider, string title, string desc )
{
	file.sliderTitles[ slider ] <- title
	file.sliderDescs[ slider ] <- desc
	Hud_AddEventHandler( slider, UIE_GET_FOCUS, LabTargets_SliderFocus )

	if ( !Hud_HasChild( slider, "BtnDropButton" ) )
		return

	var dropButton = Hud_GetChild( slider, "BtnDropButton" )
	SetButtonRuiText( dropButton, title )
	file.sliderTitles[ dropButton ] <- title
	file.sliderDescs[ dropButton ] <- desc
	AddButtonEventHandler( dropButton, UIE_GET_FOCUS, LabTargets_SliderFocus )
}

void function LabTargets_SliderFocus( var widget )
{
	if ( !( widget in file.sliderDescs ) )
		return
	Lab_SetDetails( Localize( file.sliderTitles[ widget ] ), Localize( file.sliderDescs[ widget ] ) )
}

void function LabTargets_BuildAimModeList()
{
	var button = LabTargets_Row( "SwitchAimMode" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_MODE_TS" ), "ts" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_MODE_POPCORN" ), "popcorn" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_MODE_STRAFER" ), "strafer_challenge" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_MODE_STRAFERFAST" ), "strafer_hard_challenge" )
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

void function LabTargets_BuildArmorList()
{
	var button = LabTargets_Row( "SwitchDummyArmor" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_ARMOR_WHITE" ), "1" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_ARMOR_BLUE" ), "2" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_ARMOR_PURPLE" ), "3" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_ARMOR_RED" ), "4" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_ARMOR_RANDOM" ), "10" )
	Hud_SetDialogListSelectionValue( button, "1" )
}

// Same steps as the firing range dummy strafe duration list.
void function LabTargets_BuildStrafeTimeList( var button )
{
	array< string > labels = [
		"#FRSETTING_DUMMIESTRAFEDURATION_010",
		"#FRSETTING_DUMMIESTRAFEDURATION_015",
		"#FRSETTING_DUMMIESTRAFEDURATION_020",
		"#FRSETTING_DUMMIESTRAFEDURATION_025",
		"#FRSETTING_DUMMIESTRAFEDURATION_030",
		"#FRSETTING_DUMMIESTRAFEDURATION_040",
		"#FRSETTING_DUMMIESTRAFEDURATION_050",
		"#FRSETTING_DUMMIESTRAFEDURATION_060",
		"#FRSETTING_DUMMIESTRAFEDURATION_075",
		"#FRSETTING_DUMMIESTRAFEDURATION_090",
	]
	Hud_DialogList_ClearList( button )
	for ( int i = 0; i < labels.len(); i++ )
		Hud_DialogList_AddListItem( button, Localize( labels[ i ] ), string( i ) )
}

void function LabTargets_BuildStraferBodyList()
{
	var button = LabTargets_Row( "SwitchStraferBody" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_BODY_DUMMY" ), "dummy" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_BODY_LEGEND" ), "legend" )
	Hud_SetDialogListSelectionValue( button, "dummy" )
}

// Short class-first picker so no single legend list overflows the popup.
void function LabTargets_BuildStraferGroupList()
{
	var button = LabTargets_Row( "SwitchStraferClass" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_SAME_AS_ME" ), "-1" )
	for ( int role = 0; role < eCharacterClassRole._COUNT; role++ )
	{
		string title = ""
		try
		{
			title = Localize( CharacterClass_GetRoleTitle( role ) )
		}
		catch ( eTitle )
		{
		}
		if ( title == "" )
			continue
		Hud_DialogList_AddListItem( button, title, string( role ) )
	}
	Hud_SetDialogListSelectionValue( button, "-1" )
}

void function LabTargets_BuildStraferLegendListForGroup( int role )
{
	var button = LabTargets_Row( "SwitchStraferLegend" )
	Hud_DialogList_ClearList( button )
	if ( role < 0 )
	{
		Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_SAME_AS_ME" ), "same" )
		Hud_SetDialogListSelectionValue( button, "same" )
		return
	}
	string firstRef = ""

	array<ItemFlavor> characters = clone GetAllCharacters()
	foreach ( ItemFlavor character in characters )
	{
		string ref = ItemFlavor_GetCharacterRef( character )
		if ( HIDDEN_CHARACTER_REFS.len() > 0 && HIDDEN_CHARACTER_REFS.contains( ref ) )
			continue
		int charRole = -1
		try
		{
			charRole = CharacterClass_GetRole( character )
		}
		catch ( eRole )
		{
		}
		if ( charRole != role )
			continue

		string label = Localize( ItemFlavor_GetLongName( character ) )
		if ( label == "" )
			label = ref

		Hud_DialogList_AddListItem( button, label, ref )
		if ( firstRef == "" )
			firstRef = ref
	}
	if ( firstRef == "" )
	{
		Hud_DialogList_AddListItem( button, Localize( "#LAB_TARGETS_SAME_AS_ME" ), "same" )
		firstRef = "same"
	}
	Hud_SetDialogListSelectionValue( button, firstRef )
}

// Same ordering as the server sync index: sorted visible character refs.
array<string> function LabTargets_BuildVisibleLegendRefs()
{
	array<string> refs = []
	foreach ( ItemFlavor character in GetAllCharacters() )
	{
		string ref = ItemFlavor_GetCharacterRef( character )
		if ( ref == "" || refs.contains( ref ) )
			continue
		if ( HIDDEN_CHARACTER_REFS.len() > 0 && HIDDEN_CHARACTER_REFS.contains( ref ) )
			continue
		refs.append( ref )
	}
	refs.sort()
	return refs
}

int function LabTargets_FindLegendRole( string ref )
{
	foreach ( ItemFlavor character in GetAllCharacters() )
	{
		if ( ItemFlavor_GetCharacterRef( character ) != ref )
			continue
		try
		{
			return CharacterClass_GetRole( character )
		}
		catch ( eRole )
		{
			return -1
		}
	}
	return -1
}

void function OnLabTargetsPanel_Show( var panel )
{
	if ( !file.straferListsBuilt )
	{
		LabTargets_BuildStraferGroupList()
		LabTargets_BuildStraferLegendListForGroup( -1 )
		file.straferListsBuilt = true
	}

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
void function LabTargets_SetState( bool hit, bool shot, bool kill, bool dynStats, bool reconBars, int durationSec, bool straferGod, int strafeSpeedTenth, int dummyShield, int straferBody, int straferLegendIdx, bool highlight = true, bool straferFire = false, int straferAim = 50, int strafeTime = 26, bool fixedSpawn = false )
{
	if ( file.rows.len() == 0 )
		return

	file.applyingValues = true
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchHighlight" ), highlight ? "1" : "0" )
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
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchBotFire" ), straferFire ? "1" : "0" )
	file.lastAimSent = straferAim
	Hud_SliderControl_SetCurrentValue( LabTargets_Row( "SldBotAim" ), float( straferAim ) / 100.0 )
	file.lastStrafeTimeSent = strafeTime
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchStrafeTimeMin" ), string( ( strafeTime / 10 ) % 10 ) )
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchStrafeTimeMax" ), string( strafeTime % 10 ) )
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchFixedSpawn" ), fixedSpawn ? "1" : "0" )
	// Selection 0 means default, which tiers as white.
	int armorSel = dummyShield
	if ( armorSel != 1 && armorSel != 2 && armorSel != 3 && armorSel != 4 && armorSel != 10 )
		armorSel = 1
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchDummyArmor" ), string( armorSel ) )
	file.straferIsLegend = straferBody == 1
	Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchStraferBody" ), file.straferIsLegend ? "legend" : "dummy" )
	if ( file.straferListsBuilt )
	{
		if ( straferLegendIdx < 0 )
		{
			file.straferClass = -1
			Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchStraferClass" ), "-1" )
			LabTargets_BuildStraferLegendListForGroup( -1 )
		}
		else
		{
			array<string> refs = LabTargets_BuildVisibleLegendRefs()
			if ( straferLegendIdx < refs.len() )
			{
				string ref = refs[straferLegendIdx]
				int role = LabTargets_FindLegendRole( ref )
				if ( role >= 0 )
				{
					file.straferClass = role
					Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchStraferClass" ), string( role ) )
					LabTargets_BuildStraferLegendListForGroup( role )
					Hud_SetDialogListSelectionValue( LabTargets_Row( "SwitchStraferLegend" ), ref )
				}
			}
		}
	}
	file.applyingValues = false
	LabTargets_ApplyGates()
}

void function LabTargets_ApplyGates()
{
	if ( file.rows.len() == 0 )
		return

	foreach ( string name, var button in file.rows )
		Lab_SetRowState( button )

	bool legendLive = Lab_GetCheats() && file.straferIsLegend
	Hud_SetEnabled( LabTargets_Row( "SwitchStraferClass" ), legendLive )
	Hud_SetEnabled( LabTargets_Row( "SwitchStraferLegend" ), legendLive )
	Hud_SetEnabled( LabTargets_Row( "SwitchBotFire" ), legendLive )
	Hud_SetEnabled( LabTargets_Row( "SldBotAim" ), legendLive )
	Hud_SetEnabled( LabTargets_Row( "SwitchStrafeTimeMin" ), legendLive )
	Hud_SetEnabled( LabTargets_Row( "SwitchStrafeTimeMax" ), legendLive )
}

bool function LabTargets_Ignore()
{
	return file.applyingValues || !Lab_GetCheats()
}

void function LabTargets_SendRaw( string cmd )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( cmd )
}

void function LabTargets_Send( string action )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "dev_aimtrainer " + action )
}

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

void function LabTargets_OnStraferBody( var button )
{
	if ( LabTargets_Ignore() )
		return

	string val = Hud_GetDialogListSelectionValue( button )
	if ( val != "dummy" && val != "legend" )
		return
	file.straferIsLegend = val == "legend"
	LabTargets_ApplyGates()
	ClientCommand( "dev_aimtrainer strafer_body " + val )
}

void function LabTargets_OnStraferClass( var button )
{
	if ( LabTargets_Ignore() )
		return

	string v = Hud_GetDialogListSelectionValue( button )
	int role = -1
	try
	{
		role = int( v )
	}
	catch ( eInt )
	{
	}
	file.straferClass = role
	LabTargets_BuildStraferLegendListForGroup( role )
	ClientCommand( "dev_aimtrainer strafer_legend " + Hud_GetDialogListSelectionValue( LabTargets_Row( "SwitchStraferLegend" ) ) )
}

void function LabTargets_OnStraferLegend( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer strafer_legend " + Hud_GetDialogListSelectionValue( button ) )
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

void function LabTargets_OnBotFire( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer bot_fire " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabTargets_OnBotAim( var button )
{
	if ( LabTargets_Ignore() )
		return
	int aim = int( Hud_SliderControl_GetCurrentValue( button ) * 100.0 + 0.5 )
	if ( aim == file.lastAimSent )
		return
	file.lastAimSent = aim
	ClientCommand( format( "dev_aimtrainer bot_aim %d", aim ) )
}

void function LabTargets_OnStrafeTime( var button )
{
	if ( LabTargets_Ignore() )
		return
	int minIdx = int( Hud_GetDialogListSelectionValue( LabTargets_Row( "SwitchStrafeTimeMin" ) ) )
	int maxIdx = int( Hud_GetDialogListSelectionValue( LabTargets_Row( "SwitchStrafeTimeMax" ) ) )
	int packed = minIdx * 10 + maxIdx
	if ( packed == file.lastStrafeTimeSent )
		return
	file.lastStrafeTimeSent = packed
	ClientCommand( format( "dev_aimtrainer strafe_time %d %d", minIdx, maxIdx ) )
}

void function LabTargets_OnFixedSpawn( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer spawn_fixed " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabTargets_ClickSetSpawn( var button ) { LabTargets_Send( "spawn_set" ) }

void function LabTargets_OnArmor( var button )
{
	if ( LabTargets_Ignore() )
		return

	int setting = int( Hud_GetDialogListSelectionValue( button ) )
	if ( setting != 1 && setting != 2 && setting != 3 && setting != 4 && setting != 10 )
		return
	ClientCommand( format( "dev_aimtrainer armor %d", setting ) )
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

void function LabTargets_OnHighlight( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer highlight " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabTargets_OnReconBars( var button )
{
	if ( LabTargets_Ignore() )
		return
	ClientCommand( "dev_aimtrainer healthbars " + Hud_GetDialogListSelectionValue( button ) )
}
