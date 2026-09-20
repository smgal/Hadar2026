@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/hd_config.dart';

import 'known_verbs.dart';

/// VS Code 확장의 동사 표가 **실제 등록과 같은지** 본다.
///
/// 편집기의 빨간 줄과 CI 의 감사(`cm2_assets_audit_test.dart`)는 같은
/// 이름 목록을 봐야 한다. 그런데 어댑터는 Flutter 를 끌어오므로 언어
/// 서버(순수 Dart)가 직접 import 할 수 없다. 그래서 이름·인자·설명을
/// `tools/vscode-cm2/server/lib/data/cm2_symbols.json` 에 손으로 적고,
/// 이 시험이 두 목록이 어긋나는 순간 알린다.
///
/// 동사를 등록하거나 지우면 JSON 도 고친다. 어느 쪽이 빠졌는지 실패
/// 메시지가 이름으로 말한다.

void main() {
  final jsonFile = File(
    '../tools/vscode-cm2/server/lib/data/cm2_symbols.json',
  );

  setUp(bindSilentHosts);
  tearDown(HDHosts().reset);

  test('동사 표 파일이 있다', () {
    expect(jsonFile.existsSync(), isTrue, reason: jsonFile.path);
  });

  test('동사 표의 명령·함수 이름이 실제 등록과 같다', () {
    final registeredCommands = knownCm2Commands();
    final registeredFunctions = knownCm2Functions();

    final doc = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
    final symbols = (doc['symbols'] as List).cast<Map<String, dynamic>>();
    final tableCommands = <String>{};
    final tableFunctions = <String>{};
    for (final s in symbols) {
      final name = s['name'] as String;
      switch (s['kind'] as String) {
        case 'command':
          tableCommands.add(name);
        case 'function':
          tableFunctions.add(name);
        default:
          fail('$name: kind 는 command 또는 function 이어야 한다');
      }
    }

    String diff(String what, Set<String> code, Set<String> table) {
      final onlyCode = code.difference(table).toList()..sort();
      final onlyTable = table.difference(code).toList()..sort();
      final lines = <String>[];
      if (onlyCode.isNotEmpty) {
        lines.add('$what — 코드에는 있는데 JSON 에 없음: ${onlyCode.join(', ')}');
      }
      if (onlyTable.isNotEmpty) {
        lines.add('$what — JSON 에는 있는데 코드에 없음: ${onlyTable.join(', ')}');
      }
      return lines.join('\n');
    }

    final problems = [
      diff('명령', registeredCommands, tableCommands),
      diff('함수', registeredFunctions, tableFunctions),
    ].where((s) => s.isNotEmpty).join('\n');

    expect(
      problems,
      isEmpty,
      reason:
          '${jsonFile.path} 를 고쳐 실제 등록과 맞춘다.\n$problems',
    );
  });

  // 편집기의 「0~255 밖」 판정과 마우스 도움말의 숫자는 이 값에서 나온다.
  // 앱의 상수가 바뀌면 여기서 걸려야 표가 조용히 낡지 않는다.
  test('동사 표의 maxFlags 가 HDConfig.maxFlags 와 같다', () {
    final doc = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
    expect(doc['maxFlags'], HDConfig.maxFlags);
  });

  test('동사 표의 항목마다 params 와 doc 이 있다', () {
    final doc = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
    final symbols = (doc['symbols'] as List).cast<Map<String, dynamic>>();
    final missing = <String>[];
    for (final s in symbols) {
      final name = s['name'];
      if (s['params'] is! List) missing.add('$name: params');
      if ((s['doc'] as String?)?.trim().isEmpty ?? true) {
        missing.add('$name: doc');
      }
    }
    expect(missing, isEmpty);
  });
}
