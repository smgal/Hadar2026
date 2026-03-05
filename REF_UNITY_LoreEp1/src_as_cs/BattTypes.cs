
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Yunjr
{
	namespace Batt
	{
		public static class Types
		{
			public const int NOT_ASSIGNED = -1;

			public enum STATE
			{
				ON_MEAURE_COMBAT_POWER,
				IN_MEAURE_COMBAT_POWER,
				ON_COMMAND_EACH,
				IN_COMMAND_EACH,
				IN_WAITING,
				JUST_SELECTED,
				IN_PRESS_ANY_KEY,
				ON_BATTLE,
				IN_BATTLE,
				RESULT_WIN,
				RESULT_LOSE,
				RESULT_RUN_AWAY,
				MAX
			}

			public enum RESULT_OF_ATTACK
			{
				HESITATE,
				HIT,
				MISS,
				CRITICAL_HIT,
				CRITICAL_MISS,
				NOT_ENOUGH_SP
			}

			public enum RESULT_OF_ATTACKED
			{
				RESISTED,
				DODGED,
				NO_DAMAGED,
				DAMAGED,
				POISONED,
				TURN_TO_UNCONSCIOUS,
				STILL_UNCONSCIOUS,
				TURN_TO_DEAD,
				STILL_DEAD
			}
		};
	}
}
