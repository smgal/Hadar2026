using System;
using System.Collections;
using System.Collections.Generic;

using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class CreateCharacterDecision: MonoBehaviour
	{
		private const string NAME_NOT_INPUT = "아직 이름이 입력되지 않았습니다";
		private const string NAME_TOO_LONG = "이름은 한글 기준 5자까지입니다";
		private const string NAME_INVALID_CHAR = "이름에 기호, 숫자, 공백이 있습니다";
		private const string NAME_IS_AVAILABLE = "사용 가능한 이름입니다";
		private const string NAME_EXISTS = "게임 안에서 중복되는 이름이 나옵니다";

		public GameObject m_image_class_holder;
		public Button m_button_ok;
		public Button m_button_done;
		public Text m_text_your_class;
		public Text m_text_your_name;
		public Text m_text_name_inputing;
		public Text m_text_name_verifing;

		private Animator _animator;
		private Image _button_image;
		private Color[] _button_color = new Color[2];
		private List<GameObject> _class_selectors = new List<GameObject>();

		private const int CLASS_SELECTOR_Y_INIT = -320;
		private const int CLASS_SELECTOR_Y_STEP = -160;
		private const int CLASS_DECIDED_Y_INIT = -160;

		// Use this for initialization
		void Start()
		{
			Debug.Assert(m_image_class_holder != null);

			m_text_your_class.gameObject.SetActive(false);
			m_text_your_name.gameObject.SetActive(false);

			m_button_ok.gameObject.SetActive(false);
			m_button_done.gameObject.SetActive(false);

			// 클래스 결정을 위한 widget은 처음에는 숨겨 놓는다.
			for (int i = 0; i < m_image_class_holder.transform.childCount; i++)
			{
				GameObject obj = m_image_class_holder.transform.GetChild(i).gameObject;
				_class_selectors.Add(obj);
				obj.SetActive(false);
			}

			_animator = gameObject.GetComponent<Animator>();
			_button_image = m_button_ok.GetComponent<Image>();

			_button_color[1] = _button_image.color;
			_button_color[0] = _button_color[1];
			_button_color[0].a *= 0.2f;

			_SetButtonDisabled();
		}

		private void _SetButtonEnabled()
		{
			m_button_ok.interactable = true;
			_button_image.color = _button_color[1];
		}

		private void _SetButtonDisabled()
		{
			m_button_ok.interactable = false;
			_button_image.color = _button_color[0];
		}

		public void OnCreateCharacterDecisionPressAnyKey(int step)
		{
			switch (step)
			{
			case 0:
				break;
			case 1:
			case 2:
				_animator.speed = 0;
				_SetButtonEnabled();
				break;
			}
		}

		public void OnCreateCharacterDecisionOkClick()
		{
			_animator.speed = 1;
			_SetButtonDisabled();
		}

		public void OnCreateCharacterDecisionAnimationEnd()
		{
			_animator.enabled = false;
			//_animator.StopPlayback();
			_SetButtonEnabled();

			{
				Debug.Assert(CreateCharacter.modifier_weight.Length == 7);

				String s = String.Format(
					"     KN HU MO PA AS MA ES\n" +
					"누적 {0,2}:{1,2}:{2,2}:{3,2}:{4,2}:{5,2}:{6,2}"
					, CreateCharacter.modifier_weight[0]
					, CreateCharacter.modifier_weight[1]
					, CreateCharacter.modifier_weight[2]
					, CreateCharacter.modifier_weight[3]
					, CreateCharacter.modifier_weight[4]
					, CreateCharacter.modifier_weight[5]
					, CreateCharacter.modifier_weight[6]
				);

				Debug.Log(s);
			}

			int num_acceptance = 0;

			for (int i = 0; i < CreateCharacter.modifier_weight.Length; i++)
			{
				if ((float)CreateCharacter.modifier_weight[i] >= CreateCharacter.CUT_OFF_POINT)
				{
					_class_selectors[i].SetActive(true);

					Vector2 pos = _class_selectors[i].GetComponent<RectTransform>().anchoredPosition;
					pos.x = 0;
					pos.y = CLASS_SELECTOR_Y_INIT + CLASS_SELECTOR_Y_STEP * num_acceptance;
					_class_selectors[i].GetComponent<RectTransform>().anchoredPosition = pos;

					++num_acceptance;
				}
			}

			// 최소 합격수가 안 되는 경우, WANDERER 추가 
			if (num_acceptance < CreateCharacter.MIN_ACCEPTANCE)
			{
				// TODO2: magic number
				int i = 7;

				Debug.Assert(CreateCharacter.modifier_weight.Length == i);

				_class_selectors[i].SetActive(true);

				Vector2 pos = _class_selectors[i].GetComponent<RectTransform>().anchoredPosition;
				pos.x = 0;
				pos.y = CLASS_SELECTOR_Y_INIT + CLASS_SELECTOR_Y_STEP * num_acceptance;
				_class_selectors[i].GetComponent<RectTransform>().anchoredPosition = pos;
			}
		}

		// 0~ES
		private static readonly int[,] _CLASS_ABILITY = new int[9, (int)STATUS.MAX]
		{
			{10,10,10,10,10,10,10,10, 5},
			{10,10,10,10,10,10,10,10, 5},
			{15, 6,13, 7,10, 8,11,10, 5},
			{ 9, 8,10,11,12, 6,15,10, 5},
			{11, 7,15, 9,10,12, 6,10, 5},
			{13,10,13, 8, 6,13, 7,10, 5},
			{ 6,11, 7, 9,15,13,10,10, 5},
			{ 6,15, 6,13, 9,11,10,10, 5},
			{10,13, 6,14, 9, 7,11,10, 5}
		};

		/* 이 부분은 다음에 다시 고려해 보자.
		private static readonly int[,] _MODIFIER_ABILITY = new int[(int)CreateCharacter.NUM_MODIFIER, (int)STATUS.MAX]
		{
			{15, 6,13, 7,10, 8,11,10, 5}, // KN
			{ 9, 8,10,11,12, 6,15,10, 5}, // HU
			{11, 7,15, 9,10,12, 6,10, 5}, // MO
			{13,10,13, 8, 6,13, 7,10, 5}, // PA
			{ 6,11, 7, 9,15,13,10,10, 5}, // AS
			{ 6,15, 6,13, 9,11,10,10, 5}, // MA
			{10,13, 6,14, 9, 7,11,10, 5}  // ES
        };
		
		// [ IN] CreateCharacter.modifier_weight[]
		// [OUT] Yunjr.LAUNCHING_PARAM.new_player_status[]
		// [USE] _MODIFIER_ABILITY[]
		private void _SetPlayerStatus()
		{
			// 예>
			//      KN HU MO PA AS MA ES
			// 누적 23:17:17:14:13:16: 7  -> 합계 107
			// CreateCharacter.modifier_weight[0~6]
			// 
			// STR, INT, END, CON, AGI, RES, DEX, LUC, LEV
			//

			// Normalize
			double[] QQQ = new double[(int)STATUS.MAX];
			Array.Clear(QQQ, 0, QQQ.Length);

			double[] modifier_ratio = new double[CreateCharacter.modifier_weight.Length];
			{
				double sum = 0.0f;
				foreach (var i in CreateCharacter.modifier_weight)
					sum += i;

				for (int j = 0; j < modifier_ratio.Length; j++)
					modifier_ratio[j] = CreateCharacter.modifier_weight[j] / sum;

				for (int j = 0; j < modifier_ratio.Length; j++)
					for (int i = 0; i < (int)STATUS.MAX; i++)
						QQQ[i] += (double)_MODIFIER_ABILITY[j, i] * modifier_ratio[j];
			}

			for (int ix_status = 0; ix_status < (int)STATUS.MAX; ix_status++)
				Yunjr.LAUNCHING_PARAM.new_player_status[ix_status] = (int)Math.Round(QQQ[ix_status]);
		}
		*/

		private string _VerifyYourName(string name)
		{
			if (name == "")
				return NAME_NOT_INPUT;

			foreach (char ch in name)
			{
				System.Globalization.UnicodeCategory category = char.GetUnicodeCategory(ch);

				if (category != System.Globalization.UnicodeCategory.OtherLetter
					&& category != System.Globalization.UnicodeCategory.LowercaseLetter
					&& category != System.Globalization.UnicodeCategory.UppercaseLetter)
					return NAME_INVALID_CHAR;
			}

			if (LibUtil.SmTextExtent(name) > 10)
				return NAME_TOO_LONG;

			if (GameStrRes.IsNpcName(name))
				return NAME_EXISTS;

			return "";
		}

		public void OnCreateCharacterDecisionNameChange(string name)
		{
			string error_message = _VerifyYourName(name);
			m_text_name_verifing.text = (error_message == "") ? NAME_IS_AVAILABLE : error_message;
			m_button_done.gameObject.SetActive((error_message == ""));
		}

		public void OnCreateCharacterDecisionNameEnd(string name)
		{
			string error_message = _VerifyYourName(name);
			m_button_done.gameObject.SetActive((error_message == ""));
		}

		public void OnCreateCharacterDecisionClassClick(int selected_class)
		{
			m_text_your_class.gameObject.SetActive(false);
			m_text_your_name.gameObject.SetActive(true);

			int ix_class_selectors = 0;

			// 하드 코딩
			switch (selected_class)
			{
				case 1: ix_class_selectors = 7; break;
				case 2: ix_class_selectors = 0; break;
				case 3: ix_class_selectors = 1; break;
				case 4: ix_class_selectors = 2; break;
				case 5: ix_class_selectors = 3; break;
				case 6: ix_class_selectors = 4; break;
				case 7: ix_class_selectors = 5; break;
				case 8: ix_class_selectors = 6; break;
			}

			for (int i = 0; i < _class_selectors.Count; i++)
			{
				_class_selectors[i].SetActive(ix_class_selectors == i);

				if (ix_class_selectors == i)
				{
					Vector2 pos = _class_selectors[i].GetComponent<RectTransform>().anchoredPosition;
					pos.x = 0;
					pos.y = CLASS_DECIDED_Y_INIT;
					_class_selectors[i].GetComponent<RectTransform>().anchoredPosition = pos;
				}
			}

			OnCreateCharacterDecisionNameChange("");
			_SetButtonEnabled();

			Debug.Log("Your choice: " + selected_class);

			Yunjr.LAUNCHING_PARAM.type = LAUNCHING_PARAM.TYPE.NEW_GAME_MAIN;
			Yunjr.LAUNCHING_PARAM.param.clazz = (Yunjr.CLASS)(selected_class);
			Yunjr.LAUNCHING_PARAM.param.name = "아무개";

			// 문제가 있어서 적용하지 않는다.
			// _SetPlayerStatus();

			if (selected_class < 0 && selected_class >= _CLASS_ABILITY.Length / (int)STATUS.MAX)
				selected_class = 0;

			for (int ix_status = 0; ix_status < (int)STATUS.MAX; ix_status++)
				Yunjr.LAUNCHING_PARAM.param.status[ix_status] = _CLASS_ABILITY[selected_class, ix_status];

			for (int ix_skill = 0; ix_skill < (int)SKILL_TYPE.MAX; ix_skill++)
				Yunjr.LAUNCHING_PARAM.param.skills[ix_skill] = ObjPlayer.GetMinValueOfSkill((CLASS)selected_class, (SKILL_TYPE)ix_skill);
		}

		public void OnCreateCharacterDecisionDoneClick()
		{
			Yunjr.LAUNCHING_PARAM.param.name = this.m_text_name_inputing.text;
			// TODO: ?? LAUNCHING_PARAM.param.gender
			Yunjr.LAUNCHING_PARAM.param.gender = GENDER.MALE;

			CreateCharacter.NextStep();
		}
	}
}
