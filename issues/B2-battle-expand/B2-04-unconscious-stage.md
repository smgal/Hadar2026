# B2-04 적이 의식불명을 거쳐 사망한다 (경로에 따라 다르게 동작 중)

- **상태**: DONE
- **구간**: B2 — **잠정 항목** ([_README](_README.md))
- **성격**: **판단** — C++ 은 `unconscious`/`dead` 가 별 필드라는 것만 알려준다.
  분기는 우리가 정했다 ([6차 판정](../DECISION-LOG.md): C++ 은 정본이 아니다)
- **규모**: S
- **선행**: B1 전체
- **설계 근거**: [MILESTONES §7](../MILESTONES.md)

## 문제

**같은 "hp 0" 이 죽는 경로에 따라 다르게 처리된다.**

독으로 hp 가 0 이 되면 의식불명이다 — `battle.dart:212-218`:

```dart
if (e.poison > 0) {
  if (e.unconscious > 0) { e.dead = 1; }
  else { e.hp -= e.poison; if (e.hp <= 0) e.unconscious = 1; }
}
```

그런데 물리 공격으로 hp 가 0 이 되면 **의식불명을 건너뛰고 즉사한다** — `battle.dart:486-489`:

```dart
t.hp = 0;
t.unconscious =
    0; // if it was conscious, goes unconscious first in hadar sometimes but let's just do death for simplicity
t.dead = 1;
```

주석이 스스로 생략을 적어 두었다. 그래서 `battle.dart:437-446` 의 "의식불명 상태인 적을 가볍게 처치"
분기는 **독으로 쓰러진 적에게만** 도달한다.

## 이식 원본 — 원작은 전투 전반이 2단계다

`REF_hadar/src/hadar/hd_class_pc_player.cpp` 와 `hd_class_pc_enemy.cpp` 를 대조해
hp 0 의 처리를 한 규칙으로 맞춘다. 원작에서 `unconscious` 와 `dead` 가 별 필드인 것
(`hd_class_pc_enemy.h` `PcEnemy`)이 곧 2단계가 설계였다는 증거다.

Dart 는 독 경로에만 2단계가 남아 있다 — 물리 경로가 이식되면서 생략됐다(`battle.dart:488`
주석이 자백한다). **즉 이 항목은 새 규칙이 아니라 되돌리기다.**

⚠ Unity 포트도 2단계를 갖지만(`TURN_TO_UNCONSCIOUS` → `TURN_TO_DEAD`) 그 위에
크리티컬·회피 등 신규 개념이 얹혀 있다. C++ 쪽을 본다.

## 완료 판정 기준
## 완료 판정 기준

- [x] 죽는 경로(물리·마법·독)와 무관하게 hp 0 의 처리가 **한 규칙**이다
- [x] 의식불명 상태의 적을 공격하면 즉살 분기가 도달한다
- [x] 의식불명과 사망이 `isConscious()` 판정과 경험치 정산에서 구분된다
      → `packages/hd_battle/test/rules/unconscious_test.dart`

## 결과 (2026-09-05)

세 경로를 `packages/hd_battle/lib/src/rules/collapse.dart` 의 `applyDamage` **하나**로 합쳤다.

```
이미 사망      → 아무것도 바뀌지 않는다
이미 붕괴      → 사망
그 외          → hp -= 피해; 0 이 되면 붕괴(의식불명)
```

**정한 것 4개** (C++ 에서 가져온 것이 아니라 판단이다)

| 결정 | 이유 |
|---|---|
| hp 를 **0 으로 정리**한다 | 부록 O-7. 음수 hp 를 RPG 에 넘기지 않는다 |
| 경험치는 **붕괴 시점**에 준다 (마무리 때 두 번 주지 않는다) | 붕괴한 채로 전투가 끝난 적이 0점이 되면 안 된다. 마법 사망이 경험치를 안 주던 것도 같이 해소된다(부록 O-4) |
| 재조준은 **붕괴한 대상을 그대로 둔다** (사망·범위 밖만 교체) | 이래야 원작에 있던 마무리 일격 문장이 도달한다(부록 O-3). 같은 턴 뒤 사람이 앞 사람이 쓰러뜨린 적을 처치한다 |
| **파티도 2단계**이고, 파티 독을 턴마다 처리한다 | 붕괴가 회복 가능해지면 파티가 죽을 길이 없어진다. 독이 그 경로다. 전투 중 `HDPlayer.poison` 은 읽히는 곳이 0곳이었다(부록 O-6) |

**범위 판단**: 파티 독 처리는 원래 B2-03(상태이상)의 일로 보였지만, 그것 없이는 붕괴 규칙이
완결되지 않아(사망 경로가 사라진다) 여기 포함했다.

**전체 마법은 붕괴한 적을 건너뛴다** — 단일 대상 마법과 무기는 마무리하지만, 전체 마법이
쓰러진 적까지 정리하면 단일 대상보다 무조건 유리해진다.

시연: `hd_battle_console/fixtures/finishing_blow.json` · `party_poison.json`.
고정 테스트: `test/rules/collapse_test.dart`(15개) · `test/flow/collapse_flow_test.dart`(7개).

## 하지 않을 것

파티원 쪽 의식불명 규칙 변경 · 부활 마법(B2-02) · 사망 연출.
