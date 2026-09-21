// Movement recorder server: record own usercmd stream, replay on looping fake players.

global function MovementRecorder_ServerInit
global function MovementRecorder_OnPlayerDisconnected
global function MovementRecorder_StopAllForPlayer
global function MovementRecorder_IsEnabled
global function MRec_WaitForBotReady
global function MRec_BindBotRealms
global function MRec_ApplyLegend
global function MRec_TakeSnapshot
global function MRec_ApplySnapshot
global function MRec_GroundPoint
global function MRec_UnfreezeBot
global function MRec_RunProgram
global function MRec_PlayerBotCount

const string MREC_BOT_NAME_PREFIX = "REC-"
const float MREC_BOT_READY_TIMEOUT = 8.0
const float MREC_BOT_PARK_SECONDS = 45.0
const float MREC_START_PLACE_TOLERANCE = 4.0

struct MRecRecording
{
	int cmdRecId
	var anim
	MRecSnapshot snapshot
	float duration
	vector startOrigin
	vector startAngles
	string characterRef
	string ownerName
	float madeTime
	asset model
	string name
	string loadout
}

struct MRecPlayback
{
	entity dummy
	int slot
	bool loop
	string legend
	bool wanted
}

struct MRecPlayerState
{
	bool recording = false
	bool countingDown = false
	float recordStart = 0.0
	vector refOrigin = <0, 0, 0>
	vector refAngles = <0, 0, 0>
	array<MRecRecording> recordings
	array<MRecPlayback> playbacks
	bool loopDefault = true
	float lastCmdTime = 0.0
	float rate = 1.0
	string legendOverride = ""
	string recordMode = "input"
	float respawnDelay = 0.0
	array<entity> programBots
	MRecSnapshot pendingSnap
	bool pendingAnimRecording = false
	bool pendingInputRecording = true
	entity parkedBot = null
	string parkedCharRef = ""
	asset parkedModel = $""
	int parkedSerial = 0
}

struct
{
	table<int, MRecPlayerState> states = {}
	table<int, entity> realmOwner = {}
	int botSerial = 0
} file

bool function MovementRecorder_IsEnabled()
{
	return GetCurrentPlaylistVarBool( "movement_recorder_enable", false ) || GetConVarInt( "sv_cheats" ) == 1
}

void function MovementRecorder_ServerInit()
{
	RegisterSignal( MREC_SIGNAL_STOP_RECORD )
	RegisterSignal( MREC_SIGNAL_STOP_PLAYBACK )
	AddClientCommandCallback( "mrec", MRec_ClientCommand )
	AddCallback_OnPlayerAddedToRealm( MRec_OnPlayerAddedToRealm )
	printt( "[MRec] ServerInit" )
}

MRecPlayerState function MRec_GetState( entity player )
{
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
	{
		MRecPlayerState st
		st.recording = false
		st.countingDown = false
		st.recordStart = 0.0
		st.refOrigin = <0, 0, 0>
		st.refAngles = <0, 0, 0>
		st.recordings = []
		st.playbacks = []
		st.loopDefault = true
		st.lastCmdTime = 0.0
		st.rate = 1.0
		st.legendOverride = ""
		st.recordMode = "input"
		st.respawnDelay = 0.0
		st.programBots = []
		file.states[key] <- st
	}
	return file.states[key]
}

MRecPlayerState ornull function MRec_TryGetState( entity player )
{
	if ( !IsValid( player ) )
		return null
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return null
	return file.states[key]
}

int function MRec_GlobalRecordingCount()
{
	int n = 0
	foreach ( key, st in file.states )
		n += st.recordings.len()
	return n
}

int function MRec_ParseNonNegativeInt( string s )
{
	if ( s.len() < 1 || s.len() > 9 )
		return -1
	for ( int i = 0; i < s.len(); i++ )
	{
		string c = s.slice( i, i + 1 )
		if ( c < "0" || c > "9" )
			return -1
	}
	return s.tointeger()
}

float function MRec_ParseRate( string s )
{
	if ( s.len() < 1 || s.len() > 8 )
		return -1.0
	bool dot = false
	for ( int i = 0; i < s.len(); i++ )
	{
		string c = s.slice( i, i + 1 )
		if ( c == "." )
		{
			if ( dot )
				return -1.0
			dot = true
			continue
		}
		if ( c < "0" || c > "9" )
			return -1.0
	}
	return s.tofloat()
}

string function MRec_FormatRate( float v )
{
	return format( "%.2fx", v )
}

void function MRec_ClientCommand( entity player, array<string> args )
{
	try
	{
		MRec_ClientCommandImpl( player, args )
	}
	catch ( eCmd )
	{
		printt( format( "[MRec] command failed: %s", string( eCmd ) ) )
	}
	try
	{
		MRec_SendState( player )
	}
	catch ( eSync )
	{
	}
}

void function MRec_ClientCommandImpl( entity player, array<string> args )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	if ( args.len() < 1 )
	{
		printt( format( "[MRec] missing action from %s", player.GetPlayerName() ) )
		return
	}
	if ( !MovementRecorder_IsEnabled() )
	{
		Message( player, "#MREC_MSG_DISABLED", "#MREC_MSG_DISABLED_SUB" )
		return
	}
	MRecPlayerState st = MRec_GetState( player )
	if ( Time() - st.lastCmdTime < MREC_CMD_RATE_LIMIT )
		return
	st.lastCmdTime = Time()

	string action = args[0].tolower()
	if ( action == "start" )
	{
		MRec_CmdStart( player, st )
		return
	}
	if ( action == "stop" )
	{
		MRec_CmdStop( player, st )
		return
	}
	if ( action == "toggle" )
	{
		if ( st.recording || st.countingDown )
			MRec_CmdStop( player, st )
		else
			MRec_CmdStart( player, st )
		return
	}
	if ( action == "play" )
	{
		MRec_CmdPlay( player, st, args )
		return
	}
	if ( action == "playall" )
	{
		MRec_CmdPlayAll( player, st )
		return
	}
	if ( action == "playrandom" )
	{
		MRec_CmdPlayRandom( player, st )
		return
	}
	if ( action == "stopall" )
	{
		MRec_StopAllPlaybacks( st )
		Message( player, "#MREC_MSG_PLAYBACK_STOPPED" )
		return
	}
	if ( action == "clear" )
	{
		MRec_CmdClear( player, st, args )
		return
	}
	if ( action == "list" )
	{
		MRec_CmdList( player, st )
		return
	}
	if ( action == "loop" )
	{
		MRec_CmdLoop( player, st, args )
		return
	}
	if ( action == "rate" )
	{
		MRec_CmdRate( player, st, args )
		return
	}
	if ( action == "legend" )
	{
		MRec_CmdLegend( player, st, args )
		return
	}
	if ( action == "mode" )
	{
		MRec_CmdMode( player, st, args )
		return
	}
	if ( action == "respawn" )
	{
		MRec_CmdRespawn( player, st, args )
		return
	}
	if ( action == "name" )
	{
		MRec_CmdName( player, st, args )
		return
	}
	if ( action == "program" )
	{
		MRec_CmdProgram( player, st, args )
		return
	}
	if ( action == "sync" )
	{
		return
	}
	printt( format( "[MRec] unknown action '%s' from %s", args[0], player.GetPlayerName() ) )
}

void function MRec_CmdStart( entity player, MRecPlayerState st )
{
	if ( st.recording || st.countingDown )
	{
		Message( player, "#MREC_MSG_ALREADY_RECORDING" )
		return
	}
	if ( !IsAlive( player ) )
	{
		Message( player, "#MREC_MSG_MUST_BE_ALIVE" )
		return
	}
	if ( st.recordings.len() >= MREC_MAX_RECORDINGS_PER_PLAYER )
	{
		Message( player, "#MREC_MSG_SLOTS_FULL", "#MREC_MSG_CLEAR_TO_FREE" )
		return
	}
	if ( MRec_GlobalRecordingCount() >= MREC_GLOBAL_RECORDING_CAP )
	{
		Message( player, "#MREC_MSG_TABLE_FULL", "#MREC_MSG_TRY_LATER" )
		return
	}
	st.countingDown = true
	thread function() : ( player )
	{
		OnThreadEnd(
			function() : ( player )
			{
				MRec_ClearCountdown( player )
			}
		)
		if ( !IsValid( player ) )
			return
		player.EndSignal( "OnDestroy" )
		player.EndSignal( "OnDeath" )
		player.EndSignal( MREC_SIGNAL_STOP_RECORD )
		int total = int( MREC_COUNTDOWN_SECONDS )
		if ( total < 1 )
			total = 1
		for ( int i = total; i >= 1; i-- )
		{
			if ( !IsValid( player ) || !IsAlive( player ) )
				return
			Message( player, "#MREC_MSG_COUNTDOWN|" + string( i ), "", 1.2 )
			wait 1.0
		}
		MRec_BeginRecording( player )
	}()
}

void function MRec_ClearCountdown( entity player )
{
	if ( !IsValid( player ) )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	file.states[key].countingDown = false
}

