import 'wire.dart';

/// A number an item is allowed to move.
///
/// ## Why this is a closed list
///
/// Rules switch on these, so the set has to be knowable at compile
/// time — a modifier naming a stat no rule reads is the `powOfShield`
/// mistake again, a field written by content and read by nothing.
/// Adding a key means adding the rule that honours it, in the same
/// change. That is the point.
enum StatKey implements Wired {
  maxHitPoints(0),
  maxSpellPoints(1),
  maxEspPoints(2),

  /// Worn protection, before the shield's own roll.
  defence(3),

  accuracyPhysical(4),
  accuracyMagic(5),
  accuracyEsp(6),

  /// Chance to turn a blow aside entirely.
  evasion(7),

  /// How early in a round this member acts.
  initiative(8),

  strength(9),
  mentality(10),
  concentration(11),
  endurance(12),
  resistance(13),
  agility(14),
  luck(15),

  /// Percentage of a blow that the shield stops.
  shieldBlock(16),

  /// How many coatings the weapon holds at once.
  coatingSlots(17),

  /// Cost taken off a spell.
  spellCostRelief(18),

  /// Cost taken off an esp ability.
  espCostRelief(19);

  const StatKey(this.wire);

  @override
  final int wire;

  static StatKey? fromWire(int wire) => byWire(values, wire);
}

/// How a modifier combines with what is already there.
enum ModifierOp implements Wired {
  /// Added to the running total.
  add(0),

  /// A percentage of the base, added after every [add] has landed.
  ///
  /// Percentages read off the **base**, never off each other, so two
  /// amulets of ten percent give twenty and not twenty-one. Order of
  /// equipping can then never change the answer, which is the whole
  /// reason for the rule.
  percent(1);

  const ModifierOp(this.wire);

  @override
  final int wire;

  static ModifierOp? fromWire(int wire) => byWire(values, wire);
}

/// One statement of the form "this stat, this way, this much".
class Modifier {
  const Modifier(this.stat, this.op, this.value);

  const Modifier.add(this.stat, this.value) : op = ModifierOp.add;

  const Modifier.percent(this.stat, this.value) : op = ModifierOp.percent;

  final StatKey stat;
  final ModifierOp op;
  final int value;

  @override
  String toString() => 'Modifier(${stat.name}, ${op.name}, $value)';
}

/// Something a status effect cannot do to the wearer.
enum Ailment implements Wired {
  poison(0),
  paralysis(1),

  /// Mind and esp attacks.
  mind(2),

  /// Being struck senseless.
  stun(3),

  /// Being killed outright.
  deathTouch(4);

  const Ailment(this.wire);

  @override
  final int wire;

  static Ailment? fromWire(int wire) => byWire(values, wire);
}
