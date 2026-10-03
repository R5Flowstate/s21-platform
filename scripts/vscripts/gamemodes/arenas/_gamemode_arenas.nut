global function Arenas_ServerGamemode_Init

// GAME LOOP:
//   WaitingForPlayers -> Prematch -> [BuyPhase -> CombatPhase -> RoundEnd] x N -> MatchEnd
//   - Buy phase: Players confined by start zone walls, buy menu open (Prematch game state)
//   - Combat phase: Walls toggled off, canisters spawned, elimination polling (Playing game state)
//   - First to ARENAS_ROUNDS_TO_WIN wins (win-by-2 at high scores, sudden death after max ties)
//
// MAP ENTITIES (via AddSpawnCallbackEditorClass):
//   info_arenas_spawn_location (2)         - Team spawn origins, players spread in triangle formation
//   func_brush_arenas_start_zone (9)       - Spawn room walls, toggled solid/invisible between phases
//   info_arenas_materials_canister (3)      - Positions where prop_script canisters are spawned each round
//   info_arenas_airdrop_location (2)        - Care package drop points
//   info_arenas_circle_end_location (2)     - Ring/deathfield closure endpoints
//   info_arenas_defensive_end_location (2)  - Defensive positions with script_radius
//   info_arenas_intro_camera (4)            - Cinematic intro camera positions
//   info_arenas_map_location (1)            - Master config: map name, radius, deathfield stages
//   info_arenas_med_lootbin_location (2)    - Loot bin placement positions
//
// ECONOMY:
//   - Base materials per round from Arenas_GetCashAmountForRound() (escalating per round)
//   - Kill bonus: ARENAS_KILL_REWARD awarded in real-time, carried over via materialsCarryover
//   - Canister bonus: ARENAS_CANISTER_REWARD on use, configurable via playlist var
//   - Client buy menu sends "Arenas_Select <idx> <cost> <ref>" via ClientCommand
//   - Server validates, deducts, syncs arenas_current_cash netvar -> client UI refresh
//
// DEPENDENCIES:
//   - sh_gamemode_arenas.nut: Networking registration, client callbacks, Arenas_GetCashAmountForRound()
//   - sh_arenas_buy_system.nut: Economy constants, client buy menu UI, store data
//   - sh_cash_station.gnut: Model precache, client canister UI (ServerToClient_OnUseCashStationSmall)
// ============================================================================

// Economy constants defined in sh_arenas_buy_system.nut (shared):
// ARENAS_MAX_CASH, ARENAS_KILL_REWARD, ARENAS_CANISTER_REWARD, ARENAS_ROUND_PER_LOSE_CASH

// Dev mode: skip buy phase, give default loadout, jump straight to combat
const bool ARENAS_DEV_MODE = false

// Timing constants
const float ARENAS_ROUND_END_DELAY = 3.0
const float ARENAS_ROUND_RESTART_DELAY = 2.0
const float ARENAS_MATCH_END_DELAY = 8.0
const float ARENAS_PREMATCH_DELAY = 3.0
const float ARENAS_RING_CLOSURE_DELAY = 90.0
const string ARENAS_DEFAULT_AIRDROP_CONTENTS = "crate_weapons_earlygame control_gold_kitted_weapons control_gold_kitted_weapons"

// Post-round summary duration (fade-to-black, score animation, Ash effects).
// Client calculates summary window as: gameStartTime - shopDuration.
// Must match sh_gamemode_arenas.nut ROUND_SUMMARY_DURATION (intro 2.5 + outro 1.5 = 4.0)
// plus margin for fade-from-black (0.35) and audio cues.
const float ARENAS_POST_ROUND_SUMMARY_DURATION = 5.0

// Win condition constants
const int ARENAS_ROUNDS_TO_WIN = 3
const int ARENAS_MAX_TIES = 2

// Game phase enum
global enum eArenaPhase
{
	PREMATCH,
	BUY_PHASE,
	COMBAT,
	ROUND_END,
	MATCH_END
}

struct ArenasSelectedItem
{
	string ref = ""
	int cost = 0
}

struct ArenaPlayerData
{
	int materials = 0
	int materialsCarryover = 0
	int killsThisRound = 0
	int killsThisMatch = 0
	int killsLastRound = 0
	int damageThisRound = 0
	int canistersThisRound = 0
	int canistersThisMatch = 0
	int canistersLastRound = 0
	array<ArenasSelectedItem> selectedItems
	string selectedOptic = ""
	bool isEliminated = false

	// Rounds the ultimate stays unbuyable; the value before this round's purchase restores a sale.
	int ultCooldownRounds = 0
	int ultCooldownBeforePurchase = 0
	// Ultimate clip before a purchase, -1 when the player had no ultimate; a sale puts it back.
	int ultClipBeforePurchase = -1
}

// Spawn offset pattern for spreading players around a single spawn location
// 3v3 triangle formation: center, left, right
const array<vector> ARENAS_SPAWN_OFFSETS = [
	<0, 0, 0>,
	<-100, -80, 0>,
	<100, -80, 0>
]

struct
{
	int currentPhase = eArenaPhase.PREMATCH
	int roundNumber = 0
	int leftTeam = TEAM_IMC
	int rightTeam = TEAM_MILITIA
	int leftTeamScore = 0
	int rightTeamScore = 0
	int numTies = 0
	int lastWonTeam = 0
	bool matchOver = false

	table<entity, ArenaPlayerData> playerData

	// Map entities collected via AddSpawnCallbackEditorClass
	array<entity> spawnLocations              // info_arenas_spawn_location (2 per map, one per team)
	array<entity> startZoneBrushes            // func_brush_arenas_start_zone (spawn room walls)
	array<entity> canisterInfoEnts            // info_arenas_materials_canister (canister position markers)
	array<entity> airdropLocations            // info_arenas_airdrop_location (care package drop points)
	array<entity> circleEndLocations          // info_arenas_circle_end_location (ring closure endpoints)
	array<entity> defensiveEndLocations       // info_arenas_defensive_end_location
	array<entity> introCameras                // info_arenas_intro_camera
	array<entity> medLootbinLocations         // info_arenas_med_lootbin_location
	entity        mapLocationEnt = null       // info_arenas_map_location (master config, one per map)

	// Spawned canister props (created from canisterInfoEnts positions)
	array<entity> activeCanisters

	// Spawned loot bins (created from medLootbinLocations)
	array<entity> activeLootBins

	// Legacy spawn arrays (populated from spawnLocations)
	array<entity> leftSpawns
	array<entity> rightSpawns

	float buyPhaseEndTime = 0.0
	table< string, array<string> > announcerLines
	IntroCameraSettings waitingView
	bool mainLoopStarted = false
	bool teamsAssigned = false
	bool deathfieldOverridesSet = false
	bool forceNextRound = false
	bool firstBloodThisRound = false

	// Map config extracted from info_arenas_map_location
	string mapName = ""
	float mapRadius = 6000.0
	array<float> deathfieldStagesRadius
	array<float> deathfieldStagesMinimapZoom

	// This round's care package, one item per pod door; the buy menu previews it.
	array<string> roundAirdropContents
} file

