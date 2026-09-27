// Flowstate 1v1. CafeFPS (makimakima, mkos).

global function getSbmmSetting
global function setSbmmSetting
global function TriggerMatchmaking
global function FS_1v1_SweepStaleMatchmakingState
global function FS_1v1_SampleQueueLatency
global function FS_1v1_ReleaseChallengeSide
global function Fetch_IBMM_Timeout_For_Player
global function Init_IBMM
global function ResetIBMM
global function FS_1v1_RefreshQueueGrace
global function FS_1v1_RearmQueueForRound
global function StartIBMMGracePeriodTimer
global function StartVictimPenaltyTimer
global function StartWaitingTimeoutTimer
global function UpdateRestingNotifications
global function FS_1v1_RequestRestingNotificationRefresh

//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 7: MATCHMAKING SYSTEM
// Complete matchmaking logic and execution
//
//═══════════════════════════════════════════════════════════════════════════════

// GetLatency is a native and the pairing scan is quadratic -- sample once per pass, not per pair.
void function FS_1v1_SampleQueueLatency()
{
	foreach ( playerHandle, playerWaiting in file.waitingQueue )
	{
		if ( !IsValid( playerWaiting.player ) )
			continue

		playerWaiting.latencyMs = int( playerWaiting.player.GetLatency() * 1000 )
	}
}

void function ExecuteMatchmaking()
{
	//////////////////////////////////////
	// CONDITIONS THAT STOP MATCHMAKING //
	//////////////////////////////////////
	if( GetScoreboardShowingState() || GetChampionShowingState() || GetTDMState() != eTDMState.IN_PROGRESS )
	{
		printt( format( "[FS-1V1][MM] execute skipped: scoreboard=%d champion=%d tdmState=%d waiting=%d",
			GetScoreboardShowingState() ? 1 : 0, GetChampionShowingState() ? 1 : 0,
			GetTDMState(), file.waitingQueue.len() ) )
		return
	}

	printt( format( "[FS-1V1][MM] execute: waiting=%d", file.waitingQueue.len() ) )

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[MATCHMAKING DEBUG] Executing matchmaking (waiting: %d)", file.waitingQueue.len()) )
	#endif

	FS_1v1_SweepStaleMatchmakingState()

	if ( isScenariosMode() )
	{
		FS_Scenarios_FormGroups()
		return
	}

	FS_1v1_SampleQueueLatency()

	// Pairs that cannot be created are excluded for the rest of this pass rather than
	// ending it. The pairer always picks the same candidate first, so letting one bad
	// pair stop the loop starves every other player in the queue behind it.
	table<int, bool> unpairable = {}

	while( file.waitingQueue.len() >= 2 )
	{
		int pairResult = TryCreateOneMatch( unpairable )

		if( pairResult == FS_1V1_PAIR_NONE )
			break

		// Coaching pairs on the admin's start, so retrying would re-enter that wait.
		if( pairResult == FS_1V1_PAIR_FAILED && bIsCoachingMode() )
			break

		// Small delay between match creations to prevent overwhelming the system
		WaitFrame()
	}
}

void function FS_1v1_CoachingModeMatchmakingStart()
{
	//Coaching mode, we should wait until admin decides to start
	//Open menu with recordings list, wait until amdin presses "start new"

	foreach ( player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		if( !player.p.playerisready )
		{
			Message_New( player, "Welcome to District's 1v1 Faceoff\n\n Waiting For Admin To Start", 300 )

			player.p.playerisready = true

			Remote_CallFunction_NonReplay(player, "Flowstate_OpenCoachingMenu")
		}
	}

	while( !GetStartNewGameBool() && GetPlayerArray_Alive().len() == 2)
		WaitFrame()

	SetStartNewGameBool( false )
}

entity function GetNewRandomOpponentForPlayer_1v1( entity player, table<int, bool> unpairable )
{
    entity p

    if ( !IsValid( player ) )
		return p

    array<entity> eligible = []
    foreach ( playerHandle, playerWaiting in file.waitingQueue )
    {
		if( !IsValidPlayer( playerWaiting.player ) )
			continue

		if( playerHandle in unpairable )
			continue

		// still dying, skip for MM until penalty expires
		if (playerWaiting.victimPenaltyExpire > Time())
			continue

        if ( IsValid( playerWaiting.player ) && player != playerWaiting.player && !playerWaiting.player.p.waitingFor1v1 )
		{
			if( IsPlayerPendingChallenge( playerWaiting.player ) || IsPlayerPendingLockOpponent( playerWaiting.player ) )
				continue

			// Timeout does not end anyone else's input grace. K/D stays unchecked here -- wait timeout escapes SBMM, not the input filter.
			if( !bIsCoachingMode() && player.p.input != playerWaiting.player.p.input && !playerWaiting.ibmmTimeoutReached )
				continue

            if ( playerWaiting.player.GetLatency() * 1000 < player.p.max_enemy_ping && player.GetLatency() * 1000 < playerWaiting.player.p.max_enemy_ping )
                eligible.append(playerWaiting.player)
		}
    }

	int count = eligible.len()
	if( count > 0 )
	{
		entity foundOpponent = eligible[ RandomIntRangeInclusive( 0, count - 1 ) ]

		if( IsValid( foundOpponent ) )
			return foundOpponent
	}

	return p
}

