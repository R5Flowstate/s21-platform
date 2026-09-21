global function InitLabRecorderPanel
global function LabRecorder_SetState
global function LabRecorder_ClearSlots
global function LabRecorder_AddSlot
global function LabRecorder_SetHints
global function LabRecorder_SetRecording

const int LAB_RECORDER_ROWS = 8

struct
{
	var panel
	var contentPanelParent
	var contentPanel
	var scrollBar
	var scrollFrame

	table< string, var > rows
	array<var> recRows
	array<string> recLabels
	array<string> recDescs

	bool listsBuilt = false
	bool scrollReady = false
	bool applyingValues = false
	float lastRateSent = 1.0
	int selectedSlot = -1
	bool recording = false
} file

void function InitLabRecorderPanel( var panel )
{
	file.panel = panel

	file.contentPanelParent = Hud_GetChild( panel, "ModeOptionsPanel" )
	file.contentPanel = Hud_GetChild( file.contentPanelParent, "ContentPanel" )
	file.scrollBar = Hud_GetChild( file.contentPanelParent, "ScrollBar" )
	file.scrollFrame = Hud_GetChild( file.contentPanelParent, "ScrollFrame" )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabRecorderPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabRecorderPanel_Hide )

	LabRecorder_BindRows()

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_InitPanel( file.contentPanelParent )
	ScrollPanel_InitScrollBar( file.contentPanelParent, file.scrollBar )
	file.scrollReady = true
	LabRecorder_ClearSlots()

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	Lab_AddGateListener( LabRecorder_ApplyGates )
}

var function LabRecorder_Row( string name )
{
	return file.rows[ name ]
}

void function LabRecorder_BindRows()
{
	array<string> names = [
		"SwitchLegendGroup", "SwitchLegend",
		"ButtonRecord", "ButtonRename", "ButtonDelete", "ButtonPlayAll", "ButtonClearAll",
		"SwitchHints", "SwitchLoop", "SwitchRespawn", "SldRate", "SwitchRecordMode"
	]

	foreach ( string name in names )
		file.rows[ name ] <- Hud_GetChild( file.contentPanel, name )

	Lab_SetupRow( LabRecorder_Row( "SwitchLegendGroup" ), "#LAB_RECORDER_LEGENDGROUP",
		"#LAB_RECORDER_LEGENDGROUP_DESC" )
	Lab_SetupRow( LabRecorder_Row( "SwitchLegend" ), "#LAB_RECORDER_LEGEND",
		"#LAB_RECORDER_LEGEND_DESC" )
	Lab_SetupRow( LabRecorder_Row( "ButtonRecord" ), "#LAB_RECORDER_RECORD",
		"#LAB_RECORDER_RECORD_DESC" )
	Lab_SetupRow( LabRecorder_Row( "ButtonRename" ), "#LAB_RECORDER_RENAME",
		"#LAB_RECORDER_RENAME_DESC" )
	Lab_SetupRow( LabRecorder_Row( "ButtonDelete" ), "#LAB_RECORDER_DELETE",
		"#LAB_RECORDER_DELETE_DESC" )
	Lab_SetupRow( LabRecorder_Row( "ButtonPlayAll" ), "#LAB_RECORDER_PLAYALL",
		"#LAB_RECORDER_PLAYALL_DESC" )
	Lab_SetupRow( LabRecorder_Row( "ButtonClearAll" ), "#LAB_RECORDER_CLEARALL",
		"#LAB_RECORDER_CLEARALL_DESC" )
	Lab_SetupRow( LabRecorder_Row( "SwitchHints" ), "#LAB_RECORDER_HINTS",
		"#LAB_RECORDER_HINTS_DESC" )
	Lab_SetupRow( LabRecorder_Row( "SwitchLoop" ), "#LAB_RECORDER_LOOP",
		"#LAB_RECORDER_LOOP_DESC" )
	Lab_SetupRow( LabRecorder_Row( "SwitchRespawn" ), "#LAB_RECORDER_RESPAWN",
		"#LAB_RECORDER_RESPAWN_DESC" )
	LabRecorder_SetupSlider( LabRecorder_Row( "SldRate" ), "#LAB_RECORDER_RATE" )
	Lab_SetupRow( LabRecorder_Row( "SwitchRecordMode" ), "#LAB_RECORDER_RECMODE",
		"#LAB_RECORDER_RECMODE_DESC" )

	for ( int i = 0; i < LAB_RECORDER_ROWS; i++ )
	{
		var row = Hud_GetChild( file.contentPanel, format( "ButtonRec%d", i ) )
		file.recRows.append( row )
		file.recLabels.append( "" )
		file.recDescs.append( "" )
		Hud_Hide( row )
		Hud_SetEnabled( row, false )
		Lab_SetupRow( row, "", "#LAB_RECORDER_ROW_DESC" )
		Hud_AddEventHandler( row, UIE_GET_FOCUS, LabRecorder_RowFocus )
		AddButtonEventHandler( row, UIE_CLICK, LabRecorder_ClickRow )
	}

	LabRecorder_BuildHintsList()
	LabRecorder_BuildLoopList()
	LabRecorder_BuildRespawnList()
	LabRecorder_BuildModeLists()

	AddButtonEventHandler( LabRecorder_Row( "SwitchLegendGroup" ), UIE_CHANGE, LabRecorder_OnLegendGroup )
	AddButtonEventHandler( LabRecorder_Row( "SwitchLegend" ), UIE_CHANGE, LabRecorder_OnLegend )
	AddButtonEventHandler( LabRecorder_Row( "SwitchRespawn" ), UIE_CHANGE, LabRecorder_OnRespawn )
	AddButtonEventHandler( LabRecorder_Row( "SwitchHints" ), UIE_CHANGE, LabRecorder_OnHints )
	AddButtonEventHandler( LabRecorder_Row( "SwitchLoop" ), UIE_CHANGE, LabRecorder_OnLoop )
	AddButtonEventHandler( LabRecorder_Row( "SldRate" ), UIE_CHANGE, LabRecorder_OnRate )
	AddButtonEventHandler( LabRecorder_Row( "SwitchRecordMode" ), UIE_CHANGE, LabRecorder_OnRecordMode )

	AddButtonEventHandler( LabRecorder_Row( "ButtonRecord" ), UIE_CLICK, LabRecorder_ClickRecord )
	AddButtonEventHandler( LabRecorder_Row( "ButtonRename" ), UIE_CLICK, LabRecorder_ClickRename )
	AddButtonEventHandler( LabRecorder_Row( "ButtonDelete" ), UIE_CLICK, LabRecorder_ClickDelete )
	AddButtonEventHandler( LabRecorder_Row( "ButtonPlayAll" ), UIE_CLICK, LabRecorder_ClickPlayAll )
	AddButtonEventHandler( LabRecorder_Row( "ButtonClearAll" ), UIE_CLICK, LabRecorder_ClickClearAll )
}

