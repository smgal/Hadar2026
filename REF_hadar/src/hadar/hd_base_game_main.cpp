
#include "hd_base_game_main.h"

#include "hd_base_config.h"
#include "hd_base_type.h"
#include "hd_base_pc_functor.h"

#include "hd_class_script.h"
#include "hd_class_select.h"
#include "hd_class_key_buffer.h"
#include "hd_class_console.h"

#include "hd_class_window_map.h"
#include "hd_class_window_console.h"
#include "hd_class_window_status.h"
#include "hd_class_window_battle.h"

#include <algorithm>

using namespace avej;

////////////////////////////////////////////////////////////////////////////////
// macro

#define CONSOLE_WRITE(format, var) \
	SPRINTF(sz_temp, 256, format, var); \
	console.Write(sz_temp);

#define CONSOLE_WRITE2(format, var1, var2) \
	SPRINTF(sz_temp, 256, format, var1, var2); \
	console.Write(sz_temp);

#define CONSOLE_WRITE4(format, var1, var2, var3, var4) \
	SPRINTF(sz_temp, 256, format, var1, var2, var3, var4); \
	console.Write(sz_temp);

#define NUM_OF_CONSCIOUS_PLAYER(player) std::for_each(player.begin(), player.end(), FnNumOfConscious<PcPlayer*>()).Result()
#define NUM_OF_CONSCIOUS_ENEMY(enemy) std::for_each(enemy.begin(), enemy.end(), FnNumOfConscious<PcEnemy*>()).Result()

////////////////////////////////////////////////////////////////////////////////
// private

namespace
{
	template <class type>
	class FnctDelete
	{
	public:
		void operator()(type obj)
		{
			delete obj;
		}
	};
}

////////////////////////////////////////////////////////////////////////////////
// class

namespace hadar
{
	GameMain* s_p_game_main;
}

////////////////////////////////////////////////////////////////////////////////
// class

hadar::GameMain::GameMain()
	: game_state(GAMESTATE_MAP)
{
	player.reserve(MAX_PLAYER);
	enemy.reserve(MAX_ENEMY);

	ASSERT(player.capacity() == MAX_PLAYER);
	ASSERT(enemy.capacity() == MAX_ENEMY);

	// save를 해야 하는 object의 목록 등록
	{
		//?? 헤더 파일을 만들어야 함
		save_list.push_back(&party);

		for (int i = 0; i < MAX_PLAYER; i++)
			save_list.push_back(&m_player[i]);

		save_list.push_back(&map);
		save_list.push_back(&game_option);
	}

	// party 초기화
	{
		// 외부에서 이 값이 수정되어져야 함
		party.x = -1;
		party.y = -1;
		//??
		party.ability.can_use_ESP = false;
		party.ability.can_use_special_magic = false;
	}

	// player 초기화
	{
		m_player[0].setDefault(0);

		m_player[0].setName("슴갈");
		m_player[0].class_ = 8;
		m_player[0].level[0] = 3;
		m_player[0].level[1] = 1;
		m_player[0].level[2] = 0;
		m_player[0].reviseAttribute();

/*@@ 이전 임시 party 멤버임

		m_player[4].setDefault(0);
		m_player[4].setName("Becrux");
		m_player[4].hp = 100;

		m_player[2].setDefault(0);
		m_player[2].setName("슴가");
		m_player[2].gender = PcPlayer::FEMALE;
		m_player[2].hp = 100;

		m_player[3].setDefault(0);
		m_player[3].setName("Lore Hunter");
		m_player[3].hp = 100;
		m_player[3].class_ = 2;

/* */
		for (int i = 0; i < sizeof(m_player) / sizeof(m_player[0]); i++)
		{
			m_player[i].order = i;
			player.push_back(&m_player[i]);
		}
	}
	
	// map 초기화
	{
		// map에게 default handler를 알려줌
		map.act_func[Map::ACT_BLOCK] = &GameMain::m_actBlock;
		map.act_func[Map::ACT_MOVE]  = &GameMain::m_actMove;
		map.act_func[Map::ACT_EVENT] = &GameMain::m_actEvent;
		map.act_func[Map::ACT_ENTER] = &GameMain::m_actEnter;
		map.act_func[Map::ACT_SIGN]  = &GameMain::m_actSign;
		map.act_func[Map::ACT_WATER] = &GameMain::m_actWater;
		map.act_func[Map::ACT_SWAMP] = &GameMain::m_actSwamp;
		map.act_func[Map::ACT_LAVA]  = &GameMain::m_actLava;
		map.act_func[Map::ACT_TALK]  = &GameMain::m_actTalk;
	}

	// window 초기화
	{
		// 아래 window들의 생성 순서는 정해져 있음

		// Map용 window
		{
			CWindow* pWindow = new CWindowMap(this);
			const config::Rect& region = config::REGION_MAP_WINDOW;
			pWindow->setRegion(region.x, region.y, region.w, region.h);
			window.push_back(pWindow);
		}

		// Console용 window
		{
			CWindow* pWindow = new CWindowConsole(this);
			const config::Rect& region = config::REGION_CONSOLE_WINDOW;
			pWindow->setRegion(region.x, region.y, region.w, region.h);
			window.push_back(pWindow);
		}

		// Status용 window
		{
			CWindow* pWindow = new CWindowStatus(this);
			const config::Rect& region = config::REGION_STATUS_WINDOW;
			pWindow->setRegion(region.x, region.y, region.w, region.h);
			window.push_back(pWindow);
		}

		// Battle용 window
		{
			CWindow* pWindow = new CWindowBattle(this);
			const config::Rect& region = config::REGION_MAP_WINDOW;
			pWindow->setRegion(region.x, region.y, region.w, region.h);
			pWindow->hide();
			window.push_back(pWindow);
		}
	}
}

hadar::GameMain::~GameMain(void)
{
	std::for_each(window.begin(), window.end(), FnctDelete<CWindow*>());
}

