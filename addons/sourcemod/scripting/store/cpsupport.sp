#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#include <chat-processor>
#endif

new String:g_szNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
new String:g_szNameColors[STORE_MAX_ITEMS][32];
new String:g_szMessageColors[STORE_MAX_ITEMS][32];

new g_iNameTags = 0;
new g_iNameColors = 0;
new g_iMessageColors = 0;

#if defined STANDALONE_BUILD
public OnPluginStart()
#else
public CPSupport_OnPluginStart()
#endif
{	
	if(FindPluginByFile("chat-processor.smx")==INVALID_HANDLE)
	{
		LogError("Chat-Processor isn't installed or failed to load. Chat-Processor support will be disabled. (https://forums.alliedmods.net/showthread.php?t=286913)");
		return;
	}

	Store_RegisterHandler("nametag", "tag", CPSupport_OnMappStart, CPSupport_Reset, NameTags_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("namecolor", "color", CPSupport_OnMappStart, CPSupport_Reset, NameColors_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("msgcolor", "color", CPSupport_OnMappStart, CPSupport_Reset, MsgColors_Config, CPSupport_Equip, CPSupport_Remove, true);
}

public CPSupport_OnMappStart()
{
}

public CPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
}

public NameTags_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iNameTags);
	KvGetString(kv, "tag", g_szNameTags[g_iNameTags], sizeof(g_szNameTags[]));
	++g_iNameTags;
	
	return true;
}

public NameColors_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iNameColors);
	KvGetString(kv, "color", g_szNameColors[g_iNameColors], sizeof(g_szNameColors[]));
	++g_iNameColors;
	
	return true;
}

public MsgColors_Config(&Handle:kv, itemid)
{
	Store_SetDataIndex(itemid, g_iMessageColors);
	KvGetString(kv, "color", g_szMessageColors[g_iMessageColors], sizeof(g_szMessageColors[]));
	++g_iMessageColors;
	
	return true;
}

public CPSupport_Equip(client, id)
{
	return -1;
}

public CPSupport_Remove(client, id)
{
}

public Action:OnChatMessage(int& client, ArrayList recipients, eChatFlags& flag, char[] name, char[] message, bool& bProcessColors, bool& bRemoveColors)
{
	new m_iEquippedNameTag = Store_GetEquippedItem(client, "nametag");
	new m_iEquippedNameColor = Store_GetEquippedItem(client, "namecolor");
	new m_iEquippedMsgColor = Store_GetEquippedItem(client, "msgcolor");
	
	if(m_iEquippedNameTag < 0 && m_iEquippedNameColor < 0 && m_iEquippedMsgColor < 0)
		return Plugin_Continue;
	
	new String:m_szName[MAXLENGTH_NAME*2];
	new String:m_szNameTag[MAXLENGTH_NAME];
	new String:m_szNameColor[32];
	
	if(m_iEquippedNameTag >= 0)
	{
		new m_iNameTag = Store_GetDataIndex(m_iEquippedNameTag);
		strcopy(STRING(m_szNameTag), g_szNameTags[m_iNameTag]);
	}
	if(m_iEquippedNameColor >= 0)
	{
		new m_iNameColor = Store_GetDataIndex(m_iEquippedNameColor);
		strcopy(STRING(m_szNameColor), g_szNameColors[m_iNameColor]);
	}
	Format(STRING(m_szName), "%s%s%s", m_szNameTag, m_szNameColor, name);
	ReplaceColors(STRING(m_szName), client);
	strcopy(name, MAXLENGTH_NAME, m_szName);

	if(m_iEquippedMsgColor >= 0)
	{
		new String:m_szMessage[MAXLENGTH_INPUT];
		strcopy(STRING(m_szMessage), message);
		Format(message, MAXLENGTH_INPUT, "%s%s", g_szMessageColors[Store_GetDataIndex(m_iEquippedMsgColor)], m_szMessage);
		ReplaceColors(message, MAXLENGTH_INPUT, client);
	}

	return Plugin_Changed;
}