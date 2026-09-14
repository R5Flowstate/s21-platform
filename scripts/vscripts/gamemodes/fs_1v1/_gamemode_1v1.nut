// Flowstate 1v1. CafeFPS (makimakima, mkos).

//The file is properly organized by sections
// Section 1: File Header & Global Declarations
// Section 2: Structs, Enums & Constants
// Section 3: Initialization & Setup
// Section 4: Main Callbacks
// Section 5: -> moved to _1v1_commands.nut
// Section 6: Player State Management
// Section 7-9: -> moved to _1v1_matchmaking.nut
// Section 10-11: -> moved to _1v1_match.nut
// Section 12: -> moved to _1v1_challenge.nut
// Section 13: -> moved to _1v1_spectate.nut
// Section 14: -> moved to _1v1_weapons.nut
// Section 15: -> moved to _1v1_legend.nut
// Section 16: -> moved to _1v1_realm.nut
// Section 17: -> moved to _1v1_ui.nut
// Section 18: Helper/Utility Functions (remaining)
  
//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 1: FILE HEADER & GLOBAL DECLARATIONS
// File header, global declarations, and includes
//
//═══════════════════════════════════════════════════════════════════════════════

// Global declarations for functions implemented in THIS file
global function _Gamemode1v1Standalone_Init

global function FS1v1_OnEntitiesDidLoad
global function FS_1v1_ApplyWaitingRoomForMap
global function FS_1v1_WaitingRoomEngineSpawn
global function FS_1v1_RateSpawnpoints
global function FS_1v1_InstallWaitingRoomEngineSpawns
global function FS_1v1_PickWaitingRoomLoc
global function FS_1v1_SpawnPairDesc

global function Gamemode1v1_IsPlayerResting
global function Gamemode1v1_IsPlayerWaiting
global function Gamemode1v1_IsPlayerInChallenge
global function Gamemode1v1_IsPlayerInState
global function Gamemode1v1_Init
global function Gamemode1v1_SetPlayerGamestate
global function Gamemode1v1_GetPlayerGamestate
global function FS_1v1_ApplyLobbyCinematicHudFlags
global function Gamemode1v1_GetNumberOfGroupsInProgress
global function Gamemode1v1_GetNumberOfPlayersInGroupMap

global function AddEntityCallback_OnPlayerGamestateChange_1v1
global function RemoveEntityCallback_OnPlayerGamestateChange_1v1

global function DecideToggleCollision_Rest
global function IsPlayerInProgress
global function IsPlayerInSoloMode
global function getTimeOutPlayer
global function getTimeOutPlayerAmount
global function OnWeaponAttachmentChanged
global function GetCurrentRound
global function GetBlackListedWeapons
global function Scoreboard1v1_PackName
global function Scoreboard1v1_WriteRanks
global function FS_1v1_PublishConnectedCount

// Global data shared across modules
global table<int, string> weaponlist_1v1
global typedef PanelTable table<string, entity>
global const bool DEBUG_STATE		= false
// Post-fight queue: keep short so rematches start quickly (was 2.0 / magic +3.0).
global const float penaltyDuration = 0.5
global const float QUEUE_TIMEOUT_EXTRA = 1.0

// TryCreateOneMatch outcome. FAILED means this one pair cannot be created right now,
// not that the queue is done -- the pass excludes the pair and keeps going.
global const int FS_1V1_PAIR_NONE = 0
global const int FS_1V1_PAIR_CREATED = 1
global const int FS_1V1_PAIR_FAILED = 2
global const int MAX_REALM = 63
// Warn while there is still room to act; 120 players run 60 of the 63 slots.
global const int FS_1V1_REALM_LOW_WATERMARK = 6
global const float FS_1V1_SPECTATE_COOLDOWN = 2.0
// Notification panel placement when a map ships no panels row: out in front of
// the waiting-room spawn, a little above eye level.
global const float FS_1V1_PANEL_FORWARD_DIST = 250.0
global const float FS_1V1_PANEL_HEIGHT = 80.0
global array<string> STANDARD_INV_LOOT = ["health_pickup_combo_small", "health_pickup_health_small"]

global const int DEFAULT_WAITING_ROOM_RADIUS = 2500
const int FS_1V1_MIN_GENERATED_WAITING_SPOTS = 4
global const int DEFAULT_MAX_FIGHT_DISTANCE = 2000
global const int RING_DISABLED_RADIUS = 99999
global const int MAX_AMMO_CAPACITY = 65535
global const float RESPAWN_DELAY_1V1 = 0.1
global const float ROUND_END_GRACE_DEFAULT = 10.0
global const int INITIAL_GROUP_ID = 112250000

global table<string,int> characterRefMap =
{
	["725342087"] 	= 0,	//"Bangalore",
	["898565421"] 	= 1,	//"Bloodhound",
	["1111853120"] 	= 2,	//"Caustic",
	["182221730"] 	= 3,	//"Gibraltar",
	["1409694078"] 	= 4,	//"Lifeline",
	["2045656322"] 	= 5,	//"Mirage",
	["843405508"] 	= 6,	//"Octane",
	["1464849662"] 	= 7,	//"Pathfinder",
	["827049897"] 	= 8,	//"Wraith",
	["187386164"] 	= 9,	//"Wattson",
	["80232848"] 	= 10 	//"Crypto",
}
global array<int> LEGEND_GUID_ENABLED_ULTIMATES =
[
	898565421, //ref character_bloodhound
	187386164, //ref character_wattson
	2045656322, //ref character_mirage
	843405508, //ref character_octane
	827049897, //ref character_wraith
	1464849662, //ref character_pathfinder
]

global function DEV_printlegends
global function DEV_legend
global function DEV_acceptchal
global function DEV_allchals
global function DEV_acceptedchallenges
global function DEV_GetGamestateRef
global function DEV_PrintGameStates
global function DEV_rest


//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 2: STRUCTS, ENUMS & CONSTANTS
// Data structures and constant definitions
//
//═══════════════════════════════════════════════════════════════════════════════

global struct LocationsData
{
	array<LocPair> respawnLocations
	vector Center
	entity Panel //keep current opponent panel //(mk):not used
	string info //(mk): game behavior defining meta data.
	string ids
}

global struct groupStats 
{
	entity player
	string displayname
	float damage = 0
	int hits = 0
	int shots = 0
	int kills = 0
	int deaths = 0
	int headshots = 0
}

global struct MatchGroup
{
	int groupHandle
	entity player1
	entity player2
	
	int player1_handle
	int player2_handle
	
	int p1LegendIndex = -1
	int p2LegendIndex = -1
	
	entity ring//ring boundaries
	LocationsData &groupLocStruct

	int slotIndex
	bool inputLocked = false //(mk): lock group to their input
	bool boundaryMonitorRunning = false //one per group, not one per respawn
	bool inputWatchdogRunning = false //ditto: a challenge re-arms every round
	bool IsFinished = false //player1 or player2 has died, handled by HandleGroupIsFinished via OnPlayerKilled callback
	bool IsKeep = false //player may want to play with current opponent,so we will keep this group
	bool cycle = true //(mk): locked 1v1s can choose to cycle spawns
	bool swap = true //(mk): locked 1v1s can have random side they spawn on
	
	bool isValid = false 
	
	float startTime
	table <entity,groupStats> statsRecap
	
	entity winner
	bool vsHudThread = false
}

global struct QueuedPlayer
{
	entity player
	int handle
	float queue_time = 0.0 //(mk):marks the time when they queued, to allow checking for same input
	bool ibmmTimeoutReached = false //(mk):input based match making timeout 
	bool showWaitingMsg = true
	float waitingTime //players may want to play with random opponent(or a matched opponent), so adding a waiting time after they died can allow server to match proper opponent
	float kd //stored this player's kd to help server match proper opponent
	entity lastOpponent //opponent of last round
	bool IsTimeOut = false
	float victimPenaltyExpire
	int latencyMs = 0 //sampled once per matchmaking pass, not per candidate pair
}

global struct ChallengesStruct
{
	entity player
	table<int,float> challengers = {} // challenging entity handle, float Time
	bool isValid
}

//this is fine
global array <LocationsData> arenaLocations //all respawn location stored here


global struct _1v1FileStruct
{
	int state = 0

	float waitingRoomRadius = 600
	float season_kd_weight
	float current_kd_weight
	float SBMM_kd_difference

	//playerHandle -> QueuedPlayer
	table <int, QueuedPlayer > waitingQueue = {} //moved to table for O(1) add/delete/lookup without shifting arrays, looping/scanning

	//playerHandle -> MatchGroup
	table< int, MatchGroup > playerMatchMap = {} //map for quick assessment

	//groupHandle -> MatchGroup
	table< int, MatchGroup > activeMatches = {} //group map to group

	//playerHandle -> struct resting
	table< int, bool > restingPlayers = {}

	bool APlayerHasMessage = false

	array< ChallengesStruct > allChallenges
	table< int, entity > acceptedChallenges //(player handle challenger -> player challenged )
	table< string, float > chalLastSent

	bool bRestEnabled = false

	// One resting-panel refresh per frame: each refresh costs a reliable remote
	// per character of the count text, per resting player.
	bool restingNotifyPending = false

	array< bool > realmSlots
	float realmLowNextLog = 0.0
	bool realmExhaustedLogged = false
	table< int, int > spectatorRealm = {}

	// Track last spawn group index per player (playerHandle -> groupIndex)
	// Prevents players from spawning at same location back-to-back
	table< int, int > playerLastSpawnGroup = {}

	array< string > Weapons
	array< string > WeaponsSecondary
	array< string > LongRangeWeapons
	array< string > LongRangeWeaponsSecondary

	LocPair WaitingRoom
	entity waitingRoomStartSpawn
	bool waitingRoomSpawnsInstalled = false
	int hazardBlockLogCount = 0
	float restGrace

	vector notificationPanel_Coordinates
	vector notificationPanel_Angles

	// Matchmaking throttle (was 0.5s -- cut so requeue fires faster after penalty timers)
	bool matchmakingPending = false
	bool matchmakingReady = false
	float lastMatchmakingTime = 0
	float MATCHMAKING_COOLDOWN = 0.15

	// Clients with FSLeaderboard open. Names skip when roster fingerprint matches.
	table< int, bool > scoreboardOpenClients = {}
	table< int, int > scoreboardNameFp = {}
	table< int, int > scoreboardCardFp = {}
	table< int, int > scoreboardSyncSeq = {}
	table< int, float > scoreboardResyncTime = {}
	table< int, array<int> > scoreboardCardGuids = {}
	table< int, float > scoreboardCardGuidsAt = {}
	array<int> sbHashes
	array<int> sbN1s
	array<int> sbN2s
	array<int> sbN3s
	array<int> sbN4s
	array<int> sbKdPing
	array<int> sbDmgFlags
	array<int> sbSlots
	array<int> sbCards
	array<int> sbHandles

	// Players currently opted out of the map's hazard triggers.
	table< entity, bool > triggerExemptPlayers

	// Ordered kill log shipped with the session stats. Rating is computed host-side.
	array<string> duelLog

	// Standalone round tracking and tgive blacklists
	int currentRound = 1
	string lastChampionUID = ""
	array<string> blacklistedWeapons
	array<string> blacklistedAbilities

	#if DEVELOPER
		bool DEBUG_MATCHMAKING = false
	#endif
	table< string, int > e1v1StateNameToIntMap = {}
	table< int, string > e1v1StateIDToNameMap = {}

}

global _1v1FileStruct file

global struct _1v1SettingsStruct
{
	array<string> hostSetAttachments
	array<string> Weapons = []

	int ibmm_wait_limit = 30 //deprecate
	float default_ibmm_wait = 0 //deprecate
	bool enableChallenges = false
	int groupID = INITIAL_GROUP_ID
	bool bGiveSameRandomLegendToBothPlayers = false
	bool bAllowLegend = false
	bool bAllowAbilities = false
	bool bChalServerMsg = false
	bool bEnableStreaks = true
	bool customWeaponsChallengeOnly = false
	bool isScenariosMode
	float roundTime
	bool bAllowWeaponsMenu
	int playerMaxFightDistance = DEFAULT_MAX_FIGHT_DISTANCE
	int give_weapon_stack_count_amount
	bool player_collision_enabled
	bool player_rest_collision_enabled
	bool allow_legend_select
	bool enableHelmets
	bool giveSkinsWeapons
	bool enableCosmetics
	bool bNoPrimary
	bool bNoSecondary
	bool bNoPrimaryLongrange
	bool bNoSecondaryLongrange
	float matchFoundDelay = 0.2

}

global _1v1SettingsStruct settings

global array<LocPair> g_waitingRoomSpawnLocations
global const int MAX_CHALLENGERS = 3
global const float CHALLENGE_OFFER_TTL = 20.0
global const float CHALLENGE_SEND_COOLDOWN = 10.0

//TODO: unite this in a singular modular framework
global array<string> LEGEND_INDEX_ARRAY =
[
		"Bangalore", //0
		"Bloodhound", //1
		"Caustic", //2
		"Gibby", //3
		"Lifeline", //4
		"Mirage", //5
		"Octane", //6
		"Pathfinder", //7
		"Wraith", //8
		"Wattson", //9
		"Crypto", //10
		
		"Blisk", //11
		"Fade", //12
		"Amogus", //13
		
		"Rhapsody", //14
		"Ash", //15
		"Jack", //16
		"Loba", //17 --
		"Revenant", //18
		"Ballistic", //19
		"Marvin", //20
		"Pete", //21
	];

//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 3: INITIALIZATION & SETUP
// Game initialization and setup functions
//
//═══════════════════════════════════════════════════════════════════════════════

// FSDM-compat round counter (file.currentRound driven by _Run1v1).
int function GetCurrentRound()
{
	return file.currentRound
}

array<string> function GetBlackListedWeapons()
{
	return file.blacklistedWeapons
}

// Populates flowstateSettings struct from playlist vars (equivalent to DM's InitializePlaylistSettings)
void function _InitializePlaylistSettings1v1()
{
	flowstateSettings.ForceCharacter = GetCurrentPlaylistVarBool( "flowstateForceCharacter", GetCurrentPlaylistName() == "fs_1v1" )
	flowstateSettings.is_halo_gamemode 						= GetCurrentPlaylistVarBool( "is_halo_gamemode", false )
	flowstateSettings.RandomCharacterOnSpawn 				= GetCurrentPlaylistVarBool( "flowstateRandomCharacterOnSpawn", false )
	flowstateSettings.GiveAllOpticsToPlayer 				= GetCurrentPlaylistVarBool( "flowstateGiveAllOpticsToPlayer", false )
	flowstateSettings.hackersVsPros 						= GetCurrentPlaylistVarBool( "flowstate_hackersVsPros", false )
	flowstateSettings.enable_afk_thread 					= GetCurrentPlaylistVarBool( "enable_afk_thread", true )
	flowstateSettings.enable_ping_kick 						= GetCurrentPlaylistVarBool( "enable_ping_kick", false )
	SetAfkToRest( GetCurrentPlaylistVarBool( "afk_to_rest_bool", true ) )
	flowstateSettings.aimassist_magnet_pc 					= GetCurrentPlaylistVarFloat( "aimassist_magnet_pc", 0.0 )
	flowstateSettings.BattleLogEnable 						= GetCurrentPlaylistVarBool( "flowstateBattleLogEnable", false )
	flowstateSettings.BattleLog_Linux 						= GetCurrentPlaylistVarBool( "flowstateBattleLog_Linux", false )
	flowstateSettings.custom_match_ending_title 			= GetCurrentPlaylistVarString( "custom_match_ending_title", "Server clean up incoming" )
	flowstateSettings.custom_match_ending_message 			= GetCurrentPlaylistVarString( "custom_match_ending_message", "Don't leave. Server is going to reload to avoid lag." )
	flowstateSettings.end_match_message 					= GetCurrentPlaylistVarBool( "end_match_message",true )
	flowstateSettings.rotate_map 							= GetCurrentPlaylistVarBool( "rotate_map", false )
	flowstateSettings.maplist 								= GetCurrentPlaylistVarString( "maplist", "" )
	flowstateSettings.ring_radius_padding 					= GetCurrentPlaylistVarFloat( "ring_radius_padding", 800 )
	flowstateSettings.Admins 								= GetCurrentPlaylistVarString( "Admins", "" )
	flowstateSettings.enable_oddball_gamemode 				= GetCurrentPlaylistVarBool( "enable_oddball_gamemode", false )
	flowstateSettings.default_ibmm_wait 					= GetCurrentPlaylistVarFloat( "default_ibmm_wait", 0 )
	flowstateSettings.ReloadTacticalOnRespawn 				= GetCurrentPlaylistVarBool( "flowstateReloadTacticalOnRespawn", false )
	flowstateSettings.ReloadUltimateOnRespawn 				= GetCurrentPlaylistVarBool( "flowstateReloadUltimateOnRespawn", false )
	flowstateSettings.RandomHaloGuns 						= GetCurrentPlaylistVarBool( "flowstateRandomHaloGuns", false )
	flowstateSettings.DroppodsOnPlayerConnected 			= GetCurrentPlaylistVarBool( "flowstateDroppodsOnPlayerConnected", false )
	flowstateSettings.EndlessFFAorTDM 						= GetCurrentPlaylistVarBool( "flowstateEndlessFFAorTDM", false )
	flowstateSettings.endgame_delay 						= GetCurrentPlaylistVarInt( "endgame_delay", 6 )
	flowstateSettings.enable_global_chat 					= GetCurrentPlaylistVarBool( "enable_global_chat", true)
	flowstateSettings.allow_cfgs 							= GetCurrentPlaylistVarBool( "flowstate_allow_cfgs", false )
	flowstateSettings.give_random_custom_models_toall		= GetCurrentPlaylistVarBool( "flowstate_give_random_custom_models_toall", false )
	flowstateSettings.show_short_champion_screen			= GetCurrentPlaylistVarBool( "show_short_champion_screen", true )
	flowstateSettings.bIsRealisticMode 						= GetCurrentPlaylistName() == "fs_realistic_ttv"
	flowstateSettings.give_weapon_stack_count_amount		= GetCurrentPlaylistVarInt( "give_weapon_stack_count_amount", 0 )
}

