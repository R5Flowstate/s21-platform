global function MpAbilityHalo_Init

global function OnWeaponTossPrep_ability_halo
global function OnWeaponToss_ability_halo
global function OnWeaponTossReleaseAnimEvent_ability_halo
global function OnWeaponDeactivate_ability_halo
global function OnWeaponTossCancel_ability_halo
global function IsHalo
global function IsHaloShield
global function Halo_IsAllowedStickyEnt

global const string HALO_SCRIPTNAME 		= "lifeline_halo"
global const string HALO_SHIELD_SCRIPTNAME 	= "lifeline_halo_shield"
global const string HALO_MOVER_NAME 		= "lifeline_halo_mover"
global const string HALO_WEAPON_NAME 		= "mp_ability_lifeline_halo"

const asset HALO_MODEL = $"mdl/props/lifeline_drone_rework/lifeline_drone_rework.rmdl"
const asset HALO_SHIELD_MODEL = $"mdl/fx/shield_wall_col.rmdl"

const asset HALO_SHIELD_FX = $"P_LLR_shield_MDL"
const asset HALO_SHIELD_LOW_FX = $"P_LLR_shield_glitch_MDL"
const asset HALO_DESTROY_FX = $"P_LLR_halo_exp"
const asset HALO_SHOCKWAVE_FX = $"P_halo_shockwave"
const asset HALO_HEAL_FX_1P = $"P_LLR_ult_boost_screen"
const asset HALO_HEAL_GROUND_FX = $"P_LLR_halo_teleport_beam"
const asset HALO_RADIUS_PREVIEW_FX = $"LLR_halo_AR_mesh"
const asset FX_DRONE_MEDIC_JET_CTR = $"P_LL_med_drone_jet_ctr_loop"
const asset FX_DRONE_MEDIC_EYE = $"P_LL_med_drone_eye"
const asset FX_DRONE_MEDIC_JET_LOOP = $"P_LL_med_drone_jet_loop"
const vector HALO_COLOR_FRIENDLY = <30, 225, 177>
const vector HALO_COLOR_ENEMY = <255, 66, 100>

const string HALO_DEPLOY_SOUND = "LifelineRevived_Ult_Start_3p"
const string HALO_DURATION_WARNING_SOUND = "LifelineRevived_Ult_Ending_3p"
const string HALO_DESTROY_SOUND = "LifelineRevived_Ult_Stop_3p"
const string HALO_IDLE_SOUND = "LifelineRevived_Ult_Loop_3p"
const string HALO_APPLY_FAST_HEAL_SOUND = "LifelineRevived_Ult_FastHeal_Enabled_1p"
const string HALO_REMOVE_FAST_HEAL_SOUND = "LifelineRevived_Ult_FastHeal_Disabled_1p"
const string HALO_PERIMETER_SOUND = "LifelineRevived_Ult_Loop_Perimeter_3p"
const string HALO_RING_DAMAGE_SOUND = "VoidRing_Damage"
const string HALO_VO = "bc_superHalo"

const float HALO_LIFETIME = 20.0
const float HALO_ACTIVATION_DELAY = 0.75
const float HALO_DURATION_WARNING = 5.0
const float HALO_RADIUS = 245
const float HALO_TRIGGER_HEIGHT = 160
const vector HALO_RADIUS_PREVIEW_COLOR = <60, 110, 300>
const float HALO_RING_DAMAGE_MULTIPLIER = 2
const vector HALO_INTERSECTION_BOUND_MINS = <-16, -16, 0>
const vector HALO_INTERSECTION_BOUND_MAXS = <16, 16, 32>

const bool HALO_DEBUG_DRAW = false
const bool HALO_DEBUG_DRAW_INTERSECTION = false

#if SERVER
const float HALO_PLANT_TRACE_DIST = 64.0
const float HALO_HOVER_HEIGHT = 48.0
const float HALO_ZONE_TICK = 0.1
#endif

struct
{
	#if SERVER
		// Players we granted PAS_FAST_HEAL to, per halo; a mode-granted one is never taken.
		table< entity, table<entity, bool> > fastHealGiven
	#endif

