/// 전투 메뉴의 한국어 문구.
///
/// 문장과 같은 이유로 여기 있다 — **콘솔과 Flutter view 가 같은 것을 보여야**
/// 한다. 여백·정렬·그리는 방법은 읽는 쪽의 일이고, 여기에는 글과 색 번호만
/// 있다.
///
/// `hd_battle_text` 에서 갈라 왔고 **함수 이름은 그대로**다. 사라진 것은
/// 무기 도포에 딸린 셋뿐이다(`itemUseMenuHeader` · `itemUseLabel` ·
/// `coatingBadge`) — 로어에는 바르는 병이 없다.
library;

import 'package:lore_battle/lore_battle.dart';

import 'battle_lines.dart';
import 'item_names.dart';
import 'magic_names.dart';
import 'names.dart';
import 'noun.dart';

/// 공격 방식의 이름. 무기가 어떻게 닿는지를 한 낱말로.
String attackMethodName(AttackMethod method) => switch (method) {
  AttackMethod.slash => '베기',
  AttackMethod.pierce => '찌르기',
  AttackMethod.blunt => '타격',
};

/// 원작의 명령 메뉴 제목 — "{이름}의 전투 모드 ===>" (부록 E.6).
String actionMenuHeader(String memberName) => '$memberName의 전투 모드 ===>';

/// 최상위 메뉴 여섯 줄. 원작의 아홉 줄(8.4)을 접은 것이다.
///
/// 글자 하나가 앞에 붙는다 — 줄이 여섯이면 글자만 훑어도 찾을 수 있다.
String actionLabel(BattleAction action, {required String weaponName}) {
  switch (action) {
    case BattleAction.attack:
      final w = HDNoun(weaponName);
      return '⚔ 공격 — 한 명의 적을 $w${w.withJosa}';
    case BattleAction.castSkill:
      return '✨ 기술 — 마법 · 초능력 · 소환';
    case BattleAction.useItem:
      return '🎒 물품 — 약초나 크리스탈';
    case BattleAction.charge:
      final w = HDNoun(weaponName);
      return '🏇 파고들기 — 앞으로 나서며 $w${w.withJosa} 공격';
    case BattleAction.brace:
      return '🛡 버팀 — 앞에 서서 막는다';
    case BattleAction.escape:
      return '🏃 도망을 시도함 — 일행 전체';
    case BattleAction.orders:
      return '⚙ 지시 — 대열 · 무조건 공격';
    // 지시 하위 항목 (OrderDecision)
    case BattleAction.autoBattle:
      return '일행에게 무조건 공격 할 것을 지시';
    case BattleAction.advanceFormation:
      return '일행 전체가 앞으로 (이 턴은 공격하지 않음)';
    case BattleAction.retreatFormation:
      return '일행 전체가 물러남 (이 턴은 공격하지 않음)';
    case BattleAction.skip:
      return '아무것도 하지 않음';
  }
}

/// 범위 글자. 기술 목록이 하나가 된 대신 이것이 갈래를 말한다.
String scopeGlyph(SkillScope scope) => switch (scope) {
  SkillScope.oneEnemy => '🎯',
  SkillScope.allEnemies => '💥',
  SkillScope.curse => '☠',
  SkillScope.curseAll => '💀',
  SkillScope.oneAlly => '💚',
  SkillScope.allAllies => '💞',
  SkillScope.summon => '🌀',
};

/// 초능력은 범위 글자 대신 이것을 단다 — 마법이 아니라는 것이 먼저다.
/// **마법 지수는 같이 쓴다**(제3부는 지수가 하나다).
const String espGlyph = '🔮';

/// 기술 이름. [magicName] 과 같다 — `hd_battle_text` 에서 이 이름을 쓰던
/// 곳이 그대로 돌게 남겨 둔다.
String skillName(int magicId) => magicName(magicId);

/// 비용 표기. 대상에 따라 달라지면 `~`, 대상마다 내면 `×적` · `×명`.
String skillCostLabel(SkillOption option) {
  if (option.cost < 0) return 'MP ~';
  if (!option.perTarget) return 'MP ${option.cost}';
  final each = switch (option.scope) {
    SkillScope.allAllies || SkillScope.oneAlly => '명',
    _ => '적',
  };
  return 'MP ${option.cost}×$each';
}

