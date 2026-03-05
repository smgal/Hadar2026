
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class MainMenuSaveDialog : MonoBehaviour
	{
		public Text Title;
		public Text SaveLocation;
		public Text SaveTime;

		private static int ix_save = 0;

		public void AssignIndex(int index)
		{
			ix_save = index;

			string key_info = String.Format(CONFIG.PREF_STR_SAVE_INFO, ix_save);
			SaveLocation.text = PlayerPrefs.GetString(key_info, "[위치 불명]");

			string key_time = String.Format(CONFIG.PREF_STR_SAVE_TIME, ix_save);
			SaveTime.text = PlayerPrefs.GetString(key_time, "");
		}

		public void OnOkClick()
		{
			MainMenuSave.SaveFile(ix_save);
			GameEventMain.HideMainMenu();
		}

		public void OnCancelClick()
		{
			GameObj.SetMainMenuOnOff(MAIN_MENU.GAME_SAVE);
		}
	}
}
