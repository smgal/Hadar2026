import 'dart:math';

import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/class_table.dart';
import '../data/level_table.dart';
import '../domain/calendar.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';

/// 필드 중독으로 이미 죽은 대원의 죽음 수치가 쌓이는 상한.
const int fieldPoisonDeadCap = 100;

/// 용암으로 쌓이는 죽음 수치의 상한.
const int lavaDeadCap = 30000;

/// 필드 중독은 열 걸음마다 피해 1 이다.
const int poisonStepsPerDamage = 10;

/// 어두울 때 보이는 범위.
final class Sight {
  const Sight({required this.radius, required this.dimBeyond});

  /// 낮처럼 전부 보인다.
  static const Sight full = Sight(radius: null, dimBeyond: false);

  /// 주인공 둘레 몇 칸까지 밝게 보이는가. null 이면 전부, 0 이면 주인공도
  /// 보이지 않는 완전한 암흑.
  final int? radius;

  /// 시야 밖이 어둡게나마(달빛·센 횃불) 보이는가. 아니면 새까맣다.
  final bool dimBeyond;

  bool get isFull => radius == null;

  @override
  bool operator ==(Object other) =>
      other is Sight && other.radius == radius && other.dimBeyond == dimBeyond;

  @override
  int get hashCode => Object.hash(radius, dimBeyond);

  @override
  String toString() => 'Sight(radius: $radius, dimBeyond: $dimBeyond)';
}

/// 시각만으로 정해지는 밤의 시야 반경(제11장 11.5). 낮이면 null.
int? nightRadius(int hour, int minute) {
  if (hour >= 7 && hour < 18) return null;
  if (hour == 18) return minute < 20 ? 4 : (minute < 40 ? 3 : 2);
  if (hour == 6) return minute < 20 ? 2 : (minute < 40 ? 3 : 4);
  return 1;
}

/// 휴식과 걸음(제11장), 그리고 그 안에서 일어나는 레벨업 판정(제7장 7.6).
extension FieldRules on LoreWorld {
  // ── 시야 ──────────────────────────────────────────────────

  /// 지금 얼마나 보이는가.
  ///
  /// [darknessZone] 은 완전한 암흑 구역 안인가(코볼트성 동쪽 미로) —
  /// 그 안에서는 횃불도 소용없다.
  Sight sight(MapKind mapKind, {bool darknessZone = false}) {
    if (darknessZone) return const Sight(radius: 0, dimBeyond: false);
    final cave = mapKind == MapKind.cave;
    final base = cave ? 1 : nightRadius(calendar.hour, calendar.minute);
    if (base == null) return Sight.full;

    // 달빛: 매달 10~20일. 마을형은 언제나 있고 동굴형은 언제나 없다.
    var dim = !cave && (mapKind == MapKind.town || calendar.moonIsUp);
    var radius = base;
    if (torch >= 5) {
      if (radius < 3) radius = 3;
      dim = true;
    } else if (torch >= 3) {
      if (radius < 3) radius = 3;
    } else if (torch >= 1) {
      if (radius < 2) radius = 2;
    }
    return Sight(radius: radius, dimBeyond: dim);
  }

  // ── 레벨업 ────────────────────────────────────────────────

  /// 누적 수련치로 도달한 레벨이 지금보다 높으면 올린다.
  ///
  /// **휴식할 때만** 불린다. 경험치를 벌기만 해서는 오르지 않는다 —
  /// 훈련소·마법 학교에서 써야 누적 수련치가 된다. 레벨이 올라도 현재 HP 는
  /// 저절로 늘지 않는다.
  List<LoreEvent> _judgeLevelUp(int seat, Member m, Random rng) {
    final reached = levelForTrainedExp(m.trainedExp);
    if (reached <= m.level) return const [];
    final gained = reached - m.level;
    m.level = reached;
    final events = <LoreEvent>[LevelUp(seat, reached)];

    // 제1부 전용 계급의 원작 규칙(1st/07 7.2).
    if (m.classId == ClassId.demigod) {
      // 반신반인: 레벨이 오를 때마다 저항·행운을 뺀 모든 능력치 +1(최대 20).
      for (final a in Ability.values) {
        if (a == Ability.resistance || a == Ability.luck) continue;
        final before = m.ability(a);
        if (before >= 20) continue;
        final after = before + gained > 20 ? 20 : before + gained;
        m.setAbility(a, after);
        events.add(AbilityRaised(seat, a, after));
      }
    } else if (m.family == Family.mage && m.classId == ClassId.esper) {
      // 에스퍼: 행운 판정을 통과하면 집중력 → 정확성 → 정신력 순으로,
      // 아직 20 이 안 된 첫 능력치가 1 오른다.
      for (var i = 0; i < gained; i++) {
        if (rng.nextInt(20) >= m.luck) continue;
        for (final a in const [
          Ability.concentration,
          Ability.accuracy,
          Ability.mentality,
        ]) {
          if (m.ability(a) >= 20) continue;
          m.setAbility(a, m.ability(a) + 1);
          events.add(AbilityRaised(seat, a, m.ability(a)));
          break;
        }
      }
    }
    return events;
  }

