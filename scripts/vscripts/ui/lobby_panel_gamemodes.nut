// Gamemode selector. Every row is built from the engine's playlist table, which is
// the server's own table whenever we are connected -- the dedi ships its whole
// playlist file at signon. Nothing here parses the file itself.

global function InitGamemodesPanel

// 0..2 are both a classification and a view; ALL is a view only; OTHER is a
// classification only and surfaces under the ALL view.
global enum eGamemodeCategory
{
	BATTLE_ROYALE,
	MIXTAPE,
	SANDBOX,
	ALL,
	OTHER
}

const array<string> GAMEMODE_CATEGORY_TITLES = [
	"BATTLE ROYALE", "MIXTAPE", "SANDBOX", "ALL"
]

// Maps present as both a client rpak and a dedi rpak + VPK on this install.
// Interim source: g_InstalledMaps is empty in client.dll, so GetAvailableMaps
// cannot answer this yet. Rows whose maps are missing here are shown locked
// rather than hidden, so a wrong entry reads as a data problem, not a gap.
const table<string, bool> GAMEMODE_INSTALLED_MAPS = {
	mp_lobby = true,
	mp_rr_angel_city = true,
	mp_rr_arena_habitat = true,
	mp_rr_arena_phase_runner = true,
	mp_rr_boneyard = true,
	mp_rr_canyonlands_hu = true,
	mp_rr_canyonlands_staging = true,
	mp_rr_canyonlands_staging_mu1 = true,
	mp_rr_crashsite = true,
	mp_rr_desertlands_hu = true,
	mp_rr_district = true,
	mp_rr_district_mu1 = true,
	mp_rr_divided_moon_mu1 = true,
	mp_rr_freedm_skulltown = true,
	mp_rr_freedm_skulltown_s27 = true,
	mp_rr_olympus_mu2 = true,
	mp_rr_party_crasher = true,
	mp_rr_thunderdome = true,
	mp_rr_tropic_island_mu2 = true
}

// Installed maps with no #MP_RR_* token reachable from any playlist entry.
const table<string, string> GAMEMODE_MAP_TITLE_OVERRIDES = {
	mp_lobby = "Lobby",
	mp_rr_angel_city = "Angel City",
	mp_rr_boneyard = "Boneyard",
	mp_rr_crashsite = "Crash Site",
	mp_rr_district_mu1 = "E-District MU1",
	mp_rr_freedm_skulltown = "Skull Town",
	mp_rr_freedm_skulltown_s27 = "Skull Town (Revamped)"
}

// Group order per category. A group with no entries is skipped.
const array<string> GAMEMODE_GROUPS_BR = [
	"TRIOS", "DUOS", "QUADS", "SOLO", "SQUADS", "RANKED", "BOTS"
]
const array<string> GAMEMODE_GROUPS_MIXTAPE = [
	"TEAM DEATHMATCH", "BIG TEAM DEATHMATCH", "GUN GAME", "CONTROL", "LOCKDOWN", "MIXTAPE"
]
const array<string> GAMEMODE_GROUPS_SANDBOX = [
	"FIRING RANGE", "TRAINING", "FREE ROAM"
]
const array<string> GAMEMODE_GROUPS_ALL = [
	"BATTLE ROYALE", "MIXTAPE", "SANDBOX", "OTHER"
]

struct GamemodeEntry
{
	string playlistId
	string mapName
	string title
	string mapTitle
	string desc
	string imageKey
	string groupKey
	int    category
	int    maxTeams
	int    maxPlayers
	int    squadSize
	bool   servable
	bool   isPrivateMatch
	bool   isLimitedMode
}

struct GamemodeRow
{
	bool   isHeader
	string headerText
	int    entryIdx
}

struct
{
	var menu
	var panel
	var listPanel
	var preview

	int activeCategory = eGamemodeCategory.BATTLE_ROYALE

	// selectedEntry is what SET ON SERVER acts on and only a click changes it.
	// hoverEntry only drives the preview -- merging the two meant that moving the
	// cursor from a row to the button re-pointed the selection at whatever it
	// passed over.
	int selectedEntry = -1
	int hoverEntry = -1

	array<GamemodeEntry> entries
	array<GamemodeRow> rows
	array<var> categoryButtons

