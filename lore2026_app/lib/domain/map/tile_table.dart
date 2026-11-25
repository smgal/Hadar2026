import 'map_unit.dart';
import 'tile_properties.dart';

/// How one original tile number is drawn and what it does.
///
/// The Lore originals have one number per cell (0~55) whose meaning
/// depends on the map type and on which of the three games it is. The
/// engine draws in layers, so the converter
/// (`tools/lore_import/import_maps.py`) resolved every number into this
/// tuple once and shipped the result as `assets/maps/tiletable.json`.
class TileEntry {
  const TileEntry({
    required this.a5,
    required this.decor,
    required this.obj0,
    required this.obj1,
    required this.action,
    this.actor = -1,
  });

  /// Index into `Lore_A5` (without the RPG Maker `0x600` base).
  final int a5;
  final int decor;
  final int obj0;
  final int obj1;
  final HDTileAction action;

  /// 이 칸의 사람을 배우로 걷게 할 때 쓰는 투명한 그림(`Lore_C.png` 번호).
  /// -1 이면 없다 — 하다르의 투명한 인물([obj0]·[obj1])이 있거나 사람이 아니다.
  final int actor;

  static const TileEntry solid = TileEntry(
    a5: 0,
    decor: 0,
    obj0: 0,
    obj1: 0,
    action: HDTileAction.none,
  );

  factory TileEntry.fromJson(Map<String, dynamic> j) => TileEntry(
    a5: j['a5'] as int? ?? 0,
    decor: j['decor'] as int? ?? 0,
    obj0: j['obj0'] as int? ?? 0,
    obj1: j['obj1'] as int? ?? 0,
    action: _actionByName[j['action']] ?? HDTileAction.none,
    actor: j['actor'] as int? ?? -1,
  );

  TileEntry withAction(HDTileAction a) => TileEntry(
    a5: a5,
    decor: decor,
    obj0: obj0,
    obj1: obj1,
    action: a,
    actor: actor,
  );

  /// Writes this entry into [unit], the way the converter wrote the cell
  /// in the first place.
  void applyTo(MapUnit unit) {
    unit
      ..ixTile = a5
      ..ixDecor = decor
      ..ixObj0 = obj0
      ..ixObj1 = obj1;
    HDTileProperties.setUnitAction(unit, action);
  }

  static const Map<String, HDTileAction> _actionByName = {
    'none': HDTileAction.none,
    'move': HDTileAction.move,
    'talk': HDTileAction.talk,
    'sign': HDTileAction.sign,
    'enter': HDTileAction.enter,
    'event': HDTileAction.event,
    'water': HDTileAction.water,
    'swamp': HDTileAction.swamp,
    'lava': HDTileAction.lava,
  };
}

/// `assets/maps/tiletable.json`, parsed.
///
/// What it is for at run time: `Map::ChangeTile(x, y, n)` takes an
/// **original** tile number, exactly as the design documents and the
/// original scripts write it, and this table turns it into layers.
class TileTable {
  TileTable._(this._episodes, this._maps, {this.darkTile = 0});

  /// episode → map type → 56 entries (null where no map uses the number).
  final Map<int, Map<String, List<TileEntry?>>> _episodes;

  /// map name → (episode, type, default tile, per-map overrides).
  final Map<String, _MapTiles> _maps;

  /// `Lore_A5` 의 검은 칸. 투시가 숨은 이벤트 칸을 드러낼 때 덮는 그림이다.
  final int darkTile;

  static final TileTable empty = TileTable._(const {}, const {});

