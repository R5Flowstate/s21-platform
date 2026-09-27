global function MpWeaponSonarDart_Init

global function OnWeaponActivate_SonarDart
global function OnWeaponDeactivate_SonarDart
global function OnWeaponTossCancel_weapon_SonarDart
global function OnWeaponTossReleaseAnimEvent_weapon_SonarDart
global function OnProjectileCollision_weapon_SonarDart

global function SonarDart_GetFullScanDuration

#if CLIENT
global function OnClientAnimEvent_SoanrDart
global function ServerToClient_SonarDartDestroyed
#endif

#if SERVER
global function SonarDart_IsTrackedByTeam
#endif

const asset SONAR_TRAP_MODEL		 			= $"mdl/props/sparrow_ult_arrow/w_sparrow_tact.rmdl"
global const string SONAR_DART_SCRIPT_NAME = "sonar_dart"

const asset PREVIEW_SCAN_RADIUS_FX = $"P_sprw_tac_goober_edge"
const asset BLINKING_LIGHT = $"p_sprw_tact_dart_glow"
const asset BLINKING_LIGHT_FRIENDLY = $"p_sprw_tact_dart_glow_friendly"
const string SPARROW_TRAP_LOOP_SFX = "Sparrow_Tac_Scanner_Armed_Idle_Loop"

const asset SONAR_TRAP_DESTROY_FX = $"P_sprw_tac_goober_exp"
const asset BLACK_MARKET_WARP_BEAM_FX = $"P_sprw_tact_target_MDL"
const asset SCAN_MARKER_AR_FX = $"P_sprw_tact_target_MDL_spawn"
const asset SCAN_EFFECT = $"P_sprw_tac_nme_trail"
const asset AREA_SCAN_FX = $"P_sprw_tac_trap_activate"
const asset IMPACT_TELL_EFFECT = $"P_sprw_tac_trap_init"
const asset IMPACT_ARCO_TAC = $"P_sprw_tac_impact"
const asset ARROW_ZONE_PREVIEW_FX = $"P_sprw_tactical_AR_Radius"
const asset ARROW_ZONE_PREARM_FX = $"P_sprw_tactical_arming_UI"
const asset ARROW_ZONE_BEACON_FX = $"P_sprw_tactical_scan"
const asset SCANNED_TARGET_RETICLE = $"P_sprw_tact_target_reticle"
const asset ON_SCREEN_SCAN_INDICATOR_FX = $"P_sprw_tact_indicator_cp10"
const asset ON_SCREEN_BRACKET_FX = $"P_sprw_tact_indicator_MDL_FP"
const asset HUNT_MODE_ACTIVATION_SCREEN_FX =  $"P_foa_disrupt_screen_CP"

const string SONAR_DART_FIRE_SCREEN_SHAKE = "sparrow_tact_screen_shake"
const asset HIT_BY_TRAP_TRIGGERED_ICON = $"rui/hud/tactical_icons/tactical_sparrow"
const asset TRAP_DESTROYED_ICON = $"rui/hud/tactical_icons/tactical_sparrow_destroyed"
const float SHAKE_AMPLITUDE = 2.0
const float SHAKE_FREQUENCY = 10.0
const float SHAKE_DURATION = 0.2
const vector SHAKE_DIRECTION = < 0.0, 0.0, 1.0 >

const vector SCAN_START_EFFECT_COLOR = <155, 0, 0>
const float SCAN_START_EFFECT_SIZE = 768.0

const vector SPARROW_FRIENDLY_COLOR = < 48, 180, 255 >
const vector SPARROW_ENEMY_COLOR = < 155, 0, 0 >

global const string SONAR_DART_ACTIVE_TRAP_NETVAR = "sonar_dart_active_trap"

#if SERVER
const float SONAR_DART_SCAN_TICK = 0.1
const float SONAR_DART_GROUND_TRACE = 96.0
#endif

struct
{
	float sonarDartRadius = 650
	int sonarDartMaxInWorld = 5
	float sonarDartArmTime = 2.0
	int sonarDartHealth = 10
	float sonarDartTimeToFullScan = 3.0
	float sonarDartFullScanDuration = 12.0
	float beaconScanRadius = 300
	int sonarDartMaxInWorldModifier = 1
} tuning

