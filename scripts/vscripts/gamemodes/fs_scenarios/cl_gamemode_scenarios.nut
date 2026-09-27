// Flowstate Scenarios client: per-fight legend pick, team scorebar, standings.

global function Cl_FS_Scenarios_Init
global function Cl_FS_Scenarios_ScoreBarRules
global function ServerCallback_FS_Scenarios_Standing
global function ServerCallback_FS_Scenarios_StandingsDone
global function ServerCallback_FS_Scenarios_HudPhase
global function ServerCallback_FS_Scenarios_HudSlot
global function ServerCallback_FS_Scenarios_HudOut
global function ServerCallback_FS_Scenarios_SquadSize
global function FS_Scenarios_ToggleMapKey

// Mirrors the geometry baked into ui/fs_scenarios_hud.rpak (1920x1080).
const float HUD_CHIP_W = 59.4
const float HUD_CHIP_H = 68.4
const float HUD_CHIP_SKEW = 10.8
const float HUD_CHIP_TOP = 40.8
const float HUD_CHIP_STEP = 73.8
const float HUD_CHIP_CELL = 72.0
const float HUD_SHIELD_DY = 10.8
const float HUD_HEALTH_DY = 5.4
const float HUD_BAR_PAD = 3.6
const float HUD_BAR_W = 51.3
const float HUD_GROUP_MIN = 153.0
const float HUD_VS_W = 34.2
const float HUD_VS_GAP = 12.6
const float HUD_HDR_Y = 13.8
const float HUD_HDR_H = 21.6
// narrowest strip that still fits "SQUAD n" and its count
const float HUD_HDR_MIN = 141.0
const float HUD_FRAME = 1.8
const int HUD_HEADERS = 5
const int HUD_VS_MARKS = 4
// The clock plate sits just under the corner minimap.
const float HUD_PLATE_X = 46.0
const float HUD_PLATE_Y = 298.0
const float HUD_PLATE_W = 244.0
const float HUD_PLATE_H = 100.0
const float HUD_PLATE_PAD = 15.0
const float HUD_TRACK_Y = 62.0
const vector HUD_OFF = <-2.0, -2.0, 0.0>
const asset HUD_ICON_DOWN = $"rui/hud/obituary/obituary_downed"
const asset HUD_ICON_OUT = $"rui/hud/gametype_icons/ltm/deathpos_skull_default"

const vector HUD_FRIEND = <0.345, 0.784, 0.941>
const vector HUD_ENEMY = <0.898, 0.314, 0.227>
const vector HUD_NAME = <0.953, 0.957, 0.965>
const vector HUD_NAME_DIM = <0.424, 0.451, 0.490>
const vector HUD_WHITE = <1.0, 1.0, 1.0>
const vector HUD_KNOCKED = <0.839, 0.235, 0.173>
const vector HUD_RING = <0.941, 0.627, 0.188>
const vector HUD_URGENT = <1.0, 0.353, 0.271>
const vector HUD_GOLD = <0.949, 0.761, 0.188>
const array<vector> HUD_SQUAD_COLORS = [ <0.898, 0.314, 0.227>, <0.839, 0.424, 0.941>, <0.949, 0.604, 0.220>, <0.463, 0.839, 0.451> ]

struct
{
	bool scorebarHasSquadArgs = true

	var hud = null
	bool hudFailed
	int hudFight = -1
	int hudPhase
	float hudT0
	float hudT1
	float hudT2
	int hudScoreStart = -1
	array<entity> slotPlayer
	array<int> slotEHandle
	array<bool> slotOut
	array<int> slotSquad
} file

void function Cl_FS_Scenarios_Init()
{
	// Ring wall, ring sounds and screen effects follow the fight's deathField mover.
	Sh_ArenaDeathField_Init()
	// Knockdowns and freefall: survival's client init owns these and the 1v1 shell never runs it.
	BleedoutClient_Init()
	SurvivalFreefall_Init()

	RegisterNetVarBoolChangeCallback( CharSelect_PlayerStateNetVar( "characterSelectionReady" ), Cl_FS_Scenarios_OnPickReadyChanged )

	// M opens the fullmap like survival; the shell's custom-scoreboard cap would block it.
	Fullmap_SetupScoreboard()
	Scoreboard_SetAllowCustomModeTeamsTab( true )

}

