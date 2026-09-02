# 아이템·인벤토리 시스템 신설

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-42 · **상태**: 초안 · **선행 문서**: [BP-40](40_gameplay_changes.md), [BP-22 §6](22_world_bible_model.md), [BP-25](25_world_state_and_save.md), [BP-41](41_journal_ui_spec.md)
> **독자**: 런타임 구현자 · 콘텐츠 저작자 · 밸런스 담당
> **한 줄 요약**: `food:int` + `gold:int` 둘뿐인 소지품에 **실제 아이템**을 세우고, 원작 톤의 초기 20종을 실제 수치로 확정하며, `item_gained`/`item_lost` 의 **첫 발행 지점**을 만든다.

**파이프라인 구획**(D-01): 아이템 **카탈로그**는 Authoring(콘텐츠 팩), **인벤토리 규칙과 UI**는 Runtime 이다.
런타임에 카탈로그를 생성하지 않는다.

---

## 0. 이 장의 범위

| 항목 | 내용 |
|---|---|
| **이 장이 소유하는 것**(D-18) | 아이템 **실제 데이터**(20종 카탈로그의 값·성능·설명) · 인벤토리 **게임 규칙**(스택·용량·정렬·장착·버리기) · **장비 마이그레이션**(정수 ID → 아이템 ID) · 소지품 UI · `item_gained`/`item_lost` 발행 지점 |
| **이 장이 소유하지 않는 것** | 아이템 **스키마**(→ [BP-22 §6](22_world_bible_model.md)) · `WorldState.inventory` 필드·세이브 봉투(→ [BP-25](25_world_state_and_save.md)) · Effect/Condition DSL(→ [BP-21 §6](21_content_pack_spec.md)) · 월드 이벤트 이름 집합(→ [BP-23 §23.11](23_quest_model.md), D-20) · 저널 UI(→ [BP-41](41_journal_ui_spec.md)) · 문체(→ [BP-43](43_content_style_guide.md)) |
| **근거 결정** | D-05(`has_item`/`give_item`/`take_item`), D-06(`acquire`/`deliver`), D-16-2, D-20 |

- **R-42-1** 이 장은 스키마를 **한 필드도 새로 정의하지 않는다.** [BP-22 §6.1](22_world_bible_model.md) 의
  15개 필드가 전부이며, 이 장은 그 필드에 **넣을 값**과 **그 값이 게임에서 어떻게 동작하는가**만 정한다.

---

## 1. 현황 실측

### 1.1 인벤토리는 정수 두 개다

```dart
// hadar2026_app/lib/domain/party/party.dart:13
class PartyInventory {
  int food = 100;
  int gold = 500;
}
```

`HDParty` 가 노출하는 것은 `food`/`gold` getter·setter 뿐이고,
`toJson()`/`fromJson()` 도 그 둘만 실어 나른다. **아이템 목록이라는 개념 자체가 없다.**

### 1.2 장비는 정수 3개, 이름은 플레이스홀더

```dart
// hadar2026_app/lib/domain/party/player.dart:44-50
int weapon = 0;   int shield = 0;   int armor = 0;
int powOfWeapon = 0;  int powOfShield = 0;  int powOfArmor = 0;
```

```dart
// hadar2026_app/lib/domain/party/player.dart:91-93
String getWeaponName() => weapon == 0 ? "맨손"   : "무기$weapon";
String getShieldName() => shield == 0 ? "없음"   : "방패$shield";
String getArmorName()  => armor  == 0 ? "평상복" : "갑옷$armor";
```

`HDMenuFlows.showCharacterStatus()` 가 이 값을 그대로 찍는다 —
화면에 **"사용 무기 - 무기1"**, **"방패 - 방패0        갑옷 - 갑옷1"** 이 나온다.

### 1.3 `powOfShield` / `powOfArmor` 는 **아무 규칙도 읽지 않는 죽은 필드다** (신규 실측)

`lib/` 전체 grep 결과, 두 필드를 참조하는 곳은 **선언·직렬화·`getAttribute`/`changeAttribute` 뿐**이고
**전투 계산식에는 한 번도 등장하지 않는다.**

| 필드 | 읽는 게임 규칙 |
|---|---|
| `powOfWeapon` | `battle.dart:439` — `damage = (strength × powOfWeapon × level.physical) ÷ 20` |
| `ac` | `battle.dart:441`(적 방어), `battle.dart:514`(파티 방어) |
| **`powOfShield`** | **없음** |
| **`powOfArmor`** | **없음** |

→ 방어력을 결정하는 것은 **`ac` 하나뿐**이다. 갑옷·방패를 도입할 때 `powOfArmor`/`powOfShield` 에
값을 넣어 봐야 게임은 아무 반응도 하지 않는다(§4.3).

### 1.4 `assets/maps/books.json` — 미사용 아이템 데이터 (직접 읽음)

1,506바이트, 탭 들여쓰기, 최상위 키 2개(`weapon`, `armor`). **앱 코드 어디에서도 로드하지 않는다**
(`grep books.json lib/` → 0건). 맵 디렉토리에 놓인 것 자체가 오분류다.

**`weapon` 5항목**

| 배열 idx | `id` | `name` | `type` | `power` | `etc_data` | `etc_description` |
|---|---|---|---|---|---|---|
| 0 | 1 | 맨손 | `NONE` | 1.0 | `[1,2,3,4]` | `brief[0]` 에 **실제 설명문**(`img_fist` + 90자 한국어) |
| 1 | 2 | 단도 | `STAB` | 5.0 | `[1,2,3,4]` | `{"image":"img","text":"txt"}` — **더미** |
| 2 | 3 | 단검 | `WIELD` | 15.0 | `[1,2,3,4]` | 더미 |
| 3 | 4 | 단창 | `STAB` | 20.0 | `[1,2,3,4]` | 더미 |
| 4 | 5 | 작은도끼 | `CHOP` | 22.0 | `[1,2,3,4]` | 더미 |

**`armor` 3항목**

| 배열 idx | `id` | `name` | `ac` |
|---|---|---|---|
| 0 | 0 | 맨몸 | 0.0 |
| 1 | 1 | 두꺼운옷 | 10.0 |
| 2 | 2 | 가죽갑옷 | 20.0 |

**읽어 낸 사실 4가지**

| # | 사실 | 의미 |
|---|---|---|
| B-1 | `power`/`ac` 가 **실수**(`5.0`, `10.0`) | [BP-21 §8](21_content_pack_spec.md) 이 부동소수를 금지하므로 정수로 반올림해 흡수 |
| B-2 | `weapon` 은 id 1부터, `armor` 는 id 0부터 | 두 배열의 기수가 다르다. 통합 정수 공간이 아니라는 증거 |
| B-3 | `type` 이 `NONE/STAB/WIELD/CHOP` | 원작 `ITEM_TYPE` 계열. [BP-22 §6.2](22_world_bible_model.md) `equip.weaponType` 로 흡수 |
| B-4 | `etc_data`/`etc_description` 이 **1항목 빼고 전부 더미** | 설명문 시스템을 만들다 만 흔적. 신규 카탈로그의 `desc` 가 이 자리를 대체 |

### 1.5 `books.json` 의 id 는 `HDPlayer.weapon` 의 정수 공간이 **아니다** (중요)

```dart
// hadar2026_app/lib/domain/party/party.dart:104-108  (슴갈)
p.weapon = 1;      // Short Sword     ← books.json id 1 은 "맨손"
p.powOfWeapon = 12;
p.armor = 1;       // Leather Armor   ← books.json armor id 1 은 "두꺼운옷"
p.powOfArmor = 5;
p.ac = 5;
```

| 관찰 | 결론 |
|---|---|
| 코드 주석은 `weapon=1` 을 "Short Sword", `armor=1` 을 "Leather Armor" 로 부른다 | `books.json` 의 맨손/두꺼운옷과 **다르다** |
| `assets/L1_ep1d0.cm2` 는 `Player::ChangeAttribute(1,"weapon",3)`, `"shield",5`, `"armor",3` 을 쓴다 | `shield` 는 `books.json` 에 배열조차 없다 |
| `assets/menace.cm2` 는 `weapon/shield/armor` 를 전부 0 으로 리셋한다 | 0 = "없음" 만이 유일하게 합의된 값 |

→ **정수 장비 ID 공간은 정의된 적이 없다.** 유일한 근거는 코드 주석이고, 그 주석은 `books.json` 과 충돌한다.
따라서 §4.2 의 마이그레이션 표는 "발굴" 이 아니라 **선언**이다 — 어떤 데이터도 이 매핑에 의존하지 않으므로
지금 정하면 그것이 정본이 된다.

### 1.6 이것 때문에 죽어 있는 콘텐츠 표현 (D-16-2 재확인)

| 죽은 것 | 소유 |
|---|---|
| `Objective.kind = acquire(itemId, count)` | [BP-23](23_quest_model.md) |
| `Objective.kind = deliver(itemId, actorId)` | [BP-23](23_quest_model.md) |
| `Condition op = has_item(id, count?)` | [BP-21 §6](21_content_pack_spec.md) |
| `Effect do = give_item(id, count?)` / `take_item(id, count?)` | [BP-21 §6](21_content_pack_spec.md) |
| 월드 이벤트 `item_gained` / `item_lost` | [BP-23 §23.11](23_quest_model.md), D-20 |

원작은 이 자리를 **플래그로 흉내** 냈다 — `assets/L1_ep1d0.cm2` 의
`Flag::Set(GFD0_GET_KEY_FOR_D1)`(`:134`, "경비병의 열쇠"), `Flag::Set(GFD0_GET_WALL_REMOVER)`("지형 변화의 아이템").
화면에 `@B[경비병이 가지고 있던 열쇠+1]@@`(`:131`) 이라고 **적어 놓고 실제로는 아무것도 늘지 않는다.**

### 1.7 파티 버프 8종 중 **런타임이 읽는 것은 3종뿐이다** (신규 실측)

아이템 효과를 설계하기 전에 반드시 알아야 하는 실측이다. `PartyBuffs`(`lib/domain/party/party.dart:18-27`)에
필드가 8개 있는데, **그중 5개는 어떤 게임 규칙도 읽지 않는다.**

```dart
// hadar2026_app/lib/domain/party/party.dart:18-27
class PartyBuffs {
  int magicTorch = 0;   int levitation = 0;
  int walkOnWater = 0;  int walkOnSwamp = 0;
  int mindControl = 0;  int penetration = 0;
  bool canUseEsp = false;  bool canUseSpecialMagic = false;
}
```

`grep -rn "<필드명>" hadar2026_app/lib` 를 8회 돌린 결과:

| 필드 | 세우는 곳 | **읽어서 동작을 바꾸는 곳** | 판정 |
|---|---|---|---|
| **`magicTorch`** | `magic_system.dart:89`(마법 33 `+= 10`) | **`sight_calculator.dart:47,48,75`** — 어둠 속 시야 거리와 `inMoonlight` | ✅ **살아 있다** |
| **`walkOnWater`** | `magic_system.dart` | **`tile_properties.dart:112`**(`ixTile == 56 && walkOnWater > 0`), 소비는 `tile_event_dispatcher.dart:82-83`, 전달은 `player_sprite.dart:292` | ✅ **살아 있다** |
| **`canUseEsp`** | cm2 / 세이브 | **`magic_system.dart:118`**(`level.esp == 0 && !canUseEsp` → 사용 거부) | ✅ **살아 있다** |
| `levitation` | `magic_system.dart:92` | 없음 — `menu_flows.dart:199` 가 숫자를 **찍기만** 하고 `party_actions.dart:106` 이 0으로 리셋 | ❌ 죽음 |
| `walkOnSwamp` | — | 없음 — `menu_flows.dart:201` 표시 + `party_actions.dart:107` 리셋 | ❌ 죽음 |
| `mindControl` | — | 없음 — `party_actions.dart:109` 리셋뿐. 표시조차 없다 | ❌ 죽음 |
| `penetration` | — | **`party.dart` 밖에 참조 0건** | ❌ 죽음 |
| `canUseSpecialMagic` | — | **`party.dart` 밖에 참조 0건** | ❌ 죽음 |

- **R-42-0** 아이템 효과가 "버프" 를 준다고 쓰려면 **위 3종(`magicTorch`/`walkOnWater`/`canUseEsp`) 중 하나**여야 한다.
  나머지 5종에 값을 넣는 것은 §1.3 의 `powOfArmor` 와 같은 종류의 자기기만이다.
- **그런데 v1 DSL(D-05)의 22 do 에 버프를 세우는 것이 하나도 없다.** `set_flag`/`add_var` 는
  `WorldState` 를 만지고 `PartyBuffs` 는 `HDParty` 안에 있어 **다리가 없다.** 이 다리는 어느 장에도 설계되어 있지 않다.
  → §3.3 과 §7.4 가 이 사실에 묶인다. 다리 요청은 §9.2 로 [BP-27](27_runtime_engine.md) 에 넘긴다.

---

## 2. 인벤토리 데이터 모델

### 2.1 저장소는 하나뿐 — `WorldState.inventory`

`Map<itemId, int>`. 필드 정의·불변식(`INV-3`: 값 ≥ 1, 0이면 키 제거)·직렬화는
[BP-25 §2.1](25_world_state_and_save.md) 이 소유한다. 이 장은 **링크만** 한다.

- **R-42-2** 인벤토리 저장소를 **새로 만들지 않는다.** `PartyInventory` 에 `Map` 을 추가하지 않고,
  `HDNativeScriptRunner` 에도 두지 않는다. 3중 분열(GROUND_TRUTH §8)을 아이템으로 재생산하지 않기 위해서다.

### 2.2 파티 공용이다 — 개인 소지는 없다

| 항목 | 소유 주체 | 근거 |
|---|---|---|
| 소모품·열쇠·퀘스트 아이템·유물·크리스탈 | **파티 공용** (`WorldState.inventory`) | 원작 `PARTY_ITEM`/`PARTY_CRYSTAL`/`PARTY_RELIC` 이 전부 파티 단위 |
| **장착 중인** 무기·방패·갑옷 | **개인** (`HDPlayer.equipped*`) | 인물마다 다른 것을 든다 |
| `food` / `gold` | 파티 코어 값 (`PartyInventory`) | 아이템화하지 않는다([BP-40](40_gameplay_changes.md) F-9) |

- **R-42-3** "누가 들고 있는가" 를 묻지 않는다. 6인 파티에서 소지자를 관리하면
  `has_item` 조건이 "누가" 를 되묻게 되고 DSL(D-05)이 닫힌 집합을 벗어난다.

**반대 심문: 파티 6인 개인 소지품이면 UI 가 감당 가능한가 / 공용이면 원작과 어긋나지 않는가**

두 방향 모두 답이 필요한 질문이므로 여기서 닫는다.

| 축 | 개인 소지품(6인 각각) | **공용 소지품(채택)** |
|---|---|---|
| 화면 예산 | 인물 선택 단계가 **한 겹 더** 붙는다: `소지품 → 누구의 → 목록 → 다루기`. 창은 (144,40) 512×400 **하나**뿐이고([BP-41 R-41-8](41_journal_ui_spec.md)) 본문이 19행이므로, 6인 탭을 1행에 얹으면 카테고리 탭 7개와 **같은 행을 다툰다** | 탭 1줄로 끝난다(§5.1) |
| 키 예산 | 인물 축이 늘어 ←→ 가 이미 카테고리 탭에 쓰이므로 **새 키가 필요**해진다 — [BP-40 §40.1.4](40_gameplay_changes.md) 의 "신규 키 0" 예산 위반 | ←→ 탭 / ↑↓ 항목으로 닫힌다 |
| 옮기기 | "슴갈 → 유리에게 회복약 건네기" 라는 조작이 새로 생긴다. 그 조작이 `item_gained`/`item_lost` 를 발행해야 하는지가 애매해지고, 발행하면 `acquire` 카운터가 **파티 내부 이동으로 헛돈다** | 옮기기 자체가 없다 |
| DSL | `has_item` 이 "누가" 를 되묻는다(R-42-3) | 닫힌 집합 유지 |
| **원작 정합** | — | 원작이 이미 공용이다: `PARTY_ITEM`/`PARTY_CRYSTAL`/`PARTY_RELIC` 이 전부 파티 단위이고, `HDParty.food`/`gold`(`party.dart:14-15`) 도 파티 값이다 |

