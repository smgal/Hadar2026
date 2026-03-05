using UnityEngine;
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using LitJson;

namespace Yunjr
{
	public static class EVENT_BIT
	{
		public const int NONE = 0x00000000;

		public const int MASK_OF_TYPE = 0x00FF0000;
		public const int MASK_OF_INDEX = 0x0000FFFF;

		public const int TYPE_NONE = 0x00000000;
		public const int TYPE_EVENT = 0x00010000;
		public const int TYPE_TALK = 0x00020000;
		public const int TYPE_SIGN = 0x00030000;
		public const int TYPE_ENTER = 0x00040000;
	}

	[Serializable]
	public struct MapUnit
	{
		public int ix_tile;
		public int ix_obj0; // lower
		public int ix_obj1; // normal
		public int shadow;
		public int ix_event; // consist of EVENT_BIT
		public ACT_TYPE act_type;
	}

	public struct TalkDesc
	{
		public string name;
		public string note;
		public int x;
		public int y;
		public List<string> dialog;
	}

	[Serializable]
	public class MapData: ISerialize
	{
		[NonSerialized]
		public string map_name;
		[NonSerialized]
		public string file_name;
		[NonSerialized]
		public string byname;
		[NonSerialized]
		public Dictionary<int, string> events;
		[NonSerialized]
		public Dictionary<int, TalkDesc> talks;
		[NonSerialized]
		public Dictionary<int, TalkDesc> signs;
		[NonSerialized]
		public Dictionary<int, TalkDesc> enters;

		public Size<int> size;
		public MapUnit[,] data;

		public override void _Load(Stream stream)
		{
			_Read(stream, out this.size.w);
			_Read(stream, out this.size.h);

			this.data = new MapUnit[size.w, size.h];

			MapUnit mu;

			for (int x = 0; x < size.w; x++)
			{
				for (int y = 0; y < size.h; y++)
				{
					_Read(stream, out mu.ix_tile);
					_Read(stream, out mu.ix_obj0);
					_Read(stream, out mu.ix_obj1);
					_Read(stream, out mu.shadow);
					_Read(stream, out mu.ix_event);
					mu.act_type = (ACT_TYPE)_GetEnumAsInt(stream);

					data[x, y] = mu;
				}
			}
		}

		public override void _Save(Stream stream)
		{
			_Write(stream, ref size.w);
			_Write(stream, ref size.h);

			for (int x = 0; x < size.w; x++)
			{
				for (int y = 0; y < size.h; y++)
				{
					MapUnit mu = data[x, y];
					_Write(stream, ref mu.ix_tile);
					_Write(stream, ref mu.ix_obj0);
					_Write(stream, ref mu.ix_obj1);
					_Write(stream, ref mu.shadow);
					_Write(stream, ref mu.ix_event);
					_WriteEnum(stream, (int)mu.act_type);
				}
			}
		}

		public MapUnit this[int x, int y]
		{
			get { return (x >= 0 && x < size.w && y >= 0 && y < size.h) ? data[x, y] : data[0, 0]; }
			/* set { this.data[x,y] = value; } */
		}

		public ACT_TYPE GetActType(int x, int y)
		{
			ACT_TYPE act_type = this[x, y].act_type;
			int event_type = this[x, y].ix_event & EVENT_BIT.MASK_OF_TYPE;

			if (event_type != EVENT_BIT.TYPE_NONE)
			{
				if (event_type == EVENT_BIT.TYPE_EVENT)
					act_type = ACT_TYPE.EVENT;
				else if (event_type == EVENT_BIT.TYPE_TALK)
					act_type = ACT_TYPE.TALK;
				else if (event_type == EVENT_BIT.TYPE_SIGN)
					act_type = ACT_TYPE.SIGN;
				else if (event_type == EVENT_BIT.TYPE_ENTER)
					act_type = ACT_TYPE.ENTER;
				else
					Debug.Assert(false);
			}
			else
			{
				if (act_type == ACT_TYPE.DEFAULT)
				{
					int obj1 = this[x, y].ix_obj1;
					if (obj1 > 0)
						act_type = GameRes.sprite_bundle_ex[GameRes.ix_sprite_bundle_ex_object + obj1].act_type;

					if (act_type == ACT_TYPE.DEFAULT || act_type == ACT_TYPE.MOVE)
					{
						int tile = this[x, y].ix_tile;
						act_type = GameRes.sprite_bundle_ex[GameRes.ix_sprite_bundle_ex_tile + tile].act_type;
					}
				}
			}

			return act_type;
		}

