# P0-03 cm2 로드 실패가 엔진 상태를 누수시킨다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 A-2 · A-1 · §9](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-28 이관·cm2 공존](../../blueprint/28_migration_and_coexistence.md)

## 문제

`hadar2026_app/lib/application/scripting/script_engine_adapter.dart:92-112`:

```dart
Future<void> loadScript(String assetPath) async {
  String content;
  try {
    content = await HDHosts().assets.loadString(assetPath);
  } catch (e) {
    print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
    return;                        // ← :98  clearRuntimeState() 에 도달하지 못한다
  }

  print("ScriptEngine: Loading script content from $assetPath");

  _engine.clearRuntimeState();     // ← :103
  _tileMap.clear();
  _currentRow = 0;

  await _engine.loadFromString(content);
  HDGameSession().gameOption.scriptFile = assetPath;
```

로드 실패 시 **직전 맵의 스크립트·변수·컨텍스트가 그대로 남는다.**
`_tileMap`·`_currentRow` 도 초기화되지 않는다.

부록 A-1(모든 등록 맵에 없는 cm2 경로가 부여됨)과 합치면:
**맵을 옮겨도 이전 맵의 cm2 가 계속 실행되는 상태가 정상 동작처럼 보인다.**

그리고 이것이 디스패치 티어 선택을 왜곡한다 — `tile_event_dispatcher.dart:121,137`:

```dart
final cm2Path = HDGameSession().currentMapCm2Path;
...
if (cm2Path != null) {           // :137
  HDScriptEngine().setTargetPos(x, y);
  HDScriptEngine().setScriptMode(action.scriptMode);
  await HDScriptEngine().run();  // ← 이전 맵의 스크립트가 돌아간다
```

`currentMapCm2Path` 는 `game_session.dart:100` 에서 `bundle.cm2Path` 로 갱신되고 부록 A-1 때문에 사실상 항상 non-null 이므로,
**3티어 중 cm2 티어가 늘 선택되면서 그 안에서 남의 맵 스크립트가 실행된다.**

## 왜 지금 고쳐야 하는가

- [P0-02](P0-02-map-load-failure-silent.md) 의 "실패를 실패로 보고" 판정이 `cm2 로드 성공 여부` 를 알아야 하는 경우가 있는데,
  현재 `loadScript` 는 **반환값이 `void`** 라 성공/실패를 호출자에게 알릴 수단이 없다.
- BP-28 의 cm2 공존 상태 기계는 "어떤 맵의 cm2 가 지금 로드되어 있는가" 를 신뢰해야 한다.
- 이 누수는 [P0-01](P0-01-mapinfos-name-resolution.md) 을 고친 뒤에도 남는다 — cm2 파일은 여전히
  15개 이름 중 2개만 존재하므로 실패 경로가 계속 실행된다.

## 무엇을 할 것인가

`script_engine_adapter.dart:92-112` 만 수정한다.

```diff
- Future<void> loadScript(String assetPath) async {
+ /// Returns `true` when the script was loaded. On failure the engine's
+ /// runtime state is cleared (not left holding the previous map's script).
+ Future<bool> loadScript(String assetPath) async {
    String content;
    try {
      content = await HDHosts().assets.loadString(assetPath);
    } catch (e) {
      print("ScriptEngine: [ERROR] Failed to load $assetPath: $e");
-     return;
+     _engine.clearRuntimeState();
+     _tileMap.clear();
+     _currentRow = 0;
+     return false;
    }
    ...
+   return true;
  }
```

- 호출부 3곳의 시그니처 영향 확인: `game_session.dart:69`(startup), `:107`(per-map),
  `save_manager.dart:68`(세이브 로드), `script_engine_adapter.dart:46`(pendingNavigation 실패 폴백).
  전부 `await` 만 하고 값을 쓰지 않으므로 `bool` 반환은 **호환 변경**이다.
- `game_session.dart:107` 에서 반환값이 `false` 면 `currentMapCm2Path` 를 `null` 로 되돌린다.
  그래야 디스패처가 cm2 티어를 잘못 고르지 않는다.

## 완료 판정 기준

- [ ] 없는 cm2 경로로 `HDScriptEngine().loadScript(...)` 를 부른 뒤
      `HDScriptEngine().currentScript.isEmpty` 가 참이다 (직전 스크립트가 남지 않는다)
- [ ] 같은 상황에서 `loadScript` 가 `false` 를 반환한다
- [ ] cm2 로드가 실패한 맵에서는 `HDGameSession().currentMapCm2Path == null` 이다
      → 디스패처가 cm2 티어를 고르지 않는다
- [ ] `assets/startup.cm2` → `LORE_EP` 부팅 경로가 이전과 동일하게 동작한다
- [ ] 테스트 추가: `hadar2026_app/test/application/script_engine_state_test.dart` —
      `map_navigation_test.dart` 의 `_FakeAssets` 페이크 바인딩 패턴을 그대로 써서
      ① 성공 로드 후 `currentScript` 가 채워짐 ② 실패 로드 후 `currentScript` 가 **비워짐** ③ 반환값 `false` 를 고정한다
      (`tearDown(HDHosts().reset)` 포함)

## 하지 않을 것

- cm2 언어·파서 수정. `packages/cm2_script` 는 건드리지 않는다.
- 맵 전환 시 cm2 전역을 **보존**하는 기능. 상태 통합은 [P1-03](../deferred/P1-03-worldstate-unification.md) 소관이다.
- `currentMapCm2Path` 를 세이브에 넣기 — [P1-04](../deferred/P1-04-save-v2.md) 소관.
- 디스패처 티어 우선순위 자체의 변경. [P1-11](../deferred/P1-11-dispatcher-tier0.md) 소관.
