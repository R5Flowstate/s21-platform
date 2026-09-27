global function MpWeaponFollowingMedic_Init

global function OnWeaponOwnerChanged_ability_following_medic
global function OnWeaponAttemptOffhandSwitch_following_medic
global function OnWeaponActivate_following_medic
global function OnWeaponDeactivate_following_medic
global function OnWeaponPrimaryAttackAnimEvent_ability_follow_medic
global function PlayerDroneIsAssignedToAValidTarget

#if SERVER
global function ClientCallback_DroneMedic_TryAssignOrRecall
global function FollowMedic_GetDrone
#endif

#if CLIENT
global function GetLifelineTacticalRui
global function GetAllyDroneTacticalRui
global function ServerToClient_CreateSimpleFollowRuiForDroneTarget
global function ServerToClient_DestroySimpleFollowRuiForDroneTarget
global function ServerToClient_FollowDroneAttachedTetherFX
#endif

global const string FOLLOW_MEDIC_SCRIPT_NAME = "follow_medic"
global const string FOLLOW_MEDIC_WEAPON_NAME = "mp_ability_lifeline_follow_medic"

global const string LIFELINE_DRONE_FOLLOW_ENT_NETVAR = "lifeline_drone_follow_ent"
const string LIFELINE_DRONE_BEST_TARGET_NETVAR = "follow_drone_bestTarget"
global const string LIFELINE_DRONE_LIFETIME_NETVAR = "lifeline_drone_lifetime"

const asset DEPLOYABLE_MEDIC_DRONE_MODEL = $"mdl/props/lifeline_drone_rework/lifeline_drone_rework.rmdl"

const asset FX_DRONE_MEDIC_JET_CTR = $"P_LL_med_drone_jet_ctr_loop"
const asset FX_DRONE_MEDIC_EYE = $"P_LL_med_drone_eye"
const asset FX_DRONE_MEDIC_JET_LOOP = $"P_LL_med_drone_jet_loop"
const asset FX_DRONE_MEDIC_HEAL_COCKPIT_FX = $"P_heal_loop_screen"
const asset FOLLOW_DRONE_TELEPORT_TRAIL_FX = $"P_LLR_DOC_trail"
const asset FOLLOW_DRONE_ATTACHED_FX_1P = $"P_LLR_DOC_screen_indicator"

const string FOLLOW_MEDIC_HOVER_3P = "LifelineRevived_Tac_Drone_Mvmt_Hover_3p"
const string DEPLOYABLE_MEDIC_DEPLOY_CABLE_SOUND = "Lifeline_Drone_Cable_Deploy_3P"
const string DEPLOYABLE_MEDIC_ATTACH_SOUND_1P = "Lifeline_Drone_Attach_1P"
const string DEPLOYABLE_MEDIC_ATTACH_SOUND_3P = "Lifeline_Drone_Attach_3P"
const string DEPLOYABLE_MEDIC_DETATCH_SOUND_1P = "Lifeline_Drone_Detach_1P"
const string DEPLOYABLE_MEDIC_DETATCH_SOUND_3P = "Lifeline_Drone_Detach_3P"
const string DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_1P = "Lifeline_Drone_Healing_1P"
const string DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_3P = "Lifeline_Drone_Healing_3P"

const string FOLLOW_DRONE_FAILURE_TO_ASSIGN_1P = "LifelineRevived_Tac_Assign_Failed_1p"
const string FOLLOW_DRONE_ASSIGN_1P = "LifelineRevived_Tac_Assign_1p"
const string FOLLOW_DRONE_ASSIGN_3P = "LifelineRevived_Tac_Assign_Foley_3p"
const string FOLLOW_DRONE_RECALL_1P = "LifelineRevived_Tac_Recall_1p"
const string FOLLOW_DRONE_FLY_OUT_3P = "LifelineRevived_Tac_Drone_InitialFlyOut_3p"
const string TELEPORT_DEPARTURE_SOUND = "LifelineRevived_Tac_WarpOut_3p"
const string TELEPORT_ARRIVAL_SOUND = "LifelineRevived_Tac_WarpIn_3p"
const string GEO_PHASE_DEPARTURE_SOUND = "LifelineRevived_Tac_WarpOut_Quiet_3p"
const string GEO_PHASE_ARRIVAL_SOUND = "LifelineRevived_Tac_WarpIn_Quiet_3p"

const string MEDIC_ASSIGN_VO 		= "bc_tactical_assign"
const string MEDIC_ASSIGN_SOLO_VO 	= "bc_tactical_assignSelf"
const string MEDIC_RECALL_VO 		= "bc_tactical_recall"

const float FOLLOW_MEDIC_MAX_LIFETIME = 20

const int DEPLOYABLE_MEDIC_HEAL_MAX_TARGETS = 5
const float DEPLOYABLE_MEDIC_HEAL_START_DELAY = 1.0
const float DEPLOYABLE_MEDIC_HEAL_RADIUS = 256.0
const float HEAL_TRIGGER_ABOVE_HEIGHT = 92
const float HEAL_TRIGGER_BELOW_HEIGHT = 80
const float FOLLOW_MEDIC_HEAL_PER_SEC = 8

const int ROPE_NODE_COUNT = 10
const float ROPE_LENGTH_MOD = 50
const float ROPE_SHOOT_OUT_TIME = 0.25
const float ROPE_REAL_IN_TIME = 0.25
const float MAX_ROPE_BREAK_DISTANCE_MOD = 100

const int FOLLOW_MEDIC_HEAL_WARNING_THRESHOLD = 0
const float DRONE_ASSIGNMENT_TARGETING_DISTANCE = 45 * METERS_TO_INCHES
const float TARGETING_CONE_DOT = DOT_50DEGREE
const float FOLLOW_DRONE_ORDER_DEBOUNCE = 0.25
const float FOLLOW_DRONE_ASSIGNMENT_TETHER_FX_DURATION = 2.0

const float MEDIC_FOLLOW_MIN_DISTANCE = 60.0
const float MEDIC_FOLLOW_MAX_DISTANCE = 85.0
const float MEDIC_FOLLOW_TARGET_DISTANCE_TOLERANCE_SQR = 100.0
const float MEDIC_FOLLOW_MIN_DISTANCE_CROUCHED = 35.0
const float MEDIC_FOLLOW_MAX_DISTANCE_CROUCHED = 45.0
const float DRONE_MIN_HOVER_HEIGHT = 40.0
const float HEIGHT_CORRECTION_TOLERANCE = 1.0
const float PARENT_GROUND_HEIGHT_DIFF_TOLERANCE = 7.0

const float BASE_SPEED_MULTIPLIER = 40.0
const float ADJUSTMENT_SPEED_MULTIPLIER = 3.0
const float VELOCITY_DECELERATION_DISTANCE = 7.0
const float PARENT_VELOCITY_FRACTION = 0.5
const float MAX_DISTANCE_FROM_TARGET_POS = 50.0
const float MAX_PARENT_VELOCITY_MULTIPLIER = 0.6

const vector HULL_OFFSET = <0.0, 0.0, 0.0>
const float HULL_SCALE_FACTOR = 0.7

const float DRONE_POSE_PARAM_MAX_VAL = 45.0
const float DRONE_VEL_TO_PITCH_MAX = 20.0
const float DRONE_TURN_TO_ROLL_MAX = 17.0

const vector DRONE_VEHICLE_OFFSET = <0,0,10.0>

