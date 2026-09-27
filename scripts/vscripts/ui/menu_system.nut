global function InitSystemMenu
global function UpdateSystemMenu
global function OpenSystemMenu

global function ShouldDisplayOptInOptions
global function EnableCharacterChangeInFiringRange
global function SetFiringRangeChallengeInProgress
global function SetAimTrainerChallengeInProgress
global function IsOptInEnabled

#if DEVELOPER
global function ToggleOptIn
global function SetOptIn
#endif


global function RangeCustomizationMenu


struct ButtonData
{
	string             label
	void functionref() activateFunc
}

struct
{
	var menu

	array<var>        buttons
	array<ButtonData> buttonDatas

	ButtonData settingsButtonData
	ButtonData leaveMatchButtonData
	ButtonData endMatchButtonData
	ButtonData exitButtonData
	ButtonData lobbyReturnButtonData
	ButtonData nullButtonData
	ButtonData leavePartyData
	ButtonData leaveCustomMatchData
	ButtonData abandonMissionButtonData
	ButtonData changeCharacterButtonData
	ButtonData friendlyFireButtonData
	ButtonData leaveChallengButtoneData
	// Freeplay DevMenu / freeroam aim trainer timed challenge (not S21 FRC).
	ButtonData finishAimTrainerChallengeButtonData

		ButtonData rangeCustomizationButtonData

	ButtonData suicideButtonData

	ButtonData restButtonData
	ButtonData vsUiButtonData
	ButtonData oneVOneSettingsButtonData
	ButtonData leaderboardButtonData
	ButtonData scenariosStandingsButtonData

	bool enableChangeCharacterButton = true
	bool challengeInProgress = false
	bool aimTrainerChallengeInProgress = false

	InputDef& qaFooter
	bool isOptInEnabled = false
} file

void function InitSystemMenu( var newMenuArg ) 
{
	var menu = GetMenu( "SystemMenu" )
	Hud_SetAboveBlur( menu, true )
	file.menu = menu

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnSystemMenu_Open )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, OnSystemMenu_Close )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, OnSystemMenu_NavigateBack )


	file.buttons = GetElementsByClassname( menu, "SystemButtonClass" )
	file.buttonDatas.resize( file.buttons.len() )

	foreach ( index, button in file.buttons )
	{
		SetButtonData( index, file.nullButtonData )
		Hud_AddEventHandler( button, UIE_CLICK, OnButton_Activate )
	}

	file.settingsButtonData.label = "#SETTINGS"
	file.settingsButtonData.activateFunc = OpenSettingsMenu


		file.rangeCustomizationButtonData.label = "#BUTTON_RANGE_CUSTOMIZE"
		file.rangeCustomizationButtonData.activateFunc = RangeCustomizationMenu


	file.leaveMatchButtonData.label = "#QUIT_SERVER"
	file.leaveMatchButtonData.activateFunc = LeaveDialog

	file.endMatchButtonData.label = "#TOURNAMENT_END_MATCH"
	file.endMatchButtonData.activateFunc = EndMatchDialog

	file.exitButtonData.label = "#EXIT_TO_DESKTOP"
	file.exitButtonData.activateFunc = OpenConfirmExitToDesktopDialog

	file.lobbyReturnButtonData.label = "#QUIT_SERVER"
	file.lobbyReturnButtonData.activateFunc = LeaveDialog

	file.leavePartyData.label = "#LEAVE_PARTY"
	file.leavePartyData.activateFunc = LeavePartyDialog

	file.leaveCustomMatchData.label = "#CUSTOMMATCH_LEAVE"
	file.leaveCustomMatchData.activateFunc = LeaveCustomMatchDialog

	file.abandonMissionButtonData.label = "#QUIT_SERVER"
	file.abandonMissionButtonData.activateFunc = LeaveDialog

	file.changeCharacterButtonData.label = "#BUTTON_CHARACTER_CHANGE"
	file.changeCharacterButtonData.activateFunc = TryChangeCharacters

	file.leaveChallengButtoneData.label = "#LEAVE_CHALLENGE"
	file.leaveChallengButtoneData.activateFunc = TryLeaveChallenge

	// Freeplay aim trainer -- same string as Flowstate ESC finish.
	file.finishAimTrainerChallengeButtonData.label = "#FS_FINISH_CHALLENGE"
	file.finishAimTrainerChallengeButtonData.activateFunc = TryFinishAimTrainerChallenge

	file.friendlyFireButtonData.label = "#BUTTON_FRIENDLY_FIRE_TOGGLE"
	file.friendlyFireButtonData.activateFunc = ToggleFriendlyFire

	file.suicideButtonData.label = "#BUTTON_SUICIDE"
	file.suicideButtonData.activateFunc = TryRespawnAndChangeCharacters

	file.vsUiButtonData.label = "#FS_TOGGLE_VS_UI"
	file.vsUiButtonData.activateFunc = Toggle1v1Scoreboard_System

	file.restButtonData.label = "#FS_TOGGLE_REST"
	file.restButtonData.activateFunc = ToggleRest_1v1

	file.oneVOneSettingsButtonData.label = "#FS_1V1_SETTINGS"
	file.oneVOneSettingsButtonData.activateFunc = Open1v1Settings_System

	file.leaderboardButtonData.label = "#FS_TOGGLE_SCOREBOARD"
	file.leaderboardButtonData.activateFunc = OpenLeaderboard_System

	file.scenariosStandingsButtonData.label = "#FS_SCENARIOS_STANDINGS"
	file.scenariosStandingsButtonData.activateFunc = UI_FS_Scenarios_OpenStandings

	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	// DevMenu always registered; content gated by sv_cheats inside the menu.
	AddMenuFooterOption( menu, LEFT, BUTTON_Y, true, "#Y_BUTTON_DEV_MENU", "#DEV_MENU", OpenDevMenu )
	AddMenuFooterOption( menu, LEFT, KEY_M, true, "#Y_BUTTON_MODS", "#BRIDGE_MODS", OpenModsListDialog )
	AddMenuFooterOption( menu, LEFT, KEY_J, true, "", "#DEMO_FOOTER_REPLAYS", OpenReplaysMenu )
	if ( GetConVarBool( "cl_ezlaunch_button" ) )
		AddMenuFooterOption( menu, LEFT, BUTTON_Y, true, "EZ Launch", "EZ Launch", RunEZLaunch, ShouldDisplayOptInOptions )

	file.qaFooter = AddMenuFooterOption( menu, LEFT, BUTTON_X, true, "#X_BUTTON_QA", "QA", ToggleOptIn, ShouldDisplayOptInOptions )





		AddMenuFooterOption( menu, RIGHT, BUTTON_STICK_RIGHT, true, "#BUTTON_VIEW_CINEMATIC", "", ViewCinematic, IsLobby )
		AddMenuFooterOption( menu, RIGHT, KEY_V, true, "", "#BUTTON_VIEW_CINEMATIC", ViewCinematic, IsLobby )

		AddMenuFooterOption( menu, RIGHT, BUTTON_STICK_LEFT, true, "#BUTTON_VIEW_WELCOME_TRAILER", "", ViewWelcomeCinematic, IsLobby )
		AddMenuFooterOption( menu, RIGHT, KEY_B, true, "", "#BUTTON_VIEW_WELCOME_TRAILER", ViewWelcomeCinematic, IsLobby )


	AddMenuFooterOption( menu, RIGHT, BUTTON_BACK, true, "#BUTTON_RETURN_TO_MAIN", "", ReturnToMain_OnActivate, IsLobby )
	AddMenuFooterOption( menu, RIGHT, KEY_R, true, "", "#BUTTON_RETURN_TO_MAIN", ReturnToMain_OnActivate, IsLobby )
}


