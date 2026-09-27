global function InitErrorDialog
global function OpenErrorDialogThread
global function PreviewErrorDialog

struct
{
	var menu
	var contentRui
	asset contextImage
	string headerText
	string messageText
	string SIDText
} file

void function InitErrorDialog( var newMenuArg ) 
{
	var menu = GetMenu( "ErrorDialog" )
	file.menu = menu

	SetDialog( menu, true )
	SetGamepadCursorEnabled( menu, false )

	file.contentRui = Hud_GetRui( Hud_GetChild( file.menu, "ContentRui" ) )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, ErrorDialog_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, ErrorDialog_OnClose )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, ErrorDialog_OnNavigateBack )

	AddMenuFooterOption( menu, LEFT, BUTTON_A, true, "#A_BUTTON_CONTINUE", "#CONTINUE", Continue )

#if DEVELOPER
	AddMenuThinkFunc( menu, ErrorDialogAutomationThink )
#endif
}

#if DEVELOPER
void function ErrorDialogAutomationThink( var menu )
{
	if (AutomateUi())
	{
		printt("ErrorDialogAutomationThink Continue()")
		Continue(null)
	}
}
#endif

void function Continue( var button )
{
	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()
}

// Present in every EA sign-in / session failure string, in all 14 languages.
const string EA_HELP_MARKER = "ea.com/unable-to-connect"

const string PREVIEW_ERROR_TIMEOUT = "Connection to server timed out (code:net). See ea.com/unable-to-connect for additional information"
const string PREVIEW_ERROR_EA = "Unable to connect to EA Servers. Please check your Internet connection, make sure EA app is online and try again. See ea.com/unable-to-connect for more information."

// Console, from the main menu:
//   script_ui PreviewErrorDialog( 0 )   timeout family
//   script_ui PreviewErrorDialog( 1 )   EA sign-in family
void function PreviewErrorDialog( int variant = 0 )
{
	thread OpenErrorDialogThread( variant == 1 ? PREVIEW_ERROR_EA : PREVIEW_ERROR_TIMEOUT )
}

bool function ErrorDialog_IsEaConnect( string errorMessage )
{
	return errorMessage.find( EA_HELP_MARKER ) != -1
}

// Drops the trailing "See ea.com/unable-to-connect ..." sentence; our own
// advice replaces it.
string function ErrorDialog_TrimEaHelpLine( string errorMessage )
{
	int ea = errorMessage.find( EA_HELP_MARKER )
	if ( ea == -1 )
		return errorMessage

	int cut = -1
	int at = errorMessage.find( ". " )
	while ( at != -1 && at < ea )
	{
		cut = at + 1
		at = errorMessage.find( ". ", at + 1 )
	}

	if ( cut == -1 )
		return errorMessage

	return errorMessage.slice( 0, cut )
}

bool function ErrorDialog_IsModsPolicy( string errorMessage )
{
	if ( errorMessage.find( "SDK_MODS_POLICY" ) != -1 )
		return true

	string localized = Localize( "#SDK_MODS_POLICY" )
	if ( localized != "" && localized != "#SDK_MODS_POLICY" && errorMessage.find( localized ) != -1 )
		return true

	return false
}

void function ErrorDialog_OnOpen()
{
	RuiSetAsset( file.contentRui, "contextImage", file.contextImage )
	RuiSetString( file.contentRui, "headerText", file.headerText )

	string messageText = file.messageText
	if( !IsValid( messageText ) )
	{
		messageText = "ERROR MESSAGE TEXT WAS INVALID"
	}
	RuiSetString( file.contentRui, "messageText", messageText )

	var label = Hud_GetChild( file.menu, "ServerID" )
	Hud_SetText( label, file.SIDText )
}

void function ErrorDialog_OnClose()
{
}

void function ErrorDialog_OnNavigateBack()
{
	CloseActiveMenu()
}

void function OpenErrorDialogThread( string errorMessage )
{
	bool isIdleDisconnect = errorMessage.find( Localize( "#DISCONNECT_IDLE" ) ) == 0
	bool isModsPolicy = ErrorDialog_IsModsPolicy( errorMessage )
	bool isEaConnect = !isModsPolicy && ErrorDialog_IsEaConnect( errorMessage )

	if ( isModsPolicy )
		printt( "[MOD] disconnect: server refused client mod set" )

	string headerText
	string messageText
	if ( isModsPolicy )
	{
		headerText = Localize( "#BRIDGE_MODS_POLICY_HEADER" )
		messageText = Localize( "#BRIDGE_MODS_POLICY_BODY" )
	}
	else if ( isEaConnect )
	{
		string hint = errorMessage.find( "(code:" ) != -1 ? "#BRIDGE_NET_TIMEOUT_HINT" : "#BRIDGE_EA_CONNECT_HINT"
		headerText = Localize( "#BRIDGE_EA_CONNECT_HEADER" )
		messageText = ErrorDialog_TrimEaHelpLine( errorMessage ) + "\n\n" + Localize( hint )
	}
	else
	{
		headerText = isIdleDisconnect ? Localize( "#DISCONNECTED_HEADER" ) : Localize( "#ERROR" )
		messageText = errorMessage
	}

	file.contextImage = isIdleDisconnect ? $"ui/menu/common/dialog_notice" : $"ui/menu/common/dialog_error"
	file.headerText = headerText.toupper()
	file.messageText = messageText
	file.SIDText = "SID: " + GetServerDebugId() 

	while ( GetActiveMenu() != GetMenu( "MainMenu" ) )
		WaitSignal( uiGlobal.signalDummy, "OpenErrorDialog", "ActiveMenuChanged" )

	if ( isModsPolicy && LauncherHandoff_IsAvailable() )
	{
		ErrorDialog_OfferLauncherRejoin()
		return
	}

	AdvanceMenu( file.menu )
}

void function ErrorDialog_OfferLauncherRejoin()
{
	ConfirmDialogData data
	data.headerText = "#BRIDGE_MODS_POLICY_HEADER"
	data.messageText = "#BRIDGE_MODS_POLICY_LAUNCHER"
	data.resultCallback = void function ( int result )
	{
		if ( result != eDialogResult.YES || LauncherHandoff_RejoinLastServer() )
			return

		ConfirmDialogData failed
		failed.headerText = "#BRIDGE_MODS_POLICY_HEADER"
		failed.messageText = "#BRIDGE_SB_HANDOFF_FAILED"
		OpenOKDialogFromData( failed )
	}
	OpenConfirmDialogFromData( data )
}