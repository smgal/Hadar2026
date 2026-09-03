# G1-03 파티 소지품 — `HDParty` 에 아이템 목록을 만든다

- **상태**: DONE
- **구간**: G1
- **규모**: M
- **선행**: [G1-01](G1-01-item-model-port.md)
- **설계 근거**: [MILESTONES §1.5](../MILESTONES.md) · [DECISION-LOG 3차 판정](../DECISION-LOG.md) · [`GROUND_TRUTH` §10](../../blueprint/_meta/GROUND_TRUTH.md)
- **참고만**: [BP-42 §2](../../blueprint/42_item_and_inventory.md) — `WorldState.inventory` 노선은 **채택하지 않는다**. 여기서는 `HDParty` 에 직접 넣는다.

## 문제

### 소지품이 정수 두 개다

`hadar2026_app/lib/domain/party/party.dart:13-16` (직접 확인):

```dart
class PartyInventory {
  int food = 100;
  int gold = 500;
}
```

노출도 `:56-59` 의 `food`/`gold` getter·setter 둘뿐이다. **"무엇을 몇 개 가졌다" 를 표현할 수단이 없다.**

### 원작에는 20칸 가방이 있다

`REF_UNITY_LoreEp1/src_as_cs/ObjParty.cs:109`:
```csharp
public int  current_capacity_of_backpack = 20;
```
같은 파일 `:424-471` 이 API 3종을 정의한다:
- `PutInBackpack(Equiped)` `:424-439` — **첫 빈 칸**을 찾아 넣고, 자리가 없으면 `false`
- `PutInBackpack(ResId)` `:441-444` — id 로부터 만들어 넣는 편의 오버로드
- `RemoveFromBackpack(Equiped)` `:446-461` — 슬롯을 `null` 로 되돌림
- `GetNumItemsInBackpack()` `:463-471` — 유효 칸 수

가방은 **파티 공용**이다 — 저장소가 `GameRes.party.core.back_pack` 이고 개인 소지 개념이 없다.
세이브도 용량을 그대로 직렬화한다(`ObjParty.cs:2424` 읽기 / `:2488` 쓰기).

## 왜 지금 고쳐야 하는가

- **재미** — "가방에서 본다" 가 없으면 아이템을 얻어도 아무 일이 일어나지 않는다. [G1-07](G1-07-inventory-ui.md) 이 그릴 대상이 이것이다.
- **부채 방지** — 3차 판정: 2차 판정은 "퀘스트 아이템 = 플래그"(`GFD0_GET_KEY_FOR_D1` 이 곧 열쇠 소지)로 갔다. 그 표현으로 퀘스트 20개를 쓰면 **20개를 다시 쓴다.** [G1-08](G1-08-cm2-item-commands.md) 의 `Item::Has` 가 이 위에 얹히고, 그것이 [S1-03](../S1-sample-quest/S1-03-quest-cm2.md) 의 선행이다([BOARD](../BOARD.md)).
- [G1-04](G1-04-equipment-slots.md) 의 장착/해제는 "해제하면 가방으로 돌아간다"(`GameEventEquipment.cs:130`)를 전제한다. 가방이 없으면 해제가 아이템을 **없애 버린다**.

## 무엇을 할 것인가

### 이식 대응표

| 원작 | Dart | 비고 |
|---|---|---|
| `ObjParty.cs:109` `current_capacity_of_backpack = 20` | `PartyInventory.capacity` (기본 20) | 필드로 둔다 — 원작이 세이브에 담는다 |
| `back_pack[]` (고정 길이 슬롯 배열) | `List<HDItemId?> backpack` (길이 = `capacity`) | **고정 길이 유지.** 아래 근거 |
| `PutInBackpack` `:424-439` | `bool give(HDItemId)` | 첫 `null` 칸에 넣고, 없으면 `false` |
| `RemoveFromBackpack` `:446-461` | `bool take(HDItemId)` | 첫 일치 칸을 `null` 로. 없으면 `false` |
| — (원작에 없음) | `bool has(HDItemId)` | [G1-08](G1-08-cm2-item-commands.md) `Item::Has` 가 쓴다 |
| `GetNumItemsInBackpack` `:463-471` | `int get count` | |

`party.dart` 는 이미 `package:flutter/foundation.dart` 만 import 한다(`:1`). 계층 위반 없음.

### 왜 고정 길이 슬롯 배열인가 (`List<HDItemId>` 가 아니라 `List<HDItemId?>`)

1. **원작이 슬롯 인덱스로 참조한다** — `GameEventEquipment.cs:369-370` 이 `back_pack[i]` 를 순회하며 인덱스로 목록을 만든다.
2. **[G1-07](G1-07-inventory-ui.md) 의 커서가 인덱스다** — 아이템을 하나 꺼내도 나머지 항목의 위치가 밀리지 않는 것이 원작 동작이다.
3. **[G1-09](G1-09-item-save.md) 의 직렬화가 단순해진다** — 길이 20 의 정수 배열(`null` → `-1`)이 되고 용량이 곧 스키마다.

### 노출

