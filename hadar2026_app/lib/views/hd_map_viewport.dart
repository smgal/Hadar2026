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
                directionalKeys: [KeyboardDirectionalKeys.arrows()],
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
  SpriteSheet? _tileSheet;
  static const double renderTileSize = 32.0;

  HDWorldMap(this.mapModel) : super([]);

  @override
  int get priority => -1; // Ensure map is below player

  @override
  Future<void> onLoad() async {
    try {
      final image = await Flame.images.load('lore_tile.bmp');
      int columns = (image.width / 24).floor();
      int rows = (image.height / 24).floor();

      _tileSheet = SpriteSheet.fromColumnsAndRows(
        image: image,
        columns: columns,
        rows: rows,
      );
    } catch (e) {
      print("Error loading tile sheet: $e");
    }
    // DO NOT add tiles as components anymore. We will render them manually for performance.
    return super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    if (_tileSheet == null) return;

    // Viewport Culling for performance
    final camera = gameRef.camera;
    final viewport = camera.viewport.size;

    // If camera is not yet centered on player (e.g. first frame),
    // Use player position as a fallback for culling to avoid black screen.
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
        int logicalTileId = mapModel.getTile(x, y);
        int tileId = mapModel.tileOverrides[logicalTileId] ?? logicalTileId;

        int mapType = HDGameMain().gameOption.mapType;
        if (tileId >= 0 &&
            tileId < _tileSheet!.columns &&
            mapType < _tileSheet!.rows) {
          final sprite = _tileSheet!.getSprite(mapType, tileId);
          // nearest neighbor look
          sprite.paint.filterQuality = FilterQuality.low;
          sprite.render(
            canvas,
            position: Vector2(x * renderTileSize, y * renderTileSize),
            size: Vector2(renderTileSize, renderTileSize),
          );
        }
      }
    }
  }
}
