import 'package:hd_world/hd_world.dart';

import 'legacy_item.dart';

/// What happened when a script wrote an attribute.
///
/// ## Nothing is silently ignored
///
/// The predecessor's `changeAttribute` ended in a `default:` that fell
/// through, so a misspelled name did nothing and said nothing. Three of
/// its cases were worse than that: they accepted a write to a field no
/// rule ever read.
///
/// So every write comes back with a verdict, and the two failure kinds
/// are told apart — a name this build does not know is a content bug, a
/// name that exists but no longer decides anything is a design change
/// the content has not caught up with.
enum AttributeVerdict {
  /// Applied.
  applied,

  /// The name is real, but the value is now derived from equipment, so
  /// honouring the write would put two answers in the world.
  derived,

  /// The name was real once and nothing reads it any more.
  dead,

  /// No such attribute. A content bug.
  unknown,
}

class AttributeResult {
  const AttributeResult(this.verdict, {this.detail = ''});

  final AttributeVerdict verdict;

  /// What to say about it. English, like everything in these packages —
  /// this reaches a developer log, not a player.
  final String detail;

  bool get changed => verdict == AttributeVerdict.applied;
}

/// The attribute names shipped scripts actually write.
///
/// Measured rather than guessed: `Player::ChangeAttribute` appears 75
/// times across the shipped scripts and touches these names. The set is
/// closed on purpose — a name outside it is [AttributeVerdict.unknown].
const Set<String> knownAttributes = {
  'max_hp',
  'max_sp',
  'max_esp',
  'hp',
  'sp',
  'esp',
  'experience',
  'strength',
  'mentality',
  'concentration',
  'endurance',
  'resistance',
  'agility',
  'luck',
  'weapon',
  'shield',
  'armor',
  'pow_of_weapon',
  'pow_of_shield',
  'pow_of_armor',
  'ac',
  'level',
  'level(magic)',
  'level(esp)',
  'accuracy',
  'accuracy(magic)',
  'accuracy(esp)',
  'name',
  'class',
  'poison',
  'unconscious',
  'dead',
};

/// Names that exist but no longer decide anything, and why.
///
/// Keeping them answerable is the point: a script that writes one gets
/// told, instead of getting silence and a wrong assumption.
const Map<String, String> retiredAttributes = {
  'pow_of_weapon':
      'derived from the main hand. Equip an item instead of writing this.',
  'pow_of_shield':
      'nothing has ever read it; defence comes from worn armour and the '
      'shield block chance.',
  'pow_of_armor':
      'nothing has ever read it; defence comes from worn armour and the '
      'shield block chance.',
  'ac': 'derived from what is worn on the four body slots and the shield.',
  'max_hp': 'derived from the base maximum plus what is worn.',
  'max_sp': 'derived from the base maximum plus what is worn.',
  'max_esp': 'derived from the base maximum plus what is worn.',
};

/// Writes one attribute, the way a script asks for it.
///
/// [equip] is called for the three equipment integers, because putting
/// something on is a command and this function must not reach into the
/// world itself. It returns whether the slot took it.
AttributeResult writeAttribute(
  Member member,
  String attribute,
  Object? value, {
  bool Function(EquipSlot slot, int legacyIndex)? equip,
}) {
  if (!knownAttributes.contains(attribute)) {
    return AttributeResult(
      AttributeVerdict.unknown,
      detail: 'no such attribute',
    );
  }
  if (attribute == 'name') {
    if (value is! String) {
      return const AttributeResult(
        AttributeVerdict.unknown,
        detail: 'name takes a string',
      );
    }
    member.name = value;
    return const AttributeResult(AttributeVerdict.applied);
  }

  final retired = retiredAttributes[attribute];
  if (retired != null) {
    return AttributeResult(
      attribute.startsWith('pow_of') && attribute != 'pow_of_weapon'
          ? AttributeVerdict.dead
          : AttributeVerdict.derived,
      detail: retired,
    );
  }

  final number = switch (value) {
    int() => value,
    num() => value.toInt(),
    _ => null,
  };
  if (number == null) {
    return const AttributeResult(
      AttributeVerdict.unknown,
      detail: 'expected a number',
    );
  }

  switch (attribute) {
    case 'hp':
      member.hitPoints = number;
    case 'sp':
      member.spellPoints = number;
    case 'esp':
      member.espPoints = number;
    case 'experience':
      member.experience = number;
    case 'strength':
      member.stats = member.stats.copyWith(strength: number);
    case 'mentality':
      member.stats = member.stats.copyWith(mentality: number);
    case 'concentration':
      member.stats = member.stats.copyWith(concentration: number);
    case 'endurance':
      member.stats = member.stats.copyWith(endurance: number);
    case 'resistance':
      member.stats = member.stats.copyWith(resistance: number);
    case 'agility':
      member.stats = member.stats.copyWith(agility: number);
    case 'luck':
      member.stats = member.stats.copyWith(luck: number);
    case 'level':
      member.levels = member.levels.copyWith(physical: number);
    case 'level(magic)':
      member.levels = member.levels.copyWith(magic: number);
    case 'level(esp)':
      member.levels = member.levels.copyWith(esp: number);
    case 'accuracy':
      member.accuracy = Accuracy(
        physical: number,
        magic: member.accuracy.magic,
        esp: member.accuracy.esp,
      );
    case 'accuracy(magic)':
      member.accuracy = Accuracy(
        physical: member.accuracy.physical,
        magic: number,
        esp: member.accuracy.esp,
      );
    case 'accuracy(esp)':
      member.accuracy = Accuracy(
        physical: member.accuracy.physical,
        magic: member.accuracy.magic,
        esp: number,
      );
    case 'class':
      final clazz = CharacterClass.fromWire(number);
      if (clazz == null) {
        return AttributeResult(
          AttributeVerdict.unknown,
          detail: 'no class numbered $number',
        );
      }
      member.clazz = clazz;
    // The conditions belong to the party, not to the fight: poison
    // decays with rest and a dead member stays dead between battles.
    // The battle borrows them and hands them back.
    case 'poison':
      member.poison = number;
    case 'unconscious':
      member.unconscious = number;
    case 'dead':
      member.dead = number;
    case 'weapon':
    case 'shield':
    case 'armor':
      final slot = switch (attribute) {
        'weapon' => EquipSlot.rightHand,
        'shield' => EquipSlot.leftHand,
        _ => EquipSlot.body,
      };
      if (equip == null) {
        return const AttributeResult(
          AttributeVerdict.unknown,
          detail: 'equipping needs a world; pass equip:',
        );
      }
      return equip(slot, number)
          ? const AttributeResult(AttributeVerdict.applied)
          : const AttributeResult(
              AttributeVerdict.dead,
              detail: 'the slot refused it',
            );
  }
  return const AttributeResult(AttributeVerdict.applied);
}

