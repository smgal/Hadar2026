
#pragma warning disable 0162

using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using System.Collections;
using System.IO;

namespace Yunjr
{
	public class GameEventMain : MonoBehaviour
	{
		// key status
		private static bool _click_arrow_button_up = false;
		private static bool _click_arrow_button_down = false;

		private static bool _press_arrow_button_up = false;
		private static bool _press_arrow_button_down = false;
		private static bool _press_arrow_button_left = false;
		private static bool _press_arrow_button_right = false;

		private static uint _prev_unique_id = 0;

		private static int _focused_player = -1;
		private UIWidgets.Popup _player_popup = null;

		public UIWidgets.Popup popup_main_menu;
		public UIWidgets.Popup popup_player_menu;

		void Start()
		{
			Debug.Log("GameEventMain::Start()");
		}

		public static uint PrevUniqueId
		{
			get { return _prev_unique_id; }
			set { _prev_unique_id = value; }
		}

		public static void ResetArrowKey()
		{
			_click_arrow_button_up = false;
			_click_arrow_button_down = false;

			_press_arrow_button_up = false;
			_press_arrow_button_down = false;
			_press_arrow_button_left = false;
			_press_arrow_button_right = false;

			_prev_unique_id = 0;
		}

		public static void ClearPrevEvent()
		{
			_prev_unique_id = 0;
		}

		public static bool IsClicked(BUTTON button)
		{
			bool result = false;

			switch (button)
			{
			case BUTTON.ARROW_UP:
				if (_click_arrow_button_up)
				{
					_click_arrow_button_up = false;
					result = true;
				}
				break;
			case BUTTON.ARROW_DOWN:
				if (_click_arrow_button_down)
				{
					_click_arrow_button_down = false;
					result = true;
				}
				break;
			case BUTTON.MENU:
			case BUTTON.ARROW_LEFT:
			case BUTTON.ARROW_RIGHT:
			case BUTTON.OK:
			case BUTTON.CANCEL:
			default:
				Debug.Log("IsClicked(button) not supported");
				break;
			}

			return result;
		}

		public static bool IsPressing(BUTTON button)
		{
			bool result = false;

			switch (button)
			{
			case BUTTON.ARROW_UP:
				result = _press_arrow_button_up;
				break;
			case BUTTON.ARROW_DOWN:
				result = _press_arrow_button_down;
				break;
			case BUTTON.ARROW_LEFT:
				result = _press_arrow_button_left;
				break;
			case BUTTON.ARROW_RIGHT:
				result = _press_arrow_button_right;
				break;
			case BUTTON.MENU:
			case BUTTON.OK:
			case BUTTON.CANCEL:
			default:
				Debug.Log("IsPressing(button) not supported");
				break;
			}

			return result;
		}

		public void OnButtonMenuClick()
		{
			if (CONFIG.ENABLE_GUI_LOG)
				Debug.Log("OnButtonMenuClick");

#if true
			GameEventMainMenu main_menu = popup_main_menu.GetComponent<GameEventMainMenu>();
			main_menu.Show();
#else
			// 이전 스타일
			GameEventMain.ShowMainMenu();

#endif
		}

		public void OnButtonMenuTestClick()
		{
			if (CONFIG.ENABLE_GUI_LOG)
				Debug.Log("OnButtonMenuTestClick");

			if (!MainMenu.IsRunning())
				MainMenu.Run();
			else
				MainMenu.Cancel();
		}

		public void OnButtonOkClick()
		{
			if (CONFIG.ENABLE_GUI_LOG)
				Debug.Log("OnButtonOkClick");

			switch (GameRes.GameState)
			{
			case GAME_STATE.IN_MOVING:
				break;
			case GAME_STATE.IN_WAITING_FOR_OK_CANCEL:
				GameRes.GameState = GAME_STATE.JUST_OK_PRESSED;
				break;
			case GAME_STATE.IN_WAITING_FOR_KEYPRESS:
				GameRes.GameState = GAME_STATE.JUST_KEYPRESSED;
				break;
			case GAME_STATE.IN_PICKING_SENTENCE:
				GameRes.GameState = GAME_STATE.JUST_PICKED;
				break;
			case GAME_STATE.IN_SELECTING_MENU:
				GameRes.GameState = GAME_STATE.JUST_SELECTED;
				break;
			case GAME_STATE.IN_SELECTING_SPIN:
				GameRes.GameState = GAME_STATE.JUST_SELECTED_FOR_SPIN;
				break;
			case GAME_STATE.IN_BATTLE:
				GameRes.GameState = GAME_STATE.JUST_BATTLE_COMMAND_SELECTED;
				break;
			}
		}

