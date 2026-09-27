// Lab > Targets: difficulty presets, additive strafer slots, and the saved
// Lab target preferences (Cafe_PlayerPrefs key "lab_targets").

global function AimTrainer_Targets_Init
global function AimTrainer_TargetsCmd
global function AimTrainer_GetStraferSlotCount
global function AimTrainer_EnsureStraferSlots
global function AimTrainer_ClearStraferSlots
global function AimTrainer_RespawnStraferSlots
global function AimTrainer_ApplyPreset
global function AimTrainer_Prefs_MarkDirty

const float STRAFER_SLOT_SPAWN_DIST = 400.0
const float STRAFER_SLOT_SPACING = 96.0
const string LAB_PREFS_KEY = "lab_targets"
const float LAB_PREFS_DEBOUNCE = 2.0

struct StraferSlot
{
	int id
	bool alive = true
	entity target
}

struct
{
	table< int, array<StraferSlot> > slots = {}
	int slotSerial = 0

	table< entity, bool > prefsDirty = {}
	table< entity, bool > prefsFlushRunning = {}
} file

void function AimTrainer_Targets_Init()
{
	AddCallback_OnClientConnected( AimTrainer_Targets_OnClientConnected )
	AddCallback_OnClientDisconnected( AimTrainer_Targets_OnClientDisconnected )
}

void function AimTrainer_Targets_OnClientConnected( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return
	AimTrainer_Prefs_Restore( player )
	AimTrainer_ApplyPreset( player, player.p.aimTrainerPreset, false )
}

void function AimTrainer_Targets_OnClientDisconnected( entity player )
{
	// Disconnect ends the debounce thread before it writes.
	if ( ( player in file.prefsDirty ) && file.prefsDirty[ player ] )
		AimTrainer_Prefs_Flush( player )
	if ( player in file.prefsDirty )
		delete file.prefsDirty[ player ]
	if ( player in file.prefsFlushRunning )
		delete file.prefsFlushRunning[ player ]

	int key = AimTrainer_SlotKey( player )
	if ( key < 0 || !( key in file.slots ) )
		return
	foreach ( StraferSlot slot in file.slots[key] )
		slot.alive = false
	delete file.slots[key]
}

