
#ifndef __HD_CLASS_SELECT_H__
#define __HD_CLASS_SELECT_H__

#pragma warning( disable: 4786 )
#include <vector>
#include "UAvejUtil.h"

namespace hadar
{
	typedef std::vector<avej::string> MenuList;

	class MenuSelection
	{
	public:
		MenuSelection(const MenuList& menu, int num_enabled = -1, int ix_initial = 1);

		int operator()(void)
		{
			return m_selected;
		}

	private:
		int  m_selected;
		void m_display(const MenuList& menu, int num_menu, int num_enabled, int selected);
	};

	class MenuSelectionUpDown
	{
	public:
		/*
			INPUT PARAMETER
			x: 시작 x좌표
			y: 시작 y좌표
			min: 시작 최소 값
			max: 시작 최대 값
			step: 증감폭
			init: 초기 값
			fgColor: 출력색 (index color)
			bgColor: 배경색 (index color)
		*/
		MenuSelectionUpDown(int x, int y, int min, int max, int step, int init, unsigned long fg_color, unsigned long bg_color);
		/*
			REUTRN VALUE: min~max 사이의 값일 때 성공, min 보다 작으면 실패
		*/
		int operator()(void)
		{
			return m_value;
		}

	private:
		int  m_value;
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_SELECT_H__
