import '../domain/enums.dart';
import '../domain/member.dart';
import 'outcome.dart';

/// 일어난 일 하나.
///
/// 문장이 아니라 **구조**다. 한국어는 `lore_world_text` 가 이것을 읽고
/// 만든다. `seat` 은 언제나 0~5 의 자리 번호다.
sealed class LoreEvent {
  const LoreEvent();

  /// 선 위의 이름. Dart 클래스 이름을 바꿔도 이 값은 그대로다.
  String get kind;

  Map<String, Object?> toJson();
}

// ── 일행 ──────────────────────────────────────────────────────

/// 동료가 빈자리(1~4)에 들어왔다.
final class MemberJoined extends LoreEvent {
  const MemberJoined(this.seat);
  final int seat;
  @override
  String get kind => 'memberJoined';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat};
}

/// 보조 일원(5번 자리)이 정해졌다. 있던 보조 일원은 사라진다.
final class AssistantSet extends LoreEvent {
  const AssistantSet({required this.replaced, this.summoned = false});

  /// 원래 있던 보조 일원을 덮어썼는가.
  final bool replaced;

  /// 소환(문서·크리스탈)으로 왔는가.
  final bool summoned;
  @override
  String get kind => 'assistantSet';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'replaced': replaced,
    'summoned': summoned,
  };
}

/// 대원이 일행에서 빠졌다(영구). 떠난 사람의 이름을 같이 싣는다.
final class MemberDismissed extends LoreEvent {
  const MemberDismissed(this.seat, {required this.name, this.nameKey});
  final int seat;
  final String name;
  final String? nameKey;
  @override
  String get kind => 'memberDismissed';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'name': name,
    if (nameKey != null) 'nameKey': nameKey,
  };
}

final class SeatsSwapped extends LoreEvent {
  const SeatsSwapped(this.a, this.b);
  final int a;
  final int b;
  @override
  String get kind => 'seatsSwapped';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'a': a, 'b': b};
}

/// 동료(1~4)가 데이터를 남긴 채 숨겨지거나 돌아왔다(부록 B.4).
final class CompanionsHidden extends LoreEvent {
  const CompanionsHidden(this.seats, {required this.hidden});
  final List<int> seats;
  final bool hidden;
  @override
  String get kind => hidden ? 'companionsHidden' : 'companionsRestored';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seats': seats};
}

// ── 성장 ──────────────────────────────────────────────────────

final class SkillTrained extends LoreEvent {
  const SkillTrained(this.seat, this.skill, this.value, this.cost);
  final int seat;

  /// 기술치 자리(0~5).
  final int skill;

  /// 오른 뒤의 값.
  final int value;

  /// 쓴 경험치.
  final int cost;
  @override
  String get kind => 'skillTrained';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'skill': skill,
    'value': value,
    'cost': cost,
  };
}

/// "모든 과정을 수료했으므로 모든 경험치를 레벨로 바꾸겠습니다."
final class AllCoursesCompleted extends LoreEvent {
  const AllCoursesCompleted(this.seat, this.expMoved);
  final int seat;
  final int expMoved;
  @override
  String get kind => 'allCoursesCompleted';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'expMoved': expMoved,
  };
}

/// "{이름}은 이제 {계급} 계급이 되었다."
final class ClassChanged extends LoreEvent {
  const ClassChanged(this.seat, this.from, this.to);
  final int seat;
  final int from;
  final int to;
  @override
  String get kind => 'classChanged';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'from': from,
    'to': to,
  };
}

/// 경험치 훈련장. "일행은 N 시간동안 훈련을 받게 되었다."
final class ExpTrained extends LoreEvent {
  const ExpTrained(this.seats, this.expEach, this.hours);
  final List<int> seats;
  final int expEach;
  final int hours;
  @override
  String get kind => 'expTrained';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seats': seats,
    'expEach': expEach,
    'hours': hours,
  };
}

/// 경험치를 얻었다(전투·이야기 보상).
final class ExpGained extends LoreEvent {
  const ExpGained(this.seat, this.amount);
  final int seat;
  final int amount;
  @override
  String get kind => 'expGained';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'amount': amount,
  };
}

/// "일행은 N개의 금을 얻었다."
final class GoldGained extends LoreEvent {
  const GoldGained(this.amount);
  final int amount;
  @override
  String get kind => 'goldGained';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'amount': amount};
}

/// "{이름}의 레벨은 N 입니다"
final class LevelUp extends LoreEvent {
  const LevelUp(this.seat, this.level);
  final int seat;
  final int level;
  @override
  String get kind => 'levelUp';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat, 'level': level};
}

/// 능력치가 올랐다(제1부 전용 계급의 레벨업).
final class AbilityRaised extends LoreEvent {
  const AbilityRaised(this.seat, this.ability, this.value);
  final int seat;
  final Ability ability;
  final int value;
  @override
  String get kind => 'abilityRaised';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'ability': ability.name,
    'value': value,
  };
}

// ── 장비 · 상점 · 병원 ────────────────────────────────────────

