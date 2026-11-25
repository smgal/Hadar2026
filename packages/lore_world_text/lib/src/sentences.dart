/// 명령의 결과를 문장으로 — 거절 하나에 한 문장, 사건 하나에 한두 문장.
///
/// 기획서가 문구를 정해 둔 곳은 그 문구를 쓴다(띄어쓰기·맞춤법은 고쳤다).
/// 정해 두지 않은 곳은 같은 말투로 지어 넣었고, 그런 문장은 주석에 「지음」
/// 이라고 적었다.
///
/// 이벤트는 자리 번호만 싣는다 — 이름은 [LoreWorld] 에서 찾는다.
library;

import 'package:lore_world/lore_world.dart';

import 'josa.dart';
import 'names.dart';

/// 글자 색 — 앱의 `@X…@@` 표기(원작 16색 번호, 16진수 한 글자).
const String _red = 'C'; // 밝은 빨강 — 경고 · 위험
const String _cyan = 'B'; // 하늘색 — 시스템 알림
const String _yellow = 'E'; // 노랑 — 중요한 결과

String _paint(String colour, String text) => '@$colour$text@@';

/// 자리 [seat] 의 이름. 비었으면 「누군가」.
String _who(LoreWorld world, int? seat) {
  if (seat == null) return '누군가';
  final m = world.seats.length > seat ? world.seats[seat] : null;
  if (m == null) return '누군가';
  return memberName(m, episode: world.episode);
}

String _whoWith(LoreWorld world, int? seat, String pair) =>
    josa(_who(world, seat), pair);

// ── 거절 ────────────────────────────────────────────────────────

