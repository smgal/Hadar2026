
using System;
using System.Text;
using System.IO;

namespace Yunjr
{
	public enum STATUS
	{
		[AssignedString("체력")]
		STR,
		[AssignedString("정신력")]
		INT,
		[AssignedString("인내력")]
		END,
		[AssignedString("집중력")]
		CON,
		[AssignedString("민첩성")]
		AGI,
		[AssignedString("저항력")]
		RES,
		[AssignedString("손재주")]
		DEX,
		[AssignedString("행운")]
		LUC,
		[AssignedString("레벨")]
		LEV,
		[AssignedString("")]
		MAX
	}

	public enum ITEM_TYPE : int
	{
		NONE = -1,
		WEAPON_MIN = 0,
			WIELD = WEAPON_MIN, CHOP, STAB, HIT, SHOOT,
			SUMMON_SINGLE, SUMMON_MULTI,
		WEAPON_MAX,
		SHIELD_MIN = WEAPON_MAX,
			SHIELD = SHIELD_MIN,
		SHIELD_MAX,
		ARMOR_MIN = SHIELD_MAX,
			ARMOR = ARMOR_MIN, HEAD, LEG,
		ARMOR_MAX,
		ETC_MIN = ARMOR_MAX,
			ORNAMENT = ETC_MIN,
		ETC_MAX,
		MAX = ETC_MAX
	}

	public enum SKILL_TYPE
	{
		[AssignedString("베는 무기")]
		WIELD,
		[AssignedString("찍는 무기")]
		CHOP,
		[AssignedString("찌르는무기")]
		STAB,
		[AssignedString("타격 무기")]
		HIT,
		[AssignedString("쏘는 무기")]
		SHOOT,
		[AssignedString("방패 사용")]
		SHIELD,
		[AssignedString("공격 마법")]
		DAMAGE,
		[AssignedString("변화 마법")]
		ENVIRONMENT,
		[AssignedString("치료 마법")]
		CURE,
		[AssignedString("소환 마법")]
		SUMMON,
		[AssignedString("특수 마법")]
		SPECIAL,
		[AssignedString("초 자연력")]
		ESP,
		[AssignedString("")]
		MAX
	}

	public enum EQUIP
	{
		HAND, HAND_SUB, ARMOR, HEAD, LEG, ETC, // Leg -> Sabaton
		MAX
	}

	[Serializable]
	public enum GENDER
	{
		[AssignedString("불명")]
		UNKNOWN = 0,
		[AssignedString("남성")]
		MALE = 1,
		[AssignedString("여성")]
		FEMALE = 2
	}

	/*
	 * 캐릭터 생성에 의해서는 1~8번까지만 생성 가능하다.
	 * 따라서 0~8까지 순서는 절대 변경되어서는 안 된다.
	 */
	[Serializable]
	public enum CLASS
	{
		[AssignedString("불확실함")]
		UNKNOWN = 0,
		[AssignedString("떠돌이")]
		WANDERER = 1,
		[AssignedString("기사")]
		KNIGHT = 2,
		[AssignedString("사냥꾼")]
		HUNTER = 3,
		[AssignedString("전투승")]
		MONK = 4,
		[AssignedString("전사")]
		PALADIN = 5,
		[AssignedString("암살자")]
		ASSASSIN = 6,
		[AssignedString("마법사")]
		MAGICIAN = 7,
		[AssignedString("에스퍼")]
		ESPER = 8,
		[AssignedString("검사")]
		SWORDMAN = 9,
		[AssignedString("메이지")]
		MAGE = 10,
		[AssignedString("컨저러")]
		CONJURER = 11,
		[AssignedString("주술사")]
		SORCERER = 12,
		[AssignedString("위저드")]
		WIZARD = 13,
		[AssignedString("강령술사")]
		NECROMANCER = 14,
		[AssignedString("대마법사")]
		ARCHIMAGE = 15,
		[AssignedString("타임워커")]
		TIMEWALKER = 16,
		MAX
	}

	[Serializable]
	public enum CLASS_TYPE
	{
		PHYSICAL_FORCE,
		MAGIC_USER,
		HYBRID1, // 전사
		HYBRID2, // 암살자
		HYBRID3, // 에스퍼
		MAX
	}

	[Serializable]
	public enum RACE : uint
	{
		[AssignedString("인간")]
		HUMAN = 0,
		[AssignedString("불명")]
		UNKNOWN = 1,
		[AssignedString("엘리멘탈")]
		ELEMENTAL = 2,
		[AssignedString("거인")]
		GIANT = 3,
		[AssignedString("골렘")]
		GOLEM = 4,
		[AssignedString("용")]
		DRAGON = 5,
		[AssignedString("천사")]
		ANGEL = 6,
		[AssignedString("악마")]
		DEVIL = 7
	}

	// OR 이 가능한 값
	[Serializable]
	public enum PLAYER_TITLE : uint
	{
		[AssignedString("없음")]
		NONE = 0,
		[AssignedString("혼령")]
		UNDEAD = 1,
		[AssignedString("반신반인")]
		SEMIGOD = 2
	}

