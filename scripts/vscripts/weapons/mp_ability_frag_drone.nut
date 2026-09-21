global function MpAbilityFragDrone_Init
global function OnWeaponToss_FragDrone
global function OnWeaponActivate_ability_frag_drone
global function OnWeaponDeactivate_ability_frag_drone
global function OnWeaponTossReleaseAnimEvent_ability_frag_drone
global function DoesPlayerHaveOverdrivePassive


#if CLIENT
global function ServerToClient_FragDroneLockFX

#if CLIENT
global function ServerToClient_ShowFragDroneHealthBar
global function ServerToClient_ChangeDroneState
global function FragDrone_EntityShouldBeHighlighted
global function OnCreateClientPreviewFX_ability_FragDrone
global function OnUpdateClientPreviewFX_ability_FragDrone
global function OnDestroyClientPreviewFX_ability_FragDrone
#endif
#endif

const asset FRAG_DRONE_MODEL = $"mdl/props/overdrive_ult_drone/overdrive_ult_drone_w.rmdl"

const asset VFX_DRONE_DEST						= $"P_ability_axle_ult_drone_dest"
const asset VFX_FRAG_DRONE_IDLE_TAIL			= $"P_ability_axle_ult_drone_wing_trail"
const asset VFX_FRAG_DRONE_IDLE_WING			= $"P_ability_axle_ult_active_wing"
const asset VFX_FRAG_DRONE_CHASE				= $"P_ability_axle_ult_drone_wing_trail"
const asset VFX_FRAG_DRONE_BOOM_BUILDUP			= $"P_ability_axle_ultimate_repulse_buildup"
const asset VFX_FRAG_DRONE_BOOM_BUILDUP_WING	= $"P_ability_axle_ultimate_repulse_buildup_wing"
const asset VFX_FRAG_DRONE_VICTIM 				= $"P_ability_axle_ult_repulse_trail"
const asset COCKPIT_TARGETING_IDLE_SCREEN_FX	= $"P_clbr_tac_screen_idle"
const asset VFX_FRAG_DRONE_DEPLOY				= $"P_ability_axle_ult_drone_launch_trail"
const asset LOCK_ON_MARKER						= $"P_ability_axle_ult_lockon"
const asset VFX_DEPLOY_PREVIEW_PATH				= $"P_ability_axle_ult_gate_arrows_preview"
const asset VFX_SCAN_AREA						= $"P_ability_axle_ult_target_wedge"
const asset VFX_DEPLOY_GROUND_FX 				= $"P_axle_ult_graffiti"
const asset VFX_SCAN_IDLE						= $"P_axle_ult_scan_lines"
const asset VFX_DRONE_SPAWN						= $"P_ability_axle_ult_drone_pop_in"
const asset VFX_ULT_PATH_EDGE 					= $"P_axle_ult_preview_edge"
const asset VFX_ULT_CLIMB_OVER_ARROW			= $"P_axle_ult_preview_over"
const asset VFX_ULT_OVER_EDGE_ARROW				= $"P_axle_ult_preview_under"
const asset VFX_ULT_STOP_ARROW					= $"P_axle_ult_preview_stop"
const asset DRONE_PATH_PREVIEW_FX				= $"mdl/fx/abilities/fx_ability_overdrive_ult_previewarrow_w.rmdl"

const vector VFX_DRONE_TRAIL_COLOR_FRIENDLY 	= <255, 32, 162>
const vector VFX_DRONE_TRAIL_COLOR_ENEMY 		= <255, 32, 69>
const vector VFX_SCAN_AREA_COLOR				= <228, 12, 248>

const string DRONE_DESTROYED_SOUND				= "Overdrive_Ult_Drone_Explo_Destroyed"
const string DRONE_EXPLODE_SOUND				= "Overdrive_Ult_Drone_Explo_OnTarget"
const string DRONE_DETONATION_WARNING			= "Overdrive_Ult_Drone_ExplosiveWarningBeep"
const string SEEKING_TARGET_SOUND_LOOP			= "Overdrive_Ult_Drone_SearchForTarget_LP"
const string CHASE_TARGET_SOUND_LOOP			= "Overdrive_Ult_Drone_ChaseTarget_LP"
const string CLIMB_OVER_SOUND					= "Overdrive_Ult_Drone_VerticalHop"

const string DRONE_LOCKED_ON_1P					= "Overdrive_Ult_Drone_TargetLock_Attacker"
const string DRONE_TARGET_LOST_1P				= "Overdrive_Ult_Drone_TargetLock_Lost_Attacker"
const string TARGET_OF_FRAG_DRONE_LOCK_ON_1P	= "Overdrive_Ult_Drone_TargetLock_Victim"
const string TARGET_OF_FRAG_DRONE_LOCK_ON_LOST_1P = "Overdrive_Ult_Drone_TargetLock_Lost_Victim"

const string SIGNAME_END_SEARCH_FOR_PLAYER_TARGETS	= "EndFragDroneSearchingForPlayerTargets"
const string SIGNAME_STOP_CHASE				= "FragDroneStopChase"
const string STOP_HEALTH_BAR_SIGNAL			= "FragDroneStopHealthBar"

global const string FRAG_DRONE_MOVER_SCRIPTNAME = "frag_drone_mover"
const string IMPACT_FX_BOMB_EXPLODE = "ability_axle_ult_repulsor"

const string DEPLOY_ANIM 			= "overdrive_killswitch_deploy"
const string IDLE_ANIM 				= "overdrive_killswitch_idle"
const string IDLE_TO_LOCKON_ANIM 	= "overdrive_killswitch_idle_LockOn"
const string HIT_REACTION_ANIM 		= "overdrive_killswitch_idle_HitReaction"
const string DIVE_TO_DETONATE_ANIM 	= "overdrive_killswitch_dive"

const int DRONE_MOVEMENT_TRACE_MASK = TRACE_MASK_PLAYERSOLID
const int DRONE_MOVEMENT_COLLISION_GROUP = TRACE_COLLISION_GROUP_PLAYER_MOVEMENT
// TraceHull on this engine rejects a hull whose X and Y extents differ; the drone's real box is 32.8 x 45.6
const vector DRONE_BOUNDING_MINS = < -22.8009911, -22.8009911, -3.86204815 >
const vector DRONE_BOUNDING_MAXS = < 22.8009911, 22.8009911, 20.7043133 >

const float HEIGHT_CORRECTION_TOLERANCE = 1.0
const float PARENT_GROUND_HEIGHT_DIFF_TOLERANCE = 7.0
const float FOLLOW_TARGET_DISTANCE_TOLERANCE_SQR = 25.0

const float FRAG_DRONE_GIVE_UP_TIME = 20.0
const float CRITICAL_SLOPE = 0.7
const float MIN_DIST_BUFFER = 1.0
const int PATH_ARROWS_ACTIVATION_CP	= 4
const int PATH_ARROWS_MAX_CP = 11

#if SERVER
const float FRAG_DRONE_EXPLOSION_FORCE = 500.0
const float FRAG_DRONE_KNOCKBACK_MOVING_SPEED = 50.0
const float FRAG_DRONE_KNOCKBACK_BASE_SHOVE = 150.0
const float FRAG_DRONE_CHASE_HOVER_HEIGHT = 40.0
#endif

#if DEV
const bool DEBUG_DRAW_CHASE_TARGET = false
const bool DEBUG_DRAW_LOS_CHECK = false
const bool DEBUG_DRAW_CREATE_STRAIGHT_PATH = false
const bool DEBUG_DRAW_STRAIGHT_PATH_MOVEMENT = false
const bool DEBUG_DRAW_CREATION_SPOT = false
const bool DEBUG_DRAW_FIND_PATH_START = false
const bool DAMAGE_KNOCKUP_SCALING_DEBUG = false
const bool CLIENT_PREVIEW_FX_PERF = false
const bool DEBUG_SCAN_CONNECT_POINT = false
#endif

struct ArrowLocationData
{
	vector pos
	bool showStop = false
	bool showClimbArrow = false
	bool showOverLedgeArrow = false
}

struct
{
#if CLIENT
	table< int, var > droneOffscreenRuis = {}
	int deployPathFX
	int deployEdgeFxLeft
	int deployEdgeFxRight
	int groundFX
	int scanAreaFX
	int stopArrowFX
	int climbOverArrowFX
	int overLedgeArrowFX
	entity minDistFxProxy
	float previewTraceTime = 0.0
	array<entity> minDistArrows
#endif
} file

struct
{
	int droneMaxHealth = 200
	float droneLifetime = 15.0
	float droneChaseTime = 10.0
	float droneHealthBarDuration = 1.0
	float startHeightFromGround = 20.0
	float startDistFromPlayer = 10.0
	float minFwdClearance = 75.0
	float refundTime = 0.3

	float maxChaseSpeed = 450.0
	float minChaseSpeed = 50.0
	float maxSearchDistance = 1000.0
	float startExplodeDistance = 150.0
	float maxChaseValuesBuffer = 100.0
	float maxHeightDiffForTargetAcquisition = 200.0
	float droneBufferRadius = 25.0
	float parentVelFrac = 0.35
	float droneFollowMaxDistance = 50.0
	float droneFollowMinDistance = 40.0
	int maxTotalAdjustments = 10
	float adjustmentDistToPosTolerance = 5.0
	float adjustmentOffWallAvoidDist = 10.0

	float defaultMinTargetingDist = 160.0
	float fovSearchAngle = 80.0

	float droneMinHeight = 50.0
	float maxPathLength = 1000.0
	float pathStep = 50.0
	float straightPathSpeed = 650.0
	float timeToInitialPos = 0.4
	float gravityScale = 1.25
	float baseMinHeightUpwardsVel = 600.0
	float baseAccel = 100.0

