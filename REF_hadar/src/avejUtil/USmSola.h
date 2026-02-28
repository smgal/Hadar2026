
#if !defined(__USMSOLA_H__)
#define __USMSOLA_H__

/*!
 * \file
 * \ingroup AVEJ utility
 * \brief AVEJ utility 중 일반 패턴을 template으로 만든 것
 * \author SMgal smgal@hitel.net
 * \date 2007-10-27
*/

#pragma warning(disable: 4786)

#include <map>
#include <cstdlib>

namespace sola
{

////////////////////////////////////////////////////////////////////////////////
// math

template <typename _type>
_type max(_type val1, _type val2)
{
	return (val1 > val2) ? val1 : val2;
}

template <typename _type>
_type min(_type val1, _type val2)
{
	return (val1 < val2) ? val1 : val2;
}

////////////////////////////////////////////////////////////////////////////////
// auto_deletor

//! 객체의 자동 삭제를 위한 template
/*!
 * \ingroup AVEJ utility
*/
template <class TBaseClass>
class auto_deletor
{
public:
	//! 자동 삭제를 위한 객체를 지정한다.
	auto_deletor(TBaseClass* object = 0)
		: m_object(object)
	{
	}
	//! 이 template의 수명이 끝나면 등록된 객체를 소멸시킨다. (배열 객체는 지원하지 않는다)
	~auto_deletor(void)
	{
		delete m_object;
	}
	void SetDeletor(TBaseClass* object)
	{
		m_object = object;
	}

private:
	TBaseClass* m_object;
};

////////////////////////////////////////////////////////////////////////////////
// singleton

//! 싱글톤용 template
/*!
 * \ingroup AVEJ utility
*/
template <class TBaseClass>
class singleton
{
public:
	//! 싱글톤 객체를 레퍼런스로 받는다.
	static TBaseClass& Instance(void)
	{
		if (m_instance == 0)
		{
			m_instance = new TBaseClass;
			m_deletor.SetDeletor(m_instance);
		}

		return *m_instance;
	}
	//! 싱글톤 객체를 해제 한다. 명시적인 해제 순서가 필요할 때 사용한다.
	static void DestroyInstance(void)
	{
		if (m_instance)
		{
			delete m_instance;
			m_instance = 0;
			m_deletor.SetDeletor(m_instance);
		}
	}

private:
	singleton(void);

	static TBaseClass* m_instance;
	static auto_deletor<TBaseClass> m_deletor;
};

//! 싱글톤용 내부 정적 객체.
template <class TBaseClass> TBaseClass* singleton<TBaseClass>::m_instance = 0;
//! 싱글톤의 수명 제어를 위해 사용되는 내부 정적 객체.
template <class TBaseClass> auto_deletor<TBaseClass> singleton<TBaseClass>::m_deletor;

////////////////////////////////////////////////////////////////////////////////
// factory

//! 팩토리용 template
/*!
 * \ingroup AVEJ utility
*/
template <class TBaseClass, typename TId>
class factory
{
	typedef TBaseClass*(*TFnCreate)(int);
	typedef std::map<TId, TFnCreate> Map;

public:
	//! 객체를 생성한다.
	TBaseClass* CreateObject(const TId& id, int level = 0)
	{
		typename Map::iterator i = m_map.find(id);
		if (i != m_map.end())
		{
			return (i->second)(level);
		}
		else
		{
			return 0;
		}
	}
	//! 객체 생성 함수를 등록한다.
	bool Register(const TId& id, TFnCreate fnCreate)
	{
		typename Map::iterator i = m_map.find(id);
		if (i != m_map.end())
			return false;

		m_map[id] = fnCreate;
		return true;
	}
	//! 팩토리 자체를 리셋한다..
	void Reset(void)
	{
		Map temp;
		m_map.swap(temp);
	}

private:
	Map m_map;
	
};

////////////////////////////////////////////////////////////////////////////////
// boolflag

template <int MAX_FLAG_NUM>
class boolflag
{
	enum
	{
		MAX_FLAG_BYTE = (MAX_FLAG_NUM+7) / 8,
	};

