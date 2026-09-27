// Flowstate Scenarios server: group lifecycle, team forming, player routing.
// The fs_1v1 shell owns the waiting room, queue table, rest list, realm pool and
// round loop; this file owns the fights.

global function FS_Scenarios_Init
global function FS_Scenarios_OnEntitiesDidLoad
global function FS_Scenarios_PrepareForLobby
global function FS_Scenarios_ForceRest
global function FS_Scenarios_FormGroups
global function FS_Scenarios_OnPlayerKilled
global function FS_Scenarios_ShouldBlockDamage
global function FS_Scenarios_ForceAllGroupsToFinish
global function FS_Scenarios_GetGroupCount
global function FS_Scenarios_GetScenariosTeamCount
global function FS_Scenarios_GetPlayersPerTeam
global function FS_Scenarios_GetGroupForPlayer
global function FS_Scenarios_IsPlayerInGroup
global function FS_Scenarios_GetAlivePlayersOfTeam
global function FS_Scenarios_GetGroupMembers
global function FS_Scenarios_GetGroupHandleOfPlayer
global function FS_Scenarios_Hud_SendPhase
global function FS_Scenarios_SweepRealm
global function FS_Scenarios_IsCarriedByPlayer

global enum eScenariosPhase
{
	FORMED,
	CHARSELECT,
	DROP,
	LIVE,
	ENDING,
	RETIRED
}

global struct ScenariosTeam
{
	array<entity> players
	int team = TEAM_INVALID
	int customTeamID = -1
}

global struct ScenariosGroup
{
	int groupHandle = -1
	entity dummyEnt
	array<ScenariosTeam> teams
	int locIndex = -1
	int slotIndex = -1
	vector center
	float ringRadius
	int phase = eScenariosPhase.FORMED
	float liveStartTime
	float ringStartTime
	float ringCloseTime
	bool isValid = false
	bool forced = false
	bool lastOfRound = false
	array<entity> spawnedEnts
}

const float SCENARIOS_MATCH_FOUND_DELAY = 1.5
const float SCENARIOS_VICTORY_HOLD = 5.0
const float SCENARIOS_DEATH_TRANSFER_TIME = 3.0
const float SCENARIOS_REST_CONFIRM_WINDOW = 5.0
const float SCENARIOS_OVERTIME = 30.0
const float SCENARIOS_SPAWN_CIRCLE_RADIUS = 30.0
const float SCENARIOS_KNOCK_STREAK_WINDOW = 6.0

struct ScenariosKnockStreak
{
	int count
	float lastTime
}

struct
{
	table<int, ScenariosGroup> groups
	table<int, ScenariosGroup> playerGroup
	table<int, int> queuePriority
	table<int, float> restConfirmUntil
	table<int, ScenariosKnockStreak> knockStreaks
	array<bool> teamSlotUsed
	int lobbyTeam
	table<entity, int> soloLobbyTeam
	int firstFightTeam
	int nextGroupHandle = 1
	entity signalEnt
	bool forceTimerArmed = false
	float forceTimerWakeAt = -1.0

	int playersPerTeam
	int teamAmount
	float maxQueueTime
	float maxQueueTimeLow
	int lowPlayerThreshold
	int minPlayersForcedMatch
	bool forceGameEnabled
	bool deathboxesEnabled
	bool inventoryEmpty
	bool charSelectEnabled
	float startDelay
	int stoppedRound = -1
	table<entity, bool> toldRoundEnd
} file

//////////////////////////////////////////////////////////////////////////////
// Init

void function FS_Scenarios_Init()
{
	// max_team_size also sizes the client squad HUD, so it is the one source for squad size.
	file.playersPerTeam = ClampInt( GetCurrentPlaylistVarInt( "max_team_size", 2 ), 1, SCENARIOS_MAX_ALLOWED_TEAMSIZE )
	file.teamAmount = ClampInt( GetCurrentPlaylistVarInt( "fs_scenarios_teamAmount", 3 ), 2, SCENARIOS_MAX_ALLOWED_TEAMSIZE )

	// Spawn set N holds locations for N + 1 teams.
	AddCallback_SpawnsSettings( void function() : ()
	{
		SpawnSystem_SetPreferredPak( file.teamAmount - 1 )
	} )
	file.maxQueueTime = GetCurrentPlaylistVarFloat( "fs_scenarios_max_queuetime", 12.0 )
	file.maxQueueTimeLow = GetCurrentPlaylistVarFloat( "fs_scenarios_max_queuetime_low", 8.0 )
	file.lowPlayerThreshold = GetCurrentPlaylistVarInt( "fs_scenarios_low_player_threshold", file.playersPerTeam * file.teamAmount )
	file.minPlayersForcedMatch = maxint( 2, GetCurrentPlaylistVarInt( "fs_scenarios_min_players_forced_match", 2 ) )
	file.forceGameEnabled = GetCurrentPlaylistVarBool( "fs_scenarios_forcegame_enabled", true )
	file.deathboxesEnabled = GetCurrentPlaylistVarBool( "fs_scenarios_deathboxes_enabled", true )
	file.inventoryEmpty = GetCurrentPlaylistVarBool( "fs_scenarios_inventory_empty", true )
	file.charSelectEnabled = GetCurrentPlaylistVarBool( "fs_scenarios_characterselect_enabled", true )
	file.startDelay = GetCurrentPlaylistVarFloat( "fs_scenarios_game_start_time_delay", 3.0 )

	RegisterSignal( "FS_Scenarios_GroupEnding" )
	RegisterSignal( "FS_Scenarios_GroupEnd" )
	RegisterSignal( "FS_Scenarios_ForceTimerReset" )

	// Everyone waiting shares one team so the waiting room never counts as a fight.
	// Fight teams come from the rest of the playlist's team range.
	file.lobbyTeam = TEAM_IMC
	file.firstFightTeam = TEAM_MULTITEAM_FIRST
	int maxTeams = GetCurrentPlaylistVarInt( "max_teams", 120 )
	file.teamSlotUsed.resize( TEAM_MULTITEAM_FIRST + maxTeams, false )
	for ( int t = 0; t < file.firstFightTeam; t++ )
		file.teamSlotUsed[ t ] = true
	if ( file.lobbyTeam < file.teamSlotUsed.len() )
		file.teamSlotUsed[ file.lobbyTeam ] = true

	// Knockdowns, ultimate charge, death boxes and freefall: survival's server init
	// owns these and fs_1v1 never runs it.
	Bleedout_Init()
	Ultimates_Init()
	SURVIVAL_Loot_InitServer()
	SurvivalFreefall_Init()

	AddCallback_OnClientConnected( FS_Scenarios_OnClientConnected )
	AddCallback_OnClientDisconnected( FS_Scenarios_OnPlayerDisconnected )
	Bleedout_AddCallback_OnPlayerStartBleedout( FS_Scenarios_OnPlayerKnocked )
	AddClientCommandCallback( "rest", ClientCommand_FS_Scenarios_Rest )
	AddClientCommandCallback( "scenarios_standings", ClientCommand_FS_Scenarios_Standings )
	AddClientCommandCallback( "scenarios_realm_audit", ClientCommand_FS_Scenarios_RealmAudit )

	FS_Scenarios_Spawns_Init()
	FS_Scenarios_Ring_Init()
	FS_Scenarios_Loot_Init()
	FS_Scenarios_Score_Init()
	FS_Scenarios_CharSelect_Init()
	FS_Scenarios_Teams_Init()

}

void function FS_Scenarios_OnEntitiesDidLoad()
{
	file.signalEnt = CreateEntity( "info_target" )
	DispatchSpawn( file.signalEnt )

	FS_Scenarios_Loot_OnEntitiesDidLoad()
	FS_Scenarios_EnableMapHazards()
}

