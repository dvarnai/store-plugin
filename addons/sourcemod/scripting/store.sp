#pragma semicolon 1

//////////////////////////////
//		DEFINITIONS			//
//////////////////////////////

#define PLUGIN_NAME "Store - The Resurrection"
#define PLUGIN_AUTHOR "Zephyrus"
#define PLUGIN_DESCRIPTION "A completely new Store system."
#define PLUGIN_VERSION "1.1"
#define PLUGIN_URL ""

#define SERVER_LOCK_IP ""

//////////////////////////////
//			INCLUDES		//
//////////////////////////////

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <store>
#include <zephstocks>
#include <donate>
#include <adminmenu>
#if !defined STANDALONE_BUILD
#include <sdkhooks>
#include <cstrike>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <gifts>
#include <scp>
#include <thirdperson>
#include <saxtonhale>
#endif

//////////////////////////////
//			ENUMS			//
//////////////////////////////

enum Client
{
	iId,
	iUserId,
	String:szAuthId[32],
	String:szName[64],
	String:szNameEscaped[128],
	iCredits,
	iOriginalCredits,
	iDateOfJoin,
	iDateOfLastJoin,
	iItems,
	aEquipment[STORE_MAX_HANDLERS*STORE_MAX_SLOTS],
	aEquipmentSynced[STORE_MAX_HANDLERS*STORE_MAX_SLOTS],
	Handle:hCreditTimer,
	bool:bLoaded
}

enum Menu_Handler
{
	String:szIdentifier[64],
	Handle:hPlugin,
	Function:fnMenu,
	Function:fnHandler
}

//////////////////////////////////
//		GLOBAL VARIABLES		//
//////////////////////////////////

new GAME_CSS = false;
new GAME_CSGO = false;
new GAME_DOD = false;
new GAME_TF2 = false;
new GAME_L4D = false;
new GAME_L4D2 = false;

new String:g_szGameDir[64];

new Handle:g_hDatabase = INVALID_HANDLE;
new Handle:g_hAdminMenu = INVALID_HANDLE;
new Handle:g_hLogFile = INVALID_HANDLE;
new Handle:g_hCustomCredits = INVALID_HANDLE;

new g_cvarDatabaseEntry = -1;
new g_cvarDatabaseRetries = -1;
new g_cvarDatabaseTimeout = -1;
new g_cvarItemSource = -1;
new g_cvarItemsTable = -1;
new g_cvarStartCredits = -1;
new g_cvarCreditTimer = -1;
new g_cvarCreditAmountActive = -1;
new g_cvarCreditAmountInactive = -1;
new g_cvarCreditAmountKill = -1;
new g_cvarRequiredFlag = -1;
new g_cvarVIPFlag = -1;
new g_cvarSellEnabled = -1;
new g_cvarGiftEnabled = -1;
new g_cvarCreditGiftEnabled = -1;
new g_cvarSellRatio = -1;
new g_cvarConfirmation = -1;
new g_cvarAdminFlag = -1;
new g_cvarSaveOnDeath = -1;
new g_cvarCreditMessages = -1;
new g_cvarShowVIP = -1;
new g_cvarLogging = -1;
new g_cvarSilent = -1;

new g_eItems[STORE_MAX_ITEMS][Store_Item];
new g_eClients[MAXPLAYERS+1][Client];
new g_eClientItems[MAXPLAYERS+1][STORE_MAX_ITEMS][Client_Item];
new g_eTypeHandlers[STORE_MAX_HANDLERS][Type_Handler];
new g_eMenuHandlers[STORE_MAX_HANDLERS][Menu_Handler];
new g_ePlans[STORE_MAX_ITEMS][STORE_MAX_PLANS][Item_Plan];

new g_iItems = 0;
new g_iTypeHandlers = 0;
new g_iMenuHandlers = 0;
new g_iMenuBack[MAXPLAYERS+1];
new g_iLastSelection[MAXPLAYERS+1];
new g_iSelectedItem[MAXPLAYERS+1];
new g_iSelectedPlan[MAXPLAYERS+1];
new g_iMenuClient[MAXPLAYERS+1];
new g_iMenuNum[MAXPLAYERS+1];
new g_iSpam[MAXPLAYERS+1];
new g_iPackageHandler = -1;
new g_iDatabaseRetries = 0;

new bool:g_bInvMode[MAXPLAYERS+1];
new bool:g_bMySQL = false;

new String:g_szClientData[MAXPLAYERS+1][256];

new TopMenuObject:g_eStoreAdmin;

new PublicChatTrigger = 0;
new SilentChatTrigger = 0;

//////////////////////////////
//			MODULES			//
//////////////////////////////

#if !defined STANDALONE_BUILD
#include "store/hats.sp"
#include "store/tracers.sp"
#include "store/playerskins.sp"
#include "store/trails.sp"
#include "store/grenskins.sp"
#include "store/grentrails.sp"
#include "store/weaponcolors.sp"
#include "store/tfsupport.sp"
#include "store/paintball.sp"
#include "store/betting.sp"
#include "store/watergun.sp"
#include "store/gifts.sp"
#include "store/scpsupport.sp"
#include "store/weapons.sp"
#include "store/help.sp"
#include "store/jetpack.sp"
#include "store/bunnyhop.sp"
#include "store/lasersight.sp"
#include "store/health.sp"
#include "store/speed.sp"
#include "store/gravity.sp"
#include "store/invisibility.sp"
#include "store/commands.sp"
#include "store/doors.sp"
#include "store/zrclass.sp"
#include "store/jihad.sp"
#include "store/godmode.sp"
#include "store/sounds.sp"
#include "store/attributes.sp"
#include "store/respawn.sp"
#include "store/pets.sp"
#include "store/sprays.sp"
#include "store/admin.sp"
#include "store/glow.sp"
#endif

//////////////////////////////////
//		PLUGIN DEFINITION		//
//////////////////////////////////

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

//////////////////////////////
//		PLUGIN FORWARDS		//
//////////////////////////////

public OnPluginStart()
{
	RegPluginLibrary("store_zephyrus");

	if(strcmp(SERVER_LOCK_IP, "") != 0)
	{
		new String:m_szIP[64];
		new m_unIP = GetConVarInt(FindConVar("hostip"));
		Format(STRING(m_szIP), "%d.%d.%d.%d:%d", (m_unIP >> 24) & 0x000000FF, (m_unIP >> 16) & 0x000000FF, (m_unIP >> 8) & 0x000000FF, m_unIP & 0x000000FF, GetConVarInt(FindConVar("hostport")));

		if(strcmp(SERVER_LOCK_IP, m_szIP)!=0)
			SetFailState("GTFO");
	}

	// Identify the game
	GetGameFolderName(STRING(g_szGameDir));
	
	if(strcmp(g_szGameDir, "cstrike")==0)
		GAME_CSS = true;
	else if(strcmp(g_szGameDir, "csgo")==0)
		GAME_CSGO = true;
	else if(strcmp(g_szGameDir, "dod")==0)
		GAME_DOD = true;
	else if(strcmp(g_szGameDir, "tf")==0)
		GAME_TF2 = true;
	else if(strcmp(g_szGameDir, "l4d")==0)
		GAME_L4D = true;
	else if(strcmp(g_szGameDir, "l4d2")==0)
		GAME_L4D2 = true;
	else
	{
		SetFailState("This game is not be supported. Please contact the author for support.");
	}

	// Supress warnings about unused variables.....
	if(GAME_DOD || GAME_L4D || GAME_L4D2 || g_bL4D || g_bL4D2 || g_bND) {}

	// Setting default values
	for(new i=1;i<=MaxClients;++i)
	{
		g_eClients[i][iCredits] = -1;
		g_eClients[i][iOriginalCredits] = 0;
		g_eClients[i][iItems] = -1;
		g_eClients[i][hCreditTimer] = INVALID_HANDLE;
	}

	// Register ConVars
	g_cvarDatabaseEntry = RegisterConVar("sm_store_database", "storage-local", "Name of the default store database entry", TYPE_STRING);
	g_cvarDatabaseRetries = RegisterConVar("sm_store_database_retries", "4", "Number of retries if the connection fails to estabilish with timeout", TYPE_INT);
	g_cvarDatabaseTimeout = RegisterConVar("sm_store_database_timeout", "10", "Timeout in seconds to wait for database connection before retry", TYPE_FLOAT);
	g_cvarItemSource = RegisterConVar("sm_store_item_source", "flatfile", "Source of the item list, can be set to flatfile and database, sm_store_items_table must be set if database is chosen (THIS IS HIGHLY EXPERIMENTAL AND MAY NOT WORK YET)", TYPE_STRING);
	g_cvarItemsTable = RegisterConVar("sm_store_items_table", "store_menu", "Name of the items table", TYPE_STRING);
	g_cvarStartCredits = RegisterConVar("sm_store_startcredits", "0", "Number of credits a client starts with", TYPE_INT);
	g_cvarCreditTimer = RegisterConVar("sm_store_credit_interval", "60", "Interval in seconds to give out credits", TYPE_FLOAT, ConVar_CreditTimer);
	g_cvarCreditAmountActive = RegisterConVar("sm_store_credit_amount_active", "1", "Number of credits to give out for active players", TYPE_INT, ConVar_CreditTimer);
	g_cvarCreditAmountInactive = RegisterConVar("sm_store_credit_amount_inactive", "1", "Number of credits to give out for inactive players (spectators)", TYPE_INT, ConVar_CreditTimer);
	g_cvarCreditAmountKill = RegisterConVar("sm_store_credit_amount_kill", "1", "Number of credits to give out for killing a player", TYPE_INT, ConVar_CreditTimer);
	g_cvarRequiredFlag = RegisterConVar("sm_store_required_flag", "", "Flag to access the !store menu", TYPE_FLAG);
	g_cvarVIPFlag = RegisterConVar("sm_store_vip_flag", "", "Flag for VIP access (all items unlocked). Leave blank to disable.", TYPE_FLAG);
	g_cvarAdminFlag = RegisterConVar("sm_store_admin_flag", "z", "Flag for admin access. Leave blank to disable.", TYPE_FLAG);
	g_cvarSellEnabled = RegisterConVar("sm_store_enable_selling", "1", "Enable/disable selling of already bought items.", TYPE_INT);
	g_cvarGiftEnabled = RegisterConVar("sm_store_enable_gifting", "1", "Enable/disable gifting of already bought items. [1=everyone, 2=admins only]", TYPE_INT);
	g_cvarCreditGiftEnabled = RegisterConVar("sm_store_enable_credit_gifting", "1", "Enable/disable gifting of credits.", TYPE_INT);
	g_cvarSellRatio = RegisterConVar("sm_store_sell_ratio", "0.60", "Ratio of the original price to get for selling an item.", TYPE_FLOAT);
	g_cvarConfirmation = RegisterConVar("sm_store_confirmation_windows", "1", "Enable/disable confirmation windows.", TYPE_INT);
	g_cvarSaveOnDeath = RegisterConVar("sm_store_save_on_death", "0", "Enable/disable client data saving on client death.", TYPE_INT);
	g_cvarCreditMessages = RegisterConVar("sm_store_credit_messages", "1", "Enable/disable messages when a player earns credits.", TYPE_INT);
	g_cvarChatTag = RegisterConVar("sm_store_chat_tag", "[Store] ", "The chat tag to use for displaying messages.", TYPE_STRING);
	g_cvarShowVIP = RegisterConVar("sm_store_show_vip_items", "0", "If you enable this VIP items will be shown in grey.", TYPE_INT);
	g_cvarLogging = RegisterConVar("sm_store_logging", "0", "Set this to 1 for file logging and 2 to SQL logging (only MySQL). Leaving on 0 means disabled.", TYPE_INT);
	g_cvarSilent = RegisterConVar("sm_store_silent_givecredits", "0", "Controls the give credits message visibility. 0 = public 1 = private 2 = no message", TYPE_INT);

	// Register Commands
	RegConsoleCmd("sm_store", Command_Store);
	RegConsoleCmd("sm_shop", Command_Store);
	RegConsoleCmd("sm_inv", Command_Inventory);
	RegConsoleCmd("sm_inventory", Command_Inventory);
	RegConsoleCmd("sm_gift", Command_Gift);
	RegAdminCmd("sm_givecredits", Command_GiveCredits, ADMFLAG_ROOT, "sm_givecredits <<#userid|name> <amount>");
	RegAdminCmd("sm_resetplayer", Command_ResetPlayer, ADMFLAG_ROOT, "sm_givecredits <<#userid|name> <amount>");
	RegConsoleCmd("sm_credits", Command_Credits);
	RegServerCmd("sm_store_custom_credits", Command_CustomCredits);
	
	// Hook events
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// Load the translations file
	LoadTranslations("store.phrases");

	// Initiaze the fake package handler
	g_iPackageHandler = Store_RegisterHandler("package", "", INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION);

	// Initialize the modules	
#if !defined STANDALONE_BUILD
	Hats_OnPluginStart();
	Tracers_OnPluginStart();
	Trails_OnPluginStart();
	PlayerSkins_OnPluginStart();
	GrenadeSkins_OnPluginStart();
	GrenadeTrails_OnPluginStart();
	WeaponColors_OnPluginStart();
	TFSupport_OnPluginStart();
	Paintball_OnPluginStart();
	Watergun_OnPluginStart();
	Betting_OnPluginStart();
	Gifts_OnPluginStart();
	SCPSupport_OnPluginStart();
	Weapons_OnPluginStart();
	Help_OnPluginStart();
	Jetpack_OnPluginStart();
	Bunnyhop_OnPluginStart();
	LaserSight_OnPluginStart();
	Health_OnPluginStart();
	Gravity_OnPluginStart();
	Speed_OnPluginStart();
	Invisibility_OnPluginStart();
	Commands_OnPluginStart();
	Doors_OnPluginStart();
	ZRClass_OnPluginStart();
	Jihad_OnPluginStart();
	Godmode_OnPluginStart();
	Sounds_OnPluginStart();
	Attributes_OnPluginStart();
	Respawn_OnPluginStart();
	Pets_OnPluginStart();
	Sprays_OnPluginStart();
	AdminGroup_OnPluginStart();
	Glow_OnPluginStart();
#endif

	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
		OnAdminMenuReady(topmenu);

	// Initialize handles
	g_hCustomCredits = CreateArray(3);

	// Load the config file
	Store_ReloadConfig();
	
	// After every module was loaded we are ready to generate the cfg
	AutoExecConfig();

	// Read core.cfg for chat triggers
	ReadCoreCFG();

	// Add a say command listener for shortcuts
	AddCommandListener(Command_Say, "say");

	LoopIngamePlayers(client)
	{
		OnClientConnected(client);
		OnClientPostAdminCheck(client);
		OnClientPutInServer(client);
	}

}

