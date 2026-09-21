// Flowstate 1v1. CafeFPS (makimakima, mkos).
untyped

global function Cl_Gamemode1v1_Init
global function CL_1v1_RegisterNetworkFunctions

// UI visibility functions
global function FS_1v1_ToggleUIVisibility
global function Toggle1v1Scoreboard
global function ForceHide1v1Scoreboard
global function ForceShow1v1Scoreboard
global function SetShow1v1Scoreboard
global function FS_1v1_DisplayHints
global function FS_Show1v1Banner
global function FS_1v1_SetCombatHudVisible
global function FS_1v1_SetMinimapVisible
global function FS_1v1_RestoreFfaPlayHud
global function FS_1v1_HideFfaPlayHud

global function Gamemode1v1_ForceLegendSelector_Deprecated

// Cross-realm scoreboard sync callbacks (server pushes data bypassing realm filtering)
global function ServerCallback_1v1_SbName
global function ServerCallback_1v1_SbStats
global function ServerCallback_1v1_SbSlot
global function ServerCallback_1v1_SbCard
global function ServerCallback_1v1_ChallengeState
global function ServerCallback_1v1_ChallengeInbox
global function ServerCallback_1v1_ScoreboardClear
global function ServerCallback_1v1_ScoreboardRefresh
global function ServerCallback_1v1_VsHudEnemy
global function ServerCallback_1v1_VsHudHide
global function ServerCallback_1v1_Obituary
// UI -> client: FSLeaderboard MENU_CLOSE clears fullScoreboardOpen
global function FS_1v1_OnFullScoreboardClosed
global function FS_1v1_ForceCloseVoluntaryLeaderboard
global function FS_1v1_BeginLeaderboardTransition
global function FS_1v1_ToggleFullScoreboard
global function FS_1v1_ToggleMuteByName
global function FS_1v1_FindPlayerByName
global function ServerCallback_FSDM_SetScreen
global function ServerCallback_FSDM_OpenVotingPhase

// HUD element name constants
const string HUD_1V1_BG             = "FS_1v1_UI_BG"
const string HUD_1V1_ENEMY_NAME     = "FS_1v1_UI_EnemyName"
const string HUD_1V1_ENEMY_KILLS    = "FS_1v1_UI_EnemyKills"
const string HUD_1V1_ENEMY_DEATHS   = "FS_1v1_UI_EnemyDeaths"
const string HUD_1V1_ENEMY_DAMAGE   = "FS_1v1_UI_EnemyDamage"
const string HUD_1V1_ENEMY_LATENCY  = "FS_1v1_UI_EnemyLatency"
const string HUD_1V1_ENEMY_POSITION = "FS_1v1_UI_EnemyPosition"
const string HUD_1V1_NAME           = "FS_1v1_UI_Name"
const string HUD_1V1_KILLS          = "FS_1v1_UI_Kills"
const string HUD_1V1_DEATHS         = "FS_1v1_UI_Deaths"
const string HUD_1V1_DAMAGE         = "FS_1v1_UI_Damage"
const string HUD_1V1_LATENCY        = "FS_1v1_UI_Latency"
const string HUD_1V1_POSITION       = "FS_1v1_UI_Position"
const string HUD_COUNTDOWN_TEXT     = "FS_DMCountDown_Text"
const string HUD_COUNTDOWN_FRAME    = "FS_DMCountDown_Frame"
const string HUD_1V1_BANNER         = "FS_1v1Banner"

// The VS panel's rui draws the names and stats itself. Flip this off to fall
// back to the separate vgui labels.
const bool VSHUD_RUI_TEXT = true

// Scoreboard1v1_PackName packs a name into 4 ints, 4 bytes each.
const int SCOREBOARD_1V1_PACKED_NAME_MAX = 16
const float SCOREBOARD_1V1_RESYNC_COOLDOWN = 3.0

// Retail TDM (freedm) HUD assets, reused for the 1v1 round.
const asset  FS_1V1_COUNTDOWN_RUI      = $"ui/freedm_countdown_timer.rpak"
const float  FS_1V1_COUNTDOWN_SHRINK   = 3.0
const string FS_1V1_COUNTDOWN_SOUND    = "TDM_UI_InGame_Countdown"
const string FS_1V1_ROUND_START_SOUND  = "TDM_UI_StartRoundHUD"

const asset  FS_1V1_HINT_RUI           = $"ui/wraith_comms_hint.rpak"

const asset  FS_1V1_LOBBYINFO_RUI      = $"ui/fs_1v1_lobbyinfo.rpak"

// Cached scoreboard entry for cross-realm display
struct ScoreboardCacheEntry
{
	int hash
	string name
	int kills
	int deaths
	float kd
	int damage
	int latency
	int isLocal
	int winStreak = 0
	int rank = 0
	int slot = -1
	int input = -1
	int careerKills = -1
	int careerDeaths = -1
	int charGuid = 0
	int skinGuid = 0
	int frameGuid = 0
}

struct {
	var lobbyInfoRui
	var lobbyInfoTopo
	int lobbyInfoCount = -1
	bool lobbyInfoProbed = false
	var activeQuickHint2
	int hintState = e1v1State.INVALID
	var roundIntroRui
	bool show1v1Scoreboard = true
	bool vsHudShown = false
	bool hudSuppressed = false
	entity vsHudEnemy = null
	int lastLocalPlayerState = e1v1State.INVALID

	// Cross-realm scoreboard cache (populated by server push)
	array<ScoreboardCacheEntry> scoreboardCache
	bool scoreboardMissingNames = false
	float scoreboardResyncTime = -999.0
	table<int, ScoreboardCacheEntry> scoreboardByHash
	table<string, bool> chatMutedNames
	bool scoreboardDataReady = false
	bool fullScoreboardOpen = false
	bool roundEndScoreboard = false
	bool leaderboardTransitionLock = false
	bool didScorebarSetup = false

	bool vsHudRemoteActive = false
	string vsHudEnemyName = ""
	int vsHudEnemyKills = 0
	int vsHudEnemyDeaths = 0
	int vsHudEnemyDamage = 0
	int vsHudEnemyLatency = 0
	int vsHudEnemyRank = 0
	int vsHudLocalRank = 0

	string scorebarDeathArg = "?"
	bool combatHudPainted = false
	bool minimapHeldHidden = false
	bool enemyMinimapActive = false
	var enemyMinimapRui = null
	entity enemyMinimapTracked = null
} file

void function Cl_Gamemode1v1_Init()
{
	// FreeDM scorebar: kills, damage, match clock. No squads-remaining block.
	// Must run before ClGameState_Init -> CreateScoreRUI.
	ClGameState_RegisterGameStateAsset( $"ui/gamestate_freedm_mode.rpak" )
	ClGameState_RegisterGameStateFullmapAsset( $"ui/gamestate_info_fullmap_freedm.rpak" )
	SetGameModeScoreBarUpdateRulesWithFlags( FS_1v1_GameModeScoreBarRules, sbflag.SKIP_STANDARD_UPDATE )

	// Core: death-screen refuse etc. Inventory signals registered in SharedInit;
	// full inventory init after Sh_InitToolTips (this client mode init is late enough).
	FS_Core_SharedInit()
	if ( FS_HasCap( FS_CAP_SURVIVAL_INVENTORY_UI ) )
		Cl_Survival_InventoryInit()

	// Stock champion gladcard path (DoChampionSquadCardsPresentation) calls
	// PickCommentaryLineFromBucket. That needs commentaryTables filled by
	// ClSurvivalCommentary_Init -- only Cl_GamemodeSurvival_Init did that before.
	ClSurvivalCommentary_Init()
	SurvivalCommentary_SetHost( eSurvivalHostType.AI )
	printt( "[FS-1V1] ClSurvivalCommentary_Init + host AI (stock champion VO)" )

	Obituary_SetAlwaysShow( true )
	Obituary_SetMaxEntries( 8 )
	CL_1v1_RegisterNetworkFunctions()

	// Precache particles
	PrecacheParticleSystem( $"P_wrth_tt_portal_screen_flash" )
	FS_1v1_ChampionFX_Precache()
	PrecacheModel( $"mdl/levels_terrain/mp_lobby/mp_character_select_geo.rmdl" )
	PrecacheModel( $"mdl/levels_terrain/mp_lobby/mp_character_select_smoke.rmdl" )

	// Register signals
	RegisterSignal( "StopCurrentEnemyThread" )
	RegisterSignal( "FS_1v1_EnemyMinimapStop" )
	RegisterSignal( "Destroy1v1SettingsHint" )
	RegisterSignal( "FS_1v1Banner" )
	RegisterSignal( "FS_CloseNewMsgBox" )
	RegisterSignal( "FS_1v1_RoundIntro" )
	RegisterSignal( "NewKillChangeRui" )
	RegisterSignal( "ChangeCameraToSelectedLocation" )
	RegisterSignal( "ChallengeStartRemoveCameras" )

	FS_Hud_EnsureSurvivalHudSignals()

	AddCinematicEventFlagChangedCallback( CE_FLAG_HIDE_MAIN_HUD_INSTANT, FS_1v1_OnCinematicHudFlagChanged )

	// Cl_Survival_AddClient builds the waiting overlay; its teardown is in Cl_GamemodeSurvival_Init, which 1v1 never runs.
	AddCallback_GameStateEnter( eGameState.Playing, WaitingForPlayersOverlay_Destroy )

	// Register button command callbacks for 1v1 modes
	if ( Flowstate_IsGame1v1Type() )
	{
		RegisterConCommandTriggeredCallback( "+scriptCommand5", FS_RestButton )
		RegisterConCommandTriggeredCallback( "+scriptCommand3", FS_SettingsButton )
		RegisterConCommandTriggeredCallback( "+scriptCommand4", FS_SpectateButton )

		// Full scoreboard = FSLeaderboard on map key (default PC: M = toggle_map).
		// TAB is inventory. Stock ToggleScoreboard blocked by FS_CAP_CUSTOM_SCOREBOARD.
		RegisterConCommandTriggeredCallback( "toggle_map", FS_1v1_ToggleFullScoreboard )
	}

	// Resolution change callback
	AddClientCallback_OnResolutionChanged( Cl_1v1_OnResolutionChanged )

	// Push local fs_1v1_* ConVars once player is live (start_in_rest / IBMM / etc).
	thread Cl_1v1_PushSettingsWhenReady()

	// Netvar change callbacks alone miss initial rest/wait stamps and races with
	// NEXT_ROUND blackout -- poll keeps rest/wait hints + VS strip alive.
	thread FS_1v1_LobbyHudWatchdog_THREAD()

	thread Cl_1v1_HudBind_THREAD()
	thread FS_1v1_RoundClock_THREAD()
	printt( "[FS-1V1] Cl_Gamemode1v1_Init complete (watchdog started)" )
}

