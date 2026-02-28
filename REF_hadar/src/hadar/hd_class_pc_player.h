
#ifndef __HD_CLASS_PC_PLAYER_H__
#define __HD_CLASS_PC_PLAYER_H__

#pragma warning(disable: 4786)

#include "hd_class_pc_name_base.h"
#include "hd_class_serialized.h"

namespace hadar
{
	struct EnemyData;
	struct PcEnemy;

	/*!
	 * \file
	 * \ingroup game main
	 * \brief 게임에 사용되는 player 캐릭터의 class
	 * \author SMgal smgal@hitel.net
	 * \date 2006-12-31
	*/
	struct PcPlayer: public PcNameBase
	{
		enum GENDER
		{
			GENDER_MALE,
			GENDER_FEMALE,
			GENDER_MAX = 0x7FFFFFFF
		};

		union
		{
			struct
			{
				int   order;
				GENDER gender;
				int   class_;

				int   strength;
				int   mentality;
				int   concentration;
				int   endurance;
				int   resistance;
				int   agility;
				int   luck;

				int   ac;

				int   hp;
				int   sp;
				int   esp;
				int   experience;
				int   accuracy[3];
				int   level[3];

				int   poison;
				int   unconscious;
				int   dead;

				int   weapon;
				int   shield;
				int   armor;

				int   pow_of_weapon;
				int   pow_of_shield;
				int   pow_of_armor;
			};

			char save[30 * sizeof(int)];
		};

	public:
		PcPlayer(void);
		~PcPlayer(void);

		//! 속성 값을 kind에 맞는 디폴트 값로 채움
		void setDefault(int kind);
		//! 현재의 상태를 점검하고 이상이 있는 경우는 보정
		void checkCondition(void);

		//! 현재의 상태를 나타내는 문자열을 돌려줌
		const char* getConditionString(void) const;
		//! 현재의 상태를 32-bit 컬러 값으로 돌려줌
		unsigned long getConditionColor(void) const;
		//! 3인칭 대명사를 돌려줌
		const char* get3rdPersonName(void) const;
		//! 성별을 나타내는 문자열을 돌려줌
		const char* getGenderName(void) const;
		//! class를 나타내는 문자열을 돌려줌
		const char* getClassName(void) const;
		//! 현재의 무기를 나타내는 문자열을 돌려줌
		const char* getWeaponName(void) const;
		//! 현재의 방패를 나타내는 문자열을 돌려줌
		const char* getShieldName(void) const;
		//! 현재의 갑옷을 나타내는 문자열을 돌려줌
		const char* getArmorName(void) const;

		//! 문자열을 통해 현재의 속성을 변경
		bool changeAttribute(const char* sz_attribute, int value);
		bool changeAttribute(const char* sz_attribute, const char* sz_data);
		bool getAttribute(const char* sz_attribute, int& value);
		bool getAttribute(const char* sz_attribute, avej::string& data);

		//! 조합되는 속성(hp등)이 가능한 값 범위에 있는지를 확인하고, 문제가 있으면 보정한다.
		void reviseAttribute(void);
		//! 수정한 속성값에 맞는 hp값으로 보정한다.
		void applyAttribute(void);

		//! 의식이 있는 상태인지 아닌지를 판별
		bool isConscious(void) const
		{
			return this->isValid() && (unconscious == 0) && (dead == 0) && (hp > 0);
		}

		//! 적 데이터로부터 player를 생성
		void operator<<(const struct EnemyData& data);

		/*
		runBattleMode -+-> attackWithWeapon -------,
					|                           |
					+-> castSpellToAll          |
					|      |                    |
					+------+-> castSpellToOne --+
					|                           |
					+-> useESPForBattle --------+-> m_plusExperience
					|
					+-> castCureSpell -+-> m_healAll
					|              |        |
					|              +--------+-> m_healOne
					|              |
					|              +-> m_antidoteAll
					|              |        |
					|              +--------+-> m_antidoteOne
					|              |
					|              +-> m_recoverConsciousnessAll
					|              |        |
					|              +--------+-> m_recoverConsciousnessOne
					|              |
					|              +-> m_revitalizeAll
					|              |        |
					|              `--------+-> m_revitalizeOne
					|
					+-> castSpellWithSpecialAbility
					|
					`-> tryToRunAway
		*/

		//! 공격 마법 사용
		void castAttackSpell(void);
		//! 치료 마법 사용
		void castCureSpell(void);
		//! 변화 마법 사용
		void castPhenominaSpell(void);

		//! 무리를 이용한 공격
		void attackWithWeapon(int ix_object, int ix_enemy);
		//! 적 전체에 대한 마법 공격
		void castSpellToAll(int ix_object);
		//! 적 하나에 대한 마법 공격
		void castSpellToOne(int ix_object, int ix_enemy);
		//! 평상용 esp 사용
		void useESP(void);
		//! 전투용 esp 사용
		void useESPForBattle(int ix_object, int ix_enemy);
		//! 특수 마법 공격을 사용
		void castSpellWithSpecialAbility(int ix_object, int ix_enemy);
		//! 도망을 시도
		bool tryToRunAway(void);

	private:
		//! 한 명을 치료
		void m_healOne(PcPlayer* p_target);
		//! 한 명을 해독
		void m_antidoteOne(PcPlayer* p_target);
		//! 한 명의 의식을 돌림
		void m_recoverConsciousnessOne(PcPlayer* p_target);
		//! 한 명의 부활 시킴
		void m_revitalizeOne(PcPlayer* p_target);
		//! 모두를 치료
		void m_healAll(void);
		//! 모두를 해독
		void m_antidoteAll(void);
		//! 모두를 의식을 돌림
		void m_recoverConsciousnessAll(void);
		//! 모두를 부활 시킴
		void m_revitalizeAll(void);
		//! 특수 마법의 사용 가능한지 확인
		bool m_canUseSpecialMagic(void);
		//! ESP 사용 가능한지 확인
		bool m_canUseESP(void);
		//! 물리친 적에 대해 경험치를 추가
		void m_plusExperience(PcEnemy* p_enemy);
		//! Spell point가 부족하다는 메시지 출력
		void m_printSpNotEnough(void);
		//! ESP point가 부족하다는 메시지 출력
		void m_printESPNotEnough(void);

	protected:
		bool _load(const ReadStream& stream);
		bool _save(const WriteStream& stream) const;
	};

	avej::string getBattleMessage(const PcPlayer& who, int how, int what, const PcEnemy& whom);

} // namespace hadar

#endif // #ifndef __HD_CLASS_PC_PLAYER_H__
