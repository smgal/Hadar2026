
using UnityEngine;
using System;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap__Dummy : YunjrMap
	{
		private enum FLAG
		{
			I_KNOW_THIS_PLACE_WELL = 0
		}

		private enum VARIABLE
		{
			LEVEL_OF_KNOWING_WELL_HERE = 0
		}

		public override string GetPlaceName(byte degree_of_well_known)
		{
			if (degree_of_well_known > 0)
				return "더미맵";
			else
				return "어디지?";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.TOWN);
			CONFIG.TILE_BG_DEFAULT = 44;
			CONFIG.BGM = "DefaultBgm";
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			Debug.Log("YunjrMap::OnLoad() from [" + prev_map + ", " + from_x + ", " + from_y + "]");

			GameRes.party.core.gameover_condition = (int)GAMEOVER_COND.COMPLETELY_DEFEATED;

			if (prev_map != "NoWhere")
			{
				Debug.Log("まさか!");
			}
		}

		public override void OnUnload()
		{
		}

		public override bool OnEvent(int event_id, out int post_event_id)
		{
			bool you_can_move_to_there = true;

			post_event_id = 0;
			bool processing_completed = true;

			switch (event_id)
			{
				default:
					Talk(String.Format("OnEvent({0})", event_id));
					processing_completed = false;
					break;
			}

			if (!processing_completed)
			{
			}

			return you_can_move_to_there;
		}

		public override void OnPostEvent(int event_id, out int post_event_id)
		{
			post_event_id = 0;
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
	}
}
/*
RegisterKeyPressedAction(delegate ()
{
	Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.MANUAL_MAGIC_TORCH));
}); PressAnyKey();
*/