void function MatchmakingWorker()
{
	// Ensure matchmakingPending is always cleared, even if thread dies
	OnThreadEnd(
		function() : ()
		{
			file.matchmakingPending = false
			#if DEVELOPER
				if ( file.DEBUG_MATCHMAKING )
					printw( "[MATCHMAKING DEBUG] Worker thread ending - matchmakingPending cleared" )
			#endif
		}
	)

	// Debounce: Wait for cooldown period to prevent excessive CPU usage
	float timeSinceLastRun = Time() - file.lastMatchmakingTime

	if ( timeSinceLastRun < file.MATCHMAKING_COOLDOWN )
	{
		float waitTime = file.MATCHMAKING_COOLDOWN - timeSinceLastRun
		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
				printw( format("[MATCHMAKING DEBUG] Worker waiting %.2fs for cooldown", waitTime) )
		#endif
		wait waitTime
	}

	// ExecuteMatchmaking returns without pairing while the round is not ready. Hold here (bounded) so the trigger is not lost.
	float gateDeadline = Time() + 30.0
	bool gateReported = false
	while ( ( GetScoreboardShowingState() || GetChampionShowingState() || GetTDMState() != eTDMState.IN_PROGRESS ) && Time() < gateDeadline )
	{
		// matchmakingPending stays true for the whole hold, so later triggers are dropped rather than lost.
		if ( !gateReported )
		{
			gateReported = true
			printt( format( "[FS-1V1][MM] worker holding: scoreboard=%d champion=%d tdmState=%d waiting=%d",
				GetScoreboardShowingState() ? 1 : 0, GetChampionShowingState() ? 1 : 0,
				GetTDMState(), file.waitingQueue.len() ) )
		}
		WaitFrame()
	}

	if ( gateReported )
		printt( format( "[FS-1V1][MM] worker released after %.1fs (tdmState=%d)",
			30.0 - ( gateDeadline - Time() ), GetTDMState() ) )

	// Hold pairing until the round intro countdown finishes. Read after the gate:
	// the round that just opened publishes its own intro end time.
	float introEnd = GetGlobalNetTime( "FSDM_RoundIntroEndTime" )
	if ( introEnd > Time() )
		wait introEnd - Time()

	file.lastMatchmakingTime = Time()

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[MATCHMAKING DEBUG] Worker executing matchmaking (waiting players: %d)", file.waitingQueue.len()) )
	#endif

	// Run Execute inline so matchmakingPending stays true until pairing finishes.
	// threading Execute cleared pending in OnThreadEnd while the pairer still ran.
	ExecuteMatchmaking()
}

// Event-driven matchmaking with throttling
// Instead of running matchmaking every frame (60 Hz), we trigger it only when needed
// and throttle to max 2 Hz (every 0.5 seconds)
void function TriggerMatchmaking()
{
	// If matchmaking is already pending, don't schedule another one
	if ( file.matchmakingPending )
	{
		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
				if ( file.DEBUG_MATCHMAKING )
					printw( "[MATCHMAKING DEBUG] TriggerMatchmaking called but already pending - skipping" )
		#endif
		return
	}

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[MATCHMAKING DEBUG] TriggerMatchmaking called - spawning worker (waiting: %d)", file.waitingQueue.len()) )
	#endif

	file.matchmakingPending = true
	thread MatchmakingWorker()
}