	// Rebuilt every refresh: a shorter category leaves stale buttons behind, and a
	// stale row->entry mapping is another way to act on the wrong mode.
	table<var, int> rowButtonToIndex
	table<var, bool> rowHandlerBound

	int skippedNoMaps = 0
	int skippedHidden = 0
} file


void function InitGamemodesPanel( var panel )
{
	SetPanelTabTitle( panel, "Modes" )
	file.panel = panel
	file.menu = GetParentMenu( panel )

	if ( Hud_HasChild( panel, "ModeList" ) )
		file.listPanel = Hud_GetChild( panel, "ModeList" )

	if ( Hud_HasChild( panel, "ModePreview" ) )
		file.preview = Hud_GetChild( panel, "ModePreview" )

	foreach ( var button in GetElementsByClassname( file.menu, "GamemodeCategoryButton" ) )
	{
		file.categoryButtons.append( button )
		Hud_AddEventHandler( button, UIE_CLICK, GamemodesPanel_OnCategoryClick )
	}

	if ( Hud_HasChild( panel, "BtnApplyMode" ) )
		Hud_AddEventHandler( Hud_GetChild( panel, "BtnApplyMode" ), UIE_CLICK, GamemodesPanel_OnApply )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, GamemodesPanel_OnShow )
	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )
}


void function GamemodesPanel_OnShow( var panel )
{
	// WEAPON_CATEGORY is the S21 armory cam. BRIDGE_CREATE / STORE_INSPECT
	// corrupt the Legends locker framing once this panel is left.
	UI_SetPresentationType( ePresentationType.WEAPON_CATEGORY )

	GamemodesPanel_BuildCatalog()
	GamemodesPanel_Rebuild()
	GamemodesPanel_SetStatus( "" )
}


//-----------------------------------------------------------------------------
// Catalog
//-----------------------------------------------------------------------------
void function GamemodesPanel_BuildCatalog()
{
	file.entries = []
	file.skippedNoMaps = 0
	file.skippedHidden = 0

	int count = GetPlaylistCount()
	for ( int i = 0; i < count; i++ )
	{
		string playlistId = string( GetPlaylistName( i ) )
		if ( playlistId == "" )
			continue

		if ( !GetPlaylistVarBool( playlistId, "visible", false ) )
		{
			file.skippedHidden++
			continue
		}

		array<string> maps = GetPlaylistMaps( playlistId )
		if ( maps.len() == 0 )
		{
			// Inheritance parents (control_base, freedm_tdm,...) resolve to no map
			// and are not playable.
			file.skippedNoMaps++
			continue
		}

		string uiSlot   = GetPlaylistVarString( playlistId, "ui_slot", "" )
		string gamemode = GamemodesPanel_GetGamemode( playlistId )
		int category    = GamemodesPanel_ClassifyCategory( playlistId, gamemode, uiSlot )

		foreach ( string mapName in maps )
		{
			GamemodeEntry entry
			entry.playlistId     = playlistId
			entry.mapName        = mapName
			entry.title          = GamemodesPanel_LocalizeVar( playlistId, "name", playlistId )
			entry.desc           = GamemodesPanel_LocalizeVar( playlistId, "description", "" )
			entry.mapTitle       = GamemodesPanel_GetMapTitle( playlistId, mapName )
			entry.imageKey       = GetPlaylistVarString( playlistId, "image", "" )
			entry.category       = category
			entry.maxTeams       = GetPlaylistVarInt( playlistId, "max_teams", 0 )
			entry.maxPlayers     = GetPlaylistVarInt( playlistId, "max_players", 0 )
			entry.squadSize      = GamemodesPanel_SquadSize( entry.maxPlayers, entry.maxTeams,
				GetPlaylistVarInt( playlistId, "max_team_size", 0 ) )
			entry.isPrivateMatch = GetPlaylistVarBool( playlistId, "private_match", false )
			entry.isLimitedMode  = GetPlaylistVarBool( playlistId, "is_limited_mode", false )
			entry.servable       = mapName in GAMEMODE_INSTALLED_MAPS
			entry.groupKey       = GamemodesPanel_GroupKey( entry, gamemode )

			file.entries.append( entry )
		}
	}
}