// Returns true when the action belongs here. Difficulty actions only take
// effect under the Custom preset; anything else re-syncs so the UI shows the
// preset's values again.
bool function AimTrainer_TargetsCmd( entity player, string action, array<string> args )
{
	if ( action == "preset" )
	{
		if ( args.len() >= 2 )
			AimTrainer_ApplyPreset( player, AimTrainer_ParseInt( args[1], -1 ), true )
		else
			AimTrainer_SyncDevMenuState( player )
		return true
	}
	if ( action == "strafer_add" )
	{
		AimTrainer_AddStraferSlot( player )
		return true
	}
	if ( action == "strafer_remove" )
	{
		AimTrainer_RemoveStraferSlot( player )
		return true
	}
	if ( action == "strafer_challenge" )
	{
		AimTrainer_StartSlotChallenge( player, AIMTRAINER_FREEROAM_AUTOSPAWN, 1 )
		return true
	}
	if ( action == "manual_challenge" )
	{
		AimTrainer_StartSlotChallenge( player, AIMTRAINER_FREEROAM_MANUAL, 0 )
		return true
	}
	if ( action == "chal_mode" )
	{
		int mode = args.len() >= 2 ? AimTrainer_ParseInt( args[1], -1 ) : -1
		if ( mode >= 0 && mode <= 3 )
			player.p.aimTrainerChallengeMode = mode
		AimTrainer_SyncDevMenuState( player )
		return true
	}

	if ( !AimTrainer_IsTuningAction( action ) )
		return false

	if ( player.p.aimTrainerPreset != AIMTRAINER_PRESET_CUSTOM )
	{
		printt( format( "[AimTrainer] '%s' refused for %s: preset %d is not Custom", action, player.GetPlayerName(), player.p.aimTrainerPreset ) )
		AimTrainer_SyncDevMenuState( player )
		return true
	}

	if ( action == "strafe_speed" )
	{
		if ( args.len() >= 2 )
			DEV_AimTrainer_SetStrafeSpeed( player, float( maxint( 5, minint( 20, AimTrainer_ParseInt( args[1], 10 ) ) ) ) / 10.0 )
	}
	else if ( action == "strafing" )
	{
		DEV_AimTrainer_SetStrafing( player, AimTrainer_ParseSwitch( args, player.p.aimTrainerStrafing ) )
	}
	else if ( action == "bot_health" )
	{
		DEV_AimTrainer_SetStraferInfiniteHealth( player, AimTrainer_ParseSwitch( args, player.p.aimTrainerStraferInfiniteHealth ) )
	}
	else if ( action == "bot_fire" )
	{
		DEV_AimTrainer_SetStraferFire( player, AimTrainer_ParseSwitch( args, player.p.aimTrainerStraferFire ) )
	}
	else if ( action == "bot_aim" )
	{
		if ( args.len() >= 2 )
			DEV_AimTrainer_SetStraferAim( player, AimTrainer_ParseInt( args[1], player.p.aimTrainerStraferAim ) )
	}
	else if ( action == "strafe_time" )
	{
		if ( args.len() >= 3 )
			DEV_AimTrainer_SetStrafeTime( player, AimTrainer_ParseInt( args[1], 0 ), AimTrainer_ParseInt( args[2], 0 ) )
	}
	else if ( action == "armor" )
	{
		if ( args.len() >= 2 )
			DEV_AimTrainer_SetDummyShield( player, AimTrainer_ParseInt( args[1], -1 ) )
	}
	else if ( action == "crouch" )
	{
		int mode = -1
		if ( args.len() >= 2 && [ "0", "1", "2" ].contains( args[1] ) )
			mode = args[1].tointeger()
		DEV_AimTrainer_SetStraferCrouch( player, mode )
	}
	else if ( action == "strafer_hard" )
	{
		AimTrainer_SetStraferHard( player, AimTrainer_ParseSwitch( args, player.p.aimTrainerStraferHard ) )
		AimTrainer_SyncDevMenuState( player )
	}

	AimTrainer_CaptureCustomTuning( player )
	return true
}

bool function AimTrainer_IsTuningAction( string action )
{
	return action == "strafe_speed" || action == "strafing" || action == "bot_health" || action == "bot_fire"
		|| action == "bot_aim" || action == "strafe_time" || action == "armor" || action == "strafer_hard"
		|| action == "crouch"
}

// Digits only, so a garbage argument cannot throw inside the command handler.
int function AimTrainer_ParseInt( string text, int fallback )
{
	if ( !AimTrainer_Prefs_IsIntString( text ) )
		return fallback
	return text.tointeger()
}

void function AimTrainer_CaptureCustomTuning( entity player )
{
	player.p.aimTrainerCustomStrafing = player.p.aimTrainerStrafing
	player.p.aimTrainerCustomTimeMin = player.p.aimTrainerStrafeTimeMin
	player.p.aimTrainerCustomTimeMax = player.p.aimTrainerStrafeTimeMax
	player.p.aimTrainerCustomSpeedTenth = int( player.p.aimTrainerStrafeSpeedMult * 10.0 + 0.5 )
	player.p.aimTrainerCustomArmor = player.p.aimTrainerDummyShield
	player.p.aimTrainerCustomGod = player.p.aimTrainerStraferInfiniteHealth
	player.p.aimTrainerCustomFire = player.p.aimTrainerStraferFire
	player.p.aimTrainerCustomAim = player.p.aimTrainerStraferAim
	player.p.aimTrainerCustomHard = player.p.aimTrainerStraferHard
	player.p.aimTrainerCustomCrouch = player.p.aimTrainerStraferCrouch
}

