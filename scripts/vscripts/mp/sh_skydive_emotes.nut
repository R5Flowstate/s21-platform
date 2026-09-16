global function ShSkydiveEmotes_LevelInit

global function RegisterSkydiveEmotesForCharacter
global function Loadout_SkydiveEmote
global function GetValidPlayerSkydiveEmotes
global function GetPlayerSkydiveEmote

#if SERVER
global function SkydiveEmote_FreeFall_DisableSkydiveEmotes
#endif

global function SkydiveEmote_IsTheEmpty
global function SkydiveEmote_GetCharacterFlavor
global function SkydiveEmote_GetAnimSeq
global function SkydiveEmote_GetVideo
global function SkydiveEmote_GetBcEvent
global function SkydiveEmote_GetSortOrdinal

#if CLIENT || UI
global function CreateNestedRuiForSkydiveEmote
#endif

global const int NUM_SKYDIVE_EMOTE_SLOTS = 8

struct FileStruct_LifetimeLevel
{
	table<ItemFlavor, array<LoadoutEntry> >     loadoutCharacterSkydiveEmoteSlotMap
	table<ItemFlavor, int>                      skydiveEmoteSortOrdinalMap
}
FileStruct_LifetimeLevel& fileLevel


void function ShSkydiveEmotes_LevelInit()
{
	FileStruct_LifetimeLevel newFileLevel
	fileLevel = newFileLevel

	#if SERVER
	if ( !AreEmotesEnabled() )
	{
		Survival_AddCallback_PlayerFreefallBegin( SkydiveEmote_FreeFall_DisableSkydiveEmotes )
	}

	if ( GetCurrentPlaylistVarBool( "disable_skydive_emotes_postdrop", false) )
	{
		Survival_AddCallback_PlayerFreefallEnd( SkydiveEmote_FreeFall_DisableSkydiveEmotes )
	}
	#endif
}


void function RegisterSkydiveEmotesForCharacter( ItemFlavor characterClass )
{
	array<ItemFlavor> skydiveEmotesList = RegisterReferencedItemFlavorsFromArray( characterClass, "skydiveEmotes", "flavor" )
	MakeItemFlavorSet( skydiveEmotesList, fileLevel.skydiveEmoteSortOrdinalMap )

	fileLevel.loadoutCharacterSkydiveEmoteSlotMap[characterClass] <- []

	for ( int i = 0; i < NUM_SKYDIVE_EMOTE_SLOTS; i++ )
	{
		LoadoutEntry entry = RegisterLoadoutSlot( eLoadoutEntryType.ITEM_FLAVOR, "character_skydive_emote_" + i + "_for_" + ItemFlavor_GetGUIDString( characterClass ), eLoadoutEntryClass.CHARACTER )
		entry.category     = eLoadoutCategory.CHARACTER_SKYDIVE_EMOTES
		entry.DEV_name     = ItemFlavor_GetCharacterRef( characterClass ) + " Skydive Emote " + i
		#if DEVELOPER
			entry.pdefSectionKey = "character " + ItemFlavor_GetGUIDString( characterClass )
		#endif
		entry.defaultItemFlavor   = skydiveEmotesList[0]
		entry.validItemFlavorList = skydiveEmotesList
		entry.isSlotLocked        = bool function( EHI playerEHI ) {
			return !IsLobby()
		}
		#if SERVER
		entry.specialValidationFunc = ItemFlavor function( EHI playerEHI, ItemFlavor currFlav, bool ignoreGRX ) : ( entry, skydiveEmotesList, i ) {
			array<ItemFlavor> unlockedNonEmptyFlavs
			foreach ( ItemFlavor emoteFlav in skydiveEmotesList )
			{
				if ( !SkydiveEmote_IsTheEmpty( emoteFlav ) && IsItemFlavorUnlockedForLoadoutSlot( playerEHI, entry, emoteFlav ) )
					unlockedNonEmptyFlavs.append( emoteFlav )
			}

			if ( unlockedNonEmptyFlavs.len() > i )
				return unlockedNonEmptyFlavs[i]

			return skydiveEmotesList[0]
		}
		#endif
		entry.associatedCharacterOrNull = characterClass
		entry.networkTo                 = eLoadoutNetworking.PLAYER_EXCLUSIVE
		fileLevel.loadoutCharacterSkydiveEmoteSlotMap[characterClass].append( entry )
	}
}


LoadoutEntry function Loadout_SkydiveEmote( ItemFlavor characterClass, int index )
{
	return fileLevel.loadoutCharacterSkydiveEmoteSlotMap[characterClass][ index ]
}


array<ItemFlavor> function GetAllSkydiveEmotesForPlayer( entity player )
{
	array<ItemFlavor> emotes
	EHI playerEHI = ToEHI( player )
	LoadoutEntry characterSlot = Loadout_Character()

	if ( !LoadoutSlot_IsReady( playerEHI, characterSlot ) )
		return emotes

	ItemFlavor character = LoadoutSlot_GetItemFlavor( playerEHI, characterSlot )
	if ( !( character in fileLevel.loadoutCharacterSkydiveEmoteSlotMap ) )
		return emotes

	array<LoadoutEntry> slots = fileLevel.loadoutCharacterSkydiveEmoteSlotMap[character]
	if ( slots.len() == 0 )
		return emotes

	foreach ( ItemFlavor flav in slots[0].validItemFlavorList )
	{
		if ( !SkydiveEmote_IsTheEmpty( flav ) )
			emotes.append( flav )
	}

	return emotes
}


