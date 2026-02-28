
#include "hd_class_script.h"
#include "hd_base_extern.h"

#include <stdio.h>
#include <string.h>
#include <map>
#include <vector>
#include <stack>

namespace
{
	std::stack<avej::string> s_string_stack;
}

///////////////////////////////////////////////////////////
// General

void hadar::Script::nativeEqual(SmParam* p_param)
{
	assert(p_param);
	assert((p_param->type[1] == 'i' && p_param->type[2] == 'i') ||
	       (p_param->type[1] == 's' && p_param->type[2] == 's'));

	p_param->result.type = 'i';

	if (p_param->type[1] == 'i')
	{
		// 정수끼리 비교
		p_param->result.data = (p_param->data[1] == p_param->data[2]) ? 1 : 0;
	}
	else
	{
		// 문자열끼리 비교
		p_param->result.data = (strcmp(p_param->string[1], p_param->string[2]) == 0) ? 1 : 0;
	}
}


void hadar::Script::nativeLess(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = (p_param->data[1] < p_param->data[2]) ? 1 : 0;
}

void hadar::Script::nativeNot(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = (p_param->data[1] != 0) ? 0 : 1;
}

void hadar::Script::nativeOr(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = ((p_param->data[1] != 0) || (p_param->data[2] != 0)) ? 1 : 0;
}

void hadar::Script::nativeAnd(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = ((p_param->data[1] != 0) && (p_param->data[2] != 0)) ? 1 : 0;
}

void hadar::Script::nativeRandom(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = rand() % p_param->data[1];
}

void hadar::Script::nativeAdd(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = p_param->data[1] + p_param->data[2];
}


void hadar::Script::nativePushString(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');

	s_string_stack.push(p_param->string[1]);
}

void hadar::Script::nativePopString(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	avej::string result;

	for (int i = 0; i < p_param->data[1]; i++)
	{
		assert(!s_string_stack.empty());
		if (!s_string_stack.empty())
		{
			result.copyToFront(s_string_stack.top());
			s_string_stack.pop();
		}
	}
	p_param->result.type = 's';
	p_param->result.sz_str = result;
}


void hadar::Script::nativeDisplayMap(SmParam* p_param)
{
	game::window::displayMap();
	game::updateScreen();
}

void hadar::Script::nativeDisplayStatus(SmParam* p_param)
{
	game::window::displayStatus();
	game::updateScreen();
}

void hadar::Script::nativeScriptMode(SmParam* p_param)
{
	assert(p_param);

	p_param->result.type = 'i';
	p_param->result.data = m_mode;
}

void hadar::Script::nativeOn(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = 0;

	if (m_x_pos == p_param->data[1] && m_y_pos == p_param->data[2])
	{
		printf("NativeOn(%d, %d)\n", p_param->data[1], p_param->data[2]);
		p_param->result.data = 1;
	}
}

void hadar::Script::nativeOnArea(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');
	assert(p_param->type[3] == 'i');
	assert(p_param->type[4] == 'i');

	int x1 = p_param->data[1];
	int y1 = p_param->data[2];
	int x2 = p_param->data[3];
	int y2 = p_param->data[4];

	p_param->result.type = 'i';
	p_param->result.data = 0;

	if ((m_x_pos >= x1 && m_x_pos <= x2) && (m_y_pos >= y1 && m_y_pos <= y2))
	{
		printf("NativeOnArea(%d, %d, %d, %d)\n", x1, y1, x2, y2);
		p_param->result.data = 1;
	}
}

void hadar::Script::nativeTalk(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');

	printf("NativeTalk(%s)\n", p_param->string[1]);
	game::console::writeLine(p_param->string[1]);
}

void hadar::Script::nativeTextAlign(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	switch (p_param->data[1])
	{
	case 0:
		game::console::setTextAlign(game::console::TEXTALIGN_LEFT);
		break;
	case 1:
		game::console::setTextAlign(game::console::TEXTALIGN_CENTER);
		break;
	case 2:
		game::console::setTextAlign(game::console::TEXTALIGN_RIGHT);
		break;
	default:
		assert(0);
	}
}

void hadar::Script::nativeWarpPrevPos(SmParam* p_param)
{
	assert(p_param);

	game::warpPrevPos();
}

void hadar::Script::nativePressAnyKey(SmParam* p_param)
{
	game::pressAnyKey();
}

void hadar::Script::nativeWait(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::wait(p_param->data[1]);
}

void hadar::Script::nativeLoadScript(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');

	// p_param->data[2], p_param->data[3]은 deafault parameter
	game::loadScript(p_param->string[1], p_param->data[2], p_param->data[3]);
}

