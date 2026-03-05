
using UnityEngine;

using System;
using System.IO;
using System.Collections;

namespace Yunjr
{
	public class PlayerParams
	{
		public CLASS clazz = CLASS.UNKNOWN;
		public GENDER gender = GENDER.UNKNOWN;
		public string name = "";

		// STR, INT, END, CON, AGI, RES, DEX, LUC, LEV
		public int[] status = new int[(int)STATUS.MAX];
		public int[] skills = new int[(int)SKILL_TYPE.MAX];

		public PlayerParams()
		{
		}

		public PlayerParams(string _name, GENDER _gender, CLASS _clazz, int level)
		{
			this.name = _name;
			this.gender = _gender;
			this.clazz = _clazz;

			for (int ix_status = 0; ix_status < (int)STATUS.MAX; ix_status++)
				this.status[ix_status] = ObjPlayer.GetMinValueOfStatus(_clazz, (STATUS)ix_status);

			this.status[(int)STATUS.LEV] = (level > 0) ? level : 1;

			for (int ix_skill = 0; ix_skill < (int)SKILL_TYPE.MAX; ix_skill++)
				this.skills[ix_skill] = ObjPlayer.GetMinValueOfSkill(_clazz, (SKILL_TYPE)ix_skill);
		}
	}

	[Serializable]
	public class Equiped: ISerialize
	{
		public ObjNameBase name = new ObjNameBase();
		public Item item = new Item();
		public ItemSub added = ItemSub.GetDefault();
		public int[] added_status = new int[(int)STATUS.MAX];

		public bool IsValid()
		{
			return (this.name.GetName() != "");
		}

		public static Equiped Create(Item item)
		{
			Equiped equip = new Equiped();

			equip.item = item;
			equip.added = ItemSub.GetDefault();
			equip.added.item_type = equip.item.param.item_type;
			equip.name.SetName(equip.item.name);

			// equip.item.annex --> equip.status_correction
			ObjItem.ConvertToAnnex(equip.item.annex, ref equip.added.atta_pow, ref equip.added.ac, ref equip.added_status);

			return equip;
		}

		public static Equiped Create(ResId res_id)
		{
			uint id = res_id.GetId();

			if (!GameRes.item_table.ContainsKey(id))
			{
				Debug.LogError(String.Format("Resource Id(0x{0,-8:X8}) not found", id));
				return new Equiped();
			}

			return Create(GameRes.item_table[id]);
		}

		public override void _Load(Stream stream)
		{
			Debug.Assert(added_status.Length == 9);

			this.name._Load(stream);
			_Read(stream, out this.item);
			_Read(stream, out this.added);

			for (int i = 0; i < this.added_status.Length; i++)
				_Read(stream, out this.added_status[i]);

		}

		public override void _Save(Stream stream)
		{
			this.name._Save(stream);
			_Write(stream, this.item);
			_Write(stream, this.added);

			for (int i = 0; i < this.added_status.Length; i++)
				_Write(stream, ref this.added_status[i]);
		}
	}

	[Serializable]
	public class ObjPlayer: ObjNameBase
	{
		public GENDER gender;
		public CLASS  clazz;
		public RACE race;
		public PLAYER_TITLE title;

		/* 경험치 운용 방법
		 * 
		 * 경험치는 역대 누적 경험치(1) 과 비정산 경험치(2) 가 있다.
		 * 일반적으로 경험치를 얻게 되면 (2)에 증가가 된다.
		 * 원작에서는 (2)가 실제 상태 출력시 사용되는 경험치이다.
		 * 
		 * 훈련소 등에서는 (2)에 쌓인 값을 스킬로 바꾸게 되는데,
		 * 스킬로 증가시킨 값만큼 (2)는 감소하고, 감소된 만큼 (1)에 누적된다.
		 * 
		 * 레벨이 올라가는 유일한 방법은 RestHere()이다.
		 * 여기서 (1)의 값을 체크하게 되는데, (1)이 다음 레벨 요구치보다 같거나 크다면
		 * 실질적인 레벨업이 발생하게 된다.
		 * 
		 * (1)누적 경험치는 'accumulated_exprience'
		 * (2)비정산 경험치는 'exprience'
		 */
		public long exprience;
		public long accumulated_exprience;

		public uint specially_allowed_magic;
		// TODO: 적용해야 함
		public uint specially_allowed_esp;

		public uint reserved_1;
		public uint reserved_2;
		public uint reserved_3;

		public int hp;
		public int sp;
		public int poison;
		public int unconscious;
		public int dead;

		public uint reserved_4;
		public uint reserved_5;

		public int[] intrinsic_status = new int[(int)STATUS.MAX];
		public int[] intrinsic_skill = new int[(int)SKILL_TYPE.MAX];

		public Equiped[] equip = new Equiped[(int)EQUIP.MAX];