void function MRec_BeginRecording( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() || !IsAlive( player ) )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	if ( st.recording || !st.countingDown )
		return
	if ( st.recordings.len() >= MREC_MAX_RECORDINGS_PER_PLAYER )
	{
		st.countingDown = false
		Message( player, "#MREC_MSG_SLOTS_FULL", "#MREC_MSG_CLEAR_TO_FREE" )
		return
	}
	bool wantInput = st.recordMode == "input"
	bool wantAnim = st.recordMode == "anim"
	int id = -1
	if ( wantInput )
	{
		try
		{
			id = player.CmdRec_Start()
		}
		catch ( eStart )
		{
			printt( format( "[MRec] CmdRec_Start failed for %s: %s", player.GetPlayerName(), string( eStart ) ) )
			id = -1
		}
		if ( id < 0 )
		{
			st.countingDown = false
			Message( player, "#MREC_MSG_REFUSED", "#MREC_MSG_REFUSED_BUSY" )
			return
		}
	}
	if ( wantAnim )
	{
		bool animOk = false
		try
		{
			player.StartRecordingAnimation( player.GetOrigin(), <0, player.GetAngles().y, 0> )
			animOk = true
		}
		catch ( eAnim )
		{
			printt( format( "[MRec] StartRecordingAnimation failed for %s: %s", player.GetPlayerName(), string( eAnim ) ) )
		}
		if ( !animOk )
		{
			if ( id >= 0 )
			{
				try { player.CmdRec_Stop() } catch ( eUndo ) {}
				try { CmdRec_Free( id ) } catch ( eUndo2 ) {}
			}
			st.countingDown = false
			Message( player, "#MREC_MSG_REFUSED", "#MREC_MSG_REFUSED_ANIM" )
			return
		}
	}
	st.pendingAnimRecording = wantAnim
	st.pendingInputRecording = wantInput
	st.refOrigin = player.GetOrigin()
	st.refAngles = <0, player.GetAngles().y, 0>
	MRec_TakeSnapshot( player, st.pendingSnap )
	st.countingDown = false
	st.recording = true
	st.recordStart = Time()
	Message( player, "#MREC_MSG_RECORDING", "#MREC_MSG_STOP_TO_FINISH" )
	MRec_HudPush( player, "MRec_CL_RecState", 1 )
	thread function() : ( player )
	{
		OnThreadEnd(
			function() : ( player )
			{
				MRec_FinishRecording( player )
			}
		)
		if ( !IsValid( player ) )
			return
		player.EndSignal( "OnDestroy" )
		player.EndSignal( "OnDeath" )
		player.EndSignal( MREC_SIGNAL_STOP_RECORD )
		wait MREC_MAX_SECONDS
	}()
}

void function MRec_FinishRecording( entity player )
{
	if ( !IsValid( player ) )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	if ( !st.recording )
		return
	st.recording = false
	int id = -1
	var anim = null
	if ( st.pendingInputRecording )
	{
		try
		{
			id = player.CmdRec_Stop()
		}
		catch ( eStop )
		{
			printt( format( "[MRec] CmdRec_Stop failed for %s: %s", player.GetPlayerName(), string( eStop ) ) )
			id = -1
		}
	}
	if ( st.pendingAnimRecording )
	{
		try
		{
			anim = player.StopRecordingAnimation()
		}
		catch ( eAnimStop )
		{
			printt( format( "[MRec] StopRecordingAnimation failed for %s: %s", player.GetPlayerName(), string( eAnimStop ) ) )
			anim = null
		}
	}
	if ( id < 0 && anim == null )
	{
		Message( player, "#MREC_MSG_EMPTY", "#MREC_MSG_CLIP_DISCARDED" )
		MRec_HudPush( player, "MRec_CL_RecDiscarded", 0 )
		return
	}
	float duration = 0.0
	vector org = st.refOrigin
	vector ang = st.refAngles
	if ( id >= 0 )
	{
		try
		{
			duration = CmdRec_GetDuration( id )
		}
		catch ( eDur )
		{
		}
		try
		{
			org = CmdRec_GetStartOrigin( id )
		}
		catch ( eOrg )
		{
		}
		try
		{
			ang = CmdRec_GetStartAngles( id )
		}
		catch ( eAng )
		{
		}
	}
	if ( anim != null )
	{
		float animDur = 0.0
		try
		{
			animDur = GetRecordedAnimationDuration( anim )
		}
		catch ( eAnimDur )
		{
		}
		if ( animDur <= 0.0 )
			anim = null
		else if ( duration <= 0.0 )
			duration = animDur
	}
	if ( duration <= 0.0 )
	{
		if ( id >= 0 )
		{
			try { CmdRec_Free( id ) } catch ( eFreeEmpty ) {}
		}
		Message( player, "#MREC_MSG_EMPTY", "#MREC_MSG_CLIP_DISCARDED" )
		MRec_HudPush( player, "MRec_CL_RecDiscarded", 0 )
		return
	}
	if ( st.recordings.len() >= MREC_MAX_RECORDINGS_PER_PLAYER )
	{
		if ( id >= 0 )
		{
			try { CmdRec_Free( id ) } catch ( eFreeFull ) {}
		}
		Message( player, "#MREC_MSG_SLOTS_FULL", "#MREC_MSG_CLIP_DISCARDED" )
		MRec_HudPush( player, "MRec_CL_RecDiscarded", 1 )
		return
	}
	int inputCount = 0
	if ( id >= 0 )
	{
		try
		{
			inputCount = CmdRec_GetCount( id )
		}
		catch ( eCount )
		{
		}
	}
	MRecRecording rec
	rec.cmdRecId = id
	rec.anim = anim
	MRec_CopySnapshot( st.pendingSnap, rec.snapshot )
	rec.duration = duration
	rec.startOrigin = org
	rec.startAngles = ang
	rec.characterRef = MovementRecorder_GetPlayerCharacterRef( player )
	rec.ownerName = player.GetPlayerName()
	rec.madeTime = Time()
	try
	{
		rec.model = player.GetModelName()
	}
	catch ( eModel )
	{
		rec.model = $""
	}
	rec.name = ""
	rec.loadout = MRec_BuildLoadoutLine( rec )
	st.recordings.append( rec )
	Message( player, "#MREC_MSG_SAVED|" + string( st.recordings.len() ), format( "%.1fs", rec.duration ) )
	MRec_SendState( player )
	if ( inputCount > 9000 )
		inputCount = 9000
	MRec_HudPush( player, "MRec_CL_RecSaved", st.recordings.len() - 1, int( rec.duration * 10.0 + 0.5 ), inputCount )
}

void function MRec_CmdStop( entity player, MRecPlayerState st )
{
	if ( st.recording )
	{
		MRec_FinishRecording( player )
		if ( IsValid( player ) )
			Signal( player, MREC_SIGNAL_STOP_RECORD )
		return
	}
	if ( st.countingDown )
	{
		st.countingDown = false
		if ( IsValid( player ) )
			Signal( player, MREC_SIGNAL_STOP_RECORD )
		Message( player, "#MREC_MSG_CANCELLED" )
		MRec_HudPush( player, "MRec_CL_RecState", 0 )
		return
	}
	Message( player, "#MREC_MSG_NOT_RECORDING" )
}

void function MRec_CmdPlay( entity player, MRecPlayerState st, array<string> args )
{
	if ( st.recordings.len() < 1 )
	{
		Message( player, "#MREC_MSG_NO_RECORDINGS", "#MREC_MSG_START_TO_RECORD" )
		return
	}
	int slot = st.recordings.len() - 1
	if ( args.len() >= 2 )
	{
		int v = MRec_ParseNonNegativeInt( args[1] )
		if ( v < 1 || v > st.recordings.len() )
		{
			Message( player, "#MREC_MSG_BAD_SLOT", "#MREC_MSG_SLOT_RANGE|1-" + string( st.recordings.len() ) )
			return
		}
		slot = v - 1
	}
	MRec_PrunePlaybacks( st )
	MRec_PruneProgramBots( st )
	if ( st.playbacks.len() + st.programBots.len() >= MREC_MAX_PLAYBACK_DUMMIES_PER_PLAYER )
	{
		Message( player, "#MREC_MSG_DUMMIES_FULL", "#MREC_MSG_STOPALL_TO_FREE" )
		return
	}
	entity npc = MRec_TakeParkedBot( st, st.recordings[slot] )
	bool reused = IsValid( npc )
	if ( !reused )
		npc = MRec_SpawnPlaybackDummy( player, st, slot )
	if ( !IsValid( npc ) )
		return
	MRec_BeginPlayback( player, st, npc, slot, null, reused )
	Message( player, "#MREC_MSG_REPLAYING|" + string( slot + 1 ) )
}

void function MRec_CmdPlayRandom( entity player, MRecPlayerState st )
{
	if ( st.recordings.len() < 1 )
	{
		Message( player, "#MREC_MSG_NO_RECORDINGS", "#MREC_MSG_START_TO_RECORD" )
		return
	}
	int slot = RandomInt( st.recordings.len() )
	MRec_CmdPlay( player, st, [ "play", string( slot + 1 ) ] )
}

void function MRec_CmdPlayAll( entity player, MRecPlayerState st )
{
	if ( st.recordings.len() < 1 )
	{
		Message( player, "#MREC_MSG_NO_RECORDINGS", "#MREC_MSG_START_TO_RECORD" )
		return
	}
	MRec_PrunePlaybacks( st )
	MRec_PruneProgramBots( st )
	int started = 0
	for ( int slot = 0; slot < st.recordings.len(); slot++ )
	{
		if ( MRec_FindPlaybackDummy( st, slot ) != null )
			continue
		if ( st.playbacks.len() + st.programBots.len() >= MREC_MAX_PLAYBACK_DUMMIES_PER_PLAYER )
		{
			Message( player, "#MREC_MSG_DUMMIES_FULL", "#MREC_MSG_STOPALL_TO_FREE" )
			return
		}
		entity npc = MRec_SpawnPlaybackDummy( player, st, slot )
		if ( !IsValid( npc ) )
			return
		MRec_BeginPlayback( player, st, npc, slot )
		started++
	}
	Message( player, "#MREC_MSG_REPLAYING_N|" + string( started ) )
}

