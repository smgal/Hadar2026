
#ifndef __HD_CLASS_SERIALIZED_H__
#define __HD_CLASS_SERIALIZED_H__

#include "USmStream.h"

namespace hadar
{
	class Serialized
	{
		friend class SerializedStream;

	protected:
		virtual bool _load(const ReadStream& stream) = 0;
		virtual bool _save(const WriteStream& stream) const = 0;
	};

	class SerializedStream
	{
	public:
		enum STREAM_TYPE
		{
			STREAM_TYPE_READ,
			STREAM_TYPE_WRITE
		};

		SerializedStream(const char* sz_file_name, STREAM_TYPE stream_type);
		~SerializedStream(void);

		virtual void operator<<(const Serialized& stream);
		virtual void operator>>(Serialized& stream);

	private:
		ReadStream*  p_read_stream;
		WriteStream* p_write_stream;
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_SERIALIZED_H__
