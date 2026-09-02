# P0-09 맵 스냅샷 세이브가 웹 저장 한계에 근접한다 — 한계 측정과 경고까지만

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 C-3 · B-5](../../blueprint/_meta/GROUND_TRUTH.md) · [D-22 `mapDelta`](../../blueprint/_meta/DECISIONS.md) · [BP-25 세이브 포맷](../../blueprint/25_world_state_and_save.md)

## 범위 선언 (먼저 읽을 것)

**세이브 v2 와 `mapDelta` 는 [P1-04](../deferred/P1-04-save-v2.md) 소관이며 [D-22](../../blueprint/_meta/DECISIONS.md) 가 이미 설계를 확정했다.**
이 이슈는 **한계를 측정하고, 한계에 닿았을 때 침묵하지 않게 하는 것**까지만 한다.
포맷을 바꾸지 않는다.

## 문제

`hadar2026_app/lib/domain/map/map_unit.dart:26-34` 는 칸마다 키를 반복한다:

```dart
Map<String, dynamic> toJson() {
  return {
    'ixTile': ixTile,
    'ixObj0': ixObj0,
    'ixObj1': ixObj1,
    'shadow': shadow,
    'ixEvent': ixEvent,
  };
}
```

`map_model.dart:54` 가 `data.map((u) => u.toJson()).toList()` 로 전 칸을 담고,
`save_manager.dart:23` 이 `'map': session.map?.toJson()` 으로 봉투에 넣는다.

### 본인 실측 (`assets/maps/` 실데이터로 `toJson` 출력을 재현)

| 맵 | 크기 | 칸 수 | 맵 항목 JSON | 칸당 |
|---|---|---|---|---|
| `TOWN1.json` | 100×100 | 10,000 | **602KB** | 61.6B |
| `GROUND1.json` | 100×100 | 10,000 | **606KB** | 62.1B |
| `Map002.json` | 50×50 | 2,500 | 150KB | 61.4B |

부록 C-3 의 "약 570KB/슬롯" 추정보다 **약간 크다**(실측 602~606KB). 칸당 57B 추정 대비 61.6B.
슬롯 4개를 100×100 맵으로 채우면 **약 2.4MB**.

`shared_preferences` 의 웹 백엔드는 `localStorage` 이고 통상 한도 5MB, **UTF-16 저장이라 실질 여유는 그 절반**이다.
그리고 `save_manager.dart:26-27` 은 실패를 이렇게 처리한다:

```dart
final jsonString = jsonEncode(data);
await prefs.setString('${_savePrefix}$index', jsonString);
return true;
} catch (e) {
  if (kDebugMode) {
    print("Failed to save game: $e");   // ← :31  릴리즈 빌드에서는 아무 흔적도 없다
  }
  return false;
}
```

**즉 웹 릴리즈에서 용량 초과로 저장이 실패하면 로그조차 남지 않는다.** 반환값 `false` 를 호출부가
플레이어에게 보여주는지 확인이 필요하다(`menu_flows.dart` 의 `selectSaveMenu`).

## 왜 지금 고쳐야 하는가

- 웹은 이미 배포 대상이다(`.github/workflows/deploy_web.yml`). 실패가 침묵하면 플레이어가 진행을 잃는다.
- [P1-04](../deferred/P1-04-save-v2.md) 가 `mapDelta` 를 도입할 때 **개선 폭을 주장할 기준선**이 필요하다.
  부록 B-5(웹 페이로드 45MB 실측)와 같은 역할이다 — 숫자 없이 최적화를 정당화하면 안 된다.
- [P0-07](P0-07-save-drops-map-events.md) 이 `events` 를 봉투에 추가하므로 용량이 조금 더 늘어난다. 그 증가분도 측정 대상이다.

## 무엇을 할 것인가

포맷은 그대로 두고 **세 가지만** 한다.

1. **측정을 코드로 고정한다** — `save_manager.dart` 의 `saveGame` 이 `jsonString.length` 를 로그로 남긴다.
   `kDebugMode` 밖에서도 남도록 하고, 임계값(예: 2MB)을 넘으면 경고 등급으로 구분한다.

   ```diff
     final jsonString = jsonEncode(data);
   + final bytes = jsonString.length;   // UTF-16 code units ≈ localStorage 소비 단위
   + if (bytes > _warnBytes) {
   +   print("HDSaveManager: save slot $index is ${(bytes / 1024).round()}KB "
   +         "(warn threshold ${(_warnBytes / 1024).round()}KB) — see P0-09/P1-04");
   + }
     await prefs.setString('${_savePrefix}$index', jsonString);
   ```

2. **실패를 침묵시키지 않는다** — `catch` 의 `kDebugMode` 가드를 걷고,
   `saveGame` 이 `false` 를 반환할 때 호출부가 플레이어에게 알리는지 확인해 없으면 메시지를 추가한다
   (`menu_flows.dart` 의 저장 메뉴). `UiHost.addLog` 를 쓴다.
3. **기준선을 문서로 남긴다** — 위 실측 표를
   `hadar2026_app/UI_SPEC.md` 가 아니라 이 이슈 파일에 남긴 것으로 충분하다.
   [P1-04](../deferred/P1-04-save-v2.md) 가 이 표를 인용한다.

## 완료 판정 기준

- [ ] 100×100 맵에서 저장하면 세이브 크기(KB)가 **로그에 남는다** (릴리즈 빌드 포함)
- [ ] 임계값을 넘는 세이브는 경고 로그로 구분된다
- [ ] 저장 실패(`saveGame == false`) 시 **플레이어가 보는 메시지가 나온다** — 침묵하지 않는다
- [ ] `catch` 블록의 `kDebugMode` 가드가 제거되어 릴리즈에서도 원인이 남는다
- [ ] 테스트 추가: `hadar2026_app/test/domain/map/map_model_size_test.dart` —
      100×100 `MapModel` 을 만들어 `jsonEncode(map.toJson()).length` 가
      **550,000 초과·700,000 미만**임을 고정한다.
      목적은 최적화 검증이 아니라 **[P1-04](../deferred/P1-04-save-v2.md) 가 개선했을 때 이 테스트가 실패해 기준선 갱신을 강제**하는 것이다
      (테스트 주석에 그 의도를 명시)

## 하지 않을 것

- **`mapDelta` 도입 · 5필드 평행 배열 · RLE 인코딩** — 전부 [P1-04](../deferred/P1-04-save-v2.md) 소관이며 [D-22](../../blueprint/_meta/DECISIONS.md) 가 설계를 확정했다.
- 세이브 봉투 `version` 승격.
- `shared_preferences` 를 IndexedDB 등 다른 저장소로 교체.
- 압축(gzip/base64) 도입. 포맷 변경이며 [P1-04](../deferred/P1-04-save-v2.md) 에서 함께 판단할 일이다.
- 슬롯 수 축소나 세이브 정책 변경.
