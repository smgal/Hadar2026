
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using LitJson;

namespace Yunjr
{
	[Serializable]
	public struct ItemSub
	{
		public double atta_pow;
		public double ac;
		public ITEM_TYPE item_type;

		public static ItemSub GetDefault()
		{
			ItemSub item_sub;
			item_sub.atta_pow = 0;
			item_sub.ac = 0;
			item_sub.item_type = ITEM_TYPE.NONE;

			return item_sub;
		}
	}

	[Serializable]
	public struct Item
	{
		public ResId res_id;
		public string name;
		public ItemSub param;
		public string annex;
	}
}

namespace Yunjr
{
	[Serializable]
	public class ResId
	{
		/*---------------------------------------------------------------------|
			## Verification bits
				- MSB 00: <<invalid>>
				- MSB 01: Item type resource
				- MSB 10: <<reserved>>
				- MSB 11: String type resource

			msb                                  lsb
			 |                                    |
			 VV......  ........  ........  ........

		 |---------------------------------------------------------------------|

			## Item type resource

			msb                                  lsb
			 |         [ type ]  [detail]  [ index]
			 01......  xxxxxxxx  yyyyyyyy  zzzzzzzz

		 |---------------------------------------------------------------------|

			## String type resource

			msb                                  lsb
			 |  [ 1 ] [ 2 ] [ 3 ] [ 4 ] [ 5 ] [ 6 ]
			 11 iiiii jjjjj kkkkk lllll mmmmm nnnnn

			 11   : tag
			 iiiii: 1st character
			 jjjjj: 2nd character
			 kkkkk: 3rd character
			 lllll: 4th character
			 mmmmm: 5th character
			 nnnnn: 6th character

			5-bit composition from a character

			  0: etc
			  1: 'A' or 'a'
			 26: 'Z' or 'z'
			 27: '1'
			 28: '2'
			 29: '3'
			 30: '4'
			 31: '-' or '_'

		 |--------------------------------------------------------------------*/

		const uint VERIF_MASK         = 0xC0000000U;
		const int  VERIF_SHIFT        = 30;
		const uint VERIF_TAG_INVALID  = 0x0U;
		const uint VERIF_TAG_ITEM     = 0x1U;
		const uint VERIF_TAG_RESERVED = 0x2U;
		const uint VERIF_TAG_STRING   = 0x3U;

		const uint ITEM_TYPE_MASK     = 0x00FF0000U;
		const  int ITEM_TYPE_SHIFT    = 16;

		const uint ITEM_DETAIL_MASK   = 0x0000FF00U;
		const int  ITEM_DETAIL_SHIFT  = 8;

		const uint ITEM_INDEX_MASK    = 0x000000FFU;
		const int  ITEM_INDEX_SHIFT   = 0;

		public const uint ITEM_TYPE_TAG_WEAPON   = 0x01U;
		public const uint ITEM_TYPE_TAG_SHIELD   = 0x02U;
		public const uint ITEM_TYPE_TAG_ARMOR    = 0x03U;
		public const uint ITEM_TYPE_TAG_ORNAMENT = 0x04U;

		uint unique_id = 0;

		public ResId()
		{
			this.unique_id = 0;
		}

		public ResId(uint unique_id)
		{
			this.unique_id = unique_id;
		}

		public ResId(string name)
		{
            // resource id from a string
            uint[] encode = new uint[6] { 0, 0, 0, 0, 0, 0 };

            for (int i = 0; i < encode.Length; i++)
			{
				int character = name[i];

				if (character == 0)
					break;

                uint code = 0;

				if ((character >= 'A') && (character <= 'Z'))
					code = (uint)(character - 'A' + 1);
				else if ((character >= 'a') && (character <= 'z'))
					code = (uint)(character - 'a' + 1);
				else if ((character >= '1') && (character <= '4'))
					code = (uint)(character - '1' + 27);
				else if ((character == '-') || (character == '_'))
					code = 31;
				else
					code = 0;

                encode[i] = code;
            }

            unique_id = (VERIF_TAG_STRING << VERIF_SHIFT) | (encode[0] << 25) | (encode[1] << 20) | (encode[2] << 15) | (encode[3] << 10) | (encode[4] << 5) | (encode[5]);
		}

