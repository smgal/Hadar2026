import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_battle_text/hd_battle_text.dart' as tx;

import '../ports/ui_host.dart';

/// 새 전투 model 을 `UiHost` 로 굴린다 (B3-02).
///
/// ## 호출 방향이 뒤집혀 있다
///
/// 예전 전투(`application/battle.dart`)는 규칙 안에서 `_host.showMenu` 를
/// 직접 불렀다. 그래서 규칙과 화면이 한 함수에 섞여 있었고, 헤드리스로
/// 돌릴 수 없었다.
///
/// 새 model 은 반대다 — 물을 것이 있으면 `pendingDecision` 을 내놓고
/// 기다린다. 이 파일이 그 물음을 `UiHost` 의 메뉴로 옮기고 답을
/// `applyCommand` 로 돌려주는 **얇은 운전자**다. 규칙은 한 줄도 없다.
///
/// B4 의 Flutter view 는 같은 자리에 다른 운전자를 놓으면 되고,
/// `packages/hd_battle` 은 그때도 안 바뀐다.
class HDBattleRunner {
  HDBattleRunner(
    this.host, {
    this.onBattleStarted,
    this.onStep,
    this.suppressAppearance = false,
  });

  final UiHost host;

  /// 조우 알림(`EnemiesAppeared`)을 버릴 것인가.
  ///
  /// cm2 는 `Battle::ShowEnemy` 로 **싸울지 묻기 전에** 누가 나왔는지
  /// 먼저 알린다. 그 경우 model 이 개시하며 내는 같은 줄은 중복이다.
  final bool suppressAppearance;

  /// 전투가 만들어진 직후 한 번. 화면이 적의 상태를 읽을 수 있게 열어 준다.
  final void Function(hb.Battle battle)? onBattleStarted;

  /// 한 걸음 지날 때마다. 화면 갱신용이다.
  final void Function()? onStep;

  /// 한 걸음도 진행하지 못하면 멈춘다. 규칙이 어긋나 무한 반복이 되면
  /// 화면이 멎는 것보다 예외가 낫다.
  static const int _stepLimit = 20000;

  /// 아직 사람이 안 읽은 줄이 화면에 있는가.
  ///
  /// 5인 파티면 한 라운드에 열 줄이 넘는다. 멈추지 않으면 전부 스쳐 지나가고,
  /// 무슨 일이 일어났는지 모른 채 다음 명령을 내리게 된다. 옛 전투가 턴
  /// 끝마다 `waitForAnyKey` 를 부른 것이 이 리듬이다.
  bool _unread = false;