public OnAllPluginsLoaded()
{
	CreateTimer(1.0, LoadConfig);

	if(GetFeatureStatus(FeatureType_Native, "Donate_RegisterHandler")==FeatureStatus_Available)
		Donate_RegisterHandler("Store", Store_OnPaymentReceived);
}

public Action:LoadConfig(Handle:timer, any:data)
{
	// Load the config file
	Store_ReloadConfig();
}

public OnPluginEnd()
{
	LoopIngamePlayers(i)
		if(g_eClients[i][bLoaded])
			OnClientDisconnect(i);

	if(GetFeatureStatus(FeatureType_Native, "Donate_RemoveHandler")==FeatureStatus_Available)
		Donate_RemoveHandler("Store");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Store_RegisterHandler", Native_RegisterHandler);
	CreateNative("Store_RegisterMenuHandler", Native_RegisterMenuHandler);
	CreateNative("Store_SetDataIndex", Native_SetDataIndex);
	CreateNative("Store_GetDataIndex", Native_GetDataIndex);
	CreateNative("Store_GetEquippedItem", Native_GetEquippedItem);
	CreateNative("Store_IsClientLoaded", Native_IsClientLoaded);
	CreateNative("Store_DisplayPreviousMenu", Native_DisplayPreviousMenu);
	CreateNative("Store_SetClientMenu", Native_SetClientMenu);
	CreateNative("Store_GetClientCredits", Native_GetClientCredits);
	CreateNative("Store_SetClientCredits", Native_SetClientCredits);
	CreateNative("Store_IsClientVIP", Native_IsClientVIP);
	CreateNative("Store_IsItemInBoughtPackage", Native_IsItemInBoughtPackage);
	CreateNative("Store_DisplayConfirmMenu", Native_DisplayConfirmMenu);
	CreateNative("Store_ShouldConfirm", Native_ShouldConfirm);
	CreateNative("Store_GetItem", Native_GetItem);
	CreateNative("Store_GetHandler", Native_GetHandler);
	CreateNative("Store_GiveItem", Native_GiveItem);
	CreateNative("Store_RemoveItem", Native_RemoveItem);
	CreateNative("Store_GetClientItem", Native_GetClientItem);
	CreateNative("Store_GetClientTarget", Native_GetClientTarget);
	CreateNative("Store_GiveClientItem", Native_GiveClientItem);
	CreateNative("Store_HasClientItem", Native_HasClientItem);
	CreateNative("Store_IterateEquippedItems", Native_IterateEquippedItems);

#if !defined STANDALONE_BUILD
	MarkNativeAsOptional("ZR_IsClientZombie");
	MarkNativeAsOptional("ZR_IsClientHuman");
	MarkNativeAsOptional("ZR_GetClassByName");
	MarkNativeAsOptional("ZR_SelectClientClass");
	MarkNativeAsOptional("HideTrails_ShouldHide");
#endif
	return APLRes_Success;
} 

#if !defined STANDALONE_BUILD
public OnLibraryAdded(const String:name[])
{
	PlayerSkins_OnLibraryAdded(name);
	ZRClass_OnLibraryAdded(name);
}
#endif

//////////////////////////////
//		 ADMIN MENUS		//
//////////////////////////////

public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu == g_hAdminMenu)
		return;
	g_hAdminMenu = topmenu;

	g_eStoreAdmin = AddToTopMenu(g_hAdminMenu, "Store Admin", TopMenuObject_Category, CategoryHandler_StoreAdmin, INVALID_TOPMENUOBJECT);
	AddToTopMenu(g_hAdminMenu, "sm_store_resetdb", TopMenuObject_Item, AdminMenu_ResetDb, g_eStoreAdmin, "sm_store_resetdb", g_eCvars[g_cvarAdminFlag][aCache]);
	AddToTopMenu(g_hAdminMenu, "sm_store_resetplayer", TopMenuObject_Item, AdminMenu_ResetPlayer, g_eStoreAdmin, "sm_store_resetplayer", g_eCvars[g_cvarAdminFlag][aCache]);
	AddToTopMenu(g_hAdminMenu, "sm_store_givecredits", TopMenuObject_Item, AdminMenu_GiveCredits, g_eStoreAdmin, "sm_store_givecredits", g_eCvars[g_cvarAdminFlag][aCache]);
	AddToTopMenu(g_hAdminMenu, "sm_store_viewinventory", TopMenuObject_Item, AdminMenu_ViewInventory, g_eStoreAdmin, "sm_store_viewinventory", g_eCvars[g_cvarAdminFlag][aCache]);
}

public CategoryHandler_StoreAdmin(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Store Admin");
}

//////////////////////////////
//		Reset database		//
//////////////////////////////

public AdminMenu_ResetDb(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Reset database");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;
		Store_DisplayConfirmMenu(client, "Do you want to reset database?\nServer will be restarted!", FakeMenuHandler_ResetDatabase, 0);
	}
}

public FakeMenuHandler_ResetDatabase(Handle:menu, MenuAction:action, client, param2)
{
	SQL_TVoid(g_hDatabase, "DROP TABLE store_players");
	SQL_TVoid(g_hDatabase, "DROP TABLE store_items");
	SQL_TVoid(g_hDatabase, "DROP TABLE store_equipment");
	ServerCommand("_restart");
}

//////////////////////////////
//		Reset player		//
//////////////////////////////

public AdminMenu_ResetPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Reset player");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		new Handle:m_hMenu = CreateMenu(MenuHandler_ResetPlayer);
		SetMenuTitle(m_hMenu, "Choose a player to reset");
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			decl String:m_szName[64];
			decl String:m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public MenuHandler_ResetPlayer(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
			FakeClientCommandEx(client, "sm_resetplayer \"%s\"", g_szClientData[client]);
		else
		{
			decl style;
			decl String:m_szName[64];
			GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]), style, STRING(m_szName));

			decl String:m_szTitle[256];
			Format(STRING(m_szTitle), "Do you want to reset %s?", m_szName);
			Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_ResetPlayer, 0);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

//////////////////////////////
//		Give credits		//
//////////////////////////////

public AdminMenu_GiveCredits(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Give credits");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 5;
		new Handle:m_hMenu = CreateMenu(MenuHandler_GiveCredits);
		SetMenuTitle(m_hMenu, "Choose a player to give credits to");
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			decl String:m_szName[64];
			decl String:m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public MenuHandler_GiveCredits(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(param2 != -1)
			GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]));
		new Handle:m_hMenu = CreateMenu(MenuHandler_GiveCredits2);

		new target = GetClientBySteamID(g_szClientData[client]);
		if(target == 0)
		{
			AdminMenu_GiveCredits(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
			return;
		}

		SetMenuTitle(m_hMenu, "Choose the amount of credits\n%N - %d credits", target, g_eClients[target][iCredits]);
		SetMenuExitBackButton(m_hMenu, true);
		AddMenuItem(m_hMenu, "-1000", "-1000");
		AddMenuItem(m_hMenu, "-100", "-100");
		AddMenuItem(m_hMenu, "-10", "-10");
		AddMenuItem(m_hMenu, "10", "10");
		AddMenuItem(m_hMenu, "100", "100");
		AddMenuItem(m_hMenu, "1000", "1000");
		DisplayMenu(m_hMenu, client, 0);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

public MenuHandler_GiveCredits2(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		decl String:m_szData[11];
		GetMenuItem(menu, param2, STRING(m_szData));
		FakeClientCommand(client, "sm_givecredits \"%s\" %s", g_szClientData[client], m_szData);
		MenuHandler_GiveCredits(INVALID_HANDLE, MenuAction_Select, client, -1);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		AdminMenu_GiveCredits(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
}

//////////////////////////////
//		View inventory		//
//////////////////////////////

public AdminMenu_ViewInventory(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "View inventory");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		new Handle:m_hMenu = CreateMenu(MenuHandler_ViewInventory);
		SetMenuTitle(m_hMenu, "Choose a player");
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			decl String:m_szName[64];
			decl String:m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public MenuHandler_ViewInventory(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]));
		new target = GetClientBySteamID(g_szClientData[client]);
		if(target == 0)
		{
			AdminMenu_ViewInventory(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
			return;
		}

		g_bInvMode[client]=true;
		g_iMenuClient[client]=target;
		DisplayStoreMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

//////////////////////////////////////
//		REST OF PLUGIN FORWARDS		//
//////////////////////////////////////

public OnMapStart()
{
	for(new i=0;i<g_iTypeHandlers;++i)
	{
		if(g_eTypeHandlers[i][fnMapStart] != INVALID_FUNCTION)
		{
			Call_StartFunction(g_eTypeHandlers[i][hPlugin], g_eTypeHandlers[i][fnMapStart]);
			Call_Finish();
		}
	}
}

public OnConfigsExecuted()
{
	Jetpack_OnConfigsExecuted();
	Jihad_OnConfigsExecuted();

	// Connect to the database
	if(g_hDatabase == INVALID_HANDLE)
		SQL_TConnect(SQLCallback_Connect, g_eCvars[g_cvarDatabaseEntry][sCache]);
	if(g_eCvars[g_cvarDatabaseRetries][aCache] > 0)
		CreateTimer(Float:g_eCvars[g_cvarDatabaseTimeout][aCache], Timer_DatabaseTimeout);

	if(g_eCvars[g_cvarLogging][aCache] == 1)
		if(g_hLogFile == INVALID_HANDLE)
		{
			new String:m_szPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, STRING(m_szPath), "logs/store.log.txt");
			g_hLogFile = OpenFile(m_szPath, "w+");
		}
}

#if !defined STANDALONE_BUILD
public OnGameFrame()
{
	Trails_OnGameFrame();
	TFWeapon_OnGameFrame();
	TFHead_OnGameFrame();
}
#endif

#if !defined STANDALONE_BUILD
public OnEntityCreated(entity, const String:classname[])
{
	GrenadeSkins_OnEntityCreated(entity, classname);
	GrenadeTrails_OnEntityCreated(entity, classname);
}
#endif

//////////////////////////////
//			NATIVES			//
//////////////////////////////

public Native_RegisterHandler(Handle:plugin, numParams)
{
	if(g_iTypeHandlers == STORE_MAX_HANDLERS)
		return -1;
		
	decl String:m_szType[32];
	GetNativeString(1, STRING(m_szType));
	new m_iHandler = Store_GetTypeHandler(m_szType);	
	new m_iId = g_iTypeHandlers;
	
	if(m_iHandler != -1)
		m_iId = m_iHandler;
	else
		++g_iTypeHandlers;
	
	g_eTypeHandlers[m_iId][hPlugin] = plugin;
	g_eTypeHandlers[m_iId][fnMapStart] = GetNativeCell(3);
	g_eTypeHandlers[m_iId][fnReset] = GetNativeCell(4);
	g_eTypeHandlers[m_iId][fnConfig] = GetNativeCell(5);
	g_eTypeHandlers[m_iId][fnUse] = GetNativeCell(6);
	g_eTypeHandlers[m_iId][fnRemove] = GetNativeCell(7);
	g_eTypeHandlers[m_iId][bEquipable] = GetNativeCell(8);
	g_eTypeHandlers[m_iId][bRaw] = GetNativeCell(9);
	strcopy(g_eTypeHandlers[m_iId][szType], 32, m_szType);
	GetNativeString(2, g_eTypeHandlers[m_iId][szUniqueKey], 32);

	return m_iId;
}

public Native_RegisterMenuHandler(Handle:plugin, numParams)
{
	if(g_iMenuHandlers == STORE_MAX_HANDLERS)
		return -1;
		
	decl String:m_szIdentifier[64];
	GetNativeString(1, STRING(m_szIdentifier));
	new m_iHandler = Store_GetMenuHandler(m_szIdentifier);	
	new m_iId = g_iMenuHandlers;
	
	if(m_iHandler != -1)
		m_iId = m_iHandler;
	else
		++g_iMenuHandlers;
	
	g_eMenuHandlers[m_iId][hPlugin] = plugin;
	g_eMenuHandlers[m_iId][fnMenu] = GetNativeCell(2);
	g_eMenuHandlers[m_iId][fnHandler] = GetNativeCell(3);
	strcopy(g_eMenuHandlers[m_iId][szIdentifier], 64, m_szIdentifier);

	return m_iId;
}

public Native_SetDataIndex(Handle:plugin, numParams)
{
	g_eItems[GetNativeCell(1)][iData] = GetNativeCell(2);
}

public Native_GetDataIndex(Handle:plugin, numParams)
{
	return g_eItems[GetNativeCell(1)][iData];
}

public Native_GetEquippedItem(Handle:plugin, numParams)
{
	decl String:m_szType[16];
	GetNativeString(2, STRING(m_szType));
	
	new m_iHandler = Store_GetTypeHandler(m_szType);
	if(m_iHandler == -1)
		return -1;
	
	return Store_GetEquippedItemFromHandler(GetNativeCell(1), m_iHandler, GetNativeCell(3));
}

