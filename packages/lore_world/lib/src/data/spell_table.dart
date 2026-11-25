import '../domain/enums.dart';

/// 마법의 갈래(제9장 9.1).
enum SpellSchool {
  /// 1명 공격 마법.
  attackOne,

  /// 전체 공격 마법.
  attackAll,

  /// 변화 마법 — 필드.
  change,

  /// 치료 마법 — 필드·전투.
  cure,

  /// 특수 마법 — 전투.
  special,

  /// 소환 마법 — 전투.
  summon,

  /// 초자연력.
  esp,
}

/// 마법·초능력 하나. 이름과 해금 기준과 소모량이 **자료**다.
///
/// 전투 마법의 효과는 다른 패키지가 굴린다. 여기는 누가 무엇을 언제부터
/// 얼마에 쓸 수 있는지만 갖는다.
final class SpellDef {
  const SpellDef(
    this.key,
    this.school,
    this.tier,
    this.unlock, {
    this.mp,
    this.battleMp,
    this.field = false,
    this.battle = false,
    this.onlyIn,
  });

  final String key;
  final SpellSchool school;

  /// 단계(1~10). 초능력은 0.
  final int tier;

  /// 이 능력치부터 쓸 수 있다.
  final int unlock;

  /// 고정 소모량. 공식으로 정해지면 null([attackMagicMp] · [cureMagicMp] …).
  final int? mp;

  /// 전투에서의 소모량이 필드와 다르면 그 값(독심 20 → 15).
  final int? battleMp;

  final bool field;
  final bool battle;

  /// 이 편에만 있는 마법이면 그 편.
  final Episode? onlyIn;
}

const SpellSchool _one = SpellSchool.attackOne;
const SpellSchool _all = SpellSchool.attackAll;
const SpellSchool _chg = SpellSchool.change;
const SpellSchool _cur = SpellSchool.cure;
const SpellSchool _spc = SpellSchool.special;
const SpellSchool _sum = SpellSchool.summon;
const SpellSchool _esp = SpellSchool.esp;

const List<SpellDef> spellTable = [
  // ── 1명 공격 (소모 = 능력치 × j² ÷ 10) ──
  SpellDef('magic.magic_arrow', _one, 1, 10, battle: true),
  SpellDef('magic.fireball', _one, 2, 20, battle: true),
  SpellDef('magic.magic_spear', _one, 3, 30, battle: true),
  SpellDef('magic.poison_needle', _one, 4, 40, battle: true),
  SpellDef('magic.ignition', _one, 5, 50, battle: true),
  SpellDef('magic.freezing_ray', _one, 6, 60, battle: true),
  SpellDef('magic.dancing_sword', _one, 7, 70, battle: true),
  SpellDef('magic.pulse_ray', _one, 8, 80, battle: true),
  SpellDef('magic.lightning_strike', _one, 9, 90, battle: true),
  SpellDef('magic.doom', _one, 10, 100, battle: true),
  // ── 전체 공격 (적마다 소모) ──
  SpellDef('magic.air_storm', _all, 1, 10, battle: true),
  SpellDef('magic.heat_wave', _all, 2, 20, battle: true),
  SpellDef('magic.ultrasound', _all, 3, 30, battle: true),
  SpellDef('magic.toxic_gas', _all, 4, 40, battle: true),
  SpellDef('magic.deep_freeze', _all, 5, 50, battle: true),
  SpellDef('magic.flame_field', _all, 6, 60, battle: true),
  SpellDef('magic.blizzard', _all, 7, 70, battle: true),
  SpellDef('magic.energy_curtain', _all, 8, 80, battle: true),
  SpellDef('magic.earthquake', _all, 9, 90, battle: true),
  SpellDef('magic.dimension_shift', _all, 10, 100, battle: true),
  // ── 변화 (필드) ──
  SpellDef('magic.magic_torch', _chg, 1, 10, mp: 1, field: true),
  SpellDef('magic.beholder_eye', _chg, 2, 20, mp: 5, field: true),
  SpellDef('magic.levitation', _chg, 3, 30, mp: 5, field: true),
  SpellDef('magic.water_walk', _chg, 4, 40, mp: 10, field: true),
  SpellDef('magic.swamp_walk', _chg, 5, 50, mp: 20, field: true),
  SpellDef('magic.ethereal_move', _chg, 6, 60, mp: 25, field: true),
  SpellDef('magic.terraform', _chg, 7, 70, mp: 30, field: true),
  SpellDef('magic.teleport', _chg, 8, 80, mp: 50, field: true),
  SpellDef('magic.create_food', _chg, 9, 90, mp: 30, field: true),
  SpellDef('magic.great_terraform', _chg, 10, 100, mp: 60, field: true),
  // ── 치료 (소모는 시전자·대상에 달렸다) ──
  SpellDef('magic.heal_one', _cur, 1, 10, field: true, battle: true),
  SpellDef(
    'magic.antidote_one',
    _cur,
    2,
    20,
    mp: 15,
    field: true,
    battle: true,
  ),
  SpellDef('magic.awaken_one', _cur, 3, 30, field: true, battle: true),
  SpellDef('magic.revive_one', _cur, 4, 40, field: true, battle: true),
  SpellDef('magic.full_cure_one', _cur, 5, 50, field: true, battle: true),
  SpellDef('magic.heal_all', _cur, 6, 60, field: true, battle: true),
  SpellDef(
    'magic.antidote_all',
    _cur,
    7,
    70,
    mp: 15,
    field: true,
    battle: true,
  ),
  SpellDef('magic.awaken_all', _cur, 8, 80, field: true, battle: true),
  SpellDef('magic.revive_all', _cur, 9, 90, field: true, battle: true),
  SpellDef('magic.full_cure_all', _cur, 10, 100, field: true, battle: true),
  // ── 특수 (전투) ──
  SpellDef('magic.disable_skill_one', _spc, 1, 10, mp: 200, battle: true),
  SpellDef('magic.disable_defence_one', _spc, 2, 20, mp: 50, battle: true),
  SpellDef('magic.weaken_one', _spc, 3, 30, mp: 100, battle: true),
  SpellDef('magic.silence_one', _spc, 4, 40, mp: 150, battle: true),
  SpellDef('magic.demote_one', _spc, 5, 50, mp: 400, battle: true),
  SpellDef('magic.disable_skill_all', _spc, 6, 60, mp: 200, battle: true),
  SpellDef('magic.disable_defence_all', _spc, 7, 70, mp: 50, battle: true),
  SpellDef('magic.weaken_all', _spc, 8, 80, mp: 100, battle: true),
  SpellDef('magic.silence_all', _spc, 9, 90, mp: 150, battle: true),
  SpellDef('magic.demote_all', _spc, 10, 100, mp: 400, battle: true),
  // 제1부 전용 특수 마법 「독」. 원작 그대로 두기로 했고, 기획서에 해금
  // 기준과 소모량이 없다 — 이름만 싣는다.
  SpellDef('magic.poison', _spc, 0, 0, battle: true, onlyIn: Episode.ep1),
  // ── 소환 (전투, 소모 = 능력치 × j² ÷ 10 — 부록 A D1 의 제안) ──
  SpellDef('magic.summon_fire', _sum, 1, 10, battle: true),
  SpellDef('magic.summon_water', _sum, 2, 20, battle: true),
  SpellDef('magic.summon_air', _sum, 3, 30, battle: true),
  SpellDef('magic.summon_earth', _sum, 4, 40, battle: true),
  SpellDef('magic.raise_dead', _sum, 5, 50, battle: true),
  SpellDef('magic.summon_other_dimension', _sum, 6, 60, battle: true),
  SpellDef('magic.summon_giant', _sum, 7, 70, battle: true),
  SpellDef('magic.summon_golem', _sum, 8, 80, battle: true),
  SpellDef('magic.summon_dragon', _sum, 9, 90, battle: true),
  SpellDef('magic.summon_lycanthrope', _sum, 10, 100, battle: true),
  // ── 초자연력 ──
  SpellDef('esp.clairvoyance', _esp, 0, 70, mp: 10, field: true),
  SpellDef('esp.prophecy', _esp, 0, 10, mp: 5, field: true),
  SpellDef(
    'esp.mind_reading',
    _esp,
    0,
    40,
    mp: 20,
    battleMp: 15,
    field: true,
    battle: true,
  ),
  // 천리안의 소모량은 레벨 × 5 다.
  SpellDef('esp.far_sight', _esp, 0, 55, field: true),
  SpellDef('esp.hydrogen_fusion', _esp, 0, 20, mp: 100, battle: true),
  SpellDef('esp.fear', _esp, 0, 30, mp: 100, battle: true),
  SpellDef('esp.illusion', _esp, 0, 80, mp: 300, battle: true),
  SpellDef('esp.metabolism', _esp, 0, 90, mp: 500, battle: true),
  SpellDef('esp.astral_projection', _esp, 0, 100, mp: 1000, battle: true),
];

