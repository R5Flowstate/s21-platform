// 1v1 duel demos: each round of a match group is recorded when sv_demo_record allows it.

global function FS_Coaching_StartRecording
global function FS_Coaching_StopRecording
global function FS_Coaching_StopForGroup
global function FS_Coaching_OnDamage
global function FS_Coaching_GetAvailableMatchIdentifier

struct
{
	table<int, string> demoMatchIds
	table<int, float> demoNextDamageEvent
	int demoSerial = 0
} file

// Called by both duelists as they spawn into a round; the first call starts it.
void function FS_Coaching_StartRecording( entity player )
{
	if ( !IsValid( player ) )
		return

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( player )
	if ( !Gamemode1v1_IsMatchValid( group ) || !IsValid( group.player1 ) || !IsValid( group.player2 ) )
		return

	DemoMoment_Send( player, eDemoMoment.ROUND_START )

	if ( !Demo_ServerEnabled() )
		return
	if ( group.player1.IsBot() || group.player2.IsBot() )
		return

	if ( group.groupHandle in file.demoMatchIds && Demo_ServerIsRecording( file.demoMatchIds[ group.groupHandle ] ) )
		return

	file.demoSerial++
	string matchId = format( "%d_%d_%d", GetUnixTimestamp(), group.groupHandle, file.demoSerial )
	if ( !Demo_ServerStart( matchId, [ group.player1, group.player2 ] ) )
		return

	file.demoMatchIds[ group.groupHandle ] <- matchId
	Demo_ServerEvent( matchId, "round_start", null, null, "", 0.0 )
}

void function FS_Coaching_StopRecording( int matchIdentifier, entity victim, entity attacker )
{
	if ( !IsValid( victim ) )
		return

	MatchGroup group = Gamemode1v1_GetPlayerSoloGroup( victim )
	if ( !Gamemode1v1_IsMatchValid( group ) )
		return

	entity winner = null
	if ( IsValid( attacker ) && attacker.IsPlayer() && attacker != victim && ( attacker == group.player1 || attacker == group.player2 ) )
		winner = attacker
	else
		winner = ( victim == group.player1 ) ? group.player2 : group.player1

	DemoMoment_Send( victim, eDemoMoment.ROUND_LOST )
	DemoMoment_Send( winner, eDemoMoment.ROUND_WON )

	if ( !( group.groupHandle in file.demoMatchIds ) )
		return

	string matchId = file.demoMatchIds[ group.groupHandle ]
	Demo_ServerEvent( matchId, "kill", IsValid( winner ) ? winner : null, victim, FS_Coaching_WeaponOf( winner ), 0.0 )
	FS_Coaching_StopForGroup( group, winner, "kill" )
}

void function FS_Coaching_StopForGroup( MatchGroup group, entity winner, string reason )
{
	if ( !( group.groupHandle in file.demoMatchIds ) )
		return

	string matchId = file.demoMatchIds[ group.groupHandle ]
	delete file.demoMatchIds[ group.groupHandle ]
	if ( !Demo_ServerIsRecording( matchId ) )
		return

	Demo_ServerEvent( matchId, "round_end", null, null, "", 0.0 )
	Demo_ServerStop( matchId, IsValid( winner ) && winner.IsPlayer() ? winner : null, reason )
}

// One damage marker per attacker per 100 ms keeps the timeline readable.
void function FS_Coaching_OnDamage( MatchGroup group, entity attacker, entity victim, string weapon, float damage )
{
	if ( !( group.groupHandle in file.demoMatchIds ) || !IsValid( attacker ) )
		return

	int key = attacker.GetEncodedEHandle()
	float now = Time()
	if ( key in file.demoNextDamageEvent && now < file.demoNextDamageEvent[ key ] )
		return
	file.demoNextDamageEvent[ key ] <- now + 0.1

	Demo_ServerEvent( file.demoMatchIds[ group.groupHandle ], "damage", attacker, IsValid( victim ) ? victim : null, weapon, damage )
}

string function FS_Coaching_WeaponOf( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return ""
	entity weapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	return IsValid( weapon ) ? weapon.GetWeaponClassName() : ""
}

int function FS_Coaching_GetAvailableMatchIdentifier()
{
	return file.demoSerial
}