void function Cl_1v1_HudBind_THREAD()
{
	float deadline = Time() + 20.0
	while ( Time() < deadline )
	{
		entity player = GetLocalClientPlayer()
		if ( ClGameState_GetRui() != null && IsValid( player ) && player.IsPlayer() )
			break
		WaitFrame()
	}

	entity player = GetLocalClientPlayer()
	if ( ClGameState_GetRui() == null || !IsValid( player ) || !player.IsPlayer() )
	{
		printt( "[FS-1V1] HUD bind aborted -- no gamestate RUI or player" )
		return
	}

	FS_Hud_EnsureSurvivalHudSignals()
	Survival_ClientCombatHudInit()
	var pilotRui = GetPilotRui()
	if ( pilotRui != null )
		RuiSetBool( pilotRui, "isEvolvingShield", false )
	FS_Hud_RefreshPlayerInfo()
	FS_1v1_SetCombatHudVisible( FS_1v1_ShouldShowCombatHud( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) ) )
	UpdateGamestateRuiTracking( player )
	FS_1v1_HideCustomCountdown()
	Cl_1v1_OnResolutionChanged()
	thread FS_1v1_ShowRoundIntro( GetGlobalNetTime( "FSDM_RoundIntroEndTime" ) )
	printt( "[FS-1V1] HUD sized" )
}

// One arg per call: a bar layout that lacks any one of these must still get
// the rest.
void function FS_1v1_RuiSetBoolSafe( var rui, string argName, bool value )
{
	try
	{
		RuiSetBool( rui, argName, value )
	}
	catch ( eArg )
	{
		printt( "[FS-1V1] scorebar arg '" + argName + "' unavailable" )
	}
}

void function FS_1v1_RuiSetIntSafe( var rui, string argName, int value )
{
	try
	{
		RuiSetInt( rui, argName, value )
	}
	catch ( eArg )
	{
		printt( "[FS-1V1] scorebar arg '" + argName + "' unavailable" )
	}
}

void function FS_1v1_GameModeScoreBarRules( var gamestateRui )
{
	entity player = GetLocalViewPlayer()
	if ( !IsValid( player ) || !player.IsPlayer() )
		player = GetLocalClientPlayer()
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !file.didScorebarSetup )
	{
		// Do not ScorebarInitTracking: that binds squadsRemainingCount /
		// livingPlayerCount. SetCommonScoreRUIVars turns the living-player
		// counter on at RUI creation, so turn it back off here.
		FS_1v1_RuiSetBoolSafe( gamestateRui, "shouldDisplayLivingPlayerCount", false )
		FS_1v1_RuiSetBoolSafe( gamestateRui, "hideSquadsRemaining", true )
		FS_1v1_RuiSetBoolSafe( gamestateRui, "hideWaitingForPlayers", true )

		file.didScorebarSetup = true
		printt( "[FS-1V1] FreeDM gamestate scorebar setup" )
	}

	FS_Hud_ApplyModeChrome( gamestateRui )

	// Survival's OnGameStateChanged never runs in this mode, and the
	// kill/damage widgets are gated on gamestateIsPlaying.
	FS_1v1_RuiSetBoolSafe( gamestateRui, "gamestateIsPlaying", true )
	FS_1v1_RuiSetBoolSafe( gamestateRui, "gamestateWaitingForPlayers", false )
	FS_1v1_RuiSetBoolSafe( gamestateRui, "gamestateIsEpilogue", false )
	FS_1v1_RuiSetIntSafe( gamestateRui, "gamestate", eGameState.Playing )

	// Do not RuiTrackInt these -- the tracker does not
	// follow S3 script-netvar replication, so a bound track would freeze at 0
	// and stomp RuiSetInt.
	FS_1v1_RuiSetIntSafe( gamestateRui, "killCount", FS_1v1_HudNetInt( player, "kills" ) )
	FS_1v1_RuiSetIntSafe( gamestateRui, "damageDealt", FS_1v1_HudDamage( player ) )
	FS_1v1_RuiSetIntSafe( gamestateRui, "assistCount", FS_1v1_HudNetInt( player, "assists" ) )
	FS_1v1_FeedScorebarDeaths( gamestateRui, FS_1v1_HudNetInt( player, "deaths" ) )
}

// The bar layout decides which name it exposes for deaths, and this runs every
// frame -- probe the candidates once, then feed the one that took (or none).
void function FS_1v1_FeedScorebarDeaths( var gamestateRui, int deaths )
{
	if ( file.scorebarDeathArg == "" )
		return

	if ( file.scorebarDeathArg == "?" )
	{
		array<string> candidates = [ "deathCount", "deaths", "playerDeaths" ]
		foreach ( string argName in candidates )
		{
			try
			{
				RuiSetInt( gamestateRui, argName, deaths )
				file.scorebarDeathArg = argName
				printt( "[FS-1V1] scorebar deaths arg = '" + argName + "'" )
				return
			}
			catch ( eProbe )
			{
			}
		}

		file.scorebarDeathArg = ""
		printt( "[FS-1V1] scorebar exposes no deaths arg" )
		return
	}

	try
	{
		RuiSetInt( gamestateRui, file.scorebarDeathArg, deaths )
	}
	catch ( eDeaths )
	{
	}
}

void function Cl_1v1_PushSettingsWhenReady()
{
	entity player = GetLocalClientPlayer()
	float giveUp = Time() + 30.0
	while ( Time() < giveUp )
	{
		player = GetLocalClientPlayer()
		if ( IsValid( player ) && player.IsPlayer() )
			break
		wait 0.25
	}

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	wait 0.5
	Send1v1SettingsToServer()
	printt( "[FS-1V1] client settings pushed to server" )
}

void function CL_1v1_RegisterNetworkFunctions()
{
	if ( IsLobby() )
		return

	// S21 CLIENT natives are RegisterNetVar* / *_Internal (2-arg), not the
	// 4-arg RegisterNetworkedVariableChangeCallback_* names (UI/SDK-only).
	RegisterNetVarIntChangeCallback( "FS_1v1_PlayerState", FS_1v1_PlayerStateChanged )
	RegisterNetVarTimeChangeCallback( "flowstate_DMRoundEndTime", Flowstate_RoundEndTimeChanged )
	// Round driver sets NEXT_ROUND then IN_PROGRESS; rest/wait hints must re-show on the latter.
	RegisterNetVarIntChangeCallback( "FSDM_GameState", Flowstate_FSDM_GameStateChanged )
	RegisterNetVarTimeChangeCallback( "FSDM_RoundIntroEndTime", Flowstate_RoundIntroChanged )
}

void function Gamemode1v1_ForceLegendSelector_Deprecated()
{
	printt( "[FS-1V1] legend selector is disabled" )
}

void function Gamemode1v1_OnLegendSelector_Close()
{
	// Menu already closed; S21 has no public CharacterSelect_SetMenuState
}

void function Gamemode1v1_OnSelectedLegend( ItemFlavor character )
{
	entity player = GetLocalClientPlayer()

	if( IsValid( player ) )
	{
		thread
		(
			void function() : ( player, character )
			{
				wait 0.5
				RunUIScript( "Gamemode1v1_CloseLegendMenu" )
				player.ClientCommand( "challenge legend -1 " + string( ItemFlavor_GetGUID( character ) ) )
				ScreenFade( GetLocalViewPlayer(), 255, 255, 255, 255, .1, 0, FFADE_PURGE | FFADE_INOUT | FFADE_NOT_IN_REPLAY )
			}
		)()
	}
}

void function Gamemode1v1_PlayRestFX()
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	// Client: ATTACHMENTID_INVALID is 0 (not -1). Literal -1 script-errors as "Invalid attachment id -1".
	int fxHandle = StartParticleEffectOnEntityWithPos( player, GetParticleSystemIndex( $"P_wrth_tt_portal_screen_flash" ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID, player.EyePosition(), <0,0,0> )
	if ( EffectDoesExist( fxHandle ) )
		EffectSetIsWithCockpit( fxHandle, true )

	EmitSoundOnEntity( player, "gruntcooper_wounded_loop_1p" )
}

// Safe HudElement: missing FS_* controls in HudScripted_mp.res used to throw.
var function FS_HudElementOrNull( string name )
{
	try
	{
		return HudElement( name )
	}
	catch ( errHud )
	{
		printt( "[FS-1V1] missing HUD element '" + name + "': " + errHud )
		return null
	}
}

void function FS_1v1_HideCustomCountdown()
{
	var text = FS_HudElementOrNull( HUD_COUNTDOWN_TEXT )
	if ( text != null )
		Hud_SetVisible( text, false )

	var frame = FS_HudElementOrNull( HUD_COUNTDOWN_FRAME )
	if ( frame != null )
		Hud_SetVisible( frame, false )
}

int function FS_1v1_HudNetInt( entity p, string name )
{
	if ( !IsValid( p ) )
		return 0
	try
	{
		return p.GetPlayerNetInt( name )
	}
	catch ( eNet )
	{
		return 0
	}
}

int function FS_1v1_HudDamage( entity p )
{
	int dmg = FS_1v1_HudNetInt( p, "damage" )
	if ( dmg == 0 )
		dmg = FS_1v1_HudNetInt( p, "damageDealt" )
	return dmg
}

void function FS_1v1_HudSetText( string name, string text )
{
	var el = FS_HudElementOrNull( name )
	if ( el != null )
		Hud_SetText( el, text )
}

void function FS_1v1_VsRuiSetText( string argName, string text )
{
	if ( !VSHUD_RUI_TEXT )
		return

	var el = FS_HudElementOrNull( HUD_1V1_BG )
	if ( el == null )
		return

	var rui = Hud_GetRui( el )
	if ( rui != null )
		RuiSetString( rui, argName, text )
}

void function FS_1v1_VsRuiSetImage( string argName, asset img )
{
	if ( !VSHUD_RUI_TEXT )
		return

	var el = FS_HudElementOrNull( HUD_1V1_BG )
	if ( el == null )
		return

	var rui = Hud_GetRui( el )
	if ( rui != null )
		RuiSetImage( rui, argName, img )
}

// Writes one value to both the rui and the legacy label, so VSHUD_RUI_TEXT is
// the only thing that decides which one the player sees.
void function FS_1v1_VsHudSetField( string hudName, string argName, string text )
{
	if ( VSHUD_RUI_TEXT )
		FS_1v1_VsRuiSetText( argName, text )
	else
		FS_1v1_HudSetText( hudName, text )
}

void function FS_1v1_OnCinematicHudFlagChanged( entity player )
{
	if ( player != GetLocalClientPlayer() )
		return
	FS_1v1_SetCombatHudVisible( FS_1v1_ShouldShowCombatHud( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) ) )
}

void function FS_1v1_SetRuiVisibleSafe( var rui, bool vis )
{
	if ( rui != null )
		RuiSetBool( rui, "isVisible", vis )
}

void function FS_1v1_HideCombatHudPieces()
{
	try { FS_1v1_SetRuiVisibleSafe( GetPilotRui(), false ) } catch ( ePilot ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetDpadMenuRui(), false ) } catch ( eDpad ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetWeaponRui(), false ) } catch ( eWeap ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetTacticalRui(), false ) } catch ( eTac ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetUltimateRui(), false ) } catch ( eUlt ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetCompassRui(), false ) } catch ( eCompass ) {}
	FS_1v1_SetMinimapVisible( false )
	FS_1v1_SetEnemyMinimapActive( false )
}

void function FS_1v1_SetMinimapVisible( bool show )
{
	if ( show )
	{
		file.minimapHeldHidden = false
		// EnableDraw is 1:1 with DisableDraw; leftover stack keeps the corner map off for the whole fight.
		Minimap_ClearDisableDrawStack()
		return
	}

	if ( file.minimapHeldHidden )
		return
	file.minimapHeldHidden = true
	Minimap_DisableDraw()
}

void function FS_1v1_HideFfaPlayHud()
{
	FS_1v1_SuppressAllHud()
}

