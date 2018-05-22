#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <csx>
#include <fakemeta>

#define PLUGIN_VERSION "2.1"
#define EXPLODE_MAX 60.0

enum _:Settings
{
	bool:MSG_ENABLE,
	MSG_HE[128],
	MSG_FLASH[128],
	MSG_SMOKE[128],
	MSG_SHOW_TYPE,
	bool:MSG_ADMIN_LISTEN,
	MSG_ADMIN_FLAG,
	MSG_TEAM_T[16],
	MSG_TEAM_CT[16],
	MSG_TEAM_SPEC[16],
	bool:SOUND_ENABLE,
	SOUND_HE[128],
	bool:SOUND_HE_ENABLE,
	SOUND_FLASH[128],
	bool:SOUND_FLASH_ENABLE,
	SOUND_SMOKE[128],
	bool:SOUND_SMOKE_ENABLE,
	SOUND_PLAY_TYPE,
	bool:TRAIL_ENABLE,
	TRAIL_HE[12],
	TRAIL_FLASH[12],
	TRAIL_SMOKE[12],
	TRAIL_SPRITE[64],
	TRAIL_LIFE,
	TRAIL_WIDTH,
	TRAIL_BRIGHTNESS,
	TRAIL_SHOW_TYPE,
	bool:GLOW_ENABLE,
	GLOW_HE[12],
	GLOW_FLASH[12],
	GLOW_SMOKE[12],
	Float:GLOW_BRIGHTNESS,
	GLOW_TYPE,
	bool:EXPLODE_ENABLE,
	Float:EXPLODE_HE,
	Float:EXPLODE_FLASH,
	Float:EXPLODE_SMOKE
}

new g_iSprite
new g_eSettings[Settings]

new const g_szRadio[] = "#Game_radio"
new const g_szFireInTheHole[] = "#Fire_in_the_hole"
new const g_szFITHSound[] = "radio/ct_fireinhole.wav"
new const g_szMradFire[] = "%!MRAD_FIREINHOLE"
new const g_szSetMdl[][] = { "models/w_", "grenade.mdl", "flashbang.mdl" }
new const g_szNameField[] = "$name$"
new const g_szTeamField[] = "$team$"

