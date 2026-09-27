// Flowstate Scenarios: scoring and standings. Totals cover the whole map
// session; the last-fight set restarts when the player's next fight forms.
// Standings are keyed by platform UID so a reconnect keeps them.

global function FS_Scenarios_Score_Init
global function FS_Scenarios_AddScore
global function FS_Scenarios_SendStandings
global function FS_Scenarios_GetPlayerScore
global function FS_Scenarios_ResetLastFight

struct
{
	table< string, table<int, int> > total
	table< string, table<int, int> > lastFight

	table< entity, array<int> > msgTypes
	table< entity, array<int> > msgEarned
	table< entity, bool > msgRunning
} file

const float SCENARIOS_SCORE_MSG_TIME = 1.8

void function FS_Scenarios_Score_Init()
{
	FS_Scenarios_SharedInit()
	AddCallback_OnClientConnected( FS_Scenarios_Score_OnClientConnected )
}

void function FS_Scenarios_Score_OnClientConnected( entity player )
{
	string uid = player.GetPlatformUID()
	if ( !( uid in file.total ) )
	{
		file.total[ uid ] <- FS_Scenarios_NewStanding()
		file.lastFight[ uid ] <- FS_Scenarios_NewStanding()
	}

	player.SetPlayerNetInt( "FS_Scenarios_PlayerScore", FS_Scenarios_GetPlayerScore( player ) )
}

table<int, int> function FS_Scenarios_NewStanding()
{
	table<int, int> counts
	for ( int scoreType = FS_ScoreType.PLAYERSCORE; scoreType <= FS_Scenarios_LastScoreType(); scoreType++ )
		counts[ scoreType ] <- 0
	return counts
}

int function FS_Scenarios_GetPlayerScore( entity player )
{
	string uid = player.GetPlatformUID()
	if ( !( uid in file.total ) )
		return 0
	return file.total[ uid ][ FS_ScoreType.PLAYERSCORE ]
}

void function FS_Scenarios_AddToStanding( table<int, int> counts, int scoreType, int count, int earned )
{
	counts[ scoreType ] = ClampInt( counts[ scoreType ] + count, 0, FS_SCENARIOS_STAT_LIMIT )
	counts[ FS_ScoreType.PLAYERSCORE ] = ClampInt( counts[ FS_ScoreType.PLAYERSCORE ] + earned, -FS_SCENARIOS_STAT_LIMIT, FS_SCENARIOS_STAT_LIMIT )
}

// Survival time scores once per two seconds survived; every other event once.
void function FS_Scenarios_AddScore( entity player, int scoreType, entity victim = null, float value = -1.0 )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( scoreType <= FS_ScoreType.PLAYERSCORE || scoreType > FS_Scenarios_LastScoreType() )
		return

	string uid = player.GetPlatformUID()
	if ( !( uid in file.total ) )
		return

	int count = 1
	if ( scoreType == FS_ScoreType.SURVIVAL_TIME )
	{
		count = value > 1.0 ? int( value / 2.0 ) : 0
		if ( count == 0 )
			return
	}

	int earned = FS_Scenarios_GetEventScoreValue( scoreType ) * count
	FS_Scenarios_AddToStanding( file.total[ uid ], scoreType, count, earned )
	FS_Scenarios_AddToStanding( file.lastFight[ uid ], scoreType, count, earned )

	player.SetPlayerNetInt( "FS_Scenarios_PlayerScore", file.total[ uid ][ FS_ScoreType.PLAYERSCORE ] )

	// Ring ticks and survival time would flood the feed; they show in standings.
	if ( scoreType == FS_ScoreType.PENALTY_RING || scoreType == FS_ScoreType.SURVIVAL_TIME )
		return

	if ( earned != 0 && FS_1v1_PlayerHasClient( player ) )
		FS_Scenarios_QueueScoreMsg( player, scoreType, earned )
}

// One line at a time: each message streams its text char by char, and a burst of
// them in one frame overruns the remote call budget and arrives garbled.
void function FS_Scenarios_QueueScoreMsg( entity player, int scoreType, int earned )
{
	if ( !( player in file.msgTypes ) )
	{
		file.msgTypes[ player ] <- []
		file.msgEarned[ player ] <- []
	}
	file.msgTypes[ player ].append( scoreType )
	file.msgEarned[ player ].append( earned )

	if ( !( player in file.msgRunning ) )
	{
		file.msgRunning[ player ] <- true
		thread FS_Scenarios_ScoreMsg_THREAD( player )
	}
}

void function FS_Scenarios_ScoreMsg_THREAD( entity player )
{
	OnThreadEnd(
		function() : ( player )
		{
			if ( player in file.msgTypes )
				delete file.msgTypes[ player ]
			if ( player in file.msgEarned )
				delete file.msgEarned[ player ]
			if ( player in file.msgRunning )
				delete file.msgRunning[ player ]
		}
	)
	player.EndSignal( "OnDestroy" )

	while ( file.msgTypes[ player ].len() > 0 )
	{
		int scoreType = file.msgTypes[ player ].remove( 0 )
		int earned = file.msgEarned[ player ].remove( 0 )
		LocalEventMsg( player, "#FS_Scenarios_Score_" + string( scoreType ), ( earned > 0 ? "+" : "" ) + string( earned ), SCENARIOS_SCORE_MSG_TIME )
		wait SCENARIOS_SCORE_MSG_TIME
	}
}

void function FS_Scenarios_SendStandings( entity player )
{
	if ( !FS_1v1_PlayerHasClient( player ) )
		return

	string uid = player.GetPlatformUID()
	if ( !( uid in file.total ) )
		return

	FS_Scenarios_SendStandingSet( player, FS_SCENARIOS_STANDINGS_TOTAL, file.total[ uid ] )
	FS_Scenarios_SendStandingSet( player, FS_SCENARIOS_STANDINGS_ROUND, file.lastFight[ uid ] )
	Remote_CallFunction_NonReplay( player, "ServerCallback_FS_Scenarios_StandingsDone" )
}

void function FS_Scenarios_ResetLastFight( entity player )
{
	string uid = player.GetPlatformUID()
	if ( uid in file.lastFight )
		file.lastFight[ uid ] = FS_Scenarios_NewStanding()
}

void function FS_Scenarios_SendStandingSet( entity player, int standingType, table<int, int> counts )
{
	foreach ( int scoreType, int count in counts )
	{
		int value = scoreType == FS_ScoreType.PLAYERSCORE ? count : count * FS_Scenarios_GetEventScoreValue( scoreType )
		Remote_CallFunction_NonReplay( player, "ServerCallback_FS_Scenarios_Standing", standingType, scoreType,
			ClampInt( value, -FS_SCENARIOS_STAT_LIMIT, FS_SCENARIOS_STAT_LIMIT ), ClampInt( count, 0, FS_SCENARIOS_STAT_LIMIT ) )
	}
}
