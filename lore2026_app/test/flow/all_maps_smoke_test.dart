import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';

import 'fake_hosts.dart';

/// 세 편의 맵을 하나씩 열어 본다 — 맵에 들어설 때 도는 시작 스크립트
/// (`FLAG_MAP`)가 던지지 않고 끝나는지, cm2 가 모르는 이름을 만나지 않는지.
///
/// 정적 검사기(`tools/lore_cm2_check`)는 이름만 본다. 이 시험은 실제로 돌린다.
/// cm2 엔진은 모르는 명령·함수를 `print` 로, 어댑터는 잘못 쓴 인자를
/// `debugPrint`(`[cm2] …`)로 알린다 — 둘 다 모아서 본다.
/// 물음에는 맨 앞 답을 고른다(편 고르기만 정해 둔다).
void main() {
  late List<String> logs;
  final original = debugPrint;

  setUp(() {
    logs = [];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = original;
    HDHosts().reset();
  });

  final infos = jsonDecode(File('assets/maps/MapInfos.json').readAsStringSync()) as List;

  for (final episode in [1, 2, 3]) {
    final names = [
      for (final e in infos)
        if (e != null && e['episode'] == episode && e['cm2'] != null) e['name'] as String,
    ];
    test('제$episode부 맵 ${names.length}개의 시작 스크립트', () async {
      final ui = ScriptedUi((items) => items.first.contains('3부작') ? episode : 1);
      final session = HDGameSession();
      final engine = HDScriptEngine();
      HDHosts().bind(
        ui: ui,
        movement: InstantMovement(session.party.move),
        assets: DiskAssets(),
      );
      await session.init();
      session.resetToTitle();
      await HDTitleFlow().run();
      await engine.executePendingNavigation();

      final failures = <String>[];
      var printsSeen = 0;
      for (final name in names) {
        logs.clear();
        engine.pendingNavigation = (path: name, hasExplicit: false, nx: 0, ny: 0);
        session.clearCurrentMap();
        try {
          // cm2 엔진은 모르는 이름을 print 로 알린다 — 그것도 모은다
          await runZoned(
            () => engine.executePendingNavigation().timeout(const Duration(seconds: 20)),
            zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, line) => logs.add(line),
            ),
          );
        } catch (e) {
          failures.add('$name: $e');
          continue;
        }
        printsSeen += logs.where((l) => l.contains('Including common/const.cm2')).length;
        final bad = logs.where(
          (l) => l.contains('Unknown') || l.contains('[cm2]') || l.contains('Error') || l.contains('error'),
        );
        if (bad.isNotEmpty) failures.add('$name: ${bad.take(3).join(' | ')}');
      }
      // 모으기가 실제로 동작한다 — 맵마다 cm2 엔진이 print 로 내는 줄이 모였다
      expect(printsSeen, greaterThanOrEqualTo(names.length));
      expect(failures, isEmpty, reason: failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
