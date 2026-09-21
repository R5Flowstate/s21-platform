// Shared movement-recorder helpers (recordings and playback live in fs_movement_recorder).

#if SERVER
	global function MovementRecorder_GetPlayerActiveWeaponData
	global function MovementRecorder_ApplyWeaponToDummy
	global function MovementRecorder_PlayerKey
#endif

global function MovementRecorder_GetPlayerCharacterRef
global function MovementRecorder_GetDummyAISettingsFromCharacterRef

// GiveWeapon/SpinOff can run player-only weapon callbacks on CAI_BaseNPC.
const bool MOVEMENT_RECORDER_GIVE_DUMMY_WEAPONS = false

#if SERVER
int function MovementRecorder_PlayerKey( entity player )
{
	return player.GetEncodedEHandle()
}

table ornull function MovementRecorder_GetPlayerActiveWeaponData( entity player )
{
	if ( !IsValid( player ) )
		return null

	entity weapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( !IsValid( weapon ) )
		return null

	string weaponName = weapon.GetWeaponClassName()
	if ( weaponName == "" )
		return null

	table data = {}
	data[ "name" ] <- weaponName
	return data
}

void function MovementRecorder_ApplyWeaponToDummy( entity dummy, table ornull weaponData )
{
	if ( !MOVEMENT_RECORDER_GIVE_DUMMY_WEAPONS )
		return

	if ( !IsValid( dummy ) || weaponData == null )
		return

	table wd = expect table( weaponData )
	if ( !( "name" in wd ) )
		return

	string weaponName = string( wd[ "name" ] )
	if ( weaponName == "" )
		return

	entity givenWeapon = dummy.GiveWeapon( weaponName, WEAPON_INVENTORY_SLOT_ANY )
	if ( IsValid( givenWeapon ) )
		dummy.SetActiveWeaponByName( eActiveInventorySlot.mainHand, weaponName )
}
#endif // SERVER

string function MovementRecorder_GetPlayerCharacterRef( entity player )
{
	if ( !IsValid( player ) )
		return "character_wraith"

	ItemFlavor character = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() )
	return ItemFlavor_GetCharacterRef( character )
}

// character_wraith -> npc_dummie_wraith (legend AI settings / pilot model).
string function MovementRecorder_GetDummyAISettingsFromCharacterRef( string characterRef )
{
	if ( characterRef == "" )
		return "npc_dummie_wraith"

	string aiName = characterRef
	const string prefix = "character_"
	if ( aiName.find( prefix ) == 0 )
		aiName = aiName.slice( prefix.len() )

	if ( aiName == "" )
		aiName = "wraith"

	// Only legends with an npc_dummie_<name> aisettings file on this build.
	array<string> known = [ "ash", "ballistic", "bangalore", "bloodhound", "catalyst", "caustic", "crypto", "gibby", "horizon", "lifeline", "loba", "mirage", "octane", "pathfinder", "rampart", "revenant", "valkyrie", "wattson", "wraith" ]
	if ( aiName == "gibraltar" )
		aiName = "gibby"
	if ( !known.contains( aiName ) )
		return ""

	return "npc_dummie_" + aiName
}
