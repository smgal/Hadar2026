import 'package:bonfire/bonfire.dart';

/// Holds virtual D-pad / action button state set by the on-screen control
/// panel and read by the player sprite during update.
///
/// 맵에서 짧게 누른 키도 여기에 남긴다. 주인공 그림은 매 화면마다 「지금 눌려
/// 있는가」만 보므로, 다음 화면이 오기 전에 손을 뗀 키(0.1초 안쪽의 톡 누름)는
/// 걷기·말 걸기가 되지 않았다. 키가 내려간 순간 [HDInputDispatcher] 가 적어 두고,
/// 주인공 그림이 다음 화면에서 한 번 쓰고 지운다.
class HDVirtualInputState {
  static final HDVirtualInputState _instance = HDVirtualInputState._internal();
  factory HDVirtualInputState() => _instance;
  HDVirtualInputState._internal();

  bool actionPressed = false;
  JoystickMoveDirectional direction = JoystickMoveDirectional.IDLE;

  bool _actionTapped = false;
  JoystickMoveDirectional? _stepTapped;

  /// 맵에서 Enter · E 가 내려갔다.
  void tapAction() => _actionTapped = true;

  /// 맵에서 방향 키가 내려갔다.
  void tapStep(JoystickMoveDirectional d) => _stepTapped = d;

  /// 적어 둔 말 걸기를 한 번 꺼내고 지운다.
  bool takeActionTap() {
    final t = _actionTapped;
    _actionTapped = false;
    return t;
  }

  /// 적어 둔 한 걸음을 한 번 꺼내고 지운다.
  JoystickMoveDirectional? takeStepTap() {
    final t = _stepTapped;
    _stepTapped = null;
    return t;
  }

  /// 맵을 벗어나면(대화 · 메뉴 · 창) 적어 둔 것을 버린다 — 닫은 뒤에 저절로 걷지 않게.
  void clearTaps() {
    _actionTapped = false;
    _stepTapped = null;
  }
}
