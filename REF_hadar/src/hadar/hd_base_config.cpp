
#include "AvejConfig.h"
#include "hd_base_config.h"

#if   (SCREEN_WIDTH == 480)
	#define CONFIG_NUM 1
#elif (SCREEN_WIDTH == 320)
	#define CONFIG_NUM 2
#elif (SCREEN_WIDTH == 800)
	#define CONFIG_NUM 0
#endif

#if !defined(CONFIG_NUM)
	#error cannot support current platform
#endif

const int hadar::config::DEFAULT_FONT_HEIGHT = 20;
const int hadar::config::DEFAULT_FONT_WIDTH = hadar::config::DEFAULT_FONT_HEIGHT / 2;

const int hadar::config::DEFAULT_TILE_DISPLAY_WIDTH = 32;
const int hadar::config::DEFAULT_TILE_DISPLAY_HEIGHT = 32;

#if (CONFIG_NUM == 0)

	const int SCREEN_DISPLAY_WIDTH = 800;
	const int SCREEN_DISPLAY_HEIGHT = 480+100;

	// 실제로 사용되지는 않는 디폴트 값
	const hadar::config::Rect hadar::config::REGION_MAP_WINDOW =
	{
		0,
		0,
		hadar::config::DEFAULT_TILE_DISPLAY_WIDTH * 9,
		hadar::config::DEFAULT_TILE_DISPLAY_HEIGHT * 10 
	};

	const int CONSOLE_WINDOW_MARGIN_LEFT = 16;
	const int CONSOLE_WINDOW_MARGIN_TOP = 16;
	const int CONSOLE_WINDOW_MARGIN_RIGHT = 16;
	const int CONSOLE_WINDOW_MARGIN_BOTTOM = 16;

	const hadar::config::Rect hadar::config::REGION_CONSOLE_WINDOW =
	{
		CONSOLE_WINDOW_MARGIN_LEFT + hadar::config::REGION_MAP_WINDOW.x + hadar::config::REGION_MAP_WINDOW.w,
		CONSOLE_WINDOW_MARGIN_TOP + hadar::config::REGION_MAP_WINDOW.y,
		SCREEN_DISPLAY_WIDTH - (hadar::config::REGION_MAP_WINDOW.x + hadar::config::REGION_MAP_WINDOW.w) - (CONSOLE_WINDOW_MARGIN_LEFT + CONSOLE_WINDOW_MARGIN_RIGHT),
		hadar::config::DEFAULT_FONT_HEIGHT * 15
	};

	const int STATUS_Y = hadar::config::REGION_MAP_WINDOW.y + hadar::config::REGION_MAP_WINDOW.h + (0);

	const hadar::config::Rect hadar::config::REGION_STATUS_WINDOW =
	{
		hadar::config::DEFAULT_TILE_DISPLAY_WIDTH,
		STATUS_Y,
		SCREEN_DISPLAY_WIDTH,
		SCREEN_DISPLAY_HEIGHT - STATUS_Y
	};

#elif (CONFIG_NUM == 1)

const hadar::config::Rect hadar::config::REGION_MAP_WINDOW     = {0, 0, 24*9, 24*9};
const hadar::config::Rect hadar::config::REGION_CONSOLE_WINDOW = {24*9, 0, 480-24*9, 24*9};
const hadar::config::Rect hadar::config::REGION_STATUS_WINDOW  = {0, 24*10, 480, 360-24*10};

#elif (CONFIG_NUM == 2)

const hadar::config::Rect hadar::config::REGION_MAP_WINDOW     = {0, 0, 24*6, 24*7};
const hadar::config::Rect hadar::config::REGION_CONSOLE_WINDOW = {24*6, 0, SCREEN_WIDTH-24*6, 24*7};
const hadar::config::Rect hadar::config::REGION_STATUS_WINDOW  = {0, 24*7, SCREEN_WIDTH, SCREEN_HEIGHT-24*7};

#else

	#error cannot support current platform

#endif
