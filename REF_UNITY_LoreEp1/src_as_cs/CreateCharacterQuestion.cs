using System;
using UnityEngine;
using UnityEngine.UI;
using System.Collections;

namespace Yunjr
{
	public struct Phrase
	{
		public string phrase;
		public int[] modifier;

		public Phrase(string _phrase, int _m2, int _m3, int _m4, int _m5, int _m6, int _m7, int _m8)
		{
			Debug.Assert((int)CLASS.KNIGHT == 2 && (int)CLASS.ESPER == 8);

			phrase = _phrase;
			modifier = new int[CreateCharacter.NUM_MODIFIER] { _m2, _m3, _m4, _m5, _m6, _m7, _m8 };
		}
	};

	public class STR
	{

		public static readonly string[] QUESTIONS =
		{
			"자, 눈을 감고 떠올려 보자.\n"
			+ "당신이 생각하는 당신은 어떤 부류의 사람\n"
			+ "이라 생각하는가?",

			"당신은 전쟁터에 배치가 되었다.\n"
			+ "남에게 비친 자신의 모습은 어떤 사람이기\n"
			+ "를 원하는가?",

			"당신은 이미 성인이다.\n"
			+ "기술적인 목적을 이루기 위한 방법에 대한\n"
			+ "당신의 생각이 궁금하다.",

			"좀 어려운 질문일 수는 있다.\n"
			+ "신체와 정신에 대한 당신의 생각은 어떠한\n"
			+ "가?",

			"당신은 자신이 속한 이익 집단이나 종교나\n"
			+ "맹약에 대해서 어떤 생각을 가지고 있는가?"
		};

