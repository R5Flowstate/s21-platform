// Shared server browser list/paint/connect for lobby Servers and main-menu Browse.
// UI VM only. No presentation types, no Client script.

global function ServerBrowserShared_Bind
global function ServerBrowserShared_Unbind
global function ServerBrowserShared_IsBound
global function ServerBrowserShared_OnShow
global function ServerBrowserShared_OnHide
global function ServerBrowserShared_WireControls
global function ServerBrowserShared_OnRefresh
global function ServerBrowserShared_OnConnect
global function ServerBrowserShared_OnClearFilters
global function ServerBrowserShared_OnPageDown
global function ServerBrowserShared_OnPageUp
global function ServerBrowserShared_OnSearchChanged
global function ServerBrowserShared_OnRowClick
global function UICodeCallback_OnServerListRequestCompleted

const int SERVER_ROWS_PER_PAGE = 15

struct
{
	var panel = null
	var menu = null
	bool bound = false
	bool controlsWired = false

	array<int> matches
	int pageStart = 0
	int selected = -1
	string search = ""

	// Parallel to SwtBtnSelectMap / SwtBtnSelectGamemode dialog-list indices (0 = Any).
	array<string> filterMaps
	array<string> filterPlaylists
} file

void function ServerBrowserShared_Bind( var panel, var menu )
{
	file.panel = panel
	file.menu = menu
	file.bound = ( panel != null && menu != null )
}

void function ServerBrowserShared_Unbind()
{
	file.bound = false
	file.panel = null
	// keep menu null only after hide of active host
	file.menu = null
	file.matches.clear()
	file.pageStart = 0
	file.selected = -1
	file.search = ""
	file.filterMaps.clear()
	file.filterPlaylists.clear()
}

bool function ServerBrowserShared_IsBound()
{
	return file.bound && file.panel != null
}

void function ServerBrowserShared_WireControls( var panel, var menu )
{
	// Handlers are panel-lifetime; wire once per panel instance.
	if ( file.controlsWired && file.panel == panel )
		return

	ServerBrowserShared_Bind( panel, menu )

	Hud_AddEventHandler( Hud_GetChild( panel, "ConnectButton" ), UIE_CLICK, ServerBrowserShared_OnConnect )
	Hud_AddEventHandler( Hud_GetChild( panel, "RefreshServers" ), UIE_CLICK, ServerBrowserShared_OnRefresh )
	Hud_AddEventHandler( Hud_GetChild( panel, "ClearFliters" ), UIE_CLICK, ServerBrowserShared_OnClearFilters )
	Hud_AddEventHandler( Hud_GetChild( panel, "BtnServerListDownArrow" ), UIE_CLICK, ServerBrowserShared_OnPageDown )
	Hud_AddEventHandler( Hud_GetChild( panel, "BtnServerListUpArrow" ), UIE_CLICK, ServerBrowserShared_OnPageUp )
	Hud_AddEventHandler( Hud_GetChild( panel, "BtnServerSearch" ), UIE_CHANGE, ServerBrowserShared_OnSearchChanged )

	// Dialog-list switches (playlist / map / hide-empty): re-filter after the ConVar settles.
	ServerBrowserShared_WireFilterSwitch( panel, "SwtBtnSelectGamemode" )
	ServerBrowserShared_WireFilterSwitch( panel, "SwtBtnSelectMap" )
	ServerBrowserShared_WireFilterSwitch( panel, "SwtBtnHideEmpty" )

	foreach ( var elem in GetElementsByClassname( menu, "ServBtn" ) )
	{
		RuiSetString( Hud_GetRui( elem ), "buttonText", "" )
		Hud_AddEventHandler( elem, UIE_CLICK, ServerBrowserShared_OnRowClick )
		Hud_SetVisible( elem, false )
	}

	for ( int row = 0; row < SERVER_ROWS_PER_PAGE; row++ )
		ServerBrowserShared_WireRowClickThrough( panel, row )

	file.controlsWired = true
	ServerBrowserShared_UpdateFilterLists()
	ServerBrowserShared_ShowEmptyState()
}

