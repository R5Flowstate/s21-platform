// Flowstate 1v1. CafeFPS (makimakima, mkos).

global function INIT_playerChallengesStruct
global function ClientCommand_mkos_challenge
global function ClientCommand_1v1_ChalShortcut
global function ClientCommand_1v1_AcceptShortcut
global function ClientCommand_1v1_DenyShortcut
global function FS_1v1_PushChallengeState
global function FS_1v1_ChallengesOnDisconnect
global function IsPlayerPendingChallenge
global function IsPlayerPendingLockOpponent
global function resetChallenges
global function endLock1v1
global function getLock1v1OpponentOfPlayer
global function isChalValid
global function returnChallengedPlayer
global function Gamemode1v1_OnChallengeMatchCreated

//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 12: CHALLENGE SYSTEM
// 1v1 challenge and lock system
//
//═══════════════════════════════════════════════════════════════════════════════

void function INIT_playerChallengesStruct( entity player )
{
	for ( int i = file.allChallenges.len() - 1; i >= 0; i-- )
	{
		if ( !isChalValid( file.allChallenges[i] ) )
			file.allChallenges.fastremove( i )
	}

	ChallengesStruct existing = getChallengeListForPlayer( player )
	if ( isChalValid( existing ) )
		return

	ChallengesStruct chalStruct
	chalStruct.player = player
	chalStruct.isValid = true
	file.allChallenges.append( chalStruct )
}

string function Challenge_JoinArgs( array<string> args, int startIdx )
{
	if ( args.len() <= startIdx )
		return ""

	string joined = args[startIdx]
	for ( int i = startIdx + 1; i < args.len(); i++ )
		joined += " " + args[i]
	return joined
}

bool function FS_1v1_IsLiveDuelPair( entity a, entity b )
{
	if ( !IsValid( a ) || !IsValid( b ) )
		return false

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( a )
	if ( !Gamemode1v1_IsMatchValid( group ) )
		return false

	return ( group.player1 == a && group.player2 == b ) || ( group.player1 == b && group.player2 == a )
}

string function FS_1v1_ChalSendKey( int fromHandle, int toHandle )
{
	return format( "%d:%d", fromHandle, toHandle )
}

void function FS_1v1_RecordSendTime( int fromHandle, int toHandle )
{
	file.chalLastSent[ FS_1v1_ChalSendKey( fromHandle, toHandle ) ] <- Time()
}

float function FS_1v1_GetSendTime( int fromHandle, int toHandle )
{
	string key = FS_1v1_ChalSendKey( fromHandle, toHandle )
	if ( key in file.chalLastSent )
		return file.chalLastSent[ key ]

	return -1.0
}

int function FS_1v1_CountOutgoing( entity challenger )
{
	if ( !IsValid( challenger ) )
		return 0

	int n = 0
	int handle = challenger.p.handle
	foreach ( ChallengesStruct chalStruct in file.allChallenges )
	{
		if ( !isChalValid( chalStruct ) )
			continue
		if ( handle in chalStruct.challengers )
			n++
	}

	return n
}

void function FS_1v1_PruneDeadAndExpired( entity player )
{
	ChallengesStruct chalStruct = getChallengeListForPlayer( player )
	if ( !isChalValid( chalStruct ) )
		return

	array<int> drop
	foreach ( int existingHandle, float existingTime in chalStruct.challengers )
	{
		entity existing = GetEntityFromEncodedEHandle( existingHandle )
		if ( !IsValid( existing ) || Time() - existingTime >= CHALLENGE_OFFER_TTL )
			drop.append( existingHandle )
	}

	foreach ( int dropHandle in drop )
	{
		entity sender = GetEntityFromEncodedEHandle( dropHandle )
		removeChallenger( player, dropHandle )
		if ( IsValid( sender ) )
		{
			LocalEventMsg( sender, "#FS_ChalExpired", player.GetPlayerName() )
			FS_1v1_PushChallengeState( sender )
		}
	}
}

array<int> function FS_1v1_IncomingNewest( entity player )
{
	FS_1v1_PruneDeadAndExpired( player )

	array<int> handles
	ChallengesStruct chalStruct = getChallengeListForPlayer( player )
	if ( !isChalValid( chalStruct ) )
		return handles

	foreach ( int existingHandle, float existingTime in chalStruct.challengers )
		handles.append( existingHandle )

	handles.sort( int function( int a, int b ) : ( chalStruct )
	{
		float ta = chalStruct.challengers[ a ]
		float tb = chalStruct.challengers[ b ]
		if ( ta < tb )
			return 1
		if ( ta > tb )
			return -1
		return 0
	} )

	return handles
}

entity function FS_1v1_PromptChallenger( entity player )
{
	array<int> incoming = FS_1v1_IncomingNewest( player )
	entity none
	if ( incoming.len() <= 0 )
		return none

	return GetEntityFromEncodedEHandle( incoming[ 0 ] )
}

