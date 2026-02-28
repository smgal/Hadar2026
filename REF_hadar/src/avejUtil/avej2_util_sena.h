
#ifndef __AVEJ2_UTIL_SENA_H__
#define __AVEJ2_UTIL_SENA_H__

////////////////////////////////////////////////////////////////////////////////
// uses

#include "avej2_util_sena.h"

#include <cassert>
#include <stdlib.h>
#include <new>

////////////////////////////////////////////////////////////////////////////////
// definition

#if defined(_MSC_VER)
#pragma warning(4: 4018)
#pragma warning(disable: 4284 4786)
#endif

////////////////////////////////////////////////////////////////////////////////
// interface

namespace sena
{
	//! 각 타입에 대한 유효성 플래그를 둘 수 있는 템플릿
	/*!
	 * \ingroup gfx2d
	 * \remarks 이 템플릿 코드는 '게임 개발자를 위한 C++'의 것을 가져와서 수정한 것임.
	 *          share_ptr<>을 포함하는 구조체를 optional<>로 두고 다시 그것을 포함하는 구조체를 vector<>등에 넣으면 안된다.
	 */
	template<typename TBaseType>
	class optional
	{
	public:
		optional()
			: m_initialized(false)
		{
		}
		optional(const TBaseType& t)
			: m_initialized(false)
		{
			reset(t);
		}
		~optional()
		{
			reset();
		}

		TBaseType& operator*() 
		{ 
			assert(m_initialized);
			return *static_cast<TBaseType*>(address()); 
		}
		const TBaseType& operator*() const
		{ 
			assert(m_initialized);
			return *static_cast<const TBaseType*>(address()); 
		}
		TBaseType* operator->() 
		{ 
			assert(m_initialized);
			return static_cast<TBaseType*>(address()); 
		}
		const TBaseType* operator->() const
		{ 
			assert(m_initialized);
			return static_cast<const TBaseType*>(address()); 
		}
		//! 담겨진 실제 객체의 주소를 얻기
		TBaseType* get() 
		{ 
			assert(m_initialized);
			return static_cast<TBaseType*>(address()); 
		}
		//! 담겨진 실제 객체의 주소를 얻기 (const)
		const TBaseType* get() const
		{ 
			assert(m_initialized);
			return static_cast<const TBaseType*>(address()); 
		}
		//! 담겨진 객체를 해제하고 초기 상태로 돌아가기
		void reset() 
		{
			if (m_initialized)
			{ 
	#if 1
				static_cast<TBaseType*>(address())->TBaseType::~TBaseType();
	#else
				TBaseType* t = static_cast<TBaseType*>(address());
				t->~TBaseType();
	#endif
				m_initialized = false;
			}
		}
		//! 담겨진 객체를 해제하고 새로운 객체를 등록하기
		void reset(const TBaseType& t) 
		{
			reset();
			new (address()) TBaseType(t); 
			m_initialized = true;
		}
		//! 현재 담겨진 객체가 유효한지의 여부
		bool valid() const
		{
			return m_initialized;
		}
		//! 현재 담겨진 객체가 유효하지 않은지의 여부
		bool invalid() const
		{
			return !m_initialized;
		}

	private:
		bool       m_initialized;
		TBaseType  m_storage;

		optional(const optional&);
		optional& operator=(const optional&);

		void* address()
		{
			return &m_storage;
		}
		const void* address() const
		{
			return &m_storage;
		}
	};

	template<typename TPtr>
	class auto_ptr
	{
	public:
		explicit auto_ptr(TPtr* ptr = 0)
			: m_owns(ptr != 0), m_ptr((TPtr*)ptr)
		{
		}
		~auto_ptr()
		{
			if (m_owns)
				delete (TPtr*)m_ptr;
		}
		void bind(TPtr* ptr)
		{
			SM_ASSERT(m_ptr == 0);
			m_owns = (ptr != 0);
			m_ptr  = (TPtr*)ptr;
		}
		TPtr* get() const
		{
			return m_ptr;
		}
		TPtr* release() const
		{
			((auto_ptr<TPtr>*)this)->m_owns = false;
			return m_ptr;
		}

