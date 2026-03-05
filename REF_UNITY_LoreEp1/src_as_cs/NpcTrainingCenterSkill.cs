
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	namespace Npc
	{
		class TrainingCenterSkill
		{
			private YunjrMap _associated_map;

			public TrainingCenterSkill(YunjrMap map)
			{
				_associated_map = map;

				_associated_map.Talk("@F여기는 군사 훈련소 입니다.@@\n");
				_associated_map.Talk("@F당신이 쌓은 전투 경험을, 더욱 더 능숙하게 무기를 다루는데 적용할 수 있게 합니다.@@");

				_associated_map.RegisterKeyPressedAction(_ImproveSkill);
				_associated_map.PressAnyKey();
			}

			private void _ImproveSkill()
			{
				_associated_map.Select_Init
				(
					"@F누가 훈련을 받겠습니까?@@",
					"@A한 명을 고르시오 ---@@\n",
					null
				);

				for (int i = 0; i < GameRes.player.Length; i++)
				{
					if (GameRes.player[i].IsValid())
					{
						if (GameRes.player[i].exprience > 0)
							_associated_map.Select_AddItem(GameRes.player[i].Name);
						else
							_associated_map.Select_AddItem("<color=#2A2A2A>" + GameRes.player[i].Name + "@@");
					}
				}

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						if (selected > 0)
						{
							ObjPlayer player = GameRes.player[selected - 1];

							if (player.exprience > 0)
							{
								_ImproveSkillSub1(player);
							}
							else
							{
								_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 추가로 훈련을 받기에는 경험이 부족합니다.");
								_associated_map.RegisterKeyPressedAction(_ImproveSkill);
								_associated_map.PressAnyKey();
							}
						}
					}
				);
			}

			private void _ImproveSkillSub1(ObjPlayer player)
			{
				CLASS_TYPE class_type = Yunjr.LibUtil.GetClassType(player.clazz);

				switch (class_type)
				{
					case CLASS_TYPE.PHYSICAL_FORCE:
						_ChangeJobSub2(player, new SKILL_TYPE[] { SKILL_TYPE.WIELD, SKILL_TYPE.CHOP, SKILL_TYPE.STAB, SKILL_TYPE.HIT, SKILL_TYPE.SHOOT, SKILL_TYPE.SHIELD });
						break;
					case CLASS_TYPE.MAGIC_USER:
						_ChangeJobSub2(player, new SKILL_TYPE[] { SKILL_TYPE.HIT, SKILL_TYPE.DAMAGE, SKILL_TYPE.ENVIRONMENT, SKILL_TYPE.CURE, SKILL_TYPE.SUMMON, SKILL_TYPE.SPECIAL, SKILL_TYPE.ESP });
						break;
					case CLASS_TYPE.HYBRID1: // 전사
						_ChangeJobSub2(player, new SKILL_TYPE[] { SKILL_TYPE.WIELD, SKILL_TYPE.CHOP, SKILL_TYPE.STAB, SKILL_TYPE.HIT, SKILL_TYPE.SHOOT, SKILL_TYPE.SHIELD, SKILL_TYPE.CURE });
						break;
					case CLASS_TYPE.HYBRID2: // 암살자
						_ChangeJobSub2(player, new SKILL_TYPE[] { SKILL_TYPE.WIELD, SKILL_TYPE.CHOP, SKILL_TYPE.STAB, SKILL_TYPE.HIT, SKILL_TYPE.SHOOT, SKILL_TYPE.SUMMON, SKILL_TYPE.SPECIAL });
						break;
					case CLASS_TYPE.HYBRID3:  // 에스퍼
						_ChangeJobSub2(player, new SKILL_TYPE[] { SKILL_TYPE.WIELD, SKILL_TYPE.CHOP, SKILL_TYPE.STAB, SKILL_TYPE.HIT, SKILL_TYPE.SHOOT, SKILL_TYPE.SHIELD, SKILL_TYPE.ESP });
						break;
				}
			}

			private void _ChangeJobSub2(ObjPlayer player, SKILL_TYPE[] RELEVNT_SKILLS, int init_val = 1)
			{
				_associated_map.Select_Init
				(
					// "@C당신이 수련 하고 싶은 부분을 고르시오.@@",
					String.Format("@C남은 경험치: {0}@@", player.exprience),
					"",
					null,
					init_val
				);

				bool skill_master = (RELEVNT_SKILLS.Length > 0);
				int  num_available_skill = 0;

				foreach (SKILL_TYPE skill_type in RELEVNT_SKILLS)
				{
					string s = LibUtil.GetAssignedString(skill_type);
					Yunjr.LibUtil.SmTextAddSpace(ref s, 11);
					s += "<- " + player.intrinsic_skill[(int)skill_type];

					// s의 예> "베는 무기  <- 10" 

					int max_value_of_skill = ObjPlayer.GetMaxValueOfSkill(player.clazz, skill_type);

					if (max_value_of_skill == 0)
					{
						_associated_map.Select_AddItem("<color=#2A2A2A>" + s + "@@");
					}
					else if (player.intrinsic_skill[(int)skill_type] >= max_value_of_skill)
					{
						_associated_map.Select_AddItem("<color=#6ABA20>" + s + "@@");
						num_available_skill++;
					}
					else
					{
						_associated_map.Select_AddItem(s);
						skill_master = false;
						num_available_skill++;
					}
				}

				if (num_available_skill == 0)
				{
					// 기획상 이쪽으로 갈 일은 없어야 한다.
					_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 배울 수 있는 분야가 없습니다.");
					_associated_map.RegisterKeyPressedAction(_ImproveSkill);
					_associated_map.PressAnyKey();
				}
				else if (skill_master)
				{
					_associated_map.Select_Init
					(
						"@7" + player.GetName(ObjNameBase.JOSA.SUB) + " 모든 과정을 수료했으므로 모든 경험치를 레벨로 바꾸겠습니다.@@",
						"",
						new string[]
						{
							"모두 경험치로 바꾸겠습니다",
							"다음에 하겠습니다"
						}
					);

					_associated_map.Select_Run
					(
						delegate (int selected)
						{
							if (selected == 1)
							{
								player.accumulated_exprience += player.exprience;
								player.exprience = 0;
								player.Apply();
							}

							_ImproveSkill();
						}
					);
				}
				else
				{
					_associated_map.Select_Run
					(
						delegate (int selected)
						{
							if (selected > 0)
							{
								string failure_message = "";

								SKILL_TYPE skill_type = RELEVNT_SKILLS[selected - 1];
								int max_value_of_skill = ObjPlayer.GetMaxValueOfSkill(player.clazz, skill_type);

								if (max_value_of_skill > 0)
								{
									if (player.intrinsic_skill[(int)skill_type] < max_value_of_skill)
									{
										int need_exp = 15 * player.intrinsic_skill[(int)skill_type] * player.intrinsic_skill[(int)skill_type];
										if (need_exp <= player.exprience)
										{
											player.exprience -= need_exp;
											player.accumulated_exprience += need_exp;
											player.intrinsic_skill[(int)skill_type]++;
											player.Apply();

											_ChangeJobSub2(player, RELEVNT_SKILLS, selected);
										}
										else
											failure_message = "아직 경험치가 모자랍니다";
									}
									else
										failure_message = "이 분야는 더 배울 것이 없습니다";
								}
								else
									failure_message = "이 기술은 당신의 신분과 맞지 않습니다";

								if (failure_message != "")
								{
									_associated_map.Talk(failure_message);

									_associated_map.RegisterKeyPressedAction
									(
										delegate ()
										{
											_ChangeJobSub2(player, RELEVNT_SKILLS, selected);
										}
									);

									_associated_map.PressAnyKey();
								}
							}
						}
					);
				}
			}
		}
	}
}
