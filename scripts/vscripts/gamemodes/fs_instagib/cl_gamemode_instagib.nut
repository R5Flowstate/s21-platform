// Instagib client: freedm gamestate HUD, death overlay, optional legend reselect.

global function Cl_GamemodeInstagib_Init
global function ServerCallback_Instagib_RespawnUI
global function ServerCallback_Instagib_ClearDeathUI
global function ServerCallback_Instagib_Score

const string INSTAGIB_CHARSELECT_HINT = "%use% CHANGE LEGEND"

// %use% is substituted for the bound key by Localize, not by the RUI.
string function FS_IG_CharSelectHint()
{
	return Localize( INSTAGIB_CHARSELECT_HINT )
}

struct
{
	int lastKills = 0
	int lastDeaths = 0
	bool awaitingRespawn = false
	var deathHintRui = null
} file

void function Cl_GamemodeInstagib_Init()
{
	// Must precede ClGameState_Init -> CreateScoreRUI.
	FS_Hud_RegisterFreeDMScorebar( "instagib" )

	FS_Core_SharedInit()
	FlagInit( "SquadEliminated" )
	HudTargetInfo_Enable( true )

	RegisterSignal( "FS_IG_StopDeathHint" )
	RegisterConCommandTriggeredCallback( "+use", FS_IG_TryOpenCharSelect )
	RegisterConCommandTriggeredCallback( "toggle_map", FS_Hud_ToggleLeaderboard )
	RegisterNetVarTimeChangeCallback( "flowstate_DMRoundEndTime", FS_IG_RoundEndTimeChanged )
	AddCallback_LocalClientPlayerSpawned( FS_IG_OnLocalPlayerSpawned )

	thread FS_IG_HudBind_THREAD()
	thread FS_IG_ApplyMovementWhenReady_THREAD()
	thread FS_IG_WorkInProgressSplash_THREAD()

	printt( "[FS-IG] Cl_GamemodeInstagib_Init" )
}

void function FS_IG_WorkInProgressSplash_THREAD()
{
	entity player
	while ( true )
	{
		player = GetLocalClientPlayer()
		if ( IsValid( player ) && player.IsPlayer() && IsAlive( player ) )
			break
		wait 0.5
	}

	wait 4.0

	AnnouncementData announcement = Announcement_Create( "WORK IN PROGRESS" )
	Announcement_SetSubText( announcement, "Mode is in the kitchen." )
	Announcement_SetTitleColor( announcement, <1, 0.45, 0.05> )
	announcement.duration = 8.0
	announcement.hideOnDeath = false
	announcement.purge = true
	announcement.priority = 100

	printt( "[FS-IG] work-in-progress splash firing" )
	AnnouncementFromClass( player, announcement )
}

void function FS_IG_HudBind_THREAD()
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
		printt( "[FS-IG] HUD bind aborted -- no gamestate RUI or player" )
		return
	}

	FS_Hud_CombatHudInit()
	FS_IG_SetFreeDMClock( GetGlobalNetTime( "flowstate_DMRoundEndTime" ) )
	printt( "[FS-IG] combat HUD + gamestate RUI bound" )
}

void function FS_IG_RoundEndTimeChanged( entity player, float new )
{
	FS_IG_SetFreeDMClock( new )
}

void function FS_IG_SetFreeDMClock( float endTime )
{
	FS_Hud_SetScorebarClock( endTime, GetGlobalNetTime( "flowstate_DMStartTime" ) )
}

void function FS_IG_DestroyDeathHint()
{
	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		player.Signal( "FS_IG_StopDeathHint" )

	if ( file.deathHintRui != null )
	{
		RuiDestroyIfAlive( file.deathHintRui )
		file.deathHintRui = null
	}
	HidePlayerHint( FS_IG_CharSelectHint() )
}

