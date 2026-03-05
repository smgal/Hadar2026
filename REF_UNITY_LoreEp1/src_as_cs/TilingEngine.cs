
using UnityEngine;
using UnityEngine.SceneManagement;

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using Lean;

namespace Yunjr
{
	public class TilingEngine : MonoBehaviour
	{
		public GameObject prefabTileContainer;
		public GameObject prefabTile;
		public GameObject prefabTileNight;

		// map renderer
		private GameObject _tileContainer;
		private List<GameObject> _tiles = new List<GameObject>();
		private float _scalingFactor = 28.8f * 10.0f / 12.0f; // 12 tiles in width

		// player information
		private GameObject _player;
		private SpriteRenderer _player_renderer;

		// shadow map
		private const int VIEW_PORT_W_HALF = CONFIG.VIEW_PORT_W_HALF;
		private const int VIEW_PORT_H_HALF = CONFIG.VIEW_PORT_H_HALF;

		private const int VIEW_PORT_X1 = -VIEW_PORT_W_HALF + 1;
		private const int VIEW_PORT_X2 = VIEW_PORT_W_HALF;
		private const int VIEW_PORT_Y1 = -VIEW_PORT_H_HALF + 1;
		private const int VIEW_PORT_Y2 = VIEW_PORT_H_HALF;

		private const int _LIGHT_RANGE_W = VIEW_PORT_X2 - VIEW_PORT_X1 + 1;
		private const int _LIGHT_RANGE_H = VIEW_PORT_Y2 - VIEW_PORT_Y1 + 1;

		private const int _MAX_LIGHT_RANGE_STEP = 5;

		private bool _light_range_not_initialized = true;
		private byte[,,] _LIGHT_RANGE = new byte[_MAX_LIGHT_RANGE_STEP, _LIGHT_RANGE_H, _LIGHT_RANGE_W];

		public void Start()
		{
			Debug.Log("TilingEngine::Start()");

			_player = GameObject.Find("Player");

			Debug.Log(String.Format("Player position ({0}, {1})", _player.transform.position.x, _player.transform.position.y));

			if (_player != null)
				_player_renderer = _player.GetComponent<SpriteRenderer>();

			// _LIGHT_RANGE[] 배열을 계산해서 채우기
			if (_light_range_not_initialized)
			{
				Array.Clear(_LIGHT_RANGE, 0, _LIGHT_RANGE.Length);

				const int MAG = 2;

				int CEN_X = Math.Abs(VIEW_PORT_X1) * MAG + 1;
				int CEN_Y = Math.Abs(VIEW_PORT_Y1) * MAG + 1;

				for (int range = 0; range < _MAX_LIGHT_RANGE_STEP; range++)
				{
					float sqr_radius = (MAG * range + 0.3f);
					sqr_radius *= sqr_radius;

					for (int y = 0; y < _LIGHT_RANGE_H * MAG; y++)
					{
						for (int x = 0; x < _LIGHT_RANGE_W * MAG; x++)
						{
							float fx = (x - CEN_X) + 0.5f;
							float fy = (y - CEN_Y) + 0.5f;

							if ((fx * fx + fy * fy) <= sqr_radius)
								_LIGHT_RANGE[range, y / MAG, x / MAG] |= (byte)(1 << ((x % 2) + 2 * (y % 2)));
						}
					}
				}

				_light_range_not_initialized = false;
			}

		}

#if (false)
		void OnGUI()
		{
/*
			float SCREEN_WIDTH  = 720;
			float SCREEN_HEIGHT = 1280;

			GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, new Vector3(1.0f * Screen.width / SCREEN_WIDTH, 1.0f * Screen.height / SCREEN_HEIGHT, 1.0f));
*/
			
/*
			float x = GameObj.text_dialog.transform.position.x;
			float y = GameObj.text_dialog.transform.position.y;
			float z = GameObj.text_dialog.transform.position.z;

			x += GameObj.text_dialog.rectTransform.offsetMin.x;
			y += GameObj.text_dialog.rectTransform.offsetMax.y;
			y -= GameObj.text_dialog.rectTransform.offsetMin.y;

			Vector3 pos = Camera.main.WorldToScreenPoint(new Vector3(x, y, 0.0f));
			Vector3 size = Camera.main.WorldToScreenPoint(new Vector3(256.0f, 256.0f, 0.0f));

			pos.y = Camera.main.pixelHeight - pos.y;

			GUI.DrawTexture(new Rect(pos.x, pos.y, size.x, size.y), Console.mini_map, ScaleMode.ScaleToFit);
*/
/*
			RectTransform rt = GameObj.text_dialog.rectTransform;
			float x1 = rt.offsetMin.x;
			float x2 = rt.offsetMax.x;
			float y1 = rt.offsetMax.y;
			float y2 = rt.offsetMin.y;

			Vector3 pos1 = Camera.main.WorldToScreenPoint(new Vector3(x1, y1, 0.0f));
			Vector3 pos2 = Camera.main.WorldToScreenPoint(new Vector3(x2, y2, 0.0f));

			GUI.DrawTexture(new Rect(pos1.x, pos1.y, pos2.x - pos1.x, pos2.y - pos1.y), Console.mini_map);

			Debug.Log(String.Format("Screen: ({0,2},{1,2}) - ({2,2},{3,2})", pos1.x, pos1.y, pos2.x - pos1.x, pos2.y - pos1.y));
*/
		}
#endif

