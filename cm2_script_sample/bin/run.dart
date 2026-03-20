import 'dart:io';

import 'package:cm2_script_sample/sample_runner.dart';

void main() async {
  _printTitle();
  final scriptDir = Directory.current.path + '/scripts';
  final runner = SampleRunner(scriptsPath: scriptDir);
  await runner.runScript('main.script');
  final score = runner.engine.variables['score'];
  if (score != null) {
    print('\n  📊 Final score: $score');
  }
  print('\n  👋 Thanks for playing!\n');
}

void _printTitle() {
  print('');
  print(r'   ____  __  __  ___    ____  ____  _____ _____ _     ');
  print(r'  / ___||  \/  |/ _ \  / ___|/ ___||_   _|_   _| |    ');
  print(r' | |    | |\/| | | | | \___ \___ \  | |   | | | |    ');
  print(r' | |___ | |  | | |_| |  ___) |__) | | |   | | | |___ ');
  print(r'  \____||_|  |_|\___/  |____/____/  |_|   |_| |_____|');
  print('');
  print('  📜 CUI Sample — Interactive Story + Mini Quiz');
  print('');
}
