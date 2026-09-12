@TestOn('vm')
library;

import 'dart:io';

import 'package:cm2_script/cm2_script.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';
import 'package:hd_world/hd_world.dart';
import 'package:hd_world_legacy/hd_world_legacy.dart' as legacy;

/// 출하되는 `assets/*.cm2` 전체를 훑는 감사.
///
/// **cm2 는 틀려도 멈추지 않는다.** 모르는 명령은 "Unknown command" 한 줄을
/// 찍고 넘어가고, 모르는 함수는 **0 을 돌려줘서** 조용히 다른 갈래로 간다.
/// 그래서 오타 하나가 퀘스트 한 줄기를 통째로 죽여도 게임은 멀쩡히 돈다 —
/// 사람이 읽어서 잡을 수 있는 종류의 결함이 아니다. 기계가 훑는다.
///
/// 실제로 이 감사가 잡은 것: `town2.cm2` 가 `"name"` 을 `"_name"` 으로
/// 쓰고 있어서 `Equal(Player::GetAttribute(6, "_name"), "Mad Joe")` 가
/// 영원히 거짓이었다.

class _Silent implements UiHost, PartyMovementHost, AssetSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 한 파일이 쓰는 모든 명령·함수 이름.
class _Symbols {
  final Set<String> commands = {};
  final Set<String> functions = {};

  /// 인자 없이 조건에 쓰인 이름 — 변수여야 한다.
  final Set<String> reads = {};
}

void _walk(List<ScriptStatement> statements, _Symbols out) {
  for (final stmt in statements) {
    if (stmt is CommandStatement) {
      out.commands.add(stmt.command);
      for (final arg in stmt.args) {
        _expression(arg, out);
      }
    } else if (stmt is IfStatement) {
      // 인자 없는 조건은 함수 호출이 아니라 **변수 읽기**다 —
      // `if (temp)`. 엔진도 `getVal('temp')` 로 변수를 찾는다.
      if (stmt.conditionArgs.isEmpty) {
        out.reads.add(stmt.conditionFunc);
      } else {
        out.functions.add(stmt.conditionFunc);
      }
      for (final arg in stmt.conditionArgs) {
        _expression(arg, out);
      }
      _walk(stmt.body, out);
      _walk(stmt.elseBody, out);
    }
  }
}

/// 인자 안에 또 함수 호출이 있을 수 있다 — `Not(Flag::IsSet(x))`.
void _expression(String raw, _Symbols out) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('"')) return; // 문자열 안은 코드가 아니다
  if (!trimmed.contains('(')) return;
  final parsed = parseCommand(trimmed);
  if (parsed.command == trimmed) return;
  out.functions.add(parsed.command);
  for (final arg in parsed.args) {
    _expression(arg, out);
  }
}

/// 접미사로 처리되는 멤버 호출 형태 (`temp.assign` · `x.add` · `x.Equal`).
bool _memberForm(String name) =>
    name.endsWith('.assign') ||
    name.endsWith('.add') ||
    name.endsWith('.Equal');