void function LabRecorder_SetupSlider( var slider, string title )
{
	if ( Hud_HasChild( slider, "BtnDropButton" ) )
		SetButtonRuiText( Hud_GetChild( slider, "BtnDropButton" ), title )
	Hud_AddEventHandler( slider, UIE_GET_FOCUS, LabRecorder_SliderFocus )
}

void function LabRecorder_SliderFocus( var slider )
{
	if ( slider == LabRecorder_Row( "SldRate" ) )
		Lab_SetDetails( Localize( "#LAB_RECORDER_RATE" ), Localize( "#LAB_RECORDER_RATE_DESC" ) )
}

void function LabRecorder_BuildLegendList()
{
	LabRecorder_BuildLegendGroupList()
	LabRecorder_BuildLegendListForGroup( -1 )
}

// The list popup shows a handful of rows; the roster is grouped by class so
// no single list overflows.
void function LabRecorder_BuildLegendGroupList()
{
	var button = LabRecorder_Row( "SwitchLegendGroup" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_SAME" ), "-1" )
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

void function LabRecorder_BuildLegendListForGroup( int role )
{
	var button = LabRecorder_Row( "SwitchLegend" )
	Hud_DialogList_ClearList( button )
	if ( role < 0 )
	{
		Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_SAME" ), "same" )
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
		Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_SAME" ), "same" )
		firstRef = "same"
	}
	Hud_SetDialogListSelectionValue( button, firstRef )
}

void function LabRecorder_OnLegendGroup( var button )
{
	string v = Hud_GetDialogListSelectionValue( button )
	int role = -1
	try
	{
		role = int( v )
	}
	catch ( eInt )
	{
	}
	LabRecorder_BuildLegendListForGroup( role )
	LabRecorder_Send( "legend " + Hud_GetDialogListSelectionValue( LabRecorder_Row( "SwitchLegend" ) ) )
}

void function LabRecorder_BuildRespawnList()
{
	var button = LabRecorder_Row( "SwitchRespawn" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_RESPAWN_INSTANT" ), "0" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_RESPAWN_1" ), "1" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_RESPAWN_3" ), "3" )
	Hud_DialogList_AddListItem( button, Localize( "#LAB_RECORDER_RESPAWN_5" ), "5" )
	Hud_SetDialogListSelectionValue( button, "0" )
}

void function LabRecorder_OnRespawn( var button )
{
	LabRecorder_Send( "respawn " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabRecorder_BuildHintsList()
{
	var button = LabRecorder_Row( "SwitchHints" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#SETTING_OFF" ), "0" )
	Hud_DialogList_AddListItem( button, Localize( "#SETTING_ON" ), "1" )
	Hud_SetDialogListSelectionValue( button, "0" )
}

void function LabRecorder_SetHints( bool shown )
{
	if ( file.rows.len() == 0 )
		return
	file.applyingValues = true
	Hud_SetDialogListSelectionValue( LabRecorder_Row( "SwitchHints" ), shown ? "1" : "0" )
	file.applyingValues = false
}

void function LabRecorder_OnHints( var button )
{
	if ( file.applyingValues )
		return
	RunClientScript( "MRec_CL_SetHints", Hud_GetDialogListSelectionValue( button ) == "1" )
}

void function LabRecorder_BuildLoopList()
{
	var button = LabRecorder_Row( "SwitchLoop" )
	Hud_DialogList_ClearList( button )
	Hud_DialogList_AddListItem( button, Localize( "#SETTING_OFF" ), "0" )
	Hud_DialogList_AddListItem( button, Localize( "#SETTING_ON" ), "1" )
	Hud_SetDialogListSelectionValue( button, "1" )
}

void function LabRecorder_BuildModeLists()
{
	var rec = LabRecorder_Row( "SwitchRecordMode" )
	Hud_DialogList_ClearList( rec )
	Hud_DialogList_AddListItem( rec, Localize( "#LAB_RECORDER_MODE_INPUT" ), "input" )
	Hud_DialogList_AddListItem( rec, Localize( "#LAB_RECORDER_MODE_ANIM" ), "anim" )
	Hud_SetDialogListSelectionValue( rec, "input" )
}

void function LabRecorder_OnRecordMode( var button )
{
	LabRecorder_Send( "mode " + Hud_GetDialogListSelectionValue( button ) )
}

void function OnLabRecorderPanel_Show( var panel )
{
	if ( !file.listsBuilt )
	{
		LabRecorder_BuildLegendList()
		file.listsBuilt = true
	}

	ClientCommand( "mrec sync" )
	LabRecorder_ApplyGates()

	ScrollPanel_SetActive( file.contentPanelParent, true )
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

void function OnLabRecorderPanel_Hide( var panel )
{
	ScrollPanel_SetActive( file.contentPanelParent, false )
}

void function LabRecorder_SetState( int count, int loopFlag, int rateTenth )
{
	if ( file.rows.len() == 0 )
		return

	file.applyingValues = true
	Hud_SetDialogListSelectionValue( LabRecorder_Row( "SwitchLoop" ), loopFlag == 1 ? "1" : "0" )
	float rate = float( rateTenth ) / 10.0
	if ( rate < 0.25 )
		rate = 0.25
	if ( rate > 2.0 )
		rate = 2.0
	file.lastRateSent = rate
	Hud_SliderControl_SetCurrentValue( LabRecorder_Row( "SldRate" ), rate )
	file.applyingValues = false
}

// The list is rebuilt from a full sync: ClearSlots, one AddSlot per recording.
void function LabRecorder_ClearSlots()
{
	if ( file.recRows.len() == 0 )
		return
	foreach ( var row in file.recRows )
	{
		Hud_Hide( row )
		Hud_SetEnabled( row, false )
	}
	if ( LabRecorder_Enabled() )
		LabRecorder_LabelRow( 0, "#LAB_RECORDER_NOREC", "#LAB_RECORDER_NOREC_DESC" )
	else
		LabRecorder_LabelRow( 0, "#LAB_RECORDER_DISABLED", "#LAB_RECORDER_DISABLED_DESC" )
	Hud_Show( file.recRows[0] )
	file.selectedSlot = -1
	LabRecorder_RelayoutRows()
}

// The playlist turns the recorder on for everyone; sv_cheats turns it on anywhere.
bool function LabRecorder_Enabled()
{
	if ( Lab_GetCheats() )
		return true
	if ( !IsConnected() )
		return false
	return GetCurrentPlaylistVarBool( "movement_recorder_enable", false )
}

void function LabRecorder_AddSlot( int idx, int durationTenth, string name, string loadout )
{
	if ( file.recRows.len() == 0 )
		return
	if ( idx < 0 || idx >= LAB_RECORDER_ROWS )
		return

	string title = name != "" ? name : Localize( "#LAB_RECORDER_SLOT", idx + 1 )
	string label = string( idx + 1 ) + ".  " + title
	if ( loadout != "" )
		label += "   " + loadout
	label += "   " + format( "%.1fs", float( durationTenth ) / 10.0 )
	var row = file.recRows[idx]
	LabRecorder_LabelRow( idx, label, "#LAB_RECORDER_ROW_DESC" )
	Hud_Show( row )
	Lab_SetRowState( row )
	if ( file.selectedSlot < 0 )
		file.selectedSlot = idx
	LabRecorder_RelayoutRows()
}

// Rows are wired once at init (every setup adds focus handlers); only the text moves.
void function LabRecorder_LabelRow( int idx, string label, string desc )
{
	file.recLabels[idx] = label
	file.recDescs[idx] = desc
	SetButtonRuiText( file.recRows[idx], label )
}

void function LabRecorder_RelayoutRows()
{
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	if ( file.scrollReady )
		ScrollPanel_Refresh( file.contentPanelParent )
}

void function LabRecorder_RowFocus( var row )
{
	int idx = file.recRows.find( row )
	if ( idx < 0 )
		return
	Lab_SetDetails( Localize( file.recLabels[idx] ), Localize( file.recDescs[idx] ) )
	if ( file.selectedSlot >= 0 )
		file.selectedSlot = idx
}

void function LabRecorder_ClickRow( var row )
{
	if ( !Lab_GetCheats() )
		return
	int idx = file.recRows.find( row )
	if ( idx < 0 || file.selectedSlot < 0 )
		return
	file.selectedSlot = idx
	ClientCommand( "mrec play " + string( idx + 1 ) )
}

void function LabRecorder_ApplyGates()
{
	if ( file.rows.len() == 0 )
		return

	foreach ( string name, var button in file.rows )
	{
		if ( name == "SwitchHints" )
			continue
		Lab_SetRowState( button )
	}
	for ( int i = 0; i < file.recRows.len(); i++ )
	{
		if ( Hud_IsVisible( file.recRows[i] ) && file.selectedSlot >= 0 )
			Lab_SetRowState( file.recRows[i] )
	}
	if ( file.selectedSlot < 0 )
		LabRecorder_ClearSlots()
}

bool function LabRecorder_Ignore()
{
	return file.applyingValues || !Lab_GetCheats()
}

void function LabRecorder_Send( string action )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "mrec " + action )
}

void function LabRecorder_OnLegend( var button )
{
	if ( LabRecorder_Ignore() )
		return
	LabRecorder_Send( "legend " + Hud_GetDialogListSelectionValue( button ) )
}

void function LabRecorder_OnLoop( var button )
{
	if ( LabRecorder_Ignore() )
		return

	string val = Hud_GetDialogListSelectionValue( button )
	if ( val != "0" && val != "1" )
		return
	LabRecorder_Send( "loop " + val )
}

void function LabRecorder_OnRate( var button )
{
	if ( LabRecorder_Ignore() )
		return

	float rate = Hud_SliderControl_GetCurrentValue( button )
	if ( rate < 0.25 )
		rate = 0.25
	if ( rate > 2.0 )
		rate = 2.0
	if ( fabs( rate - file.lastRateSent ) < 0.01 )
		return
	file.lastRateSent = rate
	ClientCommand( format( "mrec rate %.2f", rate ) )
}

// Starting a recording drops you straight back into the game; stopping keeps
// the menu so the new clip is right there in the list.
void function LabRecorder_ClickRecord( var button )
{
	if ( !Lab_GetCheats() )
		return

	bool starting = !file.recording
	LabRecorder_Send( "toggle" )
	if ( starting )
		CloseAllMenus()
}

void function LabRecorder_SetRecording( bool recording )
{
	file.recording = recording
	if ( file.rows.len() == 0 )
		return
	SetButtonRuiText( LabRecorder_Row( "ButtonRecord" ),
		Localize( recording ? "#MREC_HUD_STOP_SAVE" : "#LAB_RECORDER_RECORD" ) )
}

void function LabRecorder_ClickRename( var button )
{
	if ( !Lab_GetCheats() || file.selectedSlot < 0 )
		return
	int slot = file.selectedSlot
	ConfirmDialogData data
	data.headerText = "#LAB_RECORDER_RENAME"
	data.messageText = Localize( "#LAB_RECORDER_RENAME_PROMPT", slot + 1 )
	OpenTextEntryDialogFromData( data, void function( string name ) : ( slot )
	{
		ClientCommand( "mrec name " + string( slot + 1 ) + " " + strip( name ) )
	} )
}

void function LabRecorder_ClickDelete( var button )
{
	if ( !Lab_GetCheats() || file.selectedSlot < 0 )
		return
	ClientCommand( "mrec clear " + string( file.selectedSlot + 1 ) )
}

void function LabRecorder_ClickPlayAll( var button )
{
	LabRecorder_Send( "playall" )
}

void function LabRecorder_ClickClearAll( var button )
{
	LabRecorder_Send( "clear all" )
}
