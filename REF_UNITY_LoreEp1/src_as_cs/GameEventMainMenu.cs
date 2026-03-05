
using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class GameEventMainMenu: MonoBehaviour
	{
		public UIWidgets.Popup popup_main_menu;
		public UIWidgets.Popup popup_game_option;
		public UIWidgets.Popup popup_game_load;
		public UIWidgets.Popup popup_game_save;
		public UIWidgets.Popup popup_game_save_confirm;

		private static UIWidgets.Popup _main_menu = null;
		private static UIWidgets.Popup _current_popup = null;
		private static UIWidgets.Popup _confirmation_popup = null;
		private static int _ix_save = -1;

		public void Show()
		{
			_Show();
		}

		protected void _Show()
		{
			_main_menu = popup_main_menu.Clone();
			_main_menu.Show
			(
				position: new Vector3(0, 0),
				modal: true,
				modalColor: new Color(0.0f, 0.0f, 0.0f, 0.6f)
			);
		}

		protected void _Hide()
		{
			if (_main_menu != null)
			{
				_main_menu.Close();
				_main_menu = null;
			}
		}

		protected void _ShowSubPopup(out UIWidgets.Popup out_popup, UIWidgets.Popup template, string name)
		{
			out_popup = null;

			if (template != null)
			{
				out_popup = template.Clone();

				out_popup.name = name;
				out_popup.Show
				(
					position: new Vector3(0, 0),
					modal: true,
					modalColor: new Color(0.0f, 0.0f, 0.0f, 0.0f)
				);
			}
		}

		protected void _HideAllPopup()
		{
			if (_confirmation_popup != null)
			{
				_confirmation_popup.Close();
				_confirmation_popup = null;
			}

			if (_current_popup != null)
			{
				_current_popup.Close();
				_current_popup = null;
			}

			this._Hide();
		}

		protected void _HideTopPopup()
		{
			if (_confirmation_popup != null)
			{
				_confirmation_popup.Close();
				_confirmation_popup = null;
			}
			else if (_current_popup != null)
			{
				_current_popup.Close();
				_current_popup = null;
			}
			else
				this._Hide();
		}

		public void OnMainMenuGameOptionClick()
		{
			this._ShowSubPopup(out _current_popup, popup_game_option, "GameOption");
		}

		public void OnMainMenuLoadClick()
		{
			this._ShowSubPopup(out _current_popup, popup_game_load, "GameLoad");

			MainMenuLoad main_menu_load = (MainMenuLoad)_current_popup.GetComponent<MainMenuLoad>();
			main_menu_load.UpdateSlotInfo();
		}

		public void OnMainMenuSaveClick()
		{
			this._ShowSubPopup(out _current_popup, popup_game_save, "GameSave");

			MainMenuSave main_menu_save = (MainMenuSave)_current_popup.GetComponent<MainMenuSave>();
			main_menu_save.UpdateSlotInfo();
		}

		public void OnMainMenuExitClick(bool try_to_save)
		{
			if (try_to_save)
				MainMenuSave.SaveFile(0);

#if UNITY_EDITOR
			UnityEditor.EditorApplication.isPlaying = false;
#else
			Application.Quit();
#endif
		}

		///
		/// Game Option
		///
		public void OnGameOptionLeftHandedClick(bool is_on)
		{
			PlayerPrefs.SetInt(CONFIG.PREF_STR_OPTION_LEFT_HANDED, (is_on) ? 1 : 0);
			GameObj.SetButtonGroupHanded(!is_on);
		}

		public void OnGameOptionSoundOnClick(bool is_on)
		{
			PlayerPrefs.SetInt(CONFIG.PREF_STR_OPTION_SOUND_ON, (is_on) ? 1 : 0);
			GameObj.SetBgmMode(is_on);
		}

		public void OnGameOptionCheatOnClick(bool is_on)
		{
			PlayerPrefs.SetInt(CONFIG.PREF_STR_OPTION_CHEAT_ON, (is_on) ? 1 : 0);
			GameObj.SetCheatMode(is_on);
		}

		public void OnGameOptionOkClick()
		{
			_HideTopPopup();
		}

		///
		/// Game Load
		///
		public void OnGameLoadButtonClick(int index)
		{
			if (GameRes.LoadGame(index))
			{
				GameObj.SetHeaderText("");
				Yunjr.Console.Clear();
				GameObj.UpdatePlayerStatus();

				_HideAllPopup();
			}
		}

		public void OnGameLoadCancelClick()
		{
			_HideAllPopup();
		}

		///
		/// Game Save
		///
		public void OnGameSaveButtonClick(int index)
		{
			if (GameRes.DoesSaveFileExist(index))
			{
				_ix_save = index;
				this._ShowSubPopup(out _confirmation_popup, popup_game_save_confirm, "GameSaveConfirmation");
			}
			else
			{
				MainMenuSave.SaveFile(index);
				_HideAllPopup();
				// TODO2: 저장이 완료되었다는 팝업을 띄워야?
			}
		}

		public void OnGameSaveCancelClick()
		{
			_HideAllPopup();
		}

		///
		/// Game Save Confirmation
		///
		public void OnGameSaveConfirmationCancelClick()
		{
			_HideTopPopup();
		}

		public void OnGameSaveConfirmationOkClick()
		{
			MainMenuSave.SaveFile(_ix_save);
			_ix_save = -1;

			_HideAllPopup();
		}
	}
}
