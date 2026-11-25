import '../domain/enums.dart';
import 'events.dart';

/// 명령이 거절된 이유. **닫힌 열거**다 — 화면은 이 값으로 문장을 고른다.
///
/// 「안 됐다」 하나로 뭉치지 않는다. 죽어서 안 되는 것과 돈이 없어서
/// 안 되는 것은 다른 문장이다.
enum RefusalReason {
  // ── 공통 ──
  /// 그 자리에 사람이 없다(비었거나 숨겨졌다).
  noSuchMember,

  /// 자리 번호가 그 명령이 받는 범위 밖이다.
  invalidSeat,

  /// 개수·시간·거리가 허용 범위 밖이다.
  invalidAmount,

  /// 모르는 열쇠다.
  unknownItem,

  // ── 캐릭터 생성 ──
  emptyName,
  nameTooLong,
  invalidGender,
  invalidAnswers,
  invalidPointSplit,
  invalidSkillSplit,

  // ── 계급 ──
  /// 기술치가 그 계급의 조건에 못 미친다.
  classRequirementNotMet,

  /// 고를 수 없는 계급이다(없는 번호, 이야기로만 얻는 계급).
  classNotSelectable,

  /// 이미 그 계급이다.
  alreadyThatClass,

  // ── 훈련 ──
  /// "당신은 전투사 계열이 아닙니다."
  notFighterFamily,

  /// "당신은 마법사 계열이 아닙니다."
  notMageFamily,

  /// "이 분야는 더 배울 것이 없습니다"
  skillAtCap,

  /// "당신의 계급과 맞지 않습니다"
  skillNotForClass,

  /// "아직 경험치가 모자랍니다"
  notEnoughExp,

  /// 제1부: 스피카를 만나기 전에는 초자연력을 올릴 수 없다.
  espTrainingLocked,

  /// 전직 비용 금 10000 이 없다.
  notEnoughGoldForClassChange,

  // ── 돈과 한도 ──
  /// "당신은 충분한 돈이 없습니다."
  notEnoughGold,

  /// 이미 한도까지 갖고 있다.
  atLimit,

  /// 팔지 않는 물건이다(흑요석 갑옷, 다른 편의 전용 무기).
  notForSale,

  /// 그 가게에서 파는 물건이 아니다.
  wrongShop,

  // ── 장비 ──
  notInBackpack,

  /// 그 칸에 이미 장착한 것이 있다. 먼저 해제해야 한다.
  slotOccupied,

  /// 계급 제한에 걸린다(원작은 경고음).
  classCannotUse,
  nothingEquipped,
  backpackFull,

  // ── 병원 · 치료 ──
  /// "{이름}은 이미 죽은 상태입니다"
  alreadyDead,

  /// "{이름}은 이미 의식불명입니다"
  alreadyUnconscious,

  /// "{이름}은 독이 퍼진 상태입니다"
  poisonSpreading,

  /// "치료할 필요가 없습니다"
  noTreatmentNeeded,

  /// "{이름}는 치료될 상태가 아닙니다"
  targetNotCurable,

  /// "독에 걸리지 않았습니다"
  notPoisoned,

  /// "의식불명이 아닙니다"
  notUnconscious,

  /// "아직 살아 있습니다"
  notDead,

  /// 죽음 수치가 10000 이상이라 부활의 약초로는 되살릴 수 없다.
  beyondRevival,

  // ── 물품 · 크리스탈 ──
  /// "하지만 {물품}이 없습니다."
  noneOwned,

  /// 쓰려는 사람이 행동할 수 없다.
  userCannotAct,

  /// "마법사 계열이 아닙니다." (마법 회복약)
  notMagicUser,

  /// 전투에서만 쓰인다(염력, 전투용 크리스탈).
  battleOnly,

  // ── 마법 · 초능력 ──
  /// "그는 마법을 사용할수있는 상태가 아닙니다"
  casterCannotAct,

  /// "마법을 사용할 수 없는 계열입니다"
  notMagicFamily,

