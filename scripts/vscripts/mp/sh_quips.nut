global function ShQuips_LevelInit
global function ShQuips_Init
global function RegisterEquippableQuipsForCharacter

global function CharacterQuip_IsTheEmpty

global function CharacterQuip_GetAnim3p
global function CharacterQuip_GetAnimLoop3p
global function CharacterQuip_SelectWeightedAnimFlourish3p
global function CharacterQuip_GetCameraHeightOffset

global function CharacterQuip_UseHoloProjector
global function CharacterQuip_GetModelAsset
global function CharacterQuip_GetUseEffectColor2
global function CharacterQuip_GetEffectColor1
global function CharacterQuip_GetEffectColor2

#if CLIENT
global function PerformQuip
global function CharacterQuip_ShortenTextForCommsMenu
#endif

#if SERVER
global function BroadcastQuip
global function ClientCallback_BroadcastQuip
global function ClientCallback_BroadcastFavoredQuip
#endif

#if CLIENT || UI
global function CreateNestedRuiForQuip
global function EmoteIcon_PopulateNestedRui
global function ItemFlavor_GetFavoredQuipArrayForCharacter
#endif

global function ItemFlavor_GetQuipArrayForCharacter
global function GetAllCharacterEmotesForCharacter
global function GetAllHolospraysForCharacter
global function HoloSpray_FilterRankedSeasonCopies
global function GetRandomEmoteWheelItems
global function CharacterQuip_GetCharacterFlavor
global function CharacterQuip_GetAliasSubName
global function Loadout_CharacterQuip
global function Loadout_FavoredQuip
global function Loadout_FavoredQuipArrayForCharacter
global function Loadout_IsCharacterQuipLoadoutEntry
global function ItemFlavor_CanEquipToWheel

#if SERVER
const float PLANE_QUIP_DEBOUNCE = 5.0
const float QUIP_BROADCAST_DEBOUNCE = 1.0
#endif

global const int MAX_QUIPS_EQUIPPED = 8
global const int MAX_FAVORED_QUIPS = 4

global const string CAUSTIC_SPECIAL_CASE_EMOTE_ASSET_PATH = "settings/itemflav/character_emote/caustic/epic_rakestep.rpak"

struct FileStruct_LifetimeLevel
{
	table<ItemFlavor, array<LoadoutEntry> >     loadoutCharacterQuipsSlotListMap
	table<ItemFlavor, array<LoadoutEntry> >	    loadoutCharacterFavoredQuipMap

	array<ItemFlavor> universalQuips
}
FileStruct_LifetimeLevel& fileLevel

// Bakery Data Keys
const string ANIM_3P_KEY = "anim3p" // also used for the override anim
const string OVERRIDE_ANIMS_ARRAY_KEY = "overrideAnims"
const string OVERRIDE_CHARACTER_KEY = "character"

void function ShQuips_LevelInit()
{
	FileStruct_LifetimeLevel newFileLevel
	fileLevel = newFileLevel

	#if SERVER
		Remote_RegisterServerFunction( "ClientCallback_BroadcastQuip", "int", INT_MIN, INT_MAX )
		Remote_RegisterServerFunction( "ClientCallback_BroadcastFavoredQuip", "int", 0, MAX_FAVORED_QUIPS )
	#endif
}

void function ShQuips_Init()
{
	ShQuips_LevelInit()
}

