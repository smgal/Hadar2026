import 'package:flutter/foundation.dart';

/// 진행 상태 — 플래그와 변수, 그리고 지금 서 있는 맵이 무엇인지.
///
/// ## hadar2026_app 과 다른 점: 번호가 아니라 이름이다
///
/// 하다르 쪽은 `Flag::Set(51)` 처럼 번호를 쓰고, 이름은 `flag4ep1.cm2` 가
/// 붙여 준다. 그 방식은 include 를 빠뜨린 스크립트가 같은 번호를 다른 뜻으로
/// 쓰는 사고를 냈다(10 · 31 · 50). 로어 쪽 기획서는 처음부터 상태를
/// `ORC_KING_DEAD` · `MAIN_STAGE` 같은 **이름**으로 적어 두었으므로(부록 B)
/// 그 이름을 그대로 열쇠로 쓴다. 번호가 없으니 충돌도 없고, 세이브 파일을
/// 열면 무엇이 켜져 있는지 읽힌다.
class HDGameOption extends ChangeNotifier {
  HDGameOption();

  /// 켜진 플래그. **없는 이름은 꺼진 것이다** — 미리 선언할 필요가 없다.
  Map<String, bool> flags = {};

  /// 변수. 없는 이름은 0.
  Map<String, int> variables = {};

  int mapType = 0; // 0: TOWN, 1: KEEP, 2: GROUND, 3: DEN
  String scriptFile = "";

  /// `E3_Lore` — 세이브에서 돌아올 때 맵의 딸린 정보(유형·기본 타일)를
  /// 다시 찾는 열쇠.
  String mapName = "";

  bool flag(String name) => flags[name] ?? false;
  int variable(String name) => variables[name] ?? 0;

  void refresh() {
    notifyListeners();
  }

  void reset() {
    flags = {};
    variables = {};
    mapType = 0;
    scriptFile = "";
    mapName = "";
  }

  Map<String, dynamic> toJson() {
    return {
      // 꺼진 것은 적지 않는다 — 「한 번 켜지면 꺼지지 않는다」가 원칙이라
      // (부록 B) 꺼진 이름은 대개 `Flag::Reset` 의 흔적일 뿐이다.
      'flags': [
        for (final e in flags.entries)
          if (e.value) e.key,
      ],
      'variables': variables,
      'mapType': mapType,
      'scriptFile': scriptFile,
      'mapName': mapName,
    };
  }

  factory HDGameOption.fromJson(Map<String, dynamic> json) {
    final option = HDGameOption();
    final rawFlags = json['flags'];
    if (rawFlags is List) {
      option.flags = {for (final name in rawFlags.whereType<String>()) name: true};
    }
    final rawVars = json['variables'];
    if (rawVars is Map) {
      option.variables = {
        for (final e in rawVars.entries)
          if (e.value is int) e.key.toString(): e.value as int,
      };
    }
    option.mapType = json['mapType'] ?? 0;
    option.scriptFile = json['scriptFile'] ?? "";
    option.mapName = json['mapName'] ?? "";
    return option;
  }
}
