// Structured control surface for a local agent (MCP). Every Agent_* call
// answers once through AgentLink_Reply with a JSON object.
global function Agent_Help
global function Agent_State
global function Agent_Players
global function Agent_Places
global function Agent_FindPlace
global function Agent_SavePlace
global function Agent_Teleport
global function Agent_TeleportTo
global function Agent_Look
global function Agent_Give
global function Agent_TakeWeapons
global function Agent_SetLegend
global function Agent_SetHealth
global function Agent_God
global function Agent_Noclip
global function Agent_Kill
global function Agent_Respawn
global function Agent_SpawnDummy
global function Agent_SpawnBots
global function Agent_SpawnProp
global function Agent_Trace
global function Agent_Catalog
global function Agent_Events
global function Agent_Say

const int AGENT_EVENTS_MAX = 500

struct AgentPlace
{
	string name
	string kind
	string token
	vector origin
	int tier
}

struct
{
	bool eventsReady = false
	int eventSeq = 0
	array<table> events
	table<string, vector> customPlaces
} file

void function Agent_Ok( table data )
{
	data.ok <- true
	AgentLink_Reply( Agent_Json( data ) )
}

void function Agent_Fail( string message, table ornull extra = null )
{
	table data = extra != null ? expect table( extra ) : {}
	data.ok <- false
	data.error <- message
	AgentLink_Reply( Agent_Json( data ) )
}

// ---------------------------------------------------------------------------
// Players
// ---------------------------------------------------------------------------

string function Agent_Legend( entity player )
{
	try
	{
		if ( !LoadoutSlot_IsReady( ToEHI( player ), Loadout_Character() ) )
			return ""
		return ItemFlavor_GetHumanReadableRef( LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() ) )
	}
	catch ( agentErr1 )
	{
	}
	return ""
}

table function Agent_WeaponInfo( entity weapon )
{
	return {
		name = weapon.GetWeaponClassName(),
		clip = weapon.GetWeaponPrimaryClipCount(),
		mods = weapon.GetMods()
	}
}

string function Agent_ZoneName( vector origin )
{
	try
	{
		int zoneId = MapZones_GetZoneForOrigin( origin )
		if ( zoneId >= 0 )
			return MapZones_GetNameForZone( zoneId )
	}
	catch ( agentErr2 )
	{
	}
	return ""
}

table function Agent_PlayerInfo( entity player )
{
	array weapons
	foreach ( int slot in [ WEAPON_INVENTORY_SLOT_PRIMARY_0, WEAPON_INVENTORY_SLOT_PRIMARY_1 ] )
	{
		entity weapon = player.GetNormalWeapon( slot )
		if ( IsValid( weapon ) )
		{
			table info = Agent_WeaponInfo( weapon )
			info.slot <- slot
			weapons.append( info )
		}
	}
	array offhands
	foreach ( entity weapon in player.GetOffhandWeapons() )
	{
		if ( IsValid( weapon ) )
			offhands.append( weapon.GetWeaponClassName() )
	}
	entity active = player.GetActiveWeapon( eActiveInventorySlot.mainHand )

	return {
		name = player.GetPlayerName(),
		index = player.GetPlayerIndex(),
		bot = player.IsBot(),
		team = player.GetTeam(),
		alive = IsAlive( player ),
		origin = player.GetOrigin(),
		eyeAngles = player.EyeAngles(),
		velocity = player.GetVelocity(),
		health = player.GetHealth(),
		maxHealth = player.GetMaxHealth(),
		shield = player.GetShieldHealth(),
		maxShield = player.GetShieldHealthMax(),
		legend = Agent_Legend( player ),
		weapons = weapons,
		offhands = offhands,
		activeWeapon = IsValid( active ) ? active.GetWeaponClassName() : "",
		noclip = player.GetPhysics() == MOVETYPE_NOCLIP,
		invulnerable = player.IsInvulnerable(),
		zone = Agent_ZoneName( player.GetOrigin() )
	}
}

