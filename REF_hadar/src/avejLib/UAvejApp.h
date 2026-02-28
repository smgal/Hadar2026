
#ifndef __AVEJ_APP_H
#define __AVEJ_APP_H

namespace avej
{
	
typedef unsigned long  UINT32;
typedef unsigned short UINT16;
typedef unsigned char  UINT08;

typedef signed long    INT32;
typedef signed short   INT16;
typedef signed char    INT08;

typedef bool           BOOL;

enum EKeySym
{
	KEY_UNKNOWN    = 0,
	KEY_START      = 1,
	KEY_SELECT     = 2,
	KEY_UP         = 3,
	KEY_UP_LEFT    = 4,
	KEY_LEFT       = 5,
	KEY_DOWN_LEFT  = 6,
	KEY_DOWN       = 7,
	KEY_DOWN_RIGHT = 8,
	KEY_RIGHT      = 9,
	KEY_UP_RIGHT   = 10,
	KEY_BUTTON_A   = 11,
	KEY_BUTTON_B   = 12,
	KEY_BUTTON_C   = 13,
	KEY_BUTTON_D   = 14,
	KEY_BUTTON_L   = 15,
	KEY_BUTTON_R   = 16,
	KEY_VOL_UP     = 17,
	KEY_VOL_DOWN   = 18,
	KEY_MAX_VALUE  = 19,
	KEY_DWORD      = 0x7FFFFFFF
};

struct AppCallback
{
	bool (*OnCreate)(void);
	bool (*OnDestory)(void);
	bool (*OnKeyDown)(unsigned short key, unsigned long state);
	bool (*OnKeyUp)(unsigned short key, unsigned long state);
	bool (*OnJoyDown)(unsigned short button);
	bool (*OnJoyUp)(unsigned short button);
	bool (*OnProcess)(void);
};

class IAvejApp
{
public:
	virtual ~IAvejApp(void) {};
	virtual void Process(void) = 0;
	static  void ProcessMessages(void);
	static IAvejApp* GetInstance(const AppCallback& callBack);
    static int Release(void);
};

class IAvejAppTarget: IAvejApp
{
public:
	IAvejAppTarget(void);
	~IAvejAppTarget(void);

	void Create(void);
	void Destory(void);
	void Process(void);
};

}

#endif // #ifndef __AVEJ_APP_H