- **R-42-3a** 즉 **공용이 원작과 어긋나는 쪽이 아니라, 개인 소지품이 원작에 없던 것을 들여오는 쪽**이다.
  원작에서 인물마다 달랐던 것은 **장착 중인 장비**뿐이고, 그것은 §2.3 이 `equipped*` 로 개인 소유로 남겼다.
  따라서 "공용 소지품 + 개인 장비" 는 타협이 아니라 원작 구조의 그대로다.

### 2.3 장착과 인벤토리의 관계 — **장착해도 가방에서 빠지지 않는다**

```
WorldState.inventory: { "item.core.short_sword": 2, "item.core.leather_armor": 1 }
HDPlayer[0].equippedWeapon = "item.core.short_sword"
HDPlayer[1].equippedWeapon = "item.core.short_sword"   ← 2개 있으므로 둘 다 가능
HDPlayer[0].equippedArmor  = "item.core.leather_armor"
HDPlayer[1].equippedArmor  = null                       ← 1개뿐이라 불가
```

| # | 규칙 |
|---|---|
| **R-42-4** | `equipped*` 는 인벤토리 항목을 **가리키는 참조**다. 장착이 `inventory` 의 수를 줄이지 않는다 |
| **R-42-5** | **불변식 EQ-1**: 모든 `equipped*` 값은 `inventory` 에 존재해야 한다. 세이브 로드 시 위반이면 해당 슬롯을 `null` 로 강등하고 progress 로그에 1줄 남긴다 |
| **R-42-6** | **불변식 EQ-2**: 같은 `itemId` 를 장착한 인물 수 ≤ `inventory[itemId]`. 장착 시점에 검사하고, 초과하면 `"단검이 하나뿐입니다."` 로 거부 |
| **R-42-7** | 버리기·건네기(`take_item`)가 EQ-2 를 깨뜨리게 되면 **초과분을 자동 해제**한다. 해제 순서는 `order` **내림차순**(뒷사람부터) — 결정론 |
| **R-42-8** | `has_item(id, count)` 은 **`inventory` 만** 본다. 장착 여부와 무관하게 참이다 |

**왜 이 방식인가**

| 대안 | 문제 |
|---|---|
| 장착 시 인벤토리에서 제거 | `has_item("단검")` 이 장착하면 거짓이 된다. "단검을 가져오라" 퀘스트가 장착 여부에 따라 갈린다 |
| 장착 아이템을 별도 목록으로 | 저장소가 둘로 늘어 R-42-2 를 깬다 |
| **채택: 참조 방식** | 저장소 하나, `has_item` 단순, 불변식 2개로 정합 유지 |

### 2.4 스택·용량·정렬

| 축 | 규칙 | 근거 |
|---|---|---|
| **스택** | `stackable:true` 면 같은 `itemId` 를 수량으로 합친다. 상한은 `maxStack`(기본 99) | [BP-22 §6.1](22_world_bible_model.md) |
| **비스택** | `stackable:false` 는 보유 수량 0 또는 1. 두 번째 획득은 **조용히 버려지지 않고** 경고 로그 + 이벤트 미발행 | R-42-10 |
| **종류 상한** | **48종**([BP-40](40_gameplay_changes.md) RK-40-6). 단 `quest`/`key`/`relic` 은 **상한 밖**(R-42-11) | 세이브 크기: 48 × ~34B ≈ 1.6KB([BP-25 §257](25_world_state_and_save.md)) |
| **정렬** | ① `category` 고정 순서 ② 같은 category 안에서 `itemId` **사전순** ③ 가상 항목은 각 슬롯 탭 맨 위(R-42-9a) | 결정론(D-01). 획득 순서로 정렬하면 세이브에 순서 필드가 필요해진다 |

**category 고정 순서** (소지품 화면의 탭 순서이기도 하다)

```
1 consumable  2 weapon  3 shield  4 armor  5 key  6 quest  7 relic  8 crystal  9 lore
```

- **R-42-9** 정렬 키에 **표시명(한국어)을 쓰지 않는다.** 문자열 정렬은 로케일에 의존하고,
  `strings/ko.json` 이 바뀌면 순서가 바뀐다. `itemId` 는 불변이다(D-04).
- **R-42-9a** **가상 항목 예외.** `맨손`/`평상복`/`없음`(R-42-42)은 `itemId` 가 없으므로 사전순에 자리가 없다.
  이들은 정렬 대상이 **아니고**, `weapon`/`shield`/`armor` 탭의 **0번 행에 고정**된다. 커서 초기 위치는 1번 행(첫 실제 아이템)이다.
- **R-42-10** 비스택 중복 획득 또는 상한 초과 시:
  획득을 **거부**하고 `@C소지품이 가득 찼다.@@` 를 progress 로그에 남기며 `item_gained` 를 **발행하지 않는다**.
  "받은 척하고 사라지는" 동작은 퀘스트 목표를 조용히 망가뜨린다.

**반대 심문: 퀘스트 아이템을 버릴 수 없다면 가방이 가득 찼을 때 무슨 일이 일어나는가**

- 초판은 "거부" 로 답하고 `Q-42-7` 에 "1차 스코프에서 발생 불가(카탈로그 20종)" 라고 적었다. **그 답은 틀렸다.**
  1. **거부해도 퀘스트는 똑같이 망가진다.** `give_item` 이 0을 반환하고 이벤트가 없으면
     `acquire`/`deliver` 목표는 **영원히 진행되지 않는다.** 로그 한 줄이 남을 뿐이고 플레이어는 그 물건이 어느 임무에 필요한지 모른다.
  2. **버릴 수 없는 카테고리가 상한을 잠식한다.** `quest`/`key`/`relic` 은 R-42-16·17 로 버리기·매매가 막혀 있으므로,
     이들이 48칸을 채우면 **자력 복구가 불가능한 상태**가 된다.
  3. **D-26 이 이 실패 양식을 잡지 못한다.** D-26 의 `SUPPORTED` 축은 "그 경로가 의존하는 모든 월드 이벤트에
     **발행 지점이 존재하는가**" 만 본다. 발행 지점은 있는데 **런타임 조건 때문에 발행되지 않는** 경우는
     레지스트리 대조로 걸리지 않는다 — `PROVEN + SUPPORTED` 를 받은 임무가 런타임에서 막힐 수 있다.
  4. **카탈로그 크기는 방어선이 아니다.** 팩 합성(D-03: `core` + `gen_ep1` 겹쳐 쓰기)이 아이템을 더하는 순간 20종 전제는 깨진다.

- **R-42-11** 따라서 **`quest`/`key`/`relic` 은 48종 상한에서 제외**한다. 상한은
  `consumable`/`weapon`/`shield`/`armor`/`crystal`/`lore` 6개 카테고리의 **종류 수 합계**에만 적용된다.
  - 근거: R-42-11 의 취지는 **세이브 팽창 방어선**이다. 버릴 수 없는 3개 카테고리는 콘텐츠 팩이 선언한 유한 집합이고
    플레이어가 반복 획득으로 늘릴 수 없으므로(비스택·`unique`), 팽창의 원인이 아니다.
  - 비용: 상한 검사가 `inventory.length >= 48` 에서 `countCapped() >= 48` 로 바뀐다(§8.3). 다른 규칙 변화 없음.
- **R-42-11a** 남는 실패 경로(6개 카테고리가 실제로 48종을 채움)는 **빌드가 미리 막는다.**
  "한 팩 합성 결과의 상한 대상 카테고리 종류 수 ≤ 48" 을 검사하는 규칙을 [BP-33](33_validation_and_lint.md) 에 요청한다(§9.2).
  런타임 거부는 그 뒤에 남는 **최후 방어선**이며, 상한 밖 카테고리는 거부 대상이 아니다.
- **R-42-11b** UI 에 잔여 칸을 표시하지 **않는다.** 상한이 게임 규칙이 아니라 방어선이므로 세는 화면을 만들면
  플레이어가 관리해야 하는 예산처럼 보인다([BP-40 §40.6.2](40_gameplay_changes.md) 의 "상시 HUD 를 만들지 않는다" 와 같은 정신).

### 2.5 획득·소실의 단일 통로

```
Effect give_item / take_item          ┐
container 앵커의 contents             ├──▶ MutableWorldState.giveItem / takeItem ──▶ inventory 변경
퀘스트 rewards 의 give_item           │                     │
아이템 사용(소모)                      ┘                     └──▶ 월드 이벤트 발행 (§8)
```

- **R-42-12** 인벤토리를 바꾸는 코드 경로는 `MutableWorldState.giveItem`/`takeItem`
  **단 두 함수**뿐이다([BP-27 §7.5](27_runtime_engine.md)). UI·전투·스크립트가 `inventory` 맵을 직접 만지지 않는다.
- **R-42-13** cm2 는 아이템을 다루지 않는다([BP-40](40_gameplay_changes.md) R-40-7). `Item::Give` 같은 신규 커맨드를 만들지 않는다.
  레거시 cm2 의 "열쇠" 는 플래그로 남고, 이관 시 [BP-28](28_migration_and_coexistence.md) 이 아이템으로 바꾼다.

---

## 3. 분류별 동작

### 3.1 9종 카테고리 동작표

| category | 스택 | 사용 | 장착 | 버리기 | 매매 | 완료 시 회수 | 소지품 탭 |
|---|---|---|---|---|---|---|---|
| `consumable` | ✅ | **✅** | ❌ | ✅ | ✅ | ❌ | 소모품 |
| `weapon` | ❌ | ❌ | **✅**(weapon 슬롯) | ✅ | ✅ | ❌ | 무기 |
| `shield` | ❌ | ❌ | **✅**(shield 슬롯) | ✅ | ✅ | ❌ | 방패 |
| `armor` | ❌ | ❌ | **✅**(armor 슬롯) | ✅ | ✅ | ❌ | 갑옷 |
| `key` | ❌ | ❌ | ❌ | **❌** | **❌** | ❌ | 열쇠 |
| `quest` | 선언에 따름 | ❌ | ❌ | **❌** | **❌** | **✅** | 물건 |
| `relic` | ❌ | ❌ | ❌ | **❌** | **❌** | ❌ | 물건 |
| `crystal` | ✅ | ❌(v1) | ❌ | ❌ | ❌ | ❌ | 물건 |
| `lore` | ❌ | **읽기** | ❌ | ✅ | ✅ | ❌ | 기록 |

- **R-42-14** `tradable`/`droppable` 의 **기본값은 [BP-22 §6.1](22_world_bible_model.md) 이 정한 유도식**을 따른다
  (`tradable` = `category != quest && != key`, `droppable` = `!(quest|key)`).
  위 표의 `relic`/`crystal` 은 **개별 아이템이 명시적으로 `false` 를 선언**해서 막는다 — 스키마를 바꾸지 않는다.
- **R-42-15** `lore` 아이템의 "읽기" 는 대화 그래프를 여는 것이 아니라 **`desc` 를 전문으로 보여 주는 것**이다.
  대화를 열면 [BP-24 §24.7.3](24_dialogue_model.md) 의 꼬리 호출 규칙이 메뉴 컨텍스트에서 성립하지 않는다.

### 3.2 퀘스트 아이템 특수 규칙 (`category: "quest"`)

| # | 규칙 | 이유 |
|---|---|---|
| **R-42-16** | 버릴 수 없다. 소지품 화면에서 `[버리기]` 가 **비활성**이며 사유를 한 줄로 보여 준다: `이 물건은 버릴 수 없다.` | 버리면 퀘스트가 완주 불가가 되고, 솔버(D-13)의 완주 증명이 런타임에서 거짓이 된다 |
| **R-42-17** | 팔 수 없다(`tradable:false` 강제). 상점이 생겨도 목록에 안 뜬다 | 동상 |
| **R-42-18** | `effects` 가 비어 있어야 한다([BP-22 R-22-19](22_world_bible_model.md)). 따라서 "사용" 이 없다 | 퀘스트 아이템은 조건 재료다 |
| **R-42-19** | **완료 시 회수** — 퀘스트가 `completed` 또는 `failed` 로 전이할 때, 그 퀘스트의 `onComplete`/`onFail` 이 `take_item` 을 **명시적으로** 적으면 회수한다. 런타임이 자동으로 뒤지지 않는다 | 자동 회수는 "어떤 퀘스트가 이 아이템을 쓰는가" 역참조를 런타임에 요구한다. 명시가 결정론적이고 검증 가능하다 |
| **R-42-20** | 회수를 안 적으면 **린트 경고**: 어떤 `acquire`/`deliver` 목표가 요구한 `quest` 아이템이 완료 후에도 남으면 `가방에 죽은 물건이 쌓입니다`. 소유는 [BP-33](33_validation_and_lint.md) | R-42-19 가 자동 회수를 거부한 대가다. 런타임에 넣지 않은 검사는 빌드가 대신 본다 |
| **R-42-21** | 회수 대상이 없어도(플레이어가 이미 잃었어도) `take_item` 은 **실패하지 않는다.** 0 이하로 내려가면 키를 제거하고 끝. 보상 지급 중 예외가 나면 퀘스트가 완료 상태로 못 간다 | [BP-25 INV-3](25_world_state_and_save.md) |

### 3.3 소모품의 즉시 효과 — v1 에서 실제로 되는 것

[BP-22 G-22-2](22_world_bible_model.md) 가 지적한 대로 원작 소비품 효과 상당수에 대응하는 `do` 가 v1 DSL 에 없다.
**이 장은 DSL 을 늘리지 않는다.** v1 에서 실제로 동작하는 소모품과 그렇지 않은 것을 **분리**한다.

**판정 축이 하나가 아니라 둘이다.** "do 가 있는가" 와 "그 do 의 결과를 플레이어가 볼 수 있는가" 는 다른 질문이고,
초판은 이 둘을 섞어 `set_flag`/`add_var` 를 "✅ 동작" 으로 분류했다 — R-42-23 이 스스로 금지한 것을 카탈로그가 하게 된 원인이다.

| 효과 | v1 do | ① do 존재 | ② 런타임 착지점 | ③ **플레이어 관측** |
|---|---|---|---|---|
| HP 회복 | `heal_party(percent)` | ✅ | `HDPlayer.hp` | ✅ 상태 패널 HP 숫자 |
| 식량 | `add_food(delta)` | ✅ | `HDParty.food`(`party.dart:14`) | ✅ 상태·소지품 18행 |
| 황금 | `add_gold(delta)` | ✅ | `HDParty.gold`(`party.dart:15`) | ✅ 동상 |
| 경험치 | `grant_exp(amount)` | ✅ | `HDPlayer.experience` + `checkLevelUp()`(`player.dart:164`) | ✅ 레벨업 로그 |
| 이동 | `warp(map,x,y)` ([BP-22 R-22-20](22_world_bible_model.md) 예외) | ✅ | 맵 전환 | ✅ 화면이 바뀐다 |
| 지형 변화 | `change_tile(map?,x,y,tile)` | ✅ | `MapUnit` | ✅ 벽이 열린다 |
| 전투 개시 | `start_battle(encounterId)` | ✅ | 전투 창 | ✅ |
| 임무·저널 | `start_quest`/`advance_quest`/`complete_quest`/`fail_quest`/`journal` | ✅ | `WorldState.quests`/`.journal` | ✅ 저널 화면([BP-41](41_journal_ui_spec.md)) |
| 플래그·변수 | `set_flag` / `clear_flag` / `set_var` / `add_var` | ✅ | `WorldState.flags`/`.vars` | ⚠️ **콘텐츠가 그 값을 조건으로 읽을 때만.** 값 자체를 보여 주는 화면이 없다 |
| **버프 부여** | **없음** | ❌ | (`PartyBuffs` — 다리 없음, §1.7) | ❌ |
| SP/ESP 회복 · 해독 · 의식 회복 · 부활 | **없음** | ❌ | — | ❌ |

