using UnityEngine;
using System;
using System.IO;
using System.Reflection;
using System.Collections;
using System.Collections.Generic;

namespace Yunjr
{
	public class StringComposer
	{
		private List<string> _prepared = new List<string>();

		public void Init(bool clear_console = true)
		{
			_prepared.Clear();

			if (clear_console)
				Console.Clear();
		}

		public string Done()
		{
			string s = "";

			foreach (string sub in _prepared)
			{
				s += sub;
				s += "\n";
			}

			return LibUtil.SmTextToRichText(Console.GetStringWordWrap(s));
		}

		public void Add(string s)
		{
			_prepared.Add(s);
		}

		public bool Empty()
		{
			return (_prepared.Count == 0);
		}
	}

	[Serializable]
	public class Flag: ISerialize
	{
		private int _max;
		private byte[] _data;

		public Flag(int max)
		{
			max = (max >= 0) ? max : 0;

			_max = max;
			_data = new byte[(max + 7) / 8];
			System.Array.Clear(_data, 0, _data.Length);
		}

		public void Clear()
		{
			Array.Clear(_data, 0, _data.Length);
		}

		public void Set(int index)
		{
			if (index >= 0 && index < _max)
			{
				int offset = index / 8;
				int shift = index % 8;
				_data[offset] |= (byte)(1 << shift);
			}
		}

		public void Reset(int index)
		{
			if (index >= 0 && index < _max)
			{
				int offset = index / 8;
				int shift = index % 8;
				_data[offset] &= (byte)~(1 << shift);
			}
		}

		public bool IsSet(int index)
		{
			if (index >= 0 && index < _max)
			{
				int offset = index / 8;
				int shift = index % 8;
				return (_data[offset] & (1 << shift)) > 0;
			}
			else
			{
				return false;
			}
		}

		public override void _Load(Stream stream)
		{
			_Read(stream, out _max);
			Array.Resize<byte>(ref _data, (_max + 7) / 8);
			stream.Read(_data, 0, _data.Length);
		}

		public override void _Save(Stream stream)
		{
			_Write(stream, ref _max);
			stream.Write(_data, 0, _data.Length);
		}
	}

	[Serializable]
	public class Variable: ISerialize
	{
		private int _max;
		private byte[] _data;

		public Variable(int max)
		{
			max = (max >= 0) ? max : 0;

			_max = max;
			_data = new byte[max];
			System.Array.Clear(_data, 0, _data.Length);
		}

		public byte this[int i]
		{
			get
			{
				return (i >= 0 && i < _max) ? _data[i] : (byte)0;
			}

			set
			{
				if (i >= 0 && i < _max)
					this._data[i] = value;
			}
		}

		public void Clear()
		{
			Array.Clear(_data, 0, _data.Length);
		}

		public override void _Load(Stream stream)
		{
			_Read(stream, out _max);
			Array.Resize<byte>(ref _data, _max);
			stream.Read(_data, 0, _data.Length);
		}

		public override void _Save(Stream stream)
		{
			_Write(stream, ref _max);
			stream.Write(_data, 0, _data.Length);
		}
	}

	public class AssignedString : System.Attribute
	{
		private string _value;

		public AssignedString(string value)
		{
			_value = value;
		}

		public string Value
		{
			get { return _value; }
		}
	}

	/* 사용 예는 다음과 같다
	 * 
	 * public class GameRes: MonoSingleton<GameRes>; 
	 * 
	 */
	public class MonoSingleton<T> : MonoBehaviour where T : Component
	{
		private static T instance;

		public static T Instance
		{
			get
			{
				if (instance == null)
				{
					instance = FindObjectOfType<T>();
					if (instance == null)
					{
						GameObject obj = new GameObject();
						obj.name = typeof(T).Name;
						instance = obj.AddComponent<T>();
					}
				}
				return instance;
			}
		}

		public virtual void Awake()
		{
			if (instance == null)
			{
				instance = this as T;
				DontDestroyOnLoad(this.gameObject);
			}
			else
			{
				Destroy(gameObject);
			}
		}
	}

	public static class LibUtil
	{
		public static int Sign(int a)
		{
			return (a > 0) ? 1 : ((a < 0) ? -1 : 0);
		}

		public static int Clamp(int val, int min, int max)
		{
			if (val < min)
				return min;
			else if (val > max)
				return max;
			else
				return val;
		}