public plugin_init()
{
	register_plugin("Ultimate Fire in the Hole", PLUGIN_VERSION, "OciXCrom")
	register_cvar("UltimateFITH", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	
	if(g_eSettings[SOUND_ENABLE] && ((!g_eSettings[SOUND_HE_ENABLE] && !g_eSettings[SOUND_FLASH_ENABLE] && !g_eSettings[SOUND_SMOKE_ENABLE]) || !g_eSettings[SOUND_PLAY_TYPE]))
		register_forward(FM_PrecacheSound, "OnPrecacheSound")
	
	if(g_eSettings[MSG_ENABLE])
		register_message(get_user_msgid("TextMsg"), "OnTextMessage")
		
	if(g_eSettings[SOUND_ENABLE])
		register_message(get_user_msgid("SendAudio"), "OnSendAudio")
		
	if(g_eSettings[GLOW_ENABLE] || g_eSettings[EXPLODE_ENABLE])
		register_forward(FM_SetModel, "OnSetModel")
}

public plugin_precache()
	ReadFile()

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/FireInTheHole.ini", szConfigsName)
	
	if(!file_size(szFilename))
	{
		pause("ad")
		log_amx("Configuration file (%s) is empty. The plugin is paused.", szFilename)
		return
	}
	
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[128], szKey[32], szValue[96], iSize
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, '#', ';': continue
				case '[':
				{
					iSize = strlen(szData)
					
					if(szData[iSize - 1] == ']')
					{
						switch(szData[1])
						{
							case 'M', 'm': g_eSettings[MSG_ENABLE] = bool:(str_to_num(szData[iSize - 2]))
							case 'S', 's': g_eSettings[SOUND_ENABLE] = bool:(str_to_num(szData[iSize - 2]))
							case 'T', 't': g_eSettings[TRAIL_ENABLE] = bool:(str_to_num(szData[iSize - 2]))
							case 'G', 'g': g_eSettings[GLOW_ENABLE] = bool:(str_to_num(szData[iSize - 2]))
							case 'E', 'e': g_eSettings[EXPLODE_ENABLE] = bool:(str_to_num(szData[strlen(szData) - 2]))
						}
					}
					else continue
				}
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
					
					if(is_blank(szValue))
						continue
					
					if(g_eSettings[MSG_ENABLE])
					{
						if(equal(szKey, "MSG_HE"))
							copy(g_eSettings[MSG_HE], charsmax(g_eSettings[MSG_HE]), szValue)
						else if(equal(szKey, "MSG_FLASH"))
							copy(g_eSettings[MSG_FLASH], charsmax(g_eSettings[MSG_FLASH]), szValue)
						else if(equal(szKey, "MSG_SMOKE"))
							copy(g_eSettings[MSG_SMOKE], charsmax(g_eSettings[MSG_SMOKE]), szValue)
						else if(equal(szKey, "MSG_SHOW_TYPE"))
							g_eSettings[MSG_SHOW_TYPE] = clamp(str_to_num(szValue), 0, 3)
						else if(equal(szKey, "MSG_ADMIN_LISTEN"))
							g_eSettings[MSG_ADMIN_LISTEN] = bool:(clamp(str_to_num(szValue), 0, 1))
						else if(equal(szKey, "MSG_ADMIN_FLAG"))
							g_eSettings[MSG_ADMIN_FLAG] = read_flags(szValue)
						else if(equal(szKey, "MSG_TEAM_T"))
							copy(g_eSettings[MSG_TEAM_T], charsmax(g_eSettings[MSG_TEAM_T]), szValue)
						else if(equal(szKey, "MSG_TEAM_CT"))
							copy(g_eSettings[MSG_TEAM_CT], charsmax(g_eSettings[MSG_TEAM_CT]), szValue)
						else if(equal(szKey, "MSG_TEAM_SPEC"))
							copy(g_eSettings[MSG_TEAM_SPEC], charsmax(g_eSettings[MSG_TEAM_SPEC]), szValue)
					}
					
					if(g_eSettings[SOUND_ENABLE])
					{
						if(equal(szKey, "SOUND_HE"))
						{						
							precache_sound(szValue)
							copy(g_eSettings[SOUND_HE], charsmax(g_eSettings[SOUND_HE]), szValue)
							g_eSettings[SOUND_HE_ENABLE] = true
						}
						else if(equal(szKey, "SOUND_FLASH"))
						{
							precache_sound(szValue)
							copy(g_eSettings[SOUND_FLASH], charsmax(g_eSettings[SOUND_FLASH]), szValue)
							g_eSettings[SOUND_FLASH_ENABLE] = true
						}
						else if(equal(szKey, "SOUND_SMOKE"))
						{
							precache_sound(szValue)
							copy(g_eSettings[SOUND_SMOKE], charsmax(g_eSettings[SOUND_SMOKE]), szValue)
							g_eSettings[SOUND_SMOKE_ENABLE] = true
						}
						else if(equal(szKey, "SOUND_PLAY_TYPE"))
							g_eSettings[SOUND_PLAY_TYPE] = clamp(str_to_num(szValue), 0, 3)
					}
					
					if(g_eSettings[TRAIL_ENABLE])
					{
						if(equal(szKey, "TRAIL_HE"))
							copy(g_eSettings[TRAIL_HE], charsmax(g_eSettings[TRAIL_HE]), szValue)
						else if(equal(szKey, "TRAIL_FLASH"))
							copy(g_eSettings[TRAIL_FLASH], charsmax(g_eSettings[TRAIL_FLASH]), szValue)
						else if(equal(szKey, "TRAIL_SMOKE"))
							copy(g_eSettings[TRAIL_SMOKE], charsmax(g_eSettings[TRAIL_SMOKE]), szValue)
						else if(equal(szKey, "TRAIL_SPRITE"))
						{
							copy(g_eSettings[TRAIL_SPRITE], charsmax(g_eSettings[TRAIL_SPRITE]), szValue)
							g_iSprite = precache_model(szValue)
						}
						else if(equal(szKey, "TRAIL_LIFE"))
							g_eSettings[TRAIL_LIFE] = str_to_num(szValue)
						else if(equal(szKey, "TRAIL_WIDTH"))
							g_eSettings[TRAIL_WIDTH] = str_to_num(szValue)
						else if(equal(szKey, "TRAIL_BRIGHTNESS"))
							g_eSettings[TRAIL_BRIGHTNESS] = clamp(str_to_num(szValue), 0, 255)
						else if(equal(szKey, "TRAIL_SHOW_TYPE"))
							g_eSettings[TRAIL_SHOW_TYPE] = clamp(str_to_num(szValue), 0, 2)
					}
					
					if(g_eSettings[GLOW_ENABLE])
					{
						if(equal(szKey, "GLOW_HE"))
							copy(g_eSettings[GLOW_HE], charsmax(g_eSettings[GLOW_HE]), szValue)
						else if(equal(szKey, "GLOW_FLASH"))
							copy(g_eSettings[GLOW_FLASH], charsmax(g_eSettings[GLOW_FLASH]), szValue)
						else if(equal(szKey, "GLOW_SMOKE"))
							copy(g_eSettings[GLOW_SMOKE], charsmax(g_eSettings[GLOW_SMOKE]), szValue)
						else if(equal(szKey, "GLOW_BRIGHTNESS"))
							g_eSettings[GLOW_BRIGHTNESS] = _:str_to_float(szValue)
						else if(equal(szKey, "GLOW_TYPE"))
							g_eSettings[GLOW_TYPE] = clamp(str_to_num(szValue), 0, 1) ? kRenderTransAlpha : kRenderNormal
					}
					
					if(g_eSettings[EXPLODE_ENABLE])
					{
						if(equal(szKey, "EXPLODE_HE"))
							g_eSettings[EXPLODE_HE] = _:floatclamp(str_to_float(szValue), 0.0, EXPLODE_MAX)
						else if(equal(szKey, "EXPLODE_FLASH"))
							g_eSettings[EXPLODE_FLASH] = _:floatclamp(str_to_float(szValue), 0.0, EXPLODE_MAX)
						else if(equal(szKey, "EXPLODE_SMOKE"))
							g_eSettings[EXPLODE_SMOKE] = _:floatclamp(str_to_float(szValue), 0.0, EXPLODE_MAX)
					}
				}
			}	
		}
		
		fclose(iFilePointer)
	}
}