// ============================================================================
// INITIALIZATION
// ============================================================================
void function Arenas_ServerGamemode_Init()
{

	AddCallback_OnClientConnected( Arenas_OnClientConnected )
	AddCallback_OnClientDisconnected( Arenas_OnClientDisconnected )
	AddCallback_OnPlayerKilled( Arenas_OnPlayerKilled )
	AddDamageCallback( "player", Arenas_OnPlayerDamaged )
	AddCallback_EntitiesDidLoad( Arenas_EntitiesDidLoad )
	// Onboarding system handles WaitingForPlayers -> PickLoadout -> Prematch -> Playing
	// Assign teams early so character select draft and UI work correctly.
	// PickLoadout may be skipped if char select is disabled, so also hook Prematch as fallback.
	AddCallback_GameStateEnter( eGameState.PickLoadout, Arenas_OnPickLoadout )
	AddCallback_GameStateEnter( eGameState.Prematch, Arenas_OnPrematch )
	AddCallback_GameStateEnter( eGameState.Playing, Arenas_OnGameStatePlaying )

	// Buy system client commands
	AddClientCommandCallback( "Arenas_Select", ClientCommand_Arenas_Select )
	AddClientCommandCallback( "Arenas_Unselect", ClientCommand_Arenas_Unselect )
	AddClientCommandCallback( "Arenas_SetOptic", ClientCommand_Arenas_SetOptic )
	AddClientCommandCallback( "Arenas_ChangeWeaponTab", ClientCommand_Arenas_ChangeWeaponTab )
	AddClientCommandCallback( "next_round", ClientCommand_Arenas_ForceNextRound )

	// Register editorclass spawn callbacks for all arenas entity types
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_spawn_location", Arenas_OnSpawnLocationCreated )
	AddSpawnCallbackEditorClass( "func_brush", "func_brush_arenas_start_zone", Arenas_OnStartZoneBrushCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_materials_canister", Arenas_OnCanisterInfoCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_cash_station_small", Arenas_OnCanisterInfoCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_airdrop_location", Arenas_OnAirdropLocationCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_circle_end_location", Arenas_OnCircleEndLocationCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_defensive_end_location", Arenas_OnDefensiveEndLocationCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_intro_camera", Arenas_OnIntroCameraCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_map_location", Arenas_OnMapLocationCreated )
	AddSpawnCallbackEditorClass( "script_ref", "info_arenas_med_lootbin_location", Arenas_OnMedLootbinLocationCreated )

	SetRoundBased( true )
	Arenas_LoadAnnouncerLines()

	// Players spawn only through the buy phase, straight into their team's spawn room.
	AddCallback_ShouldPlayerSpawnAtStart( bool function( entity player ) { return false } )
	Survival_SetCallback_ModeShouldSpawnPlayersDuringCharacterSelect( bool function() { return false } )

	// Equipment netvars are set in EntitiesDidLoad (SetGlobalNetInt requires entity system)

}

void function Arenas_EntitiesDidLoad()
{
	Arenas_GatherSpawnPoints()
	Arenas_SetupWaitingView()

	// Set equipment netvars here - loot datatables loaded (sh_init.gnut:185) and
	// entity system is up so SetGlobalNetInt works
	Arenas_SetEquipmentNetvars()
}

// WaitingForPlayers -> PickLoadout -> Prematch -> Playing is handled by
// the standard onboarding system in sh_onboarding.gnut.
// Team assignment uses GiveInitialTeamToPlayer which respects max_team_size
// and max_players playlist vars (TEAM_IMC and TEAM_MILITIA for 2-team arenas).

void function Arenas_OnPickLoadout()
{
	// Assign teams before character select begins. GiveInitialTeamToPlayer fills
	// teams sequentially up to max_team_size, which puts all players on TEAM_IMC
	// when player count < max_team_size. Rebalance to alternate teams here.
	if ( !file.teamsAssigned )
	{
		file.teamsAssigned = true
		Arenas_AssignTeams()
	}

	// The legend pick ends PickLoadout by setting pickLoadoutGamestateEndTime; the
	// gamestate think then moves to Prematch, the first buy phase.
	SetCustomIntroLength( Arenas_BuyPhaseDuration() )
	thread Survival_RunCharacterSelectionNew_Thread()
}

void function Arenas_OnPrematch()
{
	// Assign teams on first Prematch (from onboarding). Subsequent Prematch
	// transitions (from BuyPhase each round) skip this.
	if ( !file.teamsAssigned )
	{
		file.teamsAssigned = true
		Arenas_AssignTeams()
	}

	// Set up deathfield circle overrides once from map entities
	if ( !file.deathfieldOverridesSet )
	{
		file.deathfieldOverridesSet = true

		// Arenas has no loot, so the ring end must not snap to loot: that search returns the world origin.
		foreach ( entity endLoc in file.circleEndLocations )
		{
			if ( IsValid( endLoc ) )
				SURVIVAL_AddOverrideCircleLocation( endLoc.GetOrigin(), 250.0, true )
		}

		if ( IsValid( file.mapLocationEnt ) )
		{
			vector mapCenter = file.mapLocationEnt.GetOrigin()
			foreach ( int realm in Survival_Loot_GetRealmsToPopulate() )
				SURVIVAL_SetDeathFieldOverrideStartPos( realm, < mapCenter.x, mapCenter.y, 0 > )
		}

		SURVIVAL_SetDeathFieldOverrideStartRadius( file.mapRadius )

		if ( file.deathfieldStagesRadius.len() == 0 )
			file.deathfieldStagesRadius = Arenas_ScaledRingStages()
		if ( file.deathfieldStagesRadius.len() > 0 )
			SURVIVAL_SetDeathFieldStagesOverrideRadius( file.deathfieldStagesRadius )
		if ( file.deathfieldStagesMinimapZoom.len() > 0 )
			SURVIVAL_SetDeathFieldStagesOverrideMinimapZoom( file.deathfieldStagesMinimapZoom )

		// Reinitialize deathfield data now that overrides are set
		RoundBased_ResetDeathfield()

	}

	// Start the main game loop on first Prematch from onboarding.
	// Onboarding stops at Prematch for arenas; we take over from here.
	if ( !file.mainLoopStarted )
	{
		file.mainLoopStarted = true
		thread Arenas_MainGameLoop()
	}
}

// The ring tuning playlist authors its radii for its own start radius; scale them to this map.
array<float> function Arenas_ScaledRingStages()
{
	array<float> stages
	string tuning = GetCurrentPlaylistVarString( "playlist_ring_tuning_override", "" )
	if ( tuning == "" )
		return stages

	float authoredStart = GetPlaylistVarFloat( tuning, "survival_death_field_start_radius", -1.0 )
	if ( authoredStart <= 0.0 )
		return stages

	float radius = GetPlaylistVarFloat( tuning, "deathfield_radius_0", -1.0 )
	while ( radius >= 0.0 )
	{
		float scaled = radius * file.mapRadius / authoredStart
		stages.append( scaled < 1.0 ? 1.0 : scaled )
		radius = GetPlaylistVarFloat( tuning, "deathfield_radius_" + stages.len(), -1.0 )
	}

	return stages
}

void function Arenas_OnGameStatePlaying()
{
	// Game loop is started from Arenas_OnPrematch. This callback exists
	// as a safety guard only.
	if ( file.mainLoopStarted )
		return

	file.mainLoopStarted = true
	thread Arenas_MainGameLoop()
}

// ============================================================================
// EDITORCLASS ENTITY SPAWN CALLBACKS
// ============================================================================
void function Arenas_OnSpawnLocationCreated( entity ent )
{
	file.spawnLocations.append( ent )
}

void function Arenas_OnStartZoneBrushCreated( entity ent )
{
	if ( GetEditorClass( ent ) != "func_brush_arenas_start_zone" )
		return

	file.startZoneBrushes.append( ent )
	// Start zone brushes spawn already solid from the BSP, keep them that way
}

void function Arenas_OnCanisterInfoCreated( entity ent )
{
	file.canisterInfoEnts.append( ent )
}

void function Arenas_OnAirdropLocationCreated( entity ent )
{
	file.airdropLocations.append( ent )
}

void function Arenas_OnCircleEndLocationCreated( entity ent )
{
	file.circleEndLocations.append( ent )
}

void function Arenas_OnDefensiveEndLocationCreated( entity ent )
{
	file.defensiveEndLocations.append( ent )
}

void function Arenas_OnIntroCameraCreated( entity ent )
{
	file.introCameras.append( ent )

}

void function Arenas_OnMapLocationCreated( entity ent )
{
	file.mapLocationEnt = ent

	// Extract map configuration from KV pairs
	if ( ent.HasKey( "script_noteworthy" ) )
		file.mapName = ent.GetValueForKey( "script_noteworthy" )

	if ( ent.HasKey( "script_radius" ) )
		file.mapRadius = ent.GetValueForKey( "script_radius" ).tofloat()

	if ( ent.HasKey( "minimap_zoom_scales" ) )
	{
		array<string> zoomParts = split( ent.GetValueForKey( "minimap_zoom_scales" ), " " )
		file.deathfieldStagesMinimapZoom.clear()
		foreach ( string part in zoomParts )
			file.deathfieldStagesMinimapZoom.append( part.tofloat() )
	}

	if ( ent.HasKey( "deathfield_stages_radius" ) )
	{
		string radiusStr = ent.GetValueForKey( "deathfield_stages_radius" )
		array<string> parts = split( radiusStr, " " )
		file.deathfieldStagesRadius.clear()
		foreach ( string part in parts )
			file.deathfieldStagesRadius.append( part.tofloat() )
	}

}

void function Arenas_OnMedLootbinLocationCreated( entity ent )
{
	file.medLootbinLocations.append( ent )
}

// ============================================================================
// SPAWN POINT SETUP (from editorclass entities)
// ============================================================================
void function Arenas_GatherSpawnPoints()
{
	// Spawn locations are collected via AddSpawnCallbackEditorClass callbacks
	// by the time EntitiesDidLoad fires. Assign them to teams.
	if ( file.spawnLocations.len() >= 2 )
	{
		// Two spawn locations: first = left team, second = right team
		file.leftSpawns.clear()
		file.rightSpawns.clear()
		file.leftSpawns.append( file.spawnLocations[0] )
		file.rightSpawns.append( file.spawnLocations[1] )
	}
	else if ( file.spawnLocations.len() == 1 )
	{
		// Only one spawn location found, use it for both teams
		file.leftSpawns.append( file.spawnLocations[0] )
		file.rightSpawns.append( file.spawnLocations[0] )
		Warning( "[Arenas] Only 1 spawn location found, using for both teams" )
	}
	else
	{
		// No editorclass spawn locations found, fall back to info_player_start
		Warning( "[Arenas] No info_arenas_spawn_location entities found, using generic spawns" )
		array<entity> genericSpawns = GetEntArrayByClass_Expensive( "info_player_start" )
		if ( genericSpawns.len() >= 2 )
		{
			file.leftSpawns.append( genericSpawns[0] )
			file.rightSpawns.append( genericSpawns[1] )
		}
		else if ( genericSpawns.len() >= 1 )
		{
			file.leftSpawns = clone genericSpawns
			file.rightSpawns = clone genericSpawns
		}
	}

}

// ============================================================================
// PLAYER CONNECTION CALLBACKS
// ============================================================================
void function Arenas_OnClientConnected( entity player )
{
	ArenaPlayerData data
	data.materials = Arenas_GetCashAmountForRound( file.roundNumber )
	file.playerData[player] <- data

	// Sync initial cash to client
	player.SetPlayerNetInt( "arenas_current_cash", data.materials )

	if ( file.teamsAssigned )
		SetTeam( player, Arenas_GetSmallerTeam() )

	Arenas_UpdateConnectedCount()
	if ( !file.mainLoopStarted )
		thread Arenas_HoldWaitingView( player )

	// If joining mid-match during buy phase, open buy menu
	if ( file.currentPhase == eArenaPhase.BUY_PHASE )
	{
		thread Arenas_LateJoinBuyPhase( player )
	}
}

void function Arenas_HoldWaitingView( entity player )
{
	player.EndSignal( "OnDestroy" )
	WaitFrame()
	if ( file.mainLoopStarted || IsAlive( player ) )
		return

	if ( file.waitingView.origin != ZERO_VECTOR )
	{
		player.SetObserverModeStaticPosition( file.waitingView.origin )
		player.SetObserverModeStaticAngles( file.waitingView.angles )
	}
	player.StartObserverMode( OBS_MODE_STATIC_LOCKED )
	player.FreezeControlsOnServer()
}

// The map location links the intro fly-through cameras; the one camera it does not
// link is the map overview, used while waiting for players.
void function Arenas_SetupWaitingView()
{
	if ( file.introCameras.len() == 0 )
	{
		Arenas_SetupFallbackWaitingView()
		return
	}

	array<entity> flyThrough
	if ( IsValid( file.mapLocationEnt ) )
		flyThrough = file.mapLocationEnt.GetLinkEntArray()
	entity camera = file.introCameras[0]
	foreach ( entity candidate in file.introCameras )
	{
		if ( !flyThrough.contains( candidate ) )
		{
			camera = candidate
			break
		}
	}

	file.waitingView.origin = camera.GetOrigin()
	file.waitingView.angles = camera.GetAngles()
	SetIntroCameraSettings( file.waitingView )
}

// Maps without intro cameras (phase runner) get an elevated view over the map location.
void function Arenas_SetupFallbackWaitingView()
{
	if ( !IsValid( file.mapLocationEnt ) )
		return

	vector center = file.mapLocationEnt.GetOrigin()
	vector back = AnglesToForward( file.mapLocationEnt.GetAngles() ) * -( file.mapRadius * 0.5 )
	vector origin = center + back + <0, 0, file.mapRadius * 0.35>

	file.waitingView.origin = origin
	file.waitingView.angles = VectorToAngles( center - origin )
	SetIntroCameraSettings( file.waitingView )
}

// Drives the "connected / max players" readout on the waiting HUD.
void function Arenas_UpdateConnectedCount()
{
	SetGlobalNetInt( "connectedPlayerCount", GetPlayerArray_ConnectedNotSpectatorTeam().len() )
}

void function Arenas_UpdateConnectedCountNextFrame()
{
	WaitFrame()
	Arenas_UpdateConnectedCount()
}

void function Arenas_OnClientDisconnected( entity player )
{
	thread Arenas_UpdateConnectedCountNextFrame()

	if ( player in file.playerData )
		delete file.playerData[player]

	// Check if a team was eliminated by this disconnect
	if ( file.currentPhase == eArenaPhase.COMBAT )
	{
		thread Arenas_CheckTeamEliminated()
	}
}

void function Arenas_LateJoinBuyPhase( entity player )
{
	wait 1.0
	if ( !IsValid( player ) )
		return
	if ( file.currentPhase != eArenaPhase.BUY_PHASE )
		return

	int leftTeam = file.leftTeam
	int rightTeam = file.rightTeam
	int savedCash = 0
	int kills = 0
	int canisters = 0

	Remote_CallFunction_NonReplay( player, "ServerCallback_DisplayArenasPrematch", leftTeam, rightTeam, savedCash, kills, canisters )
	Arenas_SendAirdropPreview( player )
}

// ============================================================================
// ECONOMY SYSTEM
// ============================================================================
void function Arenas_AwardMaterials( entity player, int amount )
{
	if ( !( player in file.playerData ) )
		return

	ArenaPlayerData data = file.playerData[player]
	data.materials = minint( data.materials + amount, ARENAS_MAX_CASH )
	file.playerData[player] = data
}

void function Arenas_SetMaterials( entity player, int amount )
{
	if ( !( player in file.playerData ) )
		return

	ArenaPlayerData data = file.playerData[player]
	data.materials = minint( maxint( amount, 0 ), ARENAS_MAX_CASH )
	file.playerData[player] = data
}

int function Arenas_GetMaterials( entity player )
{
	if ( !( player in file.playerData ) )
		return 0

	return file.playerData[player].materials
}

bool function Arenas_DeductMaterials( entity player, int cost )
{
	if ( !( player in file.playerData ) )
		return false

	ArenaPlayerData data = file.playerData[player]
	if ( data.materials < cost )
		return false

	data.materials -= cost
	file.playerData[player] = data
	return true
}

void function Arenas_SyncCashToClient( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( !( player in file.playerData ) )
		return

	player.SetPlayerNetInt( "arenas_current_cash", file.playerData[player].materials )
}

void function Arenas_SyncCashToAllClients()
{
	foreach ( entity player, ArenaPlayerData data in file.playerData )
	{
		if ( !IsValid( player ) )
			continue
		player.SetPlayerNetInt( "arenas_current_cash", data.materials )
	}
}

void function Arenas_ResetEconomyForRound()
{
	int baseMaterials = Arenas_GetCashAmountForRound( file.roundNumber )

	foreach ( entity player, ArenaPlayerData data in file.playerData )
	{
		if ( !IsValid( player ) )
			continue

		// Save previous round stats before resetting (used by prematch callback)
		data.killsLastRound = data.killsThisRound
		data.canistersLastRound = data.canistersThisRound

		// Base materials for this round + carryover from previous round
		// Kill rewards are already awarded in real-time during combat and
		// included in materialsCarryover, so no additional kill bonus here
		int totalMaterials = baseMaterials + data.materialsCarryover

		data.materials = minint( totalMaterials, ARENAS_MAX_CASH )
		data.killsThisRound = 0
		data.damageThisRound = 0
		data.canistersThisRound = 0
		data.selectedItems.clear()
		data.selectedOptic = ""
		data.isEliminated = false
		file.playerData[player] = data

		// Sync materials to client for buy menu display
		player.SetPlayerNetInt( "arenas_current_cash", data.materials )
	}
}

// ============================================================================
// MAIN GAME LOOP
// ============================================================================
void function Arenas_MainGameLoop()
{
	// Teams were already assigned in Arenas_OnPickLoadout before character select.

	// Prematch notification
	file.currentPhase = eArenaPhase.PREMATCH
	file.roundNumber = 0
	file.leftTeamScore = 0
	file.rightTeamScore = 0
	file.numTies = 0
	file.matchOver = false
	Arenas_PublishTeamScores()

	// Update networked vars
	SetGlobalNetInt( "arenas_numties", 0 )
	SetGlobalNetInt( "arenas_lastWonTeam", 0 )
	SetGlobalNonRewindNetInt( "roundsPlayed", 0 )

	WaitFrame()

	// Main round loop
	while ( !file.matchOver )
	{
		Arenas_ResetEconomyForRound()
		Arenas_BuyPhase()
		Arenas_CombatPhase()

		// Wait handled inside RoundEnd
		if ( file.matchOver )
			break

		file.roundNumber++
		SetGlobalNonRewindNetInt( "roundsPlayed", file.roundNumber )
	}

	// Match end sequence
	Arenas_MatchEnd()
}

// ============================================================================
// TEAM ASSIGNMENT
// ============================================================================
int function Arenas_GetSmallerTeam()
{
	int left = GetPlayerArrayOfTeam( file.leftTeam ).len()
	int right = GetPlayerArrayOfTeam( file.rightTeam ).len()
	return left <= right ? file.leftTeam : file.rightTeam
}

void function Arenas_AssignTeams()
{
	array<entity> allPlayers = GetPlayerArray()

	// Shuffle players for random team assignment
	allPlayers.randomize()

	int halfSize = allPlayers.len() / 2

	for ( int i = 0; i < allPlayers.len(); i++ )
	{
		entity player = allPlayers[i]
		if ( i < halfSize )
			SetTeam( player, file.leftTeam )
		else
			SetTeam( player, file.rightTeam )
	}

}

// ============================================================================
// BUY PHASE
// ============================================================================
void function Arenas_BuyPhase()
{
	file.currentPhase = eArenaPhase.BUY_PHASE
	// Entering Prematch sets gameStartTime to now + the custom intro length, and the
	// gamestate think moves to Playing once that has passed; the intro length is the
	// buy phase. The start time is refined below once the players are placed.
	float totalDuration = Arenas_BuyPhaseDuration()
	if ( file.roundNumber > 0 )
		totalDuration += ARENAS_POST_ROUND_SUMMARY_DURATION
	SetCustomIntroLength( totalDuration )

	if ( GetGameState() != eGameState.Prematch )
		SetGameState( eGameState.Prematch )
	SetGlobalNonRewindNetInt( "gameState", eGameState.Prematch )
	SetGlobalNonRewindNetInt( "roundsPlayed", file.roundNumber )

	// Start deathfield paused — ring visible at full size during buy phase. The round reset
	// regenerates the stage data on a thread; the ring must not start from a half-built set.
	FlagWait( "DeathFieldCalculationComplete" )
	FlagSet( "DeathCircleActive" )
	FlagSet( "DeathFieldPaused" )
	thread SURVIVAL_RunArenaDeathField()

	// Static ring netvars until combat activates shrinking
	SetGlobalNetInt( "currentDeathFieldStage", GetDeathFieldStartStage() )
	// The deathfield writes its own timers once it unpauses; until then show when it will.
	SetGlobalNetTime( "nextCircleStartTime", Time() + totalDuration + ARENAS_RING_ACTIVATION_DELAY )
	SetGlobalNetTime( "circleCloseTime", Time() + totalDuration + ARENAS_RING_ACTIVATION_DELAY )

	if ( ARENAS_DEV_MODE )
	{
		Arenas_DevMode_SetupPlayers()
		Arenas_SetStartZoneWalls( false )
		return
	}

	// Enable spawn room blockers
	Arenas_SetStartZoneWalls( true )

	// Reset and teleport all players BEFORE setting the timer,
	// so processing time doesn't eat into the buy phase duration.
	array<entity> allPlayers = GetPlayerArray()
	foreach ( entity player in allPlayers )
	{
		if ( !IsValid( player ) )
			continue

		// A knocked player from last round starts this one fresh.
		if ( IsAlive( player ) && Bleedout_IsBleedingOut( player ) )
			player.Die( svGlobal.worldspawn, svGlobal.worldspawn, { damageSourceId = eDamageSourceId.round_end } )

		// Respawn dead players; every round starts with the full squad. A respawn lands on a
		// generic map spawn point as a spectator class, so give the legend class and move the
		// player into the spawn room in the same frame.
		if ( !IsAlive( player ) )
		{
			ClearPlayerEliminated( player )
			if ( !DecideRespawnPlayer( player, false ) || !IsAlive( player ) )
				continue
			Arenas_SetupCharacter( player )
			Arenas_TeleportToSpawn( player )
		}

		// Unfreeze controls (frozen during WaitingForPlayers for safe parking)
		player.UnfreezeControlsOnServer()

		// Zoom minimap in for buy phase
		player.SetMinimapZoomScale( ARENAS_PREMATCH_MINIMAP_ZOOM, 0.0 )

		// Reset player state
		Arenas_ResetPlayerForRound( player )

		// Teleport to spawn room
		Arenas_TeleportToSpawn( player )
	}

	// Brief delay for respawns to settle
	wait 0.5

	// Fade from black after teleport (round 0 has no prior fade, but harmless to call)
	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			ScreenFadeFromBlack( player, 0.5, 0.0 )
	}

	// gameStartTime marks when combat begins. The client uses it to derive:
	//   summaryEndTime = gameStartTime - shopDuration  (post-round summary window)
	//   buyPhaseEndTime = gameStartTime                (buy menu countdown target)
	// For round 0 there is no summary, so gameStartTime = now + buyDuration.
	// For rounds > 0 we prepend the post-round summary window.
	// IMPORTANT: Set timer AFTER player processing so the full duration is available.
	file.buyPhaseEndTime = Time() + totalDuration
	SetGameStartTime( file.buyPhaseEndTime )
	SetGlobalNetTime( "arenas_buyMenuStartTime", Time() )

	// Notify all clients to open buy menu
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		ArenaPlayerData data = Arenas_GetPlayerData( player )

		// Send previous round's stats to the client for the cash breakdown display:
		// savedCash = unspent materials carried from last round
		// kills = kills scored in the last round (for kill bonus line)
		// canisters = canisters collected in the last round (for canister bonus line)
		Remote_CallFunction_NonReplay( player, "ServerCallback_DisplayArenasPrematch",
			file.leftTeam, file.rightTeam,
			data.materialsCarryover, data.killsLastRound, data.canistersLastRound )
	}
	Arenas_Announce( file.roundNumber == 0 ? "MATCH_INTRO" : "ROUND_PREPARE", GetPlayerArray(), 2.5 )

	file.roundAirdropContents = Arenas_PickAirdropContents()
	foreach ( entity player in GetPlayerArray() )
		Arenas_SendAirdropPreview( player )

	// Closing the shop does not end the buy phase; it can be reopened until the timer runs out.
	float endTime = file.buyPhaseEndTime
	while ( Time() < endTime )
	{
		if ( file.forceNextRound )
			break
		WaitFrame()
	}

	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) && player.IsBot() && IsAlive( player ) )
			Arenas_GiveBotLoadout( player )
	}

	// Timer expired: close buy menu and open doors immediately so the RUI
	// transition and door opening happen at the same moment for players.
	SetGlobalNetTime( "arenas_buyMenuStartTime", -1.0 )
	Arenas_SetStartZoneWalls( false )

	// Items were already granted immediately on purchase via Arenas_GrantItem.
	// Just save carryover materials for next round.
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue
		if ( player in file.playerData )
		{
			ArenaPlayerData data = file.playerData[player]
			data.materialsCarryover = data.materials
			file.playerData[player] = data
		}
	}
}