// max_team_size is set on only a minority of playlists; max_players / max_teams is
// the field pair that is actually populated (60/20 = trios, 60/30 = duos).
int function GamemodesPanel_SquadSize( int maxPlayers, int maxTeams, int maxTeamSize )
{
	if ( maxTeamSize > 0 )
		return maxTeamSize

	if ( maxPlayers > 0 && maxTeams > 0 )
		return maxPlayers / maxTeams

	return 0
}


string function GamemodesPanel_GetGamemode( string playlistId )
{
	// One gamemode block per playlist in practice; the first is the one the dedi runs.
	int modeCount = GetPlaylistGamemodesCount( playlistId )
	if ( modeCount <= 0 )
		return ""

	return GetPlaylistGamemodeByIndex( playlistId, 0 )
}


string function GamemodesPanel_LocalizeVar( string playlistId, string varName, string fallback )
{
	string token = GetPlaylistVarString( playlistId, varName, "" )
	if ( token == "" || token == "#EMPTY_STRING" )
		return fallback

	return Localize( token )
}


string function GamemodesPanel_GetMapTitle( string playlistId, string mapName )
{
	if ( mapName in GAMEMODE_MAP_TITLE_OVERRIDES )
		return GAMEMODE_MAP_TITLE_OVERRIDES[mapName]

	string token = GetPlaylistVarString( playlistId, "map_name", "" )
	if ( token != "" && token != "#EMPTY_STRING" )
		return Localize( token )

	return mapName
}


int function GamemodesPanel_ClassifyCategory( string playlistId, string gamemode, string uiSlot )
{
	if ( uiSlot == "training" || uiSlot == "firing_range" )
		return eGamemodeCategory.SANDBOX

	if ( playlistId.find( "firingrange" ) != -1
		|| playlistId.find( "training" ) != -1
		|| playlistId.find( "staging" ) != -1
		|| playlistId.find( "_dev" ) != -1 )
		return eGamemodeCategory.SANDBOX

	if ( gamemode == "control" || gamemode == "freedm" )
		return eGamemodeCategory.MIXTAPE

	if ( gamemode == "survival" )
		return eGamemodeCategory.BATTLE_ROYALE

	return eGamemodeCategory.OTHER
}


string function GamemodesPanel_GroupKey( GamemodeEntry entry, string gamemode )
{
	string id = entry.playlistId

	switch ( entry.category )
	{
		case eGamemodeCategory.SANDBOX:
			if ( id.find( "firingrange" ) != -1 )
				return "FIRING RANGE"
			if ( id.find( "training" ) != -1 )
				return "TRAINING"
			return "FREE ROAM"

		case eGamemodeCategory.MIXTAPE:
			if ( gamemode == "control" )
				return "CONTROL"
			if ( id.find( "btdm" ) != -1 )
				return "BIG TEAM DEATHMATCH"
			if ( id.find( "tdm" ) != -1 )
				return "TEAM DEATHMATCH"
			if ( id.find( "gungame" ) != -1 || id.find( "gg_" ) != -1 )
				return "GUN GAME"
			if ( id.find( "tr_hunt" ) != -1 )
				return "LOCKDOWN"
			return "MIXTAPE"

		case eGamemodeCategory.BATTLE_ROYALE:
			if ( id.find( "ranked" ) != -1 )
				return "RANKED"
			if ( id.find( "bots" ) != -1 )
				return "BOTS"

			// Squad size, not private_match: bucketing every custom/tournament
			// variant together buried the ordinary modes under 32 near-duplicates.
			// The [PRIVATE] badge still marks them.
			switch ( entry.squadSize )
			{
				case 1: return "SOLO"
				case 2: return "DUOS"
				case 3: return "TRIOS"
				case 4: return "QUADS"
			}
			return "SQUADS"
	}

	return "OTHER"
}


// Group key used when the ALL category flattens every entry.
string function GamemodesPanel_AllGroupKey( GamemodeEntry entry )
{
	switch ( entry.category )
	{
		case eGamemodeCategory.BATTLE_ROYALE: return "BATTLE ROYALE"
		case eGamemodeCategory.MIXTAPE:       return "MIXTAPE"
		case eGamemodeCategory.SANDBOX:       return "SANDBOX"
	}
	return "OTHER"
}


