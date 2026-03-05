using UnityEngine;
using System;
using System.Collections;

namespace Yunjr
{
	public class Console
	{
		public static void Clear()
		{
			GameObj.text_dialog.text = "";
			GameObj.mini_map.gameObject.SetActive(false);
		}

		public static void SelectPlayer(string title, SelectionFromList.FnCallBack0 fn_callback)
		{
			GameRes.selection_list.Init();

			GameRes.selection_list.AddTitle((title != null) ? title : "");

			GameRes.selection_list.AddGuide("@A한 명을 고르시오 ---@@\n");
			for (int i = 0; i < GameRes.player.Length; i++)
				if (GameRes.player[i].Name != "")
					GameRes.selection_list.AddItem(GameRes.player[i].Name);

			GameRes.selection_list.Run(fn_callback);
		}

		public static string GetStringWordWrap(string sm_text)
		{
			string sm_s = "";

			int index = 0;
			while (index < sm_text.Length)
			{
				int length = LibUtil.SmTextIndexInWidth(sm_text.Substring(index), CONFIG.CONSOLE_CONTENTS_WIDTH, CONFIG.FONT_SIZE);
				sm_s += sm_text.Substring(index, length);
				sm_s += '\n';
				index += length;

				while (index < sm_text.Length && sm_text[index] == ' ')
					++index;
			}

			return sm_s;
		}

		public static void DisplaySmText(string sm_text, bool word_wrap)
		{
			if (word_wrap)
				GameObj.text_dialog.text = LibUtil.SmTextToRichText(GetStringWordWrap(sm_text));
			else
				GameObj.text_dialog.text = LibUtil.SmTextToRichText(sm_text);
		}

		public static void DisplayRichText(string rich_text)
		{
			GameObj.text_dialog.text = rich_text;
		}

		public static string GetCurrentTime()
		{
			/*
			 4.. 6: 새벽
			 6.. 8: 아침
			 8..12: 오전
			12..18: 오후
			18..20: 저녁
			18.. 4: 밤
			*/
			int time_zone = GameRes.party.core.hour;
			time_zone = (time_zone >= 4) ? time_zone : time_zone + 24;

			int hour = GameRes.party.core.hour;
			hour = (hour <= 12) ? hour : hour - 12;

			string time = "";

			if (time_zone < 6)
				time = "새벽";
			else if (time_zone < 8)
				time = "아침";
			else if (time_zone < 12)
				time = "오전";
			else if (time_zone < 18)
				time = "오후";
			else if (time_zone < 20)
				time = "저녁";
			else
				time = "  밤";

			time += String.Format(" {0}시{1,2:D2}분", hour, GameRes.party.core.min); 

			return time;
		}

		private static string _GetColoredGauge(int max, float progress)
		{
			if (max < 0)
				return "";

			int n_colored = 0;

			if (progress > 0.0f)
			{
				n_colored = max;

				for (int i = 1; i < max; i++)
				{
					if ((float)i / max > progress)
					{
						n_colored = i;
						break;
					}
				}
			}

			string result = "@F";

			if (n_colored < max)
			{
				for (int i = 0; i < n_colored; i++)
					result += "■";
				result += "@@@0";
				for (int i = n_colored; i < max; i++)
					result += "■";
			}
			else
			{
				for (int i = 0; i < max; i++)
					result += "■";
			}

			result += "@@";

			return result;
		}

		private static void _AddSpace(ref string s, int width)
		{
			Yunjr.LibUtil.SmTextAddSpace(ref s, width);
		}

		private static void _AddSpaceCenterAlign(ref string s, int width)
		{
			int len = Yunjr.LibUtil.SmTextExtent(s);

			if (len >= width)
				return;

			int padding = (width - len);
			int padding_left = padding / 2;

			s = s.PadLeft(s.Length + padding_left, ' ');
			s = s.PadRight(s.Length + (padding - padding_left), ' ');
		}