void function FS_1v1_PushChallengeState( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( player.IsBot() || !FS_1v1_PlayerHasClient( player ) )
		return

	array<int> incoming = FS_1v1_IncomingNewest( player )
	string promptName = ""
	if ( incoming.len() > 0 )
	{
		entity prompt = GetEntityFromEncodedEHandle( incoming[ 0 ] )
		if ( IsValid( prompt ) )
			promptName = prompt.GetPlayerName()
	}

	int extra = incoming.len() - 1
	if ( extra < 0 )
		extra = 0

	string outgoingName = ""
	int selfHandle = player.p.handle
	foreach ( ChallengesStruct chalStruct in file.allChallenges )
	{
		if ( !isChalValid( chalStruct ) )
			continue
		if ( !( selfHandle in chalStruct.challengers ) )
			continue
		if ( IsValid( chalStruct.player ) )
			outgoingName = chalStruct.player.GetPlayerName()
		break
	}

	array<int> promptPacked = Scoreboard1v1_PackName( promptName )
	array<int> outPacked = Scoreboard1v1_PackName( outgoingName )
	Remote_CallFunction_NonReplay( player, "ServerCallback_1v1_ChallengeState",
		extra,
		promptPacked[ 0 ], promptPacked[ 1 ], promptPacked[ 2 ], promptPacked[ 3 ],
		outPacked[ 0 ], outPacked[ 1 ], outPacked[ 2 ], outPacked[ 3 ] )

	int count = incoming.len()
	if ( count > 3 )
		count = 3

	array<int> n0 = Scoreboard1v1_PackName( "" )
	array<int> n1 = Scoreboard1v1_PackName( "" )
	array<int> n2 = Scoreboard1v1_PackName( "" )
	if ( count > 0 )
	{
		entity e0 = GetEntityFromEncodedEHandle( incoming[ 0 ] )
		if ( IsValid( e0 ) )
			n0 = Scoreboard1v1_PackName( e0.GetPlayerName() )
	}
	if ( count > 1 )
	{
		entity e1 = GetEntityFromEncodedEHandle( incoming[ 1 ] )
		if ( IsValid( e1 ) )
			n1 = Scoreboard1v1_PackName( e1.GetPlayerName() )
	}
	if ( count > 2 )
	{
		entity e2 = GetEntityFromEncodedEHandle( incoming[ 2 ] )
		if ( IsValid( e2 ) )
			n2 = Scoreboard1v1_PackName( e2.GetPlayerName() )
	}

	Remote_CallFunction_NonReplay( player, "ServerCallback_1v1_ChallengeInbox",
		count,
		n0[ 0 ], n0[ 1 ], n0[ 2 ], n0[ 3 ],
		n1[ 0 ], n1[ 1 ], n1[ 2 ], n1[ 3 ],
		n2[ 0 ], n2[ 1 ], n2[ 2 ], n2[ 3 ] )
}

void function FS_1v1_ChallengeOfferTTL( entity challenged, int challengerHandle, float stamp )
{
	wait CHALLENGE_OFFER_TTL

	if ( !IsValid( challenged ) )
		return

	ChallengesStruct chalStruct = getChallengeListForPlayer( challenged )
	if ( !isChalValid( chalStruct ) )
		return
	if ( !( challengerHandle in chalStruct.challengers ) )
		return
	if ( chalStruct.challengers[ challengerHandle ] != stamp )
		return

	entity sender = GetEntityFromEncodedEHandle( challengerHandle )
	removeChallenger( challenged, challengerHandle )
	if ( IsValid( sender ) )
	{
		LocalEventMsg( sender, "#FS_ChalExpired", challenged.GetPlayerName() )
		FS_1v1_PushChallengeState( sender )
	}
	FS_1v1_PushChallengeState( challenged )
}

void function FS_1v1_DeclineOtherIncoming( entity player, entity keep )
{
	if ( !IsValid( player ) )
		return

	ChallengesStruct chalStruct = getChallengeListForPlayer( player )
	if ( !isChalValid( chalStruct ) )
		return

	int keepHandle = -1
	if ( IsValid( keep ) )
		keepHandle = keep.p.handle

	array<int> drop
	foreach ( int existingHandle, float existingTime in chalStruct.challengers )
	{
		if ( existingHandle == keepHandle )
			continue
		drop.append( existingHandle )
	}

	foreach ( int dropHandle in drop )
	{
		entity sender = GetEntityFromEncodedEHandle( dropHandle )
		removeChallenger( player, dropHandle )
		if ( IsValid( sender ) )
		{
			LocalEventMsg( sender, "#FS_ChalDeclined", player.GetPlayerName() )
			FS_1v1_PushChallengeState( sender )
		}
	}

	FS_1v1_PushChallengeState( player )
}

void function FS_1v1_RevokeOutgoingExcept( entity sender, entity keep )
{
	if ( !IsValid( sender ) )
		return

	int senderHandle = sender.p.handle
	int keepHandle = -1
	if ( IsValid( keep ) )
		keepHandle = keep.p.handle

	foreach ( ChallengesStruct chalStruct in file.allChallenges )
	{
		if ( !isChalValid( chalStruct ) )
			continue
		if ( !( senderHandle in chalStruct.challengers ) )
			continue
		if ( IsValid( chalStruct.player ) && chalStruct.player.p.handle == keepHandle )
			continue

		removeChallenger( chalStruct.player, senderHandle )
		FS_1v1_PushChallengeState( chalStruct.player )
	}

	FS_1v1_PushChallengeState( sender )
}

