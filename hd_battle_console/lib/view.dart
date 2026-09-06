import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_text/hd_battle_text.dart';
import 'package:hd_battle_text/hd_battle_text.dart' as tx;

import 'palette.dart';

/// 전투를 **터미널에** 그린다.
///
/// 문장 자체는 `hd_battle_text` 가 만든다 — 콘솔과 Flutter view(B4)가 같은
/// 문장을 쓰도록 한 곳에 모아 뒀다. 이 파일이 하는 일은 그 문장에
/// **색·표·메뉴** 를 입히는 것, 즉 터미널 표현이다.
class BattleView implements BattleNames {
  BattleView(this.battle, {this.ansi = HDAnsi.plain});

  final Battle battle;

  /// `@` 색 표기를 무엇으로 바꿀지. 기본값은 "표기만 뗀다" 라서
  /// 이 view 를 그냥 쓰면 예전과 똑같은 맨 문자열이 나온다.
  final HDAnsi ansi;

  /// 원작에 없던 줄을 붙일 표시.
  static const String added = addedMarker;

  @override
  HDNoun member(int slot) =>
      HDNoun(battle.party.firstWhere((c) => c.slot == slot).name);

  @override
  String weapon(int slot) =>
      battle.party.firstWhere((c) => c.slot == slot).snapshot.weaponName;

  @override
  HDNoun enemy(int index) => HDNoun(battle.enemies[index].name);

  /// 한 이벤트가 만드는 줄들. 빈 목록이면 출력할 것이 없다.
  ///
  /// 색은 [colorOf] 가 줄 단위로 입힌다 — 원작의 `writeConsole(색번호, ...)`
  /// 과 같은 방식이다.
  List<String> render(BattleEvent event) {
    final color = colorOf(event);
    return [
      for (final line in lines(event)) ansi.render(line, defaultColor: color),
    ];
  }

  /// 색을 입히기 전의 줄들. `hd_battle_text` 가 만든다.
  List<String> lines(BattleEvent event) => battleLines(event, this);

  /// 한 줄의 색. 원작 `writeConsole` 의 첫 인자다 (부록 V).
  int colorOf(BattleEvent event) => battleLineColor(event);

  // --- 상태 표 -------------------------------------------------------

  /// 적과 일행의 현재 상태 표.
  ///
  /// 이름 색이 곧 상태다 — 그것도 원작에서 온 규칙이다. 적은 남은 HP 로
  /// ([enemyNameColor], `hd_class_window_battle.h`), 일행은 상태로
  /// ([conditionColor], `hd_class_pc_player.cpp`) 색이 정해진다.
  /// 원작 화면은 320x240 이라 상태를 글자로 적을 자리가 없어서 색만 썼다.
  /// 여기는 자리가 있으니 색과 글자를 같이 낸다.
  String statusTable() {
    final out = <String>['', ..._formationLines()];

    out.add(ansi.render(paint(HDColor.darkGray, '  적')));
    // 앞열부터 — 묻는 순서와 같다 (B6-07). 번호는 그대로 적는다.
    for (final i in tx.enemiesInDisplayOrder(battle)) {
      final e = battle.enemies[i];
      final color = enemyNameColor(
        hp: e.hp,
        unconscious: e.unconscious,
        dead: e.dead,
      );
      final condition = _condition(
        hp: e.hp,
        unconscious: e.unconscious,
        dead: e.dead,
        deathThreshold: e.deathThreshold,
      );
      out.add(
        ansi.render(
          '   ${(i + 1).toString().padLeft(2)}. '
          '${paint(color, padDisplay(e.name, 20))}'
          '${paint(HDColor.lightBlue, "${e.rank}열")}  '
          'HP ${e.hp.toString().padLeft(5)}   ${paint(color, condition)}',
          defaultColor: HDColor.lightGray,
        ),
      );
    }

    out.addAll(['', ansi.render(paint(HDColor.darkGray, '  일행'))]);
    // 리더가 맨 위, 그 다음 앞열부터 (B6-07).
    for (final c in tx.partyInDisplayOrder(battle)) {
      final color = conditionColor(
        hp: c.hp,
        poison: c.poison,
        unconscious: c.unconscious,
        dead: c.dead,
      );
      final condition = _condition(
        hp: c.hp,
        unconscious: c.unconscious,
        dead: c.dead,
        deathThreshold: c.deathThreshold,
      );
      out.add(
        ansi.render(
          '   ${c.slot}. ${paint(color, padDisplay(c.name, 14))}'
          '${paint(HDColor.lightBlue, "${c.rank}열")}  '
          'HP ${c.hp.toString().padLeft(5)}/${c.snapshot.maxHp.toString().padLeft(4)}  '
          'SP ${c.sp.toString().padLeft(4)}  ESP ${c.esp.toString().padLeft(4)}  '
          '${paint(color, condition)}  ${_reachSummary(c)}'
          '${c.coating == null ? "" : "  ${tx.coatingBadge(c.coating)}"}',
          defaultColor: HDColor.lightGray,
        ),
      );
    }
    return out.join('\n');
  }