// Map key: the leaderboard while waiting in the lobby, the fullmap during a fight.
void function FS_Scenarios_ToggleMapKey()
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) )
		return

	if ( player.GetPlayerNetInt( "FS_Scenarios_EnemiesAlive" ) >= 0 )
	{
		ClientToUI_ToggleScoreboard()
		return
	}

	if ( IsScoreboardShown() )
		HideScoreboard()

	FS_1v1_ToggleFullScoreboard( player )
}

void function Cl_FS_Scenarios_OnPickReadyChanged( entity player, bool ready )
{
	if ( player != GetLocalClientPlayer() )
		return

	if ( ready )
	{
		if ( !CharacterSelect_MenuIsOpen() )
			OpenCharacterSelectMenu()
		return
	}

	if ( CharacterSelect_MenuIsOpen() )
		CloseCharacterSelectMenu()
}

void function Cl_FS_Scenarios_ScoreBarRules( var gamestateRui, entity player )
{
	if ( !file.scorebarHasSquadArgs )
		return

	int enemies = player.GetPlayerNetInt( "FS_Scenarios_EnemiesAlive" )
	bool inFight = enemies >= 0

	try
	{
		RuiSetBool( gamestateRui, "hideSquadsRemaining", !inFight )
		RuiSetBool( gamestateRui, "shouldDisplayLivingPlayerCount", inFight )
		if ( !inFight )
			return

		RuiSetInt( gamestateRui, "squadsRemainingCount", enemies )
		RuiSetInt( gamestateRui, "livingPlayerCount", enemies )
		RuiSetString( gamestateRui, "squadsRemainingTextSingular", "#FS_SCENARIOS_ENEMY_ALIVE" )
		RuiSetString( gamestateRui, "squadsRemainingTextPlural", "#FS_SCENARIOS_ENEMIES_ALIVE" )
	}
	catch ( eScorebar )
	{
		// This runs every frame; a bar without the squad block is not retried.
		file.scorebarHasSquadArgs = false
	}
}

void function ServerCallback_FS_Scenarios_Standing( int standingType, int scoreType, int value, int count )
{
	RunUIScript( "UI_FS_Scenarios_SetStanding", standingType, scoreType, value, count )
}

void function ServerCallback_FS_Scenarios_StandingsDone()
{
	RunUIScript( "UI_FS_Scenarios_StandingsReady" )
}

// Fights can run smaller squads than the playlist's max_team_size (host setting,
// short-handed forced fight). The pick menu ends its lockstep at MAX_TEAM_PLAYERS
// and spaces the lineup by it, so it has to be this fight's squad size.
void function ServerCallback_FS_Scenarios_SquadSize( int size )
{
	MAX_TEAM_PLAYERS = size
}

//////////////////////////////////////////////////////////////////////////////
// Fight HUD: plate with the phase clock, and a chip per fighter drawn from the
// player entity (alive, knocked, shield, health, legend). Hidden while legends
// are picked; it comes up for the drop.

void function ServerCallback_FS_Scenarios_HudPhase( int phase, int fight, float t0, float t1, float t2 )
{
	if ( phase == eScenariosHudPhase.NONE )
	{
		FS_Scenarios_Hud_Destroy()
		return
	}

	if ( fight != file.hudFight )
	{
		FS_Scenarios_Hud_Destroy()
		file.hudFight = fight
		file.hudScoreStart = -1
		file.slotPlayer.clear()
		file.slotEHandle.clear()
		file.slotOut.clear()
		file.slotSquad.clear()
		for ( int i = 0; i < FS_SCENARIOS_HUD_SLOTS; i++ )
		{
			file.slotPlayer.append( null )
			file.slotEHandle.append( EncodedEHandle_null )
			file.slotOut.append( false )
			file.slotSquad.append( 0 )
		}
	}

	file.hudPhase = phase
	file.hudT0 = t0
	file.hudT1 = t1
	file.hudT2 = t2

	if ( phase == eScenariosHudPhase.PICK || file.hud != null || file.hudFailed )
		return

	try
	{
		asset a = GetKeyValueAsAsset( { kn = "ui/fs_scenarios_hud.rpak" }, "kn" )
		file.hud = CreateCockpitPostFXRui( a, 0 )
		thread FS_Scenarios_Hud_Think( file.hud )
	}
	catch ( eCreate )
	{
		file.hudFailed = true
		printt( "[FS-SCN][HUD] create failed: " + eCreate )
	}
}