table<int, ItemFlavor> function GetValidPlayerSkydiveEmotes( entity player )
{
	table<int, ItemFlavor> emotes
	EHI playerEHI = ToEHI( player )
	LoadoutEntry characterSlot = Loadout_Character()

	if ( !LoadoutSlot_IsReady( playerEHI, characterSlot ) )
		return emotes

	ItemFlavor character = LoadoutSlot_GetItemFlavor( playerEHI, characterSlot )
	if ( !( character in fileLevel.loadoutCharacterSkydiveEmoteSlotMap ) )
		return emotes

	array<LoadoutEntry> slots = fileLevel.loadoutCharacterSkydiveEmoteSlotMap[character]
	int count = slots.len()
	if ( count > NUM_SKYDIVE_EMOTE_SLOTS )
		count = NUM_SKYDIVE_EMOTE_SLOTS

	for ( int i = 0; i < count; i++ )
	{
		if ( !LoadoutSlot_IsReady( playerEHI, slots[i] ) )
			continue

		ItemFlavor flav = LoadoutSlot_GetItemFlavor( playerEHI, slots[i] )
		if ( SkydiveEmote_IsTheEmpty( flav ) )
			continue

		if ( !IsItemFlavorUnlockedForLoadoutSlot( playerEHI, slots[i], flav ) )
			continue

		emotes[i] <- flav
	}

	return emotes
}


ItemFlavor function GetPlayerSkydiveEmote( entity player, int index )
{
	ItemFlavor emptyEmote = GetItemFlavorByAsset( $"settings/itemflav/skydive_emote/_empty.rpak" )

	EHI playerEHI = ToEHI( player )
	LoadoutEntry characterSlot = Loadout_Character()

	if ( !LoadoutSlot_IsReady( playerEHI, characterSlot ) )
		return emptyEmote

	ItemFlavor character = LoadoutSlot_GetItemFlavor( playerEHI, characterSlot )
	if ( !( character in fileLevel.loadoutCharacterSkydiveEmoteSlotMap ) )
		return emptyEmote

	array<LoadoutEntry> slots = fileLevel.loadoutCharacterSkydiveEmoteSlotMap[character]
	if ( index < 0 || index >= slots.len() )
		return emptyEmote

	if ( !LoadoutSlot_IsReady( playerEHI, slots[index] ) )
		return emptyEmote

	ItemFlavor flav = LoadoutSlot_GetItemFlavor( playerEHI, slots[index] )
	if ( SkydiveEmote_IsTheEmpty( flav ) )
		return emptyEmote

	if ( !IsItemFlavorUnlockedForLoadoutSlot( playerEHI, slots[index], flav ) )
		return emptyEmote

	return flav
}


bool function SkydiveEmote_IsTheEmpty( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.skydive_emote )

	return GetGlobalSettingsBool( ItemFlavor_GetAsset( item ), "isTheEmpty" )
}


ItemFlavor function SkydiveEmote_GetCharacterFlavor( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.skydive_emote )
	Assert( GetGlobalSettingsAsset( ItemFlavor_GetAsset( item ), "parentItemFlavor" ) != "" )

	return GetItemFlavorByAsset( GetGlobalSettingsAsset( ItemFlavor_GetAsset( item ), "parentItemFlavor" ) )
}


asset function SkydiveEmote_GetAnimSeq( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.skydive_emote )

	return GetGlobalSettingsAsset( ItemFlavor_GetAsset( item ), "animSequence" )
}


asset function SkydiveEmote_GetVideo( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.skydive_emote )

	return GetGlobalSettingsStringAsAsset( ItemFlavor_GetAsset( item ), "video" )
}


string function SkydiveEmote_GetBcEvent( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.skydive_emote )

	return GetGlobalSettingsString( ItemFlavor_GetAsset( item ), "bcEvent" )
}


int function SkydiveEmote_GetSortOrdinal( ItemFlavor item )
{
	Assert( ItemFlavor_GetType( item ) == eItemType.skydive_emote )

	return fileLevel.skydiveEmoteSortOrdinalMap[item]
}

#if SERVER
void function SkydiveEmote_FreeFall_DisableSkydiveEmotes( entity player )
{
	if( !player.p.skydiveEmotesDisabled )
	{
		player.p.skydiveEmotesDisabled = true
		player.SetPlayerNetBool( "freefallEmoteAvailable", false )
	}
}
#endif


#if CLIENT || UI
var function CreateNestedRuiForSkydiveEmote( var baseRui, string argName, ItemFlavor item )
{
	var nestedRui = RuiCreateNested( baseRui, argName, $"ui/comms_menu_icon_default.rpak" )

	RuiSetImage( nestedRui, "icon", ItemFlavor_GetIcon( item ) )
	RuiSetBool( nestedRui, "showBackground", false )

	return nestedRui
}
#endif // CLIENT || UI
