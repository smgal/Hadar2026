@TestOn('vm')
library;

import 'dart:io';

import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_console/fixture.dart';
import 'package:hd_battle_console/runner.dart';
import 'package:hd_battle_console/view.dart';
import 'package:test/test.dart';

/// B1-05 의 완료 판정: fixture 가 끝까지 돌고, 두 번 돌리면 출력이 같다.
void main() {
  // fixture 는 두 벌이다 — `original/`(원작 조우, 원작 파티)과
  // `rules/`(규칙 시연, 5인 파티). 재귀로 훑는다.
  final files =
      Directory('fixtures')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('fixture 가 있다', () {
    expect(files, isNotEmpty);
  });

  List<String> replayLines(Fixture fixture) {
    final lines = <String>[];
    BattleRunner(
      fixture: fixture,
      source: replay(fixture.commands),
      sink: lines.add,
    ).run();
    return lines;
  }

  group('모든 fixture', () {
    for (final file in files) {
      final fixture = Fixture.load(file.path);

      test('${file.uri.pathSegments.last} — 끝까지 돌고 결과가 결정적이다', () {
        expect(
          fixture.commands,
          isNotEmpty,
          reason: '명령 열이 없으면 재생할 수 없다 — --record 로 만든다',
        );

        final first = replayLines(fixture);
        final second = replayLines(fixture);
        expect(second, first, reason: '같은 시드·같은 명령 열인데 출력이 갈렸다');
        expect(first.any((l) => l.contains('종료 코드')), isTrue);
      });

      test('${file.uri.pathSegments.last} — JSON 왕복', () {
        final again = Fixture.fromJson(fixture.toJson());
        expect(again.toJson(), fixture.toJson());
      });
    }
  });

  group('종료 코드 세 갈래가 모두 시연된다', () {
    test('승리·전멸·도주 fixture 가 각각 있다', () {
      final codes = <BattleResultCode>{};
      for (final file in files) {
        final fixture = Fixture.load(file.path);
        if (fixture.commands.isEmpty) continue;
        final battle = Battle(fixture.setup);
        final source = replay(fixture.commands);
        final view = BattleView(battle);
        while (!battle.isFinished) {
          final decision = battle.pendingDecision;
          if (decision == null) {
            battle.advance();
          } else {
            battle.applyCommand(source(decision, view)!);
          }
        }
        codes.add(battle.outcome!.resultCode);
      }
      expect(
        codes,
        containsAll([
          BattleResultCode.win,
          BattleResultCode.lose,
          BattleResultCode.evade,
        ]),
      );
    });
  });
}
