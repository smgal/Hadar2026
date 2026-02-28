
#ifndef __AVEJ_CONFIG_H
#define __AVEJ_CONFIG_H

#pragma warning (disable: 4996)

#include "UAvejPixelFormat.h"

#ifdef GP2X
#define SCREEN_WIDTH   320
#define SCREEN_HEIGHT  240
#else
#define SCREEN_WIDTH   800//480
#define SCREEN_HEIGHT  480//360
#endif

#define SCREEN_DEPTH   16

#define ENABLE_MEMORY_MANAGER

#ifdef _WIN32
#ifdef _MSVC

#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>
//#define new new(_NORMAL_BLOCK, __FILE__, __LINE__)

#undef  ENABLE_MEMORY_MANAGER
#define ENABLE_MEMORY_MANAGER _CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);

#endif
#endif

#endif // #ifndef __AVEJ_CONFIG_H