		// 아래의 것들은 Apply()에 의해서 결정된다.
		public int atta_pow;
		public int ac;
		public int[] status = new int[(int)STATUS.MAX];
		public int[] skill = new int[(int)SKILL_TYPE.MAX];

		public string Name
		{
			get { return this._name; }
			set { this.SetName(value); }
		}

		public override void _Load(Stream stream)
		{
			base._Load(stream);

			gender = (GENDER)_GetEnumAsInt(stream);
			clazz = (CLASS)_GetEnumAsInt(stream);
			race = (RACE)_GetEnumAsInt(stream);
			title = (PLAYER_TITLE)_GetEnumAsInt(stream);

			_Read(stream, out exprience);
			_Read(stream, out accumulated_exprience);

			_Read(stream, out specially_allowed_magic);
			_Read(stream, out specially_allowed_esp);

			_Read(stream, out reserved_1);
			_Read(stream, out reserved_2);
			_Read(stream, out reserved_3);

			_Read(stream, out hp);
			_Read(stream, out sp);
			_Read(stream, out poison);
			_Read(stream, out unconscious);
			_Read(stream, out dead);

			_Read(stream, out reserved_4);
			_Read(stream, out reserved_5);

			for (int i = 0; i < (int)STATUS.MAX; i++)
				_Read(stream, out intrinsic_status[i]);

			for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
				_Read(stream, out intrinsic_skill[i]);

			for (int i = 0; i < (int)EQUIP.MAX; i++)
			{
				bool exist;
				_Read(stream, out exist);

				equip[i] = null;
				if (exist)
				{
					equip[i] = new Equiped();
					equip[i]._Load(stream);
				}
			}

			_Read(stream, out atta_pow);
			_Read(stream, out ac);

			for (int i = 0; i < (int)STATUS.MAX; i++)
				_Read(stream, out status[i]);

			for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
				_Read(stream, out skill[i]);
		}

		public override void _Save(Stream stream)
		{
			base._Save(stream);

			_WriteEnum(stream, (int)gender);
			_WriteEnum(stream, (int)clazz);
			_WriteEnum(stream, (int)race);
			_WriteEnum(stream, (int)title);

			_Write(stream, ref exprience);
			_Write(stream, ref accumulated_exprience);

			_Write(stream, ref specially_allowed_magic);
			_Write(stream, ref specially_allowed_esp);

			_Write(stream, ref reserved_1);
			_Write(stream, ref reserved_2);
			_Write(stream, ref reserved_3);

			_Write(stream, ref hp);
			_Write(stream, ref sp);
			_Write(stream, ref poison);
			_Write(stream, ref unconscious);
			_Write(stream, ref dead);

			_Write(stream, ref reserved_4);
			_Write(stream, ref reserved_5);

			for (int i = 0; i < (int)STATUS.MAX; i++)
				_Write(stream, ref intrinsic_status[i]);

			for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
				_Write(stream, ref intrinsic_skill[i]);

			for (int i = 0; i < (int)EQUIP.MAX; i++)
			{
				if (equip[i] != null && equip[i].IsValid())
				{
					_Write(stream, true);
					equip[i]._Save(stream);
				}
				else
				{
					_Write(stream, false);
				}

			}

			_Write(stream, ref atta_pow);
			_Write(stream, ref ac);

			for (int i = 0; i < (int)STATUS.MAX; i++)
				_Write(stream, ref status[i]);

			for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
				_Write(stream, ref skill[i]);
		}