array<string> function GamemodesPanel_GroupOrder( int category )
{
	switch ( category )
	{
		case eGamemodeCategory.BATTLE_ROYALE: return GAMEMODE_GROUPS_BR
		case eGamemodeCategory.MIXTAPE:       return GAMEMODE_GROUPS_MIXTAPE
		case eGamemodeCategory.SANDBOX:       return GAMEMODE_GROUPS_SANDBOX
	}
	return GAMEMODE_GROUPS_ALL
}


//-----------------------------------------------------------------------------
// Rows
//-----------------------------------------------------------------------------
void function GamemodesPanel_BuildRows()
{
	file.rows = []

	bool isAll = file.activeCategory == eGamemodeCategory.ALL
	array<string> groupOrder = GamemodesPanel_GroupOrder( file.activeCategory )

	foreach ( string groupKey in groupOrder )
	{
		array<int> inGroup = []

		foreach ( int idx, GamemodeEntry entry in file.entries )
		{
			if ( !isAll && entry.category != file.activeCategory )
				continue

			string entryGroup = isAll ? GamemodesPanel_AllGroupKey( entry ) : entry.groupKey
			if ( entryGroup != groupKey )
				continue

			inGroup.append( idx )
		}

		if ( inGroup.len() == 0 )
			continue

		GamemodeRow header
		header.isHeader   = true
		header.headerText = format( "%s  (%d)", groupKey, inGroup.len() )
		header.entryIdx   = -1
		file.rows.append( header )

		foreach ( int idx in inGroup )
		{
			GamemodeRow row
			row.isHeader = false
			row.entryIdx = idx
			file.rows.append( row )
		}
	}
}


void function GamemodesPanel_Rebuild()
{
	if ( file.listPanel == null )
		return

	GamemodesPanel_BuildRows()

	var scrollPanel = Hud_GetChild( file.listPanel, "ScrollPanel" )
	Hud_InitGridButtons( file.listPanel, file.rows.len() )

	// Start from an empty mapping so buttons left over from a longer category
	// cannot answer with an entry that is no longer on screen.
	file.rowButtonToIndex = {}

	int lockedCount = 0

	foreach ( int rowIdx, GamemodeRow row in file.rows )
	{
		if ( !Hud_HasChild( scrollPanel, "GridButton" + rowIdx ) )
			break

		var button = Hud_GetChild( scrollPanel, "GridButton" + rowIdx )

		if ( row.isHeader )
		{
			RuiSetString( Hud_GetRui( button ), "buttonText", row.headerText )
			Hud_SetEnabled( button, false )
			file.rowButtonToIndex[button] <- -1
			continue
		}

		// Not-servable rows stay focusable so the detail pane can say which map is
		// missing; the apply path is what refuses them.
		Hud_SetEnabled( button, true )

		if ( !file.entries[row.entryIdx].servable )
			lockedCount++

		if ( !( button in file.rowHandlerBound ) )
		{
			Hud_AddEventHandler( button, UIE_CLICK, GamemodesPanel_OnRowClick )
			Hud_AddEventHandler( button, UIE_GET_FOCUS, GamemodesPanel_OnRowFocus )
			Hud_AddEventHandler( button, UIE_LOSE_FOCUS, GamemodesPanel_OnRowLoseFocus )
			file.rowHandlerBound[button] <- true
		}
		file.rowButtonToIndex[button] <- row.entryIdx
	}

	GamemodesPanel_UpdateCategoryButtons()
	GamemodesPanel_SetFooter( lockedCount )

	// Select the first selectable row so the panel is never blank and SET ON SERVER
	// always has a target.
	int firstEntry = -1
	foreach ( GamemodeRow row in file.rows )
	{
		if ( !row.isHeader )
		{
			firstEntry = row.entryIdx
			break
		}
	}

	file.selectedEntry = firstEntry
	file.hoverEntry = -1
	GamemodesPanel_RefreshRowLabels()
	GamemodesPanel_ShowEntry( firstEntry )
}