// who: "me" (first human), "all", "humans", "bots", "#<playerIndex>", or a name (exact, then substring).
array<entity> function Agent_ResolvePlayers( string who )
{
	string w = strip( who ).tolower()
	array<entity> all = GetPlayerArray()
	array<entity> result

	if ( w == "" || w == "me" )
	{
		foreach ( entity p in all )
		{
			if ( !p.IsBot() )
			{
				result.append( p )
				return result
			}
		}
		if ( all.len() > 0 )
			result.append( all[0] )
		return result
	}
	if ( w == "all" )
		return all
	if ( w == "humans" || w == "bots" )
	{
		bool wantBots = w == "bots"
		foreach ( entity p in all )
		{
			if ( p.IsBot() == wantBots )
				result.append( p )
		}
		return result
	}
	if ( w.len() > 1 && w.slice( 0, 1 ) == "#" )
	{
		int idx = w.slice( 1 ).tointeger()
		foreach ( entity p in all )
		{
			if ( p.GetPlayerIndex() == idx )
				result.append( p )
		}
		return result
	}
	foreach ( entity p in all )
	{
		if ( p.GetPlayerName().tolower() == w )
		{
			result.append( p )
			return result
		}
	}
	foreach ( entity p in all )
	{
		if ( p.GetPlayerName().tolower().find( w ) != -1 )
			result.append( p )
	}
	return result
}

array<entity> function Agent_RequirePlayers( string who )
{
	array<entity> players = Agent_ResolvePlayers( who )
	if ( players.len() == 0 )
		Agent_Fail( "no player matches '" + who + "'", { players = Agent_PlayerNames() } )
	return players
}

array function Agent_PlayerNames()
{
	array names
	foreach ( entity p in GetPlayerArray() )
		names.append( p.GetPlayerName() )
	return names
}

// ---------------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------------

array<AgentPlace> function Agent_CollectPlaces()
{
	array<AgentPlace> places

	try
	{
		foreach ( ZoneData zd in MapZones_GetZoneDatas( false, false ) )
		{
			if ( !IsValid( zd.zoneTrigger ) )
				continue
			AgentPlace p
			p.token = zd.zoneName
			p.name = Agent_PrettyToken( zd.zoneName != "" ? zd.zoneName : zd.zoneTriggerName )
			p.kind = "zone"
			p.origin = zd.zoneTrigger.GetCenter()
			p.tier = zd.zoneTier
			places.append( p )
		}
	}
	catch ( agentErr3 )
	{
	}

	try
	{
		foreach ( ForcedSpawnPoint sp in ForcedSpawn_GetSpawnPoints() )
		{
			AgentPlace p
			p.token = sp.name
			p.name = Agent_PrettyToken( sp.name )
			p.kind = "spawn"
			p.origin = sp.location
			places.append( p )
		}
	}
	catch ( agentErr4 )
	{
	}

	foreach ( string name, vector origin in file.customPlaces )
	{
		AgentPlace p
		p.token = name
		p.name = name
		p.kind = "custom"
		p.origin = origin
		places.append( p )
	}

	return places
}

// "#DES_ZONE_6_FRAGMENT_WEST" -> "fragment west"
string function Agent_PrettyToken( string token )
{
	string s = token.tolower()
	if ( s.len() > 0 && s.slice( 0, 1 ) == "#" )
		s = s.slice( 1 )
	array<string> words = split( s, "_ " )
	array<string> kept
	foreach ( int i, string word in words )
	{
		if ( word == "zone" || word == "poi" || word == "des" || word == "can" || word == "trop" || word == "olym" || word == "sal" )
			continue
		if ( word.len() > 0 && "0123456789".find( word.slice( 0, 1 ) ) != -1 )
			continue
		kept.append( word )
	}
	string out = ""
	foreach ( string word in kept )
		out += ( out == "" ? "" : " " ) + word
	return out == "" ? s : out
}

array<string> function Agent_Words( string s )
{
	array<string> words
	foreach ( string w in split( StringReplace( s.tolower(), "#", "" ), "_ -," ) )
	{
		if ( w != "" )
			words.append( w )
	}
	return words
}

int function Agent_ScorePlace( AgentPlace place, array<string> queryWords )
{
	array<string> nameWords = Agent_Words( place.name + " " + place.token )
	int score = 0
	foreach ( string q in queryWords )
	{
		int best = 0
		foreach ( string n in nameWords )
		{
			if ( n == q )
				best = maxint( best, 10 )
			else if ( n.find( q ) == 0 )
				best = maxint( best, 6 )
			else if ( n.find( q ) != -1 )
				best = maxint( best, 3 )
		}
		if ( best == 0 )
			return 0
		score += best
	}
	string joined = ""
	foreach ( string q in queryWords )
		joined += ( joined == "" ? "" : " " ) + q
	if ( place.name == joined )
		score += 20
	return score
}

