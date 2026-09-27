// Map editor model preview: while the browser is open the main view is a menu
// camera frozen at the player's eye, so the level stays behind the menu and the
// selected model renders at full screen resolution. The browser leaves its preview
// rect clear and the model floats on the ray through that rect, close enough to
// clear nearby walls and scaled to fit; zoom and true scale are scale changes.
// Depth of field blurs everything past the model. Spin and drag turn the model;
// the lights stay with the camera.

global function MapEditPreview_Init
global function UIToClient_MapEditPreview_Open
global function UIToClient_MapEditPreview_Close
global function UIToClient_MapEditPreview_SetModel
global function UIToClient_MapEditPreview_Orbit
global function UIToClient_MapEditPreview_Pan
global function UIToClient_MapEditPreview_Zoom
global function UIToClient_MapEditPreview_SetOptions
global function UIToClient_MapEditPreview_Reset
global function UIToClient_MapEditPreview_SetRect
global function MapEditPreview_Debug

const float PREVIEW_FOV = 70.0
const float PREVIEW_FIT_MARGIN = 1.08
const float PREVIEW_MODEL_DIST = 100.0
// Closest the model may come when a wall is in the way.
const float PREVIEW_MODEL_DIST_MIN = 16.0
// Depth of field: sharp to this multiple of the model distance, fully soft by the end.
const float PREVIEW_DOF_START = 1.6
const float PREVIEW_DOF_END = 700.0
// Auto-fit frames the model as seen from this tilt, so dragging does not rescale it.
const float PREVIEW_FIT_PITCH = 18.0
// Radius used for light placement around the studio.
const float PREVIEW_STUDIO_RADIUS = 24.0
// True scale shows a model this radius (units) at the auto-fit size.
const float PREVIEW_TRUE_SCALE_RADIUS = 256.0
const float PREVIEW_SPIN_DEG_PER_SEC = 26.0
const float PREVIEW_PITCH_MIN = -85.0
const float PREVIEW_PITCH_MAX = 60.0
const float PREVIEW_ZOOM_MIN = 0.35
const float PREVIEW_ZOOM_MAX = 4.0
const float PREVIEW_STATE_INTERVAL = 0.1
// Specials (jump pad, door, loot bin) are not in the catalog the server sizes; they share this box.
const vector PREVIEW_FALLBACK_MINS = <-48, -48, 0>
const vector PREVIEW_FALLBACK_MAXS = <48, 48, 96>
const asset PREVIEW_EMPTY_MODEL = $"mdl/dev/empty_model.rmdl"

struct
{
	bool   inited = false
	bool   open = false
	bool   live = false
	entity prop
	entity camera
	array< entity > lights

	asset  model = $"mdl/dev/empty_model.rmdl"
	int    catalogId = -1
	int    specialId = 0
	bool   modelChanged = false
	float  yaw = 35.0
	float  pitch = -18.0
	float  zoom = 1.0
	vector pan = <0, 0, 0>
	float  spinYaw = 0.0
	bool   spin = true
	bool   autoFit = true
	int    lightPreset = 0
	// Preview rect as fractions of the screen: x, y, w, h.
	float  rectX = 0.53
	float  rectY = 0.11
	float  rectW = 0.45
	float  rectH = 0.61

	float  lastStateTime = 0.0
	// Unscaled studio bounds of the current model. A client-side prop has no
	// collision bounds (GetBoundingMins is zero), so these come from the server.
	vector mins = <0, 0, 0>
	vector maxs = <0, 0, 0>
	bool   boundsKnown = false
	float  lastScale = 1.0
	float  pixelsPerTan = 0.0
	table  signalDummy
} file

void function MapEditPreview_Init()
{
	if ( file.inited )
		return
	file.inited = true
	RegisterSignal( "MapEditPreview_Close" )
	PrecacheModel( PREVIEW_EMPTY_MODEL )
}

// ---------------------------------------------------------------------------
// UI entry points
// ---------------------------------------------------------------------------

void function UIToClient_MapEditPreview_Open()
{
	MapEditPreview_SetSelection( -1, 0 )
	if ( file.open )
	{
		MapEditPreview_PushLive()
		return
	}

	file.open = true
	thread MapEditPreview_Thread()
}

void function UIToClient_MapEditPreview_Close()
{
	if ( !file.open )
		return
	file.open = false
	Signal( file.signalDummy, "MapEditPreview_Close" )
}

void function UIToClient_MapEditPreview_SetModel( int catalogId, int specialId )
{
	MapEditPreview_SetSelection( catalogId, specialId )
}

