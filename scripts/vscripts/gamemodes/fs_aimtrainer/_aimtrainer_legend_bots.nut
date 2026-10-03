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
global function LegendBot_DespawnWithFX
global function LegendBot_RestorePrefs
global function LegendBot_SortedVisibleRefs
global function LegendBot_SetHardAll
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
global function LegendBot_SetStrafeTimingAll
global function LegendBot_SetStrafingAll
global function LegendBot_SetCrouchAll
global function LegendBot_ApplyArmor

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
	table<entity, bool> hard = {}
	int botSerial = 0
} file

void function AimTrainer_LegendBots_Init()
{
	RegisterSignal( "LegendBot_FireLoop" )
	AddCallback_OnPlayerKilled( LegendBot_OnPlayerKilled )
	AddDamageCallback( "player", LegendBot_OnPlayerDamaged )
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

// Strafer infinite health for fake players: same lethal-hit absorb as the NPC
// strafers, then refill once they have been left alone.
void function LegendBot_OnPlayerDamaged( entity victim, var damageInfo )
{
	if ( !LegendBot_IsBot( victim ) || !IsAlive( victim ) )
		return
	int key = LegendBot_KeyOf( victim )
	if ( key < 0 || !( key in file.god ) || !file.god[key] )
		return
	file.lastDamaged[key] <- Time()
	AimTrainerStrafer_AbsorbLethal( victim, damageInfo )
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
		fallback.body = "legend"
		fallback.charRef = ""
		return fallback
	}
	if ( !( key in file.prefs ) )
	{
		LegendStraferPrefs p
		p.body = "legend"
		p.charRef = ""
		file.prefs[key] <- p
	}
	return file.prefs[key]
}

// Saved prefs at connect: no bots exist yet, so nothing to redress or sync.
void function LegendBot_RestorePrefs( entity player, bool legend, string charRef )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( charRef != "" && !LegendBot_SortedVisibleRefs().contains( charRef ) )
		charRef = ""
	LegendStraferPrefs p = LegendBot_GetPrefs( player )
	p.body = legend ? "legend" : "dummy"
	p.charRef = charRef
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
		return true
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
	bool changed = p.body != want
	p.body = want
	printt( format( "[LegendBot] Strafer body = %s for %s", want, player.GetPlayerName() ) )

	// Live strafers keep the body they spawned with; swap them.
	if ( changed )
		AimTrainer_RespawnStraferSlots( player )
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
		LegendBot_RedressAll( player )
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
	LegendBot_RedressAll( player )
	try
	{
		AimTrainer_SyncDevMenuState( player )
	}
	catch ( eSync )
	{
	}
}

