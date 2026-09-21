// Aim trainer legend strafer bots: fake players wearing a legend, driven by BotCmd_Strafe.

global function LegendBot_Spawn
global function LegendBot_StartStrafe
global function LegendBot_Kick
global function LegendBot_KickAll
global function LegendBot_DespawnAllWithFX
global function LegendBot_Count
global function LegendBot_GetBodyIsLegend
global function LegendBot_GetStoredCharRef
global function LegendBot_GetLegendIdx
global function LegendBot_SetBody
global function LegendBot_SetLegend
global function LegendBot_AutospawnLoop
global function AimTrainer_LegendBots_Init
global function LegendBot_IsBot
global function LegendBot_SetGodAll
global function LegendBot_ApplyHighlightAll
global function LegendBot_Place
global function LegendBot_SetArmorAll
global function LegendBot_SetStrafeSpeedAll
global function LegendBot_OnOwnerDisconnected
global function LegendBot_StrafeHalfWidth
global function LegendBot_SetFireAll
global function LegendBot_SetAimAll
global function LegendBot_CrosshairSpot
global function LegendBot_SetStrafeWidthAll

const string LEGENDBOT_NAME_PREFIX = "R5F-"
const int LEGENDBOT_KILL_HEAL = 50
const float LEGENDBOT_AUTOSPAWN_DIST = 400.0
const float LEGENDBOT_DESPAWN_FX_HOLD = 0.6
const float LEGENDBOT_CORPSE_LINGER = 0.5
const float LEGENDBOT_LANE_PROBE = 256.0
const float LEGENDBOT_LANE_MIN = 96.0
const float LEGENDBOT_LANE_STEP_HEIGHT = 18.0
const float LEGENDBOT_SPOT_BACKOFF = 64.0
const float LEGENDBOT_SPOT_MIN_DIST = 96.0
const int LEGENDBOT_SPOT_TRIES = 6
const float LEGENDBOT_AIM_ERROR_WORST_DEG = 10.0
const float LEGENDBOT_AIM_ERROR_BEST_DEG = 0.3
const float LEGENDBOT_FIRE_THINK = 0.1
const float LEGENDBOT_REACTION_MIN = 0.15
const float LEGENDBOT_REACTION_MAX = 0.4
const float LEGENDBOT_RELOAD_SETTLE_MIN = 0.15
const float LEGENDBOT_RELOAD_SETTLE_MAX = 0.45
const float LEGENDBOT_BURST_GAP = 0.25
const int BOTFIRE_HOLD = 0
const int BOTFIRE_TAP = 1
const int BOTFIRE_BURST = 2

struct LegendBotSpot
{
	vector origin
	float halfLane
	bool ok
}

struct LegendStraferPrefs
{
	string body
	string charRef
}

struct
{
	table<int, LegendStraferPrefs> prefs = {}
	table<int, array<entity> > bots = {}
	table<int, entity> ownerOf = {}
	table<int, bool> god = {}
	table<int, float> lastDamaged = {}
	table<entity, float> lane = {}
	table<entity, float> laneFit = {}
	int botSerial = 0
} file

void function AimTrainer_LegendBots_Init()
{
	RegisterSignal( "LegendBot_FireLoop" )
	AddCallback_OnPlayerKilled( LegendBot_OnPlayerKilled )
	AddPostDamageCallback( "player", LegendBot_OnPlayerPostDamaged )
	printt( "[LegendBot] Init" )
}

bool function LegendBot_IsBot( entity ent )
{
	if ( !IsValid( ent ) || !ent.IsPlayer() || !ent.IsBot() )
		return false
	string name = ent.GetPlayerName()
	return name.find( LEGENDBOT_NAME_PREFIX ) == 0 || name.find( "REC-" ) == 0
}

int function LegendBot_KeyOf( entity ent )
{
	try
	{
		return ent.GetEncodedEHandle()
	}
	catch ( eKey )
	{
	}
	return -1
}

entity function LegendBot_OwnerOf( entity bot )
{
	int key = LegendBot_KeyOf( bot )
	if ( key < 0 || !( key in file.ownerOf ) )
		return null
	entity owner = file.ownerOf[key]
	return IsValid( owner ) ? owner : null
}

// A killed bot counts like a killed dummy: auto reload on kill and the
// client kill hook that feeds the challenge score.
void function LegendBot_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !LegendBot_IsBot( victim ) )
		return
	if ( !IsValid( attacker ) || !attacker.IsPlayer() || attacker.IsBot() )
		return
	try
	{
		AimTrainer_OnTrainingDummyKilled( attacker )
	}
	catch ( eKill )
	{
	}
	if ( LegendBot_OwnerOf( victim ) == attacker && attacker.p.aimTrainerStraferFire )
		LegendBot_RewardKill( attacker )
	if ( victim.GetPlayerName().find( LEGENDBOT_NAME_PREFIX ) == 0 )
		thread LegendBot_KickAfter( victim, LEGENDBOT_CORPSE_LINGER )
}

