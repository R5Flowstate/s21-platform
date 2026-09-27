
global function InitMainMenuPanel
global function StartSearchForPartyServer
global function StopSearchForPartyServer
global function IsSearchingForPartyServer
global function SetLaunchState
global function PrelaunchValidateAndLaunch
global function Bridge_SetAuthMessage

global function IsCrossProgressing
global function UICodeCallback_XProgCheckRolloutRequestFinished
global function UICodeCallback_XProgMigrateRequestFinished
global function UICodeCallback_XProgMigrateStatusRequestFinished
global function UICodeCallback_XProgMigrateFlowFailed
global function UICodeCallback_XProgMigrateNotificationRequestFinished
global function UI_CrossProgression_DoMigrateFlow

global function UICodeCallback_GetOnPartyServer













#if DEVELOPER
global function DEV_ToggleRuiIssuesDemo
#endif

const bool SPINNER_DEBUG_INFO = PC_PROG

const int MIGRATE_DEFAULT_RETRY_MINUTES = 180
const float REAUTH_REQUEST_TIMEOUT = 10.0

struct
{
	var                menu
	var                panel
	var                status
	var                launchButton
	void functionref() launchButtonActivateFunc = null
	var                statusDetails
	bool               statusDetailsVisiblity = false
	
	bool               working = false
	bool               searching = false
	bool               crossProgressing = false
	bool			   hasReconnectFile = false
	bool               isNucleusProcessActive = false
	var				   serverSearchMessage
	var				   serverSearchError
	var				   bridgeAuthMessage = null
	bool				needsEAAccountRegistration = false

	bool xProgCheckRolloutRequestFinished = false
	bool xProgCheckNotificationRequestFinished = false
	bool xProgRequestMigrateFinished = false
	bool xProgMigrateDoneWithMTXData = false
	bool xProgMigrateFailed = false





	float startTime = 0
} file

#if SPINNER_DEBUG_INFO
void function SetSpinnerDebugInfo( string message )
{
	if ( GetConVarBool( "spinner_debug_info" ) )
	{
		Assert( file.working )
		SetLaunchState( eLaunchState.WORKING, message )
	}
}
#endif

