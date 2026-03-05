using UnityEngine;
using System;
using System.IO;
using System.Collections.Generic;

namespace Yunjr
{
	public class GameStrRes
	{
		private static List<string> s_npc_names = new List<string>();

		public enum NPC_ID
		{
			MIN = 0,
			LEADING_ACTOR = MIN,
			LORD_AHN,
			YOUNGKI_AHN,
			RED_ANTARES,
			SPICA,
			ACRUX,
			BECRUX,
			NPC_FIRST_CLIENT1,
			NPC_FIRST_CLIENT2,
			NPC_FIRST_CLIENT3,
			MAX
		}

		private static void _RegisterNpcName()
		{
			if (s_npc_names.Count == 0)
			{
				s_npc_names.Add("머큐리");
				s_npc_names.Add("로드안");
				s_npc_names.Add("안영기");
				s_npc_names.Add("안타레스");
				s_npc_names.Add("스피카");
				s_npc_names.Add("아크룩스");
				s_npc_names.Add("베크룩스");
				s_npc_names.Add("티안키");
				s_npc_names.Add("마르카브");
				s_npc_names.Add("마루트");
			}
		}

		public static string GetNpcName(NPC_ID id)
		{
			_RegisterNpcName();

			if ((int)id >= (int)NPC_ID.MIN && (int)id < s_npc_names.Count)
				return s_npc_names[(int)id];
			else
				return "";
		}

		public static bool IsNpcName(string name)
		{
			_RegisterNpcName();

			return (s_npc_names.Find(x => (x == name)) != null);
		}

		// TODO: 왠만한 문자열 메시지는 GetMessageString(MESSAGE_ID id)를 이용하자
		public enum MESSAGE_ID
		{
			NOT_ENOUGH_SP,
			NOT_ENOUGH_GOLD,
			NOT_ENOUGH_GOLD_2,
			NOT_ENOUGH_ITEM,
			YOU_HAVE_NO_ITEMS,
			BACKPACK_IS_FULL,
			NO_RESERVED_SPACE,
			NOT_A_MAGIC_USER,
			AS_YOU_WISH,
			THANK_YOU_VERY_MUCH,
			MANUAL_MAGIC_TORCH,
			MANUAL_EYES_OF_BEHOLDER,
			MANUAL_LEVITATION,
			MANUAL_WALK_ON_WATER,
			MANUAL_WALK_ON_SWAMP,
			MANUAL_ETHEREALIZE,
			MANUAL_REST_HERE
		};

