import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/class_table.dart';
import '../data/item_table.dart';
import '../data/level_table.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';

/// 훈련 화면의 한 줄.
final class TrainingOption {
  const TrainingOption({
    required this.skill,
    required this.skillKey,
    required this.value,
    required this.cap,
    required this.cost,
    required this.blocked,
  });

  /// 기술치 자리(0~5).
  final int skill;
  final String skillKey;
  final int value;
  final int cap;

  /// 1 올리는 데 드는 경험치.
  final int cost;

  /// 지금 올릴 수 없는 이유. 올릴 수 있으면 null.
  final RefusalReason? blocked;

  /// 계급에 맞는 분야인가(화면이 밝게 칠할 줄).
  bool get forClass => cap > 0;
}

/// 훈련소 · 마법 학교 · 전직 · 경험치 훈련장(제7장 7.3 · 7.6, 제10장 10.7).
extension TrainingRules on LoreWorld {
  RefusalReason? _familyGate(Member m, TrainingFacility facility) {
    switch (facility) {
      case TrainingFacility.military:
        return m.family == Family.fighter
            ? null
            : RefusalReason.notFighterFamily;
      case TrainingFacility.magicSchool:
        return m.family == Family.mage ? null : RefusalReason.notMageFamily;
    }
  }

  /// 그 대원의 계열에 맞는 시설.
  TrainingFacility? facilityFor(int seat) => switch (member(seat)?.family) {
    Family.fighter => TrainingFacility.military,
    Family.mage => TrainingFacility.magicSchool,
    _ => null,
  };

  RefusalReason? _skillGate(
    Member m,
    ClassDef clazz,
    int skill,
    bool military,
  ) {
    final cap = clazz.caps[skill];
    if (cap == 0) return RefusalReason.skillNotForClass;
    if (m.skills[skill] >= cap) return RefusalReason.skillAtCap;
    if (m.family == Family.mage &&
        skill == MageSkill.esp &&
        !espTrainingUnlocked) {
      return RefusalReason.espTrainingLocked;
    }
    final cost = trainingCost(
      military: military,
      currentSkill: m.skills[skill],
    );
    if (m.exp < cost) return RefusalReason.notEnoughExp;
    return null;
  }

  /// 훈련 화면에 보일 여섯 줄. 대원이 없거나 계급이 없으면 빈 목록.
  List<TrainingOption> trainingOptions(int seat) {
    final m = member(seat);
    final clazz = m?.classDef;
    if (m == null || clazz == null) return const [];
    final military = m.family == Family.fighter;
    return [
      for (var i = 0; i < 6; i++)
        TrainingOption(
          skill: i,
          skillKey: skillKey(m.family, m.classId, i),
          value: m.skills[i],
          cap: clazz.caps[i],
          cost: trainingCost(military: military, currentSkill: m.skills[i]),
          blocked: _skillGate(m, clazz, i, military),
        ),
    ];
  }

  /// 계급의 모든 분야가 상한에 닿았는가.
  bool allCoursesCompleted(int seat) {
    final m = member(seat);
    final clazz = m?.classDef;
    if (m == null || clazz == null) return false;
    for (var i = 0; i < 6; i++) {
      if (m.skills[i] < clazz.caps[i]) return false;
    }
    return true;
  }

