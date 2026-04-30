import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import '../../domain/map/map_model.dart';
import '../../domain/party/party.dart';
import '../host/flutter_ui_host.dart';
import 'battle_overlay.dart';
import 'player_sprite.dart';
import 'world_map_renderer.dart';

class HDMapViewport extends StatefulWidget {
  final MapModel mapModel;
  final HDParty party;

  const HDMapViewport({super.key, required this.mapModel, required this.party});

  @override
  State<HDMapViewport> createState() => _HDMapViewportState();
}

class _HDMapViewportState extends State<HDMapViewport> {
  late HDWorldMap _worldMap;
  late HDPlayerSprite _player;

  @override
  void initState() {
    super.initState();
    _worldMap = HDWorldMap(widget.mapModel);
    _player = HDPlayerSprite(widget.party);
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
            HDFlutterUiHost().attachBonfireGame(game);
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