struct
{
	#if SERVER
		table< entity, array<entity> > ownerDarts
		table< entity, table< int, float > > trackedUntil
		table< int, array<entity> > beaconsUsedByTeam
		table< entity, bool > destroyedByEnemy
	#endif
} file

void function MpWeaponSonarDart_Init()
{
	PrecacheParticleSystem( PREVIEW_SCAN_RADIUS_FX )
	PrecacheParticleSystem( SONAR_TRAP_DESTROY_FX )
	PrecacheParticleSystem( AREA_SCAN_FX )
	PrecacheParticleSystem( BLACK_MARKET_WARP_BEAM_FX )
	PrecacheParticleSystem( HUNT_MODE_ACTIVATION_SCREEN_FX )
	PrecacheParticleSystem( SCAN_EFFECT )
	PrecacheParticleSystem( BLINKING_LIGHT )
	PrecacheParticleSystem( BLINKING_LIGHT_FRIENDLY )
	PrecacheParticleSystem( IMPACT_TELL_EFFECT )
	PrecacheParticleSystem( ARROW_ZONE_PREVIEW_FX )
	PrecacheParticleSystem( ARROW_ZONE_PREARM_FX )
	PrecacheParticleSystem( ON_SCREEN_SCAN_INDICATOR_FX )
	PrecacheParticleSystem( SCANNED_TARGET_RETICLE )
	PrecacheParticleSystem( SCAN_MARKER_AR_FX )
	PrecacheParticleSystem( ON_SCREEN_BRACKET_FX )
	PrecacheParticleSystem( ARROW_ZONE_BEACON_FX )

	PrecacheScriptString( SONAR_DART_SCRIPT_NAME )

	PrecacheModel( SONAR_TRAP_MODEL )

	tuning.sonarDartRadius           = GetCurrentPlaylistVarFloat( "sparrow_sonar_dart_sonarDartRadius", tuning.sonarDartRadius )
	tuning.sonarDartMaxInWorld       = GetCurrentPlaylistVarInt( "sparrow_sonar_dart_sonarDartMaxInWorld", tuning.sonarDartMaxInWorld )
	tuning.sonarDartArmTime          = GetCurrentPlaylistVarFloat( "sparrow_sonar_dart_sonarDartArmTime", tuning.sonarDartArmTime )
	tuning.sonarDartHealth           = GetCurrentPlaylistVarInt( "sparrow_sonar_dart_sonarDartHealth", tuning.sonarDartHealth )
	tuning.sonarDartTimeToFullScan   = GetCurrentPlaylistVarFloat( "sparrow_sonar_dart_sonarDartTimeToFullScan", tuning.sonarDartTimeToFullScan )
	tuning.sonarDartFullScanDuration = GetCurrentPlaylistVarFloat( "sparrow_sonar_dart_sonarDartFullScanDuration", tuning.sonarDartFullScanDuration )
	tuning.beaconScanRadius          = GetCurrentPlaylistVarFloat( "sparrow_sonar_dart_beaconScanRadius", tuning.beaconScanRadius )

	RegisterNetworkedVariable( SONAR_DART_ACTIVE_TRAP_NETVAR, SNDC_PLAYER_EXCLUSIVE, SNVT_ENTITY )
	Remote_RegisterClientFunction( "ServerToClient_SonarDartDestroyed" )

	RegisterSignal( "DestroySonarDart" )
	RegisterSignal( "StopScan" )
	RegisterSignal( "StopTracking" )
	RegisterSignal( "StopTrackingClient" )
	RegisterSignal( "SonarDart_EndPreview" )
	RegisterSignal( "SonarDartPreScan" )
	RegisterSignal( "EndEffects" )

	#if CLIENT
		RegisterMinimapPackage( "prop_script", eMinimapObject_prop_script.SONAR_DART, MINIMAP_OBJECT_RUI, MinimapPackage_SonarDart, FULLMAP_OBJECT_RUI, MinimapPackage_SonarDart )
		AddScriptNameCreateCallback( SONAR_DART_SCRIPT_NAME, AddBowUltThreatIndicator )
	#endif
}

var function OnWeaponTossCancel_weapon_SonarDart( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}

var function OnWeaponTossReleaseAnimEvent_weapon_SonarDart( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return SonarDart_FireProjectile( weapon, attackParams )
}

