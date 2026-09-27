// Flowstate Scenarios: premade teams (mkos). Console command "team":
//   team help | list | info [player|id] | make [name] | join <captain|id> | leave
//   captains: requests | accept <player|#> | reject <player|#> | kick <player|#>
//             makecaptain <player|#> | settings | set <fill|timeout|allcaptain|open|name> <value>

global function FS_Scenarios_Teams_Init
global function FS_Scenarios_Teams_OnDisconnect
global function FS_Scenarios_GetCustomTeamID
global function FS_Scenarios_CustomTeamAllowsRandomFill
global function FS_Scenarios_IsWaitingForTeammates
global function FS_Scenarios_Teams_OnFightEnded

const int TEAM_NAME_MAX_LEN = 12
const int TEAM_TIMEOUT_MAX = 300
const int TEAM_MAX_JOIN_REQUESTS = 8

struct ScenariosPremade
{
	int teamID = -1
	string name
	float lastFightEndTime
	table<string, int> settings
	array<entity> captains
	array<entity> players
	array<entity> joinRequests
}

struct
{
	bool enabled
	int nextTeamID = 0
	table<int, ScenariosPremade> teams
	table<int, int> teamOfPlayer
} file

const table<string, string> TEAM_SETTING_ALIASES =
{
	fill = "allow_random_fill",
	timeout = "matchmaking_timeout",
	allcaptain = "anyone_is_captain",
	open = "anyone_can_join"
}

void function FS_Scenarios_Teams_Init()
{
	file.enabled = GetCurrentPlaylistVarBool( "fs_scenarios_allow_teams", true )
	AddClientCommandCallback( "team", ClientCommand_FS_Scenarios_Team )
}

//////////////////////////////////////////////////////////////////////////////
// Queries used by the team former

ScenariosPremade ornull function FS_Scenarios_GetPremadeOfPlayer( entity player )
{
	if ( !IsValid( player ) || !( player.p.handle in file.teamOfPlayer ) )
		return null

	int teamID = file.teamOfPlayer[ player.p.handle ]
	if ( !( teamID in file.teams ) )
		return null

	return file.teams[ teamID ]
}

int function FS_Scenarios_GetCustomTeamID( entity player )
{
	ScenariosPremade ornull team = FS_Scenarios_GetPremadeOfPlayer( player )
	return team == null ? -1 : expect ScenariosPremade( team ).teamID
}

bool function FS_Scenarios_CustomTeamAllowsRandomFill( int teamID )
{
	if ( !( teamID in file.teams ) )
		return true
	return file.teams[ teamID ].settings[ "allow_random_fill" ] == 1
}

// A premade enters a fight together: nobody is formed while a teammate is still
// fighting, resting or inside the team's cooldown.
bool function FS_Scenarios_IsWaitingForTeammates( entity player )
{
	ScenariosPremade ornull maybeTeam = FS_Scenarios_GetPremadeOfPlayer( player )
	if ( maybeTeam == null )
		return false

	ScenariosPremade team = expect ScenariosPremade( maybeTeam )

	int timeout = team.settings[ "matchmaking_timeout" ]
	if ( timeout > 0 && Time() - team.lastFightEndTime < timeout )
		return true

	bool fill = team.settings[ "allow_random_fill" ] == 1
	if ( !fill && team.players.len() < FS_Scenarios_GetPlayersPerTeam() )
		return true

	foreach ( entity teammate in team.players )
	{
		if ( IsValid( teammate ) && !Gamemode1v1_IsPlayerWaiting( teammate ) )
			return true
	}

	return false
}

void function FS_Scenarios_Teams_OnFightEnded( entity player )
{
	ScenariosPremade ornull team = FS_Scenarios_GetPremadeOfPlayer( player )
	if ( team == null )
		return

	expect ScenariosPremade( team )
	team.lastFightEndTime = Time()
}

//////////////////////////////////////////////////////////////////////////////
// Membership

ScenariosPremade function FS_Scenarios_CreatePremade( entity captain, string name )
{
	ScenariosPremade team
	team.teamID = ++file.nextTeamID
	team.name = name != "" ? name : format( "Team%d", team.teamID )
	team.lastFightEndTime = Time()
	team.settings[ "allow_random_fill" ] <- 0
	team.settings[ "matchmaking_timeout" ] <- 0
	team.settings[ "anyone_is_captain" ] <- 0
	team.settings[ "anyone_can_join" ] <- 0
	team.captains.append( captain )
	team.players.append( captain )

	file.teams[ team.teamID ] <- team
	file.teamOfPlayer[ captain.p.handle ] <- team.teamID
	return team
}

