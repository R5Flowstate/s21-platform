global function MpWeaponChargeGauntlet_Init
global function OnWeaponActivate_weapon_charge_gauntlet
global function OnWeaponDeactivate_weapon_charge_gauntlet
global function OnWeaponPrimaryAttack_weapon_charge_gauntlet
global function OnWeaponChargeBegin_weapon_charge_gauntlet

global const string SPARROW_ULT_WEAPON_NAME = "mp_weapon_charge_gauntlet"
const asset SPARROW_TARGETING_MARKER = $"P_ar_sprw_ult_artillery_marker"

const string INSTANT_HOLSTER_MOD = "instant_holster"

struct
{
	float redraw_delay = 0.5
} tuning

void function MpWeaponChargeGauntlet_Init()
{
	PrecacheParticleSystem( SPARROW_TARGETING_MARKER )

	ChargeGauntletSetup()

	RegisterSignal( "UltArrow_EndPreview" )
	MpWeapon_Bow_Ult_Missile_Init()
}

void function ChargeGauntletSetup()
{
	tuning.redraw_delay = GetCurrentPlaylistVarFloat( "sparrow_charge_guantlet_redraw_delay", tuning.redraw_delay )
}

void function OnWeaponActivate_weapon_charge_gauntlet( entity weapon )
{
	#if CLIENT
		thread ShowUltArrowImpactSpot( weapon )
	#endif

	entity player = weapon.GetWeaponOwner()
	if ( !IsValid( player ) )
		return

	entity tacticalWeapon = player.GetOffhandWeapon( OFFHAND_TACTICAL )

	bool serverOrPredicted = IsServer() || (InPrediction() && IsFirstTimePredicted())
	if ( serverOrPredicted )
	{
		if( IsValid( tacticalWeapon ) )
		{
			tacticalWeapon.Holster()
		}

		if( weapon.HasMod( INSTANT_HOLSTER_MOD ) )
		{
			weapon.RemoveMod( INSTANT_HOLSTER_MOD )
		}
	}
}

void function OnWeaponDeactivate_weapon_charge_gauntlet( entity weapon )
{
	#if CLIENT
		weapon.Signal( "UltArrow_EndPreview" )
	#endif
}

var function OnWeaponPrimaryAttack_weapon_charge_gauntlet( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		weapon.Signal( "UltArrow_EndPreview" )

		if ( !(InPrediction() && IsFirstTimePredicted()) )
			return
	#endif

	entity player     = weapon.GetWeaponOwner()
	entity deployable = ThrowDeployable( weapon, attackParams, 1.0, ArrowUlt_ProjectileLanded, null, <0, 0, 0> )
	PlayerUsedOffhand( player, weapon, true, deployable )

	int ammoReq = weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )

	#if SERVER
		EmitSoundOnEntity( player, "Sparrow_Ult_Fire" )
		TrackingVision_CreatePOI( eTrackingVisionNetworkedPOITypes.PLAYER_ABILITY_SPRROW_STINGER_BOLT, player, player.GetOrigin(), player.GetTeam(), player )
	#endif

	if ( PlayerHasPassive( player, ePassives.PAS_ULT_UPGRADE_THREE ) )
	{
		#if CLIENT
			int ammoPerShot = weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
			int currentAmmo = weapon.GetWeaponPrimaryClipCount()
			if ( currentAmmo - ammoPerShot >= ammoPerShot )
				thread ShowUltArrowImpactSpot( weapon )
		#endif
	}
	else
	{
		weapon.Holster()
		weapon.AddMod( INSTANT_HOLSTER_MOD )
	}

	return ammoReq
}

bool function OnWeaponChargeBegin_weapon_charge_gauntlet( entity weapon )
{
	if ( weapon.GetWeaponChargeFraction() == 0.0 )
		weapon.EmitWeaponSound_1p3p( "Weapon_ChargeRifle_TriggerOn", "" )
	else
		weapon.EmitWeaponSound_1p3p( "weapon_chargerifle_chargeupclick_1p", "" )

	return true
}

void function ArrowUlt_ProjectileLanded( entity projectile, DeployableCollisionParams collisionParams )
{
	#if SERVER
		BowUlt_OnArrowLanded( projectile, collisionParams )
	#endif
}

#if CLIENT
void function ShowUltArrowImpactSpot( entity weapon )
{
	EndSignal( weapon, "UltArrow_EndPreview" )
	EndSignal( weapon, "OnDestroy" )

	entity localClientPlayer = GetLocalClientPlayer()
	entity player = weapon.GetOwner()
	if( player != localClientPlayer )
		return

	int ringFX = -1
	entity previewEnt = CreateClientSidePropDynamic( <0, 0, 0>, <0, 0, 0>, EMPTY_MODEL )

	if ( IsValid( weapon ) )
	{
		ringFX = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( SPARROW_TARGETING_MARKER ), ZERO_VECTOR, ZERO_VECTOR )
		EffectSetControlPointVector( ringFX, 1, <255,0,0> )
		EffectSetControlPointVector( ringFX, 2, <100 / 20, 0, 0> )
	}

	OnThreadEnd(
		function() : ( ringFX, previewEnt )
		{
			if ( ringFX != -1 )
				EffectStop( ringFX, true, false )

			if( IsValid( previewEnt ) )
				previewEnt.Destroy()
		}
	)

	WaitFrame()
	while( !weapon.IsReadyToFire() )
	{
		WaitFrame()
	}

	while( EffectDoesExist( ringFX ) )
	{
		GrenadeIndicatorData data = weapon.GetMostRecentGrenadeIndicatorData()
		bool projectileIsOnGround = data.hitNormal.Dot( <0,0,1> ) > DOT_45DEGREE
		vector dropPosition = data.hitPos
		if( projectileIsOnGround )
		{
			TraceResults hullTrace = TraceHull( dropPosition, dropPosition, BOW_ULT_TIP_HULL_MINS, BOW_ULT_TIP_HULL_MAXS, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
			if( hullTrace.fraction < 1.0 )
			{
				previewEnt.SetOrigin( dropPosition )
				PutEntityInSafeSpot_Hullsize( previewEnt, null, null, dropPosition, dropPosition, BOW_ULT_HULL_MINS, BOW_ULT_HULL_MAXS )
				dropPosition = previewEnt.GetOrigin()
			}
		}

		if ( !projectileIsOnGround )
		{
			EffectSetControlPointVector( ringFX, 2, <0, 0, 0> )
			EffectSetControlPointVector( ringFX, 3, <255, 0, 0> )
		}
		else
		{
			EffectSetControlPointVector( ringFX, 2, <255, 0, 0> )
			EffectSetControlPointVector( ringFX, 3, <0, 0, 0> )
		}

		EffectSetControlPointVector( ringFX, 0, dropPosition )
		WaitFrame()
	}
}
#endif