/// 거절 하나를 한 문장으로. [world] 를 주면 사람 이름을 넣는다.
String refusalLine(Refusal r, {LoreWorld? world}) {
  String who(String pair) =>
      world == null ? '' : '${_whoWith(world, r.seat, pair)} ';
  final thing = r.key == null ? '그것' : nameOf(r.key!);

  return switch (r.reason) {
    RefusalReason.noSuchMember => '그 자리에는 아무도 없습니다.',
    RefusalReason.invalidSeat => '고를 수 없는 사람입니다.',
    RefusalReason.invalidAmount => '그 수는 고를 수 없습니다.',
    RefusalReason.unknownItem => '알 수 없는 물건입니다.',
    RefusalReason.emptyName => '이름을 입력하십시오.',
    RefusalReason.nameTooLong => '이름은 한글 4자 또는 영문 8자까지입니다.',
    RefusalReason.invalidGender => '성별을 고르십시오.',
    RefusalReason.invalidAnswers => '모든 질문에 답해 주십시오.',
    RefusalReason.invalidPointSplit => '남아 있는 지수를 모두 나눠 주십시오.',
    RefusalReason.invalidSkillSplit => '기술치의 합이 맞지 않습니다.',
    RefusalReason.classRequirementNotMet => '그 계급이 되기에는 기술치가 모자랍니다.',
    RefusalReason.classNotSelectable => '고를 수 없는 계급입니다.',
    RefusalReason.alreadyThatClass => '이미 그 계급입니다.',
    RefusalReason.notFighterFamily => '당신은 전투사 계열이 아닙니다.',
    RefusalReason.notMageFamily => '당신은 마법사 계열이 아닙니다.',
    RefusalReason.skillAtCap => '이 분야는 더 배울 것이 없습니다.',
    RefusalReason.skillNotForClass => '당신의 계급과 맞지 않습니다.',
    RefusalReason.notEnoughExp => '아직 경험치가 모자랍니다.',
    // 지음 — 제1부: 스피카를 만나기 전.
    RefusalReason.espTrainingLocked => '아직 초자연력을 가르쳐 줄 사람이 없습니다.',
    RefusalReason.notEnoughGoldForClassChange =>
      '그러나 일행에게는 직업을 바꿀 때 드는 비용인 금 $classChangeFee개가 없습니다.',
    RefusalReason.notEnoughGold => '당신은 충분한 돈이 없습니다.',
    RefusalReason.atLimit => '$thing${particle(thing, '은/는')} 더 이상 가질 수 없습니다.',
    RefusalReason.notForSale => '$thing${particle(thing, '은/는')} 팔지 않습니다.',
    RefusalReason.wrongShop => '$thing${particle(thing, '은/는')} 여기서 팔지 않습니다.',
    RefusalReason.notInBackpack => '배낭에 $thing${particle(thing, '이/가')} 없습니다.',
    RefusalReason.slotOccupied => '이미 장착한 것이 있습니다. 먼저 해제하십시오.',
    RefusalReason.classCannotUse => '${who('은/는')}$thing${particle(thing, '을/를')} 쓸 수 없는 계급입니다.',
    RefusalReason.nothingEquipped => '장착한 것이 없습니다.',
    RefusalReason.backpackFull => '배낭이 가득 찼습니다.',
    RefusalReason.alreadyDead => '${who('은/는')}이미 죽은 상태입니다.',
    RefusalReason.alreadyUnconscious => '${who('은/는')}이미 의식 불명입니다.',
    RefusalReason.poisonSpreading => '${who('은/는')}독이 퍼진 상태입니다.',
    RefusalReason.noTreatmentNeeded => '${who('은/는')}치료할 필요가 없습니다.',
    RefusalReason.targetNotCurable => '${who('은/는')}치료될 상태가 아닙니다.',
    RefusalReason.notPoisoned => '${who('은/는')}독에 걸리지 않았습니다.',
    RefusalReason.notUnconscious => '${who('은/는')}의식 불명이 아닙니다.',
    RefusalReason.notDead => '${who('은/는')}아직 살아 있습니다.',
    // 지음 — 죽음 수치 10000 이상.
    RefusalReason.beyondRevival => '${who('은/는')}너무 오래전에 죽어서 약초로는 되살릴 수 없습니다.',
    RefusalReason.noneOwned => '하지만 $thing${particle(thing, '이/가')} 없습니다.',
    RefusalReason.userCannotAct => '${who('은/는')}물품을 사용할 수 있는 상태가 아닙니다.',
    RefusalReason.notMagicUser => '마법사 계열이 아닙니다.',
    RefusalReason.battleOnly => r.key == 'esp.telekinesis'
        ? '염력은 전투에서만 사용됩니다.'
        : '$thing${particle(thing, '은/는')} 전투에서만 쓸 수 있습니다.',
    RefusalReason.casterCannotAct => '${who('은/는')}마법을 사용할 수 있는 상태가 아닙니다.',
    RefusalReason.notMagicFamily => '마법을 사용할 수 없는 계열입니다.',
    RefusalReason.spellLocked => '아직 $thing${particle(thing, '을/를')} 쓸 수 있는 능력이 되지 않습니다.',
    RefusalReason.notEnoughMp => '마법 지수가 충분하지 않습니다.',
    RefusalReason.espTooWeak =>
      '${who('은/는')}$thing${particle(thing, '을/를')} 시도해 보았지만 아직은 역부족이었다.',
    RefusalReason.partyFull => '벌써 사람이 모두 채워져 있습니다.',
    RefusalReason.cannotDismissProtagonist => '당신은 일행을 떠날 수 없습니다.',
    RefusalReason.waterBlocked => '물 위를 걸을 수 없습니다.',
  };
}

// ── 사건 ────────────────────────────────────────────────────────

/// 결과 하나를 문장들로. 거절이면 그 까닭 한 줄.
///
/// 같은 문장이 사람마다 되풀이되는 경우(식량이 바닥났다)는 한 번만 낸다.
List<String> outcomeLines(Outcome outcome, LoreWorld world) {
  final refusal = outcome.refusal;
  if (refusal != null) return [refusalLine(refusal, world: world)];
  final lines = <String>[];
  for (final e in outcome.events) {
    for (final line in eventLines(e, world)) {
      if (lines.isNotEmpty && lines.last == line) continue;
      lines.add(line);
    }
  }
  return lines;
}

