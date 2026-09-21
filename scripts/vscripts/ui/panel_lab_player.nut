// Lab > Player. Everything that acts on the person using the menu.
// Every action is issued as a ClientCommand so the server binds it to the
// caller; nothing here reaches another player.

global function InitLabPlayerPanel
global function LabPlayer_SetInfiniteAbilities

const string LAB_LEGEND_NONE = "?"

struct
{
	var panel
	var contentPanelParent
	var contentPanel
	var scrollBar
	var scrollFrame

	table< string, var > rows

	bool listsBuilt = false
	bool applyingValues = false
	bool infiniteAbilities = false

	array<string> legendRefs
	array<string> bodyModelIds
} file

void function InitLabPlayerPanel( var panel )
{
	file.panel = panel

	file.contentPanelParent = Hud_GetChild( panel, "ModeOptionsPanel" )
	file.contentPanel = Hud_GetChild( file.contentPanelParent, "ContentPanel" )
	file.scrollBar = Hud_GetChild( file.contentPanelParent, "ScrollBar" )
	file.scrollFrame = Hud_GetChild( file.contentPanelParent, "ScrollFrame" )

	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, OnLabPlayerPanel_Show )
	AddPanelEventHandler( panel, eUIEvent.PANEL_HIDE, OnLabPlayerPanel_Hide )

	LabPlayer_BindRows()

	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_InitPanel( file.contentPanelParent )
	ScrollPanel_InitScrollBar( file.contentPanelParent, file.scrollBar )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )

	Lab_AddGateListener( LabPlayer_ApplyGates )
}

var function LabPlayer_Row( string name )
{
	return file.rows[ name ]
}

