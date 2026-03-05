
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	namespace Npc
	{
		class Hospital
		{
			private YunjrMap _associated_map;

			public Hospital(YunjrMap map)
			{
				_associated_map = map;

				_associated_map.Talk("@F여기는 병원입니다.@@");

				_associated_map.RegisterKeyPressedAction
				(
					_HospitalSub1
				);

				_associated_map.PressAnyKey();
			}

			private void _HospitalSub1()
			{
				_associated_map.Select_Init
				(
					"@F누가 치료를 받겠습니까?@@",
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
							_HospitalSub2(GameRes.player[selected - 1]);

						GameObj.UpdatePlayerStatus();
					}
				);
			}

			private void _HospitalSub2(ObjPlayer player)
			{
				_associated_map.Select_Init
				(
					"@F어떤 치료입니까@@",
					"",
					new string[]
					{
						"상처를 치료",
						"독을 제거",
						"의식의 회복",
						"부활"
					}
				);

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 0:
								_HospitalSub1();
								break;
							case 1:
								{
									bool should_skip = true;

									if (player.dead > 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 이미 죽은 상태입니다");
									else if (player.unconscious > 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 이미 의식 불명입니다");
									else if (player.poison > 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 독이 퍼진 상태입니다");
									else if (player.hp >= player.GetMaxHP())
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 치료할 필요가 없습니다");
									else
										should_skip = false;

									if (should_skip)
									{
										_associated_map.RegisterKeyPressedAction
										(
											delegate ()
											{
												_HospitalSub2(player);
											}
										);

										_associated_map.PressAnyKey();
									}
									else
									{
										int hp_to_be_added = player.GetMaxHP() - player.hp;
										int amount_to_pay = Mathf.RoundToInt(hp_to_be_added * ((float)player.status[(int)STATUS.LEV] / 10.0f)) + 1;

										if (GameRes.party.gold < amount_to_pay)
										{
											_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_GOLD));

											_associated_map.RegisterKeyPressedAction
											(
												delegate ()
												{
													_HospitalSub2(player);
												}
											);

											_associated_map.PressAnyKey();
										}
										else
										{
											GameRes.party.gold -= amount_to_pay;
											player.hp = player.GetMaxHP();

											_associated_map.Talk(player.GetGenderName().GetName() + "의 모든 건강이 회복되었다");

											GameObj.UpdatePlayerStatus();

											_associated_map.RegisterKeyPressedAction
											(
												_HospitalSub1
											);

											_associated_map.PressAnyKey();
										}
									}
								}
								break;
							case 2:
								{
									bool should_skip = true;

									if (player.dead > 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 이미 죽은 상태입니다");
									else if (player.unconscious > 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 이미 의식 불명입니다");
									else if (player.poison <= 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 독에 걸리지 않았습니다");
									else
										should_skip = false;

									if (should_skip)
									{
										_associated_map.RegisterKeyPressedAction
										(
											delegate ()
											{
												_HospitalSub2(player);
											}
										);

										_associated_map.PressAnyKey();
									}
									else
									{
										int amount_to_pay = player.status[(int)STATUS.LEV] * 10;

										if (GameRes.party.gold < amount_to_pay)
										{
											_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_GOLD));

											_associated_map.RegisterKeyPressedAction
											(
												delegate ()
												{
													_HospitalSub2(player);
												}
											);

											_associated_map.PressAnyKey();
										}
										else
										{
											GameRes.party.gold -= amount_to_pay;
											player.poison = 0;

											_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 독이 제거 되었습니다");

											GameObj.UpdatePlayerStatus();

											_associated_map.RegisterKeyPressedAction
											(
												_HospitalSub1
											);

											_associated_map.PressAnyKey();
										}
									}
								}
								break;
							case 3:
								{
									bool should_skip = true;

									if (player.dead > 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 이미 죽은 상태입니다");
									else if (player.unconscious == 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 의식불명이 아닙니다");
									else
										should_skip = false;

									if (should_skip)
									{
										_associated_map.RegisterKeyPressedAction
										(
											delegate ()
											{
												_HospitalSub2(player);
											}
										);

										_associated_map.PressAnyKey();
									}
									else
									{
										int amount_to_pay = player.unconscious * 2;

										if (GameRes.party.gold < amount_to_pay)
										{
											_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_GOLD_2));
											_associated_map.Talk("");
											_associated_map.Talk(player.GetName() + "의 의식을 돌리기 위해서는");
											_associated_map.Talk(String.Format("@C{0}@@ 만큼의 돈이 필요 합니다.", amount_to_pay));

											_associated_map.RegisterKeyPressedAction
											(
												delegate ()
												{
													_HospitalSub2(player);
												}
											);

											_associated_map.PressAnyKey();
										}
										else
										{
											GameRes.party.gold -= amount_to_pay;
											player.unconscious = 0;
											player.hp = 1;

											_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 의식을 차렸습니다");

											GameObj.UpdatePlayerStatus();

											_associated_map.RegisterKeyPressedAction
											(
												_HospitalSub1
											);

											_associated_map.PressAnyKey();
										}
									}
								}
								break;
							case 4:
								{
									bool should_skip = true;

									if (player.dead == 0)
										_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 죽지 않았습니다");
									else
										should_skip = false;

									if (should_skip)
									{
										_associated_map.RegisterKeyPressedAction
										(
											delegate ()
											{
												_HospitalSub2(player);
											}
										);

										_associated_map.PressAnyKey();
									}
									else
									{
										int amount_to_pay = player.dead * 100 + 400;

										if (GameRes.party.gold < amount_to_pay)
										{
											_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_GOLD_2));
											_associated_map.Talk("");
											_associated_map.Talk(player.GetName(ObjNameBase.JOSA.OBJ) + " 다시 살리기 위해서는");
											_associated_map.Talk(String.Format("@C{0}@@ 만큼의 돈이 필요 합니다.", amount_to_pay));

											_associated_map.RegisterKeyPressedAction
											(
												delegate ()
												{
													_HospitalSub2(player);
												}
											);

											_associated_map.PressAnyKey();
										}
										else
										{
											GameRes.party.gold -= amount_to_pay;
											player.dead = 0;

											if (player.unconscious > player.GetMaxHP())
												player.unconscious = player.GetMaxHP();

											_associated_map.Talk(player.GetName(ObjNameBase.JOSA.SUB) + " 다시 살아났습니다");

											GameObj.UpdatePlayerStatus();

											_associated_map.RegisterKeyPressedAction
											(
												_HospitalSub1
											);

											_associated_map.PressAnyKey();
										}
									}
								}
								break;
						}
					}
				);
			}
		}
	}
}