/// 사건 하나의 문장들. 화면에 낼 것이 없는 사건(지도 작업 요청, 조우 시작,
/// 게임 오버 — 앱이 따로 다룬다)은 빈 목록.
List<String> eventLines(LoreEvent e, LoreWorld world) {
  String who(int seat) => _who(world, seat);
  String w(int seat, String pair) => _whoWith(world, seat, pair);

  return switch (e) {
    // ── 일행 ──
    MemberJoined(:final seat) => ['${w(seat, '이/가')} 일행에 참가했다.'],
    AssistantSet() => [
      if (world.assistant != null)
        '${josa(memberName(world.assistant!, episode: world.episode), '이/가')} 보조 일원이 되었다.',
    ],
    MemberDismissed(:final name, :final nameKey) => [
      '${josa(name.isNotEmpty ? name : (nameKey == null ? '누군가' : nameOf(nameKey)), '이/가')} 일행에서 제외되었습니다.',
    ],
    SeatsSwapped() => ['일행의 순서가 변경되었습니다.'],
    CompanionsHidden() => const [],

    // ── 성장 ──
    SkillTrained(:final seat, :final skill, :final value) => [
      if (world.member(seat) case final m?)
        '${who(seat)}의 ${josa(skillName(m, skill), '이/가')} $value${particle('$value', '이/가')} 되었다.',
    ],
    AllCoursesCompleted() => ['모든 과정을 수료했으므로 모든 경험치를 레벨로 바꾸겠습니다.'],
    ClassChanged(:final seat, :final to) => [
      if (world.member(seat) case final m?)
        '${w(seat, '은/는')} 이제 ${classNameOf(m.family, to)} 계급이 되었다.',
    ],
    ExpTrained(:final hours) => ['일행은 $hours시간 동안 훈련을 받게 되었다.'],
    ExpGained(:final seat, :final amount) => ['${w(seat, '은/는')} $amount만큼 경험치를 얻었다!'],
    GoldGained(:final amount) => ['일행은 $amount개의 금을 얻었다.'],
    LevelUp(:final seat, :final level) => [
      _paint(_yellow, '${who(seat)}의 레벨은 $level입니다.'),
    ],
    AbilityRaised(:final seat, :final ability, :final value) => [
      '${who(seat)}의 ${josa(abilityName(ability), '이/가')} $value${particle('$value', '이/가')} 되었다.',
    ],

    // ── 장비 · 상점 · 병원 ──
    Equipped(:final seat, :final key) => ['${w(seat, '은/는')} ${nameWith(key, '을/를')} 장착했다.'],
    Unequipped(:final seat, :final key) => ['${w(seat, '은/는')} ${nameWith(key, '을/를')} 해제했다.'],
    EquipmentDiscarded(:final seat, :final key) => ['${w(seat, '은/는')} ${nameWith(key, '을/를')} 버렸다.'],
    WeaponBlessed(:final seat) => ['${_who(world, seat)}의 무기에 신의 축복이 내렸다.'],
    Purchased() => ['매우 고맙습니다.'],
    HospitalTreated(:final seat, :final treatment) => [
      switch (treatment) {
        Treatment.wounds => '${w(seat, '은/는')} 모든 건강이 회복되었다.',
        Treatment.poison => '${who(seat)}의 독이 제거되었습니다.',
        Treatment.consciousness => '${w(seat, '은/는')} 의식을 차렸습니다.',
        Treatment.revival => '${w(seat, '은/는')} 다시 살아났습니다.',
      },
    ],

    // ── 물품 · 마법 ──
    ItemUsed(:final key, :final remaining, :final consumed) => [
      if (consumed) '${nameWith(key, '은/는')} 이제 $remaining개 남았습니다.',
    ],
    SpellCast(:final key) => switch (key) {
      'magic.magic_torch' => ['일행은 마법의 횃불을 밝혔습니다.'],
      _ => const <String>[],
    },
    HpRestored(:final seat, :final full) => [
      full ? '${w(seat, '은/는')} 모든 건강이 회복되었다.' : '${w(seat, '은/는')} 치료되었다.',
    ],
    MpRestored(:final seat, :final amount) => ['${who(seat)}의 마법 지수가 $amount만큼 회복되었다.'],
    PoisonCured(:final seat) => ['${who(seat)}의 독이 제거되었다.'],
    Awakened(:final seat) => ['${w(seat, '은/는')} 의식을 되찾았다.'],
    Revived(:final seat) => ['${w(seat, '은/는')} 다시 살아났다.'],
    NoEffect(:final seat, :final reason) => [
      refusalLine(Refusal(reason, seat: seat), world: world),
    ],
    TorchChanged() => const [],
    BuffsGranted(:final buffs) => [
      for (final b in buffs)
        switch (b) {
          FieldBuff.levitation => '일행은 공중 부상 중입니다.',
          FieldBuff.waterWalk => '일행은 물 위를 걸을 수 있습니다.',
          FieldBuff.swampWalk => '일행은 늪 위를 걸을 수 있습니다.',
        },
    ],
    BuffsExpired() => const [],
    FoodCreated(:final added, :final total) => [
      '식량 제조 마법은 성공적으로 수행되었습니다.',
      '$added개의 식량이 증가됨',
      '일행의 현재 식량은 $total개입니다.',
    ],
    MindReadingStarted() => ['당신은 잠시 동안 다른 사람의 마음을 읽을 수 있다.'],
    // 지음 — 원작은 말없이 풀렸다. 진행 기록 창에만 낸다.
    MindReadingEnded() => ['독심의 효과가 사라졌다.'],
    MapActionNeeded() => const [],
    StoryCrystalUsed() => const [],

    // ── 휴식 ──
    RestMember(:final seat, :final result) => [
      switch (result) {
        RestResult.noFood => '일행은 식량이 바닥났다.',
        RestResult.dead => '${w(seat, '은/는')} 죽었다.',
        RestResult.regainedConsciousness => '${w(seat, '은/는')} 의식이 회복되었다.',
        RestResult.stillUnconscious => '${w(seat, '은/는')} 여전히 의식 불명이다.',
        RestResult.unconsciousAndPoisoned => '독 때문에 ${who(seat)}의 의식은 회복되지 않았다.',
        RestResult.poisoned => '독 때문에 ${who(seat)}의 건강은 회복되지 않았다.',
        RestResult.fullyRecovered => '${w(seat, '은/는')} 모든 건강이 회복되었다.',
        RestResult.healed => '${w(seat, '은/는')} 치료되었다.',
      },
    ],

    // ── 걸음 ──
    MemberHarmed(:final seat, :final amount, :final result, :final cause) => [
      // 필드의 독은 원작도 말없이 HP 만 깎았다 — 쓰러질 때만 말한다.
      if (cause != HarmCause.poison) '${w(seat, '은/는')} $amount만큼의 피해를 입었다.',
      if (result == DamageResult.fellUnconscious) _paint(_red, '${w(seat, '은/는')} 의식 불명이 되었다.'),
      if (result == DamageResult.died) _paint(_red, '${w(seat, '은/는')} 죽었다.'),
    ],
    EnteredSwamp(:final protected) => [
      if (!protected) _paint(_red, '일행은 독이 있는 늪에 들어갔다!!!'),
    ],
    MemberPoisoned(:final seat) => ['${w(seat, '은/는')} 중독되었다.'],
    EnteredLava() => [_paint(_red, '일행은 용암 지대로 들어섰다!!!')],
    EncounterStarted() => const [],
    GameOver() => const [],
  };
}

/// 시스템 알림 한 줄 — 「[ 황금 + 4 ]」 같은 획득·변화 알림 (제13장 13.5).
String noticeLine(String text) => _paint(_cyan, '[ $text ]');