void function ViewWelcomeCinematic( var button )
{
	CloseActiveMenu()

	bool isEnglishLang = GetLanguage() == "english"

	VideoPlaySettings settings
	settings.video = isEnglishLang ? WELCOME_VIDEO : WELCOME_INT_VIDEO
	settings.milesAudio = WELCOME_AUDIO_EVENT
	settings.forceSubtitles = !isEnglishLang

	thread PlayVideoMenu( false, settings )
}

void function ViewCinematic( var button )
{
	CloseActiveMenu()

	VideoPlaySettings settings
	settings.video = INTRO_VIDEO
	settings.milesAudio = INTRO_AUDIO_EVENT
	settings.forceSubtitles = GetLanguage() != "english"

	thread PlayVideoMenu( false, settings )
}

void function TryChangeCharacters()
{
	if ( !file.enableChangeCharacterButton )
		return

	RunClientScript( "UICallback_OpenCharacterSelectMenu" )
}

void function TryLeaveChallenge()
{
	Remote_ServerCallFunction( "FRC_ClientToServer_TryLeaveChallenge" )
}

// ESC: finish freeplay aim trainer timed challenge (recap + stop freeroam/dummies).
void function TryFinishAimTrainerChallenge()
{
	if ( !file.aimTrainerChallengeInProgress )
		return

	CloseActiveMenu()
	Remote_ServerCallFunction( "AimTrainer_SV_FinishChallenge" )
	printt( "[AimTrainer] UI Finish Challenge" )
}

void function ToggleFriendlyFire()
{
	Remote_ServerCallFunction( "UCB_SV_FRSetting_FriendlyFire_Toggle" )
}


void function RangeCustomizationMenu()
{
	OpenSurvivalInventoryMenu( 2 )
}


void function TryRespawnAndChangeCharacters()
{
	RunClientScript( "UICallback_DieAndChangeCharacters" )
}