int function SonarDart_FireProjectile( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )
	bool projectilePredicted      = PROJECTILE_PREDICTED
	bool projectileLagCompensated = PROJECTILE_LAG_COMPENSATED

	entity grenade     = Grenade_Launch( weapon, attackParams.pos, attackParams.dir, projectilePredicted, projectileLagCompensated, ZERO_VECTOR )
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.Signal( "ThrowGrenade" )

	PlayerUsedOffhand( weaponOwner, weapon, true, grenade )

	#if SERVER
		TrackingVision_CreatePOI( eTrackingVisionNetworkedPOITypes.PLAYER_ABILITY_SPRROW_TRACKER_DART, weaponOwner, weaponOwner.GetOrigin(), weaponOwner.GetTeam(), weaponOwner )
	#endif

	if ( IsValid( grenade ) )
	{
		grenade.proj.savedDir = weaponOwner.GetViewForward()
		grenade.proj.savedOrigin = grenade.GetOrigin()
	}

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnWeaponActivate_SonarDart( entity weapon )
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	if ( !IsValid( ownerPlayer ) || !ownerPlayer.IsPlayer() )
		return

	bool serverOrPredicted = IsServer() || (InPrediction() && IsFirstTimePredicted())
	if( serverOrPredicted )
	{
		entity ultimateWeapon = ownerPlayer.GetOffhandWeapon( OFFHAND_ULTIMATE )
		if ( IsValid( ultimateWeapon ) )
			ultimateWeapon.Holster()
	}

	#if CLIENT
		thread ShowRadiusPreview( weapon )
	#endif
}

void function OnWeaponDeactivate_SonarDart( entity weapon )
{
	#if CLIENT
		weapon.Signal( "SonarDart_EndPreview" )
	#endif
}

#if SERVER
void function OnProjectileCollision_weapon_SonarDart( entity projectile, vector pos, vector normal, entity hitEnt, int hitBox, bool isCritical )
#else
void function OnProjectileCollision_weapon_SonarDart( entity projectile, vector pos, vector normal, entity hitEnt, int hitBox, bool isCritical, bool isPassthrough )
#endif
{
	bool isBounceTarget = ( hitEnt.IsPlayer() || hitEnt.IsNPC() )
	entity hitEntParent = hitEnt.GetParent()
	if ( IsValid( hitEntParent ) )
		isBounceTarget = isBounceTarget || hitEntParent.IsPlayer() || hitEntParent.IsNPC()

	projectile.SetVelocity( <0, 0, 0> )
	projectile.StopPhysics()

	#if SERVER
		thread SonarDart_Plant( projectile, pos, normal, isBounceTarget ? null : hitEnt )
	#endif
}

float function SonarDart_UpgradedRadiusScaler()
{
	return GetCurrentPlaylistVarFloat( "passive_upgrade_arco_tact_radius_scaler", 1.3 )
}

float function SonarDart_GetRadius( entity player )
{
	float result = tuning.sonarDartRadius

	if( IsValid( player ) && PlayerHasPassive( player, ePassives.PAS_TAC_UPGRADE_ONE ) )
	{
		result *= SonarDart_UpgradedRadiusScaler()
	}

	return result
}

float function SonarDart_GetFullScanDuration()
{
	return tuning.sonarDartFullScanDuration
}

#if CLIENT
void function OnClientAnimEvent_SoanrDart( entity weapon, string name )
{
	if ( !IsValid( weapon ) )
		return

	if ( name == SONAR_DART_FIRE_SCREEN_SHAKE )
		ClientScreenShake( SHAKE_AMPLITUDE, SHAKE_FREQUENCY, SHAKE_DURATION, SHAKE_DIRECTION )
}
#endif

entity function SonarDart_GetNearestBeacon( vector pos, float range )
{
	entity best = null
	float bestDistSqr = range * range
	foreach ( entity beacon in GetEntArrayByScriptName( ENEMY_SURVEY_BEACON_SCRIPTNAME ) )
	{
		if ( !IsValid( beacon ) )
			continue

		float distSqr = DistanceSqr( beacon.GetOrigin(), pos )
		if ( distSqr < bestDistSqr )
		{
			best = beacon
			bestDistSqr = distSqr
		}
	}
	return best
}