///////////////////////////////////////////////////////////
// Map

namespace
{
	struct MapTemplate
	{
		int width;
		int height;
		int row;

		typedef std::map<unsigned short, unsigned char> Convert;
		Convert convert;
	} m_map;
}

void hadar::Script::nativeMapInit(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	m_map.width  = p_param->data[1];
	m_map.height = p_param->data[2];
	m_map.row    = 0;
	m_map.convert.clear();

	game::map::init(m_map.width, m_map.height);
}

void hadar::Script::nativeMapSetType(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	switch (p_param->data[1])
	{
	case 0:
		game::map::setType(Map::TYPE_TOWN);
		break;
	case 1:
		game::map::setType(Map::TYPE_KEEP);
		break;
	case 2:
		game::map::setType(Map::TYPE_GROUND);
		break;
	case 3:
		game::map::setType(Map::TYPE_DEN);
		break;
	}
}

void hadar::Script::nativeMapSetEncounter(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	game::map::setEncounter(p_param->data[1], p_param->data[2]);
}

void hadar::Script::nativeMapSetStartPos(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	game::map::setStartPos(p_param->data[1], p_param->data[2]);
}

void hadar::Script::nativeMapSetTile(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');
	assert(p_param->type[2] == 'i');

	unsigned short temp = p_param->string[1][0];
	temp <<= 8;
	temp  |= (unsigned short)p_param->string[1][1] & 0xFF;

	m_map.convert[temp] = p_param->data[2];
}

void hadar::Script::nativeMapSetRow(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');

	int len = strlen(p_param->string[1]) / 2;
	unsigned char* p_char = (unsigned char*)p_param->string[1];

	std::vector<unsigned char> row;
	row.reserve(len);

	int loop = len;
	while (--loop >= 0)
	{
		unsigned short temp = *p_char++;
		temp <<= 8;
		temp  |= (unsigned short)*p_char++ & 0xFF;

		MapTemplate::Convert::iterator i = m_map.convert.find(temp);
		if (i != m_map.convert.end())
		{
			row.push_back(i->second);
			continue;
		}
		assert(false);
		row.push_back(0);
	}

	game::map::push(m_map.row++, &(*row.begin()), len);
}

void hadar::Script::nativeMapChangeTile(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');
	assert(p_param->type[3] == 'i');

	game::map::change(p_param->data[1], p_param->data[2], p_param->data[3]);
}

void hadar::Script::nativeMapLoadFromFile(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');

	game::map::loadFromFile(p_param->string[1]);
}

///////////////////////////////////////////////////////////
// Tile

void hadar::Script::nativeTileCopyToDefaultTile(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::tile::copyToDefaultTile(p_param->data[1]);
}

void hadar::Script::nativeTileCopyToDefaultSprite(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::tile::copyToDefaultSprite(p_param->data[1]);
}

void hadar::Script::nativeTileCopyTile(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	game::tile::copyTile(p_param->data[1], p_param->data[2]);
}

///////////////////////////////////////////////////////////
// Flag

void hadar::Script::nativeFlagSet(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::flag::set(p_param->data[1]);
}

void hadar::Script::nativeFlagReset(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::flag::reset(p_param->data[1]);
}

void hadar::Script::nativeFlagIsSet(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = game::flag::isSet(p_param->data[1]) ? 1 :0;
}

void hadar::Script::nativeVariableSet(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	game::variable::set(p_param->data[1], p_param->data[2]);
}

void hadar::Script::nativeVariableAdd(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::variable::add(p_param->data[1]);
}

void hadar::Script::nativeVariableGet(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 'i';
	p_param->result.data = game::variable::get(p_param->data[1]);
}

///////////////////////////////////////////////////////////
// Battle

void hadar::Script::nativeBattleInit(SmParam* p_param)
{
	assert(p_param);

	game::battle::init();
}

void hadar::Script::nativeBattleRegisterEnemy(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::battle::registerEnemy(p_param->data[1]);
}

void hadar::Script::nativeBattleShowEnemy(SmParam* p_param)
{
	assert(p_param);

	game::battle::showEnemy();
}

void hadar::Script::nativeBattleStart(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::battle::start((p_param->data[1] > 0) ? true : false);
}

void hadar::Script::nativeBattleResult(SmParam* p_param)
{
	assert(p_param);

	p_param->result.type = 'i';
	p_param->result.data = game::battle::getResult();
}

void hadar::Script::nativeSelectInit(SmParam* p_param)
{
	game::select::init();
}

void hadar::Script::nativeSelectAdd(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 's');

	game::select::add(p_param->string[1]);
}

void hadar::Script::nativeSelectRun(SmParam* p_param)
{
	game::select::run();
}