void function EnableCharacterChangeInFiringRange( bool enable )
{
	file.enableChangeCharacterButton = enable
	UpdateSystemMenu()
}

void function SetFiringRangeChallengeInProgress( bool isInProgress )
{
	file.challengeInProgress = isInProgress
}

// Client ChallengeStart/End drives this so ESC can offer Finish Challenge on freeplay.
// Must stay a plain global (RunUIScript lookup) in this UI file -- full client restart after edit.
void function SetAimTrainerChallengeInProgress( bool isInProgress )
{
	file.aimTrainerChallengeInProgress = isInProgress
	printt( format( "[AimTrainer] UI challengeInProgress=%s", string( isInProgress ) ) )
	// Refresh ESC if already open (safe even if menu not inited yet).
	if ( file.menu != null && GetActiveMenu() == file.menu )
		UpdateSystemMenu()
}

void function OnSystemMenu_Open()
{
	// Pull live freeplay challenge flag from client (UI VM may lag script reloads).
	try
	{
		RunClientScript( "AimTrainer_CL_PushChallengeFlagToUI" )
	}
	catch ( ePull )
	{
		printt( format( "[AimTrainer] UI open pull challenge flag failed: %s", string( ePull ) ) )
	}

	UpdateSystemMenu()
	SetBlurEnabled( true )

	UpdateOptInFooter()
	DevHud_Apply()
}

void function UpdateSystemMenu()
{
	foreach ( index, button in file.buttons )
		SetButtonData( index, file.nullButtonData )

	int buttonIndex = 0
	if ( IsConnected() && !IsLobby() )
	{
		
		SetCursorPosition( <1920.0 * 0.5, 1080.0 * 0.5, 0> )

		SetButtonData( buttonIndex++, file.settingsButtonData )

		if ( Flowstate_IsGame1v1Type() )
		{
			if ( FS_IsScenarios() )
				SetButtonData( buttonIndex++, file.scenariosStandingsButtonData )
			else
				SetButtonData( buttonIndex++, file.vsUiButtonData )
			SetButtonData( buttonIndex++, file.restButtonData )
			SetButtonData( buttonIndex++, file.oneVOneSettingsButtonData )
		}

		if ( FS_IsInstagib() )
			SetButtonData( buttonIndex++, file.leaderboardButtonData )

		// Freeplay aim trainer timed challenge (any map / mode -- not S21 FRC only).
		if ( file.aimTrainerChallengeInProgress )
			SetButtonData( buttonIndex++, file.finishAimTrainerChallengeButtonData )

		if ( GameModeVariant_IsActive( eGameModeVariants.SURVIVAL_FIRING_RANGE ) && !Flowstate_IsGame1v1Type() )
		{

				if ( FiringRangeHasInfiniteClips() )
					SetButtonData( buttonIndex++, file.rangeCustomizationButtonData )





			if ( file.enableChangeCharacterButton )
				SetButtonData( buttonIndex++, file.changeCharacterButtonData )

			if( file.challengeInProgress )
				SetButtonData( buttonIndex++, file.leaveChallengButtoneData )

		}

		int gameState = GetGameState()
		{
			if ( IsPVEMode() )
			{
				SetButtonData( buttonIndex++, file.abandonMissionButtonData )
			}
			else if ( GameModeVariant_IsActive( eGameModeVariants.SURVIVAL_TRAINING ) || GameModeVariant_IsActive( eGameModeVariants.SURVIVAL_FIRING_RANGE ) )
			{
				SetButtonData( buttonIndex++, file.lobbyReturnButtonData )
			}
			else if( !MenuStack_Contains( GetMenu( "CharacterSelectMenu" ) )

				&& !MenuStack_Contains( GetMenu( "SpecialCharacterSelectMenu" ) )

			)
			{
				SetButtonData( buttonIndex++, file.leaveMatchButtonData )
			}
		}


		bool playingOrSuddenDeath = ( gameState == eGameState.Playing )  || ( gameState == eGameState.SuddenDeath )
		if ( IsPrivateMatch() && HasMatchAdminRole() && playingOrSuddenDeath )
			SetButtonData( buttonIndex++, file.endMatchButtonData )


			if ( GameMode_IsActive( eGameModes.CONTROL ) && gameState == eGameState.Playing && GetTeam() != TEAM_UNASSIGNED && GetTeam() != TEAM_SPECTATOR )
				SetButtonData( buttonIndex++, file.suicideButtonData )

	}
	else
	{
		if ( AmIPartyMember() || AmIPartyLeader() && GetPartySize() > 1 )
			SetButtonData( buttonIndex++, file.leavePartyData )

		if ( MenuStack_Contains( GetMenu( "CustomMatchLobbyMenu" ) ) )
			SetButtonData( buttonIndex++, file.leaveCustomMatchData )

		SetButtonData( buttonIndex++, file.settingsButtonData )

			SetButtonData( buttonIndex++, file.exitButtonData )


		if ( IsPrivateMatchLobby() && !MenuStack_Contains( GetMenu( "CharacterSelectMenu" ) )

			&& !MenuStack_Contains( GetMenu( "SpecialCharacterSelectMenu" ) )

		)
			SetButtonData( buttonIndex++, file.leaveMatchButtonData )
	}

	int maxNumButtons = file.buttons.len()
	for( int i = 0; i < maxNumButtons; i++ )
	{
		if( i > 0 && i < buttonIndex)
			Hud_SetNavUp( file.buttons[i], file.buttons[i - 1] )
		else
			Hud_SetNavUp( file.buttons[i], file.buttons[ minint(maxNumButtons, buttonIndex) - 1 ] )

		if( i < (buttonIndex - 1) )
			Hud_SetNavDown( file.buttons[i], file.buttons[i + 1] )
		else
			Hud_SetNavDown( file.buttons[i], null )
	}

	var dataCenterElem = Hud_GetChild( file.menu, "DataCenter" )
	// Live connection SPING (engine NET_GetSPing) — not EA MyPing/datacenter.
	// Native TC reg still types as var on UI; cast for compile.
	int pingMs = expect int( GetConnectionPingMs() )
	Hud_SetText( dataCenterElem, format( "R5 Flowstate - %dms", pingMs ) )
}