#if SERVER
int function SonarDart_GetMaxInWorld( entity owner )
{
	int maxDarts = tuning.sonarDartMaxInWorld
	if ( PlayerHasPassive( owner, ePassives.PAS_TAC_UPGRADE_THREE ) )
		maxDarts += tuning.sonarDartMaxInWorldModifier
	return maxDarts
}

void function SonarDart_Plant( entity projectile, vector pos, vector normal, entity hitEnt )
{
	if ( !IsValid( projectile ) )
		return

	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) || !owner.IsPlayer() )
	{
		projectile.Destroy()
		return
	}

	// A dart that hits a player or NPC drops to the ground beneath the hit.
	if ( !IsValid( hitEnt ) )
	{
		TraceResults groundTrace = TraceLine( pos, pos - <0, 0, SONAR_DART_GROUND_TRACE>, [ projectile ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_BLOCK_WEAPONS_AND_PHYSICS )
		if ( groundTrace.fraction < 1.0 )
		{
			pos = groundTrace.endPos
			normal = groundTrace.surfaceNormal
			hitEnt = groundTrace.hitEnt
		}
		else
		{
			normal = <0, 0, 1>
		}
	}

	vector forward = projectile.proj.savedDir
	vector angles = AnglesOnSurface( normal, forward )
	int team = owner.GetTeam()
	projectile.Destroy()

	entity dart = CreatePropScript( SONAR_TRAP_MODEL, pos, angles, SOLID_VPHYSICS )
	dart.SetScriptName( SONAR_DART_SCRIPT_NAME )
	dart.SetOwner( owner )
	SetTeam( dart, team )
	dart.RemoveFromAllRealms()
	dart.AddToOtherEntitysRealms( owner )
	dart.SetMaxHealth( tuning.sonarDartHealth )
	dart.SetHealth( tuning.sonarDartHealth )
	dart.SetDamageNotifications( true )
	dart.SetDeathNotifications( false )
	dart.SetArmorType( ARMOR_TYPE_HEAVY )
	dart.SetBlocksRadiusDamage( false )
	dart.SetTakeDamageType( DAMAGE_YES )
	dart.e.ignoreJumpPad = true
	SetObjectCanBeMeleed( dart, true )
	dart.Minimap_SetCustomState( eMinimapObject_prop_script.SONAR_DART )
	dart.Minimap_AlwaysShow( team, null )
	dart.Minimap_SetAlignUpright( true )
	dart.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	AddEntityCallback_OnDamaged( dart, SonarDart_OnDamaged )
	AddSonarDetectionForPropScript( dart )
	AddEMPDestroyDeviceNoDissolve( dart )
	FiringRange_AddToRemoveOnCharacterChange( dart, owner )
	thread TrapDestroyOnRoundEnd( owner, dart )

	if ( IsValid( hitEnt ) && EntityShouldStick( dart, hitEnt ) && !hitEnt.IsWorld() )
		dart.SetParent( hitEnt, "", true, 0.0 )

	SonarDart_TrackOwnerDart( owner, dart )
	SonarDart_TryActivateBeacon( owner, dart )

	EmitSoundOnEntityToTeam( dart, "Sparrow_Tac_Scanner_Placed_Friendly", team )
	EmitSoundOnEntityToEnemies( dart, "Sparrow_Tac_Scanner_Placed_Enemy", team )
	thread SonarDart_Think( dart, owner, team )
}

// A dart landing by a survey beacon uses it for the owner, as if surveyed by hand.
void function SonarDart_TryActivateBeacon( entity owner, entity dart )
{
	if ( !Perks_DoesPlayerHavePerk( owner, ePerkIndex.BEACON_ENEMY_SCAN ) )
		return

	entity beacon = SonarDart_GetNearestBeacon( dart.GetOrigin(), tuning.beaconScanRadius )
	if ( !IsValid( beacon ) )
		return

	int team = owner.GetTeam()
	if ( !( team in file.beaconsUsedByTeam ) )
		file.beaconsUsedByTeam[ team ] <- []
	if ( file.beaconsUsedByTeam[ team ].contains( beacon ) )
		return
	file.beaconsUsedByTeam[ team ].append( beacon )

	BeaconScanEnemy_RevealPlayerOnMinimapAndStartSonar( owner, beacon )
	Perks_HideMinimapVisibilityForTeam( beacon, ePerkIndex.BEACON_ENEMY_SCAN, team )
	foreach ( entity teammate in GetPlayerArrayOfTeam( team ) )
		Remote_CallFunction_NonReplay( teammate, "ServerToClient_BeaconScanEnemy_Notifications", owner, beacon )
}

