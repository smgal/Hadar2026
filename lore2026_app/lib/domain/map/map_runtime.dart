/// 지금 서 있는 맵에만 해당하는 설정 — 스크립트가 `FLAG_MAP` 에서 정한다.
///
/// 맵을 옮기면 비워지고, 새 맵의 스크립트가 다시 채운다. **세이브에도
/// 들어간다**: 불러올 때는 저장해 둔 칸 배열을 그대로 되살리므로 `FLAG_MAP`
/// 을 다시 돌리지 않는다(돌리면 가입한 동료 자리를 지우는 식의 변경이 두 번
/// 적용된다). 그래서 스크립트가 정해 둔 것을 여기서 같이 실어 보낸다.
class HDMapRuntime {
  /// 이 맵에서 막히는 마법 (`HANDICAP_*`, `assets/common/const.cm2`).
  final Set<int> handicaps = {};

  /// 무작위 조우에 나오는 적 번호들 (그 편의 적 표 번호). 같은 번호가
  /// 여러 번 있으면 그만큼 자주 나온다.
  final List<int> encounterTable = [];

  /// 조우가 켜져 있는가. 표가 비어 있으면 켜져 있어도 조우는 없다.
  bool encounterEnabled = false;

  /// 완전한 암흑 구역 안인가 (코볼트성). 횃불이 있어도 보이지 않는다.
  bool darkZone = false;

  /// 지금 흐르는 곡. 불러온 뒤 다시 틀기 위해 적어 둔다.
  String? music;

  /// 공간 이동 · 기화 이동이 건너지 못하는 사각형들 (엔진 좌표, 0부터,
  /// `(x1, y1, x2, y2)` 양 끝 포함) — `Map::SetMagicBarrier`. 지나가는 칸이나
  /// 내려서는 칸이 하나라도 안에 들면 마법이 배척된다. 와이번 줄 · 이블 실의
  /// 문 줄처럼 「걸어서 지나가야 하는 줄」을 지킨다.
  final List<(int, int, int, int)> magicBarriers = [];

  bool isBarrier(int x, int y) {
    for (final (x1, y1, x2, y2) in magicBarriers) {
      if (x >= x1 && x <= x2 && y >= y1 && y <= y2) return true;
    }
    return false;
  }

  bool blocks(int handicap) => handicaps.contains(handicap);

  bool get hasEncounters => encounterEnabled && encounterTable.isNotEmpty;

  void clear() {
    handicaps.clear();
    encounterTable.clear();
    encounterEnabled = false;
    darkZone = false;
    music = null;
    magicBarriers.clear();
  }

  Map<String, dynamic> toJson() => {
    'handicaps': handicaps.toList()..sort(),
    'encounterTable': encounterTable,
    'encounterEnabled': encounterEnabled,
    'darkZone': darkZone,
    if (music != null) 'music': music,
    if (magicBarriers.isNotEmpty)
      'magicBarriers': [
        for (final (x1, y1, x2, y2) in magicBarriers) [x1, y1, x2, y2],
      ],
  };

  void fromJson(Map<String, dynamic>? json) {
    clear();
    if (json == null) return;
    handicaps.addAll((json['handicaps'] as List? ?? const []).whereType<int>());
    encounterTable.addAll(
      (json['encounterTable'] as List? ?? const []).whereType<int>(),
    );
    encounterEnabled = json['encounterEnabled'] as bool? ?? false;
    darkZone = json['darkZone'] as bool? ?? false;
    music = json['music'] as String?;
    for (final r in json['magicBarriers'] as List? ?? const []) {
      if (r is List && r.length == 4 && r.every((v) => v is int)) {
        magicBarriers.add((r[0] as int, r[1] as int, r[2] as int, r[3] as int));
      }
    }
  }
}

/// `Map::SetHandicap` 의 번호 — `assets/common/const.cm2` 의 `HANDICAP_*` 와
/// 같은 순서다.
abstract final class HDHandicap {
  static const int tileChanging = 0; // 지형 변화
  static const int bigTileChanging = 1; // 대지형 변화
  static const int ethereal = 2; // 기화 이동
  static const int teleport = 3; // 공간 이동 · 이동 구슬
  static const int eagleEye = 4; // 주시자의 눈 · 수정 구슬
  static const int seeThrough = 5; // 투시
  static const int clairvoyance = 6; // 천리안
}