- **R-42-22** v1 카탈로그는 **③ 관측 가능한 효과만 가진 소모품**을 넣는다.
  해독·부활·버프 아이템은 `effects: []` 로 두지 않는다 — 그러면 [BP-22 R-22-18](22_world_bible_model.md)
  (효과 없는 소비품 금지)에 걸린다. 대신 **`category: "quest"`/`"key"` 로 두거나 카탈로그에서 뺀다**.
- **R-42-23** §7 의 카탈로그는 해독·의식·부활·시야·평판을 **`set_flag`/`add_var` 로 표현하지 않는다.**
  플래그로 흉내 내는 것이 바로 지금 고치려는 문제다(§1.6). 대신 `Q-42-1` 로 남기고
  DSL 확장(`schemaVersion` 승격) 뒤에 정식 효과를 붙인다.
- **R-42-23a** 더 강하게 못박는다: **v1 카탈로그의 어떤 아이템도 `effects` 에 `set_flag`/`clear_flag`/`set_var`/`add_var`
  를 단독으로 쓰지 않는다.** 이유는 세 가지다.
  1. 위 표 ③열대로 **아이템만으로는 관측 가능한 결과가 0** 이다. 그 플래그를 읽는 Condition 이 같은 팩 안에 있어야 하는데,
     그것은 **아이템의 성질이 아니라 그 팩의 콘텐츠 배치**다 — 카탈로그가 약속할 수 없는 것을 약속하게 된다.
  2. `flag.core.party.torch_lit` / `farsight` 처럼 **런타임 기능을 흉내 내는 이름**을 쓰게 되고,
     그 이름을 본 다음 사람이 "횃불은 이미 아이템으로 된다" 고 오해한다(실제 횃불은 `PartyBuffs.magicTorch`, §1.7).
  3. 평판은 [BP-40 §40.5.2](40_gameplay_changes.md) 가 **표시(UI 0)와 분기(Soft 경고)를 둘 다 막았다.**
     `add_var(reputation_lore, 1)` 은 v1 에서 관측·분기 어느 쪽으로도 나갈 길이 없다.
  - **예외**: `quest`/`key` 아이템은 `effects` 가 비어 있고(R-42-18), 플래그는 **그 아이템을 소비하는 쪽**
    (대화 노드·트리거 앵커)이 세운다. 그쪽에는 `has_item` 조건이 함께 있으므로 ③이 성립한다.
- **R-42-23b** `set_encounter`/`set_npc_state`/`unlock_place`/`play_dialogue` 는 do 가 있고 착지점도 있으나
  **아이템 효과로는 쓰지 않는다** — 소모품 한 개가 조우율이나 NPC 상태를 바꾸면 되돌릴 방법이 없다.
  (금지가 아니라 v1 카탈로그의 자기 제약이다. 근거를 남겨 두어야 다음 카탈로그가 이유를 알고 푼다.)

---

## 4. 장비 시스템 연결

### 4.1 필드 확장 (`HDPlayer`)

```dart
// hadar2026_app/lib/domain/party/player.dart  — 추가
String? equippedWeapon;   // item id | null(맨손)
String? equippedShield;   // item id | null(없음)
String? equippedArmor;    // item id | null(평상복)
```

기존 `int weapon/shield/armor` 는 **남긴다**([BP-40](40_gameplay_changes.md) RK-40-5).

| # | 규칙 |
|---|---|
| **R-42-24** | **표시는 아이템 ID 우선.** `getWeaponName()` 은 `equippedWeapon != null` 이면 카탈로그의 `name` 문자열 키를 해석하고, `null` 이면 기존 정수 폴백(`"무기$weapon"`)을 그대로 쓴다 |
| **R-42-25** | `Player::ChangeAttribute(n,"weapon",3)` 같은 cm2 경로는 **정수 필드만** 바꾸고 `equipped*` 는 건드리지 않는다. 즉 cm2 가 장비를 만지면 표시가 정수 폴백으로 **되돌아간다** — 그것이 옳다. 두 체계를 동시에 참으로 만들면 어느 쪽이 진실인지 알 수 없다 |
| **R-42-26** | 소지품 화면에서 장착하면 `equipped*` 를 세우고 **정수 필드도 함께 갱신**한다(`legacyItemMap` 역방향). cm2 가 `Player::GetAttribute("weapon")` 로 읽는 값이 계속 의미를 갖게 하기 위해서다 |

### 4.2 마이그레이션 표 — 정수 → 아이템 ID (**선언**, §1.5)

빌드가 `content.lock.json#legacyItemMap` 을 만든다([BP-22 §6.4](22_world_bible_model.md)).
아래가 그 내용의 정본이다.

**`weapon`**

| 정수 | → item id | 근거 |
|---|---|---|
| 0 | `null` (맨손) | `getWeaponName()` 의 유일한 합의된 값 |
| **1** | `item.core.short_sword` | `party.dart:104` 주석 `// Short Sword`. 슴갈의 `powOfWeapon=12` 가 이 아이템의 `power=15` 와 근사 |
| 2 | `item.core.dagger` | 선언 |
| 3 | `item.core.short_spear` | 선언. `L1_ep1d0.cm2` 가 3을 쓰지만 그때 `pow_of_weapon=100` 을 함께 주므로 표시만 바뀐다 |
| 4 | `item.core.hand_axe` | 선언 |
| 5 | `item.core.steel_sword` | 선언 |
| 6~255 | `null` + 경고 | 대응 없음. 정수 필드와 `powOfWeapon` 은 그대로 유지 |

**`armor`**

| 정수 | → item id | 근거 |
|---|---|---|
| 0 | `null` (평상복) | — |
| **1** | `item.core.leather_armor` | `party.dart:106` 주석 `// Leather Armor`. 슴갈의 `ac=5` 가 이 아이템의 `ac=5` 와 **정확히 일치** |
| 2 | `item.core.thick_clothes` | 선언 |
| 3 | `item.core.chain_mail` | 선언 |
| 4~255 | `null` + 경고 | — |

**`shield`**

| 정수 | → item id | 근거 |
|---|---|---|
| 0 | `null` (없음) | — |
| 1 | `item.core.wooden_shield` | 선언 |
| 2 | `item.core.iron_shield` | 선언 |
| 3~255 | `null` + 경고 | `L1_ep1d0.cm2` 의 `shield 5` 가 여기 걸린다 |

- **R-42-27** 매핑에 없는 정수는 **추측하지 않는다.** `null` + 경고 1줄이고, 표시는 정수 폴백이다.
- **R-42-28** `books.json` 의 `id` 는 이 표와 **무관하다**(§1.5). `books.json` 은
  `assets/_legacy/` 로 옮기고 폐기 예정으로 표시한다([BP-22 R-22-22](22_world_bible_model.md)) — **읽지 않는다.**

### 4.3 `powOfWeapon` / `ac` 와의 관계 (전투식 실측 기반)

**공격** (`battle.dart:439-441`)

```
damage  = (strength × powOfWeapon × level.physical) ÷ 20
damage -= (damage × rand(0..49)) ÷ 100          // 0~49% 감쇠
damage -= (t.ac × t.level × rand(1..10)) ÷ 10   // 적 방어
if (damage <= 0) → 빗나감 처리
```

**피격** (`battle.dart:513-514`)

```
damage  = (e.strength × e.level × rand(1..10)) ÷ 10
damage -= (t.ac × t.level.physical × rand(1..10)) ÷ 10
```

| # | 규칙 |
|---|---|
| **R-42-29** | 장착 시 `powOfWeapon ← equip.power`. **덮어쓴다.** 합산하지 않는다 |
| **R-42-30** | 장착 시 `ac ← equip(armor).ac + equip(shield).ac`. **합산한다.** `ac` 가 유일한 방어 수치이므로 방패가 의미를 가지려면 여기 더해져야 한다 |
| **R-42-31** | `powOfArmor` / `powOfShield` 에는 **표시용 사본**을 넣는다(각 슬롯의 `ac`). 게임 규칙은 이 값을 읽지 않으므로(§1.3) 넣어도 무해하고, `Player::GetAttribute("pow_of_armor")` 를 읽는 레거시 cm2 가 0 이 아닌 값을 보게 된다 |
| **R-42-32** | **`powOfArmor`/`powOfShield` 는 폐기 예정 필드다.** 신규 코드는 읽지 않는다. `player.dart` 선언 옆에 `// deprecated: 어떤 전투 규칙도 읽지 않음 (BP-42 §1.3)` 주석을 단다 |
| **R-42-33** | 해제 시 `powOfWeapon ← 0`, `ac ← 0`. 원작의 "맨손이면 거의 못 때린다" 를 유지한다(§7.3 근거) |
| **R-42-33a** | **R-42-30 의 전제**: `HDPlayer.ac` 는 **레벨업으로 성장하지 않는다.** 실측 — `player.dart` 에서 `ac` 를 쓰는 곳은 선언 · `assignFromEnemyData:234` · `getAttribute` · `changeAttribute` · 직렬화뿐이고 `checkLevelUp()`(`player.dart:164`) 은 `ac` 를 만지지 않는다. 따라서 장착 시 덮어써도 성장분이 사라지지 않는다. **`ac` 성장식이 도입되면 R-42-30 의 덮어쓰기를 "기본 ac + 장비 ac" 로 바꿔야 한다** |
| **R-42-33b** | cm2 가 `ac` 를 만지는 곳은 3줄뿐이고 전부 **소환 슬롯(플레이어 6번)을 0 으로 리셋**한다 — `menace.cm2:52`, `lore_ep1.cm2:122`, `town2.cm2:122`. 소환 슬롯은 장착 UI 대상이 아니므로(§5.4 는 `isValid()` 인 파티원만 나열) 실제 충돌은 없다 |

### 4.4 `books.json` 흡수안

| books.json | 신규 item id | `power`/`ac` 조정 | 근거 |
|---|---|---|---|
| 맨손 (power 1) | **아이템 없음** | — | `equippedWeapon == null` 이 곧 맨손 |
| 단도 (5.0) | `item.core.dagger` | `power: 5` | 그대로 |
| 단검 (15.0) | `item.core.short_sword` | `power: 15` | 그대로 |
| 단창 (20.0) | `item.core.short_spear` | `power: 20` | 그대로 |
| 작은도끼 (22.0) | `item.core.hand_axe` | `power: 22` | 그대로 |
| 맨몸 (ac 0.0) | **아이템 없음** | — | `equippedArmor == null` |
| 두꺼운옷 (ac 10.0) | `item.core.thick_clothes` | **`ac: 2`** | §7.3 — ac 10 이면 레벨 1 캐릭터가 Troll 의 공격에서 피해를 입는 턴이 **36%** 로 떨어진다(재척도 후 83%) |
| 가죽갑옷 (ac 20.0) | `item.core.leather_armor` | **`ac: 5`** | 슴갈의 현행 `ac=5`(`party.dart:108`)와 일치. ac 20 이면 Troll 피해 턴이 **16%** — 초반 전투가 성립하지 않는다 |

- **R-42-34** `books.json` 의 `ac` 척도는 `battle.dart` 의 방어식과 **호환되지 않는다.**
  값을 그대로 옮기면 초반 전투의 대부분 턴이 "방어했다" 로 끝난다(§7.3 의 전수 계산). **`power` 는 그대로, `ac` 는 재척도**한다.
  - 재척도의 근거는 **부록 H-2** 이며, 부록도 "무효화" 라는 표현만 쓰고 "항상" 을 쓰지 않는다.
    §7.3 이 확률·기댓값을 전수 계산해 그 강도를 확정한다.
- **R-42-35** `weaponType` 은 `books.json` 의 `type` 을 그대로 옮긴다(`NONE`→ 없음, `STAB`/`WIELD`/`CHOP`).
  v1 전투식은 `weaponType` 을 읽지 않으므로 **표시·서술 전용**이다. 그 사실을 `_summary` 에 남긴다.

### 4.5 부록 H-1 대응 — **전투식 변경은 무엇의 선행 과제인가**

GROUND_TRUTH **부록 H-1** 이 확정한 사실: `powOfWeapon`/`powOfShield`/`powOfArmor` 중
**전투식이 읽는 것은 `powOfWeapon` 하나**이고, 방어는 `ac` **하나뿐**이다(`battle.dart:513-514`).
부록 초판은 여기서 "아이템 시스템이 `powOfWeapon`/`powOfArmor` 를 장비 성능의 근거로 삼으려면 **전투식을 먼저 바꿔야 한다**" 고 적었다.
> **주**: 부록 초판은 `powOfWeapon` 까지 죽은 필드로 잘못 적었고, **본 절의 지적이 반영되어 정정되었다**(부록 H-1 정정판). 아래 A/B 갈래 구분이 이제 부록의 정본 서술과 일치한다.

**본 장의 답**: 두 갈래로 나뉘며, 한 갈래는 선행 과제가 **없고** 다른 갈래는 선행 과제가 **있다.**

| 갈래 | 설계 | 전투식 변경 필요? |
|---|---|---|
| **A. v1 (본 장이 확정하는 것)** | 무기 `power` → `powOfWeapon`(R-42-29) · 갑옷+방패 `ac` 합 → `ac`(R-42-30) | **불필요.** 두 필드가 이미 전투식이 읽는 유일한 두 자리다 |
| **B. 이 장이 하지 않는 것** | 방패를 `ac` 와 **별개 축**으로(막기 확률·피해 상한) · 무기 종류(`weaponType`)별 상성 · 방어구 부위별 감쇠 · 마법 방어 | **필요.** `battle.dart:439-441`·`:513-514` 두 식의 변경이 선행이며, 본 장은 착수하지 않는다 |

- **R-42-33c** 즉 **본 장은 전투식 변경을 선행 과제로 두지 않고 그 필요를 제거했다.**
  `ac` 합산(R-42-30)이 그 장치다 — 방패에 의미를 주기 위해 `powOfShield` 를 살리는 대신,
  이미 읽히고 있는 `ac` 에 더한다. 대가는 "방패와 갑옷이 같은 축이라 서로 대체 가능해진다" 는 것이고,
  R-42-55(방패 상승 폭은 갑옷의 절반 이하)가 그 대가를 관리한다.
- **R-42-33d** 반대로 **B 갈래를 원하는 장은 전투식 변경을 선행으로 명시해야 한다.** 그 사실을
  [BP-40 §40.1.2](40_gameplay_changes.md)(Freeze List F-6 전투 시스템)와 [BP-50](50_roadmap.md) 에 남긴다(§9.2).

#### 4.5.1 카탈로그 수치 유효/무효 판정표 (현행 식에 직접 대입)

§7.4 카탈로그가 아이템마다 적는 수치가 **현행 전투식·현행 런타임에 넣었을 때 실제로 무엇을 하는가**를 필드 단위로 검산한다.
"무효" 는 값이 틀렸다는 뜻이 아니라 **어떤 규칙도 그 값을 읽지 않는다**는 뜻이다.

