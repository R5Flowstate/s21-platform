// Map editor extended palette: non-prop recipes and zipline two-point flow.
// Client only ever sends a recipe index -- never a classname, model path, or asset.

global function MapEditor_Palette_ServerInit
global function MapEditPalette_SpawnSpecial
global function MapEditPalette_SpawnZipline


// Particle allowlist -- index 0 is default for recipe 5.
const asset MAPEDIT_FX_LAUNCHPAD = $"P_launchpad_launch"
const asset MAPEDIT_FX_LOOTBIN_OPEN = $"P_LootBin_open"
const asset MAPEDIT_FX_JUMPJET = $"P_team_jump_jet_ON_trails"

const float MAPEDIT_ZIPLINE_MIN_DIST = 64.0

struct
{
	table< entity, vector > ziplineAnchor
	bool particlesPrecached = false
} file

void function MapEditor_Palette_ServerInit()
{
	if ( !MapEditor_IsEnabled() )
		return

	PrecacheModel( MAPEDIT_JUMP_PAD_MODEL )
	PrecacheModel( MAPEDIT_DOOR_MODEL )
	PrecacheParticleSystem( MAPEDIT_FX_LAUNCHPAD )
	PrecacheParticleSystem( MAPEDIT_FX_LOOTBIN_OPEN )
	PrecacheParticleSystem( MAPEDIT_FX_JUMPJET )
	file.particlesPrecached = true

	AddClientCommandCallback( "mapedit_special", ClientCommand_MapEdit_Special )
	AddClientCommandCallback( "mapedit_zipline_start", ClientCommand_MapEdit_ZiplineStart )
	AddClientCommandCallback( "mapedit_zipline_end", ClientCommand_MapEdit_ZiplineEnd )
	AddClientCommandCallback( "mapedit_zipline_cancel", ClientCommand_MapEdit_ZiplineCancel )

	AddCallback_OnClientDisconnected( MapEditPalette_OnClientDisconnected )

	printt( "[MAPEDIT] palette init (recipes 1-5; light omitted)" )
}

void function MapEditPalette_OnClientDisconnected( entity player )
{
	if ( player in file.ziplineAnchor )
		delete file.ziplineAnchor[player]
}

// ---------------------------------------------------------------------------
// Recipes -- every spawned entity goes into ents, primary first; on failure
// whatever was spawned is destroyed and ents is left empty.
// ---------------------------------------------------------------------------

void function MapEditPalette_DestroyAll( array< entity > ents )
{
	foreach ( entity e in ents )
	{
		if ( IsValid( e ) )
			e.Destroy()
	}
	ents.clear()
}

void function MapEditPalette_Recipe_JumpPad( vector origin, vector angles, array< entity > ents )
{
	entity prop = CreatePropDynamic( MAPEDIT_JUMP_PAD_MODEL, origin, angles, SOLID_VPHYSICS, -1.0 )
	if ( !IsValid( prop ) )
		return
	prop.SetScriptName( "mapedit_jumppad" )
	prop.AllowMantle()
	ents.append( prop )

	entity trigger = CreateEntity( "trigger_cylinder_heavy" )
	if ( !IsValid( trigger ) )
	{
		MapEditPalette_DestroyAll( ents )
		return
	}

	trigger.SetOwner( prop )
	trigger.SetRadius( MAPEDIT_JUMP_PAD_RADIUS )
	trigger.SetAboveHeight( MAPEDIT_JUMP_PAD_HEIGHT )
	trigger.SetBelowHeight( MAPEDIT_JUMP_PAD_BELOW )
	trigger.SetOrigin( origin )
	trigger.SetAngles( angles )
	trigger.SetTriggerType( TT_JUMP_PAD )
	trigger.SetLaunchScaleValues( MAPEDIT_JUMP_PAD_VELOCITY, MAPEDIT_JUMP_PAD_VERT )
	trigger.SetLaunchDir( <0.0, 0.0, 1.0> )
	trigger.UsePointCollision()
	trigger.kv.triggerFilterNonCharacter = "0"
	DispatchSpawn( trigger )
	trigger.SetParent( prop, "", true, 0.0 )
	trigger.SetScriptName( "mapedit_jumppad_trigger" )
	ents.append( trigger )
}

