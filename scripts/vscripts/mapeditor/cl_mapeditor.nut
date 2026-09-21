// Map editor client: build-mode ghost, placement math, and bind surface.

global function MapEditor_ClientInit
global function MapEditor_SetSelectedModel
global function MapEditor_IsModelOffered
global function UIToClient_MapEditor_SetModel
global function ServerCallback_MapEdit_PackLoad

// Physical keys for the editor-only verbs, so they need no bind. Chosen from
// keys Apex leaves unbound by default -- a key callback fires alongside
// whatever else that key happens to be bound to. Client-only: the KEY_ enum
// does not exist in the server VM, so these cannot live in the shared file.
const int MAPEDIT_KEY_TOGGLE  = KEY_F6
const int MAPEDIT_KEY_NOCLIP  = KEY_F7
const int MAPEDIT_KEY_YAW_CCW = KEY_LBRACKET
const int MAPEDIT_KEY_YAW_CW  = KEY_RBRACKET
const int MAPEDIT_KEY_WHOIS   = KEY_F8

// Frame size as authored in hudscripted_mp.res, scaled to the real resolution.
const float MAPEDIT_PANEL_WIDE = 320.0
const float MAPEDIT_PANEL_TALL = 406.0

struct
{
	bool   buildMode = false
	entity ghost
	int    catalogId = 0
	bool   modelDirty = false
	float  zOffset = 0.0
	vector angleOffset = <0, 0, 0>
	int    snapIndex = 0
	vector lastOrigin = <0, 0, 0>
	vector lastAngles = <0, 0, 0>
	bool   hasPlacement = false
	// 0 = no grid snap
	array< float > snapSizes
	bool   noclipOn = false
	bool   ziplinePending = false
	bool   autoStarted = false
	// Drawn preview transform; eases toward the placement target every frame.
	vector smoothOrigin = <0, 0, 0>
	vector smoothNormal = <0, 0, 1>
	vector smoothForward = <1, 0, 0>
	bool   smoothValid = false
	// Catalog ids we PrecacheModel'd this map (client has no ModelIsPrecached).
	table< int, bool > offeredIds
	int activePackMask = 0
	bool netRegistered = false
} file

void function MapEditor_ClientInit()
{
	MapEdit_ClientRegisterNetworking()

	if ( !MapEditor_IsEnabled() )
		return

	MapEditorCatalog_Init()

	file.snapSizes = [ 0.0, 1.0, 4.0, 16.0, 64.0, 128.0, 256.0 ]
	file.ghost = null
	file.buildMode = false
	file.catalogId = 0
	file.modelDirty = false
	file.zOffset = 0.0
	file.angleOffset = <0, 0, 0>
	file.snapIndex = 0
	file.hasPlacement = false
	file.autoStarted = false
	file.offeredIds = {}
	file.activePackMask = 0
	MapEditorCatalog_SetActivePackMask( 0 )
	file.smoothValid = false

	// Ghost / SetModel fallback; must always be safe for CreateClientSidePropDynamic.
	PrecacheModel( $"mdl/dev/empty_model.rmdl" )

	string mapName = GetMapName()
	array< MapEditorCatalogEntry > available = MapEdit_CollectMapAvailableOrdered_Client( mapName )
	int availableCount = available.len()
	int attempted = 0

	foreach ( MapEditorCatalogEntry entry in available )
	{
		if ( attempted >= MAPEDIT_PRECACHE_MAX )
			break

		PrecacheModel( entry.model )
		file.offeredIds[ entry.id ] <- true
		attempted++
	}

	printt( format( "[MAPEDIT] client precache map=%s available=%d attempted=%d cap=%d",
		mapName, availableCount, attempted, MAPEDIT_PRECACHE_MAX ) )

	MapEdit_SelectDefaultModel()

	RegisterSignal( "MapEdit_BuildModeOff" )

	// Permanent toggle -- not deregistered when build mode ends.
	RegisterButtonPressedCallback( MAPEDIT_KEY_TOGGLE, MapEdit_OnToggleBuildModeKey )

	// Local player may not exist at init; auto-start when they respawn.
	AddCallback_OnYouRespawned( MapEdit_OnYouRespawned )
	// If already alive (callback already fired before our register), start now.
	if ( IsValid( GetLocalClientPlayer() ) )
		MapEdit_OnYouRespawned()

	printt( format( "[MAPEDIT] client init, catalog=%d, defaultId=%d, map=%s, offered=%d",
		MapEditorCatalog_Count(), file.catalogId, mapName, attempted ) )
}

