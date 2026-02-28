
#include "hd_class_game_option.h"

////////////////////////////////////////////////////////////////////////////////
// serializing method

bool hadar::GameOption::_load(const ReadStream& stream)
{
	bool result = (stream.Read((void*)&flag, sizeof(flag)) == sizeof(flag)) &&
	              (stream.Read((void*)&variable, sizeof(variable)) == sizeof(variable)) &&
	              (stream.Read((void*)&script_file, sizeof(script_file)) == sizeof(script_file));
	return result;
}

bool hadar::GameOption::_save(const WriteStream& stream) const
{
	bool result = (stream.Write((void*)&flag, sizeof(flag)) == sizeof(flag)) &&
	              (stream.Write((void*)&variable, sizeof(variable)) == sizeof(variable)) &&
	              (stream.Write((void*)&script_file, sizeof(script_file)) == sizeof(script_file));
	return result;
}

////////////////////////////////////////////////////////////////////////////////
// public method

