
#ifndef __USMRANDOM_H__
#define __USMRANDOM_H__

#endif // #ifndef __USMRANDOM_H__

class CSmRandom
{
public:
	static void Randomize(unsigned long seed);
	static int  random(unsigned long max);
	static int  Expected(unsigned long seed, unsigned long max, unsigned long iteration = 0);
};
