
#ifndef __HD_CLASS_WINDOW_CONSOLE_H__
#define __HD_CLASS_WINDOW_CONSOLE_H__

#include "hd_base_config.h"

#include "hd_class_window.h"
#include "hd_class_console.h"

namespace hadar
{
	class CWindowConsole: public CWindow
	{
	protected:
		void _onDisplay(int param1, int param2)
		{
			static bool s_is_first = true;
			if (s_is_first)
			{
				_onSetRegion();

				// 전체 영역을 background color 로 채운 뒤, LoreConsole을 통해 client 영역을 채움
				unsigned long bgColor = p_back_buffer->Color(0xFF, 0x40, 0x40, 0x40);
				p_back_buffer->FillRect(bgColor, m_x, m_y, m_w, m_h);

 				// 시작시 console 화면을 bg color로 채움
				LoreConsole& console = LoreConsole::getConsole();
				console.setBgColor(bgColor);
				console.clear();

				s_is_first = false;
			}
			return;
		}

		void _onSetRegion()
		{
			int wReal = m_w / config::DEFAULT_FONT_WIDTH * config::DEFAULT_FONT_WIDTH;
			int hReal = m_h / config::DEFAULT_FONT_HEIGHT * config::DEFAULT_FONT_HEIGHT;
			LoreConsole::getConsole().setRegion(m_x+(m_w-wReal)/2, m_y+(m_h-hReal)/2, wReal, hReal);
		}

	public:
		CWindowConsole(GameMain* p_game_main)
			: CWindow(p_game_main)
		{
		}
		virtual ~CWindowConsole(void)
		{
		}
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_WINDOW_CONSOLE_H__
