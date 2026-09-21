untyped

global function InitDevMenu
// Always available: DevMenu content gated by sv_cheats at runtime (not -dev/DEVELOPER).
global function DEV_InitLoadoutDevSubMenu
global function SetupAlterLoadout
global function SetupDevCommand
global function SetupDevFunc
global function SetupDevMenu
global function ChangeToThisMenu
global function RepeatLastDevCommand
global function UpdatePrecachedSPWeapons
global function RunCodeDevCommandByAlias
global function DEV_ExecBoundDevMenuCommand
global function DEV_InitCodeDevMenu
global function DevMenu_ToggleBG

global function ServerCallback_OpenDevMenu
global function AimTrainer_UI_SyncDevMenuState
global function MovementRecorder_UI_Open
global function CafeMod_UI_SyncState
global function CafeMod_UI_ItemsState
global function UpdateDevMenuServerState
global function DevMenu_SetInfiniteAbilities
global function GetCheatsState



global function DevHud_Toggle
global function DevHud_IsHidden
global function DevHud_Apply
global function DevHud_SetHidden

global function AddLevelDevCommand

const string DEV_MENU_NAME = "[LEVEL]"

struct DevMenuPage
{
	void functionref()      devMenuFunc
	void functionref( var ) devMenuFuncWithOpParm
	var                     devMenuOpParm
}

struct DevCommand
{
	string                  label
	string                  command
	var                     opParm
	void functionref( var ) func
	bool                    isAMenuCommand = false
	bool					canBeUsedInMatchmaking = false
}


struct
{
	array<DevMenuPage> pageHistory = []
	DevMenuPage &      currentPage
	var                header
	array<var>         buttons
	array<table>       actionBlocks
	array<DevCommand>  devCommands
	DevCommand&        lastDevCommand
	bool               lastDevCommandAssigned
	string             lastDevCommandLabel
	string             lastDevCommandLabelInProgress
	bool               precachedWeapons

	DevCommand& focusedCmd
	bool        focusedCmdIsAssigned

	DevCommand boundCmd
	bool       boundCmdIsAssigned

	var footerHelpTxtLabel

	bool                      initializingCodeDevMenu = false
	string                    codeDevMenuPrefix = DEV_MENU_NAME + "/"
	table<string, DevCommand> codeDevMenuCommands

	array<DevCommand> levelSpecificCommands = []

	var menu
	var bg

	// Aim trainer DevMenu labels (UI mirror; flipped on toggle, server owns gameplay).
	bool aimTrainerReloadHit = false
	bool aimTrainerReloadShot = false
	bool aimTrainerReloadKill = true
	bool aimTrainerDynStats = false
	bool aimTrainerReconBars = false
	bool aimTrainerHighlight = true
	bool aimTrainerStraferFire = false
	int aimTrainerStraferAim = 50
	int aimTrainerStrafeWidth = 512
	bool aimTrainerFixedSpawn = false
	int  aimTrainerDurationSec = 60
	bool aimTrainerStraferGod = false
	int  aimTrainerStrafeSpeedTenth = 10
	int  aimTrainerDummyShield = 0
	int  aimTrainerStraferBody = 0
	int  aimTrainerStraferLegendIdx = -1

	// Main DevMenu toggle labels (UI mirror).
	bool devNoclip = false
	bool devInfiniteAmmo = false
	bool devInfiniteAbilities = false
	bool devAutoRespawn = false
	bool devGodMode = false
	bool devThirdPerson = false
	bool devAlertMsgs = false
	bool devHudHidden = false
	bool buildingDevMenu = false
	bool devMenuInited = false
	bool devSkyboxView = false
	// Default ON = map triggers live (server starts enabled).
	bool devMapTriggers = true

	// CafeMod DevMenu bitfield (server truth; slot i = bit i).
	int cafeModBits = 0

	// Items Weapon config mirror (cafeitems set/physics).
	int cafeItemsProfile = 0
	bool cafeItemsPhysics = true

	// Player Models submenu selection label (UI mirror).
	string cafePlayerModelId = "default"

	// Legacy cafe port: always open DevMenu; content gated by sv_cheats.
	bool cheatsState = false
	// True when local client is GetPlayerArray()[0] (admin seat for global tools).
	bool isServerPlayer0 = false
} file

function Dummy_Untyped( param )
{

}

// Client -> UI: cheats + player-0 seat (from DEV_SendDevMenuStateToUI).
// Change-guarded: SetupDefaultDevCommandsMP pushes this from inside a page build,
// so an unconditional refresh here would rebuild forever.
void function UpdateDevMenuServerState( bool cheatsState, bool isServerPlayer0 )
{
	bool changed = ( file.cheatsState != cheatsState || file.isServerPlayer0 != isServerPlayer0 )
	file.cheatsState = cheatsState
	file.isServerPlayer0 = isServerPlayer0

	Lab_SetState( cheatsState, isServerPlayer0 )

	if ( changed && GetActiveMenu() == GetMenu( "DevMenu" ) )
		UpdateDevMenuButtons()
}

void function DevMenu_SetInfiniteAbilities( bool enable )
{
	file.devInfiniteAbilities = enable
}

// Server -> client -> UI: dynamic CafeMod slot labels.
void function CafeMod_UI_ResolveDynamicDefs()
{
	int idx = CafeMod_GetCount()
	foreach ( mod in ModList_Get() )
	{
		if ( idx >= CAFEMOD_MAX )
			break
		if ( !mod.enabled || !mod.hasScripts )
			continue

		CafeMod_DefineDynamic( idx, mod.id, mod.name != "" ? mod.name : mod.id )
		idx++
	}
}

void function CafeMod_UI_SyncState( int bitfield )
{
	CafeMod_UI_ResolveDynamicDefs()

	bool changed = ( file.cafeModBits != bitfield )
	file.cafeModBits = bitfield
	printt( format( "[CafeMod] UI sync bits=0x%x", bitfield ) )
	LabMods_SetBits( bitfield )
	if ( changed && GetActiveMenu() == GetMenu( "DevMenu" ) )
		UpdateDevMenuButtons()
}

void function CafeMod_UI_ItemsState( int profileIndex, int physicsOn )
{
	bool physics = ( physicsOn != 0 )
	bool changed = ( file.cafeItemsProfile != profileIndex || file.cafeItemsPhysics != physics )
	file.cafeItemsProfile = profileIndex
	file.cafeItemsPhysics = physics
	printt( format( "[CafeMod] UI items profile=%d physics=%s", profileIndex, string( physics ) ) )
	if ( changed && GetActiveMenu() == GetMenu( "DevMenu" ) )
		UpdateDevMenuButtons()
}

// Server -> client -> UI: reconcile DevMenu aim-trainer toggle labels.
// Must live outside #if DEVELOPER: global is always declared; DEVELOPER=0
// (no -dev) would strip the body and fail UI compile.
void function AimTrainer_UI_SyncDevMenuState( bool hit, bool shot, bool kill, bool dynStats, bool reconBars, int durationSec, bool straferGod, int strafeSpeedTenth, int dummyShield, int straferBody, int straferLegendIdx, bool highlight = true, bool straferFire = false, int straferAim = 50, int strafeWidth = 512, bool fixedSpawn = false )
{
	bool changed = ( file.aimTrainerReloadHit != hit
		|| file.aimTrainerHighlight != highlight
		|| file.aimTrainerStraferFire != straferFire
		|| file.aimTrainerStraferAim != straferAim
		|| file.aimTrainerStrafeWidth != strafeWidth
		|| file.aimTrainerFixedSpawn != fixedSpawn
		|| file.aimTrainerReloadShot != shot
		|| file.aimTrainerReloadKill != kill
		|| file.aimTrainerDynStats != dynStats
		|| file.aimTrainerReconBars != reconBars
		|| file.aimTrainerStraferGod != straferGod
		|| ( strafeSpeedTenth > 0 && file.aimTrainerStrafeSpeedTenth != strafeSpeedTenth )
		|| ( durationSec > 0 && file.aimTrainerDurationSec != durationSec )
		|| ( dummyShield >= 0 && file.aimTrainerDummyShield != dummyShield )
		|| file.aimTrainerStraferBody != straferBody
		|| file.aimTrainerStraferLegendIdx != straferLegendIdx )

	file.aimTrainerReloadHit = hit
	file.aimTrainerReloadShot = shot
	file.aimTrainerReloadKill = kill
	file.aimTrainerDynStats = dynStats
	file.aimTrainerReconBars = reconBars
	file.aimTrainerHighlight = highlight
	file.aimTrainerStraferFire = straferFire
	file.aimTrainerStraferAim = straferAim
	file.aimTrainerStrafeWidth = strafeWidth
	file.aimTrainerFixedSpawn = fixedSpawn
	file.aimTrainerStraferGod = straferGod
	if ( strafeSpeedTenth > 0 )
		file.aimTrainerStrafeSpeedTenth = strafeSpeedTenth
	if ( durationSec > 0 )
		file.aimTrainerDurationSec = durationSec
	if ( dummyShield >= 0 )
		file.aimTrainerDummyShield = dummyShield
	file.aimTrainerStraferBody = straferBody
	file.aimTrainerStraferLegendIdx = straferLegendIdx

	printt( format( "[AimTrainer] UI SyncDevMenu hit=%s shot=%s kill=%s dyn=%s bars=%s dur=%d god=%s speed=%d shield=%d body=%d legIdx=%d",
		string( hit ), string( shot ), string( kill ), string( dynStats ), string( reconBars ), durationSec, string( straferGod ), strafeSpeedTenth, dummyShield, straferBody, straferLegendIdx ) )

	LabTargets_SetState( hit, shot, kill, dynStats, reconBars, durationSec, straferGod, strafeSpeedTenth, dummyShield, straferBody, straferLegendIdx, highlight, straferFire, straferAim, strafeWidth, fixedSpawn )

	// Function-ref compare is unreliable -- refresh any open DevMenu page.
	if ( changed && GetActiveMenu() == GetMenu( "DevMenu" ) )
		UpdateDevMenuButtons()
}