void function Arenas_SetupCharacter( entity player )
{
	array<ItemFlavor> playable
	foreach ( ItemFlavor c in GetAllCharacters() )
	{
		if ( ItemFlavor_GetAsset( c ) != CHARACTER_RANDOM )
			playable.append( c )
	}
	if ( playable.len() == 0 )
		return

	ItemFlavor character = playable.getrandom()
	if ( LoadoutSlot_IsReady( ToEHI( player ), Loadout_Character() ) )
	{
		asset current = ItemFlavor_GetAsset( LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() ) )
		foreach ( ItemFlavor c in playable )
		{
			if ( ItemFlavor_GetAsset( c ) == current )
				character = c
		}
	}
	SetItemFlavorLoadoutSlot( ToEHI( player ), Loadout_Character(), character )

	try
	{
		Survival_PlayerCharacterSetup( player, character, true )
	}
	catch ( err )
	{
		printt( "[Arenas] character setup failed:", player, err )
	}

	SURVIVAL_SetDefaultPlayerSettings( player )
	player.AmmoPool_SetCapacity( SURVIVAL_MAX_AMMO_PICKUPS )
	player.DisableAutoReloadNoAmmo()

	thread Arenas_RefreshSquadBuyMenus( player )
}

// Squadmate portraits and weapons in an open buy menu only redraw on a refresh.
void function Arenas_RefreshSquadBuyMenus( entity player )
{
	if ( !IsValid( player ) )
		return

	int team = player.GetTeam()
	WaitFrame()

	foreach ( entity teammate in GetPlayerArrayOfTeam( team ) )
	{
		if ( teammate == player || !IsValid( teammate ) || teammate.IsBot() )
			continue

		Remote_CallFunction_NonReplay( teammate, "ServerCallback_RefreshMenu" )
	}
}

const array<string> ARENAS_BOT_WEAPONS = [
	"mp_weapon_r97",
	"mp_weapon_wingman",
	"mp_weapon_rspn101",
	"mp_weapon_energy_shotgun",
	"mp_weapon_hemlok",
	"mp_weapon_pdw"
]

// Bots cannot shop; they get what a player would buy with the round's materials:
// two weapons whose tier rises with the round, grenades, and the ultimate later on.
void function Arenas_GiveBotLoadout( entity bot )
{
	string tier = ""
	if ( file.roundNumber >= 4 )
		tier = "_purpleset"
	else if ( file.roundNumber >= 2 )
		tier = "_blueset"
	else if ( file.roundNumber >= 1 )
		tier = "_whiteset"

	array<string> picks = clone ARENAS_BOT_WEAPONS
	picks.randomize()
	for ( int i = 0; i < 2; i++ )
	{
		string ref = picks[i] + tier
		Arenas_GrantItem( bot, SURVIVAL_Loot_IsRefValid( ref ) ? ref : picks[i] )
	}

	Arenas_GrantItem( bot, "mp_weapon_frag_grenade" )
	if ( file.roundNumber >= 2 )
		Arenas_GrantItem( bot, "arenas_full_ultimate" )
}

// Everyone starts with their tactical and its own ready charge; bought charges start empty.
// The store's startingCount column adds any free items on top.
void function Arenas_GrantStartingItems( entity player )
{
	var dataTable = GetDataTable( $"datatable/arenas/arenas_items.rpak" )
	int refColumn = GetDataTableColumnByName( dataTable, "ref" )
	int startColumn = GetDataTableColumnByName( dataTable, "startingCount" )
	int categoryColumn = GetDataTableColumnByName( dataTable, "category" )

	Arenas_EnsureTactical( player )

	for ( int row = 0; row < GetDataTableRowCount( dataTable ); row++ )
	{
		string ref = GetDataTableString( dataTable, row, refColumn )
		int count = GetDataTableInt( dataTable, row, startColumn )
		if ( count <= 0 )
			continue

		if ( GetDataTableString( dataTable, row, categoryColumn ) == "skills" )
			continue

		for ( int i = 0; i < count; i++ )
			Arenas_GrantItem( player, ref )
	}
}

// Bought tactical charges wait in the ability's stockpile; the buy menu counts clip plus
// stockpile against their maximums and calls the ability maxed once the stockpile is full.
int function Arenas_TacticalAmmoPerCharge( entity weapon )
{
	return maxint( 1, weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot ) ) * maxint( 1, weapon.GetWeaponSettingInt( eWeaponVar.burst_fire_count ) )
}

entity function Arenas_EnsureTactical( entity player )
{
	entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
	if ( IsValid( weapon ) )
		return weapon

	ItemFlavor character = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() )
	player.GiveOffhandWeapon( CharacterAbility_GetWeaponClassname( CharacterClass_GetTacticalAbility( character ) ), OFFHAND_TACTICAL, [] )
	weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
	if ( IsValid( weapon ) && weapon.GetWeaponPrimaryAmmoCountMax( AMMOSOURCE_STOCKPILE ) > 0 )
		weapon.SetWeaponPrimaryAmmoCount( AMMOSOURCE_STOCKPILE, 0 )
	return weapon
}

bool function Arenas_CanAddTacticalCharge( entity player )
{
	entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
	if ( !IsValid( weapon ) )
		return true

	int room = weapon.GetWeaponPrimaryAmmoCountMax( AMMOSOURCE_STOCKPILE ) - weapon.GetWeaponPrimaryAmmoCount( AMMOSOURCE_STOCKPILE )
	return room >= Arenas_TacticalAmmoPerCharge( weapon )
}

void function Arenas_AddTacticalCharges( entity player, int charges )
{
	entity weapon = Arenas_EnsureTactical( player )
	if ( !IsValid( weapon ) )
		return

	int stockpileMax = weapon.GetWeaponPrimaryAmmoCountMax( AMMOSOURCE_STOCKPILE )
	int stock = weapon.GetWeaponPrimaryAmmoCount( AMMOSOURCE_STOCKPILE ) + charges * Arenas_TacticalAmmoPerCharge( weapon )
	weapon.SetWeaponPrimaryAmmoCount( AMMOSOURCE_STOCKPILE, minint( maxint( stock, 0 ), stockpileMax ) )
}

// Tactical cooldown only refills from bought charges (the ammo_regen_takes_from_stockpile
// behaviour, which the server engine does not implement): every unit the cooldown adds is paid
// from the stockpile, and with the stockpile empty the clip stays where the player left it.
void function Arenas_TacticalChargeFeed_Thread()
{
	table<entity, int> lastClip

	while ( file.currentPhase == eArenaPhase.COMBAT && !file.matchOver )
	{
		foreach ( entity player in GetPlayerArray_Alive() )
		{
			entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
			if ( !IsValid( weapon ) )
				continue

			int clip = weapon.GetWeaponPrimaryClipCount()
			if ( !( weapon in lastClip ) )
			{
				lastClip[ weapon ] <- clip
				continue
			}

			int gained = clip - lastClip[ weapon ]
			if ( gained > 0 )
			{
				int stock = weapon.GetWeaponPrimaryAmmoCount( AMMOSOURCE_STOCKPILE )
				int paid = minint( gained, stock )
				weapon.SetWeaponPrimaryAmmoCount( AMMOSOURCE_STOCKPILE, stock - paid )
				if ( paid < gained )
				{
					clip = lastClip[ weapon ] + paid
					weapon.SetWeaponPrimaryClipCount( clip )
				}
			}
			lastClip[ weapon ] = clip
		}

		foreach ( entity weapon, int clipSeen in clone lastClip )
		{
			if ( !IsValid( weapon ) )
				delete lastClip[ weapon ]
		}
		wait 0.1
	}
}

