import 'package:hd_battle/hd_battle.dart';

import 'item_names.dart';
import 'magic_names.dart';
import 'noun.dart';

/// `BattleEvent` 를 사람이 읽는 한국어 줄로 바꾼다.
///
/// **문장과 조사는 전부 여기서 만든다.** `hd_battle` 은 행위자·대상·수치만
/// 넘기고(코드에 한국어 0 이 불변조건이다), 원작이 쓰던 문장은 이 파일이
/// 재현한다. 콘솔과 Flutter view 가 **같은 문장**을 쓴다.
///
/// 원작에 **없던 줄**은 앞에 [addedMarker] 를 붙인다. 원작이 조용히
/// 지나가던 것들(독 피해, 골드 획득, 라운드 구분)이라 보여야 하지만,
/// "원작과 같은 출력" 을 눈으로 확인할 때 구분되어야 한다.

/// 원작에 없던 줄임을 나타내는 표시.
const String addedMarker = '\u00b7 ';

/// 슬롯·적 번호를 이름으로 바꾸는 방법.
///
/// 이 패키지가 `Battle` 을 들고 있지 않아도 되게 하려고 인터페이스로 뺐다 —
/// 호출자가 자기 방식으로 이름을 찾는다.
abstract interface class BattleNames {
  /// 파티 슬롯의 이름 (조사까지).
  HDNoun member(int slot);

  /// 적 번호의 이름.
  HDNoun enemy(int index);

  /// 그 슬롯이 든 무기의 표시 이름.
  String weapon(int slot);
}

/// 줄 안에서 수치만 다른 색으로 낼 때 쓰는 표기.
///
/// 원작이 하던 그대로다 — `hd_class_pc_enemy.cpp:346` 이 피해 수치를
/// `@D...@@` 로 감쌌다. 표기를 어떻게 그릴지는 읽는 쪽이 정한다.
String paintText(int colorIndex, Object text) {
  final code = colorIndex < 10
      ? String.fromCharCode(0x30 + colorIndex)
      : String.fromCharCode(0x41 + colorIndex - 10);
  return '@$code$text@@';
}

/// 줄 전체에 기본색을 입힌다. 안쪽 `@@` 까지 그 색으로 되돌린다.
///
/// ## 왜 그냥 감싸면 안 되나
///
/// 원작 파서에서 `@@` 는 **기본색 복귀**이지 바깥 색 복귀가 아니다
/// (`hd_base_gfx.cpp:141`, 앱의 `hd_text_utils.dart:53` 도 같다).
/// 그래서 `paintText(5, '슴갈은 @D30@@만큼…')` 처럼 감싸면 수치 뒤가
/// 5번이 아니라 **기본색**으로 떨어진다 — 줄의 절반이 색을 잃는다.
///
/// 안쪽 `@@` 를 바깥 색 지정으로 바꿔서 그것을 없앤다. 콘솔은 renderer 가
/// `defaultColor` 를 알고 있어 필요 없지만, 색을 문자열로만 주고받는 쪽
/// (앱의 `UiHost.addLog`)에는 필요하다.
String withDefaultColor(String line, int colorIndex) {
  final code = paintText(colorIndex, '').substring(0, 2);
  return '$code${line.replaceAll('@@', code)}';
}

/// 일행이 준 피해의 수치. 줄은 7번인데 **수치만 15번**이다.
///
/// C++ 은 수치도 7번으로 내면서 `// 원래는 중간이 15번 색` 이라고 스스로
/// 적어 두었다(`hd_class_pc_player.cpp:1074,1185`). C++ 은 정본이 아니고
/// 스스로 표시한 자리이므로 원래 형태로 되돌린다(6차 판정).
String highlightDealt(int amount) => paintText(TextColor.white, amount);

/// 일행이 받은 피해의 수치. 줄은 5번, **수치만 13번**.
String highlightTaken(int amount) => paintText(TextColor.lightMagenta, amount);

