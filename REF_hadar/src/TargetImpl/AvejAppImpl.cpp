
#define USE_WIN32_KEY

#include <SDL.h>
#include <stdlib.h>

#ifdef GP2X
#include <unistd.h>
#endif

#include "AvejConfig.h"
#include "UAvejGfx.h"
#include "UAvejApp.h"

void Terminate(void)
{
#ifdef GP2X
	chdir("/usr/gp2x");
	execl("/usr/gp2x/gp2xmenu", "/usr/gp2x/gp2xmenu", NULL);
#endif
}

#define KEY_MATCHING(SDLK, AVEJK) case SDLK_##SDLK : key = avej::KEY_##AVEJK; break;

static avej::EKeySym s_ConvertKey(int nativeKey)
{
#if defined(USE_WIN32_KEY)
	avej::EKeySym key = avej::EKeySym(nativeKey);
#else
	avej::EKeySym key = avej::KEY_UNKNOWN;
#endif

	switch (nativeKey)
	{
#if 0
		KEY_MATCHING(q, UP_LEFT   )
		KEY_MATCHING(w, UP        )
		KEY_MATCHING(e, UP_RIGHT  )
		KEY_MATCHING(a, LEFT      )
		KEY_MATCHING(d, RIGHT     )
		KEY_MATCHING(z, DOWN_LEFT )
		KEY_MATCHING(x, DOWN      )
		KEY_MATCHING(c, DOWN_RIGHT)

		KEY_MATCHING(UP, BUTTON_D)
		KEY_MATCHING(DOWN, BUTTON_C)
		KEY_MATCHING(RIGHT, BUTTON_B)
		KEY_MATCHING(LEFT, BUTTON_A)
#else
		KEY_MATCHING(UP, UP        )
		KEY_MATCHING(LEFT, LEFT      )
		KEY_MATCHING(RIGHT, RIGHT     )
		KEY_MATCHING(DOWN, DOWN      )

		KEY_MATCHING(SPACE, SELECT)
		KEY_MATCHING(RETURN, BUTTON_B)
		KEY_MATCHING(ESCAPE, BUTTON_A)

		KEY_MATCHING(LSHIFT, BUTTON_L)
		KEY_MATCHING(RSHIFT, BUTTON_R)

		KEY_MATCHING(KP_MINUS, VOL_DOWN)
		KEY_MATCHING(KP_PLUS, VOL_UP)
#endif
	}

	return key;
}

/* GP2X button mapping */
enum MAP_KEY
{
	VK_UP         , // 0
	VK_UP_LEFT    , // 1
	VK_LEFT       , // 2
	VK_DOWN_LEFT  , // 3
	VK_DOWN       , // 4
	VK_DOWN_RIGHT , // 5
	VK_RIGHT      , // 6
	VK_UP_RIGHT   , // 7
	VK_START      , // 8
	VK_SELECT     , // 9
	VK_FL         , // 10
	VK_FR         , // 11
	VK_FA         , // 12
	VK_FB         , // 13
	VK_FX         , // 14
	VK_FY         , // 15
	VK_VOL_UP     , // 16
	VK_VOL_DOWN   , // 17
	VK_TAT        , // 18
	VK_MAX_VALUE
};

static avej::EKeySym s_ConvertJoyButton(int nativeKey)
{
	if ((nativeKey < 0) || (nativeKey >= VK_MAX_VALUE))
		return avej::KEY_UNKNOWN;

	const avej::EKeySym KEY_CONVERSION_MAP[VK_MAX_VALUE] =
	{
		avej::KEY_UP,
		avej::KEY_UP_LEFT,
		avej::KEY_LEFT,
		avej::KEY_DOWN_LEFT,
		avej::KEY_DOWN,
		avej::KEY_DOWN_RIGHT,
		avej::KEY_RIGHT,
		avej::KEY_UP_RIGHT,
		avej::KEY_START,
		avej::KEY_SELECT,
		avej::KEY_BUTTON_L,
		avej::KEY_BUTTON_R,
		avej::KEY_BUTTON_A,
		avej::KEY_BUTTON_B,
		avej::KEY_BUTTON_C,
		avej::KEY_BUTTON_D,
		avej::KEY_VOL_UP,
		avej::KEY_VOL_DOWN,
		avej::KEY_UNKNOWN,
	};

	return KEY_CONVERSION_MAP[nativeKey];
}

