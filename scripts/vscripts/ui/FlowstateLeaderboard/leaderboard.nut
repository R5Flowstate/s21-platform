global function InitMatchLeaderboard
global function Init_LeaderboardScrollPanel

global function OpenMatchLeaderboard
global function CloseMatchLeaderboard
global function TryCloseMatchLeaderboard

global function Leaderboard_ReceivePlayerData
global function Leaderboard_SetMuted
global function Leaderboard_Refresh
global function Leaderboard_Clear
global function Leaderboard_SetGamemode
global function Leaderboard_SetRoundTimer
global function Leaderboard_SetPlayerStreak
global function Leaderboard_SetRoundEndMode
global function Leaderboard_SetTransitionLock
global function Leaderboard_SetCardData
global function Leaderboard_SetChallengePrompt
global function Leaderboard_SetChallengeInbox

const int LEADERBOARD_MAX_ROWS = 120

global struct LeaderboardEntry
{
	string name
	int score
	int kills
	int deaths
	float kd
	int damage
	int latency
	bool isLocal
	int winStreak = 0
	bool muted = false
	int input = -1  // 0 = MnK, 1 = controller, -1 = unknown
	bool hasCard = false
	int charGuid = 0
	int skinGuid = 0
	int frameGuid = 0
	int careerKills = -1
	int careerDeaths = -1
}

// Banner data arrives keyed by name because the row order is not settled until
// the refresh sorts and filters.
global struct LeaderboardCardData
{
	int charGuid = 0
	int skinGuid = 0
	int frameGuid = 0
	int careerKills = -1
	int careerDeaths = -1
}

struct
{
	var menu
	var scrollPanel
	var contentPanel

	array<LeaderboardEntry> players
	array<LeaderboardEntry> displayed
	table<var, int> muteButtonRow
	table<var, int> cardButtonRow
	table<string, LeaderboardCardData> cardData
	string cardOpenName = ""
	string currentGamemode = "dm"
	string roundTimerText = ""
	bool menuReady = false
	int lastPopulatedCount = 0
	int rowHeight = 0
	bool roundEndMode = false
	bool transitionLock = false
	bool rowButtonsBound = false
	int inputFilter = -1  // -1 = all, 0 = MnK only, 1 = controller only
	bool anyInputKnown = false
	string chalPrompt = ""
	int chalExtra = 0
	string chalOutgoing = ""
	string chalInbox0 = ""
	string chalInbox1 = ""
	string chalInbox2 = ""
} file

void function OnMuteButtonClick( var button )
{
	if ( !( button in file.muteButtonRow ) )
		return

	int row = file.muteButtonRow[button]
	if ( row < 0 || row >= file.displayed.len() )
		return

	LeaderboardEntry entry = file.displayed[row]
	if ( entry.isLocal || entry.name == "" )
		return

	if ( !CanRunClientScript() )
		return

	// Flip now so the click reads as one; the client answers either way and
	// Leaderboard_SetMuted reverts this if the mute did not take.
	entry.muted = !entry.muted
	UpdateMuteButton( row )

	RunClientScript( "FS_1v1_ToggleMuteByName", entry.name )
}

void function Leaderboard_SetMuted( string name, int muted )
{
	foreach ( LeaderboardEntry entry in file.players )
	{
		if ( entry.name != name )
			continue
		entry.muted = ( muted != 0 )
		break
	}
	for ( int i = 0; i < file.displayed.len(); i++ )
	{
		if ( file.displayed[i].name != name )
			continue
		UpdateMuteButton( i )
		break
	}
}

void function UpdateMuteButton( int rowIndex )
{
	if ( file.contentPanel == null )
		return

	var btn = Hud_GetChild( file.contentPanel, "Mute" + rowIndex.tostring() )
	if ( rowIndex < 0 || rowIndex >= file.displayed.len() )
	{
		Hud_SetVisible( btn, false )
		return
	}

	LeaderboardEntry entry = file.displayed[rowIndex]
	if ( entry.isLocal )
	{
		Hud_SetVisible( btn, false )
		return
	}

	Hud_SetVisible( btn, true )
	var rui = Hud_GetRui( btn )
	if ( rui != null )
		RuiSetBool( rui, "isMuted", entry.muted )

	ToolTipData tip
	tip.titleText = entry.muted ? "#UNMUTE" : "#MUTE"
	tip.tooltipStyle = eTooltipStyle.DEFAULT
	Hud_SetToolTipData( btn, tip )
}