// ---------------------------------------------------------------------------
// Model selection (menu hook)
// ---------------------------------------------------------------------------

bool function MapEditor_IsModelOffered( int catalogId )
{
	return ( catalogId in file.offeredIds )
}

void function MapEditor_SetSelectedModel( int catalogId )
{
	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( catalogId )
	if ( entryOrNull == null )
	{
		printt( "[MAPEDIT] SetSelectedModel: unknown catalog id " + string( catalogId ) )
		return
	}

	MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
	string mapName = GetMapName()
	if ( !MapEditorCatalog_IsAvailableOnMap( entry, mapName ) )
	{
		printt( format( "[MAPEDIT] SetSelectedModel: id %d not available on map %s", catalogId, mapName ) )
		entity rejectPlayer = GetLocalClientPlayer()
		if ( IsValid( rejectPlayer ) )
			AnnouncementMessageRight( rejectPlayer, format( "Model not on %s", mapName ), "", <1, 1, 1>, $"", 3.0 )
		return
	}

	if ( !MapEditor_IsModelOffered( catalogId ) )
	{
		printt( format( "[MAPEDIT] SetSelectedModel: id %d not offered (not precached)", catalogId ) )
		entity rejectPlayer = GetLocalClientPlayer()
		if ( IsValid( rejectPlayer ) )
			AnnouncementMessageRight( rejectPlayer, "Model not precached", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	file.catalogId = catalogId
	file.modelDirty = true
	MapEdit_RefreshPanel()

	entity player = GetLocalClientPlayer()
	if ( IsValid( player ) )
		AnnouncementMessageRight( player, format( "Model %d: %s", catalogId, entry.category ), "", <1, 1, 1>, $"", 3.0 )
}

void function UIToClient_MapEditor_SetModel( int catalogId )
{
	MapEditor_SetSelectedModel( catalogId )
}

void function MapEdit_SelectDefaultModel()
{
	file.catalogId = 0
	file.modelDirty = false

	string mapName = GetMapName()
	array< MapEditorCatalogEntry > ordered = MapEdit_CollectMapAvailableOrdered_Client( mapName )
	foreach ( MapEditorCatalogEntry entry in ordered )
	{
		if ( !MapEditor_IsModelOffered( entry.id ) )
			continue

		file.catalogId = entry.id
		file.modelDirty = true
		printt( format( "[MAPEDIT] default model id=%d on map %s", entry.id, mapName ) )
		return
	}

	printt( format( "[MAPEDIT] no offered catalog model on map %s; no default selected", mapName ) )
}

// Same order as server: build-tier by id, then extra-tier by id.
array< MapEditorCatalogEntry > function MapEdit_CollectMapAvailableOrdered_Client( string mapName )
{
	array< MapEditorCatalogEntry > buildList
	array< MapEditorCatalogEntry > extraList

	foreach ( string category in MapEditorCatalog_GetCategoriesByTier( "build" ) )
	{
		array< MapEditorCatalogEntry > entries = MapEditorCatalog_GetAvailableCategoryEntries( category, mapName )
		foreach ( MapEditorCatalogEntry entry in entries )
			buildList.append( entry )
	}

	foreach ( string category in MapEditorCatalog_GetCategoriesByTier( "extra" ) )
	{
		array< MapEditorCatalogEntry > entries = MapEditorCatalog_GetAvailableCategoryEntries( category, mapName )
		foreach ( MapEditorCatalogEntry entry in entries )
			extraList.append( entry )
	}

	buildList.sort( MapEdit_CompareCatalogId_Client )
	extraList.sort( MapEdit_CompareCatalogId_Client )

	array< MapEditorCatalogEntry > result
	foreach ( MapEditorCatalogEntry entry in buildList )
		result.append( entry )
	foreach ( MapEditorCatalogEntry entry in extraList )
		result.append( entry )

	return result
}

int function MapEdit_CompareCatalogId_Client( MapEditorCatalogEntry a, MapEditorCatalogEntry b )
{
	if ( a.id < b.id )
		return -1
	if ( a.id > b.id )
		return 1
	return 0
}

// ---------------------------------------------------------------------------
// Extra map packs -- server sends a catalog bit, the name comes from our own
// catalog copy. The model browser reads availability live, so updating the
// mask is the menu refresh.
// ---------------------------------------------------------------------------

void function MapEdit_ClientRegisterNetworking()
{
	if ( file.netRegistered )
		return
	file.netRegistered = true

	Remote_RegisterClientFunction( "ServerCallback_MapEdit_PackLoad", "int", 0, 31 )
	Remote_RegisterServerFunction( "MapEdit_SV_PackReady", "int", 0, 31 )
}

void function ServerCallback_MapEdit_PackLoad( int bit )
{
	MapEditorCatalog_Init()

	if ( bit < 0 || bit > 31 )
	{
		printt( "[MAPEDIT] PackLoad: bit out of range" )
		return
	}

	string name = MapEditorCatalog_GetMapNameForBit( bit )
	if ( name == "" )
	{
		printt( format( "[MAPEDIT] PackLoad: unknown bit %d", bit ) )
		return
	}

	if ( ( file.activePackMask & ( 1 << bit ) ) != 0 )
	{
		printt( format( "[MAPEDIT] PackLoad: bit %d (%s) already active", bit, name ) )
		return
	}

	if ( !MapEdit_RequestMapPak( name ) )
	{
		printt( format( "[MAPEDIT] PackLoad: load rejected for %s", name ) )
		return
	}

	printt( format( "[MAPEDIT] PackLoad: loading %s bit=%d", name, bit ) )
	thread MapEdit_ClientPackLoadThread( bit, name )
}

void function MapEdit_ClientPackLoadThread( int bit, string name )
{
	float deadline = Time() + 60.0

	while ( Time() < deadline )
	{
		int status = MapEdit_MapPakStatus( name )
		if ( status == 1 )
		{
			MapEdit_ClientPrecachePack( bit )
			file.activePackMask = file.activePackMask | ( 1 << bit )
			MapEditorCatalog_SetActivePackMask( file.activePackMask )
			RunUIScript( "UI_MapEditor_SetActivePackMask", file.activePackMask )

			if ( file.catalogId == 0 )
				MapEdit_SelectDefaultModel()
			MapEdit_RefreshPanel()

			Remote_ServerCallFunction( "MapEdit_SV_PackReady", bit )

			printt( format( "[MAPEDIT] client pack loaded: %s bit=%d mask=%d", name, bit, file.activePackMask ) )
			return
		}

		if ( status == -1 )
		{
			printt( format( "[MAPEDIT] client pack load failed: %s bit=%d", name, bit ) )
			return
		}

		wait 0.25
	}

	printt( format( "[MAPEDIT] client pack load timed out: %s bit=%d", name, bit ) )
}

void function MapEdit_ClientPrecachePack( int bit )
{
	int flag = 1 << bit
	int attempted = 0

	foreach ( string category in MapEditorCatalog_GetCategories() )
	{
		if ( attempted >= MAPEDIT_PACK_PRECACHE_MAX )
			break

		foreach ( MapEditorCatalogEntry entry in MapEditorCatalog_GetCategoryEntries( category ) )
		{
			if ( attempted >= MAPEDIT_PACK_PRECACHE_MAX )
				break

			if ( ( entry.mapMask & flag ) == 0 )
				continue

			if ( entry.id in file.offeredIds )
				continue

			PrecacheModel( entry.model )
			file.offeredIds[ entry.id ] <- true
			attempted++
		}
	}

	printt( format( "[MAPEDIT] client pack precache bit=%d attempted=%d cap=%d",
		bit, attempted, MAPEDIT_PACK_PRECACHE_MAX ) )
}

// ---------------------------------------------------------------------------
// Build mode toggle
// ---------------------------------------------------------------------------

void function MapEdit_OnToggleBuildMode( entity player )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.buildMode )
		MapEdit_ExitBuildMode( player )
	else
		MapEdit_EnterBuildMode( player )
}