		private int _fps_prev_second = -1;
		private int _fps_count = 0;

		private void _DisplayDebugFps()
		{
			++_fps_count;

			int fps_current_second = (int)Time.realtimeSinceStartup;
			if (fps_current_second > _fps_prev_second)
			{
				GameObj.text_debug_fps.text = String.Format("{0:F1}", 1.0f * _fps_count / (fps_current_second - _fps_prev_second));
				_fps_prev_second = fps_current_second;
				_fps_count = 0;
			}
		}

		private void Update()
		{
			if (GameRes.map_data.map_name != "")
			{
				switch (GameRes.GameState)
				{
					case GAME_STATE.IN_BATTLE:
					case GAME_STATE.JUST_BATTLE_COMMAND_SELECTED:
						break;
					default:
						DisplayMainMap();
						break;
				}
			}

			if (!GameRes.party.IsBusy())
			{
				switch (GameRes.GameOverCondition)
				{
					case GAMEOVER_CONDITION.NONE:
					case GAMEOVER_CONDITION.DEAD_ON_FIELD_LOAD:
						break;
					case GAMEOVER_CONDITION.EXIT_REQUIRED:
						Application.Quit();
						return;
					case GAMEOVER_CONDITION.PROLOG_CLEARED:
						GameRes.GameOverCondition = GAMEOVER_CONDITION.NONE;
						SceneManager.LoadScene("CreateCharacter", LoadSceneMode.Single);
						return;
					case GAMEOVER_CONDITION.DEAD_ON_FIELD:
						{
							Console.Clear();
							GameEventMain.ResetArrowKey();

							MainMenuConfirm main_menu_confirm = (MainMenuConfirm)GameObj.panel_main_menus[(int)MAIN_MENU.POPUP_CONFIRM].GetComponent<MainMenuConfirm>();
							byte identifing_degree = GameRes.GetIdentifingDegreeOfCurrentMap();

							main_menu_confirm.AssignMessageAndLocation(MainMenuConfirm.MESSAGE.DEAD_ON_FIELD, "[" + GameRes.map_script.GetPlaceName(identifing_degree) + "]");

							GameObj.SetButtonGroup(BUTTON_GROUP.DISABLE);
							GameObj.SetMainMenuOnOff(MAIN_MENU.POPUP_CONFIRM);
						}
						return;
					case GAMEOVER_CONDITION.DEAD_ON_BATTLE:
						{
							Console.Clear();
							GameEventMain.ResetArrowKey();

							MainMenuConfirm main_menu_confirm = (MainMenuConfirm)GameObj.panel_main_menus[(int)MAIN_MENU.POPUP_CONFIRM].GetComponent<MainMenuConfirm>();
							byte identifing_degree = GameRes.GetIdentifingDegreeOfCurrentMap();
							
							main_menu_confirm.AssignMessageAndLocation(MainMenuConfirm.MESSAGE.DEAD_ON_BATTLE, "[" + GameRes.map_script.GetPlaceName(identifing_degree) + "]");

							GameObj.SetButtonGroup(BUTTON_GROUP.DISABLE);
							GameObj.SetMainMenuOnOff(MAIN_MENU.POPUP_CONFIRM);
						}
						return;
				}

				if (GameRes.GameState == GAME_STATE.ON_MOVING_STEP)
				{
					// 이 코드는 이 위치에 있어야 PressAnyKey 처리가 된다.
					GameRes.GameState = GAME_STATE.IN_MOVING;

					if (GameRes.party.core.time_event_duration > 0)
					{
						if (--GameRes.party.core.time_event_duration == 0)
						{
							int time_event_id = GameRes.party.core.time_event_id;
							GameRes.party.core.time_event_id = 0;

							GameObj.text_dialog_prepared.Init(false);
							{
								int party_x = (int)(GameRes.party.pos.x);
								int party_y = (int)(GameRes.party.pos.y);

								int dx = 0;
								int dy = 0;

								int post_event_id = 0;

								GameRes.map_script.Process(ACT_TYPE.EVENT, party_x, party_y, ref dx, ref dy, time_event_id, out post_event_id);
								GameRes.PostEventId = post_event_id;
							}

							// 무시된(또는 재설정된) Time event가 console의 메시지를 지우지 않도록 
							if (!GameObj.text_dialog_prepared.Empty())
							{
								Console.Clear();
								GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();
							}
						}
					}
				}

				switch (GameRes.GameState)
				{
				case GAME_STATE.ON_MOVING:
					GameObj.panel_map.SetActive(true);
					GameObj.panel_battle.SetActive(false);
					GameObj.SetButtonGroup(BUTTON_GROUP.MOVE_MENU);
					GameRes.GameState = GAME_STATE.IN_MOVING;
					Console.Clear();
					break;

				case GAME_STATE.IN_MOVING:
					{
						int dx = 0;
						int dy = 0;

						if (GameRes.PostEventId <= 0)
						{
							if (GameEventMain.IsPressing(BUTTON.ARROW_LEFT))
								dx = -1;
							if (GameEventMain.IsPressing(BUTTON.ARROW_RIGHT))
								dx = 1;

							if (Input.GetKey(KeyCode.LeftArrow))
								dx = -1;
							if (Input.GetKey(KeyCode.RightArrow))
								dx = 1;

							// 방향키 2개를 키를 동시에 눌렀을 경우를 대비
							if (dx == 0)
							{
								if (GameEventMain.IsPressing(BUTTON.ARROW_UP))
									dy = -1;
								if (GameEventMain.IsPressing(BUTTON.ARROW_DOWN))
									dy = 1;

								if (Input.GetKey(KeyCode.UpArrow))
									dy = -1;
								if (Input.GetKey(KeyCode.DownArrow))
									dy = 1;
							}

							/*
							if (Input.GetKey(KeyCode.A))
								GameEventMain.OnButtonOkClick();
							if (Input.GetKey(KeyCode.Escape))
								GameEventMain.OnButtonMenuClick();
							*/

							if (Input.GetKey(KeyCode.S))
							{
								LibUtil.SaveScreenShot("screen_shot.png");
								GameObj.text_debug.text = "Screen shot saved.";
							}
						}

						int party_x = (int)(GameRes.party.pos.x);
						int party_y = (int)(GameRes.party.pos.y);

						// 공중 부상 중일 때는 계속 앞으로 진행한다.
						{
							if (GameRes.map_data.GetActType(party_x, party_y) == ACT_TYPE.CLIFF)
							{
								int _dx = LibUtil.Sign(GameRes.party.faced.dx);
								int _dy = LibUtil.Sign(GameRes.party.faced.dy);

								if (GameRes.map_data.GetActType(party_x + dx, party_y + dy) != ACT_TYPE.BLOCK)
								{
									dx = _dx;
									dy = _dy;
								}
							}
						}

						if (dx != 0 || dy != 0)
						{
							GameRes.party.SetDirection(dx, dy);

							int map_x = party_x + dx;
							int map_y = party_y + dy;

							// 지도 밖으로 나가는 것에 대한 제한
							if (map_x < CONFIG.VIEW_PORT_W_HALF - 1 || map_x > GameRes.map_data.size.w - CONFIG.VIEW_PORT_W_HALF
								|| map_y < CONFIG.VIEW_PORT_H_HALF - 1 || map_y > GameRes.map_data.size.h - CONFIG.VIEW_PORT_H_HALF)
								break;

							ACT_TYPE act_type = GameRes.map_data.GetActType(map_x, map_y);
							int event_id = GameRes.map_data[map_x, map_y].ix_event & EVENT_BIT.MASK_OF_INDEX;

							uint unique_id = LibUtil.MakeUniqueId(act_type, map_x, map_y, dx, dy);

							if (unique_id > 0 && GameEventMain.PrevUniqueId == unique_id)
								break;

							GameRes.party.aux.latest_event_pos.x = map_x;
							GameRes.party.aux.latest_event_pos.y = map_y;

							GameRes.map_script.ProcessPost();

							GameEventMain.PrevUniqueId = 0;

							switch (act_type)
							{
							case ACT_TYPE.BLOCK:
								dx = dy = 0;
								
								// 움직이지 않고 방향만 바꿔도 이벤트 발생
								{
									int event_x = party_x;
									int event_y = party_y;

									if (GameRes.map_data.GetActType(event_x, event_y) == ACT_TYPE.EVENT)
									{
										event_id = GameRes.map_data[event_x, event_y].ix_event & EVENT_BIT.MASK_OF_INDEX;

										GameObj.text_dialog_prepared.Init();
										{
											int post_event_id = 0;
											GameRes.map_script.Process(ACT_TYPE.EVENT, event_x, event_y, ref dx, ref dy, event_id, out post_event_id);
											GameRes.PostEventId = post_event_id;
										}
										GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();
									}
								}
								break;
							case ACT_TYPE.MOVE:
								break;
							case ACT_TYPE.WATER:
								GameRes.party.EnterWater(GameRes.map_data[map_x, map_y].ix_tile, ref dx, ref dy);
								break;
							case ACT_TYPE.SWAMP:
								GameRes.party.EnterSwamp(ref dx, ref dy);
								break;
							case ACT_TYPE.LAVA:
								GameRes.party.EnterLava(ref dx, ref dy);
								break;
							case ACT_TYPE.CLIFF:
								GameRes.party.EnterCliff(ref dx, ref dy);
								break;
							case ACT_TYPE.EVENT:
							case ACT_TYPE.ENTER:
							case ACT_TYPE.SIGN:
							case ACT_TYPE.TALK:
								GameObj.text_dialog_prepared.Init();
								{
									int post_event_id = 0;
									GameRes.map_script.Process(act_type, party_x, party_y, ref dx, ref dy, event_id, out post_event_id);
									GameRes.PostEventId = post_event_id;
								}
								GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();

								// 대화를 한 후 캐릭터가 그 자리에서 사라지는 경우를 대비하여, unique_id를 이벤트 후의 값으로 갱신
								{
									act_type = GameRes.map_data.GetActType(map_x, map_y);
									unique_id = LibUtil.MakeUniqueId(act_type, map_x, map_y, dx, dy);
								}

								GameEventMain.PrevUniqueId = unique_id;

								// 이렇게 하지 않으면 지나가면서 글자가 나타나는 이벤트에서 끊기게 된다. (또는 아직 미발생 이벤트)
								if (act_type != ACT_TYPE.EVENT)
									GameEventMain.ResetArrowKey();

								break;

							case ACT_TYPE.POST_EVENT:
							case ACT_TYPE.DEFAULT:
							default:
								Debug.Log("[map][x,y] is faced with a unknown tile");
								GameEventMain.PrevUniqueId = unique_id;
								break;
							}

							if (dx != 0 || dy != 0)
							{
								GameRes.party.Move(dx, dy);

								if (CONFIG.TILE_SET_CURRENT == TILE_SET.GROUND)
									GameRes.party.PassTime(0, 2, 0);
								else
									GameRes.party.PassTime(0, 0, 5);

								GameObj.UpdadeTick();
							}
						}
						else if (GameRes.PostEventId > 0)
						{
							GameObj.text_dialog_prepared.Init();

							int event_id = GameRes.PostEventId;
							{
								int post_event_id = 0;
								GameRes.map_script.Process(ACT_TYPE.POST_EVENT, party_x, party_y, ref dx, ref dy, event_id, out post_event_id);
								GameRes.PostEventId = post_event_id;
							}
							GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();

							ACT_TYPE act_type = GameRes.map_data.GetActType(party_x, party_y);
							GameEventMain.PrevUniqueId = LibUtil.MakeUniqueId(act_type, party_x, party_y, dx, dy);
						}
						else
						{
							// 이동 키를 떼고나면 같은 이벤트 이동 제한 풀린다.
							GameEventMain.PrevUniqueId = 0;
						}
					}
					break;

				case GAME_STATE.IN_WAITING_FOR_OK_CANCEL:
					break;

				case GAME_STATE.JUST_OK_PRESSED:
					GameRes.GameState = GAME_STATE.IN_MOVING;
					if (GameRes._fn_ok_pressed != null)
						GameRes._fn_ok_pressed();
					break;

				case GAME_STATE.JUST_CANCEL_PRESSED:
					GameRes.GameState = GAME_STATE.IN_MOVING;
					if (GameRes._fn_cancel_pressed != null)
						GameRes._fn_cancel_pressed();
					break;

				case GAME_STATE.IN_WAITING_FOR_KEYPRESS:
					break;

				case GAME_STATE.JUST_KEYPRESSED:
					GameRes.GameState = GAME_STATE.IN_MOVING;
					GameObj.text_dialog_prepared.Init();
					GameRes.map_script.ProcessJustKeyPressed();
					GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();
					break;

				case GAME_STATE.IN_PICKING_SENTENCE:
					{
						int dy = (GameEventMain.IsClicked(BUTTON.ARROW_UP) || Input.GetKey(KeyCode.UpArrow)) ? -1 : 0;
						dy = (GameEventMain.IsClicked(BUTTON.ARROW_DOWN) || Input.GetKey(KeyCode.DownArrow)) ? 1 : dy;

						if (dy != 0)
						{
						SKIP_1:
							int index = GameRes.selection_list.ix_curr + LibUtil.Sign(dy);
							int ix_min = 1;
							int ix_max = GameRes.selection_list.items.Count;

							index = (index < ix_max) ? index : ix_min;
							index = (index >= ix_min) ? index : ix_max - 1;

							GameRes.selection_list.ix_curr = index;

							if (!GameRes.selection_list.enable[index])
								goto SKIP_1;

							GameObj.text_dialog_prepared.Init();
							GameObj.text_dialog_prepared.Add(GameRes.selection_list.GetCompleteString());
							GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();
						}
					}
					break;

				case GAME_STATE.JUST_PICKED:
					GameRes.GameState = GAME_STATE.IN_MOVING;
					GameObj.text_dialog_prepared.Init();
					GameRes.map_script.ProcessJustPicked();
					GameObj.text_dialog.text = GameObj.text_dialog_prepared.Done();
					break;

				case GAME_STATE.IN_SELECTING_MENU:
					{
						int dy = (GameEventMain.IsClicked(BUTTON.ARROW_UP) || Input.GetKey(KeyCode.UpArrow)) ? -1 : 0;
						dy = (GameEventMain.IsClicked(BUTTON.ARROW_DOWN) || Input.GetKey(KeyCode.DownArrow)) ? 1 : dy;

						if (dy != 0)
						{
							int ix_min = 1;
							int ix_max = GameRes.selection_list.items.Count;

							int index = GameRes.selection_list.ix_curr;

							do
							{
								index += LibUtil.Sign(dy);

								index = (index < ix_max) ? index : ix_min;
								index = (index >= ix_min) ? index : ix_max - 1;

							} while (!GameRes.selection_list.IsEnabled(index));

							GameRes.selection_list.ix_curr = index;

							GameObj.text_dialog.text = LibUtil.SmTextToRichText(GameRes.selection_list.GetCompleteString());
						}
					}
					break;

				case GAME_STATE.JUST_SELECTED:
					GameRes.GameState = GAME_STATE.IN_MOVING;
					GameRes.selection_list.JustSelected();
					break;

				case GAME_STATE.IN_SELECTING_SPIN:
					{
						int dy = (GameEventMain.IsClicked(BUTTON.ARROW_UP) || Input.GetKey(KeyCode.UpArrow)) ? -1 : 0;
						dy = (GameEventMain.IsClicked(BUTTON.ARROW_DOWN) || Input.GetKey(KeyCode.DownArrow)) ? 1 : dy;
						if (dy != 0)
						{
							if (dy < 0)
								GameRes.selection_spin.PressUp();
							else
								GameRes.selection_spin.PressDown();
						}

						GameRes.selection_spin.Update();
					}
					break;

				case GAME_STATE.JUST_SELECTED_FOR_SPIN:
					GameRes.selection_spin.JustSelected();
					break;

				case GAME_STATE.ON_BATTLE:
					GameObj.panel_map.SetActive(false);
					GameObj.panel_battle.SetActive(true);
					GameObj.SetButtonGroup(BUTTON_GROUP.OK_UP_DOWN);
					GameRes.GameState = GAME_STATE.IN_BATTLE;
					break;

				case GAME_STATE.IN_BATTLE:
					OldStyleBattle.Process();
					break;

				case GAME_STATE.JUST_BATTLE_COMMAND_SELECTED:
					OldStyleBattle.State = OldStyleBattle.STATE.JUST_SELECTED;
					GameRes.GameState = GAME_STATE.IN_BATTLE;
					OldStyleBattle.Process();
					break;

				case GAME_STATE.OUT_BATTLE:
					GameRes.GameState = GAME_STATE.ON_MOVING;
					break;
				}
			}

			if (GameRes.party.IsBusy())
				GameRes.party.Process();

			if (CONFIG.ENABLE_FPS_COUNTER)
				_DisplayDebugFps();
		}

