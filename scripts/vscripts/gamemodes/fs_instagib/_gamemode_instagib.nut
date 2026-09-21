// Instagib FFA: one-shot rail pistol, railjump, no player collision.

global function _GamemodeInstagib_Init

const float INSTAGIB_SPAWN_IMMUNITY = 2.5
const float INSTAGIB_MIN_SPAWN_DIST = 400.0
const int INSTAGIB_RING_DISABLED = 99999

struct
{
	int currentRound = 1
} file

void function _GamemodeInstagib_Init()
{
	if ( !FS_IsInstagib() )
		return

	printt( "[FS-IG] _GamemodeInstagib_Init" )

	// PickLoadout DecideRespawnPlayer -> FindSpawnPoint. Survival sets this; custom modes must.
	Spawn_SetSpawnpointRatingFunc( RateSpawnpoints_Generic )

	PrecacheWeapon( INSTAGIB_WEAPON_CLASS )
	PrecacheWeapon( INSTAGIB_TAC_CLASS )
	PrecacheWeapon( "mp_ability_phase_walk" )
	PrecacheWeapon( "mp_weapon_melee_survival" )
	PrecacheWeapon( "melee_pilot_emptyhanded" )
	RegisterWeaponDamageSource( INSTAGIB_WEAPON_CLASS )

	AddCallback_EntitiesDidLoad( FS_Instagib_OnEntitiesDidLoad )
	AddCallback_OnClientConnected( FS_Instagib_OnClientConnected )
	AddCallback_OnPlayerKilled( FS_Instagib_OnPlayerKilled )
	AddCallback_OnPlayerRespawned( FS_Instagib_OnPlayerRespawned )
	AddSpawnCallback( "npc_dummie", FS_Instagib_OnDummySpawned )

	thread FS_Instagib_ForcePlayingShell_THREAD()
	thread _RunInstagib()
}

void function FS_Instagib_OnEntitiesDidLoad()
{
	if ( !GetCurrentPlaylistVarBool( "flowstateDoorsEnabled", false ) )
	{
		array<entity> doors = GetAllPropDoors()
		foreach ( entity door in doors )
		{
			if ( IsValid( door ) )
				door.Destroy()
		}
	}

	SetDeathFieldParams( <0, 0, 0>, INSTAGIB_RING_DISABLED, INSTAGIB_RING_DISABLED, 90000, INSTAGIB_RING_DISABLED, 0 )
	FS_Instagib_DisableAllLootBins()
	thread FS_Instagib_DisableAllLootBins_Retry_THREAD()

	foreach ( entity dummy in GetNPCArrayByClass( "npc_dummie" ) )
		FS_Instagib_OnDummySpawned( dummy )

	printt( "[FS-IG] EDL spawns=" + string( FS_Instagib_GetSpawnsForMap().len() ) + " map=" + GetMapName() )
}

void function FS_Instagib_DisableAllLootBins()
{
	foreach ( entity lootBin in GetAllLootBins() )
	{
		if ( !IsValid( lootBin ) )
			continue
		lootBin.UnsetUsable()
	}
}

void function FS_Instagib_DisableAllLootBins_Retry_THREAD()
{
	for ( int i = 0; i < 8; i++ )
	{
		wait 1.0
		FS_Instagib_DisableAllLootBins()
	}
}

int function FS_Instagib_CountConnectedPlayers()
{
	int n = 0
	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			n++
	}
	return n
}

void function FS_Instagib_WaitForFirstPlayer()
{
	if ( FS_Instagib_CountConnectedPlayers() >= 1 )
		return

	printt( "[FS-IG] waiting for first player" )
	while ( FS_Instagib_CountConnectedPlayers() < 1 )
		WaitFrame()
	printt( "[FS-IG] first player present" )
}

