// Freeroam weapons menu -- server give router + client commands.
// Kit path: baseWeapon + locked-set mods + SetWeaponLockedSetFromLootTags.
// Freeform path: bare GiveWeapon (+ optional mod args), no locked-set stamp.

global function FreeroamWeaponsMenu_ServerInit
global function FreeroamWeaponsMenu_OnGiveCommand
global function FreeroamWeaponsMenu_OnSelectSlot
global function FreeroamWeaponsMenu_OnCloseSelector
global function FreeroamWeaponsMenu_GiveKit
global function FreeroamWeaponsMenu_GiveFreeform
global function FreeroamWeaponsMenu_GiveAkimbo
global function FreeroamWeaponsMenu_Refill
global function FreeroamWeaponsMenu_Strip
global function FreeroamWeaponsMenu_ApplyLoadoutCosmetics
global function FreeroamWeaponsMenu_OnPlayerDisconnected

struct
{
	bool inited = false
	table<entity, int> preferredSlot
} file

void function FreeroamWeaponsMenu_ServerInit()
{
	if ( file.inited )
		return
	file.inited = true

	// Do NOT force LoadoutSelection FullInit here -- loot tables may not be ready and
	// InitWeaponData will throw on S21-only refs missing from S3 loot (shotgun_pistol).
	// Force-enable runs on freeroam_open_loadout / EnsureReadyForMenu instead.

	AddClientCommandCallback( "CC_MenuGiveAimTrainerWeapon", FreeroamWeaponsMenu_OnGiveCommand )
	AddClientCommandCallback( "CC_AimTrainer_SelectWeaponSlot", FreeroamWeaponsMenu_OnSelectSlot )
	AddClientCommandCallback( "CC_AimTrainer_WeaponSelectorClose", FreeroamWeaponsMenu_OnCloseSelector )
	// Console / bind friendly open is UI-side; equip helpers:
	AddClientCommandCallback( "freeroam_wep", FreeroamWeaponsMenu_OnGiveCommand )
	AddClientCommandCallback( "weapons_menu_give", FreeroamWeaponsMenu_OnGiveCommand )
	// Opens stock LoadoutSelectionSystemLoadoutSelector (same UI FreeDM/Control use).
	AddClientCommandCallback( "freeroam_open_loadout", FreeroamWeaponsMenu_OnOpenLoadout )

	printt( "[FreeroamWM] ServerInit clientcmds registered (loadout force deferred to open)" )
}

void function FreeroamWeaponsMenu_OnPlayerDisconnected( entity player )
{
	if ( player in file.preferredSlot )
		delete file.preferredSlot[player]
}

void function FreeroamWeaponsMenu_OnOpenLoadout( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return
	if ( GetConVarInt( "sv_cheats" ) != 1 )
		return

	LoadoutSelection_EnsureReadyForMenu()

	if ( !IsUsingLoadoutSelectionSystem() )
	{
		printt( "[FreeroamWM] open_loadout: system still disabled" )
		return
	}

	LoadoutSelection_UpdateLoadoutInfoForMenus( player )
	Remote_CallFunction_UI( player, "LoadoutSelectionMenu_OpenLoadoutMenu", false )
	printt( format( "[FreeroamWM] open_loadout player=%s -> stock LoadoutSelection menu", player.GetPlayerName() ) )
}

int function FreeroamWeaponsMenu_GetPreferredSlot( entity player )
{
	if ( player in file.preferredSlot )
		return file.preferredSlot[player]
	return WEAPON_INVENTORY_SLOT_PRIMARY_0
}

void function FreeroamWeaponsMenu_SetPreferredSlot( entity player, int slot )
{
	if ( slot != WEAPON_INVENTORY_SLOT_PRIMARY_0 && slot != WEAPON_INVENTORY_SLOT_PRIMARY_1 )
		slot = WEAPON_INVENTORY_SLOT_PRIMARY_0
	file.preferredSlot[player] <- slot
}

void function FreeroamWeaponsMenu_OnSelectSlot( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return
	if ( GetConVarInt( "sv_cheats" ) != 1 )
		return

	int slot = WEAPON_INVENTORY_SLOT_PRIMARY_0
	if ( args.len() > 0 )
		slot = FreeroamWeaponsMenu_SlotFromArg( args[0] )

	FreeroamWeaponsMenu_SetPreferredSlot( player, slot )
	printt( format( "[FreeroamWM] SelectSlot player=%s slot=%d", player.GetPlayerName(), slot ) )
}

