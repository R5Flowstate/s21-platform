// Instagib hitscan rail: FireWeaponBullet + tesla beam. Railjump is the tactical.

global function OnWeaponPrimaryAttack_Clickweapon
global function OnWeaponActivate_Clickweapon
global function OnWeaponDeactivate_Clickweapon
global function Clickweapon_Init
global function LGUN_DoRailJump

#if CLIENT
	global function ServerCallback_CreatesLaserFXFromServer
#endif

const asset INSTAGIB_BEAM_FX = $"P_tesla_trap_link_CP"
const asset INSTAGIB_IMPACT_FX = $"P_tesla_trap_exp"
const asset INSTAGIB_RAILJUMP_FX = $"P_tesla_trap_exp"
const asset TEAM_JUMPJET_DBL = $"P_team_jump_jet_ON_trails"
const asset ENEMY_JUMPJET_DBL = $"P_enemy_jump_jet_ON_trails"

// Just under 1/2.8s so the engine fire_rate is the cap.
const float LG_SINGLE_FIRE_DEBOUNCE = 0.35
const float LG_DRAG_TIME = 0.45
const float LG_MAX_DISTANCE_RAILJUMP_TRACE = 400.0

struct
{
	#if CLIENT
		table<entity, int> beamsFxs
		table<entity, entity> handmover
		table<entity, entity> beammover
	#endif
} file

void function Clickweapon_Init()
{
	if ( !FS_IsInstagib() )
		return

	RegisterSignal( "EndLaser" )
	RegisterSignal( "EndNoAutoThread" )
	RegisterSignal( "PlayerStartShotingLightningGun" )
	RegisterSignal( "RestartAirborne" )

	#if SERVER || CLIENT
		PrecacheWeapon( INSTAGIB_WEAPON_CLASS )
		RegisterWeaponDamageSource( INSTAGIB_WEAPON_CLASS )
		RegisterAdditionalMainWeapon( INSTAGIB_WEAPON_CLASS )
	#endif

	PrecacheParticleSystem( INSTAGIB_BEAM_FX )
	PrecacheParticleSystem( INSTAGIB_IMPACT_FX )
	PrecacheParticleSystem( INSTAGIB_RAILJUMP_FX )
	PrecacheParticleSystem( TEAM_JUMPJET_DBL )
	PrecacheParticleSystem( ENEMY_JUMPJET_DBL )

	#if SERVER || CLIENT
		Remote_RegisterClientFunction( "ServerCallback_CreatesLaserFXFromServer", "entity", "vector", -64000.0, 64000.0, 32, "vector", -1.0, 1.0, 32 )
	#endif

	#if CLIENT
		AddCreateCallback( "player", FS_IG_OnPlayerCreated )
		AddDestroyCallback( "player", FS_IG_OnPlayerDestroyed )
	#endif

	printt( "[FS-IG] Clickweapon_Init" )
}

bool function FS_IG_IsInstagibWeapon( entity weapon )
{
	if ( !IsValid( weapon ) )
		return false
	return weapon.GetWeaponClassName() == INSTAGIB_WEAPON_CLASS
}