void function Arenas_ResetPlayerForRound( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	// Full health restore
	if ( player.GetMaxHealth() > 0 )
		player.SetHealth( player.GetMaxHealth() )

	// Strip all weapons and inventory (clean slate for new buy phase)
	TakeAllWeapons( player )
	SetPlayerInventory( player, [] )

	// Give melee back
	player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )
	player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )

	// Emotes and holosprays ride these offhands.
	if ( GetCurrentPlaylistVarBool( "holosprays_enabled", true ) )
		player.GiveOffhandWeapon( HOLO_PROJECTOR_WEAPON_NAME, HOLO_PROJECTOR_INDEX )
	player.GiveOffhandWeapon( GENERIC_OFFHAND_WEAPON_NAME, GENERIC_OFFHAND_INDEX )

	// Abilities are NOT given for free - player must purchase them through buy menu
	// (tactical_upgrade, arenas_full_ultimate, buy_passive)

	// Give consumable slot (so heals are usable during buy phase if granted)
	player.GiveOffhandWeapon( CONSUMABLE_WEAPON_NAME, OFFHAND_SLOT_FOR_CONSUMABLES, [] )

	// Give default equipment (backpack, helmet, armor) so inventory and buy menu work during buy phase
	Survival_SetInventoryEnabled( player, true )
	Inventory_SetPlayerEquipment( player, "backpack_pickup_lv3", "backpack" )
	// Blue for rounds 1-2, purple after, red body shield in sudden death.
	string armor = file.roundNumber < 2 ? "armor_pickup_lv2" : "armor_pickup_lv3"
	string helmet = file.roundNumber < 2 ? "helmet_pickup_lv2" : "helmet_pickup_lv3"
	if ( file.numTies >= ARENAS_MAX_TIES )
		armor = "armor_pickup_lv5_evolving"
	Inventory_SetPlayerEquipment( player, helmet, "helmet" )
	Inventory_SetPlayerEquipment( player, armor, "armor" )

	// Shields fill after the armor sets their capacity.
	player.SetShieldHealth( player.GetShieldHealthMax() )

	// Nothing bought yet: the tactical with its own charge, plus any free starting items.
	player.SetPlayerNetInt( "passiveCharges", 0 )
	Arenas_GrantStartingItems( player )

	if ( player in file.playerData )
	{
		ArenaPlayerData cooldownData = file.playerData[player]
		player.SetPlayerNetInt( "ultimateCooldown", cooldownData.ultCooldownRounds )
		cooldownData.ultCooldownBeforePurchase = maxint( 0, cooldownData.ultCooldownRounds - 1 )
		cooldownData.ultCooldownRounds = cooldownData.ultCooldownBeforePurchase
		file.playerData[player] = cooldownData
	}

	// Reset elimination state (economy/selections cleared by Arenas_ResetEconomyForRound)
	if ( player in file.playerData )
	{
		ArenaPlayerData data = file.playerData[player]
		data.isEliminated = false
		file.playerData[player] = data
	}
}

void function Arenas_GiveLegendAbilities( entity player )
{
	if ( !IsValid( player ) )
		return

	// Give character's tactical and ultimate abilities
	ItemFlavor character = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() )
	ItemFlavor ultimateAbility = CharacterClass_GetUltimateAbility( character )
	ItemFlavor tacticalAbility = CharacterClass_GetTacticalAbility( character )

	player.GiveOffhandWeapon( CharacterAbility_GetWeaponClassname( tacticalAbility ), OFFHAND_TACTICAL, [] )
	player.GiveOffhandWeapon( CharacterAbility_GetWeaponClassname( ultimateAbility ), OFFHAND_ULTIMATE, [] )
}

void function Arenas_DevMode_SetupPlayers()
{

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		if ( !IsAlive( player ) )
		{
			DecideRespawnPlayer( player, false )
			wait 0.1
			if ( !IsValid( player ) || !IsAlive( player ) )
				continue
		}

		player.UnfreezeControlsOnServer()
		Arenas_ResetPlayerForRound( player )
		Arenas_TeleportToSpawn( player )

		// Give wingman + full ammo
		player.GiveWeapon( "mp_weapon_wingman", WEAPON_INVENTORY_SLOT_PRIMARY_0, [] )
		entity weapon = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		if ( IsValid( weapon ) )
		{
			weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
			player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		}

		// Give legend abilities
		Arenas_GiveLegendAbilities( player )

		// Give full armor and health
		player.SetHealth( player.GetMaxHealth() )
		player.SetShieldHealth( player.GetShieldHealthMax() )

		ScreenFadeFromBlack( player, 0.3, 0.0 )
	}
}

void function Arenas_TeleportToSpawn( entity player )
{
	if ( !IsValid( player ) )
		return

	int team = player.GetTeam()
	array<entity> spawns = ( team == file.leftTeam ) ? file.leftSpawns : file.rightSpawns

	if ( spawns.len() == 0 )
		return

	entity spawnEnt = spawns[0]
	vector spawnOrigin = spawnEnt.GetOrigin()
	vector spawnAngles = spawnEnt.GetAngles()

	// Spread players around the spawn location in a triangle formation
	array<entity> teammates = GetPlayerArrayOfTeam( team )
	int playerIndex = teammates.find( player )
	if ( playerIndex == -1 )
		playerIndex = 0

	// Apply offset relative to spawn facing direction
	vector offset = <0, 0, 0>
	if ( playerIndex < ARENAS_SPAWN_OFFSETS.len() )
		offset = ARENAS_SPAWN_OFFSETS[playerIndex]

	// Rotate offset by spawn facing angle
	vector forward = AnglesToForward( spawnAngles )
	vector right = AnglesToRight( spawnAngles )
	vector finalPos = spawnOrigin + ( forward * offset.y ) + ( right * offset.x )

	// The offsets are flat; settle the player's hull on whatever floor is under the spot,
	// and use the marker itself when the offset spot is blocked.
	vector placed = Arenas_GroundedSpawnPos( player, finalPos )
	if ( !PlayerCanTeleportHere( player, placed ) )
		placed = Arenas_GroundedSpawnPos( player, spawnOrigin )

	player.SetOrigin( placed )
	player.SetAngles( spawnAngles )
}

vector function Arenas_GroundedSpawnPos( entity player, vector pos )
{
	vector start = pos + <0, 0, 72>
	TraceResults result = TraceHull( start, pos - <0, 0, 256>, player.GetPlayerMins(), player.GetPlayerMaxs(), [ player ], TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )
	if ( result.startSolid || result.fraction >= 1.0 )
		return pos
	return result.endPos + <0, 0, 1>
}

void function Arenas_SetStartZoneWalls( bool enabled )
{
	foreach ( entity wall in file.startZoneBrushes )
	{
		if ( !IsValid( wall ) )
			continue

		if ( enabled )
		{
			wall.Solid()
			wall.MakeVisible()
			EmitSoundOnEntity( wall, ARENAS_SPAWNROOMWALL_SOUND_EVENT_NAME )
		}
		else
		{
			StopSoundOnEntity( wall, ARENAS_SPAWNROOMWALL_SOUND_EVENT_NAME )
			EmitSoundOnEntity( wall, ARENAS_SPAWNROOMWALL_DISSOLVE_SOUND )
			wall.NotSolid()
			wall.MakeInvisible()
		}
	}
}

// ============================================================================
// MATERIAL CANISTERS (Cash Stations)
// ============================================================================
void function Arenas_SpawnCanisters()
{
	// Clean up any existing canisters from a previous round
	Arenas_CleanupCanisters()

	foreach ( entity infoEnt in file.canisterInfoEnts )
	{
		if ( !IsValid( infoEnt ) )
			continue

		vector origin = infoEnt.GetOrigin()
		vector angles = infoEnt.GetAngles()

		// Create a usable prop_script at the canister position
		entity canister = CreatePropScript( CASH_STATION_MODEL_SMALL, origin, angles, 6 )

		if ( !IsValid( canister ) )
			continue

		canister.SetScriptName( CASH_STATION_SMALL_SCRIPTNAME )
		canister.SetUsable()
		canister.SetUsableByGroup( "pilot" )
		canister.SetUsablePriority( USABLE_PRIORITY_LOW )
		canister.SetUsePrompts( "#ARENAS_GET_CASH", "#ARENAS_GET_CASH" )
		AddCallback_OnUseEntity( canister, Arenas_OnCanisterUsed )

		thread PlayAnim( canister, "source_full_idle" )

		file.activeCanisters.append( canister )
	}

}

void function Arenas_CleanupCanisters()
{
	foreach ( entity canister in file.activeCanisters )
	{
		if ( IsValid( canister ) )
			canister.Destroy()
	}
	file.activeCanisters.clear()
}

// ============================================================================
// LOOT BINS
// ============================================================================
void function Arenas_SpawnLootBins()
{
	// Med loot bins contain healing items for mid-round recovery
	array<string> healingRefs = [
		"health_pickup_health_small",
		"health_pickup_health_large",
		"health_pickup_combo_small",
		"health_pickup_combo_large"
	]

	foreach ( entity locationEnt in file.medLootbinLocations )
	{
		if ( !IsValid( locationEnt ) )
			continue

		vector origin = locationEnt.GetOrigin()
		vector angles = locationEnt.GetAngles()

		// Spawn loot bin with random healing items (2-3 items per bin)
		int numItems = RandomIntRangeInclusive( 2, 3 )
		array<string> lootRefs
		for ( int i = 0; i < numItems; i++ )
			lootRefs.append( healingRefs.getrandom() )

		entity lootbin = CreateCustomLootBin( origin, angles, lootRefs )
		file.activeLootBins.append( lootbin )
	}
}

void function Arenas_CleanupLootBins()
{
	foreach ( entity lootbin in file.activeLootBins )
	{
		if ( IsValid( lootbin ) )
			lootbin.Destroy()
	}
	file.activeLootBins.clear()
}

// ============================================================================
// DEATHFIELD / RING MANAGEMENT
// ============================================================================
void function Arenas_ActivateRing()
{
	svGlobal.levelEnt.EndSignal( "GenerateDeathFieldData" )

	wait ARENAS_RING_ACTIVATION_DELAY

	if ( file.matchOver || file.currentPhase != eArenaPhase.COMBAT )
		return

	FlagClear( "DeathFieldPaused" )
}

void function Arenas_FreezeDeathfield()
{
	// Stop the deathfield stage loop, keep entities alive
	svGlobal.levelEnt.Signal( "GenerateDeathFieldData" )
	FlagClear( "SUR_DeathFieldShrinking" )
	FlagClear( "DeathCircleActive" )
	FlagSet( "DeathFieldPaused" )

	// Freeze ring at current interpolated radius
	int realm = Survival_Loot_GetDefaultRealm()
	DeathFieldData data = SURVIVAL_GetDeathFieldData( realm )

	float now = Time()
	float totalTime = data.endTime - data.startTime
	float frac = 0.0
	if ( totalTime > 0.0 )
		frac = clamp( (now - data.startTime) / totalTime, 0.0, 1.0 )
	float frozenRadius = data.startRadius + (data.endRadius - data.startRadius) * frac

	data.startRadius = frozenRadius
	data.endRadius = frozenRadius
	data.currentRadius = frozenRadius
	data.startTime = now
	data.endTime = now + 99999.0

	SetGlobalNetTime( "nextCircleStartTime", now + 99999.0 )
	SetGlobalNetTime( "circleCloseTime", now + 199999.0 )
}

void function Arenas_StopDeathfield()
{
	RoundBased_ResetDeathfield()
}

// ============================================================================
// CARE PACKAGE AIRDROPS
// ============================================================================
void function Arenas_AirdropTimer()
{
	svGlobal.levelEnt.EndSignal( "GenerateDeathFieldData" )

	wait ARENAS_AIRDROP_DELAY

	if ( file.matchOver || file.currentPhase != eArenaPhase.COMBAT )
		return

	Arenas_SpawnAirdrops()
}

array<string> function Arenas_PickAirdropContents()
{
	// One loot group or ref per pod door: a care package weapon and two fully kitted gold weapons.
	string contentList = GetCurrentPlaylistVarString( "arenas_airdrop_contents", ARENAS_DEFAULT_AIRDROP_CONTENTS )
	array<string> tokens = split( contentList, WHITESPACE_CHARACTERS )
	if ( tokens.len() != 3 )
		tokens = split( ARENAS_DEFAULT_AIRDROP_CONTENTS, WHITESPACE_CHARACTERS )

	array<string> contents
	foreach ( array<string> door in DetermineAirdropContents( [ [ tokens[0] ], [ tokens[1] ], [ tokens[2] ] ] ) )
		contents.append( door.len() > 0 ? door[0] : "" )
	return contents
}

void function Arenas_SendAirdropPreview( entity player )
{
	if ( !IsValid( player ) || file.airdropLocations.len() == 0 || file.roundAirdropContents.len() < 3 )
		return

	array<int> ids
	foreach ( string ref in file.roundAirdropContents )
		ids.append( SURVIVAL_Loot_IsRefValid( ref ) ? SURVIVAL_Loot_GetLootDataByRef( ref ).index : 0 )

	Remote_CallFunction_NonReplay( player, "ServerCallback_Arenas_UpdateAirdropPreview", ids[0], ids[1], ids[2] )
}

void function Arenas_SpawnAirdrops()
{
	foreach ( entity locationEnt in file.airdropLocations )
	{
		if ( !IsValid( locationEnt ) )
			continue

		vector origin = locationEnt.GetOrigin()
		vector angles = locationEnt.GetAngles()

		// One list per pod door (L, R, C); each door gets one item.
		array< array<string> > doorContents
		foreach ( string item in file.roundAirdropContents )
			doorContents.append( [ item ] )

		AirdropItemsOptionalInfo optionInfo
		optionInfo.animationName = ARENAS_AIRDROP_ANIMATION
		thread AirdropItems( origin, angles, doorContents, optionInfo )

	}
	if ( file.airdropLocations.len() > 0 )
		Arenas_Announce( "CARE_PACKAGE_DROPPING", GetPlayerArray() )

	// Announce care packages to all players via minimap ping
	if ( file.airdropLocations.len() > 0 && IsValid( file.airdropLocations[0] ) )
	{
		vector pingOrigin = file.airdropLocations[0].GetOrigin()
		foreach ( entity player in GetPlayerArray() )
		{
			if ( IsValid( player ) )
				Remote_CallFunction_NonReplay( player, "ServerCallback_SUR_PingMinimap", pingOrigin, 10.0, 500.0, 50.0, COLORID_AIRDROP_DEFAULT_COLOR, 0.8, 0.2, eAirdropType.STANDARD )
		}
	}
}