bool hadar::GameMain::loadMapFromFile(const char* sz_file_name)
{
	CFileReadStream stream(sz_file_name);

	if (!stream.isValid())
		return false;

	unsigned char byte;

	map.clearData();

	// 가장 먼저 map type의 판별이 있어야 함
	map.setType(Map::TYPE_TOWN);

	stream.Read(&byte, 1);
	map.width  = byte;

	stream.Read(&byte, 1);
	map.height = byte;

	for (int y = 0; y < map.height; y++)
	{
		stream.Read(&map.data[y][0], map.width);
	}

	return true;
}

bool hadar::GameMain::loadScript(const char* sz_file_name)
{
	Script::registerScriptFileName(sz_file_name);
	game_option.script_file = sz_file_name;

	Script script(Script::MODE_MAP, 0);

	return true;
}

void hadar::GameMain::changeWindowForBattle(void)
{
	window[WINDOWTYPE_MAP]->hide();
	window[WINDOWTYPE_BATTLE]->show();
}

void hadar::GameMain::changeWindowForField(void)
{
	window[WINDOWTYPE_BATTLE]->hide();
	window[WINDOWTYPE_MAP]->show();
}

bool hadar::GameMain::isValidWarpPos(int x, int y)
{
	return ((x >= CWindowMap::_X_RADIUS) && (x < map.width-CWindowMap::_X_RADIUS) && (y >= CWindowMap::_Y_RADIUS) && (y < map.height-CWindowMap::_Y_RADIUS));
}

int hadar::GameMain::selectPlayer(const char* szTitle)
{
	if (szTitle == NULL)
		szTitle = "한명을 고르시오 ---";

	MenuList menu;

	menu.reserve(MAX_PLAYER+1);

	menu.push_back(szTitle);

	int realPlayer[MAX_PLAYER];
	int nReal = 0;
	int count = 0;
	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj, ++count)
	{
		ASSERT(nReal < MAX_PLAYER);

		if ((*obj)->isValid())
		{
			menu.push_back((*obj)->getName());
			realPlayer[nReal++] = count;
		}
	}

	ASSERT(nReal > 0);

	int selected = MenuSelection(menu)();

	--selected;

	return (selected >= 0) ? realPlayer[selected] : -1;
}

int hadar::GameMain::selectEnemy(void)
{
	int num_enabled = enemy.size();
	int selected = 0;
	
	do
	{
		window[WINDOWTYPE_BATTLE]->display(1, selected);

		bool bUpdate = false;

		do
		{
			unsigned short key;
			while ((key = KeyBuffer::getKeyBuffer().getKey()) < 0)
				;

			switch (key)
			{
			case avej::KEY_UP:
			case avej::KEY_DOWN:
				{
					int dy = (key == avej::KEY_UP) ? -1 : +1;
					selected += dy;

					if (selected < 0)
						selected = num_enabled - 1;
					if (selected >= num_enabled)
						selected = 0;

					bUpdate = true;
				}
				break;
/* 무효 숫자를 돌려주지 않게 함
			case avej::KEY_BUTTON_A:
				selected = -1;
				// pass through
*/
			case avej::KEY_BUTTON_B:
				window[WINDOWTYPE_BATTLE]->display(1);
				return selected;
			}
		} while (!bUpdate);
		
	} while (1);
}

void hadar::GameMain::detectGameOver(void)
{
	// 전처리
	std::for_each(player.begin(), player.end(), FnCheckCondition<PcPlayer*>());

	// 실제 생존해 있는 숫자를 확인
	int num_alive = NUM_OF_CONSCIOUS_PLAYER(player);

	if (num_alive == 0)
		proccessGameOver(EXITCODE_BY_ACCIDENT);
}

bool hadar::GameMain::checkEndOfBattle(ENDBATTLE& exitCode)
{
	int num_alive = NUM_OF_CONSCIOUS_PLAYER(player);

	if (num_alive == 0)
	{
		exitCode = ENDBATTLE_LOSE;
		return true;
	}

	num_alive = NUM_OF_CONSCIOUS_ENEMY(enemy);

	if (num_alive == 0)
	{
		exitCode = ENDBATTLE_WIN;
		return true;
	}

	exitCode = ENDBATTLE_NONE;

	return false;
}

void hadar::GameMain::plusGold(void)
{
	int num_gold = std::for_each(enemy.begin(), enemy.end(), FnPlusGold<PcEnemy*>()).Result();
	
	party.gold += num_gold;

	game::console::writeConsole(15, 3, "일행은 ", avej::IntToStr(num_gold)(), "개의 금을 얻었다.");
}

int hadar::GameMain::registerEnemy(int index)
{
	int ix_enemy = enemy.size();

	m_enemy[ix_enemy] << getEnemyDataFromEnemyTable(index);
	m_enemy[ix_enemy].ed_number = index;
	enemy.push_back(&m_enemy[ix_enemy]);

	return ix_enemy;
}