// Fires when the local client player is ready (same callback as cl_spectator_mode_audio).
void function MapEdit_OnYouRespawned()
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( file.autoStarted )
		return

	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	file.autoStarted = true

	if ( file.buildMode )
		return

	MapEdit_EnterBuildMode( player )
	AnnouncementMessageRight( player, "Build mode auto-on (toggle: F6)", "", <1, 1, 1>, $"", 5.0 )
	printt( "[MAPEDIT] auto-started build mode on spawn; toggle with F6" )
}

void function MapEdit_EnterBuildMode( entity player )
{
	if ( file.buildMode )
		return

	file.buildMode = true
	file.zOffset = 0.0
	file.angleOffset = <0, 0, 0>
	file.hasPlacement = false

	MapEdit_CreateGhost()
	MapEdit_RegisterBuildBinds()
	MapEdit_ShowPanel()

	if ( IsValid( player ) && IsValid( file.ghost ) )
		thread MapEdit_GhostUpdateThread( player, file.ghost )

	AnnouncementMessageRight( player, "Build mode ON", "", <1, 1, 1>, $"", 3.0 )
	printt( "[MAPEDIT] build mode on" )
}

void function MapEdit_ExitBuildMode( entity player )
{
	if ( !file.buildMode )
		return

	file.buildMode = false
	MapEdit_DeregisterBuildBinds()
	MapEdit_HidePanel()

	// Leaving mid-zipline would strand the anchor on the server.
	if ( file.ziplinePending && IsValid( player ) )
		player.ClientCommand( "mapedit_zipline_cancel" )
	file.ziplinePending = false

	if ( IsValid( player ) )
		player.Signal( "MapEdit_BuildModeOff" )

	if ( IsValid( file.ghost ) )
	{
		file.ghost.Destroy()
		file.ghost = null
	}

	file.hasPlacement = false

	if ( IsValid( player ) )
		AnnouncementMessageRight( player, "Build mode OFF", "", <1, 1, 1>, $"", 3.0 )
	printt( "[MAPEDIT] build mode off" )
}