void function LabPlayer_BindRows()
{
	array<string> names = [
		"SwitchGodMode", "SwitchNoClip", "SwitchInfiniteAmmo", "SwitchInfiniteAbilities",
		"SwitchAutoRespawn", "ButtonRecharge", "ButtonRespawnMe", "ButtonKillSelf",
		"SwitchThirdPerson", "SwitchHud", "SwitchSkyboxView",
		"SwitchLegendGroup", "SwitchLegend", "SwitchBodyModel", "ButtonAlterLoadout"
	]

	foreach ( string name in names )
		file.rows[ name ] <- Hud_GetChild( file.contentPanel, name )

	Lab_SetupRow( LabPlayer_Row( "SwitchGodMode" ), "#LAB_PLAYER_GODMODE",
		"#LAB_PLAYER_GODMODE_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchNoClip" ), "#LAB_PLAYER_NOCLIP",
		"#LAB_PLAYER_NOCLIP_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchInfiniteAmmo" ), "#LAB_PLAYER_INFAMMO",
		"#LAB_PLAYER_INFAMMO_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchInfiniteAbilities" ), "#LAB_PLAYER_INFAB",
		"#LAB_PLAYER_INFAB_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchAutoRespawn" ), "#LAB_PLAYER_AUTORESPAWN",
		"#LAB_PLAYER_AUTORESPAWN_DESC" )
	Lab_SetupRow( LabPlayer_Row( "ButtonRecharge" ), "#LAB_PLAYER_RECHARGE",
		"#LAB_PLAYER_RECHARGE_DESC" )
	Lab_SetupRow( LabPlayer_Row( "ButtonRespawnMe" ), "#LAB_PLAYER_RESPAWNME",
		"#LAB_PLAYER_RESPAWNME_DESC" )
	Lab_SetupRow( LabPlayer_Row( "ButtonKillSelf" ), "#LAB_PLAYER_KILLSELF",
		"#LAB_PLAYER_KILLSELF_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchThirdPerson" ), "#LAB_PLAYER_THIRDPERSON",
		"#LAB_PLAYER_THIRDPERSON_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchHud" ), "#LAB_PLAYER_HUDVIS", "#LAB_PLAYER_HUDVIS_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchSkyboxView" ), "#LAB_PLAYER_SKYBOX",
		"#LAB_PLAYER_SKYBOX_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchLegendGroup" ), "#LAB_PLAYER_LEGENDGROUP",
		"#LAB_PLAYER_LEGENDGROUP_DESC" )
	Lab_SetupRow( LabPlayer_Row( "SwitchLegend" ), "#LAB_PLAYER_LEGEND",
		"#LAB_PLAYER_LEGEND_DESC", true )
	Lab_SetupRow( LabPlayer_Row( "SwitchBodyModel" ), "#LAB_PLAYER_BODYMODEL",
		"#LAB_PLAYER_BODYMODEL_DESC", true )
	Lab_SetupRow( LabPlayer_Row( "ButtonAlterLoadout" ), "#LAB_PLAYER_LOADOUT",
		"#LAB_PLAYER_LOADOUT_DESC" )
	Hud_Hide( LabPlayer_Row( "ButtonAlterLoadout" ) )
	Hud_SetEnabled( LabPlayer_Row( "ButtonAlterLoadout" ), false )

	AddButtonEventHandler( LabPlayer_Row( "SwitchGodMode" ), UIE_CHANGE, LabPlayer_OnGodMode )
	AddButtonEventHandler( LabPlayer_Row( "SwitchNoClip" ), UIE_CHANGE, LabPlayer_OnNoClip )
	AddButtonEventHandler( LabPlayer_Row( "SwitchInfiniteAmmo" ), UIE_CHANGE, LabPlayer_OnInfiniteAmmo )
	AddButtonEventHandler( LabPlayer_Row( "SwitchInfiniteAbilities" ), UIE_CHANGE, LabPlayer_OnInfiniteAbilities )
	AddButtonEventHandler( LabPlayer_Row( "SwitchAutoRespawn" ), UIE_CHANGE, LabPlayer_OnAutoRespawn )
	AddButtonEventHandler( LabPlayer_Row( "SwitchThirdPerson" ), UIE_CHANGE, LabPlayer_OnThirdPerson )
	AddButtonEventHandler( LabPlayer_Row( "SwitchHud" ), UIE_CHANGE, LabPlayer_OnHud )
	AddButtonEventHandler( LabPlayer_Row( "SwitchSkyboxView" ), UIE_CHANGE, LabPlayer_OnSkyboxView )
	AddButtonEventHandler( LabPlayer_Row( "SwitchLegendGroup" ), UIE_CHANGE, LabPlayer_OnLegendGroup )
	AddButtonEventHandler( LabPlayer_Row( "SwitchLegend" ), UIE_CHANGE, LabPlayer_OnLegend )
	AddButtonEventHandler( LabPlayer_Row( "SwitchBodyModel" ), UIE_CHANGE, LabPlayer_OnBodyModel )

	AddButtonEventHandler( LabPlayer_Row( "ButtonRecharge" ), UIE_CLICK, LabPlayer_OnRecharge )
	AddButtonEventHandler( LabPlayer_Row( "ButtonRespawnMe" ), UIE_CLICK, LabPlayer_OnRespawnMe )
	AddButtonEventHandler( LabPlayer_Row( "ButtonKillSelf" ), UIE_CLICK, LabPlayer_OnKillSelf )
	AddButtonEventHandler( LabPlayer_Row( "ButtonAlterLoadout" ), UIE_CLICK, LabPlayer_OnAlterLoadout )
}

void function OnLabPlayerPanel_Show( var panel )
{
	if ( !file.listsBuilt )
	{
		LabPlayer_BuildDynamicLists()
		file.listsBuilt = true
	}

	LabPlayer_ApplyGates()

	file.applyingValues = true
	Hud_SetDialogListSelectionValue( LabPlayer_Row( "SwitchHud" ), DevHud_IsHidden() ? "0" : "1" )
	Hud_SetDialogListSelectionValue( LabPlayer_Row( "SwitchInfiniteAbilities" ), file.infiniteAbilities ? "1" : "0" )
	file.applyingValues = false

	ScrollPanel_SetActive( file.contentPanelParent, true )
	SettingsPanel_SetContentPanelHeight( file.contentPanel )
	ScrollPanel_Refresh( file.contentPanelParent )
}

