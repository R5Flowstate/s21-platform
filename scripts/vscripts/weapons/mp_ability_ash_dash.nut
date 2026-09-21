global function MpAbilityAshDash_Init

global function AshDashEnabled

#if CLIENT
global function ServerToClient_Ash_OnPlayerDash
global function ServerToClient_Ash_OnPlayerLanded
global function ServerToSpectator_Ash_OnPlayerDash
global function ServerToSpectator_Ash_OnPlayerLanded
#endif

const asset FX_ASH_DASH_HUD = $"P_ash_player_boost_screen"
const string RUI_ASH_DASH_METER = "ui/ash_dash_meter.rpak"

const string KILL_DASH_FX_SIGNAL = "ash_dash_fx"

const bool ASH_DASH_HOLSTER_WEAPONS = false
const bool ASH_DASH_BREAKS_CLOAK = true
const bool ASH_DASH_FLIP_LEFT_RIGHT_VFX = true

const string ASH_DASH_MOD = "ash_dash"
const string ASH_DASH_UPGRADE_MOD = "ash_dash_upgrade"

struct
{
	int numberOfDashCharges = 1
	var dashPassiveRui
} file

bool function AshDashEnabled()
{
	return GetCurrentPlaylistVarBool( "ash_passive_dash_enabled", true )
}

array<string> function AshDash_GetMods()
{
	array<string> mods = [ ASH_DASH_MOD ]
	if ( GetCurrentPlaylistVarBool( "ash_dash_two_charges", false ) )
		mods.append( ASH_DASH_UPGRADE_MOD )
	return mods
}

void function MpAbilityAshDash_Init()
{
	if ( !AshDashEnabled() )
		return

	PrecacheParticleSystem( FX_ASH_DASH_HUD )

	RegisterSignal( KILL_DASH_FX_SIGNAL )

	Remote_RegisterClientFunction( "ServerToClient_Ash_OnPlayerDash" )
	Remote_RegisterClientFunction( "ServerToClient_Ash_OnPlayerLanded" )
	Remote_RegisterClientFunction( "ServerToSpectator_Ash_OnPlayerDash" )
	Remote_RegisterClientFunction( "ServerToSpectator_Ash_OnPlayerLanded" )

#if CLIENT
	AddCallback_OnPassiveChanged( ePassives.PAS_PAS_UPGRADE_TWO, AshDash_OnUpgradeChanged )

	AddCallback_CreatePlayerPassiveRui( AshDash_CreatePassiveRui )
	AddCallback_DestroyPlayerPassiveRui( AshDash_DestroyPassiveRui )
#endif

#if SERVER
	AddCallback_OnPassiveChanged( ePassives.PAS_ASH, AshDash_OnPassiveChanged )
	AddCallback_OnPlayerRespawned( AshDash_OnPlayerRespawned )
#endif
}

#if CLIENT
void function AshDash_OnUpgradeChanged( entity player, int passive, bool didHave, bool nowHas )
{
	if ( !IsValid( GetLocalClientPlayer() ) || player != GetLocalClientPlayer() )
		return

	if ( !PlayerHasPassive( player, ePassives.PAS_ASH ) )
		return

	if ( didHave && !nowHas )
	{
		file.numberOfDashCharges = 1
	}
	else if ( nowHas && !didHave )
	{
		file.numberOfDashCharges = 2
	}
}
#endif

#if SERVER
void function AshDash_OnPassiveChanged( entity player, int passive, bool didHave, bool nowHas )
{
	if ( !IsValid( player ) )
		return

	if ( nowHas )
	{
		AshDash_ApplyForPlayer( player )
	}
	else if ( didHave )
	{
		array<string> mods = player.GetPlayerSettingsMods()
		array<string> take
		foreach ( string mod in AshDash_GetMods() )
		{
			if ( mods.contains( mod ) )
				take.append( mod )
		}
		if ( take.len() > 0 )
			TakePlayerSettingsMods( player, take )

		if ( HasPlayerMovementEventCallback( player, ePlayerMovementEvents.DODGE, AshDash_OnPlayerDodge ) )
			RemovePlayerMovementEventCallback( player, ePlayerMovementEvents.DODGE, AshDash_OnPlayerDodge )
		if ( HasPlayerMovementEventCallback( player, ePlayerMovementEvents.TOUCH_GROUND, AshDash_OnPlayerLanded ) )
			RemovePlayerMovementEventCallback( player, ePlayerMovementEvents.TOUCH_GROUND, AshDash_OnPlayerLanded )
	}
}

