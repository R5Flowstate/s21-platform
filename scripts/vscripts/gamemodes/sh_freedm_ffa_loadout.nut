// FFA playlist-forced weapons, armor, and abilities.

global function FreeDM_FFA_PrecacheForcedKit
#if SERVER
global function FreeDM_FFA_ShouldGiveForcedWeapons
global function FreeDM_FFA_GiveForcedWeapons
global function FreeDM_FFA_ApplyArmor
global function FreeDM_FFA_ApplyAbilities
#endif

string function FreeDM_FFA_PlaylistToken( string varName, string defaultValue )
{
	return strip( GetCurrentPlaylistVarString( varName, defaultValue ) )
}

bool function FreeDM_FFA_RefIsNone( string ref )
{
	string token = strip( ref ).tolower()
	return token == "" || token == "none" || token == "0" || token == "null" || token == "off"
}

array<string> function FreeDM_FFA_SplitMods( string raw )
{
	array<string> mods
	array<string> tokens = split( strip( raw ), " " )
	foreach ( string token in tokens )
	{
		string mod = strip( token )
		if ( mod != "" )
			mods.append( mod )
	}
	return mods
}

array<string> function FreeDM_FFA_ParseWeaponTokens( string varName, string defaultRef )
{
	array<string> tokens
	array<string> raw = split( FreeDM_FFA_PlaylistToken( varName, defaultRef ), " " )
	foreach ( string token in raw )
	{
		string part = strip( token )
		if ( part != "" )
			tokens.append( part )
	}
	return tokens
}

string function FreeDM_FFA_GetLockedSetChoice()
{
	return FreeDM_FFA_PlaylistToken( "ffa_locked_set", "blue" ).tolower()
}

string function FreeDM_FFA_LockedSetSuffixForChoice( string choice )
{
	switch ( choice )
	{
		case "1":
		case "white":
		case "whiteset":
			return WEAPON_LOCKEDSET_SUFFIX_WHITESET
		case "2":
		case "blue":
		case "blueset":
			return WEAPON_LOCKEDSET_SUFFIX_BLUESET
		case "3":
		case "purple":
		case "purpleset":
			return WEAPON_LOCKEDSET_SUFFIX_PURPLESET
		case "4":
		case "gold":
			return WEAPON_LOCKEDSET_SUFFIX_GOLD
	}
	return ""
}

string function FreeDM_FFA_LockedSetModForChoice( string choice )
{
	switch ( choice )
	{
		case "1":
		case "white":
		case "whiteset":
			return WEAPON_LOCKEDSET_MOD_WHITESET
		case "2":
		case "blue":
		case "blueset":
			return WEAPON_LOCKEDSET_MOD_BLUESET
		case "3":
		case "purple":
		case "purpleset":
			return WEAPON_LOCKEDSET_MOD_PURPLESET
		case "4":
		case "gold":
			return WEAPON_LOCKEDSET_MOD_GOLD
	}
	return ""
}

void function FreeDM_FFA_KeepRequestedSights( array<string> mods, array<string> requestedMods, string weaponclass )
{
	array<string> keepSights
	foreach ( string m in requestedMods )
	{
		if ( IsModTypeSight( m, weaponclass ) )
			keepSights.append( m )
	}
	if ( keepSights.len() == 0 )
		return

	for ( int i = mods.len() - 1; i >= 0; i-- )
	{
		if ( IsModTypeSight( mods[i], weaponclass ) )
			mods.remove( i )
	}
	foreach ( string s in keepSights )
		mods.append( s )
}

string function FreeDM_FFA_WeaponClassnameForGive( string ref )
{
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
		return GetBaseWeaponRef( ref )
	return ref
}

#if SERVER
bool function FreeDM_FFA_ShouldGiveForcedWeapons()
{
	if ( !FreeDM_IsFFA() )
		return false
	return GetCurrentPlaylistVarBool( "ffa_force_weapons", false )
}

