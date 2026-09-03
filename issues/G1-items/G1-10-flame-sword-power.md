# G1-10 `화염검` 의 공격력이 자리표시값이다 (원작에 값이 없음)

- **상태**: TODO
- **구간**: G1 (사후 발견 — G1 자체는 2026-09-03 완료)
- **규모**: S
- **선행**: 없음 ([G1-02](G1-02-item-data.md) 가 만든 상태)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-5](../../blueprint/_meta/GROUND_TRUTH.md) · [G1-02 구현 기록](G1-02-item-data.md)

## 현재 값

`hadar2026_app/lib/domain/item/item_data.dart`:

```dart
HDItem(id: HDItemId(HDItemType.wield, index: 8), name: '화염검',
       param: HDItemParam(attaPow: 10, ac: 0, type: HDItemType.wield)),
// ObjItem.cs:453  무기 표에 대응 항 없음 — SUMMON_SINGLE:8 의 자리표시 10.0(원작 TODO). 밸런스 값 아님
```

`10` 은 **밸런스 판단으로 정한 값이 아니라** 파이프라인을 통과시키려고 넣은 자리표시값이다.
곤봉(25)·장검(60)·도끼창(90) 보다 낮다.

## 왜 이렇게 됐나 (실측 근거 전량)

### C++ 원작에는 무기별 공격력 표가 **없다**

`pow_of_weapon` 이 등장하는 곳 전량 5줄이고, **`weapon` 으로 인덱싱하는 표가 한 줄도 없다**:

| 위치 | 내용 |
|---|---|
| `hd_class_pc_player.h:64` | `int pow_of_weapon;` 선언 |
| `hd_class_pc_player.cpp:155` | 속성맵 등록 |
| `hd_class_pc_player.cpp:212` | `pow_of_weapon = 5;` (초기값) |
| `hd_class_pc_player.cpp:451` | `pow_of_weapon = level[0] * 2 + 10;` (크리처 생성) |
| `hd_class_pc_player.cpp:1045` | `damage = (strength * pow_of_weapon * level[0]) / 20;` (전투식) |

`hd_res_string.cpp:41-53` 의 `NAME[]` 은 **이름만** 담는다. 즉 원작에서 `weapon = 9` 는
"화면에 화염검이라고 출력한다" 는 뜻일 뿐이고 공격력은 스크립트가 따로 넣는다.

### 원작 스크립트는 화염검을 준 적이 없다

배포된 cm2 전량에서 `Player::ChangeAttribute(n, "weapon", …)` 에 들어가는 값:

```
   8 → 0   (맨손 — 무장 해제 연출)
  24 → 1   (단도)
   4 → 3   (미늘창)
```

**9는 0건.** 화염검은 이름 표에만 있고 플레이 중 손에 들어오는 경로가 없다.
(`REF_hadar/bin/gamedat0.sav`·`gamedat1.sav` 는 포맷 미해독 — 그 안은 확인하지 않았다.)

### Unity 포트에서 화염검은 **무기가 아니라 소환수 기술**이다

전체 등장 2곳:

```csharp
// ObjItem.cs:453
new _WeaponStruct( 8, "화염검", 10.0, Yunjr.ITEM_TYPE.SUMMON_SINGLE),

// ObjItem.cs:604-608
/* TODO: 소환수 기술에 대한 power 수치가 필요
        '화염','해일','폭풍','지진','이빨','촉수','창',
        '발톱','바위','화염검','동물의 뼈','번개 마법', ... */
```

소환수 기술 21개의 power 가 **전부 10.0** 이다 — 원작자가 TODO 로 표시한 자리표시값이고
화염검이 그 목록에 들어 있다.

## 지금 고치지 않는 이유

- **실플레이 영향 0** — 화염검을 주는 스크립트가 없어 현재 도달 불가다.
- 값을 정하는 것은 **이식이 아니라 밸런스 창작**이다. G1 의 원칙("창작하지 않는다")에 걸린다.
- 아이템을 보상으로 주는 콘텐츠가 생겨야 적정값을 판단할 근거가 생긴다.

## 고쳐야 하는 시점

**화염검을 실제로 플레이어에게 주는 콘텐츠를 만들 때.** 그 전에는 도달 불가라 무해하다.
[S1](../S1-sample-quest/S1-01-quest-design.md) 이 보상으로 무기를 쓰면 그때 후보에 올라온다.

## 선택지 (그때 판단할 것)

| # | 안 | 비고 |
|---|---|---|
| A | 무기 사다리에 맞는 값을 **정한다** (예: 도끼창 90 위인 100) | 창작이지만 가장 단순. C++ 목록 끝자리라는 것 외에 근거는 없다 |
| B | 카탈로그에서 **뺀다** — 이름 표(`legacyWeaponNames`)에만 남긴다 | 원작에 가장 충실. 단 `legacyWeaponIds[9]` 가 갈 곳을 잃는다 |
| C | `attaPow` 를 **nullable** 로 두고 "값 미정" 을 타입으로 표현 | 소환수 기술 21종도 같은 처지라 함께 풀린다. 변경 면적이 가장 크다 |

**C 는 소환수 기술까지 같은 문제를 안고 있다는 점을 함께 본다** — 21종 전부 10.0 자리표시다.

## 완료 판정 기준

- [ ] 위 3안 중 하나를 골라 근거를 남긴다
- [ ] `item_data.dart` 의 "밸런스 값 아님" 주석이 해소되거나, 남는다면 그 이유가 적힌다
- [ ] `test/domain/item/item_data_test.dart` 의 `powerOf('화염검')` 고정값이 갱신된다
- [ ] 소환수 기술 21종의 자리표시 10.0 을 어떻게 할지 함께 판단한다

## 하지 않을 것

- 마법 45종 효과 구현 — 별 트랙이다([MILESTONES §1](../MILESTONES.md)).
- 전투 밸런스 전반 재설계.