public Native_IsClientLoaded(Handle:plugin, numParams)
{
	return g_eClients[GetNativeCell(1)][bLoaded];
}

public Native_DisplayPreviousMenu(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(g_iMenuNum[client] == 1)
		DisplayStoreMenu(client, g_iMenuBack[client], g_iLastSelection[client]);
	else if(g_iMenuNum[client] == 2)
		DisplayItemMenu(client, g_iSelectedItem[client]);
	else if(g_iMenuNum[client] == 3)
		DisplayPlayerMenu(client);
	else if(g_iMenuNum[client] == 4)
		AdminMenu_ResetPlayer(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
	else if(g_iMenuNum[client] == 5)
		DisplayPlanMenu(client, g_iSelectedItem[client]);
	else if(g_iMenuNum[client] == 0)
		RedisplayAdminMenu(g_hAdminMenu, client);
}

public Native_SetClientMenu(Handle:plugin, numParams)
{
	g_iMenuNum[GetNativeCell(1)] = GetNativeCell(2);
}

public Native_GetClientCredits(Handle:plugin, numParams)
{
	return g_eClients[GetNativeCell(1)][iCredits];
}

public Native_SetClientCredits(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new m_iCredits = GetNativeCell(2);
	Store_LogMessage(client, m_iCredits-g_eClients[client][iCredits], "Set by external plugin");
	g_eClients[client][iCredits] = m_iCredits;
	return 1;
}

public Native_IsClientVIP(Handle:plugin, numParams)
{
	return (g_eCvars[g_cvarVIPFlag][aCache] != 0 && GetClientPrivilege(GetNativeCell(1), g_eCvars[g_cvarVIPFlag][aCache]));
}

public Native_IsItemInBoughtPackage(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	new uid = GetNativeCell(3);

	decl m_iParent;
	if(itemid<0)
		m_iParent = g_eItems[itemid][iParent];
	else
		m_iParent = g_eItems[itemid][iParent];
		
	while(m_iParent != -1)
	{
		for(new i=0;i<g_eClients[client][iItems];++i)
			if(((uid == -1 && g_eClientItems[client][i][iUniqueId] == m_iParent) || (uid != -1 && g_eClientItems[client][i][iUniqueId] == uid)) && !g_eClientItems[client][i][bDeleted])
				return true;
		m_iParent = g_eItems[m_iParent][iParent];
	}
	return false;
}

public Native_DisplayConfirmMenu(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	decl String:title[255];
	GetNativeString(2, STRING(title));
	new callback = GetNativeCell(3);
	new data = GetNativeCell(4);

	new Handle:m_hMenu = CreateMenu(MenuHandler_Confirm);
	SetMenuTitle(m_hMenu, title);
	SetMenuExitButton(m_hMenu, false);
	new String:m_szCallback[32];
	new String:m_szData[11];
	Format(STRING(m_szCallback), "%d.%d", plugin, callback);
	IntToString(data, STRING(m_szData));
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, m_szCallback, "%t", "Confirm_Yes");
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, m_szData, "%t", "Confirm_No");
	DisplayMenu(m_hMenu, client, 0);
}

public Native_ShouldConfirm(Handle:plugin, numParams)
{
	return g_eCvars[g_cvarConfirmation][aCache];
}

public Native_GetItem(Handle:plugin, numParams)
{
	SetNativeArray(2, _:g_eItems[GetNativeCell(1)], sizeof(g_eItems[])); 
}

public Native_GetHandler(Handle:plugin, numParams)
{
	SetNativeArray(2, _:g_eTypeHandlers[GetNativeCell(1)], sizeof(g_eTypeHandlers[])); 
}

public Native_GetClientItem(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);

	new uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;

	SetNativeArray(3, _:g_eClientItems[client][uid], sizeof(g_eClientItems[][])); 

	return 1;
}

public Native_GiveItem(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	new purchase = GetNativeCell(3);
	new expiration = GetNativeCell(4);
	new price = GetNativeCell(5);

	new m_iDateOfPurchase = (purchase==0?GetTime():purchase);
	new m_iDateOfExpiration = expiration;

	new m_iId = g_eClients[client][iItems]++;
	g_eClientItems[client][m_iId][iId] = -1;
	g_eClientItems[client][m_iId][iUniqueId] = itemid;
	g_eClientItems[client][m_iId][iDateOfPurchase] = m_iDateOfPurchase;
	g_eClientItems[client][m_iId][iDateOfExpiration] = m_iDateOfExpiration;
	g_eClientItems[client][m_iId][iPriceOfPurchase] = price;
	g_eClientItems[client][m_iId][bSynced] = false;
	g_eClientItems[client][m_iId][bDeleted] = false;
}

public Native_RemoveItem(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);
	if(itemid>0 && g_eTypeHandlers[g_eItems[itemid][iHandler]][fnRemove] != INVALID_FUNCTION)
	{
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid][iHandler]][hPlugin], g_eTypeHandlers[g_eItems[itemid][iHandler]][fnRemove]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	
	Store_UnequipItem(client, itemid, false);
	
	new m_iId = Store_GetClientItemId(client, itemid);
	if(m_iId != -1)
		g_eClientItems[client][m_iId][bDeleted] = true;
}

public Native_GetClientTarget(Handle:plugin, numParams)
{
	return g_iMenuClient[GetNativeCell(1)];
}

public Native_GiveClientItem(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new receiver = GetNativeCell(2);
	new itemid = GetNativeCell(3);

	new item = Store_GetClientItemId(client, itemid);
	if(item == -1)
		return 1;

	new m_iId = g_eClientItems[client][item][iUniqueId];
	new target = g_iMenuClient[client];
	g_eClientItems[client][item][bDeleted] = true;
	Store_UnequipItem(client, m_iId);

	g_eClientItems[receiver][g_eClients[receiver][iItems]][iId] = -1;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iUniqueId] = m_iId;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][bSynced] = false;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][bDeleted] = false;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iDateOfPurchase] = g_eClientItems[target][item][iDateOfPurchase];
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iDateOfExpiration] = g_eClientItems[target][item][iDateOfExpiration];
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iPriceOfPurchase] = g_eClientItems[target][item][iPriceOfPurchase];
	
	++g_eClients[receiver][iItems];

	return 1;
}

public Native_HasClientItem(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new itemid = GetNativeCell(2);

	// Can he even have it?	
	if(!GetClientPrivilege(client, g_eItems[itemid][iFlagBits]))
		return false;

	// Is the item free (available for everyone)?
	if(g_eItems[itemid][iPrice] <= 0 && g_eItems[itemid][iPlans]==0)
		return true;
		
	// Is the client a VIP therefore has access to all the items already?
	if(Store_IsClientVIP(client) && !g_eItems[itemid][bIgnoreVIP])
		return true;
		
	// Can he even have it?	
	if(!GetClientPrivilege(client, g_eItems[itemid][iFlagBits]))
		return false;
		
	// Check if the client actually has the item
	for(new i=0;i<g_eClients[client][iItems];++i)
	{
		if(g_eClientItems[client][i][iUniqueId] == itemid && !g_eClientItems[client][i][bDeleted])
			if(g_eClientItems[client][i][iDateOfExpiration]==0 || (g_eClientItems[client][i][iDateOfExpiration] && GetTime()<g_eClientItems[client][i][iDateOfExpiration]))
				return true;
			else
				return false;
	}
	
	// Check if the item is part of a group the client already has
	if(Store_IsItemInBoughtPackage(client, itemid))
		return true;
		
	return false;
}

public Native_IterateEquippedItems(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new start = GetNativeCellRef(2);
	new bool:attributes = GetNativeCell(3);

	for(new i=start+1;i<STORE_MAX_HANDLERS*STORE_MAX_SLOTS;++i)
	{
		if(g_eClients[client][aEquipment][i] >= 0 && (attributes==false || (attributes && g_eItems[g_eClients[client][aEquipment][i]][hAttributes]!=INVALID_HANDLE)))
		{
			SetNativeCellRef(2, i);
			return g_eClients[client][aEquipment][i];
		}
	}
		
	return -1;
}

//////////////////////////////
//		CLIENT FORWARDS		//
//////////////////////////////

public OnClientConnected(client)
{
	g_iSpam[client] = 0;
	g_eClients[client][iUserId] = GetClientUserId(client);
	g_eClients[client][iCredits] = -1;
	g_eClients[client][iOriginalCredits] = 0;
	g_eClients[client][iItems] = -1;
	g_eClients[client][bLoaded] = false;
	for(new i=0;i<STORE_MAX_HANDLERS;++i)
	{
		for(new a=0;a<STORE_MAX_SLOTS;++a)
		{
			g_eClients[client][aEquipment][i*STORE_MAX_SLOTS+a] = -2;
			g_eClients[client][aEquipmentSynced][i*STORE_MAX_SLOTS+a] = -2;
		}
	}

#if !defined STANDALONE_BUILD
	PlayerSkins_OnClientConnected(client);
	Jetpack_OnClientConnected(client);
	ZRClass_OnClientConnected(client);
	Pets_OnClientConnected(client);
	Sprays_OnClientConnected(client);
	Glow_OnClientConnected(client);
#endif
}

public OnClientPostAdminCheck(client)
{
	if(IsFakeClient(client))
		return;
	Store_LoadClientInventory(client);
}

#if !defined STANDALONE_BUILD
public OnClientPutInServer(client)
{
	if(IsFakeClient(client))
		return;
	WeaponColors_OnClientPutInServer(client);
}
#endif

public OnClientDisconnect(client)
{
	if(IsFakeClient(client))
		return;
	
#if !defined STANDALONE_BUILD
	Betting_OnClientDisconnect(client);
	Pets_OnClientDisconnect(client);
	Glow_OnClientDisconnect(client);
#endif

	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
	Store_DisconnectClient(client);
}

public OnClientSettingsChanged(client)
{
	GetClientName(client, g_eClients[client][szName], 64);
	if(g_hDatabase)
		SQL_EscapeString(g_hDatabase, g_eClients[client][szName], g_eClients[client][szNameEscaped], 128);
}

#if !defined STANDALONE_BUILD
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if(!IsClientInGame(client))
		return Plugin_Continue;

	new Action:m_iRet = Plugin_Continue;

	Jetpack_OnPlayerRunCmd(client, buttons);
	LaserSight_OnPlayerRunCmd(client);
	Pets_OnPlayerRunCmd(client, tickcount);
	Sprays_OnPlayerRunCmd(client, buttons);
	m_iRet = Bunnyhop_OnPlayerRunCmd(client, buttons);

	return m_iRet;
}
#endif

//////////////////////////////
//			EVENTS			//
//////////////////////////////

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(g_eCvars[g_cvarSaveOnDeath][aCache])
	{
		Store_SaveClientData(victim);
		Store_SaveClientInventory(victim);
		Store_SaveClientEquipment(victim);
	}

	if(!attacker || victim == attacker || !IsClientInGame(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;

	if(g_eCvars[g_cvarCreditAmountKill][aCache])
	{
		g_eClients[attacker][iCredits] += GetMultipliedCredits(attacker, g_eCvars[g_cvarCreditAmountKill][aCache]);
		if(g_eCvars[g_cvarCreditMessages][aCache])
			Chat(attacker, "%t", "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill][aCache], g_eClients[victim][szName]);
		Store_LogMessage(attacker, g_eCvars[g_cvarCreditAmountKill][aCache], "Earned for killing");
	}
		
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsClientInGame(client))
		return Plugin_Continue;

#if !defined STANDALONE_BUILD
	Health_OnPlayerSpawn(client);
#endif
		
	return Plugin_Continue;
}


//////////////////////////////////
//			COMMANDS	 		//
//////////////////////////////////

public Action:Command_Say(client, const String:command[], argc)
{
	if(argc > 0)
	{
		decl String:m_szArg[65];
		GetCmdArg(1, STRING(m_szArg));
		if(m_szArg[0] == PublicChatTrigger)
		{
			for(new i=0;i<g_iItems;++i)
				if(strcmp(g_eItems[i][szShortcut], m_szArg[1])==0 && g_eItems[i][szShortcut][0] != 0)
				{
					g_bInvMode[client]=false;
					g_iMenuClient[client]=client;
					DisplayStoreMenu(client, i);
					break;
				}
		}
	}
	return Plugin_Continue;
}

public Action:Command_Store(client, params)
{
	if(g_eCvars[g_cvarRequiredFlag][aCache] && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag][aCache]))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}
	
	if((g_eClients[client][iCredits] == -1 && g_eClients[client][iItems] == -1) || !g_eClients[client][bLoaded])
	{
		Chat(client, "%t", "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	
	g_bInvMode[client]=false;
	g_iMenuClient[client]=client;
	DisplayStoreMenu(client);
	
	return Plugin_Handled;
}

public Action:Command_Inventory(client, params)
{
	if(g_eCvars[g_cvarRequiredFlag][aCache] && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag][aCache]))
	{
		Chat(client, "%t", "You dont have permission");
		return Plugin_Handled;
	}
	
	if((g_eClients[client][iCredits] == -1 && g_eClients[client][iItems] == -1) || !g_eClients[client][bLoaded])
	{
		Chat(client, "%t", "Inventory hasnt been fetched");
		return Plugin_Handled;
	}
	
	g_bInvMode[client]=true;
	g_iMenuClient[client]=client;
	DisplayStoreMenu(client);

	return Plugin_Handled;
}

