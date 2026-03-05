
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	namespace Npc
	{
		class Common
		{
			public static int CheckQuantity(int current, int quantity, int max)
			{
				int sum = current + quantity;

				if (sum <= max)
					return quantity;
				else
					return max - current;
			}

			public static bool ApplyRequiredGold(YunjrMap associated_map, ObjParty party, int required_gold)
			{
				if (party.gold >= required_gold)
				{
					party.gold -= required_gold;
					return true;
				}
				else
				{
					associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_GOLD));
					return false;
				}
			}
		}

		class WeaponShop
		{
			private YunjrMap _associated_map;

			public WeaponShop(YunjrMap map)
			{
				_associated_map = map;

				_associated_map.Talk("@F여기는 무기상점입니다.@@");
				_associated_map.Talk("@F우리들은 무기, 방패, 갑옷을 팔고있습니다.@@");

				_associated_map.RegisterKeyPressedAction(_WeaponShopSub1);

				_associated_map.PressAnyKey();
			}

			private bool _CheckBackpackSpace(ObjParty party, int required_space)
			{
				return (party.GetNumItemsInBackpack() + required_space <= party.core.current_capacity_of_backpack);
			}

			private bool _RefundProductJustBought(ObjParty party, int refunded_gold)
			{
				party.gold += refunded_gold;
				return true;
			}

			private void _WeaponShopSub1()
			{
				_associated_map.Select_Init
				(
					"@F어떤 종류를 원하십니까 ?@@",
					"",
					new string[]
					{
						"베는 무기류",
						"찍는 무기류",
						"찌르는 무기류",
						"타격 무기류",
						"쏘는 무기류",
						"방패류",
						"갑옷류"
					}
				);

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						switch (selected)
						{
							case 1:
								_WeaponShopSub2(ITEM_TYPE.WIELD);
								break;
							case 2:
								_WeaponShopSub2(ITEM_TYPE.CHOP);
								break;
							case 3:
								_WeaponShopSub2(ITEM_TYPE.STAB);
								break;
							case 4:
								_WeaponShopSub2(ITEM_TYPE.HIT);
								break;
							case 5:
								_WeaponShopSub2(ITEM_TYPE.SHOOT);
								break;
						}
					}
				);
			}

			private static readonly uint[][][] PRICE = new uint[5][][]
			{
				new uint[2][] // ITEM_TYPE.WIELD
				{
					new uint[] {   1,    2,    3,    4,     5,     6,     7 },
					new uint[] { 500, 3000, 5000, 7000, 12000, 40000, 70000 }
				},
				new uint[2][] // ITEM_TYPE.CHOP
				{
					new uint[] {   1,    2,    3,     4,     5,     6,      7 },
					new uint[] { 500, 3000, 5000, 10000, 30000, 60000, 100000 }
				},
				new uint[2][] // ITEM_TYPE.STAB
				{
					new uint[] {   1,    2,    3,    4,    5,     6,     7 },
					new uint[] { 100, 1000, 1500, 4000, 8000, 35000, 50000 }
				},
				new uint[2][] // ITEM_TYPE.HIT, SHOOT
				{
					new uint[] {   1,    2,    3 },
					new uint[] { 100, 1000, 2500 }
				},
				new uint[2][] // ITEM_TYPESHOOT
				{
					new uint[] {   1,   2,   3,    4,    5,     6,     7 },
					new uint[] { 200, 300, 800, 2000, 5000, 10000, 30000 }
				},
			};

			private void _WeaponShopSub2(ITEM_TYPE item_type)
			{
				if (item_type < ITEM_TYPE.WEAPON_MIN || item_type >= ITEM_TYPE.WEAPON_MAX)
					return;

				int ix_type = item_type - ITEM_TYPE.WEAPON_MIN;

				_associated_map.Select_Init
				(
					"@F어떤 무기를 원하십니까?@@",
					"",
					null
				);

				Debug.Assert(PRICE[ix_type][0].Length == PRICE[ix_type][1].Length);

				int max_len_of_item_name = 0;
				List<string> item_name_list = new List<string>();

				foreach (var index in PRICE[ix_type][0])
				{
					ResId res_id = ResId.CreateResId_Weapon((uint)item_type, index);

					string s = GameRes.item_table[res_id.GetId()].name;
					item_name_list.Add(s);

					max_len_of_item_name = Math.Max(max_len_of_item_name, LibUtil.SmTextExtent(s));
				}

				Debug.Assert(PRICE[ix_type][0].Length == item_name_list.Count);

				for (int i = 0; i < PRICE[ix_type][0].Length; i++)
				{
					string s = item_name_list[i];
					LibUtil.SmTextAddSpace(ref s, max_len_of_item_name + 2);
					_associated_map.Select_AddItem(s + ": 금 " + PRICE[ix_type][1][i] + "개");
				}

				_associated_map.Select_Run
				(
					delegate (int selected)
					{
						if (selected == 0)
						{
							_WeaponShopSub1();
							return;
						}

						uint weapon_id = PRICE[ix_type][0][selected - 1];
						int price = (int)PRICE[ix_type][1][selected - 1];

						if (!Common.ApplyRequiredGold(_associated_map, GameRes.party, price))
							return;

						if (!_CheckBackpackSpace(GameRes.party, 1))
						{
							_RefundProductJustBought(GameRes.party, price);
							_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.BACKPACK_IS_FULL));
							return;
						}

						_associated_map.Talk("당신은 물건을 받아서 백팩에 넣었다.");

						Equiped equipment = Equiped.Create(ResId.CreateResId_Weapon((uint)item_type, weapon_id));

						bool success = GameRes.party.PutInBackpack(equipment);
						
						Debug.Assert(success);
					}
				);
			}

		}

		class ItemShop
		{
			public enum ITEM
			{
				GOODS = 0,
				MEDICINE,
				MAX
			};

			private YunjrMap _associated_map;
			private ITEM _item;

			public ItemShop(YunjrMap map, ITEM item)
			{
				_associated_map = map;
				_item = item;

				switch (_item)
				{
					case ITEM.GOODS:
						_associated_map.Talk("@F여기는 여러가지 물품을 파는 곳입니다.@@");
						break;
					case ITEM.MEDICINE:
						_associated_map.Talk("@F여기는 약초를 파는 곳입니다.@@");
						break;
					default:
						return;
				}

				_associated_map.RegisterKeyPressedAction(_ItemShopSub);
				_associated_map.PressAnyKey();
			}

			private void _ItemShopSub()
			{
				string greeting = "";

				switch (_item)
				{
					case ITEM.GOODS:
						greeting = "@F당신이 사고 싶은 물건을 고르십시오.@@";
						break;
					case ITEM.MEDICINE:
						greeting = "@F사고 싶은 약이나 약초를 고르십시오.@@";
						break;
					default:
						return;
				}

				_associated_map.Select_Init
				(
					greeting,
					"",
					null
				);

				var _NAME_PRICE = _NAME_PRICE_TABLE[(int)_item];

				foreach (var name_price in _NAME_PRICE)
					_associated_map.Select_AddItem(String.Format("{0}: 금 {1,4} 개", name_price.name, name_price.price));

				_associated_map.Select_Run
				(
					delegate (int selected_item)
					{
						if (--selected_item < 0)
						{
							_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.AS_YOU_WISH));
							return;
						}

						int price = _NAME_PRICE[selected_item].price;

						_associated_map.Select_Init
						(
							"@F개수를 지정 하십시오.@@",
							"",
							null
						);

						foreach (var num in _NUM_SEQUENCE)
							_associated_map.Select_AddItem(String.Format("{0,2} 개: 금 {1} 개", num, num * price));

						_associated_map.Select_Run
						(
							delegate (int selected)
							{
								if (--selected < 0)
									return;

								int quantity = _NUM_SEQUENCE[selected];
								int num_this_item = -1;

								// switch 분류를 위해서만 딱 한 번 사용되는 변수
								int ix_selected_item = selected_item + (int)_item * 10;
								int ix_item = 0;

								switch (ix_selected_item)
								{
									case 0:
										quantity = Common.CheckQuantity(GameRes.party.core.arrow, quantity, _NAME_PRICE[selected_item].max);
										GameRes.party.core.arrow += quantity;
										num_this_item = GameRes.party.core.arrow;
										break;
									case 1: ix_item = (int)PARTY_ITEM.SCROLL_SUMMON;
										goto common;
									case 2: ix_item = (int)PARTY_ITEM.BIG_TORCH;
										goto common;
									case 3: ix_item = (int)PARTY_ITEM.CRYSTAL_BALL;
										goto common;
									case 4: ix_item = (int)PARTY_ITEM.WINGED_BOOTS;
										goto common;
									case 5: ix_item = (int)PARTY_ITEM.TELEPORT_BALL;
										goto common;

									case 10: ix_item = (int)PARTY_ITEM.POTION_HEAL;
										goto common;
									case 11: ix_item = (int)PARTY_ITEM.POTION_MANA;
										goto common;
									case 12: ix_item = (int)PARTY_ITEM.HERB_DETOX;
										goto common;
									case 13: ix_item = (int)PARTY_ITEM.HERB_JOLT;
										goto common;
									case 14: ix_item = (int)PARTY_ITEM.HERB_RESURRECTION;
										goto common;

									// virtual
									common:
										quantity = Common.CheckQuantity(GameRes.party.core.item[ix_item], quantity, _NAME_PRICE[selected_item].max);
										GameRes.party.core.item[ix_item] += (short)quantity;
										num_this_item = GameRes.party.core.item[ix_item];
										break;
								}

								if (quantity > 0)
								{
									if (Common.ApplyRequiredGold(_associated_map, GameRes.party, price * quantity))
									{
										if (num_this_item > 0)
										{
											ObjNameBase item_name = new ObjNameBase();
											item_name.SetName(_NAME_PRICE[selected_item].name.TrimEnd(' '));

											GameObj.SetHeaderText(String.Format("{0} {1}개가 되었습니다.", item_name.GetName(ObjNameBase.JOSA.SUB), num_this_item));
										}
									}
								}
								else
								{
									_associated_map.Talk(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.BACKPACK_IS_FULL));
								}
							}
						);
					}
				);
			}

			struct NamePrice
			{
				public string name;
				public int price;
				public int max;
			};

			NamePrice a = new NamePrice() { name = "화살     ", price = 500, max = 32767 };

			private static readonly NamePrice[][] _NAME_PRICE_TABLE = new NamePrice[(int)ITEM.MAX][]
			{
				new NamePrice[]
				{
					new NamePrice() { name = "화살     ", price =  500, max = 32767 },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.SCROLL_SUMMON), price = 4000, max = 255 },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.BIG_TORCH), price =  300, max = 255 },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.CRYSTAL_BALL), price =  500, max = 255 },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.WINGED_BOOTS), price = 1000, max = 255 },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.TELEPORT_BALL), price = 5000, max = 255 }
				},
				new NamePrice[]
				{
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.POTION_HEAL), price = 2000, max = 255  },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.POTION_MANA), price = 3000, max = 255  },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.HERB_DETOX), price = 1000, max = 255  },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.HERB_JOLT), price = 5000, max = 255  },
					new NamePrice() { name = GameStrRes.GetItemName((int)PARTY_ITEM.HERB_RESURRECTION), price = 10000, max = 255 }
				}
			};

			private static readonly int[] _NUM_SEQUENCE = new int[6]
			{
				1, 3, 5, 10, 20, 50
			};

		}
	}
}

