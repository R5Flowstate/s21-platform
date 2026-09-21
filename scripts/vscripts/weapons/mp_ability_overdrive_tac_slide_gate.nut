global function MpAbilitySlideGate_Init
global function OnWeaponTossPrep_ability_slide_gate
global function OnWeaponTossReleaseAnimEvent_ability_slide_gate
global function OnWeaponActivate_ability_slide_gate
global function OnWeaponDeactivate_ability_slide_gate
global function OnWeaponTossCancel_ability_slide_gate
global function OnWeaponAttemptOffhandSwitch_ability_slide_gate


#if SERVER
global function SlideGate_OnEnter_Server
#endif

#if CLIENT
global function ServerToClient_SlideGateEnter

#if CLIENT
global function OnClientAnimEvent_DeploySlideGate
global function StopSlideGateBoostFX
#endif
#endif

global const string OVERDRIVE_SLIDE_JUMP_PASSIVE	= "boosted_slide_jump"
global const string SLIDEGATE_SCRIPTNAME			= "slide_gate"
global const string SLIDEGATE_ABILITY_NAME			= "mp_ability_overdrive_tac_slide_gate"
const string SLIDEGATE_BOOSTED_SLIDE_PASSIVE		= "slide_boost"
const string SLIDEGATE_DESTRUCTION_IMPACT_TABLE     = "ability_axle_tac_nitro_gate_destruction"

const string SLIDEGATE_TRIGGER_ENTER	= "SlideGate_EnterTrigger"
const string SLIDEGATE_FX_END			= "SlideGate_BoostFXEnd"
const string SLIDEGATE_BOOST_END		= "SlideGate_BoostEnd"

const asset SLIDEGATE_ACTIVE_1P_FX			= $"P_ability_axle_tac_rush_1p"
const asset SLIDEGATE_BRACKET_ARROWS_FX		= $"P_ability_axle_tac_gate_arrows"
const asset SLIDEGATE_PATH_ARROWS_FX		= $"p_ability_axle_tac_gate_arrows_UX"
const asset SLIDEGATE_CORE_FX				= $"P_ability_axle_tac_gate_core"
const asset SLIDEGATE_CORE_UPGRADE_FX		= $"P_ability_axle_tac_gate_core_upgrade"
const asset SLIDEGATE_TRAIL_FX				= $"P_ability_axle_tac_rush_3p_trail"
const asset SLIDEGATE_GATE_FX_INIT			= $"P_ability_axle_tac_rush_3p_init_dir"
const asset SLIDEGATE_JUMPJETS_FX			= $"P_ability_axle_tac_init_nitrogate"
const asset SLIDEGATE_JUMPJETS_FX_OVERDRIVE	= $"P_ability_axle_tac_init_nitrogate_axle"
const string SLIDEGATE_DEPLOY_IMPACT_TABLE 	= "ability_axle_tac_nitro_gate"
const vector SLIDEGATE_FLASH_COLOR 			= <177.0 / 255.0 * 3.0, 85.0 / 255.0 * 3.0, 214.0 / 255.0 * 3.0>

const string SLIDEGATE_DEPLOY_UNPACK		= "Overdrive_Tac_NitroGate_Deploy_Unpack"
const string SLIDEGATE_IDLE					= "Overdrive_Tac_NitroGate_Armed_Idle_Loop"
const string SLIDEGATE_LAUNCH_1P_GENERIC	= "Overdrive_Tac_Player_NitroGate_Launch_1P"
const string SLIDEGATE_LAUNCH_1P_AXLE		= "Overdrive_Tac_Overdrive_NitroGate_Launch_1P"
const string SLIDEGATE_LAUNCH_3P			= "Overdrive_Tac_Player_NitroGate_Launch_3P"
const string SLIDEGATE_EFFECT_ACTIVE_3P		= "Overdrive_Tac_Player_SlidingPresence"
const string SLIDEGATE_EFFECT_END_1P		= "Overdrive_Tac_Player_NitroGate_Slide_End_1P"
const string SLIDEGATE_EFFECT_END_3P		= "Overdrive_Tac_Player_NitroGate_Slide_End_3P"
const string SLIDEGATE_REMOVED				= "wattson_tactical_l"

const asset SLIDEGATE_MODEL = $"mdl/props/overdrive_tactical_pad/overdrive_tactical_pad.rmdl"