void function FS_Instagib_ForcePlayingShell_THREAD()
{
	FS_Instagib_WaitForFirstPlayer()
	wait 0.5

	if ( GetGameState() >= eGameState.Playing )
	{
		printt( "[FS-IG] ForcePlayingShell: already Playing" )
		foreach ( entity player in GetPlayerArray() )
		{
			if ( IsValid( player ) )
				player.UnfreezeControlsOnServer()
		}
		return
	}

	SetGlobalNetTime( "pickLoadoutGamestateEndTime", Time() - 1.0 )

	if ( GetGameState() < eGameState.Playing )
	{
		SetGameState( eGameState.Playing )
		printt( "[FS-IG] forced eGameState.Playing" )
	}

	foreach ( entity player in GetPlayerArray() )
	{
		if ( IsValid( player ) )
			player.UnfreezeControlsOnServer()
	}
}

void function _RunInstagib()
{
	WaitForGameState( eGameState.Playing )
	FS_Instagib_WaitForFirstPlayer()

	SetDeathFieldParams( <0, 0, 0>, INSTAGIB_RING_DISABLED, INSTAGIB_RING_DISABLED, 90000, INSTAGIB_RING_DISABLED, 0 )

	while ( true )
	{
		float roundTime = GetCurrentPlaylistVarFloat( "flowstateRoundtime", 800.0 )
		float startTime = Time()
		float endTime = startTime + roundTime
		SetGlobalNetTime( "flowstate_DMStartTime", startTime )
		SetGlobalNetTime( "flowstate_DMRoundEndTime", endTime )
		SetGlobalNetInt( "FSDM_GameState", 0 )
		SetGameEndTime( endTime )
		SetGameStartTime( startTime )
		printt( "[FS-IG] round " + string( file.currentRound ) + " start dur=" + string( roundTime ) )

		foreach ( entity player in GetPlayerArray() )
		{
			if ( IsValid( player ) )
				FS_Instagib_ResetPlayerStats( player )
		}

		while ( Time() < endTime )
			WaitFrame()

		entity champ = FS_Instagib_GetBestPlayer()
		string champName = IsValid( champ ) ? champ.GetPlayerName() : "none"
		printt( "[FS-IG] round " + string( file.currentRound ) + " over champ=" + champName )

		file.currentRound++

		if ( file.currentRound > GetCurrentPlaylistVarInt( "flowstateRoundsBeforeChangeLevel", 3 ) && GetCurrentPlaylistVarBool( "flowstateAutoChangeLevelEnable", false ) )
		{
			string nextMap = FS_Instagib_NextMap()
			string playlist = GetCurrentPlaylistName()
			if ( nextMap == "" || !Tracker_IsSafeMapName( nextMap ) )
			{
				printt( "[FS-IG] changelevel aborted: bad map '" + nextMap + "' playlist=" + playlist )
			}
			else
			{
				printt( "[FS-IG] changelevel -> " + nextMap + " playlist=" + playlist )
				GameRules_ChangeMap( nextMap, playlist )
				return
			}
		}

		foreach ( entity player in GetPlayerArray() )
		{
			if ( !IsValid( player ) )
				continue
			if ( !IsAlive( player ) )
				FS_Instagib_ForcePilotRespawn( player )
			FS_Instagib_HandleRespawn( player )
		}
	}
}

string function FS_Instagib_NextMap()
{
	return Tracker_DetermineNextMap()
}

entity function FS_Instagib_GetBestPlayer()
{
	entity best = null
	int bestKills = -1
	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsValid( player ) )
			continue
		int k = player.GetPlayerNetInt( "kills" )
		if ( k > bestKills )
		{
			bestKills = k
			best = player
		}
	}
	return best
}

void function FS_Instagib_OnClientConnected( entity player )
{
	if ( !IsValid( player ) )
		return

	AddEntityCallback_OnDamaged( player, FS_Instagib_OnDamaged )
	player.p.lastTimeUsedRailjump = -1.0
	player.p.railjumptimes = 0
	player.p.shotsfired = 0
	player.p.instagibLegendReady = false

	thread FS_Instagib_ConnectedPlayer_THREAD( player )
	thread FS_Instagib_LatencyFeed_THREAD( player )
}

void function FS_Instagib_LatencyFeed_THREAD( entity player )
{
	EndSignal( player, "OnDestroy" )

	for ( ;; )
	{
		player.SetPlayerNetInt( "latency", ClampInt( int( player.GetLatency() * 1000 ), 0, 500 ) )
		wait 0.5
	}
}