void function UIToClient_MapEditPreview_Orbit( float dYaw, float dPitch )
{
	file.yaw = MapEditPreview_WrapDeg( file.yaw + dYaw )
	file.pitch = clamp( file.pitch + dPitch, PREVIEW_PITCH_MIN, PREVIEW_PITCH_MAX )
}

// dx/dy are fractions of the preview height, so a drag feels the same at any zoom.
void function UIToClient_MapEditPreview_Pan( float dx, float dy )
{
	file.pan = < clamp( file.pan.x + dx, -1.5, 1.5 ), clamp( file.pan.y + dy, -1.5, 1.5 ), 0 >
}

void function UIToClient_MapEditPreview_Zoom( float factor )
{
	if ( factor <= 0.0 )
		return
	file.zoom = clamp( file.zoom * factor, PREVIEW_ZOOM_MIN, PREVIEW_ZOOM_MAX )
}

void function UIToClient_MapEditPreview_SetOptions( bool spin, bool autoFit, int lightPreset )
{
	file.spin = spin
	file.autoFit = autoFit
	file.lightPreset = ( lightPreset < 0 || lightPreset > 2 ) ? 0 : lightPreset
}

void function UIToClient_MapEditPreview_SetRect( float x, float y, float w, float h )
{
	file.rectX = clamp( x, 0.0, 1.0 )
	file.rectY = clamp( y, 0.0, 1.0 )
	file.rectW = clamp( w, 0.05, 1.0 )
	file.rectH = clamp( h, 0.05, 1.0 )
}

void function UIToClient_MapEditPreview_Reset()
{
	file.yaw = 35.0
	file.pitch = -18.0
	file.zoom = 1.0
	file.pan = <0, 0, 0>
	file.spinYaw = 0.0
	file.autoFit = true
}

// ---------------------------------------------------------------------------
// Studio lifetime
// ---------------------------------------------------------------------------

void function MapEditPreview_SetSelection( int catalogId, int specialId )
{
	file.catalogId = specialId > 0 ? -1 : catalogId
	file.specialId = specialId
	MapEditPreview_ResolveModel()
}

// A model the server has not precached yet resolves to the empty model until it lands.
void function MapEditPreview_ResolveModel()
{
	asset model = MapEditor_PreviewModelFor( file.catalogId, file.specialId )
	if ( model == file.model )
		return
	file.model = model
	file.modelChanged = true
}

void function MapEditPreview_Thread()
{
	EndSignal( file.signalDummy, "MapEditPreview_Close" )

	OnThreadEnd(
		function() : ()
		{
			MapEditPreview_Teardown()
		}
	)

	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		WaitForever()

	vector eye = player.EyePosition()
	vector eyeAng = player.EyeAngles()
	vector camAng = < eyeAng.x, eyeAng.y, 0 >
	vector ahead = eye + AnglesToForward( camAng ) * PREVIEW_MODEL_DIST

	entity prop = CreateClientSidePropDynamic( ahead, <0, 0, 0>, file.model )
	prop.kv.fadedist = -1
	prop.MakeSafeForUIScriptHack()
	file.prop = prop
	file.modelChanged = true

	file.camera = CreateClientSidePointCamera( eye, camAng, PREVIEW_FOV )

	for ( int i = 0; i < 3; i++ )
		file.lights.append( CreateClientSideDynamicLight( ahead, <0, 0, 0>, <1, 1, 1>, 0.0 ) )

	player.SetMenuCameraEntity( file.camera )
	file.live = true
	// The same switch full-screen dialogs use to take the main HUD down.
	clGlobal.isSoloDialogMenuOpen = true
	UpdateMainHudVisibility( player )
	MapEdit_SetHudSuppressed( true )

	MapEditPreview_PushLive()

	while ( file.open )
	{
		MapEditPreview_Frame()
		WaitFrame()
	}
}

void function MapEditPreview_Teardown()
{
	if ( file.live )
	{
		file.live = false
		DoF_SetFarDepthToDefault()
		clGlobal.isSoloDialogMenuOpen = false
		MapEdit_SetHudSuppressed( false )
		entity player = GetLocalClientPlayer()
		if ( IsValid( player ) )
		{
			player.ClearMenuCameraEntity()
			UpdateMainHudVisibility( player )
		}
	}
	foreach ( entity light in file.lights )
	{
		if ( IsValid( light ) )
			light.Destroy()
	}
	file.lights.clear()
	if ( IsValid( file.camera ) )
		file.camera.Destroy()
	if ( IsValid( file.prop ) )
		file.prop.Destroy()
	file.camera = null
	file.prop = null

	file.open = false
	RunUIScript( "UI_MapEditPreview_OnSlot", -1 )
}

// The browser reads any slot >= 0 as "the 3D view is live, clear the preview rect".
void function MapEditPreview_PushLive()
{
	if ( file.live )
		RunUIScript( "UI_MapEditPreview_OnSlot", 0 )
}