void function MRec_CmdClear( entity player, MRecPlayerState st, array<string> args )
{
	if ( st.recordings.len() < 1 )
	{
		Message( player, "#MREC_MSG_NO_RECORDINGS" )
		return
	}
	if ( args.len() >= 2 && args[1].tolower() != "all" )
	{
		int v = MRec_ParseNonNegativeInt( args[1] )
		if ( v < 1 || v > st.recordings.len() )
		{
			Message( player, "#MREC_MSG_BAD_SLOT", "#MREC_MSG_SLOT_RANGE|1-" + string( st.recordings.len() ) )
			return
		}
		MRec_ClearSlot( st, v - 1 )
		Message( player, "#MREC_MSG_CLEARED|" + string( v ) )
		return
	}
	MRec_StopAllPlaybacks( st )
	foreach ( MRecRecording rec in st.recordings )
	{
		try
		{
			if ( rec.cmdRecId >= 0 )
				CmdRec_Free( rec.cmdRecId )
			rec.anim = null
		}
		catch ( eFree )
		{
		}
	}
	st.recordings = []
	Message( player, "#MREC_MSG_ALL_CLEARED" )
}

const int MREC_HUD_BOT_GONE = 0
const int MREC_HUD_BOT_PREP = 1
const int MREC_HUD_BOT_PLAYING = 2
const int MREC_HUD_BOT_RESPAWNING = 3
const int MREC_HUD_BOT_DEAD = 4
const int MREC_HUD_BOT_DONE = 5

void function MRec_HudPush( entity player, string fn, ... )
{
	if ( !IsValid( player ) || !player.IsPlayer() || player.IsBot() )
		return
	try
	{
		switch ( vargc )
		{
			case 0:
				Remote_CallFunction_NonReplay( player, fn )
				break
			case 1:
				Remote_CallFunction_NonReplay( player, fn, vargv[0] )
				break
			case 3:
				Remote_CallFunction_NonReplay( player, fn, vargv[0], vargv[1], vargv[2] )
				break
			case 8:
				Remote_CallFunction_NonReplay( player, fn, vargv[0], vargv[1], vargv[2], vargv[3], vargv[4], vargv[5], vargv[6], vargv[7] )
				break
		}
	}
	catch ( ePush )
	{
	}
}

// Row state for the playback HUD; t is the play start for PLAYING and the respawn time for RESPAWNING.
void function MRec_HudBot( entity player, entity bot, int slot, int state, int loopCur, float t )
{
	if ( !IsValid( player ) || !IsValid( bot ) )
		return
	MRecPlayerState ornull stNow = MRec_TryGetState( player )
	if ( stNow == null )
		return
	MRecPlayerState st = expect MRecPlayerState( stNow )
	if ( slot < 0 || slot >= st.recordings.len() )
		return
	int loopMode = 0
	foreach ( pb in st.playbacks )
	{
		if ( pb.dummy == bot )
			loopMode = pb.loop ? 1 : 0
	}
	int rateTenth = int( st.rate * 10.0 + 0.5 )
	int durTenth = int( st.recordings[slot].duration * 10.0 + 0.5 )
	if ( durTenth > 3000 )
		durTenth = 3000
	if ( loopCur > 255 )
		loopCur = 255
	if ( t < 0.0 )
		t = 0.0
	MRec_HudPush( player, "MRec_CL_Bot", bot, slot, state, loopCur, loopMode, rateTenth, durTenth, t )
}

// "wraith|RSPN101|WINGMAN": legend ref stem and weapon token stems, the client localizes.
string function MRec_BuildLoadoutLine( MRecRecording rec )
{
	string legend = rec.characterRef
	if ( legend.find( "character_" ) == 0 )
		legend = legend.slice( 10 )
	string line = legend
	int shown = 0
	foreach ( MRecWeaponSnap ws in rec.snapshot.weapons )
	{
		if ( shown >= 2 || ws.className == "" )
			continue
		string token = ""
		try
		{
			token = GetWeaponInfoFileKeyField_GlobalString( ws.className, "shortprintname" )
		}
		catch ( eTok )
		{
			token = ""
		}
		if ( token.find( "#WPN_" ) == 0 )
			token = token.slice( 5 )
		else if ( ws.className.find( "mp_weapon_" ) == 0 )
			token = ws.className.slice( 10 ).toupper()
		if ( token.len() > 6 && token.slice( token.len() - 6 ) == "_SHORT" )
			token = token.slice( 0, token.len() - 6 )
		if ( token == "" )
			continue
		line += "|" + token
		shown++
	}
	if ( line.len() > 45 )
		line = line.slice( 0, 45 )
	return line
}

const int MREC_NAME_MAX_CHARS = 15
const int MREC_NAME_CHARS_PER_INT = 3

string function MRec_SanitizeName( string raw )
{
	string out = ""
	for ( int i = 0; i < raw.len() && out.len() < MREC_NAME_MAX_CHARS; i++ )
	{
		int c = expect int( raw[i] )
		bool ok = ( c >= 48 && c <= 57 ) || ( c >= 65 && c <= 90 ) || ( c >= 97 && c <= 122 )
		ok = ok || c == 32 || c == 45 || c == 46 || c == 95
		if ( ok )
			out += raw.slice( i, i + 1 )
	}
	return strip( out )
}

void function MRec_CmdName( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		Message( player, "#MREC_MSG_NAME_PROMPT", "#MREC_MSG_NAME_USAGE" )
		return
	}
	int slot = int( args[1] ) - 1
	if ( slot < 0 || slot >= st.recordings.len() )
	{
		Message( player, "#MREC_MSG_NO_SUCH", "#MREC_MSG_LIST_USAGE" )
		return
	}
	string raw = ""
	for ( int i = 2; i < args.len(); i++ )
		raw += ( raw == "" ? "" : " " ) + args[i]
	st.recordings[slot].name = MRec_SanitizeName( raw )
	MRec_SendState( player )
	Message( player, "#MREC_MSG_RECORDING_N|" + string( slot + 1 ), st.recordings[slot].name == "" ? "#MREC_MSG_NAME_CLEARED" : st.recordings[slot].name )
}

// Remote functions carry ints only, so a name travels as 7-bit chars packed three per int.
void function MRec_SendSlotName( entity player, int idx, string name )
{
	MRec_SendPacked( player, "MRec_CL_SyncSlotName", idx, name )
}

void function MRec_SendPacked( entity player, string fn, int idx, string name )
{
	for ( int c = 0; c * MREC_NAME_CHARS_PER_INT < name.len(); c++ )
	{
		int packed = 0
		for ( int k = 0; k < MREC_NAME_CHARS_PER_INT; k++ )
		{
			int pos = c * MREC_NAME_CHARS_PER_INT + k
			if ( pos < name.len() )
				packed = packed | ( ( expect int( name[pos] ) & 0x7F ) << ( 7 * k ) )
		}
		Remote_CallFunction_NonReplay( player, fn, idx, c, packed )
	}
}

void function MRec_CmdList( entity player, MRecPlayerState st )
{
	string lines = ""
	for ( int i = 0; i < st.recordings.len(); i++ )
	{
		MRecRecording rec = st.recordings[i]
		string shortRef = rec.characterRef
		string prefix = "character_"
		if ( shortRef.find( prefix ) == 0 )
			shortRef = shortRef.slice( prefix.len() )
		if ( lines != "" )
			lines += "\n"
		string tracks = rec.anim != null ? " [anim]" : ""
		string title = rec.name != "" ? rec.name : "#" + string( i + 1 )
		lines += title + " " + format( "%.1fs", rec.duration ) + " " + shortRef + tracks
	}
	if ( lines == "" )
		lines = "none"
	Message( player, "#MREC_MSG_LIST_TITLE|" + string( st.recordings.len() ), lines, 10.0 )
}

void function MRec_CmdLoop( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		Message( player, st.loopDefault ? "#MREC_MSG_LOOP_ON" : "#MREC_MSG_LOOP_OFF", "#MREC_MSG_LOOP_USAGE" )
		return
	}
	int v = args[1].tolower() == "toggle" ? ( st.loopDefault ? 0 : 1 ) : MRec_ParseNonNegativeInt( args[1] )
	if ( v != 0 && v != 1 )
	{
		Message( player, "#MREC_MSG_BAD_VALUE", "#MREC_MSG_LOOP_USAGE_TOGGLE" )
		return
	}
	st.loopDefault = v == 1
	Message( player, st.loopDefault ? "#MREC_MSG_LOOP_ON" : "#MREC_MSG_LOOP_OFF", "#MREC_MSG_FUTURE_PLAY" )
}