// ---------------------------------------------------------------------------
// Bind registration (symmetric with deregistration)
// ---------------------------------------------------------------------------

// Every action below is a real bindable S21 ConCommand, so it follows
// whatever the player set. The legend kit is deliberately untouched:
// +offhand1 (tactical), +offhand4 (ultimate), +melee, +scriptCommand4 (heal),
// +ping, +jump, +duck, +use and +speed are never hooked, so abilities and
// movement keep working. Everything here is also released on build mode off.
void function MapEdit_RegisterBuildBinds()
{
	RegisterConCommandTriggeredCallback( "+attack", MapEdit_OnPlace )
	RegisterConCommandTriggeredCallback( "+reload", MapEdit_OnDelete )
	// Switch fire mode: an editor has no fire modes to switch.
	RegisterConCommandTriggeredCallback( "+scriptCommand3", MapEdit_OnUndo )
	RegisterConCommandTriggeredCallback( "+weaponCycle", MapEdit_OnRedo )
	RegisterConCommandTriggeredCallback( "weaponSelectPrimary0", MapEdit_OnRaise )
	RegisterConCommandTriggeredCallback( "weaponSelectPrimary1", MapEdit_OnLower )
	RegisterConCommandTriggeredCallback( "+use_alt", MapEdit_OnCycleSnap )
	// Gib shield toggle: cosmetic, and nothing in the editor uses it.
	RegisterConCommandTriggeredCallback( "+scriptCommand5", MapEdit_OnZiplineAnchor )
	RegisterConCommandTriggeredCallback( "weapon_inspect", MapEdit_OnOpenModelBrowser )

	// Noclip / yaw / whois are editor-only; Apex leaves these keys unbound.
	RegisterButtonPressedCallback( MAPEDIT_KEY_NOCLIP, MapEdit_OnToggleNoclipKey )
	RegisterButtonPressedCallback( MAPEDIT_KEY_YAW_CCW, MapEdit_OnRotateYawCCWKey )
	RegisterButtonPressedCallback( MAPEDIT_KEY_YAW_CW, MapEdit_OnRotateYawCWKey )
	RegisterButtonPressedCallback( MAPEDIT_KEY_WHOIS, MapEdit_OnWhoisKey )
}

