// Flowstate 1v1. CafeFPS (makimakima, mkos).

global function ForceAllRoundsToFinish_solomode
global function Gamemode1v1_GetNextAvailableGroupID
global function Gamemode1v1_GetPlayerSoloGroup
global function Gamemode1v1_RecordMatchStats
global function FS_1v1_RecordForfeit
global function Gamemode1v1_RecordMatchHeadshot
global function Gamemode1v1_IsMatchValid
global function Gamemode1v1_RemovePlayerFromWaitingList
global function Gamemode1v1_RemovePlayerFromRestingList
global function HandleGroupIsFinished
global function RemovePlayerFromGroup
global function Gamemode1v1_ForceRest
global function Gamemode1v1_AddPlayerToQueue
global function Gamemode1v1_AddPlayerToQueueAfterDeath
global function FS_1v1_GetPlayersWaiting
global function FS_1v1_GetPlayersResting
global function _3v3ModePlayerToRestingList
global function Gamemode1v1_GetWaitingRoomLocation
global function Gamemode1v1_TeleportPlayer
global function FS_ClearRealmsAndAddPlayerToAllRealms
global function FS_SetRealmForPlayer
global function FS_GetEntityPrimaryRealm
global function Gamemode1v1_BroadcastObituary
global function Gamemode1v1_StartVsHudSync
global function SetIsUsedBoolForRealmSlot
global function Gamemode1v1_GetFreeRealmSlot
global function FS_1v1_CountFreeRealmSlots
global function FS_1v1_AuditRealmSlots
global function FS_1v1_TrackSpectatorRealm
global function FS_1v1_ForgetSpectatorRealm
global function FS_1v1_EvictSpectatorsFromRealm
global function PlayerRestoreHP_1v1
global function Gamemode1v1_ForcePilotRespawn
global function Gamemode1v1_RespawnForMatch
global function HandleChallengeMatchRespawn
global function HandlePlayerDisconnectedDuringMatch
global function StartWaitingRoomBoundaryMonitor
global function Gamemode1v1_AddPlayerToRest
global function GroupIsLockable
global function HandleOpponentInfo
global function InputWatchdog
global function SetShowWaitingMsg
global function ValidateSpawns
global function _CreateMatchFromPair
global function _SendMatchRecaps
global function FS1v1_RemoteStats_SubmitSession
global function FS1v1_RemoteStats_RecordWeaponDamage
global function FS1v1_RemoteStats_ResetWeapon
global function FS1v1_Elo_RecordKill
global function FS1v1_Elo_ResetLog
global function FS_1v1_ApplyLobbyLoadout
global function FS_1v1_LobbyHasGuns
global function FS_1v1_GatherPlayersToWaitingRoom
global function FS_1v1_EnqueueFromRecap

//===============================================================================
//
// HELPERS
//
//===============================================================================

// Returns the weighted K/D for matchmaking. Uses season stats + current session stats.
float function _CalculateWeightedKD( entity player )
{
	float season_kd = getkd( ( player.GetPlayerNetInt( "kills" ) + player.p.season_kills), ( player.GetPlayerNetInt( "deaths" ) + player.p.season_deaths ) )
	float current_kd = getkd( player.GetPlayerNetInt( "kills" ), player.GetPlayerNetInt( "deaths" ) )
	return ( ( season_kd * file.season_kd_weight ) + ( current_kd * file.current_kd_weight ) )
}

// S21 death path marks eliminated (IsPilotEliminationBased always true) then
// PostDeathThread stamps SPECTATOR_SETTINGS + ObserverThread. 1v1 always wants
// a pilot respawn into waiting/rest/match -- never BR spectator.
bool function Gamemode1v1_ForcePilotRespawn( entity player )
{
	if( !IsValid( player ) )
		return false

	if( IsAlive( player ) )
		return true

	ClearPlayerEliminated( player )
	player.Signal( "StopPostDeathLogic" )

	if( player.IsObserver() )
	{
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
	}

	bool ok = DecideRespawnPlayer( player, false )
	if( !ok )
		printt( "[FS-1V1] ForcePilotRespawn failed " + player.GetPlayerName() + " eliminated=" + string( IsPlayerEliminated( player ) ) )
	return ok
}

//===============================================================================
//
// SECTION 10: GROUP/MATCH MANAGEMENT
// Match group lifecycle management
//
//===============================================================================

void function ForceAllRoundsToFinish_solomode()
{
	// Full teardown first: free realms + drop match maps. Marking IsFinished alone
	// never ran event cleanup and leaked realmSlots until MM starved.
	array<int> matchHandles = []
	foreach ( groupHandle, group in file.activeMatches )
		matchHandles.append( groupHandle )

	foreach ( int groupHandle in matchHandles )
	{
		if ( !( groupHandle in file.activeMatches ) )
			continue

		MatchGroup group = file.activeMatches[ groupHandle ]
		group.IsFinished = true
		group.isValid = false

		if ( IsValid( group.player1 ) )
		{
			group.player1.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )
			group.player1.Signal( "GroupFinished" )
		}
		if ( IsValid( group.player2 ) )
		{
			group.player2.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )
			group.player2.Signal( "GroupFinished" )
		}

		destroyRingsForGroup( group )
		Gamemode1v1_RemoveMatch( group )
	}

	foreach( player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue

		if( TryProcessRestRequest( player ) )
			continue

		if( Gamemode1v1_IsPlayerResting( player ) )
			continue

		FS_1v1_ParkPlayerForRecap( player )
	}

	foreach( challengeStruct in file.allChallenges )
	{
		if( !isChalValid( challengeStruct ) )
			continue

		endLock1v1( challengeStruct.player, false )
	}

	if( GetCurrentRound() > 0 )
	{
		ClearAllNotifications()
	}
}

void function FS_1v1_ParkPlayerForRecap( entity player )
{
	if ( !IsValid( player ) )
		return

	// Stay in the current realm. Dumping everyone into realm 0 here makes every
	// snapshot carry every other player for the champion/scoreboard window.
	DirectClearAllPanels( player )
	player.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )

	if ( player.IsObserver() || player.p.isSpectating )
	{
		FS_1v1_ForgetSpectatorRealm( player )
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
		player.p.isSpectating = false
		RemoveButtonPressedPlayerInputCallback( player, IN_JUMP, endSpectate )
	}

	if ( !IsAlive( player ) )
		Gamemode1v1_ForcePilotRespawn( player )

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.RECAP )
	player.HolsterWeapon()
	player.FreezeControlsOnServer()
	player.ForceStand()
}

void function FS_1v1_GatherPlayersToWaitingRoom()
{
	array<entity> players = GetPlayerArray()
	int n = 0
	float t0 = Time()

	foreach ( entity player in players )
	{
		if ( !IsValid( player ) )
			continue
		if ( Gamemode1v1_IsPlayerResting( player ) )
			continue
		if ( Gamemode1v1_GetPlayerGamestate( player ) != e1v1State.RECAP )
			continue

		if ( !IsAlive( player ) )
			Gamemode1v1_ForcePilotRespawn( player )

		Gamemode1v1_TeleportPlayer( player, FS_1v1_PickWaitingRoomLoc() )
		FS_ClearRealmsAndAddPlayerToAllRealms( player )
		FS_1v1_ApplyLobbyLoadout( player )
		player.Show()
		player.UnfreezeControlsOnServer()
		player.UnforceStand()
		thread _LobbyStateSanitize( player )

		if ( FS_1v1_PlayerHasClient( player ) )
			ScreenFade( player, 0, 0, 0, 255, 0.2, 0.0, FFADE_IN | FFADE_PURGE )

		n++
		if ( n % 8 == 0 )
			WaitEndFrame()
	}

	printt( "[FS-1V1] gather-wr recap=" + string( n ) + " dt=" + string( Time() - t0 ) )
}

void function FS_1v1_EnqueueFromRecap( entity player )
{
	if ( !IsValid( player ) )
		return
	if ( Gamemode1v1_IsPlayerResting( player ) )
		return

	if ( Gamemode1v1_IsPlayerWaiting( player ) )
	{
		Gamemode1v1_SetPlayerGamestate( player, e1v1State.WAITING )
		return
	}

	if ( !IsAlive( player ) )
	{
		if ( !Gamemode1v1_ForcePilotRespawn( player ) || !IsAlive( player ) )
			return
	}

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.WAITING )

	QueuedPlayer playerStruct
	playerStruct.player = player
	playerStruct.handle = player.p.handle
	playerStruct.victimPenaltyExpire = Time()
	playerStruct.waitingTime = Time() + QUEUE_TIMEOUT_EXTRA
	if ( player.p.IBMM_grace_period > 0 )
		playerStruct.waitingTime += player.p.IBMM_grace_period
	playerStruct.kd = _CalculateWeightedKD( player )
	if ( IsValid( player.p.lastOpponent ) )
		playerStruct.lastOpponent = player.p.lastOpponent
	else
		playerStruct.lastOpponent = player.p.lastKiller
	playerStruct.queue_time = Time()

	Gamemode1v1_RemovePlayerFromRestingList( player )
	AddPlayerToWaitingList( playerStruct )
	ResetIBMM( player )
}

int function Gamemode1v1_GetNextAvailableGroupID()
{
    return ++settings.groupID
}

// Returns the group struct that corresponds to the given player
// and their opponent.
MatchGroup function Gamemode1v1_GetPlayerSoloGroup( entity player )
{
	MatchGroup group

	if( IsValid ( player ) )
	{
		int handle = player.p.handle
		if ( handle in file.playerMatchMap )
			return file.playerMatchMap[ handle ]
	}

	return group
}

bool function GroupIsLockable( MatchGroup newGroup )
{
	// If inputs match, lock immediately (no movement check needed)
	if( newGroup.player1.p.input == newGroup.player2.p.input )
		return true

	// For cross-input matches, require movement to avoid false positives
	return (
		newGroup.player1.p.lastmoved > 2 &&
		newGroup.player2.p.lastmoved > 2 &&
		Fetch_IBMM_Timeout_For_Player( newGroup.player1 ) == false &&
		Fetch_IBMM_Timeout_For_Player( newGroup.player2 ) == false
	)
}

// Replaces frame-by-frame polling in main loop (lines 4275-4313)
void function HandleChallengeMatchRespawn( MatchGroup group, entity victimPlayer, entity attacker = null )
{
	if ( Gamemode1v1_IsMatchValid( group ) )
		Gamemode1v1_RecordDuelKills( group, victimPlayer, attacker )

	// Wait a brief moment for death state to settle
	wait 0.1

	if ( !Gamemode1v1_IsMatchValid( group ) )
		return

	entity player1 = group.player1
	entity player2 = group.player2
	if ( !IsValid( player1 ) || !IsValid( player2 ) )
		return

	#if DEVELOPER
		printw( format("Challenge match respawn triggered for group %d", group.groupHandle) )
	#endif

	// Determine spawn indices
	int p1 = 0
	int p2 = 1

	// Cycle location if enabled
	if( group.cycle )
	{
		int selectedGroupIndex = FS_1v1_PickAndLogSpawnGroup( player1, player2 )
		if( selectedGroupIndex >= 0 )
		{
			group.groupLocStruct = arenaLocations[ selectedGroupIndex ]
			file.playerLastSpawnGroup[ player1.p.handle ] <- selectedGroupIndex
			file.playerLastSpawnGroup[ player2.p.handle ] <- selectedGroupIndex
		}
	}

	// Swap sides if enabled
	if( group.swap )
	{
		p1 = CoinFlip() ? 1 : 0
		p2 = p1 == 0 ? 1 : 0
	}

	bool nowep = false

	// Clean up entities
	_CleanupPlayerEntities( player1 )
	_CleanupPlayerEntities( player2 )

	// Handle rest requests (this also ends the challenge)
	// This block is important to prevent exploits
	if ( TryProcessRestRequest( player1 ) )
		nowep = true
	else
		thread Gamemode1v1_RespawnForMatch( player1, p1 )

	// If no wep is true, player 1 rested, which handles player 2's state
	if ( !nowep && TryProcessRestRequest( player2 ) )
		nowep = true
	else if ( !nowep )
		thread Gamemode1v1_RespawnForMatch( player2, p2 )

	// Don't give this group weapons if either player rested
	if( !nowep )
		GiveWeaponsToGroup( [ player1, player2 ], group )

	#if DEVELOPER
		printw( format("Challenge match respawn completed for group %d (nowep=%d)", group.groupHandle, nowep ? 1 : 0) )
	#endif
}