#if SERVER
const vector FOLLOW_DRONE_MINS = <-9, -9, -10>
const vector FOLLOW_DRONE_MAXS = <9, 9, 10>
// Height above the followed player's origin, standing and crouched.
const float FOLLOW_DRONE_HEIGHT = 70.0
const float FOLLOW_DRONE_HEIGHT_CROUCHED = 46.0
const float FOLLOW_DRONE_LOS_TELEPORT_TIME = 1.0
const float FOLLOW_DRONE_DESPAWN_GRACE = 10.0
const float FOLLOW_DRONE_TARGET_SCAN_INTERVAL = 0.1
#endif

enum eLockResult
{
	FAILED_GENERIC,
	FAILED_OUT_OF_RANGE,
	FAILED_NOT_FACING_ALLY,
	SUCCESS,
}

#if SERVER
struct FollowDroneRope
{
	entity playerRope
	entity playerRopeEnd
	entity otherRope
	entity otherRopeEnd
}

struct FollowDroneData
{
	entity drone
	entity owner
	entity followTarget
	float  endTime
	array<entity> particles
	array<entity> healTargets
	table<entity, int> healResourceIDs
	table<entity, int> statusEffectIDs
	table<entity, float> inRangeSince
	table<entity, FollowDroneRope> ropes
}
#endif

struct
{
	#if SERVER
		table< entity, FollowDroneData > droneByOwner
	#endif

	#if CLIENT
		int healFxHandle
		var droneFollowRui
		var allyDroneLeashedRui
		array<entity> trackedAllies
	#endif

	table< entity, float > lastDroneOrderTime

	float droneLifetime

	bool healThroughWallsEnabled
	bool attachedPlayerBlocksDespawns
	float healRadius
	float healPerSec

	int healWarningThreshold
	float targetingDistance
	float targetingConeDOT
	float assignOrderDebounce
	float assignTetherFxDuration

	bool pitchParamEnabled
	bool rollParamEnabled
	float velToPitchMax
	float turnToRollmax
} file

void function MpWeaponFollowingMedic_Init()
{
	PrecacheScriptString( FOLLOW_MEDIC_SCRIPT_NAME )
	PrecacheWeapon( FOLLOW_MEDIC_WEAPON_NAME )

	PrecacheModel( DEPLOYABLE_MEDIC_DRONE_MODEL )
	PrecacheMaterial( $"models/cable/drone_medic_cable" )

	PrecacheParticleSystem( FX_DRONE_MEDIC_JET_CTR )
	PrecacheParticleSystem( FX_DRONE_MEDIC_EYE )
	PrecacheParticleSystem( FX_DRONE_MEDIC_JET_LOOP )
	PrecacheParticleSystem( FX_DRONE_MEDIC_HEAL_COCKPIT_FX )
	PrecacheParticleSystem( FOLLOW_DRONE_TELEPORT_TRAIL_FX )
	PrecacheParticleSystem( FOLLOW_DRONE_ATTACHED_FX_1P )

	RegisterNetworkedVariable( LIFELINE_DRONE_FOLLOW_ENT_NETVAR, SNDC_PLAYER_EXCLUSIVE, SNVT_ENTITY )
	RegisterNetworkedVariable( LIFELINE_DRONE_BEST_TARGET_NETVAR, SNDC_PLAYER_EXCLUSIVE, SNVT_ENTITY )
	RegisterNetworkedVariable( LIFELINE_DRONE_LIFETIME_NETVAR, SNDC_PLAYER_GLOBAL, SNVT_TIME, -1 )

	RegisterSignal( "TargetingStop" )
	RegisterSignal( "FollowMedic_End" )

	#if CLIENT
		RegisterConCommandTriggeredCallback( "+offhand1", FollowMedic_OnAbilityButtonPressed )
		RegisterConCommandTriggeredCallback( "+scriptCommand5", FollowMedic_OnCharacterButtonPressed )
		RegisterNetVarEntityChangeCallback( LIFELINE_DRONE_FOLLOW_ENT_NETVAR, LifelineDroneFollowPlayerChanged )
		AddCallback_OnWeaponStatusUpdate( LifelineDrone_WeaponStatusCheck )

		AddCallback_CreatePlayerPassiveRui( CreateLifelineTacticalRui_Internal )
		AddCallback_DestroyPlayerPassiveRui( DestroyLifelineTacticalRui )

		RegisterSignal( "EndDroneTether1PFX" )
		RegisterSignal( "EndLifelineTacticalRUI" )
	#endif

	#if SERVER
		AddCallback_OnPlayerKilled( FollowMedic_OnPlayerKilled )
		AddCallback_OnClientDisconnected( FollowMedic_OnClientDisconnected )
	#endif

	Remote_RegisterClientFunction( "ServerToClient_CreateSimpleFollowRuiForDroneTarget", "entity" )
	Remote_RegisterClientFunction( "ServerToClient_DestroySimpleFollowRuiForDroneTarget" )
	Remote_RegisterClientFunction( "ServerToClient_FollowDroneAttachedTetherFX", "entity" )

	Remote_RegisterServerFunction( "ClientCallback_DroneMedic_TryAssignOrRecall", "bool" )

	file.droneLifetime					= GetCurrentPlaylistVarFloat( "lifeline_follow_medic_lifetime", FOLLOW_MEDIC_MAX_LIFETIME )

	file.healThroughWallsEnabled 		= GetCurrentPlaylistVarBool( "lifeline_follow_drone_healThroughWalls", true )
	file.attachedPlayerBlocksDespawns	= GetCurrentPlaylistVarBool( "lifeline_follow_drone_healBlocksDespawns", true )

	file.healRadius						= GetCurrentPlaylistVarFloat( "lifeline_follow_medic_healRadius", DEPLOYABLE_MEDIC_HEAL_RADIUS )
	file.healPerSec						= GetCurrentPlaylistVarFloat( "lifeline_follow_drone_healPerSec", FOLLOW_MEDIC_HEAL_PER_SEC )

	file.healWarningThreshold 			= GetCurrentPlaylistVarInt( "lifeline_follow_drone_heal_warning_threshold", FOLLOW_MEDIC_HEAL_WARNING_THRESHOLD )
	file.targetingDistance				= GetCurrentPlaylistVarFloat( "lifeline_follow_medic_targetingDistance", DRONE_ASSIGNMENT_TARGETING_DISTANCE )
	file.targetingConeDOT				= GetCurrentPlaylistVarFloat( "lifeline_follow_medic_targetingCone", TARGETING_CONE_DOT )
	file.assignOrderDebounce 			= GetCurrentPlaylistVarFloat( "lifeline_follow_drone_order_debounce", FOLLOW_DRONE_ORDER_DEBOUNCE )
	file.assignTetherFxDuration 		= GetCurrentPlaylistVarFloat( "lifeline_follow_drone_assign_thether_fx_duration", FOLLOW_DRONE_ASSIGNMENT_TETHER_FX_DURATION )

	file.pitchParamEnabled				= GetCurrentPlaylistVarBool( "lifeline_follow_drone_pitchParamEnabled", true )
	file.rollParamEnabled				= GetCurrentPlaylistVarBool( "lifeline_follow_drone_rollParamEnabled", true )
	file.velToPitchMax				    = GetCurrentPlaylistVarFloat( "lifeline_follow_medic_velToPitchMax", DRONE_VEL_TO_PITCH_MAX )
	file.turnToRollmax			        = GetCurrentPlaylistVarFloat( "lifeline_follow_medic_turnToRollmax", DRONE_TURN_TO_ROLL_MAX )
}

bool function PlayerDroneIsAssignedToAValidTarget( entity player )
{
	return IsValid( player.GetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR ) )
}