// 정상적인 승부로 끝이나면 true, 도망을 치면 false
hadar::GameMain::BATTLERESULT hadar::GameMain::runBattleMode(bool is_assualt_mode)
{
	BATTLERESULT result = BATTLERESULT_WIN;
	game_state = GAMESTATE_BATTLE;

	ENDBATTLE exitCode = ENDBATTLE_NONE;
	int battle[MAX_PLAYER][4];

	do
	{
		if (!is_assualt_mode)
			goto QAZ;

		CLEAR_MEMORY(battle);

		window[WINDOWTYPE_BATTLE]->display(0);

		// 명령 등록
		{
			bool bAutoBattle = false;

			for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
			{
				int order = (*obj)->order;

				if ((*obj)->isConscious())
				{
					if (!bAutoBattle)
					{
						MenuList menu;

						avej::string str1;
						str1 += (*obj)->getName();
						str1 += "의 전투 모드 ===>";

						avej::string str2;
						str2 += "한 명의 적을 ";
						str2 += resource::getWeaponName((*obj)->weapon).sz_name;
						str2 += resource::getWeaponName((*obj)->weapon).sz_josa_with;
						str2 += "로 공격";

						menu.reserve(8);
						menu.push_back(str1);
						menu.push_back(str2);
						menu.push_back("한 명의 적에게 마법 공격");
						menu.push_back("모든 적에게 마법 공격");
						menu.push_back("적에게 특수 마법 공격");
						menu.push_back("일행을 치료");
						menu.push_back("적에게 초능력 사용");

						if (order == 0)
							menu.push_back("일행에게 무조건 공격 할 것을 지시");
						else
							menu.push_back("도망을 시도함");

						int selected = MenuSelection(menu)();

						if (selected != 1)
							LoreConsole::getConsole().clear();

						if ((selected == 7) && (order == 0))
						{
							selected = 8;
							bAutoBattle = true;
						}

						battle[order][1] = selected;
					}
					else
					{
						battle[order][1] = 8;
					}

					// 메뉴 선택에 따른 동작 방식 결정
					switch (battle[order][1])
					{
					case 1:
						{
							int selected = selectEnemy();
							LoreConsole::getConsole().clear();
							if (selected == -1)
								battle[order][1] = 0;
							battle[order][2] = (*obj)->weapon;
							battle[order][3] = selected;
						}
						break;
					case 2:
					case 3:
					case 4:
						{
							int  ixMagicOffset = 0;
							int  num_enabled = 7;
							bool isSingleAttack = true;

							switch (battle[order][1])
							{
							case 2:
								ixMagicOffset = 0;
								{
									int level2 = (*obj)->level[1];
									if      (level2 <= 1)
										num_enabled = 2;
									else if (level2 <= 3)
										num_enabled = 3;
									else if (level2 <= 7)
										num_enabled = 4;
									else if (level2 <= 11)
										num_enabled = 5;
									else if (level2 <= 15)
										num_enabled = 6;
								}
								break;
							case 3:
								ixMagicOffset = 6;
								{
									int level2 = (*obj)->level[1];
									if      (level2 <= 1)
										num_enabled = 1;
									else if (level2 <= 2)
										num_enabled = 2;
									else if (level2 <= 5)
										num_enabled = 3;
									else if (level2 <= 9)
										num_enabled = 4;
									else if (level2 <= 13)
										num_enabled = 5;
									else if (level2 <= 17)
										num_enabled = 6;
								}
								isSingleAttack = false;
								break;
							case 4:
								ixMagicOffset = 12;
								{
									int level2 = (*obj)->level[1];
									if      (level2 <= 4)
										num_enabled = 1;
									else if (level2 <= 9)
										num_enabled = 2;
									else if (level2 <= 11)
										num_enabled = 3;
									else if (level2 <= 13)
										num_enabled = 4;
									else if (level2 <= 15)
										num_enabled = 5;
									else if (level2 <= 17)
										num_enabled = 6;
								}
								break;
							default:
								ASSERT(false);
							}

							MenuList menu;

							menu.reserve(8);
							menu.push_back("");
							menu.push_back("없음");
							for (int i = 0; i < 6; i++)
								menu.push_back(resource::getMagicName(i+1+ixMagicOffset).sz_name);

							int selected = MenuSelection(menu, num_enabled)();
							int ix_enemy  = -1;

							if ((selected == 0) || (selected == 1))
								battle[order][1] = 0;
							else if (isSingleAttack)
								ix_enemy = selectEnemy();

							LoreConsole::getConsole().clear();

							battle[order][2] = selected - 1;
							battle[order][3] = ix_enemy;
						}
						break;
					case 5:
						player[order]->castCureSpell();
						break;
					case 6:
						{
							MenuList menu;

							menu.reserve(8);
							menu.push_back("");
							for (int i = 0; i < 5; i++)
								menu.push_back(resource::getMagicName(i+1+40).sz_name);

							int selected = MenuSelection(menu)();
							int ix_enemy  = -1;

							if (selected == 0)
								battle[order][1] = 0;
							else
								ix_enemy = selectEnemy();

							LoreConsole::getConsole().clear();

							battle[order][2] = selected;
							battle[order][3] = ix_enemy;

							if ((ix_enemy < 0) || (enemy[ix_enemy]->unconscious > 0) || (enemy[ix_enemy]->dead > 0))
								battle[order][1] = 0;
						}
						break;
					case 8:
						switch ((*obj)->class_)
						{
						case  0:
						case  1:
						case  4:
						case  5:
						case  6:
						case  7:
						case  8:
						case 10:
							battle[order][1] = 1;
							battle[order][2] = (*obj)->weapon;
							battle[order][3] = 0;
							break;
						case  2:
						case  9:
							battle[order][1] = 2;

							switch ((*obj)->level[1])
							{
							case 0:
							case 1:
							case 2:
							case 3:
								battle[order][2] = 1;
								break;
							case 4:
							case 5:
							case 6:
							case 7:
							case 8:
							case 9:
							case 10:
							case 11:
								battle[order][2] = 2;
								break;
							default:
								battle[order][2] = 3;
								break;
							}
							battle[order][3] = 0;
							break;
						case  3:
							battle[order][1] = 6;
							battle[order][2] = 5;
							{
								int target = 0;
								for (int ix_enemy = 1; ix_enemy < int(enemy.size()); ++ix_enemy)
								{ // @@ dead 맞나?
									if ((enemy[ix_enemy]->unconscious == 0) && (enemy[ix_enemy]->dead))
										target = ix_enemy;
								}
								battle[order][3] = target;
							}

							break;
						default:
							ASSERT(false);
						}
						break;
					}
				}
			}
		}

		LoreConsole::getConsole().clear();

		// 명령 해석
		{
			for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
			{
				if ((*obj)->isConscious())
				{
					int order = (*obj)->order;

					static SmSet s_printMessage("0,4,6..8");

					if (s_printMessage.isSet(battle[order][1]))
					{
						avej::string s = getBattleMessage(**obj, battle[order][1], battle[order][2], *enemy[battle[order][3]]);
						LoreConsole::getConsole().setTextColorIndex(15);
						LoreConsole::getConsole().Write(s);
					}

					switch (battle[order][1])
					{
						case 1:
							player[order]->attackWithWeapon(battle[order][2], battle[order][3]);
							break;
						case 2:
							player[order]->castSpellToOne(battle[order][2], battle[order][3]);
							break;
						case 3:
							player[order]->castSpellToAll(battle[order][2]);
							break;
						case 4:
							player[order]->castSpellWithSpecialAbility(battle[order][2], battle[order][3]);
							break;
						case 6:
							player[order]->useESPForBattle(battle[order][2], battle[order][3]);
							break;
						case 7:
							{
								if ((*obj)->tryToRunAway())
								{
									game::pressAnyKey();

									LoreConsole::getConsole().clear();

									exitCode = ENDBATTLE_RUN_AWAY;

									goto END_OF_BATTLE;
								}
							}
					}
					
					LoreConsole::getConsole().Write("");
				}
			}
			
			window[WINDOWTYPE_BATTLE]->display(1);

			LoreConsole::getConsole().Write("");
			LoreConsole::getConsole().display();
			game::updateScreen();
			game::pressAnyKey();
		}
QAZ:
		LoreConsole::getConsole().clear();

		{
			for (std::vector<PcEnemy*>::iterator obj = enemy.begin(); obj != enemy.end(); ++obj)
			{
				if ((*obj)->poison > 0)
				{
					if ((*obj)->unconscious > 0)
					{
						(*obj)->dead = 1;
					}
					else
					{
						(*obj)->hp -= (*obj)->poison;
						if ((*obj)->hp <= 0)
							(*obj)->unconscious = 1;
					}
				}
				if (((*obj)->unconscious == 0) && ((*obj)->dead == 0))
				{
					(*obj)->attack();
				}
			}
		}

		window[WINDOWTYPE_STATUS]->setUpdateFlag();
		window[WINDOWTYPE_STATUS]->display();

		game::updateScreen();

		if (checkEndOfBattle(exitCode))
			break;

		is_assualt_mode = true;

		// 원작에서는 적 공격 후에 Press Any Key 문자 출력이 없었음
		game::pressAnyKey();

	} while (1);

END_OF_BATTLE:
	switch (exitCode)
	{
	case ENDBATTLE_LOSE:
		proccessGameOver(EXITCODE_BY_ENEMY);
		return BATTLERESULT_LOSE;
	case ENDBATTLE_WIN:
		LoreConsole::getConsole().clear();
		plusGold();
		break;
	case ENDBATTLE_RUN_AWAY:
		result = BATTLERESULT_EVADE;
		break;
	default:
		ASSERT(false);
	}

	window[WINDOWTYPE_MAP]->setUpdateFlag();
	window[WINDOWTYPE_MAP]->display();

	game_state = GAMESTATE_MAP;

	return result;
}