void function ServerBrowserShared_WireFilterSwitch( var panel, string childName )
{
	if ( !Hud_HasChild( panel, childName ) )
		return

	var sw = Hud_GetChild( panel, childName )
	if ( Hud_HasChild( sw, "LeftButton" ) )
		Hud_AddEventHandler( Hud_GetChild( sw, "LeftButton" ), UIE_CLICK, ServerBrowserShared_OnFilterChanged )
	if ( Hud_HasChild( sw, "RightButton" ) )
		Hud_AddEventHandler( Hud_GetChild( sw, "RightButton" ), UIE_CLICK, ServerBrowserShared_OnFilterChanged )
}

void function ServerBrowserShared_OnShow()
{
	if ( !ServerBrowserShared_IsBound() )
	{
		printt( "[BRIDGE-SB] OnShow skipped: host not bound" )
		return
	}

	printt( "[BRIDGE-SB] OnShow: empty state + RequestServerList" )
	ServerBrowserShared_ShowEmptyState()
	ServerBrowserShared_OnRefresh( null )
}

void function ServerBrowserShared_OnHide()
{
	// Active host releases bind so a second host cannot paint into a dead panel.
	// controlsWired stays true so re-show does not double-bind handlers.
	file.bound = false
}

// ----- list fetch -----

void function ServerBrowserShared_OnRefresh( var button )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	if ( IsServerListRequestInFlight() )
		return

	RequestServerList()
	ServerBrowserShared_SetMessage( Localize( "#BRIDGE_SB_REFRESHING" ) )

	// Belt: if UICodeCallback is delayed or missed, rebuild when in-flight clears.
	thread ServerBrowserShared_WaitInFlightAndRebuild()
}

void function ServerBrowserShared_WaitInFlightAndRebuild()
{
	// Drain natives run when IsServerListRequestInFlight is polled.
	while ( IsServerListRequestInFlight() )
		WaitFrame()

	if ( !ServerBrowserShared_IsBound() )
		return

	// List data is already in the native cache. Prefer master message when count is zero.
	string msg = GetServerListMessage()
	int count = GetServerCount()
	bool success = ( count > 0 || msg == "" )
	ServerBrowserShared_ApplyListResult( success, msg, count )
}

void function UICodeCallback_OnServerListRequestCompleted( bool success, string errorMsg, int serverCount )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	ServerBrowserShared_ApplyListResult( success, errorMsg, serverCount )
}

void function ServerBrowserShared_ApplyListResult( bool success, string errorMsg, int serverCount )
{
	file.selected = -1
	file.pageStart = 0

	// Refresh dialog-list options from the live listing, then re-apply filters.
	ServerBrowserShared_UpdateFilterLists()
	ServerBrowserShared_RebuildMatches()
	ServerBrowserShared_Redraw()

	if ( !success )
	{
		string reason = errorMsg
		if ( reason == "" )
			reason = GetServerListMessage()
		if ( reason == "" )
			reason = Localize( "#BRIDGE_SB_UNREACHABLE" )

		ServerBrowserShared_SetMessage( reason )
	}
}

// ----- filtering and paging -----

void function ServerBrowserShared_OnFilterChanged( var button )
{
	// SwitchButton updates its ConVar on the same click; wait a frame so we read the new value.
	thread ServerBrowserShared_OnFilterChanged_Thread()
}

void function ServerBrowserShared_OnFilterChanged_Thread()
{
	WaitFrame()

	if ( !ServerBrowserShared_IsBound() )
		return

	file.pageStart = 0
	file.selected = -1
	ServerBrowserShared_RebuildMatches()
	ServerBrowserShared_Redraw()
}

// Read filter switches from the dialog-list widgets (not ConVars). ConVars may be
// unbound until client.dll ships stubs; the widgets still cycle and report index.
int function ServerBrowserShared_GetMapFilterIndex()
{
	if ( !ServerBrowserShared_IsBound() )
		return 0
	if ( !Hud_HasChild( file.panel, "SwtBtnSelectMap" ) )
		return 0
	int idx = Hud_GetDialogListSelectionIndex( Hud_GetChild( file.panel, "SwtBtnSelectMap" ) )
	if ( idx < 0 || idx >= file.filterMaps.len() )
		return 0
	return idx
}

