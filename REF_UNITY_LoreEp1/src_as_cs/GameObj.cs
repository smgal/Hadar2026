using UnityEngine;
using UnityEngine.UI;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public enum BUTTON
	{
		MENU = 0,
		ARROW_UP,
		ARROW_DOWN,
		ARROW_LEFT,
		ARROW_RIGHT,
		OK,
		CANCEL,
		MAX
	}

	public enum BUTTON_GROUP
	{
		MOVE_MENU,
		OK,
		OK_CANCEL,
		OK_CANCEL_UP_DOWN,
		OK_UP_DOWN,
		RIGHT_CANCEL,
		DISABLE,
		MAX
	}

	public enum MAIN_MENU
	{
		MAIN,
		GAME_OPTION,
		GAME_LOAD,
		GAME_SAVE,
		GAME_SAVE_DIALOG,
		POPUP_CONFIRM,
		MAX
	}

	public class GameObj : MonoBehaviour
	{
		private const float DIMMING_FACTOR = 0.2f;

		public GameObject m_screen_fg;
		public GameObject m_obj_tile;
		public GameObject m_player;

		public static Text text_header;
		public static int  text_header_duration;
		public static Text text_dialog;

		public static GameObject[] canvas = new GameObject[3];

		public static Text[,] player_status = new Text[2, CONFIG.MAX_PLAYER];
		public static GameObject[] player_focus = new GameObject[2];

		public static Text text_debug;
		public static Text text_debug_fps;

		public static Image mini_map;

		public static GameObject[] panel_main_menus;

		public static GameObject panel_map;
		public static GameObject panel_battle;

		public static GameObject panel_button_group_right_handed;
		public static GameObject panel_button_group_left_handed;

		public static GameObject[] panel_button_cheat = new GameObject[2];

		public static TilingEngine tiling_engine;

		public static GameObject[,] panel_buttons = new GameObject[2, (int)BUTTON.MAX];

		public static StringComposer text_dialog_prepared = new StringComposer();

		// 아직 검증은 안 되었음
		// 기기 화면 비율에 맞춰서 카메라 viewport를 조절하여 양옆에 까만 띠를 붙임
		private void setupCamera()
		{
			// 타겟 화면 비율
			float targetWidthAspect = 16.0f;
			float targetHeightAspect = 9.0f;

			// 메인 카메라
			Camera mainCamera = Camera.main;

			mainCamera.aspect = targetWidthAspect / targetHeightAspect;

			float widthRatio = (float)Screen.width / targetWidthAspect;
			float heightRatio = (float)Screen.height / targetHeightAspect;

			float heightadd = ((widthRatio / (heightRatio / 100)) - 100) / 200;
			float widthtadd = ((heightRatio / (widthRatio / 100)) - 100) / 200;

			// 16_10비율보다 가로가 짦다면(4_3 비율)
			// 16_10비율보다 세로가 짧다면(16_9 비율)
			// 시작 지점을 0으로 만들어준다
			if (heightRatio > widthRatio)
				widthtadd = 0.0f;
			else
				heightadd = 0.0f;

			mainCamera.rect = new Rect(
				mainCamera.rect.x + Mathf.Abs(widthtadd),
				mainCamera.rect.y + Mathf.Abs(heightadd),
				mainCamera.rect.width + (widthtadd * 2),
				mainCamera.rect.height + (heightadd * 2));
		}

		void Start()
		{
			Debug.Log("GameObj::Start()");

			// 세로가 더 긴 경우 대응 (예를 들어, iPhoneX = 1127x2346)
			if (CONFIG.GUI_SCALE < 1.0f)
			{
				{
					Vector3 local_scale = m_screen_fg.transform.localScale;

					local_scale.x *= (float)CONFIG.GUI_SCALE;
					local_scale.y *= (float)CONFIG.GUI_SCALE;

					m_screen_fg.transform.transform.localScale = local_scale;
				}

				{
					Vector3 local_scale = m_obj_tile.transform.localScale;

					local_scale.x *= (float)CONFIG.GUI_SCALE;
					local_scale.y *= (float)CONFIG.GUI_SCALE;

					m_obj_tile.transform.transform.localScale = local_scale;
				}

				{
					Vector3 local_scale = m_player.transform.localScale;

					local_scale.x *= (float)CONFIG.GUI_SCALE;
					local_scale.y *= (float)CONFIG.GUI_SCALE;

					m_player.transform.transform.localScale = local_scale;

					Vector3 local_position = m_player.transform.localPosition;
					local_position.x *= CONFIG.GUI_SCALE;
					local_position.y *= CONFIG.GUI_SCALE;

					m_player.transform.localPosition = local_position;
				}
			}

			{
				GameObject canvas_holder = GameObject.FindGameObjectWithTag("CanvasHolder");

				for (int i = 0; i < canvas.Length; i++)
					canvas[i] = null;

				{
					GameObject canvas_main = GameObject.Find("CanvasMain");
					canvas[0] = (canvas_main != null) ? canvas_main.gameObject : null;
				}

				for (int i = 0; i < canvas.Length; i++)
				{
					if (canvas[i] == null)
						canvas[i] = canvas_holder.transform.GetChild(i).gameObject;

					if (canvas[i] != null)
						canvas[i].SetActive(true);
				}
			}

			text_header = GameObject.Find("TextHeader").GetComponent<Text>();
			text_dialog = GameObject.Find("TextDialog").GetComponent<Text>();
			text_debug = GameObject.Find("TextDebug").GetComponent<Text>();
			text_debug_fps = GameObject.Find("TextDebugFps").GetComponent<Text>();

			player_focus[0] = GameObject.Find("PlayerStatusFocus_1");
			player_focus[1] = GameObject.Find("PlayerStatusFocus_2");

			player_focus[0].SetActive(false);
			player_focus[1].SetActive(false);

			{
				Debug.Assert(player_status.Rank == 2);

				for (int ix_major = 0; ix_major < player_status.GetLength(0); ix_major++)
				{
					string control_name = "PlayerStatus_" + (ix_major + 1).ToString() + "_";

					for (int ix_minor = 0; ix_minor < player_status.GetLength(1); ix_minor++)
					{
						string s = control_name + (ix_minor + 1).ToString();
						GameObject ga = GameObject.Find(s);
						if (ga != null)
							player_status[ix_major, ix_minor] = ga.GetComponentInChildren<Text>();

						// player_status[ix_major, ix_minor] = GameObject.Find(control_name + (ix_minor + 1).ToString()).GetComponent<Text>();
					}
				}
			}

			// Activate canvas 0 only
			for (int i = 0; i < canvas.Length; i++)
				canvas[i].SetActive(i == 0);

			mini_map = text_dialog.GetComponentInChildren<Image>();
			mini_map.gameObject.SetActive(false);

			// 메인 메뉴 그룹
			{
				GameObject panel_main_menu_group = GameObject.Find("PanelMainMenuGroup");

				int n_child = panel_main_menu_group.transform.childCount;
				Debug.Assert(n_child == (int)MAIN_MENU.MAX);

				panel_main_menus = new GameObject[n_child];
				for (int i = 0; i < n_child; i++)
				{
					panel_main_menus[i] = panel_main_menu_group.transform.GetChild(i).gameObject;
					panel_main_menus[i].SetActive(false);
				}
			}

			// 메인 패널 그룹
			{
				GameObject panel_main_group = GameObject.FindGameObjectWithTag("PanelMainGroup");

				panel_map = panel_main_group.transform.GetChild(0).gameObject;
				panel_battle = panel_main_group.transform.GetChild(1).gameObject;

				panel_map.SetActive(true);
				panel_battle.SetActive(false);
			}

			// 버튼 패널 그룹
			{
				GameObject panel_button_group = GameObject.Find("PanelButtonGroup");

				panel_button_group_right_handed = panel_button_group.transform.GetChild(0).gameObject;
				panel_button_group_left_handed = panel_button_group.transform.GetChild(1).gameObject;
				panel_button_group_right_handed.SetActive(true);
				panel_button_group_left_handed.SetActive(true);

				panel_buttons[0, (int)BUTTON.MENU] = GameObject.Find("ButtonMenu");
				panel_buttons[0, (int)BUTTON.ARROW_UP] = GameObject.Find("ButtonArrowUp");
				panel_buttons[0, (int)BUTTON.ARROW_DOWN] = GameObject.Find("ButtonArrowDown");
				panel_buttons[0, (int)BUTTON.ARROW_LEFT] = GameObject.Find("ButtonArrowLeft");
				panel_buttons[0, (int)BUTTON.ARROW_RIGHT] = GameObject.Find("ButtonArrowRight");
				panel_buttons[0, (int)BUTTON.OK] = GameObject.Find("ButtonOk");
				panel_buttons[0, (int)BUTTON.CANCEL] = GameObject.Find("ButtonCancel");

				panel_buttons[1, (int)BUTTON.MENU] = GameObject.Find("ButtonMenu_LH");
				panel_buttons[1, (int)BUTTON.ARROW_UP] = GameObject.Find("ButtonArrowUp_LH");
				panel_buttons[1, (int)BUTTON.ARROW_DOWN] = GameObject.Find("ButtonArrowDown_LH");
				panel_buttons[1, (int)BUTTON.ARROW_LEFT] = GameObject.Find("ButtonArrowLeft_LH");
				panel_buttons[1, (int)BUTTON.ARROW_RIGHT] = GameObject.Find("ButtonArrowRight_LH");
				panel_buttons[1, (int)BUTTON.OK] = GameObject.Find("ButtonOk_LH");
				panel_buttons[1, (int)BUTTON.CANCEL] = GameObject.Find("ButtonCancel_LH");

				panel_button_cheat[0] = GameObject.Find("ButtonCheat");
				panel_button_cheat[1] = GameObject.Find("ButtonCheat_LH");

				// Assign normal color and dimming color
				for (int i = 0; i < (int)BUTTON.MAX; i++)
				{
					BUTTON_COLOR[i, 0] = panel_buttons[0, i].GetComponent<Image>().color;
					BUTTON_COLOR[i, 1] = BUTTON_COLOR[i, 0];
					BUTTON_COLOR[i, 1].a *= DIMMING_FACTOR;
				}

				SetButtonGroupHanded(true);
			}

			GameObj.ApplyGameOptions();

			tiling_engine = (TilingEngine)GameObject.Find("ObjMapRenderer").GetComponent<TilingEngine>();

			GameObj.text_header.text = "";
			GameObj.text_header_duration = 0;
			GameObj.text_dialog.text = "";
			GameObj.text_debug.text = "";
			GameObj.text_debug_fps.text = "";

			GameObj.text_debug_fps.enabled = CONFIG.ENABLE_FPS_COUNTER;

			GameObj.UpdatePlayerStatus();

			GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
		}

		public static void ApplyGameOptions()
		{
			int left_handed = PlayerPrefs.GetInt(CONFIG.PREF_STR_OPTION_LEFT_HANDED, CONFIG.PREF_DEFAULT_OPTION_LEFT_HANDED);
			if (left_handed != CONFIG.PREF_DEFAULT_OPTION_LEFT_HANDED)
				GameObj.SetButtonGroupHanded(left_handed == 0);

			int sound_on = PlayerPrefs.GetInt(CONFIG.PREF_STR_OPTION_SOUND_ON, CONFIG.PREF_DEFAULT_OPTION_SOUND_ON);
			if (sound_on != CONFIG.PREF_DEFAULT_OPTION_SOUND_ON)
				GameObj.SetBgmMode(sound_on != 0);

			int cheat_on = PlayerPrefs.GetInt(CONFIG.PREF_STR_OPTION_CHEAT_ON, CONFIG.PREF_DEFAULT_OPTION_CHEAT_ON);
			GameObj.SetCheatMode(cheat_on != 0);
		}

		private static uint GetColorForHP(float percent)
		{
			/*
			0.0: FF2519
			0.5: FFDB00
			1.0: 00FF00
			 */
			if (percent <= 0.0f)
				return 0xFFFF2519;
			if (percent <= 0.5f)
			{
				percent = percent * 2;

				uint r = (uint)Mathf.Lerp(0xFF, 0xFF, percent) << 16;
				uint g = (uint)Mathf.Lerp(0x25, 0xDB, percent) << 8;
				uint b = (uint)Mathf.Lerp(0x19, 0x00, percent);

				return 0xFF000000 | r | g | b;
			}
			if (percent < 1.0f)
			{
				percent = (percent - 0.5f) * 2;
				
				uint r = (uint)Mathf.Lerp(0xFF, 0x00, percent) << 16;
				uint g = (uint)Mathf.Lerp(0xDB, 0xFF, percent) << 8; 
				uint b = (uint)Mathf.Lerp(0x00, 0x00, percent);

				return 0xFF000000 | r | g | b;
			}
			else
				return 0xFF00FF00;
		}

		private static uint GetColorForSP(float percent)
		{
			/*
			0.0: FF2519
			0.5: E8DB19
			1.0: A0FF60
			 */
			if (percent <= 0.0f)
				return 0xFFFF2519;
			if (percent <= 0.5f)
			{
				percent = percent * 2;

				uint r = (uint)Mathf.Lerp(0xFF, 0xE8, percent) << 16;
				uint g = (uint)Mathf.Lerp(0x25, 0xDB, percent) << 8;
				uint b = (uint)Mathf.Lerp(0x19, 0x19, percent);

				return 0xFF000000 | r | g | b;
			}
			if (percent < 1.0f)
			{
				percent = (percent - 0.5f) * 2;

				uint r = (uint)Mathf.Lerp(0xE8, 0xA0, percent) << 16;
				uint g = (uint)Mathf.Lerp(0xDB, 0xFF, percent) << 8;
				uint b = (uint)Mathf.Lerp(0x19, 0x60, percent);

				return 0xFF000000 | r | g | b;
			}
			else
				return 0xFFA0FF60;
		}

		public static void UpdateEnemyStatus()
		{

		}

		public static void UpdatePlayerStatus()
		{
/*
			for (int ix_major = 0; ix_major < player_status.Rank; ix_major++)
			{
				string control_name = "TextStatus_" + (ix_major + 1).ToString() + "_";

				for (int ix_minor = 0; ix_minor < player_status.GetLength(ix_major); ix_minor++)
*/
			for (int i = 0; i < player_status.GetLength(1); i++)
			{
				if (GameRes.player[i].Name.Length > 0)
				{
					if (GameRes.player[i].equip[(uint)Yunjr.EQUIP.HAND].item.res_id == null)
						GameRes.player[i].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.HIT, 0));

					// player의 상태에 따라 색이 바뀜
					string s = @"<color=";

					if (GameRes.player[i].dead > 0)
						s += "#403038";
					else if (GameRes.player[i].unconscious > 0)
						s += "#806070";
					else if (GameRes.player[i].poison > 0)
						s += "#C060E0";
					else
						s += "#FFFFFF";

					s += @">" + GameRes.player[i].Name + "</color>\n";

					if (GameRes.player[i].GetMaxHP() > 0)
						s += "HP " + LibUtil.ColorTagFromInt(GetColorForHP(1.0f * GameRes.player[i].hp / GameRes.player[i].GetMaxHP()), GameRes.player[i].hp) + "\n";
					else
						s += @"HP <color=#C0C0C0>--</color>";

					if (GameRes.player[i].GetMaxSP() > 0)
						s += "SP " + LibUtil.ColorTagFromInt(GetColorForSP(1.0f * GameRes.player[i].sp / GameRes.player[i].GetMaxSP()), GameRes.player[i].sp);
					else
						s += @"SP <color=#C0C0C0>--</color>";

					for (int ix_major = 0; ix_major < player_status.GetLength(0); ix_major++)
						player_status[ix_major, i].text = s;
				}
				else
				{
					for (int ix_major = 0; ix_major < player_status.GetLength(0); ix_major++)
						player_status[ix_major, i].text = "";
				}
			}
		}

		public static void SetHeaderText(string message, int duration = 0x7FFFFFFF)
		{
			if (text_header != null)
			{
				int index = message.IndexOf('\n');
				if (index >= 0)
				{
					message = message.Insert(index + 1, "<color=#FFBF40FF>");
					message = message.Insert(message.Length, "</color>");
				}

				text_header.text = message;
				text_header_duration = duration;
			}
		}

		public static void UpdadeTick()
		{
			if (text_header_duration > 0)
			{
				if (--text_header_duration == 0)
					text_header.text = "";
			}
		}

		private static uint[,] BUTTON_ENABLED = new uint[(int)BUTTON_GROUP.MAX, (int)BUTTON.MAX]
		{
			{ 1, 1, 1, 1, 1, 0, 0 },
			{ 0, 0, 0, 0, 0, 1, 0 },
			{ 0, 0, 0, 0, 0, 1, 1 },
			{ 0, 1, 1, 0, 0, 1, 1 },
			{ 0, 1, 1, 0, 0, 1, 0 },
			{ 0, 0, 0, 0, 1, 0, 1 },
			{ 0, 0, 0, 0, 0, 0, 0 }
		};

		private static UnityEngine.Color[,] BUTTON_COLOR = new UnityEngine.Color[(int)BUTTON.MAX, 2];

		public static void SetButtonGroup(BUTTON_GROUP button_group)
		{
			// TODO2:
			// Debug.Log("GameObj::SetButtonGroup(" + button_group.ToString() + ")");

			int ix_button_group = (int)button_group;

			if (ix_button_group >= 0 && ix_button_group < (int)BUTTON_GROUP.MAX)
			{
				for (int j = 0; j < 2; j++)
				{
					for (int i = 0; i < (int)BUTTON.MAX; i++)
					{
						int index = (BUTTON_ENABLED[ix_button_group, i] > 0) ? 0 : 1;

						panel_buttons[j, i].GetComponent<Button>().enabled = (index == 0);
						panel_buttons[j, i].GetComponent<UnityEngine.EventSystems.EventTrigger>().enabled = (index == 0);
						panel_buttons[j, i].GetComponent<Image>().color = BUTTON_COLOR[i, index];
						panel_buttons[j, i].transform.Find("Image").gameObject.GetComponent<Image>().color = BUTTON_COLOR[i, index];
					}
				}
				//GameEventMain.ResetArrowKey();
			}
		}

		public static void SetMainMenuOnOff(MAIN_MENU target = MAIN_MENU.MAX)
		{
			for (int i = 0; i < panel_main_menus.Length; i++)
				panel_main_menus[i].SetActive(i == (int)target);
		}

		public static void SetButtonGroupHanded(bool is_right_handed)
		{
			panel_button_group_right_handed.SetActive(is_right_handed);
			panel_button_group_left_handed.SetActive(!is_right_handed);
		}

		public static void SetBgmMode(bool is_bgm_on)
		{
			AudioManager audio_manager = AudioManager.m_instance;

			if (audio_manager != null)
				audio_manager.Mute(!is_bgm_on);
		}

		public static void SetCheatMode(bool is_cheat_on)
		{
			if (panel_button_cheat != null)
			{
				foreach (var button in panel_button_cheat)
				{
					if (button != null)
						button.SetActive(is_cheat_on);
				}

				GameObj.text_debug_fps.enabled = is_cheat_on;
				CONFIG.ENABLE_FPS_COUNTER = is_cheat_on;
			}
		}

		public static void ScreenFadeOut(FnCallBack0 fn_callback = null)
		{
			GameObj.canvas[2].SetActive(true);

			ScreenFade obj_fade = GameObj.canvas[2].transform.GetComponentInChildren<ScreenFade>();

			if (obj_fade != null)
			{
				obj_fade.StartFadeOut(() =>
				{
					if (fn_callback != null)
						fn_callback();

					// TODO: fadeout 후처리
					// GameObj.canvas[2].SetActive(false);
				});
			}
		}

	}
}
