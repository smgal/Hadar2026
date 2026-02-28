
#ifndef __HD_CLASS_WINDOW_BATTLE_H__
#define __HD_CLASS_WINDOW_BATTLE_H__

#include "hd_base_type.h"
#include "hd_base_gfx.h"
#include "hd_class_pc_enemy.h"
#include "hd_class_window.h"

namespace hadar
{
	namespace data
	{
		const std::vector<PcEnemy* >& getEnemyList(void);
	}

	namespace game
	{
		unsigned long getRealColor(int index);
		void updateScreen(void);
	}

	class CWindowBattle: public CWindow
	{
		void m_displayWithColor(PcEnemy* obj, int row)
		{
			if (obj->isValid())
			{
				int ixColor = 10;

				if (obj->hp <= 0)
					ixColor = 8;
				else if (obj->hp <= 20)
					ixColor = 12;
				else if (obj->hp <= 50)
					ixColor = 4;
				else if (obj->hp <= 100)
					ixColor = 6;
				else if (obj->hp <= 200)
					ixColor = 14;
				else if (obj->hp <= 300)
					ixColor = 2;

				if (obj->unconscious)
					ixColor = 8;
				if (obj->dead)
					ixColor = 0;

				ASSERT(ixColor >= 0 && ixColor < 16);

				gfx::drawText(m_x+26, 20*(row++)+(m_y+6), obj->getName(), game::getRealColor(ixColor));
			}
		}

	protected:
		void m_DisplayEnemies(bool bClean, int inverted = -1)
		{
			if (bClean)
			{
				unsigned long color = p_back_buffer->Color(0xFF, 0x00, 0x00, 0x00);
				p_back_buffer->FillRect(color, m_x, m_y, m_w, m_h);
			}

			if (inverted >= 0)
			{
				unsigned long color = p_back_buffer->Color(0xFF, 0x80, 0x80, 0x80);
				p_back_buffer->FillRect(color, m_x, 20*(inverted)+m_y+6, m_w, 16);
			}
#if 0
			GameMain* p_game_main = (GameMain*)(_getMainInstance());

			int row = 0;
			std::vector<PcEnemy*>::iterator obj = p_game_main->enemy.begin();

			while (obj != p_game_main->enemy.end())
			{
				m_displayWithColor(*obj++, row++);
			}
#else
			const std::vector<PcEnemy*>& enemy_list = data::getEnemyList();

			int row = 0;
			std::vector<PcEnemy*>::const_iterator obj = enemy_list.begin();

			while (obj != enemy_list.end())
			{
				m_displayWithColor(*obj++, row++);
			}
#endif

			game::updateScreen();
		}

		void _onDisplay(int param1, int param2)
		{
			m_DisplayEnemies((param1 != 0) ? true : false, param2);
		}
	public:
		CWindowBattle(GameMain* p_game_main)
			: CWindow(p_game_main)
		{
		}
		virtual ~CWindowBattle(void)
		{
		}
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_WINDOW_BATTLE_H__
