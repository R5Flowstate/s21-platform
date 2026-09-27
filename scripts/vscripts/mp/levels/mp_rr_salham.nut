global function CodeCallback_PreMapInit

#if SERVER
global function CodeCallback_MapInit
#endif

#if CLIENT
global function ClientCodeCallback_MapInit
global function ServerCallback_S17DisableTweakLight
global function ServerCallback_S17ChrMessage
#endif

const string S17_VAULT_PANEL_SCRIPTNAME    = "SalhamLockedDoorPanel"
const string S17_TWEAK_LIGHT_SCRIPTNAME    = "s17_chr_end_tweak_light"
const string S17_DOOR_SCRIPTNAME           = "SalhamDoor"
const string S17_DOOR_RIGHT_SCRIPTNAME     = "SalhamDoorRight"
const string S17_DATAPAD_SCRIPTNAME        = "s17_chr_datapad"
const string S17_RESPAWN_TRIGGER           = "s17_respawn_trigger"
const string S17_ELEV_PLATFORM             = "s17_chr_elev_platform"
const string S17_ELEV_PAD                  = "s17_chr_pad"
const string S17_ELEV_ENDPT                = "s17_chr_elev_endpt"
const string S17_INTRO_DOOR                = "s17_chr_intro_door"
const string S17_FAKE_PLATFORM             = "s17_chr_fake_platform"
const string S17_FALL_TRIGGER              = "s17_chr_platform_fall_trigger"
const string S17_ABILITY_TRIGGER_1         = "s17_chr_act_ability_trigger_1"
const string S17_ABILITY_TRIGGER_2         = "s17_chr_act_ability_trigger_2"
const string S17_FINAL_ROOM_TRIGGER        = "s17_chr_final_room_trigger"
const string S17_END_PAD                   = "s17_chr_end_pad"
const string S17_END_CONTAINER             = "s17_chr_container_end"
const string S17_INTRO_DOOR_SEQ            = "yos1_elevator_room_door_open_close"
const string S17_CANISTER_SEQ              = "prop_loba_se17_monologue_canister"
const float  S17_ELEVATOR_RIDE_TIME        = 9.0

const asset  S17_VALK_MODEL                = $"mdl/Humans/class/medium/pilot_medium_valkyrie.rmdl"
const asset  S17_VALK_HELMET_MODEL         = $"mdl/props/valkryie_northstar_helmet/valkyrie_northstar_helmet.rmdl"
const asset  S17_CATWALK_ANIM_MODEL        = $"mdl/props/hammondCatwalk_wreaked/hammondCatwalk_wreaked.rmdl"
const asset  S17_REV_SKULL_MODEL           = $"mdl/props/revenant_skull_nojaw/revenant_skull_nojaw_base_w_lod0.rmdl"
const string S17_OPENING_LOBA_SEQ          = "loba_cine_yos1_elevator_room"
const string S17_OPENING_VALK_SEQ          = "valk_cine_yos1_elevator_room"
const string S17_OPENING_HELMET_SEQ        = "prop_cine_yos1_elevator_room_helmet"
const string S17_COLLAPSE_1P_SEQ           = "ptpov_loba_se17_bridgeCollapse"
const string S17_COLLAPSE_CATWALK_SEQ      = "prop_loba_se17_catwalk"
const string S17_MONOLOGUE_1P_SEQ          = "ptpov_loba_se17_monologue"
const string S17_MONOLOGUE_SKULL_SEQ       = "prop_loba_se17_monologue_skull"
const string S17_SND_ELEVATOR_START        = "Chronicles_S17_Loba_Scr_Elevator_Start"
const string S17_SND_ELEVATOR_STOP         = "Chronicles_S17_Loba_Scr_Elevator_Stop"
const string S17_SND_DOOR_UNLOCK           = "Chronicles_S17_Loba_Scr_KeycardDoorUnlock"
const string S17_SND_DOOR_OPEN             = "Chronicles_S17_Loba_Scr_KeycardDoorOpen"

const int eS17Msg_TACTICAL  = 0
const int eS17Msg_ULTIMATE  = 1
const int eS17Msg_DATAPAD   = 2
const int eS17Msg_UNLOCKED  = 3
const int eS17Msg_COMPLETE  = 4
const int eS17Msg_CHECKPOINT = 5
const int eS17Msg_COUNT     = 6

