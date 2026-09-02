# P0-07 세이브가 `map.events` 를 유실해 로드 후 JSON 대사 티어가 사망한다

- **상태**: TODO
- **구간**: P0
- **규모**: M
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 C-1 · §4 · §6](../../blueprint/_meta/GROUND_TRUTH.md) · [BP-25 세이브 포맷](../../blueprint/25_world_state_and_save.md)

## 문제

`hadar2026_app/lib/domain/map/map_model.dart:50-58`:

```dart
Map<String, dynamic> toJson() {
  return {
    'width': width,
    'height': height,
    'data': data.map((u) => u.toJson()).toList(),
    'handicapData': handicapData.toList(),
    'tileOverrides': tileOverrides.map((k, v) => MapEntry(k.toString(), v)),
  };          // ← 'events' 없음
}
```

`MapModel.fromJson`(`:60-81`)도 `events` 를 복원하지 않는다. `events` 는 `:13` 에
`List<MapEvent> events = []` 로 선언되어 있으므로, **세이브를 로드한 순간 빈 리스트가 된다.**

그리고 그 리스트가 JSON 대사 티어의 유일한 자료다 — `tile_event_dispatcher.dart:159-179`:

```dart
Future<void> _emitJsonDialog(MapModel map, int x, int y, UiHost host, HDTileAction action) async {
  for (final ev in map.events) {       // ← :166  빈 리스트면 아무것도 하지 않는다
    if (ev.x == x && ev.y == y) {
      for (final line in ev.dialogLines) { ... }
```

`_emitJsonDialog` 는 3티어 중 두 티어에서 호출된다 — 네이티브 맵(`:132`)과 cm2 폴백(`:144`),
그리고 레거시 경로(`:153`). **즉 세 경로 전부에서 정적 대사가 사라진다.**

영향 범위(부록 §6 의 이벤트 수 실측): `Map002`(18개)·`Map003`(3개)·`Map010`(8개)·`Map011`(9개) = **38개 이벤트**의
정적 대사가 세이브 로드 후 전부 사라진다. 부팅 맵이 `LORE_EP` → `Map002.json` 이므로(`assets/startup.cm2:6`)
**첫 맵의 18개가 바로 영향권**이다.

또 하나: `map_loader.dart` 는 맵 JSON 의 `events[]` 를 읽어 `ixEvent` 상위 바이트를 만든다(부록 J-1).
`data` 는 세이브에 들어가므로 **타일의 액션 판정은 살아남는데 대사만 사라진다** —
즉 "말을 걸 수는 있는데 아무 말도 안 하는 NPC" 가 된다. 침묵 실패다.

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 3번 항목이 정확히 이것이다:
  "세이브를 저장→로드한 뒤 **JSON 대사 티어가 살아 있다**".
- [P0-08](P0-08-save-skips-native-attach.md)(로드가 네이티브 스크립트를 붙이지 않음)의 **선행**이다 — 같은 `loadGame` 경로를 손대므로.
- [P1-04](../deferred/P1-04-save-v2.md)(세이브 v2 + `mapDelta`)가 이 이슈에 의존한다 (BOARD 의 선행 표기).
  v2 로 가더라도 "이벤트를 보존한다" 는 계약이 먼저 정의돼야 한다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 변경 | 장점 | 단점 |
|---|---|---|---|---|
| A | **`events` 를 `toJson`/`fromJson` 에 추가** | `map_model.dart` + `map_event.dart`(직렬화 필요) | 자기 완결적. 로드가 원본 파일에 의존하지 않는다 | 세이브 용량이 더 커진다 ([P0-09](P0-09-save-size-limit.md) 와 상충). `MapEvent` 에 `toJson` 이 없어 신규 작성 필요 |
| B | **맵 이름을 세이브에 넣고, 로드 시 원본 JSON 에서 `events` 만 다시 읽는다** | `save_manager.dart` + `game_session.dart`(`currentMapName` 추가) | 용량 증가 거의 없음. `events` 는 세이브 중 변하지 않는 정적 데이터이므로 원본이 정본으로 옳다 | `currentMapName` 이 필요하다. cm2 생성 맵(`Map::Init`)에는 원본이 없다 (D-22 의 `base` 구분과 같은 문제) |
| C | 로드 후 `events` 없음을 감지해 경고만 남긴다 | `save_manager.dart` 몇 줄 | 최소 변경 | 문제를 고치지 않는다. P0 완료 기준을 충족하지 못한다 |