void function MRec_CmdRate( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		Message( player, "#MREC_MSG_RATE|" + MRec_FormatRate( st.rate ), "#MREC_MSG_RATE_USAGE" )
		return
	}
	float v = MRec_ParseRate( args[1] )
	if ( v < 0.0 )
	{
		Message( player, "#MREC_MSG_BAD_RATE", "#MREC_MSG_RATE_USAGE" )
		return
	}
	if ( v < 0.25 )
		v = 0.25
	if ( v > 2.0 )
		v = 2.0
	st.rate = v
	Message( player, "#MREC_MSG_RATE|" + MRec_FormatRate( v ), "#MREC_MSG_FUTURE_PLAY" )
}

void function MRec_CmdMode( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		Message( player, "#MREC_MSG_RECORD_MODE|" + st.recordMode, "#MREC_MSG_MODE_USAGE" )
		return
	}
	string v = args[1].tolower()
	if ( v != "input" && v != "anim" )
	{
		Message( player, "#MREC_MSG_BAD_MODE", "#MREC_MSG_MODE_USAGE" )
		return
	}
	st.recordMode = v
	Message( player, "#MREC_MSG_RECORD_MODE|" + v, "#MREC_MSG_NEXT_RECORDING" )
}

void function MRec_CmdRespawn( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		Message( player, format( "#MREC_MSG_RESPAWN_DELAY|%.1f", st.respawnDelay ), "#MREC_MSG_RESPAWN_USAGE" )
		return
	}
	float v = MRec_ParseRate( args[1] )
	if ( v < 0.0 )
	{
		Message( player, "#MREC_MSG_BAD_DELAY", "#MREC_MSG_RESPAWN_USAGE" )
		return
	}
	if ( v > 10.0 )
		v = 10.0
	st.respawnDelay = v
	Message( player, format( "#MREC_MSG_RESPAWN_DELAY|%.1f", v ), "#MREC_MSG_ZERO_INSTANT" )
}

// Cycle order: same as recording, then every selectable legend.
string function MRec_NextLegendRef( string current )
{
	array<string> refs = [ "same" ]
	try
	{
		foreach ( ItemFlavor character in GetAllCharacters() )
		{
			string ref = ItemFlavor_GetCharacterRef( character )
			if ( HIDDEN_CHARACTER_REFS.contains( ref ) )
				continue
			refs.append( ref )
		}
	}
	catch ( eChars )
	{
	}
	int idx = refs.find( current == "" ? "same" : current )
	return refs[ ( idx + 1 ) % refs.len() ]
}

void function MRec_CmdLegend( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		if ( st.legendOverride != "" )
			Message( player, "#MREC_MSG_LEGEND|" + st.legendOverride, "#MREC_MSG_LEGEND_USAGE" )
		else
			Message( player, "#MREC_MSG_LEGEND_SAME", "#MREC_MSG_LEGEND_USAGE" )
		return
	}
	string v = args[1].tolower()
	if ( v == "next" )
		v = MRec_NextLegendRef( st.legendOverride )
	if ( v == "same" )
	{
		st.legendOverride = ""
		Message( player, "#MREC_MSG_LEGEND_SAME", "#MREC_MSG_FUTURE_PLAY" )
		return
	}
	string match = ""
	try
	{
		foreach ( ItemFlavor character in GetAllCharacters() )
		{
			if ( ItemFlavor_GetCharacterRef( character ) == v )
			{
				match = v
				break
			}
		}
	}
	catch ( eChars )
	{
	}
	if ( match == "" )
	{
		Message( player, "#MREC_MSG_UNKNOWN_LEGEND", "#MREC_MSG_LEGEND_USAGE" )
		return
	}
	st.legendOverride = match
	Message( player, "#MREC_MSG_LEGEND|" + match, "#MREC_MSG_FUTURE_PLAY" )
}

void function MRec_CmdProgram( entity player, MRecPlayerState st, array<string> args )
{
	if ( args.len() < 2 )
	{
		Message( player, "#MREC_MSG_BAD_PROGRAM", "#MREC_MSG_PROGRAM_USAGE" )
		return
	}
	string name = args[1].tolower()
	if ( name == "none" || name == "stop" )
	{
		MRec_StopProgramBots( st )
		try
		{
			LegendBot_KickAll( player )
		}
		catch ( eKick )
		{
		}
		Message( player, "#MREC_MSG_PROGRAMS_STOPPED" )
		return
	}
	if ( name != "strafe_narrow" && name != "strafe_wide" && name != "walk" && name != "face" )
	{
		Message( player, "#MREC_MSG_BAD_PROGRAM", "#MREC_MSG_PROGRAM_USAGE" )
		return
	}
	MRec_PrunePlaybacks( st )
	MRec_PruneProgramBots( st )
	int total = st.playbacks.len() + st.programBots.len()
	try
	{
		total += LegendBot_Count( player )
	}
	catch ( eCount )
	{
	}
	if ( total >= MREC_MAX_PLAYBACK_DUMMIES_PER_PLAYER )
	{
		Message( player, "#MREC_MSG_DUMMIES_FULL", "#MREC_MSG_STOPALL_TO_FREE" )
		return
	}
	vector spawn = <0, 0, 0>
	bool haveCross = false
	try
	{
		spawn = GetPlayerCrosshairOrigin( player )
		haveCross = true
	}
	catch ( eCross )
	{
	}
	if ( !haveCross )
	{
		try
		{
			spawn = player.GetOrigin()
		}
		catch ( eOrg )
		{
			Message( player, "#MREC_MSG_BOT_SPAWN_FAILED" )
			return
		}
	}
	spawn = MRec_GroundPoint( spawn )
	float yaw = 0.0
	try
	{
		yaw = player.GetAngles().y
	}
	catch ( eYaw )
	{
	}
	entity bot = null
	try
	{
		bot = LegendBot_Spawn( player, st.legendOverride, spawn, <0, yaw, 0>, 0 )
	}
	catch ( eSpawn )
	{
		bot = null
	}
	if ( !IsValid( bot ) )
		return
	bool hard = name == "strafe_wide"
	thread function() : ( player, bot, name, hard )
	{
		if ( !IsValid( bot ) )
			return
		bot.EndSignal( "OnDestroy" )
		bool ready = false
		try
		{
			ready = MRec_WaitForBotReady( bot )
		}
		catch ( eReady )
		{
		}
		if ( !ready )
			return
		wait 0.5
		if ( !IsValid( bot ) || !IsValid( player ) )
			return
		if ( name == "walk" || name == "face" )
		{
			try
			{
				bot.BotCmd_Stop()
			}
			catch ( eStop )
			{
			}
			if ( !IsValid( bot ) || !IsValid( player ) )
				return
			vector pt = <0, 0, 0>
			try
			{
				pt = bot.GetOrigin()
			}
			catch ( ePt )
			{
			}
			MRec_RunProgram( player, bot, pt, name )
			return
		}
		LegendBot_StartStrafe( player, bot, hard )
	}()
	Message( player, "#MREC_MSG_PROGRAM_STARTED", name )
}

string function MRec_LegendShortName( string ref )
{
	if ( ref.find( "character_" ) == 0 )
		return ref.slice( 10 )
	return ref
}

void function MRec_SendState( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	int count = st.recordings.len()
	int loopFlag = st.loopDefault ? 1 : 0
	int rateTenth = int( st.rate * 10.0 + 0.5 )
	try
	{
		Remote_CallFunction_NonReplay( player, "MRec_CL_SyncState", count, loopFlag, rateTenth )
		Remote_CallFunction_NonReplay( player, "MRec_CL_SyncClear" )
		for ( int i = 0; i < st.recordings.len(); i++ )
		{
			int durTenth = int( st.recordings[i].duration * 10.0 + 0.5 )
			Remote_CallFunction_NonReplay( player, "MRec_CL_SyncSlot", i, durTenth )
			MRec_SendSlotName( player, i, st.recordings[i].name )
			MRec_SendPacked( player, "MRec_CL_SyncSlotLoad", i, st.recordings[i].loadout )
		}
		MRec_SendPacked( player, "MRec_CL_SyncLegend", 0, MRec_LegendShortName( st.legendOverride ) )
		Remote_CallFunction_NonReplay( player, "MRec_CL_SyncDone" )
	}
	catch ( eSync )
	{
		printt( format( "[MRec] sync failed for %s: %s", player.GetPlayerName(), string( eSync ) ) )
	}
}