int function Agent_SortByScore( table a, table b )
{
	return expect int( b.score ) - expect int( a.score )
}

array<table> function Agent_MatchPlaces( string query, int maxResults = 5 )
{
	array<string> queryWords = Agent_Words( query )
	array<table> matches
	if ( queryWords.len() == 0 )
		return matches

	foreach ( AgentPlace place in Agent_CollectPlaces() )
	{
		int score = Agent_ScorePlace( place, queryWords )
		if ( score > 0 )
			matches.append( { name = place.name, token = place.token, kind = place.kind, origin = place.origin, score = score } )
	}
	matches.sort( Agent_SortByScore )
	if ( matches.len() > maxResults )
		matches.resize( maxResults )
	return matches
}

// Walks down from above the point until it finds floor the player's hull fits on.
vector ornull function Agent_GroundFor( vector point, entity player )
{
	vector mins = player.GetPlayerMins()
	vector maxs = player.GetPlayerMaxs()
	foreach ( float above in [ 8000.0, 4000.0, 2000.0, 1000.0, 400.0, 100.0 ] )
	{
		vector start = <point.x, point.y, point.z + above>
		TraceResults down = TraceLine( start, <point.x, point.y, point.z - 30000.0>, [ player ], TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )
		if ( down.startSolid || down.fraction >= 1.0 )
			continue
		vector land = down.endPos + <0, 0, 4>
		TraceResults fit = TraceHull( land, land, mins, maxs, [ player ], TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )
		if ( fit.startSolid )
			continue
		return land
	}
	return null
}

void function Agent_MovePlayer( entity player, vector origin, vector ornull angles )
{
	player.SetVelocity( <0, 0, 0> )
	player.SetOrigin( origin )
	if ( angles != null )
		player.SnapEyeAngles( expect vector( angles ) )
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

void function Agent_EnsureEvents()
{
	if ( file.eventsReady )
		return
	file.eventsReady = true
	AddCallback_OnPlayerKilled( Agent_OnPlayerKilled )
	AddCallback_OnClientConnected( Agent_OnClientConnected )
	AddCallback_OnClientDisconnected( Agent_OnClientDisconnected )
	AddCallback_OnPlayerRespawned( Agent_OnPlayerRespawned )
	AddDamageCallback( "player", Agent_OnPlayerDamaged )
}

void function Agent_PushEvent( table ev )
{
	file.eventSeq++
	ev.seq <- file.eventSeq
	ev.time <- Time()
	file.events.append( ev )
	if ( file.events.len() > AGENT_EVENTS_MAX )
		file.events.remove( 0 )
}

string function Agent_EntName( entity ent )
{
	if ( !IsValid( ent ) )
		return ""
	if ( ent.IsPlayer() )
		return ent.GetPlayerName()
	return ent.GetClassName()
}

void function Agent_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	Agent_PushEvent( { kind = "kill", victim = Agent_EntName( victim ), attacker = Agent_EntName( attacker ), damageSource = DamageInfo_GetDamageSourceIdentifier( damageInfo ) } )
}

void function Agent_OnPlayerDamaged( entity victim, var damageInfo )
{
	Agent_PushEvent( { kind = "damage", victim = Agent_EntName( victim ), attacker = Agent_EntName( DamageInfo_GetAttacker( damageInfo ) ), amount = DamageInfo_GetDamage( damageInfo ) } )
}

void function Agent_OnClientConnected( entity player )
{
	Agent_PushEvent( { kind = "connect", player = Agent_EntName( player ) } )
}

void function Agent_OnClientDisconnected( entity player )
{
	Agent_PushEvent( { kind = "disconnect", player = Agent_EntName( player ) } )
}

