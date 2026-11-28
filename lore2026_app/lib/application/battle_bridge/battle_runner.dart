import 'package:lore_battle/lore_battle.dart' as lb;
import 'package:lore_battle_text/lore_battle_text.dart' as bt;

import '../ports/ui_host.dart';

/// 전투 하나를 [UiHost] 로 끝까지 굴린다.
///
/// 전투 model 은 묻고(`pendingDecision`) 답을 받고(`applyCommand`) 한 걸음
/// 나아간다(`advance`). 여기서는 물음을 창 메뉴로, 사건을 대화 창의 문장으로
/// 옮긴다. 규칙은 하나도 갖지 않는다.
class HDBattleRunner {
  HDBattleRunner(
    this.host, {
    this.onBattleStarted,
    this.onStep,
    this.suppressAppearance = false,
    this.pronounOf,
  });

  final UiHost host;

  /// 「적이 출현했다」를 이미 냈으면(교전 앞 물음) 전투가 다시 내지 않게 한다.
  final bool suppressAppearance;

  final void Function(lb.BattleView battle)? onBattleStarted;

  /// 한 걸음마다 — 화면(적 목록 · 일행)을 다시 그리라는 신호.
  final void Function()? onStep;

  /// 자리 → 「그」 · 「그녀」. 원작 문장은 결과 줄에서 이름 대신 대명사를 쓴다.
  final String? Function(int slot)? pronounOf;

  /// 끝나지 않는 전투를 막는 안전장치. 정상이면 닿지 않는다.
  static const int _stepLimit = 20000;

  bool _unread = false;

  Future<lb.BattleOutcome> run(lb.BattleSetup setup) async {
    final battle = lb.Battle(setup);
    final names = bt.LoreBattleNames(battle.view, pronounOf: pronounOf);
    onBattleStarted?.call(battle.view);

    var steps = 0;
    _unread = false;
    while (!battle.isFinished) {
      if (steps++ > _stepLimit) {
        throw StateError('battle did not finish within $_stepLimit steps');
      }
      final decision = battle.pendingDecision;
      if (decision == null) {
        for (final event in battle.advance()) {
          await _report(event, names);
        }
        onStep?.call();
        continue;
      }
      await _letRead();
      final command = await _ask(battle, decision, names);
      for (final event in battle.applyCommand(command)) {
        await _report(event, names);
      }
      onStep?.call();
    }
    await _letRead();
    return battle.outcome!;
  }

  /// 물음을 내기 전에, 아직 읽지 않은 문장이 있으면 키를 기다린다.
  Future<void> _letRead() async {
    if (!_unread) return;
    _unread = false;
    await host.waitForAnyKey();
  }

  Future<void> _report(lb.BattleEvent event, bt.BattleNames names) async {
    if (event is lb.RoundStarted) {
      await _letRead();
      host.clearLogs();
    }
    if (suppressAppearance && event is lb.EnemiesAppeared) return;
    final color = bt.battleLineColor(event);
    for (final line in bt.battleLines(event, names)) {
      await host.addLog(bt.withDefaultColor(line, color));
      _unread = true;
    }
  }

  Future<lb.BattleCommand> _ask(
    lb.Battle battle,
    lb.BattleDecision decision,
    bt.BattleNames names,
  ) async {
    final slot = decision.slot;
    switch (decision) {
      case lb.ActionDecision():
        final picked = await host.showWindowMenu([
          bt.actionMenuHeader(names.member(slot).text),
          for (final a in decision.options)
            bt.actionLabel(a, weaponName: names.weapon(slot)),
        ]);
        if (picked <= 0 || picked > decision.options.length) {
          return lb.CancelChoice(slot);
        }
        return lb.ChooseAction(slot, decision.options[picked - 1]);

      case lb.EnemyTargetDecision():
        final picked = await host.showWindowMenu([
          '공격할 적을 선택하십시오 ===>',
          for (final i in decision.enemyIndices)
            bt.enemyLabel(battle.enemies[i]),
        ]);
        if (picked <= 0 || picked > decision.enemyIndices.length) {
          return lb.CancelChoice(slot);
        }
        return lb.ChooseEnemyTarget(slot, decision.enemyIndices[picked - 1]);

      case lb.SpellDecision():
        var options = decision.options;
        var header = bt.skillMenuHeader;
        // 목록이 길면 범위 묶음으로 한 번 접는다.
        if (bt.skillListFolds(options)) {
          final groups = bt.skillGroups(options);
          final g = await host.showWindowMenu([
            bt.skillGroupMenuHeader,
            for (final group in groups) bt.skillGroupLabel(group),
          ]);
          if (g <= 0 || g > groups.length) return lb.CancelChoice(slot);
          options = groups[g - 1].options;
          header = bt.skillGroupHeader(groups[g - 1]);
        }
        final picked = await host.showWindowMenu([
          header,
          for (final option in options) bt.skillLine(option),
        ]);
        if (picked <= 0 || picked > options.length) {
          return lb.CancelChoice(slot);
        }
        return lb.ChooseSpell(slot, options[picked - 1].magicId);

      case lb.OrderDecision():
        final picked = await host.showWindowMenu([
          bt.orderMenuHeader,
          for (final action in decision.options) bt.orderLabel(action),
        ]);
        if (picked <= 0 || picked > decision.options.length) {
          return lb.CancelChoice(slot);
        }
        return lb.ChooseAction(slot, decision.options[picked - 1]);

      case lb.ItemDecision():
        final picked = await host.showWindowMenu([
          bt.itemMenuHeader,
          for (final k in decision.itemKeys)
            bt.itemLineWithCount(k, battle.consumables[k] ?? 0),
        ]);
        if (picked <= 0 || picked > decision.itemKeys.length) {
          return lb.CancelChoice(slot);
        }
        return lb.ChooseItem(slot, decision.itemKeys[picked - 1]);

      case lb.AllyTargetDecision():
        final picked = await host.showWindowMenu([
          '누구에게 사용할 것입니까? ===>',
          for (final s in decision.slots) names.member(s).text,
        ]);
        if (picked <= 0 || picked > decision.slots.length) {
          return lb.CancelChoice(slot);
        }
        return lb.ChooseAllyTarget(slot, decision.slots[picked - 1]);
    }
  }
}