  /// 능력치가 모자라 아직 고를 수 없는 단계다.
  spellLocked,

  /// "마법 지수가 충분하지 않습니다."
  notEnoughMp,

  /// "{그}는 투시를 시도해 보았지만 아직은 역부족이었다."
  espTooWeak,

  // ── 일행 ──
  /// 2~5번이 모두 찼다.
  partyFull,
  cannotDismissProtagonist,

  // ── 걸음 ──
  /// 물 위를 걷는 효과 없이는 물에 들어갈 수 없다.
  waterBlocked,
}

/// 거절 하나. 이유와, 문장을 만드는 데 필요한 것들.
final class Refusal {
  const Refusal(this.reason, {this.seat, this.key, this.amount});

  final RefusalReason reason;

  /// 누구 때문인가(있으면).
  final int? seat;

  /// 어떤 물건·마법 때문인가(있으면).
  final String? key;

  /// 얼마가 모자라는가 · 얼마가 필요한가(있으면).
  final int? amount;

  Map<String, Object?> toJson() => {
    'reason': reason.name,
    if (seat != null) 'seat': seat,
    if (key != null) 'key': key,
    if (amount != null) 'amount': amount,
  };

  @override
  String toString() =>
      'Refusal(${reason.name}'
      '${seat == null ? '' : ', seat: $seat'}'
      '${key == null ? '' : ', key: $key'}'
      '${amount == null ? '' : ', amount: $amount'})';
}

/// 명령 하나의 결과.
///
/// ## 던지지 않는다
///
/// 모든 명령이 이것을 돌려준다. 거절이면 [refusal] 이 있고 아무것도
/// 바뀌지 않았다. 받아들여졌으면 [events] 에 일어난 일이 순서대로 있다.
/// 그래서 화면·테스트·재생 기록이 같은 모양을 쓴다.
final class Outcome {
  const Outcome.accepted(this.events) : refusal = null;

  Outcome.refused(RefusalReason reason, {int? seat, String? key, int? amount})
    : refusal = Refusal(reason, seat: seat, key: key, amount: amount),
      events = const [];

  final Refusal? refusal;
  final List<LoreEvent> events;

  bool get ok => refusal == null;
  bool get isRefused => refusal != null;
  RefusalReason? get reason => refusal?.reason;

  /// 그 종류의 사건만.
  Iterable<T> of<T extends LoreEvent>() => events.whereType<T>();

  /// 그 종류의 첫 사건. 없으면 null.
  T? first<T extends LoreEvent>() {
    for (final e in events) {
      if (e is T) return e;
    }
    return null;
  }

  bool has<T extends LoreEvent>() => first<T>() != null;

  /// 지도를 가진 쪽이 마저 해야 할 일. 없으면 null.
  MapActionNeeded? get mapAction => first<MapActionNeeded>();

  /// 이 걸음에서 적을 만났는가.
  bool get encounterStarted => has<EncounterStarted>();

  /// 이 명령으로 일행 전원이 행동 불가가 됐는가.
  bool get gameOver => has<GameOver>();

  Map<String, Object?> toJson() => {
    'ok': ok,
    if (refusal != null) 'refusal': refusal!.toJson(),
    'events': [for (final e in events) e.toJson()],
  };

  @override
  String toString() => ok
      ? 'Outcome.accepted(${events.map((e) => e.kind).join(', ')})'
      : 'Outcome.refused($refusal)';
}

/// 걸음 한 번에 넣는 것. 지도는 앱이 갖고 있으므로 앱이 알려 준다.
final class StepInput {
  const StepInput({
    this.mapKind = MapKind.field,
    this.terrain = Terrain.normal,
    this.encounters = true,
  });

  final MapKind mapKind;
  final Terrain terrain;

  /// 이 맵에서 지금 무작위 조우가 일어나는가. 마을형은 넣은 값과 관계없이
  /// 조우가 없다. 우두머리를 잡아 조우가 사라진 지역은 false 로 넣는다.
  final bool encounters;
}
