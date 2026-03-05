using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public class SelectionFromList
	{
		public delegate void FnCallBack0();

		private string title = "";
		public List<string> items = new List<string>();
		public List<bool> enable = new List<bool>();
		public List<int> real_index = new List<int>();
		public int ix_curr = 1;
		public bool is_multi_page = false;

		protected FnCallBack0 _fn_just_selected_action = null;

		public void Init(int init_val = 1, bool _is_multi_page = false)
		{
			title = "";

			items.Clear();
			items.Add("");

			enable.Clear();
			enable.Add(true);

			real_index.Clear();
			real_index.Add(0);

			ix_curr = init_val;
			is_multi_page = _is_multi_page;

			_fn_just_selected_action = null;

			Console.Clear();
			GameEventMain.ResetArrowKey();
		}

		public void AddTitle(string s)
		{
			title = s;
		}

		public void AddGuide(string s)
		{
			items[0] = s;
		}

		public void AddItem(string s)
		{
			items.Add(s);
			enable.Add(true);
			real_index.Add(real_index.Count);
		}

		public void AddItem(string s, int ix_real)
		{
			items.Add(s);
			enable.Add(true);
			real_index.Add(ix_real);
		}

		public void AddItem(string s, int ix_real, bool _enable)
		{
			items.Add(s);
			enable.Add(_enable);
			real_index.Add(ix_real);
		}

		public int GetRealIndex(int index)
		{
			if (index > 0 && index < items.Count)
				return (real_index[index]);
			else
				return 0;
		}

		public bool IsEnabled(int index)
		{
			if (index > 0 && index < items.Count)
				return (this.enable[index]);
			else
				return false;
		}

		public int GetNumOfItems()
		{
			return (items.Count <= 1) ? 0 : items.Count - 1;
		}

		public string GetCurrentItem()
		{
			int ix = GameRes.selection_list.ix_curr;

			if (ix > 0 && ix < GameRes.selection_list.items.Count)
				return GameRes.selection_list.items[ix];
			else
				return "";
		}
		/*
		public void AddItem(int index, string s)
		{
		}
		*/
		public string GetCompleteString()
		{
			const int NUM_ROW_PER_PAGE = 6;

			bool MULTI_PAGE = (is_multi_page && GameRes.selection_list.GetNumOfItems() > NUM_ROW_PER_PAGE);

			int  page_index = 0;
			bool page_scroll_mark_up = false;
			bool page_scroll_mark_dn = false;

			if (MULTI_PAGE)
			{
				Debug.Assert(GameRes.selection_list.GetNumOfItems() <= 12);
				page_index = (GameRes.selection_list.ix_curr <= NUM_ROW_PER_PAGE) ? 0 : 1;
				page_scroll_mark_up = (page_index == 1);
				page_scroll_mark_dn = (page_index == 0);
			}

			string s = "";

			// Add title
			if (title != "")
				s += "@F" + title + "@@\n\n";

			// Add guide message
			if (GameRes.selection_list.items.Count > 0)
			{
				if (GameRes.selection_list.items[0] != "")
					s += "@C" + GameRes.selection_list.items[0] + "@@\n";
			}

			// Add scroll mark if it exists
			if (page_scroll_mark_up)
				s += "   @6▲      ▲       ▲      ▲@@\n";

			int count = 0;
			foreach (string sub in GameRes.selection_list.items)
			{
				if (count == 0)
				{
					;
				}
				else
				{
					if (!MULTI_PAGE || ((count - 1) / 6 == page_index))
					{
						if (count == GameRes.selection_list.ix_curr)
							s += "@A>> @F" + sub + "@@ <<@@\n";
						else if (GameRes.selection_list.enable[count])
							s += "   " + sub + "\n";
						else
							s += "   <color=#384038FF>" + sub + "</color>\n";
					}
				}

				count++;
			}

			if (page_scroll_mark_dn)
				s += "   @6▼      ▼       ▼      ▼@@\n";

			return s;
		}

		public void Run(FnCallBack0 fn_callback = null)
		{
			Debug.Assert(items.Count == enable.Count);

			bool invalid = true;

			if (enable.Count > 1)
			{
				for (int i = 1; i < enable.Count; i++)
				{
					if (enable[i])
					{
						invalid = false;
						break;
					}
				}
			}

			// 모든 항목이 disable 이라면
			if (invalid)
			{
				Console.DisplayRichText("");
				return;
			}

			// 커서를 enabled에 맞추기
			ix_curr = (ix_curr >= 1 && ix_curr < enable.Count) ? ix_curr : 1;

			if (!enable[ix_curr])
				for (int i = enable.Count - 1; i >= 1 ; i--)
					if (enable[i])
						ix_curr = i;

			GameObj.text_dialog.text = LibUtil.SmTextToRichText(GameRes.selection_list.GetCompleteString());

			_fn_just_selected_action = fn_callback;

			GameObj.SetButtonGroup(BUTTON_GROUP.OK_CANCEL_UP_DOWN);

			GameRes.GameState = GAME_STATE.IN_SELECTING_MENU;

			GameEventMain.ResetArrowKey();
		}

		public void JustSelected()
		{
			GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);

			if (_fn_just_selected_action != null)
			{
				FnCallBack0 fn_local_just_selected_action = _fn_just_selected_action;
				_fn_just_selected_action = null;

				fn_local_just_selected_action();
			}
		}
	}
}
