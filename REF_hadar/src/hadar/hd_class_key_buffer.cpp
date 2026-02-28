
#include "hd_class_key_buffer.h"

#include <string.h>

#define CLEAR_MEMORY(var) memset(var, 0, sizeof(var));

hadar::KeyBuffer::KeyBuffer(void)
	: m_key_head_ptr(0)
	, m_key_tail_ptr(0)
{
	CLEAR_MEMORY(m_key_buffer);
	CLEAR_MEMORY(m_key_buffer);
}

hadar::KeyBuffer::~KeyBuffer(void)
{
}

namespace
{
	hadar::KeyBuffer s_key_buffer;
}

hadar::KeyBuffer& hadar::KeyBuffer::getKeyBuffer(void)
{
	return s_key_buffer;
}