	float lifetime
	float activationDelay
	float durationWarning
	float haloRadius
	float haloTriggerHeight
} file

void function MpAbilityHalo_Init()
{
	PrecacheWeapon( HALO_WEAPON_NAME )
	PrecacheModel( HALO_MODEL )
	PrecacheModel( HALO_SHIELD_MODEL )

	PrecacheParticleSystem( HALO_SHIELD_FX )
	PrecacheParticleSystem( HALO_SHIELD_LOW_FX )
	PrecacheParticleSystem( HALO_DESTROY_FX )
	PrecacheParticleSystem( HALO_SHOCKWAVE_FX )
	PrecacheParticleSystem( HALO_HEAL_GROUND_FX )
	PrecacheParticleSystem( FX_DRONE_MEDIC_JET_CTR )
	PrecacheParticleSystem( FX_DRONE_MEDIC_EYE )
	PrecacheParticleSystem( FX_DRONE_MEDIC_JET_LOOP )

	#if CLIENT
		PrecacheParticleSystem( HALO_HEAL_FX_1P )
		PrecacheParticleSystem( HALO_RADIUS_PREVIEW_FX )

		RegisterSignal( "EndRadiusPreview" )

		StatusEffect_RegisterEnabledCallback( eStatusEffect.halo_visuals, Halo_HealVisualsEnabled )
		StatusEffect_RegisterDisabledCallback( eStatusEffect.halo_visuals, Halo_HealVisualsDisabled )

		AddCreateCallback( "prop_script", OnClientHaloCreated )

		AddCallback_MinimapEntShouldCreateCheck_Scriptname( HALO_SCRIPTNAME, Minimap_DontCreateRuisForEnemies )
	#endif

	#if SERVER
		RegisterSignal( "EndRadiusPreview" )
		RegisterSignal( "Halo_End" )
		RegisterSignal( "Halo_ShieldLow" )
	#endif

	PrecacheScriptString( HALO_SCRIPTNAME )
	PrecacheScriptString( HALO_SHIELD_SCRIPTNAME )

	file.lifetime        	= GetCurrentPlaylistVarFloat( "lifeline_halo_lifetime", HALO_LIFETIME )
	file.activationDelay 	= GetCurrentPlaylistVarFloat( "lifeline_halo_activationDelay", HALO_ACTIVATION_DELAY )
	file.durationWarning	= GetCurrentPlaylistVarFloat( "lifeline_halo_durationWarning", HALO_DURATION_WARNING )
	file.haloRadius 		= GetCurrentPlaylistVarFloat( "lifeline_halo_radius", HALO_RADIUS )
	file.haloTriggerHeight 	= GetCurrentPlaylistVarFloat( "lifeline_halo_trigger_height", HALO_TRIGGER_HEIGHT )
}

void function OnWeaponTossPrep_ability_halo( entity weapon, WeaponTossPrepParams prepParams )
{
	weapon.EmitWeaponSound_1p3p( GetGrenadeDeploySound_1p( weapon ), GetGrenadeDeploySound_3p( weapon ) )

	#if CLIENT
		if ( weapon.GetWeaponOwner() != GetLocalViewPlayer() )
			return

		thread WeaponActiveThread_Client( weapon.GetWeaponOwner(), weapon )
	#endif
}

var function OnWeaponToss_ability_halo( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetOwner()
	if ( !IsValid( owner ) )
		return

	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	#if CLIENT
		owner.Signal("EndRadiusPreview")
	#endif

	return -1
}

var function OnWeaponTossReleaseAnimEvent_ability_halo( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetOwner()
	if ( !IsValid( owner ) )
		return

	int ammoReq = weapon.GetAmmoPerShot()

	#if CLIENT
		owner.Signal("EndRadiusPreview")
	#endif

	entity deployable = ThrowDeployable( weapon, attackParams, 1.0, OnHaloPlanted, null, null )
	if ( deployable )
	{
		entity player = weapon.GetWeaponOwner()
		PlayerUsedOffhand( player, weapon, true, deployable )

		#if SERVER
			string projectileSound = GetGrenadeProjectileSound( weapon )
			if ( projectileSound != "" )
				EmitSoundOnEntity( deployable, projectileSound )

			weapon.w.lastProjectileFired = deployable
			PlayBattleChatterLineToSpeakerAndTeam( player, HALO_VO )
		#endif
	}

	return ammoReq
}