		public bool IsOpaque(int x, int y)
		{
			int tile = this[x, y].ix_tile;
			return GameRes.sprite_bundle_ex[GameRes.ix_sprite_bundle_ex_tile + tile].act_type == ACT_TYPE.BLOCK;
		}

	}

	public class LibMapEx
	{
		public static void CreateMap(string map_name, int map_size_w, int map_size_h, out MapData map)
		{
			if (map_size_w < (int)CONFIG.MIN_MAP_SIZE)
				map_size_w = (int)CONFIG.MIN_MAP_SIZE;

			if (map_size_h < (int)CONFIG.MIN_MAP_SIZE)
				map_size_h = (int)CONFIG.MIN_MAP_SIZE;

			MapUnit default_val = new MapUnit();
			{
				default_val.ix_tile = CONFIG.IX_MAP_TILE_DEFAULT;
				default_val.ix_obj0 = CONFIG.IX_MAP_OBJECT_DEFAULT;
				default_val.ix_obj1 = CONFIG.IX_MAP_OBJECT_DEFAULT;
				default_val.ix_event = CONFIG.IX_MAP_EVENT_DEFAULT;
				default_val.act_type = ACT_TYPE.DEFAULT;
			}

			map = new MapData();

			map.map_name = map_name;
			map.file_name = map_name;
			map.byname = map_name;

			map.size.w = map_size_w;
			map.size.h = map_size_h;

			map.data = new MapUnit[map_size_w, map_size_h];
			map.events = new Dictionary<int, string>();
			map.talks = new Dictionary<int, TalkDesc>();
			map.signs = new Dictionary<int, TalkDesc>();
			map.enters = new Dictionary<int, TalkDesc>();

			for (int y = 0; y < map_size_h; y++)
				for (int x = 0; x < map_size_w; x++)
					map.data[x, y] = default_val;
		}

		public static bool LoadMap(string map_name, string file_name, ref MapData ref_map)
		{
			TextAsset json_file = Resources.Load("Text/" + file_name) as TextAsset;

			if (json_file == null)
				return false;

			JsonData json_map = JsonMapper.ToObject(json_file.text);

			if (json_map == null)
			{
				Debug.LogWarning(String.Format("Unable to load '{0}' as map format", file_name));
				return false;
			}

			MapData map = new MapData();

			map.map_name = map_name;
			map.file_name = file_name;
			map.byname = json_map["displayName"].ToString();

			map.size.w = Convert.ToInt32(json_map["width"].ToString());
			map.size.h = Convert.ToInt32(json_map["height"].ToString());

			map.data = new MapUnit[map.size.w, map.size.h];
			map.events = new Dictionary<int, string>();
			map.talks = new Dictionary<int, TalkDesc>();
			map.signs = new Dictionary<int, TalkDesc>();
			map.enters = new Dictionary<int, TalkDesc>();

			Array.Clear(map.data, 0, map.data.Length);

			int map_size = map.size.w * map.size.h;
			int map_pitch = map.size.w;
			int num_map_layer = json_map["data"].Count / map_size;

			const int RM_MAP_LAYER_TILE   = 0;
			const int RM_MAP_LAYER_OBJECT_LOWER = 2;
			const int RM_MAP_LAYER_OBJECT = 3;
			const int RM_MAP_LAYER_SHADOW = 4; // TL:1 TR:2 BL:4 BR:8
			const int RM_MAP_LAYER_EVENT  = 5;

			for (int layer = 0; layer < num_map_layer; layer++)
			{
				switch (layer)
				{
				case RM_MAP_LAYER_TILE:
					for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int data = Convert.ToInt32(json_map["data"][layer * map_size + y * map_pitch + x].ToString());
							data = (data < 0x600) ? data : data - 0x600;

							map.data[x, y].ix_tile = data;
							map.data[x, y].act_type = ACT_TYPE.DEFAULT;
						}
					break;

				case RM_MAP_LAYER_OBJECT_LOWER:
					for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int data = Convert.ToInt32(json_map["data"][layer * map_size + y * map_pitch + x].ToString());
							map.data[x, y].ix_obj0 = data;
						}
					break;

				case RM_MAP_LAYER_OBJECT:
					for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int data = Convert.ToInt32(json_map["data"][layer * map_size + y * map_pitch + x].ToString());
							map.data[x, y].ix_obj1 = data;
						}
					break;

