
#ifndef __HD_CLASS_WINDOW_H__
#define __HD_CLASS_WINDOW_H__

namespace hadar
{
	/* window */
	class CWindow
	{
	private:
		// 현재 이 window는 update 되어야 하는 상태인가?
		bool m_must_be_update;
		// 현재 이 window는 눈에 보이는 상태인가?
		bool m_is_visible;

		const class GameMain* m_p_game_main;

	protected:
		// window의 위치와 크기
		int  m_x, m_y, m_w, m_h;

		inline const GameMain* _getMainInstance(void) { return m_p_game_main; };
		virtual void _onDisplay(int param1, int param2) = 0;
		virtual void _onSetRegion() {}
	
	public:
		CWindow(GameMain* p_game_main)
			: m_must_be_update(true)
			, m_is_visible(true)
			, m_p_game_main(p_game_main)
			, m_x(0)
			, m_y(0)
			, m_w(0)
			, m_h(0)
		{
		}

		virtual ~CWindow(void)
		{
		}

		void setUpdateFlag(void)
		{
			m_must_be_update = true;
		}

		void display(int param1 = -1, int param2 = -1)
		{
			if (!m_is_visible)
				return;

			bool bForceUpdate = (param1 != -1) || (param2 != -1);

//??		if (bForceUpdate || m_must_be_update)
				_onDisplay(param1, param2);

			m_must_be_update = false;
		}

		void setRegion(int x, int y, int w, int h)
		{
			m_x = x;
			m_y = y;
			m_w = w;
			m_h = h;

			_onSetRegion();
		}

		void getRegion(int* p_out_x, int* p_out_y, int* p_out_width, int* p_out_height)
		{
			if (p_out_x)
				*p_out_x = m_x;
			if (p_out_y)
				*p_out_y = m_y;
			if (p_out_width)
				*p_out_width = m_w;
			if (p_out_height)
				*p_out_height = m_h;
		}

		bool isVisible(void)
		{
			return m_is_visible;
		}

		void show(void)
		{
			if (!m_is_visible)
				m_must_be_update = true;

			m_is_visible = true;

			this->display();
		}
		void hide(void)
		{
			m_is_visible = false;
			//@@ 추가적인 뭔가가 더 필요한가?
		}
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_WINDOW_H__