	[Serializable]
	public enum GAMEOVER_COND : uint
	{
		COMPLETELY_DEFEATED = 0,
		HERO_DEFEATED = 1,
		ALL_MEMBERS_DEFEATED = 2,
		ANY_MEMBERS_DEFEATED = 3,
	}

	struct SmResult
	{
		public bool success;
		public string message;
	};

	[Serializable]
	public abstract class ISerialize
	{
		protected void _Read(Stream stream, out int data)
		{ byte[] buffer = new byte[sizeof(int)]; stream.Read(buffer, 0, sizeof(int)); data = BitConverter.ToInt32(buffer, 0); }

		protected void _Read(Stream stream, out uint data)
		{ byte[] buffer = new byte[sizeof(uint)]; stream.Read(buffer, 0, sizeof(uint)); data = BitConverter.ToUInt32(buffer, 0); }

		protected void _Read(Stream stream, out long data)
		{ byte[] buffer = new byte[sizeof(long)]; stream.Read(buffer, 0, sizeof(long)); data = BitConverter.ToInt64(buffer, 0); }

		protected void _Read(Stream stream, out short data)
		{ byte[] buffer = new byte[sizeof(short)]; stream.Read(buffer, 0, sizeof(short)); data = BitConverter.ToInt16(buffer, 0); }

		protected void _Read(Stream stream, out bool data)
		{ byte[] buffer = new byte[sizeof(bool)]; stream.Read(buffer, 0, sizeof(bool)); data = BitConverter.ToBoolean(buffer, 0); }

		protected void _Read(Stream stream, out float data)
		{ byte[] buffer = new byte[sizeof(float)]; stream.Read(buffer, 0, sizeof(float)); data = BitConverter.ToSingle(buffer, 0); }

		protected void _Read(Stream stream, out double data)
		{ byte[] buffer = new byte[sizeof(double)]; stream.Read(buffer, 0, sizeof(double)); data = BitConverter.ToDouble(buffer, 0); }

		protected void _Read(Stream stream, out string data)
		{ data = ReadString(stream); }

		protected void _Read(Stream stream, ref int[] data)
		{
			byte[] buffer = new byte[data.Length * sizeof(int)];
			stream.Read(buffer, 0, buffer.Length);
			Buffer.BlockCopy(buffer, 0, data, 0, buffer.Length);
		}

		protected void _Read(Stream stream, out ItemSub item_sub)
		{
			_Read(stream, out item_sub.atta_pow);
			_Read(stream, out item_sub.ac);
			item_sub.item_type = (ITEM_TYPE)_GetEnumAsInt(stream);
		}

		protected void _Read(Stream stream, out Item item)
		{
			uint id = 0;
			_Read(stream, out id);
			item.res_id = new ResId(id);
			_Read(stream, out item.name);
			_Read(stream, out item.param);
			_Read(stream, out item.annex);
		}

		protected int _GetEnumAsInt(Stream stream)
		{ byte[] buffer = new byte[sizeof(int)]; stream.Read(buffer, 0, sizeof(int)); return BitConverter.ToInt32(buffer, 0); }

		///////////////////

		protected void _Write(Stream stream, ref int data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, ref uint data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, ref long data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, ref short data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, bool data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, ref float data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, ref double data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		protected void _Write(Stream stream, string str)
		{ WriteString(stream, str); }

		protected void _Write(Stream stream, ref int[] data)
		{
			byte[] buffer = new byte[data.Length * sizeof(int)];
			Buffer.BlockCopy(data, 0, buffer, 0, buffer.Length);
			stream.Write(buffer, 0, buffer.Length);
		}

		protected void _Write(Stream stream, ItemSub item_sub)
		{
			_Write(stream, ref item_sub.atta_pow);
			_Write(stream, ref item_sub.ac);
			_WriteEnum(stream, (int)item_sub.item_type);
		}

		protected void _Write(Stream stream, Item item)
		{
			if (item.res_id == null)
				return;
			uint id = item.res_id.GetId();
			_Write(stream, ref id);
			_Write(stream, item.name);
			_Write(stream, item.param);
			_Write(stream, item.annex);
		}

		protected void _WriteEnum(Stream stream, int data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		////////////////////

		public static int ReadInt(Stream stream)
		{ byte[] buffer = new byte[sizeof(int)]; stream.Read(buffer, 0, sizeof(int)); return BitConverter.ToInt32(buffer, 0); }

		public static void WriteInt(Stream stream, int data)
		{ byte[] buffer = BitConverter.GetBytes(data); stream.Write(buffer, 0, buffer.Length); }

		public static string ReadString(Stream stream)
		{
			int len = ReadInt(stream);
			byte[] buffer = new byte[len];
			stream.Read(buffer, 0, len);
			return Encoding.UTF8.GetString(buffer);
		}

		public static void WriteString(Stream stream, string data)
		{
			byte[] buffer = Encoding.UTF8.GetBytes(data);
			WriteInt(stream, buffer.Length);
			stream.Write(buffer, 0, buffer.Length);
		}

		////////////////////

		public abstract void _Load(Stream stream);
		public abstract void _Save(Stream stream);

	}
}
