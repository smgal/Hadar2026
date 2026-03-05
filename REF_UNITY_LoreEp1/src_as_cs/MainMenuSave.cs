
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class MainMenuSave : MonoBehaviour
	{
		public List<GameObject> slots;

		private Color COLOR_ON = new Color(1.0f, 1.0f, 1.0f, 1.0f);
		private Color COLOR_OFF = new Color(0.4f, 1.0f, 0.7f, 0.8f);
		private Color COLOR_DISABLE = new Color(1.0f, 1.0f, 1.0f, 0.3f);

		private string _GetSaveFileInfo(int index)
		{
			string key_info = String.Format(CONFIG.PREF_STR_SAVE_INFO, index);

			return PlayerPrefs.GetString(key_info, "[위치 불명]");
		}

		private string _GetSaveTimeInfo(int index)
		{
			string key_time = String.Format(CONFIG.PREF_STR_SAVE_TIME, index);

			return PlayerPrefs.GetString(key_time, "");
		}

		public void UpdateSlotInfo()
		{
			for (int i = 0; i < slots.Count; i++)
			{
				int index = i;

				Button button = slots[i].GetComponent<Button>();
				Text[] text = slots[i].GetComponentsInChildren<Text>();

				int save_file_version = GameRes.GetSaveFileVersion(index);

				if (save_file_version == (int)CONFIG.SAVE_FILE_VERSION)
				{
					text[0].text = _GetSaveFileInfo(index);
					text[0].color = (i > 0) ? COLOR_ON : COLOR_DISABLE;
					text[1].text = _GetSaveTimeInfo(index);
				}
				else
				{
					text[0].text = "(비어 있음)";
					text[0].color = COLOR_OFF;
					text[1].text = "";
				}

				button.interactable = (i > 0);
			}
		}

		public int GetMaxSaveFile()
		{
			return slots.Count;
		}

		public void OnButtonClick(int index)
		{
			if (GameRes.DoesSaveFileExist(index))
			{
				MainMenuSaveDialog main_menu_save_dialog = (MainMenuSaveDialog)GameObj.panel_main_menus[(int)MAIN_MENU.GAME_SAVE_DIALOG].GetComponent<MainMenuSaveDialog>();
 				main_menu_save_dialog.AssignIndex(index);

				GameObj.SetMainMenuOnOff(MAIN_MENU.GAME_SAVE_DIALOG);
			}
			else
			{
				MainMenuSave.SaveFile(index);
				GameEventMain.HideMainMenu();
				// TODO2: 저장이 완료되었다는 팝업을 띄워야?
			}
		}

		public static void SaveFile(int index)
		{
			if (GameRes.SaveGame(index))
			{
				string key_info = String.Format(CONFIG.PREF_STR_SAVE_INFO, index);
				string key_time = String.Format(CONFIG.PREF_STR_SAVE_TIME, index);

				byte identifing_degree = GameRes.GetIdentifingDegreeOfCurrentMap();
				string str_time = System.DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss");

				PlayerPrefs.SetString(key_info, "[" + GameRes.map_script.GetPlaceName(identifing_degree) + "]");
				PlayerPrefs.SetString(key_time, str_time);

				Debug.Log("[SAVE][TIME] " + str_time);
			}
		}
	}
}