/// 기술 목록 한 줄 — `🎯 마법 화살  MP 10`.
///
/// 못 쓰는 것도 줄에 남긴다 — 어둡게, 왜 안 되는지가 보이게. 원작은 쓸 수
/// 없는 단계를 검은색으로 그려 목록에서 사라지게 했다(부록 E.6).
String skillLine(SkillOption option) {
  final glyph = option.resource == SkillResource.esp
      ? espGlyph
      : scopeGlyph(option.scope);
  final name = skillName(option.magicId);
  final cost = skillCostLabel(option);
  if (!option.affordable) {
    return paintText(TextColor.darkGray, '$glyph $name  $cost  (부족)');
  }
  final color = switch (option.scope) {
    SkillScope.oneAlly || SkillScope.allAllies => TextColor.white,
    SkillScope.curse || SkillScope.curseAll => TextColor.lightMagenta,
    SkillScope.summon => TextColor.lightGreen,
    _ =>
      option.resource == SkillResource.esp
          ? TextColor.lightCyan
          : TextColor.lightRed,
  };
  return '${paintText(color, "$glyph $name")}  '
      '${paintText(TextColor.darkGray, cost)}';
}

/// 기술 목록 머리글.
const String skillMenuHeader = '기술 ===>';

// --- 목록이 길면 범위로 한 번 접는다 -------------------------------------
//
// 기술치가 모두 100 인 마법사는 56줄이다. 원작의 갈래 메뉴를 되살리지는
// 않는다 — 대신 **8줄을 넘을 때만** 첫 화면을 묶음으로 하고 두 번째 화면이
// 그 안 목록이다. model 은 모른다 — 답은 여전히 `ChooseSpell` 하나다.

/// 이 줄 수를 넘으면 접는다.
const int skillFoldThreshold = 8;

bool skillListFolds(List<SkillOption> options) =>
    options.length > skillFoldThreshold;

/// 접힌 첫 화면의 한 묶음 — 범위 + 갈래가 같은 것들.
class SkillGroup {
  const SkillGroup(this.scope, this.resource, this.options);

  final SkillScope scope;
  final SkillResource resource;
  final List<SkillOption> options;

  bool holds(SkillOption o) => o.scope == scope && o.resource == resource;
}

/// 목록 순서 그대로 묶는다 — 한 명 공격 · 전체 공격 · 약화 · 모두 약화 ·
/// 한 명 치료 · 모두 치료 · 초능력(한 명 / 전체) · 소환.
List<SkillGroup> skillGroups(List<SkillOption> options) {
  final groups = <SkillGroup>[];
  for (final o in options) {
    final i = groups.indexWhere((g) => g.holds(o));
    if (i < 0) {
      groups.add(SkillGroup(o.scope, o.resource, [o]));
    } else {
      groups[i].options.add(o);
    }
  }
  return groups;
}

String _groupName(SkillGroup g) {
  if (g.resource == SkillResource.esp) {
    return g.scope == SkillScope.allEnemies
        ? '$espGlyph 초능력 — 모든 적'
        : '$espGlyph 초능력 — 한 명';
  }
  return switch (g.scope) {
    SkillScope.oneEnemy => '🎯 한 명의 적에게 마법 공격',
    SkillScope.allEnemies => '💥 모든 적에게 마법 공격',
    SkillScope.curse => '☠ 적에게 특수 마법 공격',
    SkillScope.curseAll => '💀 모든 적에게 특수 마법 공격',
    SkillScope.oneAlly => '💚 한 명을 치료',
    SkillScope.allAllies => '💞 일행 모두를 치료',
    SkillScope.summon => '🌀 소환 마법',
  };
}

/// 묶음 이름과 개수 — `🎯 한 명의 적에게 마법 공격  10`.
String skillGroupLabel(SkillGroup g) {
  final usable = g.options.where((o) => o.affordable).length;
  final count = usable == g.options.length
      ? '${g.options.length}'
      : '$usable/${g.options.length}';
  return '${_groupName(g)}  ${paintText(TextColor.darkGray, count)}';
}

/// 접힌 첫 화면의 머리글.
const String skillGroupMenuHeader = '어떤 기술을 ===>';

/// 묶음 안 목록의 머리글 — `🎯 한 명의 적에게 마법 공격 ===>`.
String skillGroupHeader(SkillGroup g) => '${_groupName(g)} ===>';

/// 지시 목록 머리글.
const String orderMenuHeader = '지시 ===>';

/// 지시 항목 한 줄. [actionLabel] 의 하위 항목 문구를 그대로 쓴다.
String orderLabel(BattleAction action) => actionLabel(action, weaponName: '');

/// 물품 목록 머리글 — 원작의 "약초나 크리스탈을 사용" (8.4).
const String itemMenuHeader = '약초나 크리스탈을 사용 ===>';