void function InitMainMenuPanel( var panel )
{
	RegisterSignal( "EndPrelaunchValidation" )
	RegisterSignal( "EndSearchForPartyServerTimeout" )
	RegisterSignal( "EndSetMainProfileForCrossProgressionTimeout" )
	RegisterSignal( "EndMigrateFlow" )
	RegisterSignal( "SetLaunchState" )
	RegisterSignal( "MainMenu_Think" )

	file.panel = GetPanel( "MainMenuPanel" )
	file.menu = GetParentMenu( file.panel )

#if DEVELOPER
	AddMenuThinkFunc( file.menu, MainMenuPanelAutomationThink )
#endif

	AddPanelEventHandler( file.panel, eUIEvent.PANEL_SHOW, OnMainMenuPanel_Show )
	AddPanelEventHandler( file.panel, eUIEvent.PANEL_HIDE, OnMainMenuPanel_Hide )

	file.launchButton = Hud_GetChild( panel, "LaunchButton" )
	Hud_AddEventHandler( file.launchButton, UIE_CLICK, LaunchButton_OnActivate )

	file.status = Hud_GetRui( Hud_GetChild( panel, "Status" ) )
	file.statusDetails = Hud_GetRui( Hud_GetChild( file.panel, "StatusDetails" ) )
	file.serverSearchMessage = Hud_GetChild( file.panel, "ServerSearchMessage" )
	file.serverSearchError = Hud_GetChild( file.panel, "ServerSearchError" )

	// Optional: it comes from a loose layout file, and Hud_GetChild throws rather
	// than returning null when an element is absent, which would take the menu down
	// at boot. Absent simply means no message line.
	if ( Hud_HasChild( file.panel, "BridgeAuthMessage" ) )
		file.bridgeAuthMessage = Hud_GetChild( file.panel, "BridgeAuthMessage" )









	

#if DEVELOPER
		if ( GetBugReproNum() == 233677 )
		{
			AddPanelFooterOption( panel, LEFT, BUTTON_Y, true, "", "" )
			var footerButtons = Hud_GetChild( file.menu, "FooterButtons" )
			var leftRuiFooterButton0 = Hud_GetChild( footerButtons, "LeftRuiFooterButton0" )
			thread DEV_TestFooterTextWidths( leftRuiFooterButton0 )
		}
#endif


		AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_EXIT_TO_DESKTOP", "#B_BUTTON_EXIT_TO_DESKTOP", null, IsExitToDesktopFooterValid )

	AddPanelFooterOption( panel, LEFT, KEY_TAB, true, "#MAINMENU_CONNECT_LOCALHOST", "#MAINMENU_CONNECT_LOCALHOST", ConnectFooter_OnActivate, IsConnectFooterValid )
	AddPanelFooterOption( panel, LEFT, BUTTON_SHOULDER_RIGHT, true, "#MAINMENU_CONNECT_LOCALHOST", "", ConnectFooter_OnActivate, IsConnectFooterValid )

	AddPanelFooterOption( panel, LEFT, BUTTON_Y, true, "#BUTTON_REVIEW_TERMS", "#REVIEW_TERMS", OpenEULAReviewFromFooter, IsExitToDesktopFooterValid )
	AddPanelFooterOption( panel, LEFT, KEY_J, true, "", "#DEMO_FOOTER_REPLAYS", OpenReplaysMenu )


	file.hasReconnectFile = TryLoadReconnectFromLocalStorage()

		AddPanelFooterOption( panel, LEFT, KEY_Q, true, "", "#BUTTON_RETRY_CONNECT", RetryConnect_OnActivate, IsRetryConnectFooterValid )

	AddPanelFooterOption( panel, LEFT, BUTTON_X, true, "#BUTTON_RETRY_CONNECT", "", RetryConnect_OnActivate, IsRetryConnectFooterValid )

	AddPanelFooterOption( panel, LEFT, BUTTON_START, true, "#START_BUTTON_ACCESSIBLITY", "#BUTTON_ACCESSIBLITY", Accessibility_OnActivate, IsAccessibilityFooterValid )





}

#if DEVELOPER
void function MainMenuPanelAutomationThink( var menu )
{
	if (AutomateUi())
	{
		printt("MainMenuPanelAutomationThink LaunchButton_OnActivate()")
		LaunchButton_OnActivate(null)
	}
}
#endif

void function RetryConnect_OnActivate( var button )
{
	if ( IsRetryConnectFooterValid() )
	{
		EnableAutoRetryConnect()
		PrelaunchValidateAndLaunch()
	}
}

bool function IsRetryConnectFooterValid()
{
	return !IsWorking() && !IsSearchingForPartyServer() && !IsCrossProgressing() && file.hasReconnectFile && !CanAutoRetryConnect()
}

bool function IsConnectFooterValid()
{
	return !IsWorking() && !IsSearchingForPartyServer() && !IsCrossProgressing()
}

void function ConnectFooter_OnActivate( var button )
{
	if ( !IsConnectFooterValid() )
		return

	OpenBridgeConnectDialog()
}

void function MainMenuLaunch_OpenServerBrowser()
{
	OpenMainMenuServerBrowser( null )
}


void function OpenEULAReviewFromFooter( var button )
{
	OpenEULADialog( true )
}

bool function IsExitToDesktopFooterValid()
{
	return !IsWorking() && !IsSearchingForPartyServer() && !IsCrossProgressing()
}



bool function IsAccessibilityFooterValid()
{
	if ( !IsAccessibilityAvailable() )
		return false




		return !IsWorking() && !IsSearchingForPartyServer() && !IsCrossProgressing()

}






void function OnMainMenuPanel_Show( var panel )
{

	file.startTime = UITime()

	AccessibilityHintReset()
	EnterLobbySurveyReset()

	thread MainMenu_Think()

	thread PrelaunchValidation( false )
	thread Bridge_MaybeShowFirstTimeEULA()

	ExecCurrentGamepadButtonConfig()
	ExecCurrentGamepadStickConfig()
}

