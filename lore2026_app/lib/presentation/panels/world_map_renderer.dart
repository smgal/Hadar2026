import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';

import '../../application/game_session.dart';
import '../../domain/lighting/sight_calculator.dart';
import '../../domain/map/actor.dart';
import '../../domain/map/map_model.dart';
import '../../domain/party/party.dart';
import '../../hd_game_main.dart';
import '../host/flutter_ui_host.dart';

/// Renders the tiled map and the per-tile shadow/visibility overlay.
/// Game rules (sight radius, moonlight, light bit) come from
/// [HDSightCalculator]; this class only loads sprite sheets and paints.
class HDWorldMap extends WorldMap {
  final MapModel mapModel;

  SpriteSheet? _tileSheetA5;
  SpriteSheet? _tileSheetB;
  SpriteSheet? _actorSheet; // Lore_C — 바닥을 뺀 원작 사람 그림
  SpriteSheet? _stripSheet; // 3부 스프라이트 띠 — 24px, 타일 표에 없는 그림

  static const double renderTileSize = 32.0;
  static const double srcTileSize = 48.0;

  HDWorldMap(this.mapModel) : super([]);

  @override
  int get priority => -1; // Ensure map is below player

  @override
  Future<void> onLoad() async {
    try {
      final imageA5 = await Flame.images.load('Lore_A5.png');
      int colsA5 = (imageA5.width / srcTileSize).floor();
      int rowsA5 = (imageA5.height / srcTileSize).floor();

      _tileSheetA5 = SpriteSheet.fromColumnsAndRows(
        image: imageA5,
        columns: colsA5,
        rows: rowsA5,
      );

      final imageB = await Flame.images.load('Lore_B.png');
      int colsB = (imageB.width / srcTileSize).floor();
      int rowsB = (imageB.height / srcTileSize).floor();

      _tileSheetB = SpriteSheet.fromColumnsAndRows(
        image: imageB,
        columns: colsB,
        rows: rowsB,
      );
      final strip = await Flame.images.load('lore_sprite_transparent.png');
      _stripSheet = SpriteSheet.fromColumnsAndRows(
        image: strip,
        columns: strip.width ~/ 24,
        rows: 1,
      );
      final imageC = await Flame.images.load('Lore_C.png');
      _actorSheet = SpriteSheet.fromColumnsAndRows(
        image: imageC,
        columns: (imageC.width / srcTileSize).floor(),
        rows: (imageC.height / srcTileSize).floor(),
      );
    } catch (e) {
      print("Error loading tile sheets: $e");
    }
    return super.onLoad();
  }

  Sprite? _getA5Sprite(int id) {
    if (_tileSheetA5 == null) return null;
    int cols = _tileSheetA5!.columns;
    if (cols <= 0) return null;
    int row = id ~/ cols;
    int col = id % cols;
    if (row >= _tileSheetA5!.rows) return null;
    return _tileSheetA5!.getSprite(row, col);
  }

  Sprite? _getBSprite(int id) {
    if (_tileSheetB == null) return null;
    if (id <= 0) return null;

    // RPG Maker MZ direct global ID mapping:
    // Left half of the image (cols 0~7, rows 0~15) has 128 items
    // Right half of the image (cols 8~15, rows 0~15) has the next 128 items
    int row;
    int col;
    if (id < 128) {
      row = id ~/ 8;
      col = id % 8;
    } else {
      int localId = id - 128;
      row = localId ~/ 8;
      col = 8 + (localId % 8);
    }

    if (row >= _tileSheetB!.rows || col >= _tileSheetB!.columns) return null;
    return _tileSheetB!.getSprite(row, col);
  }