// Standalone entry point - provides DM infrastructure for 1v1 mode
void function _Gamemode1v1Standalone_Init()
{
	_InitializePlaylistSettings1v1()
	Flowstate_Afk_Init()

	// Stock champion EEH + commentary host tables. GamemodeSurvival_Init never
	// runs for GAMETYPE fs_1v1, so this is the only place that arms them.
	SurvivalCommentary_Init()
	SurvivalCommentary_SetHost( eSurvivalHostType.AI )
	printt( "[FS-1V1] SurvivalCommentary_Init + host AI" )
	printt( "[FS-1V1] rotate auto=" + string( Flowstate_EnableAutoChangeLevel() ) + " rounds=" + string( Flowstate_AutoChangeLevelRounds() ) + " rotate_map=" + string( flowstateSettings.rotate_map ) + " playlist=" + GetCurrentPlaylistName() )

	VOTING_PHASE_ENABLE = false
	SCOREBOARD_ENABLE = true

	RegisterSignal( "EndScriptedPropsThread" )
	RegisterSignal( "FS_WaitForBlackScreen" )
	RegisterSignal( "FS_ForceDestroyAllLifts" )
	if ( !IsValidSignal( "OnPickup" ) )
		RegisterSignal( "OnPickup" )
	if ( !IsValidSignal( "OnFirstCollision" ) )
		RegisterSignal( "OnFirstCollision" )

	if( flowstateSettings.enable_global_chat )
		SetConVarBool( "sv_forceChatToTeamOnly", false )
	else
		SetConVarBool( "sv_forceChatToTeamOnly", true )

	try {
		if( flowstateSettings.allow_cfgs )
			SetConVarInt( "sv_quota_scriptExecsPerSecond", 20 )
		else
			SetConVarInt( "sv_quota_scriptExecsPerSecond", 4 )
	} catch( e )
	{
		#if DEVELOPER
			sqerror( "[1v1:StandaloneInit] " + e )
		#endif
	}

	__InitAdmins()

	// Elimination policy: FS_Core_SharedInit sets FS_NeverEliminate for duel family.
	// Keep local override if core did not run yet.
	if ( !FS_HasCap( FS_CAP_NO_ELIMINATION ) )
		SetPlayerEliminationCheck( FS_1v1_ShouldPlayerBeEliminated )

	AddCallback_OnClientConnected( _OnPlayerConnected1v1 )
	AddCallback_OnPlayerKilled( _OnPlayerKilled1v1 )
	AddCallback_OnTdmStateEnter_InProgress( _OnTdmStateEnter_InProgress1v1 )
	AddCallback_OnWeaponAttack( FS_1v1_OnWeaponAttack )

	if( GetCurrentPlaylistName() == "fs_vamp_1v1" )
	{
		AddCallback_OnClientConnected(
			void function( entity player )
			{
				AddEntityCallback_OnDamaged( player, Vamp_OnPlayerDamaged )
				AddCallback_OnWeaponAttack( Vamp_OnWeaponAttack )
			}
		)
	}

	if ( FlowState_TgiveEnabled() )
		AddClientCommandCallback( "tgive", ClientCommand_GiveWeapon_1v1 )
	AddClientCommandCallback( "saveguns", ClientCommand_SaveCurrentWeapons_1v1 )
	AddClientCommandCallback( "resetguns", ClientCommand_ResetSavedWeapons_1v1 )

	AddClientCommandCallback( "adminlogin", ClientCommand_adminlogin )
	AddClientCommandCallback( "god", ClientCommand_God )
	AddClientCommandCallback( "ungod", ClientCommand_UnGod )
	AddClientCommandCallback( "next_round", ClientCommand_NextRound_1v1 )
	AddClientCommandCallback( "champion_room", ClientCommand_ChampionRoom_1v1 )
	AddClientCommandCallback( "dev_1v1", FS_1v1_DevMenuCmd )

	if( !FlowState_AdminTgive() )
	{
		AddClientCommandCallback( "saveskills", ClientCommand_Maki_SaveCurSkill )
		AddClientCommandCallback( "resetskills", ClientCommand_Maki_ResetSkills )
	}

	AddSpawnCallback( "prop_survival", Common_DissolveDropable )

	for( int i = 0; GetCurrentPlaylistVarString( "blacklisted_weapon_" + i.tostring(), "~~none~~" ) != "~~none~~"; i++ )
		file.blacklistedWeapons.append( GetCurrentPlaylistVarString( "blacklisted_weapon_" + i.tostring(), "~~none~~" ) )

	for( int i = 0; GetCurrentPlaylistVarString( "blacklisted_ability_" + i.tostring(), "~~none~~" ) != "~~none~~"; i++ )
		file.blacklistedAbilities.append( GetCurrentPlaylistVarString( "blacklisted_ability_" + i.tostring(), "~~none~~" ) )

	Gamemode1v1_Init( GetMapName() )

	thread _Run1v1()
	thread Scoreboard1v1_SyncThread()
}

// Connected count for match-start gating (includes bots; empty server must not start).
int function FS_1v1_CountConnectedPlayers()
{
	int n = 0
	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			n++
	}
	return n
}

void function FS_1v1_PublishConnectedCount()
{
	SetGlobalNetInt( "connectedPlayerCount", FS_1v1_CountConnectedPlayers() )
}

void function FS_1v1_WaitForFirstPlayer( string reason )
{
	if ( FS_1v1_CountConnectedPlayers() >= 1 )
		return

	printt( "[FS-1V1] waiting for first player (" + reason + ")" )
	while ( FS_1v1_CountConnectedPlayers() < 1 )
		WaitFrame()
	printt( "[FS-1V1] first player present (" + reason + ") count=" + string( FS_1v1_CountConnectedPlayers() ) )
}

entity function FS_1v1_ResolveMatchChampion()
{
	entity champion = null
	if ( file.lastChampionUID != "" )
		champion = GetPlayerEntityByUID( file.lastChampionUID )
	if ( !IsValid( champion ) )
		champion = GetBestPlayer()
	if ( !IsValid( champion ) )
	{
		array<entity> players = GetPlayerArray()
		if ( players.len() > 0 )
			champion = players[0]
	}
	return champion
}

void function FS_1v1_LatchMatchChampion()
{
	entity champion = GetBestPlayer()
	if ( !IsValid( champion ) )
	{
		file.lastChampionUID = ""
		printt( "[FS-1V1] LatchMatchChampion: no players" )
		return
	}

	file.lastChampionUID = champion.GetPlatformUID()
	printt( "[FS-1V1] LatchMatchChampion name=" + champion.GetPlayerName()
		+ " uid=" + file.lastChampionUID
		+ " kills=" + string( champion.GetPlayerNetInt( "kills" ) ) )
}

void function FS_1v1_PickChampion()
{
	entity champion = FS_1v1_ResolveMatchChampion()

	if ( !IsValid( champion ) )
	{
		printt( "[FS-1V1] PickChampion: no players" )
		SetGlobalNetInt( "championEEH", EncodedEHandle_null )
		SetGlobalNetInt( "championSquad1EEH", EncodedEHandle_null )
		SetGlobalNetInt( "championSquad2EEH", EncodedEHandle_null )
		return
	}

	array<EncodedEHandle> squad = GetPlayerSquadSafe( champion.GetEncodedEHandle(), 3 )
	SetGlobalNetInt( "championEEH", squad[0] )
	SetGlobalNetInt( "championSquad1EEH", squad[1] )
	SetGlobalNetInt( "championSquad2EEH", squad[2] )
	printt( "[FS-1V1] PickChampion name=" + champion.GetPlayerName() + " eeh=" + string( squad[0] )
		+ " uid=" + champion.GetPlatformUID()
		+ " kills=" + string( champion.GetPlayerNetInt( "kills" ) ) )
}

void function FS_1v1_StartShortChampionScreen( int teamWon )
{
	if ( !flowstateSettings.show_short_champion_screen )
	{
		SetGlobalNetTime( "championDisplayEndTime", Time() - 1.0 )
		SetGlobalNetTime( "pickLoadoutGamestateEndTime", Time() - 1.0 )
		SetChampionShowingState( false )
		return
	}

	if ( FS_1v1_IsForceCharacter() )
	{
		entity forceChamp = FS_1v1_ResolveMatchChampion()
		if ( IsValid( forceChamp ) )
			FS_1v1_ApplyForcedCharacter( forceChamp )
	}

	FS_1v1_PickChampion()

	entity pickedChampion = FS_1v1_ResolveMatchChampion()
	if ( IsValid( pickedChampion ) && FS_1v1_IsForceCharacter() )
		FS_1v1_ApplyForcedCharacter( pickedChampion )

	WaitEndFrame()

	int careerKills = 0
	int careerDeaths = 0
	int champSkin = -1
	int champCamo = -1
	entity champion = FS_1v1_ResolveMatchChampion()
	if ( IsValid( champion ) )
	{
		careerKills = champion.p.season_kills + champion.GetPlayerNetInt( "kills" )
		careerDeaths = champion.p.season_deaths + champion.GetPlayerNetInt( "deaths" )
		if ( careerKills < 0 )
			careerKills = 0
		if ( careerDeaths < 0 )
			careerDeaths = 0
		if ( champion.p.playerCamo > 0 )
		{
			champSkin = champion.GetSkin()
			champCamo = champion.GetCamo()
		}
		FS_1v1_PublishCareerStats( champion )
		champion.AddToAllRealms()
	}

	float totalSecs = 4.0
	float endTime = Time() + totalSecs
	int durationSec = int( totalSecs )

	SetGlobalNetTime( "pickLoadoutGamestateEndTime", endTime )
	SetChampionShowingState( true, endTime )
	SetGlobalNetTime( "championSquadPresentationStartTime", Time() )

	printt( "[FS-1V1] champion room start team=" + string( teamWon )
		+ " end=" + string( endTime ) + " dur=" + string( durationSec )
		+ " now=" + string( Time() ) )

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !FS_1v1_PlayerHasClient( player ) )
			continue
		Remote_CallFunction_NonReplay( player, "ServerCallback_FSDM_ChampionScreenHandle", true, teamWon, durationSec, careerKills, careerDeaths, champSkin, champCamo )
	}
}

void function FS_1v1_EndShortChampionScreen()
{
	SetChampionShowingState( false )
	SetGlobalNetTime( "championDisplayEndTime", Time() - 1.0 )
	SetGlobalNetTime( "pickLoadoutGamestateEndTime", Time() - 1.0 )

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue
		if ( FS_1v1_PlayerHasClient( player ) )
			Remote_CallFunction_NonReplay( player, "ServerCallback_FSDM_ChampionScreenHandle", false, 0, 0, 0, 0, -1, -1 )
		FS_1v1_ApplyLobbyCinematicHudFlags( player, Gamemode1v1_GetPlayerGamestate( player ) )
		player.Show()
	}
}

void function FS_1v1_PresentMatchChampion()
{
	if ( !flowstateSettings.show_short_champion_screen )
		return

	entity champion = FS_1v1_ResolveMatchChampion()
	int TeamWon = 69
	if ( GetPlayerArray().len() == 1 && IsValid( GetPlayerArray()[0] ) )
		TeamWon = GetPlayerArray()[0].GetTeam()
	if ( IsValid( champion ) )
		TeamWon = champion.GetTeam()

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue
		FS_1v1_ApplyLobbyCinematicHudFlags( player, e1v1State.INVALID )
		AddCinematicFlag( player, CE_FLAG_HIDE_PERMANENT_HUD )
		player.HolsterWeapon()
		player.FreezeControlsOnServer()
		player.ForceStand()
		player.Hide()
	}

	if ( IsValid( champion ) )
	{
		if ( FS_1v1_IsForceCharacter() )
			FS_1v1_ApplyForcedCharacter( champion )
		champion.Show()
	}

	if ( !IsValid( champion ) && GetPlayerArray().len() < 1 )
		return

	FS_1v1_StartShortChampionScreen( TeamWon )
	WaitForChampionToFinish()
	FS_1v1_EndShortChampionScreen()
}

// TDM state machine driver - round loop that handles timer, scoreboard, round transitions
void function _Run1v1()
{
	WaitForGameState( eGameState.Playing )

	SetGlobalNetBool( "displayMapzoneText", false )

	SetTdmStateToNextRound()

	// One-time setup
	if( !Flowstate_DoorsEnabled() )
	{
		array<entity> doors = GetAllPropDoors()
		foreach( entity door in doors )
			if( IsValid( door ) )
				door.Destroy()
	}

	SetDeathFieldParams( <0, 0, 0>, RING_DISABLED_RADIUS, RING_DISABLED_RADIUS, 90000, RING_DISABLED_RADIUS, 0 )

	// Do not burn the first-round start cycle on an empty dedi. First joiner
	// must be present for matchmaking countdown.
	FS_1v1_WaitForFirstPlayer( "pre-round-1" )

	// Main round loop
	while( true )
	{
		// ---- ROUND TRANSITION (round 2+) ----
		// Screen is already black from the round-end fade
		if( file.currentRound > 1 )
		{
			foreach( entity player in GetPlayerArray() )
			{
				if( !IsValid( player ) )
					continue

				player.HolsterWeapon()
				player.Server_TurnOffhandWeaponsDisabledOn()
			}
		}

		// ---- CHAMPION (every round start, including round 1) ----
		FS_1v1_PresentMatchChampion()

		entity champion = FS_1v1_ResolveMatchChampion()

		Tracker_RoundEnd( file.currentRound )

		FlowstateTracker_Finalize( IsValid( champion ) ? champion.GetPlatformUID() : "", false )
		WaitEndFrame()

		// ---- SCOREBOARD (round 2+) ----
		if( file.currentRound > 1 && SCOREBOARD_ENABLE )
		{
			Scoreboard1v1_PresentRoundEnd()

			float extraHold = GetCurrentPlaylistVarFloat( "fs_1v1_post_champion_delay", 0.0 )
			if( extraHold > 0 )
				wait extraHold
		}

		printt( "[FS-1V1] round=" + string( file.currentRound ) + " roundsBeforeChange=" + string( Flowstate_AutoChangeLevelRounds() ) + " auto=" + string( Flowstate_EnableAutoChangeLevel() ) + " rotate=" + string( flowstateSettings.rotate_map ) )

		if( file.currentRound > 1 && file.currentRound > Flowstate_AutoChangeLevelRounds() && Flowstate_EnableAutoChangeLevel() )
		{
			foreach( entity player in GetPlayerArray() )
				if( IsValid( player ) && player.p.isSpectating )
					endSpectate( player )

			if( bLog() )
				FlagEnd( "START_LOG" )

			if( flowstateSettings.end_match_message )
			{
				foreach( entity player in GetPlayerArray() )
				{
					if( !IsValid( player ) )
						continue
					Message( player, flowstateSettings.custom_match_ending_title, flowstateSettings.custom_match_ending_message, 6.0 )
				}
			}

			string to_map = GetMapName()
			string playlist = GetCurrentPlaylistName()
			if( flowstateSettings.rotate_map )
				to_map = Tracker_DetermineNextMap()

			if( to_map == "" || !Tracker_IsSafeMapName( to_map ) )
			{
				printt( "[FS-1V1] changelevel aborted: bad map '" + to_map + "' playlist=" + playlist )
			}
			else
			{
				printt( "[FS-1V1] changelevel map=" + to_map + " playlist=" + playlist + " round=" + string( file.currentRound ) )
				GameRules_ChangeMap( to_map, playlist )
				return
			}
		}

		FS_1v1_GatherPlayersToWaitingRoom()

		if( !isScenariosMode() )
			SetDeathFieldParams( <0, 0, 0>, RING_DISABLED_RADIUS, 0, 90000, RING_DISABLED_RADIUS, 0 )

		// ---- START ROUND ----
		// Triggers _OnTdmStateEnter_InProgress1v1 callback (resets challenges, sets timer, unfreezes)
		SetTdmStateToInProgress()

		// ---- ROUND TIMER LOOP ----
		float roundEndTime = GetGlobalNetTime( "flowstate_DMRoundEndTime" )

		if( FlowState_Timer() )
		{
			while( Time() <= roundEndTime && GetTDMState() == eTDMState.IN_PROGRESS )
				wait 1
		}
		else
		{
			while( Time() <= roundEndTime )
				wait 1
		}

		// ---- ROUND END ----
		// Stop pairing. Remaining fights run until they finish.
		SetTdmStateToNextRound()
		FS_1v1_WaitForActiveMatchesToSettle()

		foreach( entity player in GetPlayerArray() )
			if( FS_1v1_PlayerHasClient( player ) )
				ScreenFade( player, 0, 0, 0, 255, 0.0, 0.0, FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE )

		_OnRoundEnd1v1()
	}
}

void function ClientCommand_NextRound_1v1( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return
	if ( !GetConVarBool( "sv_cheats" ) )
	{
		printt( "[FS-1V1] next_round denied (sv_cheats 0) from " + player.GetPlayerName() )
		return
	}

	SetTdmStateToNextRound()
}

void function ClientCommand_ChampionRoom_1v1( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return
	if ( !GetConVarBool( "sv_cheats" ) )
	{
		printt( "[FS-1V1] champion_room denied (sv_cheats 0) from " + player.GetPlayerName() )
		return
	}

	if ( args.len() > 0 )
	{
		entity named = GetPlayer( args[0] )
		if ( IsValid( named ) )
			file.lastChampionUID = named.GetPlatformUID()
		else
			file.lastChampionUID = player.GetPlatformUID()
	}
	else
	{
		file.lastChampionUID = player.GetPlatformUID()
	}

	if ( GetChampionShowingState() )
		FS_1v1_EndShortChampionScreen()

	thread FS_1v1_PresentMatchChampion()
}

void function FS_1v1_NetworkedLatencyThread( entity player )
{
	if( !IsValid( player ) )
		return

	player.EndSignal( "OnDestroy" )

	for( ; ; )
	{
		int latency = int( player.GetLatency() * 1000 ) - 45
		player.SetPlayerNetInt( "latency", ClampInt( latency, -1, 500 ) )
		wait 0.5
	}
}

void function FS_1v1_OnPlayerDamaged_Score( entity victim, var damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsPlayer() )
		return

	entity attacker = InflictorOwner( DamageInfo_GetAttacker( damageInfo ) )

	if ( FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( victim ) ) )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim )
	{
		if ( FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( attacker ) ) )
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			return
		}

		MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( victim )
		if ( Gamemode1v1_IsMatchValid( group ) && attacker != group.player1 && attacker != group.player2 )
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			return
		}
	}

	if( !IsValid( attacker ) || !attacker.IsPlayer() || attacker == victim )
		return

	float dmg = DamageInfo_GetDamage( damageInfo )
	if( dmg <= 0 )
		return

	int nextDmg = attacker.GetPlayerNetInt( "damage" ) + int( dmg )
	attacker.SetPlayerNetInt( "damage", nextDmg )
	attacker.SetPlayerNetInt( "damageDealt", nextDmg )
	FS1v1_RemoteStats_RecordWeaponDamage( attacker, damageInfo, dmg )

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( attacker )
	if ( !Gamemode1v1_IsMatchValid( group ) )
		return

	if ( Flowstate_IsLGDuels() )
	{
		Gamemode1v1_RecordMatchStats( attacker, group, dmg, 1, 1, false )
		attacker.p.fs_stats_hits++
		attacker.p.fs_stats_shots++
		if ( IsBitFlagSet( DamageInfo_GetCustomDamageType( damageInfo ), DF_HEADSHOT ) )
		{
			Gamemode1v1_RecordMatchHeadshot( attacker, group )
			attacker.p.fs_stats_headshots++
		}
		return
	}

	entity weap = DamageInfo_GetWeapon( damageInfo )
	if ( IsValid( weap ) && !FS_1v1_IsAccuracyWeapon( weap, weap.GetWeaponClassName() ) )
		return

	Gamemode1v1_RecordMatchStats( attacker, group, dmg, 1, 0, false )
	attacker.p.fs_stats_hits++
	if ( IsBitFlagSet( DamageInfo_GetCustomDamageType( damageInfo ), DF_HEADSHOT ) )
	{
		Gamemode1v1_RecordMatchHeadshot( attacker, group )
		attacker.p.fs_stats_headshots++
	}
	FS_1v1_PushAccuracy( attacker )
}

