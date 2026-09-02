# P1-14 소지품·장비 UI

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-05 대기)
- **구간**: P1
- **규모**: M
- **선행**: P1-05
- **설계 근거**: [BP-42 §5](../../blueprint/42_item_and_inventory.md)(**소유 장** — 진입·기하학·탭·목록/다루기 화면·장착 흐름) · [BP-41 R-41-8](../../blueprint/41_journal_ui_spec.md)(창 기하학) · [BP-40 §40.4](../../blueprint/40_gameplay_changes.md)

## 문제

**소지한 것을 볼 화면이 없다.** 볼 것이 두 정수뿐이었기 때문이다.

- `hadar2026_app/lib/domain/party/party.dart:13-16` 의 `PartyInventory` 가 `food`/`gold` 정수 2개뿐이다.
- 개인 상황 화면은 무기 이름을 플레이스홀더로 찍는다 —
  `hadar2026_app/lib/domain/party/player.dart:91`
  `String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";`
  `hadar2026_app/lib/application/menu_flows.dart:228` 의 `showCharacterStatus()` 가 이것을 출력한다.
- 메인 메뉴(`menu_flows.dart:34-43`) 7항목에 소지품이 없다.
- 선택 창의 표시 행 수가 하드코딩이다 — `hadar2026_app/lib/domain/window/selection_window_data.dart:11`
  `final int maxVisibleItems = 6;`

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** P1-05 가 아이템을, P1-06 이 장비 배선을 만들어도
**플레이어가 볼 수 없으면 `acquire`/`deliver` 목표를 검증할 방법이 없다** —
"쪽지를 받았는가" 를 확인하려면 저널이 아니라 소지품 화면을 봐야 한다.

퀘스트 아이템은 특히 이 화면에 의존한다. 버릴 수 없고 쓸 수 없는 물건이므로
([BP-42 §3.2](../../blueprint/42_item_and_inventory.md)) 소지 사실 자체가 유일한 관측 지점이다.

## 무엇을 할 것인가

**화면 스펙(기하학·탭 대응·행 배분·장착 흐름)은 [BP-42 §5](../../blueprint/42_item_and_inventory.md) 소유다. 재서술하지 않는다.**

1. **저널과 같은 창 크기·같은 키를 쓴다**(R-42-36) — **(144,40) · 512×400 · 본문 19행**.
   메뉴에서 이웃한 두 항목이 다른 조작법을 가지면 둘 다 외울 수 없다.
   따라서 P1-13 이 만든 창 기하학과 키 핸들러 구조를 **그대로 재사용**한다.
2. **화면에 "인벤토리" 라는 말을 쓰지 않는다**(R-42-37). 제목은 **`소지품`** 이다.
3. **신규 파일**
   - `hadar2026_app/lib/domain/window/inventory_window_data.dart` — `HDInventoryWindow extends HDWindow`
     + 탭 열거. 표시 상태만 보유하고 **키 처리는 하지 않는다**(기존 규약).
   - `packages/hadar_content/lib/inventory_rows.dart` — 목록/상세 DTO(순수 Dart).
     `hadar2026_app/lib/domain/content/inventory_rows.dart` 는 배럴.
   - `hadar2026_app/lib/application/content/inventory_presenter.dart` — 탭 필터·정렬·설명 2행 생성.
     정렬은 [BP-42 §2.4](../../blueprint/42_item_and_inventory.md) 규칙(결정론 필수).
   - `hadar2026_app/lib/presentation/panels/inventory_view.dart` — `HDInventoryView`.
4. **기존 수정**
   - `presentation/panels/window_view.dart:67` `_buildContent` — `HDInventoryWindow` 분기 1개.
   - `presentation/input/window_key_dispatcher.dart:35-40` `_dispatch` — `_handleInventory` 분기 1개.
   - `application/menu_flows.dart:34-43` `showMainMenu` — **`소지품을 살핀다`** 항목 추가 + `showInventory()` 신규.
   - `application/menu_flows.dart:228` `showCharacterStatus()` — 무기·방패·갑옷을 아이템 표시명으로 출력
     ([BP-42 §5.5](../../blueprint/42_item_and_inventory.md)). `getWeaponName()` 의 `"무기$weapon"` 이 화면에서 사라진다.
   - `domain/window/selection_window_data.dart:11` — `maxVisibleItems` 인자화(P1-13 과 공유 변경. 먼저 하는 쪽이 한다).