| 카탈로그 필드 | 착지하는 코드 자리 | 그 자리를 읽는 규칙 | 판정 |
|---|---|---|---|
| `equip.power` (무기 5종: 5/15/20/22/30) | `HDPlayer.powOfWeapon` | **`battle.dart:439`** `damage = (strength × powOfWeapon × level.physical) ÷ 20` | ✅ **작동** — 수치가 데미지로 직결 |
| `equip.ac` (갑옷 3종: 2/5/9) | `HDPlayer.ac` | **`battle.dart:514`** 파티 피격 방어 · **`:441`** 은 *적* 의 `ac` | ✅ **작동** |
| `equip.ac` (방패 2종: 2/4) | `HDPlayer.ac` 에 **합산**(R-42-30) | 동상 | ✅ **작동** |
| `equip.weaponType` (`stab`/`wield`/`chop`) | (필드만 존재) | **없음** — `grep weaponType lib/application/battle.dart` → 0건 | ❌ **무효** (표시·서술 전용, R-42-35) |
| R-42-31 의 표시용 사본 | `powOfArmor` / `powOfShield` | **없음** — 부록 H-1. 읽는 곳은 `getAttribute`/`changeAttribute`/직렬화뿐 | ❌ **무효** (레거시 cm2 의 `GetAttribute` 만 본다) |
| `value` (0 ~ 900) | (런타임 필드 없음) | **없음** — 상점이 1차 스코프 밖이므로([BP-40 §40.5.4](40_gameplay_changes.md)) 매매 경로가 없다 | ❌ **런타임 무효** — `grade` 유도(§7.5)와 린트 QV-33 에만 쓰인다 |
| `grade` (1~4) | (런타임 필드 없음) | **없음** — 빌드 린트 전용 | ❌ **런타임 무효**(의도된 것) |
| `maxStack` (9/20/50/99) | `WorldState.inventory` 값 | ✅ §8.3 `giveItem` 상한 | ✅ **작동** |
| `stackable` | 동상 | ✅ R-42-10 | ✅ **작동** |
| `effects` (`heal_party`/`add_food`/`warp`) | `HDPlayer.hp` · `HDParty.food` · 맵 전환 | ✅ §3.3 ③열 | ✅ **작동** |
| `sources` / `desc` / `name` | (데이터) | 표시·린트 | ✅ 의도된 것 |

**결론 — 20종 카탈로그에서 실제로 게임을 움직이는 수치는 `power` 5개 · `ac` 5개 · `effects` 4개, 총 14개다.**
`weaponType` 10건, `powOfArmor`/`powOfShield` 사본 5건, `value` 20건은 **현행 빌드에서 아무 규칙도 읽지 않는다.**

- **R-42-33e** 위 표에서 ❌ 인 필드는 **카탈로그에서 빼지 않는다.** `weaponType`·`value` 는 서술·린트·장차의 상점이
  쓰는 데이터이고, `powOfArmor` 사본은 레거시 cm2 호환이다. **다만 "이 수치가 전투를 바꾼다" 고 쓰지 않는다** —
  그것이 §1.3 이 비판한 자기기만이다. `_summary` 에 무효 사실을 남긴다(R-42-35).
- **R-42-33f** 반대로 **❌ 를 ✅ 로 바꾸는 것은 전부 B 갈래**이고 전투식 변경이 선행이다.
  `weaponType` 상성을 넣고 싶으면 `battle.dart:439` 에 계수를 더해야 하고, `value` 를 살리려면 상점이 있어야 한다.

---

## 5. UI — 소지품 화면

### 5.1 진입과 기하학

| 항목 | 값 | 근거 |
|---|---|---|
| 진입 | 메인 메뉴 **7번 `소지품을 살핀다`** | [BP-40 §40.4.2](40_gameplay_changes.md) |
| 창 위치·크기 | **(144, 40) · 512 × 400** | [BP-41 R-41-8](41_journal_ui_spec.md) — 저널 창과 동일 기하학 |
| 본문 행 수 | **19행** | 동상 |
| 한 행 폭 | **한글 30자 / 반각 60칸** | 동상 |
| 입력 모드 | 신규 모드 없음. `HDWindowManager` 스택 + `HDWindowKeyDispatcher` 분기 | [BP-40](40_gameplay_changes.md) R-40-14 |
| 키 | ↑↓/WS 이동 · **←→/AD 탭 전환** · Enter/E/Space 확정 · Esc/Q 닫기 | [BP-40 §40.4.4](40_gameplay_changes.md) |

- **R-42-36** 저널과 **같은 창 크기·같은 키**를 쓴다. 메뉴에서 이웃한 두 항목이 다른 조작법을 가지면
  둘 다 못 외운다.
- **R-42-37** 화면에 **"인벤토리" 라는 말을 쓰지 않는다**([BP-40](40_gameplay_changes.md) R-40-5). 제목은 `소지품`.

**탭 7개 ↔ 카테고리 9종 대응** (§3.1 의 "소지품 탭" 열을 1행으로 접은 것)

| 탭 | `소모품` | `무기` | `방패` | `갑옷` | `열쇠` | `물건` | `기록` |
|---|---|---|---|---|---|---|---|
| 포함 category | `consumable` | `weapon` | `shield` | `armor` | `key` | `quest` · `relic` · `crystal` | `lore` |
| 정렬(§2.4) | `itemId` 사전순 | 가상 항목 `맨손` 후 사전순 | 가상 `없음` 후 사전순 | 가상 `평상복` 후 사전순 | 사전순 | **category 고정 순서(quest→relic→crystal) 후** 사전순 | 사전순 |
| 48종 상한 대상 | ✅ | ✅ | ✅ | ✅ | ❌(R-42-11) | ❌ `quest`/`relic` · ✅ `crystal` | ✅ |

- **R-42-37a** `물건` 탭만 **세 category 를 합친다.** 각각 1~2종뿐이라 탭을 나누면 빈 탭이 생기고,
  세 category 는 모두 "쓸 수 없고 버릴 수 없는 것"(`crystal` 은 v1 에서 사용 없음, Q-42-4)이라 조작이 동일하다.
  탭 안에서는 §2.4 의 category 고정 순서가 그대로 유지되므로 정렬 결정론은 깨지지 않는다.

**반대 심문: 소지품 화면이 콘솔(대화) 영역을 점유하면 진행 중이던 대화는 어떻게 되는가**

- **R-42-37b 불변식**: **대화가 진행 중일 때는 소지품 화면을 열 수 없다.** 저널도 같다([BP-41 R-41-9a](41_journal_ui_spec.md)).
  따라서 "가려진 대화" 라는 상태가 애초에 만들어지지 않는다.
- 실측 근거 3단:
  1. 소지품은 **메인 메뉴에서만** 열린다(§5.1 진입 행). 다른 진입점을 만들지 않는다.
  2. 메인 메뉴는 **`HDInputMode.map` 에서만** 열린다 — Space/Esc/Q 를 메뉴로 해석하는 것은
     `input_dispatcher.dart:118` 의 `_handleMap` 하나뿐이다.
  3. `HDGameMain.currentInputMode` 는 `window > menu > dialogue > map` 우선순위(`hd_game_main.dart:159-164`)이므로,
     대화 대기 중(`isWaitingForKey`)에는 `dialogue` 가 잡혀 2번에 도달하지 못한다.
- **그럼에도 창이 대화 패널을 덮는 것 자체는 사실이다.** 소지품 창은 (144,40)~(656,440)으로
  대화 패널(288,0)~(800,320)의 **대부분을 가린다.** 이때 가려지는 것은 *진행 중인 대화*가 아니라
  `showMainMenu` 가 이미 `beginNarrative()`(`menu_flows.dart:48`) 로 **닫아 둔 이전 대화의 잔상**이다.
  창을 닫으면 `endNarrative()`(`:80`)가 원래 화면을 되돌린다 — 별도 복원 로직이 필요 없다.
- **R-42-37c** 이 불변식은 **티어 0 의 비동기 대화 그래프가 들어오면 깨질 수 있다.**
  "대화 중에도 소지품을 열어 물건을 건넨다" 를 원하게 되는 순간이 그 지점이다.
  그때는 `beginNarrative` 중첩 규약을 먼저 정해야 하며, 본 장은 그 문을 열지 않는다.
  회귀 1건을 §9.2 의 태스크로 남긴다(T-42-7).

### 5.2 목록 화면 (19행)

| 행 | 내용 |
|---|---|
| 1 | 탭 행 + 우측 `(커서/총수)` |
| 2 | 구분선 |
| 3 ~ 14 | **항목 12행** (초과 시 스크롤 `▲`/`▼`) |
| 15 | 구분선 |
| 16 ~ 17 | 선택 항목 설명 **2행** |
| 18 | `황금 500   식량 100` — 파티 코어 값 상시 표시 |
| 19 | 힌트 푸터 |

```
        (144,40)                                        (656,40)
           ┌────────────────────────────────────────────────────────────┐
행1  19.2px│@F[소모품]@@ 무기  방패  갑옷  열쇠  물건  기록         (2/3)   │
행2        │────────────────────────────────────────────────────────────│
행3        │  회복약                                            ×3      │
행4        │@F> 성수@@                                              ×1      │
행5        │  마른 양식                                         ×5      │
행6        │                                                            │
행7        │                                                            │
 …         │                                                            │
행14       │                                                            │
행15       │────────────────────────────────────────────────────────────│
행16       │@7맑은 물을 담은 병. 일행 모두의 상처가 아문다.@@               │
행17       │                                                            │
행18       │@7황금 500      식량 100@@                                      │
행19       │@7↑↓ 고르기  ←→ 갈래  Enter 다루기  Esc 닫기@@                  │
           └────────────────────────────────────────────────────────────┘
        (144,440)                                       (656,440)
```

- 커서 행은 `@F` + `> ` 접두(저널과 동일).
- 수량은 우측 정렬. `stackable:false` 는 수량을 **표시하지 않는다**(`×1` 이 반복되면 잡음).
- 빈 탭은 행3 에 `@7가진 것이 없다.@@` 한 줄.
- **행1 우측 `(커서/총수)` 의 총수는 "그 탭에 실제로 그려진 항목 수" 다.** 위 목업은 소모품 3종을 보유한 상태이므로
  `(2/3)` 이고, 커서는 2번째(`성수`)에 있다. 탭을 바꾸면 총수도 그 탭의 보유 종류 수로 바뀐다
  ([BP-41 §41.8.1](41_journal_ui_spec.md) 의 `(1/2)`·§41.8.2 의 `(1/3)` 과 같은 규약).
- **목업의 `│` 정렬 규약**: 각 행은 **색 태그를 제거한 뒤의 폭이 정확히 반각 60칸**이 되도록 채웠다.
  `@F`/`@7`/`@@` 는 렌더 시 제거되어 폭 0 이므로(`hd_text_utils.dart` `_parseToChunks`),
  **원문에서는 태그가 있는 행의 `│` 가 오른쪽으로 밀려 보인다.** 실제 화면에서는 어긋나지 않는다.

### 5.3 다루기 화면 (Enter 후)

```
           ┌────────────────────────────────────────────────────────────┐
행1        │@F회복약@@                                          ×3      │
행2        │────────────────────────────────────────────────────────────│
행3        │@7상처를 아물게 하는 물약. 일행 모두의 몸이 조금 낫는다.@@      │
행4        │@7                                                     @@   │
행5        │                                                            │
행6        │  값어치  60 황금                                            │
행7        │  갈래    소모품                                             │
행8        │                                                            │
행9        │────────────────────────────────────────────────────────────│
행10       │@F> 쓴다@@                                                   │
행11       │  버린다                                                     │
행12       │  그만둔다                                                   │
행13       │                                                            │
 …         │                                                            │
행19       │@7↑↓ 고르기  Enter 고름  Esc 뒤로@@                           │
           └────────────────────────────────────────────────────────────┘
```

**행동 목록은 category 로 결정된다**(§3.1).

| category | 행동 |
|---|---|
| `consumable` | `쓴다` · `버린다` · `그만둔다` |
| `weapon`/`shield`/`armor` | `채운다` · `버린다` · `그만둔다` |
| `lore` | `읽는다` · `버린다` · `그만둔다` |
| `key`/`quest`/`relic`/`crystal` | `그만둔다` (단독) — **버리기 항목 자체를 안 만든다** |

- **R-42-38** 못 하는 행동을 **회색으로 남기지 않고 아예 뺀다.** 원작 메뉴(`menu_flows.dart`)에
  비활성 항목이라는 어휘가 없다.
- **R-42-39** `quest`/`key`/`relic` 을 열었을 때 행3~4 설명 아래에 한 줄을 덧붙인다:
  `@7이 물건은 버릴 수 없다.@@` — 항목이 없는 이유를 말해 준다(R-36-6 과 같은 정신).

### 5.4 장착 흐름 (`채운다`)

```
채운다 선택
   ↓
누구에게 채우겠습니까?          ← showWindowMenu, 파티원 중 isValid() 인 사람만
   ↓
[EQ-2 검사]  이미 다른 사람이 다 쓰고 있으면 → "단검이 하나뿐입니다." 후 되돌아감
   ↓
[교체 확인]  그 사람이 이미 그 슬롯에 무엇을 차고 있으면
             "가죽 갑옷을 벗고 사슬 갑옷을 채우겠습니까?"  예 / 아니오
   ↓
equipped* 갱신 + 정수 필드 갱신(R-42-26) + powOfWeapon/ac 재계산(R-42-29/30)
   ↓
"슴갈이 사슬 갑옷을 채웠다."   ← progress 로그 1줄
```

- **R-42-40** 파티원 선택 메뉴는 기존 `_selectPlayerForMagic()` 과 **같은 형태**를 쓴다
  (`menu_flows.dart` — `"누가 마법을 사용하겠습니까 ?"`). 문구만 `"누구에게 채우겠습니까 ?"`.
- **R-42-41** 장착 결과는 **오버레이가 아니라 progress 로그**로 알린다. 창 위에 창을 또 띄우지 않는다.
- **R-42-42** 벗기기는 별도 항목이 아니라 **다른 것을 채우는 것**으로만 일어난다.
  "맨손으로 돌아가기" 가 필요하면 `맨손`/`평상복`을 목록의 **가상 항목**으로 각 슬롯 탭 맨 위에 둔다.

### 5.5 `showCharacterStatus()` 반영

```
현행:  사용 무기 - 무기1
       방패 - 방패0        갑옷 - 갑옷1

변경:  사용 무기 - 단검
       방패 - 없음          갑옷 - 가죽 갑옷
```

- **R-42-43** `menu_flows.dart` 의 `padRight(12)` 정렬은 그대로 둔다. 아이템 이름이 길어지면
  줄이 밀리므로 **장비 표시명은 8자 이하**로 제한한다(§7.4 린트).

---

## 6. 세이브 영향

### 6.1 v2 에서 무엇이 늘어나는가

| 위치 | 항목 | 소유 |
|---|---|---|
| `worldState.inventory` | `Map<itemId,int>` | [BP-25 §2.1](25_world_state_and_save.md) |
| `party.players[i].equippedWeapon/Shield/Armor` | `String?` × 3 | **이 장** |
| `contentVersion` | 아이템 카탈로그가 속한 팩 버전 | [BP-25](25_world_state_and_save.md) |

- **R-42-44** `equipped*` 는 **`party` 봉투 안**(플레이어별)에 넣는다. `worldState` 로 옮기지 않는다.
  파티원 배열이 이미 `players[]` 로 직렬화되고 있고, 장비는 개인 속성이기 때문이다.
- **R-42-45** 크기 추정: 인벤토리 48종 × ~34B ≈ 1.6KB, `equipped*` 6인 × 3슬롯 × ~48B ≈ 0.9KB.
  합계 **2.5KB 미만** — 부록 C-3 의 570KB 맵 스냅샷 문제에 비하면 무시 가능.

### 6.2 v1 → v2 마이그레이션 절차

