
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	namespace Npc
	{
		class TrainingCenterJob
		{
			private YunjrMap _associated_map;

			public TrainingCenterJob(YunjrMap map)
			{
				_associated_map = map;

				_associated_map.Talk("@F여기는 군사 훈련소 입니다.@@\n");
				_associated_map.Talk("@F만약 당신이 원한다면 새로운 신분으로 바꿀 수가 있습니다.@@");

				if (GameRes.party.gold >= CONFIG.COST_OF_JOB_CHANGING)
				{
					_associated_map.Talk(String.Format("\n신분을 바꾸는 비용은 금 {0}개입니다.", CONFIG.COST_OF_JOB_CHANGING));

					_associated_map.RegisterKeyPressedAction(_ChangeJob);
					_associated_map.PressAnyKey();
				}
				else
				{
					_associated_map.Talk(String.Format("\n그러나 일행에게는 신분을 바꿀때 드는 비용인 금 {0}개가 없습니다.", CONFIG.COST_OF_JOB_CHANGING));
				}
			}

			private void _ChangeJob()
			{
				_associated_map.Select_Init
				(
					"@F누가 신분을 바꾸겠습니까?@@",
					"@A한 명을 고르시오 ---@@\n",
					null
				);

				for (int i = 0; i < GameRes.player.Length; i++)
					if (GameRes.player[i].IsValid())
						_associated_map.Select_AddItem(GameRes.player[i].Name);

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						if (selected > 0)
							_ChangeJobSub1(GameRes.player[selected - 1]);
					}
				);
			}

			private void _ChangeJobSub1(ObjPlayer player)
			{
				CLASS clazz = player.clazz;

				if (clazz == CLASS.UNKNOWN)
				{
					_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 신분을 바꿀 수 있는 계층이 아닙니다.");
					return;
				}
				else if (clazz == CLASS.ESPER)
				{
					ObjNameBase class_name = new ObjNameBase();
					class_name.SetName(LibUtil.GetAssignedString(clazz));
					_associated_map.Talk(class_name.GetName(ObjNameBase.JOSA.SUB) + " 신분을 바꿀 수 없습니다.");
					return;
				}

				CLASS_TYPE class_type = Yunjr.LibUtil.GetClassType(clazz);

				if (class_type != CLASS_TYPE.MAGIC_USER)
				{
					// "기사","사냥꾼","전투승","전사","암살자","검사"
					CLASS[] CHANGEABLE_CLASS = new CLASS[] { CLASS.KNIGHT, CLASS.HUNTER, CLASS.MONK, CLASS.PALADIN, CLASS.ASSASSIN, CLASS.SWORDMAN };
					_ChangeJobSub2(player, CHANGEABLE_CLASS);
				}
				else
				{
					//"메이지","컨저러","주술사","위저드","강령술사","대마법사","타임워커"
					CLASS[] CHANGEABLE_CLASS = new CLASS[] { CLASS.MAGE, CLASS.CONJURER, CLASS.SORCERER, CLASS.WIZARD, CLASS.NECROMANCER, CLASS.ARCHIMAGE, CLASS.TIMEWALKER };
					_ChangeJobSub2(player, CHANGEABLE_CLASS);
				}
			}

			private void _ChangeJobSub2(ObjPlayer player, CLASS[] CHANGEABLE_CLASS)
			{
				List<CLASS> available_class = new List<CLASS>();

				foreach (CLASS c in CHANGEABLE_CLASS)
				{
					if (player.clazz != c)
					{
						for (int i = 0; i < (int)SKILL_TYPE.MAX; i++)
						{
							int min = ObjPlayer.GetMinValueOfSkill(c, (SKILL_TYPE)i);
							if (player.intrinsic_skill[i] < min)
								goto NOT_AVAILABLE;
						}

						available_class.Add(c);
					}

				NOT_AVAILABLE:
					;
				}

				if (available_class.Count == 0)
				{
					_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 바꿀 수 있는 신분이 없습니다.");
					return;
				}

				_associated_map.Select_Init
				(
					"@C바꾸고 싶은 신분을 고르십시오.@@",
					"",
					null
				);

				foreach (CLASS c in available_class)
					_associated_map.Select_AddItem("   " + LibUtil.GetAssignedString(c));

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						if (selected > 0)
						{
							CLASS selected_class = available_class[selected - 1];
							player.clazz = selected_class;
							GameRes.party.core.gold -= CONFIG.COST_OF_JOB_CHANGING;

							ObjNameBase class_name = new ObjNameBase();
							class_name.SetName(LibUtil.GetAssignedString(selected_class));

							_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " " + class_name.GetName(ObjNameBase.JOSA.SUB2) + " 되었습니다.");
						}

						GameObj.UpdatePlayerStatus();
					}
				);
			}
		}

	}
}
