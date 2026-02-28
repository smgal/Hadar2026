
#include <SDL.h>
#include <stdlib.h>
#include <assert.h>

#include "AvejConfig.h"

//////////////////////////////////

#include "UAvejGfx.h"

class IGfxSurfaceImpl: public avej::IGfxSurface
{
protected:
	SDL_Surface* m_surface;
	bool m_useColorKey;
	unsigned long m_colorKey;

public:
	IGfxSurfaceImpl(SDL_Surface* _handle)
		: m_surface(_handle), m_useColorKey(false), m_colorKey(0)
	{
	}
	~IGfxSurfaceImpl(void)
	{
		if (m_surface)
			SDL_FreeSurface(m_surface);
	}
	bool  AssignType(EType type, unsigned long color)
	{
		switch (type)
		{
		case TYPE_NONE:
			m_useColorKey = false;
			break;
		case TYPE_COLORKEY:
			m_useColorKey = true;
			m_colorKey = color;
			break;
		case TYPE_COLORKEY_AUTO:
			m_useColorKey = true;
			{
				TLockDesc lockDesc;
				if (!this->Lock(lockDesc))
					return false;

				switch (m_surface->format->BytesPerPixel)
				{
					case 1:
						m_colorKey = *((unsigned char*)lockDesc.pMem);
						break;
					case 2:
						m_colorKey = *((unsigned short*)lockDesc.pMem);
						break;
					case 4:
						m_colorKey = *((unsigned long*)lockDesc.pMem);
						break;
					default:
						assert(false);
						
				}

				this->Unlock();
			}
			break;
		case TYPE_ALPHA:
			m_useColorKey = false;
			return (SDL_SetAlpha(m_surface, SDL_SRCALPHA, (unsigned char)color) == 0);
			break;
		default:
			return false;
		}

		return (SDL_SetColorKey(m_surface, m_useColorKey ? SDL_SRCCOLORKEY : 0, m_colorKey) == 0);
	}
	bool  FillRect(unsigned long color, int x, int y, int w, int h)
	{
		SDL_Rect srcRect = {x, y, w, h};
		return (SDL_FillRect(m_surface, &srcRect, color) == 0);
	}
	bool  BitBlt(int x, int y, const avej::IGfxSurface* srcSurface, int x_src, int y_src, int wSour, int hSour)
	{
		SDL_Rect srcRect = {x_src, y_src, wSour, hSour};
		SDL_Rect dstRect = {x, y, wSour, hSour};
		return (SDL_BlitSurface((SDL_Surface*)srcSurface->Handle(), &srcRect, m_surface, &dstRect) == 0);
	}
	bool  BitBlt(int x_dst, int y_dst, const avej::IGfxSurface* srcSurface, int x_src, int y_src, int wSour, int hSour, unsigned long color[])
	{
		if (color[0] == Color(0xFFFFFFFF))
		{
			SDL_Rect srcRect = {x_src, y_src, wSour, hSour};
			SDL_Rect dstRect = {x_dst, y_dst, wSour, hSour};

			return (SDL_BlitSurface((SDL_Surface*)srcSurface->Handle(), &srcRect, m_surface, &dstRect) == 0);
		}
		else
		{
			//?? incomplete code: y2 clipping only
			if (y_dst + hSour > m_surface->h)
				hSour = m_surface->h - y_dst;

			//??? юс╫ц
			typedef unsigned short pixel;

			pixel _color = color[0];

			IGfxSurface::TLockDesc sourDesc;
			IGfxSurface::TLockDesc destDesc;

			((IGfxSurface*)srcSurface)->Lock(sourDesc);
			this->Lock(destDesc);
			{
				pixel* pSour = (pixel*)sourDesc.pMem;
				int sourPadding = (sourDesc.pitch / sizeof(pixel)) - wSour;
				pixel* pDest = (pixel*)destDesc.pMem;
				int destPadding = (destDesc.pitch / sizeof(pixel)) - wSour;

				pSour += (y_src * (sourDesc.pitch / sizeof(pixel)) + x_src);
				pDest += (y_dst * (destDesc.pitch / sizeof(pixel)) + x_dst);

				int hCopy = hSour;
				while (--hCopy >= 0)
				{
					int wCopy = wSour;
					while (--wCopy >= 0)
					{
						if (*pSour++)
							*pDest = _color;
						++pDest;
					}

					pSour += sourPadding;
					pDest += destPadding;
				}
			}
			this->Unlock();
			((IGfxSurface*)srcSurface)->Unlock();

			return true;
		}
	}
	
	bool  SetClipRect(int x, int y, int w, int h)
	{
		SDL_Rect srcRect = {x, y, w, h};
		SDL_SetClipRect(m_surface, &srcRect);
		return true;
	}
	
