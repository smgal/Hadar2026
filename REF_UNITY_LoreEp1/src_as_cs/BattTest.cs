
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Yunjr
{
	public class BattTest : MonoBehaviour
	{
		public BattMain m_batt_main;

		// Use this for initialization
		void Start()
		{
		}

		// Update is called once per frame
		void Update()
		{
		}

		public void OnBattStart()
		{
			// public static Yunjr.ObjParty party = new Yunjr.ObjParty();
			// public static Yunjr.ObjPlayer[] player = new Yunjr.ObjPlayer[CONFIG.MAX_PLAYER];
			// public static Yunjr.ObjEnemy[] enemy = new Yunjr.ObjEnemy[CONFIG.MAX_ENEMY];

			if (GameRes.player[0] == null)
			{
				GameRes.party.core.year -= 1;
				GameRes.party.core.day = 4;
				GameRes.party.core.hour = 2;

				GameRes.party.core.food = 10;
				GameRes.party.core.gold = 1000;

				////////////////////////////////////////////////////////////////////////////

				for (int i = 0; i < GameRes.player.Length; i++)
					GameRes.player[i] = new Yunjr.ObjPlayer();

				for (int i = 0; i < GameRes.enemy.Length; i++)
					GameRes.enemy[i] = new Yunjr.ObjEnemy(i);

				////////////////////////////////////////////////////////////////////////////

				const int LEVEL = 5;

				PlayerParams[] player_params =
				{
					new PlayerParams("테스트1", GENDER.MALE, CLASS.ASSASSIN, LEVEL),
					new PlayerParams("테스트2", GENDER.MALE, CLASS.KNIGHT, LEVEL),
					new PlayerParams("테스트3", GENDER.MALE, CLASS.MAGE, LEVEL),
					new PlayerParams("테스트4", GENDER.MALE, CLASS.MONK, LEVEL)
				};

				for (int i = 0; i < Mathf.Min(GameRes.player.Length, player_params.Length); i++)
				{
					GameRes.player[i] = ObjPlayer.CreateCharacter(player_params[i], LEVEL);
				}
			}

			m_batt_main.Init(new int[,] { { 1, 10 }, { 2, 10 }, { 3, 10 }, { 4, 10 }, { 5, 10 }, { 6, 10 } });

			for (int i = 0; i < CONFIG.MAX_ENEMY; i++)
				if (GameRes.enemy[i].IsValid())
					GameRes.enemy[i].attrib.name = String.Format("Mons {0}", i + 1);

			m_batt_main.Run();
		}
	}
}