void function FS_1v1_OnLockArmed( entity player, entity challenger )
{
	FS_1v1_DeclineOtherIncoming( player, challenger )
	FS_1v1_DeclineOtherIncoming( challenger, player )
	FS_1v1_RevokeOutgoingExcept( player, challenger )
	FS_1v1_RevokeOutgoingExcept( challenger, player )
}

void function FS_1v1_ChallengesOnDisconnect( entity player )
{
	if ( !IsValid( player ) )
		return

	ChallengesStruct own = getChallengeListForPlayer( player )
	if ( isChalValid( own ) )
	{
		foreach ( int existingHandle, float existingTime in own.challengers )
		{
			entity sender = GetEntityFromEncodedEHandle( existingHandle )
			if ( IsValid( sender ) )
			{
				LocalEventMsg( sender, "#FS_ChalQuit" )
				FS_1v1_PushChallengeState( sender )
			}
		}
	}

	int handle = player.p.handle
	foreach ( ChallengesStruct chalStruct in file.allChallenges )
	{
		if ( !isChalValid( chalStruct ) )
			continue
		if ( !( handle in chalStruct.challengers ) )
			continue

		removeChallenger( chalStruct.player, handle )
		FS_1v1_PushChallengeState( chalStruct.player )
	}
}

void function FS_1v1_QueueIfIdleForChallenge( entity player )
{
	if ( !IsValid( player ) )
		return
	if ( IsPlayerInProgress( player.p.handle ) )
		return
	if ( Gamemode1v1_IsPlayerWaiting( player ) )
		return

	bool fromResting = Gamemode1v1_IsPlayerResting( player )
	Gamemode1v1_AddPlayerToQueue( player, true, fromResting )
}

void function FS_1v1_ArmAcceptedChallenge( entity player, entity challenger )
{
	player.p.rest_request = false
	challenger.p.rest_request = false

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	if ( Gamemode1v1_IsMatchValid( group ) )
	{
		entity opp = player == group.player1 ? group.player2 : group.player1
		if ( IsValid( opp ) && opp == challenger )
		{
			group.IsKeep = true
			FS_1v1_OnLockArmed( player, challenger )
			Gamemode1v1_OnChallengeMatchCreated( group )
			return
		}
	}

	FS_1v1_OnLockArmed( player, challenger )
	SetUpChallengeNotifications( player, challenger )
	FS_1v1_QueueIfIdleForChallenge( player )
	FS_1v1_QueueIfIdleForChallenge( challenger )
	thread TriggerMatchmaking()
}

bool function IsPlayerPendingChallenge( entity player )
{
	return ( player.p.handle in file.acceptedChallenges )
}

bool function IsPlayerPendingLockOpponent( entity player )
{
	foreach ( challenged, opponent in file.acceptedChallenges )
	{
		if( !IsValid( opponent ) )
			continue

		if ( player == opponent )
			return true
	}

	return false
}

void function SetChallengeNotifications( array<entity> players, bool setting )
{
	foreach ( player in players )
	{
		if( !IsValid( player ) )
			continue

		player.p.challengenotify = setting

		if( setting )
			thread ChallengeNotificationsThread( player )
	}
}

void function SetUpChallengeNotifications( entity player, entity challenger )
{
	player.p.waitingFor1v1 = true
	challenger.p.waitingFor1v1 = true

	LocalMsg( player, "#FS_ChalAccepted" )
	LocalMsg( challenger, "#FS_ChalAccepted" )

	player.p.entLastChallenger = challenger
	challenger.p.entLastChallenger = player

	SetChallengeNotifications( [ player, challenger ], true )
}

bool function acceptChallenge( entity player, entity challenger )
{
	if( !IsValid( challenger ) )
		return false

	if( IsPlayerPendingChallenge( player ) || IsPlayerPendingLockOpponent( player ) )
	{
		#if DEVELOPER
			printt("ALREADY IN CHALLENGE", "do /end or /clear to finish" )
		#endif

		LocalMsg( player, "#FS_InChallenge", "#FS_InChallenge_SUBSTR" )
		return false
	}

	if( IsPlayerPendingChallenge( challenger ) || IsPlayerPendingLockOpponent( challenger ) )
	{
		#if DEVELOPER
			printt("PLAYER ALREADY IN CHALLENGE" )
		#endif

		LocalMsg( player, "#FS_PlayerInChal" )
		return false
	}

	//sqprint("accepted")
	ChallengesStruct chalStruct = getChallengeListForPlayer( player )

	if ( isChalValid( chalStruct ) && challenger.p.handle in chalStruct.challengers )
	{
		file.acceptedChallenges[ player.p.handle ] <- challenger
		removeChallenger( player, challenger.p.handle )
		FS_1v1_ArmAcceptedChallenge( player, challenger )
		FS_1v1_PushChallengeState( player )
		FS_1v1_PushChallengeState( challenger )
	}
	else
	{
		#if DEVELOPER
			printt("NO CHALLENGES FROM PLAYER", "Maybe revoked? Check with /list")
		#endif

		LocalMsg( player, "#FS_NoChalFromPlayer", "#FS_NoChalFromPlayer_SUBSTR" )
		return false
	}

	return true
}

