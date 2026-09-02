# P1-10 앵커와 트리거 인덱스 — NPC 정체성

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-01 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-01
- **설계 근거**: [BP-26](../../blueprint/26_entity_registry_and_anchors.md)(**소유 장** — 앵커 스키마 · 트리거 인덱스 · 정합 규칙) · [D-09 · D-27 · **D-28**](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` 부록 **J** · **K**

## 문제

**대사가 맵 JSON 안의 좌표에 박혀 있다. NPC 를 옮기면 대사가 깨진다.**

```dart
// hadar2026_app/lib/application/tile_event_dispatcher.dart:166-178
for (final ev in map.events) {
  if (ev.x == x && ev.y == y) { ... return; }
}
```
`map.events` 선형 탐색이고 좌표가 유일한 키다. 맵 편집기가 지형을 고치면서 이벤트를 옮기지 않으면
그 대사는 도달 불가가 되고, **아무 오류도 나지 않는다.**

부록 J 가 확정한 더 깊은 사실: **region 레이어는 기능적으로 죽어 있다.**
```dart
// hadar2026_app/lib/application/map_loader.dart:44
map.data[index].ixEvent = _getLayerData(rawData, 5, index, size);   // z5 = region, 0~255
// hadar2026_app/lib/domain/map/tile_properties.dart:187
int eventType = unit.ixEvent & 0x00FF0000;                          // 비트 16~23
```
region 값은 비트 0~7 에 들어가고 마스크는 비트 16~23 을 본다 — `200 & 0x00FF0000 == 0`.
**어떤 region 값도 타일 액션을 만들지 못한다.** `ixEvent` 상위 바이트가 채워지는 유일한 경로는
`map_loader.dart:57-67` 의 이벤트 이름 접두사 변환뿐이다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 손으로 만든 퀘스트도 맵을 편집한다 —
`tools/mapEditor` 로 지형을 다듬거나 NPC 위치를 조정하는 것은 저작 과정의 일상이다.
좌표 결합이 남아 있으면 편집 한 번에 콘텐츠가 조용히 끊기고, 그 발견이 플레이 시점까지 밀린다.
GATE-01 의 측정 항목 "플레이에서야 드러난 오류" 를 직접 키우는 요인이다.

MILESTONES §3 의 "NPC 를 맵에서 옮겨도 **대화가 따라온다** (앵커)" 가 이 이슈의 직접 판정이다.

## 무엇을 할 것인가

**핵심 결정: 앵커는 타일 비트에 의존하지 않는다**(D-27).
**region 200~255 예약안은 D-28 로 최종 기각**되었다 — 비용 문제가 아니라 부록 J 대로 **작동하지 않기 때문**이고,
로더 승격(BP-26 T1)이라는 작동하는 대안도 "맵 편집 내구성" 때문에 기각되었다.
따라서 **`map_loader.dart` 를 수정하지 않는다.** region 은 계속 읽히되 계속 아무 효과가 없다.

1. `packages/hadar_content/lib/anchor.dart`
   - `Anchor` · `AnchorKind`(`actor`/`sign`/`portal`/`trigger`/`container`/`battle`) ·
     `HDAnchorActivation`(**값 2개: `interact`, `stepOn`**).
   - 스키마는 [BP-26 §2](../../blueprint/26_entity_registry_and_anchors.md), `facing` 매핑은 §2.5.
   - `activation: "both"` 는 **굽히지 않고 두 키로 펼쳐진다**(R-26-61).
2. `hadar2026_app/lib/application/content/trigger_index.dart`
   - **조회 키는 `(mapName, "x,y", activation)` 3단**이다([BP-26 §4.2](../../blueprint/26_entity_registry_and_anchors.md)).
     3단 키는 `HDTileAction` 이름이 **아니다** — D-28 이 정정했고, 두 표기가 공존하면
     빌드가 굽는 키와 런타임이 조회하는 키가 갈라져 티어 0 이 통째로 죽는다.
   - 런타임 표현은 `mapName → (x<<16|y) → activation → anchorIds`.
     맵 폭·높이 실측 최대 100 이므로 `x<<16|y` 로 충분하다(R-26-12).
   - **현재 맵의 서브맵만 유지**하고 맵 전환 시 교체한다(R-26-13). 훅은
     `hadar2026_app/lib/application/game_session.dart:97-130`.
   - 클래스 계약(`has`/`resolve` 시그니처)의 정본은 [BP-27 §2.2](../../blueprint/27_runtime_engine.md) 다(R-26-72).
   - 다중 앵커는 `priority` 내림차순으로 굽고 `when` 으로 갈린다([BP-26 §4.4](../../blueprint/26_entity_registry_and_anchors.md)).
3. **앵커-타일 정합은 런타임 요구가 아니라 린트 규칙(WARN)** 이다(D-27 · [BP-26 §3.3](../../blueprint/26_entity_registry_and_anchors.md)).
   actor 앵커가 통행 가능한 타일 위에 있으면 마주 볼 수 없어 대화가 불가능하므로 여전히 경고 대상이지만,
   **런타임 동작 조건이 아니다.** 런타임은 위반을 무시하되 **한 번만 진단**한다
   ([BP-27 §4.6](../../blueprint/27_runtime_engine.md)).
4. **엔티티 레지스트리(역참조 인덱스)** — [BP-26 §5](../../blueprint/26_entity_registry_and_anchors.md).
   "이 actor 를 참조하는 대화·퀘스트·앵커" 를 역으로 찾는다. 좌표 이동 안전성(§6)의 재료이고,
   `tools/mapEditor` 가 앵커를 오버레이로 표시할 때도 이것을 읽는다(맵 데이터는 건드리지 않는다).
5. `assets/content/core/anchors/<MAPNAME>.json` 레이아웃과 로딩(`ContentRepository`, `AssetSource` 경유).

**부록 K 의 함의 — 진입점 3개 중 2개는 코드 변경이 필요 없다.**

| 진입점 | 파일:줄 | 게이트 | 앵커 발화 |
|---|---|---|---|
| step-on | `presentation/panels/player_sprite.dart:193` | **없음** | 코드 변경 없이 발화 |
| 확인키 | `presentation/panels/player_sprite.dart:405` | **없음** | 코드 변경 없이 발화 |
| bump | `presentation/panels/player_sprite.dart:359` (`if (action.isInteractive)`) | **있음** | 게이트 제거 필요 — **P0-18 담당** |

`:193`·`:405` 는 마주본/밟은 칸의 타일 액션과 **무관하게 항상** `checkTileEvent` 를 부르므로,
콘텐츠 티어가 `(map,x,y)` 로 인덱스를 직접 조회하면 앵커가 맵에 아무 표시를 남기지 않아도 발화한다.
`:359` 의 비대칭(같은 앵커가 조작 방식에 따라 다르게 동작)은 **P0-18** 이 제거한다.

## 완료 판정 기준

- [ ] `hadar2026_app/lib/application/map_loader.dart` 가 **한 줄도 바뀌지 않았다** (D-28 집행 — region 승격 금지)
- [ ] 앵커 파일에서 NPC 좌표만 바꿔도 대화가 그 좌표로 따라온다 (맵 JSON 무편집, 플레이로 확인)
- [ ] `TriggerIndex.lookup` 의 3단 키가 `interact`/`stepOn` **2값**이고, 그 밖의 문자열은 로드 시 예외다
- [ ] `activation: "both"` 앵커가 두 키 모두에서 조회된다
- [ ] `move` 타일(평범한 통행 칸) 위의 `trigger` 앵커가 step-on 으로 발화한다 (타일 비트 무의존 확인)
- [ ] actor 앵커가 통행 가능 타일 위에 있어도 **런타임은 죽지 않고** 진단 로그를 **1회만** 남긴다
- [ ] 역참조 레지스트리로 "이 actor 를 참조하는 것들" 을 나열할 수 있다
- [ ] **테스트 1**: `hadar2026_app/test/application/content/trigger_index_test.dart` —
      3단 키 조회, `both` 펼침, 다중 앵커 `priority` 정렬, 맵 전환 시 서브맵 교체를 고정.
      페이크 `AssetSource` 로 앵커 JSON 을 인메모리 제공한다
      (선례: `test/application/map_navigation_test.dart:13-28`)
- [ ] **테스트 2**: `hadar2026_app/test/application/content/anchor_no_tile_bits_test.dart` —
      **D-27 회귀** — `ixEvent`/`ixObj1`/`ixTile` 이 전부 0인 맵 칸에서도 앵커가 조회된다는 명제를 고정.
      누군가 타일 비트 의존을 되살리면 이 테스트가 먼저 깨진다
- [ ] **테스트 3**: `packages/hadar_content/test/anchor_test.dart` — 앵커 kind 6종 파싱과 `facing` 매핑

## 하지 않을 것

- **`map_loader.dart` region 승격** — D-28 로 최종 기각. BP-26 의 R-26-9·R-26-46~48·`A-26-13`·T-26-1 은 폐기 상태다.
- `Map001.json` region 마이그레이션 — 예약을 하지 않으므로 충돌이 없다(부록 I-1 무의미화).
- **bump 게이트 제거** — **P0-18**.
- **디스패처 티어 0 삽입** — **P1-11**.
- 기존 `map.events[]` → 앵커 **일괄 변환 실행** — 변환 규칙은 [BP-26 §8](../../blueprint/26_entity_registry_and_anchors.md) 에 있고,
  실제 이관은 P1-15·P1-16 이 필요한 만큼만 한다. `events[]` 는 레거시 폴백으로 남는다.
- 맵 에디터의 앵커 편집 UI — **P2**.
