import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/class_table.dart';
import '../data/spell_table.dart';
import '../domain/calendar.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';
import 'items.dart';

/// 치료 마법 한 단계가 한 사람에게 드는 MP(제9장 9.4).
///
/// 1 치료 = 시전자 레벨 × 2, 2 독 제거 = 15, 3 의식 돌림 = 10 × 대상의
/// 의식불명 수치, 4 부활 = 30 × 대상의 죽음 수치. 5(복합)는 단계마다 따로다.
int cureStepMp(int step, Member caster, Member target) => switch (step) {
  1 => caster.level * 2,
  2 => 15,
  3 => 10 * target.unconscious,
  4 => 30 * target.dead,
  _ => 0,
};

/// 그 단계의 치료가 그 사람에게 안 통하는 이유. 통하면 null.
///
/// **깊은 곳부터** — 죽었으면 부활만, 의식불명이면 의식 돌림만, 중독이면
/// 독 제거만 통한다.
RefusalReason? cureStepBlocked(int step, Member target) {
  switch (step) {
    case 1:
      if (target.isDead || target.isUnconscious || target.isPoisoned) {
        return RefusalReason.targetNotCurable;
      }
      if (target.hp >= target.maxHp) return RefusalReason.noTreatmentNeeded;
    case 2:
      if (target.isDead || target.isUnconscious) {
        return RefusalReason.targetNotCurable;
      }
      if (!target.isPoisoned) return RefusalReason.notPoisoned;
    case 3:
      if (target.isDead) return RefusalReason.targetNotCurable;
      if (!target.isUnconscious) return RefusalReason.notUnconscious;
    case 4:
      if (!target.isDead) return RefusalReason.notDead;
  }
  return null;
}

/// 필드 마법과 필드 초능력(제9장 9.3 · 9.4 · 9.6).
///
/// ## 지도가 필요한 마법
///
/// 이 패키지는 자격과 MP 와 일행 공용 효과까지만 정하고, 지도에서 일어날
/// 일은 `MapActionNeeded` 로 **무엇을 할지만** 알린다. 순서는 이렇다.
///
/// 1. 앱이 [checkChange] / [checkFieldEsp] 로 쓸 수 있는지 본다(바뀌는 것 없음).
/// 2. 앱이 그 맵의 제한을 본다(막힌 맵이면 여기서 그만 — MP 가 줄지 않는다).
/// 3. 앱이 [castChange] / [castFieldEsp] 를 부른다. **MP 가 빠진다.**
/// 4. 앱이 지도에서 실행한다. 특수 칸에 막혀 실패해도 MP 는 돌아오지 않는다.
extension MagicRules on LoreWorld {
  RefusalReason? _casterGate(Member? m, {required bool cureOnly}) {
    if (m == null) return RefusalReason.noSuchMember;
    final allowed = cureOnly ? m.canUseCureMagic : m.family == Family.mage;
    if (!allowed) return RefusalReason.notMagicFamily;
    if (!m.canAct) return RefusalReason.casterCannotAct;
    return null;
  }

  // ── 치료 마법 ─────────────────────────────────────────────

  /// 그 대원이 지금 고를 수 있는 치료 마법의 단계들.
  ///
  /// 치료 단계 L = 치료 마법 능력치 ÷ 10. 한 명: 1 ~ min(L, 5).
  /// 모두: L 이 6 이상일 때만 6 ~ L.
  List<int> availableCureSpells(int seat) {
    final m = member(seat);
    if (m == null || !m.canUseCureMagic) return const [];
    final tiers = unlockedTiers(m.cureSkill);
    return [for (var i = 1; i <= tiers; i++) i];
  }

  /// 치료 마법 한 단계를 한 사람에게 건다. 사건과, 막혔으면 그 이유.
  (List<LoreEvent>, RefusalReason?) _cureStep(
    int step,
    Member caster,
    int targetSeat,
    Member target,
  ) {
    final blocked = cureStepBlocked(step, target);
    if (blocked != null) return (const [], blocked);
    final cost = cureStepMp(step, caster, target);
    if (caster.mp < cost) return (const [], RefusalReason.notEnoughMp);
    caster.mp -= cost;
    switch (step) {
      case 1:
        final gained = target.healHp(caster.level * 20);
        return (
          [HpRestored(targetSeat, gained, full: target.hp >= target.maxHp)],
          null,
        );
      case 2:
        target.curePoison();
        return ([PoisonCured(targetSeat)], null);
      case 3:
        target.awaken();
        return ([Awakened(targetSeat)], null);
      default:
        target.revive();
        return ([Revived(targetSeat)], null);
    }
  }

