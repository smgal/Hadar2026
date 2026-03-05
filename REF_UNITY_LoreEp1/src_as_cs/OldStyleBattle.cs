using UnityEngine;
using UnityEngine.UI;
using System;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public static class OldStyleBattle
	{
		public static LabelEnemy[] enemy_status = null;
		public static int MAX_ENEMY = 0;
		private const int _NOT_ASSIGNED = -1;

		public enum RESULT_OF_ATTACK
		{
			HESITATE,
			HIT,
			MISS,
			CRITICAL_HIT,
			CRITICAL_MISS,
			NOT_ENOUGH_SP
		}

		public enum RESULT_OF_ATTACKED
		{
			RESISTED,
			DODGED,
			NO_DAMAGED,
			DAMAGED,
			POISONED,
			TURN_TO_UNCONSCIOUS,
			STILL_UNCONSCIOUS,
			TURN_TO_DEAD,
			STILL_DEAD
		}

		public delegate void FnCallBack0();
		public delegate void FnCallBack1(int i);

		public enum STATE
		{
			ON_MEAURE_COMBAT_POWER,
			IN_MEAURE_COMBAT_POWER,
			ON_COMMAND_EACH,
			IN_COMMAND_EACH,
			IN_WAITING,
			JUST_SELECTED,
			IN_PRESS_ANY_KEY,
			ON_BATTLE,
			IN_BATTLE,
			RESULT_WIN,
			RESULT_LOSE,
			RESULT_RUN_AWAY,
			MAX
		}

		public class CommandSub
		{
			public int O = _NOT_ASSIGNED; // object
			public RESULT_OF_ATTACK result_of_attack = RESULT_OF_ATTACK.HESITATE;
			public RESULT_OF_ATTACKED result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
			public int damage = 0;
		}

		public class Command: ICloneable
		{
			public int S = _NOT_ASSIGNED; // subject
			public int V = _NOT_ASSIGNED; // verb
			public int W = _NOT_ASSIGNED; // with
			public int O = _NOT_ASSIGNED; // object

			public RESULT_OF_ATTACK result_of_attack = RESULT_OF_ATTACK.HESITATE;
			public RESULT_OF_ATTACKED result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
			public int damage = 0;

			public List<CommandSub> multi = new List<CommandSub>();

			public void Reset()
			{
				S = V = W = O = _NOT_ASSIGNED;
				result_of_attack = RESULT_OF_ATTACK.HESITATE;
				result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				damage = 0;
				multi.Clear();
			}

			public object Clone()
			{
				Command obj = new Command();

				obj.S = this.S;
				obj.V = this.V;
				obj.W = this.W;
				obj.O = this.O;
				obj.result_of_attack = this.result_of_attack;
				obj.result_of_attacked = this.result_of_attacked;
				obj.damage = this.damage;
				obj.multi = new List<CommandSub>(this.multi);

				return obj;
			}
		}

		public static Command[] command = null;
		public static int ix_curr_command = 0;

		private static Command _curr_command = new Command();
		private static int _ix_curr_command_progress = 0;

		private static List<string> _battle_log = new List<string>();
		private static int _ix_battle_log = 0;

		private static FnCallBack1 _fn_just_selected_action = null;

		private static STATE _state = STATE.ON_COMMAND_EACH;

		public static STATE State
		{
			get { return _state; }
			set { _state = value; }
		}

		private static void _Reset()
		{
			if (command == null)
				command = new Command[CONFIG.MAX_PLAYER];

			for (int i = 0; i < command.Length; i++)
				command[i] = new Command();

			ix_curr_command = 0;
			_ix_curr_command_progress = 0;

			_battle_log.Clear();
			_ix_battle_log = 0;
		}

		public static void Init(int[,] ix_enemy)
		{
			_Reset();

			///////////////////////////////

			enemy_status = GameObj.panel_battle.GetComponentsInChildren<LabelEnemy>();

			// '2' is a magic key
			MAX_ENEMY = ix_enemy.Length / 2;

			for (int i = 0; i < GameRes.enemy.Length; i++)
			{
				GameRes.enemy[i].Valid = (i < MAX_ENEMY);
				if (GameRes.enemy[i].Valid)
					GameRes.enemy[i]._New(ix_enemy[i, 0], ix_enemy[i, 1]);
			}
		}

		public static void Run(bool cause_by_encounter)
		{
			for (int i = 0; i < GameRes.enemy.Length; i++)
			{
				if (GameRes.enemy[i].Valid)
					GameRes.enemy[i].Reset();
			}

			UpdateAllEnemy();

			GameRes.GameState = GAME_STATE.ON_BATTLE;

			if (cause_by_encounter)
				_state = STATE.ON_MEAURE_COMBAT_POWER;
			else
				_state = STATE.ON_COMMAND_EACH;
		}

		private static long __GetExperienceFromEnemy(ObjEnemy enemy)
		{
			long plus = enemy.attrib.level * 2;

			plus = plus * plus * plus / 8;

			return (plus > 0) ? plus : 1;
		}

		// Turn to unconscious가 발생할 때 
		private static long _PlusExperience(ObjPlayer player, ObjEnemy enemy)
		{
			long plus = __GetExperienceFromEnemy(enemy);

			player.exprience += plus;

			return plus;
		}

		private static long _PlusExperienceAll(ref ObjPlayer[] players, ObjEnemy[] enemies)
		{
			long plus = 0;

			foreach (var enemy in enemies)
			{
				if (enemy.IsValid())
					plus += __GetExperienceFromEnemy(enemy);
			}

			foreach (var player in players)
			{
				if (player.IsValid())
				{
					if (player.IsAvailable())
						player.exprience += plus;
					else
						player.exprience += (plus / 2);
				}
			}

			return plus;
		}

		private static long _PlusGold(ref ObjParty party, ObjEnemy[] enemies)
		{
			long plus = 0;

			foreach (var enemy in enemies)
			{
				if (enemy.IsValid())
				{
					int multiply = 0;
					{
						// 이상하긴 하지만 원작이 이러니...
						int index = enemy.attrib.level * 2;
						index = LibUtil.Clamp(index, 0, CreatureAttribOld.GetMaxIndexOfEnemy());

						CreatureAttribOld enemy_data = CreatureAttribOld.GetEnemy(index);
						multiply = Math.Max(Math.Min(enemy_data.ac, enemy_data.level), 1);
					}

					plus += (enemy.attrib.level * enemy.attrib.level * enemy.attrib.level * multiply);
				}
			}

			party.gold += plus;

			return plus;
		}

		public static void _Select_Run(FnCallBack1 fn_callback = null)
		{
			_fn_just_selected_action = fn_callback;

			GameEventMain.ResetArrowKey();

			GameObj.SetButtonGroup(BUTTON_GROUP.OK_UP_DOWN);

			GameObj.text_dialog.text = LibUtil.SmTextToRichText(GameRes.selection_list.GetCompleteString());

			_state = STATE.IN_WAITING;
		}

		public static void _PressAnyKey(FnCallBack1 fn_callback = null)
		{
			_fn_just_selected_action = fn_callback;

			GameEventMain.ResetArrowKey();
			GameObj.SetButtonGroup(BUTTON_GROUP.OK);
			
			_state = STATE.IN_PRESS_ANY_KEY;
		}

		/*
		 *           S     V     W     O
		 * s.att.   [F]    1          [E]
		 * s.mag.   [F]    2   s[M]   [E]
		 * m.mag.   [F]    3   m[M]
		 * s.cur.   [F]    4   s[C]   [F]
		 * m.cur.   [F]    5   m[C]
		 * use      [F]    6    [I]   [F]
		 * summ     ???
		 */

		public static class VERB
		{
			public const int NOT_ASSIGNED  = _NOT_ASSIGNED;
			public const int DO_NOTHING    = 0;
			public const int ATTACK_SINGLE = 1;
			public const int ATTACK_MULTI  = 2;
			public const int MAGIC_SINGLE  = 3;
			public const int MAGIC_MULTI   = 4;
			public const int CURE_SINGLE   = 5;
			public const int CURE_MULTI    = 6;
			public const int ITEM_USING    = 7;
			public const int SUMMON        = 8;
			public const int RUN_AWAY      = 9;
			public const int AUTO_BATTLE   = 10;
		}

		private static string _GetCurrentCommand(Command command)
		{
			string s = "";
			if (command.S >= 0)
			{
				s += GameRes.player[command.S].GetName(Yunjr.ObjNameBase.JOSA.SUB);

				switch (command.V)
				{
					case VERB.NOT_ASSIGNED:
						s += " [...]";
						break;
					case VERB.ATTACK_SINGLE:
						{
							string WITH_WEAPON = GameRes.player[command.S].equip[(int)EQUIP.HAND].name.GetName(ObjNameBase.JOSA.WITH);
							if (command.O == _NOT_ASSIGNED)
								s += " [...]을 " + WITH_WEAPON + " 공격한다";
							else
								s += " " + GameRes.enemy[command.O].GetName(Yunjr.ObjNameBase.JOSA.OBJ) + " " + WITH_WEAPON + " 공격한다";
						}
						break;
					case VERB.ATTACK_MULTI:
						{
							string WITH_WEAPON = GameRes.player[command.S].equip[(int)EQUIP.HAND].name.GetName(ObjNameBase.JOSA.WITH);
							s += " 적 전체에게 " + WITH_WEAPON + " 공격한다";
						}
						break;
					case VERB.MAGIC_SINGLE:
						if (command.O != _NOT_ASSIGNED)
						{
							if (command.W == _NOT_ASSIGNED)
							{
								s += " " + GameRes.enemy[command.O].GetName(ObjNameBase.JOSA.OBJ) + " 마법으로 공격한다";
							}
							else
							{
								ObjNameBase with = new ObjNameBase();
								int index = command.W - 1;
								with.SetName(GameStrRes.GetMagicName(0, (index >= 0) ? index : 0));
								s += " " + GameRes.enemy[command.O].GetName() + "에게 " + with.GetName(ObjNameBase.JOSA.WITH) + " 공격한다";
							}
						}
						else
						{
							s += " [...]을" + " 마법으로 공격한다";
						}
						break;
					case VERB.MAGIC_MULTI:
						if (command.W == _NOT_ASSIGNED)
							s += " 적들 전체에게 마법으로 공격한다";
						else
						{
							ObjNameBase with = new ObjNameBase();
							int index = command.W - 11;
							with.SetName(GameStrRes.GetMagicName(1, (index >= 0) ? index : 0));
							s += " 적들에게 " + with.GetName(ObjNameBase.JOSA.WITH) + " 공격한다";
						}
						break;
					case VERB.CURE_SINGLE:
						if (command.O == _NOT_ASSIGNED)
							s += " [...]에게" + " 회복 마법을 시도한다";
						else if (command.W == _NOT_ASSIGNED)
						{
							if (command.S == command.O)
								s += " 자신에게 회복 마법을 시도한다";
							else
								s += " " + GameRes.player[command.O].GetName() + "에게 회복 마법을 시도한다";
						}
						else
						{
							ObjNameBase with = new ObjNameBase();
							// 만약 자동 전투에서 치료 기능이 생긴다면 아래의 메시지는 엉뚱한 것이 출력 된다.
							with.SetName(GameRes.selection_list.GetCurrentItem());

							if (command.S == command.O)
								s += " 자신에게 " + with.GetName(ObjNameBase.JOSA.OBJ) + " 시도한다";
							else
								s += " " + GameRes.player[command.O].GetName() + "에게 "+ with.GetName(ObjNameBase.JOSA.OBJ) + " 시도한다";
						}
						break;
					case VERB.CURE_MULTI:
						s += " 일행 전체에게" + " 회복 마법을 시도한다";
						break;
					case VERB.ITEM_USING:
						// 만약 자동 전투에서 아이템 사용 기능이 생긴다면 아래의 메시지는 엉뚱한 것이 출력 된다.
						// s += " [...]에게" + " [...]을" + " 사용한다";
						s += " " + GameRes.selection_list.GetCurrentItem();

						break;
					case VERB.SUMMON:
						if (command.W == _NOT_ASSIGNED)
							s += " 조력자 소환을 시도한다";
						else
						{
							ObjNameBase with = new ObjNameBase();
							with.SetName(GameRes.selection_list.GetCurrentItem());
							s += " " + with.GetName(ObjNameBase.JOSA.OBJ) + " 시도한다";
						}
						break;
					case VERB.RUN_AWAY:
						s += " 도망을 시도한다";
						break;
					case VERB.AUTO_BATTLE:
						s += " 각자 알아서 전투할 것을 명령한다";
						break;
					case VERB.DO_NOTHING:
					default:
						s += " [...]";
						break;
				}
			}
			else
			{
				s = "[...]";
			}

			{
				int index = 0;
				int length = LibUtil.SmTextIndexInWidth(s, CONFIG.CONSOLE_CONTENTS_WIDTH, CONFIG.FONT_SIZE);

				string sm_1 = s.Substring(index, length) + '\n';
				index += length;

				while (index < s.Length && s[index] == ' ')
					++index;

				string sm_2 = s.Substring(index, s.Length - index);

				return sm_1 + sm_2;
			}
		}

		private static Yunjr.Equiped _GetPlayerEquiped(int ix_player, Yunjr.EQUIP equip)
		{
			return GameRes.player[ix_player].equip[(uint)equip];
		}

		private static void __AssistAttackToOneEnemy(ObjPlayer player)
		{
			_curr_command.V = VERB.ATTACK_SINGLE;
			_curr_command.W = (int)GameRes.player[_curr_command.S].equip[(uint)Yunjr.EQUIP.HAND].item.res_id.GetId();
			_curr_command.O = 0;
		}

		private static void __AssistAttackToAllEnemies(ObjPlayer player)
		{
			_curr_command.V = VERB.MAGIC_MULTI;
			_curr_command.W = (int)GameRes.player[_curr_command.S].equip[(uint)Yunjr.EQUIP.HAND].item.res_id.GetId();
			_curr_command.O = 0;
		}

		// 소환수로부터 호출되지는 않음
		private static bool __AssistMagic(ObjPlayer player)
		{
			bool attempted_to_attack = false;
			
			if (player.skill[(int)SKILL_TYPE.DAMAGE] >= 10)
			{
				// TODO2: __AssistMagic()이 1번 이외에도 SP를 보고 적당히 결정해야 함
				// 원본에서는 1~20 까지의 마법이 되도록 하려 하였음 (그러나 코딩 오류?)
				int magic_index = 1;

				int required_sp = player.GetRequiredSP(magic_index);

				if (player.sp >= required_sp)
				{
					if (magic_index >= 1 && magic_index <= 10)
					{
						_curr_command.V = VERB.MAGIC_SINGLE;
						_curr_command.W = magic_index;
					}
					else if (magic_index >= 11 && magic_index <= 20)
					{
						_curr_command.V = VERB.MAGIC_MULTI;
						_curr_command.W = magic_index - 10;
					}
					_curr_command.O = 0;

					attempted_to_attack = true;
				}
			}

			return attempted_to_attack;
		}

		private static bool __AssistEsp(ObjPlayer player)
		{
			// TODO2: __AssistEsp()는 지원하지 않는 것으로...
			bool attempted_to_attack = false;
			return attempted_to_attack;
		}

		private static void __AssistAttack(ObjPlayer player, FnCallBack0 fn_callback = null)
		{
			switch (player.race)
			{
				case RACE.HUMAN:
				case RACE.UNKNOWN:
					switch (LibUtil.GetClassType(player.clazz))
					{
						case CLASS_TYPE.PHYSICAL_FORCE:
						case CLASS_TYPE.HYBRID1:
						case CLASS_TYPE.HYBRID2:
							__AssistAttackToOneEnemy(player);
							break;
						case CLASS_TYPE.HYBRID3:
						case CLASS_TYPE.MAGIC_USER:
							bool have_attempted_to_attack = false;

							if (LibUtil.GetClassType(player.clazz) == CLASS_TYPE.MAGIC_USER)
								have_attempted_to_attack = __AssistMagic(player);
							else if (LibUtil.GetClassType(player.clazz) == CLASS_TYPE.HYBRID3)
								have_attempted_to_attack = __AssistEsp(player);
							else
								Debug.Assert(false);

							if (!have_attempted_to_attack)
								__AssistAttackToOneEnemy(player);

							break;
					}
					break;
				case RACE.ELEMENTAL:
				case RACE.GIANT:
				case RACE.GOLEM:
				case RACE.DRAGON:
				case RACE.ANGEL:
				case RACE.DEVIL:
					/* 원본 코드
						// (weapon == 29)에 대응하는 것은 '화염'이며,
						// <불의 정령 소환>{'불의 정령' | '사라만다' | '아저' | '이프리트'} 과 <죽은 자의 소생> 중 '에인션트 메이지'
						if player[person].weapon = 29 then
							Assist_Attack_One
						else
							Assist_Attack_All;
					*/
					if (player.equip[(int)EQUIP.HAND].item.param.item_type == ITEM_TYPE.SUMMON_MULTI)
						__AssistAttackToAllEnemies(player);
					else
						__AssistAttackToOneEnemy(player);
					break;
				default:
					Debug.Assert(false);
					break;
			}

			if (fn_callback != null)
				fn_callback();
		}

		private static void _SelectFirstAction(FnCallBack1 fn_callback = null)
		{
			if (_curr_command.S < 0 || _curr_command.S >= GameRes.player.Length)
				return;

			bool is_magic_user = (GameRes.player[_curr_command.S].GetMaxSP() > 0);
			bool is_magic_attacker = is_magic_user && (GameRes.player[_curr_command.S].skill[(int)SKILL_TYPE.DAMAGE] >= 10);

			GameRes.selection_list.Init();

			string with_weapon = _GetPlayerEquiped(_curr_command.S, Yunjr.EQUIP.HAND).name.GetName(Yunjr.ObjNameBase.JOSA.WITH);
			GameRes.selection_list.AddItem(with_weapon + " 한 명의 적을 공격한다", VERB.ATTACK_SINGLE);
			GameRes.selection_list.AddItem("한 명의 적에게 마법을 사용한다", VERB.MAGIC_SINGLE, is_magic_attacker);
			GameRes.selection_list.AddItem("전체의 적에게 마법을 사용한다", VERB.MAGIC_MULTI, is_magic_attacker);
			GameRes.selection_list.AddItem("한 명의 아군을 치료한다", VERB.CURE_SINGLE, is_magic_user);
			GameRes.selection_list.AddItem("전체의 아군을 치료한다", VERB.CURE_MULTI, is_magic_user);
			GameRes.selection_list.AddItem("아이템 사용 및 소환을 한다", VERB.ITEM_USING, false);

			if (_curr_command.S == 0)
				GameRes.selection_list.AddItem("각자 알아서 전투를 한다", VERB.AUTO_BATTLE);
			else
				GameRes.selection_list.AddItem("도망을 시도한다", VERB.RUN_AWAY);

			_curr_command.V = GameRes.selection_list.GetRealIndex(VERB.ATTACK_SINGLE);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectOneFriend(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 3;

			GameRes.selection_list.Init();
			for (int i = 0; i < CONFIG.MAX_PLAYER; i++)
			{
				if (GameRes.player[i].IsValid())
					GameRes.selection_list.AddItem(GameRes.player[i].Name, i);
			}

			_curr_command.O = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectOneEnemy(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 3;

			GameRes.selection_list.Init();
			for (int i = 0; i < MAX_ENEMY; i++)
				GameRes.selection_list.AddItem(GameRes.enemy[i].Name, i);

			_curr_command.O = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}
	
		private static void _SelectAttackMagicForOne(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 2;

			GameRes.selection_list.Init(1, true);

			GameRes.selection_list.AddTitle("");
			GameRes.selection_list.AddGuide("");

			for (int i = 0; i < GameStrRes.GetMaxMagicName(0); i++)
				GameRes.selection_list.AddItem(GameStrRes.GetMagicName(0, i), i+1);

			_curr_command.V = VERB.MAGIC_SINGLE;
			_curr_command.W = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectAttackMagicForAll(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 2;

			GameRes.selection_list.Init(1, true);

			GameRes.selection_list.AddTitle("");
			GameRes.selection_list.AddGuide("");

			for (int i = 0; i < GameStrRes.GetMaxMagicName(1); i++)
				GameRes.selection_list.AddItem(GameStrRes.GetMagicName(1, i), i + 11);

			_curr_command.V = VERB.MAGIC_MULTI;
			_curr_command.W = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectCureMagicForOne(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 2;

			GameRes.selection_list.Init();

			GameRes.selection_list.AddTitle("");
			GameRes.selection_list.AddGuide("");

			GameRes.selection_list.AddItem("개인 치료");
			GameRes.selection_list.AddItem("개인 독 제거");
			GameRes.selection_list.AddItem("개인 의식 돌림");
			GameRes.selection_list.AddItem("개인 부활");
			GameRes.selection_list.AddItem("개인 복합 치료");

			_curr_command.V = VERB.CURE_SINGLE;
			_curr_command.W = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectCureMagicForAll(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 2;

			GameRes.selection_list.Init();

			GameRes.selection_list.AddTitle("");
			GameRes.selection_list.AddGuide("");

			GameRes.selection_list.AddItem("전체 치료");
			GameRes.selection_list.AddItem("전체 독 제거");
			GameRes.selection_list.AddItem("전체 의식 돌림");
			GameRes.selection_list.AddItem("전체 부활");
			GameRes.selection_list.AddItem("전체 복합 치료");

			_curr_command.V = VERB.CURE_MULTI;
			_curr_command.W = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectKindOfItem(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 2;

			GameRes.selection_list.Init(1, true);

			GameRes.selection_list.AddTitle("");
			GameRes.selection_list.AddGuide("");

			GameRes.selection_list.AddItem("약초나 약물을 사용한다", 1);
			GameRes.selection_list.AddItem("크리스탈을 사용한다", 2);

			_curr_command.V = VERB.ITEM_USING;
			_curr_command.W = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static void _SelectMedicalItem(FnCallBack1 fn_callback = null)
		{
			if (_curr_command.S < 0 && _curr_command.S >= GameRes.player.Length)
				return;

			ObjPlayer player = GameRes.player[_curr_command.S];

			if (!(player.IsValid() && player.IsAvailable()))
			{
				ObjNameBase name = player.GetGenderName();
				Console.DisplaySmText(name.GetName(ObjNameBase.JOSA.SUB) + " 물건을 사용할 수 있는 상태가 아닙니다.", true);
				_PressAnyKey();
				return;
			}

			GameRes.selection_list.Init(1, true);
			GameRes.selection_list.AddGuide("사용할 물품을 고르시오.\n");

			int num_valid_items = 0;
			// 5 is a magic key
			for (int i = 0; i < 5; i++)
			{
				if (GameRes.party.core.item[i] > 0)
				{
					Debug.Assert(i >=0 && i < GameStrRes.GetMaxItemName());
					
					GameRes.selection_list.AddItem(GameStrRes.GetItemName(i), i + 1);

					++num_valid_items;
				}
			}

			if (num_valid_items == 0)
			{
				Console.DisplaySmText(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.YOU_HAVE_NO_ITEMS), true);
				return;
			}

			GameRes.selection_list.Run
			(
				delegate ()
				{
					// TODO: 누구에게 아이템을 쓸지를 정한 뒤에 Console.UseItem()의 내용이 적용되어야 한다.
				}
			);
		}

		private static void _SelectCrystalItem(FnCallBack1 fn_callback = null)
		{
		}

		private static void _SelectMonsterToSummon(FnCallBack1 fn_callback = null)
		{
			_ix_curr_command_progress = 2;

			GameRes.selection_list.Init(1, true);

			GameRes.selection_list.AddTitle("");
			GameRes.selection_list.AddGuide("");

			GameRes.selection_list.AddItem("불의 정령 소환", 1);
			GameRes.selection_list.AddItem("물의 정령 소환", 2);
			GameRes.selection_list.AddItem("공기의 정령 소환", 3);
			GameRes.selection_list.AddItem("땅의 정령 소환", 4);
			GameRes.selection_list.AddItem("죽은 자의 소생", 5);
			GameRes.selection_list.AddItem("다른 차원 생물 소환", 6);
			GameRes.selection_list.AddItem("거인을 부름", 7);
			GameRes.selection_list.AddItem("고렘을 부름", 8);
			GameRes.selection_list.AddItem("용을 부름", 9);
			GameRes.selection_list.AddItem("라이칸스로프 소환", 10);

			_curr_command.V = VERB.SUMMON;
			_curr_command.W = GameRes.selection_list.GetRealIndex(0);
			GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

			_Select_Run(fn_callback);
		}

		private static STATE _ProcessOnCombatPower()
		{
			// TODO: [우선] _ProcessOnCombatPower()
			long sum_of_player_power = 0;
			foreach (var player in GameRes.player)
			{
				if (player.IsAvailable())
				{
					sum_of_player_power += player.hp;
					sum_of_player_power += player.sp;
					sum_of_player_power += player.GetPAP();
					sum_of_player_power += player.GetAcByArmor();
				}
			}

			long sum_of_enemy_power = 0;
			foreach (var enemy in GameRes.enemy)
			{
				if (enemy.IsAvailable() && enemy.state.doppelganger == 0)
				{
					sum_of_enemy_power += enemy.state.regenerative_hp;
					sum_of_enemy_power += enemy.state.hp;
					sum_of_enemy_power += enemy.attrib.strength;
					sum_of_enemy_power += enemy.attrib.ac;
					sum_of_enemy_power += enemy.attrib.level;
					sum_of_enemy_power += enemy.attrib.special;
					sum_of_enemy_power += enemy.attrib.special_cast_level;
				}
			}

			return STATE.IN_MEAURE_COMBAT_POWER;
		}

		private static STATE _ProcessInCombatPower()
		{
			// TODO: [우선] _ProcessInCombatPower()
			return STATE.ON_COMMAND_EACH;
		}

		private static STATE _ProcessOnCommandEach()
		{
			for (int i = 0; i < command.Length; i++)
				command[i].Reset();

			ix_curr_command = 0;
			_ix_curr_command_progress = 0;

			return STATE.IN_COMMAND_EACH;
		}

		private static STATE _ProcessInCommandEach()
		{
			bool passed = false;
			do
			{
				if (ix_curr_command >= GameRes.player.Length)
					return STATE.ON_BATTLE;

				if (GameRes.player[ix_curr_command].IsValid() && GameRes.player[ix_curr_command].IsAvailable())
					passed = true;
				else
					ix_curr_command++;
			} while (!passed);

			if (command[ix_curr_command].S == _NOT_ASSIGNED)
			{
				_curr_command.Reset();
				_curr_command.S = ix_curr_command;
				_ix_curr_command_progress = 1;

				if (_curr_command.S != GameRes.GetIndexOfResevedPlayer())
				{
					_SelectFirstAction
					(
						delegate (int ix_action)
						{
							_curr_command.V = ix_action;
							_ix_curr_command_progress = 2;

							switch (_curr_command.V)
							{
								case VERB.ATTACK_SINGLE:
									_curr_command.W = (int)GameRes.player[_curr_command.S].equip[(uint)Yunjr.EQUIP.HAND].item.res_id.GetId();

									_SelectOneEnemy
									(
										delegate (int index)
										{
											_curr_command.O = index;

											// assign to command list
											command[ix_curr_command++] = _curr_command.Clone() as Command;
										}
									);
									break;
								case VERB.ATTACK_MULTI:
									// 여기는 진입하면 안 됨. 만약 진입할 경우는 구현이 필요함
									Debug.Assert(false);
									break;
								case VERB.MAGIC_SINGLE:
									// TODO: BattleESP 가 추가되어야 함
									_SelectOneEnemy
									(
										delegate (int index)
										{
											_curr_command.O = index;

											_SelectAttackMagicForOne
											(
												delegate (int ix_spell)
												{
													_curr_command.W = ix_spell;

													// assign to command list
													command[ix_curr_command++] = _curr_command.Clone() as Command;
												}
											);
										}
									);
									break;
								case VERB.MAGIC_MULTI:
									{
										_SelectAttackMagicForAll
										(
											delegate (int ix_spell)
											{
												_curr_command.W = ix_spell;

												// assign to command list
												command[ix_curr_command++] = _curr_command.Clone() as Command;
											}
										);
									}
									break;
								case VERB.CURE_SINGLE:
									_SelectOneFriend
									(
										delegate (int index)
										{
											_curr_command.O = index;

											_SelectCureMagicForOne
											(
												delegate (int ix_spell)
												{
													ObjPlayer player = GameRes.player[_curr_command.S];
													ObjPlayer target = GameRes.player[_curr_command.O];

													string message = "";

													switch (ix_spell)
													{
														case 1:
															message = GameRes.party.CureWounds(player, target);
															break;
														case 2:
															message = GameRes.party.CurePoison(player, target);
															break;
														case 3:
															message = GameRes.party.AwakeFromUnconsciousness(player, target);
															break;
														case 4:
															message = GameRes.party.RaiseDead(player, target);
															break;
														case 5:
															message = GameRes.party.RaiseDead(player, target);
															message += "\n";
															message += GameRes.party.AwakeFromUnconsciousness(player, target);
															message += "\n";
															message += GameRes.party.CurePoison(player, target);
															message += "\n";
															message += GameRes.party.CureWounds(player, target);
															break;
													}

													GameObj.UpdatePlayerStatus();

													if (message.Length > 0)
													{
														Console.DisplaySmText(message, true);
														_PressAnyKey();
													}
												}
											);

											// assign to command list
											command[ix_curr_command++] = _curr_command.Clone() as Command;
										}
									);
									break;
								case VERB.CURE_MULTI:
									{
										_SelectCureMagicForAll
										(
											delegate (int ix_spell)
											{
												ObjPlayer player = GameRes.player[_curr_command.S];

												string message = "";
												string adder = "";

												foreach (var target in GameRes.player)
												{
													if (!target.IsValid())
														continue;

													adder = "";

													switch (ix_spell)
													{
														case 1:
															adder = GameRes.party.CureWounds(player, target);
															break;
														case 2:
															adder = GameRes.party.CurePoison(player, target);
															break;
														case 3:
															adder = GameRes.party.AwakeFromUnconsciousness(player, target);
															break;
														case 4:
															adder = GameRes.party.RaiseDead(player, target);
															break;
														case 5:
															if (target.IsValid() && target.dead == 0 && target.unconscious == 0 && target.poison == 0 && target.hp >= target.GetMaxHP())
															{
																adder = "@F" + target.GetName(ObjNameBase.JOSA.SUB) + " 치료할 필요가 없습니다.@@";
															}
															else
															{
																GameRes.party.RaiseDead(player, target);
																GameRes.party.AwakeFromUnconsciousness(player, target);
																GameRes.party.CurePoison(player, target);
																GameRes.party.CureWounds(player, target);
																adder = "@F" + target.GetName(ObjNameBase.JOSA.SUB) + " 복합 치료를 받았습니다.@@";
															}
															break;
													}

													if (adder.Length > 0)
														message += adder + "\n";
												}

												GameObj.UpdatePlayerStatus();

												if (message.Length > 0)
												{
													Console.DisplaySmText(message, true);
													_PressAnyKey();
												}
											}
										);

										// assign to command list
										command[ix_curr_command++] = _curr_command.Clone() as Command;
									}
									break;
								case VERB.ITEM_USING:
									// TODO: Battle (VERB.ITEM_USING + VERB.SUMMON)

									// TODO: 또는 소환 마법
									{
										int ix_reserved = GameRes.GetIndexOfResevedPlayer();

										if (!GameRes.player[ix_reserved].IsValid())
										{
											// 소환이 가능한 상태
											_SelectMonsterToSummon
											(
												delegate (int ix_spell)
												{
													_curr_command.W = ix_spell;

													// assign to command list
													command[ix_curr_command++] = _curr_command.Clone() as Command;

													ObjPlayer player = GameRes.player[_curr_command.S];
													string message = GameRes.party.SummonSomething(player, ix_spell);
												}
											);
										}
										else
										{
											_SelectKindOfItem
											(
												delegate (int ix_index)
												{
													switch (ix_index)
													{
													// TODO: Use items such as a herb
													case 1:
														_SelectMedicalItem();
														break;
													// TODO: Use items such as a crystal
													case 2:
														_SelectCrystalItem
														(
															delegate (int ix_spell)
															{
																switch (ix_spell)
																{
																	case 0:
																	default:
																		break;
																}
															}
														);
														break;
													}
												}
											);
										}
									}

									break;
								case VERB.RUN_AWAY:
									if (GameRes.player[_curr_command.S].TryToRunAway())
									{
										Console.DisplaySmText("@B성공적으로 도망을 갔다@@", true);

										_PressAnyKey
										(
											delegate (int dummy)
											{
												GameRes.GameState = GAME_STATE.OUT_BATTLE;
												_state = STATE.RESULT_RUN_AWAY;
											}
										);
									}
									else
									{
										Console.DisplaySmText("그러나, 일행은 성공하지 못했다", true);
										_PressAnyKey();
									}

									command[ix_curr_command++] = _curr_command.Clone() as Command;

									break;
								case VERB.AUTO_BATTLE:
									_Reset();

									ix_curr_command = 0;
									foreach (var player in GameRes.player)
									{
										if (GameRes.player[ix_curr_command].IsValid() && GameRes.player[ix_curr_command].IsAvailable())
										{
											_curr_command.Reset();
											_curr_command.S = ix_curr_command;

											__AssistAttack
											(
												GameRes.player[_curr_command.S],
												delegate ()
												{
													command[ix_curr_command] = _curr_command.Clone() as Command;
												}
											);
										}

										ix_curr_command++;
									}
									break;

								default:
									GameRes.GameState = GAME_STATE.OUT_BATTLE;
									break;
							}
						}
					);
				}
				else
				{
					__AssistAttack
					(
						GameRes.player[_curr_command.S],
						delegate()
						{
							command[ix_curr_command++] = _curr_command.Clone() as Command;
						}
					);
				}
			}
			else
			{
				Debug.Log("????? OldStyleBattle::Process() error??");
			}

			return _state;
		}

		private static STATE _ProcessInWaiting()
		{
			int dy = (GameEventMain.IsClicked(BUTTON.ARROW_UP) || Input.GetKey(KeyCode.UpArrow)) ? -1 : 0;
			dy = (GameEventMain.IsClicked(BUTTON.ARROW_DOWN) || Input.GetKey(KeyCode.DownArrow)) ? 1 : dy;

			if (dy != 0)
			{
				int ix_min = 1;
				int ix_max = GameRes.selection_list.items.Count;

				int index = GameRes.selection_list.ix_curr;

				do
				{
					index += LibUtil.Sign(dy);

					index = (index < ix_max) ? index : ix_min;
					index = (index >= ix_min) ? index : ix_max - 1;

				} while (!GameRes.selection_list.IsEnabled(index));

				GameRes.selection_list.ix_curr = index;

				switch (_ix_curr_command_progress)
				{
					case 0:
						_curr_command.S = GameRes.selection_list.GetRealIndex(index);
						break;
					case 1:
						_curr_command.V = GameRes.selection_list.GetRealIndex(index);
						break;
					case 2:
						_curr_command.W = GameRes.selection_list.GetRealIndex(index);
						break;
					case 3:
						_curr_command.O = GameRes.selection_list.GetRealIndex(index);
						break;
				}

				GameRes.selection_list.AddGuide(_GetCurrentCommand(_curr_command));

				GameObj.text_dialog.text = LibUtil.SmTextToRichText(GameRes.selection_list.GetCompleteString());
			}

			return _state;
		}

		private static STATE _ProcessJustSelected()
		{
			_state = STATE.IN_COMMAND_EACH;

			if (_fn_just_selected_action != null)
			{
				FnCallBack1 fn_local_just_selected_action = _fn_just_selected_action;
				_fn_just_selected_action = null;

				fn_local_just_selected_action(GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr));

				GameEventMain.ResetArrowKey();
			}

			return _state;
		}

		private static STATE _ProcessPressAnyKey()
		{
			return _state;
		}

		private enum BATTLE_STATE
		{
			FRIEND_TURN,
			FRIEND_TURN_END,
			ENEMY_TURN,
			ENEMY_TURN_MESSAGE,
			ENEMY_TURN_END
		}

		private static BATTLE_STATE _battle_state = BATTLE_STATE.FRIEND_TURN;
		private static int _battle_state_turn_index = 0;

		private static STATE _ProcessOnBattle()
		{
			_battle_state = BATTLE_STATE.FRIEND_TURN;
			_battle_state_turn_index = 0;

			return STATE.IN_BATTLE;
		}

		// Search a next target if the current target is not available
		private static int __GetProperTarget(int expected)
		{
			if (expected >= 0)
			{
				int i = expected;
				expected = _NOT_ASSIGNED;
				for (; i < GameRes.enemy.Length; i++)
				{
					if (GameRes.enemy[i].IsValid())
					{
						if ((GameRes.enemy[i].state.unconscious == 0 || CONFIG.CRUEL_MODE) && GameRes.enemy[i].state.dead == 0)
						{
							expected = i;
							break;
						}
					}
				}
			}

			return expected;
		}

		private static void _ProcessInBattlePlayerSingleAttack(ref Command command)
		{
			// Default value for any result
			command.result_of_attack = RESULT_OF_ATTACK.HESITATE;
			command.result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
			command.damage = 0;

			// Search a next target if the current target is not available
			command.O = __GetProperTarget(command.O);

			if (command.O == _NOT_ASSIGNED)
				return;

			ObjPlayer player = GameRes.player[command.S];
			ObjEnemy enemy = GameRes.enemy[command.O];

			RESULT_OF_ATTACK state_of_attack = RESULT_OF_ATTACK.HESITATE;
			RESULT_OF_ATTACKED state_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;

			double critical = Yunjr.LibUtil.GetRandomPercentage();
			if (critical < 10.0f)
			{
				// Critical hit or miss
				double lucky_rate = Yunjr.LibUtil.GetRandomProbability() * player.status[(int)STATUS.LUC] / CONFIG.MAX_VALUE_OF_STATUS;
				Debug.Assert(lucky_rate >= 0.0 && lucky_rate <= 1.0);
				double baseline = 3.0 + lucky_rate * 4.0;
				if (critical >= baseline)
					state_of_attack = RESULT_OF_ATTACK.CRITICAL_HIT;
				else
					state_of_attack = RESULT_OF_ATTACK.CRITICAL_MISS;
			}
			else
			{
				// Hit rate
				if (player.GetRateHit() >= Yunjr.LibUtil.GetRandomProbability())
					state_of_attack = RESULT_OF_ATTACK.HIT;
				else
					state_of_attack = RESULT_OF_ATTACK.MISS;
			}

			if (enemy.state.hp > 0)
			{
				if (state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT || state_of_attack == RESULT_OF_ATTACK.HIT)
				{
					// Resist rate (from En)
					if (Yunjr.LibUtil.GetRandomPercentage() < enemy.attrib.resistance_1)
						state_of_attacked = RESULT_OF_ATTACKED.RESISTED;

					// TODO2: 0~100인지를 밸런스를 맞춰서 설정
					if (Yunjr.LibUtil.GetRandomPercentage() < enemy.attrib.agility)
						state_of_attacked = RESULT_OF_ATTACKED.DODGED;
				}
			}

			// My attack works
			if ((state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT || state_of_attack == RESULT_OF_ATTACK.HIT) && state_of_attacked == RESULT_OF_ATTACKED.NO_DAMAGED)
			{
				int damage = player.GetPAP();

				if (state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT)
				{
					double critical_rate = 1.0 + 1.0 * player.status[(int)STATUS.LUC] / CONFIG.MAX_VALUE_OF_STATUS;
					damage = (int)(damage * critical_rate + 0.5);
				}

				/*
					int damage = (pPlayer->strength * pPlayer->pow_of_weapon * pPlayer->level[0]) / 20;
					damage -= (damage * AvejUtil::Random(50) / 100);
					damage -= (pEnemy->ac * pEnemy->level * (AvejUtil::Random(10)+1) / 10);
				 */

				// TODO2: 밸런스를 위해 값을 조정
				int ac = enemy.attrib.ac * enemy.attrib.level;

				damage -= ac;

				if (damage > 0)
				{
					if (enemy.state.dead > 0)
					{
						enemy.state.dead += damage;
						state_of_attacked = RESULT_OF_ATTACKED.STILL_DEAD;
					}
					else if (enemy.state.unconscious > 0)
					{
						enemy.state.unconscious += damage;
#if true
						enemy.state.dead = 1;
						state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_DEAD;
#else
						state_of_attacked = RESULT_OF_ATTACKED.STILL_UNCONSCIOUS;

						if (enemy.state.unconscious > enemy.GetMaxHp())
						{
							enemy.state.unconscious = enemy.GetMaxHp();
							enemy.state.dead = 1;
							state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_DEAD;
						}
#endif
					}
					else
					{
						enemy.state.hp -= damage;
						state_of_attacked = RESULT_OF_ATTACKED.DAMAGED;

						if (enemy.state.hp <= 0)
						{
							enemy.state.hp = 0;
							enemy.state.unconscious = 1;
							state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_UNCONSCIOUS;
						}
					}

					command.damage = damage;
				}
				else
				{
					state_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				}
			}

			command.result_of_attack = state_of_attack;
			command.result_of_attacked = state_of_attacked;
		}

		private static string _GetMessageForSingleAttack(Command command)
		{
			string message = "";

			ObjPlayer player = GameRes.player[command.S];
			ObjEnemy enemy = (command.O >= 0) ? GameRes.enemy[command.O] : null;

			switch (command.result_of_attack)
			{
				case RESULT_OF_ATTACK.HESITATE:
				case RESULT_OF_ATTACK.NOT_ENOUGH_SP:
					message = player.GetName(ObjNameBase.JOSA.SUB) + "잠시 주저했다";
					break;
				case RESULT_OF_ATTACK.MISS:
					message = player.GetName() + "의 공격은 빗나갔다 ....";
					break;
				case RESULT_OF_ATTACK.CRITICAL_MISS:
					message = player.GetName(ObjNameBase.JOSA.SUB) + " 공격 타이밍을 놓쳤다";
					break;
				case RESULT_OF_ATTACK.HIT:
				case RESULT_OF_ATTACK.CRITICAL_HIT:
					switch (command.result_of_attacked)
					{
						case RESULT_OF_ATTACKED.RESISTED:
							message = "적은 " + player.GetName() + "의 공격을 저지했다";
							break;
						case RESULT_OF_ATTACKED.DODGED:
							message = "그러나, 적은 " + player.GetName() + "의 공격을 피했다";
							break;
						case RESULT_OF_ATTACKED.NO_DAMAGED:
							message = "그러나, 적은 " + player.GetName() + "의 공격을 막았다";
							break;
						case RESULT_OF_ATTACKED.DAMAGED:
							message = "적은 @F" + (command.damage).ToString() + "@@만큼의 피해를 입었다";
							break;
						case RESULT_OF_ATTACKED.POISONED:
							message = "적은 당신의 공격으로 중독되었다";
							break;
						case RESULT_OF_ATTACKED.TURN_TO_UNCONSCIOUS:
							message = "@C적은 " + player.GetName() + "의 공격으로 의식불명이 되었다@@";
							long exp_up = _PlusExperience(player, enemy);
							message += "\n@E" + player.GetName(ObjNameBase.JOSA.SUB) + " @B" + (exp_up).ToString() + "@@만큼 경험치를 얻었다!@@";
							break;
						case RESULT_OF_ATTACKED.STILL_UNCONSCIOUS:
							message = "[ERROR] RESULT_OF_ATTACKED.STILL_UNCONSCIOUS";
							break;
						case RESULT_OF_ATTACKED.TURN_TO_DEAD:
							message = "@C당신은 적에게 마지막 일격을 가했다@@";
							break;
						case RESULT_OF_ATTACKED.STILL_DEAD:
							message = "[ERROR] RESULT_OF_ATTACKED.STILL_DEAD";
							break;
					}
					break;
			}

			return message;
		}

		private static void _ProcessInBattlePlayerMultiAttack(ref Command command)
		{
			for (int i = 0; i < MAX_ENEMY; i++)
			{
				if (GameRes.enemy[i].IsValid())
				{
					command.O = i;
					_ProcessInBattlePlayerSingleAttack(ref command);

					if (command.O == _NOT_ASSIGNED)
						break;
				}
			}

			command.O = _NOT_ASSIGNED;
		}

		private static string _GetMessageForMultiAttack(Command command)
		{
			// TODO2: _GetMessageForMultiAttack()은 원작의 메시지와 내용이 다르다
			return "";
		}

		private static void _ProcessInBattlePlayerSingleMagic(ref Command command)
		{
			// Default value for any result
			command.result_of_attack = RESULT_OF_ATTACK.HESITATE;
			command.result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
			command.damage = 0;

			// Search a next target if the current target is not available
			command.O = __GetProperTarget(command.O);

			if (command.O == _NOT_ASSIGNED)
				return;

			ObjPlayer player = GameRes.player[command.S];
			ObjEnemy enemy = GameRes.enemy[command.O];

			RESULT_OF_ATTACK state_of_attack = RESULT_OF_ATTACK.HESITATE;
			RESULT_OF_ATTACKED state_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;

			int needed_sp = player.GetRequiredSP(command.W);
			int magic_damage = player.GetAttackMagicPower(command.W);

			if (magic_damage == 0)
			{
				Debug.Assert(false);

				command.result_of_attack = RESULT_OF_ATTACK.HESITATE;
				command.result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				return;
			}

			if (player.sp < needed_sp)
			{
				command.result_of_attack = RESULT_OF_ATTACK.NOT_ENOUGH_SP;
				command.result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				return;
			}

			player.sp -= needed_sp;

			double critical = Yunjr.LibUtil.GetRandomPercentage();
			if (critical < 10.0f)
			{
				// Critical hit or miss
				double lucky_rate = Yunjr.LibUtil.GetRandomProbability() * player.status[(int)STATUS.LUC] / CONFIG.MAX_VALUE_OF_STATUS;
				Debug.Assert(lucky_rate >= 0.0 && lucky_rate <= 1.0);
				double baseline = 3.0 + lucky_rate * 4.0;
				if (critical >= baseline)
					state_of_attack = RESULT_OF_ATTACK.CRITICAL_HIT;
				else
					state_of_attack = RESULT_OF_ATTACK.CRITICAL_MISS;
			}
			else
			{
				// Attack magic success rate
				if (player.GetRateAttackMagic() >= Yunjr.LibUtil.GetRandomProbability())
					state_of_attack = RESULT_OF_ATTACK.HIT;
				else
					state_of_attack = RESULT_OF_ATTACK.MISS;
			}

			if (enemy.state.hp > 0)
			{
				if (state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT || state_of_attack == RESULT_OF_ATTACK.HIT)
				{
					// Resist rate (from En)
					if (Yunjr.LibUtil.GetRandomPercentage() < enemy.attrib.resistance_2)
						state_of_attacked = RESULT_OF_ATTACKED.RESISTED;

					// TODO2: 0~100인지를 밸런스를 맞춰서 설정
					if (Yunjr.LibUtil.GetRandomPercentage() < enemy.attrib.agility)
						state_of_attacked = RESULT_OF_ATTACKED.DODGED;
				}
			}

			// My attack works
			if ((state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT || state_of_attack == RESULT_OF_ATTACK.HIT) && state_of_attacked == RESULT_OF_ATTACKED.NO_DAMAGED)
			{
				if (state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT)
				{
					double critical_rate = 1.0 + 1.0 * player.status[(int)STATUS.LUC] / CONFIG.MAX_VALUE_OF_STATUS;
					magic_damage = (int)(magic_damage * critical_rate + 0.5);
				}

				// TODO2: 밸런스를 위해 값을 조정
				int ac = enemy.attrib.ac * enemy.attrib.level;

				magic_damage -= ac;

				if (magic_damage > 0)
				{
					if (enemy.state.dead > 0)
					{
						enemy.state.dead += magic_damage;
						state_of_attacked = RESULT_OF_ATTACKED.STILL_DEAD;
					}
					else if (enemy.state.unconscious > 0)
					{
						enemy.state.unconscious += magic_damage;
						enemy.state.dead = 1;
						state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_DEAD;
					}
					else
					{
						enemy.state.hp -= magic_damage;
						state_of_attacked = RESULT_OF_ATTACKED.DAMAGED;

						if (enemy.state.hp <= 0)
						{
							enemy.state.hp = 0;
							enemy.state.unconscious = 1;
							state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_UNCONSCIOUS;
						}
					}

					command.damage = magic_damage;
				}
				else
				{
					state_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				}
			}

			command.result_of_attack = state_of_attack;
			command.result_of_attacked = state_of_attacked;
		}

		private static string _GetMessageForSingleMagic(Command command)
		{
			string message = "";

			ObjPlayer player = GameRes.player[command.S];
			ObjEnemy enemy = (command.O >= 0) ? GameRes.enemy[command.O] : null;

			switch (command.result_of_attack)
			{
				case RESULT_OF_ATTACK.HESITATE:
					message = player.GetName(ObjNameBase.JOSA.SUB) + "잠시 주저했다";
					break;
				case RESULT_OF_ATTACK.MISS:
					message = "그러나, " + enemy.GetName(ObjNameBase.JOSA.OBJ) + " 빗나갔다";
					break;
				case RESULT_OF_ATTACK.CRITICAL_MISS:
					message = player.GetName(ObjNameBase.JOSA.SUB) + " 공격 타이밍을 놓쳤다";
					break;
				case RESULT_OF_ATTACK.NOT_ENOUGH_SP:
					message = "마법 지수가 부족했다";
					break;
				case RESULT_OF_ATTACK.HIT:
				case RESULT_OF_ATTACK.CRITICAL_HIT:
					switch (command.result_of_attacked)
					{
						case RESULT_OF_ATTACKED.RESISTED:
							message = "적은 " + player.GetName() + "의 마법을 저지했다";
							break;
						case RESULT_OF_ATTACKED.DODGED:
							message = "그러나, 적은 " + player.GetName() + "의 공격을 피했다";
							break;
						case RESULT_OF_ATTACKED.NO_DAMAGED:
							message = "그러나, " + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + player.GetGenderName().GetName() + "의 마법 공격을 막았다";
							break;
						case RESULT_OF_ATTACKED.DAMAGED:
							message = "적은 @F" + (command.damage).ToString() + "@@만큼의 피해를 입었다";
							break;
						case RESULT_OF_ATTACKED.POISONED:
							message = "적은 당신의 마법에 의해 중독되었다";
							break;
						case RESULT_OF_ATTACKED.TURN_TO_UNCONSCIOUS:
							message = "@C적은 " + player.GetName() + "의 마법에 의해 의식불명이 되었다@@";
							long exp_up = _PlusExperience(player, enemy);
							message += "\n@E" + player.GetName(ObjNameBase.JOSA.SUB) + " @B" + (exp_up).ToString() + "@@만큼 경험치를 얻었다!@@";
							break;
						case RESULT_OF_ATTACKED.STILL_UNCONSCIOUS:
							message = "[ERROR] RESULT_OF_ATTACKED.STILL_UNCONSCIOUS";
							break;
						case RESULT_OF_ATTACKED.TURN_TO_DEAD:
							message = "@C" + player.GetGenderName().GetName() + "의 마법은 적을 완전히 제거해 버렸다@@";
							break;
						case RESULT_OF_ATTACKED.STILL_DEAD:
							message = "[ERROR] RESULT_OF_ATTACKED.STILL_DEAD";
							break;
					}
					break;
			}

			return message;
		}

		private static void _ProcessInBattlePlayerMultiMagic(ref Command command)
		{
			// 원작은 foreach in enemys -> CastOne 이지만 이번은 다르게.
			ObjPlayer player = GameRes.player[command.S];

			int needed_sp = player.GetRequiredSP(command.W);
			int magic_power = player.GetAttackMagicPower(command.W);

			if (magic_power == 0)
			{
				Debug.Assert(false);

				command.result_of_attack = RESULT_OF_ATTACK.HESITATE;
				command.result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				return;
			}

			if (player.sp < needed_sp)
			{
				command.result_of_attack = RESULT_OF_ATTACK.NOT_ENOUGH_SP;
				command.result_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
				return;
			}

			player.sp -= needed_sp;

			command.result_of_attack = RESULT_OF_ATTACK.HIT;
			command.result_of_attacked = RESULT_OF_ATTACKED.DAMAGED;

			for (int ix_enemy = 0; ix_enemy < MAX_ENEMY; ix_enemy++)
			{
				ObjEnemy enemy = GameRes.enemy[ix_enemy];

				if (!enemy.IsValid())
					continue;

				int magic_damage = magic_power;

				RESULT_OF_ATTACK state_of_attack = RESULT_OF_ATTACK.HESITATE;
				RESULT_OF_ATTACKED state_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;

				double critical = Yunjr.LibUtil.GetRandomPercentage();
				if (critical < 10.0f)
				{
					// Critical hit or miss
					double lucky_rate = Yunjr.LibUtil.GetRandomProbability() * player.status[(int)STATUS.LUC] / CONFIG.MAX_VALUE_OF_STATUS;
					Debug.Assert(lucky_rate >= 0.0 && lucky_rate <= 1.0);
					double baseline = 3.0 + lucky_rate * 4.0;
					if (critical >= baseline)
						state_of_attack = RESULT_OF_ATTACK.CRITICAL_HIT;
					else
						state_of_attack = RESULT_OF_ATTACK.CRITICAL_MISS;
				}
				else
				{
					// Attack magic success rate
					if (player.GetRateAttackMagic() >= Yunjr.LibUtil.GetRandomProbability())
						state_of_attack = RESULT_OF_ATTACK.HIT;
					else
						state_of_attack = RESULT_OF_ATTACK.MISS;
				}

				if (enemy.state.hp > 0)
				{
					if (state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT || state_of_attack == RESULT_OF_ATTACK.HIT)
					{
						// Resist rate (from En)
						if (Yunjr.LibUtil.GetRandomPercentage() < enemy.attrib.resistance_2)
							state_of_attacked = RESULT_OF_ATTACKED.RESISTED;

						// TODO2: 0~100인지를 밸런스를 맞춰서 설정
						if (Yunjr.LibUtil.GetRandomPercentage() < enemy.attrib.agility)
							state_of_attacked = RESULT_OF_ATTACKED.DODGED;
					}
				}

				// My attack works
				if ((state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT || state_of_attack == RESULT_OF_ATTACK.HIT) && state_of_attacked == RESULT_OF_ATTACKED.NO_DAMAGED)
				{
					if (state_of_attack == RESULT_OF_ATTACK.CRITICAL_HIT)
					{
						double critical_rate = 1.0 + 1.0 * player.status[(int)STATUS.LUC] / CONFIG.MAX_VALUE_OF_STATUS;
						magic_damage = (int)(magic_damage * critical_rate + 0.5);
					}

					// TODO2: 밸런스를 위해 값을 조정
					int ac = enemy.attrib.ac * enemy.attrib.level;

					magic_damage -= ac;

					if (magic_damage > 0)
					{
						if (enemy.state.dead > 0)
						{
							enemy.state.dead += magic_damage;
							state_of_attacked = RESULT_OF_ATTACKED.STILL_DEAD;
						}
						else if (enemy.state.unconscious > 0)
						{
							enemy.state.unconscious += magic_damage;
							enemy.state.dead = 1;
							state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_DEAD;
						}
						else
						{
							enemy.state.hp -= magic_damage;
							state_of_attacked = RESULT_OF_ATTACKED.DAMAGED;

							if (enemy.state.hp <= 0)
							{
								enemy.state.hp = 0;
								enemy.state.unconscious = 1;
								state_of_attacked = RESULT_OF_ATTACKED.TURN_TO_UNCONSCIOUS;
							}
						}

						command.damage = magic_damage;
					}
					else
					{
						state_of_attacked = RESULT_OF_ATTACKED.NO_DAMAGED;
					}
				}

				{
					CommandSub command_sub = new CommandSub();
					command_sub.O = ix_enemy;
					command_sub.result_of_attack = state_of_attack;
					command_sub.result_of_attacked = state_of_attacked;
					command_sub.damage = magic_damage;

					command.multi.Add(command_sub);
				}
			}
		}

		private static string _GetMessageForMultiMagic(Command main_command)
		{
			ObjPlayer player = GameRes.player[main_command.S];

			switch (main_command.result_of_attack)
			{
				case RESULT_OF_ATTACK.HESITATE:
					return player.GetName(ObjNameBase.JOSA.SUB) + "잠시 주저했다";
				case RESULT_OF_ATTACK.NOT_ENOUGH_SP:
					return "마법 지수가 부족했다";
			}

			string all_messages = "";
			long total_exp_up = 0;

			// TODO: _GetMessageForMultiMagic() 행동에 따라 메시지 추가
			foreach (var command_sub in main_command.multi)
			{
				ObjEnemy enemy = (command_sub.O >= 0) ? GameRes.enemy[command_sub.O] : null;
				if (enemy != null)
				{
					string message = "";

					switch (command_sub.result_of_attack)
					{
						case RESULT_OF_ATTACK.HESITATE:
							message = player.GetName(ObjNameBase.JOSA.SUB) + "잠시 주저했다";
							break;
						case RESULT_OF_ATTACK.MISS:
							message = "그러나, " + enemy.GetName(ObjNameBase.JOSA.OBJ) + " 빗나갔다";
							break;
						case RESULT_OF_ATTACK.CRITICAL_MISS:
							message = player.GetName(ObjNameBase.JOSA.SUB) + " 공격 타이밍을 놓쳤다";
							break;
						case RESULT_OF_ATTACK.NOT_ENOUGH_SP:
							message = "마법 지수가 부족했다";
							break;
						case RESULT_OF_ATTACK.HIT:
						case RESULT_OF_ATTACK.CRITICAL_HIT:
							switch (command_sub.result_of_attacked)
							{
								case RESULT_OF_ATTACKED.RESISTED:
									message = "적은 " + player.GetName() + "의 마법을 저지했다";
									break;
								case RESULT_OF_ATTACKED.DODGED:
									message = "그러나, 적은 " + player.GetName() + "의 공격을 피했다";
									break;
								case RESULT_OF_ATTACKED.NO_DAMAGED:
									message = "그러나, " + enemy.GetName(ObjNameBase.JOSA.SUB) + " 마법 공격을 막았다";
									break;
								case RESULT_OF_ATTACKED.DAMAGED:
									message = "적은 @F" + (command_sub.damage).ToString() + "@@만큼의 피해를 입었다";
									break;
								case RESULT_OF_ATTACKED.POISONED:
									message = "적은 당신의 마법에 의해 중독되었다";
									break;
								case RESULT_OF_ATTACKED.TURN_TO_UNCONSCIOUS:
									message = "@C적은 마법에 의해 의식불명이 되었다@@";
									total_exp_up += _PlusExperience(player, enemy);
									break;
								case RESULT_OF_ATTACKED.STILL_UNCONSCIOUS:
									message = "";
									break;
								case RESULT_OF_ATTACKED.TURN_TO_DEAD:
									message = "@C마법으로 적을 완전히 제거해 버렸다@@";
									break;
								case RESULT_OF_ATTACKED.STILL_DEAD:
									message = "";
									break;
							}
							break;
					}

					if (all_messages == "")
						all_messages = message;
					else if (message != "")
						all_messages += "\n" + message;
				}
			}

			if (total_exp_up > 0)
				all_messages += "\n@E" + player.GetName(ObjNameBase.JOSA.SUB) + " @B" + (total_exp_up).ToString() + "@@만큼 경험치를 얻었다!@@";

			return all_messages;
		}

		private static bool __EnemyAttack(ObjEnemy enemy, out string message)
		{
			message = "";

			if (LibUtil.GetRandomIndex(20) >= enemy.attrib.accuracy_1)
			{
				message = enemy.GetName(ObjNameBase.JOSA.SUB) + " 빗맞추었다";
				return true;
			}

			int num_conscious = 0;
			{
				foreach (var pl in GameRes.player)
					num_conscious += (pl.IsAvailable()) ? 1 : 0;
			}

			int fall_of_dice = LibUtil.GetRandomIndex(num_conscious) + 1;
			num_conscious = 0;

			int selected_player = -1;
			{
				for (int ix_player = 0; ix_player < GameRes.player.Length; ix_player++)
				{
					num_conscious += (GameRes.player[ix_player].IsAvailable()) ? 1 : 0;
					if (num_conscious == fall_of_dice)
					{
						selected_player = ix_player;
						break;
					}
				}
			}

			if (selected_player < 0)
				selected_player = LibUtil.GetRandomIndex(GameRes.player.Length);

			if (!GameRes.player[selected_player].IsValid())
				selected_player = LibUtil.GetRandomIndex(GameRes.player.Length - 1);

			ObjPlayer player = GameRes.player[selected_player];

			if (!player.IsValid())
				return true;

			int damage = enemy.attrib.strength * enemy.attrib.level * (LibUtil.GetRandomIndex(10) + 1) / 5; // i

			if (player.IsAvailable())
			{
				int ac_by_shield = player.GetAcByShield();

				if (ac_by_shield > 0 && ac_by_shield > LibUtil.GetRandomIndex(550))
				{
					message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + player.GetName(ObjNameBase.JOSA.OBJ) + " 공격했다@@\n";
					message += "그러나, " + player.GetName(ObjNameBase.JOSA.SUB) + " 방패로 적의 공격을 막았다";
					return true;
				}

				damage -= (player.GetAcByArmor() * (LibUtil.GetRandomIndex(10) + 1) / 10);

				if (damage <= 0)
				{
					message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + player.GetName(ObjNameBase.JOSA.OBJ) + " 공격했다@@\n";
					message += "그러나, " + player.GetName(ObjNameBase.JOSA.SUB) + " 적의 공격을 방어했다";
					return true;
				}
			}

			player.Damaged(damage);

			message = "@D" + player.GetName(ObjNameBase.JOSA.SUB) + " " + enemy.GetName() + "에게 공격 받았다@@\n";
			message += "@5" + player.GetName(ObjNameBase.JOSA.SUB) + " @D" + (damage).ToString() + "@@만큼의 피해를 입었다@@";

			return true;
		}

		private static bool __EnemyCastOneSub(ObjEnemy enemy, ObjPlayer player, int damage, out string message)
		{
			message = "";

			if (!player.IsValid())
				return false;

			if (LibUtil.GetRandomIndex(20) >= enemy.attrib.accuracy_2)
			{
				message = "@7" + enemy.GetName() + "의 마법공격은 빗나갔다@@";
				return true;
			}

			damage -= LibUtil.GetRandomIndex(damage / 2);

			if (player.IsAvailable())
			{
				if (LibUtil.GetRandomIndex(50) < player.status[(int)STATUS.RES])
				{
					message = "@7그러나, " + player.GetName(ObjNameBase.JOSA.SUB) + " 적의 마법을 저지했다@@";
					return true;
				}

				damage -= (player.GetAcByArmor() * (LibUtil.GetRandomIndex(10) + 1) / 10);
			}

			if (damage <= 0)
			{
				message = "@7그러나, " + player.GetName(ObjNameBase.JOSA.SUB) + " 적의 마법을 막아냈다@@";
				return true;
			}

			player.Damaged(damage);

			message = String.Format("@5{0} @D{1}@@만큼의 피해를 입었다@@", player.GetName(ObjNameBase.JOSA.SUB), damage);

			return true;
		}

		private static bool __EnemyCastOne(ObjEnemy enemy, ObjPlayer player, out string message)
		{
			string magic_name = "";
			int power = 0;
			
			switch (enemy.attrib.mentality)
			{
				case 1:
				case 2:
				case 3:
					magic_name = "충격";
					power = 1;
					break;
				case 4:
				case 5:
				case 6:
				case 7:
				case 8:
					magic_name = "냉기";
					power = 2;
					break;
				case 9:
				case 10:
					magic_name = "고통";
					power = 4;
					break;
				case 11:
				case 12:
				case 13:
				case 14:
					magic_name = "혹한";
					power = 6;
					break;
				case 15:
				case 16:
				case 17:
				case 18:
					magic_name = "화염";
					power = 7;
					break;
				default:
					magic_name = "번개";
					power = 10;
					break;
			}

			int damage = power * enemy.attrib.level * 5;

			message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + player.GetName() + "에게 '" + magic_name + "'마법을 사용했다@@\n";

			string message2;

			if (__EnemyCastOneSub(enemy, player, damage, out message2))
			{
				message += message2;
				return true;
			}
			else
			{
				message = "";
				return false;
			}
		}

		private static bool __EnemyCastAll(ObjEnemy enemy, out string message)
		{
			string method = "";
			int power = 0;

			if (enemy.attrib.mentality <= 0)
			{
				message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " 일행 모두를 향해 크게 웃었다@@";
				return true;
			}
			else if (enemy.attrib.mentality <= 6)
			{
				method = "열파";
				power = 1;
			}
			else if (enemy.attrib.mentality <= 12)
			{
				method = "에너지";
				power = 2;
			}
			else if (enemy.attrib.mentality <= 16)
			{
				method = "초음파";
				power = 3;
			}
			else if (enemy.attrib.mentality <= 20)
			{
				method = "혹한기";
				power = 5;
			}
			else
			{
				method = "화염폭풍";
				power = 8;
			}

			int damage = power * enemy.attrib.level * 5;

			message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " 일행 모두에게 '" + method + "' 마법을 사용했다@@";

			foreach (var player in GameRes.player)
			{
				string result;
				if (__EnemyCastOneSub(enemy, player, damage, out result))
					message += "\n" + result;
			}

			return true;
		}

		private static bool __EnemyCure(ObjEnemy enemy, ObjEnemy target, int cure_point, out string message)
		{
			if (enemy.Equals(target))
				message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " 자신을 치료했다@@";
			else
				message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + target.GetName(ObjNameBase.JOSA.OBJ) + " 치료했다@@";

			if (target.state.dead > 0)
			{
				target.state.dead = 0;
				target.state.unconscious = Math.Min(target.state.unconscious, target.GetMaxHp());
			}
			else if (target.state.unconscious > 0)
			{
				target.state.unconscious -= cure_point;
				if (target.state.unconscious <= 0)
				{
					target.state.unconscious = 0;
					target.state.hp = Math.Min(target.state.hp, 1);
				}
			}
			else
			{
				target.state.hp += cure_point;
				target.state.hp = Math.Min(target.state.hp, target.GetMaxHp());
			}

			return true;
		}

		private static bool __EnemyCast(ObjEnemy enemy, out string message)
		{
			// TODO2: 각 cast_level별로 메시지를 검증해야 함. 특히 긴 메시지
			int cast_level = enemy.attrib.cast_level;

RETRY:
			switch (cast_level)
			{
				case 1:
					{
						int index = GameRes.GetIndexOfResevedPlayer();
						int max = (index >= 0 && GameRes.player[index].IsValid()) ? CONFIG.MAX_PLAYER : CONFIG.MAX_PLAYER - 1;
						int target = LibUtil.GetRandomIndex(max);
						if (!GameRes.player[target].IsValid())
							target = LibUtil.GetRandomIndex(max);

						__EnemyCastOne(enemy, GameRes.player[target], out message);
					}
					break;

				case 2:
					{
						int target = GameRes.GetRandomIndexOfValidPlayer();
						if (!GameRes.player[target].IsAvailable())
							target = GameRes.GetRandomIndexOfValidPlayer();

						__EnemyCastOne(enemy, GameRes.player[target], out message);
					}
					break;

				case 3:
					{
						int num_valid_player = GameRes.GetNumOfValidPlayer();

						if (LibUtil.GetRandomIndex(num_valid_player) < 2)
						{
							int target = GameRes.GetRandomIndexOfValidPlayer();
							if (!GameRes.player[target].IsAvailable())
								target = GameRes.GetRandomIndexOfValidPlayer();
							if (!GameRes.player[target].IsAvailable())
								target = GameRes.GetRandomIndexOfValidPlayer(false);

							__EnemyCastOne(enemy, GameRes.player[target], out message);
						}
						else
						{
							__EnemyCastAll(enemy, out message);
						}
					}
					break;

				case 4:
					if (enemy.state.hp / 3 < enemy.GetMaxHp() && LibUtil.GetRandomIndex(2) == 0)
					{
						__EnemyCure(enemy, enemy, enemy.attrib.level * enemy.attrib.mentality * 3, out message);
					}
					else
					{
						--cast_level;
						goto RETRY;
					}
					break;

				case 5:
					if (enemy.state.hp / 3 < enemy.GetMaxHp() && LibUtil.GetRandomIndex(3) == 0)
					{
						__EnemyCure(enemy, enemy, enemy.attrib.level * enemy.attrib.mentality * 3, out message);
					}
					else
					{
						int num_valid_player = GameRes.GetNumOfValidPlayer();

						if (LibUtil.GetRandomIndex(num_valid_player) < 2)
						{
							long sum_hp = 0;
							long sum_max_hp = 0;

							foreach (var en in GameRes.enemy)
							{
								if (en.IsValid())
								{
									sum_hp += (en.state.hp > 0) ? en.state.hp : 0;
									sum_max_hp += en.GetMaxHp();
								}
							}

							sum_max_hp /= 3;

							if ((GameRes.GetNumOfValidEnemy() > 2) && (sum_hp < sum_max_hp) && (LibUtil.GetRandomIndex(2) == 0))
							{
								message = "";

								string temp_messsage;
								for (int i = 0; i < MAX_ENEMY; i++)
								{
									__EnemyCure(enemy, GameRes.enemy[i], enemy.attrib.level * enemy.attrib.mentality * 2, out temp_messsage);
									message = temp_messsage + "\n";
								}
							}
							else
							{
								// 가장 HP가 낮은 아군
								int target = -1;
								int min_hp = 0x7FFFFFFF;

								for (int i = 0; i < GameRes.player.Length; i++)
								{
									if (GameRes.player[i].IsAvailable())
									{
										if (GameRes.player[i].hp < min_hp)
										{
											target = i;
											min_hp = GameRes.player[i].hp;
										}
									}
								}

								target = (target >= 0) ? target : 0;

								__EnemyCastOne(enemy, GameRes.player[target], out message);
							}
						}
						else
						{
							__EnemyCastAll(enemy, out message);
						}
					}
					break;

				case 6:
					if (enemy.state.hp * 4 / 10 < enemy.GetMaxHp() && LibUtil.GetRandomIndex(3) == 0)
					{
						__EnemyCure(enemy, enemy, enemy.attrib.level * enemy.attrib.mentality * 3, out message);
						break;
					}

					double sum_ac = 0;
					{
						int num_valid_player = 0;
						foreach (var player in GameRes.player)
						{
							if (player.IsValid())
							{
								++num_valid_player;
								sum_ac += player.ac;
							}
						}

						if (num_valid_player > 0)
							sum_ac /= num_valid_player;
					}

					if ((sum_ac > 4) && (LibUtil.GetRandomIndex(5) == 0))
					{
						message = "";

						foreach (var player in GameRes.player)
						{
							if (player.IsValid())
							{
								message += "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + player.GetName() + "의 갑옷파괴를 시도했다@@\n";
								if (player.status[(int)STATUS.LUC] > LibUtil.GetRandomIndex(21))
								{
									message += "@7그러나, " + enemy.GetName(ObjNameBase.JOSA.SUB) + " 성공하지 못했다@@\n";
								}
								else
								{
									message += "@5" + player.GetName() + "의 갑옷은 파괴되었다@@\n";
									if (player.ac > 0)
										--player.ac;
								}
							}
						}
					}
					else
					{
						long sum_hp = 0;
						long sum_max_hp = 0;

						foreach (var en in GameRes.enemy)
						{
							if (en.IsValid())
							{
								sum_hp += (en.state.hp > 0) ? en.state.hp : 0;
								sum_max_hp += en.GetMaxHp();
							}
						}

						sum_max_hp /= 3;

						if ((GameRes.GetNumOfValidEnemy() > 2) && (sum_hp < sum_max_hp) && (LibUtil.GetRandomIndex(3) == 0))
						{
							message = "";

							string temp_messsage;
							for (int i = 0; i < MAX_ENEMY; i++)
							{
								__EnemyCure(enemy, GameRes.enemy[i], enemy.attrib.level * enemy.attrib.mentality * 2, out temp_messsage);
								message = temp_messsage + "\n";
							}
						}
						else if (LibUtil.GetRandomIndex(2) == 0)
						{
							// 가장 HP가 낮은 아군
							int target = -1;
							int min_hp = 0x7FFFFFFF;

							for (int i = 0; i < GameRes.player.Length; i++)
							{
								if (GameRes.player[i].IsAvailable())
								{
									if (GameRes.player[i].hp < min_hp)
									{
										target = i;
										min_hp = GameRes.player[i].hp;
									}
								}
							}

							target = (target >= 0) ? target : 0;

							__EnemyCastOne(enemy, GameRes.player[target], out message);
						}
						else
						{
							__EnemyCastAll(enemy, out message);
						}
					}
					break;

				default:
					Debug.Assert(false);
					message = "";
					break;
			}

			return false;
		}

		private static bool __EnemySpecialAttack(ObjEnemy enemy, out string message)
		{
			switch (enemy.attrib.special)
			{
				case 1: // poison
					{
						ObjPlayer target = null;
						{
							int num_not_poisoned = 0;
							foreach (var player in GameRes.player)
								num_not_poisoned += (player.poison == 0) ? 1 : 0;

							int ix_target = LibUtil.GetRandomIndex(num_not_poisoned);

							foreach (var player in GameRes.player)
							{
								if (player.poison == 0)
								{
									if (--num_not_poisoned == ix_target)
									{
										target = player;
										break;
									}
								}
							}
						}

						if (target == null)
						{
							int ix_player = GameRes.GetRandomIndexOfAvailablePlayer(true);
							target = GameRes.player[ix_player];
						}

						message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + target.GetName() + "에게 독 공격을 시도했다@@\n";

						if (LibUtil.GetRandomIndex(40) > enemy.attrib.agility)
						{
							message += "@7독 공격은 실패했다@@";
						}
						else if (LibUtil.GetRandomIndex(20) < target.status[(int)STATUS.LUC])
						{
							message += "@7그러나, " + target.GetName(ObjNameBase.JOSA.SUB) + " 독 공격을 피했다@@";
						}
						else
						{
							message += "@4" + target.GetName(ObjNameBase.JOSA.SUB) + " 중독 되었다 !!@@";
							if (target.poison == 0)
								target.poison = 1;
						}
					}
					return true;

				case 2: // critical attack
					{
						ObjPlayer target = null;
						{
							int num_not_unconscious = 0;
							foreach (var player in GameRes.player)
								num_not_unconscious += (player.unconscious == 0) ? 1 : 0;

							int ix_target = LibUtil.GetRandomIndex(num_not_unconscious);

							foreach (var player in GameRes.player)
							{
								if (player.unconscious == 0)
								{
									if (--num_not_unconscious == ix_target)
									{
										target = player;
										break;
									}
								}
							}
						}

						if (target == null)
						{
							int ix_player = GameRes.GetRandomIndexOfAvailablePlayer(true);
							target = GameRes.player[ix_player];
						}

						message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + target.GetName() + "에게 치명적 공격을 시도했다@@\n";

						if (LibUtil.GetRandomIndex(50) > enemy.attrib.agility)
						{
							message += "@7치명적 공격은 실패했다@@";
						}
						else if (LibUtil.GetRandomIndex(20) < target.status[(int)STATUS.LUC])
						{
							message += "@7그러나, " + target.GetName(ObjNameBase.JOSA.SUB) + " 치명적 공격을 피했다@@";
						}
						else
						{
							message += "@4" + target.GetName(ObjNameBase.JOSA.SUB) + " 의식불명이 되었다 !!@@";

							if (target.unconscious == 0)
							{
								target.unconscious = 1;
								// 원작은 아래와 같다.
								// if player[j].hp > 0 then player[j].hp:= 0;
							}
						}
					}
					return true;

				case 3: // instant death
					{
						ObjPlayer target = null;
						{
							int num_not_dead = 0;
							foreach (var player in GameRes.player)
								num_not_dead += (player.dead == 0) ? 1 : 0;

							int ix_target = LibUtil.GetRandomIndex(num_not_dead);

							foreach (var player in GameRes.player)
							{
								if (player.dead == 0)
								{
									if (--num_not_dead == ix_target)
									{
										target = player;
										break;
									}
								}
							}
						}

						if (target == null)
						{
							int ix_player = GameRes.GetRandomIndexOfAvailablePlayer(true);
							target = GameRes.player[ix_player];
						}

						message = "@D" + enemy.GetName(ObjNameBase.JOSA.SUB) + " " + target.GetName() + "에게 죽음의 공격을 시도했다@@\n";

						if (LibUtil.GetRandomIndex(60) > enemy.attrib.agility)
						{
							message += "@7죽음의 공격은 실패했다@@";
						}
						else if (LibUtil.GetRandomIndex(20) < target.status[(int)STATUS.LUC])
						{
							message += "@7그러나, " + target.GetName(ObjNameBase.JOSA.SUB) + " 죽음의 공격을 피했다@@";
						}
						else
						{
							message += "@4" + target.GetName(ObjNameBase.JOSA.SUB) + " 죽었다 !!@@";

							if (target.dead == 0)
							{
								target.dead = 1;
								// 원작은 아래와 같다.
								// if player[j].hp > 0 then player[j].hp:= 0;
							}
						}
					}
					return true;

				default:
					message = "";
					break;
			}

			return true;
		}

		private static bool __EnemySpecialCastAttack(ObjEnemy enemy, out string message)
		{
			// TODO2: __EnemySpecialCastAttack() 메시지 리턴
			message = "[미완] __EnemySpecialCastAttack()";
			// 아직 구현할 필요는 없음
			Debug.Assert(false);

			if ((enemy.attrib.special_cast_level & 0x80) > 0)
			{
				// 도플갱어 생성. 현재는 해당 enemy가 없음
				Debug.Assert(false);
				/*
					if enemynumber < 8 then begin
					   enemynumber := 8;
					   for i := 1 to 8 do
					   if i <> person then begin
						  enemy[i].name := enemy[person].name;
						  enemy[i].E_Number := 0;
						  enemy[i].hp := 1;
						  enemy[i].aux_hp := 0;
					   end;
					   DisplayEnemies(TRUE);
					end;
					j := random(8) + 1;
					move(enemy[person],enemy[j],sizeof(enemydata2));
					for i := 1 to 8 do
					if i <> j then begin
					   enemy[i].E_Number := 0;
					   enemy[i].hp := 1;
					   enemy[i].poison := FALSE;
					   enemy[i].unconscious := FALSE;
					   enemy[i].dead := FALSE;
					   enemy[i].resistance[1] := 0;
					   enemy[i].resistance[2] := 0;
					   enemy[i].ac := 0;
					   enemy[i].level := 0;
					end;
					DisplayEnemies(FALSE);
				*/
			}

			/*
				j = 0;

				for i = 0 to 6 do
					if (specialcastlevel and (1 shl i)) > 0 then
						inc(j);

				if j == 0 then
					exit;

				method = 0;
				k = 0;
				j = random(j) + 1;
				repeat
					if (specialcastlevel and (1 shl method)) > 0 then
						inc(k);
					inc(method);
				until k = j;

				dec(method);

				  case method of
					 0 :
					 begin
						j := 0; k := enemynumber;
						for i := enemynumber downto 1 do
						if not enemy[i].dead then inc(j)
						else k := i;
						if (player[6].name <> '') and (j < 8) and (random(5) = 0) then begin
						   s[0] := chr(2);
						   s[1] := player[6].name[1];
						   s[2] := player[6].name[2];
						   if (s = '크') or (s = '대') then exit;
						   if enemynumber < 8 then begin
							  inc(enemynumber);
							  k := enemynumber;
						   end;
						   turn_mind(6,k);
						   player[6].name := '';
						   Display_Condition;
						   DisplayEnemies(TRUE);
						   Print(13,name+ReturnSJosa(name)+' 독심술을 사용하여 '+enemy[k].name+
									ReturnSJosa(enemy[k].name)+' 자기편으로 끌어들였다');
						end;
					 end;
					 1 :
					 begin
						j := 0; k := 0;
						for i := 1 to 6 do if player[i].name <> '' then begin
						   inc(j);
						   k := k + player[i].ac;
						end;
						k := k div j;
						if (k>4) and (random(5)=0) then begin
						   for i := 1 to 6 do if player[i].name <> '' then begin
							  Print(13,name+'는 '+player[i].name+'의 갑옷파괴를 시도했다');
							  if player[i].luck > random(21) then Print(7,'그러나, '+name+ReturnSJosa(name)+' 성공하지 못했다')
							  else begin
								 Print(5,player[i].name+'의 갑옷은 파괴되었다');
								 if player[i].ac > 0 then dec(player[i].ac);
							  end;
						   end;
						   display_condition;
						end;
					 end;
					 2 :
					 begin
						j := 0; k := enemynumber;
						for i := enemynumber downto 1 do
						if not enemy[i].dead then inc(j)
						else k := i;
						if (j < random(3)+2) then begin
						   if enemynumber < 8 then begin
							  inc(enemynumber);
							  k := enemynumber;
						   end;
						   case E_Number of
							  29 : i := 1 + random(5);
							  42 : i := 6 + random(5);
							  45 : i := 39 + random(2) * 2;
							  52 : i := 11 + random(5);
							  59 : i := 50;
						  73..74 : i := 71
							  else i := 1 + random(15);
						   end;
						   joinenemy(k,i);
						   DisplayEnemies(TRUE);
						   Print(13,name+ReturnSJosa(name)+' '+enemy[k].name+ReturnOJosa(enemy[k].name)+' 생성시켰다');
						end;
					 end;
					 3..5 :
					 begin
						j := 0;
						for i := 1 to 6 do if exist(i) then inc(j);
						if j < random(3) + 5 then exit;
						for i := 1 to 6 do
						case method of
						   3 :
						   begin
							  if random(40) > player[i].luck then begin
								 inc(player[i].poison);
								 if player[i].poison = 0 then player[i].poison := 255;
								 Print(13,player[i].name+ReturnSJosa(player[i].name)+' '+
										  name+'에 의해 독에 감염 되었다.');
							  end;
						   end;
						   4 :
						   begin
							  if (player[i].unconscious = 0) and (random(30) > player[i].luck) then begin
								 player[i].unconscious := 1;
								 Print(13,player[i].name+ReturnSJosa(player[i].name)+' '+
										  name+'에 의해 의식불명이 되었다.');
							  end;
						   end;
						   5 :
						   begin
							  if (player[i].dead = 0) and (random(22) > player[i].luck) then begin
								 player[i].dead := 1;
								 Print(13,player[i].name+ReturnSJosa(player[i].name)+' '+
										  name+'에 의해 급사 당했다.');
							  end;
						   end;
						end;
					 end;
					 6 :
					 begin
						for i := 1 to enemynumber do EnemyCure(i,level * mentality * 4);
						if E_Number in [5,10,47] then Exit_Code := 1;
					 end;
				  end;
			 */

			return false;
		}

		private static string _ProcessInBattleEnemyAttack(ObjEnemy enemy)
		{
			if (enemy.state.doppelganger > 0)
				return "";

			string message;

			if (enemy.attrib.special_cast_level > 0)
			{
				bool action_finished = __EnemySpecialCastAttack(enemy, out message);
				if (action_finished)
					return message;
			}

			int agility = Math.Min(enemy.attrib.agility, 20);

			if ((enemy.attrib.special > 0) && LibUtil.GetRandomIndex(50) < agility)
			{
				int count = 0;

				foreach (var en in GameRes.enemy)
					count += (en.IsAvailable()) ? 1 : 0;

				if (count > 3)
				{
					bool action_finished = __EnemySpecialAttack(enemy, out message);
					if (action_finished)
						return message;
				}
			}

			if (enemy.attrib.strength > 0 && LibUtil.GetRandomIndex(enemy.attrib.accuracy_1 * 1000) > LibUtil.GetRandomIndex(enemy.attrib.accuracy_2 * 1000))
				__EnemyAttack(enemy, out message);
			else
				__EnemyCast(enemy, out message);

			return message;
		}

		private static void _ForInBattle(int i)
		{
			_state = STATE.IN_BATTLE;
		}

		private static STATE _ProcessInBattle()
		{
			switch (_battle_state)
			{
				case BATTLE_STATE.FRIEND_TURN:

					string title = "";
					string message = "";

					do
					{
						bool pass = false;

						Command com = command[_battle_state_turn_index];

						if (com.S >= 0)
						{
							switch (com.V)
							{
								case VERB.ATTACK_SINGLE:
									_ProcessInBattlePlayerSingleAttack(ref com);
									message = _GetMessageForSingleAttack(com);
									break;
								case VERB.ATTACK_MULTI:
									_ProcessInBattlePlayerMultiAttack(ref com);
									message = _GetMessageForMultiAttack(com);
									break;
								case VERB.MAGIC_SINGLE:
									_ProcessInBattlePlayerSingleMagic(ref com);
									message = _GetMessageForSingleMagic(com);
									break;
								case VERB.MAGIC_MULTI:
									_ProcessInBattlePlayerMultiMagic(ref com);
									message = _GetMessageForMultiMagic(com);
									break;
								case VERB.NOT_ASSIGNED:
								case VERB.DO_NOTHING:
								case VERB.CURE_SINGLE:
								case VERB.CURE_MULTI:
								case VERB.ITEM_USING:
								case VERB.SUMMON:
								case VERB.RUN_AWAY:
								case VERB.AUTO_BATTLE:
									break;
							}

							UpdateAllEnemy();

							pass = true;
						}

						if (++_battle_state_turn_index >= command.Length)
						{
							_battle_state = BATTLE_STATE.FRIEND_TURN_END;
							_battle_state_turn_index = 0;
							pass = true;
						}

						if (!pass)
							continue;

						title = _GetCurrentCommand(com);

					} while (false);

					if (message.Length > 0)
					{
						Console.DisplaySmText(title + "\n" + message, true);
						_PressAnyKey(_ForInBattle);
					}

					break;
				case BATTLE_STATE.FRIEND_TURN_END:

					bool enemy_down = true;
					foreach (var enemy in GameRes.enemy)
					{
						if (enemy.IsValid() && enemy.state.dead == 0 && enemy.state.unconscious == 0 && enemy.state.hp > 0)
						{
							enemy_down = false;
							break;
						}
					}

					if (enemy_down)
					{
						// 승리 종료
						_state = STATE.RESULT_WIN;
					}
					else
					{
						_battle_state = BATTLE_STATE.ENEMY_TURN;
						_battle_state_turn_index = 0;
					}

					break;

				case BATTLE_STATE.ENEMY_TURN:

					foreach (var enemy in GameRes.enemy)
					{
						if (enemy.IsValid())
						{
							if (enemy.state.poison > 0)
							{
								if (enemy.state.unconscious > 0)
								{
									enemy.state.dead = 1;
								}
								else
								{
									enemy.state.hp -= 50;
									if (enemy.state.hp <= 0)
										enemy.state.unconscious = 1;
								}

							}

							while ((enemy.state.regenerative_hp > 0) && (enemy.state.hp < 30000))
							{
								--enemy.state.regenerative_hp;
								enemy.state.hp += 1000;
								enemy.state.unconscious = 0;
								enemy.state.dead = 0;
							}

							if (enemy.IsAvailable())
							{
								string log = _ProcessInBattleEnemyAttack(enemy);
								_battle_log.Add(log);
							}
						}
					}

					_battle_state = BATTLE_STATE.ENEMY_TURN_MESSAGE;

					break;

				case BATTLE_STATE.ENEMY_TURN_MESSAGE:

					string battle_log = "";

					// MAX_LINE 만큼 글자르기
					// 이전 코드: int ix_end = Math.Min(_ix_battle_log + 3, _battle_log.Count);

					// TODO2: (1/3) 같은 것을 출력하기
					int ix_end = _ix_battle_log;
					{
						const int MAX_LINE = 8;

						int num_line = 0;
						while (ix_end < _battle_log.Count)
						{
							string[] sub_strings = _battle_log[ix_end].Split('\n');
							num_line += sub_strings.Length;

							if (num_line > MAX_LINE)
								break;

							++num_line;
							++ix_end;
						}

						// 한 줄이 MAX_LINE을 넘어 갈 때 무한루프에 안 빠지도록
						if ((_ix_battle_log == ix_end) && (ix_end < _battle_log.Count))
							ix_end += _ix_battle_log;
					}

					for ( ; _ix_battle_log < ix_end; _ix_battle_log++)
						battle_log += _battle_log[_ix_battle_log] + "\n\n";

					if (battle_log != "")
					{
						Console.DisplaySmText(battle_log, false);

						_PressAnyKey(_ForInBattle);
					}
					else
					{
						GameObj.UpdatePlayerStatus();

						_battle_state = BATTLE_STATE.ENEMY_TURN_END;
						_battle_state_turn_index = 0;
					}

					break;

				case BATTLE_STATE.ENEMY_TURN_END:
					// Friend의 poison 적용
					foreach (var player in GameRes.player)
					{
						if (player.IsValid() && player.poison > 0)
							player.DamagedByPoison();
					}

					// Friend 전멸 체크
					bool more_than_one_is_alive = false;
					foreach (var player in GameRes.player)
					{
						if (player.IsValid())
						{
							player.StateUpdates();
							more_than_one_is_alive |= player.IsAvailable();
						}
					}

					if (more_than_one_is_alive)
						return STATE.ON_COMMAND_EACH;
					else
						return STATE.RESULT_LOSE;
			}

			return _state;
		}

		private static STATE _ProcessResultWin()
		{
			// 전투를 승리하여 종료하면 전체가 Exp를 얻는다.
			long exp_up = _PlusExperienceAll(ref GameRes.player, GameRes.enemy);
			long gold_up = _PlusGold(ref GameRes.party, GameRes.enemy);

			// 승리 보상 화면
			string message = "@C일행은 전투에서 승리했다.\n\n@@";
			message += "\n@E각자 @B" + (exp_up).ToString() + "@@만큼 경험치를 얻었다!@@";
			message += "\n@F그리고, 일행은 " + (gold_up).ToString()  + "개의 금을 얻었다.@@";
			Console.DisplaySmText(message, true);

			_PressAnyKey
			(
				delegate (int dummy)
				{
					GameRes.GameState = GAME_STATE.OUT_BATTLE;
					_state = STATE.RESULT_WIN;
				}
			);

			return _state;
		}

		private static STATE _ProcessResultLose()
		{
			GameRes.GameOverCondition = GAMEOVER_CONDITION.DEAD_ON_BATTLE;
			GameRes.GameState = GAME_STATE.OUT_BATTLE;
			_state = STATE.RESULT_WIN;

			return _state;
		}

		private static STATE _ProcessResultRunAway()
		{
			// TODO: RunAway 종료
			return _state;
		}

		private delegate STATE _FnProcessCallBack0();

		private static readonly _FnProcessCallBack0[] PROCESS_CALLBACK = new _FnProcessCallBack0[(int)STATE.MAX]
		{
			_ProcessOnCombatPower,
			_ProcessInCombatPower,
			_ProcessOnCommandEach,
			_ProcessInCommandEach,
			_ProcessInWaiting,
			_ProcessJustSelected,
			_ProcessPressAnyKey,
			_ProcessOnBattle,
			_ProcessInBattle,
			_ProcessResultWin,
			_ProcessResultLose,
			_ProcessResultRunAway
		};

		public static void Process()
		{
			STATE prev_status;

			do
			{
				prev_status = _state;

				if (_state >= 0 && (int)_state < PROCESS_CALLBACK.Length)
					_state = PROCESS_CALLBACK[(int)_state]();

			} while (prev_status != _state);
		}

		private static readonly Color32[] _ENEMY_COLOR =
		{
			new Color32(0x00, 0x00, 0x00, 0xFF),
			new Color32(0x4D, 0x5D, 0xAA, 0xFF),
			new Color32(0x4D, 0xAA, 0x4D, 0xFF),
			new Color32(0x45, 0xA6, 0xA6, 0xFF),
			new Color32(0xB6, 0x3C, 0x3C, 0xFF),
			new Color32(0x82, 0x30, 0x7D, 0xFF),
			new Color32(0xAE, 0x79, 0x28, 0xFF),
			new Color32(0xAA, 0xAA, 0xAA, 0xFF),
			new Color32(0x51, 0x51, 0x51, 0xFF),
			new Color32(0x24, 0x49, 0xFF, 0xFF),
			new Color32(0x3C, 0xFF, 0x75, 0xFF),
			new Color32(0x59, 0xE3, 0xE3, 0xFF),
			new Color32(0xFF, 0x59, 0x65, 0xFF),
			new Color32(0xCF, 0x71, 0xC7, 0xFF),
			new Color32(0xFF, 0xFF, 0x5D, 0xFF),
			new Color32(0xFF, 0xFF, 0xFF, 0xFF)
		};

		private static Color32 _GetEnemyColor(ObjEnemy enemy)
		{
			int ix_color = 0;

			if (enemy.IsValid())
			{
				ix_color = 10;

				if (enemy.state.hp <= 0)
					ix_color = 8;
				else if (enemy.state.hp <= 20)
					ix_color = 12;
				else if (enemy.state.hp <= 50)
					ix_color = 4;
				else if (enemy.state.hp <= 100)
					ix_color = 6;
				else if (enemy.state.hp <= 200)
					ix_color = 14;
				else if (enemy.state.hp <= 300)
					ix_color = 2;

				if (enemy.state.unconscious > 0)
					ix_color = 8;
				if (enemy.state.dead > 0)
					ix_color = 0;
				if (enemy.state.doppelganger > 0 && enemy.state.doppelganger < _ENEMY_COLOR.Length)
					ix_color = enemy.state.doppelganger;
			}

			Debug.Assert(ix_color >= 0 && ix_color < _ENEMY_COLOR.Length);
			return _ENEMY_COLOR[ix_color];
		}

		public static void UpdateEnemy(int index)
		{
			if (index >= 0 && index < GameRes.enemy.Length)
			{
				if (GameRes.enemy[index].Valid)
				{
					OldStyleBattle.enemy_status[index].SetDistance(15);
					OldStyleBattle.enemy_status[index].SetName(GameRes.enemy[index].attrib.name);
					OldStyleBattle.enemy_status[index].SetNameColor(_GetEnemyColor(GameRes.enemy[index]));
					OldStyleBattle.enemy_status[index].SetBgColor(new Color32(0x30, 0x30, 0x30, 0xFF));
				}
				else
				{
					OldStyleBattle.enemy_status[index].SetDistance(0);
					OldStyleBattle.enemy_status[index].SetName("");
					OldStyleBattle.enemy_status[index].SetNameColor(new Color32(0xFF, 0xFF, 0x30, 0xFF));
					OldStyleBattle.enemy_status[index].SetBgColor(new Color32(0x00, 0x00, 0x00, 0xFF));
				}
			}
		}

		public static void UpdateAllEnemy()
		{
			for (int i = 0; i < GameRes.enemy.Length; i++)
				UpdateEnemy(i);
		}
	}

	/*
	 *           S     V     I     O
	 * s.att.   [F]    1          [E]
	 * s.mag.   [F]    2   s[M]   [E]
	 * m.mag.   [F]    3   m[M]
	 * s.cur.   [F]    4   s[C]   [F]
	 * m.cur.   [F]    5   m[C]
	 * use      [F]    6    [I]   [F]
	 * summ     ???
	 * 
	 * sub-module
	 * - select one friend
	 * - select one enemy
	 * - select attack magic for one
	 * - select attack magic for all
	 * - select cure magic for one
	 * - select cure magic for all
	 * - use an item
	 * - summon a monster
	 *
	 * /

	/*
	 한 명의 적을 맨손으로 공격 
	 한 명의 적에게 마법 공격
	 모든 적에게 마법 공격
	 적에게 특수 마법 공격
	 일행을 치료
	 적에게 초능력 사용
	 소환 마법 사용
	 약초를 사용
	 무조건 공격 지시 (아까맨치로)



		- 물리 공격
		- 마법 공격
		- 특수 기술 공격
		- 초능력 공격
		- 치료 마법
		- 아이템 사용
		- 소환

	스무갸루가 오크를 맨손으로 공격한다
	스무갸루가 오크를 마법의 화살로 공격한다
	스무갸루가 적들을 향해 화염 폭풍으로 공격한다
	스무갸루가 오크에게 '능력저하'를 시도한다.
	스무갸루가 오크에게 '독심술'을 시도한다.

	스무갸루가 폴라리스에게 '회복'을 시도한다.
	스무갸루가 일행 전체에게 '의식 돌림'을 시도한다.

	스무갸루가 자신에게 회복약을 사용한다.
	스무갸루가 폴라리스에게 회복약을 사용한다.

	스무갸루가 대천사장의 소환을 시도한다.



	 Player가 | 적에게   | 맨손으로 
						   마법으로 
			  | 일행에게 | 

	 */



	/*
	 runBattleMode -+-> attackWithWeapon -------,
					|                           |
					+-> castSpellToAll          |
					|      |                    |
					+------+-> castSpellToOne --+
					|                           |
					+-> useESPForBattle --------+-> m_plusExperience
					|
					+-> castCureSpell -+-> m_healAll
					|              |        |
					|              +--------+-> m_healOne
					|              |
					|              +-> m_antidoteAll
					|              |        |
					|              +--------+-> m_antidoteOne
					|              |
					|              +-> m_recoverConsciousnessAll
					|              |        |
					|              +--------+-> m_recoverConsciousnessOne
					|              |
					|              +-> m_revitalizeAll
					|              |        |
					|              `--------+-> m_revitalizeOne
					|
					+-> castSpellWithSpecialAbility
					|
					`-> tryToRunAway
	*/
}