		public static bool InRange(int val, int min, int max)
		{
			return (val >= min) && (val <= max);
		}

		public static string GetAssignedString<T>(T value)
		{
			Type type = value.GetType();

			FieldInfo field_info = type.GetField(value.ToString());
			AssignedString[] custom_attrs = field_info.GetCustomAttributes(typeof(AssignedString), false) as AssignedString[];

			if (custom_attrs.Length > 0)
				return custom_attrs[0].Value;
			else
				return "";
		}

		public static int SmTextExtent(string sm_text)
		{
			//?? @@
			int length = 0;

			foreach (char c in sm_text)
				length += (c < (char)256) ? 1 : 2;

			return length;
		}

		public static void SmTextAddSpace(ref string s, int width)
		{
			int len = LibUtil.SmTextExtent(s);

			if (len >= width)
				return;

			s = s.PadRight(s.Length + (width - len), ' ');
		}

		public static int SmTextIndexInWidth(string sm_text, int guide_width, int font_size)
		{
			int max_length = 2 * guide_width / font_size;
			int length = 0;
			int index = 0;

			while (index < sm_text.Length)
			{
				char c = sm_text[index];

				if (c == '\n')
					length = 0;
				else if (c == '@')
					++index;
				else if ((length += (c < (char)256) ? 1 : 2) > max_length)
					break;

				++index;
			}

			return index;
		}

		/*
		// Positive
		yunjr.Party.SmTextToRichText("ABC@AQWERTY@@ABC", out out_string);
		yunjr.Party.SmTextToRichText("@AQWERTY@@ABC", out out_string);
		yunjr.Party.SmTextToRichText("ABC@AQWERTY@@", out out_string);
		yunjr.Party.SmTextToRichText("@AQWERTY@@", out out_string);
		yunjr.Party.SmTextToRichText("QWERTY", out out_string);
		// Negative
		yunjr.Party.SmTextToRichText("@@QWERTY@@", out out_string);
		yunjr.Party.SmTextToRichText("@@QWERTY@A", out out_string);
		*/
		private static readonly string[] COLOR_TABLE =
		{
			"000000FF", "4D5DAAFF", "4DAA4DFF", "45A6A6FF", "B63C3CFF", "82307DFF", "AE7928FF", "AAAAAAFF",
			"515151FF", "2449FFFF", "3CFF75FF", "59E3E3FF", "FF5965FF", "CF71C7FF", "FFFF5DFF", "FFFFFFFF",
			"FFBF40FF"
		};

		public static string SmTextToRichText(string sm_text)
		{
			string rich_text = "";

			bool check_failed = false; ;
			int depth_count = 0;
			int ix_curr = 0;

			while (true)
			{
				int ix_found = sm_text.IndexOf('@', ix_curr);

				if (ix_found < 0)
				{
					rich_text += sm_text.Substring(ix_curr, sm_text.Length - ix_curr);
					break;
				}

				rich_text += sm_text.Substring(ix_curr, ix_found - ix_curr);

				if (sm_text[ix_found + 1] != '@')
				{
					int index = -1;
					char ch = sm_text[ix_found + 1];

					if (ch >= '0' && ch <= '9')
						index = ch - '0';
					else if (ch >= 'A' && ch <= 'G')
						index = ch - 'A' + 10;

					if (index < 0)
					{
						check_failed = true;
						index = 7;
					}

					rich_text += "<color=#";
					rich_text += COLOR_TABLE[index];
					rich_text += ">";

					depth_count++;
				}
				else
				{
					rich_text += "</color>";
					depth_count--;
				}

				if (depth_count < 0)
					check_failed = true;

				ix_curr = ix_found + 2;
			}

			if (check_failed || depth_count != 0)
				Debug.Log("(" + sm_text + ") not a complete sm-text");

			return rich_text;
		}

		public static uint MakeUniqueId(ACT_TYPE act_type, int x, int y, int dx, int dy)
		{
			int sign = LibUtil.Sign(dx) * 3 + LibUtil.Sign(dy);
			return (uint)(((int)act_type << 24) | (sign << 20) | (x << 10) | (y));
		}

		private static byte[] _ReadFully(Stream input)
		{
			byte[] buffer = new byte[16 * 1024];
			using (MemoryStream ms = new MemoryStream())
			{
				int read;
				while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
				{
					ms.Write(buffer, 0, read);
				}
				return ms.ToArray();
			}
		}