// CreateSurvivalDoorPlain keeps the survival_door_plain script name so door logic runs.
void function MapEditPalette_Recipe_DoorSingle( vector origin, vector angles, array< entity > ents )
{
	entity door = CreateSurvivalDoorPlain( MAPEDIT_DOOR_MODEL, origin, angles )
	if ( IsValid( door ) )
		ents.append( door )
}

void function MapEditPalette_Recipe_DoorDouble( vector origin, vector angles, array< entity > ents )
{
	vector right = AnglesToRight( angles )
	float half = MAPEDIT_DOOR_DOUBLE_GAP * 0.5

	entity left = CreateSurvivalDoorPlain( MAPEDIT_DOOR_MODEL, origin - right * half, angles )
	if ( !IsValid( left ) )
		return
	ents.append( left )

	entity rightDoor = CreateSurvivalDoorPlain( MAPEDIT_DOOR_MODEL, origin + right * half, AnglesCompose( angles, <0, 180, 0> ) )
	if ( !IsValid( rightDoor ) )
	{
		MapEditPalette_DestroyAll( ents )
		return
	}
	ents.append( rightDoor )
}

void function MapEditPalette_Recipe_LootBin( vector origin, vector angles, array< entity > ents )
{
	entity bin = CreateLootBin( origin, angles, false, false, false )
	if ( IsValid( bin ) )
		ents.append( bin )
}

void function MapEditPalette_Recipe_Particle( vector origin, vector angles, array< entity > ents )
{
	if ( !file.particlesPrecached )
		return

	entity fx = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( MAPEDIT_FX_LAUNCHPAD ), origin, angles )
	if ( !IsValid( fx ) )
		return
	fx.SetScriptName( "mapedit_fx" )
	ents.append( fx )
}

// Recipe 6 (light) has no light entity spawn path in this tree.
bool function MapEditPalette_SpawnSpecial( int recipeId, vector origin, vector angles, array< entity > ents )
{
	switch ( recipeId )
	{
		case 1:
			MapEditPalette_Recipe_JumpPad( origin, angles, ents )
			break
		case 2:
			MapEditPalette_Recipe_DoorSingle( origin, angles, ents )
			break
		case 3:
			MapEditPalette_Recipe_DoorDouble( origin, angles, ents )
			break
		case 4:
			MapEditPalette_Recipe_LootBin( origin, angles, ents )
			break
		case 5:
			MapEditPalette_Recipe_Particle( origin, angles, ents )
			break
		default:
			return false
	}
	return ents.len() > 0
}

// The S21 client only knows ziplines as zipline + zipline_end. A move_rope with
// Zipline=1 reaches it as a plain rope, which its zipline code then calls
// through a zipline vtable slot the rope class does not have.
bool function MapEditPalette_SpawnZipline( vector start, vector end, array< entity > ents )
{
	float dist = Distance( start, end )
	if ( dist < MAPEDIT_ZIPLINE_MIN_DIST || dist > MAPEDIT_ZIPLINE_MAX_DIST )
		return false

	entity startPoint = CreateEntity( "zipline" )
	if ( !IsValid( startPoint ) )
		return false
	startPoint.kv.Material = "cable/zipline.vmt"
	startPoint.kv.Width = 2.0
	startPoint.kv.scale = 1.0
	startPoint.kv.ZiplineAutoDetachDistance = 100.0
	startPoint.kv.ZiplineDropToBottom = 1
	startPoint.kv.ZiplineFadeDistance = -1.0
	startPoint.kv.ZiplineLengthScale = 1.0
	startPoint.kv.ZiplinePreserveVelocity = 0
	startPoint.kv.ZiplinePushOffInDirectionX = 0
	startPoint.kv.ZiplineSpeedScale = 1.0
	startPoint.kv.ZiplineVersion = 3
	startPoint.kv.ZiplineVertical = 0
	startPoint.kv.DetachEndOnSpawn = 0
	startPoint.kv.DetachEndOnUse = 0
	startPoint.SetAngles( VectorToAngles( Normalize( end - start ) ) )
	startPoint.SetOrigin( start )
	ents.append( startPoint )

	entity endPoint = CreateEntity( "zipline_end" )
	if ( !IsValid( endPoint ) )
	{
		MapEditPalette_DestroyAll( ents )
		return false
	}
	endPoint.kv.ZiplineAutoDetachDistance = 100.0
	endPoint.kv.ZiplinePushOffInDirectionX = 0
	endPoint.SetAngles( VectorToAngles( Normalize( start - end ) ) )
	endPoint.SetOrigin( end )
	ents.append( endPoint )

	startPoint.LinkToEnt( endPoint )
	DispatchSpawn( startPoint )
	DispatchSpawn( endPoint )

	startPoint.SetScriptName( "mapedit_zipline" )
	endPoint.SetScriptName( "mapedit_zipline" )
	return true
}