bool function GetCheatsState()
{
	return file.cheatsState
}

bool function DevMenu_IsServerPlayer0()
{
	return file.isServerPlayer0
}


void function InitDevMenu( var newMenuArg )
{
	var menu = GetMenu( "DevMenu" )
	file.menu = menu
	file.header = Hud_GetChild( menu, "MenuTitle" )
	file.bg = Hud_GetChild( menu, "BlackBackground" )
	file.footerHelpTxtLabel = GetElementsByClassname( menu, "FooterHelpTxt" )[0]

	DevMenu_CaptureButtons()

	if ( !file.devMenuInited )
	{
		AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnOpenDevMenu )
		AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, BackOnePage_Activate )

		foreach ( button in file.buttons )
		{
			Hud_AddEventHandler( button, UIE_CLICK, OnDevButton_Activate )
			Hud_AddEventHandler( button, UIE_GET_FOCUS, OnDevButton_GetFocus )
			Hud_AddEventHandler( button, UIE_LOSE_FOCUS, OnDevButton_LoseFocus )
		}

		AddMenuFooterOption( menu, LEFT, BUTTON_B, true, "%[B_BUTTON|]% Back", "Back" )
		AddMenuFooterOption( menu, LEFT, BUTTON_Y, true, "%[Y_BUTTON|]% Repeat Last Dev Command:", "Repeat Last Dev Command:", RepeatLastCommand_Activate )
		AddMenuFooterOption( menu, LEFT, BUTTON_BACK, true, "%[BACK|]% Bind Selection to Gamepad", "", BindCommandToGamepad_Activate )

		RegisterSignal( "DEV_InitCodeDevMenu" )
		AddUICallback_LevelLoadingFinished( DEV_InitCodeDevMenu )
		AddUICallback_LevelShutdown( ClearCodeDevMenu )
		AddUICallback_OnResolutionChanged( DevMenu_OnResolutionChanged )

		file.devMenuInited = true
		thread DevHud_WatchMenus()
	}

	DevHud_RestoreIntent()
}

void function AddLevelDevCommand( string label, string command )
{
	string codeDevMenuAlias = DEV_MENU_NAME + "/" + label
	DevMenu_Alias_DEV( codeDevMenuAlias, command )

	DevCommand cmd
	cmd.label = label
	cmd.command = command
	file.levelSpecificCommands.append( cmd )
}

void function ServerCallback_OpenDevMenu()
{
	AdvanceMenu( GetMenu( "DevMenu" ) )
}

void function OnOpenDevMenu()
{
	file.pageHistory.clear()
	file.currentPage.devMenuFunc = null
	file.currentPage.devMenuFuncWithOpParm = null
	file.currentPage.devMenuOpParm = null
	file.lastDevCommandLabelInProgress = ""

	SetDevMenu_MP()

	DevHud_Apply()
}













void function DEV_InitCodeDevMenu()
{
	thread DEV_InitCodeDevMenu_Internal()
}


void function DEV_InitCodeDevMenu_Internal()
{
	Signal( uiGlobal.signalDummy, "DEV_InitCodeDevMenu" )
	EndSignal( uiGlobal.signalDummy, "DEV_InitCodeDevMenu" )

	while ( !IsFullyConnected() || !IsItemFlavorRegistrationFinished() )
	{
		WaitFrame()
	}

	file.initializingCodeDevMenu = true
	DevMenu_Alias_DEV( DEV_MENU_NAME, "" )
	DevMenu_Rm_DEV( DEV_MENU_NAME )
	OnOpenDevMenu()
	file.initializingCodeDevMenu = false

	// Freelance code-dev aliases only exist under DEVELOPER (sh_freelance.nut).
#if DEVELOPER
	if ( IsPVEMode() || FreelanceSystemsAreEnabled() )
		PopulateFreelanceDevMenu()
#endif
}


void function ClearCodeDevMenu()
{
	DevMenu_Alias_DEV( DEV_MENU_NAME, "" )
	DevMenu_Rm_DEV( DEV_MENU_NAME )

#if DEVELOPER
	ClearFreelanceDevMenu()
#endif
}


void function UpdateDevMenuButtons()
{
	if ( file.buildingDevMenu )
		return
	file.buildingDevMenu = true

	file.devCommands.clear()
	// Always populate when the menu is open (legacy: show menu even when cheats off).
	// Content is gated in SetupDefaultDevCommandsMP via GetCheatsState().

	if ( file.initializingCodeDevMenu )
	{
		file.buildingDevMenu = false
		return
	}

	DevMenu_CaptureButtons()

	
	{
		string titleText = file.lastDevCommandLabelInProgress
		if ( titleText == "" )
			titleText = ("Developer Menu    -    " + GetActiveLevel())
		Hud_SetText( file.header, titleText )
	}

	if ( file.currentPage.devMenuOpParm != null )
		file.currentPage.devMenuFuncWithOpParm( file.currentPage.devMenuOpParm )
	else
		file.currentPage.devMenuFunc()

	foreach ( index, button in file.buttons )
	{
		int buttonID = int( Hud_GetScriptID( button ) )

		if ( buttonID < file.devCommands.len() )
		{
			RuiSetString( Hud_GetRui( button ), "buttonText", file.devCommands[buttonID].label )
			Hud_SetEnabled( button, true )
		}
		else
		{
			RuiSetString( Hud_GetRui( button ), "buttonText", "" )
			Hud_SetEnabled( button, false )
		}

		if ( buttonID == 0 )
			Hud_SetFocused( button )
	}

	RefreshRepeatLastDevCommandPrompts()
	file.buildingDevMenu = false
}

void function SetDevMenu_MP()
{
	if ( file.initializingCodeDevMenu )
	{
		SetupDefaultDevCommandsMP()
		return
	}
	PushPageHistory()
	file.currentPage.devMenuFunc = SetupDefaultDevCommandsMP
	UpdateDevMenuButtons()
}


void function ChangeToThisMenu( void functionref() menuFunc )
{
	if ( file.initializingCodeDevMenu )
	{
		menuFunc()
		return
	}
	PushPageHistory()
	file.currentPage.devMenuFunc = menuFunc
	file.currentPage.devMenuFuncWithOpParm = null
	file.currentPage.devMenuOpParm = null
	UpdateDevMenuButtons()
}


void function ChangeToThisMenu_WithOpParm( void functionref( var ) menuFuncWithOpParm, opParm = null )
{
	if ( file.initializingCodeDevMenu )
	{
		menuFuncWithOpParm( opParm )
		return
	}

	PushPageHistory()
	file.currentPage.devMenuFunc = null
	file.currentPage.devMenuFuncWithOpParm = menuFuncWithOpParm
	file.currentPage.devMenuOpParm = opParm
	UpdateDevMenuButtons()
}