5. **탭 7개 ↔ 카테고리 9종 대응** — [BP-42 §5.1](../../blueprint/42_item_and_inventory.md) 표.
   `물건` 탭만 `quest`·`relic`·`crystal` 세 category 를 합친다(각각 1~2종이라 빈 탭이 생기는 것을 막기 위해).
   탭 안에서는 category 고정 순서를 유지하므로 정렬 결정론이 깨지지 않는다.
6. **장착 흐름** — [BP-42 §5.4](../../blueprint/42_item_and_inventory.md).
   장착해도 **가방에서 빠지지 않는다**([BP-42 §2.3](../../blueprint/42_item_and_inventory.md)) —
   이 규칙이 화면에서도 보여야 한다(장착 표시만 붙는다).
7. **불변식: 대화 진행 중에는 소지품을 열 수 없다**(R-42-37b).
   근거 3단은 [BP-42 §5.1](../../blueprint/42_item_and_inventory.md) 에 있다 —
   ① 소지품은 메인 메뉴에서만 열린다, ② 메인 메뉴는 `HDInputMode.map` 에서만 열린다
   (`hadar2026_app/lib/presentation/input/input_dispatcher.dart` 의 `_handleMap` 하나뿐),
   ③ `HDGameMain.currentInputMode` 가 `window > menu > dialogue > map` 우선순위이므로
   대화 대기 중에는 `dialogue` 가 잡혀 ②에 도달하지 못한다.
   **다른 진입점을 만들지 않는다.** 이 불변식이 "가려진 대화" 상태를 원천적으로 없앤다.

## 완료 판정 기준

- [ ] 메인 메뉴에 `소지품을 살핀다` 가 있고, 선택하면 소지품 창이 열린다 (플레이로 확인)
- [ ] 창 기하학이 저널과 동일하고(144,40 · 512×400 · 19행) 키 조작도 동일하다
- [ ] 화면 어디에도 "인벤토리" 라는 문자열이 없다 (grep 으로 확인 가능)
- [ ] 탭 7개가 동작하고, 빈 탭에서도 화면이 깨지지 않는다
- [ ] 퀘스트 아이템이 `물건` 탭에 보이고 **버리기·쓰기가 제공되지 않는다**
- [ ] 무기를 장착해도 목록에서 사라지지 않고 장착 표시만 붙는다
- [ ] `showCharacterStatus()` 가 `"무기1"` 대신 아이템 표시명을 출력한다
- [ ] **대화 대기 중에 Space/Esc/Q 를 눌러도 소지품이 열리지 않는다** (R-42-37b 불변식)
- [ ] 같은 인벤토리 상태로 두 번 열면 목록 순서가 동일하다 (결정론)
- [ ] 계층 grep 2종 통과 — `inventory_presenter.dart` 가 `presentation/` 을 import 하지 않는다
- [ ] **테스트 1**: `hadar2026_app/test/application/content/inventory_presenter_test.dart` —
      탭 필터, 정렬 결정론(`itemId` 사전순 · 가상 항목 `맨손`/`없음`/`평상복` 선행 ·
      `물건` 탭의 category 고정 순서), 설명 2행 생성.
      `HDHosts().bind(...)` + `reset()` 패턴은 `test/application/map_navigation_test.dart:13-28`
- [ ] **테스트 2**: `hadar2026_app/test/presentation/input/inventory_gate_test.dart` —
      **회귀** — 대화 대기 중 소지품 진입 차단(R-42-37b). `input_dispatcher` 의 모드 우선순위가 바뀌면 이 테스트가 먼저 깨진다
- [ ] **테스트 3**: `hadar2026_app/test/presentation/input/inventory_key_test.dart` —
      `HDWindowKeyDispatcher` 의 타입 스위치 순서 회귀 (`HDInventoryWindow` 가 `HDSelectionWindow` 보다 먼저 잡힌다)

## 하지 않을 것

- **대화 중 소지품 열기** — R-42-37c. 티어 0 의 비동기 대화 그래프가 들어오면 이 불변식이 깨질 수 있지만,
  `beginNarrative` 중첩 규약을 먼저 정해야 하므로 P1 에서 문을 열지 않는다.
- 상점·매매 화면 — 1차 스코프 밖.
- 아이템 아이콘·이미지 — 텍스트만.
- 무게·개인 소지·가방 확장 — 파티 공용 단일 저장소다([BP-42 §2.1·§2.2](../../blueprint/42_item_and_inventory.md)).
- 장비 성능 배선 자체 — **P1-06**.
- 위젯 테스트 인프라 도입 — P1 범위 밖(P1-13 과 같은 판단).