  /// 한 사람에게 한 가지(1~4) 또는 복합(5) 치료를 건다.
  (List<LoreEvent>, RefusalReason?) _cureOne(
    int kind,
    Member caster,
    int targetSeat,
    Member target,
  ) {
    if (kind != 5) return _cureStep(kind, caster, targetSeat, target);
    // 복합 치료: 부활 → 의식 돌림 → 독 제거 → 치료. 해당 없는 단계는
    // 조용히 건너뛰고, 마법 지수가 떨어지면 거기서 멈춘다.
    final events = <LoreEvent>[];
    for (final step in const [4, 3, 2, 1]) {
      final (stepEvents, blocked) = _cureStep(step, caster, targetSeat, target);
      events.addAll(stepEvents);
      if (blocked == RefusalReason.notEnoughMp) {
        return (events, events.isEmpty ? blocked : null);
      }
    }
    if (events.isEmpty) return (events, RefusalReason.noTreatmentNeeded);
    return (events, null);
  }

  /// 치료 마법을 쓴다. [spell] 은 1~10.
  ///
  /// 1~5 는 [target] 한 명에게(안 주면 시전자 자신), 6~10 은 일행 전원
  /// (0~5번)에게 대상마다 따로 MP 를 내고 건다.
  ///
  /// 한 명 마법이 통하지 않으면 **거절**이고 MP 가 줄지 않는다. 모두 마법은
  /// 통하지 않는 사람을 `NoEffect` 로 건너뛰고 계속한다.
  Outcome castCure(int caster, int spell, {int? target}) {
    final c = member(caster);
    final gate = _casterGate(c, cureOnly: true);
    if (gate != null) return Outcome.refused(gate, seat: caster);
    if (spell < 1 || spell > 10) {
      return Outcome.refused(RefusalReason.invalidAmount, seat: caster);
    }
    final def = spellAt(SpellSchool.cure, spell)!;
    if (c!.cureSkill < def.unlock) {
      return Outcome.refused(
        RefusalReason.spellLocked,
        seat: caster,
        key: def.key,
      );
    }
    final mpBefore = c.mp;

    if (spell <= 5) {
      final targetSeat = target ?? caster;
      final t = member(targetSeat);
      if (t == null) {
        return Outcome.refused(RefusalReason.noSuchMember, seat: targetSeat);
      }
      final (events, blocked) = _cureOne(spell, c, targetSeat, t);
      if (blocked != null) {
        return Outcome.refused(blocked, seat: targetSeat, key: def.key);
      }
      return Outcome.accepted([
        SpellCast(caster, def.key, mpBefore - c.mp),
        ...events,
      ]);
    }

    final events = <LoreEvent>[];
    for (final seat in presentSeats) {
      final (done, blocked) = _cureOne(spell - 5, c, seat, seats[seat]!);
      events.addAll(done);
      if (blocked != null) events.add(NoEffect(seat, blocked));
    }
    return Outcome.accepted([
      SpellCast(caster, def.key, mpBefore - c.mp),
      ...events,
    ]);
  }

  // ── 변화 마법 ─────────────────────────────────────────────

  /// 변화 마법을 쓸 수 있는가. 되면 null. 아무것도 바꾸지 않는다.
  RefusalReason? checkChange(int caster, int spell, {int? distance}) {
    final c = member(caster);
    final gate = _casterGate(c, cureOnly: false);
    if (gate != null) return gate;
    if (spell < 1 || spell > 10) return RefusalReason.invalidAmount;
    final def = spellAt(SpellSchool.change, spell)!;
    if (c!.skills[MageSkill.change] < def.unlock) {
      return RefusalReason.spellLocked;
    }
    if (spell == 8) {
      final d = distance ?? teleportDefault;
      if (d < teleportMin || d > teleportMax)
        return RefusalReason.invalidAmount;
    }
    if (c.mp < def.mp!) return RefusalReason.notEnoughMp;
    return null;
  }

