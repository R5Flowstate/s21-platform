global function InitEULADialog
global function OpenEULADialog
global function IsEULAAccepted
global function IsLobbyAndEULAAccepted
global function Bridge_MaybeShowFirstTimeEULA

// The agreement text comes from the master server so it can be updated without
// shipping a build. The local body below is the fallback used until the fetch
// lands, and permanently if it fails.
// First-time-seen persistence: archive convars eula_version / eula_version_accepted
// (games/client/convar_stubs.cpp).

struct
{
	var menu
	var agreement
	var acknowledgement
	var footersPanel
	var parentMenuPanel
	var savedFocusItem
	int eulaVersion
	bool reviewing
	bool firstTimePromptQueued = false
	string fetchedBody = ""
	int fetchedVersion = 0
} file

// Fallback body, used until the master server answers and if it never does.
const string BRIDGE_EULA_BODY = "R5Flowstate USER NOTICE\n\nThis build is an unofficial community client. It is not affiliated with, endorsed by, or supported by Electronic Arts, Respawn Entertainment, or Apex Legends retail services.\n\nBy continuing you acknowledge that:\n1. You use this software at your own risk on systems you control.\n2. Online features connect only to servers you intentionally join.\n3. There is no official matchmaking, account progression, or EA platform support in this path.\n4. You will not use this software to attack, disrupt, or gain unauthorized access to systems you do not own or administer.\n5. Game assets and trademarks remain the property of their respective owners.\n6. You will not port skins or cosmetics from the retail game for the purpose of leaking them or creating content.\n7. You will not try to unlock game cosmetics.\n8. You will report any multiplayer server that uses retail cosmetics.\n9. You own Apex Legends and have it in your EA library.\n\nPRIVACY -- what we process\nThe master server at r5flowstate.org is operated by the R5Flowstate project. The data controller is the R5Flowstate project, contact r5flowstate1@gmail.com. It processes:\n- your EA/Nucleus account id and persona name, so we can authenticate you and show who is playing\n- a history of persona names used on this account\n- a short log of sign-in attempts (time, success/failure, method)\n- IP addresses only when an operator issues a restriction (ban), plus short-lived connection logs used to stop abuse\n- a country code supplied by Cloudflare, stored only as an aggregate count, never against your account\n\nWe do not store the EA platform token after the sign-in check. We do not sell personal data.\n\nCrash reports\nIf the game client crashes, we send an automatic report so we can patch the build. That report includes a minidump (call stack and a slice of process memory), a hardware summary (CPU, GPU, RAM, disk), a session id, and the build stamp. It is processed in the United States by our error-reporting service. We do not sell it. You can turn this off with backtrace_enabled 0.\n\nWhy we process it (lawful basis in brackets)\n- to let you join community servers (contract: this is the service you asked for)\n- to enforce restrictions and rate limits (legitimate interests: abuse prevention)\n- to diagnose and patch client crashes (legitimate interests: fixing the build)\n\nHow long we keep it\nUnrestricted accounts and their sign-in log are deleted after 14 days of inactivity. Active restrictions are kept so a banned account cannot immediately return. You can ask us to export or erase your data at any time.\n\nWhere it is processed\nThe master server is hosted in the United States. Traffic may pass through Cloudflare. Continuing means you understand that transfer.\n\nYour rights\nYou may request a copy of the data we hold about you, or ask us to erase it. You may also ask us to correct it, restrict how we use it, receive it in a portable form, or object to how we use it. You may complain to your national data protection authority. Erase removes your account, persona history, and sign-in log. An active restriction may be kept (without operator notes) so the ban still works. We cannot erase data held by Electronic Arts.\n\nHow to ask\nEmail r5flowstate1@gmail.com, or open a request on the R5Flowstate Discord or GitHub and include the Nucleus account id shown in your Origin/EA account. There is no in-game delete button.\n\nPress Continue to acknowledge this notice. You may review it later from the main menu (Read EULA) or at https://r5flowstate.org/privacy/";

const int BRIDGE_EULA_VERSION_FALLBACK = 4

void function InitEULADialog( var newMenuArg )
{
	var menu = GetMenu( "EULADialog" )
	file.menu = menu

	SetDialog( menu, true )
	SetGamepadCursorEnabled( menu, false )

	file.agreement = Hud_GetChild( menu, "Agreement" )
	file.acknowledgement = Hud_GetRui( Hud_GetChild( menu, "Acknowledgement" ) )
	file.footersPanel = Hud_GetChild( menu, "FooterButtons" )
	file.savedFocusItem = null

	AddMenuFooterOption( menu, LEFT, BUTTON_A, true, "#A_BUTTON_ACCEPT", "#A_BUTTON_ACCEPT", AcceptEULA, IsNotReviewingAndStandardVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_A, true, "#A_BUTTON_CONTINUE", "#A_BUTTON_CONTINUE", AcceptEULA, IsNotReviewingAndEUVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_DECLINE", "#B_BUTTON_DECLINE", null, IsNotReviewingAndStandardVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CANCEL", "#CANCEL", null, IsNotReviewingAndEUVersion )
	AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "#B_BUTTON_CLOSE", "#CLOSE", null, IsReviewing )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, EULADialog_OnOpen )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, EULADialog_OnClose )

	// Fetch early so the text is usually present before the dialog is ever opened.
	RequestEULAContents()
}