		private ResId(uint type, uint detail, uint index)
		{
			Debug.Assert(type < 0x100);
            Debug.Assert(detail < 0x100);
            Debug.Assert(index < 0x100);

            unique_id = (VERIF_TAG_ITEM << VERIF_SHIFT) | (type << ITEM_TYPE_SHIFT) | (detail << ITEM_DETAIL_SHIFT) | (index << ITEM_INDEX_SHIFT);
		}

		public uint GetId()
		{
			return unique_id;
		}

		public uint GetItemType()
		{
			return (unique_id & ITEM_TYPE_MASK) >> ITEM_TYPE_SHIFT;
		}

		public uint GetItemDetail()
		{
			return (unique_id & ITEM_DETAIL_MASK) >> ITEM_DETAIL_SHIFT;
		}

		public uint GetItemIndex()
		{
			return (unique_id & ITEM_INDEX_MASK) >> ITEM_INDEX_SHIFT;
		}

		public static ResId CreateResId_Weapon(uint detail, uint index)
		{
			if (index >= 0 && index < 0x100)
				return new ResId(ITEM_TYPE_TAG_WEAPON, detail, index);
			else
				return new ResId();
		}

		public static ResId CreateResId_Shield(uint index)
		{
			if (index >= 0 && index < 0x100)
				return new ResId(ITEM_TYPE_TAG_SHIELD, 0, index);
			else
				return new ResId();
		}

		public static ResId CreateResId_ArmorType(uint detail, uint index)
		{
			if (index >= 0 && index < 0x100)
				return new ResId(ITEM_TYPE_TAG_ARMOR, detail, index);
			else
				return new ResId();
		}

		public static ResId CreateResId_Armor(uint index)
		{
			return CreateResId_ArmorType(Yunjr.ITEM_TYPE.ARMOR - Yunjr.ITEM_TYPE.ARMOR_MIN, index);
		}

		public static ResId CreateResId_Head(uint index)
		{
			return CreateResId_ArmorType(Yunjr.ITEM_TYPE.HEAD - Yunjr.ITEM_TYPE.ARMOR_MIN, index);
		}

		public static ResId CreateResId_Leg(uint index)
		{
			return CreateResId_ArmorType(Yunjr.ITEM_TYPE.LEG - Yunjr.ITEM_TYPE.ARMOR_MIN, index);
		}

		public static ResId CreateResId_Ornament(uint index)
		{
			if (index >= 0 && index < 0x100)
				return new ResId(ITEM_TYPE_TAG_ORNAMENT, 0, index);
			else
				return new ResId();
		}
	}

	public class ObjItem: ObjNameBase
	{
		public ResId res_id;
		public int ix_db;

		public ObjItem()
		{
			this.res_id = new ResId();
			this.ix_db = 0;
		}

		public ObjItem(ResId res_id, int ix_db)
		{
			this.res_id = res_id;
			this.ix_db = ix_db;
		}