void function SetupDefaultDevCommandsMP()
{
	file.devCommands.clear()

	// Legacy: always open DevMenu; pull sv_cheats + player-0 seat from client.
	RunClientScript( "DEV_SendDevMenuStateToUI" )

	if ( !IsLobby() && ( GetCurrentPlaylistVarBool( "movement_recorder_enable", false ) || GetCheatsState() ) )
		SetupDevMenu( "Movement Recorder", SetDevMenu_MovementRecorder )

	if ( !GetCheatsState() )
	{
		SetupDevCommand( "Cheats are disabled! Type 'sv_cheats 1' in console to enable dev menu if you're the server admin.", "empty" )
		return
	}

	if ( IsLobby() )
		SetupDevCommand( "EZ Launch", "ezlaunch", true )

	if ( IsSurvivalMenuEnabled() )
	{
		SetupDevMenu( "Change Character", SetDevMenu_SurvivalCharacter )
		SetupDevMenu( "Weapons", SetDevMenu_FreeroamWeapons )
		//SetupDevMenu( "Override Spawn Character", SetDevMenu_OverrideSpawnSurvivalCharacter )
		SetupDevMenu( "Survival", SetDevMenu_Survival )
		SetupDevMenu( "Ammo", SetDevMenu_SurvivalLoot, "ammo" )
		SetupDevMenu( "Attachments", SetDevMenu_SurvivalLoot, "attachment" )
		SetupDevMenu( "Helmets", SetDevMenu_SurvivalLoot, "helmet" )
		SetupDevMenu( "Armor", SetDevMenu_SurvivalLoot, "armor" )
		SetupDevMenu( "Backpack", SetDevMenu_SurvivalLoot, "backpack" )
		SetupDevMenu( "Incap Shield", SetDevMenu_SurvivalLoot, "incapshield" )
		SetupDevMenu( "Ordnance", SetDevMenu_SurvivalLoot, "ordnance" )
		SetupDevMenu( "Health", SetDevMenu_SurvivalLoot, "health evo_pickup" )
		//SetupDevMenu( "Survival Incap Shield Debugging", SetDevMenu_SurvivalIncapShieldBots )

		string itemsString = "gadget data_knife marvin_arm custom_pickup"

		SetupDevMenu( "More Items", SetDevMenu_SurvivalLoot, itemsString )

		// SetupDevFunc( "Survival Loot Zone Preprocess", void function( var unused ) {
			// ConfirmDialogData data
			// data.headerText = "Run survival loot preprocess?"
			// data.messageText = ""
			// data.resultCallback = void function( int result ) {
				// if ( result == eDialogResult.YES )
				// {
					// Dev_CommandLineAddParm( "-survival_preprocess", "" )
					// ClientCommand( "reload" ) 
				// }
			// }
			// OpenConfirmDialogFromData( data )
		// } )

		// string cmdstr = "script " + GetActiveLevel().tolower()  + "_PathsPreprocess()"
		// SetupDevCommand( "Map Paths Preprocess (function must be defined)", cmdstr )
	}

	// if ( (GetConVarString( "mp_gamemode" ) == GAMEMODE_FREELANCE) )
		// SetupDevMenu( "Freelance", SetDevMenu_Freelance )

	SetupDevMenu( "Respawn Player(s)", SetDevMenu_RespawnPlayers )
	//SetupDevMenu( "Set Respawn Behaviour Override", SetDevMenu_RespawnOverride )
	//SetupDevMenu( "Narrative Debug", SetDevMenu_NarrativeDebug )
	//SetupDevMenu( "Victory Screen", SetDevMenu_VictorySceen )

	SetupDevCommand( "Recharge Abilities", "recharge" )
	SetupDevCommand( "Kill Self", "kill_self" )
	// Per-issuer skydive (legacy SkydiveTest hit every player).
	SetupDevCommand( "Start Skydive", "dev_aimtrainer skydive" )
	SetupDevMenu( "Spawn NPC at crosshair", SetDevMenu_SpawnNPC )
	// CreateFakePlayer at issuer crosshair (ClientCommand binds sender; never gp()[0]).
	SetupDevCommand( "Spawn Fake Player", "spawn_fake_player" )
	SetupDevCommand( "Spawn Fake Player Enemy", "spawn_fake_player enemy" )
	SetupDevMenu( "Flowstate Aim Trainer", SetDevMenu_FlowstateAimTrainer )
	if ( Flowstate_IsGame1v1Type() )
		SetupDevMenu( "Flowstate 1v1", SetDevMenu_Flowstate1v1 )
	SetupDevMenu( "Cafe Mods", SetDevMenu_CafeMods )
	SetupDevFunc( format( "NoClip: %s", DevMenu_OnOffLabel( file.devNoclip ) ), void function( var unused ) {
		ClientCommand( "noclip" )
		file.devNoclip = !file.devNoclip
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Infinite Ammo: %s", DevMenu_OnOffLabel( file.devInfiniteAmmo ) ), void function( var unused ) {
		ClientCommand( "infinite_ammo" )
		file.devInfiniteAmmo = !file.devInfiniteAmmo
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Auto Respawn: %s", DevMenu_OnOffLabel( file.devAutoRespawn ) ), void function( var unused ) {
		ClientCommand( "auto_respawn" )
		file.devAutoRespawn = !file.devAutoRespawn
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "God Mode: %s", DevMenu_OnOffLabel( file.devGodMode ) ), void function( var unused ) {
		ClientCommand( "demigod" )
		file.devGodMode = !file.devGodMode
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Third Person: %s", DevMenu_OnOffLabel( file.devThirdPerson ) ), void function( var unused ) {
		ClientCommand( "ToggleThirdPerson" )
		file.devThirdPerson = !file.devThirdPerson
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Dev Alert Msgs: %s", DevMenu_OnOffLabel( file.devAlertMsgs ) ), void function( var unused ) {
		ClientCommand( "toggle_dev_alerts" )
		file.devAlertMsgs = !file.devAlertMsgs
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Map Triggers: %s", DevMenu_OnOffLabel( file.devMapTriggers ) ), void function( var unused ) {
		ClientCommand( "toggle_map_triggers" )
		file.devMapTriggers = !file.devMapTriggers
		thread DevMenu_RefreshInPlace()
	} )

	
	
	


	//SetupDevCommand( "Toggle Model Viewer", "script thread ToggleModelViewer()" )
	//SetupDevCommand( "Toggle Outsource Viewer", "script_client ServerCallback_OVToggle()" )
	
	
	

	
	

	
	
	
	
	
	
	
	
	
	

	
	

	
	//SetupDevCommand( "DoF debug (ads)", "script_client ToggleDofDebug()" )

	

	
	

	

	
	

	

	// Global admin tool: player-0 seat only.
	if ( DevMenu_IsServerPlayer0() )
		SetupDevCommand( "Summon Players to player 0", "script summonplayers()" )

	//SetupDevCommand( "Max Activity (Pilots)", "script SetMaxActivityMode(1)" )
	
	
	//SetupDevCommand( "Max Activity (Disabled)", "script SetMaxActivityMode(0)" )

	SetupDevFunc( format( "Skybox View: %s", DevMenu_OnOffLabel( file.devSkyboxView ) ), void function( var unused ) {
		ClientCommand( "script thread ToggleSkyboxView()" )
		file.devSkyboxView = !file.devSkyboxView
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "HUD: %s", file.devHudHidden ? "HIDDEN" : "SHOWN" ), void function( var unused ) {
		DevHud_Toggle()
		thread DevMenu_RefreshInPlace()
	} )
	
	//SetupDevCommand( "Map Metrics Toggle", "script_client GetLocalClientPlayer().ClientCommand( \"toggle map_metrics 0 1 2 3\" )" )
	//SetupDevCommand( "Toggle Pain Death sound debug", "script TogglePainDeathDebug()" )
	//SetupDevCommand( "Jump Randomly Forever", "script_client thread JumpRandomlyForever()" )

	//SetupDevCommand( "Toggle Zeroing Mode", "script ToggleZeroingMode()" )
	//SetupDevCommand( "Toggle Screen Alignment Tool", "script_client DEV_ToggleScreenAlignmentTool()" )


	//SetupDevCommand( "[CRAFTING] Airdrop Replicator at Player", "script Crafting_AirdropWorkbenchAtPlayer(gp()[0])" )


	//SetupDevCommand( "[HOVER VEHICLE] Spawn Hover Vehicle At Player", "script HoverVehicle_CreateForPlayer(gp()[0])" )

	//SetupDevCommand( "[WEAPON MASTERY] Toggle Weapon Mastery Debug Window", "script_client DEV_ToggleWeaponMasteryDebugWindow()" )
	//SetupDevCommand( "[WEAPON MASTERY] Dump Weapon Mastery Info", "mastery_dump" )

	SetupDevMenu( "Prototypes", SetDevMenu_Prototypes )

	//SetupDevMenu_SeasonQuests()

#if DEVELOPER
	if ( IsLobby() )
		SetupDevMenu( "Override Menu Heirloom Models", SetDevMenu_OverrideMenuHeirloomModels )
#endif

	foreach ( DevCommand cmd in file.levelSpecificCommands )
		SetupDevCommand( cmd.label, cmd.command )
}