	private:
		bool  m_owns;
		TPtr* m_ptr;
	};

	template<typename TPtr>
	class auto_array
	{
	public:
		explicit auto_array(TPtr* ptr = 0)
			: m_owns(ptr != 0), m_ptr((TPtr*)ptr)
		{
		}
		~auto_array()
		{
			if (m_owns)
				delete[] (TPtr*)m_ptr;
		}
		TPtr& operator[](unsigned int index) const
		{
			return m_ptr[index];
		}
		void bind(TPtr* ptr)
		{
			SM_ASSERT(m_ptr == 0);
			m_owns = (ptr != 0);
			m_ptr  = (TPtr*)ptr;
		}
		TPtr* get() const
		{
			return m_ptr;
		}
		TPtr* release() const
		{
			((auto_array<TPtr>*)this)->m_owns = false;
			return m_ptr;
		}

	private:
		bool  m_owns;
		TPtr* m_ptr;
	};

	//! 참조 카운트가 달린 객체를 담는 템플릿
	/*!
	 * \ingroup gfx2d
	 * \remarks 이 템플릿 코드는 'Ogre3D'의 것을 가져와서 싱글 쓰레드용으로 수정한 것임
	 */
	template<typename TBaseType>
	class shared_ptr
	{
	protected:
		TBaseType*    m_p_instance;
		unsigned int* m_use_count;

	public:
		shared_ptr()
			: m_p_instance(0), m_use_count(0)
		{
		}
		explicit shared_ptr(TBaseType* p_instance)
			: m_p_instance(p_instance), m_use_count(new unsigned int(1))
		{
		}
		shared_ptr(const shared_ptr& ref_instance)
			: m_p_instance(0), m_use_count(0)
		{
			m_p_instance = ref_instance.m_p_instance;
			m_use_count  = ref_instance.m_use_count; 

			if (m_use_count)
				++(*m_use_count); 
		}
		virtual ~shared_ptr()
		{
			release();
		}

		shared_ptr& operator=(const shared_ptr& ref_instance)
		{
			if (m_p_instance == ref_instance.m_p_instance)
				return *this;

			release();

			{
				m_p_instance = ref_instance.m_p_instance;
				m_use_count  = ref_instance.m_use_count;
				if (m_use_count)
					++(*m_use_count);
			}

			return *this;
		}

		inline TBaseType& operator*() const
		{
			assert(m_p_instance);
			return *m_p_instance;
		}
		inline TBaseType* operator->() const
		{
			assert(m_p_instance);
			return m_p_instance;
		}
		inline TBaseType* get() const
		{
			return m_p_instance;
		}

		void bind(TBaseType* rep)
		{
			assert(!m_p_instance && !m_use_count);
			m_use_count  = new unsigned int(1);
			m_p_instance = rep;
		}

		inline bool unique() const
		{
			assert(m_use_count);
			return (*m_use_count == 1);
		}
		inline unsigned int useCount() const
		{
			assert(m_use_count);
			return *m_use_count;
		}
		inline unsigned int* useCountPointer() const
		{
			return m_use_count;
		}

		inline TBaseType* getPointer() const
		{
			return m_p_instance;
		}

		inline bool isNull(void) const
		{
			return (m_p_instance == 0);
		}

		inline void setNull(void)
		{ 
			if (m_p_instance)
			{
				release();
				m_p_instance = 0;
				m_use_count  = 0;
			}
		}

	protected:
		inline void release(void)
		{
			if (m_use_count)
				if (--(*m_use_count) == 0) 
					destroy();
		}

		virtual void destroy(void)
		{
			delete m_p_instance;
			delete m_use_count;
		}
	};

	template<typename TBaseType1, typename TBaseType2> inline bool operator==(shared_ptr<TBaseType1> const& a, shared_ptr<TBaseType2> const& b)
	{
		return a.get() == b.get();
	}

	template<typename TBaseType1, typename TBaseType2> inline bool operator!=(shared_ptr<TBaseType1> const& a, shared_ptr<TBaseType2> const& b)
	{
		return a.get() != b.get();
	}

