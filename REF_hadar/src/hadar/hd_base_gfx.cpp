
#include "hd_base_gfx.h"

#include "hd_base_config.h"
#include "hd_base_type.h"

#include "util/util_render_text.h"
#include "util/util_convert_to_ucs.h"

#include "UAvejUtil.h"

#include <cstring>

using hadar::util::widechar;


unsigned long hadar::gfx::getColorFromIndexedColor(unsigned long index, unsigned long default_color)
{
	enum { MAX_COLOR_TABLE = 16 };

	static const unsigned long COLOR_TABLE[MAX_COLOR_TABLE] =
	{
		0xFF000000, 0xFF000080, 0xFF008000, 0xFF008080,
		0xFF800000, 0xFF800080, 0xFF808000, 0xFF808080,
		0xFF404040, 0xFF0000FF, 0xFF00FF00, 0xFF00FFFF,
		0xFFFF0000, 0xFFFF00FF, 0xFFFFFF00, 0xFFFFFFFF
	};

	static bool s_is_first = true;
	static unsigned long s_localTable[MAX_COLOR_TABLE];

	if (s_is_first)
	{
		for (int index = 0; index < sizeof(COLOR_TABLE) / sizeof(COLOR_TABLE[0]); index++)
			s_localTable[index] = p_back_buffer->Color(COLOR_TABLE[index]);

		s_is_first = false;
	}

	return (index < sizeof(s_localTable) / sizeof(s_localTable[0])) ? s_localTable[index] : default_color;
}

namespace
{
	template <typename pixel>
	void s_drawBltList(int x, int y, hadar::gfx::BltParam rect[], int num_rect)
	{
		static bool s_is_first = true;
		static unsigned long s_white;

		if (s_is_first)
		{
			ASSERT(hadar::p_back_buffer);
			s_white = hadar::p_back_buffer->Color(0xFF, 0xFF, 0xFF, 0xFF);
			s_is_first = false;
		}

		for (int i = 0; i < num_rect; i++)
		{
			if (!rect[i].is_available)
				break;

			unsigned long color[4] = { rect[i].color, rect[i].color, rect[i].color, rect[i].color };

			hadar::p_back_buffer->BitBlt(x + rect[i].dst_bound.x1, y + rect[i].dst_bound.y1, hadar::p_font_image, rect[i].src_bound.x1, rect[i].src_bound.y1, rect[i].src_bound.x2 - rect[i].src_bound.x1, rect[i].src_bound.y2 - rect[i].src_bound.y1, color);
		}
	}

	void renderText(int x_dest, int y_dest, int width, int height, int x_sour, int y_sour, unsigned long color)
	{
		unsigned long color_list[4] = { color, color, color, color };
		hadar::p_back_buffer->BitBlt(x_dest, y_dest, hadar::p_font_image, x_sour, y_sour, width, height, color_list);
	}

}

void hadar::gfx::drawBltList(int x, int y, hadar::gfx::BltParam rect[], int num_rect)
{
	s_drawBltList<avej::pixel>(x, y, rect, num_rect);
}

void hadar::gfx::drawText(int x, int y, const char* sz_text, unsigned long color)
{
	const char* sz_text_end = sz_text + strlen(sz_text);
	gfx::drawFormatedText(x, y, sz_text, sz_text_end, color, renderText);
}

void hadar::gfx::drawFormatedText(int x, int y, const char* sz_text_begin, const char* sz_text_end, unsigned long default_color, hadar::util::TextRenderer::FnBitBlt fn_bitblt)
{
	// 항상 UCS-2 형식의 wchar_t로 컴파일 되어야 한다.
	CT_ASSERT(sizeof(widechar) == sizeof(wchar_t), QAZ);

	static const hadar::util::TextRenderer& ref_render_text = *hadar::util::TextRenderer::getTextInstance();

	if (sz_text_begin == NULL || sz_text_end == NULL || sz_text_begin >= sz_text_end )
		return;

	//?? 현재는 이 사이즈로 고정
	static widechar w_str[256];

	// KSC-5601을 UCS-2로 변경
	{
		widechar* w_str_end = hadar::util::convertUhcToUcs2(w_str, 256, sz_text_begin, sz_text_end - sz_text_begin);
		*w_str_end = 0;
	}

	{
		const int DEFAULT_INDEX_COLOR = 15;

		widechar* p_str_begin  = w_str;
		widechar* p_str_end    = w_str;
		int       x_end        = x;

		unsigned long current_color = default_color;

		while (*p_str_end)
		{
			if (*p_str_end == widechar('@'))
			{
				// NULL 문자로 끝내기, '@'가 NULL로 치환되는 것이기 때문에 조작해도 문제 없음
				*p_str_end = 0;

				// blitting list 만들기
				ref_render_text.renderText(x, y, p_str_begin, current_color, fn_bitblt);

				// x 시작값 갱신
				x = x_end;

				// current_color 갱신
				{
					widechar index_char = *(++p_str_end);
					int      index_color = -1;

					if      (index_char >= widechar('0') && index_char <= widechar('9'))
						index_color = index_char - '0';
					else if (index_char >= widechar('A') && index_char <= widechar('Z'))
						index_color = index_char - 'A' + 10;
					else if (index_char >= widechar('a') && index_char <= widechar('z'))
						index_color = index_char - widechar('A') + 10;
					else if (index_char == widechar('@'))
						current_color = default_color; // 복구

					if (index_color >= 0)
						current_color = gfx::getColorFromIndexedColor(index_color, default_color);
				}

				// 문자열의 시작을 갱신
				p_str_begin = ++p_str_end;
			}
			else
			{
				x_end += (*p_str_end > 0x00FF) ? config::DEFAULT_FONT_WIDTH*2 : config::DEFAULT_FONT_WIDTH;
				++p_str_end;
			}
		}

		// 남은 문자열에 대해 blitting list 만들기
		ref_render_text.renderText(x, y, p_str_begin, current_color, fn_bitblt);
	}
}
