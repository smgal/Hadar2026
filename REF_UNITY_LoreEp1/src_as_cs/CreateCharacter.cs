using UnityEngine;
using System.Collections;

namespace Yunjr
{
	public class CreateCharacter: MonoBehaviour
	{
		// 질문의 총 수
		public const int MAX_QUESTION = 5;
		// 선택지의 총 수
		public const int MAX_CHOICE = 3;
		// 영향을 주는 파라미터의 개수
		public const int NUM_MODIFIER = 7;
		// 합격점
		public const float CUT_OFF_POINT = 3.5f * MAX_QUESTION;
		// 최소 합격수
		public const int MIN_ACCEPTANCE = 2;

		public static int[] modifier_weight = new int[NUM_MODIFIER];

		public static GameObject[] m_animator = new GameObject[4];
		private static int _step = 0;

		void Awake()
		{
			// Back pannel의 모든 차일드를 enable 한다.
			{
				GameObject back_panel = GameObject.FindGameObjectWithTag("CreateCharacterBackPanel");
				for (int index = 0; index < back_panel.transform.childCount; index++)
					back_panel.transform.GetChild(index).gameObject.SetActive(true);
			}

			// 그 중에 애니메이션 홀더들을 기록한다.
			m_animator[0] = GameObject.FindGameObjectWithTag("CreateCharacterProlog");
			m_animator[1] = GameObject.FindGameObjectWithTag("CreateCharacterQuestion");
			m_animator[2] = GameObject.FindGameObjectWithTag("CreateCharacterDecision");
			m_animator[3] = GameObject.FindGameObjectWithTag("CreateCharacterEpilogue");
			/*
			// 테스트용
			_step = 2;
			modifier_weight[0] = 10;
			modifier_weight[1] = 10;
			modifier_weight[2] = 10;
			modifier_weight[3] = 10;
			modifier_weight[4] = 20;
			modifier_weight[5] = 10;
			modifier_weight[6] = 10;
			*/
			// 먼저 첫 번째 스텝을 시작
			_SetStep(_step);
		}

		public static void NextStep()
		{
			_SetStep(++_step);
		}

		private static void _SetStep(int step)
		{
			if (m_animator != null)
			{ 
				for (int i = 0; i < m_animator.Length; i++)
					m_animator[i].SetActive(i == step);
			}
		}
	}
}