void function OnWeaponDeactivate_ability_halo( entity weapon )
{
	#if CLIENT
		entity owner = weapon.GetOwner()
		if ( !IsValid( owner ) )
			return

		owner.Signal("EndRadiusPreview")
	#endif
}

var function OnWeaponTossCancel_ability_halo( entity weapon, WeaponPrimaryAttackParams attackParams)
{
	#if CLIENT
		entity owner = weapon.GetOwner()
		if ( !IsValid( owner ) )
			return

		owner.Signal("EndRadiusPreview")
	#endif

	return 0
}

bool function IsHalo( entity ent )
{
	if( !IsValid( ent ) )
		return false

	return ent.GetScriptName() == HALO_SCRIPTNAME
}

bool function IsHaloShield( entity ent )
{
	if( !IsValid( ent ) )
		return false

	return ent.GetScriptName() == HALO_SHIELD_SCRIPTNAME
}

bool function ShouldApplyHaloEffects( entity ent )
{
	if( !IsValid( ent ) )
		return false

	if( !ent.IsPlayer() || ent.IsPlayerDecoy() || IsTrainingDummie( ent ))
		return false

	return true
}

void function OnHaloPlanted( entity projectile, DeployableCollisionParams collisionParams )
{
	#if SERVER
		thread Halo_Deploy( projectile )
	#endif
}

bool function Halo_IsAllowedStickyEnt( entity halo, entity stickyEnt, string stickyEntWeaponClassName )
{
	if( !IsValid( halo ) || !IsValid( stickyEnt ) )
		return false
	if( IsFriendlyTeam( stickyEnt.GetTeam(), halo.GetTeam() ) )
		return false

	bool allowStick = false

	if ( stickyEntWeaponClassName == "mp_weapon_cluster_bomb_launcher" )
		allowStick = true

	if ( ( stickyEntWeaponClassName == "mp_weapon_arc_bolt" ) || ( stickyEntWeaponClassName == TETHER_TRAP_SCRIPTNAME ) )
		allowStick = true

	if( stickyEntWeaponClassName == "mp_ability_debuff_zone" )
		allowStick = true

	if ( stickyEntWeaponClassName == GRENADE_EMP_WEAPON_NAME )
		allowStick = true

	if( allowStick )
		thread Halo_TrackStickyEnt_Thread( halo, stickyEnt )

	return allowStick
}

void function Halo_TrackStickyEnt_Thread( entity halo, entity stickyEnt )
{
	EndSignal( halo, "OnDestroy" )
	EndSignal( stickyEnt, "OnDestroy" )

	bool hadLoS = true

	array<entity> ignoreArray	= HaloIgnoreArray()
	TraceResults initialTrace = TraceLine( halo.GetOrigin(), stickyEnt.GetOrigin(), ignoreArray, TRACE_MASK_VISIBLE, TRACE_COLLISION_GROUP_NONE )

	if(initialTrace.fraction < 1)
		hadLoS = false

	WaitFrame()

	while ( true )
	{
		if( !IsValid( halo ) )
			return
		if( !IsValid( stickyEnt ) )
			return

		ignoreArray	= HaloIgnoreArray()
		TraceResults results = TraceLine( halo.GetOrigin(), stickyEnt.GetOrigin(), ignoreArray, TRACE_MASK_VISIBLE, TRACE_COLLISION_GROUP_NONE )
		if(	results.fraction < 1 )
		{
			#if SERVER
				stickyEnt.ClearParent()
				if( hadLoS )
					stickyEnt.SetAbsOrigin( results.endPos )
			#endif
			return
		}

		WaitFrame()
	}
}