void function Agent_OnPlayerRespawned( entity player )
{
	Agent_PushEvent( { kind = "respawn", player = Agent_EntName( player ) } )
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

void function Agent_Help()
{
	Agent_Ok( { functions = [
		"Agent_State()",
		"Agent_Players()",
		"Agent_Places( string filter = \"\" )",
		"Agent_FindPlace( string query )",
		"Agent_SavePlace( string name, string who = \"me\" )",
		"Agent_Teleport( string who, string target )  target = place name, player name, or \"x y z\"",
		"Agent_TeleportTo( string who, vector origin, bool snapToGround = true )",
		"Agent_Look( string who, vector angles )",
		"Agent_Give( string who, string ref, int count = 1 )",
		"Agent_TakeWeapons( string who )",
		"Agent_SetLegend( string who, string legend )",
		"Agent_SetHealth( string who, int health = -1, int shield = -1 )",
		"Agent_God( string who, bool enable )",
		"Agent_Noclip( string who, bool enable )",
		"Agent_Kill( string who )",
		"Agent_Respawn( string who )",
		"Agent_SpawnDummy( string where = \"crosshair\", int count = 1, int shieldLevel = 0 )",
		"Agent_SpawnBots( int count = 1 )",
		"Agent_SpawnProp( asset model, string where = \"crosshair\", vector angles = <0,0,0> )",
		"Agent_Trace( string who = \"me\", float distance = 20000.0 )",
		"Agent_Catalog( string kind )  kind = legends | weapons | loot | playlist",
		"Agent_Events( int sinceSeq = 0 )",
		"Agent_Say( string text, string who = \"all\" )"
	] } )
}

void function Agent_State()
{
	Agent_EnsureEvents()

	array players
	foreach ( entity p in GetPlayerArray() )
		players.append( Agent_PlayerInfo( p ) )

	table ring = {}
	try
	{
		ring = { center = SURVIVAL_GetDeathFieldCenter( 0 ), radius = SURVIVAL_GetDeathFieldCurrentRadius( 0 ) }
	}
	catch ( agentErr5 )
	{
	}

	string gameState = ""
	try
	{
		gameState = GetEnumString( "eGameState", GetGameState() )
	}
	catch ( agentErr6 )
	{
	}

	Agent_Ok( {
		map = GetMapName(),
		playlist = GetCurrentPlaylistName(),
		gameState = gameState,
		time = Time(),
		players = players,
		ring = ring,
		eventSeq = file.eventSeq
	} )
}

void function Agent_Players()
{
	array players
	foreach ( entity p in GetPlayerArray() )
		players.append( Agent_PlayerInfo( p ) )
	Agent_Ok( { players = players } )
}

void function Agent_Places( string filter = "" )
{
	string f = filter.tolower()
	array places
	foreach ( AgentPlace p in Agent_CollectPlaces() )
	{
		if ( f != "" && p.name.find( f ) == -1 && p.token.tolower().find( f ) == -1 )
			continue
		places.append( { name = p.name, token = p.token, kind = p.kind, origin = p.origin, tier = p.tier } )
	}
	Agent_Ok( { map = GetMapName(), places = places } )
}

void function Agent_FindPlace( string query )
{
	Agent_Ok( { query = query, matches = Agent_MatchPlaces( query ) } )
}

void function Agent_SavePlace( string name, string who = "me" )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	file.customPlaces[ name.tolower() ] <- players[0].GetOrigin()
	Agent_Ok( { saved = name.tolower(), origin = players[0].GetOrigin() } )
}

vector ornull function Agent_ParseVector( string s )
{
	array<string> parts = split( s, " ," )
	if ( parts.len() != 3 )
		return null
	foreach ( string part in parts )
	{
		if ( part == "" || "0123456789-.".find( part.slice( 0, 1 ) ) == -1 )
			return null
	}
	return < parts[0].tofloat(), parts[1].tofloat(), parts[2].tofloat() >
}