bool function FS_1v1_IsAccuracyWeapon( entity weapon, string weaponName )
{
	if ( !IsValid( weapon ) )
		return false
	if ( weaponName == "mp_ability_sniper_ult" || weaponName == "mp_weapon_mobile_hmg" )
		return true
	if ( weapon.IsWeaponOffhand() )
		return false
	int flags = weapon.GetWeaponTypeFlags()
	if ( IsBitFlagSet( flags, WPT_TACTICAL )
		|| IsBitFlagSet( flags, WPT_ULTIMATE )
		|| IsBitFlagSet( flags, WPT_CONSUMABLE )
		|| IsBitFlagSet( flags, WPT_SURVIVAL ) )
		return false
	return true
}

void function FS_1v1_PushAccuracy( entity player )
{
	if ( !IsValid( player ) || Flowstate_IsLGDuels() )
		return

	int shots = player.p.fs_stats_shots
	int hits = player.p.fs_stats_hits
	int acc = 0
	if ( shots > 0 )
	{
		acc = int( ( float( hits ) / float( shots ) ) * 100.0 )
		if ( acc > 100 )
			acc = 100
	}
	player.SetPlayerNetInt( "accuracy", acc )
}

void function FS_1v1_OnWeaponAttack( entity player, entity weapon, string weaponName, int ammoUsed, vector attackOrigin, vector attackDir )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( Flowstate_IsLGDuels() )
		return
	if ( FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( player ) ) )
		return
	if ( !FS_1v1_IsAccuracyWeapon( weapon, weaponName ) )
		return

	int n = 1
	if ( IsValid( weapon ) )
	{
		n = weapon.GetProjectilesPerShot()
		if ( ammoUsed > n )
			n = ammoUsed
		if ( n < 1 )
			n = 1
	}

	player.p.fs_stats_shots += n

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	if ( Gamemode1v1_IsMatchValid( group ) )
		Gamemode1v1_RecordMatchStats( player, group, 0, 0, n, false )

	FS_1v1_PushAccuracy( player )
}

bool function FS_1v1_ShouldPlayerBeEliminated( entity player )
{
	return false
}

void function FS_1v1_EnsurePlayableCharacter( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( FS_1v1_IsForceCharacter() )
	{
		FS_1v1_ApplyForcedCharacter( player )
		return
	}

	EHI ehi = ToEHI( player )
	LoadoutEntry slot = Loadout_Character()
	if ( LoadoutSlot_IsReady( ehi, slot ) )
	{
		ItemFlavor current = LoadoutSlot_GetItemFlavor( ehi, slot )
		if ( ItemFlavor_GetType( current ) == eItemType.character )
			return
	}

	SetItemFlavorLoadoutSlot( ehi, slot, FS_1v1_ResolveCharacter( player, -1 ) )
}

void function _OnPlayerConnected1v1( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( FS_1v1_IsForceCharacter() )
		FS_1v1_ApplyForcedCharacter( player )

	// Fake clients stay IsDisconnected through this callback. Waiting here yields
	// the connect path and DecideRespawnPlayer runs with no legend. Champion
	// intro can start during that wait, so the slot is written above first.
	if ( !player.IsBot() )
	{
		float startTime = Time()
		while( IsDisconnected( player ) )
		{
			WaitFrame()
			if( Time() - startTime >= 3 )
			{
				#if DEVELOPER
					Warning( "PLAYER DISCONNECTED BREAK LOOP" )
				#endif
				break
			}
		}

		if ( !IsValid( player ) )
			return
	}

	FS_1v1_EnsurePlayableCharacter( player )

	Survival_OnClientConnected( player )
	player.SetMinimapZoomScale( 0.75, 3.0 )

	player.p.name = player.GetPlayerName()
	player.p.handle = player.GetEncodedEHandle()
	player.p.isConnected = true
	player.p.lastTgiveUsedTime = Time()
	player.p.lastRestUsedTime = Time()

	FS1v1_Stats_Load( player )
	player.p.fs_stats_hits = 0
	player.p.fs_stats_shots = 0
	player.p.fs_stats_headshots = 0
	FS1v1_RemoteStats_ResetWeapon( player )
	player.SetPlayerNetInt( "accuracy", 0 )

	if ( !player.IsBot() )
		thread FS_1v1_NetworkedLatencyThread( player )
	AddEntityCallback_OnDamaged( player, FS_1v1_OnPlayerDamaged_Score )

	Gamemode1v1_SetPlayerGamestate( player, e1v1State.MATCH_START )

	printt( format( "[FS-1V1][LEGEND] connect %s: ForceCharacter=%d RandomOnSpawn=%d chosen=%d",
		player.GetPlayerName(), FS_1v1_IsForceCharacter() ? 1 : 0,
		flowstateSettings.RandomCharacterOnSpawn ? 1 : 0, FlowState_ChosenCharacter() ) )

	if( FS_1v1_IsForceCharacter() )
	{
		FS_1v1_ApplyForcedCharacter( player )
	}
	else if( flowstateSettings.RandomCharacterOnSpawn && !player.GetPlayerNetBool( "hasLockedInCharacter" ) )
	{
		int randomIndex = RandomIntRangeInclusive( 0, LEGEND_CHARACTER_REFS.len() - 1 )
		SetItemFlavorLoadoutSlot( ToEHI( player ), Loadout_Character(), FS_1v1_GetCharacterByIndex( randomIndex ) )
		player.SetPlayerNetBool( "hasLockedInCharacter", true )
	}

	if( GetGameState() == eGameState.Playing )
		player.UnfreezeControlsOnServer()

	UpdatePlayerCounts()
	FS_1v1_PublishConnectedCount()
	thread FS_1v1_PublishConnectedCountDeferred()

	if ( !player.IsBot() )
	{
		if( flowstateSettings.enable_ping_kick )
			thread __HighPingCheck( player )

		if( flowstateSettings.enable_afk_thread )
			thread Flowstate_InitAFKThreadForPlayer( player )
	}
}

void function Gamemode1v1_Init( string mapName )
{
	#if DEVELOPER 
	printw( "Gamemode1v1_Init" )
	#endif
	
	RegisterSignal( "ChallengeStarted" )
	RegisterSignal( "ChallengeEnded" )
	RegisterSignal( "MatchFound" ) // For canceling penalty timers
	RegisterSignal( "FS_1v1_GraceChanged" ) // Wait-time setting changed mid-queue
	RegisterSignal( "GroupFinished" ) // For canceling fight boundary monitors

	// NotificationThread WaitSignal needs these before any player connects.
	NotificationSystem_Init()

	// Base gametype DecideRespawnPlayer -> FindStartSpawnPoint calls this; freem sets it, 1v1 did not.
	Spawn_SetSpawnpointRatingFunc( FS_1v1_RateSpawnpoints )
	FS_1v1_ApplyWaitingRoomForMap()
	Spawn_SetSpawnPointOverride( FS_1v1_WaitingRoomEngineSpawn )

	AddCallback_EntitiesDidLoad( FS1v1_OnEntitiesDidLoad )

	// Map lootbins still InitLootBin even with survival_block_lootbin_creation;
	// open hits missing weapon_ultralow group and aborts host. Disable at spawn.
	AddSpawnCallback_ScriptName( LOOT_BIN_SCRIPTNAME, FS_1v1_OnLootBinSpawned )
	
	DEV_1v1Init()
	
	INIT_PlaylistSettings() // Always first

	// Only claim the slot when the playlist actually dictates the legend; otherwise
	// stock validation still owns it.
	if ( FS_1v1_IsForceCharacter() )
		Loadout_SetCharacterResetOverride( FS_1v1_CharacterResetOverride )

	AddCallback_ItemFlavorLoadoutSlotDidChange_AnyPlayer( Loadout_Character(), FS_1v1_OnCharacterSlotChanged, false )
	FS_1v1_DumpLegendTable()
	INIT_PregameCallbacks()
	INIT_1v1_sbmm()
	INIT_HostCustomWeapons()
	
	if( GetMapName() == "mp_rr_olympus_tt" )
		SpawnSystem_UseNavMeshCorrection( false )
		
	if( !isScenariosMode() && !bIsCoachingMode() ) //intertwined D:
	{
		AddClientCommandCallback( "challenge", ClientCommand_mkos_challenge )
		AddClientCommandCallback( "chal", ClientCommand_1v1_ChalShortcut )
		AddClientCommandCallback( "accept", ClientCommand_1v1_AcceptShortcut )
		AddClientCommandCallback( "deny", ClientCommand_1v1_DenyShortcut )

		//1v1 settings
		AddClientCommandCallback("CC_1v1_StartInRest", CC_1v1_StartInRest)
		AddClientCommandCallback("CC_1v1_IBMM", CC_1v1_IBMM)
		AddClientCommandCallback("CC_1v1_AcceptChallenges", CC_1v1_AcceptChallenges) 
		AddClientCommandCallback("CC_1v1_ShowInputBanner", CC_1v1_ShowInputBanner)
		AddClientCommandCallback("CC_1v1_ShowVsUI", CC_1v1_ShowVsUI)
		AddClientCommandCallback("CC_1v1_CamoColor", CC_1v1_CamoColor)
		AddClientCommandCallback("CC_1v1_MaxEnemyLatency", CC_1v1_MaxEnemyLatency)
		AddClientCommandCallback("CC_1v1_MaxIBMMTime", CC_1v1_MaxIBMMTime)
		AddClientCommandCallback("CC_1v1_ScoreboardOpen", CC_1v1_ScoreboardOpen)
	}
	// Coaching mode not ported (FS_Init_1v1_Coaching / recordings).

	if ( Flowstate_IsLGDuels() )
		Flowstate_LgDuels1v1_Init()

	// Scenarios not ported (Init_FS_Scenarios).

	SpawnSystem_InitGamemodeOptions()
		
	SetHostInventoryAttachments()
	
	if( settings.bAllowWeaponsMenu )
		INIT_WeaponsMenu()
	else 
		INIT_WeaponsMenu_Disabled()
	
	file.restGrace = GetCurrentPlaylistVarFloat( "rest_grace", 0.0 )
	
	if( !settings.player_collision_enabled )
		AddCallback_OnPlayerRespawned( DisablePlayerCollision )
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//INIT PRIMARY WEAPON SELECTION
	if ( Flowstate_IsLGDuels() )
		file.Weapons = [ "mp_weapon_r97 optic_cq_hcog_classic stock_tactical_l1 bullets_mag_l2" ]
	
	if ( file.Weapons.len() == 0 && !settings.bNoPrimary )
	{
		file.Weapons = 
		[
			"mp_weapon_r97 optic_cq_hcog_classic stock_tactical_l1 bullets_mag_l2",
			"mp_weapon_nemesis optic_cq_hcog_classic energy_mag_l2 stock_tactical_l1",
			"mp_weapon_vinson optic_cq_hcog_classic stock_tactical_l1 highcal_mag_l3",
			"mp_weapon_volt_smg optic_cq_hcog_classic energy_mag_l1 stock_tactical_l1"
		]
	}
	
	//longrange class primary
	if( file.LongRangeWeapons.len() == 0 && !settings.bNoPrimaryLongrange )
		file.LongRangeWeapons = [ "mp_weapon_g2 optic_cq_hcog_bruiser" ]		

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//INIT SECONDARY WEAPON SELECTION	
	if ( Flowstate_IsLGDuels() )
		file.WeaponsSecondary = [ "mp_weapon_r97 optic_cq_hcog_classic stock_tactical_l1 bullets_mag_l2" ]
	
	if ( file.WeaponsSecondary.len() == 0 && !settings.bNoSecondary )
	{
		file.WeaponsSecondary =
		[
			"mp_weapon_wingman optic_cq_hcog_classic sniper_mag_l1",
			"mp_weapon_energy_shotgun optic_cq_hcog_classic shotgun_bolt_l1",
			"mp_weapon_mastiff optic_cq_hcog_classic shotgun_bolt_l2",
			"mp_weapon_autopistol_fusion optic_cq_hcog_classic energy_mag_l2",
			"mp_weapon_bow optic_cq_hcog_classic stock_sniper_l1"
		]
	}
	
	//longrange class secondary
	if( file.LongRangeWeaponsSecondary.len() == 0 && !settings.bNoSecondaryLongrange )
		file.LongRangeWeaponsSecondary = [ "mp_weapon_sniper" ]
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Validate final selection to host settings 
	
	ValidateBlacklistedWeapons( file.Weapons )
	ValidateBlacklistedWeapons( file.LongRangeWeapons )	
	ValidateBlacklistedWeapons( file.WeaponsSecondary )
	ValidateBlacklistedWeapons( file.LongRangeWeaponsSecondary )
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	if( GetCurrentPlaylistName() == "fs_vamp_1v1" ) //Todo(mk): This should be handled by the mode's script file using AddCallback_SpawnsSettings
		SpawnSystem_SetCustomPlaylist( "fs_1v1" )
}

// BannerImages_1v1Init moved to _1v1_ui.nut

// S21: LocPair cannot be assigned as a whole -- write fields only.
void function Gamemode1v1_SetWaitingRoomLocation( vector origin, vector angles )
{
	file.WaitingRoom.origin = origin
	file.WaitingRoom.angles = angles
	printt( "[FS-1V1] waiting room set origin=" + string( origin ) + " angles=" + string( angles ) )
}

vector function FS_1v1_WaitingRoomLookTarget()
{
	if ( FS_1v1_WorldBanner_IsReady() )
		return FS_1v1_WorldBanner_GetOrigin()
	return Gamemode1v1_GetNotificationPanel_Coordinates()
}

vector function FS_1v1_WaitingRoomLookAngles( vector fromOrigin )
{
	vector target = FS_1v1_WaitingRoomLookTarget()
	if ( Distance2D( fromOrigin, target ) < 8.0 )
		return <0, Gamemode1v1_GetWaitingRoomLocation().angles.y, 0>
	return <0, VectorToAngles( FlattenVec( target - fromOrigin ) ).y, 0>
}

LocPair function FS_1v1_PickWaitingRoomLoc()
{
	LocPair loc
	if ( g_waitingRoomSpawnLocations.len() > 0 )
	{
		LocPair picked = g_waitingRoomSpawnLocations.getrandom()
		loc.origin = picked.origin
	}
	else
	{
		LocPair waitLoc = Gamemode1v1_GetWaitingRoomLocation()
		loc.origin = waitLoc.origin
	}

	loc.angles = FS_1v1_WaitingRoomLookAngles( loc.origin )
	return loc
}

void function FS_1v1_ApplyWaitingRoomForMap()
{
	Gamemode1v1_SetWaitingRoomRadius( DEFAULT_WAITING_ROOM_RADIUS )
	Gamemode1v1_SetWaitingRoomLocation( <1408.2179, -4048.65088, 411.03125>, <0, -157.148438, 0> )

	switch( GetMapName() )
	{
		case "mp_rr_canyonlands_staging":
			Gamemode1v1_SetWaitingRoomLocation( <31897.502, -5671.05029, -17916.1934>, <0, 0, 0> )
			break

		case "mp_rr_arena_composite":
			Gamemode1v1_SetWaitingRoomLocation( <-3468.73755, 6571.66357, 1421.50903>, <0, -37.9684105, 0> )
			break

		case "mp_rr_aqueduct":
			Gamemode1v1_SetWaitingRoomLocation( <719.94, -5805.13, 494.03>, <0, 90, 0> )
			break

		case "mp_rr_party_crasher":
			Gamemode1v1_SetWaitingRoomLocation( <3435.34, -2596.51, 563.285>, <0, 137.179, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 400 )
			break

		case "mp_rr_canyonlands_staging_mu1":
			Gamemode1v1_SetWaitingRoomLocation( <-2982.03, 2915.74, 236.22>, <0, -118.774, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 700 )
			break

		case "mp_rr_arena_habitat":
			Gamemode1v1_SetWaitingRoomLocation( <-551.402, -3660.74, 2384.16>, <0, 65.4421, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 700 )
			break

		case "mp_rr_district":
		case "mp_rr_district_mu1":
			Gamemode1v1_SetWaitingRoomLocation( <25400.8, 8320.78, 7680.03>, <0, -117.055, 0> )
			break

		case "mp_rr_canyonlands_64k_x_64k":
			Gamemode1v1_SetWaitingRoomLocation( <-762.59, 20485.05, 4626.03>, <0, 45, 0> )
			break

		case "mp_rr_thunderdome":
			Gamemode1v1_SetWaitingRoomLocation( <-1183.91, 1792.74, 1312.03>, <0, -68.7226, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 700 )
			break

		case "mp_rr_arena_phase_runner":
			Gamemode1v1_SetWaitingRoomLocation( <21071.3, 16455.5, -895.97>, <0, -41.6689, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 400 )
			break

		case "mp_rr_arena_skygarden":
			Gamemode1v1_SetWaitingRoomLocation( <3945.66, 1692.38, 2653.67>, <0, -145.165, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 700 )
			break

		case "mp_rr_freedm_skulltown":
		case "mp_rr_freedm_skulltown_s27":
			Gamemode1v1_SetWaitingRoomLocation( <1270.37, 3926.07, 196.147>, <0, -105.331, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 700 )
			break

		case "mp_rr_divided_moon_mu1":
			Gamemode1v1_SetWaitingRoomLocation( <-11791.8, -4623.37, 3712.04>, <0, -0.476587, 0> )
			Gamemode1v1_SetWaitingRoomRadius( 700 )
			break
	}
}

bool function FS_1v1_WaitingRoomNeedsFallback( LocPair loc )
{
	if ( loc.origin.z >= 15000.0 )
		return true

	string map = GetMapName()
	if ( map == "mp_rr_canyonlands_staging" || map == "mp_rr_canyonlands_staging_mu1" )
		return false

	return Distance( loc.origin, <1408.2179, -4048.65088, 411.03125> ) < 8.0
}

void function FS_1v1_ApplyWaitingRoomSafeFallback( array<SpawnData> allSoloLocations )
{
	if ( !FS_1v1_WaitingRoomNeedsFallback( Gamemode1v1_GetWaitingRoomLocation() ) )
		return

	string setName = SpawnSystem_GetCurrentSpawnSet()
	bool fromDisk = setName.find( "trivial:" ) != 0

	if ( fromDisk && allSoloLocations.len() > 0 )
	{
		Gamemode1v1_SetWaitingRoomLocation( allSoloLocations[0].spawn.origin, allSoloLocations[0].spawn.angles )
		printt( "[FS-1V1] waiting room safe fallback disk spawn0=" + string( allSoloLocations[0].spawn.origin ) + " map=" + GetMapName() )
		return
	}

	entity spawnpoint = FS_1v1_FindExistingEngineSpawn()
	if ( IsValid( spawnpoint ) )
	{
		Gamemode1v1_SetWaitingRoomLocation( spawnpoint.GetOrigin(), spawnpoint.GetAngles() )
		printt( "[FS-1V1] waiting room safe fallback engine spawn=" + string( spawnpoint.GetOrigin() ) + " map=" + GetMapName() )
		return
	}

	if ( allSoloLocations.len() > 0 )
	{
		Gamemode1v1_SetWaitingRoomLocation( allSoloLocations[0].spawn.origin, allSoloLocations[0].spawn.angles )
		printt( "[FS-1V1] waiting room safe fallback trivial spawn0=" + string( allSoloLocations[0].spawn.origin ) + " map=" + GetMapName() )
	}
}