void function BindRowButtons()
{
	if ( file.rowButtonsBound || file.contentPanel == null )
		return

	for ( int i = 0; i < LEADERBOARD_MAX_ROWS; i++ )
	{
		var btn = Hud_GetChild( file.contentPanel, "Mute" + i.tostring() )
		file.muteButtonRow[btn] <- i
		Hud_AddEventHandler( btn, UIE_CLICK, OnMuteButtonClick )

		// mute_button.rpak ships no art: isMuted only picks which of the two
		// image slots to draw. Only the unmuted slot is filled, so a muted row
		// draws no icon at all.
		var btnRui = Hud_GetRui( btn )
		RuiSetImage( btnRui, "unmuteIcon", $"rui/menu/lobby/speech_bubble_icon" )

		var cardBtn = Hud_GetChild( file.contentPanel, "Card" + i.tostring() )
		file.cardButtonRow[cardBtn] <- i
		Hud_AddEventHandler( cardBtn, UIE_CLICK, OnCardButtonClick )
		RuiSetImage( Hud_GetRui( cardBtn ), "unmuteIcon", $"rui/menu/buttons/battlepass/banner_frame" )
	}
	file.rowButtonsBound = true
}

// -----------------------------------------------------------------------
// Gladiator card overlay
// -----------------------------------------------------------------------

void function Leaderboard_SetCardData( string name, int charGuid, int skinGuid, int frameGuid, int careerKills, int careerDeaths )
{
	// No legend resolved server-side means there is nothing to draw a card from.
	if ( charGuid == 0 )
	{
		if ( name in file.cardData )
			delete file.cardData[name]
		return
	}

	LeaderboardCardData data
	data.charGuid = charGuid
	data.skinGuid = skinGuid
	data.frameGuid = frameGuid
	data.careerKills = careerKills
	data.careerDeaths = careerDeaths
	file.cardData[name] <- data
}

void function UpdateCardButton( int rowIndex )
{
	if ( file.contentPanel == null )
		return

	var btn = Hud_GetChild( file.contentPanel, "Card" + rowIndex.tostring() )
	if ( rowIndex < 0 || rowIndex >= file.displayed.len() )
	{
		Hud_SetVisible( btn, false )
		return
	}

	LeaderboardEntry entry = file.displayed[rowIndex]
	Hud_SetVisible( btn, entry.hasCard )
	if ( !entry.hasCard )
		return

	ToolTipData tip
	tip.titleText = "View banner"
	tip.tooltipStyle = eTooltipStyle.DEFAULT
	Hud_SetToolTipData( btn, tip )
}

void function OnCardButtonClick( var button )
{
	if ( !( button in file.cardButtonRow ) )
		return

	int row = file.cardButtonRow[button]
	if ( row < 0 || row >= file.displayed.len() )
		return

	LeaderboardEntry entry = file.displayed[row]
	if ( entry.name == "" )
		return

	if ( file.cardOpenName == entry.name )
	{
		ClosePlayerCard()
		return
	}

	OpenPlayerCard( entry )
}

void function OnChallengeButtonClick( var button )
{
	if ( file.cardOpenName == "" )
		return
	int ornull sep = file.cardOpenName.find( ";" )
	if ( sep != null )
		return

	if ( Leaderboard_NameIsIncoming( file.cardOpenName ) )
		ClientCommand( "challenge accept " + file.cardOpenName )
	else
		ClientCommand( "challenge chal " + file.cardOpenName )
}

void function OnDeclineButtonClick( var button )
{
	if ( file.cardOpenName == "" )
		return
	int ornull sep = file.cardOpenName.find( ";" )
	if ( sep != null )
		return

	ClientCommand( "challenge deny " + file.cardOpenName )
}

bool function Leaderboard_NameIsIncoming( string name )
{
	if ( name == "" )
		return false
	return name == file.chalInbox0 || name == file.chalInbox1 || name == file.chalInbox2
}

void function Leaderboard_SetButtonText( var button, string text )
{
	var rui = Hud_GetRui( button )
	if ( rui != null )
		RuiSetString( rui, "buttonText", text )
}

void function UpdateCardChallengeButtons()
{
	if ( file.menu == null )
		return

	var chalBtn = Hud_GetChild( file.menu, "CardChallengeBtn" )
	var denyBtn = Hud_GetChild( file.menu, "CardDeclineBtn" )

	if ( file.cardOpenName == "" || file.currentGamemode != "1v1" )
	{
		Hud_SetVisible( chalBtn, false )
		Hud_SetVisible( denyBtn, false )
		return
	}

	LeaderboardEntry entry
	bool found = false
	foreach ( LeaderboardEntry e in file.displayed )
	{
		if ( e.name != file.cardOpenName )
			continue
		entry = e
		found = true
		break
	}

	if ( !found || entry.isLocal )
	{
		Hud_SetVisible( chalBtn, false )
		Hud_SetVisible( denyBtn, false )
		return
	}

	Hud_SetVisible( chalBtn, true )

	if ( Leaderboard_NameIsIncoming( file.cardOpenName ) )
	{
		int pairX = ( Hud_GetWidth( chalBtn ) + 20 ) / 2
		Hud_SetX( chalBtn, -pairX )
		Hud_SetX( denyBtn, pairX )
		Leaderboard_SetButtonText( chalBtn, Localize( "#FS_Accept" ) )
		Hud_SetEnabled( chalBtn, true )
		Hud_SetVisible( denyBtn, true )
		Leaderboard_SetButtonText( denyBtn, Localize( "#FS_Decline" ) )
		Hud_SetEnabled( denyBtn, true )
		return
	}

	Hud_SetX( chalBtn, 0 )
	Hud_SetVisible( denyBtn, false )
	Leaderboard_SetButtonText( chalBtn, Localize( "#FS_Challenge_Player" ) )

	if ( file.chalOutgoing == file.cardOpenName )
		Hud_SetEnabled( chalBtn, false )
	else
		Hud_SetEnabled( chalBtn, true )
}