void hadar::GameMain::encounterEnemy(void)
{
	if (map.getEncounteredEnemy() == 0)
		return;

	enemy.clear();

	int nEnemy = (AvejUtil::random(party.max_enemy) + 1);

	int enemyAgility = 0;
	for (int i = 0; i < nEnemy; i++)
	{
		int ix_enemy = map.getEncounteredEnemy();
		ASSERT(ix_enemy > 0);

		int index = registerEnemy(ix_enemy);
		enemyAgility += enemy[index]->agility;
	}

	ASSERT(nEnemy > 0);
	enemyAgility /= nEnemy;

	LoreConsole& console = LoreConsole::getConsole();

	console.clear();

	console.setTextColorIndex(12);
	console.Write("적이 출현했다 !!!");
	console.Write("");

	console.setTextColorIndex(11);
	console.Write("적의 평균 민첩성");
	{
		char sz_temp[256];
		int avgAgility = std::for_each(enemy.begin(), enemy.end(), FnAverageAgility<PcEnemy*>()).Result();
		CONSOLE_WRITE(" : %d", avgAgility);
	}

	console.display();

	changeWindowForBattle();

	game::updateScreen();

	// 위의 글자를 출력하기 위해서 임시로 console 창의 사이즈를 줄인다.
	config::Rect savedRect;
	int reducedSize = 4*config::DEFAULT_FONT_HEIGHT;

	window[WINDOWTYPE_CONSOLE]->getRegion(&savedRect.x, &savedRect.y, &savedRect.w, &savedRect.h);
	window[WINDOWTYPE_CONSOLE]->setRegion(savedRect.x, savedRect.y+reducedSize, savedRect.w, savedRect.h-reducedSize);

	MenuList menu;

	menu.reserve(3);
	menu.push_back("");
	menu.push_back("적과 교전한다");
	menu.push_back("도망간다");

	bool willingToAvoidBattle = (MenuSelection(menu)() != 1);

	// console 창의 사이즈를 복귀시킨다.
	window[WINDOWTYPE_CONSOLE]->setRegion(savedRect.x, savedRect.y, savedRect.w, savedRect.h);

	// '도망간다'를 선택했을 때 전 영역을 bg color로 채우기 위함
	console.clear();
	console.display();

	do
	{
		bool is_assualt_mode;

		if (willingToAvoidBattle)
		{
			int avgLuck    = std::for_each(player.begin(), player.end(), FnAverageLuck<PcPlayer*>()).Result();
			int avgAgility = std::for_each(enemy.begin(), enemy.end(), FnAverageAgility<PcEnemy*>()).Result();

			if (avgLuck > avgAgility)
				break; // 전투를 회피

			is_assualt_mode = false;
		}
		else
		{
			int avgAgility1 = std::for_each(player.begin(), player.end(), FnAverageAgility<PcPlayer*>()).Result();
			int avgAgility2 = std::for_each(enemy.begin(), enemy.end(), FnAverageAgility<PcEnemy*>()).Result();

			is_assualt_mode = (avgAgility1 > avgAgility2);
		}

		runBattleMode(is_assualt_mode);
	} while(0);

	changeWindowForField();
}

