#if SERVER
// Arena start-zone cages and hologram emitters. Modes decide realm and raised state.

global function FS_ArenaWalls_Init
global function FS_ArenaWalls_Collect
global function FS_ArenaWalls_IsOwned
global function FS_ArenaWalls_GetStartZone
global function FS_ArenaWalls_GetEmitters
global function FS_ArenaWalls_GetAll
global function FS_ArenaWalls_Raise
global function FS_ArenaWalls_Drop
global function FS_ArenaWalls_RaiseAll
global function FS_ArenaWalls_DropAll
global function FS_ArenaWalls_SetExclusiveRealm
global function FS_ArenaWalls_ClearExclusiveRealm
global function FS_ArenaWalls_SetAshHolosHidden

const string FS_ARENA_WALLS_START_ZONE = "func_brush_arenas_start_zone"
const string FS_ARENA_WALLS_EMITTER = "arena_hologram_emitter"
const asset FS_ARENA_ASH_HOLO = $"mdl/props/ash_hologram/holo_ash_bust.rmdl"
const float FS_ARENA_ASH_HOLO_Z = 138.0
const float FS_ARENA_ASH_HOLO_SCALE = 0.4
const int FS_ARENA_ASH_HOLO_SKIN = 3

struct
{
	bool inited = false
	bool collected = false
	int exclusiveRealm = -1
	bool ashHolosHidden = false
	array<entity> startZone
	array<entity> emitters
	array<entity> ashHolos
} file

void function FS_ArenaWalls_Init()
{
	if ( file.inited )
		return
	file.inited = true
	PrecacheModel( FS_ARENA_ASH_HOLO )
	AddCallback_EntitiesDidLoad( FS_ArenaWalls_Collect )
}

void function FS_ArenaWalls_Collect()
{
	if ( file.collected )
		return
	file.collected = true

	file.startZone.clear()
	file.emitters.clear()
	file.ashHolos.clear()

	entity brush = Entities_FindByClassname( null, "func_brush" )
	while ( IsValid( brush ) )
	{
		if ( GetEditorClass( brush ) == FS_ARENA_WALLS_START_ZONE )
			file.startZone.append( brush )
		brush = Entities_FindByClassname( brush, "func_brush" )
	}

	array<entity> emitters = GetEntArrayByScriptName( FS_ARENA_WALLS_EMITTER )
	foreach ( entity emitter in emitters )
	{
		if ( IsValid( emitter ) )
			file.emitters.append( emitter )
	}

	FS_ArenaWalls_SpawnAshHolos()

	if ( file.exclusiveRealm >= 0 )
		FS_ArenaWalls_ApplyExclusiveRealm()

	printt( "[FS-ARENA-WALLS] collected startZone=" + string( file.startZone.len() ) + " emitters=" + string( file.emitters.len() ) + " ashHolos=" + string( file.ashHolos.len() ) )
}

bool function FS_ArenaWalls_IsOwned( entity ent )
{
	if ( !IsValid( ent ) )
		return false
	if ( GetEditorClass( ent ) == FS_ARENA_WALLS_START_ZONE )
		return true
	return ent.GetScriptName() == FS_ARENA_WALLS_EMITTER
}

array<entity> function FS_ArenaWalls_GetStartZone()
{
	return file.startZone
}

array<entity> function FS_ArenaWalls_GetEmitters()
{
	return file.emitters
}

array<entity> function FS_ArenaWalls_GetAll()
{
	array<entity> all = clone file.startZone
	foreach ( entity emitter in file.emitters )
		all.append( emitter )
	foreach ( entity holo in file.ashHolos )
		all.append( holo )
	return all
}

void function FS_ArenaWalls_SpawnAshHolos()
{
	foreach ( entity emitter in file.emitters )
	{
		if ( !IsValid( emitter ) )
			continue

		entity head = CreatePropDynamic( FS_ARENA_ASH_HOLO, emitter.GetOrigin() + <0, 0, FS_ARENA_ASH_HOLO_Z>, emitter.GetAngles() )
		if ( !IsValid( head ) )
			continue
		head.SetSkin( FS_ARENA_ASH_HOLO_SKIN )
		head.SetModelScale( FS_ARENA_ASH_HOLO_SCALE )
		head.NotSolid()
		file.ashHolos.append( head )
	}
}

void function FS_ArenaWalls_SetAshHolosHidden( bool hidden )
{
	file.ashHolosHidden = hidden
	foreach ( entity holo in file.ashHolos )
	{
		if ( !IsValid( holo ) )
			continue
		if ( hidden )
		{
			holo.Hide()
			holo.MakeInvisible()
		}
		else
		{
			holo.Show()
			holo.MakeVisible()
		}
	}
	printt( "[FS-ARENA-WALLS] ash holos " + ( hidden ? "hidden" : "shown" ) + " count=" + string( file.ashHolos.len() ) )
}

void function FS_ArenaWalls_Raise( entity ent )
{
	if ( !IsValid( ent ) )
		return
	if ( file.ashHolosHidden && file.ashHolos.contains( ent ) )
		return
	ent.Show()
	ent.MakeVisible()
	if ( GetEditorClass( ent ) == FS_ARENA_WALLS_START_ZONE )
		ent.Solid()
}

void function FS_ArenaWalls_Drop( entity ent )
{
	if ( !IsValid( ent ) )
		return
	ent.NotSolid()
	ent.Hide()
	ent.MakeInvisible()
}

void function FS_ArenaWalls_RaiseAll()
{
	foreach ( entity wall in FS_ArenaWalls_GetAll() )
		FS_ArenaWalls_Raise( wall )
}

void function FS_ArenaWalls_DropAll()
{
	foreach ( entity wall in FS_ArenaWalls_GetAll() )
		FS_ArenaWalls_Drop( wall )
}

void function FS_ArenaWalls_SetExclusiveRealm( int realm )
{
	if ( realm < 0 || realm >= REALM_COUNT )
		return
	file.exclusiveRealm = realm
	if ( !file.collected )
		FS_ArenaWalls_Collect()
	FS_ArenaWalls_ApplyExclusiveRealm()
}

void function FS_ArenaWalls_ClearExclusiveRealm()
{
	file.exclusiveRealm = -1
	foreach ( entity ent in FS_ArenaWalls_GetAll() )
	{
		if ( !IsValid( ent ) )
			continue
		ent.AddToAllRealms()
	}
}

void function FS_ArenaWalls_ApplyExclusiveRealm()
{
	int n = 0
	foreach ( entity ent in FS_ArenaWalls_GetAll() )
	{
		if ( !IsValid( ent ) )
			continue
		ent.RemoveFromAllRealms()
		ent.AddToRealm( file.exclusiveRealm )
		FS_ArenaWalls_Raise( ent )
		if ( ent.GetRealms().len() < 1 )
			printt( "[FS-ARENA-WALLS] AddToRealm(" + string( file.exclusiveRealm ) + ") empty mask origin=" + string( ent.GetOrigin() ) )
		n++
	}
	printt( "[FS-ARENA-WALLS] exclusive realm=" + string( file.exclusiveRealm ) + " ents=" + string( n ) )
}
#endif