int function Bridge_GetCurrentEULAVersion()
{
	int served = GetEULAVersion()
	if ( served > 0 )
		file.fetchedVersion = served

	// A served version wins: it is what the displayed text actually corresponds to.
	if ( file.fetchedVersion > 0 )
		return file.fetchedVersion

	int ver = GetConVarInt( "eula_version" )
	if ( ver <= 0 )
		ver = BRIDGE_EULA_VERSION_FALLBACK
	return ver
}

// Empty until the request lands, and after a failure, so the local body stands in.
string function Bridge_GetEULABody()
{
	string served = GetEULAContents()
	if ( served != "" )
	{
		file.fetchedBody = served

		int ver = GetEULAVersion()
		if ( ver > 0 )
			file.fetchedVersion = ver
	}

	if ( file.fetchedBody != "" )
		return file.fetchedBody

	return BRIDGE_EULA_BODY
}

int function Bridge_GetAcceptedEULAVersion()
{
	return GetConVarInt( "eula_version_accepted" )
}

void function Bridge_SetAcceptedEULAVersion( int ver )
{
	SetConVarInt( "eula_version_accepted", ver )
	SetEULAVersionAccepted( ver )
}

void function Bridge_MaybeShowFirstTimeEULA()
{
	if ( file.firstTimePromptQueued )
		return
	file.firstTimePromptQueued = true

	if ( IsEULAAccepted() )
	{
		return
	}

	OpenEULADialog( false )
}

bool function IsReviewing()
{
	return file.reviewing
}

bool function IsEUVersion()
{
	return true
}

bool function IsNotReviewingAndStandardVersion()
{
	return !IsReviewing() && !IsEUVersion()
}

bool function IsNotReviewingAndEUVersion()
{
	return !IsReviewing() && IsEUVersion()
}

void function OpenEULADialog( bool review, var parentMenu = null, var focusItem = null )
{
	file.reviewing = review
	file.parentMenuPanel = parentMenu
	file.savedFocusItem = focusItem
	AdvanceMenu( file.menu )
}

void function EULADialog_OnOpen()
{
	file.eulaVersion = Bridge_GetCurrentEULAVersion()

	if ( file.reviewing && file.parentMenuPanel != null )
		ScrollPanel_SetActive( file.parentMenuPanel, false )

	RegisterStickMovedCallback( ANALOG_RIGHT_Y, FocusAgreementForScrolling )
	RegisterButtonPressedCallback( BUTTON_DPAD_UP, FocusAgreementForScrolling )
	RegisterButtonPressedCallback( BUTTON_DPAD_DOWN, FocusAgreementForScrolling )

	var frameElem = Hud_GetChild( file.menu, "DialogFrame" )
	RuiSetImage( Hud_GetRui( frameElem ), "basicImage", $"rui/menu/common/dialog_gradient" )

	int agreementHeight = IsReviewing() ? 480 : 410
	Hud_SetHeight( file.agreement, ContentScaledYAsInt( agreementHeight ) )

	Hud_SetText( file.agreement, Bridge_GetEULABody() )

	// Re-fetch on every open so a language switch picks up the matching body.
	RequestEULAContents()

	string acknowledgementText = ""
	if ( !IsReviewing() )
		acknowledgementText = "#EULA_ACKNOWLEDGEMENT"
	RuiSetArg( file.acknowledgement, "acknowledgementText", Localize( acknowledgementText ) )

	int footerPanelWidth = IsReviewing() ? 200 : 422
	Hud_SetWidth( file.footersPanel, ContentScaledXAsInt( footerPanelWidth ) )
}

void function EULADialog_OnClose()
{
	if ( GetLaunchingState() != 0 )
	{
		if ( IsEULAAccepted() )
			PrelaunchValidateAndLaunch()
		else
			SetLaunchState( eLaunchState.WAIT_TO_CONTINUE, "", Localize( "#MAINMENU_BROWSE_SERVERS" ) )
	}

	if ( file.reviewing && file.parentMenuPanel != null )
		ScrollPanel_SetActive( file.parentMenuPanel, true )

	DeregisterStickMovedCallback( ANALOG_RIGHT_Y, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( BUTTON_DPAD_UP, FocusAgreementForScrolling )
	DeregisterButtonPressedCallback( BUTTON_DPAD_DOWN, FocusAgreementForScrolling )

	if ( file.savedFocusItem != null )
		Hud_SetFocused( file.savedFocusItem )
}

void function AcceptEULA( var button )
{
	Bridge_SetAcceptedEULAVersion( file.eulaVersion )
	CloseActiveMenu()
}

bool function IsEULAAccepted()
{
	// Prefer archive convars (first-time-seen). eula_version_accepted 0 = never seen/accepted.
	return Bridge_GetAcceptedEULAVersion() >= Bridge_GetCurrentEULAVersion()
}

bool function IsLobbyAndEULAAccepted()
{
	return IsLobby() && IsEULAAccepted()
}

void function FocusAgreementForScrolling( ... )
{
	if ( !Hud_IsFocused( file.agreement ) )
		Hud_SetFocused( file.agreement )
}
