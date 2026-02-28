
#ifndef __HD_CLASS_PC_PARTY_H__
#define __HD_CLASS_PC_PARTY_H__

#include "hd_class_serialized.h"

namespace hadar
{
	struct PcParty: public Serialized
	{
		enum POS
		{
			POS_PREV,
			POS_ABS,
			POS_REL,
		};

		union
		{
			struct
			{
				long x, y;
				long x_prev, y_prev;
				long faced;
				long encounter;
				long max_enemy;

				long food;
				long gold;

				struct
				{
					long magic_torch;
					long levitation;
					long walk_on_water;
					long walk_on_swamp;
					long mind_control;
					bool can_use_ESP; // etc[39] and bit1 > 0
					bool can_use_special_magic; // etc[38] and bit1 > 0
				} ability;
			};

			char save[20 * sizeof(long)];
		};

		PcParty(void);

		void move(int x1, int y1);
		void warp(POS pos, int x = 0, int y = 0);
		void face(int x1, int y1);

		void igniteTorch(void);
		void levitate(void);
		void walkOnWater(void);
		void walkOnSwamp(void);

	protected:
		bool _load(const ReadStream& stream);
		bool _save(const WriteStream& stream) const;
	};

} // namespace hadar

#endif // #ifndef __HD_CLASS_PC_PARTY_H__