bool function _1v1_IsDuelPlayer( entity ent )
{
	return IsValid( ent ) && ent.IsPlayer()
}

// Map attacker -> duel winner. Never returns a non-player (trigger_hurt, world, props).
entity function _1v1_ResolveDuelWinner( MatchGroup group, entity victim, entity attacker )
{
	if ( _1v1_IsDuelPlayer( attacker ) && attacker != victim
		&& ( attacker == group.player1 || attacker == group.player2 ) )
		return attacker

	if ( victim == group.player1 && _1v1_IsDuelPlayer( group.player2 ) )
		return group.player2
	if ( victim == group.player2 && _1v1_IsDuelPlayer( group.player1 ) )
		return group.player1

	return null
}

// Disconnect has no kill event. Deaths are written here because GamemodeUtility_OnPlayerKilled never runs for a disconnect.
void function FS_1v1_RecordForfeit( MatchGroup group, entity leaver )
{
	if( group.IsFinished )
		return

	// Only the live group may score, on the same contents test Gamemode1v1_RemoveMatch uses.
	if( !( group.groupHandle in file.activeMatches ) )
		return

	MatchGroup liveGroup = file.activeMatches[ group.groupHandle ]
	if( liveGroup.slotIndex != group.slotIndex
		|| liveGroup.player1_handle != group.player1_handle
		|| liveGroup.player2_handle != group.player2_handle )
		return

	entity survivor = ( leaver == group.player1 ) ? group.player2 : group.player1
	if( !_1v1_IsDuelPlayer( survivor ) )
		return

	group.winner = survivor

	survivor.SetPlayerNetInt( "kills", survivor.GetPlayerNetInt( "kills" ) + 1 )
	survivor.SetPlayerGameStat( PGS_KILLS, survivor.GetPlayerGameStat( PGS_KILLS ) + 1 )

	if( settings.bEnableStreaks )
	{
		survivor.p.winStreak++
		if( survivor.p.winStreak > survivor.p.bestStreak )
			survivor.p.bestStreak = survivor.p.winStreak
		if( survivor.p.bestStreak > survivor.p.careerBestStreak )
			survivor.p.careerBestStreak = survivor.p.bestStreak
	}

	FS1v1_Stats_MarkDirty( survivor )

	if( !_1v1_IsDuelPlayer( leaver ) )
		return

	FS1v1_Elo_RecordKill( survivor, leaver, group.IsKeep )

	leaver.SetPlayerNetInt( "deaths", leaver.GetPlayerNetInt( "deaths" ) + 1 )
	leaver.SetPlayerGameStat( PGS_DEATHS, leaver.GetPlayerGameStat( PGS_DEATHS ) + 1 )
	leaver.p.winStreak = 0
	FS1v1_Stats_MarkDirty( leaver )
}

void function Gamemode1v1_RecordDuelKills( MatchGroup group, entity victim, entity attacker )
{
	entity winnerPlayer = _1v1_ResolveDuelWinner( group, victim, attacker )
	if ( !_1v1_IsDuelPlayer( winnerPlayer ) )
		return

	entity loserPlayer = ( winnerPlayer == group.player1 ) ? group.player2 : group.player1

	winnerPlayer.SetPlayerNetInt( "kills", winnerPlayer.GetPlayerNetInt( "kills" ) + 1 )
	winnerPlayer.SetPlayerGameStat( PGS_KILLS, winnerPlayer.GetPlayerGameStat( PGS_KILLS ) + 1 )
	FS1v1_Stats_MarkDirty( winnerPlayer )

	if ( !_1v1_IsDuelPlayer( loserPlayer ) )
		return

	FS1v1_Elo_RecordKill( winnerPlayer, loserPlayer, group.IsKeep )

	// The "deaths" netvar is owned by GamemodeUtility_OnPlayerKilled, which runs on
	// this same kill for every playlist with is_elimination_based 0. Writing it here
	// too counted each death twice.
	loserPlayer.SetPlayerGameStat( PGS_DEATHS, loserPlayer.GetPlayerGameStat( PGS_DEATHS ) + 1 )
	FS1v1_Stats_MarkDirty( loserPlayer )
}

void function HandleGroupIsFinished( entity player, entity winner ) //, var damageInfo )
{
	if( !IsValid( player ) )
		return

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )

	if( !Gamemode1v1_IsMatchValid( group ) )
		return

	if( !group.IsKeep && !group.IsFinished )
	{
		#if DEVELOPER
			printw( format("group %d marked as IsFinished - triggering immediate cleanup", group.groupHandle ) )
		#endif

		// Sanitise first: trigger_hurt must never become group.winner.
		entity winnerPlayer = _1v1_ResolveDuelWinner( group, player, winner )
		if ( IsValid( winner ) && !_1v1_IsDuelPlayer( winner ) )
			printt( "[FS-1V1] non-player attacker on match end class=" + winner.GetClassName() + " -> winner=" + ( IsValid( winnerPlayer ) ? winnerPlayer.GetPlayerName() : "null" ) )

		group.winner = winnerPlayer

		// Session kills/deaths for duel HUD + scoreboard remotes (not BR elimination path).
		// Use locals only -- never call player methods on group.winner after assignment races.
		Gamemode1v1_RecordDuelKills( group, player, winner )

		// Update win streaks (non-challenge matches only)
		if( settings.bEnableStreaks && _1v1_IsDuelPlayer( winnerPlayer ) )
		{
			entity loserPlayer = ( winnerPlayer == group.player1 ) ? group.player2 : group.player1

			if( _1v1_IsDuelPlayer( loserPlayer ) )
			{
				winnerPlayer.p.winStreak++
				if( winnerPlayer.p.winStreak > winnerPlayer.p.bestStreak )
					winnerPlayer.p.bestStreak = winnerPlayer.p.winStreak
				if( winnerPlayer.p.bestStreak > winnerPlayer.p.careerBestStreak )
					winnerPlayer.p.careerBestStreak = winnerPlayer.p.bestStreak
				FS1v1_Stats_MarkDirty( winnerPlayer )

				loserPlayer.p.winStreak = 0
			}
		}

		group.IsFinished = true // Mark as finished to prevent duplicate processing

		// Signal both players to stop boundary monitoring thread
		if ( IsValid( group.player1 ) )
			group.player1.Signal( "GroupFinished" )
		if ( IsValid( group.player2 ) )
			group.player2.Signal( "GroupFinished" )

		// Immediate cleanup via callback instead of waiting for polling thread
		thread HandleMatchEndCleanup( group )
	}
}

void function FS_1v1_RouteFinishedPlayer( entity player, bool isWinner )
{
	if ( !IsValid( player ) )
		return

	if ( Gamemode1v1_IsPlayerInState( player, e1v1State.RECAP ) )
		return

	if ( GetTDMState() == eTDMState.NEXT_ROUND_NOW )
	{
		FS_1v1_ParkFinishedPlayerForRoundEnd( player )
		return
	}

	if ( TryProcessRestRequest( player ) )
		return

	Gamemode1v1_AddPlayerToQueue( player, isWinner )
}

void function FS_1v1_ParkFinishedPlayerForRoundEnd( entity player )
{
	if ( !IsValid( player ) )
		return
	if ( Gamemode1v1_IsPlayerResting( player ) )
		return

	FS_1v1_ParkPlayerForRecap( player )
}

void function HandleMatchEndCleanup( MatchGroup group )
{
	// PostDeathThread is started AFTER OnPlayerKilled returns. Yield so it can
	// EndSignal StopPostDeathLogic; then we respawn before BecomeRagdoll.
	wait 0.1

	bool killPauseEnabled = GetCurrentPlaylistVarBool( "kill_pause_enabled", false )
	if( killPauseEnabled && GetTDMState() != eTDMState.NEXT_ROUND_NOW )
	{
		float pauseDuration = GetCurrentPlaylistVarFloat( "kill_pause_duration", 1.5 )
		wait pauseDuration
	}

	// Destroy visual rings
	destroyRingsForGroup( group )

	// Retire the group before routing: a rest request would otherwise re-enter the
	// live-match teardown from Gamemode1v1_AddPlayerToRest and tear it down twice.
	Gamemode1v1_RemoveMatch( group )

	// Both players leave the match into exactly one bucket: resting on their own
	// request, queued otherwise. RECAP players are owned by the round teardown, which
	// queues them itself. One player's rest must never decide the other's routing.
	FS_1v1_RouteFinishedPlayer( group.player1, group.player1 == group.winner )
	FS_1v1_RouteFinishedPlayer( group.player2, group.player2 == group.winner )

	#if DEVELOPER
		printw( format("group %d cleanup completed via callback", group.groupHandle ) )
	#endif

	// Trigger matchmaking for newly waiting players
	thread TriggerMatchmaking()
}

void function HandleOpponentInfo( MatchGroup group )
{
	#if ( false ) && DEVELOPER
		printt
		(
			"Setting Opponents: \n",
			group.player1,
			"'s Opponent:",
			group.player2,
			"\n ",
			group.player2,
			"'s Opponent:",
			group.player1
		)
	#endif

	group.player1.p.lastOpponent = group.player2
	group.player2.p.lastOpponent = group.player1
}

// New function to handle mid-match disconnections immediately
void function HandlePlayerDisconnectedDuringMatch( MatchGroup group, entity disconnectedPlayer )
{
	// Determine which player disconnected and get the remaining player
	entity remainingPlayer = disconnectedPlayer == group.player1 ? group.player2 : group.player1

	// Destroy rings
	destroyRingsForGroup( group )

	// Retire the group before routing, so a rest request cannot re-enter the
	// live-match teardown and put the leaving player back in the queue.
	Gamemode1v1_RemoveMatch( group )

	if ( IsValid( remainingPlayer ) )
	{
		if ( !Gamemode1v1_IsPlayerInState( remainingPlayer, e1v1State.RESTING ) )
			LocalMsg( remainingPlayer, "#FS_OpponentDisconnect" )

		FS_1v1_RouteFinishedPlayer( remainingPlayer, true )
	}

	#if DEVELOPER
		printw( format("group %d cleaned up due to player disconnect", group.groupHandle ) )
	#endif
}

void function InputWatchdog( entity player, entity opponent, MatchGroup group )
{
	// Compare against the inputs this match STARTED with. Reading them again in
	// OnThreadEnd cannot tell 'someone swapped device' from 'they never matched'.
	int startInput = player.p.input
	int opponentStartInput = opponent.p.input

	#if DEVELOPER
		sqprint( format( "THREAD FOR GROUP STARTED - Waiting for input to change" ) )
	#endif

	EndSignal( player, "InputChanged", "OnDeath", "OnDisconnecting" )
	EndSignal( opponent, "InputChanged", "OnDeath", "OnDisconnecting" )

	OnThreadEnd
	(
		function() : ( player, opponent, group, startInput, opponentStartInput )
		{
			#if DEVELOPER
				sqprint( "INPUT WATCHDOG THREAD FOR GROUP ENDED" )
			#endif

			bool inputChanged = IsValid( player ) && IsValid( opponent )
				&& ( player.p.input != startInput || opponent.p.input != opponentStartInput )

			if ( inputChanged )
			{
				entity culprit = player.p.lastInputChangeTime > opponent.p.lastInputChangeTime ? player : opponent
				array<entity> players = [ player, opponent ]

				string infoString
				foreach( pl in players )
				{
					if( !FS_1v1_PlayerHasClient( pl ) )
						continue

					infoString = pl == culprit ? "#FS_YOUR" : pl.p.name
					Remote_CallFunction_ByRef( pl, "ForceScoreboardLoseFocus" )
					LocalMsg( pl, "#FS_INPUT_CHANGED", "#FS_INPUT_CHANGED_SUBSTR", eMsgUI.DEFAULT, 3, "", infoString, "weapon_vortex_gun_explosivewarningbeep" )
				}

				// Full teardown (IsFinished alone left IN_MATCH + realm held forever).
				// A challenge series ends on its own score condition, never on input.
				if( group.isValid && !group.IsFinished && !group.IsKeep )
				{
					group.IsFinished = true
					if ( IsValid( group.player1 ) )
						group.player1.Signal( "GroupFinished" )
					if ( IsValid( group.player2 ) )
						group.player2.Signal( "GroupFinished" )
					thread HandleMatchEndCleanup( group )
				}
			}
		}
	)

	WaitForever()
}