    bool  Lock(TLockDesc& desc)
	{
		if SDL_MUSTLOCK(m_surface)
			if (SDL_LockSurface(m_surface) != 0)
				return false;

		desc.pMem  = m_surface->pixels;
		desc.pitch = m_surface->pitch;

		return true;
	}
    bool  Unlock(void)
	{
		if SDL_MUSTLOCK(m_surface)
			SDL_UnlockSurface(m_surface);

		return true;
	}
	void* Handle(void) const
	{
		return m_surface;
	}
	unsigned long Color(unsigned char a, unsigned char r, unsigned char g, unsigned char b)
	{
		return SDL_MapRGBA(m_surface->format, r, g, b, a);
	}
	unsigned long Color(unsigned long absColor)
	{
		return SDL_MapRGBA(m_surface->format, Uint8(absColor>>16), Uint8(absColor>>8), Uint8(absColor>>0), Uint8(absColor>>24));
	}
};

class IGfxDeviceImpl: public avej::IGfxDevice
{
protected:
	avej::IGfxDevice::TDesc m_desc;
	SDL_Surface* backSurface;
	IGfxSurfaceImpl* backBuffer;

public:
	IGfxDeviceImpl(void)
	{
		// Initialize SDL
		if (SDL_Init (SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK) < 0)
		{
			fprintf (stderr, "Couldn't initialize SDL: %s\n", SDL_GetError ());
			exit(1);
		}
		// atexit (Terminate);

		SDL_WM_SetCaption("The Codex of another lore", "LoreRevive");

		SDL_ShowCursor(SDL_DISABLE);

		const SDL_VideoInfo* pVideoInfo = SDL_GetVideoInfo();

		if (pVideoInfo == NULL)
		{
			fprintf (stderr, "Couldn't query SDL: %s\n", SDL_GetError ());
			exit(1);
		}

		int flags = SDL_SWSURFACE;
//		flags |= SDL_FULLSCREEN;

		// Set 320x240 16-bits video mode
		backSurface = SDL_SetVideoMode(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_DEPTH, flags);
		if (backSurface == NULL)
		{
			fprintf (stderr, "Couldn't set %dx%dx%d video mode: %s\n", SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_DEPTH, SDL_GetError ());
			exit(2);
		}

		pVideoInfo = SDL_GetVideoInfo();
		backBuffer = new IGfxSurfaceImpl(backSurface);

		m_desc.width  = SCREEN_WIDTH;
		m_desc.height = SCREEN_HEIGHT;
		m_desc.pitch  = SCREEN_WIDTH;
		m_desc.depth  = SCREEN_DEPTH;
		m_desc.format = 0;
	}
	~IGfxDeviceImpl(void)
	{
		delete backBuffer;
	}

	bool  BeginDraw(void)
	{
		return true;
	};
	bool  EndDraw(void)
	{
		return true;
	};
	bool  Flip(void)
	{
		SDL_Flip((SDL_Surface*)backBuffer->Handle());
		return true;
	};
	bool  GetSurface(avej::IGfxSurface** ppSurface)
	{
		if (ppSurface == 0)
			return false;

		*ppSurface = backBuffer;

		return true;
	};
	bool  CreateSurface(int width, int height, avej::IGfxSurface** ppSurface)
	{
		if (ppSurface == 0)
			return false;

		SDL_Surface* pTempSurface = SDL_CreateRGBSurface(SDL_SWSURFACE, width, height, backSurface->format->BitsPerPixel,
			backSurface->format->Rmask, backSurface->format->Gmask, backSurface->format->Bmask, backSurface->format->Amask);

		IGfxSurfaceImpl* pGfxSurface = new IGfxSurfaceImpl(pTempSurface);

		*ppSurface = pGfxSurface;

		return true;
	};
    bool  CreateSurfaceFrom(const char* sz_file_name, avej::IGfxSurface** ppSurface)
	{
		if (ppSurface == 0)
			return false;
#if 0
		SDL_Surface* pConvSurface = SDL_LoadBMP(sz_file_name);
#else
		SDL_Surface* pTempSurface = SDL_LoadBMP(sz_file_name);
		SDL_Surface* pConvSurface = SDL_ConvertSurface(pTempSurface, backSurface->format, SDL_SWSURFACE);
		SDL_FreeSurface(pTempSurface);
#endif
		IGfxSurfaceImpl* pGfxSurface = new IGfxSurfaceImpl(pConvSurface);

		*ppSurface = pGfxSurface;

		return true;
	}
	bool  GetDesc(TDesc& desc)
	{
		desc = m_desc;
		return true;
	};

	static avej::IGfxDevice* pGfxImpl;
	static int refCount;
	static avej::IGfxDevice* GetInstance(void);
	static int Release(void);
};

avej::IGfxDevice* IGfxDeviceImpl::pGfxImpl = 0;
int IGfxDeviceImpl::refCount = 0;

avej::IGfxDevice* IGfxDeviceImpl::GetInstance(void)
{
	if (pGfxImpl == 0)
	{
    	pGfxImpl = new IGfxDeviceImpl;
	}

	++refCount;
	
	return pGfxImpl;
}

int IGfxDeviceImpl::Release(void)
{
	if (--refCount == 0)
		delete (IGfxDeviceImpl*)pGfxImpl;

	return refCount;
}

avej::IGfxDevice* avej::IGfxDevice::GetInstance(void)
{
	return IGfxDeviceImpl::GetInstance();
}

int avej::IGfxDevice::Release(void)
{
	return IGfxDeviceImpl::Release();
}