void function RegisterEquippableQuipsForCharacter( ItemFlavor characterClass, array<ItemFlavor> quipList, array<ItemFlavor> characterEmotesList )
{
	foreach( int index, ItemFlavor quip in quipList )
	{
		#if CLIENT || SERVER
		if ( CharacterQuip_UseHoloProjector( quip ) )
		{
			PrecacheModel( CharacterQuip_GetModelAsset( quip ) )
		}
		#endif
	}

	fileLevel.loadoutCharacterQuipsSlotListMap[characterClass] <- []

	for ( int quipIndex = 0; quipIndex < MAX_QUIPS_EQUIPPED; quipIndex++ )
	{
		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "quips_" + quipIndex + "_for_" + ItemFlavor_GetGUIDString( characterClass ), eLoadoutEntryClass.CHARACTER )
		entry.category     = eLoadoutCategory.CHARACTER_QUIPS
		entry.DEV_name     = ItemFlavor_GetCharacterRef( characterClass ) + " Quip " + quipIndex
		#if DEVELOPER
			entry.pdefSectionKey = "character " + ItemFlavor_GetGUIDString( characterClass )
		#endif
		entry.validItemFlavorList = quipList
		entry.defaultItemFlavor   = (quipIndex == 0 && characterEmotesList.len() > 0) ? characterEmotesList[0] : entry.validItemFlavorList[0]
		entry.isSlotLocked        = bool function( EHI playerEHI ) {
			return !IsLobby()
		}

		#if SERVER
			entry.specialValidationFunc = ItemFlavor function( EHI playerEHI, ItemFlavor currFlav, bool ignoreGRX ) : ( entry, quipIndex )
			{
				array<ItemFlavor> allEmotes
				array<ItemFlavor> allQuips = GetValidItemFlavorsForLoadoutSlot( playerEHI, entry )

				for ( int i = 0; i < allQuips.len(); i++ )
				{
					if ( ItemFlavor_GetType( allQuips[i] ) == eItemType.character_emote )
					{
						if ( IsItemFlavorUnlockedForLoadoutSlot( playerEHI, entry, allQuips[i] ) )
							allEmotes.append( allQuips[i] )
					}
				}

				allEmotes.sort( ItemFlavor_SortByTier )

				if ( allEmotes.len() > quipIndex )
					return allEmotes[quipIndex]

				return currFlav
			}
		#endif

		entry.associatedCharacterOrNull = characterClass
		entry.networkTo                 = eLoadoutNetworking.PLAYER_EXCLUSIVE

		fileLevel.loadoutCharacterQuipsSlotListMap[characterClass].append( entry )
	}

	fileLevel.loadoutCharacterFavoredQuipMap[characterClass] <- []


	for ( int favQuipIndex = 0; favQuipIndex < MAX_FAVORED_QUIPS; favQuipIndex++ )
	{
		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "favoredQuip_" + favQuipIndex + "_for_" + ItemFlavor_GetGUIDString( characterClass ), eLoadoutEntryClass.CHARACTER )
		entry.category     = eLoadoutCategory.CHARACTER_FAVORED_QUIPS
		entry.DEV_name     = ItemFlavor_GetCharacterRef( characterClass ) + " Favored Quip " + favQuipIndex
		#if DEVELOPER
			entry.pdefSectionKey = "character " + ItemFlavor_GetGUIDString( characterClass )
		#endif
		entry.validItemFlavorList = quipList
		entry.defaultItemFlavor   = entry.validItemFlavorList[0]
		entry.isSlotLocked        = bool function( EHI playerEHI ) {
			return !IsLobby()
		}

		entry.associatedCharacterOrNull = characterClass
		entry.networkTo                 = eLoadoutNetworking.PLAYER_EXCLUSIVE
		fileLevel.loadoutCharacterFavoredQuipMap[characterClass].append( entry )
	}
}


#if CLIENT
void function PerformQuip( entity player, int index )
{
	if ( !IsAlive( player ) )
		return

	// PlaySoundForCommsAction has different signature, quip sounds disabled for now
	// TODO: Implement direct sound playback for quips
}
#endif



#if SERVER || CLIENT || UI
LoadoutEntry function Loadout_CharacterQuip( ItemFlavor characterClass, int badgeIndex )
{
	return fileLevel.loadoutCharacterQuipsSlotListMap[characterClass][badgeIndex]
}

LoadoutEntry function Loadout_FavoredQuip( ItemFlavor characterClass, int badgeIndex )
{
	return fileLevel.loadoutCharacterFavoredQuipMap[characterClass][badgeIndex]
}

array<LoadoutEntry> function Loadout_QuipArrayForCharacter( ItemFlavor characterClass )
{
	return fileLevel.loadoutCharacterQuipsSlotListMap[characterClass]
}

array<LoadoutEntry> function Loadout_FavoredQuipArrayForCharacter( ItemFlavor characterClass )
{
	return fileLevel.loadoutCharacterFavoredQuipMap[characterClass]
}

bool function Loadout_IsCharacterQuipLoadoutEntry( LoadoutEntry entry )
{
	return entry.category == eLoadoutCategory.CHARACTER_QUIPS
}

