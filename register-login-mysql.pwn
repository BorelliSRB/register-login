/*=================== REGISTER / LOGIN SYSTEM =================//
|- Credits: 
			@ Slade
			@ Emmet White
			@ solstice_ (base script)  | https://sampforum.blast.hk/showthread.php?tid=659037 
===============================================================*/
#define YSI_NO_HEAP_MALLOC
#include <a_samp>
//-------------------//
#include <a_mysql>
#include <samp_bcrypt>
//-------------------//
#include <ysilib\YSI_Visual\y_dialog>
#include <ysilib\YSI_Coding\y_inline>
#include <ysilib\YSI_Coding\y_va>
#include <ysilib\YSI_Data\y_iterate>
#include <ysilib\YSI_Data\y_bit>
#include <ysilib\YSI_Coding\y_hooks>
//-------------------//
#include <ysilib\YSI_Extra\y_inline_bcrypt>
#include <ysilib\YSI_Extra\y_inline_mysql>
//-------------------//
#define MYSQL_HOSTNAME		"localhost" 
#define MYSQL_USERNAME		"root" 
#define MYSQL_PASSWORD		"" 
#define MYSQL_DATABASE		"reglog" 
//------------------//
#define GetPlayerUniqueID(%0) account_ID[%0]
#define GetPlayerCharUniqueID(%0) character_ID[%0]
//-----------------//
new MySQL: Database,

	BitArray: isLogged<MAX_PLAYERS>,

	account_ID[MAX_PLAYERS],
    account_Password[MAX_PLAYERS][YSI_MAX_STRING],

	character_ID[MAX_PLAYERS],
    character_Cash[MAX_PLAYERS],
	character_Kills[MAX_PLAYERS],
    character_Age[MAX_PLAYERS],
	character_Deaths[MAX_PLAYERS];
//----------------------------//
public OnGameModeInit()
{
	//=======================//
	Database = mysql_connect(MYSQL_HOSTNAME, MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_DATABASE);
	if(mysql_errno(Database) != 0)
	{
		print("SERVER: MySQL Connection failed, shutting the server down!");
		SendRconCommand("exit");
		return 1;
	}
	print("SERVER: MySQL Connection was successful.");

	mysql_tquery(Database, "CREATE TABLE IF NOT EXISTS `players` (`accountID` INT NOT NULL AUTO_INCREMENT, `Username` VARCHAR(24) NOT NULL, `Password` VARCHAR(64) NOT NULL, `IPAddress` VARCHAR(17) NOT NULL, PRIMARY KEY (`accountID`))");    
	mysql_tquery(Database, "CREATE TABLE IF NOT EXISTS `player_character` (`characterID` INT NOT NULL AUTO_INCREMENT, `character_name` VARCHAR(24) NOT NULL, `Cash` INT NOT NULL, `Kills` INT NOT NULL, `Deaths` INT NOT NULL, `Godine` INT NOT NULL, FOREIGN KEY (`characterID`) REFERENCES players(`accountID`) ON DELETE CASCADE ON UPDATE CASCADE)");
	
	//===============================================//
	DisableInteriorEnterExits();
	ManualVehicleEngineAndLights();
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
	SetNameTagDrawDistance(20.0);
	LimitGlobalChatRadius(20.0);
	AllowInteriorWeapons(1);
	EnableVehicleFriendlyFire();
	EnableStuntBonusForAll(0);
	return 1;
}

public OnPlayerConnect(playerid)
{
	Bit_Set(isLogged, playerid, false);
	CheckPlayerAccount(playerid);
	TogglePlayerSpectating(playerid, false);
	return 1;
}