void function OnWeaponOwnerChanged_ability_following_medic( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if CLIENT
	if ( weapon.GetOwner() == GetLocalClientPlayer() )
	#endif
	{
		if ( IsValid( changeParams.oldOwner ) )
		{
			changeParams.oldOwner.Signal( "TargetingStop" )
			#if SERVER
				if ( changeParams.oldOwner.IsPlayer() )
					FollowMedic_End( changeParams.oldOwner )
			#endif
		}

		if ( IsValid( changeParams.newOwner ) && changeParams.newOwner.IsPlayer() )
		{
			thread FollowMedic_TargetingThread( changeParams.newOwner, weapon )
		}
	}
}

bool function OnWeaponAttemptOffhandSwitch_following_medic( entity weapon )
{
	entity owner = weapon.GetOwner()
	if( !IsValid( owner ) )
		return false

	return !PlayerDroneIsAssignedToAValidTarget( owner )
}

void function OnWeaponActivate_following_medic( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return

	entity followOrdersWeapon = GetFollowOrdersWeapon( owner )
	if( IsValid( owner.GetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR ) ) )
	{
		#if CLIENT
		if( InPrediction() )
		#endif
		{
			weapon.AddMod( MEDIC_ASSIGN_MOD )
			if( IsValid( followOrdersWeapon ) && followOrdersWeapon.GetWeaponClassName() == MEDIC_ORDERS_WEAPON_NAME )
			{
				if( !followOrdersWeapon.HasMod( MEDIC_ASSIGN_MOD ) )
					followOrdersWeapon.AddMod( MEDIC_ASSIGN_MOD )
			}
		}
	}
	else
	{
		#if CLIENT
		if( InPrediction() )
		#endif
		{
			weapon.RemoveMod( MEDIC_ASSIGN_MOD )
			if( IsValid( followOrdersWeapon ) && followOrdersWeapon.GetWeaponClassName() == MEDIC_ORDERS_WEAPON_NAME )
			{
				if( followOrdersWeapon.HasMod( MEDIC_ASSIGN_MOD ) )
					followOrdersWeapon.RemoveMod( MEDIC_ASSIGN_MOD )
			}
		}
	}

	#if CLIENT
		if( file.droneFollowRui != null )
			RuiSetFloat( file.droneFollowRui, "orderedTransitionTime", Time() )
	#endif
}

void function OnWeaponDeactivate_following_medic( entity weapon )
{

}

var function OnWeaponPrimaryAttackAnimEvent_ability_follow_medic( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return

	int ammoReq = weapon.GetAmmoPerShot()

	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	PlayerUsedOffhand( owner, weapon )

	#if SERVER
		FollowMedic_Deploy( owner, attackParams.pos )
	#endif

	return ammoReq
}

float function GetRemainingDroneLifetime( entity player )
{
	return max( player.GetPlayerNetTime( LIFELINE_DRONE_LIFETIME_NETVAR ) - Time(), 0.0 )
}

float function GetDroneAssignmentUpgradedRangeScaler()
{
	return GetCurrentPlaylistVarFloat( "upgrade_lifeline_doc_range_scaler", 1.5 )
}

float function GetDroneAssignmentRange( entity player )
{
	float result = file.targetingDistance

	if( PlayerHasPassive( player, ePassives.PAS_TAC_UPGRADE_ONE ) )
		result *= GetDroneAssignmentUpgradedRangeScaler()

	return result
}

float function GetDroneAssignmentRangeSqr( entity player )
{
	float range = GetDroneAssignmentRange( player )
	return range * range
}

float function GetDroneMaxRopeLength()
{
	return file.healRadius + ROPE_LENGTH_MOD
}

float function GetMaxRopeBreakDistance()
{
	return GetDroneMaxRopeLength() + MAX_ROPE_BREAK_DISTANCE_MOD
}

float function GetMaxRopeBreakDistanceSqr()
{
	float ropeDist = GetMaxRopeBreakDistance()
	return ( ropeDist * ropeDist )
}

void function FollowMedic_TargetingThread( entity player, entity weapon )
{
	EndSignal( weapon, "OnDestroy" )
	EndSignal( player, "OnDeath", "OnDestroy", "TargetingStop" )

	if ( !IsValid( player ) )
		return

	bool tacticalIncludeAlliances = GetCurrentPlaylistVarBool( "lifeline_tactical_includes_alliances", false )

	#if SERVER
		OnThreadEnd(
			function() : ( player )
			{
				if ( IsValid( player ) )
					player.SetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR, null )
			}
		)
	#endif

	array<entity> allyArray
	while ( true )
	{
		allyArray = GetArrayOfPossibleAlliesForPlayer( player, tacticalIncludeAlliances )

		#if SERVER
			entity bestTarget = FollowMedic_FindBestTarget( player, allyArray )
			if ( player.GetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR ) != bestTarget )
				player.SetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR, bestTarget )
			wait FOLLOW_DRONE_TARGET_SCAN_INTERVAL
		#elseif CLIENT
			foreach ( ally in allyArray )
			{
				if ( ally == player )
					continue
				if ( !file.trackedAllies.contains( ally ) )
					thread SingleTargetRui_Thread( player, ally, weapon )
			}
			WaitFrame()
		#endif
	}
}

void function TryDroneAssignOrRecall( entity player, bool isRecalling = false )
{
	if( player in file.lastDroneOrderTime )
	{
		if( Time() - file.lastDroneOrderTime[player] <= file.assignOrderDebounce )
			return
	}

	entity currentFollowTarget = player.GetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR )
	entity bestNewTarget = player.GetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR )

	if( currentFollowTarget != player && isRecalling )
	{
		IssueOrderToDrone( player, false )
		#if SERVER
			FollowMedic_SetFollowTarget( player, player )
			PlayBattleChatterLineToSpeakerAndTeam( player, MEDIC_RECALL_VO )
		#endif

		if( player in file.lastDroneOrderTime )
			file.lastDroneOrderTime[player] = Time()
		else
			file.lastDroneOrderTime[player] <- Time()
	}
	else if( IsValid( bestNewTarget ) && !isRecalling && currentFollowTarget != bestNewTarget && DistanceSqr( player.GetOrigin(), bestNewTarget.GetOrigin() ) <= GetDroneAssignmentRangeSqr( player ) )
	{
		IssueOrderToDrone( player, true )
		#if SERVER
			FollowMedic_SetFollowTarget( player, bestNewTarget )
			PlayBattleChatterLineToSpeakerAndTeam( player, bestNewTarget == player ? MEDIC_ASSIGN_SOLO_VO : MEDIC_ASSIGN_VO )
		#endif

		if( player in file.lastDroneOrderTime )
			file.lastDroneOrderTime[player] = Time()
		else
			file.lastDroneOrderTime[player] <- Time()
	}
	else
	{
		#if CLIENT
			EmitSoundOnEntity( player, FOLLOW_DRONE_FAILURE_TO_ASSIGN_1P )
		#endif
	}
}

void function IssueOrderToDrone( entity player, bool isBeingAssigned )
{
	entity followOrdersWeapon = GetFollowOrdersWeapon( player )

	if( IsValid( followOrdersWeapon ) && followOrdersWeapon.GetWeaponClassName() == MEDIC_ORDERS_WEAPON_NAME )
		followOrdersWeapon.w.droneIsAssginedToATarget = isBeingAssigned

	player.TrySelectOffhand( MEDIC_ORDERS_OFFHAND_SLOT )
}

entity function GetFollowOrdersWeapon( entity player )
{
	return player.GetOffhandWeapon( MEDIC_ORDERS_OFFHAND_SLOT )
}

#if SERVER
entity function FollowMedic_GetDrone( entity owner )
{
	if ( !( owner in file.droneByOwner ) )
		return null
	return file.droneByOwner[owner].drone
}