// Strafers that shoot back cost health, so each one killed gives some back:
// health first, shield once health is full.
void function LegendBot_RewardKill( entity player )
{
	if ( !IsAlive( player ) )
		return

	int heal = LEGENDBOT_KILL_HEAL
	int hp = player.GetHealth()
	int maxHp = player.GetMaxHealth()
	if ( hp < maxHp )
	{
		int give = minint( heal, maxHp - hp )
		player.SetHealth( hp + give )
		heal -= give
	}
	if ( heal <= 0 )
		return

	int shield = player.GetShieldHealth()
	int maxShield = player.GetShieldHealthMax()
	if ( shield < maxShield )
		player.SetShieldHealth( minint( maxShield, shield + heal ) )
}

void function LegendBot_KickAfter( entity bot, float delay )
{
	wait delay
	if ( IsValid( bot ) )
		LegendBot_Kick( bot )
}

// Strafer infinite health for fake players: keep them at 1 HP under fire and
// refill once they have been left alone, mirroring the NPC strafer regen.
void function LegendBot_OnPlayerPostDamaged( entity victim, var damageInfo )
{
	if ( !LegendBot_IsBot( victim ) )
		return
	int key = LegendBot_KeyOf( victim )
	if ( key < 0 || !( key in file.god ) || !file.god[key] )
		return
	file.lastDamaged[key] <- Time()
	try
	{
		if ( victim.GetHealth() < 1 )
			victim.SetHealth( 1 )
	}
	catch ( eHp )
	{
	}
}

void function LegendBot_GodRegenThread( entity bot )
{
	bot.EndSignal( "OnDestroy" )
	bot.EndSignal( "OnDeath" )
	int key = LegendBot_KeyOf( bot )
	if ( key < 0 )
		return
	while ( IsValid( bot ) )
	{
		wait 0.1
		if ( !( key in file.god ) || !file.god[key] )
			return
		float last = ( key in file.lastDamaged ) ? file.lastDamaged[key] : 0.0
		if ( Time() - last < AIMTRAINER_STRAFER_GOD_REGEN_IDLE )
			continue
		try
		{
			int maxHp = bot.GetMaxHealth()
			if ( bot.GetHealth() < maxHp )
				bot.SetHealth( maxHp )
			int maxShield = bot.GetShieldHealthMax()
			if ( maxShield > 0 && bot.GetShieldHealth() < maxShield )
				bot.SetShieldHealth( maxShield )
		}
		catch ( eRegen )
		{
		}
	}
}

void function LegendBot_SetGod( entity bot, bool on )
{
	int key = LegendBot_KeyOf( bot )
	if ( key < 0 )
		return
	bool was = ( key in file.god ) && file.god[key]
	file.god[key] <- on
	if ( on && !was && IsValid( bot ) )
		thread LegendBot_GodRegenThread( bot )
}

void function LegendBot_SetGodAll( entity owner, bool on )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
		LegendBot_SetGod( bot, on )
}

void function LegendBot_ApplyHighlightAll( entity owner )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
		AimTrainer_ApplyTargetHighlight( owner, bot )
}

void function LegendBot_SetArmorAll( entity owner, int shieldLevel )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( !IsValid( bot ) || !IsAlive( bot ) )
			continue
		if ( shieldLevel <= 0 )
		{
			try
			{
				Inventory_SetPlayerEquipment( bot, "", "armor" )
				bot.SetShieldHealth( 0 )
			}
			catch ( eNone )
			{
			}
			continue
		}
		LegendBot_ApplyArmor( bot, shieldLevel )
	}
}

void function LegendBot_OnOwnerDisconnected( entity owner )
{
	LegendBot_KickAll( owner )
	int key = LegendBot_KeyOf( owner )
	if ( key >= 0 && key in file.prefs )
		delete file.prefs[key]
}

LegendStraferPrefs function LegendBot_GetPrefs( entity player )
{
	int key = -1
	try
	{
		key = player.GetEncodedEHandle()
	}
	catch ( eKey )
	{
		LegendStraferPrefs fallback
		fallback.body = "dummy"
		fallback.charRef = ""
		return fallback
	}
	if ( !( key in file.prefs ) )
	{
		LegendStraferPrefs p
		p.body = "dummy"
		p.charRef = ""
		file.prefs[key] <- p
	}
	return file.prefs[key]
}

bool function LegendBot_GetBodyIsLegend( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return false
	int key = -1
	try
	{
		key = player.GetEncodedEHandle()
	}
	catch ( eKey )
	{
		return false
	}
	if ( !( key in file.prefs ) )
		return false
	return file.prefs[key].body == "legend"
}