void function Agent_Teleport( string who, string target )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return

	vector ornull coords = Agent_ParseVector( target )
	if ( coords != null )
	{
		Agent_TeleportTo( who, expect vector( coords ), false )
		return
	}

	string t = strip( target )
	bool forcePlayer = t.len() > 7 && t.slice( 0, 7 ).tolower() == "player:"
	string playerQuery = forcePlayer ? t.slice( 7 ) : t
	array<entity> targets = Agent_ResolvePlayers( playerQuery )
	if ( targets.len() > 0 && ( forcePlayer || targets[0] != players[0] ) && ( forcePlayer || targets[0].GetPlayerName().tolower() == playerQuery.tolower() || Agent_MatchPlaces( t, 1 ).len() == 0 ) )
	{
		entity dest = targets[0]
		vector origin = dest.GetOrigin() + AnglesToForward( FlattenAngles( dest.EyeAngles() ) ) * -64.0
		vector ornull besideDest = Agent_GroundFor( origin, players[0] )
		array movedToPlayer
		foreach ( entity p in players )
		{
			Agent_MovePlayer( p, besideDest != null ? expect vector( besideDest ) : dest.GetOrigin(), dest.EyeAngles() )
			movedToPlayer.append( p.GetPlayerName() )
		}
		Agent_Ok( { moved = movedToPlayer, to = { kind = "player", name = dest.GetPlayerName() }, origin = players[0].GetOrigin() } )
		return
	}

	array<table> matches = Agent_MatchPlaces( t, 5 )
	if ( matches.len() == 0 )
	{
		Agent_Fail( "no place matches '" + target + "' on " + GetMapName(), { hint = "call Agent_Places() to list places, or pass coordinates \"x y z\"" } )
		return
	}

	table best = matches[0]
	vector center = expect vector( best.origin )
	vector ornull ground = Agent_GroundFor( center, players[0] )
	if ( ground == null )
	{
		Agent_Fail( "found '" + best.name + "' but no floor the player fits on near it", { place = best, alternatives = matches } )
		return
	}

	array moved
	foreach ( int i, entity p in players )
	{
		vector spread = < ( i % 4 ) * 48.0, ( i / 4 ) * 48.0, 0 >
		Agent_MovePlayer( p, expect vector( ground ) + spread, null )
		moved.append( p.GetPlayerName() )
	}
	Agent_Ok( { moved = moved, to = best, origin = expect vector( ground ), alternatives = matches } )
}

void function Agent_TeleportTo( string who, vector origin, bool snapToGround = true )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return

	vector dest = origin
	if ( snapToGround )
	{
		vector ornull ground = Agent_GroundFor( origin, players[0] )
		if ( ground != null )
			dest = expect vector( ground )
	}
	array moved
	foreach ( entity p in players )
	{
		Agent_MovePlayer( p, dest, null )
		moved.append( p.GetPlayerName() )
	}
	Agent_Ok( { moved = moved, origin = dest } )
}

void function Agent_Look( string who, vector angles )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	foreach ( entity p in players )
		p.SnapEyeAngles( angles )
	Agent_Ok( { angles = angles } )
}

void function Agent_Give( string who, string ref, int count = 1 )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return

	count = maxint( 1, minint( count, 999 ) )
	bool isLoot = SURVIVAL_Loot_IsRefValid( ref )
	bool isWeapon = ref.find( "mp_weapon_" ) == 0 || ref.find( "mp_ability_" ) == 0
	if ( isLoot )
		isWeapon = SURVIVAL_Loot_GetLootDataByRef( ref ).lootType == eLootType.MAINWEAPON
	if ( !isLoot && !isWeapon )
	{
		Agent_Fail( "unknown item '" + ref + "'", { hint = "call Agent_Catalog( \"weapons\" ) or Agent_Catalog( \"loot\" )" } )
		return
	}

	array given
	foreach ( entity p in players )
	{
		if ( !IsAlive( p ) )
			continue
		if ( isWeapon )
		{
			int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0
			entity second = p.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
			if ( IsValid( p.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 ) ) )
			{
				// Both slots full: replace the one in hand.
				bool holdingSecond = IsValid( second ) && p.GetActiveWeapon( eActiveInventorySlot.mainHand ) == second
				slot = ( !IsValid( second ) || holdingSecond ) ? WEAPON_INVENTORY_SLOT_PRIMARY_1 : WEAPON_INVENTORY_SLOT_PRIMARY_0
			}
			entity old = p.GetNormalWeapon( slot )
			if ( IsValid( old ) )
				p.TakeWeaponNow( old.GetWeaponClassName() )
			p.GiveWeapon( ref, slot, [] )
			p.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, slot )
		}
		else
		{
			SURVIVAL_AddToPlayerInventory( p, ref, count )
		}
		given.append( p.GetPlayerName() )
	}
	Agent_Ok( { given = given, ref = ref, count = count, asWeapon = isWeapon } )
}

void function Agent_TakeWeapons( string who )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	foreach ( entity p in players )
	{
		foreach ( int slot in [ WEAPON_INVENTORY_SLOT_PRIMARY_0, WEAPON_INVENTORY_SLOT_PRIMARY_1 ] )
		{
			entity weapon = p.GetNormalWeapon( slot )
			if ( IsValid( weapon ) )
				p.TakeWeaponNow( weapon.GetWeaponClassName() )
		}
	}
	Agent_Ok( { players = Agent_PlayerNames() } )
}

