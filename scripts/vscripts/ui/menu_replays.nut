global function InitReplaysMenu
global function OpenReplaysMenu

const int REPLAYS_ROWS = 15

struct ReplaySummary
{
	string map
	string recorder
	int povCount
	string pov0
	string pov1
	int winner = -1
	float duration
	bool partial
	bool playable
	string mode
	string modeTitle
}

struct
{
	var menu
	array<var> rows
	var infoTitle
	var detail
	var pageLabel
	var countLabel
	var emptyLabel
	var play0
	var play1
	var deleteButton
	var prevButton
	var nextButton
	array<string> names
	table<string, ReplaySummary> summaries
	int page = 0
	int selected = -1
	bool inputsRegistered = false
} file

void function InitReplaysMenu( var newMenuArg )
{
	var menu = GetMenu( "ReplaysMenu" )
	file.menu = menu

	SetGamepadCursorEnabled( menu, true )

	for ( int i = 0; i < REPLAYS_ROWS; i++ )
	{
		var row = Hud_GetChild( menu, "Row" + i )
		file.rows.append( row )
		Hud_AddEventHandler( row, UIE_CLICK, Replays_OnRowClick )
		Hud_AddEventHandler( row, UIE_DOUBLECLICK, Replays_OnRowDoubleClick )
	}

	file.infoTitle = Hud_GetChild( menu, "InfoTitle" )
	file.detail = Hud_GetChild( menu, "DetailLabel" )
	file.pageLabel = Hud_GetChild( menu, "PageLabel" )
	file.countLabel = Hud_GetChild( menu, "CountLabel" )
	file.emptyLabel = Hud_GetChild( menu, "EmptyLabel" )
	file.play0 = Hud_GetChild( menu, "PlayPov0Button" )
	file.play1 = Hud_GetChild( menu, "PlayPov1Button" )
	file.deleteButton = Hud_GetChild( menu, "DeleteButton" )
	file.prevButton = Hud_GetChild( menu, "PrevButton" )
	file.nextButton = Hud_GetChild( menu, "NextButton" )

	Hud_AddEventHandler( file.play0, UIE_CLICK, Replays_OnPlay0 )
	Hud_AddEventHandler( file.play1, UIE_CLICK, Replays_OnPlay1 )
	Hud_AddEventHandler( file.deleteButton, UIE_CLICK, Replays_OnDelete )
	Hud_AddEventHandler( file.prevButton, UIE_CLICK, Replays_OnPrev )
	Hud_AddEventHandler( file.nextButton, UIE_CLICK, Replays_OnNext )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, Replays_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, Replays_OnClose )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, Replays_OnNavBack )

	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CLOSE", "#CLOSE" )
	AddMenuFooterOption( menu, LEFT, KEY_ENTER, true, "", "#DEMO_REPLAYS_FOOTER_WATCH", Replays_OnPlay0, Replays_HasSelection )
	AddMenuFooterOption( menu, LEFT, BUTTON_X, true, "#DEMO_REPLAYS_FOOTER_DELETE_PAD", "", Replays_OnDelete, Replays_HasSelection )
	AddMenuFooterOption( menu, LEFT, KEY_DELETE, true, "", "#DEMO_REPLAYS_FOOTER_DELETE", Replays_OnDelete, Replays_HasSelection )
	AddMenuFooterOption( menu, LEFT, BUTTON_SHOULDER_LEFT, true, "#DEMO_REPLAYS_FOOTER_PREV_PAD", "", Replays_OnPrev, Replays_HasPages )
	AddMenuFooterOption( menu, LEFT, BUTTON_SHOULDER_RIGHT, true, "#DEMO_REPLAYS_FOOTER_NEXT_PAD", "", Replays_OnNext, Replays_HasPages )
}

void function OpenReplaysMenu( var button )
{
	if ( file.menu == null )
		return
	AdvanceMenu( file.menu )
}

void function Replays_OnOpen()
{
	SetMenuNavigationDisabled( false )
	Replays_Refresh()
	if ( !file.inputsRegistered )
	{
		RegisterButtonPressedCallback( KEY_UP, Replays_OnKeyUp )
		RegisterButtonPressedCallback( KEY_DOWN, Replays_OnKeyDown )
		file.inputsRegistered = true
	}
}

void function Replays_OnClose()
{
	if ( !file.inputsRegistered )
		return
	DeregisterButtonPressedCallback( KEY_UP, Replays_OnKeyUp )
	DeregisterButtonPressedCallback( KEY_DOWN, Replays_OnKeyDown )
	file.inputsRegistered = false
}

void function Replays_OnNavBack()
{
	CloseActiveMenu()
}

bool function Replays_HasSelection()
{
	return file.selected >= 0 && file.selected < file.names.len()
}

bool function Replays_HasPages()
{
	return file.names.len() > REPLAYS_ROWS
}