void function SetDevMenu_SpawnNPC( var _ )
{
	thread ChangeToThisMenu( SetupSpawnNPCDevMenu )
}

void function SetDevMenu_FlowstateAimTrainer( var _ )
{
	// Multiplayer-safe: clientcmd binds the issuer (not gp()[0]).
	ClientCommand( "dev_aimtrainer sync" )
	thread function()
	{
		wait 0.15
		ChangeToThisMenu( SetupFlowstateAimTrainerDevMenu )
	}()
}

void function SetDevMenu_MovementRecorder( var _ )
{
	thread ChangeToThisMenu( SetupMovementRecorderDevMenu )
}

void function MovementRecorder_UI_Open()
{
	CloseAllMenus()
	AdvanceMenu( GetMenu( "DevMenu" ) )
	thread function()
	{
		WaitFrame()
		WaitFrame()
		ChangeToThisMenu( SetupMovementRecorderDevMenu )
	}()
}

void function SetupMovementRecorderDevMenu()
{
	bool legacy = GetCurrentPlaylistVarBool( "movement_recorder_legacy_binds", false )
	SetupDevCommand( legacy ? "Start / Stop Recording  [F2]" : "Start / Stop Recording  [F4]", "mrec toggle" )
	SetupDevCommand( legacy ? "Play Last Recording  [F3-F7 = slots]" : "Play Last Recording  [F5]", "mrec play" )
	SetupDevCommand( "Play All Recordings", "mrec playall" )
	SetupDevCommand( "Stop Bots", "mrec stopall" )
	SetupDevCommand( "List Recordings", "mrec list" )
	SetupDevCommand( "Loop Playback: On", "mrec loop 1" )
	SetupDevCommand( "Loop Playback: Off", "mrec loop 0" )
	SetupDevCommand( "Clear All Recordings", "mrec clear all" )
	SetupDevCommand( ( legacy ? "F10" : "F3" ) + " opens this menu. Console: mrec <start|stop|play [n]|playall|stopall|clear [n|all]|list|loop 0|1>", "empty" )
}

void function SetDevMenu_Flowstate1v1( var _ )
{
	thread ChangeToThisMenu( SetupFlowstate1v1DevMenu )
}

void function SetupFlowstate1v1DevMenu()
{
	SetupDevCommand( "Rest / Unrest", "dev_1v1 rest" )
	SetupDevCommand( "Print Game States", "dev_1v1 states" )
	SetupDevCommand( "Print Legends", "dev_1v1 legends" )
	SetupDevCommand( "Accept Challenge", "dev_1v1 accept" )
	SetupDevCommand( "Dump All Challenges", "dev_1v1 chals" )
	SetupDevCommand( "Dump Accepted Challenges", "dev_1v1 accepted" )
	SetupDevCommand( "Next Round", "dev_1v1 next_round" )
	SetupDevCommand( "Champion Room", "dev_1v1 champion" )
	SetupDevCommand( "Stress: Spawn 10 Bots", "dev_1v1 stress spawn 10" )
	SetupDevCommand( "Stress: Spawn 60 Bots", "dev_1v1 stress spawn 60" )
	SetupDevCommand( "Stress: Start", "dev_1v1 stress start" )
	SetupDevCommand( "Stress: Status", "dev_1v1 stress status" )
	SetupDevCommand( "Stress: Stop", "dev_1v1 stress stop" )
	SetupDevCommand( "Stress: Kick All Bots", "dev_1v1 stress kick" )
}

void function SetDevMenu_CafeMods( var _ )
{
	ClientCommand( "cafemod sync" )
	thread function()
	{
		wait 0.15
		ChangeToThisMenu( SetupCafeModsDevMenu )
	}()
}

void function SetupCafeModsDevMenu()
{
	// First row: custom body overrides (not a CafeMod bitfield slot).
	string pmLabel = CafePlayerModel_UI_Label( file.cafePlayerModelId )
	SetupDevMenu( format( "Player Models: %s", pmLabel ), SetDevMenu_PlayerModels )

	int count = CafeMod_GetTotalCount()
	for ( int i = 0; i < count; i++ )
	{
		string id = CafeMod_GetId( i )
		if ( id == "" )
			continue
		// Items Weapon lives only under its own Setup submenu (not a root toggle row).
		if ( id == "items_weapon" )
			continue

		string name = CafeMod_GetName( i )
		bool on = CafeMod_IsBitSet( file.cafeModBits, i )

		SetupDevFunc( format( "%s: %s", name, DevMenu_OnOffLabel( on ) ), void function( var unused ) : ( i, id ) {
			if ( CafeMod_IsBitSet( file.cafeModBits, i ) )
				file.cafeModBits = file.cafeModBits & ~CafeMod_BitForIndex( i )
			else
				file.cafeModBits = file.cafeModBits | CafeMod_BitForIndex( i )
			ClientCommand( format( "cafemod toggle %s", id ) )
			thread DevMenu_RefreshInPlace()
		} )
	}

	SetupDevMenu( "Items Weapon", SetDevMenu_ItemsWeapon )
	// Parked: raygun is the only cafe port in this submenu.
	// SetupDevMenu( "Weapons Mods", SetDevMenu_WeaponsMods )

	// Dev cheats that belong next to Cafe mutators (not CafeMod bitfield).
	SetupDevFunc( format( "Infinite Abilities: %s", DevMenu_OnOffLabel( file.devInfiniteAbilities ) ), void function( var unused ) {
		bool next = !file.devInfiniteAbilities
		ClientCommand( format( "infinite_abilities %d", next ? 1 : 0 ) )
		file.devInfiniteAbilities = next
		thread DevMenu_RefreshInPlace()
	} )

	// Pull server bitfield so ON/OFF labels match dedi truth (not local optimistic flips).
	SetupDevCommand( "Sync Cafe Mods", "cafemod sync" )
	SetupDevCommand( "Disable All Cafe Mods", "cafemod disable_all" )
}

// Cafe port weapons not in ItemFlavor -- same give shape as Dev Menu > Weapons.
void function SetDevMenu_WeaponsMods( var _ )
{
	thread ChangeToThisMenu( SetupWeaponsModsDevMenu )
}

void function SetupWeaponsModsDevMenu()
{
	// Parked: raygun models not packed. Restore when RAYGUN_PACK is True.
	// WeaponsMods_AddWeapon( "Ray Gun", "mp_weapon_raygun" )
}

void function WeaponsMods_AddWeapon( string display, string classname )
{
	SetupDevMenu( display, void function( var unused ) : ( classname, display ) {
		string payload = classname + "|" + display
		thread ChangeToThisMenu( void function() : ( payload ) {
			SetupWeaponsModsWeapon( payload )
		} )
	} )
}

void function SetupWeaponsModsWeapon( var payloadVar )
{
	string payload = string( payloadVar )
	var parts = split( payload, "|" )
	string classname = parts.len() > 0 ? string( parts[0] ) : ""

	// Freeform give -- no loot kits / ItemFlavor for cafe-only ports.
	SetupDevCommand( "Primary Slot 0",
		format( "CC_MenuGiveAimTrainerWeapon free 0 %s", classname ) )
	SetupDevCommand( "Primary Slot 1",
		format( "CC_MenuGiveAimTrainerWeapon free 1 %s", classname ) )
}

string function CafePlayerModel_UI_Label( string id )
{
	if ( id == "amogus" )
		return "Amogus"
	if ( id == "pete" )
		return "Pete"
	return "Default"
}

void function SetDevMenu_PlayerModels( var _ )
{
	thread ChangeToThisMenu( SetupPlayerModelsDevMenu )
}

void function SetupPlayerModelsDevMenu()
{
	// Issuer-bound body override (server cafeplayermodel). Marks current UI selection.
	CafePlayerModel_UI_AddPick( "Amogus", "amogus" )
	CafePlayerModel_UI_AddPick( "Pete", "pete" )
	CafePlayerModel_UI_AddPick( "Default (clear override)", "clear" )
}

void function CafePlayerModel_UI_AddPick( string label, string id )
{
	bool selected = false
	if ( id == "clear" )
		selected = ( file.cafePlayerModelId == "default" || file.cafePlayerModelId == "clear" )
	else
		selected = ( file.cafePlayerModelId == id )
	string mark = selected ? " *" : ""

	SetupDevFunc( format( "%s%s", label, mark ), void function( var unused ) : ( id ) {
		if ( id == "clear" )
			file.cafePlayerModelId = "default"
		else
			file.cafePlayerModelId = id
		ClientCommand( format( "cafeplayermodel %s", id ) )
		thread DevMenu_RefreshInPlace()
	} )
}