// Strafe time values are indices into FRDummie_StrafeDurationIndexToSeconds.
// live=false only sets the fields: nothing is spawned yet and nothing else is touched.
void function AimTrainer_ApplyPreset( entity player, int preset, bool live )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( preset < 0 || preset >= AIMTRAINER_PRESET_COUNT )
	{
		printt( format( "[AimTrainer] preset %d rejected for %s", preset, player.GetPlayerName() ) )
		if ( live )
			AimTrainer_SyncDevMenuState( player )
		return
	}

	player.p.aimTrainerPreset = preset
	switch ( preset )
	{
		case AIMTRAINER_PRESET_EASY:
			AimTrainer_ApplyTuning( player, live, true, 12, 12, 10, eDummie_Selector_Shields.WHITE, false, false, 50, false, AIMTRAINER_CROUCH_AUTO )
			break
		case AIMTRAINER_PRESET_MEDIUM:
			AimTrainer_ApplyTuning( player, live, true, 7, 10, 10, eDummie_Selector_Shields.BLUE, false, false, 50, false, AIMTRAINER_CROUCH_AUTO )
			break
		case AIMTRAINER_PRESET_HARD:
			AimTrainer_ApplyTuning( player, live, true, 2, 6, 12, eDummie_Selector_Shields.PURPLE, false, true, 50, true, AIMTRAINER_CROUCH_AUTO )
			break
		case AIMTRAINER_PRESET_TRACKING:
			AimTrainer_ApplyTuning( player, live, true, 12, 15, 12, eDummie_Selector_Shields.RED, true, false, 50, false, AIMTRAINER_CROUCH_OFF )
			if ( live )
				AimTrainer_SetPresetReload( player, false, true, false )
			break
		case AIMTRAINER_PRESET_REACTIVE:
			AimTrainer_ApplyTuning( player, live, true, 4, 7, 13, eDummie_Selector_Shields.RED, true, false, 50, true, AIMTRAINER_CROUCH_AUTO )
			if ( live )
				AimTrainer_SetPresetReload( player, true, false, false )
			break
		case AIMTRAINER_PRESET_CLOSE:
			AimTrainer_ApplyTuning( player, live, true, 0, 3, 15, eDummie_Selector_Shields.PURPLE, false, false, 50, true, AIMTRAINER_CROUCH_ON )
			break
		case AIMTRAINER_PRESET_FLICK:
			AimTrainer_ApplyTuning( player, live, false, 12, 12, 10, eDummie_Selector_Shields.WHITE, false, false, 50, false, AIMTRAINER_CROUCH_OFF )
			break
		case AIMTRAINER_PRESET_DUEL:
			AimTrainer_ApplyTuning( player, live, true, 3, 7, 11, eDummie_Selector_Shields.RED, false, true, 65, true, AIMTRAINER_CROUCH_AUTO )
			if ( live )
				AimTrainer_SetPresetReload( player, false, false, false )
			break
		default:
			AimTrainer_ApplyTuning( player, live, player.p.aimTrainerCustomStrafing, player.p.aimTrainerCustomTimeMin, player.p.aimTrainerCustomTimeMax,
				player.p.aimTrainerCustomSpeedTenth, player.p.aimTrainerCustomArmor, player.p.aimTrainerCustomGod,
				player.p.aimTrainerCustomFire, player.p.aimTrainerCustomAim, player.p.aimTrainerCustomHard, player.p.aimTrainerCustomCrouch )
			break
	}

	printt( format( "[AimTrainer] preset %d applied for %s", preset, player.GetPlayerName() ) )
	if ( live )
		AimTrainer_SyncDevMenuState( player )
}

// Only the drills that need a reload habit pin these; other presets leave them alone.
void function AimTrainer_SetPresetReload( entity player, bool hit, bool shot, bool kill )
{
	player.p.aimTrainerAutoReloadOnHit = hit
	player.p.aimTrainerAutoReloadOnShot = shot
	player.p.aimTrainerAutoReloadOnKill = kill
}