void hadar::Script::nativeSelectResult(SmParam* p_param)
{
	assert(p_param);

	p_param->result.type = 'i';
	p_param->result.data = game::select::getResult();
}


void hadar::Script::nativePartyPosX(SmParam* p_param)
{
	assert(p_param);

	p_param->result.type = 'i';
	p_param->result.data = game::party::getPosX();
}

void hadar::Script::nativePartyPosY(SmParam* p_param)
{
	assert(p_param);

	p_param->result.type = 'i';
	p_param->result.data = game::party::getPosY();
}

void hadar::Script::nativePartyPlusGold(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	game::party::plusGold(p_param->data[1]);
}

void hadar::Script::nativePartyMove(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	game::party::move(p_param->data[1], p_param->data[2]);
}

void hadar::Script::nativePlayerIsAvailable(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 'i';
	// script는 1-base이고 C++은 0-base이기 때문에 -1을 한다.
	p_param->result.data = (game::player::isAvailable(p_param->data[1]-1)) ? 1 : 0;
}

void hadar::Script::nativePlayerGetName(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 's';
	// script는 1-base이고 C++은 0-base이기 때문에 -1을 한다.
	p_param->result.sz_str = game::player::getName(p_param->data[1]-1);
}

void hadar::Script::nativePlayerGetGenderName(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');

	p_param->result.type = 's';
	// script는 1-base이고 C++은 0-base이기 때문에 -1을 한다.
	p_param->result.sz_str = game::player::getGenderName(p_param->data[1]-1);
}

void hadar::Script::nativePlayerAssignFromEnemyData(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 'i');

	game::player::assignFromEnemyData(p_param->data[1]-1, p_param->data[2]);
}

void hadar::Script::nativePlayerChangeAttribute(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 's');

	if (p_param->type[3] == 'i')
		game::player::changeAttribute(p_param->data[1]-1, p_param->string[2], p_param->data[3]);
	else
		game::player::changeAttribute(p_param->data[1]-1, p_param->string[2], p_param->string[3]);
}

void hadar::Script::nativePlayerGetAttribute(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 's');

	// script는 1-base이고 C++은 0-base이기 때문에 -1을 한다.
	int ixPerson = p_param->data[1]-1;

	p_param->result.type = 'i';
	if (!game::player::getAttribute(ixPerson, p_param->string[2], p_param->result.data))
	{
		// integer 형에는 존재 하지 않음
		p_param->result.type  = 's';
		game::player::getAttribute(ixPerson, p_param->string[2], p_param->result.sz_str);
	}
}

void hadar::Script::nativeEnemyChangeAttribute(SmParam* p_param)
{
	assert(p_param);
	assert(p_param->type[1] == 'i');
	assert(p_param->type[2] == 's');

	if (p_param->type[3] == 'i')
		game::enemy::changeAttribute(p_param->data[1]-1, p_param->string[2], p_param->data[3]);
	else
		game::enemy::changeAttribute(p_param->data[1]-1, p_param->string[2], p_param->string[3]);
}

