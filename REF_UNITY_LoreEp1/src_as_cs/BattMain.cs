
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Yunjr
{
	public class BattMain : MonoBehaviour
	{
		public int MAX_ENEMY = 0;

		public void Init(int[,] ix_enemy)
		{
			MAX_ENEMY = ix_enemy.Length / ix_enemy.Rank;

			for (int i = 0; i < GameRes.enemy.Length; i++)
			{
				GameRes.enemy[i].Valid = (i < MAX_ENEMY);
				if (GameRes.enemy[i].Valid)
					GameRes.enemy[i]._New(ix_enemy[i, 0], ix_enemy[i, 1]);
			}
		}

		public void Run()
		{
			StartCoroutine(_Run());
		}

		IEnumerator _Run()
		{
			int count = 10;

			while (--count >= 0)
			{
				Debug.Log("QQQ" + count);
				yield return count;
			}
		}

	};
}