void function AshDash_OnPlayerRespawned( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( !PlayerHasPassive( player, ePassives.PAS_ASH ) )
		return

	AshDash_ApplyForPlayer( player )
}

void function AshDash_ApplyForPlayer( entity player )
{
	array<string> mods = player.GetPlayerSettingsMods()
	array<string> give
	foreach ( string mod in AshDash_GetMods() )
	{
		if ( !mods.contains( mod ) )
			give.append( mod )
	}
	if ( give.len() > 0 )
		GivePlayerSettingsMods( player, give )

	printt( format( "[ASH-DASH] %s settings=%s mods=%s dodgeAvail=%s", player.GetPlayerName(), string( player.GetPlayerSettings() ),
		ArrayToString( player.GetPlayerSettingsMods() ), string( player.IsClassModAvailableForPlayerSetting( string( player.GetPlayerSettings() ), ASH_DASH_MOD ) ) ) )

	if ( !HasPlayerMovementEventCallback( player, ePlayerMovementEvents.DODGE, AshDash_OnPlayerDodge ) )
		AddPlayerMovementEventCallback( player, ePlayerMovementEvents.DODGE, AshDash_OnPlayerDodge )
	if ( !HasPlayerMovementEventCallback( player, ePlayerMovementEvents.TOUCH_GROUND, AshDash_OnPlayerLanded ) )
		AddPlayerMovementEventCallback( player, ePlayerMovementEvents.TOUCH_GROUND, AshDash_OnPlayerLanded )
}

void function AshDash_OnPlayerDodge( entity player )
{
	if ( !IsValid( player ) )
		return

	Remote_CallFunction_Replay( player, "ServerToClient_Ash_OnPlayerDash" )

	foreach ( entity spectator in GetPlayerArrayOfTeam( TEAM_SPECTATOR ) )
	{
		if ( IsValid( spectator ) && spectator.GetObserverTarget() == player )
			Remote_CallFunction_Replay( spectator, "ServerToClient_Ash_OnPlayerDash" )
	}
}

void function AshDash_OnPlayerLanded( entity player )
{
	if ( !IsValid( player ) )
		return

	Remote_CallFunction_Replay( player, "ServerToClient_Ash_OnPlayerLanded" )

	foreach ( entity spectator in GetPlayerArrayOfTeam( TEAM_SPECTATOR ) )
	{
		if ( IsValid( spectator ) && spectator.GetObserverTarget() == player )
			Remote_CallFunction_Replay( spectator, "ServerToClient_Ash_OnPlayerLanded" )
	}
}
#endif

#if CLIENT
void function ServerToClient_Ash_OnPlayerDash()
{
	entity player = GetLocalViewPlayer()

	if ( AshDash_HasDash( player ) )
	{
		thread AshDash_ScreenFx_Thread( player )
	}
}

void function ServerToClient_Ash_OnPlayerLanded()
{
	entity player = GetLocalViewPlayer()

	if ( AshDash_HasDash( player ) )
	{
		AshDash_OnLanded( player )
	}
}

void function ServerToSpectator_Ash_OnPlayerDash()
{
	ServerToClient_Ash_OnPlayerDash()
}

void function ServerToSpectator_Ash_OnPlayerLanded()
{
	ServerToClient_Ash_OnPlayerLanded()
}

void function AshDash_OnLanded( entity player )
{
	if ( IsValid( player ) )
	{
		if ( player == GetLocalViewPlayer() )
		{
			Signal( player, KILL_DASH_FX_SIGNAL )
		}
	}
}

