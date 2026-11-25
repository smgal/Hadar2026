import 'dart:async';

import 'game_window.dart';

/// 편지 화면의 방식 — `Letter::Show` 의 둘째 값(`LETTER_*`, `assets/common/const.cm2`).
enum HDLetterMode {
  /// 한 번에 보인다.
  still(0),

  /// 아래에서 위로 흘러 올라온다 (3편 오프닝 편지 · 엔딩 B 의 알비레오 편지).
  scroll(1),

  /// 한 번에 보이고, 키를 누를 때까지 드물게 번개가 번쩍인다 (1·2편 엔딩 · 3편 엔딩 C).
  lightning(2),

  /// 1편 「공헌한 인물」 — 번개가 번쩍이다가, 첫 키를 누르면 번개가 멎고 오른쪽 가장자리를
  /// 제작자가 걸어 내려간다(되풀이). 다음 키에 닫힌다 (LOREEND.PAS:157~210).
  credits(3);

  const HDLetterMode(this.wire);
  final int wire;

  static HDLetterMode fromWire(int v) =>
      values.firstWhere((m) => m.wire == v, orElse: () => still);
}

/// 검은 화면 한 장에 쓴 글 — 오프닝 편지와 엔딩 글 (13 §13.7 · §13.10).
///
/// 게임 안의 대화 창이 아니라 화면 전체를 쓴다. 색은 원작 16색 번호
/// (`HDTextUtils.colorTable` 의 열쇠, `'C'` 빨강 · `'E'` 노랑 …)이고 문단 안에서
/// `@X…@@` 로 바꿀 수 있다. 아무 키나 누르면 닫힌다 — 흘러 올라오는 중이면
/// 첫 키는 끝까지 건너뛰기만 한다.
class HDLetterWindow extends HDWindow {
  HDLetterWindow({
    required this.paragraphs,
    this.color = 'F',
    this.mode = HDLetterMode.still,
    this.pictures,
  }) {
    x = 0;
    y = 0;
    w = 800;
    h = 480;
    settled = mode != HDLetterMode.scroll;
    isVisible = true;
  }

  final List<String> paragraphs;
  final String color;
  final HDLetterMode mode;

  /// 문단마다 왼쪽에 붙일 1부 인물 그림(`lore1_chara.png` 번호) — 줄마다 번호 목록. 없으면 null.
  final List<List<List<int>>?>? pictures;

  /// [HDLetterMode.credits] 에서 제작자가 걷기 시작했는가 (첫 키 뒤).
  bool walking = false;

  void startWalking() {
    walking = true;
    notifyListeners();
  }

  /// 글이 다 자리를 잡았는가. 흘러 올라오는 편지는 다 올라온 뒤 true.
  bool settled = false;

  final Completer<void> _closed = Completer<void>();

  Future<void> waitForClose() => _closed.future;

  /// 흘러 올라오는 중이면 끝까지 건너뛴다.
  void skip() {
    settled = true;
    notifyListeners();
  }

  void close() {
    if (!_closed.isCompleted) _closed.complete();
    isVisible = false;
    notifyListeners();
  }
}
