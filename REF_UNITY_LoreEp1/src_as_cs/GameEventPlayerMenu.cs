
using System;
using UnityEngine;
using UnityEngine.UI;

namespace Yunjr
{
	public class GameEventPlayerMenu: MonoBehaviour
	{
		public UIWidgets.Popup popup_main_menu;
		public UIWidgets.Popup popup_use_items;
		public UIWidgets.Popup popup_rest_here;
		public UIWidgets.Spinner spinner_in_rest_here;

		private static int _focused_player = -1;

		static private UIWidgets.Popup _main_menu = null;
		private static UIWidgets.Popup _current_popup = null;
		private static UIWidgets.Popup _confirmation_popup = null;

		public void Show(int focused_player)
		{
			_focused_player = focused_player;
			_Show((_focused_player >= 0) ? GameRes.player[_focused_player].GetName() : "");
		}

		protected void _Show(string name)
		{
			_main_menu = popup_main_menu.Clone();
			_main_menu.name = "PlayerMenu";
			_main_menu.Show
			(
				title: name,
				position: new Vector3(0, 0),
				modal: true,
				modalColor: new Color(0.0f, 0.0f, 0.0f, 0.6f)
			);
		}

		protected void _Hide()
		{
			if (_main_menu != null)
			{
				_main_menu.Close();
				_main_menu = null;
			}
		}

		protected void _ShowSubPopup(out UIWidgets.Popup out_popup, UIWidgets.Popup template, string name)
		{
			out_popup = null;

			if (template != null)
			{
				out_popup = template.Clone();

				out_popup.name = name;
				out_popup.Show
				(
					position: new Vector3(0, 0),
					modal: true,
					modalColor: new Color(0.0f, 0.0f, 0.0f, 0.0f)
				);
			}
		}

		protected void _HideAllPopup()
		{
			if (_confirmation_popup != null)
			{
				_confirmation_popup.Close();
				_confirmation_popup = null;
			}

			if (_current_popup != null)
			{
				_current_popup.Close();
				_current_popup = null;
			}

			this._Hide();
		}

		protected void _HideTopPopup()
		{
			if (_confirmation_popup != null)
			{
				_confirmation_popup.Close();
				_confirmation_popup = null;
			}
			else if (_current_popup != null)
			{
				_current_popup.Close();
				_current_popup = null;
			}
			else
				this._Hide();
		}

		//////////////////////////////////////////////////////////////////////////////

		public void OnPlayerInfoClick()
		{
			if (_focused_player >= 0)
				Console.DisplayPlayerInfo(_focused_player);

			_HideAllPopup();
		}

		public void OnPlayerStatusClick()
		{
			if (_focused_player >= 0)
				Console.DisplayPlayerStatus(_focused_player);

			_HideAllPopup();
		}

		public void OnUsingMagicClick()
		{
			_HideAllPopup();

			if (_focused_player >= 0)
				Console.UseAbility(GameRes.player[_focused_player]);
		}

		public void OnUsingEspClick()
		{
			_HideAllPopup();

			if (_focused_player >= 0)
				GameRes.party.UseEsp(GameRes.player[_focused_player]);
		}

		public void OnUsingItemClick()
		{
			_HideAllPopup();

			if (_focused_player >= 0)
				Console.UseItem(GameRes.player[_focused_player]);
		/* TODO:
			this._ShowSubPopup(out _current_popup, popup_use_items, "UseItems");

			GameObject go = GameObject.FindWithTag("ItemListView");
			
			if (go != null)
			{
				UIWidgets.ListViewIcons list_view_icons = go.GetComponentInChildren<UIWidgets.ListViewIcons>();
				list_view_icons.DataSource.Clear();

				for (int i = 0; i < GameRes.party.core.back_pack.Length; i++)
				{
					Equiped backpack_item = GameRes.party.core.back_pack[i];

					if (backpack_item != null && backpack_item.IsValid())
					{
						UIWidgets.ListViewIconsItemDescription icon_item_desc = new UIWidgets.ListViewIconsItemDescription();

						icon_item_desc.Icon = null;
						icon_item_desc.Name = String.Format("{0}", backpack_item.name.GetName());
						icon_item_desc.Value = i;

						list_view_icons.DataSource.Add(icon_item_desc);

						//_currrent_listed.Add(backpack_item);
					}
				}
			}
		*/
		}

		public void OnManagingEquipmentClick()
		{
			if (_focused_player >= 0)
			{
				Console.Clear();

				GameObj.canvas[0].SetActive(false);
				GameObj.canvas[1].SetActive(true);

				GameObject go = GameObject.Find("GameEventEquipment");
				if (go != null)
				{
					GameEventEquipment game_event = go.GetComponent<GameEventEquipment>();
					if (game_event != null)
						game_event.Reset(_focused_player);
				}
			}

			_HideAllPopup();
		}

		public void OnPartyInfoClick()
		{
			Console.DisplayPartyStatus();
			_HideAllPopup();
		}

		public void OnPartyItemClick()
		{
			Console.DisplayPartyItems();
			_HideAllPopup();
		}

		public void OnPlayerMenuRestHereClick()
		{
			spinner_in_rest_here.Value = GameRes.party.core.rest_time;
			this._ShowSubPopup(out _current_popup, popup_rest_here, "RestHere");
		}

		//////////////////////////////////////////////////////////////////////////////
		
		public void OnRestHereValueChanged(int val)
		{
			GameRes.party.core.rest_time = val;
		}

		public void OnRestHereOkClick()
		{
			_HideAllPopup();

			Console.Clear();
			Console.RestHere(GameRes.party.core.rest_time);
		}
	}
}