		public ObjPlayer()
		{
			gender = GENDER.UNKNOWN;
			clazz = CLASS.UNKNOWN;
			race = RACE.HUMAN;
			title = PLAYER_TITLE.NONE;
			exprience = 0;
			accumulated_exprience = 0;
			hp = 1;
			sp = 1;
			poison = 0;
			unconscious = 0;
			dead = 0;

			for (int i = 0; i < (int)STATUS.MAX; i++)
				intrinsic_status[i] = 10;

			for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
				intrinsic_skill[i] = 0;

			for (int i = 0; i < (int)EQUIP.MAX; i++)
				equip[i] = new Equiped();

			this.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 0));
			this.SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(0));

			Apply();
		}

		public bool IsAvailable()
		{
			return (this.IsValid() && this.dead == 0 && this.unconscious == 0 && this.hp > 0);
		}

		public void Apply()
		{
			double sum_ap = 0.0;
			double sum_ac = 0.0;
			int[] sum_status = new int[(int)STATUS.MAX];

			for (int i = 0; i < (int)EQUIP.MAX; i++)
			{
				if (equip[i] != null && equip[i].IsValid())
				{
					sum_ap += equip[i].item.param.atta_pow + equip[i].added.atta_pow;
					sum_ac += equip[i].item.param.ac + equip[i].added.ac;
					for (int ix_status = 0; ix_status < (int)STATUS.MAX; ix_status++)
						sum_status[ix_status] += equip[i].added_status[ix_status];
				}
			}

			// TODO: 나중에 제대로 테스트 해봐야 함
			/*
			if (sum_ap != equip[0].item.param.atta_pow)
			{
				Debug.LogFormat("[TEST] #1 {0} -> {1}", equip[0].item.param.atta_pow, sum_ap);
			}

			if (sum_ac != equip[0].item.param.ac)
			{
				Debug.LogFormat("[TEST] #2 {0} -> {1}", equip[0].item.param.ac, sum_ac);
			}
			*/

			//////////

			for (int i = 0; i < (int)STATUS.MAX; i++)
				status[i] = intrinsic_status[i] + sum_status[i];

			for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
				skill[i] = intrinsic_skill[i];

			atta_pow = (int)sum_ap;
			ac = (int)sum_ac;
		}

		public bool StateUpdates()
		{
			bool state_changed = false;

			if (this.hp <= 0 && this.unconscious == 0)
			{
				this.unconscious = 1;
				state_changed = true;
			}
			else if (this.unconscious > 0 && this.dead == 0)
			{
				if (this.unconscious > this.GetMaxHP())
				{
					this.dead = 1;
					state_changed = true;
				}
			}
			else if (this.dead > 0)
			{
				if (this.dead > 30000)
					this.dead = 30000;
			}

			return state_changed;
		}

		public ObjNameBase GetGenderName()
		{
			ObjNameBase pronoun_gender = new ObjNameBase();
			pronoun_gender.SetName((this.gender != GENDER.FEMALE) ? "그" : "그녀");
			return pronoun_gender;
		}

		public void SetEquipment(EQUIP part, Equiped equipment)
		{
			this.equip[(int)part] = equipment;
		}

		public void SetEquipment(EQUIP part, ResId res_id)
		{
			if ((int)part >= 0 && part < EQUIP.MAX)
			{
				/* << Equiped 구조 >>
				 * 
				 * 기본적으로는 원본 item에서 모든 속성을 가져 온다.
				 * 원본 item의 모든 속성을 item에 복사를 하고, 이름도 name에 따로 복사를 한다.
				 * (이름을 따로 복사하는 이유는, 고유 이름을 부여할 수 있도록 하기 위함이다.)
				 * 그리고 원본 item의 부가 속성은 equip.added의 atta_pow와 ac에 복사를 하여
				 * 원본 item 자체의 특수 부가 속성은 모두 added_status에 기록된다.
				 * 
				 * 따라서 Equiped 로 변환이 되고나면 원본 item 속성은 원상 복구를 위한 참고로만 쓰며
				 * 모든 속성은 Equiped 자체에 기록된 속성만 적용하여야 한다.
				 * 
				 * Equiped 는 장비에만 쓰여야 하며, 다시 Item으로 복구되는 기능은 없다.
				 */

				Equiped equip = Equiped.Create(res_id);

				if (equip.IsValid())
					this.equip[(int)part] = equip;
				else
					Debug.LogError(String.Format("Player.SetEquipment() failed: Cannot create an equipment based on (res Id: {0})", res_id.GetId()));
			}
		}

		public bool Damaged(int damage)
		{
			bool state_changed = false;

			if (this.dead > 0)
				this.dead += damage;

			if (this.unconscious > 0 && this.dead == 0)
				this.unconscious += damage;

			if (this.hp > 0)
				this.hp -= damage;

			return state_changed = this.StateUpdates();
		}

		public bool DamagedByPoison()
		{
			bool state_changed = false;

			if (this.dead > 0 && this.dead < 100)
			{
				this.dead++;
			}
			else if (this.unconscious > 0)
			{
				this.unconscious += 5;
				if (this.unconscious > this.GetMaxHP())
				{
					this.dead = 1;
					state_changed = true;
				}
			}
			else
			{
				this.hp--;
				if (this.hp <= 0)
				{
					this.unconscious = 1;
					state_changed = true;
				}
			}

			return state_changed;
		}

		public int GetPAP()
		{
			double pow = 1.0;

			if (equip[(int)EQUIP.HAND] != null)
			{
				pow = this.atta_pow;

				ITEM_TYPE weapon_type = equip[(int)EQUIP.HAND].added.item_type;
				if (weapon_type >= ITEM_TYPE.WEAPON_MIN && weapon_type <= ITEM_TYPE.SHOOT)
					pow *= (double)skill[(int)weapon_type - (int)ITEM_TYPE.WEAPON_MIN] / 10;
			}

			pow *= (double)status[(int)STATUS.STR] / 10;
			pow *= (double)status[(int)STATUS.DEX] / 10;

			// TODO2: GetPAP()에 원래는 STATUS.LEV이 없었지만 추가하였음. 밸런스 체크 필요
			// lev  1: x1.0
			// lev 11: x2.0
			// lev 21: x3.0
			pow *= (double)(status[(int)STATUS.LEV]+9) / 10;

			// TODO2: skill이 0일 경우를 피하기 위해
			pow = (pow > 1.0) ? pow : 1.0;
			
			return (int)(pow + 0.5);
		}

		public int GetAttackMagicPower(int magic_index)
		{
			if (magic_index >= 1 && magic_index <= 10)
			{
				int magic = magic_index;
				return this.skill[(int)SKILL_TYPE.DAMAGE] * magic * magic * 3;
			}
			else if (magic_index >= 11 && magic_index <= 20)
			{
				int magic = magic_index - 10;
				// 다중 공격은 데미지가 2/3
				return this.skill[(int)SKILL_TYPE.DAMAGE] * magic * magic * 2;
			}
			else
			{
				Debug.Assert(false);
				return 0;
			}
		}

		public int GetRequiredSP(int magic_index)
		{
			if (magic_index >= 1 && magic_index <= 10)
			{
				int magic = magic_index;
				return this.skill[(int)SKILL_TYPE.DAMAGE] * magic * magic / 10;
			}
			else if (magic_index >= 11 && magic_index <= 20)
			{
				int magic = magic_index - 10;
				// 다중 공격은 SP 소모가 2배
				return this.skill[(int)SKILL_TYPE.DAMAGE] * magic * magic / 5;
			}
			else
			{
				Debug.Assert(false);
				return 0;
			}
		}

		public int GetMaxHP()
		{
			// 5 is magic value, and this value can modify the game balance
			double hp = (double)status[(int)STATUS.END] * (double)status[(int)STATUS.LEV] * 5;

			switch (LibUtil.GetClassType(this.clazz))
			{
				case CLASS_TYPE.PHYSICAL_FORCE:
					break;
				case CLASS_TYPE.HYBRID1:
				case CLASS_TYPE.HYBRID2:
				case CLASS_TYPE.HYBRID3:
					hp *= 0.8;
					break;
				case CLASS_TYPE.MAGIC_USER:
					hp *= 0.5;
					break;
			}

			return (int)hp;
		}

		public int GetMaxSP()
		{
			/*	원본
				if classtype = magic then sp := mentality * level * 10
				else if (classtype = sword) and(class = 7) then sp := mentality* level * 5
				else sp := 0;
			*/

			double sp = (double)status[(int)STATUS.INT] * (double)status[(int)STATUS.LEV] * 10;

			switch (LibUtil.GetClassType(this.clazz))
			{
				case CLASS_TYPE.PHYSICAL_FORCE:
					sp = 0.0;
					break;
				case CLASS_TYPE.MAGIC_USER:
					break;
				case CLASS_TYPE.HYBRID1:
				case CLASS_TYPE.HYBRID2:
				case CLASS_TYPE.HYBRID3:
					sp *= 0.5;
					break;
			}

			return (int)sp;
		}

		public int GetAcByArmor()
		{
			double ac = 0.0;

			if (equip[(int)EQUIP.ARMOR] != null)
				ac = this.ac * status[(int)STATUS.LEV];
			else
				ac = 0.101 * status[(int)STATUS.LEV];

			return (int)(ac + 0.5);
		}

		public int GetAcByShield()
		{
			int shield_skill = this.skill[(int)SKILL_TYPE.SHIELD];

			if (shield_skill <= 0)
				return 0;

			Equiped equiped = this.equip[(int)EQUIP.HAND_SUB];

			if (equiped == null || !equiped.IsValid())
				return 0;

			return (int)(shield_skill * equiped.item.param.ac + 0.5);
		}

		public double GetRateHit()
		{
			double rate_hit = (double)status[(int)STATUS.CON] / CONFIG.MAX_VALUE_OF_STATUS;

			return _Clamp(rate_hit, 0.0, 1.0);
		}

		public double GetRateAttackMagic()
		{
			// TODO2: Rate of AttackMagic
			double rate_hit = (double)status[(int)STATUS.CON] / CONFIG.MAX_VALUE_OF_STATUS;

			return _Clamp(rate_hit, 0.0, 1.0);
		}

		public double GetRateAreaMagic()
		{
			// TODO2: Rate of AreaMagic
			double rate_hit = (double)status[(int)STATUS.CON] / CONFIG.MAX_VALUE_OF_STATUS;

			return _Clamp(rate_hit, 0.0, 1.0);
		}

		public double GetRateDodge()
		{
			double rate_dodge = (double)status[(int)STATUS.AGI] / CONFIG.MAX_VALUE_OF_STATUS;
			return _Clamp(rate_dodge, 0.0, 1.0);
		}

		public bool TryToRunAway()
		{
			return (LibUtil.GetRandomIndex(50) <= status[(int)STATUS.AGI]);
		}
		
		private double _Clamp(double val, double min, double max)
		{
			if (val < min)
				return min;
			else if (val > max)
				return max;
			else
				return val;
		}

		private string _GetColoredGaugeForExp(int max, float progress_real, float progress_accum)
		{
			// "[■■■■■■■■]" '▣' '▒'
			const char DEFAULT_BG = '■';
			const char DEFAULT_FG1 = '■';
			const char DEFAULT_FG2 = '▣';

			Debug.Assert(max >= 2);

			if (max < 0)
				return "";

			if (progress_accum > progress_real)
				progress_accum = progress_real;

			int n_colored_long = 0;
			int n_colored_short = 0;

			if (progress_real > 0.0f)
			{
				n_colored_long = max;

				for (int i = 1; i < max; i++)
				{
					if ((float)i / (max - 1) > progress_real)
					{
						n_colored_long = i;
						break;
					}
				}

				if (progress_accum >= 1.0f)
				{
					n_colored_short = n_colored_long;
				}
				else if (progress_accum > 0.0f)
				{
					for (int i = 1; i < max; i++)
					{
						if ((float)i / (max - 1) > progress_accum)
						{
							n_colored_short = i;
							break;
						}
					}
				}
			}

			string result = "@B";

			if (n_colored_long < max)
			{
				for (int i = 0; i < n_colored_short; i++)
					result += DEFAULT_FG1;
				for (int i = n_colored_short; i < n_colored_long; i++)
					result += DEFAULT_FG2;
				result += "@@<color=#003A3A>";
				for (int i = n_colored_long; i < max; i++)
					result += DEFAULT_BG;
			}
			else
			{
				for (int i = 0; i < n_colored_short; i++)
					result += DEFAULT_FG1;
				for (int i = n_colored_short; i < max; i++)
					result += DEFAULT_FG2;
			}

			result += "</color>";

			return result;
		}

		public string GetExpGauge()
		{
			int level = this.status[(uint)STATUS.LEV];

			long min_exp = ObjPlayer.GetRequiredExp(level);
			long max_exp = ObjPlayer.GetRequiredExp(level + 1);
			long EXP_ACCUM = this.accumulated_exprience;
			long EXP_REAL = EXP_ACCUM + this.exprience;

			if (EXP_REAL < EXP_ACCUM)
				EXP_REAL = EXP_ACCUM;

			float progress_real = 0.0f;
			float progress_accum = 0.0f;

			if (min_exp < max_exp)
			{
				if (EXP_REAL > min_exp)
					progress_real = (float)(EXP_REAL - min_exp) / (float)(max_exp - min_exp);
				if (EXP_ACCUM > min_exp)
					progress_accum = (float)(EXP_ACCUM - min_exp) / (float)(max_exp - min_exp);
			}
			else if (min_exp == max_exp)
			{
				// max level
				progress_real = 1.0f;
				progress_accum = 1.0f;
			}

			return _GetColoredGaugeForExp(8, progress_real, progress_accum);
		}

		public void DisplayStatusOnConsole()
		{
			string s = String.Format
			(
				"Name   : {0}\n" +
				"Gender : {1}\n" +
				"Class  : {2}\n" +
				"Race   : {3}\n" +
				"Title  : {4}\n" +
				"\n" +
				"Exp({5}), AccumExp({6})\n" +
				"\n" +
				"Max HP({7}), Max MP({8})\n" +
				"AttPow({9}), AC({10})\n",

				this.Name,
				LibUtil.GetAssignedString(this.gender),
				LibUtil.GetAssignedString(this.clazz),
				LibUtil.GetAssignedString(this.race),
				LibUtil.GetAssignedString(this.title),
				this.exprience, this.accumulated_exprience,
				this.GetMaxHP(), this.GetMaxSP(),
				this.atta_pow, this.ac
			);

			// TODO2: 귀찮아서...
			/*
					public int[] intrinsic_status = new int[(int)STATUS.MAX];
					public int[] status = new int[(int)STATUS.MAX];

					public int[] intrinsic_skill = new int[(int)SKILL_TYPE.MAX];
					public int[] skill = new int[(int)SKILL_TYPE.MAX];

					public Equiped[] equip = new Equiped[(int)EQUIP.MAX];
			 */

			 Debug.Log(s);
		}

		public static ObjPlayer CreateCreature(string name, GENDER gender, CLASS clazz, RACE race, int level)
		{
			ObjPlayer creature = CreateCharacter(name, gender, clazz, level);
			creature.race = race;

			for (int ix_skill = 0; ix_skill < (int)SKILL_TYPE.MAX; ix_skill++)
				creature.intrinsic_skill[ix_skill] = 0;

			switch (race)
			{
				case RACE.ELEMENTAL:
					creature.intrinsic_status[(int)STATUS.STR] = 10 + LibUtil.GetRandomForSummon(5);
					creature.intrinsic_status[(int)STATUS.INT] = 10 + LibUtil.GetRandomForSummon(5);
					creature.intrinsic_status[(int)STATUS.END] = 10 + LibUtil.GetRandomForSummon(5);
					creature.intrinsic_status[(int)STATUS.CON] = 10 + LibUtil.GetRandomForSummon(5);
					creature.intrinsic_status[(int)STATUS.AGI] = 0;
					creature.intrinsic_status[(int)STATUS.RES] = 10 + LibUtil.GetRandomForSummon(5);
					creature.intrinsic_status[(int)STATUS.DEX] = 10 + LibUtil.GetRandomForSummon(5);
					creature.intrinsic_status[(int)STATUS.LUC] = 10 + LibUtil.GetRandomForSummon(5);
					break;
				case RACE.HUMAN:
				case RACE.UNKNOWN:
				case RACE.GIANT:
				case RACE.GOLEM:
				case RACE.DRAGON:
				case RACE.ANGEL:
				case RACE.DEVIL:
					break;
			}

			creature.Apply();

			creature.hp = creature.GetMaxHP();
			creature.sp = creature.GetMaxSP();

			return creature;
		}

		public static ObjPlayer CreateCharacter(string name, GENDER gender, CLASS clazz, int level)
		{
			ObjPlayer player = new ObjPlayer();

			player.Name = name;
			player.gender = gender;
			player.clazz = clazz;
			player.exprience = 0;
			player.accumulated_exprience = GetRequiredExp(level);

			for (int i = 0; i < (int)STATUS.MAX; i++)
				player.intrinsic_status[i] = GetMinValueOfStatus(clazz, (STATUS)i);

			level = (level > 0) ? level : 1;
			player.intrinsic_status[(int)STATUS.LEV] = level;

			for (int ix_skill = 0; ix_skill < (int)SKILL_TYPE.MAX; ix_skill++)
				player.intrinsic_skill[ix_skill] = GetMinValueOfSkill(clazz, (SKILL_TYPE)ix_skill);

			player.Apply();

			player.hp = player.GetMaxHP();
			player.sp = player.GetMaxSP();

			return player;
		}

		public static ObjPlayer CreateCharacter(PlayerParams param, int level)
		{
			ObjPlayer player = ObjPlayer.CreateCharacter(param.name, param.gender, param.clazz, level);

			for (int ix_status = 0; ix_status < (int)STATUS.MAX; ix_status++)
				player.intrinsic_status[ix_status] = param.status[ix_status];

			for (int ix_skill = 0; ix_skill < (int)SKILL_TYPE.MAX; ix_skill++)
				player.intrinsic_skill[ix_skill] = param.skills[ix_skill];

			player.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 1));
			player.SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(1));
			player.SetEquipment(Yunjr.EQUIP.LEG, Yunjr.ResId.CreateResId_Leg(1));

			player.Apply();

			return player;
		}

		public static int GetMinValueOfStatus(CLASS clazz, STATUS status)
		{
			int ix_class = (int)clazz;
			// TODO2: 9 is a magic number. _CLASS_STATUS[] 의 크기에 이 값은 영향을 받는다.
			ix_class = (ix_class < 9) ? ix_class : 0;

			return _CLASS_STATUS[ix_class, (int)status];
		}

		// 0~ES
		private static readonly int[,] _CLASS_STATUS = new int[9, (int)STATUS.MAX]
		{
			{10,10,10,10,10,10,10,10, 5},
			{10,10,10,10,10,10,10,10, 5},
			{15, 6,13, 7,10, 8,11,10, 5},
			{ 9, 8,10,11,12, 6,15,10, 5},
			{11, 7,15, 9,10,12, 6,10, 5},
			{13,10,13, 8, 6,13, 7,10, 5},
			{ 6,11, 7, 9,15,13,10,10, 5},
			{ 6,15, 6,13, 9,11,10,10, 5},
			{10,13, 6,14, 9, 7,11,10, 5}
		};

		public static int GetMinValueOfSkill(CLASS clazz, SKILL_TYPE skill_type)
		{
			return _CLASS_ABILITY[(int)clazz, (int)skill_type, 0];
		}

		public static int GetMaxValueOfSkill(CLASS clazz, SKILL_TYPE skill_type)
		{
			return _CLASS_ABILITY[(int)clazz, (int)skill_type, 1];
		}

		private static readonly int[,,] _CLASS_ABILITY = new int[(int)CLASS.MAX, (int)SKILL_TYPE.MAX, 2]
		{
			// WIELD      CHOP      STAB       HIT      SHOOT    SHIELD    DAMAGE  ENVIRONMENT  CURE     SUMMON    SPECIAL     ESP
			{{ 10, 50},{ 10, 50},{ 10, 50},{  0, 50},{ 10, 50},{ 10, 50},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0}}, // 0  UNKNOWN
			{{ 10, 50},{ 10, 50},{ 10, 50},{  0, 50},{ 10, 50},{ 10, 50},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0}}, // 1  WANDERER
			{{ 10, 60},{ 10, 60},{  5, 50},{  0, 50},{  0,  0},{ 20, 60},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0}}, // 2  KNIGHT
			{{  0,  0},{  5, 50},{  5, 50},{  0, 60},{ 40,100},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0}}, // 3  HUNTER
			{{  0,  0},{  0,  0},{  0,  0},{ 40,100},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0}}, // 4  MONK
			{{ 25, 60},{  0,  0},{  5, 50},{ 10, 50},{  0, 30},{ 20, 70},{  0,  0},{  0,  0},{ 10, 50},{  0,  0},{  0,  0},{  0,  0}}, // 5  PALADIN
			{{ 10, 80},{  0,  0},{  0, 60},{ 20, 70},{ 10, 80},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{ 10, 30},{ 10, 40},{  0,  0}}, // 6  ASSASSIN
			{{  0,  0},{  0,  0},{  0,  0},{  0, 20},{  0,  0},{  0,  0},{ 10, 20},{ 10, 20},{ 10, 20},{  0,  0},{  0,  0},{  0, 50}}, // 7  MAGICIAN
			{{  0, 40},{  0, 40},{  0, 40},{  0, 40},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{ 50,100}}, // 8  ESPER
			{{ 40,100},{  0,  0},{  0,  0},{  0, 30},{  0,  0},{  0, 30},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0},{  0,  0}}, // 9  SWORDMAN
			{{  0,  0},{  0,  0},{  0,  0},{  0, 20},{  0,  0},{  0,  0},{ 10, 50},{ 10, 30},{ 10, 30},{  0,  0},{  0,  0},{  0, 50}}, // 10 MAGE
			{{  0,  0},{  0,  0},{  0,  0},{  0, 20},{  0,  0},{  0,  0},{  0, 20},{ 10, 50},{ 10, 30},{ 10, 30},{  0, 10},{  0, 50}}, // 11 CONJURER
			{{  0,  0},{  0,  0},{  0,  0},{  0, 20},{  0,  0},{  0,  0},{  0, 20},{  0, 20},{ 10, 50},{ 10, 50},{  0, 10},{  0, 50}}, // 12 SORCERER
			{{  0,  0},{  0,  0},{  0,  0},{  0, 30},{  0,  0},{  0,  0},{ 40,100},{ 25, 60},{ 25, 60},{  0,  0},{  0, 50},{  0,100}}, // 13 WIZARD
			{{  0,  0},{  0,  0},{  0,  0},{  0, 30},{  0,  0},{  0,  0},{ 20, 60},{ 20, 70},{ 40,100},{ 40,100},{  0,100},{  0,100}}, // 14 NECROMANCER
			{{  0,  0},{  0,  0},{  0,  0},{  0, 30},{  0,  0},{  0,  0},{ 10, 60},{ 40,100},{ 30, 70},{ 20, 50},{  0,100},{  0,100}}, // 15 ARCHIMAGE
			{{  0,  0},{  0,  0},{  0,  0},{  0, 30},{  0,  0},{  0,  0},{ 40, 70},{ 40,100},{ 40, 70},{ 20,100},{ 20, 50},{ 20,100}}  // 16 TIMEWALKER
		};

		public static long GetRequiredExp(int level)
		{
			if (level >= _REQUIRED_EXP.Length)
				return long.MaxValue;

			level = (level >= 0) ? level : 0;
			level = (level >= _REQUIRED_EXP.Length) ? _REQUIRED_EXP.Length - 1 : level;

			return _REQUIRED_EXP[level];
		}

		private static readonly long[] _REQUIRED_EXP = new long[41]
		{
			0, 0,1500,6000,20000,50000,150000,250000,500000,800000,1050000,
			1320000,1620000,1950000,2320000,2700000,3120000,3570000,4050000,4560000,5100000,
			6000000,7000000,8000000,9000000,10000000,12000000,14000000,16000000,18000000,20000000,
			25000000,30000000,35000000,40000000,45000000,50000000,55000000,60000000,65000000,70000000
		};
	}
}