`HDParty` 는 `_inventory` 를 private 으로 들고 `food`/`gold` 만 위임한다(`party.dart:40, 56-59`).
같은 방식으로 `give`/`take`/`has`/`itemCount`/`itemCapacity`/`itemAt(i)` 를 위임한다.
아이템이 바뀌면 `notifyListeners()` — `HDParty` 는 `ChangeNotifier`(`:29-37`, `Future.microtask` 래핑)다.

**개인 소지는 만들지 않는다.** 원작이 파티 공용이고, `HDPlayer` 6명(`party.dart:81`) 각자에게 가방을 주면
[G1-07](G1-07-inventory-ui.md) 의 화면이 800×480 에 들어가지 않는다.

## 완료 판정 기준

- [x] `PartyInventory` 가 `capacity`(기본 20)와 `List<HDItemId?> backpack` 을 갖고, `food`/`gold` 는 그대로 남아 있다
- [x] `HDParty.give()` 가 **첫 빈 칸**에 넣는다 — 20칸이 찬 상태에서는 `false` 를 반환하고 **아무것도 버리지 않는다**
- [x] `HDParty.take()` 가 첫 일치 칸만 비우고, 없는 아이템이면 `false` 를 반환한다
- [x] `HDParty.has()` 가 있음/없음을 정확히 답한다 (같은 아이템 2개면 1개를 꺼낸 뒤에도 `true`)
- [x] 아이템 변경 시 `notifyListeners()` 가 호출된다 (`HDGameMain()` 리스너로 UI 가 갱신됨)
- [x] `domain/` 계층 위반 grep 2종 통과 (`flutter/material`·`bonfire`·`flame` 0건, `presentation`·`hd_game_main` 0건)
- [x] 테스트 추가: `hadar2026_app/test/domain/party/party_inventory_test.dart` —
      ① 20칸을 채운 뒤 21번째 `give` 가 `false` 이고 기존 20칸이 **그대로**임을 고정
      ② 5번 칸을 `take` 한 뒤 `give` 하면 **5번 칸이 다시 쓰인다**(첫 빈 칸 규칙, `ObjParty.cs:426-433` 과 같은 동작)
      ③ 같은 아이템 2개 → `take` 1회 → `has` 가 여전히 `true`, `count` 가 1 감소
      ④ `food`/`gold` 가 소지품 변경에 영향받지 않음
- [x] 기존 테스트 `test/domain/party/party_actions_test.dart` 가 그대로 통과한다

## 하지 않을 것

- **세이브 직렬화** — `toJson`/`fromJson` 에 `backpack` 을 넣는 것은 [G1-09](G1-09-item-save.md) 소관. 이 이슈는 **런타임 자료구조**만 만든다.
- **cm2 노출** — `Item::Give/Take/Has` 등록은 [G1-08](G1-08-cm2-item-commands.md).
- **화면** — 목록 UI 는 [G1-07](G1-07-inventory-ui.md).
- **장착과의 연동** — "해제하면 가방으로" 는 [G1-04](G1-04-equipment-slots.md)·[G1-07](G1-07-inventory-ui.md) 이 붙인다.
- 스택(같은 아이템 개수 묶음)·정렬·자동 정리 — 원작에 없다. 20칸이 곧 개수다.
- 개인 소지·무게·용량 증가 아이템 — `capacity` 는 필드로 두지만 늘리는 수단은 만들지 않는다.
- 상점·제작·강화·선언적 콘텐츠 팩·저널 UI.

## 구현 기록 (2026-09-03)

### 산출물

| 파일 | 내용 |
|---|---|
| `hadar2026_app/lib/domain/party/party.dart` | `PartyInventory` 에 `capacity`·`backpack`·`give`/`take`/`has`/`count`, `HDParty` 에 위임 6종 |
| `hadar2026_app/test/domain/party/party_inventory_test.dart` | 9개 테스트 |

### 검증

- `flutter test` — 118개 전량 통과 (G1-02 후 109 + 신규 9). `party_actions_test.dart` 그대로 통과
- `flutter analyze --no-fatal-infos` — 77건, **기존과 동일**
- 계층 위반 grep 2종 — 둘 다 빈 결과 (`party.dart` 는 `foundation.dart` + 도메인 상대 import 뿐)

### 이슈 서술에서 벗어난 부분

- **`capacity` 를 `final` 로 뒀다.** 이슈는 "필드로 둔다" 였고 `final` 도 필드다.
  `backpack` 의 길이가 `capacity` 와 어긋나면 안 되는데 가변이면 둘이 갈라진다.
  "늘리는 수단은 만들지 않는다"(이 이슈의 「하지 않을 것」)와도 맞는다.
  [G1-09](G1-09-item-save.md) 는 `PartyInventory(capacity: n)` 로 복원하면 된다.
- **`itemAt` 은 범위 밖에서 `RangeError` 를 던진다** — null 을 돌려주면 "빈 칸" 과
  "그런 칸 없음" 이 구분되지 않는다. 조용한 무시는 [P0-14](../P0-foundation/P0-14-silent-out-of-range.md) 가 기록한 실패 방식이다.
- **실패한 `give`/`take` 는 `notifyListeners()` 를 부르지 않는다** — 바뀐 것이 없다.
  테스트가 이 동작을 고정한다.
