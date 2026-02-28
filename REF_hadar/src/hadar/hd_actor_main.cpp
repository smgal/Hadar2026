
/*

  물의 정령 조인했을 때 자동을 status 맞춰줘야 함
  여관에 돈이 없을 경우...
  음식파는 장사꾼 추가

BUG list

저장한 것을 부르면 default tile이 사라짐
예> ground1에서 save를 했는데도 0번 이 나무 모양이 아니라 까만색이 됨


TODO list

 - CONSOLE_WRITE 사용 법 재고, 적어도 sz_temp를 외부 선언 해서는 안됨

- 동굴에 들어가면 불이 꺼지기
	시야가 좁아지거나 색이 바뀌는 것은?

- 문자열을 resource 化
	UPcPlayer 하던 중

- resource file을 지정하여 모든 파일을 하나의 파일에 저장
	실제로는 file과 resource 형태 둘 다 지원해야 함
	또는, code로 resouce 지정 가능한 형태

- 한글 입력 방법 만들기

- character 생성하는 것 만들기

- press any key 가 아니라 press enter key 같은 것이 되어야 하지않는가?

- g_?? 함수들은 모두 global을 뜻하는 namespace로 정리
	main.h 에 있는 아래의 두 함수가 대상임
	void gfx::drawBltList(int x, int y, SmFont12x12::BltParam rect[], int num_rect = 0x7FFFFFFF);
	void gfx::drawText(int x, int y, const char* sz_text, unsigned long color = 0xFFFFFFFF);

- event에 사용되는 함수들을 매뉴얼로 정리
- 스크립트 전투시 전투 결과를 받는 방법
  - 전투에서 도망쳤을 때 회피가 불가능 하게 하는 시나리오
  - 전투에서 도망쳤을 때 남은 수 만큼만 다시 나타나는 시나리오

- Doxygen 문서 만들기



개선 사항

- resource 암호화 seed: byte; adder: byte 의 xor만으로 암호화

- 헤더 딸린 자체 map file 구조 필요, 가능하다면 3탄의 map 구조도 사용 가능

- script를 파일 단위로 미리 읽어 놓는 방식으로 속도 개선
- 게임 내의 singleton 정리
	Script 객체
	GameMain 객체
- factory 정리


CODING GUIDE

- localization 고려하여 문자열을 따로 관리
- 16-bit color에 대한 conversion이 항상 필요
- strcpy -> strncpy
- sprintf -> snprintf
- class 정의
  - 저장하는 변수는 protected로
  - private 변수/함수는 m_*
  - protected 변수는 원래 이름, 함수는 _*
  - public 변수는 허용하지 않음, 함수는 원래 이름
- ??(구현 해야 하는 부분) @@(개선 사항)

- singleton 목록
	LoreConsole


  원작의 버그 목록

- 특수 기술을 얻기만 해도 일반 ESP를 사용할 수 있음
- 독심술을 사용해도 ESP 지수가 30이 빠지지 않음
- 적을 아군으로 만들 때 20레벨인 적의 경험치가 5100000가 아닌 510000만 할당됨
- 적이 독심술을 걸어 6번째 아군을 데려갈 수 있는데, 6번째 아군이 적의 n번이 되는 것이 아니라 n번째 아군이 적의 6번이 된다. 하지만 사라지는 것은 6번째 아군이다.
- 예언는/천리안는 전투모드에서는 사용할 수가 없습니다. <- 조사가 틀렸음

*/

////////////////////////////////////////////////////////////////////////////////
// uses

#pragma warning( disable: 4786 )

#include "hd_base_game_main.h"

#include "hd_base_config.h"
#include "hd_base_type.h"

#include "hd_class_key_buffer.h"

#include "util/util_render_text.h"

#include "AvejConfig.h"
#include "UAvejApp.h"
#include "UAvejGfx.h"
#include "UAvejUtil.h"


////////////////////////////////////////////////////////////////////////////////
// type definition

using namespace avej;

////////////////////////////////////////////////////////////////////////////////
// global variables

namespace hadar
{
	IGfxDevice*  p_gfx_device   = NULL;
	IGfxSurface* p_back_buffer  = NULL;
	IGfxSurface* p_tile_image   = NULL;
	IGfxSurface* p_sprite_image = NULL;
	IGfxSurface* p_font_image   = NULL;
}

////////////////////////////////////////////////////////////////////////////////
// main

namespace hadar
{
	void _makeFile(const char* sz_file_name, const char* sz_contents)
	{
		FILE* fp = fopen(sz_file_name, "wt");
		if (sz_contents)
		{
			fprintf(fp, sz_contents);
			fprintf(fp, "\n");
		}
		fclose(fp);
	}

