
#pragma warning disable 0162

using UnityEngine;
using System;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using LitJson;

namespace Yunjr
{
	public abstract class YunjrMap
	{
		private struct _MapCreator
		{
			public delegate YunjrMap FnCreate();

			public uint index;
			public FnCreate fn_create;

			public _MapCreator(uint _index, FnCreate _fn_create)
			{
				index = _index;
				fn_create = _fn_create;
			}
		}

		private static readonly Dictionary<string, _MapCreator> _MAP_LIST = new Dictionary<string, _MapCreator>
		{
			{ "ORIGIN",   new _MapCreator(0, delegate () { return new YunjrMap_T1_Origin(); } ) },
			{ "GROUND1",  new _MapCreator(0, delegate () { return new YunjrMap_G1(); } ) },
			{ "TOWN1",    new _MapCreator(0, delegate () { return new YunjrMap_T1(); } ) },
			{ "TOWN2",    new _MapCreator(0, delegate () { return new YunjrMap_T2(); } ) },
			{ "DEN1",     new _MapCreator(0, delegate () { return new YunjrMap_D1(); } ) },
			{ "DEN2",     new _MapCreator(0, delegate () { return new YunjrMap_D2(); } ) },
			{ "Map002",   new _MapCreator(0, delegate () { return new YunjrMap_Z1(); } ) },
			{ "Map003",   new _MapCreator(0, delegate () { return new YunjrMap_Z2(); } ) },
			{ "Map011",   new _MapCreator(0, delegate () { return new YunjrMap_Z4(); } ) },
			{ "Prolog_B1",new _MapCreator(0, delegate () { return new YunjrMap_Z3(); } ) },
			{ "Prolog_B2",new _MapCreator(0, delegate () { return new YunjrMap_Z4(); } ) },
			{ "LoreContinent",new _MapCreator(0, delegate () { return new YunjrMap_C1(); } ) },
			{ "CastleLore",new _MapCreator(0, delegate () { return new YunjrMap_C1_T1(); } ) },
			{ "LastDitch",new _MapCreator(0, delegate () { return new YunjrMap_C1_T2(); } ) },
		};

		private static Dictionary<string, string> _MAP_NAME_TO_ID = null;

		// static functions
		public static YunjrMap CreateMapScript(string map_name)
		{
			if (_MAP_NAME_TO_ID == null)
			{
				_MAP_NAME_TO_ID = new Dictionary<string, string>();

				TextAsset map_info = Resources.Load("Text/MapInfos") as TextAsset;

				if (map_info != null)
				{
					JsonData json_map = JsonMapper.ToObject(map_info.text);

					if (json_map != null && json_map.IsArray)
					{
						for (int i = 0; i < json_map.Count; i++)
						{
							JsonData info = json_map[i];
							if (info != null)
							{
								string rpg_maker_map_name = info["name"].ToString();
								string id_as_string = info["id"].ToString();

								while (id_as_string.Length < 3)
									id_as_string = id_as_string.Insert(0, "0");

								_MAP_NAME_TO_ID.Add(rpg_maker_map_name, "Map" + id_as_string);
							}
						}
					}
					else
					{
						Debug.LogWarning("Unable to load 'MapInfos.json' as map infos");
					}
				}
			}

			YunjrMap map = null;

			string file_name = map_name;

			if (!_MAP_LIST.ContainsKey(map_name))
			{
				if (_MAP_NAME_TO_ID.ContainsValue(file_name))
					map_name = _MAP_NAME_TO_ID.FirstOrDefault(x => x.Value == file_name).Key;
				else
					Debug.LogErrorFormat("Map name '{0}' not found.", map_name);
			}
			else if (_MAP_NAME_TO_ID.ContainsKey(map_name))
			{
				file_name = _MAP_NAME_TO_ID[map_name];
			}

			if (_MAP_LIST.ContainsKey(map_name))
			{
				_MapCreator map_creator = _MAP_LIST[map_name];

				map = map_creator.fn_create();
				if (map != null)
				{
					map._global_index = map_creator.index;
					map._map_name = map_name;
					map._file_name = file_name;
				}
			}

			return map;
		}

