# P0-01 `MapInfos.json` 이름 해석 파손 — 등록 15개 중 7개가 없는 파일로 해석된다

- **상태**: TODO
- **구간**: P0
- **규모**: M
- **선행**: P0-00
- **설계 근거**: [`GROUND_TRUTH` 부록 D-1 · F-4 · A-1 · H-4](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-22 places 매핑](../../blueprint/22_world_bible_model.md) · [BP-26 앵커](../../blueprint/26_entity_registry_and_anchors.md)

## 문제

`hadar2026_app/lib/application/map_navigation.dart` 의 해석 순서가 **폴백을 먼저 세우고 덮어쓴다**:

```dart
// :29
String resolvedJsonName = '$searchName.json'; // Fallback
...
// :39-49
for (var info in mapInfos) {
  if (info != null && info['name'] == searchName) {
    final int id = info['id'];
    final idStr = id.toString().padLeft(3, '0');
    resolvedJsonName = 'Map$idStr.json';   // ← :43 폴백을 덮어씀
    cm2Path = 'Map$idStr.cm2';             // ← :44 무조건 부여 (부록 A-1)
    if (info['json'] is String) overrideJsonName = info['json'];   // :45
    if (info['cm2'] is String) cm2Path = info['cm2'];              // :46
```

`json`/`cm2` 오버라이드 코드는 **이미 있다**(`:45-46`). 그런데 `assets/maps/MapInfos.json` 의
**15개 엔트리 중 어느 것도 `json`·`cm2` 필드를 갖고 있지 않다**(본인 재검증: `python3` 로 전 엔트리 덤프,
전부 `json=None cm2=None`). 따라서 등록된 이름은 무조건 `Map{id:03d}.json` 으로 해석된다.

### 부록 D-1 의 15행 표 — 본인 재검증 결과 (`assets/maps/` 실파일 대조)

실제 존재 파일: `DEN1 DEN2 GROUND1 Map001 Map002 Map003 Map010 Map011 Map013 Map014 Map015 ORIGIN TOWN1` (+`MapInfos`, `books`)

| 이름 | id | 해석 결과 | 존재 | `<이름>.json` 존재 | 판정 |
|---|---|---|---|---|---|
| Test | 1 | Map001.json | Y | N | OK |
| LORE_EP | 2 | Map002.json | Y | N | OK |
| MAP003 | 3 | Map003.json | Y | Y | OK |
| **TOWN1** | 4 | Map004.json | **N** | **Y** | **깨짐** |
| **GROUND1** | 5 | Map005.json | **N** | **Y** | **깨짐** |
| **DEN1** | 6 | Map006.json | **N** | **Y** | **깨짐** |
| **DEN2** | 7 | Map007.json | **N** | **Y** | **깨짐** |
| Template_TOWN | 8 | Map008.json | N | N | 깨짐 |
| Prolog | 9 | Map009.json | N | N | 깨짐 |
| Prolog_B1 | 10 | Map010.json | Y | N | OK |
| Prolog_B2 | 11 | Map011.json | Y | N | OK |
| Template_DUNGEON | 12 | Map012.json | N | N | 깨짐 |
| LoreContinent | 13 | Map013.json | Y | N | OK |
| CastleLore | 14 | Map014.json | Y | N | OK |
| LastDitch | 15 | Map015.json | Y | N | OK |

**부록 D-1 의 표와 일치한다. 깨짐 7건 확정.**

**핵심 역설**: TOWN1/GROUND1/DEN1/DEN2 는 동명 파일이 실제로 있다.
이름이 인덱스에 **없었다면 폴백이 살아남아 정상 로드되었을 것**이다.
반증 사례가 레포에 실재한다 — `ORIGIN` 은 `MapInfos.json` 에 미등록이고, `ORIGIN.json` 은 정상 로드된다(부록 F-4).
**즉 인덱스에 등록하는 행위가 맵을 로드 불가로 만든다.**

게임이 지금 부팅되는 이유는 `assets/startup.cm2:6` 이 `LoadScript("LORE_EP", 32, 25)` 로
**우연히 OK 행인 id 2 를 부르기 때문**이다(본인 확인). 첫 맵만 살아 있는 상태다.

## 왜 지금 고쳐야 하는가

- [P0-02](P0-02-map-load-failure-silent.md)(실패가 성공으로 보고)와 [P0-05](P0-05-native-script-without-geometry.md)(지오메트리 없는 맵에 네이티브 부착)는
  **둘 다 이 결함의 하위 증상**이다. 이 이슈가 선행이다.
- `TOWN1`/`GROUND1`/`DEN1` 은 네이티브 맵 스크립트가 등록된 3개 맵이다
  (`native_script_runner.dart:26-29`). 즉 **네이티브 스크립트가 붙는 맵 전부가 로드 불가**다.