void function Replays_Refresh()
{
	file.summaries.clear()
	file.names.clear()
	foreach ( string name in Demo_ListFiles() )
	{
		if ( Replays_GetSummary( name ).playable )
			file.names.append( name )
	}
	file.page = 0
	file.selected = file.names.len() > 0 ? 0 : -1
	Replays_Render()
}

ReplaySummary function Replays_GetSummary( string name )
{
	if ( name in file.summaries )
		return file.summaries[ name ]

	ReplaySummary s
	array<string> parts = split( Demo_GetFileSummary( name ), "|" )
	if ( parts.len() >= 9 )
	{
		s.map = Replays_Field( parts[0] )
		s.recorder = Replays_Field( parts[1] )
		s.povCount = parts[2].tointeger()
		s.pov0 = Replays_Field( parts[3] )
		s.pov1 = Replays_Field( parts[4] )
		s.winner = parts[5].tointeger()
		s.duration = parts[6].tofloat()
		s.partial = parts[8] == "1"
		s.playable = parts.len() >= 10 && parts[9] == "1"
		if ( parts.len() >= 12 )
		{
			s.mode = Replays_Field( parts[10] )
			s.modeTitle = Replays_Field( parts[11] )
		}
	}
	file.summaries[ name ] <- s
	return s
}

string function Replays_Field( string value )
{
	return value == " " ? "" : value
}

// Automatic recordings are named [demo_]YYYY-MM-DD_HH-MM-SS_<map>.
string function Replays_When( string name )
{
	string n = name
	if ( n.len() > 5 && n.slice( 0, 5 ) == "demo_" )
		n = n.slice( 5 )
	if ( n.len() < 19 || n.slice( 4, 5 ) != "-" || n.slice( 10, 11 ) != "_" )
		return name
	return n.slice( 0, 10 ) + "  " + n.slice( 11, 13 ) + ":" + n.slice( 14, 16 )
}

string function Replays_Mode( ReplaySummary s )
{
	if ( s.modeTitle != "" )
		return s.modeTitle.slice( 0, 1 ) == "#" ? Localize( s.modeTitle ) : s.modeTitle
	return s.mode
}

string function Replays_Players( ReplaySummary s )
{
	if ( s.povCount > 1 && s.pov0 != "" && s.pov1 != "" )
		return s.pov0 + "  vs  " + s.pov1
	return s.pov0
}

string function Replays_Length( float seconds )
{
	int total = int( max( seconds, 0.0 ) )
	return format( "%d:%02d", total / 60, total % 60 )
}

int function Replays_PageCount()
{
	return maxint( 1, ( file.names.len() + REPLAYS_ROWS - 1 ) / REPLAYS_ROWS )
}

void function Replays_Render()
{
	int pageCount = Replays_PageCount()
	file.page = minint( maxint( file.page, 0 ), pageCount - 1 )

	for ( int i = 0; i < REPLAYS_ROWS; i++ )
	{
		var row = file.rows[ i ]
		int idx = file.page * REPLAYS_ROWS + i
		bool used = idx < file.names.len()
		Hud_SetVisible( row, used )
		Replays_SetRowText( i, "Date", "" )
		Replays_SetRowText( i, "Mode", "" )
		Replays_SetRowText( i, "Players", "" )
		Replays_SetRowText( i, "Map", "" )
		Replays_SetRowText( i, "Length", "" )
		if ( !used )
			continue

		string name = file.names[ idx ]
		ReplaySummary s = Replays_GetSummary( name )
		Hud_SetSelected( row, idx == file.selected )
		Replays_SetRowText( i, "Date", Replays_When( name ) )
		Replays_SetRowText( i, "Mode", Replays_Mode( s ) )
		Replays_SetRowText( i, "Players", Replays_Players( s ) )
		Replays_SetRowText( i, "Map", GetMapDisplayName( s.map ) )
		Replays_SetRowText( i, "Length", Replays_Length( s.duration ) + ( s.partial ? " *" : "" ) )
	}

	bool any = file.names.len() > 0
	Hud_SetVisible( file.emptyLabel, !any )
	foreach ( string panel in [ "InfoBG", "InfoAccent", "InfoTitle", "DetailLabel" ] )
		Hud_SetVisible( Hud_GetChild( file.menu, panel ), any )
	Hud_SetText( file.countLabel, any ? Localize( "#DEMO_REPLAYS_COUNT", string( file.names.len() ) ) : "" )
	Hud_SetText( file.pageLabel, pageCount > 1 ? Localize( "#DEMO_REPLAYS_PAGE", string( file.page + 1 ), string( pageCount ) ) : "" )
	Hud_SetVisible( file.prevButton, pageCount > 1 )
	Hud_SetVisible( file.nextButton, pageCount > 1 )

	bool hasSel = Replays_HasSelection()
	Hud_SetVisible( file.play0, hasSel )
	Hud_SetVisible( file.play1, false )
	Hud_SetVisible( file.deleteButton, hasSel )

	if ( !hasSel )
	{
		Hud_SetText( file.infoTitle, "" )
		Hud_SetText( file.detail, any ? "#DEMO_REPLAYS_SELECT" : "" )
		return
	}

	string name = file.names[ file.selected ]
	ReplaySummary s = Replays_GetSummary( name )

	string result = Localize( "#DEMO_REPLAYS_RESULT_UNKNOWN" )
	if ( s.winner == 0 )
		result = Localize( "#DEMO_REPLAYS_RESULT_WON", s.pov0 )
	else if ( s.winner == 1 )
		result = Localize( "#DEMO_REPLAYS_RESULT_WON", s.pov1 )

	string title = Replays_Players( s )
	Hud_SetText( file.infoTitle, title != "" ? title : GetMapDisplayName( s.map ) )

	string detail = Localize( "#DEMO_REPLAYS_DETAIL", Replays_When( name ), GetMapDisplayName( s.map ), Replays_Length( s.duration ), result )
	string mode = Replays_Mode( s )
	if ( mode != "" )
		detail = Localize( "#DEMO_REPLAYS_DETAIL_MODE", mode ) + "\n" + detail
	if ( s.partial )
		detail += "\n\n" + Localize( "#DEMO_REPLAYS_PARTIAL" )
	Hud_SetText( file.detail, detail )

	RuiSetString( Hud_GetRui( file.play0 ), "buttonText", Localize( "#DEMO_REPLAYS_PLAY_AS", s.pov0 != "" ? s.pov0 : "1" ) )
	if ( s.povCount > 1 )
	{
		Hud_SetVisible( file.play1, true )
		RuiSetString( Hud_GetRui( file.play1 ), "buttonText", Localize( "#DEMO_REPLAYS_PLAY_AS", s.pov1 != "" ? s.pov1 : "2" ) )
	}
}