		public static void DisplayPartyStatus()
		{
			object[] party_status_1_args = new object[]
			{
				GameRes.party.pos.x, GameRes.party.pos.y,
				GameRes.party.food,
				GameRes.party.gold,
				GameRes.party.arrow,
				_GetColoredGauge(3, (float)GameRes.party.core.magic_torch / 5.0f),
				_GetColoredGauge(3, (float)GameRes.party.core.levitation / 255.0f),
				_GetColoredGauge(3, (float)GameRes.party.core.walk_on_water / 255.0f),
				_GetColoredGauge(3, (float)GameRes.party.core.walk_on_swamp / 255.0f),
				_GetColoredGauge(3, (float)GameRes.party.core.mind_control / 3.0f),
			};

			string party_status_1 = String.Format(
				"@F" + GetCurrentTime() + "@@" +
				"\n@A현재 위치 [{0}, {1}]@@" +
				"\n" +
				"\n남은 황금 = {3}" +
				"\n남은 식량 = {2,-6}  남은 화살 = {4,-6}" +
				"\n" +
				"\n마법 횃불 [{5}]  공중 부상 [{6}]" +
				"\n물위 걸음 [{7}]  늪위 걸음 [{8}]" +
				"\n독심술    [{9}]",
				party_status_1_args
			);

			GameObj.text_dialog.text = LibUtil.SmTextToRichText(party_status_1);
		}

		public static void DisplayPartyItems()
		{
			// TODO2: 모든 Crystal과 Relic을 표시할 수 있어야 한다.

			string party_status_2_1 = String.Format(
				  "체력 회복약 = {0,-5}  소환 문서 = {5,-5}" +
				"\n마법 회복약 = {1,-5}  대형 횃불 = {6,-5}" +
				"\n해독의 약초 = {2,-5}  수정 구슬 = {7,-5}" +
				"\n의식의 약초 = {3,-5}  비행 부츠 = {8,-5}" +
				"\n부활의 약초 = {4,-5}  이동 구슬 = {9,-5}" +
				"\n",
				GameRes.party.core.item[(int)PARTY_ITEM.POTION_HEAL],
				GameRes.party.core.item[(int)PARTY_ITEM.POTION_MANA],
				GameRes.party.core.item[(int)PARTY_ITEM.HERB_DETOX],
				GameRes.party.core.item[(int)PARTY_ITEM.HERB_JOLT],
				GameRes.party.core.item[(int)PARTY_ITEM.HERB_RESURRECTION],
				GameRes.party.core.item[(int)PARTY_ITEM.SCROLL_SUMMON],
				GameRes.party.core.item[(int)PARTY_ITEM.BIG_TORCH],
				GameRes.party.core.item[(int)PARTY_ITEM.CRYSTAL_BALL],
				GameRes.party.core.item[(int)PARTY_ITEM.WINGED_BOOTS],
				GameRes.party.core.item[(int)PARTY_ITEM.TELEPORT_BALL]
			);

			string party_status_2_2 = String.Format(
				"\n화염의크리스탈: {0,-4}  소환의크리스탈: {1,-4}" +
				"\n한파의크리스탈: {2,-4}  에너지크리스탈: {3,-4}" +
				"\n다크  크리스탈: {4,-4}  황금방패의조각: {5,-4}",
				GameRes.party.core.crystal[(int)PARTY_CRYSTAL.PYRO_CRYSTAL],
				GameRes.party.core.crystal[(int)PARTY_CRYSTAL.SUMMON_CRYSTAL],
				GameRes.party.core.crystal[(int)PARTY_CRYSTAL.FROZEN_CRYSTAL],
				GameRes.party.core.crystal[(int)PARTY_CRYSTAL.ENERGY_CRYSTAL],
				GameRes.party.core.crystal[(int)PARTY_CRYSTAL.DARK_CRYSTAL],
				GameRes.party.core.relic[(int)PARTY_RELIC.SHARD_OF_GOLD]
			);

			GameObj.text_dialog.text = LibUtil.SmTextToRichText(party_status_2_1 + party_status_2_2);
		}

		public static void DisplayPartyAllStatus()
		{
			DisplayPartyStatus();

			GameObj.SetButtonGroup(BUTTON_GROUP.RIGHT_CANCEL);
			GameRes.GameState = GAME_STATE.IN_WAITING_FOR_OK_CANCEL;

			GameRes._fn_ok_pressed = delegate ()
			{
				DisplayPartyItems();

				GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
				GameRes.GameState = GAME_STATE.IN_MOVING;
			};

			GameRes._fn_cancel_pressed = delegate ()
			{
				GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
				GameRes.GameState = GAME_STATE.IN_MOVING;
			};
		}

