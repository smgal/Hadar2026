# P0-08 세이브 로드가 네이티브 맵 스크립트를 붙이지 않는다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: P0-07
- **설계 근거**: [`GROUND_TRUTH` 부록 C-2 · §7](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-25 세이브 포맷](../../blueprint/25_world_state_and_save.md)

## 문제

`hadar2026_app/lib/application/save_manager.dart:84-87` 은 맵을 **직접** 갈아 끼운다:

```dart
if (data['map'] != null) {
  final loadedMap = MapModel.fromJson(data['map']);
  session.setNewMap(loadedMap);      // ← :86
}
```

그런데 네이티브 스크립트 스왑(`onUnload` → `mapScriptFactory` → `onPrepare`/`onLoad`)은
`game_session.dart:117-128`, 즉 **`loadMapFromFile` 안에만** 있다:

```dart
final native = HDNativeScriptRunner();
if (native.currentMapScript != null) {
  native.currentMapScript!.onUnload();
}
final factory = native.mapScriptFactory[bundle.mapName];
if (factory != null) {
  native.currentMapScript = factory();
  native.currentMapScript!.onPrepare();
  native.currentMapScript!.onLoad(bundle.mapName, 0, 0);
} else {
  native.currentMapScript = null;
}
```

`setNewMap`(`game_session.dart:54-58`)은 `map`·`mapVersion`·`notifyListeners` 만 건드린다.
**따라서 세이브 로드 경로는 스크립트 스왑 코드를 타지 않는다.**

결과로 로드 후 `currentMapScript` 는 **직전 맵의 것으로 남거나 null 이다.**
그리고 `currentMapCm2Path`(`game_session.dart:83`)도 갱신되지 않는다.

이것이 디스패처 티어 선택을 바꾼다 — `tile_event_dispatcher.dart:126`:

```dart
if (native.currentMapScript != null) {
  await _emitJsonDialog(map, x, y, host, action);
  await native.processMapEvent(action, x, y);   // ← 남의 맵 스크립트
  return;
}
```

즉 **부록 F-2([P0-05](P0-05-native-script-without-geometry.md))와 같은 "다른 맵 좌표로 평가되는 스크립트" 상태가 세이브 로드로도 만들어진다.**
`save_manager.dart:68` 은 `gameOption.scriptFile` 로 cm2 만 되살리므로 cm2 는 일부 복구되지만
네이티브는 전혀 복구되지 않는다.

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 4번: "세이브 로드 후 **네이티브 맵 스크립트가 올바른 맵에 붙는다**".
- [P0-07](P0-07-save-drops-map-events.md) 이 `mapName` 을 세이브 봉투에 넣는다. **그 필드가 이 이슈의 해법 재료**이므로 선행이다.
- [P0-05](P0-05-native-script-without-geometry.md) 가 부착 조건에 가드를 넣는다. 이 이슈는 그 가드를 **로드 경로에서도** 타게 만드는 일이다.

## 무엇을 할 것인가

핵심은 **부착 로직을 두 곳에 복사하지 않는 것**이다. `game_session.dart:110-128` 을 별도 메서드로 뽑아
로드 경로에서 재사용한다.

1. `game_session.dart:117-128` 의 블록을 그대로 `void swapNativeMapScript(String? mapName)` 로 추출한다
   (`mapName == null` 이면 팩토리 조회를 건너뛰고 `currentMapScript = null`).
2. `loadMapFromFile` 은 `swapNativeMapScript(mapChanged ? bundle.mapName : null)` 을 부른다
   ([P0-05](P0-05-native-script-without-geometry.md) 의 `mapChanged` 가드와 결합).
3. `save_manager.dart` 의 맵 복원부가 같은 메서드를 부른다:

```diff
    if (data['map'] != null) {
      final loadedMap = MapModel.fromJson(data['map']);
      session.setNewMap(loadedMap);
+     final name = data['mapName'] as String?;
+     session.currentMapName = name;
+     session.swapNativeMapScript(name);
    }
```

**`onLoad` 주의**: `onLoad(prevMap, fromX, fromY)` 는 시작 좌표를 세운다
(`town2_map_script.dart:13-23`, `town1_map_script.dart:20-25` 가 `game.party.x/y` 를 대입한다).
세이브 로드는 저장된 좌표를 복원해야 하므로 **`swapNativeMapScript` 호출을 좌표 복원(`save_manager.dart:91-94`)보다 앞에** 두어야 한다.
현재 코드가 이미 그 순서(`:84-87` → `:91-94`)이므로 순서를 유지하면 된다 — 주석으로 그 이유를 남긴다.

`currentMapCm2Path` 도 함께 복원한다. `MapInfos.json` 조회 없이 `mapName` 만으로 되살릴 수 있도록
`HDMapNavigation().loadByName(name)` 의 `cm2Path` 를 쓰거나(P0-07 이 이미 이 호출을 한다) 세이브에 직접 넣는다 — 전자를 권고.

## 완료 판정 기준

- [ ] `TOWN1`(네이티브 스크립트 등록 맵) 위에서 저장 → 다른 맵으로 이동 → 로드하면
      `HDNativeScriptRunner().currentMapScript` 의 `mapName` 이 **`'TOWN1'`** 이다
- [ ] 네이티브 스크립트가 없는 맵(`LORE_EP`)에서 저장→로드하면 `currentMapScript == null` 이다
      (직전 맵의 것이 남지 않는다)
- [ ] 로드 후 `HDGameSession().currentMapCm2Path` 가 그 맵의 것이다
- [ ] 로드 후 파티 좌표가 **저장된 좌표**다 (`onLoad` 가 좌표를 덮어쓰지 않는다)
- [ ] 부착 로직이 `game_session.dart` 한 곳에만 있다 (`grep -c "mapScriptFactory\[" lib/` 가 1)
- [ ] 테스트 추가: `hadar2026_app/test/application/save_native_attach_test.dart` —
      `map_navigation_test.dart` 의 페이크 바인딩 패턴으로 `swapNativeMapScript` 가
      ① 등록 이름이면 부착 ② null/미등록이면 해제 ③ 재호출 시 이전 스크립트의 `onUnload` 가 불림을 고정한다

## 하지 않을 것

- 세이브 봉투에 `mapName` 을 **추가하는 것 자체** — [P0-07](P0-07-save-drops-map-events.md) 소관 (이 이슈는 그 필드를 소비한다).
- 세이브 v2 승격 · 스키마 버전 올리기 — [P1-04](../deferred/P1-04-save-v2.md) 소관.
- `HDNativeScriptRunner.flags` 복원 — [P1-04](../deferred/P1-04-save-v2.md) 소관.
- `onLoad` 시그니처 변경(prevMap 을 실제 이전 맵으로 채우기 등). 현재 `loadMapFromFile` 도 `(mapName, 0, 0)` 을 넘긴다 — 별건.