const string SLIDEGATE_DEPLOY_SCREEN_SHAKE = "slide_gate_screen_shake"
const float SHAKE_AMPLITUDE  = 2.0
const float SHAKE_FREQUENCY  = 10.0
const float SHAKE_DURATION   = 0.2
const vector SHAKE_DIRECTION = < 0.0, 0.0, 1.0 >

const string SLIDEGATE_DEPLOY_ANIM	= "overdrive_tac_pad_deploy"
const string SLIDEGATE_IDLE_ANIM	= "overdrive_tac_pad_idle"
const string SLIDEGATE_LAUNCH_ANIM	= "overdrive_tac_pad_trigger"

#if SERVER
const int SLIDEGATE_MAX_HEALTH			= 100
const int SLIDEGATE_MAX_ACTIVE			= 2
const float SLIDEGATE_TRIGGER_RADIUS	= 32.0
const float SLIDEGATE_TRIGGER_ABOVE		= 72.0
const float SLIDEGATE_TRIGGER_BELOW		= 8.0
const float SLIDEGATE_LAUNCH_SPEED		= 750.0
const float SLIDEGATE_BOOST_MIN_TIME	= 0.25
const float SLIDEGATE_BOOST_STOP_SPEED	= 100.0
const float SLIDEGATE_DUMMIE_HOP		= 120.0
const float SLIDEGATE_MOVE_DIR_MIN_SPEED	= 50.0
const string SLIDEGATE_COOLDOWN_MOD		= "upgrade_core_tac_cooldown_reduction"
#endif

#if DEV
const bool DEBUG_GATE_BOOST_VFX = false
#endif

struct
{
	string movementKeyBoundHint

#if CLIENT
	table<entity, float> gateEnterTimes = {}
#endif

#if SERVER
	table<entity, array<entity> > slideGatesByOwner = {}
#endif
} file

struct
{
	float gateHighlightFadeDist = 1500.0

	float slideMaxTime = 5.0
	float slideMaxTimeNerfed = 3.0
} tuning

void function MpAbilitySlideGate_Init()
{

	PrecacheModel( SLIDEGATE_MODEL )

	PrecacheParticleSystem( SLIDEGATE_ACTIVE_1P_FX )
	PrecacheParticleSystem( SLIDEGATE_BRACKET_ARROWS_FX )
	PrecacheParticleSystem( SLIDEGATE_PATH_ARROWS_FX )
	PrecacheParticleSystem( SLIDEGATE_CORE_FX )
	PrecacheParticleSystem( SLIDEGATE_CORE_UPGRADE_FX )
	PrecacheParticleSystem( SLIDEGATE_TRAIL_FX )
	PrecacheParticleSystem( SLIDEGATE_GATE_FX_INIT )
	PrecacheParticleSystem( SLIDEGATE_JUMPJETS_FX )
	PrecacheParticleSystem( SLIDEGATE_JUMPJETS_FX_OVERDRIVE )
	PrecacheImpactEffectTable( SLIDEGATE_DEPLOY_IMPACT_TABLE )
	PrecacheScriptString( SLIDEGATE_SCRIPTNAME )

	Remote_RegisterClientFunction( "ServerToClient_SlideGateEnter", "entity" )

#if SERVER
	RegisterSignal( SLIDEGATE_BOOST_END )
#endif

#if CLIENT
	RegisterMinimapPackage( "prop_script", eMinimapObject_prop_script.NITRO_GATE, MINIMAP_OBJECT_RUI, MinimapPackage_SlideGate, FULLMAP_OBJECT_RUI, MinimapPackage_SlideGate )
	AddCreateCallback( "trigger_cylinder", OnSlideGateTriggerCreated )
	AddScriptNameCreateCallback( SLIDEGATE_SCRIPTNAME, OnSlideGateCreated )

	RegisterSignal( SLIDEGATE_FX_END )
	StatusEffect_RegisterEnabledCallback( eStatusEffect.slide_gate_boosting, StartSlideGateBoostFX )
	StatusEffect_RegisterDisabledCallback( eStatusEffect.slide_gate_boosting, StopSlideGateBoostFX )
#endif
}

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function __________________SharedFuncs_________________________(){}
#endif

void function OnWeaponTossPrep_ability_slide_gate( entity weapon, WeaponTossPrepParams prepParams )
{
	Grenade_OnWeaponTossPrep( weapon, prepParams )
}