		public enum HANDICAP : int
		{
			NONE = 0,
			WIZARD_EYE = 1,
			ETHEREALIZE = 2,
			TELEPORT = 4,
			CHANGE_TO_GROUND = 8,
			CHANGE_TO_GROUND_EX = 16,
			//MAX = 0x0F
		}

		public uint Index
		{
			get { return _global_index; }
		}

		public string MapName
		{
			get { return _map_name; }
		}

		public string FileName
		{
			get { return _file_name; }
		}

		protected uint _global_index;
		protected string _map_name;
		protected string _file_name;
		protected uint _handicap_bits = (uint)HANDICAP.NONE;

		protected int _prev_x;
		protected int _prev_y;
		protected int _curr_x;
		protected int _curr_y;
		protected List<string> _string_stack = new List<string>();
		protected System.Random _random = new System.Random();
		protected FnCallBack0 _fn_post_action = null;
		protected FnCallBack0 _fn_key_pressed_action = null;
		protected FnCallBack1_i _fn_just_selected_action = null;

		protected bool On(int x, int y)
		{
			return (_curr_x == x && _curr_y == y);
		}

		protected bool OnArea(int x1, int y1, int x2, int y2)
		{
			return (_curr_x >= x1 && _curr_x <= x2 && _curr_y >= y1 && _curr_y <= y2);
		}

		protected bool Equal<T>(T a, T b)
		{
			return (a.Equals(b));
		}

		protected bool Less(int a, int b)
		{
			return (a < b);
		}

		protected bool Not(bool cond)
		{
			return (!cond);
		}

		public void Talk(string s)
		{
			GameObj.text_dialog_prepared.Add(s);
		}

		public void PressAnyKey()
		{
			GameRes.GameState = GAME_STATE.IN_WAITING_FOR_KEYPRESS;
			GameObj.SetButtonGroup(BUTTON_GROUP.OK);
			GameEventMain.ResetArrowKey();
		}

		protected void Flag_Set(int index)
		{
			GameRes.flag.Set(index);
		}

		protected bool Flag_IsSet(int index)
		{
			return GameRes.flag.IsSet(index);
		}

		protected void Variable_Add(int index)
		{
			GameRes.variable[index] += 1;
		}

		protected void Variable_Set(int index, byte val)
		{
			GameRes.variable[index] = val;
		}

		protected byte Variable_Get(int index)
		{
			return GameRes.variable[index];
		}

