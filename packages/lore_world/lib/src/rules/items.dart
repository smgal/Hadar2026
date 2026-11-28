import 'dart:math';

import '../contract/events.dart';
import '../contract/outcome.dart';
import '../data/item_table.dart';
import '../data/summon_table.dart';
import '../domain/calendar.dart';
import '../domain/enums.dart';
import '../domain/member.dart';
import '../model/world.dart';

/// 체력 회복약·마법 회복약 한 병이 채우는 양.
const int potionAmount = 1000;

/// 대형 횃불 하나가 올리는 횃불 수치.
const int bigTorchAmount = 10;

/// 죽음 수치가 이 값 이상이면 부활의 약초로 되살릴 수 없다.
const int revivalHerbLimit = 10000;

/// 공간 이동·이동 구슬의 칸 수 범위와 기본값.
const int teleportMin = 1;
const int teleportMax = 9;
const int teleportDefault = 5;

/// 물품과 크리스탈을 필드에서 쓴다(제10장 10.5, 제9장 9.8).
///
/// ## 헛되이 쓰는 것
///
/// 기획서가 **문구를 정해 둔** 실패(마법사 계열이 아니다, 이미 죽었다)는
/// 거절이고 물품이 줄지 않는다. 그 밖에 효과가 없을 뿐인 경우(생명력이
/// 가득한데 회복약)는 원작대로 **쓰이고 사라진다** — 화면이 먼저
/// [consumableWouldBeWasted] 로 물어 확인 절차를 두라는 것이 기획서의 권고다.
extension ItemRules on LoreWorld {
  /// 지금 쓰면 아무 효과가 없는 이유. 효과가 있으면 null.
  ///
  /// 거절될 명령에 대해서는 답하지 않는다(null). 그쪽은 명령이 말한다.
  RefusalReason? consumableWouldBeWasted(
    String key, {
    required int user,
    int? target,
  }) {
    final u = member(user);
    final t = member(target ?? user);
    if (u == null || t == null) return null;
    return switch (key) {
      ItemKey.hpPotion =>
        u.hp >= u.maxHp ? RefusalReason.noTreatmentNeeded : null,
      ItemKey.mpPotion =>
        u.hasMagicPool && u.mp >= u.maxMp
            ? RefusalReason.noTreatmentNeeded
            : null,
      ItemKey.antidoteHerb => u.isPoisoned ? null : RefusalReason.notPoisoned,
      ItemKey.awakeningHerb =>
        t.isDead || t.isUnconscious ? null : RefusalReason.notUnconscious,
      ItemKey.revivalHerb => t.isDead ? null : RefusalReason.notDead,
      _ => null,
    };
  }

  /// 물품 하나를 쓴다.
  ///
  /// [user] 는 0~4번 중 행동 가능한 대원. [target] 은 의식의 약초·부활의
  /// 약초가 받는 사람(안 주면 쓰는 사람). [distance] 는 이동 구슬의 칸 수.
  /// [rng] 는 소환 문서가 누구를 부를지 굴리는 데 쓴다.
  ///
  /// 수정 구슬과 이동 구슬은 지도가 있어야 끝나므로 `MapActionNeeded` 를
  /// 낸다. **그 맵에서 통하는지는 부르기 전에 앱이 본다** — 부르면 물품은
  /// 이미 쓰였다.
  Outcome useConsumable(
    String key, {
    required int user,
    int? target,
    int distance = teleportDefault,
    required Random rng,
  }) {
    final def = consumableByKey(key);
    if (def == null)
      return Outcome.refused(RefusalReason.unknownItem, key: key);
    if (user < Seat.protagonist || user > Seat.lastCompanion) {
      return Outcome.refused(RefusalReason.invalidSeat, seat: user, key: key);
    }
    final u = member(user);
    if (u == null) {
      return Outcome.refused(RefusalReason.noSuchMember, seat: user, key: key);
    }
    if (!u.canAct) {
      return Outcome.refused(RefusalReason.userCannotAct, seat: user, key: key);
    }
    if ((consumables[key] ?? 0) <= 0) {
      return Outcome.refused(RefusalReason.noneOwned, key: key);
    }
    final targetSeat = def.needsTarget ? (target ?? user) : user;
    final t = member(targetSeat);
    if (t == null) {
      return Outcome.refused(
        RefusalReason.noSuchMember,
        seat: targetSeat,
        key: key,
      );
    }

    final events = <LoreEvent>[];
    switch (key) {
      case ItemKey.hpPotion:
        final gained = u.healHp(potionAmount);
        events.add(
          gained > 0
              ? HpRestored(user, gained, full: u.hp >= u.maxHp)
              : NoEffect(user, RefusalReason.noTreatmentNeeded),
        );
      case ItemKey.mpPotion:
        if (!u.hasMagicPool) {
          return Outcome.refused(
            RefusalReason.notMagicUser,
            seat: user,
            key: key,
          );
        }
        final gained = u.restoreMp(potionAmount);
        events.add(
          gained > 0
              ? MpRestored(user, gained)
              : NoEffect(user, RefusalReason.noTreatmentNeeded),
        );
      case ItemKey.antidoteHerb:
        events.add(
          u.curePoison()
              ? PoisonCured(user)
              : NoEffect(user, RefusalReason.notPoisoned),
        );
      case ItemKey.awakeningHerb:
        if (t.isDead) {
          return Outcome.refused(
            RefusalReason.alreadyDead,
            seat: targetSeat,
            key: key,
          );
        }
        events.add(
          t.awaken()
              ? Awakened(targetSeat)
              : NoEffect(targetSeat, RefusalReason.notUnconscious),
        );
      case ItemKey.revivalHerb:
        if (t.dead >= revivalHerbLimit) {
          return Outcome.refused(
            RefusalReason.beyondRevival,
            seat: targetSeat,
            key: key,
          );
        }
        events.add(
          t.revive()
              ? Revived(targetSeat)
              : NoEffect(targetSeat, RefusalReason.notDead),
        );
      case ItemKey.summonScroll:
        // 다른 차원 생물. S 대신 「일행 평균 레벨 × 5」 를 쓴다.
        final level = averageCommandLevel < 1 ? 1 : averageCommandLevel;
        final pick =
            otherDimensionCreatures[rng.nextInt(
              otherDimensionCreatures.length,
            )];
        final summoned = buildSummon(pick, skill: level * 5, rng: rng);
        events.addAll(setAssistant(summoned, summoned: true).events);
      case ItemKey.bigTorch:
        final before = torch;
        setTorch(torch + bigTorchAmount);
        events.add(TorchChanged(torch, torch - before));
      case ItemKey.seeingOrb:
        events.add(MapActionNeeded(MapAction.showMap, seat: user));
      case ItemKey.flyingBoots:
        for (final b in FieldBuff.values) {
          buffs.grant(b);
        }
        events.add(const BuffsGranted(FieldBuff.values));
      case ItemKey.warpOrb:
        if (distance < teleportMin || distance > teleportMax) {
          return Outcome.refused(
            RefusalReason.invalidAmount,
            seat: user,
            key: key,
          );
        }
        events.add(
          MapActionNeeded(MapAction.teleport, distance: distance, seat: user),
        );
    }
    take(key);
    events.add(ItemUsed(key, consumables[key] ?? 0));
    return Outcome.accepted(events);
  }