array<entity> function HaloIgnoreArray()
{
	array<entity> ignoreArray = GetPlayerArray_Alive()

	foreach ( haloShield in GetEntArrayByScriptName( HALO_SHIELD_SCRIPTNAME ) )
	{
		if( IsValid( haloShield ) )
			ignoreArray.append( haloShield )
	}

	foreach ( shadowShield in GetEntArrayByScriptName( FORGED_SHADOWS_SHIELD_NAME ) )
	{
		if( IsValid( shadowShield ) )
			ignoreArray.append( shadowShield )
	}

	foreach ( shieldWall in GetEntArrayByScriptName( MOBILE_SHIELD_SCRIPTNAME ) )
	{
		if( IsValid( shieldWall ) )
			ignoreArray.append( shieldWall )
	}

	foreach ( shield in GetEntArrayByScriptName( SHIELD_THROW_SCRIPTNAME ) )
	{
		if( IsValid( shield ) )
			ignoreArray.append( shield )
	}

	foreach ( bubble in GetEntArrayByScriptName( BUBBLE_SHIELD_SCRIPTNAME ) )
	{
		if( IsValid( bubble ) )
			ignoreArray.append( bubble )
	}

	ignoreArray.extend( GetPlayerDecoyArray() )

	return ignoreArray
}

void function RestartCooldown( entity player, float refundAmountFrac )
{
	if ( player )
	{
		entity ultimateWeapon = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
		if ( IsValid( ultimateWeapon ) )
		{
			ultimateWeapon.SetWeaponPrimaryClipCount( 0 )
			ultimateWeapon.OverrideNextAttackTime( Time() )

			if ( refundAmountFrac > 0 )
				ultimateWeapon.SetWeaponPrimaryClipCount( int( ultimateWeapon.GetWeaponPrimaryClipCountMax() * refundAmountFrac ) )
		}
	}
}