void function FS_IG_SetDeathHintMsg( float endTime )
{
	int remain = int( ceil( endTime - Time() ) )
	if ( remain < 0 )
		remain = 0
	string msg = Localize( "#RESPAWNING_IN" ) + " " + string( remain ) + "\n" + FS_IG_CharSelectHint()
	if ( file.deathHintRui != null )
		RuiSetString( file.deathHintRui, "msg", msg )
}

void function FS_IG_DeathHint_THREAD( float endTime )
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	EndSignal( player, "OnDestroy" )
	EndSignal( player, "FS_IG_StopDeathHint" )

	while ( file.awaitingRespawn && Time() < endTime )
	{
		FS_IG_SetDeathHintMsg( endTime )
		wait 0.25
	}
}

void function FS_IG_ShowDeathHint( float waitTime )
{
	FS_IG_DestroyDeathHint()

	try
	{
		file.deathHintRui = CreateFullscreenRui( $"ui/wraith_comms_hint.rpak" )
		RuiSetGameTime( file.deathHintRui, "startTime", Time() )
		RuiSetGameTime( file.deathHintRui, "endTime", Time() + waitTime )
		RuiSetBool( file.deathHintRui, "commsMenuOpen", false )
		FS_IG_SetDeathHintMsg( Time() + waitTime )
	}
	catch ( eHint )
	{
		file.deathHintRui = null
		printt( "[FS-IG] death hint RUI failed: " + eHint )
	}

	if ( waitTime > 0.5 )
		AddPlayerHint( waitTime, 0.25, $"", FS_IG_CharSelectHint() )

	thread FS_IG_DeathHint_THREAD( Time() + waitTime )
}

void function FS_IG_TryOpenCharSelect( entity player )
{
	if ( !file.awaitingRespawn )
		return
	if ( player != GetLocalClientPlayer() )
		return
	if ( CharacterSelect_MenuIsOpen() )
		return
	if ( !CharacterSelect_Menu_ShouldOpen( player ) )
		return

	FS_IG_DestroyDeathHint()
	HideScoreboard()
	OpenCharacterSelectMenu( true, true )
}

void function ServerCallback_Instagib_RespawnUI( int seconds )
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	file.awaitingRespawn = true

	float waitTime = float( seconds )
	float endTime = Time() + waitTime
	RunUIScript( "SetRespawnOverlayTime", Time(), endTime )
	RunUIScript( "SetRespawnOverlayString", "#RESPAWNING_IN" )
	RunUIScript( "SetRespawnOverlayIdleString", "#READY_TO_SPAWN" )

	FS_IG_ShowDeathHint( waitTime )
}

void function ServerCallback_Instagib_ClearDeathUI()
{
	file.awaitingRespawn = false
	FS_IG_DestroyDeathHint()
	if ( CharacterSelect_MenuIsOpen() )
		CloseCharacterSelectMenu()
	RunUIScript( "UI_ClearRespawnOverlay" )
}

void function ServerCallback_Instagib_Score( int kills, int deaths )
{
	file.lastKills = kills
	file.lastDeaths = deaths
}

void function FS_IG_OnLocalPlayerSpawned( entity player )
{
	FS_Instagib_ApplyMovement( player )
}

// First spawn can land before this init registers the callback, or while the
// local slot / settings block is not ready yet (refused, sticky stays empty).
void function FS_IG_ApplyMovementWhenReady_THREAD()
{
	float deadline = Time() + 30.0
	entity player = GetLocalClientPlayer()
	while ( Time() < deadline && ( !IsValid( player ) || !player.IsPlayer() || !IsAlive( player ) ) )
	{
		wait 0.5
		player = GetLocalClientPlayer()
	}

	if ( !IsValid( player ) || !player.IsPlayer() || !IsAlive( player ) )
		return

	FS_Instagib_ApplyMovement( player )

	wait 1.0

	if ( IsValid( player ) && player.IsPlayer() && IsAlive( player ) )
		FS_Instagib_ApplyMovement( player )
}