		public static readonly Phrase[][][] CHOICES = new Phrase[CreateCharacter.MAX_QUESTION][][]
		{
			// #1-x-x
			// [대분류]<KN,HU,MO><PA,AS><MA,ES>
			new Phrase[CreateCharacter.MAX_CHOICE][]
			{
				new Phrase[]
				{
					new Phrase
					(
						"1) 나는 나의 힘을 믿는 주의다.  모든 난\n"+
						"   관을 헤쳐 나갈 수 있었던 이유는 바로\n"+
						"   내 두 손이 있어서다.",
						6, 4, 5, 3, 2, 1, 1),
					new Phrase
					(
						"1) 나는 남들보다 많은 수련을 했다. 그리\n"+
						"   고  나의 몸을 가장 효율적으로 움직이\n"+
						"   는 방법을 안다.",
						4, 6, 5, 2, 3, 1, 1)
				},
				new Phrase[]
				{
					new Phrase
					(
						"2) 힘과 정신은 결국은 하나이다.  강인한\n"+
						"   힘은 물론  강인한 정신을 가져야만 진\n"+
						"   정한 나라고 할 수 있다.",
						3, 3, 3, 4, 5, 2, 2),
					new Phrase
					(
						"2) 물리적인 힘은 중요하다.  그리고 그것\n"+
						"   을 뒷받침할 마력도 필요하다.  그래서\n"+
						"   게을러서는 안 된다.",
						1, 2, 0, 5, 4, 5, 4)
				},
				new Phrase[]
				{
					new Phrase
					(
						"3) 많은 지식을 통해  정신력을  운용하는\n"+
						"   것이야 말로  인간이 낼 수 있는  가장\n"+
						"   강력한 힘이라 생각한다.",
						2, 1, 1, 4, 3, 6, 4),
					new Phrase
					(
						"3) 자연의 힘과 감각의 힘을 믿는다. 끊임\n"+
						"   없이 연구하고  사람을 이롭게  만드는\n"+
						"   것이 가장 중요하다.",
						2, 2, 4, 1, 2, 4, 7)
				}
			},
			// #2-x-x
			new Phrase[CreateCharacter.MAX_CHOICE][]
			{
				new Phrase[]
				{
					new Phrase
					(
						"1) 적을 바로 앞에서 마주하면서도 거침없\n"
						+ "   는 용맹을 떨치는 자.",
						5, 2, 5, 5, 2, 1, 2),
					new Phrase
					(
						"1) 아군에게는 든든한 방패이고, 적들에게\n"
						+ "   는 날카로운 검과 같은 존재.",
						5, 2, 5, 5, 1, 3, 1)
				},
				new Phrase[]
				{
					new Phrase
					(
						"2) 적의 눈이 닿지 않는 곳에서도 적의 약\n"
						+ "   점을 단번에 공략하여 적들이 두려움에\n"
						+ "   떨게 만드는 자.",
						2, 5, 1, 2, 5, 4, 3),
					new Phrase
					(
						"2) 시기 적절하게 적의 허점을 노려, 전세\n"
						+ "   를 바꾸어 놓는 자.",
						3, 4, 2, 3, 5, 4, 1)
				},
				new Phrase[]
				{
					new Phrase
					(
						"3) 적들의 마음을 혼란 시키고  내부를 분\n"
						+ "   열 시켜서  적들이 스스로 무너지게 만\n"
						+ "   는 자.",
						1, 2, 3, 2, 4, 3, 6),
					new Phrase
					(
						"3) 전세를  미리 예측하고  배치를 꿰뚫어\n"
						+ "   보아서,  항상 아군이 유리한 상황으로\n"
						+ "   만들어 가는 자.",
						2, 4, 2, 2, 2, 3, 6)
				}
			},
			// #3-x-x
			new Phrase[CreateCharacter.MAX_CHOICE][]
			{
				new Phrase[]
				{
					new Phrase
					(
						"1) 목적을 이루기 위해서는 도구가 필요하\n"
						+ "   다.  그래서 그 도구를 잘 쓰도록 손에\n"
						+ "   서 놓지 않았다.",
						5, 4, 0, 5, 3, 1, 3),
					new Phrase
					(
						"1) 무엇인가를 손에 익혀 두면  결국 제대\n"
						+ "   로 쓰일 날이 오게 된다.  그래서 그런\n"
						+ "   연습을 꾸준히 했다.",
						5, 3, 0, 5, 4, 1, 3)
				},
				new Phrase[]
				{
					new Phrase
					(
						"2) 도구를 쓰든 몸을 단련하든  내가 정한\n"+
						"   목표를 이루는 것 자체가 우선이다.",
						1, 5, 3, 1, 5, 2, 5),
					new Phrase
					(
						"2) 어떠한 목적이냐에 따라 기술이 달라지\n"+
						"   므로  그러한 방법에 대해 말하기는 어\n"+
						"   렵다.",
						1, 5, 3, 1, 4, 4, 4)
				},
				new Phrase[]
				{
					new Phrase
					(
						"3) 과연 이 세상에서 믿을 만한 것이 무엇\n"+
						"   을 있을까.  아마도 내 몸 자체가 기술\n"+
						"   일 것이다.",
						4, 1, 6, 3, 1, 5, 1),
					new Phrase
					(
						"3) 모든 것을 다 잃더라도 내 몸은 남기에,\n"+
						"   모든 기술은 내 몸이 기억하도록 만들었\n"+
						"   다.",
						3, 1, 6, 4, 1, 5, 2)
				}
			},
			// #4-x-x
			new Phrase[CreateCharacter.MAX_CHOICE][]
			{
				new Phrase[]
				{
					new Phrase
					(
						"1) 잘 모르겠다. 하지만 건전한 몸에 건전\n"+
						"   한 정신이 깃든다고 생각한다.",
						5, 4, 3, 3, 4, 1, 1),
					new Phrase
					(
						"1) 정신력을 말하는 것이라면 자신 있다.\n"+
						"   육체적 한계를 정신력으로 버티는 그것\n"+
						"   말이다.",
						5, 2, 3, 2, 5, 2, 2)
				},
				new Phrase[]
				{
					new Phrase
					(
						"2) 정신이라 함은 신을 말하는 것인가? 그\n"+
						"   렇다면  나는 신을 섬긴다고 이야기 할\n"+
						"   수 있다.",
						1, 4, 1, 7, 2, 3, 3),
					new Phrase
					(
						"2) 그 둘 간의 조화가 필요한 것이라 생각\n"+
						"   된다. 몸이 가는 곳에 마음도 간다.",
						2, 3, 2, 5, 3, 3, 3)
				},
				new Phrase[]
				{
					new Phrase
					(
						"3) 정신이란 수련을 통해 얻어진다고 생각\n"+
						"   한다.  그 둘을 떼어 놓고  생각하기는\n"+
						"   어렵다.",
						3, 3, 5, 1, 2, 4, 4),
					new Phrase
					(
						"3) 신체는 정신의 능력을 발현하는 도구이\n"+
						"   다.  그래서 그 도구의 단련도 어느 정\n"+
						"   도 필요하다.",
						2, 2, 4, 1, 2, 5, 5)
				}
			},
			// #5-x-x
			new Phrase[CreateCharacter.MAX_CHOICE][]
			{
				new Phrase[]
				{
					new Phrase
					(
						"1) 절대적이다.  모든 일은 신뢰와 의리를\n"+
						"   바탕으로 판단되어야 한다.",
						3, 1, 4, 5, 5, 3, 1),
					new Phrase
					(
						"1) 그러한 것을 거스르는 자는  용서할 수\n"+
						"   없다. 맹약을 저버린 자는 끝까지 응징\n"+
						"   해야 한다.",
						3, 1, 5, 4, 6, 2, 1)
				},
				new Phrase[]
				{
					new Phrase
					(
						"2) 모든 것은 계약에 의한 관계이다. 서로\n"+
						"   간의 신뢰로 모두 이득을 얻을 수 있게\n"+
						"   해야 한다.",
						5, 4, 1, 2, 1, 5, 3),
					new Phrase
					(
						"2) 나에게 신뢰를 주는 이상, 나도 그들을\n"+
						"   신뢰할 것이고 배신하지 않는다.",
						5, 3, 3, 2, 1, 4, 3)
				},
				new Phrase[]
				{
					new Phrase
					(
						"3) 잘 모르겠다.  그런 것에 대한 강한 소\n"+
						"   속감을 가져 본 적이 없었기 때문이다.",
						1, 5, 3, 3, 2, 2, 5),
					new Phrase
					(
						"3) 적어도  다른 쪽에게  피해를 입혀서는\n"+
						"   안 된다고 생각한다. 그렇지 않으면 사\n"+
						"   회적으로 독이다.",
						2, 4, 3, 3, 3, 2, 5)
				}
			}
		};
	}
}