void function FS_Instagib_ConnectedPlayer_THREAD( entity player )
{
	EndSignal( player, "OnDestroy" )
	wait 0.5
	if ( !IsValid( player ) )
		return

	if ( GetGameState() < eGameState.Playing )
	{
		SetGlobalNetTime( "pickLoadoutGamestateEndTime", Time() - 1.0 )
		SetGameState( eGameState.Playing )
	}

	player.UnfreezeControlsOnServer()
	FS_Instagib_HandleRespawn( player )
}

void function FS_Instagib_OnDummySpawned( entity dummy )
{
	if ( !IsValid( dummy ) )
		return

	AddEntityCallback_OnDamaged( dummy, FS_Instagib_OnDamaged )
}

void function FS_Instagib_OnDamaged( entity victim, var damageInfo )
{
	if ( !IsValid( victim ) || !IsAlive( victim ) )
		return
	if ( !victim.IsPlayer() && !victim.IsNPC() )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return
	if ( attacker == victim )
		return
	if ( !IsAlive( attacker ) )
		return

	EmitSoundAtPosition( TEAM_UNASSIGNED, victim.GetWorldSpaceCenter(), "wattson_tactical_m_3p" )

	int dealt = victim.GetHealth() + victim.GetShieldHealth()
	int nextDmg = attacker.GetPlayerNetInt( "damage" ) + dealt
	attacker.SetPlayerNetInt( "damage", nextDmg )
	attacker.SetPlayerNetInt( "damageDealt", nextDmg )

	DamageInfo_SetDamage( damageInfo, 9999 )
	DamageInfo_SetDamageSourceIdentifier( damageInfo, eDamageSourceId.mp_weapon_instagib )
}

void function FS_Instagib_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( victim ) )
		return

	thread FS_Instagib_OnPlayerDied_THREAD( victim, attacker, damageInfo )
}

void function FS_Instagib_OnPlayerDied_THREAD( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( victim ) )
		return

	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim )
	{
		attacker.p.lastTimeUsedRailjump = -1.0
		int k = attacker.GetPlayerNetInt( "kills" ) + 1
		attacker.SetPlayerNetInt( "kills", k )
		attacker.SetPlayerGameStat( PGS_KILLS, k )
		Remote_CallFunction_NonReplay( attacker, "ServerCallback_Instagib_Score", k, attacker.GetPlayerNetInt( "deaths" ) )
	}

	int d = victim.GetPlayerNetInt( "deaths" ) + 1
	victim.SetPlayerNetInt( "deaths", d )
	victim.SetPlayerGameStat( PGS_DEATHS, d )
	float respawnWait = FS_Instagib_GetRespawnWait()
	Remote_CallFunction_NonReplay( victim, "ServerCallback_Instagib_RespawnUI", int( respawnWait ) )
	Remote_CallFunction_NonReplay( victim, "ServerCallback_Instagib_Score", victim.GetPlayerNetInt( "kills" ), d )

	wait respawnWait

	if ( !IsValid( victim ) )
		return

	FS_Instagib_ForcePilotRespawn( victim )
	FS_Instagib_HandleRespawn( victim )
}

bool function FS_Instagib_ForcePilotRespawn( entity player )
{
	if ( !IsValid( player ) )
		return false

	if ( IsAlive( player ) )
		return true

	ClearPlayerEliminated( player )
	player.Signal( "StopPostDeathLogic" )

	if ( player.IsObserver() )
	{
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
	}

	bool ok = DecideRespawnPlayer( player, false )
	if ( !ok )
		printt( "[FS-IG] ForcePilotRespawn failed " + player.GetPlayerName() )
	return ok
}