// Live pushes every difficulty value to the player's targets; the caller syncs once.
void function AimTrainer_ApplyTuning( entity player, bool live, bool strafing, int timeMin, int timeMax, int speedTenth, int armor, bool god, bool fire, int aim, bool hard, int crouch )
{
	int lastStep = AIMTRAINER_STRAFE_TIME_STEPS - 1
	if ( !live )
	{
		player.p.aimTrainerStrafing = strafing
		player.p.aimTrainerStrafeTimeMin = maxint( 0, minint( lastStep, minint( timeMin, timeMax ) ) )
		player.p.aimTrainerStrafeTimeMax = maxint( 0, minint( lastStep, maxint( timeMin, timeMax ) ) )
		player.p.aimTrainerStrafeSpeedMult = float( maxint( 5, minint( 20, speedTenth ) ) ) / 10.0
		player.p.aimTrainerDummyShield = armor
		player.p.aimTrainerStraferInfiniteHealth = god
		player.p.aimTrainerStraferFire = fire
		player.p.aimTrainerStraferAim = maxint( 0, minint( 100, aim ) )
		player.p.aimTrainerStraferHard = hard
		player.p.aimTrainerStraferCrouch = crouch
		return
	}
	DEV_AimTrainer_SetStrafing( player, strafing, false )
	DEV_AimTrainer_SetStrafeTime( player, timeMin, timeMax, false )
	DEV_AimTrainer_SetStrafeSpeed( player, float( maxint( 5, minint( 20, speedTenth ) ) ) / 10.0, false )
	DEV_AimTrainer_SetDummyShield( player, armor, false )
	DEV_AimTrainer_SetStraferInfiniteHealth( player, god, false )
	DEV_AimTrainer_SetStraferFire( player, fire, false )
	DEV_AimTrainer_SetStraferAim( player, aim, false )
	DEV_AimTrainer_SetStraferCrouch( player, crouch, false )
	AimTrainer_SetStraferHard( player, hard )
}

void function AimTrainer_SetStraferHard( entity player, bool hard )
{
	if ( player.p.aimTrainerStraferHard == hard )
		return
	player.p.aimTrainerStraferHard = hard
	foreach ( StraferSlot slot in AimTrainer_Slots( player ) )
	{
		if ( IsValid( slot.target ) && slot.target.IsNPC() )
			FlowstateDummy_SetHard( slot.target, player, hard )
	}
	LegendBot_SetHardAll( player )
	printt( format( "[AimTrainer] Strafer brain = %s for %s", hard ? "hard" : "normal", player.GetPlayerName() ) )
}

int function AimTrainer_SlotKey( entity player )
{
	if ( !IsValid( player ) )
		return -1
	return player.GetEncodedEHandle()
}

array<StraferSlot> function AimTrainer_Slots( entity player )
{
	int key = AimTrainer_SlotKey( player )
	if ( key < 0 )
		return []
	if ( !( key in file.slots ) )
		file.slots[key] <- []
	return file.slots[key]
}

int function AimTrainer_GetStraferSlotCount( entity player )
{
	return AimTrainer_Slots( player ).len()
}

bool function AimTrainer_AddStraferSlot( entity player )
{
	array<StraferSlot> slots = AimTrainer_Slots( player )
	if ( slots.len() >= AIMTRAINER_MAX_STRAFER_SLOTS )
	{
		LocalEventMsg( player, "#LAB_TARGETS_STRAFER_CAP" )
		AimTrainer_SyncDevMenuState( player )
		return false
	}

	AimTrainer_EnterMode( player )
	StraferSlot slot
	file.slotSerial++
	slot.id = file.slotSerial
	slots.append( slot )
	thread AimTrainer_StraferSlotThread( player, slot )

	printt( format( "[AimTrainer] strafer slot %d added for %s (%d live)", slot.id, player.GetPlayerName(), slots.len() ) )
	AimTrainer_SyncDevMenuState( player )
	return true
}

void function AimTrainer_RemoveStraferSlot( entity player )
{
	array<StraferSlot> slots = AimTrainer_Slots( player )
	if ( slots.len() > 0 )
	{
		StraferSlot slot = slots.pop()
		slot.alive = false
		AimTrainer_DespawnTarget( player, slot.target )
		printt( format( "[AimTrainer] strafer slot %d removed for %s (%d live)", slot.id, player.GetPlayerName(), slots.len() ) )
	}
	AimTrainer_SyncDevMenuState( player )
}

