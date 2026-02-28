
#ifndef __USMSCRIPT_H__
#define __USMSCRIPT_H__

#include <assert.h>
#include "UAvejUtil.h"
#include "USmStream.h"

struct SmResult
{
	char  type;
	int   data;
	avej::string sz_str;
};

struct SmParam
{
	char*    type;
	int*     data;
	char**   string;
	SmResult result;
/*
	SmParam(char* _type, int* _data, char** _string)
		: type(_type), data(_data), string(_string)
	{
	}
*/
};

////////////////////////////////////

#pragma warning(disable: 4786)

#include <string>
#include <map>
#include <stack>

template <class _type>
class SmScriptFunction
{
public:
	typedef void (_type::*FnLink)(SmParam*);
	typedef std::map<std::string, FnLink> TSmFunctionMap;
	TSmFunctionMap m_functionMap;
	_type* m_pThis;

	SmScriptFunction(void)
		: m_pThis(0)
	{
	}
	void SetScript(_type* pThis)
	{
		m_pThis = pThis;
	}
	bool IsNotInitialized(void)
	{
		return m_functionMap.empty();
	}
	bool RegisterFunction(const char* sz_name, FnLink function)
	{
		if (sz_name == 0 || function == 0)
			return false;

		m_functionMap[sz_name] = function;

		return true;
	}
	bool UnregisterFunction(const char* sz_name)
	{
		if (sz_name == 0)
			return false;

		typename TSmFunctionMap::iterator i = m_functionMap.find(sz_name);
		if (i == m_functionMap.end())
			return false;

		m_functionMap.erase(i);

		return true;
	}
	bool ExecuteFunction(const char* sz_name, SmParam* p_param)
	{
		if ((m_pThis == 0) || (sz_name == 0))
			return false;

		typename TSmFunctionMap::iterator i = m_functionMap.find(sz_name);
		if (i == m_functionMap.end())
			return false;

		(m_pThis->*(i->second))(p_param);

		return true;
	}
};

////////////////////////////////////

#include <stdio.h>
#include <string.h>

template <class _type>
class CSmScript
{
	enum {MAX_STRING = 256*8};
	enum {MAX_PARAM  = 10};

	typedef std::map<std::string, int> TSmVariableMap;

	bool            m_bNotTerminated;
	const char*     m_szFileName;
	int             m_line;
	TSmVariableMap  m_variableMap;
	SmScriptFunction<_type>&  m_scriptFunction;

	char* SearchDelimiter(char* src, char delimiter)
	{
		char* dst  = src;
		bool  inQM = false;
		while ((*dst) && (*dst != delimiter))
		{
			char ch = *dst;
			if (ch == '"')
				inQM = !inQM;
			else if ((ch == delimiter) && (!inQM))
				break;
			++dst;
		}

		return (*dst == delimiter) ? dst : 0;
	}

	char* SearchDelimiter2(char* src, char delimiter)
	{
		char* dst  = src;
		bool  inQM = false;
		int   inPR = 0;
		while (*dst)
		{
			char ch = *dst;
			if (ch == '"')
				inQM = !inQM;
			else if (ch == '(')
				++inPR;
			else if (ch == ')')
				--inPR;
			else if ((ch == delimiter) && (!inQM) && (inPR == 0))
				break;
			++dst;
		}

		return (*dst == delimiter) ? dst : 0;
	}

	int GetLevel(const char* szSrc)
	{
		int level = 0;

		--szSrc;
		while (*(szSrc++ + 1) == 9)
			++level;

		return level;
	}
	
	bool Parse(const char* szSrc, char* szDst, int& level)
	{
		char* _szDst = szDst;
		level = 0;

		--szSrc;
		while (*(szSrc++ + 1) == 9)
			++level;

		bool  inQM = false;
		unsigned short ch;
		while ((ch = (unsigned short)(*szSrc++)) > 26)
		{
			if (ch == '"')
				inQM = !inQM;
			else if ((ch == ' ') && (!inQM))
				continue;
			*szDst++ = ch;
		}
		*szDst = 0;

		// 마지막의 ';' 제거
		while (_szDst < szDst)
		{
			if (*(szDst-1) == ';') 
			{
				*(--szDst) = 0;
				continue;
			}
			break;
		}

		return (_szDst < szDst);
	}

