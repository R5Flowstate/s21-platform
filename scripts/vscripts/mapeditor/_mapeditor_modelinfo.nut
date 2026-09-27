// Per-model facts for the browser, read from studio data: collision and size.

global function MapEditInfo_Add
global function MapEditInfo_Send
global function MapEditInfo_OnDisconnect

const int MEINFO_SENDS_PER_FRAME = 32
const int MEINFO_READS_PER_FRAME = 48

struct
{
	table< int, int > collision
	table< int, vector > size
	table< int, vector > center
	// players that asked; they also get models added later (map packs)
	table< entity, bool > listeners
} file

void function MapEditInfo_Add( array< int > ids )
{
	thread MapEditInfo_AddThread( ids )
}

// Reading studio data loads each model, so a whole map's catalog is spread over frames.
void function MapEditInfo_AddThread( array< int > ids )
{
	array< int > added
	foreach ( int id in ids )
	{
		if ( id in file.collision )
			continue
		MapEditorCatalogEntry ornull e = MapEditorCatalog_GetEntry( id )
		if ( e == null )
			continue
		asset model = ( expect MapEditorCatalogEntry( e ) ).model
		file.collision[id] <- MapEdit_ModelCollision( model )
		file.size[id] <- MapEdit_ModelSize( model )
		file.center[id] <- MapEdit_ModelCenter( model )
		added.append( id )
		if ( added.len() % MEINFO_READS_PER_FRAME == 0 )
			WaitFrame()
	}
	foreach ( entity player, bool on in file.listeners )
	{
		if ( IsValid( player ) )
			thread MapEditInfo_SendIds( player, added )
	}
}

void function MapEditInfo_Send( entity player )
{
	// Listeners already get every later addition; a repeat request would only resend the whole table.
	if ( !IsValid( player ) || player in file.listeners )
		return
	file.listeners[player] <- true
	array< int > ids
	foreach ( int id, int c in file.collision )
		ids.append( id )
	thread MapEditInfo_SendIds( player, ids )
}

void function MapEditInfo_OnDisconnect( entity player )
{
	if ( player in file.listeners )
		delete file.listeners[player]
}

void function MapEditInfo_SendIds( entity player, array< int > ids )
{
	player.EndSignal( "OnDestroy" )
	int sent = 0
	foreach ( int id in ids )
	{
		vector s = file.size[id]
		s = < clamp( s.x, 0.0, 16000.0 ), clamp( s.y, 0.0, 16000.0 ), clamp( s.z, 0.0, 16000.0 ) >
		vector c = file.center[id]
		c = < clamp( c.x, -16000.0, 16000.0 ), clamp( c.y, -16000.0, 16000.0 ), clamp( c.z, -16000.0, 16000.0 ) >
		Remote_CallFunction_NonReplay( player, "ServerCallback_MapEdit_ModelInfo", id, file.collision[id], s, c )
		sent++
		if ( sent % MEINFO_SENDS_PER_FRAME == 0 )
			WaitFrame()
	}
}