bool function acceptRecentChallenge( entity player )
{
	if( IsPlayerPendingChallenge( player ) || IsPlayerPendingLockOpponent( player ) )
	{
		#if DEVELOPER
			printt("ALREADY IN CHALLENGE", "do /end or /clear to finish" )
		#endif

		LocalMsg( player, "#FS_InChallenge", "#FS_InChallenge_SUBSTR" )
		return true
	}

	ChallengesStruct chalStruct = getChallengeListForPlayer( player )

	if( !isChalValid( chalStruct ) )
		return false

	if( chalStruct.challengers.len() <= 0 )
	{
		#if DEVELOPER
			printt( "NO CHALLENGES", "Maybe revoked? Check with /list" )
		#endif

		LocalMsg( player, "#FS_NoChal", "#FS_NoChalFromPlayer_SUBSTR" )
		return false
	}

	entity recentChallenger = FS_1v1_PromptChallenger( player )
	int recentChallenger_eHandle = -1
	if ( IsValid( recentChallenger ) )
		recentChallenger_eHandle = recentChallenger.p.handle

	if( !IsValid( recentChallenger ) )
	{
		if ( removeChallenger( player, recentChallenger_eHandle ) )
		{
			#if DEVELOPER
				printt( "CHALLENGER QUIT" )
			#endif

			LocalMsg( player, "#FS_ChalQuit" )
		}
		else
		{
			#if DEVELOPER
				printt("PLAYER NOT IN CHALLENGES" )
			#endif

			LocalMsg( player, "#FS_PlayerNotInChallenges" )
		}

		return false
	}

	if( !IsValid( recentChallenger ) || IsPlayerPendingChallenge( recentChallenger ) || IsPlayerPendingLockOpponent( recentChallenger ) )
	{
		#if DEVELOPER
			printt( "PLAYER ALREADY IN CHALLENGE", IsValid( recentChallenger ), IsPlayerPendingChallenge( recentChallenger ), IsPlayerPendingLockOpponent( recentChallenger ) )
		#endif

		LocalMsg( player, "#FS_PlayerInChal" )
		return false
	}

	#if DEVELOPER
		printt( "accepting player:", player, "challenger accepted:", recentChallenger )
	#endif

	file.acceptedChallenges[ player.p.handle ] <- recentChallenger
	removeChallenger( player, recentChallenger.p.handle )
	FS_1v1_ArmAcceptedChallenge( player, recentChallenger )
	FS_1v1_PushChallengeState( player )
	FS_1v1_PushChallengeState( recentChallenger )

	return true
}

int function addToChallenges( entity challenger, entity challengedPlayer )
{
	ChallengesStruct chalStruct = getChallengeListForPlayer( challengedPlayer )

	if( GetGlobalNetInt( "FSDM_GameState" ) != eTDMState.IN_PROGRESS )
		return 6

	if( !isChalValid( chalStruct ) )
		return 5

	if( !challengedPlayer.p.lock1v1_setting )
		return 4

	FS_1v1_PruneDeadAndExpired( challengedPlayer )

	int challengerHandle = challenger.p.handle
	if ( challengerHandle in chalStruct.challengers )
		return 8

	float lastSent = FS_1v1_GetSendTime( challengerHandle, challengedPlayer.p.handle )
	if ( lastSent >= 0.0 && Time() - lastSent <= CHALLENGE_SEND_COOLDOWN )
		return 3

	if ( FS_1v1_CountOutgoing( challenger ) >= 1 && !FS_1v1_IsLiveDuelPair( challenger, challengedPlayer ) )
		return 7

	if ( chalStruct.challengers.len() >= MAX_CHALLENGERS )
		return 2

	float stamp = Time()
	chalStruct.challengers[ challengerHandle ] <- stamp
	FS_1v1_RecordSendTime( challengerHandle, challengedPlayer.p.handle )
	thread FS_1v1_ChallengeOfferTTL( challengedPlayer, challengerHandle, stamp )
	return 1
}