void function SetDevMenu_ItemsWeapon( var _ )
{
	ClientCommand( "cafeitems sync" )
	ClientCommand( "cafemod sync" )
	thread function()
	{
		wait 0.15
		ChangeToThisMenu( SetupItemsWeaponDevMenu )
	}()
}

void function SetupItemsWeaponDevMenu()
{
	// No global ON/OFF -- profile binds to the next weapon you Give (per weapon entity).
	string profileName = CafeItems_GetName( file.cafeItemsProfile )
	if ( profileName == "" )
		profileName = "?"

	SetupDevFunc( format( "Physics Mode: %s", DevMenu_OnOffLabel( file.cafeItemsPhysics ) ), void function( var unused ) {
		file.cafeItemsPhysics = !file.cafeItemsPhysics
		ClientCommand( format( "cafeitems physics %s", file.cafeItemsPhysics ? "1" : "0" ) )
		thread DevMenu_RefreshInPlace()
	} )

	SetupDevMenu( format( "Select Model: %s", profileName ), SetDevMenu_ItemsWeaponProfiles )

	// Arms stamp_next then opens freeroam catalog (tier/class/weapon/slot).
	// The granted weapon entity gets this menu's profile + physics only.
	SetupDevMenu( "Give Weapon (stamp profile)", SetDevMenu_ItemsWeaponGive )
}

void function SetDevMenu_ItemsWeaponProfiles( var _ )
{
	thread ChangeToThisMenu( SetupItemsWeaponProfilesMenu )
}

void function SetupItemsWeaponProfilesMenu()
{
	int count = CafeItems_GetCount()
	for ( int i = 0; i < count; i++ )
	{
		string id = CafeItems_GetId( i )
		string name = CafeItems_GetName( i )
		bool selected = ( file.cafeItemsProfile == i )
		string mark = selected ? " *" : ""

		SetupDevFunc( format( "%s%s", name, mark ), void function( var unused ) : ( i, id ) {
			file.cafeItemsProfile = i
			ClientCommand( format( "cafeitems set %s", id ) )
			thread DevMenu_RefreshInPlace()
		} )
	}
}

void function SetDevMenu_ItemsWeaponGive( var _ )
{
	// Next freeroam give stamps pending profile onto that weapon only.
	ClientCommand( "cafeitems stamp_next" )
	thread ChangeToThisMenu( FreeroamWeaponsMenu_SetupRoot )
}



void function SetupSpawnNPCDevMenu()
{
	// Dummy only. Other DEV spawn entries need map/class precache; use Aim Trainer for sandbag / FR dummies.
	// dev_aimtrainer binds the issuer -- never script + gp()[0] (wrong player in MP).
	SetupDevCommand( "Spawn NPC: Dummy", "dev_aimtrainer dummy" )
}

void function SetDevMenu_FreeroamWeapons( var _ )
{
	thread ChangeToThisMenu( FreeroamWeaponsMenu_SetupRoot )
}

string function DevMenu_OnOffLabel( bool on )
{
	return on ? "ON" : "OFF"
}

bool function DevHud_IsHidden()
{
	return file.devHudHidden
}

void function DevHud_Toggle()
{
	DevHud_SetHidden( !file.devHudHidden )
}

void function DevHud_SetHidden( bool hidden )
{
	file.devHudHidden = hidden
	if ( CanRunClientScript() )
		RunClientScript( "DevHud_ClientSet", hidden )
	DevHud_Apply()
}

void function DevHud_RestoreIntent()
{
}

// The hide itself lives on the server (cinematic HUD flags on the player), so
// it survives menus, respawns and map changes; this only re-sends the intent.
void function DevHud_Apply()
{
	if ( CanRunClientScript() )
		RunClientScript( "DevHud_ClientSet", file.devHudHidden )
}

void function DevHud_WatchMenus()
{
	DevHud_Apply()
	for ( ; ; )
	{
		WaitSignal( uiGlobal.signalDummy, "ActiveMenuChanged" )
		DevHud_Apply()
	}
}

void function DevMenu_OnResolutionChanged()
{
	DevHud_RestoreIntent()
	DevHud_Apply()
	if ( file.menu != null && GetActiveMenu() == file.menu )
		UpdateDevMenuButtons()
}

void function DevMenu_CaptureButtons()
{
	if ( file.menu == null )
		return

	array<var> raw = GetElementsByClassname( file.menu, "DevButtonClass" )
	file.buttons.clear()

	array<int> seenIds
	foreach ( button in raw )
	{
		int id = int( Hud_GetScriptID( button ) )
		if ( seenIds.contains( id ) )
		{
			RuiSetString( Hud_GetRui( button ), "buttonText", "" )
			Hud_SetEnabled( button, false )
			continue
		}

		seenIds.append( id )
		file.buttons.append( button )
		RuiSetString( Hud_GetRui( button ), "buttonText", "" )
		Hud_SetEnabled( button, false )
	}
}

// Rebuild the current page labels without pushing history (same-page toggles).
void function DevMenu_RefreshInPlace()
{
	WaitFrame()
	UpdateDevMenuButtons()
}

void function SetupFlowstateAimTrainerDevMenu()
{
	// All actions: ClientCommand "dev_aimtrainer <action>" -- server uses the issuer.
	SetupDevCommand( "Sand Bag Dummy", "dev_aimtrainer sandbag" )
	SetupDevCommand( "Strafer Dummy", "dev_aimtrainer flowstate_auto" )
	SetupDevCommand( "Strafer Dummy Fast", "dev_aimtrainer flowstate_hard_auto" )
	SetupDevCommand( "Aim Freeroam: Target Switch", "dev_aimtrainer ts" )
	SetupDevCommand( "Aim Freeroam: Popcorn", "dev_aimtrainer popcorn" )

	string durationLabel
	if ( file.aimTrainerDurationSec == 999 )
		durationLabel = "Challenge Duration: Unlimited"
	else
		durationLabel = format( "Challenge Duration: %ds", file.aimTrainerDurationSec )
	SetupDevMenu( durationLabel, SetDevMenu_AimTrainerDuration )
	SetupDevMenu( "Dummy Armor: " + AimTrainerDummyShieldLabel( file.aimTrainerDummyShield ), SetDevMenu_AimTrainerArmor )
	SetupDevCommand( "Start Manual Challenge", "dev_aimtrainer start" )
	SetupDevCommand( "Stop Challenge", "dev_aimtrainer stop" )

	// Optimistic flip for instant label; server SyncDevMenuState confirms truth.
	SetupDevFunc( format( "AutoReload on Hit: %s", DevMenu_OnOffLabel( file.aimTrainerReloadHit ) ), void function( var unused ) {
		file.aimTrainerReloadHit = !file.aimTrainerReloadHit
		ClientCommand( "dev_aimtrainer reload_hit" )
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "AutoReload on Shot: %s", DevMenu_OnOffLabel( file.aimTrainerReloadShot ) ), void function( var unused ) {
		file.aimTrainerReloadShot = !file.aimTrainerReloadShot
		ClientCommand( "dev_aimtrainer reload_shot" )
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "AutoReload on Kill: %s", DevMenu_OnOffLabel( file.aimTrainerReloadKill ) ), void function( var unused ) {
		file.aimTrainerReloadKill = !file.aimTrainerReloadKill
		ClientCommand( "dev_aimtrainer reload_kill" )
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Dynamic Stats HUD: %s", DevMenu_OnOffLabel( file.aimTrainerDynStats ) ), void function( var unused ) {
		file.aimTrainerDynStats = !file.aimTrainerDynStats
		ClientCommand( "dev_aimtrainer dynstats" )
		thread DevMenu_RefreshInPlace()
	} )
	SetupDevFunc( format( "Recon Health Bars: %s", DevMenu_OnOffLabel( file.aimTrainerReconBars ) ), void function( var unused ) {
		file.aimTrainerReconBars = !file.aimTrainerReconBars
		ClientCommand( "dev_aimtrainer healthbars" )
		thread DevMenu_RefreshInPlace()
	} )

	SetupDevCommand( "Quit Aimtrainer", "dev_aimtrainer quit" )
}

void function SetDevMenu_AimTrainerDuration( var _ )
{
	thread ChangeToThisMenu( SetupAimTrainerDurationMenu )
}

void function SetupAimTrainerDurationMenu()
{
	array<int> durations = [ 30, 60, 90, 120, 999 ]
	foreach ( int d in durations )
	{
		string mark = ( d == file.aimTrainerDurationSec ) ? " *" : ""
		string label
		if ( d == 999 )
			label = "Unlimited" + mark
		else if ( d == 60 )
			label = "60s (default)" + mark
		else
			label = format( "%ds%s", d, mark )

		SetupDevFunc( label, void function( var unused ) : ( d ) {
			ClientCommand( format( "dev_aimtrainer duration %d", d ) )
			file.aimTrainerDurationSec = d
			// Server also syncs; return to parent with updated duration label.
			thread ChangeToThisMenu( SetupFlowstateAimTrainerDevMenu )
		} )
	}
}

