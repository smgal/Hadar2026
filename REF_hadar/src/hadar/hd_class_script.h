
#ifndef __HD_CLASS_SCRIPT_H__
#define __HD_CLASS_SCRIPT_H__

#include "USmScript.h"

namespace hadar
{
	class Script
	{
		int m_mode;
		int m_position;
		int m_x_pos;
		int m_y_pos;

	public:
		enum
		{
			MODE_MAP   = 0,
			MODE_TALK  = 1,
			MODE_SIGN  = 2,
			MODE_EVENT = 3,
			MODE_ENTER = 4,
		};

		Script(int mode, int position, int x = 0, int y = 0);

		void nativeEqual(SmParam* p_param);
		void nativeLess(SmParam* p_param);
		void nativeNot(SmParam* p_param);
		void nativeOr(SmParam* p_param);
		void nativeAnd(SmParam* p_param);
		void nativeRandom(SmParam* p_param);
		void nativeAdd(SmParam* p_param);

		void nativePushString(SmParam* p_param);
		void nativePopString(SmParam* p_param);

		void nativeDisplayMap(SmParam* p_param);
		void nativeDisplayStatus(SmParam* p_param);
		void nativeScriptMode(SmParam* p_param);
		void nativeOn(SmParam* p_param);
		void nativeOnArea(SmParam* p_param);
		void nativeTalk(SmParam* p_param);
		void nativeTextAlign(SmParam* p_param);
		void nativeWarpPrevPos(SmParam* p_param);
		void nativePressAnyKey(SmParam* p_param);
		void nativeWait(SmParam* p_param);
		void nativeLoadScript(SmParam* p_param);

		// map
		void nativeMapInit(SmParam* p_param);
		void nativeMapSetType(SmParam* p_param);
		void nativeMapSetEncounter(SmParam* p_param);
		void nativeMapSetStartPos(SmParam* p_param);
		void nativeMapSetTile(SmParam* p_param);
		void nativeMapSetRow(SmParam* p_param);
		void nativeMapChangeTile(SmParam* p_param);
		void nativeMapLoadFromFile(SmParam* p_param);

		// tile
		void nativeTileCopyToDefaultTile(SmParam* p_param);
		void nativeTileCopyToDefaultSprite(SmParam* p_param);
		void nativeTileCopyTile(SmParam* p_param);

		// flag / variable
		void nativeFlagSet(SmParam* p_param);
		void nativeFlagReset(SmParam* p_param);
		void nativeFlagIsSet(SmParam* p_param);
		void nativeVariableSet(SmParam* p_param);
		void nativeVariableGet(SmParam* p_param);
		void nativeVariableAdd(SmParam* p_param);

		// battle
		void nativeBattleInit(SmParam* p_param);
		void nativeBattleStart(SmParam* p_param);
		void nativeBattleRegisterEnemy(SmParam* p_param);
		void nativeBattleShowEnemy(SmParam* p_param);
		void nativeBattleResult(SmParam* p_param);

		// select
		void nativeSelectInit(SmParam* p_param);
		void nativeSelectAdd(SmParam* p_param);
		void nativeSelectRun(SmParam* p_param);
		void nativeSelectResult(SmParam* p_param);

		// party
		void nativePartyPosX(SmParam* p_param);
		void nativePartyPosY(SmParam* p_param);
		void nativePartyPlusGold(SmParam* p_param);
		void nativePartyMove(SmParam* p_param);

		// player
		void nativePlayerIsAvailable(SmParam* p_param);
		void nativePlayerGetName(SmParam* p_param);
		void nativePlayerGetGenderName(SmParam* p_param);
		void nativePlayerAssignFromEnemyData(SmParam* p_param);
		void nativePlayerChangeAttribute(SmParam* p_param);
		void nativePlayerGetAttribute(SmParam* p_param);

		// enemy
		void nativeEnemyChangeAttribute(SmParam* p_param);

		static void registerScriptFileName(const char* sz_file_name);
		static const char* getScriptFileName(void);
	};

} // namespace hadar

#endif // __HD_CLASS_SCRIPT_H__
