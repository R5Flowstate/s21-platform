// Flowstate Scenarios: a legend pick per fight. Each fight runs the retail
// lockstep on its own players while other fights play; the pick clock lives on
// each player (charselect_per_player_state), and the server alone decides locks.

global function FS_Scenarios_CharSelect_Init
global function FS_Scenarios_RunCharacterSelect
global function FS_Scenarios_CharSelect_Duration
global function FS_Scenarios_AssignTeamUniqueLegends
global function FS_Scenarios_ApplyLegend
global function FS_Scenarios_ClearPickLock

// a start time already reached skips the menu's pre-pick countdown
const float PICK_INTRO = 0.5
const float PICK_AFTER_LOCK = 0.5
const float PICK_OUTRO = 1.5

struct
{
	float timePerPick
} file

void function FS_Scenarios_CharSelect_Init()
{
	file.timePerPick = max( 1.0, GetCurrentPlaylistVarFloat( "fs_scenarios_characterselect_time_per_player", 3.5 ) )

	if ( !CharSelect_UsesPlayerState() )
		Warning( "[FS-SCN][CHARSEL] playlist is missing charselect_per_player_state 1; picks will not open per fight" )
}

float function FS_Scenarios_CharSelect_Duration( int pickCount )
{
	return PICK_INTRO + pickCount * ( file.timePerPick + PICK_AFTER_LOCK ) + PICK_OUTRO
}

void function FS_Scenarios_RunCharacterSelect( ScenariosGroup group )
{
	group.dummyEnt.EndSignal( "OnDestroy" )
	group.dummyEnt.EndSignal( "FS_Scenarios_GroupEnd" )

	array<entity> members = FS_Scenarios_GetGroupMembers( group )

	OnThreadEnd(
		function() : ( members )
		{
			foreach ( entity player in members )
				FS_Scenarios_ClosePick( player )
		}
	)

	int pickCount = 0
	foreach ( ScenariosTeam team in group.teams )
		pickCount = maxint( pickCount, team.players.len() )

	float pickStart = Time()
	float pickEnd = pickStart + pickCount * ( file.timePerPick + PICK_AFTER_LOCK ) + PICK_OUTRO

	foreach ( ScenariosTeam team in group.teams )
	{
		array<entity> order = clone team.players
		order.randomize()
		foreach ( int i, entity player in order )
		{
			if ( !IsValid( player ) )
				continue

			Gamemode1v1_SetPlayerGamestate( player, e1v1State.CHARSELECT )
			player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_LOCK_STEP_PLAYER_INDEX, i )
			player.SetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER, false )
			FS_Scenarios_ClearPickFocus( player )
			player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), -1 )
			player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( "pickLoadoutGamestateStartTime" ), pickStart )
			player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( "pickLoadoutGamestateEndTime" ), pickEnd )
			player.SetPlayerNetBool( CharSelect_PlayerStateNetVar( "characterSelectionReady" ), true )
		}
	}

	FS_Scenarios_Hud_SendPhase( group, eScenariosHudPhase.PICK, pickStart, pickEnd, -1.0 )

	wait PICK_INTRO

	for ( int pick = 0; pick < pickCount; pick++ )
	{
		float stepStart = Time()
		float stepEnd = stepStart + file.timePerPick

		foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
		{
			player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_START_TIME ), stepStart )
			player.SetPlayerNetTime( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_END_TIME ), stepEnd )
			player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), pick )
		}

		wait file.timePerPick

		foreach ( ScenariosTeam team in group.teams )
		{
			foreach ( entity player in team.players )
			{
				if ( IsValid( player ) && player.GetPlayerNetInt( CHARACTER_SELECT_NETVAR_LOCK_STEP_PLAYER_INDEX ) == pick )
					FS_Scenarios_FinalizePick( player, team )
			}
		}

		wait PICK_AFTER_LOCK
	}

	foreach ( entity player in FS_Scenarios_GetGroupMembers( group ) )
		player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), pickCount )

	wait PICK_OUTRO
}

void function FS_Scenarios_ClosePick( entity player )
{
	if ( !IsValid( player ) )
		return

	player.SetPlayerNetBool( CharSelect_PlayerStateNetVar( "characterSelectionReady" ), false )
	player.SetPlayerNetInt( CharSelect_PlayerStateNetVar( CHARACTER_SELECT_NETVAR_LOCK_STEP_INDEX ), -1 )
	player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_LOCK_STEP_PLAYER_INDEX, -1 )
	FS_Scenarios_ClearPickFocus( player )
}