struct
{
#if SERVER
	table< entity, entity > checkpoint
	entity elevMover
	entity elevButton
	vector sceneOrigin = <-10249, -13540, 38434>
	vector sceneAngles = <0, 90, 0>
	bool   openingPlayed = false
	bool   elevatorUsed = false
	bool   platformsFell = false
	bool   doorUnlocked = false
	bool   finaleReached = false
#endif

#if CLIENT
	bool isDoorUnlocked = false
#endif
} file

void function CodeCallback_PreMapInit()
{
	AddCallback_OnNetworkRegistration( OnNetworkRegistration )
}

void function OnNetworkRegistration()
{
	RegisterNetworkedVariable( "DatapadPickedUp", SNDC_PLAYER_EXCLUSIVE, SNVT_BOOL, false )
	Remote_RegisterClientFunction( "ServerCallback_S17DisableTweakLight" )
	Remote_RegisterClientFunction( "ServerCallback_S17ChrMessage", "int", 0, eS17Msg_COUNT )
}

#if SERVER
void function CodeCallback_MapInit()
{
	RegisterSignal( "S17_CheckpointTeleport" )
	PrecacheModel( $"mdl/dev/empty_model.rmdl" )
	PrecacheModel( S17_VALK_MODEL )
	PrecacheModel( S17_VALK_HELMET_MODEL )
	PrecacheModel( S17_CATWALK_ANIM_MODEL )
	PrecacheModel( S17_REV_SKULL_MODEL )
	AddClientCommandCallback( "salham_scene", ClientCommand_SalhamScene )
	AddClientCommandCallback( "salham_finale", ClientCommand_SalhamFinale )
	AddClientCommandCallback( "salham_collapse", ClientCommand_SalhamCollapse )
	AddSpawnCallback( "prop_dynamic", VaultPanelSpawned )
	AddCallback_EntitiesDidLoad( Salham_OnEntitiesDidLoad )
	AddCallback_OnClientConnected( Salham_OnClientConnected )
	AddCallback_OnPlayerRespawned( Salham_OnPlayerRespawned )
	AddCallback_OnPlayerKilled( Salham_OnPlayerKilled )
}

void function Salham_OnEntitiesDidLoad()
{
	foreach ( entity trigger in GetEntArrayByScriptName( S17_RESPAWN_TRIGGER ) )
		trigger.SetEnterCallback( RespawnTrigger_OnEnter )

	foreach ( string name in [ "s17_chr_cp1_trigger", "s17_chr_cp2_trigger", "s17_chr_cp3_trigger" ] )
	{
		entity trigger = GetEntByScriptName( name )
		if ( IsValid( trigger ) )
			trigger.SetEnterCallback( CheckpointTrigger_OnEnter )
	}

	SetTriggerCallback( S17_FALL_TRIGGER, FallTrigger_OnEnter )
	SetTriggerCallback( S17_ABILITY_TRIGGER_1, AbilityTrigger1_OnEnter )
	SetTriggerCallback( S17_ABILITY_TRIGGER_2, AbilityTrigger2_OnEnter )
	SetTriggerCallback( S17_FINAL_ROOM_TRIGGER, FinalRoomTrigger_OnEnter )

	foreach ( string name in [ S17_DOOR_SCRIPTNAME, S17_DOOR_RIGHT_SCRIPTNAME ] )
	{
		entity door = GetEntByScriptName( name )
		if ( IsValid( door ) )
			LockDoor( door )
	}

	SetupElevator()
	SetupDatapad()
	SetupEndPad()
	thread OpenIntroDoor()
}

entity function MakeUsableProxy( entity lightweight, string prompt )
{
	entity proxy = CreatePropDynamic( lightweight.GetModelName(), lightweight.GetOrigin(), lightweight.GetAngles(), 6 )
	proxy.SetScriptName( lightweight.GetScriptName() + "_use" )
	lightweight.Hide()
	lightweight.NotSolid()
	proxy.SetUsable()
	proxy.SetUsableByGroup( "pilot" )
	proxy.AddUsableValue( USABLE_CUSTOM_HINTS )
	proxy.SetUsePrompts( prompt, prompt )
	return proxy
}

// Props without a REF attachment cannot be placed off a reference mover; they are
// spawned at the scene origin and play in place, which is the same transform.
void function PlaySceneAnim( entity prop, string seq, entity animRef )
{
	if ( prop.LookupAttachment( "REF" ) > 0 )
		thread PlayAnimTeleport( prop, seq, animRef )
	else
		prop.Anim_Play( seq )
}

