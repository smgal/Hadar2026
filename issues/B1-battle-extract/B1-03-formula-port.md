# B1-03 전투식 19개를 시드 주입 순수 함수로 이식하고 단위 테스트로 고정한다

- **상태**: DONE
- **구간**: B1
- **규모**: L
- **선행**: [B1-01](B1-01-package-skeleton.md) · [B1-02](B1-02-enemy-table.md)
- **설계 근거**: [`GROUND_TRUTH` 부록 H-1·H-2(정정판)](../../blueprint/_meta/GROUND_TRUTH.md) · [P0-11](../P0-foundation/P0-11-unseeded-random.md)

## 문제

### 무시드 `Random()` 14곳 때문에 전투식을 테스트로 구동할 수 없다

`hadar2026_app/test/application/defense_scale_test.dart:14-18` 이 그 사실을 이미 적어 두었다:

> *"Both `Random()` calls are unseeded (P0-11), so the real formula cannot be driven from a test.
> Enumerating all 10x10 draws instead gives the exact distribution."*

그래서 그 테스트는 **수식을 파일 안에 복사해 놓고** 전수 계산한다(`:29-31`).
복사본이라 원본이 바뀌면 조용히 갈라진다 — 테스트 주석이 *"If these numbers change,
fix appendix H-2 first, then this test"* 로 사람에게 부탁하고 있는 이유다.

### 이식 대상은 19개다

`battle.dart` 를 전수로 세었다. **경험치는 두 곳에서 같은 식으로 더해지므로 1개로 센다.**

| # | 전투식 | 위치 |
|---|---|---|
| 1 | 물리 명중 판정 `rand(20) > accuracy.physical` | `battle.dart:450` |
| 2 | 적 저지 판정 `rand(100) < t.resistance` | `battle.dart:455` |
| 3 | 물리 피해 기본 `(strength * powOfWeapon * level.physical) ~/ 20` | `battle.dart:462` |
| 4 | 물리 피해 난수 감쇠 `-= (damage * rand(50)) ~/ 100` | `battle.dart:463` |
| 5 | 적 방어 항 `-= (t.ac * t.level * (rand(10)+1)) ~/ 10` | `battle.dart:470` |
| 6 | 처치 경험치 `t.level * 10` | `battle.dart:446` · `:494` |
| 7 | 마법 전체 대상 피해 `(level.magic + level.esp) * 5 + rand(10)` | `battle.dart:166` |
| 8 | 마법 단일 대상 피해 `(level.magic + level.esp) * 8 + rand(15)` | `battle.dart:185` |
| 9 | 도주 판정 `(agility + luck) ~/ 2 + rand(20)` vs `평균 민첩 + 10` | `battle.dart:412-415` |
| 10 | 적 대상 선정 `targets[rand(targets.length)]` | `battle.dart:504` |
| 11 | 적 특수/물리 선택 `rand(acc[0]*1000+1) > rand(acc[1]*1000+1)` | `battle.dart:508-509` |
| 12 | 적 마법 피해 `(e.level * 5) + rand(10)` | `battle.dart:518` |
| 13 | 플레이어 저지 판정 `rand(50) < t.resistance` | `battle.dart:533` |
| 14 | 적 물리 피해 `(e.strength * e.level * (rand(10)+1)) ~/ 10` | `battle.dart:543` |
| 15 | 플레이어 방어 항 `-= (t.ac * t.level.physical * (rand(10)+1)) ~/ 10` | `battle.dart:548` |
| 16 | 승리 경험치 총량 `max(1, ((id+1)^3) ~/ 8)` 합 | `battle.dart:276-280` |
| 17 | 골드 `e.level * 5` 합 | `battle.dart:294` |
| 18 | 적 초기 hp `endurance * level`, 최소 1 | `domain/battle/enemy.dart:41-42` |
| 19 | 적 독 피해 `hp -= poison`, `hp<=0 → unconscious` | `battle.dart:212-219` |

## 왜 지금 해야 하는가

이것이 **B1 의 완료 판정 그 자체**다. 규칙을 바꾸는 것은 전부 B2 이므로,
이 구간에서 "옮기다 깨졌는지" 를 판정할 수 있어야 한다.

기존 `battle.dart` 에 시드를 주입해 기준 결과를 뽑는 방식은 **버릴 코드에 하는 작업**이라 하지 않는다.
대신 새 패키지가 시드를 받으니 테스트가 **수식 복사본이 아니라 원본을 직접 구동**한다 —
`defense_scale_test.dart` 의 취약점이 여기서 같이 해소된다.

## 무엇을 할 것인가

- `packages/hd_battle/lib/src/rules/` 에 19개를 **순수 함수**로 둔다. 난수는 인자로 받은
  `Random` 하나에서만 뽑는다. 전역 `Random()` 생성 금지.
- 값 자체는 **한 곳도 바꾸지 않는다.** 나눗셈은 `~/` 그대로, 난수 범위도 그대로.
- `BattleSetup.seed` 로 `Random(seed)` 하나를 만들고 전투 내내 그것만 쓴다.
  뽑는 **순서**가 결과를 결정하므로, 순서도 현재 코드와 같게 유지한다.

## 완료 판정 기준

- [x] 19개가 각각 단위 테스트로 고정된다 → `packages/hd_battle/test/rules/`
      (수식을 테스트 안에 복사하지 않고 **함수를 호출**해 검증한다)
- [x] 같은 시드로 두 번 돌리면 뽑히는 난수 열이 같다
- [x] 시드 없는 `Random()` 생성이 0 이다 — `test/flow/purity_test.dart`
      (**주석을 걷어낸 뒤** 본다. 각 수식의 주석이 원작 코드를 그대로 인용하고 있어서
      생 grep 은 그 주석을 오탐한다. 인용은 이식 검증에 필요하므로 검사 쪽을 맞췄다)
- [x] 부록 H-2 의 대역표(ac 2 → 83.0% / ac 10 → 36.0% / ac 20 → 16.0%, 최대 피해 9/8/7)를
      새 함수로 재현한다 — 값이 다르면 이식이 깨진 것이다

## 결과 (2026-09-04)

19개 전부 `lib/src/rules/` 에 순수 함수로 있고, 각 함수 주석에 원작 위치와 원래 코드가 붙어 있다.
`ScriptedRng`(정해진 뽑기 열을 내주는 구현)이 있어서 테스트가 **원본 함수를 직접 구동**한다 —
`defense_scale_test.dart` 가 수식을 복사해야 했던 이유가 없어졌다.

부록 H-2 의 대역표는 `test/rules/enemy_action_test.dart` 에서 `enemyPhysicalDamage` 를
100가지 뽑기 조합으로 돌려 **정확히 재현**된다(83.0 / 65.0 / 45.0 / 36.0 / 16.0, 최대 9 / 8 / 7).

**뽑기 순서에서 살려야 했던 것**: 특수 능력이 없는 적은 `&&` 단축 평가 때문에
**아무 숫자도 뽑지 않는다**(`chooseEnemyAttack`). 이 조건을 재배치하면 그 뒤의 모든 뽑기가
밀려서 같은 시드가 다른 결과를 낸다. 테스트가 `rng.draws == 0` 으로 고정한다.

## 하지 않을 것

전투식 수정·밸런스 조정(B2) · 턴 진행 구조(B1-04) · 마법 45종 개별화(B2-01) ·
`defense_scale_test.dart` 삭제(B4-03).
