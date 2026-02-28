
#ifndef __AVEJ_PIXELFORMAT_H
#define __AVEJ_PIXELFORMAT_H

namespace avej
{

enum EPixelFormat
{
	PIXELFORMAT_RGB565,
	PIXELFORMAT_ARGB8888,
	PIXELFORMAT_DWORD    = 0x7FFFFFFF
};

template <EPixelFormat pixel_format> struct TDataTraits
{
};

template <> struct TDataTraits<PIXELFORMAT_RGB565>
{
	typedef unsigned short pixel_type;
	enum
	{
		SHIFT_A   =  0,
		SHIFT_R   = 11,
		SHIFT_G   =  5,
		SHIFT_B   =  0,
		MASK_A    = 0x0000,
		MASK_R    = 0xF800,
		MASK_G    = 0x07E0,
		MASK_B    = 0x001F,
		USEBIT_A  = 0,
		USEBIT_R  = 5,
		USEBIT_G  = 6,
		USEBIT_B  = 5
	};
};

template <> struct TDataTraits<PIXELFORMAT_ARGB8888>
{
	typedef unsigned long pixel_type;
	enum
	{
		SHIFT_A   = 24,
		SHIFT_R   = 16,
		SHIFT_G   =  8,
		SHIFT_B   =  0,
		MASK_A    = 0xFF000000,
		MASK_R    = 0x00FF0000,
		MASK_G    = 0x0000FF00,
		MASK_B    = 0x000000FF,
		USEBIT_A  = 8,
		USEBIT_R  = 8,
		USEBIT_G  = 8,
		USEBIT_B  = 8
	};
};

template<EPixelFormat pixel_format>
class PixelFormat
{
public:
	typedef typename TDataTraits<pixel_format>::pixel_type pixel_type;
	enum EPixelFormatData
	{
		SHIFT_A  = TDataTraits<pixel_format>::SHIFT_A,
		SHIFT_R  = TDataTraits<pixel_format>::SHIFT_R,
		SHIFT_G  = TDataTraits<pixel_format>::SHIFT_G,
		SHIFT_B  = TDataTraits<pixel_format>::SHIFT_B,
		MASK_A   = TDataTraits<pixel_format>::MASK_A,
		MASK_R   = TDataTraits<pixel_format>::MASK_R,
		MASK_G   = TDataTraits<pixel_format>::MASK_G,
		MASK_B   = TDataTraits<pixel_format>::MASK_B,
		MASK_RGB = MASK_R | MASK_G | MASK_B,
		USEBIT_A = TDataTraits<pixel_format>::USEBIT_A,
		USEBIT_R = TDataTraits<pixel_format>::USEBIT_R,
		USEBIT_G = TDataTraits<pixel_format>::USEBIT_G,
		USEBIT_B = TDataTraits<pixel_format>::USEBIT_B,
		FORMAT   = pixel_format
	};

	inline static pixel_type MakePixel(unsigned char a, unsigned char r, unsigned char g, unsigned char b)
	{
		pixel_type maskB = ((SHIFT_B-(8-USEBIT_B)) > 0) ? ((pixel_type(b) << (SHIFT_B-(8-USEBIT_B))) & MASK_B) : ((pixel_type(b) >> ((8-USEBIT_B)-SHIFT_B)) & MASK_B);
		return ((pixel_type(a) << (SHIFT_A-(8-USEBIT_A))) & MASK_A) |
		       ((pixel_type(r) << (SHIFT_R-(8-USEBIT_R))) & MASK_R) |
		       ((pixel_type(g) << (SHIFT_G-(8-USEBIT_G))) & MASK_G) |
		       maskB;
	}

	inline static pixel_type Alpha(pixel_type color)
	{
		return (color & MASK_A) >> SHIFT_A << (8-USEBIT_A);
	}

	inline static pixel_type Red(pixel_type color)
	{
		return (color & MASK_R) >> SHIFT_R << (8-USEBIT_R);
	}

	inline static pixel_type Green(pixel_type color)
	{
		return (color & MASK_G) >> SHIFT_G << (8-USEBIT_G);
	}

	inline static pixel_type Blue(pixel_type color)
	{
		return (color & MASK_B) >> SHIFT_B << (8-USEBIT_B);
	}
};

}

#endif
