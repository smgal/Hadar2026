# G1-09 세이브 v1 에 소지품·장비를 더한다 (현행 구조 최소 변경)

- **상태**: DONE
- **구간**: G1
- **규모**: M
- **선행**: [G1-03](G1-03-party-inventory.md) · [G1-04](G1-04-equipment-slots.md)
- **설계 근거**: [`GROUND_TRUTH` §7 · 부록 C-1 · C-3 · H-3](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md)
- **참고만**: [BP-42 §6](../../blueprint/42_item_and_inventory.md) — **선언적 세이브 v2 노선이 아니다.** 현행 스키마에 필드를 더하는 최소 변경이다.

## 문제

### 현행 세이브는 v1 이고 아이템 개념이 없다

`hadar2026_app/lib/application/save_manager.dart:18-24` (직접 확인):
```dart
final Map<String, dynamic> data = {
  'version': 1,
  'party': session.party.toJson(),
  'gameSystem': session.gameSystem.toJson(),
  'gameOption': session.gameOption.toJson(),
  'map': session.map?.toJson(),
};
```

`party.toJson()`(`party.dart:182-203`)은 `food`/`gold` 와 `players` 배열만 담는다.
`player.toJson()`(`player.dart:396-429`)은 `:422-427` 에서 정수 3칸 + 죽은 필드 3개를 담는다:
```dart
'weapon': weapon, 'shield': shield, 'armor': armor,
'powOfWeapon': powOfWeapon, 'powOfShield': powOfShield, 'powOfArmor': powOfArmor,
```

[G1-03](G1-03-party-inventory.md) 의 `backpack` 과 [G1-04](G1-04-equipment-slots.md) 의 `equip` 6칸은 **어디에도 실리지 않는다.**

## 왜 지금 고쳐야 하는가

- **재미** — MILESTONES §1.5 완료 기준: *"세이브·로드 후 소지품과 장비가 유지된다."* 유지되지 않으면 [S1-04](../S1-sample-quest/S1-04-playthrough.md) 의 "중간에 세이브·로드해도 진행이 유지" 가 아이템 구간에서 깨진다.
- **부채 방지** — 지금 v1→v2 를 한 번에 하면 마이그레이션이 **한 번**이다. [G1-04](G1-04-equipment-slots.md) 가 6부위를 처음부터 넣는 이유와 같은 계산이다.

## 무엇을 할 것인가

### 최소 변경 — 필드 추가와 버전 올림뿐

| 파일 | 변경 |
|---|---|
| `save_manager.dart:19` | `'version': 1` → `2` |
| `party.dart:182-203` `toJson` | `'backpack': [...]` 추가 (길이 20 정수 배열, 빈 칸은 `-1`) |
| `party.dart:204-...` `fromJson` | `backpack` 복원 + **v1 폴백**(키 없음 → 빈 20칸) |
| `player.dart:415-428` `toJson` | `'equip': [...]` 추가 (길이 6 정수 배열, 빈 칸은 `-1`), `'baseAc': baseAc` 추가([G1-05](G1-05-equipment-effect.md)) |
| `player.dart:431-464` `fromJson` | `equip`/`baseAc` 복원 + **v1 마이그레이션** |

`weapon`/`shield`/`armor`/`powOf*` **6개 키는 계속 쓴다.** 삭제하면 v1 세이브를 읽을 수 없고
[P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) 가 아직 정리 전이다.
쓸 때는 슬롯에서 유도한 값을 넣는다([G1-04](G1-04-equipment-slots.md) 의 읽기 규칙과 같다).

### v1 → v2 마이그레이션 규칙

`fromJson` 이 `version` 을 볼 수 없으므로(`party.toJson` 에 버전이 없다) **키 존재 여부**로 판정한다 —
`json['equip'] == null` 이면 v1 페이로드다.