bool function endLock1v1( entity player, bool addmsg = true, bool revoke = false )
{
	if( !IsValid ( player ) )
		return false

	ClearNotifications( player, eNotify.CHALLENGE )
	player.Signal( "ChallengeEnded" )
	int iRemoveOpponent = 0
	entity opponent
	entity challenged
	int playerHandle = player.p.handle

	if( playerHandle in file.acceptedChallenges )
	{
		opponent = file.acceptedChallenges[ playerHandle ]
		delete file.acceptedChallenges[ playerHandle ]
		iRemoveOpponent = 1
	}
	else
	{
		challenged = returnChallengedPlayer( player )

		if ( IsValid( challenged ) )
		{
			int challenegedHandle = challenged.p.handle
			if( challenegedHandle in file.acceptedChallenges )
			{
				delete file.acceptedChallenges[ challenegedHandle ]
				iRemoveOpponent = 2
			}
		}
		else
		{
			MatchGroup liveGroup = Gamemode1v1_GetPlayerSoloGroup( player )
			if ( liveGroup.isValid && liveGroup.IsKeep )
			{
				iRemoveOpponent = 3
				opponent = player == liveGroup.player1 ? liveGroup.player2 : liveGroup.player1
			}
			else if( addmsg )
			{
				LocalMsg( player, "#FS_NoChalToEnd" )
				return true
			}
		}
	}

	if( iRemoveOpponent == 1 && IsValid( opponent ) )
	{
		if( addmsg || revoke )
			LocalMsg( opponent, "#FS_ChalEnded" )

		removeChallenger( player, opponent.p.handle )
		player.p.waitingFor1v1 = false
		opponent.p.waitingFor1v1 = false
		opponent.Signal( "ChallengeEnded" )
	}

	if ( iRemoveOpponent == 2 && IsValid( challenged ) )
	{
		if( addmsg || revoke )
			LocalMsg( challenged, "#FS_ChalEnded")

		removeChallenger( challenged, playerHandle )
		player.p.waitingFor1v1 = false
		challenged.p.waitingFor1v1 = false
		challenged.Signal( "ChallengeEnded" )
	}

	if ( iRemoveOpponent == 3 )
	{
		player.p.waitingFor1v1 = false
		if ( IsValid( opponent ) )
		{
			opponent.p.waitingFor1v1 = false
			opponent.Signal( "ChallengeEnded" )
			if( addmsg || revoke )
				LocalMsg( opponent, "#FS_ChalEnded" )
		}
	}

	if ( iRemoveOpponent > 0 && IsPlayerInProgress( playerHandle ) )
	{
		MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )

		if( addmsg )
			LocalMsg( player, "#FS_ChalEnded" )

		if( group.isValid )
		{
			group.IsKeep = false
			//group.IsFinished = true

			thread //(mk): without this delay, two calls can happen to rest on same frame, .001 apart. Resting list handles each other opponent causing undefined game behavior when group is still keep.
			(
				void function() : ( group )
				{
					wait 0.1

					if( !group.isValid )
						return

					int endedHandle = group.groupHandle
					entity player1 = group.player1
					entity player2 = group.player2

					// If either re-paired into a new match, do not ForceRest out of that match.
					if ( IsValid( player1 ) )
					{
						MatchGroup cur = Gamemode1v1_GetPlayerSoloGroup( player1 )
						if ( cur.isValid && cur.groupHandle != endedHandle )
							return
					}
					if ( IsValid( player2 ) )
					{
						MatchGroup cur2 = Gamemode1v1_GetPlayerSoloGroup( player2 )
						if ( cur2.isValid && cur2.groupHandle != endedHandle )
							return
					}

					if( IsValid( player1 ) && !Gamemode1v1_IsPlayerInState( player1, e1v1State.RESTING ) )
						Gamemode1v1_ForceRest( player1 )

					WaitFrame()

					if( !group.isValid )
						return

					if( IsValid( player2 ) && !Gamemode1v1_IsPlayerInState( player2, e1v1State.RESTING ) )
						Gamemode1v1_ForceRest( player2 )

					AssignLegendToGroup( -1, [ group.player1, group.player2 ] )
					_SendMatchRecaps( group )
				}
			)()
		}
	}

	if( iRemoveOpponent > 0 )
	{
		entity opp

		if( IsValid( opponent ) )
		{
			ClearNotifications( opponent )
			opp = opponent
		}
		else if( IsValid( challenged ) )
		{
			ClearNotifications( challenged )
			opp = challenged
		}

		if( addmsg )
			LocalMsg( player, "#FS_ChalEnded" )

		ClearNotifications( player )
		SetChallengeNotifications( [ player, opp ], false )

		FS_1v1_PushChallengeState( player )
		if ( IsValid( opp ) )
			FS_1v1_PushChallengeState( opp )

		// Both sides just became pairable again; nothing else fires for a lock release.
		thread TriggerMatchmaking()
	}

	return true
}

ChallengesStruct function getChallengeListForPlayer( entity player )
{
	ChallengesStruct chalStruct

	if( !IsValid( player ) )
		return chalStruct

	foreach ( challengeStruct in file.allChallenges )
	{
		if( !IsValid( challengeStruct ) )
			continue

		if ( IsValid( challengeStruct.player ) && challengeStruct.player == player )
			return challengeStruct
	}

	return chalStruct
}

entity function getLock1v1OpponentOfPlayer( entity player )
{
	entity p

	if ( !IsValid( player ) )
		return p

	int playerEHandle = player.p.handle
	if( !( playerEHandle in file.acceptedChallenges ) )
		return p
	if( !( playerEHandle in file.waitingQueue ) )
		return p

	entity opponent = file.acceptedChallenges[ playerEHandle ]
	if( !IsValid( opponent ) )
		return p
	if( !( opponent.p.handle in file.waitingQueue ) )
		return p

	return opponent
}

void function Gamemode1v1_OnChallengeMatchCreated( MatchGroup group )
{
	if ( !IsValid( group.player1 ) || !IsValid( group.player2 ) )
		return

	group.player1.p.waitingFor1v1 = false
	group.player2.p.waitingFor1v1 = false

	int h1 = group.player1.p.handle
	int h2 = group.player2.p.handle
	if ( h1 in file.acceptedChallenges )
		delete file.acceptedChallenges[ h1 ]
	if ( h2 in file.acceptedChallenges )
		delete file.acceptedChallenges[ h2 ]

	LocalMsg( group.player1, "#FS_ChalStarted" )
	LocalMsg( group.player2, "#FS_ChalStarted" )
	group.player1.Signal( "ChallengeStarted" )
	group.player2.Signal( "ChallengeStarted" )
	FS_1v1_PushChallengeState( group.player1 )
	FS_1v1_PushChallengeState( group.player2 )
	FS_1v1_QueueChallengePick( group.player1, true )
	FS_1v1_QueueChallengePick( group.player2, true )
}