void hadar::GameMain::showPartyStatus()
{
	char sz_temp[256];

	LoreConsole& console = LoreConsole::getConsole();

	console.clear();
	console.setTextColorIndex(7);

	CONSOLE_WRITE("X 축 = %d", party.x);
	CONSOLE_WRITE("Y 축 = %d", party.y);
	CONSOLE_WRITE("남은 식량 = %d", party.food);
	CONSOLE_WRITE("남은 황금 = %d", party.gold);

	console.Write("");

	CONSOLE_WRITE("마법의 횃불 : %d", party.ability.magic_torch);
	CONSOLE_WRITE("공중 부상   : %d", party.ability.levitation);
	CONSOLE_WRITE("물위를 걸음 : %d", party.ability.walk_on_water);
	CONSOLE_WRITE("늪위를 걸음 : %d", party.ability.walk_on_swamp);

	console.display();
}

void hadar::GameMain::showCharacterStatus(void)
{
	int selected = selectPlayer("능력을 보고싶은 인물을 선택하시오");
	if (selected >= 0)
	{
		ASSERT(selected < MAX_PLAYER);
		showCharacterStatus(*player[selected]);
	}
}

void hadar::GameMain::showCharacterStatus(const PcPlayer& selected)
{
	ASSERT(selected.isValid());

	if (!selected.isValid())
		return;

	char sz_temp[256];

	LoreConsole& console = LoreConsole::getConsole();

	console.clear();

	console.setTextColorIndex(11);
	CONSOLE_WRITE("# 이름 : %s", selected.getName())
	CONSOLE_WRITE("# 성별 : %s", selected.getGenderName())
	CONSOLE_WRITE("# 계급 : %s", selected.getClassName())

	console.Write("");

	console.setTextColorIndex(3);
	CONSOLE_WRITE("체력   : %d", selected.strength)
	CONSOLE_WRITE("정신력 : %d", selected.mentality)
	CONSOLE_WRITE("집중력 : %d", selected.concentration)
	CONSOLE_WRITE("인내력 : %d", selected.endurance)
	CONSOLE_WRITE("저항력 : %d", selected.resistance)
	CONSOLE_WRITE("민첩성 : %d", selected.agility)
	CONSOLE_WRITE("행운   : %d", selected.luck)

	console.display();
	game::updateScreen();

	game::pressAnyKey();

	console.clear();

	// 이 부분은 한 번 더 반복
	console.setTextColorIndex(11);
	CONSOLE_WRITE("# 이름 : %s", selected.getName())
	CONSOLE_WRITE("# 성별 : %s", selected.getGenderName())
	CONSOLE_WRITE("# 계급 : %s", selected.getClassName())

	console.Write("");

	console.setTextColorIndex(3);
	CONSOLE_WRITE2("무기의 정확성   : %2d    전투 레벨   : %2d", selected.accuracy[0], selected.level[0])
	CONSOLE_WRITE2("정신력의 정확성 : %2d    마법 레벨   : %2d", selected.accuracy[1], selected.level[1])
	CONSOLE_WRITE2("초감각의 정확성 : %2d    초감각 레벨 : %2d", selected.accuracy[2], selected.level[2])
	CONSOLE_WRITE("## 경험치   : %d", selected.experience)

	console.Write("");

	console.setTextColorIndex(2);
	CONSOLE_WRITE("사용 무기 - %s", selected.getWeaponName())
	CONSOLE_WRITE2("방패 - %s           갑옷 - %s", selected.getShieldName(), selected.getArmorName())

	console.display();
}

void hadar::GameMain::showQuickView(void)
{
	char sz_temp[256];

	LoreConsole& console = LoreConsole::getConsole();

	console.clear();

	console.setTextColorIndex(15);
	console.Write("                이름    중독  의식불명    죽음");
	console.Write("");

	console.setTextColorIndex(7);
	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
	{
		if ((*obj)->isValid())
		{
			CONSOLE_WRITE4("%20s   %5d %9d %7d", (*obj)->getName(), (*obj)->poison, (*obj)->unconscious, (*obj)->dead)
		}
	}

	console.display();
}

void hadar::GameMain::castSpell(void)
{
	int selected = selectPlayer();
	if (selected < 0)
		return;

	if (!player[selected]->isConscious())
	{
		game::console::writeConsole(7, 2, player[selected]->get3rdPersonName(), "는 마법을 사용할 수 있는 상태가 아닙니다.");
		return;
	}

	MenuList menu;

	menu.reserve(4);
	menu.push_back("사용할 마법의 종류 ===>");
	menu.push_back("공격 마법");
	menu.push_back("치료 마법");
	menu.push_back("변화 마법");

	switch (MenuSelection(menu)())
	{
	case 1:
		player[selected]->castAttackSpell();
		break;
	case 2:
		player[selected]->castCureSpell();
		break;
	case 3:
		player[selected]->castPhenominaSpell();
		break;
	default:
		break;
	}
}

void hadar::GameMain::useExtrasense(void)
{
	LoreConsole::getConsole().clear();

	int selected = selectPlayer();
	if (selected < 0)
		return;

	if (!player[selected]->isConscious())
	{
		game::console::writeConsole(7, 2, player[selected]->get3rdPersonName(), "는 초감각을 사용할수있는 상태가 아닙니다.");
		return;
	}

	player[selected]->useESP();
}

void hadar::GameMain::restHere(void)
{
	LoreConsole& console = LoreConsole::getConsole();

	console.clear();

	std::for_each(player.begin(), player.end(), FnRestHere<PcPlayer*>());

	if (party.ability.magic_torch > 0)
		--party.ability.magic_torch;

	party.ability.levitation  = 0;
	party.ability.walk_on_water = 0;
	party.ability.walk_on_swamp = 0;
	party.ability.mind_control = 0;

	console.display();

	window[WINDOWTYPE_STATUS]->setUpdateFlag();
	window[WINDOWTYPE_STATUS]->display();

	game::updateScreen();
	//@@ 필요한가?
	game::pressAnyKey();
}

namespace
{
	///////////////////////////////////////////////////////////////////////////////
	// GetSaveFileName class;
	const char* SAVE_FILE_NAME = "gamedat";
	const char* SAVE_FILE_EXT = ".sav";