/// Reads one attribute, resolved the way the rules see it.
///
/// Null for a name this build does not know — the caller reports it
/// rather than getting a zero that mis-branches, which is exactly how
/// the old scripting layer went wrong.
///
/// `Object?` rather than `int?` because `name` is a real attribute and
/// it is a string. A script asking for it gets the string; every other
/// name answers with a number.
Object? readAttribute(
  Member member,
  String attribute, {
  required ItemCatalog catalog,
}) {
  final stats = resolveStats(member: member, catalog: catalog);
  return switch (attribute) {
    'name' => member.name,
    // The three equipment integers answer with the position a script
    // would recognise, or zero for a slot holding something this build
    // invented — a new amulet has no number and never had one.
    //
    // **The weapon integer is its own space.** A script's `weapon 4`
    // means the fourth name on the original's ten-name ladder, not the
    // fourth cutting weapon — the two spaces only coincide for shields
    // and armour, which the original numbered 0..5 in both.
    'weapon' => _ladderIndex(member),
    'shield' => _legacyEquipIndex(member, EquipSlot.leftHand, catalog),
    'armor' => _legacyEquipIndex(member, EquipSlot.body, catalog),
    'max_hp' => stats[StatKey.maxHitPoints],
    'max_sp' => stats[StatKey.maxSpellPoints],
    'max_esp' => stats[StatKey.maxEspPoints],
    'hp' => member.hitPoints,
    'sp' => member.spellPoints,
    'esp' => member.espPoints,
    'strength' => stats[StatKey.strength],
    'mentality' => stats[StatKey.mentality],
    'concentration' => stats[StatKey.concentration],
    'endurance' => stats[StatKey.endurance],
    'resistance' => stats[StatKey.resistance],
    'agility' => stats[StatKey.agility],
    'luck' => stats[StatKey.luck],
    'ac' => stats[StatKey.defence],
    'pow_of_weapon' => stats.attackPower,
    'level' => member.levels.physical,
    'level(magic)' => member.levels.magic,
    'level(esp)' => member.levels.esp,
    'accuracy' => stats[StatKey.accuracyPhysical],
    'accuracy(magic)' => stats[StatKey.accuracyMagic],
    'accuracy(esp)' => stats[StatKey.accuracyEsp],
    'class' => member.clazz.wire,
    // Zero rather than null for the two retired fields: the name is
    // real, so the caller is not looking at a typo.
    'poison' => member.poison,
    'unconscious' => member.unconscious,
    'dead' => member.dead,
    'experience' => member.experience,
    'pow_of_shield' || 'pow_of_armor' => 0,
    _ => null,
  };
}

int _ladderIndex(Member m) {
  final ref = m.at(EquipSlot.rightHand);
  if (ref == null) return 0;
  final index = legacyWeaponLadder.indexOf(ref.value);
  return index < 0 ? 0 : index;
}

int _legacyEquipIndex(Member m, EquipSlot slot, ItemCatalog catalog) {
  final ref = m.at(slot);
  if (ref == null) return 0;
  final index = catalog[ref]?.legacyIndex ?? -1;
  return index < 0 ? 0 : index;
}