```
1. party.players[i].weapon/shield/armor 를 읽는다        (v1 에 반드시 있음)
2. legacyItemMap 으로 역참조 (§4.2)
   ├─ 매핑 있음 → equipped* = itemId,  inventory[itemId] += 1
   └─ 매핑 없음 → equipped* = null,    경고 1건 기록 (정수 필드는 보존)
3. powOfWeapon / ac 는 v1 값을 그대로 유지한다  ← 재계산하지 않는다
4. inventory 의 나머지는 비운다 (v1 에는 아이템 개념이 없었으므로)
5. 이 마이그레이션은 item_gained 를 발행하지 않는다     ← R-42-47
```

| # | 규칙 |
|---|---|
| **R-42-46** | 2단계에서 `inventory` 에 **1개를 넣는다.** 장착 참조 방식(R-42-4)의 불변식 EQ-1 을 만족시키기 위해서다. 넣지 않으면 로드 직후 모든 장비가 강등된다 |
| **R-42-47** | 마이그레이션은 **월드 이벤트를 발행하지 않는다.** 세이브를 여는 것만으로 `acquire` 목표가 진행되면 안 된다 |
| **R-42-48** | 3단계에서 `powOfWeapon`/`ac` 를 재계산하지 않는 이유: cm2 가 `Player::ChangeAttribute` 로 직접 넣어 둔 값(`L1_ep1d0.cm2` 의 `pow_of_weapon 100`)이 있을 수 있고, 그것이 그 세이브의 진실이다. **다음 장착 때 덮어쓴다** |
| **R-42-49** | 경고는 세이브 슬롯 메타에 남기고 로드 직후 progress 로그에 요약 1줄을 낸다: `@7옛 저장이라 장비 이름을 알 수 없는 것이 2개 있다.@@` |

---

## 7. 밸런스 초안 — 초기 `core` 아이템 20종

### 7.1 근거 수치 (전부 실측)

| 축 | 값 | 출처 |
|---|---|---|
| 시작 자산 | `gold 500`, `food 100` | `party.dart:13` |
| **여관 1박** | **−50 gold** | `assets/L1_ep1d0.cm2` `Party::PlusGold(-50)` |
| 전투 골드 | `Σ enemy.level × 5`, 최대 3기 | `battle.dart:261-264` |
| 전투 경험치 | `Σ max(1, ((id+1)^3) ÷ 8)` | `battle.dart:243-247` (승리 분기는 `:240`) |
| 레벨 2 필요 exp | 1,500 | `player.dart:170`(`expTable` 은 `:167` 부터) |
| 적 HP | `endurance × level`, **하한 1** | **`domain/battle/enemy.dart` `HDEnemy` 생성자** — `hp = endurance * level; if (hp <= 0) hp = 1;` |
| 사용 가능한 적 | **id 1~74 (74종)** | 부록 B-1 — `battle.dart:44` 의 `<= 0` 가드로 id 0 은 소환 불가 |
| 퀘스트 tier1 골드 | 100~400 | [BP-23 §23.9.3](23_quest_model.md) |

- **주의(출처 정정)**: `player.dart` 의 `assignFromEnemyData`(`:241`)에도 `maxHp = endurance * level.physical` 이 있어 **식은 같으나**,
  전투에 등장하는 적은 `HDEnemy` 이고 `assignFromEnemyData` 는 **적을 파티원으로 영입할 때**(`Player::AssignFromEnemyData`) 쓰이는 경로다.
  밸런스 계산의 정본은 `HDEnemy` 생성자 쪽이며, `hp <= 0 → 1` 하한이 `Phantom`(strength 0) 계열의 계산에 영향을 준다.

**골드 척도 기준선**

```
여관 1박 50 gold = 레벨1 적 3기 전투 약 3.3회분 (15 gold/전투)
시작금 500 gold  = 여관 10박 = 전투 33회분
```

→ **50 gold 를 "하룻밤" 단위로 삼는다.** 초반 소모품은 1~2박, 첫 무기는 2~5박, 좋은 갑옷은 10박 이상.

### 7.2 무기 성능 척도 — `power` → 실제 데미지

슴갈(`strength 18`, `level.physical 1`) 기준. `damage = (18 × power × 1) ÷ 20` 후 0~49% 감쇠, 그 뒤 적 방어.

**계산 방법**: 세 항 모두 **정수 나눗셈**이고 난수가 두 개(감쇠 `rand(0..49)`, 적 방어 `rand(1..10)`)이므로
평균값을 대입하면 오차가 크다. 아래는 **500개 조합(50 × 10) 전수 열거**로 얻은 정확한 기댓값이며,
`damage <= 0` 은 0 으로 접어(빗나감) 계산했다.

**각 적의 실제 `ac`·`level` 을 적용한다** — 초판은 두 열 모두 `ac1·lv1` 로 계산해 Goblin 열이 낙관적이었다.
실측(`domain/battle/enemy_data.dart`): `Troll(id 1)` `ac 1 · level 1 · endurance 6` → HP **6** /
`Goblin(id 9)` `ac 3 · level 3 · endurance 13` → HP **39**.

| 무기 | `power` | 기본값 | Troll 상대 E[피해] | Troll 필요 타수 | Goblin 상대 E[피해] | Goblin P(피해>0) | Goblin 필요 타수 |
|---|---|---|---|---|---|---|---|
| 맨손 | (없음, `powOfWeapon 0`) | **0** | **0.00** | **∞** | **0.00** | 0% | **∞** |
| 단도 | 5 | 4 | 3.40 | 2타 | **0.80** | **35%** | **약 49타** |
| **단검** | **15** | **13** | **10.20** | **1타** | 5.83 | 93% | 약 7타 |
| 단창 | 20 | 18 | 13.98 | 1타 | 9.58 | 100% | 약 4타 |
| 작은 도끼 | 22 | 19 | 14.74 | 1타 | 10.34 | 100% | 약 4타 |
| 강철 검 | 30 | 27 | 20.78 | 1타 | 16.38 | 100% | 약 3타 |

(Troll 상대 `P(피해>0)` 은 단도 이상 전부 **100%** 다 — `ac 1 · lv 1` 의 최대 경감이 1 이라 기본값 3 이상이면 뚫린다.)

- **R-42-50** **맨손은 0 데미지다.** `(18 × 0 × 1) ÷ 20 = 0` → `damage <= 0` 분기.
  이것은 버그가 아니라 "무기 없이는 못 싸운다" 는 원작 규칙으로 **유지**한다.
  `books.json` 의 맨손 `power 1` 을 아이템화하지 않는 이유이기도 하다(§4.4).
- **R-42-51** 첫 무기(`단검`, power 15)가 **레벨 1 적을 한 방에 잡는다**는 것이 기준선이다.
  `lore_ep1.cm2:382` 의 `"일행은 가장 기본적인 무기로 모두 무장을 하였다."`(무기고 지급) 가 이 지점이다.
- **R-42-51a** **단도(power 5)는 레벨 3 적을 상대할 수 없다.** Goblin 상대 기댓값 0.80, 피해가 들어가는 턴이 35%,
  필요 타수 약 49 — 사실상 "못 이긴다". 이것은 재조정 대상이 **아니라 의도**다: 단도는 `chest`/`npc_gift` 급
  최하급 무기이고(§7.6), 이 계산이 **R-42-51 의 "첫 무기는 power 15" 를 수치로 정당화**한다.
  단, 콘텐츠가 "단도만 주고 레벨 3 적을 붙이는" 배치를 하면 진행 불가가 되므로 §7.6 의 획득처 배분을 지켜야 한다.
- **R-42-52** 강철 검(power 30) 이상은 **tier 2 이후**에만 등장한다. tier 1 에서 주면 레벨 3 적을 **약 3타**에
  정리해 같은 tier 의 다른 무기(단창·도끼 약 4타, 단검 약 7타)와의 격차가 사라지고 경험치 곡선이 무너진다.
  - 초판은 "2타" 라고 적었고 그것은 Goblin 방어를 `ac1·lv1` 로 계산한 결과였다. **실제는 3타**이므로
    위험의 강도는 초판보다 **약하다.** 판정(tier 2 이후)은 유지한다 — 단검 대비 2.4배는 여전히 큰 격차다.
- **R-42-52a** 위 표의 수치는 **`level.physical = 1` 고정이다.** 공격식은 `powOfWeapon × level.physical` 로
  레벨과 **곱**하므로, 레벨 2 가 되면 같은 무기의 데미지가 2배가 된다. 무기 사다리를 촘촘히 만들 필요가 없는 이유이며,
  5 / 15 / 20 / 22 / 30 이라는 5단 사다리로 충분한 근거다.

### 7.3 방어 척도 — `ac` → 실제 감소량

피격식: `damage = (e.strength × e.level × rand(1..10)) ÷ 10`, 방어 `−= (ac × player.level × rand(1..10)) ÷ 10`.

방어가 없을 때(`ac 0`)의 적 공격력. 정수 나눗셈이므로 `(str × lv × r) ÷ 10` 을 `r = 1..10` 전수 열거해 평균했다.

| 적 | str × lv | 최대 피해 | **평균 피해(전수)** |
|---|---|---|---|
| Troll(id 1) | 9 × 1 | 9 | **4.50** |
| Wolf(id 7) | 7 × 2 | 14 | **7.30** |
| Goblin(id 9) | 11 × 3 | 33 | **17.70** |
| Rock-Man(id 23) | 19 × 6 | 114 | **62.30** |

(초판의 5.0 / 7.7 / 18.2 / 62.7 은 `× 5.5 ÷ 10` 이라는 연속 근사였다. 정수 절단 때문에 실제 평균은 이보다 낮다.)

**레벨 1 파티원의 `ac` 별 실제 피격 결과** — 난수 두 개(적 공격 `rand(1..10)`, 방어 `rand(1..10)`)의
**100개 조합 전수 열거**. `damage <= 0` 은 "방어했다" 분기이므로 0 으로 접었다.

| `ac` | Troll E[피해] | Troll **P(피해>0)** | Troll 최대 | Goblin E[피해] | Goblin P(피해>0) | Rock-Man E[피해] |
|---|---|---|---|---|---|---|
| 0 (평상복) | 4.50 | 90% | 9 | 17.70 | 100% | 62.30 |
| **2** (두꺼운 옷) | 3.88 | 83% | 9 | 17.00 | 100% | 61.60 |
| **5** (가죽 갑옷) | 2.55 | 65% | 9 | 15.24 | 95% | 59.80 |
| **7** (가죽+나무방패) | 2.07 | 56% | 9 | 14.42 | 92% | 58.90 |
| **9** (사슬 갑옷) | 1.65 | 45% | 9 | 13.47 | 88% | 57.80 |
| 10 (books.json 두꺼운옷) | 1.20 | **36%** | **8** | 12.59 | 85% | 56.80 |
| 20 (books.json 가죽갑옷) | 0.50 | **16%** | **7** | 8.66 | 69% | 51.55 |

- **R-42-53** `books.json` 의 `ac 10`/`ac 20` 은 이 식에서 **초반 전투를 사실상 성립하지 않게 만든다.**
  §4.4 의 재척도(2 / 5)가 필수다.
  - **정정**: 초판은 이 두 줄을 "**항상 0**" 이라고 적었다. **그것은 거짓이다.**
    두 난수가 독립이므로 `ac 20` 에서도 100개 조합 중 **16개**에서 피해가 들어가고 최댓값은 **7** 이다
    (`ac 10` 은 36개 조합·최대 8). "항상" 이 아니라 "**대부분의 턴이 0 피해이고 드물게 큰 피해가 들어온다**" 가 맞다.
  - 그런데도 **결론(재척도 필요)은 그대로 옳다.** 방어의 성격이 바뀌기 때문이다 —
    `ac 2` 에서는 매 턴 조금씩 깎이는 소모전이지만, `ac 20` 에서는 6턴 중 5턴은 아무 일도 없고
    한 턴에 7 이 들어온다. 후자는 **플레이어가 방어구를 입었다는 사실을 체감할 수 없고**(로그가 거의 "방어했다" 뿐),
    전투가 난수 스파이크의 문제가 된다. 부록 H-2 의 "무효화" 는 이 뜻으로 읽는다.
- **R-42-53a** 사슬 갑옷(`ac 9`)도 "거의 무피해" 가 **아니다** — Troll 상대 45% 의 턴에서 피해가 들어가고 기댓값 1.65 다.
  초판의 "평균 0.0 → 거의 무피해" 는 연속 근사로 음수가 나온 것을 잘못 접은 결과였다.
  갑옷 최상단(`ac 9`)이 초반 적을 완전히 막지 못한다는 사실이 오히려 사다리 설계의 근거다.
- **R-42-53b** **`ac` 는 레벨 3 이상 적에게 거의 의미가 없다.** Goblin 상대 `ac 0 → 9` 로 올려도 기댓값이
  17.70 → 13.47(−24%)뿐이고, Rock-Man 은 62.30 → 57.80(−7%)이다. 방어식의 경감이 `ac × level.physical` 인데
  파티 레벨이 1 이면 상한이 `ac` 이고, 적 공격력은 `str × level` 로 **적 레벨과 곱**하기 때문이다.
  → 갑옷은 "초반 소모전을 완만하게" 만드는 장치이고, 중반 이후의 생존은 **레벨과 HP** 가 담당한다.
    이 사실이 §7.6 에서 사슬 갑옷을 tier 2~3 보상으로만 둔 이유다(초반에 줘도 체감이 크지 않다).
- **R-42-54** `ac` 는 파티원 레벨과 곱해지므로 **레벨이 오르면 저절로 강해진다.**
  따라서 갑옷 사다리는 **완만하게** 만든다: 0 → 2 → 5 → 9. 한 단계에 2배를 넘기지 않는다.
- **R-42-55** 방패는 갑옷의 **절반 이하** 폭으로만 올린다(2, 4). 두 슬롯이 합산되므로(R-42-30)
  같은 폭이면 방패가 갑옷을 무의미하게 만든다.
- **R-42-55a** 위 두 표는 [BP-33](33_validation_and_lint.md) 이 받을 **밸런스 회귀의 기준값**이다.
  전투식(`battle.dart:439-441`, `:513-514`)을 한 줄이라도 고치면 이 표가 전부 무효가 되므로,
  §4.5 B 갈래에 착수하는 장은 이 표의 재계산을 함께 태스크로 잡아야 한다.

### 7.4 카탈로그 20종 (실제 데이터)

`value` 는 골드 기준가. `grade` 는 [BP-23 QV-33](23_quest_model.md) 이 요구하는 보상 등급(§7.5).
`설명` 은 `desc` 문자열의 초안이며 문체 규범은 [BP-43](43_content_style_guide.md) 을 따른다.

