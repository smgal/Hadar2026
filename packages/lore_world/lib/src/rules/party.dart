import 'dart:math';

import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/level_table.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';

/// 적 한 마리의 능력치 중 보조 일원이 될 때 필요한 것(제12장 12.1).
///
/// 전투 패키지의 타입을 가져다 쓰지 않는다 — 이 패키지는 전투를 모른다.
/// 다리 쪽이 이 모양으로 옮겨 준다.
final class EnemyStatBlock {
  const EnemyStatBlock({
    required this.nameKey,
    this.name = '',
    required this.level,
    required this.strength,
    required this.mentality,
    required this.endurance,
    required this.agility,
    required this.physicalResist,
    required this.physicalAccuracy,
    required this.defence,
  });

  final String nameKey;
  final String name;
  final int level;
  final int strength;
  final int mentality;
  final int endurance;
  final int agility;

  /// 물리 저항(%).
  final int physicalResist;

  /// 물리 명중(0~20).
  final int physicalAccuracy;
  final int defence;
}

/// 타고난 무기가 무엇인지 알 수 없는 보조 일원(설득한 적)의 무기 이름표.
const String naturalWeaponUnknown = 'natural.attack';

/// 적을 보조 일원으로 바꾼다(제7장 7.8 의 변환 규칙).
///
/// 이름·레벨·체력·정신력·인내력·민첩성은 그대로. 성별은 중성, 계열은
/// 불명(한 명 공격), 집중력 0, 저항력 = 물리 저항 ÷ 2, 정확성 = 물리 명중,
/// 행운 10, HP·MP 는 가득, 방어력 = 적의 방어, 무기 공격력 = 레벨 × 2 + 10.
///
/// 원작은 계열을 정하지 않아 **앞선 보조 일원의 계열을 물려받았다**
/// (부록 A #12). 여기서는 언제나 불명이다.
Member assistantFromEnemy(EnemyStatBlock enemy) {
  final m = Member(
    name: enemy.name,
    nameKey: enemy.nameKey,
    gender: Gender.neutral,
    family: Family.unknown,
    level: enemy.level,
    abilities: [
      enemy.strength,
      enemy.mentality,
      0,
      enemy.endurance,
      enemy.physicalResist ~/ 2,
      enemy.agility,
      enemy.physicalAccuracy,
      10,
    ],
    baseAc: enemy.defence,
    naturalWeapon: naturalWeaponUnknown,
    naturalPower: enemy.level * 2 + 10,
    trainedExp: trainedExpForLevel(enemy.level),
  );
  m.hp = m.maxHp;
  m.mp = m.maxMp;
  return m;
}

/// 전투가 끝난 뒤 한 자리에 되돌려 쓸 것.
///
/// 절대값(`hp` · `mp` · 상태 카운터)은 null 이면 건드리지 않는다. 전투가
/// 자기 사본으로 굴렸으면 절대값을, 이쪽 대원을 직접 고쳤으면 증분만 넘긴다.
final class SeatSettlement {
  const SeatSettlement(
    this.seat, {
    this.hp,
    this.mp,
    this.poison,
    this.unconscious,
    this.dead,
    this.expGained = 0,
    this.acLoss = 0,
  });

  final int seat;
  final int? hp;
  final int? mp;
  final int? poison;
  final int? unconscious;
  final int? dead;

  /// 이 전투에서 얻은 경험치(쓰지 않은 경험치에 더한다).
  final int expGained;

  /// 갑옷 파괴로 깎인 방어력.
  final int acLoss;
}

/// 전투 한 판의 정산.
final class BattleSettlement {
  const BattleSettlement({
    this.seats = const [],
    this.goldGained = 0,
    this.arrowsUsed = 0,
    this.itemsUsed = const {},
    this.newAssistant,
    this.assistantLost = false,
  });

  final List<SeatSettlement> seats;
  final int goldGained;
  final int arrowsUsed;

  /// 전투 중에 쓴 물품·크리스탈(열쇠 → 개수).
  final Map<String, int> itemsUsed;

  /// 전투 중에 생긴 보조 일원(소환·설득). 있으면 5번 자리를 덮어쓴다.
  final Member? newAssistant;

