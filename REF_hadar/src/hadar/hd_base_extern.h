
#ifndef __HD_BASE_EXTERN_H__
#define __HD_BASE_EXTERN_H__

#include <vector>
#include "UAvejUtil.h"
#include "hd_class_console.h"
#include "hd_class_map.h"
#include "hd_class_pc_party.h"
#include "hd_class_pc_enemy.h"
#include "hd_class_pc_player.h"

namespace hadar
{
	namespace data
	{
		const std::vector<PcPlayer*>& getPlayerList(void);
		const std::vector<PcEnemy* >& getEnemyList(void);
		const PcParty& getParty(void);
		const Map& getMap(void);
	}

	namespace game
	{
		// ¹«¼Ò¼Ó
		unsigned long getRealColor(int index);
		void warpPrevPos(void);
		void pressAnyKey(void);
		void waitForAnyKey(void);
		void wait(unsigned long msec);
		void updateScreen(void);
		bool loadScript(const char* sz_text, int x_start = 0, int y_start = 0);
		void proccessGameOver(void);

		namespace map
		{
			void init(int width, int height);
			void setType(Map::TYPE _type);
			void setHandicap(int handicap);
			void setEncounter(int offset, int range);
			void setStartPos(int x, int y);
			void push(int row, unsigned char* p_data, int num_data);
			void change(int x, int y, int tile);
			void setLight(int x, int y);
			void resetLight(int x, int y);
			bool isValidWarpPos(int x, int y);
			bool loadFromFile(const char* sz_file_name);
		}

		namespace console
		{
			enum TEXTALIGN
			{
				TEXTALIGN_LEFT   = LoreConsole::TEXTALIGN_LEFT,
				TEXTALIGN_CENTER = LoreConsole::TEXTALIGN_CENTER,
				TEXTALIGN_RIGHT  = LoreConsole::TEXTALIGN_RIGHT
			};

			void writeConsole(unsigned long index, int num_arg, ...);
			void writeLine(const char* sz_text, unsigned long color = 0xFFFFFFFF);
			void showMessage(unsigned long index, const char* sz_message);
			void setTextAlign(TEXTALIGN align);
		}

		namespace tile
		{
			void copyToDefaultTile(int ix_tile);
			void copyToDefaultSprite(int ix_sprite);
			void copyTile(int src_tile, int dst_tile);
		}

		namespace window
		{
			void displayMap(void);
			void displayConsole(void);
			void displayStatus(void);
			void displayBattle(int);
			void getRegionForConsole(int* p_out_x, int* p_out_y, int* p_out_width, int* p_out_height);
		}

		namespace status
		{
			bool inBattle(void);
		}

		namespace object
		{
			std::vector<PcPlayer*>& getPlayerList(void);
			std::vector<PcEnemy*>& getEnemyList(void);
			PcParty& getParty(void);
			Map& getMap(void);
		}

		namespace variable
		{
			void set(int index, int value);
			void add(int index);
			int  get(int index);
		}

		namespace flag
		{
			void set(int index);
			void reset(int index);
			bool isSet(int index);
		}

		namespace battle
		{
			void init(void);
			void start(bool is_assualt_mode);
			void registerEnemy(int ix_enemy);
			void showEnemy(void);
			int  getResult(void);
		}

		namespace party
		{
			enum CHECKIF
			{
				CHECKIF_MAGICTORCH,
				CHECKIF_LEVITATION,
				CHECKIF_WALKONWATER,
				CHECKIF_WALKONSWAMP,
				CHECKIF_MINDCONTROL
			};

			int  getPosX(void);
			int  getPosY(void);
			void plusGold(int plus);
			void move(int x1, int y1);
			bool checkIf(CHECKIF check);
		}

		namespace player
		{
			int  getNumOfConsciousPlayer(void);
			bool isAvailable(int ix_player);
			const char* getName(int ix_player);
			const char* getGenderName(int ix_player);
			void assignFromEnemyData(int ix_player, int ix_enemy);
			void changeAttribute(int ix_player, const char* sz_attrib, int value);
			void changeAttribute(int ix_player, const char* sz_attrib, const char* sz_data);
			bool getAttribute(int ix_player, const char* sz_attrib, int& value);
			bool getAttribute(int ix_player, const char* sz_attrib, avej::string& data);
			void reviseAttribute(int ix_player);
			void applyAttribute(int ix_player);
		}

		namespace enemy
		{
			int  getNumOfConsciousEnemy(void);
			void changeAttribute(int ix_enemy, const char* sz_attrib, int value);
			void changeAttribute(int ix_enemy, const char* sz_attrib, const char* sz_data);
		}

		namespace select
		{
			void init(void);
			void add(const char* sz_string);
			void run(void);
			int  getResult(void);
		}

	} // namespace game

} // namespace hadar

#endif // #ifndef __HD_BASE_EXTERN_H__