string function LegendBot_GetStoredCharRef( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return ""
	int key = -1
	try
	{
		key = player.GetEncodedEHandle()
	}
	catch ( eKey )
	{
		return ""
	}
	if ( !( key in file.prefs ) )
		return ""
	return file.prefs[key].charRef
}

array<string> function LegendBot_SortedVisibleRefs()
{
	array<string> refs = []
	try
	{
		foreach ( ItemFlavor character in GetAllCharacters() )
		{
			string ref = ""
			try
			{
				ref = ItemFlavor_GetCharacterRef( character )
			}
			catch ( eRef )
			{
				continue
			}
			if ( ref == "" || refs.contains( ref ) )
				continue
			if ( HIDDEN_CHARACTER_REFS.len() > 0 && HIDDEN_CHARACTER_REFS.contains( ref ) )
				continue
			refs.append( ref )
		}
	}
	catch ( eChars )
	{
	}
	refs.sort()
	return refs
}

int function LegendBot_GetLegendIdx( entity player )
{
	string want = LegendBot_GetStoredCharRef( player )
	if ( want == "" )
		return -1
	array<string> refs = LegendBot_SortedVisibleRefs()
	for ( int i = 0; i < refs.len(); i++ )
	{
		if ( refs[i] == want )
			return i
	}
	return -1
}

void function LegendBot_SetBody( entity player, string v )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	string want = v.tolower()
	if ( want != "dummy" && want != "legend" )
	{
		printt( format( "[LegendBot] SetBody reject '%s' from %s", v, player.GetPlayerName() ) )
		return
	}
	LegendStraferPrefs p = LegendBot_GetPrefs( player )
	p.body = want
	printt( format( "[LegendBot] Strafer body = %s for %s", want, player.GetPlayerName() ) )
	try
	{
		AimTrainer_SyncDevMenuState( player )
	}
	catch ( eSync )
	{
	}
}

void function LegendBot_SetLegend( entity player, string v )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	string want = v.tolower()
	LegendStraferPrefs p = LegendBot_GetPrefs( player )
	if ( want == "same" )
	{
		p.charRef = ""
		printt( format( "[LegendBot] Strafer legend = same for %s", player.GetPlayerName() ) )
		try
		{
			AimTrainer_SyncDevMenuState( player )
		}
		catch ( eSync )
		{
		}
		return
	}
	string match = ""
	try
	{
		foreach ( ItemFlavor character in GetAllCharacters() )
		{
			if ( ItemFlavor_GetCharacterRef( character ) == want )
			{
				match = want
				break
			}
		}
	}
	catch ( eChars )
	{
	}
	if ( match == "" )
	{
		printt( format( "[LegendBot] SetLegend reject '%s' from %s", v, player.GetPlayerName() ) )
		return
	}
	p.charRef = match
	printt( format( "[LegendBot] Strafer legend = %s for %s", match, player.GetPlayerName() ) )
	try
	{
		AimTrainer_SyncDevMenuState( player )
	}
	catch ( eSync )
	{
	}
}

int function LegendBot_PickTeam( entity player )
{
	int myTeam = TEAM_IMC
	try
	{
		myTeam = player.GetTeam()
	}
	catch ( eTeam )
	{
		return TEAM_MILITIA
	}
	if ( Is2TeamPvPGame() )
		return GetEnemyTeam( myTeam )
	if ( myTeam >= TEAM_MULTITEAM_FIRST )
	{
		int maxTeams = GetCurrentPlaylistVarInt( "max_teams", MAX_TEAMS )
		int team = myTeam + 1
		if ( team >= TEAM_MULTITEAM_FIRST + maxTeams )
			team = TEAM_MULTITEAM_FIRST
		if ( team == myTeam )
			team = myTeam + 1
		return team
	}
	return myTeam == TEAM_IMC ? TEAM_MILITIA : TEAM_IMC
}

void function LegendBot_Kick( entity bot )
{
	if ( !IsValid( bot ) || !bot.IsPlayer() || !bot.IsBot() )
		return
	string name = ""
	try
	{
		name = bot.GetPlayerName()
	}
	catch ( eName )
	{
		return
	}
	if ( name.find( LEGENDBOT_NAME_PREFIX ) != 0 )
		return
	bool kicked = false
	try
	{
		kicked = bot.BotCmd_Kick()
	}
	catch ( eKick )
	{
		kicked = false
	}
	if ( !kicked )
	{
		try
		{
			ServerCommand( "kick \"" + name + "\"" )
		}
		catch ( eCmd )
		{
		}
	}
}

void function LegendBot_Track( entity owner, entity bot )
{
	int key = -1
	try
	{
		key = owner.GetEncodedEHandle()
	}
	catch ( eKey )
	{
		return
	}
	if ( !( key in file.bots ) )
		file.bots[key] <- []
	file.bots[key].append( bot )
	int botKey = LegendBot_KeyOf( bot )
	if ( botKey >= 0 )
		file.ownerOf[botKey] <- owner
	MRec_BindBotRealms( bot, owner )
	AimTrainer_ApplyTargetHighlight( owner, bot )
	if ( IsValid( owner ) && owner.p.aimTrainerStraferInfiniteHealth )
		LegendBot_SetGod( bot, true )
}