void function FreeroamWeaponsMenu_OnCloseSelector( entity player, array<string> args )
{
	if ( !IsValid( player ) )
		return
	if ( GetConVarInt( "sv_cheats" ) != 1 )
		return
	printt( format( "[FreeroamWM] CloseSelector player=%s", player.GetPlayerName() ) )
}

// Args:
//   kit <slot> <baseRef> [tier]
//   free <slot> <baseRef> [mods...]
//   refill
//   strip <slot>
//   ord <ordnanceRef>
// Also accepts legacy bare: <p|s> <ref> [mods...]  (tgive-shaped)
void function FreeroamWeaponsMenu_OnGiveCommand( entity player, array<string> args )
{
	// Self-heal if mode never ran ServerInit (non-firing-range maps).
	FreeroamWeaponsMenu_ServerInit()

	if ( !IsValid( player ) || !IsAlive( player ) )
		return
	if ( GetConVarInt( "sv_cheats" ) != 1 )
		return

	if ( args.len() < 1 )
	{
		printt( "[FreeroamWM] give: missing args" )
		return
	}

	string mode = args[0].tolower()

	// Legacy tgive shape without mode keyword.
	if ( mode == "p" || mode == "s" || mode == "primary" || mode == "secondary" )
	{
		if ( args.len() < 2 )
			return
		int slot = FreeroamWeaponsMenu_SlotFromArg( mode )
		string baseRef = args[1]
		array<string> mods
		for ( int i = 2; i < args.len(); i++ )
			mods.append( args[i] )
		FreeroamWeaponsMenu_GiveFreeform( player, baseRef, slot, mods )
		return
	}

	switch ( mode )
	{
		case "kit":
		{
			if ( args.len() < 3 )
			{
				printt( "[FreeroamWM] kit usage: kit <slot> <base> [tier]" )
				return
			}
			int slot = FreeroamWeaponsMenu_SlotFromArg( args[1] )
			string baseRef = args[2]
			string tier = FREEROAM_WM_TIER_AUTO
			if ( args.len() >= 4 )
				tier = FreeroamWeaponsMenu_TierFromArg( args[3] )
			FreeroamWeaponsMenu_GiveKit( player, baseRef, slot, tier )
			return
		}
		case "free":
		case "freeform":
		{
			if ( args.len() < 3 )
			{
				printt( "[FreeroamWM] free usage: free <slot> <base> [mods...]" )
				return
			}
			int slot = FreeroamWeaponsMenu_SlotFromArg( args[1] )
			string baseRef = args[2]
			array<string> mods
			for ( int i = 3; i < args.len(); i++ )
				mods.append( args[i] )
			FreeroamWeaponsMenu_GiveFreeform( player, baseRef, slot, mods )
			return
		}
		case "akimbo":
		{
			if ( args.len() < 3 )
			{
				printt( "[FreeroamWM] akimbo usage: akimbo <slot> <base> [tier]" )
				return
			}
			int slot = FreeroamWeaponsMenu_SlotFromArg( args[1] )
			string baseRef = args[2]
			string tier = FREEROAM_WM_TIER_BARE
			if ( args.len() >= 4 )
				tier = FreeroamWeaponsMenu_TierFromArg( args[3] )
			FreeroamWeaponsMenu_GiveAkimbo( player, baseRef, slot, tier )
			return
		}
		case "refill":
			FreeroamWeaponsMenu_Refill( player )
			return
		case "strip":
		{
			int slot = FreeroamWeaponsMenu_GetPreferredSlot( player )
			if ( args.len() >= 2 )
				slot = FreeroamWeaponsMenu_SlotFromArg( args[1] )
			FreeroamWeaponsMenu_Strip( player, slot )
			return
		}
		case "ord":
		case "ordnance":
		{
			if ( args.len() < 2 )
				return
			FreeroamWeaponsMenu_GiveOrdnance( player, args[1] )
			return
		}
	}

	printt( format( "[FreeroamWM] unknown mode '%s'", mode ) )
}

void function FreeroamWeaponsMenu_TakeSlot( entity player, int slot )
{
	entity existing = player.GetNormalWeapon( slot )
	if ( IsValid( existing ) )
		player.TakeWeaponByEntNow( existing )
}