ItemFlavor ornull function Agent_FindLegend( string query )
{
	string q = StringReplace( query.tolower(), " ", "" )
	foreach ( ItemFlavor character in GetAllCharacters() )
	{
		string ref = ItemFlavor_GetHumanReadableRef( character ).tolower()
		if ( ref == q || ref == "character_" + q )
			return character
	}
	foreach ( ItemFlavor character in GetAllCharacters() )
	{
		if ( ItemFlavor_GetHumanReadableRef( character ).tolower().find( q ) != -1 )
			return character
	}
	return null
}

void function Agent_SetLegend( string who, string legend )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return

	ItemFlavor ornull found = Agent_FindLegend( legend )
	if ( found == null )
	{
		array names
		foreach ( ItemFlavor character in GetAllCharacters() )
			names.append( ItemFlavor_GetHumanReadableRef( character ) )
		Agent_Fail( "unknown legend '" + legend + "'", { legends = names } )
		return
	}
	ItemFlavor character = expect ItemFlavor( found )

	array changed
	foreach ( entity p in players )
	{
		SetItemFlavorLoadoutSlot( ToEHI( p ), Loadout_Character(), character )
		if ( IsAlive( p ) )
		{
			try
			{
				Survival_PlayerCharacterSetup( p, character, true )
			}
			catch ( agentErr7 )
			{
				printt( "[AGENT] character setup failed:", p, agentErr7 )
			}
		}
		changed.append( p.GetPlayerName() )
	}
	Agent_Ok( { changed = changed, legend = ItemFlavor_GetHumanReadableRef( character ) } )
}

void function Agent_SetHealth( string who, int health = -1, int shield = -1 )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	foreach ( entity p in players )
	{
		if ( !IsAlive( p ) )
			continue
		if ( health >= 0 )
			p.SetHealth( minint( health, p.GetMaxHealth() ) )
		if ( shield >= 0 )
			p.SetShieldHealth( minint( shield, p.GetShieldHealthMax() ) )
	}
	Agent_Ok( { players = Agent_PlayerNames() } )
}

void function Agent_God( string who, bool enable )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	foreach ( entity p in players )
	{
		if ( enable )
			p.SetInvulnerable()
		else
			p.ClearInvulnerable()
	}
	Agent_Ok( { god = enable } )
}

void function Agent_Noclip( string who, bool enable )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	foreach ( entity p in players )
		p.SetPhysics( enable ? MOVETYPE_NOCLIP : MOVETYPE_WALK )
	Agent_Ok( { noclip = enable } )
}

void function Agent_Kill( string who )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	array killed
	foreach ( entity p in players )
	{
		if ( !IsAlive( p ) )
			continue
		p.Die()
		killed.append( p.GetPlayerName() )
	}
	Agent_Ok( { killed = killed } )
}

void function Agent_Respawn( string who )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	array respawned
	foreach ( entity p in players )
	{
		if ( IsAlive( p ) )
			continue
		if ( DecideRespawnPlayer( p, false ) )
			respawned.append( p.GetPlayerName() )
	}
	Agent_Ok( { respawned = respawned } )
}