  /// 전투 하나를 끝까지 굴리고 정산 결과를 돌려준다.
  Future<hb.BattleOutcome> run(hb.BattleSetup setup) async {
    final battle = hb.Battle(setup);
    final names = _Names(battle);
    onBattleStarted?.call(battle);
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
      // 물어보기 **전에** 읽을 시간을 준다.
      await _letRead();
      final command = await _ask(battle, decision, names);
      for (final event in battle.applyCommand(command)) {
        await _report(event, names);
      }
      onStep?.call();
    }
    // 마지막 줄도 읽고 나서 닫는다.
    await _letRead();
    return battle.outcome!;
  }

  /// 찍힌 줄이 있으면 한 번 멈춘다.
  Future<void> _letRead() async {
    if (!_unread) return;
    _unread = false;
    await host.waitForAnyKey();
  }

  /// 이벤트 하나를 화면에 낸다.
  ///
  /// 문장은 `hd_battle_text` 가 만든다 — 콘솔과 같은 문장이다.
  /// 색 표기(`@X..@@`)는 앱의 콘솔이 이미 읽는다(원작 규격, 부록 V).
  ///
  /// **줄을 그냥 감싸면 안 된다** — `@@` 는 바깥 색이 아니라 **기본색**으로
  /// 되돌아가므로(`hd_text_utils.dart:53`), 피해 수치처럼 줄 안에 다른 색이
  /// 끼면 그 뒤가 색을 잃는다. `withDefaultColor` 가 안쪽 `@@` 까지 줄 색으로
  /// 바꿔 준다.
  Future<void> _report(hb.BattleEvent event, _Names names) async {
    // 라운드가 열리면 앞 라운드의 줄을 치운다. 안 치우면 콘솔에 계속
    // 쌓여서 지금 무슨 일이 일어났는지가 묻힌다 — 옛 전투도 라운드마다
    // `clearLogs` 를 불렀다.
    if (event is hb.RoundStarted) {
      await _letRead();
      host.clearLogs();
    }
    if (suppressAppearance && event is hb.EnemiesAppeared) return;
    final color = tx.battleLineColor(event);
    for (final line in tx.battleLines(event, names)) {
      await host.addLog(tx.withDefaultColor(line, color), isDialogue: false);
      _unread = true;
    }
  }

  /// 물음 하나를 메뉴로 옮기고 답을 명령으로 돌려준다.
  ///
  /// 취소(0)는 `CancelChoice` 다 — 원작도 취소하면 그 턴을 넘겼다.
  Future<hb.BattleCommand> _ask(
    hb.Battle battle,
    hb.BattleDecision decision,
    _Names names,
  ) async {
    switch (decision) {
      case hb.ActionDecision():
        final picked = await host.showWindowMenu([
          '${names.member(decision.slot)}의 전투 모드 ===>',
          for (final a in decision.options)
            _actionLabel(a, decision.slot, names),
        ]);
        if (picked <= 0 || picked > decision.options.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseAction(decision.slot, decision.options[picked - 1]);

      case hb.EnemyTargetDecision():
        final picked = await host.showWindowMenu([
          '공격할 적을 선택하십시오 ===>',
          for (final i in decision.enemyIndices)
            '${names.enemy(i)}  (HP ${battle.enemies[i].hp})',
        ]);
        if (picked <= 0 || picked > decision.enemyIndices.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseEnemyTarget(
          decision.slot,
          decision.enemyIndices[picked - 1],
        );

      case hb.SpellDecision():
        // B6-01: 한 목록. 글자가 범위를 말하고 못 쓰는 것도 어둡게 남는다.
        // 8줄을 넘으면 범위 묶음을 먼저 묻는다 — 규칙은 `hd_battle_text`.
        var options = decision.options;
        String header = tx.skillMenuHeader;
        if (tx.skillListFolds(options)) {
          final groups = tx.skillGroups(options);
          final g = await host.showWindowMenu([
            tx.skillGroupMenuHeader,
            for (final group in groups) tx.skillGroupLabel(group),
          ]);
          if (g <= 0 || g > groups.length) {
            return hb.CancelChoice(decision.slot);
          }
          options = groups[g - 1].options;
          header = tx.skillGroupHeader(groups[g - 1]);
        }
        final picked = await host.showWindowMenu([
          header,
          for (final option in options) tx.skillLine(option),
        ]);
        if (picked <= 0 || picked > options.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseSpell(decision.slot, options[picked - 1].magicId);

      case hb.OrderDecision():
        final picked = await host.showWindowMenu([
          tx.orderMenuHeader,
          for (final action in decision.options) tx.orderLabel(action),
        ]);
        if (picked <= 0 || picked > decision.options.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseAction(decision.slot, decision.options[picked - 1]);

      case hb.ItemUseDecision():
        final picked = await host.showWindowMenu([
          tx.itemUseMenuHeader,
          for (final use in decision.uses) tx.itemUseLabel(use),
        ]);
        if (picked <= 0 || picked > decision.uses.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseItemUse(decision.slot, decision.uses[picked - 1]);

      case hb.ItemDecision():
        final picked = await host.showWindowMenu([
          '사용할 물건 ===>',
          for (final k in decision.itemKeys) tx.itemLine(k),
        ]);
        if (picked <= 0 || picked > decision.itemKeys.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseItem(decision.slot, decision.itemKeys[picked - 1]);

      case hb.AllyTargetDecision():
        final picked = await host.showWindowMenu([
          '누구에게 사용할 것입니까? ===>',
          for (final s in decision.slots) '${names.member(s)}',
        ]);
        if (picked <= 0 || picked > decision.slots.length) {
          return hb.CancelChoice(decision.slot);
        }
        return hb.ChooseAllyTarget(decision.slot, decision.slots[picked - 1]);
    }
  }

  /// 항목 글은 `hd_battle_text` 가 만든다 — 콘솔·실험실과 같은 것.
  String _actionLabel(hb.BattleAction action, int slot, _Names names) =>
      tx.actionLabel(action, weaponName: names.weapon(slot));
}

/// 슬롯·적 번호를 이름으로. `hd_battle_text` 가 문장을 만들 때 쓴다.
class _Names implements tx.BattleNames {
  _Names(this.battle);

  final hb.Battle battle;

  @override
  tx.HDNoun member(int slot) =>
      tx.HDNoun(battle.party.firstWhere((c) => c.slot == slot).name);

  @override
  tx.HDNoun enemy(int index) => tx.HDNoun(battle.enemies[index].name);

  @override
  String weapon(int slot) =>
      battle.party.firstWhere((c) => c.slot == slot).snapshot.weaponName;
}