	typedef unsigned char TItem;

	class boolflag_private
	{
	public:
		boolflag_private(TItem& item, int shift)
			: m_item(item), m_shift(shift)
		{
		}
		boolflag_private& operator=(bool flag)
		{
			if (flag)
				m_item |=  (0x80 >> m_shift);
			else
				m_item &= ~(0x80 >> m_shift);

			return (*this);
		}
		operator bool() const
		{
			return (m_item & (0x80 >> m_shift)) > 0;
		}

	private:
		TItem& m_item;
		int    m_shift;
	};

public:
	boolflag(void)
	{
		TItem* pTable = m_table;
		for (int nItem = MAX_FLAG_BYTE; nItem > 0; --nItem)
			*pTable++ = 0;
	}
	boolflag_private operator[](int index)
	{
		if ((index < 0) || (index >= MAX_FLAG_NUM))
		{
			static TItem item;
			item = 0;
			return (boolflag_private(item, 0));
		}
		return (boolflag_private(m_table[index/8], index%8));
	}

private:
	boolflag(const boolflag&);
	boolflag& operator=(const boolflag<MAX_FLAG_NUM>& ref);

	TItem m_table[MAX_FLAG_BYTE];

};

////////////////////////////////////////////////////////////////////////////////
// intflag

template <typename TItem, int MAX_FLAG_NUM>
class intflag
{
	enum
	{
		MAX_FLAG_BYTE = (MAX_FLAG_NUM+7) / 8,
	};

	class intflag_private
	{
	public:
		intflag_private(TItem& item)
			: m_item(item)
		{
		}
		intflag_private& operator=(TItem value)
		{
			m_item = value;
			return (*this);
		}
		operator TItem() const
		{
			return m_item;
		}
		intflag_private& operator++()
		{
			++m_item;
			return (*this);
		}

	private:
		TItem& m_item;
	};

public:
	intflag(void)
	{
		TItem* pTable = m_table;
		for (int nItem = MAX_FLAG_BYTE; nItem > 0; --nItem)
			*pTable++ = 0;
	}
	intflag_private operator[](int index)
	{
		if ((index < 0) || (index >= MAX_FLAG_NUM))
		{
			static TItem item;
			item = 0;
			return (intflag_private(item));
		}
		return (intflag_private(m_table[index]));
	}

private:
	intflag(const intflag& ref);
	intflag& operator=(const intflag<TItem, MAX_FLAG_NUM>& ref);

	TItem m_table[MAX_FLAG_BYTE];

};

////////////////////////////////////////////////////////////////////////////////
// random

template <typename TBase>
TBase random_(void)
{
	TBase temp;
	unsigned char* pChar = &temp;
	int loop = sizeof(TBase);

	while (--loop >= 0)
		*pChar++ = (unsigned char)(rand() % 256);

	return temp;
};

////////////////////////////////////////////////////////////////////////////////
// himitsu

template <typename TBase>
TBase himitsu_private(TBase value)
{
	static bool  s_isFirst = true;
	static TBase s_table[256];

	if (s_isFirst)
	{
		//?? 원래는 shuffle 되어있어야 함
		//?? 단, 0은 0이어야 함
		for (int i = 0; i < 256; i++)
			s_table[i] = i;
		s_isFirst = false;
	}

	TBase temp;

	unsigned char* pSour = &value;
	unsigned char* pDest = &temp;

	int loop = sizeof(TBase);

	while (--loop >= 0)
		*pDest++ = s_table[*pSour++];

	return temp;
}


//?? 특별한 패턴의 값을 저장하고 있도록 수정. himitsu_private 사용해야 함
template <typename TBase>
struct himitsu
{
	TBase value;

	operator TBase(void)
	{
		return value;
	}
	TBase operator=(const TBase& _value)
	{
		value = _value;
		return value;
	}
};

} // namespace sola

#endif // #if !defined(__USMSOLA_H__)