// The shell switches off the map's volumes because its duels sit in sealed arenas.
// Fights here use the real map: hazards hurt, geysers launch, slides and the
// no-zipline / no-grapple areas apply. Out-of-bounds and kill volumes stay off,
// since waiting players are parked outside the play space; they are also exempt
// from world damage.
void function FS_Scenarios_EnableMapHazards()
{
	int enabled = 0
	array<entity> triggers
	if ( GetCurrentPlaylistVarBool( "fs_scenarios_map_hazards", true ) )
		triggers.extend( GetEntArrayByClass_Expensive( "trigger_hurt" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_slip" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_no_zipline" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_no_grapple" ) )
	foreach ( entity pad in GetEntArrayByClass_Expensive( "trigger_cylinder_heavy" ) )
	{
		if ( IsValid( pad ) && pad.GetTargetName() == "geyser_trigger" )
			triggers.append( pad )
	}

	foreach ( entity trigger in triggers )
	{
		if ( !IsValid( trigger ) )
			continue
		trigger.Enable()
		enabled++
	}
}

void function FS_Scenarios_OnClientConnected( entity player )
{
	if ( !IsValid( player ) )
		return

	FS_Scenarios_SetLobbyTeam( player )
	player.SetPlayerNetInt( "FS_Scenarios_EnemiesAlive", -1 )
	player.SetPlayerNetTime( "FS_Scenarios_RingCloseTime", -1 )
}

int function FS_Scenarios_GetScenariosTeamCount()
{
	return file.teamAmount
}

int function FS_Scenarios_GetPlayersPerTeam()
{
	return file.playersPerTeam
}

int function FS_Scenarios_GetGroupCount()
{
	return file.groups.len()
}

//////////////////////////////////////////////////////////////////////////////
// Group lookup

ScenariosGroup ornull function FS_Scenarios_GetGroupForPlayer( entity player )
{
	if ( !IsValid( player ) )
		return null

	int handle = player.p.handle
	if ( !( handle in file.playerGroup ) )
		return null

	ScenariosGroup group = file.playerGroup[ handle ]
	if ( !group.isValid )
		return null

	return group
}

bool function FS_Scenarios_IsPlayerInGroup( entity player )
{
	return FS_Scenarios_GetGroupForPlayer( player ) != null
}

// Group handles are never reused, so they identify a fight across its lifetime.
int function FS_Scenarios_GetGroupHandleOfPlayer( entity player )
{
	ScenariosGroup ornull group = FS_Scenarios_GetGroupForPlayer( player )
	if ( group == null )
		return -1
	return expect ScenariosGroup( group ).groupHandle
}

array<entity> function FS_Scenarios_GetGroupMembers( ScenariosGroup group )
{
	array<entity> members
	foreach ( ScenariosTeam team in group.teams )
	{
		foreach ( entity player in team.players )
		{
			if ( IsValid( player ) )
				members.append( player )
		}
	}
	return members
}

array<entity> function FS_Scenarios_GetAlivePlayersOfTeam( ScenariosTeam team )
{
	array<entity> alive
	foreach ( entity player in team.players )
	{
		if ( IsValid( player ) && IsAlive( player ) )
			alive.append( player )
	}
	return alive
}

ScenariosTeam ornull function FS_Scenarios_GetTeamOfPlayer( ScenariosGroup group, entity player )
{
	foreach ( ScenariosTeam team in group.teams )
	{
		if ( team.players.contains( player ) )
			return team
	}
	return null
}

//////////////////////////////////////////////////////////////////////////////
// Team slots

int function FS_Scenarios_ClaimTeamSlot()
{
	for ( int t = file.firstFightTeam; t < file.teamSlotUsed.len(); t++ )
	{
		if ( !file.teamSlotUsed[ t ] )
		{
			file.teamSlotUsed[ t ] = true
			return t
		}
	}
	return TEAM_INVALID
}

// Waiting players get a team of their own so the squad HUD never shows the lobby
// as one squad. A reserve stays free for the fights the next matchmaking pass forms.
void function FS_Scenarios_SetLobbyTeam( entity player )
{
	FS_Scenarios_ClearPickLock( player )

	if ( player in file.soloLobbyTeam )
	{
		SetTeam( player, file.soloLobbyTeam[ player ] )
		return
	}

	int free = 0
	for ( int t = file.firstFightTeam; t < file.teamSlotUsed.len(); t++ )
	{
		if ( !file.teamSlotUsed[ t ] )
			free++
	}

	int team = free > file.teamAmount * 4 ? FS_Scenarios_ClaimTeamSlot() : TEAM_INVALID
	if ( team == TEAM_INVALID )
	{
		SetTeam( player, file.lobbyTeam )
		return
	}

	file.soloLobbyTeam[ player ] <- team
	SetTeam( player, team )
}

void function FS_Scenarios_ReleaseLobbyTeam( entity player )
{
	if ( !( player in file.soloLobbyTeam ) )
		return

	FS_Scenarios_ReleaseTeamSlot( file.soloLobbyTeam[ player ] )
	delete file.soloLobbyTeam[ player ]
}

void function FS_Scenarios_ReleaseTeamSlot( int team )
{
	if ( team < file.firstFightTeam || team >= file.teamSlotUsed.len() || team == file.lobbyTeam )
		return
	file.teamSlotUsed[ team ] = false
}

//////////////////////////////////////////////////////////////////////////////
// Team forming. Runs inside the shell's matchmaking worker, which already holds
// the trigger through the round transition.

void function FS_Scenarios_FormGroups()
{
	if ( FS_Scenarios_MatchmakingStopped() )
	{
		FS_Scenarios_TellWaitingForRoundEnd()
		return
	}

	int fullGroup = file.playersPerTeam * file.teamAmount

	for ( int pass = 0; pass < MAX_REALM; pass++ )
	{
		array<entity> eligible = FS_Scenarios_GetEligibleQueuedPlayers()
		if ( eligible.len() < 2 )
			return

		bool forced = false
		if ( eligible.len() < fullGroup )
		{
			if ( !file.forceGameEnabled || eligible.len() < file.minPlayersForcedMatch || !FS_Scenarios_AllQueuedPastDeadline( eligible ) )
			{
				FS_Scenarios_ArmForceTimer( eligible )
				return
			}
			forced = true
		}

		if ( !FS_Scenarios_TryFormGroup( eligible, forced ) )
			return

		WaitFrame()
	}
}

// A fight never gets cut by the round clock: one that would outlast it pushes
// the round end out instead and closes matchmaking until the next round.
bool function FS_Scenarios_MatchmakingStopped()
{
	return file.stoppedRound == GetGlobalNetInt( "FSDM_CurrentRound" )
}

void function FS_Scenarios_ExtendRoundFor( ScenariosGroup group )
{
	float roundEnd = GetGlobalNetTime( "flowstate_DMRoundEndTime" )
	if ( roundEnd <= 0 )
		return

	int pickCount = 0
	foreach ( ScenariosTeam team in group.teams )
		pickCount = maxint( pickCount, team.players.len() )

	float fightEnd = Time() + SCENARIOS_MATCH_FOUND_DELAY + file.startDelay + FS_Scenarios_Ring_MaxCloseTime() + SCENARIOS_OVERTIME + SCENARIOS_VICTORY_HOLD
	if ( file.charSelectEnabled )
		fightEnd += FS_Scenarios_CharSelect_Duration( pickCount )
	if ( fightEnd <= roundEnd )
		return

	SetGlobalNetTime( "flowstate_DMRoundEndTime", fightEnd )
	if ( !FS_Scenarios_MatchmakingStopped() )
	{
		file.stoppedRound = GetGlobalNetInt( "FSDM_CurrentRound" )
		file.toldRoundEnd.clear()
	}
	group.lastOfRound = true
}

void function FS_Scenarios_TellWaitingForRoundEnd()
{
	float left = GetGlobalNetTime( "flowstate_DMRoundEndTime" ) - Time()
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !FS_1v1_PlayerHasClient( player ) || FS_Scenarios_IsPlayerInGroup( player ) || player in file.toldRoundEnd )
			continue
		file.toldRoundEnd[ player ] <- true
		LocalMsg( player, "#FS_Scenarios_WaitingForRoundEnd", "", eMsgUI.EVENT, max( 3.0, left ) )
	}
}

