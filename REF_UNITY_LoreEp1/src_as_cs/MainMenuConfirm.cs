
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class MainMenuConfirm : MonoBehaviour
	{
		public enum MESSAGE
		{
			DEAD_ON_FIELD,
			DEAD_ON_BATTLE
		}

		public Text Title;
		public Text Location;

		public void AssignMessageAndLocation(MESSAGE message_type, string location)
		{
			switch (message_type)
			{
				case MESSAGE.DEAD_ON_FIELD:
					{
						bool someone_alive = false;

						foreach (var player in GameRes.player)
						{
							if (player.IsValid() && player.IsAvailable())
							{
								someone_alive = true;
								break;
							}
						}

						if (someone_alive)
						{
							if (GameRes.player[0].IsAvailable())
								Title.text = "일행 중 일부가 더 이상\n모험을 할 수 없는 상태이다.";
							else
								Title.text = "주인공은 더 이상 모험을\n할 수 없는 상태이다.";
						}
						else
						{
							// 전멸
							Title.text = "일행은 모험중에\n 모두 목숨을 잃었다.";
						}
					}
					break;
				case MESSAGE.DEAD_ON_BATTLE:
					Title.text = "일행은 모두 전투에서 패했다!!";
					break;
			}

			Location.text = location;
		}

		public void OnOkClick()
		{
			// 다른 문제가 생겼을 때의 디폴트
			GameRes.GameOverCondition = GAMEOVER_CONDITION.EXIT_REQUIRED;

			GameObject go = GameObject.Find("GameEventMain");
			if (go != null)
			{
				GameEventMain game_event = go.GetComponent<GameEventMain>();
				if (game_event != null)
				{
					GameRes.GameOverCondition = GAMEOVER_CONDITION.DEAD_ON_FIELD_LOAD;
					game_event.OnMainMenuLoadClick();
				}
			}
		}

	}
}