void function UpdateChallengeInboxLabel()
{
	if ( file.menu == null )
		return

	var sub = Hud_GetChild( file.menu, "TitleSubLabel" )
	if ( file.currentGamemode != "1v1" )
	{
		Hud_SetText( sub, "SORTED BY SCORE" )
		return
	}

	if ( file.chalInbox0 == "" )
	{
		Hud_SetText( sub, "SORTED BY KILLS" )
		return
	}

	string line = file.chalInbox0 + " CHALLENGED YOU"
	if ( file.chalExtra > 0 )
		line += "  +" + file.chalExtra.tostring()
	Hud_SetText( sub, line )
}

void function Leaderboard_SetChallengePrompt( string prompt, int extra, string outgoing )
{
	file.chalPrompt = prompt
	file.chalExtra = extra
	file.chalOutgoing = outgoing
	UpdateChallengeInboxLabel()
	UpdateCardChallengeButtons()
}

void function Leaderboard_SetChallengeInbox( string a, string b, string c )
{
	file.chalInbox0 = a
	file.chalInbox1 = b
	file.chalInbox2 = c
	UpdateChallengeInboxLabel()
	UpdateCardChallengeButtons()
	UpdateIncomingNameColors()
}

void function UpdateIncomingNameColors()
{
	if ( file.contentPanel == null )
		return

	int n = file.displayed.len()
	if ( n > LEADERBOARD_MAX_ROWS )
		n = LEADERBOARD_MAX_ROWS

	for ( int i = 0; i < n; i++ )
	{
		var nameLabel = Hud_GetChild( file.contentPanel, "Name" + i.tostring() )
		if ( Leaderboard_NameIsIncoming( file.displayed[i].name ) )
			Hud_SetColor( nameLabel, 232, 176, 72, 255 )
		else
			Hud_SetColor( nameLabel, 233, 241, 236, 255 )
	}
}

void function OnCardCatcherClick( var button )
{
	ClosePlayerCard()
}

void function OpenPlayerCard( LeaderboardEntry entry )
{
	if ( file.menu == null )
		return

	var cardPanel = Hud_GetChild( file.menu, "CardPanel" )
	file.cardOpenName = entry.name

	Hud_SetText( Hud_GetChild( file.menu, "CardStatsLine" ), FormatCardStatsLine( entry ) )
	SetCardChromeVisible( true )
	UpdateCardChallengeButtons()

	if ( CanRunClientScript() && entry.hasCard )
		RunClientScript( "FS_1v1_SetupLeaderboardGladCard", cardPanel, entry.name,
			entry.charGuid, entry.skinGuid, entry.frameGuid, entry.careerKills, entry.careerDeaths )
}

void function ClosePlayerCard()
{
	if ( file.cardOpenName == "" )
		return

	file.cardOpenName = ""
	SetCardChromeVisible( false )

	if ( CanRunClientScript() )
		RunClientScript( "FS_1v1_TeardownLeaderboardGladCard" )
}

void function SetCardChromeVisible( bool show )
{
	if ( file.menu == null )
		return

	array<string> chrome = [ "CardDim", "CardClickCatcher", "CardPanel", "CardStatsLine", "CardHint" ]
	foreach ( string child in chrome )
		Hud_SetVisible( Hud_GetChild( file.menu, child ), show )

	if ( !show )
	{
		Hud_SetVisible( Hud_GetChild( file.menu, "CardChallengeBtn" ), false )
		Hud_SetVisible( Hud_GetChild( file.menu, "CardDeclineBtn" ), false )
	}
}

string function FormatCardStatsLine( LeaderboardEntry entry )
{
	// 1v1 score is the kill count, so showing both reads as a duplicate. The
	// rating players are ranked on lives on the launcher and the website.
	if ( file.currentGamemode == "1v1" )
		return format( "THIS SESSION    KILLS %d    DEATHS %d    K/D %.2f    DAMAGE %d",
			entry.kills, entry.deaths, entry.kd, entry.damage )

	return format( "THIS SESSION    SCORE %d    KILLS %d    DEATHS %d    K/D %.2f    DAMAGE %d",
		entry.score, entry.kills, entry.deaths, entry.kd, entry.damage )
}

