
#include "hd_class_pc_player.h"

#if defined(_WIN32)
#pragma warning(disable: 4786)
#endif

#include "UAvejUtil.h"
#include "USmSet.h"
#include "USmSola.h"
#include "hd_class_pc_party.h"
#include "hd_class_pc_enemy.h"
#include "hd_res_string.h"
#include "hd_class_console.h"
#include "hd_class_select.h"
#include "hd_class_sound.h"
#include "hd_base_extern.h"
#include <assert.h>
#include <vector>
#include <map>
#include <algorithm>
#include <string>

using namespace avej;

#define DETECT_NOT_ENOUGH_SP(consumption) \
	if (sp < consumption) \
	{ \
		game::console::writeConsole(7, 1, resource::getMessageString(resource::MESSAGE_NOT_ENOUGH_SP)); \
		return; \
	}

namespace
{
	using hadar::PcPlayer;

	// 파티에 등록된 player의 수
	template <class type>
	class FnNumOfRegistered
	{
		int num_player;

	public:
		FnNumOfRegistered(void)
			: num_player(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
				++num_player;
		}
		int Result(void)
		{
			return num_player;
		}
	};

	///////////////////////////////////////////////////////////////////////////////
	// static function

	void setPlayerName(PcPlayer& player, const char* sz_name)
	{
		player.setName(sz_name);
	}

	void getPlayerName(PcPlayer& player, avej::string& ref_name)
	{
		const char* sz_name = player.getName();
		ref_name = sz_name;
	}

	hadar::resource::CONDITION getPlayerCondition(const PcPlayer& player)
	{
		if (player.dead > 0)
			return hadar::resource::CONDITION_DEAD;
		if (player.unconscious > 0)
			return hadar::resource::CONDITION_UNCONSCIOUS;
		if (player.poison > 0)
			return hadar::resource::CONDITION_POISONED;

		return hadar::resource::CONDITION_GOOD;
	}

	inline int getPlayerMaxHP(const PcPlayer& player)
	{
		return player.endurance * player.level[0];
	}

	inline int getPlayerMaxSP(const PcPlayer& player)
	{
		return player.mentality * player.level[1];
	}

	inline int getPlayerMaxESP(const PcPlayer& player)
	{
		return player.concentration * player.level[2];
	}
}

namespace
{
	typedef std::map<std::string, int> AttribMapInt;
	static AttribMapInt s_attrib_map_int_list;

	typedef void (*FnSet)(PcPlayer&, const char*);
	typedef void (*FnGet)(PcPlayer&, avej::string&);
	typedef std::pair<void*, void*> FnSetGet;
	typedef std::map<std::string, FnSetGet> AttribMapStr;
	static AttribMapStr s_attrib_map_str_list;
}

////////////////////////////////////////////////////////////////////////////////
// serializing method

bool hadar::PcPlayer::_load(const ReadStream& stream)
{
	if (!PcNameBase::_load(stream))
		return false;

	return (stream.Read((void*)save, sizeof(save)) == sizeof(save));
}

bool hadar::PcPlayer::_save(const WriteStream& stream) const
{
	if (!PcNameBase::_save(stream))
		return false;

	return (stream.Write((void*)save, sizeof(save)) == sizeof(save));
}

////////////////////////////////////////////////////////////////////////////////
// public method

hadar::PcPlayer::PcPlayer(void)
{
	// save data 0으로 초기화
	for (int i = 0; i < sizeof(save) / sizeof(save[0]); i++)
		save[i] = 0;

	// static data의 초기화
	if (s_attrib_map_int_list.empty())
	{
		s_attrib_map_int_list["class"]           = int(&this->class_) - int(this);
		s_attrib_map_int_list["strength"]        = int(&this->strength) - int(this);
		s_attrib_map_int_list["mentality"]       = int(&this->mentality) - int(this);
		s_attrib_map_int_list["concentration"]   = int(&this->concentration) - int(this);
		s_attrib_map_int_list["endurance"]       = int(&this->endurance) - int(this);
		s_attrib_map_int_list["resistance"]      = int(&this->resistance) - int(this);
		s_attrib_map_int_list["agility"]         = int(&this->agility) - int(this);
		s_attrib_map_int_list["luck"]            = int(&this->luck) - int(this);
		s_attrib_map_int_list["weapon"]          = int(&this->weapon) - int(this);
		s_attrib_map_int_list["shield"]          = int(&this->shield) - int(this);
		s_attrib_map_int_list["armor" ]          = int(&this->armor ) - int(this);
		s_attrib_map_int_list["pow_of_weapon"]   = int(&this->pow_of_weapon) - int(this);
		s_attrib_map_int_list["pow_of_shield"]   = int(&this->pow_of_shield) - int(this);
		s_attrib_map_int_list["pow_of_armor"]    = int(&this->pow_of_armor ) - int(this);
		s_attrib_map_int_list["ac"]              = int(&this->ac) - int(this);

		s_attrib_map_int_list["level"]           = int(&this->level[0]) - int(this);
		s_attrib_map_int_list["level(magic)"]    = int(&this->level[1]) - int(this);
		s_attrib_map_int_list["level(esp)"]      = int(&this->level[2]) - int(this);
		s_attrib_map_int_list["accuracy"]        = int(&this->accuracy[0]) - int(this);
		s_attrib_map_int_list["accuracy(magic)"] = int(&this->accuracy[1]) - int(this);
		s_attrib_map_int_list["accuracy(esp)"]   = int(&this->accuracy[2]) - int(this);
	}

	if (s_attrib_map_str_list.empty())
	{
		s_attrib_map_str_list["_name"] = std::make_pair((void*)setPlayerName, (void*)getPlayerName);
	}
}

hadar::PcPlayer::~PcPlayer(void)
{
}

void hadar::PcPlayer::setDefault(int kind)
{
	CT_ASSERT(sizeof(*this) == 916, TPlayer_size_is_changed);

	order         = 0;
	gender        = GENDER_MALE;
	class_        = 8;

	strength      = 10;
	mentality     = 10;
	concentration = 10;
	endurance     = 10;
	resistance    = 10;
	agility       = 10;
	luck          = 10;

	ac            = 0;

	experience    = 0;
	accuracy[0]   = 10;
	accuracy[1]   = 10;
	accuracy[2]   = 10;
	level[0]      = 1;
	level[1]      = 1;
	level[2]      = 1;

	poison        = 0;
	unconscious   = 0;
	dead          = 0;

	weapon        = 0;
	shield        = 0;
	armor         = 0;

	pow_of_weapon = 5;
	pow_of_shield = 0;
	pow_of_armor  = 0;

	hp  = getPlayerMaxHP(*this);
	sp  = getPlayerMaxSP(*this);
	esp = getPlayerMaxESP(*this);

	setName(resource::getMessageString(resource::MESSAGE_ANONYMOUS_NAME));
}

void hadar::PcPlayer::checkCondition(void)
{
	if ((hp <= 0) && (unconscious == 0))
		unconscious = 1;
	if ((unconscious > endurance * level[0]) && (dead == 0))
		dead = 1;
}

const char* hadar::PcPlayer::getConditionString(void) const
{
	resource::CONDITION ix_condition = getPlayerCondition(*this);

	return resource::getConditionName(ix_condition).sz_name;
}

