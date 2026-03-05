using UnityEngine;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_D1 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "메너스";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.DEN);
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			if (prev_map == "ORIGIN" || prev_map == "TOWN1")
			{
				Talk("여기는 광산 메너스이다.");

				GameRes.party.Warp(25, 44);
				GameRes.party.SetDirection(0, -1);
			}
			else if (prev_map == "DEN2")
			{
				GameRes.party.Warp(42, 40);
				GameRes.party.SetDirection(-1, 0);
			}
			else
			{
				GameRes.party.Warp(25, 44);
				GameRes.party.SetDirection(0, -1);
			}

			// 성의 입구
			GameRes.map_data.data[24, 45].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[25, 45].act_type = ACT_TYPE.ENTER;
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
			if (On(43, 40))
				GameRes.LoadMapEx("DEN2");

			if (OnArea(24, 44, 25, 45))
			{
				Select_Init();

				Select_AddTitle("여기는 로어대륙으로 나가는 출구이다.");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("일단 나가본다");
				Select_AddItem("조금 더 있는다");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 1:
								GameRes.LoadMapEx("GROUND1");
								break;
							case 2:
								Talk("일행은 다시 황야로 나섰다");
								break;
							default:
								Talk("당신은 그냥 그 자리에 서 있다");
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