	class GetSaveFileName
	{
	public:
		GetSaveFileName(int index)
		{
			m_name += "./";
			m_name += SAVE_FILE_NAME;
			m_name += avej::IntToStr(index)();
			m_name += SAVE_FILE_EXT;
		}
		~GetSaveFileName(void)
		{
			m_name += "./";
		}
		operator const char*(void)
		{
			return m_name;
		}

	private:
		avej::string m_name;

	};
}

bool hadar::GameMain::loadGame(int index)
{
	SerializedStream stream(GetSaveFileName(index), SerializedStream::STREAM_TYPE_READ);

	for (std::vector<Serialized*>::iterator obj = save_list.begin(); obj != save_list.end(); ++obj)
	{
		stream >> *(*obj);
	}

	Script::registerScriptFileName(game_option.script_file);

	window[WINDOWTYPE_MAP]->setUpdateFlag();
	window[WINDOWTYPE_STATUS]->setUpdateFlag();

	return true;
}

bool hadar::GameMain::saveGame(int index)
{
	SerializedStream stream(GetSaveFileName(index), SerializedStream::STREAM_TYPE_WRITE);

	for (std::vector<Serialized*>::iterator obj = save_list.begin(); obj != save_list.end(); ++obj)
	{
		stream << *(*obj);
	}

	return true;
}

bool hadar::GameMain::selectLoadMenu(void)
{
	MenuList menu;

	menu.push_back("불러 내고 싶은 게임을 선택하십시오.");
	menu.push_back("없습니다");
	menu.push_back("본 게임 데이타");
	menu.push_back("게임 데이타 1 (부)");
	menu.push_back("게임 데이타 2 (부)");
	menu.push_back("게임 데이타 3 (부)");

	int selected = MenuSelection(menu)();

	if (selected <= 1)
		return false;

	{
		LoreConsole& console = LoreConsole::getConsole();

		console.clear();
		console.setTextColorIndex(11);
		console.Write("저장했던 게임을 다시 불러옵니다");
		console.display();

		// 0~3 사의 값
		if (!loadGame(selected-2))
		{
			// 파일이 존재 하지 않음
			//?? 관련된 메시지를 보내고 다시 메뉴를 선택하게 해야 함
			//?? 또는 자동으로 데이터가 있는지를 확인하여 메뉴를 하이라이트를 시켜야 함
			return false;
		}

		window[WINDOWTYPE_MAP]->setUpdateFlag();
		window[WINDOWTYPE_STATUS]->setUpdateFlag();
		console.clear();
		console.display();
	}

	return true;
}

bool hadar::GameMain::selectSaveMenu(void)
{
	MenuList menu;

	menu.push_back("게임의 저장 장소를 선택하십시오.");
	menu.push_back("없습니다");
	menu.push_back("본 게임 데이타");
	menu.push_back("게임 데이타 1 (부)");
	menu.push_back("게임 데이타 2 (부)");
	menu.push_back("게임 데이타 3 (부)");

	int selected = MenuSelection(menu)();

	if (selected <= 1)
		return false;

	{
		LoreConsole& console = LoreConsole::getConsole();

		console.clear();
		console.setTextColorIndex(12);
		console.Write("현재의 게임을 저장합니다");
		console.display();

		// 0~3 사의 값
		if (!saveGame(selected-2))
		{
			//?? 실패 했음을 알려 줘야 하나?
			return false;
		}

		console.setTextColorIndex(7);
		console.Write("");
		console.Write("성공했습니다");
		console.display();

		game::pressAnyKey();
	}

	return true;
}