		protected void Map_ChangeTile(int x, int y, int tile)
		{
			GameRes.map_data.data[x, y].ix_tile = tile;
			GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected void MapEx_ChangeTile(int x, int y, int tile)
		{
			GameRes.map_data.data[x, y].ix_tile = tile;
			GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected void MapEx_ChangeObj1(int x, int y, int obj1, bool reset_to_default_act_type = true)
		{
			GameRes.map_data.data[x, y].ix_obj1 = obj1;
			if (reset_to_default_act_type)
				GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected void MapEx_ChangeTile(int x, int y, int tile, int obj1)
		{
			GameRes.map_data.data[x, y].ix_tile = tile;
			GameRes.map_data.data[x, y].ix_obj1 = obj1;
			GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected void MapEx_ClearObj(int x, int y, bool reset_to_default_act_type = true)
		{
			GameRes.map_data.data[x, y].ix_obj0 = 0;
			GameRes.map_data.data[x, y].ix_obj1 = 0;
			if (reset_to_default_act_type)
				GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected void MapEx_ClearEvent(int x, int y)
		{
			GameRes.map_data.data[x, y].ix_event = 0;
			GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected void MapEx_SetEvent(int x, int y, int id)
		{
			GameRes.map_data.data[x, y].ix_event = EVENT_BIT.TYPE_EVENT | id;
			GameRes.map_data.data[x, y].act_type = ACT_TYPE.DEFAULT;
		}

		protected string Player_GetName(int index)
		{
			if (index >= 0 && index < GameRes.player.Length)
				return GameRes.player[index].Name;
			else
				return "";
		}

		protected string Player_GetGenderName(int index)
		{
			if (index >= 0 && index < GameRes.player.Length)
				return LibUtil.GetAssignedString(GameRes.player[index].gender);
			else
				return LibUtil.GetAssignedString(Yunjr.GENDER.UNKNOWN);
		}

		protected void Select_Init()
		{
			GameRes.selection_list.Init();
		}

		protected void Select_AddTitle(string s)
		{
			GameRes.selection_list.AddTitle(s);
		}

		protected void Select_AddGuide(string s)
		{
			GameRes.selection_list.AddGuide(s);
		}

		public void Select_AddItem(string s)
		{
			GameRes.selection_list.AddItem(s);
		}

		public void Select_Init(string title, string guide, string[] items, int init_val = 1)
		{
			GameRes.selection_list.Init(init_val);
			GameRes.selection_list.AddTitle(title);
			GameRes.selection_list.AddGuide(guide);

			if (items != null)
				foreach (var item in items)
					GameRes.selection_list.AddItem(item);
		}

		public void Select_Run(FnCallBack1_i fn_callback = null)
		{
			_fn_just_selected_action = fn_callback;

			GameObj.SetButtonGroup(BUTTON_GROUP.OK_CANCEL_UP_DOWN);
			GameObj.text_dialog_prepared.Add(GameRes.selection_list.GetCompleteString());
			GameRes.GameState = GAME_STATE.IN_PICKING_SENTENCE;
			GameEventMain.ResetArrowKey();
		}

		public void Select_Run_NoCancel(FnCallBack1_i fn_callback = null)
		{
			_fn_just_selected_action = fn_callback;

			GameObj.SetButtonGroup(BUTTON_GROUP.OK_UP_DOWN);
			GameObj.text_dialog_prepared.Add(GameRes.selection_list.GetCompleteString());
			GameRes.GameState = GAME_STATE.IN_PICKING_SENTENCE;
			GameEventMain.ResetArrowKey();
		}

		protected int Random(int max)
		{
			return (_random.Next(0, max));
		}

		protected void PushString(string s)
		{
			/*
			 *	PushString("힘내게, ");
			 *	PushString(Player_GetName(0));
			 *	PushString(" 자네라면 충분히 Necromancer를 무찌를수 있을 걸세. 자네만 믿겠네.");
			 *	Talk(PopString(3));
			 */
			_string_stack.Add(s);
		}

		protected void _MoveBack()
		{
			GameRes.party.Move(_prev_x - _curr_x, _prev_y - _curr_y, false);
			GameEventMain.ResetArrowKey();
		}

		protected string PopString(int count)
		{
			count = (count <= _string_stack.Count) ? count : _string_stack.Count;

			string s = "";

			int ix_end = _string_stack.Count;
			for (int ix = ix_end - count; ix < ix_end; ix++)
				s += _string_stack[ix];

			_string_stack.RemoveRange(ix_end - count, count);

			return s;
		}

		// 움직이고 난 뒤 할 행동 정의
		protected void RegisterPostAction(FnCallBack0 fn_callback = null)
		{
			_fn_post_action = fn_callback;
		}

		public void ProcessPost()
		{
			if (_fn_post_action != null)
			{
				FnCallBack0 fn_local_post_action = _fn_post_action;
				_fn_post_action = null;

				fn_local_post_action();
			}
		}

		public void RegisterKeyPressedAction(FnCallBack0 fn_callback = null)
		{
			_fn_key_pressed_action = fn_callback;
		}

		public void ProcessJustKeyPressed()
		{
			GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);

			if (_fn_key_pressed_action != null)
			{
				FnCallBack0 fn_local_key_pressed_action = _fn_key_pressed_action;
				_fn_key_pressed_action = null;

				fn_local_key_pressed_action();
			}
		}

		public void ProcessJustPicked()
		{
			GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);

			if (_fn_just_selected_action != null)
			{
				FnCallBack1_i fn_local_just_selected_action = _fn_just_selected_action;
				_fn_just_selected_action = null;

				fn_local_just_selected_action(GameRes.selection_list.ix_curr);

				GameEventMain.ResetArrowKey();
			}
		}

		public void Process(ACT_TYPE act_type, int x, int y, ref int dx, ref int dy, int event_id, out int post_event_id)
		{
			_prev_x = x;
			_prev_y = y;
			_curr_x = x + dx;
			_curr_y = y + dy;

			// 이벤트 없음
			post_event_id = 0;

			switch (act_type)
			{
			case ACT_TYPE.EVENT:
				if (CONFIG.DEBUG_MESSAGE_TO_HEADER)
					GameObj.SetHeaderText(LibUtil.SmTextToRichText("[ACT_TYPE.EVENT] 발생"));

					if (!OnEvent(event_id, out post_event_id))
						dx = dy = 0;

					break;

			case ACT_TYPE.POST_EVENT:
				if (CONFIG.DEBUG_MESSAGE_TO_HEADER)
					GameObj.SetHeaderText(LibUtil.SmTextToRichText("[ACT_TYPE.POST_EVENT] 발생"));

				OnPostEvent(event_id, out post_event_id);
				break;

			case ACT_TYPE.ENTER:
				if (CONFIG.DEBUG_MESSAGE_TO_HEADER)
					GameObj.SetHeaderText(LibUtil.SmTextToRichText("[ACT_TYPE.ENTER] 발생"));

				if (OnEnter(event_id))
				{
					dx = dy = 0;
				}
				else
				{
					dx = dy = 0;
				}
				break;

			case ACT_TYPE.SIGN:
				if (CONFIG.DEBUG_MESSAGE_TO_HEADER)
					GameObj.SetHeaderText(LibUtil.SmTextToRichText("[ACT_TYPE.SIGN] 발생"));

				dx = dy = 0;
				//TextAlign(ALIGN_CENTER)
				OnSign(event_id);
				//TextAlign(ALIGN_LEFT)

				break;
			case ACT_TYPE.TALK:
				dx = dy = 0;
				//GameObj.SetHeaderText(LibUtil.SmTextToRichText("@2(한 번 이름을 기억한 사람이라면 그에 대한 간단한 설명이 뜬다)@@"), 4);
				Debug.Log("[" + _curr_x + "," + _curr_y + "]");
				OnTalk(event_id);
				break;
			default:
				Debug.Log("[ERROR] YunjrMap_T1.Process(): Unknown act_type");
				break;
			}
		}

		public void AddHandicap(HANDICAP handicap)
		{
			_handicap_bits |= (uint)handicap;
		}

		public void RemoveHandicap(HANDICAP handicap)
		{
			if (IsHandicapped(handicap))
				_handicap_bits ^= (uint)handicap;
		}

		public void ResetHandicap()
		{
			_handicap_bits = (uint)HANDICAP.NONE;
		}

		public bool IsHandicapped(HANDICAP handicap)
		{
			return (_handicap_bits & (uint)handicap) > 0;
		}

		public abstract string GetPlaceName(byte degree_of_well_known);

		public abstract void OnPrepare();
		public abstract void OnLoad(string prev_map, int from_x, int from_y);
		public abstract void OnUnload();

		// Return value: true -> you can move to there
		public abstract bool OnEvent(int event_id, out int post_event_id);
		public abstract void OnPostEvent(int event_id, out int post_event_id);
		public abstract bool OnEnter(int event_id);
		public abstract void OnSign(int event_id);
		public abstract void OnTalk(int event_id);
	}
}
