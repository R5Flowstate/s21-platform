// Map editor per-player preferences: quick slots, favorites, preview options.
// Stored under one me_ prefs key so they follow the player across maps.

global function MapEditPrefs_ServerInit
global function MapEditPrefs_OnDisconnect

const string MEPREFS_KEY = "me_prefs"
const int    MEPREFS_SLOTS = 3
const int    MEPREFS_FAV_MAX = 64
const int    MEPREFS_SPECIAL_MAX = 5
const float  MEPREFS_WRITE_DELAY = 1.5
const int    MEPREFS_CMD_BURST = 24
const float  MEPREFS_CMD_WINDOW = 1.0

struct MapEditSlotPref
{
	int    kind = 0
	int    id = 0
	vector angles = <0, 0, 0>
}

struct MapEditPlayerPrefs
{
	array< MapEditSlotPref > slots
	int         opts = -1
	array< int > favs
	bool        loaded = false
	bool        dirty = false
	array< float > cmdTimes
}

struct
{
	table< entity, MapEditPlayerPrefs > prefs
} file

void function MapEditPrefs_ServerInit()
{
	AddClientCommandCallback( "mapedit_prefs_get", ClientCommand_MapEditPrefs_Get )
	AddClientCommandCallback( "mapedit_hotbar_set", ClientCommand_MapEditPrefs_HotbarSet )
	AddClientCommandCallback( "mapedit_prefs_opts", ClientCommand_MapEditPrefs_Opts )
	AddClientCommandCallback( "mapedit_fav", ClientCommand_MapEditPrefs_Fav )
}