bool function LGUN_DoRailJump( entity player, entity weapon )
{
	if ( !IsValid( player ) || !IsAlive( player ) || player.ContextAction_IsActive() )
		return false

	if ( GetGameState() != eGameState.Playing )
		return false

	if ( !FS_IsInstagib() )
		return false

	vector viewVec = player.GetViewVector()
	viewVec.Normalize()
	if ( viewVec.z > 0 )
		return false

	vector eyePos = player.EyePosition()
	TraceResults trace = TraceLineHighDetail( eyePos, eyePos + ( viewVec * 50000 ), [player], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	float traceDistance = Distance( eyePos, trace.endPos )

	if ( traceDistance > LG_MAX_DISTANCE_RAILJUMP_TRACE )
		return false

	float distanceValue = min( traceDistance, LG_MAX_DISTANCE_RAILJUMP_TRACE ) / LG_MAX_DISTANCE_RAILJUMP_TRACE
	if ( distanceValue < 0.1 )
		return false

	player.p.lastTimeUsedRailjump = Time()

	vector impulse = viewVec * ( -850.0 * ( 1.0 - distanceValue ) )
	player.KnockBack( impulse, 0.1 )

	#if SERVER
		StartParticleEffectInWorldForRealms( GetParticleSystemIndex( INSTAGIB_RAILJUMP_FX ), trace.endPos, <0, 0, 0>, player )
	#else
		StartParticleEffectInWorld( GetParticleSystemIndex( INSTAGIB_RAILJUMP_FX ), trace.endPos, <0, 0, 0> )
	#endif

	#if CLIENT
		if ( player == GetLocalViewPlayer() )
			OnLocalPlayerShoot( player, eyePos, viewVec, true )
	#endif

	#if SERVER
		player.p.railjumptimes++
		thread LGUN_Airborne( player )
	#endif

	return true
}

#if SERVER

void function LGUN_Airborne( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	Signal( player, "RestartAirborne" )
	EndSignal( player, "RestartAirborne" )
	EndSignal( player, "OnDeath" )
	EndSignal( player, "OnDestroy" )

	player.SetOneHandedWeaponUsageOn()
	EmitSoundOnEntityExceptToPlayer( player, player, "boost_freefall_body_3p" )
	EmitSoundOnEntityExceptToPlayer( player, player, "JumpPad_Ascent_Windrush" )
	EmitSoundOnEntityOnlyToPlayer( player, player, "boost_freefall_body_1p" )

	array<entity> jumpJetFXs
	array<string> attachments = [ "vent_left", "vent_right" ]
	int team = player.GetTeam()
	foreach ( attachment in attachments )
	{
		if ( player.LookupAttachment( "vent_left" ) > 0 && player.LookupAttachment( "vent_right" ) > 0 )
		{
			int friendlyID = GetParticleSystemIndex( TEAM_JUMPJET_DBL )
			entity friendlyFX = StartParticleEffectOnEntity_ReturnEntity( player, friendlyID, FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( attachment ) )
			friendlyFX.SetOwner( player )
			SetTeam( friendlyFX, team )
			friendlyFX.RemoveFromAllRealms()
			friendlyFX.AddToOtherEntitysRealms( player )
			friendlyFX.kv.VisibilityFlags = ( ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY )
			jumpJetFXs.append( friendlyFX )

			int enemyID = GetParticleSystemIndex( ENEMY_JUMPJET_DBL )
			entity enemyFX = StartParticleEffectOnEntity_ReturnEntity( player, enemyID, FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( attachment ) )
			enemyFX.SetOwner( player )
			SetTeam( enemyFX, team )
			enemyFX.kv.VisibilityFlags = ( ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY )
			enemyFX.RemoveFromAllRealms()
			enemyFX.AddToOtherEntitysRealms( player )
			jumpJetFXs.append( enemyFX )
		}
	}

	OnThreadEnd(
		function() : ( jumpJetFXs, player )
		{
			if ( IsValid( player ) )
			{
				StopSoundOnEntity( player, "JumpPad_Ascent_Windrush" )
				StopSoundOnEntity( player, "boost_freefall_body_3p" )
				StopSoundOnEntity( player, "boost_freefall_body_1p" )
				player.SetOneHandedWeaponUsageOff()
			}
			foreach ( fx in jumpJetFXs )
			{
				if ( IsValid( fx ) )
					fx.Destroy()
			}
		}
	)

	WaitFrame()
	wait 0.1
	while ( IsValid( player ) && !player.IsOnGround() )
		WaitFrame()
}
#endif

#if CLIENT
void function ServerCallback_CreatesLaserFXFromServer( entity fromPlayer, vector origin, vector direction )
{
	if ( !IsValid( fromPlayer ) )
		return

	if ( fromPlayer != GetLocalViewPlayer() )
		OnEnemyPlayerShoot( fromPlayer, origin, direction )
}

entity function FS_IG_GetHandMover( entity player, entity weapon )
{
	entity moverForHand = CreateClientsideScriptMover( $"mdl/dev/empty_model.rmdl", <0, 0, 0>, <0, 0, 0> )
	entity viewmodel = weapon.GetWeaponViewmodel()

	if ( IsValid( viewmodel ) )
	{
		int muzzle = weapon.LookupViewModelAttachment( "muzzle_flash" )
		if ( muzzle > 0 )
			moverForHand.SetParent( viewmodel, "muzzle_flash" )
	}

	if ( player.IsThirdPersonShoulderModeOn() || !IsValid( viewmodel ) || !IsValid( moverForHand.GetParent() ) )
	{
		if ( player.LookupAttachment( "R_HAND" ) > 0 )
			moverForHand.SetParent( player, "R_HAND" )
	}

	return moverForHand
}

void function OnLocalPlayerShoot( entity player, vector origin, vector direction, bool isRailjump = false )
{
	entity weapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( !FS_IG_IsInstagibWeapon( weapon ) )
		return

	if ( !FS_IsInstagib() || player != GetLocalViewPlayer() )
		return

	vector traceEnd = origin + ( direction * 50000 )
	TraceResults trace = TraceLineHighDetail( origin, traceEnd, player, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )

	entity moverForLaserEnt = CreateClientsideScriptMover( $"mdl/dev/empty_model.rmdl", <0, 0, 0>, <0, 0, 0> )
	moverForLaserEnt.SetOrigin( ClampToWorldspace( trace.endPos ) )

	entity moverForHand = FS_IG_GetHandMover( player, weapon )

	int fxIDTeam = GetParticleSystemIndex( INSTAGIB_BEAM_FX )
	int localFx = StartParticleEffectOnEntityWithPos( moverForHand, fxIDTeam, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID, <0, 0, 0>, <0, 0, 0> )
	EffectSetDontKillForReplay( localFx )
	EffectAddTrackingForControlPoint( localFx, 1, moverForLaserEnt, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID, <0, 0, 0> )
	if ( !isRailjump )
		EffectSetControlPointVector( localFx, 2, <89, 232, 37> )
	else
		EffectSetControlPointVector( localFx, 2, <255, 255, 255> )

	moverForHand.ClearParent()

	if ( !isRailjump )
		StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( INSTAGIB_IMPACT_FX ), trace.endPos, <0, 0, 0> )

	thread function() : ( localFx, moverForLaserEnt, moverForHand )
	{
		wait LG_DRAG_TIME
		if ( EffectDoesExist( localFx ) )
			EffectStop( localFx, false, true )
		if ( IsValid( moverForLaserEnt ) )
			moverForLaserEnt.Destroy()
		if ( IsValid( moverForHand ) )
			moverForHand.Destroy()
	}()
}