string function FreeDM_FFA_ArmorRefForLevel( int level )
{
	if ( level <= 0 )
		return ""
	if ( level >= 4 )
	{
		if ( SURVIVAL_Loot_IsRefValid( "armor_pickup_lv4_all_fast" ) )
			return "armor_pickup_lv4_all_fast"
		if ( SURVIVAL_Loot_IsRefValid( "armor_pickup_lv4" ) )
			return "armor_pickup_lv4"
		return "armor_pickup_lv3"
	}

	string ref = "armor_pickup_lv" + string( level )
	if ( SURVIVAL_Loot_IsRefValid( ref ) )
		return ref
	return "armor_pickup_lv2"
}
#endif

void function FreeDM_FFA_PrecacheRef( string ref )
{
	string classname = strip( ref )
	if ( FreeDM_FFA_RefIsNone( classname ) )
		return

	classname = FreeDM_FFA_WeaponClassnameForGive( classname )
	if ( classname == "" )
		return

	try
	{
		PrecacheWeapon( classname )
	}
	catch ( precacheErr )
	{
		printt( "[FreeDM] FFA precache fail " + classname + " " + precacheErr )
	}
}

void function FreeDM_FFA_PrecacheForcedKit()
{
	if ( !FreeDM_IsFFA() )
		return

	array<string> primaryTokens = FreeDM_FFA_ParseWeaponTokens( "ffa_primary", "mp_weapon_r97" )
	array<string> secondaryTokens = FreeDM_FFA_ParseWeaponTokens( "ffa_secondary", "mp_weapon_wingman" )
	if ( primaryTokens.len() > 0 )
		FreeDM_FFA_PrecacheRef( primaryTokens[0] )
	if ( secondaryTokens.len() > 0 )
		FreeDM_FFA_PrecacheRef( secondaryTokens[0] )

	FreeDM_FFA_PrecacheRef( FreeDM_FFA_PlaylistToken( "ffa_tactical_weapon", "" ) )
	FreeDM_FFA_PrecacheRef( FreeDM_FFA_PlaylistToken( "ffa_ultimate_weapon", "" ) )
	FreeDM_FFA_PrecacheRef( FreeDM_FFA_PlaylistToken( "ffa_ordnance", "" ) )

	printt( "[FreeDM] FFA kit disableLoadouts=" + string( GetCurrentPlaylistVarBool( "ffa_disable_loadouts", false ) ) +
		" forceWeapons=" + string( GetCurrentPlaylistVarBool( "ffa_force_weapons", false ) ) +
		" akimbo=" + string( GetCurrentPlaylistVarBool( "ffa_akimbo", false ) ) +
		" lockedSet=" + FreeDM_FFA_GetLockedSetChoice() +
		" primary=" + FreeDM_FFA_PlaylistToken( "ffa_primary", "mp_weapon_r97" ) +
		" secondary=" + FreeDM_FFA_PlaylistToken( "ffa_secondary", "mp_weapon_wingman" ) +
		" armor=" + string( GetCurrentPlaylistVarInt( "ffa_armor_level", 2 ) ) +
		" tac=" + string( GetCurrentPlaylistVarBool( "ffa_give_tactical", true ) ) +
		" ult=" + string( GetCurrentPlaylistVarBool( "ffa_give_ultimate", true ) ) )
}