/// 취소 줄의 글. 최상위에서 취소는 턴을 넘기는 것("잠시 주저했다")이고,
/// 하위 물음에서 취소는 한 단계 위로 가는 것이다 — 둘을 같은 글로 두면
/// 턴을 잃는 줄 안다.
const String cancelTopLabel = '이 턴을 넘긴다';
const String cancelBackLabel = '뒤로';

/// 이 물음에서 취소가 무엇인가.
String cancelLabelFor(BattleDecision decision) =>
    decision is ActionDecision ? cancelTopLabel : cancelBackLabel;

/// 화면에 늘어놓는 순서 — **앞열부터**. 묻는 순서와 같다.
///
/// 파티는 리더가 맨 위, 나머지는 열 → 슬롯. 자리를 비운 사람(정신 지배로
/// 넘어간 보조 일원)은 빠진다.
List<Combatant> partyInDisplayOrder(Battle battle) {
  final leader = leaderSlotOf(battle);
  final members = [
    for (final c in battle.party)
      if (c.isPresent) c,
  ];
  members.sort((a, b) {
    if (a.slot == leader) return -1;
    if (b.slot == leader) return 1;
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.slot.compareTo(b.slot);
  });
  return members;
}

/// 적 목록의 표시 순서 — 인덱스 목록. 앞열부터, 같은 열은 등록 순.
///
/// 원작처럼 번호 순으로 늘어놓고 싶으면 이것을 쓰지 않고 인덱스를 그대로
/// 쓰면 된다. 죽은 적은 줄을 남긴다(부록 E.2) — 빼지 않는다.
List<int> enemiesInDisplayOrder(Battle battle) {
  final ix = [for (var i = 0; i < battle.enemies.length; i++) i];
  ix.sort((a, b) {
    final byRank = battle.enemies[a].rank.compareTo(battle.enemies[b].rank);
    return byRank != 0 ? byRank : a.compareTo(b);
  });
  return ix;
}

/// 리더 = 명령을 받는 다섯 가운데 행동 가능한 가장 낮은 슬롯. model 의
/// 규칙(`Battle.leaderSlot`)을 그대로 읽는다.
int? leaderSlotOf(Battle battle) => battle.leaderSlot;

/// 물품 목록 한 줄 — `💚 체력 회복약`.
String itemLine(String key) {
  final glyph = itemGlyph(key);
  return glyph.isEmpty ? itemName(key) : '$glyph ${itemName(key)}';
}

/// 물품 목록 한 줄에 남은 개수까지 — `💚 체력 회복약  ×3`.
String itemLineWithCount(String key, int count) =>
    '${itemLine(key)}  ${paintText(TextColor.darkGray, "×$count")}';

/// 이 무기가 지금 이 거리에서 무엇을 하는지 한 줄로.
///
/// **거리 계산은 플레이어의 일이 아니다.** 닿으면 무엇으로 치는지, 안
/// 닿으면 무엇을 무는지(명중 벌점 · 앞열이 대신 맞을 확률)를 그대로 적는다.
/// 안 닿아도 목록에서 빼지 않는 것이 이 뼈대의 불변식이라, 무엇을 걸고
/// 있는지가 보여야 한다.
String reachVerdict({required WeaponAttack attack, required int distance}) {
  final short = attack.shortfall(distance);
  if (short == 0) {
    return paintText(
      TextColor.lightGreen,
      '닿음 · ${attackMethodName(attack.method)}',
    );
  }
  final penalty = reachPenalty(short);
  return paintText(
    TextColor.lightRed,
    '$short칸 부족 · 정확성 -${penalty.accuracy} · '
    '앞열이 대신 ${penalty.interception}%',
  );
}

/// 행동 메뉴 머리글에 붙는 자기 정보 — 열 · 무기 사거리 대역 · 간격.
String actionHeaderSuffix({
  required int rank,
  required WeaponProfile weapon,
  required int gap,
}) {
  final band = weapon.attacks
      .map((a) => '${attackMethodName(a.method)} ${a.minReach}~${a.maxReach}')
      .join(' / ');
  return '${paintText(TextColor.lightBlue, "$rank열")} '
      '${paintText(TextColor.darkGray, "· $band · 간격 $gap")}';
}

/// 적 목록 한 줄의 이름 — 이름표에서 찾은 표시 이름. 색은
/// `enemyNameColor` 가 따로 준다.
String enemyLabel(EnemyInstance enemy) => enemyDisplayName(enemy);
