import 'dart:io';

import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_console/fixture.dart';
import 'package:hd_battle_console/palette.dart';
import 'package:hd_battle_console/runner.dart';

const String _usage = '''
hd_battle_console — 전투 model 을 콘솔에서 직접 돌린다.

  dart run bin/battle.dart <fixture.json>              대화형으로 플레이
  dart run bin/battle.dart <fixture.json> --replay     기록된 명령 열 재생
  dart run bin/battle.dart <fixture.json> --record=<방침> [--out=<경로>]
  dart run bin/battle.dart <fixture.json> --seed=<정수>

옵션
  --replay          fixture 의 명령 열을 그대로 먹인다. 출력이 결정적이다
  --record=<방침>   방침대로 플레이하며 명령 열을 만든다
                    (attack · auto · escape · magic · magic-all · special · heal ·
                    esp · item)
                    `heal:21` 처럼 `:` 뒤에 마법 id 를 붙이면 그것을 고른다
  --out=<경로>      --record 결과를 fixture 파일로 저장
  --seed=<정수>     fixture 의 시드를 덮어쓴다
  --no-status       매 턴 상태 표를 출력하지 않는다
  --color           색을 강제로 켠다 (파일·파이프로 보낼 때)
  --no-color        색을 끈다. 환경 변수 NO_COLOR 도 같은 일을 한다

view 는 이 패키지에만 있고 model(packages/hd_battle)은 화면을 모른다.
출력 줄 앞의 `·` 는 **원작에 없던 줄**이다 (독 피해·골드·턴 구분).
색은 원작의 16색 표와 색 번호를 그대로 옮긴 것이다 — lib/palette.dart 참고.
''';

int main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final flags = args.where((a) => a.startsWith('--')).toList();

  String? flagValue(String name) {
    for (final f in flags) {
      if (f == '--$name') return '';
      if (f.startsWith('--$name=')) return f.substring(name.length + 3);
    }
    return null;
  }

  // 색은 터미널일 때만 기본으로 켠다. NO_COLOR 는 관례대로 존중한다
  // (값이 무엇이든 정의되어 있으면 끈다). stdout 과 stderr 을 따로 보는
  // 것은 한쪽만 파일로 보내는 경우가 있어서다.
  final noColorEnv = Platform.environment.containsKey('NO_COLOR');
  bool colorFor(Stdout s) =>
      s.hasTerminal && s.supportsAnsiEscapes && !noColorEnv;
  var useColor = colorFor(stdout);
  var useColorErr = colorFor(stderr);
  if (flagValue('color') != null) {
    useColor = true;
    useColorErr = true;
  }
  if (flagValue('no-color') != null) {
    useColor = false;
    useColorErr = false;
  }
  final ansi = useColor ? const HDAnsi() : HDAnsi.plain;
  final err = useColorErr ? const HDAnsi() : HDAnsi.plain;

  String fail(Object text) =>
      err.render('$text', defaultColor: HDColor.lightRed);
  String hint(Object text) =>
      err.render('$text', defaultColor: HDColor.lightGray);

  if (positional.isEmpty) {
    stdout.write(ansi.render(_usage, defaultColor: HDColor.lightGray));
    _listFixtures(ansi);
    return 0;
  }

  final path = positional.first;
  if (!File(path).existsSync()) {
    stderr.writeln(fail('fixture 를 찾을 수 없다: $path'));
    _listFixtures(ansi);
    return 2;
  }

  var fixture = Fixture.load(path);

  final seed = flagValue('seed');
  if (seed != null && seed.isNotEmpty) {
    final parsed = int.tryParse(seed);
    if (parsed == null) {
      stderr.writeln(fail('--seed 는 정수여야 한다: $seed'));
      return 2;
    }
    fixture = Fixture(
      name: fixture.name,
      note: fixture.note,
      setup: BattleSetup(
        party: fixture.setup.party,
        enemyKeys: fixture.setup.enemyKeys,
        seed: parsed,
        mode: fixture.setup.mode,
      ),
      commands: fixture.commands,
    );
  }

  final record = flagValue('record');
  final CommandSource source;
  if (record != null && record.isNotEmpty) {
    try {
      source = policy(record);
    } on ArgumentError catch (e) {
      stderr.writeln(fail(e.message));
      return 2;
    }
  } else if (flagValue('replay') != null) {
    if (fixture.commands.isEmpty) {
      stderr.writeln(fail('이 fixture 에는 명령 열이 없다. --record 로 먼저 만들어야 한다.'));
      return 2;
    }
    source = replay(fixture.commands);
  } else {
    source = interactive(ansi: ansi);
  }

  final runner = BattleRunner(
    fixture: fixture,
    source: source,
    showStatus: flagValue('no-status') == null,
    ansi: ansi,
  );

  try {
    runner.run();
  } on StateError catch (e) {
    stderr.writeln('\n${fail('[중단] ${e.message}')}');
    return 1;
  } on ArgumentError catch (e) {
    // 기록된 명령 열이 지금의 전투와 맞지 않는다. --seed 를 바꾸거나
    // 규칙이 바뀌면 이렇게 된다 — 스택 트레이스 대신 할 일을 알려준다.
    stderr.writeln('\n${fail('[중단] 기록된 명령이 지금 상황에 맞지 않는다: ${e.message}')}');
    stderr.writeln(
      hint(
        '  시드나 규칙이 바뀌면 명령 열을 다시 만들어야 한다:\n'
        '  dart run bin/battle.dart $path --record=attack --out=$path',
      ),
    );
    return 1;
  }

  final out = flagValue('out');
  if (out != null && out.isNotEmpty) {
    fixture.withCommands(runner.used).save(out);
    stdout.writeln(
      ansi.render(
        '\n명령 열 ${paint(HDColor.white, runner.used.length)}개를 '
        '${paint(HDColor.white, out)} 에 저장했다.',
        defaultColor: HDColor.lightGray,
      ),
    );
  }
  return 0;
}

void _listFixtures(HDAnsi ansi) {
  final dir = Directory('fixtures');
  if (!dir.existsSync()) return;
  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) return;
  stdout.writeln(ansi.render('있는 fixture', defaultColor: HDColor.yellow));
  for (final f in files) {
    try {
      final fx = Fixture.load(f.path);
      stdout.writeln(
        ansi.render(
          '  ${paint(HDColor.lightCyan, f.path.padRight(40))}${fx.name}'
          '${fx.commands.isEmpty ? "" : " (명령 열 ${fx.commands.length}개)"}',
          defaultColor: HDColor.lightGray,
        ),
      );
    } catch (_) {
      stdout.writeln(
        ansi.render(
          '  ${f.path.padRight(40)} (읽을 수 없음)',
          defaultColor: HDColor.red,
        ),
      );
    }
  }
}
