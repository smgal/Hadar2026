// lore2026_app 의 cm2 스크립트 검사기.
//
// cm2 는 모르는 명령을 건너뛰고 모르는 함수에 0 을 돌려준다 — 오타가 조용히
// 다른 갈래를 탄다. 그래서 실행하기 전에 밖에서 훑는다. 파서는
// `packages/cm2_script` 그대로이고 동사 표는 앱이 읽는
// `assets/common/cm2_symbols.json` 한 곳이다.
//
// 사용법:
//   dart run bin/check.dart --assets ../../lore2026_app/assets [파일...]
// 파일을 안 주면 assets/ep1 · ep2 · ep3 · common 의 *.cm2 전부.
//
// 끝 코드: 오류가 있으면 1. 경고만 있으면 0.
import 'dart:convert';
import 'dart:io';

import 'package:cm2_script/cm2_script.dart';

late Map<String, List<Object?>> commands;
late Map<String, List<Object?>> functions;
late Set<String> builtinCommands;
late Set<String> builtinFunctions;
late Map<String, Map<String, dynamic>> mapsByCm2; // 'ep3/Lore.cm2' → MapInfos 항목 + 크기
late Set<String> mapNames;
late String assetsDir;

final errors = <String>[];
final warnings = <String>[];

/// 편별로 플래그·변수가 어디서 쓰이고 읽히는지.
final flagWrites = <String, Map<String, String>>{};
final flagReads = <String, Map<String, String>>{};
final varWrites = <String, Map<String, String>>{};
final varReads = <String, Map<String, String>>{};

bool _isNumber(String s) => num.tryParse(s) != null;
bool _isString(String s) => s.length >= 2 && s.startsWith('"') && s.endsWith('"');
bool _isCall(String s) => RegExp(r'^[A-Za-z_][A-Za-z0-9_:.]*\s*\(').hasMatch(s) && s.endsWith(')');

String _unq(String s) => _isString(s) ? s.substring(1, s.length - 1) : s;

class FileCtx {
  FileCtx(this.path, this.rel);
  final String path;
  final String rel; // assets 기준 상대 경로
  final variables = <String>{};
  Map<String, dynamic>? map;
  String get episode => rel.split('/').first;
  String at(int line) => '$rel:${line < 0 ? '?' : line + 1}';
}

void collectVariables(List<ScriptStatement> stmts, FileCtx ctx, Set<String> seen) {
  for (final s in stmts) {
    if (s is CommandStatement) {
      if (s.command == 'variable' && s.args.isNotEmpty) ctx.variables.add(s.args[0]);
      if (s.command == 'include' && s.args.isNotEmpty) {
        final inc = _unq(s.args[0]);
        if (seen.add(inc)) {
          final f = File('$assetsDir/$inc');
          if (!f.existsSync()) {
            errors.add('${ctx.at(s.line)}: include("$inc") — 그런 파일이 없다');
          } else {
            collectVariables(parseScript(f.readAsStringSync()), ctx, seen);
          }
        }
      }
    } else if (s is IfStatement) {
      collectVariables(s.body, ctx, seen);
      collectVariables(s.elseBody, ctx, seen);
    }
  }
}

void checkArity(String name, int n, List<Object?> spec, String where, String kind) {
  final lo = spec[0] as int, hi = spec[1] as int;
  if (n < lo || n > hi) {
    errors.add('$where: $kind $name 의 인자가 $n개다 — ${lo == hi ? '$lo개' : '$lo~$hi개'}여야 한다');
  }
}

void checkExpr(String arg, FileCtx ctx, int line) {
  final a = arg.trim();
  if (a.isEmpty || _isNumber(a) || _isString(a)) return;
  if (_isCall(a)) {
    final c = parseCommand(a);
    checkFunction(c.command, c.args, ctx, line);
    return;
  }
  if (a.contains('"')) {
    errors.add('${ctx.at(line)}: 따옴표가 맞지 않는다 — $a');
    return;
  }
  if (!ctx.variables.contains(a)) {
    errors.add('${ctx.at(line)}: 선언되지 않은 이름 `$a` (variable 로 선언하거나 따옴표를 붙인다)');
  }
}

