// Lab > Mods. The player's mod heirloom, then the server mutator list.
// Slot labels come from the mod registry, so a new mod appears without an edit.

global function InitLabModsPanel
global function LabMods_SetBits
global function LabMods_SetHeirloom
global function LabMods_OnHeirloomNotice

const int LAB_MOD_ROWS = 12
const int LAB_RGB_PANEL_TALL = 300
const float LAB_RGB_VALUE_MIN = 0.5

struct
{
	var panel
	var contentPanelParent
	var contentPanel
	var scrollBar
	var scrollFrame

	array<var> modRows
	array<string> modIds

	var buttonDisableAll
	var serverModsHeader
	var serverModsHeaderText

	var switchHeirloom
	int heirloomIndex = -1

	var switchColor
	string colorWritten

	var switchModWeapon

	var rgbPanel
	var rgbPlate
	var rgbHue
	var rgbShade
	array<var> rgbSwatches
	array<var> rgbEntries
	bool rgbShown = false
	vector rgbColor
	vector rgbPrevious
	float rgbHueProgress
	float rgbShadeProgress
	bool lookSendQueued = false
	table<int, bool> refused

	int  modBits = 0

	bool applyingValues = false
} file

void function InitLabModsPanel( var panel )
{
	file.panel = panel

	file.contentPanelParent = Hud_GetChild( panel, "ModeOptionsPanel" )
	file.contentPanel = Hud_GetChild( file.contentPanelParent, "ContentPanel" )
	file.scrollBar = Hud_GetChild( file.contentPanelParent, "ScrollBar" )
	file.scrollFrame = Hud_GetChild( file.contentPanelParent, "ScrollFrame" )

	file.serverModsHeader = Hud_GetChild( file.contentPanel, "ServerModsHeader" )
	file.serverModsHeaderText = Hud_GetChild( file.contentPanel, "ServerModsHeaderText" )
	file.buttonDisableAll = Hud_GetChild( file.contentPanel, "ButtonDisableAllMods" )
	file.switchHeirloom = Hud_GetChild( file.contentPanel, "SwitchHeirloom" )

	Lab_SetupRow( file.switchHeirloom, "Heirloom",
		"Wear an heirloom from an installed mod in place of your loadout melee. The server remembers it." )
	AddButtonEventHandler( file.switchHeirloom, UIE_CHANGE, LabMods_OnHeirloomChanged )

	file.switchColor = Hud_GetChild( file.contentPanel, "SwitchHeirloomColor" )
	Lab_SetupRow( file.switchColor, "Heirloom Color",
		"Pick a color for heirlooms that support one, or Cycle. Everyone in the match sees it. Very dark colors are brightened." )
	AddButtonEventHandler( file.switchColor, UIE_CHANGE, LabMods_OnColorPreset )

	LabMods_InitRgbPanel()

	file.switchModWeapon = Hud_GetChild( file.contentPanel, "SwitchModWeapon" )
	Lab_SetupRow( file.switchModWeapon, "Mod Weapon",
		"Swap a gun from an installed mod into your active primary slot. Works with cheats on or in modes that allow mod weapons." )
	AddButtonEventHandler( file.switchModWeapon, UIE_CHANGE, LabMods_OnModWeaponChanged )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabModsPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabModsPanel_Hide )

	for ( int i = 0; i < LAB_MOD_ROWS; i++ )
	{
		var row = Hud_GetChild( file.contentPanel, format( "SwitchMod%d", i ) )
		file.modRows.append( row )
		file.modIds.append( "" )

		Hud_Hide( row )
		Hud_SetEnabled( row, false )

		AddButtonEventHandler( row, UIE_CHANGE, LabMods_OnModChanged )
	}

	Lab_SetupRow( file.buttonDisableAll, "#LAB_MODS_DISABLEALL",
		"#LAB_MODS_DISABLEALL_DESC", true )

	AddButtonEventHandler( file.buttonDisableAll, UIE_CLICK, LabMods_OnDisableAll )

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_InitPanel( file.contentPanelParent )
	ScrollPanel_InitScrollBar( file.contentPanelParent, file.scrollBar )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	Lab_AddGateListener( LabMods_ApplyGates )
}

