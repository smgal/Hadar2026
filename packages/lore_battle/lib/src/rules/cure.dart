import 'attack_magic.dart' show tiersOpened;

/// Cure magic — ch.9.4.
///
/// Ten tiers: 1..5 on one member, 6..10 on everyone. Each is one of
/// four steps, and the fifth of each half runs all four.

/// The four things a cure can do.
enum CureStep {
  /// Restore hit points.
  heal,

  /// Clear poison.
  antidote,

  /// Bring someone round from unconsciousness.
  recoverConsciousness,

  /// Bring someone back from the dead — **unconscious, not standing**.
  revitalize,
}

/// Which steps a tier runs, in order.
///
/// | tier | spell | steps |
/// |---|---|---|
/// | 1 / 6 | 치료 | heal |
/// | 2 / 7 | 독 제거 | antidote |
/// | 3 / 8 | 의식 돌림 | recoverConsciousness |
/// | 4 / 9 | 부활 | revitalize |
/// | 5 / 10 | 복합 치료 | revitalize, recoverConsciousness, antidote, heal |
///
/// **The order of the fifth is load-bearing** — "치료는 깊은 곳부터"
/// (ch.7.7). Healing refuses a poisoned target and the antidote refuses
/// an unconscious one, so the composite only works because it starts at
/// the bottom.
List<CureStep> cureStepsForTier(int tier) => switch ((tier - 1) % 5) {
  0 => const [CureStep.heal],
  1 => const [CureStep.antidote],
  2 => const [CureStep.recoverConsciousness],
  3 => const [CureStep.revitalize],
  _ => const [
    CureStep.revitalize,
    CureStep.recoverConsciousness,
    CureStep.antidote,
    CureStep.heal,
  ],
};

/// Tiers 6..10 are cast on the whole party, the assistant included.
bool cureTierTargetsAll(int tier) => tier >= 6;

/// The tiers a cure skill opens.
///
/// With `L = skill ÷ 10`: the one-member cures are 1 to `min(L, 5)`,
/// and the party-wide ones are 6 to `L` — which is nothing at all until
/// `L` reaches 6.
List<int> castableCureTiers(int cureSkill) {
  final level = tiersOpened(cureSkill);
  return [
    for (var tier = 1; tier <= (level < 5 ? level : 5); tier++) tier,
    for (var tier = 6; tier <= level; tier++) tier,
  ];
}

/// What one cure step did.
class CureApplied {
  const CureApplied({
    required this.hp,
    required this.poison,
    required this.unconscious,
    required this.dead,
    required this.mpSpent,
    required this.amount,
    required this.step,
    required this.applied,
    this.shortOfMp = false,
  });

  final int hp;
  final int poison;
  final int unconscious;
  final int dead;

  /// Magic points the caster paid. Zero when nothing happened.
  final int mpSpent;

  /// Hit points restored, for [CureStep.heal]. Zero otherwise.
  final int amount;

  final CureStep step;

  /// False when the target did not need it, or the caster could not pay.
  final bool applied;

  /// Distinguishes "could not pay" from "was not needed".
  final bool shortOfMp;
}

