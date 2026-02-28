
#ifndef __USMSET_H__
#define __USMSET_H__

class SmSet
{
public:
	enum
	{
		SET_SIZE = 256 / 8
	};

	typedef unsigned char Set[SET_SIZE];

public:
	SmSet(void);
	SmSet(const char* sz_stream);

	void assign(const char* sz_stream);
	inline const Set& getSet(void) const { return m_set; }
	inline bool isSet(unsigned char index) const { return (m_set[index / 8] & (1 << (index % 8))) > 0; }

private:
	Set   m_set;

	bool  m_makeSetArray(const char* sz_stream, Set& set);

};

#endif // #ifndef __USMSET_H__
