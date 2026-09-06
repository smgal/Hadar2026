/// 전투 메뉴의 한국어 문구.
///
/// 문장과 같은 이유로 여기 있다 — **콘솔과 Flutter view 가 같은 것을 보여야**
/// 한다(B4-01 의 "표현 격차 0"). 여백·정렬·그리는 방법은 읽는 쪽의 일이고,
/// 여기에는 글과 색 번호만 있다.
library;

import 'package:hd_battle/hd_battle.dart';

import 'battle_lines.dart';
import 'item_names.dart';
import 'magic_names.dart';
import 'noun.dart';

/// 공격 방식의 이름. 무기가 어떻게 닿는지를 한 낱말로 (B5-06).
String attackMethodName(AttackMethod method) => switch (method) {
  AttackMethod.slash => '베기',
  AttackMethod.pierce => '찌르기',
  AttackMethod.blunt => '타격',
};

/// 최상위 메뉴 여섯 줄 (B6-01). 원작의 열세 줄을 버렸다.
///
/// 글자 하나가 앞에 붙는다 — 줄이 여섯이면 글자만 훑어도 찾을 수 있다.
String actionLabel(BattleAction action, {required String weaponName}) {
  switch (action) {
    case BattleAction.attack:
      final w = HDNoun(weaponName);
      return '⚔ 공격 — $w${w.withJosa}';
    case BattleAction.castSkill:
      return '✨ 기술 — 마법과 초능력';
    case BattleAction.useItem:
      return '🎒 물건';
    case BattleAction.charge:
      final w = HDNoun(weaponName);
      return '🏇 파고들기 — 앞으로 나서며 $w${w.withJosa} 공격';
    case BattleAction.brace:
      return '🛡 버팀 — 앞에 서서 막는다';
    case BattleAction.escape:
      return '🏃 도망 — 일행 전체';
    case BattleAction.orders:
      return '⚙ 지시 — 대열 · 자동 전투';
    // 지시 하위 항목 (OrderDecision)
    case BattleAction.autoBattle:
      return '남은 일행 전원 자동 전투';
    case BattleAction.advanceFormation:
      return '일행 전체가 앞으로 (이 턴은 공격하지 않음)';
    case BattleAction.retreatFormation:
      return '일행 전체가 물러남 (이 턴은 공격하지 않음)';
    case BattleAction.skip:
      return '아무것도 하지 않음';
  }
}

/// 범위 글자 (B6-01). 기술 목록이 하나가 된 대신 이것이 갈래를 말한다.
String scopeGlyph(SkillScope scope) => switch (scope) {
  SkillScope.oneEnemy => '🎯',
  SkillScope.allEnemies => '💥',
  SkillScope.curse => '☠',
  SkillScope.oneAlly => '💚',
  SkillScope.allAllies => '💞',
  SkillScope.selfWeapon => '🌀',
};

/// 초능력은 범위 글자 대신 이것을 단다 — 자원이 다르다는 것이 먼저다.
const String espGlyph = '🔮';

/// 기술 이름. 전투 안에서만 다른 이름을 쓰는 것이 하나 있다 — 13 은
/// `magicNames` 에서 '독' 이지만 B6-02 이후 **무기에 바르는 것**이라
/// 그렇게 읽히게 한다. 표 자체는 세이브·cm2 와 이어져 있어 안 고친다.
String skillName(int magicId) =>
    magicId == coatingSpellId ? '독 바르기' : magicName(magicId);

/// 비용 표기. 가변이면 `~`.
String skillCostLabel(SkillOption option) {
  final unit = option.resource == SkillResource.esp ? 'ESP' : 'SP';
  return option.cost < 0 ? '$unit ~' : '$unit ${option.cost}';
}

/// 기술 목록 한 줄 (B6-01) — `🎯 마법 화살    SP 1`.
///
/// 못 쓰는 것도 줄에 남긴다 — 어둡게, 왜 안 되는지가 보이게. 전에는 목록에서
/// 사라져서 있는지조차 알 수 없었다. 여백은 읽는 쪽이 맞춘다; 여기는 글과
/// 색 번호만 있다.
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
    SkillScope.curse => TextColor.lightMagenta,
    SkillScope.selfWeapon => TextColor.lightGreen,
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
// 레벨 20 술사는 37줄이다. 갈래를 되살리지는 않는다 — 대신 **8줄을 넘을 때만**
// 첫 화면을 범위 글자(≤7)로 하고 두 번째 화면이 그 안 목록이다. 초반 파티는
// 한 화면. 세 view(콘솔 · 게임 메뉴 · 실험실)가 같은 규칙을 쓰도록 여기 둔다.
// model 은 모른다 — 답은 여전히 `ChooseSpell` 하나다.

/// 이 줄 수를 넘으면 접는다.
const int skillFoldThreshold = 8;

bool skillListFolds(List<SkillOption> options) =>
    options.length > skillFoldThreshold;

/// 접힌 첫 화면의 한 묶음 — 범위 + 자원이 같은 것들.
class SkillGroup {
  const SkillGroup(this.scope, this.resource, this.options);

  final SkillScope scope;
  final SkillResource resource;
  final List<SkillOption> options;

  bool holds(SkillOption o) => o.scope == scope && o.resource == resource;
}

/// 목록 순서 그대로 묶는다 — 단일 · 전체 · 도포 · 저주 · 치료 · 모두 치료 · 초능력.
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