void function SetTriggerCallback( string name, void functionref( entity, entity ) callback )
{
	entity trigger = GetEntByScriptName( name )
	if ( !IsValid( trigger ) )
	{
		Warning( "[SALHAM] trigger '" + name + "' not found" )
		return
	}
	trigger.SetEnterCallback( callback )
}

void function OpenIntroDoor()
{
	entity door = GetEntByScriptName( S17_INTRO_DOOR )
	if ( !IsValid( door ) )
		return

	door.EndSignal( "OnDestroy" )
	door.Anim_Play( S17_INTRO_DOOR_SEQ )
	wait door.GetSequenceDuration( S17_INTRO_DOOR_SEQ ) * 0.5
	door.Anim_SetPlaybackRate( 0.0 )
	door.NotSolid()
}

void function SetupElevator()
{
	entity platform = GetEntByScriptName( S17_ELEV_PLATFORM )
	entity pad = GetEntByScriptName( S17_ELEV_PAD )
	if ( !IsValid( platform ) || !IsValid( pad ) )
	{
		Warning( "[SALHAM] elevator platform/pad missing" )
		return
	}

	file.elevMover = CreateScriptMoverModel( $"mdl/dev/empty_model.rmdl", platform.GetOrigin(), platform.GetAngles() )
	platform.SetParent( file.elevMover, "", true )

	entity button = MakeUsableProxy( pad, "%use% Start elevator" )
	button.SetParent( file.elevMover, "", true )
	AddCallback_OnUseEntity( button, ElevatorPad_OnUse )
	file.elevButton = button
}

void function ElevatorPad_OnUse( entity pad, entity player, int useInputFlags )
{
	if ( file.elevatorUsed )
		return
	file.elevatorUsed = true
	pad.UnsetUsable()
	thread ElevatorRide( pad )
}

// The original opening is one 80 s piece: Loba walks in, Valkyrie drops in, they
// talk, Loba works the console and rides the elevator down. Both actors and the
// helmet play their cine sequences off one shared reference mover.
void function PlayOpeningScene( entity player )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	file.openingPlayed = true

	// survival's own start-of-match pass (ClearPlayerIntroDropSettings) repositions
	// players and refuses to while a scripted animation drives them
	while ( GetGameState() < eGameState.Playing )
		WaitFrame()
	wait 1.0
	if ( !IsAlive( player ) )
		return

	entity animRef = CreateScriptMoverModel( $"mdl/dev/empty_model.rmdl", file.sceneOrigin, file.sceneAngles )
	entity valk = CreatePropDynamic( S17_VALK_MODEL, file.sceneOrigin, file.sceneAngles, SOLID_BBOX, 99999 )
	entity helmet = CreatePropDynamic( S17_VALK_HELMET_MODEL, file.sceneOrigin, file.sceneAngles, 0, 99999 )
	OnThreadEnd( function() : ( animRef, valk, helmet )
	{
		if ( IsValid( valk ) ) valk.Destroy()
		if ( IsValid( helmet ) ) helmet.Destroy()
		if ( IsValid( animRef ) ) animRef.Destroy()
	} )

	player.SetPlayerNetBool( "DatapadPickedUp", false )
	HolsterAndDisableWeapons( player )

	// each cine sequence plays its own scene audio through an AE_CL_PLAYSOUND
	// event, so emitting the stem here as well makes every line play twice
	FirstPersonSequenceStruct seq
	seq.attachment = "ref"
	seq.blendTime = 0
	seq.teleport = true
	seq.thirdPersonAnim = S17_OPENING_LOBA_SEQ
	seq.thirdPersonCameraAttachments = [ "VDU" ]
	seq.viewConeFunction = void function( entity player )
	{
		if ( !player.IsPlayer() )
			return
		player.PlayerCone_SetLerpTime( 0.2 )
		player.PlayerCone_FromAnim()
		player.PlayerCone_SetMinYaw( 0 )
		player.PlayerCone_SetMaxYaw( 0 )
		player.PlayerCone_SetMinPitch( 0 )
		player.PlayerCone_SetMaxPitch( 0 )
	}

	PlaySceneAnim( valk, S17_OPENING_VALK_SEQ, animRef )
	PlaySceneAnim( helmet, S17_OPENING_HELMET_SEQ, animRef )
	waitthread FirstPersonSequence( seq, player, animRef )

	ClearPlayerAnimViewEntity( player )
	DeployAndEnableWeapons( player )
	player.Anim_Stop()
	if ( IsValid( file.elevButton ) )
		file.elevButton.UnsetUsable()
	file.elevatorUsed = true
	if ( IsValid( file.elevMover ) )
	{
		player.SetOrigin( file.elevMover.GetOrigin() + <0, 0, 8> )
		player.SetAngles( <0, 90, 0> )
		player.SnapEyeAngles( <0, 90, 0> )
	}
	thread ElevatorRide( null )
}