| # | item id | 이름 | 분류 | 스택 | `value` | grade | 성능 | 설명(초안) |
|---|---|---|---|---|---|---|---|---|
| 1 | `item.core.potion_heal` | 회복약 | consumable | ✅ 99 | **60** | 1 | `heal_party(40)` | 상처를 아물게 하는 물약. 일행 모두의 몸이 조금 낫는다. |
| 2 | `item.core.blessed_water` | 성수 | consumable | ✅ 20 | **300** | 2 | `heal_party(100)` | 맑은 물을 담은 병. 일행 모두의 상처가 아문다. |
| 3 | `item.core.travel_ration` | 마른 양식 | consumable | ✅ 50 | **20** | 1 | `add_food(20)` | 소금에 절여 말린 고기와 딱딱한 빵. 맛은 기대하지 마시오. |
| 4 | `item.core.teleport_ball` | 이동 구슬 | consumable | ✅ 9 | **900** | 3 | `warp(CastleLore, x, y)` | 쥐면 따뜻해지는 유리 구슬. 깨뜨리면 로어성으로 돌아간다. |
| 5 | `item.core.dagger` | 단도 | weapon | ❌ | **40** | 1 | `power 5` · `stab` | 품에 넣고 다니는 짧은 칼. 없는 것보다 나을 뿐이다. |
| 6 | `item.core.short_sword` | 단검 | weapon | ❌ | **120** | 1 | `power 15` · `wield` | 로어 무기고에서 내주는 가장 흔한 검. 손에 익기 쉽다. |
| 7 | `item.core.short_spear` | 단창 | weapon | ❌ | **200** | 2 | `power 20` · `stab` | 자루가 짧은 창. 좁은 굴에서도 다루기 어렵지 않다. |
| 8 | `item.core.hand_axe` | 작은 도끼 | weapon | ❌ | **240** | 2 | `power 22` · `chop` | 나무를 패던 도끼. 뼈를 부수는 데에도 모자람이 없다. |
| 9 | `item.core.steel_sword` | 강철 검 | weapon | ❌ | **600** | 3 | `power 30` · `wield` | 잘 벼린 강철 검. 값이 비싼 만큼 날이 오래 간다. |
| 10 | `item.core.wooden_shield` | 나무 방패 | shield | ❌ | **70** | 1 | `ac 2` | 판자를 덧대어 만든 방패. 한두 번은 막아 준다. |
| 11 | `item.core.iron_shield` | 무쇠 방패 | shield | ❌ | **260** | 2 | `ac 4` | 무쇠를 두른 방패. 무겁지만 믿을 만하다. |
| 12 | `item.core.thick_clothes` | 두꺼운 옷 | armor | ❌ | **60** | 1 | `ac 2` | 겹겹이 누빈 옷. 갑옷이라 부르기는 민망하다. |
| 13 | `item.core.leather_armor` | 가죽 갑옷 | armor | ❌ | **180** | **2** | `ac 5` | 삶은 가죽을 덧댄 갑옷. 값에 비해 든든하다. |
| 14 | `item.core.chain_mail` | 사슬 갑옷 | armor | ❌ | **700** | 3 | `ac 9` | 쇠고리를 엮어 지은 갑옷. 무게만큼 목숨을 지켜 준다. |
| 15 | `item.core.armory_key` | 무기고 열쇠 | key | ❌ | **0** | 1 | — | 경비병의 허리에 걸려 있던 놋쇠 열쇠. 무기고 문에 맞는다. |
| 16 | `item.core.wall_charm` | 허무는 부적 | key | ❌ | **0** | 2 | — | 낡은 삼줄에 엮은 뼛조각. 막힌 곳을 무너뜨린다고 한다. |
| 17 | `item.core.gatekeeper_seal` | 문지기의 인장 | quest | ❌ | **0** | 1 | — | 수감소 문지기가 내주는 나무 패. 이것이 없으면 들여보내지 않는다. |
| 18 | `item.core.lore_ale` | 로어 에일 | quest | ✅ 20 | **25** | 1 | — (건네는 물건) | 로어 주점에서 담근 검은 맥주. 문지기가 이것을 반긴다. |
| 19 | `item.core.worn_logbook` | 낡은 항해 일지 | lore | ❌ | **30** | 1 | 읽기 | 물에 불은 일지. 가라앉은 대륙의 마지막 날이 적혀 있다. |
| 20 | `item.core.shard_of_gold` | 황금방패의 조각 | relic | ❌ | **0** | 4 | `unique` | 황금의 방패에서 떨어져 나온 조각. 메너스 어딘가에 나머지가 있다. |

**분류별 집계**: consumable 4 · weapon 5 · shield 2 · armor 3 · key 2 · quest 2 · lore 1 · relic 1 = **20종**

#### 7.4.1 초판에서 **빼거나 성격을 바꾼 3종** (검수 F-03 대응)

초판 카탈로그의 소모품 6종 중 **3종이 게임에 아무 관측 가능한 효과가 없었다.** §3.3 의 ③열(관측)과
§1.7(파티 버프 실측)로 되짚으면 다음과 같고, 이것은 이 장 자신의 R-42-23 을 위반한 상태였다 —
§1.6 이 비판한 원작의 "화면에 적어 놓고 실제로는 아무것도 안 일어난다" 와 **구조가 동일**했다.

| 초판 항목 | 초판 성능 | 실제로 무슨 일이 일어나는가 | 처분 |
|---|---|---|---|
| `item.core.big_torch` 대형 횃불 | `set_flag(flag.core.party.torch_lit)` | **아무 일도.** 실제 횃불은 `PartyBuffs.magicTorch` 이고 그것을 읽는 곳은 `sight_calculator.dart:47,48,75` 다(§1.7). `torch_lit` 이라는 이름의 플래그를 읽는 코드는 **존재하지 않으며**, `WorldState.flags` → `PartyBuffs` 다리도 어느 장에도 없다 | **v1 카탈로그에서 제외.** id 예약 |
| `item.core.crystal_ball` 수정 구슬 | `set_flag(flag.core.party.farsight)` | **아무 일도.** 맵 뷰포트는 `sight_calculator` 의 결과만 사용하고 `farsight` 를 읽는 렌더 경로가 없다 | **v1 카탈로그에서 제외.** id 예약 |
| `item.core.lore_ale` 로어 에일 | `add_var(var.core.party.reputation_lore, 1)` | **아무 일도 관측되지 않는다.** [BP-40 §40.5.2](40_gameplay_changes.md) 가 평판을 1차 스코프에서 빼면서 "**표시: 하지 않는다(UI 0)**" 와 "`var_cmp` 로 분기하는 것은 Soft 경고" 를 함께 못박았다 — 화면에도 안 나오고 분기에도 못 쓴다 | **`category: "quest"` 로 전환** (아래) |

- **R-42-57a** **대형 횃불·수정 구슬은 v1 카탈로그에서 뺀다.** R-42-57 의 해독·부활 약초와 **같은 처분**이다.
  - 두 아이템이 요구하는 것은 새 `do` 하나가 아니라 **`Effect` → `PartyBuffs` 다리**다. 그 다리가 있으면
    `grant_buff(magicTorch, n)` 형태로 대형 횃불이 성립하고(원작에서도 `magicTorch` 를 세우는 것은
    마법 33번 "마법의 횃불" 이므로 아이템이 같은 값을 세우는 것은 자연스럽다), 수정 구슬은
    `sightRange` 를 직접 만지는 별개 규칙이 필요하다.
  - 다리 요청은 §9.2 로 [BP-27](27_runtime_engine.md) 에 넘기고, DSL 승격은 `Q-42-1` 에 합친다.
  - **id 는 예약**한다([BP-22 §6.5](22_world_bible_model.md) 가 이미 잡아 둔 id 이므로 지우지 않는다).
- **R-42-57b** **로어 에일은 `quest` 아이템으로 전환한다.** 뺀 것이 아니라 **성격을 바로잡은 것**이다.
  - 근거: [BP-41 §41.8.3](41_journal_ui_spec.md) 의 저널 목업이 이미 목표 문구로
    **"로어 에일을 문지기에게 건넨다"** 를 쓴다. 즉 이 아이템의 실제 용도는 마시는 것이 아니라
    **`deliver` 목표의 대상**이다. `quest` 로 두면 `effects: []` 가 정당하고(R-42-18),
    건네는 순간 `take_item` → **`item_lost` 발행** → `deliver` 판정으로 **완전히 관측 가능**해진다(§8.4).
  - `stackable: true`(maxStack 20)는 유지한다 — §3.1 의 `quest` 행이 "선언에 따름" 이므로 스키마 위반이 아니고,
    "에일 3병을 모아 오라" 는 `acquire(count:3)` 목표를 열어 둔다.
  - `value 25` 는 유지한다. `quest` 는 매매 불가(R-42-17)이므로 값은 **가치 척도로만** 남는다(§4.5 판정표의 `value` 행).
- **R-42-57c** 빠진 자리를 채운 **신규 2종은 둘 다 현행 런타임에서 검증된 효과만 쓴다.**

| 신규 | 어떻게 관측되는가 |
|---|---|
| `item.core.blessed_water` 성수 (`heal_party(100)`) | `HDPlayer.hp` 가 오르고 상태 패널의 HP 숫자가 바뀐다. `heal_party` 는 D-05 닫힌 집합 안이며 §3.3 ③열 ✅ |
| `item.core.wall_charm` 허무는 부적 (`key`, `effects: []`) | **원작의 `Flag::Set(GFD0_GET_WALL_REMOVER)`("지형 변화의 아이템")를 실제 물건으로 되살린 것.** 벽 쪽 트리거 앵커가 `has_item` 으로 검사하고 `change_tile` 로 벽을 무너뜨린다 — 둘 다 D-05 닫힌 집합 안이고 화면에서 지형이 바뀌므로 ③열 ✅. §1.6 이 "죽어 있다" 고 지목한 두 플래그 중 나머지 하나가 이것으로 닫힌다 |

- **R-42-57d** `wall_charm` 을 **소모품이 아니라 `key`** 로 둔 것이 핵심이다. 소모품 `effects` 에
  `change_tile(map, x, y, tile)` 을 굽는 순간 그 아이템은 **한 좌표에서만 의미가 있는** 물건이 되고,
  다른 곳에서 쓰면 엉뚱한 맵의 타일을 바꾼다. 좌표를 아는 쪽은 **벽**이므로 조건·효과를 벽이 갖는다 —
  이것이 원작의 `L1_ep1d1.cm2:31`(`if (Not(Flag::IsSet(GFD0_GET_WALL_REMOVER)))`)가 이미 하고 있던 구조다.
- **R-42-56** 위 20종 중 **9종은 [BP-22 §6.4·§6.5](22_world_bible_model.md) 가 이미 id 를 잡아 둔 것**을
  그대로 쓴다: `dagger`, `short_sword`, `short_spear`, `hand_axe`, `thick_clothes`, `leather_armor`,
  `potion_heal`, `teleport_ball`, `shard_of_gold`.
  **신규 11종**: `blessed_water`, `travel_ration`, `steel_sword`, `wooden_shield`, `iron_shield`,
  `chain_mail`, `armory_key`, `wall_charm`, `gatekeeper_seal`, `lore_ale`, `worn_logbook`. (9 + 11 = 20)
- **R-42-57** [BP-22 §6.5](22_world_bible_model.md) 가 시드로 올린 **해독의 약초·의식의 약초·부활의 약초·
  마법 회복약·소환 두루마리·비행 부츠·크리스탈 5종**은 **v1 카탈로그에서 뺀다**.
  대응하는 `do` 가 없어 R-22-18(효과 없는 소비품 금지)에 걸리기 때문이다(§3.3, Q-42-1).
  id 는 예약 상태로 남기고 DSL 확장 후에 넣는다. **R-42-57a 의 대형 횃불·수정 구슬이 이 목록에 합류한다** — 예약 총 9종.
- **R-42-58** `item.core.armory_key`·`item.core.wall_charm`·`item.core.gatekeeper_seal`·`item.core.lore_ale` 은
  `L1_ep1d0.cm2:134` 의 `GFD0_GET_KEY_FOR_D1`, 같은 파일의 `GFD0_GET_WALL_REMOVER`,
  그리고 [BP-41 §41.8.3](41_journal_ui_spec.md) 의 저널 목업("문지기의 인장 1개를 구한다",
  "로어 에일을 문지기에게 건넨다")에 각각 대응한다. **기존 서사에 이미 존재하는 물건**부터 아이템화한다.
- **R-42-58a** 이동 구슬의 `warp` 목적지는 `CastleLore` 다. `MapInfos.json` 의 id 14 로 등록되어 있고
  `json` 필드가 없어 `Map014.json` 으로 폴백되며 **그 파일은 실재한다**(부록 D-1 의 7개 미해석 이름에 들지 않는다).
  다만 **좌표는 이 장이 정하지 않는다** — portal 앵커로 두고 [BP-26](26_entity_registry_and_anchors.md) 이 지정하며,
  [BP-33](33_validation_and_lint.md) 이 "warp 목적지가 통행 가능한 칸인가" 를 검사한다. 카탈로그에는 `x, y` 를 하드코딩하지 않는다.

### 7.5 `grade` — 보상 등급의 유도 규칙

[BP-23 QV-33](23_quest_model.md) 은 `give_item` 의 아이템 `grade` 와 퀘스트 `tier` 의 차이를 검사한다.
그런데 **[BP-22 §6.1](22_world_bible_model.md) 의 아이템 스키마에는 `grade` 필드가 없다.**

- **R-42-59** `grade` 는 **`value` 에서 유도**한다. 새 필드를 요구하지 않는다.

| grade | `value` 범위 | 대표 | 대응 퀘스트 tier |
|---|---|---|---|
| 1 | 1 ~ 150 | 회복약 60, 단검 120 | 1 |
| 2 | 151 ~ 500 | 가죽 갑옷 180, 단창 200, 무쇠 방패 260, 성수 300 | 1~2 |
| 3 | 501 ~ 2,000 | 강철 검 600, 사슬 갑옷 700, 이동 구슬 900 | 2~3 |
| 4 | 2,001 ~ 10,000 | (v1 카탈로그에 없음 — 값 0 명시 예외인 `shard_of_gold` 만 grade 4) | 3~4 |
| 5 | 10,001 이상 | (v1 카탈로그에 없음) | 4~5 |

| 예외 | 규칙 |
|---|---|
| **`value == 0` 인 아이템** | **`grade` 를 별도로 선언**한다. 값이 없다고 등급이 낮은 것이 아니다 — `shard_of_gold` 는 값 0에 grade 4, `wall_charm` 은 값 0에 grade 2 |
| `unique: true` | grade 를 **최소 4** 로 강제 |

> 예외 조항의 조건은 **`value == 0`** 이며 category 가 아니다. `lore_ale` 은 `quest` 이지만 `value 25` 를 가지므로
> 유도 규칙을 그대로 따라 grade 1 이다 — "quest 면 값이 0" 이 아니다.

**전수 검산 (20종)** — 유도 grade 와 표기 grade 가 전부 일치한다.

| `value` → 유도 grade | 해당 아이템 | 표기 | 판정 |
|---|---|---|---|
| 20 / 25 / 30 / 40 / 60 / 60 / 70 / 120 → **1** | 마른 양식 · 로어 에일 · 항해 일지 · 단도 · 회복약 · 두꺼운 옷 · 나무 방패 · 단검 | 1 | ✅ |
| 180 / 200 / 240 / 260 / 300 → **2** | 가죽 갑옷 · 단창 · 작은 도끼 · 무쇠 방패 · 성수 | 2 | ✅ |
| 600 / 700 / 900 → **3** | 강철 검 · 사슬 갑옷 · 이동 구슬 | 3 | ✅ |
| 0 (명시 예외) | 무기고 열쇠 1 · 문지기의 인장 1 · **허무는 부적 2** · 황금방패의 조각 4(`unique` 최소 4) | 명시 | ✅ |

- **정정 기록**: 초판은 `가죽 갑옷`(value 180)을 grade **1** 로 적어 유도 규칙(151~500 → 2)과 어긋났다.
  20종 중 유일한 불일치였고, **grade 2** 로 올려 해소했다. 값을 150 이하로 내리는 쪽은 택하지 않았다 —
  §7.7 의 시작금 490 세트 검산과 §7.3 의 `ac 5` 위치가 180 을 전제하고, §7.6 이 이 아이템을
  `quest_reward`/`chest`(tier 1~2)에 두므로 grade 2 가 오히려 자연스럽다.
- **R-42-59a** [BP-23 QV-33](23_quest_model.md) 은 `give_item` 아이템의 `grade` 와 퀘스트 `tier` 의 차이를
  **린트로 검사**한다. 따라서 위 검산은 **카탈로그 커밋 전에 반드시 통과해야 하는 자기 정합 조건**이다 —
  유도 규칙과 표기가 어긋난 채 커밋되면 린트가 첫 실행부터 자기 데이터를 반박한다.