bool function isChalValid( ChallengesStruct chalStruct )
{
	return ( chalStruct.isValid && IsValid( chalStruct.player ) )
}

string function listPlayerChallenges( entity player )
{
	ChallengesStruct chalStruct = getChallengeListForPlayer( player )

	string list
	string emphasis
	entity opponent

	if( IsPlayerPendingChallenge( player ) || IsPlayerPendingLockOpponent( player ) )
	{
		opponent = returnChallengedPlayer( player )

		if( IsValid( opponent ) )
			list += format("***ACTIVE CHALLENGE***:[ %s ]\n\n", opponent.p.name )
	}
	else
	{
		list += "No active challenge yet... \n\n"
	}

	if ( !isChalValid( chalStruct ) )
		return list

	if( chalStruct.challengers.len() == 0 )
		list += "No incoming challenges yet..."

	array<int> deadChallengers

	foreach ( challenger_eHandle, chalTime in chalStruct.challengers )
	{
		entity challenger = GetEntityFromEncodedEHandle ( challenger_eHandle )

		if ( IsValid( challenger ) )
			list += format("Challenger: %s, Seconds ago: %d \n", challenger.p.name, Time() - chalTime )
		else
			deadChallengers.append( challenger_eHandle )
	}

	// Deferred: removeChallenger deletes out of the very table being walked.
	foreach ( int deadHandle in deadChallengers )
		removeChallenger( player, deadHandle )

	return list
}

bool function removeChallenger( entity player, int challenger_eHandle )
{
	ChallengesStruct chalStruct = getChallengeListForPlayer( player )

	if ( !isChalValid( chalStruct ) )
		return false

	if ( challenger_eHandle in chalStruct.challengers )
	{
		delete getChallengeListForPlayer( player ).challengers[ challenger_eHandle ]
		return true
	}

	return false
}

entity function returnChallengedPlayer( entity player )
{
	int playerHandle = player.p.handle
	entity p

	foreach( challenged_eHandle, challenger in file.acceptedChallenges )
	{
		if( !IsValid( challenger ) )
			continue

		if ( challenger == player )
		{
			return GetEntityFromEncodedEHandle( challenged_eHandle )
		}
		else if ( challenged_eHandle == playerHandle )
		{
			return challenger
		}
	}

	return p
}


//═══════════════════════════════════════════════════════════════════════════════
//
// ClientCommand_mkos_challenge (from Section 5)
//
//═══════════════════════════════════════════════════════════════════════════════

void function ClientCommand_1v1_ChalShortcut( entity player, array<string> args )
{
	array<string> forwarded = [ "chal" ]
	foreach ( string a in args )
		forwarded.append( a )
	ClientCommand_mkos_challenge( player, forwarded )
}

void function ClientCommand_1v1_AcceptShortcut( entity player, array<string> args )
{
	array<string> forwarded = [ "accept" ]
	foreach ( string a in args )
		forwarded.append( a )
	ClientCommand_mkos_challenge( player, forwarded )
}

void function ClientCommand_1v1_DenyShortcut( entity player, array<string> args )
{
	array<string> forwarded = [ "deny" ]
	foreach ( string a in args )
		forwarded.append( a )
	ClientCommand_mkos_challenge( player, forwarded )
}