// Dev triggers for the chronicle scenes: they run map-wide events and take raw coordinates.
bool function Salham_DevCommandAllowed( entity player )
{
	return IsValid( player ) && player.IsPlayer() && GetConVarInt( "sv_cheats" ) == 1
}

void function ClientCommand_SalhamScene( entity player, array<string> args )
{
	if ( !Salham_DevCommandAllowed( player ) )
		return
	if ( args.len() >= 4 )
	{
		file.sceneOrigin = < float( args[0] ), float( args[1] ), float( args[2] ) >
		file.sceneAngles = < 0, float( args[3] ), 0 >
	}
	else if ( args.len() == 1 )
	{
		file.sceneOrigin = player.GetOrigin()
		file.sceneAngles = < 0, float( args[0] ), 0 >
	}
	thread PlayOpeningScene( player )
}

void function ClientCommand_SalhamFinale( entity player, array<string> args )
{
	if ( Salham_DevCommandAllowed( player ) )
		thread ChronicleFinale( player )
}

void function ClientCommand_SalhamCollapse( entity player, array<string> args )
{
	if ( Salham_DevCommandAllowed( player ) )
		thread CollapseCatwalk( player )
}

void function ElevatorRide( entity pad )
{
	entity endpt = GetEntByScriptName( S17_ELEV_ENDPT )
	entity mover = file.elevMover
	if ( !IsValid( endpt ) || !IsValid( mover ) )
		return

	vector dest = endpt.GetOrigin()
	vector start = mover.GetOrigin()
	array<entity> riders
	foreach ( entity player in GetPlayerArray_Alive() )
	{
		if ( Distance2D( player.GetOrigin(), start ) < 260 && fabs( player.GetOrigin().z - start.z ) < 160 )
		{
			player.SetParent( mover, "", true )
			riders.append( player )
		}
	}

	EmitSoundOnEntity( mover, S17_SND_ELEVATOR_START )
	wait 1.0
	mover.NonPhysicsMoveTo( dest, S17_ELEVATOR_RIDE_TIME, 1.5, 1.5 )
	wait S17_ELEVATOR_RIDE_TIME
	EmitSoundOnEntity( mover, S17_SND_ELEVATOR_STOP )

	foreach ( entity player in riders )
	{
		if ( !IsValid( player ) )
			continue
		player.ClearParent()
		player.SetOrigin( dest + <0, 0, 8> )
		GiveChronicleTactical( player, "s17cr_p0_cooldown_mod" )
		SetAbilityHudVis( player, "ServerCallback_SetTacticalHudVis", true )
	}
}

void function AbilityTrigger1_OnEnter( entity trigger, entity player )
{
	if ( !player.IsPlayer() )
		return
	GiveChronicleTactical( player, "s17cr_p0_cooldown_mod" )
	Remote_CallFunction_NonReplay( player, "ServerCallback_S17ChrMessage", eS17Msg_TACTICAL )
	SetAbilityHudVis( player, "ServerCallback_SetTacticalHudVis", true )
}

void function AbilityTrigger2_OnEnter( entity trigger, entity player )
{
	if ( !player.IsPlayer() )
		return
	GiveChronicleTactical( player, "s17cr_p1_cooldown_mod" )
	GiveChronicleUltimate( player )
	Remote_CallFunction_NonReplay( player, "ServerCallback_S17ChrMessage", eS17Msg_ULTIMATE )
	SetAbilityHudVis( player, "ServerCallback_SetUltimateHudVis", true )
}

void function GiveChronicleTactical( entity player, string mod )
{
	entity tactical = player.GetOffhandWeapon( OFFHAND_TACTICAL )
	if ( IsValid( tactical ) )
	{
		if ( tactical.HasMod( mod ) )
			return
		player.TakeOffhandWeapon( OFFHAND_TACTICAL )
	}
	player.GiveOffhandWeapon( "mp_ability_translocation", OFFHAND_TACTICAL, [ mod ] )
	entity weapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
	if ( IsValid( weapon ) )
		weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
}