// Round wins ride team score 2, which every client score readout reads (Arenas_GetTeamWins).
void function Arenas_PublishTeamScores()
{
	foreach ( int team in [ file.leftTeam, file.rightTeam ] )
	{
		if ( team <= 0 )
			continue
		int wins = team == file.leftTeam ? file.leftTeamScore : file.rightTeamScore
		GameRules_SetTeamScore( team, wins )
		GameRules_SetTeamScore2( team, wins )
	}
}

void function Arenas_CleanupAirdrops()
{
	// The Pathfinder scan markers are only linked to their pod and would outlive it.
	DeleteCarepackagePerkLinks()

	// Includes pods still falling: destroying one ends its AirdropItems thread.
	foreach ( entity pod in GetEntArrayByScriptName( CARE_PACKAGE_SCRIPTNAME ) )
	{
		if ( IsValid( pod ) )
			pod.Destroy()
	}
}

void function Arenas_OnCanisterUsed( entity canister, entity player, int useInputFlags )
{
	if ( file.currentPhase != eArenaPhase.COMBAT )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !( player in file.playerData ) )
		return

	// Every member of the collector's squad gets the full reward.
	int reward = GetCurrentPlaylistVarInt( "arenas_cash_station_small_reward", ARENAS_CANISTER_REWARD )
	foreach ( entity teammate in GetPlayerArrayOfTeam( player.GetTeam() ) )
	{
		Arenas_AwardMaterials( teammate, reward )
		Arenas_SyncCashToClient( teammate )
		if ( teammate != player )
			Remote_CallFunction_NonReplay( teammate, "ServerCallback_Arenas_AnnounceResourcesCollected", reward )
	}

	// Track canister collection (both per-round and cumulative)
	ArenaPlayerData data = file.playerData[player]
	data.canistersThisRound++
	data.canistersThisMatch++
	file.playerData[player] = data

	// Prevent double-use; the emptied canister stays until the round cleanup
	canister.UnsetUsable()

	// Play collection sounds
	EmitSoundOnEntityOnlyToPlayer( canister, player, "Crafting_Extractor_Collect_1P" )
	PlayBattleChatterLineToSpeakerAndTeam( player, "bc_arenasMatsPickedUp" )
	EmitSoundOnEntityExceptToPlayer( canister, player, "Crafting_Extractor_Collect_3P" )

	// Notify client while entity is still alive (needed for remote call entity param)
	Remote_CallFunction_NonReplay( player, "ServerCallback_Arenas_AnnounceResourcesCollected", reward )
	Remote_CallFunction_NonReplay( player, "ServerToClient_OnUseCashStationSmall", canister, reward )


	thread Arenas_CanisterCollectedAnim( canister )
}

void function Arenas_CanisterCollectedAnim( entity canister )
{
	canister.EndSignal( "OnDestroy" )

	printt( "[Arenas] canister seq server: full_idle", canister.LookupSequence( "source_full_idle" ), "full_to_empty", canister.LookupSequence( "source_full_to_empty" ), "empty_idle", canister.LookupSequence( "source_empty_idle" ) )
	waitthread PlayAnim( canister, "source_full_to_empty" )
	thread PlayAnim( canister, "source_empty_idle" )
}

// ============================================================================
// LOADOUT GRANTING
// ============================================================================

// Determines if a loot ref is a main weapon (not ordnance, melee, or attachment).
// Uses the survival loot data system for proper classification.
bool function Arenas_IsWeaponRef( string ref )
{
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
	{
		LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
		return data.lootType == eLootType.MAINWEAPON
	}
	// Fallback: check prefix for weapons not in loot table
	return ref.find( "mp_weapon_" ) == 0
		&& ref.find( "melee" ) == -1
		&& ref.find( "frag_grenade" ) == -1
		&& ref.find( "thermite_grenade" ) == -1
		&& ref.find( "arc_star" ) == -1
		&& ref.find( "grenade_" ) == -1
}

// Determines if a loot ref is ordnance (grenades, arc stars, thermites).
bool function Arenas_IsOrdnanceRef( string ref )
{
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
	{
		LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
		return data.lootType == eLootType.ORDNANCE
	}
	return ref.find( "frag_grenade" ) != -1
		|| ref.find( "thermite_grenade" ) != -1
		|| ref.find( "arc_star" ) != -1
}

// Determines if a loot ref is a healing item (syringes, medkits, cells, batteries).
bool function Arenas_IsHealingRef( string ref )
{
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
	{
		LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
		return data.lootType == eLootType.HEALTH
	}
	return ref.find( "health_pickup_" ) == 0
}

// Gets the base weapon classname and mods array from a loot ref.
// For locked set weapons (whiteset/blueset/purpleset), the baseMods contain
// the tier mod which tells the engine what attachments to apply.
// Returns: [baseWeapon, modsArray]
string function Arenas_GetBaseWeaponFromRef( string ref )
{
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
	{
		LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
		if ( data.baseWeapon != "" )
			return data.baseWeapon
	}
	return ref
}

array<string> function Arenas_GetWeaponModsFromRef( string ref )
{
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
	{
		LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
		return clone data.baseMods
	}
	return []
}

// ============================================================================
// IMMEDIATE GRANT / REVOKE (called on buy/sell during buy phase)
// ============================================================================

// Grants a single item immediately when purchased during buy phase.
// Called from ClientCommand_Arenas_Select after materials are deducted.
void function Arenas_GrantItem( entity player, string ref )
{
	if ( !IsValid( player ) )
		return

	printt( "[Arenas GrantItem]", ref )

	// Tactical ability upgrade
	if ( ref == "tactical_upgrade" )
	{
		Arenas_AddTacticalCharges( player, 1 )
		return
	}

	// Full ultimate
	if ( ref == "arenas_full_ultimate" )
	{
		entity existingUlt = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
		if ( !IsValid( existingUlt ) )
		{
			ItemFlavor character = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() )
			ItemFlavor ultimateAbility = CharacterClass_GetUltimateAbility( character )
			player.GiveOffhandWeapon( CharacterAbility_GetWeaponClassname( ultimateAbility ), OFFHAND_ULTIMATE, [] )
		}
		player.SetPlayerNetInt( "ultimateCooldown", 0 )
		entity ultWeapon = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
		if ( IsValid( ultWeapon ) )
			ultWeapon.SetWeaponPrimaryClipCount( ultWeapon.GetWeaponPrimaryClipCountMax() )
		return
	}

	// Passive ability
	if ( ref == "buy_passive" )
	{
		int currentCharges = player.GetPlayerNetInt( "passiveCharges" )
		player.SetPlayerNetInt( "passiveCharges", currentCharges + 1 )
		return
	}

	// Ordnance (grenades) - use correct BR slot
	if ( Arenas_IsOrdnanceRef( ref ) )
	{
		string ordWeapon = Arenas_GetBaseWeaponFromRef( ref )
		SURVIVAL_AddToPlayerInventory( player, ref, 1 )

		entity existingOrd = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_ANTI_TITAN )
		if ( IsValid( existingOrd ) && existingOrd.GetWeaponClassName() == ordWeapon )
		{
			int count = SURVIVAL_CountItemsInInventory( player, ref )
			existingOrd.SetWeaponPrimaryClipCount( minint( count, existingOrd.GetWeaponPrimaryClipCountMax() ) )
		}
		else
		{
			if ( IsValid( existingOrd ) )
				player.TakeWeaponByEnt( existingOrd )
			player.GiveWeapon( ordWeapon, WEAPON_INVENTORY_SLOT_ANTI_TITAN, ["survival_finite_ordnance"] )
			entity newOrd = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_ANTI_TITAN )
			if ( IsValid( newOrd ) )
			{
				int count = SURVIVAL_CountItemsInInventory( player, ref )
				newOrd.SetWeaponPrimaryClipCount( minint( count, newOrd.GetWeaponPrimaryClipCountMax() ) )
			}
		}
		return
	}

	// Healing items
	if ( Arenas_IsHealingRef( ref ) )
	{
		SURVIVAL_AddToPlayerInventory( player, ref, 1 )
		return
	}

	// Weapons
	if ( Arenas_IsWeaponRef( ref ) )
	{
		string baseWeapon = Arenas_GetBaseWeaponFromRef( ref )

		// Check if player already has same base weapon (upgrade scenario)
		for ( int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0; slot <= WEAPON_INVENTORY_SLOT_PRIMARY_1; slot++ )
		{
			entity existing = player.GetNormalWeapon( slot )
			if ( !IsValid( existing ) )
				continue

			// Same upgrade line (a single and an akimbo pistol are different lines)
			if ( Arenas_WeaponLineRef( GetWeaponClassNameWithLockedSet( existing ) ) == Arenas_WeaponLineRef( ref ) )
			{
				// Same base weapon - upgrade in place: take old, give new with mods
				Arenas_TakeStoreWeapon( player, slot )
				Arenas_GiveStoreWeapon( player, ref, slot, false )
				Arenas_SelectStoreWeapon( player, slot )
				printt( "[Arenas GrantItem] Weapon upgraded in slot", slot )
				return
			}
		}

		// New weapon - find first free slot
		for ( int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0; slot <= WEAPON_INVENTORY_SLOT_PRIMARY_1; slot++ )
		{
			entity existing = player.GetNormalWeapon( slot )
			if ( IsValid( existing ) )
				continue

			Arenas_GiveStoreWeapon( player, ref, slot, true )
			Arenas_SelectStoreWeapon( player, slot )
			printt( "[Arenas GrantItem] Weapon given to slot", slot )
			return
		}

		printt( "[Arenas GrantItem] No free weapon slot for:", ref )
		return
	}

	// Fallback
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
		SURVIVAL_AddToPlayerInventory( player, ref, 1 )
}

// A store weapon ref is a base weapon or one of its locked sets; the set is a weapon property
// both VMs read back as the tier, not a mod. A new purchase also brings its reserve ammo.
entity function Arenas_GiveStoreWeapon( entity player, string ref, int slot, bool giveAmmo )
{
	entity weapon = player.GiveWeapon( Arenas_GetBaseWeaponFromRef( ref ), slot, Arenas_GetWeaponModsFromRef( ref ) )
	if ( !IsValid( weapon ) )
		return null

	if ( SURVIVAL_Loot_IsRefValid( ref ) )
		SetWeaponLockedSetFromLootTags( SURVIVAL_Loot_GetLootDataByRef( ref ).lootTags, weapon )

	if ( weapon.UsesClipsForAmmo() )
		weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
	player.AmmoPool_SetCapacity( 999 )
	if ( giveAmmo )
		Arenas_ChangeReserveAmmo( player, weapon, Arenas_GetWeaponStartingAmmo( ref ) )

	if ( Arenas_IsAkimboLine( ref ) && CanWeaponAkimbo( weapon.GetWeaponClassName() ) )
		Arenas_GiveAkimboPartner( player, weapon, ref )
	return weapon
}

// The partner hand is a second copy in the dual-primary slot with the same mods and set.
void function Arenas_GiveAkimboPartner( entity player, entity weapon, string ref )
{
	int dualSlot = weapon.GetInventoryIndex() + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0
	if ( IsValid( player.GetNormalWeapon( dualSlot ) ) )
		player.TakeNormalWeaponByIndexNow( dualSlot )

	entity partner = player.GiveWeapon( weapon.GetWeaponClassName(), dualSlot, weapon.GetMods(), false )
	if ( !IsValid( partner ) )
		return

	if ( SURVIVAL_Loot_IsRefValid( ref ) )
		SetWeaponLockedSetFromLootTags( SURVIVAL_Loot_GetLootDataByRef( ref ).lootTags, partner )
	if ( partner.UsesClipsForAmmo() )
		partner.SetWeaponPrimaryClipCount( partner.GetWeaponPrimaryClipCountMax() )
}

void function Arenas_TakeStoreWeapon( entity player, int slot )
{
	int dualSlot = slot + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0
	if ( IsValid( player.GetNormalWeapon( dualSlot ) ) )
		player.TakeNormalWeaponByIndexNow( dualSlot )
	player.TakeNormalWeaponByIndexNow( slot )
}

void function Arenas_SelectStoreWeapon( entity player, int slot )
{
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, slot )

	int dualSlot = slot + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0
	if ( IsValid( player.GetNormalWeapon( dualSlot ) ) )
	{
		player.ClearFirstDeployForAllWeapons()
		player.SetActiveWeaponBySlot( eActiveInventorySlot.altHand, dualSlot )
	}
}

void function Arenas_ChangeReserveAmmo( entity player, entity weapon, int delta )
{
	int ammoType = weapon.GetWeaponAmmoPoolType()
	if ( ammoType < 0 || delta == 0 )
		return

	string ammoRef = AmmoType_GetRefFromIndex( ammoType )
	if ( !SURVIVAL_Loot_IsRefValid( ammoRef ) )
		return

	if ( delta > 0 )
		SURVIVAL_AddToPlayerInventory( player, ammoRef, delta )
	else
		SURVIVAL_RemoveFromPlayerInventory( player, ammoRef, minint( -delta, SURVIVAL_CountItemsInInventory( player, ammoRef ) ) )

	player.AmmoPool_SetCount( ammoType, SURVIVAL_CountItemsInInventory( player, ammoRef ) )
}