void function FS_1v1_RestoreFfaPlayHud()
{
	// FFA has no 1v1 PlayerState. SetCombatHudVisible(true) starts the duel
	// opponent blip and hides compass; only unwind the champion suppress here.
	file.hudSuppressed = false
	entity lp = GetLocalClientPlayer()
	if ( IsValid( lp ) )
		ShowScriptHUD( lp )
	SetAllHudVisExceptMinimap( true )
	try { FS_1v1_SetRuiVisibleSafe( GetCompassRui(), true ) } catch ( eCompass ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetPilotRui(), true ) } catch ( ePilot ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetDpadMenuRui(), true ) } catch ( eDpad ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetWeaponRui(), true ) } catch ( eWeap ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetTacticalRui(), true ) } catch ( eTac ) {}
	try { FS_1v1_SetRuiVisibleSafe( GetUltimateRui(), true ) } catch ( eUlt ) {}
	FS_1v1_SetMinimapVisible( true )
	FS_Hud_SetModeChromeVisible( true )
	FS_1v1_SetLeaderboardTransitionLock( false )
	var rui = ClGameState_GetRui()
	if ( rui != null )
		FS_1v1_RuiSetBoolSafe( rui, "isVisible", true )
}

void function FS_1v1_SetEnemyMinimapActive( bool active )
{
	if ( file.enemyMinimapActive == active )
		return

	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		Signal( player, "FS_1v1_EnemyMinimapStop" )

	file.enemyMinimapActive = active
	FS_1v1_DestroyEnemyMinimapRui()

	if ( !active || !IsValid( player ) )
		return

	thread FS_1v1_EnemyMinimapThink( player )
}

void function FS_1v1_DestroyEnemyMinimapRui()
{
	var rui = file.enemyMinimapRui
	file.enemyMinimapRui = null
	file.enemyMinimapTracked = null
	if ( rui != null )
		Minimap_CommonCleanup( rui )
}

entity function FS_1v1_FindFightOpponent( entity localPlayer )
{
	if ( !IsValid( localPlayer ) )
		return null

	foreach ( entity p in GetPlayerArray() )
	{
		if ( !IsValid( p ) || p == localPlayer || p.IsObserver() )
			continue
		if ( !p.DoesShareRealms( localPlayer ) )
			continue
		return p
	}

	return null
}

var function FS_1v1_CreateEnemyMinimapRui( entity enemy )
{
	entity viewPlayer = GetLocalViewPlayer()
	if ( !IsValid( viewPlayer ) || !IsValid( enemy ) )
		return null

	var rui = Minimap_CommonAdd( MINIMAP_OBJECT_RUI, MINIMAP_Z_BASE + 20, enemy.GetOrigin(), enemy.GetAngles() )

	RuiTrackInt( rui, "objectFlags", viewPlayer, RUI_TRACK_MINIMAP_FLAGS )
	RuiTrackInt( rui, "customState", viewPlayer, RUI_TRACK_MINIMAP_CUSTOM_STATE )
	RuiSetFloat2( rui, "iconScale", <1.0, 1.0, 0> )
	RuiSetBool( rui, "alwaysShowOnMinimap", true )
	RuiSetBool( rui, "useTeamColor", false )
	RuiSetFloat3( rui, "iconColor", GetKeyColor( COLORID_MINIMAP_ENEMY_REF ) * ( 1.0 / 255.0 ) )
	RuiSetImage( rui, "defaultIcon", $"rui/hud/minimap/compass_icon_player" )
	RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/minimap/compass_icon_player_clamped" )
	RuiTrackFloat3( rui, "objectPos", enemy, RUI_TRACK_ABSORIGIN_FOLLOW )
	RuiTrackFloat3( rui, "objectAngles", enemy, RUI_TRACK_CAMANGLES_FOLLOW )

	return rui
}

void function FS_1v1_EnemyMinimapThink( entity player )
{
	EndSignal( player, "FS_1v1_EnemyMinimapStop" )
	EndSignal( player, "OnDestroy" )

	OnThreadEnd(
		function() : ()
		{
			FS_1v1_DestroyEnemyMinimapRui()
		}
	)

	while ( true )
	{
		entity opponent = FS_1v1_FindFightOpponent( player )
		if ( !IsValid( opponent ) || !IsAlive( opponent ) )
		{
			FS_1v1_DestroyEnemyMinimapRui()
			wait 0.1
			continue
		}

		if ( file.enemyMinimapRui == null || file.enemyMinimapTracked != opponent )
		{
			FS_1v1_DestroyEnemyMinimapRui()
			var rui = FS_1v1_CreateEnemyMinimapRui( opponent )
			if ( rui == null )
			{
				wait 0.1
				continue
			}
			file.enemyMinimapRui = rui
			file.enemyMinimapTracked = opponent
		}

		wait 0.1
	}
}

void function FS_1v1_SetCombatHudVisible( bool show )
{
	entity lp = GetLocalClientPlayer()
	if ( !IsValid( lp ) )
		return

	if ( FS_1v1_FullscreenPresentationActive() )
	{
		FS_1v1_SuppressAllHud()
		return
	}

	// SuppressAllHud zeroed every permanent-hud isVisible; ShowScriptHUD does
	// not restore those, so the toggle has to be undone explicitly.
	if ( file.hudSuppressed )
	{
		file.hudSuppressed = false
		SetAllHudVisExceptMinimap( true )
	}

	if ( show )
	{
		ShowScriptHUD( lp )
		try { FS_1v1_SetRuiVisibleSafe( GetCompassRui(), false ) } catch ( eCompassShow ) {}
		FS_1v1_SetMinimapVisible( true )
		FS_1v1_SetEnemyMinimapActive( true )
		FS_1v1_ApplyRoundHudVisibility()
		FS_1v1_ApplyAbilityHudVisibility()
		if ( !file.combatHudPainted )
		{
			file.combatHudPainted = true
			FS_Hud_RefreshPlayerInfo()
		}
		return
	}

	file.combatHudPainted = false

	// Rest/wait keeps the scorebar: HideScriptHUD would take it and the
	// netgraph nested on it down with the combat pieces.
	FS_1v1_HideCombatHudPieces()
	FS_1v1_ApplyRoundHudVisibility()
	FS_1v1_ApplyAbilityHudVisibility()
}

// Empty tactical and ultimate slots when the mode grants no abilities.
// HUD_TogglePermanentHudsVisibility turns both back on with the rest of the
// combat HUD, so hiding them once at init does not hold.
void function FS_1v1_ApplyAbilityHudVisibility()
{
	if ( GetCurrentPlaylistVarBool( "freedm_ffa_active", false ) )
		return
	if ( GetCurrentPlaylistVarBool( "give_legend_tactical", false ) )
		return

	try
	{
		var tactical = GetTacticalRui()
		if ( tactical != null )
			RuiSetBool( tactical, "isVisible", false )

		var ultimate = GetUltimateRui()
		if ( ultimate != null )
			RuiSetBool( ultimate, "isVisible", false )
	}
	catch ( eAbilityHud )
	{
	}
}

bool function FS_1v1_RoundClockIsActive()
{
	return GetGlobalNetInt( "FSDM_GameState" ) == eTDMState.IN_PROGRESS
		&& Flowstate_GetRoundEndTimeFromNet() > Time()
}

// Champion presentation owns the whole screen: nothing of ours draws over it.
bool function FS_1v1_ChampionIsShowing()
{
	if ( FS_1v1_ChampionRoomIsRunning() )
		return true
	return Time() < GetGlobalNetTime( "championDisplayEndTime" )
}

// Champion podium and the round-end leaderboard are both fullscreen takeovers.
bool function FS_1v1_FullscreenPresentationActive()
{
	return FS_1v1_ChampionIsShowing() || file.roundEndScoreboard
}

bool function FS_1v1_LeaderboardLocked()
{
	if ( FS_1v1_FullscreenPresentationActive() )
		return true
	return GetGlobalNetInt( "FSDM_GameState" ) == eTDMState.NEXT_ROUND_NOW
}

void function FS_1v1_SetLeaderboardTransitionLock( bool locked )
{
	if ( file.leaderboardTransitionLock == locked )
		return
	file.leaderboardTransitionLock = locked
	RunUIScript( "Leaderboard_SetTransitionLock", locked ? 1 : 0 )
}

void function FS_1v1_ForceCloseVoluntaryLeaderboard()
{
	if ( file.roundEndScoreboard )
		return
	if ( !file.fullScoreboardOpen )
		return

	file.fullScoreboardOpen = false
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		player.ClientCommand( "CC_1v1_ScoreboardOpen 0" )
	RunUIScript( "CloseMatchLeaderboard" )
	printt( "[FS-1V1] FSLeaderboard force-closed (transition)" )
}

void function FS_1v1_BeginLeaderboardTransition()
{
	FS_1v1_SetLeaderboardTransitionLock( true )
	FS_1v1_ForceCloseVoluntaryLeaderboard()
}

void function FS_1v1_EndLeaderboardTransition()
{
	if ( FS_1v1_FullscreenPresentationActive() )
		return
	FS_1v1_SetLeaderboardTransitionLock( false )
}

void function FS_1v1_SyncLeaderboardTransitionLock()
{
	if ( FS_1v1_LeaderboardLocked() )
		FS_1v1_BeginLeaderboardTransition()
	else
		FS_1v1_EndLeaderboardTransition()
}

// Idempotent: the engine re-shows permanent huds from its own flag update, so
// the watchdog re-applies this every tick while a presentation is up.
void function FS_1v1_SuppressAllHud()
{
	file.hudSuppressed = true

	if ( file.vsHudShown )
		FS_1v1_ToggleUIVisibility( false, null )

	FS_1v1_HideCustomCountdown()
	FS_1v1_HideCombatHudPieces()
	FS_1v1_UpdateLobbyInfo( false )
	FS_Hud_SetModeChromeVisible( false )
	SetAllHudVisExceptMinimap( false )

	var rui = ClGameState_GetRui()
	if ( rui != null )
		FS_1v1_RuiSetBoolSafe( rui, "isVisible", false )
}

void function FS_1v1_ApplyRoundHudVisibility()
{
	var rui = ClGameState_GetRui()
	if ( rui != null )
		FS_1v1_RuiSetBoolSafe( rui, "isVisible", !FS_1v1_FullscreenPresentationActive() )

	FS_Hud_SetModeChromeVisible( !FS_1v1_FullscreenPresentationActive() )
	FS_1v1_UpdateLobbyInfo( FS_1v1_ShouldShowLobbyInfo( file.lastLocalPlayerState ) )
	FS_1v1_HideCustomCountdown()
}