void function MainMenu_Think()
{
	Signal( uiGlobal.signalDummy, "MainMenu_Think" )
	EndSignal( uiGlobal.signalDummy, "MainMenu_Think" )

	while ( true )
	{
		
#if DEVELOPER
		    if ( GetBugReproNum() != 233677 )
#endif
		UpdateFooterOptions()

		WaitFrame()
	}
}


void function PrelaunchValidateAndLaunch()
{
	Bridge_MainMenuContinue()
}

// Empty hides it. Null-safe: the element is optional, so every caller can just
// say what it wants shown without checking first.
void function Bridge_SetAuthMessage( string message )
{
	if ( file.bridgeAuthMessage == null )
		return

	Hud_SetText( file.bridgeAuthMessage, message )
	Hud_SetVisible( file.bridgeAuthMessage, message != "" )
}

void function PrelaunchValidation( bool autoContinue = false )
{
	EndSignal( uiGlobal.signalDummy, "EndPrelaunchValidation" )

	// A server verifies the account before admitting anyone, and the proof arrives
	// a second or two after launch. WORKING hides the launch button and shows the
	// spinner, so there is no window in which the player can start something that
	// would only be refused.
	if ( !Bridge_IsIdentityReady() )
	{
		// Its own line under the spinner. The prompt slot belongs to the launch
		// action, above the spinner is already occupied, and the details line at the
		// bottom of the screen is too far away to read as an explanation of it.
		SetLaunchState( eLaunchState.WORKING, "", "" )
		Bridge_SetAuthMessage( Localize( "#BRIDGE_SIGNING_IN" ) )

		bool warnedSlow = false

		while ( !Bridge_IsIdentityReady() )
		{
			// Say so once it is overdue. The wait is the same either way, but a
			// spinner that never explains itself is where a player decides the
			// game has hung.
			if ( !warnedSlow && GetPlatformIdentityState() == ePlatformIdentity.SLOW )
			{
				Bridge_SetAuthMessage( Localize( "#BRIDGE_SIGNING_IN_SLOW" ) )
				warnedSlow = true
			}

			WaitFrame()
		}

		Bridge_SetAuthMessage( "" )
	}

	SetLaunchState( eLaunchState.WAIT_TO_CONTINUE, "", Localize( "#MAINMENU_BROWSE_SERVERS" ) )
	if ( autoContinue )
		Bridge_MainMenuContinue()
}

void function OnMainMenuPanel_Hide( var panel )
{
	Signal( uiGlobal.signalDummy, "MainMenu_Think" )
	Signal( uiGlobal.signalDummy, "EndPrelaunchValidation" )
	Bridge_SetAuthMessage( "" )
	file.working = false
	file.searching = false
	file.crossProgressing = false



}


void function SetLaunchState( int launchState, string details = "", string prompt = "" )
{
	printt( "*** SetLaunchState *** launchState: " + GetEnumString( "eLaunchState", launchState ) + " details: \"" + details + "\" prompt: \"" + prompt + "\"" )

	if ( launchState == eLaunchState.WAIT_TO_CONTINUE )
	{
		printt( "*** Setting LaunchButton_OnActivate ***  MainMenuLaunch_OpenServerBrowser")
		file.launchButtonActivateFunc = MainMenuLaunch_OpenServerBrowser
		AccessibilityHint( eAccessibilityHint.LAUNCH_TO_LOBBY )
	}
	else
	{
		printt( "*** Setting LaunchButton_OnActivate ***  NULL")
		file.launchButtonActivateFunc = null
	}

	Hud_SetVisible( file.launchButton, launchState == eLaunchState.WAIT_TO_CONTINUE )

	RuiSetString( file.status, "prompt", prompt )
	RuiSetBool( file.status, "showPrompt", prompt != "" )

	file.working = launchState == eLaunchState.WORKING
	RuiSetBool( file.status, "showSpinner", file.working )

	thread ShowStatusMessagesAfterDelay()

	if ( details == "" )
		details = GetConVarString( "rspn_motd" )

	if ( details != "" )
		RuiSetString( file.statusDetails, "details", details )

	bool lastStatusDetailsVisiblity = file.statusDetailsVisiblity
	file.statusDetailsVisiblity = details != ""

	if ( file.statusDetailsVisiblity == true || ( file.statusDetailsVisiblity == false && lastStatusDetailsVisiblity != false ) )
	{
		RuiSetBool( file.statusDetails, "ruiVisible", file.statusDetailsVisiblity )
		RuiSetGameTime( file.statusDetails, "initTime", ClientTime() )
	}

	UpdateSignedInState()
	UpdateFooterOptions()
}


