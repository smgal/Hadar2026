using UnityEngine;
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;

namespace Yunjr
{
	public delegate void FnCallBack0();
	public delegate void FnCallBack1_i(int index);

	public static class LAUNCHING_PARAM
	{
		public enum TYPE
		{
			NEW_GAME_PROLOG,
			NEW_GAME_MAIN,
			NEW_GAME_MAIN_IN_EDITOR,
			CONTINUE
		}

		//public static TYPE type = TYPE.NEW_GAME_MAIN_IN_EDITOR;
		public static TYPE type = TYPE.CONTINUE;
		public static int continue_index = 0;

		public static PlayerParams param = new PlayerParams();
	}

	public enum GAMEOVER_CONDITION
	{
		NONE,
		EXIT_REQUIRED,
		DEAD_ON_FIELD,
		DEAD_ON_BATTLE,

		// intermediate states
		DEAD_ON_FIELD_LOAD,

		// GAME_CLEARED,
		PROLOG_CLEARED
	}

	[Serializable]
	public enum ACT_TYPE
	{
		BLOCK = 0,
		MOVE,
		WATER,
		SWAMP,
		LAVA,
		CLIFF,
		ENTER,
		SIGN,
		TALK,
		EVENT,
		POST_EVENT,
		DEFAULT,
		MAX,
	}

	public enum TILE_SET
	{
		TOWN,
		KEEP,
		GROUND,
		DEN
	}

	/*
	 * IN_MOVING -> IN_WAITING_FOR_KEYPRESS -> JUST_KEYPRESSED
	 *           -> IN_PICKING_SENTENCE -> JUST_PICKED
	 *           -> IN_SELECTING_MENU -> JUST_SELECTED
	 *           -> IN_SELECTING_SPIN -> JUST_SELECTED_FOR_SPIN
	 */

	public enum GAME_STATE
	{
		ON_MOVING, ON_MOVING_STEP,
		IN_MOVING,
		IN_WAITING_FOR_OK_CANCEL, JUST_OK_PRESSED, JUST_CANCEL_PRESSED,
		IN_WAITING_FOR_KEYPRESS, JUST_KEYPRESSED,
		IN_WAITING_FOR_KEYPRESS_EX, JUST_KEYPRESSED_EX,
		IN_PICKING_SENTENCE, JUST_PICKED,
		IN_SELECTING_MENU, JUST_SELECTED,
		IN_SELECTING_SPIN, JUST_SELECTED_FOR_SPIN,
		ON_BATTLE,
		IN_BATTLE, JUST_BATTLE_COMMAND_SELECTED,
		OUT_BATTLE,
	}

	public sealed class ATTIBUTE_BIT
	{
		public const int JUMPABLE = 1;
		public const int TELEPORTABLE = 2;
	}

	public class SpriteData
	{
		public Sprite tile_image;
		public ACT_TYPE act_type;
		public uint attribute;
		/*
		public SpriteData()
		{
			tile_image = new Sprite();
			act_type = ACT_TYPE.MOVE;
			attribute = 0;
		}
		*/
		public SpriteData(Sprite image)
		{
			tile_image = image;
			act_type = ACT_TYPE.MOVE;
			attribute = 0;
		}

		public void SetAttrib(int shift)
		{
			Debug.Assert(shift >= 0 && shift < 32);

			attribute |= (1U << shift);
		}

		public bool HasAttrib(int shift)
		{
			Debug.Assert(shift >= 0 && shift < 32);

			if (shift == ATTIBUTE_BIT.JUMPABLE)
				return (act_type == ACT_TYPE.EVENT || act_type == ACT_TYPE.MOVE);
			if (shift == ATTIBUTE_BIT.TELEPORTABLE)
				return (act_type == ACT_TYPE.MOVE);

			return (attribute & (1 << shift)) > 0;
		}
	}

	[Serializable]
	public struct Size<T>
	{
		public T w;
		public T h;
	}

	public class GameRes: MonoBehaviour
	{
		// 
		private static GAME_STATE _game_state = GAME_STATE.IN_MOVING;
		public static GAME_STATE GameState
		{
			get { return _game_state; }
			set { _game_state = value; }
		}

		private static GAMEOVER_CONDITION _gameover_condition = GAMEOVER_CONDITION.NONE;
		public static GAMEOVER_CONDITION GameOverCondition
		{
			get { return _gameover_condition; }
			set { _gameover_condition = value; }
		}

		private static int _post_event_id = 0;
		public static int PostEventId
		{
			get { return _post_event_id; }
			set { _post_event_id = value; }
		}

		// image resource (obsolete)
		public static List<SpriteData> sprite_bundle;
		public static int ix_sprite_bundle_tile = -1;
		public static int ix_sprite_bundle_sprite = 0;

		// image resource
		public static List<SpriteData> sprite_bundle_ex;
		public static int ix_sprite_bundle_ex_tile = -1;
		public static int ix_sprite_bundle_ex_object = 0;
		public static int ix_sprite_bundle_ex_sprite = 0;

		public static Dictionary<uint, Yunjr.Item> item_table = new Dictionary<uint, Yunjr.Item>();

		public static SelectionFromList selection_list = null;
		public static SelectionFromSpin selection_spin = null;

		// event
		//public delegate void FnCallBack0();

		public static FnCallBack0 _fn_ok_pressed = null;
		public static FnCallBack0 _fn_cancel_pressed = null;

