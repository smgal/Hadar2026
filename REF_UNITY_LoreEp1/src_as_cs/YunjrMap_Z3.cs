
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인
/*
 */
namespace Yunjr
{
	public class YunjrMap_Z3 : YunjrMap
	{
		const int POST_EVENT = 0x10000;

		readonly string NPC_1_NAME = GameStrRes.GetNpcName(GameStrRes.NPC_ID.NPC_FIRST_CLIENT1); // Anunitum
		readonly string NPC_2_NAME = GameStrRes.GetNpcName(GameStrRes.NPC_ID.NPC_FIRST_CLIENT2); // Revathi
		readonly int NPC_1_SPRITE_IX = 138;
		readonly int NPC_2_SPRITE_IX = 137;

		readonly Pos<int> EVENT_POS_1_NPC_1 = Pos<int>.Create(32, 58);
		readonly Pos<int> EVENT_POS_1_NPC_2 = Pos<int>.Create(31, 58);

		readonly Pos<int> EVENT_POS_2_NPC_1 = Pos<int>.Create(28, 59);
		readonly Pos<int> EVENT_POS_2_NPC_2 = Pos<int>.Create(29, 59);

		readonly Pos<int> EVENT_WARP_UPSTAIRS = Pos<int>.Create(54, 51);
		readonly Pos<int> EVENT_WARP_DOWNSTAIRS = Pos<int>.Create(31, 60);
		readonly Pos<int> EVENT_WARP_3RD_ROOM = Pos<int>.Create(28, 57);

		private enum FLAG
		{
			MONOLOG_1ST = 1,
			MONOLOG_2ND = 2,
			MONOLOG_3RD = 3,
			DIALOG_1ST = 4,
			ASSITANT_STEPPED_BACK = 5,
			UNLOCK_FIRST_DOOR = 6,
			MAKE_PARTY = 7,
			EQUIP_BASIC_ARMOR = 8,
			PICK_DOOR_KEY_HEXAGON = 9,
			MONOLOG_AFTER_LEVITATION = 10,
			TALK_ABOUT_LEVITATION = 11,
			TALK_ABOUT_WALK_ON_WATER = 12,
			TALK_ABOUT_WALK_ON_SWAMP = 13,
			CHECK_NORTH_DOOR = 14,
			BREAK_MAGIC_POWER_SOURCE = 15,
			GET_BIG_TORCH = 16,
			GET_TRIVIAL_LOOT = 17,
			FIND_RARE_LOOT = 18,
			TALK_WITH_CLIENT2_IN_3RD_ROOM = 19,
			UNLOCK_3RD_ROOM_SOUTH_DOOR = 20,
			UNLOCK_LAST_DOOR = 21,
			OPEN_DOWN_STAIRS = 22,
			TALK_TO_CLIENTS_BEFORE_GOING_DOWN = 23,
			TITLE_OF_COWARD = 24,
			TITLE_OF_POOP_MAN = 25,
			GET_RARE_LOOT = 26,
			UNLOCK_SECOND_DOOR = 27,
			GO_DOWN_TO_NEXT_FLOOR = 28,
			RESTORE_MAGIC_POWER_SOURCE = 29,
			TALK_ABOUT_PENETRATION = 30,
			TALK_ABOUT_LORE_CASTLE_TREASURE = 31,
			MAX
		}

		private enum VARIABLE
		{
			// 우회로 앞의 통과 회수를 기록
			NUM_PASS_CRACKED_WALL = 0,
			// 0: 미진행
			// 1: 문 앞에서 십자 석판 홈을 확인
			// 2: 우회로로 진입
			// 3: 문열기 성공
			// 4: 동력이 끊긴 상태
			ROOM_3RD = 1,
			// 0: 미진행
			// 1: 왼쪽의 바람을 느낌
			// 2: 통과 후 대화 마침
			TALK_ABOUT_HIDDEN_WAY = 2,
		}

		//////////////////////////////////////////////////////////////////////////////

		private const int IX_FLAG_BASE = 100;
		private const int IX_VARIABLE_BASE = 10;

		private void _SetLocalFlag(FLAG index)
		{
			Flag_Set(IX_FLAG_BASE + (int)index);
			_DoActionByFlag(index);
		}

		private bool _IsLocalFlagSet(FLAG index)
		{
			return Flag_IsSet(IX_FLAG_BASE + (int)index);
		}

		private void _IncLocalVariable(VARIABLE index)
		{
			Variable_Add(IX_VARIABLE_BASE + (int)index);
		}

		private void _SetLocalVariable(VARIABLE index, byte val)
		{
			Variable_Set(IX_VARIABLE_BASE + (int)index, val);
		}

		private byte _GetLocalVariable(VARIABLE index)
		{
			return Variable_Get(IX_VARIABLE_BASE + (int)index);
		}

		private void _DoActionByFlag(FLAG ix_flag)
		{
			switch (ix_flag)
			{
				case FLAG.EQUIP_BASIC_ARMOR:
					{
						int event_x = 34;
						int event_y = 12;
						this.MapEx_ClearObj(event_x, event_y);
						this.MapEx_ChangeObj1(event_x, event_y, 88, false);
					}
					break;

				case FLAG.PICK_DOOR_KEY_HEXAGON:
					{
						int event_x = 34;
						int event_y = 12;
						this.MapEx_ClearObj(event_x, event_y);
					}
					break;

				case FLAG.UNLOCK_FIRST_DOOR:
					{
						int event_x = 29;
						int event_y = 14;

						this.MapEx_ChangeTile(event_x, event_y, 14);

						GameRes.map_data.data[event_x, event_y - 1].ix_event = EVENT_BIT.TYPE_EVENT | 98;
						GameRes.map_data.data[event_x, event_y - 1].act_type = ACT_TYPE.DEFAULT;
					}
					break;

				case FLAG.UNLOCK_SECOND_DOOR:
					{
						int event_x = 47;
						int event_y = 27;
						this.MapEx_ChangeTile(event_x, event_y, 14);
					}
					break;

				case FLAG.BREAK_MAGIC_POWER_SOURCE:
					LibMapEx.FillMapWithShadow(ref GameRes.map_data);

					GameRes.map_data.data[20, 59].act_type = ACT_TYPE.MOVE;
					GameRes.map_data.data[21, 59].act_type = ACT_TYPE.MOVE;
					GameRes.map_data.data[20, 61].act_type = ACT_TYPE.MOVE;
					GameRes.map_data.data[21, 61].act_type = ACT_TYPE.MOVE;

					this.MapEx_ClearObj(29, 60);

					break;

				case FLAG.UNLOCK_3RD_ROOM_SOUTH_DOOR:
					{
						int event_x = 29;
						int event_y = 60;
						this.MapEx_ChangeTile(event_x, event_y, 14);
					}
					break;

				case FLAG.UNLOCK_LAST_DOOR:
					{
						int event_x = 27;
						int event_y = 30;
						this.MapEx_ChangeTile(event_x, event_y, 14);
					}
					break;

				case FLAG.OPEN_DOWN_STAIRS:
					MapEx_ChangeTile(26, 27, 17);
					MapEx_ChangeTile(27, 26, 17);
					MapEx_ChangeTile(27, 27, 17);

					MapEx_ChangeTile(27, 27, 87);
					MapEx_ChangeTile(28, 26, 83);
					MapEx_ChangeTile(28, 27, 83);
					break;

				case FLAG.RESTORE_MAGIC_POWER_SOURCE:
					LibMapEx.FillMapWithLight(ref GameRes.map_data);
					break;

				case FLAG.TALK_ABOUT_PENETRATION:
					MapEx_ClearEvent(47, 29); // 현재 위치
					MapEx_ClearEvent(45, 29);
					break;

				default:
					break;
			}
		}

		private string _GetNpcBrief(GameStrRes.NPC_ID id, bool know_name, int variation = 0)
		{
			string name = GameStrRes.GetNpcName(id);

			switch (id)
			{
				case GameStrRes.NPC_ID.NPC_FIRST_CLIENT1:
					if (know_name)
						if (variation == 1)
							return name + "\n생각보다는 능력있는 마법사 일지도...";
						else
							return name + "\n대단한 마법사는 아닌 것 같다.";
					else
						return "의뢰인\n마법사 차림을 하고 있다.";

				case GameStrRes.NPC_ID.NPC_FIRST_CLIENT2:
					if (know_name)
						if (variation == 1)
							return name + "\n힘을 쓰는 일을 위해 동행한 듯 하다.";
						else
							return name + "\n우락부락해 보이지만 착한 듯.";
					else
						return "또 다른 의뢰인\n근육이 있어 보이는 남자다.";
			}

			return "";
		}

		private void _RejoinClientsToParty()
		{
			Debug.Assert(!GameRes.player[1].IsValid());
			Debug.Assert(!GameRes.player[2].IsValid());
			{
				ObjPlayer player = GameRes.retired.Find(x => x.GetName() == NPC_1_NAME);
				Debug.Assert(player != null);
				GameRes.player[1] = player;
				GameRes.retired.Remove(player);
			}
			{
				ObjPlayer player = GameRes.retired.Find(x => x.GetName() == NPC_2_NAME);
				Debug.Assert(player != null);
				GameRes.player[2] = player;
				GameRes.retired.Remove(player);
			}

			GameObj.UpdatePlayerStatus();
		}

		private void _LeaveClientsFromParty()
		{
			Debug.Assert(GameRes.player[1].IsValid());
			Debug.Assert(GameRes.player[2].IsValid());

			Debug.Assert(GameRes.retired.Count <= 1);

			GameRes.retired.Add(GameRes.player[1]);
			GameRes.retired.Add(GameRes.player[2]);

			GameRes.player[1] = new ObjPlayer();
			GameRes.player[2] = new ObjPlayer();

			GameObj.UpdatePlayerStatus();
		}