final class Equipped extends LoreEvent {
  const Equipped(this.seat, this.slot, this.key);
  final int seat;
  final EquipSlot slot;
  final String key;
  @override
  String get kind => 'equipped';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'slot': slot.name,
    'key': key,
  };
}

final class Unequipped extends LoreEvent {
  const Unequipped(this.seat, this.slot, this.key);
  final int seat;
  final EquipSlot slot;
  final String key;
  @override
  String get kind => 'unequipped';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'slot': slot.name,
    'key': key,
  };
}

final class EquipmentDiscarded extends LoreEvent {
  const EquipmentDiscarded(this.seat, this.slot, this.key);
  final int seat;
  final EquipSlot slot;
  final String key;
  @override
  String get kind => 'equipmentDiscarded';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'slot': slot.name,
    'key': key,
  };
}

/// 「신의 축복」 — [seat] 의 무기 공격력이 ×1.2 가 됐다(1편 리겔).
final class WeaponBlessed extends LoreEvent {
  const WeaponBlessed(this.seat);
  final int seat;
  @override
  String get kind => 'weaponBlessed';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat};
}

/// 샀다. "매우 고맙습니다."
final class Purchased extends LoreEvent {
  const Purchased(this.key, this.count, this.cost);

  /// 장비·물품의 열쇠, 또는 `supply.food` · `supply.arrows`.
  final String key;

  /// 실제로 받은 개수(한도에 걸리면 청한 것보다 적다).
  final int count;

  /// 실제로 낸 금.
  final int cost;
  @override
  String get kind => 'purchased';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'key': key,
    'count': count,
    'cost': cost,
  };
}

final class HospitalTreated extends LoreEvent {
  const HospitalTreated(this.seat, this.treatment, this.fee);
  final int seat;
  final Treatment treatment;
  final int fee;
  @override
  String get kind => 'hospitalTreated';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'treatment': treatment.name,
    'fee': fee,
  };
}

// ── 물품 · 마법 ───────────────────────────────────────────────

/// 물품·크리스탈을 썼다. "{물품}은 이제 N개 남았습니다."
final class ItemUsed extends LoreEvent {
  const ItemUsed(this.key, this.remaining, {this.consumed = true});
  final String key;
  final int remaining;
  final bool consumed;
  @override
  String get kind => 'itemUsed';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'key': key,
    'remaining': remaining,
    'consumed': consumed,
  };
}

/// 마법·초능력을 썼다.
final class SpellCast extends LoreEvent {
  const SpellCast(this.seat, this.key, this.mpSpent);
  final int seat;
  final String key;
  final int mpSpent;
  @override
  String get kind => 'spellCast';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'key': key,
    'mpSpent': mpSpent,
  };
}

final class HpRestored extends LoreEvent {
  const HpRestored(this.seat, this.amount, {required this.full});
  final int seat;
  final int amount;

  /// 최대치까지 찼는가.
  final bool full;
  @override
  String get kind => 'hpRestored';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'amount': amount,
    'full': full,
  };
}

final class MpRestored extends LoreEvent {
  const MpRestored(this.seat, this.amount);
  final int seat;
  final int amount;
  @override
  String get kind => 'mpRestored';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'amount': amount,
  };
}

final class PoisonCured extends LoreEvent {
  const PoisonCured(this.seat);
  final int seat;
  @override
  String get kind => 'poisonCured';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat};
}

/// 의식을 되찾았다(HP 최소 1).
final class Awakened extends LoreEvent {
  const Awakened(this.seat);
  final int seat;
  @override
  String get kind => 'awakened';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat};
}

/// 되살아났다.
final class Revived extends LoreEvent {
  const Revived(this.seat);
  final int seat;
  @override
  String get kind => 'revived';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat};
}

/// 한 사람에게는 아무 일도 없었다 — 물품이 헛되이 쓰였거나, 「모두」
/// 마법이 이 사람을 건너뛰었다. 명령 전체는 받아들여졌다.
final class NoEffect extends LoreEvent {
  const NoEffect(this.seat, this.reason);
  final int seat;
  final RefusalReason reason;
  @override
  String get kind => 'noEffect';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'reason': reason.name,
  };
}

/// 횃불 수치가 바뀌었다. "일행은 마법의 횃불을 밝혔습니다."
final class TorchChanged extends LoreEvent {
  const TorchChanged(this.value, this.delta);
  final int value;
  final int delta;
  @override
  String get kind => 'torchChanged';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'value': value,
    'delta': delta,
  };
}

/// 일행 공용 효과가 켜졌다(다음 휴식까지).
final class BuffsGranted extends LoreEvent {
  const BuffsGranted(this.buffs);
  final List<FieldBuff> buffs;
  @override
  String get kind => 'buffsGranted';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'buffs': [for (final b in buffs) b.name],
  };
}

/// 휴식으로 공중 부상·물 위·늪 위 효과가 풀렸다.
final class BuffsExpired extends LoreEvent {
  const BuffsExpired(this.buffs);
  final List<FieldBuff> buffs;
  @override
  String get kind => 'buffsExpired';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'buffs': [for (final b in buffs) b.name],
  };
}