void function MRec_TakeSnapshot( entity player, MRecSnapshot snap )
{
	snap.weapons = []
	snap.activeSlot = -1
	snap.tactical = ""
	snap.ultimate = ""
	snap.equipment = []
	snap.inventory = {}
	snap.health = 100
	snap.shield = 0

	array<int> slots = [ WEAPON_INVENTORY_SLOT_PRIMARY_0, WEAPON_INVENTORY_SLOT_PRIMARY_1, WEAPON_INVENTORY_SLOT_PRIMARY_2 ]
	entity active = null
	try
	{
		active = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
	}
	catch ( eAct )
	{
	}
	foreach ( int slot in slots )
	{
		entity weapon = null
		bool haveWeapon = false
		try
		{
			weapon = player.GetNormalWeapon( slot )
			haveWeapon = IsValid( weapon )
		}
		catch ( eGet )
		{
			haveWeapon = false
		}
		if ( !haveWeapon )
			continue
		MRecWeaponSnap ws
		ws.className = ""
		ws.mods = []
		ws.clip = -1
		ws.skin = -1
		ws.slot = slot
		try
		{
			ws.className = weapon.GetWeaponClassName()
		}
		catch ( eCls )
		{
		}
		if ( ws.className == "" )
			continue
		try
		{
			ws.mods = weapon.GetMods()
		}
		catch ( eMods )
		{
			ws.mods = []
		}
		try
		{
			ws.clip = weapon.GetWeaponPrimaryClipCount()
		}
		catch ( eClip )
		{
		}
		try
		{
			ws.skin = weapon.GetSkin()
		}
		catch ( eSkin )
		{
		}
		snap.weapons.append( ws )
		try
		{
			if ( IsValid( active ) && weapon == active )
				snap.activeSlot = slot
		}
		catch ( eCmp )
		{
		}
	}
	try
	{
		entity tac = player.GetOffhandWeapon( OFFHAND_TACTICAL )
		if ( IsValid( tac ) )
			snap.tactical = tac.GetWeaponClassName()
	}
	catch ( eTac )
	{
	}
	try
	{
		entity ult = player.GetOffhandWeapon( OFFHAND_ULTIMATE )
		if ( IsValid( ult ) )
			snap.ultimate = ult.GetWeaponClassName()
	}
	catch ( eUlt )
	{
	}
	foreach ( string eqSlot in [ "armor", "helmet", "incapshield", "backpack" ] )
	{
		string ref = ""
		try
		{
			LootData ld = EquipmentSlot_GetEquippedLootDataForSlot( player, eqSlot )
			if ( SURVIVAL_Loot_IsRefValid( ld.ref ) )
				ref = ld.ref
		}
		catch ( eEq )
		{
		}
		snap.equipment.append( ref )
	}
	try
	{
		array<ConsumableInventoryItem> inv = SURVIVAL_GetPlayerInventory( player )
		foreach ( ConsumableInventoryItem item in inv )
		{
			string ref = ""
			try
			{
				LootData ld = SURVIVAL_Loot_GetLootDataByIndex( item.type )
				ref = ld.ref
			}
			catch ( eRef )
			{
			}
			if ( ref != "" && item.count > 0 )
			{
				if ( ref in snap.inventory )
					snap.inventory[ref] += item.count
				else
					snap.inventory[ref] <- item.count
			}
		}
	}
	catch ( eInv )
	{
	}
	try
	{
		snap.health = player.GetHealth()
	}
	catch ( eHp )
	{
	}
	try
	{
		snap.shield = player.GetShieldHealth()
	}
	catch ( eSh )
	{
	}
}

void function MRec_CopySnapshot( MRecSnapshot src, MRecSnapshot dst )
{
	dst.weapons = []
	foreach ( MRecWeaponSnap ws in src.weapons )
	{
		MRecWeaponSnap c
		c.className = ws.className
		c.mods = clone ws.mods
		c.clip = ws.clip
		c.skin = ws.skin
		c.slot = ws.slot
		dst.weapons.append( c )
	}
	dst.activeSlot = src.activeSlot
	dst.tactical = src.tactical
	dst.ultimate = src.ultimate
	dst.equipment = clone src.equipment
	dst.inventory = clone src.inventory
	dst.health = src.health
	dst.shield = src.shield
}

// Only the main weapon slots and the inventory are replaced. Offhands and melee
// stay with the bot so the character setup that just ran is not undone.
void function MRec_ClearBotLoadout( entity bot )
{
	array<entity> mains = []
	try
	{
		mains = bot.GetMainWeapons()
	}
	catch ( eMains )
	{
	}
	foreach ( entity weapon in mains )
	{
		if ( !IsValid( weapon ) )
			continue
		try
		{
			bot.TakeWeaponNow( weapon.GetWeaponClassName() )
		}
		catch ( eTake )
		{
		}
	}
	array<ConsumableInventoryItem> inv = []
	try
	{
		inv = SURVIVAL_GetPlayerInventory( bot )
	}
	catch ( eInv )
	{
	}
	foreach ( ConsumableInventoryItem item in inv )
	{
		try
		{
			string ref = SURVIVAL_Loot_GetLootDataByIndex( item.type ).ref
			SURVIVAL_RemoveFromPlayerInventory( bot, ref, item.count )
		}
		catch ( eRemove )
		{
		}
	}
}

// A mod the weapon does not define makes GiveWeapon throw and the weapon is lost.
// Fall back to a bare weapon and add the mods it will take.
entity function MRec_GiveWeaponSnap( entity bot, MRecWeaponSnap ws )
{
	entity given = null
	try
	{
		given = bot.GiveWeapon( ws.className, ws.slot, ws.mods )
	}
	catch ( eGive )
	{
		given = null
	}
	if ( !IsValid( given ) )
	{
		try
		{
			given = bot.GiveWeapon( ws.className, ws.slot, [] )
		}
		catch ( eBare )
		{
			printt( format( "[MRec] GiveWeapon '%s' failed: %s", ws.className, string( eBare ) ) )
			return null
		}
		if ( IsValid( given ) )
		{
			foreach ( string mod in ws.mods )
			{
				try
				{
					given.AddMod( mod )
				}
				catch ( eMod )
				{
				}
			}
		}
	}
	if ( !IsValid( given ) )
		return null
	if ( ws.clip >= 0 )
	{
		try
		{
			given.SetWeaponPrimaryClipCount( ws.clip )
		}
		catch ( eClip )
		{
		}
	}
	if ( ws.skin >= 0 )
	{
		try
		{
			given.SetSkin( ws.skin )
		}
		catch ( eSkin )
		{
		}
	}
	return given
}

bool function MRec_BotHasWeapon( entity bot, string className )
{
	return IsValid( MRec_BotWeapon( bot, className ) )
}

entity function MRec_BotWeapon( entity bot, string className )
{
	array<entity> mains = []
	try
	{
		mains = bot.GetMainWeapons()
	}
	catch ( eMains )
	{
		return null
	}
	foreach ( entity weapon in mains )
	{
		try
		{
			if ( IsValid( weapon ) && weapon.GetWeaponClassName() == className )
				return weapon
		}
		catch ( eCls )
		{
		}
	}
	return null
}

void function MRec_EnsureBotMelee( entity bot )
{
	entity melee = null
	try
	{
		melee = bot.GetOffhandWeapon( OFFHAND_MELEE )
	}
	catch ( eMelee )
	{
	}
	if ( IsValid( melee ) )
		return
	try
	{
		bot.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE, [] )
	}
	catch ( eGive )
	{
		printt( format( "[MRec] melee grant failed: %s", string( eGive ) ) )
	}
}

// fresh = a just-spawned bot: wipe and rebuild. A loop restart keeps the
// weapons it already holds (TakeWeaponNow + GiveWeapon in one frame leaves the
// slot empty) and only refills clips and adds what is missing.
void function MRec_ApplySnapshot( entity bot, MRecSnapshot snap, bool fresh = true )
{
	if ( !IsValid( bot ) )
		return
	if ( fresh )
		MRec_ClearBotLoadout( bot )
	foreach ( MRecWeaponSnap ws in snap.weapons )
	{
		if ( !IsValid( bot ) )
			return
		if ( ws.className == "" )
			continue
		if ( !fresh )
		{
			entity held = MRec_BotWeapon( bot, ws.className )
			if ( IsValid( held ) )
			{
				if ( ws.clip >= 0 )
				{
					try
					{
						held.SetWeaponPrimaryClipCount( ws.clip )
					}
					catch ( eClip )
					{
					}
				}
				continue
			}
		}
		MRec_GiveWeaponSnap( bot, ws )
	}
	if ( !IsValid( bot ) )
		return
	// One retry for anything the first pass dropped, then a loud report.
	array<string> missing = []
	foreach ( MRecWeaponSnap ws in snap.weapons )
	{
		if ( ws.className != "" && !MRec_BotHasWeapon( bot, ws.className ) )
		{
			if ( !IsValid( MRec_GiveWeaponSnap( bot, ws ) ) )
				missing.append( ws.className )
		}
	}
	if ( missing.len() > 0 )
	{
		string list = ""
		foreach ( string cls in missing )
			list += ( list == "" ? "" : ", " ) + cls
		printt( format( "[MRec] bot %s missing weapons after apply: %s", bot.GetPlayerName(), list ) )
	}
	MRec_EnsureBotMelee( bot )
	if ( !IsValid( bot ) )
		return
	if ( snap.activeSlot >= 0 )
	{
		string activeClass = ""
		foreach ( MRecWeaponSnap ws in snap.weapons )
		{
			if ( ws.slot == snap.activeSlot )
			{
				activeClass = ws.className
				break
			}
		}
		if ( activeClass != "" )
		{
			try
			{
				bot.SetActiveWeaponByName( eActiveInventorySlot.mainHand, activeClass )
			}
			catch ( eActive )
			{
			}
		}
	}
	if ( snap.tactical != "" )
	{
		try
		{
			bool same = false
			try
			{
				entity cur = bot.GetOffhandWeapon( OFFHAND_TACTICAL )
				if ( IsValid( cur ) && cur.GetWeaponClassName() == snap.tactical )
					same = true
			}
			catch ( eCurTac )
			{
			}
			if ( !same )
				bot.GiveOffhandWeapon( snap.tactical, OFFHAND_TACTICAL, [] )
		}
		catch ( eTac )
		{
		}
	}
	if ( snap.ultimate != "" )
	{
		try
		{
			bool same = false
			try
			{
				entity cur = bot.GetOffhandWeapon( OFFHAND_ULTIMATE )
				if ( IsValid( cur ) && cur.GetWeaponClassName() == snap.ultimate )
					same = true
			}
			catch ( eCurUlt )
			{
			}
			if ( !same )
				bot.GiveOffhandWeapon( snap.ultimate, OFFHAND_ULTIMATE, [] )
		}
		catch ( eUlt )
		{
		}
	}
	array<string> eqSlots = [ "armor", "helmet", "incapshield", "backpack" ]
	for ( int i = 0; i < snap.equipment.len() && i < eqSlots.len(); i++ )
	{
		if ( snap.equipment[i] == "" )
			continue
		try
		{
			Inventory_SetPlayerEquipment( bot, snap.equipment[i], eqSlots[i] )
		}
		catch ( eEq )
		{
		}
	}
	foreach ( string ref, int count in snap.inventory )
	{
		if ( ref == "" || count <= 0 )
			continue
		try
		{
			int have = fresh ? 0 : SURVIVAL_CountItemsInInventory( bot, ref )
			if ( have < count )
				SURVIVAL_AddToPlayerInventory( bot, ref, count - have )
		}
		catch ( eInv )
		{
		}
	}
	try
	{
		bot.SetHealth( snap.health )
	}
	catch ( eHp )
	{
	}
	try
	{
		bot.SetShieldHealth( snap.shield )
	}
	catch ( eSh )
	{
	}
}