public Action:Command_Gift(client, params)
{
	if(!g_eCvars[g_cvarCreditGiftEnabled][aCache])
	{
		Chat(client, "%t", "Credit Gift Disabled");
		return Plugin_Handled;
	}
	
	decl String:m_szTmp[64];
	GetCmdArg(2, STRING(m_szTmp));
	
	new m_iCredits = StringToInt(m_szTmp);
	if(g_eClients[client][iCredits]<m_iCredits || m_iCredits<=0)
	{
		Chat(client, "%t", "Credit Invalid Amount");
		return Plugin_Handled;
	}

	decl bool:m_bTmp;
	decl m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));
	
	new m_iClients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
	if(m_iClients>2)
	{
		Chat(client, "%t", "Credit Too Many Matches");
		return Plugin_Handled;
	}
	
	if(m_iClients != 1)
	{
		Chat(client, "%t", "Credit No Match");
		return Plugin_Handled;
	}
	
	new m_iReceiver = m_iTargets[0];
	
	g_eClients[client][iCredits] -= m_iCredits;
	g_eClients[m_iReceiver][iCredits] += m_iCredits;
	
	Chat(client, "%t", "Credit Gift Sent", m_iCredits, g_eClients[m_iReceiver][szName]);
	Chat(m_iReceiver, "%t", "Credit Gift Received", m_iCredits, g_eClients[client][szName]);

	Store_LogMessage(m_iReceiver, m_iCredits, "Gifted by %N", client);
	Store_LogMessage(client, -m_iCredits, "Gifted to %N", m_iReceiver);
	
	return Plugin_Handled;
}

public Action:Command_GiveCredits(client, params)
{
	decl String:m_szTmp[64];
	GetCmdArg(2, STRING(m_szTmp));
	
	new m_iCredits = StringToInt(m_szTmp);

	decl bool:m_bTmp;
	decl m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));

	new m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			decl String:m_szQuery[512];
			if(g_bMySQL)
				Format(STRING(m_szQuery), "INSERT IGNORE INTO store_players (authid, credits) VALUES (\"%s\", %d) ON DUPLICATE KEY UPDATE credits=credits+%d", m_szTmp[8], m_iCredits, m_iCredits);
			else
			{
				Format(STRING(m_szQuery), "INSERT OR IGNORE INTO store_players (authid) VALUES (\"%s\")", m_szTmp[8]);
				SQL_TVoid(g_hDatabase, m_szQuery);
				Format(STRING(m_szQuery), "UPDATE store_players SET credits=credits+%d WHERE authid=\"%s\"", m_iCredits, m_szTmp[8]);
			}
			SQL_TVoid(g_hDatabase, m_szQuery);
			ChatAll("%t", "Credits Given", m_szTmp[8], m_iCredits);
			m_iReceiver = -1;
		}
	} else if(strcmp(m_szTmp, "@all")==0)
	{
		LoopIngamePlayers(i)
			FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
	} else if(strcmp(m_szTmp, "@t")==0 || strcmp(m_szTmp, "@red")==0)
	{
		LoopIngamePlayers(i)
			if(GetClientTeam(i)==2)
				FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
	} else if(strcmp(m_szTmp, "@ct")==0 || strcmp(m_szTmp, "@blu")==0)
	{
		LoopIngamePlayers(i)
			if(GetClientTeam(i)==3)
				FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
	}
	else
	{
		new m_iClients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_iClients>2)
		{
			if(client)
				Chat(client, "%t", "Credit Too Many Matches");
			else
				ReplyToCommand(client, "%t", "Credit Too Many Matches");
			return Plugin_Handled;
		} else if(m_iClients != 1)
		{
			if(client)
				Chat(client, "%t", "Credit No Match");
			else
				ReplyToCommand(client, "%t", "Credit No Match");
			return Plugin_Handled;
		}

		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		g_eClients[m_iReceiver][iCredits] += m_iCredits;
		if(g_eCvars[g_cvarSilent][aCache] == 1)
		{
			if(client)
				Chat(client, "%t", "Credits Given", g_eClients[m_iReceiver][szName], m_iCredits);
			else
				ReplyToCommand(client, "%t", "Credits Given", g_eClients[m_iReceiver][szName], m_iCredits);
			Chat(m_iReceiver, "%t", "Credits Given", g_eClients[m_iReceiver][szName], m_iCredits);
		}
		else if(g_eCvars[g_cvarSilent][aCache] == 0)
			ChatAll("%t", "Credits Given", g_eClients[m_iReceiver][szName], m_iCredits);
		Store_LogMessage(m_iReceiver, m_iCredits, "Given by Admin");
	}
	
	return Plugin_Handled;
}

public Action:Command_ResetPlayer(client, params)
{
	decl String:m_szTmp[64];
	decl bool:m_bTmp;
	decl m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));

	new m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			decl String:m_szQuery[512];
			Format(STRING(m_szQuery), "SELECT id, authid FROM store_players WHERE authid=\"%s\"", m_szTmp[9]);
			SQL_TQuery(g_hDatabase, SQLCallback_ResetPlayer, m_szQuery, g_eClients[client][iUserId]);
		}
	}
	else
	{	
		new m_iClients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_iClients>2)
		{
			Chat(client, "%t", "Credit Too Many Matches");
			return Plugin_Handled;
		}
		
		if(m_iClients != 1)
		{
			Chat(client, "%t", "Credit No Match");
			return Plugin_Handled;
		}

		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		Store_LogMessage(client, -g_eClients[m_iReceiver][iCredits], "Player resetted");
		g_eClients[m_iReceiver][iCredits] = 0;
		for(new i=0;i<g_eClients[m_iReceiver][iItems];++i)
			Store_RemoveItem(m_iReceiver, g_eClientItems[m_iReceiver][i][iUniqueId]);
		ChatAll("%t", "Player Resetted", g_eClients[m_iReceiver][szName]);
	}
	
	return Plugin_Handled;
}

public Action:Command_Credits(client, params)
{	
	if(g_eClients[client][iCredits] == -1 && g_eClients[client][iItems] == -1)
	{
		Chat(client, "%t", "Inventory hasnt been fetched");
		return Plugin_Handled;
	}

	if(g_iSpam[client]<GetTime())
	{
		ChatAll("%t", "Player Credits", g_eClients[client][szName], g_eClients[client][iCredits]);
		g_iSpam[client] = GetTime()+30;
	}
	
	return Plugin_Handled;
}

public Action:Command_CustomCredits(params)
{
	if(params < 2)
	{
		PrintToServer("sm_store_custom_credits [flag] [multiplier]");
		return Plugin_Handled;
	}

	new String:tmp[16];
	GetCmdArg(1, STRING(tmp));
	new flag = ReadFlagString(tmp);
	GetCmdArg(2, STRING(tmp));
	new Float:mult = StringToFloat(tmp);

	new size = GetArraySize(g_hCustomCredits);
	new index = -1;
	for(new i=0;i<size;++i)
	{
		new sflag = GetArrayCell(g_hCustomCredits, i, 0);
		if(sflag == flag)
		{
			index = i;
			break;
		}
	}

	if(index == -1)
	{
		index = PushArrayCell(g_hCustomCredits, flag);
	}

	SetArrayCell(g_hCustomCredits, index, mult, 1);

	return Plugin_Handled;
}

//////////////////////////////
//			MENUS	 		//
//////////////////////////////

DisplayStoreMenu(client, parent=-1, last=-1)
{
	if(!client || !IsClientInGame(client))
		return;

	g_iMenuNum[client] = 1;
	new target = g_iMenuClient[client];

	new Handle:m_hMenu = CreateMenu(MenuHandler_Store);
	if(parent!=-1)
	{
		SetMenuExitBackButton(m_hMenu, true);
		if(client == target)
			SetMenuTitle(m_hMenu, "%s\n%t", g_eItems[parent][szName], "Title Credits", g_eClients[target][iCredits]);
		else
			SetMenuTitle(m_hMenu, "%N\n%s\n%t", target, g_eItems[parent][szName], "Title Credits", g_eClients[target][iCredits]);
		g_iMenuBack[client] = g_eItems[parent][iParent];
	}
	else if(client == target)
		SetMenuTitle(m_hMenu, "%t\n%t", "Title Store", "Title Credits", g_eClients[target][iCredits]);
	else
		SetMenuTitle(m_hMenu, "%N\n%t\n%t", target, "Title Store", "Title Credits", g_eClients[target][iCredits]);
	
	decl String:m_szId[11];
	new m_iFlags = GetUserFlagBits(target);
	new m_iPosition = 0;
	
	g_iSelectedItem[client] = parent;
	if(parent != -1)
	{
		if(g_eItems[parent][iPrice]>0)
		{
			if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, parent))
			{
				if(g_eCvars[g_cvarSellEnabled][aCache])
				{
					AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "sell_package", "%t", "Package Sell", RoundToFloor(g_eItems[parent][iPrice]*Float:g_eCvars[g_cvarSellRatio][aCache]));
					++m_iPosition;
				}
				if(g_eCvars[g_cvarGiftEnabled][aCache] == 1 || (g_eCvars[g_cvarGiftEnabled][aCache] == 2 && GetUserFlagBits(client) & g_eCvars[g_cvarAdminFlag][aCache]))
				{
					AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "gift_package", "%t", "Package Gift");
					++m_iPosition;
				}

				for(new i=0;i<g_iMenuHandlers;++i)
				{
					if(g_eMenuHandlers[i][hPlugin] == INVALID_HANDLE)
						continue;
					Call_StartFunction(g_eMenuHandlers[i][hPlugin], g_eMenuHandlers[i][fnMenu]);
					Call_PushCellRef(m_hMenu);
					Call_PushCell(client);
					Call_PushCell(parent);
					Call_Finish();
				}
			}
		}
	}
	
	for(new i=0;i<g_iItems;++i)
	{
		if(g_eItems[i][iParent]==parent && (g_eCvars[g_cvarShowVIP][aCache] == 0 && GetClientPrivilege(target, g_eItems[i][iFlagBits], m_iFlags) || g_eCvars[g_cvarShowVIP][aCache]))
		{
			new m_iPrice = Store_GetLowestPrice(i);

			// This is a package
			if(g_eItems[i][iHandler] == g_iPackageHandler)
			{
				if(!Store_PackageHasClientItem(target, i, g_bInvMode[client]))
					continue;

				new m_iStyle = ITEMDRAW_DEFAULT;
				if(g_eCvars[g_cvarShowVIP][aCache] && !GetClientPrivilege(target, g_eItems[i][iFlagBits], m_iFlags))
					m_iStyle = ITEMDRAW_DISABLED;
				
				IntToString(i, STRING(m_szId));
				if(g_eItems[i][iPrice] == -1 || Store_HasClientItem(target, i))
					AddMenuItem(m_hMenu, m_szId, g_eItems[i][szName], m_iStyle);
				else if(!g_bInvMode[client] && g_eItems[i][iPlans]==0 && g_eItems[i][bBuyable])
					InsertMenuItemEx(m_hMenu, m_iPosition, (m_iPrice<=g_eClients[target][iCredits]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), m_szId, "%t", "Item Available", g_eItems[i][szName], g_eItems[i][iPrice]);
				else if(!g_bInvMode[client])
					InsertMenuItemEx(m_hMenu, m_iPosition, (m_iPrice<=g_eClients[target][iCredits]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), m_szId, "%t", "Item Plan Available", g_eItems[i][szName]);
				++m_iPosition;
			}
			// This is a normal item
			else
			{
				IntToString(i, STRING(m_szId));
				if(Store_HasClientItem(target, i))
				{
					if(Store_IsEquipped(target, i))
						InsertMenuItemEx(m_hMenu, m_iPosition, ITEMDRAW_DEFAULT, m_szId, "%t", "Item Equipped", g_eItems[i][szName]);
					else
						InsertMenuItemEx(m_hMenu, m_iPosition, ITEMDRAW_DEFAULT, m_szId, "%t", "Item Bought", g_eItems[i][szName]);
				}
				else if(!g_bInvMode[client])
				{				
					new m_iStyle = ITEMDRAW_DEFAULT;
					if((g_eItems[i][iPlans]==0 && g_eClients[target][iCredits]<m_iPrice) || (g_eCvars[g_cvarShowVIP][aCache] && !GetClientPrivilege(target, g_eItems[i][iFlagBits], m_iFlags)))
						m_iStyle = ITEMDRAW_DISABLED;
					
					if(!g_eItems[i][bBuyable])
						continue;

					if(g_eItems[i][iPlans]==0)
						AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t", "Item Available", g_eItems[i][szName], g_eItems[i][iPrice]);
					else
						AddMenuItemEx(m_hMenu, m_iStyle, m_szId, "%t", "Item Plan Available", g_eItems[i][szName], g_eItems[i][iPrice]);
				}
			}
		}
	}
	
	if(last == -1)
		DisplayMenu(m_hMenu, client, 0);
	else
		DisplayMenuAtItem(m_hMenu, client, (last/GetMenuPagination(m_hMenu))*GetMenuPagination(m_hMenu), 0);
}

