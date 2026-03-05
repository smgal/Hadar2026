using UnityEngine;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

namespace Yunjr
{
	public class YunjrMap_D2 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			return "지하동굴";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.DEN);
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			GameRes.party.Warp(19, 26);
			GameRes.party.SetDirection(-1, 0);
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
			if (On(20, 26))
				GameRes.LoadMapEx("DEN1");

			if (On(6, 6))
				GameRes.LoadMapEx("DEN2");
			if (On(5, 43))
				GameRes.LoadMapEx("DEN2");
			if (On(45, 37))
				GameRes.LoadMapEx("DEN2");
			if (On(39, 45))
				GameRes.LoadMapEx("DEN2");

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