void function SetButtonData( int buttonIndex, ButtonData buttonData )
{
	file.buttonDatas[buttonIndex] = buttonData

	var rui = Hud_GetRui( file.buttons[buttonIndex] )
	RHud_SetText( file.buttons[buttonIndex], buttonData.label )

	if ( buttonData.label == "" )
		Hud_SetVisible( file.buttons[buttonIndex], false )
	else
		Hud_SetVisible( file.buttons[buttonIndex], true )
}


void function OnSystemMenu_Close()
{
	DevHud_Apply()
}


void function OnSystemMenu_NavigateBack()
{
	Assert( GetActiveMenu() == file.menu )
	CloseActiveMenu()
}


void function OnButton_Activate( var button )
{
	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()

	int buttonIndex = int( Hud_GetScriptID( button ) )

	file.buttonDatas[buttonIndex].activateFunc()
}

void function OpenSystemMenu()
{
	AdvanceMenu( file.menu )
}

void function OpenSettingsMenu()
{
	AdvanceMenu( GetMenu( "MiscMenu" ) )
}

void function ToggleRest_1v1()
{
	ClientCommand( "rest" )
}

void function Toggle1v1Scoreboard_System()
{
	RunClientScript( "Toggle1v1Scoreboard" )
}

void function Open1v1Settings_System()
{
	FS_1v1_SettingsMenu_Open()
}

void function OpenLeaderboard_System()
{
	if ( CanRunClientScript() )
		RunClientScript( "FS_Hud_LeaderboardFromMenu" )
}


void function ReturnToMain_OnActivate( var button )
{
	ConfirmDialogData data
	data.headerText = "#EXIT_TO_MAIN"
	data.messageText = ""
	data.resultCallback = OnReturnToMainMenu
	

	OpenConfirmDialogFromData( data )
	AdvanceMenu( GetMenu( "ConfirmDialog" ) )
}

void function OnReturnToMainMenu( int result )
{
	if ( result == eDialogResult.YES )
	{
		LeaveMatch()
		ClientCommand( "disconnect" )
	}
}


void function ToggleOptIn( var button )
{
	file.isOptInEnabled = !file.isOptInEnabled

	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()
}

void function SetOptIn( bool state )
{
	file.isOptInEnabled = state
	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()
}

void function RunEZLaunch( var _ )
{
	ClientCommand( "ezlaunch" )

	CloseActiveMenu()
}

bool function ShouldDisplayOptInOptions()
{
	if ( !IsFullyConnected() )
		return false

	if ( GRX_IsInventoryReady() && (GRX_HasItem( GRX_DEV_ITEM ) || GRX_HasItem( GRX_QA_ITEM )) )
		return true

	return GetGlobalNetBool( "isOptInServer" )
}


void function UpdateOptInFooter()
{
	if ( file.isOptInEnabled )
	{
		file.qaFooter.gamepadLabel = "#X_BUTTON_HIDE_OPT_IN"
		file.qaFooter.mouseLabel = "#HIDE_OPT_IN"
	}
	else
	{
		file.qaFooter.gamepadLabel = "#X_BUTTON_SHOW_OPT_IN"
		file.qaFooter.mouseLabel = "#SHOW_OPT_IN"
	}

	UpdateFooterOptions()
}


bool function IsOptInEnabled()
{
	return file.isOptInEnabled
}