void function OnEnemyPlayerShoot( entity player, vector origin, vector direction )
{
	entity weapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( !FS_IG_IsInstagibWeapon( weapon ) )
		return

	if ( !FS_IsInstagib() )
		return

	vector traceEnd = origin + ( direction * 50000 )
	TraceResults trace = TraceLineHighDetail( origin, traceEnd, player, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )

	entity mover = CreateClientsideScriptMover( $"mdl/dev/empty_model.rmdl", <0, 0, 0>, <0, 0, 0> )
	mover.SetOrigin( ClampToWorldspace( trace.endPos ) )

	entity handmover = CreateClientsideScriptMover( $"mdl/dev/empty_model.rmdl", <0, 0, 0>, <0, 0, 0> )
	handmover.SetOrigin( origin )

	int laserStoreMe = StartParticleEffectOnEntityWithPos( handmover, GetParticleSystemIndex( INSTAGIB_BEAM_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID, <0, 0, 0>, <0, 0, 0> )
	StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( INSTAGIB_IMPACT_FX ), mover.GetOrigin(), <0, 0, 0> )

	thread function() : ( laserStoreMe, mover, handmover )
	{
		wait LG_DRAG_TIME
		if ( EffectDoesExist( laserStoreMe ) )
			EffectStop( laserStoreMe, false, true )
		if ( IsValid( mover ) )
			mover.Destroy()
		if ( IsValid( handmover ) )
			handmover.Destroy()
	}()

	EffectSetDontKillForReplay( laserStoreMe )

	if ( IsValid( GetLocalViewPlayer() ) && player.GetTeam() != GetLocalViewPlayer().GetTeam() )
		EffectSetControlPointVector( laserStoreMe, 2, <252, 3, 227> )
	else
		EffectSetControlPointVector( laserStoreMe, 2, <89, 232, 37> )

	EffectAddTrackingForControlPoint( laserStoreMe, 1, mover, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID, <0, 0, 3> )
}