// Revokes a single item immediately when sold during buy phase.
// Called from ClientCommand_Arenas_Unselect after materials are refunded.
void function Arenas_RevokeItem( entity player, string ref, ArenaPlayerData data )
{
	if ( !IsValid( player ) )
		return

	printt( "[Arenas RevokeItem]", ref )

	// Tactical ability
	if ( ref == "tactical_upgrade" )
	{
		Arenas_AddTacticalCharges( player, -1 )
		return
	}

	// Full ultimate
	// Selling restores the state from before the purchase; the purchase was only allowed off cooldown.
	if ( ref == "arenas_full_ultimate" )
	{
		player.SetPlayerNetInt( "ultimateCooldown", 0 )
		entity ult = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
		if ( IsValid( ult ) )
		{
			if ( data.ultClipBeforePurchase < 0 )
				player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
			else
				ult.SetWeaponPrimaryClipCount( minint( data.ultClipBeforePurchase, ult.GetWeaponPrimaryClipCountMax() ) )
		}
		return
	}

	// Passive ability
	if ( ref == "buy_passive" )
	{
		int currentCharges = player.GetPlayerNetInt( "passiveCharges" )
		player.SetPlayerNetInt( "passiveCharges", maxint( 0, currentCharges - 1 ) )
		return
	}

	// Ordnance
	if ( Arenas_IsOrdnanceRef( ref ) )
	{
		SURVIVAL_RemoveFromPlayerInventory( player, ref, 1 )
		int remaining = SURVIVAL_CountItemsInInventory( player, ref )
		entity ordWeapon = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_ANTI_TITAN )
		if ( remaining <= 0 )
		{
			if ( IsValid( ordWeapon ) )
				player.TakeWeaponByEnt( ordWeapon )
		}
		else if ( IsValid( ordWeapon ) )
		{
			ordWeapon.SetWeaponPrimaryClipCount( minint( remaining, ordWeapon.GetWeaponPrimaryClipCountMax() ) )
		}
		return
	}

	// Healing items
	if ( Arenas_IsHealingRef( ref ) )
	{
		SURVIVAL_RemoveFromPlayerInventory( player, ref, 1 )
		return
	}

	// Weapons
	if ( Arenas_IsWeaponRef( ref ) )
	{
		string baseWeapon = Arenas_GetBaseWeaponFromRef( ref )

		// Find which slot has this weapon
		for ( int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0; slot <= WEAPON_INVENTORY_SLOT_PRIMARY_1; slot++ )
		{
			entity existing = player.GetNormalWeapon( slot )
			if ( !IsValid( existing ) )
				continue
			if ( Arenas_WeaponLineRef( GetWeaponClassNameWithLockedSet( existing ) ) != Arenas_WeaponLineRef( ref ) )
				continue

			// Check if there's a lower tier still purchased for same base weapon
			string remainingRef = Arenas_GetHighestRemainingTier( data, baseWeapon, ref )
			if ( remainingRef == "" )
				Arenas_ChangeReserveAmmo( player, existing, -Arenas_GetWeaponStartingAmmo( ref ) )

			Arenas_TakeStoreWeapon( player, slot )
			if ( remainingRef != "" )
			{
				Arenas_GiveStoreWeapon( player, remainingRef, slot, false )
				Arenas_SelectStoreWeapon( player, slot )
				printt( "[Arenas RevokeItem] Downgraded to:", remainingRef )
			}
			else
			{
				printt( "[Arenas RevokeItem] Weapon removed from slot", slot )
			}
			return
		}
		return
	}

	// Fallback
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
		SURVIVAL_RemoveFromPlayerInventory( player, ref, 1 )
}

// Finds the highest tier weapon ref still in selectedItems for the given base weapon,
// excluding a specific ref (the one being sold). Returns "" if none found.
string function Arenas_GetHighestRemainingTier( ArenaPlayerData data, string baseWeapon, string excludeRef )
{
	string bestRef = ""
	int bestTier = -1

	foreach ( ArenasSelectedItem item in data.selectedItems )
	{
		if ( item.ref == excludeRef )
			continue
		if ( !Arenas_IsWeaponRef( item.ref ) )
			continue

		if ( Arenas_WeaponLineRef( item.ref ) != Arenas_WeaponLineRef( excludeRef ) )
			continue

		// Determine tier from loot data
		int tier = 0
		if ( SURVIVAL_Loot_IsRefValid( item.ref ) )
		{
			LootData lootData = SURVIVAL_Loot_GetLootDataByRef( item.ref )
			tier = lootData.tier
		}

		if ( tier > bestTier )
		{
			bestTier = tier
			bestRef = item.ref
		}
	}

	return bestRef
}

// ============================================================================
// COMBAT PHASE
// ============================================================================
void function Arenas_CombatPhase()
{
	file.currentPhase = eArenaPhase.COMBAT
	SetGameState( eGameState.Playing )
	SetGlobalNonRewindNetInt( "gameState", eGameState.Playing )

	// Log team state at combat start for debugging
	array<entity> leftAll = GetPlayerArrayOfTeam( file.leftTeam )
	array<entity> rightAll = GetPlayerArrayOfTeam( file.rightTeam )

	// A side with nobody on it cannot lose a fight: scoring it lets a lone player win, and a draw
	// never advances the match. End the match on the current score instead.
	if ( leftAll.len() == 0 || rightAll.len() == 0 )
	{
		file.matchOver = true
		return
	}

	// Walls already opened at end of BuyPhase (synced with client RUI timer)

	// Zoom minimap out for combat
	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			player.SetMinimapZoomScale( ARENAS_DEFAULT_MINIMAP_ZOOM, 1.0 )
	}

	// Reset first blood flag for this round
	file.firstBloodThisRound = false

	// Spawn material canisters and loot bins for this round
	Arenas_SpawnCanisters()
	Arenas_SpawnLootBins()

	// Notify all clients that combat has begun (per-player announcement style)
	Arenas_SendRoundStartAnnouncement()

	// Round start battle chatter
	Arenas_AnnounceRoundStart()

	thread Arenas_TacticalChargeFeed_Thread()

	// Activate ring shrink after delay
	thread Arenas_ActivateRing()

	// Care package airdrop timer
	if ( file.airdropLocations.len() > 0 )
		thread Arenas_AirdropTimer()

	// Wait for one team to be eliminated or timeout
	float combatStartTime = Time()
	bool roundResolved = false

	while ( !roundResolved )
	{
		// Force next round via debug command
		if ( file.forceNextRound )
		{
			file.forceNextRound = false
			Arenas_RoundEnd( file.leftTeam )
			roundResolved = true
			break
		}

		// Check if either team is fully eliminated
		array<entity> leftAlive = GetPlayerArrayOfTeam_Alive( file.leftTeam )
		array<entity> rightAlive = GetPlayerArrayOfTeam_Alive( file.rightTeam )

		if ( leftAlive.len() == 0 && rightAlive.len() == 0 )
		{
			// Both teams eliminated simultaneously - draw/tie
			Arenas_RoundEnd( 0 ) // 0 = draw
			roundResolved = true
		}
		else if ( leftAlive.len() == 0 )
		{
			// Left team eliminated - right team wins
			Arenas_RoundEnd( file.rightTeam )
			roundResolved = true
		}
		else if ( rightAlive.len() == 0 )
		{
			// Right team eliminated - left team wins
			Arenas_RoundEnd( file.leftTeam )
			roundResolved = true
		}

		if ( !roundResolved )
			WaitFrame()
	}
}

// ============================================================================
// ROUND END
// ============================================================================
void function Arenas_RoundEnd( int winningTeam )
{
	file.currentPhase = eArenaPhase.ROUND_END

	// Clean up any remaining canisters, loot bins, airdrops
	Arenas_CleanupCanisters()
	Arenas_CleanupLootBins()
	Arenas_CleanupAirdrops()

	// Freeze ring in place (stays visible during round-end celebration)
	Arenas_FreezeDeathfield()

	// Clean up player abilities, tracked projectiles (traps, gas, drones, etc.), and deathboxes
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		PROTO_CleanupTrackedProjectiles( player )
		player.Signal( "CleanUpPlayerAbilities" )
	}

	// Destroy all deathboxes
	array<entity> deathboxes = GetEntArrayByClass_Expensive( "prop_death_box" )
	foreach ( entity deathbox in deathboxes )
	{
		if ( IsValid( deathbox ) )
			deathbox.Destroy()
	}

	// Destroy all dropped loot
	array<entity> droppedLoot = GetEntArrayByClass_Expensive( "prop_survival" )
	foreach ( entity loot in droppedLoot )
	{
		if ( IsValid( loot ) )
			loot.Destroy()
	}

	int leftBefore = file.leftTeamScore
	int rightBefore = file.rightTeamScore

	// A draw scores nothing. A tie at match point or beyond (3-3, 4-4) counts toward the
	// tiebreaker limit; the last one makes the next round sudden death.
	if ( winningTeam != 0 )
	{
		if ( winningTeam == file.leftTeam )
			file.leftTeamScore++
		else
			file.rightTeamScore++

		if ( file.leftTeamScore == file.rightTeamScore && file.leftTeamScore >= ARENAS_ROUNDS_TO_WIN )
		{
			file.numTies++
			SetGlobalNetInt( "arenas_numties", file.numTies )
		}

		file.lastWonTeam = winningTeam
		SetGlobalNetInt( "arenas_lastWonTeam", winningTeam )

		Arenas_PublishTeamScores()
	}

	// Determine round won descriptor
	int roundWonDesc = Arenas_GetRoundWonDescriptor( winningTeam )

	// Notify clients
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		if ( winningTeam == 0 )
		{
			// Draw round - display as lost for everyone
			Remote_CallFunction_NonReplay( player, "ServerCallback_DisplayRoundLost" )
		}
		else if ( player.GetTeam() == winningTeam )
		{
			Remote_CallFunction_NonReplay( player, "ServerCallback_DisplayRoundWon", roundWonDesc )
		}
		else
		{
			Remote_CallFunction_NonReplay( player, "ServerCallback_DisplayRoundLost" )
		}
	}

	// Round end battle chatter
	Arenas_AnnounceRoundEnd( winningTeam, roundWonDesc, leftBefore, rightBefore )

	wait ARENAS_ROUND_END_DELAY

	// Check match end conditions
	if ( Arenas_CheckMatchEnd() )
	{
		file.matchOver = true
		Arenas_StopDeathfield()
		return
	}

	// Fade to black before round restart (players will be teleported during black screen)
	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			ScreenFadeToBlack( player, 1.0, ARENAS_ROUND_RESTART_DELAY + 1.0 )
	}

	// Wait for fade before destroying ring
	wait 1.0

	Arenas_StopDeathfield()

	wait ARENAS_ROUND_RESTART_DELAY - 1.0
}

int function Arenas_GetRoundWonDescriptor( int winningTeam )
{
	if ( winningTeam == 0 )
		return eArenasRoundWonDescriptor.DEFAULT

	// Check for perfect round (winning team took no damage)
	bool perfectRound = true
	bool flawlessRound = true

	array<entity> winners = GetPlayerArrayOfTeam( winningTeam )
	foreach ( entity player in winners )
	{
		if ( !IsValid( player ) )
			continue
		if ( player in file.playerData )
		{
			// If anyone on the winning team died, not perfect
			if ( file.playerData[player].isEliminated )
				perfectRound = false
		}
		// Check health - if any damage taken at all, not flawless
		if ( IsAlive( player ) && player.GetHealth() < player.GetMaxHealth() )
			flawlessRound = false
	}

	// Check for clutch (1 alive vs full team)
	array<entity> aliveWinners = GetPlayerArrayOfTeam_Alive( winningTeam )
	int losingTeam = ( winningTeam == file.leftTeam ) ? file.rightTeam : file.leftTeam
	array<entity> losingTeamPlayers = GetPlayerArrayOfTeam( losingTeam )

	if ( aliveWinners.len() == 1 && losingTeamPlayers.len() >= 3 )
		return eArenasRoundWonDescriptor.CLUTCH

	if ( flawlessRound )
		return eArenasRoundWonDescriptor.FLAWLESS

	if ( perfectRound )
		return eArenasRoundWonDescriptor.PERFECT

	return eArenasRoundWonDescriptor.DEFAULT
}

bool function Arenas_CheckMatchEnd()
{
	// First to three with a two-round lead; after the last tiebreaker (4-4) the next
	// round wins outright.
	if ( file.numTies >= ARENAS_MAX_TIES )
		return file.leftTeamScore != file.rightTeamScore

	int best = maxint( file.leftTeamScore, file.rightTeamScore )
	int lead = best - minint( file.leftTeamScore, file.rightTeamScore )
	return best >= ARENAS_ROUNDS_TO_WIN && lead >= 2
}

