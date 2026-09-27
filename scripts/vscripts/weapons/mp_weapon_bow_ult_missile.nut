global function MpWeapon_Bow_Ult_Missile_Init
global function SparrowAbility_HasLOSToPlayer

#if SERVER
global function BowUlt_OnArrowLanded
#endif

const asset CORE_MODEL = $"mdl/props/sparrow_ult_arrow/w_sparrow_ult.rmdl"

const asset HIT_BY_TRAP_TRIGGERED_ICON = $"rui/hud/ultimate_icons/ultimate_sparrow"

const asset BOW_ULT_1P_SCREEN_FX = $"P_sprw_ult_snare_FP"
const asset BOW_ULT_1P_FRIENDLY_SCREEN_FX = $"P_sprw_ult_snare_friendly_FP"
const asset LANDING_SCAN_EFFECT =  $"P_sprw_ult_3P_scan"
const asset ULT_CHARGEUP_EFFCT = $"P_sprw_ult_mine_chargeUp"
const asset FIRE_BOLT_MISS_FX = $"P_sprw_ult_active_miss"
const asset FIRE_BOLT_BLOCKED_FX = $"P_sprw_ult_active_env"
const asset FIRE_BOLT_HIT_FX = $"P_sprw_ult_active_hit"
const asset ENEMY_TARGETING_WARP_BEAM_FX = $"P_sprw_ult_active_beam_to_nme"
const asset ULT_TARGET_BEAM_FX = $"P_sprw_ult_targeting_beam"
const asset ULT_TARGET_FULL_BEAM_FX = $"P_sprw_ult_targeting_beam_sky"
const asset CORE_EXPLOSION = $"P_sprw_ult_goober_exp"
const asset CHARGE_COUNTDOWN_FX = $"P_sprw_ult_charge_countdown"
const asset BOW_ULT_TARGETING_LASER_FX = $"P_sprw_ult_target_MDL_3P"
const asset BOW_ULT_TARGETING_1P_LASER_FX = $"P_ult_tether_FP_SS"
const asset MISSILE_ULT_TETHER_INDICATOR_FX = $"P_sprw_ult_tether_cp10"
const asset BOW_ULT_ZONE_AR_FX = $"P_sprw_ult_AR_edge_MDL"
const asset BOW_ULT_DOME = $"P_sprw_ult_active_orb"
const asset BOW_ULT_POLE_EYE = $"p_sprw_ult_pole_eye"
const asset BOW_ULT_HIT_BY_ULT_3P = $"P_sprw_emp_body_3p"
const asset BOW_ULT_ORB_BLAST = $"P_sprw_ult_active_orb_timing"

const string BOW_ULT_STATUS_EFFECT_START = "bow_ult_status_start"
global const string BOW_ULT_MISSILE_SCRIPT_NAME = "bow_ult_core"
global const string BOW_ULT_MISSILE_READY_SCRIPT_NAME = "bow_ult_core_ready"
global const string BOW_ULT_MISSILE_FIRING_SCRIPT_NAME = "bow_ult_core_firing"
global const string BOW_ULT_MISSILE_CLOSING_SCRIPT_NAME = "bow_ult_core_closing"

global vector BOW_ULT_TIP_HULL_MINS = < -10, -10, 45 >
global vector BOW_ULT_TIP_HULL_MAXS = < 10, 10, 65 >
global vector BOW_ULT_HULL_MINS = < -10, -10, 0 >
global vector BOW_ULT_HULL_MAXS = < 10, 10, 65 >

const vector SPARROW_FRIENDLY_COLOR = < 48, 180, 255 >
const vector SPARROW_ENEMY_COLOR = < 155, 50, 50 >

// Severity above this is the enemy snare; at or below it the friendly one.
const float BOW_ULT_FRIENDLY_SEVERITY = 0.5

#if SERVER
const float BOW_ULT_CLOSING_TIME = 0.5
const float BOW_ULT_ENEMY_SLOW = 0.3
const float BOW_ULT_FRIENDLY_SLOW = 0.15
#endif

struct
{
	float hit_by_ult_status_effect_duration = 6.0
	float hit_by_ult_slow_duration = 6.0
	float ult_radius = 800
	int ult_health = 400
	int impact_damage_inner_radius = 50
	int impact_damage_outer_radius = 150
	float impact_scan_time = 3.0
	float time_between_shots = 1.0
	float charge_time = 1.5
	float upgrade_charge_time = 1.5
	float prefire_delay = 0.5
	float fire_duration = 6.0
	float upgrade_fire_duration = 3.0
	float scan_effect_size = 50
	int impact_damage = 15
	float zoneEffectSize = 300
	int ult_main_damage = 20
	float status_effect_removal_delay = 0.5
	float structure_damage_modifier = 5.0
	float vehicle_damage_modifier 	= 5.0
	float vehicle_occupant_damage_modifier = 1.0
	float destroyOverlapingUltZone = 200
	int ult_health_for_upgrade = 400
	float ult_orb_blast_size = 200
	float lifeSiphonHealModifier = 1.0
	bool hasDamagePassthrough = true
	bool hasFriendlySlow = true
} tuning

struct
{
	#if CLIENT
		int cockpitScreenFx
		int cockpitScreenFriendlyFx
	#endif
} file

