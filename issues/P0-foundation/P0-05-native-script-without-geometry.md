# P0-05 지오메트리 없는 맵에 네이티브 스크립트가 부착된다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: P0-01
- **설계 근거**: [`GROUND_TRUTH` 부록 F-2 · D-1 · D-2](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-27 런타임 실행 경로](../../blueprint/27_runtime_engine.md)

## 문제

`hadar2026_app/lib/application/game_session.dart:97-128` — 맵 교체와 네이티브 스크립트 부착이 **서로 독립적으로** 일어난다:

```dart
if (bundle.json != null) {
  setNewMap(bundle.json!);       // ← :97-99  json 이 null 이면 맵은 그대로 남는다
}
currentMapCm2Path = bundle.cm2Path;
...
final native = HDNativeScriptRunner();
if (native.currentMapScript != null) {
  native.currentMapScript!.onUnload();      // :118-120
}
final factory = native.mapScriptFactory[bundle.mapName];
if (factory != null) {                      // ← :122  json 유무와 무관하게 실행
  native.currentMapScript = factory();
  native.currentMapScript!.onPrepare();
  native.currentMapScript!.onLoad(bundle.mapName, 0, 0);
} else {
  native.currentMapScript = null;
}
```

[P0-01](P0-01-mapinfos-name-resolution.md) 의 표와 합치면 구체적 사고가 된다:
`TOWN1` 로드 시 `Map004.json` 이 없어 `bundle.json == null` 이지만
`mapScriptFactory['TOWN1']`(`native_script_runner.dart:26`)은 존재하므로
**`Town1MapScript` 가 직전 맵 위에 부착된다.**

그 스크립트의 좌표 판정은 **다른 맵의 좌표**를 상대로 평가된다 —
`map_script.dart:50-56` 의 `isOn(x,y)` / `isArea(...)` 는 `tx`/`ty` 만 비교하고
어느 맵인지는 보지 않는다. 예: `town1_map_script.dart:62` 의 `isOn(50, 83)` 이
`Map002`(50×50) 위에서 평가되면 그 좌표는 애초에 존재하지 않는다.

네이티브 스크립트가 등록된 4개 이름 중 3개(`TOWN1`·`GROUND1`·`DEN1`)가
[P0-01](P0-01-mapinfos-name-resolution.md) 표에서 **깨짐** 행이다. 나머지 `TOWN2` 는 [P0-06](P0-06-town2-unreachable.md) 소관.

## 왜 지금 고쳐야 하는가

- [P0-01](P0-01-mapinfos-name-resolution.md) 이 이름 해석을 고치면 이 이슈의 **발현은 사라지지만 결함은 남는다.**
  맵 파일 하나가 나중에 지워지거나 이름이 바뀌면 같은 사고가 재발한다. 가드를 코드에 남기는 것이 이 이슈다.
- 부록 A-3([P0-04](P0-04-mapscript-flag-stub.md))와 **원인이 독립적**이다 — 플래그를 고쳐도 이 문제는 남는다.
- BP-27 의 티어 0 삽입은 "지금 부착된 스크립트가 지금 로드된 맵의 것" 이라는 불변식을 요구한다.

## 무엇을 할 것인가

`game_session.dart:110-128` 한 블록만 손댄다. 부착 조건에 **맵 교체 성공**을 결합한다.

```diff
+ // A native script may only attach to the map it belongs to. Without
+ // this, a failed JSON load leaves the previous map loaded while the
+ // new map's script binds to it (부록 F-2) and evaluates isOn/isArea
+ // against foreign coordinates.
  final native = HDNativeScriptRunner();
  if (native.currentMapScript != null) {
    native.currentMapScript!.onUnload();
  }
- final factory = native.mapScriptFactory[bundle.mapName];
- if (factory != null) {
+ final factory = mapChanged ? native.mapScriptFactory[bundle.mapName] : null;
+ if (factory != null) {
    native.currentMapScript = factory();
```

`mapChanged` 는 `:97` 의 분기에서 세운다:

```diff
+ final bool mapChanged = bundle.json != null;
- if (bundle.json != null) {
+ if (mapChanged) {
    setNewMap(bundle.json!);
  }
```

추가로:
- `mapChanged == false` 이면서 `factory != null` 인 경우 **로그를 남긴다** — 침묵 실패를 만들지 않는다.
  이 조합은 곧 "지오메트리 없이 스크립트만 있는 맵" 이라는 데이터 오류의 신호다.
- `mapChanged == false` 이면 `native.currentMapScript = null` 로 확실히 떨어뜨린다
  (이전 맵의 스크립트를 계속 붙여 두는 것도 잘못된 상태다).

**대안(채택하지 않음)**: `HDMapScript` 에 `mapName` 검사를 넣어 런타임에 매 호출 확인하는 안.
`mapName` getter 는 이미 있으므로(`map_script.dart:7`) 가능하지만, 부착 시점에 막는 것이 더 이르고 싸다.
다만 방어 수단으로 `HDNativeScriptRunner.processMapEvent`(`:68-70`) 에
`script.mapName` 과 현재 맵 이름을 비교하는 assert 를 넣는 것은 [P1-11](../deferred/P1-11-dispatcher-tier0.md) 에서 고려한다.

## 완료 판정 기준

- [ ] `bundle.json == null` 인 맵 이름으로 `loadMapFromFile` 을 부른 뒤
      `HDNativeScriptRunner().currentMapScript == null` 이다
- [ ] 정상 맵(`LORE_EP` → `Map002.json`)에서는 기존과 동일하게 스크립트가 부착/미부착된다
- [ ] 지오메트리 없이 스크립트만 있는 조합이 발생하면 **로그가 남는다** (침묵 아님)
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과
- [ ] 테스트 추가: `hadar2026_app/test/application/game_session_native_attach_test.dart` —
      `map_navigation_test.dart` 의 `_FakeAssets` 페이크 바인딩 패턴으로
      ① json 있는 이름 → 팩토리 등록 이름이면 부착됨 ② json 없는 이름 → **부착되지 않음**
      ③ 부착 실패 시 직전 스크립트도 남지 않음을 고정한다

## 하지 않을 것

- `MapInfos.json` 데이터 수정 — [P0-01](P0-01-mapinfos-name-resolution.md) 소관.
- 로드 실패의 반환값 계약 — [P0-02](P0-02-map-load-failure-silent.md) 소관.
- `TOWN2` 등록 정리 — [P0-06](P0-06-town2-unreachable.md) 소관.
- `mapScriptFactory` 를 데이터 주도(맵 JSON 에서 스크립트 이름 읽기)로 바꾸기 — P1 이후.
- 맵 스크립트의 좌표 하드코딩을 앵커로 바꾸기 — [P1-10](../deferred/P1-10-anchors.md) 소관.