#if SERVER
entity function FreeDM_FFA_GiveLockedWeapon( entity player, string weaponclass, int slot, array<string> requestedMods )
{
	string classname = weaponclass
	array<string> mods
	foreach ( string m in requestedMods )
		mods.append( m )

	string choice = FreeDM_FFA_GetLockedSetChoice()
	string suffix = FreeDM_FFA_LockedSetSuffixForChoice( choice )
	string setMod = FreeDM_FFA_LockedSetModForChoice( choice )
	array<string> lootTags
	if ( setMod != "" )
		lootTags.append( setMod )
	bool usedKit = false

	if ( SURVIVAL_Loot_IsRefValid( weaponclass ) )
	{
		LootData src = SURVIVAL_Loot_GetLootDataByRef( weaponclass )
		if ( src.lootType == eLootType.MAINWEAPON )
		{
			string base = GetBaseWeaponRef( weaponclass )
			string kitRef = weaponclass
			if ( suffix != "" )
				kitRef = base + suffix

			if ( SURVIVAL_Loot_IsRefValid( kitRef ) )
			{
				LootData ld = SURVIVAL_Loot_GetLootDataByRef( kitRef )
				if ( ld.baseWeapon != "" )
					classname = ld.baseWeapon
				else
					classname = base
				mods = []
				foreach ( string m in ld.baseMods )
				{
					if ( m != "" )
						mods.append( m )
				}
				FreeDM_FFA_KeepRequestedSights( mods, requestedMods, classname )
				foreach ( string m in requestedMods )
				{
					if ( m == "" || mods.contains( m ) )
						continue
					if ( !IsModTypeSight( m, classname ) )
						mods.append( m )
				}
				if ( ld.lootTags.len() > 0 )
					lootTags = ld.lootTags
				usedKit = true
			}
			else
			{
				classname = base
			}
		}
	}

	player.TakeNormalWeaponByIndexNow( slot )

	entity weaponNew = null
	try
	{
		weaponNew = player.GiveWeapon( classname, slot, mods, false )
	}
	catch ( giveErr )
	{
		printt( "[FreeDM] FFA locked-set give failed class=" + classname + " set=" + choice + " " + giveErr )
		weaponNew = null
	}

	if ( !IsValid( weaponNew ) && usedKit )
	{
		try
		{
			weaponNew = player.GiveWeapon( weaponclass, slot, requestedMods, false )
		}
		catch ( giveErr2 )
		{
			weaponNew = null
		}
	}

	if ( IsValid( weaponNew ) && lootTags.len() > 0 )
		SetWeaponLockedSetFromLootTags( lootTags, weaponNew )

	if ( IsValid( weaponNew ) )
	{
		if ( weaponNew.UsesClipsForAmmo() )
			weaponNew.SetWeaponPrimaryClipCount( weaponNew.GetWeaponPrimaryClipCountMax() )
		SetInfiniteAmmoForWeapon( player, weaponNew, true )
		CafeItems_OnWeaponGiven( player, weaponNew )
	}

	return weaponNew
}

void function FreeDM_FFA_GiveSlotFromPlaylist( entity player, string varName, string modsVarName, string defaultRef, int slot )
{
	array<string> tokens = FreeDM_FFA_ParseWeaponTokens( varName, defaultRef )
	if ( tokens.len() == 0 || FreeDM_FFA_RefIsNone( tokens[0] ) )
		return

	string weaponclass = tokens[0]
	array<string> mods
	for ( int i = 1; i < tokens.len(); i++ )
		mods.append( tokens[i] )
	foreach ( string extra in FreeDM_FFA_SplitMods( FreeDM_FFA_PlaylistToken( modsVarName, "" ) ) )
	{
		if ( extra != "" && !mods.contains( extra ) )
			mods.append( extra )
	}

	entity weapon = FreeDM_FFA_GiveLockedWeapon( player, weaponclass, slot, mods )
	if ( !IsValid( weapon ) )
	{
		printt( "[FreeDM] FFA give failed slot=" + string( slot ) + " class=" + weaponclass )
		return
	}

	if ( GetCurrentPlaylistVarBool( "ffa_akimbo", false ) )
		FreeDM_FFA_GiveAkimboPartner( player, weapon )
}

void function FreeDM_FFA_GiveAkimboPartner( entity player, entity weapon )
{
	string classname = weapon.GetWeaponClassName()
	if ( !CanWeaponAkimbo( classname ) )
		return

	int dualslot = weapon.GetInventoryIndex() + WEAPON_INVENTORY_SLOT_DUALPRIMARY_0
	player.TakeNormalWeaponByIndexNow( dualslot )

	entity partner = null
	try
	{
		partner = player.GiveWeapon( classname, dualslot, weapon.GetMods(), false )
	}
	catch ( giveErr )
	{
		printt( "[FreeDM] FFA akimbo partner give failed class=" + classname + " " + giveErr )
		return
	}
	if ( !IsValid( partner ) )
		return

	if ( partner.UsesClipsForAmmo() )
		partner.SetWeaponPrimaryClipCount( partner.GetWeaponPrimaryClipCountMax() )
	SetInfiniteAmmoForWeapon( player, partner, true )
	CafeItems_OnWeaponGiven( player, partner )
	player.ClearFirstDeployForAllWeapons()
	player.SetActiveWeaponBySlot( eActiveInventorySlot.altHand, dualslot )
}

