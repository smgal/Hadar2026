import 'package:hd_world/hd_world.dart';

/// Named equipment sets, captured and re-applied.
///
/// ## Why a lab wants these
///
/// Every question this screen exists to answer is a comparison: the
/// torch party against the dual-wield party, the shield wall against
/// the great swords. Rebuilding a five-member set by hand between two
/// readings is where the comparison gets abandoned.
///
/// ## They are moves, not state
///
/// A loadout stores what should be worn, and applying it is an ordinary
/// sequence of commands through `World.apply`. So a loadout cannot put
/// the world anywhere a player could not have put it by hand, and
/// anything it fails to place comes back as the same refusal the manual
/// move would have given — not as a silent gap.
class Loadouts {
  final Map<String, Loadout> _byName = {};

  Iterable<Loadout> get all => _byName.values;

  Loadout? operator [](String name) => _byName[name];

  bool remove(String name) => _byName.remove(name) != null;

  /// Reads what is worn right now and keeps it under [name].
  Loadout capture(World world, String name) {
    final set = Loadout(
      name: name,
      members: [
        for (final m in world.members)
          LoadoutMember(
            ref: m.ref,
            equipment: {
              for (final slot in EquipSlot.displayOrder)
                if (m.at(slot) != null) slot: m.at(slot)!,
            },
            style: m.style,
            thrift: m.thrift,
          ),
      ],
    );
    _byName[name] = set;
    return set;
  }

  Loadout restore(Map<String, Object?> json) {
    final set = Loadout.fromJson(json);
    _byName[set.name] = set;
    return set;
  }

  Map<String, Object?> toJson() => {
    'loadouts': [for (final l in _byName.values) l.toJson()],
  };
}

class Loadout {
  const Loadout({required this.name, required this.members});

  final String name;
  final List<LoadoutMember> members;

  static Loadout fromJson(Map<String, Object?> json) => Loadout(
    name: '${json['name'] ?? 'unnamed'}',
    members: [
      for (final raw in (json['members'] as List? ?? const []))
        if (raw is Map) LoadoutMember.fromJson(raw.cast<String, Object?>()),
    ],
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'members': [for (final m in members) m.toJson()],
  };

  /// The commands that would put the world into this shape.
  ///
  /// Strip the whole party, then dress the whole party. Two passes, and
  /// both are unconditional.
  ///
  /// **Why not keep what is already right.** Three reasons, and each one
  /// on its own is enough:
  ///
  /// * A thing this member is to wear may be on somebody else's arm
  ///   right now, and it cannot be equipped out of a pack it is not in.
  ///   So every member has to be stripped before any member is dressed.
  /// * Putting a two-handed weapon in the main hand evicts the off hand
  ///   on its own. A pass that skipped the off hand because it already
  ///   held the right thing would find it empty afterwards and never
  ///   go back.
  /// * Re-equipping what is already worn is refused as `notCarried`,
  ///   and a set that lands correctly while reporting eight refusals
  ///   teaches the reader to stop reading refusals.
  ///
  /// Bare hands are the exception: they cannot be taken off, so asking
  /// would only produce noise of the third kind.
  List<WorldCommand> plan(World world) {
    final out = <WorldCommand>[];

    for (final want in members) {
      final m = world.memberAt(want.ref);
      if (m == null) continue;
      for (final slot in EquipSlot.displayOrder) {
        final have = m.at(slot);
        if (have == null) continue;
        if (world.catalog[have]?.removable == false) continue;
        out.add(UnequipToPack(member: want.ref, slot: slot));
      }
    }

    for (final want in members) {
      if (world.memberAt(want.ref) == null) continue;
      // `displayOrder` puts the main hand before the off hand, which is
      // the order this has to happen in.
      for (final slot in EquipSlot.displayOrder) {
        final item = want.equipment[slot];
        if (item == null) continue;
        if (world.catalog[item]?.removable == false) continue;
        out.add(EquipFromPack(member: want.ref, slot: slot, item: item));
      }
      out.add(
        SetStyle(member: want.ref, style: want.style, thrift: want.thrift),
      );
    }

    return out;
  }

  /// Slots that do not hold what this set asked for.
  ///
  /// ## Why this is not the same question as "were there refusals"
  ///
  /// Stripping five members at once can fill the pack, and a pack that
  /// is full refuses to take a worn item — which is the pack doing its
  /// job, since the alternative is destroying it. The item then stays on
  /// the arm it was already on, the following equip is refused as
  /// `notCarried`, and the set has nevertheless landed exactly as asked.
  ///
  /// So the refusals are true and the outcome is fine, and only this
  /// tells them apart. An empty list means the world is what the set
  /// said, whatever was refused on the way.
  List<Map<String, Object?>> mismatch(World world) {
    final out = <Map<String, Object?>>[];
    for (final want in members) {
      final m = world.memberAt(want.ref);
      if (m == null) {
        out.add({'member': want.ref.value, 'missing': true});
        continue;
      }
      for (final slot in EquipSlot.displayOrder) {
        final wanted = want.equipment[slot];
        final have = m.at(slot);
        if (wanted == have) continue;
        out.add({
          'member': want.ref.value,
          'slot': slot.name,
          'wanted': wanted?.value,
          'got': have?.value,
        });
      }
    }
    return out;
  }
}

class LoadoutMember {
  const LoadoutMember({
    required this.ref,
    required this.equipment,
    required this.style,
    required this.thrift,
  });

  final MemberRef ref;
  final Map<EquipSlot, ItemRef> equipment;
  final FightingStyle style;
  final bool thrift;

  static LoadoutMember fromJson(Map<String, Object?> json) {
    final equipment = <EquipSlot, ItemRef>{};
    final raw = json['equipment'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final slot = EquipSlot.values
            .where((s) => s.name == '${e.key}')
            .firstOrNull;
        if (slot != null) equipment[slot] = ItemRef('${e.value}');
      }
    }
    return LoadoutMember(
      ref: MemberRef('${json['ref'] ?? ''}'),
      equipment: equipment,
      style:
          FightingStyle.values
              .where((s) => s.name == '${json['style']}')
              .firstOrNull ??
          FightingStyle.assault,
      thrift: json['thrift'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'ref': ref.value,
    'equipment': {
      for (final e in equipment.entries) e.key.name: e.value.value,
    },
    'style': style.name,
    'thrift': thrift,
  };
}