/// 원작 16색 팔레트의 색 번호에 이름을 붙인 것.
///
/// 값의 출처와 근거는 `GROUND_TRUTH` 부록 V. 그리는 방법은 읽는 쪽의 일이라
/// 여기에는 번호만 있다.
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

List<String> battleLines(BattleEvent event, BattleNames names) {
  switch (event) {
    case EnemiesAppeared(:final enemyIndices):
      if (enemyIndices.isEmpty) return const [];
      // 원작 `battle.dart:70-88`: 같은 이름을 묶어 "이름 x N" 으로 만들고,
      // 조사는 **첫 적** 것을 쓴다(이름이 여러 개여도). 그 특성까지 그대로.
      final counts = <String, int>{};
      for (final i in enemyIndices) {
        final name = names.enemy(i).text;
        counts[name] = (counts[name] ?? 0) + 1;
      }
      final labels = [
        for (final e in counts.entries)
          if (e.value > 1) '${e.key} x ${e.value}' else e.key,
      ];
      return [
        '${labels.join(", ")} ${names.enemy(enemyIndices.first).sub2} 나타났다 !',
      ];

    case RoundStarted(:final round):
      return ['$addedMarker--- $round번째 턴 ---'];

    case ActionSkipped():
      // 원작은 취소하면 콘솔만 지우고 아무 줄도 남기지 않았다.
      return const [];

    case NoSpellAvailable():
      return ['사용 가능한 기술이 없습니다.'];

    case NotEnoughSpellPoints(:final usesEsp):
      return [usesEsp ? 'ESP 지수가 충분하지 않습니다.' : '마법 지수가 충분하지 않습니다.'];

    case SpellCast(:final slot, :final magicId):
      final p = names.member(slot);
      final m = HDNoun(magicName(magicId));
      return ['$p${p.sub1} $m${m.obj} 시전했다!'];

    case MemberHealed(:final slot, :final amount):
      final t = names.member(slot);
      return ['$t의 상처가 $amount 회복되었다.'];

    case MemberCured(:final slot):
      final t = names.member(slot);
      return ['$t${t.sub1} 독에서 벗어났다.'];

    case MemberRevived(:final slot):
      final t = names.member(slot);
      return ['$t${t.sub2} 의식을 되찾았다.'];

    case MemberResurrected(:final slot):
      // 부활은 **의식불명 상태로** 돌려놓는다 — 완전 회복에는 의식 돌림이
      // 더 필요하다(`rules/cure.dart`).
      final t = names.member(slot);
      return ['$t${t.sub2} 되살아났다. 아직 의식은 없다.'];

    case CureHadNoEffect():
      return ['치료할 상처가 없었다.'];

    case AttackMissed(:final slot):
      return ['${names.member(slot)}의 공격은 빗나갔다....'];

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
        return ['${moves.join(", ")} — 간격은 그대로 $to'];
      }
      return ['${moves.join(", ")}. 간격 $from → $to'];

    case Charged(:final slot, :final toRank):
      final p = names.member(slot);
      return ['$p${p.sub2} 앞으로 파고들었다! ($toRank열)'];

    case Braced(:final slot, :final toRank):
      final p = names.member(slot);
      return ['$p${p.sub2} $toRank열에서 방패를 세우고 버틴다'];

    case AttackerShovedBack(:final slot, :final enemyIndex, :final toRank):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      return ['$p${p.sub2} 방패로 $t${t.obj} 밀쳐냈다. ($toRank열)'];

    case DodgedBack(:final slot, :final toRank):
      final p = names.member(slot);
      return ['$p${p.sub2} 몸을 던져 물러났다 — 아슬아슬하게 피했다. ($toRank열)'];

    case EnemyPushedBack(:final enemyIndex, :final toRank):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub2} 뒤로 밀려났다. ($toRank열)'];

    case EnemyCornered(:final enemyIndex, :final extraDamage):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 더 물러설 곳이 없다! (+${highlightDealt(extraDamage)})'];

    case MemberPushedBack(:final slot, :final toRank):
      final t = names.member(slot);
      return ['$t${t.sub2} 뒤로 밀려났다. ($toRank열)'];

    case MemberCornered(:final slot, :final extraDamage):
      final t = names.member(slot);
      return ['$t${t.sub1} 더 물러설 곳이 없다! (+${highlightTaken(extraDamage)})'];

    case AttackStrained(:final slot, :final enemyIndex, :final shortBy):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      return ['$p${p.sub1} $shortBy칸 멀리 있는 $t${t.obj} 향해 몸을 뻗었다'];

    case AttackIntercepted(
      :final slot,
      :final intendedIndex,
      :final actualIndex,
    ):
      final p = names.member(slot);
      final want = names.enemy(intendedIndex);
      final got = names.enemy(actualIndex);
      return ['앞을 막아선 $got${got.sub2} $p의 공격을 $want 대신 받아냈다'];

    case EnemyAttackStrained(:final enemyIndex, :final slot, :final shortBy):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      return ['$e${e.sub1} $shortBy칸 떨어진 $t${t.obj} 향해 몸을 뻗었다'];

    case EnemyAttackIntercepted(
      :final enemyIndex,
      :final intendedSlot,
      :final actualSlot,
    ):
      final e = names.enemy(enemyIndex);
      final want = names.member(intendedSlot);
      final got = names.member(actualSlot);
      return ['앞에 선 $got${got.sub2} $e의 공격을 $want 대신 받아냈다'];

    case EnemyBlocked(
      :final slot,
      :final enemyIndex,
      :final kind,
      :final source,
    ):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      final what = source == DamageSource.spell ? '마법' : '공격';
      return switch (kind) {
        BlockKind.resisted => ['$t${t.sub1} $p의 $what을 저지했다'],
        BlockKind.absorbed => ['그러나 $t${t.sub1} $p의 $what을 막았다'],
      };

    case SpellMissed(:final slot, :final enemyIndex):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      return ['그러나, $p의 마법은 $t${t.obj} 빗나갔다'];

    case DebuffApplied(:final enemyIndex, :final detail):
      final t = names.enemy(enemyIndex);
      return [
        switch (detail) {
          DebuffDetail.poisonStacked => '$t${t.sub2} 중독 되었다',
          DebuffDetail.specialRemoved => '$t의 특수 공격 능력이 제거되었다',
          DebuffDetail.armourLowered => '$t의 방어 능력이 저하되었다',
          DebuffDetail.resistanceLowered => '$t의 저항력이 저하되었다',
          DebuffDetail.abilityLowered => '$t의 전체적인 능력이 저하되었다',
          DebuffDetail.castingLowered => '$t의 마법 능력이 저하되었다',
          DebuffDetail.castingRemoved => '$t의 마법 능력은 사라졌다',
          DebuffDetail.superhumanLowered => '$t의 초자연적 능력이 저하되었다',
          DebuffDetail.superhumanRemoved => '$t의 초자연적 능력은 사라졌다',
        },
      ];

    case DebuffFailed(:final magicId, :final resisted):
      final m = magicName(magicId);
      return [resisted ? '$m 공격은 저지 당했다' : '$m 공격은 빗나갔다'];

    case EnemyDamaged(
      :final slot,
      :final enemyIndex,
      :final amount,
      :final source,
      :final whileCollapsed,
    ):
      final t = names.enemy(enemyIndex);
      if (whileCollapsed) {
        // B2-03: 쓰러진 대상에게 들어간 피해는 HP 가 아니라 의식불명
        // 누적값으로 쌓인다. 원작에 없던 줄이다.
        final p = names.member(slot);
        return [
          '$addedMarker$p${p.sub1} 쓰러진 $t${t.obj} 다시 내리쳤다 (${highlightDealt(amount)})',
        ];
      }
      if (source == DamageSource.spell) {
        return ['$t에게 ${highlightDealt(amount)}의 데미지!'];
      }
      final p = names.member(slot);
      final w = HDNoun(names.weapon(slot));
      return [
        '$p${p.sub1} $w${w.withJosa} $t${t.obj} 공격하여 ${highlightDealt(amount)} 데미지!',
      ];

    case EnemyCollapsed(:final slot, :final enemyIndex, :final source):
      // 원작은 "죽었다"·"치명상을 입었다" 로 끝을 알렸지만, B2-04 이후
      // hp 0 은 **사망이 아니라 붕괴**다. 문구를 그에 맞춘다.
      final t = names.enemy(enemyIndex);
      if (source == DamageSource.spell) return ['$t${t.sub2} 쓰러졌다.'];
      return ['$t${t.sub1} ${names.member(slot)}의 공격으로 치명상을 입었다'];

    case EnemyFinished(:final slot, :final enemyIndex):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      return ['$p${p.sub1} 의식불명 상태인 $t${t.obj} 가볍게 처치했다!'];

    case EscapeAttempted(:final slot, :final gap):
      // B6-04: 파티 행동. 리더가 명령하고 한 번 굴린다. 간격이 도움이 됐는지
      // 보이게 적는다 — 그것이 후퇴를 먼저 하는 이유다.
      final p = names.member(slot);
      final how = gap > 0 ? ' (간격 $gap 만큼 유리)' : '';
      return ['$p의 신호에 일행이 도망을 시도했다...$how'];

    case EscapeFailed():
      return ['그러나 실패했다. 일행은 이 턴을 잃었다.'];

    case EscapeSucceeded():
      // 원작은 성공 줄을 따로 쓰지 않고 종료 시 "무사히 도망쳤다..." 만 냈다.
      return const [];

    case EnemyPoisonTick(:final enemyIndex, :final amount):
      // 원작은 독 피해를 **아무 줄도 남기지 않고** 처리했다
      // (`battle.dart:211-219`). 데모에서는 보이게 한다.
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub2} 독으로 $amount 피해를 입었다.'];

    case EnemyCollapsedFromPoison(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub2} 독으로 의식을 잃었다.'];

    case EnemyDiedFromPoison(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub2} 독으로 죽었다.'];

    case EnemyUsedSpecial(:final enemyIndex):
      final e = names.enemy(enemyIndex);
      return ['$e${e.sub2} 마법/특수 능력을 사용했다!'];

    case EnemyHealedSelf(:final enemyIndex, :final amount):
      final e = names.enemy(enemyIndex);
      return ['$e${e.sub2} 스스로를 $amount 회복했다.'];

    case EnemyHealedAlly(:final enemyIndex, :final targetIndex, :final amount):
      final e = names.enemy(enemyIndex);
      final t = names.enemy(targetIndex);
      return ['$e${e.sub2} $t${t.obj} $amount 회복시켰다.'];

    case EnemyRevivedAlly(:final targetIndex, :final fromDeath):
      final t = names.enemy(targetIndex);
      return [fromDeath ? '$t${t.sub2} 되살아났다!' : '$t${t.sub2} 의식을 되찾았다.'];

    case MemberArmourWorn(:final slot):
      final t = names.member(slot);
      return ['$t의 방어구가 삭아 내렸다.'];

    case MemberLuckSaved(:final slot):
      final t = names.member(slot);
      return ['$t${t.sub1} 운 좋게 피했다.'];

    case EnemyAbilityUsed(:final enemyIndex, :final ability, :final slot):
      final e = names.enemy(enemyIndex);
      final what = switch (ability) {
        EnemySpecialKind.poison => '독 기운을 뿜었다',
        EnemySpecialKind.knockOut => '기절시키려 덤벼들었다',
        EnemySpecialKind.slay => '숨통을 끊으려 한다',
      };
      if (slot < 0) return ['$e${e.sub2} $what. 그러나 대상이 없었다.'];
      final t = names.member(slot);
      return ['$e${e.sub2} $t${t.obj} 향해 $what!'];

    case EnemyAbilityMissed():
      return ['그러나 빗나갔다.'];

    case ItemUsed(:final slot, :final itemKey):
      final p = names.member(slot);
      final n = HDNoun(itemName(itemKey));
      return ['$p${p.sub1} $n${n.obj} 사용했다!'];

    case ShieldBlocked(:final enemyIndex, :final slot):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      return ['$e의 공격을 $t${t.sub2} 방패로 막아냈다.'];

    case AffinityApplied(:final element, :final result):
      final name = switch (element) {
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
      return [
        result == AffinityKind.weak
            ? '$name 속성이 약점을 파고들었다!'
            : '$name 속성은 잘 통하지 않았다.',
      ];

    case EspHadNoEffect(:final slot, :final magicId):
      final p = names.member(slot);
      return ['$p${p.sub1} ${magicName(magicId)}을 써 보았으나 전투에는 쓸모가 없었다.'];

    case EnemyRecruited(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 우리의 편이 되었다!'];

    case MindControlFailed(:final reason):
      return [
        switch (reason) {
          MindControlFailure.immune => '독심술은 전혀 통하지 않았다',
          MindControlFailure.outmatched => '적의 마음을 끌어들이기에는 아직 능력이 부족했다',
          MindControlFailure.unmoved => '적의 마음은 흔들리지 않았다',
          MindControlFailure.notAffordable => '초감각 지수가 부족했다',
        },
      ];

    case PsychokinesisRolled(:final slot, :final effect):
      final p = names.member(slot);
      return [
        switch (effect) {
          PsychokinesisKind.strikeOne => '주위의 돌들이 떠올라 적을 공격하기 시작한다',
          PsychokinesisKind.strikeAll => '공기중의 수소가 핵융합을 일으켜 적들에게 에너지를 방출한다',
          PsychokinesisKind.terrify => '$p${p.sub1} 적에게 공포심을 불어 넣었다',
          PsychokinesisKind.poison => '$p${p.sub1} 적의 신진 대사를 조절하여 체력을 약화시키려 한다',
          PsychokinesisKind.stopHeart => '$p${p.sub1} 염력으로 적의 심장을 멈추려 한다',
          PsychokinesisKind.illusion => '$p${p.sub1} 적을 환상속에 빠지게 하려한다',
        },
      ];

    case EnemyFled(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub2} 겁을 먹고는 도망 가버렸다'];

    case EnemyPoisoned(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub2} 중독 되었다'];

    case EnemyWeakened(:final enemyIndex, :final stat):
      final t = names.enemy(enemyIndex);
      return [
        switch (stat) {
          WeakenedStat.resistance => '$t의 저항력이 떨어졌다',
          WeakenedStat.endurance => '$t의 체력이 떨어졌다',
          WeakenedStat.agility => '$t의 민첩이 떨어졌다',
          WeakenedStat.accuracy => '$t의 명중이 떨어졌다',
          WeakenedStat.heart => '$t${t.sub2} 심장이 멎어 쓰러졌다',
        },
      ];

    case EnemySummoned(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$addedMarker$t${t.sub2} 새로 불려 나왔다!'];

    case MemberAbducted(:final slot):
      final t = names.member(slot);
      return ['$t${t.sub2} 적에게 끌려갔다! 일행에서 사라졌다.'];

    case MemberPoisoned(:final slot):
      final t = names.member(slot);
      return ['$t${t.sub2} 중독되었다.'];

    case MemberStruckDown(:final slot, :final killed):
      final t = names.member(slot);
      return [killed ? '$t${t.sub2} 그대로 숨을 거두었다!' : '$t${t.sub2} 의식을 잃었다!'];

    case MemberDied(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub1} 더 버티지 못하고 숨을 거두었다.'];

    case MemberBlocked(:final enemyIndex, :final slot, :final kind):
      final e = names.enemy(enemyIndex);
      final t = names.member(slot);
      // 원작은 이 두 줄을 서로 다른 색으로 냈다 — 적이 움직인 줄은
      // 13번, 막아낸 줄은 7번(`hd_class_pc_enemy.cpp:324-325`).
      // 줄 하나에 색 하나라는 규칙을 지키려고 앞줄에만 표기를 박는다.
      return [
        paintText(TextColor.lightMagenta, '$e${e.sub1} $t${t.obj} 공격했다.'),
        switch (kind) {
          BlockKind.resisted => '그러나, $t${t.sub1} 적의 공격을 저지했다.',
          BlockKind.absorbed => '그러나, $t${t.sub1} 적의 공격을 방어했다.',
        },
      ];

    case MemberDamaged(
      :final enemyIndex,
      :final slot,
      :final amount,
      :final source,
      :final whileCollapsed,
    ):
      final t = names.member(slot);
      final e = names.enemy(enemyIndex);
      if (whileCollapsed) {
        return [
          '$addedMarker$e${e.sub1} 쓰러진 $t${t.obj} 다시 공격했다 (${highlightTaken(amount)})',
        ];
      }
      if (source == DamageSource.spell) {
        return ['$t에게 ${highlightTaken(amount)} 데미지!'];
      }
      return ['$e${e.sub1} $t${t.obj} 공격하여 ${highlightTaken(amount)} 데미지!'];

    case MemberCollapsed(:final slot):
      final t = names.member(slot);
      return ['$t${t.sub1} 의식을 잃고 쓰러졌다.'];

    case MemberPoisonTick(:final slot, :final amount):
      // 원작은 파티 독을 전투 중에 아예 읽지 않았다 — B2-04 가 추가했다.
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub2} 독으로 $amount 피해를 입었다.'];

    case MemberCollapsedFromPoison(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub2} 독으로 의식을 잃었다.'];

    case MemberDiedFromPoison(:final slot):
      final t = names.member(slot);
      return ['$addedMarker$t${t.sub2} 독을 이기지 못하고 숨을 거두었다.'];

    case ExperienceSettled(:final total):
      return ['전투에서 승리하여 경험치 $total을 얻었다.'];

    case GoldSettled(:final amount):
      // 원작은 골드를 조용히 더했다(`battle.dart:294`).
      return ['$addedMarker금화 $amount을 얻었다.'];

    // --- 무기 도포 (B6-03) ---
    case WeaponCoated(:final slot, :final coating, :final rounds):
      final p = names.member(slot);
      final what = coatingName(coating);
      return ['$p${p.sub1} 무기에 $what을 발랐다. ($rounds턴 지속)'];

    case CoatingExpired(:final slot, :final coating):
      final p = names.member(slot);
      return ['$addedMarker$p의 무기에서 ${coatingName(coating)} 기운이 사라졌다.'];

    case EnemyStunned(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub2} 마비되어 몸이 굳었다!'];

    case EnemyLostTurn(:final enemyIndex):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} 마비로 움직이지 못했다.'];

    case CoatingResisted(:final enemyIndex, :final coating):
      final t = names.enemy(enemyIndex);
      return ['$t${t.sub1} ${coatingName(coating)} 기운을 견뎌냈다.'];

    case VialThrown(:final slot, :final enemyIndex, :final coating):
      final p = names.member(slot);
      final t = names.enemy(enemyIndex);
      final what = HDNoun('${coatingName(coating)}병');
      return ['$p${p.sub1} $t${t.obj} 향해 $what${what.obj} 던졌다!'];

    case MemberSpRestored(:final slot, :final amount):
      final t = names.member(slot);
      return ['$t의 마법 지수가 $amount 회복되었다.'];

    case BattleEnded(:final code):
      return switch (code) {
        BattleResultCode.lose => ['파티가 전멸했습니다.'],
        BattleResultCode.evade => ['무사히 도망쳤다...'],
        BattleResultCode.win => const [],
        BattleResultCode.none => ['$addedMarker[경고] 결과 없이 전투가 끝났다.'],
      };
  }
}

