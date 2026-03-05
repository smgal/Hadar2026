
using UnityEngine;
using UnityEngine.UI;
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	[Serializable]
	public struct Dir<T>
	{
		public T dx, dy;
	}

	[Serializable]
	public struct Pos<T>
	{
		public T x, y;

		public static Pos<T> Create(T x, T y)
		{
			Pos<T> pos;
			pos.x = x;
			pos.y = y;
			return pos;
		}
	}

	public enum PARTY_ITEM
	{
		POTION_HEAL, POTION_MANA, HERB_DETOX, HERB_JOLT, HERB_RESURRECTION,
		SCROLL_SUMMON, BIG_TORCH, CRYSTAL_BALL, WINGED_BOOTS, TELEPORT_BALL,
		MAX
	}

	public enum PARTY_CRYSTAL
	{
		PYRO_CRYSTAL, FROZEN_CRYSTAL, SUMMON_CRYSTAL, ENERGY_CRYSTAL, DARK_CRYSTAL,
		RESERVED_6, RESERVED_7, RESERVED_8, RESERVED_9, RESERVED_10,
		MAX
	}

	public enum PARTY_RELIC
	{
		SHARD_OF_GOLD, RESERVED_2, RESERVED_3, RESERVED_4, RESERVED_5,
		RESERVED_6, RESERVED_7, RESERVED_8, RESERVED_9, RESERVED_10,
		MAX
	}

	[Serializable]
	public class ObjPartyAux
	{
		#if UNITY_IOS
		public const int   MAX_STEP = 10; // FPS: 60
		#else
		public const int   MAX_STEP = 10;
		#endif
		public const float STEP_UNIT = 1.0f / MAX_STEP;

		public int        ix_face_offset = 0;
		public int        ix_face_add = 0;

		public Pos<int>   prev_pos;
		public Pos<int>   latest_event_pos;
		public bool       in_moving = false;
		public Pos<float> mov_vector = new Pos<float> { x = 0.0f, y = 0.0f };
		public int        mov_count = 0;
		public int        mov_count_end = MAX_STEP;

		public bool       in_remote_viewing = false;
		public bool       in_navigation_mode = false;
		public bool       in_second_sight = false;
	}

	[Serializable]
	public class ObjPartyCore
	{
		// From section 7.6.10.4 of the C# 5 specification:
		// All elements of the new array instance are initialized to their default values (§5.2).
		public int gameover_condition; // GAMEOVER_COND
		public int time_event_duration;
		public int time_event_id;

		public Pos<float> pos;
		public Dir<int> faced;
		public int food = 0;
		public long gold = 0;
		public int arrow = 0;
		public short[] item = new short[(int)PARTY_ITEM.MAX];
		public short[] crystal = new short[(int)PARTY_CRYSTAL.MAX];
		public short[] relic = new short[(int)PARTY_RELIC.MAX];
		public Equiped[] back_pack = new Equiped[(int)CONFIG.CAPACITY_OF_BACKPACK];

		public int[] _reserved_1 = new int[36];

		public int magic_torch;
		public int levitation;
		public int walk_on_water;
		public int walk_on_swamp;
		public int mind_control;
		public int penetration;

		public int[] _reserved_2 = new int[36];

		public bool can_use_ESP = false;
		public bool can_use_special_magic = false;
		public int  current_capacity_of_backpack = 20;

		public int[] _reserved_3 = new int[36];

		// settings
		public int year = 640;
		public int day = 1;
		public int hour = 12;
		public int min = 0;
		public int sec = 0;
		public int encounter = 2;
		public int max_enemy = 5;
		public int rest_time = 6;

		// internal flag
		public byte[] identified_map = new byte[128];

		// check
		public byte[] checksum = new byte[2] { 0, 0 };
	}

	[Serializable]
	public class ObjParty: ISerialize
	{
		// property
		public Pos<float> pos { get { return core.pos; } }
		public Dir<int> faced { get { return core.faced; } }
		public int food { get { return core.food; } }
		public long gold { get { return core.gold; } set { core.gold = value; } }
		public int arrow { get { return core.arrow; } }

		// delegator
		public delegate void FnCallBack0();

		// member
		public ObjPartyAux aux = new ObjPartyAux();
		public ObjPartyCore core = new ObjPartyCore();

		public ObjParty()
		{
			this.core.gameover_condition = (int)GAMEOVER_COND.COMPLETELY_DEFEATED;
			this.core.time_event_duration = 0;
			this.core.time_event_id = 0;

			this.core.faced.dx = 0;
			this.core.faced.dy = -1;

			this.aux.prev_pos.x = 25;
			this.aux.prev_pos.y = 25;

			this.aux.latest_event_pos = this.aux.prev_pos;

			this.core.pos.x = this.aux.prev_pos.x;
			this.core.pos.y = this.aux.prev_pos.y;
		}

		public void SetTimeEvent(int duration, int event_id)
		{
			this.core.time_event_duration = duration + 1;
			this.core.time_event_id = event_id;
		}

		public void PlusExp(long add)
		{
			foreach (ObjPlayer player in GameRes.player)
			{
				if (player != null && player.IsValid())
					player.exprience += add;
			}
		}

		public void PassTime(int _hour, int _min, int _sec)
		{
			this.core.sec += _sec;
			this.core.min += _min;
			this.core.hour += _hour;

			for (; this.core.sec >= 60; this.core.sec -= 60)
				this.core.min++;

			for (; this.core.min >= 60; this.core.min -= 60)
				this.core.hour++;

			for (; this.core.hour >= 24; this.core.hour -= 24)
				this.core.day++;

			for (; this.core.day >= 365; this.core.hour -= 365)
				this.core.year++;
		}

		public bool IsBusy()
		{
			return (this.aux.in_moving);
		}

		public void WaitForIdleState(FnCallBack0 fn_callback = null)
		{
			while (this.IsBusy())
			{
				this.Process();

				if (fn_callback != null)
					fn_callback();
			}
		}

		public void TimeGoes()
		{
			if (GameRes.party.core.mind_control > 0)
				GameRes.party.core.mind_control--;

			if (GameRes.party.core.levitation > 0)
				GameRes.party.core.levitation--;

			if (GameRes.party.core.penetration > 0)
				GameRes.party.core.penetration--;

			bool invalidate_status = false;

			foreach (ObjPlayer player in GameRes.player)
			{
				if (player.IsValid())
				{
					if (player.poison > 0)
						player.poison++;

					if (player.poison > 10)
					{
						player.poison = 1;
						player.DamagedByPoison();
						invalidate_status = true;
					}
				}
			}

			if (invalidate_status)
				GameObj.UpdatePlayerStatus();

			DetectGameOver();
		}

		public bool DetectGameOver()
		{
			// 전멸이라면 무조건 끝
			bool someone_alive = false;

			foreach (var player in GameRes.player)
			{
				if (player.IsValid() && player.IsAvailable())
				{
					someone_alive = true;
					break;
				}
			}

			if (someone_alive)
			{
				switch ((GAMEOVER_COND)GameRes.party.core.gameover_condition)
				{
					case GAMEOVER_COND.COMPLETELY_DEFEATED:
						return false;
					case GAMEOVER_COND.HERO_DEFEATED:
						if (GameRes.player[0].IsAvailable())
							return false;
						break;
					case GAMEOVER_COND.ALL_MEMBERS_DEFEATED:
						foreach (var player in GameRes.player)
							if (player != GameRes.player[0])
								if (player.IsValid() && player.IsAvailable())
									return false;
						break;
					case GAMEOVER_COND.ANY_MEMBERS_DEFEATED:
						foreach (var player in GameRes.player)
							if (player.IsValid() && !player.IsAvailable())
								goto GAMEOVER_CONDITION;
						return false;
				}
			}

GAMEOVER_CONDITION:
			GameRes.GameOverCondition = GAMEOVER_CONDITION.DEAD_ON_FIELD;

			return true;
		}

		public void SetDirection(int dx, int dy)
		{
			if (this.IsBusy())
				return;

			this.core.faced.dx = dx;
			this.core.faced.dy = dy;

			this.aux.ix_face_add = 0;

			if (dx < 0 && dy == 0)
				this.aux.ix_face_add += 3;
			else if (dx > 0 && dy == 0)
				this.aux.ix_face_add += 2;
			else if (dx == 0 && dy < 0)
				this.aux.ix_face_add += 1;
			else if (dx == 0 && dy > 0)
				this.aux.ix_face_add += 0;
		}

		public void Warp(int x, int y)
		{
			this.aux.in_moving = false;
			this.aux.mov_count = 0;

			this.core.pos.x = x;
			this.core.pos.y = y;
		}

		public void WarpRel(int dx, int dy)
		{
			this.aux.in_moving = false;
			this.aux.mov_count = 0;

			this.core.pos.x += dx;
			this.core.pos.y += dy;
		}
		/*
		public void Move(float dx, float dy, bool direction_applied = true)
		{
			dx = (dx < 0.0f) ? -1.0f : dx;
			dx = (dx > 0.0f) ?  1.0f : dx;
			dy = (dy < 0.0f) ? -1.0f : dy;
			dy = (dy > 0.0f) ?  1.0f : dy;

			this.Move((int)dx, (int)dy, direction_applied);
		}
		*/
		public void Move(int dx, int dy, bool direction_applied = true)
		{
			if (this.IsBusy())
				return;

			if (!_NormalizeDirection(ref dx, ref dy))
				return;

			if (direction_applied)
				this.SetDirection(dx, dy);

			this.aux.in_moving = true;
			this.aux.mov_vector.x = dx * ObjPartyAux.STEP_UNIT;
			this.aux.mov_vector.y = dy * ObjPartyAux.STEP_UNIT;
			this.aux.mov_count = 0;
			this.aux.mov_count_end = ObjPartyAux.MAX_STEP;
		}

		public void EnterWater(int tile, ref int dx, ref int dy)
		{
			// 얕은 물만 이 마법으로 건널 수 있음
			if (tile == 56 && GameRes.party.core.walk_on_water > 0)
				GameRes.party.core.walk_on_water--;
			else
				dx = dy = 0;
		}

		public void EnterSwamp(ref int dx, ref int dy)
		{
			if (GameRes.party.core.walk_on_swamp > 0)
			{
				GameRes.party.core.walk_on_swamp--;
				return;
			}

			string text = "@C일행은 독이 있는 늪에 들어갔다 !!!@@\n\n";

			foreach (ObjPlayer player in GameRes.player)
			{
				if (player.IsValid())
				{
					if (player.status[(int)STATUS.LUC] <= LibUtil.GetRandomIndex(20) + 1)
					{
						text += "@D" + player.GetName(ObjNameBase.JOSA.SUB) + " 중독 되었다.@@\n";

						if (player.poison == 0)
							player.poison = 1;
					}
				}
			}

			Console.DisplaySmText(text, true);
			GameObj.UpdatePlayerStatus();
		}

		public void EnterLava(ref int dx, ref int dy)
		{
			Console.DisplaySmText("@C일행은 용암지대로 들어섰다 !!!@@", false);

			foreach (ObjPlayer player in GameRes.player)
			{
				if (player.IsValid())
				{
					// TODO2: Lava damage factor 재계산
					int damage = (LibUtil.GetRandomIndex(40) + 40 - 2 * LibUtil.GetRandomIndex(player.status[(int)STATUS.LUC])) * 2;

					player.Damaged(damage);
				}
			}

			GameObj.UpdatePlayerStatus();
		}

		public void EnterCliff(ref int dx, ref int dy)
		{
			if (GameRes.party.core.levitation <= 0)
			{
				// TODO: 아무 것도 안 해도 되나?
				dx = dy = 0;
			}
		}

		public bool PutInBackpack(Equiped equipment)
		{
			for (int i = 0; i < GameRes.party.core.current_capacity_of_backpack; i++)
			{
				if (GameRes.party.core.back_pack[i] == null || !GameRes.party.core.back_pack[i].IsValid())
				{
					GameRes.party.core.back_pack[i] = equipment;

					Debug.Log(String.Format("Backpack used: {0}/{1}", this.GetNumItemsInBackpack(), this.core.current_capacity_of_backpack));

					return true;
				}
			}
			
			return false;
		}

		public bool PutInBackpack(ResId res_id)
		{
			return PutInBackpack(Equiped.Create(res_id));
		}

		public bool RemoveFromBackpack(Equiped equipment)
		{
			for (int i = 0; i < GameRes.party.core.current_capacity_of_backpack; i++)
			{
				if (GameRes.party.core.back_pack[i] != null && GameRes.party.core.back_pack[i].IsValid())
				{
					if (GameRes.party.core.back_pack[i] == equipment)
					{
						GameRes.party.core.back_pack[i] = null;
						return true;
					}
				}
			}

			return false;
		}

		public int GetNumItemsInBackpack()
		{
			int total = 0;

			for (int i = 0; i < GameRes.party.core.current_capacity_of_backpack; i++)
				total += (GameRes.party.core.back_pack[i] != null && GameRes.party.core.back_pack[i].IsValid()) ? 1 : 0;

			return total;
		}

		public void Process()
		{
			if (aux.in_moving)
			{
				this.core.pos.x += this.aux.mov_vector.x;
				this.core.pos.y += this.aux.mov_vector.y;

				if (++this.aux.mov_count >= this.aux.mov_count_end)
				{
					this.aux.in_moving = false;
					this.aux.mov_count = 0;

					this.aux.prev_pos.x = (int)(pos.x + 0.5f);
					this.aux.prev_pos.y = (int)(pos.y + 0.5f);

					this.core.pos.x = this.aux.prev_pos.x;
					this.core.pos.y = this.aux.prev_pos.y;

					GameRes.party.TimeGoes();

					if (GameRes.GameState == GAME_STATE.IN_MOVING)
						GameRes.GameState = GAME_STATE.ON_MOVING_STEP;

#if UNITY_EDITOR
					string debug_message = "" + pos.x + "|" + pos.y;
					debug_message += "   ";
					debug_message += Console.GetCurrentTime();
					GameObj.text_debug.text = debug_message;
#endif
				}
			}
		}

		private void _PrintNotEnoughSP()
		{
			Console.DisplaySmText(GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_SP), false);
		}

		private bool _ApplyRequiredSP(ObjPlayer player, int required_sp)
		{
			if (player.IsValid() && player.sp >= required_sp)
			{
				player.sp -= required_sp;
				GameObj.UpdatePlayerStatus();
				return true;
			}
			else
			{
				_PrintNotEnoughSP();
				return false;
			}
		}

		public void Cast_IgniteTorch(ObjPlayer player)
		{
			const int REQUIRED_SP = 1;

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			this.core.magic_torch = Math.Min(this.core.magic_torch + REQUIRED_SP, 255);

			Console.DisplaySmText("@F일행은 마법의 횃불을 밝혔습니다.@@", false);
		}

		public void Cast_EyesOfBeholder(ObjPlayer player)
		{
			const int REQUIRED_SP = 5;

			if (player != null)
				if (!_ApplyRequiredSP(player, REQUIRED_SP))
					return;

			Console.Clear();

			string result = _EyesOfBeholder();

			if (result.Length > 0)
				Console.DisplaySmText(result, true);
		}

		public void Cast_Levitate(ObjPlayer player)
		{
			const int REQUIRED_SP = 5;

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			this.core.levitation = 255;

			Console.DisplaySmText("@F일행은 공중부상중 입니다.@@", false);
		}

		public void Cast_WalkOnWater(ObjPlayer player)
		{
			const int REQUIRED_SP = 10;

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			this.core.walk_on_water = 255;

			Console.DisplaySmText("@F일행은 물위를 걸을수 있습니다.@@", false);
		}

		public void Cast_WalkOnSwamp(ObjPlayer player)
		{
			const int REQUIRED_SP = 20;

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			this.core.walk_on_swamp = 255;

			Console.DisplaySmText("@F일행은 늪위를 걸을수 있습니다.@@", false);
		}

		public void Cast_Etherealize(ObjPlayer player)
		{
			const int REQUIRED_SP = 25;

			if (GameRes.map_script.IsHandicapped(YunjrMap.HANDICAP.ETHEREALIZE))
			{
				Console.DisplaySmText("@D이 동굴의 악의 힘이 기화 이동을 방해 합니다.@@", false);
				return;
			}

			if (player.sp < REQUIRED_SP)
			{
				_PrintNotEnoughSP();
				return;
			}

			GameRes.selection_list.Init();
			GameRes.selection_list.AddGuide("<<<  방향을 선택하시오  >>>\n");

			GameRes.selection_list.AddItem("북쪽으로 기화 이동");
			GameRes.selection_list.AddItem("남쪽으로 기화 이동");
			GameRes.selection_list.AddItem("동쪽으로 기화 이동");
			GameRes.selection_list.AddItem("서쪽으로 기화 이동");

			GameRes.selection_list.Run
			(
				delegate ()
				{
					Console.DisplayRichText("");

					int x1 = 0;
					int y1 = 0;

					int index = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);
					switch (index)
					{
						case 1:
							y1 = -1;
							break;
						case 2:
							y1 = 1;
							break;
						case 3:
							x1 = 1;
							break;
						case 4:
							x1 = -1;
							break;
					}

					int map_x_to_move = (int)this.core.pos.x + 2 * x1;
					int map_y_to_move = (int)this.core.pos.y + 2 * y1;

					// 화면 밖으로 벗어 나려 하면 안됨
					if (map_x_to_move < CONFIG.VIEW_PORT_W_HALF || map_x_to_move > GameRes.map_data.size.w - CONFIG.VIEW_PORT_W_HALF - 1
					   || map_y_to_move < CONFIG.VIEW_PORT_H_HALF || map_y_to_move > GameRes.map_data.size.h - CONFIG.VIEW_PORT_H_HALF - 1)
					{
						return;
					}

					ACT_TYPE act_type = GameRes.map_data.GetActType(map_x_to_move, map_y_to_move);

					if (!(act_type == ACT_TYPE.MOVE || act_type == ACT_TYPE.EVENT))
					{
						Console.DisplaySmText("@7기화 이동이 통하지 않습니다.@@", false);
						return;
					}

					if (!_ApplyRequiredSP(player, REQUIRED_SP))
						return;

					if (act_type != ACT_TYPE.MOVE)
					{
						Console.DisplaySmText("@D알 수 없는 힘이 당신의 마법을 배척합니다.@@", false);
						return;
					}

					this.Warp(map_x_to_move, map_y_to_move);

					Console.DisplaySmText("@F기화 이동을 마쳤습니다.@@", false);
				}
			);
		}

		public void Cast_ChangeToGround(ObjPlayer player)
		{
			const int REQUIRED_SP = 30;

			if (GameRes.map_script.IsHandicapped(YunjrMap.HANDICAP.CHANGE_TO_GROUND))
			{
				Console.DisplaySmText("@D이 지역의 악의 힘이 지형 변화를 방해 합니다.@@", false);
				return;
			}

			if (player.sp < REQUIRED_SP)
			{
				_PrintNotEnoughSP();
				return;
			}

			int x1 = Math.Sign(this.faced.dx);
			int y1 = Math.Sign(this.faced.dy);

			int map_x_to_change = (int)this.core.pos.x + 1 * x1;
			int map_y_to_change = (int)this.core.pos.y + 1 * y1;

			// 화면 밖으로 벗어 나려 하면 안됨
			if (map_x_to_change < CONFIG.VIEW_PORT_W_HALF || map_x_to_change > GameRes.map_data.size.w - CONFIG.VIEW_PORT_W_HALF - 1
			   || map_y_to_change < CONFIG.VIEW_PORT_H_HALF || map_y_to_change > GameRes.map_data.size.h - CONFIG.VIEW_PORT_H_HALF - 1)
			{
				Console.DisplaySmText("@7지형 변화가 통하지 않습니다.@@", false);
				return;
			}

			ACT_TYPE act_type = GameRes.map_data.GetActType(map_x_to_change, map_y_to_change);

			switch (act_type)
			{
				case ACT_TYPE.EVENT:
					_ApplyRequiredSP(player, REQUIRED_SP);
					Console.DisplaySmText("@7알 수 없는 힘이 당신의 마법을 배척합니다.@@", false);
					return;
				case ACT_TYPE.TALK:
				case ACT_TYPE.ENTER:
				case ACT_TYPE.SIGN:
					Console.DisplaySmText("@7지형 변화가 통하지 않습니다.@@", false);
					return;
			}

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_tile = CONFIG.IX_MAP_TILE_DEFAULT;
			GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_obj0 = CONFIG.IX_MAP_OBJECT_DEFAULT;
			GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_obj1 = CONFIG.IX_MAP_OBJECT_DEFAULT;
			GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_event = CONFIG.IX_MAP_EVENT_DEFAULT;
			GameRes.map_data.data[map_x_to_change, map_y_to_change].act_type = ACT_TYPE.DEFAULT;

			Console.DisplaySmText("@F지형 변화에 성공했습니다.@@", false);
		}

		public void Cast_Telelport(ObjPlayer player)
		{
			_Telelport(player, true);
		}

		public void Cast_CreateFood(ObjPlayer player)
		{
			const int REQUIRED_SP = 30;

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			int num_food_added = 0;

			foreach (ObjPlayer p in GameRes.player)
				if (p.IsValid())
					num_food_added++;

			this.core.food = Math.Min(this.food + num_food_added, 255);

			Console.DisplaySmText(String.Format(
				"@F마법으로 식량을 만드는데 성공하였습니다.@@\n\n\n" +
				"@F         '{0}'개의 식량이 증가됨@@\n\n" +
				"@B    일행의 현재 식량은 '{1}'개 입니다.@@",
				num_food_added, this.food
			), false);
		}

		public void Cast_ChangeToGroundEx(ObjPlayer player)
		{
			const int REQUIRED_SP = 60;

			if (GameRes.map_script.IsHandicapped(YunjrMap.HANDICAP.CHANGE_TO_GROUND)
			    || GameRes.map_script.IsHandicapped(YunjrMap.HANDICAP.CHANGE_TO_GROUND_EX))
			{
				Console.DisplaySmText("@D이 지역의 악의 힘이 지형 변화를 방해 합니다.@@", false);
				return;
			}

			if (!_ApplyRequiredSP(player, REQUIRED_SP))
				return;

			int x1 = Math.Sign(this.faced.dx);
			int y1 = Math.Sign(this.faced.dy);

			int map_x_to_change = (int)this.core.pos.x;
			int map_y_to_change = (int)this.core.pos.y;

			bool is_succeeded = false;
			string failure_message = "";

			int POWER_EXTENT = (x1 != 0) ? CONFIG.VIEW_PORT_W_HALF : CONFIG.VIEW_PORT_H_HALF;

			for (int i = 0; i < POWER_EXTENT; i++)
			{
				map_x_to_change += x1;
				map_y_to_change += y1;

				if (map_x_to_change < CONFIG.VIEW_PORT_W_HALF || map_x_to_change > GameRes.map_data.size.w - CONFIG.VIEW_PORT_W_HALF - 1
				   || map_y_to_change < CONFIG.VIEW_PORT_H_HALF || map_y_to_change > GameRes.map_data.size.h - CONFIG.VIEW_PORT_H_HALF - 1)
				{
					failure_message = "@7지형 변화가 통하지 않습니다.@@";
					break;
				}

				ACT_TYPE act_type = GameRes.map_data.GetActType(map_x_to_change, map_y_to_change);

				switch (act_type)
				{
					case ACT_TYPE.EVENT:
						failure_message = "@7알 수 없는 힘이 당신의 마법을 배척합니다.@@";
						break;
					case ACT_TYPE.TALK:
					case ACT_TYPE.ENTER:
					case ACT_TYPE.SIGN:
						failure_message = "@7지형 변화가 통하지 않습니다.@@";
						break;
				}

				if (failure_message.Length > 0)
					break;

				GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_tile = CONFIG.IX_MAP_TILE_DEFAULT;
				GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_obj0 = CONFIG.IX_MAP_OBJECT_DEFAULT;
				GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_obj1 = CONFIG.IX_MAP_OBJECT_DEFAULT;
				GameRes.map_data.data[map_x_to_change, map_y_to_change].ix_event = CONFIG.IX_MAP_EVENT_DEFAULT;
				GameRes.map_data.data[map_x_to_change, map_y_to_change].act_type = ACT_TYPE.DEFAULT;

				is_succeeded = true;
			}

			if (is_succeeded)
			{
				if (failure_message.Length == 0)
					Console.DisplaySmText("@F지형 변화에 성공했습니다.@@", false);
				else
					Console.DisplaySmText("@F지형 변화에 일부 성공했습니다.@@", false);
			}
			else
			{
				Console.DisplaySmText(failure_message, false);
			}
		}

		public string Use_PotionHeal(ObjPlayer player, ObjPlayer target)
		{
			if (this.core.item[(int)PARTY_ITEM.POTION_HEAL] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.POTION_HEAL];

			int HEAL_POINT = 1000;
			SmResult result = __CureWounds(player, target, HEAL_POINT);

			if (!result.success)
				return result.message;

			if (target.hp >= target.GetMaxHP())
				return String.Format("@F{0} 모든 건강이 회복 되었습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
			else
				return String.Format("@F{0} 건강이 회복 되었습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
		}

		public string Use_PotionMana(ObjPlayer player, ObjPlayer target)
		{
			if (target.GetMaxSP() == 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " " + GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_A_MAGIC_USER);

			if (this.core.item[(int)PARTY_ITEM.POTION_MANA] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.POTION_MANA];

			int RECOVERY_POINT = 1000;

			if (!target.IsValid() || target.dead > 0 || target.unconscious > 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " 회복할 상태가 아닙니다.";

			if (target.sp >= target.GetMaxSP())
				return target.GetName(ObjNameBase.JOSA.SUB) + " 회복할 필요가 없습니다.";

			target.sp = Math.Min(target.sp + RECOVERY_POINT, target.GetMaxSP());

			if (target.sp >= target.GetMaxSP())
				return String.Format("@F{0} 모든 마법 지수가 회복 되었습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
			else
				return String.Format("@F{0} 마법 지수가 회복 되었습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
		}

		public string Use_HerbDetox(ObjPlayer player, ObjPlayer target)
		{
			if (target.poison == 0)
				return String.Format("@F{0} 중독되지 않았습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));

			if (this.core.item[(int)PARTY_ITEM.HERB_DETOX] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.HERB_DETOX];

			target.poison = 0;

			return String.Format("@F{0} 해독 되었습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
		}

		public string Use_HerbJolt(ObjPlayer player, ObjPlayer target)
		{
			if (target.unconscious == 0)
				return String.Format("@F{0} 의식이 있습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));

			if (this.core.item[(int)PARTY_ITEM.HERB_JOLT] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.HERB_JOLT];

			target.unconscious = 0;

			if (target.dead == 0)
				return String.Format("@F{0} 의식을 차렸습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
			else
				return String.Format("@F{0} 이미 죽은 상태입니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
		}

		public string Use_HerbResurrection(ObjPlayer player, ObjPlayer target)
		{
			if (target.dead == 0)
				return String.Format("@F{0} 죽지 않았습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));

			if (this.core.item[(int)PARTY_ITEM.HERB_RESURRECTION] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.HERB_RESURRECTION];

			if (target.dead < 10000)
			{
				target.dead = 0;
				target.unconscious = Math.Min(target.unconscious, target.GetMaxHP());

				return String.Format("@F{0} 다시 살아났습니다.@@", target.GetName(ObjNameBase.JOSA.SUB));
			}
			else
			{
				return String.Format("@F{0}의 죽음은 이 약초로는 살리지 못합니다..@@", target.GetName());
			}
		}

		public string Use_ScrollSummon(ObjPlayer player)
		{
			if (this.core.item[(int)PARTY_ITEM.SCROLL_SUMMON] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.SCROLL_SUMMON];

			// 11 is a magic key for summoning from a scroll
			return GameRes.party.SummonSomething(player, 11);
		}

		public string Use_BigTorch(ObjPlayer player)
		{
			if (this.core.item[(int)PARTY_ITEM.BIG_TORCH] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.BIG_TORCH];

			this.core.magic_torch = Math.Min(this.core.magic_torch + 10, 255);

			return "@F일행은 대형 횃불을 켰습니다.@@";
		}

		public string Use_CrystalBall(ObjPlayer player)
		{
			if (this.core.item[(int)PARTY_ITEM.CRYSTAL_BALL] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.CRYSTAL_BALL];

			Console.Clear();

			return _EyesOfBeholder();
		}

		public string Use_WingedBoots(ObjPlayer player)
		{
			if (this.core.item[(int)PARTY_ITEM.WINGED_BOOTS] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.WINGED_BOOTS];

			this.core.levitation = 255;
			this.core.walk_on_water = 255;
			this.core.walk_on_swamp = 255;

			return "@F일행은 모두 비행 부츠를 신었습니다.@@";
		}

		public string Use_TeleportBall(ObjPlayer player)
		{
			if (this.core.item[(int)PARTY_ITEM.TELEPORT_BALL] <= 0)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_ITEM);

			--this.core.item[(int)PARTY_ITEM.TELEPORT_BALL];

			_Telelport(player, false);

			// _Telelport()가 string을 돌려 주기 어려운 구조라서, 이번은 특이한 경우이다.
			return "";
		}

		private string _EyesOfBeholder()
		{
			if (GameRes.map_script.IsHandicapped(YunjrMap.HANDICAP.WIZARD_EYE))
				return "@D당신의 머리속에는 아무런 형상도 떠오르지 않았다.@@";

			// 최대 101 x 81
			{
				const int WIZARD_EYE_W = 40;
				const int WIZARD_EYE_H = 40;

				int PARTY_X = (int)GameRes.party.core.pos.x;
				int PARTY_Y = (int)GameRes.party.core.pos.y;
				int MAP_W = GameRes.map_data.size.w;
				int MAP_H = GameRes.map_data.size.h;

				int x1 = 0;
				int x2 = MAP_W;
				int y1 = 0;
				int y2 = MAP_H;

				if (MAP_W > WIZARD_EYE_W)
				{
					x1 = (int)PARTY_X - WIZARD_EYE_W / 2;
					x2 = x1 + WIZARD_EYE_W;

					if (x1 < 0)
					{
						x1 = 0;
						x2 = x1 + WIZARD_EYE_W;
					}

					if (x2 > MAP_W)
					{
						x2 = MAP_W;
						x1 = x2 - WIZARD_EYE_W;
					}
				}

				if (MAP_H > WIZARD_EYE_H)
				{
					y1 = (int)PARTY_Y - WIZARD_EYE_H / 2;
					y2 = y1 + WIZARD_EYE_H;

					if (y1 < 0)
					{
						y1 = 0;
						y2 = y1 + WIZARD_EYE_H;
					}

					if (y2 > MAP_H)
					{
						y2 = MAP_H;
						y1 = y2 - WIZARD_EYE_H;
					}
				}

				Texture2D mini_map = new Texture2D(x2 - x1, y2 - y1, TextureFormat.ARGB32, false, false);

				mini_map.filterMode = FilterMode.Point;

				Color32[] buffer = mini_map.GetPixels32();

				if (!(x1 == 0 && x2 == GameRes.map_data.size.w && y1 == 0 && y2 == GameRes.map_data.size.h))
				{
					Color32 CLEAR_COLOR = new Color32(0, 0, 0, 0);
					for (int i = 0; i < buffer.Length; i++)
						buffer[i] = CLEAR_COLOR;
				}

				Color32[,] COLORS = new Color32[(int)ACT_TYPE.MAX + 1, 2]
				{
					{ new Color32(0xBF, 0xBF, 0xBF, 0xFF), new Color32(0xBF, 0xBF, 0xBF, 0xCF) }, // BLOCK
					{ new Color32(0x00, 0x00, 0x00, 0xFF), new Color32(0x00, 0x00, 0x00, 0xCF) }, // MOVE
					{ new Color32(0x00, 0x00, 0xFF, 0xFF), new Color32(0x00, 0x00, 0xFF, 0xCF) }, // WATER
					{ new Color32(0x00, 0x80, 0x80, 0xFF), new Color32(0x00, 0x80, 0x80, 0xCF) }, // SWAMP
					{ new Color32(0xFF, 0x00, 0x00, 0xFF), new Color32(0xFF, 0x00, 0x00, 0xCF) }, // LAVA
					{ new Color32(0x00, 0x00, 0x00, 0xFF), new Color32(0x00, 0x00, 0x00, 0xCF) }, // CLIFF
					{ new Color32(0x00, 0xFF, 0x00, 0xFF), new Color32(0x00, 0xFF, 0x00, 0xCF) }, // ENTER
					{ new Color32(0x00, 0xFF, 0xFF, 0xFF), new Color32(0x00, 0xFF, 0xFF, 0xCF) }, // SIGN
					{ new Color32(0xFF, 0x00, 0xFF, 0xFF), new Color32(0xFF, 0x00, 0xFF, 0xCF) }, // TALK
					{ new Color32(0x00, 0x00, 0x00, 0xFF), new Color32(0x00, 0x00, 0x00, 0xCF) }, // EVENT
					{ new Color32(0x00, 0x00, 0x00, 0xFF), new Color32(0x00, 0x00, 0x00, 0xCF) }, // POST_EVENT
					{ new Color32(0x00, 0x00, 0x00, 0xFF), new Color32(0x00, 0x00, 0x00, 0xCF) }, // DEFAULT
					{ new Color32(0xFF, 0xC0, 0x40, 0xFF), new Color32(0xFF, 0xC0, 0x40, 0xCF) }  // PC location
				};

				for (int h = 0; h < (y2 - y1); h++)
				{
					int pixel_y = mini_map.height - h - 1;
					int ix = pixel_y * mini_map.width;
					for (int w = 0; w < (x2 - x1); w++, ix++)
						buffer[ix] = COLORS[(int)GameRes.map_data.GetActType(x1 + w, y1 + h), (h % 2 + w) % 2];
				}

				// PC의 위치 표시
				{
					int w = PARTY_X - x1;
					int h = (mini_map.height - 1 - PARTY_Y) + y1;
					buffer[h * mini_map.width + w] = COLORS[(int)ACT_TYPE.MAX, 0];

					// PC의 주위 4칸에 색 블렌딩
					for (int y = -1; y <= 1; y++)
						for (int x = -1; x <= 1; x++)
							if (Math.Abs(x) + Math.Abs(y) == 1)
								buffer[(h + y) * mini_map.width + (w + x)] = Color32.Lerp(COLORS[(int)ACT_TYPE.MAX, 0], buffer[(h + y) * mini_map.width + (w + x)], 0.7f);
				}

				mini_map.SetPixels32(buffer);
				mini_map.Apply();

				Sprite sprite = Sprite.Create(mini_map, new Rect(0, 0, mini_map.width, mini_map.height), new Vector2(0, 0));

				GameObj.mini_map.sprite = sprite;
				GameObj.mini_map.gameObject.SetActive(true);
			}

			return "";
		}

		private void _Telelport(ObjPlayer player, bool sp_consumed)
		{
			if (GameRes.map_script.IsHandicapped(YunjrMap.HANDICAP.TELEPORT))
			{
				Console.DisplaySmText("@D알 수 없는 힘이 공간 이동을 방해 합니다.@@", false);
				return;
			}

			string inquiry_format = " @F## @@@A{0,1}000@@@F 공간 이동력@@\n";

			int power = 5;

			GameRes.selection_spin.Init();
			GameRes.selection_spin.AddTitle("@B당신의 공간 이동력을 지정@@");
			GameRes.selection_spin.AddContents(String.Format(inquiry_format, power));
			GameRes.selection_spin.Run
			(
				delegate () // just selected
				{
					int REQUIRED_SP = 10 * power;

					if (player.sp < REQUIRED_SP)
					{
						_PrintNotEnoughSP();
						return;
					}

					int x1 = Math.Sign(this.faced.dx);
					int y1 = Math.Sign(this.faced.dy);

					int map_x_to_teleport = (int)this.core.pos.x + power * x1;
					int map_y_to_teleport = (int)this.core.pos.y + power * y1;

					if (map_x_to_teleport < CONFIG.VIEW_PORT_W_HALF || map_x_to_teleport > GameRes.map_data.size.w - CONFIG.VIEW_PORT_W_HALF - 1
					   || map_y_to_teleport < CONFIG.VIEW_PORT_H_HALF || map_y_to_teleport > GameRes.map_data.size.h - CONFIG.VIEW_PORT_H_HALF - 1)
					{
						Console.DisplaySmText("@7공간 이동이 통하지 않습니다.@@", false);
						return;
					}

					ACT_TYPE act_type = GameRes.map_data.GetActType(map_x_to_teleport, map_y_to_teleport);

					if (!(act_type == ACT_TYPE.MOVE || act_type == ACT_TYPE.EVENT))
					{
						Console.DisplaySmText("@7공간 이동 장소로 부적합 합니다.@@", false);
						return;
					}

					if (!_ApplyRequiredSP(player, REQUIRED_SP))
						return;

					if (act_type != ACT_TYPE.MOVE)
					{
						Console.DisplaySmText("@D알 수 없는 힘이 당신을 배척합니다.@@", false);
						return;
					}

					GameRes.party.Warp(map_x_to_teleport, map_y_to_teleport);

					Console.DisplaySmText("@F공간 이동 마법이 성공했습니다.@@", false);
				},
				delegate () // up
				{
					if (power < 9)
					{
						power++;
						GameRes.selection_spin.AddContents(String.Format(inquiry_format, power));
					}
				},
				delegate () // down
				{
					if (power > 1)
					{
						power--;
						GameRes.selection_spin.AddContents(String.Format(inquiry_format, power));
					}
				}
			);
		}

		private SmResult __CureWounds(ObjPlayer player, ObjPlayer target, int heal)
		{
			if (!target.IsValid() || target.dead > 0 || target.unconscious > 0 || target.poison > 0)
				return new SmResult() { success = false, message = target.GetName(ObjNameBase.JOSA.SUB) + " 치료될 상태가 아닙니다." };

			if (target.hp >= target.GetMaxHP())
				return new SmResult() { success = false, message = target.GetName(ObjNameBase.JOSA.SUB) + " 치료할 필요가 없습니다." };

			target.hp = Math.Min(target.hp + heal, target.GetMaxHP());

			return new SmResult() { success = true, message = "@F" + target.GetName(ObjNameBase.JOSA.SUB) + " 치료되어 졌습니다.@@" };
		}

		private string _CureWounds(ObjPlayer player, ObjPlayer target)
		{
			int REQUIRED_SP = 2 * player.status[(int)STATUS.LEV];
			int HEAL_POINT = REQUIRED_SP * 10;

			if (player.sp < REQUIRED_SP)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_SP);

			SmResult result = __CureWounds(player, target, HEAL_POINT);

			if (result.success)
				player.sp -= REQUIRED_SP;

			return result.message;
		}

		private string _CurePoison(ObjPlayer player, ObjPlayer target)
		{
			if (!target.IsValid() || target.dead > 0 || target.unconscious > 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " 독이 치료될 상태가 아닙니다.";

			if (target.poison == 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " 독에 걸리지 않았습니다.";

			int REQUIRED_SP = 15;

			if (player.sp < REQUIRED_SP)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_SP);

			player.sp -= REQUIRED_SP;
			target.poison = 0;

			return "@F" + target.GetName() + "의 독은 제거 되었습니다.@@";
		}

		private string _AwakeFromUnconsciousness(ObjPlayer player, ObjPlayer target)
		{
			if (!target.IsValid() || target.dead > 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " 의식이 돌아올 상태가 아닙니다.";

			if (target.unconscious == 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " 의식불명이 아닙니다.";

			int REQUIRED_SP = 10 * target.unconscious;

			if (player.sp < REQUIRED_SP)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_SP);

			player.sp -= REQUIRED_SP;

			target.unconscious = 0;

			if (target.hp <= 0)
				target.hp = 1;

			return "@F" + target.GetName() + "의식을 되찾았습니다.@@";
		}

		private string _RaiseDead(ObjPlayer player, ObjPlayer target)
		{
			if (!target.IsValid())
				return "";

			if (target.dead == 0)
				return target.GetName(ObjNameBase.JOSA.SUB) + " 아직 살아 있습니다.";

			int REQUIRED_SP = 30 * target.dead;

			if (player.sp < REQUIRED_SP)
				return GameStrRes.GetMessageString(GameStrRes.MESSAGE_ID.NOT_ENOUGH_SP);

			player.sp -= REQUIRED_SP;

			target.dead = 0;

			if (target.unconscious > target.GetMaxHP())
				target.unconscious = target.GetMaxHP();

			if (target.unconscious == 0)
				target.unconscious = 1;

			return "@F" + target.GetName(ObjNameBase.JOSA.SUB) + " 다시 생명을 얻었습니다.@@";
		}

		public string CureWounds(ObjPlayer player, ObjPlayer target)
		{
			return this._CureWounds(player, target);
		}

		public string CurePoison(ObjPlayer player, ObjPlayer target)
		{
			return this._CurePoison(player, target);
		}

		public string AwakeFromUnconsciousness(ObjPlayer player, ObjPlayer target)
		{
			return this._AwakeFromUnconsciousness(player, target);
		}

		public string RaiseDead(ObjPlayer player, ObjPlayer target)
		{
			return this._RaiseDead(player, target);
		}

		public void UseCureSpell(ObjPlayer player, bool low_level)
		{
			if (player.GetMaxSP() == 0)
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 치료 마법을 사용하는 계열이 아닙니다.", true);
				return;
			}

			int level_to_use = player.skill[(int)SKILL_TYPE.CURE] / 10;

			if ((low_level && level_to_use <= 0) || (!low_level && level_to_use < 6))
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 사용 가능한 치료 마법이 없습니다.", true);
				return;
			}

			if (low_level)
			{
				GameRes.selection_list.Init();
				GameRes.selection_list.AddTitle("");
				GameRes.selection_list.AddGuide("@A누구에게@@\n");

				for (int i = 0; i < GameRes.player.Length; i++)
					if (GameRes.player[i].Name != "")
						GameRes.selection_list.AddItem(GameRes.player[i].Name, i + 1);

				GameRes.selection_list.Run
				(
					delegate()
					{
						int index = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);
						if (index > 0)
						{
							ObjPlayer target = GameRes.player[index - 1];
							Debug.Assert(target.IsValid());

							GameRes.selection_list.Init();
							GameRes.selection_list.AddTitle("");
							GameRes.selection_list.AddGuide("");

							GameRes.selection_list.AddItem("개인 치료");
							GameRes.selection_list.AddItem("개인 독 제거");
							GameRes.selection_list.AddItem("개인 의식 돌림");
							GameRes.selection_list.AddItem("개인 부활");
							GameRes.selection_list.AddItem("개인 복합 치료");

							GameRes.selection_list.Run
							(
								delegate ()
								{
									string message = "";

									int ix_spell = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);
									switch (ix_spell)
									{
										case 1:
											message = _CureWounds(player, target);
											break;
										case 2:
											message = _CurePoison(player, target);
											break;
										case 3:
											message = _AwakeFromUnconsciousness(player, target);
											break;
										case 4:
											message = _RaiseDead(player, target);
											break;
										case 5:
											message = _RaiseDead(player, target);
											message += "\n";
											message += _AwakeFromUnconsciousness(player, target);
											message += "\n";
											message += _CurePoison(player, target);
											message += "\n";
											message += _CureWounds(player, target);
 											break;
									}

									if (message.Length > 0)
										Console.DisplaySmText(message, true);

									GameObj.UpdatePlayerStatus();
								}
							);
						}
					}
				);
			}
			else
			{
				// CureSpell (high)
				GameRes.selection_list.Init();
				GameRes.selection_list.AddTitle("");
				GameRes.selection_list.AddGuide("");

				GameRes.selection_list.AddItem("전체 치료");
				GameRes.selection_list.AddItem("전체 독 제거");
				GameRes.selection_list.AddItem("전체 의식 돌림");
				GameRes.selection_list.AddItem("전체 부활");
				GameRes.selection_list.AddItem("전체 복합 치료");

				GameRes.selection_list.Run
				(
					delegate ()
					{
						string message = "";
						string adder = "";

						int ix_spell = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);

						foreach (var target in GameRes.player)
						{
							if (target.IsValid())
							{
								adder = "";

								switch (ix_spell)
								{
									case 1:
										adder = _CureWounds(player, target);
										break;
									case 2:
										adder = _CurePoison(player, target);
										break;
									case 3:
										adder = _AwakeFromUnconsciousness(player, target);
										break;
									case 4:
										adder = _RaiseDead(player, target);
										break;
									case 5:
										if (target.IsValid() && target.dead == 0 && target.unconscious == 0 && target.poison == 0 && target.hp >= target.GetMaxHP())
										{
											adder = "@F" + target.GetName(ObjNameBase.JOSA.SUB) + " 치료할 필요가 없습니다.@@";
										}
										else
										{
											_RaiseDead(player, target);
											_AwakeFromUnconsciousness(player, target);
											_CurePoison(player, target);
											_CureWounds(player, target);
											adder = "@F" + target.GetName(ObjNameBase.JOSA.SUB) + " 복합 치료를 받았습니다.@@";
										}
										break;
								}

								if (adder.Length > 0)
									message += adder + "\n";
							}
						}

						if (message.Length > 0)
							Console.DisplaySmText(message, true);

						GameObj.UpdatePlayerStatus();
					}
				);
			}
		}

		public void UsePhenominaSpell(ObjPlayer player, bool low_level)
		{
			if (player.GetMaxSP() == 0)
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 변화 마법을 사용하는 계열이 아닙니다.", true);
				return;
			}

			int level_to_use = player.skill[(int)SKILL_TYPE.ENVIRONMENT] / 10;
			
			if ((low_level && level_to_use <= 0 && ((player.specially_allowed_magic & 0x001F) == 0)) ||
			    (!low_level && level_to_use < 6 && ((player.specially_allowed_magic & 0x03E0) == 0)))
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 사용 가능한 변화 마법이 없습니다.", true);
				return;
			}

			GameRes.selection_list.Init();
			GameRes.selection_list.AddGuide("선택\n");
			if (low_level)
			{
				GameRes.selection_list.AddItem("마법의 횃불", 1, (level_to_use >= 1) || ((player.specially_allowed_magic & 0x0001) > 0));
				GameRes.selection_list.AddItem("주시자의 눈", 2, (level_to_use >= 2) || ((player.specially_allowed_magic & 0x0002) > 0));
				GameRes.selection_list.AddItem("공중 부상",   3, (level_to_use >= 3) || ((player.specially_allowed_magic & 0x0004) > 0));
				GameRes.selection_list.AddItem("물위를 걸음", 4, (level_to_use >= 4) || ((player.specially_allowed_magic & 0x0008) > 0));
				GameRes.selection_list.AddItem("늪위를 걸음", 5, (level_to_use >= 5) || ((player.specially_allowed_magic & 0x0010) > 0));
			}
			else
			{
				GameRes.selection_list.AddItem("기화 이동", 6, (level_to_use >= 6) || ((player.specially_allowed_magic & 0x0020) > 0));
				GameRes.selection_list.AddItem("지형 변화", 7, (level_to_use >= 7) || ((player.specially_allowed_magic & 0x0040) > 0));
				GameRes.selection_list.AddItem("공간 이동", 8, (level_to_use >= 8) || ((player.specially_allowed_magic & 0x0080) > 0));
				GameRes.selection_list.AddItem("식량 제조", 9, (level_to_use >= 9) || ((player.specially_allowed_magic & 0x0100) > 0));
				GameRes.selection_list.AddItem("대지형 변화", 10, (level_to_use >= 10) || ((player.specially_allowed_magic & 0x0200) > 0));
			}

			GameRes.selection_list.Run
			(
				delegate ()
				{
					Console.DisplayRichText("");

					int index = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);
					switch (index)
					{
						case 1:
							this.Cast_IgniteTorch(player);
							break;
						case 2:
							this.Cast_EyesOfBeholder(player);
							break;
						case 3:
							this.Cast_Levitate(player);
							break;
						case 4:
							this.Cast_WalkOnWater(player);
							break;
						case 5:
							this.Cast_WalkOnSwamp(player);
							break;
						case 6:
							this.Cast_Etherealize(player);
							break;
						case 7:
							this.Cast_ChangeToGround(player);
							break;
						case 8:
							this.Cast_Telelport(player);
							break;
						case 9:
							this.Cast_CreateFood(player);
							break;
						case 10:
							this.Cast_ChangeToGroundEx(player);
							break;
						default:
							Debug.Assert(false);
							break;
					}
				}
			);
		}

		public void UseEsp(ObjPlayer player)
		{
			// TODO: UseESP
			if (player.GetMaxSP() == 0)
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 초능력을 사용하는 계열이 아닙니다.", true);
				return;
			}

			int level_to_use = player.skill[(int)SKILL_TYPE.ESP] / 10;

			if (level_to_use <= 0)
			{
				Console.DisplaySmText(player.GetName(ObjNameBase.JOSA.SUB) + " 사용 가능한 초능력이 없습니다.", true);
				return;
			}

			GameRes.selection_list.Init();
			GameRes.selection_list.AddGuide("선택\n");

			GameRes.selection_list.AddItem("투시", 1, level_to_use >= 1);
			GameRes.selection_list.AddItem("초감각 집중", 2, level_to_use >= 2);
			GameRes.selection_list.AddItem("독심술", 3, level_to_use >= 3);
			GameRes.selection_list.AddItem("천리안", 4, level_to_use >= 4);

			GameRes.selection_list.Run
			(
				delegate ()
				{
					Console.DisplayRichText("");

					int index = GameRes.selection_list.GetRealIndex(GameRes.selection_list.ix_curr);
					switch (index)
					{
						case 1:
							GameRes.party.core.penetration = 5;
							break;
						default:
							Debug.Assert(false);
							break;
					}
				}
			);
		}

		public string SummonSomething(ObjPlayer player, int spell)
		{
			// TODO: SummonSomething

			string message = "";

			int ix_reserved =  GameRes.GetIndexOfResevedPlayer();

			if (GameRes.player[ix_reserved].IsValid())
				return "";

			if (player == null || spell <= 0)
				return "";

			// <spell>
			// 1~10 : Summon something from the magic casting
			// 11   : Summon something by using a scroll
			// 12   : Summon something by using a crystal

			// TODO: Magic number 10?
			if (player != null)
			if (player.skill[(int)SKILL_TYPE.SUMMON] < 10)
				return "";

			string target_name = "[]";
			GENDER target_gender = GENDER.UNKNOWN;
			CLASS  target_clazz = CLASS.UNKNOWN;
			RACE   target_race = RACE.UNKNOWN;
			int    target_level = 1;

			ObjPlayer summoned = null;

			// TODO: 이름이 긴 소환수 문제. (최대 5자) 드래곤은 없애자.
			// TODO: 산출된 summoned.atta_pow 가 level이나 skill에 비례하는지 확인
			switch (spell)
			{
				case 1: // 불의 정령 소환
					switch (LibUtil.GetRandomIndex(3))
					{
						case 0: target_name = "사라만다"; break;
						case 1: target_name = "아저"; break;
						case 2: target_name = "이프리트"; break;
					}

					target_race = RACE.ELEMENTAL;
					target_level = player.skill[(int)SKILL_TYPE.SUMMON] / 5;

					summoned = ObjPlayer.CreateCreature(target_name, target_gender, target_clazz, target_race, target_level);

					summoned.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_SINGLE, 1));
					// 원작은 wea_power := player[person].summon_magic * 3;
					break;

				case 2: // 물의 정령 소환
					switch (LibUtil.GetRandomIndex(9))
					{
						// https://en.wikipedia.org/wiki/Pitys_(mythology)
						case 0: target_name = "님프"; break;
						case 1: target_name = "드리어드"; break;
						case 2: target_name = "네레이드"; break;
						case 3: target_name = "나이아드"; break;
						case 4: target_name = "나파이어"; break;
						case 5: target_name = "오레이드"; break;
						case 6: target_name = "알세이드"; break;
						case 7: target_name = "마리드"; break;
						case 8: target_name = "켈피"; break;
					}

					target_race = RACE.ELEMENTAL;
					target_level = player.skill[(int)SKILL_TYPE.SUMMON] / 5;

					summoned = ObjPlayer.CreateCreature(target_name, target_gender, target_clazz, target_race, target_level);

					summoned.intrinsic_status[(int)STATUS.END] -= 2;
					summoned.intrinsic_status[(int)STATUS.RES] += 2;
					summoned.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_MULTI, 1));
					// 원작은 wea_power := player[person].summon_magic * 2;
					// ac := 1; potential_ac:= 1;
					break;
				case 3: // 공기의 정령 소환
					switch (LibUtil.GetRandomIndex(4))
					{
						case 0: target_name = "실프"; break;
						case 1: target_name = "실피드"; break;
						case 2: target_name = "디지니"; break;
						case 3: target_name = "투명미행자"; break;
					}

					target_race = RACE.ELEMENTAL;
					target_level = player.skill[(int)SKILL_TYPE.SUMMON] / 5;

					summoned = ObjPlayer.CreateCreature(target_name, target_gender, target_clazz, target_race, target_level);

					summoned.intrinsic_status[(int)STATUS.END] -= 4;
					summoned.intrinsic_status[(int)STATUS.RES] += 4;
					summoned.intrinsic_status[(int)STATUS.DEX] += 3;
					summoned.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_MULTI, 2));
					// 원작은 wea_power := player[person].summon_magic * 1;
					// ac := 1; potential_ac:= 1;
					break;
				case 4: // 땅의 정령 소환
					switch (LibUtil.GetRandomIndex(2))
					{
						case 0: target_name = "노움"; break;
						case 1: target_name = "다오"; break;
					}

					target_race = RACE.ELEMENTAL;
					target_level = player.skill[(int)SKILL_TYPE.SUMMON] / 5;

					summoned = ObjPlayer.CreateCreature(target_name, target_gender, target_clazz, target_race, target_level);

					summoned.intrinsic_status[(int)STATUS.END] += 4;
					summoned.intrinsic_status[(int)STATUS.DEX] -= 4;
					summoned.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_SINGLE, 2));
					// 원작은 wea_power := player[person].summon_magic * 4;
					// ac := 3; potential_ac:= 3;
					break;
				case 5: // 죽은 자의 소생
					target_race = RACE.HUMAN;
					target_level = player.skill[(int)SKILL_TYPE.SUMMON] / 5;

					// TODO: [소환] 하다 말았음
					switch (LibUtil.GetRandomIndex(2))
					{
						case 0:
							target_name = "고대의기사";
							target_clazz = CLASS.KNIGHT;
							target_gender = GENDER.MALE;

							summoned = ObjPlayer.CreateCreature(target_name, target_gender, target_clazz, target_race, target_level);
							summoned.title = PLAYER_TITLE.UNDEAD;

							summoned.intrinsic_status[(int)STATUS.STR] += LibUtil.GetRandomForSummon(4);
							summoned.intrinsic_status[(int)STATUS.INT] += LibUtil.GetRandomForSummon(2);
							summoned.intrinsic_status[(int)STATUS.END] += LibUtil.GetRandomForSummon(4);
							summoned.intrinsic_status[(int)STATUS.CON] += LibUtil.GetRandomForSummon(4);
							summoned.intrinsic_status[(int)STATUS.RES] += LibUtil.GetRandomForSummon(3);
							summoned.intrinsic_status[(int)STATUS.DEX] += LibUtil.GetRandomForSummon(3);
							summoned.intrinsic_status[(int)STATUS.LUC] += LibUtil.GetRandomForSummon(1);

							summoned.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.WIELD, 2));
							break;
						case 1:
							target_name = "고대마법사";
							break;
					}

					summoned.intrinsic_status[(int)STATUS.END] += 4;
					summoned.intrinsic_status[(int)STATUS.DEX] -= 4;
					summoned.SetEquipment(Yunjr.EQUIP.HAND, Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_SINGLE, 2));
					// 원작은 wea_power := player[person].summon_magic * 4;
					// ac := 3; potential_ac:= 3;
					break;
				case 6: // 다른 차원 생물 소환
				case 7: // 거인을 부름
				case 8: // 고렘을 부름
				case 9: // 용을 부름
				case 10: // 라이칸스로프 소환
					Debug.Assert(false);
					break;

				case 11: // 소환 두루마리에 의한 소환
					{
						ResId weapon_resid = null;
						int index = LibUtil.GetRandomIndex(4);

						switch (index)
						{
							case 0:
								target_name = "불의정령";
								weapon_resid = Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_SINGLE, 1);
								break;
							case 1:
								target_name = "물의정령";
								weapon_resid = Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_MULTI, 1);
								break;
							case 2:
								target_name = "공기의정령";
								weapon_resid = Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_MULTI, 2);
								break;
							case 3:
								target_name = "땅의정령";
								weapon_resid = Yunjr.ResId.CreateResId_Weapon((uint)Yunjr.ITEM_TYPE.SUMMON_SINGLE, 2);
								break;
						}

						target_race = RACE.ELEMENTAL;
						target_level = 10;

						summoned = ObjPlayer.CreateCreature(target_name, target_gender, target_clazz, target_race, target_level);

						summoned.SetEquipment(Yunjr.EQUIP.HAND, weapon_resid ?? new ResId());
					}
					break;

				case 12: // 소환 크리스탈에 의한 소환
					Debug.Assert(false);
					break;
			}

			summoned.Apply();

			summoned.hp = summoned.GetMaxHP();
			summoned.sp = summoned.GetMaxSP();

			// TODO: 
			/*
			begin
			   case battle[person,2] of
				  5 : with player[6] do begin
						 if random(2) = 0 then begin
							name := '고대의기사';
							sex := male;
							class := 2;
							classtype := sword;
							strength := 12+r(5);
							mentality := 6+r(5);
							endurance := 15+r(5);
							resistance := 10+r(5);
							accuracy := 13+r(5);
							sp := 0;
							weapon := 6;
							wea_power := 60+r(10);
							shield := 2;
							shi_power := 2;
							armor := 3+r(1);
							potential_ac := 2;
							ac := armor + potential_ac;
							sword_skill := player[person].summon_magic;
							axe_skill := 0;
							spear_skill := 0;
							bow_skill := 0;
							fist_skill := 0;
							shield_skill := player[person].summon_magic;
						 end
						 else begin
							name := '고대마법사';
							sex := female;
							class := 1;
							classtype := magic;
							strength := 7+r(5);
							mentality := 12+r(5);
							endurance := 7+r(5);
							resistance := 10+r(5);
							accuracy := 13+r(5);
							sp := mentality * level;
							weapon := 29;
							wea_power := 2;
							shield := 0;
							shi_power := 0;
							armor := 0;
							potential_ac := 0;
							ac := 0;
							sword_skill := 0;
							axe_skill := 0;
							spear_skill := 0;
							bow_skill := 0;
							fist_skill := 0;
							shield_skill := 0;
						 end;
						 level := player[person].summon_magic div 5;
						 concentration := 10+r(5);
						 agility := 0;
						 luck := 10+r(5);
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 experience := 0;
						 potential_experience := 0;
						 Display_Condition;
					  end;
				  6 : with player[6] do begin
						 case random(8) of
							0 : begin
								   name := '밴더스내치';
								   endurance := 15+r(5);
								   resistance := 8+r(5);
								   accuracy := 12+r(5);
								   weapon := 33;
								   wea_power := player[person].summon_magic * 3;
								   potential_ac := 3;
								   ac := 3;
								end;
							1 : begin
								   name := '부육크롤러';
								   endurance := 20+r(5);
								   resistance := 14+r(5);
								   accuracy := 13+r(5);
								   weapon := 34;
								   wea_power := player[person].summon_magic * 1;
								   potential_ac := 3;
								   ac := 3;
								end;
							2 : begin
								   name := '켄타우루스';
								   endurance := 17+r(5);
								   resistance := 12+r(5);
								   accuracy := 18+r(2);
								   weapon := 35;
								   wea_power := round(player[person].summon_magic * 1.5);
								   potential_ac := 2;
								   ac := 2;
								end;
							3 : begin
								   name := '데모고르곤';
								   endurance := 18+r(5);
								   resistance := 5+r(5);
								   accuracy := 17+r(3);
								   weapon := 36;
								   wea_power := player[person].summon_magic * 4;
								   potential_ac := 4;
								   ac := 4;
								end;
							4 : begin
								   name := '듈라한';
								   endurance := 10+r(5);
								   resistance := 20;
								   accuracy := 17;
								   weapon := 16;
								   wea_power := player[person].summon_magic * 1;
								   potential_ac := 3;
								   ac := 3;
								end;
							5 : begin
								   name := '에틴';
								   endurance := 10+r(5);
								   resistance := 10;
								   accuracy := 10+r(9);
								   weapon := 8;
								   wea_power := round(player[person].summon_magic * 0.8);
								   potential_ac := 1;
								   ac := 1;
								end;
							6 : begin
								   name := '헬하운드';
								   endurance := 14+r(5);
								   resistance := 9+r(5);
								   accuracy := 11+r(5);
								   weapon := 33;
								   wea_power := player[person].summon_magic * 3;
								   potential_ac := 2;
								   ac := 2;
								end;
							7 : begin
								   name := '미노타우르';
								   endurance := 13+r(5);
								   resistance := 11+r(5);
								   accuracy := 14+r(5);
								   weapon := 9;
								   wea_power := player[person].summon_magic * 3;
								   potential_ac := 2;
								   ac := 2;
								end;
						 end;
						 sex := neutral;
						 class := 0;
						 classtype := unknown;
						 level := player[person].summon_magic div 5;
						 strength := 10+r(5);
						 mentality := 10+r(5);
						 concentration := 10+r(5);
						 agility := 0;
						 luck := 10+r(5);
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 sp := 0;
						 experience := 0;
						 potential_experience := 0;
						 shield := 0;
						 shi_power := 0;
						 armor := 0;
						 sword_skill := 0;
						 axe_skill := 0;
						 spear_skill := 0;
						 bow_skill := 0;
						 shield_skill := 0;
						 fist_skill := 0;
						 Display_Condition;
					  end;
				  7 : with player[6] do begin
						 case random(6) of
							0 : begin
								   name := '구름거인';
								   endurance := 20+r(5);
								   resistance := 15+r(5);
								   accuracy := 10+r(5);
								   weapon := 37;
								   wea_power := round(player[person].summon_magic * 2.5);
								   potential_ac := 2;
								   ac := 2;
								end;
							1 : begin
								   name := '화염거인';
								   endurance := 25+r(5);
								   resistance := 5+r(5);
								   accuracy := 12+r(5);
								   weapon := 38;
								   wea_power := player[person].summon_magic * 4;
								   potential_ac := 2;
								   ac := 2;
								end;
							2 : begin
								   name := '한랭거인';
								   endurance := 30+r(5);
								   resistance := 8+r(5);
								   accuracy := 8+r(2);
								   weapon := 2;
								   wea_power := player[person].summon_magic * 2;
								   potential_ac := 2;
								   ac := 2;
								end;
							3 : begin
								   name := '언덕거인';
								   endurance := 40+r(5);
								   resistance := 5+r(5);
								   accuracy := 7+r(3);
								   weapon := 39;
								   wea_power := round(player[person].summon_magic * 1.5);
								   potential_ac := 2;
								   ac := 2;
								end;
							4 : begin
								   name := '바위거인';
								   endurance := 20+r(5);
								   resistance := 10+r(5);
								   accuracy := 11+r(5);
								   weapon := 37;
								   wea_power := round(player[person].summon_magic * 2.5);
								   potential_ac := 4;
								   ac := 4;
								end;
							5 : begin
								   name := '폭풍거인';
								   endurance := 20+r(5);
								   resistance := 10+r(5);
								   accuracy := 15+r(9);
								   weapon := 40;
								   wea_power := player[person].summon_magic * 6;
								   potential_ac := 1;
								   ac := 1;
								end;
						 end;
						 sex := male;
						 class := 0;
						 classtype := giant;
						 level := player[person].summon_magic div 5;
						 strength := 10+r(5);
						 mentality := 10+r(5);
						 concentration := 10+r(5);
						 agility := 0;
						 luck := 10+r(5);
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 sp := 0;
						 experience := 0;
						 potential_experience := 0;
						 shield := 0;
						 shi_power := 0;
						 armor := 0;
						 sword_skill := 0;
						 axe_skill := 0;
						 spear_skill := 0;
						 bow_skill := 0;
						 shield_skill := 0;
						 fist_skill := 0;
						 Display_Condition;
					  end;
				  8 : with player[6] do begin
						 case random(4) of
							0 : begin
								   name := '진흙고렘';
								   endurance := 30+r(5);
								   resistance := 15+r(5);
								   accuracy := 13+r(5);
								   weapon := 41;
								   wea_power := round(player[person].summon_magic * 0.5);
								   potential_ac := 3;
								   ac := 3;
								end;
							1 : begin
								   name := '프레쉬고렘';
								   endurance := 20+r(5);
								   resistance := 10+r(5);
								   accuracy := 12+r(5);
								   weapon := 0;
								   wea_power := player[person].summon_magic * 1;
								   potential_ac := 1;
								   ac := 1;
								end;
							2 : begin
								   name := '강철고렘';
								   endurance := 20+r(5);
								   resistance := 5+r(5);
								   accuracy := 10+r(2);
								   weapon := 42;
								   wea_power := player[person].summon_magic * 4;
								   potential_ac := 5;
								   ac := 5;
								end;
							3 : begin
								   name := '바위고렘';
								   endurance := 25+r(5);
								   resistance := 10+r(5);
								   accuracy := 13+r(3);
								   weapon := 0;
								   wea_power := player[person].summon_magic * 2;
								   potential_ac := 4;
								   ac := 4;
								end;
						 end;
						 sex := neutral;
						 class := 0;
						 classtype := golem;
						 level := player[person].summon_magic div 5;
						 strength := 10+r(5);
						 mentality := 10+r(5);
						 concentration := 10+r(5);
						 agility := 0;
						 luck := 10+r(5);
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 sp := 0;
						 experience := 0;
						 potential_experience := 0;
						 shield := 0;
						 shi_power := 0;
						 armor := 0;
						 sword_skill := 0;
						 axe_skill := 0;
						 spear_skill := 0;
						 bow_skill := 0;
						 shield_skill := 0;
						 fist_skill := 0;
						 Display_Condition;
					  end;
				  9 : with player[6] do begin
						 case random(12) of
							0 : begin
								   name := '블랙드래곤';
								   weapon := 43;
								end;
							1 : begin
								   name := '블루드래곤';
								   weapon := 44;
								end;
							2 : begin
								   name := '블래스 드래곤';
								   weapon := 45;
								end;
							3 : begin
								   name := '브론즈 드래곤';
								   weapon := 44;
								end;
							4 : begin
								   name := '크로매틱 드래곤';
								   weapon := 46;
								end;
							5 : begin
								   name := '코퍼드래곤';
								   weapon := 43;
								end;
							6 : begin
								   name := '골드드래곤';
								   weapon := 46;
								end;
							7 : begin
								   name := '그린드래곤';
								   weapon := 47;
								end;
							8 : begin
								   name := '플래티움 드래곤';
								   weapon := 48;
								end;
							9 : begin
								   name := '레드드래곤';
								   weapon := 46;
								end;
							10: begin
								   name := '실버드래곤';
								   weapon := 49;
								end;
							11: begin
								   name := '화이트 드래곤';
								   weapon := 49;
								end;
						 end;
						 endurance := 30+r(10);
						 resistance := 10+r(10);
						 accuracy := 15+r(5);
						 wea_power := round(player[person].summon_magic * (random(5)+1));
						 potential_ac := 3;
						 ac := 3;
						 sex := neutral;
						 class := 0;
						 classtype := dragon;
						 level := player[person].summon_magic div 5;
						 strength := 10+r(5);
						 mentality := 10+r(5);
						 concentration := 10+r(5);
						 agility := 0;
						 luck := 10+r(5);
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 sp := 0;
						 experience := 0;
						 potential_experience := 0;
						 shield := 0;
						 shi_power := 0;
						 armor := 0;
						 sword_skill := 0;
						 axe_skill := 0;
						 spear_skill := 0;
						 bow_skill := 0;
						 shield_skill := 0;
						 fist_skill := 0;
						 Display_Condition;
					  end;
				  10: with player[6] do begin
						 case random(2) of
							0 : begin
								   name := '늑대인간';
								   classtype := unknown;
								   endurance := 25;
								   resistance := 15;
								   accuracy := 18;
								   weapon := 36;
								   wea_power := player[person].summon_magic * 3;
								   potential_ac := 2;
								   ac := 2;
								end;
							1 : begin
								   name := '드래곤뉴트';
								   classtype := dragon;
								   endurance := 30;
								   resistance := 18;
								   accuracy := 19;
								   weapon := 6;
								   wea_power := round(player[person].summon_magic * 4.5);
								   potential_ac := 4;
								   ac := 4;
								end;
						 end;
						 sex := male;
						 class := 0;
						 level := player[person].summon_magic div 5;
						 strength := 10+r(5);
						 mentality := 10+r(5);
						 concentration := 10+r(5);
						 agility := 0;
						 luck := 10+r(5);
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 sp := 0;
						 experience := 0;
						 potential_experience := 0;
						 shield := 0;
						 shi_power := 0;
						 armor := 0;
						 sword_skill := 0;
						 axe_skill := 0;
						 spear_skill := 0;
						 bow_skill := 0;
						 shield_skill := 0;
						 fist_skill := 0;
						 Display_Condition;
					  end;
				  11: with player[6] do begin
						 case random(3) of
							0 : begin
								   name := '수정드래곤';
								   classtype := dragon;
								   strength := 25;
								   mentality := 20;
								   concentration := 20;
								   endurance := 30;
								   resistance := 20;
								   agility := 0;
								   accuracy := 20;
								   luck := 20;
								   weapon := 49;
								   wea_power := 255;
								   potential_ac := 4;
								end;
						  1,2 : begin
								   name := '수정고렘';
								   classtype := golem;
								   strength := 20;
								   mentality := 0;
								   concentration := 0;
								   endurance := 40;
								   resistance := 25;
								   agility := 0;
								   accuracy := 13;
								   luck := 0;
								   weapon := 0;
								   wea_power := 150;
								   potential_ac := 5;
								end;
						 end;
						 sex := neutral;
						 class := 0;
						 level := 30;
						 poison := 0;
						 unconscious := 0;
						 dead := 0;
						 hp := endurance * level * 10;
						 sp := 0;
						 ac := potential_ac;
						 experience := 0;
						 potential_experience := 0;
						 shield := 0;
						 shi_power := 0;
						 armor := 0;
						 sword_skill := 0;
						 axe_skill := 0;
						 spear_skill := 0;
						 bow_skill := 0;
						 shield_skill := 0;
						 fist_skill := 0;
						 Display_Condition;
					  end;
			   end;
			end;  
			*/

			if (summoned.IsAvailable())
			{
				GameRes.player[ix_reserved] = summoned;
				GameObj.UpdatePlayerStatus();
			}

			return "";
		}

		private bool _NormalizeDirection(ref int dx, ref int dy, bool height_priority = true)
		{
			dx = (dx < 0) ? -1 : dx;
			dx = (dx > 0) ? +1 : dx;
			dy = (dy < 0) ? -1 : dy;
			dy = (dy > 0) ? +1 : dy;

			if (dx != 0 && dy != 0)
			{
				if (height_priority)
					dx = 0;
				else
					dy = 0;
			}

			return (dx != 0 || dy != 0);
		}

		public override void _Load(Stream stream)
		{
			Debug.Assert(core.item.Length == 10);
			Debug.Assert(core.crystal.Length == 10);
			Debug.Assert(core.relic.Length == 10);
			Debug.Assert(core.back_pack.Length == 100);
			Debug.Assert(core.identified_map.Length == 128);
			Debug.Assert(core.checksum.Length == 2);

			Debug.Assert(core._reserved_1.Length == 36);
			Debug.Assert(core._reserved_2.Length == 36);
			Debug.Assert(core._reserved_3.Length == 36);

			_Read(stream, out core.gameover_condition);
			_Read(stream, out core.time_event_duration);
			_Read(stream, out core.time_event_id);

			_Read(stream, out core.pos.x);
			_Read(stream, out core.pos.y);
			_Read(stream, out core.faced.dx);
			_Read(stream, out core.faced.dy);
			_Read(stream, out core.food);
			_Read(stream, out core.gold);
			_Read(stream, out core.arrow);

			for (int i = 0; i < core.item.Length; i++)
				_Read(stream, out core.item[i]);
			for (int i = 0; i < core.crystal.Length; i++)
				_Read(stream, out core.crystal[i]);
			for (int i = 0; i < core.relic.Length; i++)
				_Read(stream, out core.relic[i]);

			for (int i = 0; i < core.back_pack.Length; i++)
			{
				bool exist;
				_Read(stream, out exist);

				core.back_pack[i] = null;
				if (exist)
				{
					core.back_pack[i] = new Equiped();
					core.back_pack[i]._Load(stream);
				}
			}

			_Read(stream, ref core._reserved_1);

			_Read(stream, out core.magic_torch);
			_Read(stream, out core.levitation);
			_Read(stream, out core.walk_on_water);
			_Read(stream, out core.walk_on_swamp);
			_Read(stream, out core.mind_control);
			_Read(stream, out core.penetration);

			_Read(stream, ref core._reserved_2);

			_Read(stream, out core.can_use_ESP);
			_Read(stream, out core.can_use_special_magic);
			_Read(stream, out core.current_capacity_of_backpack);

			_Read(stream, ref core._reserved_3);

			_Read(stream, out core.year);
			_Read(stream, out core.day);
			_Read(stream, out core.hour);
			_Read(stream, out core.min);
			_Read(stream, out core.sec);
			_Read(stream, out core.encounter);
			_Read(stream, out core.max_enemy);
			_Read(stream, out core.rest_time);

			stream.Read(core.identified_map, 0, core.identified_map.Length);
			stream.Read(core.checksum, 0, core.checksum.Length);
		}

		public override void _Save(Stream stream)
		{
			_Write(stream, ref core.gameover_condition);
			_Write(stream, ref core.time_event_duration);
			_Write(stream, ref core.time_event_id);

			_Write(stream, ref core.pos.x);
			_Write(stream, ref core.pos.y);
			_Write(stream, ref core.faced.dx);
			_Write(stream, ref core.faced.dy);
			_Write(stream, ref core.food);
			_Write(stream, ref core.gold);
			_Write(stream, ref core.arrow);

			for (int i = 0; i < core.item.Length; i++)
				_Write(stream, ref core.item[i]);
			for (int i = 0; i < core.crystal.Length; i++)
				_Write(stream, ref core.crystal[i]);
			for (int i = 0; i < core.relic.Length; i++)
				_Write(stream, ref core.relic[i]);

			for (int i = 0; i < core.back_pack.Length; i++)
			{
				if (core.back_pack[i] != null && core.back_pack[i].IsValid())
				{
					_Write(stream, true);
					core.back_pack[i]._Save(stream);
				}
				else
				{
					_Write(stream, false);
				}
			}

			_Write(stream, ref core._reserved_1);

			_Write(stream, ref core.magic_torch);
			_Write(stream, ref core.levitation);
			_Write(stream, ref core.walk_on_water);
			_Write(stream, ref core.walk_on_swamp);
			_Write(stream, ref core.mind_control);
			_Write(stream, ref core.penetration);

			_Write(stream, ref core._reserved_2);

			_Write(stream, core.can_use_ESP);
			_Write(stream, core.can_use_special_magic);
			_Write(stream, ref core.current_capacity_of_backpack);

			_Write(stream, ref core._reserved_3);

			_Write(stream, ref core.year);
			_Write(stream, ref core.day);
			_Write(stream, ref core.hour);
			_Write(stream, ref core.min);
			_Write(stream, ref core.sec);
			_Write(stream, ref core.encounter);
			_Write(stream, ref core.max_enemy);
			_Write(stream, ref core.rest_time);

			stream.Write(core.identified_map, 0, core.identified_map.Length);
			stream.Write(core.checksum, 0, core.checksum.Length);
		}
	}
}

#if _TESTCASE_
namespace Testcase
{
	class ObjParty
	{
		static void Main(string[] args)
		{
			yunjr.Party party = new yunjr.Party();

			for (bool exit_condition = false; !exit_condition; )
			{
				party.WaitForIdleState(delegate () { Console.Write("."); });
				Console.WriteLine("\nparty ({0},{1})", party.pos.x, party.pos.y);

				ConsoleKeyInfo ki = Console.ReadKey(true);

				switch (ki.Key)
				{
				case ConsoleKey.LeftArrow  : party.Move(-1, 0); break;
				case ConsoleKey.RightArrow : party.Move( 1, 0); break;
				case ConsoleKey.UpArrow    : party.Move(0, -1); break;
				case ConsoleKey.DownArrow  : party.Move(0,  1); break;
				case ConsoleKey.Escape     : exit_condition = true; break;
				}
			}
		}
	}
}
#endif // #if _TESTCASE_
