import 'package:flutter/material.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_battle_text/hd_battle_text.dart' as tx;

import '../../../hd_config.dart';
import '../../../utils/hd_text_utils.dart';
import 'battle_controller.dart';

/// 전투 화면 (B4-01).
///
/// 800×480 고정 좌표는 게임과 같다 — 지도 자리에 적, 콘솔 자리에 로그,
/// 상태창 자리에 일행. 그래야 나중에 게임 안으로 옮길 때 자리가 안 바뀐다.
///
/// **문장·색·메뉴 문구는 한 줄도 여기서 만들지 않는다.** 전부
/// `hd_battle_text` 가 만든다 — 콘솔과 같은 것을 보여야 하기 때문이다.
class HDBattleScreen extends StatelessWidget {
  const HDBattleScreen({super.key, required this.controller, this.onExit});

  final HDBattleController controller;

  /// 실험실에서 fixture 목록으로 돌아가는 길. 게임 안에서는 없다.
  final VoidCallback? onExit;

  static const double _stripHeight = 40;
  static const double _topHeight =
      HDConfig.mapViewportHeight - _stripHeight; // 280

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: HDConfig.gameScreenWidth,
              height: _stripHeight,
              child: _FormationStrip(controller: controller),
            ),
            Positioned(
              left: 0,
              top: _stripHeight,
              width: HDConfig.mapViewportWidth,
              height: _topHeight,
              child: _EnemyPane(controller: controller),
            ),
            Positioned(
              left: HDConfig.mapViewportWidth,
              top: _stripHeight,
              width: HDConfig.consoleWidth,
              height: _topHeight,
              child: _LogPane(controller: controller),
            ),
            Positioned(
              left: 0,
              top: HDConfig.mapViewportHeight,
              width: HDConfig.gameScreenWidth,
              height: HDConfig.statusPanelHeight,
              child: _PartyPane(controller: controller, onExit: onExit),
            ),
            if (controller.decision != null)
              _DecisionLayer(controller: controller),
            if (controller.isFinished && controller.decision == null)
              _OutcomeLayer(controller: controller, onExit: onExit),
          ],
        );
      },
    );
  }
}

// --- 공통 조각 ---------------------------------------------------------

const TextStyle _base = TextStyle(
  fontFamily: 'DungGeunMo',
  fontSize: 14,
  height: 1.25,
  color: Color(0xFF808080),
);

/// 색 번호가 붙은 글을 그린다. `@X..@@` 표기는 원작 규격이다(부록 V).
Widget _tinted(String markup, {TextStyle? style, int? color}) {
  final text = color == null ? markup : tx.withDefaultColor(markup, color);
  return Text.rich(
    HDTextUtils.parseRichText(
      color == null ? text : tx.paintText(color, text),
      baseStyle: style ?? _base,
    ),
  );
}

Widget _panel({required Widget child, EdgeInsets? padding}) => Container(
  decoration: BoxDecoration(
    color: const Color(0xFF101010),
    border: Border.all(color: const Color(0xFF303030)),
  ),
  padding: padding ?? const EdgeInsets.fromLTRB(8, 6, 8, 6),
  child: child,
);

// --- 대열 -------------------------------------------------------------

/// 두 진영과 간격을 한 줄에. 위치가 결정을 만드는데 안 보이면 결정을 못 한다.
class _FormationStrip extends StatelessWidget {
  const _FormationStrip({required this.controller});

  final HDBattleController controller;

  String _side(List<({int rank, String name})> members, {required bool flip}) {
    final ranks = <int, List<String>>{};
    for (final m in members) {
      (ranks[m.rank] ??= []).add(m.name);
    }
    final parts = <String>[];
    for (final r in flip ? [1, 2, 3] : [3, 2, 1]) {
      final names = ranks[r];
      if (names == null || names.isEmpty) continue;
      parts.add(
        '${tx.paintText(tx.TextColor.lightBlue, "[$r]")} '
        '${names.join(" ")}',
      );
    }
    return parts.isEmpty ? '—' : parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final battle = controller.battle;
    final party = _side([
      for (final c in battle.party)
        if (c.isPresent && c.dead == 0) (rank: c.rank, name: c.name),
    ], flip: false);
    final enemies = _side([
      for (final e in battle.enemies)
        if (e.dead == 0) (rank: e.rank, name: e.name),
    ], flip: true);
    // 간격은 화살표 길이로도 보여 준다 — 숫자보다 먼저 읽힌다.
    final arrow = '←${"─" * (battle.gap * 2 + 1)}→';
    return _panel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: _tinted(
        '$party  '
        '${tx.paintText(tx.TextColor.yellow, "$arrow 간격 ${battle.gap}")}  '
        '$enemies',
        style: _base.copyWith(fontSize: 15),
      ),
    );
  }
}