  factory TileTable.fromJson(Map<String, dynamic> j) {
    final episodes = <int, Map<String, List<TileEntry?>>>{};
    for (final ep in (j['episodes'] as Map<String, dynamic>).entries) {
      episodes[int.parse(ep.key)] = {
        for (final t in (ep.value as Map<String, dynamic>).entries)
          t.key: [
            for (final e in t.value as List)
              e == null ? null : TileEntry.fromJson(e as Map<String, dynamic>),
          ],
      };
    }
    final maps = <String, _MapTiles>{};
    for (final m in (j['maps'] as Map<String, dynamic>).entries) {
      final v = m.value as Map<String, dynamic>;
      maps[m.key] = _MapTiles(
        episode: v['episode'] as int,
        type: v['type'] as String,
        defaultTile: v['default'] as int? ?? 0,
        overrides: {
          for (final t in (v['tiles'] as Map<String, dynamic>).entries)
            int.parse(t.key): TileEntry.fromJson(
              t.value as Map<String, dynamic>,
            ),
        },
      );
    }
    return TileTable._(episodes, maps, darkTile: j['darkTile'] as int? ?? 0);
  }

  bool knows(String mapName) => _maps.containsKey(mapName);

  /// The map's "기본 타일" — what a hidden event cell is drawn as, and what
  /// a person's cell becomes when they leave.
  int defaultTile(String mapName) => _maps[mapName]?.defaultTile ?? 0;

  /// How tile [tile] of map [mapName] is drawn and what it does.
  ///
  /// Tile 0 is the hidden event cell: the map's default tile's picture,
  /// with the event action. An unknown number comes back solid rather
  /// than throwing — a script typo should not take the map down.
  TileEntry entry(String mapName, int tile) {
    final m = _maps[mapName];
    if (m == null) return TileEntry.solid;
    return _resolve(m, tile) ?? TileEntry.solid;
  }

  /// 원작 타일 번호는 0~55 다.
  static const int tileCount = 56;

  /// [unit] 이 지금 원작 타일 [tile] 로 깔려 있는가.
  ///
  /// 바닥 그림 · 물체 두 겹 · 행동이 [entry] 와 모두 같으면 그렇다. 바닥
  /// 장식(decor)은 보지 않는다 — 사람이 그 위를 걸어 다니고 행동을 정하지
  /// 않는다. 그 맵에서 쓰이지 않는 번호면 언제나 아니다.
  bool matches(String mapName, MapUnit unit, int tile) {
    final m = _maps[mapName];
    if (m == null) return false;
    final e = _resolve(m, tile);
    if (e == null) return false;
    return unit.ixTile == e.a5 &&
        unit.ixObj0 == e.obj0 &&
        unit.ixObj1 == e.obj1 &&
        HDTileProperties.getUnitAction(unit) == e.action;
  }

  /// [unit] 에 지금 깔린 원작 타일 번호 — [entry] 의 반대 방향.
  ///
  /// 그림과 행동이 똑같은 번호가 둘이면 작은 번호를 돌려준다. 그런 짝은
  /// 두 가지다 — 들판의 23·49, 동굴·성채 몇 곳(제1부 피라미드 · 제2부
  /// 베리알의 동굴 · 제3부 메너스 금광 등)의 0·52. 조건을 볼 때는 번호를
  /// 비교하지 말고 [matches] 를 쓰면 짝이 있어도 틀리지 않는다.
  /// 맞는 번호가 없으면 -1.
  int numberOf(String mapName, MapUnit unit) {
    for (var t = 0; t < tileCount; t++) {
      if (matches(mapName, unit, t)) return t;
    }
    return -1;
  }

  /// [tile] 의 풀이. 0 은 숨은 사건 칸 — 그 맵 기본 타일의 그림에 사건
  /// 행동을 붙인 것이다. 그 맵에서 쓰이지 않는 번호면 null.
  TileEntry? _resolve(_MapTiles m, int tile) {
    if (tile == 0) {
      final base = _lookup(m, m.defaultTile);
      return (base ?? TileEntry.solid).withAction(HDTileAction.event);
    }
    return _lookup(m, tile);
  }

  TileEntry? _lookup(_MapTiles m, int tile) {
    final own = m.overrides[tile];
    if (own != null) return own;
    final row = _episodes[m.episode]?[m.type];
    if (row == null || tile <= 0 || tile >= row.length) return null;
    return row[tile];
  }
}

class _MapTiles {
  const _MapTiles({
    required this.episode,
    required this.type,
    required this.defaultTile,
    required this.overrides,
  });

  final int episode;
  final String type;
  final int defaultTile;
  final Map<int, TileEntry> overrides;
}