void function MapEdit_DeregisterBuildBinds()
{
	DeregisterConCommandTriggeredCallback( "+attack", MapEdit_OnPlace )
	DeregisterConCommandTriggeredCallback( "+reload", MapEdit_OnDelete )
	DeregisterConCommandTriggeredCallback( "+scriptCommand3", MapEdit_OnUndo )
	DeregisterConCommandTriggeredCallback( "+weaponCycle", MapEdit_OnRedo )
	DeregisterConCommandTriggeredCallback( "weaponSelectPrimary0", MapEdit_OnRaise )
	DeregisterConCommandTriggeredCallback( "weaponSelectPrimary1", MapEdit_OnLower )
	DeregisterConCommandTriggeredCallback( "+use_alt", MapEdit_OnCycleSnap )
	DeregisterConCommandTriggeredCallback( "+scriptCommand5", MapEdit_OnZiplineAnchor )
	DeregisterConCommandTriggeredCallback( "weapon_inspect", MapEdit_OnOpenModelBrowser )

	DeregisterButtonPressedCallback( MAPEDIT_KEY_NOCLIP, MapEdit_OnToggleNoclipKey )
	DeregisterButtonPressedCallback( MAPEDIT_KEY_YAW_CCW, MapEdit_OnRotateYawCCWKey )
	DeregisterButtonPressedCallback( MAPEDIT_KEY_YAW_CW, MapEdit_OnRotateYawCWKey )
	DeregisterButtonPressedCallback( MAPEDIT_KEY_WHOIS, MapEdit_OnWhoisKey )
}

// ---------------------------------------------------------------------------
// Raw-key entry points (button callbacks pass the button, not the player)
// ---------------------------------------------------------------------------

void function MapEdit_OnToggleBuildModeKey( var button )
{
	MapEdit_OnToggleBuildMode( GetLocalClientPlayer() )
}

void function MapEdit_OnToggleNoclipKey( var button )
{
	MapEdit_OnToggleNoclip( GetLocalClientPlayer() )
}

void function MapEdit_OnRotateYawCCWKey( var button )
{
	MapEdit_RotateYaw( GetLocalClientPlayer(), -1 )
}

void function MapEdit_OnRotateYawCWKey( var button )
{
	MapEdit_RotateYaw( GetLocalClientPlayer(), 1 )
}

void function MapEdit_OnWhoisKey( var button )
{
	MapEdit_OnWhois( GetLocalClientPlayer() )
}

// ---------------------------------------------------------------------------
// Bind panel
// ---------------------------------------------------------------------------

var function MapEdit_HudElementOrNull( string name )
{
	try
	{
		return HudElement( name )
	}
	catch ( errHud )
	{
		printt( format( "[MAPEDIT] missing HUD element '%s': %s", name, string( errHud ) ) )
		return null
	}
}

void function MapEdit_SetPanelVisible( bool visible )
{
	array< string > names = [ MAPEDIT_HUD_FRAME, MAPEDIT_HUD_TITLE, MAPEDIT_HUD_STATUS ]
	for ( int i = 0; i < MAPEDIT_HUD_HINT_COUNT; i++ )
		names.append( MAPEDIT_HUD_HINT_PREFIX + string( i ) )

	foreach ( string name in names )
	{
		var elem = MapEdit_HudElementOrNull( name )
		if ( elem == null )
			continue

		Hud_SetVisible( elem, visible )
		Hud_SetEnabled( elem, visible )
	}
}

void function MapEdit_ShowPanel()
{
	MapEdit_SetPanelVisible( true )

	// Row text is authored in the .res; only the frame needs a runtime size,
	// since its .res values are a 1080p reference layout.
	var frame = MapEdit_HudElementOrNull( MAPEDIT_HUD_FRAME )
	if ( frame != null )
	{
		UISize screenSize = GetScreenSize()
		float resMultiplier = screenSize.height / 1080.0
		Hud_SetSize( frame, MAPEDIT_PANEL_WIDE * resMultiplier, MAPEDIT_PANEL_TALL * resMultiplier )
	}

	MapEdit_RefreshPanel()
}

void function MapEdit_HidePanel()
{
	MapEdit_SetPanelVisible( false )
}