		private static readonly uint[][] SKILL_TYPES_FOR_CLASS_TYPE = new uint[(int)CLASS_TYPE.MAX][]
		{
			new uint[] // CLASS_TYPE.PHYSICAL_FORCE
			{
				(1 << 16) | (uint)SKILL_TYPE.WIELD,
				(2 << 16) | (uint)SKILL_TYPE.CHOP,
				(3 << 16) | (uint)SKILL_TYPE.STAB,
				(4 << 16) | (uint)SKILL_TYPE.HIT,
				(5 << 16) | (uint)SKILL_TYPE.SHOOT,
				(6 << 16) | (uint)SKILL_TYPE.SHIELD
			},
			new uint[] // CLASS_TYPE.MAGIC_USER
			{
				(1 << 16) | (uint)SKILL_TYPE.HIT,
				(3 << 16) | (uint)SKILL_TYPE.DAMAGE,
				(4 << 16) | (uint)SKILL_TYPE.ENVIRONMENT,
				(5 << 16) | (uint)SKILL_TYPE.CURE,
				(6 << 16) | (uint)SKILL_TYPE.SUMMON,
				(7 << 16) | (uint)SKILL_TYPE.SPECIAL,
				(8 << 16) | (uint)SKILL_TYPE.ESP
			},
			new uint[] // CLASS_TYPE.HYBRID1
			{
				(1 << 16) | (uint)SKILL_TYPE.WIELD,
				(2 << 16) | (uint)SKILL_TYPE.CHOP,
				(3 << 16) | (uint)SKILL_TYPE.STAB,
				(4 << 16) | (uint)SKILL_TYPE.HIT,
				(5 << 16) | (uint)SKILL_TYPE.SHOOT,
				(6 << 16) | (uint)SKILL_TYPE.SHIELD,
				(8 << 16) | (uint)SKILL_TYPE.CURE
			},
			new uint[] // CLASS_TYPE.HYBRID2
			{
				(1 << 16) | (uint)SKILL_TYPE.WIELD,
				(2 << 16) | (uint)SKILL_TYPE.CHOP,
				(3 << 16) | (uint)SKILL_TYPE.STAB,
				(4 << 16) | (uint)SKILL_TYPE.HIT,
				(5 << 16) | (uint)SKILL_TYPE.SHOOT,
				(7 << 16) | (uint)SKILL_TYPE.SUMMON,
				(8 << 16) | (uint)SKILL_TYPE.SPECIAL
			},
			new uint[] // CLASS_TYPE.HYBRID3
			{
				(1 << 16) | (uint)SKILL_TYPE.WIELD,
				(2 << 16) | (uint)SKILL_TYPE.CHOP,
				(3 << 16) | (uint)SKILL_TYPE.STAB,
				(4 << 16) | (uint)SKILL_TYPE.HIT,
				(5 << 16) | (uint)SKILL_TYPE.SHOOT,
				(6 << 16) | (uint)SKILL_TYPE.SHIELD,
				(8 << 16) | (uint)SKILL_TYPE.ESP
			}
		};

