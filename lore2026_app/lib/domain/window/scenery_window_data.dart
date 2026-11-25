import 'dart:async';

import '../map/map_unit.dart';
import 'game_window.dart';

/// 먼 곳의 풍경 — 크리스탈 볼이 다음 원혼이 있는 자리를 비춰 준다
/// (3편 들판, 05 §5.4 L2).
///
/// 다른 맵의 [columns]×[rows] 칸을 그 맵의 그림 그대로 보인다. 일행은 그리지
/// 않는다. 밤이고 달이 없으면 [dark] 로 어둡게 그린다. 아무 키나 누르면 닫힌다.
class HDSceneryWindow extends HDWindow {
  HDSceneryWindow({
    required this.columns,
    required this.rows,
    required this.units,
    this.tileOverrides = const {},
    this.dark = false,
  }) {
    // 맵 화면과 같은 칸 크기(32)로, 화면(800×480) 가운데에.
    w = columns * 32 + 20;
    h = rows * 32 + 20;
    x = (800 - w) ~/ 2;
    y = (480 - h) ~/ 2;
    isVisible = true;
  }

  final int columns;
  final int rows;

  /// 칸마다 그 맵의 칸(그림 네 겹). 맵 밖이면 null. 행 우선.
  final List<MapUnit?> units;

  /// 그 맵의 바닥 그림 대체표 (`MapModel.tileOverrides`).
  final Map<int, int> tileOverrides;

  final bool dark;

  final Completer<void> _closed = Completer<void>();

  Future<void> waitForClose() => _closed.future;

  void close() {
    if (!_closed.isCompleted) _closed.complete();
    isVisible = false;
    notifyListeners();
  }
}