		private static void RegisterItem(ref Dictionary<uint, Yunjr.Item> item_list, ItemConv item_base)
		{
			uint id = item_base.CreateResId().GetId();

			if (!item_list.ContainsKey(id))
				item_list.Add(item_base.CreateResId().GetId(), item_base.AsItem());
			else
				Debug.LogError(String.Format("Resource Id(0x{0,-8:X8}) duplicated", id));
		}
		/*
		public static void LoadItemListFromJson(out Dictionary<uint, Yunjr.Item> item_list)
		{
			item_list = new Dictionary<uint, Yunjr.Item>();

			//string text = System.IO.File.ReadAllText(@"books.json");
			//JsonData jsonBooks = JsonMapper.ToObject(text);
			TextAsset bin = Resources.Load("Text/" + "books") as TextAsset;
			JsonData jsonBooks = JsonMapper.ToObject(bin.text);
 
			Weapon weapon;

			for (int i = 0; i < jsonBooks["weapon"].Count; i++)
			{
				weapon = new Weapon();
				weapon.unique_id = Convert.ToUInt32(jsonBooks["weapon"][i]["id"].ToString());
				weapon.name = jsonBooks["weapon"][i]["name"].ToString();
				weapon.power = Convert.ToDouble(jsonBooks["weapon"][i]["power"].ToString());

				string type_str = jsonBooks["weapon"][i]["type"].ToString();
				switch (type_str)
				{
					case "WIELD":
						weapon.type = Yunjr.ITEM_TYPE.WIELD;
						break;
					case "CHOP":
						weapon.type = Yunjr.ITEM_TYPE.CHOP;
						break;
					case "STAB":
						weapon.type = Yunjr.ITEM_TYPE.STAB;
						break;
					case "HIT":
						weapon.type = Yunjr.ITEM_TYPE.HIT;
						break;
					case "SHOOT":
						weapon.type = Yunjr.ITEM_TYPE.SHOOT;
						break;
					case "SHIELD":
						weapon.type = Yunjr.ITEM_TYPE.SHIELD;
						break;
					case "ARMOR":
						weapon.type = Yunjr.ITEM_TYPE.ARMOR;
						break;
					case "HEAD":
						weapon.type = Yunjr.ITEM_TYPE.HEAD;
						break;
					case "LEG":
						weapon.type = Yunjr.ITEM_TYPE.LEG;
						break;
					case "ORNAMENT":
						weapon.type = Yunjr.ITEM_TYPE.ORNAMENT;
						break;
					default:
						weapon.type = Yunjr.ITEM_TYPE.NONE;
						break;
				}

				for (int j = 0; j < jsonBooks["weapon"][i]["etc_data"].Count; j++)
				{
					weapon.data[j] = Convert.ToInt32(jsonBooks["weapon"][i]["etc_data"][j].ToString());
				}

				if (jsonBooks["weapon"][i]["etc_description"] != null)
				{
					weapon.description = new Description();
					weapon.description.brief = new ArrayList();

					for (int j = 0; j < jsonBooks["weapon"][i]["etc_description"]["brief"].Count; j++)
					{
						Brief brief = new Brief();
						brief.image_name = jsonBooks["weapon"][i]["etc_description"]["brief"][j]["image"].ToString();
						brief.text = jsonBooks["weapon"][i]["etc_description"]["brief"][j]["text"].ToString();

						weapon.description.brief.Add(brief);
					}
				}

				// register to DB
				RegisterItem(ref item_list, weapon);

				//GameObject bookGameObject = GameObject.Find("Book" + book.id.ToString());
				//bookGameObject.SendMessage("LoadBook", book);
			}

			Armor armor;

			for (int i = 0; i < jsonBooks["armor"].Count; i++)
			{
				armor = new Armor();
				armor.unique_id = Convert.ToUInt32(jsonBooks["armor"][i]["id"].ToString());
				armor.name = jsonBooks["armor"][i]["name"].ToString();
				armor.ac = Convert.ToDouble(jsonBooks["armor"][i]["ac"].ToString());

				// register to DB
				RegisterItem(ref item_list, armor);

				//GameObject bookGameObject = GameObject.Find("Book" + book.id.ToString());
				//bookGameObject.SendMessage("LoadBook", book);
			}

			Debug.Log("!");
		}
		*/
		public struct _WeaponStruct
		{
			public uint detail;
			public uint index;
			public string name;
			public double power;
			public Yunjr.ITEM_TYPE type;

			public _WeaponStruct(uint _index, string _name, double _power, Yunjr.ITEM_TYPE _type)
			{
				if (_type >= Yunjr.ITEM_TYPE.WEAPON_MIN && _type < Yunjr.ITEM_TYPE.WEAPON_MAX)
					detail = (uint)_type - (uint)Yunjr.ITEM_TYPE.WEAPON_MIN;
				else
					detail = 0;

				index = _index;
				name = _name;
				power = _power;
				type = _type;
			}
		}

