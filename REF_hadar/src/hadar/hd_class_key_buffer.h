
#ifndef __HD_CLASS_KEY_BUFFER_H__
#define __HD_CLASS_KEY_BUFFER_H__

#include "AvejConfig.h"
#include "UAvejApp.h"

namespace hadar
{
	//! Key event를 DOS 때의 key buffer 형식으로 만들어 주는 class
	/*!
	 * \ingroup AVEJ library utilities
	*/
	class KeyBuffer
	{
		//! Key의 타입
		typedef avej::UINT16 Key;

		//! 버퍼의 최대 queue 크기
		enum
		{
			MAX_KEY_BUFFER = 100
		};

		avej::INT32 m_key_head_ptr;
		avej::INT32 m_key_tail_ptr;
		Key         m_key_buffer[MAX_KEY_BUFFER];
		avej::INT32 m_key_map[avej::KEY_MAX_VALUE];

		avej::INT32 m_increasePtr(avej::INT32 ptr)
		{
			if (++ptr >= 100)
				ptr -= 100;

			return ptr;
		}

		bool  m_pushKeyChar(Key key)
		{
			if (m_increasePtr(m_key_tail_ptr) != m_key_head_ptr)
			{
				m_key_buffer[m_key_tail_ptr] = key;
				m_key_tail_ptr = m_increasePtr(m_key_tail_ptr);
				return true;
			}
			else
			{
				return false;
			}
		}

	public:
		//! KeyBuffer의 생성자
		KeyBuffer(void);
		//! KeyBuffer의 소멸자
		~KeyBuffer(void);

		//! Key가 눌려졌다는 것을 알려준다.
		bool setKeyDown(Key key)
		{
			if (key < avej::KEY_MAX_VALUE)
				m_key_map[key] = 1;

			return m_pushKeyChar(key);
		}
		//! Key가 떨어졌다는 것을 알려준다.
		bool setKeyUp(Key key)
		{
			if (key < avej::KEY_MAX_VALUE)
				m_key_map[key] = 0;

			return true;
		}
		//! 현재 Key buffer에 key가 남아 있는지 알려 준다.
		avej::BOOL isKeyPressed(void)
		{
			avej::IAvejApp::ProcessMessages();
			// Application.ProcessMessages;
			return  (m_key_head_ptr != m_key_tail_ptr);
		}
		//! Key buffer에 남아 있는 key를 돌려 준다.
		Key getKey()
		{
			Key key = -1;

			if (isKeyPressed())
			{
				key = m_key_buffer[m_key_head_ptr];
				m_key_head_ptr = m_increasePtr(m_key_head_ptr);
			}

			return key;
		}
		//! 현재 특정 Key가 눌려진 상태인지를 판별한다.
		avej::BOOL isKeyPressing(Key key)
		{
			if (key >= avej::KEY_MAX_VALUE)
				return false;

			return (m_key_map[key] > 0);
		}

		static KeyBuffer& getKeyBuffer(void);
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_KEY_BUFFER_H__