  // --- 위치를 눈으로 (B5) ---------------------------------------------

  /// 두 진영을 한 줄에 그린다.
  ///
  /// 위치가 결정을 만드는데 화면에 안 보이면 결정을 할 수가 없다.
  /// 열은 좌표가 아니라 정수 하나라서 한 줄로 다 그려진다.
  List<String> _formationLines() {
    String side(List<({int rank, String name})> members, {required bool flip}) {
      final ranks = <int, List<String>>{};
      for (final m in members) {
        (ranks[m.rank] ??= []).add(m.name);
      }
      final order = flip ? [1, 2, 3] : [3, 2, 1];
      final parts = <String>[];
      for (final r in order) {
        final names = ranks[r];
        if (names == null || names.isEmpty) continue;
        parts.add('${paint(HDColor.lightBlue, "[$r]")} ${names.join(" ")}');
      }
      return parts.isEmpty ? '—' : parts.join('  ');
    }

    final party = side([
      for (final c in battle.party)
        if (c.isPresent && c.dead == 0) (rank: c.rank, name: c.name),
    ], flip: false);
    final enemies = side([
      for (final e in battle.enemies)
        if (e.dead == 0) (rank: e.rank, name: e.name),
    ], flip: true);

    // 간격을 화살표 길이로도 보여 준다 — 숫자보다 먼저 읽힌다.
    final arrow = '←${"─" * (battle.gap * 2 + 1)}→';
    return [
      ansi.render(
        '  $party  ${paint(HDColor.yellow, arrow)} '
        '${paint(HDColor.yellow, "간격 ${battle.gap}")}  $enemies',
        defaultColor: HDColor.lightGray,
      ),
      '',
    ];
  }

  /// 이 사람의 무기가 지금 어디까지 닿는지.
  ///
  /// 무기의 사거리 대역을 그대로 보여 주는 것이 아니라 **지금 이 판에서
  /// 몇 번 적에게 닿는가**를 낸다 — 계산은 플레이어의 일이 아니다.
  String _reachSummary(Combatant c) {
    if (!c.isConscious) return '';
    final reachable = <String>[];
    for (var i = 0; i < battle.enemies.length; i++) {
      final e = battle.enemies[i];
      if (e.dead > 0) continue;
      if (_shortfall(c, e) == 0) reachable.add('${i + 1}');
    }
    if (reachable.isEmpty) {
      return paint(HDColor.darkGray, '닿는 적 없음');
    }
    return paint(HDColor.lightGreen, '닿음 ${reachable.join(",")}');
  }

  /// 이 사람이 그 적을 치려면 몇 칸 모자란가. 0 이면 닿는다.
  int _shortfall(Combatant c, EnemyInstance e) {
    final distance = distanceBetween(
      gap: battle.gap,
      attackerRank: c.rank,
      targetRank: e.rank,
    );
    return chooseAttack(c.weapon, distance).shortfall(distance);
  }