public OnTextMessage(MsgId, MsgDest, MsgEntity)
{
	if(get_msg_args() != 5 || get_msg_argtype(3) != ARG_STRING || get_msg_argtype(5) != ARG_STRING)
		return PLUGIN_CONTINUE
		
	new szRadio[16]
	get_msg_arg_string(3, szRadio, charsmax(szRadio))
	
	if(!equal(szRadio, g_szRadio))
		return PLUGIN_CONTINUE
		
	new szMessage[20]
	get_msg_arg_string(5, szMessage, charsmax(szMessage))
	return equal(szMessage, g_szFireInTheHole)
}

public OnSendAudio(MsgId, MsgDest, MsgEntity)
{
	new szMessage[32]
	get_msg_arg_string(2, szMessage, charsmax(szMessage))
	return equal(szMessage, g_szMradFire)
}

public OnSetModel(iEnt, const szModel[])
{
	if(!pev_valid(iEnt))
		return
		
	if(contain(szModel, g_szSetMdl[0]) != -1 && (contain(szModel, g_szSetMdl[1]) != -1 || contain(szModel, g_szSetMdl[2]) != -1))
	{
		new szGlow[12]
		
		switch(szModel[9])
		{
			case 'h':
			{
				set_pev(iEnt, pev_dmg, 1000.0)
				copy(szGlow, charsmax(szGlow), g_eSettings[GLOW_HE])
				
				if(g_eSettings[EXPLODE_HE])
					set_pev(iEnt, pev_dmgtime, get_gametime() + g_eSettings[EXPLODE_HE])
			}
			case 'f':
			{
				copy(szGlow, charsmax(szGlow), g_eSettings[GLOW_FLASH])
				
				if(g_eSettings[EXPLODE_FLASH])
					set_pev(iEnt, pev_dmgtime, get_gametime() + g_eSettings[EXPLODE_FLASH])
			}
			case 's':
			{
				copy(szGlow, charsmax(szGlow), g_eSettings[GLOW_SMOKE])
				
				if(g_eSettings[EXPLODE_SMOKE])
					set_pev(iEnt, pev_dmgtime, get_gametime() + g_eSettings[EXPLODE_SMOKE])
			}
			default: return
		}
		
		new szRed[4], szGreen[4], szBlue[4], Float:flColor[3]
		parse(szGlow, szRed, charsmax(szRed), szGreen, charsmax(szGreen), szBlue, charsmax(szBlue))
		flColor[0] = is_random(szRed) ? random_float(0.0, 255.0) : floatclamp(str_to_float(szRed), 0.0, 255.0)
		flColor[1] = is_random(szGreen) ? random_float(0.0, 255.0) : floatclamp(str_to_float(szGreen), 0.0, 255.0)
		flColor[2] = is_random(szBlue) ? random_float(0.0, 255.0) : floatclamp(str_to_float(szBlue), 0.0, 255.0)
		set_pev(iEnt, pev_renderfx, kRenderFxGlowShell)
		set_pev(iEnt, pev_renderamt, g_eSettings[GLOW_BRIGHTNESS])
		set_pev(iEnt, pev_rendermode, g_eSettings[GLOW_TYPE])
		set_pev(iEnt, pev_rendercolor, flColor)
	}
}

