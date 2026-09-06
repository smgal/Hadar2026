# B2 — 전투 확장

> **판정 정정 (2026-09-04, [5차 판정](../DECISION-LOG.md))**
> B2 는 **설계가 아니라 절반이 이식**이다. C++ 원작에 완성 구현이 있다 —
> `hd_class_pc_player.cpp`(2,242줄) · `hd_class_pc_enemy.cpp`(1,079줄).
> 소재 목록은 [`GROUND_TRUTH` 부록 P](../../blueprint/_meta/GROUND_TRUTH.md).

> **이 디렉토리의 이슈 9개는 잠정이다.** 개념 자체가 없어지거나 바뀌면 해당 이슈를
> `DROPPED` 로 닫고(이유를 남긴다) 새로 만든다. 목록이 바뀌어도
> [B2-99](B2-99-freeze-contract.md) 와 자동 검증 4개는 바뀌지 않는다.

`hadar2026_app` 은 이 구간에서 **한 줄도 고치지 않는다.** RPG 쪽 연결은 전부 B3 다.

## ⚠ Unity 포트를 이식 원본으로 쓰지 말 것

`REF_UNITY_LoreEp1/src_as_cs/OldStyleBattle.cs` 는 3,248줄이라 매력적으로 보이지만
**다른 전투다** — 마법 번호가 1~20, 능력치가 `status[]`/`skill[]` 배열, 적 저항이 2개,
**적 테이블 인덱스가 +1 밀려 있다**(0번에 `존재없음` 행이 있다). 행동 순서 계산은 TODO 스텁이다.
Unity 를 보고 옮기면 cm2 의 `Battle::RegisterEnemy(26)` 과 어긋난다. 부록 P-3 을 먼저 읽을 것.

## 순서 — 이식 먼저, 판단 나중

이식이 판단의 근거를 만든다. 원작 전투가 실제로 어떻게 굴렀는지 보고 나서 새 것을 얹는다.

```
이식 5개                                     판단 4개
B2-04 → B2-03 → B2-02 → B2-01 → B2-07  ─▶   B2-05 → B2-06 → B2-08 → B2-09  ─▶  B2-99
의식불명  상태이상  치료   마법    적 AI       행동순서  아이템  부위감쇠 속성상성      규격 확정
```

| ID | 항목 | 성격 | 이식 원본 | 규격 영향 |
|---|---|---|---|---|
| [B2-04](B2-04-unconscious-stage.md) | 의식불명 단계 | **이식** | 원작 전투 전반이 2단계다 | 있음 |
| [B2-03](B2-03-status-effects.md) | 상태이상 모델 | **이식 + 판단** | `checkCondition`·`getConditionString` | **있음** |
| [B2-02](B2-02-heal-applies.md) | 치료 실제 적용 | **이식** | 치료 8종 `m_healOne`~`m_revitalizeAll` | 있음 |
| [B2-01](B2-01-magic-effects.md) | 공격 마법 1~18 | 판단 | `castSpellToOne/All` | **있음** |
| [B2-10](B2-10-esp-abilities.md) | 초능력 41~45 | 판단 | `useESPForBattle` | **있음** — 독심이 파티원을 늘린다 |
| [B2-07](B2-07-enemy-behavior.md) | 적 AI 사다리 | 판단 | `hd_class_pc_enemy.cpp` | 없음 |
| [B2-11](B2-11-superhuman-casting.md) | 초자연 시전 | 판단 | `enemyCastSpellWithSpecialAbility` | **있음** — 파티원이 이탈한다 |
| [B2-05](B2-05-turn-order.md) | 행동 순서 | 판단 | 없음 (C++ 도 슬롯 고정) | 없음 |
| [B2-06](B2-06-battle-items.md) | 전투 중 아이템 | 판단 | 없음 (C++ 메뉴에 없다) | **있음** |
| [B2-08](B2-08-slot-mitigation.md) | 부위별 감쇠 | 판단 | 없음 (부록 H-1) | 없음 |
| [B2-09](B2-09-elemental-affinity.md) | 속성 상성 | 판단 | 없음 | 없음 — 단 B3 작업량을 늘린다 |
| [B2-99](B2-99-freeze-contract.md) | 규격 확정 (구간 종료) | — | — | — |

**"규격 영향 없음" 인 항목은 전투 내부에서 끝난다** — RPG 는 최종 수치만 받으므로 어떻게
계산됐는지 알 필요가 없다. 그래서 나중에 늘어나도 B3 를 다시 하지 않는다.

## 이식할 때

C++ 은 cp949 다. `codecs.open(path, 'r', 'cp949')` 로 읽는다.
전역 상태(`hadar::game::object::getPlayerList()`)와 콘솔 출력(`console.Write`)이 규칙과
한 함수에 섞여 있으니, B1 이 만든 `packages/hd_battle/lib/src/rules/` 로 **값과 분기만** 옮긴다.

**B1 이 고정한 전투식 19개 중 마법·치료 쪽은 여기서 교체된다.** `test/rules/magic_escape_test.dart`
등이 함께 갱신되는 것은 예상된 일이다 — B1 은 "옮기다 깨지지 않았다" 를 고정한 것이고,
B2 는 규칙을 바꾸는 구간이다.