		public void OnButtonCancelClick()
		{
			switch (GameRes.GameState)
			{
			case GAME_STATE.IN_WAITING_FOR_OK_CANCEL:
				GameRes.GameState = GAME_STATE.JUST_CANCEL_PRESSED;
				break;
			case GAME_STATE.IN_PICKING_SENTENCE:
				GameRes.selection_list.ix_curr = 0;
				GameRes.GameState = GAME_STATE.JUST_PICKED;
				break;
			case GAME_STATE.IN_SELECTING_MENU:
				MainMenu.Cancel();
				break;
			case GAME_STATE.IN_SELECTING_SPIN:
				GameRes.selection_spin.Cancel();
				break;
			}
		}

		public void SaveScreenShot(string file_name)
		{
			if (Application.isEditor)
			{
				ScreenCapture.CaptureScreenshot(file_name);
			}
			else
			{
				Texture2D tex = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, true);
				tex.ReadPixels(new Rect(0f, 0f, Screen.width, Screen.height), 0, 0, true);
				tex.Apply();
				byte[] captureScreenShot = tex.EncodeToPNG();
				DestroyImmediate(tex);
				File.WriteAllBytes(file_name, captureScreenShot);
			}
		}

		public void OnButtonCheatClick()
		{
			// 원작의 binary 지도 데이터를 RPG maker의 json으로 저장할 때 사용된다.
			// LibMapEx.SaveMap(GameRes.map_data, "menace_m.json");

			// 스크린샷을 저장하고 싶을 때
			// SaveScreenShot("screen_shot.png");
			// return;

			int x = Mathf.RoundToInt(GameRes.party.pos.x + GameRes.party.faced.dx);
			int y = Mathf.RoundToInt(GameRes.party.pos.y + GameRes.party.faced.dy);

			// ??
			// GameRes.map.data[x, y].ix_sprite = CONFIG.TILE_BG_DEFAULT;
			// GameRes.map.data[x, y].act_type = ACT_TYPE.DEFAULT;
			GameRes.map_data.data[x, y].ix_tile = 0;
			GameRes.map_data.data[x, y].ix_obj1 = 0;
			GameRes.map_data.data[x, y].ix_event = EVENT_BIT.NONE;
			GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;

			GameRes.party.Move(GameRes.party.faced.dx, GameRes.party.faced.dy);
		}

		public void OnArrowButtonUpPress()
		{
			if (!_press_arrow_button_up)
				_click_arrow_button_up = true;

			_press_arrow_button_up = true;
			_press_arrow_button_down = false;
			_press_arrow_button_left = false;
			_press_arrow_button_right = false;
		}

		public void OnArrowButtonUpRelease()
		{
			_press_arrow_button_up = false;
		}

		public void OnArrowButtonDownPress()
		{
			if (!_press_arrow_button_down)
				_click_arrow_button_down = true;

			_press_arrow_button_up = false;
			_press_arrow_button_down = true;
			_press_arrow_button_left = false;
			_press_arrow_button_right = false;
		}

		public void OnArrowButtonDownRelease()
		{
			_press_arrow_button_down = false;
		}

		public void OnArrowButtonLeftPress()
		{
			_press_arrow_button_up = false;
			_press_arrow_button_down = false;
			_press_arrow_button_left = true;
			_press_arrow_button_right = false;
		}

		public void OnArrowButtonLeftRelease()
		{
			_press_arrow_button_left = false;
		}

		public void OnArrowButtonRightPress()
		{
			_press_arrow_button_up = false;
			_press_arrow_button_down = false;
			_press_arrow_button_left = false;
			_press_arrow_button_right = true;
		}

		public void OnArrowButtonRightRelease()
		{
			_press_arrow_button_right = false;

			switch (GameRes.GameState)
			{
				case GAME_STATE.IN_WAITING_FOR_OK_CANCEL:
					GameRes.GameState = GAME_STATE.JUST_OK_PRESSED;
					break;
			}
		}

		public static void ShowMainMenu()
		{
			Console.Clear();
			GameObj.SetButtonGroup(BUTTON_GROUP.DISABLE);
			GameObj.SetMainMenuOnOff(MAIN_MENU.MAIN);
		}

		public static void HideMainMenu()
		{
			GameObj.SetMainMenuOnOff();
			GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
		}

		public static void ShowItemManagementView(int ix_player = -1)
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				Console.Clear();

				GameObj.canvas[0].SetActive(false);
				GameObj.canvas[1].SetActive(true);

