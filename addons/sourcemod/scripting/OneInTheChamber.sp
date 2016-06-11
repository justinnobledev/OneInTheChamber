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
ConVar g_cLives;

int g_iPlayerLives[MAXPLAYERS + 1];

int m_iClip1 = -1, m_iPrimaryReserveAmmo = -1;

Handle g_hRespawnTimer = null;

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
	g_cLives = CreateConVar("otc_lives", "3", "How many lives does everyone have", FCVAR_NONE, true, 1.0);
	
	AutoExecConfig(true, "OneInTheChamber");
	
	m_iClip1 = FindSendPropOffs("CBaseCombatWeapon", "m_iClip1");
	m_iPrimaryReserveAmmo = FindSendPropOffs("CBaseCombatWeapon", "m_iPrimaryReserveAmmoCount");
	
	if(m_iClip1 == -1)
		SetFailState("[OTC] Could not find \"m_iClip1\" stopping plugin");
		
	if(m_iPrimaryReserveAmmo == -1)
		SetFailState("[OTC] Could not find \"m_iPrimaryReserveAmmoCount\" stopping plugin");
	
	if (g_cLives != null)
		g_cLives.AddChangeHook(OTCCvarChanged);
	
	HookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawnPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
	ConVar teammatesEnmies = FindConVar("mp_teammates_are_enemies");
	teammatesEnmies.SetInt(1);
}

public void OTCCvarChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if (g_cLives.IntValue < 1)
		g_cLives.SetInt(1);
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
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int team = GetClientTeam(i);
			if(team == CS_TEAM_CT || team == CS_TEAM_T)
			{
				g_iPlayerLives[i] = g_cLives.IntValue;
				char sTag[32];
				Format(sTag, 32, "Lives: %i", g_cLives.IntValue);
				CS_SetClientClanTag(i, sTag);
			}
		}
	}
	
	ConVar respawn = FindConVar("mp_respawn_on_death_ct");
	if(g_hRespawnTimer == null)
		g_hRespawnTimer = CreateTimer(respawn.FloatValue, Timer_RespawnPlayers, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		
	respawn.SetInt(0);
	respawn = FindConVar("mp_respawn_on_death_t");
	respawn.SetInt(0);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(g_hRespawnTimer != null)
	{
		KillTimer(g_hRespawnTimer);
		g_hRespawnTimer = null;
	}
}

public Action Timer_RespawnPlayers(Handle Timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int team = GetClientTeam(i);
			if(!IsPlayerAlive(i) && team > CS_TEAM_SPECTATOR && g_iPlayerLives[i] > 0)
			{
				CS_RespawnPlayer(i);
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawnPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(g_iPlayerLives[client] <= 0)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	StripClientWeapons(client);
	GivePlayerItem(client, "weapon_knife");
	GivePlayerItem(client, "weapon_deagle");
	
	int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
	CreateTimer(0.1, Timer_SetPlayerAmmo, weapon, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SetPlayerAmmo(Handle Timer, int weapon)
{
	if (IsValidEntity(weapon))
	{
		SetEntData(weapon, m_iClip1, 1);
		SetEntData(weapon, m_iPrimaryReserveAmmo, 0);
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
	if(!IsValidEntity(weapon))
		return Plugin_Handled;
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
			
	g_iPlayerLives[victim]--;
	
	char sTag[32];
	if(g_iPlayerLives[victim] > 0)
		Format(sTag, 32, "Lives: %i", g_iPlayerLives[victim]);
	else
		Format(sTag, 32, "DEAD");
	
	CS_SetClientClanTag(victim, sTag);
	
	int alive = 0;
	int clients[MAXPLAYERS + 1];
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int team = GetClientTeam(i);
			if(team == CS_TEAM_CT || team == CS_TEAM_T)
			{
				if(g_iPlayerLives[i] > 0)
				{
					clients[alive] = i;
					alive++;
					if(alive >= 2)
						break;
				}
			}
		}
	}
	
	if(alive == 1)
	{
		int team = GetClientTeam(clients[0]);
		if(team == CS_TEAM_CT)
			CS_TerminateRound(5.0, CSRoundEnd_CTWin);
		else if(team == CS_TEAM_T)
			CS_TerminateRound(5.0, CSRoundEnd_TerroristWin);
	}
	
	if (StrEqual(sWeapon, "weapon_knife", false))
		GiveKillAmmo(attacker);
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
		//weapon = GiveWeapon(client, "weapon_deagle");
		weapon = GivePlayerItem(client, "weapon_deagle");
	}
	
	if (weapon == -1)
		return;
	
	if(GetEntData(weapon, m_iClip1) == 0)
	{
		SetEntData(weapon, m_iClip1, 1);
		return;
	}
	else
		SetEntData(weapon, m_iPrimaryReserveAmmo, GetEntData(weapon, m_iPrimaryReserveAmmo) + 1);
	
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

/*stock int GiveWeapon(int client, const char[] weaponName)
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
}*/