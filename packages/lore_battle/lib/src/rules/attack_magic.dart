import 'affinity.dart';
import 'rng.dart';

/// Attack magic — ch.8.5 and ch.9.2.
///
/// Ten tiers for one enemy and ten for all of them, on one curve. A
/// caster with attack skill `A` has tiers 1 to `A ÷ 10`; tier `j` costs
/// `A × j² ÷ 10` and hits for `j² × A × 3`.
///
/// So within the list the last tier hits a hundred times as hard as the
/// first and costs a hundred times as much, and **a stronger caster
/// pays more for the same tier** — the skill is in both formulas.

/// The highest tier a skill value opens, 0..10.
int tiersOpened(int skill) {
  final tiers = skill ~/ 10;
  return tiers < 0 ? 0 : (tiers > 10 ? 10 : tiers);
}

/// `skill × tier² ÷ 10`, rounded — the document's "(반올림)".
int attackMagicCost({required int skill, required int tier}) =>
    (skill * tier * tier + 5) ~/ 10;

/// `tier² × skill × 3`.
int attackMagicDamage({required int skill, required int tier}) =>
    tier * tier * skill * 3;

/// `rand(20) >= accuracy` misses — `>=`, where a weapon blow uses `>`.
bool magicAttackMisses({required int accuracy, required BattleRng rng}) =>
    rng.next(20) >= accuracy;

/// `rand(100) < magic resistance` stops the spell outright.
bool enemyResistsMagic({
  required int magicResistance,
  required BattleRng rng,
}) => rng.next(100) < magicResistance;

/// The element a tier goes through the affinity chart with.
///
/// The documents say every attack spell is pure damage (ch.9.2), and it
/// is — this only feeds the inherited affinity layer. Read off the
/// spell's name, and only where the name is unambiguous: 마법 화살 is an
/// arrow of nothing in particular, 냉동 광선 plainly is not.
Element attackMagicElement({required int tier, required bool area}) =>
    (area ? _areaElements : _singleElements)[tier] ?? Element.none;

const Map<int, Element> _singleElements = {
  2: Element.fire, // 마법 화구
  4: Element.poison, // 독 바늘
  5: Element.fire, // 마법 발화
  6: Element.ice, // 냉동 광선
  8: Element.lightning, // 맥동 광선
  9: Element.lightning, // 직격 뇌전
};

const Map<int, Element> _areaElements = {
  1: Element.force, // 공기 폭풍
  2: Element.fire, // 열선 파동
  3: Element.force, // 초음파
  4: Element.poison, // 유독 가스
  5: Element.ice, // 초냉기
  6: Element.fire, // 화염 지대
  7: Element.ice, // 브리자드
  9: Element.force, // 인공 지진
};
