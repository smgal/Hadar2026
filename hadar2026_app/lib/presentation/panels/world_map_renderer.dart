import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';

import '../../domain/lighting/sight_calculator.dart';
import '../../domain/map/map_model.dart';
import '../../domain/party/party.dart';
import '../../hd_game_main.dart';
import '../../application/scripting/native_script_runner.dart';
import '../host/flutter_ui_host.dart';

/// Renders the tiled map and the per-tile shadow/visibility overlay.
/// Game rules (sight radius, moonlight, light bit) come from
/// [HDSightCalculator]; this class only loads sprite sheets and paints.
class HDWorldMap extends WorldMap {
  final MapModel mapModel;

  SpriteSheet? _tileSheetA5;
  SpriteSheet? _tileSheetB;

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

        if (unit.ixObj0 > 0) {
          final lowerSprite = _getBSprite(unit.ixObj0);
          if (lowerSprite != null) {
            lowerSprite.paint.filterQuality = FilterQuality.low;
            lowerSprite.render(
              canvas,
              position: Vector2(x * renderTileSize, y * renderTileSize),
              size: Vector2(renderTileSize, renderTileSize),
            );
          }
        }

        if (unit.ixObj1 > 0) {
          final upperSprite = _getBSprite(unit.ixObj1);
          if (upperSprite != null) {
            upperSprite.paint.filterQuality = FilterQuality.low;
            upperSprite.render(
              canvas,
              position: Vector2(x * renderTileSize, y * renderTileSize),
              size: Vector2(renderTileSize, renderTileSize),
            );
          }
        }

        _renderShadow(canvas, x, y, unit.shadow);
      }
    }
  }

  void _renderShadow(Canvas canvas, int x, int y, int shadowVal) {
    if (shadowVal <= 0) return;

    final HDParty party = HDGameMain().party;
    final String mapName =
        HDNativeScriptRunner().currentMapScript?.mapName ?? "";
    int sightRange = HDSightCalculator.sightRangeFor(
      party: party,
      mapName: mapName,
    );
    if (sightRange >= 5) return;

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
      party: party,
      mapName: mapName,
    );
    int lightBit = HDSightCalculator.lightBitFor(
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