// ---------------------------------------------------------------------------
// mapedit_special <recipeId> <x> <y> <z> <pitch> <yaw> <roll>
// ---------------------------------------------------------------------------

void function ClientCommand_MapEdit_Special( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( args.len() != 7 )
	{
		MapEdit_Reject( player, "special needs 7 args: <recipeId> <x> <y> <z> <pitch> <yaw> <roll>" )
		return
	}

	MapEditPlacement desc
	desc.kind = eMapEditKind.SPECIAL
	if ( !MapEdit_ParsePlacementArgs( player, args, desc ) )
		return

	MapEdit_TryPlaceFromClient( player, desc )
}

// ---------------------------------------------------------------------------
// Zipline two-point flow
// ---------------------------------------------------------------------------

vector function MapEditPalette_EyeTrace( entity player )
{
	vector eye = player.EyePosition()
	TraceResults tr = TraceLine( eye, eye + player.GetViewVector() * MAPEDIT_MAX_PLACE_DIST, player, TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
	return tr.endPos
}

void function ClientCommand_MapEdit_ZiplineStart( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( MapEditor_IsFrozenFor( player ) )
	{
		MapEdit_Reject( player, "zipline frozen by admin" )
		return
	}

	vector anchor = MapEditPalette_EyeTrace( player )
	file.ziplineAnchor[player] <- anchor

	MapEdit_Report( player, format( "zipline start set %.0f %.0f %.0f", anchor.x, anchor.y, anchor.z ) )
}

void function ClientCommand_MapEdit_ZiplineEnd( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( !( player in file.ziplineAnchor ) )
	{
		MapEdit_Reject( player, "zipline end: no start anchor" )
		return
	}

	MapEditPlacement desc
	desc.kind = eMapEditKind.ZIPLINE
	desc.origin = file.ziplineAnchor[player]
	desc.endOrigin = MapEditPalette_EyeTrace( player )

	float dist = Distance( desc.origin, desc.endOrigin )
	if ( dist > MAPEDIT_ZIPLINE_MAX_DIST )
	{
		MapEdit_Reject( player, format( "zipline end: too far (max %.0f)", MAPEDIT_ZIPLINE_MAX_DIST ) )
		return
	}
	if ( dist < MAPEDIT_ZIPLINE_MIN_DIST )
	{
		MapEdit_Reject( player, "zipline end: too close to start" )
		return
	}

	delete file.ziplineAnchor[player]
	MapEdit_TryPlaceFromClient( player, desc )
}

void function ClientCommand_MapEdit_ZiplineCancel( entity player, array<string> args )
{
	if ( !MapEditor_IsEnabled() )
		return

	if ( !IsValid( player ) || !player.IsPlayer() )
		return

	if ( player in file.ziplineAnchor )
		delete file.ziplineAnchor[player]
}