void function ServerCallback_FS_Scenarios_HudSlot( int slot, int ehandle, int squad )
{
	if ( slot < 0 || slot >= file.slotPlayer.len() || ehandle == EncodedEHandle_null )
		return
	file.slotEHandle[ slot ] = ehandle
	file.slotPlayer[ slot ] = GetEntityFromEncodedEHandle( ehandle )
	file.slotOut[ slot ] = false
	file.slotSquad[ slot ] = squad
}

void function ServerCallback_FS_Scenarios_HudOut( int ehandle )
{
	if ( ehandle == EncodedEHandle_null )
		return
	foreach ( int i, int eh in file.slotEHandle )
	{
		if ( eh == ehandle )
			file.slotOut[ i ] = true
	}
}

bool function FS_Scenarios_Hud_SlotUsed( int i )
{
	return file.slotEHandle[ i ] != EncodedEHandle_null
}

void function FS_Scenarios_Hud_Destroy()
{
	if ( file.hud != null )
		RuiDestroyIfAlive( file.hud )
	file.hud = null
}

void function FS_Scenarios_Hud_Think( var rui )
{
	while ( file.hud == rui )
	{
		try
		{
			FS_Scenarios_Hud_Update( rui )
		}
		catch ( eUpdate )
		{
			printt( "[FS-SCN][HUD] update failed: " + eUpdate )
			FS_Scenarios_Hud_Destroy()
			file.hudFailed = true
			return
		}
		wait 0.1
	}
}

void function FS_Scenarios_Hud_Col( var rui, string name, vector rgb, float a )
{
	RuiSetColorAlpha( rui, name, SrgbToLinear( rgb ), a )
}

vector function FS_Scenarios_Hud_Px( float x, float y )
{
	return < x / 1920.0, y / 1080.0, 0 >
}

vector function FS_Scenarios_Hud_SquadColor( int squad )
{
	return HUD_SQUAD_COLORS[ squad % HUD_SQUAD_COLORS.len() ]
}

string function FS_Scenarios_Hud_Clock( float seconds )
{
	int s = maxint( 0, int( ceil( seconds ) ) )
	return format( "%d:%02d", s / 60, s % 60 )
}

vector function FS_Scenarios_Hud_ShieldColor( int maxShield )
{
	if ( maxShield >= 125 )
		return HUD_ENEMY
	if ( maxShield >= 100 )
		return <0.706, 0.361, 1.0>
	if ( maxShield >= 75 )
		return <0.243, 0.545, 1.0>
	return <0.855, 0.867, 0.886>
}

void function FS_Scenarios_Hud_HideChip( var rui, int r )
{
	string s = "s" + r
	foreach ( string k in [ "TL", "TR", "BL", "Pos" ] )
		RuiSetFloat2( rui, s + k, HUD_OFF )
	RuiSetString( rui, s + "Name", "" )
}

// Top-left x of a chip tile centred on xc; lean -1 tops the tile left, 1 right, 0 upright.
float function FS_Scenarios_Hud_TileLeft( float xc, int lean )
{
	if ( lean > 0 )
		return xc - ( HUD_CHIP_W + HUD_CHIP_SKEW ) * 0.5 + HUD_CHIP_SKEW
	if ( lean < 0 )
		return xc - ( HUD_CHIP_W + HUD_CHIP_SKEW ) * 0.5
	return xc - HUD_CHIP_W * 0.5
}