SpellDef? spellByKey(String key) {
  for (final s in spellTable) {
    if (s.key == key) return s;
  }
  return null;
}

/// 그 갈래의 n 단계 마법. 없으면 null.
SpellDef? spellAt(SpellSchool school, int tier) {
  for (final s in spellTable) {
    if (s.school == school && s.tier == tier && tier > 0) return s;
  }
  return null;
}

/// 그 갈래의 마법 전부(단계 순).
List<SpellDef> spellsOf(SpellSchool school) => [
  for (final s in spellTable)
    if (s.school == school) s,
];

/// 능력치로 쓸 수 있는 단계 수(0~10). 10 마다 한 단계.
int unlockedTiers(int skill) {
  final tiers = skill ~/ 10;
  if (tiers < 0) return 0;
  return tiers > 10 ? 10 : tiers;
}

/// 공격 마법의 소모량 = 능력치 × j² ÷ 10 (반올림).
int attackMagicMp(int skill, int tier) => (skill * tier * tier + 5) ~/ 10;

/// 공격 마법의 피해 = j² × 능력치 × 3.
int attackMagicDamage(int skill, int tier) => tier * tier * skill * 3;

/// 소환 마법의 소모량. 원작에는 소모가 없어 무한히 부를 수 있었다 —
/// 공격 마법과 같은 식을 쓴다(부록 A D1 의 제안).
int summonMagicMp(int skill, int tier) => attackMagicMp(skill, tier);

/// 소환수의 레벨 = 소환 마법 능력치 ÷ 5.
int summonLevel(int skill) {
  final level = skill ~/ 5;
  return level < 1 ? 1 : level;
}

/// 염력 하위 메뉴에서 고를 수 있는 개수.
int telekinesisChoices(int esp) {
  if (esp >= 100) return 5;
  if (esp >= 90) return 4;
  if (esp >= 80) return 3;
  if (esp >= 30) return 2;
  if (esp >= 20) return 1;
  return 0;
}

/// 필드 초능력의 열쇠.
String fieldEspKey(FieldEsp power) => switch (power) {
  FieldEsp.clairvoyance => 'esp.clairvoyance',
  FieldEsp.prophecy => 'esp.prophecy',
  FieldEsp.mindReading => 'esp.mind_reading',
  FieldEsp.farSight => 'esp.far_sight',
  FieldEsp.telekinesis => 'esp.telekinesis',
};
