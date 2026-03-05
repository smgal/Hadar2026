using UnityEngine;
using System.Collections;

namespace Yunjr
{
	public class ObjEnemy: ObjNameBase
	{
		public CreatureAttribOld attrib;
		public CreatureState  state;
		public int distance;

		private bool _valid = false;
		private int _ix_obj = 0;

		public bool Valid
		{
			get { return _valid; }
			set { _valid = value; }
		}

		public string Name
		{
			get { return this._name; }
			set { this.SetName(value); }
		}

		public ObjEnemy(int ix_obj)
		{
			_valid = false;
			_ix_obj = ix_obj;
		}

		public void _New(int index, int distance)
		{
			_valid = true;
			this.distance = distance;

			this.attrib = Yunjr.CreatureAttribOld.GetEnemy(index);
			this.Reset();
		}

		// fill 'state' from the current 'attrib'
		public void Reset()
		{
			this.state.hp = GetMaxHp();
			this.state.poison = 0;
			this.state.unconscious = 0;
			this.state.dead = 0;
			this.state.regenerative_hp = 0;
			this.state.doppelganger = 0; // init color
			this.SetName(this.attrib.name);
		}

		public int GetMaxHp()
		{
			return this.attrib.endurance * this.attrib.level * 10;
		}

		public bool IsAvailable()
		{
			return (this.IsValid() && this.state.dead == 0 && this.state.unconscious == 0 && this.state.hp > 0);
		}
	}
}