bool function OnWeaponAttemptOffhandSwitch_ability_slide_gate( entity weapon )
{
	return true
}

void function OnWeaponActivate_ability_slide_gate( entity weapon )
{
}

void function OnWeaponDeactivate_ability_slide_gate( entity weapon )
{
	Grenade_OnWeaponDeactivate( weapon )
}

var function OnWeaponTossCancel_ability_slide_gate( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return Grenade_OnWeaponTossCancelDrop( weapon, attackParams )
}

var function OnWeaponTossReleaseAnimEvent_ability_slide_gate( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	int ammoReq = weapon.GetAmmoPerShot()
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	entity deployable = ThrowDeployable( weapon, attackParams, 1.0, DeploySlideGate, null, <0, 0, 1900> )
	if ( deployable )
	{
		entity player = weapon.GetWeaponOwner()
		PlayerUsedOffhand( player, weapon, true, deployable )

		#if SERVER
		if ( IsValid( player ) )
		{
			FiringRange_AddToRemoveOnCharacterChange( deployable, player )
		}

		deployable.proj.refundAmount = ammoReq

		string projectileSound = GetGrenadeProjectileSound( weapon )
		if ( projectileSound != "" )
			EmitSoundOnEntity( deployable, projectileSound )
		#endif
	}

	return ammoReq
}

void function DeploySlideGate( entity projectile, DeployableCollisionParams deployCollisionParams)
{
#if SERVER
	if ( !IsValid( projectile ) )
		return

	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) )
	{
		projectile.Destroy()
		return
	}

	vector fwd = AnglesToForward( projectile.proj.savedAngles )
	vector surfaceAngles = AnglesOnSurface( deployCollisionParams.normal, fwd )
	vector origin = deployCollisionParams.pos

	entity gate = CreatePropScript( SLIDEGATE_MODEL, origin, surfaceAngles, SOLID_CYLINDER )
	gate.SetScriptName( SLIDEGATE_SCRIPTNAME )
	SetTeam( gate, owner.GetTeam() )
	gate.SetOwner( owner )
	gate.SetMaxHealth( SLIDEGATE_MAX_HEALTH )
	gate.SetHealth( SLIDEGATE_MAX_HEALTH )
	gate.SetTakeDamageType( DAMAGE_YES )
	gate.SetDeathNotifications( true )
	gate.SetDamageNotifications( true )
	gate.DisableHibernation()
	gate.SetBlocksRadiusDamage( false )
	gate.Highlight_Enable()
	Highlight_SetOwnedHighlight( gate, "sp_friendly_hero" )
	Highlight_SetFriendlyHighlight( gate, "sp_friendly_hero" )
	gate.Minimap_SetCustomState( eMinimapObject_prop_script.NITRO_GATE )
	AddToUltimateRealm( owner, gate )
	AddEntityCallback_OnKilled( gate, SlideGate_OnPadKilled )
	thread TrapDestroyOnRoundEnd( owner, gate )
	FiringRange_AddToRemoveOnCharacterChange( gate, owner )
	FiringRange_AddToPermanentDeployableQuota( gate, owner )

	PlayImpactFXTable( origin, owner, SLIDEGATE_DEPLOY_IMPACT_TABLE )
	EmitSoundOnEntity( gate, SLIDEGATE_DEPLOY_UNPACK )
	thread SlideGate_PlayDeployAnim( gate )

	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetOwner( owner )
	trigger.SetCylinderRadius( SLIDEGATE_TRIGGER_RADIUS )
	trigger.SetAboveHeight( SLIDEGATE_TRIGGER_ABOVE )
	trigger.SetBelowHeight( SLIDEGATE_TRIGGER_BELOW )
	trigger.kv.triggerFilterNpc          = "all"
	trigger.kv.triggerFilterPlayer       = "all"
	trigger.kv.triggerFilterNonCharacter = 1
	trigger.SetOrigin( origin )
	trigger.SetAngles( surfaceAngles )
	DispatchSpawn( trigger )
	trigger.Enable()
	trigger.SetParent( gate, "", false, 0.0 )
	trigger.SetEnterCallback( SlideGate_OnEnter_Server )
	trigger.SearchForNewTouchingEntity()
	if ( IsValid( owner ) )
		AddToUltimateRealm( owner, trigger )

	SlideGate_TrackGateForOwner( owner, gate, trigger, projectile )
	projectile.Destroy()
#endif
}