  /// 보조 일원을 정신 지배로 빼앗겼는가.
  final bool assistantLost;
}

/// 일행 관리와 전투 정산(제7장 7.8).
extension PartyRules on LoreWorld {
  /// 동료가 들어온다 — 1~4번 빈자리 중 가장 앞.
  ///
  /// 자리가 없으면 `partyFull`. "벌써 사람이 모두 채워져 있군요."
  Outcome join(Member newcomer) {
    final seat = firstFreeCompanionSeat;
    if (seat == null) return Outcome.refused(RefusalReason.partyFull);
    seats[seat] = newcomer;
    return Outcome.accepted([MemberJoined(seat)]);
  }

  /// 보조 일원(5번 자리)을 정한다. 이미 있으면 **덮어쓴다.**
  Outcome setAssistant(Member newcomer, {bool summoned = false}) {
    final replaced = seats[Seat.assistant] != null;
    seats[Seat.assistant] = newcomer;
    return Outcome.accepted([
      AssistantSet(replaced: replaced, summoned: summoned),
    ]);
  }

  /// 한 자리(1~5)의 사람을 새 사람으로 바꾼다. 있던 사람은 영구히 떠난다.
  ///
  /// 제1부의 「합류 교체」가 쓴다 — 시작할 때 자리가 모두 차 있어서
  /// 누군가와 바꾸거나 5번 자리에 둔다.
  Outcome replace(int seat, Member newcomer) {
    if (!Seat.isValid(seat)) {
      return Outcome.refused(RefusalReason.invalidSeat, seat: seat);
    }
    if (seat == Seat.protagonist) {
      return Outcome.refused(
        RefusalReason.cannotDismissProtagonist,
        seat: seat,
      );
    }
    final old = seats[seat];
    final events = <LoreEvent>[];
    if (old != null) {
      events.add(MemberDismissed(seat, name: old.name, nameKey: old.nameKey));
    }
    seats[seat] = newcomer;
    events.add(
      seat == Seat.assistant
          ? AssistantSet(replaced: old != null)
          : MemberJoined(seat),
    );
    return Outcome.accepted(events);
  }

  /// 「일행에서 제외 시킴」 — 1~5번 중 한 명을 내보낸다. 영구히 떠나고
  /// 들고 있던 장비도 함께 간다.
  Outcome dismiss(int seat) {
    if (!Seat.isValid(seat)) {
      return Outcome.refused(RefusalReason.invalidSeat, seat: seat);
    }
    if (seat == Seat.protagonist) {
      return Outcome.refused(
        RefusalReason.cannotDismissProtagonist,
        seat: seat,
      );
    }
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    seats[seat] = null;
    return Outcome.accepted([
      MemberDismissed(seat, name: m.name, nameKey: m.nameKey),
    ]);
  }

  /// 「정식 일행의 순서 정렬」 — 1~4번 중 두 명의 자리를 바꾼다.
  Outcome swapSeats(int a, int b) {
    if (!Seat.isCompanion(a) || !Seat.isCompanion(b) || a == b) {
      return Outcome.refused(RefusalReason.invalidSeat, seat: a);
    }
    if (member(a) == null) {
      return Outcome.refused(RefusalReason.noSuchMember, seat: a);
    }
    if (member(b) == null) {
      return Outcome.refused(RefusalReason.noSuchMember, seat: b);
    }
    final t = seats[a];
    seats[a] = seats[b];
    seats[b] = t;
    return Outcome.accepted([SeatsSwapped(a, b)]);
  }

  /// 동료(1~4번)를 데이터를 남긴 채 숨긴다(부록 B.4). 보조 일원은 남는다.
  Outcome hideCompanions() {
    final hidden = <int>[];
    for (var i = Seat.firstCompanion; i <= Seat.lastCompanion; i++) {
      final m = seats[i];
      if (m != null && !m.hidden) {
        m.hidden = true;
        hidden.add(i);
      }
    }
    return Outcome.accepted([CompanionsHidden(hidden, hidden: true)]);
  }

