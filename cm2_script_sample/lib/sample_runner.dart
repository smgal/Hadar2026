import 'dart:async';
import 'dart:io';

import 'package:cm2_script/cm2_script.dart';

/// Creates and configures a [ScriptEngine] with CUI commands and script file loading.
class SampleRunner {
  SampleRunner({required this.scriptsPath});

  final String scriptsPath;

  late final ScriptEngine _engine = _createEngine();

  ScriptEngine get engine => _engine;

  ScriptEngine _createEngine() {
    final contentLoader = (String path) async {
      final file = File(scriptsPath + '/$path');
      if (!await file.exists()) throw Exception('Script not found: $path');
      return file.readAsString();
    };

    final e = ScriptEngine(contentLoader: contentLoader);

    e.registerCommand('Print', (stmt, eng) async {
      final msg = eng.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '').toString();
      print(msg);
    });

    e.registerCommand('Choice', (stmt, eng) async {
      final args = stmt.args;
      if (args.isEmpty) return;
      final prompt = eng.getVal(args[0]).toString();
      print(prompt);
      for (var i = 1; i < args.length; i++) {
        print('  ${i}. ${eng.getVal(args[i])}');
      }
      stdout.write('> ');
      final line = stdin.readLineSync();
      final n = int.tryParse(line?.trim() ?? '') ?? 1;
      eng.variables['choice'] = n.clamp(1, args.length - 1);
    });

    e.registerCommand('Wait', (stmt, eng) async {
      final ms = (eng.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '0') as num).toInt();
      await Future.delayed(Duration(milliseconds: ms));
    });

    e.registerCommand('SetMode', (stmt, eng) async {
      final m = (eng.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '0') as num).toInt();
      eng.scriptMode = m;
    });

    e.registerFunction('GetChoice', (args, eng) => eng.variables['choice'] ?? 0);

    return e;
  }

  Future<void> runScript(String scriptPath) async {
    final content = await File(scriptsPath + '/$scriptPath').readAsString();
    await _engine.loadFromString(content);
    await _engine.run(onError: (e, st) {
      print('ScriptEngine Error: $e');
      print(st);
    });
  }
}
