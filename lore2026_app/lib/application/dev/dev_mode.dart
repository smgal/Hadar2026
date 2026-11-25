import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 개발자 모드 스위치.
///
/// 켜는 방법 넷 — 어느 것이든 켜진다:
///
/// * 제목 화면 맨 아래 「[개발] 개발자 모드 켜기」 ([switchOnTitle] 이 true 인 동안).
/// * 웹: 주소 뒤에 `?dev=1` (끄려면 `?dev=0`).
/// * 실행할 때 `--dart-define=LORE_DEV=true`.
/// * 시험: [enabled] 를 바로 바꾼다.
///
/// 제목 화면과 주소로 바꾼 값은 기억해서 다음 실행에도 그대로다.
///
/// 켜지면 제목 화면에 「[개발] 시나리오 중간에서 시작」이, 게임 중 주 메뉴에
/// 「[개발] 개발자 메뉴」가 생긴다 (`HDDevJump`).
class HDDevMode {
  static final HDDevMode _instance = HDDevMode._internal();
  factory HDDevMode() => _instance;
  HDDevMode._internal();

  static const String _prefsKey = 'lore2026_dev_mode';

  /// 제목 화면에 「개발자 모드 켜기 · 끄기」 줄을 보인다.
  /// **최종 배포 때 false 로 바꾼다** — 그러면 주소(`?dev=1`)와 실행 옵션으로만 켜진다.
  static const bool switchOnTitle = true;

  bool enabled = false;

  /// 걸어 다닐 때 무작위 조우를 일으키지 않는다 (개발자 메뉴에서 켜고 끈다).
  bool noEncounters = false;

  /// 앱이 뜰 때 한 번 부른다. [query] 는 주소의 `dev` 값(없으면 null).
  Future<void> init({String? query, bool define = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (query != null) {
        final on = !(query == '0' || query == 'off' || query == 'false');
        await prefs.setBool(_prefsKey, on);
      }
      enabled = define || (prefs.getBool(_prefsKey) ?? false);
    } catch (e) {
      // 저장소를 못 쓰는 곳(시험 등) — 주소와 실행 옵션만 본다.
      enabled = define || (query != null && query != '0' && query != 'off');
      debugPrint('[dev] preferences unavailable: $e');
    }
    if (enabled) debugPrint('[dev] developer mode is on');
  }

  /// 제목 화면에서 켜고 끈다. 다음 실행에도 기억한다.
  /// 끄면 「무작위 조우 끄기」도 풀린다 — 개발자 메뉴 없이 남으면 되돌릴 길이 없다.
  Future<void> setEnabled(bool on) async {
    enabled = on;
    if (!on) noEncounters = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, on);
    } catch (e) {
      debugPrint('[dev] could not remember the switch: $e');
    }
  }
}