// --- 색 ------------------------------------------------------------

/// 한 이벤트가 만드는 줄의 색.
///
/// 지어낸 것이 아니라 원작에서 캐낸 것이다. 원작의 모든 전투 메시지는
/// `writeConsole(색번호, 인자수, ...)` 로 나갔고, 그 첫 인자가 색이다
/// (`REF_hadar/src/hadar/hd_base_extern.cpp:241`). 그 호출들을 훑어서
/// 얻은 규칙은 이렇다.
///
/// | 색 | 뜻 | 원작 예 |
/// |---|---|---|
/// | 12 밝은 빨강 | **일행이 움직인 줄** | `pc_player.cpp:1010,1035,1064` |
/// | 13 밝은 자홍 | **적이 움직인 줄** | `pc_enemy.cpp:324,575,704,795` |
/// | 7 밝은 회색 | 빗나감·저지·막힘·실패 | `pc_enemy.cpp:309`, `pc_player.cpp:1041` |
/// | 5 자홍 | **일행이 입은 피해** | `pc_enemy.cpp:346,488,909` |
/// | 4 빨강 | 상태가 나빠짐 (중독·의식불명·사망·약화) | `pc_enemy.cpp:589,615,646` |
/// | 15 하양 | 치료 성공·금화 | `pc_player.cpp:1963`, `game_main.cpp:368` |
/// | 14 노랑 | 경험치 | `pc_player.cpp:2160` |
/// | 11 밝은 청록 | 도주 성공·적 영입 | `pc_player.cpp:1486,1890` |
/// | 10 밝은 초록 | 적이 겁먹고 달아남 | `pc_player.cpp:1618` |
///
/// 원작에 대응하는 줄이 없는 이벤트(B2 가 새로 만든 것들)는 위 뜻을
/// 그대로 따라 붙였다. 판정에 쓰이지 않는 진행 표시(턴 구분)만 8번이다.
int battleLineColor(BattleEvent event) => switch (event) {
  // 판 자체에 대한 줄
  EnemiesAppeared() => TextColor.lightRed,
  RoundStarted() => TextColor.darkGray,
  ActionSkipped() => TextColor.lightGray,

  // 진형이 움직인 줄 (B5-03)
  FormationResolved() => TextColor.yellow,
  Charged() => TextColor.lightRed,
  Braced() => TextColor.lightCyan,

  // 밀쳐내기와 회피 후퇴 (B5-07)
  AttackerShovedBack() => TextColor.lightCyan,
  DodgedBack() => TextColor.lightCyan,

  // 밀려난 줄 — 약점을 찌른 보상이자 위치가 움직이는 사건 (B5-06)
  EnemyPushedBack() => TextColor.lightCyan,
  MemberPushedBack() => TextColor.magenta,
  // 벽에 몰린 줄
  EnemyCornered() => TextColor.lightRed,
  MemberCornered() => TextColor.red,

  // 사거리가 모자란 줄. 무효가 아니라 벌점이라 회색이다 (B5-01)
  AttackStrained() => TextColor.lightGray,
  EnemyAttackStrained() => TextColor.lightGray,
  // 앞열이 대신 맞은 줄은 그 자체로 사건이다
  AttackIntercepted() => TextColor.lightCyan,
  EnemyAttackIntercepted() => TextColor.lightCyan,

  // 일행이 움직인 줄
  SpellCast() => TextColor.lightRed,
  ItemUsed() => TextColor.lightRed,
  EscapeAttempted() => TextColor.lightRed,
  AttackMissed() => TextColor.lightRed,
  // 적이 입은 피해 줄만 7번이다 — 수치는 `_hit` 이 15번으로 낸다
  EnemyDamaged() => TextColor.lightGray,
  EnemyCollapsed() => TextColor.lightRed,
  EnemyFinished() => TextColor.lightRed,
  EnemyCollapsedFromPoison() => TextColor.lightRed,
  EnemyDiedFromPoison() => TextColor.lightRed,

  // 적이 움직인 줄
  EnemyUsedSpecial() => TextColor.lightMagenta,
  EnemyAbilityUsed() => TextColor.lightMagenta,
  EnemyHealedSelf() => TextColor.lightMagenta,
  EnemyHealedAlly() => TextColor.lightMagenta,
  EnemyRevivedAlly() => TextColor.lightMagenta,
  EnemySummoned() => TextColor.lightMagenta,
  MemberBlocked() => TextColor.lightGray, // 앞줄만 13번을 직접 박는다
  // 빗나감·저지·막힘·실패·안내
  NoSpellAvailable() => TextColor.lightGray,
  NotEnoughSpellPoints() => TextColor.lightGray,
  CureHadNoEffect() => TextColor.lightGray,
  EnemyBlocked() => TextColor.lightGray,
  SpellMissed() => TextColor.lightGray,
  DebuffFailed() => TextColor.lightGray,
  EscapeFailed() => TextColor.lightGray,
  EnemyAbilityMissed() => TextColor.lightGray,
  ShieldBlocked() => TextColor.lightGray,
  MemberLuckSaved() => TextColor.lightGray,
  EspHadNoEffect() => TextColor.lightGray,
  MindControlFailed() => TextColor.lightGray,
  PsychokinesisRolled() => TextColor.lightGray,
  EnemyPoisonTick() => TextColor.lightGray,

  // 일행이 입은 피해
  MemberDamaged() => TextColor.magenta,
  MemberArmourWorn() => TextColor.magenta,
  MemberPoisonTick() => TextColor.magenta,

  // 상태가 나빠졌다
  MemberPoisoned() => TextColor.red,
  MemberCollapsed() => TextColor.red,
  MemberStruckDown() => TextColor.red,
  MemberDied() => TextColor.red,
  MemberCollapsedFromPoison() => TextColor.red,
  MemberDiedFromPoison() => TextColor.red,
  MemberAbducted() => TextColor.red,
  DebuffApplied() => TextColor.red,
  EnemyPoisoned() => TextColor.red,

  // 무기 도포 (B6-03)
  WeaponCoated() => TextColor.lightGreen,
  CoatingExpired() => TextColor.darkGray,
  EnemyStunned() => TextColor.red,
  EnemyLostTurn() => TextColor.lightGray,
  CoatingResisted() => TextColor.lightGray,
  VialThrown() => TextColor.lightRed,
  MemberSpRestored() => TextColor.white,
  EnemyWeakened() => TextColor.red,

  // 치료는 성공했을 때만 하얗다
  MemberHealed() => TextColor.white,
  MemberCured() => TextColor.white,
  MemberRevived() => TextColor.white,
  MemberResurrected() => TextColor.white,

  // 크게 좋은 일
  EnemyRecruited() => TextColor.lightCyan,
  EscapeSucceeded() => TextColor.lightCyan,
  EnemyFled() => TextColor.lightGreen,

  // 속성 상성은 B2 가 새로 넣었다 — 약점은 일행이 잘한 것,
  // 저항은 잘 통하지 않은 것이라 위 두 뜻을 그대로 따른다.
  AffinityApplied(:final result) =>
    result == AffinityKind.weak ? TextColor.lightRed : TextColor.lightGray,

  // 정산
  ExperienceSettled() => TextColor.yellow,
  GoldSettled() => TextColor.white,
  BattleEnded(:final code) => switch (code) {
    BattleResultCode.win => TextColor.yellow,
    BattleResultCode.evade => TextColor.lightCyan,
    BattleResultCode.lose => TextColor.red,
    BattleResultCode.none => TextColor.lightRed,
  },
};