void function SonarDart_TrackOwnerDart( entity owner, entity dart )
{
	if ( !( owner in file.ownerDarts ) )
		file.ownerDarts[ owner ] <- []

	array<entity> live
	foreach ( entity d in file.ownerDarts[ owner ] )
	{
		if ( IsValid( d ) )
			live.append( d )
	}
	live.insert( 0, dart )

	int maxDarts = SonarDart_GetMaxInWorld( owner )
	while ( live.len() > maxDarts )
	{
		entity oldest = live.pop()
		if ( IsValid( oldest ) )
			oldest.Signal( "DestroySonarDart" )
	}
	file.ownerDarts[ owner ] = live
}

void function SonarDart_OnDamaged( entity dart, var damageInfo )
{
	if ( !IsValid( dart ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsPlayer() && IsFriendlyTeam( attacker.GetTeam(), dart.GetTeam() ) && attacker != dart.GetOwner() )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	float damage = DamageInfo_GetDamage( damageInfo )
	if ( damage <= 0 )
		return

	if ( IsValid( attacker ) && attacker.IsPlayer() )
		attacker.NotifyDidDamage( dart, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamagePosition( damageInfo ), DamageInfo_GetCustomDamageType( damageInfo ) | DF_NO_HITBEEP, damage, DamageInfo_GetDamageFlags( damageInfo ), DamageInfo_GetHitGroup( damageInfo ), DamageInfo_GetWeapon( damageInfo ), DamageInfo_GetDistFromAttackOrigin( damageInfo ) )

	if ( dart.GetHealth() - damage <= 0 )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		if ( IsValid( attacker ) && IsEnemyTeam( dart.GetTeam(), attacker.GetTeam() ) )
			file.destroyedByEnemy[ dart ] <- true
		dart.Signal( "DestroySonarDart" )
	}
}

array<entity> function SonarDart_ScanIgnoreEnts( entity dart )
{
	array<entity> ignore = GetPlayerArray_AliveConnected()
	ignore.append( dart )
	ignore.extend( GetPlayerDecoyArray() )
	return ignore
}

bool function SonarDart_HasLOS( entity dart, entity target, float radius )
{
	int attachID = dart.LookupAttachment( "BOX_POINT" )
	vector start = attachID > 0 ? dart.GetAttachmentOrigin( attachID ) : dart.GetOrigin()
	if ( DistanceSqr( start, target.GetOrigin() ) > radius * radius )
		return false

	array<entity> ignore = SonarDart_ScanIgnoreEnts( dart )
	int mask = TRACE_MASK_BLOCKLOS | CONTENTS_WINDOW
	foreach ( vector endPos in [ target.EyePosition(), target.GetWorldSpaceCenter() ] )
	{
		TraceResults tr = TraceLine( start, endPos, ignore, mask, TRACE_COLLISION_GROUP_NONE )
		if ( tr.fraction >= 0.99 )
			return true
	}
	return false
}