| v1 값 | v2 해석 | 근거 |
|---|---|---|
| `weapon` 정수 | 원작 **C++ 무기 인덱스 공간**(0~9)으로 해석해 `equip[hand]` 에 장착 | `REF_hadar/src/hadar/hd_class_pc_player.cpp:302-315` 가 `resource::getWeaponName(weapon)` 로 그 공간을 쓴다. `hd_res_string.cpp:38-56` 이 표다 |
| `shield` 정수 | 방패 인덱스 0~5 → `equip[handSub]` | `hd_res_string.cpp:58-72` |
| `armor` 정수 | 갑옷 인덱스 0~5 → `equip[armor]` | `hd_res_string.cpp:74-88` |
| 범위 밖 정수 | **index 0**(맨손/없음/평상복)으로 떨어뜨리고 **경고 로그** | 부록 H-3: `books.json` id 공간과 무관하므로 임의 매핑을 만들지 않는다 |
| `head`/`leg`/`etc` | 항상 **빈 칸** | v1 에 존재하지 않았다 |
| `backpack` | 빈 20칸 | 같음 |
| `powOfWeapon` | **읽지 않는다** — `recomputeEquipmentStats()` 가 덮는다([G1-05](G1-05-equipment-effect.md)) | 파생값이다 |
| `powOfShield` / `powOfArmor` | **읽지 않는다** | 부록 H-1 정정판: 죽은 필드 |
| `ac` | `baseAc = max(0, ac - 마이그레이션한 장비 ac 합)` | v1 의 `ac` 는 소양 + 장비가 섞이지 않은 순수 소양값이지만, 마이그레이션이 장비를 채우면 `ac` 가 부풀어 오른다. **뺀 뒤 0 으로 클램프**해 v1 의 최종 `ac` 를 보존한다 |

**되돌리기는 없다.** v2 로 저장한 세이브를 v1 코드가 읽으면 `equip`/`backpack` 을 무시하고 정수 3칸만 본다 —
데이터가 사라지므로 v1 로 **저장하지 않는다**(항상 v2). 이 사실을 `save_manager.dart` 주석에 남긴다.

로드 직후 `recomputeEquipmentStats()` 를 호출한다 — 그러지 않으면 `powOfWeapon` 이 0 인 상태로 전투에 들어간다.

### 용량

부록 C-3: 현행 세이브는 맵 스냅샷 때문에 **557~664KB** 이고 웹 저장 한계에 근접한다([P0-09](../P0-foundation/P0-09-save-size-limit.md)).
이 이슈가 더하는 것은 인물당 정수 7개(`equip` 6 + `baseAc`) × 6명 + 가방 20 = **정수 62개**, 수백 바이트다. **영향 없음**을 확인하고 기록한다.

## 완료 판정 기준

- [x] `save_manager.dart` 가 `'version': 2` 로 저장한다
- [x] v2 왕복(저장 → 로드) 후 **가방 20칸과 장비 6칸이 정확히 같다**
- [x] v2 로드 직후 `powOfWeapon` 과 `ac` 가 재계산되어 있다 ([G1-05](G1-05-equipment-effect.md) 의 두 항등식이 성립)
- [x] **v1 페이로드**(`equip` 키 없음, `weapon: 4`)를 로드하면 `equip[hand]` 가 무기 index 4 (`"장검"`)로 채워지고 가방은 빈 20칸이다
- [x] v1 의 `ac` 가 보존된다 — `baseAc + 장비 ac == v1 의 ac`
- [x] v1 의 범위 밖 정수(`weapon: 99`)가 index 0 으로 떨어지고 **경고 로그**가 남는다
- [x] `weapon`/`shield`/`armor` 키가 v2 에도 쓰이고, 값이 슬롯에서 유도된 index 다
- [x] 세이브 크기 증가가 1KB 미만임을 실측해 기록했다
- [x] `application/` 계층 위반 grep 2종 통과
- [x] 테스트 추가: `hadar2026_app/test/application/item_save_test.dart` —
      ① v2 `toJson`/`fromJson` 왕복에서 가방 20칸·장비 6칸 보존
      ② **v1 페이로드 리터럴**(JSON 문자열을 테스트에 그대로 박는다)에서 정수 3칸 → 슬롯 마이그레이션 고정
      ③ `baseAc` 클램프 규칙(v1 `ac` 보존, 음수 방지) 고정
      ④ 범위 밖 정수 폴백 고정
      v1 페이로드를 리터럴로 박는 이유를 주석에 남긴다 — **v1 스키마는 더 이상 코드에 존재하지 않으므로 테스트가 유일한 명세다**