- BP-22 의 `places` 매핑, BP-26 의 앵커/warp 검증, BP-34 의 헤드리스 시뮬레이터는
  "이름 → 맵" 이 신뢰 가능하다는 전제 위에 있다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 대상 | 장점 | 단점 |
|---|---|---|---|---|
| A | **`MapInfos.json` 의 7개 엔트리에 `json` 필드를 채운다** | 데이터만 (`assets/maps/MapInfos.json`) | 코드 무변경. 맵 에디터 `registerAs` 가 이미 `json: file` 을 쓰므로(부록 H-4) **신규 맵과 규약이 일치**한다 | 파일 없는 4개(Template_TOWN·Prolog·Template_DUNGEON·Map009)는 여전히 해석 불가 — 별도 처리 필요 |
| B | **폴백 우선순위를 반전한다** — `<이름>.json` 이 있으면 그것을 먼저 쓰고, 없을 때만 `Map{id}.json` | `map_navigation.dart:29-54` | 데이터 수정 없이 7건 중 4건이 즉시 살아난다 | 해석 규칙이 "파일 존재 여부" 에 의존해 **암묵적**이 된다. 같은 이름에 두 파일이 다 있으면 어느 쪽인지 코드를 읽어야 안다 |
| C | **등록을 해제한다** — 파일이 없는 이름을 `MapInfos.json` 에서 지운다 | 데이터만 | 부록 F-4 가 근거: 미등록이면 폴백이 살아 `ORIGIN` 처럼 정상 동작한다. 가장 적은 변경 | 인덱스가 "이름 목록" 역할을 못 하게 된다. BP-22 places 매핑이 인덱스를 참조할 곳을 잃는다 |

### 권고안: **A + C 조합**

1. **A** — `assets/maps/MapInfos.json` 의 `TOWN1(4)`·`GROUND1(5)`·`DEN1(6)`·`DEN2(7)` 4개 엔트리에
   `"json": "TOWN1.json"` 식으로 명시한다. 맵 에디터가 만드는 신규 엔트리와 형식이 같아져 규약이 하나로 통일된다.

   ```diff
   - {"id":4,"name":"TOWN1", ...}
   + {"id":4,"name":"TOWN1","json":"TOWN1.json", ...}
   ```

2. **C** — 데이터 파일이 아예 없는 `Template_TOWN(8)`·`Prolog(9)`·`Template_DUNGEON(12)` 는
   엔트리를 **삭제**하거나 `"json"` 을 명시한 뒤 [P0-02](P0-02-map-load-failure-silent.md) 의 실패 보고에 맡긴다.
   삭제를 권고 — 존재하지 않는 이름이 인덱스에 남아 있으면 BP-26 의 도달성 검증이 계속 위양성을 낸다.
3. **B 는 채택하지 않는다.** 단 `map_navigation.dart:29` 의 폴백 주석에
   "`json` 필드가 정본이며 이 폴백은 레거시 호환용" 임을 명시한다.
4. `cm2Path` 무조건 부여(`:44`, 부록 A-1)는 **[P0-02](P0-02-map-load-failure-silent.md) 소관**으로 넘긴다 — 이 이슈는 JSON 해석만 다룬다.

## 완료 판정 기준

- [ ] `assets/maps/MapInfos.json` 의 남은 모든 엔트리에 대해, `name` → 해석된 JSON 파일이
      `assets/maps/` 에 **실제로 존재**한다 (스크립트로 전수 대조하여 불일치 0건)
- [ ] `ORIGIN` 은 이전과 동일하게 로드된다 (미등록 폴백 경로 회귀 없음)
- [ ] `flutter test` 통과, `flutter analyze --no-fatal-infos` 통과
- [ ] `hadar2026_app/test/application/map_navigation_test.dart` 에 케이스 추가:
      `_FakeAssets` 로 실제 `assets/maps/MapInfos.json` 과 같은 형태(15 엔트리, `json` 필드 유)를 주고
      **모든 이름이 non-null `bundle.json` 을 낸다**는 것을 고정한다.
      기존 `honours the explicit json and cm2 overrides in the index` 테스트의 페이크 바인딩 패턴을 그대로 따른다.

## 하지 않을 것

- 맵 데이터(`TOWN1.json` 등) 내용 수정. 인덱스만 고친다.
- 없는 맵(`Template_TOWN` 등)의 **신규 제작**. 콘텐츠 작업은 P1 이후다.
- `cm2Path` 폴백 제거 — [P0-02](P0-02-map-load-failure-silent.md) 소관.
- `MapInfos.json` 스키마 확장(places·앵커 필드 추가 등). BP-22/BP-26 소관이며 P1 이다.