void function OnLabModsPanel_Show( var panel )
{
	ClientCommand( "cafemod sync" )
	if ( ModHeirloom_GetCount() > 0 )
		ClientCommand( "mod_heirloom sync" )

	LabMods_RebuildHeirloomList()
	LabMods_RebuildModWeaponList()
	LabMods_RebuildModRows()
	LabMods_ApplyGates()

	ScrollPanel_SetActive( file.contentPanelParent, true )
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

void function OnLabModsPanel_Hide( var panel )
{
	ScrollPanel_SetActive( file.contentPanelParent, false )
}

// One visible row per registered mod; the rest stay hidden and unfocusable.
void function LabMods_RebuildModRows()
{
	if ( file.modRows.len() == 0 )
		return

	int total = CafeMod_GetTotalCount()
	int shown = 0

	for ( int i = 0; i < total && shown < LAB_MOD_ROWS; i++ )
	{
		string id = CafeMod_GetId( i )
		if ( id == "" || id == "items_weapon" )
			continue

		string name = CafeMod_GetName( i )
		if ( name == "" )
			name = id

		var row = file.modRows[ shown ]

		// Row labels are wired once per slot; the registry only grows.
		if ( file.modIds[ shown ] != id )
		{
			file.modIds[ shown ] = id
			Lab_SetupRow( row, name, format( Localize( "#LAB_MODS_ROW_DESC_FMT" ), name ), true )
		}

		Hud_Show( row )

		file.applyingValues = true
		Hud_SetDialogListSelectionValue( row, CafeMod_IsBitSet( file.modBits, i ) ? "1" : "0" )
		file.applyingValues = false

		shown++
	}

	for ( int i = shown; i < LAB_MOD_ROWS; i++ )
	{
		file.modIds[ i ] = ""
		Hud_Hide( file.modRows[ i ] )
		Hud_SetEnabled( file.modRows[ i ], false )
	}

	if ( shown > 0 )
	{
		Hud_Show( file.serverModsHeader )
		Hud_Show( file.serverModsHeaderText )
	}
	else
	{
		Hud_Hide( file.serverModsHeader )
		Hud_Hide( file.serverModsHeaderText )
	}
}

void function LabMods_SetBits( int bitfield )
{
	file.modBits = bitfield
	LabMods_RebuildModRows()
	LabMods_ApplyGates()
}

// Any player may wear one; the server validates the pick against the mods it loaded.
void function LabMods_RebuildHeirloomList()
{
	file.applyingValues = true
	Hud_DialogList_ClearList( file.switchHeirloom )
	Hud_DialogList_AddListItem( file.switchHeirloom, "Loadout melee", "none" )
	for ( int i = 0; i < ModHeirloom_GetCount(); i++ )
	{
		string label = ModHeirloom_GetName( i ) + ( ( i in file.refused ) ? " (unavailable)" : "" )
		Hud_DialogList_AddListItem( file.switchHeirloom, label, ModHeirloom_GetPrimary( i ) )
	}

	string primary = ModHeirloom_GetPrimary( file.heirloomIndex )
	Hud_SetDialogListSelectionValue( file.switchHeirloom, primary != "" ? primary : "none" )
	file.applyingValues = false

	Hud_SetEnabled( file.switchHeirloom, ModHeirloom_GetCount() > 0 )
	LabMods_RefreshColorRows()
}

// A pick is a one-shot give; the row stays on it so the player sees what they took.
void function LabMods_RebuildModWeaponList()
{
	string current = Hud_GetDialogListSelectionValue( file.switchModWeapon )
	file.applyingValues = true
	Hud_DialogList_ClearList( file.switchModWeapon )
	Hud_DialogList_AddListItem( file.switchModWeapon, "None", "none" )
	for ( int i = 0; i < ModWeapon_GetCount(); i++ )
		Hud_DialogList_AddListItem( file.switchModWeapon, ModWeapon_GetName( i ), ModWeapon_GetClass( i ) )
	Hud_SetDialogListSelectionValue( file.switchModWeapon, ModWeapon_FindClass( current ) >= 0 ? current : "none" )
	file.applyingValues = false
	Hud_SetEnabled( file.switchModWeapon, ModWeapon_GetCount() > 0 )
}

void function LabMods_OnModWeaponChanged( var button )
{
	if ( file.applyingValues )
		return

	string cls = Hud_GetDialogListSelectionValue( button )
	if ( ModWeapon_FindClass( cls ) >= 0 )
		ClientCommand( "mod_weapon " + cls )
}

table<string, string> function LabMods_ColorPresets()
{
	return {
		[ "Green" ] = "40 255 70", [ "Blue" ] = "40 130 255", [ "Red" ] = "255 30 30",
		[ "Purple" ] = "170 60 255", [ "Yellow" ] = "255 220 40", [ "Orange" ] = "255 120 20",
		[ "Cyan" ] = "40 240 255", [ "Pink" ] = "255 80 200", [ "White" ] = "255 255 255"
	}
}

array<string> function LabMods_ColorPresetOrder()
{
	return [ "Green", "Blue", "Red", "Purple", "Yellow", "Orange", "Cyan", "Pink", "White" ]
}

string function LabMods_ColorConVar()
{
	return ModHeirloom_GetColorConVar( file.heirloomIndex )
}

// The preset matching a ConVar value ("green", "40 255 70", "cycle"), or "" for a custom colour.
string function LabMods_PresetFor( string value )
{
	if ( value.tolower() == "cycle" )
		return "cycle"
	foreach ( string name, string rgb in LabMods_ColorPresets() )
	{
		if ( rgb == value || name.tolower() == value.tolower() )
			return name
	}
	return ""
}

// Shows the worn heirloom's colour setting; the row goes inert when it has none. A colour set
// from the console that matches no preset shows as Custom and is left alone.
void function LabMods_RefreshColorRows()
{
	if ( file.switchColor == null )
		return

	string convar = LabMods_ColorConVar()
	string value = convar != "" ? strip( GetConVarString( convar ) ) : ""

	array<string> keys = ModHeirloom_GetStyleKeys( file.heirloomIndex )
	if ( keys.len() > 0 )
	{
		array<string> labels = ModHeirloom_GetStyleLabels( file.heirloomIndex )
		file.applyingValues = true
		Hud_DialogList_ClearList( file.switchColor )
		for ( int i = 0; i < keys.len(); i++ )
			Hud_DialogList_AddListItem( file.switchColor, labels[ i ], keys[ i ] )
		Hud_SetDialogListSelectionValue( file.switchColor, keys.contains( value ) ? value : keys[0] )
		file.colorWritten = value
		file.applyingValues = false
		Hud_SetEnabled( file.switchColor, true )
		LabMods_RefreshRgbPanel()
		return
	}

	string preset = LabMods_PresetFor( value )

	file.applyingValues = true
	Hud_DialogList_ClearList( file.switchColor )
	foreach ( string name in LabMods_ColorPresetOrder() )
		Hud_DialogList_AddListItem( file.switchColor, name, name )
	Hud_DialogList_AddListItem( file.switchColor, "Cycle", "cycle" )
	if ( preset == "" && value != "" )
		Hud_DialogList_AddListItem( file.switchColor, "Custom", "custom" )
	Hud_SetDialogListSelectionValue( file.switchColor, preset != "" ? preset : ( value != "" ? "custom" : "Green" ) )
	file.colorWritten = value
	file.applyingValues = false

	Hud_SetEnabled( file.switchColor, convar != "" )
	LabMods_RefreshRgbPanel()
}

// The client sends the ConVar to the server while the heirloom is out; nothing goes on the wire here.
void function LabMods_OnColorPreset( var button )
{
	if ( file.applyingValues )
		return

	LabMods_RefreshRgbPanel()
	string convar = LabMods_ColorConVar()
	string pick = Hud_GetDialogListSelectionValue( button )
	table<string, string> presets = LabMods_ColorPresets()
	string value = pick == "cycle" ? "cycle" : ( ( pick in presets ) ? presets[ pick ] : "" )
	if ( ModHeirloom_GetStyleKeys( file.heirloomIndex ).contains( pick ) )
		value = pick
	if ( convar == "" || value == "" || value == file.colorWritten )
		return

	file.colorWritten = value
	SetConVarString( convar, value )
	if ( ModHeirloom_GetStyleKeys( file.heirloomIndex ).contains( value ) )
		LabMods_QueueLookSend()
}

// ---- free colour for a heirloom's last style (ModHeirloom_RegisterStyleColor) ----
// Same controls and HSV mapping as the stock reticle color menu, writing the mod's own ConVar.

array<vector> function LabMods_RgbSwatchColors()
{
	return [ <40, 255, 70>, <40, 130, 255>, <255, 30, 30>, <170, 60, 255>, <255, 200, 40> ]
}

void function LabMods_InitRgbPanel()
{
	file.rgbPanel = Hud_GetChild( file.contentPanel, "HeirloomRgbPanel" )
	file.rgbPlate = Hud_GetChild( file.rgbPanel, "Plate" )
	file.rgbHue = Hud_GetChild( file.rgbPanel, "H_Slider" )
	file.rgbShade = Hud_GetChild( file.rgbPanel, "SV_Slider" )
	RuiSetBool( Hud_GetRui( Hud_GetChild( file.rgbShade, "PrgValue" ) ), "isShade", true )
	Hud_AddEventHandler( file.rgbHue, UIE_CHANGE, LabMods_OnRgbHue )
	Hud_AddEventHandler( file.rgbShade, UIE_CHANGE, LabMods_OnRgbShade )

	array<vector> swatches = LabMods_RgbSwatchColors()
	for ( int i = 0; i < swatches.len(); i++ )
	{
		var btn = Hud_GetChild( file.rgbPanel, format( "BtnSwatch%d", i ) )
		file.rgbSwatches.append( btn )
		RuiSetFloat3( Hud_GetRui( btn ), "paletteColor", swatches[ i ] )
		AddButtonEventHandler( btn, UIE_CLICK, LabMods_OnRgbSwatch )
	}
	foreach ( string ch in [ "R", "G", "B" ] )
	{
		var entry = Hud_GetChild( file.rgbPanel, "Color" + ch + "TextEntry" )
		file.rgbEntries.append( entry )
		AddButtonEventHandler( entry, UIE_CHANGE, LabMods_OnRgbEntry )
	}
	Hud_SetColor( file.rgbEntries[0], 255, 54, 54 )
	Hud_SetColor( file.rgbEntries[1], 31, 255, 68 )
	Hud_SetColor( file.rgbEntries[2], 57, 129, 255 )

	LabMods_SetRgbPanelShown( false, false )
}

void function LabMods_SetRgbPanelShown( bool shown, bool relayout = true )
{
	file.rgbShown = shown
	Hud_SetHeight( file.rgbPanel, shown ? ContentScaledYAsInt( LAB_RGB_PANEL_TALL ) : 0 )
	Hud_SetVisible( file.rgbPanel, shown )
	Hud_SetEnabled( file.rgbHue, shown )
	Hud_SetEnabled( file.rgbShade, shown )
	foreach ( var btn in file.rgbSwatches )
		Hud_SetEnabled( btn, shown )
	foreach ( var entry in file.rgbEntries )
		Hud_SetEnabled( entry, shown )

	if ( !relayout )
		return
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

// "r g b" with 0-255 integer channels -> vector; fallback when malformed.
vector function LabMods_ParseRgb( string value, vector fallback )
{
	array<string> parts = split( value, " \t" )
	if ( parts.len() != 3 )
		return fallback
	array<int> rgb
	foreach ( string part in parts )
	{
		if ( part.len() == 0 || part.len() > 3 )
			return fallback
		for ( int i = 0; i < part.len(); i++ )
		{
			if ( "0123456789".find( part.slice( i, i + 1 ) ) < 0 )
				return fallback
		}
		int v = part.tointeger()
		if ( v > 255 )
			return fallback
		rgb.append( v )
	}
	return < rgb[0], rgb[1], rgb[2] >
}

// Shown while the style list sits on the key the mod registered for a free colour.
void function LabMods_RefreshRgbPanel()
{
	if ( file.rgbPanel == null )
		return

	string convar = ModHeirloom_GetStyleColorConVar( file.heirloomIndex )
	string key = ModHeirloom_GetStyleColorKey( file.heirloomIndex )
	bool show = convar != "" && key != "" && Hud_GetDialogListSelectionValue( file.switchColor ) == key
	if ( !show )
	{
		if ( file.rgbShown )
			LabMods_SetRgbPanelShown( false )
		return
	}

	if ( !file.rgbShown )
	{
		file.rgbColor = LabMods_ParseRgb( strip( GetConVarString( convar ) ), LabMods_RgbSwatchColors()[3] )
		file.rgbPrevious = file.rgbColor
		file.rgbHueProgress = OptionsColor_RGBToHSV( file.rgbColor ).hue / 360
		LabMods_UpdateRgbShadeProgress()
		LabMods_SetRgbPanelShown( true )
	}
	LabMods_ApplyRgb( file.rgbColor, true )
}

void function LabMods_UpdateRgbShadeProgress()
{
	HSV hsv = OptionsColor_RGBToHSV( file.rgbColor )
	if ( hsv.value > hsv.saturation )
		file.rgbShadeProgress = 1.0 - max( hsv.saturation, 0.0 ) / 2.0
	else
		file.rgbShadeProgress = max( hsv.value - LAB_RGB_VALUE_MIN, 0.0 )
}

// Stores the colour, writes the mod ConVar and redraws; moveSliders is false while a slider drives it.
void function LabMods_ApplyRgb( vector color, bool moveSliders )
{
	int r = maxint( 0, minint( 255, int( color.x + 0.5 ) ) )
	int g = maxint( 0, minint( 255, int( color.y + 0.5 ) ) )
	int b = maxint( 0, minint( 255, int( color.z + 0.5 ) ) )
	file.rgbColor = < r, g, b >

	string convar = ModHeirloom_GetStyleColorConVar( file.heirloomIndex )
	string value = format( "%d %d %d", r, g, b )
	if ( convar != "" && strip( GetConVarString( convar ) ) != value )
	{
		SetConVarString( convar, value )
		LabMods_QueueLookSend()
	}

	var rui = Hud_GetRui( file.rgbPlate )
	RuiSetColorAlpha( rui, "currentColor", SrgbToLinear( file.rgbColor / 255.0 ), 1.0 )
	RuiSetColorAlpha( rui, "previousColor", SrgbToLinear( file.rgbPrevious / 255.0 ), 1.0 )
	RuiSetString( rui, "rgbText", value )

	file.applyingValues = true
	if ( moveSliders )
		LabMods_RedrawRgbSliders()
	array<int> channels = [ r, g, b ]
	for ( int i = 0; i < 3; i++ )
	{
		if ( Hud_GetUTF8Text( file.rgbEntries[ i ] ) != string( channels[ i ] ) )
			Hud_SetUTF8Text( file.rgbEntries[ i ], string( channels[ i ] ) )
	}
	file.applyingValues = false
}

// Hue band and shade gradient follow the colour; also moves both knobs to the stored progress.
void function LabMods_RedrawRgbSliders()
{
	bool wasApplying = file.applyingValues
	file.applyingValues = true
	OptionsColor_UpdateColorSliders( file.rgbPanel, Hud_GetChild( file.rgbHue, "PrgValue" ), Hud_GetChild( file.rgbShade, "PrgValue" ),
		file.rgbColor, file.rgbHueProgress, file.rgbShadeProgress )
	file.applyingValues = wasApplying
}

void function LabMods_OnRgbHue( var slider )
{
	if ( file.applyingValues || !file.rgbShown )
		return
	HSV current = OptionsColor_RGBToHSV( file.rgbColor )
	HSV next
	next.hue = Hud_SliderControl_GetCurrentValue( slider ) * 360
	next.saturation = current.saturation
	next.value = current.value
	file.rgbHueProgress = Hud_SliderControl_GetCurrentValue( slider )
	LabMods_ApplyRgb( OptionsColor_HSVToRGB( next ), false )
	LabMods_RedrawRgbSliders()
}

void function LabMods_OnRgbShade( var slider )
{
	if ( file.applyingValues || !file.rgbShown )
		return
	float v = Hud_SliderControl_GetCurrentValue( slider )
	HSV next
	next.hue = file.rgbHueProgress * 360
	next.saturation = v <= 0.5 ? 1.0 : 1.0 - ( v - 0.5 ) * 2.0
	next.value = v > 0.5 ? 1.0 : LAB_RGB_VALUE_MIN + v * 2.0 * ( 1.0 - LAB_RGB_VALUE_MIN )
	file.rgbShadeProgress = v
	LabMods_ApplyRgb( OptionsColor_HSVToRGB( next ), false )
	LabMods_RedrawRgbSliders()
}

void function LabMods_SetRgbFromPick( vector color )
{
	file.rgbColor = color
	file.rgbHueProgress = OptionsColor_RGBToHSV( color ).hue / 360
	LabMods_UpdateRgbShadeProgress()
	LabMods_ApplyRgb( color, true )
}

void function LabMods_OnRgbSwatch( var button )
{
	int index = file.rgbSwatches.find( button )
	if ( index < 0 || !file.rgbShown )
		return
	LabMods_SetRgbFromPick( LabMods_RgbSwatchColors()[ index ] )
}

void function LabMods_OnRgbEntry( var entry )
{
	if ( file.applyingValues || !file.rgbShown )
		return
	string text = format( "%s %s %s", Hud_GetUTF8Text( file.rgbEntries[0] ), Hud_GetUTF8Text( file.rgbEntries[1] ), Hud_GetUTF8Text( file.rgbEntries[2] ) )
	vector color = LabMods_ParseRgb( text, < -1, -1, -1 > )
	if ( color.x >= 0 )
		LabMods_SetRgbFromPick( color )
}

// The server owns the look everyone sees; send it at most every quarter second while dragging.
void function LabMods_QueueLookSend()
{
	if ( file.lookSendQueued )
		return
	file.lookSendQueued = true
	thread LabMods_SendLookThread()
}

void function LabMods_SendLookThread()
{
	wait 0.25
	file.lookSendQueued = false

	int index = file.heirloomIndex
	string styleConVar = ModHeirloom_GetColorConVar( index )
	if ( styleConVar == "" )
		return
	string rgbConVar = ModHeirloom_GetStyleColorConVar( index )
	string cmd = ModHeirloom_BuildLookCommand( index, strip( GetConVarString( styleConVar ) ).tolower(),
		rgbConVar != "" ? strip( GetConVarString( rgbConVar ) ) : "" )
	if ( cmd != "" )
		ClientCommand( cmd )
}

void function LabMods_OnHeirloomNotice( int index, int kind )
{
	string name = ModHeirloom_GetName( index )
	if ( kind == eModHeirloomNotice.REFUSED )
	{
		if ( !( index in file.refused ) )
		{
			file.refused[ index ] <- true
			if ( file.switchHeirloom != null )
				LabMods_RebuildHeirloomList()
		}
		Lab_SetDetails( name, "This server refuses this heirloom: its gameplay values differ from the original heirloom it is built on." )
	}
	else if ( kind == eModHeirloomNotice.PENDING )
	{
		Lab_SetDetails( name, "Equipped at the next round or respawn." )
	}
}

void function LabMods_SetHeirloom( int index )
{
	file.heirloomIndex = index
	if ( file.switchHeirloom != null )
		LabMods_RebuildHeirloomList()
}

void function LabMods_OnHeirloomChanged( var button )
{
	if ( file.applyingValues )
		return

	string primary = Hud_GetDialogListSelectionValue( button )
	if ( primary == "none" || ModHeirloom_FindPrimary( primary ) >= 0 )
		ClientCommand( "mod_heirloom " + primary )
}

void function LabMods_ApplyGates()
{
	if ( file.modRows.len() == 0 )
		return

	Hud_SetEnabled( file.switchHeirloom, ModHeirloom_GetCount() > 0 )
	Hud_SetEnabled( file.switchColor, LabMods_ColorConVar() != "" )
	Hud_SetEnabled( file.switchModWeapon, ModWeapon_GetCount() > 0 )

	for ( int i = 0; i < LAB_MOD_ROWS; i++ )
	{
		if ( file.modIds[ i ] == "" )
			continue
		Lab_SetRowState( file.modRows[ i ], true )
	}

	Lab_SetRowState( file.buttonDisableAll, true )

	if ( Lab_GetCheats() && !Lab_IsHostSeat() )
		Lab_SetDetails( Localize( "#LAB_MODS_HOST_TITLE" ), Localize( "#LAB_MODS_HOST_DESC" ) )
}

void function LabMods_OnModChanged( var button )
{
	if ( file.applyingValues || !Lab_GetCheats() || !Lab_IsHostSeat() )
		return

	int index = file.modRows.find( button )
	if ( index < 0 || file.modIds[ index ] == "" )
		return

	ClientCommand( "cafemod toggle " + file.modIds[ index ] )
}

void function LabMods_OnDisableAll( var button )
{
	if ( !Lab_GetCheats() || !Lab_IsHostSeat() )
		return
	ClientCommand( "cafemod disable_all" )
}