// ---------------------------------------------------------------------------
// Per frame
// ---------------------------------------------------------------------------

void function MapEditPreview_Frame()
{
	entity prop = file.prop
	entity camera = file.camera
	if ( !IsValid( prop ) || !IsValid( camera ) )
		return

	MapEditPreview_ResolveModel()
	if ( file.modelChanged )
	{
		file.modelChanged = false
		prop.SetModel( file.model )
		StreamModelHint( file.model )
	}

	bool waiting = file.catalogId >= 0 && file.model == PREVIEW_EMPTY_MODEL
	bool resident = !waiting && StreamModelIsResident( file.model )
	MapEditPreview_ResolveBounds()
	if ( file.spin )
		file.spinYaw = MapEditPreview_WrapDeg( file.spinYaw + PREVIEW_SPIN_DEG_PER_SEC * FrameTime() )

	vector camPos = camera.GetOrigin()
	vector camAng = camera.GetAngles()
	vector fwd = AnglesToForward( camAng )
	vector right = AnglesToRight( camAng )
	vector up = AnglesToUp( camAng )

	// Where the preview rect sits in the live view, in tangent units.
	UISize screen = GetScreenSize()
	float sw = float( screen.width )
	float sh = float( maxint( 1, screen.height ) )
	float ppt = MapEditPreview_PixelsPerTan( camPos, fwd, right, sw, sh )
	float cx = ( file.rectX + file.rectW * 0.5 ) * sw
	float cy = ( file.rectY + file.rectH * 0.5 ) * sh
	float tanH = file.rectW * 0.5 * sw / ppt
	float tanV = file.rectH * 0.5 * sh / ppt
	vector ray = Normalize( fwd + right * ( ( cx - sw * 0.5 ) / ppt ) + up * ( ( sh * 0.5 - cy ) / ppt ) )

	vector mins = file.mins
	vector maxs = file.maxs
	vector size = maxs - mins
	float fitDist = max( MapEditPreview_FitDistance( size, tanH, tanV ), 0.5 )
	float dist = MapEditPreview_ClearDistance( camPos, ray, prop )
	float fitScale = dist / ( fitDist * PREVIEW_FIT_MARGIN )
	float trueScale = dist / ( PREVIEW_TRUE_SCALE_RADIUS / tanV * PREVIEW_FIT_MARGIN )
	float scale = ( file.autoFit ? fitScale : trueScale ) * file.zoom
	prop.SetModelScale( scale )
	file.lastScale = scale

	// Pan moves the model in the view plane, scaled by the visible height.
	float visibleH = dist * tanV * 2.0
	vector target = camPos + ray * dist + right * ( file.pan.x * visibleH ) + up * ( file.pan.y * visibleH )

	// Spin about the model's own vertical axis, then tilt it toward the camera.
	float modelYaw = file.yaw + file.spinYaw
	vector modelAng = AnglesCompose( < file.pitch, camAng.y, 0 >, < 0, modelYaw - camAng.y, 0 > )
	vector centerOffset = RotateVector( ( mins + maxs ) * 0.5 * scale, modelAng )
	prop.SetOrigin( target - centerOffset )
	prop.SetAngles( modelAng )

	MapEditPreview_PlaceLights( target, fwd, right, up, dist, PREVIEW_STUDIO_RADIUS )
	DoF_SetFarDepth( dist * PREVIEW_DOF_START, PREVIEW_DOF_END )

	if ( Time() - file.lastStateTime >= PREVIEW_STATE_INTERVAL )
	{
		file.lastStateTime = Time()
		// At or below 1 the scaled model fits the view.
		float onScreenFrac = fitDist * scale / dist
		RunUIScript( "UI_MapEditPreview_OnState", size.x, size.y, size.z, scale,
			onScreenFrac, resident, MapEditPreview_WrapDeg( modelYaw ), -file.pitch, file.zoom )
	}
}