public MenuHandler_Store(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		new target = g_iMenuClient[client];
		// Confirmation was given
		if(menu == INVALID_HANDLE)
		{
			if(param2 == 0)
			{
				g_iMenuBack[client]=1;
				new m_iPrice = 0;
				if(g_iSelectedPlan[client]==-1)
					m_iPrice = g_eItems[g_iSelectedItem[client]][iPrice];
				else
					m_iPrice = g_ePlans[g_iSelectedItem[client]][g_iSelectedPlan[client]][iPrice];

				if(g_eClients[target][iCredits]>=m_iPrice && !Store_HasClientItem(target, g_iSelectedItem[client]))
					Store_BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);

				if(g_eItems[g_iSelectedItem[client]][iHandler] == g_iPackageHandler)
					DisplayStoreMenu(client, g_iSelectedItem[client]);
				else
					DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			else if(param2 == 1)
			{
				Store_SellItem(target, g_iSelectedItem[client]);
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			new String:m_szId[64];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			g_iLastSelection[client]=param2;
			
			// We are selling a package
			if(strcmp(m_szId, "sell_package")==0)
			{
				if(g_eCvars[g_cvarConfirmation][aCache])
				{
					decl String:m_szTitle[128];
					Format(STRING(m_szTitle), "%t", "Confirm_Sell", g_eItems[g_iSelectedItem[client]][szName], g_eTypeHandlers[g_eItems[g_iSelectedItem[client]][iHandler]][szType], RoundToFloor(g_eItems[g_iSelectedItem[client]][iPrice]*Float:g_eCvars[g_cvarSellRatio][aCache]));
					Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 1);
					return;
				}
				else
				{
					Store_SellItem(target, g_iSelectedItem[client]);
					Store_DisplayPreviousMenu(client);
				}
			}
			// We are gifting a package
			else if(strcmp(m_szId, "gift_package")==0)
			{
				DisplayPlayerMenu(client);
			}
			// This is menu handler stuff
			else if(!(48 <= m_szId[0] <= 57))
			{
				decl ret;
				for(new i=0;i<g_iMenuHandlers;++i)
				{
					Call_StartFunction(g_eMenuHandlers[i][hPlugin], g_eMenuHandlers[i][fnHandler]);
					Call_PushCell(target);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
			// We are being boring
			else
			{
				new m_iId = StringToInt(m_szId);
				g_iMenuBack[client]=g_eItems[m_iId][iParent];
				g_iSelectedItem[client] = m_iId;
				g_iSelectedPlan[client] = -1;
				
				if((g_eClients[target][iCredits]>=g_eItems[m_iId][iPrice] || g_eItems[m_iId][iPlans]>0 && g_eClients[target][iCredits]>=Store_GetLowestPrice(m_iId)) && !Store_HasClientItem(target, m_iId) && g_eItems[m_iId][iPrice] != -1)				{
					if(g_eItems[m_iId][iPlans] > 0)
					{
						DisplayPlanMenu(client, m_iId);
						return;
					}
					else
						if(g_eCvars[g_cvarConfirmation][aCache])
						{
							decl String:m_szTitle[128];
							Format(STRING(m_szTitle), "%t", "Confirm_Buy", g_eItems[m_iId][szName], g_eTypeHandlers[g_eItems[m_iId][iHandler]][szType]);
							Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 0);
							return;
						}
						else
							Store_BuyItem(target, m_iId);
				}
				
				if(g_eItems[m_iId][iHandler] != g_iPackageHandler)
				{				
					if(Store_HasClientItem(target, m_iId))
					{
						if(g_eTypeHandlers[g_eItems[m_iId][iHandler]][bRaw])
						{
							Call_StartFunction(g_eTypeHandlers[g_eItems[m_iId][iHandler]][hPlugin], g_eTypeHandlers[g_eItems[m_iId][iHandler]][fnUse]);
							Call_PushCell(target);
							Call_PushCell(m_iId);
							Call_Finish();
						}
						else
							DisplayItemMenu(client, m_iId);
					}
					else
						DisplayStoreMenu(client, g_iMenuBack[client]);					
				}
				else
				{			
					if(Store_HasClientItem(target, m_iId) || g_eItems[m_iId][iPrice] == -1)
						DisplayStoreMenu(client, m_iId);
					else
						DisplayStoreMenu(client, g_eItems[m_iId][iParent]);
				}
			}
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
}

public DisplayItemMenu(client, itemid)
{
	g_iMenuNum[client] = 1;
	g_iMenuBack[client] = g_eItems[itemid][iParent];
	new target = g_iMenuClient[client];

	new Handle:m_hMenu = CreateMenu(MenuHandler_Item);
	SetMenuExitBackButton(m_hMenu, true);
	
	new bool:m_bEquipped = Store_IsEquipped(target, itemid);
	new String:m_szTitle[256];
	new idx = 0;
	if(m_bEquipped)
		idx = Format(STRING(m_szTitle), "%t\n%t", "Item Equipped", g_eItems[itemid][szName], "Title Credits", g_eClients[target][iCredits]);
	else
		idx = Format(STRING(m_szTitle), "%s\n%t", g_eItems[itemid][szName], "Title Credits", g_eClients[target][iCredits]);

	new m_iExpiration = Store_GetExpiration(target, itemid);
	if(m_iExpiration != 0)
	{
		m_iExpiration = m_iExpiration-GetTime();
		new m_iDays = m_iExpiration/(24*60*60);
		new m_iHours = (m_iExpiration-m_iDays*24*60*60)/(60*60);
		Format(m_szTitle[idx-1], sizeof(m_szTitle)-idx-1, "\n%t", "Title Expiration", m_iDays, m_iHours);
	}
	
	SetMenuTitle(m_hMenu, m_szTitle);
	
	if(g_eTypeHandlers[g_eItems[itemid][iHandler]][bEquipable])
		if(!m_bEquipped)
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "0", "%t", "Item Equip");
		else
			AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "3", "%t", "Item Unequip");
	else
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "0", "%t", "Item Use");
		
	if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid))
	{
		new m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, itemid)*Float:g_eCvars[g_cvarSellRatio][aCache]);
		if(m_iCredits!=0)
		{
			new uid = Store_GetClientItemId(client, itemid);
			if(g_eClientItems[client][uid][iDateOfExpiration] != 0)
			{
				new m_iLength = g_eClientItems[client][uid][iDateOfExpiration]-g_eClientItems[client][uid][iDateOfPurchase];
				new m_iLeft = g_eClientItems[client][uid][iDateOfExpiration]-GetTime();
				if(m_iLeft < 0)
					m_iLeft = 0;
				m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
			}

			if(g_eCvars[g_cvarSellEnabled][aCache])
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "1", "%t", "Item Sell", m_iCredits);
			if(g_eCvars[g_cvarGiftEnabled][aCache] == 1 || (g_eCvars[g_cvarGiftEnabled][aCache] == 2 && GetUserFlagBits(client) & g_eCvars[g_cvarAdminFlag][aCache]))
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "2", "%t", "Item Gift");
		}
	}

	for(new i=0;i<g_iMenuHandlers;++i)
	{
		if(g_eMenuHandlers[i][hPlugin] == INVALID_HANDLE)
			continue;
		Call_StartFunction(g_eMenuHandlers[i][hPlugin], g_eMenuHandlers[i][fnMenu]);
		Call_PushCellRef(m_hMenu);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}
	
	DisplayMenu(m_hMenu, client, 0);
}

public DisplayPlanMenu(client, itemid)
{
	g_iMenuNum[client] = 1;
	new target = g_iMenuClient[client];

	new Handle:m_hMenu = CreateMenu(MenuHandler_Plan);
	SetMenuExitBackButton(m_hMenu, true);
	
	SetMenuTitle(m_hMenu, "%s\n%t", g_eItems[itemid][szName], "Title Credits", g_eClients[target][iCredits]);
	
	for(new i=0;i<g_eItems[itemid][iPlans];++i)
	{
		AddMenuItemEx(m_hMenu, (g_eClients[target][iCredits]>=g_ePlans[itemid][i][iPrice]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED), "", "%t",  "Item Available", g_ePlans[itemid][i][szName], g_ePlans[itemid][i][iPrice]);
	}
	
	DisplayMenu(m_hMenu, client, 0);
}

public MenuHandler_Plan(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		new target = g_iMenuClient[client];
		g_iSelectedPlan[client]=param2;
		g_iMenuNum[client]=5;

		if(g_eCvars[g_cvarConfirmation][aCache])
		{
			decl String:m_szTitle[128];
			Format(STRING(m_szTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]][szName], g_eTypeHandlers[g_eItems[g_iSelectedItem[client]][iHandler]][szType]);
			Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Store, 0);
			return;
		}
		else
		{
			Store_BuyItem(target, g_iSelectedItem[client], param2);
			DisplayItemMenu(client, g_iSelectedItem[client]);
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
}

public MenuHandler_Item(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		new target = g_iMenuClient[client];
		// Confirmation was sent
		if(menu == INVALID_HANDLE)
		{
			if(param2 == 0)
			{
				g_iMenuNum[client] = 1;
				Store_SellItem(target, g_iSelectedItem[client]);
				Store_DisplayPreviousMenu(client);
			}
		}
		else
		{
			decl String:m_szId[64];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			new m_iId = StringToInt(m_szId);
			
			// Menu handlers
			if(!(48 <= m_szId[0] <= 57))
			{
				decl ret;
				for(new i=0;i<g_iMenuHandlers;++i)
				{
					if(g_eMenuHandlers[i][hPlugin] == INVALID_HANDLE)
						continue;
					Call_StartFunction(g_eMenuHandlers[i][hPlugin], g_eMenuHandlers[i][fnHandler]);
					Call_PushCell(client);
					Call_PushString(m_szId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if(ret)
						break;
				}
			}
			// Player wants to equip this item
			else if(m_iId == 0)
			{
				new m_iRet = Store_UseItem(target, g_iSelectedItem[client]);
				if(GetClientMenu(client)==MenuSource_None && m_iRet == 0)
					DisplayItemMenu(client, g_iSelectedItem[client]);
			}
			// Player wants to sell this item
			else if(m_iId == 1)
			{
				if(g_eCvars[g_cvarConfirmation][aCache])
				{
					new m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, g_iSelectedItem[client])*Float:g_eCvars[g_cvarSellRatio][aCache]);
					new uid = Store_GetClientItemId(client, g_iSelectedItem[client]);
					if(g_eClientItems[client][uid][iDateOfExpiration] != 0)
					{
						new m_iLength = g_eClientItems[client][uid][iDateOfExpiration]-g_eClientItems[client][uid][iDateOfPurchase];
						new m_iLeft = g_eClientItems[client][uid][iDateOfExpiration]-GetTime();
						if(m_iLeft < 0)
							m_iLeft = 0;
						m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
					}

					decl String:m_szTitle[128];
					Format(STRING(m_szTitle), "%t", "Confirm_Sell", g_eItems[g_iSelectedItem[client]][szName], g_eTypeHandlers[g_eItems[g_iSelectedItem[client]][iHandler]][szType], m_iCredits);
					g_iMenuNum[client] = 2;
					Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Item, 0);
				}
				else
				{
					Store_SellItem(target, g_iSelectedItem[client]);
					Store_DisplayPreviousMenu(client);
				}
			}
			// Player wants to gift this item
			else if(m_iId == 2)
			{
				g_iMenuNum[client] = 2;
				DisplayPlayerMenu(client);
			}
			// Player wants to unequip this item
			else if(m_iId == 3)
			{
				Store_UnequipItem(target, g_iSelectedItem[client]);
				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			Store_DisplayPreviousMenu(client);
}

public DisplayPlayerMenu(client)
{
	g_iMenuNum[client] = 3;
	new target = g_iMenuClient[client];

	new m_iCount = 0;
	new Handle:m_hMenu = CreateMenu(MenuHandler_Gift);
	SetMenuExitBackButton(m_hMenu, true);
	SetMenuTitle(m_hMenu, "%t\n%t", "Title Gift", "Title Credits", g_eClients[client][iCredits]);
	
	decl String:m_szID[11];
	decl m_iFlags;
	LoopIngamePlayers(i)
	{
		m_iFlags = GetUserFlagBits(i);
		if(!GetClientPrivilege(i, g_eItems[g_iSelectedItem[client]][iFlagBits], m_iFlags))
			continue;
		if(i != target && IsClientInGame(i) && !Store_HasClientItem(i, g_iSelectedItem[client]))
		{
			IntToString(g_eClients[i][iUserId], STRING(m_szID));
			AddMenuItem(m_hMenu, m_szID, g_eClients[i][szName]);
			++m_iCount;
		}
	}
	
	if(m_iCount == 0)
	{
		CloseHandle(m_hMenu);
		g_iMenuNum[client] = 1;
		DisplayItemMenu(client, g_iSelectedItem[client]);
		Chat(client, "%t", "Gift No Players");
	}
	else
		DisplayMenu(m_hMenu, client, 0);
}

public MenuHandler_Gift(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		decl m_iItem, m_iReceiver;
		new target = g_iMenuClient[client];
	
		// Confirmation was given
		if(menu == INVALID_HANDLE)
		{
			m_iItem = Store_GetClientItemId(target, g_iSelectedItem[client]);
			m_iReceiver = GetClientOfUserId(param2);
			if(!m_iReceiver)
			{
				Chat(client, "%t", "Gift Player Left");
				return;
			}
			Store_GiftItem(target, m_iReceiver, m_iItem);
			g_iMenuNum[client] = 1;
			Store_DisplayPreviousMenu(client);
		}
		else
		{
			decl String:m_szId[11];
			GetMenuItem(menu, param2, STRING(m_szId));
			
			new m_iId = StringToInt(m_szId);
			m_iReceiver = GetClientOfUserId(m_iId);
			if(!m_iReceiver)
			{
				Chat(client, "%t", "Gift Player Left");
				return;
			}
				
			m_iItem = Store_GetClientItemId(target, g_iSelectedItem[client]);
			
			if(g_eCvars[g_cvarConfirmation][aCache])
			{
				decl String:m_szTitle[128];
				Format(STRING(m_szTitle), "%t", "Confirm_Gift", g_eItems[g_iSelectedItem[client]][szName], g_eTypeHandlers[g_eItems[g_iSelectedItem[client]][iHandler]][szType], g_eClients[m_iReceiver][szName]);
				Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_Gift, m_iId);
				return;
			}
			else
				Store_GiftItem(target, m_iReceiver, m_iItem);
			Store_DisplayPreviousMenu(client);
		}
	}
	else if(action==MenuAction_Cancel)
		if (param2 == MenuCancel_ExitBack)
			DisplayItemMenu(client, g_iSelectedItem[client]);
}

