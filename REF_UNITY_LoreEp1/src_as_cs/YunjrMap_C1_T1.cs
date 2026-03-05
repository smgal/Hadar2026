
using UnityEngine;
using UnityEngine.UI;
using System;
using System.Collections;
using System.Collections.Generic;

// 한 줄 허용 길이 150라인

/*
	Var
	10: 로드안과 대화 진행 정도

	Flag
		- Flag_IsSet(??))
		- Flag_Set(??);
	31: 로어성 왕궁 문 열림
	32: 로어성 문 열림
	33: Joe의 감옥이 열림
	34: Joe와 Join
	35: 무기고의 병사와 이야기
	36: 무기고에서 무기를 얻음
	37: Jr. Antares의 보물을 얻음
	41: 로드안 - 로어성의 성주 / 당신과 이야기 하고 싶어한다
	50: Jr. Antares 와 대화
	51: 성의 중앙 거리에 제작자 출현 
	
 */

namespace Yunjr
{
	public class YunjrMap_C1_T1 : YunjrMap
	{
		public override string GetPlaceName(byte degree_of_well_known)
		{
			if (degree_of_well_known > 0)
				return "로어성";
			else
				return "꽤 큰 성";
		}

		public override void OnPrepare()
		{
			GameRes.ChangeTileSet(TILE_SET.TOWN);
			CONFIG.TILE_BG_DEFAULT = 44;
			CONFIG.BGM = "LoreTown1";
		}

		public override void OnLoad(string prev_map, int from_x, int from_y)
		{
			Debug.Log("prev_map = " + prev_map);

			if (prev_map == "LoreContinent")
			{
				GameRes.party.Warp(50, 91);
				GameRes.party.SetDirection(0, -1);
			}
			else
			{
				GameRes.party.Warp(50, 31);
				GameRes.party.SetDirection(0, -1);
			}

			// 로어성을 나가는 이벤트
			GameRes.map_data.data[48, 92].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[49, 92].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[50, 92].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[51, 92].act_type = ACT_TYPE.ENTER;
			GameRes.map_data.data[52, 92].act_type = ACT_TYPE.ENTER;

			// Joe의 감옥 입구가 열림
			if (Flag_IsSet(33))
			{
				Map_ChangeTile(44, 14, 0);
			}

			if (Flag_IsSet(34))
			{
				GameRes.map_data.data[39, 14].ix_obj0 = 0;
				GameRes.map_data.data[39, 14].ix_obj1 = 0;
				GameRes.map_data.data[39, 14].act_type = ACT_TYPE.DEFAULT;
			}

			if (Flag_IsSet(31))
			{
				MapEx_ChangeTile(48, 51, 0);
				MapEx_ChangeTile(49, 51, 8);
				MapEx_ChangeTile(50, 51, 8);
				MapEx_ChangeTile(51, 51, 8);
				MapEx_ChangeTile(52, 51, 0);
				MapEx_ChangeTile(48, 52, 0);
				MapEx_ChangeTile(49, 52, 8);
				MapEx_ChangeTile(50, 52, 8);
				MapEx_ChangeTile(51, 52, 8);
				MapEx_ChangeTile(52, 52, 0);
			}

			if (Flag_IsSet(32))
			{
				MapEx_ChangeTile(48, 87, 8);
				MapEx_ChangeTile(49, 87, 8);
				MapEx_ChangeTile(50, 87, 8);
				MapEx_ChangeTile(51, 87, 8);
				MapEx_ChangeTile(52, 87, 8);
			}

			// Jr. Antares의 보물 길이 열림
			if (Flag_IsSet(50))
			{
				MapEx_ChangeTile(61, 78, 10);
				MapEx_ChangeTile(61, 79, 10);
				MapEx_ChangeTile(61, 80, 10);
				MapEx_ChangeTile(61, 81, 10);
				MapEx_ChangeTile(61, 82, 10, 7);

				GameRes.map_data.data[61, 81].act_type = ACT_TYPE.EVENT;
			}
			else
			{
				MapEx_ChangeTile(61, 79, 32);
				MapEx_ChangeTile(61, 80, 32);
				MapEx_ChangeTile(61, 81, 32);
				MapEx_ChangeTile(61, 82, 32);
			}

			// 무기고 앞의 이벤트
			GameRes.map_data.data[40, 78].act_type = ACT_TYPE.EVENT;

			// for test
			// GameRes.map.data[50, 46].ix_sprite = 51;
			// GameRes.map.data[50, 46].act_type = ACT_TYPE.TALK;

			/*
				if (prev_map == "TOWN2")
				{
					GameRes.party.Warp(48, 48);
					GameRes.party.SetDirection(1, 0);
				}
				else
				{
					GameRes.party.Warp(50, 48);
					GameRes.party.SetDirection(0, -1);
				}

				GameRes.map.data[47, 48].ix_sprite = 22;
				GameRes.map.data[47, 48].act_type = ACT_TYPE.ENTER;
			*/
			if (prev_map != "LoreContinent")
			{
				//GameRes.map.data[48, 46].ix_sprite = 0;
				//GameRes.map.data[48, 46].act_type = ACT_TYPE.EVENT;

				//GameRes.party.Warp(50, 46);
			}
				
		}

