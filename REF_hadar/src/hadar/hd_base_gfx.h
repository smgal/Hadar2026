
#ifndef __HD_BASE_GFX_H__
#define __HD_BASE_GFX_H__

#include "util/util_render_text.h"

namespace hadar
{
	namespace gfx
	{
		////////////////////////////////////////////////////////////////////////

		unsigned long getColorFromIndexedColor(unsigned long index, unsigned long default_color);

		////////////////////////////////////////////////////////////////////////

		struct Bound
		{
			int x1, y1, x2, y2;
			
			Bound(int _x1, int _y1, int _x2, int _y2)
				: x1(_x1)
				, y1(_y1)
				, x2(_x2)
				, y2(_y2)
			{
			}
			
			Bound()
				: x1(0)
				, y1(0)
				, x2(0)
				, y2(0)
			{
			}
		};

		struct BltParam
		{
			bool  is_available;
			Bound dst_bound;
			Bound src_bound;
			unsigned long color;

			BltParam(int x_dst, int y_dst, int width, int height, int x_src, int y_src, unsigned long _color)
				: is_available(true)
				, dst_bound(x_dst, y_dst, x_dst+width, y_dst+height)
				, src_bound(x_src, y_src, x_src+width, y_src+height)
				, color(_color)
			{
			}

			BltParam()
				: is_available(false)
			{
			}
		};

		void drawBltList(int x, int y, BltParam rect[], int nRect = 0x7FFFFFFF);

		////////////////////////////////////////////////////////////////////////

		void drawText(int x, int y, const char* sz_text, unsigned long color = 0xFFFFFFFF);
		void drawFormatedText(int x, int y, const char* sz_text_begin, const char* sz_text_end, unsigned long default_color, hadar::util::TextRenderer::FnBitBlt fn_bitblt);

	} // namespace gfx

} // namespace hadar

#endif // __HD_BASE_GFX_H__
