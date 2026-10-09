global function SurfFpsCap_Init

// Air movement is frame-time sensitive; above this rate the client's prediction
// drifts from the server.
const int SURF_FPS_CAP = 300

struct
{
	bool capped = false
	int playerFpsMax = 0
} file

void function SurfFpsCap_Init()
{
	AddUICallback_LevelLoadingFinished( SurfFpsCap_OnLevelLoaded )
	AddUICallback_LevelShutdown( SurfFpsCap_Restore )
	AddUICallback_UIShutdown( SurfFpsCap_Restore )
}

void function SurfFpsCap_OnLevelLoaded()
{
	if ( GetActiveLevel().find( "__surf_" ) == -1 )
	{
		SurfFpsCap_Restore()
		return
	}
	if ( file.capped )
		return

	int fpsMax = GetConVarInt( "fps_max" )
	if ( fpsMax > 0 && fpsMax <= SURF_FPS_CAP )
		return

	file.playerFpsMax = fpsMax
	file.capped = true
	SetConVarInt( "fps_max", SURF_FPS_CAP )
}

// Leaves the player's value alone if they changed it while on the map.
void function SurfFpsCap_Restore()
{
	if ( !file.capped )
		return

	file.capped = false
	if ( GetConVarInt( "fps_max" ) == SURF_FPS_CAP )
		SetConVarInt( "fps_max", file.playerFpsMax )
}
