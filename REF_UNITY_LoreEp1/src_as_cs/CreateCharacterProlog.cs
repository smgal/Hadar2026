using UnityEngine;
using UnityEngine.UI;
using System.Collections;

namespace Yunjr
{
	public class CreateCharacterProlog: MonoBehaviour
	{
		public Button m_ok_button;
		private Animator _animator;
		private Image _button_image;
		private Color[] _button_color = new Color[2];

		// Use this for initialization
		void Start()
		{
			_animator = gameObject.GetComponent<Animator>();
			_button_image = m_ok_button.GetComponent<Image>();

			_button_color[1] = _button_image.color;
			_button_color[0] = _button_color[1];
			_button_color[0].a *= 0.2f;

			_SetButtonDisabled();
		}

		private void _SetButtonEnabled()
		{
			m_ok_button.interactable = true;
			_button_image.color = _button_color[1];
		}

		private void _SetButtonDisabled()
		{
			m_ok_button.interactable = false;
			_button_image.color = _button_color[0];
		}

		public void OnCreateCharacterPressAnyKey(int step)
		{
			switch (step)
			{
			case 0:
				break;
			case 1:
			case 2:
			case 3:
			case 4:
				_animator.speed = 0;
				_SetButtonEnabled();
				break;
			}
		}

		public void OnCreateCharacterOkClick()
		{
			_animator.speed = 1;
			_SetButtonDisabled();
		}

		public void OnCreateCharacterAnimationEnd()
		{
			_animator.StopPlayback();
			_SetButtonEnabled();

			CreateCharacter.NextStep();
		}
	}
}