	float lookAheadTime = 0.5
	float wallClimbHeight = 180.0
	float offGroundAvoidanceDistFrac = 0.5
	float fwdWallClimbTraceAdditionalDistFrac = 0.125
	float overWallClearanceDistFrac = 0.5
	float diagAvoidanceMaxDegreePivot = 30.0
	float diagAvoidanceClearanceMult = 1.3
	float initialDiagAvoidanceDegreeCheck = 10.0
	float diagonalAvoidanceReturnTrajectoryDistToCheck = 100.0

	int maxMinDistArrows = 50
	float minDistArrowPathStep = 20.0
	bool showGroundFX = false
	float scanAreaFXScaling = 4.2
	float minUltIconVisibleDistance = 3500.0
	float fxClimbHeight = 50.0
	float maxArrowHeightDiff = 110.0

	float detonationTime = 1.4
	float explosionRadius = 250.0
	float proximityThreatIndicatorRange = 350.0
	float maxExplosionDamage = 25.0
	float minExplosionDamage = 25.0
	float minKnockUpMagnitude = 500.0
	float minKnockupDist = 100.0
	float maxKnockUpMagnitude = 850.0
	float xyLowSpeedLimit = 0.0
	float xyHighSpeedLimit = 800.0
	float xyLowSpeedKnockBackScale = 1.75
	float xyHighSpeedKnockBackScale = 0.8
	float shellshockDuration = 1.5
	float highlightDuration = 2.0

	bool hasFriendlyKnockback = true
} tuning

void function MpAbilityFragDrone_Init()
{

	PrecacheScriptString( "mp_ability_frag_drone" )
	PrecacheModel( FRAG_DRONE_MODEL )
	PrecacheModel( DRONE_PATH_PREVIEW_FX )

	PrecacheParticleSystem( VFX_DRONE_DEST )
	PrecacheParticleSystem( VFX_FRAG_DRONE_IDLE_TAIL )
	PrecacheParticleSystem( VFX_FRAG_DRONE_IDLE_WING )
	PrecacheParticleSystem( VFX_FRAG_DRONE_CHASE )
	PrecacheParticleSystem( VFX_FRAG_DRONE_BOOM_BUILDUP )
	PrecacheParticleSystem( VFX_FRAG_DRONE_BOOM_BUILDUP_WING )
	PrecacheParticleSystem( VFX_FRAG_DRONE_VICTIM )
	PrecacheParticleSystem( COCKPIT_TARGETING_IDLE_SCREEN_FX )
	PrecacheParticleSystem( VFX_FRAG_DRONE_DEPLOY )
	PrecacheParticleSystem( LOCK_ON_MARKER )
	PrecacheParticleSystem( VFX_DEPLOY_PREVIEW_PATH )
	PrecacheParticleSystem( VFX_SCAN_AREA )
	PrecacheParticleSystem( VFX_SCAN_IDLE )
	PrecacheParticleSystem( VFX_DRONE_SPAWN )
	PrecacheParticleSystem( VFX_ULT_PATH_EDGE )
	PrecacheParticleSystem( VFX_DEPLOY_GROUND_FX )
	PrecacheParticleSystem( VFX_ULT_OVER_EDGE_ARROW )
	PrecacheParticleSystem( VFX_ULT_CLIMB_OVER_ARROW )
	PrecacheParticleSystem( VFX_ULT_STOP_ARROW )

	Remote_RegisterClientFunction( "ServerToClient_ShowFragDroneHealthBar", "entity" )
	Remote_RegisterClientFunction( "ServerToClient_ChangeDroneState", "entity", "bool" )
	Remote_RegisterClientFunction( "ServerToClient_FragDroneLockFX", "entity", "entity" )

	RegisterSignal( SIGNAME_END_SEARCH_FOR_PLAYER_TARGETS )
	RegisterSignal( SIGNAME_STOP_CHASE )
	RegisterSignal( FRAG_DRONE_PREVIEW_END )

#if CLIENT
	RegisterSignal( STOP_HEALTH_BAR_SIGNAL )
	RegisterSignal( "EnemyHealthBarEnd" )

	AddScriptNameCreateCallback( FRAG_DRONE_MOVER_SCRIPTNAME, FragDrone_OnMoverCreated )

	StatusEffect_RegisterEnabledCallback( eStatusEffect.overdrive_ult_scan, UpdateHighlightOnStatusEffectChange )
	StatusEffect_RegisterDisabledCallback( eStatusEffect.overdrive_ult_scan, UpdateHighlightOnStatusEffectChange )
#endif
}

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function _____________SharedWeaponCallbacks___________________________(){}
#endif

var function OnWeaponToss_FragDrone( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetOwner()
	if ( !IsValid( weaponOwner ) )
		return 0

	if( !FragDrone_CheckForwardClearance(  weapon, weaponOwner, attackParams.dir ) )
		return 0

	return -1.0
}

var function OnWeaponTossReleaseAnimEvent_ability_frag_drone( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetOwner()
	if ( !IsValid( weaponOwner ) )
		return 0

	if( !FragDrone_CheckForwardClearance( weapon, weaponOwner, attackParams.dir ) )
		return 0

	PlayerUsedOffhand( weaponOwner, weapon, true )

#if SERVER
	thread FragDrone_Launch( weapon, weaponOwner, attackParams )
#endif

	return weapon.GetAmmoPerShot()
}

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function _____________ClientWeaponCallbacks___________________________(){}
#endif

const string FRAG_DRONE_PREVIEW_END = "FragDronePreviewEnd"

void function OnWeaponActivate_ability_frag_drone( entity weapon )
{
	Grenade_OnWeaponActivate( weapon )

	#if CLIENT
		printt( "[NITRO] C ult activate", weapon, weapon.GetWeaponOwner(), GetLocalViewPlayer() )
		if ( weapon.GetWeaponOwner() == GetLocalViewPlayer() )
			thread FragDrone_PreviewThink( weapon )
	#endif
}

void function OnWeaponDeactivate_ability_frag_drone( entity weapon )
{
	Grenade_OnWeaponDeactivate( weapon )
	Signal( weapon, FRAG_DRONE_PREVIEW_END )
}

#if CLIENT
void function FragDrone_PreviewThink( entity weapon )
{
	weapon.Signal( FRAG_DRONE_PREVIEW_END )
	weapon.EndSignal( FRAG_DRONE_PREVIEW_END )
	weapon.EndSignal( "OnDestroy" )

	entity player = weapon.GetWeaponOwner()
	if ( !IsValid( player ) )
		return
	player.EndSignal( "OnDeath" )

	OnCreateClientPreviewFX_ability_FragDrone( weapon, player )
	OnThreadEnd(
		function() : ( weapon, player )
		{
			OnDestroyClientPreviewFX_ability_FragDrone( weapon, player )
		}
	)

	while ( IsValid( weapon ) && IsValid( player ) )
	{
		OnUpdateClientPreviewFX_ability_FragDrone( weapon, player )
		WaitFrame()
	}
}
#endif