// where: "crosshair", a place name, a player name, or "x y z".
vector ornull function Agent_ResolveWhere( string where )
{
	vector ornull coords = Agent_ParseVector( where )
	if ( coords != null )
		return coords

	array<entity> me = Agent_ResolvePlayers( "me" )
	string w = strip( where ).tolower()
	if ( w == "" || w == "crosshair" )
	{
		if ( me.len() == 0 )
			return null
		entity p = me[0]
		TraceResults tr = TraceLine( p.EyePosition(), p.EyePosition() + p.GetViewVector() * 20000.0, [ p ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		return tr.endPos + tr.surfaceNormal * 8.0
	}

	array<entity> targets = Agent_ResolvePlayers( where )
	if ( targets.len() > 0 && targets[0].GetPlayerName().tolower() == w )
		return targets[0].GetOrigin() + AnglesToForward( FlattenAngles( targets[0].EyeAngles() ) ) * 128.0

	array<table> matches = Agent_MatchPlaces( where, 1 )
	if ( matches.len() == 0 || me.len() == 0 )
		return null
	return Agent_GroundFor( expect vector( matches[0].origin ), me[0] )
}

void function Agent_SpawnDummy( string where = "crosshair", int count = 1, int shieldLevel = 0 )
{
	vector ornull at = Agent_ResolveWhere( where )
	if ( at == null )
	{
		Agent_Fail( "could not resolve '" + where + "'" )
		return
	}
	vector origin = expect vector( at )
	array<entity> me = Agent_ResolvePlayers( "me" )
	vector facing = me.len() > 0 ? < 0, VectorToAngles( me[0].GetOrigin() - origin ).y, 0 > : <0, 0, 0>

	int spawned = 0
	for ( int i = 0; i < minint( count, 32 ); i++ )
	{
		vector spread = < ( i % 4 ) * 64.0, ( i / 4 ) * 64.0, 0 >
		entity npc = SpawnNPCCombatDummie( origin + spread, facing, shieldLevel )
		if ( IsValid( npc ) )
			spawned++
	}
	Agent_Ok( { spawned = spawned, origin = origin } )
}

void function Agent_SpawnBots( int count = 1 )
{
	int n = maxint( 0, minint( count, 32 ) )
	SpawnBots( n )
	Agent_Ok( { requested = n } )
}

void function Agent_SpawnProp( asset model, string where = "crosshair", vector angles = <0, 0, 0> )
{
	vector ornull at = Agent_ResolveWhere( where )
	if ( at == null )
	{
		Agent_Fail( "could not resolve '" + where + "'" )
		return
	}
	entity prop = ReMap_CreateProp( model, expect vector( at ), angles )
	if ( !IsValid( prop ) )
	{
		Agent_Fail( "could not create prop " + string( model ) )
		return
	}
	Agent_Ok( { model = string( model ), origin = prop.GetOrigin() } )
}

void function Agent_Trace( string who = "me", float distance = 20000.0 )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	entity p = players[0]
	TraceResults tr = TraceLine( p.EyePosition(), p.EyePosition() + p.GetViewVector() * distance, [ p ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
	table hit = {}
	if ( IsValid( tr.hitEnt ) )
	{
		hit = { className = tr.hitEnt.GetClassName(), scriptName = tr.hitEnt.GetScriptName(), origin = tr.hitEnt.GetOrigin() }
		if ( tr.hitEnt.IsPlayer() )
			hit.name <- tr.hitEnt.GetPlayerName()
		try
		{
			hit.model <- string( tr.hitEnt.GetModelName() )
		}
		catch ( agentErr8 )
		{
		}
	}
	Agent_Ok( { from = p.EyePosition(), endPos = tr.endPos, fraction = tr.fraction, normal = tr.surfaceNormal, distance = Distance( p.EyePosition(), tr.endPos ), hitEntity = hit, zone = Agent_ZoneName( tr.endPos ) } )
}

void function Agent_Catalog( string kind )
{
	string k = kind.tolower()
	if ( k == "legends" )
	{
		array legends
		foreach ( ItemFlavor character in GetAllCharacters() )
			legends.append( ItemFlavor_GetHumanReadableRef( character ) )
		Agent_Ok( { legends = legends } )
		return
	}
	if ( k == "weapons" || k == "loot" )
	{
		array items
		for ( int lootType = 1; lootType < 64; lootType++ )
		{
			if ( k == "weapons" && lootType != eLootType.MAINWEAPON )
				continue
			string typeName = ""
			try
			{
				typeName = GetEnumString( "eLootType", lootType )
			}
			catch ( agentErr9 )
			{
				break
			}
			foreach ( LootData data in SURVIVAL_Loot_GetByType( lootType ) )
				items.append( { ref = data.ref, lootType = typeName, tier = data.tier, name = data.pickupString } )
		}
		Agent_Ok( { kind = k, items = items } )
		return
	}
	if ( k == "playlist" )
	{
		Agent_Ok( { current = GetCurrentPlaylistName(), maps = GetPlaylistMaps( GetCurrentPlaylistName() ) } )
		return
	}
	Agent_Fail( "unknown catalog '" + kind + "'", { kinds = [ "legends", "weapons", "loot", "playlist" ] } )
}

void function Agent_Events( int sinceSeq = 0 )
{
	Agent_EnsureEvents()
	array out
	foreach ( table ev in file.events )
	{
		if ( expect int( ev.seq ) > sinceSeq )
			out.append( ev )
	}
	Agent_Ok( { events = out, next = file.eventSeq } )
}

void function Agent_Say( string text, string who = "all" )
{
	array<entity> players = Agent_RequirePlayers( who )
	if ( players.len() == 0 )
		return
	foreach ( entity p in players )
		SendHudMessage( p, text, -1, 0.3, 255, 255, 255, 255, 0.15, 4.0, 0.5 )
	Agent_Ok( { said = text } )
}