string function AimTrainerDummyShieldLabel( int setting )
{
	switch ( setting )
	{
		case 1:
			return "White"
		case 2:
			return "Blue"
		case 3:
			return "Purple"
		case 4:
			return "Red"
		case 10:
			return "Random"
	}
	return "White (default)"
}

void function SetDevMenu_AimTrainerArmor( var _ )
{
	thread ChangeToThisMenu( SetupAimTrainerArmorMenu )
}

void function SetupAimTrainerArmorMenu()
{
	array<int> settings = [ 1, 2, 3, 4, 10 ]
	foreach ( int s in settings )
	{
		string mark = ( s == file.aimTrainerDummyShield ) ? " *" : ""
		string label = AimTrainerDummyShieldLabel( s ) + mark

		SetupDevFunc( label, void function( var unused ) : ( s ) {
			ClientCommand( format( "dev_aimtrainer armor %d", s ) )
			file.aimTrainerDummyShield = s
			// Server also syncs; return to parent with updated armor label.
			thread ChangeToThisMenu( SetupFlowstateAimTrainerDevMenu )
		} )
	}
}


void function SetDevMenu_LevelCommands( var _ )
{
	ChangeToThisMenu( SetupLevelDevCommands )
}


void function SetupLevelDevCommands()
{
	string activeLevel = GetActiveLevel()
	if ( activeLevel == "" )
		return

	switch ( activeLevel )
	{
		case "model_viewer":
			SetupDevCommand( "Toggle Rebreather Masks", "script ToggleRebreatherMasks()" )
			break
	}
}


void function SetDevMenu_SurvivalCharacter( var _ )
{
	thread ChangeToThisMenu( SetupChangeSurvivalCharacterClass )
}

void function DEV_InitLoadoutDevSubMenu()
{
	return
}


void function SetDevMenu_AlterLoadout( var _ )
{
	return
}

// Alter Loadout is disabled. The apply path stays in sh_loadouts for engine
// callers, but no menu reaches it.
void function SetupAlterLoadout()
{
	return
}

void function SetupAlterLoadout_CategoryScreen( string category )
{
	return
}

void function SetupAlterLoadout_CategoryScreenForCharacter( string category, string character )
{
	return
}

string function GetCharacterNameFromDEV_name( string DEV_name )
{
	string prefix = "character_"
	return split( DEV_name.slice( prefix.len() ), WHITESPACE_CHARACTERS )[ 0 ]
}

void function SetupAlterLoadout_SlotScreen( LoadoutEntry entry, int qualityFilter = -99 )
{
	return
}

void function DevMenu_ToggleBG()
{
	if ( Hud_IsVisible( file.bg ) )
	{
		Hud_Hide( file.bg )
	}
	else
	{
		Hud_Show( file.bg )
	}
}

void function SetDevMenu_OverrideSpawnSurvivalCharacter( var _ )
{
	thread ChangeToThisMenu( SetupOverrideSpawnSurvivalCharacter )
}


void function SetDevMenu_Survival( var _ )
{
	thread ChangeToThisMenu( SetupSurvival )
}


void function SetDevMenu_SurvivalLoot( var categories )
{
	thread ChangeToThisMenu_WithOpParm( SetupSurvivalLoot, categories )
}


void function SetDevMenu_SurvivalIncapShieldBots( var _ )
{
	thread ChangeToThisMenu( SetupSurvivalIncapShieldBot )
}



void function ChangeToThisMenu_PrecacheWeapons( void functionref() menuFunc )
{
	if ( file.initializingCodeDevMenu )
	{
		menuFunc()
		return
	}

	waitthread PrecacheWeaponsIfNecessary()

	PushPageHistory()
	file.currentPage.devMenuFunc = menuFunc
	file.currentPage.devMenuFuncWithOpParm = null
	file.currentPage.devMenuOpParm = null
	UpdateDevMenuButtons()
}


void function ChangeToThisMenu_PrecacheWeapons_WithOpParm( void functionref( var ) menuFuncWithOpParm, opParm = null )
{
	if ( file.initializingCodeDevMenu )
	{
		menuFuncWithOpParm( opParm )
		return
	}

	waitthread PrecacheWeaponsIfNecessary()

	PushPageHistory()
	file.currentPage.devMenuFunc = null
	file.currentPage.devMenuFuncWithOpParm = menuFuncWithOpParm
	file.currentPage.devMenuOpParm = opParm
	UpdateDevMenuButtons()
}


void function PrecacheWeaponsIfNecessary()
{
	if ( file.precachedWeapons )
		return

	file.precachedWeapons = true
	CloseAllMenus()

	DisablePrecacheErrors()
	wait 0.1
	ClientCommand( "script PrecacheSPWeapons()" )
	wait 0.1
	ClientCommand( "script_client PrecacheSPWeapons()" )
	wait 0.1
	RestorePrecacheErrors()

	AdvanceMenu( GetMenu( "DevMenu" ) )
}


void function UpdatePrecachedSPWeapons()
{
	file.precachedWeapons = true
}

void function SetDevMenu_RespawnPlayers( var _ )
{
	ChangeToThisMenu( SetupRespawnPlayersDevMenu )
}


void function SetupRespawnPlayersDevMenu()
{
	// Always available to the issuer.
	SetupDevCommand( "Respawn me", "respawn" )

	// Mass / team / bot respawns: player-0 seat only (global admin tools).
	if ( !DevMenu_IsServerPlayer0() )
		return

	SetupDevCommand( "Respawn all players", "respawn all" )
	SetupDevCommand( "Respawn all dead players", "respawn alldead" )
	SetupDevCommand( "Respawn random player", "respawn random" )
	SetupDevCommand( "Respawn random dead player", "respawn randomdead" )
	SetupDevCommand( "Respawn bots", "respawn bots" )
	SetupDevCommand( "Respawn dead bots", "respawn deadbots" )
	SetupDevCommand( "Respawn my teammates", "respawn allies" )
	SetupDevCommand( "Respawn my enemies", "respawn enemies" )
}


void function SetDevMenu_RespawnOverride( var _ )
{
	ChangeToThisMenu( SetupRespawnOverrideDevMenu )
}

void function SetDevMenu_NarrativeDebug ( var _ )
{
	ChangeToThisMenu( SetupNarrativeDebugDevMenu )
}

void function SetupNarrativeDebugDevMenu()
{
	SetupDevMenu( "Dynamic Dialogue Debug", SetDevMenu_DynamicDialogueDebug )
}

void function SetDevMenu_VictorySceen( var _ )
{
	ChangeToThisMenu( SetupVictoryScreenDebugDevMenu )
}

void function SetupVictoryScreenDebugDevMenu()
{
	SetupDevCommand("Show Victory Sequence", "script_client Dev_ShowVictorySequence()")
	SetupDevCommand("No Clip To Podium (New Podium Only)", "noclip; script DEV_TeleportToPodium(gp()[0])")
	SetupDevMenu( "Override Podium Background Debug Menu", SetDevMenu_PodiumBackgroundDebug )
	SetupDevMenu( "Override Base Background Debug Menu", SetDevMenu_PodiumBaseDebug )
	SetupDevMenu( "Override Banner Background Debug Menu", SetDevMenu_PodiumBannerDebug )
}

void function SetDevMenu_PodiumBackgroundDebug( var _ )
{
	ChangeToThisMenu( SetupPodiumBackgroundDebug )
}

void function SetupPodiumBackgroundDebug()
{
	SetupDevCommand("MP_RR_DESERTLANDS_HU", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_DESERTLANDS_HU )")
	SetupDevCommand("MP_RR_DIVIDED_MOON", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_DIVIDED_MOON )")
	SetupDevCommand("MP_RR_CANYONLANDS_HU", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_CANYONLANDS_HU )")
	SetupDevCommand("MP_RR_OLYMPUS_MU2", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_OLYMPUS_MU2 )")
	SetupDevCommand("MP_RR_TROPICS_ISLAND_MU1", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_TROPICS_ISLAND_MU1 )")
	SetupDevCommand("MP_RR_ADQUEDUCT", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_ADQUEDUCT )")
	SetupDevCommand("MP_RR_ARENA_HABITAT", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_ARENA_HABITAT )")
	SetupDevCommand("MP_RR_PARTY_CRASHER", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_PARTY_CRASHER )")
	SetupDevCommand("MP_RR_ARENA_PHASE_RUNNER", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_ARENA_PHASE_RUNNER )")
	SetupDevCommand("MP_RR_FREEDM_SKULLTOWN", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_FREEDM_SKULLTOWN )")
	SetupDevCommand("MP_RR_ARENA_SKYGARDER", "script DEV_OverridePodiumBackground( ePodiumBackground.MP_RR_ARENA_SKYGARDER )")
}