		private void _ClearProlog()
		{
			int ix_var = 0;
			byte result_of_prolog = 0;
			{
				Debug.Assert(Variable_Get(ix_var) == result_of_prolog);

				// 0x000: 프롤로그 진행 결과
				if (_IsLocalFlagSet(FLAG.TITLE_OF_COWARD))
					result_of_prolog = 1;
				else if (_IsLocalFlagSet(FLAG.TITLE_OF_POOP_MAN))
					result_of_prolog = 2;
				else
					result_of_prolog = 3;
			}

			// 0x000: 청금석의 원석을 발견하였다.
			// 0x001: 청금석의 원석을 가지고 탈출하였다.
			bool behavior_0 = _IsLocalFlagSet(FLAG.FIND_RARE_LOOT);
			bool behavior_1 = _IsLocalFlagSet(FLAG.GET_RARE_LOOT);

			// 전체 플래그 클리어
			GameRes.flag.Clear();
			GameRes.variable.Clear();

			// 결과 기록
			Variable_Set(ix_var, result_of_prolog);
			if (behavior_0)
				Flag_Set(0);
			if (behavior_1)
				Flag_Set(1);

			Talk("");
			Talk("");
			Talk("@A        프롤로그가 종료되었습니다.@@");
			Talk("");
			Talk("@A     이제 자신의 캐릭터를 생성합니다.@@");

			RegisterKeyPressedAction(delegate ()
			{
				GameObj.ScreenFadeOut(delegate ()
				{
					GameRes.GameOverCondition = GAMEOVER_CONDITION.PROLOG_CLEARED;

				});

			}); PressAnyKey();
		}

		//////////////////////////////////////////////////////////////////////////////

		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "의뢰 장소";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.DEN);
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			GameRes.party.core.gameover_condition = (int)GAMEOVER_COND.ANY_MEMBERS_DEFEATED;

			if (prev_map == "Map002")
			{
				GameRes.party.Warp(21, 6);
				GameRes.party.SetDirection(0, 1);
			}
			else if (prev_map == "Prolog_B2")
			{
				int event_x = 54;
				int event_y = 31;

				GameRes.party.Warp(event_x, event_y);
				GameRes.party.SetDirection(-1, 0);

				event_x = 47;
				event_y = 29;

				GameRes.map_data.data[event_x, event_y].ix_event = EVENT_BIT.TYPE_EVENT | 90;
				GameRes.map_data.data[event_x, event_y].act_type = ACT_TYPE.DEFAULT;

				event_x = 51;
				event_y = 31;

				GameRes.map_data.data[event_x, event_y].ix_event = EVENT_BIT.TYPE_EVENT | 88;
				GameRes.map_data.data[event_x, event_y].act_type = ACT_TYPE.DEFAULT;

				GameRes.map_script.AddHandicap(HANDICAP.WIZARD_EYE);
			}
			else
			{
				GameRes.party.Warp(21, 6);
				GameRes.party.SetDirection(0, 1);
			}