  // ── 휴식 ──────────────────────────────────────────────────

  /// 여기서 쉰다. [hours] 는 1~24.
  ///
  /// 대원마다(0~5번):
  /// * 식량이 0 이면 회복이 없다.
  /// * 죽었으면 그대로다.
  /// * 의식불명(중독 아님)이면 의식불명 수치가 레벨 × (시간 ÷ 2) 만큼 준다.
  ///   0 이하가 되면 깨어난다(HP 최소 1, 식량 1).
  /// * 중독이면 회복되지 않는다 — 의식도, 건강도.
  /// * 멀쩡하면 HP 가 레벨 × 시간 만큼 찬다(식량 1. 이미 가득했으면 0).
  ///
  /// 이어서 횃불이 (시간 ÷ 3 + 1) 만큼 줄고, 공중 부상·물 위·늪 위 효과가
  /// 풀리고, 행동 가능한 대원의 MP 가 가득 차고, **레벨업을 판정**하고,
  /// 시간이 흐른다. 쉬는 동안 적은 나타나지 않는다.
  ///
  /// [notAfter] 를 주면 시계가 그 시각을 넘지 않는다(예약 시간 이벤트).
  /// [rng] 는 제1부 에스퍼의 레벨업 행운 판정에만 쓰인다.
  Outcome rest(int hours, {required Random rng, LoreCalendar? notAfter}) {
    if (hours < 1 || hours > 24) {
      return Outcome.refused(RefusalReason.invalidAmount);
    }
    options.restHours = hours;
    final events = <LoreEvent>[];

    for (final seat in presentSeats) {
      final m = seats[seat]!;
      if (food <= 0) {
        events.add(RestMember(seat, RestResult.noFood));
      } else if (m.isDead) {
        events.add(RestMember(seat, RestResult.dead));
      } else if (m.isUnconscious && !m.isPoisoned) {
        final drop = m.level * (hours ~/ 2);
        m.unconscious -= drop;
        if (m.unconscious <= 0) {
          m.unconscious = 0;
          if (m.hp < 1) m.hp = 1;
          food -= 1;
          events.add(
            RestMember(
              seat,
              RestResult.regainedConsciousness,
              amount: drop,
              foodUsed: 1,
            ),
          );
        } else {
          events.add(
            RestMember(seat, RestResult.stillUnconscious, amount: drop),
          );
        }
      } else if (m.isUnconscious) {
        events.add(RestMember(seat, RestResult.unconsciousAndPoisoned));
      } else if (m.isPoisoned) {
        events.add(RestMember(seat, RestResult.poisoned));
      } else {
        final wasFull = m.hp >= m.maxHp;
        final gained = m.healHp(m.level * hours);
        final used = wasFull ? 0 : 1;
        food -= used;
        events.add(
          RestMember(
            seat,
            m.hp >= m.maxHp ? RestResult.fullyRecovered : RestResult.healed,
            amount: gained,
            foodUsed: used,
          ),
        );
      }
    }

    // 횃불은 걸어서는 줄지 않고 쉴 때만 준다.
    if (torch > 0) {
      final before = torch;
      setTorch(torch - (hours ~/ 3 + 1));
      events.add(TorchChanged(torch, torch - before));
    }

    final expired = [
      for (final b in FieldBuff.values)
        if (buffs.has(b)) b,
    ];
    buffs.expireOnRest();
    if (expired.isNotEmpty) events.add(BuffsExpired(expired));

    for (final seat in presentSeats) {
      final m = seats[seat]!;
      if (m.canAct) m.mp = m.maxMp;
    }

    for (final seat in presentSeats) {
      final m = seats[seat]!;
      if (m.canAct) events.addAll(_judgeLevelUp(seat, m, rng));
    }

    calendar.advance(hours: hours);
    if (notAfter != null && calendar.isAfter(notAfter)) {
      calendar.setTo(notAfter);
    }
    return Outcome.accepted(events);
  }

  // ── 걸음 ──────────────────────────────────────────────────