void function ClientCallback_DroneMedic_TryAssignOrRecall( entity player, bool isRecalling )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return
	if ( !IsPlayerLifelineRevived( player ) )
		return
	if ( !( player in file.droneByOwner ) || !IsValid( file.droneByOwner[player].drone ) )
		return
	if ( Bleedout_IsBleedingOut( player ) )
		return

	TryDroneAssignOrRecall( player, isRecalling )
}

entity function FollowMedic_FindBestTarget( entity player, array<entity> allies )
{
	float rangeSqr = GetDroneAssignmentRangeSqr( player )
	vector eyePos = player.EyePosition()
	vector viewVec = player.GetViewVector()

	entity bestTarget = null
	float bestDot = file.targetingConeDOT
	foreach ( ally in allies )
	{
		if ( ally == player || !IsValid( ally ) || !IsAlive( ally ) )
			continue
		if ( !IsFriendlyTeam( ally.GetTeam(), player.GetTeam() ) || !ally.DoesShareRealms( player ) )
			continue
		if ( Bleedout_IsBleedingOut( ally ) )
			continue
		if ( DistanceSqr( player.GetOrigin(), ally.GetOrigin() ) > rangeSqr )
			continue

		float dot = DotProduct( Normalize( ally.GetWorldSpaceCenter() - eyePos ), viewVec )
		if ( dot < bestDot )
			continue

		bestDot = dot
		bestTarget = ally
	}

	return bestTarget
}

void function FollowMedic_Deploy( entity owner, vector handPos )
{
	FollowMedic_End( owner )

	entity target = owner.GetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR )
	if ( !IsValid( target ) || !IsAlive( target ) || !IsFriendlyTeam( target.GetTeam(), owner.GetTeam() ) || !target.DoesShareRealms( owner ) )
		target = owner

	entity drone = CreateEntity( "script_mover" )
	drone.kv.solid = 0
	drone.kv.fadedist = -1
	drone.kv.SpawnAsPhysicsMover = 0
	drone.SetValueForModelKey( DEPLOYABLE_MEDIC_DRONE_MODEL )
	drone.SetOrigin( handPos )
	drone.SetAngles( <0, owner.EyeAngles().y, 0> )
	DispatchSpawn( drone )

	drone.DisableHibernation()
	drone.SetMaxHealth( 100 )
	drone.SetHealth( 100 )
	drone.SetTakeDamageType( DAMAGE_NO )
	drone.SetDamageNotifications( false )
	drone.SetDeathNotifications( false )
	drone.SetScriptName( FOLLOW_MEDIC_SCRIPT_NAME )
	drone.SetBlocksRadiusDamage( false )
	drone.SetOwner( owner )
	SetTeam( drone, owner.GetTeam() )
	drone.SetCanBeMeleed( false )
	drone.RemoveFromAllRealms()
	drone.AddToOtherEntitysRealms( owner )
	drone.e.ignoreJumpPad = true
	Highlight_SetOwnedHighlight( drone, "sp_friendly_hero" )
	Highlight_SetFriendlyHighlight( drone, "sp_friendly_hero" )
	drone.Highlight_Enable()
	AddSonarDetectionForPropScript( drone )
	FiringRange_AddToRemoveOnCharacterChange( drone, owner )

	FollowDroneData data
	data.drone = drone
	data.owner = owner
	data.followTarget = owner
	data.endTime = Time() + file.droneLifetime
	file.droneByOwner[owner] <- data

	owner.SetPlayerNetTime( LIFELINE_DRONE_LIFETIME_NETVAR, data.endTime )
	owner.SetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR, owner )

	EmitSoundOnEntity( drone, FOLLOW_DRONE_FLY_OUT_3P )
	EmitSoundOnEntity( drone, FOLLOW_MEDIC_HOVER_3P )
	FollowMedic_StartDroneFX( data )

	if ( target != owner )
		FollowMedic_SetFollowTarget( owner, target )

	thread FollowMedic_LifetimeThread( data )
	thread FollowMedic_MoveThread( data )
	thread FollowMedic_HealThread( data )
	thread FollowMedic_DroneAnims( drone )
}

void function FollowMedic_DroneAnims( entity drone )
{
	EndSignal( drone, "OnDestroy", "FollowMedic_End" )

	if ( drone.LookupSequence( "deploy_F" ) != -1 )
	{
		drone.Anim_PlayOnly( "deploy_F" )
		WaittillAnimDone( drone )
	}
	if ( drone.LookupSequence( "lifeline_drone_floating" ) != -1 )
		drone.Anim_PlayOnly( "lifeline_drone_floating" )
}

void function FollowMedic_StartDroneFX( FollowDroneData data )
{
	entity drone = data.drone
	int fxID_VENT = drone.LookupAttachment( "VENT_BOT" )
	int fxID_EYE  = drone.LookupAttachment( "EYEGLOW" )
	array<string> vents = [ "VENT_RF", "VENT_LF", "VENT_RR", "VENT_LR" ]

	if ( fxID_VENT > 0 )
		data.particles.append( StartParticleEffectOnEntity_ReturnEntity( drone, GetParticleSystemIndex( FX_DRONE_MEDIC_JET_CTR ), FX_PATTACH_POINT_FOLLOW, fxID_VENT ) )
	if ( fxID_EYE > 0 )
		data.particles.append( StartParticleEffectOnEntity_ReturnEntity( drone, GetParticleSystemIndex( FX_DRONE_MEDIC_EYE ), FX_PATTACH_POINT_FOLLOW, fxID_EYE ) )
	foreach ( vent in vents )
	{
		int id = drone.LookupAttachment( vent )
		if ( id > 0 )
			data.particles.append( StartParticleEffectOnEntity_ReturnEntity( drone, GetParticleSystemIndex( FX_DRONE_MEDIC_JET_LOOP ), FX_PATTACH_POINT_FOLLOW, id ) )
	}
}

void function FollowMedic_SetFollowTarget( entity owner, entity target )
{
	if ( !( owner in file.droneByOwner ) )
		return

	FollowDroneData data = file.droneByOwner[owner]
	entity oldTarget = data.followTarget
	if ( oldTarget == target )
		return

	if ( IsValid( oldTarget ) && oldTarget != owner && oldTarget.IsPlayer() )
		Remote_CallFunction_NonReplay( oldTarget, "ServerToClient_DestroySimpleFollowRuiForDroneTarget" )

	data.followTarget = target
	owner.SetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR, target )

	if ( target == owner )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, FOLLOW_DRONE_RECALL_1P )
		return
	}

	EmitSoundOnEntityOnlyToPlayer( owner, owner, FOLLOW_DRONE_ASSIGN_1P )
	if ( IsValid( data.drone ) )
		EmitSoundOnEntity( data.drone, FOLLOW_DRONE_ASSIGN_3P )

	if ( target.IsPlayer() )
	{
		Remote_CallFunction_NonReplay( target, "ServerToClient_CreateSimpleFollowRuiForDroneTarget", owner )
		Remote_CallFunction_NonReplay( target, "ServerToClient_FollowDroneAttachedTetherFX", data.drone )
	}
}

