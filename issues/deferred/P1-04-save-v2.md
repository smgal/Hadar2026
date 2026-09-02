# P1-04 세이브 v2 + v1 마이그레이션 (`mapDelta` 포함)

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-03 · P0-07 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-03 · P0-07
- **설계 근거**: [BP-25 §5~§8](../../blueprint/25_world_state_and_save.md)(**소유 장**) · [D-08 · D-08a · D-22](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` 부록 C-1 · C-2 · C-3

## 문제

세이브 v1 이 **콘텐츠를 지우고, 크기 한계에 부딪히고, 재현 불가능한 값을 담는다.**

**① 저장 대상이 5개뿐이다**
```dart
// hadar2026_app/lib/application/save_manager.dart:18-24
final Map<String, dynamic> data = {
  'version': 1,
  'party': session.party.toJson(),
  'gameSystem': session.gameSystem.toJson(),
  'gameOption': session.gameOption.toJson(),
  'map': session.map?.toJson(),
};
```
빠진 것: `HDNativeScriptRunner.flags`/`.variables`, `HDScriptEngine.variables`,
**현재 맵의 이름**(`session.currentMapCm2Path` 도 미저장). 맵은 데이터 스냅샷만 저장된다.

**② `map.events` 유실 → 로드 후 JSON 대사 티어 영구 사망** (부록 C-1)
`hadar2026_app/lib/domain/map/map_model.dart:50-58` 의 `toJson()` 에 `'events'` 키가 없고
`fromJson`(`:60~`)도 복원하지 않는다. `tile_event_dispatcher.dart:166` 이 `map.events` 를 순회하므로
세이브를 로드한 순간 Map002(18개)·Map003(3개)·Map010(8개)·Map011(9개)의 정적 대사가 전부 사라진다.
**P0-07 이 이 결함 자체를 고치므로 선행이다.**

**③ 로드가 네이티브 맵 스크립트를 붙이지 않는다** (부록 C-2)
`save_manager.dart:86` 은 `session.setNewMap(loadedMap)` 을 **직접** 호출한다.
네이티브 스크립트 스왑은 `hadar2026_app/lib/application/game_session.dart:117-128`,
즉 `loadMapFromFile` 안에만 있으므로 로드 경로가 그 코드를 타지 않는다.
`currentMapScript` 가 직전 맵의 것으로 남거나 `null` 이 된다.

**④ 크기** (부록 C-3)
`hadar2026_app/lib/domain/map/map_unit.dart` 의 `toJson()` 은 칸마다
`{"ixTile":N,"ixObj0":N,"ixObj1":N,"shadow":N,"ixEvent":N}` 을 만든다 — 최소 **~57바이트/칸**.
100×100 맵이면 **약 570KB/슬롯**이고 4슬롯이면 2MB 를 넘는다. 브라우저 `localStorage` 는 통상 5MB,
UTF-16 저장이라 실질 여유는 절반이다.

**⑤ 벽시계** — `hadar2026_app/lib/domain/party/player.dart:71` 이
`damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));` 로 독 데미지를 결정한다(부록 C-4).
저장 포맷이 논리 시각을 갖지 않으면 같은 세이브를 두 번 로드해도 같은 결과가 나오지 않는다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** P1-03 이 통합한 `WorldState` 가 저장되지 않으면 퀘스트 진행이 세션을 넘기지 못한다 —
저널을 열어 "진행 중" 을 본 다음 게임을 끄면 처음부터다. 손으로 만든 퀘스트 1개를 **완주 확인**(P1-16)하려면
저장·로드를 거쳐도 상태가 살아 있어야 한다.

또한 ②를 고치지 않으면 이관 기간 동안 **레거시 JSON 대사와 신규 콘텐츠가 공존하지 못한다** —
세이브를 한 번 로드한 플레이어는 레거시 대사를 영구히 잃는다.

## 무엇을 할 것인가

**봉투 전체(필드명·`mapDelta`·레거시 플래그 보관 위치)는 [BP-25 §5](../../blueprint/25_world_state_and_save.md) 소유다.**
구조를 재서술하지 않는다.

1. `hadar2026_app/lib/application/save_manager.dart` 를 v2 로 개편.
   - 봉투 최상위: `version:2` · `envelope` · `currentMapName` · `party` · `gameSystem` · `gameOption` ·
     `mapDelta` · `worldState` · `orphans`. 각 블록의 소속 근거는 [BP-25 §5.1](../../blueprint/25_world_state_and_save.md) 표.
   - **벽시계는 `envelope` 에만 둔다**(D-08a). `worldState` 안에는 `step` 정수뿐이고,
     `envelope` 는 결정론 해시(`contentHash`) 대상에서 **제외**한다.
   - `:84-87` 의 맵 복원을 `mapDelta` 적용으로 교체하고, **네이티브 스크립트 스왑 경로를 타게 한다**
     (부록 C-2 — `setNewMap` 직접 호출 대신 `game_session.dart:117-128` 과 같은 스왑을 수행하거나
     그 블록을 함수로 추출해 양쪽이 공유). P0-08 과 중복되지 않도록 P0-08 이 만든 접합점을 재사용한다.
2. **`mapDelta` — base 종류 2종**(D-22).
   - `base: "asset:<path>"` — 원본 대비 변경 칸만 `[[x,y,field,value],…]`.
   - `base: "generated"` — `Map::Init`/`Map::SetRow` 로 런타임 생성된 맵. 디스크 원본이 없으므로 전체 스냅샷을
     저장하되 **칸당 5필드 반복 JSON 을 쓰지 않는다.** 5개 정수 평행 배열 + **RLE** 로 인코딩한다.
     실사용 cm2 8개(`L1_ep1d0`~`d5_1`, `town1.cm2`)가 이 경로다.
   - `Map::Init`/`Map::SetRow` 실행 시 `base` 를 `generated` 로 표시하는 훅은
     `script_engine_adapter.dart` 의 해당 커맨드 핸들러에 둔다([BP-27](../../blueprint/27_runtime_engine.md) 이 훅을 정의).
   - `currentMapName` 은 **로드 성공이 확정된 뒤에만** 갱신한다. 미확정 상태에서는 `base: "generated"` 로 강등한다 —
     `map_navigation.dart` 의 조기 반환 경로(부록 D-2)에서 이름이 스테일해지기 때문이다.
3. **v1 → v2 마이그레이션** — 알고리즘은 [BP-25 §6](../../blueprint/25_world_state_and_save.md).
   - `gameOption.flags`/`variables` 를 `legacyFlagMap` **역참조**로 이름 공간에 흡수(P1-03 의 다리 재사용).
   - 역참조에 없는 정수는 `orphans.legacyFlag`/`.legacyVar` 로 보존한다. 버리지 않는다.
   - 맵 이름 추론은 [BP-25 §6.3](../../blueprint/25_world_state_and_save.md) 의 단서 순위를 따른다.
   - 마이그레이션 실패 시 동작은 [BP-25 §6.5](../../blueprint/25_world_state_and_save.md)(로드 거부 + 사용자 안내).
4. 세이브↔콘텐츠 버전 호환 판정 SC-1~SC-9 — [BP-25 §7](../../blueprint/25_world_state_and_save.md).
5. 원자성 — 부분 저장/부분 로드 방지([BP-25 §8.2](../../blueprint/25_world_state_and_save.md)).
   성공 로드가 `GameReloadException` 을 던져 실행 루프를 되감는 기존 계약은 유지한다.

## 완료 판정 기준

- [ ] 저장 → 로드 후 **JSON 대사 티어가 살아 있다** (Map002 의 18개 이벤트 대사가 다시 나온다)
- [ ] 저장 → 로드 후 `HDNativeScriptRunner.currentMapScript` 가 **로드된 맵의 것**이다 (직전 맵도 `null` 도 아니다)
- [ ] 100×100 맵에서 타일 3칸만 바꾼 세이브의 크기가 **50KB 미만**이다 (현행 ~570KB 대비)
- [ ] `generated` 맵 세이브가 RLE 인코딩을 쓰고, 디코딩 후 원본 맵과 **칸 단위로 동일**하다
- [ ] `worldState` 블록에 벽시계 타입이 **0개**다. `envelope.savedAtWallClock` 은 `contentHash()` 입력에서 제외된다
- [ ] v1 세이브 파일을 로드하면 v2 로 승격되고, `legacyFlagMap` 에 없는 정수 플래그가 `orphans` 에 남는다
- [ ] **테스트 1**: `hadar2026_app/test/application/save_v2_roundtrip_test.dart` —
      `WorldState` + `mapDelta`(양 base) 왕복 후 동치성. `HDHosts().bind(...)` 페이크 `AssetSource` 로
      원본 맵을 인메모리 제공한다 (선례: `test/application/map_navigation_test.dart:13-28`)
- [ ] **테스트 2**: `hadar2026_app/test/application/save_v1_migration_test.dart` —
      v1 봉투 픽스처 → v2 승격. `orphans` 보존과 맵 이름 추론 순위를 고정
- [ ] **테스트 3**: `hadar2026_app/test/application/save_events_regression_test.dart` —
      **부록 C-1 회귀** — 저장·로드 후 `map.events` 가 비지 않는다는 명제를 고정

## 하지 않을 것

- 독 데미지의 벽시계 제거 자체 — **P0-10**. 이 이슈는 저장 포맷이 벽시계를 담지 않는 것까지다.
- `Map::Init`/`Map::SetRow` 의 동작 변경 — `base` 표시 훅만 추가한다.
- 세이브 슬롯 UI 개편 — 범위 밖.
- 디버그 커맨드·치트 표면([BP-25 §9](../../blueprint/25_world_state_and_save.md)) — P1 범위 밖.
- 세이브를 `SharedPreferences` 밖(IndexedDB 등)으로 옮기는 것 — [BP-25 §8.3](../../blueprint/25_world_state_and_save.md) 의 대안은 P1 에서 채택하지 않는다.