void function MpWeapon_Bow_Ult_Missile_Init()
{
	PrecacheParticleSystem( BOW_ULT_1P_SCREEN_FX )
	PrecacheParticleSystem( BOW_ULT_1P_FRIENDLY_SCREEN_FX )
	PrecacheParticleSystem( ULT_CHARGEUP_EFFCT )
	PrecacheParticleSystem( CHARGE_COUNTDOWN_FX )
	PrecacheParticleSystem( FIRE_BOLT_MISS_FX )
	PrecacheParticleSystem( FIRE_BOLT_BLOCKED_FX )
	PrecacheParticleSystem( FIRE_BOLT_HIT_FX )
	PrecacheParticleSystem( ENEMY_TARGETING_WARP_BEAM_FX )
	PrecacheParticleSystem( LANDING_SCAN_EFFECT )
	PrecacheParticleSystem( MISSILE_ULT_TETHER_INDICATOR_FX )
	PrecacheParticleSystem( ULT_TARGET_BEAM_FX )
	PrecacheParticleSystem( ULT_TARGET_FULL_BEAM_FX )
	PrecacheParticleSystem( CORE_EXPLOSION )
	PrecacheParticleSystem( BOW_ULT_TARGETING_LASER_FX )
	PrecacheParticleSystem( BOW_ULT_TARGETING_1P_LASER_FX )
	PrecacheParticleSystem( BOW_ULT_ZONE_AR_FX )
	PrecacheParticleSystem( BOW_ULT_DOME )
	PrecacheParticleSystem( BOW_ULT_POLE_EYE )
	PrecacheParticleSystem( BOW_ULT_HIT_BY_ULT_3P )
	PrecacheParticleSystem( BOW_ULT_ORB_BLAST )
	PrecacheModel( CORE_MODEL )
	PrecacheModel( GRENADE_INDICATOR_ARCO_ULT )
	PrecacheParticleSystem( FX_SPARROW_ULT_TARGET )

	#if CLIENT
		file.cockpitScreenFx = GetParticleSystemIndex( BOW_ULT_1P_SCREEN_FX )
		file.cockpitScreenFriendlyFx = GetParticleSystemIndex( BOW_ULT_1P_FRIENDLY_SCREEN_FX )
	#endif

	PrecacheScriptString( BOW_ULT_MISSILE_SCRIPT_NAME )
	PrecacheScriptString( BOW_ULT_MISSILE_READY_SCRIPT_NAME )
	PrecacheScriptString( BOW_ULT_MISSILE_FIRING_SCRIPT_NAME )
	PrecacheScriptString( BOW_ULT_MISSILE_CLOSING_SCRIPT_NAME )

	RegisterSignal( "StopThreatIndicator" )
	RegisterSignal( "RemovedBlindingEffect" )
	RegisterSignal( "StopChargeUpEffect" )
	RegisterSignal( "EndLaser" )
	RegisterSignal( "BowUltEnded" )
	RegisterSignal( "DestroyCore" )
	RegisterSignal( BOW_ULT_STATUS_EFFECT_START )

	tuning.ult_radius           = GetCurrentPlaylistVarFloat( "sparrow_ult_ult_radius", tuning.ult_radius )
	tuning.ult_health           = GetCurrentPlaylistVarInt( "sparrow_ult_ult_health", tuning.ult_health )
	tuning.ult_main_damage      = GetCurrentPlaylistVarInt( "sparrow_ult_ult_main_damage", tuning.ult_main_damage )
	tuning.impact_damage        = GetCurrentPlaylistVarInt( "sparrow_ult_impact_damage", tuning.impact_damage )
	tuning.charge_time          = GetCurrentPlaylistVarFloat( "sparrow_ult_charge_time", tuning.charge_time )
	tuning.fire_duration        = GetCurrentPlaylistVarFloat( "sparrow_ult_fire_duration", tuning.fire_duration )
	tuning.time_between_shots   = GetCurrentPlaylistVarFloat( "sparrow_ult_time_between_shots", tuning.time_between_shots )
	tuning.hasFriendlySlow      = GetCurrentPlaylistVarBool( "sparrow_ult_hasFriendlySlow", tuning.hasFriendlySlow )

	#if CLIENT
		RegisterMinimapPackage( "prop_script", eMinimapObject_prop_script.BOW_ULT, MINIMAP_OBJECT_RUI, MinimapPackage_BowUlt, FULLMAP_OBJECT_RUI, MinimapPackage_BowUlt )
		AddScriptNameCreateCallback( BOW_ULT_MISSILE_SCRIPT_NAME, BowUltSourceCreated )
		AddScriptNameCreateCallback( BOW_ULT_MISSILE_READY_SCRIPT_NAME, BowUltSourceCreated )

		StatusEffect_RegisterEnabledCallback( eStatusEffect.hit_by_sparrow_ult, BowUltScreenVFXEnabled )
		StatusEffect_RegisterDisabledCallback( eStatusEffect.hit_by_sparrow_ult, BowUltScreenVFXDisabled )
	#endif
}

// S21 has no IsEntityVisibleFromPoint: the player counts as visible when the
// eye or the centre clears the trace.
bool function SparrowAbility_HasLOSToPlayer( entity trap, entity player, string attachId, float maxDist )
{
	int attachID       = trap.LookupAttachment( attachId )
	vector startOrigin = attachID > 0 ? trap.GetAttachmentOrigin( attachID ) : trap.GetOrigin()
	int traceMask      = TRACE_MASK_BLOCKLOS | CONTENTS_WINDOW

	if( DistanceSqr( startOrigin, player.GetOrigin() ) > maxDist*maxDist )
		return false

	array<entity> ignoreEnts = GetPlayerArray_AliveConnected()
	ignoreEnts.append( trap )

	foreach ( vector endPos in [ player.EyePosition(), player.GetWorldSpaceCenter() ] )
	{
		TraceResults tr = TraceLine( startOrigin, endPos, ignoreEnts, traceMask, TRACE_COLLISION_GROUP_NONE )
		if ( tr.fraction >= 0.99 )
			return true
	}
	return false
}

