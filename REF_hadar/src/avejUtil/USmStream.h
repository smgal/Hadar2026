
#ifndef __USMSTREAM_H__
#define __USMSTREAM_H__

#include <stdio.h>

////////////////////////////////////////////////////////////////////////////////
// ReadStream class

class ReadStream
{ 
public:
	ReadStream(void): m_isAvailable(false) { };
	virtual ~ReadStream(void) { };

	bool          isValid(void) const { return m_isAvailable; };
	virtual long  Read(void* pBuffer, long Count) const = 0;
	virtual long  Seek(long Offset, unsigned short Origin) const = 0;
	virtual long  GetSize(void) const = 0;
	virtual void* GetPointer(void) = 0;
	virtual bool  IsValidPos(void) const = 0;

protected:
	bool m_isAvailable;
};

class CFileReadStream : public ReadStream
{
public:
	CFileReadStream(const char* sz_file_name);
	~CFileReadStream(void);

private:
	FILE* m_pFile;

public:
	long  Read(void* pBuffer, long Count) const;
	long  Seek(long Offset, unsigned short Origin) const;
	long  GetSize(void) const;
	void* GetPointer(void) { return NULL; };
	bool  IsValidPos(void) const;
};

class CMemoryReadStream : public ReadStream
{
public:
	CMemoryReadStream(void* pMemory, long size);
	~CMemoryReadStream(void) {;};

private:
	void* m_pMemory;
	long  m_Size;
	mutable long  m_Position;

public:
	long  Read(void* pBuffer, long Count) const;
	long  Seek(long Offset, unsigned short Origin) const;
	long  GetSize(void) const;
	void* GetPointer(void);
	bool  IsValidPos(void) const;
};

////////////////////////////////////////////////////////////////////////////////
// WriteStream class

class WriteStream
{ 
public:
	WriteStream(void): m_isAvailable(false) { };
	virtual ~WriteStream(void) { ; };

	bool          isValid(void) const { return m_isAvailable; };
	virtual long  Write(void* pBuffer, long Count) const = 0;

protected:
	bool m_isAvailable;
};

class CFileWriteStream : public WriteStream
{
public:
	CFileWriteStream(const char* sz_file_name);
	~CFileWriteStream(void);

private:
	FILE* m_pFile;

public:
	long  Write(void* pBuffer, long Count) const;
};

////////////////////////////////////////////////////////////////////////////////
// CTextFileHolder class

class CTextFileHolder
{
public:
	CTextFileHolder();
	CTextFileHolder(const char* p_buffer, int size);
	~CTextFileHolder();

	void Reset(const char* p_buffer, int size);
	int  GetLineCount(void) const;
	int  GetLineLength(int index) const;
	bool GetLine(int index, char* out_str, int str_size) const;

private:
	struct TImpl;
	TImpl* m_p_impl;
};

#endif // #ifndef __USMSTREAM_H__