// -----------------------------------------------------------------------
// Init
// -----------------------------------------------------------------------

void function InitMatchLeaderboard( var newMenuArg )
{
	var menu = GetMenu( "FSLeaderboard" )
	file.menu = menu

	RegisterSignal( "LeaderboardRefresh" )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnLeaderboardOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, OnLeaderboardClose )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, OnLeaderboardNavBack )

	Hud_AddEventHandler( Hud_GetChild( menu, "CardClickCatcher" ), UIE_CLICK, OnCardCatcherClick )
	Hud_AddEventHandler( Hud_GetChild( menu, "CardChallengeBtn" ), UIE_CLICK, OnChallengeButtonClick )
	Hud_AddEventHandler( Hud_GetChild( menu, "CardDeclineBtn" ), UIE_CLICK, OnDeclineButtonClick )

	var mnkBtn = Hud_GetChild( menu, "FilterMnkBtn" )
	var ctrlBtn = Hud_GetChild( menu, "FilterCtrlBtn" )
	RuiSetImage( Hud_GetRui( mnkBtn ), "unmuteIcon", $"rui/flowstate_custom/input_mouse" )
	RuiSetImage( Hud_GetRui( ctrlBtn ), "unmuteIcon", $"rui/menu/crossplatform/controller" )
	ApplyLeaderboardModeBadge()
	Hud_AddEventHandler( mnkBtn, UIE_CLICK, OnFilterMnkClick )
	Hud_AddEventHandler( ctrlBtn, UIE_CLICK, OnFilterCtrlClick )

	SetMenuReceivesCommands( menu, false )
	SetGamepadCursorEnabled( menu, true )
}

void function OnFilterMnkClick( var button )
{
	SetInputFilter( file.inputFilter == 0 ? -1 : 0 )
}

void function OnFilterCtrlClick( var button )
{
	SetInputFilter( file.inputFilter == 1 ? -1 : 1 )
}

void function SetInputFilter( int filter )
{
	file.inputFilter = filter
	UpdateFilterButtons()
	if ( file.players.len() > 0 )
		Leaderboard_Refresh()
}

void function UpdateFilterButtons()
{
	if ( file.menu == null )
		return

	var mnkBtn = Hud_GetChild( file.menu, "FilterMnkBtn" )
	var ctrlBtn = Hud_GetChild( file.menu, "FilterCtrlBtn" )
	Hud_SetVisible( mnkBtn, file.anyInputKnown )
	Hud_SetVisible( ctrlBtn, file.anyInputKnown )
	Hud_SetVisible( Hud_GetChild( file.menu, "FilterBody" ), file.anyInputKnown )
	Hud_SetVisible( Hud_GetChild( file.menu, "FilterSplit" ), file.anyInputKnown )
	Hud_SetVisible( Hud_GetChild( file.menu, "FilterMnkActive" ), file.anyInputKnown && file.inputFilter == 0 )
	Hud_SetVisible( Hud_GetChild( file.menu, "FilterCtrlActive" ), file.anyInputKnown && file.inputFilter == 1 )

	ToolTipData mnkTip
	mnkTip.titleText = file.inputFilter == 0 ? "Show all players" : "Show mouse players only"
	mnkTip.tooltipStyle = eTooltipStyle.DEFAULT
	Hud_SetToolTipData( mnkBtn, mnkTip )

	ToolTipData ctrlTip
	ctrlTip.titleText = file.inputFilter == 1 ? "Show all players" : "Show controller players only"
	ctrlTip.tooltipStyle = eTooltipStyle.DEFAULT
	Hud_SetToolTipData( ctrlBtn, ctrlTip )
}

void function Init_LeaderboardScrollPanel( var panel )
{
	file.scrollPanel = panel
	file.contentPanel = Hud_GetChild( panel, "ContentPanel" )

	BindRowButtons()

	ScrollPanel_InitPanel( panel )
	ScrollPanel_InitScrollBar( panel, Hud_GetChild( panel, "ScrollBar" ) )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLeaderboardPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLeaderboardPanel_Hide )
}

// -----------------------------------------------------------------------
// Panel events
// -----------------------------------------------------------------------

void function OnLeaderboardPanel_Show( var panel )
{
	ScrollPanel_SetActive( panel, true )
	ScrollPanel_Refresh( panel )
}

void function OnLeaderboardPanel_Hide( var panel )
{
	ScrollPanel_SetActive( panel, false )
}

// -----------------------------------------------------------------------
// Open / Close
// -----------------------------------------------------------------------