void function OnLabPlayerPanel_Hide( var panel )
{
	ScrollPanel_SetActive( file.contentPanelParent, false )
}

// The legend list is read from the character registry. Body models have no
// registry to read, so the three cafe overrides are named here.
void function LabPlayer_BuildDynamicLists()
{
	LabPlayer_BuildBodyModelList()

	LabPlayer_BuildLegendGroupList()
	LabPlayer_BuildLegendListForGroup( LabPlayer_DefaultLegendGroup() )
}

// The list popup shows a handful of rows; legends are grouped by class so no
// single list overflows.
int function LabPlayer_DefaultLegendGroup()
{
	for ( int role = 0; role < eCharacterClassRole._COUNT; role++ )
	{
		string title = ""
		try
		{
			title = Localize( CharacterClass_GetRoleTitle( role ) )
		}
		catch ( eTitle )
		{
		}
		if ( title != "" )
			return role
	}
	return 0
}

void function LabPlayer_BuildLegendGroupList()
{
	var button = LabPlayer_Row( "SwitchLegendGroup" )
	Hud_DialogList_ClearList( button )
	int first = -1
	for ( int role = 0; role < eCharacterClassRole._COUNT; role++ )
	{
		string title = ""
		try
		{
			title = Localize( CharacterClass_GetRoleTitle( role ) )
		}
		catch ( eTitle )
		{
		}
		if ( title == "" )
			continue
		if ( first < 0 )
			first = role
		Hud_DialogList_AddListItem( button, title, string( role ) )
	}
	if ( first >= 0 )
		Hud_SetDialogListSelectionValue( button, string( first ) )
}

void function LabPlayer_BuildLegendListForGroup( int role )
{
	var button = LabPlayer_Row( "SwitchLegend" )
	Hud_DialogList_ClearList( button )
	file.legendRefs.clear()

	array<ItemFlavor> characters = clone GetAllCharacters()
	foreach ( ItemFlavor character in characters )
	{
		string ref = ItemFlavor_GetCharacterRef( character )
		if ( HIDDEN_CHARACTER_REFS.len() > 0 && HIDDEN_CHARACTER_REFS.contains( ref ) )
			continue
		int charRole = -1
		try
		{
			charRole = CharacterClass_GetRole( character )
		}
		catch ( eRole )
		{
		}
		if ( charRole != role )
			continue

		string label = Localize( ItemFlavor_GetLongName( character ) )
		if ( label == "" )
			label = ref

		Hud_DialogList_AddListItem( button, label, string( file.legendRefs.len() ) )
		file.legendRefs.append( ref )
	}

	if ( file.legendRefs.len() == 0 )
		Hud_DialogList_AddListItem( button, LAB_LEGEND_NONE, "0" )
}

void function LabPlayer_OnLegendGroup( var button )
{
	int role = LabPlayer_DefaultLegendGroup()
	try
	{
		role = int( Hud_GetDialogListSelectionValue( button ) )
	}
	catch ( eInt )
	{
	}
	file.applyingValues = true
	LabPlayer_BuildLegendListForGroup( role )
	file.applyingValues = false
}

void function LabPlayer_BuildBodyModelList()
{
	var button = LabPlayer_Row( "SwitchBodyModel" )
	Hud_DialogList_ClearList( button )
	file.bodyModelIds.clear()

	Hud_DialogList_AddListItem( button, Localize( "#LAB_PLAYER_MODEL_DEFAULT" ), "0" )
	file.bodyModelIds.append( "clear" )

	Hud_DialogList_AddListItem( button, Localize( "#LAB_PLAYER_MODEL_AMOGUS" ), "1" )
	file.bodyModelIds.append( "amogus" )

	Hud_DialogList_AddListItem( button, Localize( "#LAB_PLAYER_MODEL_PETE" ), "2" )
	file.bodyModelIds.append( "pete" )
}

