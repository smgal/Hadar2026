
#ifndef __AVEJ_UTIL_H
#define __AVEJ_UTIL_H

#include "avej2_util_sena.h"

#include <string.h>
#include <stdio.h>

////////////////////////////////////////////////////////////////////////////////
// definition

#if 1
#define CT_ASSERT(x, msg) \
		typedef int __CT_ASSERT ## msg ## __ [(x) ? 1 : -1];
#else
#define CT_ASSERT(x, msg)
#endif

#if defined(_WIN32)
#	define SPRINTF _snprintf
#else
#	define SPRINTF snprintf
#endif

////////////////////////////////////////////////////////////////////////////////
// namespace

namespace avej
{

class AvejUtil
{
public:
	static unsigned long GetTicks(void);
	static void Delay(unsigned long msec);
	static int  random(int range);
};

class IntToStr
{
	char m_s[32];
public:
	IntToStr(int value)
	{
		SPRINTF(m_s, 32, "%d", value);
	}
	const char* operator()(void)
	{
		return m_s;
	}
};

#define MAX_STRLEN 255 

class string
{
private:
	char m_string[MAX_STRLEN+1];

public:
	string(void)
	{
		m_string[0] = 0;
	}
	string(const char* lpsz)
	{      
		sena::strncpy(m_string, lpsz, MAX_STRLEN);
	}

	operator const char*() const
	{
		return m_string;
	};

	const string& operator=(const char* lpsz)
	{      
		sena::strncpy(m_string, lpsz, MAX_STRLEN);
		return *this;
	}

	const string& operator+=(const char* lpsz)
	{      
		strncat(m_string, lpsz, MAX_STRLEN);
		return *this;
	}

	void copyToFront(const string& lpsz)
	{      
		char m_temp[MAX_STRLEN+1];
		sena::strncpy(m_temp, m_string, MAX_STRLEN);
		sena::strncpy(m_string, lpsz.m_string, MAX_STRLEN);
		strncat(m_string, m_temp, MAX_STRLEN);
	}
};

}

#endif // #ifndef __AVEJ_UTIL_H