// Helper function to attempt creating one match from waiting pool
// Returns true if match was created, false if no match could be made
int function TryCreateOneMatch( table<int, bool> unpairable )
{
	if( bIsCoachingMode() )
	{
		FS_1v1_CoachingModeMatchmakingStart()

		//check if there are still two players, if not, return false
		if( GetPlayerArray_Alive().len() < 2 )
		{
			foreach ( player in GetPlayerArray() )
			{
				if ( !IsValid( player ) )
					continue

				player.p.playerisready = false
			}
			return FS_1V1_PAIR_NONE
		}

		//NEW COACHING 1V1 GAME HAS STARTED, INMINENT..
		//close menu

		foreach ( player in GetPlayerArray() )
		{
			if ( !IsValid( player ) )
				continue

			Remote_CallFunction_NonReplay(player, "Flowstate_CloseCoachingMenu")
			Message_New( player, "STARTING RECORDED 1V1 MATCH", 3 )
			player.p.playerisready = false
		}

		wait 3
	}

	MatchGroup newGroup
	bool bMatchFound = false

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
		{
			printw( format("[MATCHMAKING DEBUG] Starting matchmaking iteration with %d waiting players", file.waitingQueue.len()) )
			foreach ( handle, playerStruct in file.waitingQueue )
			{
				if ( IsValid( playerStruct.player ) )
					printw( format("  - %s (handle: %d, kd: %.2f)", playerStruct.player.GetPlayerName(), handle, playerStruct.kd) )
			}
		}
	#endif

	///////////////////////////////////
	// CREATE MATCHES VIA CHALLENGES //
	///////////////////////////////////
	foreach ( playerHandle, playerWaiting in file.waitingQueue )
	{
		if( !IsValid( playerWaiting ) )
			continue

		entity playerSelf = playerWaiting.player
		if( !IsValid( playerSelf ) )
			continue

		if( playerHandle in unpairable )
			continue

		if( !bIsCoachingMode() && IsPlayerPendingChallenge( playerSelf ) )
		{
			entity Lock1v1Opponent = getLock1v1OpponentOfPlayer( playerSelf )
			if ( IsValid( Lock1v1Opponent ) )
			{
				newGroup.player1 = playerSelf
				newGroup.player2 = Lock1v1Opponent

				#if DEVELOPER
				printw( "MATCH CREATED VIA CHALLENGE" )
				#endif

				newGroup.IsKeep = true
				bMatchFound = true
				break
			}
			else
			{
				#if DEVELOPER
					sqprint( "waiting for lockmatch TIMEOUT matching" )
				#endif

				continue //(mk): these guys are still waiting for each other
			}
		}
	}

	/////////////////
	// IBMM / SBMM //
	/////////////////
	entity opponent

	if( !bMatchFound && getTimeOutPlayerAmount() > 0 ) //MATCHING VIA PLAYER IS TIMED OUT AND NEEDS AN ENEMY RIGHT NOW
	{
		entity timedOutPlayer = getTimeOutPlayer()
		if( IsValid( timedOutPlayer ) && !( timedOutPlayer.p.handle in unpairable ) )
		{
			opponent = GetNewRandomOpponentForPlayer_1v1( timedOutPlayer, unpairable )

			if( IsValid( opponent ) )
			{
				ClearNotifications( timedOutPlayer, eNotify.MATCHING )
				newGroup.player1 = timedOutPlayer
				newGroup.player2 = opponent

				#if DEVELOPER
					if ( file.DEBUG_MATCHMAKING )
						printw( "MATCH CREATED VIA PLAYER TIMED OUT (RANDOM ENEMY)", getTimeOutPlayerAmount(), "TIMED OUT PLAYER:", timedOutPlayer.GetPlayerName() )
				#endif
				bMatchFound = true
			}
			else
			{
				Gamemode1v1_NotifyPlayerOnce( timedOutPlayer, eNotify.MATCHING, "#FS_MATCHING_FOR", FetchInputName( timedOutPlayer ) )
			}
		}
	}

	if ( !bMatchFound ) //MATCHING VIA KD
	{
		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
			printw( "[MATCHMAKING DEBUG] Starting SBMM matching logic" )
		#endif

		foreach ( playerHandle, playerWaiting in file.waitingQueue )
		{
			if( !IsValid( playerWaiting ) )
				continue

			entity playerSelf = playerWaiting.player
			if( !IsValid( playerSelf ) )
				continue

			if( playerHandle in unpairable )
				continue

			// Challenge path owns lock pairs; do not SBMM-pair a pending lock player.
			if( IsPlayerPendingChallenge( playerSelf ) || IsPlayerPendingLockOpponent( playerSelf ) )
				continue

			// still dying, skip for MM until penalty expires
			if (playerWaiting.victimPenaltyExpire > Time())
			{
				#if DEVELOPER
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG] Skipping %s - victim penalty not expired (%.2fs remaining)", playerSelf.GetPlayerName(), playerWaiting.victimPenaltyExpire - Time()) )
				#endif
				continue
			}

			float selfKd = playerWaiting.kd
			table <entity,float> properOpponentTable

			#if DEVELOPER
				if ( file.DEBUG_MATCHMAKING )
				printw( format("[MATCHMAKING DEBUG] Evaluating %s as player1 candidate (kd: %.2f)", playerSelf.GetPlayerName(), selfKd) )
			#endif

			foreach ( opponentHandle, eachOpponentPlayerStruct in file.waitingQueue )
			{
				entity eachOpponent = eachOpponentPlayerStruct.player
				float opponentKd = eachOpponentPlayerStruct.kd

				//(mk): this makes sure we don't compare same player as opponent during matchmaking
				if( !IsValid( eachOpponent ) || playerSelf == eachOpponent )
					continue

				if( opponentHandle in unpairable )
					continue

				if( IsPlayerPendingChallenge( eachOpponent ) || IsPlayerPendingLockOpponent( eachOpponent ) )
				{
					//sqprint("waiting for lockmatch main matching")
					continue //these guys are trying to lock with each other
				}

				if ( eachOpponentPlayerStruct.latencyMs > playerSelf.p.max_enemy_ping )
				{
					#if DEVELOPER
						if ( file.DEBUG_MATCHMAKING )
						printw( format("[MATCHMAKING DEBUG]   Rejecting %s - ping too high (%d > %d)", eachOpponent.GetPlayerName(), eachOpponentPlayerStruct.latencyMs, playerSelf.p.max_enemy_ping) )
					#endif
					continue
				}

				if ( playerWaiting.latencyMs > eachOpponent.p.max_enemy_ping )
				{
					#if DEVELOPER
						if ( file.DEBUG_MATCHMAKING )
						printw( format("[MATCHMAKING DEBUG]   Rejecting %s - our ping too high (%d > %d)", eachOpponent.GetPlayerName(), playerWaiting.latencyMs, eachOpponent.p.max_enemy_ping) )
					#endif
					continue
				}

				// still dying, skip for MM until penalty expires
				if (eachOpponentPlayerStruct.victimPenaltyExpire > Time())
				{
					#if DEVELOPER
						if ( file.DEBUG_MATCHMAKING )
						printw( format("[MATCHMAKING DEBUG]   Rejecting %s - victim penalty", eachOpponent.GetPlayerName()) )
					#endif
					continue
				}

				if( !bIsCoachingMode() && fabs(selfKd - opponentKd) > file.SBMM_kd_difference )
				{
					#if DEVELOPER
						if ( file.DEBUG_MATCHMAKING )
						printw( format("[MATCHMAKING DEBUG]   Rejecting %s - K/D difference too large (%.2f vs %.2f, max diff: %.2f)", eachOpponent.GetPlayerName(), selfKd, opponentKd, file.SBMM_kd_difference) )
					#endif
					continue
				}

				// FIX ISSUE 1: Check IBMM BEFORE adding to candidate table
				// This prevents cross-input opponents from entering the pool during grace period
				//(mk): keep building a list of candidates who are not timed out with same input
				if( !bIsCoachingMode() && playerSelf.p.input != eachOpponent.p.input && ( playerWaiting.ibmmTimeoutReached == false || eachOpponentPlayerStruct.ibmmTimeoutReached == false ) )
				{
					#if DEVELOPER
						if ( file.DEBUG_MATCHMAKING )
						printw( format("[MATCHMAKING DEBUG]   Rejecting %s - input mismatch and IBMM not timed out (player input: %d, opp input: %d, player timeout: %d, opp timeout: %d)", eachOpponent.GetPlayerName(), playerSelf.p.input, eachOpponent.p.input, playerWaiting.ibmmTimeoutReached ? 1 : 0, eachOpponentPlayerStruct.ibmmTimeoutReached ? 1 : 0) )
					#endif
					continue
				}

				#if DEVELOPER
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]   Adding %s to properOpponentTable (K/D diff: %.2f)", eachOpponent.GetPlayerName(), fabs(selfKd - opponentKd)) )
				#endif

				properOpponentTable[ eachOpponent ] <- fabs( selfKd - opponentKd )
			}

			float lowestKd = 999
			entity bestOpponent
			entity secondBestOpponent

			#if DEVELOPER
				if ( file.DEBUG_MATCHMAKING )
				printw( format("[MATCHMAKING DEBUG]   properOpponentTable has %d candidates", properOpponentTable.len()) )
			#endif

			foreach (properOpponent,kd in properOpponentTable)
			{
				if( bIsCoachingMode() )
				{
					bestOpponent = properOpponent
					break
				}

				if(kd < lowestKd)
				{
					if( IsValid( bestOpponent ) )
						secondBestOpponent = bestOpponent
					bestOpponent = properOpponent
					lowestKd = kd
				}
			}

			entity lastOpponent = playerWaiting.lastOpponent

			#if DEVELOPER
				if ( IsValid(bestOpponent) )
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]   bestOpponent: %s (K/D diff: %.2f)", bestOpponent.GetPlayerName(), lowestKd) )
				else
					if ( file.DEBUG_MATCHMAKING )
			printw( "[MATCHMAKING DEBUG]   No bestOpponent found - continuing to next player" )
			#endif

			if(!IsValid(bestOpponent))
				continue

			if( bIsCoachingMode() )
			{
				newGroup.player1 = playerSelf
				newGroup.player2 = bestOpponent
				break
			}
			// Grace only ever gates CROSS-input pairing, which is what the
			// candidate filter above already enforces: same input pairs here
			// whatever either side's timeout says.
			else if( bestOpponent != lastOpponent && ( playerSelf.p.input == bestOpponent.p.input || ( Fetch_IBMM_Timeout_For_Player( playerSelf ) && Fetch_IBMM_Timeout_For_Player( bestOpponent ) ) ) )
			{
					#if DEVELOPER
						if ( file.DEBUG_MATCHMAKING )
						printw( format("[MATCHMAKING DEBUG]   Match condition MET! Creating match: %s vs %s", playerSelf.GetPlayerName(), bestOpponent.GetPlayerName()) )
					#endif

					bool inputresult = playerSelf.p.input == bestOpponent.p.input ? true : false

					//sqprint(format("Player found: ibmm timeout: %s, INputs are same?: ", Fetch_IBMM_Timeout_For_Player(bestOpponent), inputresult  ));
					// Warning("Best opponent, kd gap: " + lowestKd)
					newGroup.player1 = playerSelf
					newGroup.player2 = bestOpponent

					break
			}
			else if( IsValid( secondBestOpponent ) && secondBestOpponent != lastOpponent && ( playerSelf.p.input == secondBestOpponent.p.input || ( Fetch_IBMM_Timeout_For_Player( playerSelf ) && Fetch_IBMM_Timeout_For_Player( secondBestOpponent ) ) ) )
			{
					//sqprint(format("Player found: ibmm timeout: %s, INputs are same?: ", Fetch_IBMM_Timeout_For_Player(secondBestOpponent), inputresult  ));

					// Warning("Secondary opponent, kd gap: " + lowestKd)
					newGroup.player1 = playerSelf
					newGroup.player2 = secondBestOpponent

					break
			}
			else
			{
				#if DEVELOPER
					bool playerTimeout = Fetch_IBMM_Timeout_For_Player( playerSelf )
					bool oppTimeout = Fetch_IBMM_Timeout_For_Player( bestOpponent )
					bool sameInput = playerSelf.p.input == bestOpponent.p.input
					bool isLastOpp = bestOpponent == lastOpponent

					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]   Match condition FAILED for %s vs %s:", playerSelf.GetPlayerName(), bestOpponent.GetPlayerName()) )
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]     - Is last opponent: %d", isLastOpp ? 1 : 0) )
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]     - Player IBMM timeout: %d", playerTimeout ? 1 : 0) )
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]     - Opponent IBMM timeout: %d", oppTimeout ? 1 : 0) )
					if ( file.DEBUG_MATCHMAKING )
					printw( format("[MATCHMAKING DEBUG]     - Same input: %d (player: %d, opp: %d)", sameInput ? 1 : 0, playerSelf.p.input, bestOpponent.p.input) )
				#endif
				// Warning("Only last opponent found, waiting for time out")
				continue
			}
		}
	}

	if( !IsValid( newGroup.player1 ) || !IsValid( newGroup.player2 ) )
	{
		// No realm was claimed yet -- _CreateMatchFromPair claims it, and releases it
		// itself on every failure past that point.
		if ( IsValid( newGroup.player1 ) )
			Gamemode1v1_AddPlayerToQueue( newGroup.player1 )

		if ( IsValid( newGroup.player2 ) )
			Gamemode1v1_AddPlayerToQueue( newGroup.player2 )

		return FS_1V1_PAIR_NONE  // Nothing left in the queue can be paired this pass
	}

	////////////////////////////
	// ACTUAL GROUPS CREATION //
	////////////////////////////
	// Challenge lock may still have waitingFor1v1 set; consume the lock only after create.
	bool chalLock = newGroup.IsKeep
	if( chalLock || ( !newGroup.player1.p.waitingFor1v1 && !newGroup.player2.p.waitingFor1v1 ) )
	{
		//already matched two players
		array<entity> players = [newGroup.player1,newGroup.player2]

		//set handles to group for cleanup on invalid player
		newGroup.player1_handle = newGroup.player1.p.handle
		newGroup.player2_handle = newGroup.player2.p.handle

		if( GroupIsLockable( newGroup ) )
			newGroup.inputLocked = true
		else
			newGroup.inputLocked = false

		if( !_CreateMatchFromPair( newGroup ) )
			return FS_1v1_MarkPairUnpairable( unpairable, newGroup, "match creation failed" )

		if ( chalLock )
			Gamemode1v1_OnChallengeMatchCreated( newGroup )

		// Signal both players to cancel any pending penalty timers
		newGroup.player1.Signal( "MatchFound" )
		newGroup.player2.Signal( "MatchFound" )

		foreach ( index, eachPlayer in players )
		{
			LocalEventMsg( eachPlayer, "", "", 1 ) //reset in queue msg
			EnableOffhandWeapons( eachPlayer )
			thread Gamemode1v1_RespawnForMatch( eachPlayer, index )
		}

		// Isolate immediately so teleport/setup never shares all-realms with outsiders
		FS_SetRealmForPlayer( newGroup.player1, newGroup.slotIndex )
		FS_SetRealmForPlayer( newGroup.player2, newGroup.slotIndex )

		// Weapons, IBMM notifications, and input watchdog are initialized after match found delay
		GiveWeaponsToGroup( players, newGroup )

			return FS_1V1_PAIR_CREATED
	} //not waiting

	return FS_1v1_MarkPairUnpairable( unpairable, newGroup, "still locked to a challenge" )
}