unsigned long hadar::PcPlayer::getConditionColor(void) const
{
	resource::CONDITION ix_condition = getPlayerCondition(*this);

	switch (ix_condition)
	{
	case resource::CONDITION_GOOD:
		return 0xFFFFFFFF;
	case resource::CONDITION_POISONED:
		return 0xFFFF00FF;
	case resource::CONDITION_UNCONSCIOUS:
		return 0xFF808080;
	case resource::CONDITION_DEAD:
		return 0xFF404040;
	default:
		assert(false);
	}

	return 0xFFFFFFFF;
}

const char* hadar::PcPlayer::get3rdPersonName(void) const
{
	int ix_gender;

	switch (gender)
	{
	case GENDER_MALE:
		ix_gender = 0;
		break;
	case GENDER_FEMALE:
		ix_gender = 1;
		break;
	default:
		ix_gender = -1;
		break;
	}
	return resource::get3rdPersonName(ix_gender).sz_name;
}

const char* hadar::PcPlayer::getGenderName(void) const
{
	int ix_gender;

	switch (gender)
	{
	case GENDER_MALE:
		ix_gender = 0;
		break;
	case GENDER_FEMALE:
		ix_gender = 1;
		break;
	default:
		ix_gender = -1;
		break;
	}
	return resource::getGenderName(ix_gender).sz_name;
}

const char* hadar::PcPlayer::getClassName(void) const
{
	return resource::getClassName(class_).sz_name;
}

const char* hadar::PcPlayer::getWeaponName(void) const
{
	return resource::getWeaponName(weapon).sz_name;
}

const char* hadar::PcPlayer::getShieldName(void) const
{
	return resource::getShieldName(shield).sz_name;
}

const char* hadar::PcPlayer::getArmorName(void) const
{
	return resource::getArmorName(armor).sz_name;
}

bool hadar::PcPlayer::changeAttribute(const char* sz_attribute, int value)
{
	AttribMapInt::iterator attrib = s_attrib_map_int_list.find(sz_attribute);

	if (attrib == s_attrib_map_int_list.end())
		return false;

	int* p_int = reinterpret_cast<int*>(int(this) + int(attrib->second));

	*p_int = value;

	return true;
}

bool hadar::PcPlayer::changeAttribute(const char* sz_attribute, const char* sz_data)
{
	AttribMapStr::iterator attrib = s_attrib_map_str_list.find(sz_attribute);

	if (attrib == s_attrib_map_str_list.end())
		return false;

	FnSet((attrib->second).first)(*this, sz_data);

	return true;
}

bool hadar::PcPlayer::getAttribute(const char* sz_attribute, int& value)
{
	AttribMapInt::iterator attrib = s_attrib_map_int_list.find(sz_attribute);

	if (attrib == s_attrib_map_int_list.end())
		return false;

	int* p_int = reinterpret_cast<int*>(int(this) + int(attrib->second));

	value = *p_int;

	return true;
}

bool hadar::PcPlayer::getAttribute(const char* sz_attribute, avej::string& data)
{
	AttribMapStr::iterator attrib = s_attrib_map_str_list.find(sz_attribute);

	if (attrib == s_attrib_map_str_list.end())
		return false;

	FnGet((attrib->second).second)(*this, data);

	return true;
}

void hadar::PcPlayer::reviseAttribute(void)
{
	this->hp  = sola::min(hp,  getPlayerMaxHP(*this));
	this->sp  = sola::min(sp,  getPlayerMaxSP(*this));
	this->esp = sola::min(esp, getPlayerMaxESP(*this));
}

void hadar::PcPlayer::applyAttribute(void)
{
	this->hp  = getPlayerMaxHP(*this);
	this->sp  = getPlayerMaxSP(*this);
	this->esp = getPlayerMaxESP(*this);
}

void hadar::PcPlayer::operator<<(const EnemyData& data)
{
	CT_ASSERT(sizeof(*this) == 916, TPlayer_size_is_changed);

	// 이름 설정
	this->setName(data._name);

	// 기타 속성 설정
	gender        = GENDER_MALE;
	class_        = 0;
	
	strength      = data.strength;
	mentality     = data.mentality;
	concentration = 0;;
	endurance     = data.endurance;
	resistance    = data.resistance / 2;
	agility       = data.agility;
	luck          = 10;

	ac            = data.ac;

	level[0]      = data.level;
	level[1]      = data.cast_level * 3;
	if (level[1] == 0)
		level[1]  = 1;
	level[2]      = 1;

	hp  = getPlayerMaxHP(*this);
	sp  = getPlayerMaxSP(*this);
	esp = getPlayerMaxESP(*this);

	switch (level[0])
	{
		case 0 :
		case 1 : experience = 0; break;
		case 2 : experience = 1500; break;
		case 3 : experience = 6000; break;
		case 4 : experience = 20000; break;
		case 5 : experience = 50000; break;
		case 6 : experience = 150000; break;
		case 7 : experience = 250000; break;
		case 8 : experience = 500000; break;
		case 9 : experience = 800000; break;
		case 10 : experience = 1050000; break;
		case 11 : experience = 1320000; break;
		case 12 : experience = 1620000; break;
		case 13 : experience = 1950000; break;
		case 14 : experience = 2310000; break;
		case 15 : experience = 2700000; break;
		case 16 : experience = 3120000; break;
		case 17 : experience = 3570000; break;
		case 18 : experience = 4050000; break;
		case 19 : experience = 4560000; break;
		default : experience = 5100000; break;
	}

	accuracy[0] = data.accuracy[0];
	accuracy[1] = data.accuracy[1];
	accuracy[2] = 0;

	poison      = 0;
	unconscious = 0;
	dead        = 0;

	weapon      = 10;
	shield      = 6;
	armor       = 6;

	pow_of_weapon = level[0] * 2 + 10;
	pow_of_shield = 0;
	pow_of_armor  = ac;
}

void hadar::PcPlayer::castAttackSpell(void)
{
	LoreConsole& console = LoreConsole::getConsole();
	
	console.setTextColorIndex(7);
	console.Write(resource::getMessageString(resource::MESSAGE_CANNOT_USE_ATTACK_MAGIC_NOT_IN_BATTLE_MODE));
	console.display();
}

