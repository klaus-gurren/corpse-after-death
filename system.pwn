#define D_DEAD  4442 //Діалог, 4442 - вільний ID
#define D_DEAD_AMMO  4443

#define MAX_DEAD_NUM	300 //макс кількість трупів
#define DESTRUCTION_TIMER	10000*60 //через скільки видалиться труп, приклад - 10хв.
#define SEARCH_CORPSE	2700 //тривалість першого лута трупа (в мілісекундах)

new MaxDead = 0; //макс. кількість створених трупів
new CorpseIDNear[MAX_PLAYERS]; //ID трупа около гравця

enum DeadPlayer {
	deadName[MAX_PLAYER_NAME], //Нік трупа
	DeadActorID, //ID актора
	bool:CorpseLost, //чи залутаний труп
	Float:xActor, //координати X
	Float:yActor, //координати Y
	Float:zActor, //координати Z
	Text3D:deadLabel3D, //3D текст
	dead_timer, //таймер
	gunslot[13], //зброя
	cartridges[13] //боєприпаси
}
new pDeadAct[MAX_DEAD_NUM][DeadPlayer]; //створення двомірного масива, для змінних із enum-a. 
	
new const DgunName[][] = { //константа для послідовної номерації назв зброї
    "", "Кастет", "Клюшка для гольфа", "Поліцейська дубинка", 
    "Ніж", "Бейсбольна бита", "Лопата", "Більярдний кий", 
    "Катана", "Бензопила", "Велике дилдо", "Мале дилдо", 
    "Великий вібратор", "Малий вібратор", "Квіти", "Трость", 
    "Граната", "Сльозоточивий газ", "", "", 
    "", "Коктель молотова", "Кольт.45", "Кольт.45 з глушителем", 
    "Desert Eagle", "Дробовик", "Обріз", "Дробовик SPAS-12", 
    "Микро-Узи", "MP5", "АК-47", "M4", 
    "TEC-9", "Гвинтівка", "Снайперска гвинтівка", "Гранатомет",
    "Самонаводящийся гранатомет", "Вогнемет", "Мініган", "Взривчатка",
    "Детонатор", "Балончик з краскою", "Вогнетушитель"};

public OnPlayerDeath(playerid, killerid, reason) //В паблік після смерті персонажа
{
	for(new i = 0; i <= MaxDead; i++) //цикл для перевірки на відсутність трупа по ніку
	{
		if(!strlen(pDeadAct[i][deadName])) continue; //якщо масив ніка порожній/немає трупа
		if(!strcmp(PI[playerid][pNames], pDeadAct[i][deadName])) //якщо вже є труп із ніком гравця
		{
			removal_corpse(i); //Видалення ID трупа із виявленим ніком
			break; //перериваю цикл
		}
	}
	CreateDeathActor(playerid); //викликаю сток створення трупа
	return 1;
}

public OnPlayerDisconnect(playerid, reason) //при відключенні від сервера
{
	CorpseIDNear[playerid] = 0; //обнуляю змінну
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) //паблік роботи із діалогами
{
	case D_DEAD_AMMO:
	{
		if(!response) return 1;
		SetPVarInt(playerid, "pListGun", listitem); //Збереження в Пвар ID вибраної із списка зброї
		ShowPlayerDialog(playerid, D_DEAD, DIALOG_STYLE_INPUT, "Труп", "Ведіть кількіть патронів яку бажаєте забрати", "Продовжити", "Закрити");
	}
	case D_DEAD:
	{
		if(!response) return 1;
		new weaponidx;
		if(sscanf(inputtext, "d", weaponidx)) return SendClientMessage(playerid, -1, "Помилка! Ведіть число");

		new nslotDD = 0, listgun = GetPVarInt(playerid, "pListGun");
		new dIDcheck = CorpseIDNear[playerid]; //для зручності та оптимальності
		for(new i = 0; i <= 12; i++)
		{
			if(pDeadAct[dIDcheck][gunslot][i] == 0 || pDeadAct[dIDcheck][cartridges][i] == 0) continue; //якщо в слоті відсутня зброя або патрони, перевірка умови цикла та повторення
			if(nslotDD != listgun)  //якщо знайдено зброю, яка не являється обраною раніше в діалозі playerid
			{
				nslotDD++; //+1 змінній
				continue;
			}
			if(weaponidx > pDeadAct[dIDcheck][cartridges][i]) return SendClientMessage(playerid, -1, "[Думки] Тут немає стільки патронів");
			GivePlayerWeapon(playerid, pDeadAct[dIDcheck][gunslot][i], weaponidx); //Коли вибрана зброя в діалозі співпадає із номером слота, видаю зброю та пт

			pDeadAct[dIDcheck][cartridges][i] -= weaponidx; //віднімаю кількість пт для даного ID трупа.
			if(pDeadAct[dIDcheck][cartridges][i] <= 0) //Якщо патронів менше або рівно нулю
			{
				pDeadAct[dIDcheck][gunslot][i] = 0; //під даний слот присвоюю нульове значення
				pDeadAct[dIDcheck][cartridges][i] = 0;
			}
			pc_cmd_wander(playerid); //повторний виклик команди
			break;
		}
		return DeletePVar(playerid, "pListGun"); //В любому випадку повернути видалення пвара
	}
	return 1;
}