// How far along the ray the model can float before it would sit inside the level.
float function MapEditPreview_ClearDistance( vector camPos, vector ray, entity prop )
{
	float reach = PREVIEW_MODEL_DIST * 1.4
	TraceResults tr = TraceLine( camPos, camPos + ray * reach, [ prop ], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	if ( tr.fraction >= 1.0 )
		return PREVIEW_MODEL_DIST
	return clamp( tr.fraction * reach * 0.6, PREVIEW_MODEL_DIST_MIN, PREVIEW_MODEL_DIST )
}

// Pixels per unit of view-space tangent, measured by projecting two points through
// the live view. Until the projection is this camera's (centred), the engine's
// 4:3-horizontal FOV rule stands in.
float function MapEditPreview_PixelsPerTan( vector camPos, vector fwd, vector right, float sw, float sh )
{
	float[2] a = GetScreenSpace( camPos + fwd * 100.0 )
	float[2] b = GetScreenSpace( camPos + fwd * 100.0 + right * 10.0 )
	float ax = a[0]
	float ay = a[1]
	float measured = ( b[0] - ax ) / 0.1
	bool centred = fabs( ax - sw * 0.5 ) < sw * 0.02 && fabs( ay - sh * 0.5 ) < sh * 0.02
	if ( centred && measured > 1.0 )
		file.pixelsPerTan = measured
	if ( file.pixelsPerTan > 0.0 )
		return file.pixelsPerTan
	return ( sh * 0.5 ) / ( 0.75 * tan( PREVIEW_FOV * 0.5 * DEG_TO_RAD ) )
}

// Camera distance at unit scale that keeps the model's box in view from any yaw:
// the spin axis is vertical, so the footprint is bounded by a circle of radius rxy.
float function MapEditPreview_FitDistance( vector size, float tanH, float tanV )
{
	float rxy = 0.5 * sqrt( size.x * size.x + size.y * size.y )
	float hz = 0.5 * size.z
	float p = PREVIEW_FIT_PITCH * DEG_TO_RAD
	float vExt = hz * cos( p ) + rxy * sin( p )
	float depth = rxy * cos( p ) + hz * sin( p )
	return depth + max( rxy / tanH, vExt / tanV )
}

void function MapEditPreview_ResolveBounds()
{
	array< vector > bounds
	if ( file.catalogId >= 0 )
		bounds = MapEditor_ModelBounds( file.catalogId )
	file.boundsKnown = bounds.len() == 2
	file.mins = file.boundsKnown ? bounds[0] : PREVIEW_FALLBACK_MINS
	file.maxs = file.boundsKnown ? bounds[1] : PREVIEW_FALLBACK_MAXS
}

void function MapEditPreview_PlaceLights( vector target, vector fwd, vector right, vector up, float dist, float radius )
{
	if ( file.lights.len() < 3 )
		return

	// key, fill, rim -- positions ride with the camera frame
	array< vector > offsets = [
		right * 0.7 + up * 0.6 - fwd * 0.6,
		right * -0.8 + up * 0.15 - fwd * 0.5,
		up * 0.5 + fwd * 1.0
	]
	array< vector > colors
	array< float > power
	switch ( file.lightPreset )
	{
		case 1:
			colors = [ <1.0, 1.0, 1.0>, <1.0, 1.0, 1.0>, <1.0, 1.0, 1.0> ]
			power = [ 2.6, 1.8, 1.4 ]
			break
		case 2:
			colors = [ <1.0, 0.82, 0.62>, <0.35, 0.55, 1.0>, <0.5, 0.85, 1.0> ]
			power = [ 3.2, 0.35, 2.4 ]
			break
		default:
			colors = [ <1.0, 0.92, 0.82>, <0.72, 0.84, 1.0>, <0.55, 0.85, 1.0> ]
			power = [ 2.4, 1.1, 1.6 ]
			break
	}

	float reach = dist + radius * 2.0
	for ( int i = 0; i < 3; i++ )
	{
		entity light = file.lights[i]
		if ( !IsValid( light ) )
			continue
		vector pos = target + offsets[i] * ( dist * 0.9 + radius )
		light.SetOrigin( pos )
		light.SetLightColor( colors[i] * power[i] )
		light.SetLightRadius( reach * 1.6 )
	}
}

// One line of live state for the agent link / console.
string function MapEditPreview_Debug()
{
	string cam = IsValid( file.camera ) ? format( "cam %s ang %s", string( file.camera.GetOrigin() ), string( file.camera.GetAngles() ) ) : "cam none"
	string prop = IsValid( file.prop ) ? format( "prop %s model %s scale %.3f", string( file.prop.GetOrigin() ), string( file.prop.GetModelName() ), file.lastScale ) : "prop none"
	return format( "open %d live %d %s %s resident %d catalog %d bounds %s mins %s maxs %s ppt %.1f rect %.3f %.3f %.3f %.3f",
		file.open ? 1 : 0, file.live ? 1 : 0, cam, prop, StreamModelIsResident( file.model ) ? 1 : 0, file.catalogId,
		file.boundsKnown ? "studio" : "fallback", string( file.mins ), string( file.maxs ), file.pixelsPerTan,
		file.rectX, file.rectY, file.rectW, file.rectH )
}

float function MapEditPreview_WrapDeg( float deg )
{
	while ( deg >= 360.0 )
		deg -= 360.0
	while ( deg < 0.0 )
		deg += 360.0
	return deg
}