	//! 포인터 객체에 자동 해제 기능을 부여하는 템플릿
	/*!
	 * \ingroup gfx2d
	 */
	template <typename TBaseClass>
	class auto_deletor
	{
	public:
		auto_deletor(TBaseClass* object = 0)
			: m_object(object)
		{
		}
		~auto_deletor(void)
		{
			delete m_object;
		}
		void set(TBaseClass* object)
		{
			m_object = object;
		}

	private:
		TBaseClass* m_object;
	};

	//! 싱글톤 객체를 만들어 주기 위한 템플릿 (single thread 전용)
	/*!
	 * \ingroup gfx2d
	 */
	template <typename TBaseClass, int kind = 0>
	class singleton
	{
	public:
		static TBaseClass& get(int param = 0)
		{
			if (m_instance == 0)
			{
				m_instance = new TBaseClass;
				m_deletor.set(m_instance);
			}

			return *m_instance;
		}
		// 명시적인 해제 순서가 필요할 때 사용한다.
		static void release(int param = 0)
		{
			if (m_instance)
			{
				delete m_instance;
				m_instance = 0;
				m_deletor.Set(m_instance);
			}
		}
	private:
		singleton(void);

		static TBaseClass* m_instance;
		static auto_deletor<TBaseClass> m_deletor;
	};

	template <class TBaseClass, int kind> TBaseClass* singleton<TBaseClass, kind>::m_instance = 0;
	template <class TBaseClass, int kind> auto_deletor<TBaseClass> singleton<TBaseClass, kind>::m_deletor;

} // namespace sena

namespace sena
{
	template<typename TData>
	inline void swap(TData& a, TData& b)
	{
		TData temp = a;
		a = b, b = temp;
	}

	template<class TInIter, class TOutIter>
	inline TOutIter copy(TInIter first, TInIter last, TOutIter dest)
	{
		for (; first != last; ++dest, ++first)
			*dest = *first;

		return dest;
	}

	template<class TInIter, class TOutIter>
	inline TOutIter copy_backward(TInIter first, TInIter last, TOutIter dest)
	{
		while (first != last)
			*--dest = *--last;
		
		return dest;
	}

	template<class TIter, class TData>
	inline void fill(TIter first, TIter last, const TData& data)
	{
		for (; first != last; ++first)
			*first = data;
	}

	template<class TInIter, class TOutIter>
	inline TOutIter strncpy(TOutIter dest, TInIter first, int size)
	{
		TInIter last = first + size;
		for (; first != last; ++dest, ++first)
		{
			*dest = *first;
			if (*first == 0)
				break;
		}

		return dest;
	}

	template<typename T1, typename T2>
	struct pair
	{
		pair()
			: first(T1()), second(T2()) {}
		pair(const T1& val1, const T2& val2)
			: first(val1), second(val2) {}
		template<class U, class V> pair(const pair<U, V>& ref)
			: first(ref.first), second(ref.second) {}

		T1 first;
		T2 second;
	};

	template<typename T1, typename T2>
	inline pair<T1, T2> make_pair(const T1& val1, const T2& val2)
	{
		return (pair<T1, T2>(val1, val2));
	}

	template<typename T1, typename T2, typename T3>
	struct triple
	{
		triple()
			: first(T1()), second(T2()), third(T3()) {}
		triple(const T1& val1, const T2& val2, const T3& val3)
			: first(val1), second(val2), third(val3) {}
		template<class U, class V, class W> triple(const triple<U, V, W>& ref)
			: first(ref.first), second(ref.second), third(ref.third) {}

		T1 first;
		T2 second;
		T3 third;
	};

	template<typename T1, typename T2, typename T3>
	inline triple<T1, T2, T3> make_triple(const T1& val1, const T2& val2, const T3& val3)
	{
		return (triple<T1, T2, T3>(val1, val2, val3));
	}

	template<typename TIter, typename TProc>
	inline TIter find_if(TIter first, TIter last, TProc Proc)
	{
		for (; first != last; ++first)
			if (Proc(*first))
				break;

		return (first);
	}

