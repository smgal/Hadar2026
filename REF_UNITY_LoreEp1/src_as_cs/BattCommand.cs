
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Yunjr
{
	namespace Batt
	{
		public class CommandSub
		{
			public int O = Batt.Types.NOT_ASSIGNED; // object
			public Batt.Types.RESULT_OF_ATTACK result_of_attack = Batt.Types.RESULT_OF_ATTACK.HESITATE;
			public Batt.Types.RESULT_OF_ATTACKED result_of_attacked = Batt.Types.RESULT_OF_ATTACKED.NO_DAMAGED;
			public int damage = 0;
		}

		public class Command: ICloneable
		{
			public int S = Batt.Types.NOT_ASSIGNED; // subject
			public int V = Batt.Types.NOT_ASSIGNED; // verb
			public int W = Batt.Types.NOT_ASSIGNED; // with
			public int O = Batt.Types.NOT_ASSIGNED; // object

			public Batt.Types.RESULT_OF_ATTACK result_of_attack = Batt.Types.RESULT_OF_ATTACK.HESITATE;
			public Batt.Types.RESULT_OF_ATTACKED result_of_attacked = Batt.Types.RESULT_OF_ATTACKED.NO_DAMAGED;
			public int damage = 0;

			public List<CommandSub> multi = new List<CommandSub>();

			public void Reset()
			{
				S = V = W = O = Batt.Types.NOT_ASSIGNED;
				result_of_attack = Batt.Types.RESULT_OF_ATTACK.HESITATE;
				result_of_attacked = Batt.Types.RESULT_OF_ATTACKED.NO_DAMAGED;
				damage = 0;
				multi.Clear();
			}

			public object Clone()
			{
				Command obj = new Command
				{
					S = this.S,
					V = this.V,
					W = this.W,
					O = this.O,
					result_of_attack = this.result_of_attack,
					result_of_attacked = this.result_of_attacked,
					damage = this.damage,
					multi = new List<CommandSub>(this.multi)
				};

				return obj;
			}
		}
	}
}
