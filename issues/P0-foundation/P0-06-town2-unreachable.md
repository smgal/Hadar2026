# P0-06 `TOWN2` 가 맵 없이 등록되어 실행 불가 코드로 남아 있다

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 G-2 · F-2 · D-1](../../blueprint/_meta/GROUND_TRUTH.md)

## 문제

`hadar2026_app/lib/application/scripting/native_script_runner.dart:25-30`:

```dart
final Map<String, HDMapScript Function()> mapScriptFactory = {
  'TOWN1': () => Town1MapScript(),
  'GROUND1': () => Ground1MapScript(),
  'TOWN2': () => Town2MapScript(),
  'DEN1': () => Den1MapScript(),
};
```

`TOWN2` 는 (본인 전수 확인):
- `assets/maps/MapInfos.json` 에 **등록되어 있지 않다** (15개 엔트리 덤프 확인)
- `assets/maps/TOWN2.json` **파일이 없다** (`assets/maps/` 목록 확인)
- `lib/application/scripting/maps/town2_map_script.dart` 는 **83줄로 실재**한다

도달 시도 경로는 실재한다 — `maps/ground1_map_script.dart:82`:

```dart
await HDNativeScriptRunner().loadMapScript('TOWN2');
```

이것이 `loadMapScript`(`native_script_runner.dart:43-61`) → `loadMapFromFile('TOWN2.json')` →
`HDMapNavigation.loadByName('TOWN2')` 로 흐른다. `TOWN2` 는 미등록이므로
`map_navigation.dart:29` 의 폴백 `'TOWN2.json'` 이 살아남지만 **그 파일이 없다.**
`cm2Path` 도 null 이므로 `:63-66` 의 가드가 발동해 `null` 을 반환하고,
`loadMapFromFile` 은 `:88` 에서 `false` 를 반환한다.

**결과**: `Town2MapScript` 는 `mapScriptFactory[bundle.mapName]` 조회에 도달할 수 없으므로
**한 번도 실행된 적이 없는 코드**다. 부록 F-2([P0-05](P0-05-native-script-without-geometry.md))와 달리 이쪽은 이름 자체가 도달 불가다.

참고로 `assets/town2.cm2` 는 355줄로 존재하지만, 그 파일의 `:501` 은
`Map::LoadFromFile("town1.map")` 을 부른다 — 레거시 `*.map` 은 이미 삭제된 포맷이다(`CLAUDE.md`).
즉 **cm2 쪽 경로도 살아 있지 않다.**

## 왜 지금 고쳐야 하는가

- P0 의 목표는 "맵을 이름으로 부를 수 있다" 다. 도달 불가 이름이 인덱스/팩토리에 남아 있으면
  [P0-01](P0-01-mapinfos-name-resolution.md) 의 전수 검증과 BP-26 의 도달성 검증이 **위양성을 계속 낸다.**
- `ground1_map_script.dart:82` 는 지금 플레이어에게 **아무 일도 일어나지 않는 출구**로 보인다.
  `loadMapFromFile` 이 `false` 를 반환하지만 호출부는 그 값을 쓰지 않는다.
- 코드 83줄 + cm2 355줄이 "동작하는 콘텐츠" 로 오인될 수 있다. 물량 판정([P0-00](P0-00-content-volume-target.md))을 흐린다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **등록 해제 + 폐기 예정 표시** — `mapScriptFactory` 에서 `'TOWN2'` 를 지우고, `town2_map_script.dart` 와 `ground1_map_script.dart:82` 에 도달 불가 사유 주석을 남긴다 | 3파일 소규모 | 가장 정직하다. 검증이 위양성을 멈춘다. 코드는 보존되므로 나중에 맵을 만들면 되살릴 수 있다 | `TOWN2` 콘텐츠가 계속 잠들어 있다 |
| B | **`TOWN2.json` 맵을 새로 만든다** | 신규 맵 데이터(맵 에디터) | 콘텐츠 83줄이 살아난다 | **P0 범위 밖.** "콘텐츠 모델·새 콘텐츠 금지" 규칙 위반. 맵 제작은 별개 작업량 |
| C | **파일과 cm2 를 삭제한다** | 3파일 삭제 | 레포가 가장 깔끔해진다 | 되돌릴 수 없다. `town2.cm2` 355줄에 원작 대사가 들어 있을 가능성 — [P0-00](P0-00-content-volume-target.md) 물량 판정 전에 지울 근거가 없다 |

### 권고안: **A**

```diff
  final Map<String, HDMapScript Function()> mapScriptFactory = {
    'TOWN1': () => Town1MapScript(),
    'GROUND1': () => Ground1MapScript(),
-   'TOWN2': () => Town2MapScript(),
    'DEN1': () => Den1MapScript(),
  };
+ // 'TOWN2' 는 의도적으로 등록하지 않는다: assets/maps/TOWN2.json 이 없고
+ // MapInfos.json 에도 미등록이라 loadByName('TOWN2') 가 항상 null 을 낸다
+ // (부록 G-2). 맵 데이터가 생기면 여기에 되살릴 것.
```

그리고 `maps/ground1_map_script.dart:82` 의 `loadMapScript('TOWN2')` 지점에
같은 사유 주석을 남긴다 — 플레이어에게 "여긴 아직 갈 수 없다" 대사를 하나 내보내도 좋다
(`town1_map_script.dart:54` 의 `"밖은 황야가 펼쳐져 있다. 구현 예정..."` 이 같은 선례).

`town2_map_script.dart` 파일과 `assets/town2.cm2` 는 **지우지 않는다.**
`import '../maps/town2_map_script.dart'`(`native_script_runner.dart:4`)는 미사용이 되므로
`flutter analyze` 의 `unused_import` 를 확인해 필요하면 임포트만 제거한다.

## 완료 판정 기준

- [ ] `HDNativeScriptRunner().mapScriptFactory.keys` 의 **모든 이름이** `assets/maps/` 의
      실제 맵으로 해석된다 (스크립트로 전수 대조, 불일치 0건)
- [ ] `ground1_map_script.dart` 의 TOWN2 출구를 타면 침묵하지 않는다 (대사 또는 로그가 남는다)
- [ ] `town2_map_script.dart` 파일과 `assets/town2.cm2` 는 **삭제되지 않았다** (git 상태로 확인)
- [ ] `flutter analyze --no-fatal-infos` 통과 (미사용 임포트 경고 없음)
- [ ] 테스트 추가: `hadar2026_app/test/application/scripting/map_script_factory_test.dart` —
      `mapScriptFactory` 의 키 집합이 `{'TOWN1','GROUND1','DEN1'}` 임을 고정한다.
      맵을 새로 만들어 되살릴 때 이 테스트가 함께 갱신되도록 하는 것이 목적이다

## 하지 않을 것

- `TOWN2.json` 맵 제작. P0 은 순수 복구이며 새 콘텐츠는 범위 밖이다.
- `town2_map_script.dart` / `assets/town2.cm2` 삭제.
- `assets/*.cm2` 의 `Map::LoadFromFile("*.map")` 죽은 호출 정리 — 별건이며 P1 이후.
- `TOWN2` 를 `MapInfos.json` 에 등록하는 것 (맵 파일이 없으므로 [P0-01](P0-01-mapinfos-name-resolution.md) 의 전수 검증을 다시 깨뜨린다).
