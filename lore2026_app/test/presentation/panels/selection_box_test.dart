import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;
import 'package:lore2026_app/domain/window/selection_window_data.dart';
import 'package:lore2026_app/presentation/panels/window_view.dart';

/// 선택 창은 가장 긴 줄에 맞춰 넓어지고, 화면(800) 안에 머문다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('짧은 줄만 있으면 정해 둔 자리와 너비 그대로', () {
    final w = HDSelectionWindow(choices: ['당신의 성별은?', '남성', '여성'], x: 200, y: 100);
    expect(HDWindowWidget.selectionBox(w), (200.0, 400.0));
  });

  test('주인공 만들기 6번 질문 — 창이 넓어지고 왼쪽으로 옮겨 화면 안에 들어간다', () {
    final long = <String>[
      for (var v = 0; v < 2; v++) ...wt.questionChoices(5, v),
    ].reduce((a, b) => a.length >= b.length ? a : b);
    expect(long, contains('끝까지 열려 한다'));
    final w = HDSelectionWindow(choices: ['당신의 선택은?', long], x: 300, y: 250);
    final (left, width) = HDWindowWidget.selectionBox(w);
    expect(width, greaterThan(400));
    expect(left, greaterThanOrEqualTo(8));
    expect(left + width, lessThanOrEqualTo(792));
  });
}
