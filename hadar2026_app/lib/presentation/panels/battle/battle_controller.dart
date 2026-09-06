import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_battle_text/hd_battle_text.dart' as tx;

/// 화면에 찍힌 줄 하나. 색은 원작 규격의 번호다(부록 V).
class HDBattleLine {
  const HDBattleLine(this.text, this.color);

  final String text;
  final int color;
}

/// 전투 하나를 화면이 굴리는 상태 (B4-01).
///
/// ## 콘솔 운전자와 무엇이 다른가
///
/// `HDBattleRunner` 는 `UiHost` 의 메뉴를 **기다린다** — 규칙이 물으면
/// `await showWindowMenu` 로 멈춘다. 화면은 그렇게 못 한다. 위젯은 매
/// 프레임 다시 그려지므로, 물음은 **상태로 놓여 있어야** 한다.
///
/// 그래서 이 클래스는 뒤집혀 있다 — `decision` 을 밖에 내놓고 기다리며,
/// 위젯이 [choose] 로 답한다. `packages/hd_battle` 은 한 줄도 안 바뀐다.
///
/// ## 한 걸음씩 보여 준다
///
/// 라운드 하나를 한꺼번에 풀면 열 줄이 동시에 나타난다. 이벤트를 큐에
/// 담아 두고 [tick] 마다 하나씩 흘려서, 무슨 일이 일어나는지 보이게 한다.
///
/// ## 물릴 수 있다
///
/// 전투는 **시드 + 명령 열**이면 완전히 재현된다. 그래서 [undo] 는
/// 판을 새로 만들고 명령을 하나 적게 다시 먹이는 것으로 끝난다.
/// 다른 수를 보려고 처음부터 다시 치지 않아도 된다.
class HDBattleController extends ChangeNotifier {
  HDBattleController(this.setup) {
    _reset();
  }

  final hb.BattleSetup setup;

  hb.Battle _battle = hb.Battle(
    const hb.BattleSetup(party: [], enemyKeys: [], seed: 0),
  );
  hb.Battle get battle => _battle;

  final List<HDBattleLine> _log = [];
  List<HDBattleLine> get log => List.unmodifiable(_log);

  /// 아직 화면에 안 흘린 이벤트.
  final List<hb.BattleEvent> _queue = [];

  /// 지금까지 사람이 낸 명령. [undo] 와 재현이 이것을 쓴다.
  final List<hb.BattleCommand> _used = [];
  bool get canUndo => _used.isNotEmpty;

  Timer? _timer;

  /// 한 줄이 나타나는 간격. 0 이면 기다리지 않는다.
  Duration pace = const Duration(milliseconds: 110);
  bool get isFast => pace == Duration.zero;

  bool get isFinished => _battle.isFinished;
  hb.BattleOutcome? get outcome => _battle.outcome;

  /// 지금 사람에게 물어볼 것. 아직 보여 줄 줄이 남아 있으면 **감춘다** —
  /// 방금 무슨 일이 있었는지 못 본 채로 다음 명령을 내리게 되면 안 된다.
  hb.BattleDecision? get decision =>
      _queue.isEmpty ? _battle.pendingDecision : null;

  late final _Names _names = _Names(() => _battle);

  void _reset() {
    _battle = hb.Battle(setup);
    _log.clear();
    _queue.clear();
  }

  /// 큐가 비면 model 을 한 걸음 밀어 다시 채운다.
  void _pump() {
    while (_queue.isEmpty &&
        !_battle.isFinished &&
        _battle.pendingDecision == null) {
      _queue.addAll(_battle.advance());
    }
  }

  /// 큐에서 한 줄 꺼내 화면에 올린다. 남은 것이 있으면 `true`.
  bool _reveal() {
    if (_queue.isEmpty) return false;
    final event = _queue.removeAt(0);
    if (event is hb.RoundStarted) _log.clear();
    final color = tx.battleLineColor(event);
    for (final line in tx.battleLines(event, _names)) {
      _log.add(HDBattleLine(line, color));
    }
    return true;
  }

  /// 화면이 붙으면 부른다.
  void start() {
    _pump();
    _schedule();
    notifyListeners();
  }

  void _schedule() {
    _timer?.cancel();
    if (_queue.isEmpty) return;
    if (pace == Duration.zero) {
      _drain();
      notifyListeners();
      return;
    }
    _timer = Timer.periodic(pace, (_) {
      _reveal();
      _pump();
      if (_queue.isEmpty) _timer?.cancel();
      notifyListeners();
    });
  }

  /// 남은 줄을 지금 다 흘린다 — 기다리기 싫을 때.
  void skipAhead() {
    _timer?.cancel();
    _drain();
    notifyListeners();
  }

  void setPace(Duration next) {
    pace = next;
    _schedule();
    notifyListeners();
  }

  /// 사람의 답.
  void choose(hb.BattleCommand command) {
    if (_battle.pendingDecision == null) return;
    _used.add(command);
    _queue.addAll(_battle.applyCommand(command));
    _pump();
    _schedule();
    notifyListeners();
  }

  /// 마지막 명령을 무른다. 판을 새로 만들고 하나 적게 다시 먹인다.
  void undo() {
    if (_used.isEmpty) return;
    _replay(_used.length - 1);
  }

  /// 처음부터 다시.
  void restart() => _replay(0);

  void _replay(int keep) {
    _timer?.cancel();
    final commands = _used.take(keep).toList();
    _used
      ..clear()
      ..addAll(commands);
    _reset();
    // 기다리지 않고 그대로 다시 돌린다. `_reveal` 이 라운드가 열릴 때마다
    // 로그를 비우므로, 끝나면 **지금 라운드의 줄만** 남는다 — 되감은
    // 자리에서 화면이 원래 그랬을 모습 그대로다.
    for (final command in commands) {
      _drain();
      if (_battle.pendingDecision == null) break;
      _queue.addAll(_battle.applyCommand(command));
    }
    _drain();
    notifyListeners();
  }

  /// 큐가 마를 때까지 즉시 흘린다.
  void _drain() {
    _pump();
    while (_reveal()) {
      _pump();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 슬롯·적 번호를 이름으로. 판이 바뀌어도 늘 **지금** 판을 본다.
class _Names implements tx.BattleNames {
  _Names(this.current);

  final hb.Battle Function() current;

  @override
  tx.HDNoun member(int slot) =>
      tx.HDNoun(current().party.firstWhere((c) => c.slot == slot).name);

  @override
  tx.HDNoun enemy(int index) => tx.HDNoun(current().enemies[index].name);

  @override
  String weapon(int slot) =>
      current().party.firstWhere((c) => c.slot == slot).snapshot.weaponName;
}
