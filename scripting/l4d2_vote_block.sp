#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.00"

#define DEBUG

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_VALID_HUMAN(%1)		(IS_VALID_CLIENT(%1) && IsClientConnected(%1) && !IsFakeClient(%1))
#define IS_SPECTATOR(%1)        (GetClientTeam(%1) == TEAM_SPECTATOR)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == TEAM_INFECTED)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_SPECTATOR(%1)  (IS_VALID_INGAME(%1) && IS_SPECTATOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))
#define IS_HUMAN_SURVIVOR(%1)   (IS_VALID_HUMAN(%1) && IS_SURVIVOR(%1))
#define IS_HUMAN_INFECTED(%1)   (IS_VALID_HUMAN(%1) && IS_INFECTED(%1))

#define MAX_CLIENTS MaxClients

#define CONFIG_FILENAME "l4d2_vote_block"
#define CONFIG_FILE "l4d2_vote_block.cfg"
#define PREFIX 		"\x04[Vote Block (simple)]\x03"

#define KICK_REASON "kick"
#define RETURNTOLOBBY_REASON "returntolobby"
#define CHANGEALLTALK_REASON "changealltalk"
#define RESTART_REASON "restartgame"
#define MISSION_REASON "changemission"
#define CHAPTER_REASON "changechapter"
#define DIFFICULTY_REASON "changedifficulty"

public Plugin myinfo = 
{
	name = "Vote Block (simple)", 
	author = "kahdeg", 
	description = "Blocking vote.", 
	version = PLUGIN_VERSION, 
	url = ""
};

ConVar g_bCvarAllow,g_bCvarPrintChat,g_bCvarBlockKick,g_bCvarBlockLobby,g_bCvarBlockAllTalk,g_bCvarBlockRestart,g_bCvarBlockMission,g_bCvarBlockChapter,g_bCvarBlockDifficulty;

char g_ConfigPath[PLATFORM_MAX_PATH];


public void OnPluginStart()
{
	//Make sure we are on left 4 dead 2!
	if (GetEngineVersion() != Engine_Left4Dead2) {
		SetFailState("This plugin only supports left 4 dead 2!");
		return;
	}
	
	BuildPath(Path_SM, g_ConfigPath, sizeof(g_ConfigPath), "configs/%s", CONFIG_FILE);
	
	/**
	 * @note For the love of god, please stop using FCVAR_PLUGIN.
	 * Console.inc even explains this above the entry for the FCVAR_PLUGIN define.
	 * "No logic using this flag ever existed in a released game. It only ever appeared in the first hl2sdk."
	 */
	CreateConVar("sm_voteblock_version", PLUGIN_VERSION, "Plugin Version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_bCvarAllow = CreateConVar("vote_block_on", "1", "Enable plugin. 1=Plugin On. 0=Plugin Off", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarPrintChat = CreateConVar("vote_block_print_on", "1", "Enable plugin to print to chat. 1=Plugin On. 0=Plugin Off", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockKick = CreateConVar("vote_kick_block_on", "1", "Block kick vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockLobby = CreateConVar("vote_returntolobby_block_on", "1", "Block return to lobby vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockAllTalk = CreateConVar("vote_changealltalk_block_on", "1", "Block change all talk vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockRestart = CreateConVar("vote_restart_block_on", "1", "Block restart vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockMission = CreateConVar("vote_changemission_block_on", "1", "Block change mission vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockChapter = CreateConVar("vote_changechapter_block_on", "1", "Block change chapter vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarBlockDifficulty = CreateConVar("vote_changedifficulty_block_on", "1", "Block change difficulty vote. 1=Disable. 0=Enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, CONFIG_FILENAME);

	// Listen for when the callvote command is used
	AddCommandListener(Listener_CallVote, "callvote");
}

/**
* Callback for callvote command.
*/
public Action Listener_CallVote(int client, const char[] command, int args) {
	
	if (IsPluginDisabled()) {
		return Plugin_Continue;
	}
	
	if (IsClientAdmin(client)){
		return Plugin_Continue;
	}
	
	char issue[255];
	GetCmdArg(1, issue, sizeof(issue));
	
	if (g_bCvarBlockKick.BoolValue && StrEqual(issue, KICK_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	if (g_bCvarBlockLobby.BoolValue && StrEqual(issue, RETURNTOLOBBY_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	if (g_bCvarBlockAllTalk.BoolValue && StrEqual(issue, CHANGEALLTALK_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	if (g_bCvarBlockRestart.BoolValue && StrEqual(issue, RESTART_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	if (g_bCvarBlockMission.BoolValue && StrEqual(issue, MISSION_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	if (g_bCvarBlockChapter.BoolValue && StrEqual(issue, CHAPTER_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	if (g_bCvarBlockDifficulty.BoolValue && StrEqual(issue, DIFFICULTY_REASON, false)){
		DebugPrint("%s Vote %s blocked!", PREFIX, issue);
		return Plugin_Handled;
	}
	
	//DebugPrint("%s Vote %s allowed", PREFIX, issue);
	return Plugin_Continue;
}

public void DebugPrint(const char[] format, any...) {
	#if defined DEBUG
	if (!g_bCvarPrintChat.BoolValue) return;
	
	char buffer[254];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToChat(i, "%s", buffer);
		}
	}
	#endif
}

public bool IsPluginDisabled() {
	return !g_bCvarAllow.BoolValue;
}

public bool IsClientAdmin(int client)
{
	// If the client has the ban flag, return true
	if (CheckCommandAccess(client, "admin_ban", ADMFLAG_BAN, false))
	{
		return true;
	}

	// If the client does not, return false
	else
	{
		return false;
	}
}