void function SonarDart_Think( entity dart, entity owner, int team )
{
	dart.EndSignal( "OnDestroy", "DestroySonarDart" )
	EndThreadOn_PlayerChangedClass( owner )

	table< entity, float > scanTime
	table< entity, int > scanHandles
	array<entity> fx
	bool concealed = false

	OnThreadEnd(
		function() : ( dart, team, scanTime, scanHandles, fx )
		{
			foreach ( entity victim, int handle in scanHandles )
			{
				if ( IsValid( victim ) )
				{
					StatusEffect_Stop( victim, handle )
					if ( victim.IsPlayer() && victim.GetPlayerNetEnt( SONAR_DART_ACTIVE_TRAP_NETVAR ) == dart )
						victim.SetPlayerNetEnt( SONAR_DART_ACTIVE_TRAP_NETVAR, null )
				}
			}

			foreach ( entity e in fx )
			{
				if ( IsValid( e ) )
					e.Destroy()
			}

			if ( dart in file.destroyedByEnemy )
			{
				delete file.destroyedByEnemy[ dart ]
				foreach ( entity teammate in GetPlayerArrayOfTeam( team ) )
					Remote_CallFunction_Replay( teammate, "ServerToClient_SonarDartDestroyed" )
			}

			if ( IsValid( dart ) )
			{
				vector pos = dart.GetOrigin()
				StopSoundOnEntity( dart, SPARROW_TRAP_LOOP_SFX )
				StartParticleEffectInWorldForRealms( GetParticleSystemIndex( SONAR_TRAP_DESTROY_FX ), pos, <0, 0, 0>, dart )
				EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Sparrow_Tac_Scanner_Destroyed", dart )
				RemoveSonarDetectionForPropScript( dart )
				dart.Destroy()
			}
		}
	)

	entity tell = StartParticleEffectOnEntity_ReturnEntity( dart, GetParticleSystemIndex( IMPACT_TELL_EFFECT ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
	fx.append( tell )

	wait tuning.sonarDartArmTime

	if ( IsValid( tell ) )
		tell.Destroy()

	int glowAttach = dart.LookupAttachment( "BOX_POINT" )
	int glowMode = glowAttach > 0 ? FX_PATTACH_POINT_FOLLOW : FX_PATTACH_ABSORIGIN_FOLLOW
	entity glowEnemy = StartParticleEffectOnEntity_ReturnEntity( dart, GetParticleSystemIndex( BLINKING_LIGHT ), glowMode, glowAttach )
	SetTeam( glowEnemy, team )
	glowEnemy.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY
	fx.append( glowEnemy )

	entity glowFriendly = StartParticleEffectOnEntity_ReturnEntity( dart, GetParticleSystemIndex( BLINKING_LIGHT_FRIENDLY ), glowMode, glowAttach )
	SetTeam( glowFriendly, team )
	glowFriendly.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_OWNER
	fx.append( glowFriendly )

	EmitSoundOnEntityToTeam( dart, "Sparrow_Tac_Scanner_Armed_Friendly", team )
	EmitSoundOnEntityToEnemies( dart, "Sparrow_Tac_Scanner_Armed_Enemy", team )
	EmitSoundOnEntity( dart, SPARROW_TRAP_LOOP_SFX )

	while ( true )
	{
		float radius = SonarDart_GetRadius( owner )
		array<entity> inScan

		foreach ( entity player in GetPlayerArray_Alive() )
		{
			if ( !IsEnemyTeam( team, player.GetTeam() ) )
				continue
			if ( !player.DoesShareRealms( dart ) )
				continue
			if ( !SonarDart_HasLOS( dart, player, radius ) )
				continue

			inScan.append( player )
		}

		foreach ( entity player in inScan )
		{
			// Already tracked by this squad: no new scan until the track ends.
			if ( SonarDart_IsTrackedByTeam( player, team ) )
				continue

			if ( !( player in scanTime ) )
			{
				scanTime[ player ] <- 0.0
				scanHandles[ player ] <- StatusEffect_AddTimed( player, eStatusEffect.hit_by_sonar_dart, 1.0, tuning.sonarDartTimeToFullScan, 0.0 )
				player.SetPlayerNetEnt( SONAR_DART_ACTIVE_TRAP_NETVAR, dart )
				EmitSoundOnEntityOnlyToPlayer( player, player, "Sparrow_Tac_Scanner_DetectedYou_1P" )
			}

			scanTime[ player ] += SONAR_DART_SCAN_TICK
			if ( scanTime[ player ] >= tuning.sonarDartTimeToFullScan )
			{
				StatusEffect_Stop( player, scanHandles[ player ] )
				delete scanTime[ player ]
				delete scanHandles[ player ]
				thread SonarDart_TrackTarget( dart, owner, team, player )
				if ( !concealed )
				{
					concealed = true
					SonarDart_Conceal( dart, fx )
				}
			}
		}

		array<entity> left
		foreach ( entity player, float t in scanTime )
		{
			if ( !inScan.contains( player ) )
				left.append( player )
		}
		foreach ( entity player in left )
		{
			if ( IsValid( player ) )
			{
				StatusEffect_Stop( player, scanHandles[ player ] )
				if ( player.GetPlayerNetEnt( SONAR_DART_ACTIVE_TRAP_NETVAR ) == dart )
					player.SetPlayerNetEnt( SONAR_DART_ACTIVE_TRAP_NETVAR, null )
			}
			delete scanTime[ player ]
			delete scanHandles[ player ]
		}

		wait SONAR_DART_SCAN_TICK
	}
}

// A dart that has tracked someone goes invisible to everyone but keeps its
// collision, so it can still be shot by anyone who knows where it is.
void function SonarDart_Conceal( entity dart, array<entity> fx )
{
	dart.Hide()
	foreach ( entity e in fx )
	{
		if ( IsValid( e ) )
			e.Destroy()
	}
	fx.clear()
}

bool function SonarDart_IsTrackedByTeam( entity player, int team )
{
	if ( !( player in file.trackedUntil ) || !( team in file.trackedUntil[ player ] ) )
		return false
	return file.trackedUntil[ player ][ team ] > Time()
}

void function SonarDart_TrackTarget( entity dart, entity owner, int team, entity victim )
{
	if ( !( victim in file.trackedUntil ) )
	{
		table< int, float > byTeam
		file.trackedUntil[ victim ] <- byTeam
	}
	file.trackedUntil[ victim ][ team ] <- Time() + tuning.sonarDartFullScanDuration

	victim.EndSignal( "OnDeath", "OnDestroy" )

	vector dartPos = dart.GetOrigin()
	SonarStart( victim, victim.GetOrigin(), team, owner )
	int hitListHandle = StatusEffect_AddTimed( victim, eStatusEffect.on_hit_list, 1.0, tuning.sonarDartFullScanDuration, 0.0 )

	entity wp = CreatePlayerWaypoint( eWaypoint.SPARROW_TRACKED_ENEMY )
	wp.SetWaypointEntity( 0, victim )
	wp.SetWaypointFloat( 0, Time() )
	wp.SetOwner( owner )
	SetTeam( wp, team )
	CopyRealmsFromTo( victim, wp )
	AllianceProximity_SetOnlyTransmitWaypointToFriendlyTeams( wp, team )
	StartParticleEffectInWorldForRealms( GetParticleSystemIndex( AREA_SCAN_FX ), dartPos, <0, 0, 0>, dart )
	EmitSoundOnEntityToTeam( dart, "Sparrow_Tac_Scanner_Scan_Friendly", team )
	EmitSoundOnEntityOnlyToPlayer( victim, victim, "Sparrow_Tac_Scanner_Scan_Enemy" )

	OnThreadEnd(
		function() : ( victim, team, owner, wp, hitListHandle )
		{
			if ( IsValid( wp ) )
				wp.Destroy()
			if ( IsValid( victim ) )
				StatusEffect_Stop( victim, hitListHandle )
			if ( victim in file.trackedUntil && team in file.trackedUntil[ victim ] )
				delete file.trackedUntil[ victim ][ team ]
			if ( IsValid( victim ) )
				SonarEnd( victim, team, owner )
		}
	)

	wait tuning.sonarDartFullScanDuration
}
#endif

#if CLIENT
void function MinimapPackage_SonarDart( entity ent, var rui )
{
	RuiSetImage( rui, "defaultIcon", $"rui/hud/tactical_icons/tactical_sparrow" )
	RuiSetImage( rui, "clampedDefaultIcon", $"rui/hud/tactical_icons/tactical_sparrow" )
	RuiSetBool( rui, "useTeamColor", false )
	RuiSetFloat( rui, "iconBlend", 0.0 )
}

void function ServerToClient_SonarDartDestroyed()
{
	entity player = GetLocalViewPlayer()
	if ( !IsValid( player ) )
		return

	AnnouncementMessageRight( player, "#WPN_ARTEMIS_TRACKER_DESTROYED", "", <255, 255, 255>, TRAP_DESTROYED_ICON, 2.0 )
}

void function ShowRadiusPreview( entity weapon )
{
	EndSignal( weapon, "SonarDart_EndPreview" )
	EndSignal( weapon, "OnDestroy" )

	entity localClientPlayer = GetLocalClientPlayer()

	entity player = weapon.GetOwner()

	if( player != localClientPlayer )
		return

	wait 0.2

	int radiusFxHandle = -1
	int beaconFxHandle = -1
	if ( IsValid( weapon ) )
	{
		radiusFxHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( ARROW_ZONE_PREVIEW_FX ), <0, 0, 0>, <0, 0, 0> )
		beaconFxHandle = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( ARROW_ZONE_BEACON_FX ), <0, 0, 0>, <0, 0, 0> )

		EffectSetControlPointVector( radiusFxHandle, 3, < SonarDart_GetRadius(player), 0,0> )
		EffectSetControlPointVector( beaconFxHandle, 0, weapon.GetOrigin() )
		EffectSetControlPointVector( beaconFxHandle, 1, weapon.GetOrigin() )
	}

	OnThreadEnd(
		function() : ( radiusFxHandle, beaconFxHandle )
		{
			if ( radiusFxHandle != -1 )
				EffectStop( radiusFxHandle, false, true )

			if ( beaconFxHandle != -1 )
				EffectStop( beaconFxHandle, false, true )
		}
	)

	while( EffectDoesExist( radiusFxHandle ) )
	{
		vector dropPosition = weapon.GetMostRecentGrenadeImpactPos()
		EffectSetControlPointVector( radiusFxHandle, 0, dropPosition )
		EffectSetControlPointVector( beaconFxHandle, 1, dropPosition )

		entity nearestBeacon = SonarDart_GetNearestBeacon( dropPosition, tuning.beaconScanRadius - 5 )
		if ( IsValid( nearestBeacon ) && Perks_DoesPlayerHavePerk( player, ePerkIndex.BEACON_ENEMY_SCAN ) )
			EffectSetControlPointVector( beaconFxHandle, 0, nearestBeacon.GetOrigin() + <0, 0, 55> )
		else
			EffectSetControlPointVector( beaconFxHandle, 0, dropPosition )

		WaitFrame()
	}
}