int function ServerBrowserShared_GetPlaylistFilterIndex()
{
	if ( !ServerBrowserShared_IsBound() )
		return 0
	if ( !Hud_HasChild( file.panel, "SwtBtnSelectGamemode" ) )
		return 0
	int idx = Hud_GetDialogListSelectionIndex( Hud_GetChild( file.panel, "SwtBtnSelectGamemode" ) )
	if ( idx < 0 || idx >= file.filterPlaylists.len() )
		return 0
	return idx
}

bool function ServerBrowserShared_GetHideEmpty()
{
	if ( !ServerBrowserShared_IsBound() )
		return false
	if ( !Hud_HasChild( file.panel, "SwtBtnHideEmpty" ) )
		return false
	// list { "No" 0 ; "Yes" 1 } — index 1 = hide empty.
	return Hud_GetDialogListSelectionIndex( Hud_GetChild( file.panel, "SwtBtnHideEmpty" ) ) == 1
}

void function ServerBrowserShared_UpdateFilterLists()
{
	if ( !ServerBrowserShared_IsBound() )
		return

	// Preserve prior selection by name when the listing set changes.
	string prevMap = "Any"
	string prevMode = "Any"
	int mapIdx = ServerBrowserShared_GetMapFilterIndex()
	int modeIdx = ServerBrowserShared_GetPlaylistFilterIndex()
	if ( mapIdx >= 0 && mapIdx < file.filterMaps.len() )
		prevMap = file.filterMaps[mapIdx]
	if ( modeIdx >= 0 && modeIdx < file.filterPlaylists.len() )
		prevMode = file.filterPlaylists[modeIdx]

	array<string> maps
	array<string> playlists
	maps.append( "Any" )
	playlists.append( "Any" )

	table<string, bool> seenMaps
	table<string, bool> seenPlaylists
	seenMaps["Any"] <- true
	seenPlaylists["Any"] <- true

	// Options = unique map / playlist values currently on the master list.
	int count = GetServerCount()
	for ( int i = 0; i < count; i++ )
	{
		string map = GetServerMap( i )
		if ( map != "" && !( map in seenMaps ) )
		{
			seenMaps[map] <- true
			maps.append( map )
		}

		string mode = GetServerPlaylist( i )
		if ( mode != "" && !( mode in seenPlaylists ) )
		{
			seenPlaylists[mode] <- true
			playlists.append( mode )
		}
	}

	file.filterMaps = maps
	file.filterPlaylists = playlists

	var mapBtn = Hud_GetChild( file.panel, "SwtBtnSelectMap" )
	var modeBtn = Hud_GetChild( file.panel, "SwtBtnSelectGamemode" )

	Hud_DialogList_ClearList( mapBtn )
	Hud_DialogList_ClearList( modeBtn )

	foreach ( int id, string map in maps )
	{
		string label = map == "Any" ? "Any" : GetUIMapName( map )
		Hud_DialogList_AddListItem( mapBtn, label, string( id ) )
	}

	foreach ( int id, string mode in playlists )
	{
		string label = mode == "Any" ? "Any" : GetUIPlaylistName( mode )
		Hud_DialogList_AddListItem( modeBtn, label, string( id ) )
	}

	// Restore selection if still present; else fall back to Any (index 0).
	int newMapIdx = 0
	int newModeIdx = 0
	foreach ( int id, string map in maps )
	{
		if ( map == prevMap )
		{
			newMapIdx = id
			break
		}
	}
	foreach ( int id, string mode in playlists )
	{
		if ( mode == prevMode )
		{
			newModeIdx = id
			break
		}
	}

	Hud_SetDialogListSelectionIndex( mapBtn, newMapIdx )
	Hud_SetDialogListSelectionIndex( modeBtn, newModeIdx )
}