void checkCoords(String name, List<String> args, FileCtx ctx, int line) {
  final m = ctx.map;
  if (m == null) return;
  final w = m['width'] as int, h = m['height'] as int;
  void xy(int ix, int iy) {
    if (args.length <= iy) return;
    final x = int.tryParse(args[ix]), y = int.tryParse(args[iy]);
    if (x != null && (x < 1 || x > w)) {
      errors.add('${ctx.at(line)}: $name 의 x=$x 가 맵 너비 1~$w 밖이다');
    }
    if (y != null && (y < 1 || y > h)) {
      errors.add('${ctx.at(line)}: $name 의 y=$y 가 맵 높이 1~$h 밖이다');
    }
  }

  switch (name) {
    case 'On' || 'Map::ChangeTile' || 'Party::Warp':
      xy(0, 1);
    case 'OnArea' || 'Map::ChangeTileArea' || 'Map::SetLightArea' || 'Map::ResetLightArea':
      xy(0, 1);
      xy(2, 3);
  }
  final tileArg = switch (name) { 'Map::ChangeTile' => 2, 'Map::ChangeTileArea' => 4, _ => -1 };
  if (tileArg >= 0 && args.length > tileArg) {
    final t = int.tryParse(args[tileArg]);
    if (t != null && (t < 0 || t > 55)) {
      errors.add('${ctx.at(line)}: $name 의 타일 번호 $t 가 0~55 밖이다');
    }
  }
}

void noteName(Map<String, Map<String, String>> into, FileCtx ctx, List<String> args, int line, String what) {
  if (args.isEmpty) return;
  if (!_isString(args[0])) {
    if (_isNumber(args[0])) {
      errors.add('${ctx.at(line)}: $what 에 번호를 썼다 — lore2026 은 이름으로 쓴다 ("NAME")');
    }
    return;
  }
  into.putIfAbsent(ctx.episode, () => {}).putIfAbsent(_unq(args[0]), () => ctx.at(line));
}

void checkFunction(String name, List<String> args, FileCtx ctx, int line) {
  if (name.endsWith('.Equal')) {
    final v = name.substring(0, name.length - 6);
    if (!ctx.variables.contains(v)) errors.add('${ctx.at(line)}: 선언되지 않은 변수 `$v`');
  } else if (builtinFunctions.contains(name)) {
    // 인자 수는 내장 쪽이 느슨하다 (And/Or/JoinString 은 가변).
  } else if (functions.containsKey(name)) {
    checkArity(name, args.length, functions[name]!, ctx.at(line), '함수');
  } else if (commands.containsKey(name) || builtinCommands.contains(name)) {
    errors.add('${ctx.at(line)}: `$name` 은 명령이다 — 값을 돌려주지 않으므로 식 안에 쓸 수 없다');
  } else {
    errors.add('${ctx.at(line)}: 모르는 함수 `$name` (0 을 돌려주고 조용히 다른 갈래를 탄다)');
  }
  switch (name) {
    case 'Flag::IsSet':
      noteName(flagReads, ctx, args, line, name);
    case 'Variable::Get':
      noteName(varReads, ctx, args, line, name);
  }
  checkCoords(name, args, ctx, line);
  for (final a in args) {
    checkExpr(a, ctx, line);
  }
}

