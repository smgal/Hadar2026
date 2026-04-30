import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/presentation/host/flutter_ui_host.dart';

void main() {
  // Wrap calculation inside addLog uses TextPainter, which needs a
  // ServicesBinding for font metrics.
  TestWidgetsFlutterBinding.ensureInitialized();

  HDFlutterUiHost host() => HDFlutterUiHost();

  setUp(() {
    host().resetForTest();
  });

  group('HDFlutterUiHost.viewMode', () {
    test('starts in progress mode', () {
      expect(host().viewMode, HDConsoleViewMode.progress);
    });

    test('beginNarrative switches to overlay even without events/menu', () {
      host().beginNarrative();
      expect(host().viewMode, HDConsoleViewMode.overlay);
    });

    test('endNarrative returns to progress and clears events', () async {
      host().beginNarrative();
      host().consoleLog.appendEvent('story');
      expect(host().viewMode, HDConsoleViewMode.overlay);

      await host().endNarrative(autoFlush: false);

      expect(host().viewMode, HDConsoleViewMode.progress);
      expect(host().consoleLog.events, isEmpty);
    });

    test('endNarrative pushes the summary onto progress', () async {
      host().beginNarrative();
      host().consoleLog.appendEvent('rest detail');

      await host().endNarrative(
        summary: '일행이 잠시 쉬었다.',
        autoFlush: false,
      );

      expect(host().consoleLog.events, isEmpty);
      expect(host().consoleLog.progress, ['일행이 잠시 쉬었다.']);
      expect(host().viewMode, HDConsoleViewMode.progress);
    });

    test('overlay is held even when events briefly empty within a cycle',
        () async {
      // Reproduces the page-flush window: a narrative cycle is open and
      // events get cleared (e.g. after a PressAnyKey). Without
      // _narrativeActive, viewMode would flicker back to progress.
      host().beginNarrative();
      host().consoleLog.appendEvent('p1');
      host().consoleLog.clearEvents();
      expect(host().viewMode, HDConsoleViewMode.overlay,
          reason: '_narrativeActive must keep overlay open');
    });

    test('beginNarrative is idempotent', () {
      host().beginNarrative();
      host().beginNarrative();
      expect(host().viewMode, HDConsoleViewMode.overlay);
    });

    test('endNarrative autoFlush waits when events are still on screen',
        () async {
      // Reproduces the [Sig] bug: a one-shot sign whose script left a
      // line on screen without a PressAnyKey. autoFlush must hold the
      // overlay until a key arrives, not flash the text away.
      host().beginNarrative();
      host().consoleLog.appendEvent('표지판: 이곳은 마을입니다.');

      final future = host().endNarrative();
      // Pump microtasks so endNarrative reaches its waitForAnyKey().
      await Future<void>.delayed(Duration.zero);

      expect(host().isWaitingForKey, isTrue,
          reason: 'autoFlush should keep the overlay open via waitForAnyKey');
      expect(host().consoleLog.events, isNotEmpty,
          reason: 'events must remain visible until the key arrives');

      host().dismissKeyWait();
      await future;

      expect(host().consoleLog.events, isEmpty);
      expect(host().viewMode, HDConsoleViewMode.progress);
    });

    test('endNarrative does not wait when events are already empty',
        () async {
      // The Talk → PressAnyKey → clearLogs CM2 path leaves events empty
      // by the time the dispatcher unwinds; autoFlush must be a no-op.
      host().beginNarrative();

      await host().endNarrative();

      expect(host().isWaitingForKey, isFalse);
      expect(host().viewMode, HDConsoleViewMode.progress);
    });

    test('endNarrative(autoFlush: false) skips the wait', () async {
      host().beginNarrative();
      host().consoleLog.appendEvent('caller knows it has been read');

      await host().endNarrative(autoFlush: false);

      expect(host().isWaitingForKey, isFalse);
      expect(host().consoleLog.events, isEmpty);
    });
  });

}
