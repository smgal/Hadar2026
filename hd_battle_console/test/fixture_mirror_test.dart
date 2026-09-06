@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:hd_battle_console/fixture.dart';
import 'package:test/test.dart';

/// 앱의 전투 실험실이 읽는 사본이 여기와 같은가.
///
/// Flutter 의 asset 경로는 패키지 밖을 못 가리켜서 같은 파일이 두 곳에 있다.
/// **저작은 `fixtures/` 한 곳**이고 앱 쪽은 `tool/make_fixtures.dart` 가
/// 함께 떨군 것이다. 손으로 한쪽만 고치면 여기서 걸린다.
void main() {
  final sources =
      Directory('fixtures')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('훑을 fixture 가 있다', () {
    expect(sources, isNotEmpty);
  });

  test('목록을 그릴 색인이 있다', () {
    final index = File('$appFixtureRoot/index.json');
    expect(index.existsSync(), isTrue);
    expect(
      (jsonDecode(index.readAsStringSync()) as List),
      hasLength(sources.length),
      reason: 'fixture 하나마다 한 줄이어야 한다',
    );
  });

  test('앱 쪽 사본이 하나도 빠지지 않고 같다', () {
    final stale = <String>[];
    for (final source in sources) {
      final path = source.path.replaceAll(r'\', '/');
      final mirror = File(appMirror(path));
      if (!mirror.existsSync()) {
        stale.add('${mirror.path} 없음');
        continue;
      }
      if (mirror.readAsStringSync() != source.readAsStringSync()) {
        stale.add('${mirror.path} 내용이 다름');
      }
    }
    expect(stale, isEmpty, reason: 'dart run tool/make_fixtures.dart 로 다시 만든다');
  });

  test('앱 쪽에 남아도는 사본이 없다', () {
    final root = Directory(appFixtureRoot);
    expect(root.existsSync(), isTrue);
    final expected = {
      // 목록을 그리는 색인. fixture 의 사본은 아니지만 같이 만들어진다.
      '$appFixtureRoot/index.json',
      for (final s in sources) appMirror(s.path.replaceAll(r'\', '/')),
    };
    final extra = [
      for (final f in root.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.json') &&
            !expected.contains(f.path.replaceAll(r'\', '/')))
          f.path,
    ];
    expect(extra, isEmpty, reason: '지워진 fixture 의 사본이 남아 있다');
  });
}