void checkCommand(CommandStatement s, FileCtx ctx) {
  final name = s.command;
  final where = ctx.at(s.line);
  if (name == 'else') {
    errors.add('$where: 짝이 없는 else (들여쓰기가 if 와 다르다)');
    return;
  }
  if (name.endsWith('.assign') || name.endsWith('.add')) {
    final v = name.substring(0, name.lastIndexOf('.'));
    if (!ctx.variables.contains(v)) errors.add('$where: 선언되지 않은 변수 `$v`');
    if (s.args.length != 1) errors.add('$where: $name 의 인자는 1개여야 한다');
  } else if (name == 'variable') {
    return;
  } else if (name == 'include') {
    return;
  } else if (builtinCommands.contains(name)) {
    // 내장
  } else if (commands.containsKey(name)) {
    checkArity(name, s.args.length, commands[name]!, where, '명령');
  } else if (functions.containsKey(name) || builtinFunctions.contains(name)) {
    errors.add('$where: `$name` 은 함수다 — 명령 자리에 쓰면 아무 일도 하지 않는다');
  } else if (!name.contains('(') && s.args.isEmpty && !RegExp(r'^[A-Za-z_][A-Za-z0-9_:.]*$').hasMatch(name)) {
    errors.add('$where: 명령으로 읽을 수 없는 줄 — $name');
    return;
  } else {
    errors.add('$where: 모르는 명령 `$name` (건너뛴다)');
  }
  switch (name) {
    case 'Flag::Set' || 'Flag::Reset':
      noteName(flagWrites, ctx, s.args, s.line, name);
    case 'Variable::Set' || 'Variable::Add':
      noteName(varWrites, ctx, s.args, s.line, name);
    case 'LoadScript':
      if (s.args.isNotEmpty && _isString(s.args[0]) && !mapNames.contains(_unq(s.args[0]))) {
        errors.add('$where: LoadScript("${_unq(s.args[0])}") — MapInfos.json 에 그런 맵이 없다');
      }
      if (s.args.length == 2) errors.add('$where: LoadScript 의 좌표는 x, y 둘 다 준다');
      if (s.args.length == 3 && _isString(s.args[0])) {
        final target = mapsByCm2.values.where((m) => m['name'] == _unq(s.args[0])).firstOrNull;
        final x = int.tryParse(s.args[1]), y = int.tryParse(s.args[2]);
        if (target != null && x != null && y != null &&
            (x < 1 || x > (target['width'] as int) || y < 1 || y > (target['height'] as int))) {
          errors.add('$where: LoadScript 의 도착 좌표 ($x,$y) 가 ${target['name']} 의 크기 밖이다');
        }
      }
  }
  checkCoords(name, s.args, ctx, s.line);
  for (final a in s.args) {
    checkExpr(a, ctx, s.line);
  }
}

void walk(List<ScriptStatement> stmts, FileCtx ctx) {
  for (final s in stmts) {
    if (s is CommandStatement) {
      checkCommand(s, ctx);
    } else if (s is IfStatement) {
      // 파서는 `if (F())` 의 괄호를 버린다. 인자가 없으면 엔진이 조건을
      // `F` 라는 **글자**로 읽어 늘 참이 된다 — 함수가 불리지 않는다.
      if (s.conditionArgs.isEmpty &&
          (functions.containsKey(s.conditionFunc) ||
              builtinFunctions.contains(s.conditionFunc))) {
        errors.add(
          '${ctx.at(s.line)}: if (${s.conditionFunc}()) 는 늘 참이다 — 인자 없는 함수를 '
          '조건에 단독으로 쓰면 불리지 않는다. Equal(${s.conditionFunc}(), 1) 로 쓴다',
        );
      }
      checkFunction(s.conditionFunc, s.conditionArgs, ctx, s.line);
      if (s.body.isEmpty) warnings.add('${ctx.at(s.line)}: if 의 몸통이 비었다 (들여쓰기를 확인)');
      walk(s.body, ctx);
      walk(s.elseBody, ctx);
    }
  }
}

void checkFile(String path) {
  final rel = path.substring(assetsDir.length + 1);
  final ctx = FileCtx(path, rel)..map = mapsByCm2[rel];
  final text = File(path).readAsStringSync();
  // 탭과 공백이 섞이면 파서가 탭을 8칸으로 세어 블록이 어긋난다.
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final lead = RegExp(r'^[ \t]*').stringMatch(lines[i]) ?? '';
    if (lead.contains(' ') && lead.contains('\t')) {
      errors.add('${ctx.at(i)}: 들여쓰기에 탭과 공백이 섞였다');
    }
    final body = stripComment(lines[i]);
    if ('"'.allMatches(body).length.isOdd) {
      errors.add('${ctx.at(i)}: 따옴표가 홀수 개다 (본문 안의 큰따옴표는 작은따옴표나 「」로 바꾼다)');
    }
    var depth = 0;
    var inStr = false;
    for (final ch in body.split('')) {
      if (ch == '"') inStr = !inStr;
      if (inStr) continue;
      if (ch == '(') depth++;
      if (ch == ')') depth--;
    }
    if (depth != 0 && !inStr) errors.add('${ctx.at(i)}: 괄호가 맞지 않는다');
  }
  final stmts = parseScript(text);
  collectVariables(stmts, ctx, {rel});
  walk(stmts, ctx);
}

