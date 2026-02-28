
#include "hd_class_pc_enemy.h"

#include "hd_class_pc_player.h"
#include "UAvejUtil.h"
#include "hd_base_extern.h"
#include <assert.h>
#include <algorithm>
#include <string>
#include <map>

using namespace avej;

namespace
{
	using hadar::PcPlayer;
	using hadar::PcEnemy;

	enum PLAYERSTATUS
	{
		PLAYERSTATUS_CONSCIOUS, // 의식이 있는 상태
		PLAYERSTATUS_NOT_DEAD,  // 죽지 않은 상태
		PLAYERSTATUS_ALL,       // 유효한 모든 상태
	};

	PcPlayer* getRandomPlayer(PLAYERSTATUS status)
	{
		PcPlayer* p_player = NULL;
		int num_player = 0;

		std::vector<PcPlayer*>& player = hadar::game::object::getPlayerList();

		for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
		{
			if (!(*obj)->isValid())
				continue;

			if (status == PLAYERSTATUS_CONSCIOUS)
				if (((*obj)->unconscious > 0) || ((*obj)->dead > 0) || ((*obj)->hp == 0))
					continue;

			if (status == PLAYERSTATUS_NOT_DEAD)
				if ((*obj)->dead > 0)
					continue;

			++num_player;
		}

		if (num_player > 0)
		{
			int order = AvejUtil::random(num_player);

			for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
			{
				if (!(*obj)->isValid())
					continue;

				if (status == PLAYERSTATUS_CONSCIOUS)
					if (((*obj)->unconscious > 0) || ((*obj)->dead > 0) || ((*obj)->hp == 0))
						continue;

				if (status == PLAYERSTATUS_NOT_DEAD)
					if ((*obj)->dead > 0)
						continue;

				if (order-- == 0)
				{
					p_player = *obj;
					break;
				}
			}
		}
		else
		{
			// 만약 해당되는 조건에 맞는 캐릭터가 없다면 임의로 추출한다.
			p_player = player[AvejUtil::random(player.size())];

			if (!p_player->isValid())
				p_player = NULL;
		}

		return p_player;
	}

	void setEnemyName(PcEnemy& enemy, const char* sz_name)
	{
		enemy.setName(sz_name);
	}

	void getEnemyName(PcEnemy& enemy, avej::string& ref_name)
	{
		const char* sz_name = enemy.getName();
		ref_name = sz_name;
	}

	/* 호출 순서도
	Attack -+-> enemyAttackWithWeapon
	        |
	        +-> enemyCastSpell -+-> enemyCastAttackSpellToAll -,
	        |                |                           |
	        |                +-> enemyCastAttackSpellToOne -+-> enemyCastAttackSpellSub
	        |                |
	        |                `-> enemyCastCureSpell
	        |
	        +-> enemyAttackWithSpecialAbility
	        |
	        `-> enemyCastSpellWithSpecialAbility
	*/
	void enemyAttackWithWeapon(PcEnemy* p_enemy);
	void enemyCastSpell(PcEnemy* p_enemy);
	void enemyCastAttackSpellToAll(PcEnemy* p_enemy);
	void enemyCastAttackSpellToOne(PcEnemy* p_enemy, PcPlayer* p_player);
	void enemyCastAttackSpellSub(PcEnemy* p_enemy, PcPlayer* p_player, int damage);
	void enemyCastCureSpell(PcEnemy* p_enemy, PcEnemy* p_target, int recovery);
	void enemyAttackWithSpecialAbility(PcEnemy* p_enemy);
	void enemyCastSpellWithSpecialAbility(PcEnemy* p_enemy);
}

// local variables
namespace
{
	typedef std::map<std::string, int> AttribMapInt;
	AttribMapInt s_m_attrib_map_int_list;

	typedef void (*FnSet)(PcEnemy&, const char*);
	typedef void (*FnGet)(PcEnemy&, avej::string&);
	typedef std::pair<void*, void*> FnSetGet;
	typedef std::map<std::string, FnSetGet> AttribMapStr;
	AttribMapStr s_m_attrib_map_str_list;
}

////////////////////////////////////////////////////////////////////////////////
// serializing method

bool hadar::PcEnemy::_load(const ReadStream& stream)
{
	return false;
}

bool hadar::PcEnemy::_save(const WriteStream& stream) const
{
	return false;
}

////////////////////////////////////////////////////////////////////////////////
// public method

hadar::PcEnemy::PcEnemy(void)
{
	// static data의 초기화
	if (s_m_attrib_map_int_list.empty())
	{
		s_m_attrib_map_int_list["ed_number"]          = int(&this->ed_number) - int(this);
		s_m_attrib_map_int_list["strength"]           = int(&this->strength) - int(this);
		s_m_attrib_map_int_list["mentality"]          = int(&this->mentality) - int(this);
		s_m_attrib_map_int_list["endurance"]          = int(&this->endurance) - int(this);
		s_m_attrib_map_int_list["resistance"]         = int(&this->resistance) - int(this);
		s_m_attrib_map_int_list["agility"]            = int(&this->agility) - int(this);
		s_m_attrib_map_int_list["accuracy[0]"]        = int(&this->accuracy[0]) - int(this);
		s_m_attrib_map_int_list["accuracy[1]"]        = int(&this->accuracy[1]) - int(this);
		s_m_attrib_map_int_list["ac"]                 = int(&this->ac) - int(this);
		s_m_attrib_map_int_list["special"]            = int(&this->special) - int(this);
		s_m_attrib_map_int_list["cast_level"]         = int(&this->cast_level) - int(this);
		s_m_attrib_map_int_list["special_cast_level"] = int(&this->special_cast_level) - int(this);
		s_m_attrib_map_int_list["level"]              = int(&this->level) - int(this);
	}

	if (s_m_attrib_map_str_list.empty())
	{
		s_m_attrib_map_str_list["_name"] = std::make_pair((void*)setEnemyName, (void*)getEnemyName);
	}
}