void function ServerBrowserShared_RebuildMatches()
{
	file.matches.clear()

	string needle = file.search.tolower()
	bool hideEmpty = ServerBrowserShared_GetHideEmpty()

	int mapIdx = ServerBrowserShared_GetMapFilterIndex()
	int modeIdx = ServerBrowserShared_GetPlaylistFilterIndex()

	string filterMap = "Any"
	string filterMode = "Any"
	if ( file.filterMaps.len() > 0 )
		filterMap = file.filterMaps[mapIdx]
	if ( file.filterPlaylists.len() > 0 )
		filterMode = file.filterPlaylists[modeIdx]

	int count = GetServerCount()
	for ( int i = 0; i < count; i++ )
	{
		if ( hideEmpty && GetServerCurrentPlayers( i ) < 1 )
			continue

		if ( filterMap != "Any" && filterMap != GetServerMap( i ) )
			continue

		if ( filterMode != "Any" && filterMode != GetServerPlaylist( i ) )
			continue

		if ( needle != "" )
		{
			// Match name, map id/display, and playlist id/display (S3 parity).
			bool found = false
			array<string> fields
			fields.append( GetServerName( i ).tolower() )
			fields.append( GetServerMap( i ).tolower() )
			fields.append( GetUIMapName( GetServerMap( i ) ).tolower() )
			fields.append( GetServerPlaylist( i ).tolower() )
			fields.append( GetUIPlaylistName( GetServerPlaylist( i ) ).tolower() )

			foreach ( string field in fields )
			{
				// S21 string.find returns int index, or -1 if missing (not null).
				if ( field.find( needle ) != -1 )
				{
					found = true
					break
				}
			}

			if ( !found )
				continue
		}

		file.matches.append( i )
	}
}

void function ServerBrowserShared_OnSearchChanged( var entry )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	file.search = Hud_GetUTF8Text( entry )
	file.pageStart = 0
	file.selected = -1

	ServerBrowserShared_RebuildMatches()
	ServerBrowserShared_Redraw()
}

void function ServerBrowserShared_OnClearFilters( var button )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	file.search = ""
	file.pageStart = 0
	file.selected = -1

	Hud_SetUTF8Text( Hud_GetChild( file.panel, "BtnServerSearch" ), "" )

	if ( Hud_HasChild( file.panel, "SwtBtnSelectMap" ) )
		Hud_SetDialogListSelectionIndex( Hud_GetChild( file.panel, "SwtBtnSelectMap" ), 0 )
	if ( Hud_HasChild( file.panel, "SwtBtnSelectGamemode" ) )
		Hud_SetDialogListSelectionIndex( Hud_GetChild( file.panel, "SwtBtnSelectGamemode" ), 0 )
	if ( Hud_HasChild( file.panel, "SwtBtnHideEmpty" ) )
		Hud_SetDialogListSelectionIndex( Hud_GetChild( file.panel, "SwtBtnHideEmpty" ), 0 )

	ServerBrowserShared_RebuildMatches()
	ServerBrowserShared_Redraw()
	EmitUISound( "menu_accept" )
}

void function ServerBrowserShared_OnPageDown( var button )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	int next = file.pageStart + SERVER_ROWS_PER_PAGE
	if ( next >= file.matches.len() )
		return

	file.pageStart = next
	ServerBrowserShared_Redraw()
}

void function ServerBrowserShared_OnPageUp( var button )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	if ( file.pageStart == 0 )
		return

	file.pageStart = maxint( 0, file.pageStart - SERVER_ROWS_PER_PAGE )
	ServerBrowserShared_Redraw()
}

// ----- rows -----

void function ServerBrowserShared_OnRowClick( var button )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	ServerBrowserShared_SelectRow( Hud_GetScriptID( button ).tointeger() )
}

void function ServerBrowserShared_SelectRow( int row )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	int slot = file.pageStart + row

	if ( slot >= file.matches.len() )
		return

	file.selected = file.matches[slot]
	ServerBrowserShared_RefreshInfoPane()
	EmitUISound( "menu_accept" )
}

void function ServerBrowserShared_WireRowClickThrough( var panel, int row )
{
	array<string> names
	names.append( format( "ServerName%d", row ) )
	names.append( format( "PlayerCount%d", row ) )
	names.append( format( "Playlist%d", row ) )
	names.append( format( "Map%d", row ) )
	names.append( format( "ServerLocked%d", row ) )

	foreach ( string name in names )
	{
		if ( !Hud_HasChild( panel, name ) )
			continue

		Hud_AddEventHandler( Hud_GetChild( panel, name ), UIE_CLICK, void function( var button ) : ( row )
		{
			ServerBrowserShared_SelectRow( row )
		} )
	}
}