class IAvejAppImpl: public avej::IAvejApp
{
protected:
	avej::IGfxDevice* p_gfx_device;
	avej::AppCallback callBack;
	SDL_Joystick* joy;
	bool done;

public:
	IAvejAppImpl(const avej::AppCallback& _callBack)
		: p_gfx_device(NULL), callBack(_callBack), joy(NULL)
	{
        atexit (Terminate);
       
		p_gfx_device = avej::IGfxDevice::GetInstance();

		// Check and open joystick device
		if (SDL_NumJoysticks() > 0)
		{
			joy = SDL_JoystickOpen(0);
			if (joy == NULL)
			{
				fprintf (stderr, "Couldn't open joystick 0: %s\n", SDL_GetError ());
			}
		}

		if (callBack.OnCreate)
			callBack.OnCreate();
	}
	~IAvejAppImpl(void)
	{
		if (callBack.OnDestory)
			callBack.OnDestory();

		p_gfx_device->Release();

		SDL_Quit();
	}

	void ProcessMessages(void)
	{
		SDL_Event event;

		// Check for events
		while (SDL_PollEvent (&event))
		{
			switch (event.type)
			{
			case SDL_KEYDOWN:
				// if press Ctrl + C, terminate program
				if ((event.key.keysym.sym == SDLK_c) && (event.key.keysym.mod & (KMOD_LCTRL | KMOD_RCTRL)))
				{
					done = true;
					break;
				}
				if (callBack.OnKeyDown)
					callBack.OnKeyDown(s_ConvertKey(event.key.keysym.sym), 0);
				break;
			case SDL_KEYUP:
				if (callBack.OnKeyUp)
					callBack.OnKeyUp(s_ConvertKey(event.key.keysym.sym), 0);
				break;
			case SDL_JOYBUTTONDOWN:
				// if press Start button, terminate program
				if (event.jbutton.button == VK_START)
				{
					done = true;
					break;
				}
				if (callBack.OnJoyDown)
					callBack.OnJoyDown(s_ConvertJoyButton(event.jbutton.button));
				break;
			case SDL_JOYBUTTONUP:
				if (callBack.OnJoyUp)
					callBack.OnJoyUp(s_ConvertJoyButton(event.jbutton.button));
				break;
			case SDL_QUIT:
				done = true;
				break;
			default:
				break;
			}
		}
	}

	void Process(void)
	{
		done = false;
		while (!done)
		{
			ProcessMessages();

			if (callBack.OnProcess)
				callBack.OnProcess();
		}
	}

	static avej::IAvejApp* pAppImpl;
	static int refCount;
	static avej::IAvejApp* GetInstance(const avej::AppCallback& callBack);
	static int Release(void);
};

avej::IAvejApp* IAvejAppImpl::pAppImpl = 0;
int IAvejAppImpl::refCount = 0;

avej::IAvejApp* IAvejAppImpl::GetInstance(const avej::AppCallback& callBack)
{
	if (pAppImpl == 0)
	{
    	pAppImpl = new IAvejAppImpl(callBack);
	}

	++refCount;

	return pAppImpl;
}

int IAvejAppImpl::Release(void)
{
	if (--refCount == 0)
		delete (IAvejAppImpl*)pAppImpl;

	return refCount;
}

avej::IAvejApp* avej::IAvejApp::GetInstance(const avej::AppCallback& callBack)
{
	return IAvejAppImpl::GetInstance(callBack);
}

int avej::IAvejApp::Release(void)
{
	return IAvejAppImpl::Release();
}

void avej::IAvejApp::ProcessMessages(void)
{
	avej::AppCallback dummy;
	IAvejAppImpl* pApp = static_cast<IAvejAppImpl*>(IAvejAppImpl::GetInstance(dummy));
	pApp->ProcessMessages();
	pApp->Release();
}