				case RM_MAP_LAYER_SHADOW:
					for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int data = Convert.ToInt32(json_map["data"][layer * map_size + y * map_pitch + x].ToString());
							map.data[x, y].shadow = data;
						}
					break;

				case RM_MAP_LAYER_EVENT:
					for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int data = Convert.ToInt32(json_map["data"][layer * map_size + y * map_pitch + x].ToString());
							map.data[x, y].ix_event = (data > 0) ? (EVENT_BIT.TYPE_EVENT | data) : EVENT_BIT.NONE;
						}
					break;

				}
			}

			var event_list = json_map["events"];
			if (event_list != null)
			{
				for (int i = 0; i < event_list.Count; i++)
				{
					var event_ = event_list[i];
					if (event_ == null)
						continue;

					// "id", "name", "note", "x", "y"
					int x = Convert.ToInt32(event_["x"].ToString());
					int y = Convert.ToInt32(event_["y"].ToString());
					int _id = Convert.ToInt32(event_["id"].ToString()); // 'id' not used
					string name = event_["name"].ToString();
					string note = event_["note"].ToString();

					int event_type = EVENT_BIT.TYPE_NONE;
					int event_id;
					{
						// "TALK001" ->
						// [0] ""
						// [1] "TALK"
						// [2] ""
						// [3] "001"
						// [4] ""
						string pattern = @"(^[a-zA-Z]+|[0-9]+$)";
						string[] result = Regex.Split(name, pattern);

						string event_name = result[1];

						if (event_name == "TALK")
							event_type = EVENT_BIT.TYPE_TALK;
						else if (event_name == "SIGN")
							event_type = EVENT_BIT.TYPE_SIGN;
						else if (event_name == "ENTER")
							event_type = EVENT_BIT.TYPE_ENTER;
						else if (event_name == "EVENT")
							event_type = EVENT_BIT.TYPE_EVENT;
						else
							Debug.Assert(false);

						event_id = Convert.ToInt32(result[3]);
					}

					Debug.Log(name + ": " + note);
					System.Diagnostics.Debug.WriteLine(name + ": " + note);

					var pages = event_["pages"];
					if (pages.Count > 0)
					{
						TalkDesc talk_desc;

						talk_desc.x = x;
						talk_desc.y = y;
						talk_desc.name = name;
						talk_desc.note = note;
						talk_desc.dialog = new List<string>();

						var page_ = pages[0];
						var lists = page_["list"];
						/*
						"list":
						[
							{"code":101,"indent":0,"parameters":["",0,1,0]},
							{"code":401,"indent":0,"parameters":["DIALOG"]},
							{"code":0,"indent":0,"parameters":[]}
						],

						멀티 라인
						"list":
						[
							{"code":101,"indent":0,"parameters":["",0,1,1]},
							{"code":401,"indent":0,"parameters":["푯말도 스크립트로 가능하다."]},
							{"code":401,"indent":0,"parameters":["두 번째 줄"]},
							{"code":401,"indent":0,"parameters":[""]},
							{"code":401,"indent":0,"parameters":["4번째 줄"]},
							{"code":0,"indent":0,"parameters":[]}
						],
						*/
						for (int ix_list = 0; ix_list < lists.Count; ++ix_list)
						{
							var list_ = lists[ix_list];
							int code = Convert.ToInt32(list_["code"].ToString());

							if (code != 401)
								continue;

							var parameters = list_["parameters"];

							for (int ix_param = 0; ix_param < parameters.Count; ++ix_param)
							{
								if (parameters[ix_param].IsString)
								{
									string dialog = parameters[ix_param].ToString();
									talk_desc.dialog.Add(dialog);
									//System.Diagnostics.Debug.WriteLine();
								}
							}
						}

						if (talk_desc.dialog.Count > 0)
						{
							if (event_type == EVENT_BIT.TYPE_TALK)
								map.talks.Add(event_id, talk_desc);
							else if (event_type == EVENT_BIT.TYPE_SIGN)
								map.signs.Add(event_id, talk_desc);
							else if (event_type == EVENT_BIT.TYPE_ENTER)
								map.enters.Add(event_id, talk_desc);
							else if (event_type == EVENT_BIT.TYPE_EVENT)
							{
								string s = "";
								for (int ix = 0; ix < talk_desc.dialog.Count; ix++)
								{
									s += (ix > 0) ? "\n" : "";
									s += talk_desc.dialog[ix];
								}
								map.events.Add(event_id, s);
							}
							else
								Debug.Assert(false);
						}
					}

					map.data[x, y].ix_event = event_type | event_id;

					// TODO2: ??
					// map.events[event_number] = name;
				}
			}

			ref_map = map;

			return true;
		}

		// 원작의 바이너리 형태의 Lore map을 여는 함수
		public static bool LoadMapFromOldFormat(string map_name, ref MapData map)
		{
			bool isMapVersionM = false;

			TextAsset bin = Resources.Load("Bin/" + map_name + "_MAP") as TextAsset;

			if (bin == null)
			{
				bin = Resources.Load("Bin/" + map_name + "_M") as TextAsset;

				if (bin == null)
					return false;

				isMapVersionM = true;
			}

			Stream s = new MemoryStream(bin.bytes);
			BinaryReader br = new BinaryReader(s);

			if (br == null)
				return false;

			byte map_size_w = 0;
			byte map_size_h = 0;

			if (isMapVersionM)
			{
				/*
					Map_Header_Type = record
						[ 0] ID : string[10];
						[11] xmax, ymax : byte;
						[13] tile_type : PositionType = (town,ground,den,keep);
						[14] encounter, handicap : boolean;
						[16] start_x, start_y : byte;
						[18] exitmap : string[10];
						[29] exit_x, exit_y : byte;
						[31] entermap : string[10];
						[42] enter_x, enter_y, default, handicap_bit : byte;
						[46] unused : string[49];
						[96]
					end;
				 */

				byte[] buffer = new byte[96];
				int read = br.Read(buffer, 0, buffer.Length);
				Debug.Assert(read == buffer.Length);

				map_size_w = buffer[11];
				map_size_h = buffer[12];
			}
			else
			{
				map_size_w = br.ReadByte();
				map_size_h = br.ReadByte();
			}

			map.map_name = map_name;
			map.file_name = map_name;
			map.size.w = map_size_w;
			map.size.h = map_size_h;

			map.data = new MapUnit[map_size_w, map_size_h];

			// shadowing is default
			for (int w = 0; w < map.size.w; w++)
				for (int h = 0; h < map.size.h; h++)
					map.data[w, h].shadow = 0x0F;

			int ix_convert = 0;

			switch (CONFIG.TILE_SET_CURRENT)
			{
				case TILE_SET.TOWN:
					ix_convert = 0;
					break;
				case TILE_SET.GROUND:
					ix_convert = 1;
					break;
				case TILE_SET.DEN:
					ix_convert = 2;
					break;
				case TILE_SET.KEEP:
					Debug.Assert(false);
					break;
			}

			int[,,] MAP_CONV_TABLE = new int[3, 55, 2]
			{
				// TOWN
				{
					{68, 0 },
					{ 8, 9 },
					{ 4,10 },
					{ 8,11 },
					{ 8,12 },
					{82, 0 },
					{83, 0 },
					{84, 0 },
					{88, 0 },
					{89, 0 },

					{90, 0 },
					{91, 0 },
					{ 8, 5 },
					{ 8, 6 },
					{10, 7 },
					{10, 8 },
					{81, 0 },
					{ 1, 3 },
					{ 0, 4 },
					{10, 0 },

					{14, 1 },
					{14, 2 },
					{64, 0 },
					{ 0,112},
					{56, 0 },
					{61, 0 },
					{63, 0 },
					{ 9, 0 },
					{ 2, 0 },
					{ 3, 0 },

					{10, 0 },
					{11, 0 },
					{16, 0 },
					{ 7, 0 },
					{ 5, 0 },
					{14, 0 },
					{ 6, 0 },
					{15, 0 },
					{13, 0 },
					{21, 0 },

					{23, 0 },
					{22, 0 },
					{20, 0 },
					{12, 0 },
					{ 8, 0 },
					{ 1, 0 },
					{ 4, 0 },
					{ 0, 0 },
					{14,128},
					{ 0,129},

					{ 0,130},
					{10,131},
					{ 8,132},
					{ 8,133},
					{20,134}
				},
				// GROUND
				{
					{68, 0 },
					{58, 0 },
					{ 4,10 },
					{26,10 },
					{87, 0 },
					{81, 0 },
					{ 0, 4 },
					{ 0,106},
					{ 0,107},
					{ 0,108},

					{ 0,109},
					{ 0,110},
					{ 0,111},
					{68, 0 },
					{68, 0 },
					{68, 0 },
					{68, 0 },
					{68, 0 },
					{68, 0 },
					{68, 0 },

					{ 0, 0 },
					{85, 0 },
					{ 0,112},
					{61, 0 },
					{48, 0 },
					{49, 0 },
					{50, 0 },
					{51, 0 },
					{52, 0 },
					{53, 0 },

					{54, 0 },
					{55, 0 },
					{39, 0 },
					{40, 0 },
					{41, 0 },
					{42, 0 },
					{43, 0 },
					{44, 0 },
					{45, 0 },
					{46, 0 },

					{47, 0 },
					{27, 0 },
					{28, 0 },
					{24, 0 },
					{25, 0 },
					{ 3, 0 },
					{26, 0 },
					{ 4, 0 },
					{56, 0 },
					{61, 0 },

					{63, 0 },
					{86, 0 },
					{64, 0 },
					{ 4,126},
					{ 0,126}
				},
				// DEN
				{
					{ 68, 0 },
					{125, 0 },
					{111, 0 },
					{109, 0 },
					{118, 0 },
					{102, 0 },
					{116, 0 },
					{100, 0 },
					{126, 0 },
					{124, 0 },

					{119, 0 },
					{103, 0 },
					{108, 0 },
					{117, 0 },
					{110, 0 },
					{101, 0 },
					{ 93, 0 },
					{114, 0 },
					{ 98, 0 },
					{112, 0 },

					{ 68, 0 },
					{ 68, 0 },
					{ 96, 0 },
					{104, 0 },
					{113, 0 },
					{106, 0 },
					{ 97, 0 },
					{107, 0 },
					{121, 0 },
					{127, 0 },

					{123, 0 },
					{105, 0 },
					{115, 0 },
					{120, 0 },
					{ 99, 0 },
					{122, 0 },
					{ 81, 0 },
					{ 82, 0 },
					{ 83, 0 },
					{ 84, 0 },

					{ 87, 0 },
					{ 14, 0 },
					{ 17, 0 },
					{ 27, 0 },
					{ 24, 0 },
					{ 26, 0 },
					{  2, 0 },
					{  3, 0 },
					{ 56, 0 },
					{ 61, 0 },

					{ 63, 0 },
					{ 86, 0 },
					{ 24, 0 },
					{ 24,112},
					{ 64, 0 }
				}
			};

			for (int y = 0; y < map_size_h - 1; y++)
			{
				for (int x = 0; x < map_size_w; x++)
				{
					byte map_data = br.ReadByte();

					var index = (map_data & 0x3F);

					if (index < 0)
						index = 0;

					if (index >= 55)
						index = 54;

					if (index > 0)
					{
						map.data[x, y].ix_tile = MAP_CONV_TABLE[ix_convert, index, 0];
						map.data[x, y].ix_obj1 = MAP_CONV_TABLE[ix_convert, index, 1];
						map.data[x, y].ix_event = EVENT_BIT.NONE;
						map.data[x, y].act_type = ACT_TYPE.DEFAULT;
					}
					else
					{
						index = CONFIG.TILE_BG_DEFAULT;

						map.data[x, y].ix_tile = MAP_CONV_TABLE[ix_convert, index, 0];
						map.data[x, y].ix_obj1 = MAP_CONV_TABLE[ix_convert, index, 1];
						map.data[x, y].ix_event = EVENT_BIT.NONE;
						map.data[x, y].act_type = ACT_TYPE.EVENT;
					}
				}
			}

			Debug.Log("GameRes.LoadMap() succeeded [" + map_size_w + "x" + map_size_h + "]");

			br.Close();
			s.Close();

			return true;
		}


		/*
			{
				"width":21,
				"height":21,
				"data":
				[
					1641,1641, ..... ,0,0,0,0
				],
			}		  
		 */

		private enum MV_LAYER
		{
			TILE_0 = 0,
			TILE_1,
			OBJECT_0,
			OBJECT_1,
			SHADOW,
			EVENT,
			MAX
		};

		public static bool SaveMap(MapData map, string map_name)
		{
			int map_size = map.size.w * map.size.h;
			string data = "";

			for (int layer = 0; layer < (int)MV_LAYER.MAX; layer++)
			{
				int offset = layer * map_size;
				int pitch = map.size.w;

				switch ((MV_LAYER)layer)
				{
					case MV_LAYER.TILE_0:
						for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int tile = (map.data[x, y].ix_tile + 0x600);
							data += (tile.ToString() + ",");
						}
						break;
					case MV_LAYER.TILE_1:
						for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
							data += "0,";
						break;
					case MV_LAYER.OBJECT_0:
						for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int obj = map.data[x, y].ix_obj0;
							data += (obj.ToString() + ",");
						}
						break;
					case MV_LAYER.OBJECT_1:
						for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
						{
							int obj = map.data[x, y].ix_obj1;
							data += (obj.ToString() + ",");
						}
						break;
					case MV_LAYER.SHADOW:
						for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
							data += "15,";
						break;
					case MV_LAYER.EVENT:
						for (int y = 0; y < map.size.h; y++)
						for (int x = 0; x < map.size.w; x++)
							data += "0,";
						break;
					default:
						break;
				}
			}

			/*
				{
					"autoplayBgm":false,
					"autoplayBgs":false,
					"battleback1Name":"",
					"battleback2Name":"",
					"bgm":{"name":"","pan":0,"pitch":100,"volume":90},
					"bgs":{"name":"","pan":0,"pitch":100,"volume":90},
					"disableDashing":false,
					"displayName":"작은맵",
					"encounterList":[],
					"encounterStep":30,
					"height":{1},
					"note":"",
					"parallaxLoopX":false,
					"parallaxLoopY":false,
					"parallaxName":"",
					"parallaxShow":true,
					"parallaxSx":0,
					"parallaxSy":0,
					"scrollType":0,
					"specifyBattleback":false,
					"tilesetId":7,
					"width":{0},
			*/

			/*
			string complete_str_format =
				"{"
				+ "	\"width\":{0},"
				+ "	\"height\":{1},"
				+ "	\"data\":[{2}]"
				+ "}";

			string complete_str = String.Format(complete_str_format, map.size.w, map.size.h, data);
			*/

			{
				System.IO.StreamWriter file = new System.IO.StreamWriter(map_name);
				file.WriteLine(data);
				file.Close();
			}

			return true;
		}

		public static void FillMapWithShadow(ref MapData map)
		{
			for (int y = 0; y < map.size.h; y++)
				for (int x = 0; x < map.size.w; x++)
					map.data[x, y].shadow = 15;
		}

		public static void FillMapWithLight(ref MapData map)
		{
			for (int y = 0; y < map.size.h; y++)
				for (int x = 0; x < map.size.w; x++)
					map.data[x, y].shadow = 0;
		}

		public static void ClearMapEvent(ref MapData map, int id)
		{
			for (int y = 0; y < map.size.h; y++)
				for (int x = 0; x < map.size.w; x++)
					if ((GameRes.map_data[x, y].ix_event & EVENT_BIT.MASK_OF_TYPE) == EVENT_BIT.TYPE_EVENT)
						if ((GameRes.map_data[x, y].ix_event & EVENT_BIT.MASK_OF_INDEX) == id)
							GameRes.map_data.data[x, y].ix_event = 0;
		}
	}
}