hadar::PcEnemy::~PcEnemy(void)
{
}

void hadar::PcEnemy::operator<<(const EnemyData& data)
{
	CT_ASSERT(sizeof(_name) >= sizeof(data._name), name_is_too_small);

	// 이름 설정
	setName(data._name);

	// 기타 속성 설정
	strength           = data.strength;
	mentality          = data.mentality;
	endurance          = data.endurance;
	resistance         = data.resistance;
	agility            = data.agility;
	accuracy[0]        = data.accuracy[0];
	accuracy[1]        = data.accuracy[1];
	ac                 = data.ac;
	special            = data.special;
	cast_level         = data.cast_level;
	special_cast_level = data.special_cast_level;
	level              = data.level;

	// 속성에서 계산 가능한 값
	hp                 = endurance * level;
	poison             = 0;
	unconscious        = 0;
	dead               = 0;

	ed_number          = 1;
}

void hadar::PcEnemy::operator<<(const PcPlayer& player)
{
	setName(player.getName(JOSA_NONE));

	strength           = player.strength;
	mentality          = player.mentality;
	endurance          = player.endurance;
	resistance         = player.resistance;
	agility            = player.agility;
	accuracy[0]        = player.accuracy[0];
	accuracy[1]        = player.accuracy[1];
	ac                 = player.ac;
	special            = (player.class_ == 7) ? 2 : 0;
	cast_level         = player.level[1] / 4;
	special_cast_level = 0;
	level              = player.level[0];

	hp                 = endurance * level;
	poison             = 0;
	unconscious        = 0;
	dead               = 0;

	ed_number          = 1;
}

bool hadar::PcEnemy::isConscious(void) const
{
	return this->isValid() && (unconscious == 0) && (dead == 0) && (hp > 0);
}

void hadar::PcEnemy::attack(void)
{
	PcEnemy* p_enemy = this;

	if (p_enemy->special_cast_level > 0)
		enemyCastSpellWithSpecialAbility(p_enemy);

	int agility = p_enemy->agility;

	if (agility > 20)
		agility = 20;

	if ((p_enemy->special > 0) && (AvejUtil::random(50) < agility))
	{
		int num_alive = game::player::getNumOfConsciousPlayer();

		if (num_alive > 3)
		{
			enemyAttackWithSpecialAbility(p_enemy);
			return;
		}
	}

	if ((AvejUtil::random(p_enemy->accuracy[0]*1000) > AvejUtil::random(p_enemy->accuracy[1]*1000)) && (p_enemy->strength > 0))
	{
		enemyAttackWithWeapon(p_enemy);
	}
	else
	{
		if (p_enemy->cast_level > 0)
			enemyCastSpell(p_enemy);
		else
			enemyAttackWithWeapon(p_enemy);
	}
}

bool hadar::PcEnemy::changeAttribute(const char* sz_attribute, int value)
{
	AttribMapInt::iterator attrib = s_m_attrib_map_int_list.find(sz_attribute);

	if (attrib == s_m_attrib_map_int_list.end())
		return false;

	int* p_int = reinterpret_cast<int*>(int(this) + int(attrib->second));

	*p_int = value;

	return true;
}

bool hadar::PcEnemy::changeAttribute(const char* sz_attribute, const char* sz_data)
{
	AttribMapStr::iterator attrib = s_m_attrib_map_str_list.find(sz_attribute);

	if (attrib == s_m_attrib_map_str_list.end())
		return false;

	FnSet((attrib->second).first)(*this, sz_data);

	return true;
}

////////////////////////////////////////////////////////////////////////////////
// private method

namespace
{
	void enemyAttackWithWeapon(PcEnemy* p_enemy)
	{
		if (AvejUtil::random(20) >= p_enemy->accuracy[0])
		{
			hadar::game::console::writeConsole(7, 2, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " 빗맞추었다");
			return;
		}

		PcPlayer* p_player = getRandomPlayer(PLAYERSTATUS_CONSCIOUS);

		if (p_player == NULL)
			return;

		int damage = p_enemy->strength * p_enemy->level * (AvejUtil::random(10)+1) / 10;

		if (p_player->isConscious())
		{
			if (AvejUtil::random(50) < p_player->resistance)
			{
				hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_player->getName(hadar::PcEnemy::JOSA_OBJ), " 공격했다");
				hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 적의 공격을 저지했다");
				return;
			}
			damage -= (p_player->ac * p_player->level[0] * (AvejUtil::random(10)+1) / 10);
		}