		public static readonly _WeaponStruct[] WEAPON_LIST =
		{
			// '불확실한 무기',

			new _WeaponStruct(0, "맨손",  1.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct(0, "맨손",  1.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct(0, "맨손",  1.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct(0, "맨손",  1.0, Yunjr.ITEM_TYPE.HIT),
			new _WeaponStruct(0, "맨손",  1.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct(0, "(없음)",  1.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(0, "(없음)",  1.0, Yunjr.ITEM_TYPE.SUMMON_MULTI),
			/* TODO: 원작에서는 class 별로 보정치가 있음
			 * -->
			 * ('투사','기사','검사','사냥꾼','전투승','암살자','전사')
			 * -->
			 * ((15,15,15,15,15,25,15),
			 *  (30,30,25,25,25,25,30),
			 *  (35,40,35,35,35,35,40),
			 *  (45,48,50,40,40,40,40),
			 *  (50,55,60,50,50,50,55),
			 *  (60,70,70,60,60,60,65),
			 *  (70,70,80,70,70,70,70)),
			 */
			new _WeaponStruct( 1, "단검",           15.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct( 2, "그라디우스",     30.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct( 3, "샤벨",           35.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct( 4, "신월도",         45.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct( 5, "인월도",         50.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct( 6, "장검",           60.0, Yunjr.ITEM_TYPE.WIELD),
			new _WeaponStruct( 7, "프렘버그",       70.0, Yunjr.ITEM_TYPE.WIELD),

			new _WeaponStruct( 1, "소형 해머",      15.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct( 2, "소형 도끼",      35.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct( 3, "프레일",         35.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct( 4, "전투용 망치",    52.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct( 5, "철퇴",           60.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct( 6, "양날 전투 도끼", 75.0, Yunjr.ITEM_TYPE.CHOP),
			new _WeaponStruct( 7, "핼버드",         80.0, Yunjr.ITEM_TYPE.CHOP),

			new _WeaponStruct( 1, "단도",           10.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct( 2, "기병창",         35.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct( 3, "단창",           35.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct( 4, "레이피어",       40.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct( 5, "삼지창",         60.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct( 6, "랜서",           80.0, Yunjr.ITEM_TYPE.STAB),
			new _WeaponStruct( 7, "도끼창",         90.0, Yunjr.ITEM_TYPE.STAB),

			new _WeaponStruct( 1, "너클",            5.0, Yunjr.ITEM_TYPE.HIT),
			new _WeaponStruct( 2, "장대",           10.0, Yunjr.ITEM_TYPE.HIT),
			new _WeaponStruct( 3, "곤봉",           25.0, Yunjr.ITEM_TYPE.HIT),

			new _WeaponStruct( 1, "블로우 파이프",  10.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct( 2, "표창",           10.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct( 3, "투석기",         20.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct( 4, "투창",           35.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct( 5, "활",             45.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct( 6, "석궁",           55.0, Yunjr.ITEM_TYPE.SHOOT),
			new _WeaponStruct( 7, "아르발레스트",   70.0, Yunjr.ITEM_TYPE.SHOOT),

			new _WeaponStruct( 1, "화염",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 1, "해일",           10.0, Yunjr.ITEM_TYPE.SUMMON_MULTI),
			new _WeaponStruct( 2, "폭풍",           10.0, Yunjr.ITEM_TYPE.SUMMON_MULTI),
			new _WeaponStruct( 2, "지진",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 3, "이빨",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 4, "촉수",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 5, "창",             10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),

			new _WeaponStruct( 6, "발톱",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 7, "바위",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 8, "화염검",         10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 9, "동물의 뼈",      10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(10, "번개 마법",      10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),

			new _WeaponStruct(11, "점토",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(12, "강철 주먹",      10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(13, "산성 가스",      10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(14, "전광",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(15, "독가스",         10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),

			new _WeaponStruct(16, "불꽃",           10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct(17, "염소 가스",      10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),
			new _WeaponStruct( 3, "한기",           10.0, Yunjr.ITEM_TYPE.SUMMON_MULTI),
			new _WeaponStruct(18, "냉동 가스",      10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE)
	
		};

		public struct _ShieldStruct
		{
			public uint detail;
			public uint index;
			public string name;
			public double ac;

			public _ShieldStruct(uint _index, string _name, double _ac)
			{
				detail = Yunjr.ITEM_TYPE.SHIELD - Yunjr.ITEM_TYPE.SHIELD_MIN;
				Debug.Assert(detail == 0);
				index = _index;
				name = _name;
				ac = _ac;
			}
		}

		public static readonly _ShieldStruct[] SHIELD_LIST =
		{
			// + '불확실함',
			new _ShieldStruct(0, "없음",           0.0),
			new _ShieldStruct(1, "가죽 방패",      1.0),
			new _ShieldStruct(2, "소형 강철 방패", 2.0),
			new _ShieldStruct(3, "대형 강철 방패", 3.0),
			new _ShieldStruct(4, "크로매틱 방패",  4.0),
			new _ShieldStruct(5, "플래티움 방패",  5.0)
		};

		public struct _ArmorStruct
		{
			public uint detail;
			public uint index;
			public string name;
			public double ac;

			public _ArmorStruct(uint _index, string _name, double _ac)
			{
				detail = Yunjr.ITEM_TYPE.ARMOR - Yunjr.ITEM_TYPE.ARMOR_MIN;
				Debug.Assert(detail >= 0 && detail < 3);
				index = _index;
				name = _name;
				ac = _ac;
			}
		}

		public static readonly _ArmorStruct[] ARMOR_LIST =
		{
			// + '불확실함',
			new _ArmorStruct( 0, "평상복",         0.0),
			new _ArmorStruct( 1, "가죽 갑옷",      1.0),
			new _ArmorStruct( 2, "링 메일",        2.0),
			new _ArmorStruct( 3, "체인 메일",      3.0),
			new _ArmorStruct( 4, "미늘 갑옷",      4.0),
			new _ArmorStruct( 5, "브리간디",       5.0),
			new _ArmorStruct( 6, "큐일보일",       6.0),
			new _ArmorStruct( 7, "라멜라",         7.0),
			new _ArmorStruct( 8, "철판 갑옷",      8.0),
			new _ArmorStruct( 9, "크로매틱 갑옷",  9.0),
			new _ArmorStruct(10, "플래티움 갑옷", 10.0),
			new _ArmorStruct(11, "흑요석 갑옷",   20.0)
		};

		public struct _PropsStruct
		{
			public uint detail;
			public uint index;
			public string name;
			public Yunjr.ITEM_TYPE type;
			public string annex;

			public _PropsStruct(uint _index, Yunjr.ITEM_TYPE _type, string _name, string _annex)
			{
				switch (_type)
				{
					case Yunjr.ITEM_TYPE.HEAD:
						detail = Yunjr.ITEM_TYPE.HEAD - Yunjr.ITEM_TYPE.ARMOR_MIN;
						break;
					case Yunjr.ITEM_TYPE.LEG:
						detail = Yunjr.ITEM_TYPE.LEG - Yunjr.ITEM_TYPE.ARMOR_MIN;
						break;
					case Yunjr.ITEM_TYPE.ORNAMENT:
						detail = Yunjr.ITEM_TYPE.ORNAMENT - Yunjr.ITEM_TYPE.ETC_MIN;
						break;
					default:
						detail = 0;
						break;
				}
				index = _index;
				name = _name;
				type = _type;
				annex = _annex;
			}
		}

		public static readonly _PropsStruct[] PROPS_LIST =
		{
			new _PropsStruct( 0, Yunjr.ITEM_TYPE.HEAD, "없음",  ""),
			new _PropsStruct( 0, Yunjr.ITEM_TYPE.LEG, "없음",  ""),
			new _PropsStruct( 0, Yunjr.ITEM_TYPE.ORNAMENT, "없음",  ""),

			new _PropsStruct( 1, Yunjr.ITEM_TYPE.HEAD, "두건", "ATT+1AC-1STR+1"),
			new _PropsStruct( 2, Yunjr.ITEM_TYPE.HEAD, "사냥 모자", ""),
			new _PropsStruct( 3, Yunjr.ITEM_TYPE.HEAD, "반쪽 가면", ""),
			new _PropsStruct( 4, Yunjr.ITEM_TYPE.HEAD, "중절모", ""),
			new _PropsStruct( 5, Yunjr.ITEM_TYPE.HEAD, "가죽캡", ""),
			new _PropsStruct( 6, Yunjr.ITEM_TYPE.HEAD, "가죽 투구", ""),
			new _PropsStruct( 7, Yunjr.ITEM_TYPE.HEAD, "멋쟁이 모자", ""),
			new _PropsStruct( 8, Yunjr.ITEM_TYPE.HEAD, "청동 투구", ""),
			new _PropsStruct( 9, Yunjr.ITEM_TYPE.HEAD, "판금 투구", ""),
			new _PropsStruct(10, Yunjr.ITEM_TYPE.HEAD, "황금 왕관", ""),

			new _PropsStruct( 1, Yunjr.ITEM_TYPE.LEG, "헝겊 신발", "INT-2"),
			new _PropsStruct( 2, Yunjr.ITEM_TYPE.LEG, "가죽 신발", ""),
			new _PropsStruct( 3, Yunjr.ITEM_TYPE.LEG, "망사 스타킹", ""),
			new _PropsStruct( 4, Yunjr.ITEM_TYPE.LEG, "날개 신발", ""),
			new _PropsStruct( 5, Yunjr.ITEM_TYPE.LEG, "미늘 부츠", ""),
			new _PropsStruct( 6, Yunjr.ITEM_TYPE.LEG, "다리6", ""),
			new _PropsStruct( 7, Yunjr.ITEM_TYPE.LEG, "다리7", ""),
			new _PropsStruct( 8, Yunjr.ITEM_TYPE.LEG, "다리8", ""),
			new _PropsStruct( 9, Yunjr.ITEM_TYPE.LEG, "다리9", ""),
			new _PropsStruct(10, Yunjr.ITEM_TYPE.LEG, "다리A", ""),

			new _PropsStruct( 1, Yunjr.ITEM_TYPE.ORNAMENT, "멋쟁이 혁띠", "STR+100"),
			new _PropsStruct( 2, Yunjr.ITEM_TYPE.ORNAMENT, "민무늬 반지", ""),
			new _PropsStruct( 3, Yunjr.ITEM_TYPE.ORNAMENT, "은 가락지", ""),
			new _PropsStruct( 4, Yunjr.ITEM_TYPE.ORNAMENT, "루비 목걸이", ""),
			new _PropsStruct( 5, Yunjr.ITEM_TYPE.ORNAMENT, "가짜 훈장", ""),
			new _PropsStruct( 6, Yunjr.ITEM_TYPE.ORNAMENT, "장식6", ""),
			new _PropsStruct( 7, Yunjr.ITEM_TYPE.ORNAMENT, "장식7", ""),
			new _PropsStruct( 8, Yunjr.ITEM_TYPE.ORNAMENT, "장식8", ""),
			new _PropsStruct( 9, Yunjr.ITEM_TYPE.ORNAMENT, "장식9", ""),
			new _PropsStruct(10, Yunjr.ITEM_TYPE.ORNAMENT, "장식A", "")
		};

		/* TODO: 소환수 기술에 대한 power 수치가 필요
				< 소환수들의 기술 >
				'화염','해일','폭풍','지진','이빨','촉수','창',
				'발톱','바위','화염검','동물의 뼈','번개 마법',
				'점토','강철 주먹','산성 가스','전광','독가스',
				'불꽃','염소 가스','한기','냉동 가스'
			*/


		public static void LoadItemList(out Dictionary<uint, Yunjr.Item> item_list)
		{
			item_list = new Dictionary<uint, Yunjr.Item>();

			foreach (_WeaponStruct i in WEAPON_LIST)
			{
				Weapon weapon = new Weapon();

				weapon.detail_id = i.detail;
				weapon.index_id = i.index;
				weapon.name = i.name;
				weapon.power = i.power;
				weapon.type = i.type;

				RegisterItem(ref item_list, weapon);
			}

			foreach (_ShieldStruct i in SHIELD_LIST)
			{
				Shield shield = new Shield();

				shield.detail_id = i.detail;
				shield.index_id = i.index;
				shield.name = i.name;
				shield.ac = i.ac;

				RegisterItem(ref item_list, shield);
			}

			foreach (_ArmorStruct i in ARMOR_LIST)
			{
				Armor armor = new Armor();

				armor.detail_id = i.detail;
				armor.index_id = i.index;
				armor.name = i.name;
				armor.ac = i.ac;

				RegisterItem(ref item_list, armor);
			}

			foreach (_PropsStruct i in PROPS_LIST)
			{
				Props props = new Props();

				props.detail_id = i.detail;
				props.index_id = i.index;
				props.name = i.name;
				props.type = i.type;
				props.annex = i.annex;

				RegisterItem(ref item_list, props);
			}
		}

		public static bool ConvertToAnnex(string input, ref double ref_atta_pow, ref double ref_ac, ref int[] ref_annex)
		{
			if (ref_annex.Length != (int)STATUS.MAX)
			{
				Debug.LogError("The length of parameter 'annex' is not STATUS.MAX");
				return false;
			}

			var reg_ex = new Regex(@"([A-Z_]+)([+-]?)(\d+)*");

			var match = reg_ex.Match(input);
			while (match.Success)
			{
				if (match.Groups.Count == 4)
				{
					string tag = match.Groups[1].Value;
					string sign = match.Groups[2].Value;
					int value = int.Parse(match.Groups[3].Value);
					value = (sign != "-") ? value : -value;

					switch (tag)
					{
						case "ATT":
							ref_atta_pow += value;
							break;
						case "AC":
							ref_ac += value;
							break;
						case "STR":
							ref_annex[(int)STATUS.STR] += value;
							break;
						case "INT":
							ref_annex[(int)STATUS.INT] += value;
							break;
						case "END":
							ref_annex[(int)STATUS.END] += value;
							break;
						case "CON":
							ref_annex[(int)STATUS.CON] += value;
							break;
						case "AGI":
							ref_annex[(int)STATUS.AGI] += value;
							break;
						case "RES":
							ref_annex[(int)STATUS.RES] += value;
							break;
						case "DEX":
							ref_annex[(int)STATUS.DEX] += value;
							break;
						case "LUC":
							ref_annex[(int)STATUS.LUC] += value;
							break;
						case "LEV":
							ref_annex[(int)STATUS.LEV] += value;
							break;
					}
				}
				else
				{
					Debug.LogError("Annex string error: " + input);
					break;
				}

				match = match.NextMatch();
			}

			return true;
		}
	}
}

namespace Yunjr
{
	// For test
	public class Brief
	{
		public string image_name;
		public string text;
	}

	public class Description
	{
		public ArrayList brief;
	}

	public abstract class ItemConv
	{
		public uint   detail_id = (uint)Yunjr.ITEM_TYPE.HIT;
		public uint   index_id = 0;
		public string name = "";

		public abstract Yunjr.Item AsItem();
		public abstract Yunjr.ResId CreateResId();
	}

	public class Weapon: ItemConv
	{
		public Yunjr.ITEM_TYPE type;
		public double  power;
		public int[]   data = new int[10];
		public Description description;

		public override Yunjr.Item AsItem()
		{
			Yunjr.Item item = new Yunjr.Item();

			item.res_id = this.CreateResId();
			item.name = this.name;
			item.param = Yunjr.ItemSub.GetDefault();
			item.param.atta_pow = this.power;
			item.param.item_type = this.type;
			item.annex = "";

			return item;
		}

		public override Yunjr.ResId CreateResId()
		{
			return Yunjr.ResId.CreateResId_Weapon(detail_id, index_id);
		}
	}

	public class Shield : ItemConv
	{
		public double ac;

		public override Yunjr.Item AsItem()
		{
			Yunjr.Item item = new Yunjr.Item();

			item.res_id = this.CreateResId();
			item.name = this.name;
			item.param = Yunjr.ItemSub.GetDefault();
			item.param.ac = this.ac;
			item.param.item_type = Yunjr.ITEM_TYPE.SHIELD; ;
			item.annex = "";

			return item;
		}

		public override Yunjr.ResId CreateResId()
		{
			return Yunjr.ResId.CreateResId_Shield(index_id);
		}
	}

	public class Armor: ItemConv
	{
		public double  ac;

		public override Yunjr.Item AsItem()
		{
			Yunjr.Item item = new Yunjr.Item();

			item.res_id = this.CreateResId();
			item.name = this.name;
			item.param = Yunjr.ItemSub.GetDefault();
			item.param.ac = this.ac;
			item.param.item_type = Yunjr.ITEM_TYPE.ARMOR;
			item.annex = "";

			return item;
		}

		public override Yunjr.ResId CreateResId()
		{
			return Yunjr.ResId.CreateResId_ArmorType(detail_id, index_id);
		}
	}

	public class Props : ItemConv
	{
		public Yunjr.ITEM_TYPE type;
		public string annex;

		public override Yunjr.Item AsItem()
		{
			Yunjr.Item item = new Yunjr.Item();

			item.res_id = this._CreateResId(type);
			item.name = this.name;
			item.param = Yunjr.ItemSub.GetDefault();
			item.param.item_type = type;
			item.annex = annex;

			return item;
		}

		public override Yunjr.ResId CreateResId()
		{
			return _CreateResId(type);
		}

		private Yunjr.ResId _CreateResId(Yunjr.ITEM_TYPE type)
		{
			switch (type)
			{
				case Yunjr.ITEM_TYPE.HEAD:
					return Yunjr.ResId.CreateResId_Head(index_id);
				case Yunjr.ITEM_TYPE.LEG:
					return Yunjr.ResId.CreateResId_Leg(index_id);
				case Yunjr.ITEM_TYPE.ORNAMENT:
					return Yunjr.ResId.CreateResId_Ornament(index_id);
				default:
					Debug.Assert(false);
					return new Yunjr.ResId();
			}
		}
	}
}
