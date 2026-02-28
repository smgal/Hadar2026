
#ifndef __HD_BASE_CONFIG_H__
#define __HD_BASE_CONFIG_H__

namespace hadar
{
	namespace config
	{
		struct Rect
		{
			int x, y, w, h;
		};

		extern const Rect REGION_MAP_WINDOW;
		extern const Rect REGION_CONSOLE_WINDOW;
		extern const Rect REGION_STATUS_WINDOW;

		extern const int DEFAULT_FONT_WIDTH;
		extern const int DEFAULT_FONT_HEIGHT;

		extern const int DEFAULT_TILE_DISPLAY_WIDTH;
		extern const int DEFAULT_TILE_DISPLAY_HEIGHT;
	}
}

#endif // __HD_BASE_CONFIG_H__