void function MapEdit_RefreshPanel()
{
	if ( !file.buildMode )
		return

	var status = MapEdit_HudElementOrNull( MAPEDIT_HUD_STATUS )
	if ( status == null )
		return

	string modelName = "none"
	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
	if ( entryOrNull != null )
	{
		MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
		modelName = entry.category + " #" + string( entry.id )
	}

	float snapSize = MapEdit_GetSnapSize()
	string snapText = "off"
	if ( snapSize > 0.0 )
		snapText = string( int( snapSize ) )

	Hud_SetText( status, format( "%s  |  snap %s  |  z %+d  |  yaw %d",
		modelName, snapText, int( file.zOffset ), int( file.angleOffset.y ) ) )
}

// ---------------------------------------------------------------------------
// Ghost
// ---------------------------------------------------------------------------

void function MapEdit_CreateGhost()
{
	if ( IsValid( file.ghost ) )
	{
		file.ghost.Destroy()
		file.ghost = null
	}

	// Only offered (precached) models may reach CreateClientSidePropDynamic.
	asset model = $"mdl/dev/empty_model.rmdl"
	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
	if ( entryOrNull != null )
	{
		MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
		string mapName = GetMapName()
		if ( MapEditorCatalog_IsAvailableOnMap( entry, mapName ) && MapEditor_IsModelOffered( entry.id ) )
		{
			model = entry.model
		}
		else
		{
			printt( format( "[MAPEDIT] ghost: id %d not offered/available on %s; using empty_model",
				file.catalogId, mapName ) )
		}
	}

	entity ghost = CreateClientSidePropDynamic( <0, 0, 0>, <0, 0, 0>, model )
	if ( !IsValid( ghost ) )
	{
		printt( "[MAPEDIT] CreateClientSidePropDynamic failed" )
		return
	}

	// Same setup the other client-side props in this tree use. A render mode is
	// deliberately not set: glow mode leaves the model invisible, and fadedist
	// must be -1 or the prop fades out at close range.
	ghost.kv.solid          = 0 // NotSolid() is SERVER-only at compile
	ghost.kv.fadedist       = -1
	ghost.kv.disableshadows = 1
	Highlight_SetNeutralHighlight( ghost, "survival_item_rare" )

	file.ghost = ghost
	file.modelDirty = false
	file.smoothValid = false
}

void function MapEdit_GhostUpdateThread( entity player, entity ghost )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "MapEdit_BuildModeOff" )
	ghost.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( ghost )
		{
			if ( IsValid( ghost ) )
				ghost.Destroy()
			if ( file.ghost == ghost )
				file.ghost = null
		}
	)

	bool logged = false

	while ( file.buildMode && IsValid( ghost ) && IsValid( player ) )
	{
		MapEdit_UpdateGhost( player, ghost )

		// One line on the first tick: says where the preview actually went, so an
		// invisible preview can be told apart from one placed somewhere unexpected.
		if ( !logged )
		{
			logged = true
			printt( format( "[MAPEDIT] ghost first tick: origin %s eye %s model %s",
				string( ghost.GetOrigin() ), string( player.EyePosition() ),
				string( ghost.GetModelName() ) ) )
		}

		WaitFrame()
	}
}