// Live strafers take the new legend at once. Character setup resets the kit,
// so armor, highlight and move speed go back on after it.
void function LegendBot_RedressAll( entity owner )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	string ref = LegendBot_GetStoredCharRef( owner )
	if ( ref == "" )
	{
		try
		{
			ref = MovementRecorder_GetPlayerCharacterRef( owner )
		}
		catch ( eRef )
		{
			return
		}
	}
	int shield = AimTrainer_ResolveDummyShieldLevel( owner )
	foreach ( entity bot in file.bots[key] )
	{
		if ( !IsValid( bot ) || !IsAlive( bot ) )
			continue
		MRec_ApplyLegend( bot, ref, $"", false )
		if ( !IsValid( bot ) )
			continue
		LegendBot_ApplyArmor( bot, shield )
		AimTrainer_ApplyTargetHighlight( owner, bot )
		LegendBot_ApplySpeedBoost( bot, AimTrainer_TargetsStatic( owner ) ? 1.0 : owner.p.aimTrainerStrafeSpeedMult )
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
	foreach ( entity bot, bool isHard in clone file.hard )
	{
		if ( !IsValid( bot ) )
			delete file.hard[bot]
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

void function LegendBot_DespawnWithFX( entity owner, entity bot )
{
	if ( !IsValid( bot ) )
		return
	int key = LegendBot_KeyOf( owner )
	if ( key >= 0 && key in file.bots )
		file.bots[key].removebyvalue( bot )
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

// Brain changes restart each live bot's movement program with the owner's pick.
void function LegendBot_SetHardAll( entity owner )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( IsValid( bot ) && IsAlive( bot ) )
			LegendBot_StartStrafe( owner, bot, owner.p.aimTrainerStraferHard )
	}
}

// Plain armor sizes its shield from the item tier. Armor cores size it from the
// wearer's upgrade level instead, so every tier would come out the same.
string function LegendBot_ArmorRefForShieldLevel( int level )
{
	array<string> cands = []
	if ( level == 1 )
		cands = [ "armor_pickup_lv1" ]
	else if ( level == 2 )
		cands = [ "armor_pickup_lv2" ]
	else if ( level == 3 )
		cands = [ "armor_pickup_lv3" ]
	else if ( level >= 4 )
		cands = [ "armor_pickup_lv5_evolving", "armor_pickup_lv3" ]
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
	{
		printt( format( "[LegendBot] no valid armor ref for level %d", shieldLevel ) )
		return
	}
	try
	{
		Inventory_SetPlayerEquipment( bot, "", "armor" )
		bot.SetShieldHealth( 0 )
		Inventory_SetPlayerEquipment( bot, ref, "armor" )
		bot.SetShieldHealth( bot.GetShieldHealthMax() )
	}
	catch ( eEq )
	{
		printt( format( "[LegendBot] armor %s failed: %s", ref, string( eEq ) ) )
		return
	}
	printt( format( "[LegendBot] %s armor %s shield %d/%d", bot.GetPlayerName(), ref, bot.GetShieldHealth(), bot.GetShieldHealthMax() ) )
}

// needSight=false only for a spot the owner already proved visible when saving it.
entity function LegendBot_Spawn( entity owner, string charRef, vector origin, vector yawAngles, int shieldLevel, bool needSight = true )
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

	LegendBotSpot fit = LegendBot_FitSpawnSpot( owner, origin, needSight )
	if ( !fit.ok )
	{
		printt( format( "[LegendBot] no room for a strafer near %s, spawn skipped", string( origin ) ) )
		return null
	}
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
		if ( !LegendBot_StandsClear( bot ) )
		{
			printt( format( "[LegendBot] %s ended up in solid at %s, removed", bot.GetPlayerName(), string( bot.GetOrigin() ) ) )
			LegendBot_Kick( bot )
			return
		}
		// Respawn and the legend change above both reset the enemy highlight.
		AimTrainer_ApplyTargetHighlight( owner, bot )
		if ( IsValid( owner ) && owner.p.aimTrainerStraferInfiniteHealth )
			LegendBot_SetGod( bot, true )
		WaitFrame()
		LegendBot_StartStrafe( owner, bot, owner.p.aimTrainerStraferHard )
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
	file.hard[bot] <- hard
	bool strafing = !AimTrainer_TargetsStatic( owner )
	try
	{
		if ( strafing )
		{
			bot.BotCmd_Strafe( LegendBot_StrafeHalfWidth( bot ), hard, mult )
			LegendBot_ApplyStrafeTiming( bot, owner )
			bot.BotCmd_SetStrafeCrouch( owner.p.aimTrainerStraferCrouch )
		}
		else
		{
			bot.BotCmd_SetMove( 0.0, 0.0, 0 )
		}
	}
	catch ( eStrafe )
	{
	}
	LegendBot_ApplySpeedBoost( bot, strafing ? mult : 1.0 )
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
	{
		try
		{
			SetInfiniteAmmoForPlayer( bot, true, [], true, true )
		}
		catch ( eAmmo )
		{
		}
		thread LegendBot_FireLoop( bot )
	}
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
		if ( weapon.UsesClipsForAmmo() && weapon.GetWeaponPrimaryClipCount() <= 0 )
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
			if ( IsValid( weapon ) && weapon.GetWeaponPrimaryClipCount() <= 0 )
				weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
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

float function LegendBot_ClampLane( entity owner, float fitHalf )
{
	return max( fitHalf, 16.0 )
}

void function LegendBot_ApplyStrafeTiming( entity bot, entity owner )
{
	int minIdx = 2
	int maxIdx = 6
	try
	{
		minIdx = owner.p.aimTrainerStrafeTimeMin
		maxIdx = owner.p.aimTrainerStrafeTimeMax
	}
	catch ( eIdx )
	{
	}
	bot.BotCmd_SetStrafeTiming( FRDummie_StrafeDurationIndexToSeconds( minIdx ), FRDummie_StrafeDurationIndexToSeconds( maxIdx ) )
}

void function LegendBot_SetStrafeTimingAll( entity owner )
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
			LegendBot_ApplyStrafeTiming( bot, owner )
		}
		catch ( eTiming )
		{
		}
	}
}

void function LegendBot_SetCrouchAll( entity owner )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( IsValid( bot ) )
			bot.BotCmd_SetStrafeCrouch( owner.p.aimTrainerStraferCrouch )
	}
}