  /// 필드 중독의 진행. 중독된 대원마다 카운터가 1 오르고, 10 을 넘으면
  /// 1 로 돌아가며 피해 1 — 죽었으면 죽음 수치(100 미만일 때), 의식불명이면
  /// 의식불명 수치, 아니면 HP.
  List<LoreEvent> _poisonProgress() {
    final events = <LoreEvent>[];
    for (final seat in presentSeats) {
      final m = seats[seat]!;
      if (m.poison <= 0) continue;
      m.poison += 1;
      if (m.poison <= poisonStepsPerDamage) continue;
      m.poison = 1;
      final result = m.takeDamage(1, deadCap: fieldPoisonDeadCap);
      if (result != DamageResult.none) {
        events.add(MemberHarmed(seat, 1, result, HarmCause.poison));
      }
    }
    return events;
  }

  /// 한 걸음(부록 D.4). 지도는 앱이 갖고 있으므로 **들어서는 칸의 종류**를
  /// 받는다. 막힌 칸·사람·입구·푯말은 걸음이 아니므로 부르지 않는다.
  ///
  /// * 이벤트 칸 — 아무 일도 없다. 시간도 조우도 없다.
  /// * 물 — 물 위를 걷는 효과가 없으면 `waterBlocked`. 있으면 일반 걸음.
  /// * 늪 — 중독 진행 → 늪 효과. 늪 위를 걷는 효과가 있으면 그 수치가
  ///   1 줄고 아무도 중독되지 않는다. 없으면 대원마다
  ///   `rand(20) + 1 ≥ 행운` 이면 중독. 시간도 조우도 없다.
  /// * 용암 — 대원마다 `(rand(40) + 40 − 2 × rand(행운)) × 10` 의 피해.
  ///   시간도 조우도 없다.
  /// * 일반 — 중독 진행 → 게임 오버 확인 → 독심 −1 → 조우 판정 → 시간 경과
  ///   (필드 +2분, 그 밖 +5초).
  ///
  /// 조우 확률은 `1 / (20 × 전투 성향)`, 적의 수는 `rand(최대 출현수) + 1`.
  /// 마을형 맵에는 조우가 없다. 난수는 [rng] 에서만 나온다.
  Outcome step(StepInput input, {required Random rng}) {
    final events = <LoreEvent>[];
    switch (input.terrain) {
      case Terrain.event:
        return const Outcome.accepted([]);

      case Terrain.swamp:
        events.addAll(_poisonProgress());
        if (buffs.swampWalk > 0) {
          buffs.swampWalk -= 1;
          events.add(const EnteredSwamp(protected: true));
        } else {
          events.add(const EnteredSwamp(protected: false));
          for (final seat in presentSeats) {
            final m = seats[seat]!;
            if (rng.nextInt(20) + 1 >= m.luck && m.poison == 0) {
              m.poison = 1;
              events.add(MemberPoisoned(seat));
            }
          }
        }
        if (isGameOver) events.add(const GameOver());
        return Outcome.accepted(events);

      case Terrain.lava:
        events.add(const EnteredLava());
        for (final seat in presentSeats) {
          final m = seats[seat]!;
          final luckRoll = m.luck > 0 ? rng.nextInt(m.luck) : 0;
          final damage = (rng.nextInt(40) + 40 - 2 * luckRoll) * 10;
          if (damage <= 0) continue;
          final result = m.takeDamage(damage, deadCap: lavaDeadCap);
          if (result != DamageResult.none) {
            events.add(MemberHarmed(seat, damage, result, HarmCause.lava));
          }
        }
        if (isGameOver) events.add(const GameOver());
        return Outcome.accepted(events);

      case Terrain.water:
        if (!buffs.canWalkOnWater) {
          return Outcome.refused(RefusalReason.waterBlocked);
        }
      case Terrain.normal:
        break;
    }

    // 일반 걸음.
    events.addAll(_poisonProgress());
    if (isGameOver) {
      events.add(const GameOver());
      return Outcome.accepted(events);
    }

    if (buffs.mindReadSteps > 0) {
      buffs.mindReadSteps -= 1;
      if (buffs.mindReadSteps == 0) events.add(const MindReadingEnded());
    }

    if (input.encounters && input.mapKind != MapKind.town) {
      final tendency = options.encounterTendency.clamp(1, 5);
      if (rng.nextInt(20 * tendency) == 0) {
        final most = options.maxEnemies.clamp(3, 8);
        events.add(EncounterStarted(rng.nextInt(most) + 1));
      }
    }

    if (input.mapKind == MapKind.field) {
      calendar.advance(minutes: 2);
    } else {
      calendar.advance(seconds: 5);
    }
    return Outcome.accepted(events);
  }
}