  @override
  void render(Canvas canvas) {
    if (_tileSheetA5 == null || _tileSheetB == null) return;

    // Viewport Culling for performance
    final camera = gameRef.camera;
    final viewport = camera.viewport.size;

    Vector2 cameraPos = camera.position;
    if (cameraPos.x == 0 &&
        cameraPos.y == 0 &&
        (mapModel.width > 10 || mapModel.height > 10)) {
      cameraPos = Vector2(
        HDGameMain().party.x * renderTileSize,
        HDGameMain().party.y * renderTileSize,
      );
    }

    int startX = ((cameraPos.x - viewport.x / 2) / renderTileSize).floor();
    int startY = ((cameraPos.y - viewport.y / 2) / renderTileSize).floor();
    int endX = ((cameraPos.x + viewport.x / 2) / renderTileSize).ceil();
    int endY = ((cameraPos.y + viewport.y / 2) / renderTileSize).ceil();

    startX = startX.clamp(0, mapModel.width - 1);
    startY = startY.clamp(0, mapModel.height - 1);
    endX = endX.clamp(0, mapModel.width - 1);
    endY = endY.clamp(0, mapModel.height - 1);

    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        final unit = mapModel.getUnit(x, y);
        if (unit == null) continue;

        // Base tile
        int logicalTileId = unit.ixTile;
        int tileId = mapModel.tileOverrides[logicalTileId] ?? logicalTileId;

        final a5Sprite = _getA5Sprite(tileId);
        if (a5Sprite != null) {
          a5Sprite.paint.filterQuality = FilterQuality.low;
          a5Sprite.render(
            canvas,
            position: Vector2(x * renderTileSize, y * renderTileSize),
            size: Vector2(renderTileSize, renderTileSize),
          );
        }

        // Bottom to top: L2 floor decor (z1) → L3 object (z2) →
        // L4 top object (z3), then the night shadow. BP-36 R-36-57.
        _renderBTile(canvas, x, y, unit.ixDecor);
        _renderBTile(canvas, x, y, unit.ixObj0);
        _renderBTile(canvas, x, y, unit.ixObj1);
      }
    }

    // 장면 속 인물 — 칸 위에 겹쳐, 어둠보다 먼저 그린다.
    _renderActors(canvas);

    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        final unit = mapModel.getUnit(x, y);
        if (unit == null) continue;
        _renderShadow(canvas, x, y, unit.shadow);
      }
    }
  }

  void _renderActors(Canvas canvas) {
    final actors = HDGameSession().actors.values;
    if (actors.isEmpty) return;
    final now = HDActorClock.nowMs;
    for (final a in actors) {
      final (ax, ay) = a.positionAt(now);
      final sprite = a.strip >= 0
          ? _stripSprite(a.strip)
          : a.cutout >= 0
          ? _actorSprite(a.cutout)
          : (a.sprite > 0 ? _getBSprite(a.sprite) : _getA5Sprite(a.a5));
      if (sprite == null) continue;
      sprite.paint.filterQuality = FilterQuality.low;
      sprite.render(
        canvas,
        position: Vector2(ax * renderTileSize, ay * renderTileSize),
        size: Vector2(renderTileSize, renderTileSize),
      );
    }
  }

  Sprite? _stripSprite(int id) {
    final sheet = _stripSheet;
    if (sheet == null || id >= sheet.columns) return null;
    return sheet.getSprite(0, id);
  }

  Sprite? _actorSprite(int id) {
    final sheet = _actorSheet;
    if (sheet == null || sheet.columns <= 0) return null;
    final row = id ~/ sheet.columns, col = id % sheet.columns;
    if (row >= sheet.rows) return null;
    return sheet.getSprite(row, col);
  }

  void _renderBTile(Canvas canvas, int x, int y, int id) {
    if (id <= 0) return;
    final sprite = _getBSprite(id);
    if (sprite == null) return;
    sprite.paint.filterQuality = FilterQuality.low;
    sprite.render(
      canvas,
      position: Vector2(x * renderTileSize, y * renderTileSize),
      size: Vector2(renderTileSize, renderTileSize),
    );
  }

  void _renderShadow(Canvas canvas, int x, int y, int shadowVal) {
    if (shadowVal <= 0) return;

    final HDParty party = HDGameMain().party;
    final session = HDGameSession();
    final mapType = session.gameOption.mapType;
    final darkZone = session.mapRuntime.darkZone;

    int sightRange = HDSightCalculator.sightRangeFor(
      world: party.world,
      mapType: mapType,
      darkZone: darkZone,
    );

    // Full daylight: no darkness to draw.
    if (sightRange >= HDSightCalculator.fullSight) return;

    int pX = party.x;
    int pY = party.y;

    final game = HDFlutterUiHost().bonfireGame;
    if (game != null && game.player != null) {
      double valX = game.player!.position.x / renderTileSize;
      double valY = game.player!.position.y / renderTileSize;

      // When moving (+), use ceil to see ahead. When moving (-), use floor —
      // gives instant feedback for direction of movement.
      pX = (valX > party.x) ? valX.ceil() : valX.floor();
      pY = (valY > party.y) ? valY.ceil() : valY.floor();
    }

    bool inMoonlight = HDSightCalculator.isInMoonlight(
      world: party.world,
      mapType: mapType,
      darkZone: darkZone,
    );
    // cm2 `Map::SetLightArea` 로 밝혀 둔 칸은 시야 반경과 무관하게
    // 완전히 밝다 — 원작 `map::setLight` 와 같다.
    int lightBit = HDGameSession().lightAreas.isLit(x, y)
        ? 15
        : HDSightCalculator.lightBitFor(
            mapX: x,
            mapY: y,
            playerX: pX,
            playerY: pY,
            sightRange: sightRange,
          );
    int ix = ((shadowVal ^ 15) | lightBit) ^ 15;

    bool isThisTileBackOut = !inMoonlight && (ix == 15);

    if (ix > 0) {
      int shadowSpriteId = 240 + ix;
      final shadowSprite = _getBSprite(shadowSpriteId);
      if (shadowSprite != null) {
        shadowSprite.paint.filterQuality = FilterQuality.low;
        shadowSprite.render(
          canvas,
          position: Vector2(x * renderTileSize, y * renderTileSize),
          size: Vector2(renderTileSize, renderTileSize),
        );

        if (isThisTileBackOut) {
          shadowSprite.render(
            canvas,
            position: Vector2(x * renderTileSize, y * renderTileSize),
            size: Vector2(renderTileSize, renderTileSize),
          );
        }
      }
    }
  }
}