string function CharacterQuip_GetAliasSubName( ItemFlavor flavor )
{
	AssertEmoteIsValid( flavor )

	try
	{
		return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "quickchatAliasSubName" )
	}
	catch ( e )
	{
		return ""
	}
}

bool function CharacterQuip_IsTheEmpty( ItemFlavor flavor )
{
	AssertEmoteIsValid( flavor )

	if ( ItemFlavor_GetType( flavor ) == eItemType.character_emote )
		return false // Character Emotes have a default, rather than an "empty"

	try
	{
		return ( GetGlobalSettingsBool( ItemFlavor_GetAsset( flavor ), "isTheEmpty" ) )
	}
	catch ( e )
	{
		Warning( "Warning: Asset \"" + ItemFlavor_GetAsset( flavor ) + "\" does not have setting var  \"" + "isTheEmpty" + "\"" )
		return false  // Return empty asset if isTheEmpty setting doesn't exist
	}
}

array<ItemFlavor> function GetAllQuipsOfTypeForCharacter( ItemFlavor characterClass, int itemType )
{
	array<ItemFlavor> items
	if ( !( characterClass in fileLevel.loadoutCharacterQuipsSlotListMap ) )
		return items
	if ( fileLevel.loadoutCharacterQuipsSlotListMap[characterClass].len() == 0 )
		return items

	foreach ( ItemFlavor flav in fileLevel.loadoutCharacterQuipsSlotListMap[characterClass][0].validItemFlavorList )
	{
		if ( ItemFlavor_GetType( flav ) != itemType )
			continue
		if ( CharacterQuip_IsTheEmpty( flav ) )
			continue
		items.append( flav )
	}

	return items
}

array<ItemFlavor> function GetAllCharacterEmotesForCharacter( ItemFlavor characterClass )
{
	array<ItemFlavor> emotes = GetAllQuipsOfTypeForCharacter( characterClass, eItemType.character_emote )
	emotes.sort( ItemFlavor_SortByTier )
	return emotes
}

array<ItemFlavor> function GetAllHolospraysForCharacter( ItemFlavor characterClass )
{
	return HoloSpray_FilterRankedSeasonCopies( GetAllQuipsOfTypeForCharacter( characterClass, eItemType.emote_icon ) )
}

array<ItemFlavor> function HoloSpray_FilterRankedSeasonCopies( array<ItemFlavor> holos )
{
	// Ranked split rewards reuse one pose with a badge.
	array<ItemFlavor> playable
	foreach ( ItemFlavor flav in holos )
	{
		string path = string( ItemFlavor_GetAsset( flav ) ).tolower()
		if ( path.find( "ranked" ) != -1 )
			continue
		playable.append( flav )
	}
	return playable
}

array<ItemFlavor> function GetRandomEmoteWheelItems( ItemFlavor characterClass )
{
	const int WHEEL_RANDOM_EMOTES = 4
	const int WHEEL_RANDOM_HOLOSPRAYS = 4

	if ( FS_Is1v1Playlist() )
		return []

	array<ItemFlavor> emotes = GetAllCharacterEmotesForCharacter( characterClass )
	array<ItemFlavor> holos = GetAllHolospraysForCharacter( characterClass )
	emotes.randomize()
	holos.randomize()

	array<ItemFlavor> wheel
	int emoteCount = WHEEL_RANDOM_EMOTES
	if ( emoteCount > emotes.len() )
		emoteCount = emotes.len()
	for ( int i = 0; i < emoteCount; i++ )
		wheel.append( emotes[i] )

	int holoCount = WHEEL_RANDOM_HOLOSPRAYS
	if ( holoCount > holos.len() )
		holoCount = holos.len()
	for ( int i = 0; i < holoCount; i++ )
		wheel.append( holos[i] )

	int extra = emoteCount
	while ( wheel.len() < MAX_QUIPS_EQUIPPED && extra < emotes.len() )
	{
		wheel.append( emotes[extra] )
		extra++
	}
	extra = holoCount
	while ( wheel.len() < MAX_QUIPS_EQUIPPED && extra < holos.len() )
	{
		wheel.append( holos[extra] )
		extra++
	}

	return wheel
}