// Row labels carry the selection marker, so they are re-set whenever the
// selection moves rather than only on a full rebuild.
void function GamemodesPanel_RefreshRowLabels()
{
	if ( file.listPanel == null )
		return

	var scrollPanel = Hud_GetChild( file.listPanel, "ScrollPanel" )

	foreach ( int rowIdx, GamemodeRow row in file.rows )
	{
		if ( row.isHeader )
			continue
		if ( !Hud_HasChild( scrollPanel, "GridButton" + rowIdx ) )
			break

		var button = Hud_GetChild( scrollPanel, "GridButton" + rowIdx )
		RuiSetString( Hud_GetRui( button ), "buttonText",
			GamemodesPanel_RowText( file.entries[row.entryIdx], row.entryIdx == file.selectedEntry ) )
	}
}


string function GamemodesPanel_RowText( GamemodeEntry entry, bool isSelected )
{
	string badges = ""

	if ( !entry.servable )
		badges += "  [NO MAP]"
	if ( entry.isLimitedMode )
		badges += "  [LTM]"
	if ( entry.isPrivateMatch )
		badges += "  [PRIVATE]"

	return format( "%s%s  -  %s%s", isSelected ? "> " : "", entry.title, entry.mapTitle, badges )
}


void function GamemodesPanel_SetFooter( int lockedCount )
{
	if ( !Hud_HasChild( file.panel, "ListFooterText" ) )
		return

	Hud_SetText( Hud_GetChild( file.panel, "ListFooterText" ),
		format( "%d rows  -  %d not installed  -  skipped: %d hidden, %d with no map (of %d playlists)",
			file.rows.len(), lockedCount, file.skippedHidden, file.skippedNoMaps, GetPlaylistCount() ) )
}


// generic_button only exposes buttonText, so the active category is marked in the
// label rather than through a selected-state rui arg.
void function GamemodesPanel_UpdateCategoryButtons()
{
	foreach ( var button in file.categoryButtons )
	{
		int id = Hud_GetScriptID( button ).tointeger()
		if ( id < 0 || id >= GAMEMODE_CATEGORY_TITLES.len() )
			continue

		string title = GAMEMODE_CATEGORY_TITLES[id]
		RuiSetString( Hud_GetRui( button ), "buttonText",
			id == file.activeCategory ? format( "> %s <", title ) : title )
	}
}


//-----------------------------------------------------------------------------
// Detail pane
//-----------------------------------------------------------------------------
// Paints the preview + detail pane only. The selection lives in file.selectedEntry.
void function GamemodesPanel_ShowEntry( int entryIdx )
{
	if ( entryIdx < 0 || entryIdx >= file.entries.len() )
	{
		GamemodesPanel_SetDetailText( "", "", "", "", "" )
		return
	}

	GamemodeEntry entry = file.entries[entryIdx]

	if ( file.preview != null )
	{
		var rui = Hud_GetRui( file.preview )
		RuiSetString( rui, "modeNameText", entry.title )
		RuiSetString( rui, "modeDescText", entry.mapTitle )
		RuiSetString( rui, "playlistName", entry.playlistId )
		RuiSetString( rui, "playlistTypeText", entry.groupKey )
		RuiSetString( rui, "modeLockedReason", entry.servable ? "" : "MAP NOT INSTALLED" )
		RuiSetBool( rui, "alwaysShowDesc", true )
		RuiSetBool( rui, "showLockedIcon", !entry.servable )
		RuiSetImage( rui, "modeImage", GetImageFromImageMap( entry.imageKey ) )
		RuiSetImage( rui, "thumbnailImage", GetThumbnailImageFromImageMap( entry.imageKey ) )
	}

	string shape = entry.maxTeams > 0 && entry.squadSize > 0
		? format( "%d teams of %d  -  %d players", entry.maxTeams, entry.squadSize, entry.maxPlayers )
		: format( "%d players", entry.maxPlayers )

	GamemodesPanel_SetDetailText(
		entry.title,
		entry.mapTitle,
		entry.desc,
		shape,
		format( "%s  /  %s", entry.playlistId, entry.mapName ) )
}


void function GamemodesPanel_SetDetailText( string title, string subtitle, string desc, string shape, string idText )
{
	if ( Hud_HasChild( file.panel, "DetailTitle" ) )
		Hud_SetText( Hud_GetChild( file.panel, "DetailTitle" ), title )
	if ( Hud_HasChild( file.panel, "DetailSubtitle" ) )
		Hud_SetText( Hud_GetChild( file.panel, "DetailSubtitle" ), subtitle )
	if ( Hud_HasChild( file.panel, "DetailDesc" ) )
		Hud_SetText( Hud_GetChild( file.panel, "DetailDesc" ), desc )
	if ( Hud_HasChild( file.panel, "DetailShape" ) )
		Hud_SetText( Hud_GetChild( file.panel, "DetailShape" ), shape )
	if ( Hud_HasChild( file.panel, "DetailIdText" ) )
		Hud_SetText( Hud_GetChild( file.panel, "DetailIdText" ), idText )
}