void hadar::PcPlayer::castCureSpell(void)
{
	PcPlayer* p_player = this;

	MenuList menu;

	menu.push_back(resource::getMessageString(resource::MESSAGE_TO_WHOM));

	PcPlayer* table[10];
	int max_table = 0;

	std::vector<PcPlayer*>& player = game::object::getPlayerList();

	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
	{
		if ((*obj)->isValid())
		{
			table[max_table++] = (*obj);
			menu.push_back((*obj)->getName());
		}
	}

	menu.push_back(resource::getMessageString(resource::MESSAGE_TO_EVERYBODY));

	int whom = MenuSelection(menu)() - 1;

	if (whom < 0)
		return;

	if (whom < max_table)
	{
		int num_enabled = p_player->level[1] / 2 + 1;

		if (num_enabled > 7)
			num_enabled = 7;

		menu.clear();
		menu.push_back(resource::getMessageString(resource::MESSAGE_SELECTION));

		for (int i = 0; i < 7; i++)
			menu.push_back(resource::getMagicName(19+i).sz_name);

		int selected = MenuSelection(menu, num_enabled)();

		if (selected <= 0)
			return;

		PcPlayer* p_target = table[whom];

		switch (selected)
		{
		case 1:
			p_player->m_healOne(p_target);
			break;
		case 2:
			p_player->m_antidoteOne(p_target);
			break;
		case 3:
			p_player->m_antidoteOne(p_target);
			p_player->m_healOne(p_target);
			break;
		case 4:
			p_player->m_recoverConsciousnessOne(p_target);
			break;
		case 5:
			p_player->m_revitalizeOne(p_target);
			break;
		case 6:
			p_player->m_recoverConsciousnessOne(p_target);
			p_player->m_antidoteOne(p_target);
			p_player->m_healOne(p_target);
			break;
		case 7:
			p_player->m_revitalizeOne(p_target);
			p_player->m_recoverConsciousnessOne(p_target);
			p_player->m_antidoteOne(p_target);
			p_player->m_healOne(p_target);
			break;
		default:
			assert(false);
		}
	}
	else
	{
		int num_enabled = p_player->level[1] / 2 - 3;

		if (num_enabled <= 0) //@@ 원래는 < 0 이었음 검토 필요
		{
			game::console::writeConsole(7, 3, p_player->getName(JOSA_SUB), " ", resource::getMessageString(resource::MESSAGE_CANNOT_USE_POWERFUL_CURE_SPELL));
			game::pressAnyKey();

			return;
		}

		if (num_enabled > 7)
			num_enabled = 7;

		menu.clear();
		menu.push_back(resource::getMessageString(resource::MESSAGE_SELECTION));
		for (int i = 0; i < 7; i++)
			menu.push_back(resource::getMagicName(26+i).sz_name);

		int selected = MenuSelection(menu, num_enabled)();

		if (selected < 0)
			return;

		switch (selected+1)
		{
		case 1:
			p_player->m_healAll();
			break;
		case 2:
			p_player->m_antidoteAll();
			break;
		case 3:
			p_player->m_antidoteAll();
			p_player->m_healAll();
			break;
		case 4:
			p_player->m_recoverConsciousnessAll();
			break;
		case 6:
			p_player->m_revitalizeAll();
			break;
		case 5:
			p_player->m_recoverConsciousnessAll();
			p_player->m_antidoteAll();
			p_player->m_healAll();
			break;
		case 7:
			p_player->m_revitalizeAll();
			p_player->m_recoverConsciousnessAll();
			p_player->m_antidoteAll();
			p_player->m_healAll();
			break;
		}
	}

	LoreConsole::getConsole().Write("");
	LoreConsole::getConsole().Write("");
	LoreConsole::getConsole().display();

	game::window::displayStatus();

	game::updateScreen();
	game::pressAnyKey();
}

void hadar::PcPlayer::castPhenominaSpell(void)
{
	PcPlayer* p_player = this;

	MenuList menu;
	menu.reserve(8);

	menu.push_back(resource::getMessageString(resource::MESSAGE_SELECTION));

	for (int i = 0; i < 8; i++)
		menu.push_back(resource::getMagicName(i+33).sz_name);

	int num_enabled = (p_player->level[1] > 1) ? (p_player->level[1] / 2 + 1) : 1;

	if (num_enabled > 8)
		num_enabled = 8;

	int selected = MenuSelection(menu, num_enabled)();

	if (selected <= 0)
		return;

	PcParty& party = game::object::getParty();
	Map& map = game::object::getMap();

	switch (selected)
	{
	case 1:
		{
			if (p_player->sp < 1)
			{
				m_printSpNotEnough();
				return;
			}

			p_player->sp -= 1;

			party.igniteTorch();
		}
		break;
	case 2:
		{
			if (p_player->sp < 5)
			{
				m_printSpNotEnough();
				return;
			}

			p_player->sp -= 5;

			party.levitate();
		}
		break;
	case 3:
		{
			if (p_player->sp < 10)
			{
				m_printSpNotEnough();
				return;
			}

			p_player->sp -= 10;

			party.walkOnWater();
		}
		break;
	case 4:
		{
			if (p_player->sp < 20)
			{
				m_printSpNotEnough();
				return;
			}

			p_player->sp -= 20;

			party.walkOnSwamp();
		}
		break;
	case 5:
		{
			if (p_player->sp < 25)
			{
				m_printSpNotEnough();
				return;
			}

			MenuList menu;

			menu.push_back(resource::getMessageString(resource::MESSAGE_SELECT_DIRECTION));
			menu.push_back("북쪽으로 기화 이동");
			menu.push_back("남쪽으로 기화 이동");
			menu.push_back("동쪽으로 기화 이동");
			menu.push_back("서쪽으로 기화 이동");

			int selected = MenuSelection(menu)();

			if (selected <= 0)
				return;

			int x = party.x;
			int y = party.y;

			switch (selected)
			{
			case 1:
				y -= 2;
				break;
			case 2:
				y += 2;
				break;
			case 3:
				x += 2;
				break;
			case 4:
				x -= 2;
				break;
			default:
				assert(false);
			}

			if (!game::map::isValidWarpPos(x, y))
				return;

			if (!map.isJumpable(x, y))
			{
				game::console::showMessage(7, "기화 이동이 통하지 않습니다.");
				return;
			}

			p_player->sp -= 25;

			// 기화 이동 중간에 이벤트 지점이 있을 때
			if (map.isEventPos((party.x + x) / 2, (party.y + y) / 2))
			{
				game::console::showMessage(13, "알 수 없는 힘이 당신의 마법을 배척합니다.");
				return;
			}

			party.x_prev = (party.x + x) / 2;
			party.y_prev = (party.y + y) / 2;
			party.x = x;
			party.y = y;

			game::console::showMessage(15, "기화 이동을 마쳤습니다.");

			game::window::displayMap();
		}
		break;
	case 6:
		{
			if (map.hasHandicap(Map::HANDICAP_TILECHANGING))
			{
				game::console::showMessage(13, "이곳의 악의 힘이 이 마법을 방해합니다.");
				return;
			}

			if (p_player->sp < 30)
			{
				m_printSpNotEnough();
				return;
			}

			MenuList menu;

			menu.push_back(resource::getMessageString(resource::MESSAGE_SELECT_DIRECTION));
			menu.push_back("북쪽에 지형 변화");
			menu.push_back("남쪽에 지형 변화");
			menu.push_back("동쪽에 지형 변화");
			menu.push_back("서쪽에 지형 변화");

			int selected = MenuSelection(menu)();

			if (selected <= 0)
				return;

			int dx = 0;
			int dy = 0;

			switch (selected)
			{
			case 1:
				--dy;
				break;
			case 2:
				++dy;
				break;
			case 3:
				++dx;
				break;
			case 4:
				--dx;
				break;
			default:
				assert(false);
			}

			p_player->sp -= 30;

			// 이벤트 지점에 대해 지형 변화를 하려할 때
			if (map.isEventPos(party.x + dx, party.y + dy))
			{
				game::console::showMessage(13, "알 수 없는 힘이 당신의 마법을 배척합니다.");
				return;
			}

			map.changeToWay(party.x + dx, party.y + dy);

			game::console::showMessage(15, "지형 변화에 성공했습니다.");

			game::window::displayMap();
		}
		break;
	case 7:
		{
			if (map.hasHandicap(Map::HANDICAP_TELEPORT))
			{
				game::console::showMessage(13, "이곳의 악의 힘이 이 마법을 방해합니다.");
				return;
			}

			if (p_player->sp < 50)
			{
				m_printSpNotEnough();
				return;
			}

			MenuList menu;

			menu.push_back(resource::getMessageString(resource::MESSAGE_SELECT_DIRECTION));
			menu.push_back(resource::getMessageString(resource::MESSAGE_TELEPORT_TO_NORTH));
			menu.push_back(resource::getMessageString(resource::MESSAGE_TELEPORT_TO_SOUTH));
			menu.push_back(resource::getMessageString(resource::MESSAGE_TELEPORT_TO_EAST));
			menu.push_back(resource::getMessageString(resource::MESSAGE_TELEPORT_TO_WEST));

			int selected = MenuSelection(menu)();

			if (selected <= 0)
				return;

			int dx = 0;
			int dy = 0;

			switch (selected)
			{
			case 1: --dy; break;
			case 2: ++dy; break;
			case 3: ++dx; break;
			case 4: --dx; break;
			default:
				assert(false);
			}

			LoreConsole::getConsole().Write("");
			LoreConsole::getConsole().setTextColorIndex(11);
			LoreConsole::getConsole().Write("당신의 공간 이동력을 지정");
			LoreConsole::getConsole().setTextColorIndex(15);
			LoreConsole::getConsole().Write(" ## 5000 공간 이동력");
			LoreConsole::getConsole().display();

			//@@ console에서 text extent 형식으로 얻어 와야 함
			int power = 5000;
			{
				int x_origin;
				int y_origin;

				game::window::getRegionForConsole(&x_origin, &y_origin, NULL, NULL);

				power = MenuSelectionUpDown(x_origin + 4*6, y_origin + 2*12, 1000, 9000, 1000, power, game::getRealColor(10), game::getRealColor(8))();

				if (power < 1000)
					return;

				power /= 1000;
			}

			int x = party.x + dx * power;
			int y = party.y + dy * power;

			if (!game::map::isValidWarpPos(x, y))
			{
				game::console::showMessage(7, "공간 이동이 통하지 않습니다.");
				return;
			}

			// 이벤트 지점에 대해 지형 변화를 하려할 때
			if (!map.isTeleportable(x, y))
			{
				game::console::showMessage(13, "공간 이동 장소로 부적합 합니다.");
				return;
			}

			p_player->sp -= 50;

			// 순간 이동 지점이 이벤트 지점일 때
			if (map.isEventPos(x, y))
			{
				game::console::showMessage(13, "알 수 없는 힘이 당신을 배척합니다.");
				return;
			}

			party.warp(PcParty::POS_ABS, x, y);

			game::console::showMessage(15, "공간 이동 마법이 성공했습니다.");

			game::window::displayMap();
		}
		break;
	case 8:
		{
			if (p_player->sp < 30)
			{
				m_printSpNotEnough();
				return;
			}

			std::vector<PcPlayer*>& player = game::object::getPlayerList();

			int num_player = std::for_each(player.begin(), player.end(), FnNumOfRegistered<PcPlayer*>()).Result();
			assert(num_player > 0);

			party.food += num_player;
			if (party.food > 255)
				party.food = 255;

			p_player->sp -= 30;

			{

				LoreConsole& console = LoreConsole::getConsole();
				console.clear();
				console.setTextColorIndex(15);
				console.Write(" 식량 제조 마법은 성공적으로 수행되었습니다");

				{
					avej::string s;
					s += "            ";
					s += IntToStr(num_player)();
					s += " 개의 식량이 증가됨";
					console.Write(s);
				}

				{
					avej::string s;
					s += "      일행의 현재 식량은 ";
					s += IntToStr(party.food)();
					s += " 개 입니다";
					console.setTextColorIndex(11);
					console.Write(s);
				}

				console.display();
			}

		}
		break;
	default:
		assert(false);
	}

	game::window::displayStatus();
}

