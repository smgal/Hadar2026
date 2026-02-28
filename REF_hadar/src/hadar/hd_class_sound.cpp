
#include "hd_class_sound.h"

void hadar::sound::playFx(SOUND ixSound)
{
	if ((ixSound < 0) || (ixSound >= SOUND_MAX))
		return;

	//?? index에 해당하는 효과음을 출력

	return;
}

void hadar::sound::muteFx(bool on)
{
	//?? 언젠가는 처리해야 함
}