void function GamemodesPanel_SetStatus( string text )
{
	if ( Hud_HasChild( file.panel, "StatusText" ) )
		Hud_SetText( Hud_GetChild( file.panel, "StatusText" ), text )
}


//-----------------------------------------------------------------------------
// Input
//-----------------------------------------------------------------------------
void function GamemodesPanel_OnCategoryClick( var button )
{
	int id = Hud_GetScriptID( button ).tointeger()
	if ( id < 0 || id >= GAMEMODE_CATEGORY_TITLES.len() )
		return

	EmitUISound( "menu_accept" )
	file.activeCategory = id
	GamemodesPanel_Rebuild()
}


// Hovering only previews. It must not move the selection, or walking the cursor
// over to SET ON SERVER would re-point it at the last row passed.
void function GamemodesPanel_OnRowFocus( var button )
{
	if ( !( button in file.rowButtonToIndex ) )
		return

	int entryIdx = file.rowButtonToIndex[button]
	if ( entryIdx < 0 )
		return

	file.hoverEntry = entryIdx
	GamemodesPanel_ShowEntry( entryIdx )
}


void function GamemodesPanel_OnRowLoseFocus( var button )
{
	if ( !( button in file.rowButtonToIndex ) )
		return
	if ( file.rowButtonToIndex[button] != file.hoverEntry )
		return

	// Back to whatever is actually selected, so the pane always agrees with what
	// SET ON SERVER will do.
	file.hoverEntry = -1
	GamemodesPanel_ShowEntry( file.selectedEntry )
}


void function GamemodesPanel_OnRowClick( var button )
{
	if ( !( button in file.rowButtonToIndex ) )
		return

	int entryIdx = file.rowButtonToIndex[button]
	if ( entryIdx < 0 )
		return

	EmitUISound( "menu_accept" )
	file.selectedEntry = entryIdx
	GamemodesPanel_RefreshRowLabels()
	GamemodesPanel_ShowEntry( entryIdx )
	GamemodesPanel_SetStatus( "" )
}


void function GamemodesPanel_OnApply( var button )
{
	if ( file.selectedEntry < 0 || file.selectedEntry >= file.entries.len() )
	{
		EmitUISound( "menu_deny" )
		GamemodesPanel_SetStatus( "Pick a mode first." )
		return
	}

	GamemodeEntry entry = file.entries[file.selectedEntry]

	if ( !entry.servable )
	{
		EmitUISound( "menu_deny" )
		GamemodesPanel_SetStatus( format( "%s is not installed on this build.", entry.mapName ) )
		return
	}

	// Only identifiers that came out of the catalog reach the RCON string, and the
	// dedi re-validates both against its own playlist + installed-map lists.
	if ( !GamemodesPanel_IsSafeIdentifier( entry.playlistId ) || !GamemodesPanel_IsSafeIdentifier( entry.mapName ) )
	{
		EmitUISound( "menu_deny" )
		GamemodesPanel_SetStatus( "Rejected: unexpected characters in playlist or map name." )
		return
	}

	ClientCommand( format( "bridge_rcon bridge_setmode %s %s", entry.playlistId, entry.mapName ) )

	EmitUISound( "menu_accept" )
	GamemodesPanel_SetStatus( format( "Requested %s on %s.", entry.title, entry.mapTitle ) )
}


const string GAMEMODE_ID_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789_"

// The identifier is concatenated into a server command string, so anything that
// could terminate that command has to be rejected before it is sent.
bool function GamemodesPanel_IsSafeIdentifier( string name )
{
	if ( name.len() == 0 )
		return false

	for ( int i = 0; i < name.len(); i++ )
	{
		if ( GAMEMODE_ID_CHARS.find( name.slice( i, i + 1 ) ) == -1 )
			return false
	}

	return true
}
