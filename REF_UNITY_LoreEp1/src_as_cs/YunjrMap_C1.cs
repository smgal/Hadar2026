using UnityEngine;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_C1 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "로어대륙";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.GROUND);
			CONFIG.BGM = "LoreGround1";
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			if (prev_map == "ORIGIN" || prev_map == "TOWN1")
			{
				GameRes.party.Warp(19, 11);
				GameRes.party.SetDirection(0, 1);

				Talk("대지는 황량하고 적막마저 감돈다.");
				Talk("");
				Talk("하지만 여행자들이 다니던 길이 나 있어, 최소한 황야에서 길을 잃지는 않을 것 같다.");
			}
			else if (prev_map == "TOWN2")
			{
				GameRes.party.Warp(75, 57);
				GameRes.party.SetDirection(0, 1);
			}
			else if (prev_map == "DEN1")
			{
				GameRes.party.Warp(17, 88);
				GameRes.party.SetDirection(1, 0);
			}
			else
			{
				GameRes.party.Warp(19, 11);
				GameRes.party.SetDirection(0, 1);
			}

			GameRes.map_data.data[19, 10].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[75, 56].act_type = ACT_TYPE.ENTER;
		}

		public override void OnUnload()
		{
		}

		public override bool OnEvent(int event_id, out int post_event_id)
		{
			post_event_id = 0;
			return true;
		}

		public override void OnPostEvent(int event_id, out int post_event_id)
		{
			post_event_id = 0;
		}
		public override bool OnEnter(int event_id)
		{
			if (On(19, 10))
			{
				Select_Init();

				Select_AddTitle("당신은 로어성의 입구에 서 있다.");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("로어성으로 들어 간다");
				Select_AddItem("들어가지 않겠다");

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
								Talk("로어성의 외관은 이전과 그다지 바뀌지는 않아 보였다.");
								break;
							default:
								Talk("당신은 별다른 선택을 하지는 않은 채로 그 자리에 서 있었다.");
								break;
						}
					}
				);
			}

			if (On(75, 56))
			{
				Select_Init();

				Select_AddTitle("여기는 라스트디치성이다.");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("들어 가 본다");
				Select_AddItem("들어가지 않겠다");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 1:
								GameRes.LoadMapEx("TOWN2");
								break;
							case 2:
								Talk("다시 로어성으로 돌아갈까?");
								break;
							default:
								Talk(".....");
								break;
						}
					}
				);
			}

			if (On(16, 88))
			{
				Select_Init();

				Select_AddTitle("여기가 메너스 광산이다");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("들어 가 본다");
				Select_AddItem("들어가지 않겠다");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 1:
								GameRes.LoadMapEx("DEN1");
								break;
							case 2:
								Talk("다시 로어성으로 돌아갈까?");
								break;
							default:
								Talk(".....");
								break;
						}
					}
				);
			}

			return false;
		}

		public override void OnSign(int event_id)
		{
		}

		public override void OnTalk(int event_id)
		{
		}
	}
}