public grenade_throw(id, iGrenade, iWeapon)
{
	new szMessage[192], szSound[128], szTeam[16], szTrail[12], iTeam
	
	if(is_user_connected(id))
		iTeam = get_user_team(id, szTeam, charsmax(szTeam))
		
	switch(iWeapon)
	{
		case CSW_HEGRENADE:
		{
			if(g_eSettings[MSG_ENABLE] && g_eSettings[MSG_SHOW_TYPE])
				copy(szMessage, charsmax(szMessage), g_eSettings[MSG_HE])
			
			if(g_eSettings[SOUND_ENABLE] && g_eSettings[SOUND_PLAY_TYPE] && g_eSettings[SOUND_HE_ENABLE])
				copy(szSound, charsmax(szSound), g_eSettings[SOUND_HE])
				
			if(g_eSettings[TRAIL_ENABLE])
				copy(szTrail, charsmax(szTrail), g_eSettings[TRAIL_HE])
		}
		case CSW_FLASHBANG:
		{
			if(g_eSettings[MSG_ENABLE] && g_eSettings[MSG_SHOW_TYPE])
				copy(szMessage, charsmax(szMessage), g_eSettings[MSG_FLASH])
			
			if(g_eSettings[SOUND_ENABLE] && g_eSettings[SOUND_PLAY_TYPE] && g_eSettings[SOUND_FLASH_ENABLE])
				copy(szSound, charsmax(szSound), g_eSettings[SOUND_FLASH])
				
			if(g_eSettings[TRAIL_ENABLE])
				copy(szTrail, charsmax(szTrail), g_eSettings[TRAIL_FLASH])
		}
		case CSW_SMOKEGRENADE:
		{
			if(g_eSettings[MSG_ENABLE] && g_eSettings[MSG_SHOW_TYPE])
				copy(szMessage, charsmax(szMessage), g_eSettings[MSG_SMOKE])
			
			if(g_eSettings[SOUND_ENABLE] && g_eSettings[SOUND_PLAY_TYPE] && g_eSettings[SOUND_SMOKE_ENABLE])
				copy(szSound, charsmax(szSound), g_eSettings[SOUND_SMOKE])
				
			if(g_eSettings[TRAIL_ENABLE])
				copy(szTrail, charsmax(szTrail), g_eSettings[TRAIL_SMOKE])
		}
	}
	
	if(g_eSettings[MSG_ENABLE] && g_eSettings[MSG_SHOW_TYPE])
	{
		new szName[32]
		get_user_name(id, szName, charsmax(szName))
		
		if(contain(szMessage, g_szNameField) != -1)
			replace_all(szMessage, charsmax(szMessage), g_szNameField, szName)
			
		if(contain(szMessage, g_szTeamField) != -1)
			replace_all(szMessage, charsmax(szMessage), g_szTeamField, szTeam)
			
		switch(g_eSettings[MSG_SHOW_TYPE])
		{
			case 1: CC_SendMessage(id, szMessage)
			case 2:
			{
				new iPlayers[32], iPnum
				get_players(iPlayers, iPnum, "ch")
			
				for(new i, iPlayer; i < iPnum; i++)
				{
					iPlayer = iPlayers[i]
					
					if(iTeam == get_user_team(iPlayer) || (g_eSettings[MSG_ADMIN_LISTEN] && get_user_flags(iPlayer) & g_eSettings[MSG_ADMIN_FLAG]))
						CC_SendMatched(iPlayer, id, szMessage)
				}
			}
			case 3: CC_SendMatched(0, id, szMessage)
		}
	}
	
	if(!is_blank(szSound))
	{
		switch(g_eSettings[SOUND_PLAY_TYPE])
		{
			case 1: client_cmd(id, "spk %s", szSound)
			case 2:
			{
				new iPlayers[32], iPnum
				get_players(iPlayers, iPnum, "ceh", szTeam)
			
				for(new i; i < iPnum; i++)
					client_cmd(iPlayers[i], "spk %s", szSound)
			}
			case 3: client_cmd(0, "spk %s", szSound)
		}
	}
	
	if(g_eSettings[TRAIL_ENABLE])
	{
		new szRed[4], szGreen[4], szBlue[4], iColor[3]
		parse(szTrail, szRed, charsmax(szRed), szGreen, charsmax(szGreen), szBlue, charsmax(szBlue))
		iColor[0] = is_random(szRed) ? random(256) : clamp(str_to_num(szRed), 0, 255)
		iColor[1] = is_random(szGreen) ? random(256) : clamp(str_to_num(szGreen), 0, 255)
		iColor[2] = is_random(szBlue) ? random(256) : clamp(str_to_num(szBlue), 0, 255)
		
		switch(g_eSettings[TRAIL_SHOW_TYPE])
		{
			case 0:	apply_grenade_trail(MSG_BROADCAST, iGrenade, iColor)
			case 1:	apply_grenade_trail(MSG_ONE_UNRELIABLE, iGrenade, iColor, id)
			case 2:
			{
				new iPlayers[32], iPnum
				get_players(iPlayers, iPnum, "ceh", szTeam)
				
				for(new i; i < iPnum; i++)
					apply_grenade_trail(MSG_ONE_UNRELIABLE, iGrenade, iColor, iPlayers[i])
			}
		}
	}
}

apply_grenade_trail(iType, iGrenade, iColor[3], iPlayer = 0)
{
	message_begin(iType, SVC_TEMPENTITY, .player = iPlayer)
	write_byte(TE_BEAMFOLLOW)
	write_short(iGrenade)
	write_short(g_iSprite)
	write_byte(g_eSettings[TRAIL_LIFE])
	write_byte(g_eSettings[TRAIL_WIDTH])
	write_byte(iColor[0])
	write_byte(iColor[1])
	write_byte(iColor[2])
	write_byte(g_eSettings[TRAIL_BRIGHTNESS])
	message_end()
}

public OnPrecacheSound(const szSound[])
	return equal(szSound, g_szFITHSound) ? FMRES_SUPERCEDE : FMRES_IGNORED
	
bool:is_blank(szString[])
	return szString[0] == EOS
	
bool:is_random(szString[])
	return szString[0] == 'R'