bool function FS_Scenarios_AddToPremade( entity player, ScenariosPremade team )
{
	if ( player.p.handle in file.teamOfPlayer )
		return false
	if ( team.players.len() >= FS_Scenarios_GetPlayersPerTeam() )
		return false

	foreach ( entity teammate in team.players )
		FS_Scenarios_TeamMsg( teammate, "#FS_PLAYER_JOINED_TEAM", player.GetPlayerName() )

	team.players.append( player )
	file.teamOfPlayer[ player.p.handle ] <- team.teamID
	FS_Scenarios_RevokeAllJoinRequests( player )
	FS_Scenarios_TeamMsg( player, "#FS_YOU_JOINED_TEAM", team.name )
	return true
}

void function FS_Scenarios_RemoveFromPremade( entity player, ScenariosPremade team, bool announce )
{
	if ( !team.players.contains( player ) )
		return

	team.players.fastremovebyvalue( player )
	if ( team.captains.contains( player ) )
		team.captains.fastremovebyvalue( player )
	if ( player.p.handle in file.teamOfPlayer )
		delete file.teamOfPlayer[ player.p.handle ]

	if ( announce )
	{
		foreach ( entity teammate in team.players )
			FS_Scenarios_TeamMsg( teammate, "#FS_PLAYER_LEFT_TEAM", player.GetPlayerName() )
	}

	if ( team.captains.len() == 0 )
		FS_Scenarios_DismantlePremade( team )
}

void function FS_Scenarios_DismantlePremade( ScenariosPremade team )
{
	foreach ( entity teammate in clone team.players )
	{
		if ( IsValid( teammate ) && teammate.p.handle in file.teamOfPlayer )
			delete file.teamOfPlayer[ teammate.p.handle ]
		FS_Scenarios_TeamMsg( teammate, "#FS_TEAM_DISMANTLED" )
	}

	team.players.clear()
	if ( team.teamID in file.teams )
		delete file.teams[ team.teamID ]
}

void function FS_Scenarios_RevokeAllJoinRequests( entity player )
{
	foreach ( int teamID, ScenariosPremade team in file.teams )
	{
		if ( team.joinRequests.contains( player ) )
			team.joinRequests.fastremovebyvalue( player )
	}
}

void function FS_Scenarios_Teams_OnDisconnect( entity player )
{
	FS_Scenarios_RevokeAllJoinRequests( player )

	ScenariosPremade ornull team = FS_Scenarios_GetPremadeOfPlayer( player )
	if ( team != null )
		FS_Scenarios_RemoveFromPremade( player, expect ScenariosPremade( team ), true )
	else if ( player.p.handle in file.teamOfPlayer )
		delete file.teamOfPlayer[ player.p.handle ]
}

bool function FS_Scenarios_IsCaptain( entity player, ScenariosPremade team )
{
	return team.captains.contains( player ) || team.settings[ "anyone_is_captain" ] == 1
}

//////////////////////////////////////////////////////////////////////////////
// Input

string function FS_Scenarios_SanitizeTeamName( string raw )
{
	string name = ""
	for ( int i = 0; i < raw.len() && name.len() < TEAM_NAME_MAX_LEN; i++ )
	{
		string ch = raw.slice( i, i + 1 )
		if ( ( ch >= "a" && ch <= "z" ) || ( ch >= "A" && ch <= "Z" ) || ( ch >= "0" && ch <= "9" ) || ch == "_" || ch == "-" )
			name += ch
	}
	return name
}

ScenariosPremade ornull function FS_Scenarios_FindPremade( string query )
{
	entity player = GetPlayer( query )
	if ( IsValid( player ) )
		return FS_Scenarios_GetPremadeOfPlayer( player )

	if ( IsStringNumeric( query, 1, 99999 ) )
	{
		int teamID = query.tointeger()
		if ( teamID in file.teams )
			return file.teams[ teamID ]
	}

	return null
}

entity function FS_Scenarios_FindListedPlayer( string query, array<entity> list )
{
	entity player = GetPlayer( query )
	if ( IsValid( player ) )
		return player

	if ( list.len() > 0 && IsStringNumeric( query, 0, list.len() - 1 ) )
		return list[ query.tointeger() ]

	return null
}