void function MRec_PrunePlaybacks( MRecPlayerState st )
{
	array<MRecPlayback> keep = []
	foreach ( pb in st.playbacks )
	{
		if ( IsValid( pb.dummy ) || pb.wanted )
			keep.append( pb )
	}
	st.playbacks = keep
}

void function MRec_PruneProgramBots( MRecPlayerState st )
{
	array<entity> keep = []
	foreach ( entity bot in st.programBots )
	{
		if ( IsValid( bot ) )
			keep.append( bot )
	}
	st.programBots = keep
}

void function MRec_StopProgramBots( MRecPlayerState st )
{
	array<entity> kill = st.programBots
	st.programBots = []
	foreach ( entity bot in kill )
	{
		if ( !IsValid( bot ) )
			continue
		try
		{
			bot.BotCmd_Stop()
		}
		catch ( eStop )
		{
		}
		MRec_KickBot( bot )
	}
}

entity function MRec_FindPlaybackDummy( MRecPlayerState st, int slot )
{
	foreach ( pb in st.playbacks )
	{
		if ( pb.slot == slot && IsValid( pb.dummy ) )
			return pb.dummy
	}
	return null
}

void function MRec_RemovePlayback( entity player, entity npc )
{
	if ( !IsValid( player ) )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	for ( int i = st.playbacks.len() - 1; i >= 0; i-- )
	{
		if ( st.playbacks[i].dummy == npc && !st.playbacks[i].wanted )
			st.playbacks.remove( i )
	}
}

void function MRec_StopAllPlaybacks( MRecPlayerState st )
{
	array<entity> kill = []
	foreach ( pb in st.playbacks )
	{
		pb.wanted = false
		if ( IsValid( pb.dummy ) )
			kill.append( pb.dummy )
	}
	st.playbacks = []
	foreach ( d in kill )
	{
		if ( IsValid( d ) )
		{
			d.Signal( MREC_SIGNAL_STOP_PLAYBACK )
			MRec_KickBot( d )
		}
	}
	MRec_StopProgramBots( st )
	MRec_KickParkedBot( st )
}

void function MRec_KillPlaybackSlot( MRecPlayerState st, int slot )
{
	array<entity> kill = []
	array<MRecPlayback> keep = []
	foreach ( pb in st.playbacks )
	{
		if ( pb.slot == slot )
		{
			pb.wanted = false
			if ( IsValid( pb.dummy ) )
				kill.append( pb.dummy )
		}
		else if ( IsValid( pb.dummy ) || pb.wanted )
		{
			keep.append( pb )
		}
	}
	st.playbacks = keep
	foreach ( d in kill )
	{
		if ( IsValid( d ) )
		{
			d.Signal( MREC_SIGNAL_STOP_PLAYBACK )
			MRec_KickBot( d )
		}
	}
}

void function MRec_ClearSlot( MRecPlayerState st, int slot )
{
	MRec_KillPlaybackSlot( st, slot )
	try
	{
		if ( st.recordings[slot].cmdRecId >= 0 )
			CmdRec_Free( st.recordings[slot].cmdRecId )
		st.recordings[slot].anim = null
	}
	catch ( eFree )
	{
	}
	st.recordings.remove( slot )
	foreach ( pb in st.playbacks )
	{
		if ( pb.slot > slot )
			pb.slot--
	}
}

int function MRec_PickBotTeam( entity player )
{
	int myTeam = player.GetTeam()
	if ( Is2TeamPvPGame() )
		return GetEnemyTeam( myTeam )
	if ( myTeam >= TEAM_MULTITEAM_FIRST )
	{
		int maxTeams = GetCurrentPlaylistVarInt( "max_teams", MAX_TEAMS )
		int team = myTeam + 1
		if ( team >= TEAM_MULTITEAM_FIRST + maxTeams )
			team = TEAM_MULTITEAM_FIRST
		if ( team == myTeam )
			team = myTeam + 1
		return team
	}
	return myTeam == TEAM_IMC ? TEAM_MILITIA : TEAM_IMC
}

// The bot that just finished stays hidden on its start spot for a while so
// the next play of the same legend starts at once instead of waiting for a
// new fake player to connect, spawn and dress.
void function MRec_ParkBot( entity player, entity bot, MRecRecording rec, string legendOverride )
{
	if ( !IsValid( bot ) || !IsAlive( bot ) || !IsValid( player ) )
	{
		MRec_KickBot( bot )
		return
	}
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
	{
		MRec_KickBot( bot )
		return
	}
	MRecPlayerState st = file.states[key]
	if ( IsValid( st.parkedBot ) && st.parkedBot != bot )
		MRec_KickBot( st.parkedBot )
	try
	{
		bot.BotCmd_Stop()
		bot.SetVelocity( <0, 0, 0> )
		bot.SetOrigin( rec.startOrigin )
		bot.NotSolid()
		bot.Hide()
		bot.SetInvulnerable()
	}
	catch ( ePark )
	{
		MRec_KickBot( bot )
		return
	}
	st.parkedBot = bot
	st.parkedCharRef = legendOverride != "" ? legendOverride : rec.characterRef
	st.parkedModel = legendOverride != "" ? $"" : rec.model
	st.parkedSerial++
	thread MRec_ParkTimeout( st, bot, st.parkedSerial )
}

void function MRec_ParkTimeout( MRecPlayerState st, entity bot, int serial )
{
	if ( !IsValid( bot ) )
		return
	bot.EndSignal( "OnDestroy" )
	wait MREC_BOT_PARK_SECONDS
	if ( st.parkedBot == bot && st.parkedSerial == serial )
	{
		st.parkedBot = null
		MRec_KickBot( bot )
	}
}

entity function MRec_TakeParkedBot( MRecPlayerState st, MRecRecording rec )
{
	entity bot = st.parkedBot
	if ( !IsValid( bot ) )
		return null
	st.parkedBot = null
	st.parkedSerial++
	string wantRef = st.legendOverride != "" ? st.legendOverride : rec.characterRef
	asset wantModel = st.legendOverride != "" ? $"" : rec.model
	if ( !IsAlive( bot ) || st.parkedCharRef != wantRef || st.parkedModel != wantModel )
	{
		MRec_KickBot( bot )
		return null
	}
	try
	{
		bot.ClearInvulnerable()
		bot.Show()
		bot.Solid()
	}
	catch ( eWake )
	{
		MRec_KickBot( bot )
		return null
	}
	return bot
}

void function MRec_KickParkedBot( MRecPlayerState st )
{
	entity bot = st.parkedBot
	st.parkedBot = null
	st.parkedSerial++
	if ( IsValid( bot ) )
		MRec_KickBot( bot )
}

void function MRec_KickBotAfter( entity bot, float delay )
{
	wait delay
	if ( IsValid( bot ) )
		MRec_KickBot( bot )
}

void function MRec_KickBot( entity bot )
{
	if ( !IsValid( bot ) || !bot.IsPlayer() || !bot.IsBot() )
		return
	string name = bot.GetPlayerName()
	if ( name.find( MREC_BOT_NAME_PREFIX ) != 0 )
		return
	bool kicked = false
	try
	{
		kicked = bot.BotCmd_Kick()
	}
	catch ( eKick )
	{
		kicked = false
	}
	if ( !kicked )
		ServerCommand( "kick \"" + name + "\"" )
}

