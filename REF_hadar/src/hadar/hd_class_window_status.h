
#ifndef __HD_CLASS_WINDOW_STATUS_H__
#define __HD_CLASS_WINDOW_STATUS_H__

#include "hd_base_extern.h"
#include "hd_base_gfx.h"

#include "hd_class_window.h"
#include "hd_class_pc_player.h"
#include "hd_res_string.h"

namespace hadar
{
	namespace data
	{
		const std::vector<PcPlayer* >& getPlayerList(void);
	}

	class CWindowStatus: public CWindow
	{
	protected:
		void m_displayStatus(PcPlayer* obj)
		{
			// 시작 전에는 항상 player의 값을 보정한다.
			obj->checkCondition();

			unsigned long nameColor = p_back_buffer->Color(obj->getConditionColor());
			unsigned long color0 = p_back_buffer->Color(0xFF, 0x00, 0x00, 0x00);
			unsigned long color1 = p_back_buffer->Color(0xFF, 0x40, 0x20, 0xC0);
			unsigned long color2 = p_back_buffer->Color(0xFF, 0x20, 0x10, 0x80);
			unsigned long color3 = p_back_buffer->Color(0xFF, 0x10, 0x00, 0x40);

			// Name HP SP ESP Condition
			static const int FILELD_WIDTH[4] = { 70*20/12, (24+4)*20/12, (18+4)*20/12, (18+4)*20/12 };

			int i;
			int y = (obj->order+0)+1;
			int x = 0;

			gfx::drawText(m_x+3, m_y, "name         hp  sp esp");

			for (i = 0; i < sizeof(FILELD_WIDTH) / sizeof(FILELD_WIDTH[0]); i++)
			{
				p_back_buffer->FillRect(color1, m_x+x, m_y+y*config::DEFAULT_FONT_HEIGHT+0, FILELD_WIDTH[i]-2, 2);
				p_back_buffer->FillRect(color2, m_x+x, m_y+y*config::DEFAULT_FONT_HEIGHT+2, FILELD_WIDTH[i]-2, 2);
				p_back_buffer->FillRect(color3, m_x+x, m_y+y*config::DEFAULT_FONT_HEIGHT+4, FILELD_WIDTH[i]-2, 3);
				p_back_buffer->FillRect(color0, m_x+x, m_y+y*config::DEFAULT_FONT_HEIGHT+7, FILELD_WIDTH[i]-2, 5);
				x += FILELD_WIDTH[i]+1;
			}

			x = 0;
			if (obj->isValid())
			{
				gfx::drawText(m_x+x, m_y+config::DEFAULT_FONT_HEIGHT*y, obj->getName(), nameColor);
				x += FILELD_WIDTH[0]+1;

				char sz_temp[32];

				SPRINTF(sz_temp, 32, "%4d", obj->hp);
				gfx::drawText(m_x+x, m_y+config::DEFAULT_FONT_HEIGHT*y, sz_temp);
				x += FILELD_WIDTH[1]+1;

				SPRINTF(sz_temp, 32, "%3d", obj->sp);
				gfx::drawText(m_x+x, m_y+config::DEFAULT_FONT_HEIGHT*y, sz_temp);
				x += FILELD_WIDTH[2]+1;

				SPRINTF(sz_temp, 32, "%3d", obj->esp);
				gfx::drawText(m_x+x, m_y+config::DEFAULT_FONT_HEIGHT*y, sz_temp);
				x += FILELD_WIDTH[3]+1;

				// 320*240 에서는 condition을 이름으로 출력하지 않고 이름 출력시 색깔로 정의됨
				//gfx::drawText(m_x+x, m_y+config::DEFAULT_FONT_HEIGHT*y, obj->getConditionString());
			}
			else
			{
				gfx::drawText(m_x+x, m_y+config::DEFAULT_FONT_HEIGHT*y, resource::getAuxName(resource::AUX_RESERVED).sz_name, game::getRealColor(4));
			}
		}

		void _onDisplay(int param1, int param2)
		{
			const std::vector<PcPlayer*>& player_list = data::getPlayerList();

			std::vector<PcPlayer*>::const_iterator obj = player_list.begin();

			while (obj != player_list.end())
			{
				m_displayStatus(*obj++);
			}
		}
	public:
		CWindowStatus(GameMain* p_game_main)
			: CWindow(p_game_main)
		{
		}
		virtual ~CWindowStatus(void)
		{
		}
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_WINDOW_STATUS_H__