void function GiveChronicleUltimate( entity player )
{
	if ( IsValid( player.GetOffhandWeapon( OFFHAND_ULTIMATE ) ) )
		return
	player.GiveOffhandWeapon( "mp_ability_black_market", OFFHAND_ULTIMATE, [ "s17cr_p2_cooldown_mod" ] )
	entity weapon = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
	if ( IsValid( weapon ) )
		weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
}

void function StripAbilities( entity player )
{
	player.TakeOffhandWeapon( OFFHAND_TACTICAL )
	player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
	SetAbilityHudVis( player, "ServerCallback_SetTacticalHudVis", false )
	SetAbilityHudVis( player, "ServerCallback_SetUltimateHudVis", false )
}

void function SetAbilityHudVis( entity player, string func, bool visible )
{
	if ( !IsEventFinale() )
		return
	Remote_CallFunction_NonReplay( player, func, visible )
}

void function FallTrigger_OnEnter( entity trigger, entity player )
{
	if ( !player.IsPlayer() || file.platformsFell )
		return
	file.platformsFell = true
	thread CollapseCatwalk( player )
}

void function CollapseCatwalk( entity player )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	array<entity> fakes = GetEntArrayByScriptName( S17_FAKE_PLATFORM )
	if ( fakes.len() == 0 )
	{
		thread DropFakePlatforms()
		return
	}
	entity first = fakes[0]
	foreach ( entity f in fakes )
	{
		if ( f.GetOrigin().z > first.GetOrigin().z )
			first = f
	}
	entity animRef = CreateScriptMoverModel( $"mdl/dev/empty_model.rmdl", first.GetOrigin(), first.GetAngles() )
	entity wreck = CreatePropDynamic( S17_CATWALK_ANIM_MODEL, first.GetOrigin(), first.GetAngles(), 0, 99999 )
	foreach ( entity f in fakes )
	{
		f.Hide()
		f.NotSolid()
	}
	OnThreadEnd( function() : ( animRef, wreck )
	{
		if ( IsValid( wreck ) ) wreck.Destroy()
		if ( IsValid( animRef ) ) animRef.Destroy()
	} )

	HolsterAndDisableWeapons( player )
	FirstPersonSequenceStruct seq
	seq.attachment = "ref"
	seq.blendTime = 0.2
	seq.teleport = true
	seq.firstPersonAnim = S17_COLLAPSE_1P_SEQ
	PlaySceneAnim( wreck, S17_COLLAPSE_CATWALK_SEQ, animRef )
	waitthread FirstPersonSequence( seq, player, animRef )
	ClearPlayerAnimViewEntity( player )
	DeployAndEnableWeapons( player )
	player.Anim_Stop()
}

void function DropFakePlatforms()
{
	array<entity> movers
	foreach ( entity platform in GetEntArrayByScriptName( S17_FAKE_PLATFORM ) )
	{
		entity mover = CreateScriptMoverModel( $"mdl/dev/empty_model.rmdl", platform.GetOrigin(), platform.GetAngles() )
		platform.SetParent( mover, "", true )
		platform.NotSolid()
		mover.NonPhysicsMoveTo( platform.GetOrigin() - <0, 0, 4000>, 2.5, 0.2, 0.0 )
		mover.NonPhysicsRotateTo( platform.GetAngles() + <35, 0, 20>, 2.5, 0.2, 0.0 )
		movers.append( mover )
	}
	wait 3.0
	foreach ( entity mover in movers )
	{
		if ( IsValid( mover ) )
			mover.Destroy()
	}
}

void function CheckpointTrigger_OnEnter( entity trigger, entity player )
{
	if ( !player.IsPlayer() )
		return
	string targetName = StringReplace( trigger.GetScriptName(), "_trigger", "_info_target" )
	entity target = GetEntByScriptName( targetName )
	if ( !IsValid( target ) )
		return
	if ( player in file.checkpoint && file.checkpoint[ player ] == target )
		return
	file.checkpoint[ player ] <- target
	Remote_CallFunction_NonReplay( player, "ServerCallback_S17ChrMessage", eS17Msg_CHECKPOINT )
}

void function RespawnTrigger_OnEnter( entity trigger, entity player )
{
	if ( !player.IsPlayer() || !IsAlive( player ) )
		return
	entity target
	foreach ( entity link in trigger.GetLinkEntArray() )
	{
		if ( link.GetClassName() == "info_target" )
			target = link
	}
	if ( !IsValid( target ) && player in file.checkpoint )
		target = file.checkpoint[ player ]
	if ( !IsValid( target ) )
		return
	thread TeleportToCheckpoint( player, target )
}