void function FollowMedic_End( entity owner )
{
	if ( !( owner in file.droneByOwner ) )
		return

	FollowDroneData data = file.droneByOwner[owner]
	delete file.droneByOwner[owner]

	foreach ( player, id in data.healResourceIDs )
	{
		if ( IsValid( player ) )
			EntityHealResource_Remove( player, id )
	}
	foreach ( player, id in data.statusEffectIDs )
	{
		if ( IsValid( player ) )
		{
			StatusEffect_Stop( player, id )
			StopSoundOnEntity( player, DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_1P )
		}
	}
	foreach ( player, rope in data.ropes )
		thread FollowMedic_RetractRope( data.drone, player, rope )

	foreach ( particle in data.particles )
	{
		if ( IsValid( particle ) )
			particle.Destroy()
	}

	entity target = data.followTarget
	if ( IsValid( target ) && target != owner && target.IsPlayer() )
		Remote_CallFunction_NonReplay( target, "ServerToClient_DestroySimpleFollowRuiForDroneTarget" )

	if ( IsValid( owner ) )
	{
		owner.SetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR, null )
		owner.SetPlayerNetTime( LIFELINE_DRONE_LIFETIME_NETVAR, -1 )
	}

	entity drone = data.drone
	if ( IsValid( drone ) )
	{
		drone.Signal( "FollowMedic_End" )
		StopSoundOnEntity( drone, FOLLOW_MEDIC_HOVER_3P )
		StopSoundOnEntity( drone, DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_3P )
		EmitSoundAtPosition( TEAM_UNASSIGNED, drone.GetOrigin(), DEPLOYABLE_MEDIC_DISSOLVE_SOUND, drone )
		RemoveSonarDetectionForPropScript( drone )
		Highlight_ClearOwnedHighlight( drone )
		Highlight_ClearFriendlyHighlight( drone )
		drone.Dissolve( ENTITY_DISSOLVE_CORE, ZERO_VECTOR, 500 )
	}
}

void function FollowMedic_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim in file.droneByOwner )
		FollowMedic_End( victim )

	foreach ( owner, data in clone file.droneByOwner )
	{
		if ( data.followTarget == victim && IsValid( owner ) )
			FollowMedic_SetFollowTarget( owner, owner )
	}
}

void function FollowMedic_OnClientDisconnected( entity player )
{
	FollowMedic_OnPlayerKilled( player, null, null )
}

void function FollowMedic_LifetimeThread( FollowDroneData data )
{
	entity drone = data.drone
	entity owner = data.owner
	EndSignal( drone, "OnDestroy", "FollowMedic_End" )
	EndSignal( owner, "OnDestroy", "CleanupAllDroneMedics" )
	EndThreadOn_PlayerChangedClass( owner )

	OnThreadEnd(
		function() : ( owner, drone )
		{
			if ( IsValid( owner ) && ( owner in file.droneByOwner ) && file.droneByOwner[owner].drone == drone )
				FollowMedic_End( owner )
		}
	)

	while ( Time() < data.endTime )
		WaitFrame()

	// A drone still healing someone finishes that heal before it leaves.
	float graceEnd = Time() + FOLLOW_DRONE_DESPAWN_GRACE
	while ( file.attachedPlayerBlocksDespawns && data.healTargets.len() > 0 && Time() < graceEnd )
		WaitFrame()
}

