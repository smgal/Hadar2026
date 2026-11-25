/// 맵 칸과 따로 그려지는 인물 — 장면 속에서 걷는 병사 · 떠나는 감독.
///
/// 칸의 그림을 바꿔 사람을 옮기면 지나간 자리의 바닥(빨간 양탄자)이 지워지고,
/// 사람은 칸 단위로 뚝뚝 움직이는데 주인공은 칸 사이를 미끄러지듯 움직여
/// 둘이 어긋난다. 배우는 칸 위에 **겹쳐** 그려지고 주인공과 같은 빠르기로
/// 칸 사이를 움직인다.
///
/// 장면 동안만 산다 — 맵을 옮기면 사라지고 세이브에도 들어가지 않는다.
class HDActor {
  HDActor({
    required this.id,
    required this.a5,
    required this.sprite,
    this.cutout = -1,
    this.strip = -1,
    required int x,
    required int y,
  }) : x = x,
       y = y,
       _fromX = x,
       _fromY = y;

  final String id;

  /// 원작 사람 그림에서 바닥을 뺀 투명한 그림(`Lore_C` 번호). -1 이면 없다.
  /// 그리는 순서: [strip] → [cutout] → [sprite] → [a5].
  final int cutout;

  /// 3부 스프라이트 띠(`lore_sprite_transparent.png`, 24px 28칸)의 번호. -1 이면
  /// 없다. 에너지 공(20) · 네크로만서(25·26) · 드라코니안킹의 큰 모습(14~19) ·
  /// 제작자(24)처럼 타일 표에 없는 그림을 세울 때 쓴다 (`Actor::ShowSprite`).
  final int strip;

  /// 하다르의 투명한 인물 그림(`Lore_B` 번호). 0 이면 없다.
  final int sprite;

  /// `Lore_A5` 번호 — 투명한 그림이 없을 때 쓰는 칸 그림(바탕까지 그려져 있다).
  final int a5;

  /// 지금 향하는 칸 (엔진 좌표, 0 부터).
  int x;
  int y;

  int _fromX;
  int _fromY;
  int _startMs = 0;
  int _durationMs = 0;

  /// 한 칸 움직이기 시작한다. [nowMs] 는 [HDActorClock] 의 시각.
  void stepBy(int dx, int dy, {required int nowMs, required int durationMs}) {
    final (cx, cy) = positionAt(nowMs);
    _fromX = cx.round();
    _fromY = cy.round();
    x = _fromX + dx;
    y = _fromY + dy;
    _startMs = nowMs;
    _durationMs = durationMs;
  }

  /// [nowMs] 에 그려질 자리 (칸 단위, 소수).
  (double, double) positionAt(int nowMs) {
    if (_durationMs <= 0 || nowMs >= _startMs + _durationMs) {
      return (x.toDouble(), y.toDouble());
    }
    final t = (nowMs - _startMs) / _durationMs;
    return (_fromX + (x - _fromX) * t, _fromY + (y - _fromY) * t);
  }

  /// 움직임이 끝나는 시각.
  int get arrivesAtMs => _startMs + _durationMs;
}

/// 배우들이 함께 쓰는 시계 — 그리는 쪽과 움직이는 쪽이 같은 시각을 본다.
class HDActorClock {
  HDActorClock._();
  static final Stopwatch _watch = Stopwatch()..start();
  static int get nowMs => _watch.elapsedMilliseconds;
}
