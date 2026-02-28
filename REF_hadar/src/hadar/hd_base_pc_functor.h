
#ifndef __HD_BASE_PC_FUNCTOR_H__
#define __HD_BASE_PC_FUNCTOR_H__

// functor
namespace
{
	// window의 갱신
	template <class type>
	class FnDisplay
	{
	public:
		void operator()(type obj)
		{
			obj->display();
		}
	};

	// 아군의 상태 점검
	template <class type>
	class FnCheckCondition
	{
	public:
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				obj->checkCondition();
			}
		}
	};

	// 의식이 남아 있는 player의 수
	template <class type>
	class FnNumOfConscious
	{
		int num_alive;

	public:
		FnNumOfConscious(void)
			: num_alive(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isConscious())
				++num_alive;
		}
		int Result(void)
		{
			// 살아 있는 player의 수
			return num_alive;
		}
	};

	// 파티가 swamp로 이동했을 때 적용되는 규칙
	template <class type>
	class FnEnterSwamp
	{
		int num_updated;

	public:
		FnEnterSwamp(void)
			: num_updated(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				if (AvejUtil::random(20) + 1 >= obj->luck)
				{
					hadar::game::console::writeConsole(13, 2, obj->getName(hadar::PcNameBase::JOSA_SUB), " 중독되었다.");

					if (obj->poison == 0)
						obj->poison = 1;

					++num_updated;
				}
			}
		}
		int Result(void)
		{
			// 데이터가 갱신된 player의 수
			return num_updated;
		}
	};

	// 파티가 lava로 이동했을 때 적용되는 규칙
	template <class type>
	class FnEnterLava
	{
		int num_updated;

	public:
		FnEnterLava(void)
			: num_updated(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				int damage = AvejUtil::random(40) + 40;

				if (obj->luck > 0)
					damage -= (2 * AvejUtil::random(obj->luck));

				if (damage > 0)
				{
					hadar::game::console::writeConsole(13, 4, obj->getName(hadar::PcNameBase::JOSA_SUB), " ", avej::IntToStr(damage)(), "의 피해를 입었다 !");

					if ((obj->hp > 0) && (obj->unconscious == 0))
					{
						obj->hp -= damage;
						if (obj->hp <= 0)
							obj->unconscious = 1;
					}
					else if ((obj->hp > 0) && (obj->unconscious > 0))
					{
						obj->hp -= damage;
					}
					else if ((obj->unconscious > 0) && (obj->dead == 0))
					{
						obj->unconscious += damage;
						if (obj->unconscious > obj->endurance * obj->level[0])
							obj->dead = 1;
					}
					else if (obj->dead > 0)
					{
						if (obj->dead + damage > 30000)
							obj->dead = 30000;
						else
							obj->dead += damage;
					}

					++num_updated;
				}
			}
		}
		int Result(void)
		{
			// 데이터가 갱신된 player의 수
			return num_updated;
		}
	};

	// 시간이 가거나 파티가 이동했을 때 적용되는 규칙
	template <class type>
	class FnTimeGoes
	{
		int num_updated;

	public:
		FnTimeGoes(void)
			: num_updated(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				if (obj->poison > 0)
					++obj->poison;

				if (obj->poison > 10)
				{
					obj->poison = 1;
					if ((obj->dead > 0) && (obj->dead < 100))
					{
						++obj->dead;
					}
					else if (obj->unconscious > 0)
					{
						++obj->unconscious;
						if (obj->unconscious > obj->endurance * obj->level[0])
							obj->dead = 1;
					}
					else
					{
						--obj->hp;
						if (obj->hp <= 0)
							obj->unconscious = 1;
					}
					++num_updated;
				}
			}
		}
		int Result(void)
		{
			// 데이터가 갱신된 player의 수
			return num_updated;
		}
	};

	// 파티가 캠프를 할 때 적용되는 규칙
	template <class type>
	class FnRestHere
	{
	public:
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				if (hadar::s_p_game_main->party.food <= 0)
				{
					hadar::game::console::writeConsole(4, 1, "일행은 식량이 바닥났다");
				}
				else if (obj->dead > 0)
				{
					hadar::game::console::writeConsole(7, 2, obj->getName(hadar::PcNameBase::JOSA_SUB), " 죽었다");
				}
				else if ((obj->unconscious > 0) && (obj->poison == 0))
				{
					obj->unconscious -= (obj->level[0] + obj->level[1] + obj->level[2]);
					if (obj->unconscious <= 0)
					{
						hadar::game::console::writeConsole(15, 2, obj->getName(hadar::PcNameBase::JOSA_SUB), " 의식이 회복되었다");

						obj->unconscious = 0;
						if (obj->hp <= 0)
							obj->hp = 1;

						--hadar::s_p_game_main->party.food;
					}
					else
					{
						hadar::game::console::writeConsole(15, 2, obj->getName(hadar::PcNameBase::JOSA_SUB), " 여전히 의식 불명이다");
					}
				}
				else if ((obj->unconscious > 0) && (obj->poison > 0))
				{
					hadar::game::console::writeConsole(7, 3, "독 때문에 ", obj->getName(hadar::PcNameBase::JOSA_NONE), "의 의식은 회복되지 않았다");
				}
				else if (obj->poison > 0)
				{
					hadar::game::console::writeConsole(7, 3, "독 때문에 ", obj->getName(hadar::PcNameBase::JOSA_NONE), "의 건강은 회복되지 않았다");
				}
				else
				{
					int i = (obj->level[0] + obj->level[1] + obj->level[2]) * 2;
					if (obj->hp >= obj->endurance * obj->level[0])
					{
						if (hadar::s_p_game_main->party.food < 255)
							++hadar::s_p_game_main->party.food;
					}

					obj->hp += i;
					if (obj->hp >= obj->endurance * obj->level[0])
					{
						obj->hp = obj->endurance * obj->level[0];
						hadar::game::console::writeConsole(15, 2, obj->getName(hadar::PcNameBase::JOSA_SUB), " 모든 건강이 회복되었다");
					}
					else
					{
						hadar::game::console::writeConsole(15, 2, obj->getName(hadar::PcNameBase::JOSA_SUB), " 치료되었다");
					}
					--hadar::s_p_game_main->party.food;
				}

				obj->sp  = obj->mentality * obj->level[1];
				obj->esp = obj->concentration * obj->level[2];
			}
		}
	};

	// 캐릭터 리스트의 평균 행운을 돌려주는 함수자  
	template <class type>
	class FnAverageLuck
	{
		int accum_luck;
		int num_player;

	public:
		FnAverageLuck(void)
			: accum_luck(0)
			, num_player(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				++num_player;
				accum_luck += obj->luck;
			}
		}
		int Result(void)
		{
			return (num_player > 0) ? (accum_luck / num_player) : 0;
		}
	};

	// 캐릭터 리스트의 평균 민첩성을 돌려주는 함수자  
	template <class type>
	class FnAverageAgility
	{
		int accum_agility;
		int num_player;

	public:
		FnAverageAgility(void)
			: accum_agility(0)
			, num_player(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				++num_player;
				accum_agility += obj->agility;
			}
		}
		int Result(void)
		{
			return (num_player > 0) ? (accum_agility / num_player) : 0;
		}
	};

	// 캐릭터 리스트의 평균 AC를 돌려주는 함수자  
	template <class type>
	class FnAverageAC
	{
		int accum_AC;
		int num_player;

	public:
		FnAverageAC(void)
			: accum_AC(0)
			, num_player(0)
		{
		}
		void operator()(type obj)
		{
			if (obj->isValid())
			{
				++num_player;
				accum_AC += obj->ac;
			}
		}
		int Result(void)
		{
			return (num_player > 0) ? (accum_AC / num_player) : 0;
		}
	};

	// 적들이 제공할 수 있는 황금의 개수를 계산하는 함수자
	template <class type>
	class FnPlusGold
	{
		int num_gold;
	public:
		FnPlusGold(void)
			: num_gold(0)
		{
		}
		void operator()(type obj)
		{
			const hadar::EnemyData& enemy_data = hadar::getEnemyDataFromEnemyTable(obj->ed_number);

			int ac = enemy_data.ac;

			if (ac < 0)
				ac = 1;

			int level = enemy_data.level;

			num_gold += level * level * level * ac;
		}
		int Result(void)
		{
			return num_gold;
		}
	};
}

#endif // #ifndef __HD_BASE_PC_FUNCTOR_H__