// Hover focus is global and outlives the pick; left set, the menu draws last
// fight's hover as a teammate's claim.
void function FS_Scenarios_ClearPickFocus( entity player )
{
	player.SetPlayerNetInt( CHARACTER_SELECT_NETVAR_FOCUS_CHARACTER_GUID, -1 )
	player.SetPlayerNetInt( "characterSelectFocusSkinGUID", -1 )
}

// The lock flag outlives the fight; left set, the next squad's menu shows this
// player's old legend as taken.
void function FS_Scenarios_ClearPickLock( entity player )
{
	player.SetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER, false )
	FS_Scenarios_ClearPickFocus( player )
}

// A player who did not lock keeps their loadout legend unless a teammate
// already took it.
void function FS_Scenarios_FinalizePick( entity player, ScenariosTeam team )
{
	if ( player.GetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER ) )
		return

	ItemFlavor character = FS_Scenarios_PickFreeLegend( player, team )
	SetItemFlavorLoadoutSlot( ToEHI( player ), Loadout_Character(), character )
	player.SetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER, true )
	player.SetPlayerNetTime( CHARACTER_SELECT_NETVAR_LOCKED_IN_CHARACTER_TIME, Time() )
}

void function FS_Scenarios_AssignTeamUniqueLegends( ScenariosGroup group )
{
	foreach ( ScenariosTeam team in group.teams )
	{
		foreach ( entity player in team.players )
			player.SetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER, false )

		foreach ( entity player in team.players )
		{
			if ( IsValid( player ) )
				FS_Scenarios_FinalizePick( player, team )
		}
	}
}

array<ItemFlavor> function FS_Scenarios_TakenLegends( entity player, ScenariosTeam team )
{
	array<ItemFlavor> taken
	foreach ( entity teammate in team.players )
	{
		if ( teammate == player || !IsValid( teammate ) )
			continue
		if ( !teammate.GetPlayerNetBool( CHARACTER_SELECT_NETVAR_HAS_LOCKED_IN_CHARACTER ) )
			continue

		EHI ehi = ToEHI( teammate )
		if ( LoadoutSlot_IsReady( ehi, Loadout_Character() ) )
			taken.append( LoadoutSlot_GetItemFlavor( ehi, Loadout_Character() ) )
	}
	return taken
}

bool function FS_Scenarios_IsPickableLegend( entity player, ItemFlavor character )
{
	if ( ItemFlavor_GetType( character ) != eItemType.character || ItemFlavor_GetAsset( character ) == CHARACTER_RANDOM )
		return false
	if ( CharacterClass_IsBlockedForCurrentPlaylist( character ) )
		return false
	return IsItemFlavorUnlockedForLoadoutSlot( ToEHI( player ), Loadout_Character(), character )
}

ItemFlavor function FS_Scenarios_PickFreeLegend( entity player, ScenariosTeam team )
{
	array<ItemFlavor> taken = FS_Scenarios_TakenLegends( player, team )

	EHI ehi = ToEHI( player )
	if ( LoadoutSlot_IsReady( ehi, Loadout_Character() ) )
	{
		ItemFlavor current = LoadoutSlot_GetItemFlavor( ehi, Loadout_Character() )
		if ( FS_Scenarios_IsPickableLegend( player, current ) && !taken.contains( current ) )
			return current
	}

	array<ItemFlavor> free
	foreach ( ItemFlavor character in GetAllCharacters() )
	{
		if ( FS_Scenarios_IsPickableLegend( player, character ) && !taken.contains( character ) )
			free.append( character )
	}

	if ( free.len() > 0 )
		return free.getrandom()

	return FS_1v1_ResolveCharacter( player, -1 )
}

// Full legend: setfile, tactical, ultimate and passives.
void function FS_Scenarios_ApplyLegend( entity player )
{
	ItemFlavor character = FS_1v1_ResolveCharacter( player, -1 )
	SetItemFlavorLoadoutSlot( ToEHI( player ), Loadout_Character(), character )
	Survival_PlayerCharacterSetup( player, character, false )
	FS_1v1_ApplyPlayerCamo( player )
	player.Server_TurnOffhandWeaponsDisabledOff()

}
