using UnityEngine;
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public struct CreatureState
	{
		public int hp;
		public int poison;
		public int unconscious;
		public int dead;
		public int regenerative_hp; // 1 r_hp는 1000hp로 재생
		public int doppelganger; // > 0 일 때, 출력 컬러로 사용
	}

	public struct CreatureAttribOld
	{
		public string name;
		public int strength;
		public int mentality;
		public int endurance;
		public int resistance_1;
		public int resistance_2;
		public int agility;
		public int accuracy_1;
		public int accuracy_2;
		public int ac;
		public int special;
		public int cast_level;
		public int special_cast_level;
		public int level;
		/*
			int   order;
			GENDER gender;
			int   class_;

			int   concentration;
			int   luck;

			int   sp;
			int   esp;
			int   experience;
			int   accuracy[3];
			int   level[3];

			int   weapon;
			int   shield;
			int   armor;

			int   pow_of_weapon;
			int   pow_of_shield;
			int   pow_of_armor;
		*/

		public CreatureAttribOld(string name, int[] attrib)
		{
			Debug.Assert(attrib.Length == 13);

			int i = 0;

			this.name               = name;
			this.strength           = attrib[i++];
			this.mentality          = attrib[i++];
			this.endurance          = attrib[i++];
			this.resistance_1       = attrib[i++];
			this.resistance_2       = attrib[i++];
			this.agility            = attrib[i++];
			this.accuracy_1         = attrib[i++];
			this.accuracy_2         = attrib[i++];
			this.ac                 = attrib[i++];
			this.special            = attrib[i++];
			this.cast_level         = attrib[i++];
			this.special_cast_level = attrib[i++];
			this.level              = attrib[i++];
		}

		public static CreatureAttribOld GetEnemy(int index)
		{
			// [0..76]
			if (index < 0 || index >= _s_enemy_data.Length)
				index = _s_enemy_data.Length - 1;

			return _s_enemy_data[index];
		}

		public static int GetMaxIndexOfEnemy()
		{
			return _s_enemy_data.Length - 1;
		}

		private static readonly CreatureAttribOld[] _s_enemy_data = new CreatureAttribList
		{
			// name                        str men end res res agi accuracy   ac spe clv scl  lv
			{"존재없음",        new int[] { 0,  0,  0,  0,  0,  0,  0,  0,     0,  0,  0,  0,  1 } },
			{"오크",            new int[] { 8,  0,  8,  0,  0,  8,  8,  0,     1,  0,  0,  0,  1 } },
			{"트롤",            new int[] { 9,  0,  6,  0,  0,  9,  9,  0,     1,  0,  0,  0,  1 } },
			{"왕 뱀",           new int[] { 7,  3,  7,  0,  0, 11, 11,  6,     1,  1,  1,  0,  1 } },
			{"왕 지렁이",       new int[] { 3,  5,  5,  0,  0,  6, 11,  7,     1,  0,  1,  0,  1 } },
			{"Dwarf",           new int[] {10,  0, 10,  0,  0, 10, 10,  0,     2,  0,  0,  0,  2 } },
			{"Giant",           new int[] {15,  0, 13,  0,  0,  8,  8,  0,     2,  0,  0,  0,  2 } },
			{"Phantom",         new int[] { 0, 12, 12,  0,  0,  0,  0, 13,     0,  0,  2,  0,  2 } },
			{"Wolf",            new int[] { 7,  0, 11,  0,  0, 15, 15,  0,     1,  0,  0,  0,  2 } },
			{"Imp",             new int[] { 8,  8, 10, 20,  0, 18, 18, 10,     2,  0,  2,  0,  3 } },
			{"Goblin",          new int[] {11,  0, 13,  0,  0, 13, 13,  0,     3,  0,  0,  0,  3 } },
			{"Python",          new int[] { 9,  5, 10,  0,  0, 13, 13,  6,     1,  1,  1,  0,  3 } },
			{"Insects",         new int[] { 6,  4,  8,  0,  0, 14, 14, 15,     2,  1,  1,  0,  3 } },
			{"Giant Spider",    new int[] {10,  0,  9,  0,  0, 20, 13,  0,     2,  1,  0,  0,  4 } },
			{"Gremlin",         new int[] {10,  0, 10,  0,  0, 20, 20,  0,     2,  0,  0,  0,  4 } },
			{"Buzz Bug",        new int[] {13,  0, 11,  0,  0, 15, 15,  0,     1,  1,  0,  0,  4 } },
			{"Salamander",      new int[] {12,  2, 13,  0,  0, 12, 12, 10,     3,  1,  1,  0,  4 } },
			{"Blood Bat",       new int[] {11,  0, 10,  0,  0,  5, 15,  0,     1,  0,  0,  0,  5 } },
			{"Giant Rat",       new int[] {13,  0, 18,  0,  0, 10, 10,  0,     2,  0,  0,  0,  5 } },
			{"Skeleton",        new int[] {10,  0, 19,  0,  0, 12, 12,  0,     3,  0,  0,  0,  5 } },
			{"Kelpie",          new int[] { 8, 13,  8,  0,  0, 14, 15, 17,     2,  0,  3,  0,  5 } },
			{"Gazer",           new int[] {15,  8, 11,  0,  0, 20, 15, 15,     3,  0,  2,  0,  6 } },
			{"Ghost",           new int[] { 0, 15, 10,  0,  0,  0,  0, 15,     0,  0,  3,  0,  6 } },
			{"Slime",           new int[] { 5, 13,  5,  0,  0, 19, 19, 19,     2,  0,  2,  0,  6 } },
			{"Rock-Man",        new int[] {19,  0, 15,  0,  0, 10, 10,  0,     5,  0,  0,  0,  6 } },
			{"Kobold",          new int[] { 9,  9,  9,  0,  0,  9,  9,  9,     2,  0,  3,  0,  7 } },
			{"Mummy",           new int[] {10, 10, 10,  0,  0, 10, 10, 10,     3,  1,  2,  0,  7 } },
			{"Devil Hunter",    new int[] {13, 10, 10,  0,  0, 10, 10, 18,     3,  2,  2,  0,  7 } },
			{"Crazy One",       new int[] { 9,  9, 10,  0,  0,  5,  5, 13,     1,  0,  3,  0,  7 } },
			{"Ogre",            new int[] {19,  0, 19,  0,  0,  9, 12,  0,     4,  0,  0,  0,  8 } },
			{"Headless",        new int[] {10,  0, 15,  0,  0, 10, 10,  0,     3,  2,  0,  0,  8 } },
			{"Mud-Man",         new int[] {10,  0, 15,  0,  0, 10, 10,  0,     7,  0,  0,  0,  8 } },
			{"Hell Cat",        new int[] {10, 15, 11,  0,  0, 18, 18, 16,     2,  2,  3,  0,  8 } },
			{"Wisp",            new int[] { 5, 16, 10,  0,  0, 20, 20, 20,     2,  0,  4,  0,  9 } },
			{"Basilisk",        new int[] {10, 15, 12,  0,  0, 20, 20, 10,     2,  1,  2,  0,  9 } },
			{"Sprite",          new int[] { 0, 20,  2, 80,  0, 20, 20, 20,     0,  3,  5,  0,  9 } },
			{"Vampire",         new int[] {15, 13, 14, 20,  0, 17, 17, 15,     3,  1,  2,  0,  9 } },
			{"Molten Monster",  new int[] { 8,  0, 20, 50,  0,  8, 16,  0,     3,  0,  0,  0, 10 } },
			{"Great Lich",      new int[] {10, 10, 11, 10,  0, 18, 10, 10,     4,  2,  3,  0, 10 } },
			{"Rampager",        new int[] {20,  0, 19,  0,  0, 19, 19,  0,     3,  0,  0,  0, 10 } },
			{"Mutant",          new int[] { 0, 10, 15,  0,  0,  0,  0, 20,     3,  0,  3,  0, 10 } },
			{"Rotten Corpse",   new int[] {15, 15, 15, 60, 60, 15, 15, 15,     2,  2,  3,  0, 11 } },
			{"Gagoyle",         new int[] {10,  0, 20, 10, 10, 10, 10,  0,     6,  0,  0,  0, 11 } },
			{"Wivern",          new int[] {10, 10,  9, 30, 30, 20, 20,  9,     3,  2,  3,  0, 11 } },
			{"Grim Death",      new int[] {16, 16, 16, 50, 50, 16, 16, 16,     2,  2,  3,  0, 12 } },
			{"Griffin",         new int[] {15, 15, 15,  0,  0, 15, 14, 14,     3,  2,  3,  0, 12 } },
			{"Evil Soul",       new int[] { 0, 20, 10,  0,  0,  0,  0, 15,     0,  3,  4,  0, 12 } },
			{"Cyclops",         new int[] {20,  0, 20, 10, 10, 20, 20,  0,     4,  0,  0,  0, 13 } },
			{"Dancing-Swd",     new int[] {15, 20,  6, 20, 20, 20, 20, 20,     0,  2,  4,  0, 13 } },
			{"Hydra",           new int[] {15, 10, 20, 40, 40, 18, 18, 12,     8,  1,  3,  0, 13 } },
			{"Stheno",          new int[] {20, 20, 20,255,255, 10, 10, 10,   255,  1,  3,  0, 14 } },
			{"Euryale",         new int[] {20, 20, 15,255,255, 10, 15, 10,   255,  2,  3,  0, 14 } },
			{"Medusa",          new int[] {15, 10, 16, 50, 50, 15, 15, 10,     4,  3,  3,  0, 14 } },
			{"Minotaur",        new int[] {15,  7, 20, 40, 40, 20, 20, 15,    10,  0,  3,  0, 15 } },
			{"Dragon",          new int[] {15,  7, 20, 50, 50, 18, 20, 15,     9,  2,  4,  0, 15 } },
			{"Dark Soul",       new int[] { 0, 20, 40, 60, 60,  0,  0, 20,     0,  0,  5,  0, 15 } },
			{"Hell Fire",       new int[] {15, 20, 30, 30, 30, 15, 15, 15,     0,  3,  5,  0, 16 } },
			{"Astral Mud",      new int[] {13, 20, 25, 40, 40, 19, 19, 10,     9,  3,  4,  0, 16 } },
			{"Reaper",          new int[] {15, 20, 33, 70, 70, 20, 20, 20,     5,  1,  3,  0, 17 } },
			{"Crab God",        new int[] {20, 20, 30, 20, 20, 18, 18, 19,     7,  2,  4,  0, 17 } },
			{"Wraith",          new int[] { 0, 24, 35, 50, 50, 15,  0, 20,     2,  3,  4,  0, 18 } },
			{"Death Skull",     new int[] { 0, 20, 40, 80, 80,  0,  0, 20,     0,  2,  5,  0, 18 } },
			{"Draconian",       new int[] {30, 20, 30, 60, 60, 18, 18, 18,     7,  2,  5,  1, 19 } },
			{"Death Knight",    new int[] {35,  0, 35, 50, 50, 20, 20,  0,     6,  3,  0,  1, 19 } },
			{"Guardian-Lft",    new int[] {25,  0, 40, 70, 70, 20, 18,  0,     5,  2,  0,  0, 20 } },
			{"Guardian-Rgt",    new int[] {25,  0, 40, 40, 40, 20, 20,  0,     7,  2,  0,  0, 20 } },
			{"Mega-Robo",       new int[] {40,  0, 50,  0,  0, 19, 19,  0,    10,  0,  0,  0, 21 } },
			{"Ancient Evil",    new int[] { 0, 20, 60,100,100, 18,  0, 20,     5,  0,  6,  2, 22 } },
			{"Lord Ahn",        new int[] {40, 20, 60,100,100, 35, 20, 20,    10,  3,  5,  3, 23 } },
			{"Frost Dragon",    new int[] {15,  7, 20, 50, 50, 18, 20, 15,     9,  2,  4,  0, 24 } },
			{"ArchiDraconian",  new int[] {30, 20, 30, 60, 60, 18, 18, 18,     7,  2,  5,  1, 25 } },
			{"Panzer Viper",    new int[] {35,  0, 40, 80, 80, 20, 20,  0,     9,  1,  0,  0, 26 } },
			{"Black Knight",    new int[] {35,  0, 35, 50, 50, 20, 20,  0,     6,  3,  0,  1, 27 } },
			{"ArchiMonk",       new int[] {20,  0, 50, 70, 70, 20, 20,  0,     5,  0,  0,  0, 28 } },
			{"ArchiMage",       new int[] {10, 19, 30, 70, 70, 10, 10, 19,     4,  0,  6,  0, 29 } },
			{"Neo-Necromancer", new int[] {40, 20, 60,100,100, 30, 20, 20,    10,  3,  6,  3, 30 } },
			{"존재미상",        new int[] {40, 20, 60,100,100, 30, 20, 20,    10,  3,  6,  3, 30 } }
		}.ToArray();
	}

	public class CreatureAttribList : List<CreatureAttribOld>
	{
		public void Add(string name, int[] strength)
		{
			Add(new CreatureAttribOld(name, strength));
		}
	}

	[Serializable]
	public class ObjNameBase: ISerialize
	{
		public enum JOSA
		{
			NONE = 0, // 이름 그대로
			SUB,      // '은' 또는 '는'
			SUB2,     // '이' 또는 '가'
			QUOTE,    // '이'라고 또는 ''라고; "민준이라 불러라" / "철수라 불러라"
			OBJ,      // '을' 또는 '를'
			WITH      // '로' 또는 '으로'
		}

		public bool IsValid()
		{
			return (_name != "");
		}

		public void Dismiss()
		{
			_name = "";
		}

		public void SetName(string sz_name)
		{
			if (sz_name.Length > 0)
			{
				_name = sz_name;

				uint last_jongsung = _GetJongsung(sz_name[sz_name.Length-1]);
				bool has_jongsung = (last_jongsung > 0);

				_name_subject1  = _name;
				_name_subject1 += (has_jongsung) ? "은" : "는";

				_name_subject2  = _name;
				_name_subject2 += (has_jongsung) ? "이" : "가";

				_name_quote     = _name;
				_name_quote    += (has_jongsung) ? "이" : "";

				_name_object = _name;
				_name_object   += (has_jongsung) ? "을" : "를";

				// 카로 / 칼로 / 칸으로 / 캉으로
				_name_with      = _name;
				_name_with     += (has_jongsung && last_jongsung != 8) ? "으로" : "로";
			}
		}

		public string GetName(JOSA method = JOSA.NONE)
		{
			switch (method)
			{
			case JOSA.NONE:
				return _name;
			case JOSA.SUB:
				return _name_subject1;
			case JOSA.SUB2:
				return _name_subject2;
			case JOSA.QUOTE:
				return _name_quote;
			case JOSA.OBJ:
				return _name_object;
			case JOSA.WITH:
				return _name_with;
			default:
				Debug.Assert(false);
				return "";
			}
		}

		private uint _GetJongsung(char _code)
		{
			uint code = (uint)_code;

			if (code >= 0xAC00 && code <= 0xD7A3)
			{
				#pragma warning disable 219
				const int MAX_SM1 = 19;
				#pragma warning restore 219
				const int MAX_SM2 = 21;
				const int MAX_SM3 = 28;

				code -= 0xAC00;

				uint SM1 = code / (MAX_SM2 * MAX_SM3);
				uint SM2 = (code - SM1 * (MAX_SM2 * MAX_SM3)) / MAX_SM3;
				uint SM3 = code - SM1 * (MAX_SM2 * MAX_SM3) - SM2 * MAX_SM3;

				return SM3; // (SM3 > 0)
			}

			//?? 영어에 대해서도 적용해야 함
			// default
			return 0;
		}

		public override void _Load(Stream stream)
		{
			_Read(stream, out _name);
			SetName(_name);
		}

		public override void _Save(Stream stream)
		{
			_Write(stream, _name);
		}

		protected string _name = "";

		private string _name_subject1 = "";
		private string _name_subject2 = "";
		private string _name_quote = "";
		private string _name_object = "";
		private string _name_with = "";
	}

	public class ObjCreature
	{
		public string name;

		public ObjCreature()
		{
			name = "";
		}

		public static ObjEnemy Clone(int index)
		{
			return null;
		}
	}
}