		public override void OnUnload()
		{
		}

		public override bool OnEvent(int event_id, out int post_event_id)
		{
			bool you_can_move_to_there = true;

			post_event_id = 0;

			if (Not(Flag_IsSet(41)) && OnArea(49, 29, 51, 29))
			{ 
				GameObj.SetHeaderText(LibUtil.SmTextToRichText("로드안 - 로어성의 성주\n<color=#FFBF40FF>당신과 이야기 하고 싶어한다.</color>"), 5);
				Flag_Set(41);
			}

			if (Not(Flag_IsSet(37)) && On(61, 81))
			{ 
				Talk("@F일행은 여기서 500 골드를 얻었다.@@");
				GameRes.party.gold += 500;
				Flag_Set(37);
			}

			if (On(47, 26) || On(50, 29))
			{
				// 로드안 뒤의 테스트용 던젼 입구
				GameRes.map_data.data[50, 25].ix_tile = 64;
				GameRes.map_data.data[50, 25].ix_obj0 = 0;
				GameRes.map_data.data[50, 25].ix_obj1 = 0;
				GameRes.map_data.data[50, 25].act_type = ACT_TYPE.ENTER;

				// 임시로 만든 동료 추가 푯말
				GameRes.map_data.data[48, 27].ix_obj1 = 112;
				GameRes.map_data.data[48, 27].act_type = ACT_TYPE.SIGN;

				// 임시로 만든 마지막 동료 추가 푯말
				GameRes.map_data.data[52, 27].ix_obj1 = 112;
				GameRes.map_data.data[52, 27].act_type = ACT_TYPE.SIGN;
			}

			if (On(40, 78))
			{
				if (Not(Flag_IsSet(35)))
				{
					Talk("잠깐 기다려주십시오.");
					Talk("");
					Talk("들어가시기 전에 저희에게 출입 권한을 받으셔야 합니다.");

					RegisterKeyPressedAction
					(
						delegate ()
						{
							this._MoveBack();
						}
					);
					PressAnyKey();
				}
				else
				{
					if (Not(Flag_IsSet(36)))
					{
						Talk("@4[이펙트 생략]@@");
						Talk("당신은 가장 기본적인 무기로 무장을 하였다.");

						RegisterKeyPressedAction
						(
							delegate ()
							{
								// 무기 얻기
								for (int i = 0; i < GameRes.player.Length - 2; i++)
								{
									if (GameRes.player[i].IsValid())
									{
										GameRes.player[i].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 3));
										GameRes.player[i].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(1));
									}
								}

								GameRes.party.SetDirection(1, 0);
								this._MoveBack();

								Flag_Set(36);
							}
						);
						PressAnyKey();
					}
					else
					{
						Talk("(다시 여기에 들어갈 필요는 없다.)");

						RegisterKeyPressedAction
						(
							delegate ()
							{
								this._MoveBack();
							}
						);
						PressAnyKey();
					}
				}

			}

			if (On(48, 46))
			{
				Select_Init();

				Select_AddTitle("여기에서는 전투모드의 테스트가 가능하다");
				Select_AddItem("준비가 되었다. 전투모드로 가자!");
				Select_AddItem("전투모드가 뭔가요? 먹는 건가요?");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
						case 1:
							OldStyleBattle.Init(new int[,] { { 1, 10 }, { 2, 10 }, { 3, 10 }, { 4, 10 }, { 5, 10 }, { 6, 10 } });
							GameRes.enemy[1].attrib.name = "마제콘";
							OldStyleBattle.Run(true);
							break;
						case 2:
							Talk("무식하고 먹보인 당신을 보며, 옆에 있던 쭌뚱어가 비웃는 소리가 들렸다");
							this._MoveBack();
							break;
						default:
							Talk("쭌뚱어가 비웃을까봐 주위를 보았지만 쭌뚱어는 없었다");
							this._MoveBack();
							break;
						}
					}
				);
			}

			return you_can_move_to_there;
		}

		public override void OnPostEvent(int event_id, out int post_event_id)
		{
			post_event_id = 0;
		}
		public override bool OnEnter(int event_id)
		{
			if (OnArea(48, 92, 52, 92))
			{
				Select_Init();

				Select_AddTitle("여기는 로어성을 나가는 출구이다.");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("일단 나가본다");
				Select_AddItem("밖은 춥다. 그냥 여기에...");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 1:
								GameRes.LoadMapEx("LoreContinent");
								break;
							case 2:
								Talk("밖은 황야가 펼쳐져 있다");
								break;
							default:
								Talk("당신은 별다른 선택을 하지는 않은 채로 그 자리에 서 있었다");
								break;
						}
					}
				);
			}

			if (On(47, 48))
			{
				Select_Init();

				Select_AddTitle("당신 앞에는 허물어져가는 유적의 입구가 있다.");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("조심스럽게 안으로 들어간다");
				Select_AddItem("일단 들어가지는 않겠다");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
						case 1:
							GameRes.LoadMapEx("TOWN2");
							break;
						case 2:
							Talk("주저하는 당신을 보며, 옆에 있던 쭌뚱어가 비웃는 소리가 들렸다");
							break;
						default:
							Talk("당신은 별다른 선택을 하지는 않은 채로 그 자리에 서 있었다");
							break;
						}
					}
				);
			}

			if (On(50, 25))
			{
				Select_Init();

				Select_AddTitle("여기는 어딘가로 이어지는 공간이다");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("조심스럽게 안으로 들어간다");
				Select_AddItem("좀 더 신중하게 생각해 본다");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 1:
								GameRes.LoadMapEx("Map002");
								break;
							case 2:
								Talk("뭔지 모를 불안감에 당신은 주저하고 있다");
								break;
							default:
								Talk("당신은 별다른 선택을 하지는 않은 채로 그 자리에 서 있다");
								break;
						}
					}
				);
			}

			return false;
		}

		public override void OnSign(int event_id)
		{
			if (On(50, 83))
			{
				Talk("여기는 'CASTLE LORE'성");
				Talk("여러분을 환영합니다");
				Talk("");
				Talk("");
				Talk("");
				//TextAlign(ALIGN_RIGHT);
				Talk("Lord Ahn     ");
			}

			if (On(23, 30))
			{
				Talk("");
				Talk("여기는 LORE 주점");
				Talk("여러분 모두를 환영합니다 !!");
			}

			if (On(50, 17) || On(51, 17))
			{
				Talk("");
				Talk("LORE 왕립  죄수 수용소");
			}

			if (On(48, 58))
			{
				Talk("@A미완성 목록@@");
				Talk("");
				Talk("- 상점들이나 훈련장");
				Talk("- 마법/아이템 사용");
				Talk("- 4:3 등의 기기의 출력");
			}

			if (On(52, 58))
			{
				Talk("@A앞으로 바뀔 부분@@");
				Talk("");
				Talk("- 에피소드 시나리오 진행");
				Talk("- 로어성의 기본 대사");
				Talk("- 배경 음악 (라이선스 문제)");
				Talk("- 아이템 관리");
			}

			if (On(52, 27))
			{
				int index = GameRes.GetIndexOfResevedPlayer();

				if (index >= 0 && !GameRes.player[index].IsValid())
				{
					Select_Init();

					Select_AddTitle("여기서는 마지막 동료를 추가할 수 있습니다.");
					Select_AddGuide("당신의 선택은 ---");
					Select_AddItem("새로운 동료가 누군지 궁금하오");
					Select_AddItem("잠깐만 더 생각해 보겠소");

					Select_Run
					(
						delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									GameRes.player[index] = ObjPlayer.CreateCharacter("대천사장", GENDER.UNKNOWN, CLASS.UNKNOWN, 5);
									GameRes.player[index].race = RACE.ANGEL;
									GameRes.player[index].intrinsic_status[(int)STATUS.CON] = 20;
									GameRes.player[index].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 4));
									GameRes.player[index].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(5));

									GameRes.player[index].Apply();

									GameObj.UpdatePlayerStatus();

									Talk("그는 인간인지 신인지 악마인지를 도무지 종잡을 수 없는 무표정한 모습을 한 채로 일행의 가장 뒤에 섰다.");
									break;
								default:
									Talk("(당신은 고민 중이다)");
									break;
							}
						}
					);
				}
				else
				{
					Talk("이미 마지막 멤버가 들어가 있다.");
				}
			}

			if (On(48, 27))
			{
				int index = GameRes.GetIndexOfVacantPlayer();

				if (index >= 0)
				{
					Select_Init();

					Select_AddTitle("여기서는 동료를 추가할 수 있습니다.");
					Select_AddGuide("당신의 선택은 ---");
					Select_AddItem("그러면 한 명을 더 추가하겠소");
					Select_AddItem("동료가 필요한지 다시 생각하겠소");

					Select_Run
					(
						delegate (int selected)
						{
							switch (selected)
							{
								case 1:
									int rand = GameRes.variable[20]++;

									switch (rand % 3)
									{
										case 0:
											GameRes.player[index] = ObjPlayer.CreateCharacter("아트리아", GENDER.FEMALE, CLASS.KNIGHT, rand * 2 + 1);
											GameRes.player[index].hp = GameRes.player[index].GetMaxHP() / 10;
											break;
										case 1:
											GameRes.player[index] = ObjPlayer.CreateCharacter("안카라", GENDER.MALE, CLASS.PALADIN, rand * 2 + 1);
											GameRes.player[index].skill[(uint)SKILL_TYPE.SHIELD] = 50;
											GameRes.player[index].hp = GameRes.player[index].GetMaxHP() / 2;
											break;
										case 2:
											GameRes.player[index] = ObjPlayer.CreateCharacter("수하일", GENDER.FEMALE, CLASS.MAGICIAN, rand * 2 + 1);
											GameRes.player[index].hp = GameRes.player[index].GetMaxHP() / 3;
											break;
									}

									ObjNameBase pronoun_gender = new ObjNameBase();
									pronoun_gender.SetName((GameRes.player[index].gender != GENDER.FEMALE) ? "그" : "그녀");

									GameObj.UpdatePlayerStatus();

									Talk("새로운 동료가 늘어 났다.");
									Talk("");
									Talk(pronoun_gender.GetName(ObjNameBase.JOSA.SUB) + " " + GameRes.player[index].GetName(ObjNameBase.JOSA.QUOTE) + "라고 불러 달라고 한다.");

									break;
								default:
									Talk("(당신은 고민 중이다)");
									break;
							}
						}
					);
				}
				else
				{
					Talk("당신은 더 이상 동료가 늘어나는 것은 원치 않는다.");
				}
			}
		}

		public override void OnTalk(int event_id)
		{
			if (On(45, 8))
			{ 
				GameObj.SetHeaderText(LibUtil.SmTextToRichText("안영기 - 이 게임의 제작자\n<color=#FFBF40FF>진행을 도와 주거나 버그를 감시한다.</color>"), 5);

				if (Not(Flag_IsSet(33)))
				{
					Talk("게임의 진행을 위해 이 안 쪽 감옥의 문을 열어 주겠소.");
					MapEx_ChangeTile(44, 14, 0, 0);
					Flag_Set(33);
				}
				else
				{
					if (Not(Flag_IsSet(34)))
					{
						Talk("내가 열어준 감옥에는 Joe라고 하는 사람이 수감되어 있소.");
					}
					else
					{ 
						Talk("Joe와 동료가 되었군요.");
						Talk("");
						Talk("재미있군요. 왜 그러셨나요?");
					}
				}

			}

			if (On(50, 27))
			{
				if (Less(Variable_Get(10), 3))
				{ 
					Talk("나는 @A로드안@@ 이오.");
					Talk("");
					Talk("이제부터 당신은 이 게임에서 새로운 인물로서 생을 시작하게 될 것이오. 그럼 나의 이야기를 시작하겠소.");

					RegisterKeyPressedAction
					(
						delegate ()
						{
							Talk("아마도 당신은 1993년에 만들어진 이 게임을 기억할 것이오.");
							Talk("");
							Talk("그리고 2018년인 지금, 시대에 맞게 모바일로 시스템 엔진을 재 제작하였고, UI를 적용해 보았소.");

							RegisterKeyPressedAction
							(
								delegate ()
								{
									Talk("그리고 원래의 3부작과는 다른, 새로운 에피소드로 시작하려 하오. 업그레이드 때마다 시나리오가 계속 추가되고 유저들의 의견을 받아 시스템도 최신에 맞게 개선해 나갈 것이오.");
									Talk("");
									Talk("그러니 앞으로도 많은 의견을 부탁드리오.");
									Talk("");
									Talk("@B [경험치 + 20000]@@");

									GameRes.party.PlusExp(20000);

									// Temporary
									Variable_Add(10);
									Variable_Add(10);
									Variable_Add(10);

									RegisterKeyPressedAction(delegate ()
									{
										Talk("@D그리고 이번 버전은 여기까지오. 다음 업데이트를 기대해 주시오@@");
									}); PressAnyKey();
								}
							);
							PressAnyKey();
						}
					);
					PressAnyKey();
				}
				else
				{
					Talk("구시대적인 인터페이스는 나 역시도 유감이오. 예전의 느낌을 살려야 하는지, 아니면 새로운 감각으로 만들어야 하는지는 나에게 주어진 큰 숙제이오.");
					Talk("");
					Talk("일단은 원작의 인터페이스를 그대로 재현한 것이 현 상태라오. 조금은 불편하겠지만 당장은 좀 참아 주시구려.");
				}
			}

			if (On(8, 63))
				Talk("당신이 모험을 시작한다면, 많은 괴물들을 만날 것이오. 무엇보다도, Serpent와 Insects와 Python은 맹독이 있으니 주의 하시기 바라오.");

			if (On(71, 72))
				Talk("Orc는 가장 하급 괴물이오.");

			if (On(50, 71))
			{
				if (Not(Flag_IsSet(51)))
				{
					MapEx_ChangeObj1(50, 71, 136, false);

					Talk("당신이 Necromancer에 진정으로 대항하고자한다면, 이 성의 바로위에 있는 피라밋에 가보도록하시오. 그곳은 Necromancer와 동시에 바다에서 떠오른 '@B또다른 지식의 성전@@'이기 때문이오. 당신이 어느 수준이 되어 그 곳에 들어간다면 진정한 이 세계의 진실을 알수 있을것이오.");

					Flag_Set(51);

					RegisterPostAction(delegate () { MapEx_ChangeObj1(50, 71, 133, false); });
				}
				else
				{
					Talk("'MENACE'' 속에는 Dwarf, Giant, Wolf, Python같은 괴물들이 살고 있소.");
				}
			}

			if (On(57, 73))
				Talk("나의 부모님은 Python 의 독에 의해 돌아 가셨습니다. Python은 정말 위험한 존재입니다.");
			if (On(62, 26))
				Talk("단지 Lord Ahn 만이 능력 상으로 Necromancer 에게 도전할 수 있습니다. 하지만 Lord Ahn 자신이 대립을 싫어해서, 현재는 Necromancer 에게 대항할 자가 없습니다.");
			if (On(89, 81))
				Talk("우리는 Ancient Evil을 배척하고 Lord Ahn님을 받들어야 합니다.");
			if (On(93, 67))
				Talk("우리는 MENACE의 동쪽에 있는 나무로부터 많은 식량을 얻은적이 있습니다.");
			if (On(18, 52))
				Talk("이 세계의 창시자는 안영기님 이시며, 그는 위대한 프로그래머 입니다.");

			if (On(12, 26) || On(17, 26))
			{
				Talk("어서 오십시오. 여기는 LORE 주점입니다.");
				if (Equal(Random(2), 0))
					Talk("거기 " + Player_GetGenderName(0) + "분 어서 오십시오.");
				else
					Talk("위스키에서 칵테일까지 마음껏 선택하십시오.");
			}

			if (On(20, 32))
				Talk("...");
			if (On(9, 29))
				Talk("요새 무덤쪽에서 유령이 떠돈다던데...");
			if (On(12, 31))
				Talk("하하하, 자네도 한번 마셔보게나.");
			if (On(14, 34))
				Talk("이제 Lord Ahn의 시대도 끝나가는가 ? 그까짓 Necromancer라는 작자에게 쩔쩔 매는 꼴이라니... 차라리 내가 나가서 그 놈과 싸우는게 났겠다.");
			if (On(17, 32))
				Talk("당신은 Skeleton족의 한 명이 우리와 함께 생활하려 한다는 것에 대해서 어떻게 생각하십니까? 저는 그 말을 들었을때 너무 혐오스러웠습니다. 어서 빨리 그 살아있는 뼈다귀를 여기서 쫓아냈으면 좋겠습니다.");

			if (On(20, 35))
				Talk("... 끄~~윽 ... ...");
			if (On(17, 37))
				Talk("이보게 자네, 내말 좀 들어 보게나. 나의 친구들은 이제 이 세상에 없다네. 그들은 너무나도 용감하고 믿음직스런 친구들이었는데... 내가 다리를 다쳐 병원에 있을 동안 그들은 모두 이 대륙의 평화를 위해 LORE 특공대에 지원 했다네. 하지만 그들은 아무도 다시는 돌아오지 못했어. 그런 그들에게 이렇게 살아있는 나로서는 미안할 뿐이네. 그래서 술로 나날을 보내고 있지. 죄책감을 잊기위해서 말이지...");

			if (On(71, 77))
				Talk("물러나십시오. 여기는 용사의 유골들을 안치해 놓은 곳입니다.");

			if (On(62, 75))
			{
				if (Not(Flag_IsSet(50)))
				{
					Talk("당신이 한 유골 앞에 섰을때 이상한 느낌과 함께 먼 곳으로 부터 어떤 소리가 들려왔다.");
					RegisterKeyPressedAction
					(
						delegate ()
						{
							Talk("안녕하시오. 대담한 용사여.");
							Talk("");
							Talk("당신이 나의 잠을 깨웠소 ? 나는 고대에 이 곳을 지키다가 죽어간 기사 Jr. Antares 라고하오. 저의 아버지는 Red Antares라고 불리웠던 최강의 마법사였소.");

							RegisterKeyPressedAction
							(
								delegate ()
								{
									Talk("그는 말년에 어떤 동굴로 은신을 한 후 아무에게도 모습을 나타내지 않았소. 하지만 당신의 운명은 나의 아버지를 만나야만하는 운명이라는 것을 알 수 있소. 반드시 나의 아버지를 만나서 당신이 알지 못했던 새로운 능력들을 배우시오. 그리고 나의 아버지를 당신의 동행으로 참가시키도록 하시오. 물론 좀 어렵겠지만 ...");

									RegisterKeyPressedAction
									(
										delegate ()
										{
											Talk("아참, 그리고 내가 죽기 전에 여기에 뭔가를 여기에 숨겨 두었는데 당신에게 도움이 될지 모르겠소. 그럼, 나는 다시 오랜 잠으로 들어가야 겠소.");

											MapEx_ChangeTile(61, 78, 10);
											MapEx_ChangeTile(61, 79, 10);
											MapEx_ChangeTile(61, 80, 10);
											MapEx_ChangeTile(61, 81, 10);
											MapEx_ChangeTile(61, 82, 10, 7);

											GameRes.map_data.data[61, 81].act_type = ACT_TYPE.EVENT;

											Flag_Set(50);
										}
									);
									PressAnyKey();
								}
							);
							PressAnyKey();
						}
					);
					PressAnyKey();
				}
			}

			if (On(23, 49))
				Talk("힘내게, " + Player_GetName(0) + " 자네라면 충분히 Necromancer를 무찌를수 있을 걸세. 자네만 믿겠네.");
			if (On(23, 53))
				Talk("위의 저 친구로부터 당신 얘기 많이 들었습니다. 저는 우리성에서 당신같은 용감한 사람이 있다는걸 자랑스럽게 생각합니다.");
			if (On(12, 54))
				Talk("만약, 당신들이 그 일을 해내기가 어렵다고 생각되시면 LASTDITCH 성에서 성문을 지키고 있는 Polaris란 청년을 일행에 참가시켜 주십시오. 분명 그 사람이라면 쾌히 승락할 겁니다.");
			if (On(49, 10))
				Talk("이 안에 갇혀있는 사람들에게는 일체 면회가허용되지 않습니다. 나가 주십시오.");

			if (On(52, 10))
			{
				Talk("여기는 Lord Ahn의 체제에 대해서 깊은 반감을 가지고 있는 자들을 수용하고 있습니다.");
				Talk("아마 그들은 죽기전에는 이곳을 나올수 없을 겁니다.");
			}

			if (On(40, 9))
			{
				Talk("나는 이곳의 기사로서 이 세계의 모든 대륙을 탐험하고 돌아왔었습니다. 내가 마지막 대륙을 돌았을때 나는 새로운 존재를 발견했습니다. 그는 바로 예전까지도 Lord Ahn과 대립하던 Ancient Evil이라는 존재였습니다. 지금 우리의 성에서는 철저하게 배격하도록 어릴 때부터 가르침 받아온 그 Ancient Evil이었습니다. 하지만 그곳에서 본 그는 우리가 알고있는 그와는 전혀 다른 인간미를 가진 말 그대로 신과같은 존재였습니다. 내가 그의 신앙 아래 있는 어느 도시를 돌면서 내가 느낀 것은 정말 Lord Ahn에게서는 찾아볼수가 없는 그런 자애와 따뜻한 정이었습니다. 그리고 여태껏 내가 알고 있는 그에 대한 지식이 정말 잘 못되었다는 것과 이런 사실을 다른 사람에게도 알려주고 싶다는 이유로 그의 사상을 퍼뜨리다 이렇게 잡히게 된것입니다.");

				RegisterKeyPressedAction
				(
					delegate ()
					{
						Talk("하지만 더욱 이상한것은 Lord Ahn 자신도 그에 대한 사실을 인정하면서도 왜 우리에게는 그를 배격하도록만 교육시키는 가를 알고 싶을뿐입니다. Lord Ahn께서는 나를 이해한다고 하셨지만 사회 혼란을 방지하기 위해 나를 이렇게 밖에 할수 없다고 말씀하시더군요. 그리고 이것은 선을 대표하는 자기로서는 이 방법 밖에는 없다고 하시더군요.");
						Talk("");
						Talk("하지만 Lord Ahn의 마음은 사실 이렇지 않다는 걸 알수 있었습니다. Ancient Evil의 말로는 사실 서로가 매우 절친한 관계임을 알수가 있었기 때문입니다.");
					}
				);
				PressAnyKey();
			}

			if (On(39, 14))
			{
				Select_Init();

				Select_AddTitle("히히히.. 위대한 용사님. 낄낄낄.. 내가 당신들의 일행에 끼이면 안될까요 ? 우히히히");
				Select_AddGuide("당신의 선택은 ---");
				Select_AddItem("그렇다면 당신을 받아들이지요");
				Select_AddItem("당신은 이곳에 그냥 있는게 낫겠소");

				Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
						case 1:
							int index = GameRes.GetIndexOfVacantPlayer();

							if (index >= 0)
							{
								Talk("당신은 그와 동료가 되기로 하였다.");
								Talk("");
								Talk("그에게 이름을 물어보니, 그는 Joe라 한다고 하였다.");

								GameRes.player[index].Name = "미친조";
								GameRes.player[index].gender = Yunjr.GENDER.MALE;

								GameObj.UpdatePlayerStatus();

								GameRes.map_data.data[39, 14].ix_obj0 = 0;
								GameRes.map_data.data[39, 14].ix_obj1 = 0;
								GameRes.map_data.data[39, 14].act_type = ACT_TYPE.DEFAULT;

								Flag_Set(34);
							}
							else
							{
								Talk("그를 동료로 맞이하고 싶었으나 우리에게는 이미 많은 동료가 있다.");
							}

							break;
						case 2:
							Talk("당신은 그의 제안을 거절했다.");
							break;
						default:
							Talk("당신은 그의 질문에 아무런 대답도 하지 않았다.");
							break;
						}
					}
				);
				//temp.assign(Select::Result());
				/*
				if (Equal(temp, 1))
				{
					Player::AssignFromEnemyData(6,1)
					Player::ChangeAttribute(6, "name", "Mad Joe")
					Player::ChangeAttribute(6, "class", 8)
					Player::ChangeAttribute(6, "weapon", 0)
					Player::ChangeAttribute(6, "shield", 0)
					Player::ChangeAttribute(6, "armor", 0)
					Player::ChangeAttribute(6, "pow_of_weapon", 0)
					Player::ChangeAttribute(6, "pow_of_shield", 0)
					Player::ChangeAttribute(6, "pow_of_armor", 0)
					Player::ChangeAttribute(6, "ac", 0)
					Map::ChangeTile(39, 14, 47)
					DisplayMap()
					DisplayStatus()
					Flag::Set(52)
					flag_press.assign(0)
				}
				else
				{
					Talk("당신이 바란다면...")
				}
				*/
			}

			if (On(62, 9))
			{
				Talk("안녕하시오. 나는 한때 이 곳의 유명한 도둑이었던 사람이오. 결국 그 때문에 나는 잡혀서 평생 여기에 있게 되었지만...");
				Talk("그건 그렇고, 내가 LORE 성의 보물인 '@B황금의 방패@@'를 훔쳐 달아나다. 그만 그것을 MENACE라는 금광에 숨겨 놓은채 잡혀 버리고 말았소.");
				Talk("나는 이제 그것을 가져봤자 쓸때도 없으니 차라리 당신이 그걸 가지시오. 가만있자... 어디였더라... 그래 ! MENACE의 가운데쯤에 벽으로 사방이 둘러 싸여진 곳이었는데.. 당신들이라면 지금 여기에 들어온것과 같은 방법으로 들어가서 방패를 찾을수 있을것이오. 행운을 빌겠소.");
			}

			if (On(59, 14))
				Talk("당신들에게 경고해 두겠는데 건너편 방에 있는 Joe는 오랜 수감생활 끝에 미쳐 버리고 말았소. 그의 말에 속아서 당신네 일행에 참가시키는 그런 실수는 하지마시오.");

			if (On(41, 77) || On(41, 79))
			{
				if (Not(Flag_IsSet(36)))
				{
					Talk("Lord Ahn 님의 명령에 의해서 당신들에게 한가지의 무기를 드리겠습니다. 들어가셔서 무기를 선택해 주십시오.");
					Flag_Set(35);
				}
				else
				{ 
					Talk("여기서 가져가신 무기를 잘 사용하셔서 세계의 적인 Necromancer를 무찔러 주십시오.");
				}
			}

			if (On(50, 13))
				Talk("MENACE 에는 금덩이가 많다던데...");
			if (On(82, 26))
				Talk("MENACE 는 한때 금광이었습니다.");

			if (On(86, 72) || On(90, 64))
				new Npc.Grocery(this, 10.0f);

			if (On(7, 70) || On(13, 68) || On(13, 72))
				new Npc.WeaponShop(this);

			if (On(86, 13) || On(85, 11))
				new Npc.Hospital(this);

			if (On(20, 11))
				new Npc.TrainingCenterJob(this);

			if (On(24, 12))
				new Npc.TrainingCenterSkill(this);

			if (On(49, 50) || On(51, 50))
			{
				if (Flag_IsSet(31))
				{
					Talk("행운을 빌겠소 !!!");
				}
				else
				{
					if (Less(Variable_Get(10), 3))
					{
						Talk("저희 성주님을 만나 보십시오.");
					}
					else
					{
						/*					
							Select::Init();
							Select::Add("당신은 이 게임 세계에 도전하고 싶습니까?");
							Select::Add("예");
							Select::Add("아니오");
							Select::Run();
							temp.assign(Select::Result());

							if (Equal(temp, 1))
						*/
						{
							Talk("이제부터 당신은 진정한 이 세계에 발을 디디게 되는 것입니다.");

							MapEx_ChangeTile(48, 51, 0);
							MapEx_ChangeTile(49, 51, 8);
							MapEx_ChangeTile(50, 51, 8);
							MapEx_ChangeTile(51, 51, 8);
							MapEx_ChangeTile(52, 51, 0);
							MapEx_ChangeTile(48, 52, 0);
							MapEx_ChangeTile(49, 52, 8);
							MapEx_ChangeTile(50, 52, 8);
							MapEx_ChangeTile(51, 52, 8);
							MapEx_ChangeTile(52, 52, 0);

							Flag_Set(31);
							//DisplayMap();
						}
						/*
						else
						{
							Talk("다시 생각 해보십시오.");
						}
						*/
					}
				}
			}

			if (On(50, 86))
			{
				if (Not(Flag_IsSet(32)))
				{
					Talk("난 당신을 믿소, " + Player_GetName(0));

					MapEx_ChangeTile(48, 87, 8);
					MapEx_ChangeTile(49, 87, 8);
					MapEx_ChangeTile(50, 87, 8);
					MapEx_ChangeTile(51, 87, 8);
					MapEx_ChangeTile(52, 87, 8);

					Flag_Set(32);
					//DisplayMap();
				}
				else
				{
					Talk("힘내시오, " + Player_GetName(0));
				}
			}

			if (OnArea(47, 30, 53, 36))
			{
				if (Less(Variable_Get(10), 1))
					Talk("저희 성주님을 만나십시오.");
				else
					Talk("당신이 성공하기를 빕니다.");
			}

			/*
			if (On(50,27))
				if (Less(Variable::Get(10), 4))
					if (Equal(Variable::Get(10), 0))
						Talk("나는 '@BLord Ahn@@' 이오.")
						Talk("")
						Talk("이제부터 당신은 이 게임에서 새로운 인물로서 생을 시작하게 될것이오. 그럼 나의 이야기를 시작하겠소.")
						Variable::Add(10)
					else
						if (Equal(Variable::Get(10), 1))
							Talk("이 세계는 내가 통치하는 동안에는 무척 평화로운 세상이 진행되어 왔었소.  그러나 그것은 한 운명의 장난으로 무참히 깨어져 버렸소.")
							Talk("")
							Talk("한날, 대기의 공간이 진동하며 난데없는 푸른 번개가 대륙들 중의 하나를 강타했소.  공간은 휘어지고 시간은 진동하며  이 세계를 공포 속으로 몰고 갔소.  그 번개의 위력으로 그 불운한 대륙은  황폐화된 용암 대지로 변하고 말았고, 다른 하나의 대륙은 충돌시의 진동에 의해 바다 깊이 가라앉아 버렸소.")
							Talk("")
							Talk("그런 일이 있은 한참 후에,  이상하게도 용암 대지의 대륙으로부터 강한 생명의 기운이 발산되기 시작 했소.  그래서, 우리들은 그 원인을 알아보기 위해 'LORE 특공대'를 조직하기로 합의를 하고 이곳에 있는 거의 모든 용사들을 모아서 용암 대지로 변한 그 대륙으로 급히 그들을 파견하였지만 여태껏 아무 소식도 듣지못했소. 그들이 생존해 있는지 조차도 말이오.")
							Talk("")
							PressAnyKey();
							Talk("이런 저런 방법을 통하여 그들의 생사를 알아려던 중 우연히 우리들은 '@ANecromancer@@'라고 불리우는  용암 대지속의  새로운 세력의 존재를 알아내었고,  그때의 그들은 이미 막강한 세력으로 성장해가고 있는중 이었소.  그때의 번개는 그가 이 공간으로 이동하는 수단이었소. 즉 그는 이 공간의 인물이 아닌 다른 차원을 가진 공간에서 왔던 것이오.")
							Talk("")
							Talk("그는 현재 이 세계의 반을  그의 세력권 안에 넣고 있소. 여기서 당신의 궁극적인 임무는 바로 'Necromancer 의 야심을 봉쇄 시키는 것'이라는 걸 명심해 두시오.")
							Talk("")
							Variable::Add(10)
						else
							if (Equal(Variable::Get(10), 2))
								Talk("Necromancer 의 영향력은 이미 LORE 대륙까지 도달해있소.  또한 그들은 이 대륙의 남서쪽에 '@BMENACE@@' 라고 불리우는 지하 동굴을 얼마전에구축했소.  그래서, 그 동굴의 존재 때문에 우리들은 그에게 위협을 당하게 되었던 것이오.")
								Talk("")
								Talk("하지만, LORE 특공대가 이 대륙을 떠난후로는 그 일당들에게 대적할 용사는  이미  남아있지 않았소. 그래서 부탁하건데, 그 동굴을 중심부까지 탐사해 주시오.")
								Talk("")
								Talk("나는 당신들에게 Necromancer에 대한 일을 맡기고 싶지만, 아직은 당신들의  확실한 능력을 모르는 상태이지요.  그래서 이 일은 당신들의 잠재력을 증명해 주는 좋은 기회가 될것이오.")
								Talk("")
								PressAnyKey();
								Talk("만약 당신들이 무기가 필요하다면 무기고에서 약간의 무기를 가져가도록 허락하겠소.")
								Talk("")
								Variable::Add(10)
							else
								if (Equal(Variable::Get(10), 3))
									Talk("대륙의 남서쪽에 있는 '@BMENACE@@'를 탐사해 주시오.")
				else
					Talk("## 이 부분은 MENACE 탐사가 끝나면 발생함")

			 */
		}

	}
}