void main() {
  final files =
      Directory('assets')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.cm2'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  setUp(() {
    final silent = _Silent();
    HDHosts().bind(ui: silent, movement: silent, assets: silent);
  });
  tearDown(HDHosts().reset);

  test('훑을 파일이 있다', () {
    expect(files, isNotEmpty);
  });

  test('모르는 명령·함수가 하나도 없다', () {
    final engine = HDScriptEngine();
    final knownCommands = {
      ...engine.registeredCommands,
      ...ScriptEngine.builtinCommands,
    };
    final knownFunctions = {
      ...engine.registeredFunctions,
      ...ScriptEngine.builtinFunctions,
    };

    // 변수는 파일 경계를 넘는다 — `include("const.cm2")` 로 들어온
    // 이름을 그 파일 안에서만 찾으면 안 된다.
    final declared = <String>{};
    final parsed = <String, _Symbols>{};
    for (final file in files) {
      final symbols = _Symbols();
      final statements = ScriptEngine.parse(file.readAsStringSync());
      _walk(statements, symbols);
      parsed[file.path] = symbols;
      for (final stmt in statements) {
        if (stmt is CommandStatement &&
            stmt.command == 'variable' &&
            stmt.args.isNotEmpty) {
          declared.add(stmt.args.first.trim());
        }
      }
    }

    final unknown = <String>[];
    parsed.forEach((path, symbols) {
      for (final name in symbols.commands) {
        if (name.isEmpty || _memberForm(name)) continue;
        if (!knownCommands.contains(name)) {
          unknown.add('$path: command $name');
        }
      }
      for (final name in symbols.functions) {
        if (name.isEmpty || _memberForm(name)) continue;
        if (!knownFunctions.contains(name)) {
          unknown.add('$path: function $name');
        }
      }
      for (final name in symbols.reads) {
        if (name.isEmpty) continue;
        if (!declared.contains(name) && !knownFunctions.contains(name)) {
          unknown.add('$path: neither variable nor function $name');
        }
      }
    });
    expect(unknown, isEmpty);
  });

  // `Player::(Get|Change)Attribute` 의 속성 이름은 오타가 나도
  // `default:` 로 빠진다 — 읽기는 0 을, 쓰기는 아무 일도 안 한다.
  // 실제 코드에 통과시켜서 그 갈래로 가는지 본다.
  test('cm2 가 쓰는 속성 이름이 전부 실제로 있다', () {
    final keys = <String, List<String>>{};
    final pattern = RegExp(
      r'Player::(Get|Change|Revise)Attribute\(\s*[^,]+,\s*"([^"]*)"',
    );
    for (final file in files) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        keys.putIfAbsent(match.group(2)!, () => []).add(file.path);
      }
    }
    expect(keys, isNotEmpty, reason: '적어도 몇 개는 쓰고 있어야 한다');

    final complaints = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) complaints.add(message);
    };
    try {
      for (final key in keys.keys) {
        // 속성 이름이 이 빌드에 있는지 묻는다. 이제 「모른다」와
        // 「있지만 아무것도 안 한다」가 다른 답이라(부록 Z-7 다음 단계)
        // 감사가 전자만 불평한다.
        final probe = Member(ref: const MemberRef('probe'), name: 'probe');
        final read = legacy.readAttribute(
          probe,
          key,
          catalog: ItemCatalog.builtIn,
        );
        if (read == null) {
          complaints.add('Player::GetAttribute("$key") — no such attribute');
        }
        final wrote = legacy.writeAttribute(
          probe,
          key,
          key == 'name' ? 'x' : 1,
          equip: (_, __) => true,
        );
        if (wrote.verdict == legacy.AttributeVerdict.unknown) {
          complaints.add(
            'Player::ChangeAttribute("$key") — ${wrote.detail}',
          );
        }
      }
    } finally {
      debugPrint = previous;
    }
    // `pow_of_weapon` 처럼 **일부러** 무시하고 경고하는 이름이 있다
    // (장비가 정하는 값이라 스크립트가 덮으면 둘이 갈린다, 부록 H-5).
    // 감사가 볼 것은 "그런 속성이 없다" 쪽뿐이다.
    expect(
      complaints.where((c) => c.contains('no such attribute')),
      isEmpty,
      reason: 'cm2 가 부르는 속성 이름 중 실제로 없는 것이 있다',
    );
  });

  // `flag4ep1.cm2:42-43` 이 이랬다:
  //
  //     variable(GFD1_OPEN_DOWN_STAIRS)
  //     GFD1_OPEN_ODD_WALL.assign(15)     ← 왼쪽 이름이 틀렸다
  //
  // 엔진은 `variable(X)` 를 **0 으로** 만들어 두므로 경고조차 나지 않는다.
  // 그래서 `GFD1_OPEN_DOWN_STAIRS` 가 0 이 되어 `GFD0_IS_FIRST` 와 **같은
  // 플래그**가 됐고, d0 의 첫 방문 이벤트가 지나면 d1 의 아래층 계단이
  // 이미 열린 것으로 읽혔다.
  test('선언만 하고 값을 안 준 이름이 없다', () {
    final declared = <String, String>{};
    final valued = <String>{};
    final declaration = RegExp(r'^variable\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)');
    // `.add` 로만 쓰는 누산기는 0 에서 시작하는 것이 맞다 — 값이 주어진
    // 것으로 본다. 잡으려는 것은 **아무도 값을 주지 않은 상수**다.
    final given = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\.(assign|add)\(');
    for (final file in files) {
      var lineNo = 0;
      for (final raw in file.readAsLinesSync()) {
        lineNo++;
        final line = raw.trim();
        if (line.startsWith('#')) continue;
        final d = declaration.firstMatch(line);
        if (d != null) {
          declared.putIfAbsent(d.group(1)!, () => '${file.path}:$lineNo');
        }
        final g = given.firstMatch(line);
        if (g != null) valued.add(g.group(1)!);
      }
    }
    expect(declared, isNotEmpty);
    final orphans = [
      for (final entry in declared.entries)
        if (!valued.contains(entry.key)) '${entry.value}: ${entry.key}',
    ];
    expect(orphans, isEmpty, reason: '값을 못 받은 이름은 조용히 0 이 된다');
  });

  // Map002.cm2 가 이랬다 — 이겨도 스크립트가 모르니 같은 싸움이 계속
  // 다시 시작됐다. 결과를 안 읽는 전투는 끝나지 않는 전투다.
  test('전투를 시작한 파일은 그 결과도 읽는다', () {
    final offenders = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync();
      final starts = 'Battle::Start'.allMatches(text).length;
      final reads = 'Battle::Result'.allMatches(text).length;
      if (starts > reads) {
        offenders.add('${file.path}: Start x$starts, Result x$reads');
      }
    }
    expect(offenders, isEmpty);
  });
}
