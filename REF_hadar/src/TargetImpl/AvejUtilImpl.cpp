
#include <SDL.h>

#include "AvejConfig.h"
#include "UAvejUtil.h"

using namespace avej;

unsigned long AvejUtil::GetTicks(void)
{
	return SDL_GetTicks();
}

void AvejUtil::Delay(unsigned long msec)
{
	SDL_Delay(msec);
}

static unsigned long holdrand = 0L;

int AvejUtil::random(int range)
{
	if (range <= 0)
		return 0;

	holdrand = holdrand * 214013L + 2531011L;
	return ((holdrand >> 16) & 0x7fff) % range;
}