float function BowUlt_UpgradedRadiusScaler()
{
	return GetCurrentPlaylistVarFloat( "passive_upgrade_arco_ult_radius_scaler", 0.5 )
}

float function BowUlt_GetRadius( entity player )
{
	float result = tuning.ult_radius

	if( IsValid( player ) && PlayerHasPassive( player, ePassives.PAS_ULT_UPGRADE_THREE ) )
	{
		result *= BowUlt_UpgradedRadiusScaler()
	}

	return result
}

#if SERVER
void function BowUlt_OnArrowLanded( entity projectile, DeployableCollisionParams collisionParams )
{
	thread BowUlt_Deploy( projectile, collisionParams.pos, collisionParams.normal, collisionParams.hitEnt )
}

array<entity> function BowUlt_TraceIgnore( entity core )
{
	array<entity> ignore = GetPlayerArray_AliveConnected()
	ignore.append( core )
	return ignore
}

void function BowUlt_DestroyOverlapping( vector pos, entity newCore )
{
	float rangeSqr = tuning.destroyOverlapingUltZone * tuning.destroyOverlapingUltZone
	foreach ( string name in [ BOW_ULT_MISSILE_SCRIPT_NAME, BOW_ULT_MISSILE_READY_SCRIPT_NAME, BOW_ULT_MISSILE_FIRING_SCRIPT_NAME ] )
	{
		foreach ( entity core in GetEntArrayByScriptName( name ) )
		{
			if ( core != newCore && IsValid( core ) && core.DoesShareRealms( newCore ) && DistanceSqr( core.GetOrigin(), pos ) < rangeSqr )
				core.Signal( "DestroyCore" )
		}
	}
}

void function BowUlt_Deploy( entity projectile, vector pos, vector normal, entity hitEnt )
{
	if ( !IsValid( projectile ) )
		return

	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) || !owner.IsPlayer() )
	{
		projectile.Destroy()
		return
	}

	vector angles = AnglesOnSurface( normal, projectile.GetForwardVector() )
	int team = owner.GetTeam()
	projectile.Destroy()

	entity core = CreatePropScript( CORE_MODEL, pos, angles, SOLID_VPHYSICS )
	core.SetScriptName( BOW_ULT_MISSILE_SCRIPT_NAME )
	core.SetOwner( owner )
	SetTeam( core, team )
	core.RemoveFromAllRealms()
	core.AddToOtherEntitysRealms( owner )
	core.SetMaxHealth( tuning.ult_health )
	core.SetHealth( tuning.ult_health )
	core.SetDamageNotifications( true )
	core.SetDeathNotifications( false )
	core.SetArmorType( ARMOR_TYPE_HEAVY )
	core.SetBlocksRadiusDamage( false )
	core.SetTakeDamageType( DAMAGE_YES )
	core.e.ignoreJumpPad = true
	SetObjectCanBeMeleed( core, true )
	AddEntityCallback_OnDamaged( core, BowUlt_OnCoreDamaged )
	AddSonarDetectionForPropScript( core )
	AddEMPDestroyDeviceNoDissolve( core )
	core.Minimap_SetCustomState( eMinimapObject_prop_script.BOW_ULT )
	core.Minimap_AlwaysShow( team, null )
	core.Minimap_SetAlignUpright( true )
	core.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	FiringRange_AddToRemoveOnCharacterChange( core, owner )
	thread TrapDestroyOnRoundEnd( owner, core )

	if ( IsValid( hitEnt ) && !hitEnt.IsWorld() && EntityShouldStick( core, hitEnt ) )
		core.SetParent( hitEnt, "", true, 0.0 )

	BowUlt_DestroyOverlapping( pos, core )
	thread BowUlt_Think( core, owner, team )
}

void function BowUlt_OnCoreDamaged( entity core, var damageInfo )
{
	if ( !IsValid( core ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsPlayer() && IsFriendlyTeam( attacker.GetTeam(), core.GetTeam() ) )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	float damage = DamageInfo_GetDamage( damageInfo )
	if ( damage <= 0 )
		return

	if ( IsValid( attacker ) && attacker.IsPlayer() )
		attacker.NotifyDidDamage( core, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamagePosition( damageInfo ), DamageInfo_GetCustomDamageType( damageInfo ) | DF_NO_HITBEEP, damage, DamageInfo_GetDamageFlags( damageInfo ), DamageInfo_GetHitGroup( damageInfo ), DamageInfo_GetWeapon( damageInfo ), DamageInfo_GetDistFromAttackOrigin( damageInfo ) )

	if ( core.GetHealth() - damage <= 0 )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		core.Signal( "DestroyCore" )
	}
}

vector function BowUlt_CoreFirePos( entity core )
{
	int attachId = core.LookupAttachment( "chargeup_effect" )
	return attachId > 0 ? core.GetAttachmentOrigin( attachId ) : core.GetOrigin() + <0, 0, 55>
}