/// "N 개의 식량이 증가됨 / 일행의 현재 식량은 N 개 입니다"
final class FoodCreated extends LoreEvent {
  const FoodCreated(this.added, this.total);
  final int added;
  final int total;
  @override
  String get kind => 'foodCreated';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'added': added,
    'total': total,
  };
}

/// "당신은 잠시동안 다른 사람의 마음을 읽을수 있다."
final class MindReadingStarted extends LoreEvent {
  const MindReadingStarted(this.steps);
  final int steps;
  @override
  String get kind => 'mindReadingStarted';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'steps': steps};
}

final class MindReadingEnded extends LoreEvent {
  const MindReadingEnded();
  @override
  String get kind => 'mindReadingEnded';
  @override
  Map<String, Object?> toJson() => {'kind': kind};
}

/// **지도를 가진 쪽이 마저 해야 한다.** MP·물품은 이미 치렀다.
final class MapActionNeeded extends LoreEvent {
  const MapActionNeeded(this.action, {this.distance, this.seat});
  final MapAction action;

  /// 공간 이동의 칸 수(1~9), 천리안이 내다보는 칸 수(= 레벨).
  final int? distance;

  /// 쓴 사람(있으면).
  final int? seat;
  @override
  String get kind => 'mapActionNeeded';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'action': action.name,
    if (distance != null) 'distance': distance,
    if (seat != null) 'seat': seat,
  };
}

/// 이야기가 정하는 크리스탈을 썼다. 무슨 일이 일어날지는 스크립트가 정한다.
final class StoryCrystalUsed extends LoreEvent {
  const StoryCrystalUsed(this.key);
  final String key;
  @override
  String get kind => 'storyCrystalUsed';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'key': key};
}

// ── 휴식 ──────────────────────────────────────────────────────

/// 휴식이 대원 한 명에게 남긴 결과(제11장 11.6).
enum RestResult {
  /// "일행은 식량이 바닥났다"
  noFood,

  /// "{이름}은 죽었다"
  dead,

  /// "의식이 회복되었다"
  regainedConsciousness,

  /// "여전히 의식 불명이다"
  stillUnconscious,

  /// "독때문에, {이름} {그의} 의식은 회복되지 않았다"
  unconsciousAndPoisoned,

  /// "독때문에, … 건강은 회복되지 않았다"
  poisoned,

  /// "모든 건강이 회복되었다"
  fullyRecovered,

  /// "치료되었다"
  healed,
}

final class RestMember extends LoreEvent {
  const RestMember(
    this.seat,
    this.result, {
    this.amount = 0,
    this.foodUsed = 0,
  });
  final int seat;
  final RestResult result;

  /// 오른 HP, 또는 줄어든 의식불명 수치.
  final int amount;
  final int foodUsed;
  @override
  String get kind => 'restMember';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'result': result.name,
    'amount': amount,
    'foodUsed': foodUsed,
  };
}

// ── 걸음 · 피해 ───────────────────────────────────────────────

/// 피해의 출처.
enum HarmCause { poison, lava, battle, other }

/// 대원이 피해를 입었다.
final class MemberHarmed extends LoreEvent {
  const MemberHarmed(this.seat, this.amount, this.result, this.cause);
  final int seat;
  final int amount;

  /// 이 피해로 어디까지 밀렸는가.
  final DamageResult result;
  final HarmCause cause;
  @override
  String get kind => 'memberHarmed';
  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'seat': seat,
    'amount': amount,
    'result': result.name,
    'cause': cause.name,
  };
}

/// "일행은 독이 있는 늪에 들어갔다 !!!" — 늪 위를 걷는 효과가 있으면
/// [protected] 가 참이고 아무도 중독되지 않는다.
final class EnteredSwamp extends LoreEvent {
  const EnteredSwamp({required this.protected});
  final bool protected;
  @override
  String get kind => 'enteredSwamp';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'protected': protected};
}

/// "{이름}는 중독 되었다."
final class MemberPoisoned extends LoreEvent {
  const MemberPoisoned(this.seat);
  final int seat;
  @override
  String get kind => 'memberPoisoned';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seat': seat};
}

/// "일행은 용암지대로 들어섰다 !!!"
final class EnteredLava extends LoreEvent {
  const EnteredLava();
  @override
  String get kind => 'enteredLava';
  @override
  Map<String, Object?> toJson() => {'kind': kind};
}

/// "적이 출현했다 !!!" — 몇 마리인지까지만 정한다. 누가 나오는지는
/// 맵과 진행 상황이 정한다.
final class EncounterStarted extends LoreEvent {
  const EncounterStarted(this.enemyCount);
  final int enemyCount;
  @override
  String get kind => 'encounterStarted';
  @override
  Map<String, Object?> toJson() => {'kind': kind, 'enemyCount': enemyCount};
}

/// "일행은 모험중에 모두 목숨을 잃었다."
final class GameOver extends LoreEvent {
  const GameOver();
  @override
  String get kind => 'gameOver';
  @override
  Map<String, Object?> toJson() => {'kind': kind};
}
