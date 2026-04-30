import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/console/console_log.dart';

void main() {
  group('HDConsoleLog', () {
    test('events and progress are independent channels', () {
      final log = HDConsoleLog();
      log.appendEvent('story line');
      log.appendProgress('progress line', maxLinesPerPage: 14);

      expect(log.events, ['story line']);
      expect(log.progress, ['progress line']);
    });

    test('clearEvents leaves progress untouched', () {
      final log = HDConsoleLog();
      log.appendEvent('e1');
      log.appendProgress('p1', maxLinesPerPage: 14);

      log.clearEvents();

      expect(log.events, isEmpty);
      expect(log.progress, ['p1']);
    });

    test('clearProgress leaves events untouched', () {
      final log = HDConsoleLog();
      log.appendEvent('e1');
      log.appendProgress('p1', maxLinesPerPage: 14);

      log.clearProgress();

      expect(log.events, ['e1']);
      expect(log.progress, isEmpty);
    });

    test('appendProgress drops the oldest line once the cap is reached', () {
      final log = HDConsoleLog();
      for (int i = 0; i < 14; i++) {
        log.appendProgress('p$i', maxLinesPerPage: 14);
      }
      // 15th append should evict 'p0' so the rolling window stays at 14.
      log.appendProgress('p14', maxLinesPerPage: 14);

      expect(log.progress.length, 14);
      expect(log.progress.first, 'p1');
      expect(log.progress.last, 'p14');
    });
  });
}