/*
나를 만나려고 기다렸다는 사람이 당신이오?
이미 알고 있겠지만 나는 로어성의 성주인 로드안이라고 하오.

당신은 여기서 처음 보는 것 같은데 소개를 부탁하오.

Q-1> 저는 머큐리라고 합니다.
Q-2> 저는 헤르메스라고 합니다.
Q-3> 내가 진짜 로드안이오!
 

A-1> 음, '머큐리'라...
부드럽게 강하면서도 재빠르다는 의미의 이름이지요?

그리고 이 대륙에서 가장 유명한 도둑의 이름이기도 하오.
그런 당신이 무엇 때문에 나를 직접 찾아 온 것이오?


Q-1-1> 저를 받아 주신다면, 로드안님의 밑에서 저의 능력을 최대한 발휘하고 싶습니다.
Q-1-2> 당신의 소중한 물건을 훔치러 왔소.
Q-1-3> 당신에게 진 빚이 있습니다.


A-2> 헤르메스... 낯 익은 듯하면서도 낯 선 이름이구려. 만약 우리가 구면인데 내가 알아 보지 못한 것이라면 저의 결례를 이해해 주시오.

그래, 그대 에르메스는 어떤 일로 나를 찾아 온 것이오?

Q-2-1> 
Q-2-2> 
Q-2-3> 



*/