void function TeleportToCheckpoint( entity player, entity target )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.Signal( "S17_CheckpointTeleport" )
	player.EndSignal( "S17_CheckpointTeleport" )

	ScreenFadeToColor( player, 0, 0, 0, 255, 0.25, 0.3 )
	wait 0.3
	player.ClearParent()
	player.SetVelocity( <0, 0, 0> )
	player.SetOrigin( target.GetOrigin() )
	player.SetAngles( <0, target.GetAngles().y, 0> )
	player.SnapEyeAngles( <0, target.GetAngles().y, 0> )
	ScreenFadeFromColor( player, 0, 0, 0, 255, 0.4, 0.1 )
}

entity function GetStartPoint()
{
	array<entity> starts = GetEntArrayByClass_Expensive( "info_player_start" )
	if ( starts.len() > 0 )
		return starts[0]
	return null
}

void function Salham_OnClientConnected( entity player )
{
	ForceLoba( player )
}

void function ForceLoba( entity player )
{
	if ( !IsValidItemFlavorCharacterRef( "character_loba" ) )
		return
	ItemFlavor loba = GetItemFlavorByCharacterRef( "character_loba" )
	EHI ehi = ToEHI( player )
	LoadoutEntry slot = Loadout_Character()
	bool changed = !LoadoutSlot_IsReady( ehi, slot ) || LoadoutSlot_GetItemFlavor( ehi, slot ) != loba
	SetItemFlavorLoadoutSlot( ehi, slot, loba )
	player.SetPlayerNetBool( "hasLockedInCharacter", true )
	if ( IsAlive( player ) && changed )
		Survival_PlayerCharacterSetup( player, loba, false )
}

void function Salham_OnPlayerRespawned( entity player )
{
	thread Salham_PlayerSpawnSetup( player )
}

void function Salham_PlayerSpawnSetup( entity player )
{
	player.EndSignal( "OnDestroy" )
	WaitFrame()
	if ( !IsAlive( player ) )
		return

	ForceLoba( player )
	StripAbilities( player )
	player.SetPlayerNetBool( "DatapadPickedUp", false )

	entity target = null
	if ( player in file.checkpoint )
		target = file.checkpoint[ player ]
	else
		target = GetStartPoint()

	if ( IsValid( target ) )
	{
		float yaw = target.GetScriptName() == "" ? 90.0 : target.GetAngles().y
		player.SetOrigin( target.GetOrigin() )
		player.SetAngles( <0, yaw, 0> )
		player.SnapEyeAngles( <0, yaw, 0> )
	}

	if ( IsValid( target ) && target.GetScriptName() == "" && !file.openingPlayed )
	{
		thread PlayOpeningScene( player )
		return
	}

	if ( IsValid( target ) && target.GetScriptName() != "" )
	{
		int stage = CheckpointStage( target.GetScriptName() )
		if ( stage >= 1 )
			GiveChronicleTactical( player, "s17cr_p0_cooldown_mod" )
		if ( stage >= 5 )
		{
			GiveChronicleTactical( player, "s17cr_p1_cooldown_mod" )
			GiveChronicleUltimate( player )
		}
	}
}

int function CheckpointStage( string name )
{
	switch ( name )
	{
		case "s17_chr_cp0_info_target": return 1
		case "s17_chr_cp1_info_target": return 2
		case "s17_chr_cp2_info_target": return 3
		case "s17_chr_cp3_info_target": return 4
		case "s17_checkpoint_info_target": return 5
		case "s17_chr_cp4_info_target": return 6
		case "s17_chr_cp5_info_target": return 7
	}
	return 0
}

void function Salham_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsPlayer() )
		return
	thread RespawnAfterDeath( victim )
}

void function RespawnAfterDeath( entity player )
{
	player.EndSignal( "OnDestroy" )
	wait 3.0
	if ( IsAlive( player ) )
		return
	ClearPlayerEliminated( player )
	player.Signal( "StopPostDeathLogic" )
	if ( player.IsObserver() )
	{
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
	}
	DecideRespawnPlayer( player, false )
}

void function SetupDatapad()
{
	entity datapad = GetEntByScriptName( S17_DATAPAD_SCRIPTNAME )
	if ( !IsValid( datapad ) )
	{
		Warning( "[SALHAM] datapad prop missing" )
		return
	}
	entity proxy = MakeUsableProxy( datapad, "%use% Take datapad" )
	AddCallback_OnUseEntity( proxy, Datapad_OnUse )
}

