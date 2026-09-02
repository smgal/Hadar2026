# G1-01 `Item`/`ItemSub`/`ITEM_TYPE` 을 `domain/item/` 으로 이식한다

- **상태**: TODO
- **구간**: G1
- **규모**: M
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 H-1(정정판) · H-3](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md) · [DECISION-LOG 3차 판정](../DECISION-LOG.md)
- **참고만**: [BP-42 §1.4·§7](../../blueprint/42_item_and_inventory.md) — 이 장은 `상태: 보류`(선언적 콘텐츠 팩 노선)다. 카탈로그 초안과 계산표만 인용하고 `WorldState`·선언적 스키마는 **채택하지 않는다**.

## 문제

### Dart 에는 아이템이라는 타입이 없다

`hadar2026_app/lib/domain/party/player.dart:44-46` (직접 확인):

```dart
int weapon = 0;
int shield = 0;
int armor = 0;
```

정수 3칸이 전부고, 이름은 `:91-93` 이 문자열로 만들어 낸다:

```dart
String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
String getShieldName() => shield == 0 ? "없음" : "방패$shield";
String getArmorName() => armor == 0 ? "평상복" : "갑옷$armor";
```

`domain/` 하위에 `item` 디렉토리가 없다(`battle`·`console`·`lighting`·`magic`·`map`·`party`·`system`·`text`·`window` 뿐).

### 원작에는 완성된 타입이 있다

`REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs:12-25` — `ItemSub { double atta_pow; double ac; ITEM_TYPE item_type; }` + `GetDefault()`.
같은 파일 `:30-34` — `Item { ResId res_id; string name; ItemSub param; string annex; }`.
`REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs:32-49` — `ITEM_TYPE` 열거. 정수값을 전수 확인했다:

| 멤버 | 값 | 그룹 |
|---|---|---|
| `NONE` | -1 | — |
| `WIELD` `CHOP` `STAB` `HIT` `SHOOT` `SUMMON_SINGLE` `SUMMON_MULTI` | 0~6 | `WEAPON_MIN=0` ~ `WEAPON_MAX=7` |
| `SHIELD` | 7 | `SHIELD_MIN=7` ~ `SHIELD_MAX=8` |
| `ARMOR` `HEAD` `LEG` | 8~10 | `ARMOR_MIN=8` ~ `ARMOR_MAX=11` |
| `ORNAMENT` | 11 | `ETC_MIN=11` ~ `ETC_MAX=12` |

**부위 개념이 원작에 있다.** 현재 Dart 는 3칸뿐이라 `HEAD`/`LEG`/`ORNAMENT` 를 표현할 수 없다.

## 왜 지금 고쳐야 하는가

- **재미** — 플레이어가 상태 메뉴에서 `"무기1"` 을 본다(`menu_flows.dart:275`). 아이템 타입이 없으면 [G1-06](G1-06-item-names.md) 이 고칠 대상 자체가 없다.
- **부채 방지** — 3차 판정([DECISION-LOG](../DECISION-LOG.md)): 플래그로 "열쇠 소지" 를 표현해 퀘스트를 만들면 인벤토리가 생길 때 **그 퀘스트를 전부 다시 써야 한다.** [S1](../S1-sample-quest/S1-01-quest-design.md) 이 G1 뒤로 간 이유가 이것이다.
- G1 의 나머지 8개 이슈가 전부 이 타입에 얹힌다. 여기서 축을 잘못 잡으면 [G1-09](G1-09-item-save.md) 의 세이브 마이그레이션을 두 번 한다.

## 무엇을 할 것인가

### 이식 대응표

| 원작 | Dart | 비고 |
|---|---|---|
| `ObjTypes.cs:32-49` `ITEM_TYPE` | `lib/domain/item/item_type.dart` — `enum HDItemType` | 아래 "sentinel 처리" 참조 |
| `ObjItem.cs:12-25` `ItemSub` | `lib/domain/item/item.dart` — `HDItemParam { int attaPow; int ac; HDItemType type; }` | `double` → `int`. 전투식이 정수 연산(`battle.dart:439`)이므로 |
| `ObjItem.cs:30-34` `Item` | 같은 파일 — `HDItem { HDItemId id; String name; HDItemParam param; String annex; }` | `annex` 는 문자열로 보관만. 파싱은 이 구간 밖 |
| `ObjItem.cs:42-231` `ResId` | `lib/domain/item/item_id.dart` — `HDItemId { HDItemType kind; int detail; int index; }` | **비트팩 폐기.** 아래 판단 참조 |

`domain/` 은 `package:flutter/foundation.dart` 만 import 가능하다([CLAUDE.md](../../CLAUDE.md) 계층 규칙). 이 4개 파일은 **import 0** 으로 쓸 수 있다.

### sentinel 처리 — C# 의 `*_MIN`/`*_MAX` 를 enum 멤버로 넣지 않는다

Dart enum 은 값 별칭을 만들 수 없어서 `WEAPON_MIN = WIELD` 를 그대로 옮길 수 없다. 대신:

- 각 멤버에 **명시적 wire 값**을 필드로 선언한다(`WIELD = 0` … `ORNAMENT = 11`, `none = -1`).
- 경계 질의는 getter 로: `isWeapon` · `isShield` · `isArmorGroup` · `isEtc` · `equipSlot`.

