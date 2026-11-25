import 'package:flutter/foundation.dart';
import 'package:lore_world/lore_world.dart';

/// Where the party is standing on the current map.
class PartyPosition {
  int x = 0;
  int y = 0;
  int xPrev = 0;
  int yPrev = 0;
  int faced = 0; // 0: 아래, 1: 위, 2: 오른쪽, 3: 왼쪽
  bool isMoving = false;
}

/// 앱 쪽 파티 — **자리(지도 위의 위치)** 와 **세계(`LoreWorld`)** 를 묶는다.
///
/// 인물·소지품·달력·횃불·변화 마법의 효과는 전부 [world] 가 갖는다
/// (`packages/lore_world`, 제3부 시스템). 여기 남는 것은 지도와 얽힌 것
/// 뿐이다: 어디에 서 있는지, 어느 쪽을 보는지.
///
/// hadar2026_app 의 `HDParty` 와 이름이 같은 것은 엔진(지도·입력·화면)이
/// 이 타입을 `party.x` · `party.setFace` 로 쓰기 때문이다. 규칙은 하나도
/// 물려받지 않았다.
class HDParty extends ChangeNotifier {
  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  /// 한 편의 RPG 상태 전부. 새 게임·불러오기가 통째로 갈아 끼운다.
  LoreWorld world = LoreWorld(episode: Episode.ep3);

  final PartyPosition _position = PartyPosition();

  /// 일행 그림을 감췄는가 (`Party::Hide`). 자리와 카메라는 그대로 움직인다 —
  /// 감춘 채 `Party::Warp` 하면 화면만 옮겨 간다(3편 결말 A 의 에필로그).
  /// 맵을 옮겨도 그대로이고, 제목으로 돌아가거나 불러오면 다시 보인다.
  bool hidden = false;

  // ── 사람 ────────────────────────────────────────────────

  /// [seat] 번 자리(0~5)의 사람. 비었거나 숨겨져 있으면 null.
  Member? seat(int seat) => world.member(seat);

  /// 글에 넣을 이름. 자리가 비어 있으면 빈 글자.
  String nameOf(int seat) => world.member(seat)?.name ?? '';

  /// 자리에 앉아 있는 사람들 (0~5번, 숨긴 동료 제외).
  List<Member> get present => world.presentMembers;

  // ── 엔진이 읽는 효과 ───────────────────────────────────

  int get magicTorch => world.torch;
  int get levitation => world.buffs.levitation;
  int get walkOnWater => world.buffs.waterWalk;
  int get walkOnSwamp => world.buffs.swampWalk;

  /// 독심이 남은 걸음 수. 0 보다 크면 마음을 여는 사람들이 있다.
  int get mindControl => world.buffs.mindReadSteps;

  // ── 자리 ────────────────────────────────────────────────

  int get x => _position.x;
  set x(int value) => _position.x = value;
  int get y => _position.y;
  set y(int value) => _position.y = value;
  int get xPrev => _position.xPrev;
  set xPrev(int value) => _position.xPrev = value;
  int get yPrev => _position.yPrev;
  set yPrev(int value) => _position.yPrev = value;
  int get faced => _position.faced;
  set faced(int value) => _position.faced = value;
  bool get isMoving => _position.isMoving;
  set isMoving(bool value) => _position.isMoving = value;

  /// 바라보는 쪽의 한 칸 (dx, dy). 기화 이동·지형 변화·공간 이동·천리안이
  /// 이 방향을 쓴다.
  (int, int) get facing => switch (faced) {
    1 => (0, -1),
    2 => (1, 0),
    3 => (-1, 0),
    _ => (0, 1),
  };

  void setPosition(int newX, int newY) {
    xPrev = x;
    yPrev = y;
    x = newX;
    y = newY;
    notifyListeners();
  }

  void move(int dx, int dy) {
    xPrev = x;
    yPrev = y;
    x += dx;
    y += dy;
    setFace(dx, dy);
  }

  void setFace(int dx, int dy) {
    if (dy > 0) {
      faced = 0;
    } else if (dy < 0) {
      faced = 1;
    } else if (dx > 0) {
      faced = 2;
    } else if (dx < 0) {
      faced = 3;
    }
    notifyListeners();
  }

  /// 한 걸음 전 자리로 되돌린다 (출구에서 「아니오」, 도망친 고정 전투).
  void warpToPrev() {
    x = xPrev;
    y = yPrev;
    notifyListeners();
  }

  // ── 저장 ────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'xPrev': xPrev,
    'yPrev': yPrev,
    'faced': faced,
    'world': world.toJson(),
  };

  /// 저장된 것을 되살린다. 돌려주는 것은 **고쳐 읽은 것들** — 모르는
  /// 물건 키처럼 세계가 버리고 읽은 항목이다. 비어 있으면 깨끗이 읽혔다.
  List<LoadIssue> fromJson(Map<String, dynamic> json) {
    x = json['x'] ?? 0;
    y = json['y'] ?? 0;
    xPrev = json['xPrev'] ?? 0;
    yPrev = json['yPrev'] ?? 0;
    faced = json['faced'] ?? 0;
    final result = LoreWorld.load(json['world']);
    world = result.world;
    notifyListeners();
    return result.issues;
  }
}