void hadar::PcPlayer::attackWithWeapon(int ix_object, int ix_enemy)
{
	PcPlayer* p_player = this;

	int num_enemy_alive = game::enemy::getNumOfConsciousEnemy();
	if (num_enemy_alive == 0)
		return;

	std::vector<PcEnemy*>& enemy = game::object::getEnemyList();

	while (enemy[ix_enemy]->dead > 0)
	{
		if (++ix_enemy > int(enemy.size()))
			return;
	}

	PcEnemy* p_enemy = enemy[ix_enemy];

	assert(p_player != NULL);
	assert(p_enemy  != NULL);

	LoreConsole& console = LoreConsole::getConsole();

	console.setTextColorIndex(15);
	console.Write(getBattleMessage(*p_player, 1, ix_object, *p_enemy));

	const char* sz_gender = p_player->get3rdPersonName();

	if ((p_enemy->unconscious > 0) && (p_enemy->dead == 0))
	{
		switch (AvejUtil::random(4))
		{
		case 0:
			game::console::writeConsole(12, 4, sz_gender, "의 무기가 ", p_enemy->getName(), "의 심장을 꿰뚫었다");
			break;
		case 1:
			game::console::writeConsole(12, 4, p_enemy->getName(), "의 머리는 ", sz_gender, "의 공격으로 산산 조각이 났다");
			break;
		case 2:
			game::console::writeConsole(12, 1, "적의 피가 사방에 뿌려졌다");
			break;
		case 3:
			game::console::writeConsole(12, 1, "적은 비명과 함께 찢겨 나갔다");
			break;
		}

		sound::playFx(sound::SOUND_SCREAM2);

		p_player->m_plusExperience(p_enemy);

		p_enemy->hp   = 0;
		p_enemy->dead = 1;

		return;
	}

	if (AvejUtil::random(20) > p_player->accuracy[0])
	{
		game::console::writeConsole(12, 2, sz_gender, "의 공격은 빗나갔다 ....");
		return;
	}

	if (AvejUtil::random(100) < p_enemy->resistance)
	{
		game::console::writeConsole(7, 3, "적은 ", sz_gender, "의 공격을 저지 했다");
		return;
	}

	int damage = (p_player->strength * p_player->pow_of_weapon * p_player->level[0]) / 20;

	damage -= (damage * AvejUtil::random(50) / 100);
	damage -= (p_enemy->ac * p_enemy->level * (AvejUtil::random(10)+1) / 10);

	if (damage <= 0)
	{
		game::console::writeConsole(7, 3, "그러나 적은 ", sz_gender, "의 공격을 막았다");
		return;
	}

	p_enemy->hp -= damage;

	if (p_enemy->hp <= 0)
	{
		p_enemy->hp = 0;
		p_enemy->unconscious = 0;
		p_enemy->dead = 0;

		game::console::writeConsole(12, 3, "적은 ", sz_gender, "의 공격으로 의식 불명이 되었다");

		sound::playFx(sound::SOUND_HIT);

		p_player->m_plusExperience(p_enemy);

		p_enemy->unconscious = 1;
	}
	else
	{
		game::console::writeConsole(7, 3, "적은 ", IntToStr(damage)(), "만큼의 피해를 입었다"); // 원래는 중간이 15번 색

		sound::playFx(sound::SOUND_HIT);
	}

	game::window::displayBattle(0);
}

void hadar::PcPlayer::castSpellToAll(int ix_object)
{
	std::vector<PcEnemy*>& enemy = game::object::getEnemyList();

	for (int ix_enemy = 0; ix_enemy < int(enemy.size()); ++ix_enemy)
	{
		if (enemy[ix_enemy]->isValid() && (enemy[ix_enemy]->dead == 0))
			castSpellToOne(ix_object, ix_enemy);
	}
}