void function ClientCommand_mkos_challenge(entity player, array<string> args)
{
	if ( !CheckRate( player, "chal", COMMAND_RATE_LIMIT, true ) )
		return;
	if( GetTDMState() != eTDMState.IN_PROGRESS )
	{
		LocalMsg( player, "#FS_GameNotPlaying" )
		return;	}

	if( !settings.enableChallenges )
	{
		LocalMsg( player, "#FS_Challenges_Disabled" )
		return;	}

	if ( args.len() < 1 )
	{
		LocalMsg( player, "#FS_Usage", "#FS_Challenge_usage" )
		return;	}

	string requestedData = args[ 0 ]
	string param = Challenge_JoinArgs( args, 1 )

	switch( requestedData )
	{
		case "challenge":
		case "chal":

			if( args.len() < 2 )
			{
				LocalMsg( player, "#FS_Challenges", "#FS_Challenge_usage_2", eMsgUI.SWEEP, 30 )
			}
			else
			{
				entity challengedPlayer

				if ( param == "player" )
				{
					MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )

					if( !IsValid( group.player1 ) )
					{
						LocalMsg( player, "#FS_NotInFight" )
						return;					}

					challengedPlayer = player == group.player1 ? group.player2 : group.player1
				}
				else
				{
					challengedPlayer = GetPlayer( param )
				}

				if( player == challengedPlayer )
				{
					LocalMsg( player, "#FS_CantChalSelf" )
					return;				}

				if ( IsValid( challengedPlayer ) )
				{
					int result = addToChallenges( player, challengedPlayer )
					string error = ""

					switch( result )
					{
						case 1:
							LocalEventMsg( player, "#FS_ChalSent" )
							LocalEventMsg( challengedPlayer, "#FS_ChalOffer", player.p.name )
							FS_1v1_PushChallengeState( player )
							FS_1v1_PushChallengeState( challengedPlayer )
							break

						case 2:
							LocalEventMsg( player, "#FS_ChalInboxFull" )
							break

						case 3:
							LocalEventMsg( player, "#FS_ChalCooldown" )
							break

						case 4:
							LocalEventMsg( player, "#FS_ChalNotAccepting" )
							break

						case 5:
							error = "Player not initialized";
							break

						case 6:
							error = "Game not in progress";
							break

						case 7:
							LocalEventMsg( player, "#FS_ChalBusy" )
							break

						case 8:
							LocalEventMsg( player, "#FS_ChalPending" )
							break
					}

					if( result == 5 || result == 6 )
						LocalMsg( player, "#FS_FAILED", "", eMsgUI.DEFAULT, 5, "", "Couldn't add challenge: " + error )

				}
				else
				{
					LocalMsg( player, "#FS_InvalidPlayer" )
				}
			}

			return;
		case "accept":

			if( args.len() <= 1 )
			{
				acceptRecentChallenge( player )
			}
			else
			{
				entity challenger = GetPlayer( param )

				if( !IsValid( challenger ) )
				{
					LocalMsg( player, "#FS_InvalidPlayer" )
					return;				}

				if ( acceptChallenge( player, challenger ) )
				{
					//sqprint("success")
				}
				else
				{
					//sqprint("failure")
				}
			}

			return;
		case "deny":

			entity denyTarget
			if ( args.len() <= 1 )
			{
				denyTarget = FS_1v1_PromptChallenger( player )
			}
			else
			{
				denyTarget = GetPlayer( param )
			}

			if ( !IsValid( denyTarget ) )
			{
				LocalMsg( player, "#FS_InvalidPlayer" )
				return
			}

			if ( removeChallenger( player, denyTarget.p.handle ) )
			{
				LocalEventMsg( denyTarget, "#FS_ChalDeclined", player.p.name )
				FS_1v1_PushChallengeState( player )
				FS_1v1_PushChallengeState( denyTarget )
			}
			else
			{
				LocalMsg( player, "#FS_PlayerNotInChallenges" )
			}

			return;
		case "list":

			// CheckRate returns true when allowed; inverted check made list never run.
			if( !CheckRate( player, "chal_list", 3.0, true ) )
				return;
			string list = listPlayerChallenges( player )
			string title = "CURRENT CHALLENGERS"

			Message( player, title, list, 20 )

			return;
		case "end":

			endLock1v1( player )
			return;
		case "remove":

			entity challenger = GetPlayer( param )

			if( IsValid( challenger ) )
			{
				if ( removeChallenger( player, challenger.p.handle ) )
				{
					LocalEventMsg( challenger, "#FS_ChalDeclined", player.p.name )
					LocalMsg( player, "#FS_RemovedChallenger", "", eMsgUI.DEFAULT, 5, challenger.p.name )
					FS_1v1_PushChallengeState( player )
					FS_1v1_PushChallengeState( challenger )
				}
				else
					LocalMsg( player, "#FS_PlayerNotInChallenges" )

				if ( returnChallengedPlayer( player ) == challenger )
					endLock1v1( player, false )
			}

			return;
		case "clear":

			player.p.waitingFor1v1 = false
			ChallengesStruct chalStruct = getChallengeListForPlayer( player )

			if( isChalValid( chalStruct ) )
			{
				array<int> drop
				foreach ( int existingHandle, float existingTime in chalStruct.challengers )
					drop.append( existingHandle )

				foreach ( int dropHandle in drop )
				{
					entity sender = GetEntityFromEncodedEHandle( dropHandle )
					removeChallenger( player, dropHandle )
					if ( IsValid( sender ) )
					{
						LocalEventMsg( sender, "#FS_ChalDeclined", player.p.name )
						FS_1v1_PushChallengeState( sender )
					}
				}
			}

			endLock1v1( player, false )
			FS_1v1_PushChallengeState( player )
			LocalMsg( player, "#FS_ChallengersCleared" )

			return;
		case "revoke":

			if( param == "all" )
			{
				int revoked = 0
				string removed = ""

				foreach ( revokedFromPlayer in GetPlayerArray() )
				{
					if( IsValid( revokedFromPlayer ) )
					{
						if( removeChallenger( revokedFromPlayer, player.p.handle ) )
						{
							revoked++
							removed += revokedFromPlayer.p.name + "\n"
						}
					}
				}

				if ( revoked > 0 )
				{
					endLock1v1( player, false )
					LocalMsg( player, "#FS_RevokedX", "#FS_RevokedFromPlayers", eMsgUI.SWEEP, 10, revoked.tostring(), removed )
					FS_1v1_PushChallengeState( player )
					foreach ( revokedFromPlayer in GetPlayerArray() )
					{
						if ( IsValid( revokedFromPlayer ) )
							FS_1v1_PushChallengeState( revokedFromPlayer )
					}
				}
				else
				{
					LocalMsg( player, "#FS_NoChallengesToRemove" )
				}

				return;			}

			entity playerToRevoke = GetPlayer( param )
			if( IsValid( playerToRevoke ) )
			{
				if( removeChallenger( playerToRevoke, player.p.handle ) )
				{
					if( returnChallengedPlayer( player ) == playerToRevoke )
						endLock1v1( player, false, true )

					LocalMsg( player, "#FS_ChalRevoked" )
					FS_1v1_PushChallengeState( player )
					FS_1v1_PushChallengeState( playerToRevoke )
				}
				else
				{
					endLock1v1( player, false, false )
					LocalMsg( player, "#FS_PlayerNotInChallenges" )
				}
			}
			else
			{
				LocalMsg( player, "#FS_PlayerQuit" )
			}

			return;
		case "cycle":

			if( !Gamemode1v1_IsPlayerInChallenge( player ) )
			{
				LocalMsg( player, "#FS_NotInChal" )
				return;			}

			MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )

			if( group.isValid )
			{
				if( group.cycle )
				{
					group.cycle = false
					LocalMsg( group.player1, "#FS_SpawnCycDisabled" )
					LocalMsg( group.player2, "#FS_SpawnCycDisabled" )
				}
				else
				{
					group.cycle = true
					LocalMsg( group.player1, "#FS_SpawnCycEnabled" )
					LocalMsg( group.player2, "#FS_SpawnCycEnabled" )
				}
			}

			return;

		case "swap":

			if( !Gamemode1v1_IsPlayerInChallenge( player ) )
			{
				LocalMsg( player, "#FS_NotInChal" )
				return;			}

			MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
			if( group.isValid )
			{
				if( group.swap )
				{
					group.swap = false
					LocalMsg( group.player1, "#FS_SpawnSwapDisabled" )
					LocalMsg( group.player2, "#FS_SpawnSwapDisabled" )
				}
				else
				{
					group.swap = true
					LocalMsg( group.player1, "#FS_SpawnSwapEnabled" )
					LocalMsg( group.player2, "#FS_SpawnSwapEnabled" )
				}
			}

			return;
		case "legend":
		{
			string refusal = FS_1v1_QueueChallengePick( player )
			LocalMsg( player, refusal != "" ? refusal : "#FS_ChalLegendNextRound" )
			return;
		}
		case "outlist":

			string list = ""

			foreach( chalplayer in GetPlayerArray() )
			{
				if ( !IsValid( chalplayer ) )
					continue

				ChallengesStruct chalStruct = getChallengeListForPlayer( chalplayer )
				if( isChalValid( chalStruct ) )
				{
					if ( player.p.handle in chalStruct.challengers )
						list += format("Outgoing challenge to: %s \n", chalplayer.p.name )
				}
			}

			if( list != "" )
				LocalMsg( player, "#FS_OutgoingChal", "", eMsgUI.SWEEP, 15, "", list )
			else
				LocalMsg( player, "#FS_NoOutgoingChal" )

			return;
		default:
			LocalMsg( player, "#FS_FAILED", "#FS_UnknownCommand" )
			return;	}

	return;}