		private static string _GetPlayerStatus(ObjPlayer player)
		{
			const string STR_NA = "  ";
			const string STR_UP = "@A▲@@";
			const string STR_DN = "@C▼@@";

			CLASS clazz = player.clazz;
			CLASS_TYPE class_type = Yunjr.LibUtil.GetClassType(clazz);

			string[] UP_DOWN = new string[(int)STATUS.MAX];
			for (int ix_status = 0; ix_status < (int)STATUS.MAX; ix_status++)
			{
				if (player.status[ix_status] > player.intrinsic_status[ix_status])
					UP_DOWN[ix_status] = STR_UP;
				else if (player.status[ix_status] < player.intrinsic_status[ix_status])
					UP_DOWN[ix_status] = STR_DN;
				else
					UP_DOWN[ix_status] = STR_NA;
			}

			string[] player_status = new string[9]
			{
				"@F# 능력치           # 기술치@@",
				String.Format("@3체  력: {0,-4}{1:1}     @@", player.status[(uint)STATUS.STR], UP_DOWN[(uint)STATUS.STR]),
				String.Format("@3정신력: {0,-4}{1:1}     @@", player.status[(uint)STATUS.INT], UP_DOWN[(uint)STATUS.INT]),
				String.Format("@3집중력: {0,-4}{1:1}     @@", player.status[(uint)STATUS.CON], UP_DOWN[(uint)STATUS.CON]),
				String.Format("@3인내력: {0,-4}{1:1}     @@", player.status[(uint)STATUS.END], UP_DOWN[(uint)STATUS.END]),
				String.Format("@3저항력: {0,-4}{1:1}     @@", player.status[(uint)STATUS.RES], UP_DOWN[(uint)STATUS.RES]),
				String.Format("@3민첩성: {0,-4}{1:1}     @@", player.status[(uint)STATUS.AGI], UP_DOWN[(uint)STATUS.AGI]),
				String.Format("@3정확성: {0,-4}{1:1}     @@", player.status[(uint)STATUS.DEX], UP_DOWN[(uint)STATUS.DEX]),
				String.Format("@3행  운: {0,-4}{1:1}     @@", player.status[(uint)STATUS.LUC], UP_DOWN[(uint)STATUS.LUC])
			};

			foreach (uint skill_type_bits in SKILL_TYPES_FOR_CLASS_TYPE[(int)class_type])
			{
				int index = (int)((skill_type_bits >> 16) & 0xFFFF);
				SKILL_TYPE skill_type = (SKILL_TYPE)(skill_type_bits & 0xFFFF);

				string format;
				format = LibUtil.GetAssignedString(skill_type);
				LibUtil.SmTextAddSpace(ref format, 10);
				format = "{1}" + format + ": {0}@@";

				player_status[index] += String.Format(format, player.skill[(uint)skill_type], (ObjPlayer.GetMaxValueOfSkill(clazz, SKILL_TYPE.SPECIAL) > 0) ? "@3" : "<color=#003A3A>");
			}

			string result = "";

			foreach(string line in player_status)
				result += line + "\n";

			return result;
		}

