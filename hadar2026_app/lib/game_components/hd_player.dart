import 'dart:async';
import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hd_party.dart';
import '../hd_config.dart';
import 'hd_game_main.dart';
import 'hd_tile_properties.dart';

class HDPlayer extends SimplePlayer with BlockMovementCollision {
  static const double tileSize = HDConfig.tileSize;
  final HDParty party;

  Vector2? _targetPosition;
  JoystickDirectionalEvent? _currentInput;
  bool _isMoving = false;
  double _moveAccumulator = 0.0;
  int? _lastInteractedX;
  int? _lastInteractedY;

  // For script engine to await movement completion
  Completer<void>? _scriptMoveCompleter;
  int _scriptDx = 0;
  int _scriptDy = 0;
  String? _lastMoveLog;

  HDPlayer(this.party)
    : super(
        position: Vector2(party.x * tileSize, party.y * tileSize),
        size: Vector2(32, 32),
        animation: SimpleDirectionAnimation(
          idleRight: _loadAnim(2),
          runRight: _loadAnim(2),
          idleLeft: _loadAnim(3),
          runLeft: _loadAnim(3),
          idleUp: _loadAnim(1),
          runUp: _loadAnim(1),
          idleDown: _loadAnim(0),
          runDown: _loadAnim(0),
          enabledFlipX: false,
        ),
        speed: HDConfig.playerMoveSpeed,
      );

  static Future<SpriteAnimation> _loadAnim(int index) async {
    // Index 0: Down, 1: Up, 2: Right, 3: Left
    try {
      final image = await Flame.images.load('lore_sprite_transparent.png');
      final sprite = Sprite(
        image,
        srcPosition: Vector2(index * 24.0, 0),
        srcSize: Vector2(24, 24),
      );
      sprite.paint.filterQuality = FilterQuality.none;
      return SpriteAnimation.spriteList([sprite], stepTime: 1);
    } catch (e) {
      print("Error loading sprite: $e");
      return SpriteAnimation.spriteList([], stepTime: 1);
    }
  }

  @override
  void onJoystickChangeDirectional(JoystickDirectionalEvent event) {
    _currentInput = event;
  }

  @override
  Future<void> onLoad() async {
    // Force initial position to match party model (safety for save/load)
    position = Vector2(party.x * 32.0, party.y * 32.0);

    // Sync initial direction
    // 0: Down, 1: Up, 2: Right, 3: Left
    switch (party.faced) {
      case 0:
        lastDirection = Direction.down;
        break;
      case 1:
        lastDirection = Direction.up;
        break;
      case 2:
        lastDirection = Direction.right;
        break;
      case 3:
        lastDirection = Direction.left;
        break;
    }
    await super.onLoad();
    idle();
  }

  bool _actionPressed = false;

  bool _isProcessingMove = false;

  @override
  void update(double dt) {
    super.update(dt);

    // Synchronize visual position BEFORE camera update if the script engine
    // (e.g. WarpPrevPos, LoadScript) teleported the player externally.
    if (!_isMoving) {
      Vector2 truePos = Vector2(party.x * tileSize, party.y * tileSize);
      if (position.distanceTo(truePos) > 0.5) {
        position = truePos;
      }
    }

    // Force camera to follow player perfectly every frame (Always Center)
    // gameRef.camera.position is the center point of the camera view.
    gameRef.camera.stop();
    gameRef.camera.position = position + Vector2(16, 16);

    // Check for interaction keys (Enter, E)
    final mode = HDGameMain().currentInputMode;
    bool isActionKeyPressed =
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.enter,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyE);

    if (mode == HDInputMode.map && isActionKeyPressed) {
      if (!_actionPressed) {
        _actionPressed = true;
        _interactWithFacingTile();
      }
    } else {
      _actionPressed = false;
    }