void function LegendBot_Prune( int key )
{
	if ( !( key in file.bots ) )
		return
	array<entity> keep = []
	foreach ( entity bot in file.bots[key] )
	{
		if ( IsValid( bot ) )
			keep.append( bot )
	}
	file.bots[key] = keep
	foreach ( entity bot, float half in clone file.lane )
	{
		if ( !IsValid( bot ) )
			delete file.lane[bot]
	}
	foreach ( entity bot, float half in clone file.laneFit )
	{
		if ( !IsValid( bot ) )
			delete file.laneFit[bot]
	}
}

int function LegendBot_Count( entity owner )
{
	int key = -1
	try
	{
		key = owner.GetEncodedEHandle()
	}
	catch ( eKey )
	{
		return 0
	}
	LegendBot_Prune( key )
	if ( !( key in file.bots ) )
		return 0
	return file.bots[key].len()
}

void function LegendBot_KickAll( entity owner )
{
	int key = -1
	try
	{
		key = owner.GetEncodedEHandle()
	}
	catch ( eKey )
	{
		return
	}
	if ( !( key in file.bots ) )
		return
	array<entity> kill = file.bots[key]
	file.bots[key] = []
	foreach ( entity bot in kill )
	{
		if ( !IsValid( bot ) )
			continue
		try
		{
			bot.BotCmd_Stop()
		}
		catch ( eStop )
		{
		}
		LegendBot_Kick( bot )
	}
}

// Challenge-end despawn: the same conduit pulse the NPC dummies get, then the
// bot leaves. Players cannot dissolve, so the kick stands in for the destroy.
void function LegendBot_DespawnAllWithFX( entity owner )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	array<entity> gone = file.bots[key]
	file.bots[key] = []
	foreach ( entity bot in gone )
	{
		if ( !IsValid( bot ) )
			continue
		try
		{
			bot.BotCmd_Stop()
		}
		catch ( eStop )
		{
		}
		if ( IsValid( owner ) && IsAlive( bot ) )
		{
			try
			{
				AimTrainer_SpawnConduitBeamToTarget( owner, bot )
			}
			catch ( eBeam )
			{
			}
		}
		thread LegendBot_KickAfter( bot, LEGENDBOT_DESPAWN_FX_HOLD )
	}
}

string function LegendBot_ArmorRefForShieldLevel( int level )
{
	array<string> cands = []
	if ( level == 1 )
		cands = [ "armor_core_pickup_lv1", "armor_pickup_lv1" ]
	else if ( level == 2 )
		cands = [ "armor_core_pickup_lv2", "armor_pickup_lv2" ]
	else if ( level == 3 )
		cands = [ "armor_core_pickup_lv3", "armor_pickup_lv3" ]
	else if ( level >= 4 )
		cands = [ "armor_pickup_lv4_all_fast", "armor_pickup_lv5_evolving", "armor_core_pickup_lv3", "armor_pickup_lv3" ]
	else
		return ""
	foreach ( string ref in cands )
	{
		bool valid = false
		try
		{
			valid = SURVIVAL_Loot_IsRefValid( ref )
		}
		catch ( eValid )
		{
			valid = false
		}
		if ( valid )
			return ref
	}
	return ""
}

void function LegendBot_ApplyArmor( entity bot, int shieldLevel )
{
	if ( !IsValid( bot ) || shieldLevel <= 0 )
		return
	string ref = LegendBot_ArmorRefForShieldLevel( shieldLevel )
	if ( ref == "" )
		return
	try
	{
		Inventory_SetPlayerEquipment( bot, ref, "armor" )
	}
	catch ( eEq )
	{
		return
	}
	if ( !IsValid( bot ) )
		return
	try
	{
		LootData ld = SURVIVAL_Loot_GetLootDataByRef( ref )
		bot.SetShieldHealth( SURVIVAL_GetArmorShieldCapacity( ld.tier ) )
	}
	catch ( eSh )
	{
	}
}