void hadar::GameMain::selectGameOption(void)
{
	MenuList menu;

	menu.reserve(7);
	menu.push_back("게임 선택 상황");
	menu.push_back("난이도 조절");
	menu.push_back("정식 일행의 순서 정렬");
	menu.push_back("일행에서 제외 시킴");
	menu.push_back("이전의 게임을 재개");
	menu.push_back("현재의 게임을 저장");
	menu.push_back("게임을 마침");

	int selected = MenuSelection(menu)();

	switch (selected)
	{
	case 0:
		break;
	case 1:
		// 전투시 출현하는 적의 최대치 기입
		{
			menu.clear();
			menu.push_back("한번에 출현하는 적들의 최대치를 기입하십시오");
			menu.push_back("3명의 적들");
			menu.push_back("4명의 적들");
			menu.push_back("5명의 적들");
			menu.push_back("6명의 적들");
			menu.push_back("7명의 적들");

			int selected = MenuSelection(menu, -1, party.max_enemy - 2)();

			if (selected == 0)
				break;

			party.max_enemy = selected + 2;
		}

		// 전투시 출현하는 적의 최대치 기입
		{
			menu.clear();
			menu.push_back("일행들의 지금 성격은 어떻습니까 ?");
			menu.push_back("일부러 전투를 피하고 싶다");
			menu.push_back("너무 잦은 전투는 원하지 않는다");
			menu.push_back("마주친 적과는 전투를 하겠다");
			menu.push_back("보이는 적들과는 모두 전투하겠다");
			menu.push_back("그들은 피에 굶주려 있다");

			int selected = MenuSelection(menu, -1, 6 - party.encounter)();

			if (selected == 0)
				break;

			party.encounter = 6 - selected;
		}
		break;
	case 2:
		{
			int  ix_player;
			int  indexTable[6] = {0, };
			int* pIndex = &indexTable[1];

			LoreConsole& console = LoreConsole::getConsole();

			console.clear();

			console.setTextColorIndex(12);
			console.Write("현재의 일원의 전투 순서를 정렬 하십시오.");
			console.Write("");
			console.display();

			menu.clear();
			menu.push_back("@B순서를 바꿀 일원 1@@");

			for (ix_player = 1; ix_player < 5; ix_player++)
			{
				if (player[ix_player]->isValid())
				{
					menu.push_back(player[ix_player]->getName());
					*pIndex++ = ix_player;
				}
			}

			// 주인공을 제외한 일행이 1명 이하라면 이 기능을 수행할 필요가 없다.
			if (menu.size() < 3)
			{
				LoreConsole& console = LoreConsole::getConsole();

				console.clear();
				console.setTextColorIndex(7);
				console.Write("전투 순서를 정렬 할 필요가 없습니다.");
				console.display();

				game::pressAnyKey();

				break;
			}

			// 위의 글자를 출력하기 위해서 임시로 console 창의 사이즈를 줄인다.
			config::Rect savedRect;
			int reducedSize = 3*config::DEFAULT_FONT_HEIGHT;

			window[WINDOWTYPE_CONSOLE]->getRegion(&savedRect.x, &savedRect.y, &savedRect.w, &savedRect.h);
			window[WINDOWTYPE_CONSOLE]->setRegion(savedRect.x, savedRect.y+reducedSize, savedRect.w, savedRect.h-reducedSize);

			do
			{
				int selected1 = MenuSelection(menu)();
				if (selected1 == 0)
					break;

				menu[0] = "@B순서를 바꿀 일원 2@@";

				int selected2 = MenuSelection(menu)();
				if (selected2 == 0)
					break;

				if (selected1 != selected2)
				{
					int ixPlayer1 = indexTable[selected1];
					int ixPlayer2 = indexTable[selected2];
					assert(ixPlayer1 > 0 && ixPlayer1 < 6);
					assert(ixPlayer2 > 0 && ixPlayer2 < 6);

					if (ixPlayer1 > ixPlayer2)
						std::swap(ixPlayer1, ixPlayer2);

					assert(ixPlayer1 < ixPlayer2);

					// 실제 등록 순서를 바꾸기
					std::swap(player[ixPlayer1], player[ixPlayer2]);
					// order는 등록 번호이므로 이전과 같아야 한다
					std::swap(player[ixPlayer1]->order, player[ixPlayer2]->order);
				}

				window[WINDOWTYPE_STATUS]->setUpdateFlag();
				window[WINDOWTYPE_STATUS]->display();
			} while(0);

			// console 창의 사이즈를 복귀시킨다.
			window[WINDOWTYPE_CONSOLE]->setRegion(savedRect.x, savedRect.y, savedRect.w, savedRect.h);

			console.clear();
		}
			
		break;
	case 3:
		{
			int  ix_player;
			int  indexTable[6] = {0, };
			int* pIndex = &indexTable[1];

			menu.clear();
			menu.push_back("@C일행에서 제외 시키고 싶은 사람을 고르십시오.@@");

			for (ix_player = 1; ix_player < 6; ix_player++)
			{
				if (player[ix_player]->isValid())
				{
					menu.push_back(player[ix_player]->getName());
					*pIndex++ = ix_player;
				}
			}

			// 주인공뿐이라면 이 기능을 수행할 필요가 없다.
			if (menu.size() < 2)
			{
				LoreConsole& console = LoreConsole::getConsole();

				console.clear();
				console.setTextColorIndex(7);
				console.Write("제외시킬 일행이 없습니다.");
				console.display();

				game::pressAnyKey();

				break;
			}

			int selected1 = MenuSelection(menu)();
			if (selected1 == 0)
				break;

			ix_player = indexTable[selected1];
			assert(ix_player > 0 && ix_player < 6);

			player[ix_player]->setName("");

			window[WINDOWTYPE_STATUS]->setUpdateFlag();
			window[WINDOWTYPE_STATUS]->display();
		}
		break;
	case 4:
		selectLoadMenu();
		break;
	case 5:
		selectSaveMenu();
		break;
	case 6:
		proccessGameOver(EXITCODE_BY_USER);
		break;
	}
}

void hadar::GameMain::selectMainMenu(void)
{
	MenuList menu;

	menu.reserve(8);
	menu.push_back("당신의 명령을 고르시오 ===>");
	menu.push_back("일행의 상황을 본다");
	menu.push_back("개인의 상황을 본다");
	menu.push_back("일행의 건강 상태를 본다");
	menu.push_back("마법을 사용한다");
	menu.push_back("초능력을 사용한다");
	menu.push_back("여기서 쉰다");
	menu.push_back("게임 선택 상황");

	int selected = MenuSelection(menu)();

	switch (selected)
	{
	case 0:
		break;
	case 1:
		showPartyStatus();
		break;
	case 2:
		showCharacterStatus();
		break;
	case 3:
		showQuickView();
		break;
	case 4:
		castSpell();
		break;
	case 5:
		useExtrasense();
		break;
	case 6:
		restHere();
		break;
	case 7:
		selectGameOption();
		break;
	default:
		ASSERT(0);
	}
}

void hadar::GameMain::proccessGameOver(EXITCODE code)
{
	switch (code)
	{
	case EXITCODE_BY_USER:
		{
			MenuList menu;

			menu.push_back("정말로 끝내겠습니까 ?"); // 원래는 10번 색
			menu.push_back("       << 아니오 >>");
			menu.push_back("       <<   예   >>");

			if (MenuSelection(menu)() != 2)
				return;
		}
		break;
	case EXITCODE_BY_ACCIDENT:
		{
			LoreConsole& console = LoreConsole::getConsole();

			console.clear();
			console.setTextColorIndex(13);
			console.Write("일행은 모험중에 모두 목숨을 잃었다.");
			console.display();

			window[WINDOWTYPE_MAP]->display();

			window[WINDOWTYPE_STATUS]->setUpdateFlag();
			window[WINDOWTYPE_STATUS]->display();

			game::updateScreen();

			game::pressAnyKey();

			if (selectLoadMenu())
				return;
		}
		break;
	case EXITCODE_BY_ENEMY:
		{
			LoreConsole& console = LoreConsole::getConsole();

			console.clear();
			console.setTextColorIndex(13);
			console.Write("일행은 모두 전투에서 패했다 !!");
			console.display();

			game::pressAnyKey();

			console.clear();

			MenuList menu;
			menu.reserve(8);
			menu.push_back("    @A어떻게 하시겠습니까 ?@@");
			menu.push_back("   이전의 게임을 재개한다");
			menu.push_back("       게임을 끝낸다");

			int selected = MenuSelection(menu)();

			if (selected == 1)
			{
				if (selectLoadMenu())
					return;
			}
		}
		break;
	case EXITCODE_BY_FORCE:
		// 특별하게 취해야할 동작이 없음
		break;
	default:
		ASSERT(false);
	}

	throw ExceptionExitGame();
}