void function AimTrainer_EnsureStraferSlots( entity player, int count )
{
	int want = minint( count, AIMTRAINER_MAX_STRAFER_SLOTS )
	while ( AimTrainer_GetStraferSlotCount( player ) < want )
	{
		if ( !AimTrainer_AddStraferSlot( player ) )
			return
	}
}

// Ends every slot; callers destroy the targets through their own despawn path.
void function AimTrainer_ClearStraferSlots( entity player )
{
	int key = AimTrainer_SlotKey( player )
	if ( key < 0 || !( key in file.slots ) )
		return
	foreach ( StraferSlot slot in file.slots[key] )
		slot.alive = false
	file.slots[key] = []
}

// Each slot thread spawns a replacement with the owner's current settings.
void function AimTrainer_RespawnStraferSlots( entity player )
{
	foreach ( StraferSlot slot in AimTrainer_Slots( player ) )
		AimTrainer_DespawnTarget( player, slot.target )
}

// A timed run on the owner's slots. Manual keeps whatever count the player
// built; the strafer run needs at least one.
void function AimTrainer_StartSlotChallenge( entity player, int mode, int minSlots )
{
	int count = maxint( AimTrainer_GetStraferSlotCount( player ), minSlots )
	AimTrainer_StopPlayerSession( player )
	player.p.aimTrainerFreeroamMode = mode
	AimTrainer_BeginTimedChallenge( player, true )
	AimTrainer_EnsureStraferSlots( player, count )
	printt( format( "[AimTrainer] slot challenge mode=%d slots=%d for %s", mode, count, player.GetPlayerName() ) )
}

int function AimTrainer_SlotIndex( entity player, StraferSlot slot )
{
	array<StraferSlot> slots = AimTrainer_Slots( player )
	for ( int i = 0; i < slots.len(); i++ )
	{
		if ( slots[i].id == slot.id )
			return i
	}
	return 0
}

void function AimTrainer_StraferSlotThread( entity player, StraferSlot slot )
{
	player.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( slot )
		{
			slot.alive = false
		}
	)

	AimTrainer_WaitForIntro( player )

	while ( slot.alive )
	{
		if ( !IsAlive( player ) || AimTrainer_GetBudgetRemaining() <= 0 )
		{
			wait 0.5
			continue
		}

		entity target = AimTrainer_SpawnSlotTarget( player, slot )
		if ( !slot.alive )
		{
			AimTrainer_DespawnTarget( player, target )
			return
		}
		if ( !IsValid( target ) )
		{
			wait 0.5
			continue
		}

		slot.target = target
		WaitSignal( target, "OnDeath", "OnDestroy" )
		wait 0.2
	}
}

// Slots after the first fan out sideways from the spawn point so targets never
// stack; every spot is still validated by the spawn path.
entity function AimTrainer_SpawnSlotTarget( entity player, StraferSlot slot )
{
	bool legend = LegendBot_GetBodyIsLegend( player )
	bool fixedSpawn = player.p.aimTrainerFixedSpawn
	vector base = fixedSpawn ? player.p.aimTrainerFixedSpawnPos : AimTrainer_ViewSpot( player, STRAFER_SLOT_SPAWN_DIST, !legend )

	vector toOwner = player.GetOrigin() - base
	toOwner.z = 0.0
	float dist = Length( toOwner )
	toOwner = dist > 1.0 ? toOwner / dist : AnglesToForward( <0, player.EyeAngles().y, 0> ) * -1.0
	vector right = CrossProduct( toOwner, <0, 0, 1> )

	int index = AimTrainer_SlotIndex( player, slot )
	float side = ( index % 2 == 1 ) ? 1.0 : -1.0
	vector want = base + right * ( float( ( index + 1 ) / 2 ) * STRAFER_SLOT_SPACING * side )
	vector angles = <0, VectorToAngles( player.GetOrigin() - want ).y, 0>
	int shield = AimTrainer_ResolveDummyShieldLevel( player )

	if ( legend )
		return LegendBot_Spawn( player, LegendBot_GetStoredCharRef( player ), want, angles, shield, !fixedSpawn )
	return FlowstateDummy_SpawnStrafer( player, want, angles, shield, player.p.aimTrainerStraferHard, !fixedSpawn )
}