		if (damage <= 0)
		{
			hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_player->getName(hadar::PcEnemy::JOSA_OBJ), " 공격했다");
			hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 적의 공격을 방어했다");
			return;
		}

		if (p_player->dead > 0)
			p_player->dead += damage;
		if ((p_player->unconscious > 0) && (p_player->dead == 0))
			p_player->unconscious += damage;
		if (p_player->hp > 0)
			p_player->hp -= damage;

		hadar::game::console::writeConsole(13, 4, p_player->getName(hadar::PcEnemy::JOSA_SUB), " ", p_enemy->getName(hadar::PcEnemy::JOSA_NONE), "에게 공격 받았다");
		hadar::game::console::writeConsole(5, 4, p_player->getName(hadar::PcEnemy::JOSA_SUB), " @D", IntToStr(damage)(), "@@만큼의 피해를 입었다");
	}

	void enemyCastSpell(PcEnemy* p_enemy)
	{
		PcPlayer* p_player = NULL;

		std::vector<PcEnemy*>& enemy = hadar::game::object::getEnemyList();
		std::vector<PcPlayer*>& player = hadar::game::object::getPlayerList();

		switch (p_enemy->cast_level)
		{
		case 0:
			break;
		case 1:
			{
				p_player = player[AvejUtil::random(player.size())];
				if (!p_player->isConscious())
					p_player = player[AvejUtil::random(player.size())];

				enemyCastAttackSpellToOne(p_enemy, p_player);
			}
			break;
		case 2:
			{
				enemyCastAttackSpellToOne(p_enemy, getRandomPlayer(PLAYERSTATUS_CONSCIOUS));
			}
			break;
		case 3:
			{
				if (AvejUtil::random(hadar::game::player::getNumOfConsciousPlayer()) < 2)
					enemyCastAttackSpellToOne(p_enemy, getRandomPlayer(PLAYERSTATUS_CONSCIOUS));
				else
					enemyCastAttackSpellToAll(p_enemy);
			}
			break;
		case 4:
			{
				if ((p_enemy->hp < p_enemy->endurance * p_enemy->level / 3) && (AvejUtil::random(2) == 0))
				{
					enemyCastCureSpell(p_enemy, p_enemy, p_enemy->level * p_enemy->mentality / 4);
				}
				else
				{
					if (AvejUtil::random(hadar::game::player::getNumOfConsciousPlayer()) < 2)
						enemyCastAttackSpellToOne(p_enemy, getRandomPlayer(PLAYERSTATUS_CONSCIOUS));
					else
						enemyCastAttackSpellToAll(p_enemy);
				}
			}
			break;
		case 5:
			{
				if ((p_enemy->hp < p_enemy->endurance * p_enemy->level / 3) && (AvejUtil::random(3) == 0))
				{
					enemyCastCureSpell(p_enemy, p_enemy, p_enemy->level * p_enemy->mentality / 4);
				}
				else
				{
					if (AvejUtil::random(hadar::game::player::getNumOfConsciousPlayer()) < 2)
					{
						int total_hp = 0;
						int total_max_hp = 0;

						for (std::vector<PcEnemy*>::iterator obj = enemy.begin(); obj != enemy.end(); ++obj)
						{
							if ((*obj)->isValid())
							{
								total_hp += (*obj)->hp;
								total_max_hp += (*obj)->endurance * (*obj)->level;
							}
						}

						if ((enemy.size() > 2) && (total_hp*3 < total_max_hp) && (AvejUtil::random(2) == 0))
						{
							for (std::vector<PcEnemy*>::iterator obj = enemy.begin(); obj != enemy.end(); ++obj)
							{
								if ((*obj)->isValid())
									enemyCastCureSpell(p_enemy, (*obj), p_enemy->level * p_enemy->mentality / 6);
							}
						}
						else
						{
							// party에서 의식이 있는 사람 중에 가장 hp가 낮은 사람을 공격
							p_player = *player.begin();
							for (std::vector<PcPlayer*>::iterator obj = player.begin()+1; obj != player.end(); ++obj)
							{
								if ((*obj)->isValid())
								{
									if ((*obj)->hp < p_player->hp)
										p_player = (*obj);
								}
							}

							if (p_player->isValid())
								enemyCastAttackSpellToOne(p_enemy, p_player);
						}
					}
					else
					{
						enemyCastAttackSpellToAll(p_enemy);
					}
				}
			}
			break;
		case 6:
			{
				if ((p_enemy->hp < p_enemy->endurance * p_enemy->level / 3) && (AvejUtil::random(3) == 0))
				{
					enemyCastCureSpell(p_enemy, p_enemy, p_enemy->level * p_enemy->mentality / 4);
					return;
				}

				int average_ac = 0;

				{
					int accum_ac = 0;
					int num_player = 0;;
					for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
					{
						if ((*obj) && ((*obj)->isValid()))
						{
							++num_player;
							accum_ac += p_enemy->ac;
						}
					}
					average_ac = (num_player > 0) ? (accum_ac / num_player) : 0;
				}

				if ((average_ac > 4) && (AvejUtil::random(5) == 0))
				{
					for (std::vector<PcPlayer*>::iterator obj = player.begin()+1; obj != player.end(); ++obj)
					{
						if ((*obj)->isValid())
						{
							hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", (*obj)->getName(hadar::PcEnemy::JOSA_NONE), "의 갑옷파괴를 시도했다");
							if ((*obj)->luck > AvejUtil::random(21))
							{
								hadar::game::console::writeConsole(7, 3, "그러나, ", p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " 성공하지 못했다");
							}
							else
							{
								hadar::game::console::writeConsole(5, 2, (*obj)->getName(hadar::PcEnemy::JOSA_NONE), "의 갑옷은 파괴되었다");
								if ((*obj)->ac > 0)
									--(*obj)->ac;
							}
						}
					}

					hadar::game::window::displayStatus();
				}
				else
				{
					int total_hp = 0;
					int total_max_hp = 0;

					for (std::vector<PcEnemy*>::iterator obj = enemy.begin(); obj != enemy.end(); ++obj)
					{
						if ((*obj)->isValid())
						{
							total_hp += (*obj)->hp;
							total_max_hp += (*obj)->endurance * (*obj)->level;
						}
					}

					if ((enemy.size() > 2) && (total_hp*3 < total_max_hp) && (AvejUtil::random(3) == 0))
					{
						for (std::vector<PcEnemy*>::iterator obj = enemy.begin(); obj != enemy.end(); ++obj)
						{
							if ((*obj)->isValid())
								enemyCastCureSpell(p_enemy, (*obj), p_enemy->level * p_enemy->mentality / 6);
						}
					}
					else
					{
						if (AvejUtil::random(hadar::game::player::getNumOfConsciousPlayer()) < 2)
						{
							// party에서 의식이 있는 사람 중에 가장 hp가 낮은 사람을 공격
							p_player = *player.begin();
							int hp = (p_player->isConscious()) ? p_player->hp : 0x7FFFFFFFL;
							for (std::vector<PcPlayer*>::iterator obj = player.begin()+1; obj != player.end(); ++obj)
							{
								if ((*obj)->isValid())
								{
									if ((*obj)->isConscious())
									{
										if ((*obj)->hp < hp)
										{
											p_player = (*obj);
											hp = p_player->hp;
										}
									}
								}
							}

							if (p_player->isValid())
								enemyCastAttackSpellToOne(p_enemy, p_player);
						}
						else
						{
							enemyCastAttackSpellToAll(p_enemy);
						}
					}
				}
			}
			break;
		default:
			assert(false);
		}
	}

	void enemyAttackWithSpecialAbility(PcEnemy* p_enemy)
	{
		PcPlayer* p_player = NULL;

		switch (p_enemy->special)
		{
		case 1:
			{
				for (int i = 0; i < 5; i++)
				{
					p_player = getRandomPlayer(PLAYERSTATUS_CONSCIOUS);
					if ((p_player != NULL) && (p_player->poison == 0))
						break;
				}

				if (p_player == NULL)
					return;

				hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_player->getName(hadar::PcEnemy::JOSA_NONE), "에게 독 공격을 시도했다");

				if (AvejUtil::random(40) > p_enemy->agility)
				{
					hadar::game::console::writeConsole(7, 1, "독 공격은 실패했다");
					return;
				}

				if (AvejUtil::random(20) < p_player->luck)
				{
					hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 독 공격을 피했다");
					return;
				}

				hadar::game::console::writeConsole(4, 2, p_player->getName(hadar::PcEnemy::JOSA_SUB), " 중독 되었다 !!");

				++p_player->poison;
			}
			break;
		case 2:
			{
				p_player = getRandomPlayer(PLAYERSTATUS_CONSCIOUS);

				if (p_player == NULL)
					return;

				hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_player->getName(hadar::PcEnemy::JOSA_NONE), "에게 치명적 공격을 시도했다");

				if (AvejUtil::random(50) > p_enemy->agility)
				{
					hadar::game::console::writeConsole(7, 1, "치명적 공격은 실패했다");
					return;
				}

				if (AvejUtil::random(20) < p_player->luck)
				{
					hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 치명적 공격을 피했다");
					return;
				}

				hadar::game::console::writeConsole(4, 2, p_player->getName(hadar::PcEnemy::JOSA_SUB), " 의식불명이 되었다 !!");

				if (p_player->unconscious == 0)
				{
					p_player->unconscious = 1;
					if (p_player->hp > 0)
						p_player->hp = 0;
				}
			}
			break;
		case 3:
			{
				p_player = getRandomPlayer(PLAYERSTATUS_NOT_DEAD);

				if (p_player == NULL)
					return;

				hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_player->getName(hadar::PcEnemy::JOSA_NONE), "에게 죽음의 공격을 시도했다");

				if (AvejUtil::random(60) > p_enemy->agility)
				{
					hadar::game::console::writeConsole(7, 1, "죽음의 공격은 실패했다");
					return;
				}

				if (AvejUtil::random(20) < p_player->luck)
				{
					hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 죽음의 공격을 피했다");
					return;
				}

				hadar::game::console::writeConsole(4, 2, p_player->getName(hadar::PcEnemy::JOSA_SUB), " 죽었다 !!");

				if (p_player->dead == 0)
				{
					p_player->dead = 1;
					if (p_player->hp > 0)
						p_player->hp = 0;
				}
			}
			break;
		}
	}

	void enemyCastSpellWithSpecialAbility(PcEnemy* p_enemy)
	{
		//?? 전체 코드 다시 봐야 함
		if (p_enemy->special_cast_level <= 0)
			return;

		// 특수한 경우임, 보통은 코드로 조작된 적
		if (p_enemy->ed_number <= 1)
			return;

		std::vector<PcEnemy*>& enemy = hadar::game::object::getEnemyList();
		std::vector<PcPlayer*>& player = hadar::game::object::getPlayerList();

		int num_enemy = enemy.size();

		{
			// 죽지 않은 적의 수
			int num_not_dead = 0;
			// 죽은 적 중에서 제일 앞에 있는 적
			int ix_enemy = num_enemy - 1;

			for (int i = num_enemy - 1; i >= 0; --i)
			{
				if (enemy[i]->dead == 0)
					++num_not_dead;
				else
					ix_enemy = i;
			}

			if ((num_not_dead < AvejUtil::random(3)+2) && (AvejUtil::random(3) == 0))
			{
				if (num_enemy < int(enemy.capacity()))
				{
					hadar::game::battle::registerEnemy(p_enemy->ed_number + AvejUtil::random(4) - 20);
					num_enemy = enemy.size();
				}
				else
				{
					int index = p_enemy->ed_number + AvejUtil::random(4) - 20;
					//@@ enemy[ix_enemy]의 유효성이 검증되었나?
					*enemy[ix_enemy] << hadar::getEnemyDataFromEnemyTable(index);
					enemy[ix_enemy]->ed_number = index;
				}

				hadar::game::window::displayBattle(0); //@@ 0 맞나?
				hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", enemy[ix_enemy]->getName(hadar::PcEnemy::JOSA_OBJ), " 생성시켰다");
			}

			if (p_enemy->special_cast_level > 1)
			{
				PcPlayer* p_last_player = *(player.end() - 1);
				if ((p_last_player->isValid()) && (num_not_dead < 7) && (AvejUtil::random(5) == 0))
				{
					if (num_enemy < int(enemy.capacity()))
						ix_enemy = num_enemy++;

					*enemy[ix_enemy] << *p_last_player;
					p_last_player->setName("");

					hadar::game::window::displayStatus();
					hadar::game::window::displayBattle(0); //@@ 0이 맞는지 확인 필요

					hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB2), " 독심술을 사용하여 ", enemy[ix_enemy]->getName(hadar::PcEnemy::JOSA_OBJ), " 자기편으로 끌어들였다");
				}
			}

			if (p_enemy->special_cast_level > 2)
			{
				int ix_player;

				if (p_enemy->special == 0)
					return;

				if (AvejUtil::random(5) == 0)
				for (ix_player = 0; ix_player < 6; ix_player++)
				if ((player[ix_player]->dead == 0) && (player[ix_player]->isValid()))
				{
					hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", player[ix_player]->getName(hadar::PcEnemy::JOSA_NONE), "에게 죽음의 공격을 시도했다");

					if (AvejUtil::random(60) > p_enemy->agility)
						hadar::game::console::writeConsole(7, 1, "죽음의 공격은 실패했다");
					else if (AvejUtil::random(20) < player[ix_player]->luck)
						hadar::game::console::writeConsole(7, 3, "그러나, ", player[ix_player]->getName(hadar::PcEnemy::JOSA_SUB), "죽음의 공격을 피했다");
					else
					{
						hadar::game::console::writeConsole(4, 2, player[ix_player]->getName(hadar::PcEnemy::JOSA_SUB), " 죽었다!!");
						if (player[ix_player]->dead == 0)
						{
							player[ix_player]->dead = 1;
							if (player[ix_player]->hp > 0)
								player[ix_player]->hp = 0;
						}
					}
				}
			}
			
		}
	}

	void enemyCastAttackSpellToAll(PcEnemy* p_enemy)
	{
		//@@ 원래는 리소스 관리 쪽으로 넘어 가야 함
		struct MagicTable
		{
			const char* sz_magic_name;
			int damage;
		};
		
		static const MagicTable MAGIC_TABLE[] = 
		{
			{ "열파",     1},  // 0
			{ "에너지",   2},  // 2
			{ "초음파",   3},  // 3
			{ "혹한기",   5},  // 4
			{ "화염폭풍", 8},  // 5
		};

		const int MAX_CONVERT_TABLE = 21;
		static const int CONVERT_TABLE[MAX_CONVERT_TABLE+1] =
		{
		//  0  1  2  3  4  5  6  7  8  9
			0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
			1, 1, 1, 2, 2, 2, 2, 3, 3, 3,
			3, 4
		};

		int mentality = p_enemy->mentality;

		if (mentality < 0)
			mentality = 0;

		if (mentality > MAX_CONVERT_TABLE)
			mentality = MAX_CONVERT_TABLE;

		const MagicTable& magic = MAGIC_TABLE[CONVERT_TABLE[mentality]];

		hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " 일행 모두에게 '", magic.sz_magic_name, "'마법을 사용했다");

		std::vector<PcPlayer*>& player = hadar::game::object::getPlayerList();

		for (std::vector<PcPlayer*>::iterator obj = player.begin(); obj != player.end(); ++obj)
			enemyCastAttackSpellSub(p_enemy, *obj, magic.damage * p_enemy->level);
	}

	void enemyCastAttackSpellToOne(PcEnemy* p_enemy, PcPlayer* p_player)
	{
		//@@ 원래는 리소스 관리 쪽으로 넘어 가야 함
		struct MagicTable
		{
			const char* sz_magic_name;
			int damage;
		};
		
		static const MagicTable MAGIC_TABLE[] = 
		{
			{ "충격", 1},  // 0
			{ "냉기", 2},  // 2
			{ "고통", 4},  // 3
			{ "혹한", 6},  // 4
			{ "화염", 7},  // 5
			{ "번개", 10}, // 6
		};

		const int MAX_CONVERT_TABLE = 20;
		static const int CONVERT_TABLE[MAX_CONVERT_TABLE+1] =
		{
		//  0  1  2  3  4  5  6  7  8  9
			0, 0, 0, 0, 1, 1, 1, 1, 1, 2,
			2, 3, 3, 3, 3, 4, 4, 4, 4, 5,
			5
		};

		if (p_player == NULL)
			return;

		int mentality = p_enemy->mentality;

		if (mentality < 0)
			mentality = 0;

		if (mentality > MAX_CONVERT_TABLE)
			mentality = MAX_CONVERT_TABLE;

		const MagicTable& magic = MAGIC_TABLE[CONVERT_TABLE[mentality]];

		hadar::game::console::writeConsole(13, 6, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_player->getName(hadar::PcEnemy::JOSA_NONE), "에게 '", magic.sz_magic_name, "'마법을 사용했다");

		enemyCastAttackSpellSub(p_enemy, p_player, magic.damage * p_enemy->level);
	}

	void enemyCastCureSpell(PcEnemy* p_enemy, PcEnemy* p_target, int recovery)
	{
		if (p_enemy == p_target)
			hadar::game::console::writeConsole(13, 2, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " 자신을 치료했다");
		else
			hadar::game::console::writeConsole(13, 4, p_enemy->getName(hadar::PcEnemy::JOSA_SUB), " ", p_target->getName(hadar::PcEnemy::JOSA_OBJ), " 치료했다");

		if (p_target->dead > 0)
		{
			p_target->dead = 0;
		}
		else if (p_target->unconscious > 0)
		{
			p_target->unconscious = 0;
			if (p_target->hp <= 0)
				p_target->hp = 1;
		}
		else
		{
			p_target->hp += recovery;
			if (p_target->hp > p_target->endurance * p_target->level)
				p_target->hp = p_target->endurance * p_target->level;
		}
	}

	void enemyCastAttackSpellSub(PcEnemy* p_enemy, PcPlayer* p_player, int damage)
	{
		if (AvejUtil::random(20) >= p_enemy->accuracy[1])
		{
			hadar::game::console::writeConsole(7, 2, p_enemy->getName(hadar::PcEnemy::JOSA_NONE), "의 마법공격은 빗나갔다");
			return;
		}

		if (p_player->isConscious())
		if (AvejUtil::random(50) < p_player->resistance)
		{
			hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 적의 마법을 저지했다");
			return;
		}

		damage -= AvejUtil::random(damage / 2);

		if (p_player->isConscious())
			damage -= (p_player->ac * p_player->level[0] * (AvejUtil::random(10)+1) / 10);

		if (damage <= 0)
		{
			hadar::game::console::writeConsole(7, 3, "그러나, ", p_player->getName(hadar::PcEnemy::JOSA_SUB), " 적의 마법을 막아냈다");
			return;
		}

		if (p_player->dead > 0)
			p_player->dead += damage;

		if ((p_player->unconscious > 0) && (p_player->dead == 0))
			p_player->unconscious += damage;

		if (p_player->hp > 0)
			p_player->hp -= damage;

		hadar::game::console::writeConsole(5, 4, p_player->getName(hadar::PcEnemy::JOSA_SUB), " @D", IntToStr(damage)(), "@@만큼의 피해를 입었다");
	}

}

