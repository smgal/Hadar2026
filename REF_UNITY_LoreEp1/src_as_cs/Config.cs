
namespace Yunjr
{
	public static class CONFIG
	{
		public const bool ENABLE_GUI_LOG = false;
		public static bool ENABLE_FPS_COUNTER = false;

		public const bool DEBUG_MESSAGE_TO_HEADER = false;

		public const int TARGET_FRAME_RATE = 60;

		public const int CONSOLE_CONTENTS_WIDTH = 701;
		public const int FONT_SIZE = 34;

		public const int MIN_MAP_SIZE = 10;

		public const int MAX_PLAYER = 5;
		public const int MAX_ENEMY = 7;

		public const int MAX_FLAG = 0x200;
		public const int MAX_VARIABLE = 0x400;
		public const int MAX_IX_FLAG_FOR_SYSTEM = 0x200; // 1/8 of MAX_FLAG
		public const int MAX_IX_VARIABLE_FOR_SYSTEM = 0x80; // 1/8 of MAX_VARIABLE

		public const int VIEW_PORT_W_HALF = 5;
		public const int VIEW_PORT_H_HALF = 5;

		// [#obsolete] begin
		public const int MAX_MAP_TILE = 56;

		public const int TILE_BG_SPECIAL = 55;
		public const int TILE_FG_SPECIAL = 27;

		public const int TILE_BG_DEFAULT_TOWN = 47;
		public const int TILE_BG_DEFAULT_KEEP = 43;
		public const int TILE_BG_DEFAULT_GROUND = 41;
		public const int TILE_BG_DEFAULT_DEN = 43;

		public static int TILE_BG_DEFAULT = TILE_BG_DEFAULT_TOWN;
		public static TILE_SET TILE_SET_CURRENT = TILE_SET.TOWN;
		// [#obsolete] end

		public const int IX_MAP_TILE_DEFAULT = 0;
		public const int IX_MAP_OBJECT_DEFAULT = 0;
		public const int IX_MAP_EVENT_DEFAULT = EVENT_BIT.NONE;

		public static System.String BGM = "";

		public static bool SMOOTH_SHADOWING = true;
		public static int  KIRAKIRA_FPS = 6;

		// preference
		public const string PREF_STR_OPTION_LEFT_HANDED = "Option:LeftHanded";
		public const int PREF_DEFAULT_OPTION_LEFT_HANDED = 0;
		public const string PREF_STR_OPTION_SOUND_ON = "Option:SoundOn";
		public const int PREF_DEFAULT_OPTION_SOUND_ON = 1;
		public const string PREF_STR_OPTION_CHEAT_ON = "Option:CheatOn";
		public const int PREF_DEFAULT_OPTION_CHEAT_ON = 0;
		public const string PREF_STR_SAVE_INFO = @"Save:Info{0}";
		public const string PREF_STR_SAVE_TIME = @"Save:Time{0}";

		// GUI
		public const int GUI_CONSOLE_WIDTH = 52;
		public static float GUI_SCALE = 1.0f;

		// config
		public const int MAX_VALUE_OF_STATUS = 20;
		public const int CAPACITY_OF_BACKPACK = 100;
		public const bool CRUEL_MODE = false;

		// main numerical value
		public const int COST_OF_JOB_CHANGING = 10000;

		// save
		// release ver. 6 -> 3
		// release ver. 7 (0607) -> 4
		// release ver. 8 (0618) -> 4
		// release ver. apple 1.0 (0618) -> 5
		// release ver. 9 (1018) -> 6
		// release ver. apple 1.1 0.5.2(5)(1022) -> 6
		// release 180116 Android: 0.5.10(10) -> 7
		//                iPhone:  0.5.8(8) -> 7
		// release 180410 Android: 0.9.0(11) -> ver.8
		//                iPhone:  0.9.0(9; [app store 1.3.0]) -> ver.8
		// release 180412 Android: 0.9.1(12) -> ver.8
		public const uint SAVE_FILE_VERSION = 8;

	}
}