// Hand-surveyed waiting-room spots. An empty result falls back to the generated ring.
array<LocPair> function FS_1v1_MapWaitingRoomSpawns()
{
	array<LocPair> spawns

	switch( GetMapName() )
	{
		case "mp_rr_arena_composite":
			spawns.append( NewLocPair( <-3468.73755, 6571.66357, 1421.50903>, <0, -37.9684105, 0> ) )
			spawns.append( NewLocPair( <-3592.55151, 6365.07520, 1418.18054>, <0, -6.75742817, 0> ) )
			spawns.append( NewLocPair( <-3783.26538, 6342.09521, 1413.57971>, <0, -5.55902910, 0> ) )
			spawns.append( NewLocPair( <-3931.94458, 6408.62207, 1409.26221>, <0, -5.33763981, 0> ) )
			spawns.append( NewLocPair( <-3860.41797, 6651.55713, 1407.75061>, <0, -27.6505299, 0> ) )
			spawns.append( NewLocPair( <-3724.17676, 6843.57813, 1408.70068>, <0, -45.0118103, 0> ) )
			spawns.append( NewLocPair( <-3570.89844, 6993.06738, 1410.72375>, <0, -66.4397583, 0> ) )
			spawns.append( NewLocPair( <-3441.29688, 7148.65039, 1412.01587>, <0, -13.0413847, 0> ) )
			spawns.append( NewLocPair( <-3335.20483, 6801.11816, 1419.88367>, <0, -16.8523407, 0> ) )
			spawns.append( NewLocPair( <-3601.69678, 6538.99902, 1416.39807>, <0, -21.9487228, 0> ) )
			spawns.append( NewLocPair( <-3492.70313, 6755.63770, 1416.25439>, <0, -42.9188805, 0> ) )
			spawns.append( NewLocPair( <-2318.58496, 7739.71240, 1418.27600>, <0, -66.4419937, 0> ) )
			spawns.append( NewLocPair( <-2504.47266, 7607.91748, 1417.84741>, <0, -17.3576965, 0> ) )
			spawns.append( NewLocPair( <-2095.62451, 7759.30713, 1421.74097>, <0, -81.9030838, 0> ) )
			spawns.append( NewLocPair( <-2433.26929, 7936.69873, 1411.29749>, <0, -73.4425430, 0> ) )
			spawns.append( NewLocPair( <-2286.30225, 8043.65039, 1411.22156>, <0, -87.7579193, 0> ) )
			spawns.append( NewLocPair( <-2637.16528, 7836.79736, 1410.18616>, <0, -65.3050919, 0> ) )
			break

		case "mp_rr_party_crasher":
			spawns.append( NewLocPair( <3435.34, -2596.51, 563.285>, <0, 137.179, 0> ) )
			break

		case "mp_rr_thunderdome":
			spawns.append( NewLocPair( <-1183.91, 1792.74, 1312.03>, <0, -68.7226, 0> ) )
			break

		case "mp_rr_arena_phase_runner":
			spawns.append( NewLocPair( <21071.3, 16455.5, -895.97>, <0, -41.6689, 0> ) )
			break

		case "mp_rr_arena_habitat":
			spawns.append( NewLocPair( <-551.402, -3660.74, 2384.16>, <0, 65.4421, 0> ) )
			break

		case "mp_rr_arena_skygarden":
			spawns.append( NewLocPair( <3945.66, 1692.38, 2653.67>, <0, -145.165, 0> ) )
			break

		case "mp_rr_freedm_skulltown":
		case "mp_rr_freedm_skulltown_s27":
			spawns.append( NewLocPair( <1270.37, 3926.07, 196.147>, <0, -105.331, 0> ) )
			break

		case "mp_rr_divided_moon_mu1":
			spawns.append( NewLocPair( <-11791.8, -4623.37, 3712.04>, <0, -0.476587, 0> ) )
			break

		case "mp_rr_district":
		case "mp_rr_district_mu1":
			spawns.append( NewLocPair( <25400.8, 8320.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25240.8, 8320.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25560.8, 8320.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25400.8, 8160.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25400.8, 8480.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25280.8, 8200.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25520.8, 8440.78, 7680.03>, <0, -117.055, 0> ) )
			spawns.append( NewLocPair( <25280.8, 8440.78, 7680.03>, <0, -117.055, 0> ) )
			break
	}

	return spawns
}

entity function FS_1v1_FindExistingEngineSpawn()
{
	array<string> classNames = [ "info_spawnpoint_human_start", "info_spawnpoint_human", "info_player_start" ]
	foreach ( string className in classNames )
	{
		array<entity> ents = GetEntArrayByClass_Expensive( className )
		foreach ( entity ent in ents )
		{
			if ( !IsValid( ent ) )
				continue

			// Prefer a real spawnpoint (.sp). info_player_start is CBaseEntity.
			try
			{
				var unused = ent.sp.enabled
				return ent
			}
			catch ( err )
			{
				continue
			}
		}
	}

	// Last resort: any valid info_player_start as a position dummy. spawn.nut
	// skips .sp on CBaseEntity.
	array<entity> starts = GetEntArrayByClass_Expensive( "info_player_start" )
	foreach ( entity ent in starts )
	{
		if ( IsValid( ent ) )
			return ent
	}

	return null
}

// One shot. Never CreateEntity a spawnpoint, and never SetOrigin one onto the
// waiting-room coords -- those fail DispatchSpawn. Placement is the teleport.
void function FS_1v1_InstallWaitingRoomEngineSpawns()
{
	if ( file.waitingRoomSpawnsInstalled )
		return

	LocPair waitLoc = Gamemode1v1_GetWaitingRoomLocation()
	if ( waitLoc.origin.x == 0 && waitLoc.origin.y == 0 && waitLoc.origin.z == 0 )
		return

	file.waitingRoomSpawnsInstalled = true

	entity spawnpoint = FS_1v1_FindExistingEngineSpawn()
	if ( !IsValid( spawnpoint ) )
	{
		printt( "[FS-1V1] engine spawn: no map spawnpoint to pin" )
		return
	}

	file.waitingRoomStartSpawn = spawnpoint

	printt( "[FS-1V1] engine spawn using existing " + spawnpoint.GetClassName() + " at " + string( spawnpoint.GetOrigin() ) + " teleport spots=" + string( g_waitingRoomSpawnLocations.len() ) )
}

// CalculateRating on a non-spawnpoint is a script error (host shutdown).
void function FS_1v1_RateSpawnpoints( int checkClass, array<entity> spawnpoints, int team, entity player )
{
	foreach ( entity spawnpoint in spawnpoints )
	{
		if ( !IsValid( spawnpoint ) )
			continue

		if ( spawnpoint.GetClassName().find( "info_spawnpoint" ) != 0 )
		{
			printt( "[FS-1V1] skipped non-spawnpoint in rating pass: " + spawnpoint.GetClassName() )
			continue
		}

		try
		{
			spawnpoint.CalculateRating( checkClass, team, 0.0, 0.0 )
		}
		catch ( err )
		{
			printt( "[FS-1V1] skipped spawnpoint without rating: " + spawnpoint.GetClassName() )
		}
	}
}

entity function FS_1v1_WaitingRoomEngineSpawn( entity player )
{
	if ( IsValid( file.waitingRoomStartSpawn ) )
		return file.waitingRoomStartSpawn

	return null
}

// 1v1 has no survival loot table (weapon_ultralow etc missing). Never allow open.
bool function FS_1v1_LootBinNeverOpen( entity player, entity lootBin )
{
	return false
}

void function FS_1v1_DisableLootBin( entity lootBin )
{
	if ( !IsValid( lootBin ) )
		return

	lootBin.UnsetUsable()
	// CanUseLootBin checks this map before any other allow.
	AddCallback_CanOpenLootBin( lootBin, FS_1v1_LootBinNeverOpen )
}

void function FS_1v1_OnLootBinSpawned( entity lootBin )
{
	// After InitLootBin (same script-name spawn list; we register second).
	thread FS_1v1_DisableLootBin_Deferred( lootBin )
}

void function FS_1v1_DisableLootBin_Deferred( entity lootBin )
{
	WaitFrame()
	FS_1v1_DisableLootBin( lootBin )
}

void function FS_1v1_DisableAllLootBins()
{
	int n = 0
	foreach ( entity lootBin in GetAllLootBins() )
	{
		if ( !IsValid( lootBin ) )
			continue
		FS_1v1_DisableLootBin( lootBin )
		n++
	}
	// Catch any not yet in the SMEA list.
	foreach ( entity lootBin in GetEntArrayByScriptName( LOOT_BIN_SCRIPTNAME ) )
	{
		if ( !IsValid( lootBin ) )
			continue
		FS_1v1_DisableLootBin( lootBin )
		n++
	}
	printt( "[FS-1V1] lootbin open disabled count~=" + string( n ) )
}

void function FS_1v1_DisableAllLootBins_Retry_THREAD()
{
	// InitLootBin / perk bin randomize can run after EDL when flags are forced.
	for ( int i = 0; i < 10; i++ )
	{
		wait 1.0
		FS_1v1_DisableAllLootBins()
	}
}

// Podium props keep skin 0 on every map unless the stock setup runs, and skin 0
// is the desertlands backdrop. 1v1 never calls GamemodeSurvivalShared_Init, so
// its EntitiesDidLoad -- the only caller -- never registers.
void function FS_1v1_SetupPodium()
{
	if ( GetEntArrayByScriptName( "podium_bg_skin_swap" ).len() != 1 )
	{
		printt( "[FS-1V1] no victory podium on " + GetMapName() )
		return
	}

	SetupVictoryPodium()

	int bannerSkin = GetCurrentPlaylistVarInt( "fs_1v1_podium_banner_skin", -1 )
	if ( bannerSkin >= 0 )
	{
		foreach ( entity banner in GetEntArrayByScriptName( "podium_banner_skin_swap" ) )
			banner.SetSkin( bannerSkin )
	}

	printt( "[FS-1V1] victory podium skinned for " + GetMapName() + " bannerOverride=" + string( bannerSkin ) )
}

void function FS1v1_OnEntitiesDidLoad()
{
	// Force out of survival PickLoadout shell so _Run1v1 / StartGame can run.
	// survival_dev never finishes char-select for this custom mode.
	thread FS_1v1_ForcePlayingShell_THREAD()

	// Playlist blocks creation; map props still exist and crash on open.
	FS_ArenaWalls_SetExclusiveRealm( eRealms.DEFAULT )
	FS_1v1_DisableAllLootBins()
	// Late InitLootBin (after Survival_LootSpawned force-set) -- re-apply.
	thread FS_1v1_DisableAllLootBins_Retry_THREAD()

	FS_1v1_SetupPodium()

	FS_1v1_ApplyWaitingRoomForMap()

	array<SpawnData> allSoloLocations = SpawnSystem_ReturnAllSpawnLocations()
	FS_1v1_ApplyWaitingRoomSafeFallback( allSoloLocations )

	file.notificationPanel_Coordinates = Gamemode1v1_GetNotificationPanel_Coordinates()
	if( !FS_1v1_HasPanelLocation() )
		printt( "[FS-1V1] no panels row in spawn data; notification panel follows the waiting room at " + string( file.notificationPanel_Coordinates ) )
	file.notificationPanel_Angles = Gamemode1v1_GetNotificationPanel_Angles()	
	
	if( !ValidateSpawns( allSoloLocations ) )
	{
		SpawnSystem_SetPreferredPak( 1 )
		//SpawnSystem_SetRunCallbacks( false ) //(mk): for this mode, we wont disable re-running callbacks, as they may be needed to customize spawns again. If the gamemode dev has prop spawning or things that should only be done once, they should make sure it's only init once in their logic.
		allSoloLocations = SpawnSystem_ReturnAllSpawnLocations()
		
		//mAssert( ValidateSpawns( allSoloLocations ), "No valid spawns were defined" )
		if( !ValidateSpawns( allSoloLocations ) )
		{
			while( GetTDMState() != eTDMState.IN_PROGRESS )
				WaitFrame()
				
			wait 8
			sqwarning( "No valid spawns defined" )
			
			foreach( player in GetPlayerArray() )
				Message( player, "Map Config Error", "No valid spawns defined." )

			Warning( "[FS-1V1] No valid spawns defined; Tracker_GotoNextMap. Map: " + GetMapName() )
			wait 5
			Tracker_GotoNextMap()
			return
		}
	}
	
	array<LocPair> surveyedWaitingRoomSpawns = FS_1v1_MapWaitingRoomSpawns()
	g_waitingRoomSpawnLocations = surveyedWaitingRoomSpawns
	if ( g_waitingRoomSpawnLocations.len() < FS_1V1_MIN_GENERATED_WAITING_SPOTS )
	{
		LocPair waitLoc = Gamemode1v1_GetWaitingRoomLocation()
		array<LocPair> generated = SpawnSystem_GenerateRandomSpawns( waitLoc.origin, waitLoc.angles, file.waitingRoomRadius, .22, 24 )
		if ( generated.len() >= FS_1V1_MIN_GENERATED_WAITING_SPOTS )
		{
			g_waitingRoomSpawnLocations = generated
			foreach ( LocPair extra in surveyedWaitingRoomSpawns )
				g_waitingRoomSpawnLocations.append( extra )
			printt( "[FS-1V1] waiting room generated " + string( generated.len() ) + " hull-clear spots on " + GetMapName() )
		}
		else if ( g_waitingRoomSpawnLocations.len() == 0 )
		{
			g_waitingRoomSpawnLocations.append( NewLocPair( waitLoc.origin, waitLoc.angles ) )
			Warning( "[FS-1V1] waiting room has no surveyed spots and only " + string( generated.len() ) + " generated spots passed the hull test on " + GetMapName() + "; using the single origin " + string( waitLoc.origin ) )
		}
		else
		{
			printt( "[FS-1V1] waiting room kept " + string( g_waitingRoomSpawnLocations.len() ) + " surveyed spots; generator only produced " + string( generated.len() ) + " on " + GetMapName() )
		}
	}
	FS_1v1_InstallWaitingRoomEngineSpawns()
	FS_1v1_DisableMapTriggers()

	if( settings.isScenariosMode )
	{
		int teamAmount = GetCurrentPlaylistVarInt( "fs_scenarios_teamAmount", 3 )	
		string potentialTeamCount = SpawnSystem_GetPakInfoForKey( "teamCount" )	
		
		int spawnPakTeamCount = -1
		if( potentialTeamCount != "_NOTFOUND" )
			spawnPakTeamCount = potentialTeamCount.tointeger()
 
		if( spawnPakTeamCount > SCENARIOS_MAX_ALLOWED_TEAMSIZE )
			Warning( "[FS-1V1] spawn pak teamCount " + string( spawnPakTeamCount ) + " exceeds max " + string( SCENARIOS_MAX_ALLOWED_TEAMSIZE ) )
		
		for ( int i = 0; i < allSoloLocations.len(); i = i + teamAmount )
		{
			LocationsData p	
			for ( int j = 0; j < teamAmount; j++  )
				p.respawnLocations.append( allSoloLocations[ i + j ].spawn )

			p.Center = GetCenterOfCircle( p.respawnLocations )
			
			if( allSoloLocations[i].info != "" )
				p.info = allSoloLocations[i].info

			string names = allSoloLocations[ i ].info
			for ( int j = 1; j < teamAmount; j++ )
				names += "," + allSoloLocations[ i + j ].info
			p.ids = names

			arenaLocations.append( p )
		}
	}
	else //1v1
	{
		for ( int i = 0; i < allSoloLocations.len(); i=i+2 )
		{
			LocationsData p
		
			p.respawnLocations.append( allSoloLocations[ i ].spawn )
			p.respawnLocations.append( allSoloLocations[ i + 1 ].spawn )

			p.Center = ( allSoloLocations[ i ].spawn.origin + allSoloLocations[ i + 1 ].spawn.origin ) / 2

			if( allSoloLocations[ i ].info != "" )
				p.info = allSoloLocations[ i ].info

			p.ids = allSoloLocations[ i ].info + "," + allSoloLocations[ i + 1 ].info

			arenaLocations.append( p )
		}
	}

	printt( "[FS-1V1] spawn pairs n=" + string( arenaLocations.len() ) )
	for ( int pi = 0; pi < arenaLocations.len(); pi++ )
		printt( "[FS-1V1] spawn pair " + FS_1v1_SpawnPairDesc( pi ) )

	file.realmSlots.resize( MAX_REALM + 1 )
	file.realmSlots[ 0 ] = true
	
	int realmSlotsLen = file.realmSlots.len()
	for ( int i = 1; i < realmSlotsLen; i++ )
		file.realmSlots[ i ] = false

	if( settings.isScenariosMode )
	{
		FS_Scenarios_SetupPanels()
		thread FS_Scenarios_Main_Thread()
		return
	}
	
	// default spawn behavior
	AddCallback_OnPlayerRespawned( Gamemode1v1_OnSpawned )
	AddDamageCallback( "player", FS_1v1_BlockWorldDamageWhileTriggerExempt )
	
	//challenges cleanup
	AddCallback_OnClientDisconnected( FS_1v1_OnPlayerDisconnected )
	
	//resting room init ///////////////////////////////////////////////////////////////////////////////////////
			
	PanelTable panels = 
	{
		[ "#FS_START_SPEC" ] 			= null,
		[ "#FS_REST_TOGGLE" ] 			= null,
		[ "#FS_IBMM_TOGGLE" ] 			= null,
		[ "#FS_CHAL_TOGGLE" ] 			= null,
		[ "#FS_START_REST_TOGGLE" ] 	= null,
		[ "#FS_INPUT_BANNER" ] 			= null,
		//["add another"] = null,
	};
	
	AddCallback_OnClientConnected
	(
		void function( entity player )
		{
			// init for IBMM
			Init_IBMM( player )
			FS_SetRealmForPlayer( player, 0 )

			INIT_playerChallengesStruct( player ) //normally init after persistence loads

			if( bIsCoachingMode() )
			{
				if( !IsAlive( player ) )
					Gamemode1v1_ForcePilotRespawn( player )

				player.p.playerisready = false
			}

			if ( FS_1v1_PlayerHasClient( player ) )
			{
				switch( GetMapName() )
				{
					case "mp_rr_party_crasher":
					case "mp_rr_arena_composite":
						Remote_CallFunction_NonReplay( player, "ServerCallback_SpawnOrModifyClientSideDynamicLight", <-131.638657, -928.141907, 20401.8008>, < 0, 0, 0 >, 0, 1024, 2.0, 0 )
						Remote_CallFunction_NonReplay( player, "ServerCallback_SpawnOrModifyClientSideDynamicLight", <-172.030136, -23.6625957, 20289.2266>, < 0, 0, 0 >, 0, 1024, 2.0, 1 )
						Remote_CallFunction_NonReplay( player, "ServerCallback_SpawnOrModifyClientSideDynamicLight", <-1601.14001, -890.200745, 21468.5039>, < 0, 0, 0 >, 1, 1024, 2.0, 2 )//jumppads area
						Remote_CallFunction_NonReplay( player, "ServerCallback_SpawnOrModifyClientSideDynamicLight", <918.127991, -1166.38794, 20793.8203>, < 0, 0, 0 >, 0, 1024, 2.0, 3 ) //çourse
						Remote_CallFunction_NonReplay( player, "ServerCallback_SpawnOrModifyClientSideDynamicLight", <-51.4564667, -2055.91406, 20776.9473>, < 0, 0, 0 >, 0, 1024, 2.0, 4 ) //çourse
					break
				}
			}

			// Bots are duel opponents here (fs_1v1_skip_bots defaults off), so the
			// queue route must not sit behind the client-only gate above.
			thread HandleNewlyConnectedPlayer( player )
		}
	)
	
	BannerImages_1v1Init()
	printt( "[FS-1V1] waiting room spawns face world banner at " + string( FS_1v1_WaitingRoomLookTarget() ) )

	if( !bIsCoachingMode() )
	{
		Gamemode1v1_SetRestEnabled()
		AddClientCommandCallback( "rest", CC_1v1_ToggleRest )
		AddClientCommandCallback( "spectate_1v1", ClientCommand_SpectateNew )
	}
	else
		Gamemode1v1_SetRestEnabled( false )
	
	thread FS_1v1_StartGame_THREAD( Gamemode1v1_GetWaitingRoomLocation() )
}