void function BowUlt_Think( entity core, entity owner, int team )
{
	core.EndSignal( "OnDestroy", "DestroyCore" )
	EndThreadOn_PlayerChangedClass( owner )

	array<entity> fx
	bool destroyed = true

	OnThreadEnd(
		function() : ( core, fx )
		{
			foreach ( entity e in fx )
			{
				if ( IsValid( e ) )
					e.Destroy()
			}

			if ( IsValid( core ) )
			{
				vector pos = core.GetOrigin()
				StartParticleEffectInWorldForRealms( GetParticleSystemIndex( CORE_EXPLOSION ), pos, <0, 0, 0>, core )
				EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Sparrow_Ult_Base_Destroyed", core )
				RemoveSonarDetectionForPropScript( core )
				core.Destroy()
			}
		}
	)

	vector pos = core.GetOrigin()
	EmitSoundOnEntity( core, "Sparrow_Ult_FirstImpact" )
	StartParticleEffectInWorldForRealms( GetParticleSystemIndex( LANDING_SCAN_EFFECT ), pos, <0, 0, 0>, core )

	RadiusDamage(
		pos,
		owner,
		core,
		tuning.impact_damage,
		tuning.impact_damage,
		tuning.impact_damage_inner_radius,
		tuning.impact_damage_outer_radius,
		SF_ENVEXPLOSION_NO_DAMAGEOWNER,
		0,
		0,
		DF_RAGDOLL | DF_EXPLOSION,
		eDamageSourceId.mp_weapon_bow_ult_splash_damage )

	thread BowUlt_LandingScan( core, owner, team, pos )

	bool upgraded = PlayerHasPassive( owner, ePassives.PAS_ULT_UPGRADE_THREE )
	float chargeTime = upgraded ? tuning.upgrade_charge_time : tuning.charge_time
	float fireDuration = upgraded ? tuning.upgrade_fire_duration : tuning.fire_duration

	int chargeAttach = core.LookupAttachment( "chargeup_effect" )
	int chargeMode = chargeAttach > 0 ? FX_PATTACH_POINT_FOLLOW : FX_PATTACH_ABSORIGIN_FOLLOW
	float radius = BowUlt_GetRadius( owner )
	array<entity> chargeFxs = BowUlt_StartTeamFxOnEntity( core, ULT_CHARGEUP_EFFCT, chargeMode, chargeAttach, team, [ 1, 2, 4 ] )
	// The countdown beams use CP2.x as their model scale (about 17 units long), not as a distance.
	float scanSize = tuning.scan_effect_size * radius / tuning.ult_radius
	chargeFxs.extend( BowUlt_StartTeamFxOnEntity( core, CHARGE_COUNTDOWN_FX, chargeMode, chargeAttach, team, [ 1 ], 2, scanSize ) )
	fx.extend( chargeFxs )

	EmitSoundOnEntityToTeam( core, "Sparrow_Ult_Initialize_Friendly", team )
	EmitSoundOnEntityToEnemies( core, "Sparrow_Ult_Initialize_Enemy", team )

	wait chargeTime

	core.SetScriptName( BOW_ULT_MISSILE_READY_SCRIPT_NAME )
	EmitSoundOnEntityToTeam( core, "Sparrow_Ult_PreFireWarmup_Friendly", team )

	wait tuning.prefire_delay

	core.SetScriptName( BOW_ULT_MISSILE_FIRING_SCRIPT_NAME )
	foreach ( entity e in chargeFxs )
	{
		if ( IsValid( e ) )
			e.Destroy()
	}

	fx.extend( BowUlt_StartTeamFxOnEntity( core, BOW_ULT_DOME, chargeMode, chargeAttach, team, [ 2 ], 1, radius ) )
	fx.extend( BowUlt_StartTeamFxOnEntity( core, BOW_ULT_POLE_EYE, chargeMode, chargeAttach, team, [ 3 ] ) )

	float endTime = Time() + fireDuration
	bool warned = false
	while ( Time() < endTime )
	{
		if ( !IsValid( owner ) )
			break

		BowUlt_Pulse( core, owner, team )

		if ( !warned && endTime - Time() <= tuning.time_between_shots * 1.5 )
		{
			warned = true
			EmitSoundOnEntityToEnemies( core, "Sparrow_Ult_FinalWarning_Enemy", team )
		}

		wait tuning.time_between_shots
	}

	core.SetScriptName( BOW_ULT_MISSILE_CLOSING_SCRIPT_NAME )
	EmitSoundOnEntity( core, "Sparrow_Ult_Arrow_Collapse" )
	wait BOW_ULT_CLOSING_TIME
}

// The landing pulse reveals every enemy the core can see for impact_scan_time.
void function BowUlt_LandingScan( entity core, entity owner, int team, vector pos )
{
	float radius = BowUlt_GetRadius( owner )
	array<entity> scanned
	foreach ( entity player in GetPlayerArray_Alive() )
	{
		if ( !IsEnemyTeam( team, player.GetTeam() ) || !player.DoesShareRealms( core ) )
			continue
		if ( !SparrowAbility_HasLOSToPlayer( core, player, "chargeup_effect", radius ) )
			continue

		scanned.append( player )
		SonarStart( player, player.GetOrigin(), team, owner )
		StatusEffect_AddTimed( player, eStatusEffect.arco_ult_scan, 1.0, tuning.impact_scan_time, 0.0 )
	}

	OnThreadEnd(
		function() : ( scanned, team, owner )
		{
			foreach ( entity player in scanned )
			{
				if ( IsValid( player ) )
					SonarEnd( player, team, owner )
			}
		}
	)

	wait tuning.impact_scan_time
}

