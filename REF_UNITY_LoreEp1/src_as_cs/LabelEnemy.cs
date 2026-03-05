
using UnityEngine;
using UnityEngine.UI;
using System.Collections;

namespace Yunjr
{
	public class LabelEnemy : MonoBehaviour
	{
		public Text _text_distance;
		public Text _text_name;
		public Image _bg_image;

		void Start()
		{
			// Text[] _text_list = GetComponentsInChildren<Text>();
			Debug.Assert(_text_distance != null);
			Debug.Assert(_text_name != null);
			Debug.Assert(_bg_image != null);
		}

		public void SetDistance(int distance)
		{
			if (distance > 0)
				_text_distance.text = "[" + distance + "]";
			else
				_text_distance.text = "";
		}

		public void SetName(string name)
		{
			_text_name.text = name;
		}

		public void SetNameColor(Color32 color32)
		{
			_text_name.color = color32;
		}

		public void SetBgColor(Color32 color32)
		{
			_bg_image.color = color32;
		}
	}
}