/// Runs one step against one target.
///
/// | step | cost | refuses |
/// |---|---|---|
/// | heal | caster level × 2 | the poisoned, the unconscious, the dead, the unhurt |
/// | antidote | 15 | the unconscious, the dead |
/// | wake | 10 × the target's unconscious counter | the dead |
/// | revive | 30 × the target's death counter | the living |
///
/// Healing restores `caster level × 20`. Reviving leaves the target
/// unconscious, with the counter pulled into `1..deathThreshold` so they
/// do not die again at once.
///
/// [free] is for the herbs: same steps, nothing paid (ch.10.5).
CureApplied applyCureStep(
  CureStep step, {
  required int hp,
  required int maxHp,
  required int poison,
  required int unconscious,
  required int dead,
  required int deathThreshold,
  required int casterMp,
  required int casterLevel,
  bool free = false,
}) {
  CureApplied unchanged({bool shortOfMp = false}) => CureApplied(
    hp: hp,
    poison: poison,
    unconscious: unconscious,
    dead: dead,
    mpSpent: 0,
    amount: 0,
    step: step,
    applied: false,
    shortOfMp: shortOfMp,
  );

  switch (step) {
    case CureStep.heal:
      if (dead > 0 || unconscious > 0 || poison > 0) return unchanged();
      if (hp >= maxHp) return unchanged();
      final cost = free ? 0 : casterLevel * 2;
      if (casterMp < cost) return unchanged(shortOfMp: true);
      final restored = casterLevel * 20;
      if (restored <= 0) return unchanged();
      final next = hp + restored > maxHp ? maxHp : hp + restored;
      return CureApplied(
        hp: next,
        poison: poison,
        unconscious: unconscious,
        dead: dead,
        mpSpent: cost,
        amount: next - hp,
        step: step,
        applied: true,
      );

    case CureStep.antidote:
      if (dead > 0 || unconscious > 0) return unchanged();
      if (poison == 0) return unchanged();
      final cost = free ? 0 : 15;
      if (casterMp < cost) return unchanged(shortOfMp: true);
      return CureApplied(
        hp: hp,
        poison: 0,
        unconscious: unconscious,
        dead: dead,
        mpSpent: cost,
        amount: 0,
        step: step,
        applied: true,
      );

    case CureStep.recoverConsciousness:
      if (dead > 0) return unchanged();
      if (unconscious == 0) return unchanged();
      final cost = free ? 0 : 10 * unconscious;
      if (casterMp < cost) return unchanged(shortOfMp: true);
      return CureApplied(
        hp: hp <= 0 ? 1 : hp,
        poison: poison,
        unconscious: 0,
        dead: dead,
        mpSpent: cost,
        amount: 0,
        step: step,
        applied: true,
      );

    case CureStep.revitalize:
      if (dead == 0) return unchanged();
      final cost = free ? 0 : 30 * dead;
      if (casterMp < cost) return unchanged(shortOfMp: true);
      var woken = unconscious > deathThreshold ? deathThreshold : unconscious;
      if (woken < 1) woken = 1;
      return CureApplied(
        hp: hp,
        poison: poison,
        unconscious: woken,
        dead: 0,
        mpSpent: cost,
        amount: 0,
        step: step,
        applied: true,
      );
  }
}

/// Applies a whole cure tier to one target, running its steps in order
/// and paying for each as it goes.
({
  int hp,
  int poison,
  int unconscious,
  int dead,
  int mpSpent,
  List<CureApplied> steps,
})
applyCure(
  int tier, {
  required int hp,
  required int maxHp,
  required int poison,
  required int unconscious,
  required int dead,
  required int deathThreshold,
  required int casterMp,
  required int casterLevel,
}) {
  var curHp = hp;
  var curPoison = poison;
  var curUnconscious = unconscious;
  var curDead = dead;
  var mp = casterMp;
  var spent = 0;
  final outcomes = <CureApplied>[];

  for (final step in cureStepsForTier(tier)) {
    final result = applyCureStep(
      step,
      hp: curHp,
      maxHp: maxHp,
      poison: curPoison,
      unconscious: curUnconscious,
      dead: curDead,
      deathThreshold: deathThreshold,
      casterMp: mp,
      casterLevel: casterLevel,
    );
    curHp = result.hp;
    curPoison = result.poison;
    curUnconscious = result.unconscious;
    curDead = result.dead;
    mp -= result.mpSpent;
    spent += result.mpSpent;
    outcomes.add(result);
  }

  return (
    hp: curHp,
    poison: curPoison,
    unconscious: curUnconscious,
    dead: curDead,
    mpSpent: spent,
    steps: outcomes,
  );
}

/// The death counter past which the revival herb no longer works
/// (ch.10.5).
const int revivalHerbDeadLimit = 10000;
