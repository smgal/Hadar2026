import 'package:lore_battle/lore_battle.dart';

import 'item_names.dart';
import 'magic_names.dart';
import 'names.dart';
import 'noun.dart';

/// `BattleEvent` 를 사람이 읽는 한국어 줄로 바꾼다.
///
/// **문장과 조사는 전부 여기서 만든다.** `lore_battle` 은 행위자·대상·수치만
/// 넘기고(코드에 한국어 0 이 불변조건이다), 원작이 쓰던 문장은 이 파일이
/// 재현한다. 콘솔과 Flutter view 가 **같은 문장**을 쓴다.
///
/// 문장의 출처는 기획서 부록 E.7(원작 전투의 결과 문장과 색)과 제8·9장이다.
/// 띄어쓰기와 문장부호는 다듬었다 — 원작의 "빗나갔다 ...." · "얻었다 !" 를
/// "빗나갔다...." · "얻었다!" 로 쓴다.
///
/// 원작에 **없던 줄**은 앞에 [addedMarker] 를 붙인다. 두 종류다 — 원작이
/// 조용히 지나가던 것(독 피해, 분신 외의 상태 변화)과, 원작에 없던 위치
/// 규칙(사거리·대열·밀려남)이 만드는 줄.

/// 원작에 없던 줄임을 나타내는 표시.
const String addedMarker = '· ';

/// 줄 안에서 수치만 다른 색으로 낼 때 쓰는 표기 — `@D30@@`.
///
/// 원작이 하던 그대로다. 표기를 어떻게 그릴지는 읽는 쪽이 정한다.
String paintText(int colorIndex, Object text) {
  final code = colorIndex < 10
      ? String.fromCharCode(0x30 + colorIndex)
      : String.fromCharCode(0x41 + colorIndex - 10);
  return '@$code$text@@';
}

/// 줄 전체에 기본색을 입힌다. 안쪽 `@@` 까지 그 색으로 되돌린다.
///
/// 원작 파서에서 `@@` 는 **기본색 복귀**이지 바깥 색 복귀가 아니다. 그래서
/// 그냥 감싸면 수치 뒤가 기본색으로 떨어진다. 안쪽 `@@` 를 바깥 색 지정으로
/// 바꿔서 그것을 없앤다 — 색을 문자열로만 주고받는 쪽(앱의 로그)에 필요하다.
String withDefaultColor(String line, int colorIndex) {
  final code = paintText(colorIndex, '').substring(0, 2);
  return '$code${line.replaceAll('@@', code)}';
}

/// 일행이 준 피해의 수치. 줄은 회색인데 **수치만 흰색**이다(부록 E.7).
String highlightDealt(int amount) => paintText(TextColor.white, amount);

/// 일행이 받은 피해의 수치. 줄은 어두운 자주, **수치만 분홍**.
String highlightTaken(int amount) => paintText(TextColor.lightMagenta, amount);

/// 원작 16색 팔레트의 색 번호에 이름을 붙인 것. 그리는 방법은 읽는 쪽의
/// 일이라 여기에는 번호만 있다.
abstract final class TextColor {
  static const int black = 0;
  static const int blue = 1;
  static const int green = 2;
  static const int cyan = 3;
  static const int red = 4;
  static const int magenta = 5;
  static const int brown = 6;
  static const int lightGray = 7;
  static const int darkGray = 8;
  static const int lightBlue = 9;
  static const int lightGreen = 10;
  static const int lightCyan = 11;
  static const int lightRed = 12;
  static const int lightMagenta = 13;
  static const int yellow = 14;
  static const int white = 15;
}

/// 결과 줄에서 행위자를 가리키는 말 — "그"/"그녀", 모르면 이름.
String _he(BattleNames names, int slot) {
  final Object source = names;
  return source is BattleNarration
      ? source.pronoun(slot)
      : names.member(slot).text;
}

/// 무기 계통에 따른 동사 (부록 E.7).
String _strikeVerb(BattleNames names, int slot) {
  final Object source = names;
  if (source is! BattleNarration) return '공격했다';
  return switch (source.weaponKind(slot)) {
    WeaponKind.chop => '내려쳤다',
    WeaponKind.pierce => '찔렀다',
    WeaponKind.shoot => '쏘았다',
    WeaponKind.bare || WeaponKind.slash || WeaponKind.special => '공격했다',
  };
}