entity function LegendBot_Spawn( entity owner, string charRef, vector origin, vector yawAngles, int shieldLevel )
{
	if ( !IsValid( owner ) || !owner.IsPlayer() )
		return null
	int maxPlayers = 60
	try
	{
		maxPlayers = GetCurrentPlaylistVarInt( "max_players", 60 )
	}
	catch ( eMax )
	{
	}
	int used = 0
	try
	{
		used = GetNumHumanPlayers() + GetNumFakeClients()
	}
	catch ( eUsed )
	{
	}
	if ( used >= maxPlayers )
	{
		Message( owner, "#MREC_MSG_SERVER_FULL", "#MREC_MSG_NO_SEAT_STRAFER" )
		return null
	}

	LegendBotSpot fit = LegendBot_FitSpawnSpot( owner, origin )
	origin = fit.origin
	yawAngles = <0, VectorToAngles( owner.GetOrigin() - origin ).y, 0>

	file.botSerial++
	string botName = LEGENDBOT_NAME_PREFIX + string( file.botSerial )
	int team = LegendBot_PickTeam( owner )
	int edict = -1
	try
	{
		edict = CreateFakePlayer( botName, team )
	}
	catch ( eSpawn )
	{
		printt( format( "[LegendBot] CreateFakePlayer threw: %s", string( eSpawn ) ) )
		edict = -1
	}
	if ( edict < 0 )
	{
		Message( owner, "#MREC_MSG_BOT_SPAWN_FAILED" )
		return null
	}

	entity bot = GetEntByIndex( edict )
	if ( !IsValid( bot ) || !bot.IsPlayer() )
	{
		bot = null
		foreach ( entity p in GetPlayerArray() )
		{
			if ( IsValid( p ) && p.IsBot() && p.GetPlayerName() == botName )
			{
				bot = p
				break
			}
		}
	}
	if ( !IsValid( bot ) )
	{
		Message( owner, "#MREC_MSG_BOT_SPAWN_FAILED" )
		return null
	}
	LegendBot_Track( owner, bot )
	file.laneFit[bot] <- fit.halfLane
	file.lane[bot] <- LegendBot_ClampLane( owner, fit.halfLane )

	thread function() : ( owner, bot, charRef, origin, yawAngles, shieldLevel )
	{
		if ( !IsValid( bot ) )
			return
		bot.EndSignal( "OnDestroy" )
		bool ready = false
		try
		{
			ready = MRec_WaitForBotReady( bot )
		}
		catch ( eReady )
		{
			ready = false
		}
		if ( !ready )
		{
			printt( "[LegendBot] bot never became ready" )
			LegendBot_Kick( bot )
			return
		}
		if ( !IsValid( bot ) || !IsValid( owner ) )
		{
			LegendBot_Kick( bot )
			return
		}
		MRec_BindBotRealms( bot, owner )
		string useRef = charRef
		if ( useRef == "" )
		{
			try
			{
				useRef = MovementRecorder_GetPlayerCharacterRef( owner )
			}
			catch ( eRef )
			{
				useRef = "character_wraith"
			}
		}
		MRec_ApplyLegend( bot, useRef, $"", false )
		if ( !IsValid( bot ) || !IsValid( owner ) )
			return
		MRecSnapshot snap
		bool haveSnap = true
		try
		{
			MRec_TakeSnapshot( owner, snap )
		}
		catch ( eSnap )
		{
			haveSnap = false
		}
		if ( !IsValid( bot ) || !IsValid( owner ) )
			return
		if ( haveSnap )
		{
			if ( shieldLevel > 0 && snap.equipment.len() > 0 )
				snap.equipment[0] = ""
			MRec_ApplySnapshot( bot, snap )
		}
		if ( !IsValid( bot ) )
			return
		if ( shieldLevel > 0 )
			LegendBot_ApplyArmor( bot, shieldLevel )
		if ( !IsValid( bot ) )
			return
		MRec_UnfreezeBot( bot )
		LegendBot_Place( bot, origin, yawAngles )
		// Respawn and the legend change above both reset the enemy highlight.
		AimTrainer_ApplyTargetHighlight( owner, bot )
		if ( IsValid( owner ) && owner.p.aimTrainerStraferInfiniteHealth )
			LegendBot_SetGod( bot, true )
		WaitFrame()
		LegendBot_StartStrafe( owner, bot, false )
	}()
	return bot
}

// The engine finishes a fresh fake player's spawn placement a tick after
// script sees it alive, which lands on top of a same-frame SetOrigin. Place,
// then hold the spot for a few frames.
void function LegendBot_Place( entity bot, vector origin, vector yawAngles )
{
	for ( int i = 0; i < 5; i++ )
	{
		if ( !IsValid( bot ) )
			return
		try
		{
			bot.SetVelocity( <0, 0, 0> )
			bot.SetOrigin( origin )
			bot.SetAngles( yawAngles )
		}
		catch ( eTp )
		{
			return
		}
		WaitFrame()
		if ( !IsValid( bot ) )
			return
		if ( Distance( bot.GetOrigin(), origin ) < 64.0 )
			return
		printt( format( "[LegendBot] %s displaced after placement (%.0f u), re-placing", bot.GetPlayerName(), Distance( bot.GetOrigin(), origin ) ) )
	}
}

