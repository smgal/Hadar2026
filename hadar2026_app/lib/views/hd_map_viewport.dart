import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import '../models/map_model.dart';
import '../models/hd_party.dart';
import '../game_components/hd_game_main.dart';
import '../game_components/hd_player.dart';
import 'hd_battle_overlay.dart';

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
      }
    }
  }
}