bool function SlideGate_FilterCallback( entity trigger, entity ent )
{
	if( !IsValid( ent ) || !ent.DoesShareRealms( trigger ) )
		return false

	if ( !ent.IsPlayer() && !ent.IsPlayerDecoy() && !IsTrainingDummie( ent ) )
		return false

#if CLIENT
	if( ent.IsPlayer() && ent.IsArmoredLeapActive() )
		return false
#endif

	if( !IsValid( trigger ) || trigger.IsMarkedForDeletion() )
		return false

	entity triggerParent = trigger.GetParent()
	if( !IsValid( triggerParent ) || triggerParent.IsMarkedForDeletion() )
		return false

	return true
}

bool function SlideGate_IsSlideGateTrigger( entity trigger )
{
	entity gateParent = trigger.GetParent()
	if ( IsValid( gateParent ) && gateParent.GetScriptName() == SLIDEGATE_SCRIPTNAME )
		return true

	entity owner = trigger.GetOwner()
	if ( IsValid( owner ) && owner.GetScriptName() == SLIDEGATE_SCRIPTNAME )
		return true

	return false
}

bool function DoesPlayerHaveJumpGate( entity player )
{
	return DoesPlayerHaveOverdrivePassive( player ) && PlayerHasPassive( player, ePassives.PAS_TAC_UPGRADE_ONE )
}

float function SlideGate_GetMaxSlideTime( entity player )
{
	return DoesPlayerHaveOverdrivePassive( player ) && PlayerHasPassive( player, ePassives.PAS_TAC_UPGRADE_THREE ) ? tuning.slideMaxTime : tuning.slideMaxTimeNerfed
}

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function __________________ServerFuncs_________________________(){}
#endif

#if SERVER
void function SlideGate_PlayDeployAnim( entity gate )
{
	gate.EndSignal( "OnDestroy" )

	gate.Anim_PlayOnly( SLIDEGATE_DEPLOY_ANIM )
	WaittillAnimDone( gate )

	if ( !IsValid( gate ) )
		return

	gate.Anim_PlayOnly( SLIDEGATE_IDLE_ANIM )
}

void function SlideGate_TrackGateForOwner( entity owner, entity gate, entity trigger, entity projectile )
{
	if ( !(owner in file.slideGatesByOwner) )
		file.slideGatesByOwner[ owner ] <- []

	file.slideGatesByOwner[ owner ].append( gate )

	int maxActive = SLIDEGATE_MAX_ACTIVE
	entity weapon = projectile.GetWeaponSource()
	if ( IsValid( weapon ) && weapon.HasMod( SLIDEGATE_COOLDOWN_MOD ) )
		maxActive += 1

	while ( file.slideGatesByOwner[ owner ].len() > maxActive )
	{
		entity oldest = file.slideGatesByOwner[ owner ][ 0 ]
		file.slideGatesByOwner[ owner ].remove( 0 )
		if ( IsValid( oldest ) )
			oldest.Destroy()
	}

	thread SlideGate_LifetimeThink( owner, gate, trigger )
}

void function SlideGate_LifetimeThink( entity owner, entity gate, entity trigger )
{
	gate.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( owner, gate, trigger )
		{
			if ( IsValid( trigger ) )
				trigger.Destroy()

			if ( owner in file.slideGatesByOwner )
			{
				file.slideGatesByOwner[ owner ].fastremovebyvalue( gate )
				if ( file.slideGatesByOwner[ owner ].len() == 0 )
					delete file.slideGatesByOwner[ owner ]
			}
		}
	)

	WaitForever()
}

void function SlideGate_OnPadKilled( entity gate, var damageInfo )
{
	if ( !IsValid( gate ) )
		return

	vector origin = gate.GetOrigin()
	PlayImpactFXTable( origin, gate, SLIDEGATE_DESTRUCTION_IMPACT_TABLE )
	EmitSoundOnEntity( gate, SLIDEGATE_REMOVED )
	gate.Destroy()
}