void function LegendBot_StartStrafe( entity owner, entity bot, bool hard )
{
	if ( !IsValid( bot ) || !IsValid( owner ) )
		return
	float mult = 1.0
	try
	{
		mult = owner.p.aimTrainerStrafeSpeedMult
	}
	catch ( eMult )
	{
		mult = 1.0
	}
	if ( mult <= 0.0 )
		mult = 1.0
	try
	{
		bot.BotCmd_Face( owner )
	}
	catch ( eFace )
	{
	}
	if ( !IsValid( bot ) )
		return
	try
	{
		bot.BotCmd_Strafe( LegendBot_StrafeHalfWidth( bot ), hard, mult )
	}
	catch ( eStrafe )
	{
	}
	bool fire = false
	try
	{
		fire = owner.p.aimTrainerStraferFire
	}
	catch ( eFire )
	{
	}
	LegendBot_SetFire( bot, fire )
}

void function LegendBot_SetFire( entity bot, bool on )
{
	if ( !IsValid( bot ) )
		return
	bot.Signal( "LegendBot_FireLoop" )
	try
	{
		bot.BotCmd_SetTrigger( false )
	}
	catch ( eOff )
	{
		return
	}
	if ( on )
		thread LegendBot_FireLoop( bot )
}

void function LegendBot_SetFireAll( entity owner, bool on )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
		LegendBot_SetFire( bot, on )
}

// Lab aim slider 0..100 -> error cone. 0 sprays, 100 is a laser.
float function LegendBot_AimErrorDeg( entity owner )
{
	int aim = 50
	try
	{
		aim = owner.p.aimTrainerStraferAim
	}
	catch ( eAim )
	{
	}
	float t = min( max( float( aim ) / 100.0, 0.0 ), 1.0 )
	return LEGENDBOT_AIM_ERROR_WORST_DEG + ( LEGENDBOT_AIM_ERROR_BEST_DEG - LEGENDBOT_AIM_ERROR_WORST_DEG ) * t
}

void function LegendBot_SetAimAll( entity owner, int aim )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( IsValid( bot ) )
			LegendBot_ApplyFireProfile( bot, owner )
	}
}

// Cadence from the weapon the bot holds: automatics are held, semi-autos
// tapped at their own fire rate, burst guns pulled once per burst.
void function LegendBot_ApplyFireProfile( entity bot, entity owner )
{
	if ( !IsValid( bot ) )
		return
	int mode = BOTFIRE_HOLD
	float interval = 0.2
	entity weapon = bot.GetActiveWeapon( eActiveInventorySlot.mainHand )
	if ( IsValid( weapon ) )
	{
		float rate = 1.0
		int burst = 0
		bool semi = false
		try
		{
			rate = weapon.GetWeaponSettingFloat( eWeaponVar.fire_rate )
			burst = weapon.GetWeaponSettingInt( eWeaponVar.burst_fire_count )
			semi = weapon.GetWeaponSettingBool( eWeaponVar.is_semi_auto )
		}
		catch ( eVar )
		{
		}
		if ( rate <= 0.0 )
			rate = 1.0
		if ( burst > 1 )
		{
			mode = BOTFIRE_BURST
			interval = float( burst ) / rate + LEGENDBOT_BURST_GAP
		}
		else if ( semi )
		{
			mode = BOTFIRE_TAP
			interval = 1.0 / rate
		}
	}
	try
	{
		bot.BotCmd_SetFireProfile( mode, interval, LegendBot_AimErrorDeg( owner ) )
	}
	catch ( eProfile )
	{
	}
}