  /// 터미널에서 차지하는 칸 수. 한글·한자·가나는 두 칸이다.
  ///
  /// `padRight` 는 글자 수를 세므로 한글 이름이 섞이면 표가 어긋난다.
  /// 위치를 표로 읽어야 하는 지금은 그게 실제로 방해가 된다.
  static int displayWidth(String text) {
    var width = 0;
    for (final r in text.runes) {
      width += _isWide(r) ? 2 : 1;
    }
    return width;
  }

  static bool _isWide(int r) =>
      (r >= 0x1100 && r <= 0x115F) || // 한글 자모
      (r >= 0x2E80 && r <= 0xA4CF) || // CJK 부수 ~ 이(彝)
      (r >= 0xAC00 && r <= 0xD7A3) || // 한글 음절
      (r >= 0xF900 && r <= 0xFAFF) || // CJK 호환 한자
      (r >= 0xFF00 && r <= 0xFF60) || // 전각 영숫자
      (r >= 0x20000 && r <= 0x3FFFD);

  /// 화면 폭 기준으로 오른쪽을 채운다.
  static String padDisplay(String text, int width) {
    final short = width - displayWidth(text);
    return short <= 0 ? text : text + ' ' * short;
  }

  /// 공격 방식의 이름.
  static String methodName(AttackMethod method) => tx.attackMethodName(method);

  /// B2-03 이후 `unconscious` 는 불린이 아니라 **누적값**이고, 임계값
  /// (`체력 x 레벨`)을 넘으면 사망이다. 그래서 `의식 불명 (3/8)` 처럼
  /// 얼마나 남았는지 같이 보여준다.
  static String _condition({
    required int hp,
    required int unconscious,
    required int dead,
    required int deathThreshold,
  }) {
    if (dead > 0) return '사망';
    if (unconscious > 0) return '의식 불명 ($unconscious/$deathThreshold)';
    if (hp <= 0) return '쓰러짐';
    return '의식 있음';
  }

  // --- 메뉴 ----------------------------------------------------------

  /// 메뉴 한 벌. 머리글과 항목의 색도 원작에서 왔다.
  ///
  /// `hd_class_select.cpp:21,27` 이 머리글을 12번, 고를 수 있는 항목을
  /// 7번, 고를 수 없는 항목을 0번(검정 = 안 보임)으로 그렸다. 이 콘솔은
  /// model 이 고를 수 있는 것만 내주므로 고를 수 없는 항목이 아예 없다.
  /// 취소만 8번으로 낮춰 뒀는데 그건 원작에 없는 우리 선택이다.
  String _menu(
    String header,
    List<String> items, {
    String cancel = tx.cancelBackLabel,
  }) {
    final out = <String>[ansi.render(header, defaultColor: HDColor.lightRed)];
    for (var i = 0; i < items.length; i++) {
      out.add(
        ansi.render('  ${i + 1}) ${items[i]}', defaultColor: HDColor.lightGray),
      );
    }
    // 최상위에서 0 은 턴을 넘기는 것, 하위 물음에서 0 은 한 단계 위로 (B6-07).
    out.add(ansi.render('  0) $cancel', defaultColor: HDColor.darkGray));
    return out.join('\n');
  }

  /// 원작 `battle.dart:311-325` 의 전투 모드 메뉴.
  String actionMenu(ActionDecision decision) {
    final c = battle.party.firstWhere((x) => x.slot == decision.slot);
    // 자기 열과 무기 사거리를 머리글에 단다 — 무엇을 고를지가 그 둘에
    // 걸려 있는데 매번 기억해 두라고 할 수는 없다.
    return _menu(
      '${c.name}의 전투 모드 '
      '${tx.actionHeaderSuffix(rank: c.rank, weapon: c.weapon, gap: battle.gap)}'
      ' ===>',
      cancel: tx.cancelTopLabel,
      [
        for (final option in decision.options)
          actionLabel(option, decision.slot),
      ],
    );
  }