bool function BowUlt_HasLOSToEnt( entity core, vector firePos, entity ent )
{
	array<entity> ignore = BowUlt_TraceIgnore( core )
	TraceResults tr = TraceLine( firePos, ent.GetWorldSpaceCenter(), ignore, TRACE_MASK_BLOCKLOS | CONTENTS_WINDOW, TRACE_COLLISION_GROUP_NONE )
	return tr.fraction >= 0.99 || tr.hitEnt == ent
}

void function BowUlt_ZapStructure( entity core, entity owner, vector firePos, entity ent, float scale )
{
	int damage = int( tuning.ult_main_damage * scale )
	if ( damage <= 0 )
		return

	foreach ( entity beam in BowUlt_StartTeamFxInWorld( ENEMY_TARGETING_WARP_BEAM_FX, firePos, core.GetTeam(), core, [ 2 ] ) )
	{
		EffectSetControlPointVector( beam, 1, ent.GetWorldSpaceCenter() )
		thread BowUlt_DestroyAfter( beam, 0.5 )
	}
	ent.TakeDamage( damage, owner, core, { damageSourceId = eDamageSourceId.mp_weapon_bow_ult_missile, origin = firePos } )
}

// Doors, enemy deployables and vehicles in sight take the pulse before the players do.
void function BowUlt_PulseStructures( entity core, entity owner, int team, vector firePos, float radius )
{
	float radiusSqr = radius * radius

	foreach ( entity door in GetAllPropDoors() )
	{
		if ( !IsValid( door ) || door.GetHealth() <= 0 || !door.DoesShareRealms( core ) )
			continue
		if ( DistanceSqr( door.GetWorldSpaceCenter(), firePos ) > radiusSqr || !BowUlt_HasLOSToEnt( core, firePos, door ) )
			continue
		BowUlt_ZapStructure( core, owner, firePos, door, tuning.structure_damage_modifier )
	}

	foreach ( entity prop in GetEntArrayByClass_Expensive( "prop_script" ) )
	{
		if ( !IsValid( prop ) || prop == core || !IsEnemyTeam( team, prop.GetTeam() ) )
			continue
		if ( prop.GetMaxHealth() <= 0 || prop.GetHealth() <= 0 || !prop.DoesShareRealms( core ) )
			continue
		if ( DistanceSqr( prop.GetWorldSpaceCenter(), firePos ) > radiusSqr || !BowUlt_HasLOSToEnt( core, firePos, prop ) )
			continue
		BowUlt_ZapStructure( core, owner, firePos, prop, tuning.structure_damage_modifier )
	}

	foreach ( entity vehicle in GetEntArrayByClass_Expensive( "player_vehicle" ) )
	{
		if ( !IsValid( vehicle ) || !IsEnemyTeam( team, vehicle.GetTeam() ) || vehicle.GetHealth() <= 0 || !vehicle.DoesShareRealms( core ) )
			continue
		if ( DistanceSqr( vehicle.GetWorldSpaceCenter(), firePos ) > radiusSqr || !BowUlt_HasLOSToEnt( core, firePos, vehicle ) )
			continue
		BowUlt_ZapStructure( core, owner, firePos, vehicle, tuning.vehicle_damage_modifier )
	}
}