		public static void DisplayPlayerInfo(int index)
		{
			if ((index < 0 || index >= GameRes.player.Length) || GameRes.player[index].Name == "")
				return;

			GameRes.player[index].Apply();

			string sub_name = "# 이름 : " + GameRes.player[index].Name;
			string sub_gender = "# 성별 : " + LibUtil.GetAssignedString(GameRes.player[index].gender);
			string sub_class = "# 계급 : " + LibUtil.GetAssignedString(GameRes.player[index].clazz);

			_AddSpace(ref sub_name, 20);
			_AddSpace(ref sub_gender, 20);
			_AddSpace(ref sub_class, 20);

			const string STR_NA = "<color=#303030>(없음)</color>";

			Equiped equiped;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.HAND];
			string equip_hands = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.HAND_SUB];
			if (equiped != null && equiped.IsValid())
				equip_hands += " + " + equiped.name.GetName();

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.ARMOR];
			string equip_body = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.HEAD];
			string equip_head = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.LEG];
			string equip_leg = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.ETC];
			string equip_etc = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA;

			string s =
				"@B{0}@@@3## 레  벨 : {1}@@@B" +
				"\n{2}@@@3## 경험치@@@B" +
				"\n{3}@@@3[{4}]@@" +
				"\n@2" +
				"\n양 손 - {5}" +
				"\n몸 통 - {6}" +
				"\n머 리 - {7}" +
				"\n다 리 - {8}" +
				"\n장 식 - {9}" + "@@";

			s = String.Format(s,
				sub_name, GameRes.player[index].status[(uint)STATUS.LEV],
				sub_gender,
				sub_class, GameRes.player[index].GetExpGauge(),
				equip_hands,
				equip_body,
				equip_head,
				equip_leg,
				equip_etc
			);

			GameObj.text_dialog.text = LibUtil.SmTextToRichText(s);
		}

		public static void DisplayPlayerStatus(int index)
		{
			if ((index < 0 || index >= GameRes.player.Length) || GameRes.player[index].Name == "")
				return;

			Console.DisplayPlayerInfo(index);

			string party_status = _GetPlayerStatus(GameRes.player[index]);
			GameObj.text_dialog.text = LibUtil.SmTextToRichText(party_status);
		}

		public static void DisplayPlayer(int index, bool verbose)
		{
			if ((index < 0 || index >= GameRes.player.Length) || GameRes.player[index].Name == "")
				return;

			Console.DisplayPlayerInfo(index);

			// 간략하게 볼 때는 여기서 끝
			if (!verbose)
				return;

			GameObj.SetButtonGroup(BUTTON_GROUP.RIGHT_CANCEL);
			GameRes.GameState = GAME_STATE.IN_WAITING_FOR_OK_CANCEL;

			GameRes._fn_ok_pressed = delegate ()
			{
				Console.DisplayPlayerStatus(index);

				GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
				GameRes.GameState = GAME_STATE.IN_MOVING;
			};

			GameRes._fn_cancel_pressed = delegate ()
			{
				GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
				GameRes.GameState = GAME_STATE.IN_MOVING;
			};
		}

		public static void DisplayQuickView()
		{
			const string COLOR_ON = "@C";
			const string COLOR_OFF = "@0";

			byte identifing_degree = GameRes.GetIdentifingDegreeOfCurrentMap();

			string title = String.Format("@F[{0}]@@@7[{1},{2}]@@", GameRes.map_script.GetPlaceName(identifing_degree), GameRes.party.pos.x, GameRes.party.pos.y);
			string time = "@F" + GetCurrentTime() + "@@";

			_AddSpace(ref title, CONFIG.GUI_CONSOLE_WIDTH - Yunjr.LibUtil.SmTextExtent(time) - 1);
			title += time;

			string text =
				title +
				"\n\n" +
				"@B#    이  름  | HP | SP | 독 |의식|죽음|@@\n";

			for (int i = 0; i < GameRes.player.Length; i++)
			{
				string s = "";

				if (GameRes.player[i].IsValid())
				{
					string name = GameRes.player[i].GetName();
					_AddSpaceCenterAlign(ref name, 12);

					s = String.Format("@7{0}@@ @3{1}@@", i + 1, name);
					_AddSpace(ref s, 22);

					int max_hp = GameRes.player[i].GetMaxHP();
					int max_sp = GameRes.player[i].GetMaxSP();

					int ratio_hp = (max_hp > 0) ? GameRes.player[i].hp * 100 / max_hp : 0;
					int ratio_sp = (max_sp > 0) ? GameRes.player[i].sp * 100 / max_sp : 0;

					ratio_hp = Math.Min(Math.Max(ratio_hp, 0), 100);
					ratio_sp = Math.Min(Math.Max(ratio_sp, 0), 100);

					s += String.Format("@7{0,3}% {1,3}%@@  ", ratio_hp, ratio_sp);

					bool poisoned = (GameRes.player[i].poison > 0);
					bool unconscious = (GameRes.player[i].unconscious > 0);
					bool dead = (GameRes.player[i].dead > 0);
					s += String.Format("{0}■@@   {1}■@@   {2}■@@\n"
						, (poisoned) ? COLOR_ON : COLOR_OFF
						, (unconscious) ? COLOR_ON : COLOR_OFF
						, (dead) ? COLOR_ON : COLOR_OFF
					);
				}
				else
				{
					s = String.Format("@8{0}    (없음)@@\n", i + 1);
				}

				text += s;
			}

			GameObj.text_dialog.text = LibUtil.SmTextToRichText(text);
		}

		public static void UseItem(ObjPlayer player)
		{
			if (!(player.IsValid() && player.IsAvailable()))
			{
				ObjNameBase name = player.GetGenderName();
				Console.DisplaySmText(name.GetName(ObjNameBase.JOSA.SUB) + " 물건을 사용할 수 있는 상태가 아닙니다.", true);
				return;
			}

			GameRes.selection_list.Init(1, true);
			GameRes.selection_list.AddGuide("사용할 물품을 고르시오.\n");

			int num_valid_items = 0;
			for (int i = 0; i < GameRes.party.core.item.Length; i++)
			{
				if (GameRes.party.core.item[i] > 0)
				{
					Debug.Assert(i >=0 && i < GameStrRes.GetMaxItemName());
					
					GameRes.selection_list.AddItem(GameStrRes.GetItemName(i), i + 1);

					++num_valid_items;
				}
			}

			if (num_valid_items == 0)
			{
				Console.DisplaySmText(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.YOU_HAVE_NO_ITEMS), true);
				return;
			}

			GameRes.selection_list.Run
			(
				delegate ()
				{
					string result = "";

					int index = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);

					--index;

					switch (index)
					{
						case 0: // PARTY_ITEM.POTION_HEAL
							result = GameRes.party.Use_PotionHeal(player, player);
							break;
						case 1: // PARTY_ITEM.POTION_MANA
							result = GameRes.party.Use_PotionMana(player, player);
							break;
						case 2: // PARTY_ITEM.HERB_DETOX
							result = GameRes.party.Use_HerbDetox(player, player);
							break;
						case 3: // PARTY_ITEM.HERB_JOLT
						case 4: // PARTY_ITEM.HERB_RESURRECTION
							Console.SelectPlayer
							(
								null,
								delegate ()
								{
									Debug.Assert(GameRes.selection_list.ix_curr > 0);

									int ix_player = GameRes.selection_list.ix_curr - 1;
									ObjPlayer target = GameRes.player[ix_player];

									switch (index)
									{
										case 3: // PARTY_ITEM.HERB_JOLT
											result = GameRes.party.Use_HerbJolt(player, target);
											break;
										case 4: // PARTY_ITEM.HERB_RESURRECTION
											result = GameRes.party.Use_HerbResurrection(player, target);
											break;
									}
								}
							);
							break;
						case 5: // PARTY_ITEM.SCROLL_SUMMON
							{
								int ix_reserved = GameRes.GetIndexOfResevedPlayer();

								if (GameRes.player[ix_reserved].IsValid())
									result = GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NO_RESERVED_SPACE);
								else
									result = GameRes.party.Use_ScrollSummon(player);
							}
							break;
						case 6: // PARTY_ITEM.BIG_TORCH
							result = GameRes.party.Use_BigTorch(player);
							break;
						case 7: // PARTY_ITEM.CRYSTAL_BALL
							result = GameRes.party.Use_CrystalBall(player);
							break;
						case 8: // PARTY_ITEM.WINGED_BOOTS
							result = GameRes.party.Use_WingedBoots(player);
							break;
						case 9: // PARTY_ITEM.TELEPORT_BALL
							result = GameRes.party.Use_TeleportBall(player);
							break;
					}

					if (result.Length > 0)
						Console.DisplaySmText(result, true);

					if (index >= 0 && index < (int)PARTY_ITEM.MAX)
					{
						ObjNameBase item_name = new ObjNameBase();
						item_name.SetName(GameStrRes.GetItemName(index));
						
						GameObj.SetHeaderText(String.Format("{0} 이제 {1}개 남았습니다.", item_name.GetName(ObjNameBase.JOSA.SUB), GameRes.party.core.item[index]));
					}

					GameObj.UpdatePlayerStatus();
				}
			);
		}

		public static void UseItem()
		{
			Console.SelectPlayer(
				null,
				delegate ()
				{
					Debug.Assert(GameRes.selection_list.ix_curr > 0);

					int ix_player = GameRes.selection_list.ix_curr - 1;
					if (ix_player < 0 || ix_player >= GameRes.player.Length)
					{
						Console.DisplaySmText(String.Format("@CPlayer index({0}) is out of range@@", ix_player), false);
						return;
					}

					Console.UseItem(GameRes.player[ix_player]);
				}
			);
		}

		public static void UseAbility(ObjPlayer player)
		{
			if (!(player.IsValid() && player.IsAvailable()))
			{
				ObjNameBase name = player.GetGenderName();
				Console.DisplaySmText(name.GetName(ObjNameBase.JOSA.SUB) + " 마법을 사용할 수 있는 상태가 아닙니다.", true);
				return;
			}

			if (player.GetMaxSP() == 0)
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 마법을 사용할 수 없는 계열입니다.", true);
				return;
			}

			int cure_spell_level = player.skill[(int)SKILL_TYPE.CURE] / 10;
			int phenomina_spell_level = player.skill[(int)SKILL_TYPE.ENVIRONMENT] / 10;
			int esp_level = player.skill[(int)SKILL_TYPE.ESP] / 10;

			bool can_use_phenomina_spell_low  = (phenomina_spell_level > 0) || ((player.specially_allowed_magic & 0x001F) > 0);
			bool can_use_phenomina_spell_high = (phenomina_spell_level > 5) || ((player.specially_allowed_magic & 0x03E0) > 0);

			GameRes.selection_list.Init();
			GameRes.selection_list.AddGuide("사용할 마법의 종류 ===>\n");
			if (cure_spell_level > 0)
				GameRes.selection_list.AddItem("치료 마법 (개인)", 1);
			if (cure_spell_level > 5)
				GameRes.selection_list.AddItem("치료 마법 (전체)", 2);
			if (can_use_phenomina_spell_low)
				GameRes.selection_list.AddItem("변화 마법 (하급)", 3);
			if (can_use_phenomina_spell_high)
				GameRes.selection_list.AddItem("변화 마법 (상급)", 4);
			if (esp_level > 0)
				GameRes.selection_list.AddItem("초능력", 5);

			if (GameRes.selection_list.GetNumOfItems() <= 0)
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 사용 가능한 마법이 없습니다.", true);
				return;
			}

			GameRes.selection_list.Run
			(
				delegate ()
				{
					int index = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);
					switch (index)
					{
						case 1:
							GameRes.party.UseCureSpell(player, true);
							break;
						case 2:
							GameRes.party.UseCureSpell(player, false);
							break;
						case 3:
							GameRes.party.UsePhenominaSpell(player, true);
							break;
						case 4:
							GameRes.party.UsePhenominaSpell(player, false);
							break;
						case 5:
							GameRes.party.UseEsp(player);
							break;
					}
				}
			);
		}

		public static void UseAbility()
		{
			SelectPlayer(
				null,
				delegate ()
				{
					Debug.Assert(GameRes.selection_list.ix_curr > 0);

					int ix_player = GameRes.selection_list.ix_curr - 1;
					if (ix_player < 0 || ix_player >= GameRes.player.Length)
					{
						Console.DisplaySmText(String.Format("@CPlayer index({0}) is out of range@@", ix_player), false);
						return;
					}

					Console.UseAbility(GameRes.player[ix_player]);
				}
			);
		}

		public static void RestHere(int hour)
		{
			GameRes.party.core.rest_time = hour;

			string text = "";
			int num_line_feed = 0;
			foreach (var player in GameRes.player)
			{
				if (player.IsValid())
				{
					//text += "@F" + player.GetName(ObjNameBase.JOSA.SUB) + " 모든 건강이 회복되었다@@\n";
					string name = player.GetName();
					string name_s = player.GetName(ObjNameBase.JOSA.SUB);
					string line = "";
					if (GameRes.party.core.food <= 0)
					{
						line = "@4일행은 식량이 바닥났다@@";
					}
					else if (player.dead > 0)
					{
						line = "@7" + name_s + " 죽었다@@";
					}
					else if (player.unconscious > 0 && player.poison == 0)
					{
						player.unconscious -= player.status[(int)STATUS.LEV] * (GameRes.party.core.rest_time / 2);
						if (player.unconscious <= 0)
						{
							line = "@F" + name_s + " 의식이 회복되었다@@";
							player.unconscious = 0;
							player.hp = (player.hp > 0) ? player.hp : 1;
							GameRes.party.core.food--;
						}
						else
						{
							line = "@F" + name_s + " 여전히 의식 불명이다@@";
						}
					}
					else if (player.unconscious > 0 && player.poison > 0)
					{
						line = "@7독 때문에, " + name + "의 의식은 여전히 없다@@";
					}
					else if (player.poison > 0)
					{
						line = "@7독 때문에, " + name_s + " 회복되지 않았다@@";
					}
					else
					{
						int add = player.status[(int)STATUS.LEV] * GameRes.party.core.rest_time;

						/* 원작의 코드인데, 새 버전에서는 반영하지 않아야 할 것 같음
						if hp >= (endurance * level * 10) then
							if party.food < 255 then
								inc(party.food);
						*/

						player.hp += add;

						if (player.hp >= player.GetMaxHP())
						{
							player.hp = player.GetMaxHP();
							line = "@F" + name_s + " 모든 건강이 회복되었다@@";
						}
						else
						{
							line = "@F" + name_s + " 치료되었다@@";
						}

						GameRes.party.core.food--;
					}

					text += line + "\n";
					++num_line_feed;
				}
			}

			// Torch 감소
			if (GameRes.party.core.magic_torch > 0)
			{
				int reduce = GameRes.party.core.rest_time / 3 + 1;
				reduce = Math.Min(GameRes.party.core.magic_torch, reduce);
				GameRes.party.core.magic_torch -= reduce;
			}

			// 나머지 마법 효과는 모두 제거
			GameRes.party.core.levitation = 0;
			GameRes.party.core.walk_on_water = 0;
			GameRes.party.core.walk_on_swamp = 0;
			GameRes.party.core.mind_control = 0;

			// 모든 파티원의 SP 회복
			foreach (var player in GameRes.player)
				if (player.IsValid())
					player.sp = player.GetMaxSP();

			// 레벨업 확인
			string text_level_up = "";
			{
				foreach (var player in GameRes.player)
				{
					if (player.IsValid())
					{
						int prev_level = player.status[(int)STATUS.LEV];
						int curr_level = prev_level;

						while (player.accumulated_exprience >= ObjPlayer.GetRequiredExp(curr_level + 1))
							++curr_level;

						if (curr_level > prev_level)
						{
							player.intrinsic_status[(int)STATUS.LEV] = curr_level;
							player.Apply();
							text_level_up += String.Format("@B{0}의 레벨은 {1} 입니다@@\n", player.GetName(), curr_level);
						}
					}
				}

				// Press Any Key 출력
				if (text_level_up != "")
				{
					for (; num_line_feed < 8; ++num_line_feed)
						text += '\n';

					// 원래는 --> "@E아무키나 누르십시오 ...@@"
					text += "@E레벨이 올라간 멤버가 있습니다.@@";
				}
			}

			Console.DisplaySmText(text, false);
			GameObj.UpdatePlayerStatus();
			GameRes.party.PassTime(GameRes.party.core.rest_time, 0, 0);

			if (text_level_up != "")
			{
				GameObj.SetButtonGroup(BUTTON_GROUP.OK);
				GameRes.GameState = GAME_STATE.IN_WAITING_FOR_OK_CANCEL;

				GameRes._fn_ok_pressed = delegate ()
				{
					Console.DisplaySmText(text_level_up, true);
					GameObj.UpdatePlayerStatus();

					GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
					GameRes.GameState = GAME_STATE.IN_MOVING;
				};

				GameRes._fn_cancel_pressed = null;
			}
		}

		public static void RestHere()
		{
			string inquiry_format = " @F##@@@A{0,3}@@@F 시간 동안@@\n";

			GameRes.selection_spin.Init();
			GameRes.selection_spin.AddTitle("@B일행이 여기서 쉴 시간을 지정 하십시오.@@");
			GameRes.selection_spin.AddContents(String.Format(inquiry_format, GameRes.party.core.rest_time));
			GameRes.selection_spin.Run
			(
				delegate () // just selected
				{
					RestHere(GameRes.party.core.rest_time);
				},
				delegate () // up
				{
					if (GameRes.party.core.rest_time < 24)
					{
						GameRes.party.core.rest_time++;
						GameRes.selection_spin.AddContents(String.Format(inquiry_format, GameRes.party.core.rest_time));
					}
				},
				delegate () // down
				{
					if (GameRes.party.core.rest_time > 1)
					{
						GameRes.party.core.rest_time--;
						GameRes.selection_spin.AddContents(String.Format(inquiry_format, GameRes.party.core.rest_time));
					}
				}
			);
		}
	}
}