void hadar::PcPlayer::castSpellToOne(int ix_object, int ix_enemy)
{
	PcPlayer* p_player = this;

	int num_enemy_alive = game::enemy::getNumOfConsciousEnemy();

	if (num_enemy_alive == 0)
		return;

	std::vector<PcEnemy*>& enemy = game::object::getEnemyList();

	while ((enemy[ix_enemy] == NULL) || (enemy[ix_enemy]->dead > 0))
	{
		if (++ix_enemy > int(enemy.size()))
			return;
	}

	PcEnemy* p_enemy = enemy[ix_enemy];

	assert(p_player != NULL);
	assert(p_enemy  != NULL);

	LoreConsole& console = LoreConsole::getConsole();

	console.setTextColorIndex(15);
	console.Write(getBattleMessage(*p_player, 2, ix_object, *p_enemy));

	const char* sz_gender = p_player->get3rdPersonName();

	if ((p_enemy->unconscious > 0) && (p_enemy->dead == 0))
	{
		game::console::writeConsole(12, 2, sz_gender, "의 마법은 적의 시체 위에서 작열했다");

		sound::playFx(sound::SOUND_SCREAM1);

		p_player->m_plusExperience(p_enemy);

		p_enemy->hp   = 0;
		p_enemy->dead = 1;

		return;
	}

	// 마법 소모치
	{
		int consumption = (ix_object * ix_object* p_player->level[1] + 1) / 2;

		DETECT_NOT_ENOUGH_SP(consumption)

		p_player->sp -= consumption;
	}

	if (AvejUtil::random(20) >= p_player->accuracy[1])
	{
		game::console::writeConsole(7, 3, "그러나, ", p_enemy->getName(JOSA_OBJ), " 빗나갔다");
		return;
	}

	if (AvejUtil::random(100) < p_enemy->resistance)
	{
		game::console::writeConsole(7, 4, p_enemy->getName(JOSA_SUB), " ", sz_gender, "의 마법을 저지 했다");
		return;
	}

	int damage = ix_object * ix_object* p_player->level[1] * 2;

	damage -= ((p_enemy->ac * p_enemy->level * (AvejUtil::random(10)+1) + 5) / 10);

	if (damage <= 0)
	{
		game::console::writeConsole(7, 5, "그러나, ", p_enemy->getName(JOSA_SUB), " ", sz_gender, "의 마법 공격을 막았다");
		return;
	}

	p_enemy->hp -= damage;

	if (p_enemy->hp <= 0)
	{
		p_enemy->hp = 0;
		p_enemy->unconscious = 0;
		p_enemy->dead = 0;

		game::console::writeConsole(12, 4, p_enemy->getName(JOSA_SUB), " ", sz_gender, "의 마법에 의해 의식 불명이 되었다");

		sound::playFx(sound::SOUND_HIT);

		p_player->m_plusExperience(p_enemy);

		p_enemy->unconscious = 1;
	}
	else
	{
		game::console::writeConsole(7, 4, p_enemy->getName(JOSA_SUB), " ", IntToStr(damage)(), "만큼의 피해를 입었다"); // 원래는 중간이 15번 색

		sound::playFx(sound::SOUND_HIT);
	}

	game::window::displayBattle(0);
}

void hadar::PcPlayer::useESP(void)
{
	if (!m_canUseESP())
	{
		game::console::writeConsole(7, 1, "당신에게는 아직 능력이 없습니다.");
		return;
	}

	MenuList menu;

	menu.clear();
	menu.push_back("사용할 초감각의 종류 ======>");

	for (int i = 1; i <= 5; i++)
		menu.push_back(resource::getMagicName(40+i).sz_name);

	int selected = MenuSelection(menu)();

	if (selected <= 0)
		return;
	
	if (selected == 5)
	{
		avej::string s;

		s += resource::getMagicName(40+selected).sz_name;
		s += resource::getMagicName(40+selected).sz_josa_sub1;
		s += " 전투 모드에서만 사용됩니다.";

		game::console::showMessage(7, s);
		return;
	}

	PcPlayer* p_player = this;
	PcParty& party = game::object::getParty();

	switch (selected)
	{
	case 1:
		{
			{
				Map& map = game::object::getMap();

				if (map.hasHandicap(Map::HANDICAP_SEETHROUGH))
				{
					game::console::showMessage(13, "이곳의 악의 힘이 이 마법을 방해합니다.");
					return;
				}
			}

			if (p_player->esp < 10)
			{
				m_printESPNotEnough();
				return;
			}

			p_player->esp -= 10;

			sound::muteFx(true);

/*??
			move(font^[0],font^[55],246);

			for i = 5 to 246 do
				font^[0,i] = 0;

			if (position in [den,keep])
			{
				move(font^[52],chara^[55],246);
				for i = 5 to 246 do
					font^[52,i] = 0;
			}

			Scroll(TRUE);

			Print(15,"일행은 주위를 투시하고 있다.");

			pressAnyKey;

			move(font^[55],font^[0],246);

			if (position in [den,keep])
				move(chara^[55],font^[52],246);

			Scroll(TRUE);
*/
			sound::muteFx(false);
		}
		break;

	case 2:
		{
			if (p_player->esp < 5)
			{
				m_printESPNotEnough();
				return;
			}

			p_player->esp -= 5;
/*??
			Print(7," 당신은 당신의 미래를 예언한다 ...");
			Print(7,"");

			k = ReturnPredict;

			if (k in [1..25])
				s = "당신은 " + Predict_Data[k] + " 것이다"
			else
				s = "당신은 어떤 힘에 의해 예언을 방해 받고 있다";

			cPrint(10,15," # ",s,"");

			pressAnyKey;
*/
		}
		break;

	case 3:
		{
			if (p_player->esp < 20)
			{
				m_printESPNotEnough();
				return;
			}

			p_player->esp -= 20;

			game::console::showMessage(5, "당신은 잠시동안 다른 사람의 마음을 읽을수 있다.");

			party.ability.mind_control = 3;
		}
		break;

	case 4:
		{
			{
				Map& map = game::object::getMap();

				if (map.hasHandicap(Map::HANDICAP_CLAIRVOYANCE))
				{
					game::console::showMessage(13, "이곳의 악의 힘이 이 마법을 방해합니다.");
					return;
				}
			}

			if (p_player->esp < level[2] * 5)
			{
				m_printESPNotEnough();
				return;
			}

			menu.clear();
			menu.push_back(resource::getMessageString(resource::MESSAGE_SELECT_DIRECTION));
			menu.push_back("북쪽으로 천리안을 사용");
			menu.push_back("남쪽으로 천리안을 사용");
			menu.push_back("동쪽으로 천리안을 사용");
			menu.push_back("서쪽으로 천리안을 사용");

			int selected = MenuSelection(menu)();

			if (selected <= 0)
				return;

			int x1 = 0;
			int y1 = 0;

			p_player->esp -= level[2] * 5;

			switch (selected)
			{
				case 1: y1 = -1; break;
				case 2: y1 =  1; break;
				case 3: x1 =  1; break;
				case 4: x1 = -1; break;
			}
/*??
			party.xaxis = x;
			party.yaxis = y;

			//@@ 사운드 끄는 부분 추가

			for i = 0 to 1 do
			{
				page = 1 - page;
				setactivepage(page);
				hany = 30;
				print(15,"천리안의 사용중 ...");
				setcolor(14);
				HPrintXY4Select(250,184,"아무키나 누르시오 ...");
			}

			for i = 1 to player[person].level[3] do
			{
				x = x + x1; y = y + y1;
				if ((x<5) or (x>==xmax-3) or (y<5) or (y>==ymax-3))
				{
					x = x - x1; y = y - y1;
				}
				else
				{
					Scroll(FALSE);
					c = readkey;

					if (c == #0)
						c = readkey;
					if (c == #27)
						goto Exit_For;
				}
			}

Exit_For:
			clear;

			x = party.xaxis;
			y = party.yaxis;

			//@@ 사운드 설정 복원하는 부분 추가

			Scroll(TRUE);
*/
		}
		break;

	default:
		assert(0);
	}

	game::window::displayStatus();
}

