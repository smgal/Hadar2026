using UnityEngine;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_Z1 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "테스트용 성";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.TOWN);
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			if (prev_map == "ORIGIN" || prev_map == "TOWN1")
			{
				GameRes.party.Warp(30, 26);
				GameRes.party.SetDirection(0, 1);
			}
			else if (prev_map == "Map003")
			{
				GameRes.party.Warp(30, 29);
				GameRes.party.SetDirection(0, 1);
			}
			else
			{
				GameRes.party.Warp(30, 26);
				GameRes.party.SetDirection(0, 1);
			}

			Console.DisplaySmText("QQQQQQQQQ", true);
		}

		public override void OnUnload()
		{
		}

		public override bool OnEvent(int event_id, out int post_event_id)
		{
			bool you_can_move_to_there = true;

			post_event_id = 0;

			switch (event_id)
			{
				case 1:
					Select_Init();

					Select_AddTitle("여기에서는 전투모드의 테스트가 가능하다 (미완성)");
					Select_AddItem("준비가 되었다. 전투모드로 간다!");
					Select_AddItem("싫어요. 싫다니까요.");

					Select_Run
					(
						delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									OldStyleBattle.Init(new int[,] { { 1, 10 }, { 2, 10 }, { 3, 10 }, { 37, 10 }, { 5, 10 }, { 6, 10 } });
									GameRes.enemy[0].attrib.name = "자코";
									GameRes.enemy[1].attrib.name = "좀비1";
									GameRes.enemy[2].attrib.name = "좀비2";
									GameRes.enemy[3].attrib.name = "이블헌터";
									GameRes.enemy[4].attrib.name = "좀비3";
									GameRes.enemy[5].attrib.name = "좀비4";
									OldStyleBattle.Run(true);
									break;
								case 2:
									Talk("당신은 평화주의자였는가보다.");
									this._MoveBack();
									break;
								default:
									Talk("당신은 슬쩍 뒤로 물러섰다.");
									this._MoveBack();
									break;
							}
						}
					);
					break;

				case 2:
					Talk("@F일행은 여기서 500 골드를 얻었다.@@");
					GameRes.party.gold += 500;
					break;
			}

			return you_can_move_to_there;
		}

		public override void OnPostEvent(int event_id, out int post_event_id)
		{
			post_event_id = 0;
		}

		public bool OnEnterById(int event_id)
		{
			TalkDesc talk_desc;

			if (!GameRes.map_data.enters.TryGetValue(event_id, out talk_desc))
			{
				Debug.Assert(false);
				return false;
			}

			GameObj.SetHeaderText(LibUtil.SmTextToRichText(talk_desc.note), 5);

			switch (event_id)
			{
				case 1:
				{
					Select_Init();

					Select_AddTitle("여기는 다시 로어성으로 돌아가는 곳이다.");
					Select_AddGuide("당신의 선택은 ---");
					Select_AddItem("로어성으로 돌아간다");
					Select_AddItem("아직은 더 있고 싶다");

					Select_Run
					(
						delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									GameRes.LoadMapEx("TOWN1");
									break;
								case 2:
									Talk("당신은 주춤하다가는 그대로 서 있는다.");
									break;
								default:
									Talk("당신은 망설였다.");
									break;
							}
						}
					);
				}
				break;

				case 2:
				{
					Select_Init();

					Select_AddTitle("여기는 작은 크기의 맵을 테스트 하는 곳이다.");
					Select_AddGuide("당신의 선택은 ---");
					Select_AddItem("들어 간다");
					Select_AddItem("들어가지 않겠다");

					Select_Run
					(
						delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									GameRes.LoadMapEx("Map003");
									break;
								case 2:
									Talk("당신은 주춤하다가는 그대로 서 있는다.");
									break;
								default:
									Talk("당신은 망설였다.");
									break;
							}
						}
					);
				}
				break;
			}

			return false;

			//for (int i = 0; i < talk_desc.dialog.Count; i++)
			//	Talk(talk_desc.dialog[i]);
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

			// TODO: 푯말을 읽을 때 Header에 뭔가를 써 넣어야 하나?
			// GameObj.SetHeaderText(LibUtil.SmTextToRichText(talk_desc.note), 5);

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
		}

		public void OnTalkById(int event_id)
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

		public override void OnTalk(int event_id)
		{
			if (event_id > 0)
			{
				OnTalkById(event_id);
				return;
			}

			if (On(23, 21) || On(23, 22))
			{
				if (Flag_IsSet(100))
					GameObj.SetHeaderText(LibUtil.SmTextToRichText("네크로맨서\n<color=#FFBF40FF>키가 참 크다.</color>"), 5);
				else
					GameObj.SetHeaderText(LibUtil.SmTextToRichText("어떤 키 큰 사람이 서 있다."), 5);

				if (Not(Flag_IsSet(100)))
				{
					Talk("나의 이름은 네크로맨서요.");
					Flag_Set(100);
				}
				else
				{
					Talk("말 걸지 마시오.");
				}
			}
		}
	}
}