// Excludes a selected-but-uncreatable pair from the rest of this pass. Both stay
// queued, so the next pass reconsiders them from scratch.
int function FS_1v1_MarkPairUnpairable( table<int, bool> unpairable, MatchGroup newGroup, string reason )
{
	int excluded = 0

	foreach ( entity pairSide in [ newGroup.player1, newGroup.player2 ] )
	{
		if ( !IsValid( pairSide ) )
			continue

		unpairable[ pairSide.p.handle ] <- true
		excluded++
		Warning( "[FS-1V1][MM-SKIP] " + pairSide.GetPlayerName() + " skipped this pass -- " + reason )
	}

	// Excluding nobody would leave the pass picking this same pair forever.
	if ( excluded == 0 )
		return FS_1V1_PAIR_NONE

	return FS_1V1_PAIR_FAILED
}

void function FS_1v1_ReleaseChallengeSide( entity player )
{
	if ( !IsValid( player ) )
		return

	player.p.waitingFor1v1 = false
	ClearNotifications( player, eNotify.CHALLENGE )
	player.Signal( "ChallengeEnded" )
}

// Sweep gone players, half-dead challenge locks, and waitingFor1v1 with no lock -- each starves pairing.
void function FS_1v1_SweepStaleMatchmakingState()
{
	array<int> deadQueued

	foreach ( playerHandle, playerWaiting in file.waitingQueue )
	{
		if ( !IsValid( playerWaiting.player ) )
			deadQueued.append( playerHandle )
	}

	foreach ( int deadHandle in deadQueued )
	{
		delete file.waitingQueue[ deadHandle ]
		Warning( "[FS-1V1][MM-HEAL] dropped queue entry of gone player handle=" + string( deadHandle ) )
	}

	array<int> deadLocks

	foreach ( challengedHandle, challenger in file.acceptedChallenges )
	{
		if ( IsValid( challenger ) && IsValid( GetEntityFromEncodedEHandle( challengedHandle ) ) )
			continue

		deadLocks.append( challengedHandle )
	}

	foreach ( int deadHandle in deadLocks )
	{
		entity challenger = file.acceptedChallenges[ deadHandle ]
		entity challenged = GetEntityFromEncodedEHandle( deadHandle )
		delete file.acceptedChallenges[ deadHandle ]

		FS_1v1_ReleaseChallengeSide( challenger )
		FS_1v1_ReleaseChallengeSide( challenged )

		Warning( "[FS-1V1][MM-HEAL] purged half-dead challenge lock handle=" + string( deadHandle ) )
	}

	foreach ( playerHandle, playerWaiting in file.waitingQueue )
	{
		entity queuedPlayer = playerWaiting.player

		if ( !queuedPlayer.p.waitingFor1v1 )
			continue

		if ( IsPlayerPendingChallenge( queuedPlayer ) || IsPlayerPendingLockOpponent( queuedPlayer ) )
			continue

		queuedPlayer.p.waitingFor1v1 = false
		ClearNotifications( queuedPlayer, eNotify.CHALLENGE )
		Warning( "[FS-1V1][MM-HEAL] cleared orphan challenge flag on " + queuedPlayer.GetPlayerName() )
	}
}

