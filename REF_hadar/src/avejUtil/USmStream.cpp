
#include "USmStream.h"
#include <memory.h>
#include "avej2_util_sena.h"

/***************************************************
                   CFileReadStream
***************************************************/

CFileReadStream::CFileReadStream(const char* sz_file_name)
{
	m_pFile = fopen(sz_file_name, "rb");

	this->m_isAvailable = (m_pFile != 0);
}

CFileReadStream::~CFileReadStream(void)
{
	if (this->m_isAvailable)
		fclose(m_pFile);
}

long CFileReadStream::Read(void* pBuffer, long count) const
{
	if (!this->m_isAvailable)
		return 0;

	return fread(pBuffer, 1, count, m_pFile);
}

long CFileReadStream::Seek(long Offset, unsigned short Origin) const
{
	if (!this->m_isAvailable)
		return -1;

	switch (Origin)
	{
	case SEEK_SET:
	case SEEK_CUR:
	case SEEK_END:
		fseek(m_pFile, Offset, Origin);
		break;
	default:
		return -1;
	}

	return ftell(m_pFile);
}

long CFileReadStream::GetSize(void) const
{
	if (!this->m_isAvailable)
		return -1;

	long  Result;
	long  CurrentPos = ftell(m_pFile);

	fseek(m_pFile, 0, SEEK_END);
	Result = ftell(m_pFile);

	fseek(m_pFile, CurrentPos, SEEK_SET);

	return Result;
}

bool CFileReadStream::IsValidPos(void) const
{
	if (!this->m_isAvailable)
		return false;

	return (feof(m_pFile) == 0);
}

/***************************************************
                   CMemoryReadStream
***************************************************/

CMemoryReadStream::CMemoryReadStream(void* pMemory, long size)
{
	m_pMemory   = pMemory;
	m_Size      = size;
	m_Position  = 0;
	m_isAvailable = (m_pMemory != NULL);
}

long CMemoryReadStream::Read(void* pBuffer, long count) const
{
	if (!this->m_isAvailable)
		return -1;

	long  Result;

	if ((m_Position >= 0) && (count >= 0 ))
	{
		Result = m_Size - m_Position;
		if (Result > 0)
		{
			if (Result > count)
				Result = count;

			memcpy(pBuffer, (char*)m_pMemory + m_Position, Result);

			m_Position += Result;

			return Result;
		}
	}

	return 0;
}

long CMemoryReadStream::Seek(long Offset, unsigned short Origin) const
{
	if (!this->m_isAvailable)
		return -1;

	switch (Origin)
	{
	case SEEK_SET:
		m_Position = Offset;
		break;
	case SEEK_CUR:
		m_Position += Offset;
		break;
	case SEEK_END:
		m_Position = m_Size + Offset;
		break;
	default:
		return -1;
	}

	// 특별한 범위 체크 안함
	return m_Position;
}

long CMemoryReadStream::GetSize(void) const
{
	if (!this->m_isAvailable)
		return -1;

	return m_Size;
}

void *CMemoryReadStream::GetPointer(void)
{
	if (!this->m_isAvailable)
		return NULL;

	return m_pMemory;
}

bool CMemoryReadStream::IsValidPos(void) const
{
	if (!this->m_isAvailable)
		return false;

	return ((m_Position >= 0) && (m_Position < m_Size));
}

/***************************************************
                   CFileWriteStream
***************************************************/

CFileWriteStream::CFileWriteStream(const char* sz_file_name)
{
	m_pFile = fopen(sz_file_name, "wb");

	this->m_isAvailable = (m_pFile != 0);
}

CFileWriteStream::~CFileWriteStream(void)
{
	if (this->m_isAvailable)
		fclose(m_pFile);
}

long CFileWriteStream::Write(void* pBuffer, long count) const
{
	if (!this->m_isAvailable)
		return 0;

	return fwrite(pBuffer, 1, count, m_pFile);
}


////////////////////////////////////////////////////////////////////////////////
// class CTextFileHolder

struct CTextFileHolder::TImpl
{
public:
	TImpl(const char* p_buffer, int size)
		: m_p_buffer(0), m_p_buffer_end(0)
	{
		if (size > 0)
		{
			m_p_buffer = new char[size+2];

			if (m_p_buffer)
			{
				sena::copy(p_buffer, p_buffer+size, m_p_buffer);
				m_p_buffer[size+0] = 0x0D;
				m_p_buffer[size+1] = 0x0A;

				m_p_buffer_end = m_p_buffer + (size+2);

				char* p_current = m_p_buffer;

				while (p_current < m_p_buffer_end)
				{
					m_line.push_back(p_current);

					while (p_current < m_p_buffer_end && *p_current != 0x0D)
						++p_current;

					if (p_current < m_p_buffer_end)
						*p_current = 0;

					while (p_current < m_p_buffer_end && *p_current != 0x0A)
						++p_current;

					if (p_current < m_p_buffer_end)
						*p_current++ = 0;
				}
			}
		}
	}

	~TImpl()
	{
		delete m_p_buffer;
	}

	int GetLineCount(void) const
	{
		return m_line.size()-1;
	}

	int GetLineLength(int index) const
	{
		if (index < 0 || index >= (m_line.size()-1))
			return 0;

		return (m_line[index+1] - m_line[index]) - 2;
	}

	bool GetLine(int index, char* p_out_str, int str_size) const
	{
		if (index < 0 || index >= (m_line.size()-1))
			return false;

		sena::strncpy(p_out_str, m_line[index], str_size);
		
		return true;
	}

private:
	char* m_p_buffer;
	char* m_p_buffer_end;

	sena::vector<char*> m_line;
};

CTextFileHolder::CTextFileHolder()
: m_p_impl(0)
{
}

CTextFileHolder::CTextFileHolder(const char* p_buffer, int size)
: m_p_impl(new TImpl(p_buffer, size))
{
}

CTextFileHolder::~CTextFileHolder()
{
	delete m_p_impl;
}

void CTextFileHolder::Reset(const char* p_buffer, int size)
{
	delete m_p_impl;

	m_p_impl = new TImpl(p_buffer, size);
}

int CTextFileHolder::GetLineCount(void) const
{
	return (m_p_impl) ? m_p_impl->GetLineCount() : 0;
}

int CTextFileHolder::GetLineLength(int index) const
{
	return (m_p_impl) ? m_p_impl->GetLineLength(index) : 0;
}

bool CTextFileHolder::GetLine(int index, char* p_out_str, int str_size) const
{
	return (m_p_impl) ? m_p_impl->GetLine(index, p_out_str, str_size) : false;
}