bool function IsLockable( entity player1, entity player2 )
{
	if ( player1.p.lock1v1_setting == false || player2.p.lock1v1_setting == false )
		return false

	return true
}

// Validate and register a new 1v1 pairing. Returns true if activeMatches was updated.
bool function RegisterSoloGroup( MatchGroup newGroup )
{
	int groupHandle = Gamemode1v1_GetNextAvailableGroupID()

	newGroup.groupHandle = groupHandle
	newGroup.startTime = Time()

	// Make sure that this group handle is not already taken.
	if( !( groupHandle in file.activeMatches ) )
	{
		if( IsValid( newGroup.player1 ) && IsValid( newGroup.player2 ) )
		{
			// Add the group to the playerToGroup map for both of the group's players.
			file.playerMatchMap[ newGroup.player1_handle ] <- newGroup
			file.playerMatchMap[ newGroup.player2_handle ] <- newGroup
			newGroup.isValid = true
			file.activeMatches[ groupHandle ] <- newGroup

			// Boundary monitor is started in Gamemode1v1_RespawnForMatch after teleport + delay
			// so damage ring only activates when the match actually begins

			#if DEVELOPER
				if ( file.DEBUG_MATCHMAKING )
					printt( format( "RegisterSoloGroup SUCCESS - players added to group %d - %s & %s - with realm %d", groupHandle, newGroup.player1.p.name, newGroup.player2.p.name, newGroup.slotIndex ))
			#endif
			return true
		}

		#if DEVELOPER
			printw("RegisterSoloGroup ERROR - a player was not valid")
		#endif
		return false
	}

	#if DEVELOPER
		printw(format("RegisterSoloGroup ERROR - group %d already exists", groupHandle))
	#endif
	return false
}

void function RemovePlayerFromGroup( entity player )
{
	//If player was in a match, remove. Cafe
	if( player.p.handle in file.playerMatchMap )
	{
		delete file.playerMatchMap[ player.p.handle ]
	}
}

void function Gamemode1v1_RecordMatchStats( entity player, MatchGroup group, float damage, int hits, int shots, bool bIsKill )
{
	if( !IsValid( player ) || !IsValid( group ) ){ return }

	if ( !( player in group.statsRecap ) )
	{
		groupStats gS
		group.statsRecap[ player ] <- gS
		group.statsRecap[ player ].player = player
		group.statsRecap[ player ].displayname = player.p.name
	}

	group.statsRecap[ player ].damage += damage
	group.statsRecap[ player ].hits += hits
	group.statsRecap[ player ].shots += shots

	if( bIsKill )
		group.statsRecap[ player ].kills++
}

void function Gamemode1v1_RecordMatchHeadshot( entity player, MatchGroup group )
{
	if ( !IsValid( player ) || !IsValid( group ) )
		return
	if ( !( player in group.statsRecap ) )
		return
	group.statsRecap[ player ].headshots++
}

const int FS1V1_DUEL_LOG_MAX = 4096

void function FS1v1_Elo_ResetLog()
{
	file.duelLog.clear()
}

// One entry per duel kill, in order. The host weighs repeats and locked series,
// so the order and the locked flag both have to survive the trip.
void function FS1v1_Elo_RecordKill( entity killer, entity victim, bool locked )
{
	if ( !bGlobalStats() )
		return
	if ( !IsValid( killer ) || !IsValid( victim ) || killer == victim )
		return
	if ( !killer.IsPlayer() || !victim.IsPlayer() || killer.IsBot() || victim.IsBot() )
		return
	if ( file.duelLog.len() >= FS1V1_DUEL_LOG_MAX )
		return

	string killerId = killer.GetPlatformUID()
	string victimId = victim.GetPlatformUID()

	if ( !FS1v1_RemoteStats_IsDigits( killerId ) || !FS1v1_RemoteStats_IsDigits( victimId ) )
		return
	if ( killerId == "9990000" || killerId == "9999000" )
		return
	if ( victimId == "9990000" || victimId == "9999000" )
		return

	file.duelLog.append(
		"{\"killerId\":" + killerId
		+ ",\"victimId\":" + victimId
		+ ",\"locked\":" + ( locked ? "true" : "false" ) + "}"
	)
}

bool function FS1v1_RemoteStats_IsDigits( string s )
{
	if ( s.len() < 1 )
		return false
	for ( int i = 0; i < s.len(); i++ )
	{
		string ch = s.slice( i, i + 1 )
		if ( ch < "0" || ch > "9" )
			return false
	}
	return true
}

string function FS1v1_RemoteStats_JsonEscape( string s )
{
	// The ingest host only accepts ASCII-printable personas, and it validates the
	// whole body: one odd byte used to cost every player in the batch. Anything
	// outside 0x20..0x7E is dropped here rather than shipped and rejected there.
	string out = ""
	int n = s.len()
	if ( n > 64 )
		n = 64
	for ( int i = 0; i < n; i++ )
	{
		int code = expect int( s[i] ) & 0xFF
		if ( code < 0x20 || code > 0x7E )
			continue

		string ch = s.slice( i, i + 1 )
		if ( ch == "\\" )
			out += "\\\\"
		else if ( ch == "\"" )
			out += "\\\""
		else
			out += ch
	}
	return out
}

string function FS1v1_RemoteStats_SanitizeWeapon( string raw )
{
	string out = ""
	int n = raw.len()
	if ( n > 80 )
		n = 80
	for ( int i = 0; i < n; i++ )
	{
		int code = expect int( raw[i] ) & 0xFF
		bool ok = ( code >= 48 && code <= 57 ) || ( code >= 65 && code <= 90 ) || ( code >= 97 && code <= 122 ) || code == 95
		if ( !ok )
		{
			if ( out.len() > 0 )
				break
			continue
		}
		out += raw.slice( i, i + 1 )
		if ( out.len() >= 64 )
			break
	}
	if ( out.len() < 3 )
		return ""
	if ( out == "unknown" || out == "Unknown" || out == "NA" || out == "na" )
		return ""
	if ( out.find( "melee" ) >= 0 )
		return ""
	if ( out.find( "mp_ability_" ) == 0 )
		return ""
	return out
}

string function FS1v1_RemoteStats_HeldWeapon( entity player )
{
	if ( !IsValid( player ) )
		return ""
	entity weap = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( IsValid( weap ) && !weap.IsWeaponOffhand() )
	{
		string w = FS1v1_RemoteStats_SanitizeWeapon( weap.GetWeaponClassName() )
		if ( w != "" )
			return w
	}
	weap = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	if ( IsValid( weap ) )
	{
		string w = FS1v1_RemoteStats_SanitizeWeapon( weap.GetWeaponClassName() )
		if ( w != "" )
			return w
	}
	weap = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
	if ( IsValid( weap ) )
		return FS1v1_RemoteStats_SanitizeWeapon( weap.GetWeaponClassName() )
	return ""
}

void function FS1v1_RemoteStats_ResetWeapon( entity player )
{
	if ( !IsValid( player ) )
		return
	player.p.fs_stats_weapon = ""
	player.p.fs_stats_weapon_damage = 0
	player.p.fs_stats_weapon_dmg = {}
}

void function FS1v1_RemoteStats_RecordWeaponDamage( entity attacker, var damageInfo, float dmg )
{
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return
	int add = int( dmg )
	if ( add < 1 )
		return
	string ornull clsOrNull = GetWeaponClassNameFromDamageInfo( damageInfo )
	if ( clsOrNull == null )
		return
	string cls = FS1v1_RemoteStats_SanitizeWeapon( expect string( clsOrNull ) )
	if ( cls == "" )
		return
	if ( !( cls in attacker.p.fs_stats_weapon_dmg ) )
		attacker.p.fs_stats_weapon_dmg[cls] <- 0
	attacker.p.fs_stats_weapon_dmg[cls] += add
	int total = attacker.p.fs_stats_weapon_dmg[cls]
	if ( total > attacker.p.fs_stats_weapon_damage )
	{
		attacker.p.fs_stats_weapon_damage = total
		attacker.p.fs_stats_weapon = cls
	}
}

string function FS1v1_RemoteStats_WeaponToken( entity player )
{
	if ( !IsValid( player ) )
		return ""
	string w = FS1v1_RemoteStats_SanitizeWeapon( player.p.fs_stats_weapon )
	if ( w != "" )
		return w
	w = FS1v1_RemoteStats_HeldWeapon( player )
	if ( w != "" )
		return w
	string loadout = player.p.weapon_loadout
	if ( loadout == "" || loadout == "NA" )
		return ""
	array<string> parts = split( strip( loadout ), " " )
	if ( parts.len() < 1 )
		return ""
	return FS1v1_RemoteStats_SanitizeWeapon( parts[0] )
}

string function FS1v1_RemoteStats_Input( entity player )
{
	if ( !IsValid( player ) )
		return "unknown"
	if ( player.p.input == 0 )
		return "mnk"
	if ( player.p.input == 1 )
		return "controller"
	return "unknown"
}

string function FS1v1_RemoteStats_PlayerJson( entity player )
{
	string uid = player.GetPlatformUID()
	string persona = FS1v1_RemoteStats_JsonEscape( player.GetPlayerName() )
	int kills = player.GetPlayerNetInt( "kills" )
	int deaths = player.GetPlayerNetInt( "deaths" )
	int damage = player.GetPlayerNetInt( "damage" )
	int hits = player.p.fs_stats_hits
	int shots = player.p.fs_stats_shots
	int headshots = player.p.fs_stats_headshots
	if ( hits > shots )
		shots = hits
	if ( headshots > hits )
		headshots = hits
	if ( damage < 0 )
		damage = 0
	if ( damage > 100000 )
		damage = 100000

	string weapon = FS1v1_RemoteStats_WeaponToken( player )
	string input = FS1v1_RemoteStats_Input( player )

	string out = "{"
	out += "\"accountId\":" + uid
	out += ",\"persona\":\"" + persona + "\""
	out += ",\"kills\":" + string( kills )
	out += ",\"deaths\":" + string( deaths )
	out += ",\"damage\":" + string( damage )
	out += ",\"shots\":" + string( shots )
	out += ",\"hits\":" + string( hits )
	out += ",\"headshots\":" + string( headshots )
	if ( weapon != "" )
		out += ",\"weapon\":\"" + FS1v1_RemoteStats_JsonEscape( weapon ) + "\""
	out += ",\"input\":\"" + input + "\""
	out += "}"
	return out
}

void function FS1v1_RemoteStats_SubmitSession()
{
	if ( !bGlobalStats() )
		return

	string mapName = GetMapName()
	if ( mapName == "" )
		mapName = "unknown"
	if ( mapName.len() > 32 )
		mapName = mapName.slice( 0, 32 )

	string playlist = GetCurrentPlaylistName()
	if ( playlist == "" )
		playlist = "fs_1v1"

	int duration = int( FlowState_RoundTime() )
	if ( duration < 1 )
		duration = 1
	if ( duration > 3600 )
		duration = 3600

	entity champion = GetBestPlayer()
	string winnerId = ""
	if ( IsValid( champion ) && champion.GetPlayerNetInt( "kills" ) > 0 )
	{
		string cuid = champion.GetPlatformUID()
		if ( FS1v1_RemoteStats_IsDigits( cuid ) && cuid != "9990000" && cuid != "9999000" )
			winnerId = cuid
	}

	if ( file.duelLog.len() < 1 )
		return

	string playersJson = ""
	int added = 0
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) || !player.IsPlayer() )
			continue
		if ( player.IsBot() )
			continue
		string uid = player.GetPlatformUID()
		if ( !FS1v1_RemoteStats_IsDigits( uid ) || uid == "9990000" || uid == "9999000" )
			continue
		if ( FS1v1_RemoteStats_JsonEscape( player.GetPlayerName() ) == "" )
			continue
		int kills = player.GetPlayerNetInt( "kills" )
		int deaths = player.GetPlayerNetInt( "deaths" )
		int damage = player.GetPlayerNetInt( "damage" )
		if ( kills < 1 && deaths < 1 && damage < 1 )
			continue
		if ( added > 0 )
			playersJson += ","
		playersJson += FS1v1_RemoteStats_PlayerJson( player )
		added++
		if ( added >= 64 )
			break
	}

	if ( added < 2 )
		return

	string body = "{"
	body += "\"map\":\"" + FS1v1_RemoteStats_JsonEscape( mapName ) + "\""
	body += ",\"playlist\":\"" + FS1v1_RemoteStats_JsonEscape( playlist ) + "\""
	body += ",\"duration\":" + string( duration )
	body += ",\"sessionId\":\"" + string( Time() ) + "-" + FS1v1_RemoteStats_JsonEscape( playlist ) + "\""
	body += ",\"shotSource\":\"fire\""
	if ( winnerId != "" )
		body += ",\"winnerId\":" + winnerId
	body += ",\"players\":[" + playersJson + "]"

	if ( file.duelLog.len() > 0 )
	{
		string duelsJson = ""
		foreach ( int i, string entry in file.duelLog )
		{
			if ( i > 0 )
				duelsJson += ","
			duelsJson += entry
		}
		body += ",\"duels\":[" + duelsJson + "]"
	}

	body += "}"

	if ( !FS_StatsIngest( body ) )
		printt( "[FS-STATS] session ingest queue rejected players=" + string( added ) )
}

