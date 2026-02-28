
#ifndef __HD_CLASS_WINDOW_MAP_H__
#define __HD_CLASS_WINDOW_MAP_H__

#include "hd_base_config.h"
#include "hd_base_gfx.h"

#include "hd_class_window.h"
#include "hd_class_map.h"
#include "hd_class_pc_party.h"

namespace hadar
{
	namespace data
	{
		const PcParty& getParty(void);
		const Map& getMap(void);
	}

	class CWindowMap: public CWindow
	{
	public:
		enum
		{
			// 기준 반지름
			_X_RADIUS = 5,
			_Y_RADIUS = 6,
			// 타일의 실제 크기
			TILE_X_SIZE = 32, //?? config::DEFAULT_TILE_DISPLAY_WIDTH,
			TILE_Y_SIZE = 32  //?? config::DEFAULT_TILE_DISPLAY_HEIGHT
		};

	private:
		// 타일 출력을 위한 시작 옵셋
		int m_xDisplayOffset;
		int m_yDisplayOffset;
		// 가로 세로 출력 반지름
		int m_wRadDisplay;
		int m_hRadDisplay;

	protected:
		void _onDisplay(int param1, int param2)
		{
			bool  must_display_character = true;

			const PcParty& party = data::getParty();
			const Map&     map   = data::getMap();

			p_back_buffer->SetClipRect(m_x, m_y, m_w, m_h);

			// 동굴이 아니거나 마법의 횟불이 켜져 있는 상태라면,
			bool bDaylight = (map.type != Map::TYPE_DEN) || (party.ability.magic_torch > 0);

			// 어두운 상태라면 일단 화면을 검게 만든다.
			if (!bDaylight)
				p_back_buffer->FillRect(0xFF000000, m_x, m_y, m_w, m_h);

			{
				int x_origin = party.x;
				int y_origin = party.y;

				int x;
				int y = m_y + m_yDisplayOffset;

				for (int j = -(m_hRadDisplay-1); j <= (m_hRadDisplay-1); j++)
				{
					x = m_x + m_xDisplayOffset;
					for (int i = -(m_wRadDisplay-1); i <= (m_wRadDisplay-1); i++)
					{
						// (bDaylight == true)라면 루프를 최적화 할 수 있지만...
						if (bDaylight)
						{
							int x_src = map(x_origin+i,y_origin+j)*TILE_X_SIZE;
							int y_src = map.type*TILE_Y_SIZE;

							p_back_buffer->BitBlt(x, y, p_tile_image, x_src, y_src, TILE_X_SIZE, TILE_Y_SIZE);
						}
						else
						{
							if (map.hasLight(x_origin+i,y_origin+j))
							{
								p_back_buffer->BitBlt(x, y, p_tile_image, map(x_origin+i,y_origin+j)*TILE_X_SIZE, map.type*TILE_Y_SIZE, TILE_X_SIZE, TILE_Y_SIZE);
							}
						}
						x += TILE_X_SIZE;
					}
					y += TILE_Y_SIZE;
				}
			}

			// 주인공 출력
			if (must_display_character)
			{
				p_back_buffer->BitBlt((m_wRadDisplay-1)*TILE_X_SIZE+m_x+m_xDisplayOffset, (m_hRadDisplay-1)*TILE_Y_SIZE+m_y+m_yDisplayOffset, p_sprite_image, party.faced*TILE_X_SIZE, 0, TILE_X_SIZE, TILE_Y_SIZE);
			}

			p_back_buffer->SetClipRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);

			// 현재 좌표 출력 (임시)
			{
				char sz_text[256];
				SPRINTF(sz_text, 256, "(%3d,%3d)", party.x, party.y);
				p_back_buffer->FillRect(0, 0, 0, 9*config::DEFAULT_FONT_WIDTH, config::DEFAULT_FONT_HEIGHT);
				gfx::drawText(0, 0, sz_text);
			}
		}
		void _onSetRegion()
		{
			if ((config::REGION_MAP_WINDOW.w > 0) && (config::REGION_MAP_WINDOW.h > 0))
			{
				m_wRadDisplay    = (config::REGION_MAP_WINDOW.w+3*TILE_X_SIZE-1) / (2*TILE_X_SIZE);
				m_hRadDisplay    = (config::REGION_MAP_WINDOW.h+3*TILE_Y_SIZE-1) / (2*TILE_Y_SIZE);
				m_xDisplayOffset = (config::REGION_MAP_WINDOW.w - (2*m_wRadDisplay-1) * TILE_X_SIZE) / 2;
				m_yDisplayOffset = (config::REGION_MAP_WINDOW.h - (2*m_hRadDisplay-1) * TILE_Y_SIZE) / 2;

				assert(_X_RADIUS == m_wRadDisplay);
				assert(_Y_RADIUS == m_hRadDisplay);
			}
			else
			{
				// 만약 유효하지 않은 영역을 설정한 경우에는 실제 출력은 하지 않는다.
				m_xDisplayOffset = 0;
				m_yDisplayOffset = 0;
				m_wRadDisplay    = 0;
				m_hRadDisplay    = 0;
			}
		}

	public:
		CWindowMap(GameMain* p_game_main)
			: CWindow(p_game_main)
		{
			m_xDisplayOffset = 0;
			m_yDisplayOffset = 0;
			m_wRadDisplay    = 0;
			m_hRadDisplay    = 0;

			assert(TILE_X_SIZE == config::DEFAULT_TILE_DISPLAY_WIDTH);
			assert(TILE_Y_SIZE == config::DEFAULT_TILE_DISPLAY_HEIGHT);
		}
		virtual ~CWindowMap(void)
		{
		}
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_WINDOW_MAP_H__