// survival_dev shell sticks in PickLoadout -- force Playing so round + matchmaking run.
// Wait for first joiner so the start cycle is not burned on an empty map boot.
void function FS_1v1_ForcePlayingShell_THREAD()
{
	FS_1v1_WaitForFirstPlayer( "force-playing-shell" )
	wait 0.5

	if ( GetGameState() >= eGameState.Playing )
	{
		printt( "[FS-1V1] ForcePlayingShell: already Playing after first player" )
		foreach ( entity player in GetPlayerArray() )
		{
			if ( IsValid( player ) )
				player.UnfreezeControlsOnServer()
		}
		return
	}

	// Unblock GameRulesThink_PickLoadout / Prematch if they are still ticking.
	// Do NOT stomp championDisplayEndTime here -- _Run1v1 owns the short intro.
	SetGlobalNetTime( "pickLoadoutGamestateEndTime", Time() - 1.0 )

	if ( GetGameState() < eGameState.Playing )
	{
		SetGameState( eGameState.Playing )
		printt( "[FS-1V1] forced eGameState.Playing (first player present)" )
		// SetGameState(Playing) always prints OutOfBoundsEnable callstack via
		// OutOfBounds_OnGameStatePlaying -- that is NOT a SCRIPT ERROR.
	}

	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			player.UnfreezeControlsOnServer()
	}
}

void function FS_1v1_StartGame_THREAD( LocPair waitingRoom )
{
	// Do not hang forever if survival shell never advances without players.
	// With players present, wait longer for the force-playing shell / survival path.
	float deadline = Time() + 90.0
	while ( GetGameState() < eGameState.Playing && Time() < deadline )
	{
		if ( FS_1v1_CountConnectedPlayers() < 1 )
		{
			// Idle empty: keep deadline sliding so we do not force empty Playing.
			deadline = Time() + 90.0
		}
		WaitFrame()
	}

	if ( GetGameState() < eGameState.Playing )
	{
		if ( FS_1v1_CountConnectedPlayers() >= 1 )
		{
			printt( "[FS-1V1] StartGame timeout waiting for Playing -- forcing (players present)" )
			SetGameState( eGameState.Playing )
		}
		else
		{
			// Still empty: wait for a player, then force.
			FS_1v1_WaitForFirstPlayer( "start-game-empty" )
			SetGameState( eGameState.Playing )
			printt( "[FS-1V1] StartGame forced Playing after first player" )
		}
	}

	// Hold until _Run1v1 finishes first-player wait + champion + SetTdmStateToInProgress.
	FS_1v1_WaitForFirstPlayer( "start-game" )

	printt( "[FS-1V1] GAME STATE PLAYING - Time():", Time(), "championDisplayEndTime:", GetGlobalNetTime( "championDisplayEndTime" ), "players:", FS_1v1_CountConnectedPlayers() )

	WaitForChampionToFinish()

	while( GetTDMState() != eTDMState.IN_PROGRESS )
		WaitFrame()

	printt( "[FS-1V1] CHAMPION SCREEN FINISHED" )

	// Publish IN_PROGRESS before stamping rest/wait so client DisplayHints is not
	// blocked by netvar default -1 or lingering NEXT_ROUND from _Run1v1 boot.
	// No-op on callbacks if _Run1v1 already entered IN_PROGRESS (see SetTdmStateToInProgress).
	SetTdmStateToInProgress()

	// Process all players who connected before champion screen finished
	// They didn't get handled by OnClientConnected because game state wasn't IN_PROGRESS yet
	foreach ( player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue

		// Skip players already in a list or in solo mode
		if( Gamemode1v1_IsPlayerResting( player ) || Gamemode1v1_IsPlayerWaiting( player ) || IsPlayerInSoloMode( player ) )
			continue

		// Add them to appropriate list based on preference
		if( !player.p.start_in_rest_setting )
		{
			printt( "[FS-1V1] [INIT] early-connected " + player.GetPlayerName() + " -> waiting" )
			Gamemode1v1_AddPlayerToQueue( player )
		}
		else
		{
			printt( "[FS-1V1] [INIT] early-connected " + player.GetPlayerName() + " -> resting" )
			Gamemode1v1_AddPlayerToRest( player )
			thread Gamemode1v1_RespawnForMatch( player )
		}
	}

	// Start waiting room boundary monitor (runs independently at 2 Hz)
	thread StartWaitingRoomBoundaryMonitor( waitingRoom )

	printt( "[FS-1V1] gamemode fully initialized (event-driven)" )
}

void function INIT_1v1_sbmm()
{
	//initialize defaults for SBMM
	if ( bGlobalStats() )
	{
		file.season_kd_weight = GetCurrentPlaylistVarFloat( "season_kd_weight", 0.90 )
		file.current_kd_weight = GetCurrentPlaylistVarFloat( "current_kd_weight", 1.3 )
		file.SBMM_kd_difference = GetCurrentPlaylistVarFloat( "kd_difference", 1.5 )
	} 
	else
	{
		//base values
		file.season_kd_weight = 1
		file.current_kd_weight = 1
		file.SBMM_kd_difference = 3	
	}
}

void function INIT_HostCustomWeapons()
{	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	// Regular weapons pool	
	
	ValidateWeaponList
	( 
		GetCurrentPlaylistVarString( "custom_1v1_weapons_primary", "" ),
		GetCurrentPlaylistVarString( "custom_1v1_weapons_primary_continue", "" ), 
		file.Weapons,
		"primary"
	)
		
	ValidateWeaponList
	(
		GetCurrentPlaylistVarString( "custom_1v1_weapons_secondary", "" ), 
		GetCurrentPlaylistVarString( "custom_1v1_weapons_secondary_continue", "" ),
		file.WeaponsSecondary,
		"secondary"
	)
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	// Longrange weapons pool
	
	ValidateWeaponList
	( 
		GetCurrentPlaylistVarString( "custom_longrange_primary", "" ),
		GetCurrentPlaylistVarString( "custom_longrange_primary_continue", "" ),
		file.LongRangeWeapons,
		"primaryLongrange"
	)
	
	ValidateWeaponList
	(
		GetCurrentPlaylistVarString( "custom_longrange_secondary", "" ),
		GetCurrentPlaylistVarString( "custom_longrange_secondary_continue", "" ),
		file.LongRangeWeaponsSecondary,
		"secondaryLongrange"
	)
}

void function INIT_PlaylistSettings()
{
	settings.bGiveSameRandomLegendToBothPlayers		= GetCurrentPlaylistVarBool( "give_random_legend_on_spawn", false )
	settings.bAllowLegend 							= GetCurrentPlaylistVarBool( "give_legend", false )
	settings.bAllowAbilities 						= GetCurrentPlaylistVarBool( "give_legend_tactical", false )
	settings.bChalServerMsg 						= bBotEnabled() ? GetCurrentPlaylistVarBool( "challenge_recap_server_message", true ) : false;
	settings.ibmm_wait_limit 						= GetCurrentPlaylistVarInt( "ibmm_wait_limit", 999 )
	settings.default_ibmm_wait 						= GetCurrentPlaylistVarFloat( "default_ibmm_wait", 3 )
	settings.enableChallenges						= GetCurrentPlaylistVarBool( "enable_challenges", true )
	settings.isScenariosMode						= GetCurrentPlaylistName() == "fs_scenarios"
	settings.customWeaponsChallengeOnly				= GetCurrentPlaylistVarBool( "custom_weapons_challenge_only", false )
	settings.roundTime								= FlowState_RoundTime()
	settings.bAllowWeaponsMenu						= !FlowState_AdminTgive()
	settings.playerMaxFightDistance					= GetCurrentPlaylistVarInt( "player_max_fight_distance", DEFAULT_MAX_FIGHT_DISTANCE )
	settings.give_weapon_stack_count_amount			= GetCurrentPlaylistVarInt( "give_weapon_stack_count_amount", 0 )
	settings.player_collision_enabled				= GetCurrentPlaylistVarBool( "player_collision_enabled", true )
	settings.player_rest_collision_enabled			= GetCurrentPlaylistVarBool( "player_rest_collision_enabled", false )
	settings.allow_legend_select					= GetCurrentPlaylistVarBool( "allow_legend_select", false )
	settings.enableHelmets							= GetCurrentPlaylistVarBool( "enable_helmets", false )
	settings.giveSkinsWeapons 						= GetCurrentPlaylistVarBool( "flowstate_giveskins_weapons", false )
	settings.enableCosmetics 						= GetCurrentPlaylistVarBool( "flowstate_enable_cosmetics", false )
	settings.bEnableStreaks							= GetCurrentPlaylistVarBool( "enable_win_streaks", true )
	settings.matchFoundDelay						= GetCurrentPlaylistVarFloat( "match_found_delay", 0.2 )
}

void function INIT_PregameCallbacks()
{
	float f_wait = settings.default_ibmm_wait
		
	if ( f_wait > 0.0 && f_wait < 3.0 )
	{
		//this shouldn't be defined out, it lets the host know they have an invalid setting
		sqerror( format( "Default IBMM wait time was set as '%.2f' ; must be either 0 or >= 3. Resetting to 3.", f_wait ) )
	}

	//(mk):custom light for custom spawns
	// if( GetMapName == "mp_rr_arena_composite" && GetCurrentPlaylistVarBool( "patch_for_dropoff", false ) )
	// {
		// DropoffPatch_Init
		// AddCallback_SpawnsPostInit( Init_DropoffPatchSpawns )
	// }

	if( GetCurrentPlaylistName() == "fs_1v1_headshots_only" )
	{
		AddCallback_SpawnsSettings
		( 
			void function()
			{
				SpawnSystem_SetCustomPlaylist( "fs_1v1" ) //(mk): this can be set in playlist for simplicity
			}
		)
	}
		
	// Kill and TDM state callbacks are registered by _Gamemode1v1Standalone_Init
	// (_OnPlayerKilled1v1 wraps Gamemode1v1_OnPlayerKilled with battle log)
	// (_OnTdmStateEnter_InProgress1v1 wraps OnMatchStart with player setup)
}

void function INIT_WeaponsMenu()
{
	FreeroamWeaponsMenu_ServerInit()
	AddClientCommandCallback( "CC_MenuGiveAimTrainerWeapon", CC_MenuGiveAimTrainerWeapon ) 
	AddClientCommandCallback( "CC_AimTrainer_SelectWeaponSlot", CC_AimTrainer_SelectWeaponSlot )
	AddClientCommandCallback( "CC_AimTrainer_WeaponSelectorClose", CC_AimTrainer_CloseWeaponSelector )
}

void function INIT_WeaponsMenu_Disabled()
{
	AddClientCommandCallback( "CC_MenuGiveAimTrainerWeapon", MessagePlayer_Disabled ) 
	AddClientCommandCallback( "CC_AimTrainer_SelectWeaponSlot", MessagePlayer_Disabled )
	AddClientCommandCallback( "CC_AimTrainer_WeaponSelectorClose", MessagePlayer_Disabled )
}



void function OnMatchStart()
{
	resetChallenges()
}

//(mk): Do not remove the sqerror variants, they are used in Tracker servers to print to console for malconfigurations.
void function ValidateWeaponList( string weaponList, string weaponListContinue, array<string> outputArrayByRef, string slotClass )
{
	if ( weaponList != "" )
	{
		string concatenated = Concatenate( weaponList, weaponListContinue )

        try
        {
			StringToArrayAppend( concatenated, outputArrayByRef )
			
			if( outputArrayByRef[ 0 ] == "~~none~~" )
			{
				switch( slotClass )
				{
					case "primary":
						settings.bNoPrimary = true
						break
					
					case "secondary":
						settings.bNoSecondary = true
						break
					
					case "primaryLongrange":
						settings.bNoPrimaryLongrange = true
						break
					
					case "secondaryLongrange":
						settings.bNoSecondaryLongrange = true
						break
				}
				
				return //exit parsing entire slotClass.
			}
			
			int listLen = outputArrayByRef.len() - 1
			for ( int i = listLen; i >= 0; --i )
			{
				string before = strip( outputArrayByRef[ i ] )
				
				outputArrayByRef[ i ] = ParseWeapon( strip( outputArrayByRef[ i ] ) )
				
				if ( strip( outputArrayByRef[ i ] ) != before )
					sqerror( format( "Weapon %d was invalid and corrected. \n Old:\n \"%s\" \n New: \n \"%s\" \n\n", i, before, strip( outputArrayByRef[ i ] ) ) )
					
				if ( outputArrayByRef[ i ] == "" )
					outputArrayByRef.remove( i )
			}
		}
		catch ( error )
		{
			sqerror( "[1v1:ValidateWeaponList] " + error )
		}
	}
}


//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 4: MAIN CALLBACKS (LIFECYCLE EVENTS)
// Core event handlers for player lifecycle
//
//═══════════════════════════════════════════════════════════════════════════════

void function FS_1v1_OnPlayerDisconnected( entity player )
{

	#if DEVELOPER
		printt( "[+] OnPlayerDisconnected 1v1 -", player )
	#endif

	int playerHandle = player.p.handle

	if ( player in file.triggerExemptPlayers )
		delete file.triggerExemptPlayers[ player ]
	SetMapTriggerExempt( player, false )

	// Handle disconnection based on player's current state

	// 1. Check if player is in an active match
	MatchGroup playerGroup = Gamemode1v1_GetPlayerSoloGroup( player )
	if ( Gamemode1v1_IsMatchValid( playerGroup ) )
	{
		// Score the forfeit before the stats flush below, and while both entities
		// are still valid -- the teardown itself is threaded and runs later.
		FS_1v1_RecordForfeit( playerGroup, player )
		thread HandlePlayerDisconnectedDuringMatch( playerGroup, player )
		// Continue to challenge cleanup below
	}

	// 2. Handle challenge cleanup
	entity opponent = returnChallengedPlayer( player )

	if( IsValid( opponent ) )
		endLock1v1( opponent )

	// endLock1v1 resolves the other half through the disconnecting player's ehandle,
	// which can already be dead here. Purge both directions by hand so no lock outlives
	// its owner and starves the survivor out of matchmaking.
	if ( playerHandle in file.acceptedChallenges )
	{
		entity lockedTo = file.acceptedChallenges[ playerHandle ]
		delete file.acceptedChallenges[ playerHandle ]
		FS_1v1_ReleaseChallengeSide( lockedTo )
	}

	array<int> lockedToDisconnector
	foreach ( challengedHandle, challenger in file.acceptedChallenges )
	{
		if ( challenger == player || !IsValid( challenger ) )
			lockedToDisconnector.append( challengedHandle )
	}

	foreach ( int challengedHandle in lockedToDisconnector )
	{
		delete file.acceptedChallenges[ challengedHandle ]
		FS_1v1_ReleaseChallengeSide( GetEntityFromEncodedEHandle( challengedHandle ) )
	}

	FS_1v1_ChallengesOnDisconnect( player )

	// Reverse so fastremove does not skip the next entry after a remove.
	for ( int i = file.allChallenges.len() - 1; i >= 0; i-- )
	{
		if ( player == file.allChallenges[ i ].player )
			file.allChallenges.fastremove( i )
	}

	// Drop session custom loadout key so reconnect/rename cannot inherit stale guns.
	if ( player.p.handle in weaponlist_1v1 )
		delete weaponlist_1v1[ player.p.handle ]

	FS_1v1_ForgetSpectatorRealm( player )

	if ( playerHandle in file.scoreboardOpenClients )
		delete file.scoreboardOpenClients[ playerHandle ]
	if ( playerHandle in file.scoreboardNameFp )
		delete file.scoreboardNameFp[ playerHandle ]
	if ( playerHandle in file.scoreboardCardFp )
		delete file.scoreboardCardFp[ playerHandle ]
	if ( playerHandle in file.scoreboardSyncSeq )
		delete file.scoreboardSyncSeq[ playerHandle ]
	if ( playerHandle in file.scoreboardResyncTime )
		delete file.scoreboardResyncTime[ playerHandle ]
	if ( playerHandle in file.scoreboardCardGuids )
	{
		delete file.scoreboardCardGuids[ playerHandle ]
		delete file.scoreboardCardGuidsAt[ playerHandle ]
	}

	// 3. Remove from waiting list if present
	if ( Gamemode1v1_IsPlayerWaiting( player ) )
	{
		Gamemode1v1_RemovePlayerFromWaitingList( playerHandle )
	}

	// 4. Remove from resting list if present
	if ( Gamemode1v1_IsPlayerResting( player ) )
	{
		Gamemode1v1_RemovePlayerFromRestingList( player )
	}

	// 5. Update resting/spectating panels for remaining players
	FS_1v1_RequestRestingNotificationRefresh()

	FS_1v1_SweepStaleMatchmakingState()
	thread TriggerMatchmaking()

	// Last: everything above can still move this player's stats.
	FS1v1_Stats_Cleanup( player )
	thread FS_1v1_PublishConnectedCountDeferred()
}

void function FS_1v1_PublishConnectedCountDeferred()
{
	WaitEndFrame()
	FS_1v1_PublishConnectedCount()
}