#if SERVER
void function Halo_Deploy( entity projectile )
{
	if ( !IsValid( projectile ) )
		return

	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) )
	{
		projectile.Destroy()
		return
	}

	vector origin = projectile.GetOrigin()
	TraceResults groundTrace = TraceLine( origin + <0, 0, 8>, origin - <0, 0, HALO_PLANT_TRACE_DIST>, [ projectile ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_BLOCK_WEAPONS_AND_PHYSICS )
	vector groundPos = groundTrace.fraction < 1.0 ? groundTrace.endPos : origin
	entity groundParent = ( IsValid( groundTrace.hitEnt ) && EntityShouldStick( projectile, groundTrace.hitEnt ) ) ? groundTrace.hitEnt : projectile.GetParent()
	vector angles = <0, projectile.proj.savedAngles.y, 0>
	int team = owner.GetTeam()
	projectile.Destroy()

	entity mover = CreateScriptMover_NEW( HALO_MOVER_NAME, groundPos, angles )
	if ( IsValid( groundParent ) )
		mover.SetParent( groundParent, "", true, 0.0 )

	entity halo = CreatePropScript( HALO_MODEL, groundPos + <0, 0, HALO_HOVER_HEIGHT>, angles )
	halo.SetScriptName( HALO_SCRIPTNAME )
	halo.SetOwner( owner )
	SetTeam( halo, team )
	halo.RemoveFromAllRealms()
	halo.AddToOtherEntitysRealms( owner )
	halo.SetParent( mover, "", true, 0.0 )
	halo.SetTakeDamageType( DAMAGE_NO )
	halo.SetBlocksRadiusDamage( false )
	halo.e.ignoreJumpPad = true
	halo.Highlight_Enable()
	Highlight_SetOwnedHighlight( halo, "sp_friendly_hero" )
	Highlight_SetFriendlyHighlight( halo, "sp_friendly_hero" )
	AddSonarDetectionForPropScript( halo )
	AddEMPDestroyDeviceNoDissolve( halo )
	FiringRange_AddToRemoveOnCharacterChange( halo, owner )
	thread TrapDestroyOnRoundEnd( owner, halo )

	array<entity> fx
	int eye = halo.LookupAttachment( "EYEGLOW" )
	if ( eye > 0 )
		fx.append( StartParticleEffectOnEntity_ReturnEntity( halo, GetParticleSystemIndex( FX_DRONE_MEDIC_EYE ), FX_PATTACH_POINT_FOLLOW, eye ) )
	foreach ( vent in [ "VENT_RF", "VENT_LF", "VENT_RR", "VENT_LR" ] )
	{
		int id = halo.LookupAttachment( vent )
		if ( id > 0 )
			fx.append( StartParticleEffectOnEntity_ReturnEntity( halo, GetParticleSystemIndex( FX_DRONE_MEDIC_JET_LOOP ), FX_PATTACH_POINT_FOLLOW, id ) )
	}

	EmitSoundOnEntity( halo, HALO_DEPLOY_SOUND )
	EmitSoundOnEntity( halo, HALO_IDLE_SOUND )
	thread Halo_DroneAnims( halo )

	entity shield = null
	entity wp = CreateWaypoint_Ping_Location( owner, ePingType.ABILITY_DRONEMEDIC, halo, halo.GetOrigin(), -1, false )
	file.fastHealGiven[halo] <- {}

	EndSignal( halo, "OnDestroy", "Halo_End" )
	EndSignal( owner, "OnDestroy", "CleanupAllDroneMedics" )
	EndThreadOn_PlayerChangedClass( owner )

	OnThreadEnd(
		function() : ( halo, mover, fx, wp )
		{
			if ( halo in file.fastHealGiven )
			{
				foreach ( player, given in file.fastHealGiven[halo] )
					Halo_RemoveEffects( halo, player )
				delete file.fastHealGiven[halo]
			}

			foreach ( e in fx )
			{
				if ( IsValid( e ) )
					e.Destroy()
			}
			if ( IsValid( wp ) )
				wp.Destroy()

			if ( IsValid( halo ) )
			{
				vector pos = halo.GetOrigin()
				StopSoundOnEntity( halo, HALO_IDLE_SOUND )
				EmitSoundAtPosition( TEAM_UNASSIGNED, pos, HALO_DESTROY_SOUND, halo )
				StartParticleEffectInWorldForRealms( GetParticleSystemIndex( HALO_DESTROY_FX ), pos, <0, 0, 0>, halo )
				StartParticleEffectInWorldForRealms( GetParticleSystemIndex( HALO_SHOCKWAVE_FX ), pos, <0, 0, 0>, halo )
				RemoveSonarDetectionForPropScript( halo )
				halo.Destroy()
			}
			if ( IsValid( mover ) )
				mover.Destroy()
		}
	)

	wait file.activationDelay

	shield = Halo_CreateShield( halo, mover, owner, team )
	AddEntityDestroyedCallback( shield,
		void function( entity ent ) : ( halo )
		{
			if ( IsValid( halo ) )
				halo.Signal( "Halo_End" )
		}
	)
	OnThreadEnd(
		function() : ( shield )
		{
			if ( IsValid( shield ) )
				shield.Destroy()
		}
	)

	float endTime = Time() + file.lifetime - file.activationDelay
	bool warned = false
	while ( Time() < endTime )
	{
		if ( !warned && endTime - Time() <= file.durationWarning )
		{
			warned = true
			EmitSoundOnEntity( halo, HALO_DURATION_WARNING_SOUND )
			if ( IsValid( shield ) )
				shield.Signal( "Halo_ShieldLow" )
		}

		Halo_UpdateZone( halo )
		wait HALO_ZONE_TICK
	}
}

void function Halo_DroneAnims( entity halo )
{
	EndSignal( halo, "OnDestroy" )

	if ( halo.LookupSequence( "lifeline_drone_ult_arming" ) != -1 )
	{
		halo.Anim_PlayOnly( "lifeline_drone_ult_arming" )
		WaittillAnimDone( halo )
	}
	if ( halo.LookupSequence( "ult_idle" ) != -1 )
		halo.Anim_PlayOnly( "ult_idle" )
}

