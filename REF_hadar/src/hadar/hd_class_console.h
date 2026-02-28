
#ifndef __HD_CLASS_CONSOLE_H__
#define __HD_CLASS_CONSOLE_H__

#include "hd_base_gfx.h"

#include <vector>

namespace hadar
{
	class LoreConsole
	{
	public:
		enum TEXTALIGN
		{
			TEXTALIGN_LEFT,
			TEXTALIGN_CENTER,
			TEXTALIGN_RIGHT
		};

		LoreConsole(void);
		~LoreConsole(void);

		bool isModified(void);
		void clear(void);
		void setBgColor(unsigned long color);
		unsigned long getBgColor(void);
		void setTextColor(unsigned long color);
		void setTextColorIndex(unsigned long index);
		void setTextAlign(TEXTALIGN align);
		void Write(const char* sz_text);
		void Write(const std::string text);
		void display(void);

		bool setRegion(int x, int y, int w, int h);
		void getRegion(int* pX, int* pY, int* pW, int* pH) const;

		static LoreConsole& getConsole(void);

	private:
		bool          m_is_modified;
		unsigned long m_text_color;
		unsigned long m_bg_color;
		TEXTALIGN     m_align;
		int           m_x_offset;
		int           m_y_offset;
		int           m_width;
		int           m_height;

		std::vector<gfx::BltParam*> m_line;

	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_CONSOLE_H__