void function SlideGate_OnEnter_Server( entity trigger, entity ent )
{
	if ( !IsValid( trigger ) || !IsValid( ent ) )
		return

	if ( !SlideGate_FilterCallback( trigger, ent ) )
		return

	entity gate = trigger.GetParent()
	if ( !IsValid( gate ) )
		return

	thread SlideGate_PlayTriggerAnim( gate )

	if ( ent.IsPhaseShifted() )
		return

	if ( IsTrainingDummie( ent ) )
	{
		SlideGate_LaunchDummie( ent, gate, FlattenNormalizeVec( AnglesToForward( ent.GetAngles() ) ) )
		return
	}

	if ( !ent.IsPlayer() )
		return

	ent.SetVelocity( SlideGate_GetLaunchDir( ent ) * SLIDEGATE_LAUNCH_SPEED )
	int stanceHandle = ent.PushForcedStance( FORCE_STANCE_CROUCH )
	StatusEffect_StopAllOfType( ent, eStatusEffect.move_slow )

	GivePlayerSettingsMods( ent, [ SLIDEGATE_BOOSTED_SLIDE_PASSIVE ] )
	bool gaveJump = DoesPlayerHaveJumpGate( ent ) && !Bleedout_IsBleedingOut( ent )
	if ( gaveJump )
		GivePlayerSettingsMods( ent, [ OVERDRIVE_SLIDE_JUMP_PASSIVE ] )

	float duration = SlideGate_GetMaxSlideTime( ent )
	StatusEffect_AddTimed( ent, eStatusEffect.slide_gate_boosting, 1.0, duration, 0.0 )

	EmitSoundOnEntity( ent, SLIDEGATE_LAUNCH_3P )
	array<entity> boostFX
	boostFX.append( StartParticleEffectOnEntity_ReturnEntity( ent, GetParticleSystemIndex( DoesPlayerHaveOverdrivePassive( ent ) ? SLIDEGATE_JUMPJETS_FX_OVERDRIVE : SLIDEGATE_JUMPJETS_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID ) )
	boostFX.append( StartParticleEffectOnEntity_ReturnEntity( ent, GetParticleSystemIndex( SLIDEGATE_TRAIL_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID ) )
	StartParticleEffectOnEntity( gate, GetParticleSystemIndex( SLIDEGATE_GATE_FX_INIT ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )

	Remote_CallFunction_NonReplay( ent, "ServerToClient_SlideGateEnter", gate )

	thread SlideGate_BoostThink( ent, gate, duration, gaveJump, stanceHandle, boostFX )
}

vector function SlideGate_GetLaunchDir( entity player )
{
	vector moveDir = player.GetVelocity()
	moveDir.z = 0.0
	if ( Length( moveDir ) > SLIDEGATE_MOVE_DIR_MIN_SPEED )
		return Normalize( moveDir )

	vector eyeAngles = player.EyeAngles()
	eyeAngles.x = 0.0
	return FlattenNormalizeVec( AnglesToForward( eyeAngles ) )
}

void function SlideGate_LaunchDummie( entity npc, entity gate, vector fwd )
{
	if ( !IsAlive( npc ) )
		return

	npc.Signal( "StopPushNPCDownToGround" )
	npc.Signal( "JumpPad_DummieInAir" )
	npc.SetVelocity( fwd * SLIDEGATE_LAUNCH_SPEED + <0, 0, SLIDEGATE_DUMMIE_HOP> )

	EmitSoundOnEntity( npc, SLIDEGATE_LAUNCH_3P )
	array<entity> boostFX
	boostFX.append( StartParticleEffectOnEntity_ReturnEntity( npc, GetParticleSystemIndex( SLIDEGATE_JUMPJETS_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID ) )
	boostFX.append( StartParticleEffectOnEntity_ReturnEntity( npc, GetParticleSystemIndex( SLIDEGATE_TRAIL_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID ) )
	StartParticleEffectOnEntity( gate, GetParticleSystemIndex( SLIDEGATE_GATE_FX_INIT ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )

	thread SlideGate_DummieBoostThink( npc, boostFX )
}

void function SlideGate_DummieBoostThink( entity npc, array<entity> boostFX )
{
	npc.Signal( SLIDEGATE_BOOST_END )
	npc.EndSignal( SLIDEGATE_BOOST_END )
	npc.EndSignal( "OnDeath" )
	npc.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( boostFX )
		{
			foreach ( entity fx in boostFX )
			{
				if ( IsValid( fx ) )
					EffectStop( fx )
			}
		}
	)

	wait SLIDEGATE_BOOST_MIN_TIME

	float endTime = Time() + tuning.slideMaxTimeNerfed - SLIDEGATE_BOOST_MIN_TIME
	while ( Time() < endTime )
	{
		if ( npc.IsOnGround() && Length2D( npc.GetVelocity() ) < SLIDEGATE_BOOST_STOP_SPEED )
			break
		WaitFrame()
	}
}

void function SlideGate_PlayTriggerAnim( entity gate )
{
	if ( !IsValid( gate ) )
		return

	gate.EndSignal( "OnDestroy" )

	gate.Anim_PlayOnly( SLIDEGATE_LAUNCH_ANIM )
	WaittillAnimDone( gate )

	if ( !IsValid( gate ) )
		return

	gate.Anim_PlayOnly( SLIDEGATE_IDLE_ANIM )
}

void function SlideGate_BoostThink( entity player, entity gate, float duration, bool gaveJump, int stanceHandle, array<entity> boostFX )
{
	player.Signal( SLIDEGATE_BOOST_END )
	player.EndSignal( SLIDEGATE_BOOST_END )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )

	EmitSoundOnEntity( player, SLIDEGATE_EFFECT_ACTIVE_3P )

	OnThreadEnd(
		function() : ( player, gaveJump, stanceHandle, boostFX )
		{
			foreach ( entity fx in boostFX )
			{
				if ( IsValid( fx ) )
					EffectStop( fx )
			}

			if ( !IsValid( player ) )
				return

			player.RemoveForcedStance( stanceHandle )
			TakePlayerSettingsMods( player, [ SLIDEGATE_BOOSTED_SLIDE_PASSIVE ] )
			if ( gaveJump )
				TakePlayerSettingsMods( player, [ OVERDRIVE_SLIDE_JUMP_PASSIVE ] )
			StatusEffect_StopAllOfType( player, eStatusEffect.slide_gate_boosting )
			StopSoundOnEntity( player, SLIDEGATE_EFFECT_ACTIVE_3P )
		}
	)

	wait SLIDEGATE_BOOST_MIN_TIME

	float endTime = Time() + duration - SLIDEGATE_BOOST_MIN_TIME
	while ( Time() < endTime )
	{
		if ( Length2D( player.GetVelocity() ) < SLIDEGATE_BOOST_STOP_SPEED )
			break
		WaitFrame()
	}

	EmitSoundOnEntity( player, SLIDEGATE_EFFECT_END_3P )
}
#endif

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function __________________ClientFuncs_________________________(){}
#endif

#if CLIENT
void function OnSlideGateTriggerCreated( entity trigger )
{
	if ( !SlideGate_IsSlideGateTrigger( trigger ) )
		return

	entity owner = trigger.GetOwner()
	if( IsValid( owner ) )
	{
		trigger.e.isJumpGate = DoesPlayerHaveJumpGate( owner )
		trigger.e.slideMaxTime = SlideGate_GetMaxSlideTime( owner )
	}

	trigger.SetClientEnterCallback( SlideGate_EnterTrigger_Client )
}

void function ServerToClient_SlideGateEnter( entity gate )
{
	entity player = GetLocalViewPlayer()

	if ( !IsValid( player ) || !IsValid( gate ) )
		return

	if ( gate in file.gateEnterTimes && Time() - file.gateEnterTimes[ gate ] < 0.5 )
		return

	file.gateEnterTimes[ gate ] <- Time()

	SlideGate_OnGateEnter1P( gate, player )
}

void function SlideGate_EnterTrigger_Client( entity trigger, entity player )
{
	entity localViewPlayer = GetLocalViewPlayer()
	if ( player != localViewPlayer )
		return

	if( !InPrediction() || !IsFirstTimePredicted() )
		return

	if ( !SlideGate_FilterCallback( trigger, player ) )
		return

	SlideGate_OnGateEnter1P( trigger, player )
}

void function SlideGate_OnGateEnter1P( entity trigger, entity player )
{
	bool isPlayerAxle = DoesPlayerHaveOverdrivePassive( player )
	string launchSound = isPlayerAxle ? SLIDEGATE_LAUNCH_1P_AXLE : SLIDEGATE_LAUNCH_1P_GENERIC
	EmitSoundOnEntity( player, launchSound )

	bool playerIsBleedingOut = Bleedout_IsBleedingOut( player )
	if( trigger.e.isJumpGate && !playerIsBleedingOut )
	{
		SlideGate_DisplaySlideJumpHint( trigger.e.slideMaxTime, player )
	}
}

void function SlideGate_DisplaySlideJumpHint( float slideMaxTime, entity player )
{
	bool movementKeyBound = IsMovementAbilityKeySet()
	string hint = movementKeyBound ? "#ABL_PAS_SLIDE_MOVEMENT_KEY_SET_JUMP_HINT" : "#ABL_PAS_SLIDE_DEFAULT_JUMP_HINT"
	AddPlayerHint( slideMaxTime, 0.10, $"", hint )

	file.movementKeyBoundHint = hint
}

void function OnSlideGateCreated( entity slideGate )
{
	if ( !IsValid( slideGate ) )
		return

	slideGate.Highlight_SetFarFadeDist( tuning.gateHighlightFadeDist )

	entity owner = slideGate.GetOwner()
	bool isJumpGate = IsValid( owner ) && DoesPlayerHaveJumpGate( owner )
	int coreFX = StartParticleEffectOnEntity( slideGate, GetParticleSystemIndex( isJumpGate ? SLIDEGATE_CORE_UPGRADE_FX : SLIDEGATE_CORE_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	int arrowsFX = StartParticleEffectOnEntity( slideGate, GetParticleSystemIndex( SLIDEGATE_BRACKET_ARROWS_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	int pathFX = StartParticleEffectOnEntity( slideGate, GetParticleSystemIndex( SLIDEGATE_PATH_ARROWS_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
}

void function MinimapPackage_SlideGate( entity ent, var rui )
{
	RuiSetImage( rui, "defaultIcon", $"rui/hud/tactical_icons/tactical_overdrive" )
	RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/tactical_icons/tactical_overdrive" )
	RuiSetBool( rui, "useTeamColor", false )
	RuiSetFloat( rui, "iconBlend", 0.0 )
}

void function OnClientAnimEvent_DeploySlideGate( entity weapon, string name )
{
	if ( !IsValid( weapon ) )
		return

	if ( name == SLIDEGATE_DEPLOY_SCREEN_SHAKE )
		ClientScreenShake( SHAKE_AMPLITUDE, SHAKE_FREQUENCY, SHAKE_DURATION, SHAKE_DIRECTION )
}

void function StartSlideGateBoostFX( entity player, int statusEffect, bool actuallyChanged )
{
	if ( player != GetLocalViewPlayer() || (GetLocalViewPlayer() == GetLocalClientPlayer() && !actuallyChanged) )
		return

	if ( StatusEffect_GetSeverity( player, statusEffect ) < 1 )
		return

	entity cockpit = player.GetCockpit()
	if ( !IsValid( cockpit ) )
		return

	Signal( player, "WreckingBall_CleanupFX" )

	ScreenFlash( SLIDEGATE_FLASH_COLOR.x, SLIDEGATE_FLASH_COLOR.y, SLIDEGATE_FLASH_COLOR.z, 0.15, 0.3 )
	Chroma_StartStimEffect()

	thread (void function() : ( player ) {
		EndSignal( player, "OnDeath", SLIDEGATE_FX_END )

		int fxHandle = StartParticleEffectOnEntityWithPos( player,
			GetParticleSystemIndex( SLIDEGATE_ACTIVE_1P_FX ),
			FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID, player.EyePosition(), <0, 0, 0> )

		EffectSetIsWithCockpit( fxHandle, true )

		OnThreadEnd( function() : ( player, fxHandle ) {
			CleanupFXHandle( fxHandle, false, true )
			HidePlayerHint( file.movementKeyBoundHint )

			bool isPlayerAxle = DoesPlayerHaveOverdrivePassive( player )
			string launchSound = isPlayerAxle ? SLIDEGATE_LAUNCH_1P_AXLE : SLIDEGATE_LAUNCH_1P_GENERIC
			StopSoundOnEntity( player, launchSound )
		} )

		while( true )
		{
			if ( !EffectDoesExist( fxHandle ) )
				break

			WaitFrame()
		}
	})()
}

bool function IsMovementAbilityKeySet()
{
	return !IsControllerModeActive() && GetKeyCodeForBinding( "+dodge", 0 ) != GetKeyCodeForBinding( "+jump", 0 )
}

void function StopSlideGateBoostFX( entity player, int statusEffect, bool actuallyChanged )
{
	if ( player != GetLocalViewPlayer() || (GetLocalViewPlayer() == GetLocalClientPlayer() && !actuallyChanged) )
		return

	player.Signal( SLIDEGATE_FX_END )
}
#endif