// Once the fight that held the round open is over, nothing else is waiting on it.
void function FS_Scenarios_CloseRoundAfter( ScenariosGroup group )
{
	if ( !group.lastOfRound || !FS_Scenarios_MatchmakingStopped() )
		return
	float roundEnd = GetGlobalNetTime( "flowstate_DMRoundEndTime" )
	float cut = Time() + SCENARIOS_VICTORY_HOLD
	if ( cut < roundEnd )
		SetGlobalNetTime( "flowstate_DMRoundEndTime", cut )
}

array<entity> function FS_Scenarios_GetEligibleQueuedPlayers()
{
	array<entity> eligible
	foreach ( int handle, QueuedPlayer queued in FS_1v1_GetPlayersWaiting() )
	{
		entity player = queued.player
		if ( !IsValidPlayer( player ) || !IsAlive( player ) )
			continue
		if ( player.IsBot() && GetCurrentPlaylistVarBool( "fs_1v1_skip_bots", false ) )
			continue
		if ( FS_Scenarios_IsWaitingForTeammates( player ) )
			continue
		eligible.append( player )
	}
	return eligible
}

float function FS_Scenarios_QueueDeadline()
{
	return GetPlayerArray().len() >= file.lowPlayerThreshold ? file.maxQueueTime : file.maxQueueTimeLow
}

float function FS_Scenarios_QueueEnterTime( entity player )
{
	table<int, QueuedPlayer> waiting = FS_1v1_GetPlayersWaiting()
	if ( player.p.handle in waiting )
		return waiting[ player.p.handle ].queue_time
	return Time()
}

bool function FS_Scenarios_AllQueuedPastDeadline( array<entity> eligible )
{
	float deadline = FS_Scenarios_QueueDeadline()
	foreach ( entity player in eligible )
	{
		if ( Time() - FS_Scenarios_QueueEnterTime( player ) < deadline )
			return false
	}
	return true
}

// The only queue event that is not a state transition: waiting out the deadline.
// One timer for the whole queue, re-armed on every pass.
void function FS_Scenarios_ArmForceTimer( array<entity> eligible )
{
	if ( !file.forceGameEnabled || eligible.len() < file.minPlayersForcedMatch )
		return

	float wakeAt = 0.0
	float deadline = FS_Scenarios_QueueDeadline()
	foreach ( entity player in eligible )
		wakeAt = max( wakeAt, FS_Scenarios_QueueEnterTime( player ) + deadline )

	if ( file.forceTimerArmed && fabs( file.forceTimerWakeAt - wakeAt ) < 0.05 )
		return

	file.forceTimerWakeAt = wakeAt
	thread FS_Scenarios_ForceTimer_THREAD( wakeAt )
}

void function FS_Scenarios_ForceTimer_THREAD( float wakeAt )
{
	if ( !IsValid( file.signalEnt ) )
		return

	Signal( file.signalEnt, "FS_Scenarios_ForceTimerReset" )
	file.signalEnt.EndSignal( "FS_Scenarios_ForceTimerReset" )
	file.signalEnt.EndSignal( "OnDestroy" )

	file.forceTimerArmed = true
	OnThreadEnd(
		function() : ()
		{
			file.forceTimerArmed = false
		}
	)

	float delay = wakeAt - Time() + 0.1
	if ( delay > 0 )
		wait delay

	thread TriggerMatchmaking()
}

int function FS_Scenarios_SortByPriority( entity a, entity b )
{
	int pa = a.p.handle in file.queuePriority ? file.queuePriority[ a.p.handle ] : 0
	int pb = b.p.handle in file.queuePriority ? file.queuePriority[ b.p.handle ] : 0
	if ( pa > pb )
		return -1
	if ( pa < pb )
		return 1
	return 0
}

int function FS_Scenarios_SortTeamsBySize( ScenariosTeam a, ScenariosTeam b )
{
	if ( a.players.len() < b.players.len() )
		return -1
	if ( a.players.len() > b.players.len() )
		return 1
	return 0
}

bool function FS_Scenarios_TryFormGroup( array<entity> eligible, bool forced )
{
	if ( arenaLocations.len() == 0 )
	{
		Warning( "[FS-SCN][MM] no locations on " + GetMapName() )
		return false
	}

	int slot = Gamemode1v1_GetFreeRealmSlot()
	if ( slot < 0 )
		return false

	// The playlist's team count is the mode; a short queue shrinks the squads,
	// never the number of squads (5 waiting for 2v2v2 plays 1v1v1).
	int teamCount = file.teamAmount
	int teamSize = minint( file.playersPerTeam, eligible.len() / teamCount )
	if ( teamSize < 1 )
		return false

	ScenariosGroup group
	group.groupHandle = file.nextGroupHandle++
	group.slotIndex = slot
	group.forced = forced

	for ( int i = 0; i < teamCount; i++ )
	{
		ScenariosTeam team
		team.team = FS_Scenarios_ClaimTeamSlot()
		if ( team.team == TEAM_INVALID )
		{
			Warning( "[FS-SCN][MM] team slots exhausted" )
			FS_Scenarios_ReleaseGroupSlots( group )
			return false
		}
		group.teams.append( team )
	}

	eligible.randomize()
	eligible.sort( FS_Scenarios_SortByPriority )

	array<entity> placed
	foreach ( entity player in eligible )
	{
		ScenariosTeam ornull target = FS_Scenarios_FindTeamForPlayer( group, player, teamSize )
		if ( target == null )
			continue

		expect ScenariosTeam( target )
		target.players.append( player )
		placed.append( player )
	}

	for ( int i = group.teams.len() - 1; i >= 0; i-- )
	{
		if ( group.teams[ i ].players.len() == 0 )
		{
			FS_Scenarios_ReleaseTeamSlot( group.teams[ i ].team )
			group.teams.remove( i )
		}
	}

	// A party can leave one team short; cut every team to the smallest so no
	// fight ever starts uneven. Players are placed in priority order, so the
	// last ones in are the ones sent back to the queue.
	int evenSize = teamSize
	foreach ( ScenariosTeam team in group.teams )
		evenSize = minint( evenSize, team.players.len() )
	foreach ( ScenariosTeam team in group.teams )
	{
		while ( team.players.len() > evenSize )
		{
			entity extra = team.players.pop()
			placed.fastremovebyvalue( extra )
		}
	}

	if ( group.teams.len() < teamCount || evenSize < 1 )
	{
		FS_Scenarios_ReleaseGroupSlots( group )
		return false
	}

	foreach ( entity player in eligible )
	{
		if ( placed.contains( player ) )
			continue
		int handle = player.p.handle
		file.queuePriority[ handle ] <- ( handle in file.queuePriority ? file.queuePriority[ handle ] : 0 ) + 1
	}

	// Anything still in the slot outlived its fight (a delayed explosion, a late spawn).
	FS_Scenarios_SweepRealm( group.slotIndex, "claim" )

	group.locIndex = RandomInt( arenaLocations.len() )
	LocationsData loc = arenaLocations[ group.locIndex ]
	group.center = loc.Center
	group.dummyEnt = CreateEntity( "info_target" )
	DispatchSpawn( group.dummyEnt )
	group.isValid = true

	file.groups[ group.groupHandle ] <- group
	FS_1v1_AuditRealmSlots( "scenarios-claim" )
	foreach ( entity player in placed )
	{
		FS_Scenarios_ResetLastFight( player )
		file.playerGroup[ player.p.handle ] <- group
		if ( player.p.handle in file.queuePriority )
			delete file.queuePriority[ player.p.handle ]
		Gamemode1v1_RemovePlayerFromWaitingList( player.p.handle )
		Gamemode1v1_RemovePlayerFromRestingList( player )
	}

	FS_Scenarios_ExtendRoundFor( group )

	thread FS_Scenarios_RunGroup_THREAD( group )
	return true
}