// Playback bodies are fake players: the client renders them through the same
// path as any remote player, which is the only path that handles legend models.
entity function MRec_SpawnPlaybackDummy( entity player, MRecPlayerState st, int slot )
{
	int maxPlayers = GetCurrentPlaylistVarInt( "max_players", 60 )
	if ( GetNumHumanPlayers() + GetNumFakeClients() >= maxPlayers )
	{
		Message( player, "#MREC_MSG_SERVER_FULL", "#MREC_MSG_NO_SEAT_PLAYBACK" )
		return null
	}

	file.botSerial++
	string botName = MREC_BOT_NAME_PREFIX + string( file.botSerial )
	int team = MRec_PickBotTeam( player )
	int edict = -1
	try
	{
		edict = CreateFakePlayer( botName, team )
	}
	catch ( eSpawn )
	{
		printt( format( "[MRec] CreateFakePlayer threw: %s", string( eSpawn ) ) )
		edict = -1
	}
	if ( edict < 0 )
	{
		Message( player, "#MREC_MSG_BOT_SPAWN_FAILED" )
		return null
	}

	entity bot = GetEntByIndex( edict )
	if ( !IsValid( bot ) || !bot.IsPlayer() )
	{
		bot = null
		foreach ( entity p in GetPlayerArray() )
		{
			if ( IsValid( p ) && p.IsBot() && p.GetPlayerName() == botName )
			{
				bot = p
				break
			}
		}
	}
	if ( !IsValid( bot ) )
	{
		Message( player, "#MREC_MSG_BOT_SPAWN_FAILED" )
		return null
	}
	MRec_BindBotRealms( bot, player )
	return bot
}

// A bot is a fake player on another team, and the staging area (firing range)
// puts every player into its TEAM's realm. Keep the bot in its owner's realms
// instead, and re-apply whenever either side gets moved.
void function MRec_BindBotRealms( entity bot, entity owner )
{
	if ( !IsValid( bot ) || !IsValid( owner ) )
		return
	file.realmOwner[ bot.GetEncodedEHandle() ] <- owner
	MRec_SyncBotRealms( bot, owner )
}

void function MRec_SyncBotRealms( entity bot, entity owner )
{
	if ( !IsValid( bot ) || !IsValid( owner ) )
		return
	array<int> want = owner.GetRealms()
	if ( want.len() == 0 )
		return
	array<int> have = bot.GetRealms()
	bool same = have.len() == want.len()
	if ( same )
	{
		foreach ( int realm in want )
		{
			if ( !have.contains( realm ) )
			{
				same = false
				break
			}
		}
	}
	if ( same )
		return
	bot.RemoveFromAllRealms()
	foreach ( int realm in want )
		bot.AddToRealm( realm )
	printt( format( "[MRec] %s realms -> %s (owner %s)", bot.GetPlayerName(), string( want ), owner.GetPlayerName() ) )
}

void function MRec_OnPlayerAddedToRealm( entity player )
{
	if ( !IsValid( player ) )
		return
	int key = player.GetEncodedEHandle()
	if ( key in file.realmOwner )
	{
		MRec_SyncBotRealms( player, file.realmOwner[key] )
		return
	}
	array<int> stale = []
	foreach ( int botKey, entity owner in file.realmOwner )
	{
		if ( !IsValid( owner ) )
		{
			stale.append( botKey )
			continue
		}
		if ( owner != player )
			continue
		entity bot = GetEntityFromEncodedEHandle( botKey )
		if ( !IsValid( bot ) )
		{
			stale.append( botKey )
			continue
		}
		MRec_SyncBotRealms( bot, owner )
	}
	foreach ( int botKey in stale )
		delete file.realmOwner[botKey]
}

bool function MRec_WaitForBotReady( entity bot )
{
	float startTime = Time()
	while ( IsValid( bot ) && Time() - startTime < MREC_BOT_READY_TIMEOUT )
	{
		if ( IsAlive( bot ) && EHIHasValidScriptStruct( ToEHI( bot ) ) )
		{
			EHIScriptStruct ehiss = GetEHIScriptStruct( ToEHI( bot ) )
			if ( ehiss.isValidated )
				return true
		}
		WaitFrame()
	}
	return false
}

vector function MRec_GroundPoint( vector pt )
{
	vector grounded = pt
	try
	{
		TraceResults res = TraceLine( pt + <0, 0, 256>, pt - <0, 0, 512> )
		grounded = res.endPos
	}
	catch ( eTr )
	{
	}
	return grounded
}

void function MRec_ApplyLegend( entity bot, string charRef, asset model, bool applyModel )
{
	try
	{
		ItemFlavor character = GetItemFlavorByCharacterRef( charRef )
		SetItemFlavorLoadoutSlot( ToEHI( bot ), Loadout_Character(), character )
		Survival_PlayerCharacterSetup( bot, character, true )
	}
	catch ( eChar )
	{
		printt( format( "[MRec] character setup '%s' failed: %s", charRef, string( eChar ) ) )
	}
	if ( !IsValid( bot ) )
		return
	if ( !applyModel )
		return
	if ( model == $"" )
		return
	bool sameModel = false
	try
	{
		sameModel = bot.GetModelName() == model
	}
	catch ( eGetModel )
	{
	}
	if ( sameModel )
		return
	try
	{
		bot.SetModel( model )
	}
	catch ( eModel )
	{
		printt( format( "[MRec] SetModel %s failed: %s", string( model ), string( eModel ) ) )
	}
}

void function MRec_DressBot( entity bot, MRecRecording rec, string legendOverride = "" )
{
	string charRef = rec.characterRef
	bool applyModel = true
	if ( legendOverride != "" )
	{
		charRef = legendOverride
		applyModel = false
	}
	MRec_ApplyLegend( bot, charRef, rec.model, applyModel )
}

void function MRec_TeleportBotToRecStart( entity bot, MRecRecording rec )
{
	try
	{
		bot.SetVelocity( <0, 0, 0> )
	}
	catch ( eVel )
	{
	}
	try
	{
		bot.SetOrigin( rec.startOrigin )
	}
	catch ( eOrg )
	{
	}
	try
	{
		bot.SetAngles( <0, rec.startAngles.y, 0> )
	}
	catch ( eAng )
	{
	}
}

// Spawn and respawn flows can leave a late-joining bot with frozen controls.
void function MRec_UnfreezeBot( entity bot )
{
	if ( !IsValid( bot ) )
		return
	try
	{
		bot.UnfreezeControlsOnServer()
	}
	catch ( eFreeze )
	{
	}
}

bool function MRec_UseAnimTrack( MRecPlayerState st, MRecRecording rec )
{
	return rec.anim != null && rec.cmdRecId < 0
}

// A fresh fake player's spawn placement lands a tick after script sees it
// alive and overwrites a same-frame SetOrigin, so the start spot is held
// until the bot stays put. Recordings replay from exactly where they began.
bool function MRec_PlaceBotAtRecStart( entity bot, MRecRecording rec )
{
	for ( int i = 0; i < 6; i++ )
	{
		if ( !IsValid( bot ) )
			return false
		MRec_TeleportBotToRecStart( bot, rec )
		WaitFrame()
		if ( !IsValid( bot ) )
			return false
		float off = Distance( bot.GetOrigin(), rec.startOrigin )
		if ( off <= MREC_START_PLACE_TOLERANCE )
			return true
		printt( format( "[MRec] %s displaced %.1f u from the recording start, re-placing", bot.GetPlayerName(), off ) )
	}
	return IsValid( bot )
}

bool function MRec_StartBotPlayback( entity bot, MRecRecording rec, bool loop, float rate, bool useAnim )
{
	MRec_UnfreezeBot( bot )
	if ( !MRec_PlaceBotAtRecStart( bot, rec ) )
		return false
	bool ok = false
	if ( useAnim )
	{
		try
		{
			bot.BotCmd_Stop()
		}
		catch ( eStopCmd )
		{
		}
		try
		{
			bot.PlayRecordedAnimation( rec.anim, rec.startOrigin, rec.startAngles, 0.0 )
			bot.SetRecordedAnimationPlaybackRate( rate )
			ok = true
		}
		catch ( eAnimPlay )
		{
			printt( format( "[MRec] PlayRecordedAnimation refused: %s", string( eAnimPlay ) ) )
			ok = false
		}
		return ok
	}
	try
	{
		ok = bot.BotCmd_PlayRecording( rec.cmdRecId, loop, rate )
	}
	catch ( ePlay )
	{
		printt( format( "[MRec] BotCmd_PlayRecording refused: %s", string( ePlay ) ) )
		ok = false
	}
	return ok
}

void function MRec_RunProgram( entity player, entity bot, vector spawn, string name )
{
	if ( !IsValid( bot ) || !IsValid( player ) )
		return
	MRec_UnfreezeBot( bot )
	if ( name == "strafe_narrow" )
	{
		try
		{
			bot.BotCmd_Face( player )
		}
		catch ( eFace )
		{
		}
		try
		{
			bot.BotCmd_Strafe( LegendBot_StrafeHalfWidth( bot ), false, 1.0 )
		}
		catch ( eStrafe )
		{
		}
		return
	}
	if ( name == "strafe_wide" )
	{
		try
		{
			bot.BotCmd_Face( player )
		}
		catch ( eFace )
		{
		}
		try
		{
			bot.BotCmd_Strafe( LegendBot_StrafeHalfWidth( bot ), true, 1.0 )
		}
		catch ( eStrafe )
		{
		}
		return
	}
	if ( name == "face" )
	{
		try
		{
			bot.BotCmd_Face( player )
		}
		catch ( eFace )
		{
		}
		return
	}
	if ( name == "walk" )
	{
		try
		{
			bot.BotCmd_Face( player )
		}
		catch ( eFace )
		{
		}
		thread function() : ( bot, spawn )
		{
			if ( !IsValid( bot ) )
				return
			bot.EndSignal( "OnDestroy" )
			while ( true )
			{
				vector pt = spawn + <RandomFloatRange( -400.0, 400.0 ), RandomFloatRange( -400.0, 400.0 ), 0>
				pt = MRec_GroundPoint( pt )
				try
				{
					if ( IsValid( bot ) )
						bot.BotCmd_MoveTo( pt, 0.8, false )
				}
				catch ( eMove )
				{
				}
				wait 3.0
			}
		}()
		return
	}
}