void function Replays_SetRowText( int row, string column, string text )
{
	Hud_SetText( Hud_GetChild( file.menu, column + row ), text )
}

void function Replays_Select( int idx )
{
	if ( file.names.len() == 0 )
		return
	file.selected = minint( maxint( idx, 0 ), file.names.len() - 1 )
	file.page = file.selected / REPLAYS_ROWS
	Replays_Render()
}

void function Replays_OnRowClick( var button )
{
	int idx = file.page * REPLAYS_ROWS + int( Hud_GetScriptID( button ) )
	if ( idx < 0 || idx >= file.names.len() )
		return
	Replays_Select( idx )
}

void function Replays_OnRowDoubleClick( var button )
{
	Replays_OnRowClick( button )
	Replays_Play( 0 )
}

void function Replays_OnKeyUp( var button )
{
	if ( GetActiveMenu() == file.menu )
		Replays_Select( file.selected - 1 )
}

void function Replays_OnKeyDown( var button )
{
	if ( GetActiveMenu() == file.menu )
		Replays_Select( file.selected + 1 )
}

void function Replays_OnPrev( var button )
{
	if ( file.page > 0 )
		Replays_Select( ( file.page - 1 ) * REPLAYS_ROWS )
}

void function Replays_OnNext( var button )
{
	if ( ( file.page + 1 ) * REPLAYS_ROWS < file.names.len() )
		Replays_Select( ( file.page + 1 ) * REPLAYS_ROWS )
}

void function Replays_Play( int pov )
{
	if ( !Replays_HasSelection() )
		return
	string name = file.names[ file.selected ]

	if ( !IsConnected() || Demo_IsPlaying() )
	{
		CloseAllMenus()
		Demo_PlayPov( name, pov )
		return
	}

	ConfirmDialogData data
	data.headerText = "#DEMO_REPLAYS_LEAVE_HEADER"
	data.messageText = "#DEMO_REPLAYS_LEAVE_CONFIRM"
	data.resultCallback = void function( int result ) : ( name, pov )
	{
		if ( result != eDialogResult.YES )
			return
		CloseAllMenus()
		Demo_PlayPov( name, pov )
	}
	OpenConfirmDialogFromData( data )
}

void function Replays_OnPlay0( var button )
{
	Replays_Play( 0 )
}

void function Replays_OnPlay1( var button )
{
	Replays_Play( 1 )
}

void function Replays_OnDelete( var button )
{
	if ( !Replays_HasSelection() )
		return
	string name = file.names[ file.selected ]

	ConfirmDialogData data
	data.headerText = "#DEMO_REPLAYS_DELETE"
	data.messageText = Localize( "#DEMO_REPLAYS_DELETE_CONFIRM", Replays_When( name ) )
	data.resultCallback = void function( int result ) : ( name )
	{
		if ( result != eDialogResult.YES )
			return
		int keep = file.selected
		Demo_DeleteFile( name )
		Replays_Refresh()
		Replays_Select( keep )
	}
	OpenConfirmDialogFromData( data )
}