			for (int ix_flag = 0; ix_flag < (int)FLAG.MAX; ++ix_flag)
				if (_IsLocalFlagSet((FLAG)ix_flag))
					_DoActionByFlag((FLAG)ix_flag);

		}

		public override void OnUnload()
		{
		}

		public override bool OnEvent(int event_id, out int post_event_id)
		{
			return _OnEvent(true, event_id, out post_event_id);
		}

		public override void OnPostEvent(int event_id, out int post_event_id)
		{
			_OnEvent(false, event_id, out post_event_id);
		}

		public bool OnEnterById(int event_id)
		{
			bool processing_completed = true;

			switch (event_id)
			{
				case 1:
					if (_IsLocalFlagSet(FLAG.TITLE_OF_COWARD) || _IsLocalFlagSet(FLAG.TITLE_OF_POOP_MAN))
					{
						Talk("이곳은 밖으로 나가는 곳이다. 여기가 아니라 @B청금석의 원석@@이 있는 곳으로 가야 한다.");
					}
					else
					{
						if (!this._IsLocalFlagSet(FLAG.DIALOG_1ST))
						{
							Talk("이곳은 방금 내가 들어 왔던 곳이다. 여기서 발을 돌릴 생각이었다면 애시당초 여기까지 오지도 않았다.");
						}
						else
						{
							if (GameRes.player[1].IsAvailable())
							{
								Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
								Talk("");
								Talk("@F우리가 가야 하는 곳은 이쪽이 아니오. 빨리 아래층으로 내려갈 방도를 찾아야 하오.@@");
							}
							else if (GameRes.player[2].IsAvailable())
							{
								Talk(GameRes.player[2].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
								Talk("");
								Talk("@F우리가 가야 하는 곳은 이쪽이 아닙니다. 빨리 아래층으로 내려갈 방도를 찾아야 합니다.@@");
							}
							else
							{
								Talk("이왕 일을 시작했으니 빨리 끝내는 것이 좋을 것 같다. 이쪽에서 머뭇거릴 시간은 없다.");
							}
						}
					}

					break;

				case 2:
					if (_IsLocalFlagSet(FLAG.TITLE_OF_COWARD) || _IsLocalFlagSet(FLAG.TITLE_OF_POOP_MAN))
					{
						Talk("여기로 내려가면 그들과 마주칠 수 있다. 그래서 여기로 내려가는 것은 좋은 선택이 아니다.");
					}
					else
					{
						Select_Init();

						Select_AddTitle("여기로 내려가면 다시 올라올 수는 없다고 한다.");
						Select_AddGuide("당신의 선택은 ---");
						Select_AddItem("문제 없다. 내려가자");
						Select_AddItem("조금 더 주위를 더 살펴 보자");

						Select_Run(delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									_SetLocalFlag(FLAG.GO_DOWN_TO_NEXT_FLOOR);
									GameRes.party.core.item[(int)PARTY_ITEM.CRYSTAL_BALL] += 3;
									GameRes.LoadMapEx("Prolog_B2");
									break;
								case 2:
									Talk("당신은 조금 더 주위를 살펴 보기로 하였다.");
									break;
								default:
									Talk("당신은 망설였다.");
									break;
							}
						});
					}
					break;

				case 3:
					Talk("여기로 다시 내려가는 것은 좋은 선택이 아니다.");
					break;

				default:
					Talk(String.Format("OnEnterById({0})", event_id));
					processing_completed = false;
					break;
			}

			if (!processing_completed)
			{
				TalkDesc talk_desc;

				if (!GameRes.map_data.enters.TryGetValue(event_id, out talk_desc))
				{
					Debug.Assert(false);
					return false;
				}
			}

			return false;
		}

		public override bool OnEnter(int event_id)
		{
			if (event_id > 0)
			{
				return OnEnterById(event_id);
			}

			return false;
		}

		public void OnSignById(int event_id)
		{
			TalkDesc talk_desc;

			if (!GameRes.map_data.signs.TryGetValue(event_id, out talk_desc))
			{
				Debug.Assert(false);
				return;
			}

			for (int i = 0; i < talk_desc.dialog.Count; i++)
				Talk(talk_desc.dialog[i]);
		}

		public override void OnSign(int event_id)
		{
			if (event_id > 0)
			{
				OnSignById(event_id);
				return;
			}

			Talk("푯말에는 이곳의 지도가 있었다.");

			RegisterKeyPressedAction(delegate ()
			{
				GameRes.party.Cast_EyesOfBeholder(null);
			}); PressAnyKey();

		}

		public void OnTalkById(int event_id)
		{
			bool processing_completed = true;

			switch (event_id)
			{
				case 1:
					GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT1, false)), 5);

					if (!this._IsLocalFlagSet(FLAG.DIALOG_1ST))
					{
						Talk("@F어서오시게. 당신이 그 유명한 @B머큐리@@이시군요.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F뒤가 조용한 것을 보니 아무에게도 안 들키고 잘 들어 오셨구려. 역시 소문대로의 실력이시오.@@");
							Talk("");
							Talk("@F잠입을 위해 몸을 가볍게 하고 오셨으니, 미리 말씀 드린대로 장비는 저희 쪽에서 준비했소이다.@@");

							RegisterKeyPressedAction(delegate ()
							{
								Talk("@F그런데 그전에 하나의 문제가 있소. 일단 이 아래의 문을 열고 앞으로 진행해야 하는데 우리는 여기서 길이 막혔다오.@@");
								Talk("");
								Talk("@F우리가 당신의 도움을 필요로 하는 부분은 @B함정에 대한 지식@@과 @B잠긴 문@@을 여는 기술 때문이라오. 당신의 활약을 보고 싶구려.@@");

								this._SetLocalFlag(FLAG.DIALOG_1ST);
								this._DoActionByFlag(FLAG.DIALOG_1ST);
							}); PressAnyKey();

						}); PressAnyKey();
					}
					else
					{
						Talk("@F아래쪽의 문을 열고 앞으로 진행해야 하는데 우리는 여기서 길이 막혔다오.@@");
						Talk("");
						Talk("@F이제 당신이 활약 할 차례요.@@");
					}
					break;

				case 2:
					GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT2, false)), 5);

					if (!this._IsLocalFlagSet(FLAG.DIALOG_1ST))
					{
						processing_completed = false;
					}
					else if (!this._IsLocalFlagSet(FLAG.ASSITANT_STEPPED_BACK))
					{
						MapUnit map_unit_1 = GameRes.map_data.data[_curr_x, _curr_y];
						MapUnit map_unit_2 = GameRes.map_data.data[_curr_x + 1, _curr_y];

						map_unit_2.ix_obj1 = map_unit_1.ix_obj1;
						map_unit_2.ix_event = map_unit_1.ix_event;
						map_unit_2.act_type = map_unit_1.act_type;

						map_unit_1.ix_obj1 = 0;
						map_unit_1.ix_event = EVENT_BIT.TYPE_EVENT | 99;
						map_unit_1.act_type = ACT_TYPE.DEFAULT;

						GameRes.map_data.data[_curr_x, _curr_y] = map_unit_1;
						GameRes.map_data.data[_curr_x + 1, _curr_y] = map_unit_2;

						this._SetLocalFlag(FLAG.ASSITANT_STEPPED_BACK);
					}
					else
					{
						Talk("@F제가 힘은 좀 쓰는 편인데, 아무리 힘을 써 봐도 문은 안 열리네요.@@");
					}

					break;

				default:
					processing_completed = false;
					break;
			}

			if (!processing_completed)
			{
				TalkDesc talk_desc;

				if (!GameRes.map_data.talks.TryGetValue(event_id, out talk_desc))
				{
					Debug.Assert(false);
					return;
				}

				GameObj.SetHeaderText(LibUtil.SmTextToRichText(talk_desc.note), 5);

				for (int i = 0; i < talk_desc.dialog.Count; i++)
					Talk(talk_desc.dialog[i]);
			}

		}

		public override void OnTalk(int event_id)
		{
			if (event_id > 0)
			{
				OnTalkById(event_id);
				return;
			}

			// 3번 방 앞 <NPC_1_NAME>
			if (On(EVENT_POS_1_NPC_1.x, EVENT_POS_1_NPC_1.y))
			{
				GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT1, true, 0)), 5);

				Talk("@F출입 권한에 따라 다른 모양의 석판이 필요한가 보오.@@");
			}
			// 3번 방 앞 <NPC_2_NAME>
			if (On(EVENT_POS_1_NPC_2.x, EVENT_POS_1_NPC_2.y))
			{
				GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT2, true, 0)), 5);

				Talk("@F이건 안쪽에서 문을 잠근 형태이고, 바깥쪽에서는 십자 모양의 석판을 열쇠로 사용하는 듯 합니다.@@");
			}

			// 3번 방 안 <NPC_1_NAME>
			if (On(EVENT_POS_2_NPC_1.x, EVENT_POS_2_NPC_1.y))
			{
				if (_IsLocalFlagSet(FLAG.GET_BIG_TORCH) && !_IsLocalFlagSet(FLAG.TALK_ABOUT_LORE_CASTLE_TREASURE))
				{
					Talk("@F지하에 이런 방이 있다니 만든 용도가 참으로 궁금하구려. 이 방을 보니 갑자기 생각이 났는데 당신은 혹시 @B로어성의 보물@@에 대해서 들은 적이 있소?@@");

					RegisterKeyPressedAction(delegate ()
					{
						Talk("@F로어성의 무기고는 경비가 삼엄하기로 유명한데, 거기는 무기고이기 이전에 로어성의 보물을 숨겨둔 보물 창고이기도 하오.@@");
						Talk("");
						Talk("@F아마도 대부분의 사람들은 무기고이기에 경비가 심한 것으로 알고 있을 것이라 의심을 피하기도 딱 좋은 곳이라오.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F무기고의 지하에 있는 보물 창고에는, 로어성의 선조때부터 쌓아온 로어성의 부가 축적된 곳이라 할 수 있소.@@");
							Talk("");
							Talk("@F소문에 의하면 그 중의 한 방은 금화로 가득 찬 방인데, 쌓인 금화에 자꾸 발이 빠지는 바람에 제대로 걸을 수도 없었다고들 하오.@@");

							RegisterKeyPressedAction(delegate ()
							{
								Talk("@F원래는 고대의 용들이 모아 놓은 보물이었는데 로어성의 선대 왕인 @B레드 안타레스@@가 용을 물리치고 가져 온 것들이라 들었소.@@");
								Talk("");
								Talk("@F그런데 현재 로어성의 성주인 @B로드안@@은 아시다시피 그렇게 재물에 욕심을 두고 있지는 않은 사람이라오. 그래서 그것들이 그냥 그대로 방치가 되어 있다고 들었소.@@");

								RegisterKeyPressedAction(delegate ()
								{
									Talk("@F그게 그대로 거기에 쌓여 있는 것은 안타까운 일이긴 하나 @B로드안@@이 로어성을 통치하는 이상은 그것들이 햇빛을 받을 일은 없을 것 같소.@@");

									RegisterKeyPressedAction(delegate ()
									{
										Talk("로어성의 무기고 지하에 보물이 있을 것이라는 소문은 이전에도 들은 적은 있다. 하지만 이번 이야기는 아주 구체적이고 뭔가가 맞아 떨어진다.");
										Talk("");
										Talk("이 일이 끝나면 로어성에나 한 번 들러봐야 할 것 같다.");
									}); PressAnyKey();

								}); PressAnyKey();

							}); PressAnyKey();

						}); PressAnyKey();

					}); PressAnyKey();

					/*

					  

					 */

					_SetLocalFlag(FLAG.TALK_ABOUT_LORE_CASTLE_TREASURE);
				}
				else if (_IsLocalFlagSet(FLAG.BREAK_MAGIC_POWER_SOURCE))
				{
					GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT1, true, 1)), 5);
					Talk("@F마법으로 사용되는 동력의 맥을 끊긴 했지만 우리도 좀 불편하구려.@@");
					if (!_IsLocalFlagSet(FLAG.GET_BIG_TORCH))
					{
						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F혹시나 해서 @B대형 횃불@@을 몇 개 들고 왔는데, 지금 사용하면 될 것 같소. 꽤나 주위를 밝게 만들어 줄 것이오.@@");
							Talk("");
							Talk("@A[대형 횃불 +5]@@");

							GameRes.party.core.item[(int)PARTY_ITEM.BIG_TORCH] += 5;

							_SetLocalFlag(FLAG.GET_BIG_TORCH);

							RegisterKeyPressedAction(delegate ()
							{
								Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_MAGIC_TORCH));

							}); PressAnyKey();

						}); PressAnyKey();
					}
				}
				else
				{
					GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT1, true, 0)), 5);
					Talk("@F지금 마법으로 사용되는 동력의 맥을 끊으려 하오.@@");
				}
			}
			// 3번 방 안 <NPC_2_NAME>
			if (On(EVENT_POS_2_NPC_2.x, EVENT_POS_2_NPC_2.y))
			{
				GameObj.SetHeaderText(LibUtil.SmTextToRichText(_GetNpcBrief(GameStrRes.NPC_ID.NPC_FIRST_CLIENT2, true, 1)), 5);

				if (_IsLocalFlagSet(FLAG.BREAK_MAGIC_POWER_SOURCE))
				{
					if (_IsLocalFlagSet(FLAG.TALK_WITH_CLIENT2_IN_3RD_ROOM) && _IsLocalFlagSet(FLAG.TALK_ABOUT_LORE_CASTLE_TREASURE))
					{
						Talk("@F다 같이 밀면 바로 열릴 것 같네요. 같이 도와 주십시오.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Select_Init();

							Select_AddTitle("모두 같이 바위 문을 밀려한다.");
							Select_AddGuide("당신의 선택은 ---");
							Select_AddItem("일행과 함께 바위 문을 민다");
							Select_AddItem("잠깐 혼자할 일이 남아 있다");

							Select_Run(delegate (int selected)
							{
								switch (selected)
								{
									case 1:
										// 일행이 합류하고 문을 염
										_RejoinClientsToParty();

										MapEx_ClearObj(EVENT_POS_2_NPC_2.x, EVENT_POS_2_NPC_2.y);
										MapEx_ClearObj(EVENT_POS_2_NPC_1.x, EVENT_POS_2_NPC_1.y);

										Talk("의뢰인들은 다시 나와 합류를 하였다.");

										_SetLocalVariable(VARIABLE.ROOM_3RD, 5);

										RegisterKeyPressedAction(delegate ()
										{
											// 아래로 한 칸
											GameRes.party.Move(0, 1);
											// 문을 미는 이벤트
											GameRes.PostEventId = 94;
										}); PressAnyKey();

										break;
									default:
										Talk("이 문이 열리면 의뢰인과 바로 동행을 해야 하니, 좀 더 주위를 살펴 보고 가야겠다.");
										break;
								}
							});

						}); PressAnyKey();

					}
					else
					{
						Talk("@F조금씩 바위 문이 밀려 나고 있습니다. 조금만 더 하면 될 것 같습니다.@@");

						// 대형 횃불을 받은 뒤에야 문을 염
						if (_IsLocalFlagSet(FLAG.GET_BIG_TORCH))
							_SetLocalFlag(FLAG.TALK_WITH_CLIENT2_IN_3RD_ROOM);
					}
				}
				else
				{
					Talk("@F문 주위의 마법만 없어지면 바로 제가 힘으로 문을 밀어 버리려 합니다.@@");
				}
			}

			if (OnArea(999, 999, 1001, 1001))
			{
			}
		}

		private bool _OnEvent(bool is_not_post, int event_id, out int post_event_id)
		{
			bool you_can_move_to_there = true;

			post_event_id = 0;
			bool processing_completed = true;

			event_id += (is_not_post) ? 0 : POST_EVENT;

			switch (event_id)
			{
				case 100:
					if (!_IsLocalFlagSet(FLAG.MONOLOG_1ST))
					{
						Talk("나의 이름은 @B머큐리@@이다.");
						Talk("");
						Talk("이쪽 계통을 아는 사람들에게는 많이 알려진 실력이 검증된 @B도둑@@이다. 이번에 누군가가 나에게 부탁을 하여 이 동굴에 잠입을 하게 되었는데 조금만 더 안쪽으로 들어가면 그들을 만날 수 있을 것이다.");
						_SetLocalFlag(FLAG.MONOLOG_1ST);
					}
					break;

				case 99:
					if (!_IsLocalFlagSet(FLAG.UNLOCK_FIRST_DOOR))
						post_event_id = event_id;
					break;
				case (POST_EVENT | 99):
					if (true)
					{
						GameRes.party.SetDirection(0, 1);
						Talk("살펴보니 이 문은 반대쪽에서 물리적으로 잠겨 있는 일반 문이다. 어떻게든 반대편으로 넘어갈 수 있다면 문을 열 수 있을 것 같다.");

						_SetLocalFlag(FLAG.MONOLOG_3RD);
					}
					break;

				case 98:
					if (!_IsLocalFlagSet(FLAG.MAKE_PARTY))
						post_event_id = event_id;
					break;
				case (POST_EVENT | 98):
					Talk("@F역시 소문대로요.@@");
					Talk("");
					Talk("@F상당히 머리가 좋으시구려.@@");

					RegisterKeyPressedAction(delegate ()
					{
						Talk("@F이 동굴의 아래층 어디에는 미리 들어간 우리의 동료가 구조 요청을 보내고 있소.@@");
						Talk("");
						Talk("@F그가 어떤 불의의 사고를 당했는지는 모르겠으나 생명이 상당히 위협 받는 수준인 것 같소.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F그나마 간간히 수신되던 구조 신호마저도 지금은 끊긴 상황이오. 서둘러야 하오.@@");

							RegisterKeyPressedAction(delegate ()
							{
								Talk("@F우리가 가져온 장비들이 옆에 준비되어 있으니 그걸 사용하면 되오.@@");
								Talk("");
								Talk("@F이제는 우리도 같이 동행하겠소.@@");

								RegisterKeyPressedAction(delegate ()
								{
									int index = 1;
									if (!GameRes.player[index].IsValid())
									{
										GameRes.player[index] = ObjPlayer.CreateCharacter(NPC_1_NAME, GENDER.MALE, CLASS.PALADIN, 5);
										// 물위걸음, 늪위걸음
										GameRes.player[index].specially_allowed_magic = 0x00000018;

										GameRes.player[index].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.STAB, 1));
										GameRes.player[index].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(1));
										GameRes.player[index].SetEquipment(Yunjr.EQUIP.HEAD, Yunjr.ResId.CreateResId_Head(1));
										GameRes.player[index].SetEquipment(Yunjr.EQUIP.LEG, Yunjr.ResId.CreateResId_Leg(1));
									}

									index = 2;
									if (!GameRes.player[index].IsValid())
									{
										GameRes.player[index] = ObjPlayer.CreateCharacter(NPC_2_NAME, GENDER.MALE, CLASS.SWORDMAN, 4);

										GameRes.player[index].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.STAB, 3));
										GameRes.player[index].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(2));
										GameRes.player[index].SetEquipment(Yunjr.EQUIP.LEG, Yunjr.ResId.CreateResId_Leg(2));
									}

									GameObj.UpdatePlayerStatus();

									int event_x = _curr_x;
									int event_y = _curr_y;

									for (int dy = -1; dy <= 1; dy++)
										for (int dx = -1; dx <= 1; dx++)
										{
											if ((GameRes.map_data.data[event_x + dx, event_y + dy].ix_event & EVENT_BIT.MASK_OF_TYPE) == EVENT_BIT.TYPE_TALK)
											{
												MapEx_ClearObj(event_x + dx, event_y + dy);
												MapEx_ClearEvent(event_x + dx, event_y + dy);
											}
										}

									_SetLocalFlag(FLAG.MAKE_PARTY);

								}); PressAnyKey();

							}); PressAnyKey();

						}); PressAnyKey();

					}); PressAnyKey();
					break;

				case 97:
					Talk("벽에는 뭔가가 쓰여 있지만 우리가 아는 언어는 아니다.");
					break;

				case 1:
					if (!_IsLocalFlagSet(FLAG.MONOLOG_2ND))
					{
						Talk("바로 앞에 있는 사람들이 나의 의뢰인인 것 같다.");
						Talk("");
						Talk("마법사 차림의 중년 남성과 가벼운 무장을 한 근육질의 젊은 남자가 있다.");

						PressAnyKey();

						_SetLocalFlag(FLAG.MONOLOG_2ND);
					}
					break;

				case 2:
					if (_IsLocalFlagSet(FLAG.MONOLOG_3RD) && !_IsLocalFlagSet(FLAG.UNLOCK_FIRST_DOOR))
						post_event_id = event_id;
					break;
				case (POST_EVENT | 2):
					GameRes.party.SetDirection(-1, 0);

					Talk("여기가 바위로 함몰되긴 했지만 뒤쪽은 원래 일반 통로인 것 같다. 옷이 더렵혀지긴 하겠지만 한 명 정도는 통과할 수 있는 틈은 만들어질 것 같다. 다만 전부 다 갈 필요는 없고 나만 저쪽으로 넘어가서 길이 어디까지 나 있는지 확인해 보면 될 것 같다.");

					RegisterKeyPressedAction(delegate ()
					{
						Select_Init();

						Select_AddTitle("무너진 바위를 헤집고 들어가 보려 한다.");
						Select_AddGuide("당신의 선택은 ---");
						Select_AddItem("틈을 비집고 건너편으로 간다");
						Select_AddItem("좀 더 근처를 조사해 보겠다");

						Select_Run(delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									GameRes.party.WarpRel(-2, 0);
									Talk("당신은 반대편으로 넘어 왔다.");
									break;
								case 2:
									Talk("그래, 주위를 좀 더 살핀 뒤에도 늦지 않다.");
									break;
								default:
									Talk("당신은 조금 더 생각해 보기로 했다.");
									break;
							}
						});
					}); PressAnyKey();
					break;

				case 3:
					if (!_IsLocalFlagSet(FLAG.UNLOCK_FIRST_DOOR))
						post_event_id = event_id;
					else if (_IsLocalFlagSet(FLAG.MAKE_PARTY) && !_IsLocalFlagSet(FLAG.EQUIP_BASIC_ARMOR))
					{
						int ix_player = GameRes.GetIndexOfSpeaker(new int[] { 1, 2 });
						if (ix_player >= 0)
						{
							Talk(GameRes.player[ix_player].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
							Talk("");
							if (ix_player == 1)
								Talk("@F이쪽으로 바로 내려가는 것보다는 아까 그 방에서 장비를 갖추고 가는 것이 어떻겠소?@@");
							else
								Talk("@F이쪽으로 바로 내려가는 것보다는 아까 그 방에서 장비를 갖추고 가는 것이 어떻겠습니까?@@");
						}
					}
					break;
				case (POST_EVENT | 3):
					Talk("아까 막혀 있던 벽의 뒷쪽이다.");
					Talk("");
					Talk("이 벽은 항상 안쪽에서만 문을 열어 줄 수 있도록 설계가 되어 있다.");

					RegisterKeyPressedAction(delegate ()
					{
						_SetLocalFlag(FLAG.UNLOCK_FIRST_DOOR);

						Talk("약간의 힘을 주자 길을 막던 바위 문이 열렸다.");

					}); PressAnyKey();
					break;

				case 4:
					if (!_IsLocalFlagSet(FLAG.UNLOCK_LAST_DOOR))
						post_event_id = event_id;
					break;
				case (POST_EVENT | 4):
					GameRes.party.SetDirection(0, 1);
					Talk("앞쪽에는 움직일 것 같아 보이는 벽이 있다.");
					Talk("하지만 적어도 이쪽에서는 움직일 방도가 없어 보인다.");
					break;

				case 5:
					if (!_IsLocalFlagSet(FLAG.UNLOCK_LAST_DOOR))
						post_event_id = event_id;
					break;
				case (POST_EVENT | 5):
					GameRes.party.SetDirection(0, 1);
					Talk("앞쪽에는 움직일 것 같아 보이는 벽이 있다.");
					Talk("벽틈으로 보이는 빛을 보면, 거기에 어떤 큰 공간이 있는 것처럼 보인다.");
					break;

				case 6:
					if (!_IsLocalFlagSet(FLAG.EQUIP_BASIC_ARMOR))
					{
						Talk("여기에는 가벼운 장비들이 몇 개 놓여 있다.");
						Talk("");
						Talk("이번은 전투가 목적이 아니라 잠입이 목적이기에 몸을 지키기 위한 최소한의 장비만 선택하기로 하였다.");

						RegisterKeyPressedAction(delegate ()
						{
							GameRes.player[0].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 2));
							GameRes.player[0].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(1));

							Equiped equiped_1 = GameRes.player[0].equip[(uint)Yunjr.EQUIP.HAND];
							Equiped equiped_2 = GameRes.player[0].equip[(uint)Yunjr.EQUIP.ARMOR];

							Talk(String.Format("@A[{0} +1]@@", (equiped_1 != null && equiped_1.IsValid()) ? equiped_1.name.GetName() : "???"));
							Talk(String.Format("@A[{0} +1]@@", (equiped_2 != null && equiped_2.IsValid()) ? equiped_2.name.GetName() : "???"));

							_SetLocalFlag(FLAG.EQUIP_BASIC_ARMOR);

						}); PressAnyKey();
					}
					else if (!_IsLocalFlagSet(FLAG.PICK_DOOR_KEY_HEXAGON))
					{
						Talk("아까 장비를 놓았던 그 바닥에 열쇠로 쓰일 법한 육각형 석판이 놓여 있다.");
						Talk("");
						Talk("아무래도 장비를 가져 올 때 딸려 온 것 같다. 내가 가진 이 장비의 출처 자체가 의심스럽긴 하지만 일단 넘어가자.");
						Talk("");
						Talk("@A[육각형 석판 + 1]@@");

						_SetLocalFlag(FLAG.PICK_DOOR_KEY_HEXAGON);
						GameEventMain.ResetArrowKey();
					}
					else
					{
						Talk("별 다르게 눈에 띄는 것은 없다.");
					}
					break;

				case 7:
					{
						int event_x = _curr_x - 1;
						int event_y = _curr_y;

						ACT_TYPE act_type = GameRes.map_data.GetActType(event_x, event_y);
						if (act_type != ACT_TYPE.MOVE)
						{
							Talk("문은 마법의 힘으로 굳게 닫혀져 있다. 그리고 중앙에는 잠금을 해제하기 위한 석판을 끼울 자리가 육각형으로 나 있다.");

							if (_IsLocalFlagSet(FLAG.PICK_DOOR_KEY_HEXAGON))
							{
								RegisterKeyPressedAction(delegate ()
								{
									Talk("당신은 조심스럽게 석판을 육각 홈에 끼우고 약간을 힘을 주어 문을 밀자, 꿈쩍도 안 할 것 같던 문이 쉽게 밀려 나갔다.");

									_SetLocalFlag(FLAG.UNLOCK_SECOND_DOOR);

								}); PressAnyKey();
							}
						}
					}
					break;

				case 8:
					if (GameRes.map_data.GetActType(_curr_x + 1, _curr_y) != ACT_TYPE.MOVE)
						post_event_id = event_id;
					break;
				case (POST_EVENT | 8):
					if (!_IsLocalFlagSet(FLAG.GO_DOWN_TO_NEXT_FLOOR))
					{
						GameRes.party.SetDirection(1, 0);
						Talk("문은 마법의 힘으로 굳게 닫혀져 있다. 그리고 중앙에는 잠금을 해제하기 위한 석판을 끼울 자리가 십자형으로 나 있다.");
					}
					break;

				case 9: // walk on water 예제 -> (53,25)에 97 이벤트 발생
					if (GameRes.party.core.walk_on_water == 0)
					{
						if (!_IsLocalFlagSet(FLAG.TALK_ABOUT_WALK_ON_WATER))
						{
							int ix_player = GameRes.GetIndexOfSpeaker(new int[] { 1 });
							if (ix_player >= 0)
							{
								Talk(GameRes.player[ix_player].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
								Talk("");
								Talk("@F여기는 물이 차 있구려. 원래는 일반 통로인 것 같은데 지하수가 흘러넘친 것 같소.@@");

								RegisterKeyPressedAction(delegate ()
								{
									Talk("@F음... 저 물 건너 벽 쪽에 뭔가가 쓰여 있는 것 같은데 여기서는 멀어서 보이지가 않는구려.@@");
									Talk("");
									Talk("@F나의 마법으로 물을 건널 수 있을 것 같소.@@");

									int event_x = 53;
									int event_y = 25;

									GameRes.map_data.data[event_x, event_y].ix_event = EVENT_BIT.TYPE_EVENT | 97;
									GameRes.map_data.data[event_x, event_y].act_type = ACT_TYPE.DEFAULT;

									_SetLocalFlag(FLAG.TALK_ABOUT_WALK_ON_WATER);

									RegisterKeyPressedAction(delegate ()
									{
										Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_WALK_ON_WATER, GameRes.player[1].GetName()));
									}); PressAnyKey();

								}); PressAnyKey();
							}
						}
						else
						{
							Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_WALK_ON_WATER, GameRes.player[1].GetName()));
						}
					}
					break;

				case 10: // walk on swamp 예제
					if (GameRes.party.core.walk_on_swamp == 0)
					{
						if (!_IsLocalFlagSet(FLAG.TALK_ABOUT_WALK_ON_SWAMP))
						{
							int ix_player = GameRes.GetIndexOfSpeaker(new int[] { 1 });
							if (ix_player >= 0)
							{
								Talk(GameRes.player[ix_player].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
								Talk("");
								Talk("@F여기는 독이 있는 늪이구려. 그냥 지나가면 독에 감염될테니 조치가 필요할 것 같소.@@");

								_SetLocalFlag(FLAG.TALK_ABOUT_WALK_ON_SWAMP);

								RegisterKeyPressedAction(delegate ()
								{
									Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_WALK_ON_SWAMP, GameRes.player[1].GetName()));
								}); PressAnyKey();
							}
						}
						else
						{
							Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_WALK_ON_SWAMP, GameRes.player[1].GetName()));
						}
					}
					break;

				case 11: // 늪지대 속의 의외의 보물
					Talk("벽에는 어떤 글자로 뭔가가 쓰여 있지만 한 번도 본 적이 없는 형식의 글자이다.");
					break;

				case 12: // 3번방 진입문
					if (_GetLocalVariable(VARIABLE.ROOM_3RD) <= 1)
						post_event_id = event_id;
					break;
				case (POST_EVENT | 12):
					GameRes.party.SetDirection(-1, 0);

					if (_GetLocalVariable(VARIABLE.ROOM_3RD) == 0)
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F여기는 십자 모양의 홈이 있는 문이 있구려. 안쪽 방의 바닥 마감을 보니 꽤 중요한 방인가 보오.@@");
						Talk("");
						Talk("@F하지만 우리는 십자 모양의 석판은 없으니 어떻게든 이번에도 당신의 능력을 믿어 봐야겠소.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("일단, 다른 일행은 여기서 대기하는 것으로 이야기 되었다.");

							_IncLocalVariable(VARIABLE.ROOM_3RD);

							_LeaveClientsFromParty();

							// NPC_2_NAME
							MapEx_ChangeObj1(EVENT_POS_1_NPC_2.x, EVENT_POS_1_NPC_2.y, NPC_2_SPRITE_IX);
							// NPC_1_NAME
							MapEx_ChangeObj1(EVENT_POS_1_NPC_1.x, EVENT_POS_1_NPC_1.y, NPC_1_SPRITE_IX);


						}); PressAnyKey();
					}
					else if (_GetLocalVariable(VARIABLE.ROOM_3RD) == 1)
					{
						Talk("어떻게든 저 너머로 넘어가서 문을 열어야 한다.");
					}

					break;

				case 13: // 3번방 진입문의 우회 이벤트
					if (_GetLocalVariable(VARIABLE.ROOM_3RD) > 0)
					{
						if (GameRes.party.core.faced.dx == 0 && GameRes.party.core.faced.dy == 1)
						{
							Talk("여기 벽은 심하게 갈라져 있다.");
							Talk("");

							if (GameRes.player[1].IsValid() || GameRes.player[2].IsValid())
							{
								Talk("하지만 일행들이 있으니 무리는 할 필요가 없다.");
							}
							else
							{
								Talk("억지로 몸을 구겨 넣으면 그 틈으로 들어 갈 수 있을 것 같다.");

								RegisterKeyPressedAction(delegate ()
								{
									Select_Init();

									Select_AddTitle("갈라진 틈으로 몸을 비벼 넣으려 한다.");
									Select_AddGuide("당신의 선택은 ---");
									Select_AddItem("한 번 시도해 보자");
									Select_AddItem("옷이 더렵혀지는 것은 싫다");

									Select_Run(delegate (int selected)
									{
										switch (selected)
										{
											case 1:
												GameRes.party.WarpRel(0, 2);
												Talk("당신은 반대편으로 힘겹게 넘어 왔다.");
												if (_GetLocalVariable(VARIABLE.ROOM_3RD) < 2)
													_SetLocalVariable(VARIABLE.ROOM_3RD, 2);
												break;
											case 2:
												Talk("이 몸은 좀 귀하게 자라서...");
												break;
											default:
												Talk("(당신은 고민 중이다)");
												break;
										}
									});

								}); PressAnyKey();
							}
						}
						else if (_GetLocalVariable(VARIABLE.ROOM_3RD) < 2)
						{
							if (_GetLocalVariable(VARIABLE.NUM_PASS_CRACKED_WALL) > 4)
								Talk("아래쪽의 벽틈에서 바람이 느껴진다.");
							else
								_IncLocalVariable(VARIABLE.NUM_PASS_CRACKED_WALL);
						}
					}
					break;

				case 14: // 3번방 진입문을 위해 윗층으로 올라가는 이벤트
					Talk("벽이 허물어진 위쪽을 보니, 그 위쪽에도 따로 공간이 있다.");

					RegisterKeyPressedAction(delegate ()
					{
						Select_Init();

						Select_AddTitle("위쪽의 공간으로 올라가려 한다.");
						Select_AddGuide("당신의 선택은 ---");
						Select_AddItem("무너진 벽을 밟고 올라간다");
						Select_AddItem("신발이 더러워질 것 같다");

						Select_Run(delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									GameRes.party.Warp(EVENT_WARP_UPSTAIRS.x, EVENT_WARP_UPSTAIRS.y);
									GameRes.party.SetDirection(1, 0);
									Talk("당신은 위쪽 틈으로 기어 올라갔다.");
									break;
								case 2:
									Talk("신발뿐만 아니라 몸도 지저분해 질 것이다.");
									break;
								default:
									Talk("일단 좀 더 생각해 보자.");
									break;
							}
						});

					}); PressAnyKey();

					break;

				case 15: // 윗층으로 다시 아래로 내려감
					if (GameRes.party.core.levitation > 0)
					{
						Talk("공중 부상을 하고 있어서 아래로 떨어지지는 않는다.");
						// TODO: 매뉴얼 필요함
					}
					else
					{
						post_event_id = event_id;
					}
					break;
				case (POST_EVENT | 15):
					Talk("당신은 아래로 떨어졌다.");

					GameRes.party.Warp(EVENT_WARP_DOWNSTAIRS.x, EVENT_WARP_DOWNSTAIRS.y);
					GameRes.party.SetDirection(-1, 0);
					break;

				case 16: // 앞은 낭떠러지임을 알려주는 독백
					Talk("이 아래에는 아까 그 방의 안쪽이 보인다.");
					PressAnyKey();
					break;

				case 17: // 3번 방으로 떨어지는 곳
					if (GameRes.party.core.levitation > 0)
					{
						Talk("공중 부상을 하고 있어서 아래로 떨어지지는 않는다.");
						// TODO: 매뉴얼 필요함
					}
					else
					{
						post_event_id = event_id;
					}
					break;
				case (POST_EVENT | 17): // 3번 방으로 떨어짐
					Talk("당신은 아래로 떨어졌다.");

					GameRes.party.Warp(EVENT_WARP_3RD_ROOM.x, EVENT_WARP_3RD_ROOM.y);
					GameRes.party.SetDirection(-1, 0);
					break;

				case 18: // 3번 방의 문을 뒤에서 열는 이벤트
					{
						int event_x = _curr_x + 1;
						int event_y = _curr_y;

						if (GameRes.map_data.GetActType(event_x, event_y) == ACT_TYPE.BLOCK)
							post_event_id = event_id;
					}
					break;
				case (POST_EVENT | 18):
					GameRes.party.SetDirection(1, 0);

					Talk("문의 이쪽에는 석판을 인식해서 문을 열기 위한 간단한 마법이 걸려 있다.");
					Talk("");
					Talk("마법을 안전하게 해제 하는 방법은 애시당초 알지 못하기에 그냥 마법이 걸려 있는 부분을 부숴버렸다.");

					RegisterKeyPressedAction(delegate ()
					{
						// TODO: 동작 함수
						int event_x = _curr_x + 1;
						int event_y = _curr_y;

						this.MapEx_ChangeObj1(event_x, event_y, 65);

						Talk("그리고, 약간의 힘을 주자 길을 막던 문이 열렸다.");

						RegisterKeyPressedAction(delegate ()
						{
							// TODO: Fade out/in 의 연출이 있으면 좋겠다.
							_RejoinClientsToParty();

							MapEx_ClearObj(EVENT_POS_1_NPC_2.x, EVENT_POS_1_NPC_2.y);
							MapEx_ClearObj(EVENT_POS_1_NPC_1.x, EVENT_POS_1_NPC_1.y);

							Talk("의뢰인들은 다시 나와 합류를 하였다.");

							_SetLocalVariable(VARIABLE.ROOM_3RD, 3);

						}); PressAnyKey();

					}); PressAnyKey();

					break;

				case 19:
					post_event_id = event_id;
					break;
				case (POST_EVENT | 19):
					if (_IsLocalFlagSet(FLAG.CHECK_NORTH_DOOR))
					{
						// 아래쪽 위쪽 모두 살펴 보니 아래쪽 문은 힘으로 열 수 있음
						// 그런데 동력의 근원은 모르겠으나 마법의 힘에 의해 접근이 안 됨
						GameRes.party.SetDirection(0, 1);

						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F이 방에는 아까 들어온 곳을 제외하고는 위쪽과 아래쪽에 각각 문이 있소. 하지만 위쪽은 너무 강하게 닫혀 있어서 그나마 여기가 더 취약하오.@@");
						Talk("");
						Talk("@F그대신 여기는 마법이 걸려 있어서 문에 접근 자체가 불가능 하오.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F일단 내가 마법을 차단 시켜 보겠소. 그러면 이 옆의 친구가 힘으로 문을 밀어 내면 될 것 같소.@@");

							RegisterKeyPressedAction(delegate ()
							{
								// 뒷걸음 치고나서
								GameRes.party.SetDirection(0, 1);
								GameRes.party.Move(0, -1, false);

								// 파티 분리 이벤트
								GameRes.PostEventId = 96;

							}); PressAnyKey();

						}); PressAnyKey();
					}
					else
					{
						GameRes.party.SetDirection(0, 1);
						Talk("이 벽은 강력한 마법으로 보호 되고 있어서 만지는 것 자체가 불가능 하다.");
					}

					// 도르레를 통해 문을 열려고 시도
					// 21번 이벤트로 가면 다시 <NPC_1_NAME> 파티 분리
					// 24번 이벤트를 보든 안 보든 문 열림
					break;
				case (POST_EVENT | 96):
					{
						Talk("의뢰인들은 뭔가를 찾으려는지 벽 쪽으로 붙었다.");

						_LeaveClientsFromParty();

						MapEx_ChangeObj1(EVENT_POS_2_NPC_1.x, EVENT_POS_2_NPC_1.y, NPC_1_SPRITE_IX);
						MapEx_ChangeObj1(EVENT_POS_2_NPC_2.x, EVENT_POS_2_NPC_2.y, NPC_2_SPRITE_IX);

						MapEx_ClearEvent(EVENT_POS_2_NPC_1.x, EVENT_POS_2_NPC_1.y);
						MapEx_ClearEvent(EVENT_POS_2_NPC_2.x, EVENT_POS_2_NPC_2.y);

						RegisterKeyPressedAction(delegate ()
						{
							ObjNameBase npc1_name = new ObjNameBase();
							npc1_name.SetName(NPC_1_NAME);

							Talk(npc1_name.GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
							Talk("");
							Talk("@F벽을 따라 흐르는 마법의 맥을 찾은 것 같소. 일단 나는 이 부분의 맥을 끊으려 하오. 당신은 잠시 쉬고 계시구려.@@");

							GameRes.party.SetTimeEvent(5, 95);

							PressAnyKey();

						}); PressAnyKey();
					}
					break;

				case 95:
					{
						ObjNameBase npc1_name = new ObjNameBase();
						npc1_name.SetName(NPC_1_NAME);

						Talk("갑자기 주위가 어두워졌다. " + npc1_name.GetName(ObjNameBase.JOSA.SUB2) + " 마법의 동력원을 끊은 듯하다.");
						Talk("");
						Talk("그리고, 그가 당신을 불렀다.");

						_SetLocalVariable(VARIABLE.ROOM_3RD, 4);
						_SetLocalFlag(FLAG.BREAK_MAGIC_POWER_SOURCE);

						PressAnyKey();
					}
					break;

				case (POST_EVENT | 94):
					Talk("우리들은 힘을 내어 문을 같이 밀어 보았다.");

					RegisterKeyPressedAction(delegate ()
					{
						Talk("거의 다 밀려 있었던 문이라 3명이 동시에 힘을 주자 문은 바로 밀려났다.");

						RegisterKeyPressedAction(delegate ()
						{
							_SetLocalFlag(FLAG.UNLOCK_3RD_ROOM_SOUTH_DOOR);

						}); PressAnyKey();

					}); PressAnyKey();
					break;

				case 20: // 반대편에서 잠긴 문
					if (GameRes.map_data.GetActType(_curr_x, _curr_y - 1) == ACT_TYPE.BLOCK)
					{
						Talk("이 벽은 단단히 고정되어 있지만 반대편에서는 쉽게 열 수 있는 구조이다.");
					}

					_SetLocalFlag(FLAG.CHECK_NORTH_DOOR);
					break;

				case 21: // 보물이 있는 쪽 틈
					if (GameRes.party.core.faced.dx == 1 && GameRes.party.core.faced.dy == 0)
					{
						Talk("이쪽 벽에는 이전에 봤던 것과 유사한 틈이 있다.");

						RegisterKeyPressedAction(delegate ()
						{
							if (!GameRes.player[1].IsValid() && !GameRes.player[2].IsValid())
							{
								Select_Init();

								Select_AddTitle("당신은 틈새를 비집고 반대편으로 가려 한다.");
								Select_AddGuide("당신의 선택은 ---");
								Select_AddItem("틈을 비집고 들어가본다");
								Select_AddItem("못 돌아 올지도 모르니 그냥 있는다");

								Select_Run(delegate (int selected)
								{
									switch (selected)
									{
										case 1:
											GameRes.party.WarpRel(2, 0);
											Talk("당신은 반대편으로 넘어 왔다.");
											break;
										case 2:
											Talk("남들은 고생하고 있으니 여기서 자리라도 지키는 것이 맞는 것 같다.");
											break;
										default:
											Talk("고민되면 그냥 그대로 있자.");
											break;
									}
								});
							}
							else
							{
								Talk("하지만 지금은 일행들이 있어서 건너갈 수 없다.");
							}

						}); PressAnyKey();

					}
					break;

				case 22: // 소소한 보물
					if (!_IsLocalFlagSet(FLAG.GET_TRIVIAL_LOOT))
					{
						Talk("항아리의 안쪽에는 누군가가 숨겨 놓았을 법한 금화가 들어 있었다. 약소한 금액이라 나와 같은 대도가 손댈 정도는 아니다.");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("... 라고 생각하고 있는데, 어느새 그 금화는 내 손에 들려 있었다. 하긴 금액의 크고 작음을 따지지 않는 것이 큰 도둑의 마음가짐이긴 하다.");
							Talk("");
							Talk("@A[금화 +100G]@@");

							GameRes.party.gold += 100;

							_SetLocalFlag(FLAG.GET_TRIVIAL_LOOT);

						}); PressAnyKey();
					}
					break;

				case 23: // 낭떠러지, levitation 예제
					if (!_IsLocalFlagSet(FLAG.FIND_RARE_LOOT) && (GameRes.party.core.levitation == 0))
						Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_LEVITATION, GameRes.player[0].GetName()));
					break;

				case 24: // 엄청난 보물
					if (!_IsLocalFlagSet(FLAG.FIND_RARE_LOOT))
					{
						Talk("눈 앞에는 어떤 상자가 있다. 굳이 이렇게 번거로운 장소에 이것을 둔 것이라면 다 이유가 있을 것이다.");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("상자를 열어보고는 먼저 내 눈을 의심했다.");
							Talk("");
							Talk("이 안에는 @B청금석의 원석@@이 있었다. 누군가가 숨겨 놓고 위치를 잊어버렸거나, 다시 여기로 찾아 오지 못 하고 있거나, 이미 주인이 없는 상태일 것이다.");

							RegisterKeyPressedAction(delegate ()
							{
								Talk("이렇게 큰 원석이라면 처음 발견한 사람도 제대로 들고 나오지 못했을 것이고 나 역시도 그렇다.");
								Talk("");
								Talk("일단 지금은 의뢰인들과 동행하고 있는 상황이니 이렇게 눈에 띄는 것을 들고 나올 수도 없는 상황이다. 나중에 기회를 봐서 다시 가지러 와야겠다.");

								_SetLocalFlag(FLAG.FIND_RARE_LOOT);

								PressAnyKey();

							}); PressAnyKey();

						}); PressAnyKey();
					}
					else
					{
						if (_IsLocalFlagSet(FLAG.TITLE_OF_COWARD) || _IsLocalFlagSet(FLAG.TITLE_OF_POOP_MAN))
						{
							Talk("이제는 이 큰 덩어리를 안전하게 밖으로 가져 나가는 일만 남았다.");
							Talk("");
							Talk("청금석 자체는 다른 귀금속보다야 조금 가치가 떨어진다고는 할 수 있지만 이 정도의 크기면 로어대륙에서 몇 년을 먹고 사는데 문제가 없을 정도라고 보면 된다.");

							RegisterKeyPressedAction(delegate ()
							{
								Talk("이것을 무사히 가져 나간 뒤, 이것을 원석 그대로 바로 팔거나, 정제를 해서 좀 더 비싸게 팔거나, 다른 장비의 재료가 되도록 가공을 해서 파는 방법 등이 있다.");
								Talk("");
								Talk("무엇을 선택하든 나는 그만큼의 이득을 얻을 것이다.");

								_SetLocalFlag(FLAG.GET_RARE_LOOT);

								RegisterKeyPressedAction(delegate ()
								{
									_ClearProlog();

								}); PressAnyKey();

							}); PressAnyKey();

						}
						else
						{
							Talk("일단 지금은 의뢰인들과 동행하고 있는 상황이니 이렇게 눈에 띄는 것을 들고 나올 수도 없는 상황이다. 나중에 기회를 봐서 다시 가지러 와야겠다.");
						}
					}
					break;

				case 25: // 틈을 통해 다시 3번 방으로
					if (GameRes.party.core.faced.dx == -1 && GameRes.party.core.faced.dy == 0)
					{
						Talk("아까 넘어 왔던 벽의 틈이다.");

						RegisterKeyPressedAction(delegate ()
						{
							Select_Init();

							Select_AddTitle("당신은 틈새를 비집고 반대편으로 가려 한다.");
							Select_AddGuide("당신의 선택은 ---");
							Select_AddItem("틈을 비집고 다시 돌아간다");
							Select_AddItem("조금 더 있어본다.");

							Select_Run(delegate (int selected)
							{
								switch (selected)
								{
									case 1:
										GameRes.party.WarpRel(-2, 0);
										Talk("당신은 다시 일행이 있는 방으로 넘어 왔다.");
										break;
									default:
										Talk("여기는 원래 정상적인 문이었지만 어떤 이유에서인지 벽으로 위장하려 한 것 같다.");
										break;
								}
							});

						}); PressAnyKey();

					}
					break;

				case 26: // 물을 건너는 마법이 없다면 메뉴얼
					if (GameRes.party.core.walk_on_water == 0)
					{
						Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_WALK_ON_WATER, GameRes.player[1].GetName()));
					}
					break;

				case 27: // 잠겨져 있음 -> 왼쪽 벽에서 바람이 느껴짐 -> 주시자의 눈으로 보니 왼쪽이 길임
					if (_GetLocalVariable(VARIABLE.TALK_ABOUT_HIDDEN_WAY) <= 0)
						post_event_id = event_id;
					break;
				case (POST_EVENT | 27):
					GameRes.party.SetDirection(0, -1);
					Talk("이것도 아까 방을 잠그고 있던 것과 같은 구조의 잠금 장치이다.");

					RegisterKeyPressedAction(delegate ()
					{
						Talk("옆에 있던 " + GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F그런데 왼쪽 벽에서 계속 바람이 불어 오는 것 같소. 분명 막혀 있는 벽처럼 보이는데 눈으로 보이는 것과 그 실체는 다를지도 모르오.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F이럴 때는 @B주시자의 눈@@으로 주위를 보게 되면 안 보이던 것을 찾을 수 있을 지도 모르오.@@");
							Talk("");
							Talk("@F자, 그럼 마법을 준비할테니 잘 봐 두시오.@@");

							_IncLocalVariable(VARIABLE.TALK_ABOUT_HIDDEN_WAY);

							RegisterKeyPressedAction(delegate ()
							{
								GameRes.party.Cast_EyesOfBeholder(null);

							}); PressAnyKey();

						}); PressAnyKey();

					}); PressAnyKey();
					break;

				case 28: // 눈속임 마법에 의해 벽으로 느껴졌음을 이야기 함
					if (_GetLocalVariable(VARIABLE.TALK_ABOUT_HIDDEN_WAY) <= 1)
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F역시 눈속임 마법이었소. 하급 속임수이긴 하지만 이런 것이 있다는 것을 모른다면 속아 넘어가고 마는 그런 류의 마법이라오.@@");

						_IncLocalVariable(VARIABLE.TALK_ABOUT_HIDDEN_WAY);
					}
					break;

				case 29: // 3번 방의 북쪽 문을 염
					if (GameRes.map_data.GetActType(_curr_x, _curr_y + 1) == ACT_TYPE.BLOCK)
						post_event_id = event_id;
					break;
				case (POST_EVENT | 29):
					Talk("아까 반대 쪽에서는 안 열렸던 그 문이다.");

					RegisterKeyPressedAction(delegate ()
					{
						// TODO: 동작 함수?
						this.MapEx_ChangeTile(_curr_x, _curr_y + 1, 14);

						Talk("잠금을 풀고 약간의 힘을 주자 문이 열렸다.");

					}); PressAnyKey();

					break;

				case 30: // 계단방의 남쪽 문을 염. 육각형
					if (GameRes.map_data.GetActType(_curr_x, _curr_y - 1) == ACT_TYPE.BLOCK)
						post_event_id = event_id;
					break;
				case (POST_EVENT | 30):
					GameRes.party.SetDirection(0, -1);

					Talk("이쪽에 육각형의 석판을 끼우는 곳이 있다. 그동안 해 왔던 것처럼 육각 석판을 거기에 끼워 보았다.");

					RegisterKeyPressedAction(delegate ()
					{
						Talk("문은 스르르 열렸다.");

						_SetLocalFlag(FLAG.UNLOCK_LAST_DOOR);

					}); PressAnyKey();

					break;

				case 31: // 뭔지 모르는 문자가 쓰여 있음
					Talk("벽에는 뭔지 모르는 문자가 쓰여 있다. 적어도 인류가 사용하는 형태의 문자는 아니다.");
					break;

				case 32: // 아래쪽을 보게 되며, 십자 모양의 열리지 않는 문
					post_event_id = event_id;
					break;
				case (POST_EVENT | 32):
					GameRes.party.SetDirection(0, 1);
					Talk("몇 번이고 봐 왔던 십자 모양의 홈이 있는 문이다. 이번에는 이런 문을 여는 것은 포기해야겠다.");
					break;

				case 33: // 왼쪽을 보게 되며, 뒤쪽에서 잠긴 문
					post_event_id = event_id;
					break;
				case (POST_EVENT | 33):
					GameRes.party.SetDirection(-1, 0);
					Talk("여기는 뒤쪽에서 잠긴 문이다. 계속 해 왔던 것처럼 어떻게든 뒤쪽으로 넘어가면 문을 열 수는 있을 것이다. 하지만 굳이 갈 필요는 없는 곳이기도 하다.");
					break;

				case 34: // 계단방의 북쪽 문을 염. 육각형
					if (GameRes.map_data.GetActType(_curr_x, _curr_y - 1) == ACT_TYPE.BLOCK)
						post_event_id = event_id;
					break;

				case (POST_EVENT | 34):
					GameRes.party.SetDirection(0, -1);
					Talk("그 문에는 육각형 모양의 홈이 있다.");

					RegisterKeyPressedAction(delegate ()
					{
						// TODO: 동작 함수?
						this.MapEx_ChangeTile(_curr_x, _curr_y - 1, 14);

						Talk("육각형 석판을 홈에 끼우자 문은 스르르 자동으로 열렸다.");

					}); PressAnyKey();
					break;

				case 35: // 계단방의 내려가는 계단 앞의 잠금 장치를 해제. 원래 의뢰자가 열쇠를 가지고 있었음.
					if (!_IsLocalFlagSet(FLAG.OPEN_DOWN_STAIRS))
						post_event_id = event_id;
					break;
				case (POST_EVENT | 35):
					GameRes.party.SetDirection(0, -1);
					Talk("지금까지 본 문 중에서 가장 고급 재료로 만들어진 문이다. 그리고 그 문에는 홈이 아닌 일반 열쇠를 꽂는 홈이 있다.");

					RegisterKeyPressedAction(delegate ()
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F우리가 여기를 들어 오기 위해 가장 먼저한 것이 여기의 열쇠를 손에 넣는 것이었소. 열쇠를 잘 못 가져 왔다면 큰 낭패겠지만 그러지는 않기를 바라오.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("그가 열쇠를 넣고 돌리자 딸깍하는 소리가 났고 문은 오른쪽으로 밀려 났다.");

							// 입구가 오른쪽으로 움직이는 연출
							_SetLocalFlag(FLAG.OPEN_DOWN_STAIRS);

							// 입구자리에는 이벤트(40) 발생
							GameRes.map_data.data[_curr_x, _curr_y - 1].ix_event = EVENT_BIT.TYPE_EVENT | 40;
							GameRes.map_data.data[_curr_x, _curr_y - 1].act_type = ACT_TYPE.DEFAULT;

						}); PressAnyKey();

					}); PressAnyKey();

					break;

				case 36: // 처음 공중 부상
					if (!_IsLocalFlagSet(FLAG.TALK_ABOUT_LEVITATION))
					{
						Talk("이 부분의 길이 무너져 내리면서 이쪽 길이 폐쇄된 것 같다.");
						Talk("");
						Talk("내가 마법에는 익숙하지 않지만 그나마 유일하게 잘하는 것이 공중 부양 마법이다. 이 능력은 내 직업에 꼭 필요한 것이었기 때문이다.");

						_SetLocalFlag(FLAG.TALK_ABOUT_LEVITATION);

						RegisterKeyPressedAction(delegate ()
						{
							Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_LEVITATION, GameRes.player[0].GetName()));

						}); PressAnyKey();
					}
					else if (GameRes.party.core.levitation <= 0)
					{
						Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_LEVITATION, GameRes.player[0].GetName()));
					}

					break;

				case 37: // 처음 공중 부상 후 대사
					if (!_IsLocalFlagSet(FLAG.MONOLOG_AFTER_LEVITATION))
					{
						Talk("공중 부상은 몸을 떠 오르게 하는 능력이 아닌 현재의 고도를 유지하는 기능을 말한다.");
						Talk("");
						Talk("주로 떨어지는 함정 등을 피하기 위해 고안된 마법이긴한데 고도를 유지하는데 큰 집중력이 요구되는 것이 단점이다. 그래서 바람이 많이 불거나 바닥이 허공이 아닌 경우는 사용하기 힘들다.");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("마법을 사용한 사람은 무방비 상태가 되며 물리 법칙을 위반하지는 않기 때문에 중간에 방향을 바꿀 수는 없다.");
							Talk("");
							Talk("다만 대마법사등 중에는 환경의 영향 없이 공중 부상을 사용할 수 있는 사람이 있다고는 한다.");

							_SetLocalFlag(FLAG.MONOLOG_AFTER_LEVITATION);

						}); PressAnyKey();
					}
					break;

				case 40: // rare 보물을 발견했을 경우는 파티를 계속할지 해체할지 결정하게 됨
					if (!_IsLocalFlagSet(FLAG.TALK_TO_CLIENTS_BEFORE_GOING_DOWN))
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F자, 원래 우리가 가려는 곳이 바로 이 아래요. 여기 바로 밑에서 동료의 신호가 나왔던 것으로 우리는 판단하고 있소.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk("계단 아래를 확인하던 " + GameRes.player[1].GetName(ObjNameBase.JOSA.SUB) + " 잠시 주춤했다.");
							Talk("");
							Talk("그리고 말을 이어 나갔다.");

							RegisterKeyPressedAction(delegate ()
							{
								Talk("@F여기의 계단은 끝쪽이 무너져 있구려. 그래서 동료가 이곳을 올라오지 못하고 구조 신호를 보낸 것 같소. 일단 여기로 내려가면 이쪽을 통해서 올라오기는 힘들 것 같소@@");

								RegisterKeyPressedAction(delegate ()
								{
									Talk("@F그나마 다행스럽게도 @B수정 구슬@@을 좀 준비해 왔소이다. 마치 주시자의 눈을 사용한 것처럼 주위를 보면서 다른 출구를 찾을 수 있을 것이외다.@@");

									if (_IsLocalFlagSet(FLAG.FIND_RARE_LOOT))
									{
										RegisterKeyPressedAction(delegate ()
										{
											Talk("여기를 내려가면 다시 이쪽으로는 못 나온다는 말을 듣고는, 아까의 그 @B청금석의 원석@@을 생각했다.");
											Talk("");
											Talk("그걸 팔면 꽤 큰 돈을 가지고 로어성 같은 곳으로 들어가 살 수가 있다. 하지만 여기의 의뢰를 저 버린다면 나의 평판은 더 떨어지게 된다.");

											RegisterKeyPressedAction(delegate ()
											{
												Talk("적절한 핑계를 대고 의뢰를 파기할지, 아니면 계속 임무를 수행할지를 결정해야 할 것 같다.");

												RegisterKeyPressedAction(delegate ()
												{
													Select_Init();

													Select_AddTitle("의뢰를 파기할지 고민 중이다.");
													Select_AddGuide("당신의 선택은 ---");
													Select_AddItem("돈을 위해서라면 신의쯤이야...");
													Select_AddItem("평판을 위해서라도 계속 같이 한다");

													Select_Run_NoCancel(delegate (int selected)
													{
														switch (selected)
														{
															case 1:
																GameRes.PostEventId = 93;
																break;
															default:
																Talk("당신은 그들과 함께 하기로 했다. 안 그래도 바닥에 닿을 듯한 나의 평판이 이번 의뢰의 해결을 계기로 좀 나아졌으면 한다.");
																break;
														}
													});

												}); PressAnyKey();

											}); PressAnyKey();

										}); PressAnyKey();
									}

								}); PressAnyKey();

							}); PressAnyKey();

						}); PressAnyKey();

						_SetLocalFlag(FLAG.TALK_TO_CLIENTS_BEFORE_GOING_DOWN);
					}
					break;

				case (POST_EVENT | 93): // rare 보물을 얻기 위해 파티를 떠날 핑계를 댐
					Talk("당신은 말한다.");
					Talk("");
					Talk("@G여기로 내려가면 다시 올라올 수 없다니, 이런 식의 이야기는 외뢰 내용에 없었소.@@");
					Talk("");
					Talk("그리고, 적당한 핑계를 만들기로 했다.");

					RegisterKeyPressedAction(delegate ()
					{
						Select_Init();

						Select_AddTitle("일행에서 빠질 핑계를 대야 한다.");
						Select_AddGuide("당신의 선택은 ---");
						Select_AddItem("제가 사실 겁이 좀 많아서...");
						Select_AddItem("욱.... 급..급똥이...");

						Select_Run(delegate (int selected1)
						{
							switch (selected1)
							{
								case 1:
									Talk("@G제가 말입죠, 딴 건 다해도 너무 깊은 동굴 아래로는 못 간답니다. 고소공포증과 반대의 병인데 저소공포증이라고 그런게 있습죠...@@");

									RegisterKeyPressedAction(delegate ()
									{
										Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB) + " 눈쌀을 찌푸렸다.");
										Talk("");
										Talk("@F갑자기 뭔 시답지 않은 소리요. 라스트디치의 지하 계곡 아래로 떨어진 용의 보물을 사흘 밤낮을 뒤져서 다시 찾아낸 전설적인 사내가 당신이지 않소.@@");

										RegisterKeyPressedAction(delegate ()
										{
											Select_Init();

											Select_AddGuide("당신의 선택은 ---\n");
											Select_AddItem("끝까지 우겨 보자");
											Select_AddItem("하하, 농담이었습니다");

											Select_Run(delegate (int selected2)
											{
												switch (selected2)
												{
													case 1:
														GameRes.PostEventId = 92;
														break;
													default:
														Talk("@G그냥 분위기 바꾸려고 한 번 해본 말입니다. 자, 가시죠.@@");
														break;
												}
											});

										}); PressAnyKey();

									}); PressAnyKey();

									break;
								case 2:
									Talk("@G그...급 똥이오!!!@@");
									Talk("@G헉.. 지금 막 쌀 것 같소!! 그리고 제가 좀 오래 누는 편이니 날 기다리지 마시고 그냥 가던 길 가시오!@@");
									Talk("");
									Talk("그러면서 당신은 뒤도 안 돌아 보고 뛰쳐 나갔다.");

									RegisterKeyPressedAction(delegate ()
									{
										GameRes.PostEventId = 91;
									}); PressAnyKey();

									break;
								default:
									Talk("@G하하하.. 농담이오. 천하의 천재 도둑 머큐리님은 신의를 가장 중요시 한다오. 아하하하...@@");
									break;
							}
						});

					}); PressAnyKey();

					break;

				case (POST_EVENT | 92): // '겁쟁이 칭호'
					Talk("@G당신들은 모르는 후천성 뭐 그렇고 그런 것이 있소. 모르면서 말을 막 함부로 하지 마시오. 갑자기 기분이 막 나빠졌소. 이런 기분으로는 같이 일 못한단 말이오!!@@");

					RegisterKeyPressedAction(delegate ()
					{
						Talk("당신은 자신이 뭘 하고 있는지도 모를만큼 무의미한 말을 뱉어 내면서 뒷걸음을 쳤다.");
						Talk("");
						Talk("그리고 방 밖으로 내 달렸다.");

						RegisterKeyPressedAction(delegate ()
						{
							GameRes.party.Warp(27, 31);
							GameRes.party.SetDirection(0, 1);

							_LeaveClientsFromParty();

							Talk("멀리서 '겁쟁이'라고 야유 하는 소리가 들린다.");
							Talk("");
							Talk("하지만 큰 돈을 위해서라면 이 정도는 참아야 한다.");

							GameRes.party.PassTime(0, 15, 0);

							_SetLocalFlag(FLAG.TITLE_OF_COWARD);

						}); PressAnyKey();

					}); PressAnyKey();

					break;

				case (POST_EVENT | 91): // '똥쟁이 칭호'
					Talk("황당해 하는 의뢰인들을 뒤로 하고 빠른 걸음으로 방을 나왔다.");
					Talk("");
					Talk("그리고는 @B청금석의 원석@@이 있는 그 통로까지 한 걸음에 달려서 몸을 숨겼다.");

					RegisterKeyPressedAction(delegate ()
					{
						GameRes.party.PassTime(1, 10, 0);

						Talk("한참의 시간이 흘렀다.");
						Talk("");
						Talk("이제는 내가 돌아 오지 않을 것이란 것을 알고 그들은 아래도 내려갔을 것이다. 동료의 생사가 더 중요했기 때문일테니.");

						_LeaveClientsFromParty();

						GameRes.party.Warp(31, 52);
						GameRes.party.SetDirection(0, -1);

						_SetLocalFlag(FLAG.TITLE_OF_POOP_MAN);

					}); PressAnyKey();

					break;

				case 90: // 다시 올라와서 마지막
					if (GameRes.map_data.GetActType(_curr_x - 1, _curr_y) == ACT_TYPE.BLOCK)
						post_event_id = event_id;
					break;
				case (POST_EVENT | 90):
					{
						GameRes.party.SetDirection(-1, 0);

						Talk(GameRes.player[3].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F잠겨진 문이오만 여기서 기화 이동을 하면 저편으로 건너갈 수 있을 것이오.@@");

						if (!_IsLocalFlagSet(FLAG.TALK_ABOUT_PENETRATION))
						{
							RegisterKeyPressedAction(delegate ()
							{
								Talk("@F잠시 @B투시@@를 사용해볼테니 이동 가능 위치를 확보해 보시오.@@");

								RegisterKeyPressedAction(delegate ()
								{
									Talk("@B투시@@ 덕분에 아주 잠깐 벽 너머를 볼 수 있게 되었다.");

									_SetLocalFlag(FLAG.TALK_ABOUT_PENETRATION);

									GameRes.party.core.penetration = 7;

									GameRes.party.SetTimeEvent(1, 89);

								}); PressAnyKey();

							}); PressAnyKey();
						}
					}
					break;

				case 89: // 마지막 타임 이벤트. 기화 이동의 성공 여부를 확인 한다.
					if (GameRes.party.pos.x <= 45 || GameRes.party.pos.y <= 27)
					{
						Talk("@F자! 되었소. 이제 처음에 들어 왔던 길로 나가면 끝이오.@@");
						Talk("");
						Talk("@F다들 수고하셨소. 그리고 이 은혜는 항상 기억할 것이오. 거기 @B머큐리@@라고 하는 젊은 친구도 항상 은인으로 생각하겠소.@@");

						RegisterKeyPressedAction(delegate ()
						{
							_ClearProlog();

						}); PressAnyKey();
					}
					else
					{
						// 조건을 만족할 때까지
						GameRes.party.SetTimeEvent(1, 89);
					}
					break;

				case 88: // 불이 켜짐
					if (!_IsLocalFlagSet(FLAG.RESTORE_MAGIC_POWER_SOURCE))
					{
						Talk("다시 동굴이 환해졌다. 동굴 내의 마법의 흐름이 자동으로 복원된 듯하다.");

						_SetLocalFlag(FLAG.RESTORE_MAGIC_POWER_SOURCE);
					}
					break;

				default:
					processing_completed = false;
					break;
			}

			if (!processing_completed && is_not_post)
			{
				string event_s;

				if (!GameRes.map_data.events.TryGetValue(event_id, out event_s))
				{
					Talk(String.Format("OnEvent({0})", event_id));
					Debug.Assert(false);
					return true;
				}

				Talk(event_s);
			}

			return you_can_move_to_there;
		}
	}
}
/*
RegisterKeyPressedAction(delegate ()
{
	Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_MAGIC_TORCH));
}); PressAnyKey();
*/

/*
 * TODO:
- '공중 부상' 막다른 길에서 멈춤

- 메인 메뉴 분리
  1. 원래의 메뉴에서는 P, R, G 만 따로 분리
  2. 나머지 메뉴는 캐릭터 클릭이 trigger
     왼쪽으로 오렌지 색의 메뉴창이 뜨고, C(Es), U, V, W 의 메뉴를 선택할 수 있다.

- 전투 부분의 템포를 빠르게 할 필요가 있다.

 */