void function Gamemode1v1_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if( IsValid( attacker ) )
		victim.p.lastKiller = attacker

	if( bIsCoachingMode() )
	{
		//(cafe)stops recording
		FS_Coaching_StopRecording( FS_Coaching_GetAvailableMatchIdentifier(), victim, attacker )
	}

	// Resting players (spectators/waiting) need immediate respawn when killed
	// Replaces 60 FPS polling in main loop (lines 4390-4409)
	if( victim.p.handle in file.restingPlayers )
	{
		thread Gamemode1v1_RespawnForMatch( victim )
		return // Don't process as match event
	}

	// Challenge matches (IsKeep = true) auto-respawn both players instead of ending
	if( !isScenariosMode() )
	{
		MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( victim )

		if( Gamemode1v1_IsMatchValid( group ) && group.IsKeep )
		{
			// Route to event-driven challenge match respawn handler
			entity chalAttacker = ( IsValid( attacker ) && attacker.IsPlayer() ) ? attacker : null
			thread HandleChallengeMatchRespawn( group, victim, chalAttacker )
			return // Don't process as normal match end
		}

		// Normal match: process as match end
		if( Gamemode1v1_IsMatchValid( group ) )
		{
			// trigger_hurt / world: pass null so HandleGroupIsFinished awards the opponent
			entity duelAttacker = ( IsValid( attacker ) && attacker.IsPlayer() ) ? attacker : null
			HandleGroupIsFinished( victim, duelAttacker )
			victim.SetPlayerNetEnt( "FSDM_1v1_Enemy", null )
			return
		}
	}
		
	if( Gamemode1v1_IsPlayerWaiting( victim ) )
	{
		thread Gamemode1v1_AddPlayerToQueueAfterDeath( victim )
		return
	}

	if( !IsAlive( victim ) )
		thread Gamemode1v1_AddPlayerToQueueAfterDeath( victim )
}

void function FS_1v1_PlaceInWaitingRoom( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	if ( IsPlayerInSoloMode( player ) )
		return

	if ( Gamemode1v1_IsPlayerInState( player, e1v1State.RESTING ) )
		return

	// The room sits outside the playable volume, so the exemption has to hold from the
	// spawn itself -- waiting for a gamestate transition leaves a window where the map
	// hazards own the player.
	FS_1v1_SetTriggerExemption( player, true )
	Gamemode1v1_TeleportPlayer( player, FS_1v1_PickWaitingRoomLoc() )
}

// 1v1 contains players with its own systems -- the waiting room teleports strays back and
// a match applies boundary damage -- so the map's hazard volumes only ever fire on players
// the mode has already placed on purpose. The under-map kill loop is deliberately left on
// as the last resort for a fall out of the world; waiting-room players are exempt from it.
void function FS_1v1_DisableMapTriggers()
{
	if ( !GetCurrentPlaylistVarBool( "disable_map_triggers", true ) )
		return

	array<entity> triggers
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_out_of_bounds" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_hurt" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_slip" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_no_zipline" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_no_grapple" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_multiple" ) )
	triggers.extend( GetEntArrayByClass_Expensive( "trigger_cylinder_heavy" ) )
	triggers.extend( GetEntArrayByScriptName( "WallTrigger_Killzone" ) )
	triggers.extend( GetEntArrayByScriptName( "WallTrigger_oob_timer" ) )

	int disabled = 0
	foreach ( entity trigger in triggers )
	{
		if ( !IsValid( trigger ) )
			continue

		trigger.Disable()
		disabled++
	}

	printt( "[FS-1V1] disabled " + string( disabled ) + " map triggers; mode owns player containment" )
}

// A trigger-exempt player is parked outside the playable area on purpose: nothing the
// world inflicts may touch them. Damage dealt by another player still lands, so this
// cannot be used to hide in a fight.
void function FS_1v1_BlockWorldDamageWhileTriggerExempt( entity player, var damageInfo )
{
	if ( !IsValid( player ) || !IsMapTriggerExempt( player ) )
		return

	entity attacker = InflictorOwner( DamageInfo_GetAttacker( damageInfo ) )
	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != player )
		return

	if ( DamageInfo_GetDamage( damageInfo ) <= 0 )
		return

	if ( file.hazardBlockLogCount < 16 )
	{
		file.hazardBlockLogCount++
		printt( "[FS-1V1] blocked world damage in waiting room source="
			+ string( DamageInfo_GetDamageSourceIdentifier( damageInfo ) )
			+ " amount=" + string( DamageInfo_GetDamage( damageInfo ) )
			+ " for " + player.GetPlayerName() )
	}

	DamageInfo_SetDamage( damageInfo, 0 )
}

void function Gamemode1v1_OnSpawned( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	// RespawnTitanPilot stamps SPECTATOR_SETTINGS before DoRespawnPlayer (S3 positioning
	// workaround in _base_gametype_mp). Survival re-applies pilot setfile in
	// Survival_OnPlayerRespawned -- but GAMETYPE fs_1v1 never runs GamemodeSurvival_Init,
	// so that callback is never registered. Without this reapply, the player keeps
	// spectator.rpak (no solid collision / "not really" pilot spawn).
	if( IsAlive( player ) )
	{
		try
		{
			FS_1v1_EnsurePlayableCharacter( player )
			// Resolve rather than read the slot back: a bot's loadout write does not
			// survive the persistence round-trip, so the slot can still hold the default.
			ItemFlavor character = FS_1v1_ResolveCharacter( player, -1 )
			printt( format( "[CHARSETUP] OnSpawned %s resolved '%s' | slot '%s' | settings=%s",
				player.GetPlayerName(), ItemFlavor_GetHumanReadableRef( character ),
				ItemFlavor_GetHumanReadableRef( LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() ) ),
				string( player.GetPlayerSettings() ) ) )
			if ( ItemFlavor_GetType( character ) == eItemType.character )
				Survival_PlayerCharacterSetup( player, character, true )
			TakeAllPassives( player )
			if ( !settings.bAllowAbilities )
				FS_1v1_StripAbilities( player )
			ClearPlayerEliminated( player )
			EnablePlayerCollision( player )
		}
		catch ( charSetupErr )
		{
			printt( "[FS-1V1] OnSpawned character setup failed: " + charSetupErr )
		}
	}

	float shieldHP = Equipment_GetDefaultShieldHP()
	bool isLG = Flowstate_IsLGDuels()

	// Read the state ONCE. Every placement decision below has to agree with the
	// one Gamemode1v1_RespawnForMatch set before it called DecideRespawnPlayer.
	int spawnState = Gamemode1v1_GetPlayerGamestate( player )
	bool isFightSpawn = spawnState == e1v1State.SEQUENCE

	// Waiting-room / champion spawn must not re-apply armor -- Inventory_SetPlayerEquipment
	// plays the shield-charge FX. Fight spawn restores in RespawnForMatch.
	if ( isFightSpawn )
	{
		if ( shieldHP > 0 && !isLG )
			PlayerRestoreHP_1v1( player, 100, shieldHP )
		else
			PlayerRestoreHP_1v1( player, 100, 0 )
	}
	else
	{
		FS_1v1_ApplyLobbyLoadout( player )
		FS_SetRealmForPlayer( player, 0 )

		// Sole placement for a non-fight spawn. It skips resting players and
		// players inside a match, both of which belong somewhere else.
		FS_1v1_PlaceInWaitingRoom( player )
	}

	Survival_SetInventoryEnabled( player, false )

	if( !isFightSpawn && GetTDMState() != eTDMState.IN_PROGRESS )
		Gamemode1v1_SetPlayerGamestate( player, e1v1State.INVALID )

	player.UnfreezeControlsOnServer()
}

// Delay ensures client has time to send start_in_rest_setting preference
void function HandleNewlyConnectedPlayer( entity player )
{
	if ( IsValid( player ) && IsAlive( player ) && !IsInvincible( player ) )
		MakeInvincible( player )

	// Wait for client to send their start_in_rest_setting preference
	wait 0.5

	if( !IsValid( player ) )
		return

	FS_1v1_WorldBanner_PushToPlayer( player )

	if ( IsAlive( player ) && !IsInvincible( player ) )
		MakeInvincible( player )

	if( Gamemode1v1_IsPlayerResting( player ) || Gamemode1v1_IsPlayerWaiting( player ) || IsPlayerInSoloMode( player ) )
		return

	// Bounded like the matchmaking worker's gate: a round that never opens must not
	// leave the joiner permanently unqueued and standing outside the waiting room.
	float gateDeadline = Time() + 30.0
	bool gateReported = false
	while ( IsValid( player ) && ( GetTDMState() != eTDMState.IN_PROGRESS || GetChampionShowingState() ) && Time() < gateDeadline )
	{
		if ( !gateReported )
		{
			gateReported = true
			printt( format( "[FS-1V1][MM] connect hold %s: tdmState=%d champion=%d",
				player.GetPlayerName(), GetTDMState(), GetChampionShowingState() ? 1 : 0 ) )
		}
		if ( IsAlive( player ) && !IsInvincible( player ) )
			MakeInvincible( player )
		WaitFrame()
	}

	if( !IsValid( player ) )
		return

	if( gateReported )
		printt( format( "[FS-1V1][MM] connect hold released %s: tdmState=%d",
			player.GetPlayerName(), GetTDMState() ) )

	if( Gamemode1v1_IsPlayerResting( player ) || Gamemode1v1_IsPlayerWaiting( player ) || IsPlayerInSoloMode( player ) )
	{
		printt( format( "[FS-1V1][MM] connect route %s skipped: state=%d solo=%d",
			player.GetPlayerName(), Gamemode1v1_GetPlayerGamestate( player ),
			IsPlayerInSoloMode( player ) ? 1 : 0 ) )
		return
	}

	// Initialize win streak tracking
	player.p.winStreak = 0
	player.p.bestStreak = 0

	// Route player to waiting or resting list based on their preference
	if( !player.p.start_in_rest_setting )
	{
		printt( format( "[FS-1V1][MM] connect route %s (bot=%d) -> waiting list",
			player.GetPlayerName(), player.IsBot() ? 1 : 0 ) )
		Gamemode1v1_AddPlayerToQueue( player )
	}
	else
	{
		printt( format( "[FS-1V1][MM] connect route %s (bot=%d) -> resting list",
			player.GetPlayerName(), player.IsBot() ? 1 : 0 ) )
		Gamemode1v1_AddPlayerToRest( player )
		thread Gamemode1v1_RespawnForMatch( player )
	}
}

void function OnWeaponAttachmentChanged( entity player, entity weapon, string modToAdd, string modToRemove )
{
	//(mk):This callbackfunc is only registered when tgive is enabled by host.
	
	//(mk):make sure chal only flag isn't configured.
	if( !Gamemode1v1_AreCustomWeaponsAllowedForPlayer( player ) )
		return 
		
	ClientCommand_SaveCurrentWeapons_1v1( player, [] )
}



// Section 5 (Client Commands) moved to _1v1_commands.nut

//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 6: PLAYER STATE MANAGEMENT
// Player gamestate getters/setters
//
//═══════════════════════════════════════════════════════════════════════════════

void function AddEntityCallback_OnPlayerGamestateChange_1v1( entity player, void functionref( entity player, int state ) callbackFunc )
{
	if( !( player.e.onPlayerGamestateChangedCallbacks.contains( callbackFunc ) ) )
		player.e.onPlayerGamestateChangedCallbacks.append( callbackFunc )
}

int function Gamemode1v1_GetPlayerGamestate( entity player )
{
	return player.GetPlayerNetInt( "FS_1v1_PlayerState" )
}

bool function Gamemode1v1_IsPlayerInChallenge( entity player )
{
	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	
	if( !Gamemode1v1_IsMatchValid( group ) || !group.IsKeep )
		return false
	
	return true
}

bool function Gamemode1v1_IsPlayerInState( entity player, int state )
{
	return player.GetPlayerNetInt( "FS_1v1_PlayerState" ) == state
}

// Waiting-room players sit wherever the map author parked them, which can be
// inside an out-of-bounds volume or below the under-map kill plane. Exempt them
// individually rather than disabling the triggers for the whole server, so a
// live duel still gets its boundaries.
void function FS_1v1_SetTriggerExemption( entity player, bool exempt )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !GetCurrentPlaylistVarBool( "waiting_room_trigger_exempt", true ) )
		exempt = false

	bool current = player in file.triggerExemptPlayers
	if ( current == exempt )
		return

	// DisableEntityOutOfBounds refcounts, so every disable needs exactly one enable.
	if ( exempt )
	{
		file.triggerExemptPlayers[ player ] <- true
		DisableEntityOutOfBounds( player )
	}
	else
	{
		delete file.triggerExemptPlayers[ player ]
		EnableEntityOutOfBounds( player )
	}

	SetMapTriggerExempt( player, exempt )
}

void function FS_1v1_ApplyLobbyCinematicHudFlags( entity player, int state )
{
	if ( !IsValid( player ) )
		return

	// PERMANENT zeros topoFullscreenHudPermanent: the gamestate scorebar, the
	// netgraph nested on it, and the unit frames. The waiting room wants those,
	// the champion presentation must not have them drawn over it. Nothing the
	// client sets survives this flag -- ShouldPermanentHudBeVisible reads it and
	// UpdateMainHudVisibility re-shows the whole topology when it is clear.
	if ( GetChampionShowingState() )
		AddCinematicFlag( player, CE_FLAG_HIDE_PERMANENT_HUD )
	else
		RemoveCinematicFlag( player, CE_FLAG_HIDE_PERMANENT_HUD )

	if ( FS_1v1_ShouldShowCombatHud( state ) )
		RemoveCinematicFlag( player, CE_FLAG_HIDE_MAIN_HUD_INSTANT )
	else
		AddCinematicFlag( player, CE_FLAG_HIDE_MAIN_HUD_INSTANT )
}

bool function Gamemode1v1_IsPlayerResting( entity player )
{		
	return ( player.p.handle in file.restingPlayers )
}

bool function Gamemode1v1_IsPlayerWaiting( entity player ) //todo: capital I 
{
	return ( player.p.handle in file.waitingQueue )
}

void function Gamemode1v1_SetPlayerGamestate( entity player, int state = 0 )
{
	// #if DEVELOPER
	// DumpStack
	// #endif
	
	// if( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) != state )
	// {
		#if DEVELOPER && DEBUG_STATE
		int prevState = player.GetPlayerNetInt( "FS_1v1_PlayerState" )
		printw( format("[1v1:State] %s: %s -> %s", string(player), DEV_GetEnumStringSafe( "e1v1State", prevState ), DEV_GetEnumStringSafe( "e1v1State", state )) )
	#endif
		
		player.SetPlayerNetInt( "FS_1v1_PlayerState", state )
		FS_1v1_ApplyLobbyCinematicHudFlags( player, state )
		FS_1v1_SetTriggerExemption( player, FS_1v1_IsLobbyState( state ) )

		foreach( callbackFunc in player.e.onPlayerGamestateChangedCallbacks )
			callbackFunc( player, state )
	// }
	#if DEVELOPER && DEBUG_STATE
		else if( !Gamemode1v1_IsPlayerInState( player, e1v1State.SEQUENCE ) )
		{
			DumpStack()
			Warning( "[FS-1V1] state already set to " + DEV_GetGamestateRef( state ) + " for " + string( player ) )
		}
	#endif
}

bool function IsPlayerInProgress( int handle )
{
	if ( handle in file.playerMatchMap )
	{
		if( IsValid( file.playerMatchMap[ handle ] ) )
			return true
	}
	
	return false 
}

bool function IsPlayerInSoloMode( entity player ) 
{
    return ( player.p.handle in file.playerMatchMap )
}

void function RemoveEntityCallback_OnPlayerGamestateChange_1v1( entity player, void functionref( entity player, int state ) callbackFunc )
{
	if( player.e.onPlayerGamestateChangedCallbacks.contains( callbackFunc ) )
		player.e.onPlayerGamestateChangedCallbacks.fastremovebyvalue( callbackFunc )
}



// Sections 7-9 (Matchmaking, IBMM/SBMM, Timer) moved to _1v1_matchmaking.nut


// Sections 10-11 (Group/Match Management, Player List Management) moved to _1v1_match.nut


// Section 12 (Challenge System) moved to _1v1_challenge.nut


// Section 13 (Spectate System) moved to _1v1_spectate.nut


// Section 14 (Weapon & Loadout Management) moved to _1v1_weapons.nut


// Section 15 (Player Abilities & Legend Management) moved to _1v1_legend.nut


// Section 16 (Realm, Boundary & Spawn Management) moved to _1v1_realm.nut


// Section 17 (UI & Notifications) moved to _1v1_ui.nut

string function FS_1v1_SpawnPairDesc( int idx )
{
	if ( idx < 0 || idx >= arenaLocations.len() )
		return "idx=" + string( idx ) + " <invalid>"

	LocationsData loc = arenaLocations[ idx ]
	string origins = ""
	int n = loc.respawnLocations.len()
	for ( int i = 0; i < n; i++ )
	{
		if ( i > 0 )
			origins += " "
		origins += string( loc.respawnLocations[ i ].origin )
	}

	string distStr = "-"
	if ( n >= 2 )
		distStr = string( int( Distance( loc.respawnLocations[ 0 ].origin, loc.respawnLocations[ 1 ].origin ) ) )

	return "idx=" + string( idx ) + " names=" + loc.ids + " dist=" + distStr + " " + origins
}

//═══════════════════════════════════════════════════════════════════════════════
//
// SECTION 18: HELPER/UTILITY FUNCTIONS
// Generic utility and helper functions
//
//═══════════════════════════════════════════════════════════════════════════════

bool function FS_1v1_DevCheatsOk( entity player = null )
{
	if ( GetConVarBool( "sv_cheats" ) )
		return true

	string who = IsValid( player ) ? player.GetPlayerName() : "?"
	printt( "[FS-1V1] requires sv_cheats 1 from " + who )
	return false
}

void function DEV_1v1Init()
{
	foreach( string key, int value in e1v1State )
	{
		file.e1v1StateNameToIntMap[ key ] <- value
		file.e1v1StateIDToNameMap[ value ] <- key
	}
}

int function DEV_GetGamestateID( string e1v1StateRef )
{
	if( e1v1StateRef in file.e1v1StateNameToIntMap )
		return file.e1v1StateNameToIntMap[ e1v1StateRef ]

	return -1
}

string function DEV_GetGamestateRef( int e1v1StateEnum )
{
	if( e1v1StateEnum in file.e1v1StateIDToNameMap )
		return file.e1v1StateIDToNameMap[ e1v1StateEnum ]

	return "not found"
}

void function DEV_PrintGameStates()
{
	if ( !FS_1v1_DevCheatsOk() )
		return

	string printmsg = ""

	foreach( player in GetPlayerArray() )
	{
		int state = player.GetPlayerNetInt( "FS_1v1_PlayerState" )
		printmsg += string( player ) + " State: " + state + " : " + DEV_GetGamestateRef( state ) + " \n"
	}

	printt( printmsg )
}

