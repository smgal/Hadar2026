import 'dart:io';

import 'package:cm2_lsp/src/analyzer.dart';
import 'package:cm2_lsp/src/index.dart';
import 'package:cm2_lsp/src/server.dart';
import 'package:cm2_lsp/src/symbol_table.dart';
import 'package:cm2_lsp/src/workspace.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:path/path.dart' as p;

const _usage = '''
cm2 언어 서버 / 검사기

  dart run bin/cm2_lsp.dart [--symbols 표.json] [--assets 폴더]
      stdio 로 LSP 를 말한다 (VS Code 확장이 이렇게 띄운다).

  dart run bin/cm2_lsp.dart --check [--symbols 표.json] [--assets 폴더] 파일.cm2 ...
      파일들을 검사해 진단을 찍고, 오류가 하나라도 있으면 1 로 끝난다.
      CI 나 AI 가 만든 스크립트를 실행 없이 훑을 때 쓴다.
''';

Future<void> main(List<String> args) async {
  String? symbolsPath;
  var assetsDir = '';
  var check = false;
  final files = <String>[];

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--symbols':
        if (i + 1 < args.length) symbolsPath = args[++i];
      case '--assets':
        if (i + 1 < args.length) assetsDir = args[++i];
      case '--check':
        check = true;
      case '--help' || '-h':
        stdout.write(_usage);
        return;
      default:
        files.add(args[i]);
    }
  }

  final symbols = await SymbolTable.load(path: symbolsPath);

  if (check) {
    exit(_check(symbols, assetsDir, files));
  }

  final connection = Connection(stdin, stdout);
  Cm2Server(connection, symbols, assetsDir: assetsDir).register();
  await connection.listen();
}

int _check(SymbolTable symbols, String assetsDir, List<String> files) {
  if (files.isEmpty) {
    stderr.write(_usage);
    return 2;
  }
  var errors = 0;
  var total = 0;
  // One workspace for the whole run: includes and flag files parse once.
  final workspace = Workspace(assetsDir: assetsDir);
  for (final raw in files) {
    final path = p.normalize(p.absolute(raw));
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('$raw: 파일이 없다');
      errors++;
      continue;
    }
    List<Finding> findings;
    try {
      findings = analyze(
        path: path,
        index: Cm2Index.build(file.readAsStringSync()),
        symbols: symbols,
        workspace: workspace,
        // The hint is for an editor; a CLI listing every handler is noise.
        options: const AnalyzeOptions(eventOverrideHint: false),
      );
    } catch (e) {
      // A file the parser cannot read at all is itself an error — but one
      // file, not the whole run.
      stdout.writeln('${p.basename(path)}:1:1: error [parse-error] 파서가 이 파일을 읽지 못했습니다: $e');
      errors++;
      total++;
      continue;
    }
    for (final f in findings) {
      if (f.severity == Severity.hint) continue;
      total++;
      if (f.severity == Severity.error) errors++;
      final tag = switch (f.severity) {
        Severity.error => 'error',
        Severity.warning => 'warning',
        _ => 'info',
      };
      stdout.writeln('${p.basename(path)}:${f.span.line + 1}:${f.span.start + 1}: $tag [${f.code}] ${f.message}');
    }
  }
  stdout.writeln('${files.length} 파일, 진단 $total 건, 오류 $errors 건');
  return errors > 0 ? 1 : 0;
}
