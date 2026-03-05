
using System.Collections;
using System.Collections.Generic;

using UnityEngine;
using UnityEngine.UI;

public class ScreenFade: MonoBehaviour
{
	public delegate void FnCallBack0();

	public float fading_seconds = 2.0f;

	private Image _target_obj;

	private const float _ALPHA_MIN = 0.0f;
	private const float _ALPHA_MAX = 1.0f;
	private float _elapsed_sec = 0.0f;

	private bool _in_action = false;

	void Awake()
	{
		_target_obj = GetComponent<Image>();
	}

	public void StartFadeOut(FnCallBack0 fn_callback = null)
	{
		if (!_in_action)
			StartCoroutine(FadeOut(fn_callback));
	}

	IEnumerator FadeOut(FnCallBack0 fn_callback = null)
	{
		_in_action = true;
		_elapsed_sec = 0f;

		Color color = _target_obj.color;
		color.a = Mathf.Lerp(_ALPHA_MIN, _ALPHA_MAX, _elapsed_sec);

		while (color.a < _ALPHA_MAX)
		{
			_elapsed_sec += Time.deltaTime / fading_seconds;

			color.a = Mathf.Lerp(_ALPHA_MIN, _ALPHA_MAX, _elapsed_sec);
			_target_obj.color = color;

			yield return null;
		}

		_in_action = false;

		if (fn_callback != null)
			fn_callback();
	}
}