void function Datapad_OnUse( entity datapad, entity player, int useInputFlags )
{
	if ( player.GetPlayerNetBool( "DatapadPickedUp" ) )
		return
	player.SetPlayerNetBool( "DatapadPickedUp", true )
	EmitSoundOnEntityOnlyToPlayer( player, player, "LootVault_Open" )
	Remote_CallFunction_NonReplay( player, "ServerCallback_S17ChrMessage", eS17Msg_DATAPAD )
}

void function SetupEndPad()
{
	entity pad = GetEntByScriptName( S17_END_PAD )
	if ( !IsValid( pad ) )
	{
		Warning( "[SALHAM] end pad missing" )
		return
	}
	entity proxy = MakeUsableProxy( pad, "%use% Open canister" )
	AddCallback_OnUseEntity( proxy, EndPad_OnUse )
}

void function FinalRoomTrigger_OnEnter( entity trigger, entity player )
{
	if ( !player.IsPlayer() )
		return
	file.finaleReached = true
}

void function EndPad_OnUse( entity pad, entity player, int useInputFlags )
{
	pad.UnsetUsable()
	thread ChronicleFinale( player )
}

void function ChronicleFinale( entity player )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	entity canister = GetEntByScriptName( S17_END_CONTAINER )
	if ( !IsValid( canister ) )
		return
	entity animRef = CreateScriptMoverModel( $"mdl/dev/empty_model.rmdl", canister.GetOrigin(), canister.GetAngles() )
	entity skull = CreatePropDynamic( S17_REV_SKULL_MODEL, canister.GetOrigin(), canister.GetAngles(), 0, 99999 )
	OnThreadEnd( function() : ( animRef, skull )
	{
		if ( IsValid( skull ) ) skull.Destroy()
		if ( IsValid( animRef ) ) animRef.Destroy()
	} )

	HolsterAndDisableWeapons( player )
	FirstPersonSequenceStruct seq
	seq.attachment = "ref"
	seq.blendTime = 0.2
	seq.teleport = true
	seq.firstPersonAnim = S17_MONOLOGUE_1P_SEQ
	PlaySceneAnim( canister, S17_CANISTER_SEQ, animRef )
	PlaySceneAnim( skull, S17_MONOLOGUE_SKULL_SEQ, animRef )
	foreach ( entity p in GetPlayerArray() )
		Remote_CallFunction_NonReplay( p, "ServerCallback_S17DisableTweakLight" )
	waitthread FirstPersonSequence( seq, player, animRef )
	ClearPlayerAnimViewEntity( player )
	DeployAndEnableWeapons( player )
	player.Anim_Stop()

	foreach ( entity p in GetPlayerArray() )
		Remote_CallFunction_NonReplay( p, "ServerCallback_S17ChrMessage", eS17Msg_COMPLETE )
}
#endif

#if CLIENT
void function ClientCodeCallback_MapInit()
{
	AddCreateCallback( "prop_dynamic", VaultPanelSpawned )
}

void function ServerCallback_S17DisableTweakLight()
{
	array< entity > tweakLight = GetEntArrayByScriptName( S17_TWEAK_LIGHT_SCRIPTNAME )
	if ( tweakLight.len() == 1 && IsValid( tweakLight[0] ) )
		tweakLight[0].SetTweakLightBrightness( 0 )
}

void function ServerCallback_S17ChrMessage( int msg )
{
	entity player = GetLocalClientPlayer()
	switch ( msg )
	{
		case eS17Msg_TACTICAL:
			AnnouncementMessageSweep( player, Localize( "#S17CR_MSG_TACTICAL" ), Localize( "#S17CR_MSG_TACTICAL_SUB" ), <255, 200, 120>, $"", SFX_HUD_ANNOUNCE_QUICK, 4.0 )
			break
		case eS17Msg_ULTIMATE:
			AnnouncementMessageSweep( player, Localize( "#S17CR_MSG_ULTIMATE" ), Localize( "#S17CR_MSG_ULTIMATE_SUB" ), <255, 200, 120>, $"", SFX_HUD_ANNOUNCE_QUICK, 4.0 )
			break
		case eS17Msg_DATAPAD:
			AnnouncementMessageSweep( player, Localize( "#S17CR_MSG_DATAPAD" ), Localize( "#S17CR_MSG_DATAPAD_SUB" ), <120, 220, 255>, $"", SFX_HUD_ANNOUNCE_QUICK, 4.0 )
			break
		case eS17Msg_UNLOCKED:
			AnnouncementMessageSweep( player, Localize( "#S17CR_MSG_UNLOCKED" ), "", <120, 220, 255>, $"", SFX_HUD_ANNOUNCE_QUICK, 3.0 )
			break
		case eS17Msg_COMPLETE:
			AnnouncementMessageSweep( player, Localize( "#S17CR_MSG_COMPLETE" ), Localize( "#S17CR_MSG_COMPLETE_SUB" ), <255, 230, 120>, $"", SFX_HUD_ANNOUNCE_QUICK, 8.0 )
			break
		case eS17Msg_CHECKPOINT:
			AnnouncementMessageSweep( player, Localize( "#S17CR_MSG_CHECKPOINT" ), "", <200, 200, 200>, $"", SFX_HUD_ANNOUNCE_QUICK, 2.0 )
			break
	}
}