- **Q-42-2** `grade` 를 유도로 둘 것인가, [BP-22](22_world_bible_model.md) 에 명시 필드를 요청할 것인가.
  유도는 "값을 올리면 등급이 뛴다" 는 부작용이 있다. 값 0 예외가 **4건**(20종 중)이 되었으므로
  Q-42-2 의 잠정 답("예외가 3개를 넘으면 명시 필드로 전환")의 **문턱을 이미 넘었다** → §9.3 에서 판정을 갱신한다.

### 7.6 획득처 배분 (`sources`) — 상점 없이 성립시키기

상점은 1차 스코프 밖이다([BP-40 §40.5.4](40_gameplay_changes.md)). 따라서 `value` 는 **매매가가 아니라 가치 척도**로만 쓰인다.

| item | `sources` |
|---|---|
| 단검, 두꺼운 옷 | `start_kit`, `quest_reward` — `lore_ep1.cm2:382` 무기고 지급 대사에 직접 대응 |
| 단도, 나무 방패, 회복약, 마른 양식 | `chest`, `npc_gift` |
| 로어 에일 | `npc_gift`, `quest_reward`(tier 1) — 주점 NPC 가 내주는 물건이므로 `chest` 에 두지 않는다 |
| 단창, 작은 도끼, 가죽 갑옷, 무쇠 방패 | `quest_reward`, `chest` |
| 성수 | `quest_reward`(tier 1~2), `hidden` |
| 강철 검, 사슬 갑옷, 이동 구슬 | `quest_reward`(tier 2~3) |
| 무기고 열쇠, 문지기의 인장 | `quest_reward`, `hidden` |
| 허무는 부적 | `chest`, `hidden` — 원작에서도 굴 안에서 얻는 물건이다(`L1_ep1d0.cm2`) |
| 낡은 항해 일지 | `chest`, `hidden` |
| 황금방패의 조각 | `hidden` — `lore_ep1.cm2` 의 도둑 대사가 메너스에 숨겼다고 말한다 |

**획득처와 §7.2 의 진행 가능성 연동** (R-42-51a 가 요구한 것)

| tier | 그 시점에 손에 들 수 있는 최선 무기 | 상대 가능한 적 레벨 | 근거 |
|---|---|---|---|
| 0(시작) | 단검 `power 15` (`start_kit`) | 1~2 | Troll 1타(§7.2) |
| 1 | 단창 / 작은 도끼 (`quest_reward`, `chest`) | 1~3 | Goblin 약 4타 |
| 2~3 | 강철 검 (`quest_reward` tier 2~3) | 3~4 | Goblin 약 3타 |

- **R-42-60a** `단도`(power 5)는 **어떤 tier 에서도 유일 무기가 되지 않는다.** `chest`/`npc_gift` 전용이며,
  시작 지급(`start_kit`)에는 `단검` 만 들어간다(R-42-62). 단도만 든 상태로 레벨 3 적을 만나면
  기댓값 0.80 으로 사실상 진행 불가이므로(R-42-51a), 이 배분이 **밸런스가 아니라 진행 가능성의 조건**이다.
  검사는 [BP-34](34_headless_sim_and_solver.md) 의 솔버가 "그 경로에서 손에 들 수 있는 최선 무기" 를
  상태에 포함하는지에 달려 있다 — §9.2 로 넘긴다.

- **R-42-60** **모든 아이템의 `sources` 는 비어 있지 않다.** [BP-22 R-22-21](22_world_bible_model.md) 이
  "획득 불가능한 아이템을 `acquire` 목표로 요구하면 하드 실패" 를 규정하므로, 카탈로그 단계에서
  획득처가 없는 아이템을 만들지 않는다.
- **R-42-61** `unobtainable` 태그를 쓰는 아이템은 v1 카탈로그에 **0개**다.
- **R-42-61a** **아이템 획득을 `chance` 조건만으로 가르지 않는다** (D-30 의 재굴림 악용).
  `chance` 의 정본 유도식은 `chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p` 이고 **`step` 을 포함**하므로,
  같은 위치의 결과가 **월드가 진행하면 바뀐다.** 즉 플레이어가 상자 앞에서 나갔다 다시 들어오면 **다시 굴릴 수 있다.**
  - `chest`/`hidden` 획득처에 `chance` 로 확률 전리품을 붙이면 **아이템을 무한히 파밍**할 수 있게 되고,
    §7.7 의 값 척도(시작금 500 = 여관 10박)가 즉시 무의미해진다.
  - **규범**: `chance` 로 갈랐으면 그 결과를 **Effect 의 `set_flag` 로 래치**하고, 이후 방문은 `flag` op 로 읽는다.
    래치는 상태 변경이므로 정의상 Effect 의 일이다 — Condition 만으로 영구 결과를 만들려는 설계는 하지 않는다.
  - `container` 앵커의 `contents` 는 **한 번만 열린다**는 것이 기본이며, 그 "한 번" 을 보장하는 것도 같은 래치다.
    배치 규약의 소유는 [BP-26 §2.3](26_entity_registry_and_anchors.md), 래치 누락 검사는 [BP-33](33_validation_and_lint.md)(WARN).
  - **v1 카탈로그 20종의 `sources` 에는 확률 전리품이 하나도 없다** — 전부 결정적 획득처다. 이 규범을 어기는 데이터가 0건이다.

### 7.7 총 가치 감각 검산

| 시나리오 | 계산 |
|---|---|
| 시작금 500 으로 살 수 있는 것 | 단검 120 + 가죽 갑옷 180 + 나무 방패 70 + 회복약 2개 120 = **490** — 정확히 한 벌 |
| tier1 퀘스트 1건(골드 100~400) | 회복약 **1~6개**(100÷60 = 1.67 → 1 / 400÷60 = 6.67 → 6) 또는 단도 2~10자루(100÷40 = 2.5 → 2 / 400÷40 = 10) |
| tier1 퀘스트 3건 완주 | 가죽 갑옷 + 무쇠 방패 (합 440) 정도 |
| 성수(300)에 도달 | tier1 퀘스트 1~3건. 회복약 5개(300)와 같은 값이므로 "한 번에 다 낫는다" 의 대가가 명확하다 |
| 강철 검(600)에 도달 | tier2 퀘스트 1건(300~1,000) 또는 레벨3 적 3기 전투 45골드 × 약 13.3회 |
| 여관 1박(50) 환산 | 15골드/전투 × 3.33회 = 1박. 시작금 500 = 10박 = 전투 33회분 |

(초판은 "회복약 2~6개" 로 적었으나 하한이 1개다 — 100 ÷ 60 = 1.67. 나머지 검산은 그대로 성립한다.)

- **R-42-62** 시작금 500 이 **"기본 한 벌 + 약간"** 이 되게 값을 잡았다. 원작에서 무기고가 무기를
  **공짜로** 준다는 사실(`lore_ep1.cm2`)과 겹치면 초반이 지나치게 풍족해지므로,
  무기고 지급은 `단검` **하나**로 한정한다.

---

## 8. 월드 이벤트 발행 — `item_gained` / `item_lost`

### 8.1 지금은 발행 지점이 **없다** (D-20 이 지적한 사실)

D-20 은 12종 이벤트 이름을 정본으로 확정하면서, 그중
**`item_gained` / `item_lost` 는 인벤토리가 없어 현재 발행 지점이 존재하지 않으며,
BP-42 가 만들 때까지 미발행임을 각 장이 명시해야 한다**고 규정했다.

- **R-42-63** **이 장이 그 발행 지점을 만든다.** 이 장이 구현되기 전까지 두 이벤트는 **한 번도 발행되지 않으며**,
  그에 의존하는 목표 종류(`acquire`, `deliver`)와 조건(`has_item`)은 **항상 거짓**이다.
  다른 장이 "덮는다" 고 쓴 서술은 이 장의 구현 이후에만 참이 된다.

### 8.2 정본 이름과 payload

**이름 2종은 `item_gained` / `item_lost` 그대로다.** `item_acquired`, `itemGained`, `item_removed` 같은
변형을 만들지 않는다(D-20: 소문자 snake_case, 변형 이름 전량 폐기).

**payload 는 본 장이 정의하지 않는다.** 정본은 소유 장
[BP-23 §23.11.1](23_quest_model.md) 의 12행 표이며 `{itemId, delta, total}` 이다.
본 장은 그 필드를 **채워 주는 쪽**일 뿐이므로 스키마를 전재하지 않는다(D-18 / D-25).

- **R-42-64** 이름은 위 2종 그대로. 변형 금지.
- **R-42-65** 발행 시점은 `MutableWorldState.giveItem` / `takeItem` **성공 직후**다.
  실패(용량 초과·수량 부족)했으면 발행하지 않는다.
- **R-42-66** `delta` 는 **이번 변화량의 절댓값**이며 항상 양수다 — 방향은 이벤트 이름이 말한다.
  `total` 은 **변화 후 소지 수량**이다. 본 장의 인벤토리 구현이 두 값을 모두 알고 있으므로 채울 수 있다.
- **R-42-67** `total` 이 필수인 이유: `acquire(itemId, count:3)` 같은 카운터형 목표를
  **이벤트 하나로 판정**하려면 누적 수량이 필요하다. `delta` 만으로는 목표 달성 여부를 알 수 없다.

> **해소 기록 (Q-42-3)**: 초판은 D-20 표의 `{itemId, count}` 를 정본으로 보고 BP-23 과 충돌한다고 기록했다.
> **D-20a 가 이를 중재해 BP-23 이 정본으로 확정**되었다 — D-20 초판 표는 조정자가 소유 장을 옮겨 적다 낸 오기였고,
> `count` 단일 필드로는 위 R-42-67 의 판정이 성립하지 않는다.
> D-25 는 이 사고를 계기로 "결정 문서조차 스키마를 전재하지 않는다" 를 규칙으로 만들었다. **Q-42-3 종결.**

### 8.3 발행 규칙

```dart
// lib/domain/content/world_state.dart (D-11 배치) — 의사 코드

/// 48종 상한의 분모. quest/key/relic 은 세지 않는다 (R-42-11).
bool get _cappedCategory(String id) =>
    !const {'quest', 'key', 'relic'}.contains(catalog.require(id).category);
int _countCapped() => inventory.keys.where(_cappedCategory).length;

int giveItem(String itemId, int count) {
  if (count <= 0) return 0;                       // R-42-68
  final item = catalog.require(itemId);
  final cur  = inventory[itemId] ?? 0;
  final cap  = item.stackable ? item.maxStack : 1;
  if (cur >= cap) return 0;                       // R-42-10: 거부, 이벤트 없음
  if (cur == 0 && _cappedCategory(itemId) && _countCapped() >= 48) return 0;   // R-42-11
  final added = min(count, cap - cur);
  inventory[itemId] = cur + added;
  step++;                                          // D-08a 논리 시각
  emit('item_gained', {
    'itemId': itemId,
    'delta' : added,                               // 실제 변화량, 항상 양수 (R-42-66)
    'total' : inventory[itemId],                   // 변화 후 소지 수량 (R-42-67)
  });
  return added;
}

int takeItem(String itemId, int count) {
  if (count <= 0) return 0;
  final cur = inventory[itemId] ?? 0;
  if (cur == 0) return 0;                          // 없는 것을 뺐다 — 이벤트 없음
  final removed = min(count, cur);
  if (cur - removed <= 0) { inventory.remove(itemId); }   // INV-3
  else { inventory[itemId] = cur - removed; }
  unequipOverflow(itemId);                          // R-42-7
  step++;
  emit('item_lost', {
    'itemId': itemId,
    'delta' : removed,
    'total' : inventory[itemId] ?? 0,               // 키가 제거되었으면 0
  });
  return removed;
}
```

| # | 규칙 |
|---|---|
| **R-42-68** | `count <= 0` 은 **아무 일도 하지 않는다.** 예외를 던지지 않는다 — 보상 지급 중 예외가 나면 퀘스트가 완료로 못 간다. **`count` 는 호출 인자(요청량)이고 payload 의 `delta` 는 실제 변화량이다** — 99개 스택에 5개를 더 주면 변화 0 이므로 이벤트를 아예 발행하지 않는다(아래 R-42-68a) |
| **R-42-68a** | 변화가 0이면 이벤트를 **발행하지 않는다.** `delta: 0` 을 발행하면 `acquire` 카운터가 헛돈다 |
| **R-42-69** | 한 Effect 배열 안에서 `give_item` 이 여러 번 나오면 **각각 별개 이벤트**다. 합치지 않는다. `deliver` 목표가 "같은 배치 안의 `talk` + `item_lost` 조합" 을 보기 때문([BP-23 §23.11.2](23_quest_model.md)) |
| **R-42-70** | 장착·해제는 이벤트를 **발행하지 않는다.** 인벤토리 수량이 변하지 않기 때문(R-42-4) |
| **R-42-71** | 소모품 사용은 `take_item(id, 1)` 을 거치므로 `item_lost` 를 **발행한다** |

### 8.4 이 발행이 살려 내는 것

| 이벤트 | 진행시키는 목표 | 출처 |
|---|---|---|
| `item_gained` | `acquire` (**S** 상태 재평가) | [BP-23 §23.11.2](23_quest_model.md) |
| `item_lost` | `acquire` (**S**), `deliver` (**P** — `talk` 과 조합) | 동상 |

- **R-42-72** `deliver` 는 **`talk` + `item_lost` 를 같은 배치에서** 봐야 하므로,
  "NPC 에게 건네기" 를 구현할 때 대화 노드의 `onEnter` 에 `take_item` 을 두고
  그 대화가 `talk` 이벤트와 **같은 배치**에 들어가게 해야 한다. 배치 경계 규약은 [BP-27](27_runtime_engine.md) 소유.
- **R-42-72a** `total` 이 R-42-69(배치 안에서 합치지 않는다)의 **부작용을 막는다.** 한 배치 안에서
  `give_item` 이 세 번 나오면 이벤트도 세 개이고 소비자는 **중간 상태**를 본다.
  `delta` 만 있으면 소비자가 그때마다 인벤토리를 다시 조회해야 하지만, `total` 이 있으면
  각 이벤트가 **그 시점의 확정 수량**을 들고 오므로 마지막 이벤트만으로 `acquire(count:3)` 이 판정된다.

**워크드 예시 — `로어 에일` 이 이 발행으로 실제로 동작하는 경로** (§7.4.1 R-42-57b 가 만든 것)

```
① 주점 NPC 대화 → onExit: give_item(item.core.lore_ale, 1)
     → giveItem → inventory{lore_ale:1} → emit item_gained {itemId, delta:1, total:1}
     → acquire(lore_ale, 1) 목표가 S 재평가에서 완료
② 문지기 대화 → onEnter: take_item(item.core.lore_ale, 1)
     → takeItem → 키 제거 → emit item_lost {itemId, delta:1, total:0}
     → 같은 배치의 talk 이벤트와 조합되어 deliver(lore_ale, actor.gatekeeper) 가 P 판정
③ 저널 목표 행이 `[v] 로어 에일을 문지기에게 건넨다` 로 바뀐다 ([BP-41 §41.8.3](41_journal_ui_spec.md))
```

- **R-42-72b** 위 3단계에 **`set_flag` 가 한 번도 등장하지 않는다.** 초판이 이 아이템에 붙였던
  `add_var(reputation_lore, 1)` 은 ①~③ 어디에도 필요하지 않았다 — 즉 그 효과는 **장식이었다**.
  R-42-23a 가 금지하는 것이 정확히 이 종류의 장식이다.

---

## 9. 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 9.1 확정한 것

