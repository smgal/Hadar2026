
#ifndef __UTIL_RENDER_TEXT_H__
#define __UTIL_RENDER_TEXT_H__

namespace hadar
{
	namespace util
	{
		typedef unsigned short widechar;

		class TextRenderer
		{
		public:
			struct BltParam
			{
				bool          is_available;
				long          x_dest, y_dest;
				long          x1, y1, x2, y2;
				unsigned long color;
				int           index_color;
			};

			typedef void  (*FnBitBlt)(int x_dest, int y_dest, int width, int height, int x_sour, int y_sour, unsigned long color);

			virtual void renderText(int x_dest, int y_dest, const widechar* sz_text, unsigned long color, FnBitBlt fn_bitblt) const = 0;
			virtual int  renderText(int x_dest, int y_dest, const widechar* sz_text, unsigned long color, BltParam blt_param[], int num_blt_param) const = 0;

			static TextRenderer* getTextInstance(void);
			static void setTextBufferDesc(unsigned int font_height, unsigned int buffer_width);

		protected:
			virtual ~TextRenderer() {}
		};

	} // namespace util
} // namespace hadar

#endif
