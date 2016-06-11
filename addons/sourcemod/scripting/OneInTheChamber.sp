#pragma semicolon 1

#define PLUGIN_AUTHOR "R3TROATTACK (http://steamcommunity.com/id/R3TROATTACK/)"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#pragma newdecls required

EngineVersion g_Game;
ConVar g_cVersion;
ConVar g_cKillsToWin;
ConVar g_cKnifePunishmet;

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
	if (g_Game != Engine_CSGO)
		SetFailState("This plugin is for CSGO only.");
	
	g_cVersion = CreateConVar("otc_version", PLUGIN_VERSION, "One in the Chambers Version do not change", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cKillsToWin = CreateConVar("otc_killstowin", "20", "How many kills are required for someone to win", FCVAR_NONE, true, 1.0);
	g_cKnifePunishmet = CreateConVar("otc_knife_penalty", "1", "How many kills are removed for being knifed?");
	
	AutoExecConfig(true, "OneInTheChamber");
	
	if (g_cKillsToWin != null)
		g_cKillsToWin.AddChangeHook(OTCCvarChanged);
	
	HookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
	ConVar teammatesEnmies = FindConVar("mp_teammates_are_enemies");
	teammatesEnmies.SetInt(1);
}

public void OTCCvarChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if (g_cKillsToWin.IntValue < 1)
		g_cKillsToWin.SetInt(1);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < GetEntityCount(); i++)
	{
		if (IsValidEntity(i))
		{
			char classname[PLATFORM_MAX_PATH];
			GetEntityClassname(i, classname, PLATFORM_MAX_PATH);
			
			if (StrEqual(classname, "func_buyzone", false))
				AcceptEntityInput(i, "kill");
		}
	}
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	StripClientWeapons(client);
	GivePlayerItem(client, "weapon_knife");
	GiveWeapon(client, "weapon_deagle");
	
	int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
	CreateTimer(0.1, Timer_SetPlayerAmmo, weapon, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SetPlayerAmmo(Handle Timer, int weapon)
{
	if (IsValidEntity(weapon))
	{
		SetEntProp(weapon, Prop_Data, "m_iClip1", 1);
		SetEntProp(weapon, Prop_Data, "m_iClip2", 0);
	}
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(client, SDKHook_WeaponEquip, Hook_WeaponEquip);
	SDKHook(client, SDKHook_WeaponDrop, Hook_WeaponDrop);
}

public Action Hook_WeaponDrop(int client, int weapon)
{
	return Plugin_Handled;
}

public Action Hook_WeaponEquip(int client, int weapon)
{
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, 32);
	
	if (!StrEqual(sWeapon, "weapon_deagle", false) && !StrEqual(sWeapon, "weapon_knife", false))
	{
		AcceptEntityInput(weapon, "kill");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, 32);
	
	if (!StrEqual(sWeapon, "weapon_deagle", false) && attacker != 0 && !StrEqual(sWeapon, "weapon_knife", false))
		return Plugin_Handled;
	
	if (StrEqual(sWeapon, "weapon_deagle", false))
	{
		damage = 500.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	char sWeapon[32];
	event.GetString("weapon", sWeapon, 32);
	
	StripClientWeapons(victim);
	
	if ((attacker > 0 && attacker <= MaxClients) && IsClientConnected(attacker))
		if (IsPlayerAlive(attacker))
			GiveKillAmmo(attacker);
	
	if (GetEntProp(attacker, Prop_Data, "m_iFrags") >= g_cKillsToWin.IntValue)
	{
		if (GetClientTeam(attacker) == CS_TEAM_T)
			CS_TerminateRound(5.0, CSRoundEnd_TerroristWin);
		else
			CS_TerminateRound(5.0, CSRoundEnd_CTWin);
	}
	
	if (StrEqual(sWeapon, "weapon_knife", false))
	{
		GiveKillAmmo(attacker);
		int kills = GetEntProp(victim, Prop_Data, "m_iFrags");
		int newFrags = kills - g_cKnifePunishmet.IntValue;
		if (newFrags >= 0)
			SetEntProp(victim, Prop_Data, "m_iFrags", newFrags);
		else
			SetEntProp(victim, Prop_Data, "m_iFrags", 0);
	}
}

stock void GiveKillAmmo(int client)
{
	int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
	
	char classname[32];
	GetEntityClassname(weapon, classname, 32);
	
	if (!StrEqual(classname, "weapon_deagle", false))
	{
		RemovePlayerItem(client, weapon);
		AcceptEntityInput(weapon, "kill");
		weapon = GiveWeapon(client, "weapon_deagle");
	}
	
	if (weapon == -1)
		return;
	
	int m_iAmmo = FindDataMapOffs(client, "m_iAmmo");
	int offset = m_iAmmo + (Weapon_GetPrimaryAmmoType(weapon) * 4); 
	SetEntData(client, offset, 1, 4, true); 
}

stock int Weapon_GetPrimaryAmmoType(int weapon) 
{ 
    return GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"); 
} 

stock int Weapon_GetSecondaryAmmoType(int weapon)
{
	return GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoType");
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

stock int GiveWeapon(int client, const char[] weaponName)
{
	if (IsClientInGame(client) && (client > 0 && client <= MaxClients))
	{
		int weapon;
		float pos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		
		weapon = CreateEntityByName(weaponName);
		if (weapon != -1)
		{
			SetEntDataEnt2(weapon, FindSendPropOffs("CBaseCombatWeapon", "m_hOwnerEntity"), client);
			DispatchSpawn(weapon);
			TeleportEntity(weapon, pos, NULL_VECTOR, NULL_VECTOR);
			EquipPlayerWeapon(client, weapon);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
			return weapon;
		}
	}
	return -1;
} 