bool function Gamemode1v1_IsMatchValid( MatchGroup group )
{
	if( !group.isValid )
		return false

	if( !IsValid( group.player1 ) || !IsValid( group.player2 ) )
		return false

	return true
}

void function Gamemode1v1_RemoveMatch( MatchGroup groupToRemove )
{
	#if DEVELOPER
	// DumpStack
	// printw( "Gamemode1v1_RemoveMatch", groupToRemove.groupHandle )
	#endif
	// Idempotent. Match on contents -- group ids are reused, and a second pass would free a realm slot a newer pair already owns.
	if( !( groupToRemove.groupHandle in file.activeMatches ) )
		return

	MatchGroup liveGroup = file.activeMatches[ groupToRemove.groupHandle ]
	if( liveGroup.slotIndex != groupToRemove.slotIndex
		|| liveGroup.player1_handle != groupToRemove.player1_handle
		|| liveGroup.player2_handle != groupToRemove.player2_handle )
		return

	// Clear validity before map deletes so any late IsMatchValid holders fail closed.
	groupToRemove.isValid = false

	// The realm slot is owned by the group: released here and nowhere else, so no
	// teardown path can burn one. There are only MAX_REALM of them, and running out
	// fails every future pairing.
	FS_1v1_EvictSpectatorsFromRealm( groupToRemove.slotIndex )
	SetIsUsedBoolForRealmSlot( groupToRemove.slotIndex, false )

	int groupHandle = groupToRemove.groupHandle
	int handle1 = groupToRemove.player1_handle
	int handle2 = groupToRemove.player2_handle

	if ( handle1 in file.playerMatchMap )
	{
		// #if DEVELOPER
			// sqprint( format( "Gamemode1v1_RemoveMatch - removed player 1 %d from group map", handle1 ) )
		// #endif
		delete file.playerMatchMap[ handle1 ]
	} else
	{
		#if DEVELOPER
			sqprint(format( "Gamemode1v1_RemoveMatch ERROR - player 1 didn't exist in the group map", handle1 ) )
		#endif
	}

	if ( handle2 in file.playerMatchMap )
	{
		// #if DEVELOPER
			// sqprint(format( "Gamemode1v1_RemoveMatch - removed player 2 %d from group map", handle2 ) )
		// #endif
		delete file.playerMatchMap[ handle2 ]
	} else
	{
		#if DEVELOPER
			sqprint(format( "Gamemode1v1_RemoveMatch ERROR - player 2 didn't exist in the group map", handle2 ) )
		#endif
	}

	if( groupHandle in file.activeMatches )
	{
		#if DEVELOPER
			if ( file.DEBUG_MATCHMAKING )
				printt( format( " SS - removing group %d for players with handles %d %d", groupHandle, handle1, handle2 ) )
		#endif
		delete file.activeMatches[ groupHandle ]
	}
	else
	{
		#if DEVELOPER
			printw( format( "Gamemode1v1_RemoveMatch ERROR - groupHandle %d not in file.activeMatches", groupToRemove.groupHandle ) )
		#endif
	}

	FS_1v1_AuditRealmSlots( "retire" )
}

void function _SendMatchRecaps( MatchGroup group )
{
	if( !IsValid( group.player1 ) || !IsValid( group.player2 ) )
		return

	if ( !( group.player1 in group.statsRecap ) || !( group.player2 in group.statsRecap ) )
		return

	groupStats player1 = group.statsRecap[ group.player1 ]
	groupStats player2 = group.statsRecap[ group.player2 ]

	string serverMsg = ""
	string winnerName = ""
	string defeatedName = ""
	int winnerKills = 0
	int defeatedDeaths = 0
	bool tied = false

	if( settings.bChalServerMsg )
	{
		if( player1.kills > player2.kills )
		{
			winnerName = group.player1.p.name
			winnerKills = player1.kills
			defeatedName = group.player2.p.name
			defeatedDeaths = player2.kills
		}
		else if ( player2.kills > player1.kills )
		{
			winnerName = group.player2.p.name
			winnerKills = player2.kills
			defeatedName = group.player1.p.name
			defeatedDeaths = player1.kills
		}
		else if ( player1.kills == player2.kills )
		{
			tied = true
			winnerName = group.player1.p.name
			winnerKills = player1.kills
			defeatedName = group.player2.p.name
			defeatedDeaths = player2.kills
		}

		if ( tied )
			serverMsg = winnerName + " tied in a challenge vs " + defeatedName
		else
			serverMsg = format( " %s won a challenge vs %s,  %d - %d", winnerName, defeatedName, winnerKills, defeatedDeaths )

		// Chat_GetAllEffects / ChatBuilder not on S21 — plain splash.
		foreach ( player in GetPlayerArray() )
		{
			if ( IsValid( player ) )
				LocalSplashMsg( player, "[Challenge] " + serverMsg, 5.0 )
		}
	}

	groupRecapStats( group.player1, player1.damage, player1.hits, player1.shots, player1.kills, player1.deaths, player2.displayname, player2.damage, player2.hits, player2.shots, player2.kills, player2.deaths, group.startTime )
	groupRecapStats( group.player2, player2.damage, player2.hits, player2.shots, player2.kills, player2.deaths, player1.displayname, player1.damage, player1.hits, player1.shots, player1.kills, player1.deaths, group.startTime )

	// Show streak info to each player after recap
	foreach( pl in [ group.player1, group.player2 ] )
	{
		if( IsValid( pl ) && pl.p.winStreak > 0 )
			Message_New( pl, format( "Win Streak: %d (Best: %d)", pl.p.winStreak, pl.p.careerBestStreak ), 5 )
	}
}

// Returns true only after realm claimed + RegisterSoloGroup succeeds.
// Caller must not Signal MatchFound / Respawn / GiveWeapons on false.
bool function _CreateMatchFromPair( MatchGroup newGroup )
{
    entity player = newGroup.player1
    entity opponent = newGroup.player2

    if ( !IsValid( player ) || !IsValid( opponent ) )
        return false

	if( player == opponent )
	{
		#if DEVELOPER
			DumpStack()
			Warning( "[FS-1V1] Tried to add same players to inprogress list." )
		#endif
		player.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )
		return false
	}

	// Hard fail if either is already mapped. Do not tear down the live match.
	if ( player.p.handle in file.playerMatchMap || opponent.p.handle in file.playerMatchMap )
	{
		#if DEVELOPER
			printw( "[FS-1V1] _CreateMatchFromPair abort: player already in match map" )
		#endif
		return false
	}

	// Claim realm before PREMATCH/dequeue so full-server cannot orphan off-queue players.
	int slotIndex = Gamemode1v1_GetFreeRealmSlot()
	if ( slotIndex < 0 )
	{
		#if DEVELOPER
			printw( "[FS-1V1] _CreateMatchFromPair: no free realm slot" )
		#endif
		return false
	}

	newGroup.slotIndex = slotIndex
	newGroup.player1 = player
	newGroup.player2 = opponent

	int selectedGroupIndex = FS_1v1_PickAndLogSpawnGroup( player, opponent )
	if( selectedGroupIndex >= 0 )
	{
		newGroup.groupLocStruct = arenaLocations[ selectedGroupIndex ]
		file.playerLastSpawnGroup[ player.p.handle ] <- selectedGroupIndex
		file.playerLastSpawnGroup[ opponent.p.handle ] <- selectedGroupIndex
	}
	else
	{
		SetIsUsedBoolForRealmSlot( slotIndex, false )
		printt( "[FS-1V1] _CreateMatchFromPair: no arenaLocations" )
		return false
	}

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.PREMATCH )
	Gamemode1v1_SetPlayerGamestate( opponent, e1v1State.PREMATCH )

	// Enemy net ent (VS scoreboard) is now set in GiveWeaponsToGroup after match found delay
	LocalMsg( player, "#FS_NULL", "", eMsgUI.EVENT, 1 )

	Gamemode1v1_RemovePlayerFromWaitingList( player.p.handle )
	Gamemode1v1_RemovePlayerFromWaitingList( opponent.p.handle )
	Gamemode1v1_RemovePlayerFromRestingList( player )
	Gamemode1v1_RemovePlayerFromRestingList( opponent )

	if ( !RegisterSoloGroup( newGroup ) )
	{
		SetIsUsedBoolForRealmSlot( slotIndex, false )
		if ( IsValid( player ) )
			Gamemode1v1_AddPlayerToQueue( player )
		if ( IsValid( opponent ) )
			Gamemode1v1_AddPlayerToQueue( opponent )
		printt( "[FS-1V1] _CreateMatchFromPair: RegisterSoloGroup failed; requeued" )
		return false
	}

	return true
}


//===============================================================================
//
// SECTION 11: PLAYER LIST MANAGEMENT
// Waiting and resting list operations
//
//===============================================================================

void function AddPlayerToWaitingList( QueuedPlayer playerStruct )
{
	if( IsValid( playerStruct.player ) )
	{
		file.waitingQueue[ playerStruct.player.p.handle ] <- playerStruct
		printt( format( "[FS-1V1][MM] queued %s (bot=%d) -- waiting=%d",
			playerStruct.player.GetPlayerName(), playerStruct.player.IsBot() ? 1 : 0,
			file.waitingQueue.len() ) )
	}
	else
		sqerror( "[AddPlayerToWaitingList] player to add was invalid" )
}

table<int,bool> function FS_1v1_GetPlayersResting()
{
	return file.restingPlayers
}

table<int, QueuedPlayer> function FS_1v1_GetPlayersWaiting()
{
	return file.waitingQueue
}

void function _LobbyStateSanitize( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MatchFound" )

	while ( true )
	{
		wait 0.5
		if ( !IsValid( player ) )
			return
		if ( !FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( player ) ) )
			return
		if ( FS_1v1_LobbyHasGuns( player ) )
			FS_1v1_ApplyLobbyLoadout( player )
	}
}

void function Gamemode1v1_ForceRest( entity player )
{
	if( !file.bRestEnabled )
		return

	if( !IsValid( player ) ) // || Gamemode1v1_IsPlayerInState( player, e1v1State.SEQUENCE ) //potential fix in future.
		return

	int playerHandle = player.p.handle
	if( playerHandle in file.restingPlayers )
		return

	if( isScenariosMode() )
	{
		FS_Scenarios_ForceRest( player )
	}
	else
	{
		//MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
		//group.IsFinished = true

		if( Gamemode1v1_IsPlayerWaiting( player ) )
			Gamemode1v1_RemovePlayerFromWaitingList( playerHandle )

		player.p.lastRestUsedTime = Time()

		try
		{
			player.Die( null, null, { damageSourceId = eDamageSourceId.damagedef_despawn } )
		}
		catch (error)
		{
			#if DEVELOPER
				sqerror( "[1v1:RestDie] " + error )
			#endif
		}

		Gamemode1v1_AddPlayerToRest( player )

		thread Gamemode1v1_RespawnForMatch( player )
	}
}