ScenariosTeam ornull function FS_Scenarios_FindTeamForPlayer( ScenariosGroup group, entity player, int teamSize )
{
	int customTeamID = FS_Scenarios_GetCustomTeamID( player )
	if ( customTeamID != -1 )
	{
		foreach ( ScenariosTeam team in group.teams )
		{
			if ( team.customTeamID == customTeamID && team.players.len() < teamSize )
				return team
		}
		foreach ( ScenariosTeam team in group.teams )
		{
			if ( team.customTeamID == -1 && team.players.len() == 0 )
			{
				team.customTeamID = customTeamID
				return team
			}
		}
		return null
	}

	array<ScenariosTeam> bySize = clone group.teams
	bySize.sort( FS_Scenarios_SortTeamsBySize )
	foreach ( ScenariosTeam team in bySize )
	{
		if ( team.players.len() >= teamSize )
			continue
		if ( team.customTeamID != -1 && !FS_Scenarios_CustomTeamAllowsRandomFill( team.customTeamID ) )
			continue
		return team
	}
	return null
}

void function FS_Scenarios_ReleaseGroupSlots( ScenariosGroup group )
{
	foreach ( ScenariosTeam team in group.teams )
		FS_Scenarios_ReleaseTeamSlot( team.team )

	if ( group.slotIndex > 0 )
	{
		FS_1v1_EvictSpectatorsFromRealm( group.slotIndex )
		SetIsUsedBoolForRealmSlot( group.slotIndex, false )
	}
}

//////////////////////////////////////////////////////////////////////////////
// Lifecycle

void function FS_Scenarios_RunGroup_THREAD( ScenariosGroup group )
{
	group.dummyEnt.EndSignal( "OnDestroy" )
	group.dummyEnt.EndSignal( "FS_Scenarios_GroupEnd" )

	OnThreadEnd(
		function() : ( group )
		{
			FS_Scenarios_RetireGroup( group )
		}
	)

	LocationsData loc = arenaLocations[ group.locIndex ]

	foreach ( int teamIndex, ScenariosTeam team in group.teams )
	{
		foreach ( entity player in team.players )
		{
			if ( !IsValid( player ) )
				continue

			Signal( player, "MatchFound" )
			if ( !IsAlive( player ) )
				Gamemode1v1_ForcePilotRespawn( player )

			FS_Scenarios_ReleaseLobbyTeam( player )
			FS_Scenarios_ClearPickLock( player )
			FS_Scenarios_StandUpKnocked( player )
			SetTeam( player, team.team )
			// the pick menu and squad HUD size themselves from this, not the playlist
			if ( FS_1v1_PlayerHasClient( player ) )
				Remote_CallFunction_NonReplay( player, "ServerCallback_FS_Scenarios_SquadSize", ClampInt( team.players.len(), 1, SCENARIOS_MAX_ALLOWED_TEAMSIZE ) )
			Gamemode1v1_SetPlayerGamestate( player, e1v1State.PREMATCH )
			if ( !IsInvincible( player ) )
				MakeInvincible( player )
			DirectClearAllPanels( player )
			DirectShowPanel( player, eNotify.MATCH_FOUND, "#FS_MATCH_FOUND" )
			LocalMsg( player, "#FS_MATCH_FOUND", "", eMsgUI.EVENT, SCENARIOS_MATCH_FOUND_DELAY + 1.0 )
		}
	}

	wait SCENARIOS_MATCH_FOUND_DELAY

	group.ringRadius = FS_Scenarios_Ring_RadiusForLocation( loc )

	table<entity, LocPair> fightSpawns
	foreach ( int teamIndex, ScenariosTeam team in group.teams )
	{
		int spawnIndex = teamIndex < loc.respawnLocations.len() ? teamIndex : RandomInt( loc.respawnLocations.len() )
		LocPair spawn = loc.respawnLocations[ spawnIndex ]

		foreach ( int i, entity player in team.players )
		{
			if ( !IsValid( player ) )
				continue

			LocPair dest = FS_Scenarios_SpawnForTeamMember( spawn, i, team.players.len() )
			fightSpawns[ player ] <- dest

			DirectClearPanel( player, eNotify.MATCH_FOUND )
			FS_SetRealmForPlayer( player, group.slotIndex )
			Gamemode1v1_TeleportPlayer( player, dest )
			FS_Scenarios_FaceLocation( player, group.center )
			HolsterAndDisableWeapons( player )
			player.MovementDisable()
			player.ForceStand()
		}
	}

	FS_Scenarios_PublishEnemiesAlive( group )
	FS_Scenarios_Hud_SendPhase( group, eScenariosHudPhase.PICK, Time(), -1.0, -1.0 )
	FS_Scenarios_Hud_SendRoster( group )

	if ( file.charSelectEnabled )
	{
		group.phase = eScenariosPhase.CHARSELECT
		waitthread FS_Scenarios_RunCharacterSelect( group )
	}
	else
	{
		FS_Scenarios_AssignTeamUniqueLegends( group )
	}

	group.phase = eScenariosPhase.DROP
	float liveStart = Time() + file.startDelay

	FS_Scenarios_Loot_SpawnForGroup( group )
	FS_Scenarios_Ring_Publish( group, liveStart )
	FS_Scenarios_Hud_SendPhase( group, eScenariosHudPhase.DROP, Time(), liveStart, -1.0 )

	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
	{
		Gamemode1v1_SetPlayerGamestate( player, e1v1State.SEQUENCE )
		FS_Scenarios_ApplyFightLoadout( player, group )

		// Applying the picked legend swaps the player's settings, which can move them.
		if ( player in fightSpawns )
		{
			LocPair dest = fightSpawns[ player ]
			float drift = Distance( player.GetOrigin(), dest.origin )
			Gamemode1v1_TeleportPlayer( player, dest )
			FS_Scenarios_FaceLocation( player, group.center )
		}

		LocalMsg( player, "#FS_Scenarios_GetReady", "", eMsgUI.EVENT, file.startDelay )
	}

	FS_Scenarios_EvaluateGroup( group )
	if ( group.phase != eScenariosPhase.DROP )
		return

	wait file.startDelay

	group.phase = eScenariosPhase.LIVE
	group.liveStartTime = Time()
	FS_Scenarios_Hud_SendPhase( group, eScenariosHudPhase.LIVE, group.ringStartTime, group.ringCloseTime, group.ringCloseTime + SCENARIOS_OVERTIME )

	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
	{
		Gamemode1v1_SetPlayerGamestate( player, e1v1State.IN_MATCH )
		// Invulnerability stacks; lobby and fight setup can each have added a hold.
		for ( int i = 0; i < 8 && IsInvincible( player ); i++ )
			ClearInvincible( player )
		player.SetTakeDamageType( DAMAGE_YES )
		player.MovementEnable()
		player.UnforceStand()
		FS_Scenarios_ReleaseWeaponHolds( player )
		if ( IsValid( player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 ) ) )
			player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		player.ClearFirstDeployForAllWeapons()
		LocalMsg( player, "#FS_Scenarios_Tip", "", eMsgUI.EVENT, 5 )
		DemoMoment_Send( player, eDemoMoment.FIGHT_START )
	}


	thread FS_Scenarios_Ring_Damage_THREAD( group )
	thread FS_Scenarios_Overtime_THREAD( group )

	FS_Scenarios_EvaluateGroup( group )

	if ( group.phase == eScenariosPhase.LIVE )
		WaitSignal( group.dummyEnt, "FS_Scenarios_GroupEnding" )

	wait SCENARIOS_VICTORY_HOLD
}

LocPair function FS_Scenarios_SpawnForTeamMember( LocPair teamSpawn, int memberIndex, int memberCount )
{
	if ( memberCount <= 1 )
		return teamSpawn

	float r = float( memberIndex ) / float( memberCount ) * 2.0 * PI
	vector candidate = teamSpawn.origin + SCENARIOS_SPAWN_CIRCLE_RADIUS * <sin( r ), cos( r ), 0.0>

	if ( !SpawnSystem_CheckSpawn( candidate + <0, 0, 8> ) )
		return teamSpawn

	return NewLocPair( candidate, teamSpawn.angles )
}

