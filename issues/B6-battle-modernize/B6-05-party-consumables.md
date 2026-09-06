# B6-05 소비 아이템과 시작 인벤토리

- **상태**: DONE (2026-09-06)
- **구간**: B6
- **규모**: M
- **선행**: [G1-03](../G1-items/G1-03-party-inventory.md) ✅ · [B3-03](../B3-battle-integrate/B3-03-rpg-attributes.md)

## 문제

B2-06 이 전투에 아이템을 넣었지만 **RPG 쪽에 대응하는 물건이 없다.**
`battleItems` 의 키(`potion` · `antidote` …)는 전투 안의 이름이고, RPG 카탈로그
(`item_data.dart`)는 **장비만** 있다 — 무기 · 방패 · 갑옷 · 머리 · 다리 · 장식.
그래서 `assembleSetup` 은 `held` 를 채울 수 없고 `applyOutcome` 의 `_consume` 은 비어 있다.

> 원작 시리즈에서는 아이템을 쓸 수 있었다. 그리고 검에 바르는 것이 생기면
> **소비되는 물건**이 반드시 필요하다.

## 무엇을 할 것인가

### `HDItemType.consumable(12)` 를 추가한다

원작의 `ITEM_TYPE` 은 `ETC_MAX = 12` 로 끝난다(배타 상한). **12 는 비어 있다.**
와이어 값은 cm2 `Item::Give(wire)` 와 세이브에 들어가므로 `item_type_test.dart` 에
고정한다. `isEtc` 등 기존 범위 판정은 건드리지 않는다 — 소비품은 어느 부위에도 못
간다(`equipSlot == null`).

### 카탈로그는 생성 파일 밖에 둔다

`item_data.dart` 는 `tools/convert_item.py` 가 만드는 파일이다. 소비품은 원작에
없으니 **손으로 쓴 `consumable_data.dart`** 에 두고, 둘을 합쳐 찾는 `lookupItem` 을
둔다. 생성 파일은 한 줄도 건드리지 않는다.

| index | 이름 | 전투 키 | 하는 일 |
|---|---|---|---|
| 0 | 회복약 | `potion` | HP 회복 |
| 1 | 해독제 | `antidote` | 독 제거 |
| 2 | 만병통치약 | `elixir` | 의식 회복 + 해독 + 회복 |
| 3 | 소생의 부적 | `revive_charm` | 부활 |
| 4 | 기력의 약 | `sp_tonic` | **SP 회복** (새로) |
| 5 | 독병 | `poison_vial` | 무기에 독 (B6-03) |
| 6 | 마비병 | `paralysis_vial` | 무기에 마비 (B6-03) |
| 7 | 화염병 | `fire_vial` | 무기에 화염 (B6-03) |
| 8 | 화염 결정 | `fire_crystal` | 한 명에게 화염 피해 |
| 9 | 폭풍 결정 | `storm_crystal` | 전체에 피해 |

### 시작 인벤토리

`HDParty` 가 만들어질 때 가방에 몇 개를 넣는다 — **실험실과 게임이 같은 것**을 갖는다.

```
회복약 ×3 · 해독제 ×1 · 기력의 약 ×1 · 독병 ×2 · 마비병 ×1 · 화염병 ×1
```

가방은 20칸이라 9칸을 쓴다. 시작 파티가 **바를 것과 마실 것을 한 번씩은 써 볼 수 있는**
양이다. 세이브에서 올라온 파티는 세이브의 가방을 따른다 — 시작 인벤토리는 새 게임에만.

### 전투 → RPG 왕복

- `assembleSetup` 이 가방을 훑어 `held: {전투 키: 개수}` 를 채운다
- `applyOutcome` 의 `_consume` 이 `consumedItems` 만큼 가방에서 뺀다
- 전투 키 ↔ `HDItemId` 대응은 소비품 카탈로그 한 곳에 있다

## 결과 (2026-09-06)

| 파일 | 무엇 |
|---|---|
| `domain/item/item_type.dart` | `consumable(12)` — 부위 없음, 원작 네 범위 밖 |
| `domain/item/consumable_data.dart` | 손으로 쓴 카탈로그 10종 · `startingBackpack()` |
| `domain/item/item_lookup.dart` | `lookupItem` — 생성 표 + 소비품 표 |
| `application/game_session.dart` | **새 게임에서만** 가방을 채운다. `HDParty()` 자체는 비어 있다(테스트가 고정) |
| `battle_bridge/setup_assembly.dart` | `heldConsumables` → `BattleSetup.consumables` · `_consume` 이 실제로 뺀다 |
| `equipment_flow.dart` · `script_engine_adapter.dart` | 가방을 읽는 곳이 `lookupItem` 을 쓴다 |

생성 파일 `item_data.dart` 는 **바뀌지 않았다.**
`test/application/battle_bridge/consumables_test.dart` 9개 — 전투 표 ↔ 카탈로그가
양방향으로 빠짐없이 대응된다는 것까지.

## 완료 판정 기준

- [x] `HDItemType.consumable` 의 와이어 값 12 가 테스트로 고정된다
- [x] 생성 파일 `item_data.dart` 가 **바뀌지 않는다**
- [x] 새 파티가 위 아이템을 들고 시작한다 · 세이브에서 온 파티는 아니다
- [x] 전투에서 쓴 물건이 **실제로 가방에서 빠진다** (`_consume` 이 비어 있지 않다)
- [x] 소지품 화면에 소비품이 이름으로 보인다

## 하지 않을 것

상점 · 드랍 · 아이템 가격 · 가방 용량 변경.
