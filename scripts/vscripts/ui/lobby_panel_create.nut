// UI-only Create tab: local server settings surface.
// Host / changelevel via RCON is intentionally NOT wired yet.

global function InitCreatePanel
global function InitR5RNamePanel
global function InitR5RDescPanel

global function SetSelectedServerMap
global function SetSelectedServerPlaylist
global function SetSelectedServerVis

global function GetUIPlaylistName
global function GetUIMapName
global function GetUIMapAsset
global function GetUIVisibilityName
global function GetCreatePlaylistMaps

// Keep in lockstep with any future native host visibility enum.
global enum eServerVisibility
{
	OFFLINE,
	HIDDEN,
	PUBLIC
}

global struct ServerStruct
{
	string svServerName
	string svServerDesc
	string svMapName
	string svPlaylist
	int svVisibility
}

global ServerStruct ServerSettings
global bool pmatch_MenuOpen = false

struct
{
	var menu
	var panel
	var namepanel
	var descpanel
	array<var> panels
} file

// Readable names for maps the bridge actually ships / targets.
global table<string, string> CreateMapNames = {
	[ "mp_rr_canyonlands_staging" ] = "Firing Range (Classic)",
	[ "mp_rr_canyonlands_64k_x_64k" ] = "King's Canyon S1",
	[ "mp_rr_canyonlands_mu1" ] = "King's Canyon S2",
	[ "mp_rr_canyonlands_mu1_night" ] = "King's Canyon After Dark",
	[ "mp_rr_canyonlands_mu2" ] = "King's Canyon S5",
	[ "mp_rr_desertlands_64k_x_64k" ] = "World's Edge S3",
	[ "mp_rr_desertlands_mu1" ] = "World's Edge S4",
	[ "mp_rr_desertlands_mu2" ] = "World's Edge S6",
	[ "mp_rr_desertlands_holiday" ] = "World's Edge Winter Express",
	[ "mp_rr_olympus" ] = "Olympus",
	[ "mp_rr_olympus_mu1" ] = "Olympus MU1",
	[ "mp_rr_party_crasher" ] = "Party Crasher",
	[ "mp_rr_arena_composite" ] = "Drop Off",
	[ "mp_rr_arena_skygarden" ] = "Encore",
	[ "mp_rr_aqueduct" ] = "Overflow",
	[ "mp_rr_district" ] = "E-District",
	[ "mp_lobby" ] = "Lobby"
}

global table<int, string> CreateVisibilityNames = {
	[ eServerVisibility.OFFLINE ] = "Offline",
	[ eServerVisibility.HIDDEN ] = "Hidden",
	[ eServerVisibility.PUBLIC ] = "Public"
}

// S21 does not ship S3 rui/menu/maps/*_big_icon set.
// Use a known-good stock image until map preview assets are ported.
const asset CREATE_MAP_PREVIEW_FALLBACK = $"rui/menu/character_skills/background"
const asset CREATE_MAP_PREVIEW_NONE = $"rui/menu/gamemode/playlist_bg_none"

void function InitR5RNamePanel( var panel )
{
	file.namepanel = panel
	AddButtonEventHandler( Hud_GetChild( panel, "BtnSaveName" ), UIE_CLICK, UpdateServerName )
}

void function InitR5RDescPanel( var panel )
{
	file.descpanel = panel
	AddButtonEventHandler( Hud_GetChild( panel, "BtnSaveDesc" ), UIE_CLICK, UpdateServerDesc )
}

void function PopupPanel_OnNavBack( var panel )
{
	foreach ( p in file.panels )
		Hud_SetVisible( p, false )
	pmatch_MenuOpen = false
}