void function SetDevMenu_PodiumBaseDebug( var _ )
{
	ChangeToThisMenu( SetupPodiumBaseDebug )
}

void function SetupPodiumBaseDebug()
{
	SetupDevCommand("BR", "script DEV_OverridePodiumBase( ePodiumBanner.NORMAL )")
	SetupDevCommand("BR - Black & Gold", "script DEV_OverridePodiumBase( ePodiumBanner.ANNIVERSARY )")
	SetupDevCommand("FREEDM", "script DEV_OverridePodiumBase( ePodiumBanner.FREEDM )")
	SetupDevCommand("CONTROL", "script DEV_OverridePodiumBase( ePodiumBanner.CONTROL )")
	SetupDevCommand("LTM", "script DEV_OverridePodiumBase( ePodiumBanner.LTM )")
}

void function SetDevMenu_PodiumBannerDebug( var _ )
{
	ChangeToThisMenu( SetupPodiumBannerDebug )
}

void function SetupPodiumBannerDebug()
{
	SetupDevCommand("BR", "script DEV_OverridePodiumBanners( ePodiumBanner.NORMAL )")
	SetupDevCommand("BR - Black & Gold", "script DEV_OverridePodiumBanners( ePodiumBanner.ANNIVERSARY )")
	SetupDevCommand("FREEDM", "script DEV_OverridePodiumBanners( ePodiumBanner.FREEDM )")
	SetupDevCommand("CONTROL", "script DEV_OverridePodiumBanners( ePodiumBanner.CONTROL )")
	SetupDevCommand("LTM", "script DEV_OverridePodiumBanners( ePodiumBanner.LTM )")
}


void function SetDevMenu_DynamicDialogueDebug( var _ )
{
	ChangeToThisMenu( SetupDynamicDialogueDebug )
}

void function SetupDynamicDialogueDebug()
{
	array<AmbientConversationData> convos = clone GetAllAmbientDialogue()
	foreach (AmbientConversationData convo in convos)
	{
		string command = "script DEV_SetupForAmbientConversation(\"" + GetPlayerUID() + "\", \"" + convo.convoName + "\")"
		SetupDevCommand("Set up for: " + convo.convoName, command)
	}
}

void function SetupRespawnOverrideDevMenu()
{
	SetupDevCommand( "Use gamemode behaviour", "set_respawn_override off" )
	SetupDevCommand( "Override: Allow all respawning", "set_respawn_override allow" )
	SetupDevCommand( "Override: Deny all respawning", "set_respawn_override deny" )
	SetupDevCommand( "Override: Allow bot respawning", "set_respawn_override allowbots" )
}


void function SetDevMenu_ThreatTracker( var _ )
{
	ChangeToThisMenu( SetupThreatTrackerDevMenu )
}


void function SetupThreatTrackerDevMenu()
{
	SetupDevCommand( "Reload Threat Data", "fs_report_sync_opens 0; script ReloadScripts(); script ThreatTracker_ReloadThreatData()" )
	SetupDevCommand( "Threat Tracking ON", "script ThreatTracker_SetActive( true )" )
	SetupDevCommand( "Threat Tracking OFF", "script ThreatTracker_SetActive( false )" )
	SetupDevCommand( "Overhead Debug ON", "script ThreatTracker_DrawDebugOverheadText( true )" )
	SetupDevCommand( "Overhead Debug OFF", "script ThreatTracker_DrawDebugOverheadText( false )" )
	SetupDevCommand( "Console Debug Level 0", "script ThreatTracker_SetDebugLevel( 0 )" )
	SetupDevCommand( "Console Debug Level 1", "script ThreatTracker_SetDebugLevel( 1 )" )
	SetupDevCommand( "Console Debug Level 2", "script ThreatTracker_SetDebugLevel( 2 )" )
	SetupDevCommand( "Console Debug Level 3", "script ThreatTracker_SetDebugLevel( 3 )" )
}


void function SetDevMenu_HighVisNPCTest( var _ )
{
	ChangeToThisMenu( SetupHighVisNPCTest )
}


void function SetupHighVisNPCTest()
{
	SetupDevCommand( "Spawn at Crosshair", "script PROTO_SpawnHighVisNPCs()" )
	SetupDevCommand( "Delete Test NPCs", "script PROTO_DeleteHighVisNPCs()" )
	SetupDevCommand( "Use R5 Art Settings", "script PROTO_HighVisNPCs_SetTestEnv( \"r5\" )" )
	SetupDevCommand( "Use R2 Art Settings", "script PROTO_HighVisNPCs_SetTestEnv( \"r2\" )" )
}

void function SetDevMenu_Prototypes( var _ )
{
	thread ChangeToThisMenu( SetupPrototypesDevMenu )
}








void function SetDevMenu_Freelance( var _ )
{
	thread ChangeToThisMenu( SetupFreelanceDevMenu )
}


void function SetupFreelanceDevMenu()
{
	SetupDevCommand( "Spawn MatchCandy", "script DEV_SpawnCandyAtCrosshair()" )
	
}

void function SetupPrototypesDevMenu()
{

		SetupDevCommand( "Change to Shadow Zombie", "script DEV_GiveShadowZombieAbilities( gp()[0] )" )

}


void function RunCodeDevCommandByAlias( string alias )
{
	RunDevCommand( file.codeDevMenuCommands[alias], false )
}


void function SetupDevCommand( string label, string command, bool canBeUsedInMatchmaking = false )
{
	DevCommand cmd
	cmd.label = label
	cmd.command = command
	cmd.canBeUsedInMatchmaking = canBeUsedInMatchmaking

	file.devCommands.append( cmd )
	if ( file.initializingCodeDevMenu )
	{
		string codeDevMenuAlias = file.codeDevMenuPrefix + label
		DevMenu_Alias_DEV( codeDevMenuAlias, command )
	}
}


void function SetupDevFunc( string label, void functionref( var ) func, var opParm = null )
{
	DevCommand cmd
	cmd.label = label
	cmd.func = func
	cmd.opParm = opParm

	file.devCommands.append( cmd )
	if ( file.initializingCodeDevMenu )
	{
		string codeDevMenuAlias   = file.codeDevMenuPrefix + label
		string codeDevMenuCommand = format( "script_ui RunCodeDevCommandByAlias( \"%s\" )", codeDevMenuAlias )
		file.codeDevMenuCommands[codeDevMenuAlias] <- cmd
		DevMenu_Alias_DEV( codeDevMenuAlias, codeDevMenuCommand )
	}
}


void function SetupDevMenu( string label, void functionref( var ) func, var opParm = null )
{
	DevCommand cmd
	cmd.label = (label + "  ->")
	cmd.func = func
	cmd.opParm = opParm
	cmd.isAMenuCommand = true

	file.devCommands.append( cmd )

	if ( file.initializingCodeDevMenu )
	{
		string codeDevMenuPrefix = file.codeDevMenuPrefix
		file.codeDevMenuPrefix += label + "/"
		cmd.func( cmd.opParm )
		file.codeDevMenuPrefix = codeDevMenuPrefix
	}
}


void function OnDevButton_Activate( var button )
{
	int buttonID   = int( Hud_GetScriptID( button ) )
	DevCommand cmd = file.devCommands[buttonID]

	if ( cmd.canBeUsedInMatchmaking == false && level.ui.uiDisableDev )
	{
		Warning( "Dev commands disabled on matchmaking servers." )
		return
	}

	RunDevCommand( cmd, false )
}


void function OnDevButton_GetFocus( var button )
{
	file.focusedCmdIsAssigned = false

	int buttonID = int( Hud_GetScriptID( button ) )
	if ( buttonID >= file.devCommands.len() )
		return

	if ( file.devCommands[buttonID].isAMenuCommand )
		return

	file.focusedCmd = file.devCommands[buttonID]
	file.focusedCmdIsAssigned = true
}


void function OnDevButton_LoseFocus( var button )
{
}


void function RunDevCommand( DevCommand cmd, bool isARepeat )
{
	if ( !isARepeat )
	{
		if ( file.lastDevCommandLabelInProgress.len() > 0 )
			file.lastDevCommandLabelInProgress += "  "
		file.lastDevCommandLabelInProgress += cmd.label

		if ( !cmd.isAMenuCommand )
		{
			file.lastDevCommand = cmd
			file.lastDevCommandAssigned = true
			file.lastDevCommandLabel = file.lastDevCommandLabelInProgress
		}
	}

	if ( cmd.command != "" )
	{
		ClientCommand( cmd.command )
		if ( IsLobby() )
		{
			CloseAllMenus()
			AdvanceMenu( GetMenu( "LobbyMenu" ) )
		}
		else
		{
			CloseAllMenus()
		}
	}
	else
	{
		cmd.func( cmd.opParm )
	}
}