		class _FOV
		{
			private const int _INVISIBLE = 0;
			private const int _VISIBLE = 1;
			private const int _FORCE_VISIBLE = 2;

			private const int _VIEW_PORT_W = 2 * VIEW_PORT_W_HALF + 1;
			private const int _VIEW_PORT_H = 2 * VIEW_PORT_H_HALF + 1;

			private Queue<int> _queue = new Queue<int>();
			private int[,] _data = new int[_VIEW_PORT_W, _VIEW_PORT_H];

			private int _map_offset_x;
			private int _map_offset_y;

			private void _PushQueue(int x, int y)
			{
				if (x >= 0 && x < _VIEW_PORT_W && y >= 0 && y < _VIEW_PORT_H)
				{
					if (_data[x, y] == _INVISIBLE)
					{
						_data[x, y] = _VISIBLE;

						if (!GameRes.map_data.IsOpaque(x + _map_offset_x, y + _map_offset_y))
							_queue.Enqueue(x << 16 | y);
					}
				}
			}

			public _FOV()
			{
				for (int w = 0; w < _VIEW_PORT_W; w++)
					for (int h = 0; h < _VIEW_PORT_H; h++)
						_data[w, h] = _VISIBLE;
			}

			public _FOV(int pos_x, int pos_y)
			{
				// _queue.Clear();
				// Array.Clear(_data, 0, _data.Length);

				const int INIT_X = VIEW_PORT_W_HALF;
				const int INIT_Y = VIEW_PORT_H_HALF;

				_map_offset_x = pos_x - INIT_X;
				_map_offset_y = pos_y - INIT_Y;

				_PushQueue(INIT_X, INIT_Y);

				while (_queue.Count > 0)
				{
					int y = _queue.Dequeue();
					int x = y >> 16;
					y &= 0xFFFF;

					_PushQueue(x, y - 1);
					_PushQueue(x, y + 1);

					_PushQueue(x - 1, y);
					_PushQueue(x + 1, y);
				}

				for (int y = 0; y < _VIEW_PORT_H; y++)
				{
					for (int x = 0; x < _VIEW_PORT_W; x++)
					{
						if (this[x, y] == 0 && GameRes.map_data.IsOpaque(x + _map_offset_x, y + _map_offset_y))
						{
							int bit = (this[x, y - 1] == _VISIBLE) ? 1 : 0;
							bit |= (this[x + 1, y] == _VISIBLE) ? 2 : 0;
							bit |= (this[x, y + 1] == _VISIBLE) ? 4 : 0;
							bit |= (this[x - 1, y] == _VISIBLE) ? 8 : 0;

							int map_x = x + _map_offset_x;
							int map_y = y + _map_offset_y;

							if ((!GameRes.map_data.IsOpaque(map_x + 1, map_y - 1) && (bit & 0x03) == 0x03)
								|| (!GameRes.map_data.IsOpaque(map_x + 1, map_y + 1) && (bit & 0x06) == 0x06)
								|| (!GameRes.map_data.IsOpaque(map_x - 1, map_y + 1) && (bit & 0x0C) == 0x0C)
								|| (!GameRes.map_data.IsOpaque(map_x - 1, map_y - 1) && (bit & 0x09) == 0x09))
								_data[x, y] = _FORCE_VISIBLE;
						}
					}
				}
			}

