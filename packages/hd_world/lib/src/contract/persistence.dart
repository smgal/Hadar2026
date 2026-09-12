import '../data/item_catalog.dart';
import '../domain/character_class.dart';
import '../domain/equip_slot.dart';
import '../domain/fighting_style.dart';
import '../domain/ids.dart';
import '../domain/member.dart';
import '../domain/pack.dart';
import '../domain/stats.dart';
import '../model/world.dart';

/// The saved shape of a world.
///
/// ## Only what cannot be recomputed
///
/// No fighting style, no final numbers, no party capabilities, no sight
/// radius. Saving a derived value means a save can disagree with the
/// rules that produced it, and then the older answer wins on load.
///
/// ## Names, not positions
///
/// Items are saved by reference. The previous format used the pair
/// `(kind, index)`, so inserting a catalogue row renamed everything
/// after it. `hd_world_legacy` reads the old numbers.
const int saveVersion = 1;

/// Something the load could not honour.
///
/// Loading never throws and never quietly drops anything. A save naming
/// an item this build does not have is a real event — the slot is
/// emptied and the loss is reported, so a player can be told rather
/// than finding a bare hand later.
class LoadIssue {
  const LoadIssue(this.message, {this.member, this.item});

  final String message;
  final String? member;
  final String? item;

  Map<String, Object?> toJson() => {
    'message': message,
    if (member != null) 'member': member,
    if (item != null) 'item': item,
  };

  @override
  String toString() => 'LoadIssue($message, member: $member, item: $item)';
}

class LoadResult {
  const LoadResult(this.world, this.issues);

  final World world;
  final List<LoadIssue> issues;

  bool get isClean => issues.isEmpty;
}

/// Writes a world out.
Map<String, Object?> saveWorld(World world) => {
  'version': saveVersion,
  'magicLight': world.magicLight,
  'pack': {
    'capacity': world.pack.capacity,
    'counts': {
      for (final e in world.pack.counts.entries) e.key.value: e.value,
    },
  },
  'members': [
    for (final m in world.members)
      {
        'ref': m.ref.value,
        'name': m.name,
        'class': m.clazz.wire,
        'style': m.style.wire,
        'thrift': m.thrift,
        'stats': {
          'strength': m.stats.strength,
          'mentality': m.stats.mentality,
          'concentration': m.stats.concentration,
          'endurance': m.stats.endurance,
          'resistance': m.stats.resistance,
          'agility': m.stats.agility,
          'luck': m.stats.luck,
        },
        'levels': {
          'physical': m.levels.physical,
          'magic': m.levels.magic,
          'esp': m.levels.esp,
        },
        'accuracy': {
          'physical': m.accuracy.physical,
          'magic': m.accuracy.magic,
          'esp': m.accuracy.esp,
        },
        'base': {
          'maxHitPoints': m.baseMaxHitPoints,
          'maxSpellPoints': m.baseMaxSpellPoints,
          'maxEspPoints': m.baseMaxEspPoints,
          'defence': m.baseDefence,
        },
        'gender': m.gender,
        'experience': m.experience,
        'vitals': {
          'hitPoints': m.hitPoints,
          'spellPoints': m.spellPoints,
          'espPoints': m.espPoints,
          'poison': m.poison,
          'unconscious': m.unconscious,
          'dead': m.dead,
        },
        'equipment': {
          for (final e in m.equipment.entries)
            '${e.key.wire}': e.value.value,
        },
      },
  ],
};

/// Reads a world back.
///
/// Anything malformed becomes an issue and a sensible value, because a
/// half-loaded party is worse than a slightly wrong one and throwing
/// would lose the rest of the file.
LoadResult loadWorld(Map<String, Object? > json, {ItemCatalog? catalog}) {
  final cat = catalog ?? ItemCatalog.builtIn;
  final issues = <LoadIssue>[];

  final version = _int(json['version'], 0);
  if (version != saveVersion) {
    issues.add(LoadIssue('save version $version, this build writes $saveVersion'));
  }

  final members = <Member>[];
  final rawMembers = json['members'];
  if (rawMembers is! List) {
    issues.add(const LoadIssue('no members in the save'));
  } else {
    for (final raw in rawMembers) {
      if (raw is! Map) {
        issues.add(const LoadIssue('a member entry was not an object'));
        continue;
      }
      members.add(_member(raw.cast<String, Object?>(), cat, issues));
    }
  }

  final packJson = json['pack'];
  final counts = <ItemRef, int>{};
  var capacity = 24;
  if (packJson is Map) {
    capacity = _int(packJson['capacity'], 24);
    final rawCounts = packJson['counts'];
    if (rawCounts is Map) {
      for (final e in rawCounts.entries) {
        final ref = ItemRef('${e.key}');
        if (!cat.contains(ref)) {
          issues.add(
            LoadIssue('the pack held an item this build has no row for',
                item: ref.value),
          );
          continue;
        }
        counts[ref] = _int(e.value, 0);
      }
    }
  }

  return LoadResult(
    World(
      members: members,
      pack: Pack(capacity: capacity, counts: counts),
      catalog: cat,
      magicLight: json['magicLight'] == true,
    ),
    issues,
  );
}