bool function AimTrainer_Prefs_IsIntString( string s )
{
	if ( s.len() < 1 || s.len() > 6 )
		return false
	int start = ( s.slice( 0, 1 ) == "-" ) ? 1 : 0
	if ( start >= s.len() )
		return false
	for ( int i = start; i < s.len(); i++ )
	{
		string ch = s.slice( i, i + 1 )
		if ( ch < "0" || ch > "9" )
			return false
	}
	return true
}

string function AimTrainer_Prefs_Build( entity player )
{
	string out = "v=1\n"
	out += "i.preset=" + string( player.p.aimTrainerPreset ) + "\n"
	out += "b.custom.strafing=" + ( player.p.aimTrainerCustomStrafing ? "1" : "0" ) + "\n"
	out += "i.custom.time_min=" + string( player.p.aimTrainerCustomTimeMin ) + "\n"
	out += "i.custom.time_max=" + string( player.p.aimTrainerCustomTimeMax ) + "\n"
	out += "i.custom.speed=" + string( player.p.aimTrainerCustomSpeedTenth ) + "\n"
	out += "i.custom.armor=" + string( player.p.aimTrainerCustomArmor ) + "\n"
	out += "b.custom.god=" + ( player.p.aimTrainerCustomGod ? "1" : "0" ) + "\n"
	out += "b.custom.fire=" + ( player.p.aimTrainerCustomFire ? "1" : "0" ) + "\n"
	out += "i.custom.aim=" + string( player.p.aimTrainerCustomAim ) + "\n"
	out += "b.custom.hard=" + ( player.p.aimTrainerCustomHard ? "1" : "0" ) + "\n"
	out += "i.custom.crouch=" + string( player.p.aimTrainerCustomCrouch ) + "\n"
	out += "b.legend_body=" + ( LegendBot_GetBodyIsLegend( player ) ? "1" : "0" ) + "\n"
	// Refs are validated against the character list, so no line breaks can ride in.
	string ref = LegendBot_GetStoredCharRef( player )
	if ( ref != "" && LegendBot_SortedVisibleRefs().contains( ref ) )
		out += "s.legend=" + ref + "\n"
	out += "b.highlight=" + ( player.p.aimTrainerTargetHighlight ? "1" : "0" ) + "\n"
	out += "b.healthbars=" + ( player.p.aimTrainerReconHealthBars ? "1" : "0" ) + "\n"
	out += "b.reload_hit=" + ( player.p.aimTrainerAutoReloadOnHit ? "1" : "0" ) + "\n"
	out += "b.reload_shot=" + ( player.p.aimTrainerAutoReloadOnShot ? "1" : "0" ) + "\n"
	out += "b.reload_kill=" + ( player.p.aimTrainerAutoReloadOnKill ? "1" : "0" ) + "\n"
	out += "i.duration=" + string( player.p.aimTrainerChallengeDurationSec ) + "\n"
	out += "i.chal_mode=" + string( player.p.aimTrainerChallengeMode ) + "\n"
	return out
}

void function AimTrainer_Prefs_Flush( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	player.Cafe_PlayerPrefs_Write( LAB_PREFS_KEY, AimTrainer_Prefs_Build( player ) )
}

void function AimTrainer_Prefs_FlushThread( entity player )
{
	player.EndSignal( "OnDestroy" )

	while ( ( player in file.prefsDirty ) && file.prefsDirty[ player ] )
	{
		file.prefsDirty[ player ] = false
		wait LAB_PREFS_DEBOUNCE
		AimTrainer_Prefs_Flush( player )
	}

	file.prefsFlushRunning[ player ] <- false
}

// Disk writes run on the server frame thread, so setters only mark; one
// debounced flush covers a burst of menu changes.
void function AimTrainer_Prefs_MarkDirty( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return

	file.prefsDirty[ player ] <- true
	if ( !( player in file.prefsFlushRunning ) || !file.prefsFlushRunning[ player ] )
	{
		file.prefsFlushRunning[ player ] <- true
		thread AimTrainer_Prefs_FlushThread( player )
	}
}