void function OpenMatchLeaderboard()
{
	if ( file.menu == null )
		return

	if ( file.transitionLock && !file.roundEndMode )
		return

	// Already showing: CloseAllMenus would fire MENU_CLOSE and drop roundEndMode.
	if ( GetActiveMenu() == file.menu )
		return

	CloseAllMenus()
	AdvanceMenu( file.menu )
}

void function Leaderboard_SetTransitionLock( int on )
{
	file.transitionLock = ( on != 0 )
}

void function CloseMatchLeaderboard()
{
	file.roundEndMode = false
	CloseAllMenus()
}

void function TryCloseMatchLeaderboard()
{
	if ( file.roundEndMode )
		return
	CloseMatchLeaderboard()
}

// The board blurs only itself (ScreenBlur is the board-sized SDK RUI), so
// round-end mode needs no blur suppression: the podium is sharp either way.
void function Leaderboard_SetRoundEndMode( int on )
{
	file.roundEndMode = ( on != 0 )
}

// Three guesses at why the column headers do not draw have all been wrong, so
// report what the engine actually thinks their rects are.
void function DumpHeaderGeometry()
{
	array<string> names = [ "HeaderBand", "ColumnHeaderBG", "ColHeader_Rank", "ColHeader_Name",
		"ColHeader_1", "ColHeader_5", "ColHeader_Ping", "HeaderDivider", "FooterBG", "MainFrame" ]

	foreach ( string name in names )
	{
		var child = Hud_GetChild( file.menu, name )
		if ( child == null )
		{
			printt( "[LB-GEO] " + name + " MISSING" )
			continue
		}
		printt( "[LB-GEO] " + name
			+ " x=" + string( Hud_GetX( child ) ) + " y=" + string( Hud_GetY( child ) )
			+ " w=" + string( Hud_GetWidth( child ) ) + " h=" + string( Hud_GetHeight( child ) )
			+ " vis=" + string( Hud_IsVisible( child ) ) )
	}
}

void function OnLeaderboardOpen()
{
	SetBlurEnabled( false )
	DumpHeaderGeometry()
	ShowPanel( file.scrollPanel )
	file.menuReady = true
	ApplyLeaderboardModeBadge()
	UpdateChallengeInboxLabel()
	RegisterButtonPressedCallback( KEY_M, OnLeaderboardToggleKey )
}

void function OnLeaderboardClose()
{
	ClosePlayerCard()
	DeregisterButtonPressedCallback( KEY_M, OnLeaderboardToggleKey )
	file.roundEndMode = false
	SetBlurEnabled( false )

	// Client owns the open flag; clear it on any UI close path (X, B/back, CloseAllMenus).
	// The duel modes keep their own handler -- they also tell the server the board closed.
	if ( CanRunClientScript() )
	{
		if ( Flowstate_IsGame1v1Type() )
			RunClientScript( "FS_1v1_OnFullScoreboardClosed" )
		else
			RunClientScript( "FS_Hud_LeaderboardClosedFromUI" )
	}
}

void function OnLeaderboardToggleKey( var unused )
{
	if ( file.cardOpenName != "" )
	{
		ClosePlayerCard()
		return
	}
	TryCloseMatchLeaderboard()
}

void function OnLeaderboardNavBack()
{
	if ( file.cardOpenName != "" )
	{
		ClosePlayerCard()
		return
	}
	TryCloseMatchLeaderboard()
}

// -----------------------------------------------------------------------
// Data reception
// -----------------------------------------------------------------------

void function Leaderboard_ReceivePlayerData( string name, int score, int kills, int deaths, float kd, int damage, int latency, int isLocal, int muted = 0, int input = -1 )
{
	LeaderboardEntry entry
	entry.name = name
	entry.score = score
	entry.kills = kills
	entry.deaths = deaths
	entry.kd = kd
	entry.damage = damage
	// Your own row shows the same live ping as the pause menu.
	entry.latency = ( isLocal == 1 ) ? expect int( GetConnectionPingMs() ) : latency
	entry.isLocal = ( isLocal == 1 )
	entry.muted = ( muted != 0 )
	entry.input = input

	file.players.append( entry )
}

void function Leaderboard_Clear()
{
	file.players.clear()
	file.displayed.clear()
	file.cardData.clear()
	file.roundTimerText = ""
}

void function Leaderboard_SetRoundTimer( string timerText )
{
	file.roundTimerText = timerText
}

void function Leaderboard_SetPlayerStreak( string playerName, int winStreak )
{
	// Find matching player entry and set their streak
	for ( int i = file.players.len() - 1; i >= 0; i-- )
	{
		if ( file.players[i].name == playerName )
		{
			file.players[i].winStreak = winStreak
			break
		}
	}
}

// -----------------------------------------------------------------------
// Gamemode column configuration
// -----------------------------------------------------------------------

