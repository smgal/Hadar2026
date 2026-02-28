
#include "util_convert_to_ucs.h"

////////////////////////////////////////////////////////////////////////////////
// external

namespace hadar
{
	namespace util
	{
		unsigned short UHC_TO_UCS2_TABLE_0[];
		unsigned short UHC_TO_UCS2_TABLE_1[];
		unsigned short UHC_TO_UCS2_TABLE_2[];
		unsigned short UHC_TO_UCS2_TABLE_3[];
	}
}

////////////////////////////////////////////////////////////////////////////////
// internal

using hadar::util::Ucs2;

namespace
{
	struct ConvertInfoTable
	{
		unsigned char   min_Lo_byte;
		unsigned char   max_Lo_byte;
		unsigned char   min_hi_byte;
		unsigned char   max_hi_byte;
		unsigned short* p_table;
	};

	const ConvertInfoTable CONVERT_INFO_TABLE[] =
	{
		{ 0x41, 0x5A, 0x81, 0xC6, hadar::util::UHC_TO_UCS2_TABLE_0 },
		{ 0x61, 0x7A, 0x81, 0xC5, hadar::util::UHC_TO_UCS2_TABLE_1 },
		{ 0x81, 0xA0, 0x81, 0xC5, hadar::util::UHC_TO_UCS2_TABLE_2 },
		{ 0xA1, 0xFE, 0x81, 0xFD, hadar::util::UHC_TO_UCS2_TABLE_3 }
	};

	long fetchUHC(const char*& p_src, const char* p_end)
	{
		unsigned long result;

		if (*p_src & 0x80)
		{
			if (p_src+1 >= p_end)
				return -1;

			result = (unsigned char)(*p_src++);
			result = (result << 8) | (unsigned char)(*p_src++);
		}
		else
		{
			if (p_src >= p_end)
				return -1;

			result = *p_src++;
		}

		return long(result);
	}

	Ucs2 convertUhcToUcs2(unsigned char byte1, unsigned char byte2, Ucs2 default_character)
	{
		if (byte1 & 0x80)
		{
			for (unsigned int ix_table = 0; ix_table < sizeof(CONVERT_INFO_TABLE) / sizeof(CONVERT_INFO_TABLE[0]); ix_table++)
			{
				const ConvertInfoTable& table = CONVERT_INFO_TABLE[ix_table];

				if ((byte2 >= table.min_Lo_byte) && (byte2 <= table.max_Lo_byte)
					&& (byte1 >= table.min_hi_byte) && (byte1 <= table.max_hi_byte))
				{
					byte2 -= table.min_Lo_byte;
					byte1 -= table.min_hi_byte;

					return table.p_table[byte1 * (table.max_Lo_byte - table.min_Lo_byte + 1) + byte2];
				}
			}

			return default_character;
		}
		else
		{
			return Ucs2(byte1);
		}

	}
}

////////////////////////////////////////////////////////////////////////////////
// public

Ucs2* hadar::util::convertUhcToUcs2(Ucs2* p_dst, int dst_size, const char* p_src, int src_size, Ucs2 default_character)
{
	if ((p_dst == 0) || (dst_size <= 0) || (p_src == 0) || (src_size <= 0))
		return 0;

	const char* p_src_end = p_src + src_size;
	Ucs2*       p_dst_end = p_dst + dst_size;

	while (p_dst < p_dst_end)
	{
		long data = fetchUHC(p_src, p_src_end);

		if (data >= 0)
		{
			if (data < 0x80)
			{
				*p_dst++ = Ucs2(data);
			}
			else
			{
				unsigned char lo_byte = data & 0xFF;
				unsigned char hi_byte = (data >> 8) & 0xFF;

				*p_dst = default_character;

				for (unsigned int ix_table = 0; ix_table < sizeof(CONVERT_INFO_TABLE) / sizeof(CONVERT_INFO_TABLE[0]); ix_table++)
				{
					const ConvertInfoTable& table = CONVERT_INFO_TABLE[ix_table];

					if ((lo_byte >= table.min_Lo_byte) && (lo_byte <= table.max_Lo_byte) &&
					    (hi_byte >= table.min_hi_byte) && (hi_byte <= table.max_hi_byte))
					{
						lo_byte  -= table.min_Lo_byte;
						hi_byte  -= table.min_hi_byte;
						*p_dst++  = table.p_table[hi_byte * (table.max_Lo_byte - table.min_Lo_byte + 1) + lo_byte];
						break;
					}
				}
			}
			continue;
		}
		break;
	}

	return p_dst;
}