vector function FollowMedic_DesiredPos( entity target )
{
	bool crouched = target.IsPlayer() && target.IsCrouched()
	float dist = crouched ? ( MEDIC_FOLLOW_MIN_DISTANCE_CROUCHED + MEDIC_FOLLOW_MAX_DISTANCE_CROUCHED ) * 0.5 : ( MEDIC_FOLLOW_MIN_DISTANCE + MEDIC_FOLLOW_MAX_DISTANCE ) * 0.5
	float height = crouched ? FOLLOW_DRONE_HEIGHT_CROUCHED : FOLLOW_DRONE_HEIGHT

	vector yawAngles = <0, target.EyeAngles().y, 0>
	vector offsetDir = Normalize( AnglesToRight( yawAngles ) - AnglesToForward( yawAngles ) * 0.6 )
	vector desired = target.GetOrigin() + offsetDir * dist + <0, 0, max( height, DRONE_MIN_HOVER_HEIGHT )>

	vector traceStart = target.GetOrigin() + <0, 0, height>
	TraceResults tr = TraceHull( traceStart, desired, FOLLOW_DRONE_MINS * HULL_SCALE_FACTOR, FOLLOW_DRONE_MAXS * HULL_SCALE_FACTOR, [ target ], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
	return tr.endPos + HULL_OFFSET
}

bool function FollowMedic_HasLOS( entity drone, entity target )
{
	TraceResults tr = TraceLine( drone.GetOrigin(), target.EyePosition(), [ drone, target ], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
	return tr.fraction >= 1.0
}

void function FollowMedic_Teleport( entity drone, vector dest, bool quiet )
{
	vector from = drone.GetOrigin()
	EmitSoundAtPosition( TEAM_UNASSIGNED, from, quiet ? GEO_PHASE_DEPARTURE_SOUND : TELEPORT_DEPARTURE_SOUND, drone )
	StartParticleEffectInWorldForRealms( GetParticleSystemIndex( FOLLOW_DRONE_TELEPORT_TRAIL_FX ), from, VectorToAngles( dest - from ), drone )
	drone.SetOrigin( dest )
	EmitSoundOnEntity( drone, quiet ? GEO_PHASE_ARRIVAL_SOUND : TELEPORT_ARRIVAL_SOUND )
}

void function FollowMedic_MoveThread( FollowDroneData data )
{
	entity drone = data.drone
	EndSignal( drone, "OnDestroy", "FollowMedic_End" )

	float lastLOSTime = Time()
	float lastYaw = drone.GetAngles().y
	float lastTime = Time()
	vector velocity = <0, 0, 0>

	while ( true )
	{
		WaitFrame()
		float dt = max( Time() - lastTime, 0.001 )
		lastTime = Time()

		entity target = data.followTarget
		if ( !IsValid( target ) || !IsAlive( target ) )
		{
			if ( IsValid( data.owner ) && IsAlive( data.owner ) && target != data.owner )
				FollowMedic_SetFollowTarget( data.owner, data.owner )
			continue
		}

		vector cur = drone.GetOrigin()
		vector desired = FollowMedic_DesiredPos( target )

		bool hasLOS = FollowMedic_HasLOS( drone, target )
		if ( hasLOS )
			lastLOSTime = Time()

		if ( DistanceSqr( cur, desired ) > GetMaxRopeBreakDistanceSqr() )
		{
			FollowMedic_Teleport( drone, desired, false )
			velocity = <0, 0, 0>
			lastLOSTime = Time()
			continue
		}
		if ( Time() - lastLOSTime > FOLLOW_DRONE_LOS_TELEPORT_TIME )
		{
			FollowMedic_Teleport( drone, desired, true )
			velocity = <0, 0, 0>
			lastLOSTime = Time()
			continue
		}

		vector toDesired = desired - cur
		float dist = Length( toDesired )
		vector targetVel = target.GetVelocity() * PARENT_VELOCITY_FRACTION
		float speed = dist * ADJUSTMENT_SPEED_MULTIPLIER
		if ( dist > VELOCITY_DECELERATION_DISTANCE )
			speed += BASE_SPEED_MULTIPLIER
		vector wantVel = ( dist > 0.01 ? toDesired / dist * speed : <0, 0, 0> ) + targetVel
		float maxSpeed = Length( target.GetVelocity() ) * ( 1.0 + MAX_PARENT_VELOCITY_MULTIPLIER ) + BASE_SPEED_MULTIPLIER * ADJUSTMENT_SPEED_MULTIPLIER + dist * ADJUSTMENT_SPEED_MULTIPLIER
		if ( Length( wantVel ) > maxSpeed )
			wantVel = Normalize( wantVel ) * maxSpeed
		velocity = velocity + ( wantVel - velocity ) * min( 1.0, dt * 8.0 )

		vector next = cur + velocity * dt
		if ( DistanceSqr( next, desired ) > MAX_DISTANCE_FROM_TARGET_POS * MAX_DISTANCE_FROM_TARGET_POS && dist < MAX_DISTANCE_FROM_TARGET_POS )
			next = desired
		drone.NonPhysicsMoveTo( next, dt, 0, 0 )

		float yaw = target.EyeAngles().y
		float pitch = file.pitchParamEnabled ? Clamp( DotProduct( velocity, AnglesToForward( <0, yaw, 0> ) ) / 400.0, -1.0, 1.0 ) * file.velToPitchMax : 0.0
		float roll = file.rollParamEnabled ? Clamp( AngleDiff( yaw, lastYaw ) / ( dt * 180.0 ), -1.0, 1.0 ) * file.turnToRollmax : 0.0
		lastYaw = yaw
		drone.NonPhysicsRotateTo( <pitch, yaw, roll>, dt, 0, 0 )
	}
}

bool function FollowMedic_ShouldHeal( FollowDroneData data, entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() || !IsAlive( player ) )
		return false
	if ( !IsFriendlyTeam( player.GetTeam(), data.owner.GetTeam() ) )
		return false
	if ( !player.DoesShareRealms( data.drone ) )
		return false
	if ( player.IsPhaseShifted() )
		return false
	if ( IsGasCausingDamage( player ) )
		return false
	if ( Bleedout_IsBleedoutLogicActive() && Bleedout_IsBleedingOut( player ) )
		return false
	if ( player.ContextAction_IsMeleeExecution() || player.ContextAction_IsMeleeExecutionTarget() )
		return false
	if ( player.GetHealth() >= player.GetMaxHealth() )
		return false
	if ( !CanBeHealedByDroneMedic( player ) )
		return false

	vector delta = player.GetOrigin() - data.drone.GetOrigin()
	if ( Length2D( delta ) > file.healRadius )
		return false
	if ( delta.z > HEAL_TRIGGER_ABOVE_HEIGHT || -delta.z > HEAL_TRIGGER_BELOW_HEIGHT + 72.0 )
		return false

	if ( !file.healThroughWallsEnabled )
	{
		TraceResults tr = TraceLine( data.drone.GetOrigin(), player.EyePosition(), [ data.drone ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_BLOCK_WEAPONS, data.drone )
		if ( tr.hitEnt != player && tr.hitEnt != null )
			return false
	}

	return true
}

void function FollowMedic_StartHeal( FollowDroneData data, entity player )
{
	float duration = max( data.endTime - Time(), 1.0 ) + FOLLOW_DRONE_DESPAWN_GRACE
	data.healTargets.append( player )
	data.healResourceIDs[player] <- EntityHealResource_Add( player, duration, file.healPerSec, 0, FOLLOW_MEDIC_WEAPON_NAME, data.owner )
	data.statusEffectIDs[player] <- StatusEffect_AddEndless( player, eStatusEffect.drone_healing, 1 )

	EmitSoundOnEntity( data.drone, DEPLOYABLE_MEDIC_DEPLOY_CABLE_SOUND )
	EmitSoundOnEntityOnlyToPlayer( player, player, DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_1P )
	if ( data.healTargets.len() == 1 )
		EmitSoundOnEntity( data.drone, DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_3P )

	data.ropes[player] <- FollowMedic_DeployRope( data.drone, player )
}

void function FollowMedic_StopHeal( FollowDroneData data, entity player )
{
	data.healTargets.fastremovebyvalue( player )

	if ( player in data.healResourceIDs )
	{
		if ( IsValid( player ) )
			EntityHealResource_Remove( player, data.healResourceIDs[player] )
		delete data.healResourceIDs[player]
	}
	if ( player in data.statusEffectIDs )
	{
		if ( IsValid( player ) )
			StatusEffect_Stop( player, data.statusEffectIDs[player] )
		delete data.statusEffectIDs[player]
	}
	if ( IsValid( player ) )
		StopSoundOnEntity( player, DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_1P )
	if ( data.healTargets.len() == 0 && IsValid( data.drone ) )
		StopSoundOnEntity( data.drone, DEPLOYABLE_MEDIC_HEAL_LOOP_SOUND_3P )

	if ( player in data.ropes )
	{
		thread FollowMedic_RetractRope( data.drone, player, data.ropes[player] )
		delete data.ropes[player]
	}
}

void function FollowMedic_HealThread( FollowDroneData data )
{
	entity drone = data.drone
	EndSignal( drone, "OnDestroy", "FollowMedic_End" )

	while ( true )
	{
		wait 0.1

		entity owner = data.owner
		if ( !IsValid( owner ) )
			return

		foreach ( player in clone data.healTargets )
		{
			if ( !FollowMedic_ShouldHeal( data, player ) )
				FollowMedic_StopHeal( data, player )
		}

		foreach ( player, since in clone data.inRangeSince )
		{
			if ( !FollowMedic_ShouldHeal( data, player ) )
				delete data.inRangeSince[player]
		}

		foreach ( player in GetPlayerArrayOfTeam_Alive( owner.GetTeam() ) )
		{
			if ( data.healTargets.contains( player ) || !FollowMedic_ShouldHeal( data, player ) )
				continue

			if ( !( player in data.inRangeSince ) )
				data.inRangeSince[player] <- Time()

			if ( Time() - data.inRangeSince[player] < DEPLOYABLE_MEDIC_HEAL_START_DELAY )
				continue
			if ( data.healTargets.len() >= DEPLOYABLE_MEDIC_HEAL_MAX_TARGETS )
				continue

			FollowMedic_StartHeal( data, player )
		}

		foreach ( player, rope in data.ropes )
			FollowMedic_UpdateRopeLength( drone, player, rope )
	}
}

FollowDroneRope function FollowMedic_DeployRope( entity drone, entity player )
{
	FollowDroneRope rope
	int droneAttachment = drone.LookupAttachment( "rope" )
	float ropeLength = GetDroneMaxRopeLength()

	rope.playerRopeEnd = CreateExpensiveScriptMover( drone.GetOrigin() )
	rope.playerRopeEnd.RenderWithViewModels( true )
	SetForceDrawWhileParented( rope.playerRopeEnd, true )
	rope.playerRopeEnd.SetParent( player, "CHESTFOCUS" )
	rope.playerRope = CreateRope( <0, 0, 0>, <0, 0, 0>, ropeLength, drone, rope.playerRopeEnd, droneAttachment, 0, 1, "models/cable/drone_medic_cable", ROPE_NODE_COUNT )
	HealRopeInit( rope.playerRope, player, true )
	rope.playerRope.kv.VisibilityFlags = ENTITY_VISIBLE_TO_OWNER

	rope.otherRopeEnd = CreateExpensiveScriptMover( drone.GetOrigin() )
	SetForceDrawWhileParented( rope.otherRopeEnd, true )
	rope.otherRopeEnd.SetParent( player, "CHESTFOCUS", true, 0.0 )
	rope.otherRope = CreateRope( <0, 0, 0>, <0, 0, 0>, ropeLength, drone, rope.otherRopeEnd, droneAttachment, 0, 1, "models/cable/drone_medic_cable", ROPE_NODE_COUNT )
	HealRopeInit( rope.otherRope, player, true )
	rope.otherRope.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY

	rope.playerRopeEnd.NonPhysicsMoveInWorldSpaceToLocalPos( <0, 0, 0>, ROPE_SHOOT_OUT_TIME, 0, ROPE_SHOOT_OUT_TIME )
	rope.otherRopeEnd.NonPhysicsMoveInWorldSpaceToLocalPos( <0, 0, 0>, ROPE_SHOOT_OUT_TIME, 0, ROPE_SHOOT_OUT_TIME )

	EmitSoundOnEntityOnlyToPlayer( player, player, DEPLOYABLE_MEDIC_ATTACH_SOUND_1P )
	EmitSoundOnEntityExceptToPlayer( player, player, DEPLOYABLE_MEDIC_ATTACH_SOUND_3P )
	return rope
}

void function FollowMedic_UpdateRopeLength( entity drone, entity player, FollowDroneRope rope )
{
	if ( !IsValid( rope.playerRope ) || !IsValid( rope.otherRope ) || !IsValid( player ) )
		return

	float minDist = file.healRadius / 3.0
	float maxLength = GetDroneMaxRopeLength()
	vector chestOrigin = player.GetAttachmentOrigin( player.LookupAttachment( "CHESTFOCUS" ) )
	float ropeLength = GraphCapped( Distance( drone.GetOrigin(), chestOrigin ), minDist, file.healRadius, maxLength * 0.7, maxLength )
	rope.playerRope.Rope_SetLength( ropeLength )
	rope.otherRope.Rope_SetLength( ropeLength )
}

void function FollowMedic_RetractRope( entity drone, entity player, FollowDroneRope rope )
{
	if ( IsValid( player ) && player.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( player, player, DEPLOYABLE_MEDIC_DETATCH_SOUND_1P )
		EmitSoundOnEntityExceptToPlayer( player, player, DEPLOYABLE_MEDIC_DETATCH_SOUND_3P )
	}

	if ( IsValid( drone ) && IsValid( rope.playerRopeEnd ) && IsValid( rope.otherRopeEnd ) && IsValid( rope.playerRope ) && IsValid( rope.otherRope ) )
	{
		rope.playerRopeEnd.ClearParent()
		rope.playerRopeEnd.NonPhysicsMoveTo( drone.GetOrigin(), ROPE_REAL_IN_TIME, 0, ROPE_REAL_IN_TIME / 2 )
		rope.playerRope.Rope_SetGravityEnabled( false )
		rope.playerRope.Rope_SetLength( 5 )
		rope.otherRopeEnd.ClearParent()
		rope.otherRopeEnd.NonPhysicsMoveTo( drone.GetOrigin(), ROPE_REAL_IN_TIME, 0, ROPE_REAL_IN_TIME / 2 )
		rope.otherRope.Rope_SetGravityEnabled( false )
		rope.otherRope.Rope_SetLength( 5 )
		wait ROPE_REAL_IN_TIME
	}

	foreach ( ent in [ rope.playerRope, rope.playerRopeEnd, rope.otherRope, rope.otherRopeEnd ] )
	{
		if ( IsValid( ent ) )
			ent.Destroy()
	}
}
#endif // SERVER

#if CLIENT
void function LifelineDroneFollowPlayerChanged( entity player, entity newFollowTarget )
{
	bool newTargetIsValid = IsValid( newFollowTarget )

	entity followOrdersWeapon = GetFollowOrdersWeapon( player )
	if ( IsValid( followOrdersWeapon ) && followOrdersWeapon.GetWeaponClassName() == MEDIC_ORDERS_WEAPON_NAME )
		followOrdersWeapon.w.droneIsAssginedToATarget = newTargetIsValid

	if ( file.droneFollowRui == null )
		return

	if ( newTargetIsValid )
	{
		RuiSetBool( file.droneFollowRui, "isLeashed", true )
		RuiSetBool( file.droneFollowRui, "isVisible", true )
		RuiSetBool( file.droneFollowRui, "currentlyDeployedToSelf", newFollowTarget == player )
		RuiSetFloat( file.droneFollowRui, "redeployAnimTime", Time() )

		ItemFlavor character = LoadoutSlot_GetItemFlavor( ToEHI( newFollowTarget ), Loadout_Character() )
		asset icon           = CharacterClass_GetGalleryPortrait( character )
		RuiSetImage( file.droneFollowRui, "legendIcon", icon )
		RuiTrackInt( file.droneFollowRui, "teamMemberIndex", newFollowTarget, RUI_TRACK_PLAYER_TEAM_MEMBER_INDEX )
	}
	else
	{
		RuiSetBool( file.droneFollowRui, "isLeashed", false )
		RuiSetBool( file.droneFollowRui, "isVisible", false )
		RuiSetBool( file.droneFollowRui, "currentlyDeployedToSelf", false )
	}
}

void function FollowMedic_OnAbilityButtonPressed( entity player )
{
	if( !IsValid( player ) )
		return

	if ( !IsPlayerLifelineRevived( player ) )
		return

	if( file.droneFollowRui == null )
		return

	entity currentFollowedTarget = player.GetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR )
	if( !IsValid( currentFollowedTarget ) )
		return

	Remote_ServerCallFunction( "ClientCallback_DroneMedic_TryAssignOrRecall", false )
	TryDroneAssignOrRecall( player, false )
}

void function FollowMedic_OnCharacterButtonPressed( entity player )
{
	if( !IsValid( player ) )
		return

	if ( !TryCharacterButtonCommonReadyChecks( player ) )
		return

	// 1v1 modes use this button for the rest request while waiting or resting.
	if ( Flowstate_IsGame1v1Type() )
	{
		int state = player.GetPlayerNetInt( "FS_1v1_PlayerState" )
		if ( state == e1v1State.WAITING || state == e1v1State.RESTING )
			return
	}

	if ( !IsPlayerLifelineRevived( player ) )
		return

	entity currentFollowedTarget = player.GetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR )
	if( !IsValid( currentFollowedTarget ) || currentFollowedTarget == player )
		return

	Remote_ServerCallFunction( "ClientCallback_DroneMedic_TryAssignOrRecall", true )
	TryDroneAssignOrRecall( player, true )
}