void function AddBowUltThreatIndicator( entity prop )
{
	entity player = GetLocalViewPlayer()
	if( !IsValid( player ) || prop.GetTeam() == player.GetTeam() )
		return

	thread TetherDirectionalEffect_Thread( player, prop )
}

void function TetherDirectionalEffect_Thread( entity player, entity prop )
{
	prop.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath", "OnDestroy" )

	PassByReferenceInt tetherFx
	tetherFx.value = -1
	int tetherFxId = GetParticleSystemIndex( ON_SCREEN_SCAN_INDICATOR_FX )
	float radiusSqr = SonarDart_GetRadius( player ) * SonarDart_GetRadius( player )

	PassByReferenceInt onScreenBracketsFx
	onScreenBracketsFx.value = -1
	int onScreenBracketFxId = GetParticleSystemIndex( ON_SCREEN_BRACKET_FX )

	OnThreadEnd(
		function() : ( tetherFx, onScreenBracketsFx )
		{
			if( tetherFx.value > -1 )
			{
				EffectStop( tetherFx.value, true, true )
			}

			if( onScreenBracketsFx.value > -1 )
			{
				EffectStop( onScreenBracketsFx.value, false, true )
			}
		}
	)

	while ( true )
	{
		entity activeTrap 	= player.GetPlayerNetEnt( SONAR_DART_ACTIVE_TRAP_NETVAR )

		bool shouldShowIndicator = DistanceSqr( player.GetOrigin(), prop.GetOrigin() ) < radiusSqr && SparrowAbility_HasLOSToPlayer( prop, player, "BOX_POINT", tuning.sonarDartRadius ) && StatusEffect_HasSeverity( player, eStatusEffect.hit_by_sonar_dart ) && activeTrap == prop
		if( shouldShowIndicator )
		{
			if( tetherFx.value == -1 )
			{
				tetherFx.value = StartParticleEffectOnEntity( player, tetherFxId, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
			}

			if( onScreenBracketsFx.value == -1 )
			{
				onScreenBracketsFx.value = StartParticleEffectOnEntity( player, onScreenBracketFxId, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )
				EffectSetControlPointVector( onScreenBracketsFx.value, 1, SPARROW_ENEMY_COLOR )
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
			EffectSetControlPointVector( tetherFx.value, 1, <255,0,0> )
		}
		else
		{
			if( tetherFx.value != -1 )
			{
				EffectStop( tetherFx.value, true, true )
				tetherFx.value = -1
			}
			if( onScreenBracketsFx.value != -1 )
			{
				EffectStop( onScreenBracketsFx.value, false, true )
				onScreenBracketsFx.value = -1
			}
		}
		WaitFrame()
	}
}
#endif