////////////////////////////////////////////////////////////////////////////////
// global function

const hadar::EnemyData& hadar::getEnemyDataFromEnemyTable(int index)
{
	static bool s_is_first = true;
	static hadar::EnemyData s_enemy_data[75] =
	{	// _name                 str men end res agi accuracy   ac spe clv scl  lv
		{"Orc",                   8,  0,  8,  0,  8,{  8,  0},  1,  0,  0,  0,  1},
		{"Troll",                 9,  0,  6,  0,  9,{  9,  0},  1,  0,  0,  0,  1},
		{"Serpent",               7,  3,  7,  0, 11,{ 11,  6},  1,  1,  1,  0,  1},
		{"Earth Worm",            3,  5,  5,  0,  6,{ 11,  7},  1,  0,  1,  0,  1},
		{"Dwarf",                10,  0, 10,  0, 10,{ 10,  0},  2,  0,  0,  0,  2},
		{"Giant",                15,  0, 13,  0,  8,{  8,  0},  2,  0,  0,  0,  2},
		{"Phantom",               0, 12, 12,  0,  0,{  0, 13},  0,  0,  2,  0,  2},
		{"Wolf",                  7,  0, 11,  0, 15,{ 15,  0},  1,  0,  0,  0,  2},
		{"Imp",                   8,  8, 10, 20, 18,{ 18, 10},  2,  0,  2,  0,  3},
		{"Goblin",               11,  0, 13,  0, 13,{ 13,  0},  3,  0,  0,  0,  3},
		{"Python",                9,  5, 10,  0, 13,{ 13,  6},  1,  1,  1,  0,  3},
		{"Insects",               6,  4,  8,  0, 14,{ 14, 15},  2,  1,  1,  0,  3},
		{"Giant Spider",         10,  0,  9,  0, 20,{ 13,  0},  2,  1,  0,  0,  4},
		{"Gremlin",              10,  0, 10,  0, 20,{ 20,  0},  2,  0,  0,  0,  4},
		{"Buzz Bug",             13,  0, 11,  0, 15,{ 15,  0},  1,  1,  0,  0,  4},
		{"Salamander",           12,  2, 13,  0, 12,{ 12, 10},  3,  1,  1,  0,  4},
		{"Blood Bat",            11,  0, 10,  0,  5,{ 15,  0},  1,  0,  0,  0,  5},
		{"Giant Rat",            13,  0, 18,  0, 10,{ 10,  0},  2,  0,  0,  0,  5},
		{"Skeleton",             10,  0, 19,  0, 12,{ 12,  0},  3,  0,  0,  0,  5},
		{"Kelpie",                8, 13,  8,  0, 14,{ 15, 17},  2,  0,  3,  0,  5},
		{"Gazer",                15,  8, 11,  0, 20,{ 15, 15},  3,  0,  2,  0,  6},
		{"Ghost",                 0, 15, 10,  0,  0,{  0, 15},  0,  0,  3,  0,  6},
		{"Slime",                 5, 13,  5,  0, 19,{ 19, 19},  2,  0,  2,  0,  6},
		{"Rock-Man",             19,  0, 15,  0, 10,{ 10,  0},  5,  0,  0,  0,  6},
		{"Kobold",                9,  9,  9,  0,  9,{  9,  9},  2,  0,  3,  0,  7},
		{"Mummy",                10, 10, 10,  0, 10,{ 10, 10},  3,  1,  2,  0,  7},
		{"Devil Hunter",         13, 10, 10,  0, 10,{ 10, 18},  3,  2,  2,  0,  7},
		{"Crazy One",             9,  9, 10,  0,  5,{  5, 13},  1,  0,  3,  0,  7},
		{"Ogre",                 19,  0, 19,  0,  9,{ 12,  0},  4,  0,  0,  0,  8},
		{"Headless",             10,  0, 15,  0, 10,{ 10,  0},  3,  2,  0,  0,  8},
		{"Mud-Man",              10,  0, 15,  0, 10,{ 10,  0},  7,  0,  0,  0,  8},
		{"Hell Cat",             10, 15, 11,  0, 18,{ 18, 16},  2,  2,  3,  0,  8},
		{"Wisp",                  5, 16, 10,  0, 20,{ 20, 20},  2,  0,  4,  0,  9},
		{"Basilisk",             10, 15, 12,  0, 20,{ 20, 10},  2,  1,  2,  0,  9},
		{"Sprite",                0, 20,  2, 80, 20,{ 20, 20},  0,  3,  5,  0,  9},
		{"Vampire",              15, 13, 14, 20, 17,{ 17, 15},  3,  1,  2,  0,  9},
		{"Molten Monster",        8,  0, 20, 50,  8,{ 16,  0},  3,  0,  0,  0, 10},
		{"Great Lich",           10, 10, 11, 10, 18,{ 10, 10},  4,  2,  3,  0, 10},
		{"Rampager",             20,  0, 19,  0, 19,{ 19,  0},  3,  0,  0,  0, 10},
		{"Mutant",                0, 10, 15,  0,  0,{  0, 20},  3,  0,  3,  0, 10},
		{"Rotten Corpse",        15, 15, 15, 60, 15,{ 15, 15},  2,  2,  3,  0, 11},
		{"Gagoyle",              10,  0, 20, 10, 10,{ 10,  0},  6,  0,  0,  0, 11},
		{"Wivern",               10, 10,  9, 30, 20,{ 20,  9},  3,  2,  3,  0, 11},
		{"Grim Death",           16, 16, 16, 50, 16,{ 16, 16},  2,  2,  3,  0, 12},
		{"Griffin",              15, 15, 15,  0, 15,{ 14, 14},  3,  2,  3,  0, 12},
		{"Evil Soul",             0, 20, 10,  0,  0,{  0, 15},  0,  3,  4,  0, 12},
		{"Cyclops",              20,  0, 20, 10, 20,{ 20,  0},  4,  0,  0,  0, 13},
		{"Dancing-Swd",          15, 20,  6, 20, 20,{ 20, 20},  0,  2,  4,  0, 13},
		{"Hydra",                15, 10, 20, 40, 18,{ 18, 12},  8,  1,  3,  0, 13},
		{"Stheno",               20, 20, 20,255, 10,{ 10, 10},255,  1,  3,  0, 14},
		{"Euryale",              20, 20, 15,255, 10,{ 15, 10},255,  2,  3,  0, 14},
		{"Medusa",               15, 10, 16, 50, 15,{ 15, 10},  4,  3,  3,  0, 14},
		{"Minotaur",             15,  7, 20, 40, 20,{ 20, 15}, 10,  0,  3,  0, 15},
		{"Dragon",               15,  7, 20, 50, 18,{ 20, 15},  9,  2,  4,  0, 15},
		{"Dark Soul",             0, 20, 40, 60,  0,{  0, 20},  0,  0,  5,  0, 15},
		{"Hell Fire",            15, 20, 30, 30, 15,{ 15, 15},  0,  3,  5,  0, 16},
		{"Astral Mud",           13, 20, 25, 40, 19,{ 19, 10},  9,  3,  4,  0, 16},
		{"Reaper",               15, 20, 33, 70, 20,{ 20, 20},  5,  1,  3,  0, 17},
		{"Crab God",             20, 20, 30, 20, 18,{ 18, 19},  7,  2,  4,  0, 17},
		{"Wraith",                0, 24, 35, 50, 15,{  0, 20},  2,  3,  4,  0, 18},
		{"Death Skull",           0, 20, 40, 80,  0,{  0, 20},  0,  2,  5,  0, 18},
		{"Draconian",            30, 20, 30, 60, 18,{ 18, 18},  7,  2,  5,  1, 19},
		{"Death Knight",         35,  0, 35, 50, 20,{ 20,  0},  6,  3,  0,  1, 19},
		{"Guardian-Lft",         25,  0, 40, 70, 20,{ 18,  0},  5,  2,  0,  0, 20},
		{"Guardian-Rgt",         25,  0, 40, 40, 20,{ 20,  0},  7,  2,  0,  0, 20},
		{"Mega-Robo",            40,  0, 50,  0, 19,{ 19,  0}, 10,  0,  0,  0, 21},
		{"Ancient Evil",          0, 20, 60,100, 18,{  0, 20},  5,  0,  6,  2, 22},
		{"Lord Ahn",             40, 20, 60,100, 35,{ 20, 20}, 10,  3,  5,  3, 23},
		{"Frost Dragon",         15,  7, 20, 50, 18,{ 20, 15},  9,  2,  4,  0, 24},
		{"ArchiDraconian",       30, 20, 30, 60, 18,{ 18, 18},  7,  2,  5,  1, 25},
		{"Panzer Viper",         35,  0, 40, 80, 20,{ 20,  0},  9,  1,  0,  0, 26},
		{"Black Knight",         35,  0, 35, 50, 20,{ 20,  0},  6,  3,  0,  1, 27},
		{"ArchiMonk",            20,  0, 50, 70, 20,{ 20,  0},  5,  0,  0,  0, 28},
		{"ArchiMage",            10, 19, 30, 70, 10,{ 10, 19},  4,  0,  6,  0, 29},
		{"Neo-Necromancer",      40, 20, 60,100, 30,{ 20, 20}, 10,  3,  6,  3, 30}
	};

	CT_ASSERT(sizeof(s_enemy_data[0]) == 32, TEnemyData_size_is_changed);

	if (s_is_first)
	{
		// 실행 디렉토리에 foedata0.dat 파일이 있는 경우는 그 파일을 이용하고,
		// 그렇지 않을 경우에는 빌드시 미리 지정된 디폴트 데이터를 사용한다.
		FILE* p_file = fopen("./foedata0.dat", "rb");
		if (p_file)
		{
			for (int i = 0; i < sizeof(s_enemy_data) / sizeof(s_enemy_data[0]); i++)
			{
				int read = fread(&s_enemy_data[i], sizeof(EnemyData), 1, p_file);

				assert(read == 1);

				if (read != 1)
					break;

				// pascal형 string을 C형 string으로 변환
				{
					unsigned char strLength = (unsigned char)s_enemy_data[i]._name[0];
					memcpy(&s_enemy_data[i]._name[0], &s_enemy_data[i]._name[1], strLength);
					s_enemy_data[i]._name[strLength] = 0;
				}
			}

			fclose(p_file);

#if 0 // 데이터 저장에 사용된 code
			{
				FILE* p_file = fopen("./foedata0.cpp", "wt");
				if (p_file)
				{
					int num_enemy = sizeof(s_enemy_data) / sizeof(s_enemy_data[0]);

					fprintf(p_file, "static EnemyData s_enemy_data[%d] =\n", num_enemy);
					fprintf(p_file, "{\t// _name                 str men end res agi accuracy   ac spe clv scl  lv\n");
	
					for (int i = 0; i < num_enemy; i++)
					{
						const EnemyData& data = s_enemy_data[i];
						fprintf(p_file, "\t{");
						fprintf(p_file, "\"%s\",", data._name);
						for (int j = 0; j < sizeof(data._name)-strlen(data._name); j++)
							fprintf(p_file, " ");
						fprintf(p_file, "%3d,", data.strength);
						fprintf(p_file, "%3d,", data.mentality);
						fprintf(p_file, "%3d,", data.endurance);
						fprintf(p_file, "%3d,", data.resistance);
						fprintf(p_file, "%3d,", data.agility);
						fprintf(p_file, "{%3d,%3d},", data.accuracy[0], data.accuracy[1]);
						fprintf(p_file, "%3d,", data.ac);
						fprintf(p_file, "%3d,", data.special);
						fprintf(p_file, "%3d,", data.cast_level);
						fprintf(p_file, "%3d,", data.special_cast_level);
						fprintf(p_file, "%3d},\n", data.level);
					}

					fprintf(p_file, "};\n");

					fclose(p_file);
				}
			}
#endif
		}
		else
		{
			// 디폴트 데이터를 사용
		}

		s_is_first = false;
	}

	// 1-base를 0-base로
	--index;

	if ((index < 0) || (index >= sizeof(s_enemy_data) / sizeof(s_enemy_data[0])))
		index = 0;

	return s_enemy_data[index];
}