void function Gamemode1v1_RemovePlayerFromRestingList( entity player )
{
	int playerHandle = player.p.handle
	if ( playerHandle in file.restingPlayers )
	{
		delete file.restingPlayers[ playerHandle ]
		FS_1v1_RequestRestingNotificationRefresh()
	}
}

void function Gamemode1v1_RemovePlayerFromWaitingList( int handle )
{
	// #if DEVELOPER
	// printt( "player removed from waiting list", handle )
	// #endif

	if ( handle in file.waitingQueue )
		delete file.waitingQueue[ handle ]
}

void function SetShowWaitingMsg( entity player, bool value )
{
    if ( !IsValid( player ) )
		return

	int handle = player.p.handle
    if ( handle in file.waitingQueue )
        file.waitingQueue[ handle ].showWaitingMsg = value
}

bool function TryProcessRestRequest( entity player )
{
	if( !IsValid( player ) ) //probably unneccessary
		return false

	if ( player.p.rest_request )
	{
		player.p.rest_request = false
		Gamemode1v1_ForceRest( player )
		return true
	}

	return false
}

void function _3v3ModePlayerToRestingList( entity player )
{
	int playerHandle = player.p.handle
	Gamemode1v1_RemovePlayerFromWaitingList( playerHandle )
	_AddPlayerToRestingList( playerHandle )

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.RESTING )
	FS_1v1_ApplyLobbyLoadout( player )
	FS_SetRealmForPlayer( player, 0 )
	LocalMsg( player, "#FS_RESTING", "", eMsgUI.EVENT, settings.roundTime )

	FS_1v1_RequestRestingNotificationRefresh()
}

void function _AddPlayerToRestingList( int playerHandle )
{
	if( playerHandle in file.restingPlayers )
		file.restingPlayers[ playerHandle ] = true
	else
		file.restingPlayers[ playerHandle ] <- true
}

entity function returnOpponentOfPlayer( entity player )
{
	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
    entity opponent

	if ( group.isValid && IsValid( player ) )
	{
		if( IsValid( group.player2 ) && IsValid( group.player1 ) )
		{
			if ( player == group.player1 )
				opponent = group.player2
			else
				opponent = group.player1
		}
    }

    return opponent
}

void function Scenarios_AddPlayerToQueue( entity player, bool isWinner = false )
{
	if( !IsValid( player ) || Gamemode1v1_IsPlayerWaiting( player ) )
		return
	if( player.IsBot() && GetCurrentPlaylistVarBool( "fs_1v1_skip_bots", false ) )
		return

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.WAITING )
	HolsterAndDisableWeapons_Raw( player )
	FS_ClearRealmsAndAddPlayerToAllRealms( player )
	Gamemode1v1_TeleportPlayer( player, FS_1v1_PickWaitingRoomLoc() )
	thread _LobbyStateSanitize( player )

	player.SetMinimapZoomScale( 0.75, 3.0 )

	Remote_CallFunction_NonReplay( player, "FS_Scenarios_TogglePlayersCardsVisibility", false, true )

	if( player.Player_IsFreefalling() )
		Signal( player, "PlayerSkyDive" )

	_CleanupPlayerEntities( player )
	SetTeam( player, TEAM_IMC )

	scenariosGroupStruct ornull playerGroup = FS_Scenarios_ReturnGroupForPlayer( player )
	if( playerGroup != null )
	{
		expect scenariosGroupStruct( playerGroup )

		if( playerGroup.isValid )
		{
			foreach( scenariosTeamStruct team in playerGroup.teams )
			{
				int maxIter = team.players.len() - 1

				for( int i = maxIter; i >= 0; i-- )
				{
					entity splayer = team.players[i]

					if( !IsValid( splayer ) || splayer == player )
						team.players.remove( i )
				}
			}

			if( player.p.handle in FS_Scenarios_GetPlayerToGroupMap() )
				delete FS_Scenarios_GetPlayerToGroupMap()[ player.p.handle ]

			player.SetShieldHealth( 0 )
			player.SetShieldHealthMax( 0 )
			Inventory_SetPlayerEquipment(player, "", "armor")
			Inventory_SetPlayerEquipment(player, "", "backpack")
			Inventory_SetPlayerEquipment(player, "", "incapshield")
			Inventory_SetPlayerEquipment(player, "", "helmet")
			if( IsAlive( player ) )
				player.SetHealth( player.GetMaxHealth() )
		}
	}

	//Remote_CallFunction_ByRef( player, "Minimap_DisableDraw" )
	// Remote_CallFunction_ByRef( player, "Minimap_DisableDraw" )

	ClearRecentDamageHistory( player )
	ClearLastAttacker( player )

	TakeAllPassives( player )
	player.SetPlayerNetTime( "FS_Scenarios_currentDeathfieldRadius", 0 )
	player.SetPlayerNetTime( "FS_Scenarios_currentDistanceFromCenter", -1 )
	player.SetPlayerNetTime( "FS_Scenarios_gameStartTime", -1 )

	if( Bleedout_IsBleedingOut( player ) )
		Signal( player, "BleedOut_OnRevive" )

	Signal(player, "InterruptSyncedMelee")

	player.SetPlayerNetTime( "FS_Scenarios_timePlayerEnteredInLobby", Time() )
	if( FS_1v1_PlayerHasClient( player ) )
		Remote_CallFunction_NonReplay( player, "FS_DestroyCompass" )

	SetPlayerInventory( player, [] ) //clear inventory.

	// Clear all equipment slots
	foreach ( slot, slotData in EquipmentSlot_GetAllEquipmentSlots() )
		Inventory_SetPlayerEquipment( player, "", slot )

	TakeAllWeapons( player )
	FS_GiveRandomMelee( player, true )

	QueuedPlayer playerStruct
	playerStruct.player = player
	playerStruct.handle = player.p.handle

	if( !settings.isScenariosMode && !bIsCoachingMode() )
	{
		// Only apply victim penalty if player lost a match (has lastKiller)
		// First-time joins (no lastKiller) should not be penalized
		if( !isWinner && IsValid( player.p.lastKiller ) )
		{
			playerStruct.victimPenaltyExpire = Time() + penaltyDuration

			// Start timer to trigger matchmaking when penalty expires
			thread StartVictimPenaltyTimer( player, penaltyDuration )
		}
		else
		{
			playerStruct.victimPenaltyExpire = Time()
		}

		playerStruct.waitingTime = playerStruct.victimPenaltyExpire + QUEUE_TIMEOUT_EXTRA

		if( player.p.IBMM_grace_period > 0 )
			playerStruct.waitingTime += player.p.IBMM_grace_period
	}

	playerStruct.kd = _CalculateWeightedKD( player )
	// Prefer duel foe (HandleOpponentInfo) over lastKiller for SBMM rematch avoid.
	if ( IsValid( player.p.lastOpponent ) )
		playerStruct.lastOpponent = player.p.lastOpponent
	else
		playerStruct.lastOpponent = player.p.lastKiller
	playerStruct.queue_time = Time()

	Gamemode1v1_RemovePlayerFromRestingList( player )
	AddPlayerToWaitingList( playerStruct )

	ResetIBMM( player ) //must be after adding to waiting list.

	FS_1v1_ApplyLobbyLoadout( player )

	LocalMsg( player, "#FS_IN_QUEUE", "", eMsgUI.EVENT, settings.roundTime )
}

void function Gamemode1v1_AddPlayerToRest( entity player ) //handles opponent to waiting list.
{
	if( !IsValid( player ) )
		return

	if( !IsAlive( player ) )
		Gamemode1v1_ForcePilotRespawn( player )

	FS_1v1_ApplyPlayerCamo( player )

	if( !IsInvincible(player ) )
		MakeInvincible(player)

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.RESTING )
	FS_1v1_ApplyLobbyLoadout( player )
	thread _LobbyStateSanitize( player )

	// Clear existing panels; resting panel is shown by UpdateRestingNotifications below
	DirectClearAllPanels( player )

	player.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )
	Gamemode1v1_RemovePlayerFromWaitingList( player.p.handle )

	// Update all resting players' panels with new counts
	FS_1v1_RequestRestingNotificationRefresh()

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	if( group.isValid )
	{
		if( IsPlayerPendingChallenge( player ) || IsPlayerPendingLockOpponent( player ) )
			endLock1v1( player, true )

		entity opponent = returnOpponentOfPlayer( player )

		// if(IsValid(arenaLocations[group.slotIndex].Panel)) //Panel in current Location
			// arenaLocations[group.slotIndex].Panel.SetSkin(1) //set panel to red(default color)

		destroyRingsForGroup( group )

		#if DEVELOPER
			sqprint( "remove group request 03" )
		#endif

		Gamemode1v1_RemoveMatch( group ) //destroy this group

		if( IsValid( opponent ) ) //opponent still valid
			Gamemode1v1_AddPlayerToQueue( opponent ) //put opponent back in waiting list
	}
	else
	{
		endLock1v1( player, false )
	}

	_AddPlayerToRestingList( player.p.handle )
	FS_SetRealmForPlayer( player, 0 )
	LocalMsg( player, "#FS_RESTING", "", eMsgUI.EVENT, settings.roundTime )

	DecideToggleCollision_Rest( player, false )
	player.p.rest_request = false
}

void function Gamemode1v1_AddPlayerToQueueAfterDeath( entity player, bool isWinner = false )
{
	wait 0.1
	if ( IsValid( player ) )
		Gamemode1v1_AddPlayerToQueue( player, isWinner )
}