// Unknown keys and out-of-range values are skipped; the field keeps its default.
void function AimTrainer_Prefs_Restore( entity player )
{
	string payload = player.Cafe_PlayerPrefs_Read( LAB_PREFS_KEY )
	if ( payload == "" || payload.len() > 4096 )
		return

	array<string> lines = split( payload, "\n" )
	if ( lines.len() < 1 || strip( lines[0] ) != "v=1" )
		return

	bool legendBody = LegendBot_GetBodyIsLegend( player )
	string legendRef = LegendBot_GetStoredCharRef( player )
	int applied = 0

	for ( int n = 1; n < lines.len() && n < 64; n++ )
	{
		string line = strip( lines[n] )
		int eq = line.find( "=" )
		if ( line.len() < 3 || line.slice( 0, 1 ) == "#" || eq < 0 )
			continue

		string key = line.slice( 0, eq )
		string val = line.slice( eq + 1, line.len() )

		if ( key == "s.legend" )
		{
			legendRef = val
			applied++
			continue
		}
		if ( !AimTrainer_Prefs_IsIntString( val ) )
			continue

		int v = val.tointeger()
		bool on = v != 0
		bool known = true
		switch ( key )
		{
			case "i.preset":
				if ( v >= 0 && v < AIMTRAINER_PRESET_COUNT )
					player.p.aimTrainerPreset = v
				break
			case "b.custom.strafing":
				player.p.aimTrainerCustomStrafing = on
				break
			case "i.custom.time_min":
				if ( v >= 0 && v < AIMTRAINER_STRAFE_TIME_STEPS )
					player.p.aimTrainerCustomTimeMin = v
				break
			case "i.custom.time_max":
				if ( v >= 0 && v < AIMTRAINER_STRAFE_TIME_STEPS )
					player.p.aimTrainerCustomTimeMax = v
				break
			case "i.custom.speed":
				if ( v >= 5 && v <= 20 )
					player.p.aimTrainerCustomSpeedTenth = v
				break
			case "i.custom.armor":
				if ( v == eDummie_Selector_Shields.WHITE || v == eDummie_Selector_Shields.BLUE || v == eDummie_Selector_Shields.PURPLE
					|| v == eDummie_Selector_Shields.RED || v == eDummie_Selector_Shields.RANDOM )
					player.p.aimTrainerCustomArmor = v
				break
			case "b.custom.god":
				player.p.aimTrainerCustomGod = on
				break
			case "b.custom.fire":
				player.p.aimTrainerCustomFire = on
				break
			case "i.custom.aim":
				if ( v >= 0 && v <= 100 )
					player.p.aimTrainerCustomAim = v
				break
			case "b.custom.hard":
				player.p.aimTrainerCustomHard = on
				break
			case "b.legend_body":
				legendBody = on
				break
			case "b.highlight":
				player.p.aimTrainerTargetHighlight = on
				break
			case "i.custom.crouch":
				if ( v >= AIMTRAINER_CROUCH_AUTO && v <= AIMTRAINER_CROUCH_ON )
					player.p.aimTrainerCustomCrouch = v
				break
			case "b.healthbars":
				player.p.aimTrainerReconHealthBars = on
				break
			case "b.reload_hit":
				player.p.aimTrainerAutoReloadOnHit = on
				break
			case "b.reload_shot":
				player.p.aimTrainerAutoReloadOnShot = on
				break
			case "b.reload_kill":
				player.p.aimTrainerAutoReloadOnKill = on
				break
			case "i.duration":
				if ( v == 30 || v == 60 || v == 90 || v == 120 || v == AIMTRAINER_CHALLENGE_DURATION_UNLIMITED )
					player.p.aimTrainerChallengeDurationSec = v
				break
			case "i.chal_mode":
				if ( v >= 0 && v <= 3 )
					player.p.aimTrainerChallengeMode = v
				break
			default:
				known = false
				break
		}
		if ( known )
			applied++
	}

	LegendBot_RestorePrefs( player, legendBody, legendRef )
	printt( format( "[AimTrainer] Lab prefs restored for %s (%d values)", player.GetPlayerName(), applied ) )
}