entity function Halo_CreateShield( entity halo, entity mover, entity owner, int team )
{
	vector origin = mover.GetOrigin()

	entity shield = CreateEntity( "prop_script" )
	shield.SetValueForModelKey( HALO_SHIELD_MODEL )
	shield.kv.solid = SOLID_VPHYSICS
	shield.kv.contents = ( int( shield.kv.contents ) | CONTENTS_NOGRAPPLE )
	shield.e.ignorePingTrace = true
	shield.SetOrigin( origin )
	shield.SetAngles( mover.GetAngles() )
	shield.SetScriptName( HALO_SHIELD_SCRIPTNAME )
	shield.SetScriptPropFlags( SPF_BLOCKS_AI_NAVIGATION )
	shield.kv.CollisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS
	shield.SetBlocksRadiusDamage( true )
	shield.SetBlocksLOS( false )
	DispatchSpawn( shield )
	shield.Hide()
	SetTeam( shield, team )
	shield.SetOwner( owner )
	shield.RemoveFromAllRealms()
	shield.AddToOtherEntitysRealms( owner )
	shield.SetParent( mover, "", true, 0.0 )

	entity friendlyFX = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( HALO_SHIELD_FX ), origin, <0, 0, 0> )
	SetTeam( friendlyFX, team )
	friendlyFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_OWNER
	EffectSetControlPointVector( friendlyFX, 1, HALO_COLOR_FRIENDLY )
	friendlyFX.SetParent( shield )

	entity enemyFX = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( HALO_SHIELD_FX ), origin, <0, 0, 0> )
	SetTeam( enemyFX, team )
	enemyFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY
	EffectSetControlPointVector( enemyFX, 1, HALO_COLOR_ENEMY )
	enemyFX.SetParent( shield )

	entity groundFX = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( HALO_HEAL_GROUND_FX ), origin, <0, 0, 0> )
	groundFX.SetParent( shield )

	EmitSoundOnEntity( shield, HALO_PERIMETER_SOUND )
	thread Halo_ShieldLowFX_Thread( shield, team )

	return shield
}

void function Halo_ShieldLowFX_Thread( entity shield, int team )
{
	EndSignal( shield, "OnDestroy" )
	WaitSignal( shield, "Halo_ShieldLow" )

	entity lowFX = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( HALO_SHIELD_LOW_FX ), shield.GetOrigin(), <0, 0, 0> )
	SetTeam( lowFX, team )
	lowFX.SetParent( shield )
}

bool function Halo_IsInside( entity halo, entity ent )
{
	vector center = halo.GetParent() != null ? halo.GetParent().GetOrigin() : halo.GetOrigin()
	vector delta = ent.GetOrigin() - center
	if ( Length2D( delta ) > file.haloRadius )
		return false
	return delta.z >= -HALO_INTERSECTION_BOUND_MAXS.z && delta.z <= file.haloTriggerHeight
}

void function Halo_UpdateZone( entity halo )
{
	table<entity, bool> given = file.fastHealGiven[halo]

	foreach ( player in GetPlayerArray_Alive() )
	{
		bool inside = ShouldApplyHaloEffects( player ) && halo.DoesShareRealms( player ) && Halo_IsInside( halo, player )
		bool tracked = player in given
		if ( inside && !tracked )
		{
			given[player] <- !PlayerHasPassive( player, ePassives.PAS_FAST_HEAL )
			if ( given[player] )
				GivePassive( player, ePassives.PAS_FAST_HEAL )
			StatusEffect_AddEndless( player, eStatusEffect.halo_visuals, 1.0 )
		}
		else if ( !inside && tracked )
		{
			Halo_RemoveEffects( halo, player )
			delete given[player]
		}
	}

	foreach ( player, wasGiven in clone given )
	{
		if ( !IsValid( player ) || !IsAlive( player ) )
		{
			if ( IsValid( player ) )
				Halo_RemoveEffects( halo, player )
			delete given[player]
		}
	}
}

