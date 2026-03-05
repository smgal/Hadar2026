
using UnityEngine;
using System;
using System.Collections;

namespace Yunjr
{
	public class MainMenu
	{
		public static bool IsRunning()
		{
			return (GameRes.GameState == GAME_STATE.IN_SELECTING_MENU);
		}

		public static void Cancel()
		{
			if (IsRunning())
			{
				GameRes.GameState = GAME_STATE.IN_MOVING;
				GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
				Console.DisplayRichText("");
			}
		}

		public static void Run()
		{
			GameRes.selection_list.Init();
			GameRes.selection_list.AddGuide("당신의 명령을 고르시오 ===>\n");
			GameRes.selection_list.AddItem("일행의 상황을 본다      [P]");
			GameRes.selection_list.AddItem("개인의 상황을 본다      [V]");
			GameRes.selection_list.AddItem("무기 장착 및 해제       [W]");
			GameRes.selection_list.AddItem("능력을 사용한다         [C]");
			GameRes.selection_list.AddItem("물건을 사용한다         [U]");
			GameRes.selection_list.AddItem("여기서 쉰다             [R]");
			GameRes.selection_list.AddItem("게임 선택 상황          [G]");

			GameRes.selection_list.Run
			(
				delegate ()
				{
					switch (GameRes.selection_list.ix_curr)
					{
					case 1:
						Console.DisplayPartyAllStatus();
						break;
					case 2:
						Console.SelectPlayer(
							"능력을 보고싶은 인물을 선택하시오",
							delegate ()
							{
								Console.DisplayPlayer(GameRes.selection_list.ix_curr - 1, true);
							}
						);
						break;
					case 3:
						// 원래는 이 메뉴였지만 이제는 메뉴로 QuickView를 보는 것은 불가능 함
						// Console.DisplayQuickView();
						GameEventMain.ShowItemManagementView();
						break;
					case 4:
						Console.UseAbility();
						break;
					case 5:
						Console.UseItem();
						break;
					case 6:
						Console.RestHere();
						break;
					case 7:
						GameEventMain.ShowMainMenu();
						break;
					}
				}
			);
		}
	}
}