bool function LegendBot_CanSee( entity bot, entity owner )
{
	vector eye = bot.EyePosition()
	vector target = owner.EyePosition()
	try
	{
		TraceResults los = TraceLine( eye, target, [ bot, owner ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		return los.fraction >= 1.0 || los.hitEnt == owner
	}
	catch ( eLos )
	{
	}
	return true
}

// Engagement: the bot fires the magazine it has while it can see its owner,
// reloads when it runs dry, settles for a moment after the reload, and
// takes a human beat before opening up when the owner comes back into view.
void function LegendBot_FireLoop( entity bot )
{
	bot.EndSignal( "LegendBot_FireLoop" )
	bot.EndSignal( "OnDestroy" )
	bot.EndSignal( "OnDeath" )

	entity lastWeapon = null
	bool hadSight = false
	while ( IsValid( bot ) )
	{
		wait LEGENDBOT_FIRE_THINK
		entity owner = LegendBot_OwnerOf( bot )
		if ( !IsValid( owner ) || !IsAlive( owner ) )
		{
			bot.BotCmd_SetTrigger( false )
			hadSight = false
			continue
		}
		entity weapon = bot.GetActiveWeapon( eActiveInventorySlot.mainHand )
		if ( !IsValid( weapon ) )
		{
			bot.BotCmd_SetTrigger( false )
			continue
		}
		if ( weapon != lastWeapon )
		{
			lastWeapon = weapon
			LegendBot_ApplyFireProfile( bot, owner )
		}
		if ( weapon.GetWeaponPrimaryClipCount() <= 0 )
		{
			bot.BotCmd_SetTrigger( false )
			bot.BotCmd_PressButtons( IN_RELOAD )
			float giveUp = Time() + 6.0
			while ( IsValid( weapon ) && weapon.GetWeaponPrimaryClipCount() <= 0 && Time() < giveUp )
			{
				wait LEGENDBOT_FIRE_THINK
				if ( !weapon.IsReloading() )
					bot.BotCmd_PressButtons( IN_RELOAD )
			}
			wait RandomFloatRange( LEGENDBOT_RELOAD_SETTLE_MIN, LEGENDBOT_RELOAD_SETTLE_MAX )
			hadSight = false
			continue
		}
		bool sight = LegendBot_CanSee( bot, owner )
		if ( sight && !hadSight )
			wait RandomFloatRange( LEGENDBOT_REACTION_MIN, LEGENDBOT_REACTION_MAX )
		hadSight = sight
		bot.BotCmd_SetTrigger( sight )
	}
}

// Lab strafe width caps the lane the spawn fit found.
float function LegendBot_ClampLane( entity owner, float fitHalf )
{
	int width = 512
	try
	{
		width = owner.p.aimTrainerStrafeWidth
	}
	catch ( eWidth )
	{
	}
	return min( fitHalf, max( float( width ) * 0.5, 16.0 ) )
}

void function LegendBot_SetStrafeWidthAll( entity owner, int width )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( !IsValid( bot ) )
			continue
		float fit = ( bot in file.laneFit ) ? file.laneFit[bot] : LEGENDBOT_LANE_PROBE
		file.lane[bot] <- LegendBot_ClampLane( owner, fit )
		try
		{
			bot.BotCmd_Strafe( file.lane[bot], false, owner.p.aimTrainerStrafeSpeedMult )
		}
		catch ( eStrafe )
		{
		}
	}
}

void function LegendBot_SetStrafeSpeedAll( entity owner, float mult )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( !IsValid( bot ) )
			continue
		try
		{
			bot.BotCmd_SetStrafeSpeed( mult )
		}
		catch ( eSpeed )
		{
		}
	}
}

float function LegendBot_StrafeHalfWidth( entity bot )
{
	if ( IsValid( bot ) && ( bot in file.lane ) )
		return file.lane[bot]
	return LEGENDBOT_LANE_PROBE
}

vector function LegendBot_GroundAt( vector pos )
{
	try
	{
		TraceResults floor = TraceLine( pos + <0, 0, 32>, pos + <0, 0, -512>, null, TRACE_MASK_SOLID_BRUSHONLY, TRACE_COLLISION_GROUP_NONE )
		if ( floor.fraction < 1.0 )
			return floor.endPos
	}
	catch ( eFloor )
	{
	}
	return pos
}

bool function LegendBot_HullClear( vector ground )
{
	vector mins = <-16, -16, 0>
	vector maxs = <16, 16, 72>
	try
	{
		TraceResults hull = TraceHull( ground + <0, 0, 4>, ground + <0, 0, 8>, mins, maxs, null, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_NONE )
		return !hull.startSolid && hull.fraction >= 1.0
	}
	catch ( eHull )
	{
	}
	return true
}

// Free run along dir from ground, player hull lifted by the step height so
// stairs and clutter under the knee do not count as walls.
float function LegendBot_LaneRoom( vector ground, vector dir, float probe )
{
	vector mins = <-16, -16, LEGENDBOT_LANE_STEP_HEIGHT>
	vector maxs = <16, 16, 72>
	try
	{
		TraceResults sweep = TraceHull( ground, ground + dir * probe, mins, maxs, null, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_NONE )
		if ( sweep.startSolid )
			return 0.0
		return sweep.fraction * probe
	}
	catch ( eSweep )
	{
	}
	return probe
}