		public static byte[] StreamToByteArray(Stream stream)
		{
			if (stream is MemoryStream)
				return ((MemoryStream)stream).ToArray();
			else
				return _ReadFully(stream);
		}

		public static string ColorTagFromInt(uint color32, int value)
		{
			uint rgba = ((color32 << 8) & 0xFFFFFF00) | ((color32 >> 24) & 0x000000FF);
			string hex = rgba.ToString("X8");
			return String.Format(@"<color=#{0}>{1}</color>", hex, value);
		}

		public class Set<T> : System.Collections.Generic.SortedDictionary<T, bool>
		{
			public void Add(T item)
			{
				this.Add(item, true);
			}
		}

		public static double GetRandomPercentage()
		{
			return UnityEngine.Random.Range(0.0f, 100.0f);
		}

		public static double GetRandomProbability()
		{
			return UnityEngine.Random.Range(0.0f, 1.0f);
		}

		public static int GetRandomIndex(int max)
		{
			return UnityEngine.Random.Range(0, max);
		}

		public static int GetRandomIndex(ref Set<int> set, int max)
		{
			if (max - set.Count <= 0)
				return max;

			int index = UnityEngine.Random.Range(0, max - set.Count);
			Debug.Assert(index >= 0 && index < max - set.Count);

			for (int i = 0; i < max; i++)
			{
				bool result;
				if (!set.TryGetValue(i, out result))
				{
					if (index-- == 0)
					{
						set[i] = true;
						return i;
					}
				}
			}

			return max;
		}

		public static int GetRandomForSummon(int seed)
		{
			return LibUtil.GetRandomIndex(seed * 2 + 1) - seed;
		}

		public static CLASS_TYPE GetClassType(CLASS clazz)
		{
			switch (clazz)
			{
				case CLASS.UNKNOWN:
				case CLASS.WANDERER:
				case CLASS.KNIGHT:
				case CLASS.HUNTER:
				case CLASS.MONK:
				case CLASS.SWORDMAN:
					return CLASS_TYPE.PHYSICAL_FORCE;
				case CLASS.PALADIN:
					return CLASS_TYPE.HYBRID1;
				case CLASS.ASSASSIN:
					return CLASS_TYPE.HYBRID2;
				case CLASS.MAGICIAN:
				case CLASS.MAGE:
				case CLASS.CONJURER:
				case CLASS.SORCERER:
				case CLASS.WIZARD:
				case CLASS.NECROMANCER:
				case CLASS.ARCHIMAGE:
				case CLASS.TIMEWALKER:
					return CLASS_TYPE.MAGIC_USER;
				case CLASS.ESPER:
					return CLASS_TYPE.HYBRID3;
				default:
					Debug.Assert(false);
					return CLASS_TYPE.PHYSICAL_FORCE;
			}
		}

		public static void SaveScreenShot(string file_name)
		{
			if (Application.isEditor)
			{
				ScreenCapture.CaptureScreenshot(file_name);
			}
			else
			{
				Texture2D tex = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, true);
				tex.ReadPixels(new Rect(0f, 0f, Screen.width, Screen.height), 0, 0, true);
				tex.Apply();
				byte[] captureScreenShot = tex.EncodeToPNG();
				UnityEngine.Object.DestroyImmediate(tex);
				File.WriteAllBytes(file_name, captureScreenShot);
			}
		}

		public static GameObject GameObjectHardFind(string str)
		{
			GameObject result = null;
			foreach (GameObject root in GameObject.FindObjectsOfType(typeof(Transform)))
			{
				if (root.transform.parent == null)
				{ // means it's a root GO
					result = GameObjectHardFind(root, str, 0);
					if (result != null) break;
				}
			}
			return result;
		}

		public static GameObject GameObjectHardFind(string str, string tag)
		{
			GameObject result = null;
			foreach (GameObject parent in GameObject.FindGameObjectsWithTag(tag))
			{
				result = GameObjectHardFind(parent, str, 0);
				if (result != null) break;
			}
			return result;
		}

		private static GameObject GameObjectHardFind(GameObject item, string str, int index)
		{
			if (index == 0 && item.name == str) return item;
			if (index < item.transform.childCount)
			{
				GameObject result = GameObjectHardFind(item.transform.GetChild(index).gameObject, str, 0);
				if (result == null)
				{
					return GameObjectHardFind(item, str, ++index);
				}
				else
				{
					return result;
				}
			}
			return null;
		}
	}
}
