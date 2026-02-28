
#ifndef __HD_BASE_GAME_MAIN_H__
#define __HD_BASE_GAME_MAIN_H__

#include "hd_class_pc_party.h"
#include "hd_class_pc_name_base.h"
#include "hd_class_pc_enemy.h"
#include "hd_class_pc_player.h"

#include "hd_class_map.h"
#include "hd_class_game_option.h"

#include "hd_class_window.h"

#include <vector>

namespace hadar
{
	extern class GameMain* s_p_game_main;

	class GameMain
	{
	public:
		enum ENDBATTLE
		{
			ENDBATTLE_NONE,
			ENDBATTLE_LOSE,
			ENDBATTLE_WIN,
			ENDBATTLE_RUN_AWAY,
		};

		enum GAMESTATE
		{
			GAMESTATE_MAP,
			GAMESTATE_BATTLE,
		};

		enum EXITCODE
		{
			EXITCODE_BY_USER,
			EXITCODE_BY_ACCIDENT,
			EXITCODE_BY_ENEMY,
			EXITCODE_BY_FORCE,
		};

		enum BATTLERESULT
		{
			BATTLERESULT_EVADE,
			BATTLERESULT_WIN,
			BATTLERESULT_LOSE,
		};
		
		enum WINDOWTYPE
		{
			WINDOWTYPE_MAP     = 0,
			WINDOWTYPE_CONSOLE = 1,
			WINDOWTYPE_STATUS  = 2,
			WINDOWTYPE_BATTLE  = 3,
		};

		GAMESTATE  game_state;
		PcParty    party;
		Map        map;
		GameOption game_option;

		std::vector<PcPlayer*> player;
		std::vector<PcEnemy* > enemy;
		std::vector<CWindow*> window;
		std::vector<Serialized*> save_list;

		GameMain(void);
		~GameMain(void);

		bool loadMapFromFile(const char* sz_file_name);
		bool loadScript(const char* sz_file_name);

		void changeWindowForBattle(void);
		void changeWindowForField(void);
		bool isValidWarpPos(int x, int y);

		// 0~(n-1) 까지의 유효 숫자 또는 -1의 무효 숫자를 돌려 줌
		int selectPlayer(const char* szTitle = NULL);
		// 0~(n-1) 까지의 유효 숫자
		// 절대 -1의 무효 숫자를 돌려 주지 않음
		int selectEnemy(void);
		
		void detectGameOver(void);
		bool checkEndOfBattle(ENDBATTLE& exitCode);

		void plusGold(void);

		int registerEnemy(int index);

		// 정상적인 승부로 끝이나면 true, 도망을 치면 false
		BATTLERESULT runBattleMode(bool is_assualt_mode);

		void encounterEnemy(void);

		void showPartyStatus(void);
		void showCharacterStatus(void);
		void showCharacterStatus(const PcPlayer& selected);
		void showQuickView(void);

		void castSpell(void);
		void useExtrasense(void);
		void restHere(void);

		bool loadGame(int index);
		bool saveGame(int index);

		bool selectLoadMenu(void);
		bool selectSaveMenu(void);
		void selectGameOption(void);
		void selectMainMenu(void);

		void proccessGameOver(EXITCODE code);
		bool process(void);

	private:
		enum
		{
			MAX_PLAYER = 6,
			MAX_ENEMY  = 7,
		};

		PcPlayer m_player[MAX_PLAYER];
		PcEnemy  m_enemy[MAX_ENEMY];

		void m_actBlock(int x1, int y1, bool bUseless);
		void m_actMove(int x1, int y1, bool bEncounter);
		void m_actEvent(int x1, int y1, bool bUseless);
		void m_actEnter(int x1, int y1, bool bUseless);
		void m_actSign(int x1, int y1, bool bUseless);
		void m_actWater(int x1, int y1, bool bUseless);
		void m_actSwamp(int x1, int y1, bool bUseless);
		void m_actLava(int x1, int y1, bool bUseless);
		void m_actTalk(int x1, int y1, bool bUseless);
	};

} // namespace hadar

#endif // #ifndef __HD_BASE_GAME_MAIN_H__
