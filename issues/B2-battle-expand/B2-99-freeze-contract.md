# B2-99 모드 인계 규격을 확정한다 (구간 종료 판정)

> **⚠ 규격이 다시 열렸다 (2026-09-05, [8차 판정](../DECISION-LOG.md))**
> B5(위치 전투)가 `rank` · 무기 사거리 · `partyCapacity` 등을 더한다.
> **v1 은 B5-99 까지만 정본**이고 그 뒤로는
> [B5-99](../B5-battle-position/B5-99-freeze-contract-v2.md) 의 v2 다.

- **상태**: DONE
- **구간**: B2
- **규모**: M
- **선행**: B2 의 살아 있는 항목 전부
- **설계 근거**: [MILESTONES §7](../MILESTONES.md) · [DECISION-LOG 4차 판정](../DECISION-LOG.md)

## 왜 이 이슈가 있는가

B2 동안 `BattleSetup`·`BattleOutcome` 의 규격은 **자유롭게 깬다.** 확장 항목 목록 자체가
잠정이라, 항목마다 규격을 닫아 나가는 것은 낭비다(4차 판정).

대신 이 이슈가 **동결 지점**이다. B3 는 여기서 확정된 규격 위에서만 시작한다.
그리고 이 이슈의 판정은 **확장 항목이 바뀌어도 바뀌지 않는다.**

## 무엇을 할 것인가

- 살아 있는 확장 항목이 요구하는 입출력이 규격에 **전부 자리를 갖는지** 확인한다.
- `BattleSetup`·`BattleOutcome` 의 JSON 스키마를 문서로 고정하고, 버전 필드를 넣는다.
- `DROPPED` 된 항목이 남긴 규격 항목을 **지운다.**
- 이 시점의 규격을 `packages/hd_battle/CONTRACT.md` 로 적는다. B3 가 인용할 정본이다.

## 결과 (2026-09-05)

규격을 `packages/hd_battle/CONTRACT.md` **v1** 으로 확정했다.
`contractVersion` 상수가 코드 쪽 표시다.

### B2 동안 규격에 늘어난 항목 4개

| 항목 | 만든 이슈 | 왜 |
|---|---|---|
| `BattleSetup.consumables` | B2-06 | 가방의 투영. 전투가 가방을 건드리지 않는다 |
| `CombatantSnapshot.armour` | B2-08 | 부위별 방어구 + 방패 블록 |
| `BattleOutcome.recruits` | B2-10 | 독심이 적을 파티로 데려온다 |
| `BattleOutcome.departedSlots` | B2-11 | 초자연 시전이 파티원을 끌어간다 |

뒤의 둘이 **반대 방향의 같은 문제**였다. 짝으로 설계해서 한 번에 닫았다.

### 확장 항목 목록의 최종 상태

12개 전부 DONE. 목록이 잠정이라고 적어 두었는데 **실제로 두 번 늘었다** —
B2-01 을 하다 초능력이 다른 물건임을 알고 B2-10 을 뗐고, B2-07 을 하다 초자연 시전이
파티 구성을 바꾼다는 것을 알고 B2-11 을 뗐다. 규격을 B2 끝에 확정한 판단(4차)이
그 두 번을 흡수했다.

### 새 실측표

[`GROUND_TRUTH` 부록 U](../../blueprint/_meta/GROUND_TRUTH.md) —
`packages/hd_battle/tool/damage_band.dart` 로 재생성한다.
부록 H-2 는 **구 전투식 기준**으로 표시했다.

표가 드러낸 것 두 가지를 적어 두었다 (밸런스는 B2 범위가 아니었다):

- **Black Knight 의 최대 피해 945** — 원작 수식을 옮긴 결과다. 후반 적의 피해가
  파티 최대 체력을 몇 배로 넘는 것이 이 게임의 원래 성질이다
- **마법이 물리를 압도한다** — 마법 레벨 20 의 6번 마법 1440 대 무기 한 자릿수.
  전체 마법이 적마다 비용을 무는 것이 유일한 제동이다

## 완료 판정 기준

### 자동 검증 — 확장 항목 목록과 무관하게 고정

- [x] `grep -rn "package:flutter" packages/hd_battle/lib` 가 빈 결과다
- [x] `grep -rnP "[가-힣]" packages/hd_battle/lib` 가 빈 결과다 (표현 로직이 model 에 0)
- [x] 같은 fixture + 같은 명령 열 + 같은 시드 → 같은 `BattleOutcome`
- [x] 살아 있는 확장 항목마다 fixture 1개가 콘솔에서 돌아간다

### 시연 판정

- [x] 새 전투식의 피해 대역 실측표가 있다 (`defense_scale_test.dart` 와 같은 시드 전수 계산 방식)
- [x] 그 표가 `blueprint/_meta/GROUND_TRUTH.md` 부록으로 등재되고, 부록 H-2 가 **구 전투식 기준임을 명시**한다
- [x] `packages/hd_battle/CONTRACT.md` 가 있고, 규격에 버전이 붙었다
- [x] **그것을 보고 "붙인다" 는 판단이 내려졌다** → [DECISION-LOG 7차 판정](../DECISION-LOG.md)

## 하지 않을 것

RPG 쪽 변경(B3) · 규격 확정 후의 추가 확장(그건 규격 안에서 하거나 새 판정을 받는다).