  /// 항목 글은 `hd_battle_text` 가 만든다 — Flutter view 와 같은 것을
  /// 보여야 한다(B4-01 의 "표현 격차 0").
  String actionLabel(BattleAction action, int slot) =>
      tx.actionLabel(action, weaponName: weapon(slot));

  /// 원작 `battle.dart:95` 의 대상 선택 메뉴.
  ///
  /// 적 이름은 상태 표와 같은 규칙으로 물들인다 — 원작의 전투 창이
  /// 대상을 고를 때 보여 주던 바로 그 목록이라서 색도 같아야 한다.
  String enemyTargetMenu(EnemyTargetDecision decision) {
    final me = battle.party.firstWhere((c) => c.slot == decision.slot);
    return _menu('공격할 적을 선택하십시오 ===>', [
      for (final index in decision.enemyIndices)
        () {
          final e = battle.enemies[index];
          final color = enemyNameColor(
            hp: e.hp,
            unconscious: e.unconscious,
            dead: e.dead,
          );
          final distance = distanceBetween(
            gap: battle.gap,
            attackerRank: me.rank,
            targetRank: e.rank,
          );
          // 닿는지 · 무엇으로 치는지 · 안 닿으면 무엇을 무는지.
          // 거리 계산은 플레이어의 일이 아니다. 문구는 공유본이 만든다.
          final verdict = tx.reachVerdict(
            attack: chooseAttack(me.weapon, distance),
            distance: distance,
          );
          return '${paint(color, padDisplay(e.name, 18))}'
              '${paint(HDColor.lightBlue, "${e.rank}열")}  '
              '거리 $distance  $verdict  '
              '${paint(HDColor.darkGray, "HP ${e.hp}")}';
        }(),
    ]);
  }

  /// 기술 목록 — 하나다 (B6-01). 글은 `hd_battle_text` 가 만든다.
  ///
  /// 못 쓰는 것도 어둡게 남아 있다. 전에는 목록에서 사라져서 있는지조차
  /// 알 수 없었다.
  String spellMenu(SpellDecision decision, {tx.SkillGroup? group}) {
    final options = group?.options ?? decision.options;
    return _menu(
      group == null ? tx.skillMenuHeader : tx.skillGroupHeader(group),
      [for (final option in options) tx.skillLine(option)],
    );
  }

  /// 목록이 8줄을 넘으면 먼저 나오는 화면 — 범위 글자로 묶은 것.
  String skillGroupMenu(SpellDecision decision) {
    return _menu(tx.skillGroupMenuHeader, [
      for (final g in tx.skillGroups(decision.options)) tx.skillGroupLabel(g),
    ]);
  }

  /// 병을 어떻게 쓸지 (B6-03).
  String itemUseMenu(ItemUseDecision decision) {
    return _menu(tx.itemUseMenuHeader, [
      for (final use in decision.uses) tx.itemUseLabel(use),
    ]);
  }

  /// 리더의 지시 — 자동 전투 · 대열 (B6-01).
  String orderMenu(OrderDecision decision) {
    return _menu(tx.orderMenuHeader, [
      for (final action in decision.options) tx.orderLabel(action),
    ]);
  }

  /// 아이템 선택 메뉴 (B2-06). 원작 전투 메뉴에는 없던 항목이다.
  String itemMenu(ItemDecision decision) {
    return _menu('사용할 물건 ===>', [
      for (final key in decision.itemKeys) tx.itemLine(key),
    ]);
  }

  /// 아군 대상 선택. 원작은 치료에서 물었고 Dart 이식본이 없앴다.
  String allyTargetMenu(AllyTargetDecision decision) {
    return _menu('누구에게 사용할 것입니까? ===>', [
      for (final slot in decision.slots)
        () {
          final c = battle.party.firstWhere((p) => p.slot == slot);
          final color = conditionColor(
            hp: c.hp,
            poison: c.poison,
            unconscious: c.unconscious,
            dead: c.dead,
          );
          return '${paint(color, padDisplay(c.name, 18))}'
              '${paint(HDColor.lightBlue, "${c.rank}열")}  '
              'HP ${c.hp}/${c.snapshot.maxHp}';
        }(),
    ]);
  }

