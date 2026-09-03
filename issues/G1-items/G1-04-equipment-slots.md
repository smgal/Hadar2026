# G1-04 장비 슬롯 재편 — 정수 3칸 → 부위별 6칸

- **상태**: DONE
- **구간**: G1
- **규모**: M
- **선행**: [G1-01](G1-01-item-model-port.md)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-1(정정판) · H-3 · F-1](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md) · [DECISION-LOG 3차 판정](../DECISION-LOG.md)

## 문제

### Dart 는 정수 3칸이다

`hadar2026_app/lib/domain/party/player.dart:44-46`:
```dart
int weapon = 0;
int shield = 0;
int armor = 0;
```

이 3개는 `getAttribute`(`:125-130`)·`changeAttribute`(`:344-352`)·`toJson`(`:422-424`)·`fromJson` 에 전부 실려 있고
cm2 가 실제로 쓴다 — `hadar2026_app/assets/menace.cm2:48` `Player::ChangeAttribute(6, "armor", 0)`.

### 원작은 6부위다

`REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs:81-85`:
```csharp
public enum EQUIP { HAND, HAND_SUB, ARMOR, HEAD, LEG, ETC, MAX }   // Leg -> Sabaton
```
`REF_UNITY_LoreEp1/src_as_cs/ObjPlayer.cs:152` `public Equiped[] equip = new Equiped[(int)EQUIP.MAX];`
`:304-305` 가 기본 장비를 채우고(`HAND` = WIELD index 0 = 맨손, `ARMOR` = index 0),
`:875-877` 은 `HAND`/`ARMOR`/`LEG` 3부위를 함께 채운다.

C++ 원본은 정수 3칸이다(`REF_hadar/src/hadar/hd_class_pc_player.h:60-62`) — **현재 Dart 는 C++ 세대 구조**이고,
Unity 포트에서 부위가 6칸으로 늘었다.

## 왜 지금 고쳐야 하는가

- **재미** — 투구·신발·장식이 없으면 장비가 3칸뿐이고, 보상으로 줄 물건의 종류가 3줄로 고정된다.
- **부채 방지** — 3차 판정이 명시한다: *"원작은 부위 개념(`HEAD`/`LEG`/`ORNAMENT`)을 갖는데 현재 Dart 는 3칸뿐이라 지금 만들면 두 번 어긋난다."*

## 무엇을 할 것인가

### 판단: **6부위를 처음부터 전량 넣는다**

| 근거 | 내용 |
|---|---|
| **세이브 마이그레이션이 두 번 필요해진다** | [G1-09](G1-09-item-save.md) 가 v1(정수 3칸) → v2(슬롯) 를 한 번 한다. 3부위로 만들면 나중에 v2 → v3 를 또 해야 하고, 그때는 이미 플레이 세이브가 존재한다 |
| **데이터가 이미 있다** | `ObjItem.cs:564-601` `PROPS_LIST` **33종**(HEAD 11 · LEG 11 · ORNAMENT 11). 슬롯이 없으면 [G1-02](G1-02-item-data.md) 가 옮겨 온 데이터가 사장된다 |
| **UI 를 두 번 쓰지 않는다** | `GameEventEquipment.cs:334-360` 의 부위 선택은 **6분기 switch** 다. 3부위로 만들면 [G1-07](G1-07-inventory-ui.md) 의 화면·커서·필터를 다시 쓴다 |
| **작업량 차이가 거의 없다** | `int` 3개 → `List<HDItemId?>` 6칸은 같은 한 번의 변경이다. 늘리는 비용은 슬롯 수가 아니라 **슬롯 개념의 도입**에 있다 |

**반론과 답**: `HEAD`/`LEG`/`ORNAMENT` 의 효과는 대부분 `annex` 문자열(`"ATT+1AC-1STR+1"`)이고 그 파싱은 G1 범위 밖이다
([G1-01](G1-01-item-model-port.md) 결정). → **슬롯은 6칸 전량 만들고, 효과는 `attaPow`/`ac` 항만 연결한다**([G1-05](G1-05-equipment-effect.md)).
장식을 끼워도 능력치가 안 변하는 것은 원작의 `annex` 미구현 상태와 같다 — 슬롯이 없어 **끼우지도 못하는 것**보다 낫다.

### 이식 대응표

| 원작 | Dart |
|---|---|
| `ObjTypes.cs:81-85` `EQUIP` | `lib/domain/item/equip_slot.dart` — `enum HDEquipSlot { hand, handSub, armor, head, leg, etc }` + 명시적 `wire` 0~5 |
| `ObjPlayer.cs:152` `Equiped[] equip` | `player.dart` — `final List<HDItemId?> equip = List.filled(6, null)` |
| `ObjPlayer.cs:390-420` `SetEquipment(part, ...)` | `bool equipItem(HDEquipSlot slot, HDItemId id)` — `HDItemType.equipSlot`([G1-01](G1-01-item-model-port.md))과 어긋나면 `false` |
| `GameEventEquipment.cs:112-133` `OnCurrentEquipmentRemove` | `HDItemId? unequip(HDEquipSlot slot)` |
| `GameEventEquipment.cs:122` 맨손은 해제 불가 | `hand` 슬롯의 `index == 0` 이면 `unequip` 이 `null` 반환 |

`wire` 는 [G1-01](G1-01-item-model-port.md) 과 같은 규율로 **명시 선언**한다 — 세이브에 실려 나가므로 `Enum.index` 금지.

### 기존 정수 3칸의 처리 — **삭제하지 않고 유도값으로 남긴다**