void function FS_Scenarios_FaceLocation( entity player, vector target )
{
	vector dir = FlattenVec( target - player.GetOrigin() )
	if ( LengthSqr( dir ) < 1.0 )
		return

	vector angles = <0, VectorToAngles( dir ).y, 0>
	player.SetAngles( angles )
	player.SnapEyeAngles( angles )
}

void function FS_Scenarios_ApplyFightLoadout( entity player, ScenariosGroup group )
{
	if ( !IsValid( player ) )
		return

	player.p.survivalLandedOnGround = true

	// The base kit strips every weapon, so the legend (tactical, ultimate, passives)
	// goes on after it.
	FS_1v1_GiveScenarioLoadout( player, false )
	if ( !file.inventoryEmpty )
		FS_Scenarios_Loot_GiveFightKit( player )
	FS_Scenarios_ApplyLegend( player )
	PlayerRestoreHP_1v1( player, 100, Equipment_GetDefaultShieldHP() )

	foreach ( string item in FS_Scenarios_GetStartingItems() )
		SURVIVAL_AddToPlayerInventory( player, item )
	SURVIVAL_AutoEquipOrdnanceFromInventory( player, false )

	string incap = GetCurrentPlaylistVarString( "fs_scenarios_incapshield", "incapshield_pickup_lv3" )
	if ( incap != "" && SURVIVAL_Loot_IsRefValid( incap ) )
		Inventory_SetPlayerEquipment( player, incap, "incapshield" )

	string backpack = GetCurrentPlaylistVarString( "fs_scenarios_backpack", "backpack_pickup_lv3" )
	if ( backpack != "" && SURVIVAL_Loot_IsRefValid( backpack ) )
		Inventory_SetPlayerEquipment( player, backpack, "backpack" )

	// The legend turns offhands back on; keep everything down until the fight is live.
	HolsterAndDisableWeapons_Raw( player )
}

//////////////////////////////////////////////////////////////////////////////
// Fight HUD. The client draws each chip from the player entity it is given;
// only the roster, the phase clock and eliminations come from here.

void function FS_Scenarios_Hud_SendPhaseTo( entity player, ScenariosGroup group, int phase, float t0, float t1, float t2 )
{
	if ( !FS_1v1_PlayerHasClient( player ) )
		return
	Remote_CallFunction_NonReplay( player, "ServerCallback_FS_Scenarios_HudPhase", phase, group.groupHandle, t0, t1, t2 )
}

void function FS_Scenarios_Hud_SendPhase( ScenariosGroup group, int phase, float t0, float t1, float t2 )
{
	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
		FS_Scenarios_Hud_SendPhaseTo( player, group, phase, t0, t1, t2 )
}

// Players travel as encoded handles: an entity arg arrives null once the player
// is out of the viewer's realm or dead. Each enemy carries its squad index among
// the viewer's opponents.
void function FS_Scenarios_Hud_SendRoster( ScenariosGroup group )
{
	int friendSlots = FS_SCENARIOS_HUD_FRIEND_SLOTS
	int enemySlots = FS_SCENARIOS_HUD_SLOTS - FS_SCENARIOS_HUD_FRIEND_SLOTS
	foreach ( ScenariosTeam team in group.teams )
	{
		foreach ( entity viewer in team.players )
		{
			if ( !FS_1v1_PlayerHasClient( viewer ) )
				continue

			array<entity> mine = [ viewer ]
			foreach ( entity p in team.players )
			{
				if ( IsValid( p ) && p != viewer )
					mine.append( p )
			}

			array<entity> theirs
			array<int> squadOf
			int squad = 0
			foreach ( ScenariosTeam other in group.teams )
			{
				if ( other.team == team.team )
					continue
				foreach ( entity p in other.players )
				{
					if ( IsValid( p ) )
					{
						theirs.append( p )
						squadOf.append( squad )
					}
				}
				squad++
			}

			for ( int k = 0; k < mine.len() && k < friendSlots; k++ )
				Remote_CallFunction_NonReplay( viewer, "ServerCallback_FS_Scenarios_HudSlot", k, mine[ k ].GetEncodedEHandle(), 0 )
			for ( int k = 0; k < theirs.len() && k < enemySlots; k++ )
				Remote_CallFunction_NonReplay( viewer, "ServerCallback_FS_Scenarios_HudSlot", friendSlots + k, theirs[ k ].GetEncodedEHandle(), squadOf[ k ] )
		}
	}
}

void function FS_Scenarios_Hud_SendOut( ScenariosGroup group, entity out )
{
	if ( !IsValid( out ) )
		return
	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
	{
		if ( FS_1v1_PlayerHasClient( player ) )
			Remote_CallFunction_NonReplay( player, "ServerCallback_FS_Scenarios_HudOut", out.GetEncodedEHandle() )
	}
}

// HolsterAndDisableWeapons is ref-counted; a fight must end with no holds left.
void function FS_Scenarios_ReleaseWeaponHolds( entity player )
{
	while ( player.p.holsterAndDisableWeaponCount > 0 )
		DeployAndEnableWeapons( player )
	if ( IsAlive( player ) )
		DeployAndEnableWeapons_Raw( player )
}

array<string> function FS_Scenarios_GetStartingItems()
{
	string raw = GetCurrentPlaylistVarString( "fs_scenarios_starting_items",
		"mp_weapon_frag_grenade health_pickup_combo_large health_pickup_combo_large health_pickup_combo_small health_pickup_combo_small health_pickup_health_large health_pickup_health_small health_pickup_health_small" )

	array<string> items
	foreach ( string ref in split( raw, " " ) )
	{
		string item = strip( ref )
		if ( item != "" && SURVIVAL_Loot_IsRefValid( item ) )
			items.append( item )
	}
	return items
}

// A fight ends at the ring's close plus overtime even if both teams hide.
void function FS_Scenarios_Overtime_THREAD( ScenariosGroup group )
{
	group.dummyEnt.EndSignal( "OnDestroy" )
	group.dummyEnt.EndSignal( "FS_Scenarios_GroupEnding" )

	float until = group.ringCloseTime + SCENARIOS_OVERTIME
	float warnAt = until - 30.0
	if ( warnAt > Time() )
	{
		wait warnAt - Time()
		foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
			LocalMsg( player, "#FS_Scenarios_30Remaining", "", eMsgUI.EVENT, 5 )
	}

	if ( until > Time() )
		wait until - Time()

	FS_Scenarios_EndGroup( group, null )
}

//////////////////////////////////////////////////////////////////////////////
// Win check. The only place a fight is decided.

void function FS_Scenarios_EvaluateGroup( ScenariosGroup group )
{
	if ( !group.isValid || group.phase == eScenariosPhase.ENDING || group.phase == eScenariosPhase.RETIRED )
		return

	FS_Scenarios_PublishEnemiesAlive( group )

	int teamsWithMembers = 0
	int teamsAlive = 0
	ScenariosTeam ornull lastAlive = null

	foreach ( ScenariosTeam team in group.teams )
	{
		if ( team.players.len() > 0 )
			teamsWithMembers++

		array<entity> alive = FS_Scenarios_GetAlivePlayersOfTeam( team )
		if ( alive.len() == 0 )
			continue

		// A team with nobody left standing is wiped; nobody can pick its downed up.
		if ( FS_Scenarios_CountStanding( alive ) == 0 )
		{
			thread FS_Scenarios_FinishDownedTeam( group, alive )
			continue
		}

		teamsAlive++
		lastAlive = team
	}

	if ( group.phase < eScenariosPhase.DROP )
	{
		// Someone left before the fight: nothing to score, hand everyone back.
		if ( teamsWithMembers < 2 )
		{
			Signal( group.dummyEnt, "FS_Scenarios_GroupEnd" )
		}
		return
	}

	if ( teamsAlive > 1 )
		return

	FS_Scenarios_EndGroup( group, lastAlive )
}

