
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class MainMenuLoad : MonoBehaviour
	{
		public List<GameObject> slots;

		private Color COLOR_ON = new Color(1.0f, 1.0f, 1.0f, 1.0f);
		private Color COLOR_OFF = new Color(1.0f, 1.0f, 1.0f, 0.3f);

		private string _GetSaveFileInfo(int index)
		{
			string key = String.Format(CONFIG.PREF_STR_SAVE_INFO, index);

			return PlayerPrefs.GetString(key, "[위치 불명]");
		}

		private string _GetSaveTimeInfo(int index)
		{
			string key = String.Format(CONFIG.PREF_STR_SAVE_TIME, index);

			return PlayerPrefs.GetString(key, "");
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
					button.interactable = true;
					text[0].text = _GetSaveFileInfo(index);
					text[0].color = COLOR_ON;
					text[1].text = _GetSaveTimeInfo(index);
				}
				else
				{
					button.interactable = false;
					text[0].text = "(없음)";
					text[0].color = COLOR_OFF;
					text[1].text = "";
				}
			}
		}

		public int GetMaxSaveFile()
		{
			return slots.Count;
		}

		public void OnButtonClick(int index)
		{
			if (GameRes.LoadGame(index))
			{
				GameObj.SetHeaderText("");
				Yunjr.Console.Clear();
				GameObj.UpdatePlayerStatus();

				GameEventMain.HideMainMenu();
			}
		}
	}
}
