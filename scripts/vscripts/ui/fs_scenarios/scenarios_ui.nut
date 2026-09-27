// Flowstate Scenarios standings menu (mkos). Rows are keyed by FS_ScoreType:
// ScoreRow<N> shows points, TotalsRow<N> shows how many times it happened.

global function InitFSScenariosStandingsMenu
global function UI_FS_Scenarios_OpenStandings
global function UI_FS_Scenarios_SetStanding
global function UI_FS_Scenarios_StandingsReady

struct StandingRow
{
	int value
	int count
}

struct
{
	var menu
	var recapsPanel
	var lastFightButton
	var totalButton
	var scoreTitle

	table<int, StandingRow> total
	table<int, StandingRow> lastFight
	int shown = FS_SCENARIOS_STANDINGS_ROUND
	bool waitingForData = false
} file

void function InitFSScenariosStandingsMenu( var menu )
{
	file.menu = menu
	file.recapsPanel = Hud_GetChild( menu, "ScoreRecapsPanel" )
	file.scoreTitle = Hud_GetChild( menu, "StandingsRecapsTitle" )
	file.lastFightButton = Hud_GetChild( file.recapsPanel, "PreviousRoundButton" )
	file.totalButton = Hud_GetChild( file.recapsPanel, "AllRoundsButton" )

	AddButtonEventHandler( file.lastFightButton, UIE_CLICK, void function( var button ) : () { FS_Scenarios_ShowStandings( FS_SCENARIOS_STANDINGS_ROUND ) } )
	AddButtonEventHandler( file.totalButton, UIE_CLICK, void function( var button ) : () { FS_Scenarios_ShowStandings( FS_SCENARIOS_STANDINGS_TOTAL ) } )

	SetMenuReceivesCommands( menu, false )
	SetGamepadCursorEnabled( menu, true )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CLOSE", "#CLOSE", null )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, void function() : () { CloseActiveMenu() } )
}

void function UI_FS_Scenarios_OpenStandings()
{
	if ( !IsFullyConnected() || !CanRunClientScript() )
		return

	// Fresh numbers arrive in UI_FS_Scenarios_StandingsReady.
	file.waitingForData = true
	ClientCommand( "scenarios_standings" )

	if ( GetActiveMenu() != file.menu )
		AdvanceMenu( file.menu )
}

void function UI_FS_Scenarios_SetStanding( int standingType, int scoreType, int value, int count )
{
	StandingRow row
	row.value = value
	row.count = count

	if ( standingType == FS_SCENARIOS_STANDINGS_TOTAL )
		file.total[ scoreType ] <- row
	else if ( standingType == FS_SCENARIOS_STANDINGS_ROUND )
		file.lastFight[ scoreType ] <- row
}

void function UI_FS_Scenarios_StandingsReady()
{
	file.waitingForData = false
	FS_Scenarios_ShowStandings( file.shown )
}

void function FS_Scenarios_ShowStandings( int standingType )
{
	file.shown = standingType
	bool showTotal = standingType == FS_SCENARIOS_STANDINGS_TOTAL

	Hud_SetSelected( file.lastFightButton, !showTotal )
	Hud_SetSelected( file.totalButton, showTotal )
	HudElem_SetRuiArg( file.lastFightButton, "solidBackground", !showTotal )
	HudElem_SetRuiArg( file.totalButton, "solidBackground", showTotal )

	if ( file.waitingForData )
		return

	table<int, StandingRow> rows = showTotal ? file.total : file.lastFight
	for ( int scoreType = FS_ScoreType.PLAYERSCORE; scoreType <= FS_Scenarios_LastScoreType(); scoreType++ )
	{
		StandingRow row
		if ( scoreType in rows )
			row = rows[ scoreType ]

		if ( scoreType == FS_ScoreType.PLAYERSCORE )
		{
			Hud_SetText( file.scoreTitle, Localize( "#FS_SCORE" ) + ": " + string( row.value ) )
			continue
		}

		string scoreRow = "ScoreRow" + string( scoreType )
		if ( Hud_HasChild( file.recapsPanel, scoreRow ) )
			Hud_SetText( Hud_GetChild( file.recapsPanel, scoreRow ), string( row.value ) )

		string totalsRow = "TotalsRow" + string( scoreType )
		if ( Hud_HasChild( file.recapsPanel, totalsRow ) )
			Hud_SetText( Hud_GetChild( file.recapsPanel, totalsRow ), string( row.count ) )
	}
}