/*	데자뷰용
namespace yunjr
{
	// enum 중에서도 배열의 index로 쓰기 위한 것과 type 자체로 쓰기 위한 것의 naming convention을 만들어야 한다.

	public enum ATTACK_TYPE
	{
		NORMAL,
		NOT_SHOWN,
		SHHOT,
		PIERCE,
		SPREAD
	}

	public enum ATTACK_ATTRIB
	{
		PHYSICAL,
		MASICAL,
		FIERY,
		WATERY,
		AIRY,
		EARTHY,
		ELECTRICAL,
		POISONOUS
	}

	public struct AttackParameters
	{
		public ATTACK_TYPE   attack_type;
		public ATTACK_ATTRIB attack_attrib;
		public int           power;
		public int           speed;
		public int           pos_org;
		public int           pos_src;
		public int           pos_dst;
	}

	public enum IX_PERSON_ABILITY
	{
		STRENGTH,
		INTELIGENCE,
		CONCENTRATION,
		ENDURANCE,
		ACCURACY,
		AGILITY,
		WILL,
		PRIETY,
		LUCK,
		LEVEL,
		MAX
	}

	public enum IX_PERSON_INTERNAL
	{
		HIT_POINT,
		SPELL_POINT,
		WHORL_SHIEN,
		HIT_POINT_RECOVERING_TEMPLET,
		SPELL_POINT_RECOVERING_TEMPLET,
		DEFENCE_LEVEL,
		DEFENCE_MAGIC,
		DISPOSITION,
		POISON_DEPTH,
		SLEEP_DEPTH,
		FEAR_DEPTH,
		PARALISIS_DEPTH,
		STONIZATION_DEPTH,
		UNCONSCIOUS_DEPTH,
		DEATH_DEPTH,
		BREATH_REMAIN_COUNT,
		ANTIDOTE_BODY,
		LEVITATION,
		TRANSPARENCY,
		LOVE,
		HOSTILE0,
		HOSTILE1,
		HOSTILE2,
		HOSTILE3,
		HOSTILE4,
		EXPERIENCE,
		POTENTIAL_EXPERIENCE,
		MAX
	}

	public enum IX_PERSON_SKILL
	{
		SWORD,
		AXE,
		SPEAR,
		THROW,
		BOW,
		FIST,
		SHEILD,
		FIRE_TREATING,
		WATER_TREATING,
		AIR_TREATING,
		EARTH_TREATING,
		LIGHT_TREATING,
		SUMMON,
		DIMENTION_CONTROL,
		CURE,
		MAGIC,
		MAX
	}

	public enum PERSON_EQUIPMENT
	{
		HAND,
		HAND_SUB,
		ARMOR,
		HELMET,
		GAUNTLET,
		LEG,
		FINGER,
		NECK,
		MONEY,
		FOOD,
		USELESS,
		MAX
	}

	public enum PERSON_WEAPON
	{
		FIST,
		SWORD,
		AXE,
		SPEAR,
		THROW,
		BOW,
		FIST4MU,
		ETC
	}

	public enum MAGIC_TYPE
	{
		NONE,
		ATTACK,
		DEFENSE,
		SUMMON,
		CURE,
		ENVIRONMENT
	}

	public enum MAGIC_DESTINATION
	{
		ONE,
		ALL,
		RANDOM,
		GROUND,
		PARTY
	}

	[FlagsAttribute]
	public enum MAGIC_NEED: int
	{
		None     = 0,
		NOT_NEED = 0x000,
		FIRE     = 0x001,
		WATER    = 0x002,
		AIR      = 0x004,
		EARTH    = 0x008,
		POISON   = 0x010,
		THING    = 0x020,
		CORPSE   = 0x040,
		WEAPON   = 0x080,
		SHIELD   = 0x100,
		ARMOR    = 0x200,
		PLAYER   = 0x400,
		All      = int.MaxValue
	}

	public struct Magic
	{
		public MAGIC_TYPE        magic_type;
		public int               number;
		public int               shape;
		public MAGIC_DESTINATION magic_destination;
		public ATTACK_TYPE       method;
		public MAGIC_NEED        set_of_magic_need;
		public ATTACK_ATTRIB     attack_attrib;
		public int               attack_power;
		public int               attack_range;
		public int               mp_consumtion;
	}

	public struct MagicData
	{
		public string name;
		public Magic  data;
	}

	public enum ITEM_ATTRIB
	{
		NORMAL,
		VIRTUE,
		VICE
	}

	public struct Item
	{
		public PERSON_EQUIPMENT equipment_type;
		public PERSON_WEAPON    weapon_type;
		public ITEM_ATTRIB      attrib;
		public int number;
		public int weight;
		public int attack_power;
		public int defense_level;
		public int attack_range;
		public int throw_range;
		public int throw_power;
		public int defense_power;
		public int suffix;
		public int suffix_bonus;
		public MAGIC_TYPE magic_type;
		public int magic;
		public int magic_remain;
		public int maintain_level;
		public int shape;
		public int shape_revolution;
		public int trailing_count;
		public int contain;
	}

	public struct ItemData
	{
		public string name;
		public int    price;
		public Item   data;
	}

	public class TempPlayer
	{
		public MAGIC_NEED person_attrib;
		//public TMapAttribute mPersonAttribute;

		public int[] ability        = new int[(int)IX_PERSON_ABILITY.MAX];
		public int[] internal_param = new int[(int)IX_PERSON_INTERNAL.MAX];
		public int[] skill          = new int[(int)IX_PERSON_SKILL.MAX];
		public int[] equipment      = new int[(int)PERSON_EQUIPMENT.MAX];
	}

}
*/