import 'package:flutter_test/flutter_test.dart';
import 'package:lore2026_app/presentation/host/flutter_ui_host.dart';

/// 대화 창의 한 쪽 — 머리글이 있으면 그만큼 줄을 덜 담는다.
///
/// 1부 오프닝은 머리글(「오래전부터 만날 운명이었던 당신에게 드리는 글」) 아래에
/// 긴 글을 낸다. 늘 13줄을 담던 때는 13번째 줄이 「계속하려면 누르십시오 ...」
/// 줄을 덮었다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final host = HDFlutterUiHost();

  tearDown(() {
    host.dismissKeyWait();
    host.clearLogs();
  });

  test('머리글이 없으면 13줄, 한 줄 머리글이 있으면 10줄', () {
    host.clearLogs();
    expect(host.linesPerPage, 13);
    host.setHeader('오래전부터 만날 운명이었던 당신에게 드리는 글');
    expect(host.linesPerPage, 10);
  });

  test('머리글 아래에서는 11번째 줄 앞에서 키를 기다린다', () async {
    host.clearLogs();
    host.setHeader('알비레오의 예언서');
    final writing = () async {
      for (var i = 1; i <= 11; i++) {
        await host.addLog('줄 $i');
      }
    }();
    while (!host.isWaitingForKey) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(host.consoleLog.events.length, 10);
    host.dismissKeyWait();
    await writing;
    expect(host.consoleLog.events, ['줄 11']);
    expect(host.header, '알비레오의 예언서'); // 쪽을 넘겨도 머리글은 남는다
  });
}