void function FS_Scenarios_Hud_PlaceChip( var rui, int r, float xc, int lean )
{
	string s = "s" + r
	float tl = FS_Scenarios_Hud_TileLeft( xc, lean )
	float bl = tl - lean * HUD_CHIP_SKEW
	float top = HUD_CHIP_TOP
	float bot = HUD_CHIP_TOP + HUD_CHIP_H
	RuiSetFloat2( rui, s + "TL", FS_Scenarios_Hud_Px( tl, top ) )
	RuiSetFloat2( rui, s + "TR", FS_Scenarios_Hud_Px( tl + HUD_CHIP_W, top ) )
	RuiSetFloat2( rui, s + "BL", FS_Scenarios_Hud_Px( bl, bot ) )
	RuiSetFloat2( rui, s + "Pos", FS_Scenarios_Hud_Px( xc, top + HUD_CHIP_H * 0.5 ) )
}

// Draws roster slot i into RUI chip r. Returns true when the player is still in the fight.
bool function FS_Scenarios_Hud_DrawChip( var rui, int i, int r, entity me, vector squadColor )
{
	string s = "s" + r
	entity p = file.slotPlayer[ i ]

	bool knocked = IsValid( p ) && IsAlive( p ) && Bleedout_IsBleedingOut( p )
	if ( file.hudPhase == eScenariosHudPhase.LIVE && IsValid( p ) && !IsAlive( p ) )
		file.slotOut[ i ] = true
	bool out = file.slotOut[ i ] || !IsValid( p )
	bool you = IsValid( p ) && p == me

	if ( you && !out )
		FS_Scenarios_Hud_Col( rui, s + "Frame", HUD_WHITE, 1.0 )
	else if ( out )
		FS_Scenarios_Hud_Col( rui, s + "Frame", <0.173, 0.192, 0.220>, 1.0 )
	else
		FS_Scenarios_Hud_Col( rui, s + "Frame", HUD_WHITE, 0.14 )

	bool hasPortrait = false
	if ( IsValid( p ) )
	{
		EHI ehi = ToEHI( p )
		if ( LoadoutSlot_IsReady( ehi, Loadout_Character() ) )
		{
			RuiSetImage( rui, s + "Img", CharacterClass_GetGalleryPortrait( LoadoutSlot_GetItemFlavor( ehi, Loadout_Character() ) ) )
			hasPortrait = true
		}
	}
	if ( !hasPortrait )
		FS_Scenarios_Hud_Col( rui, s + "Portrait", HUD_WHITE, 0.0 )
	else if ( out )
		FS_Scenarios_Hud_Col( rui, s + "Portrait", <0.45, 0.45, 0.45>, 0.6 )
	else
		FS_Scenarios_Hud_Col( rui, s + "Portrait", HUD_WHITE, 1.0 )

	if ( out )
		FS_Scenarios_Hud_Col( rui, s + "Overlay", <0.031, 0.035, 0.043>, 0.5 )
	else if ( knocked )
		FS_Scenarios_Hud_Col( rui, s + "Overlay", HUD_KNOCKED, 0.38 )
	else
		FS_Scenarios_Hud_Col( rui, s + "Overlay", HUD_WHITE, 0.0 )

	FS_Scenarios_Hud_Col( rui, s + "Accent", out ? <0.290, 0.314, 0.349> : squadColor, 1.0 )
	RuiSetImage( rui, s + "Icon", out ? HUD_ICON_OUT : HUD_ICON_DOWN )
	FS_Scenarios_Hud_Col( rui, s + "IconColor", HUD_WHITE, ( out || knocked ) ? 1.0 : 0.0 )

	float shield = 0.0
	float health = 0.0
	int maxShield = 0
	if ( IsValid( p ) && !out )
	{
		maxShield = p.GetShieldHealthMax()
		if ( !knocked && maxShield > 0 )
			shield = clamp( float( p.GetShieldHealth() ) / float( maxShield ), 0.0, 1.0 )
		if ( p.GetMaxHealth() > 0 )
			health = clamp( float( p.GetHealth() ) / float( p.GetMaxHealth() ), 0.0, 1.0 )
	}
	FS_Scenarios_Hud_Col( rui, s + "Shield", FS_Scenarios_Hud_ShieldColor( maxShield ), 1.0 )
	FS_Scenarios_Hud_Col( rui, s + "Health", knocked ? HUD_KNOCKED : <0.949, 0.953, 0.961>, 1.0 )
	// bar ends are in the tile's own slanted space, so they follow its lean
	float u0 = HUD_BAR_PAD / HUD_CHIP_W
	float span = HUD_BAR_W / HUD_CHIP_W
	RuiSetFloat2( rui, s + "ShieldTR", < u0 + span * shield, ( HUD_CHIP_H - HUD_SHIELD_DY ) / HUD_CHIP_H, 0 > )
	RuiSetFloat2( rui, s + "HealthTR", < u0 + span * health, ( HUD_CHIP_H - HUD_HEALTH_DY ) / HUD_CHIP_H, 0 > )

	RuiSetString( rui, s + "Name", IsValid( p ) ? p.GetPlayerName().toupper() : "" )
	FS_Scenarios_Hud_Col( rui, s + "NameColor", out ? HUD_NAME_DIM : HUD_NAME, 1.0 )
	return !out
}