  /// 숨겼던 동료를 그대로 되돌린다.
  Outcome restoreCompanions() {
    final restored = <int>[];
    for (var i = Seat.firstCompanion; i <= Seat.lastCompanion; i++) {
      final m = seats[i];
      if (m != null && m.hidden) {
        m.hidden = false;
        restored.add(i);
      }
    }
    return Outcome.accepted([CompanionsHidden(restored, hidden: false)]);
  }

  /// 「신의 축복」(1편 리겔, 1st/05 S8) — 무기를 든 대원마다 행운 판정을 두 번
  /// 하고(각각 0~19 의 난수 < 행운) 둘 다 통과하면 그 무기의 공격력이 ×1.2 가
  /// 된다. 맨손 · 타고난 무기 · 쓸 수 없는 무기 · 이미 축복받은 무기는 건너뛴다.
  /// 아무도 통과하지 못해도 받아들인다 — 이야기는 그대로 흘러간다.
  Outcome blessWeapons({required Random rng}) {
    final events = <LoreEvent>[];
    for (var seat = 0; seat < seats.length; seat++) {
      final m = member(seat);
      if (m == null || m.weaponBlessed) continue;
      if (m.weaponKind == WeaponKind.bare || m.naturalWeapon != null) continue;
      final first = rng.nextInt(20) < m.luck;
      final second = rng.nextInt(20) < m.luck;
      if (!first || !second) continue;
      m.weaponBlessed = true;
      events.add(WeaponBlessed(seat));
    }
    return Outcome.accepted(events);
  }

  /// 경험치를 준다(이야기 보상). [to] 를 안 주면 0~4번 중 행동 가능한
  /// 대원 전원이 받는다.
  Outcome grantExp(int amount, {List<int>? to}) {
    if (amount <= 0) return Outcome.refused(RefusalReason.invalidAmount);
    final events = <LoreEvent>[];
    for (final seat in to ?? commandSeats) {
      final m = member(seat);
      if (m == null) continue;
      m.exp += amount;
      events.add(ExpGained(seat, amount));
    }
    return Outcome.accepted(events);
  }

  /// 대원 한 명에게 피해를 준다(함정·이야기). HP → 의식불명 → 죽음 순.
  Outcome harm(
    int seat,
    int amount, {
    HarmCause cause = HarmCause.other,
    int? deadCap,
  }) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final result = m.takeDamage(amount, deadCap: deadCap);
    return Outcome.accepted([
      MemberHarmed(seat, amount, result, cause),
      if (isGameOver) const GameOver(),
    ]);
  }

  /// 전투 한 판을 정산한다.
  ///
  /// HP·MP 는 0 ~ 최대치로 맞춘다. 경험치는 **쓰지 않은 경험치**에 쌓인다 —
  /// 훈련소에서 써야 레벨이 된다.
  Outcome settleBattle(BattleSettlement result) {
    final events = <LoreEvent>[];
    for (final s in result.seats) {
      final m = member(s.seat);
      if (m == null) continue;
      if (s.poison != null) m.poison = s.poison! < 0 ? 0 : s.poison!;
      if (s.unconscious != null) {
        m.unconscious = s.unconscious! < 0 ? 0 : s.unconscious!;
      }
      if (s.dead != null) m.dead = s.dead! < 0 ? 0 : s.dead!;
      if (s.hp != null) m.hp = s.hp!.clamp(0, m.maxHp);
      if (s.mp != null) m.mp = s.mp!.clamp(0, m.maxMp);
      if (s.acLoss > 0) m.acPenalty += s.acLoss;
      if (s.expGained > 0) {
        m.exp += s.expGained;
        events.add(ExpGained(s.seat, s.expGained));
      }
    }
    if (result.arrowsUsed > 0) addArrows(-result.arrowsUsed);
    for (final e in result.itemsUsed.entries) {
      final have = countOf(e.key);
      take(e.key, e.value > have ? have : e.value);
    }
    if (result.assistantLost) seats[Seat.assistant] = null;
    final newcomer = result.newAssistant;
    if (newcomer != null) {
      events.addAll(setAssistant(newcomer).events);
    }
    if (result.goldGained > 0) {
      addGold(result.goldGained);
      events.add(GoldGained(result.goldGained));
    }
    if (isGameOver) events.add(const GameOver());
    return Outcome.accepted(events);
  }
}