void function InitCreatePanel( var panel )
{
	SetPanelTabTitle( panel, "Create" )
	file.panel = panel
	file.menu = GetParentMenu( file.panel )

	Hud_AddEventHandler( Hud_GetChild( file.panel, "BtnStartGame" ), UIE_CLICK, StartNewGame )

	array<var> buttons = GetElementsByClassname( file.menu, "createserverbuttons" )
	foreach ( var elem in buttons )
		Hud_AddEventHandler( elem, UIE_CLICK, OpenSelectedPanel )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, CreatePanel_OnShow )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, CreatePanel_OnHide )
	AddPanelEventHandler( panel, eUIEvent.PANEL_NAVBACK, PopupPanel_OnNavBack )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	file.panels.append( Hud_GetChild( file.panel, "R5RMapPanel" ) )
	file.panels.append( Hud_GetChild( file.panel, "R5RPlaylistPanel" ) )
	file.panels.append( Hud_GetChild( file.panel, "R5RVisPanel" ) )
	file.panels.append( Hud_GetChild( file.panel, "R5RNamePanel" ) )
	file.panels.append( Hud_GetChild( file.panel, "R5RDescPanel" ) )

	// Defaults: firing range / offline local host.
	ServerSettings.svServerName = "My local server"
	ServerSettings.svServerDesc = "S21 bridge local server"
	ServerSettings.svMapName = "mp_rr_canyonlands_staging"
	ServerSettings.svPlaylist = "survival_dev"
	ServerSettings.svVisibility = eServerVisibility.OFFLINE
}

void function CreatePanel_OnShow( var panel )
{
	// WEAPON_CATEGORY = S21 armory cam (S21-safe). Do not use BRIDGE_CREATE /
	// store_inspect presentation — that path was corrupting Legends locker framing.
	UI_SetPresentationType( ePresentationType.WEAPON_CATEGORY )

	foreach ( p in file.panels )
		Hud_SetVisible( p, false )
	pmatch_MenuOpen = false

	RefreshUIPlaylists()
	RefreshUIMaps()
	CreatePanel_RefreshSummary()

	Hud_SetText( Hud_GetChild( file.panel, "CreateStatusText" ), "UI only — host/RCON not wired" )
}

void function CreatePanel_OnHide( var panel )
{
	foreach ( p in file.panels )
		Hud_SetVisible( p, false )
	pmatch_MenuOpen = false
}

void function CreatePanel_RefreshSummary()
{
	Hud_SetText( Hud_GetChild( file.panel, "PlaylistInfoEdit" ), GetUIPlaylistName( ServerSettings.svPlaylist ) )
	Hud_SetText( Hud_GetChild( file.panel, "VisInfoEdit" ), GetUIVisibilityName( ServerSettings.svVisibility ) )
	Hud_SetText( Hud_GetChild( file.panel, "MapServerNameInfoEdit" ), ServerSettings.svServerName )

	// basic_image arg (S21); not S3 loadscreenImage.
	RuiSetImage( Hud_GetRui( Hud_GetChild( file.panel, "ServerMapImg" ) ), "basicImage", GetUIMapAsset( ServerSettings.svMapName ) )
}

void function OpenSelectedPanel( var button )
{
	int scriptId = Hud_GetScriptID( button ).tointeger()
	ShowSelectedPanel( file.panels[scriptId] )
	pmatch_MenuOpen = true

	switch ( scriptId )
	{
		case 3:
			Hud_SetText( Hud_GetChild( file.namepanel, "BtnServerName" ), ServerSettings.svServerName )
			break
		case 4:
			Hud_SetText( Hud_GetChild( file.descpanel, "BtnServerDesc" ), ServerSettings.svServerDesc )
			break
	}
}

// Changes the level on the local server. This does not start a server: one has to
// already be running, because the client cannot host.
void function StartNewGame( var button )
{
	string map = ServerSettings.svMapName
	string playlist = ServerSettings.svPlaylist

	var status = Hud_GetChild( file.panel, "CreateStatusText" )

	if ( map == "" )
	{
		Hud_SetText( status, Localize( "#BRIDGE_CREATE_PICK_MAP" ) )
		EmitUISound( "menu_deny" )
		return
	}

	// One server command: the playlist has to be parsed, mp_gamemode set, and the
	// pending map cleared before the changelevel, and only the server side can
	// sequence that. Two separate commands cannot.
	if ( playlist == "" )
	{
		Hud_SetText( status, Localize( "#BRIDGE_CREATE_PICK_MAP" ) )
		EmitUISound( "menu_deny" )
		return
	}

	ClientCommand( "bridge_rcon bridge_setmode " + playlist + " " + map )

	Hud_SetText( status, Localize( "#BRIDGE_CREATE_CHANGING_LEVEL", map ) )
	EmitUISound( "menu_accept" )
}