void function FS_Instagib_HandleRespawn( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( player.IsObserver() )
	{
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
	}

	if ( !IsAlive( player ) )
		FS_Instagib_ForcePilotRespawn( player )

	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	FS_Instagib_AssignCharacter( player )
	FS_Instagib_GiveLoadout( player )
	FS_Instagib_TeleportToSpawn( player )
	FS_Instagib_PlayerSpawn( player )
	player.SetHealth( 100 )
	Remote_CallFunction_NonReplay( player, "ServerCallback_Instagib_ClearDeathUI" )
	thread FS_Instagib_SpawnImmunity_THREAD( player )
}

float function FS_Instagib_GetRespawnWait()
{
	return GetCurrentPlaylistVarFloat( "respawn_delay", 5.0 )
}

void function FS_Instagib_OnPlayerRespawned( entity player )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return

	AddEntityCallback_OnDamaged( player, FS_Instagib_OnDamaged )
	FS_Instagib_AssignCharacter( player )
	// Engine respawns bypass HandleRespawn; assign rebuilds the settings
	// block to defaults, so the movement table must be re-applied here.
	FS_Instagib_PlayerSpawn( player )
}

ItemFlavor function FS_Instagib_PickCharacter( entity player )
{
	array<ItemFlavor> playable
	foreach ( ItemFlavor c in GetAllCharacters() )
	{
		if ( ItemFlavor_GetAsset( c ) == CHARACTER_RANDOM )
			continue
		playable.append( c )
	}
	if ( playable.len() < 1 )
		playable = GetAllCharacters()

	if ( GetCurrentPlaylistVarBool( "flowstateForceCharacter", false ) )
	{
		int idx = GetCurrentPlaylistVarInt( "flowstateChosenCharacter", 0 )
		if ( idx < 0 || idx >= playable.len() )
			idx = 0
		return playable[idx]
	}

	if ( player.p.instagibLegendReady )
	{
		ItemFlavor current = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_Character() )
		asset currentAsset = ItemFlavor_GetAsset( current )
		if ( currentAsset != CHARACTER_RANDOM )
		{
			foreach ( ItemFlavor c in playable )
			{
				if ( ItemFlavor_GetAsset( c ) == currentAsset )
					return current
			}
		}
	}

	return playable[ RandomInt( playable.len() ) ]
}

void function FS_Instagib_AssignCharacter( entity player )
{
	if ( !IsValid( player ) )
		return

	ItemFlavor character = FS_Instagib_PickCharacter( player )
	SetItemFlavorLoadoutSlot( ToEHI( player ), Loadout_Character(), character )

	try
	{
		Survival_PlayerCharacterSetup( player, character, true )
	}
	catch ( charSetupErr )
	{
		printt( "[FS-IG] character setup failed: " + charSetupErr )
	}

	player.p.instagibLegendReady = true
	TakeAllPassives( player )
}

void function FS_Instagib_GiveLoadout( entity player )
{
	if ( !IsValid( player ) )
		return

	TakeAllWeapons( player )

	array<string> weaponMods = [ "optic_cq_hcog_classic", "sniper_mag_l3", "laser_sight_l3", "hopup_smart_reload" ]
	entity weaponNew = player.GiveWeapon( INSTAGIB_WEAPON_CLASS, WEAPON_INVENTORY_SLOT_PRIMARY_0, weaponMods, false )
	if ( !IsValid( weaponNew ) )
		printt( "[FS-IG] GiveWeapon failed class=" + INSTAGIB_WEAPON_CLASS + " player=" + player.GetPlayerName() )
	else
		SetWeaponLockedSetFromLootTags( [ WEAPON_LOCKEDSET_MOD_GOLD ], weaponNew )

	player.GiveWeapon( "mp_weapon_melee_survival", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
	player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )

	player.TakeOffhandWeapon( OFFHAND_TACTICAL )
	player.TakeOffhandWeapon( OFFHAND_ULTIMATE )
	player.GiveOffhandWeapon( INSTAGIB_TAC_CLASS, OFFHAND_TACTICAL, [] )
	player.GiveOffhandWeapon( "mp_ability_phase_walk", OFFHAND_ULTIMATE, [] )

	// TakeAllWeapons strips these two; without them the comms wheel has no holospray and no emote.
	if ( GetCurrentPlaylistVarBool( "holosprays_enabled", true ) )
		player.GiveOffhandWeapon( HOLO_PROJECTOR_WEAPON_NAME, HOLO_PROJECTOR_INDEX )
	player.GiveOffhandWeapon( GENERIC_OFFHAND_WEAPON_NAME, GENERIC_OFFHAND_INDEX )

	player.ClearFirstDeployForAllWeapons()
	player.SetActiveWeaponBySlot( eActiveInventorySlot.mainHand, WEAPON_INVENTORY_SLOT_PRIMARY_0 )
	player.DeployWeapon()

	if ( IsValid( weaponNew ) && weaponNew.UsesClipsForAmmo() )
		weaponNew.SetWeaponPrimaryClipCount( weaponNew.GetWeaponPrimaryClipCountMax() )

	SetInfiniteAmmoForPlayer( player, true, [], true, true, true )
}