void function MapEdit_UpdateGhost( entity player, entity ghost )
{
	if ( !IsValid( player ) || !IsValid( ghost ) )
		return

	// 1. Camera ray, not EyePosition/GetViewVector: those only advance on a
	// simulation tick, so a per-frame update would still step at tick rate.
	vector eye = player.CameraPosition()
	vector forward = AnglesToForward( player.CameraAngles() )
	vector end = eye + forward * MAPEDIT_TRACE_DIST
	TraceResults result = TraceLine( eye, end, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )

	// 2. Miss places at ray end.
	vector origin = result.endPos

	// 3. Align to surface, then compose user pitch/yaw/roll offsets.
	vector normal = <0, 0, 1>
	if ( result.fraction < 1.0 )
		normal = result.surfaceNormal

	vector angles = AnglesCompose( AnglesOnSurface( normal, forward ), file.angleOffset )

	// Model change only when selection actually changed.
	if ( file.modelDirty )
	{
		asset model = $"mdl/dev/empty_model.rmdl"
		MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
		if ( entryOrNull != null )
		{
			MapEditorCatalogEntry entry = expect MapEditorCatalogEntry( entryOrNull )
			string mapName = GetMapName()
			if ( MapEditorCatalog_IsAvailableOnMap( entry, mapName ) && MapEditor_IsModelOffered( entry.id ) )
			{
				model = entry.model
			}
			else
			{
				printt( format( "[MAPEDIT] SetModel: id %d not offered/available on %s; using empty_model",
					file.catalogId, mapName ) )
			}
		}
		ghost.SetModel( model )
		file.modelDirty = false
		// New bbox: let the preview jump straight to the new resting spot.
		file.smoothValid = false
	}

	ghost.SetAngles( angles )

	// 4. Bbox lift so the lowest point rests on the surface.
	vector mins = ghost.GetBoundingMins()
	float zLift = -mins.z
	origin.z += zLift
	origin.z += file.zOffset

	// 5. Grid snap after surface offset; re-apply lift + Z so snap cannot bury.
	float snapSize = MapEdit_GetSnapSize()
	if ( snapSize > 0.0 )
	{
		origin.x = MapEdit_SnapCoord( origin.x, snapSize )
		origin.y = MapEdit_SnapCoord( origin.y, snapSize )
		float snappedSurfaceZ = MapEdit_SnapCoord( result.endPos.z, snapSize )
		origin.z = snappedSurfaceZ + zLift + file.zOffset
	}

	// 6. Never add a raw view vector to the origin.

	// Placement uses the raw target; only what is drawn is eased.
	file.lastOrigin = origin
	file.lastAngles = angles
	file.hasPlacement = true

	MapEdit_DrawGhostEased( ghost, origin, normal, forward )
}

// Easing the surface normal and the view forward rather than the composed
// angles keeps the preview from spinning the long way round when the trace
// crosses between two faces.
void function MapEdit_DrawGhostEased( entity ghost, vector origin, vector normal, vector forward )
{
	if ( !file.smoothValid || Distance( file.smoothOrigin, origin ) > MAPEDIT_GHOST_CUT_DIST )
	{
		file.smoothOrigin = origin
		file.smoothNormal = normal
		file.smoothForward = forward
		file.smoothValid = true
	}
	else
	{
		float frac = MapEdit_EaseFraction()
		file.smoothOrigin = file.smoothOrigin + ( origin - file.smoothOrigin ) * frac
		file.smoothNormal = MapEdit_EaseDirection( file.smoothNormal, normal, frac )
		file.smoothForward = MapEdit_EaseDirection( file.smoothForward, forward, frac )
	}

	ghost.SetOrigin( file.smoothOrigin )
	ghost.SetAngles( AnglesCompose( AnglesOnSurface( file.smoothNormal, file.smoothForward ), file.angleOffset ) )
}

float function MapEdit_EaseFraction()
{
	float dt = FrameTime()
	if ( dt <= 0.0 || MAPEDIT_GHOST_SMOOTH_TIME <= 0.0 )
		return 1.0

	float frac = dt / MAPEDIT_GHOST_SMOOTH_TIME
	if ( frac > 1.0 )
		return 1.0
	return frac
}

vector function MapEdit_EaseDirection( vector from, vector to, float frac )
{
	vector blend = from + ( to - from ) * frac
	// Exactly opposed directions cancel; take the target rather than normalize 0.
	if ( Length( blend ) < 0.001 )
		return to
	return Normalize( blend )
}

float function MapEdit_GetSnapSize()
{
	if ( file.snapIndex < 0 || file.snapIndex >= file.snapSizes.len() )
		return 0.0
	return file.snapSizes[file.snapIndex]
}

float function MapEdit_SnapCoord( float value, float grid )
{
	if ( grid <= 0.0 )
		return value
	return floor( ( value / grid ) + 0.5 ) * grid
}

// ---------------------------------------------------------------------------
// Place / delete / undo
// ---------------------------------------------------------------------------