void function ServerBrowserShared_Redraw()
{
	if ( !ServerBrowserShared_IsBound() )
		return

	int totalPlayers = 0

	for ( int row = 0; row < SERVER_ROWS_PER_PAGE; row++ )
	{
		int slot = file.pageStart + row

		var rowButton = Hud_GetChild( file.panel, format( "ServerButton%d", row ) )
		var rowLocked = Hud_GetChild( file.panel, format( "ServerLocked%d", row ) )
		var nameLabel = Hud_GetChild( file.panel, format( "ServerName%d", row ) )
		var playerLabel = Hud_GetChild( file.panel, format( "PlayerCount%d", row ) )
		var playlistLabel = Hud_GetChild( file.panel, format( "Playlist%d", row ) )
		var mapLabel = Hud_GetChild( file.panel, format( "Map%d", row ) )

		if ( slot >= file.matches.len() )
		{
			Hud_SetVisible( rowButton, false )
			Hud_SetVisible( rowLocked, false )
			Hud_SetText( nameLabel, "" )
			Hud_SetText( playerLabel, "" )
			Hud_SetText( playlistLabel, "" )
			Hud_SetText( mapLabel, "" )
			continue
		}

		int index = file.matches[slot]

		Hud_SetVisible( rowButton, true )
		Hud_SetVisible( rowLocked, GetServerHasPassword( index ) )
		Hud_SetText( nameLabel, GetServerName( index ) )
		Hud_SetText( playerLabel, format( "%d/%d", GetServerCurrentPlayers( index ), GetServerMaxPlayers( index ) ) )
		Hud_SetText( playlistLabel, GetUIPlaylistName( GetServerPlaylist( index ) ) )
		Hud_SetText( mapLabel, GetUIMapName( GetServerMap( index ) ) )
	}

	int count = GetServerCount()
	for ( int i = 0; i < count; i++ )
		totalPlayers += GetServerCurrentPlayers( i )

	Hud_SetText( Hud_GetChild( file.panel, "PlayersCount" ), Localize( "#BRIDGE_SB_PLAYERS_FMT", format( "%d", totalPlayers ) ) )
	Hud_SetText( Hud_GetChild( file.panel, "ServersCount" ), Localize( "#BRIDGE_SB_SERVERS_FMT", format( "%d", count ) ) )

	bool haveRows = file.matches.len() > 0

	Hud_SetVisible( Hud_GetChild( file.panel, "ServerNameLine" ), haveRows )
	Hud_SetVisible( Hud_GetChild( file.panel, "PlayerCountLine" ), haveRows )
	Hud_SetVisible( Hud_GetChild( file.panel, "PlaylistLine" ), haveRows )
	Hud_SetVisible( Hud_GetChild( file.panel, "MapLine" ), haveRows )

	var noServers = Hud_GetChild( file.panel, "NoServersLbl" )
	Hud_SetVisible( noServers, !haveRows )
	if ( !haveRows )
		Hud_SetText( noServers, file.search != "" ? Localize( "#BRIDGE_SB_NO_MATCH" ) : Localize( "#BRIDGE_SB_NO_SERVERS" ) )

	ServerBrowserShared_RefreshInfoPane()
}

void function ServerBrowserShared_RefreshInfoPane()
{
	if ( !ServerBrowserShared_IsBound() )
		return

	if ( file.selected < 0 )
	{
		Hud_SetText( Hud_GetChild( file.panel, "ServerNameInfoEdit" ), Localize( "#BRIDGE_SB_NONE_SELECTED" ) )
		Hud_SetText( Hud_GetChild( file.panel, "ServerCurrentMapEdit" ), "--" )
		Hud_SetText( Hud_GetChild( file.panel, "PlaylistInfoEdit" ), "--" )
		Hud_SetText( Hud_GetChild( file.panel, "ServerDesc" ), "" )
		ServerBrowserShared_UpdatePreview( "", "", "" )
		return
	}

	int index = file.selected

	string map = GetServerMap( index )
	string playlist = GetServerPlaylist( index )

	Hud_SetText( Hud_GetChild( file.panel, "ServerNameInfoEdit" ), GetServerName( index ) )
	Hud_SetText( Hud_GetChild( file.panel, "ServerCurrentMapEdit" ), GetUIMapName( map ) )
	Hud_SetText( Hud_GetChild( file.panel, "PlaylistInfoEdit" ), GetUIPlaylistName( playlist ) )
	ServerBrowserShared_UpdatePreview( map, playlist, GetServerRegion( index ) )

	string desc = GetServerDescription( index )

	string region = GetServerRegion( index )
	if ( region != "" )
		desc = desc == "" ? region : desc + "\n" + region

	array<string> mods = GetServerRequiredMods( index )
	if ( mods.len() > 0 )
		desc = desc + format( "\nRequires %d mod(s)", mods.len() )

	Hud_SetText( Hud_GetChild( file.panel, "ServerDesc" ), desc )
}