// One row across the top: your squad, then every enemy squad, "VS" between
// each. Groups share one width so the row is symmetric about the screen centre.
void function FS_Scenarios_Hud_LayoutSquads( var rui, entity me )
{
	int friendSlots = FS_SCENARIOS_HUD_FRIEND_SLOTS

	for ( int i = 0; i < FS_SCENARIOS_HUD_SLOTS; i++ )
	{
		if ( FS_Scenarios_Hud_SlotUsed( i ) )
			file.slotPlayer[ i ] = GetEntityFromEncodedEHandle( file.slotEHandle[ i ] )
	}

	array< array<int> > squads
	array<int> colorOf
	squads.append( [] )
	colorOf.append( -1 )
	for ( int i = 0; i < friendSlots; i++ )
	{
		if ( FS_Scenarios_Hud_SlotUsed( i ) )
			squads[ 0 ].append( i )
	}

	array< array<int> > enemies
	for ( int i = friendSlots; i < FS_SCENARIOS_HUD_SLOTS; i++ )
	{
		if ( !FS_Scenarios_Hud_SlotUsed( i ) )
			continue
		int sq = file.slotSquad[ i ]
		while ( enemies.len() <= sq )
			enemies.append( [] )
		enemies[ sq ].append( i )
	}
	foreach ( int sq, array<int> members in enemies )
	{
		if ( members.len() == 0 || squads.len() >= HUD_HEADERS )
			continue
		squads.append( members )
		colorOf.append( sq )
	}

	int count = squads.len()
	int size = 1
	foreach ( array<int> members in squads )
		size = maxint( size, members.len() )
	float groupW = max( size * HUD_CHIP_STEP, HUD_GROUP_MIN )
	float pitch = groupW + HUD_VS_GAP * 2.0 + HUD_VS_W
	float x0 = 960.0 - ( count * pitch - HUD_VS_GAP * 2.0 - HUD_VS_W ) * 0.5
	float chipMid = HUD_CHIP_TOP + HUD_CHIP_H * 0.5

	array<bool> chipUsed
	for ( int r = 0; r < FS_SCENARIOS_HUD_SLOTS; r++ )
		chipUsed.append( false )
	array<bool> headerUsed
	for ( int e = 0; e < HUD_HEADERS; e++ )
		headerUsed.append( false )

	vector youPos = HUD_OFF
	int nextEnemyChip = friendSlots
	foreach ( int g, array<int> members in squads )
	{
		bool first = g == 0
		bool last = !first && g == count - 1
		float left = x0 + g * pitch
		int n = members.len()
		float row = n * HUD_CHIP_STEP - ( HUD_CHIP_STEP - HUD_CHIP_CELL )
		float start = left + ( groupW - row ) * 0.5
		if ( first )
			start = left + groupW - row
		else if ( last )
			start = left
		vector squadColor = first ? HUD_FRIEND : FS_Scenarios_Hud_SquadColor( colorOf[ g ] )

		int alive = 0
		float mid = ( n - 1 ) * 0.5
		float stripL = 0.0
		float stripR = 0.0
		foreach ( int k, int i in members )
		{
			int r = first ? k : nextEnemyChip++
			if ( r >= FS_SCENARIOS_HUD_SLOTS )
				break
			int lean = 0
			if ( first || float( k ) < mid )
				lean = -1
			if ( last || ( !first && float( k ) > mid ) )
				lean = 1
			float xc = start + k * HUD_CHIP_STEP + HUD_CHIP_CELL * 0.5
			FS_Scenarios_Hud_PlaceChip( rui, r, xc, lean )
			bool inFight = FS_Scenarios_Hud_DrawChip( rui, i, r, me, squadColor )
			if ( inFight )
				alive++
			if ( inFight && file.slotPlayer[ i ] == me )
				youPos = FS_Scenarios_Hud_Px( xc, HUD_CHIP_TOP + 5.4 )
			chipUsed[ r ] = true

			float tileL = FS_Scenarios_Hud_TileLeft( xc, lean )
			if ( k == 0 )
				stripL = tileL - HUD_FRAME
			stripR = tileL + HUD_CHIP_W + HUD_FRAME
		}

		// The strip spans the squad's outer chip edges and continues their slant.
		if ( stripR - stripL < HUD_HDR_MIN )
		{
			float grow = ( HUD_HDR_MIN - ( stripR - stripL ) ) * 0.5
			stripL -= grow
			stripR += grow
		}
		float slope = 0.0
		if ( first )
			slope = HUD_CHIP_SKEW / HUD_CHIP_H
		else if ( last )
			slope = -HUD_CHIP_SKEW / HUD_CHIP_H
		float hdrTop = HUD_HDR_Y
		float hdrBot = HUD_HDR_Y + HUD_HDR_H
		int e = first ? 0 : ( last ? HUD_HEADERS - 1 : g )
		string h = "h" + e
		RuiSetFloat2( rui, h + "TL", FS_Scenarios_Hud_Px( stripL + slope * ( hdrTop - HUD_CHIP_TOP ), hdrTop ) )
		RuiSetFloat2( rui, h + "TR", FS_Scenarios_Hud_Px( stripR + slope * ( hdrTop - HUD_CHIP_TOP ), hdrTop ) )
		RuiSetFloat2( rui, h + "BL", FS_Scenarios_Hud_Px( stripL + slope * ( hdrBot - HUD_CHIP_TOP ), hdrBot ) )
		RuiSetString( rui, h + "Num", n > 0 ? string( alive ) + " / " + n : "" )
		if ( e > 0 )
		{
			RuiSetString( rui, h + "Label", count > 2 ? "SQUAD " + ( g + 1 ) : "ENEMY SQUAD" )
			FS_Scenarios_Hud_Col( rui, h + "Color", squadColor, 1.0 )
		}
		headerUsed[ e ] = true

		if ( g < count - 1 && g < HUD_VS_MARKS )
			RuiSetFloat2( rui, "vs" + g + "Pos", FS_Scenarios_Hud_Px( left + groupW + HUD_VS_GAP + HUD_VS_W * 0.5, chipMid ) )
	}

	for ( int e = 0; e < HUD_HEADERS; e++ )
	{
		if ( headerUsed[ e ] )
			continue
		foreach ( string corner in [ "TL", "TR", "BL" ] )
			RuiSetFloat2( rui, "h" + e + corner, HUD_OFF )
		RuiSetString( rui, "h" + e + "Num", "" )
	}
	RuiSetFloat2( rui, "youPos", youPos )
	for ( int v = maxint( 0, count - 1 ); v < HUD_VS_MARKS; v++ )
		RuiSetFloat2( rui, "vs" + v + "Pos", HUD_OFF )
	for ( int r = 0; r < FS_SCENARIOS_HUD_SLOTS; r++ )
	{
		if ( !chipUsed[ r ] )
			FS_Scenarios_Hud_HideChip( rui, r )
	}
}

