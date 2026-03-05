
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

using System;

namespace Yunjr
{
	public class TitleLauncting : MonoBehaviour
	{
		private GameObject m_title_panel_main_menu = null;

		public GameObject m_popup_about_holder;
		public GameObject m_popup_about;
		public Button m_button_continue;
		public Text m_button_continue_text;

		void Start()
		{
			// 초기화 테스트용
			// GameRes.DeleteSaveGame(0);

			// GameObject m_text_bottom = GameObject.FindGameObjectWithTag("TextBottom");
			// GameObject m_dialog_box = GameObject.FindGameObjectWithTag("ImageDialogBox");

			m_title_panel_main_menu = GameObject.FindGameObjectWithTag("TitlePanelMainMenu");
			m_title_panel_main_menu.SetActive(false);

			m_popup_about.SetActive(false);

			int save_file_version = GameRes.GetSaveFileVersion(0);

			if (save_file_version != (int)CONFIG.SAVE_FILE_VERSION)
			{
				m_button_continue.GetComponent<Button>().interactable = false;
				m_button_continue_text.color = new Color(0.55f, 0.55f, 0.55f);

				Debug.Log(String.Format("Old save file detected: Detected({0}), Current({1})", save_file_version, (int)CONFIG.SAVE_FILE_VERSION));
			}
		}

		void OnFloatingTitle()
		{
		}

		void OnBottomText()
		{
		}

		void OnDialogBox()
		{
		}

		void OnTitleAnimationEnd()
		{
			Animator animator = gameObject.GetComponent<Animator>();
			animator.StopPlayback();

			m_title_panel_main_menu.SetActive(true);
		}

        public void OnMenuNewGame()
        {
            Debug.Log("OnMenuNewGame() ---->");
			// New Game에서 바로 캐릭터 생성으로 가는 경우
			// SceneManager.LoadScene("CreateCharacter", LoadSceneMode.Single);

			Yunjr.LAUNCHING_PARAM.type = LAUNCHING_PARAM.TYPE.NEW_GAME_PROLOG;
			SceneManager.LoadScene("LoreMap", LoadSceneMode.Single);
		}

		public void OnMenuContinue()
        {
            Debug.Log("OnMenuContinue() ---->");

			Yunjr.LAUNCHING_PARAM.type = LAUNCHING_PARAM.TYPE.CONTINUE;
			SceneManager.LoadScene("LoreMap", LoadSceneMode.Single);
		}

		public void OnMenuAbout()
		{
			Debug.Log("OnMenuAbout() ---->");
			m_popup_about.SetActive(true);
		}

		public void OnMenuExit()
		{
			Debug.Log("OnMenuExit() ---->");
			Application.Quit();
		}

		public void OnPopupAboutOk()
		{
			Debug.Log("OnPopupAboutOk() ---->");
			m_popup_about.SetActive(false);
		}
	}
}
