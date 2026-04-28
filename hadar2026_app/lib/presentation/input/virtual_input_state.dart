import 'package:bonfire/bonfire.dart';

/// Holds virtual D-pad / action button state set by the on-screen control
/// panel and read by the player sprite during update.
class HDVirtualInputState {
  static final HDVirtualInputState _instance = HDVirtualInputState._internal();
  factory HDVirtualInputState() => _instance;
  HDVirtualInputState._internal();

  bool actionPressed = false;
  JoystickMoveDirectional direction = JoystickMoveDirectional.IDLE;
}