entity function FreeroamWeaponsMenu_GiveKit( entity player, string baseWeapon, int slot, string tier = FREEROAM_WM_TIER_AUTO )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return null

	if ( FreeroamWeaponsMenu_IsExcludedBaseWeapon( baseWeapon ) )
	{
		printt( format( "[FreeroamWM] kit REJECT excluded %s", baseWeapon ) )
		return null
	}

	string kitRef = FreeroamWeaponsMenu_ResolveKitRef( baseWeapon, tier )
	if ( kitRef == "" || !SURVIVAL_Loot_IsRefValid( kitRef ) )
	{
		// Last chance: bare classname give if loot table lacks the row.
		printt( format( "[FreeroamWM] kit no valid loot for %s tier=%s; freeform fallback", baseWeapon, tier ) )
		return FreeroamWeaponsMenu_GiveFreeform( player, baseWeapon, slot, [] )
	}

	LootData ld = SURVIVAL_Loot_GetLootDataByRef( kitRef )
	string classname = ld.baseWeapon
	if ( classname == "" )
		classname = GetBaseWeaponRef( kitRef )

	array<string> mods = []
	foreach ( string m in ld.baseMods )
	{
		if ( m != "" )
			mods.append( m )
	}

	FreeroamWeaponsMenu_TakeSlot( player, slot )

	entity weapon
	try
	{
		weapon = player.GiveWeapon( classname, slot, mods, false )
	}
	catch ( giveErr )
	{
		printt( format( "[FreeroamWM] kit GiveWeapon failed class=%s err=%s", classname, giveErr ) )
		return null
	}

	if ( !IsValid( weapon ) )
	{
		printt( format( "[FreeroamWM] kit GiveWeapon null class=%s", classname ) )
		return null
	}

	SetWeaponLockedSetFromLootTags( ld.lootTags, weapon )
	FreeroamWeaponsMenu_ApplyLoadoutCosmetics( player, weapon )

	player.ClearFirstDeployForAllWeapons()
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, slot )
	player.DeployWeapon()
	FreeroamWeaponsMenu_ApplyStockAmmo( player, weapon )

	FreeroamWeaponsMenu_SetPreferredSlot( player, slot )

	printt( format( "[FreeroamWM] KIT player=%s slot=%d base=%s kit=%s tier=%s mods=%d",
		player.GetPlayerName(), slot, classname, kitRef, tier, mods.len() ) )

	// Items Weapon: stamp profile onto this entity when Give was opened from Items menu.
	CafeItems_OnWeaponGiven( player, weapon )
	return weapon
}

// Same pair the loot path builds from a second pickup: main in <slot>, partner in the dual slot.
entity function FreeroamWeaponsMenu_GiveAkimbo( entity player, string baseWeapon, int slot, string tier = FREEROAM_WM_TIER_BARE )
{
	entity weapon
	if ( tier == FREEROAM_WM_TIER_BARE )
		weapon = FreeroamWeaponsMenu_GiveFreeform( player, baseWeapon, slot, [] )
	else
		weapon = FreeroamWeaponsMenu_GiveKit( player, baseWeapon, slot, tier )
	if ( !IsValid( weapon ) )
		return null

	if ( !CanWeaponAkimbo( weapon.GetWeaponClassName() ) )
	{
		printt( format( "[FreeroamWM] akimbo REJECT %s is not an akimbo weapon", weapon.GetWeaponClassName() ) )
		return weapon
	}

	int dualslot = weapon.GetInventoryIndex() + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0
	FreeroamWeaponsMenu_TakeSlot( player, dualslot )
	entity partner = player.GiveWeapon( weapon.GetWeaponClassName(), dualslot, weapon.GetMods(), false )
	if ( IsValid( partner ) )
	{
		FreeroamWeaponsMenu_ApplyLoadoutCosmetics( player, partner )
		player.ClearFirstDeployForAllWeapons()
		player.SetActiveWeaponBySlot( eActiveInventorySlot.altHand, dualslot )
	}
	printt( format( "[FreeroamWM] akimbo %s slot=%d partner=%s", weapon.GetWeaponClassName(), slot, IsValid( partner ) ? "ok" : "FAILED" ) )
	return weapon
}