void function FS_1v1_PlayerStateChanged( entity player, int newValue )
{
	printt( "[FS-1V1] PlayerStateChanged new=" + string( newValue ) + " local=" + string( player == GetLocalClientPlayer() ) )

	int oldValue = file.lastLocalPlayerState

	if ( player != GetLocalClientPlayer() )
	{
		newValue = e1v1State.SPECTATING
	}
	else
	{
		file.lastLocalPlayerState = newValue
		FS_1v1_SetCombatHudVisible( FS_1v1_ShouldShowCombatHud( newValue ) )
		FS_1v1_UpdateLobbyInfo( FS_1v1_ShouldShowLobbyInfo( newValue ) )
	}

	switch( newValue )
	{
		case e1v1State.INVALID:
		case e1v1State.CHARSELECT:
			break

		case e1v1State.MATCH_START:
			FS_1v1_HideCustomCountdown()
			break

		case e1v1State.SPECTATING:
			FS_1v1_HideCustomCountdown()
			FS_1v1_DisplayHints( e1v1State.SPECTATING )
			break

		case e1v1State.RESTING:
			EmitSoundOnEntity( GetLocalClientPlayer(), "UI_InGame_FD_UnReadyUp_1p" )
			Gamemode1v1_PlayRestFX()
			FS_1v1_HideCustomCountdown()
			FS_1v1_DisplayHints( e1v1State.RESTING )
			break

		case e1v1State.WAITING:
			if( oldValue == e1v1State.RESTING )
			{
				EmitSoundOnEntity( GetLocalClientPlayer(), "UI_InGame_FD_ReadyUp_1p" )
				Gamemode1v1_PlayRestFX()
			}
			FS_1v1_HideCustomCountdown()
			RunUIScript( "FS_1v1_SettingsMenu_Close" )
			FS_1v1_DisplayHints( e1v1State.WAITING )
			break

		case e1v1State.SEQUENCE:
		case e1v1State.IN_MATCH:
			try { RunUIScript( "FS_1v1_SettingsMenu_Close" ) } catch ( eClose ) {}
			Signal( player, "Destroy1v1SettingsHint" )
			if ( IsValid( GetLocalClientPlayer() ) )
				GetLocalClientPlayer().ClearMenuCameraEntity()
			FS_1v1_HideCustomCountdown()
			break

		default:
			try { RunUIScript( "FS_1v1_SettingsMenu_Close" ) } catch ( eClose2 ) {}
			Signal( player, "Destroy1v1SettingsHint" )
			FS_1v1_HideCustomCountdown()
			break
	}
}

void function FS_1v1_ToggleUIVisibility( bool toggle, entity newEnt )
{
	entity player = GetLocalClientPlayer()

	Signal( player, "StopCurrentEnemyThread" )

	if( !file.show1v1Scoreboard )
		toggle = false

	file.vsHudShown = toggle
	file.vsHudEnemy = null

	bool labelsVisible = toggle && !VSHUD_RUI_TEXT

	// Missing HudScripted panels must not take down the client mid-match.
	try
	{
		Hud_SetVisible( HudElement( HUD_1V1_BG ), toggle )
		Hud_SetVisible( HudElement( HUD_1V1_ENEMY_NAME ), labelsVisible )
	}
	catch ( eHud )
	{
		printt( "[FS-1V1] 1v1 HUD panels missing: " + eHud )
		return
	}

	string enemyName = file.vsHudEnemyName
	if ( enemyName != "" && !VSHUD_RUI_TEXT )
	{
		Hud_SetText( HudElement( HUD_1V1_ENEMY_NAME ), enemyName )
		thread function() : ( player, toggle )
		{
			Hud_ReturnToBasePos( HudElement( HUD_1V1_ENEMY_NAME ) )
			Hud_SetSize( HudElement( HUD_1V1_ENEMY_NAME ), 0, 0 )
			Hud_ScaleOverTime( HudElement( HUD_1V1_ENEMY_NAME ), 1.3, 1.3, 0.05, INTERPOLATOR_ACCEL )
			wait 0.05
			Hud_ScaleOverTime( HudElement( HUD_1V1_ENEMY_NAME ), 1, 1, 0.1, INTERPOLATOR_SIMPLESPLINE )
		}()
	}

	Hud_SetVisible( HudElement( HUD_1V1_ENEMY_KILLS ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_ENEMY_DEATHS ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_ENEMY_DAMAGE ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_ENEMY_LATENCY ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_ENEMY_POSITION ), labelsVisible )

	Hud_SetVisible( HudElement( HUD_1V1_NAME ), labelsVisible )
	Hud_SetText( HudElement( HUD_1V1_NAME ), GetLocalClientPlayer().GetPlayerName() )

	Hud_SetVisible( HudElement( HUD_1V1_KILLS ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_DEATHS ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_DAMAGE ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_LATENCY ), labelsVisible )
	Hud_SetVisible( HudElement( HUD_1V1_POSITION ), labelsVisible )

	RuiSetImage( Hud_GetRui( HudElement( HUD_1V1_BG ) ), "basicImage", $"rui/flowstate_custom/1v1_bg" )

	if ( VSHUD_RUI_TEXT )
	{
		FS_1v1_VsRuiSetText( "playerName", GetLocalClientPlayer().GetPlayerName() )
		FS_1v1_VsRuiSetText( "enemyName", file.vsHudEnemyName )
	}

	if( !toggle )
		return

	thread FS_1v1_StartUpdatingValues()
}

void function FS_1v1_StartUpdatingValues()
{
	entity player = GetLocalClientPlayer()

	Signal( player, "StopCurrentEnemyThread" )
	EndSignal( player, "StopCurrentEnemyThread" )

	while( file.show1v1Scoreboard && file.vsHudRemoteActive && IsValid( player ) )
	{
		FS_1v1_VsHudSetField( HUD_1V1_ENEMY_NAME, "enemyName", file.vsHudEnemyName )
		FS_1v1_VsHudSetField( HUD_1V1_ENEMY_KILLS, "enemyKills", string( file.vsHudEnemyKills ) )
		FS_1v1_VsHudSetField( HUD_1V1_ENEMY_DEATHS, "enemyDeaths", string( file.vsHudEnemyDeaths ) )
		FS_1v1_VsHudSetField( HUD_1V1_ENEMY_DAMAGE, "enemyDamage", string( file.vsHudEnemyDamage ) )
		FS_1v1_VsHudSetField( HUD_1V1_ENEMY_LATENCY, "enemyLatency", string( file.vsHudEnemyLatency ) )
		FS_1v1_VsHudSetField( HUD_1V1_ENEMY_POSITION, "enemyPosition", string( file.vsHudEnemyRank ) )

		FS_1v1_VsHudSetField( HUD_1V1_NAME, "playerName", player.GetPlayerName() )
		FS_1v1_VsHudSetField( HUD_1V1_KILLS, "playerKills", string( FS_1v1_HudNetInt( player, "kills" ) ) )
		FS_1v1_VsHudSetField( HUD_1V1_DEATHS, "playerDeaths", string( FS_1v1_HudNetInt( player, "deaths" ) ) )
		FS_1v1_VsHudSetField( HUD_1V1_DAMAGE, "playerDamage", string( FS_1v1_HudDamage( player ) ) )
		FS_1v1_VsHudSetField( HUD_1V1_LATENCY, "playerLatency", string( FS_1v1_HudNetInt( player, "latency" ) ) )
		FS_1v1_VsHudSetField( HUD_1V1_POSITION, "playerPosition", string( file.vsHudLocalRank ) )

		FS_1v1_VsRuiSetImage( "playerInputIcon", FS_1v1_InputIcon( player.GetPlayerNetBool( "FS_PlayerIsMnk" ) ? 0 : 1 ) )

		int enemyInput = player.GetPlayerNetInt( "FS_1v1_EnemyInput" )
		if ( enemyInput != -1 )
			FS_1v1_VsRuiSetImage( "enemyInputIcon", FS_1v1_InputIcon( enemyInput ) )

		// 2 is "could not lock", which only happens on a cross-input pair -- the
		// same thing ANY INPUT means to a player, so it reads the same.
		int lockState = player.GetPlayerNetInt( "FS_1v1_LockState" )
		FS_1v1_VsRuiSetImage( "lockIcon", lockState == 0 ? $"rui/menu/buttons/large_lock" : $"rui/menu/buttons/unlocked" )
		FS_1v1_VsRuiSetText( "lockLocked", lockState == 0 ? "LOCKED" : "" )
		FS_1v1_VsRuiSetText( "lockAny", lockState == 1 || lockState == 2 ? "ANY INPUT" : "" )
		wait 0.1
	}
}

asset function FS_1v1_InputIcon( int input )
{
	return input == 1 ? $"rui/menu/crossplatform/controller" : $"rui/flowstate_custom/input_mouse"
}

void function SetShow1v1Scoreboard( string show )
{
	bool bShow = show == "0" ? false : true
	file.show1v1Scoreboard = bShow
}

void function Toggle1v1Scoreboard()
{
	entity player = GetLocalClientPlayer()

	if( file.show1v1Scoreboard )
	{
		file.show1v1Scoreboard = false
		Signal( player, "StopCurrentEnemyThread" )
		FS_1v1_ToggleUIVisibility( false, null )
	}
	else
	{
		if( GetGlobalNetInt( "FSDM_GameState" ) == eTDMState.IN_PROGRESS && file.vsHudRemoteActive )
		{
			file.show1v1Scoreboard = true
			FS_1v1_ToggleUIVisibility( true, null )
		}
	}
}

void function ForceHide1v1Scoreboard()
{
	entity player = GetLocalClientPlayer()
	Signal( player, "StopCurrentEnemyThread" )
	FS_1v1_ToggleUIVisibility( false, null )
}

void function ForceShow1v1Scoreboard()
{
	entity player = GetLocalClientPlayer()

	if( GetGlobalNetInt( "FSDM_GameState" ) == eTDMState.IN_PROGRESS && file.vsHudRemoteActive && file.show1v1Scoreboard )
	{
		FS_1v1_ToggleUIVisibility( true, null )
	}
}

void function Cl_1v1_OnResolutionChanged()
{
	FS_1v1_HideCustomCountdown()
	FS_1v1_DestroyLobbyInfo()

	file.hintState = e1v1State.INVALID

	if( IsValid( GetLocalViewPlayer() ) )
		FS_1v1_PlayerStateChanged( GetLocalViewPlayer(), GetLocalViewPlayer().GetPlayerNetInt( "FS_1v1_PlayerState" ) )

	entity player = GetLocalClientPlayer()

	if( GetGlobalNetInt( "FSDM_GameState" ) == eTDMState.IN_PROGRESS && file.vsHudRemoteActive )
	{
		FS_1v1_ToggleUIVisibility( true, null )
	}

	// Coaching recordings UI not ported on S21.

}

void function Flowstate_RoundEndTimeChanged( entity player, float new )
{
	// Advisory only. FS_1v1_RoundClock_THREAD reconciles against the netvars
	// every tick, because this callback does not fire for a mid-join and the
	// round can already be running when client scripts bind.
	_1v1_SetFreeDMClock( new )
}

float function Flowstate_GetRoundEndTimeFromNet()
{
	return GetGlobalNetTime( "flowstate_DMRoundEndTime" )
}

float function Flowstate_GetRoundStartTimeFromNet()
{
	return GetGlobalNetTime( "flowstate_DMStartTime" )
}

void function FS_1v1_RuiSetGameTimeIfPresent( var rui, string argName, float value )
{
	try
	{
		if ( RuiHasGameTimeArg( rui, argName ) )
			RuiSetGameTime( rui, argName, value )
	}
	catch ( eArg )
	{
	}
}

