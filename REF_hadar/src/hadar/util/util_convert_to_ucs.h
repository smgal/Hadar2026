
#ifndef __UTIL_CONVERT_TO_UCS_H__
#define __UTIL_CONVERT_TO_UCS_H__

namespace hadar
{
	namespace util
	{
		typedef unsigned short Ucs2;

		Ucs2* convertUhcToUcs2(Ucs2* sz_dst, int dst_size, const char* sz_src, int src_size, Ucs2 default_character = 0x0020);
	}
}

#endif