			public int this[int x, int y]
			{
				get { return (x >= 0 && x < _VIEW_PORT_W && y >= 0 && y < _VIEW_PORT_H) ? _data[x, y] : 0; }
			}
		}

		private void DisplayMainMap()
		{
			foreach (GameObject o in _tiles)
			{
				LeanPool.Despawn(o);
			}

			_tiles.Clear();

			LeanPool.Despawn(_tileContainer);
			_tileContainer = LeanPool.Spawn(prefabTileContainer);

			float SCALING_FACTOR = 2.50f * _scalingFactor; // 48px // 2.50f * 28.8f * 10.0f / 12.0f = 60
			SCALING_FACTOR *= CONFIG.GUI_SCALE;

			float CENTER_X = _player.transform.position.x;
			float CENTER_Y = _player.transform.position.y;

			float SCROLL_OFFSET_X = GameRes.party.pos.x - (int)GameRes.party.pos.x;
			float SCROLL_OFFSET_Y = GameRes.party.pos.y - (int)GameRes.party.pos.y;

			bool is_character_visible = true; // If your character is shown or not
			int  sight_range = 5;

			const bool IN_ABSOLUTE_DARK = false; // The absolute dark from someone's magic
			// 달빛이나 조명이 있는 경우
			bool IN_MOONLIGHT;
			// 밝지 않은 경우
			bool IN_DARK;
			{
				IN_MOONLIGHT = LibUtil.InRange((int)(GameRes.party.core.day / 12), 10, 20);
				{
					IN_MOONLIGHT &= (CONFIG.TILE_SET_CURRENT != TILE_SET.DEN);
					IN_MOONLIGHT |= (CONFIG.TILE_SET_CURRENT == TILE_SET.TOWN);
				}

				IN_DARK = (CONFIG.TILE_SET_CURRENT == TILE_SET.DEN) || !LibUtil.InRange((int)(GameRes.party.core.hour), 7, 17);

				{
					int time = GameRes.party.core.hour * 100 + GameRes.party.core.min;

					if (time < 600)
						sight_range = 1;
					else if (time < 620)
						sight_range = 2;
					else if (time < 640)
						sight_range = 3;
					else if (time < 700)
						sight_range = 4;
					else if (time < 1800)
						sight_range = 5;
					else if (time < 1820)
						sight_range = 4;
					else if (time < 1840)
						sight_range = 3;
					else if (time < 1900)
						sight_range = 2;
					else
						sight_range = 1;

					if (CONFIG.TILE_SET_CURRENT == TILE_SET.DEN)
						sight_range = 1;

					if (IN_DARK && GameRes.party.core.magic_torch > 0)
					{
						if (LibUtil.InRange(GameRes.party.core.magic_torch, 1, 2))
							sight_range = Math.Max(sight_range, 2);
						else if (LibUtil.InRange(GameRes.party.core.magic_torch, 3, 4))
							sight_range = Math.Max(sight_range, 3);
						else
						{
							sight_range = Math.Max(sight_range, 3);
							IN_MOONLIGHT = true;
						}
					}
				}

				if (IN_ABSOLUTE_DARK && GameRes.party.core.magic_torch == 0)
				{
					IN_MOONLIGHT = false;
					IN_DARK = false;
					is_character_visible = false;
					sight_range = 0;
				}

				/* 어둠 처리에 대한 원본 코드
				int time_zone = sight_range;

				for (int y = VIEW_PORT_Y1; y <= VIEW_PORT_Y2; y++)
				{
					for (int x = VIEW_PORT_X1; x <= VIEW_PORT_X2; x++)
					{
						byte light_bit = _LIGHT_RANGE[time_zone, y - VIEW_PORT_X1, x - VIEW_PORT_Y1];

						// A blue tile is displayed at the original
						bool loomed = IN_DARK && (light_bit != 0);

						if (IN_ABSOLUTE_DARK && (GameRes.party.core.magic_torch == 0))
							loomed = true;

						// << 원본 >>
						// if (화면 밖) then
						//		까만색으로 그린다.
						// else if (현 위치의 타일에 라이트가 적용) then
						//		정상으로 그린다.
						// else if (IN_MOONLIGHT or loomed == false) then
						//		loomed 변수대로 그린다.
						// else
						//		까만색으로 그린다.
						//
						// !is_character_visible이라면 중앙에 캐릭터를 없앤다.
					}
				}
				*/
			}

			_FOV fov = null;

			if (GameRes.party.aux.in_remote_viewing || GameRes.party.core.penetration > 0)
				fov = new _FOV();
			else
				fov = new _FOV((int)GameRes.party.pos.x, (int)GameRes.party.pos.y);

			for (int y = VIEW_PORT_Y1; y <= VIEW_PORT_Y2; y++)
			{
				var view_y = CENTER_Y - (y - SCROLL_OFFSET_Y) * SCALING_FACTOR;
				var shadow_y = CENTER_Y - y * SCALING_FACTOR + 2;
				var ix_y = y + GameRes.party.pos.y;

				if (ix_y < 0)
					continue;
				if ((int)ix_y >= GameRes.map_data.size.h)
					break;

				for (int x = VIEW_PORT_X1; x <= VIEW_PORT_X2; x++)
				{
					var view_x = CENTER_X + (x - SCROLL_OFFSET_X) * SCALING_FACTOR;
					var shadow_x = CENTER_X + x * SCALING_FACTOR;
					var ix_x = x + GameRes.party.pos.x;

					if (ix_x < 0)
						continue;
					if ((int)ix_x >= GameRes.map_data.size.w)
						break;

					if (!CONFIG.SMOOTH_SHADOWING)
						if (fov[x + VIEW_PORT_W_HALF, y + VIEW_PORT_H_HALF] == 0)
							continue;

					uint[] tile_list =
					{
						(uint)GameRes.map_data[(int)(ix_x), (int)(ix_y)].ix_obj1 | 0x80000000U,
						(uint)GameRes.map_data[(int)(ix_x), (int)(ix_y)].ix_obj0 | 0x80000000U,
						(uint)GameRes.map_data[(int)(ix_x), (int)(ix_y)].ix_tile,
					};

					if (CONFIG.SMOOTH_SHADOWING)
					{
						if (fov[x + VIEW_PORT_W_HALF, y + VIEW_PORT_H_HALF] == 0)
						{
							tile_list[0] = 0x80000000U;
							tile_list[1] = 0x80000000U;
							tile_list[2] = 32;
						}
					}

					float z = 0.0f;

					// shadow 가장 위의 레이어
					if (sight_range < _MAX_LIGHT_RANGE_STEP)
					{
						{
							int time_zone = sight_range;
							int ix = GameRes.map_data[(int)(ix_x), (int)(ix_y)].shadow;

							if (ix > 0)
							{
								byte light_bit = (time_zone < _MAX_LIGHT_RANGE_STEP) ? _LIGHT_RANGE[time_zone, y - VIEW_PORT_X1, x - VIEW_PORT_Y1] : (byte)0x0F;

								ix = ((ix ^ 0x0F) | light_bit) ^ 0x0F;

								// 이 상태이면 블록 자체를 안 그리기 때문에 shadow도 필요 없다.
								bool IS_THIS_TILE_BACK_OUT = !IN_MOONLIGHT && (ix == 15);

								if (ix > 0)
								{
									int offset = GameRes.ix_sprite_bundle_ex_object;

									if (!CONFIG.SMOOTH_SHADOWING)
									{
										// 그림자를 끊어지게 만드는 편법
										shadow_x = view_x;
										shadow_y = view_y;
									}

									MORE_SHADOWING:

									//var t = LeanPool.Spawn(prefabTileNight);
									var t = LeanPool.Spawn(prefabTile);
									t.transform.position = new Vector3(shadow_x, shadow_y, z);
									t.transform.SetParent(_tileContainer.transform);

									var renderer = t.GetComponent<SpriteRenderer>();
									renderer.sprite = GameRes.sprite_bundle_ex[GameRes.ix_sprite_bundle_ex_sprite + 48 + ix].tile_image;

									_tiles.Add(t);

									if (IS_THIS_TILE_BACK_OUT)
									{
										IS_THIS_TILE_BACK_OUT = false;
										goto MORE_SHADOWING;
									}
								}
							}
						}
					}

					z = 0.5f;
					foreach (uint ix in tile_list)
					{
						if ((ix & 0x80000000U) == 0 || (ix != 0x80000000U))
						{
							int offset = ((ix & 0x80000000U) > 0) ? GameRes.ix_sprite_bundle_ex_object : GameRes.ix_sprite_bundle_ex_tile;
							int index = (int)(ix & 0x7FFFFFFFU);

							if ((ix & 0x80000000U) > 0)
							{
								// Kira kira animation object
								if (index >= 88 && index < 96)
								{
									int kind = (index >= 88 && index < 92) ? 0 : 1;

									const string ANIME_PATTERN = "032314123";
									int[,] ANIME_PATTERN_INDEX = new int[,] { { 0, 88, 89, 90, 91 }, { 0, 92, 93, 94, 95 } };

									int tick = (int)(Time.realtimeSinceStartup * CONFIG.KIRAKIRA_FPS);

									int ix_pattern = (tick + (index - (88 + 4 * kind))) % ANIME_PATTERN.Length;
									int ix_pattern_index = ((int)ANIME_PATTERN[ix_pattern] - (int)('0')) % ANIME_PATTERN_INDEX.Length;

									index = ANIME_PATTERN_INDEX[kind, ix_pattern_index];

									if (index == 0)
										continue;
								}
							}

							var t = LeanPool.Spawn(prefabTile);
							t.transform.position = new Vector3(view_x, view_y, z);
							t.transform.SetParent(_tileContainer.transform);

							var renderer = t.GetComponent<SpriteRenderer>();
							renderer.sprite = GameRes.sprite_bundle_ex[offset + index].tile_image;

							_tiles.Add(t);
						}

						z += 0.5f;
					}

					/* for debugging
					if (x == 0 && y == 1)
					{
						var t = LeanPool.Spawn(prefabTile);
						t.transform.position = new Vector3(CENTER_X, CENTER_Y - SCALING_FACTOR, 0);
						t.transform.SetParent(_tileContainer.transform);

						var renderer = t.GetComponent<SpriteRenderer>();
						renderer.sprite = GameRes.sprite_bundle_ex[GameRes.ix_sprite_bundle_ex_object + 12].tile_image;

						_tiles.Add(t);
					}
					*/
				}
			}

			// apply faced-direction of PC
			if (_player_renderer.sprite)
			{
				int ix_sprite = GameRes.ix_sprite_bundle_sprite;
				ix_sprite += (GameRes.party.aux.ix_face_offset + GameRes.party.aux.ix_face_add);

				_player_renderer.sprite = GameRes.sprite_bundle[ix_sprite].tile_image;
			}

		}
	}
}
