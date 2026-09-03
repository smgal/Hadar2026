import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';
import 'package:hadar2026_app/hd_config.dart';

Future<void> _run(String source) async {
  final engine = HDScriptEngine();
  await engine.loadFromString(source);
  await engine.run();
}

void main() {
  // Flag::Set(300) used to vanish with no log at all: the range guard had
  // no `else` (GROUND_TRUTH F-1). That is a different failure from an
  // unregistered symbol (§9), which at least prints "Unknown command".
  // These tests pin the behaviour — that the write does not land and the
  // in-range path is untouched — not the wording of the warning.

  setUp(() {
    final o = HDGameSession().gameOption;
    for (var i = 0; i < HDConfig.maxFlags; i++) {
      o.flags[i] = false;
    }
    for (var i = 0; i < HDConfig.maxVariables; i++) {
      o.variables[i] = 0;
    }
  });

  test('an out-of-range Flag::Set changes nothing', () async {
    await _run('Flag::Set(300)\nFlag::Set(-1)\n');
    final flags = HDGameSession().gameOption.flags;
    expect(flags.every((f) => f == false), isTrue);
  });

  test('an in-range Flag::Set still works', () async {
    await _run('Flag::Set(7)\n');
    expect(HDGameSession().gameOption.flags[7], isTrue);
    await _run('Flag::Reset(7)\n');
    expect(HDGameSession().gameOption.flags[7], isFalse);
  });

  test('an out-of-range Variable::Set / Add changes nothing', () async {
    await _run('Variable::Set(300, 9)\nVariable::Add(300, 9)\n');
    expect(
      HDGameSession().gameOption.variables.every((v) => v == 0),
      isTrue,
    );
  });

  test('an in-range Variable::Set / Add still works', () async {
    await _run('Variable::Set(3, 5)\nVariable::Add(3, 2)\n');
    expect(HDGameSession().gameOption.variables[3], 7);
  });

  // The reads keep returning 0 — changing that would flip existing cm2
  // branches, which is beyond a pure repair.
  test('out-of-range reads still return 0', () async {
    await _run('''
Variable::Set(0, Flag::IsSet(300))
Variable::Set(1, Variable::Get(300))
''');
    expect(HDGameSession().gameOption.variables[0], 0);
    expect(HDGameSession().gameOption.variables[1], 0);
  });

  test('the boundary index is in range, one past it is not', () async {
    await _run('Flag::Set(${HDConfig.maxFlags - 1})\n');
    expect(HDGameSession().gameOption.flags[HDConfig.maxFlags - 1], isTrue);

    await _run('Flag::Set(${HDConfig.maxFlags})\n');
    // Nothing to assert beyond "no crash and no extra flag" — the array
    // is exactly maxFlags long.
    expect(HDGameSession().gameOption.flags.length, HDConfig.maxFlags);
  });
}
