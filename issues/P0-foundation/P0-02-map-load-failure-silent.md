# P0-02 맵 로드 실패가 성공(`true`)으로 보고된다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: P0-01
- **설계 근거**: [`GROUND_TRUTH` 부록 D-2 · A-1](../../blueprint/_meta/GROUND_TRUTH.md) · [D-22 (`currentMapName` 스테일)](../../blueprint/_meta/DECISIONS.md) · [BP-34 시뮬레이터](../../blueprint/34_headless_sim_and_solver.md)

## 문제

`hadar2026_app/lib/application/map_navigation.dart:44` 는 이름이 인덱스에 있으면
`cm2Path = 'Map$idStr.cm2'` 를 **무조건** 부여한다(부록 A-1). `MapInfos.json` 에 `cm2` 필드가 없으므로
모든 등록 맵이 존재하지 않는 cm2 경로를 갖는다 — 실제로 있는 cm2 는 `assets/Map002.cm2`, `assets/Map003.cm2` **2개뿐**이다(본인 확인).

그 결과 JSON 로드 실패 분기가 무력화된다:

```dart
// map_navigation.dart:57-68
MapModel? json;
try {
  json = await _loader.loadMap(jsonAssetPath);
} catch (e) {
  if (cm2Path == null) {            // ← :63  cm2Path 는 등록 맵에서 항상 non-null
    errorMessage = "Failed to load map: $e";
    return null;
  }
  print("HDMapNavigation: cm2-only map $searchName (no JSON: $e)");   // :67
}
return MapBundle(mapName: searchName, json: json, cm2Path: cm2Path);  // :70  json == null 인 채 "성공"
```

호출자는 그 null 을 조용히 넘긴다:

```dart
// game_session.dart:97-99
if (bundle.json != null) {
  setNewMap(bundle.json!);
}
// ...
return true;                        // :130  실패했어도 true
```

**정리**: 맵 파일이 없으면 `map` 은 직전 맵 그대로 남고, cm2 스크립트만 교체되고,
`loadMapFromFile` 은 `true` 를 반환한다. 그리고 `executePendingNavigation` 은
`if (!isMap) await loadScript(...)` (`script_engine_adapter.dart:46`) 로 실패 경로를 두고 있지만
`isMap` 이 항상 true 이므로 **그 경로는 죽어 있다**.

## 왜 지금 고쳐야 하는가

- [P0-05](P0-05-native-script-without-geometry.md)(지오메트리 없는 맵에 네이티브 스크립트 부착)가 성립하는 **직접 원인**이 이 침묵이다.
- [D-22](../../blueprint/_meta/DECISIONS.md) 는 세이브 v2 의 `currentMapName` 이 "이 조기 반환 경로에서 스테일해질 수 있다" 는 것을
  이미 전제로 삼았다. 실패가 실패로 보고되면 D-22 의 강등 규칙(`base: "generated"`)이 훨씬 단순해진다.
- BP-34 의 헤드리스 시뮬레이터는 "warp 가 성공했는가" 를 판정해야 한다. 지금은 판정 근거가 없다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **`cm2Path` 무조건 부여를 제거**한다 — `MapInfos.json#cm2` 가 있을 때만 설정 | `map_navigation.dart:44` 1줄 삭제 | 원인을 없앤다. `:63` 의 `cm2Path == null` 가드가 의도대로 작동 | Map002/Map003 은 `cm2` 필드를 명시해야 한다 (데이터 2줄) |
| B | 실패 판정을 `json == null && cm2 로드 성공` 으로 강화 | `map_navigation.dart` + `game_session.dart` | cm2-only 맵을 정식 지원 | "cm2 로드 성공" 을 알려면 [P0-03](P0-03-cm2-load-state-leak.md) 이 선행되어야 한다 |
| C | `loadMapFromFile` 이 `json == null` 이면 `false` 를 반환 | `game_session.dart:97-130` | 가장 작은 변경 | cm2 로 맵을 만드는 정상 케이스(`town1.cm2:80 Map::Init(30,30)`)를 오탐한다 |

### 권고안: **A + C 의 제한판**

1. `map_navigation.dart:44` 의 무조건 `cm2Path` 부여를 삭제한다.

   ```diff
     resolvedJsonName = 'Map$idStr.json';
   - cm2Path = 'Map$idStr.cm2';
     if (info['json'] is String) overrideJsonName = info['json'];
     if (info['cm2'] is String) cm2Path = info['cm2'];
   ```

2. `assets/maps/MapInfos.json` 의 `LORE_EP(2)`·`MAP003(3)` 에 `"cm2": "Map002.cm2"` / `"Map003.cm2"` 를 명시한다
   (실제로 존재하는 두 cm2 를 잃지 않기 위해).
3. `game_session.dart` 의 `loadMapFromFile` 이 **`bundle.json == null` 이고 `bundle.cm2Path == null`** 이면
   `errorMessage` 를 세우고 `false` 를 반환하게 한다. cm2 가 있으면 기존처럼 진행 —
   `Map::Init` 로 맵을 만드는 정상 케이스를 깨지 않기 위해서다.
4. `map_navigation.dart:67` 의 `print` 를 `errorMessage` 병행 기록으로 바꾼다 (침묵 제거).

## 완료 판정 기준

- [ ] `MapInfos.json` 에 `cm2` 가 없는 이름을 로드하면 `bundle.cm2Path == null` 이다
- [ ] 존재하지 않는 맵 이름으로 `loadMapFromFile` 을 부르면 **`false`** 가 반환되고
      `HDGameSession().errorMessage` 가 비어 있지 않다
- [ ] `LORE_EP` 로드 시 `Map002.cm2` 가 여전히 로드된다 (부팅 회귀 없음 —
      `assets/startup.cm2:6` 이 이 경로를 탄다)
- [ ] `hadar2026_app/test/application/map_navigation_test.dart` 의
      `a name with neither JSON nor cm2 fails with an error message` 테스트가 여전히 통과하고,
      **새로 "인덱스에 등록되었지만 파일이 없는 이름" 케이스**가 추가되어 `bundle == null` 을 고정한다
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과

## 하지 않을 것

- cm2 로드 실패 시의 엔진 상태 누수 — [P0-03](P0-03-cm2-load-state-leak.md) 소관.
- 네이티브 스크립트 부착 조건 — [P0-05](P0-05-native-script-without-geometry.md) 소관.
- `currentMapName` 을 세션에 추가하는 것. 세이브 v2 필드이므로 [P1-04](../deferred/P1-04-save-v2.md) 소관.
- 실패를 UI 에 어떻게 보여줄지의 디자인. `errorMessage` 를 세우는 것까지만 한다.