// Coalesce RESTING panel refreshes to one per frame -- a refresh is a reliable remote per character of the count text.
void function FS_1v1_RequestRestingNotificationRefresh()
{
	if ( file.restingNotifyPending )
		return

	file.restingNotifyPending = true
	thread FS_1v1_RestingNotificationRefresh_THREAD()
}

void function FS_1v1_RestingNotificationRefresh_THREAD()
{
	WaitFrame()
	file.restingNotifyPending = false
	UpdateRestingNotifications()
}

void function UpdateRestingNotifications()
{
	int restingCount = 0
	int spectatingCount = 0

	array<entity> allPlayers = GetPlayerArray()

	foreach ( player in allPlayers )
	{
		if ( !IsValid( player ) )
			continue

		int state = Gamemode1v1_GetPlayerGamestate( player )
		if ( state == e1v1State.RESTING )
			restingCount++
		else if ( state == e1v1State.SPECTATING )
			spectatingCount++
	}

	string countText = format( "%d resting, %d spectating", restingCount, spectatingCount )

	foreach ( player in allPlayers )
	{
		if ( !FS_1v1_PlayerHasClient( player ) )
			continue

		int state = Gamemode1v1_GetPlayerGamestate( player )
		if ( state == e1v1State.RESTING )
		{
			DirectClearPanel( player, eNotify.RESTING )
			DirectShowPanel( player, eNotify.RESTING, "#FS_RESTING_PANEL", countText )
		}
	}
}


