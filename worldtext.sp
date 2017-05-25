#pragma semicolon 1

#define PLUGIN_VERSION "1.01"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

//Editing Variables
bool iPosAng[MAXPLAYERS + 1];
bool iAddMinus[MAXPLAYERS + 1];
int iClientLvl[MAXPLAYERS + 1];
char gClientFile[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
ArrayList alClientRefs[MAXPLAYERS + 1];
float fLevels[] = {1.0, 5.0, 10.0, 25.0, 50.0, 100.0};

public Plugin myinfo = 
{
	name = "World Text",
	author = "Deathknife",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegAdminCmd("sm_wtmenu", Cmd_wtMenu, ADMFLAG_ROOT, "Open World Text Menu");
	
	HookEvent("round_start", Event_RoundStart);
}

public void OnClientDisconnect(int client) {
	if(alClientRefs[client] != null) {
		delete alClientRefs[client];
		alClientRefs[client] = null;
	}
}

public Action Cmd_wtMenu(int client, int argc) {
	//Build Path
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/worldtexts/");
	
	//Open Directory
	DirectoryListing dir = OpenDirectory(path);
	//Couldn't open directory for w/e reason
	if(dir == null) {
		ReplyToCommand(client, "Could not open the directory {sourcemod directory}/data/worldtexts/");
		return Plugin_Handled;
	}
	
	//Create Menu
	Menu menu = new Menu(Handler_ListOfTexts);
	menu.SetTitle("Choose a text");
	
	//Read from dir to menu
	ReadDirToMenu("", dir, menu);
	
	//Delete Handle
	delete dir;
	
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public void ReadDirToMenu(char[] path, DirectoryListing dir, Menu menu) {
	char buffer[PLATFORM_MAX_PATH];
	FileType fileType;
	while(ReadDirEntry(dir, buffer, sizeof(buffer), fileType)) {
		//Linux always shows . and .., we don't want to loop through them
		if(StrEqual(buffer, ".")) continue;
		if(StrEqual(buffer, "..")) continue;
		
		//If it's a directory then read that one as well
		if(fileType == FileType_Directory) {
			char newPath[PLATFORM_MAX_PATH];
			FormatEx(newPath, sizeof(newPath), "%s%s/", path, buffer);
			
			char dirPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, dirPath, sizeof(dirPath), "data/worldtexts/%s", newPath);
			
			DirectoryListing ddir = OpenDirectory(dirPath);
			if(ddir == null) continue;
			
			//Read Dir
			ReadDirToMenu(newPath, ddir, menu);
			delete ddir;
		}else {
			char newPath[PLATFORM_MAX_PATH];
			FormatEx(newPath, sizeof(newPath), "%s%s", path, buffer);
			menu.AddItem(newPath, newPath);
		}
	}
}

public int Handler_ListOfTexts(Menu menu, MenuAction menuaction, int client, int param2) {
	if(menuaction == MenuAction_Select) {
		char info[PLATFORM_MAX_PATH];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		Menu hMenu = new Menu(Handler_PlaceText);
		hMenu.SetTitle("Selected: %s\nAim at top left corner of the text", info);
		hMenu.AddItem(info, "Continue");
		hMenu.Display(client, MENU_TIME_FOREVER);
	}else if(menuaction == MenuAction_Cancel) {
		//
	}else if(menuaction == MenuAction_End) {
		delete menu;
	}
}

public int Handler_PlaceText(Menu menu, MenuAction menuaction, int client, int param2) {
	if(menuaction == MenuAction_Select) {
		char info[PLATFORM_MAX_PATH];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		//Build full path
		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/worldtexts/%s", info);
		
		strcopy(gClientFile[client], sizeof(gClientFile[]), info);
		
		float fPos[3];
		float fAng[3];
		GetClientAimText(client, fPos, fAng);
		
		if(alClientRefs[client] != null) delete alClientRefs[client];
		alClientRefs[client] = new ArrayList();
		DrawFileText(client, path, fPos, fAng, false);
		
		OpenEditorMenu(client);
	}else if(menuaction == MenuAction_Cancel) {
		//
	}else if(menuaction == MenuAction_End) {
		delete menu;
	}
}

public void OpenEditorMenu(int client) {
	Menu menu = new Menu(Handler_Editor);
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	menu.AddItem("save", "Save");
	char temp[32];
	int lvl = iClientLvl[client];
	
	FormatEx(temp, sizeof(temp), "%.1f [%.1f] %.1f", 
		(lvl == 0 ? fLevels[sizeof(fLevels) - 1] : fLevels[lvl - 1]),
		 fLevels[iClientLvl[client]],
		 (lvl == sizeof(fLevels) - 1 ? fLevels[0] : fLevels[lvl + 1]));
	
	menu.AddItem("lvl", temp);
	if(iPosAng[client]) {
		menu.AddItem("posang", "[POSITION] ANGLE");
	}else {
		menu.AddItem("posang", "POSITION [ANGLE]");
	}
	
	if(iAddMinus[client]) {
		menu.AddItem("+-", "[+] -");
	}else {
		menu.AddItem("+-", "+ [-]");
	}
	menu.AddItem("X", "X");
	menu.AddItem("Y", "Y");
	menu.AddItem("Z", "Z");
	menu.AddItem("cancel", "Cancel");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_Editor(Menu menu, MenuAction menuaction, int client, int param2) {
	if(menuaction == MenuAction_Select) {
		char info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "posang")) {
			iPosAng[client] = !iPosAng[client];		
		}else if(StrEqual(info, "+-")) {
			iAddMinus[client] = !iAddMinus[client];
		}else if(StrEqual(info, "lvl")) {
			if(iClientLvl[client] == sizeof(fLevels) - 1) {
				iClientLvl[client] = 0;
			}else {
				iClientLvl[client]++;
			}
		}else if(StrEqual(info, "X")) {
			MoveClientEnts(client, 0, iPosAng[client], iAddMinus[client], fLevels[iClientLvl[client]]);
		}else if(StrEqual(info, "Y")) {
			MoveClientEnts(client, 1, iPosAng[client], iAddMinus[client], fLevels[iClientLvl[client]]);
		}else if(StrEqual(info, "Z")) {
			MoveClientEnts(client, 2, iPosAng[client], iAddMinus[client], fLevels[iClientLvl[client]]);
		}else if(StrEqual(info, "cancel")) {
			if(alClientRefs[client] != null) {
				for(int i = 0; i < alClientRefs[client].Length; i++) {
					int entity = EntRefToEntIndex(alClientRefs[client].Get(i));
					if(entity != -1 && IsValidEntity(entity)) {
						AcceptEntityInput(entity, "Kill");
					}
				}
				
				delete alClientRefs[client];
				alClientRefs[client] = null;
			}
			return;
		}else if(StrEqual(info, "save")) {
			SaveWorldText(client, gClientFile[client]);
			if(alClientRefs[client] != null) {
				delete alClientRefs[client];
				alClientRefs[client] = null;
			}
			return;
		}
		OpenEditorMenu(client);
	}else if(menuaction == MenuAction_Cancel) {
		//
	}else if(menuaction == MenuAction_End) {
		delete menu;
	}
}