// The revive signal alone leaves the downed-transition thread running, and it
// sets the player back to bleeding out after they stood up.
void function FS_Scenarios_StandUpKnocked( entity player )
{
	if ( !IsValid( player ) || !Bleedout_IsBleedingOut( player ) )
		return
	Bleedout_ForceStop( player )
	BleedoutState_SetPlayerBleedoutState( player, BS_NOT_BLEEDING_OUT )
}

int function FS_Scenarios_CountStanding( array<entity> alive )
{
	int standing = 0
	foreach ( entity player in alive )
	{
		if ( !Bleedout_IsBleedingOut( player ) )
			standing++
	}
	return standing
}

// Deferred a frame: the deaths re-enter the win check through OnPlayerKilled.
void function FS_Scenarios_FinishDownedTeam( ScenariosGroup group, array<entity> downed )
{
	WaitFrame()

	foreach ( entity player in downed )
	{
		if ( !IsAlive( player ) || !Bleedout_IsBleedingOut( player ) )
			continue
		if ( FS_Scenarios_GetGroupHandleOfPlayer( player ) != group.groupHandle )
			continue

		entity attacker = Bleedout_GetBleedoutAttacker( player )
		player.Die( IsValid( attacker ) ? attacker : null, IsValid( attacker ) ? attacker : null, { damageSourceId = eDamageSourceId.bleedout } )
	}
}

void function FS_Scenarios_OnPlayerKnocked( entity victim, entity attacker, var damageInfo )
{

	if ( !IsValid( victim ) || !IsValid( attacker ) || !attacker.IsPlayer() || attacker.GetTeam() == victim.GetTeam() )
		return

	int groupHandle = FS_Scenarios_GetGroupHandleOfPlayer( victim )
	if ( groupHandle == -1 || FS_Scenarios_GetGroupHandleOfPlayer( attacker ) != groupHandle )
		return

	FS_Scenarios_AddScore( attacker, FS_ScoreType.DOWNED, victim )

	int handle = attacker.p.handle
	ScenariosKnockStreak streak
	if ( handle in file.knockStreaks && Time() - file.knockStreaks[ handle ].lastTime <= SCENARIOS_KNOCK_STREAK_WINDOW )
		streak = file.knockStreaks[ handle ]

	streak.count++
	streak.lastTime = Time()
	file.knockStreaks[ handle ] <- streak

	if ( streak.count == 2 )
		FS_Scenarios_AddScore( attacker, FS_ScoreType.BONUS_DOUBLE_DOWNED, victim )
	else if ( streak.count == 3 )
		FS_Scenarios_AddScore( attacker, FS_ScoreType.BONUS_TRIPLE_DOWNED, victim )

	FS_Scenarios_EvaluateGroup( expect ScenariosGroup( FS_Scenarios_GetGroupForPlayer( victim ) ) )
}

void function FS_Scenarios_EndGroup( ScenariosGroup group, ScenariosTeam ornull winners )
{
	if ( !group.isValid || group.phase == eScenariosPhase.ENDING || group.phase == eScenariosPhase.RETIRED )
		return

	bool wasLive = group.phase == eScenariosPhase.LIVE
	group.phase = eScenariosPhase.ENDING

	if ( wasLive && winners != null )
	{
		expect ScenariosTeam( winners )
		array<entity> alive = FS_Scenarios_GetAlivePlayersOfTeam( winners )
		float elapsed = Time() - group.liveStartTime

		foreach ( entity player in alive )
		{
			FS_Scenarios_AddScore( player, FS_ScoreType.SURVIVAL_TIME, null, elapsed )
			FS_Scenarios_AddScore( player, alive.len() > 1 ? FS_ScoreType.TEAM_WIN : FS_ScoreType.SOLO_WIN )
			player.SetPlayerNetInt( "FS_Scenarios_MatchesWins", player.GetPlayerNetInt( "FS_Scenarios_MatchesWins" ) + 1 )
		}
	}

	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
	{
		MakeInvincible( player )
		FS_Scenarios_StandUpKnocked( player )

		bool won = winners != null && expect ScenariosTeam( winners ).players.contains( player )
		LocalMsg( player, won ? "#FS_Scenarios_Victory" : "#FS_Scenarios_RoundOver", "", eMsgUI.EVENT, SCENARIOS_VICTORY_HOLD )
		FS_Scenarios_Hud_SendPhaseTo( player, group, won ? eScenariosHudPhase.WON : eScenariosHudPhase.LOST, Time(), Time() + SCENARIOS_VICTORY_HOLD, -1.0 )
		if ( wasLive )
			DemoMoment_Send( player, won ? eDemoMoment.FIGHT_WON : eDemoMoment.FIGHT_LOST )
	}


	FS_Scenarios_CloseRoundAfter( group )
	Signal( group.dummyEnt, "FS_Scenarios_GroupEnding" )
}

void function FS_Scenarios_PublishEnemiesAlive( ScenariosGroup group )
{
	foreach ( ScenariosTeam team in group.teams )
	{
		int enemies = 0
		foreach ( ScenariosTeam other in group.teams )
		{
			if ( other.team != team.team )
				enemies += FS_Scenarios_GetAlivePlayersOfTeam( other ).len()
		}

		foreach ( entity player in team.players )
		{
			if ( IsValid( player ) )
				player.SetPlayerNetInt( "FS_Scenarios_EnemiesAlive", minint( enemies, 511 ) )
		}
	}
}

//////////////////////////////////////////////////////////////////////////////
// Retire: the sole releaser of a group's realm, deathfield and team slots.
// Retire first, then route, or a pending rest re-enters a live teardown.

void function FS_Scenarios_RetireGroup( ScenariosGroup group, bool routeMembers = true )
{
	if ( !group.isValid )
		return

	group.isValid = false
	group.phase = eScenariosPhase.RETIRED

	if ( group.groupHandle in file.groups )
		delete file.groups[ group.groupHandle ]

	array<entity> members = FS_Scenarios_GetGroupMembers( group )
	foreach ( entity player in members )
	{
		int handle = player.p.handle
		if ( handle in file.playerGroup && file.playerGroup[ handle ].groupHandle == group.groupHandle )
			delete file.playerGroup[ handle ]

		player.SetPlayerNetInt( "FS_Scenarios_EnemiesAlive", -1 )
	}

	FS_Scenarios_Ring_Clear( group, members )
	FS_Scenarios_Loot_DestroyForGroup( group )

	foreach ( entity player in members )
		_CleanupPlayerEntities( player )
	FS_Scenarios_SweepRealm( group.slotIndex, "retire" )
	FS_Scenarios_Loot_SweepLeftovers( group.slotIndex, "retire" )
	thread FS_Scenarios_SweepLateDrops( group.slotIndex )

	FS_Scenarios_ReleaseGroupSlots( group )

	FS_1v1_AuditRealmSlots( "scenarios-retire" )

	foreach ( entity player in members )
	{
		if ( routeMembers )
			thread FS_Scenarios_RouteAfterGroup( player )
		else
			FS_Scenarios_SendStandings( player )
	}

	if ( IsValid( group.dummyEnt ) )
		group.dummyEnt.Destroy()

	thread TriggerMatchmaking()
}

// Destroys everything whose realms are exactly this fight realm: deployables, traps,
// effects, loot and boxes. Players, their weapons and what they carry stay.
void function FS_Scenarios_SweepRealm( int realm, string reason )
{
	if ( realm < 1 )
		return

	entity realmInfo = RealmInfoEntity_Get( realm )

	// Linked entities follow their player through realm changes (Vantage's Echo).
	table<entity, bool> linked
	foreach ( entity player in GetPlayerArray() )
	{
		foreach ( entity linkedEnt in player.p.realmLinkedEntities )
			linked[ linkedEnt ] <- true
	}

	int destroyed = 0
	foreach ( entity ent in GetEntitiesInRealmExclusive( realm ) )
	{
		if ( !IsValid( ent ) || ent == realmInfo || ent.IsPlayer() || ent.IsWeaponX() || ( ent in linked ) || FS_Scenarios_IsCarriedByPlayer( ent ) )
			continue
		// a player's grapple hook lives as long as the player; the client never null-checks it
		if ( ent.GetClassName() == "grapple_hook" )
			continue

		ent.Destroy()
		destroyed++
	}

	destroyed += FS_Scenarios_SweepFightAndLobbyMask( realm, realmInfo, linked )

	if ( destroyed > 0 )
		printt( format( "[FS-SCN][SWEEP] %s realm=%d destroyed=%d", reason, realm, destroyed ) )
}