asset function GetLeaderboardModeBadge( string gamemode )
{
	switch ( gamemode )
	{
		case "1v1":
			return $"rui/flowstatecustom/1v1"
		case "instagib":
			return $"rui/flowstatecustom/cafesinstagib"
	}

	return $"rui/flowstatecustom/dm"
}

void function ApplyLeaderboardModeBadge()
{
	if ( file.menu == null )
		return

	RuiSetImage( Hud_GetRui( Hud_GetChild( file.menu, "TitleBadge" ) ), "basicImage", GetLeaderboardModeBadge( file.currentGamemode ) )
}

void function Leaderboard_SetGamemode( string gamemode )
{
	file.currentGamemode = gamemode
	ApplyLeaderboardModeBadge()
	UpdateChallengeInboxLabel()

	if ( !file.menuReady )
		return

	// Update column header labels
	array<string> colNames = GetColumnsForGamemode( gamemode )
	for ( int i = 0; i < colNames.len() && i < 5; i++ )
	{
		var header = Hud_GetChild( file.menu, "ColHeader_" + ( i + 1 ) )
		Hud_SetText( header, colNames[i] )
		Hud_SetVisible( header, colNames[i] != "" )
	}
}

array<string> function GetColumnsForGamemode( string gamemode )
{
	switch ( gamemode )
	{
		case "1v1":
			return [ "KILLS", "DEATHS", "DAMAGE", "K/D", "" ]
		case "dm":
		case "tdm":
			return [ "SCORE", "KILLS", "DEATHS", "K/D", "DAMAGE" ]
		case "scenarios":
			return [ "SCORE", "KILLS", "DEATHS", "DOWNS", "WIPES" ]
		case "prophunt":
			return [ "SURVIVED", "SURV. TIME", "", "", "" ]
		case "snd":
			return [ "SCORE", "KILLS", "DEATHS", "PLANTS", "DEFUSES" ]
		case "infection":
			return [ "SCORE", "KILLS", "DEATHS", "K/D", "SURVIVED" ]
	}

	return [ "SCORE", "KILLS", "DEATHS", "K/D", "DAMAGE" ]
}

// Which entry field each column slot renders. Slot 4 owns the colour-coded K/D
// label in the layout, so a gamemode showing K/D has to keep it there.
array<string> function GetColumnSourcesForGamemode( string gamemode )
{
	switch ( gamemode )
	{
		case "1v1":
			return [ "kills", "deaths", "damage", "kd", "" ]
	}

	return [ "score", "kills", "deaths", "kd", "damage" ]
}

string function GetColumnText( string source, LeaderboardEntry entry )
{
	switch ( source )
	{
		case "score":
			return entry.score.tostring()
		case "kills":
			return entry.kills.tostring()
		case "deaths":
			return entry.deaths.tostring()
		case "kd":
			return FormatCol4Value( entry.kd )
		case "damage":
			return entry.damage.tostring()
	}

	return ""
}

// -----------------------------------------------------------------------
// Refresh - sort and populate all rows
// -----------------------------------------------------------------------

void function Leaderboard_Refresh()
{
	thread Leaderboard_RefreshThread()
}