  /// 변화 마법을 쓴다. [spell] 은 1~10.
  ///
  /// | # | 마법 | 이 패키지가 하는 일 |
  /// |--:|---|---|
  /// | 1 | 마법의 횃불 | 횃불 += 변화 능력치 ÷ 10 (최대 255) |
  /// | 2 | 주시자의 눈 | `showMap` |
  /// | 3 | 공중 부상 | 효과를 켠다(다음 휴식까지) |
  /// | 4 | 물위를 걸음 | 〃 |
  /// | 5 | 늪위를 걸음 | 〃 (늪을 걸을 때마다 준다) |
  /// | 6 | 기화 이동 | `etherealMove` |
  /// | 7 | 지형 변화 | `terraform` |
  /// | 8 | 공간 이동 | `teleport`, [distance] 1~9 (기본 5) |
  /// | 9 | 식량 제조 | 식량 += 일행 인원 수 (최대 255) |
  /// | 10 | 대지형 변화 | `greatTerraform` |
  Outcome castChange(int caster, int spell, {int? distance}) {
    final refusal = checkChange(caster, spell, distance: distance);
    final def = spell >= 1 && spell <= 10
        ? spellAt(SpellSchool.change, spell)
        : null;
    if (refusal != null) {
      return Outcome.refused(refusal, seat: caster, key: def?.key);
    }
    final c = seats[caster]!;
    final cost = def!.mp!;
    c.mp -= cost;
    final events = <LoreEvent>[SpellCast(caster, def.key, cost)];
    switch (spell) {
      case 1:
        final before = torch;
        setTorch(torch + c.skills[MageSkill.change] ~/ 10);
        events.add(TorchChanged(torch, torch - before));
      case 2:
        events.add(MapActionNeeded(MapAction.showMap, seat: caster));
      case 3:
        buffs.grant(FieldBuff.levitation);
        events.add(const BuffsGranted([FieldBuff.levitation]));
      case 4:
        buffs.grant(FieldBuff.waterWalk);
        events.add(const BuffsGranted([FieldBuff.waterWalk]));
      case 5:
        buffs.grant(FieldBuff.swampWalk);
        events.add(const BuffsGranted([FieldBuff.swampWalk]));
      case 6:
        events.add(MapActionNeeded(MapAction.etherealMove, seat: caster));
      case 7:
        events.add(MapActionNeeded(MapAction.terraform, seat: caster));
      case 8:
        events.add(
          MapActionNeeded(
            MapAction.teleport,
            distance: distance ?? teleportDefault,
            seat: caster,
          ),
        );
      case 9:
        final before = food;
        addFood(presentSeats.length);
        events.add(FoodCreated(food - before, food));
      case 10:
        events.add(MapActionNeeded(MapAction.greatTerraform, seat: caster));
    }
    return Outcome.accepted(events);
  }

  /// 그 대원이 지금 고를 수 있는 변화 마법의 단계들.
  List<int> availableChangeSpells(int seat) {
    final m = member(seat);
    if (m == null || m.family != Family.mage) return const [];
    final tiers = unlockedTiers(m.skills[MageSkill.change]);
    return [for (var i = 1; i <= tiers; i++) i];
  }

  // ── 필드 초능력 ───────────────────────────────────────────

  /// 필드 초능력의 소모량. 천리안만 레벨 × 5 다.
  int fieldEspMp(Member caster, FieldEsp power) => switch (power) {
    FieldEsp.clairvoyance => 10,
    FieldEsp.prophecy => 5,
    FieldEsp.mindReading => 20,
    FieldEsp.farSight => caster.level * 5,
    FieldEsp.telekinesis => 0,
  };

  /// 필드 초능력을 쓸 수 있는가. 되면 null. 아무것도 바꾸지 않는다.
  RefusalReason? checkFieldEsp(int caster, FieldEsp power) {
    final c = member(caster);
    final gate = _casterGate(c, cureOnly: false);
    if (gate != null) return gate;
    if (power == FieldEsp.telekinesis) return RefusalReason.battleOnly;
    final def = spellByKey(fieldEspKey(power))!;
    if (c!.skills[MageSkill.esp] < def.unlock) return RefusalReason.espTooWeak;
    if (c.mp < fieldEspMp(c, power)) return RefusalReason.notEnoughMp;
    return null;
  }

  /// 필드 초능력을 쓴다.
  ///
  /// * 투시(70, MP 10) — `revealHidden`
  /// * 예언(10, MP 5) — `prophecy`
  /// * 독심(40, MP 20) — 3걸음 동안 독심 상태. **MP 를 실제로 낸다**
  ///   (원작은 확인만 하고 빼지 않았다 — 부록 A #29).
  /// * 천리안(55, MP 레벨 × 5) — `farSight`, 거리 = 레벨
  /// * 염력 — 전투 전용이라 `battleOnly`
  Outcome castFieldEsp(int caster, FieldEsp power) {
    final refusal = checkFieldEsp(caster, power);
    final key = fieldEspKey(power);
    if (refusal != null)
      return Outcome.refused(refusal, seat: caster, key: key);
    final c = seats[caster]!;
    final cost = fieldEspMp(c, power);
    c.mp -= cost;
    final events = <LoreEvent>[SpellCast(caster, key, cost)];
    switch (power) {
      case FieldEsp.clairvoyance:
        events.add(MapActionNeeded(MapAction.revealHidden, seat: caster));
      case FieldEsp.prophecy:
        events.add(MapActionNeeded(MapAction.prophecy, seat: caster));
      case FieldEsp.mindReading:
        startMindReading();
        events.add(const MindReadingStarted(FieldBuffs.mindReadDuration));
      case FieldEsp.farSight:
        events.add(
          MapActionNeeded(MapAction.farSight, distance: c.level, seat: caster),
        );
      case FieldEsp.telekinesis:
        break;
    }
    return Outcome.accepted(events);
  }

  /// 일행 중에 초자연력이 [minimum] 이상인 사람이 있는가(제1부 스피카의
  /// 합류 조건 — 제안값 40).
  bool anyoneHasEsp(int minimum) {
    for (final m in presentMembers) {
      if (m.family == Family.mage && m.skills[MageSkill.esp] >= minimum) {
        return true;
      }
    }
    return false;
  }
}
