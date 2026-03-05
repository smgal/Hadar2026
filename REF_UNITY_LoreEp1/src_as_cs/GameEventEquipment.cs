
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public class GameEventEquipment : MonoBehaviour
	{
		private const string _STR_NA = "(없음)";

		private int _ix_player = -1;
		private int _ix_equipment = -1;
		private Text _current_equipment_text = null;
		private List<Equiped> _currrent_listed = new List<Equiped>();

		private Color32 _BUTTON_TEXT_COLOR_ENABLED = new Color32(0xFF, 0xFF, 0xFF, 0xFF);
		private Color32 _BUTTON_TEXT_COLOR_DISABLED = new Color32(0xFF, 0xFF, 0xFF, 0x40);

		public Text gui_text_guide;
		public Image gui_icon_current_equipment;
		public Text gui_text_current_equipment;
		public Button gui_button_remove;
		public Button gui_button_equip;
		public List<Sprite> icon_sprites;

		void Start()
		{
			Debug.Log("EVENT(Equipment)->Start()");

			GameObj.player_focus[0].SetActive(false);
			GameObj.player_focus[1].SetActive(true);
		}

		public void Reset(int ix_player = -1)
		{
			this._ix_player = -1;
			this._ix_equipment = -1;

			_current_equipment_text = GameObject.Find("EquipmentInfo").GetComponentInChildren<Text>();

			OnPlayerClick((ix_player >= 0) ? ix_player : 0);
			OnEquipmentTabClick(0);

			GameObject go = GameObject.Find("EquipmentTabs");
			UIWidgets.Tabs tabs = go.GetComponent<UIWidgets.Tabs>();
			tabs.Start();
		}

		public void OnPlayerClick(int ix_player)
		{
			Debug.Log("OnPlayerClick() <- " + ix_player);
			Debug.Assert(ix_player >= 0 && ix_player < GameRes.player.Length);

			if (ix_player >= 0 && ix_player < GameRes.player.Length)
			{
				if (GameRes.player[ix_player].IsValid())
				{
					if (this._ix_player != ix_player)
					{
						this._ix_player = ix_player;
						this._SetFocusPlayer(ix_player);
					}

					UpdateScreen();

					// 소환 멤버는 장비를 바꿀 수 없다.
					gui_button_remove.gameObject.SetActive(ix_player < GameRes.player.Length - 1);
					gui_button_equip.gameObject.SetActive(ix_player < GameRes.player.Length - 1);
				}
			}
		}

		public void OnEquipmentTabClick(int ix_equipment)
		{
			Debug.Assert(ix_equipment >= 0 && ix_equipment < (int)EQUIP.MAX);

			// EQUIP: HAND, HAND_SUB, ARMOR, HEAD, LEG, ETC
			if (ix_equipment >= 0 && ix_equipment < (int)EQUIP.MAX)
			{
				if (this._ix_equipment != ix_equipment)
				{
					this._ix_equipment = ix_equipment;
					UpdateScreen();
				}
			}
		}

		public void OnCurrentEquipmentSelect()
		{
			Equiped equiped = GameRes.player[_ix_player].equip[_ix_equipment];

			string equipment_name = String.Format("@8{0}@@", _STR_NA);

			if (equiped != null && equiped.IsValid())
				equipment_name = equiped.name.GetName();

			this._DisplayGuideText(equiped);
		}

		public void OnEquipmentSelect(int index, UIWidgets.ListViewItem item)
		{
			Debug.Assert(index < _currrent_listed.Count);

			Equiped equiped = _currrent_listed[index];
			_DisplayGuideText(equiped);
		}

		public void OnCurrentEquipmentRemove()
		{
			if (this._ix_player < 0 || this._ix_equipment < 0)
				return;

			Equiped equiped = GameRes.player[this._ix_player].equip[this._ix_equipment];

			if (equiped == null || !equiped.IsValid())
				return;

			if (equiped.item.res_id.GetItemType() == ResId.ITEM_TYPE_TAG_WEAPON && equiped.item.res_id.GetItemIndex() == 0)
				return;

			// Remove current equipment and put it in the backpack
			if (this._ix_equipment == (int)EQUIP.HAND)
				GameRes.player[this._ix_player].equip[this._ix_equipment] = Equiped.Create(ResId.CreateResId_Weapon(0, 0));
			else
				GameRes.player[this._ix_player].equip[this._ix_equipment] = new Equiped();

			GameRes.party.PutInBackpack(equiped);

			this.UpdateScreen();
		}

		public void OnEquipmentEquip()
		{
			GameObject go = GameObject.FindWithTag("BackpackListView");
			if (go != null)
			{
				UIWidgets.ListViewIcons list_view_icons = go.GetComponentInChildren<UIWidgets.ListViewIcons>();
				if (list_view_icons.SelectedIndex >= 0)
				{
					Debug.Assert(list_view_icons.SelectedIndex < _currrent_listed.Count);

					Equiped equiped = _currrent_listed[list_view_icons.SelectedIndex];
					Equiped unequiped = null;

					switch (this._ix_equipment)
					{
						case 0:
							unequiped = GameRes.player[this._ix_player].equip[(uint)Yunjr.EQUIP.HAND];
							// 맨손인 경우
							if (unequiped.item.res_id.GetItemType() == ResId.ITEM_TYPE_TAG_WEAPON && unequiped.item.res_id.GetItemIndex() == 0)
								unequiped = null;

							GameRes.player[this._ix_player].SetEquipment(EQUIP.HAND, equiped);
							break;
						case 1:
							unequiped = GameRes.player[this._ix_player].equip[(uint)Yunjr.EQUIP.HAND_SUB];
							GameRes.player[this._ix_player].SetEquipment(EQUIP.HAND_SUB, equiped);
							break;
						case 2:
							unequiped = GameRes.player[this._ix_player].equip[(uint)Yunjr.EQUIP.ARMOR];
							GameRes.player[this._ix_player].SetEquipment(EQUIP.ARMOR, equiped);
							break;
						case 3:
							unequiped = GameRes.player[this._ix_player].equip[(uint)Yunjr.EQUIP.HEAD];
							GameRes.player[this._ix_player].SetEquipment(EQUIP.HEAD, equiped);
							break;
						case 4:
							unequiped = GameRes.player[this._ix_player].equip[(uint)Yunjr.EQUIP.LEG];
							GameRes.player[this._ix_player].SetEquipment(EQUIP.LEG, equiped);
							break;
						case 5:
							unequiped = GameRes.player[this._ix_player].equip[(uint)Yunjr.EQUIP.ETC];
							GameRes.player[this._ix_player].SetEquipment(EQUIP.ETC, equiped);
							break;
						default:
							equiped = null;
							break;
					}

					if (equiped != null && equiped.IsValid())
						GameRes.party.RemoveFromBackpack(equiped);

					if (unequiped != null && unequiped.IsValid())
						GameRes.party.PutInBackpack(unequiped);
				}

				this.UpdateScreen();
			}
		}

		public void UpdateScreen()
		{
			_SetFocusEquipment(_ix_equipment);
			_current_equipment_text.text = _GetPlayerInfo(_ix_player);
		}

		private void _SetFocusPlayer(int ix_player)
		{
			Debug.Log(String.Format("EVENT(Equipment)->_SetFocusPlayer({0})", ix_player));

			{
				GameObject ga_focus = GameObj.player_focus[1];
				GameObject ga_origin1 = GameObject.Find("PlayerStatus_2_1");
				GameObject ga_origin2 = GameObject.Find("PlayerStatus_2_2");

				Debug.Assert(ga_focus != null);
				Debug.Assert(ga_origin1 != null);
				Debug.Assert(ga_origin2 != null);

				{
					Vector3 pos = ga_origin1.transform.localPosition;
					float line_to_line_distance = ga_origin2.transform.localPosition.y - ga_origin1.transform.localPosition.y;
					pos.y = ga_origin1.transform.localPosition.y + line_to_line_distance * ix_player;
					ga_focus.transform.localPosition = pos;
				}

				_current_equipment_text.text = _GetPlayerInfo(this._ix_player);
			}

			this._DisplayItem();
		}

		private string _GetPlayerInfo(int index)
		{
			if ((index < 0 || index >= GameRes.player.Length) || !GameRes.player[index].IsValid())
				return "";

			GameRes.player[index].Apply();

			Equiped equiped;

			string STR_NA_GRAY = String.Format("@8{0}@@", _STR_NA);

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.HAND];
			string equip_hands = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA_GRAY;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.HAND_SUB];
			if (equiped != null && equiped.IsValid())
				equip_hands += " + " + equiped.name.GetName();

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.ARMOR];
			string equip_body = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA_GRAY;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.HEAD];
			string equip_head = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA_GRAY;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.LEG];
			string equip_leg = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA_GRAY;

			equiped = GameRes.player[index].equip[(uint)Yunjr.EQUIP.ETC];
			string equip_etc = (equiped != null && equiped.IsValid()) ? equiped.name.GetName() : STR_NA_GRAY;

			string s =
				"@B# 이름 : {0}@@\n" +
				"@B# 성별 : {1}@@\n" +
				"@B# 계급 : {2}@@\n" +
				"@3# 레벨 : {3}@@\n" +
				"@3# 경험치@@\n" +
				"@3[{4}]@@\n" +
				"@2\n" +
				"양 손 - {5}\n" +
				"몸 통 - {6}\n" +
				"머 리 - {7}\n" +
				"다 리 - {8}\n" +
				"장 식 - {9}@@";

			s = String.Format(s,
				GameRes.player[index].Name,
				LibUtil.GetAssignedString(GameRes.player[index].gender),
				LibUtil.GetAssignedString(GameRes.player[index].clazz),
				GameRes.player[index].status[(uint)STATUS.LEV],
				GameRes.player[index].GetExpGauge(),
				equip_hands,
				equip_body,
				equip_head,
				equip_leg,
				equip_etc
			);

			return LibUtil.SmTextToRichText(s);
		}

		private void _SetFocusEquipment(int ix_equipment)
		{
			Debug.Log(String.Format("EVENT(Equipment)->_SetFocusEquipment({0})", ix_equipment));

			this._DisplayItem();
		}

		private void _DisplayItem()
		{
			if (_ix_player < 0 || _ix_equipment < 0)
				return;

			Equiped equiped = GameRes.player[_ix_player].equip[_ix_equipment];

			string equipment_name = _STR_NA;
			bool is_equipment_removable = false;

			if (equiped != null && equiped.IsValid())
			{
				is_equipment_removable = true;

				equipment_name = equiped.name.GetName();
				if (equiped.item.res_id.GetItemType() == ResId.ITEM_TYPE_TAG_WEAPON && equiped.item.res_id.GetItemIndex() == 0)
					is_equipment_removable = false;
			}

			if (is_equipment_removable)
			{
				gui_button_remove.interactable = true;
				gui_button_remove.GetComponentInChildren<Text>().color = _BUTTON_TEXT_COLOR_ENABLED;
			}
			else
			{
				gui_button_remove.interactable = false;
				gui_button_remove.GetComponentInChildren<Text>().color = _BUTTON_TEXT_COLOR_DISABLED;
			}

			this._DisplayGuideText(equiped);

			// 현재 item 출력
			gui_text_current_equipment.text = equipment_name;
			gui_icon_current_equipment.sprite = icon_sprites[_ix_equipment % icon_sprites.Count];

			GameObject go = GameObject.FindWithTag("BackpackListView");
			if (go != null)
			{
				uint current_item_type;
				int current_item_detail = -1;
				switch (_ix_equipment)
				{
					case 0:
						current_item_type = ResId.ITEM_TYPE_TAG_WEAPON;
						break;
					case 1:
						current_item_type = ResId.ITEM_TYPE_TAG_SHIELD;
						break;
					case 2:
						current_item_type = ResId.ITEM_TYPE_TAG_ARMOR;
						current_item_detail = 0;
						break;
					case 3:
						current_item_type = ResId.ITEM_TYPE_TAG_ARMOR;
						current_item_detail = 1;
						break;
					case 4:
						current_item_type = ResId.ITEM_TYPE_TAG_ARMOR;
						current_item_detail = 2;
						break;
					case 5:
						current_item_type = ResId.ITEM_TYPE_TAG_ORNAMENT;
						break;
					default:
						Debug.Assert(false);
						return;
				}

				_currrent_listed.Clear();

				UIWidgets.ListViewIcons list_view_icons = go.GetComponentInChildren<UIWidgets.ListViewIcons>();
				list_view_icons.DataSource.Clear();

				for (int i = 0; i < GameRes.party.core.back_pack.Length; i++)
				{
					Equiped backpack_item = GameRes.party.core.back_pack[i];

					if (backpack_item != null && backpack_item.IsValid())
					{
						if (backpack_item.item.res_id.GetItemType() != current_item_type)
							continue;

						if (current_item_detail >= 0)
						if (backpack_item.item.res_id.GetItemDetail() != (uint)current_item_detail)
							continue;

						UIWidgets.ListViewIconsItemDescription icon_item_desc = new UIWidgets.ListViewIconsItemDescription();

						icon_item_desc.Icon = icon_sprites[_ix_equipment % icon_sprites.Count];
						icon_item_desc.Name = String.Format("{0}", backpack_item.name.GetName());
						icon_item_desc.Value = i;

						list_view_icons.DataSource.Add(icon_item_desc);

						_currrent_listed.Add(backpack_item);
					}
				}
			}
		}

		private void _DisplayGuideText(Equiped equiped)
		{
			string equipment_name = _STR_NA;
			string equipment_attrib = "";
			string equipment_annex = "";

			if (equiped != null && equiped.IsValid())
			{
				equipment_name = equiped.name.GetName();

				if (equiped.item.param.atta_pow != 0)
				{
					equipment_attrib += String.Format("{0}{1:+#;-#; }", "공격력", equiped.item.param.atta_pow);
					if (equiped.added.atta_pow != 0)
						equipment_attrib += String.Format("({0:+#;-#; }) ", equiped.added.atta_pow);
					else
						equipment_attrib += " ";
				}

				if (equiped.item.param.ac != 0)
				{
					equipment_attrib += String.Format("{0}{1:+#;-#; }", "방어력", equiped.item.param.ac);
					if (equiped.added.ac != 0)
						equipment_attrib += String.Format("({0:+#;-#; }) ", equiped.added.ac);
					else
						equipment_attrib += " ";
				}

				// Annex
				if (equiped.item.param.atta_pow == 0 && equiped.added.atta_pow != 0)
				{
					equipment_annex += String.Format("{0}{1:+#;-#; } ", "공격력", equiped.added.atta_pow);
				}

				if (equiped.item.param.ac == 0 && equiped.added.ac != 0)
				{
					equipment_annex += String.Format("{0}{1:+#;-#; } ", "방어력", equiped.added.ac);
				}

				for (int i = 0; i < equiped.added_status.Length; i++)
				{
					if (equiped.added_status[i] > 0)
						equipment_annex += String.Format("{0}{1:+#;-#; } ", LibUtil.GetAssignedString((STATUS)i), equiped.added_status[i]);
				}

				// 가장 위의 item 가이드 텍스트
				gui_text_guide.text = equipment_name + "\n<color=#FFD773FF>" + equipment_attrib + "</color>" + "<color=#FF73D7FF>" + equipment_annex + "</color>";
			}
			else
				gui_text_guide.text = "";

		}
	}
}