void main(List<String> argv) {
  final files = <String>[];
  String? assets;
  for (var i = 0; i < argv.length; i++) {
    if (argv[i] == '--assets') {
      assets = argv[++i];
    } else {
      files.add(argv[i]);
    }
  }
  if (assets == null) {
    stderr.writeln('사용법: dart run bin/check.dart --assets <lore2026_app/assets> [파일...]');
    exit(2);
  }
  assetsDir = Directory(assets).absolute.uri.normalizePath().toFilePath();
  if (assetsDir.endsWith('/')) assetsDir = assetsDir.substring(0, assetsDir.length - 1);

  final sym = jsonDecode(File('$assetsDir/common/cm2_symbols.json').readAsStringSync()) as Map<String, dynamic>;
  commands = (sym['commands'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as List<Object?>));
  functions = (sym['functions'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as List<Object?>));
  builtinCommands = {...(sym['builtinCommands'] as List).cast<String>()};
  builtinFunctions = {...(sym['builtinFunctions'] as List).cast<String>()};

  mapsByCm2 = {};
  mapNames = {};
  final infos = jsonDecode(File('$assetsDir/maps/MapInfos.json').readAsStringSync()) as List;
  for (final info in infos.whereType<Map<String, dynamic>>()) {
    mapNames.add(info['name'] as String);
    final id = (info['id'] as int).toString().padLeft(3, '0');
    final doc = jsonDecode(File('$assetsDir/maps/Map$id.json').readAsStringSync()) as Map<String, dynamic>;
    mapsByCm2[info['cm2'] as String] = {...info, 'width': doc['width'], 'height': doc['height']};
  }

  var targets = files.map((f) => File(f).absolute.uri.normalizePath().toFilePath()).toList();
  if (targets.isEmpty) {
    for (final d in ['common', 'ep1', 'ep2', 'ep3']) {
      final dir = Directory('$assetsDir/$d');
      if (!dir.existsSync()) continue;
      targets.addAll(dir.listSync().whereType<File>().map((f) => f.path).where((p) => p.endsWith('.cm2')));
    }
    targets.sort();
  }
  for (final t in targets) {
    if (!File(t).existsSync()) {
      errors.add('$t: 파일이 없다');
      continue;
    }
    checkFile(t);
  }

  // 플래그·변수 이름: 읽기만 하거나 쓰기만 하는 이름은 오타일 가능성이 높다.
  // 파일 하나만 볼 때는 다른 맵이 짝을 갖고 있을 수 있으므로 전체를 볼 때만 말한다.
  if (files.isEmpty) {
    void cross(String what, Map<String, Map<String, String>> writes, Map<String, Map<String, String>> reads) {
      for (final ep in {...writes.keys, ...reads.keys}) {
        final w = writes[ep] ?? const {}, r = reads[ep] ?? const {};
        for (final e in r.entries) {
          if (!w.containsKey(e.key)) warnings.add('${e.value}: $what "${e.key}" 를 읽지만 $ep 어디서도 쓰지 않는다');
        }
        for (final e in w.entries) {
          if (!r.containsKey(e.key)) warnings.add('${e.value}: $what "${e.key}" 를 쓰지만 $ep 어디서도 읽지 않는다');
        }
      }
    }

    cross('플래그', flagWrites, flagReads);
    cross('변수', varWrites, varReads);
    final expected = mapsByCm2.keys.where((k) => !File('$assetsDir/$k').existsSync()).toList()..sort();
    if (expected.isNotEmpty) warnings.add('스크립트가 아직 없는 맵 ${expected.length}개: ${expected.join(', ')}');
  }

  for (final w in warnings) {
    stdout.writeln('경고  $w');
  }
  for (final e in errors) {
    stdout.writeln('오류  $e');
  }
  stdout.writeln('파일 ${targets.length}개 · 오류 ${errors.length} · 경고 ${warnings.length}');
  exit(errors.isEmpty ? 0 : 1);
}