// ============================================================================
// MATCH END
// ============================================================================
void function Arenas_MatchEnd()
{
	file.currentPhase = eArenaPhase.MATCH_END

	// Signal to client that the match is complete (used by Arenas_IsMatchComplete())
	SetGlobalNonRewindNetBool( "roundScoreLimitComplete", true )

	int winningTeam = 0
	if ( file.leftTeamScore > file.rightTeamScore )
		winningTeam = file.leftTeam
	else if ( file.rightTeamScore > file.leftTeamScore )
		winningTeam = file.rightTeam


	// Match end battle chatter
	Arenas_AnnounceMatchEnd( winningTeam )

	// Set winning team so GetWinningTeam() works on client for champion screen
	SetWinningTeam( winningTeam )

	// Send winning squad data for champion screen display.
	// First clear existing data, then populate with each winning team member's stats.
	array<entity> winningPlayers = GetPlayerArrayOfTeam( winningTeam )
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		// Clear previous squad data
		Remote_CallFunction_NonReplay( player, "ServerCallback_AddWinningSquadData", -1, -1, 0, 0, 0, 0, 0, 0, 0, false, 0, 0, 0, 0, 0, 0 )

		// Send each winning team member's stats
		foreach ( int idx, entity winner in winningPlayers )
		{
			if ( !IsValid( winner ) )
				continue

			int kills = 0
			int damage = 0
			if ( winner in file.playerData )
			{
				ArenaPlayerData data = file.playerData[winner]
				kills = data.killsThisMatch
				damage = winner.GetPlayerNetInt( "damageDealt" )
			}

			Remote_CallFunction_NonReplay( player, "ServerCallback_AddWinningSquadData",
				idx, winner.GetEncodedEHandle(), kills, 0, 0, damage, 0, 0, 0, false, 0, 0, 0, 0, 0, 0 )
		}
	}

	// Make all players invincible and show champion screen
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		MakeInvincible( player )
		Remote_CallFunction_NonReplay( player, "ServerCallback_MatchEndAnnouncement", player.GetTeam() == winningTeam, winningTeam )
	}

	wait ARENAS_MATCH_END_DELAY

	// Trigger the victory sequence (3D character poses)
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue
		Remote_CallFunction_NonReplay( player, "ServerCallback_ShowWinningSquadSequence" )
		Arenas_Announce( "INTRO_CHAMPION_CARD", [ player ], 1.0 )
	}

	// End the match via game state transition. The map change below ends it; the stock
	// round-based winner think would otherwise send everyone back to legend select.
	SetCustomWinnerDeterminedLength( 9999.0 )
	// Arenas runs its own rounds; the stock round-based WinnerDetermined branch would score and
	// eliminate for another round. The match is over, so end it as a single-round match.
	SetRoundBased( false )
	SetGameState( eGameState.WinnerDetermined )
	SetGlobalNonRewindNetInt( "gameState", eGameState.WinnerDetermined )

	// After the champion screen the server rotates to the next arenas map.
	wait 15.0
	string nextMap = Tracker_DetermineNextMap()
	if ( nextMap == "" || !Tracker_IsSafeMapName( nextMap ) )
		nextMap = GetMapName()
	GameRules_ChangeMap( nextMap, GetCurrentPlaylistName() )
}

// ============================================================================
// PLAYER KILL TRACKING
// ============================================================================
void function Arenas_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{

	if ( file.currentPhase != eArenaPhase.COMBAT )
		return

	if ( !IsValid( victim ) )
		return

	thread Arenas_FinishDownedSquad( victim.GetTeam() )

	// Mark player as eliminated
	if ( victim in file.playerData )
	{
		ArenaPlayerData data = file.playerData[victim]
		data.isEliminated = true
		file.playerData[victim] = data
	}

	// Track kill for attacker and award kill bonus materials
	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim )
	{
		if ( attacker.GetTeam() != victim.GetTeam() )
		{
			if ( attacker in file.playerData )
			{
				ArenaPlayerData attackerData = file.playerData[attacker]
				attackerData.killsThisRound++
				attackerData.killsThisMatch++
				attackerData.materials = minint( attackerData.materials + GetCurrentPlaylistVarInt( "arenas_kill_reward", ARENAS_KILL_REWARD ), ARENAS_MAX_CASH )
				file.playerData[attacker] = attackerData
				Arenas_SyncCashToClient( attacker )

				// Sync kills to client netvar for HUD display
				attacker.SetPlayerNetInt( "kills", attackerData.killsThisMatch )
			}

			if ( !file.firstBloodThisRound )
			{
				file.firstBloodThisRound = true
				Arenas_Announce( "FIRST_BLOOD", GetPlayerArray(), ARENAS_ONKILL_BC_DELAY )
			}
			else if ( attacker in file.playerData )
			{
				int kills = file.playerData[attacker].killsThisRound
				if ( kills == 2 )
					Arenas_Announce( "DOUBLE_KILL", GetPlayerArray(), ARENAS_ONKILL_BC_DELAY )
				else if ( kills == 3 )
					Arenas_Announce( "TRIPLE_KILL", GetPlayerArray(), ARENAS_ONKILL_BC_DELAY )
			}
		}
	}

	// Note: Team elimination check happens in the combat phase loop
	// via GetPlayerArrayOfTeam_Alive() polling
}

// Bleedout ends a squad when its last standing member is knocked; this covers the
// last standing member being killed outright while the others are down.
void function Arenas_FinishDownedSquad( int team )
{
	WaitFrame()
	foreach ( entity player in GetPlayerArrayOfTeam_Alive( team ) )
	{
		if ( !Bleedout_IsBleedingOut( player ) )
			return
	}
	foreach ( entity player in GetPlayerArrayOfTeam_Alive( team ) )
		Bleedout_PlayerDiesFromBleedout( player )
}

// ============================================================================
// DAMAGE TRACKING
// ============================================================================
void function Arenas_OnPlayerDamaged( entity victim, var damageInfo )
{
	if ( file.currentPhase != eArenaPhase.COMBAT )
		return

	if ( !IsValid( victim ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	int damage = int( DamageInfo_GetDamage( damageInfo ) )

	if ( damage <= 0 )
		return

	// Track damage dealt by attacker
	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim )
	{
		if ( attacker.GetTeam() != victim.GetTeam() && attacker in file.playerData )
		{
			ArenaPlayerData attackerData = file.playerData[attacker]
			attackerData.damageThisRound += damage
			file.playerData[attacker] = attackerData

			// Sync damage to client netvar for HUD display (accumulates across match)
			attacker.SetPlayerNetInt( "damageDealt", attacker.GetPlayerNetInt( "damageDealt" ) + damage )
		}
	}
}

// ============================================================================
// TEAM ELIMINATION CHECK (for disconnects during combat)
// ============================================================================
void function Arenas_CheckTeamEliminated()
{
	wait 0.1 // Brief yield to let disconnect process

	if ( file.currentPhase != eArenaPhase.COMBAT )
		return

	// The combat loop will naturally detect the elimination
	// via GetPlayerArrayOfTeam_Alive() returning 0
}

// ============================================================================
// BUY SYSTEM SERVER CALLBACKS
// ============================================================================
// Buy flow:
// 1. Client clicks item in buy menu
// 2. Client sends "Arenas_Select <idx> <cost> <ref>" via ClientCommand
// 3. Server validates affordability, deducts materials, tracks selection
// 4. Server syncs arenas_current_cash netvar -> client OnCurrentCashChanged -> UI refresh
// 5. Server sends ServerCallback_FinishedProcessingClickEvent to unblock UI

// ============================================================================
// ANNOUNCE STYLE PER-PLAYER (server sends appropriate style to each player)
// ============================================================================
// ============================================================================
// ANNOUNCER (Ash) AND LEGEND CHATTER
// ============================================================================
void function Arenas_LoadAnnouncerLines()
{
	var dataTable = GetDataTable( $"datatable/arenas/arenas_host_dialogue.rpak" )
	int nameColumn = GetDataTableColumnByName( dataTable, "name" )
	int bucketColumn = GetDataTableColumnByName( dataTable, "bucket" )
	for ( int row = 0; row < GetDataTableRowCount( dataTable ); row++ )
	{
		string name = GetDataTableString( dataTable, row, nameColumn )
		string bucket = GetDataTableString( dataTable, row, bucketColumn )
		if ( name == "" || bucket == "" || bucket == "string" )
			continue
		if ( !( bucket in file.announcerLines ) )
			file.announcerLines[ bucket ] <- []
		if ( !file.announcerLines[ bucket ].contains( name ) )
			file.announcerLines[ bucket ].append( name )
	}
}

void function Arenas_Announce( string bucket, array<entity> players, float delay = 0.0 )
{
	if ( !( bucket in file.announcerLines ) || players.len() == 0 )
		return
	thread Arenas_AnnounceThread( file.announcerLines[ bucket ].getrandom(), clone players, delay )
}

void function Arenas_AnnounceThread( string line, array<entity> players, float delay )
{
	if ( delay > 0 )
		wait delay
	foreach ( entity player in players )
	{
		if ( IsValid( player ) )
			PlayDialogueForPlayer_NoWait( line, player, null, COMMENTARY_ANNOUNCER_DIALOGUE_FLAGS )
	}
}

void function Arenas_TeamChatter( int team, string line )
{
	array<entity> alive = GetPlayerArrayOfTeam_Alive( team )
	if ( alive.len() > 0 )
		PlayBattleChatterLineToSpeakerAndTeam( alive.getrandom(), line )
}

void function Arenas_AnnounceRoundStart()
{
	int left = file.leftTeamScore
	int right = file.rightTeamScore
	bool suddenDeath = file.numTies >= ARENAS_MAX_TIES

	string bucket = "ROUND" + minint( file.roundNumber + 1, 9 )
	if ( suddenDeath )
		bucket = "SUDDEN_DEATH"
	else if ( file.roundNumber >= 8 )
		bucket = "ROUND_FINAL"
	Arenas_Announce( bucket, GetPlayerArray(), ARENAS_ROUNDSTART_BC_DELAY )

	if ( file.roundNumber == 0 )
	{
		Arenas_TeamChatter( file.leftTeam, "bc_arenasMatchStart" )
		Arenas_TeamChatter( file.rightTeam, "bc_arenasMatchStart" )
		return
	}
	if ( suddenDeath )
		return

	int minWin = ARENAS_ROUNDS_TO_WIN
	if ( left == right && left >= minWin - 1 )
	{
		Arenas_Announce( "MATCH_POINT_TIED", GetPlayerArray(), ARENAS_ROUNDSTART_BC_DELAY + 3.0 )
		Arenas_TeamChatter( file.leftTeam, "bc_arenasMatchPoint" )
		Arenas_TeamChatter( file.rightTeam, "bc_arenasMatchPoint" )
		return
	}
	foreach ( int team in [ file.leftTeam, file.rightTeam ] )
	{
		int mine = team == file.leftTeam ? left : right
		int theirs = team == file.leftTeam ? right : left
		if ( mine >= minWin - 1 && mine > theirs )
		{
			Arenas_Announce( "MATCH_POINT_SQUAD", GetPlayerArrayOfTeam( team ), ARENAS_ROUNDSTART_BC_DELAY + 3.0 )
			Arenas_TeamChatter( team, "bc_arenasMatchPointSquad" )
		}
		else if ( theirs >= minWin - 1 && theirs > mine )
		{
			Arenas_Announce( "MATCH_POINT_ENEMY", GetPlayerArrayOfTeam( team ), ARENAS_ROUNDSTART_BC_DELAY + 3.0 )
			Arenas_TeamChatter( team, "bc_arenasMatchPointEnemy" )
		}
	}
}

void function Arenas_AnnounceRoundEnd( int winningTeam, int roundWonDesc, int leftBefore, int rightBefore )
{
	if ( winningTeam == 0 )
		return

	int losingTeam = winningTeam == file.leftTeam ? file.rightTeam : file.leftTeam
	string wonBucket = "ROUND_WON"
	if ( roundWonDesc == eArenasRoundWonDescriptor.FLAWLESS )
		wonBucket = "ROUND_FLAWLESS"
	else if ( roundWonDesc == eArenasRoundWonDescriptor.PERFECT )
		wonBucket = "ROUND_PERFECT"
	else if ( roundWonDesc == eArenasRoundWonDescriptor.CLUTCH )
		wonBucket = "ROUND_CLUTCH"
	Arenas_Announce( wonBucket, GetPlayerArrayOfTeam( winningTeam ), ARENAS_ROUNDEND_BC_DELAY )
	Arenas_Announce( "ROUND_LOST", GetPlayerArrayOfTeam( losingTeam ), ARENAS_ROUNDEND_BC_DELAY )

	if ( Arenas_CheckMatchEnd() )
		return

	int left = file.leftTeamScore
	int right = file.rightTeamScore
	int lead = maxint( left, right ) - minint( left, right )
	int leadBefore = maxint( leftBefore, rightBefore ) - minint( leftBefore, rightBefore )
	if ( left == right && leadBefore >= 2 )
		Arenas_Announce( "MATCH_COMEBACK", GetPlayerArrayOfTeam( winningTeam ), ARENAS_ROUNDEND_BC_DELAY + 3.0 )
	else if ( lead >= 2 )
		Arenas_Announce( "ONE_TEAM_WINNING", GetPlayerArray(), ARENAS_ROUNDEND_BC_DELAY + 3.0 )
	else if ( minint( left, right ) >= 1 && lead <= 1 )
		Arenas_Announce( "SCORE_CLOSE", GetPlayerArray(), ARENAS_ROUNDEND_BC_DELAY + 3.0 )
}

void function Arenas_AnnounceMatchEnd( int winningTeam )
{
	if ( winningTeam == 0 )
	{
		Arenas_Announce( "WINNER", GetPlayerArray(), ARENAS_MATCHEND_COMMENTARY_DEALY )
		return
	}

	int losingTeam = winningTeam == file.leftTeam ? file.rightTeam : file.leftTeam
	int winnerScore = winningTeam == file.leftTeam ? file.leftTeamScore : file.rightTeamScore
	int loserScore = winningTeam == file.leftTeam ? file.rightTeamScore : file.leftTeamScore
	string bucket = "WINNER"
	if ( loserScore == 0 )
		bucket = "MATCH_SHUTOUT"
	else if ( winnerScore - loserScore >= 3 )
		bucket = "MATCH_STOMP"
	Arenas_Announce( bucket, GetPlayerArrayOfTeam( winningTeam ), ARENAS_MATCHEND_COMMENTARY_DEALY )
	Arenas_Announce( "WINNER", GetPlayerArrayOfTeam( losingTeam ), ARENAS_MATCHEND_COMMENTARY_DEALY )
}

void function Arenas_SendRoundStartAnnouncement()
{
	int leftScore = file.leftTeamScore
	int rightScore = file.rightTeamScore
	int minWinScore = ARENAS_ROUNDS_TO_WIN

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		int announceStyle = eArenasRoundStartAnnounce.ROUND_NUM

		// Sudden death
		if ( file.numTies >= ARENAS_MAX_TIES )
		{
			announceStyle = eArenasRoundStartAnnounce.SUDDEN_DEATH
		}
		// Tiebreaker
		else if ( leftScore == rightScore && leftScore + 1 >= minWinScore )
		{
			announceStyle = eArenasRoundStartAnnounce.TIEBREAKER
		}
		// Match point
		else
		{
			int myTeam = player.GetTeam()
			int myScore = ( myTeam == file.leftTeam ) ? leftScore : rightScore
			int enemyScore = ( myTeam == file.leftTeam ) ? rightScore : leftScore

			bool enemyMatchPoint = enemyScore >= (minWinScore - 1) && enemyScore - myScore >= 1
			bool myMatchPoint = myScore >= (minWinScore - 1) && myScore - enemyScore >= 1

			if ( enemyMatchPoint )
				announceStyle = eArenasRoundStartAnnounce.MATCHPOINT_ENEMY
			else if ( myMatchPoint )
				announceStyle = eArenasRoundStartAnnounce.MATCHPOINT_YOU
		}

		Remote_CallFunction_NonReplay( player, "ServerCallback_Arenas_AnnounceRoundStart", announceStyle )
	}
}