  /// 훈련소(학교)에 들어선다.
  ///
  /// 모든 분야가 상한이면 "모든 과정을 수료했으므로 모든 경험치를 레벨로
  /// 바꾸겠습니다." — 남은 경험치 전부가 누적 수련치로 옮겨진다. 아니면
  /// 사건 없이 받아들여지고, 화면은 [trainingOptions] 를 그린다.
  Outcome visitSchool(int seat, TrainingFacility facility) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final gate = _familyGate(m, facility);
    if (gate != null) return Outcome.refused(gate, seat: seat);
    if (!allCoursesCompleted(seat)) return const Outcome.accepted([]);
    final moved = m.exp;
    m.trainedExp += moved;
    m.exp = 0;
    return Outcome.accepted([AllCoursesCompleted(seat, moved)]);
  }

  /// 기술치 하나를 1 올린다. 경험치가 누적 수련치로 옮겨 간다.
  ///
  /// 비용은 훈련소 15 × (현재 기술치)², 마법 학교 10 × (현재 기술치)².
  Outcome train(int seat, TrainingFacility facility, int skill) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final gate = _familyGate(m, facility);
    if (gate != null) return Outcome.refused(gate, seat: seat);
    if (skill < 0 || skill > 5) {
      return Outcome.refused(RefusalReason.invalidAmount, seat: seat);
    }
    final clazz = m.classDef;
    if (clazz == null) {
      return Outcome.refused(RefusalReason.skillNotForClass, seat: seat);
    }
    final military = facility == TrainingFacility.military;
    final blocked = _skillGate(m, clazz, skill, military);
    final cost = trainingCost(
      military: military,
      currentSkill: m.skills[skill],
    );
    if (blocked != null) {
      return Outcome.refused(
        blocked,
        seat: seat,
        key: skillKey(m.family, m.classId, skill),
        amount: blocked == RefusalReason.notEnoughExp ? cost - m.exp : null,
      );
    }
    m.exp -= cost;
    m.trainedExp += cost;
    m.skills[skill] += 1;
    return Outcome.accepted([SkillTrained(seat, skill, m.skills[skill], cost)]);
  }

  /// 전직 화면에서 밝게 보일 계급 번호.
  List<int> classChangeOptions(int seat) {
    final m = member(seat);
    if (m == null) return const [];
    return [for (final c in eligibleClasses(m.family, m.skills)) c.id];
  }

  /// 전직. 금화 10000, 같은 계열 안에서만.
  ///
  /// 전투사 계열이 전사가 아닌 계급이 되면 마법 지수가 0 이 된다. 장비의
  /// 공격력·방어력은 저장하지 않으므로 새 계급 기준으로 **저절로** 바뀐다.
  Outcome changeClass(int seat, TrainingFacility facility, int classId) {
    final m = member(seat);
    if (m == null)
      return Outcome.refused(RefusalReason.noSuchMember, seat: seat);
    final gate = _familyGate(m, facility);
    if (gate != null) return Outcome.refused(gate, seat: seat);
    if (gold < classChangeFee) {
      return Outcome.refused(
        RefusalReason.notEnoughGoldForClassChange,
        seat: seat,
        amount: classChangeFee - gold,
      );
    }
    final clazz = classOf(m.family, classId);
    if (clazz == null || !clazz.selectable) {
      return Outcome.refused(RefusalReason.classNotSelectable, seat: seat);
    }
    if (clazz.id == m.classId) {
      return Outcome.refused(RefusalReason.alreadyThatClass, seat: seat);
    }
    if (!clazz.meets(m.skills)) {
      return Outcome.refused(RefusalReason.classRequirementNotMet, seat: seat);
    }
    final from = m.classId;
    gold -= classChangeFee;
    m.classId = clazz.id;
    m.acPenalty = 0;
    if (m.mp > m.maxMp) m.mp = m.maxMp;
    return Outcome.accepted([ClassChanged(seat, from, clazz.id)]);
  }

  /// 경험치 훈련장. 금 1만마다 행동 가능한 대원(0~4번) 각자 경험치 +1만,
  /// 1시간이 지난다. `units` 는 1~10.
  ///
  /// 얻은 경험치도 훈련소·학교에서 써야 레벨이 된다.
  Outcome buyExpTraining(int units) {
    if (units < 1 || units > 10) {
      return Outcome.refused(RefusalReason.invalidAmount);
    }
    final price = units * expTrainingUnit;
    if (gold < price) {
      return Outcome.refused(RefusalReason.notEnoughGold, amount: price - gold);
    }
    gold -= price;
    final who = commandSeats;
    for (final seat in who) {
      seats[seat]!.exp += price;
    }
    calendar.advance(hours: units);
    return Outcome.accepted([ExpTrained(who, price, units)]);
  }

  /// 이야기 사건: 일행 전원(이름 있는 대원)을 반신반인으로 만든다(제1부).
  Outcome promoteAllToDemigod() {
    final events = <LoreEvent>[];
    for (final seat in presentSeats) {
      final m = seats[seat]!;
      if (m.family != Family.fighter && m.family != Family.mage) continue;
      if (m.classId == ClassId.demigod) continue;
      final from = m.classId;
      m.classId = ClassId.demigod;
      m.acPenalty = 0;
      events.add(ClassChanged(seat, from, ClassId.demigod));
    }
    return Outcome.accepted(events);
  }
}