/// 묶음 이름 — `🎯 한 명 공격  6`.
String skillGroupLabel(SkillGroup g) {
  final name = g.resource == SkillResource.esp
      ? '$espGlyph 초능력'
      : switch (g.scope) {
          SkillScope.oneEnemy => '🎯 한 명 공격',
          SkillScope.allEnemies => '💥 전체 공격',
          SkillScope.curse => '☠ 약화',
          SkillScope.oneAlly => '💚 한 명 치료',
          SkillScope.allAllies => '💞 모두 치료',
          SkillScope.selfWeapon => '🌀 무기에 바르기',
        };
  final usable = g.options.where((o) => o.affordable).length;
  final count = usable == g.options.length
      ? '${g.options.length}'
      : '$usable/${g.options.length}';
  return '$name  ${paintText(TextColor.darkGray, count)}';
}

/// 접힌 첫 화면의 머리글.
const String skillGroupMenuHeader = '어떤 기술을 ===>';

/// 묶음 안 목록의 머리글 — `🎯 한 명 공격 ===>`.
String skillGroupHeader(SkillGroup g) {
  final label = skillGroupLabel(g);
  // 개수 꼬리를 떼고 이름만.
  return '${label.substring(0, label.indexOf('  '))} ===>';
}

/// 지시 목록 머리글 (B6-01).
const String orderMenuHeader = '지시 ===>';

/// 지시 항목 한 줄. `actionLabel` 의 하위 항목 문구를 그대로 쓴다.
String orderLabel(BattleAction action) => actionLabel(action, weaponName: '');

/// 병을 어떻게 쓸지 (B6-03). 바르면 3 라운드, 던지면 지금 한 번.
const String itemUseMenuHeader = '어떻게 쓸까 ===>';

String itemUseLabel(ItemUse use) => switch (use) {
  ItemUse.coat => '🗡 무기에 바른다 (3턴 동안 때릴 때마다)',
  ItemUse.throwAtEnemy => '🎯 적에게 던진다 (지금 한 번)',
};

/// 취소 줄의 글 (B6-07). 최상위에서 취소는 턴을 넘기는 것이고, 하위 물음에서
/// 취소는 한 단계 위로 가는 것이다 — 둘을 같은 글로 두면 턴을 잃는 줄 안다.
const String cancelTopLabel = '이 턴을 넘긴다';
const String cancelBackLabel = '뒤로';

/// 이 물음에서 0 이 무엇인가.
String cancelLabelFor(BattleDecision decision) =>
    decision is ActionDecision ? cancelTopLabel : cancelBackLabel;

/// 화면에 늘어놓는 순서 — **앞열부터** (B6-07). 묻는 순서와 같다.
///
/// 파티는 리더가 맨 위, 나머지는 열 → 슬롯. 적은 열 → 등록 순.
/// 슬롯·번호는 그대로 함께 적는다 — 명령은 그것으로 간다.
List<Combatant> partyInDisplayOrder(Battle battle) {
  final leader = leaderSlotOf(battle);
  final members = [...battle.party];
  members.sort((a, b) {
    if (a.slot == leader) return -1;
    if (b.slot == leader) return 1;
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.slot.compareTo(b.slot);
  });
  return members;
}

/// 적 목록의 표시 순서 — 인덱스 목록. 앞열부터, 같은 열은 등록 순.
List<int> enemiesInDisplayOrder(Battle battle) {
  final ix = [for (var i = 0; i < battle.enemies.length; i++) i];
  ix.sort((a, b) {
    final byRank = battle.enemies[a].rank.compareTo(battle.enemies[b].rank);
    return byRank != 0 ? byRank : a.compareTo(b);
  });
  return ix;
}

/// 리더 = 의식 있는 사람 중 가장 낮은 슬롯 (B6-04). model 의 규칙과 같다.
int? leaderSlotOf(Battle battle) {
  int? best;
  for (final c in battle.party) {
    if (!c.isConscious) continue;
    if (best == null || c.slot < best) best = c.slot;
  }
  return best;
}

/// 물건 목록 한 줄 (B6-06) — `💚 치료약`.
String itemLine(String key) {
  final glyph = itemGlyph(key);
  return glyph.isEmpty ? itemName(key) : '$glyph ${itemName(key)}';
}

/// 이름 옆에 붙는 도포 표시 — `🟣독 2` (남은 라운드). 없으면 빈 문자열.
String coatingBadge(WeaponCoating? coating) {
  if (coating == null) return '';
  return paintText(
    TextColor.lightGreen,
    '${coatingGlyph(coating.kind)}${coatingName(coating.kind)} ${coating.rounds}',
  );
}

/// 이 무기가 지금 이 거리에서 무엇을 하는지 한 줄로.
///
/// **거리 계산은 플레이어의 일이 아니다.** 닿으면 무엇으로 치는지,
/// 안 닿으면 무엇을 무는지(명중 벌점 · 앞열이 대신 맞을 확률)를 그대로 적는다.
/// 안 닿아도 목록에서 빼지 않는 것이 B5 의 불변식이라, 무엇을 걸고 있는지가
/// 보여야 한다.
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
    '$short칸 부족 · 명중 -${penalty.accuracy} · '
    '앞열이 대신 ${penalty.interception}%',
  );
}

/// 행동 메뉴 머리글에 붙는 자기 정보 — 열 · 무기 사거리 대역 · 간격.
///
/// 무엇을 고를지가 이 셋에 걸려 있는데 매번 기억해 두라고 할 수는 없다.
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
