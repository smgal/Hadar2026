
#ifndef __HD_RES_STRING_H__
#define __HD_RES_STRING_H__

namespace hadar
{
	namespace resource
	{
		///////////////////////////////////////////////////////////////////////////////
		// 게임의 기본 속성 문자열 (player, weapon 등)

		enum CONDITION
		{
			CONDITION_GOOD        = 0,
			CONDITION_POISONED    = 1,
			CONDITION_UNCONSCIOUS = 2,
			CONDITION_DEAD        = 3,
		};

		enum AUX
		{
			AUX_RESERVED = 0,
			AUX_MAX
		};

		struct HanString
		{
			const char* sz_name;
			const char* sz_josa_sub1;
			const char* sz_josa_sub2;
			const char* sz_josa_obj;
			const char* sz_josa_with;

			HanString(void)
				: sz_name("")
				, sz_josa_sub1("")
				, sz_josa_sub2("")
				, sz_josa_obj("")
				, sz_josa_with("")
			{
			}
		};

		HanString getWeaponName(int index);
		HanString getShieldName(int index);
		HanString getArmorName(int index);

		HanString get3rdPersonName(int index);
		HanString getGenderName(int index);
		HanString getClassName(int index);
		HanString getConditionName(CONDITION index);

		HanString getMagicName(int index);

		HanString getAuxName(AUX index);

		///////////////////////////////////////////////////////////////////////////////
		// 게임의 메시지 문자열

		enum MESSAGE
		{
			MESSAGE_NOT_ENOUGH_SP,
			MESSAGE_ANONYMOUS_NAME,
			MESSAGE_CANNOT_USE_ATTACK_MAGIC_NOT_IN_BATTLE_MODE,
			MESSAGE_TO_WHOM,
			MESSAGE_TO_EVERYBODY,
			MESSAGE_SELECTION,
			MESSAGE_CANNOT_USE_POWERFUL_CURE_SPELL,
			MESSAGE_SELECT_DIRECTION,
			MESSAGE_TELEPORT_TO_NORTH,
			MESSAGE_TELEPORT_TO_SOUTH,
			MESSAGE_TELEPORT_TO_EAST,
			MESSAGE_TELEPORT_TO_WEST,
			MESSAGE_MAX
		};

		const char* getMessageString(MESSAGE message);

		///////////////////////////////////////////////////////////////////////////////
		// Resource 관리 utility

		unsigned short getLastMultiByte(const char* sz_text);
		bool hasJongsung(unsigned short code);

	} // namespace resource

} // namespace hadar

#endif // #ifndef __HD_RES_STRING_H__
