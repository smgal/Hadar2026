# P1-05 아이템 카탈로그와 인벤토리

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-03 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-03
- **설계 근거**: [BP-42 §2·§3·§7·§8](../../blueprint/42_item_and_inventory.md)(**소유 장**) · [BP-22 §6](../../blueprint/22_world_bible_model.md)(아이템 **스키마**) · [D-16-2 · D-20 · D-31](../../blueprint/_meta/DECISIONS.md) · `GROUND_TRUTH` §10 · 부록 H-3

## 문제

**인벤토리가 정수 두 개다.**
```dart
// hadar2026_app/lib/domain/party/party.dart:13-16
class PartyInventory {
  int food = 100;
  int gold = 500;
}
```
접근자도 이 두 개뿐이다(`party.dart:56-59`). **아이템 목록이라는 개념이 코드에 없다.**

장비도 정수 3개이고 이름은 플레이스홀더다.
```dart
// hadar2026_app/lib/domain/party/player.dart:44-46
int weapon = 0;
int shield = 0;
int armor = 0;
// :91
String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
```

아이템 데이터로 보이는 `hadar2026_app/assets/maps/books.json` 이 존재하지만
`grep -rn "books.json" hadar2026_app/lib` 결과가 **0건**이다 — 앱이 한 번도 읽지 않는다.
게다가 그 파일의 `weapon[].id` 는 1부터 시작하는 자체 번호이고 `HDPlayer.weapon` 정수와 **같은 공간이 아니다**(부록 H-3).

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다. 이것이 P1 전체에서 가장 직접적인 표현 불가 항목이다.**

- **인벤토리가 없으면 `acquire`·`deliver` 목표가 원리적으로 불가능하다**
  ([BP-23 §23.4.3](../../blueprint/23_quest_model.md)의 objective kind 9종 중 2종이 죽는다).
  "쪽지를 찾아 지기에게 건네라" 는 형태의 퀘스트 — 즉 **가장 기본적인 심부름 퀘스트** — 를
  손으로도 만들 수 없다. `food`/`gold` 정수만으로는 "무엇을" 가져오는지 구별할 수단이 없다.
- Condition `has_item`(C8)과 Effect `give_item`/`take_item`(E5/E6)도 대상 없이 남는다.
- 월드 이벤트 `item_gained`/`item_lost` 가 **발행 지점 부재**로 미발행 상태다(D-20).
  P1-09 가 버스를 만들어도 이 둘은 이 이슈가 끝나야 발행된다.

## 무엇을 할 것인가

**아이템 스키마는 [BP-22 §6](../../blueprint/22_world_bible_model.md), 인벤토리 게임 규칙과 실제 데이터는
[BP-42](../../blueprint/42_item_and_inventory.md) 소유다.** 필드 표·카탈로그 수치를 재서술하지 않는다.

1. `packages/hadar_content/lib/item.dart` — `Item` 모델 역직렬화.
   카테고리 9종, `stackable`/`maxStack`, `equip`, `effects`, `sources`, `grade`, `value`.
2. **저장소는 하나뿐이다** — `WorldState.inventory: Map<itemId, count>`
   ([BP-42 §2.1](../../blueprint/42_item_and_inventory.md)). P1-03 이 만든 필드를 쓴다.
   `PartyInventory.food`/`gold` 는 **남긴다** — Effect `add_gold`/`add_food`(E7/E8)가 그것을 계속 만진다.
   즉 "아이템은 `WorldState`, 화폐·식량은 `HDParty`" 라는 2원 구조를 명시적으로 문서화한다.
3. **파티 공용이다.** 개인 소지는 없다([BP-42 §2.2](../../blueprint/42_item_and_inventory.md)).
   **장착해도 가방에서 빠지지 않는다**([BP-42 §2.3](../../blueprint/42_item_and_inventory.md)) — 이 규칙이
   `has_item` 조건과 장착 상태를 서로 독립시켜 판정을 단순하게 만든다.
