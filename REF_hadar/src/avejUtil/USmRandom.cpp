
#include "USmRandom.h"

class CSmRandomPrivate
{
public:
	CSmRandomPrivate(unsigned long seed)
		: m_seed(seed)
	{
	}
	void SetSeed(unsigned long seed)
	{
		m_seed = seed;
	}
	unsigned long Generate(void)
	{
		unsigned long temp;

		m_seed = m_seed * 214013L + 2531011L;
		temp   = ((m_seed) >> 16) & 0xFFFF;

		m_seed = m_seed * 134775813L + 1L;

		return temp | (m_seed & 0xFFFF0000);
	}

private:
	unsigned long m_seed;
};

int  CSmRandom::Expected(unsigned long seed, unsigned long max, unsigned long iteration)
{
	CSmRandomPrivate random(seed);

	while (iteration-- > 0)
		random.Generate();

	return int(random.Generate() % max);
}

static CSmRandomPrivate s_random(1037);

void CSmRandom::Randomize(unsigned long seed)
{
	s_random.SetSeed(seed);
}

int  CSmRandom::random(unsigned long max)
{
	return (s_random.Generate() % max) & 0x7FFFFFFF;
}