public void MoveClientEnts(int client, int dir, bool Position, bool add, float amount) {
	if(alClientRefs[client] == null) return;
	for(int i = 0; i < alClientRefs[client].Length; i++) {
		int entity = EntRefToEntIndex(alClientRefs[client].Get(i));
		if(entity != -1 && IsValidEntity(entity)) {
			float pos[3];
			if(Position) {
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
				if(add) {
					pos[dir] += amount;
				}else {
					pos[dir] -= amount;
				}
				TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
			}else {
				GetEntPropVector(entity, Prop_Data, "m_angRotation", pos);
				if(add) {
					pos[dir] += amount;
				}else {
					pos[dir] -= amount;
				}
				TeleportEntity(entity, NULL_VECTOR, pos, NULL_VECTOR);
			}
		}
	}
}

public void SaveWorldText(int client, char[] entPath) {
	if(alClientRefs[client] == null) return;
	if(alClientRefs[client].Length == 0) return;
	int entity = EntRefToEntIndex(alClientRefs[client].Get(0));
	if(entity == -1) return;
	if(!IsValidEntity(entity)) return;
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/saved_world_texts/");
	if(!DirExists(path)) {
		CreateDirectory(path, 511);
	}
	char map[128];
	GetCurrentMap(map, sizeof(map));
	Format(path, sizeof(path), "%s%s.txt", path, map);
	Handle file = OpenFile(path, "ab");
	if(file != null) {
		char buffer[256];
		
		float pos[3];
		float ang[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);
		FormatEx(buffer, sizeof(buffer), "@%f %f %f %f %f %f", pos[0], pos[1], pos[2], ang[0], ang[1], ang[2]);
		WriteFileLine(file, buffer);
		WriteFileLine(file, "=%s", entPath);
		
		delete file;
	}else {
		LogError("Couldn't open file %s for writing", path);
	}
}

