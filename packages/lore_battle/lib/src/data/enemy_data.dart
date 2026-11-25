/// The single-target special attack an enemy may carry (ch.8.6).
///
/// [wire] is the number the original data uses, declared explicitly so
/// a script that sets the attribute by number keeps working. Never
/// `Enum.index`.
enum EnemySpecial {
  none(0),

  /// 독 — poisons someone who is not poisoned yet.
  poison(1),

  /// 치명타(기절) — puts someone out cold outright.
  knockOut(2),

  /// 죽음 — kills outright.
  slay(3);

  const EnemySpecial(this.wire);

  final int wire;

  /// Any number the original does not define is no special attack at
  /// all — Part 3's Orc Archmage carries a 4 and never uses one
  /// (ch.12.2).
  static EnemySpecial fromWire(int wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => none);
}

/// The supernatural abilities of Part 3's bosses (ch.8.6).
///
/// **Declaration order matters**: 탈 초인화 removes the lowest one first
/// (appendix A #2), and the random pick each turn indexes into the set
/// sorted this way.
enum EnemyAbility {
  /// 정신 지배 — takes the party's assistant member.
  mindControl,

  /// 갑옷 파괴 — lowers armour class for good.
  armourBreak,

  /// 동료 소환 — calls one more enemy in.
  summonAlly,

  /// 전체 중독.
  massPoison,

  /// 전체 기절.
  massStun,

  /// 전체 즉사.
  massDeath,

  /// 전체 회복 — heals, wakes and raises its own side, one stage each.
  healAll,

  /// 분신 — hides among copies of itself.
  clone,
}

/// One row of an enemy table. Immutable reference data.
///
/// **No name here.** A name is display text and the model carries none;
/// `lore_battle_text` holds one Korean table per episode, keyed the same
/// way.
class EnemyData {
  const EnemyData({
    required this.key,
    required this.legacyId,
    required this.level,
    required this.hp,
    required this.strength,
    required this.mentality,
    required this.endurance,
    required this.physicalResistance,
    required this.magicResistance,
    required this.agility,
    required this.accuracyPhysical,
    required this.accuracyMagic,
    required this.ac,
    this.special = EnemySpecial.none,
    this.castLevel = 0,
    this.abilities = const <EnemyAbility>{},
    this.superLevel = 0,
    this.persuadable = false,
    this.persuadeLevel,
    this.givesGold = true,
    this.endsTurnAfterHealAll = false,
    this.agedByCrystals = false,
  });

  /// Stable identity, unique **within its episode's table**. The same
  /// key in two episodes is two different creatures.
  final String key;

  /// The original number, 1-based as the design documents print it.
  final int legacyId;

  /// Drives damage, hit points, experience and gold.
  final int level;

  /// Starting hit points, as the episode's document lists them —
  /// `endurance × level × 10` in Parts 2 and 3, `endurance × level` in
  /// Part 1.
  final int hp;

  /// Weapon damage coefficient. **Zero means it never swings.**
  final int strength;

  /// Picks the spell it casts and scales how much it heals.
  final int mentality;

  /// Hit point coefficient.
  final int endurance;

  /// Percent chance to stop a weapon blow. 100 or more is immunity.
  final int physicalResistance;

  /// Percent chance to stop a spell or a special spell. Parts 1 and 2
  /// have one resistance column; both fields carry it.
  final int magicResistance;

  final int agility;

  /// 0..20-ish. The two accuracies are also weighed against each other
  /// to decide between weapon and magic.
  final int accuracyPhysical;
  final int accuracyMagic;

  /// Takes `ac × level × (1..10)` off every blow it receives.
  final int ac;

  final EnemySpecial special;

  /// 0..6 — the casting ladder (ch.8.6).
  final int castLevel;

  /// Part 3's supernatural abilities. Empty in Parts 1 and 2.
  final Set<EnemyAbility> abilities;

  /// Parts 1 and 2's "초자연 등급": 1 calls reinforcements, 2 also takes
  /// the assistant, 3 also casts death over the whole party. Zero in
  /// Part 3, which names its abilities one by one instead.
  final int superLevel;

  /// Whether 독심 can talk it round in battle.
  final bool persuadable;

  /// The level 독심 measures the caster against, when it is not [level].
  /// Draconian and the Warrior of the Southern Cross are judged as 17.
  final int? persuadeLevel;

  /// False for Part 3's 저승사자, which pays nothing (ch.8.8).
  final bool givesGold;

  /// The three support creatures that end their turn once they have
  /// healed their side (ch.8.6 step 2).
  final bool endsTurnAfterHealAll;

  /// 로드안 — the only thing the Dark and Ebony crystals react to.
  final bool agedByCrystals;
}