		// serialized (system save)
		// TODO: system save의 메모리를 할당하고 별도의 파일로 만들어야 한다.
		// 시스템 세이브의 기록 내용은 항상 save/load 되고 있어야 한다.
		// 주로 게임 플레이 기록 정보를 담는다.
		public static byte[] system_save = null;

		// serialized
		public static uint VERSION = CONFIG.SAVE_FILE_VERSION;
		public static uint SAVE_HEADER_SKIP_BYTES = 244;
		public static YunjrMap map_script = null;
		public static MapData map_data = new MapData();

		public static Yunjr.ObjParty party = new Yunjr.ObjParty();
		public static Yunjr.ObjPlayer[] player = new Yunjr.ObjPlayer[CONFIG.MAX_PLAYER];
		public static Yunjr.ObjEnemy[] enemy = new Yunjr.ObjEnemy[CONFIG.MAX_ENEMY];
		public static List<Yunjr.ObjPlayer> retired = new List<Yunjr.ObjPlayer>();

		public static Flag flag = new Flag(CONFIG.MAX_FLAG);
		public static Variable variable = new Variable(CONFIG.MAX_VARIABLE);

		void Awake()
		{
			Application.targetFrameRate = CONFIG.TARGET_FRAME_RATE;

			// CONFIG.GUI_SCALE 판별
			{
				const double BASE_W = 720.0;
				const double BASE_H = 1280.0;

				CONFIG.GUI_SCALE = (float)((BASE_H * Screen.width) / (BASE_W * Screen.height));
				CONFIG.GUI_SCALE = (CONFIG.GUI_SCALE <= 1.0f) ? CONFIG.GUI_SCALE : 1.0f;
			}

			Environment.SetEnvironmentVariable("MONO_REFLECTION_SERIALIZER", "yes");

			GameRes.GameState = GAME_STATE.IN_MOVING;
			GameRes.GameOverCondition = GAMEOVER_CONDITION.NONE;
			GameRes.PostEventId = 0;

			// GameRes.DeleteSaveGame(0);

			Debug.Log("GameRes::Start()");

			Yunjr.ObjItem.LoadItemList(out item_table); // ex> LoadItemListFromJson(out item_table);

			sprite_bundle_ex = new List<SpriteData>();
			{
				// tiles
				ix_sprite_bundle_ex_tile = sprite_bundle_ex.Count;
				{
					Sprite[] sprites = Resources.LoadAll<Sprite>("Lore_A5");
					if (sprites != null)
					{
						foreach (var sprite in sprites)
							sprite_bundle_ex.Add(new SpriteData(sprite));
					}
					else
						Debug.Log("Resources.LoadAll(\"lore_tile\") failed");
				}
				Debug.Log("Num of tiles: " + sprite_bundle_ex.Count);

				// objects
				ix_sprite_bundle_ex_object = sprite_bundle_ex.Count;
				{
					//?? magic number
					const float HALF_WIDTH = 384.0f;

					Sprite[] sprites = Resources.LoadAll<Sprite>("Lore_B");
					if (sprites != null)
					{
						foreach (var sprite in sprites)
							if (sprite.rect.x < HALF_WIDTH) 
								sprite_bundle_ex.Add(new SpriteData(sprite));

						foreach (var sprite in sprites)
							if (sprite.rect.x >= HALF_WIDTH)
								sprite_bundle_ex.Add(new SpriteData(sprite));
					}
					else
						Debug.Log("Resources.LoadAll(\"lore_tile\") failed");
				}
				Debug.Log("Num of objects: " + sprite_bundle_ex.Count);

				// sprites - magic key
				ix_sprite_bundle_ex_sprite = ix_sprite_bundle_ex_object + 192;

				int offset = 0;

				for (int i = 0; i < ix_sprite_bundle_ex_object; i++)
				{
					if      (i <  56) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.MOVE;
					else if (i <  60) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.WATER;
					else if (i <  62) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.SWAMP;
					else if (i <  64) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.LAVA;
					else if (i <  70) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.ENTER;
					else if (i <  72) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.CLIFF;
					else if (i < 128) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.BLOCK;
					else              sprite_bundle_ex[offset + i].act_type = ACT_TYPE.MOVE;
				}

				offset += ix_sprite_bundle_ex_object;
				for (int i = 0; i < (sprite_bundle_ex.Count - ix_sprite_bundle_ex_object); i++)
				{
					if      (i <=  0) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.MOVE;
					else if (i <  64) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.BLOCK;
					else if (i <  88) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.MOVE;
					else if (i <  96) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.MOVE; // 88 ~ 95 Animation object
					else if (i < 112) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.BLOCK;
					else if (i < 124) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.SIGN;
					else if (i < 128) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.ENTER;
					else if (i < 144) sprite_bundle_ex[offset + i].act_type = ACT_TYPE.TALK;
					else              sprite_bundle_ex[offset + i].act_type = ACT_TYPE.MOVE;
				}
			}

			sprite_bundle = new List<SpriteData>();
			{
				// tiles
				ix_sprite_bundle_tile = sprite_bundle.Count;
				{
					Sprite[] sprites = Resources.LoadAll<Sprite>("lore_tile");
					if (sprites != null)
					{
						foreach (var sprite in sprites)
							sprite_bundle.Add(new SpriteData(sprite));
					}
					else
						Debug.Log("Resources.LoadAll(\"lore_tile\") failed");
				}
				Debug.Log("Num of tiles: " + sprite_bundle.Count);

				// sprites
				ix_sprite_bundle_sprite = sprite_bundle.Count;
				{
					Sprite[] sprites = Resources.LoadAll<Sprite>("lore_sprite");
					if (sprites != null)
					{
						foreach (var sprite in sprites)
							sprite_bundle.Add(new SpriteData(sprite));
					}
					else
						Debug.Log("Resources.LoadAll(\"lore_tile\") failed");
				}
				Debug.Log("Num of sprites: " + sprite_bundle.Count);

				{
					int offset = 0;

					// TOWN
					for (int i = 0; i < CONFIG.MAX_MAP_TILE; i++)
					{
						if (i <= 0) sprite_bundle[offset + i].act_type = ACT_TYPE.EVENT;
						else if (i <= 21) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 22) sprite_bundle[offset + i].act_type = ACT_TYPE.ENTER;
						else if (i <= 23) sprite_bundle[offset + i].act_type = ACT_TYPE.SIGN;
						else if (i <= 24) sprite_bundle[offset + i].act_type = ACT_TYPE.WATER;
						else if (i <= 25) sprite_bundle[offset + i].act_type = ACT_TYPE.SWAMP;
						else if (i <= 26) sprite_bundle[offset + i].act_type = ACT_TYPE.LAVA;
						else if (i <= 47) sprite_bundle[offset + i].act_type = ACT_TYPE.MOVE;
						else if (i < CONFIG.MAX_MAP_TILE) sprite_bundle[offset + i].act_type = ACT_TYPE.TALK;
					}
					offset += CONFIG.MAX_MAP_TILE;

					// KEEP
					for (int i = 0; i < CONFIG.MAX_MAP_TILE; i++)
					{
						if (i <= 0) sprite_bundle[offset + i].act_type = ACT_TYPE.EVENT;
						else if (i <= 39) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 47) sprite_bundle[offset + i].act_type = ACT_TYPE.MOVE;
						else if (i <= 48) sprite_bundle[offset + i].act_type = ACT_TYPE.WATER;
						else if (i <= 49) sprite_bundle[offset + i].act_type = ACT_TYPE.SWAMP;
						else if (i <= 50) sprite_bundle[offset + i].act_type = ACT_TYPE.LAVA;
						else if (i <= 51) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 52) sprite_bundle[offset + i].act_type = ACT_TYPE.EVENT;
						else if (i <= 53) sprite_bundle[offset + i].act_type = ACT_TYPE.SIGN;
						else if (i <= 54) sprite_bundle[offset + i].act_type = ACT_TYPE.ENTER;
						else if (i < CONFIG.MAX_MAP_TILE) sprite_bundle[offset + i].act_type = ACT_TYPE.TALK;
					}
					offset += CONFIG.MAX_MAP_TILE;