void function AshDash_ScreenFx_Thread( entity player )
{
	Signal( player, KILL_DASH_FX_SIGNAL )

	EndSignal( player, "OnDeath", "OnDestroy", KILL_DASH_FX_SIGNAL )

	PassByReferenceInt fxHandle
	OnThreadEnd(
		function(): ( player, fxHandle )
		{
			if ( EffectDoesExist( fxHandle.value ) )
				EffectStop( fxHandle.value, false, true )
		}
	)

	fxHandle.value = StartParticleEffectOnEntity( player.GetCockpit(), GetParticleSystemIndex( FX_ASH_DASH_HUD ), FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID)
	EffectSetIsWithCockpit( fxHandle.value, true )

	WaitEndFrame()

	vector velocityAngles = VectorToAngles( FlattenNormalizeVec( player.GetVelocity() ) )
	vector entAngles    = player.EyeAngles()

	float damageYaw = (velocityAngles.y + 180) - entAngles.y

	damageYaw = AngleNormalize( damageYaw )

	if ( damageYaw < 0 )
		damageYaw += 360

	if ( damageYaw < 45 )
	{
		EffectSetControlPointVector( fxHandle.value, 1, <0,0,0> )
		EffectSetControlPointVector( fxHandle.value, 2, <0,0,0> )
		EffectSetControlPointVector( fxHandle.value, 3, <1,0,0> )
	}
	else if ( damageYaw < 135 )
	{
		if ( ASH_DASH_FLIP_LEFT_RIGHT_VFX )
		{
			EffectSetControlPointVector( fxHandle.value, 1, <1,0,0> )
			EffectSetControlPointVector( fxHandle.value, 2, <0,0,0> )
		}
		else
		{
			EffectSetControlPointVector( fxHandle.value, 1, <0,0,0> )
			EffectSetControlPointVector( fxHandle.value, 2, <1,0,0> )
		}
		EffectSetControlPointVector( fxHandle.value, 3, <0,0,0> )
	}
	else if ( damageYaw < 225 )
	{
		EffectSetControlPointVector( fxHandle.value, 1, <1,0,0> )
		EffectSetControlPointVector( fxHandle.value, 2, <1,0,0> )
		EffectSetControlPointVector( fxHandle.value, 3, <1,0,0> )
	}
	else if ( damageYaw < 315 )
	{
		if ( ASH_DASH_FLIP_LEFT_RIGHT_VFX )
		{
			EffectSetControlPointVector( fxHandle.value, 1, <0,0,0> )
			EffectSetControlPointVector( fxHandle.value, 2, <1,0,0> )
		}
		else
		{
			EffectSetControlPointVector( fxHandle.value, 1, <1,0,0> )
			EffectSetControlPointVector( fxHandle.value, 2, <0,0,0> )
		}
		EffectSetControlPointVector( fxHandle.value, 3, <0,0,0> )
	}
	else
	{
		EffectSetControlPointVector( fxHandle.value, 1, <0,0,0> )
		EffectSetControlPointVector( fxHandle.value, 2, <0,0,0> )
		EffectSetControlPointVector( fxHandle.value, 3, <1,0,0> )
	}

	wait 1
}

void function AshDash_CreatePassiveRui( entity player )
{
	if ( !AshDash_HasDash( player ) )
		return

	if ( file.dashPassiveRui == null )
	{
		asset meter = GetKeyValueAsAsset( { kn = RUI_ASH_DASH_METER }, "kn" )
		file.dashPassiveRui = CreateCockpitRui( meter, 32000 )

		RuiTrackFloat( file.dashPassiveRui, "bleedoutEndTime", player, RUI_TRACK_SCRIPT_NETWORK_VAR, GetNetworkedVariableIndex( "bleedoutEndTime" ) )
		RuiTrackFloat( file.dashPassiveRui, "reviveEndTime", player, RUI_TRACK_SCRIPT_NETWORK_VAR, GetNetworkedVariableIndex( "reviveEndTime" ) )
		RuiSetBool( file.dashPassiveRui, "hasUnlimitedDash", false )
		RuiSetFloat( file.dashPassiveRui, "forceOffsetLeftRight", 0.0 )
		RuiSetBool( file.dashPassiveRui, "hasAltCooldownSourceForShowHide", false )
	}

	bool twoDashes = PlayerHasPassive( player, ePassives.PAS_PAS_UPGRADE_TWO )
	file.numberOfDashCharges = twoDashes ? 2 : 1

	thread AshDash_DisplayCounter( player )
}

void function AshDash_DestroyPassiveRui( entity player )
{
	if ( !AshDash_HasDash( player ) )
	{
		if ( file.dashPassiveRui != null )
		{
			RuiDestroyIfAlive( file.dashPassiveRui )
			file.dashPassiveRui = null
		}
	}
}

void function AshDash_DisplayCounter( entity player )
{
	player.EndSignal( "OnDeath", "OnDestroy" )

	while ( file.dashPassiveRui != null && IsValid( player ) )
	{
		RuiSetInt( file.dashPassiveRui, "numDashSegments", file.numberOfDashCharges )
		RuiSetFloat( file.dashPassiveRui, "dashFrac", player.GetSuitPower() / 100.0 )

		WaitFrame()
	}
}

bool function AshDash_HasDash( entity player )
{
	if ( !IsValid( player ) )
		return false

	return PlayerHasPassive( player, ePassives.PAS_ASH )
}
#endif
