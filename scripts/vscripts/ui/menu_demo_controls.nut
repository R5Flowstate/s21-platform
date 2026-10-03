// Mouse layer for the replay HUD. The client opens it while the pointer is up;
// presses, drags, releases and keys go back to client/cl_demo_overlay.gnut,
// which owns the layout and every action.

global function InitDemoControlsMenu
global function DemoControls_Open
global function DemoControls_Close

struct
{
	var menu
	bool keysRegistered = false
	bool polling = false
} file

void function InitDemoControlsMenu( var newMenuArg )
{
	file.menu = newMenuArg
	// Leave the gamepad cursor off: it takes over the mouse and hides the pointer.
	// The Hitbox only holds the cursor; the button is polled so sliders can be dragged.
	AddMenuEventHandler( file.menu, eUIEvent.MENU_OPEN, DemoControls_OnOpen )
	AddMenuEventHandler( file.menu, eUIEvent.MENU_CLOSE, DemoControls_OnClose )
	AddMenuEventHandler( file.menu, eUIEvent.MENU_NAVIGATE_BACK, DemoControls_OnNavBack )
}

void function DemoControls_Open()
{
	if ( file.menu == null || MenuStack_Contains( file.menu ) )
		return
	AdvanceMenu( file.menu )
}

void function DemoControls_Close()
{
	if ( file.menu != null && GetActiveMenu() == file.menu )
		CloseActiveMenu()
}

void function DemoControls_OnOpen()
{
	SetMenuNavigationDisabled( false )
	SetCursorPosition( <1920.0 * 0.5, 1080.0 * 0.5, 0> )
	if ( !file.polling )
		thread DemoControls_PointerThread()
	if ( file.keysRegistered )
		return
	file.keysRegistered = true
	RegisterButtonPressedCallback( KEY_SPACE, DemoControls_Space )
	RegisterButtonPressedCallback( KEY_LEFT, DemoControls_Left )
	RegisterButtonPressedCallback( KEY_RIGHT, DemoControls_Right )
	RegisterButtonPressedCallback( KEY_PERIOD, DemoControls_Step )
	RegisterButtonPressedCallback( KEY_UP, DemoControls_Up )
	RegisterButtonPressedCallback( KEY_DOWN, DemoControls_Down )
	RegisterButtonPressedCallback( KEY_N, DemoControls_Next )
	RegisterButtonPressedCallback( KEY_P, DemoControls_Prev )
	RegisterButtonPressedCallback( KEY_C, DemoControls_Camera )
	RegisterButtonPressedCallback( KEY_F, DemoControls_Free )
	RegisterButtonPressedCallback( KEY_M, DemoControls_Moments )
	RegisterButtonPressedCallback( KEY_B, DemoControls_Bookmark )
	RegisterButtonPressedCallback( KEY_X, DemoControls_Clip )
	RegisterButtonPressedCallback( KEY_H, DemoControls_Hud )
	RegisterButtonPressedCallback( KEY_G, DemoControls_Clean )
	RegisterButtonPressedCallback( KEY_LALT, DemoControls_Mouse )
	RegisterButtonPressedCallback( KEY_V, DemoControls_Cursor )
	RegisterButtonPressedCallback( KEY_1, DemoControls_View1 )
	RegisterButtonPressedCallback( KEY_2, DemoControls_View2 )
	RegisterButtonPressedCallback( KEY_3, DemoControls_View3 )
	RegisterButtonPressedCallback( KEY_4, DemoControls_View4 )
	RegisterButtonPressedCallback( KEY_5, DemoControls_View5 )
	RegisterButtonPressedCallback( KEY_6, DemoControls_View6 )
}