void function Leaderboard_RefreshThread()
{
	// Every push spawns one of these and each yields mid-populate, so without a
	// cancel the threads interleave: one fills rows the next is still hiding.
	Signal( uiGlobal.signalDummy, "LeaderboardRefresh" )
	EndSignal( uiGlobal.signalDummy, "LeaderboardRefresh" )

	if ( file.contentPanel == null || file.menu == null )
		return

	// Wait for menu to be ready (shown at least once)
	while ( !file.menuReady )
		WaitFrame()

	// Defensive: wait for data if server sends refresh before all data arrives
	while ( file.players.len() == 0 )
		WaitFrame()

	file.players.sort( CompareLeaderboardEntries )

	file.anyInputKnown = false
	foreach ( LeaderboardEntry entry in file.players )
	{
		if ( entry.input != -1 )
		{
			file.anyInputKnown = true
			break
		}
	}
	UpdateFilterButtons()

	file.displayed.clear()
	foreach ( LeaderboardEntry entry in file.players )
	{
		entry.hasCard = ( entry.name in file.cardData )
		if ( entry.hasCard )
		{
			LeaderboardCardData data = file.cardData[entry.name]
			entry.charGuid = data.charGuid
			entry.skinGuid = data.skinGuid
			entry.frameGuid = data.frameGuid
			entry.careerKills = data.careerKills
			entry.careerDeaths = data.careerDeaths
		}
		if ( file.inputFilter == -1 || entry.input == file.inputFilter )
			file.displayed.append( entry )
	}

	// A card whose player left mid-view has nothing left to draw.
	if ( file.cardOpenName != "" && !( file.cardOpenName in file.cardData ) )
		ClosePlayerCard()

	int playerCount = file.displayed.len()
	if ( playerCount > LEADERBOARD_MAX_ROWS )
		playerCount = LEADERBOARD_MAX_ROWS
	Hud_SetText( Hud_GetChild( file.menu, "PlayerCountNum" ), playerCount.tostring() )

	array<string> colConfig = GetColumnsForGamemode( file.currentGamemode )
	for ( int c = 0; c < colConfig.len() && c < 5; c++ )
	{
		var header = Hud_GetChild( file.menu, "ColHeader_" + ( c + 1 ) )
		Hud_SetText( header, colConfig[c] )
		Hud_SetVisible( header, colConfig[c] != "" )
	}

	for ( int i = 0; i < playerCount; i++ )
	{
		LeaderboardEntry entry = file.displayed[i]
		PopulateRow( i, entry, colConfig )

		if ( file.rowHeight <= 0 && i == 0 )
		{
			file.rowHeight = Hud_GetHeight( Hud_GetChild( file.contentPanel, "RowBG0" ) )
			if ( file.rowHeight <= 0 )
				file.rowHeight = Hud_GetBaseHeight( Hud_GetChild( file.contentPanel, "RowBG0" ) )
			if ( file.rowHeight <= 0 )
				file.rowHeight = 38
		}
	}

	// Unused rows stay tall in the pin chain unless collapsed.
	int collapseTo = playerCount
	if ( file.lastPopulatedCount == 0 )
		collapseTo = LEADERBOARD_MAX_ROWS
	else if ( playerCount < file.lastPopulatedCount )
		collapseTo = file.lastPopulatedCount
	for ( int i = playerCount; i < collapseTo; i++ )
		HideRow( i )
	file.lastPopulatedCount = playerCount

	Hud_SetHeight( file.contentPanel, playerCount * file.rowHeight )
	WaitFrame()
	if ( file.scrollPanel != null )
		ScrollPanel_Refresh( file.scrollPanel )
}

// -----------------------------------------------------------------------
// Row population helpers
// -----------------------------------------------------------------------

void function PopulateRow( int rowIndex, LeaderboardEntry entry, array<string> colConfig )
{
	string idx = rowIndex.tostring()

	if ( file.rowHeight > 0 )
		SetRowHeights( rowIndex, file.rowHeight )

	Hud_SetVisible( Hud_GetChild( file.contentPanel, "RowBG" + idx ), true )

	// Only the first three rows carry a medal edge; its colour is baked per row.
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "PodiumAccent" + idx ), rowIndex < 3 )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "HighlightBG" + idx ), entry.isLocal )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "RowSep" + idx ), true )

	var rankLabel = Hud_GetChild( file.contentPanel, "Rank" + idx )
	Hud_SetText( rankLabel, ( rowIndex + 1 ).tostring() )
	array<int> rankCol = GetRankColor( rowIndex )
	Hud_SetColor( rankLabel, rankCol[0], rankCol[1], rankCol[2], rankCol[3] )
	Hud_SetVisible( rankLabel, true )

	var nameLabel = Hud_GetChild( file.contentPanel, "Name" + idx )
	Hud_SetText( nameLabel, entry.name )
	Hud_SetVisible( nameLabel, true )
	if ( Leaderboard_NameIsIncoming( entry.name ) )
		Hud_SetColor( nameLabel, 232, 176, 72, 255 )
	else
		Hud_SetColor( nameLabel, 233, 241, 236, 255 )

	array<string> colSources = GetColumnSourcesForGamemode( file.currentGamemode )
	var kdColor = Hud_GetChild( file.contentPanel, "KDColor" + idx )
	bool colorKD = false

	for ( int c = 0; c < 5; c++ )
	{
		var col = Hud_GetChild( file.contentPanel, "Col" + ( c + 1 ) + "_" + idx )
		bool shown = colConfig[c] != ""

		if ( shown && colSources[c] == "kd" && IsKDGamemode( file.currentGamemode ) )
		{
			// The colour-coded label replaces the plain one in this slot.
			Hud_SetVisible( col, false )
			Hud_SetText( kdColor, format( "%.2f", entry.kd ) )
			array<int> kdCol = GetKDColor( entry.kd, entry.kills + entry.deaths > 0 )
			Hud_SetColor( kdColor, kdCol[0], kdCol[1], kdCol[2], kdCol[3] )
			Hud_SetVisible( kdColor, true )
			colorKD = true
			continue
		}

		Hud_SetText( col, GetColumnText( colSources[c], entry ) )
		Hud_SetVisible( col, shown )
	}

	if ( !colorKD )
		Hud_SetVisible( kdColor, false )

	var pingLabel = Hud_GetChild( file.contentPanel, "Ping" + idx )
	Hud_SetText( pingLabel, entry.latency.tostring() + "ms" )
	array<int> pingCol = GetPingColor( entry.latency )
	Hud_SetColor( pingLabel, pingCol[0], pingCol[1], pingCol[2], pingCol[3] )
	Hud_SetVisible( pingLabel, true )

	var inputIcon = Hud_GetChild( file.contentPanel, "Input" + idx )
	if ( entry.input != -1 )
	{
		RuiSetImage( Hud_GetRui( inputIcon ), "basicImage", InputIconAsset( entry.input ) )
		Hud_SetVisible( inputIcon, true )
	}
	else
	{
		Hud_SetVisible( inputIcon, false )
	}

	UpdateMuteButton( rowIndex )
	UpdateCardButton( rowIndex )
}