				GameObject go = GameObject.Find("GameEventEquipment");
				if (go != null)
				{
					GameEventEquipment game_event = go.GetComponent<GameEventEquipment>();
					if (game_event != null)
						game_event.Reset(ix_player);
				}
			}
		}

		public void OnMainMenuItemManagementClick()
		{
			ShowItemManagementView();
		}

		public void OnEndOfItemManagementClick()
		{
			GameObj.canvas[0].SetActive(true);
			GameObj.canvas[1].SetActive(false);
			GameEventMain.HideMainMenu();
		}

		public void OnMainMenuResumeClick()
		{
			GameEventMain.HideMainMenu();
		}

		public void OnMainMenuGameOptionClick()
		{
			GameObj.SetMainMenuOnOff(MAIN_MENU.GAME_OPTION);

			// Left Handed 옵션
			{
				GameObject obj = GameObject.FindGameObjectWithTag("ToggleLeftHanded");
				if (obj != null)
				{
					Toggle toggle = obj.GetComponent<Toggle>();
					if (toggle != null)
					{
						int left_handed = PlayerPrefs.GetInt(CONFIG.PREF_STR_OPTION_LEFT_HANDED, CONFIG.PREF_DEFAULT_OPTION_LEFT_HANDED);
						toggle.isOn = (left_handed != 0);
					}
				}
			}

			// Sound On 옵션
			{
				GameObject obj = GameObject.FindGameObjectWithTag("ToggleSoundOn");
				if (obj != null)
				{
					Toggle toggle = obj.GetComponent<Toggle>();
					if (toggle != null)
					{
						int sound_on = PlayerPrefs.GetInt(CONFIG.PREF_STR_OPTION_SOUND_ON, CONFIG.PREF_DEFAULT_OPTION_SOUND_ON);
						toggle.isOn = (sound_on != 0);
					}
				}
			}

			// Cheat On 옵션
			{
				GameObject obj = GameObject.FindGameObjectWithTag("ToggleCheat");
				if (obj != null)
				{
					Toggle toggle = obj.GetComponent<Toggle>();
					if (toggle != null)
					{
						int cheat_on = PlayerPrefs.GetInt(CONFIG.PREF_STR_OPTION_CHEAT_ON, CONFIG.PREF_DEFAULT_OPTION_CHEAT_ON);
						toggle.isOn = (cheat_on != 0);
					}
				}
			}
		}

		public void OnMainMenuLoadClick()
		{
			MainMenuLoad main_menu_load = (MainMenuLoad)GameObj.panel_main_menus[(int)MAIN_MENU.GAME_LOAD].GetComponent<MainMenuLoad>();
			main_menu_load.UpdateSlotInfo();

			GameObj.SetMainMenuOnOff(MAIN_MENU.GAME_LOAD);
		}

		public void OnMainMenuSaveClick()
		{
			MainMenuSave main_menu_save = (MainMenuSave)GameObj.panel_main_menus[(int)MAIN_MENU.GAME_SAVE].GetComponent<MainMenuSave>();
			main_menu_save.UpdateSlotInfo();

			GameObj.SetMainMenuOnOff(MAIN_MENU.GAME_SAVE);
		}

		public void OnMainMenuQuitClick(bool try_to_save)
		{
			if (try_to_save)
				MainMenuSave.SaveFile(0);

			Application.Quit();
		}

		public void OnGameOptionLeftHandedClick(bool isOn)
		{
			PlayerPrefs.SetInt(CONFIG.PREF_STR_OPTION_LEFT_HANDED, (isOn) ? 1 : 0);
			GameObj.SetButtonGroupHanded(!isOn);
		}

		public void OnGameOptionSoundOnClick(bool isOn)
		{
			PlayerPrefs.SetInt(CONFIG.PREF_STR_OPTION_SOUND_ON, (isOn) ? 1 : 0);
			GameObj.SetBgmMode(isOn);
		}

		public void OnGameOptionCheatOnClick(bool isOn)
		{
			PlayerPrefs.SetInt(CONFIG.PREF_STR_OPTION_CHEAT_ON, (isOn) ? 1 : 0);
			GameObj.SetCheatMode(isOn);
		}

		public void OnGameOptionQuitClick()
		{
			OnMainMenuResumeClick();
		}

		public void OnGameLoadCancelClick()
		{
			if (GameRes.GameOverCondition == GAMEOVER_CONDITION.DEAD_ON_FIELD_LOAD)
			{
				GameRes.GameOverCondition = GAMEOVER_CONDITION.EXIT_REQUIRED;
				OnMainMenuQuitClick(false);
			}
			else
			{
				OnMainMenuResumeClick();
			}
		}

		public void OnGameSaveCancelClick()
		{
			OnMainMenuResumeClick();
		}

		////////////////////////////////////////////////////////////////////////

		public void OnPlayerStatusClick(int ix_player)
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				if (ix_player < 0 || ix_player >= CONFIG.MAX_PLAYER || !GameRes.player[ix_player].IsValid())
					return;

				Console.Clear();
				// Console.DisplayPlayer(ix_player, false);
				// GameRes.player[ix_player].DisplayStatusOnConsole();

				// Move focus to a valid player
				{
					_focused_player = ix_player;

					GameObject ga_focus = GameObj.player_focus[0];
					GameObject ga_origin1 = GameObject.Find("PlayerStatus_1_1");
					GameObject ga_origin2 = GameObject.Find("PlayerStatus_1_2");

					Debug.Assert(ga_focus != null);
					Debug.Assert(ga_origin1 != null);
					Debug.Assert(ga_origin2 != null);

					{
						Vector3 pos = ga_origin1.transform.localPosition;
						float line_to_line_distance = ga_origin2.transform.localPosition.y - ga_origin1.transform.localPosition.y;
						pos.y = ga_origin1.transform.localPosition.y + line_to_line_distance * ix_player;
						ga_focus.transform.localPosition = pos;
					}

					GameObj.player_focus[0].SetActive(true);

#if true
					GameEventPlayerMenu player_menu = popup_player_menu.GetComponent<GameEventPlayerMenu>();
					player_menu.Show(_focused_player);
#else
					_player_popup = popup_player_menu.Clone();
					
					_player_popup.name = "PlayerMenu";
					_player_popup.Show
					(
						title: GameRes.player[_focused_player].GetName(),
						//position: new Vector3(-31, 236),
						modal: true,
						modalColor: new Color(0.0f, 0.0f, 0.0f, 0.6f)
					);
#endif
/*					
					popup_player_menu.TemplateName = "PlayerMenu";
					popup_player_menu.Show
					(
						position: new Vector3(27, 324),
						modal: true,
						modalColor: new Color(0.0f, 0.0f, 0.0f, 0.0f)
					);
*/
				}
			}
		}

		private enum SHORTCUT
		{
			QUICK_VIEW = 0,
			PARTY_INFO = 1,
			USE_ABILITY = 2,
			USE_ITEM = 3
		};

		public void OnShortCutClick(int shortcut)
		{
			if (GameRes.GameState != GAME_STATE.IN_MOVING)
				return;

			switch ((SHORTCUT)shortcut)
			{
				case SHORTCUT.QUICK_VIEW:
					this.OnShortCut_QuickView();
					break;
				case SHORTCUT.PARTY_INFO:
					this.OnShortCut_PartyInfo();
					break;
				case SHORTCUT.USE_ABILITY:
					this.OnShortCut_UseAbility();
					break;
				case SHORTCUT.USE_ITEM:
					this.OnShortCut_UseItem();
					break;
			}
		}

		public void OnShortCut_PartyInfo()
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				Console.Clear();
				Console.DisplayPartyStatus();
			}
		}

		public void OnShortCut_QuickView()
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				Console.Clear();
				Console.DisplayQuickView();
			}
		}

		public void OnShortCut_UseAbility()
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				Console.Clear();
				Console.UseAbility();
			}
		}

		public void OnShortCut_UseItem()
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				Console.Clear();
				Console.UseItem();
			}
		}

		public void OnShortCut_RestHere()
		{
			if (GameRes.GameState == GAME_STATE.IN_MOVING)
			{
				Console.Clear();
				Console.RestHere();
			}
		}

		private void _ClosePlayerPopup()
		{
			_focused_player = -1;

			if (_player_popup != null)
				_player_popup.Close();

			//popup_player_menu.Close();
			//GameObj.player_focus[0].SetActive(false);
		}

		public void OnPlayerPopup_PlayerInfo()
		{
			if (_focused_player >= 0)
				Console.DisplayPlayerInfo(_focused_player);

			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_PlayerStatus()
		{
			if (_focused_player >= 0)
				Console.DisplayPlayerStatus(_focused_player);

			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_Cast()
		{
			if (_focused_player >= 0)
				Console.UseAbility(GameRes.player[_focused_player]);

			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_ESP()
		{
			if (_focused_player >= 0)
				GameRes.party.UseEsp(GameRes.player[_focused_player]);

			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_Use()
		{
			if (_focused_player >= 0)
				Console.UseItem(GameRes.player[_focused_player]);

			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_Equip()
		{
			if (_focused_player >= 0)
			{
				// TODO: _focused_player를 적용 해야 함
				ShowItemManagementView(_focused_player);
			}

			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_PartyInfo()
		{
			OnShortCut_PartyInfo();
			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_PartyItems()
		{
			Console.DisplayPartyItems();
			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_QuickView()
		{
			OnShortCut_QuickView();
			_ClosePlayerPopup();
		}

		public void OnPlayerPopup_RestHere()
		{
			OnShortCut_RestHere();
			_ClosePlayerPopup();
		}
	}
}