		public static string GetMessageString(MESSAGE_ID id, string target_name = "")
		{
			switch (id)
			{
				case MESSAGE_ID.NOT_ENOUGH_SP:
					return "마법 지수가 충분하지 않습니다.";
				case MESSAGE_ID.NOT_ENOUGH_GOLD:
					return "당신은 충분한 돈이 없습니다.";
				case MESSAGE_ID.NOT_ENOUGH_GOLD_2:
					return "당신은 돈이 부족합니다.";
				case MESSAGE_ID.NOT_ENOUGH_ITEM:
					return "아이템이 부족합니다.";
				case MESSAGE_ID.YOU_HAVE_NO_ITEMS:
					return "사용 가능한 아이템이 없습니다.";
				case MESSAGE_ID.BACKPACK_IS_FULL:
					return "백팩이 가득차 있습니다.";
				case MESSAGE_ID.NO_RESERVED_SPACE:
					return "이미 소환된 멤버가 있습니다.";
				case MESSAGE_ID.NOT_A_MAGIC_USER:
					return "마법 사용이 가능한 계열이 아닙니다.";
				case MESSAGE_ID.AS_YOU_WISH:
					return "당신이 바란다면 ...";
				case MESSAGE_ID.THANK_YOU_VERY_MUCH:
					return "매우 고맙습니다.";
				case MESSAGE_ID.MANUAL_MAGIC_TORCH:
					return "@A< 횃불 아이템을 사용하는 방법 >\n"
						+ "@@@2\n"
						+ "  아이템을 사용할 사람을 선택\n"
						+ "  ->'물건 사용' 버튼 누름\n"
						+ "  -> 대형 횃불 선택@@";
				case MESSAGE_ID.MANUAL_EYES_OF_BEHOLDER:
					return String.Format("@A< 주시자의 눈 마법을 사용하는 방법 >\n"
						+ "@@@2\n"
						+ "  마법을 사용할 사람을 선택\n"
						+ "  @@<color=#208030>('{0}' 선택)@@@2\n"
						+ "  ->'마법 사용' 버튼 누름\n"
						+ "  -> 변화 마법(하급) 선택\n"
						+ "  -> 주시자의 눈 선택@@"
						, target_name);
				case MESSAGE_ID.MANUAL_LEVITATION:
					return "@A< 공중 부양 마법을 사용하는 방법 >\n"
						+ "@@@2\n"
						+ "  마법을 사용할 사람을 선택\n"
						+ "  @@<color=#208030>(맵 화면의 오른쪽 영역)@@@2\n"
						+ "  ->'마법 사용' 버튼 누름\n"
						+ "  -> 변화 마법(하급) 선택\n"
						+ "  -> 공중 부양 선택@@";
				case MESSAGE_ID.MANUAL_WALK_ON_WATER:
					return String.Format("@A< 물 위를 걷는 마법을 사용하는 방법 >\n"
						+ "@@@2\n"
						+ "  마법을 사용할 사람을 선택\n"
						+ "  @@<color=#208030>('{0}' 선택)@@@2\n"
						+ "  ->'마법 사용' 버튼 누름\n"
						+ "  -> 변화 마법(하급) 선택\n"
						+ "  -> 물 위를 걸음 선택@@"
						, target_name);
				case MESSAGE_ID.MANUAL_WALK_ON_SWAMP:
					return String.Format("@A< 늪 위를 걷는 마법을 사용하는 방법 >\n"
						+ "@@@2\n"
						+ "  마법을 사용할 사람을 선택\n"
						+ "  @@<color=#208030>('{0}' 선택)@@@2\n"
						+ "  ->'마법 사용' 버튼 누름\n"
						+ "  -> 변화 마법(하급) 선택\n"
						+ "  -> 늪 위를 걸음 선택@@"
						, target_name);
				case MESSAGE_ID.MANUAL_ETHEREALIZE:
					return String.Format("@A< 기화 이동 마법을 사용하는 방법 >\n"
						+ "@@@2\n"
						+ "  마법을 사용할 사람을 선택\n"
						+ "  @@<color=#208030>('{0}' 선택)@@@2\n"
						+ "  ->'마법 사용' 버튼 누름\n"
						+ "  -> 변화 마법(상급) 선택\n"
						+ "  -> 기화 이동 선택@@"
						, target_name);
				case MESSAGE_ID.MANUAL_REST_HERE:
					return String.Format("@A< 휴식을 취하는 방법 >\n"
						+ "@@@2\n"
						+ "  아무나 선택\n"
						+ "  -> '여기서 쉰다' 선택\n"
						+ "  -> 쉴 시간을 선택@@\n"
						+ "\n"
						+ "  휴식을 취하면 회복을 하게 되며\n"
						+ "  그동안의 경험치도 정산합니다."
						, target_name);
				default:
					return "";
			}
		}

		private static readonly string[,] _MAGIC_NAME =
		{
			{
				"마법 화살",
				"마법 화구",
				"마법 단창",
				"독 바늘",
				"마법 발화",
				"냉동 광선",
				"춤추는 검",
				"맥동 광선",
				"직격 뇌전",
				"필멸 주문"
			},
			{
				"공기 폭풍",
				"열선 파동",
				"초음파",
				"유독 가스",
				"초냉기",
				"화염 지대",
				"브리자드",
				"에너지 장막",
				"인공 지진",
				"차원 이탈"
			}
		};

		public static int GetMaxMagicName(int detail)
		{
			if (detail >= 0 && detail < _MAGIC_NAME.GetLength(0))
				return _MAGIC_NAME.GetLength(1);
			else
				return 0;
		}

		public static string GetMagicName(int detail, int index)
		{
			Debug.Assert(_MAGIC_NAME.Rank == 2);

			if (detail >= 0 && detail < _MAGIC_NAME.GetLength(0) && index >= 0 && index < _MAGIC_NAME.GetLength(1))
				return _MAGIC_NAME[detail, index];
			else
				return "";
		}

		private static readonly string[] _ITEM_NAME =
		{
			"체력 회복약",
			"마법 회복약",
			"해독의 약초",
			"의식의 약초",
			"부활의 약초",
			"소환 문서",
			"대형 횃불",
			"수정 구슬",
			"비행 부츠",
			"이동 구슬"
		};

		public static int GetMaxItemName()
		{
			return _ITEM_NAME.GetLength(0);
		}

		public static string GetItemName(int index)
		{
			int len = _ITEM_NAME.GetLength(0);

			Debug.Assert((int)PARTY_ITEM.MAX == _ITEM_NAME.GetLength(0));

			if (index >= 0 && index < _ITEM_NAME.GetLength(0))
				return _ITEM_NAME[index];
			else
				return "";
		}

	}
}