public MenuHandler_Confirm(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{		
		if(param2 == 0)
		{
			decl String:m_szCallback[32];
			decl String:m_szData[11];
			GetMenuItem(menu, 0, STRING(m_szCallback));
			GetMenuItem(menu, 1, STRING(m_szData));
			new m_iPos = FindCharInString(m_szCallback, '.');
			m_szCallback[m_iPos] = 0;
			new Handle:m_hPlugin = Handle:StringToInt(m_szCallback);
			new Function:fnMenuCallback = Function:StringToInt(m_szCallback[m_iPos+1]);
			if(fnMenuCallback != INVALID_FUNCTION)
			{
				Call_StartFunction(m_hPlugin, fnMenuCallback);
				Call_PushCell(INVALID_HANDLE);
				Call_PushCell(MenuAction_Select);
				Call_PushCell(client);
				Call_PushCell(StringToInt(m_szData));
				Call_Finish();
			}
			else
				Store_DisplayPreviousMenu(client);
		}
		else
		{
			Store_DisplayPreviousMenu(client);
		}
	}
}

//////////////////////////////
//			CONVARS	 		//
//////////////////////////////

public ConVar_CreditTimer(index)
{
	new m_bTimer = (FloatCompare(g_eCvars[g_cvarCreditTimer][aCache], 0.0)==0 || g_eCvars[g_cvarCreditAmountActive][aCache]==0);
	for(new i=1;i<=MaxClients;++i)
	{
		ClearTimer(g_eClients[i][hCreditTimer]);
		if(m_bTimer && IsClientInGame(i))
			g_eClients[i][hCreditTimer] = Store_CreditTimer(i);
	}
}

//////////////////////////////
//			TIMERS	 		//
//////////////////////////////

public GetMultipliedCredits(client, amount)
{
	new flags = GetUserFlagBits(client);
	new size = GetArraySize(g_hCustomCredits);
	new Float:multiplier = 1.0;
	for(new i=0;i<size;++i)
	{
		if(GetClientPrivilege(client, GetArrayCell(g_hCustomCredits, i, 0), flags))
		{
			new Float:mul = GetArrayCell(g_hCustomCredits, i, 1);

			if(multiplier < mul)
				multiplier = mul;
		}
	}

	return RoundFloat(amount * multiplier);
}

public Action:Timer_CreditTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	decl m_iCredits;
	new team = GetClientTeam(client);
	if(2<=team<=3)
		m_iCredits = g_eCvars[g_cvarCreditAmountActive][aCache];
	else
		m_iCredits = g_eCvars[g_cvarCreditAmountInactive][aCache];

	m_iCredits = GetMultipliedCredits(client, m_iCredits);

	if(m_iCredits)
	{
		g_eClients[client][iCredits] += m_iCredits;
		if(g_eCvars[g_cvarCreditMessages][aCache])
			Chat(client, "%t", "Credits Earned For Playing", m_iCredits);
		Store_LogMessage(client, m_iCredits, "Earned for playing");
	}

	return Plugin_Continue;
}

public Action:Timer_DatabaseTimeout(Handle:timer, any:userid)
{
	// Database is connected successfully
	if(g_hDatabase != INVALID_HANDLE)
		return Plugin_Stop;

	if(g_iDatabaseRetries < g_eCvars[g_cvarDatabaseRetries][aCache])
	{
		SQL_TConnect(SQLCallback_Connect, g_eCvars[g_cvarDatabaseEntry][sCache]);
		CreateTimer(Float:g_eCvars[g_cvarDatabaseTimeout][aCache], Timer_DatabaseTimeout);
		++g_iDatabaseRetries;
	}
	else
	{
		SetFailState("Database connection failed to initialize after %d retrie(s)", g_eCvars[g_cvarDatabaseRetries][aCache]);
	}


	return Plugin_Stop;
}

//////////////////////////////
//		SQL CALLBACKS		//
//////////////////////////////