cm2 가 `Player::GetAttribute('weapon')`·`ChangeAttribute('armor', 0)` 를 실제로 쓴다(`menace.cm2:48`).
필드를 지우면 `player.dart:344-352` 의 `switch` 에서 케이스가 사라져 **조용히 무시**된다 — 부록 F-1 과 같은 침묵 실패다.

- **읽기**(`getAttribute`) — 해당 슬롯의 `HDItemId.index` 를 반환한다. 비었으면 0.
- **쓰기**(`changeAttribute`) — 값을 [G1-02](G1-02-item-data.md) 의 원작 인덱스 공간으로 해석해 슬롯에 장착한다.
  범위 밖이면 **경고 로그**를 남긴다(부록 F-1 의 재발 방지). `menace.cm2:48-52` 가 0 을 넣어 "장비를 잃는" 연출을 하므로 0 은 정상 입력이다.
- `powOfShield`/`powOfArmor` 는 여기서 건드리지 않는다 — [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md)·[G1-05](G1-05-equipment-effect.md) 소관.

## 완료 판정 기준

- [x] `HDEquipSlot` 6종이 `wire` 0~5 를 **명시 선언**하고 `ObjTypes.cs:81-85` 순서와 일치한다
- [x] `HDPlayer.equip` 이 6칸이고, `equipItem` 이 **부위가 맞지 않는 아이템을 거부**한다 (예: 갑옷을 `head` 에 못 넣음)
- [x] `hand` 슬롯의 맨손(`index == 0`)은 `unequip` 이 거부한다 (`GameEventEquipment.cs:122` 와 같은 동작)
- [x] `getAttribute('weapon'|'shield'|'armor')` 가 슬롯에서 유도한 index 를 반환한다 (cm2 기존 스크립트 무변경 동작)
- [x] `changeAttribute('armor', 0)` 이 `menace.cm2:48` 의 의도대로 갑옷을 벗기고, **범위 밖 값은 경고 로그**를 남긴다
- [x] `domain/` 계층 위반 grep 2종 통과
- [x] 테스트 추가: `hadar2026_app/test/domain/party/equipment_slots_test.dart` —
      ① 6칸 `wire` 값을 리터럴로 고정
      ② 부위 불일치 장착이 `false` 이고 슬롯이 **변하지 않음**
      ③ 맨손 해제 거부
      ④ `getAttribute('weapon')` ↔ 슬롯 왕복, 범위 밖 `changeAttribute` 가 슬롯을 바꾸지 않음
      ⑤ `menace.cm2:48-52` 시나리오(장비 전부 0)를 재현해 6칸이 전부 비는지 고정

## 하지 않을 것

- **효과 배선** — `powOfWeapon ← attaPow`, `ac` 합산은 [G1-05](G1-05-equipment-effect.md). 이 이슈는 **슬롯 자체**만 만든다.
- **세이브** — v1 정수 → 슬롯 마이그레이션은 [G1-09](G1-09-item-save.md).
- **화면** — 부위 선택 UI 는 [G1-07](G1-07-inventory-ui.md).
- `annex` 문자열 파싱(`ObjItem.cs:668-729`) — HEAD/LEG/ORNAMENT 의 능력치 보정은 G1 범위 밖이다.
- 원작 `Equiped` 클래스의 `added`/`IsValid()` 구조 — Dart 는 `HDItemId?` 의 `null` 이 곧 무효다.
- 2도류(`HAND_SUB` 에 무기)·부위별 감쇠·속성 상성 — `HAND_SUB` 는 방패 전용으로 시작한다.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.

## 구현 기록 (2026-09-03)

### 산출물

| 파일 | 변경 |
|---|---|
| `lib/domain/party/player.dart` | `equip` 6칸 + `equippedAt`/`equipItem`/`unequip`, 정수 3칸을 **유도값**으로 전환 |
| `test/domain/party/equipment_slots_test.dart` | **신규.** 14개 테스트 |

### 검증

- `flutter test` — 143개 전량 통과
- `flutter analyze --no-fatal-infos` — 77건, **기존과 동일**
- 계층 위반 grep 2종 — 빈 결과

### 이슈 서술에서 벗어난 부분

- **`HDEquipSlot` 은 `equip_slot.dart` 가 아니라 `item_type.dart` 안에 있다.**
  [G1-01](G1-01-item-model-port.md) 에서 `HDItemType.equipSlot` 의 반환 타입으로 이미 만들었고,
  같은 파일에 두면 import 가 늘지 않는다. 완료 판정 기준(wire 0~5 명시·`ObjTypes.cs` 순서)은 그대로 충족한다.
- **읽기 규칙이 이슈 서술과 다르다.** 이슈는 "해당 슬롯의 `HDItemId.index` 를 반환한다" 였지만
  그러면 **왕복이 깨진다** — 레거시 2번(곤봉)은 `HDItemId(hit, index: 3)` 이라 쓰고 읽으면 3 이 나온다.
  완료 기준 ④ 가 "왕복" 을 요구하므로 `legacyWeaponIds.indexOf(id)` 로 역인덱스를 쓴다.
  레거시 10칸 **밖의** 아이템이 끼워져 있으면 cm2 가 "장비 없음(0)" 과 구분해야 하므로
  `id.index` 를 주고 **왕복 불가를 경고 로그**로 남긴다.
- **`getWeaponName()` 3종이 슬롯 → 카탈로그 경로로 바뀌었다**([G1-06](G1-06-item-names.md) 은 레거시 정수 경유였다).
  레거시 10칸 밖의 아이템을 끼웠을 때 이름이 어긋나지 않게 하려면 이 경로여야 한다.
  빈 칸의 표시 이름(`맨손`/`없음`/`평상복`)은 여전히 레거시 표 0번에서 온다.