entity function FreeroamWeaponsMenu_GiveFreeform( entity player, string baseWeapon, int slot, array<string> mods )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return null

	// *_crate scripts are their own entity class -- do not collapse to baseWeapon.
	string classname = baseWeapon
	if ( !FreeroamWeaponsMenu_ClassnameEndsWithCrate( baseWeapon ) && SURVIVAL_Loot_IsRefValid( baseWeapon ) )
		classname = GetBaseWeaponRef( baseWeapon )

	if ( FreeroamWeaponsMenu_IsExcludedBaseWeapon( classname ) )
	{
		printt( format( "[FreeroamWM] free REJECT excluded %s", classname ) )
		return null
	}

	FreeroamWeaponsMenu_TakeSlot( player, slot )

	entity weapon
	try
	{
		weapon = player.GiveWeapon( classname, slot, [], false )
	}
	catch ( giveErr )
	{
		printt( format( "[FreeroamWM] free GiveWeapon failed class=%s err=%s", classname, giveErr ) )
		return null
	}

	if ( !IsValid( weapon ) )
		return null

	foreach ( string mod in mods )
	{
		if ( mod == "" )
			continue
		if ( !IsValidAttachment( mod ) && !SURVIVAL_Loot_IsRefValid( mod ) )
			continue
		try
		{
			weapon.AddMod( mod )
		}
		catch ( modErr )
		{
			printt( format( "[FreeroamWM] free AddMod fail %s: %s", mod, modErr ) )
			weapon.RemoveMod( mod )
		}
	}

	FreeroamWeaponsMenu_ApplyLoadoutCosmetics( player, weapon )

	player.ClearFirstDeployForAllWeapons()
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, slot )
	player.DeployWeapon()
	FreeroamWeaponsMenu_ApplyStockAmmo( player, weapon )

	FreeroamWeaponsMenu_SetPreferredSlot( player, slot )

	printt( format( "[FreeroamWM] FREE player=%s slot=%d class=%s mods=%d",
		player.GetPlayerName(), slot, classname, mods.len() ) )

	CafeItems_OnWeaponGiven( player, weapon )
	return weapon
}

// Same path as floor pickup when loot has no baked skin GUID: player loadout skin + charm.
void function FreeroamWeaponsMenu_ApplyLoadoutCosmetics( entity player, entity weapon )
{
	if ( !IsValid( player ) || !IsValid( weapon ) )
		return

	string weaponClass = weapon.GetWeaponClassName()
	ItemFlavor ornull weaponItemOrNull = GetWeaponItemFlavorByClass( weaponClass )
	if ( weaponItemOrNull == null && SURVIVAL_Loot_IsRefValid( weaponClass ) )
		weaponItemOrNull = GetWeaponItemFlavorByClass( GetBaseWeaponRef( weaponClass ) )
	if ( weaponItemOrNull == null )
		return

	expect ItemFlavor( weaponItemOrNull )

	ItemFlavor ornull weaponSkinOrNull = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_WeaponSkin( weaponItemOrNull ) )
	ItemFlavor ornull weaponCharmOrNull = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_WeaponCharm( weaponItemOrNull ) )
	WeaponCosmetics_Apply( weapon, weaponSkinOrNull, weaponCharmOrNull )
}

// Stock ground-loot load: full mag, then engine infinite via SetInfiniteAmmoForWeapon(null)
// so player.p.infiniteAmmo / gamemode rules decide (same as SURVIVAL_GiveMainWeapon).
void function FreeroamWeaponsMenu_ApplyStockAmmo( entity player, entity weapon )
{
	if ( !IsValid( player ) || !IsValid( weapon ) )
		return

	if ( weapon.UsesClipsForAmmo() )
		weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )

	SetInfiniteAmmoForWeapon( player, weapon, null )
}

void function FreeroamWeaponsMenu_Refill( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	foreach ( int slot in [ WEAPON_INVENTORY_SLOT_PRIMARY_0, WEAPON_INVENTORY_SLOT_PRIMARY_1 ] )
	{
		entity w = player.GetNormalWeapon( slot )
		if ( IsValid( w ) )
			FreeroamWeaponsMenu_ApplyStockAmmo( player, w )
	}
	printt( format( "[FreeroamWM] REFILL player=%s", player.GetPlayerName() ) )
}

void function FreeroamWeaponsMenu_Strip( entity player, int slot )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	FreeroamWeaponsMenu_TakeSlot( player, slot )
	printt( format( "[FreeroamWM] STRIP player=%s slot=%d", player.GetPlayerName(), slot ) )
}

void function FreeroamWeaponsMenu_GiveOrdnance( entity player, string ordRef )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	if ( !SURVIVAL_Loot_IsRefValid( ordRef ) )
	{
		printt( format( "[FreeroamWM] ord invalid %s", ordRef ) )
		return
	}

	LootData data = SURVIVAL_Loot_GetLootDataByRef( ordRef )
	if ( data.lootType != eLootType.ORDNANCE )
	{
		printt( format( "[FreeroamWM] ord not ORDNANCE %s", ordRef ) )
		return
	}

	SURVIVAL_AddToPlayerInventory( player, ordRef, 2 )
	SURVIVAL_EquipOrdnanceFromInventory( player, ordRef )
	printt( format( "[FreeroamWM] ORD player=%s ref=%s", player.GetPlayerName(), ordRef ) )
}