void function DEV_acceptchal( entity player )
{
	if ( !FS_1v1_DevCheatsOk( player ) )
		return

	array<string> args = ["accept"]
	ClientCommand_mkos_challenge( player, args )
}

void function DEV_acceptedchallenges()
{
	if ( !FS_1v1_DevCheatsOk() )
		return

	foreach( int handle, entity player in file.acceptedChallenges )
	{
		printt( handle, player )
	}
}

void function DEV_allchals()
{
	if ( !FS_1v1_DevCheatsOk() )
		return

	string printtext = ""

	foreach( index, structs in file.allChallenges )
	{
		printtext += "\n\n --- All challenges Index: " + index + " ---\n\n"

		printtext += " Struct for player: " + string( structs.player ) + "\n"

		foreach( int handle, float ztime in structs.challengers )
		{
			printtext += "Handle: " + handle + " Time:" + ztime
		}
	}

	printt( printtext )
}

void function DEV_legend( entity player, int id )
{
	if ( !FS_1v1_DevCheatsOk( player ) )
		return
	if ( !IsValid( player ) )
		return

	AssignLegendToGroup( id, [ player ] )
}

void function DEV_printlegends()
{
	if ( !FS_1v1_DevCheatsOk() )
		return

	foreach ( char in GetAllCharacters() )
	{
		printt( ItemFlavor_GetHumanReadableRef( char ) )
	}
}

void function DEV_rest( entity player = null )
{
	if ( !FS_1v1_DevCheatsOk( player ) )
		return

	if ( !IsValid( player ) )
	{
		array<entity> players = GetPlayerArray()
		if ( players.len() < 1 )
			return
		player = players[ 0 ]
	}

	Gamemode1v1_ForceRest( player )
}

void function FS_1v1_DevMenuCmd( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return
	if ( !FS_1v1_DevCheatsOk( player ) )
		return
	if ( args.len() < 1 )
	{
		printt( "[FS-1V1] dev_1v1 rest|states|legends|accept|chals|accepted|next_round|champion|legend <id>|stress <spawn|start|stop|status|kick>" )
		return
	}

	string action = args[0].tolower()
	if ( action == "rest" )
	{
		DEV_rest( player )
		return
	}
	if ( action == "states" )
	{
		DEV_PrintGameStates()
		return
	}
	if ( action == "legends" )
	{
		DEV_printlegends()
		return
	}
	if ( action == "accept" )
	{
		DEV_acceptchal( player )
		return
	}
	if ( action == "chals" )
	{
		DEV_allchals()
		return
	}
	if ( action == "accepted" )
	{
		DEV_acceptedchallenges()
		return
	}
	if ( action == "next_round" )
	{
		ClientCommand_NextRound_1v1( player, [] )
		return
	}
	if ( action == "champion" )
	{
		ClientCommand_ChampionRoom_1v1( player, [] )
		return
	}
	if ( action == "legend" )
	{
		if ( args.len() < 2 || !IsStringNumeric( args[1] ) )
		{
			printt( "[FS-1V1] dev_1v1 legend <id>" )
			return
		}
		DEV_legend( player, args[1].tointeger() )
		return
	}
	if ( action == "stress" )
	{
		string sub = args.len() > 1 ? args[1].tolower() : ""
		if ( sub == "spawn" )
		{
			int n = 10
			if ( args.len() > 2 && IsStringNumber( args[2] ) )
				n = args[2].tointeger()
			DEV_1v1_StressTest_SpawnBots( n )
			return
		}
		if ( sub == "start" )
		{
			DEV_1v1_StressTest_Start()
			return
		}
		if ( sub == "stop" )
		{
			DEV_1v1_StressTest_Stop()
			return
		}
		if ( sub == "status" )
		{
			DEV_1v1_StressTest_Status()
			return
		}
		if ( sub == "kick" )
		{
			DEV_1v1_StressTest_KickBots()
			return
		}
		printt( "[FS-1V1] dev_1v1 stress spawn [count]|start|stop|status|kick" )
		return
	}

	printt( "[FS-1V1] unknown dev_1v1 action '" + action + "'" )
}

void function DecideToggleCollision_Rest( entity player, bool enable )
{
	if( settings.player_rest_collision_enabled || !settings.player_collision_enabled )
		return
		
	if( enable )
		EnablePlayerCollision( player )
	else 
		DisablePlayerCollision( player )
}

void function DisablePlayerCollision( entity player )
{
	player.kv.contents = CONTENTS_BULLETCLIP | CONTENTS_MONSTERCLIP | CONTENTS_HITBOX | CONTENTS_BLOCKLOS | CONTENTS_PHYSICSCLIP; //CONTENTS_PLAYERCLIP
}

void function EnablePlayerCollision( entity player )
{
	player.kv.contents = CONTENTS_BULLETCLIP | CONTENTS_MONSTERCLIP | CONTENTS_HITBOX | CONTENTS_BLOCKLOS | CONTENTS_PHYSICSCLIP | CONTENTS_PLAYERCLIP
}

int function Gamemode1v1_GetNumberOfGroupsInProgress()
{
	return file.activeMatches.len()
}

int function Gamemode1v1_GetNumberOfPlayersInGroupMap()
{
	return file.playerMatchMap.len()
}

// Gamemode1v1_SetWaitingRoomRadius moved to _1v1_ui.nut
// GetScore moved to _1v1_ui.nut
// PlayerRestoreHP_1v1 moved to _1v1_match.nut
// _CleanupPlayerEntities moved to _1v1_ui.nut

entity function getTimeOutPlayer() 
{
    foreach ( playerHandle, eachPlayerStruct in file.waitingQueue ) 
	{
        if ( eachPlayerStruct.IsTimeOut ) 
		{
			if(!IsValid(eachPlayerStruct) || !IsValid(eachPlayerStruct.player) || eachPlayerStruct.player.p.waitingFor1v1
				|| IsPlayerPendingChallenge( eachPlayerStruct.player ) || IsPlayerPendingLockOpponent( eachPlayerStruct.player ) )
			{
				continue
			}
			
			//string set = eachPlayerStruct.player.p.waitingFor1v1 ? "true": "false";
			//sqprint(format("TIMEOUTPLAYER IS player: %s setting for waiting is: %s", eachPlayerStruct.player.p.name, set))
            return eachPlayerStruct.player
        }
    }
	
    entity p
	return p
}

int function getTimeOutPlayerAmount() 
{
    int timeOutPlayerAmount = 0
	
    foreach ( playerHandle, eachPlayerStruct in file.waitingQueue ) 
	{
		// QueuedPlayer is a struct: IsValid(struct) does not validate the entity player.
		if ( !IsValid( eachPlayerStruct ) || !IsValid( eachPlayerStruct.player ) )
			continue

        if ( eachPlayerStruct.IsTimeOut && !eachPlayerStruct.player.p.waitingFor1v1
			&& !IsPlayerPendingChallenge( eachPlayerStruct.player ) && !IsPlayerPendingLockOpponent( eachPlayerStruct.player ) ) 
		{
            timeOutPlayerAmount++
        }
    }
    return timeOutPlayerAmount
}

// isScenariosMode moved to _1v1_ui.nut

// resetChallenges moved to _1v1_challenge.nut

// =====================================================================================
// STANDALONE CALLBACKS AND DEATH HANDLING
// =====================================================================================
void function _OnPlayerKilled1v1( entity victim, entity attacker, var damageInfo )
{
	// In 1v1 mode, only call the 1v1-specific death handler
	// Do NOT call standard _OnPlayerDied from DM

	if( !IsValid( victim ) )
		return

	// Battle log
	if( IsValid( attacker ) && attacker.IsPlayer() )
		_AppendBattleLogEvent1v1( attacker, victim )

	// A kill ends the round, so this is where head-glitch totals get banked to
	// disk and the per-round score starts over. The session tally survives.
	FS1v1_Stats_MarkDirty( victim )
	HeadGlitch_ResetScore( victim )

	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim )
	{
		FS1v1_Stats_MarkDirty( attacker )
		HeadGlitch_ResetScore( attacker )
	}

	// 1v1 handles its own death logic (round tracking, respawning, etc.)
	Gamemode1v1_OnPlayerKilled( victim, attacker, damageInfo )
}

void function _AppendBattleLogEvent1v1( entity killer, entity victim )
{
	if ( !IsValid( killer ) || !IsValid( victim ) )
		return

	if ( !killer.IsPlayer() || !victim.IsPlayer() )
		return

	// Log format for 1v1 mode
	string flowstate_gamemode = "fs_1v1"

	// Additional variant info
	switch( GetCurrentPlaylistName() )
	{
		case "fs_vamp_1v1":
			flowstate_gamemode = "fs_vamp_1v1"
			break
		case "fs_1v1_headshots_only":
			flowstate_gamemode = "fs_1v1_headshots_only"
			break
		case "fs_lgduels_1v1":
			flowstate_gamemode = "fs_lgduels_1v1"
			break
		case "fs_1v1_coaching":
			flowstate_gamemode = "fs_1v1_coaching"
			break
	}

	// TODO: Full battle log implementation if needed
}

void function _OnTdmStateEnter_InProgress1v1()
{
	resetChallenges()

	// Round clock: Flowstate net time (script) + FreeDM/Lockdown gamestate clock.
	// The combat clock starts after the intro countdown, not at the state change.
	float introTime  = FS_1v1_RoundIntroTime()
	float roundStart = Time() + introTime
	float roundEnd   = roundStart + settings.roundTime
	// SNVT_INT tops out at 511; the counter is display-only past that.
	SetGlobalNetInt( "FSDM_CurrentRound", file.currentRound > 511 ? 511 : file.currentRound )
	SetGlobalNetTime( "FSDM_RoundIntroEndTime", introTime > 0 ? roundStart : -1.0 )
	SetGlobalNetTime( "flowstate_DMStartTime", roundStart )
	SetGlobalNetTime( "flowstate_DMRoundEndTime", roundEnd )

	// When round starts (TDM state enters IN_PROGRESS)
	foreach( entity player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue

		if ( FS_1v1_PlayerHasClient( player ) )
			Remote_CallFunction_Replay( player, "ServerCallback_FSDM_OpenVotingPhase", false )

		player.UnfreezeControlsOnServer()
		player.UnforceStand()
		if ( FS_1v1_IsLobbyState( Gamemode1v1_GetPlayerGamestate( player ) )
			&& Gamemode1v1_GetPlayerGamestate( player ) != e1v1State.RECAP )
			FS_1v1_ApplyLobbyLoadout( player )
	}

	// Reset stats for new round
	if( file.currentRound > 1 )
	{
		foreach( entity player in GetPlayerArray() )
		{
			_ResetPlayerStats1v1( player )
			player.p.lastKiller = null
		}
	}

	// Leave recap now that the scoreboard is dismissed: back to the queue, or back to
	// rest for anyone who asked for it.
	foreach( entity player in GetPlayerArray() )
	{
		if( !IsValid( player ) )
			continue

		if( Gamemode1v1_GetPlayerGamestate( player ) != e1v1State.RECAP )
			continue

		if( Gamemode1v1_IsPlayerResting( player ) )
			Gamemode1v1_SetPlayerGamestate( player, e1v1State.RESTING )
		else
			FS_1v1_EnqueueFromRecap( player )
	}

	thread _MatchmakingCountdown()
}

void function _MatchmakingCountdown()
{
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !FS_1v1_PlayerHasClient( player ) )
			continue
		DirectClearPanel( player, eNotify.MATCHMAKING_COUNTDOWN )
	}

	float introEnd = GetGlobalNetTime( "FSDM_RoundIntroEndTime" )
	if ( introEnd > Time() )
		wait introEnd - Time()

	// Pairing opens here, so every queue deadline starts here -- see
	// FS_1v1_RearmQueueForRound.
	FS_1v1_RearmQueueForRound()

	TriggerMatchmaking()

	FS_1v1_RequestRestingNotificationRefresh()
}

void function _ResetPlayerStats1v1( entity player )
{
	if( !IsValid( player ) )
		return

	// Career totals are baseline + live netint, and the netints are about to go to
	// zero, so fold this round in first or the next flush writes the baseline back.
	player.p.season_kills += player.GetPlayerNetInt( "kills" )
	player.p.season_deaths += player.GetPlayerNetInt( "deaths" )
	FS1v1_Stats_MarkDirty( player )

	// Reset kills, deaths, assists
	player.SetPlayerNetInt( "kills", 0 )
	player.SetPlayerNetInt( "assists", 0 )
	player.SetPlayerNetInt( "deaths", 0 )
	player.SetPlayerNetInt( "damage", 0 )
	player.SetPlayerNetInt( "damageDealt", 0 )
	player.SetPlayerGameStat( PGS_KILLS, 0 )
	player.SetPlayerGameStat( PGS_DEATHS, 0 )
	player.p.fs_stats_hits = 0
	player.p.fs_stats_shots = 0
	player.p.fs_stats_headshots = 0
	FS1v1_RemoteStats_ResetWeapon( player )
	player.SetPlayerNetInt( "accuracy", 0 )

	if( GetCurrentPlaylistName() == "fs_lgduels_1v1" )
	{
		player.p.totalLGHits = 0
		player.p.totalLGShots = 0
	}
}

void function FS_1v1_WaitForActiveMatchesToSettle()
{
	if ( file.activeMatches.len() == 0 )
		return

	float grace = GetCurrentPlaylistVarFloat( "fs_1v1_round_end_grace", ROUND_END_GRACE_DEFAULT )
	if ( grace < 0.0 )
		grace = 0.0

	int secs = int( grace )
	if ( secs < 1 )
		secs = 1

	if ( grace > 0.0 )
	{
		foreach ( entity player in GetPlayerArray() )
			LocalMsg( player, "#FS_ROUND_END_SPLASH", "", eMsgUI.SPLASH, grace, secs.tostring() )
	}

	foreach ( entity player in FS_1v1_GetRoundEndIdlePlayers() )
	{
		DirectClearPanel( player, eNotify.RESTING )
		DirectClearPanel( player, eNotify.MATCHING )
	}

	printt( "[FS-1V1] round-end settle matches=" + string( file.activeMatches.len() ) + " grace=" + string( grace ) )

	float deadline = Time() + grace
	int shownRemaining = -1

	while ( file.activeMatches.len() > 0 )
	{
		if ( Time() >= deadline )
		{
			printt( "[FS-1V1] round-end grace expired, still " + string( file.activeMatches.len() ) + " live matches -- forcing finish" )
			break
		}

		int remaining = int( ceil( deadline - Time() ) )
		if ( remaining < 0 )
			remaining = 0

		if ( remaining != shownRemaining )
		{
			shownRemaining = remaining
			string countText = format( "%ds", remaining )

			foreach ( entity player in FS_1v1_GetRoundEndIdlePlayers() )
				DirectShowPanel( player, eNotify.WAITING, "#FS_ROUND_END_PANEL", countText )
		}

		wait 0.1
	}

	foreach ( entity player in FS_1v1_GetRoundEndIdlePlayers() )
		DirectClearPanel( player, eNotify.WAITING )
}

array<entity> function FS_1v1_GetRoundEndIdlePlayers()
{
	array<entity> idle = []

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !FS_1v1_PlayerHasClient( player ) )
			continue

		int state = Gamemode1v1_GetPlayerGamestate( player )
		if ( state != e1v1State.WAITING && state != e1v1State.RESTING )
			continue

		idle.append( player )
	}

	return idle
}

void function _OnRoundEnd1v1()
{
	FS_1v1_LatchMatchChampion()

	ForceAllRoundsToFinish_solomode()
	FS1v1_RemoteStats_SubmitSession()
	FS1v1_Elo_ResetLog()

	foreach( entity player in GetPlayerArray() )
	{
		if( !IsValid( player ) || !FS_1v1_PlayerHasClient( player ) )
			continue

		LocalMsg( player, "#FS_NULL", "", eMsgUI.EVENT, 1 )
	}

	file.currentRound++
}


// Weapon functions moved to _1v1_weapons.nut


// =====================================================================================
// VARIANT MODE CALLBACKS
// =====================================================================================

//Life steal mode
void function Vamp_OnPlayerDamaged(entity victim, var damageInfo)
{
	if ( !IsValid(victim) || !victim.IsPlayer() || !IsAlive( victim ) )
		return

	entity attacker = InflictorOwner( DamageInfo_GetAttacker(damageInfo) )

	if( !IsValid( attacker ) || !attacker.IsPlayer() || !IsAlive( attacker ) )
		return

	int sourceId = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	float damage = DamageInfo_GetDamage( damageInfo )

	float attshield = float( attacker.GetShieldHealth() )
	float atthealth = float( attacker.GetHealth() )

	if ( atthealth < attacker.GetMaxHealth() )
	{
		attacker.SetHealth( min( atthealth + damage, float( attacker.GetMaxHealth() ) ) )
	}
	else if ( attshield < attacker.GetShieldHealthMax() )
	{
		attacker.SetShieldHealth( min( attshield + damage, float( attacker.GetShieldHealthMax() ) ) )
	}
}

void function Vamp_OnWeaponAttack( entity player, entity weapon, string weaponName, int ammoUsed, vector attackOrigin, vector attackDir )
{
	// if( !IsValid( player ) ) //Is this necessary to perform a valid check per bullet.. ?
		// return

	player.RefillAllAmmo()
}


// =====================================================================================
// CROSS-REALM SCOREBOARD SYNC
// Remotes only. Do not read other players' netvars on the client -- those ents
// are not in the snapshot when the viewer is in another realm.
// =====================================================================================

// Remote calls sent to one client per frame. The client's S->C hold queue is
// finite; a burst past it is released early and lands out of send order.
const int SCOREBOARD_1V1_SEND_BUDGET = 32
const float SCOREBOARD_1V1_RESYNC_MIN_INTERVAL = 3.0

// Pack a player name string into 4 integers (4 ASCII chars per int, little-endian).
// Supports names up to 16 characters. Shorter names are zero-padded.
array<int> function Scoreboard1v1_PackName( string name )
{
	array<int> result = [0, 0, 0, 0]
	int nameLen = name.len()
	if ( nameLen > 16 )
		nameLen = 16

	for ( int i = 0; i < nameLen; i++ )
	{
		// Mask to a byte: a non-ASCII name sign-extends and smears 1-bits across
		// the whole packed int, which the 0..INT_MAX remote arg range then rejects.
		int charVal = expect int( name[i] ) & 0xFF
		int intIdx = i / 4
		int byteIdx = i % 4
		result[intIdx] = result[intIdx] | ( charVal << ( byteIdx * 8 ) )
	}

	return result
}