void function ShowStatusMessagesAfterDelay()
{
	Signal( uiGlobal.signalDummy, "SetLaunchState" )
	EndSignal( uiGlobal.signalDummy, "SetLaunchState" )

	if ( !IsWorking() )
		return

	wait 5.0

	if ( !IsWorking() )
		return

	OnThreadEnd(
		function() : (  )
		{
			Hud_SetVisible( file.serverSearchMessage, false )
			Hud_SetVisible( file.serverSearchError, false )
		}
	)

	Hud_SetVisible( file.serverSearchMessage, true )
	Hud_SetVisible( file.serverSearchError, true )

	WaitForever()
}


bool function IsWorking()
{
	return file.working
}


void function DoMigrateFlow()
{
	EndSignal( uiGlobal.signalDummy, "EndMigrateFlow" )

	file.crossProgressing = true
	SetLaunchState( eLaunchState.WORKING )

	CrossProgression_RequestMigrate()

	const float MIGRATE_FLOW_TIMEOUT = 180.0
	float startTimeMigrate = UITime()

	const float QUERY_STATUS_INTERVAL = 10.0
	float nextTimeRequestStatus       = 0.0

	while ( true )
	{
		float currentTime = UITime()
		if ( currentTime - startTimeMigrate > MIGRATE_FLOW_TIMEOUT )
		{
			file.xProgMigrateFailed = true
			printt( "[CrossProgression] DoMigrateFlow Timeout" )

			UI_CloseCrossProgressionDialog()
			ConfirmDialogData data
			data.headerText = Localize( "#CROSS_PROGRESSION_MIGRATE_COOLINGDOWN_TITLE" )
			data.messageText = Localize( "#CROSS_PROGRESSION_MIGRATE_COOLINGDOWN_DESC", string( MIGRATE_DEFAULT_RETRY_MINUTES ) )
			OpenOKDialogFromData( data )

			break
		}

		if ( file.xProgMigrateFailed )
			break

		if ( CrossProgression_IsMigrated() )
		{
			XProgMigrateData migrateData = CrossProgressionGetMigrateData()
			if ( !file.xProgMigrateDoneWithMTXData && migrateData.hasMultipleProfiles )
				CrossProgression_RequestMigrateStatus()

			break
		}

		if ( file.xProgRequestMigrateFinished && currentTime > nextTimeRequestStatus )
		{
			if ( nextTimeRequestStatus > QUERY_STATUS_INTERVAL )
				CrossProgression_RequestMigrateStatus()

			nextTimeRequestStatus = currentTime + QUERY_STATUS_INTERVAL
		}

		WaitFrame()
	}

	file.crossProgressing = false
	SetLaunchState( eLaunchState.WAIT_TO_CONTINUE, "", Localize( "#MAINMENU_BROWSE_SERVERS" ) )
}

bool function IsCrossProgressionMigrateFlowEnabled()
{
	if ( !GetConVarBool( "CrossProgression_Ready" ) )
		return false

	if ( file.xProgMigrateFailed )
		return false

	return true
}

void function UI_CrossProgression_DoMigrateFlow()
{
	thread DoMigrateFlow()
}

void function UICodeCallback_XProgCheckRolloutRequestFinished()
{
	printt( "[CrossProgression] UICodeCallback_XProgCheckRolloutRequestFinished")

	file.xProgCheckRolloutRequestFinished = true

	if ( IsCrossProgressionMigrateFlowEnabled() && !CrossProgression_IsMigrated() )
	{
		RTKCrossProgressionPanel_SetDialogHeight()
		UI_OpenCrossProgressionDialog()
	}
}

