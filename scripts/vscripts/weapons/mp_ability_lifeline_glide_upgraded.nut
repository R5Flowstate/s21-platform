global function UpgradedGlide_Init

global const string LIFELINE_UPGRADE_PAS_GLIDE_DURATION = "glide_extra_fuel"
global const string LIFELINE_UPGRADE_PAS_GLIDE_EXTRA_THRUSTER = "glide_extra_thruster"
global const string LIFELINE_UPGRADE_PAS_GLIDE_HANDLING = "glide_better_handling"

void function UpgradedGlide_Init()
{
	AddCallback_OnPassiveChanged( ePassives.PAS_MORE_GLIDE_DURATION, BoostedGlide_OnPassiveChanged )
	AddCallback_OnPassiveChanged( ePassives.PAS_GLIDE_EXTRA_THRUSTER, ExtraThrusterGlide_OnPassiveChanged )
	AddCallback_OnPassiveChanged( ePassives.PAS_GLIDE_BOOSTED_HANDLING, BoostedHandlingGlide_OnPassiveChanged )
}

void function BoostedGlide_OnPassiveChanged( entity player, int passive, bool didHave, bool nowHas )
{
	#if SERVER
		UpgradedGlide_SetMod( player, LIFELINE_UPGRADE_PAS_GLIDE_DURATION, didHave, nowHas )
	#endif
}

void function ExtraThrusterGlide_OnPassiveChanged( entity player, int passive, bool didHave, bool nowHas )
{
	#if SERVER
		UpgradedGlide_SetMod( player, LIFELINE_UPGRADE_PAS_GLIDE_EXTRA_THRUSTER, didHave, nowHas )
	#endif
}

void function BoostedHandlingGlide_OnPassiveChanged( entity player, int passive, bool didHave, bool nowHas )
{
	#if SERVER
		UpgradedGlide_SetMod( player, LIFELINE_UPGRADE_PAS_GLIDE_HANDLING, didHave, nowHas )
	#endif
}

#if SERVER
void function UpgradedGlide_SetMod( entity player, string mod, bool didHave, bool nowHas )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( nowHas && !didHave )
	{
		GivePlayerSettingsMods( player, [ mod ] )
		player.SetGlideMeter( player.GetPlayerSettingFloat( "glideDuration" ) )
	}
	else if ( didHave && !nowHas )
	{
		TakePlayerSettingsMods( player, [ mod ] )
		player.SetGlideMeter( min( player.GetGlideMeter(), player.GetPlayerSettingFloat( "glideDuration" ) ) )
	}
}
#endif