void function DisplayRuiForLootVaultPanel( entity ent, entity player, var rui, ExtendedUseSettings settings )
{
	RuiSetBool( rui, "isVisible", true )
	RuiSetImage( rui, "icon", settings.icon )
	RuiSetGameTime( rui, "startTime", Time() )
	RuiSetGameTime( rui, "endTime", Time() + settings.duration )
	RuiSetString( rui, "hintKeyboardMouse", settings.hint )
	RuiSetString( rui, "hintController", settings.hint )
}

string function VaultPanel_TextOverride( entity panel )
{
	entity player = GetLocalViewPlayer()

	if ( file.isDoorUnlocked )
		return ""

	if ( player.GetPlayerNetBool( "DatapadPickedUp" ) )
		return "#S17CR_UNLOCK"

	return "#S17CR_LOCKED"
}
#endif

void function VaultPanelSpawned( entity ent )
{
	if ( ent.GetScriptName() != S17_VAULT_PANEL_SCRIPTNAME )
		return

	#if SERVER
		ent.SetUsable()
		ent.SetUsableByGroup( "pilot" )
		ent.AddUsableValue( USABLE_CUSTOM_HINTS )
		AddCallback_OnUseEntity_ClientServer( ent, VaultPanel_OnUse )
	#endif

	#if CLIENT
		AddEntityCallback_GetUseEntOverrideText( ent, VaultPanel_TextOverride )
		AddCallback_OnUseEntity_ClientServer( ent, VaultPanel_OnUse )
		file.isDoorUnlocked = false
	#endif
}

void function VaultPanel_OnUse( entity panel, entity player, int useInputFlags )
{
	if ( !IsBitFlagSet( useInputFlags, USE_INPUT_LONG ) )
		return

	if ( !player.GetPlayerNetBool( "DatapadPickedUp" ) )
		return

	#if CLIENT
	if ( file.isDoorUnlocked )
		return
	#endif

	#if SERVER
	if ( file.doorUnlocked )
		return
	#endif

	ExtendedUseSettings settings
	settings.duration = 5.0
	settings.useInputFlag = IN_USE_LONG
	settings.successSound = "LootVault_Access"
	settings.successFunc = VaultPanelUseSuccess

	#if CLIENT
		settings.loopSound = "LootVault_StatusBar"
		settings.displayRuiFunc = DisplayRuiForLootVaultPanel
		settings.displayRui = $"ui/health_use_progress.rpak"
		settings.icon = $"rui/hud/gametype_icons/survival/data_knife"
		settings.hint = "#S17CR_UNLOCKING"
	#endif

	thread ExtendedUse( panel, player, settings )
}

void function VaultPanelUseSuccess( entity panel, entity player, ExtendedUseSettings settings )
{
	#if SERVER
	if ( file.doorUnlocked )
		return
	file.doorUnlocked = true
	panel.UnsetUsable()
	EmitSoundOnEntity( panel, S17_SND_DOOR_UNLOCK )
	EmitSoundOnEntity( panel, S17_SND_DOOR_OPEN )
	foreach ( string name in [ S17_DOOR_SCRIPTNAME, S17_DOOR_RIGHT_SCRIPTNAME ] )
	{
		entity door = GetEntByScriptName( name )
		if ( !IsValid( door ) )
			continue
		UnlockDoor( door )
		OpenDoor( door, player )
	}
	foreach ( entity p in GetPlayerArray() )
		Remote_CallFunction_NonReplay( p, "ServerCallback_S17ChrMessage", eS17Msg_UNLOCKED )
	#endif

	#if CLIENT
	file.isDoorUnlocked = true
	#endif
}