asset function InputIconAsset( int input )
{
	return input == 1 ? $"rui/menu/crossplatform/controller" : $"rui/flowstate_custom/input_mouse"
}

void function HideRow( int rowIndex )
{
	string idx = rowIndex.tostring()
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "RowBG" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "PodiumAccent" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "HighlightBG" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "RowSep" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Rank" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Name" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Col1_" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Col2_" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Col3_" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Col4_" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Col5_" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "KDColor" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Ping" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Mute" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Input" + idx ), false )
	Hud_SetVisible( Hud_GetChild( file.contentPanel, "Card" + idx ), false )
	SetRowHeights( rowIndex, 0 )
}

void function SetRowHeights( int rowIndex, int height )
{
	string idx = rowIndex.tostring()
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "RowBG" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "PodiumAccent" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "HighlightBG" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Rank" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Name" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Col1_" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Col2_" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Col3_" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Col4_" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Col5_" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "KDColor" + idx ), height )
	Hud_SetHeight( Hud_GetChild( file.contentPanel, "Ping" + idx ), height )
	// Icon button stays square and inset inside the row band.
	var mute = Hud_GetChild( file.contentPanel, "Mute" + idx )
	int muteSize = height > 8 ? height - 8 : 0
	Hud_SetHeight( mute, muteSize )
	Hud_SetWidth( mute, muteSize )
	var card = Hud_GetChild( file.contentPanel, "Card" + idx )
	Hud_SetHeight( card, muteSize )
	Hud_SetWidth( card, muteSize )
	var inputIcon = Hud_GetChild( file.contentPanel, "Input" + idx )
	int iconH = height > 14 ? height - 14 : 0
	Hud_SetHeight( inputIcon, iconH )
	Hud_SetWidth( inputIcon, iconH + iconH / 3 )
}

// -----------------------------------------------------------------------
// Sort + formatting
// -----------------------------------------------------------------------

int function CompareLeaderboardEntries( LeaderboardEntry a, LeaderboardEntry b )
{
	if ( a.score < b.score ) return 1
	else if ( a.score > b.score ) return -1

	// Tiebreaker: more kills first
	if ( a.kills < b.kills ) return 1
	else if ( a.kills > b.kills ) return -1

	return 0
}

string function FormatCol4Value( float value )
{
	// For K/D ratio gamemodes, show 2 decimal places
	// For integer-based gamemodes (plants, downs), show as integer
	switch ( file.currentGamemode )
	{
		case "dm":
		case "tdm":
		case "1v1":
		case "infection":
			return format( "%.2f", value )
	}

	return int( value ).tostring()
}

bool function IsKDGamemode( string gamemode )
{
	switch ( gamemode )
	{
		case "dm":
		case "tdm":
		case "1v1":
		case "infection":
			return true
	}
	return false
}

array<int> function GetKDColor( float kd, bool hasPlayed )
{
	// A player who has neither killed nor died reads as neutral, not as a 0.00 loss.
	if ( !hasPlayed )
		return [ 122, 134, 127, 255 ]
	if ( kd >= 3.0 )
		return [ 61, 218, 138, 255 ]
	if ( kd >= 1.5 )
		return [ 240, 206, 90, 255 ]
	if ( kd >= 1.0 )
		return [ 233, 241, 236, 255 ]
	return [ 226, 92, 92, 255 ]
}

array<int> function GetPingColor( int latency )
{
	if ( latency <= 0 )
		return [ 122, 134, 127, 255 ]
	if ( latency < 70 )
		return [ 61, 218, 138, 255 ]
	if ( latency < 140 )
		return [ 240, 206, 90, 255 ]
	return [ 226, 92, 92, 255 ]
}

array<int> function GetRankColor( int rowIndex )
{
	switch ( rowIndex )
	{
		case 0:
			return [ 242, 194, 48, 255 ]
		case 1:
			return [ 201, 209, 204, 255 ]
		case 2:
			return [ 201, 138, 75, 255 ]
	}
	return [ 169, 184, 175, 255 ]
}