void function FS_IG_OnPlayerCreated( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( !( player in file.beamsFxs ) )
		file.beamsFxs[player] <- -1

	player.p.lightningGunReady = true
}

void function FS_IG_OnPlayerDestroyed( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( player in file.beammover )
	{
		if ( IsValid( file.beammover[player] ) )
			file.beammover[player].Destroy()
		delete file.beammover[player]
	}

	if ( player in file.handmover )
	{
		if ( IsValid( file.handmover[player] ) )
			file.handmover[player].Destroy()
		delete file.handmover[player]
	}

	if ( player in file.beamsFxs )
	{
		if ( EffectDoesExist( file.beamsFxs[player] ) )
			EffectStop( file.beamsFxs[player], false, true )
		delete file.beamsFxs[player]
	}
}
#endif

void function OnWeaponActivate_Clickweapon( entity weapon )
{
	OnWeaponActivate_weapon_wingman( weapon )
}

var function OnWeaponPrimaryAttack_Clickweapon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		if ( InPrediction() && !IsFirstTimePredicted() )
			return 0
	#endif

	if ( !IsValid( weapon ) )
		return 0

	entity player = weapon.GetWeaponOwner()
	if ( !IsValid( player ) || !player.IsPlayer() )
		return 0

	weapon.OverrideNextAttackTime( Time() + LG_SINGLE_FIRE_DEBOUNCE )

	#if CLIENT
		if ( player == GetLocalViewPlayer() )
			OnLocalPlayerShoot( GetLocalViewPlayer(), attackParams.pos, attackParams.dir )
		player.p.lightningGunReady = true
	#endif

	#if SERVER
		foreach ( entity splayer in GetPlayerArray() )
		{
			if ( IsValid( splayer ) )
				Remote_CallFunction_NonReplay( splayer, "ServerCallback_CreatesLaserFXFromServer", player, attackParams.pos, attackParams.dir )
		}
		player.p.shotsfired++
	#endif

	thread function() : ( weapon )
	{
		EndSignal( weapon, "OnDestroy" )
		weapon.AllowUse( false )

		#if SERVER
			// The engine bills the shot after this callback returns, so the clip
			// is topped up a frame later. Returning 0 from the attack instead
			// would read as "no shot fired" and cost the fire animation.
			WaitFrame()
			if ( IsValid( weapon ) && weapon.UsesClipsForAmmo() )
				weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
		#endif

		wait LG_SINGLE_FIRE_DEBOUNCE
		if ( IsValid( weapon ) )
			weapon.AllowUse( true )
	}()

	return weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )
}

void function OnWeaponDeactivate_Clickweapon( entity weapon )
{
	OnWeaponDeactivate_weapon_wingman( weapon )

	entity player = weapon.GetWeaponOwner()
	if ( !IsValid( player ) )
		return

	Signal( player, "EndLaser" )

	#if CLIENT
		if ( player == GetLocalViewPlayer() && player in file.beamsFxs && EffectDoesExist( file.beamsFxs[player] ) )
			EffectStop( file.beamsFxs[player], false, true )
	#endif
}