| # | 확정 |
|---|---|
| R-42-0 | 아이템 효과가 세울 수 있는 파티 버프는 `magicTorch`/`walkOnWater`/`canUseEsp` **3종뿐**이다. 나머지 5종은 런타임이 읽지 않는다(§1.7) |
| R-42-1 | 스키마를 새로 정의하지 않는다. [BP-22 §6.1](22_world_bible_model.md) 15필드에 **값만** 채운다 |
| R-42-2·3·3a | 저장소는 `WorldState.inventory` 하나. **파티 공용**이며 소지자 개념이 없다. 개인 소지품은 창·키 예산과 원작 구조 양쪽에서 기각(§2.2) |
| R-42-4~8 | **장착은 참조다.** 인벤토리에서 빠지지 않으며 불변식 EQ-1(존재)·EQ-2(수량 ≥ 장착 인원)가 정합을 지킨다. `has_item` 은 인벤토리만 본다 |
| R-42-9~11b | 정렬은 `category` 고정 순서 → `itemId` 사전순(결정론), 가상 항목은 탭 0번 행 고정. 종류 상한 48 이며 **`quest`/`key`/`relic` 은 상한 밖**. 초과 획득은 **거부 + 이벤트 미발행** 이고, 실제 방어선은 빌드 린트다 |
| R-42-12 | 인벤토리 변경 경로는 `giveItem`/`takeItem` **두 함수뿐** |
| R-42-16~21 | 퀘스트 아이템: 버리기·매매 불가, 효과 없음, **회수는 `take_item` 명시로만**(자동 회수 없음) |
| R-42-22~23b | v1 은 **③ 관측 가능한 효과를 가진 소모품만** 넣는다. 해독·부활·버프·시야·평판은 DSL 확장까지 보류하고, **어떤 아이템도 `set_flag`/`add_var` 를 단독 효과로 쓰지 않는다** |
| R-42-24~28 | 표시는 아이템 ID 우선, cm2 가 정수를 만지면 정수 폴백으로 되돌아간다. 정수 → 아이템 매핑은 **선언**이며 `books.json` id 와 무관 |
| R-42-29~33b | `powOfWeapon ← equip.power`(덮어쓰기), `ac ← armor.ac + shield.ac`(**합산**), `powOfArmor`/`powOfShield` 는 **표시용 사본 + 폐기 예정**. 덮어쓰기의 전제는 "`ac` 는 레벨업으로 성장하지 않는다"(실측) |
| R-42-33c~33f | **전투식 변경은 이 장의 선행 과제가 아니다** — `ac` 합산이 그 필요를 제거했다(§4.5 A 갈래). 방패 별개 축·무기 상성·부위별 감쇠는 B 갈래이며 전투식 변경이 선행. 카탈로그 수치 중 실제로 게임을 움직이는 것은 **`power` 5 + `ac` 5 + `effects` 4 = 14개**이고 `weaponType`·`value`·`powOfArmor` 사본은 현행 빌드에서 무효 |
| R-42-34 | `books.json` 의 `power` 는 그대로, **`ac` 는 재척도**(10→2, 20→5). 원값은 전투식과 호환되지 않는다 |
| R-42-36·37 | 소지품 창은 저널과 **같은 기하학·같은 키**. "인벤토리" 라는 말을 쓰지 않는다 |
| R-42-37a~37c | `물건` 탭이 `quest`·`relic`·`crystal` 을 합쳐 탭 7개. **대화 진행 중에는 소지품·저널을 열 수 없다**(불변식, 3단 실측 근거) |
| R-42-38·39 | 못 하는 행동은 회색이 아니라 **삭제**. 대신 이유를 한 줄로 말한다 |
| R-42-44~49 | `equipped*` 는 `party` 봉투 안. v1 마이그레이션은 인벤토리에 1개를 넣고(EQ-1), **이벤트를 발행하지 않으며**, `powOfWeapon`/`ac` 를 재계산하지 않는다 |
| R-42-50~55a | **맨손 = 0 데미지**(유지). 무기 사다리 5/15/20/22/30, 갑옷 0/2/5/9, 방패 2/4. §7.2·§7.3 의 수치는 **난수 조합 전수 열거**로 얻은 기댓값·확률이며, `books.json` 의 ac 10/20 은 "항상 0" 이 아니라 **피해 턴 36%/16%** 다 |
| §7.4 | **초기 `core` 카탈로그 20종**을 id·이름·분류·스택·값·grade·성능·설명까지 확정 (consumable 4 · weapon 5 · shield 2 · armor 3 · key 2 · quest 2 · lore 1 · relic 1) |
| R-42-57a~57d | **대형 횃불·수정 구슬은 v1 에서 제외**(id 예약) — 읽는 런타임이 없다. **로어 에일은 `quest` 로 전환** — `deliver` 대상이 그 실제 용도다. 빈 자리는 **성수**(`heal_party(100)`)와 **허무는 부적**(`key`, 벽 트리거의 `has_item`+`change_tile`)이 채운다 |
| R-42-59·59a | `grade` 는 `value` 밴드에서 유도(1~150 / ~500 / ~2,000 / ~10,000 / 초과). **`value == 0` 인 아이템**은 명시(category 조건이 아니다), `unique` 는 최소 4. 20종 전수 검산 일치 — 가죽 갑옷은 grade **2** |
| R-42-60~61a | 모든 아이템에 획득처가 있다. `unobtainable` 0개. **아이템 획득을 `chance` 만으로 가르지 않는다**(D-30 의 재굴림 악용 — `step` 이 시드에 들어가므로 나갔다 들어오면 다시 굴릴 수 있다). 갈랐으면 `set_flag` 로 래치한다. v1 20종의 `sources` 는 전부 결정적이다 |
| **R-42-63** | **`item_gained`/`item_lost` 의 발행 지점은 지금 존재하지 않으며 이 장이 만든다**(D-20) |
| R-42-64~72b | 이름은 D-20 정본 그대로, payload 는 **본 장이 정의하지 않고 [BP-23 §23.11.1](23_quest_model.md) 소유**(`{itemId, delta, total}`). `delta` 는 변화량 절댓값(양수), `total` 은 변화 후 수량. 변화 0이면 미발행, 장착/해제는 미발행 |

### 9.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| `WorldState.inventory` 직렬화·키 정렬·세이브 봉투 v2 전체 | [BP-25](25_world_state_and_save.md) |
| `giveItem`/`takeItem` 의 배치 경계·이벤트 큐 처리 순서 | [BP-27 §7.5](27_runtime_engine.md) |
| 아이템 관련 린트 규칙 ID·심각도(효과 없는 소비품, 회수 누락, 획득처 없음, grade-tier 괴리) | [BP-33](33_validation_and_lint.md) |
| `item.core.*` 표시 문자열의 실제 문안과 어미·길이 | [BP-43](43_content_style_guide.md) |
| 아이템 CRUD 엔드포인트(`/api/content/items`) | [BP-31 §2.4](31_content_server_api.md) |
| `container` 앵커의 `contents` 배치 | [BP-26 §2.3](26_entity_registry_and_anchors.md) |
| 소모품 효과 확장을 위한 `schemaVersion` 승격 계획 | [BP-21 §7](21_content_pack_spec.md), [BP-50](50_roadmap.md) |
| `books.json` 을 `assets/_legacy/` 로 옮기는 작업 (**부록 A-4**: `pubspec.yaml` 의 asset 선언이 비재귀이므로 `assets/_legacy/` 를 열거하지 않으면 번들에서 사라진다 — 읽는 코드가 없어 무해하나 이관 스크립트가 알아야 한다) | [BP-28](28_migration_and_coexistence.md), [BP-35](35_ci_and_build.md) |
| **`Effect` → `PartyBuffs` 다리** — `magicTorch`/`walkOnWater`/`canUseEsp` 를 세우는 경로. 현재 어느 장에도 없고, 대형 횃불(R-42-57a)의 선결 조건이다 | [BP-27](27_runtime_engine.md) |
| **전투식 변경(§4.5 B 갈래)** 이 선행 과제라는 사실과 그 착수 시점. §7.2·§7.3 의 기준값 재계산이 함께 간다 | [BP-40 §40.1.2](40_gameplay_changes.md), [BP-50](50_roadmap.md) |
| **"한 팩 합성 결과의 상한 대상 카테고리 종류 수 ≤ 48"** 린트(R-42-11a) | [BP-33](33_validation_and_lint.md) |
| **런타임 조건 때문에 발행되지 않는 이벤트**는 D-26 의 `SUPPORTED` 축으로 잡히지 않는다(§2.4). 솔버가 인벤토리 용량과 "그 경로에서 들 수 있는 최선 무기"(R-42-60a)를 상태 공간에 넣을지 판단 | [BP-34](34_headless_sim_and_solver.md), [BP-53](53_acceptance_criteria.md) |
| 적 HP 정본은 `domain/battle/enemy.dart` 생성자(`hp = endurance * level; if (hp <= 0) hp = 1;`)이며 `player.dart assignFromEnemyData` 는 영입 경로다 | [BP-22](22_world_bible_model.md), [BP-23](23_quest_model.md) |
| `HDPlayer.ac` 가 레벨업으로 성장하지 않는다는 사실이 R-42-30 덮어쓰기의 전제다(R-42-33a) | [BP-27](27_runtime_engine.md) |
| 이동 구슬 `warp` 목적지 좌표(`CastleLore` 의 portal 앵커) | [BP-26](26_entity_registry_and_anchors.md), [BP-33](33_validation_and_lint.md) |

**남기는 태스크**

| # | 태스크 |
|---|---|
| **T-42-1** | `HDPlayer` 에 `equippedWeapon/Shield/Armor` 추가 + `getWeaponName()` 등 3개를 카탈로그 조회로 교체(정수 폴백 유지) |
| **T-42-2** | `powOfArmor`/`powOfShield` 선언에 폐기 예정 주석 추가(R-42-32) |
| **T-42-3** | `menu_flows.dart` 에 7번 항목 `소지품을 살핀다` + `showInventory()` 추가 |
| **T-42-4** | `assets/content/items/items.json` 에 §7.4 의 20종 작성 + `strings/ko.json` 에 이름·설명 40개 |
| **T-42-5** | `assets/maps/books.json` → `assets/_legacy/books.json` 이동, 폐기 예정 표시 |
| **T-42-6** | `MutableWorldState.giveItem/takeItem` 구현 + §8.3 규칙에 대한 단위 테스트(스택 상한·48종 상한과 **상한 밖 카테고리**·EQ-2 해제 순서·이벤트 미발행 조건·payload `delta`/`total` 값) |
| **T-42-7** | 회귀 1건: **대화 대기 중(`isWaitingForKey`)에 Space/Esc/Q 를 눌러도 소지품·저널이 열리지 않는다**(R-42-37b). `input_dispatcher` 의 모드 우선순위가 바뀌면 이 테스트가 먼저 깨져야 한다 |
| **T-42-8** | 밸런스 회귀 1건: §7.2·§7.3 의 전수 열거 계산을 테스트로 굳힌다(`power 15` → Troll 1타, `ac 20` → Troll 피해 턴 16%). 전투식을 고치면 이 테스트가 깨지므로 §4.5 B 갈래 착수를 강제로 인지하게 된다 |

### 9.3 열린 질문

| # | 질문 | 왜 지금 못 정하는가 | 잠정 |
|---|---|---|---|
| **Q-42-1** | 해독·의식 회복·부활·SP 회복·**버프 부여**·시야 확장 효과를 v1 DSL 에 추가할 것인가 | D-05 는 닫힌 집합이고 확장은 `schemaVersion` 승격을 요구한다. 원작 소비품 10종 중 6종이 여기 걸린다([BP-22 G-22-2](22_world_bible_model.md)). **버프 부여는 do 하나가 아니라 `Effect` → `PartyBuffs` 다리(§1.7)까지 요구한다** | v1 카탈로그에서 제외하고 id 만 예약(**총 9종** — R-42-57 의 7종 + 대형 횃불 + 수정 구슬). M2 에서 `heal_status(kind)` + `grant_buff(kind, n)` 둘로 묶어 승격 검토 |
| **Q-42-2** | `grade` 를 `value` 유도로 둘 것인가, [BP-22](22_world_bible_model.md) 에 명시 필드를 요청할 것인가 | `value == 0` 예외가 **20종 중 4건**(무기고 열쇠·허무는 부적·문지기의 인장·황금방패의 조각)이 되어 초판 잠정 답의 문턱(3건)을 넘었다 | **명시 필드로 전환을 [BP-22](22_world_bible_model.md) 에 요청**한다(§9.2). 전환 전까지는 유도 + 명시 예외로 운용하고, §7.5 의 전수 검산표를 정본으로 둔다 |
| ~~**Q-42-3**~~ | `item_gained`/`item_lost` 의 payload 정본 | — | **종결.** D-20a 가 [BP-23 §23.11.1](23_quest_model.md) 의 `{itemId, delta, total}` 을 정본으로 확정. D-20 초판 표는 조정자의 전재 오기였고 D-25 로 전재 자체가 금지되었다. §8.2 참조 |
| **Q-42-4** | `crystal` 카테고리를 v1 에 넣을 것인가 | 원작 크리스탈 5종은 마법 계열 강화에 쓰이는데 그 규칙이 `magic_system.dart`(280줄)에 없다. §1.7 의 `canUseSpecialMagic` 이 그 자리로 보이지만 **읽는 곳이 0건**이다 | v1 카탈로그에서 제외. 카테고리는 스키마에 남겨 두고 `물건` 탭이 받는다(R-42-37a) |
| **Q-42-5** | 무기고가 무기를 공짜로 주는 원작 동작(`lore_ep1.cm2`)을 유지하면서 값 척도가 성립하는가 | 지급 무기가 여러 종이면 초반 경제가 무의미해진다 | 지급을 `단검` 하나로 한정(R-42-62). 실플레이 후 재조정 |
| **Q-42-6** | 장비 표시명 8자 제한(R-42-43)이 카탈로그 20종에 충분한가 | `황금방패의 조각`(7자)이 이미 근접. 장비는 아니지만 목록 행에는 뜬다. 장비 최장은 `작은 도끼`/`가죽 갑옷`/`사슬 갑옷`/`무쇠 방패`/`나무 방패`(각 5자) | 장비만 8자, 그 외 12자. [BP-43](43_content_style_guide.md) 이 문체 관점에서 재확인 |
| **Q-42-7** | 48종 상한에 도달했을 때 사람이 무엇을 버려야 하는지 알 수 있는가 | 초판 잠정 답("카탈로그 20종이므로 발생 불가")은 **틀렸다** — 상한은 카탈로그 크기가 아니라 **팩 합성**(D-03: `core` + `gen_ep1` 겹쳐 쓰기)에 달려 있고, 거부해도 퀘스트는 똑같이 막힌다(§2.4) | **답을 바꿨다**: ① `quest`/`key`/`relic` 을 상한 밖으로(R-42-11) ② 빌드 린트가 합성 결과를 사전 검사(R-42-11a) ③ 런타임 거부는 최후 방어선. 남는 질문은 "6개 카테고리가 실제로 48종을 채우는 팩이 나올 때 UI 가 무엇을 안내하는가" 이며, 상점·제작 도입 시점으로 미룬다 |
| **Q-42-8** | `허무는 부적`(R-42-57d)의 `change_tile` 을 **어느 앵커가** 갖는가 | 조건·효과를 벽이 갖는다는 것까지는 확정했으나, 그 벽이 `trigger` 앵커인지 `portal` 앵커인지는 [BP-26](26_entity_registry_and_anchors.md) 소유다. D-27 이 region 예약을 폐기했으므로 트리거 인덱스 직접 조회 경로를 쓴다 | `trigger` 앵커 + `has_item` 조건 + `change_tile` 효과. 좌표는 원작 `L1_ep1d1.cm2:31` 이 검사하는 벽 위치를 이관 시 확정([BP-28](28_migration_and_coexistence.md)) |
