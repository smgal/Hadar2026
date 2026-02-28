
#ifndef __HD_BASE_TYPE_H__
#define __HD_BASE_TYPE_H__

#include "AvejConfig.h"
#include "UAvejGfx.h"

////////////////////////////////////////////////////////////////////////////////
// macro definition

#define CLEAR_MEMORY(var) memset(var, 0, sizeof(var));

#if defined(_WIN32)
	#if defined(_DEBUG)
		extern "C" void __stdcall OutputDebugStringA(const char* lpOutputString);
		#define ASSERT(cond) \
			if (!(cond)) \
			{ \
				char sz_temp[1024]; \
				SPRINTF(sz_temp, 1024, "%s(%d): Assertion Failed\n", __FILE__, __LINE__ ); \
				::OutputDebugStringA(sz_temp); \
				assert(false);\
			}
	#else
		#define ASSERT
	#endif
#else
	#if defined(_DEBUG)
		#define ASSERT(cond) \
			if (!(cond)) \
			{ \
				char sz_temp[1024]; \
				SPRINTF(sz_temp, 1024, "%s(%d): Assertion Failed\n", __FILE__, __LINE__ ); \
				hadar::_makeFile("./assertion.txt", sz_temp); \
				assert(false);\
			}
	#else
		#define ASSERT assert
	#endif
#endif

namespace hadar
{
	extern avej::IGfxDevice*  p_gfx_device;
	extern avej::IGfxSurface* p_back_buffer;
	extern avej::IGfxSurface* p_tile_image;
	extern avej::IGfxSurface* p_sprite_image;
	extern avej::IGfxSurface* p_font_image;

	////////////////////////////////////////////////////////////////////////////////
	// extern definition

	void _makeFile(const char* sz_file_name, const char* sz_contents = NULL);

	////////////////////////////////////////////////////////////////////////////////
	// Exception class

	class Exception
	{
	};

	class ExceptionExitGame: public Exception
	{
	};

} // namespace hadar

#endif // #ifndef __HD_BASE_TYPE_H__