void function LabPlayer_ApplyGates()
{
	if ( file.rows.len() == 0 )
		return

	foreach ( string name, var button in file.rows )
		Lab_SetRowState( button )
}

bool function LabPlayer_Ignore()
{
	return file.applyingValues || !Lab_GetCheats()
}

void function LabPlayer_OnGodMode( var button )
{
	if ( LabPlayer_Ignore() )
		return
	ClientCommand( "demigod" )
}

void function LabPlayer_OnNoClip( var button )
{
	if ( LabPlayer_Ignore() )
		return
	ClientCommand( "noclip" )
	CloseAllMenus()
}

void function LabPlayer_OnInfiniteAmmo( var button )
{
	if ( LabPlayer_Ignore() )
		return
	ClientCommand( "infinite_ammo" )
}

void function LabPlayer_SetInfiniteAbilities( bool enable )
{
	file.infiniteAbilities = enable
	if ( file.rows.len() == 0 )
		return

	file.applyingValues = true
	Hud_SetDialogListSelectionValue( LabPlayer_Row( "SwitchInfiniteAbilities" ), enable ? "1" : "0" )
	file.applyingValues = false
}

void function LabPlayer_OnInfiniteAbilities( var button )
{
	if ( LabPlayer_Ignore() )
		return

	string val = Hud_GetDialogListSelectionValue( button )
	file.infiniteAbilities = ( val == "1" )
	ClientCommand( "infinite_abilities " + val )
}

void function LabPlayer_OnAutoRespawn( var button )
{
	if ( LabPlayer_Ignore() )
		return
	ClientCommand( "auto_respawn" )
}

void function LabPlayer_OnThirdPerson( var button )
{
	if ( LabPlayer_Ignore() )
		return
	ClientCommand( "ToggleThirdPerson" )
}

void function LabPlayer_OnHud( var button )
{
	if ( LabPlayer_Ignore() )
		return
	DevHud_Toggle()
}

void function LabPlayer_OnSkyboxView( var button )
{
	if ( LabPlayer_Ignore() )
		return
	ClientCommand( "lab_skybox" )
	CloseAllMenus()
}

void function LabPlayer_OnLegend( var button )
{
	if ( LabPlayer_Ignore() )
		return

	int index = int( Hud_GetDialogListSelectionValue( button ) )
	if ( index < 0 || index >= file.legendRefs.len() )
		return

	array<ItemFlavor> characters = clone GetAllCharacters()
	foreach ( ItemFlavor character in characters )
	{
		if ( ItemFlavor_GetCharacterRef( character ) != file.legendRefs[ index ] )
			continue

		DEV_RequestSetItemFlavorLoadoutSlot( LocalClientEHI(), Loadout_Character(), character )
		return
	}
}

void function LabPlayer_OnBodyModel( var button )
{
	if ( LabPlayer_Ignore() )
		return

	int index = int( Hud_GetDialogListSelectionValue( button ) )
	if ( index < 0 || index >= file.bodyModelIds.len() )
		return

	ClientCommand( "cafeplayermodel " + file.bodyModelIds[ index ] )
}

void function LabPlayer_OnRecharge( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "recharge" )
}

void function LabPlayer_OnRespawnMe( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "respawn" )
	CloseAllMenus()
}

void function LabPlayer_OnKillSelf( var button )
{
	if ( !Lab_GetCheats() )
		return
	ClientCommand( "kill_self" )
	CloseAllMenus()
}

void function LabPlayer_OnAlterLoadout( var button )
{
	EmitUISound( "UI_Menu_Deny" )
	return
}

void function LabPlayer_OpenAlterLoadout_Thread()
{
	return
}