//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 8: IBMM/SBMM SYSTEM
// Input-based and skill-based matchmaking
//
//═══════════════════════════════════════════════════════════════════════════════

//used for display
string function FetchInputName( entity player )
{
	return player.p.input == 0 ? "MnK" : "Controller";
}

bool function Fetch_IBMM_Timeout_For_Player( entity player )
{
    if ( !IsValid( player ) )
		return false

    if ( player.p.handle in file.waitingQueue )
        return file.waitingQueue[ player.p.handle ].ibmmTimeoutReached

    return false
}

void function Init_IBMM( entity player )
{
	// A bot has no input device and the detector never runs for it, so it must
	// be stamped here: every HUD already reads a bot as controller, and the
	// matchmaker has to agree or the input filter inverts for bots.
	player.p.input = player.IsBot() ? 1 : 0
	FS_1v1_PublishInputState( player )

	if( FS_IsScenarios() )
		return

	if( FS_1v1_PlayerHasClient( player ) )
	{
		StartInputDetectorForPlayer( player )
		thread NotificationThread( player )
	}

	// if( player.p.IBMM_grace_period == -1 )
		// SetDefaultIBMM( player )
}

void function ResetIBMM( entity player )
{
    if ( !IsValid( player ) )
		return

	int handle = player.p.handle
	// Only the grace timer ever sets this, so a player with no grace at all --
	// a bot, or a 0 wait time -- must start already past it.
    if ( handle in file.waitingQueue )
        file.waitingQueue[ handle ].ibmmTimeoutReached = player.p.IBMM_grace_period <= 0
	#if DEVELOPER
	else
		printw( "player was not in waiting list:", player )
	#endif
}