#if CLIENT
void function OnCreateClientPreviewFX_ability_FragDrone( entity weapon, entity player )
{
	for( int i = 0; i <= tuning.maxMinDistArrows; i++ )
	{
		entity arrowFXProxy = CreateMinDistArrow()
		file.minDistArrows.append( arrowFXProxy )
	}

	file.minDistFxProxy = CreateClientSidePropDynamic( ZERO_VECTOR, ZERO_VECTOR, EMPTY_MODEL )
	file.minDistFxProxy.EnableRenderAlways()

	int pathFXID = GetParticleSystemIndex( VFX_DEPLOY_PREVIEW_PATH )
	file.deployPathFX = StartParticleEffectOnEntity( player, pathFXID, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	EffectSetUpdateControlPointsImmediate( file.deployPathFX, true )

	int edgeFxID = GetParticleSystemIndex( VFX_ULT_PATH_EDGE )
	file.deployEdgeFxLeft = StartParticleEffectInWorldWithHandle( edgeFxID, ZERO_VECTOR, ZERO_VECTOR )
	file.deployEdgeFxRight = StartParticleEffectInWorldWithHandle( edgeFxID, ZERO_VECTOR, ZERO_VECTOR )
	EffectSetUpdateControlPointsImmediate( file.deployEdgeFxLeft, true )
	EffectSetUpdateControlPointsImmediate( file.deployEdgeFxRight, true )

	int stopArrowFxID = GetParticleSystemIndex( VFX_ULT_STOP_ARROW )
	file.stopArrowFX = StartParticleEffectInWorldWithHandle( stopArrowFxID, ZERO_VECTOR, ZERO_VECTOR )
	EffectSetUpdateControlPointsImmediate( file.stopArrowFX, true )

	int climbOverArrowFXID = GetParticleSystemIndex( VFX_ULT_CLIMB_OVER_ARROW )
	file.climbOverArrowFX = StartParticleEffectInWorldWithHandle( climbOverArrowFXID, ZERO_VECTOR, ZERO_VECTOR )
	EffectSetUpdateControlPointsImmediate( file.climbOverArrowFX, true )

	int overLedgeArrowFXID = GetParticleSystemIndex( VFX_ULT_OVER_EDGE_ARROW )
	file.overLedgeArrowFX = StartParticleEffectInWorldWithHandle( overLedgeArrowFXID, ZERO_VECTOR, ZERO_VECTOR )
	EffectSetUpdateControlPointsImmediate( file.overLedgeArrowFX, true )

	int scanAreaFXID = GetParticleSystemIndex( VFX_SCAN_AREA )
	file.scanAreaFX = StartParticleEffectOnEntity( file.minDistFxProxy, scanAreaFXID, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	EffectSetUpdateControlPointsImmediate( file.scanAreaFX, true )
	printt( "[NITRO] C ult preview fx path", file.deployPathFX, EffectDoesExist( file.deployPathFX ), "edge", file.deployEdgeFxLeft, EffectDoesExist( file.deployEdgeFxLeft ), "stop", file.stopArrowFX, EffectDoesExist( file.stopArrowFX ), "over", file.climbOverArrowFX, EffectDoesExist( file.climbOverArrowFX ), "under", file.overLedgeArrowFX, EffectDoesExist( file.overLedgeArrowFX ), "scan", file.scanAreaFX, EffectDoesExist( file.scanAreaFX ), "ids", pathFXID, edgeFxID, stopArrowFxID, scanAreaFXID )
	EffectSetControlPointVector( file.scanAreaFX, 1, VFX_SCAN_AREA_COLOR )
	EffectSetControlPointVector( file.scanAreaFX, 2, < tuning.scanAreaFXScaling, 0.2, 0 > )

	if( tuning.showGroundFX )
	{
		int groundFXID = GetParticleSystemIndex( VFX_DEPLOY_GROUND_FX )
		file.groundFX = StartParticleEffectOnEntity( player, groundFXID, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
		EffectSetUpdateControlPointsImmediate( file.groundFX, true )
		EffectSetControlPointVector( file.groundFX, 1, <1,0,0> )
	}
}

void function OnUpdateClientPreviewFX_ability_FragDrone( entity weapon, entity player )
{
#if DEV
	if( CLIENT_PREVIEW_FX_PERF )
		PerfStart( PerfIndexClient.FragDroneClientPreviewFX )
#endif

	if ( !IsValid( weapon ) )
		return

	if ( !IsValid( player ) )
		return

	if( InPrediction() )
	{
		weapon.SetScriptFloat0( Length2D( player.GetVelocity() ) )
	}

	if( ShouldHideAllDeployFx( player ) )
	{
		if ( Time() > file.previewTraceTime )
		{
			file.previewTraceTime = Time() + 1.0
			printt( "[NITRO] C ult preview HIDDEN zip", player.IsZiplining(), "sky", player.Player_IsSkydiving(), "mantle", player.IsMantling(), "wall", player.IsWallRunning() )
		}
		HideAllDeployFx( player.GetOrigin() )
		return
	}
	else
	{
		EffectSetControlPointVector( file.scanAreaFX, 1, VFX_SCAN_AREA_COLOR )
	}

	vector dir = FlattenNormalizeVec( weapon.GetAttackDirection() )
	vector angles = VectorToAngles( dir )
	float minDist = FragDrone_GetVariableMinTargetingDistance( player, dir )
	ArrowLocationData minDistData
	minDistData = FragDrone_FindMinDistPos( player, dir, minDist, tuning.wallClimbHeight )
	if ( Time() > file.previewTraceTime )
	{
		file.previewTraceTime = Time() + 1.0
		printt( "[NITRO] C ult preview origin", player.GetOrigin(), "dir", dir, "minDist", minDist, "pos", minDistData.pos, "stop", minDistData.showStop, "climb", minDistData.showClimbArrow, "ledge", minDistData.showOverLedgeArrow, "exists", EffectDoesExist( file.deployPathFX ), EffectDoesExist( file.stopArrowFX ), EffectDoesExist( file.scanAreaFX ) )
	}

	file.minDistFxProxy.SetOrigin( minDistData.pos )
	file.minDistFxProxy.SetAngles( angles )

	EffectSetControlPointVector( file.stopArrowFX, 0, minDistData.pos )
	EffectSetControlPointVector( file.climbOverArrowFX, 0, minDistData.pos )
	EffectSetControlPointVector( file.overLedgeArrowFX, 0, minDistData.pos )

	vector stopArrowVisibility = minDistData.showStop ? <1,1,1> : ZERO_VECTOR
	vector climbOverArrowVisibility = minDistData.showClimbArrow ? <1,1,1> : ZERO_VECTOR

	EffectSetControlPointVector( file.stopArrowFX, 1, stopArrowVisibility)
	EffectSetControlPointVector( file.climbOverArrowFX, 1, climbOverArrowVisibility )
	EffectSetControlPointVector( file.overLedgeArrowFX, 1, ZERO_VECTOR )

	FragDrone_UpdateMinDistArrows( player.GetOrigin(), dir, angles, minDist, minDistData )
	bool shouldntShowMainPathInfo = minDistData.showStop || minDistData.showClimbArrow || minDistData.showOverLedgeArrow
	FragDrone_UpdatePathArrows( player.GetOrigin(), minDistData.pos, dir, shouldntShowMainPathInfo )
	FragDrone_UpdatePathEdges( player, dir, minDistData.pos, minDist, shouldntShowMainPathInfo )

#if DEV
	if( CLIENT_PREVIEW_FX_PERF )
	{
		PerfEnd( PerfIndexClient.FragDroneClientPreviewFX )
		PerfDump()
	}
#endif
}

void function OnDestroyClientPreviewFX_ability_FragDrone( entity weapon, entity player )
{
	if ( EffectDoesExist( file.deployPathFX ) )
		EffectStop( file.deployPathFX, false, true )

	if ( EffectDoesExist( file.scanAreaFX ) )
		EffectStop( file.scanAreaFX, false, true )

	if( EffectDoesExist( file.deployEdgeFxLeft ) )
		EffectStop( file.deployEdgeFxLeft, false, true )

	if( EffectDoesExist( file.deployEdgeFxRight ) )
		EffectStop( file.deployEdgeFxRight, false, true )

	if( EffectDoesExist( file.groundFX ) )
		EffectStop( file.groundFX, true, false )

	if( EffectDoesExist( file.climbOverArrowFX ) )
		EffectStop( file.climbOverArrowFX, true, false )

	if( EffectDoesExist( file.overLedgeArrowFX ) )
		EffectStop( file.overLedgeArrowFX, true, false )

	if( EffectDoesExist( file.stopArrowFX ) )
		EffectStop( file.stopArrowFX, true, false )

	if ( IsValid( file.minDistFxProxy ) )
	{
		file.minDistFxProxy.Destroy()
	}

	foreach( entity arrow in file.minDistArrows )
	{
		if ( IsValid( arrow ) )
		{
			arrow.Destroy()
		}
	}

	file.minDistArrows.clear()
}
#endif

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function _______________ServerCodeCallbacks_________________________(){}
#endif

#if SERVER
void function FragDrone_Launch( entity weapon, entity owner, WeaponPrimaryAttackParams attackParams )
{
	if ( !IsValid( owner ) || !IsAlive( owner ) )
		return

	vector dir = FlattenNormalizeVec( attackParams.dir )
	float minDist = FragDrone_GetVariableMinTargetingDistance( owner, dir )
	ArrowLocationData minDistData = FragDrone_FindMinDistPos( owner, dir, minDist, tuning.wallClimbHeight )
	vector initialPos = minDistData.pos + <0, 0, tuning.startHeightFromGround>
	vector startPos = owner.GetOrigin() + dir * tuning.startDistFromPlayer + <0, 0, tuning.startHeightFromGround>
	vector angles = VectorToAngles( dir )

	entity mover = CreateScriptMover( FRAG_DRONE_MOVER_SCRIPTNAME, startPos, angles )
	mover.RemoveFromAllRealms()
	mover.AddToOtherEntitysRealms( owner )
	mover.DisableHibernation()
	SetTeam( mover, owner.GetTeam() )
	mover.SetOwner( owner )

	entity vis = CreatePropScript( FRAG_DRONE_MODEL, startPos, angles, SOLID_OBB )
	vis.SetOwner( owner )
	SetTeam( vis, owner.GetTeam() )
	vis.DisableHibernation()
	vis.SetBlocksRadiusDamage( false )
	vis.SetMaxHealth( tuning.droneMaxHealth )
	vis.SetHealth( tuning.droneMaxHealth )
	vis.SetTakeDamageType( DAMAGE_YES )
	vis.SetDamageNotifications( true )
	vis.RemoveFromAllRealms()
	vis.AddToOtherEntitysRealms( owner )
	vis.SetParent( mover )
	vis.e.axleDroneMover = mover
	vis.e.axleDroneOwner = owner
	vis.e.axleDroneWeapon = weapon
	vis.e.axleLaunchTime = Time()
	AddEntityCallback_OnDamaged( vis, FragDrone_OnVisDamaged )
	AddEntityCallback_OnKilled( vis, FragDrone_OnVisKilled )

	vis.Anim_PlayOnly( DEPLOY_ANIM )
	thread FragDrone_PlayIdleAfterDeploy( vis )

	StartParticleEffectInWorld( GetParticleSystemIndex( VFX_FRAG_DRONE_DEPLOY ), startPos, angles )
	StartParticleEffectOnEntity( vis, GetParticleSystemIndex( VFX_DRONE_SPAWN ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	EmitSoundOnEntity( mover, SEEKING_TARGET_SOUND_LOOP )

	Remote_CallFunction_NonReplay( owner, "ServerToClient_ChangeDroneState", mover, true )

	thread TrapDestroyOnRoundEnd( owner, mover )
	FiringRange_AddToRemoveOnCharacterChange( mover, owner )

	thread FragDrone_DroneThink( mover, vis, owner, weapon, dir, initialPos )
}

void function FragDrone_PlayIdleAfterDeploy( entity vis )
{
	vis.EndSignal( "OnDestroy" )

	WaittillAnimDone( vis )

	if ( !IsValid( vis ) )
		return

	vis.Anim_PlayOnly( IDLE_ANIM )
}

void function FragDrone_DroneThink( entity mover, entity vis, entity owner, entity weapon, vector dir, vector initialPos )
{
	mover.EndSignal( "OnDestroy" )
	vis.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )

	float endLife = Time() + tuning.droneLifetime
	float stepTime = tuning.pathStep / tuning.straightPathSpeed

	entity target = null
	entity threatIndicator = null
	float chaseEnd = 0.0
	bool seekingLoopPlaying = true

	OnThreadEnd(
		function() : ( mover, vis, owner, target, threatIndicator, seekingLoopPlaying )
		{
			StopSoundOnEntity( mover, SEEKING_TARGET_SOUND_LOOP )
			StopSoundOnEntity( mover, CHASE_TARGET_SOUND_LOOP )

			if ( IsValid( target ) )
			{
				StatusEffect_StopAllOfType( target, eStatusEffect.overdrive_ult_scan )
			}

			if ( IsValid( owner ) )
			{
				StatusEffect_StopAllOfType( owner, eStatusEffect.overdrive_ult_tracking )
			}

			if ( IsValid( threatIndicator ) )
				threatIndicator.Destroy()

			if ( IsValid( vis ) )
				vis.Destroy()

			if ( IsValid( mover ) )
				mover.Destroy()
		}
	)

	thread FragDrone_FlightFXThink( mover, vis )

	mover.NonPhysicsMoveTo( initialPos, tuning.timeToInitialPos, 0.0, 0.0 )
	wait tuning.timeToInitialPos

	while ( Time() < endLife )
	{
		if ( !IsValid( mover ) || !IsValid( vis ) || !IsValid( owner ) )
			return

		if ( !IsValid( target ) )
		{
			target = FragDrone_FindTarget( owner, mover, dir )

			if ( IsValid( target ) )
			{
				threatIndicator = FragDrone_OnLock( mover, vis, owner, target )
				chaseEnd = Time() + tuning.droneChaseTime

				StopSoundOnEntity( mover, SEEKING_TARGET_SOUND_LOOP )
				seekingLoopPlaying = false
			}
			else
			{
				if ( !FragDrone_StepStraight( mover, owner, dir ) )
				{
					FragDrone_Detonate( mover, vis, owner, weapon, null )
					return
				}

				wait stepTime
				continue
			}
		}

		if ( !FragDrone_TargetValid( target, owner, mover ) )
		{
			FragDrone_OnLost( mover, vis, owner, target, threatIndicator )
			threatIndicator = null
			target = null

			if ( !seekingLoopPlaying )
			{
				EmitSoundOnEntity( mover, SEEKING_TARGET_SOUND_LOOP )
				seekingLoopPlaying = true
			}

			Remote_CallFunction_NonReplay( owner, "ServerToClient_ChangeDroneState", mover, true )
			continue
		}

		if ( Time() > chaseEnd )
		{
			FragDrone_Detonate( mover, vis, owner, weapon, target )
			return
		}

		if ( Distance( mover.GetOrigin(), target.GetOrigin() ) <= tuning.startExplodeDistance )
		{
			FragDrone_Detonate( mover, vis, owner, weapon, target )
			return
		}

		FragDrone_StepChase( mover, target )

		WaitFrame()
	}

	FragDrone_Detonate( mover, vis, owner, weapon, target )
}

void function FragDrone_FlightFXThink( entity mover, entity vis )
{
	mover.EndSignal( SIGNAME_STOP_CHASE )
	mover.EndSignal( "OnDestroy" )
	vis.EndSignal( "OnDestroy" )

	array<entity> flightFX
	foreach ( string attachName in [ "fx_wing_le", "fx_wing_ri" ] )
	{
		int attachIdx = vis.LookupAttachment( attachName )
		foreach ( asset fx in [ VFX_FRAG_DRONE_IDLE_WING, VFX_FRAG_DRONE_IDLE_TAIL ] )
		{
			flightFX.append( FragDrone_CreateFX( fx, mover, vis, attachIdx, ENTITY_VISIBLE_TO_OWNER | ENTITY_VISIBLE_TO_FRIENDLY, VFX_DRONE_TRAIL_COLOR_FRIENDLY ) )
			flightFX.append( FragDrone_CreateFX( fx, mover, vis, attachIdx, ENTITY_VISIBLE_TO_ENEMY, VFX_DRONE_TRAIL_COLOR_ENEMY ) )
		}
	}

	OnThreadEnd(
		function() : ( flightFX )
		{
			FragDrone_StopFX( flightFX )
		}
	)

	WaitForever()
}

// The wing effects read their tint from control point 1 as an RGB vector.
entity function FragDrone_CreateFX( asset fx, entity mover, entity vis, int attachIdx, int visibilityFlags, vector ornull tint )
{
	int attachType = attachIdx > 0 ? FX_PATTACH_POINT_FOLLOW : FX_PATTACH_ABSORIGIN_FOLLOW
	entity fxEnt = StartParticleEffectOnEntity_ReturnEntity( vis, GetParticleSystemIndex( fx ), attachType, attachIdx )
	SetTeam( fxEnt, mover.GetTeam() )
	fxEnt.SetOwner( mover.GetOwner() )
	fxEnt.kv.VisibilityFlags = visibilityFlags
	if ( tint != null )
		EffectSetControlPointVector( fxEnt, 1, expect vector( tint ) )
	return fxEnt
}

entity function FragDrone_CreateAttachedControlPoint( entity vis, string attachName )
{
	int attachIdx = vis.LookupAttachment( attachName )
	entity cp = CreateEntity( "info_placement_helper" )
	SetTargetName( cp, UniqueString( "frag_drone_cp" ) )
	cp.SetOrigin( vis.GetAttachmentOrigin( attachIdx ) )
	cp.SetParent( vis, attachName, false, 0.0 )
	DispatchSpawn( cp )
	return cp
}

void function FragDrone_StopFX( array<entity> fxEnts )
{
	foreach ( entity ent in fxEnts )
	{
		if ( IsValid( ent ) )
			EffectStop( ent )
	}
}

void function FragDrone_DestroyFX( array<entity> ents )
{
	foreach ( entity ent in ents )
	{
		if ( IsValid( ent ) )
			ent.Destroy()
	}
}

// The build-up ropes arc from control point 2 to 4 (wing to wing) and each per-wing
// build-up sends its lines from the body to control point 1.
void function FragDrone_StartBuildupFX( entity mover, entity vis )
{
	if ( !IsValid( vis ) )
		return

	entity wingLeft = FragDrone_CreateAttachedControlPoint( vis, "fx_wing_le" )
	entity wingRight = FragDrone_CreateAttachedControlPoint( vis, "fx_wing_ri" )

	array<entity> fxEnts
	entity buildup = FragDrone_CreateFX( VFX_FRAG_DRONE_BOOM_BUILDUP, mover, vis, 0, ENTITY_VISIBLE_TO_EVERYONE, null )
	EffectSetControlPointEntity( buildup, 2, wingLeft )
	EffectSetControlPointEntity( buildup, 4, wingRight )
	fxEnts.append( buildup )
	foreach ( entity wing in [ wingLeft, wingRight ] )
	{
		entity buildupWing = FragDrone_CreateFX( VFX_FRAG_DRONE_BOOM_BUILDUP_WING, mover, vis, 0, ENTITY_VISIBLE_TO_EVERYONE, null )
		EffectSetControlPointEntity( buildupWing, 1, wing )
		fxEnts.append( buildupWing )
	}

	thread FragDrone_BuildupFXThink( vis, fxEnts, [ wingLeft, wingRight ] )
}

void function FragDrone_BuildupFXThink( entity vis, array<entity> fxEnts, array<entity> controlPoints )
{
	vis.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( fxEnts, controlPoints )
		{
			FragDrone_StopFX( fxEnts )
			FragDrone_DestroyFX( controlPoints )
		}
	)

	wait tuning.detonationTime
}

entity function FragDrone_FindTarget( entity owner, entity mover, vector pathDir )
{
	int ownerTeam = owner.GetTeam()
	vector moverPos = mover.GetOrigin()
	vector fwd = FlattenNormalizeVec( AnglesToForward( mover.GetAngles() ) )

	array<entity> candidates = GetPlayerArrayEx( "any", TEAM_ANY, ownerTeam, moverPos, tuning.maxSearchDistance )
	candidates.extend( GetNPCArrayEx( "any", TEAM_ANY, ownerTeam, moverPos, tuning.maxSearchDistance ) )
	candidates.extend( GetPlayerDecoyArray() )

	entity best = null
	float bestDist = tuning.maxSearchDistance

	foreach ( entity ent in candidates )
	{
		if ( !IsValid( ent ) || !IsAlive( ent ) )
			continue

		if ( ent == owner )
			continue

		if ( ent.GetTeam() == ownerTeam )
			continue

		if ( !ent.DoesShareRealms( mover ) )
			continue

		if ( ent.IsPlayer() )
		{
			if ( ent.IsPhaseShifted() )
				continue

			if ( ent.IsCloaked( true ) )
				continue

			if ( BleedoutState_GetPlayerBleedoutState( ent ) == BS_BLEEDING_OUT )
				continue
		}
		else if ( !ent.IsNPC() && !ent.IsPlayerDecoy() )
		{
			continue
		}

		vector toEnemy = ent.GetOrigin() - moverPos
		if ( fabs( toEnemy.z ) > tuning.maxHeightDiffForTargetAcquisition )
			continue

		float angle = DotToAngle( DotProduct( fwd, FlattenNormalizeVec( toEnemy ) ) )
		if ( angle > tuning.fovSearchAngle * 0.5 )
			continue

		TraceResults los = TraceLine( moverPos, ent.GetOrigin(), ent, TRACE_MASK_OPAQUE, TRACE_COLLISION_GROUP_NONE )
		if ( los.fraction < 0.99 )
			continue

		float dist = Distance( moverPos, ent.GetOrigin() )
		if ( dist < bestDist )
		{
			bestDist = dist
			best = ent
		}
	}

	return best
}

bool function FragDrone_TargetValid( entity target, entity owner, entity mover )
{
	if ( !IsValid( target ) || !IsValid( owner ) || !IsValid( mover ) )
		return false

	if ( !IsAlive( target ) )
		return false

	if ( target.GetTeam() == owner.GetTeam() )
		return false

	if ( !target.DoesShareRealms( mover ) )
		return false

	if ( target.IsPlayer() )
	{
		if ( target.IsPhaseShifted() )
			return false

		if ( BleedoutState_GetPlayerBleedoutState( target ) == BS_BLEEDING_OUT )
			return false
	}

	return true
}

entity function FragDrone_OnLock( entity mover, entity vis, entity owner, entity target )
{
	StatusEffect_AddTimed( target, eStatusEffect.overdrive_ult_scan, 1.0, tuning.droneChaseTime, 0.0 )
	StatusEffect_AddTimed( owner, eStatusEffect.overdrive_ult_tracking, 1.0, tuning.droneChaseTime, 0.0 )

	vis.Anim_PlayOnly( IDLE_TO_LOCKON_ANIM )

	EmitSoundOnEntityOnlyToPlayer( owner, owner, DRONE_LOCKED_ON_1P )
	if ( target.IsPlayer() )
		EmitSoundOnEntityOnlyToPlayer( target, target, TARGET_OF_FRAG_DRONE_LOCK_ON_1P )
	EmitSoundOnEntity( mover, CHASE_TARGET_SOUND_LOOP )

	Remote_CallFunction_NonReplay( owner, "ServerToClient_ChangeDroneState", mover, false )
	Remote_CallFunction_NonReplay( owner, "ServerToClient_FragDroneLockFX", target, mover )

	entity threatIndicator = CreateThreatIndicator( mover.GetOrigin(), eThreatIndicatorID.GRENADE_INDICATOR_AXLE_ULT, tuning.proximityThreatIndicatorRange, <0, 0, 0>, eThreatIndicatorVisibility.INDICATOR_SHOW_TO_SELF, target )
	threatIndicator.RemoveFromAllRealms()
	threatIndicator.AddToOtherEntitysRealms( mover )
	threatIndicator.SetParent( mover )

	return threatIndicator
}

void function FragDrone_OnLost( entity mover, entity vis, entity owner, entity target, entity threatIndicator )
{
	if ( IsValid( target ) )
	{
		StatusEffect_StopAllOfType( target, eStatusEffect.overdrive_ult_scan )
		if ( target.IsPlayer() )
			EmitSoundOnEntityOnlyToPlayer( target, target, TARGET_OF_FRAG_DRONE_LOCK_ON_LOST_1P )
	}

	if ( IsValid( owner ) )
	{
		StatusEffect_StopAllOfType( owner, eStatusEffect.overdrive_ult_tracking )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, DRONE_TARGET_LOST_1P )
	}

	StopSoundOnEntity( mover, CHASE_TARGET_SOUND_LOOP )

	if ( IsValid( threatIndicator ) )
		threatIndicator.Destroy()

	if ( IsValid( vis ) )
		vis.Anim_PlayOnly( IDLE_ANIM )
}

bool function FragDrone_StepStraight( entity mover, entity owner, vector dir )
{
	vector pos = mover.GetOrigin()
	vector fwdEnd = pos + dir * tuning.pathStep
	array<entity> ignore = [ mover, owner ]

	TraceResults fwdTrace = TraceHull( pos, fwdEnd, DRONE_BOUNDING_MINS, DRONE_BOUNDING_MAXS, ignore, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP, UP_VECTOR )

	vector dest = fwdEnd

	if ( TraceHitAWall( fwdTrace ) )
	{
		float fwdClearance = fwdTrace.fraction + min( 1.0 - fwdTrace.fraction, tuning.fwdWallClimbTraceAdditionalDistFrac )
		float distToCheck = fwdClearance * tuning.pathStep
		bool climbed = false

		for ( float climbHeight = tuning.fxClimbHeight; climbHeight <= tuning.wallClimbHeight; climbHeight += tuning.fxClimbHeight )
		{
			TraceResults overTrace = UpAndOverTraceCheck( pos, dir, climbHeight, distToCheck, ignore, UP_VECTOR, false )
			if ( TraceHitAWall( overTrace ) )
				continue

			dest = overTrace.endPos
			climbed = true
			break
		}

		if ( climbed )
		{
			EmitSoundOnEntity( mover, CLIMB_OVER_SOUND )
		}
		else
		{
			vector sideDest = FragDrone_FindSideStep( pos, dir, tuning.pathStep * tuning.diagAvoidanceClearanceMult, ignore )
			if ( Distance( sideDest, pos ) < 1.0 )
				return false

			dest = sideDest
		}
	}

	TraceResults downTrace = TraceLine( dest, dest - <0, 0, 3000.0>, ignore, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP )
	if ( downTrace.fraction < 1.0 )
		dest.z = max( downTrace.endPos.z + tuning.droneMinHeight, pos.z - tuning.pathStep )

	vector move = dest - pos
	if ( Length( move ) < 1.0 )
		return false

	float stepTime = tuning.pathStep / tuning.straightPathSpeed
	mover.NonPhysicsMoveTo( dest, stepTime, 0.0, 0.0 )
	mover.NonPhysicsRotateTo( VectorToAngles( dir ), 0.2, 0.0, 0.0 )

	return true
}

vector function FragDrone_FindSideStep( vector pos, vector dir, float dist, array<entity> ignore )
{
	array<float> pivots = [ tuning.initialDiagAvoidanceDegreeCheck, tuning.diagAvoidanceMaxDegreePivot ]
	array<float> pivotSigns = [ 1.0, -1.0 ]

	foreach ( float pivot in pivots )
	{
		foreach ( float sign in pivotSigns )
		{
			vector tryDir = VectorRotateAxis( dir, UP_VECTOR, pivot * sign )
			vector tryDest = pos + tryDir * dist
			TraceResults adjust = TraceHull( pos, tryDest, DRONE_BOUNDING_MINS, DRONE_BOUNDING_MAXS, ignore, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP, UP_VECTOR )

			if ( adjust.fraction >= 1.0 )
				return tryDest
		}
	}

	return pos
}

void function FragDrone_StepChase( entity mover, entity target )
{
	vector moverPos = mover.GetOrigin()
	vector targetPos = target.GetOrigin() + <0, 0, FRAG_DRONE_CHASE_HOVER_HEIGHT>
	vector aimPoint = targetPos + target.GetVelocity() * tuning.parentVelFrac * tuning.lookAheadTime

	float dist = Distance( moverPos, aimPoint )
	float speed = GraphCapped( dist, tuning.startExplodeDistance, tuning.startExplodeDistance + tuning.maxChaseValuesBuffer, tuning.minChaseSpeed, tuning.maxChaseSpeed )

	vector dest = aimPoint

	if ( dist < tuning.droneFollowMinDistance )
	{
		dest = moverPos
	}
	else
	{
		array<entity> ignore = [ mover, target ]

		TraceResults direct = TraceHull( moverPos, dest, DRONE_BOUNDING_MINS, DRONE_BOUNDING_MAXS, ignore, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP, UP_VECTOR )
		if ( direct.fraction < 1.0 )
			dest = FragDrone_FindSideStep( moverPos, Normalize( dest - moverPos ), dist, ignore )
	}

	vector move = dest - moverPos
	if ( Length( move ) < 1.0 )
	{
		mover.NonPhysicsRotateTo( VectorToAngles( aimPoint - moverPos ), 0.1, 0.0, 0.0 )
		return
	}

	float travelTime = Length( move ) / speed
	mover.NonPhysicsMoveTo( dest, travelTime, 0.0, 0.0 )
	mover.NonPhysicsRotateTo( VectorToAngles( move ), 0.1, 0.0, 0.0 )
}

void function FragDrone_Detonate( entity mover, entity vis, entity owner, entity weapon, entity target )
{
	mover.Signal( SIGNAME_STOP_CHASE )

	if ( IsValid( vis ) )
		vis.Anim_PlayOnly( DIVE_TO_DETONATE_ANIM )

	FragDrone_StartBuildupFX( mover, vis )
	EmitSoundOnEntity( mover, DRONE_DETONATION_WARNING )

	wait tuning.detonationTime

	if ( !IsValid( mover ) || !IsValid( owner ) )
		return

	vector origin = mover.GetOrigin()

	StartParticleEffectInWorld( GetParticleSystemIndex( VFX_DRONE_DEST ), origin, <0, 0, 0> )
	PlayImpactFXTable( origin, owner, IMPACT_FX_BOMB_EXPLODE )
	EmitSoundAtPosition( TEAM_ANY, origin, DRONE_EXPLODE_SOUND, mover )

	RadiusDamage(
		origin,
		owner,
		mover,
		tuning.maxExplosionDamage,
		tuning.minExplosionDamage,
		tuning.explosionRadius,
		tuning.explosionRadius,
		0,
		0,
		FRAG_DRONE_EXPLOSION_FORCE,
		DF_RAGDOLL | DF_EXPLOSION | DF_GIB,
		eDamageSourceId.damagedef_frag_drone_explode )

	array<entity> victims = GetPlayerArray()
	victims.extend( GetNPCArrayEx( "any", TEAM_ANY, TEAM_ANY, origin, tuning.explosionRadius ) )
	foreach ( entity victim in victims )
	{
		if ( !IsValid( victim ) || !IsAlive( victim ) )
			continue

		if ( !victim.DoesShareRealms( mover ) )
			continue

		float dist = Distance( origin, victim.GetOrigin() )
		if ( dist > tuning.explosionRadius )
			continue

		bool isFriendly = victim.GetTeam() == owner.GetTeam()
		if ( isFriendly && !tuning.hasFriendlyKnockback )
			continue

		if ( victim.IsPlayer() || victim.IsNPC() )
			FragDrone_ApplyKnockback( origin, victim, dist )

		if ( isFriendly )
			continue

		StatusEffect_AddTimed( victim, eStatusEffect.shellshock, 1.0, tuning.shellshockDuration, 0.0 )
		StatusEffect_AddTimed( victim, eStatusEffect.overdrive_ult_scan, 1.0, tuning.highlightDuration, 0.0 )
		StartParticleEffectOnEntity( victim, GetParticleSystemIndex( VFX_FRAG_DRONE_VICTIM ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )

		if ( victim != owner )
			Remote_CallFunction_NonReplay( owner, "ServerToClient_ShowFragDroneHealthBar", victim )
	}

	if ( IsValid( vis ) )
		vis.Destroy()

	if ( IsValid( mover ) )
		mover.Destroy()
}

void function FragDrone_ApplyKnockback( vector origin, entity victim, float dist )
{
	float knockUp = GraphCapped( dist, tuning.minKnockupDist, tuning.explosionRadius, tuning.maxKnockUpMagnitude, tuning.minKnockUpMagnitude )

	vector velocity = victim.GetVelocity()
	float xySpeed = Length2D( velocity )
	vector dir = FlattenVec( velocity )
	if ( xySpeed < FRAG_DRONE_KNOCKBACK_MOVING_SPEED )
		dir = FlattenVec( victim.GetOrigin() - origin )
	if ( Length( dir ) < 1.0 )
		dir = <1, 0, 0>
	dir = Normalize( dir )

	float scale = GraphCapped( xySpeed, tuning.xyLowSpeedLimit, tuning.xyHighSpeedLimit, tuning.xyLowSpeedKnockBackScale, tuning.xyHighSpeedKnockBackScale )

	vector launch = dir * ( FRAG_DRONE_KNOCKBACK_BASE_SHOVE * scale ) + <0, 0, knockUp>
	if ( victim.IsNPC() )
	{
		victim.Signal( "StopPushNPCDownToGround" )
		victim.Signal( "JumpPad_DummieInAir" )
	}
	victim.SetVelocity( launch )
}

void function FragDrone_OnVisDamaged( entity vis, var damageInfo )
{
	if ( !IsValid( vis ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( IsValid( attacker ) && IsValid( vis.GetOwner() ) && attacker.GetTeam() == vis.GetOwner().GetTeam() )
		return

	vis.Anim_PlayOnly( HIT_REACTION_ANIM )
	thread FragDrone_ResumeIdleAfterHit( vis )
}

void function FragDrone_ResumeIdleAfterHit( entity vis )
{
	vis.EndSignal( "OnDestroy" )

	wait 0.5

	if ( !IsValid( vis ) )
		return

	vis.Anim_PlayOnly( IDLE_ANIM )
}

void function FragDrone_OnVisKilled( entity vis, var damageInfo )
{
	if ( !IsValid( vis ) )
		return

	vector origin = vis.GetOrigin()

	StartParticleEffectInWorld( GetParticleSystemIndex( VFX_DRONE_DEST ), origin, <0, 0, 0> )
	EmitSoundAtPosition( TEAM_ANY, origin, DRONE_DESTROYED_SOUND, vis )

	if ( Time() - vis.e.axleLaunchTime < tuning.refundTime )
	{
		entity weapon = vis.e.axleDroneWeapon
		entity owner = vis.e.axleDroneOwner

		if ( IsValid( weapon ) && IsValid( owner ) && weapon.GetWeaponOwner() == owner )
			weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
	}

	entity mover = null
	if ( IsValid( vis.e.axleDroneMover ) )
		mover = vis.e.axleDroneMover
	vis.Destroy()

	if ( IsValid( mover ) )
		mover.Destroy()
}
#endif

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function __________________SharedFuncs___________________________(){}
#endif

bool function DoesPlayerHaveOverdrivePassive( entity player )
{
	return PlayerHasPassive( player, ePassives.PAS_OVERDRIVE )
}

bool function TraceHitAWall( TraceResults trace )
{
	return trace.fraction < 1.0 && trace.surfaceNormal.z < CRITICAL_SLOPE
}

bool function ShouldStopMinDistTraces( TraceResults trace, vector startPos )
{
	return TraceHitAWall( trace ) && Distance2DSqr( startPos, trace.endPos ) < (tuning.minFwdClearance * tuning.minFwdClearance)
}

bool function FragDrone_CheckForwardClearance( entity weapon, entity weaponOwner, vector attackDir )
{
	vector pathDir = FlattenNormalizeVec( attackDir )
	float minDist = FragDrone_GetVariableMinTargetingDistance( weaponOwner, pathDir )
	ArrowLocationData data = FragDrone_FindMinDistPos( weaponOwner, pathDir, minDist, tuning.wallClimbHeight )

	if( data.showStop )
	{
#if CLIENT
		AddPlayerHint( 1.0, 0.25, $"", "#DRONE_PATH_START_FAIL" )
		EmitSoundOnEntity( weaponOwner, "Overdrive_Ult_ClearanceWarning_1P" )
#endif

		return false
	}

	return true
}

TraceResults function UpAndOverTraceCheck( vector traceStart, vector traceDir, float climbHeight, float distToCheck, array<entity> ignoreArray, vector hullUp, bool showDevTraces )
{
	vector upTraceStart  = traceStart
	vector upTraceEnd    = upTraceStart + < 0, 0, climbHeight >
	TraceResults upTrace = TraceLine( upTraceStart, upTraceEnd, ignoreArray, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP )

#if DEV
	if ( showDevTraces )
		DebugDrawLine( upTraceStart, upTrace.endPos, COLOR_BLUE, true, 2.0 )
#endif

	vector newFwdTraceStart = upTrace.endPos
	vector newFwdTraceEnd   = newFwdTraceStart + (traceDir * distToCheck)

	TraceResults fwdTrace = TraceHull(
		newFwdTraceStart,
		newFwdTraceEnd,
		DRONE_BOUNDING_MINS,
		DRONE_BOUNDING_MAXS,
		ignoreArray,
		DRONE_MOVEMENT_TRACE_MASK,
		DRONE_MOVEMENT_COLLISION_GROUP,
		hullUp
	)

#if DEV
	if ( showDevTraces )
		DebugDrawLine( newFwdTraceStart, fwdTrace.endPos, COLOR_LIGHT_GREEN, true, 2.0 )
#endif

	return fwdTrace
}

ArrowLocationData function FragDrone_FindMinDistPos( entity weaponOwner, vector traceDir, float minDist, float climbHeight )
{
	ArrowLocationData data
	array<entity> ignoreArray = [weaponOwner]
	vector traceOrigin = weaponOwner.GetOrigin() + <0, 0, tuning.droneMinHeight>

	TraceResults fwdTrace = TraceHull(
		traceOrigin,
		traceOrigin + traceDir * minDist,
		DRONE_BOUNDING_MINS,
		DRONE_BOUNDING_MAXS,
		ignoreArray,
		DRONE_MOVEMENT_TRACE_MASK,
		DRONE_MOVEMENT_COLLISION_GROUP,
		weaponOwner.GetUpVector()
	)

#if DEV
	if ( DEBUG_DRAW_FIND_PATH_START )
		DebugDrawLine( traceOrigin, fwdTrace.endPos, COLOR_GREEN, true, 2.0 )
#endif

	if ( fwdTrace.fraction < 1.0 )
	{
		if( ShouldStopMinDistTraces( fwdTrace, traceOrigin ) )
		{
			data.showStop = true
		}
		else
		{
			bool originalTraceHitWall = fwdTrace.endPos.z < CRITICAL_SLOPE
			float fwdClearance = originalTraceHitWall ? fwdTrace.fraction + min( 1.0 - fwdTrace.fraction, tuning.fwdWallClimbTraceAdditionalDistFrac ) : 1.0

			float distToCheck = fwdClearance * minDist
			vector startFwdTrace = traceOrigin
			bool showDevTraces = false
#if DEV
			showDevTraces = DEBUG_DRAW_FIND_PATH_START
#endif
			TraceResults newFwdTrace = UpAndOverTraceCheck( startFwdTrace, traceDir,tuning.wallClimbHeight, distToCheck, ignoreArray, weaponOwner.GetUpVector(), showDevTraces )

			if ( TraceHitAWall( newFwdTrace ) )
			{
				data.showStop = true
			}
			else if( originalTraceHitWall )
			{
				data.showClimbArrow = true
			}
			else
			{
				fwdTrace = newFwdTrace
			}
		}
	}

	vector startDownTrace = fwdTrace.endPos
	vector endDownTrace = fwdTrace.endPos - < 0, 0, 3000 >

	TraceResults downTrace = TraceLine( startDownTrace, endDownTrace, ignoreArray, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP )

#if DEV
	if ( DEBUG_DRAW_FIND_PATH_START )
		DebugDrawLine( startDownTrace, endDownTrace, COLOR_LIGHT_GREEN, true, 0.1 )
#endif

	data.pos = downTrace.endPos

	return data
}

float function FragDrone_GetVariableMinTargetingDistance( entity player, vector dir )
{
	float playerRunSpeed = GetPlayerRunSpeed( player )
	if( playerRunSpeed <= 0 )
	{
		return tuning.defaultMinTargetingDist
	}

	float playerFwdSpeed = DotProduct( dir, player.GetVelocity() )
	float distMultiplier = max( playerFwdSpeed/playerRunSpeed, 1.0 )

	return distMultiplier * tuning.defaultMinTargetingDist
}

#if INTELLIJ_OUTLINE_SECTION_MARKER
void function ___________________ClientFuncs___________________________(){}
#endif

#if CLIENT
void function UpdateHighlightOnStatusEffectChange( entity ent, int statusEffect, bool actuallyChanged )
{
	ManageHighlightEntity( ent )
}

entity function CreateMinDistArrow()
{
	entity proxy = CreateClientSidePropDynamic( ZERO_VECTOR, ZERO_VECTOR, DRONE_PATH_PREVIEW_FX )
	proxy.Show()

	return proxy
}

bool function ShouldHideAllDeployFx( entity player )
{
	if( player.IsZiplining() )
		return true

	if( player.Player_IsSkydiving() )
		return true

	if( player.IsMantling() )
		return true

	if( player.IsWallRunning() )
		return true

	return false
}

void function HideAllDeployFx( vector playerOrigin )
{
	foreach( arrow in file.minDistArrows )
	{
		arrow.Hide()
	}

	for( int cp = PATH_ARROWS_ACTIVATION_CP; cp <= PATH_ARROWS_MAX_CP; cp++ )
	{
		int indexMain = (cp - PATH_ARROWS_ACTIVATION_CP)
		EffectSetControlPointVector( file.deployPathFX, cp, playerOrigin )
	}

	EffectSetControlPointVector( file.deployPathFX, 1, ZERO_VECTOR )
	EffectSetControlPointVector( file.deployPathFX, 2, ZERO_VECTOR )
	EffectSetControlPointVector( file.deployPathFX, 3, ZERO_VECTOR )

	EffectSetControlPointVector( file.deployEdgeFxRight, 30, ZERO_VECTOR )
	EffectSetControlPointVector( file.deployEdgeFxLeft, 30, ZERO_VECTOR )

	EffectSetControlPointVector( file.climbOverArrowFX, 0, playerOrigin )
	EffectSetControlPointVector( file.climbOverArrowFX, 1, ZERO_VECTOR )

	EffectSetControlPointVector( file.overLedgeArrowFX, 0, playerOrigin )
	EffectSetControlPointVector( file.overLedgeArrowFX, 1, ZERO_VECTOR )

	EffectSetControlPointVector( file.stopArrowFX, 0, playerOrigin )
	EffectSetControlPointVector( file.stopArrowFX, 1, ZERO_VECTOR )

	EffectSetControlPointVector( file.scanAreaFX, 1, ZERO_VECTOR )
	file.minDistFxProxy.SetOrigin( playerOrigin )
}

void function FragDrone_UpdateMinDistArrows( vector origin, vector dir, vector angles, float minDist, ArrowLocationData data )
{
	foreach( arrow in file.minDistArrows )
	{
		arrow.Hide()
	}

	float maxPathLength = min( minDist, tuning.minDistArrowPathStep * float( tuning.maxMinDistArrows ) )
	array<ArrowLocationData> arrowPositions = FragDrone_CreatePathPreviewPositions( origin, dir, tuning.minDistArrowPathStep, maxPathLength )
	for( int i = 0; i < arrowPositions.len(); i++ )
	{
		if( i == arrowPositions.len() - 1 )
		{
			if( arrowPositions[i].showClimbArrow )
			{
				EffectSetControlPointVector( file.climbOverArrowFX, 1, <1,1,1> )
				EffectSetControlPointVector( file.climbOverArrowFX, 0, arrowPositions[i].pos )
				data.showClimbArrow = true
			}
			else if( arrowPositions[i].showOverLedgeArrow )
			{
				EffectSetControlPointVector( file.overLedgeArrowFX, 1, <1,1,1> )
				EffectSetControlPointVector( file.overLedgeArrowFX, 0, arrowPositions[i].pos )
				data.showOverLedgeArrow = true
			}
		}
		else
		{
			file.minDistArrows[i].SetOrigin( arrowPositions[i].pos )
			file.minDistArrows[i].SetAngles( angles )
			file.minDistArrows[i].Show()
		}
	}
}

void function FragDrone_UpdatePathArrows( vector ownerOrigin, vector minDistPos, vector dir, bool shouldntShow )
{
	table<int, int> cpVisibilities
	if( shouldntShow )
	{
		for( int cp = PATH_ARROWS_ACTIVATION_CP; cp <= PATH_ARROWS_MAX_CP; cp++ )
		{
			int indexMain = (cp - PATH_ARROWS_ACTIVATION_CP)
			EffectSetControlPointVector( file.deployPathFX, cp, minDistPos )
			cpVisibilities[cp] <- 0
		}
	}
	else
	{
		float pathStepMain = tuning.pathStep
		float pathLength = pathStepMain * ( PATH_ARROWS_MAX_CP - PATH_ARROWS_ACTIVATION_CP + 1 )
		array<ArrowLocationData > pathPointsMain = FragDrone_CreatePathPreviewPositions( minDistPos, dir, pathStepMain, pathLength )

		for( int cp = PATH_ARROWS_ACTIVATION_CP; cp <= PATH_ARROWS_MAX_CP; cp++ )
		{
			int indexMain = (cp - PATH_ARROWS_ACTIVATION_CP)
			if( indexMain < pathPointsMain.len() )
			{
				if( indexMain == pathPointsMain.len() - 1 )
				{
					if ( pathPointsMain[indexMain].showClimbArrow )
					{
						EffectSetControlPointVector( file.climbOverArrowFX, 1, <1, 1, 1> )
						EffectSetControlPointVector( file.climbOverArrowFX, 0, pathPointsMain[indexMain].pos )
						cpVisibilities[cp] <- 0
					}
					else if ( pathPointsMain[indexMain].showOverLedgeArrow )
					{
						EffectSetControlPointVector( file.overLedgeArrowFX, 1, <1, 1, 1> )
						EffectSetControlPointVector( file.overLedgeArrowFX, 0, pathPointsMain[indexMain].pos )
						cpVisibilities[cp] <- 0
					}
					else if ( pathPointsMain[indexMain].showStop )
					{
						EffectSetControlPointVector( file.stopArrowFX, 1, <1, 1, 1> )
						EffectSetControlPointVector( file.stopArrowFX, 0, pathPointsMain[indexMain].pos )
						cpVisibilities[cp] <- 0
					}
					else
					{
						cpVisibilities[cp] <- 1
					}
				}
				else
				{
					EffectSetControlPointVector( file.deployPathFX, cp, pathPointsMain[indexMain].pos )
					cpVisibilities[cp] <- 1
				}
			}
			else
			{
				EffectSetControlPointVector( file.deployPathFX, cp, pathPointsMain[pathPointsMain.len() - 1 ].pos )
				cpVisibilities[cp] <- 0
			}
		}
	}

	vector cp1_3Visibility = <cpVisibilities[4], cpVisibilities[5], cpVisibilities[6]>
	vector cp4_6Visibility = <cpVisibilities[7], cpVisibilities[8], cpVisibilities[9]>
	vector cp7_8Visibility = <cpVisibilities[10], cpVisibilities[11], 0>

	EffectSetControlPointVector( file.deployPathFX, 1, cp1_3Visibility )
	EffectSetControlPointVector( file.deployPathFX, 2, cp4_6Visibility )
	EffectSetControlPointVector( file.deployPathFX, 3, cp7_8Visibility )
}

void function FragDrone_UpdatePathEdges( entity player, vector dir, vector minDistPos, float minDist, bool shouldntShow )
{
	EffectSetControlPointVector( file.deployEdgeFxRight, 0, minDistPos )
	EffectSetControlPointVector( file.deployEdgeFxLeft, 0, minDistPos )

	if( shouldntShow )
	{
		EffectSetControlPointVector( file.deployEdgeFxRight, 30, ZERO_VECTOR )
		EffectSetControlPointVector( file.deployEdgeFxLeft, 30, ZERO_VECTOR )
		return
	}
	else
	{
		EffectSetControlPointVector( file.deployEdgeFxRight, 30, <1,1,1> )
		EffectSetControlPointVector( file.deployEdgeFxLeft, 30, <1,1,1>  )
	}

	vector rotVec = player.GetUpVector()
	vector rightEdgeDir = VectorRotateAxis( dir, player.GetUpVector(), tuning.fovSearchAngle )
	vector leftEdgeDir = VectorRotateAxis( dir, player.GetUpVector(), -tuning.fovSearchAngle )

	const int minEdgeCP = 0
	const int maxEdgeCP = 12
	array<vector> edgePointsLeft
	array<vector> edgePointsRight

	for( int cp = minEdgeCP; cp <= maxEdgeCP; cp++ )
	{
		edgePointsRight.append( minDistPos + rightEdgeDir * tuning.pathStep * cp )
		edgePointsLeft.append( minDistPos + leftEdgeDir * tuning.pathStep * cp )

		int edgePointsIndex = cp - minEdgeCP
		if( edgePointsIndex < edgePointsLeft.len() )
			EffectSetControlPointVector( file.deployEdgeFxLeft, cp, edgePointsLeft[edgePointsIndex] )
		else
			EffectSetControlPointVector( file.deployEdgeFxLeft, cp, edgePointsLeft[edgePointsLeft.len() - 1] )

		if( edgePointsIndex < edgePointsRight.len() )
			EffectSetControlPointVector( file.deployEdgeFxRight, cp, edgePointsRight[edgePointsIndex] )
		else
			EffectSetControlPointVector( file.deployEdgeFxRight, cp,  edgePointsRight[edgePointsRight.len() - 1] )
	}
}

array<ArrowLocationData> function FragDrone_CreatePathPreviewPositions( vector startPos, vector dir, float pathStep, float maxPathLength, array<entity> ignoreEnts = [] )
{
	vector fwdTraceStart = startPos
	array<ArrowLocationData> pathPositions

	ArrowLocationData startData
	startData.pos = startPos
	pathPositions.append( startData )

	fwdTraceStart += <0, 0, tuning.droneMinHeight>
	int numSteps = int( floor(maxPathLength / pathStep) )
	for( int i = 0; i < numSteps; i++ )
	{
		ArrowLocationData data
		ArrowLocationData prevArrow = pathPositions.top()

		vector fwdTraceEnd = fwdTraceStart + ( dir * pathStep )

		TraceResults fwdTrace = TraceHull(
			fwdTraceStart,
			fwdTraceEnd,
			DRONE_BOUNDING_MINS,
			DRONE_BOUNDING_MAXS,
			ignoreEnts,
			DRONE_MOVEMENT_TRACE_MASK,
			DRONE_MOVEMENT_COLLISION_GROUP,
			UP_VECTOR
		)

#if DEV
		if( DEBUG_DRAW_CREATE_STRAIGHT_PATH )
			DebugDrawLine( fwdTraceStart, fwdTrace.endPos, COLOR_GREEN, true, 0.1 )
#endif

		vector newFwdTraceStart
		if( TraceHitAWall( fwdTrace ) )
		{
			float fwdClearance = fwdTrace.fraction + min( 1.0 - fwdTrace.fraction, tuning.fwdWallClimbTraceAdditionalDistFrac )
			float distToCheck = fwdClearance * pathStep
			bool showDevTraces = false
#if DEV
			showDevTraces = DEBUG_DRAW_CREATE_STRAIGHT_PATH
#endif
			fwdTrace = UpAndOverTraceCheck( fwdTraceStart, dir, tuning.wallClimbHeight, distToCheck, ignoreEnts, UP_VECTOR, showDevTraces )

			if( TraceHitAWall( fwdTrace ) )
				prevArrow.showStop = true
			else
				prevArrow.showClimbArrow = true

			break
		}

		vector startDownTrace = fwdTrace.endPos
		vector endDownTrace = startDownTrace - <0, 0, 3000.0>

		TraceResults downTrace = TraceLine( startDownTrace, endDownTrace, ignoreEnts, DRONE_MOVEMENT_TRACE_MASK, DRONE_MOVEMENT_COLLISION_GROUP )

		vector heightPosToTest = downTrace.endPos
		if( prevArrow.pos.z - heightPosToTest.z > tuning.maxArrowHeightDiff )
		{
			prevArrow.showOverLedgeArrow = true
			break
		}

#if DEV
		if( DEBUG_DRAW_CREATE_STRAIGHT_PATH )
		{
			DebugDrawLine( fwdTrace.endPos, downTrace.endPos, COLOR_AQUA, true, 0.1 )
			DebugDrawSphere( fwdTraceStart, 5.0, COLOR_RED, true, 0.1 )
		}
#endif

		data.pos = downTrace.endPos
		pathPositions.append( data )
		fwdTraceStart = heightPosToTest + <0, 0, tuning.droneMinHeight>
	}

	return pathPositions
}

bool function FragDrone_EntityShouldBeHighlighted( entity viewPlayer, entity hitPlayer )
{
	return StatusEffect_HasSeverity( hitPlayer, eStatusEffect.overdrive_ult_scan )
}

void function FragDrone_OnMoverCreated( entity ent )
{
	if ( ent.GetOwner() == GetLocalViewPlayer() )
		thread FragDrone_CreateAndManageHUDMarker( ent )
}

void function FragDrone_CreateAndManageHUDMarker( entity drone )
{
	EndSignal( drone, "OnDestroy" )

	var rui = CreateFullscreenRui( $"ui/frag_drone_offscreen.rpak", RuiCalculateDistanceSortKey( GetLocalViewPlayer().EyePosition(), drone.GetOrigin() ) )
	RuiTrackFloat3( rui, "playerAngles", GetLocalViewPlayer(), RUI_TRACK_CAMANGLES_FOLLOW )
	RuiTrackFloat3( rui, "pos", drone, RUI_TRACK_OVERHEAD_FOLLOW )
	RuiSetAsset( rui, "icon", $"rui/hud/ultimate_icons/ultimate_overdrive" )
	RuiSetFloat( rui, "minUltIconVisibleDistance", tuning.minUltIconVisibleDistance )

	int droneEHandle = drone.GetEncodedEHandle()
	file.droneOffscreenRuis[ droneEHandle ] <- rui

	OnThreadEnd(
		function() : ( rui, droneEHandle )
		{
			thread function() : ( rui, droneEHandle )
			{
				if( droneEHandle in file.droneOffscreenRuis )
					delete file.droneOffscreenRuis[ droneEHandle ]

				vector detonatedColor = SrgbToLinear( GetKeyColor( COLORID_ENEMY ) / 255.0 )
				RuiSetColorAlpha( rui, "bgColor", detonatedColor, 1 )
				RuiSetColorAlpha( rui, "iconColor", detonatedColor, 1 )
				RuiSetAsset( rui, "icon", $"rui/hud/ultimate_icons/ultimate_overdrive_detonated" )
				Wait( 1.0 )
				RuiDestroyIfAlive( rui )
			}()
		}
	)

	WaitForever()
}

void function ServerToClient_ShowFragDroneHealthBar( entity victim )
{
	entity attacker = GetLocalViewPlayer()

	if ( GetTotalLOSRequiredNoRestoreReconScans( attacker, victim ) > 0 )
	{
		var rui = null
		if ( victim in attacker.p.reconScanRUIs )
		{
			rui = attacker.p.reconScanRUIs[victim]
			if ( IsValid( rui ) && RuiIsAlive( rui ) )
			{
				attacker.p.damageHealthBarStartTime[victim] <- Time()
				return
			}
		}
	}
	thread FragDrone_HealthBarThink( attacker, victim )
}

void function FragDrone_HealthBarThink( entity attacker, entity victim )
{
	if( !IsValid( victim ) )
		return


	EndSignal( victim, "OnDeath" )
	EndSignal( victim, "OnDestroy" )

	EndSignal( victim, "EnemyHealthBarEnd" )

	Signal( victim, STOP_HEALTH_BAR_SIGNAL )
	EndSignal( victim, STOP_HEALTH_BAR_SIGNAL )

	OnThreadEnd(
		function() : ( attacker, victim )
		{
			ReconScan_RemoveHudForSimpleEntity( attacker, victim )
		}
	)

	attacker.p.damageHealthBarStartTime[victim] <- Time()

	var rui = ReconScan_ShowHudForSimpleEntity( attacker, victim )

	while ( Time() < attacker.p.damageHealthBarStartTime[victim] + tuning.droneHealthBarDuration )
	{
		if ( IsValid( victim ) )
		{
			if( ShouldHideHealthForPlayer( victim ) )
			{
				RuiSetBool( rui, "isVisible", false )
				return
			}
		}
		WaitFrame()
	}
}

void function ServerToClient_ChangeDroneState( entity drone, bool isSeeking )
{
	if( !IsValid( drone ) )
		return

	int droneEHandle = drone.GetEncodedEHandle()
	if ( !( droneEHandle in file.droneOffscreenRuis ) )
		return

	var rui = file.droneOffscreenRuis[ drone.GetEncodedEHandle() ]

	if( isSeeking )
	{
		RuiSetColorAlpha( rui, "bgColor", SrgbToLinear( COLOR_DARK_GRAY / 255.0 ), 1 )
		RuiSetAsset( rui, "icon", $"rui/hud/ultimate_icons/ultimate_overdrive_seek" )
		RuiSetBool( rui, "isHighlighted", false )
	}
	else
	{
		RuiSetColorAlpha( rui, "bgColor", <1, 1, 1>, 1 )
		RuiSetAsset( rui, "icon", $"rui/hud/ultimate_icons/ultimate_overdrive_targeted" )
		RuiSetBool( rui, "isHighlighted", true )
	}
}

void function ServerToClient_FragDroneLockFX( entity victim, entity drone )
{
	thread FragDrone_LockFXThink( victim, drone )
}

void function FragDrone_LockFXThink( entity victim, entity drone )
{
	if ( !IsValid( victim ) || !IsValid( drone ) )
		return

	drone.EndSignal( "OnDestroy" )
	victim.EndSignal( "OnDestroy" )
	victim.EndSignal( "OnDeath" )

	int fxIndex = GetParticleSystemIndex( LOCK_ON_MARKER )
	int attachIdx = victim.LookupAttachment( "CHESTFOCUS" )
	if ( attachIdx <= 0 )
	{
		return
	}

	int effectHandle = StartParticleEffectOnEntity( victim, fxIndex, FX_PATTACH_POINT_FOLLOW, attachIdx )

	OnThreadEnd(
		function() : ( effectHandle )
		{
			if ( EffectDoesExist( effectHandle ) )
			{
				EffectStop( effectHandle, true, true )
			}
		}
	)

	WaitForever()
}
#endif