// Nudge the wanted spot until the bot stands in open space with a strafe
// lane on both sides of the line to its owner; each retry backs the spot
// off toward the owner. The lane that was found sizes the strafe program.
LegendBotSpot function LegendBot_FitSpawnSpot( entity owner, vector want )
{
	LegendBotSpot best
	best.origin = LegendBot_GroundAt( want )
	best.halfLane = LEGENDBOT_LANE_MIN * 0.5
	best.ok = false

	vector ownerPos = owner.GetOrigin()
	vector toOwner = ownerPos - want
	toOwner.z = 0.0
	float dist = Length( toOwner )
	if ( dist < 1.0 )
		toOwner = AnglesToForward( <0, owner.EyeAngles().y, 0> ) * -1.0
	else
		toOwner = toOwner / dist

	for ( int attempt = 0; attempt < LEGENDBOT_SPOT_TRIES; attempt++ )
	{
		float back = attempt * LEGENDBOT_SPOT_BACKOFF
		if ( dist - back < LEGENDBOT_SPOT_MIN_DIST )
			break
		vector ground = LegendBot_GroundAt( want + toOwner * back )
		if ( !LegendBot_HullClear( ground ) )
			continue

		vector right = CrossProduct( toOwner, <0, 0, 1> )
		float roomR = LegendBot_LaneRoom( ground, right, LEGENDBOT_LANE_PROBE )
		float roomL = LegendBot_LaneRoom( ground, right * -1.0, LEGENDBOT_LANE_PROBE )

		// Centre in whatever lane exists so neither leg starts at a wall.
		float shift = ( roomR - roomL ) * 0.5
		if ( fabs( shift ) > 1.0 )
		{
			vector centred = LegendBot_GroundAt( ground + right * shift )
			if ( LegendBot_HullClear( centred ) )
			{
				ground = centred
				roomR = LegendBot_LaneRoom( ground, right, LEGENDBOT_LANE_PROBE )
				roomL = LegendBot_LaneRoom( ground, right * -1.0, LEGENDBOT_LANE_PROBE )
			}
		}

		float half = min( roomR, roomL )
		if ( half > best.halfLane || !best.ok )
		{
			best.origin = ground
			best.halfLane = max( half, LEGENDBOT_LANE_MIN * 0.5 )
			best.ok = true
		}
		if ( half >= LEGENDBOT_LANE_MIN )
			break
	}

	if ( !best.ok )
		printt( "[LegendBot] no clear spawn spot along the view line, using the wanted point" )
	return best
}

// Where the player is looking, no farther than LEGENDBOT_AUTOSPAWN_DIST,
// dropped to the floor.
vector function LegendBot_CrosshairSpot( entity player )
{
	vector eye = player.EyePosition()
	vector fwd = AnglesToForward( player.EyeAngles() )
	vector want = eye + fwd * LEGENDBOT_AUTOSPAWN_DIST
	try
	{
		TraceResults view = TraceLine( eye, want, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		if ( view.fraction < 1.0 )
			want = view.endPos - fwd * 24.0
	}
	catch ( eView )
	{
	}
	try
	{
		TraceResults floor = TraceLine( want + <0, 0, 16>, want + <0, 0, -512>, [ player ], TRACE_MASK_SOLID_BRUSHONLY, TRACE_COLLISION_GROUP_NONE )
		if ( floor.fraction < 1.0 )
			return floor.endPos
	}
	catch ( eFloor )
	{
	}
	return want
}

void function LegendBot_AutospawnLoop( entity player, bool hard )
{
	if ( !IsValid( player ) )
		return
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "AimFreeroam_Stop" )

	OnThreadEnd(
		function() : ()
		{
			printt( "[LegendBot] Autospawn ended" )
		}
	)

	AimTrainer_WaitForIntro( player )

	while ( IsValid( player ) )
	{
		bool budgetFull = true
		try
		{
			budgetFull = AimTrainer_GetBudgetRemaining() <= 0
		}
		catch ( eBudget )
		{
			budgetFull = true
		}
		if ( budgetFull )
		{
			wait 0.5
			continue
		}
		int total = LegendBot_Count( player )
		try
		{
			total += MRec_PlayerBotCount( player )
		}
		catch ( eCount )
		{
		}
		if ( total >= MREC_MAX_PLAYBACK_DUMMIES_PER_PLAYER )
		{
			wait 0.5
			continue
		}
		vector org = <0, 0, 0>
		try
		{
			org = player.GetOrigin()
		}
		catch ( eOrg )
		{
			wait 0.5
			continue
		}
		vector ground = LegendBot_CrosshairSpot( player )
		try
		{
			if ( player.p.aimTrainerFixedSpawn )
				ground = player.p.aimTrainerFixedSpawnPos
		}
		catch ( eFixed )
		{
		}
		float yaw = 0.0
		try
		{
			yaw = VectorToAngles( org - ground ).y
		}
		catch ( eYaw )
		{
		}
		string cref = ""
		try
		{
			cref = LegendBot_GetStoredCharRef( player )
		}
		catch ( eRef )
		{
		}
		int shield = 1
		try
		{
			shield = AimTrainer_ResolveDummyShieldLevel( player )
		}
		catch ( eShield )
		{
		}
		entity bot = null
		try
		{
			bot = LegendBot_Spawn( player, cref, ground, <0, yaw, 0>, shield )
		}
		catch ( eSpawn )
		{
			bot = null
		}
		if ( !IsValid( bot ) )
		{
			wait 0.5
			continue
		}
		bool ready = false
		try
		{
			ready = MRec_WaitForBotReady( bot )
		}
		catch ( eReady )
		{
		}
		if ( ready )
		{
			wait 0.5
			LegendBot_StartStrafe( player, bot, hard )
		}
		printt( format( "[LegendBot] Autospawn strafer live hard=%s", string( hard ) ) )
		WaitSignal( bot, "OnDeath", "OnDestroy" )
		wait 0.2
	}
}