	bool OnCreate(void)
	{
		// 그래픽 객체 생성
		hadar::p_gfx_device = IGfxDevice::GetInstance();

		hadar::p_gfx_device->GetSurface(&hadar::p_back_buffer);

		avej::string file_name_tile = "./lore_tile_";
		file_name_tile += avej::string(IntToStr(config::DEFAULT_TILE_DISPLAY_HEIGHT)());
		file_name_tile += ".bmp";

		avej::string file_name_sprite = "./lore_sprite_";
		file_name_sprite += avej::string(IntToStr(config::DEFAULT_TILE_DISPLAY_HEIGHT)());
		file_name_sprite += ".bmp";

		// "./han1bit_1024.bmp"
		avej::string file_name_font = "./han1bit_1024_";
		file_name_font += avej::string(IntToStr(config::DEFAULT_FONT_HEIGHT)());
		file_name_font += ".bmp";

		// load resources
		hadar::p_gfx_device->CreateSurfaceFrom(file_name_tile, &hadar::p_tile_image);

		hadar::p_gfx_device->CreateSurfaceFrom(file_name_sprite, &hadar::p_sprite_image);
		hadar::p_sprite_image->AssignType(IGfxSurface::TYPE_COLORKEY_AUTO);

		hadar::p_gfx_device->CreateSurfaceFrom(file_name_font, &hadar::p_font_image);
		hadar::p_font_image->AssignType(IGfxSurface::TYPE_COLORKEY_AUTO); 

		util::TextRenderer::setTextBufferDesc(hadar::config::DEFAULT_FONT_HEIGHT, (512/16) * hadar::config::DEFAULT_FONT_HEIGHT);

		// 게임 객체 초기화
		s_p_game_main = new hadar::GameMain;

		// 초기 디폴트 스크립트 로딩
		s_p_game_main->loadScript("startup.cm2");

		ASSERT(s_p_game_main->party.x >= 0 && s_p_game_main->party.y >= 0);

		return true;
	}

	bool OnDestory(void)
	{
		delete hadar::p_font_image;
		delete hadar::p_sprite_image;
		delete hadar::p_tile_image;
		
		hadar::p_gfx_device->Release();

		delete s_p_game_main;

		return true;
	}

	//?? 정확한 위치는?
	static bool           s_isKeyPressed = false;
	static unsigned short s_pressedKey;
	static unsigned long  s_repeatTime;
	const  unsigned long  c_delayTime = 75;

	bool OnJoyDown(unsigned short button)
	{
		// auto pressed key 구현
		if (!s_isKeyPressed)
		{
			s_isKeyPressed = true;
			s_pressedKey   = button;
			s_repeatTime   = AvejUtil::GetTicks() + c_delayTime*3;
		}

		return hadar::KeyBuffer::getKeyBuffer().setKeyDown(button);
	}

	bool OnJoyUp(unsigned short button)
	{
		// auto pressed key 구현
		if (s_isKeyPressed)
		{
			s_isKeyPressed = false;
		}

		return hadar::KeyBuffer::getKeyBuffer().setKeyUp(button);
	}

	bool OnKeyDown(unsigned short key, unsigned long state)
	{
		return OnJoyDown(key);
	}

	bool OnKeyUp(unsigned short key, unsigned long state)
	{
		return OnJoyUp(key);
	}

	bool OnProcess(void)
	{
		// auto pressed key 구현
		{
			unsigned long currentTick = AvejUtil::GetTicks();

			if (s_isKeyPressed)
			{
				if (s_repeatTime <= currentTick)
				{
					hadar::KeyBuffer::getKeyBuffer().setKeyUp(s_pressedKey);
					hadar::KeyBuffer::getKeyBuffer().setKeyDown(s_pressedKey);
					s_repeatTime = currentTick + c_delayTime;
				}
			}
		}

		return s_p_game_main->process();
	}

} // namespace hadar

////////////////////////////////////////////////////////////////////////////////
// main

int AvejMain(void)
{
	AppCallback callBack =
	{
		hadar::OnCreate,
		hadar::OnDestory,
		hadar::OnKeyDown,
		hadar::OnKeyUp,
		hadar::OnJoyDown,
		hadar::OnJoyUp,
		hadar::OnProcess
	};

	IAvejApp* pApp = NULL;

	try
	{
		pApp = IAvejApp::GetInstance(callBack);
		if (pApp == NULL)
			throw 0;

		pApp->Process();

		pApp->Release();
	}
	catch (hadar::ExceptionExitGame&)
	{
		if (pApp)
			pApp->Release();
	}
	catch (...)
	{
		ASSERT(false);
	}

	return 0;
}
