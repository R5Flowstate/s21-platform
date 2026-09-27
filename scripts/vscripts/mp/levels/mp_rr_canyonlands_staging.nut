global function CodeCallback_MapInit

void function CodeCallback_MapInit()
{
	PrecacheModel( MU1_LEVIATHAN_MODEL )

	Canyonlands_MapInit_Common()
	AddSpawnCallback_ScriptName( "leviathan_staging", CreateClientSideLeviathanMarkers )

	// alternate leviathan placements for other story phases of this build
	AddSpawnCallback_ScriptName( "leviathan_staging_p1", DestroyUnusedLeviathan )
	AddSpawnCallback_ScriptName( "leviathan_staging_p2", DestroyUnusedLeviathan )

	RunMySurvivalPreprocess()
}


void function CreateClientSideLeviathanMarkers( entity leviathan )
{
	leviathan.EndSignal( "OnDestroy" )

	vector leviathanOrigin = leviathan.GetOrigin()
	vector leviathanAngles = leviathan.GetAngles()

	entity ent = CreatePropDynamic_NoDispatchSpawn( $"mdl/dev/empty_model.rmdl", leviathanOrigin, leviathanAngles )
	SetTargetName( ent, leviathan.GetScriptName() )
	DispatchSpawn( ent )

	leviathan.Destroy()

	ent.EndSignal( "OnDestroy" )

	wait 3.0

	ent.Destroy()
}

void function DestroyUnusedLeviathan( entity leviathan )
{
	leviathan.Destroy()
}