void function SetSelectedServerMap( string map )
{
	pmatch_MenuOpen = false
	ServerSettings.svMapName = map
	Hud_SetVisible( file.panels[0], false )
	RuiSetImage( Hud_GetRui( Hud_GetChild( file.panel, "ServerMapImg" ) ), "basicImage", GetUIMapAsset( ServerSettings.svMapName ) )
}

void function SetSelectedServerPlaylist( string playlist )
{
	pmatch_MenuOpen = false
	ServerSettings.svPlaylist = playlist

	array<string> playlist_maps = GetCreatePlaylistMaps( ServerSettings.svPlaylist )
	Hud_SetVisible( file.panels[1], false )
	Hud_SetText( Hud_GetChild( file.panel, "PlaylistInfoEdit" ), GetUIPlaylistName( ServerSettings.svPlaylist ) )

	if ( playlist_maps.len() == 0 )
	{
		SetSelectedServerMap( "mp_rr_canyonlands_staging" )
		RefreshUIMaps()
		return
	}

	if ( !playlist_maps.contains( ServerSettings.svMapName ) )
		SetSelectedServerMap( playlist_maps[0] )

	RefreshUIMaps()
}

void function SetSelectedServerVis( int vis )
{
	pmatch_MenuOpen = false
	ServerSettings.svVisibility = vis
	Hud_SetVisible( file.panels[2], false )
	Hud_SetText( Hud_GetChild( file.panel, "VisInfoEdit" ), GetUIVisibilityName( ServerSettings.svVisibility ) )
}

void function ShowSelectedPanel( var panel )
{
	foreach ( p in file.panels )
		Hud_SetVisible( p, false )
	Hud_SetVisible( panel, true )
}

void function UpdateServerName( var button )
{
	pmatch_MenuOpen = false
	ServerSettings.svServerName = Hud_GetUTF8Text( Hud_GetChild( file.namepanel, "BtnServerName" ) )
	Hud_SetVisible( file.namepanel, false )
	Hud_SetText( Hud_GetChild( file.panel, "MapServerNameInfoEdit" ), ServerSettings.svServerName )
}

void function UpdateServerDesc( var button )
{
	pmatch_MenuOpen = false
	ServerSettings.svServerDesc = Hud_GetUTF8Text( Hud_GetChild( file.descpanel, "BtnServerDesc" ) )
	Hud_SetVisible( file.descpanel, false )
}

string function GetUIPlaylistName( string playlist )
{
	if ( !IsLobby() || !IsConnected() )
		return playlist

	string name = GetPlaylistVarString( playlist, "name", playlist )
	if ( name == "" )
		return playlist
	return name
}

string function GetUIMapName( string map )
{
	if ( map in CreateMapNames )
		return CreateMapNames[map]
	return map
}

string function GetUIVisibilityName( int vis )
{
	if ( vis in CreateVisibilityNames )
		return CreateVisibilityNames[vis]
	return "Unknown"
}

asset function GetUIMapAsset( string map, bool gamemode_assets = false )
{
	// TODO: port S21 map preview images (or map loadscreen uii) and key them here.
	// Until then keep a stable stock image so the panel never refs missing S3 rui.
	if ( map == "" )
		return CREATE_MAP_PREVIEW_NONE
	return CREATE_MAP_PREVIEW_FALLBACK
}

// Shared helper for map sub-panel — playlist -> maps with bridge fallbacks.
array<string> function GetCreatePlaylistMaps( string playlistName )
{
	array<string> maps

	// S21 script helper (sh_playlists) — safe from UI when playlists loaded.
	array<string> engineMaps = GetPlaylistMaps( playlistName )
	if ( engineMaps.len() > 0 )
		return engineMaps

	// Fallback set for offline / incomplete playlist data.
	// TODO(bridge-create): drive this from a bridge map catalog once host path lands.
	maps.append( "mp_rr_canyonlands_staging" )
	maps.append( "mp_rr_canyonlands_mu1" )
	maps.append( "mp_rr_desertlands_mu1" )
	maps.append( "mp_rr_olympus_mu1" )
	maps.append( "mp_rr_district" )
	maps.append( "mp_rr_party_crasher" )
	return maps
}