// Mods thrown off a dropped weapon land half a second later and new boxes are
// tracked a frame late, so the fight's last drops miss the sweep at retire.
void function FS_Scenarios_SweepLateDrops( int realm )
{
	wait 1.0
	FS_Scenarios_Loot_SweepLeftovers( realm, "late" )
}

bool function FS_Scenarios_IsCarriedByPlayer( entity ent )
{
	entity owner = ent.GetParent()
	for ( int depth = 0; IsValid( owner ) && depth < 16; depth++ )
	{
		if ( owner.IsPlayer() )
			return true
		owner = owner.GetParent()
	}
	return false
}

void function FS_Scenarios_RouteAfterGroup( entity player )
{
	if ( !IsValid( player ) )
		return

	FS_Scenarios_SendStandings( player )
	FS_Scenarios_Teams_OnFightEnded( player )

	if ( TryProcessRestRequest( player ) )
		return

	if ( Gamemode1v1_IsPlayerResting( player ) )
		return

	Gamemode1v1_AddPlayerToQueue( player, false )
}

//////////////////////////////////////////////////////////////////////////////
// Leaving a group

void function FS_Scenarios_RemoveFromGroup( entity player )
{
	ScenariosGroup ornull maybeGroup = FS_Scenarios_GetGroupForPlayer( player )
	if ( maybeGroup == null )
		return

	ScenariosGroup group = expect ScenariosGroup( maybeGroup )
	delete file.playerGroup[ player.p.handle ]
	FS_Scenarios_Hud_SendOut( group, player )

	foreach ( ScenariosTeam team in group.teams )
	{
		if ( team.players.contains( player ) )
			team.players.fastremovebyvalue( player )
	}

	player.SetPlayerNetInt( "FS_Scenarios_EnemiesAlive", -1 )
	FS_Scenarios_Ring_ClearPlayer( player )

	if ( FS_Scenarios_GetGroupMembers( group ).len() == 0 )
	{
		Signal( group.dummyEnt, "FS_Scenarios_GroupEnd" )
		return
	}

	FS_Scenarios_EvaluateGroup( group )
}

// Shell hook: runs before every enqueue and rest so a player never carries a fight
// into the lobby.
void function FS_Scenarios_PrepareForLobby( entity player )
{
	if ( !IsValid( player ) )
		return

	// Leaving a fight alive (rest, AFK) ends that player's abilities there; a death leaves them to the retire sweep.
	bool leftFightAlive = FS_Scenarios_IsPlayerInGroup( player ) && IsAlive( player )
	FS_Scenarios_RemoveFromGroup( player )
	if ( leftFightAlive )
		_CleanupPlayerEntities( player )

	FS_Scenarios_StandUpKnocked( player )

	FS_Scenarios_SetLobbyTeam( player )
	FS_Scenarios_ReleaseWeaponHolds( player )
	if ( FS_1v1_PlayerHasClient( player ) )
		Remote_CallFunction_NonReplay( player, "ServerCallback_FS_Scenarios_HudPhase", eScenariosHudPhase.NONE, 0, -1.0, -1.0, -1.0 )
	TakeAllPassives( player )
	FS_1v1_StripAbilities( player )
	FS_Scenarios_Ring_ClearPlayer( player )
	player.MovementEnable()
	player.UnforceStand()
}

bool function FS_Scenarios_IsDeserting( entity player )
{
	ScenariosGroup ornull maybeGroup = FS_Scenarios_GetGroupForPlayer( player )
	if ( maybeGroup == null )
		return false

	ScenariosGroup group = expect ScenariosGroup( maybeGroup )
	return group.phase == eScenariosPhase.DROP || group.phase == eScenariosPhase.LIVE
}

void function FS_Scenarios_PenalizeDeserter( entity player )
{
	ScenariosGroup ornull maybeGroup = FS_Scenarios_GetGroupForPlayer( player )
	if ( maybeGroup == null )
		return

	ScenariosGroup group = expect ScenariosGroup( maybeGroup )
	FS_Scenarios_AddScore( player, FS_ScoreType.PENALTY_DESERTER )

	if ( file.deathboxesEnabled && group.phase == eScenariosPhase.LIVE && IsAlive( player ) )
		Dev_ForceDropDeathbox( player )
}

//////////////////////////////////////////////////////////////////////////////
// Deaths

void function FS_Scenarios_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	ScenariosGroup ornull maybeGroup = FS_Scenarios_GetGroupForPlayer( victim )
	if ( maybeGroup == null )
	{
		thread Gamemode1v1_AddPlayerToQueueAfterDeath( victim )
		return
	}

	ScenariosGroup group = expect ScenariosGroup( maybeGroup )
	bool despawn = DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.damagedef_despawn
	FS_Scenarios_Hud_SendOut( group, victim )

	if ( !despawn && group.phase == eScenariosPhase.LIVE )
	{
		FS_Scenarios_ScoreDeath( group, victim, attacker )

		if ( file.deathboxesEnabled )
			thread SURVIVAL_Death_DropLoot( victim, damageInfo )
	}

	FS_Scenarios_EvaluateGroup( group )

	if ( !despawn )
		thread FS_Scenarios_RequeueAfterDeath( victim, group )
}

void function FS_Scenarios_ScoreDeath( ScenariosGroup group, entity victim, entity attacker )
{
	FS_Scenarios_AddScore( victim, FS_ScoreType.PENALTY_DEATH )
	FS_Scenarios_AddScore( victim, FS_ScoreType.SURVIVAL_TIME, null, Time() - group.liveStartTime )

	ScenariosTeam ornull maybeVictimTeam = FS_Scenarios_GetTeamOfPlayer( group, victim )
	if ( maybeVictimTeam == null )
		return

	ScenariosTeam victimTeam = expect ScenariosTeam( maybeVictimTeam )
	array<entity> victimTeamAlive = FS_Scenarios_GetAlivePlayersOfTeam( victimTeam )

	bool attackerIsEnemy = IsValid( attacker ) && attacker.IsPlayer() && attacker != victim
		&& attacker.GetTeam() != victim.GetTeam() && FS_Scenarios_GetGroupHandleOfPlayer( attacker ) == group.groupHandle

	if ( attackerIsEnemy )
	{
		FS_Scenarios_AddScore( attacker, FS_ScoreType.KILL, victim )

		if ( victimTeamAlive.len() == 0 )
		{
			if ( victimTeam.players.len() > 1 )
				FS_Scenarios_AddScore( attacker, FS_ScoreType.BONUS_TEAM_WIPE, victim )
			else
				FS_Scenarios_AddScore( attacker, FS_ScoreType.BONUS_KILLED_SOLO_PLAYER, victim )
		}
	}

	if ( victimTeamAlive.len() == 1 && victimTeam.players.len() > 1 && !Bleedout_IsBleedingOut( victimTeamAlive[ 0 ] ) )
		FS_Scenarios_AddScore( victimTeamAlive[ 0 ], FS_ScoreType.BONUS_BECOMES_SOLO_PLAYER )
}

void function FS_Scenarios_RequeueAfterDeath( entity victim, ScenariosGroup group )
{
	victim.EndSignal( "OnDestroy" )

	if ( FS_1v1_PlayerHasClient( victim ) )
		Remote_CallFunction_NonReplay( victim, "Flowstate_ShowRespawnTimeUI", int( SCENARIOS_DEATH_TRANSFER_TIME ) )

	wait SCENARIOS_DEATH_TRANSFER_TIME

	// The group may have ended and routed the player already.
	if ( FS_Scenarios_GetGroupHandleOfPlayer( victim ) != group.groupHandle )
		return

	if ( TryProcessRestRequest( victim ) )
		return

	Gamemode1v1_AddPlayerToQueue( victim, false )
}