void function ServerToClient_CreateSimpleFollowRuiForDroneTarget( entity droneOwner )
{
	if( file.allyDroneLeashedRui != null )
		return

	entity player = GetLocalClientPlayer()
	if( !IsValid( player ) )
		return

	thread AllyFollowDroneRui_Thread( droneOwner )
}

void function ServerToClient_DestroySimpleFollowRuiForDroneTarget()
{
	if( file.allyDroneLeashedRui == null )
		return

	entity player = GetLocalClientPlayer()
	if( !IsValid( player ) )
		return

	RuiDestroyIfAlive( file.allyDroneLeashedRui )
	file.allyDroneLeashedRui = null
}

void function AllyFollowDroneRui_Thread( entity droneOwner )
{
	if( !IsValid( droneOwner ) )
		return

	EndSignal( droneOwner, "OnDeath", "OnDestroy" )

	file.allyDroneLeashedRui = CreateFullscreenRui( $"ui/ally_drone_leashed_hud.rpak", 32000 )

	OnThreadEnd(
		function() : ()
		{
			if ( file.allyDroneLeashedRui != null )
			{
				RuiDestroyIfAlive( file.allyDroneLeashedRui )
				file.allyDroneLeashedRui = null
			}
		}
	)

	while( file.allyDroneLeashedRui != null )
	{
		RuiSetFloat( file.allyDroneLeashedRui, "droneLeashedTimeRemaining", GetRemainingDroneLifetime( droneOwner ) )
		RuiSetBool( file.allyDroneLeashedRui, "shouldOffset", StatusEffect_HasSeverity( GetLocalClientPlayer(), eStatusEffect.shields_repairing ) )
		WaitFrame()
	}
}

var function GetLifelineTacticalRui()
{
	return file.droneFollowRui
}

var function GetAllyDroneTacticalRui()
{
	return file.allyDroneLeashedRui
}

void function CreateLifelineTacticalRui_Internal( entity player )
{
	if ( !IsPlayerLifelineRevived( player ) )
		return

	if( file.droneFollowRui == null )
		file.droneFollowRui = CreateCockpitPostFXRui( $"ui/meddrone_is_following_you_rui.rpak", HUD_Z_BASE )

	thread UpdateLifelineTacticalRui()
}