void function ServerBrowserShared_UpdatePreview( string map, string playlist, string region )
{
	if ( !ServerBrowserShared_IsBound() )
		return
	if ( !Hud_HasChild( file.panel, "ServerMapImg" ) )
		return

	var rui = Hud_GetRui( Hud_GetChild( file.panel, "ServerMapImg" ) )
	RuiSetString( rui, "modeNameText", map == "" ? "" : GetUIMapName( map ) )
	RuiSetString( rui, "modeDescText", playlist == "" ? "" : GetUIPlaylistName( playlist ) )
	RuiSetString( rui, "playlistName", playlist )
	RuiSetString( rui, "playlistTypeText", region )
	RuiSetString( rui, "modeLockedReason", "" )
	RuiSetBool( rui, "alwaysShowDesc", map != "" || playlist != "" )
	RuiSetBool( rui, "showLockedIcon", false )

	if ( IsLobby() && IsConnected() && playlist != "" )
	{
		string imageKey = GetPlaylistVarString( playlist, "image", "" )
		RuiSetImage( rui, "modeImage", GetImageFromImageMap( imageKey ) )
		RuiSetImage( rui, "thumbnailImage", GetThumbnailImageFromImageMap( imageKey ) )
	}
}

// ----- connect -----

void function ServerBrowserShared_OnConnect( var button )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	if ( file.selected < 0 )
	{
		ServerBrowserShared_SetMessage( Localize( "#BRIDGE_SB_SELECT_FIRST" ) )
		EmitUISound( "menu_deny" )
		return
	}

	if ( !IsEULAAccepted() )
	{
		OpenEULADialog( false )
		EmitUISound( "menu_deny" )
		return
	}

	if ( Bridge_IsOfflineLaunch() )
	{
		ServerBrowserShared_SetMessage( Localize( "#BRIDGE_SB_OFFLINE_JOIN" ) )
		Bridge_ShowOfflineJoinError()
		return
	}

	if ( !Bridge_IsIdentityReady() )
	{
		ServerBrowserShared_SetMessage( Localize( "#BRIDGE_SIGNING_IN" ) )
		EmitUISound( "menu_deny" )
		return
	}

	int index = file.selected

	if ( !ServerListHasRequiredMods( index ) )
	{
		string joined = ""
		try
		{
			joined = GetServerMissingMods( index )
		}
		catch ( eMissing )
		{
			printt( format( "[MOD] GetServerMissingMods failed: %s", string( eMissing ) ) )
		}

		printt( "[MOD-POLICY] need: " + joined )

		if ( LauncherHandoff_IsAvailable() )
		{
			ServerBrowserShared_OfferLauncherInstall( index, joined )
			return
		}

		string message = joined != "" ? Localize( "#BRIDGE_SB_MISSING_LIST", joined ) : Localize( "#BRIDGE_SB_MISSING_MODS" )
		ConfirmDialogData data
		data.headerText = "#BRIDGE_SB_MISSING_HEADER"
		data.messageText = message
		OpenOKDialogFromData( data )

		ServerBrowserShared_SetMessage( message )
		EmitUISound( "menu_deny" )
		return
	}

	if ( GetServerHasPassword( index ) )
	{
		ServerBrowserShared_PromptPassword( index )
		return
	}

	ClearConnectPassword()
	ServerBrowserShared_KickoffConnect( index )
}

void function ServerBrowserShared_OfferLauncherInstall( int index, string missing )
{
	// The list can refresh while the dialog is open; only act on the same server.
	string serverName = GetServerName( index )

	ConfirmDialogData data
	data.headerText = "#BRIDGE_SB_INSTALL_MODS_HEADER"
	data.messageText = Localize( "#BRIDGE_SB_MISSING_LAUNCHER", missing )
	data.resultCallback = void function ( int result ) : ( index, serverName )
	{
		if ( result != eDialogResult.YES )
			return

		if ( index < GetServerCount() && GetServerName( index ) == serverName && LauncherHandoff_JoinListedServer( index ) )
			return

		ConfirmDialogData failed
		failed.headerText = "#BRIDGE_SB_MISSING_HEADER"
		failed.messageText = "#BRIDGE_SB_HANDOFF_FAILED"
		OpenOKDialogFromData( failed )
	}
	OpenConfirmDialogFromData( data )
}