void function MapEditPrefs_OnDisconnect( entity player )
{
	if ( !( player in file.prefs ) )
		return
	if ( file.prefs[player].dirty )
		MapEditPrefs_Write( player )
	delete file.prefs[player]
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

MapEditPlayerPrefs function MapEditPrefs_For( entity player )
{
	if ( !( player in file.prefs ) )
	{
		MapEditPlayerPrefs p
		for ( int i = 0; i < MEPREFS_SLOTS; i++ )
		{
			MapEditSlotPref s
			p.slots.append( s )
		}
		file.prefs[player] <- p
	}
	MapEditPlayerPrefs p = file.prefs[player]
	if ( !p.loaded )
	{
		p.loaded = true
		MapEditPrefs_Read( player, p )
	}
	return p
}

bool function MapEditPrefs_CmdAllowed( entity player )
{
	if ( !MapEditor_IsEnabled() || !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return false

	MapEditPlayerPrefs p = MapEditPrefs_For( player )
	float now = Time()
	array< float > kept
	foreach ( float t in p.cmdTimes )
	{
		if ( now - t < MEPREFS_CMD_WINDOW )
			kept.append( t )
	}
	p.cmdTimes = kept
	if ( p.cmdTimes.len() >= MEPREFS_CMD_BURST )
		return false
	p.cmdTimes.append( now )
	return true
}

bool function MapEditPrefs_SlotValid( int kind, int id )
{
	if ( kind == 0 )
		return id == 0
	if ( kind == 1 )
		return MapEditorCatalog_GetEntry( id ) != null
	if ( kind == 2 )
		return id >= 1 && id <= MEPREFS_SPECIAL_MAX
	return false
}

void function MapEditPrefs_MarkDirty( entity player )
{
	MapEditPlayerPrefs p = MapEditPrefs_For( player )
	if ( p.dirty )
		return
	p.dirty = true
	thread MapEditPrefs_WriteLater( player )
}

void function MapEditPrefs_WriteLater( entity player )
{
	player.EndSignal( "OnDestroy" )
	wait MEPREFS_WRITE_DELAY
	if ( player in file.prefs && file.prefs[player].dirty )
		MapEditPrefs_Write( player )
}

// ---------------------------------------------------------------------------
// Disk format: v=1, then name-keyed lines; unknown lines are ignored.
// ---------------------------------------------------------------------------

void function MapEditPrefs_Write( entity player )
{
	if ( !IsValid( player ) || player.IsBot() || !( player in file.prefs ) )
		return

	MapEditPlayerPrefs p = file.prefs[player]
	p.dirty = false

	string payload = "v=1\n"
	foreach ( int i, MapEditSlotPref s in p.slots )
		payload += format( "slot.%d=%d,%d,%.1f,%.1f,%.1f\n", i, s.kind, s.id, s.angles.x, s.angles.y, s.angles.z )
	payload += "opts=" + string( p.opts ) + "\n"
	string favLine = ""
	foreach ( int id in p.favs )
		favLine += ( favLine == "" ? "" : "," ) + string( id )
	payload += "fav=" + favLine + "\n"

	if ( !player.Cafe_PlayerPrefs_Write( MEPREFS_KEY, payload ) )
		printt( "[MAPEDIT] prefs write failed for " + player.GetPlayerName() )
}

void function MapEditPrefs_Read( entity player, MapEditPlayerPrefs p )
{
	string payload = player.Cafe_PlayerPrefs_Read( MEPREFS_KEY )
	if ( payload == "" )
		return

	array< string > lines = split( payload, "\n" )
	if ( lines.len() < 1 || strip( lines[0] ) != "v=1" )
		return

	for ( int li = 1; li < lines.len() && li < 16; li++ )
	{
		string line = strip( lines[li] )
		int eq = line.find( "=" )
		if ( eq < 1 || line.len() > 600 )
			continue
		string key = line.slice( 0, eq )
		string value = line.slice( eq + 1, line.len() )

		if ( key.len() == 6 && key.slice( 0, 5 ) == "slot." )
		{
			string idxTok = key.slice( 5, 6 )
			if ( !MapEdit_IsIntToken( idxTok ) )
				continue
			int idx = idxTok.tointeger()
			if ( idx < 0 || idx >= MEPREFS_SLOTS )
				continue
			array< string > t = split( value, "," )
			if ( t.len() != 5 || !MapEdit_IsIntToken( t[0] ) || !MapEdit_IsIntToken( t[1] ) )
				continue
			if ( !MapEdit_IsFloatToken( t[2] ) || !MapEdit_IsFloatToken( t[3] ) || !MapEdit_IsFloatToken( t[4] ) )
				continue
			int kind = t[0].tointeger()
			int id = t[1].tointeger()
			if ( !MapEditPrefs_SlotValid( kind, id ) )
				continue
			p.slots[idx].kind = kind
			p.slots[idx].id = id
			p.slots[idx].angles = < MapEdit_NormalizeAngle360( t[2].tofloat() ), MapEdit_NormalizeAngle360( t[3].tofloat() ), MapEdit_NormalizeAngle360( t[4].tofloat() ) >
		}
		else if ( key == "opts" )
		{
			if ( MapEdit_IsIntToken( value ) )
			{
				int opts = value.tointeger()
				if ( opts >= -1 && opts <= 255 )
					p.opts = opts
			}
		}
		else if ( key == "fav" )
		{
			foreach ( string tok in split( value, "," ) )
			{
				if ( p.favs.len() >= MEPREFS_FAV_MAX )
					break
				if ( !MapEdit_IsIntToken( tok ) )
					continue
				int id = tok.tointeger()
				if ( MapEditorCatalog_GetEntry( id ) != null && !p.favs.contains( id ) )
					p.favs.append( id )
			}
		}
	}
}

void function MapEditPrefs_Send( entity player )
{
	MapEditPlayerPrefs p = MapEditPrefs_For( player )
	foreach ( int i, MapEditSlotPref s in p.slots )
		Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_Hotbar", i, s.kind, s.id, s.angles )
	Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_Opts", p.opts )
	Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_FavClear" )
	foreach ( int id in p.favs )
		Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_Fav", id )
}

// ---------------------------------------------------------------------------
// Client commands
// ---------------------------------------------------------------------------

void function ClientCommand_MapEditPrefs_Get( entity player, array< string > args )
{
	if ( !MapEditPrefs_CmdAllowed( player ) )
		return
	MapEditPrefs_Send( player )
	MapEditInfo_Send( player )
}

// mapedit_hotbar_set <slot> <kind> <id> <pitch> <yaw> <roll>
void function ClientCommand_MapEditPrefs_HotbarSet( entity player, array< string > args )
{
	if ( !MapEditPrefs_CmdAllowed( player ) || args.len() != 6 )
		return
	if ( !MapEdit_IsIntToken( args[0] ) || !MapEdit_IsIntToken( args[1] ) || !MapEdit_IsIntToken( args[2] ) )
		return
	for ( int i = 3; i < 6; i++ )
	{
		if ( !MapEdit_IsFloatToken( args[i] ) )
			return
	}

	int slot = args[0].tointeger()
	int kind = args[1].tointeger()
	int id = args[2].tointeger()
	if ( slot < 0 || slot >= MEPREFS_SLOTS || !MapEditPrefs_SlotValid( kind, id ) )
		return

	MapEditPlayerPrefs p = MapEditPrefs_For( player )
	p.slots[slot].kind = kind
	p.slots[slot].id = id
	p.slots[slot].angles = < MapEdit_NormalizeAngle360( args[3].tofloat() ), MapEdit_NormalizeAngle360( args[4].tofloat() ), MapEdit_NormalizeAngle360( args[5].tofloat() ) >
	MapEditPrefs_MarkDirty( player )
}

void function ClientCommand_MapEditPrefs_Opts( entity player, array< string > args )
{
	if ( !MapEditPrefs_CmdAllowed( player ) || args.len() != 1 || !MapEdit_IsIntToken( args[0] ) )
		return
	int opts = args[0].tointeger()
	if ( opts < 0 || opts > 255 )
		return
	MapEditPlayerPrefs p = MapEditPrefs_For( player )
	if ( p.opts == opts )
		return
	p.opts = opts
	MapEditPrefs_MarkDirty( player )
}

// mapedit_fav <id> <0|1>
void function ClientCommand_MapEditPrefs_Fav( entity player, array< string > args )
{
	if ( !MapEditPrefs_CmdAllowed( player ) || args.len() != 2 )
		return
	if ( !MapEdit_IsIntToken( args[0] ) || ( args[1] != "0" && args[1] != "1" ) )
		return
	int id = args[0].tointeger()
	if ( MapEditorCatalog_GetEntry( id ) == null )
		return

	MapEditPlayerPrefs p = MapEditPrefs_For( player )
	bool on = args[1] == "1"
	int at = p.favs.find( id )
	if ( on && at < 0 && p.favs.len() < MEPREFS_FAV_MAX )
		p.favs.append( id )
	else if ( !on && at >= 0 )
		p.favs.remove( at )
	else
		return
	MapEditPrefs_MarkDirty( player )
}
