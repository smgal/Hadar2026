# G1-05 장비 효과 배선 — `powOfWeapon ← attaPow` · `ac` 합산

- **상태**: TODO
- **구간**: G1
- **규모**: M
- **선행**: [G1-04](G1-04-equipment-slots.md)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-1(**정정판**) · H-2(정정판)](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.5](../MILESTONES.md)
- **관련**: [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) (죽은 필드 정리) · [G2-01](../G2-combat/G2-01-defense-reads-equipment.md) (방어 척도)

## ⚠ 근거 주의 — 부록 H-1 은 **정정판**이다

초판은 `powOfWeapon`/`powOfShield`/`powOfArmor` **3개 모두**를 죽은 필드로 적었고 **틀렸다**.
죽은 필드는 `powOfShield`·`powOfArmor` **2개뿐**이고, **`powOfWeapon` 은 살아 있다.**
이 사실이 이 이슈의 작업량을 결정한다 — **전투식을 고치지 않아도 무기가 작동한다.**

## 문제

### `powOfWeapon` 은 이미 읽힌다 (= 넣으면 즉시 작동)

`hadar2026_app/lib/application/battle.dart:439-441` (직접 확인):
```dart
int damage = (p.strength * p.powOfWeapon * p.level.physical) ~/ 20;
damage -= (damage * Random().nextInt(50)) ~/ 100;                 // :440  0~49% 감쇠
damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;    // :441  적 방어
```

하지만 값은 **하드코딩된 초기값**이다 — `party.dart:105`(12), `:127`(8). 장비와 무관하다.

### 방어는 `ac` 하나로만 계산된다

플레이어가 맞을 때 `battle.dart:513-514`:
```dart
int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;
```
`t.ac` 는 `player.dart:27` `int ac = 0;` — 초기값 `party.dart:108`(5), `:130`(3). **장비와 무관하다.**

`powOfShield`/`powOfArmor` 를 읽는 곳은 **0곳**이다(부록 H-1 전수 확인).
C++ 원본에서도 그랬다 — `REF_hadar/src/hadar/hd_class_pc_player.cpp:1045-1048`(공격), `:1159`(피격) 이
`pow_of_weapon` 과 `ac` 만 쓰고, `:452-453` 은 `pow_of_shield = 0; pow_of_armor = ac;` 로 **거울값**을 넣는다.

### 원작 Unity 는 파생값을 함수로 계산한다

`REF_UNITY_LoreEp1/src_as_cs/ObjPlayer.cs:468-493` `GetPAP()` — `atta_pow` × 무기 스킬 × STR × DEX × LEV.
`:585-595` `GetAcByArmor()` — 갑옷 착용 여부 × `ac` × LEV.
`:597-610` `GetAcByShield()` — **방패 스킬** × `equiped.item.param.ac`.

## 왜 지금 고쳐야 하는가

- **재미** — MILESTONES §1.5 의 완료 기준: *"장비를 바꾸면 전투 피해량이 실제로 달라진다"*. 지금은 무엇을 끼워도 같다.
- **부채 방지** — 배선이 없으면 [G1-02](G1-02-item-data.md) 가 옮겨 온 `attaPow`/`ac` 수치가 **전부 죽은 데이터**다. 아이템을 보상으로 주는 퀘스트는 "숫자가 안 변한다" 를 전제로 쓰이게 되고, 나중에 배선하면 밸런스를 다시 잡아야 한다.
- 부록 H-1 정정판의 파급이 이것이다 — **선행 과제가 전투식 변경이 아니라 이 배선뿐**임이 실측으로 확정됐다.

## 무엇을 할 것인가

### 이식 대응표 — **전투식은 건드리지 않는다**

| 원작 | Dart | 전투식 변경 |
|---|---|---|
| `ObjPlayer.cs:468-493` `GetPAP()` | `HDPlayer.powOfWeapon` 을 `equip[hand]` 의 `attaPow` 로 채운다 | **불필요** — `battle.dart:439` 가 이미 읽는다 |
| `ObjPlayer.cs:585-595` `GetAcByArmor()` | `equip[armor]` 의 `ac` 를 합산 항에 넣는다 | **불필요** — `battle.dart:514` 가 `t.ac` 를 읽는다 |
| `ObjPlayer.cs:597-610` `GetAcByShield()` | `equip[handSub]` 의 `ac` 를 **같은 합산 항**에 넣는다 | **불필요.** 아래 단순화 근거 |
| `ObjPlayer.cs:390-420` 장착 시 파생값 갱신 | `HDPlayer.recomputeEquipmentStats()` — 순수 domain 함수 | — |

**방패를 별 축으로 두지 않는 근거**: 원작의 `GetAcByShield()` 는 `skill[SKILL_TYPE.SHIELD]` 를 곱하는데
Dart 에는 스킬 시스템이 없다(`HDPlayer` 에 `skill` 필드가 없고 `accuracy`/`level` 만 있다 — `player.dart:37-38`).
스킬을 함께 이식하면 이 이슈가 스킬 시스템 이식으로 부푼다. **단순 합산**으로 시작하고,
부위별 감쇠·스킬 곱은 필요해질 때 그때 꺼낸다(부록 H-1 이 "그때만 전투식 변경이 필요" 라고 명시).

