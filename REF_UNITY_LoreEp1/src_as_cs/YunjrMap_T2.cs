using UnityEngine;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_T2 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "라스트디치";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.TOWN);
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			if (prev_map == "ORIGIN" || prev_map == "TOWN1")
			{
				Talk("여기는 어디인가? 나는 누구인가?");

				GameRes.party.Warp(37, 6);
				GameRes.party.SetDirection(0, 1);
			}
			else
			{
				GameRes.party.Warp(37, 68);
				GameRes.party.SetDirection(0, -1);
			}

			// 성의 입구
			GameRes.map_data.data[36, 69].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[37, 69].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[38, 69].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[39, 69].act_type = ACT_TYPE.ENTER;

			// 성의 위쪽 좌->우 워프 지역
			GameRes.map_data.data[29,  7].act_type = ACT_TYPE.EVENT;
			GameRes.map_data.data[29,  8].act_type = ACT_TYPE.EVENT;
			GameRes.map_data.data[29,  9].act_type = ACT_TYPE.EVENT;
			GameRes.map_data.data[29, 10].act_type = ACT_TYPE.EVENT;

			// 성의 위쪽 우->좌 워프 지역
			GameRes.map_data.data[31,  7].act_type = ACT_TYPE.EVENT;
			GameRes.map_data.data[31,  8].act_type = ACT_TYPE.EVENT;
			GameRes.map_data.data[31,  9].act_type = ACT_TYPE.EVENT;
			GameRes.map_data.data[31, 10].act_type = ACT_TYPE.EVENT;
		}

		public override void OnUnload()
		{
		}

		public override bool OnEvent(int event_id, out int post_event_id)
		{
			bool you_can_move_to_there = true;

			post_event_id = 0;

			if (OnArea(29, 7, 29, 10))
			{
				if (GameRes.party.faced.dx == 1)
					GameRes.party.WarpRel(3, 0);
			}

			if (OnArea(31, 7, 31, 10))
			{
				if (GameRes.party.faced.dx == -1)
					GameRes.party.WarpRel(-3, 0);
			}

			return you_can_move_to_there;
		}

		public override void OnPostEvent(int event_id, out int post_event_id)
		{
			post_event_id = 0;
		}

		public override bool OnEnter(int event_id)
		{
			if (OnArea(36, 5, 39, 5))
			{
				Select_Init();

				Select_AddTitle("다시 로어성으로 들어가겠습니까?");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("안으로 들어간다.");
				Select_AddItem("들어가지는 않는다");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
						case 1:
							GameRes.LoadMapEx("TOWN1");
							break;
						}
					}
				);
			}

			if (OnArea(36, 69, 39, 69))
			{
				GameRes.LoadMapEx("GROUND1");
				return true;
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