  /// 크리스탈 하나를 필드에서 쓴다.
  ///
  /// * 소환의 크리스탈 — 크리스탈 드래곤 40% · 크리스탈 고렘 40% ·
  ///   대천사장 20% 가 보조 일원이 된다.
  /// * 에너지 크리스탈 — 일행 전원. 살아 있으면 의식을 찾고 HP 가 가득,
  ///   죽었으면 HP 1 로 되살아난다.
  /// * 크로매틱 크리스탈 · 크리스탈 볼 — 이야기가 정한다. `StoryCrystalUsed`
  ///   만 내고 **줄지 않는다.**
  /// * 나머지 다섯은 전투 전용이라 `battleOnly`.
  Outcome useCrystal(String key, {required Random rng}) {
    final def = crystalByKey(key);
    if (def == null)
      return Outcome.refused(RefusalReason.unknownItem, key: key);
    if ((crystals[key] ?? 0) <= 0) {
      return Outcome.refused(RefusalReason.noneOwned, key: key);
    }
    if (!def.field) return Outcome.refused(RefusalReason.battleOnly, key: key);
    if (def.story) return Outcome.accepted([StoryCrystalUsed(key)]);

    final events = <LoreEvent>[];
    switch (key) {
      case CrystalKey.summon:
        final summoned = buildSummon(
          rollCrystalSummonOnField(rng),
          skill: 0,
          rng: rng,
        );
        events.addAll(setAssistant(summoned, summoned: true).events);
      case CrystalKey.energy:
        for (final seat in presentSeats) {
          events.addAll(_energize(seat, seats[seat]!));
        }
    }
    take(key);
    events.add(ItemUsed(key, crystals[key] ?? 0));
    return Outcome.accepted(events);
  }

  List<LoreEvent> _energize(int seat, Member m) {
    if (m.isDead) {
      m.dead = 0;
      m.unconscious = 0;
      m.hp = 1;
      return [Revived(seat)];
    }
    final wasOut = m.isUnconscious;
    m.unconscious = 0;
    final gained = m.healHp(m.maxHp);
    return [
      if (wasOut) Awakened(seat),
      if (gained > 0 || wasOut) HpRestored(seat, gained, full: true),
    ];
  }

  /// 일행 공용 효과가 켜져 있는가. 지도 쪽이 물·늪·계곡을 물을 때 쓴다.
  bool hasBuff(FieldBuff buff) => buffs.has(buff);

  /// 지금 독심 상태인가.
  bool get isMindReading => buffs.mindReadSteps > 0;

  /// 독심을 켠다(3걸음).
  void startMindReading() => buffs.mindReadSteps = FieldBuffs.mindReadDuration;
}
