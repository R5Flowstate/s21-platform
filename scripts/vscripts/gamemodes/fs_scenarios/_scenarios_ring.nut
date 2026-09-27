// Flowstate Scenarios: one native ring per fight. The deathfield index is the
// fight's realm slot, and a hidden deathField mover in that realm is what the
// client binds the ring wall and minimap circle to.

global function FS_Scenarios_Ring_Init
global function FS_Scenarios_Ring_MaxCloseTime
global function FS_Scenarios_Ring_RadiusForLocation
global function FS_Scenarios_Ring_Publish
global function FS_Scenarios_Ring_Damage_THREAD
global function FS_Scenarios_Ring_Clear
global function FS_Scenarios_Ring_ClearPlayer

// Units per second the ring closes at closing speed 1.0.
const float RING_BASE_CLOSE_SPEED = 20.0
const float RING_MIN_CLOSE_TIME = 30.0

struct
{
	float radiusPadding
	float closingSpeed
	float maxCloseTime
	float damage
	float damageStep
	table<int, entity> movers
} file

void function FS_Scenarios_Ring_Init()
{
	file.radiusPadding = GetCurrentPlaylistVarFloat( "fs_scenarios_default_radius_padding", 500.0 )
	file.closingSpeed = max( 0.05, GetCurrentPlaylistVarFloat( "fs_scenarios_zonewars_ring_ringclosingspeed", 1.0 ) )
	file.maxCloseTime = GetCurrentPlaylistVarFloat( "fs_scenarios_ringclosing_maxtime", 100.0 )
	file.damage = GetCurrentPlaylistVarFloat( "fs_scenarios_ring_damage", 25.0 )
	file.damageStep = max( 0.25, GetCurrentPlaylistVarFloat( "fs_scenarios_ring_damage_step_time", 1.5 ) )
}

float function FS_Scenarios_Ring_MaxCloseTime()
{
	return max( RING_MIN_CLOSE_TIME, file.maxCloseTime )
}

float function FS_Scenarios_Ring_RadiusForLocation( LocationsData loc )
{
	float radius = 0.0
	foreach ( LocPair spawn in loc.respawnLocations )
		radius = max( radius, Distance2D( spawn.origin, loc.Center ) )
	return radius + file.radiusPadding
}

void function FS_Scenarios_Ring_Publish( ScenariosGroup group, float liveStart )
{
	float closeTime = group.ringRadius / ( RING_BASE_CLOSE_SPEED * file.closingSpeed )
	closeTime = clamp( closeTime, RING_MIN_CLOSE_TIME, max( RING_MIN_CLOSE_TIME, file.maxCloseTime ) )
	group.ringStartTime = liveStart
	group.ringCloseTime = liveStart + closeTime

	int index = group.slotIndex
	FS_Scenarios_Ring_DestroyMover( index )

	entity mover = CreateEntity( "script_mover" )
	mover.SetValueForModelKey( $"mdl/dev/empty_model.rmdl" )
	mover.kv.SpawnAsPhysicsMover = 0
	mover.kv.fadedist = -1
	mover.kv.solid = 0
	mover.SetOrigin( group.center )
	mover.SetAngles( <0, 0, 0> )
	mover.NotSolid()
	mover.Hide()
	mover.DisableHibernation()
	mover.SetScriptName( "deathField" )
	mover.RemoveFromAllRealms()
	mover.AddToRealm( index )
	SetTargetName( mover, "deathField" )
	DispatchSpawn( mover )
	file.movers[ index ] <- mover

	SetDeathFieldParams( group.center, group.ringRadius, 0.0, liveStart, group.ringCloseTime, index )

	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
	{
		player.SetDeathFieldIndex( index )
		player.SetPlayerNetTime( "FS_Scenarios_RingCloseTime", group.ringCloseTime )
	}
}

void function FS_Scenarios_Ring_Damage_THREAD( ScenariosGroup group )
{
	group.dummyEnt.EndSignal( "OnDestroy" )
	group.dummyEnt.EndSignal( "FS_Scenarios_GroupEnding" )

	int ticks = 0
	while ( group.phase == eScenariosPhase.LIVE )
	{
		wait file.damageStep

		// Damage from an attacker that shares no realm with the victim is dropped by the
		// engine; a null attacker is the world, which only lives in the lobby realm.
		entity source = group.slotIndex in file.movers ? file.movers[ group.slotIndex ] : null
		if ( !IsValid( source ) )
			continue

		foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
		{
			if ( !IsAlive( player ) || player.IsPhaseShifted() )
				continue
			if ( Distance2D( player.GetOrigin(), group.center ) < FS_Scenarios_Ring_RadiusAt( group, Time() ) )
				continue

			player.TakeDamage( file.damage, source, source, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
			FS_Scenarios_AddScore( player, FS_ScoreType.PENALTY_RING )

			if ( ticks++ < 8 )
				printt( format( "[FS-SCN][RING] tick %s handle=%d dmg=%.0f hp=%d", player.GetPlayerName(), group.groupHandle, file.damage, player.GetHealth() ) )
		}
	}
}

// Same shrink the ring was published with, evaluated here so damage never depends on
// which ring index a native query resolves.
float function FS_Scenarios_Ring_RadiusAt( ScenariosGroup group, float time )
{
	float span = group.ringCloseTime - group.ringStartTime
	if ( span <= 0.0 )
		return 0.0

	float frac = clamp( ( time - group.ringStartTime ) / span, 0.0, 1.0 )
	return group.ringRadius * ( 1.0 - frac )
}

void function FS_Scenarios_Ring_Clear( ScenariosGroup group, array<entity> members )
{
	int index = group.slotIndex
	if ( index < 1 )
		return

	FS_Scenarios_Ring_DestroyMover( index )
	SetDeathFieldParams( <0, 0, 0>, RING_DISABLED_RADIUS, RING_DISABLED_RADIUS, 90000, RING_DISABLED_RADIUS, index )

	foreach ( entity player in members )
		FS_Scenarios_Ring_ClearPlayer( player )
}

void function FS_Scenarios_Ring_ClearPlayer( entity player )
{
	if ( !IsValid( player ) )
		return

	player.SetDeathFieldIndex( 0 )
	player.SetPlayerNetTime( "FS_Scenarios_RingCloseTime", -1 )
}

void function FS_Scenarios_Ring_DestroyMover( int index )
{
	if ( !( index in file.movers ) )
		return

	if ( IsValid( file.movers[ index ] ) )
		file.movers[ index ].Destroy()
	delete file.movers[ index ]
}
