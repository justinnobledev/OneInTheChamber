#pragma semicolon 1

#define PLUGIN_AUTHOR "R3TROATTACK (http://steamcommunity.com/id/R3TROATTACK/)"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

EngineVersion g_Game;
ConVar g_cVersion;
ConVar g_cKillsToWin;
ConVar g_cKnifePunishmet;

int g_iFragsOffset = -1;

public Plugin myinfo = 
{
	name = "One in the Chamber",
	author = PLUGIN_AUTHOR,
	description = "One in the chamber gamemode",
	version = PLUGIN_VERSION,
	url = "https://github.com/R3TROATTACK"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
		SetFailState("This plugin is for CSGO only.");
	
	g_cVersion = CreateConVar("otc_version", PLUGIN_VERSION, "One in the Chambers Version do not change", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cKillsToWin = CreateConVar("otc_killstowin", "20", "How many kills are required for someone to win", FCVAR_NONE, true, 1.0);
	g_cKnifePunishmet = CreateConVar("otc_knife_penalty", "1", "How many kills are removed for being knifed?");
	
	AutoExecConfig(true, "OneInTheChamber");
	
	if(g_cKillsToWin != null)
		g_cKillsToWin.AddChangeHook(OTCCvarChanged);
		
	if((g_iFragsOffset = FindSendPropOffs("CSSPlayer", "m_iFrags")) == -1)
		SetFailState("[OTC] Could not find offset \"m_iFrags\"");
	
	HookEvent("player_hurt", Event_PlayerHurtPre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("item_pickup", Event_ItemPickupPre, EventHookMode_Pre);
}

public void OnMapStart()
{
	FindConVar("mp_teammates_are_enmies").SetInt(1);
}

public void OTCCvarChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if(g_cKillsToWin.IntValue < 1)
		g_cKillsToWin.SetInt(1);
}

public Action Event_ItemPickupPre(Event event, const char[] name, bool dontBroadcast)
{
	char sItem[32];
	event.GetString("item", sItem, 32);
	
	if(!StrEqual(sItem, "weapon_revolver", false) && !StrEqual(sItem, "weapon_knife", false))
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	StripClientWeapons(client);
	GivePlayerItem(client, "weapon_knife");
	GivePlayerItem(client, "weapon_revolver");
}

public Action Event_PlayerHurtPre(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	char sWeapon[32];
	event.GetString("weapon", sWeapon, 32);
	
	if(!StrEqual(sWeapon, "weapon_revolver", false) && attacker != 0 && !StrEqual(sWeapon, "weapon_knife", false))
		return Plugin_Handled;
	
	if(StrEqual(sWeapon, "weapon_revolver", false))
	{
		Event deathEvent = CreateEvent("player_death");
		deathEvent.SetInt("userid", GetClientUserId(victim));
		deathEvent.SetInt("attacker", GetClientUserId(attacker));
		deathEvent.SetString("weapon", sWeapon);
		deathEvent.SetBool("headshot", true);
		deathEvent.Fire();
		if(IsPlayerAlive(victim))
			ForcePlayerSuicide(victim);
			
		//int kills = GetEntProp(attacker, Prop_Data, "m_iFrags");
		if(GetEntData(attacker, g_iFragsOffset) >= g_cKillsToWin.IntValue)
		{
			if(GetClientTeam(attacker) == CS_TEAM_T)
				CS_TerminateRound(5.0, CSRoundEnd_TerroristWin);
			else
				CS_TerminateRound(5.0, CSRoundEnd_CTWin);
		}
			
		GiveKillAmmo(attacker);
		return Plugin_Handled;
	}
	
	if(StrEqual(sWeapon, "weapon_knife", false))
	{
		GiveKillAmmo(attacker);
		//int kills = GetEntProp(victim, Prop_Data, "m_iFrags");
		int newFrags = GetEntData(victim, g_iFragsOffset) - 1;
		if(newFrags >= 0)
			SetEntData(victim, g_iFragsOffset, newFrags);
	}
	
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	char sWeapon[32];
	event.GetString("weapon", sWeapon, 32);
	
	if(StrEqual(sWeapon, "weapon_knife", false))
	{
		GiveKillAmmo(attacker);
		//int kills = GetEntProp(victim, Prop_Data, "m_iFrags");
		int newFrags = GetEntData(victim, g_iFragsOffset) - g_cKnifePunishmet.IntValue;
		if(newFrags >= 0)
			SetEntData(victim, g_iFragsOffset, newFrags);
		else
			SetEntData(victim, g_iFragsOffset, 0);
	}
}

stock void GiveKillAmmo(int client)
{
	GivePlayerAmmo(client, 1, 32, true);
}

stock void StripClientWeapons(int client)
{
	int iEnt;
	for (int i = 0; i <= 4; i++)
	{
		while ((iEnt = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, iEnt);
			AcceptEntityInput(iEnt, "Kill");
		}
	}
}