void function ServerBrowserShared_PromptPassword( int index )
{
	string name = GetServerName( index )

	ConfirmDialogData data
	data.headerText = "#BRIDGE_SB_NEEDS_PASSWORD"
	data.messageText = name
	data.yesText = [ "#A_BUTTON_YES", "#BRIDGE_SB_CONNECT" ]

	OpenTextEntryDialogFromData( data, void function( string password ) : ( index )
	{
		string pw = strip( password )
		if ( pw == "" )
		{
			EmitUISound( "menu_deny" )
			return
		}

		if ( !ServerBrowserShared_IsBound() )
			return

		if ( index < 0 || index >= GetServerCount() )
		{
			ServerBrowserShared_SetMessage( Localize( "#BRIDGE_SB_SELECT_FIRST" ) )
			EmitUISound( "menu_deny" )
			return
		}

		SetConVarString( "bridge_connect_password", pw )
		ServerBrowserShared_KickoffConnect( index )
	} )
}

void function ServerBrowserShared_KickoffConnect( int index )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	ServerBrowserShared_SetMessage( Localize( "#BRIDGE_SB_CONNECTING", GetServerName( index ) ) )
	EmitUISound( "menu_accept" )

	ConnectToListedServer( index )

	var sbMenu = GetMenu( "ServerBrowserMenu" )
	if ( GetActiveMenu() == sbMenu || GetTopNonDialogMenu() == sbMenu )
		ServerBrowser_EnsureMainMenu()
}

// ----- helpers -----

void function ServerBrowserShared_SetMessage( string text )
{
	if ( !ServerBrowserShared_IsBound() )
		return

	var noServers = Hud_GetChild( file.panel, "NoServersLbl" )
	Hud_SetVisible( noServers, true )
	Hud_SetText( noServers, text )
}

void function ServerBrowserShared_ShowEmptyState()
{
	if ( !ServerBrowserShared_IsBound() )
		return

	file.matches.clear()
	file.pageStart = 0
	file.selected = -1

	Hud_SetVisible( Hud_GetChild( file.panel, "ServerNameLine" ), false )
	Hud_SetVisible( Hud_GetChild( file.panel, "PlayerCountLine" ), false )
	Hud_SetVisible( Hud_GetChild( file.panel, "PlaylistLine" ), false )
	Hud_SetVisible( Hud_GetChild( file.panel, "MapLine" ), false )

	if ( Hud_HasChild( file.panel, "NoSteamLbl" ) )
		Hud_SetVisible( Hud_GetChild( file.panel, "NoSteamLbl" ), false )

	var noServers = Hud_GetChild( file.panel, "NoServersLbl" )
	Hud_SetVisible( noServers, true )
	Hud_SetText( noServers, Localize( "#BRIDGE_SB_LOADING" ) )

	Hud_SetText( Hud_GetChild( file.panel, "PlayersCount" ), Localize( "#BRIDGE_SB_PLAYERS_DASH" ) )
	Hud_SetText( Hud_GetChild( file.panel, "ServersCount" ), Localize( "#BRIDGE_SB_SERVERS_DASH" ) )

	Hud_SetText( Hud_GetChild( file.panel, "ServerCurrentPlaylist" ), Localize( "#BRIDGE_SB_CURRENT_PLAYLIST" ) )
	Hud_SetText( Hud_GetChild( file.panel, "ServerCurrentMap" ), Localize( "#BRIDGE_SB_CURRENT_MAP" ) )

	ServerBrowserShared_RefreshInfoPane()

	if ( file.menu != null )
	{
		foreach ( var elem in GetElementsByClassname( file.menu, "ServerLabels" ) )
			Hud_SetText( elem, "" )

		foreach ( var elem in GetElementsByClassname( file.menu, "ServLocked" ) )
			Hud_SetVisible( elem, false )
	}
}