### 권고안: **B, A 를 폴백으로**

1. `HDGameSession` 에 `String? currentMapName` 을 추가하고 `loadMapFromFile` 이 **로드 성공 확정 뒤에만** 세운다
   ([D-22](../../blueprint/_meta/DECISIONS.md) 가 요구하는 규칙과 동일 — 조기 반환 경로에서 스테일해지면 안 된다).
2. `save_manager.dart:18-24` 의 봉투에 `'mapName': session.currentMapName` 을 추가한다.
3. `loadGame` 의 맵 복원(`:84-87`)을 이렇게 바꾼다:

   ```diff
     if (data['map'] != null) {
       final loadedMap = MapModel.fromJson(data['map']);
   +   final name = data['mapName'] as String?;
   +   if (name != null) {
   +     // events 는 세이브 중 변하지 않는 정적 데이터다 — 원본 파일이 정본.
   +     final fresh = await HDMapNavigation().loadByName(name);
   +     if (fresh?.json != null) loadedMap.events = fresh!.json!.events;
   +   }
       session.setNewMap(loadedMap);
     }
   ```

4. **A 를 폴백으로 함께 넣는다**: `mapName` 이 없거나(구 세이브) 원본을 못 읽으면
   `data['map']['events']` 에서 읽는다. 따라서 `MapModel.toJson` 에도 `events` 를 추가하고
   `MapEvent` 에 `toJson`/`fromJson` 을 작성한다. 용량 우려는 [P0-09](P0-09-save-size-limit.md) 가 측정할 대상이며,
   이벤트 38개는 칸 10,000개 대비 무시할 규모다.
5. `version` 은 `1` 로 유지한다 — 필드 추가는 하위 호환이다. 봉투 승격은 [P1-04](../deferred/P1-04-save-v2.md) 소관.

## 완료 판정 기준

- [ ] `Map002`(이벤트 18개) 위에서 저장 → 로드한 뒤, 이벤트 좌표에서 상호작용하면
      **저장 전과 같은 대사가 나온다**
- [ ] 로드 직후 `HDGameSession().map!.events.length` 가 저장 전과 같다
- [ ] `mapName` 필드가 없는 **구 세이브를 로드해도 예외가 나지 않는다** (폴백 경로 동작)
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과
- [ ] 테스트 추가: `hadar2026_app/test/application/save_map_events_test.dart` —
      `map_navigation_test.dart` 의 `_FakeAssets` 패턴으로 맵을 만들고,
      `MapModel.toJson` → `fromJson` 왕복 후 **`events` 와 `dialogLines` 가 보존됨**을 고정한다.
      `_emitJsonDialog` 가 대사를 내보내는지는 페이크 `UiHost` 로 `addLog` 호출을 수집해 확인한다

## 하지 않을 것

- 세이브 봉투 v2 승격 · `mapDelta` 인코딩 — [P1-04](../deferred/P1-04-save-v2.md) 소관 ([D-22](../../blueprint/_meta/DECISIONS.md)).
- 세이브 용량 최적화 — [P0-09](P0-09-save-size-limit.md) 는 **측정과 경고만** 한다.
- `HDNativeScriptRunner.flags` / `HDScriptEngine.variables` 를 세이브에 넣기 — [P1-04](../deferred/P1-04-save-v2.md).
- 로드 후 네이티브 스크립트 부착 — [P0-08](P0-08-save-skips-native-attach.md) 소관.
- `hadarEvent: {kind, payload}` 확장의 디스패치 구현 (파싱만 되고 미디스패치, 부록 §6). P1 이후.