// S21: removed #if CLIENT || UI guard - function now uses ToEHI(player) instead of LocalClientEHI
array<ItemFlavor> function ItemFlavor_GetQuipArrayForCharacter( entity player, ItemFlavor characterClass, bool characterEmotesOnly = false )
{
	array<ItemFlavor> quips = GetAllCharacterEmotesForCharacter( characterClass )

	if ( characterEmotesOnly )
		return quips

	EHI playerEHI = ToEHI( player )

	foreach ( LoadoutEntry entry in Loadout_QuipArrayForCharacter( characterClass ) )
	{
		ItemFlavor flav = LoadoutSlot_GetItemFlavor( playerEHI, entry )

		if ( ItemFlavor_GetType( flav ) == eItemType.character_emote )
			continue

		if ( !CharacterQuip_IsTheEmpty( flav ) && !quips.contains( flav ) )
			quips.append( flav )
	}

	return quips
}

#if CLIENT || UI
array<ItemFlavor> function ItemFlavor_GetFavoredQuipArrayForCharacter( ItemFlavor characterClass, bool characterEmotesOnly = false )
{
	array<ItemFlavor> favoredQuips = []

	EHI playerEHI = LocalClientEHI()

	foreach ( LoadoutEntry entry in Loadout_FavoredQuipArrayForCharacter( characterClass ) )
	{
		ItemFlavor flav = LoadoutSlot_GetItemFlavor( playerEHI, entry )

		if ( characterEmotesOnly && ItemFlavor_GetType( flav ) != eItemType.character_emote )
			continue

		if ( ! CharacterQuip_IsTheEmpty( flav ) )
			favoredQuips.append( flav )
	}

	return favoredQuips
}
#endif

string function CharacterQuip_GetAnim3p( ItemFlavor quip, ItemFlavor character )
{
	AssertEmoteIsValid( quip )

	if ( ItemFlavor_GetType( quip ) != eItemType.character_emote )
		return ""

	string anim3p = ""
	try
	{
		anim3p = GetGlobalSettingsString( ItemFlavor_GetAsset( quip ), ANIM_3P_KEY )
	}
	catch ( e )
	{
		return ""
	}

	foreach ( var overridePair in IterateSettingsAssetArray( ItemFlavor_GetAsset( quip ), OVERRIDE_ANIMS_ARRAY_KEY ) )
	{
		asset overrideCharacter = GetSettingsBlockAsset( overridePair, OVERRIDE_CHARACTER_KEY )
		if ( IsValidItemFlavorSettingsAsset( overrideCharacter ) && character == GetItemFlavorByAsset( overrideCharacter ) )
		{
			anim3p = GetSettingsBlockString( overridePair, ANIM_3P_KEY )
			break
		}
	}

	return anim3p
}

string function CharacterQuip_GetAnimLoop3p( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_emote )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( flavor ), "anim3pLoop" )
}

var function CharacterQuip_SelectWeightedAnimFlourish3p( ItemFlavor flavor )
{
	Assert( ItemFlavor_GetType( flavor ) == eItemType.character_emote )

	var flourishSettingsArray = GetSettingsBlockArray( GetSettingsBlockForAsset( ItemFlavor_GetAsset( flavor ) ), "flourishSequences" )
	int flourishCount = GetSettingsArraySize( flourishSettingsArray )

	if ( flourishCount <= 0 )
		return null

	int weighttotal = 0

	foreach ( var flourishBlock in IterateSettingsArray( flourishSettingsArray ) )
	{
		int weight = GetSettingsBlockInt( flourishBlock, "weight" )
		Assert( weight > 0, "CharacterQuip: flourish sequence: " + GetSettingsBlockString( flourishBlock, "sequence" ) + " present with invalid weight: + " + weight )
		weighttotal += weight
	}

	if ( weighttotal <= 0 )
	{
		Warning( "CharacterQuip: weight total for flourish sequences was " + weighttotal + ". Check that weights are assigned on the sequences." )
		return null
	}

	int randomValue = RandomInt( weighttotal )

	foreach ( var flourishBlock in IterateSettingsArray( flourishSettingsArray ) )
	{
		int weight = GetSettingsBlockInt( flourishBlock, "weight" )
		if ( randomValue >= weight )
		{
			randomValue -= weight
		}
		else
		{
			return flourishBlock
		}
	}

	Warning( "CharacterQuip: Unable to select flourish - you should never see this" )
	return null
}

