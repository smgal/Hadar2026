# B2-03 상태 모델 — 누적값과 능력치 감소 (원제: 상태이상이 지속·강도를 갖는다)

- **상태**: DONE
- **구간**: B2 — **잠정 항목** ([_README](_README.md))
- **성격**: **판단** — C++ 은 개념만 알려준다 ([6차 판정](../DECISION-LOG.md): C++ 은 정본이 아니다)
- **규모**: L
- **선행**: B1 전체 · [B2-04](B2-04-unconscious-stage.md)
- **설계 근거**: [MILESTONES §7](../MILESTONES.md) · [`GROUND_TRUTH` 부록 Q](../../blueprint/_meta/GROUND_TRUTH.md)

## ⚠ 이 이슈의 제목이 틀렸다 — 조사 결과 (2026-09-05)

원제는 "상태이상이 지속·강도를 갖는다" 였다. **이 게임에 지속 시간이 있는 상태이상은 없다.**
설계하기 전에 확인한 것([부록 Q](../../blueprint/_meta/GROUND_TRUTH.md)):

| 확인한 것 | 결과 |
|---|---|
| 마법 14~18 이 담길 상태 칸 | **없다.** C++ `enum CONDITION` 은 `GOOD`/`POISONED`/`UNCONSCIOUS`/`DEAD` **4개**뿐 |
| 그럼 14~18 은 무엇을 했나 | **적 능력치를 영구히 깎았다** — `special = 0` · `--ac` · `--level` · `--cast_level` · `--special_cast_level` |
| 독(13)은 | `++poison` — 독 **수치를 누적**한다 (턴당 피해량) |
| `unconscious` 는 | **불린이 아니라 누적값**이다. `체력 × 레벨`을 넘으면 사망 |

→ **`StatusEffects` 컨테이너를 만들지 않았다.** 만들었다면 이 게임에 없는 개념 위에
B2-01(마법 45종)을 쌓게 됐을 것이다. 이 조사가 그것을 막았다.

## 문제 (원래 서술)

상태를 담는 자리가 **정수 3개**뿐이다.

| 곳 | 필드 |
|---|---|
| `domain/battle/enemy.dart:22-24` | `poison` · `unconscious` · `dead` |
| `domain/party/player.dart:50-52` | `poison` · `unconscious` · `dead` |

그리고 그 셋이 **불린처럼 쓰이고 있었다** — `unconscious` 가 0 이냐 아니냐만 봤다.

## 결과 (2026-09-05)

세 가지 기제를 만들었다.

### 1. `unconscious` 를 누적값으로

`rules/collapse.dart` 의 `applyDamage` 가 임계값을 받는다. 임계값은
`rules/condition.dart` 의 `unconsciousDeathThreshold` — **체력 × 레벨**, 최소 1.

```
이미 사망   → 아무것도 바뀌지 않는다
이미 붕괴   → unconscious += 피해;  임계값을 넘으면 사망
그 외      → hp -= 피해;  0 이 되면 붕괴
```

**B2-04 가 넣은 "한 번 더 맞으면 사망" 을 이것으로 교체했다.** 마무리 일격을 위한
특수 분기도 사라졌다 — 임계값을 넘긴 피해가 곧 마무리이므로 따로 다룰 것이 없다.

단 **쓰러진 대상은 회피도 저지도 하지 못한다**고 보아 두 판정을 건너뛴다. 이건 우리 판단이다 —
의식이 없는 적이 공격을 "저지" 하는 것은 읽기에 어색하다.

### 2. 상태 판정을 한 곳으로

`conditionOf` 가 `good` / `poisoned` / `unconscious` / `dead` 를 **나쁜 상태 우선**으로 읽는다.
`Combatant.condition` · `EnemyInstance.condition` 이 노출한다. HP 가 0 이면 플래그가 없어도
`unconscious` 로 읽는다.

### 3. 능력치 감소용 클램프 함수

`reduceStat(value, amount, floor: 0)`. **C++ 의 버그 2건을 고친 것이다**([부록 Q-4](../../blueprint/_meta/GROUND_TRUTH.md)):
`castSpellWithSpecialAbility` case 3 은 클램프가 아예 없고, case 4 는 가드가 있지만
저항 5 를 -5 로 만든다. 이제 B2-01 이 이 함수를 통해서만 능력치를 깎는다.

### 부수 효과 — 누적값은 사실상 파티 쪽 기제다

적은 전원 붕괴하는 순간 전투가 끝나므로 누적값이 자랄 시간이 거의 없다 — 같은 턴에
뒷사람이 한 번 더 때리는 창뿐이다. 파티는 반대로 여러 라운드에 걸쳐 쌓이고,
그것이 파티의 사망 경로가 된다. **이 비대칭은 우리 판단의 결과**이고 원작이 그랬는지는
알 수 없다. 밸런스를 볼 때 기억할 지점이다([부록 Q-5](../../blueprint/_meta/GROUND_TRUTH.md)).

## 완료 판정 기준

- [x] `unconscious` 가 누적되고, `체력 × 레벨`을 넘으면 사망한다
- [x] 상태 판정이 한 함수(`conditionOf`)로 모이고 네 상태를 나쁜 것 우선으로 읽는다
- [x] 능력치 감소가 바닥값 아래로 내려가지 않는다 (C++ 버그 2건 수정)
- [x] 콘솔이 `의식 불명 (3/8)` 처럼 남은 여유를 보여준다
      → `test/rules/collapse_test.dart` · `test/flow/collapse_flow_test.dart`

## 하지 않을 것

마법 14~18 의 실제 배선(B2-01 이 `reduceStat` 을 쓴다) · 치료(B2-02) ·
RPG 쪽 반영(B3-02) · 상태 아이콘·연출 · 원작에 없는 상태 추가.
