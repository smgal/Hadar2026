# G2-01 방어 계산이 장비에서 온 `ac` 를 읽게 한다 (+ 척도를 원작 대역에 맞춘다)

- **상태**: DONE
- **구간**: G2
- **규모**: M
- **선행**: [G1-05](../G1-items/G1-05-equipment-effect.md)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-1(**정정판**) · H-2(**정정판**) · H-3](../../blueprint/_meta/GROUND_TRUTH.md) · [MILESTONES §1.6](../MILESTONES.md)
- **관련**: [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) · [P0-11](../P0-foundation/P0-11-unseeded-random.md)

## ⚠ 근거 주의 — 부록 H-2 는 **정정판**이고, `ac 10/20` 은 "무효화" 가 아니다

초판은 *"ac 10/20 은 초반 전투를 통째로 무효화한다"* 고 적었고 **과장이었다**(최댓값만 비교한 결과).
부록 H-2 정정판이 `battle.dart:513-514` 의 식으로 10×10 = 100 조합을 전수 계산한 실측:

| 플레이어 `ac` | 피해가 발생하는 턴 비율 | 최대 피해 |
|---|---|---|
| 2 | 83.0% | 9 |
| 5 | 65.0% | 9 |
| 9 | 45.0% | 9 |
| **10** | **36.0%** | 8 |
| **20** | **16.0%** | 7 |

`ac 20` 에서도 **6턴 중 1턴은 최대 7 피해**가 들어온다. 무효화가 아니라 **강한 감쇠**다.
따라서 이 이슈의 재척도 근거는 "무효화되기 때문" 이 **아니라** 아래의 대역 정합이다.

## 문제

### 방어 항이 장비와 무관한 정수를 읽는다

`hadar2026_app/lib/application/battle.dart:513-514` — **플레이어가 맞을 때**:
```dart
int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;
```
`t.ac` 는 `player.dart:27` `int ac = 0;` 이고 초기값은 `party.dart:108`(5)·`:130`(3) 하드코딩이다.
방패·갑옷을 무엇으로 바꿔도 이 값은 변하지 않는다.

### `battle.dart:441` 은 **적 쪽** 방어다 — 정정

```dart
damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10;    // :441
```
여기서 `t` 는 **적**이다(`t.level` 이 `int`, 플레이어는 `SkillStats` — 부록 H-1 이 이 타입 차이를 지적했다).
**적은 장비를 착용하지 않으므로 `:441` 은 이 이슈의 변경 대상이 아니다.**
장비 `ac` 를 읽어야 하는 곳은 `:514` **한 곳**이다. 두 줄을 함께 다루는 것은 대칭성 확인 때문이다.

### `powOfShield`/`powOfArmor` 는 읽는 곳이 0곳

부록 H-1 전수 확인. C++ 원본에서도 그랬다 —
`REF_hadar/src/hadar/hd_class_pc_player.cpp:1045-1048`(공격)·`:1159`(피격) 이 `pow_of_weapon` 과 `ac` 만 쓰고,
`:452-453` 은 `pow_of_shield = 0; pow_of_armor = ac;` 로 **거울값**을 넣는다.
**원작부터 죽은 필드였다.**

### 원작 Unity 는 방어를 두 항으로 나눈다

`REF_UNITY_LoreEp1/src_as_cs/ObjPlayer.cs:585-595` `GetAcByArmor()` — 갑옷 착용 여부 × `ac` × LEV.
`:597-610` `GetAcByShield()` — `skill[SKILL_TYPE.SHIELD]` × `equiped.item.param.ac`. **방패 스킬이 곱해진다.**

## 왜 지금 고쳐야 하는가

- **재미** — MILESTONES §1.6: *"방어 계산이 장비에서 온 `ac` 를 읽는다."* 지금은 방패를 끼워도 맞는 빈도가 같다. 플레이어가 장비를 바꿀 이유가 없다.
- **부채 방지** — [G1-02](../G1-items/G1-02-item-data.md) 가 옮겨 온 `ac` 수치가 배선 없이는 죽은 데이터다. 그 상태로 [S1](../S1-sample-quest/S1-01-quest-design.md) 의 보상 아이템을 정하면 밸런스를 짐작으로 잡고, 배선 후 전부 다시 잡아야 한다.

## 무엇을 할 것인가

### **전투식은 고치지 않는다** — 필요한 것은 검증과 척도다

[G1-05](../G1-items/G1-05-equipment-effect.md) 가 `ac == baseAc + 착용 슬롯 ac 합` 을 항등식으로 유지하면
`battle.dart:514` 는 **한 줄도 바뀌지 않고** 장비 `ac` 를 읽게 된다. 부록 H-1 정정판의 결론이 이것이다.

| 원작 | Dart | 전투식 변경 |
|---|---|---|
| `ObjPlayer.cs:585-595` `GetAcByArmor()` | `ac` 합산 항 ([G1-05](../G1-items/G1-05-equipment-effect.md)) | 불필요 |
| `ObjPlayer.cs:597-610` `GetAcByShield()` | 같은 합산 항 (스킬 곱은 생략) | 불필요 |
| `hd_class_pc_player.cpp:1159` 피격식 | `battle.dart:514` 그대로 | 불필요 |

