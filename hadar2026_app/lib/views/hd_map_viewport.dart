import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import '../models/map_model.dart';
import '../models/hd_party.dart';
import '../game_components/hd_game_main.dart';
import '../game_components/hd_player.dart';
import 'hd_battle_overlay.dart';
import '../scripting/hd_native_script_runner.dart';

class HDMapViewport extends StatefulWidget {
  final MapModel mapModel;
  final HDParty party;

  const HDMapViewport({super.key, required this.mapModel, required this.party});

  @override
  State<HDMapViewport> createState() => _HDMapViewportState();
}

class _HDMapViewportState extends State<HDMapViewport> {
  late HDWorldMap _worldMap;
  late HDPlayer _player;

  @override
  void initState() {
    super.initState();
    _worldMap = HDWorldMap(widget.mapModel);
    _player = HDPlayer(widget.party);
  }

  @override
  void didUpdateWidget(HDMapViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the map object changed, we need a full refresh.
    // However, the ValueKey in main.dart should handle this by creating a new State.
    // If we are here, mapModel is likely the same, but tileOverrides or Party might have changed.
    // The internal Flame loop will pick up these changes automatically.
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BonfireWidget(
          map: _worldMap,
          player: _player,
          playerControllers: [
            Keyboard(
              config: KeyboardConfig(
                enableDiagonalInput: false,
                directionalKeys: [
                  KeyboardDirectionalKeys.arrows(),
                  KeyboardDirectionalKeys.wasd(),
                ],
              ),
            ),
          ],
          cameraConfig: CameraConfig(
            moveOnlyMapArea: false,
            zoom: 1.0,
            speed: 1000.0,
            angle: 0,
          ),
          autofocus: true,
          backgroundColor: Colors.black,
          onReady: (game) {
            HDGameMain().mapViewGameRef = game;
          },
        ),
        // Coordinates overlay (Top-left)
        Positioned(
          top: 4,
          left: 4,
          child: ListenableBuilder(
            listenable: widget.party,
            builder: (context, child) {
              return Text(
                "( ${widget.party.x}, ${widget.party.y})",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Time overlay (Top-right)
        Positioned(
          top: 4,
          right: 4,
          child: ListenableBuilder(
            listenable: widget.party,
            builder: (context, child) {
              final h = widget.party.hour.toString().padLeft(2, '0');
              final m = widget.party.min.toString().padLeft(2, '0');
              final s = widget.party.sec.toString().padLeft(2, '0');
              return Text(
                "$h:$m:$s",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const HDBattleOverlay(),
      ],
    );
  }
}

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

    // Calculate visible grid range
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

        // Lower Object Layer
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

        // Upper Object Layer
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

        // Shadow / Night Layer
        _renderShadow(canvas, x, y, unit.shadow);
      }
    }
  }

  void _renderShadow(Canvas canvas, int x, int y, int shadowVal) {
    if (shadowVal <= 0) return;

    int sightRange = _getSightRange();
    if (sightRange >= 5) return;

    // Grid-aligned light origin by default
    int pX = HDGameMain().party.x;
    int pY = HDGameMain().party.y;

    final game = HDGameMain().mapViewGameRef;
    if (game != null && game.player != null) {
      double valX = game.player!.position.x / renderTileSize;
      double valY = game.player!.position.y / renderTileSize;

      // When moving (+), use ceil to see ahead. When moving (-), use floor.
      // This provides instant feedback for the direction of movement.
      pX = (valX > HDGameMain().party.x) ? valX.ceil() : valX.floor();
      pY = (valY > HDGameMain().party.y) ? valY.ceil() : valY.floor();
    }

    bool inMoonlight = _isInMoonlight();
    int lightBit = _computeLightBit(x, y, pX, pY, sightRange);
    int ix = ((shadowVal ^ 15) | lightBit) ^ 15;

    bool isThisTileBackOut = !inMoonlight && (ix == 15);

    if (ix > 0) {
      int shadowSpriteId = 240 + ix;
      final shadowSprite = _getBSprite(shadowSpriteId);
      if (shadowSprite != null) {
        shadowSprite.paint.filterQuality = FilterQuality.low;

        // Draw shadow
        shadowSprite.render(
          canvas,
          position: Vector2(x * renderTileSize, y * renderTileSize),
          size: Vector2(renderTileSize, renderTileSize),
        );

        // Double draw for full darkness outside moonlight
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

  int _computeLightBit(
    int mapX,
    int mapY,
    int playerX,
    int playerY,
    int sightRange,
  ) {
    if (sightRange >= 5) return 15;

    const int mag = 2;
    int bit = 0;
    double sqrRadius = mag * sightRange + 0.3;
    sqrRadius *= sqrRadius;

    for (int sy = 0; sy < mag; sy++) {
      for (int sx = 0; sx < mag; sx++) {
        double fx = (mapX - playerX) * mag + sx - 0.5;
        double fy = (mapY - playerY) * mag + sy - 0.5;

        if ((fx * fx + fy * fy) <= sqrRadius) {
          int shift = sx + 2 * sy;
          bit |= (1 << shift);
        }
      }
    }
    return bit;
  }

  int _getSightRange() {
    final party = HDGameMain().party;
    int time = party.hour * 100 + party.min;

    int sightRange = 5;
    if (time < 600)
      sightRange = 1;
    else if (time < 620)
      sightRange = 2;
    else if (time < 640)
      sightRange = 3;
    else if (time < 700)
      sightRange = 4;
    else if (time < 1800)
      sightRange = 5;
    else if (time < 1820)
      sightRange = 4;
    else if (time < 1840)
      sightRange = 3;
    else if (time < 1900)
      sightRange = 2;
    else
      sightRange = 1;

    String mapName = HDNativeScriptRunner().currentMapScript?.mapName ?? "";
    bool isDen = mapName.toUpperCase().contains('DEN');
    if (isDen) {
      sightRange = 1;
    }

    bool inDark = isDen || !(party.hour >= 7 && party.hour < 17);

    if (inDark && party.magicTorch > 0) {
      if (party.magicTorch >= 1 && party.magicTorch <= 2) {
        sightRange = sightRange > 2 ? sightRange : 2;
      } else if (party.magicTorch >= 3 && party.magicTorch <= 4) {
        sightRange = sightRange > 3 ? sightRange : 3;
      } else {
        sightRange = sightRange > 3 ? sightRange : 3;
      }
    }

    return sightRange;
  }

  bool _isInMoonlight() {
    final party = HDGameMain().party;
    String mapName = HDNativeScriptRunner().currentMapScript?.mapName ?? "";
    bool isDen = mapName.toUpperCase().contains('DEN');
    bool isTown =
        mapName.toUpperCase().contains('TOWN') ||
        mapName.toUpperCase().contains('CASTLE');

    bool inMoonlight = (party.day ~/ 12) >= 10 && (party.day ~/ 12) <= 20;
    inMoonlight &= !isDen;
    inMoonlight |= isTown;

    if (isDen) return false;

    bool inDark = isDen || !(party.hour >= 7 && party.hour < 17);
    if (inDark && party.magicTorch > 4) {
      inMoonlight = true;
    }
    return inMoonlight;
  }
}
