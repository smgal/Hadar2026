import 'package:hd_world/hd_world.dart';

import 'party.dart';

/// 한 사람을 쉬게 한 결과. 문구는 규칙이 정하지 않는다 — 분류만 한다.
enum RestOutcome {
  /// 식량이 없다. 아무도 쉬지 못한다.
  noFood,

  /// 죽었다. 쉬어도 돌아오지 않는다.
  alreadyDead,

  /// 기절해 있었고(독은 없었고) 이번에 깨어났다.
  unconsciousRecovered,

  /// 기절해 있고 아직 덜 쉬었다.
  unconsciousStillOut,

  /// 기절 + 중독. 독이 회복을 막는다.
  unconsciousPoisoned,

  /// 깨어 있으나 중독. 독이 치유를 막는다.
  poisoned,

  /// 최대치까지 나았다.
  fullyHealed,

  /// 올랐으나 최대치는 아니다.
  partiallyHealed,
}

class RestEntryResult {
  const RestEntryResult(this.member, this.outcome);

  final Member member;
  final RestOutcome outcome;
}

/// 「여기서 쉰다」의 규칙.
///
/// 원작 그대로다 — 식량이 없으면 아무 회복도 없고, 죽은 사람은 돌아오지 않고,
/// 독은 의식 회복과 체력 회복을 둘 다 막고, 기절은 세 레벨의 합만큼 줄고,
/// 깨어 있으면 그 합의 두 배만큼 낫는다.
///
/// ## 최대치를 두 번 계산하지 않는다
///
/// 이전 모델은 회복 상한을 `endurance × level.physical` 로 따로 계산하면서
/// `maxHp` 필드도 따로 들고 있었다 — 두 값이 갈릴 수 있었다. 지금은
/// [MemberDisplay.maxHitPoints] 가 장비까지 반영한 하나의 답을 준다.
class HDPartyActions {
  const HDPartyActions._();

  /// 한 사람에게 규칙을 적용하고 분류를 돌려준다.
  static RestEntryResult restMember(Member m, HDParty party) {
    final resolved = resolveStats(member: m, catalog: party.catalog);
    final maxHitPoints = resolved[StatKey.maxHitPoints];
    final levelSum = m.levels.physical + m.levels.magic + m.levels.esp;
    RestOutcome outcome;

    if (party.food <= 0) {
      outcome = RestOutcome.noFood;
    } else if (m.dead > 0) {
      outcome = RestOutcome.alreadyDead;
    } else if (m.unconscious > 0 && m.poison == 0) {
      m.unconscious -= levelSum;
      if (m.unconscious <= 0) {
        m.unconscious = 0;
        if (m.hitPoints <= 0) m.hitPoints = 1;
        party.food--;
        outcome = RestOutcome.unconsciousRecovered;
      } else {
        outcome = RestOutcome.unconsciousStillOut;
      }
    } else if (m.unconscious > 0 && m.poison > 0) {
      outcome = RestOutcome.unconsciousPoisoned;
    } else if (m.poison > 0) {
      outcome = RestOutcome.poisoned;
    } else {
      // 원작의 회복 상한은 `endurance × 물리 레벨` 이고 최대 체력과 별개였다.
      // 둘을 하나로 합친다 — 갈릴 수 있는 두 값을 두지 않는다.
      final cap = maxHitPoints;
      final wasFull = m.hitPoints >= cap;
      m.hitPoints += levelSum * 2;
      if (m.hitPoints >= cap) {
        m.hitPoints = cap;
        outcome = RestOutcome.fullyHealed;
      } else {
        outcome = RestOutcome.partiallyHealed;
      }
      if (!wasFull) party.food--;
    }

    // 어느 갈래든 마법·초능력 지수는 다시 찬다.
    m.spellPoints = m.stats.mentality * m.levels.magic;
    m.espPoints = m.stats.concentration * m.levels.esp;
    final maxSpell = resolved[StatKey.maxSpellPoints];
    final maxEsp = resolved[StatKey.maxEspPoints];
    if (m.spellPoints > maxSpell) m.spellPoints = maxSpell;
    if (m.espPoints > maxEsp) m.espPoints = maxEsp;
    if (m.hitPoints > maxHitPoints) m.hitPoints = maxHitPoints;

    return RestEntryResult(m, outcome);
  }

  /// 쉰 뒤 마법 잔량을 정리한다.
  ///
  /// **장비로 얻은 것은 줄지 않는다** — 부적은 쉬어도 그대로다(BP-47 §7.2).
  /// 줄어드는 것은 마법 쪽 잔량뿐이다.
  static void applyRestHousekeeping(HDParty party) {
    if (party.magicTorch > 0) party.magicTorch--;
    party.levitation = 0;
    party.walkOnWater = 0;
    party.walkOnSwamp = 0;
    party.mindControl = 0;
  }

  /// 두 자리를 맞바꾼다. 번호는 자리이므로 바뀌는 것은 앉은 사람뿐이다.
  static void swapMembers(HDParty party, int srcIdx, int destIdx) {
    final members = party.members;
    if (srcIdx < 0 ||
        destIdx < 0 ||
        srcIdx >= members.length ||
        destIdx >= members.length ||
        srcIdx == destIdx) {
      return;
    }
    final order = [for (final m in members) m.ref];
    final tmp = order[srcIdx];
    order[srcIdx] = order[destIdx];
    order[destIdx] = tmp;
    party.world.apply(ReorderParty(order: order));
    party.notifyListeners();
  }

  /// 사람을 내보낸다.
  ///
  /// 이름을 비우는 것이 「없음」의 표시고(원작의 `isValid()`), **빈 자리를
  /// 뒤로 몰지 않는다** — 자리 번호가 곧 신원이라 몰면 cm2 가 손보는 사람이
  /// 옮겨진다(부록 Z-7 과 같은 종류의 결합).
  static void dismissMember(HDParty party, int idx) {
    final m = party.seat(idx);
    if (m == null) return;
    m
      ..name = ''
      ..equipment.clear();
    party.notifyListeners();
  }
}