### 핵심 함정 — `ac` 를 덮어쓰면 캐릭터 소양이 사라진다

`party.dart:108`(5)·`:130`(3) 의 초기 `ac` 는 **장비가 아니라 캐릭터 자체의 값**이다
(`hd_class_pc_player.cpp:402` `ac = data.ac;` — 종족/직업 데이터에서 온다).
`recomputeEquipmentStats()` 가 `ac = 장비 합산` 으로 덮으면 이 값이 **조용히 0 이 된다.**

→ **`baseAc` 를 분리한다**:
```
baseAc  : 캐릭터 소양 (party.dart 초기화가 채우는 값, cm2 'ac' 쓰기가 바꾸는 값)
ac      : baseAc + 착용 중 모든 슬롯의 param.ac 합       ← battle.dart:514 가 읽는 값
```
`powOfWeapon` 은 반대로 **파생 전용**이다 — `equip[hand]` 가 비면 맨손 항(`attaPow` = 1)을 쓴다.
`Player::ChangeAttribute('pow_of_weapon', 0)`(`menace.cm2:49`)는 재계산이 덮으므로 **경고 로그**를 남긴다.

### `powOfShield`/`powOfArmor`

읽는 곳이 0곳이고 이제 대체 경로가 생겼으므로 **폐기 대상**이다.
삭제는 세이브 호환을 깨므로([G1-09](G1-09-item-save.md)) 이 이슈에서는 **주석·경고 로그까지**만 하고,
정리 자체는 [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) 에 맡긴다(선행이 이 이슈로 잡혀 있다 — [BOARD](../BOARD.md)).

### 재계산 시점

`equipItem`/`unequip`([G1-04](G1-04-equipment-slots.md)) 끝에서 호출한다. 세이브 로드 직후에도 호출한다([G1-09](G1-09-item-save.md)).
`recomputeEquipmentStats()` 는 `domain/party/player.dart` 의 **순수 메서드**다 — `application/` 을 부르지 않으므로 계층 위반 없음.

## 완료 판정 기준

- [ ] `HDPlayer.baseAc` 가 분리되고, `party.dart:108`·`:130` 의 초기값이 `baseAc` 로 들어간다
- [ ] `ac == baseAc + (착용 슬롯 6칸의 param.ac 합)` 이 항상 성립한다
- [ ] `powOfWeapon == equip[hand]?.attaPow ?? 맨손 attaPow` 가 항상 성립한다
- [ ] 장착·해제 직후 위 두 항등식이 다시 성립한다 (`recomputeEquipmentStats()` 호출)
- [ ] **`battle.dart` 가 한 줄도 바뀌지 않았다** (`git diff --stat lib/application/battle.dart` = 변경 0)
- [ ] `changeAttribute('pow_of_weapon'|'pow_of_shield'|'pow_of_armor')` 가 경고 로그를 남긴다
- [ ] `domain/` 계층 위반 grep 2종 통과
- [ ] 테스트 추가: `hadar2026_app/test/domain/party/equipment_effect_test.dart` —
      ① 무기 교체 → `powOfWeapon` 이 그 아이템의 `attaPow` 와 같아짐
      ② 방패+갑옷 착용 → `ac == baseAc + 방패ac + 갑옷ac`, 해제하면 `baseAc` 로 복귀
      ③ **`baseAc` 가 재계산으로 소실되지 않음** (위 함정의 회귀 테스트)
      ④ `strength * powOfWeapon * level.physical ~/ 20` 의 **결정론 부분**을 무기 2종으로 계산해 값이 달라짐을 고정
         (전투식 전체는 `Random()` 이 시드 없어([P0-11](../P0-foundation/P0-11-unseeded-random.md)) 직접 테스트할 수 없다 — 감쇠 전 기본 피해만 고정한다)

## 하지 않을 것

- **전투식 변경**(`battle.dart:439-441`, `:513-514`) — 부록 H-1 정정판이 불필요함을 실측했다. 방어 **척도**는 [G2-01](../G2-combat/G2-01-defense-reads-equipment.md).
- **스킬 시스템 이식** — `GetPAP()`/`GetAcByShield()` 의 스킬 곱(`ObjPlayer.cs:476-478`, `:599`)은 범위 밖.
- `annex` 문자열 파싱 — HEAD/LEG/ORNAMENT 의 `"ATT+1AC-1STR+1"` 해석(`ObjItem.cs:668-729`)은 G1 범위 밖. 슬롯은 채워지지만 능력치 보정은 없다.
- `powOfShield`/`powOfArmor` **필드 삭제** — [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) 소관. 세이브 호환이 걸려 있다.
- `Random()` 시드화 — [P0-11](../P0-foundation/P0-11-unseeded-random.md).
- 마법 45종 효과 — 별 트랙이다([MILESTONES §1](../MILESTONES.md)).
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.
