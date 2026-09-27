global function MpWeaponMedicOrders_Init
global function OnWeaponPrimaryAttack_ability_medic_orders
global function OnWeaponActivate_following_medic_orders
global function OnWeaponDeactivate_following_medic_orders

global const string MEDIC_ORDERS_WEAPON_NAME 	= "mp_weapon_following_medic_orders"
global const string MEDIC_ASSIGN_MOD 			= "medic_assign"
global const string HALO_HELD_ASSIGN_MOD 		= "halo_held_assign"
global const string HALO_HELD_RECALL_MOD 		= "halo_held_recall"
global const int MEDIC_ORDERS_OFFHAND_SLOT		= OFFHAND_RIGHT

void function MpWeaponMedicOrders_Init()
{
	PrecacheWeapon( MEDIC_ORDERS_WEAPON_NAME )

	AddCallback_OnPassiveChanged( ePassives.PAS_DRONE_RIDER, OnPassiveChangedMedicOrders )
}

void function OnPassiveChangedMedicOrders( entity player, int passive, bool didHave, bool nowHas )
{
	#if CLIENT
		if ( !IsValid( GetLocalClientPlayer() ) || player != GetLocalClientPlayer() )
			return
	#endif

	if ( didHave && !nowHas )
	{
		#if SERVER
			entity weapon = player.GetOffhandWeapon( MEDIC_ORDERS_OFFHAND_SLOT )
			if ( IsValid( weapon ) && weapon.GetWeaponClassName() == MEDIC_ORDERS_WEAPON_NAME )
				player.TakeOffhandWeapon( MEDIC_ORDERS_OFFHAND_SLOT )
		#endif
	}
	else if ( nowHas && !didHave )
	{
		#if SERVER
			if ( !IsValid( player.GetOffhandWeapon( MEDIC_ORDERS_OFFHAND_SLOT ) ) )
				player.GiveOffhandWeapon( MEDIC_ORDERS_WEAPON_NAME, MEDIC_ORDERS_OFFHAND_SLOT, [] )
		#endif
	}
}

void function OnWeaponActivate_following_medic_orders( entity weapon )
{
	#if CLIENT
		if( !InPrediction() )
			return
	#endif

	if( !IsValid( weapon ) )
		return

	entity owner = weapon.GetOwner()
	if( !IsValid( owner ) )
		return

	entity activeWeapon = owner.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if( !IsValid( activeWeapon ) )
		return
	bool haloHeld = activeWeapon.GetWeaponClassName() == "mp_ability_lifeline_halo"

	if( weapon.w.droneIsAssginedToATarget )
	{
		if( haloHeld )
		{
			if( weapon.HasMod( MEDIC_ASSIGN_MOD ) )
				weapon.RemoveMod( MEDIC_ASSIGN_MOD )

			if ( weapon.HasMod( HALO_HELD_RECALL_MOD ) )
				weapon.RemoveMod( HALO_HELD_RECALL_MOD )

			if ( !weapon.HasMod( HALO_HELD_ASSIGN_MOD ) )
				weapon.AddMod( HALO_HELD_ASSIGN_MOD )
		}
		else
		{
			if ( weapon.HasMod( HALO_HELD_ASSIGN_MOD ) )
				weapon.RemoveMod( HALO_HELD_ASSIGN_MOD )

			if ( weapon.HasMod( HALO_HELD_RECALL_MOD ) )
				weapon.RemoveMod( HALO_HELD_RECALL_MOD )

			if ( !weapon.HasMod( MEDIC_ASSIGN_MOD ) )
				weapon.AddMod( MEDIC_ASSIGN_MOD )
		}
	}
	else
	{
		if( weapon.HasMod( MEDIC_ASSIGN_MOD ) )
			weapon.RemoveMod( MEDIC_ASSIGN_MOD )

		if( haloHeld )
		{
			if ( weapon.HasMod( HALO_HELD_ASSIGN_MOD ) )
				weapon.RemoveMod( HALO_HELD_ASSIGN_MOD )

			if ( !weapon.HasMod( HALO_HELD_RECALL_MOD ) )
				weapon.AddMod( HALO_HELD_RECALL_MOD )
		}
	}
}

void function OnWeaponDeactivate_following_medic_orders( entity weapon )
{
	#if CLIENT
		if( !InPrediction() )
			return
	#endif

	if( weapon.HasMod( HALO_HELD_ASSIGN_MOD ) )
		weapon.RemoveMod( HALO_HELD_ASSIGN_MOD )
	if( weapon.HasMod( HALO_HELD_RECALL_MOD ) )
		weapon.RemoveMod( HALO_HELD_RECALL_MOD )
}

var function OnWeaponPrimaryAttack_ability_medic_orders( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}