// Arms both queue deadlines from one place: the input grace, and the wait
// timeout that lets a player match anyone. elapsed is time already served on
// this queue entry. Callers must Signal "FS_1v1_GraceChanged" first so the
// previous pair of timers dies instead of firing on its old deadline.
void function FS_1v1_ArmQueueTimers( entity player, float elapsed )
{
	int handle = player.p.handle
	if ( !( handle in file.waitingQueue ) )
		return

	float dur = player.p.IBMM_grace_period
	float remaining = dur - elapsed
	bool graceOver = dur <= 0 || remaining <= 0

	file.waitingQueue[ handle ].ibmmTimeoutReached = graceOver

	if ( graceOver )
	{
		remaining = 0.0
		player.SetPlayerNetTime( "FS_1v1_QueueGraceEnd", dur <= 0 ? -1.0 : 0.0 )
	}
	else
	{
		player.SetPlayerNetTime( "FS_1v1_QueueGraceEnd", Time() + remaining )
		player.SetPlayerNetFloat( "FS_1v1_QueueGraceDur", dur )
		thread StartIBMMGracePeriodTimer( player, remaining )
	}

	float penaltyExpire = file.waitingQueue[ handle ].victimPenaltyExpire
	float base = penaltyExpire > Time() ? penaltyExpire : Time()
	file.waitingQueue[ handle ].waitingTime = base + QUEUE_TIMEOUT_EXTRA + remaining
	file.waitingQueue[ handle ].IsTimeOut = false
	thread StartWaitingTimeoutTimer( player, file.waitingQueue[ handle ].waitingTime - Time() )
}

// Wait-time setting changed while the player sits in the queue. The new value
// starts now: charging it the time already served expires a longer wait the
// instant it is set, and the countdown bar never appears.
void function FS_1v1_RefreshQueueGrace( entity player )
{
	if ( !IsValid( player ) )
		return

	int handle = player.p.handle
	if ( !( handle in file.waitingQueue ) )
		return

	Signal( player, "FS_1v1_GraceChanged" )
	file.waitingQueue[ handle ].queue_time = Time()
	FS_1v1_ArmQueueTimers( player, 0.0 )

	if ( file.waitingQueue[ handle ].ibmmTimeoutReached )
		thread TriggerMatchmaking()
}

