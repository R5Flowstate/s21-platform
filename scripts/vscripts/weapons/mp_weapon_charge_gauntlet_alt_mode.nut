global function MpWeaponChargeGauntletAltMode_Init
global function OnWeaponActivate_weapon_charge_gauntlet_alt_mode
global function OnWeaponDeactivate_weapon_charge_gauntlet_alt_mode
global function OnWeaponPrimaryAttack_weapon_charge_gauntlet_alt_mode
global function OnWeaponChargeBegin_weapon_charge_gauntlet_alt_mode

const string INSTANT_HOLSTER_MOD = "instant_holster"

void function MpWeaponChargeGauntletAltMode_Init()
{
	RegisterSignal( "UltArrow_EndPreview" )
}

void function OnWeaponActivate_weapon_charge_gauntlet_alt_mode( entity weapon )
{
	if( weapon.HasMod( INSTANT_HOLSTER_MOD ) )
	{
		weapon.RemoveMod( INSTANT_HOLSTER_MOD )
	}
}

void function OnWeaponDeactivate_weapon_charge_gauntlet_alt_mode( entity weapon )
{
	#if CLIENT
		weapon.Signal( "UltArrow_EndPreview" )
	#endif
}

var function OnWeaponPrimaryAttack_weapon_charge_gauntlet_alt_mode( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		weapon.Signal( "UltArrow_EndPreview" )

		if ( !(InPrediction() && IsFirstTimePredicted()) )
			return
	#endif

	FireBallisticRoundWithDrop( weapon, attackParams.pos, attackParams.dir, true, true, 0, false )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

bool function OnWeaponChargeBegin_weapon_charge_gauntlet_alt_mode( entity weapon )
{
	if ( weapon.GetWeaponChargeFraction() == 0.0 )
		weapon.EmitWeaponSound_1p3p( "Weapon_ChargeRifle_TriggerOn", "" )
	else
		weapon.EmitWeaponSound_1p3p( "weapon_chargerifle_chargeupclick_1p", "" )

	return true
}