// Drive the gamestate RUI clock from the round times; endTime <= 0 blanks it.
void function _1v1_SetFreeDMClock( float endTime )
{
	var rui = ClGameState_GetRui()
	if ( rui == null )
		return

	if ( endTime > 0 )
	{
		float startTime = Flowstate_GetRoundStartTimeFromNet()
		if ( startTime <= 0 )
			startTime = Time()
		FS_1v1_RuiSetGameTimeIfPresent( rui, "matchStartTime", startTime )
		FS_1v1_RuiSetGameTimeIfPresent( rui, "matchEndTime", endTime )
		FS_1v1_RuiSetGameTimeIfPresent( rui, "endTime", endTime )
		FS_1v1_RuiSetGameTimeIfPresent( rui, "roundEndTime", endTime )
	}
	else
	{
		FS_1v1_RuiSetGameTimeIfPresent( rui, "matchStartTime", RUI_BADGAMETIME )
		FS_1v1_RuiSetGameTimeIfPresent( rui, "matchEndTime", RUI_BADGAMETIME )
		FS_1v1_RuiSetGameTimeIfPresent( rui, "endTime", RUI_BADGAMETIME )
		FS_1v1_RuiSetGameTimeIfPresent( rui, "roundEndTime", RUI_BADGAMETIME )
	}
}

void function Flowstate_RoundIntroChanged( entity player, float new )
{
	// Advisory. FS_1v1_RoundClock_THREAD polls the same netvar, because this
	// callback does not fire when the round starts while the client is bound.
	thread FS_1v1_ShowRoundIntro( new )
}

void function FS_1v1_DestroyRoundIntroRui()
{
	if ( file.roundIntroRui == null )
		return

	RuiDestroyIfAlive( file.roundIntroRui )
	file.roundIntroRui = null
}

// Retail TDM lead-in. The RUI plays its own shrink-out past timerEndTime, so it
// is kept alive for half a shrink after the countdown lands.
void function FS_1v1_ShowRoundIntro( float introEndTime )
{
	entity lp = GetLocalClientPlayer()
	if ( !IsValid( lp ) )
		return

	Signal( lp, "FS_1v1_RoundIntro" )
	EndSignal( lp, "FS_1v1_RoundIntro" )
	EndSignal( lp, "OnDestroy" )

	FS_1v1_DestroyRoundIntroRui()

	if ( introEndTime <= 0 || introEndTime <= Time() )
		return

	var introRui = null
	try
	{
		introRui = CreateFullscreenPostFXRui( FS_1V1_COUNTDOWN_RUI )
		RuiSetGameTime( introRui, "timerStartTime", Time() )
		RuiSetGameTime( introRui, "timerEndTime", introEndTime )
		RuiSetGameTime( introRui, "shrinkEndTime", introEndTime + FS_1V1_COUNTDOWN_SHRINK )
		RuiSetInt( introRui, "currentRound", GetGlobalNetInt( "FSDM_CurrentRound" ) )
		RuiSetBool( introRui, "roundsEnabled", true )
	}
	catch ( eIntro )
	{
		printt( "[FS-1V1] round intro RUI failed: " + eIntro )
		RuiDestroyIfAlive( introRui )
		return
	}

	file.roundIntroRui = introRui

	// Destroy the handle this thread owns, not whatever the next round installed.
	OnThreadEnd(
		function() : ( introRui )
		{
			RuiDestroyIfAlive( introRui )
			if ( file.roundIntroRui == introRui )
				file.roundIntroRui = null

			try { RunUIScript( "SetRespawnOverlayTime", RUI_BADGAMETIME, RUI_BADGAMETIME ) }
			catch ( eClearOverlay ) {}
		}
	)

	printt( "[FS-1V1] round intro round=" + string( GetGlobalNetInt( "FSDM_CurrentRound" ) )
		+ " remain=" + string( introEndTime - Time() ) )

	// Literal strings: #ROUND_NUM_IN / #MATCH_STARTED are retail TDM tokens this
	// build does not carry, and a missing token renders as the raw token.
	try
	{
		RunUIScript( "SetRespawnOverlayTime", Time(), introEndTime )
		RunUIScript( "SetRespawnOverlayString",
			"ROUND " + string( GetGlobalNetInt( "FSDM_CurrentRound" ) ) + " STARTING IN" )
		RunUIScript( "SetRespawnOverlayIdleString", "ROUND STARTED" )
	}
	catch ( eOverlay )
	{
		printt( "[FS-1V1] round overlay failed: " + eOverlay )
	}

	thread FS_1v1_RoundIntroSound_THREAD( introEndTime )

	wait introEndTime - Time() + FS_1V1_COUNTDOWN_SHRINK / 2
}

void function FS_1v1_RoundIntroSound_THREAD( float introEndTime )
{
	entity lp = GetLocalClientPlayer()
	if ( !IsValid( lp ) )
		return

	EndSignal( lp, "FS_1v1_RoundIntro" )
	EndSignal( lp, "OnDestroy" )

	// One tick per second over the last three seconds, then the round-start stinger.
	float lead = introEndTime - Time() - 3.0
	if ( lead > 0 )
		wait lead

	while ( Time() < introEndTime )
	{
		EmitSoundOnEntity( lp, FS_1V1_COUNTDOWN_SOUND )
		wait 1.0
	}

	EmitSoundOnEntity( lp, FS_1V1_ROUND_START_SOUND )
}

void function FS_1v1_RoundClock_THREAD()
{
	entity lp = GetLocalClientPlayer()
	float deadline = Time() + 20.0
	while ( !IsValid( lp ) && Time() < deadline )
	{
		WaitFrame()
		lp = GetLocalClientPlayer()
	}

	if ( !IsValid( lp ) )
	{
		printt( "[FS-1V1] round clock aborted -- no local player" )
		return
	}

	EndSignal( lp, "OnDestroy" )

	bool wasActive = false
	int lastRemain = -1
	float lastIntroEnd = -1.0

	while ( true )
	{
		WaitFrame()

		float introEnd = GetGlobalNetTime( "FSDM_RoundIntroEndTime" )
		if ( introEnd != lastIntroEnd )
		{
			lastIntroEnd = introEnd
			if ( introEnd > Time() )
				thread FS_1v1_ShowRoundIntro( introEnd )
		}

		float endTime = Flowstate_GetRoundEndTimeFromNet()

		if ( !FS_1v1_RoundClockIsActive() )
		{
			if ( wasActive )
			{
				_1v1_SetFreeDMClock( -1 )
				wasActive = false
				lastRemain = -1
				printt( "[FS-1V1] round clock off" )
			}
			continue
		}

		if ( !wasActive )
		{
			_1v1_SetFreeDMClock( endTime )
			wasActive = true
			printt( "[FS-1V1] round clock on remain=" + string( endTime - Time() ) )
		}

		int remain = int( endTime - Time() )
		if ( remain < 0 )
			remain = 0

		if ( remain != lastRemain )
		{
			lastRemain = remain
			_1v1_SetFreeDMClock( endTime )

			var gamestateRui = ClGameState_GetRui()
			if ( gamestateRui != null && !FS_1v1_FullscreenPresentationActive() )
				RuiSetBool( gamestateRui, "isVisible", true )

			FS_1v1_ApplyAbilityHudVisibility()
		}
	}
}

void function Send1v1SettingsToServer()
{
	entity player = GetLocalClientPlayer()

	player.ClientCommand( "CC_1v1_StartInRest " + GetConVarInt( "fs_1v1_startinrest" ).tostring() )
	player.ClientCommand( "CC_1v1_IBMM " + GetConVarInt( "fs_1v1_ibmm" ).tostring() )
	player.ClientCommand( "CC_1v1_AcceptChallenges " + GetConVarInt( "fs_1v1_acceptchallenges" ).tostring() )
	player.ClientCommand( "CC_1v1_ShowInputBanner " + GetConVarInt( "fs_1v1_showinputbanner" ).tostring() )
	player.ClientCommand( "CC_1v1_ShowVsUI " + GetConVarInt( "fs_1v1_showvsui" ).tostring() )
	SetShow1v1Scoreboard( GetConVarInt( "fs_1v1_showvsui" ).tostring() )

	player.ClientCommand( "CC_1v1_CamoColor " + GetConVarInt( "fs_1v1_camo" ).tostring() )

	player.ClientCommand( "CC_1v1_MaxEnemyLatency " + GetConVarInt( "fs_1v1_maxenemylatency" ).tostring() )

	// Both CCs write IBMM_grace_period and this one lands last, so the wait time
	// has to carry the enable state or IBMM comes back on at the stock defaults.
	int waitTime = GetConVarInt( "fs_1v1_ibmm" ) > 0 ? GetConVarInt( "fs_1v1_maxibmmtime" ) : 0
	player.ClientCommand( "CC_1v1_MaxIBMMTime " + waitTime.tostring() )
}

void function FS_RestButton( entity player )
{
	if ( player != GetLocalViewPlayer() )
		return

	if ( player != GetLocalClientPlayer() )
		return

	if( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) != e1v1State.WAITING && player.GetPlayerNetInt( "FS_1v1_PlayerState" ) != e1v1State.RESTING )
		return

	// R5V TryPingBlockingFunction is not on S21 CLIENT; dual-bind guard omitted.

	RunUIScript( "FS_1v1_SettingsMenu_Close" )
	player.ClientCommand( "rest" )
	return
}

void function FS_SettingsButton( entity player )
{
	if ( player != GetLocalViewPlayer() )
		return

	if ( player != GetLocalClientPlayer() )
		return

	if( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) != e1v1State.RESTING )
		return

	RunUIScript( "FS_1v1_SettingsMenu_Open" )
	Signal( player, "Destroy1v1SettingsHint" )
}

void function FS_SpectateButton( entity player )
{
	if ( player != GetLocalViewPlayer() )
		return

	if ( player != GetLocalClientPlayer() )
		return

	if( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) != e1v1State.RESTING )
		return

	RunUIScript( "FS_1v1_SettingsMenu_Close" )
	player.ClientCommand( "spectate_1v1" )
}

// Rest/wait/spectate hints only after champion, once the round is live.
bool function FS_1v1_CanShowLobbyHints()
{
	if ( GetGlobalNetInt( "FSDM_GameState" ) != eTDMState.IN_PROGRESS )
		return false
	if ( FS_1v1_FullscreenPresentationActive() )
		return false
	return true
}

// Poll rest/wait hints + VS strip. Netvar callbacks miss first stamp and races.
void function FS_1v1_LobbyHudWatchdog_THREAD()
{
	int lastHintState = e1v1State.INVALID

	for ( ; ; )
	{
		wait 0.5

		entity player = GetLocalClientPlayer()
		if ( !IsValid( player ) || !player.IsPlayer() )
			continue

		string pl = GetCurrentPlaylistName()
		if ( pl != "fs_1v1" && pl != "fs_lgduels_1v1" && pl != "fs_vamp_1v1" )
			continue

		FS_1v1_SyncLeaderboardTransitionLock()

		int st = player.GetPlayerNetInt( "FS_1v1_PlayerState" )
		FS_1v1_SetCombatHudVisible( FS_1v1_ShouldShowCombatHud( st ) )
		FS_1v1_UpdateLobbyInfo( FS_1v1_ShouldShowLobbyInfo( st ) )
		bool wantHints = FS_1v1_CanShowLobbyHints()
			&& ( st == e1v1State.RESTING || st == e1v1State.WAITING || st == e1v1State.SPECTATING )

		if ( wantHints )
		{
			if ( file.activeQuickHint2 == null || lastHintState != st )
			{
				lastHintState = st
				printt( "[FS-1V1] watchdog show hints state=" + string( st )
					+ " FSDM_GameState=" + string( GetGlobalNetInt( "FSDM_GameState" ) ) )
				FS_1v1_DisplayHints( st )
			}
		}
		else if ( lastHintState != e1v1State.INVALID || file.activeQuickHint2 != null )
		{
			lastHintState = e1v1State.INVALID
			Signal( player, "Destroy1v1SettingsHint" )
		}

		// VS duel strip (HudScripted FS_1v1_UI_*). Do not rebuild every tick --
		// that killed the kills/damage update thread before numbers could stick.
		bool wantVs = file.show1v1Scoreboard && file.vsHudRemoteActive
			&& !FS_1v1_FullscreenPresentationActive()
			&& ( st == e1v1State.IN_MATCH || st == e1v1State.SEQUENCE )
		if ( wantVs )
		{
			if ( !file.vsHudShown )
				FS_1v1_ToggleUIVisibility( true, null )
		}
		else if ( file.vsHudShown )
		{
			FS_1v1_ToggleUIVisibility( false, null )
		}
	}
}