	void Extract(char* szSrc, char* szParam[], int maxParam)
	{
		szParam[0] = szSrc;

		szSrc = SearchDelimiter(szSrc, '(');
		if (szSrc == 0)
		{
			szParam[1] = 0;
			return;
		}

		szSrc[strlen(szSrc)-1] = 0;
		*szSrc++ = 0;

		int index = 1;

		// aaa.bbb 형태를 파싱하여 bbb는 함수 이름으로 aaa는 첫 번째 파라미터로 변경
		{
			char* sz_temp = szParam[0];
			sz_temp = SearchDelimiter(sz_temp, '.');
			if (sz_temp)
			{
				*sz_temp++ = 0;
				szParam[1] = szParam[0];
				szParam[0] = sz_temp; 
				++index;
			}
		}

		do
		{
			szParam[index++] = szSrc;
			assert(index < maxParam);
			szSrc = SearchDelimiter2(szSrc, ',');
			if (szSrc == 0)
				break;
			*szSrc++ = 0;
		} while (1);
		szParam[index] = 0;
	}

	SmResult ExecuteNative(char type[], int data[], char* string[])
	{
		SmParam param;
		param.type = type;
		param.data = data;
		param.string = string;
		param.result.type   = 'i';
		param.result.data   = 0;

		if (strcmp(string[0], "if") == 0)
		{
			param.result.data = data[1];
			return param.result;
		}

		if (strcmp(string[0], "while") == 0)
		{
			param.result.data = data[1];
			return param.result;
		}

		if (strcmp(string[0], "assign") == 0)
		{
			TSmVariableMap::iterator i = m_variableMap.find(string[1]);
			assert(i != m_variableMap.end());

			i->second = data[2];

			param.result.data = 1;

			return param.result;
		}

		if (strcmp(string[0], "add") == 0)
		{
			TSmVariableMap::iterator i = m_variableMap.find(string[1]);
			assert(i != m_variableMap.end());

			i->second += data[2];

			param.result.data = 1;

			return param.result;
		}

		if (strcmp(string[0], "halt") == 0)
		{
			m_bNotTerminated = false;
			return param.result;
		}

		if (!m_scriptFunction.ExecuteFunction(string[0], &param))
		{
			TSmVariableMap::iterator i = m_variableMap.find(string[0]);
			if (i == m_variableMap.end())
			{
				printf("## syntax error: %s(%d) - '%s'\n", m_szFileName, m_line, string[0]);
				assert(false);
				m_variableMap[string[0]] = 0;
				i = m_variableMap.find(string[0]);
			}

			param.result.data  = i->second;
			param.result.sz_str = string[0];
		}

		return param.result;
	}