4. `hadar2026_app/lib/application/content/` 에 **획득·소실의 단일 통로**를 둔다
   ([BP-42 §2.5](../../blueprint/42_item_and_inventory.md)). `giveItem`/`takeItem` 이 그 통로이고,
   여기서만 `item_gained`/`item_lost` 를 발행한다(P1-09 의 버스에 연결).
   - payload 는 `{itemId, delta, total}` 이며 **정본은 [BP-23 §23.11.1](../../blueprint/23_quest_model.md)** 이다(D-20a).
     `count` 단일 필드를 쓰지 않는다 — 카운터형 목표의 판정이 흔들린다.
   - `maxStack` 초과분은 버리고 경고 로그를 남긴다. 조용히 버리지 않는다.
   - `take_item` 부족분은 0 클램프 + 경고. 하드 실패로 두면 "이미 잃어버린 퀘스트 아이템" 때문에 게임이 죽는다.
5. **소모품 즉시 효과** — `effects` 를 P1-02 의 `EffectApplier` 로 실행한다.
   D-31 이 추가한 `restore`·`cure`·`grant_buff` 3종이 여기서 쓰인다.
   `grant_buff` 의 허용 buff 는 **3종뿐**(`magicTorch`·`walkOnWater`·`canUseEsp`) —
   근거는 [BP-42 §1.7](../../blueprint/42_item_and_inventory.md) 의 실측
   (`party.dart:18-27` 의 8필드 중 5개는 읽는 곳이 0곳).
   `Effect` → `PartyBuffs` **다리**를 이 이슈가 놓는다(D-31 이 "어느 장도 소유하지 않음" 이라 표시한 태스크).
6. **초기 `core` 아이템 카탈로그 20종** — 실제 데이터는
   [BP-42 §7.4](../../blueprint/42_item_and_inventory.md) 를 그대로 `assets/content/core/items/items.json` 에 옮긴다.
   `books.json` 흡수는 [BP-42 §4.4](../../blueprint/42_item_and_inventory.md) 의 매핑을 따른다 —
   두 id 공간이 다르다는 부록 H-3 을 **명시적 매핑표로** 해소한다.

## 완료 판정 기준

- [ ] `assets/content/core/items/items.json` 에 20종이 있고 `hadar_content validate`(P1-12 이후) 통과 대상이 된다
- [ ] 게임 안에서 아이템을 **획득·소지·전달**할 수 있다 (Effect `give_item`/`take_item` 이 실제로 수량을 바꾼다)
- [ ] `has_item` 조건이 소지 수량을 정확히 읽는다 (장착 여부와 무관하게)
- [ ] `giveItem`/`takeItem` 이 아닌 경로로 `WorldState.inventory` 를 바꾸는 코드가 **없다** (단일 통로)
- [ ] `item_gained`/`item_lost` 가 `{itemId, delta, total}` payload 로 발행된다
- [ ] `grant_buff` 로 `magicTorch` 를 걸면 `sight_calculator` 의 시야가 실제로 바뀐다 (죽은 버프가 아님을 플레이로 확인)
- [ ] 세이브 → 로드 후 소지 아이템이 그대로다 (P1-04 의 `worldState.inventory`)
- [ ] **테스트 1**: `hadar2026_app/test/application/content/inventory_test.dart` —
      `maxStack` 초과 버림, 비스택 아이템 재지급, `takeItem` 0 클램프, 이벤트 payload 의 `delta`/`total` 정합.
      페이크 바인딩은 `test/application/map_navigation_test.dart:13-28` 패턴
- [ ] **테스트 2**: `packages/hadar_content/test/item_test.dart` —
      카탈로그 20종이 스키마를 만족하고, `consumable` 이면 `effects` 가 비어 있지 않다는 규칙(BP-22 R-22-18)을 고정

## 하지 않을 것

- **장비 배선**(`powOfWeapon` 덮어쓰기 · `ac` 합산 · `books.json` ac 재척도) — **P1-06**.
- **소지품·장비 UI** — **P1-14**. 이 이슈는 데이터 모델과 규칙까지다.
- 상점·매매 — 1차 스코프 밖([BP-40 §40.5.4](../../blueprint/40_gameplay_changes.md)). `value` 필드는 린트·`grade` 유도에만 쓰인다.
- 개인별 소지·무게 제한 — 채택하지 않는다.
- 전투식 변경 — B 갈래이며 범위 밖([BP-42 §4.5](../../blueprint/42_item_and_inventory.md)).