// When round driver leaves NEXT_ROUND -> IN_PROGRESS, re-fire rest/wait hints
// (PlayerState often already set while netvar was still NEXT_ROUND, so DisplayHints no-oped once).
void function Flowstate_FSDM_GameStateChanged( entity player, int newValue )
{
	entity lp = GetLocalClientPlayer()
	if ( !IsValid( lp ) )
		return

	if ( newValue == eTDMState.NEXT_ROUND_NOW )
	{
		try { RunUIScript( "FS_1v1_SettingsMenu_Close" ) } catch ( eCloseTimer ) {}
		Signal( lp, "Destroy1v1SettingsHint" )
		FS_1v1_BeginLeaderboardTransition()
		return
	}

	if ( newValue != eTDMState.IN_PROGRESS )
		return

	FS_1v1_EndLeaderboardTransition()

	int st = lp.GetPlayerNetInt( "FS_1v1_PlayerState" )
	if ( st == e1v1State.RESTING || st == e1v1State.WAITING || st == e1v1State.SPECTATING )
	{
		printt( "[FS-1V1] FSDM_GameState IN_PROGRESS -- re-show lobby hints state=" + string( st ) )
		FS_1v1_DisplayHints( st )
	}
}

void function FS_1v1_DisplayHints( int state )
{
	// Round blackout only. Was: != IN_PROGRESS, which also blocked default -1 and
	// any frame where players entered rest/wait before the first SetTdmStateToInProgress.
	if ( !FS_1v1_CanShowLobbyHints() )
	{
		printt( "[FS-1V1] DisplayHints skip (FSDM_GameState=" + string( GetGlobalNetInt( "FSDM_GameState" ) ) + ")" )
		return
	}

	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	int actualState = state
	if ( state == -1 )
		actualState = player.GetPlayerNetInt( "FS_1v1_PlayerState" )

	if ( file.hintState == actualState )
		return
	file.hintState = actualState

	thread function() : ( actualState )
	{
		entity player = GetLocalClientPlayer()

		if ( !IsValid( player ) )
			return

		string text = ""

		switch( actualState )
		{
			case e1v1State.RESTING:
				text = "%scriptCommand5% STOP RESTING\n%scriptCommand3% SETTINGS\n%scriptCommand4% SPECTATE\n%toggle_map% SCOREBOARD"
				break

			case e1v1State.WAITING:
				text = "%scriptCommand5% REST\n%toggle_map% SCOREBOARD"
				break

			case e1v1State.SPECTATING:
				text = "%jump% STOP SPECTATING"
				break

			default:
				text = "BUG THIS"
				break
		}

		player.EndSignal( "OnDestroy" )
		player.Signal( "Destroy1v1SettingsHint" )
		player.EndSignal( "Destroy1v1SettingsHint" )

		Gamemode1v1_PermaHint( text )
		printt( "[FS-1V1] DisplayHints show state=" + string( actualState ) )

		OnThreadEnd(
			function() : ( actualState )
			{
				Gamemode1v1_DestroyPermaHint()
				if ( file.hintState == actualState )
					file.hintState = e1v1State.INVALID
			}
		)

		WaitForever()
	}()
}

// The asset is authored on a 1920x1080 canvas. Fit a 16:9 plane to the screen
// height and anchor it top-left so the plate keeps its size and corner at any
// aspect; wider screens centre it like the retail HUD.
var function FS_1v1_CreateLobbyInfoTopology()
{
	UISize screenSize = GetScreenSize()
	float planeH = float( screenSize.height )
	float planeW = planeH * ( 16.0 / 9.0 )
	float xOffset = max( 0.0, ( screenSize.width - planeW ) / 2.0 )
	return RuiTopology_CreatePlane( <xOffset, 0, 0>, <planeW, 0, 0>, <0, planeH, 0>, false )
}

void function FS_1v1_DestroyLobbyInfo()
{
	if ( file.lobbyInfoRui != null )
	{
		RuiDestroyIfAlive( file.lobbyInfoRui )
		file.lobbyInfoRui = null
	}
	if ( file.lobbyInfoTopo != null )
	{
		RuiTopology_Destroy( file.lobbyInfoTopo )
		file.lobbyInfoTopo = null
	}
	file.lobbyInfoCount = -1
}

// Waiting room hides the minimap; SEQUENCE is still wait -- hold the plate until IN_MATCH.
bool function FS_1v1_ShouldShowLobbyInfo( int state )
{
	if ( FS_1v1_FullscreenPresentationActive() )
		return false
	return state == e1v1State.WAITING || state == e1v1State.RESTING || state == e1v1State.SEQUENCE
}

void function FS_1v1_UpdateLobbyInfo( bool show )
{
	if ( !show )
	{
		FS_1v1_DestroyLobbyInfo()
		return
	}

	if ( file.lobbyInfoRui == null )
	{
		asset lobbyAsset = GetKeyValueAsAsset( { kn = "ui/fs_1v1_lobbyinfo.rpak" }, "kn" )

		if ( file.lobbyInfoTopo == null )
			file.lobbyInfoTopo = FS_1v1_CreateLobbyInfoTopology()

		try
		{
			// posteffects stage: screen blur is refused in the HUD stage
			file.lobbyInfoRui = RuiCreate( lobbyAsset, file.lobbyInfoTopo, RUI_DRAW_POSTEFFECTS, 0 )
			InitHUDRui( file.lobbyInfoRui )
			RuiSetString( file.lobbyInfoRui, "headerText", "PLAYERS CONNECTED" )

			asset lobbyEmblem = GetModeEmblemImage( GetCurrentPlaylistName() )
			if ( lobbyEmblem != $"" )
				RuiSetImage( file.lobbyInfoRui, "logoImage", lobbyEmblem )

			RuiSetImage( file.lobbyInfoRui, "cardImage", $"rui/flowstate_custom/queue_card" )
			RuiSetImage( file.lobbyInfoRui, "lockClosedImage", $"rui/menu/buttons/large_lock" )
			RuiSetImage( file.lobbyInfoRui, "lockOpenImage", $"rui/menu/buttons/unlocked" )
			RuiSetImage( file.lobbyInfoRui, "queueMouseIcon", FS_1v1_InputIcon( 0 ) )
			RuiSetImage( file.lobbyInfoRui, "queuePadIcon", FS_1v1_InputIcon( 1 ) )
		}
		catch ( eLobbyInfo )
		{
			if ( !file.lobbyInfoProbed )
			{
				file.lobbyInfoProbed = true
				printt( "[FS-1V1] lobby RuiCreate: " + eLobbyInfo + " topoFS=" + clGlobal.topoFullScreen )
				try
				{
					var probe = RuiCreate( FS_1V1_HINT_RUI, file.lobbyInfoTopo, RUI_DRAW_HUD, 0 )
					printt( "[FS-1V1] retail probe ok" )
					RuiDestroyIfAlive( probe )
				}
				catch ( eProbe )
				{
					printt( "[FS-1V1] retail probe: " + eProbe )
				}
			}
			file.lobbyInfoRui = null
			return
		}
		file.lobbyInfoCount = -1
	}

	// GetPlayerArray on this client is realm-culled; duel-slot bots are invisible.
	int connected = GetConnectedPlayerCount()
	if ( connected != file.lobbyInfoCount )
	{
		file.lobbyInfoCount = connected
		RuiSetString( file.lobbyInfoRui, "countText", string( connected ) )
	}

	FS_1v1_UpdateQueueCard()
}

// Matchmaking readout under the header, on the same plate. Refreshed by every
// UpdateLobbyInfo call; the 0.5s watchdog gives the countdown text its cadence
// while the bar itself animates in the RUI off game time.
void function FS_1v1_UpdateQueueCard()
{
	if ( file.lobbyInfoRui == null )
		return

	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	bool searching = player.GetPlayerNetInt( "FS_1v1_PlayerState" ) == e1v1State.WAITING
	float graceEnd = player.GetPlayerNetTime( "FS_1v1_QueueGraceEnd" )
	float graceDur = player.GetPlayerNetFloat( "FS_1v1_QueueGraceDur" )
	bool graceActive = searching && graceDur > 0.0 && graceEnd > Time()
	bool isMnk = player.GetPlayerNetBool( "FS_PlayerIsMnk" )

	RuiSetFloat( file.lobbyInfoRui, "queueVis", searching ? 1.0 : 0.0 )
	RuiSetFloat( file.lobbyInfoRui, "graceVis", graceActive ? 1.0 : 0.0 )
	RuiSetFloat( file.lobbyInfoRui, "lockedVis", graceActive ? 1.0 : 0.0 )
	RuiSetFloat( file.lobbyInfoRui, "openVis", searching && !graceActive ? 1.0 : 0.0 )
	RuiSetString( file.lobbyInfoRui, "queueTitle", searching ? "WAITING FOR PLAYERS" : "" )

	// value twins: text color is fixed per widget, so the locked filter uses
	// the cyan widget and ANY INPUT the dim one
	string filterText = ""
	string filterAnyText = ""
	if ( searching )
	{
		if ( graceActive )
		{
			filterText = isMnk ? "MNK ONLY" : "CONTROLLER ONLY"
			RuiSetImage( file.lobbyInfoRui, "queueInputIcon", FS_1v1_InputIcon( isMnk ? 0 : 1 ) )
		}
		else
		{
			filterAnyText = "ANY INPUT"
		}
	}
	RuiSetString( file.lobbyInfoRui, "queueFilter", filterText )
	RuiSetString( file.lobbyInfoRui, "queueFilterAny", filterAnyText )

	string graceText = ""
	if ( graceActive )
	{
		RuiSetGameTime( file.lobbyInfoRui, "graceEnd", graceEnd )
		RuiSetFloat( file.lobbyInfoRui, "graceDur", graceDur )

		int remaining = int( ceil( graceEnd - Time() ) )
		if ( remaining < 0 )
			remaining = 0
		graceText = format( "OPENS TO ANY INPUT IN %d:%02d", remaining / 60, remaining % 60 )
	}
	RuiSetString( file.lobbyInfoRui, "graceText", graceText )
}

void function Gamemode1v1_DestroyPermaHint()
{
	if ( file.activeQuickHint2 != null )
	{
		RuiDestroyIfAlive( file.activeQuickHint2 )
		file.activeQuickHint2 = null
	}
}