그래서 이 이슈의 실제 작업은 **① 검증을 테스트로 고정 ② 척도 확인 ③ 죽은 필드 표기**다.

### 척도 — 원작 실데이터가 이미 대역에 맞다

재척도의 근거는 **원작 파티 초기 `ac` 3~5 대역과 맞추기**다(`party.dart:108,130`).
[G1-02](../G1-items/G1-02-item-data.md) 가 가져오는 원작 실데이터를 확인했다:

| 출처 | `ac` 범위 |
|---|---|
| `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs:487-497` `SHIELD_LIST` 6종 | **0 ~ 5** |
| `REF_UNITY_LoreEp1/src_as_cs/ObjItem.cs:515-529` `ARMOR_LIST` 12종 | **0 ~ 10** (+ 흑요석 갑옷 **20**) |
| `assets/maps/books.json` (샘플) | 0 / **10** / **20** |

→ **원작 데이터를 쓰면 재척도가 대부분 자동으로 풀린다.** 초기 장비(가죽 방패 1 + 가죽 갑옷 1)면 `ac` 는 5~7 —
H-2 표의 65%~55% 대역이고 파티 소양(3~5)과 같은 자리다. 튀는 값은 `books.json` 의 10/20 이었다.

남는 판단 두 가지:
1. **상한 관리** — 6부위가 다 차면 합산 `ac` 가 20 을 넘을 수 있다(갑옷 10 + 방패 5 + 확장분). H-2 표 기준 `ac 20` = 16% 이므로 그 이상은 체감 차이가 급격히 줄어든다. → **획득 시점 규칙**으로 다룬다: 흑요석 갑옷(`ac 20`)은 최종 장비이며 초반 보상에 넣지 않는다. 코드 상한은 두지 않는다.
2. **`books.json` 은 손대지 않는다** — 앱이 읽지 않고(참조 0건), 참조본과 바이트 동일하다. 재척도 대상이 아니라 **폐기 대상**이다([G1-02](../G1-items/G1-02-item-data.md)).

### 계산표 재생성

H-2 의 표를 **원작 실데이터 조합**으로 다시 만들어 이슈 완료 시 기록한다 —
`ac ∈ {3(소양만), 5, 7, 10, 15, 20, 25}` × 적 `Troll`(id 1) / `Orc`(id 0) 기준.
부록 H-2 는 `Orc` 기준 `ac 10` → 31.0%, `ac 20` → 13.0% 를 함께 기록해 뒀으니 그 형식을 따른다.
(단 `Orc` 는 id 0 이라 cm2 에서 소환 불가다 — 부록 B-1, [P0-15](../P0-foundation/P0-15-enemy-id-zero.md).)

## 완료 판정 기준

- [x] `battle.dart:514` 의 `t.ac` 가 **장비 합산 `ac`** 를 읽는다 (= [G1-05](../G1-items/G1-05-equipment-effect.md) 의 항등식이 전투 진입 시점에 성립)
- [x] **`battle.dart` 가 한 줄도 바뀌지 않았다** (`git diff --stat lib/application/battle.dart` = 변경 0)
- [x] `battle.dart:441` 이 적 방어이며 장비와 무관함이 **주석으로 명시**되었다 (초판 오독의 재발 방지)
- [x] 방패·갑옷 `ac` 가 원작 대역(방패 0~5 / 갑옷 0~10)이고, 초기 장비 합산이 **파티 소양 3~5 와 같은 자리**임을 계산표로 확인했다
- [x] `ac ∈ {3,5,7,10,15,20,25}` 의 "피해 발생 턴 비율" 표를 **부록 H-2 형식으로** 이슈에 기록했다
- [x] `powOfShield`/`powOfArmor` 가 방어에 무관함이 코드 주석에 남아 있다 ([P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) 와 중복되지 않게, 이 이슈는 **확인만**)
- [x] `books.json` 이 수정되지 않았다
- [x] 테스트 추가: `hadar2026_app/test/application/defense_scale_test.dart` —
      `battle.dart:513-514` 의 식을 **순수 함수로 복제**해 10×10 난수 조합을 전수 계산한다
      (`Random()` 이 시드 없어 전투식 자체는 직접 테스트할 수 없다 — [P0-11](../P0-foundation/P0-11-unseeded-random.md))
      ① `ac 10` → 36.0%, `ac 20` → 16.0% (부록 H-2 정정판 표와 **정확히 일치**함을 고정)
      ② 초기 장비(방패 1 + 갑옷 1 + 소양 3) 조합이 55%~70% 대역에 들어감
      ③ 방패를 해제하면 비율이 **올라감**(= 방패가 실제로 작동)
      테스트 주석에 "이 표가 바뀌면 부록 H-2 를 먼저 고친다" 를 남긴다

## 하지 않을 것