void function RepeatLastDevCommand( var _ )
{
	if ( !file.lastDevCommandAssigned )
		return

	RunDevCommand( file.lastDevCommand, true )
}


void function RepeatLastCommand_Activate( var button )
{
	RepeatLastDevCommand( null )
}


void function PushPageHistory()
{
	DevMenuPage page = file.currentPage
	if ( page.devMenuFunc != null || page.devMenuFuncWithOpParm != null )
		file.pageHistory.push( clone page )
}


void function BackOnePage_Activate()
{
	if ( file.pageHistory.len() == 0 )
	{
		CloseActiveMenu()
		return
	}

	file.currentPage = file.pageHistory.pop()
	UpdateDevMenuButtons()
}


void function RefreshRepeatLastDevCommandPrompts()
{
	string newText = ""
	
	{
		if ( file.lastDevCommandAssigned )
			newText = file.lastDevCommandLabel    
		else
			newText = "<none>"
	}

	if ( AreOnDefaultDevCommandMenu() )
		file.lastDevCommandLabelInProgress = ""

	Hud_SetText( file.footerHelpTxtLabel, newText )
}


bool function AreOnDefaultDevCommandMenu()
{
	if ( file.currentPage.devMenuFunc == SetupDefaultDevCommandsMP )
		return true

	return false
}


void function BindCommandToGamepad_Activate( var button )
{
	if ( !BindCommandToGamepad_ShouldShow() )
		return

	
	{
		string cmdText = "bind back \"script_ui DEV_ExecBoundDevMenuCommand()\""
		ClientCommand( cmdText )
	}

	file.boundCmd.command = file.focusedCmd.command
	file.boundCmd.isAMenuCommand = file.focusedCmd.isAMenuCommand
	file.boundCmd.label = file.focusedCmd.label
	file.boundCmd.func = file.focusedCmd.func
	file.boundCmd.opParm = file.focusedCmd.opParm
	file.boundCmdIsAssigned = true

	
	{
		string fullName = ""
		if ( file.lastDevCommandLabelInProgress.len() > 0 )
			fullName = file.lastDevCommandLabelInProgress + " -> "
		fullName += file.focusedCmd.label

		string prompt = "Bound to gamepad BACK: " + fullName
		printt( prompt )
		
		
		EmitUISound( "wpn_pickup_titanweapon_1p" )
	}

	CloseAllMenus()
}


bool function BindCommandToGamepad_ShouldShow()
{
	if ( !file.focusedCmdIsAssigned )
		return false
	if ( file.focusedCmd.command.len() == 0 )
		return false
	return true
}


void function DEV_ExecBoundDevMenuCommand()
{
	if ( !file.boundCmdIsAssigned )
		return

	RunDevCommand( file.boundCmd, true )
}

// ---------------------------------------------------------------------------
// Survival DevMenu helpers â€” always in this file (legacy R5VLibrary pattern).
// Do not rely on DEV-gated rson loads for these symbols.
// ---------------------------------------------------------------------------

void function SetupChangeSurvivalCharacterClass()
{
	array<ItemFlavor> characters = clone GetAllCharacters()
	foreach ( ItemFlavor character in characters )
	{
		string ref = ItemFlavor_GetCharacterRef( character )
		if ( HIDDEN_CHARACTER_REFS.len() > 0 && HIDDEN_CHARACTER_REFS.contains( ref ) )
			characters.fastremovebyvalue( character )
	}
	characters.sort( int function( ItemFlavor a, ItemFlavor b ) {
		if ( Localize( ItemFlavor_GetLongName( a ) ) < Localize( ItemFlavor_GetLongName( b ) ) )
			return -1
		if ( Localize( ItemFlavor_GetLongName( a ) ) > Localize( ItemFlavor_GetLongName( b ) ) )
			return 1
		return 0
	} )
	foreach ( ItemFlavor character in characters )
	{
		SetupDevFunc( Localize( ItemFlavor_GetLongName( character ) ), void function( var unused ) : ( character ) {
			DEV_RequestSetItemFlavorLoadoutSlot( LocalClientEHI(), Loadout_Character(), character )
		} )
	}
}

void function SetupOverrideSpawnSurvivalCharacter()
{
	SetupDevCommand( "Random (default)", "dev_sur_force_spawn_character random" )
	SetupDevCommand( "Shipping only", "dev_sur_force_spawn_character special" )
	array<ItemFlavor> characters = clone GetAllCharacters()
	foreach ( ItemFlavor character in characters )
	{
		string ref = ItemFlavor_GetCharacterRef( character )
		if ( HIDDEN_CHARACTER_REFS.len() > 0 && HIDDEN_CHARACTER_REFS.contains( ref ) )
			characters.fastremovebyvalue( character )
	}
	characters.sort( int function( ItemFlavor a, ItemFlavor b ) {
		if ( Localize( ItemFlavor_GetLongName( a ) ) < Localize( ItemFlavor_GetLongName( b ) ) )
			return -1
		if ( Localize( ItemFlavor_GetLongName( a ) ) > Localize( ItemFlavor_GetLongName( b ) ) )
			return 1
		return 0
	} )
	foreach ( ItemFlavor characterClass in characters )
	{
		SetupDevCommand( Localize( ItemFlavor_GetLongName( characterClass ) ), "dev_sur_force_spawn_character " + ItemFlavor_GetCharacterRef( characterClass ) )
	}
}

void function SetupSurvival()
{
	SetupDevCommand( "Toggle Training Completed", "script GetPlayerArray()[0].SetPersistentVar( \"trainingCompleted\", (GetPlayerArray()[0].GetPersistentVarAsInt( \"trainingCompleted\" ) == 0 ? 1 : 0) )" )
	SetupDevCommand( "Enable Survival Dev Mode", "playlist survival_dev" )
	SetupDevCommand( "Disable Match Ending", "mp_enablematchending 0" )
	SetupDevCommand( "Drop Care Package R1", "script thread AirdropForRound( gp()[0].GetOrigin(), gp()[0].GetAngles(), 0 )" )
	SetupDevCommand( "Drop Care Package R2", "script thread AirdropForRound( gp()[0].GetOrigin(), gp()[0].GetAngles(), 1 )" )
	SetupDevCommand( "Drop Care Package R3", "script thread AirdropForRound( gp()[0].GetOrigin(), gp()[0].GetAngles(), 2 )" )
	SetupDevCommand( "Death Field: Start", "dev_deathfield 1" )
	SetupDevCommand( "Death Field: Pause", "dev_deathfield 0" )
	SetupDevCommand( "Death Field End: Player", "dev_deathfield here" )
	SetupDevCommand( "Gladiator Intro Sequence", "script thread DEV_StartGladiatorIntroSequence()" )
	SetupDevCommand( "Bleedout Debug Mode", "script FlagSet( \"BleedoutDebug\" )" )
	SetupDevCommand( "Disable Loot Drops on Death", "script FlagSet( \"DisableLootDrops\" )" )
	SetupDevCommand( "Drop My Death Box", "script thread Dev_ForceDropDeathbox( GP() )" )
}

void function SetupSurvivalLoot( var categories )
{
	RunClientScript( "SetupSurvivalLoot", categories )
}

void function SetupSurvivalIncapShieldBot()
{
	SetupDevCommand( "Spawn Bot with Random Lv Incap Shield", "script Dev_SpawnBotWithIncapShieldToView( -1 )" )
	SetupDevCommand( "Spawn Bot with Lv 1 Incap Shield", "script Dev_SpawnBotWithIncapShieldToView( 1 )" )
	SetupDevCommand( "Spawn Bot with Lv 2 Incap Shield", "script Dev_SpawnBotWithIncapShieldToView( 2 )" )
	SetupDevCommand( "Spawn Bot with Lv 3 Incap Shield", "script Dev_SpawnBotWithIncapShieldToView( 3 )" )
	SetupDevCommand( "Spawn Bot with Lv 4 Incap Shield", "script Dev_SpawnBotWithIncapShieldToView( 4 )" )
	SetupDevCommand( "Spawn Bot with a Spamming Toggle Incap Shield (noreg)", "script Dev_SpawnBotWithIncapShieldToViewAndRandomAttack( 4, 0.8 )" )
	SetupDevCommand( "Spawn Bot with a Predictable Toggle Incap Shield (noreg)", "script Dev_SpawnBotWithIncapShieldToViewAndPredictableAttack( 4, 1.0 )" )
}