// ============================================================================
// CLIENT COMMAND HANDLERS (Buy System)
// ============================================================================
// Client-sent numbers; anything that is not a plain non-negative integer is -1.
int function Arenas_ParseClientInt( string arg )
{
	if ( arg == "" || arg.len() > 9 )
		return -1

	for ( int i = 0; i < arg.len(); i++ )
	{
		if ( "0123456789".find( arg.slice( i, i + 1 ) ) == -1 )
			return -1
	}

	return arg.tointeger()
}

// The client marks an item bought before it asks; every answer releases its click lock, and a
// refusal also drops that optimistic selection.
void function ClientCommand_Arenas_Select( entity player, array<string> args )
{
	// Expected args: <index> <cost> <ref>
	if ( !IsValid( player ) || args.len() < 3 )
		return

	if ( !Arenas_TrySelect( player, args[2] ) )
	{
		int clientIndex = Arenas_ParseClientInt( args[0] )
		if ( clientIndex >= 0 && clientIndex <= ARENAS_MAX_STORE_INDEX )
			Remote_CallFunction_NonReplay( player, "ServerCallback_Arenas_SelectRejected", clientIndex )
	}

	Remote_CallFunction_NonReplay( player, "ServerCallback_FinishedProcessingClickEvent" )
}

bool function Arenas_TrySelect( entity player, string ref )
{
	if ( file.currentPhase != eArenaPhase.BUY_PHASE || !( player in file.playerData ) )
		return false

	string storeRef = Arenas_FindStoreRef( player, ref )
	if ( storeRef == "" || DoesPlayerOwnMaxItems( player, storeRef ) || !Arenas_HasUpgradePrereq( player, storeRef ) )
		return false

	int cost = Arenas_GetItemCostByRef( player, ref )
	if ( cost < 0 || cost > ARENAS_MAX_CASH )
		return false

	ArenaPlayerData data = file.playerData[player]

	if ( ref == "tactical_upgrade" || ref == "arenas_full_ultimate" || ref == "buy_passive" )
	{
		int refCount = 0
		foreach ( sel in data.selectedItems )
			if ( sel.ref == ref )
				refCount++

		int maxCount = 1
		if ( ref == "tactical_upgrade" )
			maxCount = GetCurrentPlaylistVarInt( "arenas_max_tactical_upgrades", 2 )

		if ( refCount >= maxCount )
			return false

		if ( ref == "tactical_upgrade" && !Arenas_CanAddTacticalCharge( player ) )
			return false

		if ( ref == "arenas_full_ultimate" )
		{
			if ( player.GetPlayerNetInt( "ultimateCooldown" ) > 0 )
				return false
			entity ult = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
			if ( IsValid( ult ) && ult.GetWeaponPrimaryClipCount() >= ult.GetWeaponPrimaryClipCountMax() )
				return false
		}
	}

	if ( data.materials < cost )
		return false

	data.materials -= cost
	ArenasSelectedItem selection
	selection.ref = ref
	selection.cost = cost
	data.selectedItems.append( selection )
	if ( ref == "arenas_full_ultimate" )
	{
		data.ultCooldownRounds = Arenas_GetItemMaxCount( player, ref )
		entity ultBefore = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
		data.ultClipBeforePurchase = IsValid( ultBefore ) ? ultBefore.GetWeaponPrimaryClipCount() : -1
	}
	file.playerData[player] = data

	for ( int i = Arenas_GetItemCountToGive( player, ref ); i > 0; i-- )
		Arenas_GrantItem( player, ref )

	// Syncing cash refreshes the buyer's menu through OnCurrentCashChanged.
	Arenas_SyncCashToClient( player )
	thread Arenas_RefreshSquadBuyMenus( player )
	return true
}

void function ClientCommand_Arenas_Unselect( entity player, array<string> args )
{
	// Expected args: <index> <cost> <ref>
	if ( !IsValid( player ) || args.len() < 3 )
		return

	Arenas_TryUnselect( player, args[2] )
	Remote_CallFunction_NonReplay( player, "ServerCallback_FinishedProcessingClickEvent" )
}

void function Arenas_TryUnselect( entity player, string ref )
{
	if ( file.currentPhase != eArenaPhase.BUY_PHASE || !( player in file.playerData ) )
		return

	// The refund is what the server charged, never what the client sends.
	ArenaPlayerData data = file.playerData[player]
	int cost = -1
	for ( int i = 0; i < data.selectedItems.len(); i++ )
	{
		if ( data.selectedItems[i].ref == ref )
		{
			cost = data.selectedItems[i].cost
			data.selectedItems.remove( i )
			break
		}
	}

	if ( cost < 0 )
		return

	data.materials = minint( data.materials + cost, ARENAS_MAX_CASH )
	if ( ref == "arenas_full_ultimate" )
		data.ultCooldownRounds = data.ultCooldownBeforePurchase
	file.playerData[player] = data

	for ( int i = Arenas_GetItemCountToGive( player, ref ); i > 0; i-- )
		Arenas_RevokeItem( player, ref, data )

	Arenas_SyncCashToClient( player )
	thread Arenas_RefreshSquadBuyMenus( player )
}

void function ClientCommand_Arenas_SetOptic( entity player, array<string> args )
{
	if ( !IsValid( player ) || args.len() < 2 )
		return

	if ( file.currentPhase != eArenaPhase.BUY_PHASE )
		return

	int weaponIndex = Arenas_ParseClientInt( args[0] )
	if ( !SURVIVAL_Loot_IsLootIndexValid( weaponIndex ) )
		return

	// -1 clears the sight; otherwise it must be a sight attachment.
	int opticIndex = args[1] == "-1" ? -1 : Arenas_ParseClientInt( args[1] )
	string optic = ""
	if ( opticIndex != -1 )
	{
		if ( !SURVIVAL_Loot_IsLootIndexValid( opticIndex ) )
			return
		LootData opticData = SURVIVAL_Loot_GetLootDataByIndex( opticIndex )
		if ( opticData.lootType != eLootType.ATTACHMENT || opticData.attachmentStyle.find( "sight" ) < 0 )
			return
		optic = opticData.ref
	}

	LootData weaponData = SURVIVAL_Loot_GetLootDataByIndex( weaponIndex )
	string baseWeapon = weaponData.baseWeapon != "" ? weaponData.baseWeapon : weaponData.ref
	if ( !weaponData.supportedAttachments.contains( "sight" ) )
		return

	for ( int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0; slot <= WEAPON_INVENTORY_SLOT_PRIMARY_1; slot++ )
	{
		entity weapon = player.GetNormalWeapon( slot )
		if ( !IsValid( weapon ) || weapon.GetWeaponClassName() != baseWeapon )
			continue

		array<string> mods
		foreach ( string mod in weapon.GetMods() )
		{
			if ( !SURVIVAL_Loot_IsRefValid( mod ) || SURVIVAL_Loot_GetLootDataByRef( mod ).attachmentStyle.find( "sight" ) < 0 )
				mods.append( mod )
		}
		if ( optic != "" )
			mods.append( optic )
		weapon.SetMods( mods )

		entity partner = player.GetNormalWeapon( slot + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0 )
		if ( IsValid( partner ) )
			partner.SetMods( mods )
		return
	}
}

void function ClientCommand_Arenas_ChangeWeaponTab( entity player, array<string> args )
{
	if ( !IsValid( player ) || args.len() < 1 )
		return

	// Tab change is client-side only, server just acknowledges
	return
}

void function ClientCommand_Arenas_ForceNextRound( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return

	if ( !GetDeveloperLevel() )
		return

	file.forceNextRound = true
	return
}

// ============================================================================
// EQUIPMENT NETVAR SETUP
// ============================================================================
// Sets arenas_available_equipment_0..10 global netvars so the client buy menu
// knows which store indices to display in the heal/ordnance/ability slots.
// Called directly from Arenas_ServerGamemode_Init (loot datatables already loaded by then).
//
// UI layout expects:
//   Slots 0-2 = Ability section  (tactical_upgrade, arenas_full_ultimate, buy_passive)
//   Slots 3-10 = Consumable section (heals, ordnance, utility items)
//
// The datatable row order may not match this layout, so we sort items
// by type before assigning them to slots.
void function Arenas_SetEquipmentNetvars()
{
	// The client builds store indices as:
	//   [0..N-1] = weapons from SURVIVAL_Loot_GetLootDataTable() (MAINWEAPON entries)
	//   [N..N+M-1] = rows from arenas_items datatable
	// We need to count weapons the same way the client does to get the offset.

	table<string, LootData> allLootData = SURVIVAL_Loot_GetLootDataTable()
	array<string> disabledWeapons = split( GetCurrentPlaylistVarString( "survival_disabled_weapons", "" ).tolower(), " " )

	int weaponCount = 0
	foreach ( ref, data in allLootData )
	{
		if ( data.lootType != eLootType.MAINWEAPON || ref.find( WEAPON_LOCKEDSET_SUFFIX_GOLD ) >= 0 )
			continue
		if ( data.baseMods.contains( WEAPON_LOCKEDSET_MOD_CRATE ) )
			continue
		if ( disabledWeapons.contains( data.baseWeapon ) )
			continue
		weaponCount++
	}


	// Read arenas_items datatable (same one the client reads)
	var dataTable = GetDataTable( $"datatable/arenas/arenas_items.rpak" )
	int numRows = GetDataTableRowCount( dataTable )


	// Separate items into abilities and consumables.
	// The client UI has hardcoded expectations:
	//   Slot 0 = buy_passive       (Ability_0 in UI)
	//   Slot 1 = tactical_upgrade  (Ability_1 in UI, also read by arenas_player_tactical)
	//   Slot 2 = arenas_full_ultimate (Ability_2 in UI, also read by arenas_player_ultimate)
	//   Slots 3-10 = consumable items (Equipment_0..7 in UI)
	int passiveRow = -1
	int tacticalRow = -1
	int ultimateRow = -1
	array<int> consumableRows

	for ( int i = 0; i < numRows; i++ )
	{
		string itemRef = GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "ref" ) )
		if ( itemRef == "buy_passive" )
			passiveRow = i
		else if ( itemRef == "tactical_upgrade" )
			tacticalRow = i
		else if ( itemRef == "arenas_full_ultimate" )
			ultimateRow = i
		else
			consumableRows.append( i )

	}

	// Assign abilities to their fixed slots
	if ( passiveRow != -1 )
	{
		SetGlobalNetInt( "arenas_available_equipment_0", weaponCount + passiveRow )
	}
	if ( tacticalRow != -1 )
	{
		SetGlobalNetInt( "arenas_available_equipment_1", weaponCount + tacticalRow )
	}
	if ( ultimateRow != -1 )
	{
		SetGlobalNetInt( "arenas_available_equipment_2", weaponCount + ultimateRow )
	}

	// Assign consumables to slots 3-10
	int slotIndex = 3
	foreach ( int row in consumableRows )
	{
		if ( slotIndex >= 11 )
			break
		int storeIndex = weaponCount + row
		SetGlobalNetInt( "arenas_available_equipment_" + slotIndex, storeIndex )
		string itemRef = GetDataTableString( dataTable, row, GetDataTableColumnByName( dataTable, "ref" ) )
		slotIndex++
	}

	int abilityCount = ( passiveRow != -1 ? 1 : 0 ) + ( tacticalRow != -1 ? 1 : 0 ) + ( ultimateRow != -1 ? 1 : 0 )
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================
ArenaPlayerData function Arenas_GetPlayerData( entity player )
{
	if ( player in file.playerData )
		return file.playerData[player]

	ArenaPlayerData data
	return data
}

float function Arenas_BuyPhaseDuration()
{
	return GetCurrentPlaylistVarFloat( "arenas_shop_duration", 30.0 )
}