## 하지 않을 것

- **선언적 세이브 v2**(`WorldState` 직렬화·Condition/Effect·콘텐츠 팩 참조) — [deferred/](../deferred/) 노선이다. 여기서는 현행 `Map<String, dynamic>` 에 키를 더할 뿐이다.
- `powOfShield`/`powOfArmor` **키 삭제** — [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) 소관. 지우면 v1 호환이 깨진다.
- 부록 C-1(세이브가 `map.events` 유실)·C-2(네이티브 스크립트 미부착) 수정 — [P0-07](../P0-foundation/P0-07-save-drops-map-events.md)·[P0-08](../P0-foundation/P0-08-save-skips-native-attach.md).
- 세이브 용량 대책 — [P0-09](../P0-foundation/P0-09-save-size-limit.md).
- 세이브 슬롯 수 변경·자동 저장·클라우드 저장.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.

## 구현 기록 (2026-09-03)

### 산출물

| 파일 | 변경 |
|---|---|
| `lib/application/save_manager.dart` | `'version': 2` + 되돌리기 없음 주석 |
| `lib/domain/party/party.dart` | `backpackToJson`/`backpackFromJson`, `toJson` 에 `'backpack'` |
| `lib/domain/party/player.dart` | `toJson` 에 `'equip'`·`'baseAc'`, `fromJson` 을 v1/v2 분기로 재작성, `_restoreEquip` |
| `test/application/item_save_test.dart` | **신규.** 13개 테스트 |

### 검증

- `flutter test` — 183개 전량 통과
- `flutter analyze --no-fatal-infos` — 77건, **기존과 동일**
- 계층 위반 grep 2종 — 빈 결과
- **용량 실측**: 빈 상태 추가분 **382바이트**(인물당 `equip` 6 + `baseAc` = 48B × 6명 + 가방 94B).
  가방을 20칸 채워도 1KB 미만임을 테스트가 고정한다. 부록 C-3 의 557~664KB 에 비하면 **0.1% 미만**

### v1 판정과 마이그레이션

`party.toJson` 에 버전이 없어 `fromJson` 이 `version` 을 볼 수 없으므로
**`json['equip']` 키의 유무**로 판정한다(이슈 서술 그대로).

| v1 입력 | 결과 |
|---|---|
| `weapon: 4` | `equip[hand]` = 장검. `getWeaponName()` 이 `'장검'` |
| `shield: 0` | 빈 칸 |
| `armor: 1` | `equip[armor]` = 가죽 갑옷 |
| `weapon: 99` | 빈 칸(= index 0, `'맨손'`) + 경고 로그 |
| `ac: 5` + 갑옷 ac 1 | `baseAc = 4`, **유효 `ac` 는 5 로 보존** |
| `ac: 0` + 갑옷 ac 5 | `baseAc = 0` 클램프 + 경고 로그 |
| `powOfWeapon: 12` | **버린다.** 장검에서 60 이 유도된다 |
| 가방 | 빈 20칸 |

### 이슈 서술에서 벗어난 부분

- **`recomputeEquipmentStats()` 호출이 없다.** [G1-05](G1-05-equipment-effect.md) 에서 `ac`·`powOfWeapon` 을
  파생 getter 로 만들었으므로 로드 직후 재계산할 것이 없다 — 슬롯을 복원한 순간 두 값이 맞다.
- **`'ac'` 키의 의미를 v1 그대로(유효 방어도) 되돌렸다.** G1-05 에서는 세이브·로드 반복 시
  ac 가 부푸는 것을 막으려고 임시로 `baseAc` 를 담았는데, v2 가 `'baseAc'` 를 따로 담으면서
  그 우회가 필요 없어졌다. v1 판정 경로가 `'ac' - equipmentAc` 로 되돌리므로 양쪽 다 정확하다.
- **손상된 슬롯을 강제로 끼우지 않는다.** `equip[0]` 에 투구 id 가 들어 있으면
  `equipItem` 이 거부하고 빈 칸으로 두며 경고를 남긴다. 테스트가 고정한다.