String _specialAttackName(EnemySpecial special) => switch (special) {
  EnemySpecial.poison => '독 공격',
  EnemySpecial.knockOut => '치명적 공격',
  EnemySpecial.slay => '죽음의 공격',
  EnemySpecial.none => '공격',
};

String _elementName(ElementKind element) => switch (element) {
  ElementKind.fire => '화염',
  ElementKind.ice => '냉기',
  ElementKind.lightning => '뇌전',
  ElementKind.force => '충격',
  ElementKind.mind => '정신',
  ElementKind.poison => '독',
  ElementKind.slash => '베기',
  ElementKind.pierce => '찌르기',
  ElementKind.blunt => '타격',
};

List<String> battleLines(BattleEvent event, BattleNames names) {
  switch (event) {
    // --- 판 ---------------------------------------------------------
    case EnemiesAppeared():
      return ['적이 출현했다 !!!'];

    case RoundStarted(:final round, :final enemyActsFirst):
      return [
        enemyActsFirst
            ? '$addedMarker--- $round번째 턴 (적이 먼저 움직인다) ---'
            : '$addedMarker--- $round번째 턴 ---',
      ];

    case ActionSkipped(:final slot):
      final p = names.member(slot);
      return ['$p${p.sub1} 잠시 주저했다'];

    case BattleEnded(:final code):
      return switch (code) {
        BattleResultCode.lose => ['일행은 모두 전투에서 패했다 !!'],
        // 도망 성공 줄은 `EscapeSucceeded` 가 이미 냈다.
        BattleResultCode.evade => const [],
        BattleResultCode.win => const [],
        BattleResultCode.none => ['$addedMarker[경고] 결과 없이 전투가 끝났다.'],
      };

    // --- 일행의 무기 공격 ---------------------------------------------
    case AttackDeclared(:final slot, :final enemyIndex):
      final p = names.member(slot);
      final w = HDNoun(names.weapon(slot));
      final t = names.enemy(enemyIndex);
      return [
        '$p${p.sub1} $w${w.withJosa} $t${t.obj} ${_strikeVerb(names, slot)}',
      ];

    case AttackMissed(:final slot):
      return ['${_he(names, slot)}의 공격은 빗나갔다....'];

    case OutOfArrows():
      return ['화살이 다 떨어져 공격할 수 없었다'];

    case EnemyBlocked(
      :final slot,
      :final enemyIndex,
      :final kind,
      :final source,
    ):
      final he = _he(names, slot);
      if (source == DamageSource.spell) {
        final t = names.enemy(enemyIndex);
        return switch (kind) {
          BlockKind.resisted => ['$t${t.sub1} $he의 마법을 저지했다'],
          BlockKind.absorbed => ['그러나, $t${t.sub1} $he의 마법 공격을 막았다'],
        };
      }
      return switch (kind) {
        BlockKind.resisted => ['적은 $he의 공격을 저지했다'],
        BlockKind.absorbed => ['그러나, 적은 $he의 공격을 막았다'],
      };

    case EnemyDamaged(:final enemyIndex, :final amount, :final source):
      if (source == DamageSource.spell) {
        final t = names.enemy(enemyIndex);
        return ['$t${t.sub1} ${highlightDealt(amount)}만큼의 피해를 입었다'];
      }
      return ['적은 ${highlightDealt(amount)}만큼의 피해를 입었다'];

    case EnemyCollapsed(:final slot, :final enemyIndex, :final source):
      final he = _he(names, slot);
      if (source == DamageSource.spell) {
        // 원작 표기가 무기 줄("의식불명")과 다르다 — 그대로 둔다.
        final t = names.enemy(enemyIndex);
        return ['$t${t.sub1} $he의 마법에 의해 의식불능이 되었다'];
      }
      return ['적은 $he의 공격으로 의식불명이 되었다'];

    case EnemyFinished(
      :final slot,
      :final enemyIndex,
      :final source,
      :final flavour,
    ):
      final he = _he(names, slot);
      if (source == DamageSource.spell) {
        return ['$he의 마법은 적을 완전히 제거해 버렸다'];
      }
      final t = names.enemy(enemyIndex);
      // 원작에서 가장 강렬한 네 문장 (부록 E.7).
      return [
        switch (flavour % 4) {
          0 => '$he의 무기가 $t의 심장을 꿰뚫었다',
          1 => '$t의 머리는 $he의 공격으로 산산 조각이 났다',
          2 => '적의 피가 사방에 뿌려졌다',
          _ => '적은 비명과 함께 찢겨 나갔다',
        },
      ];

    case ExperienceGained(:final slot, :final amount):
      final p = names.member(slot);
      return [
        '$p${p.sub1} ${paintText(TextColor.lightCyan, amount)}만큼 경험치를 얻었다!',
      ];

    // --- 위치 (원작에 없던 층) ----------------------------------------
    case AttackStrained(:final slot, :final enemyIndex, :final shortBy):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$p${p.sub1} $shortBy칸 멀리 있는 $t${t.obj} 향해 몸을 뻗었다'];

    case AttackIntercepted(
      :final slot,
      :final intendedIndex,
      :final actualIndex,
    ):
      final p = names.member(slot);
      final want = names.enemy(intendedIndex);
      final got = names.enemy(actualIndex);
      return ['$addedMarker앞을 막아선 $got${got.sub2} $p의 공격을 $want 대신 받아냈다'];

    case FormationResolved(
      :final from,
      :final to,
      :final partyAdvanced,
      :final partyRetreated,
      :final enemyAdvanced,
      :final enemyRetreated,
    ):
      final moves = <String>[
        if (partyAdvanced) '일행이 앞으로 나섰다',
        if (partyRetreated) '일행이 물러섰다',
        if (enemyAdvanced) '적이 밀고 들어왔다',
        if (enemyRetreated) '적이 거리를 벌렸다',
      ];
      if (moves.isEmpty) return const [];
      if (from == to && moves.length > 1) {
        return ['$addedMarker${moves.join(", ")} — 간격은 그대로 $to'];
      }
      return ['$addedMarker${moves.join(", ")}. 간격 $from → $to'];

    case Charged(:final slot, :final toRank):
      final p = names.member(slot);
      return ['$addedMarker$p${p.sub2} 앞으로 파고들었다! ($toRank열)'];

    case Braced(:final slot, :final toRank):
      final p = names.member(slot);
      return ['$addedMarker$p${p.sub2} $toRank열에서 자세를 낮추고 버틴다'];

    case AttackerShovedBack(:final slot, :final enemyIndex, :final toRank):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$p${p.sub2} 방패로 $t${t.obj} 밀쳐냈다. ($toRank열)'];

    case DodgedBack(:final slot, :final toRank):
      final p = names.member(slot);
      return ['$addedMarker$p${p.sub2} 몸을 던져 물러났다 — 아슬아슬하게 피했다. ($toRank열)'];

    case EnemyPushedBack(:final enemyIndex, :final toRank):
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub2} 뒤로 밀려났다. ($toRank열)'];

    case EnemyCornered(:final enemyIndex, :final extraDamage):
      final t = names.enemy(enemyIndex);
      return [
        '$addedMarker$t${t.sub1} 더 물러설 곳이 없다! (+${highlightDealt(extraDamage)})',
      ];

    case MemberPushedBack(:final slot, :final toRank):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub2} 뒤로 밀려났다. ($toRank열)'];

    case MemberCornered(:final slot, :final extraDamage):
      final t = names.member(slot);
      return [
        '$addedMarker$t${t.sub1} 더 물러설 곳이 없다! (+${highlightTaken(extraDamage)})',
      ];

    case AffinityApplied(:final element, :final result):
      final name = _elementName(element);
      return [
        result == AffinityKind.weak
            ? '$addedMarker$name 속성이 약점을 파고들었다!'
            : '$addedMarker$name 속성은 잘 통하지 않았다.',
      ];

    // --- 일행의 마법 --------------------------------------------------
    case SpellCast(:final slot, :final magicId, :final enemyIndex):
      final p = names.member(slot);
      final m = HDNoun(magicName(magicId));
      switch (categoryOfSkill(magicId)) {
        case SkillCategory.attackOne:
        case SkillCategory.attackAll:
          final t = names.enemy(enemyIndex);
          return ["$p${p.sub1} '$m'${m.withJosa} $t에게 공격했다"];
        case SkillCategory.special:
          final t = names.enemy(enemyIndex);
          return ['$p${p.sub1} $t에게 $m${m.withJosa} 특수 공격을 했다'];
        case SkillCategory.esp:
          if (enemyIndex < 0) return ['$p${p.sub1} 모든 적에게 $m${m.obj} 사용했다'];
          final t = names.enemy(enemyIndex);
          return ['$p${p.sub1} $t에게 $m${m.obj} 사용했다'];
        case SkillCategory.summon:
          return ['$p${p.sub1} $m${m.obj} 시도했다'];
        case SkillCategory.cure:
        case null:
          // 원작의 치료는 명령을 고르는 자리에서 곧바로 결과만 나왔다.
          return ['$addedMarker$p${p.sub1} $m${m.obj} 사용했다'];
      }

    case NotEnoughSpellPoints():
      return ['마법 지수가 부족했다'];

    case SpellMissed(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['그러나, $t${t.obj} 빗나갔다'];

    case DebuffApplied(:final enemyIndex, :final detail):
      final t = names.enemy(enemyIndex);
      return [
        switch (detail) {
          DebuffDetail.specialRemoved => '$t의 특수 공격 능력이 제거되었다',
          DebuffDetail.defenceLowered => '$t의 방어 능력이 저하되었다',
          DebuffDetail.abilityLowered => '$t의 전체적인 능력이 저하되었다',
          DebuffDetail.castingLowered => '$t의 마법 능력이 저하되었다',
          DebuffDetail.castingRemoved => '$t의 마법 능력은 사라졌다',
          DebuffDetail.superhumanLowered => '$t의 초자연적 능력이 저하되었다',
          DebuffDetail.superhumanRemoved => '$t의 초자연적 능력은 사라졌다',
          DebuffDetail.poisoned => '$t${t.sub1} 중독 되었다',
        },
      ];

    case DebuffFailed(:final magicId, :final resisted):
      final m = magicName(magicId);
      return [resisted ? '$m 공격은 저지 당했다' : '$m 공격은 빗나갔다'];

    // --- 치료와 물품 --------------------------------------------------
    //
    // 원작은 전투 중 치료의 실패 문장을 생략하고(9.4) 성공은 상태 패널의
    // 숫자로만 알렸다. 기록만 읽어도 알 수 있도록 줄을 넣었다.
    case MemberHealed(:final slot, :final amount):
      final t = names.member(slot);
      return ['$addedMarker$t의 생명력이 $amount 회복되었다'];

    case MemberCured(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 독에서 벗어났다'];

    case MemberRevived(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 의식을 되찾았다'];

    case MemberResurrected(:final slot):
      // 부활은 **의식불명 상태로** 돌려놓는다 (9.4).
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 되살아났다. 아직 의식은 없다'];

    case CureHadNoEffect():
      return ['$addedMarker아무 일도 일어나지 않았다'];

    case MemberMpRestored(:final slot, :final amount):
      final t = names.member(slot);
      return ['$addedMarker$t의 마법 지수가 $amount 회복되었다'];

    case ItemUsed(:final slot, :final itemKey):
      final p = names.member(slot);
      final n = HDNoun(itemName(itemKey));
      return ['$p${p.sub1} $n${n.obj} 사용했다'];

    case CrystalDidNotReact(:final reason):
      return [
        switch (reason) {
          CrystalSilence.needsItsPair => '크리스탈은 전혀 반응하지 않았다.',
          CrystalSilence.wrongEnemy => '이 크리스탈은 선의 힘을 사용하는 적에게만 반응한다.',
        },
      ];

    case EnemyAged(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 순식간에 백여 년을 늙어 버렸다'];

    case EnemySoulWithered():
      return ['적의 영혼은 크리스탈에 의해 저주를 받아 황폐화 되어졌다.'];

    case PartyRestored():
      return ['$addedMarker크리스탈의 힘이 일행 모두를 일으켜 세웠다'];

    // --- 초능력과 소환 -------------------------------------------------
    case FusionUnleashed(:final flavour):
      // 원작은 두 문장 가운데 하나를 무작위로 낸다(9.6: 우라늄 핵분열 /
      // 수소 핵융합). 문장 자체는 기획서에 없어 요지로 썼다.
      return [
        flavour == 0
            ? '땅속의 우라늄이 핵분열을 일으켜 고온의 열기가 적들을 감쌌다'
            : '공기 중의 수소가 핵융합을 일으켜 그 에너지를 적들에게 쏟아부었다',
      ];

    case EnemyRecruited():
      return ['적은 우리의 편이 되었다'];

    case MindControlFailed(:final reason):
      return [
        switch (reason) {
          MindControlFailure.immune => '$addedMarker독심술은 전혀 통하지 않았다',
          MindControlFailure.outmatched => '아직 능력이 부족했다',
          MindControlFailure.unmoved => '$addedMarker적의 마음은 움직이지 않았다',
        },
      ];

    case EspHadNoEffect():
      return ['$addedMarker아무 일도 일어나지 않았다'];

    case EnemyWeakened(:final enemyIndex, :final stat):
      final t = names.enemy(enemyIndex);
      return [
        switch (stat) {
          WeakenedStat.resistance => '$addedMarker$t의 저항력이 떨어졌다',
          WeakenedStat.endurance => '$addedMarker$t의 인내력이 떨어졌다',
          WeakenedStat.agility => '$addedMarker$t의 민첩성이 떨어졌다',
          WeakenedStat.accuracy => '$addedMarker$t의 정확성이 떨어졌다',
        },
      ];

    case EnemyFled(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 겁을 먹고 도망가 버렸다'];

    case EnemyPoisoned(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 중독 되었다'];

    case EnemyStruckDown(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 의식불명이 되었다'];

    case AssistantJoined(:final source):
      // 설득은 "적은 우리의 편이 되었다" 가 이미 말했다.
      if (source == AssistantSource.persuasion) return const [];
      final a = names.member(assistantSeat);
      return ['$addedMarker$a${a.sub2} 나타나 일행의 곁에 섰다'];

    case EscapeAttempted():
      return ['일행은 도망을 시도했다'];

    case EscapeFailed():
      return ['그러나, 일행은 성공하지 못했다'];

    case EscapeSucceeded():
      return ['성공적으로 도망을 갔다'];

    // --- 적의 차례 ----------------------------------------------------
    case EnemyPoisonTick(:final enemyIndex, :final amount):
      // 원작은 독 피해를 문장 없이 수치만 바꿨다 (부록 E.7).
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub1} 독으로 $amount만큼의 피해를 입었다'];

    case EnemyCollapsedFromPoison(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub1} 독으로 의식불명이 되었다'];

    case EnemyDiedFromPoison(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub1} 독으로 죽었다'];

    case EnemyAttackMissed(:final enemyIndex):
      final e = names.enemy(enemyIndex);
      return ['$e${e.sub1} 빗맞추었다'];

    case EnemyAttackStrained(:final enemyIndex, :final slot, :final shortBy):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      return ['$addedMarker$e${e.sub1} $shortBy칸 떨어진 $t${t.obj} 향해 몸을 뻗었다'];

    case EnemyAttackIntercepted(
      :final enemyIndex,
      :final intendedSlot,
      :final actualSlot,
    ):
      final e = names.enemy(enemyIndex);
      final want = names.member(intendedSlot);
      final got = names.member(actualSlot);
      return ['$addedMarker앞에 선 $got${got.sub2} $e의 공격을 $want 대신 받아냈다'];

    case ShieldBlocked(:final enemyIndex, :final slot):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      // 두 줄의 색이 다르다 — 적이 움직인 줄은 분홍, 막아낸 줄은 회색.
      // 줄 하나에 색 하나라는 규칙을 지키려고 앞줄에만 표기를 박는다.
      return [
        paintText(TextColor.lightMagenta, '$e${e.sub1} $t${t.obj} 공격했다'),
        '그러나, $t${t.sub1} 방패로 적의 공격을 막았다',
      ];

    case MemberBlocked(
      :final enemyIndex,
      :final slot,
      :final kind,
      :final source,
    ):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      if (source == DamageSource.spell) {
        return [
          switch (kind) {
            BlockKind.resisted => '그러나, $t${t.sub1} 적의 마법을 저지했다',
            BlockKind.absorbed => '그러나, $t${t.sub1} 적의 마법을 막아냈다',
          },
        ];
      }
      return [
        paintText(TextColor.lightMagenta, '$e${e.sub1} $t${t.obj} 공격했다'),
        switch (kind) {
          BlockKind.resisted => '그러나, $t${t.sub1} 적의 공격을 저지했다',
          BlockKind.absorbed => '그러나, $t${t.sub1} 적의 공격을 방어했다',
        },
      ];

    case MemberDamaged(
      :final enemyIndex,
      :final slot,
      :final amount,
      :final source,
    ):
      final t = names.member(slot);
      final hurt = '$t${t.sub1} ${highlightTaken(amount)}만큼의 피해를 입었다';
      if (source == DamageSource.spell) return [hurt];
      final e = names.enemy(enemyIndex);
      return [
        paintText(TextColor.lightMagenta, '$t${t.sub1} $e에게 공격 받았다'),
        hurt,
      ];

    case MemberCollapsed(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 의식불명이 되었다'];

    case MemberDied(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 죽었다'];

    case EnemyCastSpell(:final enemyIndex, :final spell, :final slot):
      final e = names.enemy(enemyIndex);
      final m = enemySpellName(spell);
      if (slot < 0) return ["$e${e.sub1} 일행 모두에게 '$m'마법을 사용했다"];
      final t = names.member(slot);
      return ["$e${e.sub1} $t에게 '$m'마법을 사용했다"];

    case EnemySpellMissed(:final enemyIndex):
      final e = names.enemy(enemyIndex);
      return ['$e의 마법공격은 빗나갔다'];

    case EnemyHealedSelf(:final enemyIndex):
      final e = names.enemy(enemyIndex);
      return ['$e${e.sub1} 자신을 치료했다'];

    case EnemyHealedAlly(:final enemyIndex, :final targetIndex):
    case EnemyRevivedAlly(:final enemyIndex, :final targetIndex):
      final e = names.enemy(enemyIndex);
      final t = names.enemy(targetIndex);
      return ['$e${e.sub1} $t${t.obj} 치료했다'];

    case EnemyAbilityUsed(:final enemyIndex, :final ability, :final slot):
      final e = names.enemy(enemyIndex);
      final what = _specialAttackName(ability);
      if (slot < 0) return ['$e${e.sub1} $what을 시도했다'];
      final t = names.member(slot);
      return ['$e${e.sub1} $t에게 $what을 시도했다'];

    case EnemyAbilityMissed(:final ability):
      return ['${_specialAttackName(ability)}은 실패했다'];

    case MemberEvadedAbility(:final slot, :final ability):
      final t = names.member(slot);
      return ['그러나, $t${t.sub1} ${_specialAttackName(ability)}을 피했다'];

    case MemberAfflicted(
      :final slot,
      :final ability,
      :final enemyIndex,
      :final mass,
    ):
      final t = names.member(slot);
      if (mass) {
        final e = names.enemy(enemyIndex);
        return [
          switch (ability) {
            EnemySpecial.poison => '$t${t.sub1} $e에 의해 독에 감염 되었다.',
            EnemySpecial.knockOut => '$t${t.sub1} $e에 의해 의식불명이 되었다.',
            EnemySpecial.slay ||
            EnemySpecial.none => '$t${t.sub1} $e에 의해 급사 당했다.',
          },
        ];
      }
      return [
        switch (ability) {
          EnemySpecial.poison => '$t${t.sub1} 중독 되었다 !!',
          EnemySpecial.knockOut => '$t${t.sub1} 의식불명이 되었다 !!',
          EnemySpecial.slay || EnemySpecial.none => '$t${t.sub1} 죽었다 !!',
        },
      ];

    case ArmourBreakAttempted(:final enemyIndex, :final slot, :final broken):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      return [
        paintText(TextColor.lightMagenta, '$e${e.sub1} $t의 갑옷파괴를 시도했다'),
        broken ? '$t의 갑옷은 파괴되었다' : '그러나, $e${e.sub1} 성공하지 못했다',
      ];

    case EnemySummoned(:final callerIndex, :final enemyIndex):
      final e = names.enemy(callerIndex);
      final t = names.enemy(enemyIndex);
      return ['$e${e.sub1} $t${t.obj} 생성시켰다'];

    case MemberAbducted(:final enemyIndex, :final newEnemyIndex):
      // 넘어간 뒤이므로 이름은 적 목록에서 찾는다. 원작은 목적격을 틀리게
      // 썼다(부록 A #40) — 바로잡은 형태다.
      final e = names.enemy(enemyIndex);
      final a = names.enemy(newEnemyIndex);
      return ['$e${e.sub1} 독심술을 사용하여 $a${a.obj} 자기편으로 끌어들였다'];

    case EnemyClonesShifted():
      // 원작도 문장이 없다 — 적 목록만 다시 그려진다.
      return const [];

    case MemberPoisonTick(:final slot, :final amount):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 독으로 $amount만큼의 피해를 입었다'];

    case MemberCollapsedFromPoison(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 독으로 의식불명이 되었다'];

    case MemberDiedFromPoison(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 독을 이기지 못하고 죽었다'];

    // --- 정산 ---------------------------------------------------------
    case GoldSettled(:final amount):
      return ['일행은 $amount개의 금을 얻었다.'];
  }
}

// --- 색 ------------------------------------------------------------

/// 한 이벤트가 만드는 줄의 색 — 부록 E.7 의 표다.
///
/// | 색 | 뜻 |
/// |---|---|
/// | 15 흰색 | 일행이 움직인 줄, 승리의 금화 |
/// | 7 회색 | 빗나감·저지·막힘, 적이 입은 피해(수치만 흰색) |
/// | 12 빨강 | 적을 쓰러뜨림·마무리 |
/// | 14 노랑 | 경험치 (수치만 하늘색) |
/// | 13 분홍 | 적이 움직인 줄, 조우, 패배 |
/// | 5 어두운 자주 | 대원이 입은 피해 (수치만 분홍) |
/// | 4 어두운 빨강 | 치명적인 결과 — 중독·의식불명·죽음 |
/// | 11 하늘색 | 도망 성공 |
///
/// 원작에 대응하는 줄이 없는 이벤트(위치 규칙, 조용히 지나가던 것들)는
/// 위 뜻을 따라 붙였고, 판정과 무관한 진행 표시만 8번이다.
int battleLineColor(BattleEvent event) => switch (event) {
  // 판
  EnemiesAppeared() => TextColor.lightMagenta,
  RoundStarted() => TextColor.darkGray,
  ActionSkipped() => TextColor.white,
  BattleEnded(:final code) => switch (code) {
    BattleResultCode.win => TextColor.white,
    BattleResultCode.evade => TextColor.lightCyan,
    BattleResultCode.lose => TextColor.lightMagenta,
    BattleResultCode.none => TextColor.lightRed,
  },

  // 일행이 움직인 줄
  AttackDeclared() => TextColor.white,
  SpellCast() => TextColor.white,
  ItemUsed() => TextColor.white,
  EscapeAttempted() => TextColor.white,
  Charged() => TextColor.white,
  Braced() => TextColor.white,

  // 빗나감·저지·막힘·실패
  AttackMissed() => TextColor.lightGray,
  OutOfArrows() => TextColor.lightGray,
  EnemyBlocked() => TextColor.lightGray,
  NotEnoughSpellPoints() => TextColor.lightGray,
  SpellMissed() => TextColor.lightGray,
  DebuffFailed() => TextColor.lightGray,
  CureHadNoEffect() => TextColor.lightGray,
  CrystalDidNotReact() => TextColor.lightGray,
  MindControlFailed() => TextColor.lightGray,
  EspHadNoEffect() => TextColor.lightGray,
  EscapeFailed() => TextColor.lightGray,
  EnemyAttackMissed() => TextColor.lightGray,
  EnemySpellMissed() => TextColor.lightGray,
  EnemyAbilityMissed() => TextColor.lightGray,
  MemberEvadedAbility() => TextColor.lightGray,
  // 앞줄만 분홍을 직접 박는다
  ShieldBlocked() => TextColor.lightGray,
  MemberBlocked() => TextColor.lightGray,
  ArmourBreakAttempted(:final broken) =>
    broken ? TextColor.magenta : TextColor.lightGray,
  // 사거리가 모자란 줄. 무효가 아니라 벌점이라 회색이다
  AttackStrained() => TextColor.lightGray,
  EnemyAttackStrained() => TextColor.lightGray,
  AffinityApplied(:final result) =>
    result == AffinityKind.weak ? TextColor.white : TextColor.lightGray,

  // 적이 입은 피해 — 수치만 흰색
  EnemyDamaged() => TextColor.lightGray,
  EnemySoulWithered() => TextColor.lightGray,
  EnemyPoisonTick() => TextColor.lightGray,
  EnemyCornered() => TextColor.lightGray,

  // 적을 쓰러뜨림
  EnemyCollapsed() => TextColor.lightRed,
  EnemyFinished() => TextColor.lightRed,
  EnemyStruckDown() => TextColor.lightRed,
  EnemyCollapsedFromPoison() => TextColor.lightRed,
  EnemyDiedFromPoison() => TextColor.lightRed,

  // 적이 약해짐
  DebuffApplied() => TextColor.lightRed,
  EnemyWeakened() => TextColor.lightRed,
  EnemyPoisoned() => TextColor.lightRed,
  EnemyAged() => TextColor.lightRed,
  EnemyPushedBack() => TextColor.lightCyan,
  AttackIntercepted() => TextColor.lightCyan,
  AttackerShovedBack() => TextColor.lightCyan,
  DodgedBack() => TextColor.lightCyan,

  // 경험치·금화
  ExperienceGained() => TextColor.yellow,
  GoldSettled() => TextColor.white,

  // 치료
  MemberHealed() => TextColor.white,
  MemberCured() => TextColor.white,
  MemberRevived() => TextColor.white,
  MemberResurrected() => TextColor.white,
  MemberMpRestored() => TextColor.white,
  PartyRestored() => TextColor.white,

  // 크게 좋은 일
  EnemyRecruited() => TextColor.lightCyan,
  EnemyFled() => TextColor.lightGreen,
  EscapeSucceeded() => TextColor.lightCyan,
  AssistantJoined() => TextColor.lightCyan,
  FusionUnleashed() => TextColor.white,

  // 진형
  FormationResolved() => TextColor.yellow,

  // 적이 움직인 줄
  EnemyCastSpell() => TextColor.lightMagenta,
  EnemyHealedSelf() => TextColor.lightMagenta,
  EnemyHealedAlly() => TextColor.lightMagenta,
  EnemyRevivedAlly() => TextColor.lightMagenta,
  EnemyAbilityUsed() => TextColor.lightMagenta,
  EnemySummoned() => TextColor.lightMagenta,
  MemberAbducted() => TextColor.lightMagenta,
  EnemyAttackIntercepted() => TextColor.lightMagenta,
  EnemyClonesShifted() => TextColor.lightMagenta,

  // 대원이 입은 피해 — 수치만 분홍
  MemberDamaged() => TextColor.magenta,
  MemberPoisonTick() => TextColor.magenta,
  MemberPushedBack() => TextColor.magenta,
  MemberCornered() => TextColor.magenta,

  // 치명적인 결과
  MemberAfflicted(:final mass) => mass ? TextColor.lightMagenta : TextColor.red,
  MemberCollapsed() => TextColor.red,
  MemberDied() => TextColor.red,
  MemberCollapsedFromPoison() => TextColor.red,
  MemberDiedFromPoison() => TextColor.red,
};