// --- 적 ---------------------------------------------------------------

class _EnemyPane extends StatelessWidget {
  const _EnemyPane({required this.controller});

  final HDBattleController controller;

  @override
  Widget build(BuildContext context) {
    final battle = controller.battle;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tinted(tx.paintText(tx.TextColor.darkGray, '적')),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: battle.enemies.length,
              itemBuilder: (context, row) {
                // 앞열부터 — 일행 목록·묻는 순서와 같은 방향 (B6-07).
                final i = tx.enemiesInDisplayOrder(battle)[row];
                final e = battle.enemies[i];
                final color = tx.enemyNameColor(
                  hp: e.hp,
                  unconscious: e.unconscious,
                  dead: e.dead,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _tinted(
                    '${(i + 1).toString().padLeft(2)}. '
                    '${tx.paintText(color, e.name)} '
                    '${tx.paintText(tx.TextColor.lightBlue, "${e.rank}열")}  '
                    'HP ${e.hp}  '
                    '${tx.paintText(color, _condition(hp: e.hp, unconscious: e.unconscious, dead: e.dead, deathThreshold: e.deathThreshold))}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _condition({
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

// --- 로그 -------------------------------------------------------------

class _LogPane extends StatelessWidget {
  const _LogPane({required this.controller});

  final HDBattleController controller;

  @override
  Widget build(BuildContext context) {
    final lines = controller.log;
    return GestureDetector(
      // 기다리기 싫으면 아무 데나 눌러 남은 줄을 다 흘린다.
      onTap: controller.skipAhead,
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final line
                in lines.length > 15 ? lines.sublist(lines.length - 15) : lines)
              _tinted(line.text, color: line.color),
          ],
        ),
      ),
    );
  }
}

// --- 일행 -------------------------------------------------------------

class _PartyPane extends StatelessWidget {
  const _PartyPane({required this.controller, this.onExit});

  final HDBattleController controller;
  final VoidCallback? onExit;

  /// 이 사람의 무기가 지금 몇 번 적에게 닿는지. 계산은 플레이어의 일이 아니다.
  String _reach(hb.Combatant c) {
    if (!c.isConscious) return '';
    final battle = controller.battle;
    final reachable = <String>[];
    for (var i = 0; i < battle.enemies.length; i++) {
      final e = battle.enemies[i];
      if (e.dead > 0) continue;
      final distance = hb.distanceBetween(
        gap: battle.gap,
        attackerRank: c.rank,
        targetRank: e.rank,
      );
      if (hb.chooseAttack(c.weapon, distance).shortfall(distance) == 0) {
        reachable.add('${i + 1}');
      }
    }
    return reachable.isEmpty
        ? tx.paintText(tx.TextColor.darkGray, '닿는 적 없음')
        : tx.paintText(tx.TextColor.lightGreen, '닿음 ${reachable.join(",")}');
  }

  @override
  Widget build(BuildContext context) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                // 리더가 맨 위, 그 다음 앞열부터 (B6-07) — 묻는 순서다.
                for (final c in tx.partyInDisplayOrder(controller.battle))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: _tinted(
                      '${c.slot}. '
                      '${tx.paintText(tx.conditionColor(hp: c.hp, poison: c.poison, unconscious: c.unconscious, dead: c.dead), c.name)} '
                      '${tx.paintText(tx.TextColor.lightBlue, "${c.rank}열")}  '
                      'HP ${c.hp}/${c.snapshot.maxHp}  '
                      'SP ${c.sp}  ESP ${c.esp}  '
                      '${_condition(hp: c.hp, unconscious: c.unconscious, dead: c.dead, deathThreshold: c.deathThreshold)}  '
                      '${_reach(c)}'
                      '${c.coating == null ? "" : "  ${tx.coatingBadge(c.coating)}"}',
                    ),
                  ),
              ],
            ),
          ),
          _Controls(controller: controller, onExit: onExit),
        ],
      ),
    );
  }
}

/// 실험실의 조작 — **한 수 물리기**가 여기 있는 이유다.
///
/// 전투는 시드 + 명령 열이면 완전히 재현되므로, 다른 수를 보려고 처음부터
/// 다시 칠 필요가 없다.
class _Controls extends StatelessWidget {
  const _Controls({required this.controller, this.onExit});