void function ClientCommand_FS_Scenarios_Team( entity player, array<string> args )
{
	if ( !IsValid( player ) || !CheckRate( player, "scenarios_team", 0.5, false ) )
		return

	if ( !file.enabled )
	{
		FS_Scenarios_TeamMsg( player, "#FS_TEAMS_DISABLED" )
		return
	}

	string command = args.len() > 0 ? args[ 0 ].tolower() : "help"
	string param = args.len() > 1 ? args[ 1 ] : ""
	string param2 = args.len() > 2 ? args[ 2 ] : ""

	if ( param.len() > 32 || param2.len() > 32 )
	{
		FS_Scenarios_TeamMsg( player, "#FS_ERR_CMD_PARAM_LEN" )
		return
	}

	ScenariosPremade ornull myTeam = FS_Scenarios_GetPremadeOfPlayer( player )

	switch ( command )
	{
		case "help":
			LocalMsg( player, "#FS_HELP_INFO", "#FS_TEAMHELP", eMsgUI.DEFAULT, 20.0 )
			return

		case "list":
			string listing = ""
			foreach ( int teamID, ScenariosPremade team in file.teams )
				listing += format( "#%d  %s  (%d/%d)\n", team.teamID, team.name, team.players.len(), FS_Scenarios_GetPlayersPerTeam() )
			FS_Scenarios_TeamMsg( player, "#FS_ALL_TEAMS", listing, 10.0 )
			return

		case "info":
			ScenariosPremade ornull infoTeam = param == "" ? myTeam : FS_Scenarios_FindPremade( param )
			if ( infoTeam == null )
			{
				FS_Scenarios_TeamMsg( player, "#FS_INVALID_TEAM" )
				return
			}
			FS_Scenarios_TeamMsg( player, "#FS_TEAM_INFO", FS_Scenarios_TeamInfo( expect ScenariosPremade( infoTeam ) ), 10.0 )
			return

		case "make":
			if ( myTeam != null )
			{
				FS_Scenarios_TeamMsg( player, "#FS_IN_TEAM" )
				return
			}
			FS_Scenarios_RevokeAllJoinRequests( player )
			FS_Scenarios_CreatePremade( player, FS_Scenarios_SanitizeTeamName( param ) )
			FS_Scenarios_TeamMsg( player, "#FS_TEAM_CREATED" )
			return

		case "join":
			if ( !CheckRate( player, "scenarios_team_join", 5.0, false ) )
			{
				FS_Scenarios_TeamMsg( player, "#FS_JOIN_REQUEST_COOLDOWN" )
				return
			}
			if ( myTeam != null )
			{
				FS_Scenarios_TeamMsg( player, "#FS_IN_TEAM" )
				return
			}

			ScenariosPremade ornull target = FS_Scenarios_FindPremade( param )
			if ( target == null )
			{
				FS_Scenarios_TeamMsg( player, "#FS_INVALID_TEAM" )
				return
			}

			ScenariosPremade joinTeam = expect ScenariosPremade( target )
			if ( joinTeam.players.len() >= FS_Scenarios_GetPlayersPerTeam() )
			{
				FS_Scenarios_TeamMsg( player, "#FS_TEAM_FULL" )
				return
			}

			if ( joinTeam.settings[ "anyone_can_join" ] == 1 )
			{
				FS_Scenarios_AddToPremade( player, joinTeam )
				return
			}

			if ( joinTeam.joinRequests.contains( player ) || joinTeam.joinRequests.len() >= TEAM_MAX_JOIN_REQUESTS )
			{
				FS_Scenarios_TeamMsg( player, "#FS_JOIN_REQ_FAILED", joinTeam.name )
				return
			}

			joinTeam.joinRequests.append( player )
			foreach ( entity captain in joinTeam.captains )
				FS_Scenarios_TeamMsg( captain, "#FS_NEW_JOIN_REQUEST", player.GetPlayerName() )
			FS_Scenarios_TeamMsg( player, "#FS_JOIN_REQUEST_SENT", joinTeam.name )
			return

		case "leave":
			if ( myTeam == null )
			{
				FS_Scenarios_TeamMsg( player, "#FS_NOT_IN_TEAM" )
				return
			}
			FS_Scenarios_RemoveFromPremade( player, expect ScenariosPremade( myTeam ), true )
			FS_Scenarios_TeamMsg( player, "#FS_LEFT_TEAM" )
			return
	}

	// Everything below changes the team: captains only.
	if ( myTeam == null )
	{
		FS_Scenarios_TeamMsg( player, "#FS_NOT_ON_A_TEAM" )
		return
	}

	ScenariosPremade team = expect ScenariosPremade( myTeam )
	if ( !FS_Scenarios_IsCaptain( player, team ) )
	{
		FS_Scenarios_TeamMsg( player, "#FS_NOT_CAPTAIN" )
		return
	}

	switch ( command )
	{
		case "requests":
			string requests = ""
			foreach ( int i, entity requester in team.joinRequests )
			{
				if ( IsValid( requester ) )
					requests += format( "%d = %s\n", i, requester.GetPlayerName() )
			}
			FS_Scenarios_TeamMsg( player, "#FS_JOIN_REQ", requests, 10.0 )
			return

		case "accept":
		case "reject":
			entity requester = FS_Scenarios_FindListedPlayer( param, team.joinRequests )
			if ( !IsValid( requester ) || !team.joinRequests.contains( requester ) )
			{
				FS_Scenarios_TeamMsg( player, "#FS_INV_REQ_PLAYER" )
				return
			}

			team.joinRequests.fastremovebyvalue( requester )
			if ( command == "reject" )
				FS_Scenarios_TeamMsg( player, "#FS_REQ_REVOKED", requester.GetPlayerName() )
			else if ( !FS_Scenarios_AddToPremade( requester, team ) )
				FS_Scenarios_TeamMsg( player, "#FS_TEAMS_FAIL_REQ" )
			return

		case "kick":
			entity member = FS_Scenarios_FindListedPlayer( param, team.players )
			if ( !IsValid( member ) || !team.players.contains( member ) || member == player )
			{
				FS_Scenarios_TeamMsg( player, "#FS_PLAYER_NOT_ON_TEAM" )
				return
			}
			FS_Scenarios_RemoveFromPremade( member, team, true )
			return

		case "makecaptain":
			entity newCaptain = FS_Scenarios_FindListedPlayer( param, team.players )
			if ( !IsValid( newCaptain ) || !team.players.contains( newCaptain ) )
			{
				FS_Scenarios_TeamMsg( player, "#FS_PLAYER_NOT_ON_TEAM" )
				return
			}
			if ( team.captains.contains( newCaptain ) )
			{
				FS_Scenarios_TeamMsg( player, "#FS_PLAYER_CAPTAIN_ERR" )
				return
			}
			team.captains.append( newCaptain )
			FS_Scenarios_TeamMsg( player, "#FS_ADDED_CAPTAIN", newCaptain.GetPlayerName() )
			return

		case "settings":
			string current = format( "name = %s\n", team.name )
			foreach ( string alias, string setting in TEAM_SETTING_ALIASES )
				current += format( "%s = %d\n", alias, team.settings[ setting ] )
			FS_Scenarios_TeamMsg( player, "#FS_TEAM_SETTINGS", current, 10.0 )
			return

		case "set":
			FS_Scenarios_TeamMsg( player, FS_Scenarios_ApplyTeamSetting( team, param.tolower(), param2 ) )
			return
	}

	LocalMsg( player, "#FS_HELP_INFO", "#FS_TEAMHELP", eMsgUI.DEFAULT, 20.0 )
}