float function CharacterQuip_GetCameraHeightOffset( ItemFlavor flavor )
{
	Assert ( ItemFlavor_GetType( flavor ) == eItemType.character_emote )

	return GetGlobalSettingsFloat( ItemFlavor_GetAsset( flavor), "cameraHeightOffset" )
}

bool function CharacterQuip_UseHoloProjector( ItemFlavor flavor )
{
	AssertEmoteIsValid( flavor )

	try
	{
		return ( GetGlobalSettingsBool( ItemFlavor_GetAsset( flavor ), "useHoloProjector" ) )
	}
	catch ( e )
	{
		return false
	}
}

void function AssertEmoteIsValid( ItemFlavor flavor )
{
	array<int> allowedList = [
		eItemType.gladiator_card_kill_quip,
		eItemType.gladiator_card_intro_quip,
		eItemType.emote_icon,
		eItemType.character_emote,
	]

	Assert( allowedList.contains( ItemFlavor_GetType( flavor ) ) )
}
#endif


#if SERVER
void function ClientCallback_BroadcastQuip( entity player, int quipGUID )
{
	if ( !IsAlive( player ) )
		return
	if ( !IsValidItemFlavorGUID( quipGUID ) )
		return

	ItemFlavor quip = GetItemFlavorByGUID( quipGUID )
	int itemType = ItemFlavor_GetType( quip )
	if ( itemType != eItemType.character_emote && itemType != eItemType.emote_icon )
		return

	if ( player.p.lastQuipBroadcastTime > 0 && Time() - player.p.lastQuipBroadcastTime < QUIP_BROADCAST_DEBOUNCE )
		return
	player.p.lastQuipBroadcastTime = Time()

	thread BroadcastQuip( player, quip )
}

void function ClientCallback_BroadcastFavoredQuip( entity player, int quip )
{
	if ( !IsAlive( player ) )
		return

	if ( player.p.lastQuipBroadcastTime > 0 && Time() - player.p.lastQuipBroadcastTime < QUIP_BROADCAST_DEBOUNCE )
		return
	player.p.lastQuipBroadcastTime = Time()

	thread BroadcastFavoredQuipAtIndex( player, quip )
}

void function BroadcastQuipAtIndex( entity player, int index )
{
	if ( !IsAlive( player ) )
		return

	if ( index >= MAX_QUIPS_EQUIPPED )
		return

	EHI playerEHI = ToEHI( player )
	ItemFlavor character = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_Character() )
	array<ItemFlavor> allEmotes = GetAllCharacterEmotesForCharacter( character )
	if ( index < 0 || index >= allEmotes.len() )
		return

	BroadcastQuip( player, allEmotes[index] )
}

void function BroadcastFavoredQuipAtIndex( entity player, int index )
{
	if ( !IsAlive( player ) )
		return

	if ( index < 0 || index >= MAX_FAVORED_QUIPS )
		return

	EHI playerEHI = ToEHI( player )
	ItemFlavor character = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_Character() )
	ItemFlavor quip      = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_FavoredQuip( character, index ) )

	BroadcastQuip( player, quip )
}

void function BroadcastQuip( entity player, ItemFlavor quip )
{
	if ( !IsAlive( player ) )
		return

	EHI playerEHI = ToEHI( player )
	ItemFlavor character = LoadoutSlot_WaitForItemFlavor( playerEHI, Loadout_Character() )

	int quipGUID = ItemFlavor_GetGUID( quip )

	if ( quipGUID < 0 )
		return

	if ( AreEmotesEnabled() && CharacterQuip_GetAnim3p( quip, character ) != "" )
		RequestPlayerPerformEmote( player, quip )

	if ( GetGameState() >= eGameState.Resolution )
		return

	if ( !FS_Is1v1Playlist() && GetCurrentPlaylistVarBool( "holosprays_enabled", true ) && CharacterQuip_UseHoloProjector( quip ) )
	{
		AssignGUIDToHoloProjector( player, quipGUID )
	}

	bool speakerInPlane = player.GetPlayerNetBool( "playerInPlane" )
	if ( CharacterQuip_GetAliasSubName( quip ) != "" )
	{
		foreach ( p in GetPlayerArray_Alive() )
		{
			if ( !speakerInPlane || IsFriendlyTeam( p.GetTeam(), player.GetTeam() ) || p.p.nextAllowPlaneEmoteTime < Time() )
			{
				p.p.nextAllowPlaneEmoteTime = Time() + PLANE_QUIP_DEBOUNCE
				Remote_CallFunction_Replay( p, "PerformQuip", player, quipGUID )
			}
		}
	}

	// FR_Nessie_OnQuipUsed not available
}
#endif