void function UICodeCallback_XProgMigrateRequestFinished()
{
	printt( "[CrossProgression] UICodeCallback_XProgMigrateRequestFinished" )
	file.xProgRequestMigrateFinished = true

	if ( CrossProgression_IsMigrated() )
	{
		XProgMigrateData migrateData = CrossProgressionGetMigrateData()

		if ( migrateData.hasMultipleProfiles )
		{
			RTKCrossProgressionPanel_SetHeader()
			RTKCrossProgressionPanel_SetDialogHeight()
			RTKCrossProgressionPanel_UpdateDataModel()
			UI_OpenCrossProgressionDialog()
		}
		else
		{
			UI_CloseCrossProgressionDialog()
		}
	}
}


void function UICodeCallback_XProgMigrateStatusRequestFinished()
{
	printt( "[CrossProgression] UICodeCallback_XProgMigrateStatusRequestFinished")

	XProgMigrateData migrateData = CrossProgressionGetMigrateData()
	printt( "[CrossProgression] XProgStatus process state: ", migrateData.processStatus )

	if ( CrossProgression_IsMigrated() )
	{
		file.xProgMigrateDoneWithMTXData = true

		UICodeCallback_XProgMigrateRequestFinished()

		printt( "[CrossProgression] EA ID: ", migrateData.eaId )
		printt( "[CrossProgression] Nickname: ", migrateData.nickname )
		printt( "[CrossProgression] Level: ", migrateData.level )
		printt( "[CrossProgression] Herirlooms: ", migrateData.heirloom )
		printt( "[CrossProgression] Herirloom Shards ", migrateData.heirloomShards )
		printt( "[CrossProgression] Apex Packs ", migrateData.apexPacks )
		printt( "[CrossProgression] Total (Cosmetics)", migrateData.cosmetics )
		printt( "[CrossProgression] Legend Tokens", migrateData.credits )
		printt( "[CrossProgression] Crafting Metals", migrateData.crafting )
		printt( "[CrossProgression] Nintendo AC", migrateData.premiumNx )
		printt( "[CrossProgression] All other AC", migrateData.premium )
	}
}

void function UICodeCallback_XProgMigrateNotificationRequestFinished()
{
	printt( "[CrossProgression] UICodeCallback_XProgMigrateNotificationRequestFinished")
	file.xProgCheckNotificationRequestFinished = true
	UI_OpenCrossProgressionDialog()
}

void function UICodeCallback_XProgMigrateFlowFailed()
{
	printt( "[CrossProgression] UICodeCallback_XProgMigrateFlowFailed")

	file.xProgMigrateFailed = true

	XProgMigrateData migrateData = CrossProgressionGetMigrateData()
	UI_CloseCrossProgressionDialog()
	ConfirmDialogData data
	data.headerText = Localize( "#CROSS_PROGRESSION_MIGRATE_COOLINGDOWN_TITLE" )
	data.messageText = Localize( "#CROSS_PROGRESSION_MIGRATE_COOLINGDOWN_DESC" )
	OpenOKDialogFromData( data )
}

bool function IsCrossProgressing()
{
	return IsCrossProgressionMigrateFlowEnabled() && file.crossProgressing
}


void function StartSearchForPartyServer()
{







	SearchForPartyServer()
	SetLaunchState( eLaunchState.WORKING )
	file.searching = true

#if SPINNER_DEBUG_INFO
	SetSpinnerDebugInfo( "SearchForPartyServer" )
#endif

	UpdateSignedInState()
	UpdateFooterOptions()

	thread SearchForPartyServerTimeout()
}