string function FS_Scenarios_ApplyTeamSetting( ScenariosPremade team, string alias, string value )
{
	if ( alias == "name" )
	{
		string name = FS_Scenarios_SanitizeTeamName( value )
		if ( name == "" )
			return "#FS_INV_SETT_VALUE"
		team.name = name
		return "#FS_SETTING_SET"
	}

	if ( !( alias in TEAM_SETTING_ALIASES ) )
		return "#FS_INV_TEAM_SETTING"

	string setting = TEAM_SETTING_ALIASES[ alias ]
	int maxValue = setting == "matchmaking_timeout" ? TEAM_TIMEOUT_MAX : 1
	if ( !IsStringNumeric( value, 0, maxValue ) )
		return "#FS_INV_SETT_VALUE"

	int parsed = value.tointeger()
	if ( team.settings[ setting ] == parsed )
		return "#FS_SAME_SETT_VALUE"

	team.settings[ setting ] = parsed
	return "#FS_SETTING_SET"
}

string function FS_Scenarios_TeamInfo( ScenariosPremade team )
{
	string info = format( "#%d  %s\n\nCaptains:\n", team.teamID, team.name )
	foreach ( entity captain in team.captains )
	{
		if ( IsValid( captain ) )
			info += captain.GetPlayerName() + "\n"
	}

	info += "\nPlayers:\n"
	foreach ( int i, entity member in team.players )
	{
		if ( !IsValid( member ) )
			continue

		string state = "Playing"
		if ( Gamemode1v1_IsPlayerWaiting( member ) )
			state = "In queue"
		else if ( Gamemode1v1_IsPlayerResting( member ) )
			state = "Resting"

		info += format( "%d: %s  | score %d | %s\n", i, member.GetPlayerName(), member.GetPlayerNetInt( "FS_Scenarios_PlayerScore" ), state )
	}

	return info
}

void function FS_Scenarios_TeamMsg( entity player, string token, string varString = "", float duration = 5.0 )
{
	if ( !IsValid( player ) || !FS_1v1_PlayerHasClient( player ) )
		return

	LocalMsg( player, token, "#FS_NULL", eMsgUI.DEFAULT, duration, "", varString )
}
