
#include "USmSet.h"

#define NULL 0

namespace
{
	int strlen(const char* sz_str)
	{
		if (sz_str == NULL)
			return 0;

		char* p_ch = (char*)sz_str;
		int len = 0;

		while (*p_ch++)
			++len;

		return len;
	}

	char* strchr(const char* sz_str, char ch, int n)
	{
		if (sz_str == NULL)
			return NULL;

		char* p_ch = (char*)sz_str;

		while (*p_ch && --n >= 0)
		{
			if (*p_ch == ch)
				return p_ch;

			++p_ch;
		}

		return NULL;
	}

	int atoi(const char* sz_str, int n)
	{
		if (sz_str == NULL)
			return 0;

		char* p_ch = (char*)sz_str;
		int result = 0;

		while (*p_ch && --n >= 0)
		{
			if (*p_ch < '0' || *p_ch > '9')
				return 0;

			result = result * 10 + (*p_ch++ - '0');
		}

		return result;
	}

}

#define SET_SET(i) set[(i)/8] |= 1 << ((i)%8);

bool SmSet::m_makeSetArray(const char* sz_stream, Set& set)
{
	int i;

	for (i = 0; i < sizeof(set); i++)
		set[i] = 0;

	const char* sz_str = sz_stream;
	char* p_ch;

	while (p_ch = strchr(sz_str, ',', 100000))
	{
		char* p_ch2 = strchr(sz_str, '.', p_ch - sz_str);

		if (p_ch2 == NULL)
		{
			i = atoi(sz_str, p_ch - sz_str);
			SET_SET(i)
			sz_str = p_ch + 1; 
		}
		else
		{
			int iBegin = atoi(sz_str, p_ch2 - sz_str);
			int iEnd   = atoi(p_ch2+2, p_ch - p_ch2 - 2);

			for (int i = iBegin; i <= iEnd; i++)
				SET_SET(i)

			sz_str = p_ch + 1; 
		}
	}

	char* p_ch2 = strchr(sz_str, '.', 100000);

	if (p_ch2 == NULL)
	{
		i = atoi(sz_str, 100000);
		SET_SET(i)
	}
	else
	{
		int i_begin = atoi(sz_str, p_ch2 - sz_str);
		int i_end   = atoi(p_ch2+2, 100000);
		for (int i = i_begin; i <= i_end; i++)
			SET_SET(i)
	}

	return false;
}

SmSet::SmSet(void)
{
	for (int i = 0; i < sizeof(m_set); i++)
		m_set[i] = 0;
}

SmSet::SmSet(const char* sz_stream)
{
	this->assign(sz_stream);
}

void SmSet::assign(const char* sz_stream)
{
	int len = strlen(sz_stream);

	if (len > 0)
	{
		char* sz_text = new char[len+1];

		if (sz_text == NULL)
			return;

		char* p_dest = sz_text;

		for (int i = 0; i < len; i++)
		{
			if (sz_stream[i] != ' ')
				*p_dest++ = sz_stream[i];
		}

		*p_dest = 0;

		this->m_makeSetArray(sz_text, m_set);

		delete[] sz_text;
	}
}

///////////////////////////////////////

#if 0

#include <windows.h>
#include <stdio.h>

void CSet_test()
{
	char* sz_string[] = 
	{
		"9..12,17,13,100,180..185,255",
		"0,9..12,17,13,100,180..185,255",
		"255,0, 9..12, 17, 13,100,180..185",
	};

	for (int loop = 0; loop < sizeof(sz_string) / sizeof(sz_string[0]); loop++)
	{
		char s[256];

		sprintf(s, "+++ loop = %d\n", loop);
		OutputDebugString(s);

		OutputDebugString("source string: ");
		OutputDebugString(sz_string[loop]);
		OutputDebugString("\n");

		SmSet set(sz_string[loop]);

		for (int i = 0; i < 256; i++)
		{
			if (set.IsSet(i))
			{
				sprintf(s, "%d, ", i);
				OutputDebugString(s);
			}
		}
		OutputDebugString("\n");
	}
}

#endif
