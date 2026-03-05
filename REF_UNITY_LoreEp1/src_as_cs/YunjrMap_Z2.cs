using UnityEngine;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_Z2 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "작은 맵 테스트";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.TOWN);
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			if (prev_map == "Map002")
			{
				GameRes.party.Warp(10, 6);
				GameRes.party.SetDirection(0, 1);
			}
			else
			{
				GameRes.party.Warp(10, 8);
				GameRes.party.SetDirection(0, 1);
			}
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

					Select_AddTitle("여기는 다시 테스트성으로 돌아가는 곳이다.");
					Select_AddGuide("당신의 선택은 ---");
					Select_AddItem("테스트성으로 돌아간다");
					Select_AddItem("아직은 더 있고 싶다");

					Select_Run
					(
						delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									GameRes.LoadMapEx("Map002");
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
		}
	}
}