void function Gamemode1v1_PermaHint( string hintText )
{
	Gamemode1v1_DestroyPermaHint()

	try
	{
		file.activeQuickHint2 = CreateFullscreenRui( FS_1V1_HINT_RUI )
		RuiSetGameTime( file.activeQuickHint2, "startTime", Time() )
		RuiSetGameTime( file.activeQuickHint2, "endTime", 9999999 )
		RuiSetBool( file.activeQuickHint2, "commsMenuOpen", false )
		RuiSetString( file.activeQuickHint2, "msg", hintText )
	}
	catch ( eHint )
	{
		file.activeQuickHint2 = null
		printt( "[FS-1V1] PermaHint RUI failed: " + eHint )
	}
}

void function FS_Show1v1Banner( entity player )
{
	#if !DEVELOPER
		if( GetGameState() >= eGameState.Playing )
			return
	#endif

	float duration = 5

	clGlobal.levelEnt.Signal( "FS_1v1Banner" )
	clGlobal.levelEnt.EndSignal( "FS_1v1Banner" )
	player.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ()
		{
			Hud_SetVisible( HudElement( HUD_1V1_BANNER ), false )
		}
	)

	Hud_ReturnToBasePos( HudElement( HUD_1V1_BANNER ) )
	Hud_SetSize( HudElement( HUD_1V1_BANNER ), 0, 0 )

	Hud_SetVisible( HudElement( HUD_1V1_BANNER ), true )
	Hud_ScaleOverTime( HudElement( HUD_1V1_BANNER ), 1.7, 1.7, 1, INTERPOLATOR_ACCEL )
	wait 1
	Hud_ScaleOverTime( HudElement( HUD_1V1_BANNER ), 1, 1, 2, INTERPOLATOR_SIMPLESPLINE )
	wait duration - 2
	Hud_FadeOverTime( HudElement( HUD_1V1_BANNER ), 0, 3, INTERPOLATOR_ACCEL )
	wait 2
}


// =====================================================================================
// CROSS-REALM SCOREBOARD SYNC (CLIENT-SIDE)
// Receives player data pushed by the server via Remote_CallFunction_NonReplay,
// stores it in a local cache, and feeds it to the FSLeaderboard UI on TAB press.
// =====================================================================================

// Unpack 4 integers back into a player name string.
// Each int holds 4 ASCII characters in little-endian byte order.
string function Scoreboard1v1_UnpackName( int n1, int n2, int n3, int n4 )
{
	string name = ""
	array<int> parts = [n1, n2, n3, n4]

	for ( int p = 0; p < parts.len(); p++ )
	{
		int part = parts[p]
		for ( int b = 0; b < 4; b++ )
		{
			int charVal = ( part >> ( b * 8 ) ) & 0xFF
			if ( charVal == 0 )
				return name
			name += format( "%c", charVal )
		}
	}

	return name
}

ScoreboardCacheEntry function Scoreboard1v1_GetOrCreate( int h )
{
	if ( h in file.scoreboardByHash )
		return file.scoreboardByHash[h]

	ScoreboardCacheEntry entry
	entry.hash = h
	file.scoreboardByHash[h] <- entry
	return entry
}

void function Scoreboard1v1_ApplyName( int h, int n1, int n2, int n3, int n4 )
{
	if ( h == 0 )
		return
	ScoreboardCacheEntry entry = Scoreboard1v1_GetOrCreate( h )
	entry.name = Scoreboard1v1_UnpackName( n1, n2, n3, n4 )
	file.scoreboardByHash[h] <- entry
}

void function Scoreboard1v1_ApplyStats( int h, int kdPing, int dmgFlags )
{
	if ( h == 0 )
		return

	// Name-first contract: a row the name pass never delivered would render as a
	// blank line. Note it and ask for a resync instead of drawing the gap.
	if ( !( h in file.scoreboardByHash ) )
	{
		file.scoreboardMissingNames = true
		return
	}

	ScoreboardCacheEntry entry = file.scoreboardByHash[h]
	int kills = kdPing & 4095
	int deaths = ( kdPing >> 12 ) & 4095
	int latency = ( kdPing >> 24 ) & 255
	int damage = dmgFlags & 1048575
	int isLocal = ( dmgFlags >> 20 ) & 1
	int streak = ( dmgFlags >> 21 ) & 63
	entry.kills = kills
	entry.deaths = deaths
	entry.latency = latency
	entry.damage = damage
	entry.isLocal = isLocal
	entry.winStreak = streak
	entry.input = ( ( dmgFlags >> 27 ) & 3 ) - 1
	if ( deaths > 0 )
		entry.kd = kills.tofloat() / deaths.tofloat()
	else
		entry.kd = kills.tofloat()
	file.scoreboardByHash[h] <- entry
}

void function ServerCallback_1v1_SbName( int c, int h0, int a0, int b0, int c0, int d0, int h1, int a1, int b1, int c1, int d1, int h2, int a2, int b2, int c2, int d2 )
{
	if ( c > 0 )
		Scoreboard1v1_ApplyName( h0, a0, b0, c0, d0 )
	if ( c > 1 )
		Scoreboard1v1_ApplyName( h1, a1, b1, c1, d1 )
	if ( c > 2 )
		Scoreboard1v1_ApplyName( h2, a2, b2, c2, d2 )
}

void function Scoreboard1v1_ApplySlot( int h, int slot )
{
	if ( !( h in file.scoreboardByHash ) )
	{
		if ( h != 0 )
			file.scoreboardMissingNames = true
		return
	}
	file.scoreboardByHash[h].slot = slot
}

void function Scoreboard1v1_ApplyCard( int h, int careerKills, int careerDeaths, int charGuid, int skinGuid, int frameGuid )
{
	if ( h == 0 )
		return

	if ( !( h in file.scoreboardByHash ) )
	{
		file.scoreboardMissingNames = true
		return
	}

	ScoreboardCacheEntry entry = file.scoreboardByHash[h]
	entry.careerKills = careerKills
	entry.careerDeaths = careerDeaths
	entry.charGuid = charGuid
	entry.skinGuid = skinGuid
	entry.frameGuid = frameGuid
	file.scoreboardByHash[h] <- entry
}

void function ServerCallback_1v1_SbCard( int c, int h0, int ck0, int cd0, int ch0, int sk0, int fr0, int h1, int ck1, int cd1, int ch1, int sk1, int fr1 )
{
	if ( c > 0 )
		Scoreboard1v1_ApplyCard( h0, ck0, cd0, ch0, sk0, fr0 )
	if ( c > 1 )
		Scoreboard1v1_ApplyCard( h1, ck1, cd1, ch1, sk1, fr1 )
}

void function ServerCallback_1v1_ChallengeState( int extraCount, int p0, int p1, int p2, int p3, int o0, int o1, int o2, int o3 )
{
	string prompt = Scoreboard1v1_UnpackName( p0, p1, p2, p3 )
	string outgoing = Scoreboard1v1_UnpackName( o0, o1, o2, o3 )
	RunUIScript( "Leaderboard_SetChallengePrompt", prompt, extraCount, outgoing )
}

void function ServerCallback_1v1_ChallengeInbox( int count, int a0, int a1, int a2, int a3, int b0, int b1, int b2, int b3, int c0, int c1, int c2, int c3 )
{
	string n0 = ""
	string n1 = ""
	string n2 = ""
	if ( count > 0 )
		n0 = Scoreboard1v1_UnpackName( a0, a1, a2, a3 )
	if ( count > 1 )
		n1 = Scoreboard1v1_UnpackName( b0, b1, b2, b3 )
	if ( count > 2 )
		n2 = Scoreboard1v1_UnpackName( c0, c1, c2, c3 )
	RunUIScript( "Leaderboard_SetChallengeInbox", n0, n1, n2 )
}

void function ServerCallback_1v1_SbSlot( int c, int h0, int s0, int h1, int s1, int h2, int s2, int h3, int s3, int h4, int s4, int h5, int s5 )
{
	if ( c > 0 ) Scoreboard1v1_ApplySlot( h0, s0 )
	if ( c > 1 ) Scoreboard1v1_ApplySlot( h1, s1 )
	if ( c > 2 ) Scoreboard1v1_ApplySlot( h2, s2 )
	if ( c > 3 ) Scoreboard1v1_ApplySlot( h3, s3 )
	if ( c > 4 ) Scoreboard1v1_ApplySlot( h4, s4 )
	if ( c > 5 ) Scoreboard1v1_ApplySlot( h5, s5 )

	FS_1v1_ReapplyChatMutes()
}

void function ServerCallback_1v1_SbStats( int c, int h0, int p0, int d0, int h1, int p1, int d1, int h2, int p2, int d2, int h3, int p3, int d3, int h4, int p4, int d4 )
{
	if ( c > 0 )
		Scoreboard1v1_ApplyStats( h0, p0, d0 )
	if ( c > 1 )
		Scoreboard1v1_ApplyStats( h1, p1, d1 )
	if ( c > 2 )
		Scoreboard1v1_ApplyStats( h2, p2, d2 )
	if ( c > 3 )
		Scoreboard1v1_ApplyStats( h3, p3, d3 )
	if ( c > 4 )
		Scoreboard1v1_ApplyStats( h4, p4, d4 )
}

void function ServerCallback_1v1_ScoreboardClear()
{
	file.scoreboardByHash.clear()
	file.scoreboardCache.clear()
	file.scoreboardDataReady = false
	file.scoreboardMissingNames = false

	// Slots outlive the cache; drop them until the next slot batch re-stamps.
	ClearChatMutes()
}

// Rows arrived for hashes this client has no name for -- its name pass was lost.
// Ask once, throttled: the server answers with a full clear-and-resend.
void function Scoreboard1v1_RequestResync()
{
	file.scoreboardMissingNames = false

	if ( Time() - file.scoreboardResyncTime < SCOREBOARD_1V1_RESYNC_COOLDOWN )
		return

	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	file.scoreboardResyncTime = Time()
	player.ClientCommand( "CC_1v1_ScoreboardOpen 2" )
}

void function ServerCallback_1v1_ScoreboardRefresh()
{
	if ( file.scoreboardMissingNames )
		Scoreboard1v1_RequestResync()

	file.scoreboardCache.clear()
	foreach ( int h, ScoreboardCacheEntry entry in file.scoreboardByHash )
		file.scoreboardCache.append( entry )

	file.scoreboardDataReady = true
	Scoreboard1v1_SortAndRankCache()

	if ( file.fullScoreboardOpen )
		FS_1v1_PushCacheToLeaderboard()
}

void function ServerCallback_FSDM_SetScreen( int screen, int teamWon, int mapid, int done )
{
	if ( screen == eFSDMScreen.ScoreboardUI )
		FS_1v1_OpenRoundEndLeaderboard()
}

void function ServerCallback_FSDM_OpenVotingPhase( bool open )
{
	if ( open )
	{
		FS_1v1_OpenRoundEndLeaderboard()
		return
	}

	entity player = GetLocalClientPlayer()
	FS_1v1_CloseRoundEndLeaderboard()
	if ( IsValid( player ) )
		Signal( player, "ChallengeStartRemoveCameras" )
}

void function FS_1v1_OpenRoundEndLeaderboard()
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	if ( file.roundEndScoreboard && file.fullScoreboardOpen )
	{
		if ( file.scoreboardDataReady && file.scoreboardCache.len() > 0 )
			FS_1v1_PushCacheToLeaderboard()
		return
	}

	ForceHide1v1Scoreboard()
	file.roundEndScoreboard = true
	file.fullScoreboardOpen = true
	FS_1v1_SuppressAllHud()
	player.ClientCommand( "CC_1v1_ScoreboardOpen 1" )
	RunUIScript( "Leaderboard_SetRoundEndMode", 1 )
	RunUIScript( "Leaderboard_SetRoundTimer", "Round ended" )
	RunUIScript( "OpenMatchLeaderboard" )
	if ( file.scoreboardDataReady && file.scoreboardCache.len() > 0 )
		FS_1v1_PushCacheToLeaderboard()
	printt( "[FS-1V1] FSLeaderboard round-end open" )
}

