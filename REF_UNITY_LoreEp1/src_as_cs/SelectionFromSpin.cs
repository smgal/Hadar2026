using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public class SelectionFromSpin
	{
		public delegate void FnCallBack0();

		private bool _invalidated;
		private string _title;
		private string _contents;

		protected FnCallBack0 _fn_press_up_action = null;
		protected FnCallBack0 _fn_press_down_action = null;
		protected FnCallBack0 _fn_just_selected_action = null;

		public void Init()
		{
			_invalidated = true;
			_title = "";
			_contents = "";

			Console.Clear();
		}

		public void AddTitle(string s)
		{
			_title = s;
			_invalidated = true;
		}

		public void AddContents(string s)
		{
			_contents = s;
			_invalidated = true;
		}

		public string GetCompleteString()
		{
			return _title + "\n\n" + _contents;
		}

		public void Update()
		{
			if (_invalidated)
			{
				Console.DisplaySmText(GetCompleteString(), true);
				_invalidated = false;
			}
		}

		public void Run(FnCallBack0 fn_callback_just_slected, FnCallBack0 fn_callback_up, FnCallBack0 fn_callback_down)
		{
			_fn_press_up_action = fn_callback_up;
			_fn_press_down_action = fn_callback_down;
			_fn_just_selected_action = fn_callback_just_slected;

			this.Update();

			GameObj.SetButtonGroup(BUTTON_GROUP.OK_CANCEL_UP_DOWN);

			GameRes.GameState = GAME_STATE.IN_SELECTING_SPIN;

			GameEventMain.ResetArrowKey();
		}

		public void PressUp()
		{
			if (_fn_press_up_action != null)
				_fn_press_up_action();
		}

		public void PressDown()
		{
			if (_fn_press_down_action != null)
				_fn_press_down_action();
		}

		public void JustSelected()
		{
			this.Cancel();

			if (_fn_just_selected_action != null)
			{
				FnCallBack0 fn_local_just_selected_action = _fn_just_selected_action;
				_fn_just_selected_action = null;

				fn_local_just_selected_action();
			}
		}

		public void Cancel()
		{
			GameRes.GameState = GAME_STATE.IN_MOVING;
			GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
			Console.DisplayRichText("");
		}
	}
	/*
			public delegate void FnCallBack0();

			public List<string> items = new List<string>();
			public List<int> real_index = new List<int>();
			public int ix_curr = 1;

			protected FnCallBack0 _fn_just_selected_action = null;

			public void Init()
			{
				title = "";
				items.Clear();
				items.Add("");

				real_index.Clear();
				real_index.Add(0);

				ix_curr = 1;
				_fn_just_selected_action = null;

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
				real_index.Add(real_index.Count);
			}

			public void AddItem(string s, int ix_real)
			{
				items.Add(s);
				real_index.Add(ix_real);
			}

			public int GetRealIndex(int index)
			{
				if (index > 0 && index < items.Count)
					return (real_index[index]);
				else
					return 0;

			}

			public string GetCompleteString()
			{
				string s = "";

				if (title != "")
					s += "@F" + title + "@@\n\n";

				int count = 0;
				foreach (string sub in GameRes.selection_list.items)
				{
					if (count == 0 && sub != "")
					{
						s += "@C" + sub + "@@\n";
					}
					else
					{
						if (count == GameRes.selection_list.ix_curr)
							s += "@A>> @F" + sub + "@@ <<@@\n";
						else
							s += "   " + sub + "\n";
					}

					count++;
				}

				return s;
			}

			public void Run(FnCallBack0 fn_callback = null)
			{
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
	*/
}