//═══════════════════════════════════════════════════════════════════════════════
//
// ChallengeNotificationsThread (from Section 18)
//
//═══════════════════════════════════════════════════════════════════════════════

void function ChallengeNotificationsThread( entity player )
{
	entity opponent = player.p.entLastChallenger
	if ( !IsValid( opponent ) )
		return

	// ChallengeEnded: cancel/revoke/end must stop panels (not only ChallengeStarted).
	EndSignal( player, "ChallengeStarted", "ChallengeEnded", "OnDisconnecting" )
	EndSignal( opponent, "ChallengeStarted", "ChallengeEnded", "OnDisconnecting" )

	OnThreadEnd
	(
		void function() : ( player )
		{
			if( IsValid( player ) )
				ClearNotifications( player )
		}
	)

	int iStatusText = 0
	bool waitingForSelfToJoin = false
	bool HasChalText = false

	for( ; ; )
	{
		wait 1

		if ( !IsValid( player ) )
			break

		if( !HasChalText )
		{
			#if DEVELOPER
				printt( "CREATING 002 for", player )
			#endif

			Gamemode1v1_NotifyPlayer( player, eNotify.CHALLENGE, "#FS_CHALLENGE_STARTED" )
			HasChalText = true
			wait 2

			if ( !IsValid( player ) )
				break

			iStatusText = 2
		}

		if ( !Gamemode1v1_IsPlayerWaiting( player ) )
		{
			if( iStatusText != 3 )
			{
				#if DEVELOPER
					printt( "CREATING 003 for", player )
				#endif

				Gamemode1v1_NotifyPlayer( player, eNotify.CHALLENGE, "#FS_JOIN_QUEUE" )
				iStatusText = 3
			}

			wait 1
			continue
		}

		entity challenged = player.p.entLastChallenger
		if( !IsValid ( challenged ) )
		{
			#if DEVELOPER
				Warning( "Invalid challenger. DEBUG IT" )
			#endif

			continue //do something
		}
		else
		{
			if( !Gamemode1v1_IsPlayerWaiting( challenged ) )
			{
				wait 1

				if( !IsValid( player ) )
					break

				if( iStatusText != 4 )
				{
					#if DEVELOPER
						printt( "CREATING 004 for", player )
					#endif

					Gamemode1v1_NotifyPlayer( player, eNotify.CHALLENGE, "#FS_CHALLENGE_WAITING_FOR", challenged.p.name )
					iStatusText = 4
				}
			}
		}
	}
}


//═══════════════════════════════════════════════════════════════════════════════
//
// resetChallenges (from Section 18)
//
//═══════════════════════════════════════════════════════════════════════════════

void function resetChallenges()
{
	foreach ( chalStruct in file.allChallenges )
	{
		if( isChalValid( chalStruct ) )
			chalStruct.challengers.clear()
	}

	file.acceptedChallenges.clear()
}