Member _member(
  Map<String, Object?> json,
  ItemCatalog catalog,
  List<LoadIssue> issues,
) {
  final ref = '${json['ref'] ?? ''}';
  final stats = json['stats'] is Map
      ? (json['stats']! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final levels = json['levels'] is Map
      ? (json['levels']! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final accuracy = json['accuracy'] is Map
      ? (json['accuracy']! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final base = json['base'] is Map
      ? (json['base']! as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final vitals = json['vitals'] is Map
      ? (json['vitals']! as Map).cast<String, Object?>()
      : const <String, Object?>{};

  final clazz = CharacterClass.fromWire(_int(json['class'], 0));
  if (clazz == null) {
    issues.add(LoadIssue('no class numbered ${json['class']}', member: ref));
  }
  final style = FightingStyle.fromWire(_int(json['style'], -1));

  final equipment = <EquipSlot, ItemRef>{};
  final rawEquipment = json['equipment'];
  if (rawEquipment is Map) {
    for (final e in rawEquipment.entries) {
      final slot = EquipSlot.fromWire(int.tryParse('${e.key}') ?? -1);
      if (slot == null) {
        issues.add(LoadIssue('no slot numbered ${e.key}', member: ref));
        continue;
      }
      final item = ItemRef('${e.value}');
      if (!catalog.contains(item)) {
        // Emptied, and said out loud. The predecessor folded an unknown
        // item into bare hands, which looked like nothing had happened.
        issues.add(
          LoadIssue(
            'this build has no row for what was worn; the slot is empty',
            member: ref,
            item: item.value,
          ),
        );
        continue;
      }
      equipment[slot] = item;
    }
  }

  final maxHitPoints = _int(base['maxHitPoints'], 0);
  return Member(
    ref: MemberRef(ref),
    name: '${json['name'] ?? ref}',
    clazz: clazz ?? CharacterClass.unknown,
    stats: BaseStats(
      strength: _int(stats['strength'], 0),
      mentality: _int(stats['mentality'], 0),
      concentration: _int(stats['concentration'], 0),
      endurance: _int(stats['endurance'], 0),
      resistance: _int(stats['resistance'], 0),
      agility: _int(stats['agility'], 0),
      luck: _int(stats['luck'], 0),
    ),
    levels: Levels(
      physical: _int(levels['physical'], 1),
      magic: _int(levels['magic'], 0),
      esp: _int(levels['esp'], 0),
    ),
    accuracy: Accuracy(
      physical: _int(accuracy['physical'], 0),
      magic: _int(accuracy['magic'], 0),
      esp: _int(accuracy['esp'], 0),
    ),
    baseMaxHitPoints: maxHitPoints,
    baseMaxSpellPoints: _int(base['maxSpellPoints'], 0),
    baseMaxEspPoints: _int(base['maxEspPoints'], 0),
    baseDefence: _int(base['defence'], 0),
    hitPoints: _int(vitals['hitPoints'], maxHitPoints),
    spellPoints: _int(vitals['spellPoints'], 0),
    espPoints: _int(vitals['espPoints'], 0),
    poison: _int(vitals['poison'], 0),
    unconscious: _int(vitals['unconscious'], 0),
    dead: _int(vitals['dead'], 0),
    experience: _int(json['experience'], 0),
    gender: _int(json['gender'], 0),
    style: style ?? FightingStyle.assault,
    thrift: json['thrift'] == true,
    equipment: equipment,
  );
}

int _int(Object? value, int fallback) => switch (value) {
  int() => value,
  num() => value.toInt(),
  String() => int.tryParse(value) ?? fallback,
  _ => fallback,
};