void hadar::PcPlayer::useESPForBattle(int ix_object, int ix_enemy)
{
	PcPlayer* p_player = this;

	assert(p_player != NULL);

	if (!m_canUseESP())
	{
		game::console::writeConsole(7, 1, "당신에게는 아직 능력이 없습니다.");
		return;
	}

	std::vector<PcPlayer*>& player = game::object::getPlayerList();
	std::vector<PcEnemy*>& enemy = game::object::getEnemyList();

	PcEnemy* p_enemy = enemy[ix_enemy];

	assert(p_enemy  != NULL);

	if (p_enemy == NULL)
		return;

	if ((ix_object == 1) || (ix_object == 2) || (ix_object == 4))
	{
		game::console::writeConsole(7, 3, resource::getMagicName(ix_object+40).sz_name, resource::getMagicName(ix_object+40).sz_josa_with, " 전투모드에서는 사용할 수가 없습니다.");
		return;
	}

	if (ix_object == 3)
	{
		if (p_player->esp < 15)
		{
			game::console::writeConsole(7, 1, "초감각 지수가 부족했다");
			return;
		}

		p_player->esp -= 15;

		static const SmSet MIND_CONTROLLABLE("6,10,20,24,27,29,33,35,40,47,53,62");

		if (!MIND_CONTROLLABLE.isSet(p_enemy->ed_number))
		{
			game::console::writeConsole(7, 1, "독심술은 전혀 통하지 않았다");
			return;
		}

		int enemyLevel = p_enemy->level;
		//@@ 특수한 경우?
		if (p_enemy->ed_number == 62)
			enemyLevel = 17;

		if ((enemyLevel > p_player->level[2]) && (AvejUtil::random(2) == 0))
		{
			game::console::writeConsole(7, 1, "적의 마음을 끌어들이기에는 아직 능력이 부족했다");
			return;
		}

		if (AvejUtil::random(60) > (p_player->level[2]-enemyLevel)*2 + p_player->accuracy[2])
		{
			game::console::writeConsole(7, 1, "적의 마음은 흔들리지 않았다");
			return;
		}

		game::console::writeConsole(11, 1, "적은 우리의 편이 되었다");

		*player[player.size()-1] << getEnemyDataFromEnemyTable(p_enemy->ed_number);

		p_enemy->dead        = 1;
		p_enemy->unconscious = 1;
		p_enemy->hp          = 0;
		p_enemy->level       = 0;

		game::window::displayStatus();
	}
	else
	{
		if (p_player->esp < 20)
		{
			game::console::writeConsole(7, 1, "초감각 지수가 부족했다");
			return;
		}

		p_player->esp -= 20;

		int ix_ESP = AvejUtil::random(p_player->level[2]) + 1;

		switch (ix_ESP)
		{
		case 1:
		case 2:
		case 3:
		case 4:
		case 5:
		case 6:
			{
				switch (ix_ESP)
				{
				case 1:
				case 2:
					game::console::writeConsole(7, 3, "주위의 돌들이 떠올라 ", p_enemy->getName(JOSA_OBJ), " 공격하기 시작한다");
					break;
				case 3:
				case 4:
					game::console::writeConsole(7, 2, p_enemy->getName(JOSA_NONE), " 주위의 세균이 그에게 침투하여 해를 입히기 시작한다");
					break;
				case 5:
				case 6:
					game::console::writeConsole(7, 4, p_player->getGenderName(), "의 무기가 갑자기 ", p_enemy->getName(JOSA_NONE), "에게 달려들기 시작한다");
					break;
				}

				p_enemy->hp -= ix_ESP * 10;
				if (p_enemy->hp < 0)
					p_enemy->hp = 0;

				if ((p_enemy->unconscious > 0) && (p_enemy->dead == 0))
				{
					p_enemy->dead = 1;
					p_player->m_plusExperience(p_enemy);
				}

				if ((p_enemy->hp <= 0) && (p_enemy->unconscious == 0))
				{
					p_enemy->unconscious = 1;
					p_player->m_plusExperience(p_enemy);
				}
			}
			break;
		case 7:
		case 8:
		case 9:
		case 10:
			{
				switch (ix_ESP)
				{
				case 7:
				case 8:
					game::console::writeConsole(7, 1, "갑자기 땅속의 우라늄이 핵분열을 일으켜 고온의 열기가 적의 주위를 감싸기 시작한다");
					break;
				case 9:
				case 10:
					game::console::writeConsole(7, 1, "공기중의 수소가 돌연히 핵융합을 일으켜 질량 결손의 에너지를 적들에게 방출하기 시작한다");
					break;
				}

				for (std::vector<PcEnemy*>::iterator obj = enemy.begin(); obj != enemy.end(); ++obj)
				{
					p_enemy = (*obj);

					if (!p_enemy->isValid())
						continue;

					p_enemy->hp -= ix_ESP * 5;
					if (p_enemy->hp < 0)
						p_enemy->hp = 0;

					if ((p_enemy->unconscious > 0) && (p_enemy->dead == 0))
					{
						p_enemy->dead = 1;
						p_player->m_plusExperience(p_enemy);
					}

					if ((p_enemy->hp <= 0) && (p_enemy->unconscious == 0))
					{
						p_enemy->unconscious = 1;
						p_player->m_plusExperience(p_enemy);
					}
				}
			}
			break;
		case 11:
		case 12:
			{
				game::console::writeConsole(7, 2, p_player->getGenderName(), "는 적에게 공포심을 불어 넣었다");

				if (AvejUtil::random(40) < p_enemy->resistance)
				{
					if (p_enemy->resistance < 5)
						p_enemy->resistance = 0;
					else
						p_enemy->resistance = p_enemy->resistance - 5;
					return;
				}

				if (AvejUtil::random(60) > p_player->accuracy[2])
				{
					if (p_enemy->endurance < 5)
						p_enemy->endurance = 0;
					else
						p_enemy->endurance = p_enemy->endurance - 5;
					return;
				}

				p_enemy->dead = 1;

				game::console::writeConsole(10, 2, p_enemy->getName(JOSA_SUB), " 겁을 먹고는 도망 가버렸다");
			}
			break;
		case 13:
		case 14:
			{
				game::console::writeConsole(7, 2, p_player->getGenderName(), "는 적의 신진 대사를 조절하여 적의 체력을 점차 약화 시키려 한다");

				if (AvejUtil::random(100) < p_enemy->resistance)
					return;

				if (AvejUtil::random(40) > p_player->accuracy[2])
					return;

				++p_enemy->poison;
			}
			break;
		case 15:
		case 16:
		case 17:
			{
				game::console::writeConsole(7, 2, p_player->getGenderName(), "는 염력으로 적의 심장을 멈추려 한다");

				if (AvejUtil::random(40) < p_enemy->resistance)
				{
					if (p_enemy->resistance < 5)
						p_enemy->resistance = 0;
					else
						p_enemy->resistance = p_enemy->resistance - 5;
					return;
				}

				if (AvejUtil::random(80) > p_player->accuracy[2])
				{
					if (p_enemy->hp < 10)
					{
						p_enemy->hp = 0;
						p_enemy->unconscious = 1;
					}
					else
					{
						p_enemy->hp -= 10;
					}
					return;
				}

				++p_enemy->unconscious;
			}
			break;
		default:
			{
				game::console::writeConsole(7, 2, p_player->getGenderName(), "는 적을 환상속에 빠지게 하려한다");

				if (AvejUtil::random(40) < p_enemy->resistance)
				{
					if (p_enemy->agility < 5)
						p_enemy->agility = 0;
					else
						p_enemy->agility = p_enemy->agility - 5;
					return;
				}

				if (AvejUtil::random(30) > p_player->accuracy[2])
					return;

				for (int i = 0; i < 2; i++)
				{
					if (p_enemy->accuracy[i] > 0)
						--p_enemy->accuracy[i];
				}
			}
		}

		game::window::displayBattle(0); //@@DisplayEnemies(FALSE); 맞는지 모르겠음
	}
}

