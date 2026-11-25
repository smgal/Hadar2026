import 'dart:async';
import 'dart:typed_data';

import 'game_window.dart';

/// 지도 한 장 — 주시자의 눈 · 수정 구슬이 보여 주는 것 (제13장 13.4).
///
/// 칸마다 종류 하나를 색으로 칠한다. 일행의 자리는 깜빡인다. 아무 키나
/// 누르면 닫힌다.
class HDMapOverviewWindow extends HDWindow {
  HDMapOverviewWindow({
    required this.columns,
    required this.rows,
    required this.cells,
    required this.partyX,
    required this.partyY,
    this.title = '',
  }) {
    // 화면(800×480) 가운데에, 맵 비율을 지키며 최대한 크게.
    const maxW = 560, maxH = 400;
    final scale = (maxW / columns < maxH / rows) ? maxW / columns : maxH / rows;
    w = (columns * scale).round() + 20;
    h = (rows * scale).round() + 44;
    x = (800 - w) ~/ 2;
    y = (480 - h) ~/ 2;
    isVisible = true;
  }

  final int columns;
  final int rows;

  /// 칸마다 [HDOverviewCell] 의 번호. 행 우선.
  final Uint8List cells;
  final int partyX;
  final int partyY;
  final String title;

  final Completer<void> _closed = Completer<void>();

  Future<void> waitForClose() => _closed.future;

  void close() {
    if (!_closed.isCompleted) _closed.complete();
    isVisible = false;
    notifyListeners();
  }
}

/// 지도에 칠하는 칸의 종류. 색은 원작의 것을 따른다: 통로 검정 · 벽 흰색 ·
/// 입구 연두 · 푯말 하늘색 · 물 파랑 · 늪 청록 · 용암 빨강 · 사람 분홍.
abstract final class HDOverviewCell {
  static const int path = 0;
  static const int wall = 1;
  static const int entrance = 2;
  static const int sign = 3;
  static const int water = 4;
  static const int swamp = 5;
  static const int lava = 6;
  static const int person = 7;
}
