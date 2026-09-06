/// 원작이 정해 둔 두 가지 **이름 색** 규칙.
///
/// 원작 화면은 320x240 이라 상태 이름을 적을 자리가 없었다. 그래서 상태를
/// **이름 색으로만** 알렸다(`hd_class_window_status.h:70` 주석).
/// 근거와 표는 `GROUND_TRUTH` 부록 V-4.
///
/// 문장과 같은 이유로 여기 있다 — **콘솔과 Flutter view 가 같은 색을 써야**
/// 한다. 그리는 방법은 읽는 쪽의 일이고, 여기에는 번호만 있다.
library;

import 'battle_lines.dart' show TextColor;

/// 적 이름의 색. `hd_class_window_battle.h:27-47` 을 그대로 옮겼다.
///
/// **비율이 아니라 절대 HP** 로 나눈다는 점이 눈에 띈다 — 최대 HP 를 보지
/// 않으므로, 덩치 큰 적은 반쯤 깎여도 초록이고 작은 적은 멀쩡해도 빨갛다.
/// 원작이 적의 최대 HP 를 화면에 보여주지 않았으니 앞뒤는 맞는다.
int enemyNameColor({
  required int hp,
  required int unconscious,
  required int dead,
}) {
  var index = TextColor.lightGreen;
  if (hp <= 0) {
    index = TextColor.darkGray;
  } else if (hp <= 20) {
    index = TextColor.lightRed;
  } else if (hp <= 50) {
    index = TextColor.red;
  } else if (hp <= 100) {
    index = TextColor.brown;
  } else if (hp <= 200) {
    index = TextColor.yellow;
  } else if (hp <= 300) {
    index = TextColor.green;
  }

  if (unconscious > 0) index = TextColor.darkGray;
  if (dead > 0) index = TextColor.black;
  return index;
}

/// 파티원 이름의 색. `hd_class_pc_player.cpp:238-256` `getConditionColor`.
int conditionColor({
  required int hp,
  required int poison,
  required int unconscious,
  required int dead,
}) {
  if (dead > 0) return TextColor.darkGray;
  if (unconscious > 0 || hp <= 0) return TextColor.lightGray;
  if (poison > 0) return TextColor.lightMagenta;
  return TextColor.white;
}