void function Gamemode1v1_AddPlayerToQueue( entity player, bool isWinner = false, bool fromResting = false )
{
	// DumpStack
	if( settings.isScenariosMode && !bIsCoachingMode() )
	{
		Scenarios_AddPlayerToQueue( player, isWinner )
		return
	}

	if( !IsValid( player ) )
		return
	if( Gamemode1v1_IsPlayerWaiting( player ) )
		return

	// Resting is a standing choice, not a per-round state: only the rest toggle itself
	// ( fromResting ) may pull a player back into the queue. Every other route here is a
	// deferred death or teardown callback that would silently cancel the rest.
	if( !fromResting && Gamemode1v1_IsPlayerResting( player ) )
	{
		printt( "[FS-1V1] AddPlayerToQueue refused, player is resting: " + player.GetPlayerName() )
		return
	}

	// Bridge: second clients / local test players often report IsBot==true
	// (names like "test", "(1)test"). Skip that filter so queue can fill.
	// Set playlist fs_1v1_skip_bots 1 to restore stock bot exclusion.
	if( player.IsBot() && GetCurrentPlaylistVarBool( "fs_1v1_skip_bots", false ) )
		return

	if( !IsAlive( player ) )
	{
		if ( !Gamemode1v1_ForcePilotRespawn( player ) || !IsAlive( player ) )
		{
			printt( "[FS-1V1] AddPlayerToQueue still dead " + player.GetPlayerName() )
			return
		}
	}

	if( !IsInvincible(player ) ) // (cafe) fix invincible stack bug
		MakeInvincible(player)

	HolsterAndDisableWeapons_Raw( player )
	Signal( player, "InterruptSyncedMelee" )

	// Leave the fight slot before the WR teleport or the other client culls us (mask AND == 0).
	FS_ClearRealmsAndAddPlayerToAllRealms( player )

	// Joining the queue means standing in the waiting room. The old INVALID exemption
	// assumed the spawn callback had already placed us, which is not true on the first
	// connect of a round -- the player was left wherever they spawned.
	LocPair waitLoc = FS_1v1_PickWaitingRoomLoc()
	if( !fromResting )
		Gamemode1v1_TeleportPlayer( player, waitLoc )

	// Set WAITING before weapon strip so a hang mid-strip still shows queue membership.
	if( Gamemode1v1_GetPlayerGamestate( player ) != e1v1State.RECAP )
	{
		Gamemode1v1_SetPlayerGamestate( player, e1v1State.WAITING )
	}

	try
	{
		FS_1v1_ApplyLobbyLoadout( player )
	}
	catch ( weaponErr )
	{
		printt( "[FS-1V1] AddPlayerToQueue weapon strip failed: " + weaponErr )
	}
	thread _LobbyStateSanitize( player )

	// Strip shields and equipment
	try
	{
		player.SetShieldHealth( 0 )
		player.SetShieldHealthMax( 0 )
		foreach ( slot, slotData in EquipmentSlot_GetAllEquipmentSlots() )
			Inventory_SetPlayerEquipment( player, "", slot )
		if( IsAlive( player ) )
			player.SetHealth( player.GetMaxHealth() )
	}
	catch ( equipErr )
	{
		printt( "[FS-1V1] AddPlayerToQueue equip strip failed: " + equipErr )
	}

	player.SetMinimapZoomScale( 0.75, 5.0 )

	SetPlayerInventory( player, [] )

	player.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )

	QueuedPlayer playerStruct
	playerStruct.player = player
	playerStruct.handle = player.p.handle

	if( !settings.isScenariosMode && !bIsCoachingMode() )
	{
		// Only apply victim penalty if player lost a match (has lastKiller)
		// First-time joins (no lastKiller) should not be penalized
		if( !isWinner && IsValid( player.p.lastKiller ) )
		{
			playerStruct.victimPenaltyExpire = Time() + penaltyDuration

			// Start timer to trigger matchmaking when penalty expires
			thread StartVictimPenaltyTimer( player, penaltyDuration )
		}
		else
		{
			playerStruct.victimPenaltyExpire = Time()
		}

		playerStruct.waitingTime = playerStruct.victimPenaltyExpire + QUEUE_TIMEOUT_EXTRA

		if( player.p.IBMM_grace_period > 0 )
			playerStruct.waitingTime += player.p.IBMM_grace_period
	}

	playerStruct.kd = _CalculateWeightedKD( player )
	// Prefer duel foe (HandleOpponentInfo) over lastKiller for SBMM rematch avoid.
	if ( IsValid( player.p.lastOpponent ) )
		playerStruct.lastOpponent = player.p.lastOpponent
	else
		playerStruct.lastOpponent = player.p.lastKiller
	playerStruct.queue_time = Time()

	Gamemode1v1_RemovePlayerFromRestingList( player )
	AddPlayerToWaitingList( playerStruct )

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[MATCHMAKING DEBUG] Player added to waiting list: %s (total waiting: %d)", player.GetPlayerName(), file.waitingQueue.len()) )
	#endif

	// Re-stamp here as well: a fake client can reach OnClientConnected before
	// IsBot() answers, and the detector never runs to correct it.
	if( player.IsBot() && player.p.input != 1 )
	{
		player.p.input = 1
		FS_1v1_PublishInputState( player )
	}

	ResetIBMM( player ) //must be after adding to waiting list.

	// Start timer threads for IBMM grace period and waiting timeout
	if( !settings.isScenariosMode && !bIsCoachingMode() )
	{
		// Start IBMM grace period timer if player has one set
		if( player.p.IBMM_grace_period > 0 )
		{
			player.SetPlayerNetTime( "FS_1v1_QueueGraceEnd", Time() + player.p.IBMM_grace_period )
			player.SetPlayerNetFloat( "FS_1v1_QueueGraceDur", player.p.IBMM_grace_period )
			thread StartIBMMGracePeriodTimer( player, player.p.IBMM_grace_period )
		}
		else
		{
			player.SetPlayerNetTime( "FS_1v1_QueueGraceEnd", -1 )
		}

		// Waiting timeout: victimPenalty + QUEUE_TIMEOUT_EXTRA + IBMM grace
		float timeUntilTimeout = playerStruct.waitingTime - Time()
		if ( timeUntilTimeout > 0 )
		{
			thread StartWaitingTimeoutTimer( player, timeUntilTimeout )
		}
	}

	FS_1v1_ApplyPlayerCamo( player )

	if( !bIsCoachingMode() && FS_1v1_PlayerHasClient( player ) )
		LocalMsg( player, "#FS_IN_QUEUE", "", eMsgUI.EVENT, settings.roundTime )

	if( bIsCoachingMode() )
	{
		if( !IsAlive( player ) )
			Gamemode1v1_ForcePilotRespawn( player )

		if( GetPlayerArray().len() == 2 )
		{
			Message_New( player, "Welcome to District's 1v1 Faceoff\n\n Waiting For Admin To Start", 300 )
			Remote_CallFunction_NonReplay(player, "Flowstate_OpenCoachingMenu")
		}
		else
			Message_New( player, "Welcome to District's 1v1 Faceoff\n\n Waiting Another Player To Start", 9999 )
	}

	thread TriggerMatchmaking()
}


//===============================================================================
//
// SECTION 16: REALM, BOUNDARY & SPAWN MANAGEMENT
// Realm assignment, boundaries, spawning
//
//===============================================================================

entity function CreateSmallRingBoundary( vector Center )
{
    vector smallRingCenter = Center
	float smallRingRadius = DEFAULT_MAX_FIGHT_DISTANCE
	entity smallcircle = CreateEntity( "prop_script" )
	smallcircle.SetValueForModelKey( $"mdl/fx/ar_survival_radius_1x100.rmdl" )
	smallcircle.kv.fadedist = 2000
	smallcircle.kv.modelscale = smallRingRadius
	smallcircle.kv.renderamt = 1
	smallcircle.kv.rendercolor = FlowState_RingColor()
	smallcircle.kv.solid = 0
	smallcircle.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	// smallcircle.SetOwner(Owner)
	smallcircle.SetOrigin( smallRingCenter )
	smallcircle.SetAngles( <0, 0, 0> )
	smallcircle.NotSolid()
	smallcircle.DisableHibernation()
	smallcircle.RemoveFromAllRealms()

	// smallcircle.Minimap_SetObjectScale( min(smallRingRadius / SURVIVAL_MINIMAP_RING_SCALE, 1) )
	// smallcircle.Minimap_SetAlignUpright( true )
	// smallcircle.Minimap_SetZOrder( 2 )
	// smallcircle.Minimap_SetClampToEdge( true )
	// smallcircle.Minimap_SetCustomState( eMinimapObject_prop_script.OBJECTIVE_AREA )

	DispatchSpawn( smallcircle )

	// foreach ( eachPlayer in GetPlayerArray )
	// {
	// smallcircle.Minimap_AlwaysShow( 0, eachPlayer )
	// }
	return smallcircle
}

void function FS_ClearRealmsAndAddPlayerToAllRealms( entity player )
{
	FS_SetRealmForPlayer( player, eRealms.DEFAULT )

	if ( !IsValid( player ) )
		return

	array<int> realms = player.GetRealms()
	string bits = ""
	foreach ( int r in realms )
		bits += string( r ) + " "
	printt( "[FS-1V1] lobby realm " + player.GetPlayerName() + " [" + bits + "]" )
}

int function FS_GetEntityPrimaryRealm( entity ent )
{
	if ( !IsValid( ent ) )
		return 0

	array<int> realms = ent.GetRealms()
	if ( realms.len() < 1 )
		return 0

	foreach ( int r in realms )
	{
		if ( r >= 1 )
			return r
	}

	return realms[0]
}

void function FS_SetRealmForPlayer( entity player, int realmIndex )
{
	if( !IsValid( player ) )
		return

	// Playlist killswitch: fs_1v1_use_realms 0 forces all-realms (damage filter still applies).
	if( !GetCurrentPlaylistVarBool( "fs_1v1_use_realms", true ) )
	{
		player.AddToAllRealms()
		return
	}

	// 0 = lobby (eRealms.DEFAULT). Fight slots are 1-MAX_REALM.
	if( realmIndex < 0 || realmIndex > MAX_REALM )
		return

	player.RemoveFromAllRealms()
	player.AddToRealm( realmIndex )
	// Empty mask is match-none on the client. AddToRealm(0) no-op leaves both players invisible.
	if ( player.GetRealms().len() < 1 )
	{
		printt( "[FS-1V1] AddToRealm(" + string( realmIndex ) + ") empty mask " + player.GetPlayerName() + " -- AddToAllRealms" )
		player.AddToAllRealms()
	}
}

void function Gamemode1v1_BroadcastObituary( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsPlayer() )
		return

	int damageSourceId = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	if ( damageSourceId == eDamageSourceId.damagedef_despawn )
		return

	int flags = OBIT_FLAG_KILL
	int scriptDamageType = DamageInfo_GetCustomDamageType( damageInfo )
	if ( IsBitFlagSet( scriptDamageType, DF_HEADSHOT ) || IsValidHeadShot( damageInfo, victim ) )
		flags = flags | OBIT_FLAG_HEADSHOT

	array<int> attackerPacked = [0, 0, 0, 0]
	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim )
		attackerPacked = Scoreboard1v1_PackName( attacker.GetPlayerName() )

	array<int> victimPacked = Scoreboard1v1_PackName( victim.GetPlayerName() )

	foreach ( entity player in GetPlayerArrayIncludingSpectators() )
	{
		if ( !FS_1v1_PlayerHasClient( player ) )
			continue

		Remote_CallFunction_NonReplay( player, "ServerCallback_1v1_Obituary",
			attackerPacked[0], attackerPacked[1], attackerPacked[2], attackerPacked[3],
			victimPacked[0], victimPacked[1], victimPacked[2], victimPacked[3],
			damageSourceId, flags )
	}
}

void function Gamemode1v1_SendVsHud( entity viewer, entity enemy )
{
	if ( !FS_1v1_PlayerHasClient( viewer ) || !IsValid( enemy ) )
		return

	array<int> namePacked = Scoreboard1v1_PackName( enemy.GetPlayerName() )
	int enemyRank = enemy.GetPlayerNetInt( "FSDM_1v1_PositionInScoreboard" )
	if ( enemyRank < 0 )
		enemyRank = 0
	int localRank = viewer.GetPlayerNetInt( "FSDM_1v1_PositionInScoreboard" )
	if ( localRank < 0 )
		localRank = 0

	int latency = enemy.GetPlayerNetInt( "latency" )
	if ( latency < 0 )
		latency = 0

	viewer.SetPlayerNetInt( "FS_1v1_EnemyInput", enemy.GetPlayerNetBool( "FS_PlayerIsMnk" ) ? 0 : 1 )

	Remote_CallFunction_NonReplay( viewer, "ServerCallback_1v1_VsHudEnemy",
		namePacked[0], namePacked[1], namePacked[2], namePacked[3],
		enemy.GetPlayerNetInt( "kills" ),
		enemy.GetPlayerNetInt( "deaths" ),
		enemy.GetPlayerNetInt( "damage" ),
		latency,
		enemyRank,
		localRank )
}

void function Gamemode1v1_VsHudSync_THREAD( MatchGroup group )
{
	entity p1 = group.player1
	entity p2 = group.player2

	if ( IsValid( p1 ) )
	{
		p1.EndSignal( "GroupFinished" )
		p1.EndSignal( "OnDestroy" )
		p1.EndSignal( "OnDisconnecting" )
	}
	if ( IsValid( p2 ) )
	{
		p2.EndSignal( "GroupFinished" )
		p2.EndSignal( "OnDestroy" )
		p2.EndSignal( "OnDisconnecting" )
	}

	OnThreadEnd(
		function() : ( p1, p2 )
		{
			if ( IsValid( p1 ) )
			{
				p1.SetPlayerNetInt( "FS_1v1_LockState", -1 )
				p1.SetPlayerNetInt( "FS_1v1_EnemyInput", -1 )
			}
			if ( IsValid( p2 ) )
			{
				p2.SetPlayerNetInt( "FS_1v1_LockState", -1 )
				p2.SetPlayerNetInt( "FS_1v1_EnemyInput", -1 )
			}
			if ( FS_1v1_PlayerHasClient( p1 ) )
				Remote_CallFunction_NonReplay( p1, "ServerCallback_1v1_VsHudHide" )
			if ( FS_1v1_PlayerHasClient( p2 ) )
				Remote_CallFunction_NonReplay( p2, "ServerCallback_1v1_VsHudHide" )
		}
	)

	Scoreboard1v1_WriteRanks()

	while ( true )
	{
		if ( !Gamemode1v1_IsMatchValid( group ) || group.IsFinished )
			return
		if ( !IsValid( group.player1 ) || !IsValid( group.player2 ) )
			return

		Gamemode1v1_SendVsHud( group.player1, group.player2 )
		Gamemode1v1_SendVsHud( group.player2, group.player1 )
		wait 0.5
	}
}