void function FS_Instagib_TeleportToSpawn( entity player )
{
	if ( !IsValid( player ) )
		return

	LocPair loc = FS_Instagib_PickSpawn( player )
	vector origin = loc.origin
	vector angles = loc.angles

	while ( angles.y > 180.0 )
		angles.y -= 360.0
	while ( angles.y < -180.0 )
		angles.y += 360.0

	player.SetVelocity( <0, 0, 0> )
	TeleportPlayerNoInterp( player, origin, true )
	player.SetAngles( angles )
	player.SnapEyeAngles( angles )
	player.SnapFeetToEyes()
	printt( "[FS-IG] spawn player=" + player.GetPlayerName() + " origin=" + string( origin ) )
}

LocPair function FS_Instagib_PickSpawn( entity player )
{
	array<LocPair> spawns = FS_Instagib_GetSpawnsForMap()
	if ( spawns.len() < 1 )
	{
		LocPair fallback
		fallback.origin = player.GetOrigin()
		fallback.angles = player.GetAngles()
		return fallback
	}

	array<LocPair> far
	foreach ( loc in spawns )
	{
		bool tooClose = false
		foreach ( entity other in GetPlayerArray_Alive() )
		{
			if ( !IsValid( other ) || other == player )
				continue
			if ( Distance( other.GetOrigin(), loc.origin ) < INSTAGIB_MIN_SPAWN_DIST )
			{
				tooClose = true
				break
			}
		}
		if ( !tooClose )
			far.append( loc )
	}

	if ( far.len() > 0 )
		return far[ RandomInt( far.len() ) ]
	return spawns[ RandomInt( spawns.len() ) ]
}

void function FS_Instagib_PlayerSpawn( entity player )
{
	if ( !IsValid( player ) )
		return

	player.kv.contents = CONTENTS_BULLETCLIP | CONTENTS_MONSTERCLIP | CONTENTS_HITBOX | CONTENTS_BLOCKLOS | CONTENTS_PHYSICSCLIP
	player.p.lastTimeUsedRailjump = -1.0

	FS_Instagib_ApplyMovement( player )

	// Survival only sets this when landing from the dropship, which instagib never does.
	SetPlayerCanGroundEmote( player, true )
}

void function FS_Instagib_SpawnImmunity_THREAD( entity player )
{
	if ( !IsValid( player ) )
		return

	EndSignal( player, "OnDestroy" )
	EndSignal( player, "OnDeath" )
	MakeInvincible( player )
	wait INSTAGIB_SPAWN_IMMUNITY
	if ( IsValid( player ) )
		ClearInvincible( player )
}

void function FS_Instagib_ResetPlayerStats( entity player )
{
	if ( !IsValid( player ) )
		return

	player.SetPlayerGameStat( PGS_KILLS, 0 )
	player.SetPlayerGameStat( PGS_DEATHS, 0 )
	player.SetPlayerNetInt( "kills", 0 )
	player.SetPlayerNetInt( "deaths", 0 )
	player.SetPlayerNetInt( "damage", 0 )
	player.SetPlayerNetInt( "damageDealt", 0 )
	player.p.railjumptimes = 0
	player.p.shotsfired = 0
	player.p.lastTimeUsedRailjump = -1.0
}