void function FS_Scenarios_Hud_Update( var rui )
{
	float now = Time()
	entity me = GetLocalClientPlayer()

	FS_Scenarios_Hud_LayoutSquads( rui, me )

	int phase = file.hudPhase
	bool won = phase == eScenariosHudPhase.WON
	bool lost = phase == eScenariosHudPhase.LOST
	bool live = phase == eScenariosHudPhase.LIVE
	int score = IsValid( me ) ? me.GetPlayerNetInt( "FS_Scenarios_PlayerScore" ) : 0
	int wins = IsValid( me ) ? me.GetPlayerNetInt( "FS_Scenarios_MatchesWins" ) : 0
	if ( live && file.hudScoreStart < 0 && IsValid( me ) )
		file.hudScoreStart = score

	vector accent = <0.788, 0.816, 0.847>
	if ( live )
		accent = now < file.hudT1 ? HUD_RING : HUD_ENEMY
	else if ( won )
		accent = HUD_FRIEND
	else if ( lost )
		accent = HUD_ENEMY

	RuiSetFloat2( rui, "plateOrg", FS_Scenarios_Hud_Px( HUD_PLATE_X, HUD_PLATE_Y ) )
	FS_Scenarios_Hud_Col( rui, "accent", accent, 1.0 )

	string title = "FIGHT OVER"
	string clock = ""
	string word = won ? "VICTORY" : "ELIMINATED"
	bool urgent = false
	if ( phase == eScenariosHudPhase.DROP )
	{
		title = "GET READY"
		clock = string( maxint( 0, int( ceil( file.hudT1 - now ) ) ) )
		word = ""
	}
	else if ( live )
	{
		title = "FIGHT " + file.hudFight
		clock = FS_Scenarios_Hud_Clock( file.hudT2 - now )
		word = ""
		urgent = file.hudT2 - now <= 30.0
	}
	RuiSetString( rui, "title", title )
	RuiSetString( rui, "clock", clock )
	RuiSetString( rui, "clockWord", word )
	vector clockCol = urgent ? HUD_URGENT : HUD_WHITE
	if ( won )
		clockCol = HUD_GOLD
	FS_Scenarios_Hud_Col( rui, "clockColor", clockCol, 1.0 )

	float span = file.hudT1 - file.hudT0
	float frac = 0.0
	if ( live )
		frac = span > 0.0 ? clamp( ( now - file.hudT0 ) / span, 0.0, 1.0 ) : 1.0
	RuiSetString( rui, "ringLabel", live ? ( now < file.hudT1 ? "RING CLOSING" : "RING CLOSED" ) : "" )
	RuiSetString( rui, "ringTime", ( live && now < file.hudT1 ) ? FS_Scenarios_Hud_Clock( file.hudT1 - now ) : "" )
	float trackX = HUD_PLATE_PAD / HUD_PLATE_W
	float trackW = ( HUD_PLATE_W - HUD_PLATE_PAD * 2.0 ) / HUD_PLATE_W
	RuiSetFloat2( rui, "ringFillTR", < trackX + trackW * frac, HUD_TRACK_Y / HUD_PLATE_H, 0 > )

	string sub = ""
	if ( phase == eScenariosHudPhase.DROP )
		sub = "DROPPING IN"
	else if ( won || lost )
		sub = file.hudScoreStart >= 0 ? format( "+%d SCORE", maxint( 0, score - file.hudScoreStart ) ) : "BACK TO QUEUE"
	RuiSetString( rui, "subLine", sub )

	RuiSetString( rui, "scoreText", IsValid( me ) ? "SCORE " + score : "" )
	RuiSetString( rui, "winsText", IsValid( me ) ? "WINS " + wins : "" )
}
