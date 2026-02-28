
#include "util_render_text.h"

using hadar::util::widechar;
using hadar::util::TextRenderer;

namespace
{
	///////////////////////////////////////////////////////////////////////////////

	class CodeParser
	{
	public:
		struct GlyphRect
		{
			int num_rect;
			struct
			{
				int x1, y1, x2, y2;
			} rect[3];
		};

		virtual ~CodeParser()
		{
		}

		virtual bool getGlyphRect(unsigned long index, GlyphRect& glyph_rect) const = 0;
	};

	///////////////////////////////////////////////////////////////////////////////

	class UniJohabParser: public CodeParser
	{
	public:
		UniJohabParser(unsigned int font_height, unsigned int buffer_width)
			: m_font_height(font_height)
			, m_buffer_width(buffer_width)
		{
		}

		virtual bool getGlyphRect(unsigned long index, GlyphRect& glyph_rect) const;

	private:
		unsigned int m_font_height;
		unsigned int m_buffer_width;

		void m_convertUnicodeToJohap(const widechar code, unsigned long& johap) const;
		long m_getGlyphIndex(unsigned long character_code) const;
		void m_getGlyph(unsigned long index, int jamo_index[]) const;
	};

	///////////////////////////////////////////////////////////////////////////////

	void UniJohabParser::m_convertUnicodeToJohap(const widechar code, unsigned long& johap) const
	{
		const int MAX_SM1 = 19;
		const int MAX_SM2 = 21;
		const int MAX_SM3 = 28;

		const int JH_UNI_TABLE[3][32] =
		{
			{-1,-2, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
			{-1,-1,-2, 0, 1, 2, 3, 4,-1,-1, 5, 6, 7, 8, 9,10,-1,-1,11,12,13,14,15,16,-1,-1,17,18,19,20,-1,-1},
			{-1,-2, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,-1,17,18,19,20,21,22,23,24,25,26,27,-1,-1}
		};

		const int UNI_JH_TABLE[3][32] =
		{
			{ 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
			{ 3, 4, 5, 6, 7,10,11,12,13,14,15,18,19,20,21,22,23,26,27,28,29,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1},
			{ 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,19,20,21,22,23,24,25,26,27,28,29,-1,-1,-1,-1}
		};

		const int INCOMPLETE_TABLE[0x3163- 0x3131 + 1] =
		{
			// CONSONANT
			0x8800, 0x8C00, 0x8444, 0x9000, 0x8446, 0x8447, 0x9400, 0x9800, 0x9C00, 0x844A,
			0x844B, 0x844C, 0x844D, 0x844E, 0x844F, 0x8450, 0xA000, 0xA400, 0xA800, 0x8454,
			0xAC00, 0xB000, 0xB400, 0xB800, 0xBC00, 0xC000, 0xC400, 0xC800, 0xCC00, 0xD000,
			// VOWEL
			0x8461, 0x8481, 0x84A1, 0x84C1, 0x84E1, 0x8541, 0x8561, 0x8581, 0x85A1, 0x85C1,
			0x85E1, 0x8641, 0x8661, 0x8681, 0x86A1, 0x86C1, 0x86E1, 0x8741, 0x8761, 0x8781,
			0x87A1
		};

		int unicode;
		int sm1;
		int sm2;
		int sm3;
		unsigned short temp16;

		unicode = int(code);

		if (unicode < 0x0080)
		{
			johap = unicode;
		}
		else if ((unicode >= 0xAC00) & (unicode <= 0xD7A3))
		{
			unicode -= 0xAC00;

			sm1 =  unicode / (MAX_SM2 * MAX_SM3);
			sm2 = (unicode - sm1 * (MAX_SM2 * MAX_SM3)) / MAX_SM3;
			sm3 =  unicode - sm1 * (MAX_SM2 * MAX_SM3) - sm2 * MAX_SM3;

			sm1 = UNI_JH_TABLE[0][sm1];
			sm2 = UNI_JH_TABLE[1][sm2];
			sm3 = UNI_JH_TABLE[2][sm3];

			johap = 0x8000 | (sm1 << 10) | (sm2 << 5) | sm3;
		}
		else if ((unicode >= 0x3131) & (unicode <= 0x3163))
		{
			temp16 = INCOMPLETE_TABLE[unicode - 0x3131];
			if (temp16 > 0)
				johap = temp16;
		}
	}

	long UniJohabParser::m_getGlyphIndex(unsigned long character_code) const
	{
		const unsigned char CONVERT_TABLE[3][31] =
		{
			{ 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
			{ 0, 0, 0, 1, 2, 3, 4, 5, 0, 0, 6, 7, 8, 9,10,11, 0, 0,12,13,14,15,16,17, 0, 0,18,19,20,21, 0},
			{ 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16, 0,17,18,19,20,21,22,23,24,25,26,27, 0}
		};

		int i;
		unsigned long jamo[3];
		unsigned long johap;

		m_convertUnicodeToJohap(widechar(character_code), johap);

		if (((johap & 0x8000) == 0) || (johap > 0xFFFF))
			return -1;

		jamo[0] = (johap >> 10) & 0x1F;
		jamo[1] = (johap >>  5) & 0x1F;
		jamo[2] = (johap >>  0) & 0x1F;

		long result = 0;

		for (i = 0; i < 3; i++)
		{
			result = result << 8;
			if (jamo[i] < 0x20)
				result = result | long(CONVERT_TABLE[i][jamo[i]]);
		}

		return result;
	}

	void UniJohabParser::m_getGlyph(unsigned long index, int jamo_index[]) const
	{
		unsigned long jamo[4]; // 0: not used
		unsigned long face[4]; // 0: not used

		jamo[1] = (index >> 16) & 0x000000FF;
		jamo[2] = (index >>  8) & 0x000000FF;
		jamo[3] = (index >>  0) & 0x000000FF;

		face[1] = 0;
		face[2] = 0;
		face[3] = 0;

		#define IN(data, mask) ((1L << (data)) & mask)

		if (jamo[3] > 0)
		{
			if IN(jamo[2], 0x002001FE) face[1] = 95;  // [1..8,21]
			if IN(jamo[2], 0x000C6200) face[1] = 114; // [9,13,14,18,19]
			if IN(jamo[2], 0x00139C00) face[1] = 133; // [10..12,15..17,20]
			if IN(jamo[1], 0x00010002) face[2] = 194; // [1,16]
			if IN(jamo[1], 0x000EFFFC) face[2] = 215; // [2..15,17..19]
			if IN(jamo[2], 0x0000040A) face[3] = 236; // [1,3,10]
			if IN(jamo[2], 0x003290A0) face[3] = 263; // [5,7,12,15,17,20,21]
			if IN(jamo[2], 0x00010954) face[3] = 290; // [2,4,6,8,11,16]
			if IN(jamo[2], 0x000C6200) face[3] = 317; // [9,13,14,18,19]

			if ((jamo[1] == 0) & (jamo[2] == 0))
				face[3] = 236;
		}
		else
		{
			if IN(jamo[2], 0x002001FE) face[1] = 0;   // [1..8,21]
			if IN(jamo[2], 0x00082200) face[1] = 19;  // [9,13,19]
			if IN(jamo[2], 0x00044000) face[1] = 38;  // [14,18]
			if IN(jamo[2], 0x00101C00) face[1] = 57;  // [10..12,20]
			if IN(jamo[2], 0x00038000) face[1] = 76;  // [15..17]
			if IN(jamo[1], 0x00010003) face[2] = 152; // [0,1,16]
			if IN(jamo[1], 0x000EFFFC) face[2] = 173; // [2..15,17..19]

			if (jamo[1] == 0)
				face[1] = 0;
		}

		#undef IN

		jamo_index[0] = face[1] + jamo[1] - 1;

		if (jamo[2] > 0)
			jamo_index[1] = face[2] + jamo[2] - 1;
		else
			jamo_index[1] = -1;

		if ((jamo[3] > 0) && (face[3] > 0))
			jamo_index[2] = face[3] + jamo[3] - 1;
		else
			jamo_index[2] = -1;
	}

	bool UniJohabParser::getGlyphRect(unsigned long index, GlyphRect& glyph_rect) const
	{
		int i;
		int pitch;
		int jamo_index[3];

		if (int(index) >= 0x0080)
		{
			const int extent_w = m_font_height;
			const int extent_h = m_font_height;

			pitch = m_buffer_width / extent_w;

			m_getGlyph(m_getGlyphIndex(index), jamo_index);

			glyph_rect.num_rect = 0;

			for (i = 0; i < 3; i++)
			{
				if (jamo_index[i] < 0)
					break;

				index = m_buffer_width * 4 / extent_w + jamo_index[i];

				glyph_rect.rect[i].x1 = (index % pitch) * extent_w;
				glyph_rect.rect[i].y1 = (index / pitch) * extent_h;
				glyph_rect.rect[i].x2 = glyph_rect.rect[i].x1 + extent_w;
				glyph_rect.rect[i].y2 = glyph_rect.rect[i].y1 + extent_h;

				++glyph_rect.num_rect;
			}
		}
		else
		{
			const int extent_w = m_font_height >> 1;
			const int extent_h = m_font_height;

			pitch   = m_buffer_width / extent_w;
			index   = m_buffer_width * 2 / extent_w + index;

			glyph_rect.rect[0].x1 = (index % pitch) * extent_w;
			glyph_rect.rect[0].y1 = (index / pitch) * extent_h;
			glyph_rect.rect[0].x2 = glyph_rect.rect[0].x1 + extent_w;
			glyph_rect.rect[0].y2 = glyph_rect.rect[0].y1 + extent_h;

			glyph_rect.num_rect = 1;
		}

		return true;
	}

	///////////////////////////////////////////////////////////////////////////////

	static TextRenderer::BltParam* s_p_blt_param   = 0;
	static int                     s_ix_blt_param  = 0;
	static int                     s_num_blt_param = 0;

	static void s_BitBlt2TBltParam(int x_dest, int y_dest, int width, int height, int x_sour, int y_sour, unsigned long color)
	{
		if (s_ix_blt_param < s_num_blt_param)
		{
			TextRenderer::BltParam& blt_param = s_p_blt_param[s_ix_blt_param++];
			blt_param.is_available = true;
			blt_param.x_dest       = x_dest;
			blt_param.y_dest       = y_dest;
			blt_param.x1           = x_sour;
			blt_param.y1           = y_sour;
			blt_param.x2           = x_sour + width;
			blt_param.y2           = y_sour + height;
			blt_param.color        = color;
			blt_param.index_color  = -1;
		}
	}

	class TextRendererJohab: public TextRenderer
	{
	public:
		TextRendererJohab(CodeParser* p_code_parser)
			: m_p_code_parser(p_code_parser)
		{
		};

		~TextRendererJohab(void)
		{
			delete m_p_code_parser; 
		}

		void reset(CodeParser* p_code_parser)
		{
			delete m_p_code_parser;
			m_p_code_parser = p_code_parser;
		}

		void renderText(int x_dest, int y_dest, const widechar* sz_text, unsigned long color, FnBitBlt fn_bitblt) const
		{
			if (m_p_code_parser == 0)
				return;

			int w, h;
			CodeParser::GlyphRect glyph_rect;

			while (*sz_text)
			{
				m_p_code_parser->getGlyphRect((unsigned long)(*sz_text++), glyph_rect);

				w = glyph_rect.rect[0].x2 - glyph_rect.rect[0].x1;
				h = glyph_rect.rect[0].y2 - glyph_rect.rect[0].y1;

				for (int i = 0; i < glyph_rect.num_rect; i++)
				{
					fn_bitblt(x_dest, y_dest, w, h, glyph_rect.rect[i].x1, glyph_rect.rect[i].y1, color);
				}

				x_dest += (glyph_rect.rect[0].x2 - glyph_rect.rect[0].x1);
			}
		}

		int renderText(int x_dest, int y_dest, const widechar* sz_text, unsigned long color, BltParam blt_param[], int num_blt_param) const
		{
			s_p_blt_param   = &blt_param[0];
			s_ix_blt_param  = 0;
			s_num_blt_param = num_blt_param;

			this->renderText(x_dest, y_dest, sz_text, color, s_BitBlt2TBltParam);

			// 실제 기록된 개수를 넘겨 준다. 받는 쪽에서는 이 값으로 'is_available = false'등을 정의할 수 있다.
			return s_ix_blt_param;
		}

	private:
		CodeParser* m_p_code_parser;

	};

	TextRendererJohab s_render_text(new UniJohabParser(24, 512+256));
}

///////////////////////////////////////////////////////////////////////////////

TextRenderer* hadar::util::TextRenderer::getTextInstance(void)
{
	return &s_render_text;
}

void hadar::util::TextRenderer::setTextBufferDesc(unsigned int font_height, unsigned int buffer_width)
{
	s_render_text.reset(new UniJohabParser(font_height, buffer_width));
}