ReturnIP(playerid)
{
	new PlayerIP[17];
	GetPlayerIp(playerid, PlayerIP, sizeof(PlayerIP));
	return PlayerIP;
}
//--------------------------//
CheckPlayerAccount(playerid)
{
	inline const CheckAccount()
	{
		if(cache_num_rows())
		{
			inline DialogLogin(id, dialogid, response, listitem, string: inputtext[])
			{	
				#pragma unused id, dialogid, listitem
				if(response)
				{
					new query[300], Password[BCRYPT_HASH_LENGTH];
					mysql_format(Database, query, sizeof(query), "SELECT `Password` FROM `players` WHERE `Username` = '%e'", ReturnPlayerName(playerid));
					mysql_query(Database, query);
					cache_get_value_name(0, "Password", Password, BCRYPT_HASH_LENGTH);
					inline const OnHashVerification(bool: same)
					{
						if(same)
						{
							inline const OnPlayerLoad()
							{
								cache_get_value_name_int(0, "accountID", GetPlayerUniqueID(playerid));

								cache_get_value_name_int(0, "characterID", GetPlayerCharUniqueID(playerid));

								cache_get_value_name_int(0, "Cash", character_Cash[playerid]);

								cache_get_value_name_int(0, "Kills", character_Kills[playerid]);

								cache_get_value_name_int(0, "Deaths", character_Deaths[playerid]);

								cache_get_value_name_int(0, "Godine", character_Age[playerid]);

								Bit_Set(isLogged, playerid, true);
								SendClientMessage(playerid, -1, "Dobrodosli nazad na nas server.");
								SpawnPlayer(playerid);

								GivePlayerMoney(playerid, character_Cash[playerid]);
							}
							MySQL_TQueryInline(Database, using inline OnPlayerLoad, "SELECT * FROM `players` LEFT JOIN `player_character` ON `players`.`accountID` = `player_character`.`characterID` WHERE `Username` = '%e' LIMIT 1", ReturnPlayerName(playerid));
						}
						else
						{
							Dialog_ShowCallback(playerid, using inline DialogLogin, DIALOG_STYLE_PASSWORD, 
							"Login to the server", 
							va_return("{FFFFFF}Dobrodosli na {AFAFAF}Server{FFFFFF}%s. Molimo vas unesite vasu lozinku.", ReturnPlayerName(playerid)),
							"Login", "Dip");
			
						}
					}
					BCrypt_CheckInline(inputtext, Password, using inline OnHashVerification);
				}
				else
					Kick(playerid);
			}
			
			Dialog_ShowCallback(playerid, using inline DialogLogin, DIALOG_STYLE_PASSWORD, 
			"Login to the server", 
			va_return("{FFFFFF}Dobrodosli na {AFAFAF}Server{FFFFFF}%s. Molimo vas unesite vasu lozinku.", ReturnPlayerName(playerid)),
			"Login", "Dip");
		}
		else
		{
			inline DialogRegister(id, dialogid, response, listitem, string: inputtext[])
			{
				#pragma unused id, dialogid, listitem
				if(response)
				{
					
					inline const OnHashed(string: result[])
					{
						account_Password[playerid] = result;
						inline const AccountInsertID()
						{
							account_ID[playerid] = cache_insert_id();
						}
						MySQL_TQueryInline(Database, using inline AccountInsertID, "INSERT INTO `players` (`Username`, `Password`, `IPAddress`) VALUES ('%e', '%e', '%e')", ReturnPlayerName(playerid), account_Password[playerid], ReturnIP(playerid));
					}
					BCrypt_HashInline(inputtext, 12, using inline OnHashed);
					// <------- Dialog Godine -------> //
					ShowPlayerAgeDialog(playerid);
					//================================//
					}
				else
					Kick(playerid);
			}
			Dialog_ShowCallback(playerid, using inline DialogRegister, DIALOG_STYLE_PASSWORD, 
			"Register to the server", 
			va_return("{FFFFFF}Dobrodosli na nas server, %s. U input ispod unesite lozinku!.", ReturnPlayerName(playerid)), 
			"Register", "Dip");
			
		}
	}
	MySQL_TQueryInline(Database, using inline CheckAccount, "SELECT  `Username` FROM `players` WHERE `Username` = '%e'", ReturnPlayerName(playerid));
}
ShowPlayerAgeDialog(playerid)
{
	inline DialogGodine(id, dialogid, response, listitem, string: inputtext[])
	{
		#pragma unused id, dialogid, listitem
		if(response)
		{
			new query[300];
			character_Age[playerid] = strval(inputtext);
							
			mysql_format(Database, query, sizeof(query), "INSERT INTO `player_character` (`character_name`, `Cash`, `Kills`, `Deaths`, `Godine`) VALUES ('%e', 9000, 0, 0, '%d')", ReturnPlayerName(playerid), character_Age[playerid]);
			mysql_tquery(Database, query);
							
			SpawnPlayer(playerid);
			SendClientMessage(playerid, -1, "Uspesno ste se registrovali na nas server!.");
		}
		else 
			Kick(playerid);
	}
	Dialog_ShowCallback(playerid, using inline DialogGodine, DIALOG_STYLE_INPUT, "Register to the server", " U input ispod unesite vase godine!", "Register", "Dip");
}
//----------------------------//