					// GROUND
					for (int i = 0; i < CONFIG.MAX_MAP_TILE; i++)
					{
						if (i <= 0) sprite_bundle[offset + i].act_type = ACT_TYPE.EVENT;
						else if (i <= 21) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 22) sprite_bundle[offset + i].act_type = ACT_TYPE.SIGN;
						else if (i <= 23) sprite_bundle[offset + i].act_type = ACT_TYPE.SWAMP;
						else if (i <= 47) sprite_bundle[offset + i].act_type = ACT_TYPE.MOVE;
						else if (i <= 48) sprite_bundle[offset + i].act_type = ACT_TYPE.WATER;
						else if (i <= 49) sprite_bundle[offset + i].act_type = ACT_TYPE.SWAMP;
						else if (i <= 50) sprite_bundle[offset + i].act_type = ACT_TYPE.LAVA;
						else if (i < CONFIG.MAX_MAP_TILE) sprite_bundle[offset + i].act_type = ACT_TYPE.ENTER;
					}
					offset += CONFIG.MAX_MAP_TILE;

					// DEN
					for (int i = 0; i < CONFIG.MAX_MAP_TILE; i++)
					{
						if (i <= 0) sprite_bundle[offset + i].act_type = ACT_TYPE.EVENT;
						else if (i <= 20) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 21) sprite_bundle[offset + i].act_type = ACT_TYPE.TALK;
						else if (i <= 40) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 47) sprite_bundle[offset + i].act_type = ACT_TYPE.MOVE;
						else if (i <= 48) sprite_bundle[offset + i].act_type = ACT_TYPE.WATER;
						else if (i <= 49) sprite_bundle[offset + i].act_type = ACT_TYPE.SWAMP;
						else if (i <= 50) sprite_bundle[offset + i].act_type = ACT_TYPE.LAVA;
						else if (i <= 51) sprite_bundle[offset + i].act_type = ACT_TYPE.BLOCK;
						else if (i <= 52) sprite_bundle[offset + i].act_type = ACT_TYPE.EVENT;
						else if (i <= 53) sprite_bundle[offset + i].act_type = ACT_TYPE.SIGN;
						else if (i <= 54) sprite_bundle[offset + i].act_type = ACT_TYPE.ENTER;
						else if (i < CONFIG.MAX_MAP_TILE) sprite_bundle[offset + i].act_type = ACT_TYPE.TALK;
					}
					offset += CONFIG.MAX_MAP_TILE;
				}
			}

			selection_list = new SelectionFromList();
			selection_spin = new SelectionFromSpin();

			for (int i = 0; i < player.Length; i++)
				player[i] = new Yunjr.ObjPlayer();

			for (int i = 0; i < enemy.Length; i++)
				enemy[i] = new Yunjr.ObjEnemy(i);

			switch (Yunjr.LAUNCHING_PARAM.type)
			{
			case LAUNCHING_PARAM.TYPE.NEW_GAME_PROLOG:
				{
					if (!GameRes.LoadMapEx("Prolog_B1"))
						GameRes.CreateMapEx("ORIGIN", 50, 50);

					GameRes.retired.Clear();

					// TODO: Set Mercury's original status
					const int LEVEL = 5;
					PlayerParams mercury = new PlayerParams("머큐리", GENDER.MALE, CLASS.ASSASSIN, LEVEL);

					player[0] = ObjPlayer.CreateCharacter(mercury, LEVEL);
					// 공중 부상
					player[0].specially_allowed_magic = 0x00000004;

					player[0].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 1));
					player[0].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(0));
					player[0].SetEquipment(Yunjr.EQUIP.HEAD, Yunjr.ResId.CreateResId_Head(1));
					player[0].SetEquipment(Yunjr.EQUIP.LEG, Yunjr.ResId.CreateResId_Leg(2));

					player[0].Apply();

					// HP 80%, SP 50% 로 시작
					player[0].hp = player[0].hp * 8 / 10;
					player[0].sp = player[0].sp * 5 / 10;

					// Party init
					party.core.year -= 1;
					party.core.day = 4;
					party.core.hour = 2;

					party.core.food = 10;
					party.core.gold = 1000;

					// 첫 세이브
					MainMenuSave.SaveFile(0);
				}
				break;

			case LAUNCHING_PARAM.TYPE.NEW_GAME_MAIN:
			OOPS:
				{
					// Reset party
					party = new Yunjr.ObjParty();

					if (Yunjr.LAUNCHING_PARAM.type == LAUNCHING_PARAM.TYPE.NEW_GAME_MAIN_IN_EDITOR)
					{
						if (!GameRes.LoadMapEx("CastleLore"))
							GameRes.CreateMapEx("ORIGIN", 50, 50);
					}
					else
					{
						if (!GameRes.LoadMapEx("CastleLore"))
							GameRes.CreateMapEx("ORIGIN", 50, 50);
					}

					GameRes.retired.Clear();

					if (LAUNCHING_PARAM.param.clazz != CLASS.UNKNOWN)
					{
						// register a user-defined character
						ObjPlayer new_player = ObjPlayer.CreateCharacter(LAUNCHING_PARAM.param, 1);

						new_player.SetEquipment(Yunjr.EQUIP.HEAD, Yunjr.ResId.CreateResId_Head(1));
						// TODO2: Give somthing special ornament for a user character
						new_player.SetEquipment(Yunjr.EQUIP.ETC, Yunjr.ResId.CreateResId_Ornament(1));
						new_player.Apply();

						GameRes.retired.Add(new_player);
					}
					else
					{
						// Register a user-defined character from dummy
						ObjPlayer new_player = ObjPlayer.CreateCharacter("아무개", GENDER.MALE, CLASS.ESPER, 1);

						new_player.SetEquipment(Yunjr.EQUIP.HEAD, Yunjr.ResId.CreateResId_Head(1));
						new_player.SetEquipment(Yunjr.EQUIP.ETC, Yunjr.ResId.CreateResId_Ornament(1));
						new_player.Apply();

						GameRes.retired.Add(new_player);
					}

					// TODO: Set Mercury's original status
					const int LEVEL = 5;
					PlayerParams mercury = new PlayerParams("머큐리", GENDER.MALE, CLASS.ASSASSIN, LEVEL);

					player[0] = ObjPlayer.CreateCharacter(mercury, LEVEL);

					// 공중 부상
					player[0].specially_allowed_magic = 0x00000004;

					long EXP_100P = ObjPlayer.GetRequiredExp(LEVEL + 1) - ObjPlayer.GetRequiredExp(LEVEL);

					player[0].accumulated_exprience = ObjPlayer.GetRequiredExp(LEVEL + 1) + EXP_100P / 3;
					player[0].exprience = EXP_100P / 3;

					/* for test
					player[0].intrinsic_skill[(int)SKILL_TYPE.ENVIRONMENT] = 100;
					player[0].intrinsic_skill[(int)SKILL_TYPE.CURE] = 100;
					player[0].intrinsic_skill[(int)SKILL_TYPE.ESP] = 100;
					*/

					player[0].SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 1));
					//player[0].SetEquipment(Yunjr.EQUIP.HAND_SUB, Yunjr.ResId.CreateResId_Shield(1));
					player[0].SetEquipment(Yunjr.EQUIP.ARMOR, Yunjr.ResId.CreateResId_Armor(0));
					player[0].SetEquipment(Yunjr.EQUIP.HEAD, Yunjr.ResId.CreateResId_Head(1));
					player[0].SetEquipment(Yunjr.EQUIP.LEG, Yunjr.ResId.CreateResId_Leg(2));
					//player[0].SetEquipment(Yunjr.EQUIP.ETC, Yunjr.ResId.CreateResId_Ornament(1));

					player[0].Apply();

					// Party init
					party.SetDirection(0, -1);
					party.core.food = 56;
					party.core.gold = 11000;

					/*
					party.core.item[(int)PARTY_ITEM.BIG_TORCH] = 6;
					party.core.item[(int)PARTY_ITEM.SCROLL_SUMMON] = 5;
					party.core.item[(int)PARTY_ITEM.CRYSTAL_BALL] = 4;
					party.core.item[(int)PARTY_ITEM.WINGED_BOOTS] = 3;
					party.core.item[(int)PARTY_ITEM.TELEPORT_BALL] = 2;
					
					party.core.relic[(int)PARTY_RELIC.SHARD_OF_GOLD] = 1;
					*/

					party.core.identified_map[GameRes.map_script.Index] = 1;

					party.PutInBackpack(ResId.CreateResId_Head(1));

					party.PutInBackpack(ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 3));
					party.PutInBackpack(ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 4));
					party.PutInBackpack(ResId.CreateResId_Armor(3));
					party.PutInBackpack(ResId.CreateResId_Armor(4));
					party.PutInBackpack(ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 5));
					party.PutInBackpack(ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 6));
					party.PutInBackpack(ResId.CreateResId_Armor(5));
					party.PutInBackpack(ResId.CreateResId_Armor(1));
					party.PutInBackpack(ResId.CreateResId_Weapon((uint)ITEM_TYPE.WIELD, 1));

					party.PutInBackpack(ResId.CreateResId_Head(2));
					party.PutInBackpack(ResId.CreateResId_Leg(1));
					party.PutInBackpack(ResId.CreateResId_Leg(2));

					// 메인 세이브 교체
					if (Yunjr.LAUNCHING_PARAM.type  == LAUNCHING_PARAM.TYPE.NEW_GAME_MAIN)
						MainMenuSave.SaveFile(0);
				}
				break;

			case LAUNCHING_PARAM.TYPE.CONTINUE:
			case LAUNCHING_PARAM.TYPE.NEW_GAME_MAIN_IN_EDITOR:
				if (LoadGame(LAUNCHING_PARAM.continue_index))
				{
					;
				}
				else
				{
					Debug.Log("Save file loading failed (continued)");
					goto OOPS;
				}
				break;
			}
		}

		public static void CreateMapEx(string name, int map_size_w, int map_size_h)
		{
			LibMapEx.CreateMap(name, map_size_w, map_size_h, out GameRes.map_data);
			party.Warp(GameRes.map_data.size.w / 2, GameRes.map_data.size.h / 2);
		}

		// @@ Deprecated
		/*
		public static bool LoadMap(string map_name)
		{
			YunjrMap new_map_script = YunjrMap.CreateMapScript(map_name);

			if (new_map_script == null)
				return false;

			// set to default
			GameRes.ChangeTileSet(TILE_SET.TOWN);
			CONFIG.BGM = "";

			new_map_script.OnPrepare();

			Map new_map = new Map();
			if (!LibMap.LoadMap(map_name, ref new_map))
				return false;

			// map loaded successfully

			AudioManager audio_manager = AudioManager.m_instance;

			if (audio_manager != null)
				audio_manager.Stop();

			if (map_script != null)
				map_script.OnUnload();

			if (audio_manager != null)
				audio_manager.Play(CONFIG.BGM);

			string prev_map_name = map_ex.map_name;
			int prev_map_x = party.aux.latest_event_pos.x;
			int prev_map_y = party.aux.latest_event_pos.y;

			map_ex = new_map;
			map_script = new_map_script;

			// default position
			party.Warp(map_ex.size.w / 2, map_ex.size.h / 2);

			map_script.OnLoad(prev_map_name, prev_map_x, prev_map_y);

			{
				byte identifing_degree = GameRes.GetIdentifingDegreeOfCurrentMap();
				GameObj.SetHeaderText(map_script.GetPlaceName(identifing_degree));
			}

			return true;
		}
		*/

		public static bool LoadMapEx(string map_name)
		{
			string map_script_name = map_name;

			YunjrMap new_map_script = YunjrMap.CreateMapScript(map_script_name);

			if (new_map_script == null)
				return false;

			// set to default
			GameRes.ChangeTileSet(TILE_SET.TOWN);
			CONFIG.BGM = "";

			new_map_script.OnPrepare();

			MapData new_map_data = new MapData();
			if (!LibMapEx.LoadMap(map_name, new_map_script.FileName, ref new_map_data))
			{
				if (!LibMapEx.LoadMapFromOldFormat(new_map_script.FileName, ref new_map_data))
				{
					if (!LibMapEx.LoadMap(map_name, new_map_script.MapName, ref new_map_data))
					{
						Debug.LogError(String.Format("Map name '{0}->{1}' not found.", map_name, new_map_script.FileName));
						return false;
					}
				}
			}

			/* map loaded successfully */

			AudioManager audio_manager = AudioManager.m_instance;

			if (audio_manager != null)
				audio_manager.Stop();

			if (map_script != null)
				map_script.OnUnload();

			if (audio_manager != null)
				audio_manager.Play(CONFIG.BGM);

			string prev_map_name = GameRes.map_data.map_name;
			int prev_map_x = party.aux.latest_event_pos.x;
			int prev_map_y = party.aux.latest_event_pos.y;

			GameRes.map_data = new_map_data;
			map_script = new_map_script;

			// 초기화
			GameRes.party.core.gameover_condition = (int)GAMEOVER_COND.COMPLETELY_DEFEATED;

			// default position
			party.Warp(GameRes.map_data.size.w / 2, GameRes.map_data.size.h / 2);

			map_script.OnLoad(prev_map_name, prev_map_x, prev_map_y);

			{
				byte identifing_degree = GameRes.GetIdentifingDegreeOfCurrentMap();
				GameObj.SetHeaderText(map_script.GetPlaceName(identifing_degree));
			}
			
			return true;
		}

		public static void UnloadMapEx()
		{
			AudioManager audio_manager = AudioManager.m_instance;

			if (audio_manager != null)
				audio_manager.Stop();

			if (map_script != null)
			{
				map_script.OnUnload();
				map_script = null;
			}
		}

		public static bool SaveGameAsBin(string file_path)
		{
			using (FileStream file = new FileStream(file_path, FileMode.OpenOrCreate, FileAccess.ReadWrite))
			{
				BufferedStream bs = new BufferedStream(file);

				// File header
				{
					ushort version = (ushort)GameRes.VERSION;

					// <len>
					//   08    0x89 'L' 'E' 'P' '2' <high word> <low word> 0x00
					//   04    <skip bytes dword(LE)> -> 244
					//   F4    byte[244]
					bs.WriteByte(0x89);
					bs.WriteByte(Convert.ToByte('L')); // Lore EP2 save file tag
					bs.WriteByte(Convert.ToByte('E'));
					bs.WriteByte(Convert.ToByte('P'));
					bs.WriteByte(Convert.ToByte('2'));
					bs.WriteByte(Convert.ToByte((version >> 8) & 0xFF)); // Save file의 vesion
					bs.WriteByte(Convert.ToByte(version & 0xFF));
					bs.WriteByte(0x00);
				}

				// Skip bytes
				{
					bs.WriteByte(Convert.ToByte((GameRes.SAVE_HEADER_SKIP_BYTES >> 24) & 0xFF));
					bs.WriteByte(Convert.ToByte((GameRes.SAVE_HEADER_SKIP_BYTES >> 16) & 0xFF));
					bs.WriteByte(Convert.ToByte((GameRes.SAVE_HEADER_SKIP_BYTES >> 8) & 0xFF));
					bs.WriteByte(Convert.ToByte((GameRes.SAVE_HEADER_SKIP_BYTES) & 0xFF));
					{
						byte[] buffer = new byte[GameRes.SAVE_HEADER_SKIP_BYTES];
						bs.Write(buffer, 0, (int)GameRes.SAVE_HEADER_SKIP_BYTES);
					}
				}

				ISerialize.WriteString(bs, GameRes.map_script.MapName); // 현재 로드되어 있는 map scrip 이름

				party._Save(bs);

				for (int i = 0; i < GameRes.player.Length; i++)
				{
					if (GameRes.player[i] != null && GameRes.player[i].IsValid())
					{
						byte[] buffer = BitConverter.GetBytes(true);
						bs.Write(buffer, 0, buffer.Length);

						GameRes.player[i]._Save(bs);
					}
					else
					{
						byte[] buffer = BitConverter.GetBytes(false);
						bs.Write(buffer, 0, buffer.Length);
					}
				}

				{
					// Remove invalid characters
					{
					RETRY:
						for (int i = 0; i < GameRes.retired.Count; i++)
						{
							if (GameRes.retired[i] != null && !GameRes.retired[i].IsValid())
							{
								Debug.LogWarning(String.Format("Invalid character at GameRes.retired[{0}]", i));
								GameRes.retired.RemoveAt(i);
								goto RETRY;
							}
						}
					}

					int count = GameRes.retired.Count;

					byte[] buffer_for_count = BitConverter.GetBytes(GameRes.retired.Count);
					bs.Write(buffer_for_count, 0, buffer_for_count.Length);

					for (int i = 0; i < GameRes.retired.Count; i++)
						GameRes.retired[i]._Save(bs);
				}

				GameRes.flag._Save(bs);
				GameRes.variable._Save(bs);

				GameRes.map_data._Save(bs);

				bs.Close();
			}

			return true;
		}

		public static bool LoadGameAsBin(string file_path)
		{
			if (!File.Exists(file_path))
				return false;

			using (FileStream file = new FileStream(file_path, FileMode.Open, FileAccess.Read))
			{
				if (file.Length <= 8)
					return false;

				BufferedStream bs = new BufferedStream(file);

				/*
				// <len>
				//   08    0x89 'L' 'E' 'P' '2' <high word> <low word> 0x00
				//   04    <skip bytes dword(LE)> -> 244
				//   F4    byte[244]
				if (bs.ReadByte() != 0x89)
					return false;
				if (Convert.ToChar(bs.ReadByte()) != 'L')
					return false;
				if (Convert.ToChar(bs.ReadByte()) != 'E')
					return false;
				if (Convert.ToChar(bs.ReadByte()) != 'P')
					return false;
				if (Convert.ToChar(bs.ReadByte()) != '2')
					return false;

				int saved_version = ((bs.ReadByte()) << 8);
				saved_version |= bs.ReadByte();

				if (bs.ReadByte() != 0x00)
					return false;
				*/

				int saved_version;
				if (!VerifySaveFile(bs, out saved_version))
					return false;

				if (saved_version != (int)CONFIG.SAVE_FILE_VERSION)
					return false;

				// skip bytes
				{
					uint skip_bytes = 0;
					skip_bytes |= ((uint)bs.ReadByte() << 24);
					skip_bytes |= ((uint)bs.ReadByte() << 16);
					skip_bytes |= ((uint)bs.ReadByte() << 8);
					skip_bytes |= ((uint)bs.ReadByte() << 8);

					{
						byte[] buffer = new byte[GameRes.SAVE_HEADER_SKIP_BYTES];
						bs.Read(buffer, 0, (int)GameRes.SAVE_HEADER_SKIP_BYTES);
					}
				}

				// 현재 로딩된 맵을 바꿔치기 한다.
				string saved_map_name = ISerialize.ReadString(bs);
				{
					GameRes.UnloadMapEx();
					GameRes.LoadMapEx(saved_map_name);
				}

				party._Load(bs);

				for (int i = 0; i < GameRes.player.Length; i++)
				{
					byte[] buffer = new byte[sizeof(bool)];
					bs.Read(buffer, 0, sizeof(bool));
					bool exist = BitConverter.ToBoolean(buffer, 0);

					GameRes.player[i] = new ObjPlayer();
					if (exist)
						GameRes.player[i]._Load(bs);
				}

				{
					GameRes.retired.Clear();

					byte[] buffer = new byte[sizeof(int)];
					bs.Read(buffer, 0, sizeof(int));
					int count = BitConverter.ToInt32(buffer, 0);

					for (int i = 0; i < count; i++)
					{
						ObjPlayer player = new ObjPlayer();
						player._Load(bs);

						GameRes.retired.Add(player);
					}
				}

				GameRes.flag._Load(bs);
				GameRes.variable._Load(bs);

				GameRes.map_data._Load(bs);

				bs.Close();
			}

			// Update the direciton of character sprite
			GameRes.party.SetDirection(GameRes.party.faced.dx, GameRes.party.faced.dy);

			return true;
		}

		private static string _GetSaveFilePath(int index)
		{
			return Path.Combine(Application.persistentDataPath, "EP2_SAVEINFO_" + index + ".bin");
		}

		public static bool DoesSaveFileExist(int index)
		{
			return File.Exists(_GetSaveFilePath(index));
		}

		public static bool VerifySaveFile(BufferedStream bs, out int file_version)
		{
			file_version = -1;

			if (bs.Length <= 8)
				return false;

			// <len>
			//   08    0x89 'L' 'E' 'P' '2' <high word> <low word> 0x00
			//   04    <skip bytes dword(LE)> -> 244
			//   F4    byte[244]
			if (bs.ReadByte() != 0x89)
				return false;
			if (Convert.ToChar(bs.ReadByte()) != 'L')
				return false;
			if (Convert.ToChar(bs.ReadByte()) != 'E')
				return false;
			if (Convert.ToChar(bs.ReadByte()) != 'P')
				return false;
			if (Convert.ToChar(bs.ReadByte()) != '2')
				return false;

			int saved_version = ((bs.ReadByte()) << 8);
			saved_version |= bs.ReadByte();

			if (bs.ReadByte() != 0x00)
				return false;

			file_version = saved_version;
			return true;
		}

		public static int GetSaveFileVersion(int index)
		{
			string saved_file_path = _GetSaveFilePath(index);

			if (!File.Exists(saved_file_path))
				return -1;

			int file_version;

			using (FileStream file = new FileStream(saved_file_path, FileMode.Open, FileAccess.Read))
			{
				BufferedStream bs = new BufferedStream(file);

				VerifySaveFile(bs, out file_version);

				bs.Close();
			}

			return file_version;
		}

		public static bool DeleteSaveGame(int index)
		{
			if (!DoesSaveFileExist(index))
				return false;

			try
			{
				File.Delete(_GetSaveFilePath(index));
			}
			catch (Exception)
			{
				return false;
			}

			return true;
		}

		public static bool SaveGame(int index)
		{
			return GameRes.SaveGameAsBin(_GetSaveFilePath(index));
			/*
			IFormatter formatter = new BinaryFormatter();

			bool success = false;
			using (FileStream fs = new FileStream(_GetSaveFilePath(index), FileMode.Create, FileAccess.Write, FileShare.None))
			{
				try
				{
					// Save file의 vesion
					formatter.Serialize(fs, GameRes.VERSION);
					// 현재 로드되어 있는 map scrip 이름
					formatter.Serialize(fs, GameRes.map_script.Name);

					formatter.Serialize(fs, GameRes.party);

					for (int i = 0; i < GameRes.player.Length; i++)
						formatter.Serialize(fs, GameRes.player[i]);

					formatter.Serialize(fs, GameRes.map_data.data);
					formatter.Serialize(fs, GameRes.flag);
					formatter.Serialize(fs, GameRes.variable);
				}
				catch (Exception)
				{
					return false;
				}
				finally
				{
					fs.Close();
				}

				success = true;
			}

			return success;
			*/
		}

		public static bool LoadGame(int index)
		{
			string saved_file_path = _GetSaveFilePath(index);

			if (!File.Exists(saved_file_path))
				return false;

			return GameRes.LoadGameAsBin(saved_file_path);
			/*
			IFormatter formatter = new BinaryFormatter();

			using (FileStream fs = new FileStream(saved_file_path, FileMode.Open, FileAccess.Read, FileShare.None))
			{
				try
				{
					uint saved_version = 0;
					string saved_map_name;

					// Save file의 vesion
					saved_version = (formatter.Deserialize(fs) as uint?) ?? 0;

					if (saved_version != CONFIG.SAVE_FILE_VERSION)
						return false;

					// 현재 로드되어 있는 map scrip 이름
					saved_map_name = formatter.Deserialize(fs) as string;

					{
						// 현재 로딩된 맵을 바꿔치기 한다.
						GameRes.UnloadMapEx();
						GameRes.LoadMapEx(saved_map_name);
					}

					GameRes.party = formatter.Deserialize(fs) as Yunjr.ObjParty;

					for (int i = 0; i < GameRes.player.Length; i++)
						GameRes.player[i] = formatter.Deserialize(fs) as Yunjr.ObjPlayer;

					// 저장 당시의 맵의지도 데이터만 복구한다.
					GameRes.map_data.data = formatter.Deserialize(fs) as MapUnit[,];

					// 저장 당시의 플래그를 복구한다.
					GameRes.flag = formatter.Deserialize(fs) as Yunjr.Flag;
					GameRes.variable = formatter.Deserialize(fs) as Yunjr.Variable;
				}
				finally
				{
					fs.Close();
				}
			}

			return true;
			*/
		}

		public static void ChangeTileSet(TILE_SET tile_set)
		{
			CONFIG.TILE_SET_CURRENT = tile_set;

			switch (tile_set)
			{
			case TILE_SET.TOWN:
				GameRes.ix_sprite_bundle_tile = CONFIG.MAX_MAP_TILE * 0;
				CONFIG.TILE_BG_DEFAULT = CONFIG.TILE_BG_DEFAULT_TOWN;
				break;
			case TILE_SET.KEEP:
				GameRes.ix_sprite_bundle_tile = CONFIG.MAX_MAP_TILE * 1;
				CONFIG.TILE_BG_DEFAULT = CONFIG.TILE_BG_DEFAULT_KEEP;
				break;
			case TILE_SET.GROUND:
				GameRes.ix_sprite_bundle_tile = CONFIG.MAX_MAP_TILE * 2;
				CONFIG.TILE_BG_DEFAULT = CONFIG.TILE_BG_DEFAULT_GROUND;
				break;
			case TILE_SET.DEN:
				GameRes.ix_sprite_bundle_tile = CONFIG.MAX_MAP_TILE * 3;
				CONFIG.TILE_BG_DEFAULT = CONFIG.TILE_BG_DEFAULT_DEN;
				break;
			}
		}

		public static int GetIndexOfVacantPlayer()
		{
			// 제일 마지막은 소환 멤버의 자리이므로 (i < player.Length - 1)
			for (int i = 0; i < player.Length - 1; i++)
			{
				if (player[i].Name == "")
					return i;
			}

			return -1;
		}

		public static int GetIndexOfResevedPlayer()
		{
			return player.Length - 1;
		}

		public static int GetNumOfValidPlayer(bool include_reserved_one = true)
		{
			int MAX_PLAYER = (include_reserved_one) ? GameRes.player.Length : GameRes.GetIndexOfResevedPlayer();

			int num_valid = 0;
			for (int i = 0; i < MAX_PLAYER; i++)
				num_valid += (GameRes.player[i].IsValid()) ? 1 : 0;

			return num_valid;
		}

		public static int GetRandomIndexOfValidPlayer(bool include_reserved_one = true)
		{
			int MAX_PLAYER = (include_reserved_one) ? GameRes.player.Length : GameRes.GetIndexOfResevedPlayer();

			int ix_target = LibUtil.GetRandomIndex(GameRes.GetNumOfValidPlayer(include_reserved_one));
			Debug.Assert(ix_target >= 0);

			for (int i = 0; i < MAX_PLAYER; i++)
				if (GameRes.player[i].IsValid())
					if (ix_target-- == 0)
						return i;

			return (include_reserved_one) ? 0 : GameRes.GetIndexOfResevedPlayer();
		}

		public static int GetRandomIndexOfAvailablePlayer(bool include_reserved_one = true)
		{
			int MAX_PLAYER = (include_reserved_one) ? GameRes.player.Length : GameRes.GetIndexOfResevedPlayer();

			int ix_target = LibUtil.GetRandomIndex(GameRes.GetNumOfValidPlayer(include_reserved_one));
			Debug.Assert(ix_target >= 0);

			for (int i = 0; i < MAX_PLAYER; i++)
				if (GameRes.player[i].IsAvailable())
					if (ix_target-- == 0)
						return i;

			return (include_reserved_one) ? 0 : GameRes.GetIndexOfResevedPlayer();
		}

		public static int GetIndexOfSpeaker(int[] ix_candidates)
		{
			foreach (var ix in ix_candidates)
				if (ix >= 0 && ix < GameRes.player.Length)
					if (GameRes.player[ix].IsAvailable())
						return ix;

			return -1;
		}

		public static int GetNumOfValidEnemy()
		{
			int MAX_ENEMY = GameRes.enemy.Length;

			int num_valid = 0;
			for (int i = 0; i < MAX_ENEMY; i++)
				num_valid += (GameRes.enemy[i].IsValid()) ? 1 : 0;

			return num_valid;
		}

		public static byte GetIdentifingDegreeOfCurrentMap()
		{
			Debug.Assert(GameRes.map_script.Index >= 0 && GameRes.map_script.Index < GameRes.party.core.identified_map.Length);
			return GameRes.party.core.identified_map[GameRes.map_script.Index];
		}
	}
}