void function BowUlt_Pulse( entity core, entity owner, int team )
{
	vector firePos = BowUlt_CoreFirePos( core )
	float radius = BowUlt_GetRadius( owner )
	bool siphon = PlayerHasPassive( owner, ePassives.PAS_ULT_UPGRADE_TWO )

	foreach ( entity blast in BowUlt_StartTeamFxInWorld( BOW_ULT_ORB_BLAST, firePos, team, core, [ 2 ], 1, radius ) )
		thread BowUlt_DestroyAfter( blast, 2.0 )

	BowUlt_PulseStructures( core, owner, team, firePos, radius )
	if ( !IsValid( core ) || !IsValid( owner ) )
		return

	int hits = 0
	foreach ( entity player in GetPlayerArray_Alive() )
	{
		if ( !player.DoesShareRealms( core ) )
			continue

		bool isEnemy = IsEnemyTeam( team, player.GetTeam() )
		if ( !isEnemy && !tuning.hasFriendlySlow )
			continue
		if ( !isEnemy && player == owner )
			continue
		if ( !SparrowAbility_HasLOSToPlayer( core, player, "chargeup_effect", radius ) )
			continue

		foreach ( entity beam in BowUlt_StartTeamFxInWorld( ENEMY_TARGETING_WARP_BEAM_FX, firePos, team, core, [ 2 ] ) )
		{
			EffectSetControlPointVector( beam, 1, player.GetWorldSpaceCenter() )
			thread BowUlt_DestroyAfter( beam, 0.5 )
		}

		float severity = isEnemy ? 1.0 : BOW_ULT_FRIENDLY_SEVERITY
		StatusEffect_AddTimed( player, eStatusEffect.hit_by_sparrow_ult, severity, tuning.hit_by_ult_status_effect_duration, tuning.status_effect_removal_delay )
		StatusEffect_AddTimed( player, eStatusEffect.move_slow, isEnemy ? BOW_ULT_ENEMY_SLOW : BOW_ULT_FRIENDLY_SLOW, tuning.hit_by_ult_slow_duration, tuning.status_effect_removal_delay )

		if ( !isEnemy )
		{
			EmitSoundOnEntity( player, "Sparrow_Ult_Arrow_AttackZap_Friendly" )
			continue
		}

		// Knocked enemies are slowed but take no damage.
		if ( Bleedout_IsBleedingOut( player ) )
			continue

		++hits
		StartParticleEffectOnEntity( player, GetParticleSystemIndex( BOW_ULT_HIT_BY_ULT_3P ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
		StartParticleEffectInWorldForRealms( GetParticleSystemIndex( FIRE_BOLT_HIT_FX ), player.GetWorldSpaceCenter(), <0, 0, 0>, player )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Sparrow_Ult_Arrow_ZapDamage_1p" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Sparrow_Ult_Arrow_ZapDamage_3p" )

		int shieldBefore = player.GetShieldHealth()
		int healthBefore = player.GetHealth()
		player.TakeDamage( tuning.ult_main_damage, owner, core, { damageSourceId = eDamageSourceId.mp_weapon_bow_ult_missile, origin = firePos } )

		if ( siphon && IsValid( owner ) && IsAlive( owner ) )
		{
			int dealt = ( shieldBefore - ( IsValid( player ) ? player.GetShieldHealth() : 0 ) ) + ( healthBefore - ( IsValid( player ) ? player.GetHealth() : 0 ) )
			int heal = int( max( 0, dealt ) * tuning.lifeSiphonHealModifier )
			int toHealth = maxint( 0, minint( heal, owner.GetMaxHealth() - owner.GetHealth() ) )
			if ( toHealth > 0 )
				owner.SetHealth( owner.GetHealth() + toHealth )
			int toShield = heal - toHealth
			if ( toShield > 0 )
				owner.SetShieldHealth( minint( owner.GetShieldHealthMax(), owner.GetShieldHealth() + toShield ) )
		}
	}

	if ( hits == 0 )
		StartParticleEffectInWorldForRealms( GetParticleSystemIndex( FIRE_BOLT_MISS_FX ), firePos, <0, 0, 0>, core )
	else
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Sparrow_Ult_Arrow_AcquireTarget_1p" )
}

// The ult effects take their tint (CPn = RGB 0-255) and radius (CPn.x) from control points
// only the server sets; unset they draw black and zero-sized. One copy per side for the tint.
array<entity> function BowUlt_StartTeamFxOnEntity( entity ent, asset effect, int attachMode, int attachId, int team, array<int> colorCps, int radiusCp = -1, float radius = 0.0 )
{
	int fxId = GetParticleSystemIndex( effect )
	array<entity> out
	foreach ( bool friendly in [ true, false ] )
	{
		entity fx = StartParticleEffectOnEntity_ReturnEntity( ent, fxId, attachMode, attachId )
		if ( !IsValid( fx ) )
			continue
		BowUlt_SetTeamFx( fx, friendly, team, colorCps, radiusCp, radius )
		out.append( fx )
	}
	return out
}

array<entity> function BowUlt_StartTeamFxInWorld( asset effect, vector origin, int team, entity realmEnt, array<int> colorCps, int radiusCp = -1, float radius = 0.0 )
{
	int fxId = GetParticleSystemIndex( effect )
	array<entity> out
	foreach ( bool friendly in [ true, false ] )
	{
		entity fx = StartParticleEffectInWorld_ReturnEntity( fxId, origin, <0, 0, 0> )
		if ( !IsValid( fx ) )
			continue
		fx.RemoveFromAllRealms()
		fx.AddToOtherEntitysRealms( realmEnt )
		BowUlt_SetTeamFx( fx, friendly, team, colorCps, radiusCp, radius )
		out.append( fx )
	}
	return out
}

void function BowUlt_SetTeamFx( entity fx, bool friendly, int team, array<int> colorCps, int radiusCp, float radius )
{
	vector color = friendly ? SPARROW_FRIENDLY_COLOR : SPARROW_ENEMY_COLOR
	foreach ( int cp in colorCps )
		EffectSetControlPointVector( fx, cp, color )
	if ( radiusCp >= 0 )
		EffectSetControlPointVector( fx, radiusCp, < radius, 0, 0 > )
	SetTeam( fx, team )
	fx.kv.VisibilityFlags = friendly ? ( ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_OWNER ) : ENTITY_VISIBLE_TO_ENEMY
}

void function BowUlt_DestroyAfter( entity ent, float delay )
{
	ent.EndSignal( "OnDestroy" )
	wait delay
	ent.Destroy()
}
#endif

#if CLIENT
void function MinimapPackage_BowUlt( entity ent, var rui )
{
	RuiSetImage( rui, "defaultIcon", $"rui/hud/ultimate_icons/ultimate_sparrow" )
	RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/ultimate_icons/ultimate_sparrow" )
	RuiSetBool( rui, "useTeamColor", false )
	RuiSetFloat( rui, "iconBlend", 0.0 )
}

void function CreateArcFX( entity bolt )
{
	bolt.EndSignal( "OnDestroy" )

	while( bolt.GetScriptName() != BOW_ULT_MISSILE_READY_SCRIPT_NAME )
	{
		WaitFrame()
	}

	const vector MAX_ANGLE_DEVIATIONS = <5,5,5>

	array< array<float> >  thetas = [[0.0, 120.0, 240.0], [0.0, 72.0, 144.0, 216.0, 288.0], [0.0, 90.0, 180.0, 270.0], [0.0, 120.0, 240.0]]
	array<float> phis = [-.1, .1, .5, .75]

	float offset = 0
	array<int> fxHandles
	int coreAttachId = bolt.LookupAttachment( "chargeup_effect" )
	vector startCastPoint = bolt.GetAttachmentOrigin( coreAttachId )
	for( int phiIndex = 0; phiIndex < phis.len(); phiIndex++ )
	{
		float p = phis[phiIndex]
		array<float> thetaArr = thetas[phiIndex]
		foreach( float t in thetaArr )
		{
			float theta = DegToRad( t ) + offset
			float phi = acos( p )
			float x = sin(phi) * cos(theta);
			float y = sin(phi) * sin(theta);
			float z = cos(phi);
			vector dir = <x,y,z>

			fxHandles.append( ArcConnect_Thread( bolt, startCastPoint, dir, MAX_ANGLE_DEVIATIONS ) )
		}
		offset += 45
	}

	thread UpdateArcFxVisibility_Thread( bolt, fxHandles )
}

int function ArcConnect_Thread( entity bolt, vector startCastPoint, vector dir, vector maxAngleDeviations )
{
	entity player = bolt.GetOwner()
	int fxHandle = -1
	if( !IsValid( player ) )
		return fxHandle

	vector moddedAngles = < RandomFloatRange( -maxAngleDeviations.x, maxAngleDeviations.x ), RandomFloatRange( -maxAngleDeviations.y, maxAngleDeviations.y ), RandomFloatRange( -maxAngleDeviations.z, maxAngleDeviations.z ) >
	vector dirModified  = Normalize( dir )

	if ( maxAngleDeviations.x > 0)
		dirModified = VectorRotateAxis( dirModified, bolt.GetForwardVector(),moddedAngles.x )
	if ( maxAngleDeviations.y > 0)
		dirModified = VectorRotateAxis( dirModified, bolt.GetRightVector(),moddedAngles.y )
	if ( maxAngleDeviations.z > 0)
		dirModified = VectorRotateAxis( dirModified, bolt.GetUpVector(),moddedAngles.z )

	dirModified = Normalize( dirModified )

	TraceResults arcTrace = TraceLine( startCastPoint, startCastPoint + dirModified * BowUlt_GetRadius( player ), [ bolt ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	int crawlFxId = GetParticleSystemIndex( arcTrace.fraction == 1.0 ? ULT_TARGET_FULL_BEAM_FX : ULT_TARGET_BEAM_FX )
	fxHandle = StartParticleEffectOnEntity( bolt, crawlFxId, FX_PATTACH_POINT_FOLLOW, bolt.LookupAttachment( "chargeup_effect" ) )
	EffectSetControlPointVector( fxHandle, 1, arcTrace.endPos )

	return fxHandle
}

void function UpdateArcFxVisibility_Thread( entity core, array<int> handles )
{
	core.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( handles )
		{
			foreach( int handle in handles )
			{
				if ( EffectDoesExist( handle ) )
					EffectStop( handle, true, true )
			}
		}
	)

	while( true )
	{
		entity localPlayer = GetLocalViewPlayer()
		entity owner = core.GetOwner()
		if( !IsValid( owner ) )
			return
		float coreRadius =  BowUlt_GetRadius( owner )
		int ownerTeam = owner.GetTeam()
		if( IsValid( localPlayer ) )
		{
			if( core.GetScriptName() == BOW_ULT_MISSILE_FIRING_SCRIPT_NAME )
				return

			bool shouldShow = ownerTeam == localPlayer.GetTeam() || DistanceSqr( localPlayer.GetOrigin(), core.GetOrigin() ) > ( coreRadius * coreRadius )
			foreach( int handle in handles )
			{
				if( !EffectDoesExist( handle ) )
					continue

				if( shouldShow )
					EffectRestart( handle, true, true )
				else
					EffectSleep( handle )
			}
		}

		WaitFrame()
	}
}

void function BowUltSourceCreated( entity prop )
{
	AddBowUltThreatIndicator( prop )
	thread CreateArcFX( prop )

	int team = prop.GetTeam()

	entity player = GetLocalViewPlayer()
	if( !IsValid( player ) || team != player.GetTeam() )
		return

	array<entity> teammates = GetPlayerArrayOfTeam( team )

	foreach( teammate in teammates )
	{
		thread CreateUltIconForTeam( prop, teammate )
	}
}

void function AddBowUltThreatIndicator( entity prop )
{
	entity player = GetLocalViewPlayer()
	if( !IsValid( player ) || prop.GetTeam() == player.GetTeam() )
		return
	float dangerIndicatorRadius = BowUlt_GetRadius( player )
	ShowGrenadeArrow( player, prop, dangerIndicatorRadius, 0.0 )
	thread TetherDirectionalEffect_Thread( player, prop )
}

void function CreateUltIconForTeam( entity prop, entity player )
{
	prop.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath", "OnDestroy" )

	// Lifted into ui_fs: a file-scope $"" asset would intern null for it.
	var rui = RuiCreate( GetKeyValueAsAsset( { kn = "ui/in_world_sparrow_ult_icon.rpak" }, "kn" ), clGlobal.topoFullScreen, RUI_DRAW_HUD, 1 )

	InitHUDRui( rui )

	RuiTrackFloat3( rui, "pos", prop, RUI_TRACK_ABSORIGIN_FOLLOW )
	RuiTrackFloat3( rui, "playerAngles", player, RUI_TRACK_CAMANGLES_FOLLOW )
	RuiKeepSortKeyUpdated( rui, true, "pos" )
	RuiSetBool( rui, "isVisible", true )
	RuiSetBool( rui, "clampToScreen", true )

	OnThreadEnd(
		function() : ( rui )
		{
			RuiDestroyIfAlive( rui )
		}
	)

	while( true )
	{
		if( prop.GetScriptName() == BOW_ULT_MISSILE_CLOSING_SCRIPT_NAME )
			return

		WaitFrame()
	}
}

void function TetherDirectionalEffect_Thread( entity player, entity prop )
{
	prop.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath", "OnDestroy" )

	PassByReferenceInt tetherFx
	tetherFx.value = -1
	PassByReferenceInt forwardTetherFx
	forwardTetherFx.value = -1
	int tetherFxId = GetParticleSystemIndex( MISSILE_ULT_TETHER_INDICATOR_FX )
	int Laser1pFxId  = GetParticleSystemIndex( BOW_ULT_TARGETING_1P_LASER_FX )
	float radiusSqr = BowUlt_GetRadius( player ) * BowUlt_GetRadius( player )

	OnThreadEnd(
		function() : ( tetherFx, forwardTetherFx, prop )
		{
			if( tetherFx.value > -1 && EffectDoesExist( tetherFx.value ) )
			{
				EffectStop( tetherFx.value, true, true )
			}
			if( forwardTetherFx.value > -1 && EffectDoesExist( forwardTetherFx.value ) )
			{
				EffectStop( forwardTetherFx.value, true, true )
			}
		}
	)

	while ( true )
	{
		if( prop.GetScriptName() == BOW_ULT_MISSILE_CLOSING_SCRIPT_NAME )
			return

		bool shouldShowIndicator = DistanceSqr( player.GetOrigin(), prop.GetOrigin() ) < radiusSqr && SparrowAbility_HasLOSToPlayer( prop, player, "chargeup_effect", BowUlt_GetRadius( prop.GetOwner() ) )
		if( shouldShowIndicator )
		{
			if( tetherFx.value == -1 || !EffectDoesExist( tetherFx.value ) )
			{
				tetherFx.value = StartParticleEffectOnEntity( player, tetherFxId, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
			}
			if( forwardTetherFx.value == -1 || !EffectDoesExist( forwardTetherFx.value ) )
			{
				forwardTetherFx.value = StartParticleEffectOnEntity( player, Laser1pFxId, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
			}
			vector playerToTether = prop.GetOrigin() - player.GetOrigin()
			vector playerToTetherAngles = VectorToAngles( FlattenVec( playerToTether ) )
			playerToTetherAngles -= <0, 180.0, 0>

			vector eyeAngles = player.EyeAngles()
			eyeAngles = FlattenAngles( eyeAngles )

			vector fxAngle = playerToTetherAngles - eyeAngles + <0, 90, 0>
			fxAngle.y = AngleNormalize( fxAngle.y )
			if ( fabs( fxAngle.y + 90.0 ) < 70.0 )
				fxAngle.y = fxAngle.y > -90.0 ? -20.0 : -160.0

			EffectSetControlPointAngles( tetherFx.value, 10, fxAngle )
			EffectSetControlPointVector( tetherFx.value, 4, prop.GetOrigin() )
			EffectSetControlPointVector( tetherFx.value, 1, <100, 0, 0> )

			EffectSetControlPointVector( forwardTetherFx.value, 0, player.GetOrigin() )
			EffectSetControlPointVector( forwardTetherFx.value, 1, prop.GetOrigin() )
		}
		else if( tetherFx.value != -1 && EffectDoesExist( tetherFx.value ) )
		{
			EffectStop( tetherFx.value, true, true )
			tetherFx.value = -1

			EffectStop( forwardTetherFx.value, true, true )
			forwardTetherFx.value = -1
		}
		WaitFrame()
	}
}

void function BowUltScreenVFXEnabled( entity ent, int statusEffect, bool actuallyChanged )
{
	if ( !actuallyChanged )
		return

	entity viewPlayer = GetLocalViewPlayer()
	if ( ent != viewPlayer )
		return

	thread BowUltSlow_1PFX_Thread( viewPlayer )
}

void function BowUltScreenVFXDisabled( entity ent, int statusEffect, bool actuallyChanged )
{
	if ( !actuallyChanged )
		return

	if ( ent != GetLocalViewPlayer() )
		return

	ent.Signal( "BowUltEnded" )
}

void function BowUltSlow_1PFX_Thread( entity player )
{
	player.EndSignal( "OnDeath", "OnDestroy", "BleedOut_OnStartDying", "BowUltEnded" )

	float effectSeverity = StatusEffect_GetSeverity( player, eStatusEffect.hit_by_sparrow_ult )

	entity cockpit = player.GetCockpit()
	if ( !IsValid( cockpit ) )
		return

	int fxHandle

	if( effectSeverity <= BOW_ULT_FRIENDLY_SEVERITY )
	{
		fxHandle = StartParticleEffectOnEntity( cockpit, file.cockpitScreenFriendlyFx, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
		EffectSetControlPointVector( fxHandle, 1, SPARROW_FRIENDLY_COLOR )
	}
	else
	{
		fxHandle = StartParticleEffectOnEntity( cockpit, file.cockpitScreenFx, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
		EffectSetControlPointVector( fxHandle, 1, SPARROW_ENEMY_COLOR )
	}

	EffectSetIsWithCockpit( fxHandle, true )
	OnThreadEnd(
		function() : ( fxHandle )
		{
			if ( EffectDoesExist( fxHandle ) )
				EffectStop( fxHandle, false, true )
		}
	)

	for ( ;; )
	{
		if ( !EffectDoesExist( fxHandle ) )
			break

		WaitFrame()
	}
}
#endif