void function SearchForPartyServerTimeout()
{
	EndSignal( uiGlobal.signalDummy, "EndSearchForPartyServerTimeout" )

	Hud_SetAutoText( file.serverSearchMessage, "", HATT_MATCHMAKING_EMPTY_SERVER_SEARCH_STATE, 0 )
	Hud_SetAutoText( file.serverSearchError, "", HATT_MATCHMAKING_EMPTY_SERVER_SEARCH_ERROR, 0 )

	string noServers              = Localize( "#MATCHMAKING_NOSERVERS" )
	string serverError            = Localize( "#MATCHMAKING_SERVERERROR" )
	string localError             = Localize( "#MATCHMAKING_LOCALERROR" )
	string lastValidSearchMessage = ""
	string lastValidSearchError   = ""
	float startTime               = UITime()

	while ( UITime() - startTime < 30.0 )
	{
		string searchMessage = Hud_GetUTF8Text( file.serverSearchMessage )
		string searchError = Hud_GetUTF8Text( file.serverSearchError )
		

		
		if ( ClientIsPreCaching() )
		{
			startTime = UITime()
		}

		if ( searchMessage == noServers || searchMessage == serverError || searchMessage == localError )
		{
			lastValidSearchMessage = searchMessage
			lastValidSearchError = searchError
		}

		WaitFrame()
	}
	

	string details
	if ( (lastValidSearchMessage == serverError || lastValidSearchMessage == localError) && lastValidSearchError != "" )
		details = Localize( "#UNABLE_TO_CONNECT_ERRORCODE", lastValidSearchError )
	else
		details = Localize( "#UNABLE_TO_CONNECT" )

	thread StopSearchForPartyServer( details, Localize( "#MAINMENU_RETRY" ) )
}


void function StopSearchForPartyServer( string details, string prompt )
{
	Signal( uiGlobal.signalDummy, "EndSearchForPartyServerTimeout" )

	MatchmakingCancel()
	Party_LeaveParty()
	SetLaunchState( eLaunchState.WAIT_TO_CONTINUE, details, prompt )
	file.searching = false

	UpdateSignedInState()
	UpdateFooterOptions()
}


bool function IsSearchingForPartyServer()
{
	return file.searching
}

























































































































































void function LaunchButton_OnActivate( var button )
{
	if ( file.launchButtonActivateFunc == null )
	{
		printt( "*** LaunchButton_OnActivate ***  Null")
		return
	}

	printt( "*** LaunchButton_OnActivate ***", string( file.launchButtonActivateFunc ) )
	thread file.launchButtonActivateFunc()
}


void function UICodeCallback_GetOnPartyServer()
{
	SetLaunchingState( eLaunching.MULTIPLAYER_INVITE )
	PrelaunchValidateAndLaunch()
}


bool function IsStryderAuthenticated()
{
	return GetConVarInt( "mp_allowed" ) != -1
}


bool function IsStryderAllowingMP()
{
	return GetConVarInt( "mp_allowed" ) == 1
}



bool function HasLatestPatch()
{





	return true
}


bool function HasPermission()
{




	return true
}


void function Accessibility_OnActivate( var button )
{





	if ( IsDialog( GetActiveMenu() ) )
		return

	if ( !IsAccessibilityAvailable() )
		return

	AdvanceMenu( GetMenu( "AccessibilityDialog" ) )
}


void function OnConfirmDialogResult( int result )
{
	printt( result )
}


void function PrintLaunchDebugVal( string name, bool val )
{
#if DEVELOPER
		printt( "*** PrelaunchValidation *** " + name + ": " + val )
#endif
}







































































void function SwitchProfile_OnActivate( var button )
{













}


bool function IsSwitchProfileFooterValid()
{



		return false

}


#if DEVELOPER
void function DEV_TestFooterTextWidths( var elem )
{
	while ( true )
	{
		Hud_SetText( elem, "testing" )
		wait 3
		Hud_SetText( elem, "testing longer" )
		wait 3
		Hud_SetText( elem, "testing even longer" )
		wait 3
		Hud_SetText( elem, "testing even more longer" )
		wait 3
		Hud_SetText( elem, "testing even more more more longer" )
		wait 3
		Hud_SetText( elem, "testing even more more more more more more longer" )
		wait 3
	}
}

void function DEV_ToggleRuiIssuesDemo( string elemName )
{
	var targetElem = Hud_GetChild( file.panel, elemName )

	array<var> elems
	elems.append( Hud_GetChild( file.panel, "RuiIssuesTransparency" ) )
	elems.append( Hud_GetChild( file.panel, "RuiIssuesSamplingBlur" ) )
	elems.append( Hud_GetChild( file.panel, "RuiIssues9SliceScaling" ) )

	foreach ( elem in elems )
	{
		if ( elem == targetElem )
			Hud_SetVisible( elem, !Hud_IsVisible( elem ) )
		else
			Hud_SetVisible( elem, false )
	}
}
#endif
