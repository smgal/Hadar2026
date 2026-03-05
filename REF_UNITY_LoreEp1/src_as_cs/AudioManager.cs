using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public class AudioManager : MonoBehaviour
	{
		public static AudioManager m_instance;

		[Serializable]
		public class Pair
		{
			public string name;
			public AudioClip clip;
		}

		public AudioManager.Pair[] m_audio_clips;

		AudioSource m_audio_source;

		void Awake()
		{
			if (AudioManager.m_instance == null)
				AudioManager.m_instance = this;
		}

		// Use this for initialization
		void Start()
		{
			m_audio_source = GetComponent<AudioSource>();
		}

		public void Play(String bgm_name)
		{
			if (m_audio_source == null)
				m_audio_source = GetComponent<AudioSource>();

			foreach (var pair in m_audio_clips)
			{
				if (pair.name == bgm_name)
				{
					m_audio_source.clip = pair.clip;
					m_audio_source.Play();

					return;
				}
			}
		}

		public void Stop()
		{
			if (m_audio_source == null)
				m_audio_source = GetComponent<AudioSource>();

			m_audio_source.Stop();
		}

		public void Mute(bool on)
		{
			if (m_audio_source == null)
				m_audio_source = GetComponent<AudioSource>();

			m_audio_source.mute = on;
		}
	}
}
