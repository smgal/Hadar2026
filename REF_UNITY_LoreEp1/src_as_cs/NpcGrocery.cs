
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	namespace Npc
	{
		class Grocery
		{
			private YunjrMap _associated_map;

			public Grocery(YunjrMap map, float exchange_rate_food_to_gold)
			{
				_associated_map = map;

				int UNIT_OF_FOOD = 10;

				_associated_map.Select_Init
				(
					"여기는 식료품점 입니다.",
					"몇개를 원하십니까 ? ---",
					null
				);

				_associated_map.Select_AddItem("필요 없습니다");
				for (int i = 1; i <= 5; i++)
					_associated_map.Select_AddItem(String.Format("{0} 인분: 금 {1} 개", i * UNIT_OF_FOOD, (int)(i * UNIT_OF_FOOD * exchange_rate_food_to_gold)));

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						if (selected <= 1)
						{
							_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.AS_YOU_WISH));
						}
						else
						{
							int added_food = (selected - 1) * UNIT_OF_FOOD;
							int needed_gold = (int)(added_food * exchange_rate_food_to_gold);

							if (GameRes.party.gold < needed_gold)
							{
								_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_GOLD));
								return;
							}

							GameRes.party.gold -= needed_gold;
							GameRes.party.core.food += added_food;

							GameRes.party.core.food = Math.Min(GameRes.party.core.food, 255);

							_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.THANK_YOU_VERY_MUCH));
						}
					}
				);
			}
		}
	}
}