stock CreateDeathActor(playerid) //створення трупа
{
	new t_deadID = -1; //змінна зі значенням -1
	for(new i; i <= MaxDead; i++)
	{
		if(pDeadAct[i][DeadActorID]  == 0 && strlen(pDeadAct[i][deadName]) == 0) //якщо знайдено вільний слот
		{
			t_deadID = i; //змінній присвоюю значнння вільного слота
			break;
		}
	}
	if(t_deadID == -1) { //якщо цикл завершився але немає вільного слова під труп
		MaxDead++; //загальній кількості трупів +1
		t_deadID = MaxDead; 
	}
	new skins = GetPlayerSkin(playerid);

	GetPlayerPos(playerid, pDeadAct[t_deadID][xActor], pDeadAct[t_deadID][yActor], pDeadAct[t_deadID][zActor]); //запис поточних координат в масив
	pDeadAct[t_deadID][DeadActorID] = CreateActor(skins, pDeadAct[t_deadID][xActor], pDeadAct[t_deadID][yActor], pDeadAct[t_deadID][zActor], 0.0); //створення актора по вище збереженим координатам
	ApplyActorAnimation(pDeadAct[t_deadID][DeadActorID], "CRACK", "CRCKIDLE4", 4.1, false, true, true, true, 0); //анімація

	new textdead[61+MAX_PLAYER_NAME];
	format(textdead, sizeof(textdead), "Тіло: {FFFF00}%s\n{FFFFFF}Щоб обшукати ведіть {FFFF00}/wander", PI[playerid][pNames]);
	pDeadAct[t_deadID][deadLabel3D] = Create3DTextLabel(textdead, -1, pDeadAct[t_deadID][xActor], pDeadAct[t_deadID][yActor], pDeadAct[t_deadID][zActor], 15.0, 0);

	for (new i = 0; i <= 12; i++) //перевірка всіх слотів на зброю зі збереженням в масив
	{
    	GetPlayerWeaponData(playerid, i, pDeadAct[t_deadID][gunslot][i], pDeadAct[t_deadID][cartridges][i]);
	}
		
	pDeadAct[t_deadID][dead_timer] = SetTimerEx("removal_corpse", DESTRUCTION_TIMER, false, "d", t_deadID); //таймер видалення
	strmid(pDeadAct[t_deadID][deadName], PI[playerid][pNames], 0, strlen(PI[playerid][pNames]), 24);
	return 1;
}

forward removal_corpse(dIDnum); //видалення трупа
public removal_corpse(dIDnum)
{
	Delete3DTextLabel(pDeadAct[dIDnum][deadLabel3D]);
	DestroyActor(pDeadAct[dIDnum][DeadActorID]);

	pDeadAct[dIDnum][DeadActorID]  = 0;
	pDeadAct[dIDnum][CorpseLost] = false;
	pDeadAct[dIDnum][xActor] = 0.0;
	pDeadAct[dIDnum][yActor] = 0.0;
	pDeadAct[dIDnum][zActor] = 0.0;

	for(new i; i <= 12; i++)
	{
		pDeadAct[dIDnum][gunslot][i] = 0;
		pDeadAct[dIDnum][cartridges][i] = 0;
	}
	KillTimer(pDeadAct[dIDnum][dead_timer]);
	pDeadAct[dIDnum][dead_timer] = 0;
	pDeadAct[dIDnum][deadName] = EOS;
	
	if(MaxDead != 0 && pDeadAct[MaxDead][DeadActorID]  == 0 && strlen(pDeadAct[MaxDead][deadName]) == 0) return MaxDead--; //якщо останній слот трупа вільний, видаляю його
	return 1;
}

forward SearchBody(playerid);
public SearchBody(playerid) //для таймера, якщо труп раніше не був залутаний
{
	new dIDcheck = CorpseIDNear[playerid];
	pDeadAct[dIDcheck][CorpseLost] = true;

	ClearAnimations(playerid);
	pc_cmd_wander(playerid);
	return 1;
}

cmd:wander(playerid) //сама команда 
{
	if(GetPlayerState(playerid) == PLAYER_STATE_WASTED) return SendClientMessage(playerid, -1, "Помилка! Спробуйте пішніше."); //якщо гравець в стані смерті 
	new bool:radius_corpse = false;
	for(new i = 0; i <= MaxDead; i++)
	{
		if(IsPlayerInRangeOfPoint(playerid, 1.0, pDeadAct[i][xActor], pDeadAct[i][yActor], pDeadAct[i][zActor]))
		{
			radius_corpse = true;
			CorpseIDNear[playerid] = i;
			break;
		}
	}
	if(!radius_corpse) return SendClientMessage(playerid, -1, "Ви не знаходитесь около трупа!");
	ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.0, 0, true, 0, 0, 0);
	new txt[150], str[500], dIDcheck = CorpseIDNear[playerid];
	
	for(new i = 0; i <= 12; i++)
	{
		if(pDeadAct[dIDcheck][gunslot][i] == 0 || pDeadAct[dIDcheck][cartridges][i] == 0) continue;
		format(txt, sizeof(txt), "%s(%d пт)\n", DgunName[pDeadAct[dIDcheck][gunslot][i]], pDeadAct[dIDcheck][cartridges][i]);
		strcat(str, txt);
	}
	if(strlen(str) == 0) return SendClientMessage(playerid, -1, "Цей труп пустий");
	if(pDeadAct[dIDcheck][CorpseLost] == true) return ShowPlayerDialog(playerid, D_DEAD_AMMO, DIALOG_STYLE_LIST, "Труп", str, "Продовжити", "Закрити");
	
    GameTextForPlayer(playerid, "~g~~h~~h~loading...", SEARCH_CORPSE, 3);
	SetTimerEx("SearchBody", SEARCH_CORPSE, false, "i", playerid);
	return 1;
}