void function Gamemode1v1_StartVsHudSync( MatchGroup group )
{
	if ( !Gamemode1v1_IsMatchValid( group ) )
		return
	if ( group.vsHudThread )
		return

	group.vsHudThread = true
	thread Gamemode1v1_VsHudSync_THREAD( group )
}

// Engine rejects SetAngles yaw outside [-360, 360] (GenerateRandomSpawns used ang+180 raw).
vector function Gamemode1v1_NormalizeAngles( vector angles )
{
	float p = angles.x
	float y = angles.y
	float r = angles.z

	while ( y > 180.0 )
		y -= 360.0
	while ( y < -180.0 )
		y += 360.0
	while ( p > 180.0 )
		p -= 360.0
	while ( p < -180.0 )
		p += 360.0
	while ( r > 180.0 )
		r -= 360.0
	while ( r < -180.0 )
		r += 360.0

	return <p, y, r>
}

vector function Gamemode1v1_SnapTeleportOrigin( entity player, vector origin )
{
	if( !IsValid( player ) )
		return origin

	vector mins = player.GetPlayerMins()
	vector maxs = player.GetPlayerMaxs()
	array<entity> ignore = GetPlayerArray_Alive()
	if ( ignore.len() == 0 )
		ignore.append( player )

	array<vector> candidates
	candidates.append( origin )
	candidates.append( origin + <32, 0, 0> )
	candidates.append( origin + <-32, 0, 0> )
	candidates.append( origin + <0, 32, 0> )
	candidates.append( origin + <0, -32, 0> )
	candidates.append( origin + <32, 32, 0> )
	candidates.append( origin + <32, -32, 0> )
	candidates.append( origin + <-32, 32, 0> )
	candidates.append( origin + <-32, -32, 0> )

	foreach ( vector cand in candidates )
	{
		TraceResults clear = TraceHull( cand, cand, mins, maxs, ignore, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )
		if ( clear.startSolid )
			continue

		TraceResults ground = TraceHull( cand, cand - <0, 0, 96.0>, mins, maxs, ignore, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )
		if ( ground.startSolid || ground.fraction >= 1.0 )
			continue
		if ( ( cand.z - ground.endPos.z ) > 48.0 )
			continue

		if ( Distance( ground.endPos, origin ) > 1.0 )
			printt( "[FS-1V1] teleport snap " + string( origin ) + " -> " + string( ground.endPos ) )
		return ground.endPos
	}

	return origin
}

void function Gamemode1v1_TeleportPlayer( entity player, LocPair data )
{
	if( !IsValid( player ) )
		return

	vector angles = Gamemode1v1_NormalizeAngles( data.angles )
	vector dest = Gamemode1v1_SnapTeleportOrigin( player, data.origin )

	player.SetVelocity( Vector( 0,0,0 ) )
	player.SettleStance()
	player.SetOrigin( dest )
	player.SetAngles( angles )
	player.SetVelocity( Vector( 0,0,0 ) )
	player.PlantOnGround()

	player.SnapEyeAngles( angles )
	player.SnapFeetToEyes()
}

LocPairData function Init_DropoffPatchSpawns()
{
	array<LocPair> dropoff_patch =
	[
			//removed skyroom
			//NewLocPair( <-1378.05, 559.458, 1026.54 >, < 359.695, 307.314, 0 >),//13
			//NewLocPair( <-1469.03, -117.677, 1026.54 >, < 1.34318, 60.0746, 0 >),

			NewLocPair( < -2824.9, 2868.1, -111.969 >, < 0.354577, 31.8209, 0 >), //13
			NewLocPair( < -2541.81, 3919.45, -111.969 >, < 358.65, 315.899, 0 >),

			NewLocPair( < -2958.52, 183.899, 190.063 >, < 0.905181, 353.701, 0 >),//14
			NewLocPair( < -1693.05, -663.034, 190.063 >, < 0.514909, 140.627, 0 >),

			NewLocPair( <2544.54, 3934.15, -111.969 >, < 3.3168, 218.85, 0>), //15
			NewLocPair( <3196.49, 3010.24, -111.969 >, < 1.33276, 134.094, 0>),

			NewLocPair( < 2551.65, 515.938, 193.337 >, < 0.894581, 215.161, 0>), //16
			NewLocPair( <1637.37, -808.877, 193.67 >, < 0.0671947, 36.8544, 0>)
	]

	return SpawnSystem_CreateLocPairObject( dropoff_patch )
}

void function SetIsUsedBoolForRealmSlot( int realmID, bool usedState )
{
	try
	{
		// Realm 0 is the lobby every idle player shares; it is never claimed or released.
		if ( !realmID ) { return }
		file.realmSlots[ realmID ] = usedState

		if ( !usedState )
			file.realmExhaustedLogged = false
	}
	catch(e)
	{
		#if DEVELOPER
			sqprint("SetIsUsedBoolForRealmSlot crash " + e )
		#endif
	}
}

// Per-group boundary monitor - checks every 0.5s
// Monitors if players stray too far from fight center and applies damage
void function StartFightBoundaryMonitor( MatchGroup group )
{
	entity player1 = group.player1
	entity player2 = group.player2

	if ( !IsValid( player1 ) || !IsValid( player2 ) )
	{
		group.boundaryMonitorRunning = false
		return
	}

	// Use either player for EndSignal - both will be signaled on match end
	player1.EndSignal( "OnDestroy" )
	player1.EndSignal( "GroupFinished" )

	// EndSignal unwinds past the tail of this function, so the run flag has to be
	// cleared here or the group can never start another monitor.
	OnThreadEnd(
		function() : ( group )
		{
			group.boundaryMonitorRunning = false
		}
	)

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[BOUNDARY DEBUG] Starting fight boundary monitor for group %d (%s vs %s)",
				group.groupHandle, player1.GetPlayerName(), player2.GetPlayerName()) )
	#endif

	float CHECK_INTERVAL = 0.5 // 2 Hz instead of 60 Hz

	while ( true )
	{
		wait CHECK_INTERVAL

		// Validate group still exists and is active
		if ( !Gamemode1v1_IsMatchValid( group ) )
			break

		if ( group.IsFinished )
			break

		// Get current group data (may have changed)
		LocationsData groupLocStruct = group.groupLocStruct
		vector Center = groupLocStruct.Center
		array<entity> players = [ group.player1, group.player2 ]

		foreach ( eachPlayer in players )
		{
			if ( !IsValid( eachPlayer ) )
				continue

			if ( eachPlayer.IsPhaseShifted() )
				continue

			// Check if player is too far from fight center
			if ( Distance2D( eachPlayer.GetOrigin(), Center ) > settings.playerMaxFightDistance )
			{
				#if DEVELOPER
					printw( format("[BOUNDARY DEBUG] Player %s exceeded fight boundary - applying damage", eachPlayer.GetPlayerName()) )
				#endif

				// No attacker entity -- use NoAttacker remote (arg7 of PlayerTookDamage is entity).
				if ( FS_1v1_PlayerHasClient( eachPlayer ) )
					Remote_CallFunction_Replay( eachPlayer, "ServerCallback_PlayerTookDamage_NoAttacker", 1.0, <0, 0, 0>, DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, eDamageSourceId.deathField )
				eachPlayer.TakeDamage( 1, null, null, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
			}
		}
	}

	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( format("[BOUNDARY DEBUG] Fight boundary monitor ended for group %d", group.groupHandle) )
	#endif
}

const float WAITING_ROOM_FALL_LIMIT = 1500.0

// Waiting room boundary monitor - checks all non-fighting players every 0.5s
// Teleports players back if they stray too far from waiting room
void function StartWaitingRoomBoundaryMonitor( LocPair waitingRoomLocation )
{
	#if DEVELOPER
		if ( file.DEBUG_MATCHMAKING )
			printw( "[BOUNDARY DEBUG] Starting waiting room boundary monitor" )
	#endif

	float CHECK_INTERVAL = 0.5 // 2 Hz instead of 60 Hz

	// The gun sweep costs four weapon-slot natives per player. At 120 connected
	// that is ~960 a second at boundary cadence, for a state that changes on
	// spawn and loadout events -- run it every fourth pass instead.
	const int LOADOUT_SWEEP_EVERY = 4
	int pass = 0

	while ( true )
	{
		wait CHECK_INTERVAL

		pass++
		bool sweepLoadouts = ( pass % LOADOUT_SWEEP_EVERY ) == 0

		foreach ( player in GetPlayerArray() )
		{
			if ( !IsValid( player ) )
				continue

			if ( IsPlayerInSoloMode( player ) )
				continue

			int st = Gamemode1v1_GetPlayerGamestate( player )
			if ( st == e1v1State.IN_MATCH || st == e1v1State.SEQUENCE || st == e1v1State.PREMATCH || st == e1v1State.MATCH_START )
				continue

			if ( sweepLoadouts && FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( player ) ) && FS_1v1_LobbyHasGuns( player ) )
				FS_1v1_ApplyLobbyLoadout( player )

			// Skip noclip players (spectators/admins)
			if ( player.GetPhysics() == MOVETYPE_NOCLIP )
				continue

			// Distance2D alone lets a player fall out of the world unchecked, and the map
			// triggers that used to catch that are off in this mode.
			bool strayedFlat = Distance2D( player.GetOrigin(), waitingRoomLocation.origin ) > file.waitingRoomRadius
			bool fellBelow = ( waitingRoomLocation.origin.z - player.GetOrigin().z ) > WAITING_ROOM_FALL_LIMIT

			if ( strayedFlat || fellBelow )
			{
				#if DEVELOPER
					printw( format("[BOUNDARY DEBUG] Player %s exceeded waiting room boundary - teleporting back", player.GetPlayerName()) )
				#endif

				Gamemode1v1_TeleportPlayer( player, FS_1v1_PickWaitingRoomLoc() )
			}
		}
	}
}

bool function ValidateSpawns( array<SpawnData> allSoloLocations )
{
	string warningmsg = "Incorrectly configured spawns in " + FILE_NAME()

	if( allSoloLocations.len() == 0 )
	{
		Warning( "No valid spawns found! Trying default pak" )
		return false
	}

	if( g_bIs1v1GameType() && !IsEven( allSoloLocations.len() ) )
	{
		Warning( warningmsg + " ( locpair must be an even amount )" )
		allSoloLocations.resize(0)
		return false
	}
	else if( settings.isScenariosMode ) //(scenarios)
	{
		int modeTeamCount = FS_Scenarios_GetScenariosTeamCount()
		if( ( allSoloLocations.len() % modeTeamCount ) != 0 )
		{
			Warning( warningmsg + " ( locpair must be multiples of " + modeTeamCount + " )" )
			allSoloLocations.resize(0)
			return false
		}
	}

	return true
}

void function destroyRingsForGroup( MatchGroup group )
{
	if( !IsValid( group.ring ) )
		return

	group.ring.Destroy()
}

// Slots free right now. The mask is an i64 with bit 0 as the lobby, so there are
// exactly MAX_REALM duel slots and 120 players run 60 of them at once.
int function FS_1v1_CountFreeRealmSlots()
{
	int free = 0
	for( int slot = 1; slot < file.realmSlots.len(); slot++ )
	{
		if( !file.realmSlots[ slot ] )
			free++
	}
	return free
}

// Occupancy must track the live group count exactly. Drift is a leak, and at 60
// concurrent duels the pool is three slots from refusing every future pairing.
void function FS_1v1_AuditRealmSlots( string where )
{
	// Occupancy accounting is a diagnostic: off unless someone is hunting a leak.
	if( !GetCurrentPlaylistVarBool( "fs_1v1_realm_diag", false ) )
		return

	int free = FS_1v1_CountFreeRealmSlots()
	int used = MAX_REALM - free
	int groups = file.activeMatches.len()

	if( used != groups )
		Warning( "[FS-1V1][REALM-DRIFT] " + where + " used=" + string( used ) + " groups=" + string( groups ) + " free=" + string( free ) )

	if( free <= FS_1V1_REALM_LOW_WATERMARK && Time() >= file.realmLowNextLog )
	{
		file.realmLowNextLog = Time() + 10.0
		Warning( "[FS-1V1][REALM-LOW] free=" + string( free ) + " groups=" + string( groups ) )
	}
}