public SQLCallback_Connect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl==INVALID_HANDLE)
	{
		SetFailState("Failed to connect to SQL database. Error: %s", error);
	}
	else
	{
		// If it's already connected we are good to go
		if(g_hDatabase != INVALID_HANDLE)
			return;
			
		g_hDatabase = hndl;
		decl String:m_szDriver[2];
		SQL_ReadDriver(g_hDatabase, STRING(m_szDriver));
		if(m_szDriver[0] == 'm')
		{
			g_bMySQL = true;
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_players` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `authid` varchar(32) NOT NULL,\
										  `name` varchar(64) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `date_of_join` int(11) NOT NULL,\
										  `date_of_last_join` int(11) NOT NULL,\
										  PRIMARY KEY (`id`),\
										  UNIQUE KEY `id` (`id`),\
										  UNIQUE KEY `authid` (`authid`)\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_items` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `date_of_purchase` int(11) NOT NULL,\
										  `date_of_expiration` int(11) NOT NULL,\
										  PRIMARY KEY (`id`)\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_equipment` (\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `slot` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_logs` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `reason` varchar(256) NOT NULL,\
										  `date` int(11) NOT NULL,\
										  PRIMARY KEY (`id`)\
										)");
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_items ADD COLUMN price_of_purchase int(11)");
			decl String:m_szQuery[512];
			Format(STRING(m_szQuery), "CREATE TABLE IF NOT EXISTS `%s` (\
										  `id` int(11) NOT NULL AUTO_INCREMENT,\
										  `parent_id` int(11) NOT NULL DEFAULT '-1',\
										  `item_price` int(32) NOT NULL,\
										  `item_type` varchar(64) NOT NULL,\
										  `item_flag` varchar(64) NOT NULL,\
										  `item_name` varchar(64) NOT NULL,\
										  `additional_info` text NOT NULL,\
										  `item_status` tinyint(1) NOT NULL,\
										  `supported_game` varchar(64) NOT NULL,\
										  PRIMARY KEY (`id`)\
										)", g_eCvars[g_cvarItemsTable][sCache]);
			SQL_TVoid(g_hDatabase, m_szQuery);
		}
		else
		{
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_players` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `authid` varchar(32) NOT NULL,\
										  `name` varchar(64) NOT NULL,\
										  `credits` int(11) NOT NULL,\
										  `date_of_join` int(11) NOT NULL,\
										  `date_of_last_join` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_items` (\
										  `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `date_of_purchase` int(11) NOT NULL,\
										  `date_of_expiration` int(11) NOT NULL\
										)");
			SQL_TVoid(g_hDatabase, "CREATE TABLE IF NOT EXISTS `store_equipment` (\
										  `player_id` int(11) NOT NULL,\
										  `type` varchar(16) NOT NULL,\
										  `unique_id` varchar(256) NOT NULL,\
										  `slot` int(11) NOT NULL\
										)");
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, "ALTER TABLE store_items ADD COLUMN price_of_purchase int(11)");
			if(strcmp(g_eCvars[g_cvarItemSource][sCache], "database")==0)
			{
	
				SetFailState("Database item source can only be used with MySQL databases");
			}
		}
		
		// Do some housekeeping
		decl String:m_szQuery[256];
		Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `date_of_expiration` <> 0 AND `date_of_expiration` < %d", GetTime());
		SQL_TVoid(g_hDatabase, m_szQuery);
	}
}

public SQLCallback_LoadClientInventory_Credits(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(!client)
			return;
		
		decl String:m_szQuery[256];
		decl String:m_szSteamID[32];
		new m_iTime = GetTime();
		g_eClients[client][iUserId] = userid;
		g_eClients[client][iItems] = -1;
		GetLegacyAuthString(client, STRING(m_szSteamID), false);
		strcopy(g_eClients[client][szAuthId], 32, m_szSteamID[8]);
		GetClientName(client, g_eClients[client][szName], 64);
		SQL_EscapeString(g_hDatabase, g_eClients[client][szName], g_eClients[client][szNameEscaped], 128);
		
		if(SQL_FetchRow(hndl))
		{
			g_eClients[client][iId] = SQL_FetchInt(hndl, 0);
			g_eClients[client][iCredits] = SQL_FetchInt(hndl, 3);
			g_eClients[client][iOriginalCredits] = SQL_FetchInt(hndl, 3);
			g_eClients[client][iDateOfJoin] = SQL_FetchInt(hndl, 4);
			g_eClients[client][iDateOfLastJoin] = m_iTime;
			
			Format(STRING(m_szQuery), "SELECT * FROM store_items WHERE `player_id`=%d", g_eClients[client][iId]);
			SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Items, m_szQuery, userid);

			Store_LogMessage(client, g_eClients[client][iCredits], "Amount of credits when the player joined");
			
			Store_SaveClientData(client);
		}
		else
		{
			Format(STRING(m_szQuery), "INSERT INTO store_players (`authid`, `name`, `credits`, `date_of_join`, `date_of_last_join`) VALUES(\"%s\", '%s', %d, %d, %d)",
						g_eClients[client][szAuthId], g_eClients[client][szNameEscaped], g_eCvars[g_cvarStartCredits][aCache], m_iTime, m_iTime);
			SQL_TQuery(g_hDatabase, SQLCallback_InsertClient, m_szQuery, userid);
			g_eClients[client][iCredits] = g_eCvars[g_cvarStartCredits][aCache];
			g_eClients[client][iOriginalCredits] = g_eCvars[g_cvarStartCredits][aCache];
			g_eClients[client][iDateOfJoin] = m_iTime;
			g_eClients[client][iDateOfLastJoin] = m_iTime;
			g_eClients[client][bLoaded] = true;
			g_eClients[client][iItems] = 0;

			if(g_eCvars[g_cvarStartCredits][aCache] > 0)
				Store_LogMessage(client, g_eCvars[g_cvarStartCredits][aCache], "Start credits");
		}
		
		g_eClients[client][hCreditTimer] = Store_CreditTimer(client);
	}
}

public SQLCallback_LoadClientInventory_Items(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{	
		new client = GetClientOfUserId(userid);
		if(!client)
			return;

		decl String:m_szQuery[256];
		Format(STRING(m_szQuery), "SELECT * FROM store_equipment WHERE `player_id`=%d", g_eClients[client][iId]);
		SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Equipment, m_szQuery, userid);

		if(!SQL_GetRowCount(hndl))
		{
			g_eClients[client][bLoaded] = true;
			g_eClients[client][iItems] = 0;
			return;
		}
		
		decl String:m_szUniqueId[PLATFORM_MAX_PATH];
		decl String:m_szType[16];
		decl m_iExpiration;
		decl m_iUniqueId;
		new m_iTime = GetTime();
		
		new i = 0;
		while(SQL_FetchRow(hndl))
		{
			m_iUniqueId = -1;
			m_iExpiration = SQL_FetchInt(hndl, 5);
			if(m_iExpiration && m_iExpiration<=m_iTime)
				continue;
			
			SQL_FetchString(hndl, 2, STRING(m_szType));
			SQL_FetchString(hndl, 3, STRING(m_szUniqueId));
			while((m_iUniqueId = Store_GetItemId(m_szType, m_szUniqueId, m_iUniqueId))!=-1)
			{
				g_eClientItems[client][i][iId] = SQL_FetchInt(hndl, 0);
				g_eClientItems[client][i][iUniqueId] = m_iUniqueId;
				g_eClientItems[client][i][bSynced] = true;
				g_eClientItems[client][i][bDeleted] = false;
				g_eClientItems[client][i][iDateOfPurchase] = SQL_FetchInt(hndl, 4);
				g_eClientItems[client][i][iDateOfExpiration] = m_iExpiration;
				g_eClientItems[client][i][iPriceOfPurchase] = SQL_FetchInt(hndl, 6);
			
				++i;
			}
		}
		g_eClients[client][iItems] = i;
	}
}

public SQLCallback_LoadClientInventory_Equipment(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(!client)
			return;
		
		decl String:m_szUniqueId[PLATFORM_MAX_PATH];
		decl String:m_szType[16];
		decl m_iUniqueId;
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 1, STRING(m_szType));
			SQL_FetchString(hndl, 2, STRING(m_szUniqueId));
			m_iUniqueId = Store_GetItemId(m_szType, m_szUniqueId);
			if(m_iUniqueId == -1)
				continue;
				
			if(!Store_HasClientItem(client, m_iUniqueId))
				Store_UnequipItem(client, m_iUniqueId);
			else
				Store_UseItem(client, m_iUniqueId, true, SQL_FetchInt(hndl, 3));
		}
		g_eClients[client][bLoaded] = true;
	}
}

public SQLCallback_RefreshCredits(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(!client)
			return;
			
		if(SQL_FetchRow(hndl))
		{
			g_eClients[client][iCredits] = SQL_FetchInt(hndl, 3);
			g_eClients[client][iOriginalCredits] = SQL_FetchInt(hndl, 3);
		}
	}
}

public SQLCallback_InsertClient(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);
		if(!client)
			return;
			
		g_eClients[client][iId] = SQL_GetInsertId(hndl);
	}
}

public SQLCallback_ReloadConfig(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
	{
		SetFailState("Error happened reading the config table. The plugin cannot continue.", error);
	}
	else
	{
		decl String:m_szType[64];
		decl String:m_szFlag[64];
		decl String:m_szInfo[2048];
		decl String:m_szKey[64];
		decl String:m_szValue[256];
		
		decl Handle:m_hKV;
		
		decl bool:m_bSuccess;
		
		decl m_iLength;
		decl m_iHandler;
		new m_iIndex = 0;
	
		while(SQL_FetchRow(hndl))
		{
			if(g_iItems == STORE_MAX_ITEMS)
				return;
				
			if(!SQL_FetchInt(hndl, 7))
				continue;
			
			g_eItems[g_iItems][iId] = SQL_FetchInt(hndl, 0);
			g_eItems[g_iItems][iParent] = SQL_FetchInt(hndl, 1);
			g_eItems[g_iItems][iPrice] = SQL_FetchInt(hndl, 2);
			
			IntToString(g_eItems[g_iItems][iId], g_eItems[g_iItems][szUniqueId], PLATFORM_MAX_PATH);
			
			SQL_FetchString(hndl, 3, STRING(m_szType));
			m_iHandler = Store_GetTypeHandler(m_szType);
			if(m_iHandler == -1)
				continue;
			
			g_eItems[g_iItems][iHandler] = m_iHandler;
			
			SQL_FetchString(hndl, 4, STRING(m_szFlag));
			g_eItems[g_iItems][iFlagBits] = ReadFlagString(m_szFlag);
			
			SQL_FetchString(hndl, 5, g_eItems[g_iItems][szName], ITEM_NAME_LENGTH);
			SQL_FetchString(hndl, 6, STRING(m_szInfo));
			
			m_hKV = CreateKeyValues("Additional Info");
			
			m_iLength = strlen(m_szInfo);
			while(m_iIndex != m_iLength)
			{
				m_iIndex += strcopy(m_szKey, StrContains(m_szInfo[m_iIndex], "="), m_szInfo[m_iIndex])+2;
				m_iIndex += strcopy(m_szValue, StrContains(m_szInfo[m_iIndex], "\";"), m_szInfo[m_iIndex])+2; // \"
				
				KvJumpToKey(m_hKV, m_szKey, true);
				KvSetString(m_hKV, m_szKey, m_szValue);
				
				m_bSuccess = true;
				if(g_eTypeHandlers[m_iHandler][fnConfig]!=INVALID_FUNCTION)
				{
					Call_StartFunction(g_eTypeHandlers[m_iHandler][hPlugin], g_eTypeHandlers[m_iHandler][fnConfig]);
					Call_PushCellRef(m_hKV);
					Call_PushCell(g_iItems);
					Call_Finish(m_bSuccess); 
				}
				
				if(m_bSuccess)
					++g_iItems;
			}
			CloseHandle(m_hKV);
		}
	}
}

public SQLCallback_ResetPlayer(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl==INVALID_HANDLE)
		LogError("Error happened. Error: %s", error);
	else
	{
		new client = GetClientOfUserId(userid);

		if(SQL_GetRowCount(hndl))
		{
			SQL_FetchRow(hndl);
			new id = SQL_FetchInt(hndl, 0);
			decl String:m_szAuthId[32];
			SQL_FetchString(hndl, 1, STRING(m_szAuthId));

			decl String:m_szQuery[512];
			Format(STRING(m_szQuery), "DELETE FROM store_players WHERE id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);
			Format(STRING(m_szQuery), "DELETE FROM store_items WHERE player_id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);
			Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE player_id=%d", id);
			SQL_TVoid(g_hDatabase, m_szQuery);

			ChatAll("%t", "Player Resetted", m_szAuthId);

		}
		else
			if(client)
				Chat(client, "%t", "Credit No Match");
	}
}

//////////////////////////////
//			STOCKS			//
//////////////////////////////

public Store_LoadClientInventory(client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	decl String:m_szQuery[256];
	decl String:m_szAuthId[32];

	GetLegacyAuthString(client, STRING(m_szAuthId));
	if(m_szAuthId[0] == 0)
		return;

	Format(STRING(m_szQuery), "SELECT * FROM store_players WHERE `authid`=\"%s\"", m_szAuthId[8]);

	SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Credits, m_szQuery, g_eClients[client][iUserId]);
}

public Store_SaveClientInventory(client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	// Player disconnected before his inventory was even fetched
	if(g_eClients[client][iCredits]==-1 && g_eClients[client][iItems]==-1)
		return;
	
	decl String:m_szQuery[256];
	decl String:m_szType[16];
	decl String:m_szUniqueId[PLATFORM_MAX_PATH];
	
	for(new i=0;i<g_eClients[client][iItems];++i)
	{
		strcopy(STRING(m_szType), g_eTypeHandlers[g_eItems[g_eClientItems[client][i][iUniqueId]][iHandler]][szType]);
		strcopy(STRING(m_szUniqueId), g_eItems[g_eClientItems[client][i][iUniqueId]][szUniqueId]);
	
		if(!g_eClientItems[client][i][bSynced] && !g_eClientItems[client][i][bDeleted])
		{
			g_eClientItems[client][i][bSynced] = true;
			Format(STRING(m_szQuery), "INSERT INTO store_items (`player_id`, `type`, `unique_id`, `date_of_purchase`, `date_of_expiration`, `price_of_purchase`) VALUES(%d, \"%s\", \"%s\", %d, %d, %d)", g_eClients[client][iId], m_szType, m_szUniqueId, g_eClientItems[client][i][iDateOfPurchase], g_eClientItems[client][i][iDateOfExpiration], g_eClientItems[client][i][iPriceOfPurchase]);
			SQL_TVoid(g_hDatabase, m_szQuery);
		} else if(g_eClientItems[client][i][bSynced] && g_eClientItems[client][i][bDeleted])
		{
			// Might have been synced already but ID wasn't acquired
			if(g_eClientItems[client][i][iId]==-1)
				Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `player_id`=%d AND `type`=\"%s\" AND `unique_id`=\"%s\"", g_eClients[client][iId], m_szType, m_szUniqueId);
			else
				Format(STRING(m_szQuery), "DELETE FROM store_items WHERE `id`=%d", g_eClientItems[client][i][iId]);
			SQL_TVoid(g_hDatabase, m_szQuery);
		}
	}
}

public Store_SaveClientEquipment(client)
{
	decl String:m_szQuery[256];
	decl m_iId;
	for(new i=0;i<STORE_MAX_HANDLERS;++i)
	{
		for(new a=0;a<STORE_MAX_SLOTS;++a)
		{
			m_iId = i*STORE_MAX_SLOTS+a;
			if(g_eClients[client][aEquipmentSynced][m_iId] == g_eClients[client][aEquipment][m_iId])
				continue;
			else if(g_eClients[client][aEquipmentSynced][m_iId] != -2)
				if(g_eClients[client][aEquipment][m_iId]==-1)
					Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", g_eClients[client][iId], g_eTypeHandlers[i][szType], a);
				else
					Format(STRING(m_szQuery), "UPDATE store_equipment SET `unique_id`=\"%s\" WHERE `player_id`=%d AND `type`=\"%s\" AND `slot`=%d", g_eItems[g_eClients[client][aEquipment][m_iId]][szUniqueId], g_eClients[client][iId], g_eTypeHandlers[i][szType], a);
				
			else
				Format(STRING(m_szQuery), "INSERT INTO store_equipment (`player_id`, `type`, `unique_id`, `slot`) VALUES(%d, \"%s\", \"%s\", %d)", g_eClients[client][iId], g_eTypeHandlers[i][szType], g_eItems[g_eClients[client][aEquipment][m_iId]][szUniqueId], a);

			SQL_TVoid(g_hDatabase, m_szQuery);
			g_eClients[client][aEquipmentSynced][m_iId] = g_eClients[client][aEquipment][m_iId];
		}
	}
}

public Store_SaveClientData(client)
{
	if(g_hDatabase == INVALID_HANDLE)
	{
		LogError("Database connection is lost or not yet initialized.");
		return;
	}
	
	if((g_eClients[client][iCredits]==-1 && g_eClients[client][iItems]==-1) || !g_eClients[client][bLoaded])
		return;
	
	decl String:m_szQuery[256];
	if(g_bMySQL)
		Format(STRING(m_szQuery), "UPDATE store_players SET `credits`=GREATEST(`credits`+%d,0), `date_of_last_join`=%d, `name`='%s' WHERE `id`=%d", g_eClients[client][iCredits]-g_eClients[client][iOriginalCredits], g_eClients[client][iDateOfLastJoin], g_eClients[client][szNameEscaped], g_eClients[client][iId]);
	else
		Format(STRING(m_szQuery), "UPDATE store_players SET `credits`=MAX(`credits`+%d,0), `date_of_last_join`=%d, `name`='%s' WHERE `id`=%d", g_eClients[client][iCredits]-g_eClients[client][iOriginalCredits], g_eClients[client][iDateOfLastJoin], g_eClients[client][szNameEscaped], g_eClients[client][iId]);

	g_eClients[client][iOriginalCredits] = g_eClients[client][iCredits];

	SQL_TVoid(g_hDatabase, m_szQuery);
}

public Store_DisconnectClient(client)
{
	Store_LogMessage(client, g_eClients[client][iCredits], "Amount of credits when the player left");
	g_eClients[client][iCredits] = -1;
	g_eClients[client][iOriginalCredits] = -1;
	g_eClients[client][iItems] = -1;
	g_eClients[client][bLoaded] = false;
	ClearTimer(g_eClients[client][hCreditTimer]);
}

Store_GetItemId(String:type[], String:uid[], start=-1)
{
	for(new i=start+1;i<g_iItems;++i)
		if(strcmp(g_eTypeHandlers[g_eItems[i][iHandler]][szType], type)==0 && strcmp(g_eItems[i][szUniqueId], uid)==0 && g_eItems[i][iPrice] >= 0)
			return i;
	return -1;
}

Store_BuyItem(client, itemid, plan=-1)
{
	if(Store_HasClientItem(client, itemid))
		return;
	
	new m_iPrice = 0;
	if(plan==-1)
		m_iPrice = g_eItems[itemid][iPrice];
	else
		m_iPrice = g_ePlans[itemid][plan][iPrice];	

	if(g_eClients[client][iCredits]<m_iPrice)
		return;
		
	new m_iId = g_eClients[client][iItems]++;
	g_eClientItems[client][m_iId][iId] = -1;
	g_eClientItems[client][m_iId][iUniqueId] = itemid;
	g_eClientItems[client][m_iId][iDateOfPurchase] = GetTime();
	g_eClientItems[client][m_iId][iDateOfExpiration] = (plan==-1?0:(g_ePlans[itemid][plan][iTime]?GetTime()+g_ePlans[itemid][plan][iTime]:0));
	g_eClientItems[client][m_iId][iPriceOfPurchase] = m_iPrice;
	g_eClientItems[client][m_iId][bSynced] = false;
	g_eClientItems[client][m_iId][bDeleted] = false;
	
	g_eClients[client][iCredits] -= m_iPrice;

	Store_LogMessage(client, -g_eItems[itemid][iPrice], "Bought a %s %s", g_eItems[itemid][szName], g_eTypeHandlers[g_eItems[itemid][iHandler]][szType]);
	
	Chat(client, "%t", "Chat Bought Item", g_eItems[itemid][szName], g_eTypeHandlers[g_eItems[itemid][iHandler]][szType]);
}

public Store_SellItem(client, itemid)
{	
	new m_iCredits = RoundToFloor(Store_GetClientItemPrice(client, itemid)*Float:g_eCvars[g_cvarSellRatio][aCache]);
	new uid = Store_GetClientItemId(client, itemid);
	if(g_eClientItems[client][uid][iDateOfExpiration] != 0)
	{
		new m_iLength = g_eClientItems[client][uid][iDateOfExpiration]-g_eClientItems[client][uid][iDateOfPurchase];
		new m_iLeft = g_eClientItems[client][uid][iDateOfExpiration]-GetTime();
		if(m_iLeft<0)
			m_iLeft = 0;
		m_iCredits = RoundToCeil(m_iCredits*float(m_iLeft)/float(m_iLength));
	}

	g_eClients[client][iCredits] += m_iCredits;
	Chat(client, "%t", "Chat Sold Item", g_eItems[itemid][szName], g_eTypeHandlers[g_eItems[itemid][iHandler]][szType]);
	
	Store_LogMessage(client, m_iCredits, "Sold a %s %s", g_eItems[itemid][szName], g_eTypeHandlers[g_eItems[itemid][iHandler]][szType]);

	Store_RemoveItem(client, itemid);
}

public Store_GiftItem(client, receiver, item)
{
	new m_iId = g_eClientItems[client][item][iUniqueId];
	new target = g_iMenuClient[client];
	g_eClientItems[client][item][bDeleted] = true;
	Store_UnequipItem(client, m_iId);

	g_eClientItems[receiver][g_eClients[receiver][iItems]][iId] = -1;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iUniqueId] = m_iId;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][bSynced] = false;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][bDeleted] = false;
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iDateOfPurchase] = g_eClientItems[target][item][iDateOfPurchase];
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iDateOfExpiration] = g_eClientItems[target][item][iDateOfExpiration];
	g_eClientItems[receiver][g_eClients[receiver][iItems]][iPriceOfPurchase] = g_eClientItems[target][item][iPriceOfPurchase];
	
	++g_eClients[receiver][iItems];

	Chat(client, "%t", "Chat Gift Item Sent", g_eClients[receiver][szName], g_eItems[m_iId][szName], g_eTypeHandlers[g_eItems[m_iId][iHandler]][szType]);
	Chat(receiver, "%t", "Chat Gift Item Received", g_eClients[target][szName], g_eItems[m_iId][szName], g_eTypeHandlers[g_eItems[m_iId][iHandler]][szType]);

	Store_LogMessage(client, 0, "Gifted a %s to %N", g_eItems[m_iId][szName], receiver);
}

public Store_GetClientItemId(client, itemid)
{
	for(new i=0;i<g_eClients[client][iItems];++i)
	{
		if(g_eClientItems[client][i][iUniqueId] == itemid && !g_eClientItems[client][i][bDeleted])
			return i;
	}
		
	return -1;
}

public Handle:Store_CreditTimer(client)
{
	return CreateTimer(g_eCvars[g_cvarCreditTimer][aCache], Timer_CreditTimer, g_eClients[client][iUserId], TIMER_REPEAT);
}

public ReadCoreCFG()
{
	new String:m_szFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, STRING(m_szFile), "configs/core.cfg");

	new Handle:hParser = SMC_CreateParser();
	new String:error[128];
	new line = 0;
	new col = 0;

	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(hParser, Config_End);

	new SMCError:result = SMC_ParseFile(hParser, m_szFile, line, col);
	CloseHandle(hParser);

	if (result != SMCError_Okay) 
	{
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, m_szFile);
	}

}

public SMCResult:Config_NewSection(Handle:parser, const String:section[], bool:quotes) 
{
    if (StrEqual(section, "Core"))
    {
        return SMCParse_Continue;
    }
    return SMCParse_Continue;
}

public SMCResult:Config_KeyValue(Handle:parser, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
    if(StrEqual(key, "PublicChatTrigger", false))
        PublicChatTrigger = value[0];
    else if(StrEqual(key, "SilentChatTrigger", false))
        SilentChatTrigger = value[0];
    
    return SMCParse_Continue;
}

public SMCResult:Config_EndSection(Handle:parser) 
{
    return SMCParse_Continue;
}

public Config_End(Handle:parser, bool:halted, bool:failed) 
{
}  

public Store_ReloadConfig()
{
	g_iItems = 0;
	
	for(new i=0;i<g_iTypeHandlers;++i)
	{
		if(g_eTypeHandlers[i][fnReset] != INVALID_FUNCTION)
		{
			Call_StartFunction(g_eTypeHandlers[i][hPlugin], g_eTypeHandlers[i][fnReset]);
			Call_Finish();
		}
	}

	if(strcmp(g_eCvars[g_cvarItemSource][sCache], "database")==0)
	{
		decl String:m_szQuery[64];
		Format(STRING(m_szQuery), "SELECT * FROM %s WHERE supported_games LIKE \"%%%s%%\" OR supported_games = \"\"", g_eCvars[g_cvarItemsTable][sCache], g_szGameDir);
		SQL_TQuery(g_hDatabase, SQLCallback_ReloadConfig, m_szQuery);
	}
	else
	{	
		new String:m_szFile[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, STRING(m_szFile), "configs/store/items.txt");
		new Handle:m_hKV = CreateKeyValues("Store");
		FileToKeyValues(m_hKV, m_szFile);
		if (!KvGotoFirstSubKey(m_hKV))
		{
			
			SetFailState("Failed to read configs/store/items.txt");
		}
		Store_WalkConfig(m_hKV);
		CloseHandle(m_hKV);
	}
}

Store_WalkConfig(&Handle:kv, parent=-1)
{
	decl String:m_szType[32];
	decl String:m_szGame[64];
	decl String:m_szFlags[64];
	decl m_iHandler;
	decl bool:m_bSuccess;
	do
	{
		if(g_iItems == STORE_MAX_ITEMS)
				continue;
		if (KvGetNum(kv, "enabled", 1) && KvGetNum(kv, "type", -1)==-1 && KvGotoFirstSubKey(kv))
		{
			KvGoBack(kv);
			KvGetSectionName(kv, g_eItems[g_iItems][szName], 64);
			KvGetSectionName(kv, g_eItems[g_iItems][szUniqueId], 64);
			ReplaceString(g_eItems[g_iItems][szName], 64, "\\n", "\n");
			KvGetString(kv, "shortcut", g_eItems[g_iItems][szShortcut], 64);
			KvGetString(kv, "flag", STRING(m_szFlags));
			KvGetString(kv, "games", STRING(m_szGame));
			if(m_szGame[0] != 0 && StrContains(m_szGame, g_szGameDir)==-1)
				continue;
			g_eItems[g_iItems][iFlagBits] = ReadFlagString(m_szFlags);
			g_eItems[g_iItems][iPrice] = KvGetNum(kv, "price", -1);
			g_eItems[g_iItems][bBuyable] = (KvGetNum(kv, "buyable", 1)?true:false);
			g_eItems[g_iItems][bIgnoreVIP] = (KvGetNum(kv, "ignore_vip", 0)?true:false);
			g_eItems[g_iItems][iHandler] = g_iPackageHandler;
			KvGotoFirstSubKey(kv);
			
			g_eItems[g_iItems][iParent] = parent;
			
			Store_WalkConfig(kv, g_iItems++);
			KvGoBack(kv);
		}
		else
		{
			if(!KvGetNum(kv, "enabled", 1))
				continue;

			KvGetString(kv, "games", STRING(m_szGame));
			if(m_szGame[0] != 0 && StrContains(m_szGame, g_szGameDir)==-1)
				continue;
				
			g_eItems[g_iItems][iParent] = parent;
			KvGetSectionName(kv, g_eItems[g_iItems][szName], ITEM_NAME_LENGTH);
			g_eItems[g_iItems][iPrice] = KvGetNum(kv, "price");
			g_eItems[g_iItems][bBuyable] = KvGetNum(kv, "buyable", 1)?true:false;
			g_eItems[g_iItems][bIgnoreVIP] = (KvGetNum(kv, "ignore_vip", 0)?true:false);

			
			KvGetString(kv, "type", STRING(m_szType));
			m_iHandler = Store_GetTypeHandler(m_szType);
			if(m_iHandler == -1)
				continue;

			KvGetString(kv, "flag", STRING(m_szFlags));
			g_eItems[g_iItems][iFlagBits] = ReadFlagString(m_szFlags);
			g_eItems[g_iItems][iHandler] = m_iHandler;
			
			if(KvGetNum(kv, "unique_id", -1)==-1)
				KvGetString(kv, g_eTypeHandlers[m_iHandler][szUniqueKey], g_eItems[g_iItems][szUniqueId], PLATFORM_MAX_PATH);
			else
				KvGetString(kv, "unique_id", g_eItems[g_iItems][szUniqueId], PLATFORM_MAX_PATH);

			if(KvJumpToKey(kv, "Plans"))
			{
				KvGotoFirstSubKey(kv);
				new index=0;
				do
				{
					KvGetSectionName(kv, g_ePlans[g_iItems][index][szName], ITEM_NAME_LENGTH);
					g_ePlans[g_iItems][index][iPrice] = KvGetNum(kv, "price");
					g_ePlans[g_iItems][index][iTime] = KvGetNum(kv, "time");
					++index;
				} while (KvGotoNextKey(kv));

				g_eItems[g_iItems][iPlans]=index;

				KvGoBack(kv);
				KvGoBack(kv);
			}

			if(g_eItems[g_iItems][hAttributes])
				CloseHandle(g_eItems[g_iItems][hAttributes]);
			g_eItems[g_iItems][hAttributes] = INVALID_HANDLE;
			if(KvJumpToKey(kv, "Attributes"))
			{
				g_eItems[g_iItems][hAttributes] = CreateTrie();

				KvGotoFirstSubKey(kv, false);

				new String:m_szAttribute[64];
				new String:m_szValue[64];
				do
				{
					KvGetSectionName(kv, STRING(m_szAttribute));
					KvGetString(kv, NULL_STRING, STRING(m_szValue));
					SetTrieString(g_eItems[g_iItems][hAttributes], m_szAttribute, m_szValue);
				} while (KvGotoNextKey(kv, false));

				KvGoBack(kv);
				KvGoBack(kv);
			}
			
			m_bSuccess = true;
			if(g_eTypeHandlers[m_iHandler][fnConfig]!=INVALID_FUNCTION)
			{
				Call_StartFunction(g_eTypeHandlers[m_iHandler][hPlugin], g_eTypeHandlers[m_iHandler][fnConfig]);
				Call_PushCellRef(kv);
				Call_PushCell(g_iItems);
				Call_Finish(m_bSuccess); 
			}
			
			if(m_bSuccess)
				++g_iItems;
		}
	} while (KvGotoNextKey(kv));
}

public Store_GetTypeHandler(String:type[])
{
	for(new i=0;i<g_iTypeHandlers;++i)
	{
		if(strcmp(g_eTypeHandlers[i][szType], type)==0)
			return i;
	}
	return -1;
}

public Store_GetMenuHandler(String:id[])
{
	for(new i=0;i<g_iMenuHandlers;++i)
	{
		if(strcmp(g_eMenuHandlers[i][szIdentifier], id)==0)
			return i;
	}
	return -1;
}

public bool:Store_IsEquipped(client, itemid)
{
	for(new i=0;i<STORE_MAX_SLOTS;++i)
		if(g_eClients[client][aEquipment][g_eItems[itemid][iHandler]*STORE_MAX_SLOTS+i] == itemid)
			return true;
	return false;
}

public Store_GetExpiration(client, itemid)
{
	new uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;
	return g_eClientItems[client][uid][iDateOfExpiration];
}

Store_UseItem(client, itemid, bool:synced=false, slot=0)
{
	new m_iSlot = slot;
	if(g_eTypeHandlers[g_eItems[itemid][iHandler]][fnUse] != INVALID_FUNCTION)
	{
		new m_iReturn = -1;
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid][iHandler]][hPlugin], g_eTypeHandlers[g_eItems[itemid][iHandler]][fnUse]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(m_iReturn);
		
		if(m_iReturn != -1)
			m_iSlot = m_iReturn;
	}

	if(g_eTypeHandlers[g_eItems[itemid][iHandler]][bEquipable])
	{
		g_eClients[client][aEquipment][g_eItems[itemid][iHandler]*STORE_MAX_SLOTS+m_iSlot]=itemid;
		if(synced)
			g_eClients[client][aEquipmentSynced][g_eItems[itemid][iHandler]*STORE_MAX_SLOTS+m_iSlot]=itemid;
	}
	else if(m_iSlot == 0)
	{
		Store_RemoveItem(client, itemid);
		return 1;
	}
	return 0;
}

Store_UnequipItem(client, itemid, bool:fn=true)
{
	new m_iSlot = 0;
	if(fn && itemid > 0 && g_eTypeHandlers[g_eItems[itemid][iHandler]][fnRemove] != INVALID_FUNCTION)
	{
		Call_StartFunction(g_eTypeHandlers[g_eItems[itemid][iHandler]][hPlugin], g_eTypeHandlers[g_eItems[itemid][iHandler]][fnRemove]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(m_iSlot);
	}

	decl m_iId;
	if(g_eItems[itemid][iHandler] != g_iPackageHandler)
	{
		m_iId = g_eItems[itemid][iHandler]*STORE_MAX_SLOTS+m_iSlot;
		if(g_eClients[client][aEquipmentSynced][m_iId]==-2)
			g_eClients[client][aEquipment][m_iId]=-2;
		else
			g_eClients[client][aEquipment][m_iId]=-1;
	}
	else
	{
		for(new i=0;i<STORE_MAX_HANDLERS;++i)
		{
			for(new a=0;i<STORE_MAX_SLOTS;++i)
			{
				if(g_eClients[client][aEquipment][i+a] < 0)
					continue;
				m_iId = i*STORE_MAX_SLOTS+a;
				if(Store_IsItemInBoughtPackage(client, g_eClients[client][aEquipment][m_iId], itemid))
					if(g_eClients[client][aEquipmentSynced][m_iId]==-2)
						g_eClients[client][aEquipment][m_iId]=-2;
					else
						g_eClients[client][aEquipment][m_iId]=-1;
			}
		}
	}
}

Store_GetEquippedItemFromHandler(client, handler, slot=0)
{
	return g_eClients[client][aEquipment][handler*STORE_MAX_SLOTS+slot];
}

Store_PackageHasClientItem(client, packageid, bool:invmode=false)
{
	new m_iFlags = GetUserFlagBits(client);
	if(!g_eCvars[g_cvarShowVIP][aCache] && !GetClientPrivilege(client, g_eItems[packageid][iFlagBits], m_iFlags))
		return false;
	for(new i=0;i<g_iItems;++i)
		if(g_eItems[i][iParent] == packageid && (g_eCvars[g_cvarShowVIP][aCache] || GetClientPrivilege(client, g_eItems[i][iFlagBits], m_iFlags)) && (invmode && Store_HasClientItem(client, i) || !invmode))
			if((g_eItems[i][iHandler] == g_iPackageHandler && Store_PackageHasClientItem(client, i, invmode)) || g_eItems[i][iHandler] != g_iPackageHandler)
				return true;
	return false;
}

Store_LogMessage(client, credits, const String:message[], ...)
{
	if(!g_eCvars[g_cvarLogging][aCache])
		return;

	decl String:m_szReason[256];
	VFormat(STRING(m_szReason), message, 4);

	if(g_eCvars[g_cvarLogging][aCache] == 1)
	{
		LogToOpenFileEx(g_hLogFile, "%N's credits have changed by %d. Reason: %s", client, credits, m_szReason);
	} else if(g_eCvars[g_cvarLogging][aCache] == 2)
	{
		decl String:m_szQuery[256];
		Format(STRING(m_szQuery), "INSERT INTO store_logs (player_id, credits, reason, date) VALUES(%d, %d, \"%s\", %d)", g_eClients[client][iId], credits, m_szReason, GetTime());
		SQL_TVoid(g_hDatabase, m_szQuery);
	}
}

Store_GetLowestPrice(itemid)
{
	if(g_eItems[itemid][iPlans]==0)
		return g_eItems[itemid][iPrice];

	new m_iLowest=g_ePlans[itemid][0][iPrice];
	for(new i=1;i<g_eItems[itemid][iPlans];++i)
	{
		if(m_iLowest>g_ePlans[itemid][i][iPrice])
			m_iLowest = g_ePlans[itemid][i][iPrice];
	}
	return m_iLowest;
}

Store_GetClientItemPrice(client, itemid)
{
	new uid = Store_GetClientItemId(client, itemid);
	if(uid<0)
		return 0;
		
	if(g_eClientItems[client][uid][iPriceOfPurchase]==0)
		return g_eItems[itemid][iPrice];

	return g_eClientItems[client][uid][iPriceOfPurchase];
}

public Store_OnPaymentReceived(FriendID, quanity, Handle:data)
{
	LoopIngamePlayers(i)
	{
		if(GetFriendID(i)==FriendID)
		{
			Store_SaveClientData(i);

			new m_unMod = FriendID % 2;
			new m_unAccountID = (FriendID-m_unMod)/2;

			decl String:m_szQuery[256];
			Format(STRING(m_szQuery), "SELECT * FROM store_players WHERE `authid`=\"%d:%d\"", m_unMod, m_unAccountID);
			SQL_TQuery(g_hDatabase, SQLCallback_LoadClientInventory_Credits, m_szQuery, GetClientUserId(i));
			break;
		}
	}
}
