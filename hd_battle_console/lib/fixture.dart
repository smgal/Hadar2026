import 'dart:convert';
import 'dart:io';

import 'package:hd_battle/hd_battle.dart';

/// 전투 하나를 재현하는 데 필요한 전부를 담은 파일.
///
/// 세 가지가 고정되면 결과가 결정적이라, **같은 파일이 콘솔 시연용이자
/// 회귀 테스트 입력**이 된다.
///
/// - [setup] — 전투 개시 입력 (파티 스냅샷 + 적 키 목록 + 난수 시드)
/// - [commands] — 명령 열. 비어 있으면 사람이 직접 입력한다
/// - [record] — 명령 열을 **어떤 방침으로 다시 만드는지**
/// - 시드는 [setup] 안에 있다
///
/// [record] 가 있어야 규칙이 바뀔 때 fixture 를 한 번에 되살릴 수 있다.
/// 전에는 방침이 주석에만 있어서 손으로 하나씩 다시 기록해야 했다.
class Fixture {
  const Fixture({
    required this.name,
    required this.setup,
    this.note = '',
    this.commands = const [],
    this.record = 'attack',
  });

  final String name;
  final String note;
  final BattleSetup setup;
  final List<BattleCommand> commands;

  /// 명령 열을 다시 만들 때 쓸 방침 (`attack` · `heal:21` 등).
  ///
  /// `dart run tool/make_fixtures.dart` 가 이 값으로 전부 다시 기록한다.
  final String record;

  Fixture withCommands(List<BattleCommand> next) => Fixture(
    name: name,
    note: note,
    setup: setup,
    commands: next,
    record: record,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'note': note,
    'record': record,
    'setup': setup.toJson(),
    'commands': [for (final c in commands) c.toJson()],
  };

  factory Fixture.fromJson(Map<String, dynamic> j) => Fixture(
    name: j['name'] as String? ?? '(이름 없음)',
    note: j['note'] as String? ?? '',
    record: j['record'] as String? ?? 'attack',
    setup: BattleSetup.fromJson(j['setup'] as Map<String, dynamic>),
    commands: [
      for (final c in (j['commands'] as List? ?? []))
        BattleCommand.fromJson(c as Map<String, dynamic>),
    ],
  );

  static Fixture load(String path) => Fixture.fromJson(
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  );

  void save(String path) {
    File(path).parent.createSync(recursive: true);
    File(path).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n',
    );
  }
}

/// 앱의 전투 실험실이 읽는 fixture 사본이 놓이는 곳.
///
/// Flutter 의 asset 경로는 패키지 밖(`../`)을 가리킬 수 없다. 그래서
/// **저작은 여기 한 곳**에서 하고, `tool/make_fixtures.dart` 가 만들 때
/// 앱 쪽에도 같은 파일을 떨군다. 어긋나면 `fixture_mirror_test.dart` 가 잡는다.
const String appFixtureRoot = '../hadar2026_app/assets/battle';

/// `fixtures/rules/orc_x3.json` → `../hadar2026_app/assets/battle/rules/orc_x3.json`
String appMirror(String fixturePath) =>
    '$appFixtureRoot/${fixturePath.replaceFirst('fixtures/', '')}';