void hadar::PcPlayer::castSpellWithSpecialAbility(int ix_object, int ix_enemy)
{
	PcPlayer* p_player = this;

	if (!p_player->m_canUseSpecialMagic())
	{
		game::console::writeConsole(7, 1, "당신에게는 아직 능력이 없습니다.");
		return;
	}

	std::vector<PcEnemy*>& enemy = game::object::getEnemyList();

	PcEnemy* p_enemy = enemy[ix_enemy];

	assert(p_player != NULL);
	assert(p_enemy  != NULL);

	if (p_enemy == NULL)
		return;

	switch (ix_object)
	{
	case 1:
		{
			DETECT_NOT_ENOUGH_SP(10)

			p_player->sp -= 10;

			if (AvejUtil::random(100) < p_enemy->resistance)
			{
				game::console::writeConsole(7, 1, "적은 독 공격을 저지 했다");
				return;
			}

			if (AvejUtil::random(40) > p_player->accuracy[1])
			{
				game::console::writeConsole(7, 1, "독 공격은 빗나갔다");
				return;
			}

			game::console::writeConsole(4, 2, p_enemy->getName(JOSA_SUB), " 중독 되었다");
			++p_enemy->poison;
		}
		break;
	case 2:
		{
			DETECT_NOT_ENOUGH_SP(30)

			p_player->sp -= 30;

			if (AvejUtil::random(100) < p_enemy->resistance)
			{
				game::console::writeConsole(7, 1, "기술 무력화 공격은 저지 당했다");
				return;
			}

			if (AvejUtil::random(60) > p_player->accuracy[1])
			{
				game::console::writeConsole(7, 1, "기술 무력화 공격은 빗나갔다");
				return;
			}

			game::console::writeConsole(4, 2, p_enemy->getName(JOSA_NONE), "의 특수 공격 능력이 제거되었다");

			p_enemy->special = 0;
		}
		break;
	case 3:
		{
			DETECT_NOT_ENOUGH_SP(15)

			p_player->sp -= 15;

			if (AvejUtil::random(100) < p_enemy->resistance)
			{
				game::console::writeConsole(7, 1, "방어 무력화 공격은 저지 당했다");
				return;
			}

			int temp = (p_enemy->ac < 5) ? 40 : 25;

			if (AvejUtil::random(temp) > p_player->accuracy[1])
			{
				game::console::writeConsole(7, 1, "방어 무력화 공격은 빗나갔다");
				return;
			}

			game::console::writeConsole(4, 2, p_enemy->getName(JOSA_NONE), "의 방어 능력이 저하되었다");

			if ((p_enemy->resistance < 31) || (AvejUtil::random(2) == 0))
				--p_enemy->ac;
			else
				p_enemy->resistance -= 10;
		}
		break;
	case 4:
		{
			DETECT_NOT_ENOUGH_SP(20)

			p_player->sp -= 20;

			if (AvejUtil::random(200) < p_enemy->resistance)
			{
				game::console::writeConsole(7, 1, "능력 저하 공격은 저지 당했다");
				return;
			}

			if (AvejUtil::random(30) > p_player->accuracy[1])
			{
				game::console::writeConsole(7, 1, "능력 저하 공격은 빗나갔다");
				return;
			}

			game::console::writeConsole(4, 2, p_enemy->getName(JOSA_NONE), "의 전체적인 능력이 저하되었다");

			if (p_enemy->level > 1)
				--p_enemy->level;

			if (p_enemy->resistance > 0)
				p_enemy->resistance -= 10;
			else
				p_enemy->resistance = 0;
		}
		break;
	case 5:
		{
			DETECT_NOT_ENOUGH_SP(15)

			p_player->sp -= 15;

			if (AvejUtil::random(100) < p_enemy->resistance)
			{
				game::console::writeConsole(7, 1, "마법 불능 공격은 저지 당했다");
				return;
			}

			if (AvejUtil::random(100) > p_player->accuracy[1])
			{
				game::console::writeConsole(7, 1, "마법 불능 공격은 빗나갔다");
				return;
			}

			if (p_enemy->cast_level > 0)
				--p_enemy->cast_level;

			if (p_enemy->cast_level > 0)
				game::console::writeConsole(4, 2, p_enemy->getName(JOSA_NONE), "의 마법 능력이 저하되었다");
			else
				game::console::writeConsole(4, 2, p_enemy->getName(JOSA_NONE), "의 마법 능력은 사라졌다");

		}
		break;
	case 6:
		{
			DETECT_NOT_ENOUGH_SP(20)

			p_player->sp -= 20;

			if (AvejUtil::random(100) < p_enemy->resistance)
			{
				game::console::writeConsole(7, 1, "탈 초인화 공격은 저지 당했다");
				return;
			}

			if (AvejUtil::random(100) > p_player->accuracy[1])
			{
				game::console::writeConsole(7, 1, "탈 초인화 공격은 빗나갔다");
				return;
			}

			if (p_enemy->special_cast_level > 0)
				--p_enemy->special_cast_level;

			if (p_enemy->special_cast_level > 0)
				game::console::writeConsole(4, 1, p_enemy->getName(JOSA_NONE), "의 초자연적 능력이 저하되었다");
			else
				game::console::writeConsole(4, 1, p_enemy->getName(JOSA_NONE), "의 초자연적 능력은 사라졌다");
		}
		break;
	default:
		assert(false);
	}
}

bool hadar::PcPlayer::tryToRunAway()
{
	PcPlayer* p_player = this;

	if (AvejUtil::random(50) > p_player->agility)
	{
		game::console::writeConsole(7, 1, "그러나, 일행은 성공하지 못했다");
		return false;
	}
	else
	{
		game::console::writeConsole(11, 1, "성공적으로 도망을 갔다");
		return true;
	}
}

////////////////////////////////////////////////////////////////////////////////
// private method

namespace
{
	template <typename InIter, typename Function>
	Function ForEachParam1(InIter iter_begin, InIter iter_end, Function func, int param1)
	{
		while (iter_begin != iter_end)
			func(*iter_begin++, param1);

		return func;
	}

	// 아군 캐릭터의 경험치를 올려주는 함수자
	template <class type>
	class FnPlusExp
	{
		typedef type Type;

	public:
		void operator()(Type obj, int plus)
		{
			if (obj->isValid())
				obj->experience += plus;
		}
	};
}

void hadar::PcPlayer::m_healOne(PcPlayer* p_target)
{
	PcPlayer* p_player = this;

	assert(p_player);
	assert(p_target);

	if ((p_target->dead > 0) || (p_target->unconscious > 0) || (p_target->poison > 0))
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 치료될 상태가 아닙니다.");

		return;
	}

	if (p_target->hp >= p_target->endurance * p_target->level[0])
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 치료할 필요가 없습니다.");

		return;
	}

	int consumption = 2 * p_player->level[1];

	if (p_player->sp < consumption)
	{
		if (!game::status::inBattle())
			m_printSpNotEnough();

		return;
	}

	p_player->sp -= consumption;
	p_target->hp += (consumption * 3 / 2);

	if (p_target->hp > p_target->level[0] * p_target->endurance)
		p_target->hp = p_target->level[0] * p_target->endurance;

	game::console::writeConsole(15, 2, p_target->getName(JOSA_SUB), " 치료되어 졌습니다.");
}