    if (_isMoving && _targetPosition != null) {
      if (!_isProcessingMove) {
        _isProcessingMove = true;
        _moveTowardsTarget(dt).then((_) => _isProcessingMove = false);
      }
    } else {
      _checkInput();
    }
  }

  Future<void> _moveTowardsTarget(double dt) async {
    if (_targetPosition == null) return;

    double potentialStep = speed * dt;
    _moveAccumulator += potentialStep;

    while (_moveAccumulator >= 1.0) {
      if (position.distanceTo(_targetPosition!) < 0.5) {
        // Reached
        position = _targetPosition!;

        // Sync Party Model
        party.move(
          (position.x / tileSize).round() - party.x,
          (position.y / tileSize).round() - party.y,
        );

        // Trigger tile events (Event, Enter)
        // Fire-and-forget so we don't deadlock the next movement frame inside update(dt)
        HDGameMain().checkTileEvent(party.x, party.y, isInteraction: false);

        _isMoving = false;
        _targetPosition = null;
        _moveAccumulator = 0.0;
        idle();

        if (_scriptMoveCompleter != null) {
          _scriptMoveCompleter?.complete();
          _scriptMoveCompleter = null;
        }

        _checkInput();
        return;
      }

      Vector2 moveDir = (_targetPosition! - position).normalized();
      // Snap to axis
      if (moveDir.x.abs() > moveDir.y.abs()) {
        moveDir = Vector2(moveDir.x.sign, 0);
      } else {
        moveDir = Vector2(0, moveDir.y.sign);
      }

      position += moveDir;
      _moveAccumulator -= 1.0;
    }
  }

  Future<void> _checkInput() async {
    final mode = HDGameMain().currentInputMode;
    if ((mode != HDInputMode.map || HDGameMain().isScriptRunning) &&
        _scriptMoveCompleter == null) {
      return;
    }

    int dx = 0;
    int dy = 0;

    if (_scriptMoveCompleter != null) {
      // Script-driven movement overrides joystick
      dx = _scriptDx;
      dy = _scriptDy;
    } else {
      if (_currentInput == null ||
          _currentInput!.directional == JoystickMoveDirectional.IDLE) {
        _lastInteractedX = null;
        _lastInteractedY = null;
        return;
      }

      // Determine direction from input
      if (_currentInput!.directional == JoystickMoveDirectional.MOVE_LEFT) {
        dx = -1;
      } else if (_currentInput!.directional ==
          JoystickMoveDirectional.MOVE_RIGHT) {
        dx = 1;
      } else if (_currentInput!.directional ==
          JoystickMoveDirectional.MOVE_UP) {
        dy = -1;
      } else if (_currentInput!.directional ==
          JoystickMoveDirectional.MOVE_DOWN) {
        dy = 1;
      } else {
        return;
      }
    }

    // 1. Update facing immediately
    party.setFace(dx, dy);

    // Force Bonfire visual update
    if (dx > 0) lastDirection = Direction.right;
    if (dx < 0) lastDirection = Direction.left;
    if (dy > 0) lastDirection = Direction.down;
    if (dy < 0) lastDirection = Direction.up;

    // 2. Calculate next grid position
    int nextX = party.x + dx;
    int nextY = party.y + dy;

    // 3. Check Map Collision
    bool isPassable = true;
    final map = HDGameMain().map;
    int? tileIdAtNext;
    if (map != null) {
      if (nextX < 0 || nextX >= map.width || nextY < 0 || nextY >= map.height) {
        isPassable = false;
      } else {
        tileIdAtNext = map.getTile(nextX, nextY);
        if (!HDTileProperties.isPassable(
          tileIdAtNext,
          HDGameMain().gameOption.mapType,
        )) {
          isPassable = false;
        }
      }
    }

    // Log movement/interaction attempt
    if (map != null && tileIdAtNext != null) {
      final action = HDTileProperties.getAction(
        tileIdAtNext,
        HDGameMain().gameOption.mapType,
      );

      String flags = "";
      if (action == HDTileProperties.ACTION_TALK) flags += "Tak";
      if (action == HDTileProperties.ACTION_SIGN) flags += "Sig";
      if (action == HDTileProperties.ACTION_EVENT) flags += "Evt";
      if (action == HDTileProperties.ACTION_ENTER) flags += "Ent";
      if (action == HDTileProperties.ACTION_WATER) flags += "Wtr";
      if (action == HDTileProperties.ACTION_SWAMP) flags += "Swm";
      if (action == HDTileProperties.ACTION_LAVA) flags += "Lav";

      final currentLog = "MOVE: ($nextX, $nextY) - id($tileIdAtNext) [$flags]";
      if (flags.isNotEmpty && currentLog != _lastMoveLog) {
        print(currentLog);
        _lastMoveLog = currentLog;
      }
    }

    if (isPassable) {
      _lastInteractedX = null;
      _lastInteractedY = null;
      Vector2 nextPos = Vector2(nextX * tileSize, nextY * tileSize);
      _targetPosition = nextPos;
      _isMoving = true;

      // Play running animation for direction
      switch (lastDirection) {
        case Direction.left:
          animation?.play(SimpleAnimationEnum.runLeft);
          break;
        case Direction.right:
          animation?.play(SimpleAnimationEnum.runRight);
          break;
        case Direction.up:
          animation?.play(SimpleAnimationEnum.runUp);
          break;
        case Direction.down:
          animation?.play(SimpleAnimationEnum.runDown);
          break;
        default:
          break;
      }
    } else {
      // Ensure we show the new facing direction (Idle) immediately before triggering events!
      switch (lastDirection) {
        case Direction.left:
          animation?.play(SimpleAnimationEnum.idleLeft);
          break;
        case Direction.right:
          animation?.play(SimpleAnimationEnum.idleRight);
          break;
        case Direction.up:
          animation?.play(SimpleAnimationEnum.idleUp);
          break;
        case Direction.down:
          animation?.play(SimpleAnimationEnum.idleDown);
          break;
        default:
          idle();
      }

      // If blocked, check if it's an interactive tile (Talk, Sign, Enter)
      if (map != null) {
        final tileId = map.getTile(nextX, nextY);
        final action = HDTileProperties.getAction(
          tileId,
          HDGameMain().gameOption.mapType,
        );
        if (action == HDTileProperties.ACTION_TALK ||
            action == HDTileProperties.ACTION_SIGN ||
            action == HDTileProperties.ACTION_ENTER) {
          // Only trigger if we haven't interacted with THIS tile in THIS press session
          if (_lastInteractedX != nextX || _lastInteractedY != nextY) {
            await HDGameMain().checkTileEvent(
              nextX,
              nextY,
              isInteraction: true,
            );
            _lastInteractedX = nextX;
            _lastInteractedY = nextY;
          }
        }
      }

      // If this was a script move, resolve it immediately since we can't move
      if (_scriptMoveCompleter != null) {
        _scriptMoveCompleter?.complete();
        _scriptMoveCompleter = null;
      }
    }
  }

  void _interactWithFacingTile() {
    int dx = 0;
    int dy = 0;
    switch (lastDirection) {
      case Direction.left:
        dx = -1;
        break;
      case Direction.right:
        dx = 1;
        break;
      case Direction.up:
        dy = -1;
        break;
      case Direction.down:
        dy = 1;
        break;
      default:
        return;
    }

    int targetX = party.x + dx;
    int targetY = party.y + dy;

    // Trigger manual interaction
    HDGameMain().checkTileEvent(targetX, targetY, isInteraction: true);
  }

  /// Forces the player to move via script, awaiting the completion of the physical movement
  Future<void> forceMove(int dx, int dy) async {
    // Only allow one script move at a time
    if (_scriptMoveCompleter != null) {
      await _scriptMoveCompleter!.future;
    }

    _scriptDx = dx;
    _scriptDy = dy;
    _scriptMoveCompleter = Completer<void>();

    // Trigger the movement logic
    _checkInput();

    return _scriptMoveCompleter!.future;
  }
}