  String menuFor(BattleDecision decision) => switch (decision) {
    ActionDecision() => actionMenu(decision),
    EnemyTargetDecision() => enemyTargetMenu(decision),
    SpellDecision() =>
      tx.skillListFolds(decision.options)
          ? skillGroupMenu(decision)
          : spellMenu(decision),
    OrderDecision() => orderMenu(decision),
    ItemDecision() => itemMenu(decision),
    ItemUseDecision() => itemUseMenu(decision),
    AllyTargetDecision() => allyTargetMenu(decision),
  };

  /// 전투 정산 결과를 사람이 읽는 형태로.
  ///
  /// 원작에는 이 표가 없다 — 전투가 끝나면 값이 곧장 RPG 쪽 구조체로
  /// 들어갔다. 모드가 갈라진 지금은 그 인계 값이 무엇인지 눈으로
  /// 확인할 수 있어야 해서 만든 표다. 그래서 색도 원작 대응이 없다.
  String outcomeReport(BattleOutcome outcome) {
    String kv(String label, Object value) => ansi.render(
      '  $label${paint(HDColor.white, value)}',
      defaultColor: HDColor.darkGray,
    );

    final out = <String>[
      '',
      ansi.render(
        '=== 전투 정산 결과 (RPG 로 넘어가는 값) ===',
        defaultColor: HDColor.yellow,
      ),
      kv(
        '종료 코드 : ',
        '${paint(_resultColor(outcome.resultCode), _resultLabel(outcome.resultCode))}'
            ' (cm2 Battle::Result() = ${outcome.resultCode.wire})',
      ),
      kv('획득 골드 : ', outcome.goldGained),
      kv(
        '소비 아이템: ',
        outcome.consumedItems.isEmpty ? '없음 (B2-06)' : outcome.consumedItems,
      ),
      kv(
        '전투 밖 효과 요청: ',
        outcome.worldEffects.isEmpty ? '없음 (B3-04)' : outcome.worldEffects,
      ),
      kv(
        '합류한 파티원 : ',
        outcome.recruits.isEmpty
            ? '없음'
            : outcome.recruits.map((r) => r.name).join(', '),
      ),
      kv(
        '이탈한 슬롯   : ',
        outcome.departedSlots.isEmpty ? '없음' : outcome.departedSlots.join(', '),
      ),
      ansi.render('  파티 슬롯별:', defaultColor: HDColor.darkGray),
    ];
    for (final c in outcome.combatants) {
      final member = battle.party.firstWhere((p) => p.slot == c.slot);
      final color = conditionColor(
        hp: c.hp,
        poison: c.poison,
        unconscious: c.unconscious,
        dead: c.dead,
      );
      out.add(
        ansi.render(
          '    슬롯 ${c.slot} ${paint(color, member.name)}  '
          'HP ${c.hp}  SP ${c.sp}  ESP ${c.esp}  '
          '독 ${c.poison}  의식불명 ${c.unconscious}  사망 ${c.dead}  '
          '획득 경험치 ${paint(HDColor.yellow, c.experienceGained)}',
          defaultColor: HDColor.lightGray,
        ),
      );
    }
    out.add(
      ansi.render(
        '  (레벨업은 RPG 가 판정한다 — B3-05)',
        defaultColor: HDColor.darkGray,
      ),
    );
    return out.join('\n');
  }

  static String _resultLabel(BattleResultCode code) => switch (code) {
    BattleResultCode.win => '승리',
    BattleResultCode.lose => '전멸',
    BattleResultCode.evade => '도주',
    BattleResultCode.none => '결과 없음',
  };

  /// 종료 코드의 색. 마지막 `BattleEnded` 줄과 같은 색을 쓴다.
  static int _resultColor(BattleResultCode code) => switch (code) {
    BattleResultCode.win => HDColor.yellow,
    BattleResultCode.lose => HDColor.red,
    BattleResultCode.evade => HDColor.lightCyan,
    BattleResultCode.none => HDColor.lightRed,
  };
}