// A respawn hands its own playback entry back in; a fresh play creates one
// wearing the legend selected at that moment.
void function MRec_BeginPlayback( entity player, MRecPlayerState st, entity npc, int slot, MRecPlayback ornull again = null, bool reused = false )
{
	MRecRecording rec = st.recordings[slot]
	MRecPlayback pb
	if ( again != null )
	{
		pb = expect MRecPlayback( again )
		pb.dummy = npc
	}
	else
	{
		pb.dummy = npc
		pb.slot = slot
		pb.loop = st.loopDefault
		pb.legend = st.legendOverride
		pb.wanted = pb.loop
		st.playbacks.append( pb )
	}

	bool loop = pb.loop
	float rate = st.rate
	string legend = pb.legend
	bool useAnim = MRec_UseAnimTrack( st, rec )
	thread function() : ( npc, player, slot, rec, loop, rate, legend, useAnim, reused )
	{
		float playStart = Time()
		OnThreadEnd(
			function() : ( player, npc, slot, loop )
			{
				bool deadNoRespawn = IsValid( npc ) && !IsAlive( npc ) && !loop
				MRec_HudBot( player, npc, slot, deadNoRespawn ? MREC_HUD_BOT_DEAD : MREC_HUD_BOT_GONE, 0, 0.0 )
				MRec_RemovePlayback( player, npc )
				if ( deadNoRespawn )
					thread MRec_KickBotAfter( npc, 0.5 )
			}
		)
		if ( !IsValid( npc ) )
			return
		npc.EndSignal( "OnDestroy" )
		npc.EndSignal( MREC_SIGNAL_STOP_PLAYBACK )
		MRec_HudBot( player, npc, slot, MREC_HUD_BOT_PREP, 0, 0.0 )
		if ( !reused )
		{
			if ( !MRec_WaitForBotReady( npc ) )
			{
				printt( "[MRec] playback bot never became ready" )
				MRec_KickBot( npc )
				return
			}
			MRec_BindBotRealms( npc, player )
			MRec_DressBot( npc, rec, legend )
			if ( !IsValid( npc ) )
				return
		}
		float readyAt = Time()
		MRec_ApplySnapshot( npc, rec.snapshot )
		if ( !IsValid( npc ) )
			return
		npc.EndSignal( "OnDeath" )
		int lastLoop = 0
		try
		{
			lastLoop = npc.BotCmd_GetLoopCount()
		}
		catch ( eLoop0 )
		{
		}
		if ( !MRec_StartBotPlayback( npc, rec, loop, rate, useAnim ) )
		{
			if ( IsValid( player ) )
				Message( player, "#MREC_MSG_PLAYBACK_REFUSED", "#MREC_MSG_BOT_COULD_NOT_PLAY" )
			MRec_KickBot( npc )
			return
		}
		printt( format( "[MRec] play slot %d: %s ready in %.0f ms, rolling at %.0f ms", slot + 1, reused ? "parked bot" : "new bot", ( readyAt - playStart ) * 1000.0, ( Time() - playStart ) * 1000.0 ) )
		MRec_HudBot( player, npc, slot, MREC_HUD_BOT_PLAYING, 0, Time() )
		if ( useAnim )
		{
			float animWait = rec.duration / ( rate > 0.05 ? rate : 1.0 )
			int animLoop = 0
			while ( true )
			{
				wait animWait
				if ( !IsValid( npc ) )
					return
				if ( !loop )
					break
				animLoop++
				MRec_StartBotPlayback( npc, rec, loop, rate, true )
				MRec_HudBot( player, npc, slot, MREC_HUD_BOT_PLAYING, animLoop, Time() )
			}
			MRec_HudBot( player, npc, slot, MREC_HUD_BOT_DONE, 0, 0.0 )
			wait 1.0
			MRec_ParkBot( player, npc, rec, legend )
			return
		}
		while ( true )
		{
			wait 0.1
			if ( !IsValid( npc ) )
				return
			int loops = lastLoop
			try
			{
				loops = npc.BotCmd_GetLoopCount()
			}
			catch ( eLoop )
			{
			}
			if ( loops > lastLoop )
			{
				lastLoop = loops
				if ( !MRec_PlaceBotAtRecStart( npc, rec ) )
					return
				// Inputs replay from frame 0, so the loadout must match frame 0 too:
				// slots, active weapon, clips, offhands and health as recorded.
				MRec_ApplySnapshot( npc, rec.snapshot, false )
				MRec_HudBot( player, npc, slot, MREC_HUD_BOT_PLAYING, loops, Time() )
				continue
			}
			bool playing = true
			try
			{
				playing = npc.BotCmd_IsPlaying()
			}
			catch ( ePlaying )
			{
			}
			if ( !playing )
				break
		}
		MRec_HudBot( player, npc, slot, MREC_HUD_BOT_DONE, lastLoop, 0.0 )
		wait 1.0
		MRec_ParkBot( player, npc, rec, legend )
	}()
	if ( loop )
	{
		thread function() : ( npc, player, slot, pb )
		{
			if ( !IsValid( npc ) )
				return
			npc.EndSignal( "OnDestroy" )
			if ( !IsValid( player ) )
				return
			player.EndSignal( "OnDestroy" )
			WaitSignal( npc, "OnDeath" )
			MRecPlayerState ornull stNow = MRec_TryGetState( player )
			float delay = MREC_RESPAWN_DELAY
			if ( stNow != null )
				delay = expect MRecPlayerState( stNow ).respawnDelay
			int loopsSoFar = 0
			try
			{
				loopsSoFar = npc.BotCmd_GetLoopCount()
			}
			catch ( eLoops )
			{
			}
			MRec_HudBot( player, npc, slot, MREC_HUD_BOT_RESPAWNING, loopsSoFar, Time() + delay )
			// The range respawns any dead player on its own; the corpse goes now,
			// the replacement waits out the delay.
			MRec_KickBot( npc )
			if ( delay > 0.0 )
				wait delay
			MRec_RespawnPlayback( player, pb )
		}()
	}
}

void function MRec_RespawnPlayback( entity player, MRecPlayback pb )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	if ( !pb.wanted )
		return
	int slot = pb.slot
	if ( slot < 0 || slot >= st.recordings.len() || !st.playbacks.contains( pb ) )
	{
		MRec_DropPlayback( st, pb )
		return
	}
	entity npc = MRec_SpawnPlaybackDummy( player, st, slot )
	if ( !IsValid( npc ) )
	{
		MRec_DropPlayback( st, pb )
		return
	}
	MRec_BeginPlayback( player, st, npc, slot, pb )
}

void function MRec_DropPlayback( MRecPlayerState st, MRecPlayback pb )
{
	pb.wanted = false
	if ( st.playbacks.contains( pb ) )
		st.playbacks.remove( st.playbacks.find( pb ) )
}




int function MRec_PlayerBotCount( entity player )
{
	MRecPlayerState ornull stNow = MRec_TryGetState( player )
	if ( stNow == null )
		return 0
	MRecPlayerState st = expect MRecPlayerState( stNow )
	MRec_PrunePlaybacks( st )
	MRec_PruneProgramBots( st )
	return st.playbacks.len() + st.programBots.len()
}

void function MovementRecorder_StopAllForPlayer( entity player )
{
	if ( !IsValid( player ) || !player.IsPlayer() )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	st.countingDown = false
	Signal( player, MREC_SIGNAL_STOP_RECORD )
	if ( st.recording )
		MRec_FinishRecording( player )
	MRec_StopAllPlaybacks( st )
	try
	{
		LegendBot_KickAll( player )
	}
	catch ( eKick )
	{
	}
}

void function MovementRecorder_OnPlayerDisconnected( entity player )
{
	if ( !IsValid( player ) )
		return
	int key = MovementRecorder_PlayerKey( player )
	if ( !( key in file.states ) )
		return
	MRecPlayerState st = file.states[key]
	bool wasRecording = st.recording
	st.countingDown = false
	st.recording = false
	Signal( player, MREC_SIGNAL_STOP_RECORD )
	if ( wasRecording && st.pendingAnimRecording )
	{
		try { player.StopRecordingAnimation() } catch ( eAnimGone ) {}
	}
	if ( wasRecording )
	{
		int id = -1
		try
		{
			id = player.CmdRec_Stop()
		}
		catch ( eStop )
		{
		}
		if ( id >= 0 )
		{
			try
			{
				CmdRec_Free( id )
			}
			catch ( eFree )
			{
			}
		}
	}
	foreach ( MRecRecording rec in st.recordings )
	{
		try
		{
			if ( rec.cmdRecId >= 0 )
				CmdRec_Free( rec.cmdRecId )
			rec.anim = null
		}
		catch ( eFreeRec )
		{
		}
	}
	foreach ( pb in st.playbacks )
	{
		if ( IsValid( pb.dummy ) )
			MRec_KickBot( pb.dummy )
	}
	st.playbacks = []
	MRec_StopProgramBots( st )
	MRec_KickParkedBot( st )
	try
	{
		LegendBot_KickAll( player )
	}
	catch ( eKick )
	{
	}
	st.recordings = []
	delete file.states[key]
	printt( format( "[MRec] Disconnect cleanup %s", player.GetPlayerName() ) )
}
