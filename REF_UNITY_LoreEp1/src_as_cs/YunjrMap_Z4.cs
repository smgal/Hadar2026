
using UnityEngine;
using System;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_Z4 : YunjrMap
	{
		// Map size: 53 x 52
		const int POST_EVENT = 0x10000;

		readonly string NPC_3_NAME = GameStrRes.GetNpcName(GameStrRes.NPC_ID.NPC_FIRST_CLIENT3);

		private enum FLAG
		{
			I_KNOW_THIS_PLACE_WELL = 0,
			SURVIVOR_FOUND = 1,
			JOIN_TO_SURVIVOR = 2,
			REMOVE_ROCK_BY_NPC2 = 3,
			FIRST_TALK_TO_SURVIVOR = 4,
			CHAT_WITH_PARTY_ON_ROAD_1 = 5,
			CHAT_WITH_PARTY_ON_ROAD_2 = 6,
			CHAT_WITH_PARTY_ON_ROAD_3 = 7,
			CHAT_WITH_PARTY_ON_ROAD_4 = 8
		}

		private enum VARIABLE
		{
			LEVEL_OF_KNOWING_WELL_HERE = 0
		}

		//////////////////////////////////////////////////////////////////////////////

		private const int IX_FLAG_BASE = 200;
		private const int IX_VARIABLE_BASE = 20;

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
			case FLAG.JOIN_TO_SURVIVOR:
				{
					int event_x = 15;
					int event_y = 8;

					MapEx_ClearObj(event_x, event_y);
					MapEx_ClearEvent(event_x, event_y);
					MapEx_SetEvent(event_x + 2, event_y, 97);

					GameRes.party.core.gameover_condition = (int)GAMEOVER_COND.HERO_DEFEATED;
				}
				break;

			case FLAG.REMOVE_ROCK_BY_NPC2:
				{
					int event_x = 17;
					int event_y = 8;

					MapEx_ClearEvent(event_x, event_y);
					MapEx_ClearObj(event_x + 1, event_y);
					MapEx_SetEvent(event_x + 1, event_y, 96);
				}
				break;

			case FLAG.FIRST_TALK_TO_SURVIVOR:
				GameRes.party.core.gameover_condition = (int)GAMEOVER_COND.ANY_MEMBERS_DEFEATED;
				break;

			case FLAG.CHAT_WITH_PARTY_ON_ROAD_1:
				LibMapEx.ClearMapEvent(ref GameRes.map_data, 1);
				break;
			case FLAG.CHAT_WITH_PARTY_ON_ROAD_2:
				LibMapEx.ClearMapEvent(ref GameRes.map_data, 2);
				break;
			case FLAG.CHAT_WITH_PARTY_ON_ROAD_3:
				LibMapEx.ClearMapEvent(ref GameRes.map_data, 3);
				break;
			case FLAG.CHAT_WITH_PARTY_ON_ROAD_4:
				LibMapEx.ClearMapEvent(ref GameRes.map_data, 4);
				break;

			default:
				break;
			}
		}

		////////////////////////////////////////////////////////////////////////

		public override string GetPlaceName(byte degree_of_well_known)
		{
			if (degree_of_well_known > 0)
				return "자연 동굴";
			else
				return "자연 동굴";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.TOWN);
			CONFIG.TILE_BG_DEFAULT = 44;
			// CONFIG.BGM = "DefaultBgm";
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			Debug.Log("YunjrMap::OnLoad() from [" + prev_map + ", " + from_x + ", " + from_y + "]");

			GameRes.party.core.gameover_condition = (int)GAMEOVER_COND.ANY_MEMBERS_DEFEATED;

			GameRes.party.Warp(10, 8);
			GameRes.party.SetDirection(1, 0);

			if (!_IsLocalFlagSet(FLAG.SURVIVOR_FOUND))
			{
				int event_x = 12;
				int event_y = 8;

				for (int y = 0; y < 2; y++)
				{
					for (int x = 0; x < 2; x++)
					{
						GameRes.map_data.data[event_x + x, event_y + y].ix_event = EVENT_BIT.TYPE_EVENT | 99;
						GameRes.map_data.data[event_x + x, event_y + y].act_type = ACT_TYPE.DEFAULT;
					}
				}
			}
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

		public override bool OnEnter(int event_id)
		{
			if (event_id > 0)
				return OnEnterById(event_id);

			return false;
		}

		public override void OnSign(int event_id)
		{
			if (event_id > 0)
			{
				OnSignById(event_id);
				return;
			}
		}

		public override void OnTalk(int event_id)
		{
			if (event_id > 0)
			{
				OnTalkById(event_id);
				return;
			}

			if (On(999, 999))
			{
			}

			if (OnArea(999, 999, 1001, 1001))
			{
			}
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

		public bool OnEnterById(int event_id)
		{
			bool processing_completed = true;

			switch (event_id)
			{
				case 1:
					Talk("이제 이곳으로는 올라 갈 수가 없다. 다른 길을 찾아야 한다.");
					break;

				case 2: // 위로 올라가는 계단 (54, 31)
					{
						Select_Init();

						Select_AddTitle("윗층으로 올라가는 유일한 계단이다.");
						Select_AddGuide("당신의 선택은 ---");
						Select_AddItem("위로 올라간다");
						Select_AddItem("잠시 더 기다린다");

						Select_Run
						(
							delegate (int selected)
							{
								switch (selected)
								{
									case 1:
										// 기화 이동, 마법의 횃불
										GameRes.player[3].specially_allowed_magic = 0x00000021;
										// 수정 구슬 제거
										GameRes.party.core.item[(int)PARTY_ITEM.CRYSTAL_BALL] = 0;
										GameRes.LoadMapEx("Prolog_B1");
										break;
									default:
										Talk("일행은 좀 더 생각해 보기로 하였다.");
										break;
								}
							}
						);
					}
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

		public void OnTalkById(int event_id)
		{
			bool processing_completed = true;

			switch (event_id)
			{
				case 1:
					Talk("@D....@@");
					break;
				case 2: // 집단 유골 x3
					if (_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_4))
						Talk("여기에는 인간의 시체가 있다. 잔혹하게 당한 형상을 보아서는 아까의 그 빨간 괴물의 짓이 틀림 없다.");
					else
						Talk("여기에는 인간의 시체가 있다. 무언가에게 잔혹하게 당한 것 같다.");
					break;
				case 3:
					Talk("붉은 몸을 가진 괴물은 아주 불안한듯 몸을 움직이며 적대적으로 우리를 노려 보고 있다.");
					break;
				default:
					Talk(String.Format("OnTalkById({0})", event_id));
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

		private bool _OnEvent(bool is_not_post, int event_id, out int post_event_id)
		{
			bool you_can_move_to_there = true;

			post_event_id = 0;
			bool processing_completed = true;

			int event_unique_id = event_id + ((is_not_post) ? 0 : POST_EVENT);

			switch (event_unique_id)
			{
				case 99:
					if (!_IsLocalFlagSet(FLAG.SURVIVOR_FOUND))
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F아! 저기 쓰러져 있소. 빨리 가봅시다.@@");

						RegisterKeyPressedAction(delegate ()
						{
							GameRes.PostEventId = event_id;
						}); PressAnyKey();
					}
					break;
				case (POST_EVENT | 99):
					bool stop = false;

					for (int y = -1; y <= 1; y++)
					{
						ACT_TYPE act_type = GameRes.map_data.GetActType(_curr_x + 1, _curr_y + y);
						stop |= (act_type == ACT_TYPE.TALK);
					}

					if (stop)
					{
						_SetLocalFlag(FLAG.SURVIVOR_FOUND);
						post_event_id = 98;
					}
					else
					{
						GameRes.party.Move(1, 0, true);
						post_event_id = event_id;
					}

					break;

				case (POST_EVENT | 98):
					Talk("쓰러진 사람은 의식이 없는 상태였다. 숨이 끊어지지는 않았고 상처도 없는 것으로 보아 여기에 갖힌 채로 탈진한 것으로 생각된다.");
					Talk("");
					Talk("의뢰인들은 익숙한 손놀림으로 그의 상태를 살피고 응급조치를 취했다.");

					RegisterKeyPressedAction(delegate ()
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F일단 큰 문제는 없어 보이오. 다만 좀 더 휴식을 취해서 그가 의식을 차릴때까지 기다려야 할 것 같소.@@");

						RegisterKeyPressedAction(delegate ()
						{
							int index = 3;
							if (!GameRes.player[index].IsValid())
							{
								GameRes.player[index] = ObjPlayer.CreateCharacter(NPC_3_NAME, GENDER.MALE, CLASS.ARCHIMAGE, 4);
								// 기화 이동, 주시자의 눈, 마법의 횃불
								GameRes.player[index].specially_allowed_magic = 0x00000023;

								GameRes.player[index].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.STAB, 1));
								GameRes.player[index].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(1));
								GameRes.player[index].SetEquipment(Yunjr.EQUIP.HEAD, Yunjr.ResId.CreateResId_Head(1));
								GameRes.player[index].SetEquipment(Yunjr.EQUIP.LEG, Yunjr.ResId.CreateResId_Leg(1));

								GameRes.player[index].hp = 0;
								GameRes.player[index].unconscious = 1;

								GameRes.player[index].Apply();

								GameObj.UpdatePlayerStatus();

								_SetLocalFlag(FLAG.JOIN_TO_SURVIVOR);

								Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_REST_HERE));

								if (GameRes.party.food < 4)
									GameRes.party.core.food = 4;
							}

						}); PressAnyKey();

					}); PressAnyKey();

					break;

				case 97:
					if (GameRes.player[3].IsAvailable())
					{
						Talk(GameRes.player[2].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F여기의 바위는 제가 힘을 써서 좀 치워 보겠습니다.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk(GameRes.player[2].GetName(ObjNameBase.JOSA.SUB2) + " 바위를 치우고 있는 동안 " + GameRes.player[3].GetName(ObjNameBase.JOSA.SUB) + " 이제야 제 정신을 차린 듯 하다.");
							Talk("");
							Talk("@F고맙소. 나의 믿음직한 동료들이 꼭 와 줄 것이라 믿었었소! 더 이상 구조신호를 보낼 마력이 없어져서 이제는 죽는구나 하는 생각도 했었지만 말이오.@@");

							RegisterKeyPressedAction(delegate ()
							{
								Talk(GameRes.player[3].GetName(ObjNameBase.JOSA.SUB) + " 내 쪽을 보며 이야기 했다.");
								Talk("");
								Talk("@F그런데, 저기 계신 분은 누구시오? 처음 뵙는 분이신 것 같구려.@@");
								
								RegisterKeyPressedAction(delegate ()
								{
									Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 자초지종을 설명하는 사이, 앞 쪽의 바위는 옆으로 다 치워졌다.");

									RegisterKeyPressedAction(delegate ()
									{
										// 바위를 치우고 이벤트를 만듦
										_SetLocalFlag(FLAG.REMOVE_ROCK_BY_NPC2);

									}); PressAnyKey();

								}); PressAnyKey();

							}); PressAnyKey();


						}); PressAnyKey();
					}
					else
					{
						Talk(GameRes.player[1].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F일단은 " + NPC_3_NAME + "의 의식을 돌려 놓는 것이 먼저인 것 같소. 의식이 돌아 올 때까지는 좀 쉬는 것이 좋겠소.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_REST_HERE));

							if (GameRes.party.food < 4)
								GameRes.party.core.food = 4;

						}); PressAnyKey();
					}
					break;

				case 96:
					if (!_IsLocalFlagSet(FLAG.FIRST_TALK_TO_SURVIVOR))
					{
						Talk(GameRes.player[3].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F여기는 내가 무너뜨려 놓은 곳이오. 괴물들을 피하기 위해 여기의 길을 막고 저기의 계단으로 올라가려 했지만 계단이 부셔져 있을 것이란 예상은 못했소. 그래서 난 꼼짝없이 여기에 갖히게 된 것이오.@@");

						_SetLocalFlag(FLAG.FIRST_TALK_TO_SURVIVOR);

						RegisterKeyPressedAction(delegate ()
						{
							Talk("@F바위는 어느 정도 치워졌으니 저 건너편으로 이동하면 되겠구려. 여기서 @B기화 이동@@ 마법을 사용하면 바로 건너편으로 순간 이동이 가능하오.@@");
							Talk("");
							Talk("@F우리들을 잠깐동안 기체처럼 만든 후에 벽을 통과하게 만드는 마법이라오.@@");

							RegisterKeyPressedAction(delegate ()
							{
								Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_ETHEREALIZE, NPC_3_NAME));

							}); PressAnyKey();

						}); PressAnyKey();
					}
					else
					{
						Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_ETHEREALIZE, NPC_3_NAME));
					}
					break;

				case 1: // 동굴의 괴물에 대한 이야기를 함. 지금쯤 갔을까?
					if (!_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_1))
					{
						Talk("@F나는 원래 이 부근에서 사라진 범죄자들의 뒤를 쫓고 있었소. 이 동굴에서 그들의 흔적을 찾았고 이제는 완전히 궁지로 몰았다고 생각했소. 그런데 그들보다 먼저 만난 것은 날개가 달린 붉은 괴물들이었소. 어떻게 여기에 들어 왔는지는 모르겠으나 그 발톱에 찢긴다면 생명은 보장 못할 것 같았소.@@");
						_SetLocalFlag(FLAG.CHAT_WITH_PARTY_ON_ROAD_1);
					}
					break;
				case 2: // 이 앞에 괴물가 있었소. 조심하시오.
					if (!_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_2))
					{
						Talk("@F바로 이 앞이 그 붉은 괴물들을 만난 곳이오. 그들의 살기를 느끼자마자 바로 이쪽으로 도망을 쳤고 그들은 한참동안 나를 더 따라 왔다오. 아직 그들이 있을지도 모르니 조심해서 앞으로 나아가야 할 것이오.@@");
						_SetLocalFlag(FLAG.CHAT_WITH_PARTY_ON_ROAD_2);
					}
					break;
				case 3: // 저 아래로 내려가면 내가 원래 내려왔던 계단이 있을 것이오.
					if (!_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_3))
					{
						Talk("@F이제 거의 다 왔소. 이쪽으로 좀 더 내려가면 내가 원래 내려왔던 계단이 있소. 오랜만에 @B라스트디치@@에서 저녁을 먹게 되겠구려.@@");
						_SetLocalFlag(FLAG.CHAT_WITH_PARTY_ON_ROAD_3);
					}
					break;
				case 4: // 이런! 아직 괴물들이 있소. 싸워서 이기는 것은 거의 불가능할 것이오. 우회로를 찾아 보오.
					if (!_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_4))
					{
						Talk("@F이런!! 아직 괴물들이 있소. 아직 눈치를 못챘을 때 도망가야 하오. 우리 4명으로는 도저히 승산이 없소!@@");
						_SetLocalFlag(FLAG.CHAT_WITH_PARTY_ON_ROAD_4);
						PressAnyKey();
					}
					break;
				case 5: // 강제 전투
					{
						OldStyleBattle.Init(new int[,] { { 1, 10 }, { 2, 10 }, { 3, 10 }, { 4, 10 }, { 5, 10 }, { 6, 10 } });
						for (int i = 0; i < CONFIG.MAX_ENEMY; i++)
							if (GameRes.enemy[i].IsValid())
								GameRes.enemy[i].attrib.name = String.Format("붉은 괴물 {0}", i + 1);
						OldStyleBattle.Run(true);
					}
					break;
				case 10: // 남쪽 공간 이동 위치
					if (_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_4))
					{
						Talk(GameRes.player[3].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F여기서 @B주시자의 눈@@을 써 보면 될 것 같소. 기화 이동이 가능 한 지점을 확인 할 수 있을 것이오.@@");

						RegisterKeyPressedAction(delegate ()
						{
							Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_EYES_OF_BEHOLDER, NPC_3_NAME));

						}); PressAnyKey();
					}
					break;
				case 11: // 동쪽 공간 이동 위치
					if (_IsLocalFlagSet(FLAG.CHAT_WITH_PARTY_ON_ROAD_4))
					{
						Talk(GameRes.player[3].GetName(ObjNameBase.JOSA.SUB2) + " 이야기 한다.");
						Talk("");
						Talk("@F여기서 @B주시자의 눈@@을 써 보면 될 것 같소. 기화 이동이 가능 한 지점을 확인 할 수 있을 것이오.@@");
					}
					break;
				case 12: // 의문의 녹슨 보물 상자
					Talk("보물 상자가 하나 놓여져 있지만 심하게 녹이 슬어 있다. 그냥 부수면 안의 내용물을 볼 수 있을 것 같지만 나와 같이 동행하는 젊잖으신 양반들은 그런 것을 싫어할 것 같다.");

					you_can_move_to_there = false;

					PressAnyKey();
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