void function DestroyLifelineTacticalRui( entity player )
{
	if ( !IsPlayerLifelineRevived( player ) )
	{
		if ( file.droneFollowRui != null )
		{
			RuiDestroy( file.droneFollowRui )
			file.droneFollowRui = null
		}
	}
}

void function UpdateLifelineTacticalRui( )
{
	entity localViewPlayer = GetLocalViewPlayer()
	if( !IsValid( localViewPlayer ) )
		return

	localViewPlayer.Signal( "EndLifelineTacticalRUI" )
	localViewPlayer.EndSignal( "OnDeath", "OnDestroy", "EndLifelineTacticalRUI" )

	while( file.droneFollowRui != null && IsValid( localViewPlayer ) )
	{
		if ( !PlayerDroneIsAssignedToAValidTarget( localViewPlayer ) )
		{
			WaitFrame()
			continue
		}

		float timeFrac = GetRemainingDroneLifetime( localViewPlayer ) / file.droneLifetime
		RuiSetFloat( file.droneFollowRui, "durationFrac", timeFrac )

		entity possibleTarget = localViewPlayer.GetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR )
		entity currentAssignedTarget = localViewPlayer.GetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR )

		if ( IsValid( possibleTarget ) )
			RuiSetBool( file.droneFollowRui, "hasDeployTarget", possibleTarget != currentAssignedTarget )
		else
			RuiSetBool( file.droneFollowRui, "hasDeployTarget", false )

		WaitFrame()
	}
}

void function SingleTargetRui_Thread( entity player, entity target, entity weapon )
{
	if ( !IsValid( target ) )
		return

	if ( GetGameState() >= eGameState.Resolution )
		return

	EndSignal( target, "OnDestroy", "OnDeath", "OnModelChanged" )
	EndSignal( player, "OnDestroy", "OnDeath", "TargetingStop" )
	EndSignal( weapon, "OnDestroy" )

	file.trackedAllies.append( target )

	var rui = RuiCreate( $"ui/meddrone_targeting_rui.rpak", clGlobal.topoFullScreen, RUI_DRAW_HUD, RuiCalculateDistanceSortKey( player.EyePosition(), target.GetOrigin() ) )
	InitHUDRui( rui )

	RuiKeepSortKeyUpdated( rui, true, "pos" )

	RuiTrackFloat3( rui, "pos", target, RUI_TRACK_POINT_FOLLOW, target.LookupAttachment( "CHESTFOCUS" )  )

	target.DoModelChangeScriptCallback( true )
	OnThreadEnd(
		function() : ( rui, target, player )
		{
			RuiDestroyIfAlive( rui )

			if ( IsValid( target ) )
			{
				file.trackedAllies.fastremovebyvalue( target )
				target.DoModelChangeScriptCallback( false )
				target.SetTargetInfoStatusIcon( $"" )
			}
		}
	)

	if( IsValid( weapon ) )
		RuiTrackFloat( rui, "tacAmmoFrac", weapon, RUI_TRACK_WEAPON_CLIP_AMMO_FRACTION )

	while( true )
	{
		bool isBestTarget = IsValid( target ) && target == player.GetPlayerNetEnt( LIFELINE_DRONE_BEST_TARGET_NETVAR )
		entity currentFollowedPlayer = player.GetPlayerNetEnt( LIFELINE_DRONE_FOLLOW_ENT_NETVAR )
		RuiSetBool( rui, "isDeployBestTarget", isBestTarget )
		RuiSetBool( rui, "droneIsDeployedToMe", target == currentFollowedPlayer )
		RuiSetBool( rui, "droneIsDeployed", IsValid( currentFollowedPlayer ) )

		float targetRange = DistanceSqr( player.GetOrigin(), target.GetOrigin() )
		bool showNeedsDrone = 	(  target.GetHealth() < ( target.GetMaxHealth() - file.healWarningThreshold ) )
								&& ( targetRange <= GetDroneAssignmentRangeSqr( player ) )
								&& !( Bleedout_IsBleedoutLogicActive() && ( Bleedout_IsBleedingOut( player ) || Bleedout_IsBleedingOut( target ) ) )

		RuiSetBool( rui, "needsDrone", showNeedsDrone)
		RuiSetInt( rui, "targetHealth", target.GetHealth() )
		RuiSetInt( rui, "healthWarningThreshold", target.GetMaxHealth() - file.healWarningThreshold )

		DeployableMedic_ShowOffscreenUIStatus( target )

		WaitFrame()
	}
}

void function LifelineDrone_WeaponStatusCheck( entity player, var rui, int slot )
{
	if ( !IsPlayerLifelineRevived( player ) )
		return

	switch ( slot )
	{
		case OFFHAND_TACTICAL:
			entity offhandWeapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )
			if ( IsValid( offhandWeapon ) )
				RuiSetBool( rui, "isVisible", !PlayerDroneIsAssignedToAValidTarget( player ) )
			break
	}
}

void function DeployableMedic_ShowOffscreenUIStatus( entity target )
{
	int targetHealth = target.GetHealth()

	if (targetHealth <= 25 )
		target.SetTargetInfoStatusIcon( $"rui/hud/tactical_icons/tactical_lifeline_danger_offscreen_status_3" )
	else if ( targetHealth <= 50 )
		target.SetTargetInfoStatusIcon( $"rui/hud/tactical_icons/tactical_lifeline_danger_offscreen_status_2" )
	else if ( targetHealth < ( target.GetMaxHealth() - file.healWarningThreshold ) )
		target.SetTargetInfoStatusIcon( $"rui/hud/tactical_icons/tactical_lifeline_danger_offscreen_status_1" )
	else
		target.SetTargetInfoStatusIcon( $"" )
}

void function ServerToClient_FollowDroneAttachedTetherFX( entity droneMedic )
{
	entity player = GetLocalViewPlayer()

	if ( IsValid( player ) && IsValid( droneMedic ) )
		thread TetherDirectionalEffect_Thread( player, droneMedic )
}

void function TetherDirectionalEffect_Thread( entity player, entity droneMedic )
{
	player.Signal( "EndDroneTether1PFX" )
	EndSignal( player, "OnDeath", "OnDestroy", "EndDroneTether1PFX" )
	EndSignal( droneMedic, "OnDestroy" )

	int tetherDirectionalIndicator = StartParticleEffectOnEntity( player, GetParticleSystemIndex( FOLLOW_DRONE_ATTACHED_FX_1P ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )

	OnThreadEnd(
		function() : ( tetherDirectionalIndicator )
		{
			if ( EffectDoesExist( tetherDirectionalIndicator ) )
				EffectStop( tetherDirectionalIndicator, true, true )
		}
	)

	float endTime = Time() + file.assignTetherFxDuration
	while ( Time() < endTime )
	{
		if ( !EffectDoesExist( tetherDirectionalIndicator ) )
			return

		vector playerToTether = droneMedic.GetOrigin() - player.GetOrigin()

		vector playerToTetherAngles = VectorToAngles( FlattenVec( playerToTether ) )
		playerToTetherAngles -= <0, 180.0, 0>

		vector eyeAngles = player.EyeAngles()
		eyeAngles = FlattenAngles( eyeAngles )

		vector fxAngle = playerToTetherAngles - eyeAngles + <0, 90, 0>
		fxAngle.y = AngleNormalize( fxAngle.y )
		if ( fabs( fxAngle.y + 90.0 ) < 70.0 )
			fxAngle.y = fxAngle.y > -90.0 ? -20.0 : -160.0

		EffectSetControlPointAngles( tetherDirectionalIndicator, 10, fxAngle )
		EffectSetControlPointVector( tetherDirectionalIndicator, 4, droneMedic.GetOrigin() )

		WaitFrame()
	}
}
#endif // CLIENT