// Only members of the same fight hurt each other; waiting and resting players
// are protected by the shell's lobby-state gate.
bool function FS_Scenarios_ShouldBlockDamage( entity victim, entity attacker )
{
	int victimGroup = FS_Scenarios_GetGroupHandleOfPlayer( victim )
	if ( victimGroup == -1 )
		return false

	// Ring, falls and world hazards have no player attacker and always land.
	if ( !IsValid( attacker ) || !attacker.IsPlayer() || attacker == victim )
		return false

	return FS_Scenarios_GetGroupHandleOfPlayer( attacker ) != victimGroup
}

//////////////////////////////////////////////////////////////////////////////
// Rest, AFK, disconnect

void function ClientCommand_FS_Scenarios_Rest( entity player, array<string> args )
{
	if ( !IsValid( player ) || GetTDMState() != eTDMState.IN_PROGRESS )
		return

	if ( Time() < player.p.lastRestUsedTime + 1.0 )
		return

	int state = Gamemode1v1_GetPlayerGamestate( player )
	if ( state == e1v1State.CHARSELECT || state == e1v1State.PREMATCH )
	{
		LocalEventMsg( player, "#FS_NOT_AVAILABLE" )
		return
	}

	player.p.lastRestUsedTime = Time()
	int handle = player.p.handle

	if ( Gamemode1v1_IsPlayerResting( player ) )
	{
		if ( player.IsObserver() || player.p.isSpectating )
			endSpectate( player )

		Gamemode1v1_AddPlayerToQueue( player, false, true )
		return
	}

	if ( FS_Scenarios_IsDeserting( player ) )
	{
		// Leaving a live fight costs points, so it takes a second press to confirm.
		if ( !( handle in file.restConfirmUntil ) || Time() > file.restConfirmUntil[ handle ] )
		{
			file.restConfirmUntil[ handle ] <- Time() + SCENARIOS_REST_CONFIRM_WINDOW
			LocalMsg( player, "#FS_Scenarios_RestConfirm", "", eMsgUI.EVENT, SCENARIOS_REST_CONFIRM_WINDOW )
			return
		}

		delete file.restConfirmUntil[ handle ]
		FS_Scenarios_PenalizeDeserter( player )
	}

	Gamemode1v1_AddPlayerToRest( player )
	thread Gamemode1v1_RespawnForMatch( player )
}

void function ClientCommand_FS_Scenarios_Standings( entity player, array<string> args )
{
	if ( !IsValid( player ) || !CheckRate( player, "scenarios_standings", 2.0, false ) )
		return

	FS_Scenarios_SendStandings( player )
}

// Lists entities left in a fight realm no group holds, and entities owned by a
// fighter that are not in that fighter's realm.
const array<string> SCENARIOS_AUDIT_CLASSES = [ "prop_survival", "prop_death_box", "prop_script", "prop_dynamic",
	"prop_door", "prop_physics", "script_mover", "script_mover_lightweight", "grenade", "crossbow_bolt",
	"npc_drone", "npc_turret_sentry", "npc_dummie", "trigger_cylinder", "trigger_cylinder_heavy", "vortex_sphere",
	"zipline", "zipline_end", "info_particle_system", "trace_volume", "prop_dynamic_lightweight", "info_placement_helper",
	"trigger_slip_sphere", "move_rope", "keyframe_rope" ]

// Fight entities that also carry the lobby bit: the exclusive query above cannot see them.
int function FS_Scenarios_SweepFightAndLobbyMask( int realm, entity realmInfo, table<entity, bool> linked )
{
	int destroyed = 0
	foreach ( string className in SCENARIOS_AUDIT_CLASSES )
	{
		foreach ( entity ent in GetEntArrayByClass_Expensive( className ) )
		{
			if ( !IsValid( ent ) || ent == realmInfo || ent.IsPlayer() || ent.IsWeaponX() || ( ent in linked ) || FS_Scenarios_IsCarriedByPlayer( ent ) )
				continue

			array<int> realms = ent.GetRealms()
			if ( realms.len() != 2 || !realms.contains( eRealms.DEFAULT ) || !realms.contains( realm ) )
				continue

			ent.Destroy()
			destroyed++
		}
	}
	return destroyed
}

void function ClientCommand_FS_Scenarios_RealmAudit( entity player, array<string> args )
{
	if ( !IsValid( player ) || !GetConVarBool( "sv_cheats" ) )
		return

	table<int, int> slotToGroup
	foreach ( int handle, ScenariosGroup group in file.groups )
		slotToGroup[ group.slotIndex ] <- handle

	int leaked = 0
	int crossed = 0
	int scanned = 0
	foreach ( string className in SCENARIOS_AUDIT_CLASSES )
	{
		foreach ( entity ent in GetEntArrayByClass_Expensive( className ) )
		{
			if ( !IsValid( ent ) || ent.IsPlayer() )
				continue
			scanned++

			array<int> realms = ent.GetRealms()
			foreach ( int realm in realms )
			{
				if ( realms.len() > 1 || realm < 1 || realm in slotToGroup )
					continue
				leaked++
				printt( format( "[FS-SCN][AUDIT] LEAK %s realm=%d origin=%s", className, realm, string( ent.GetOrigin() ) ) )
			}

			entity owner = ent.GetOwner()
			if ( !IsValid( owner ) || !owner.IsPlayer() )
				continue

			ScenariosGroup ornull ownerGroup = FS_Scenarios_GetGroupForPlayer( owner )
			if ( ownerGroup == null )
				continue
			int ownerRealm = expect ScenariosGroup( ownerGroup ).slotIndex
			if ( !ent.IsInRealm( ownerRealm ) || realms.len() > 1 )
			{
				crossed++
				string realmList = ""
				foreach ( int realm in realms )
					realmList += string( realm ) + " "
				printt( format( "[FS-SCN][AUDIT] CROSS %s owner=%s ownerRealm=%d realms=[ %s]", className,
					owner.GetPlayerName(), ownerRealm, realmList ) )
			}
		}
	}

	printt( format( "[FS-SCN][AUDIT] scanned=%d leaked=%d crossed=%d groups=%d freeRealms=%d",
		scanned, leaked, crossed, file.groups.len(), FS_1v1_CountFreeRealmSlots() ) )
}

void function FS_Scenarios_ForceRest( entity player )
{
	if ( !IsValid( player ) || Gamemode1v1_IsPlayerResting( player ) )
		return

	if ( FS_Scenarios_IsDeserting( player ) )
		FS_Scenarios_PenalizeDeserter( player )

	Gamemode1v1_AddPlayerToRest( player )
	thread Gamemode1v1_RespawnForMatch( player )
}

void function FS_Scenarios_OnPlayerDisconnected( entity player )
{
	if ( FS_Scenarios_IsDeserting( player ) )
		FS_Scenarios_PenalizeDeserter( player )

	FS_Scenarios_RemoveFromGroup( player )

	int handle = player.p.handle
	if ( handle in file.queuePriority )
		delete file.queuePriority[ handle ]
	if ( handle in file.restConfirmUntil )
		delete file.restConfirmUntil[ handle ]
	if ( handle in file.knockStreaks )
		delete file.knockStreaks[ handle ]

	FS_Scenarios_Teams_OnDisconnect( player )
	FS_Scenarios_ReleaseLobbyTeam( player )
}

//////////////////////////////////////////////////////////////////////////////
// Round end: every live fight is retired before the champion screen. Members stay
// where they are; the shell parks them for the recap and gathers them after it,
// which keeps one realm-0 merge of the whole server out of the transition.

void function FS_Scenarios_ForceAllGroupsToFinish()
{
	array<ScenariosGroup> live
	foreach ( int handle, ScenariosGroup group in file.groups )
		live.append( group )

	foreach ( ScenariosGroup group in live )
		FS_Scenarios_RetireGroup( group, false )
}