void hadar::PcPlayer::m_antidoteOne(PcPlayer* p_target)
{
	PcPlayer* p_player = this;

	if ((p_target->dead > 0) || (p_target->unconscious > 0))
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 독이 치료될 상태가 아닙니다.");

		return;
	}

	if (p_target->poison == 0)
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 독에 걸리지 않았습니다.");

		return;
	}

	if (p_player->sp < 15)
	{
		if (!game::status::inBattle())
			m_printSpNotEnough();

		return;
	}

	p_player->sp -= 15;
	p_target->poison = 0;

	game::console::writeConsole(15, 2, p_target->getName(), "의 독은 제거 되었습니다.");
}

void hadar::PcPlayer::m_recoverConsciousnessOne(PcPlayer* p_target)
{
	PcPlayer* p_player = this;

	if (p_target->dead > 0)
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 의식이 돌아올 상태가 아닙니다.");

		return;
	}

	if (p_target->unconscious == 0)
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 의식불명이 아닙니다.");

		return;
	}

	int consumption = 10 * p_target->unconscious;

	if (p_player->sp < consumption)
	{
		if (!game::status::inBattle())
			m_printSpNotEnough();

		return;
	}

	p_player->sp -= consumption;
	p_target->unconscious = 0;

	if (p_target->hp <= 0)
		p_target->hp = 1;

	game::console::writeConsole(15, 2, p_target->getName(JOSA_SUB), " 의식을 되찾았습니다.");
}

void hadar::PcPlayer::m_revitalizeOne(PcPlayer* p_target)
{
	PcPlayer* p_player = this;

	if (p_target->dead == 0)
	{
		if (!game::status::inBattle())
			game::console::writeConsole(7, 2, p_target->getName(JOSA_SUB), " 아직 살아 있습니다.");

		return;
	}

	int consumption = 30 * p_target->dead;

	if (p_player->sp < consumption)
	{
		if (!game::status::inBattle())
			m_printSpNotEnough();

		return;
	}

	p_player->sp -= consumption;

	p_target->dead = 0;

	if (p_target->unconscious > p_target->endurance * p_target->level[0])
		p_target->unconscious = p_target->endurance * p_target->level[0];

	if (p_target->unconscious == 0)
		p_target->unconscious = 1;

	game::console::writeConsole(15, 2, p_target->getName(JOSA_SUB), " 다시 생명을 얻었습니다.");
}

void hadar::PcPlayer::m_healAll(void)
{
	std::vector<PcPlayer*>& player = game::object::getPlayerList();

	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
	{
		if ((*obj)->isValid())
			m_healOne(*obj);
	}
}

void hadar::PcPlayer::m_antidoteAll(void)
{
	std::vector<PcPlayer*>& player = game::object::getPlayerList();

	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
	{
		if ((*obj)->isValid())
			m_antidoteOne(*obj);
	}
}

void hadar::PcPlayer::m_recoverConsciousnessAll(void)
{
	std::vector<PcPlayer*>& player = game::object::getPlayerList();

	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
	{
		if ((*obj)->isValid())
			m_recoverConsciousnessOne(*obj);
	}
}

void hadar::PcPlayer::m_revitalizeAll(void)
{
	std::vector<PcPlayer*>& player = game::object::getPlayerList();

	for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
	{
		if ((*obj)->isValid())
			m_revitalizeOne(*obj);
	}
}

bool hadar::PcPlayer::m_canUseSpecialMagic(void)
{
	PcParty& party = game::object::getParty();
	return (party.ability.can_use_special_magic);
}

bool hadar::PcPlayer::m_canUseESP(void)
{
	// 아래의 조건 중 하나만 만족하면 된다

	// ESP 습득 여부
	{
		PcParty& party = game::object::getParty();
		if (party.ability.can_use_ESP)
			return true;
	}
		
	// Class 제약 확인
	{
		static const SmSet s_ESPer("2,3,6");
		if (s_ESPer.isSet(class_))
			return true;
	}

	return false;
}

void hadar::PcPlayer::m_plusExperience(PcEnemy* p_enemy)
{
	PcPlayer* p_player = this;

	assert(p_player != NULL);
	assert(p_enemy  != NULL);

	long plus = p_enemy->ed_number;
	plus = plus * plus * plus / 8;

	if (plus == 0)
		plus = 1;

	if (p_enemy->unconscious == 0)
	{
		game::console::writeConsole(14, 4, p_player->getName(JOSA_SUB), " ", IntToStr(plus)(), "만큼 경험치를 얻었다 !");
		p_player->experience += plus;
	}
	else
	{
		std::vector<PcPlayer*>& player = game::object::getPlayerList();
		ForEachParam1(player.begin(), player.end(), FnPlusExp<PcPlayer*>(), plus);
	}
}

void hadar::PcPlayer::m_printSpNotEnough(void)
{
	game::console::showMessage(7, "마법 지수가 충분하지 않습니다.");
}

void hadar::PcPlayer::m_printESPNotEnough(void)
{
	game::console::showMessage(7, "ESP 지수가 충분하지 않습니다.");
}

////////////////////////////////////////////////////////////////////////////////
// global function

avej::string hadar::getBattleMessage(const hadar::PcPlayer& who, int how, int what, const hadar::PcEnemy& whom)
{
	avej::string s;

	s += who.getName(PcNameBase::JOSA_SUB);
	s += " ";

	switch (how)
	{
	case 1:
		s += resource::getWeaponName(who.weapon).sz_name;
		s += resource::getWeaponName(who.weapon).sz_josa_with;
		s += "로 ";
		s += whom.getName(PcNameBase::JOSA_OBJ);
		s += " 공격했다";
		break;
	case 2:
		s += resource::getMagicName(what).sz_name;
		s += resource::getMagicName(what).sz_josa_with;
		s += "로 ";
		s += whom.getName(PcNameBase::JOSA_NONE);
		s += "에게 공격했다";
		break;
	case 3:
		s += resource::getMagicName(what+6).sz_name;
		s += resource::getMagicName(what+6).sz_josa_with;
		s += "로 ";
		s += whom.getName(PcNameBase::JOSA_NONE);
		s += "에게 공격했다";
		break;
	case 4:
		s += whom.getName(PcNameBase::JOSA_NONE);
		s += "에게 ";
		s += resource::getMagicName(what+12).sz_name;
		s += resource::getMagicName(what+12).sz_josa_with;
		s += "로 특수 공격을 했다";
		break;
	case 5:
		s += whom.getName(PcNameBase::JOSA_NONE);
		s += "에게 ";
		s += resource::getMagicName(what+18).sz_name;
		s += resource::getMagicName(what+18).sz_josa_obj;
		s += " 사용했다";
		break;
	case 6:
		s += whom.getName(PcNameBase::JOSA_NONE);
		s += "에게 ";
		s += resource::getMagicName(what+40).sz_name;
		s += resource::getMagicName(what+40).sz_josa_obj;
		s += " 사용했다";
		break;
	case 7:
		s  = "일행은 도망을 시도했다";
		break;
	default:
		s += "잠시 주저했다";
	}

	return s;
}