	SmResult ExecuteCommand(char* szParam[])
	{
		char paramType[MAX_PARAM];
		int  paramData[MAX_PARAM];
		avej::string stringTemplate[MAX_PARAM];

		memset(paramType, 0, sizeof(paramType));
		memset(paramData, 0, sizeof(paramData));

		if (strcmp(szParam[0], "include") == 0)
		{
			if (szParam[1])
			{
				int len = strlen(szParam[1]);
				if ((len > 2) && (szParam[1][0] == '"') && (szParam[1][len-1] == '"'))
				{
					// 따옴표 제거
					szParam[1][len-1] = 0;

					SmResult result;
					result.type = 'x';
					result.sz_str = &szParam[1][1]; 
					return result;
				}
			}
		}

		if (strcmp(szParam[0], "variable") == 0)
		{
			m_variableMap[szParam[1]] = 0;
			SmResult result;
			result.type = 'i';
			result.data = 1;
			return result;
		}

		for (int n = 1; szParam[n]; n++)
		{
			int len = strlen(szParam[n]);

			if ((szParam[n][0] == '"') && (szParam[n][len-1] == '"'))
			{
				paramType[n] = 's';
				szParam[n][len-1] = 0;
				++szParam[n];
			}
			else
			{
				int index = 0;
				int sign  = 1;

				char ch = szParam[n][index];

				if ((ch == '+') || (ch == '-'))
				{
					if (ch == '-')
					sign = -1;
					++index;
				}

				int sum   = 0;
				while ((ch = szParam[n][index]))
				{
					if ((ch < '0') || (ch > '9'))
					{
						sign = 0;
						break;
					}
					sum *= 10;
					sum += ch - '0';
					++index;
				}

				if (sign)
				{
					paramType[n] = 'i';
					paramData[n] = sum * sign;
				}
				else
				{
					SmResult result = ExcuteStream(szParam[n]);
					paramType[n] = result.type;
					paramData[n] = result.data;
					stringTemplate[n] = result.sz_str;
					//!!
					szParam[n]        = (char*)(const char*)stringTemplate[n];
				}
			}

		}
		return ExecuteNative(paramType, paramData, szParam);
	}

	SmResult ExcuteStream(char* szSrc)
	{
		char* paramList[MAX_PARAM];
		Extract(szSrc, paramList, MAX_PARAM);
		return ExecuteCommand(paramList);
	}

public:
	CSmScript(SmScriptFunction<_type>& scriptFunction, const char* sz_file_name)
	: m_bNotTerminated(true), m_szFileName(sz_file_name), m_line(0), m_scriptFunction(scriptFunction)
	{
		typedef std::pair<avej::string, int> TFileStackData;
		typedef std::stack<TFileStackData> TFileStack;

		TFileStack fileStack;
		fileStack.push(std::make_pair(sz_file_name, 0));

		while (!fileStack.empty())
		{
			TFileStackData data = fileStack.top();
			fileStack.pop();
///
			CFileReadStream file_stream(data.first);

			if (!file_stream.isValid())
				continue;

			CTextFileHolder text_holder;

			{
				int   file_size = file_stream.GetSize();
				char* p_buffer  = new char[file_size];

				file_stream.Read(p_buffer, file_size);

				text_holder.Reset(p_buffer, file_size);

				delete[] p_buffer;
			}

			int current_line = data.second;
///
/*
			FILE* file = fopen(data.first, "rt");
			if (file == 0)
				continue;

			fseek(file, data.second, SEEK_SET);
*/
			char  srcBuf[MAX_STRING];
			char  modBuf[MAX_STRING];
			int   curLevel = 0;
			int   skipLevel = -1;
			int   level;

			--current_line; 
			while (current_line < text_holder.GetLineCount() && m_bNotTerminated)
			{
				++m_line;
				++current_line; 

				if (!text_holder.GetLine(current_line, srcBuf, MAX_STRING))
					continue;
				if ((skipLevel > 0) && (GetLevel(srcBuf) >= skipLevel))
					continue;
				if (!Parse(srcBuf, modBuf, level))
					continue;
				if (modBuf[0] == '#')
					continue;

				if (skipLevel > 0)
				{
					if (strcmp(modBuf, "else") == 0)
					{
						curLevel  = level+1;
						skipLevel = (level == skipLevel-1) ? -1 : level+1;
						continue;
					}
					curLevel  = level;
					skipLevel = -1;
				}
				else if (level < curLevel)
				{
					if (strcmp(modBuf, "else") == 0)
					{
						skipLevel = level+1;
						continue;
					}
					curLevel = level;
				}

				SmResult result = ExcuteStream(modBuf);
				if (result.type == 'i')
				{
					if (result.data)
					{
						++curLevel;
					}
					else
					{
						skipLevel = curLevel+1;
					}
				}
				if (result.type == 'x')
				{
					// include
					fileStack.push(std::make_pair(data.first, current_line + 1));
					fileStack.push(std::make_pair(result.sz_str, 0));
					break;
				}
			}
		}
	}
};

#endif // #ifndef __USMSCRIPT_H__
