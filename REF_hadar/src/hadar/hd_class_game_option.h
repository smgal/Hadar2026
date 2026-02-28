
#ifndef __HD_CLASS_GAME_OPTION_H__
#define __HD_CLASS_GAME_OPTION_H__

#include "USmSola.h"
#include "hd_class_serialized.h"
#include "UAvejUtil.h"

namespace hadar
{
	struct GameOption: public Serialized
	{
		enum
		{
			MAX_FLAG     = 256,
			MAX_VARIABLE = 256
		};

		sola::boolflag<MAX_FLAG> flag;
		sola::intflag<unsigned char, MAX_VARIABLE> variable;
		avej::string script_file;

	protected:
		bool _load(const ReadStream& stream);
		bool _save(const WriteStream& stream) const;
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_GAME_OPTION_H__