// Re-runs each live bot's movement program so the Strafing switch lands at once.
void function LegendBot_SetStrafingAll( entity owner )
{
	int key = LegendBot_KeyOf( owner )
	if ( key < 0 || !( key in file.bots ) )
		return
	LegendBot_Prune( key )
	foreach ( entity bot in file.bots[key] )
	{
		if ( IsValid( bot ) && IsAlive( bot ) )
			LegendBot_StartStrafe( owner, bot, ( bot in file.hard ) ? file.hard[bot] : false )
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
		LegendBot_ApplySpeedBoost( bot, AimTrainer_TargetsStatic( owner ) ? 1.0 : mult )
	}
}

// A bot already strafes at full stick, so speeds above 1x need a real move-speed boost.
void function LegendBot_ApplySpeedBoost( entity bot, float mult )
{
	if ( !IsValid( bot ) || !IsAlive( bot ) )
		return
	StatusEffect_StopAllOfType( bot, eStatusEffect.speed_boost )
	if ( mult <= 1.0 )
		return
	StatusEffect_AddEndless( bot, eStatusEffect.speed_boost, min( mult - 1.0, 1.0 ) )
	printt( format( "[LegendBot] %s speed_boost %.2f", bot.GetPlayerName(), mult - 1.0 ) )
}

float function LegendBot_StrafeHalfWidth( entity bot )
{
	if ( IsValid( bot ) && ( bot in file.lane ) )
		return file.lane[bot]
	return LEGENDBOT_LANE_PROBE
}

// The engine can still shove a fresh fake player after placement; a bot left
// overlapping the world is removed rather than left stuck in it.
bool function LegendBot_StandsClear( entity bot )
{
	if ( !IsValid( bot ) )
		return false
	vector org = bot.GetOrigin()
	TraceResults hull = TraceHull( org + <0, 0, 2>, org + <0, 0, 3>, bot.GetPlayerMins(), bot.GetPlayerMaxs(), [ bot ], AIMTRAINER_WORLD_MASK, TRACE_COLLISION_GROUP_NONE )
	return !hull.startSolid
}

// Free run along dir from ground, player hull lifted by the step height so
// stairs and clutter under the knee do not count as walls.
float function LegendBot_LaneRoom( vector ground, vector dir, float probe )
{
	vector mins = <-16, -16, LEGENDBOT_LANE_STEP_HEIGHT>
	vector maxs = <16, 16, 72>
	try
	{
		TraceResults sweep = TraceHull( ground, ground + dir * probe, mins, maxs, null, AIMTRAINER_WORLD_MASK, TRACE_COLLISION_GROUP_NONE )
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
// ok=false means no proven-clear spot exists near `want`.
LegendBotSpot function LegendBot_FitSpawnSpot( entity owner, vector want, bool needSight = true )
{
	LegendBotSpot best
	best.origin = want
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
	vector right = CrossProduct( toOwner, <0, 0, 1> )

	for ( int attempt = 0; attempt < LEGENDBOT_SPOT_TRIES; attempt++ )
	{
		float back = attempt * LEGENDBOT_SPOT_BACKOFF
		if ( attempt > 0 && dist - back < LEGENDBOT_SPOT_MIN_DIST )
			break
		AimTrainerSpawnSpot spot = AimTrainer_CheckSpawnSpot( owner, want + toOwner * back, needSight )
		if ( !spot.ok )
			continue
		vector ground = spot.origin

		float roomR = LegendBot_LaneRoom( ground, right, LEGENDBOT_LANE_PROBE )
		float roomL = LegendBot_LaneRoom( ground, right * -1.0, LEGENDBOT_LANE_PROBE )

		// Centre in whatever lane exists so neither leg starts at a wall.
		float shift = ( roomR - roomL ) * 0.5
		if ( fabs( shift ) > 1.0 )
		{
			AimTrainerSpawnSpot centred = AimTrainer_CheckSpawnSpot( owner, ground + right * shift, needSight )
			if ( centred.ok )
			{
				ground = centred.origin
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

	if ( best.ok )
		return best

	AimTrainerSpawnSpot near = AimTrainer_FindSpawnSpot( owner, want, needSight )
	if ( near.ok )
	{
		best.origin = near.origin
		best.halfLane = max( min( LegendBot_LaneRoom( near.origin, right, LEGENDBOT_LANE_PROBE ), LegendBot_LaneRoom( near.origin, right * -1.0, LEGENDBOT_LANE_PROBE ) ), LEGENDBOT_LANE_MIN * 0.5 )
		best.ok = true
	}
	return best
}

// Where the player is looking, no farther than LEGENDBOT_AUTOSPAWN_DIST,
// dropped to the floor. Spawns still validate the spot.
vector function LegendBot_CrosshairSpot( entity player )
{
	return AimTrainer_ViewSpot( player, LEGENDBOT_AUTOSPAWN_DIST, false )
}