bool function ItemFlavor_CanEquipToWheel( ItemFlavor item )
{
	switch ( ItemFlavor_GetType( item ) )
	{
		case eItemType.gladiator_card_kill_quip:
		case eItemType.gladiator_card_intro_quip:
		case eItemType.emote_icon:
		case eItemType.character_emote:
		case eItemType.skydive_emote:
			return true
	}

	return false
}

#if CLIENT || UI
string function CharacterQuip_ShortenTextForCommsMenu( ItemFlavor flav )
{
	string txt = ""

	int itemType = ItemFlavor_GetType( flav )
	if ( itemType == eItemType.gladiator_card_kill_quip || itemType == eItemType.gladiator_card_intro_quip )
	{
		txt = Localize( ItemFlavor_GetLongName( flav ) )

		int WORD_MAX_LEN = 11
		int TEXT_MAX_LEN = 26
		int TEXT_MAX_LEN_W_DOTS = TEXT_MAX_LEN - 2
#if CLIENT
		txt = CondenseText( txt, WORD_MAX_LEN, TEXT_MAX_LEN )
#endif
	}
	return txt
}


var function CreateNestedRuiForQuip( var baseRui, string argName, ItemFlavor quip )
{
	int itemType = ItemFlavor_GetType( quip )

	switch ( itemType )
	{
		case eItemType.emote_icon:
			var rui = RuiCreateNested( baseRui, argName, $"ui/comms_menu_icon_projector.rpak" )
			EmoteIcon_PopulateNestedRui( rui, quip, null )
			return rui
	}

	var nestedRui = RuiCreateNested( baseRui, argName, $"ui/comms_menu_icon_default.rpak" )
	RuiSetImage( nestedRui, "icon", ItemFlavor_GetIcon( quip ) )
	RuiSetBool( nestedRui, "centerTextUseTierColor", itemType == eItemType.gladiator_card_intro_quip || itemType == eItemType.gladiator_card_kill_quip )
	RuiSetInt( nestedRui, "tier", ItemFlavor_GetQuality( quip, 0 ) + 1 )
	RuiSetString( nestedRui, "centerText", CharacterQuip_ShortenTextForCommsMenu( quip ) )

	return nestedRui
}


void function EmoteIcon_PopulateNestedRui( var rui, ItemFlavor item, int ornull overrideDataInt )
{
	asset ruiAsset = $"ui/basic_image.rpak"
	var nested = RuiCreateNested( rui, "ruiHandle", ruiAsset )
	asset icon = ItemFlavor_GetIcon( item )

	RuiSetInt( rui, "tier", ItemFlavor_GetQuality( item, 0 ) + 1 )
	RuiSetImage( nested, "basicImage", icon )
}
#endif


asset function CharacterQuip_GetModelAsset( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.emote_icon )
	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( item ), "holoProjectorSprayModel" )
}

bool function CharacterQuip_GetUseEffectColor2( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.emote_icon )
	return GetGlobalSettingsBool( ItemFlavor_GetAsset( item ), "holoProjectorUseEffectColor2" )
}

vector function CharacterQuip_GetEffectColor1( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.emote_icon )
	return GetGlobalSettingsVector( ItemFlavor_GetAsset( item ), "holoProjectorEffectColor1" )
}

vector function CharacterQuip_GetEffectColor2( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.emote_icon )
	return GetGlobalSettingsVector( ItemFlavor_GetAsset( item ), "holoProjectorEffectColor2" )
}


ItemFlavor ornull function CharacterQuip_GetCharacterFlavor( ItemFlavor item )
{
	if ( fileLevel.universalQuips.contains( item ) )
		return null

	asset parentAsset = $""
	try
	{
		parentAsset = GetGlobalSettingsAsset( ItemFlavor_GetAsset( item ), "parentItemFlavor" )
	}
	catch ( e )
	{
		return null
	}

	if ( parentAsset == $"" || !IsValidItemFlavorSettingsAsset( parentAsset ) )
		return null

	return GetItemFlavorByAsset( parentAsset )
}
