/// The words the battle shares with the RPG side (`lore_world`).
///
/// Neither package imports the other — the bridge between them is what
/// knows both. These are the values that have to mean the same thing on
/// either side of it, so they are spelled out once and pinned by
/// `test/contract/vocabulary_test.dart`.
library;

/// The seat the assistant member (보조 일원) sits in.
///
/// Seats are 0..5: 0 the protagonist, 1..4 companions, 5 the assistant.
/// The assistant is **never asked for a command** — it attacks on its
/// own (ch.8.5) — and it is the seat a summon, a persuaded enemy or a
/// crystal creature lands in, replacing whoever sat there.
const int assistantSeat = 5;

/// How many enemies one battle holds. The original's enemy list is
/// eight lines (appendix E.2) and three rules read it: clones fill the
/// list to this, mind control needs a free line, and so does summoning.
const int maxEnemies = 8;

/// What a combatant is (ch.7.2).
///
/// The first two are the families a player character can belong to; the
/// rest only ever describe the assistant member, and decide whether its
/// automatic attack lands on one enemy or sweeps all of them.
enum Family { fighter, mage, elemental, giant, golem, dragon, unknown }

/// Class ids. **The two families number their classes separately**, so a
/// class id only means something next to a [Family] — 5 is a monk in
/// one and a necromancer in the other.
abstract final class ClassId {
  // Fighter family (전투사 계열).
  static const int fighter = 1; // 투사
  static const int knight = 2; // 기사
  static const int swordsman = 3; // 검사
  static const int hunter = 4; // 사냥꾼
  static const int monk = 5; // 전투승
  static const int assassin = 6; // 암살자
  static const int paladin = 7; // 전사

  // Mage family (마법사 계열).
  static const int mage = 1; // 메이지
  static const int conjurer = 2; // 컨져러
  static const int sorcerer = 3; // 주술사
  static const int wizard = 4; // 위저드
  static const int necromancer = 5; // 강령술사
  static const int archmage = 6; // 대마법사
  static const int timewalker = 7; // 타임워커

  // Part 1 only. Outside both families' 1..7.
  static const int esper = 8; // 에스퍼
  static const int demigod = 9; // 반신반인
}

/// Positions in the six-entry skill list. Like class ids, an index only
/// means something next to a [Family].
abstract final class SkillIndex {
  // Fighter family — weapon skills.
  static const int slash = 0; // 베는
  static const int chop = 1; // 찍는
  static const int pierce = 2; // 찌르는
  static const int shoot = 3; // 쏘는
  static const int shield = 4; // 방패
  static const int bare = 5; // 맨손

  /// A paladin (전사) cannot use chopping weapons; the slot holds the
  /// cure skill instead (ch.7.3).
  static const int paladinCure = 1;

  // Mage family — magic skills.
  static const int attack = 0; // 공격
  static const int change = 1; // 변화 — field only, the battle never reads it
  static const int cure = 2; // 치료
  static const int special = 3; // 특수
  static const int esp = 4; // 초자연
  static const int summon = 5; // 소환
}

/// Which weapon skill an attack is measured by (ch.8.5).
enum WeaponKind {
  bare,
  slash,
  chop,
  pierce,
  shoot,

  /// The assistant's natural weapons — flame, fangs, a breath.
  special,
}

/// Consumable keys. The setup's `consumables` map is keyed by these and
/// so is `BattleOutcome.consumedItems`.
abstract final class ItemKey {
  // Herbs and potions — items 1..5, the only ones a battle can use.
  static const String hpPotion = 'item.hp_potion';
  static const String mpPotion = 'item.mp_potion';
  static const String antidoteHerb = 'item.antidote_herb';
  static const String awakeningHerb = 'item.awakening_herb';
  static const String revivalHerb = 'item.revival_herb';

  // Crystals 1..7.
  static const String flameCrystal = 'crystal.flame';
  static const String frostCrystal = 'crystal.frost';
  static const String darkCrystal = 'crystal.dark';
  static const String ebonyCrystal = 'crystal.ebony';
  static const String spiritCrystal = 'crystal.spirit';
  static const String summonCrystal = 'crystal.summon';
  static const String energyCrystal = 'crystal.energy';
}