  final HDBattleController controller;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Btn('한 수 물리기', onTap: controller.canUndo ? controller.undo : null),
        _Btn('처음부터', onTap: controller.restart),
        _Btn(
          controller.isFast ? '천천히' : '빠르게',
          onTap: () => controller.setPace(
            controller.isFast
                ? const Duration(milliseconds: 110)
                : Duration.zero,
          ),
        ),
        const Spacer(),
        if (onExit != null) _Btn('목록으로', onTap: onExit),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled
                  ? const Color(0xFF808080)
                  : const Color(0xFF303030),
            ),
          ),
          child: Text(
            label,
            style: _base.copyWith(
              color: enabled
                  ? const Color(0xFFC0C0C0)
                  : const Color(0xFF404040),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 물음 -------------------------------------------------------------

/// 지금 물어볼 것 하나를 가운데 띄운다.
class _DecisionLayer extends StatefulWidget {
  const _DecisionLayer({required this.controller});

  final HDBattleController controller;

  @override
  State<_DecisionLayer> createState() => _DecisionLayerState();
}

class _DecisionLayerState extends State<_DecisionLayer> {
  /// 접힌 기술 목록에서 고른 묶음. 물음이 바뀌면 잊는다.
  tx.SkillGroup? _group;

  /// 어느 물음에서 고른 묶음인가. `controller.decision` 은 읽을 때마다 새
  /// 객체라 identity 로는 못 알아본다 — 물음의 내용으로 표를 만든다.
  String? _groupFor;

  static String _signature(hb.BattleDecision d) => switch (d) {
    hb.SpellDecision() => 'skill:${d.slot}:${d.magicIds.join(",")}',
    _ => '${d.runtimeType}:${d.slot}',
  };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final decision = controller.decision!;
    final battle = controller.battle;
    final signature = _signature(decision);
    if (_groupFor != signature) {
      _group = null;
      _groupFor = signature;
    }

    // 기술 목록이 8줄을 넘으면 첫 화면은 범위 묶음이다 (규칙은 hd_battle_text).
    final folded =
        decision is hb.SpellDecision && tx.skillListFolds(decision.options);
    final String header;
    final List<String> items;
    final void Function(int index) onPick;
    Widget? back;

    if (folded && _group == null) {
      final groups = tx.skillGroups(decision.options);
      header = tx.skillGroupMenuHeader;
      items = [for (final g in groups) tx.skillGroupLabel(g)];
      onPick = (i) => setState(() => _group = groups[i]);
    } else if (folded) {
      final group = _group!;
      header = tx.skillGroupHeader(group);
      items = [for (final o in group.options) tx.skillLine(o)];
      onPick = (i) => controller.choose(
        hb.ChooseSpell(decision.slot, group.options[i].magicId),
      );
      back = _MenuRow(
        label: tx.paintText(tx.TextColor.darkGray, '← 다른 묶음'),
        onTap: () => setState(() => _group = null),
      );
    } else {
      final menu = _menuFor(battle, decision);
      header = menu.$1;
      items = menu.$2;
      onPick = (i) => controller.choose(_commandFor(decision, i));
    }

    return Positioned(
      left: 120,
      top: 60,
      width: 560,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000020),
          border: Border.all(color: const Color(0xFF8080FF)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _tinted(header, color: tx.TextColor.lightRed),
            const SizedBox(height: 4),
            for (var i = 0; i < items.length; i++)
              _MenuRow(label: '${i + 1}) ${items[i]}', onTap: () => onPick(i)),
            ?back,
            _MenuRow(
              label: tx.paintText(
                tx.TextColor.darkGray,
                '0) ${tx.cancelLabelFor(decision)}',
              ),
              onTap: () => controller.choose(hb.CancelChoice(decision.slot)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _tinted('  $label'),
      ),
    );
  }
}

(String, List<String>) _menuFor(hb.Battle battle, hb.BattleDecision decision) {
  switch (decision) {
    case hb.ActionDecision():
      final c = battle.party.firstWhere((x) => x.slot == decision.slot);
      return (
        '${c.name}의 전투 모드 '
            '${tx.actionHeaderSuffix(rank: c.rank, weapon: c.weapon, gap: battle.gap)} ===>',
        [
          for (final option in decision.options)
            tx.actionLabel(option, weaponName: c.snapshot.weaponName),
        ],
      );
    case hb.EnemyTargetDecision():
      final me = battle.party.firstWhere((c) => c.slot == decision.slot);
      return (
        '공격할 적을 선택하십시오 ===>',
        [
          for (final index in decision.enemyIndices)
            () {
              final e = battle.enemies[index];
              final distance = hb.distanceBetween(
                gap: battle.gap,
                attackerRank: me.rank,
                targetRank: e.rank,
              );
              final color = tx.enemyNameColor(
                hp: e.hp,
                unconscious: e.unconscious,
                dead: e.dead,
              );
              return '${tx.paintText(color, e.name)} '
                  '${tx.paintText(tx.TextColor.lightBlue, "${e.rank}열")}  '
                  '거리 $distance  '
                  '${tx.reachVerdict(attack: hb.chooseAttack(me.weapon, distance), distance: distance)}  '
                  '${tx.paintText(tx.TextColor.darkGray, "HP ${e.hp}")}';
            }(),
        ],
      );
    case hb.SpellDecision():
      // B6-01: 한 목록. 글자가 범위를 말하고 못 쓰는 것도 어둡게 남는다.
      return (
        tx.skillMenuHeader,
        [for (final option in decision.options) tx.skillLine(option)],
      );
    case hb.OrderDecision():
      return (
        tx.orderMenuHeader,
        [for (final action in decision.options) tx.orderLabel(action)],
      );
    case hb.ItemDecision():
      return (
        '사용할 물건 ===>',
        [for (final key in decision.itemKeys) tx.itemLine(key)],
      );
    case hb.ItemUseDecision():
      return (
        tx.itemUseMenuHeader,
        [for (final use in decision.uses) tx.itemUseLabel(use)],
      );
    case hb.AllyTargetDecision():
      return (
        '누구에게 사용할 것입니까? ===>',
        [
          for (final slot in decision.slots)
            () {
              final c = battle.party.firstWhere((p) => p.slot == slot);
              return '${tx.paintText(tx.conditionColor(hp: c.hp, poison: c.poison, unconscious: c.unconscious, dead: c.dead), c.name)} '
                  '${tx.paintText(tx.TextColor.lightBlue, "${c.rank}열")}  '
                  'HP ${c.hp}/${c.snapshot.maxHp}';
            }(),
        ],
      );
  }
}

hb.BattleCommand _commandFor(
  hb.BattleDecision decision,
  int index,
) => switch (decision) {
  hb.ActionDecision() => hb.ChooseAction(
    decision.slot,
    decision.options[index],
  ),
  hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
    decision.slot,
    decision.enemyIndices[index],
  ),
  hb.SpellDecision() => hb.ChooseSpell(
    decision.slot,
    decision.options[index].magicId,
  ),
  hb.OrderDecision() => hb.ChooseAction(decision.slot, decision.options[index]),
  hb.ItemDecision() => hb.ChooseItem(decision.slot, decision.itemKeys[index]),
  hb.ItemUseDecision() => hb.ChooseItemUse(decision.slot, decision.uses[index]),
  hb.AllyTargetDecision() => hb.ChooseAllyTarget(
    decision.slot,
    decision.slots[index],
  ),
};

// --- 끝 ---------------------------------------------------------------

class _OutcomeLayer extends StatelessWidget {
  const _OutcomeLayer({required this.controller, this.onExit});

  final HDBattleController controller;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final outcome = controller.outcome;
    if (outcome == null) return const SizedBox.shrink();
    final label = switch (outcome.resultCode) {
      hb.BattleResultCode.win => '승리',
      hb.BattleResultCode.lose => '전멸',
      hb.BattleResultCode.evade => '도주',
      hb.BattleResultCode.none => '미결',
    };
    return Positioned(
      left: 200,
      top: 100,
      width: 400,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF000020),
          border: Border.all(color: const Color(0xFF8080FF)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tinted(
              '전투 종료 — $label (cm2 Battle::Result() = '
              '${outcome.resultCode.wire})',
              color: tx.TextColor.yellow,
            ),
            const SizedBox(height: 6),
            _tinted('획득 골드 ${outcome.goldGained}'),
            for (final c in outcome.combatants)
              _tinted('슬롯 ${c.slot}  HP ${c.hp}  획득 경험치 ${c.experienceGained}'),
            const SizedBox(height: 8),
            Row(
              children: [
                _Btn('처음부터', onTap: controller.restart),
                if (onExit != null) _Btn('목록으로', onTap: onExit),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