void function FreeDM_FFA_GiveOrdnance( entity player )
{
	string ordnance = FreeDM_FFA_PlaylistToken( "ffa_ordnance", "" )
	if ( FreeDM_FFA_RefIsNone( ordnance ) )
		return

	string classname = FreeDM_FFA_WeaponClassnameForGive( ordnance )
	player.TakeNormalWeaponByIndexNow( WEAPON_INVENTORY_SLOT_ANTI_TITAN )

	entity weapon = null
	try
	{
		weapon = player.GiveWeapon( classname, WEAPON_INVENTORY_SLOT_ANTI_TITAN, [ "survival_finite_ordnance" ], false )
	}
	catch ( giveErr )
	{
		printt( "[FreeDM] FFA ordnance give failed class=" + classname + " " + giveErr )
		return
	}

	if ( IsValid( weapon ) )
		SetInfiniteAmmoForWeapon( player, weapon, true )
}

void function FreeDM_FFA_GiveForcedWeapons( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	FreeDM_FFA_GiveSlotFromPlaylist( player, "ffa_primary", "ffa_primary_mods", "mp_weapon_r97", WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	FreeDM_FFA_GiveSlotFromPlaylist( player, "ffa_secondary", "ffa_secondary_mods", "mp_weapon_wingman", WEAPON_INVENTORY_SLOT_PRIMARY_1 )
	FreeDM_FFA_GiveOrdnance( player )

	entity primary0 = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	entity primary1 = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
	if ( IsValid( primary0 ) )
		player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	else if ( IsValid( primary1 ) )
		player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_1 )

	player.ClearFirstDeployForAllWeapons()
	if ( IsValid( primary0 ) || IsValid( primary1 ) )
		player.DeployWeapon()
}

void function FreeDM_FFA_ApplyArmor( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	int level = GetCurrentPlaylistVarInt( "ffa_armor_level", 2 )
	if ( level <= 0 )
		return

	string ref = FreeDM_FFA_ArmorRefForLevel( level )
	if ( ref == "" || !SURVIVAL_Loot_IsRefValid( ref ) )
		return

	SURVIVAL_GivePlayerEquipment( player, ref, 0, null, "", false )
	LootData data = SURVIVAL_Loot_GetLootDataByRef( ref )
	int shieldMax = SURVIVAL_GetCharacterShieldHealthMaxForArmor( player, data )
	player.SetShieldHealthMax( shieldMax )
	player.SetShieldHealth( shieldMax )
}

void function FreeDM_FFA_ReplaceOffhand( entity player, int slot, string weaponClass )
{
	player.TakeOffhandWeapon( slot )
	if ( FreeDM_FFA_RefIsNone( weaponClass ) )
		return

	string classname = FreeDM_FFA_WeaponClassnameForGive( weaponClass )
	try
	{
		player.GiveOffhandWeapon( classname, slot, [] )
	}
	catch ( giveErr )
	{
		printt( "[FreeDM] FFA offhand give failed slot=" + string( slot ) + " class=" + classname + " " + giveErr )
	}
}

void function FreeDM_FFA_ApplyAbilities( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	bool giveTac = GetCurrentPlaylistVarBool( "ffa_give_tactical", true )
	bool giveUlt = GetCurrentPlaylistVarBool( "ffa_give_ultimate", true )
	string forceTac = FreeDM_FFA_PlaylistToken( "ffa_tactical_weapon", "" )
	string forceUlt = FreeDM_FFA_PlaylistToken( "ffa_ultimate_weapon", "" )

	if ( !giveTac )
		player.TakeOffhandWeapon( OFFHAND_TACTICAL )
	else if ( !FreeDM_FFA_RefIsNone( forceTac ) )
		FreeDM_FFA_ReplaceOffhand( player, OFFHAND_TACTICAL, forceTac )

	if ( !giveUlt )
		player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
	else if ( !FreeDM_FFA_RefIsNone( forceUlt ) )
		FreeDM_FFA_ReplaceOffhand( player, OFFHAND_ULTIMATE, forceUlt )

	if ( giveTac )
	{
		FreeDM_GivePlayerFullTactical( player )
		player.SetSuitGrapplePower( 100 )
	}
}
#endif // SERVER