- **전투식 변경**(`battle.dart:439-441`, `:513-514`) — 부록 H-1 정정판이 불필요함을 실측했다.
- **스킬 곱 이식** — `GetAcByShield()` 의 `skill[SKILL_TYPE.SHIELD]`(`ObjPlayer.cs:599`)는 Dart 에 스킬 시스템이 없어 범위 밖이다([G1-05](../G1-items/G1-05-equipment-effect.md) 와 같은 판단).
- **부위별 감쇠·속성 상성** — 부록 H-1 이 "그때만 전투식 변경이 필요" 라고 한 갈래다. 지금은 단순 합산.
- `powOfShield`/`powOfArmor` **필드 삭제** — [P0-19](../P0-foundation/P0-19-dead-equipment-fields.md).
- `Random()` 시드화 — [P0-11](../P0-foundation/P0-11-unseeded-random.md).
- `books.json` 재척도·삭제·로딩 — 부록 H-3, [G1-02](../G1-items/G1-02-item-data.md).
- 전투 결과 코드 정합(부록 B-2·F-3) — [P0-12](../P0-foundation/P0-12-battle-result-inverted.md)·[P0-13](../P0-foundation/P0-13-battle-result-defaults-win.md).
- 적 유효 범위 검사 — [P0-15](../P0-foundation/P0-15-enemy-id-zero.md).
- 마법 45종 효과·밸런스 재설계 — MILESTONES §1.6 이 명시적으로 제외했다.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.

## 구현 기록 (2026-09-03)

### 예상대로 **전투식은 한 줄도 바뀌지 않았다**

[G1-05](../G1-items/G1-05-equipment-effect.md) 가 `ac == baseAc + 착용 슬롯 ac 합` 을
파생 getter 로 항등식화한 순간 `battle.dart` 의 피격식이 장비 `ac` 를 읽게 됐다.
이 이슈가 한 일은 **검증 · 척도 확인 · 오독 방지 주석** 세 가지다.

| 파일 | 변경 |
|---|---|
| `lib/application/battle.dart` | 방어 두 줄에 **주석만** 추가 (수식 변경 0) |
| `test/application/defense_scale_test.dart` | **신규.** 7개 테스트 |

### 부록 H-2 표를 테스트가 정확히 재현한다

전투식이 시드 없는 `Random()` 두 개를 쓰므로([P0-11](../P0-foundation/P0-11-unseeded-random.md))
식을 순수 함수로 복제해 10×10 조합을 전수 계산했다. 부록 H-2 정정판과 **소수점까지 일치**:

`Troll`(id 1) ac 2 → 83.0% · 5 → 65.0% · 9 → 45.0% · 10 → 36.0% · 20 → 16.0%
`Orc`(id 0) ac 10 → 31.0% · 20 → 13.0%

### 완료 기준이 요구한 ac 사다리 (부록 H-2 형식, 플레이어 레벨 1)

| ac | Troll 피해 발생률 | Troll 최대피해 | Orc 피해 발생률 |
|---|---|---|---|
| 3 (소양만) | 78.0% | 9 | 78.0% |
| 5 | 65.0% | 9 | 62.0% |
| 7 | 56.0% | 9 | 51.0% |
| 10 | 36.0% | 8 | 31.0% |
| 15 | 24.0% | 8 | 21.0% |
| 20 | 16.0% | 7 | 13.0% |
| 25 | 13.0% | 7 | 11.0% |

**이 표가 바뀌면 부록 H-2 를 먼저 고친다.**

### 척도는 원작 데이터로 자동 해결됐다

- [G1-02](../G1-items/G1-02-item-data.md) 가 가져온 방패 `ac` **0~5** · 갑옷 `ac` **0~5** (원작 index 0~5 구간).
- 초기 장비(가죽 방패 1 + 가죽 갑옷 1 + 소양 3) → `ac` **5**, 위 표의 **65%** 대역.
  파티 소양(3~5)과 같은 자리다. 튀던 값은 `books.json` 의 10/20 이었고 그 파일은 **손대지 않았다**.
- 이식분 최상급을 다 껴도 `ac` **15**(방패 5 + 갑옷 5 + 소양 5) — 머리/다리/장식은 원작 표에 `ac` 가 없다.
  코드 상한은 두지 않고 **획득 시점 규칙**으로 다룬다(이슈 서술 그대로).

### 주석으로 남긴 오독 방지

- `battle.dart` 의 적 방어 줄: `t` 가 **적**이고 장비와 무관함을 명시. 부록 H-1 초판이 두 줄을 하나로 읽어
  "장비를 쓰려면 전투식 변경이 선행" 이라는 과장이 나왔다.
- 플레이어 방어 줄: `t.ac` 가 `baseAc + 착용 슬롯 합`(G1-05)이고 `powOfShield`/`powOfArmor` 는
  읽는 곳이 없음을 명시. ([P0-19](../P0-foundation/P0-19-dead-equipment-fields.md) 와 중복되지 않게 **확인만**.)

### 검증

- `git diff --stat lib/application/battle.dart` — 이 이슈의 변경은 **주석 2블록뿐**
- `flutter test` — 225개 전량 통과 · `flutter analyze` 77건(기존과 동일)
- `git status assets/maps/books.json` — **무변경**