**`Enum.index` 를 쓰지 않는다.** `HDTileAction.scriptMode` 가 같은 이유로 명시적 wire 값을 갖고
`test/domain/map/tile_action_test.dart` 가 그것을 고정한다([CLAUDE.md](../../CLAUDE.md) "wire value, not an index").
아이템 타입은 [G1-09](G1-09-item-save.md) 의 세이브와 [G1-08](G1-08-cm2-item-commands.md) 의 cm2 인자에 실려 나가므로
멤버 순서를 바꾸면 세이브가 깨진다. 같은 규율을 적용한다.

### `ResId` 판단 — **비트팩은 생략하고 3축만 남긴다**

`ObjItem.cs:42-88` 의 주석이 밝힌 구조: 상위 2비트가 검증 태그(`00` invalid / `01` 아이템 / `10` 예약 / `11` 문자열),
아이템일 때 하위 24비트가 `type(8) | detail(8) | index(8)`(`:99-106`).
문자열 태그는 이름 6자를 자당 5비트로 눌러 담는다(`:120-149`).

**생략 근거**:
1. **검증 비트는 Dart 에서 타입 시스템이 대신한다.** `01`/`00` 구분은 "이 uint 가 아이템 id 인가" 를 런타임에 묻기 위한 것이고, Dart 는 `HDItemId?` 로 컴파일 시점에 답한다.
2. **문자열 태그(`VERIF_TAG_STRING`)는 쓰이지 않는다.** `ResId(string)` 생성자(`:120`)를 호출하는 곳이 `src_as_cs/` 전체에 없다(`grep`). 이름 6자·대소문자 무시·`1~4` 만 허용이라 한글 아이템 이름을 담을 수도 없다.
3. **`0x02U` 예약 태그도 미사용**이다.

**남겨야 하는 것**: `(type, detail, index)` **3축 좌표는 반드시 유지한다.**
`GameEventEquipment.cs:334-360` 이 가방을 부위별로 필터링할 때 `GetItemType()` 과 `GetItemDetail()` 을 쓴다
(예: 부위 3 = `ITEM_TYPE_TAG_ARMOR` + detail 1 = `HEAD`). 3축을 뭉개면 [G1-07](G1-07-inventory-ui.md) 의 필터를 다시 설계해야 한다.

또한 [G1-08](G1-08-cm2-item-commands.md) 이 cm2 에 정수 1개로 아이템을 넘기려면 3축을 정수 하나로 접어야 하므로,
`HDItemId.wire => kind.wire * 0x10000 + detail * 0x100 + index` 를 제공한다 — **`ResId` 하위 24비트와 같은 배치**다.
비트팩을 "버린다" 가 아니라 **상위 8비트(검증 태그)만 버린다**.

### `HDItemType.equipSlot`

`ObjTypes.cs:81-85` `EQUIP { HAND, HAND_SUB, ARMOR, HEAD, LEG, ETC }` 로의 사상을 타입에 붙여 둔다.
[G1-04](G1-04-equipment-slots.md) 가 이 getter 로 "이 아이템을 어느 칸에 넣을 수 있나" 를 판정한다.
`SUMMON_SINGLE`/`SUMMON_MULTI` 도 `HAND` 다(`ObjParty.cs:1651,1677` 이 소환수 손에 넣는다).

## 완료 판정 기준

- [ ] `lib/domain/item/` 에 `item_type.dart` · `item_id.dart` · `item.dart` 가 있고 **import 가 0줄**이다 (계층 위반 grep 2종 통과)
- [ ] `HDItemType` 이 `none`(-1) 포함 **13개 멤버**를 갖고, 각 멤버의 `wire` 가 위 표의 정수값과 일치한다
- [ ] `isWeapon`/`isShield`/`isArmorGroup`/`isEtc` 가 원작의 `*_MIN <= x < *_MAX` 구간과 같은 답을 낸다
- [ ] `HDItemId.wire` 가 `ResId` 하위 24비트와 같은 배치를 만든다 (`WIELD,0,1` → `0x000001`, `ARMOR(8),1,3` → `0x080103`)
- [ ] `HDItemType.equipSlot` 이 12종 전량에 대해 `EQUIP` 6칸 중 하나를 반환한다
- [ ] 테스트 추가: `hadar2026_app/test/domain/item/item_type_test.dart` —
      ① 12종 + `none` 의 `wire` 값을 **리터럴로** 고정한다(멤버 순서 변경을 실패로 만든다)
      ② `isWeapon`/`isShield`/`isArmorGroup`/`isEtc` 가 서로 배타적이고 합집합이 12종 전량임을 고정
      ③ `HDItemId.wire` ↔ `HDItemId.fromWire` 왕복을 고정
      ④ `equipSlot` 사상표를 전량 고정
- [ ] `flutter analyze --no-fatal-infos` 새 경고 0건

## 하지 않을 것

- **아이템 실데이터** — 이름·`attaPow`·`ac` 표 작성은 [G1-02](G1-02-item-data.md) 소관. 이 이슈는 **빈 타입**만 만든다.
- `annex` 문자열 파싱 — 원작은 `ObjItem.cs:668-729` 에서 `"ATT+1AC-1STR+1"` 같은 문자열을 정규식으로 푼다. 필드로 **보관만** 하고 해석은 G1 범위 밖.
- `ResId` 의 문자열 태그·검증 태그 복원, `ItemConv`/`Weapon`/`Shield`/`Armor`/`Props` 변환 클래스(`ObjItem.cs:745-877`) — Dart 는 테이블에서 바로 `HDItem` 을 만든다.
- 소환수 기술 power 수치 — 원작도 `ObjItem.cs:603-611` 이 TODO 로 남긴 미완성이다.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI. 전부 범위 밖.