hadar::Script::Script(int mode, int position, int x, int y)
	: m_mode(mode)
	, m_position(position)
	, m_x_pos(x)
	, m_y_pos(y)
{
	// 아래의 변수가 static이기 때문에 Script에 대한 script 벌 수는 한 개로 한정됨
	// thread safety 보장되지 않음
	static SmScriptFunction<Script> function;

	function.SetScript(this);

	// script 속도 향상을 위해 초기화는 단 한번만 하도록 함
	if (function.IsNotInitialized())
	{
		function.RegisterFunction("Equal", &hadar::Script::nativeEqual);
		function.RegisterFunction("Less", &hadar::Script::nativeLess);
		function.RegisterFunction("Not", &hadar::Script::nativeNot);
		function.RegisterFunction("Or", &hadar::Script::nativeOr);
		function.RegisterFunction("And", &hadar::Script::nativeAnd);
		function.RegisterFunction("Random", &hadar::Script::nativeRandom);
		function.RegisterFunction("Add", &hadar::Script::nativeAdd);
		
		function.RegisterFunction("PushString", &hadar::Script::nativePushString);
		function.RegisterFunction("PopString", &hadar::Script::nativePopString);
		
		function.RegisterFunction("DisplayMap", &hadar::Script::nativeDisplayMap);
		function.RegisterFunction("DisplayStatus", &hadar::Script::nativeDisplayStatus);
		function.RegisterFunction("ScriptMode", &hadar::Script::nativeScriptMode);
		function.RegisterFunction("On", &hadar::Script::nativeOn);
		function.RegisterFunction("OnArea", &hadar::Script::nativeOnArea);
		function.RegisterFunction("Talk", &hadar::Script::nativeTalk);
		function.RegisterFunction("TextAlign", &hadar::Script::nativeTextAlign);
		
		function.RegisterFunction("WarpPrevPos", &hadar::Script::nativeWarpPrevPos);
		function.RegisterFunction("PressAnyKey", &hadar::Script::nativePressAnyKey);
		function.RegisterFunction("Wait", &hadar::Script::nativeWait);
		function.RegisterFunction("LoadScript", &hadar::Script::nativeLoadScript);

		function.RegisterFunction("Map::Init", &hadar::Script::nativeMapInit);
		function.RegisterFunction("Map::SetType", &hadar::Script::nativeMapSetType);
		function.RegisterFunction("Map::SetEncounter", &hadar::Script::nativeMapSetEncounter);
		function.RegisterFunction("Map::SetStartPos", &hadar::Script::nativeMapSetStartPos);
		function.RegisterFunction("Map::SetTile", &hadar::Script::nativeMapSetTile);
		function.RegisterFunction("Map::SetRow", &hadar::Script::nativeMapSetRow);
		function.RegisterFunction("Map::ChangeTile", &hadar::Script::nativeMapChangeTile);
		function.RegisterFunction("Map::LoadFromFile", &hadar::Script::nativeMapLoadFromFile);
		
		function.RegisterFunction("Tile::CopyToDefaultTile", &hadar::Script::nativeTileCopyToDefaultTile);
		function.RegisterFunction("Tile::CopyToDefaultSprite", &hadar::Script::nativeTileCopyToDefaultSprite);
		function.RegisterFunction("Tile::CopyTile", &hadar::Script::nativeTileCopyTile);

		function.RegisterFunction("Flag::Set", &hadar::Script::nativeFlagSet);
		function.RegisterFunction("Flag::Reset", &hadar::Script::nativeFlagReset);
		function.RegisterFunction("Flag::IsSet", &hadar::Script::nativeFlagIsSet);
		function.RegisterFunction("Variable::Set", &hadar::Script::nativeVariableSet);
		function.RegisterFunction("Variable::Add", &hadar::Script::nativeVariableAdd);
		function.RegisterFunction("Variable::Get", &hadar::Script::nativeVariableGet);

		function.RegisterFunction("Battle::Init", &hadar::Script::nativeBattleInit);
		function.RegisterFunction("Battle::Start", &hadar::Script::nativeBattleStart);
		function.RegisterFunction("Battle::RegisterEnemy", &hadar::Script::nativeBattleRegisterEnemy);
		function.RegisterFunction("Battle::ShowEnemy", &hadar::Script::nativeBattleShowEnemy);
		function.RegisterFunction("Battle::Result", &hadar::Script::nativeBattleResult);

		function.RegisterFunction("Select::Init", &hadar::Script::nativeSelectInit);
		function.RegisterFunction("Select::Add", &hadar::Script::nativeSelectAdd);
		function.RegisterFunction("Select::Run", &hadar::Script::nativeSelectRun);
		function.RegisterFunction("Select::Result", &hadar::Script::nativeSelectResult);

		function.RegisterFunction("Party::PosX", &hadar::Script::nativePartyPosX);
		function.RegisterFunction("Party::PosY", &hadar::Script::nativePartyPosY);
		function.RegisterFunction("Party::PlusGold", &hadar::Script::nativePartyPlusGold);
		function.RegisterFunction("Party::Move", &hadar::Script::nativePartyMove);

		function.RegisterFunction("Player::IsAvailable", &hadar::Script::nativePlayerIsAvailable);
		function.RegisterFunction("Player::GetName", &hadar::Script::nativePlayerGetName);
		function.RegisterFunction("Player::GetGenderName", &hadar::Script::nativePlayerGetGenderName);
		function.RegisterFunction("Player::AssignFromEnemyData", &hadar::Script::nativePlayerAssignFromEnemyData);
		function.RegisterFunction("Player::ChangeAttribute", &hadar::Script::nativePlayerChangeAttribute);
		function.RegisterFunction("Player::GetAttribute", &hadar::Script::nativePlayerGetAttribute);

		function.RegisterFunction("Enemy::ChangeAttribute", &hadar::Script::nativeEnemyChangeAttribute);
	}

	// 원래는 position 값을 보고 정해야 함
	CSmScript<Script> script(function, getScriptFileName());
}

namespace
{
	avej::string s_file_name;
}

void hadar::Script::registerScriptFileName(const char* sz_file_name)
{
	s_file_name = sz_file_name;
}

const char* hadar::Script::getScriptFileName(void)
{
	return s_file_name;
}