void function FS_1v1_CloseRoundEndLeaderboard()
{
	entity player = GetLocalClientPlayer()
	file.roundEndScoreboard = false
	if ( IsValid( player ) )
		FS_1v1_SetCombatHudVisible( FS_1v1_ShouldShowCombatHud( player.GetPlayerNetInt( "FS_1v1_PlayerState" ) ) )
	if ( file.fullScoreboardOpen )
	{
		file.fullScoreboardOpen = false
		if ( IsValid( player ) )
			player.ClientCommand( "CC_1v1_ScoreboardOpen 0" )
		RunUIScript( "Leaderboard_SetRoundEndMode", 0 )
		RunUIScript( "CloseMatchLeaderboard" )
	}
	printt( "[FS-1V1] FSLeaderboard round-end close" )
}

void function Scoreboard1v1_SortAndRankCache()
{
	file.scoreboardCache.sort( int function( ScoreboardCacheEntry a, ScoreboardCacheEntry b )
	{
		if ( a.kills < b.kills )
			return 1
		if ( a.kills > b.kills )
			return -1
		if ( a.damage < b.damage )
			return 1
		if ( a.damage > b.damage )
			return -1
		return 0
	} )

	for ( int i = 0; i < file.scoreboardCache.len(); i++ )
	{
		ScoreboardCacheEntry entry = file.scoreboardCache[i]
		entry.rank = i + 1
		file.scoreboardCache[i] = entry
	}
}

void function ServerCallback_1v1_VsHudEnemy( int n1, int n2, int n3, int n4, int kills, int deaths, int damage, int latency, int enemyRank, int localRank )
{
	file.vsHudEnemyName = Scoreboard1v1_UnpackName( n1, n2, n3, n4 )
	file.vsHudEnemyKills = kills
	file.vsHudEnemyDeaths = deaths
	file.vsHudEnemyDamage = damage
	file.vsHudEnemyLatency = latency
	file.vsHudEnemyRank = enemyRank
	file.vsHudLocalRank = localRank
	file.vsHudRemoteActive = true

	if ( file.show1v1Scoreboard && !file.vsHudShown )
		FS_1v1_ToggleUIVisibility( true, null )
}

void function ServerCallback_1v1_VsHudHide()
{
	file.vsHudRemoteActive = false
	file.vsHudEnemyName = ""
	FS_1v1_ToggleUIVisibility( false, null )
}

void function ServerCallback_1v1_Obituary( int a1, int a2, int a3, int a4, int v1, int v2, int v3, int v4, int damageSourceId, int obitFlags )
{
	if ( GetConVarInt( "hud_setting_showObituary" ) == 0 )
		return

	if ( FS_1v1_FullscreenPresentationActive() )
		return

	string attackerName = Scoreboard1v1_UnpackName( a1, a2, a3, a4 )
	string victimName = Scoreboard1v1_UnpackName( v1, v2, v3, v4 )
	if ( victimName == "" )
		return

	string attackerString = ""
	if ( attackerName != "" )
		attackerString = Localize( "#OBIT_PLAYER_STRING", attackerName )
	string victimString = Localize( "#OBIT_PLAYER_STRING", victimName )

	asset weaponIcon = GetObitImageFromDamageSourceID( damageSourceId )
	string weaponDisplayName = ""
	if ( weaponIcon == $"" )
	{
		string sourceDisplayName = GetObitFromDamageSourceID( damageSourceId )
		if ( sourceDisplayName != "" )
			weaponDisplayName = Localize( sourceDisplayName )
	}

	bool isMainWeapon = false
	try
	{
		string damageRef = GetRefFromDamageSourceID( damageSourceId )
		if ( SURVIVAL_Loot_IsRefValid( damageRef ) )
		{
			LootData lootData = SURVIVAL_Loot_GetLootDataByRef( damageRef )
			isMainWeapon = lootData.lootType == eLootType.MAINWEAPON
		}
		else if ( GetIsAdditionalMainWeapon( damageSourceId ) )
		{
			isMainWeapon = true
		}
	}
	catch ( eRef )
	{
	}

	asset modifierIcon = $""
	if ( ( obitFlags & OBIT_FLAG_DOWNED ) > 0 )
		modifierIcon = $"rui/hud/obituary/obituary_downed"
	else if ( ( obitFlags & OBIT_FLAG_HEADSHOT ) > 0 )
		modifierIcon = $"rui/hud/obituary/obituary_headshot"

	entity lp = GetLocalClientPlayer()
	string localName = ""
	if ( IsValid( lp ) )
		localName = lp.GetPlayerName()
	if ( localName.len() > 16 )
		localName = localName.slice( 0, 16 )

	vector attackerColor = <255, 255, 255>
	vector victimColor = <255, 255, 255>
	if ( localName != "" )
	{
		if ( attackerName == localName )
			attackerColor = OBITUARY_COLOR_LOCALPLAYER
		if ( victimName == localName )
			victimColor = OBITUARY_COLOR_LOCALPLAYER
	}

	ObitRankBadgeInfo badgeInfo
	Obituary_Print_PlayerDeath( attackerString, weaponIcon, weaponDisplayName, modifierIcon, victimString, badgeInfo, attackerColor, victimColor, <255, 255, 255>, isMainWeapon, obitFlags )
}

// Push cached scoreboard data to the FSLeaderboard UI via RunUIScript.
void function FS_1v1_PushCacheToLeaderboard()
{
	RunUIScript( "Leaderboard_Clear" )
	RunUIScript( "Leaderboard_SetGamemode", "1v1" )

	// Send round timer info to UI
	float roundEndTime = GetGlobalNetTime( "flowstate_DMRoundEndTime" )
	if ( roundEndTime > 0 )
	{
		float remaining = roundEndTime - Time()
		if ( remaining > 0 )
		{
			int mins = int( remaining / 60.0 )
			int secs = int( remaining ) % 60
			RunUIScript( "Leaderboard_SetRoundTimer", format( "Round: %d:%02d", mins, secs ) )
		}
		else
		{
			RunUIScript( "Leaderboard_SetRoundTimer", "Round ended" )
		}
	}

	foreach ( ScoreboardCacheEntry entry in file.scoreboardCache )
	{
		// FSLeaderboard: score = kills. Read the cross-realm cache -- the player entity is blank outside the local realm.
		int muted = ( entry.name in file.chatMutedNames ) ? 1 : 0
		RunUIScript( "Leaderboard_ReceivePlayerData",
			entry.name, entry.kills, entry.kills, entry.deaths,
			entry.kd, entry.damage, entry.latency, entry.isLocal, muted, entry.input )
		RunUIScript( "Leaderboard_SetCardData", entry.name,
			entry.charGuid, entry.skinGuid, entry.frameGuid, entry.careerKills, entry.careerDeaths )
	}

	RunUIScript( "Leaderboard_Refresh" )
}

entity function FS_1v1_FindPlayerByName( string name )
{
	if ( name == "" )
		return null

	foreach ( entity p in GetPlayerArray() )
	{
		if ( IsValid( p ) && p.GetPlayerName() == name )
			return p
	}

	// Scoreboard1v1_PackName caps at 16 chars, so a longer name reaches the
	// leaderboard truncated and never matches exactly.
	if ( name.len() >= SCOREBOARD_1V1_PACKED_NAME_MAX )
	{
		foreach ( entity p in GetPlayerArray() )
		{
			if ( !IsValid( p ) )
				continue
			string full = p.GetPlayerName()
			if ( full.len() > SCOREBOARD_1V1_PACKED_NAME_MAX
				&& full.slice( 0, SCOREBOARD_1V1_PACKED_NAME_MAX ) == name )
				return p
		}
	}

	return null
}

// Chat mute keys on the scoreboard slot, not a player entity -- other-realm players have none locally.
int function FS_1v1_SlotForScoreboardName( string name )
{
	foreach ( int h, ScoreboardCacheEntry entry in file.scoreboardByHash )
	{
		if ( entry.name == name )
			return entry.slot
	}
	return -1
}

// The mute set is kept by name and re-stamped onto slots on every scoreboard
// refresh: a slot is an entity index, so it is handed to a different player as
// soon as the muted one disconnects.
void function FS_1v1_ReapplyChatMutes()
{
	ClearChatMutes()

	if ( file.chatMutedNames.len() == 0 )
		return

	foreach ( int h, ScoreboardCacheEntry entry in file.scoreboardByHash )
	{
		if ( entry.slot >= 0 && entry.name in file.chatMutedNames )
			SetChatMutedSlot( entry.slot, true )
	}
}

void function FS_1v1_ToggleMuteByName( string name )
{
	int slot = FS_1v1_SlotForScoreboardName( name )
	if ( slot < 0 )
	{
		printt( "[FS-1V1] no sender slot cached for '" + name + "' -- reverting" )
		RunUIScript( "Leaderboard_SetMuted", name, 0 )
		return
	}

	bool muted = !( name in file.chatMutedNames )
	if ( muted )
		file.chatMutedNames[name] <- true
	else
		delete file.chatMutedNames[name]

	FS_1v1_ReapplyChatMutes()
	printt( "[FS-1V1] chat mute '" + name + "' slot=" + string( slot ) + " muted=" + string( muted ) )

	// Local player entity is optional: mute their voice too when we have it.
	entity p = FS_1v1_FindPlayerByName( name )
	if ( IsValid( p ) && p != GetLocalClientPlayer() && p.IsVoiceAndTextMuted() != muted )
		TogglePlayerVoiceAndTextMute( p )

	RunUIScript( "Leaderboard_SetMuted", name, muted ? 1 : 0 )
}


// Map key (toggle_map / default M): Flowstate FSLeaderboard.
void function FS_1v1_ToggleFullScoreboard( entity player )
{
	if ( player != GetLocalClientPlayer() )
		return

	if ( FS_1v1_LeaderboardLocked() )
		return

	if ( file.fullScoreboardOpen )
	{
		file.fullScoreboardOpen = false
		player.ClientCommand( "CC_1v1_ScoreboardOpen 0" )
		RunUIScript( "CloseMatchLeaderboard" )
		printt( "[FS-1V1] FSLeaderboard closed" )
	}
	else
	{
		file.fullScoreboardOpen = true
		// Server only packs NonReplay scoreboard for open boards (avoids always-on O(N^2)).
		player.ClientCommand( "CC_1v1_ScoreboardOpen 1" )
		RunUIScript( "OpenMatchLeaderboard" )

		if ( file.scoreboardDataReady && file.scoreboardCache.len() > 0 )
			FS_1v1_PushCacheToLeaderboard()
		printt( "[FS-1V1] FSLeaderboard open (map key)" )
	}
}

// Called from UI OnLeaderboardClose so X/back/CloseAllMenus cannot leave fullScoreboardOpen stuck.
void function FS_1v1_OnFullScoreboardClosed()
{
	file.fullScoreboardOpen = false
	file.roundEndScoreboard = false
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		player.ClientCommand( "CC_1v1_ScoreboardOpen 0" )
}
