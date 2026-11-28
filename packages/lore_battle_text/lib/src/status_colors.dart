/// 원작이 정해 둔 두 가지 **이름 색** 규칙.
///
/// 원작 전투 화면에는 적 그림도 HP 막대도 없다. 적의 상태는 **이름의 색**
/// 으로만 읽는다(기획서 8.7, 부록 E.2).
///
/// 문장과 같은 이유로 여기 있다 — **콘솔과 Flutter view 가 같은 색을 써야**
/// 한다. 그리는 방법은 읽는 쪽의 일이고, 여기에는 번호만 있다.
library;

import 'battle_lines.dart' show TextColor;

/// 적 이름의 색 (8.7).
///
/// **비율이 아니라 절대 HP** 로 나눈다 — 최대 HP 를 보지 않으므로, 덩치 큰
/// 적은 반쯤 깎여도 초록이고 작은 적은 멀쩡해도 빨갛다.
///
/// | 남은 HP | 제2·3부 | 제1부 | 색 |
/// |---|---|---|---|
/// | 0 | 0 | 0 | 회색 |
/// | | 1~199 | 1~19 | 밝은 빨강 |
/// | | 200~499 | 20~49 | 어두운 빨강 |
/// | | 500~999 | 50~99 | 갈색 |
/// | | 1000~1999 | 100~199 | 노랑 |
/// | | 2000~3999 | 200~299 | 초록 |
/// | | 4000 이상 | 300 이상 | 밝은 초록 |
///
/// 의식불명은 회색, 죽음은 검정(검은 바탕이라 이름이 사라진다). 제1부는
/// 적의 HP 가 열 배 작아서 기준도 따로다(부록 E.11).
///
/// [alwaysBright] 는 분신과 분신 능력자다 — 얼마나 다쳤는지로 진짜를
/// 가려낼 수 없도록 **항상 밝은 초록**이다. `EnemyView.showsAsClone`
/// 을 그대로 넘기면 된다.
int enemyNameColor({
  required int hp,
  required int unconscious,
  required int dead,
  int episode = 3,
  bool alwaysBright = false,
}) {
  if (alwaysBright) return TextColor.lightGreen;
  if (dead > 0) return TextColor.black;
  if (unconscious > 0 || hp <= 0) return TextColor.darkGray;
  final bands = episode == 1
      ? const [20, 50, 100, 200, 300]
      : const [200, 500, 1000, 2000, 4000];
  if (hp < bands[0]) return TextColor.lightRed;
  if (hp < bands[1]) return TextColor.red;
  if (hp < bands[2]) return TextColor.brown;
  if (hp < bands[3]) return TextColor.yellow;
  if (hp < bands[4]) return TextColor.green;
  return TextColor.lightGreen;
}

/// 파티원 이름의 색 — 심각한 순으로 죽음 > 의식불명 > 중독 > 좋음 (7.7).
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