	template<typename TDataType>
	class vector
	{
	public:
		typedef vector<TDataType> TMyVector;
		typedef size_t            size_type;
		typedef       TDataType*  iterator;
		typedef const TDataType*  const_iterator;
		typedef       TDataType&  reference;
		typedef const TDataType&  const_reference;

		explicit vector()
		: m_first(0), m_last(0), m_end(0)
		{
		}
		~vector()
		{
			_Destroy(m_first, m_last);
			operator delete(m_first);
			m_first = 0, m_last = 0, m_end = 0;
		}
		iterator begin()
		{
			return (m_first);
		}
		const_iterator begin() const
		{
			return ((const_iterator)m_first);
		}
		iterator end()
		{
			return (m_last);
		}
		const_iterator end() const
		{
			return ((const_iterator)m_last);
		}
		size_type size() const
		{
			return (m_first == 0) ? 0 : m_last - m_first;
		}
		bool empty() const
		{
			return (size() == 0);
		}
		const_reference at(size_type index) const
		{
			if (size() <= index)
				_Throw_OutOfRange();
			return (*(begin() + index));
		}
		reference at(size_type index)
		{
			if (size() <= index)
				_Throw_OutOfRange();
			return (*(begin() + index));
		}
		const_reference operator[](size_type index) const
		{
			return (*(begin() + index));
		}
		reference operator[](size_type index)
		{
			return (*(begin() + index));
		}
		void push_back(const TDataType& data)
		{
			insert(end(), 1, data);
		}
		void pop_back()
		{
			erase(end() - 1);
		}
		void insert(iterator iter, size_type num_insert, const TDataType& data)
		{
			if (m_end - m_last < ptrdiff_t(num_insert))
			{
				size_type num_alloc       = size() + (num_insert < size() ? size() : num_insert);
				iterator  p_allocated     = ((TDataType *)operator new(num_alloc * sizeof(TDataType)));
				iterator  p_allocated_end = _copy(m_first, iter, p_allocated);

				_fill(p_allocated_end, num_insert, data);
				_copy(iter, m_last, p_allocated_end + num_insert);

				_Destroy(m_first, m_last);
				operator delete(m_first);

				m_end   = p_allocated + num_alloc;
				m_last  = p_allocated + size() + num_insert;
				m_first = p_allocated;
			}
			else if (m_last - iter < ptrdiff_t(num_insert))
			{
				_copy(iter, m_last, iter + num_insert);
				_fill(m_last, num_insert - (m_last - iter), data);
				fill(iter, m_last, data);
				m_last += num_insert;
			}
			else if (0 < num_insert)
			{
				_copy(m_last - num_insert, m_last, m_last);
				copy_backward(iter, m_last - num_insert, m_last);
				fill(iter, iter + num_insert, data);
				m_last += num_insert;
			}
		}
		iterator erase(iterator iter)
		{
			copy(iter + 1, end(), iter);
			_Destroy(m_last - 1, m_last);
			--m_last;
			return (iter);
		}
		iterator erase(iterator iter_first, iterator iter_last)
		{
			iterator temp = copy(iter_last, end(), iter_first);
			_Destroy(temp, end());
			m_last = temp;
			return iter_first;
		}
		void clear()
		{
			erase(begin(), end());
		}
		void swap(TMyVector& ref)
		{
			TMyVector temp = *this; *this = ref, ref = temp;
		}

		friend void swap(TMyVector& ref1, TMyVector& ref2)
		{
			ref1.swap(ref2);
		}

	protected:
		void _Destroy(iterator first, iterator last)
		{
			for (; first != last; ++first)
				(first)->~TDataType();
		}
		iterator _copy(const_iterator first, const_iterator last, iterator p_allocated)
		{
			for (; first != last; ++p_allocated, ++first)
				new ((void*)p_allocated) TDataType(*first);

			return (p_allocated);
		}
		void _fill(iterator first, size_type num_fill, const TDataType &data)
		{
			for (; 0 < num_fill; --num_fill, ++first)
				new ((void*)first) TDataType(data);
		}
		void _Throw_OutOfRange() const
		{
			assert(0);
		}

		iterator m_first, m_last, m_end;
	};

}

#endif // #ifndef __AVEJ2_UTIL_SENA_H__