// Both queue deadlines burn through the whole round transition -- champion
// screen, mandatory leaderboard, round intro -- while nothing can be paired,
// so a player queued at round end reached live matchmaking already past both.
// Restart everyone from zero the moment pairing actually opens.
void function FS_1v1_RearmQueueForRound()
{
	// Signal ends threads at the call, so take the list first rather than
	// mutating the table under its own iterator.
	array<entity> queuedPlayers
	foreach ( handle, queued in file.waitingQueue )
	{
		if ( IsValid( queued.player ) )
			queuedPlayers.append( queued.player )
	}

	foreach ( entity player in queuedPlayers )
	{
		Signal( player, "FS_1v1_GraceChanged" )

		int handle = player.p.handle
		if ( !( handle in file.waitingQueue ) )
			continue

		file.waitingQueue[ handle ].queue_time = Time()
		FS_1v1_ArmQueueTimers( player, 0.0 )
	}
}

//usage intended for display only queries from scripts, not game logic
float function getSbmmSetting( string setting )
{
	switch(setting)
	{
		case "season_kd_weight":
			return file.season_kd_weight
		case "current_kd_weight":
			return file.current_kd_weight
		case "SBMM_kd_difference":
			return file.SBMM_kd_difference

		default:
			return 0.0
	}

	unreachable
}

bool function setSbmmSetting( string setting, float value )
{
	switch( setting )
	{
		case "season_kd_weight":
			file.season_kd_weight = value
			return true

		case "current_kd_weight":
			file.current_kd_weight = value
			return true

		case "SBMM_kd_difference":
			file.SBMM_kd_difference = value
			return true

		default:
			return false
	}

	unreachable
}


//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 9: TIMER FUNCTIONS
// Penalty, grace period, and timeout timers
//
//═══════════════════════════════════════════════════════════════════════════════

// Timer that triggers matchmaking when IBMM grace period expires
// Allows players to match with different input devices after waiting
void function StartIBMMGracePeriodTimer( entity player, float gracePeriod )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MatchFound" )
	player.EndSignal( "FS_1v1_GraceChanged" )

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[TIMER DEBUG] Starting IBMM grace period timer for %s (%.2fs)", player.GetPlayerName(), gracePeriod) )
	#endif

	wait gracePeriod

	// Grace period expired - check if player is still waiting
	int handle = player.p.handle
	if ( handle in file.waitingQueue )
	{
		file.waitingQueue[handle].ibmmTimeoutReached = true

		if ( IsValid( player ) )
			player.SetPlayerNetTime( "FS_1v1_QueueGraceEnd", 0 )

		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
				printw( format("[TIMER DEBUG] IBMM grace period expired for %s - can now match with any input", player.GetPlayerName()) )
		#endif

		// Show notification that we're now matching with any input
		// Gamemode1v1_NotifyPlayerOnce( player, eNotify.MATCHING, "#FS_MATCHING_ANY" )

		// Trigger matchmaking to give this player another chance with relaxed IBMM
		thread TriggerMatchmaking()
	}
}

// Timer that triggers matchmaking when victim penalty expires
// Without this, players with penalties would never get matched after penalty expires
void function StartVictimPenaltyTimer( entity player, float penaltyDuration )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MatchFound" ) // Cancel if player gets matched somehow

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[TIMER DEBUG] Starting victim penalty timer for %s (%.2fs)", player.GetPlayerName(), penaltyDuration + 0.1) )
	#endif

	// Small buffer past expire so SBMM sees victimPenaltyExpire <= Time()
	wait penaltyDuration + 0.05

	// Penalty expired - check if player is still waiting
	int handle = player.p.handle
	if ( handle in file.waitingQueue )
	{
		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
				printw( format("[TIMER DEBUG] Victim penalty expired for %s - triggering matchmaking", player.GetPlayerName()) )
		#endif

		// Trigger matchmaking to give this player another chance
		thread TriggerMatchmaking()
	}
}

// Timer that triggers matchmaking when waiting timeout expires
// Allows players to match with anyone (ignores SBMM/IBMM) after long wait
void function StartWaitingTimeoutTimer( entity player, float waitingTime )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MatchFound" )
	player.EndSignal( "FS_1v1_GraceChanged" )

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[TIMER DEBUG] Starting waiting timeout timer for %s (%.2fs)", player.GetPlayerName(), waitingTime) )
	#endif

	wait waitingTime

	// Waiting timeout reached - check if player is still waiting
	int handle = player.p.handle
	if ( handle in file.waitingQueue )
	{
		file.waitingQueue[handle].IsTimeOut = true

		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
				printw( format("[TIMER DEBUG] Waiting timeout reached for %s - can now match with anyone", player.GetPlayerName()) )
		#endif

		// Trigger matchmaking - player can now match with anyone
		thread TriggerMatchmaking()
	}
}