namespace Yunjr
{
	public class CreateCharacterQuestion : MonoBehaviour
	{
		public Text m_text_question;
		public Text m_text_choice;
		public Button[] m_num_button;

		private int _question_step = 0;
		int[,] _now_clipped = new int[3, 2];
		int[,] _selected = new int[CreateCharacter.MAX_QUESTION, 2];

		// Use this for initialization
		void Start()
		{
			_question_step = -1;

			goNextQuestionStep();
		}

		public void goNextQuestionStep()
		{
			_runQuestionStep(++_question_step);
		}

		public void OnCreateCharacterNumberClick(int number)
		{
			String s = String.Format("OnCreateCharacterNumberClick({0})", number);
			Debug.Log(s);

			_selected[_question_step, 0] = _now_clipped[number, 0];
			_selected[_question_step, 1] = _now_clipped[number, 1];

			goNextQuestionStep();
		}

		private void _runQuestionStep(int step)
		{
			if (step >= 0 && step < CreateCharacter.MAX_QUESTION)
			{
				m_text_question.text = STR.QUESTIONS[step];

				LibUtil.Set<int> set = new LibUtil.Set<int>();
				_now_clipped[0, 0] = LibUtil.GetRandomIndex(ref set, 3);
				_now_clipped[1, 0] = LibUtil.GetRandomIndex(ref set, 3);
				_now_clipped[2, 0] = LibUtil.GetRandomIndex(ref set, 3);

				int max_step = STR.CHOICES.Length;
				step = Math.Min(step, max_step - 1);

				_now_clipped[0, 1] = LibUtil.GetRandomIndex(STR.CHOICES[step][_now_clipped[0, 0]].Length);
				_now_clipped[1, 1] = LibUtil.GetRandomIndex(STR.CHOICES[step][_now_clipped[1, 0]].Length);
				_now_clipped[2, 1] = LibUtil.GetRandomIndex(STR.CHOICES[step][_now_clipped[2, 0]].Length);

				m_text_choice.text = "";

				for (int i = 0; i < CreateCharacter.MAX_CHOICE; i++)
				{
					if (i > 0)
						m_text_choice.text += "\n\n";

					System.Text.StringBuilder str = new System.Text.StringBuilder(STR.CHOICES[step][_now_clipped[i, 0]][_now_clipped[i, 1]].phrase);
					str[0] = Convert.ToChar('1' + i);
					m_text_choice.text += str.ToString();
				}
			}
			else if (step == CreateCharacter.MAX_QUESTION)
			{
				int[] sum_modifier = new int[CreateCharacter.NUM_MODIFIER];

				System.Array.Clear(sum_modifier, 0, sum_modifier.Length);

				for (int i = 0; i < CreateCharacter.MAX_QUESTION; i++)
				{
					String s = String.Format("선택 {0}-{1}-{2}", i, _selected[i, 0], _selected[i, 1]);
					Debug.Log(s);

					Debug.Assert(sum_modifier.Length == STR.CHOICES[i][_selected[i, 0]][_selected[i, 1]].modifier.Length);

					for (int j = 0; j < sum_modifier.Length; j++)
						sum_modifier[j] += STR.CHOICES[i][_selected[i, 0]][_selected[i, 1]].modifier[j];
				}

				// TODO2: 디버깅용 
				{
					String s = String.Format(
						"     KN HU MO PA AS MA ES\n" +
						"누적 {0,2}:{1,2}:{2,2}:{3,2}:{4,2}:{5,2}:{6,2}"
						, sum_modifier[0]
						, sum_modifier[1]
						, sum_modifier[2]
						, sum_modifier[3]
						, sum_modifier[4]
						, sum_modifier[5]
						, sum_modifier[6]
					);

					Debug.Log(s);
				}

				Debug.Assert(CreateCharacter.modifier_weight.Length == sum_modifier.Length);

				for (int index = 0; index < CreateCharacter.modifier_weight.Length; index++)
					CreateCharacter.modifier_weight[index] = sum_modifier[index];

				CreateCharacter.NextStep();
			}
			else
			{
				Debug.Assert(false);
			}
		}
	}
}