void function Halo_RemoveEffects( entity halo, entity player )
{
	if ( !IsValid( player ) )
		return

	if ( ( halo in file.fastHealGiven ) && ( player in file.fastHealGiven[halo] ) && file.fastHealGiven[halo][player]
		&& PlayerHasPassive( player, ePassives.PAS_FAST_HEAL ) && !Halo_IsInsideAnyOther( halo, player ) )
		TakePassive( player, ePassives.PAS_FAST_HEAL )

	if ( !Halo_IsInsideAnyOther( halo, player ) )
		StatusEffect_StopAllOfType( player, eStatusEffect.halo_visuals )
}

bool function Halo_IsInsideAnyOther( entity halo, entity player )
{
	foreach ( other, given in file.fastHealGiven )
	{
		if ( other != halo && IsValid( other ) && ( player in given ) )
			return true
	}
	return false
}
#endif // SERVER

#if CLIENT
void function OnClientHaloCreated( entity halo )
{
	if ( halo.GetScriptName() != HALO_SHIELD_SCRIPTNAME )
		return

	thread HaloAmbientSound_Thread( halo )

	AddToAllowedAirdropDynamicEntities( halo )
	AddAirdropTraceIgnoreEnt( halo )
}

void function HaloAmbientSound_Thread( entity halo )
{
	Assert( IsNewThread(), "Must be threaded off" )
	EndSignal( halo, "OnDeath", "OnDestroy" )

	wait file.activationDelay

	var ambientLoop = EmitSoundOnSphere( halo.GetOrigin(), file.haloRadius, HALO_PERIMETER_SOUND, true )

	OnThreadEnd(
		function() : ( halo, ambientLoop )
		{
			StopSound( ambientLoop )
		}
	)

	WaitForever()
}

void function WeaponActiveThread_Client( entity owner, entity weapon )
{
	EndSignal( owner, "OnDeath", "OnDestroy", "EndRadiusPreview" )
	EndSignal( weapon, "OnDestroy" )

	wait 0.2

	int ringFX = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( HALO_RADIUS_PREVIEW_FX ), ZERO_VECTOR, ZERO_VECTOR )

	EffectSetControlPointVector( ringFX, 2, HALO_RADIUS_PREVIEW_COLOR )
	EffectSetControlPointVector( ringFX, 1, <file.haloRadius, file.haloRadius, file.haloRadius> )

	OnThreadEnd(
		function() : ( owner, ringFX, weapon)
		{
			if( EffectDoesExist( ringFX ) )
				EffectStop( ringFX, true, false )

			if( IsValid( weapon ) )
				weapon.ClearIndicatorEffectOverrides()
		}
	)

	while( EffectDoesExist( ringFX ) )
	{
		vector predictedImpactPos = weapon.GetMostRecentGrenadeImpactPos()
		EffectSetControlPointVector( ringFX, 0, predictedImpactPos )

		WaitFrame()
	}
}

void function Halo_HealVisualsEnabled( entity ent, int statusEffect, bool actuallyChanged )
{
	if ( ent != GetLocalViewPlayer() )
		return

	entity player = ent

	entity cockpit = player.GetCockpit()
	if ( !IsValid( cockpit ) )
		return

	int fastHealsEnabled = StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( HALO_HEAL_FX_1P ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	EffectSetIsWithCockpit( fastHealsEnabled, true )
	EffectSetControlPointVector( fastHealsEnabled, 1, <1, 1, 1> )

	EmitSoundOnEntity( player, HALO_APPLY_FAST_HEAL_SOUND )
}

void function Halo_HealVisualsDisabled( entity ent, int statusEffect, bool actuallyChanged )
{
	if ( ent != GetLocalViewPlayer() )
		return

	entity player = ent

	entity cockpit = player.GetCockpit()
	if ( !IsValid( cockpit ) )
		return

	int fastHealsDisabled = StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( HALO_HEAL_FX_1P ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	EffectSetIsWithCockpit( fastHealsDisabled, true )
	EffectSetControlPointVector( fastHealsDisabled, 1, <1, 1, 1> )

	EmitSoundOnEntity( player, HALO_REMOVE_FAST_HEAL_SOUND )
}

#endif // CLIENT