void function MapEdit_OnPlace( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.catalogId <= 0 )
	{
		AnnouncementMessageRight( player, "No model selected", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	MapEditorCatalogEntry ornull entryOrNull = MapEditorCatalog_GetEntry( file.catalogId )
	if ( entryOrNull == null )
	{
		AnnouncementMessageRight( player, "Invalid model id", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	if ( !MapEditor_IsModelOffered( file.catalogId ) )
	{
		AnnouncementMessageRight( player, "Model not precached", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	if ( !file.hasPlacement )
	{
		AnnouncementMessageRight( player, "No placement yet", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	vector origin = file.lastOrigin
	vector angles = file.lastAngles
	vector eye = player.EyePosition()

	if ( Distance( eye, origin ) > MAPEDIT_MAX_PLACE_DIST )
	{
		AnnouncementMessageRight( player, "Too far to place", "", <1, 1, 1>, $"", 3.0 )
		return
	}

	string cmd = format( "mapedit_place %d %.2f %.2f %.2f %.2f %.2f %.2f",
		file.catalogId,
		origin.x, origin.y, origin.z,
		angles.x, angles.y, angles.z )

	player.ClientCommand( cmd )
}

void function MapEdit_OnDelete( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_delete" )
}

void function MapEdit_OnUndo( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_undo" )
}

void function MapEdit_OnRedo( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_redo" )
}

void function MapEdit_OnWhois( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	player.ClientCommand( "mapedit_whois" )
}

void function MapEdit_OnToggleNoclip( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	// Same path as the model viewer: engine "noclip" client command.
	player.ClientCommand( "noclip" )
	file.noclipOn = !file.noclipOn

	if ( file.noclipOn )
		AnnouncementMessageRight( player, "Noclip ON", "", <1, 1, 1>, $"", 2.0 )
	else
		AnnouncementMessageRight( player, "Noclip OFF", "", <1, 1, 1>, $"", 2.0 )
}

// One action drives both ends: the server already refuses an end without a
// start anchor, so alternating here matches the state it keeps.
void function MapEdit_OnZiplineAnchor( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.ziplinePending )
	{
		player.ClientCommand( "mapedit_zipline_end" )
		file.ziplinePending = false
		AnnouncementMessageRight( player, "Zipline placed", "", <1, 1, 1>, $"", 2.0 )
	}
	else
	{
		player.ClientCommand( "mapedit_zipline_start" )
		file.ziplinePending = true
		AnnouncementMessageRight( player, "Zipline start set -- press again for the far end", "", <1, 1, 1>, $"", 3.0 )
	}
}

// ---------------------------------------------------------------------------
// Adjustments
// ---------------------------------------------------------------------------

void function MapEdit_RotateYaw( entity player, int dir )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	// Squirrel: only local vector components are assignable -- reassign whole vector.
	float yaw = file.angleOffset.y + float( MAPEDIT_ANGLE_STEP * dir )
	while ( yaw >= 360.0 )
		yaw -= 360.0
	while ( yaw < 0.0 )
		yaw += 360.0
	file.angleOffset = <file.angleOffset.x, yaw, file.angleOffset.z>
	MapEdit_RefreshPanel()

	AnnouncementMessageRight( player, format( "Yaw offset %d", int( yaw ) ), "", <1, 1, 1>, $"", 3.0 )
}

void function MapEdit_OnCycleSnap( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	if ( file.snapSizes.len() == 0 )
		return

	file.snapIndex = ( file.snapIndex + 1 ) % file.snapSizes.len()
	float size = MapEdit_GetSnapSize()
	MapEdit_RefreshPanel()

	if ( size <= 0.0 )
		AnnouncementMessageRight( player, "Snap: off", "", <1, 1, 1>, $"", 3.0 )
	else
		AnnouncementMessageRight( player, format( "Snap: %d", int( size ) ), "", <1, 1, 1>, $"", 3.0 )
}

void function MapEdit_OnRaise( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	file.zOffset = clamp( file.zOffset + MAPEDIT_Z_STEP, -MAPEDIT_Z_LIMIT, MAPEDIT_Z_LIMIT )
	MapEdit_RefreshPanel()
}

void function MapEdit_OnLower( entity player )
{
	if ( !file.buildMode )
		return

	if ( !IsValid( player ) || player != GetLocalClientPlayer() )
		return

	file.zOffset = clamp( file.zOffset - MAPEDIT_Z_STEP, -MAPEDIT_Z_LIMIT, MAPEDIT_Z_LIMIT )
	MapEdit_RefreshPanel()
}

void function MapEdit_OnOpenModelBrowser( entity player )
{
	if ( !file.buildMode )
		return

	RunUIScript( "OpenMapEditorModelMenu" )
}
