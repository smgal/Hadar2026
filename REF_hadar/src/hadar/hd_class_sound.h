
#ifndef __HD_CLASS_SOUND_H__
#define __HD_CLASS_SOUND_H__

namespace hadar
{
	namespace sound
	{
		enum SOUND
		{
			SOUND_HIT   = 0,
			SOUND_SCREAM1,
			SOUND_SCREAM2,
			SOUND_MAX
		};

		void playFx(SOUND ixSound);
		void muteFx(bool on);

	} // namespace sound

} // namespace hadar

#endif // #ifndef __HD_CLASS_SOUND_H__