// Global rank for VS HUD FSDM_1v1_PositionInScoreboard (1..N).
// Order: kills desc, then damage desc -- matches FSLeaderboard score/kills intent with a real tiebreak.
void function Scoreboard1v1_WriteRanks()
{
	array<entity> ranked = []

	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			ranked.append( player )
	}

	ranked.sort( int function( entity a, entity b )
	{
		int ka = a.GetPlayerNetInt( "kills" )
		int kb = b.GetPlayerNetInt( "kills" )
		if ( ka < kb )
			return 1
		if ( ka > kb )
			return -1

		int da = a.GetPlayerNetInt( "damage" )
		int db = b.GetPlayerNetInt( "damage" )
		if ( da < db )
			return 1
		if ( da > db )
			return -1

		return 0
	} )

	for ( int i = 0; i < ranked.len(); i++ )
	{
		if ( IsValid( ranked[i] ) )
			ranked[i].SetPlayerNetInt( "FSDM_1v1_PositionInScoreboard", i + 1 )
	}
}

int function Scoreboard1v1_HashPacked( int n1, int n2, int n3, int n4 )
{
	int h = n1 ^ n2 ^ n3 ^ n4
	if ( h == 0 )
		h = 1
	return h
}

int function Scoreboard1v1_PackKdPing( int kills, int deaths, int latency )
{
	if ( kills < 0 )
		kills = 0
	if ( kills > 4095 )
		kills = 4095
	if ( deaths < 0 )
		deaths = 0
	if ( deaths > 4095 )
		deaths = 4095
	if ( latency < 0 )
		latency = 0
	if ( latency > 255 )
		latency = 255
	return kills | ( deaths << 12 ) | ( latency << 24 )
}

// input rides bits 27-28 as 0 unknown / 1 MnK / 2 controller: the client cannot
// read FS_PlayerIsMnk for a player outside its realm.
int function Scoreboard1v1_PackDmgFlags( int damage, int isLocal, int streak, int input )
{
	if ( damage < 0 )
		damage = 0
	if ( damage > 1048575 )
		damage = 1048575
	if ( isLocal != 1 )
		isLocal = 0
	if ( streak < 0 )
		streak = 0
	if ( streak > 63 )
		streak = 63
	if ( input < 0 || input > 1 )
		input = -1
	return damage | ( isLocal << 20 ) | ( streak << 21 ) | ( ( input + 1 ) << 27 )
}

// SyncToClient rebuilds every row for every watching client, so an uncached
// loadout read here would be six slot lookups per player per client.
const float SCOREBOARD_CARD_GUID_TTL = 2.0

array<int> function Scoreboard1v1_CardFlavorGuids( entity player )
{
	int handle = player.p.handle
	if ( handle in file.scoreboardCardGuidsAt && Time() < file.scoreboardCardGuidsAt[handle] )
		return file.scoreboardCardGuids[handle]

	array<int> guids = Scoreboard1v1_ReadCardFlavorGuids( player )
	file.scoreboardCardGuids[handle] <- guids
	file.scoreboardCardGuidsAt[handle] <- Time() + SCOREBOARD_CARD_GUID_TTL
	return guids
}

array<int> function Scoreboard1v1_ReadCardFlavorGuids( entity player )
{
	array<int> guids = [ 0, 0, 0 ]

	EHI ehi = ToEHI( player )
	if ( !LoadoutSlot_IsReady( ehi, Loadout_Character() ) )
		return guids

	ItemFlavor character = LoadoutSlot_GetItemFlavor( ehi, Loadout_Character() )
	guids[0] = ItemFlavor_GetGUID( character )

	if ( LoadoutSlot_IsReady( ehi, Loadout_CharacterSkin( character ) ) )
		guids[1] = ItemFlavor_GetGUID( LoadoutSlot_GetItemFlavor( ehi, Loadout_CharacterSkin( character ) ) )
	if ( LoadoutSlot_IsReady( ehi, Loadout_GladiatorCardFrame( character ) ) )
		guids[2] = ItemFlavor_GetGUID( LoadoutSlot_GetItemFlavor( ehi, Loadout_GladiatorCardFrame( character ) ) )

	return guids
}

void function Scoreboard1v1_SendCardChunk( entity client, int c, array<int> hashes, array<int> cards, array<int> rows, int i )
{
	array<int> h = [ 0, 0 ]
	array<int> ck = [ 0, 0 ]
	array<int> cd = [ 0, 0 ]
	array<int> ch = [ 0, 0 ]
	array<int> sk = [ 0, 0 ]
	array<int> fr = [ 0, 0 ]

	for ( int k = 0; k < c && k < 2; k++ )
	{
		int row = rows[i + k]
		int base = row * 5
		h[k] = hashes[row]
		ck[k] = cards[base]
		cd[k] = cards[base + 1]
		ch[k] = cards[base + 2]
		sk[k] = cards[base + 3]
		fr[k] = cards[base + 4]
	}

	Remote_CallFunction_NonReplay( client, "ServerCallback_1v1_SbCard", c,
		h[0], ck[0], cd[0], ch[0], sk[0], fr[0],
		h[1], ck[1], cd[1], ch[1], sk[1], fr[1] )
}

void function Scoreboard1v1_SendSlotChunk( entity client, int c, array<int> hashes, array<int> slots, int i )
{
	array<int> h = [0, 0, 0, 0, 0, 0]
	array<int> s = [0, 0, 0, 0, 0, 0]

	for ( int k = 0; k < c && k < 6; k++ )
	{
		h[k] = hashes[i + k]
		s[k] = slots[i + k]
	}

	Remote_CallFunction_NonReplay( client, "ServerCallback_1v1_SbSlot", c,
		h[0], s[0], h[1], s[1], h[2], s[2], h[3], s[3], h[4], s[4], h[5], s[5] )
}

void function Scoreboard1v1_SendNameChunk( entity client, int c, array<int> hashes, array<int> n1s, array<int> n2s, array<int> n3s, array<int> n4s, int i )
{
	int h0 = hashes[i]
	int a0 = n1s[i]
	int b0 = n2s[i]
	int c0 = n3s[i]
	int d0 = n4s[i]
	int h1 = 0
	int a1 = 0
	int b1 = 0
	int c1 = 0
	int d1 = 0
	int h2 = 0
	int a2 = 0
	int b2 = 0
	int c2 = 0
	int d2 = 0
	if ( c > 1 )
	{
		h1 = hashes[i + 1]
		a1 = n1s[i + 1]
		b1 = n2s[i + 1]
		c1 = n3s[i + 1]
		d1 = n4s[i + 1]
	}
	if ( c > 2 )
	{
		h2 = hashes[i + 2]
		a2 = n1s[i + 2]
		b2 = n2s[i + 2]
		c2 = n3s[i + 2]
		d2 = n4s[i + 2]
	}
	Remote_CallFunction_NonReplay( client, "ServerCallback_1v1_SbName",
		c, h0, a0, b0, c0, d0, h1, a1, b1, c1, d1, h2, a2, b2, c2, d2 )
}

void function Scoreboard1v1_SendStatsChunk( entity client, int c, array<int> hashes, array<int> kdPing, array<int> dmgFlags, array<int> handles, int i )
{
	int localHandle = client.p.handle
	int h0 = hashes[i]
	int p0 = kdPing[i]
	int d0 = dmgFlags[i]
	if ( handles[i] == localHandle )
		d0 = d0 | ( 1 << 20 )
	int h1 = 0
	int p1 = 0
	int d1 = 0
	int h2 = 0
	int p2 = 0
	int d2 = 0
	int h3 = 0
	int p3 = 0
	int d3 = 0
	int h4 = 0
	int p4 = 0
	int d4 = 0
	if ( c > 1 )
	{
		h1 = hashes[i + 1]
		p1 = kdPing[i + 1]
		d1 = dmgFlags[i + 1]
		if ( handles[i + 1] == localHandle )
			d1 = d1 | ( 1 << 20 )
	}
	if ( c > 2 )
	{
		h2 = hashes[i + 2]
		p2 = kdPing[i + 2]
		d2 = dmgFlags[i + 2]
		if ( handles[i + 2] == localHandle )
			d2 = d2 | ( 1 << 20 )
	}
	if ( c > 3 )
	{
		h3 = hashes[i + 3]
		p3 = kdPing[i + 3]
		d3 = dmgFlags[i + 3]
		if ( handles[i + 3] == localHandle )
			d3 = d3 | ( 1 << 20 )
	}
	if ( c > 4 )
	{
		h4 = hashes[i + 4]
		p4 = kdPing[i + 4]
		d4 = dmgFlags[i + 4]
		if ( handles[i + 4] == localHandle )
			d4 = d4 | ( 1 << 20 )
	}
	Remote_CallFunction_NonReplay( client, "ServerCallback_1v1_SbStats",
		c, h0, p0, d0, h1, p1, d1, h2, p2, d2, h3, p3, d3, h4, p4, d4 )
}

void function Scoreboard1v1_RebuildPackedRows()
{
	file.sbHashes.resize( 0 )
	file.sbN1s.resize( 0 )
	file.sbN2s.resize( 0 )
	file.sbN3s.resize( 0 )
	file.sbN4s.resize( 0 )
	file.sbKdPing.resize( 0 )
	file.sbDmgFlags.resize( 0 )
	file.sbSlots.resize( 0 )
	file.sbCards.resize( 0 )
	file.sbHandles.resize( 0 )

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue

		array<int> packed = Scoreboard1v1_PackName( player.GetPlayerName() )
		int h = Scoreboard1v1_HashPacked( packed[0], packed[1], packed[2], packed[3] )
		int kills = player.GetPlayerNetInt( "kills" )
		int deaths = player.GetPlayerNetInt( "deaths" )
		int damage = player.GetPlayerNetInt( "damage" )
		int latency = player.GetPlayerNetInt( "latency" )
		int streak = player.p.winStreak

		file.sbHashes.append( h )
		file.sbSlots.append( player.GetEntIndex() )
		file.sbHandles.append( player.p.handle )
		file.sbN1s.append( packed[0] )
		file.sbN2s.append( packed[1] )
		file.sbN3s.append( packed[2] )
		file.sbN4s.append( packed[3] )
		file.sbKdPing.append( Scoreboard1v1_PackKdPing( kills, deaths, latency ) )
		file.sbDmgFlags.append( Scoreboard1v1_PackDmgFlags( damage, 0, streak, player.p.input ) )

		array<int> flavors = Scoreboard1v1_CardFlavorGuids( player )
		int careerKills = player.GetPlayerNetInt( "FS_1v1_CareerKills" )
		int careerDeaths = player.GetPlayerNetInt( "FS_1v1_CareerDeaths" )
		file.sbCards.append( careerKills )
		file.sbCards.append( careerDeaths )
		file.sbCards.append( flavors[0] )
		file.sbCards.append( flavors[1] )
		file.sbCards.append( flavors[2] )
	}
}

// A newer sync for the same client supersedes this one: it re-sends the clear
// and the whole set, so the older run must stop rather than interleave.
bool function Scoreboard1v1_SyncStillCurrent( entity client, int handle, int seq )
{
	if ( !IsValid( client ) )
		return false
	if ( !( handle in file.scoreboardSyncSeq ) )
		return false
	return file.scoreboardSyncSeq[handle] == seq
}

// Runs in a thread: a full sync is paced across frames so one board never
// outruns the client's S->C hold queue and arrives out of order.
void function Scoreboard1v1_SyncToClient( entity client )
{
	if ( !IsValid( client ) )
		return

	if ( file.sbHashes.len() < 1 )
		Scoreboard1v1_RebuildPackedRows()

	// The row set is rebuilt on a timer, so a paced send reads its own copy.
	array<int> hashes = clone file.sbHashes
	array<int> n1s = clone file.sbN1s
	array<int> n2s = clone file.sbN2s
	array<int> n3s = clone file.sbN3s
	array<int> n4s = clone file.sbN4s
	array<int> slots = clone file.sbSlots
	array<int> kdPing = clone file.sbKdPing
	array<int> dmgFlags = clone file.sbDmgFlags
	array<int> handles = clone file.sbHandles
	array<int> cards = clone file.sbCards

	int n = hashes.len()
	int fp = n
	int cardFp = n
	array<int> cardRows = []
	for ( int r = 0; r < n; r++ )
	{
		int h = hashes[r]
		fp = fp ^ h
		int base = r * 5
		cardFp = cardFp ^ h ^ cards[base] ^ cards[base + 1] ^ cards[base + 2] ^ cards[base + 3] ^ cards[base + 4]

		// charGuid 0 is the client's own "no card" case, and bots never have one.
		if ( cards[base + 2] != 0 )
			cardRows.append( r )
	}

	int handle = client.p.handle
	int seq = ( handle in file.scoreboardSyncSeq ) ? file.scoreboardSyncSeq[handle] + 1 : 1
	file.scoreboardSyncSeq[handle] <- seq

	bool sendNames = true
	if ( handle in file.scoreboardNameFp )
		sendNames = ( file.scoreboardNameFp[handle] != fp )

	bool sendCards = sendNames
	if ( !sendCards && handle in file.scoreboardCardFp )
		sendCards = ( file.scoreboardCardFp[handle] != cardFp )

	int sent = 0

	if ( sendNames )
	{
		// Names first and the fingerprint last: an abandoned run must not leave a
		// fingerprint claiming names this client never received, or every later
		// sync skips them and the board draws blank rows forever.
		Remote_CallFunction_NonReplay( client, "ServerCallback_1v1_ScoreboardClear" )
		sent++

		int i = 0
		while ( i < n )
		{
			int c = n - i
			if ( c > 3 )
				c = 3
			Scoreboard1v1_SendNameChunk( client, c, hashes, n1s, n2s, n3s, n4s, i )
			i += c

			if ( ++sent < SCOREBOARD_1V1_SEND_BUDGET )
				continue
			WaitFrame()
			if ( !Scoreboard1v1_SyncStillCurrent( client, handle, seq ) )
				return
			sent = 0
		}

		int j = 0
		while ( j < n )
		{
			int c = n - j
			if ( c > 6 )
				c = 6
			Scoreboard1v1_SendSlotChunk( client, c, hashes, slots, j )
			j += c

			if ( ++sent < SCOREBOARD_1V1_SEND_BUDGET )
				continue
			WaitFrame()
			if ( !Scoreboard1v1_SyncStillCurrent( client, handle, seq ) )
				return
			sent = 0
		}

		file.scoreboardNameFp[handle] <- fp
	}

	int i = 0
	while ( i < n )
	{
		int c = n - i
		if ( c > 5 )
			c = 5
		Scoreboard1v1_SendStatsChunk( client, c, hashes, kdPing, dmgFlags, handles, i )
		i += c

		if ( ++sent < SCOREBOARD_1V1_SEND_BUDGET )
			continue
		WaitFrame()
		if ( !Scoreboard1v1_SyncStillCurrent( client, handle, seq ) )
			return
		sent = 0
	}

	if ( sendCards )
	{
		int k = 0
		while ( k < cardRows.len() )
		{
			int c = cardRows.len() - k
			if ( c > 2 )
				c = 2
			Scoreboard1v1_SendCardChunk( client, c, hashes, cards, cardRows, k )
			k += c

			if ( ++sent < SCOREBOARD_1V1_SEND_BUDGET )
				continue
			WaitFrame()
			if ( !Scoreboard1v1_SyncStillCurrent( client, handle, seq ) )
				return
			sent = 0
		}

		file.scoreboardCardFp[handle] <- cardFp
	}

	Remote_CallFunction_NonReplay( client, "ServerCallback_1v1_ScoreboardRefresh" )
}

void function Scoreboard1v1_PresentRoundEnd()
{
	Scoreboard1v1_WriteRanks()
	Scoreboard1v1_RebuildPackedRows()

	float t0 = Time()
	float hold = float( flowstateSettings.endgame_delay )
	int n = 0

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) || !FS_1v1_PlayerHasClient( player ) )
			continue

		int handle = player.p.handle
		file.scoreboardOpenClients[ handle ] <- true
		if ( handle in file.scoreboardNameFp )
			delete file.scoreboardNameFp[ handle ]
		if ( handle in file.scoreboardCardFp )
			delete file.scoreboardCardFp[ handle ]

		Scoreboard1v1_SyncToClient( player )
		Remote_CallFunction_ByRef( player, "ForceScoreboardLoseFocus" )
		Remote_CallFunction_NonReplay( player, "ServerCallback_FSDM_CoolCamera" )
		Remote_CallFunction_Replay( player, "ServerCallback_FSDM_OpenVotingPhase", true )
		EmitSoundOnEntityOnlyToPlayer( player, player, "UI_Menu_RoundSummary_Results" )

		n++
		if ( n % 2 == 0 )
			WaitEndFrame()
	}

	printt( "[FS-1V1] round-end board clients=" + string( n ) + " dt=" + string( Time() - t0 ) )

	float left = hold - ( Time() - t0 )
	if ( left > 0.0 )
		wait left
}

void function CC_1v1_ScoreboardOpen( entity player, array<string> args )
{
	if ( !IsValid( player ) || args.len() < 1 )
		return

	int handle = player.p.handle
	if ( args[0] == "2" )
	{
		// The client received rows it has no name for. Resend the whole board,
		// rate-limited: this arm is reachable by any client that asks.
		if ( !( handle in file.scoreboardOpenClients ) )
			return
		if ( handle in file.scoreboardResyncTime
			&& Time() - file.scoreboardResyncTime[handle] < SCOREBOARD_1V1_RESYNC_MIN_INTERVAL )
			return

		file.scoreboardResyncTime[handle] <- Time()
		if ( handle in file.scoreboardNameFp )
			delete file.scoreboardNameFp[handle]
		if ( handle in file.scoreboardCardFp )
			delete file.scoreboardCardFp[handle]

		Scoreboard1v1_WriteRanks()
		Scoreboard1v1_RebuildPackedRows()
		thread Scoreboard1v1_SyncToClient( player )
		FS_1v1_PushChallengeState( player )
		return
	}

	if ( args[0] == "1" )
	{
		bool already = ( handle in file.scoreboardOpenClients )
		file.scoreboardOpenClients[ handle ] <- true
		if ( already )
		{
			FS_1v1_PushChallengeState( player )
			return
		}

		Scoreboard1v1_WriteRanks()
		Scoreboard1v1_RebuildPackedRows()
		thread Scoreboard1v1_SyncToClient( player )
		FS_1v1_PushChallengeState( player )
	}
	else
	{
		if ( handle in file.scoreboardOpenClients )
			delete file.scoreboardOpenClients[ handle ]
		if ( handle in file.scoreboardNameFp )
			delete file.scoreboardNameFp[ handle ]
		if ( handle in file.scoreboardCardFp )
			delete file.scoreboardCardFp[ handle ]
	}
}

void function Scoreboard1v1_SyncThread()
{
	while ( GetGameState() < eGameState.Playing )
		wait 1

	while ( true )
	{
		if ( GetTDMState() != eTDMState.IN_PROGRESS || GetChampionShowingState() )
		{
			wait 1
			continue
		}

		Scoreboard1v1_WriteRanks()
		FS_1v1_PublishConnectedCount()
		Scoreboard1v1_RebuildPackedRows()

		foreach ( entity client in GetPlayerArray() )
		{
			if ( !IsValid( client ) )
				continue
			if ( !( client.p.handle in file.scoreboardOpenClients ) )
				continue

			Scoreboard1v1_SyncToClient( client )
		}

		wait 3
	}
}