// A spectator borrows the realm of the duel it is watching. That slot is reissued
// the moment the duel ends, so the borrow has to be tracked and revoked.
void function FS_1v1_TrackSpectatorRealm( entity player, int realmIndex )
{
	if( !IsValid( player ) || realmIndex < 1 )
		return

	file.spectatorRealm[ player.p.handle ] <- realmIndex
}

void function FS_1v1_ForgetSpectatorRealm( entity player )
{
	if( !IsValid( player ) )
		return

	if( player.p.handle in file.spectatorRealm )
		delete file.spectatorRealm[ player.p.handle ]
}

void function FS_1v1_EvictSpectatorsFromRealm( int realmIndex )
{
	if( realmIndex < 1 )
		return

	array<int> evicting
	foreach( handle, slot in file.spectatorRealm )
	{
		if( slot == realmIndex )
			evicting.append( handle )
	}

	// Deferred: endSpectate deletes out of the table being walked.
	foreach( int handle in evicting )
	{
		entity spectator = GetEntityFromEncodedEHandle( handle )
		if( IsValid( spectator ) && spectator.IsPlayer() )
			endSpectate( spectator )
		else
			delete file.spectatorRealm[ handle ]
	}
}

int function Gamemode1v1_GetFreeRealmSlot()
{
	for( int slot = 1; slot < file.realmSlots.len(); slot++ )
	{
		if( !file.realmSlots[ slot ] )
		{
			SetIsUsedBoolForRealmSlot( slot, true )
			FS_1v1_AuditRealmSlots( "claim" )
			return slot
		}
	}

	// Every duel slot is taken: no pairing can succeed until one is released.
	if( !file.realmExhaustedLogged )
	{
		file.realmExhaustedLogged = true
		Warning( "[FS-1V1][REALM-EXHAUSTED] all " + string( MAX_REALM ) + " duel slots held, groups=" + string( file.activeMatches.len() ) )
		foreach( groupHandle, group in file.activeMatches )
			Warning( "[FS-1V1][REALM-EXHAUSTED] group=" + string( groupHandle ) + " slot=" + string( group.slotIndex ) )
	}

	return -1
}

int function FS_1v1_PickAndLogSpawnGroup( entity player1, entity player2 )
{
	int selectedIndex = GetSpawnGroupIndexForPlayers( player1, player2 )
	if ( selectedIndex < 0 && arenaLocations.len() > 0 )
		selectedIndex = RandomInt( arenaLocations.len() )

	if ( selectedIndex >= 0 )
	{
		string p1 = IsValid( player1 ) ? player1.GetPlayerName() : "?"
		string p2 = IsValid( player2 ) ? player2.GetPlayerName() : "?"
		printt( "[FS-1V1] spawn selected " + p1 + " vs " + p2 + " " + FS_1v1_SpawnPairDesc( selectedIndex ) )
	}

	return selectedIndex
}

// Get spawn group index that's different from both players' last used groups
// Returns: int (index into arenaLocations array)
int function GetSpawnGroupIndexForPlayers( entity player1, entity player2 )
{
	if( arenaLocations.len() == 0 )
		return -1

	// Build array of available group indices (excluding last used by either player)
	array<int> availableIndices = []

	int player1LastGroup = -1
	int player2LastGroup = -1

	if( player1.p.handle in file.playerLastSpawnGroup )
		player1LastGroup = file.playerLastSpawnGroup[ player1.p.handle ]

	if( player2.p.handle in file.playerLastSpawnGroup )
		player2LastGroup = file.playerLastSpawnGroup[ player2.p.handle ]

	for( int i = 0; i < arenaLocations.len(); i++ )
	{
		// Exclude if either player just used this group
		if( i != player1LastGroup && i != player2LastGroup )
			availableIndices.append( i )
	}

	// If we excluded everything (unlikely with >2 spawn groups), allow any spawn
	if( availableIndices.len() == 0 )
	{
		for( int i = 0; i < arenaLocations.len(); i++ )
			availableIndices.append( i )
	}

	return availableIndices.getrandom()
}

LocPair function Gamemode1v1_GetWaitingRoomLocation()
{
	return file.WaitingRoom
}

bool function FS_1v1_LobbyHasGuns( entity player )
{
	if ( !IsValid( player ) )
		return false
	if ( IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 ) ) )
		return true
	if ( IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 ) ) )
		return true
	if ( IsValid( player.GetOffhandWeapon( OFFHAND_TACTICAL ) ) )
		return true
	if ( IsValid( player.GetOffhandWeapon( OFFHAND_ULTIMATE ) ) )
		return true
	return false
}

void function FS_1v1_ApplyLobbyLoadout( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	if( !IsInvincible( player ) )
		MakeInvincible( player )

	TakeAllWeapons( player )
	FS_GiveRandomMelee( player, true )
	Survival_SetInventoryEnabled( player, false )
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_2 )
	player.DeployWeapon()
	player.Server_TurnOffhandWeaponsDisabledOn()
}

void function PlayerRestoreHP_1v1( entity player, float health, float shields )
{
	if( !IsValid( player ) )
	{
		return
	}

	if( !IsAlive( player ) )
	{
		return
	}

	// A shieldless mode is a real configuration, not a bad ref: strip the armor and
	// still restore health, which the ref-validity bail below would skip.
	if( shields <= 0 )
	{
		player.SetHealth( health )
		Inventory_SetPlayerEquipment( player, "", "armor" )
		return
	}

	string itemRef

	if( shields == 0 )
		itemRef = ""
	else if(shields <= 50)
		itemRef = "armor_pickup_lv1"
	else if(shields <= 75)
		itemRef = "armor_pickup_lv2"
	else if(shields <= 100)
		itemRef = "armor_pickup_lv3"
	else if(shields <= 125 )
		itemRef = "armor_pickup_lv5_evolving"

	if ( !SURVIVAL_Loot_IsRefValid( itemRef ) )
	{
		// Bailing here also skips SetHealth, so a bad ref costs the player their
		// armor and leaves health wherever the previous duel left it.
		Warning( "[FS-1V1] armor ref '" + itemRef + "' invalid for shields=" + string( shields )
			+ " -- no armor and no health restore for " + player.GetPlayerName() )
		return
	}

	LootData data = SURVIVAL_Loot_GetLootDataByRef( itemRef )
	int capacity = SURVIVAL_GetArmorShieldCapacity( data.tier )

	player.SetHealth( health )

	if( settings.enableHelmets )
		Inventory_SetPlayerEquipment(player, "helmet_pickup_lv3", "helmet")

	Inventory_SetPlayerEquipment( player, itemRef, "armor", capacity )

	if( shields != capacity )
	{
		player.SetShieldHealth( shields )
	}

	printt( "[FS-1V1] armor " + player.GetPlayerName() + " ref=" + itemRef
		+ " tier=" + string( data.tier ) + " capacity=" + string( capacity )
		+ " shields=" + string( shields )
		+ " equipped=" + Inventory_GetPlayerEquipment( player, "armor" ) )
}

void function Gamemode1v1_RespawnForMatch( entity player, int respawnSlotIndex = -1 ) //respawn dead player and their match opponent
{
	if ( !IsValid( player ) )
		return

	if ( !player.p.isConnected )
		return

	if ( FS_1v1_PlayerHasClient( player ) )
		Remote_CallFunction_ByRef( player, "ForceScoreboardLoseFocus" )

	//(cafe) new
   	if( Gamemode1v1_IsPlayerResting( player ) ) //should be a spectator, or a player that was waiting
	{
		if( !IsAlive( player ) )
		{
			Gamemode1v1_ForcePilotRespawn( player )

			FS_1v1_ApplyPlayerCamo( player )

			if( !IsInvincible(player ) )
				MakeInvincible(player)
		}

		if( !Gamemode1v1_IsPlayerInState( player, e1v1State.RESTING ) ) // if it's from waiting don't teleport it again, player is already in the room
			Gamemode1v1_TeleportPlayer( player, FS_1v1_PickWaitingRoomLoc() )

		FS_ClearRealmsAndAddPlayerToAllRealms( player )

		FS_1v1_ApplyLobbyLoadout( player )
		return
	}

	if ( respawnSlotIndex == -1 )
	{
		return
	}

	player.EndSignal( "OnDestroy", "OnDisconnecting" )

	// Mark player as being set up for a match
	Gamemode1v1_SetPlayerGamestate( player, e1v1State.SEQUENCE )

	// Show "Match found!" directly (bypasses signal bottleneck for same-frame clear+create)
	DirectClearAllPanels( player )
	DirectShowPanel( player, eNotify.MATCH_FOUND, "#FS_MATCH_FOUND" )

	float matchFoundDelay = settings.matchFoundDelay
	if ( matchFoundDelay > 0.0 )
		wait matchFoundDelay

	if ( !IsValid( player ) )
		return

	// Guard: if state was changed during wait (round end -> RECAP, rest -> RESTING, etc.), abort
	int currentState = Gamemode1v1_GetPlayerGamestate( player )
	if ( currentState != e1v1State.SEQUENCE && currentState != e1v1State.IN_MATCH )
		return

	DirectClearPanel( player, eNotify.MATCH_FOUND )

	// Validate match group still exists
	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	if( !Gamemode1v1_IsMatchValid( group ) || group.IsFinished )
	{
		#if DEVELOPER
			sqerror("group was invalid or finished after match found delay, err 007")
		#endif
		return
	}

	// Re-set SEQUENCE so spawn callback skips waiting-room teleport
	Gamemode1v1_SetPlayerGamestate( player, e1v1State.SEQUENCE )

	// Alive players just get teleported/stripped; only dead players respawn.
	if( !IsAlive( player ) )
		Gamemode1v1_ForcePilotRespawn( player )

	LocationsData groupLocStruct = group.groupLocStruct
	if( respawnSlotIndex < 0 || respawnSlotIndex >= groupLocStruct.respawnLocations.len() )
	{
		printt( "[FS-1V1] RespawnForMatch bad spawn slot " + string( respawnSlotIndex ) )
		return
	}

	// Re-lock before pad entry (matchmaking already locked; covers challenge rematch)
	FS_SetRealmForPlayer( player, group.slotIndex )

	Gamemode1v1_TeleportPlayer( player, groupLocStruct.respawnLocations[ respawnSlotIndex ] )
	player.UnfreezeControlsOnServer()

	// Face the player toward enemy spawn position (head height)
	int opponentSlotIndex = respawnSlotIndex == 0 ? 1 : 0
	if( opponentSlotIndex < groupLocStruct.respawnLocations.len() )
	{
		vector enemyOrigin = groupLocStruct.respawnLocations[ opponentSlotIndex ].origin + <0, 0, 68>
		vector playerOrigin = player.GetOrigin()
		vector dirToEnemy = Normalize( enemyOrigin - playerOrigin )
		vector faceAngles = Gamemode1v1_NormalizeAngles( VectorToAngles( dirToEnemy ) )
		player.SetAngles( faceAngles )
		player.SnapEyeAngles( faceAngles )
	}

	wait RESPAWN_DELAY_1V1

	if( !IsValid( player ) )
		return

	// Validate match still exists after the wait
	if( !Gamemode1v1_IsMatchValid( group ) || group.IsFinished )
		return

	// Match officially starts now - set startTime and start boundary damage
	// Only one player thread (slot 0) sets startTime and starts boundary monitor to avoid duplicates
	if ( respawnSlotIndex == 0 )
	{
		group.startTime = Time()

		// A challenge respawns both players every round and always hands slot 0 to
		// one of them, so an unguarded start stacks one live monitor per round.
		if ( !group.boundaryMonitorRunning )
		{
			group.boundaryMonitorRunning = true
			thread StartFightBoundaryMonitor( group )
		}
	}

	ClearInvincible( player )
	player.SetAimAssistAllowed( true )

	if( Equipment_GetDefaultShieldHP() > 0 && !Flowstate_IsLGDuels() )
	{
		PlayerRestoreHP_1v1( player, 100, Equipment_GetDefaultShieldHP() )
	}
	else
	{
		PlayerRestoreHP_1v1( player, 100, 0 )
		Inventory_SetPlayerEquipment( player, "", "armor" )
	}

	if( bIsCoachingMode() )
	{
		FS_Coaching_StartRecording( player )
	}
}