void function DemoControls_OnClose()
{
	if ( !file.keysRegistered )
		return
	file.keysRegistered = false
	DeregisterButtonPressedCallback( KEY_SPACE, DemoControls_Space )
	DeregisterButtonPressedCallback( KEY_LEFT, DemoControls_Left )
	DeregisterButtonPressedCallback( KEY_RIGHT, DemoControls_Right )
	DeregisterButtonPressedCallback( KEY_PERIOD, DemoControls_Step )
	DeregisterButtonPressedCallback( KEY_UP, DemoControls_Up )
	DeregisterButtonPressedCallback( KEY_DOWN, DemoControls_Down )
	DeregisterButtonPressedCallback( KEY_N, DemoControls_Next )
	DeregisterButtonPressedCallback( KEY_P, DemoControls_Prev )
	DeregisterButtonPressedCallback( KEY_C, DemoControls_Camera )
	DeregisterButtonPressedCallback( KEY_F, DemoControls_Free )
	DeregisterButtonPressedCallback( KEY_M, DemoControls_Moments )
	DeregisterButtonPressedCallback( KEY_B, DemoControls_Bookmark )
	DeregisterButtonPressedCallback( KEY_X, DemoControls_Clip )
	DeregisterButtonPressedCallback( KEY_H, DemoControls_Hud )
	DeregisterButtonPressedCallback( KEY_G, DemoControls_Clean )
	DeregisterButtonPressedCallback( KEY_LALT, DemoControls_Mouse )
	DeregisterButtonPressedCallback( KEY_V, DemoControls_Cursor )
	DeregisterButtonPressedCallback( KEY_1, DemoControls_View1 )
	DeregisterButtonPressedCallback( KEY_2, DemoControls_View2 )
	DeregisterButtonPressedCallback( KEY_3, DemoControls_View3 )
	DeregisterButtonPressedCallback( KEY_4, DemoControls_View4 )
	DeregisterButtonPressedCallback( KEY_5, DemoControls_View5 )
	DeregisterButtonPressedCallback( KEY_6, DemoControls_View6 )
}

// Back hides the free camera's pointer, otherwise pauses or resumes the replay.
void function DemoControls_OnNavBack()
{
	RunClientScript( "DemoOverlay_Back" )
}

// Press, drag and release of the left button, while this menu is on top.
void function DemoControls_PointerThread()
{
	file.polling = true
	OnThreadEnd(
		function() : ()
		{
			file.polling = false
		}
	)

	bool wasDown = InputIsButtonDown( MOUSE_LEFT )
	vector last = GetCursorPosition()
	while ( file.menu != null && GetActiveMenu() == file.menu )
	{
		bool down = InputIsButtonDown( MOUSE_LEFT )
		vector pos = GetCursorPosition()
		if ( down && !wasDown )
			RunClientScript( "DemoOverlay_Click", pos.x, pos.y )
		else if ( down && ( pos.x != last.x || pos.y != last.y ) )
			RunClientScript( "DemoOverlay_Drag", pos.x, pos.y )
		else if ( !down && wasDown )
			RunClientScript( "DemoOverlay_Release", pos.x, pos.y )
		wasDown = down
		last = pos
		WaitFrame()
	}
	if ( wasDown )
		RunClientScript( "DemoOverlay_Release", last.x, last.y )
}

void function DemoControls_Send( int key )
{
	if ( Demo_InputDiag() )
		printt( "[DEMO-INPUT] forwarded key", key )
	RunClientScript( "DemoOverlay_Key", key, InputIsButtonDown( KEY_LSHIFT ) || InputIsButtonDown( KEY_RSHIFT ) )
}

void function DemoControls_Space( var button ) { DemoControls_Send( KEY_SPACE ) }
void function DemoControls_Left( var button ) { DemoControls_Send( KEY_LEFT ) }
void function DemoControls_Right( var button ) { DemoControls_Send( KEY_RIGHT ) }
void function DemoControls_Step( var button ) { DemoControls_Send( KEY_PERIOD ) }
void function DemoControls_Up( var button ) { DemoControls_Send( KEY_UP ) }
void function DemoControls_Down( var button ) { DemoControls_Send( KEY_DOWN ) }
void function DemoControls_Next( var button ) { DemoControls_Send( KEY_N ) }
void function DemoControls_Prev( var button ) { DemoControls_Send( KEY_P ) }
void function DemoControls_Camera( var button ) { DemoControls_Send( KEY_C ) }
void function DemoControls_Free( var button ) { DemoControls_Send( KEY_F ) }
void function DemoControls_Moments( var button ) { DemoControls_Send( KEY_M ) }
void function DemoControls_Bookmark( var button ) { DemoControls_Send( KEY_B ) }
void function DemoControls_Clip( var button ) { DemoControls_Send( KEY_X ) }
void function DemoControls_Hud( var button ) { DemoControls_Send( KEY_H ) }
void function DemoControls_Clean( var button ) { DemoControls_Send( KEY_G ) }
void function DemoControls_Mouse( var button ) { DemoControls_Send( KEY_LALT ) }
void function DemoControls_Cursor( var button ) { DemoControls_Send( KEY_V ) }
void function DemoControls_View1( var button ) { DemoControls_Send( KEY_1 ) }
void function DemoControls_View2( var button ) { DemoControls_Send( KEY_2 ) }
void function DemoControls_View3( var button ) { DemoControls_Send( KEY_3 ) }
void function DemoControls_View4( var button ) { DemoControls_Send( KEY_4 ) }
void function DemoControls_View5( var button ) { DemoControls_Send( KEY_5 ) }
void function DemoControls_View6( var button ) { DemoControls_Send( KEY_6 ) }