//Loud all texts
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	char path[PLATFORM_MAX_PATH];
	char map[128];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, path, sizeof(path), "data/saved_world_texts/%s.txt", map);
	
	Handle file = OpenFile(path, "r");
	char line[512];
	float pos[3];
	float ang[3];
	while(!IsEndOfFile(file) && ReadFileLine(file, line, sizeof(line))) {
		//Remove spaces at start & end 
		TrimString(line);
		if(line[0] == '/' && line[1] == '/') continue;
		if(line[0] == '\0') continue;
		if(line[0] == '@') {
			char buff[6][24];
			ExplodeString(line[1], " ", buff, sizeof(buff), sizeof(buff[]));
			for(int i = 0; i < 3; i++) {
				pos[i] = StringToFloat(buff[i]);
				ang[i] = StringToFloat(buff[i+3]);
			}
		}else if(line[0] == '=') {
			char textpath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, textpath, sizeof(textpath), "data/worldtexts/%s", line[1]);
			DrawFileText(-1, textpath, pos, ang, true);
		}
	}
	delete file;
}

public void DrawFileText(int client, char[] path, float fPos[3], float fAng[3], bool IgnoreFirstSize) {
	//Open the file
	Handle hFile = OpenFile(path, "r");
	if(hFile == null) return;
	
	//Buffer to store content of a line 
	char line[512];
	
	int size = 5;
	int rgb[3] = {255, 255, 255};
	
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, line, sizeof(line))) {
		//Remove spaces at start & end 
		TrimString(line);
		
		//If line starts with // or is an empty line, continue 
		if(line[0] == '/' && line[1] == '/') continue;
		if(line[0] == '\0') continue;
		
		if(line[0] == '\"' && line[strlen(line) - 1] == '\"') {
			StripQuotes(line);
			if(IgnoreFirstSize) {
				IgnoreFirstSize = false;
			}else {
				fPos[2] -= float(size);
			}
			int ent = EntIndexToEntRef(WorldText(fPos, fAng, line, size, rgb));
			if(client != -1) PushArrayCell(alClientRefs[client], ent);
		}else {
			int posE = StrContains(line, "=");
			if(StrContains(line, "rgb") == 0 && posE != -1) {
				char temp[24];
				strcopy(temp, sizeof(temp), line[posE+1]);
				TrimString(temp);
				
				char sRGB[3][6];
				ExplodeString(temp, " ", sRGB, sizeof(sRGB), sizeof(sRGB[]));
				rgb[0] = StringToInt(sRGB[0]);
				rgb[1] = StringToInt(sRGB[1]);
				rgb[2] = StringToInt(sRGB[2]);
			}else if(StrContains(line, "size") == 0 && posE != -1) {
				char temp[16];
				strcopy(temp, sizeof(temp), line[posE+1]);
				TrimString(temp);
				size = StringToInt(temp);
			}
		}
	}
	
	//Close the file handle 
	delete hFile;
}

public void GetClientAimText(int client, float fPos[3], float fAng[3]) {
	float pos[3];
	float ang[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);
	
	Handle tr = TR_TraceRayFilterEx(pos, ang, CONTENTS_SOLID, RayType_Infinite, IgnoreSelf, client);
	float fVec[3];
	TR_GetEndPosition(fPos, tr);
	TR_GetPlaneNormal(tr, fVec);
	delete tr;
	GetVectorAngles(fVec, fAng);
	if(fAng[1] == 180.0)
		fAng[1] = 0.0;
	else if(fAng[1] == 0.0)
		fAng[1] = 180.0;
	NegateVector(fAng);
}

public bool IgnoreSelf(int entity, int ContentsPassage, any data)  {
	if (entity == data)return false;
	return true;
}

stock int WorldText(float fPos[3], float fAngles[3], char[] sText = "", iSize = 10,  int rgb[3])
{
    int iEntity = CreateEntityByName("point_worldtext");
    
    if(iEntity == -1) return iEntity;
    
    DispatchKeyValue(iEntity,     "message", sText);
    
    char sSize[4];
    IntToString(iSize, sSize, sizeof(sSize));
    DispatchKeyValue(iEntity,     "textsize", sSize);
    
    char sColor[11];
    Format(sColor, sizeof(sColor), "%d %d %d", rgb[0], rgb[1], rgb[2]);
    DispatchKeyValue(iEntity,     "color", sColor);
    
    TeleportEntity(iEntity, fPos, fAngles, NULL_VECTOR);
    
    return iEntity;
}

stock bool IsValidClient(int client, bool bAlive = false)
{
	if(client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && (bAlive == false || IsPlayerAlive(client)))
	{
		return true;
	}
	
	return false;
}