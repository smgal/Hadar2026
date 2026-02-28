
#include "hd_class_serialized.h"

hadar::SerializedStream::SerializedStream(const char* sz_file_name, STREAM_TYPE stream_type)
	: p_read_stream(0)
	, p_write_stream(0)
{
	switch (stream_type)
	{
	case STREAM_TYPE_READ:
		p_read_stream = new CFileReadStream(sz_file_name);
		break;
	case STREAM_TYPE_WRITE:
		p_write_stream = new CFileWriteStream(sz_file_name);
		break;
	}
}

hadar::SerializedStream::~SerializedStream(void)
{
	delete p_read_stream;
	delete p_write_stream;
}

void hadar::SerializedStream::operator<<(const Serialized& stream)
{
	if (p_write_stream)
		stream._save(*p_write_stream);
}

void hadar::SerializedStream::operator>>(Serialized& stream)
{
	if (p_read_stream)
		stream._load(*p_read_stream);
}