bool hadar::GameMain::process(void)
{
	p_gfx_device->BeginDraw();

	if (hadar::KeyBuffer::getKeyBuffer().isKeyPressed())
	{
		UINT16 key = KeyBuffer::getKeyBuffer().getKey();
		bool bTimePassed = true;

		assert(key >= 0);

		// command 처리
		switch (key)
		{
		case 'P':
		case 'p':
			showPartyStatus();
			break;
		case 'V':
		case 'v':
			showCharacterStatus();
			break;
		case 'Q':
		case 'q':
			showQuickView();
			break;
		case 'C':
		case 'c':
			castSpell();
			break;
		case 'E':
		case 'e':
			useExtrasense();
			break;
		case 'R':
		case 'r':
			restHere();
			break;
		case 'G':
		case 'g':
			selectGameOption();
			break;
		case avej::KEY_SELECT:
			// space 처리
			selectMainMenu();
			break;
		default:
			bTimePassed = false;
		}
		
		{
			// 화살표 키처리
			int x1 = 0, y1 = 0;
			bool keyPressed = true;

			switch (key)
			{
				case KEY_UP:    y1 = -1; break;
				case KEY_DOWN:  y1 =  1; break;
				case KEY_LEFT:  x1 = -1; break;
				case KEY_RIGHT: x1 =  1; break;
				default:
					keyPressed = false;
			}

			if (keyPressed || bTimePassed)
			{
				UINT08 tile = map(party.x + x1, party.y + y1);
				(this->*map.act_list[tile])(x1, y1, true);
			}

		}
	}

	std::for_each(window.begin(), window.end(), FnDisplay<CWindow*>());

	p_gfx_device->EndDraw();

	p_gfx_device->Flip();

	return true;
}

void hadar::GameMain::m_actBlock(int x1, int y1, bool bUseless)
{
	party.face(x1, y1);

	return;
}

void hadar::GameMain::m_actMove(int x1, int y1, bool bEncounter)
{
	party.move(x1, y1);

	window[WINDOWTYPE_MAP]->setUpdateFlag();

	int num_updated;

	num_updated = std::for_each(player.begin(), player.end(), FnTimeGoes<PcPlayer*>()).Result();

	// player의 디스플레이 된 수치에 변화가 생겼다면
	if (num_updated > 0)
	{
		window[WINDOWTYPE_STATUS]->setUpdateFlag();
	}

	detectGameOver();
	
	// 독심술을 사용 중이라면 사용 시간을 감소 시킴
	if (party.ability.mind_control > 0)
		--party.ability.mind_control;

	if (bEncounter)
	{
		if (AvejUtil::random(party.encounter*20) == 0)
			encounterEnemy();
	}
}

void hadar::GameMain::m_actEvent(int x1, int y1, bool bUseless)
{
	party.move(x1, y1);

	window[WINDOWTYPE_MAP]->setUpdateFlag();

	LoreConsole::getConsole().clear();

	Script script(Script::MODE_EVENT, 0, party.x, party.y);

	return;
}

void hadar::GameMain::m_actEnter(int x1, int y1, bool bUseless)
{
	LoreConsole::getConsole().clear();
	Script script(Script::MODE_ENTER, 0, party.x + x1, party.y + y1);
}

void hadar::GameMain::m_actSign(int x1, int y1, bool bUseless)
{
	party.face(x1, y1);

	LoreConsole& console = LoreConsole::getConsole();

	console.clear();
	console.setTextColorIndex(7);
	console.Write("표지판에는 다음과 같이 적혀 있었다.");
	console.Write("");

	Script script(Script::MODE_SIGN, 0, party.x + x1, party.y + y1);
}

void hadar::GameMain::m_actWater(int x1, int y1, bool bUseless)
{
	if (party.ability.walk_on_water > 0)
	{
		--party.ability.walk_on_water;
		party.move(x1, y1);
		window[WINDOWTYPE_MAP]->setUpdateFlag();

		if (AvejUtil::random(party.encounter*30) == 0)
			encounterEnemy();
	}
	else
	{
		party.face(x1, y1);
	}
}

void hadar::GameMain::m_actSwamp(int x1, int y1, bool bUseless)
{
	m_actMove(x1, y1, false);

	// walkOnSwamp에 대한 처리
	if (party.ability.walk_on_swamp > 0)
	{
		--party.ability.walk_on_swamp;
	}
	else
	{
		LoreConsole& console = LoreConsole::getConsole();
		console.clear();
		console.setTextColorIndex(13);
		console.Write("일행은 독이 있는 늪에 들어갔다 !!!");
		console.Write("");

		int num_updated;

		num_updated = std::for_each(player.begin(), player.end(), FnEnterSwamp<PcPlayer*>()).Result();

		console.display();

		// player의 디스플레이 된 수치에 변화가 생겼다면
		if (num_updated > 0)
		{
			window[WINDOWTYPE_STATUS]->setUpdateFlag();
		}
	}

	detectGameOver();
}

void hadar::GameMain::m_actLava(int x1, int y1, bool bUseless)
{
	m_actMove(x1, y1, false);

	{
		LoreConsole& console = LoreConsole::getConsole();
		console.clear();
		console.setTextColorIndex(12);
		console.Write("일행은 용암지대로 들어섰다 !!!");
		console.Write("");

		int num_updated;

		num_updated = std::for_each(player.begin(), player.end(), FnEnterLava<PcPlayer*>()).Result();

		console.display();

		window[WINDOWTYPE_STATUS]->setUpdateFlag();
	}

	detectGameOver();

	return;
}

void hadar::GameMain::m_actTalk(int x1, int y1, bool bUseless)
{
	party.face(x1, y1);

	window[WINDOWTYPE_MAP]->setUpdateFlag();
	window[WINDOWTYPE_MAP]->display();

	LoreConsole::getConsole().clear();
	Script script(Script::MODE_TALK, 0, party.x + x1, party.y + y1);

	return;
}
