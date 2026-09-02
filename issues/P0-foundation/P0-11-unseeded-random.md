# P0-11 전투에 시드 없는 `Random()` 14곳 — 주입 가능하게 만든다

- **상태**: TODO
- **구간**: P0
- **규모**: M
- **선행**: P0-10
- **설계 근거**: [`GROUND_TRUTH` 부록 C-4](../../blueprint/_meta/GROUND_TRUTH.md) · [D-08a](../../blueprint/_meta/DECISIONS.md) · [D-21 `chance` 무커서 해시](../../blueprint/_meta/DECISIONS.md) · [BP-27 `WorldRng` 소유](../../blueprint/27_runtime_engine.md)

## 범위 선언 (먼저 읽을 것)

**`WorldRng`(`seed` + `step` + `rngCursor`)는 [BP-27](../../blueprint/27_runtime_engine.md) 이 소유하고 P1 에서 도입한다.**
이 이슈는 **`Random()` 직접 생성을 없애고 주입 가능한 하나의 구멍으로 모으는 것**까지다.
시드 관리·커서·트레이스 재현은 P1 이다.

## 문제

`hadar2026_app/lib/application/battle.dart` 는 `Random()` 을 **호출 지점마다 새로 생성**한다.
본인 실측: `grep -c 'Random(' lib/application/battle.dart` = **14**. 전 지점:

| 줄 | 코드 | 역할 |
|---|---|---|
| 155 | `(p.level.magic + p.level.esp) * 5 + Random().nextInt(10)` | 마법 피해 |
| 174 | `(p.level.magic + p.level.esp) * 8 + Random().nextInt(15)` | 마법 피해 |
| 389 | `(p.agility + p.luck) ~/ 2 + Random().nextInt(20)` | 도주 판정 |
| 427 | `if (Random().nextInt(20) > p.accuracy.physical)` | 명중 판정 |
| 432 | `if (Random().nextInt(100) < t.resistance)` | 저지 판정 |
| 440 | `damage -= (damage * Random().nextInt(50)) ~/ 100` | 피해 감쇠 0~49% |
| 441 | `damage -= (t.ac * t.level * (Random().nextInt(10) + 1)) ~/ 10` | 적 방어 |
| 474 | `targets[Random().nextInt(targets.length)]` | 적의 표적 선택 |
| 478–479 | `Random().nextInt(e.accuracy[0] * 1000 + 1) > Random().nextInt(...)` | 적 명중 (2회) |
| 488 | `(e.level * 5) + Random().nextInt(10)` | 적 마법 피해 |
| 503 | `if (Random().nextInt(50) < t.resistance)` | 저지 판정 |
| 513 | `(e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10` | 적 물리 피해 |
| 514 | `damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10` | 플레이어 방어 |

`Random()` 은 인자 없이 만들면 구현이 정한 시드(시각 등)를 쓴다.
**따라서 같은 입력으로 두 번 돌려도 전투 결과가 다르다.**
[P0-10](P0-10-wallclock-poison-damage.md)(벽시계 독 피해)과 합쳐 게임 전체가 재현 불가 상태다.

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 5번이 이 항목을 직접 지목한다.
- [D-15](../../blueprint/_meta/DECISIONS.md) 의 골든 회귀 테스트, [BP-34](../../blueprint/34_headless_sim_and_solver.md) 의 퍼저·솔버는 재현성 없이는 성립하지 않는다.
- 재현성이 없으면 **전투 밸런스 변경을 검증할 방법이 없다** — [P1-06](../deferred/P1-06-equipment-wiring.md)(장비 배선)이 전투식을 건드릴 때 회귀를 잡을 수 없다.
- 지금 고치는 비용이 P1 에서 고치는 비용보다 낮다: 14곳을 한 번에 치환하는 기계적 작업이고,
  P1 은 그 구멍에 `WorldRng` 를 꽂기만 하면 된다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 장점 | 단점 |
|---|---|---|---|
| A | **`HDBattle` 에 주입 가능한 `Random` 필드 하나** — `Random _rng = Random();` + `void setRng(Random r)` | 14곳을 `_rng.nextInt(...)` 로 기계 치환. 테스트는 `Random(42)` 를 넣으면 끝 | `HDBattle` 은 싱글턴이라 상태가 전역이 된다 (이미 그런 코드베이스이므로 새 문제는 아님) |
| B | `int Function(int)` 콜백을 주입 | `dart:math` 의존을 끊는다 | 14곳의 호출 형태가 제각각(`nextInt` 만 쓰므로 실제로는 균일) — 이득이 작다 |
| C | 곧바로 `WorldRng` 를 만든다 | P1 작업을 앞당긴다 | **[BP-27](../../blueprint/27_runtime_engine.md) 소유 위반.** `seed`/`step`/`rngCursor` 계약이 아직 확정 전이고 [D-21](../../blueprint/_meta/DECISIONS.md) 의 `siteId` 규칙과 얽힌다 |

### 권고안: **A**

```diff
  class HDBattle with ChangeNotifier {
    ...
+   /// Single injection point for battle randomness. P0 only removes the
+   /// per-call `Random()` construction; seeding/cursor/replay is P1's
+   /// `WorldRng` (BP-27). Tests inject `Random(42)`.
+   Random _rng = Random();
+   void setRng(Random rng) => _rng = rng;
```

그리고 14곳을 치환한다.

```diff
- if (Random().nextInt(20) > p.accuracy.physical) {
+ if (_rng.nextInt(20) > p.accuracy.physical) {
```

- `battle.dart:478-479` 의 **한 식 안에 2회 호출**은 순서가 결과에 영향을 준다.
  `_rng` 로 바꾸면 호출 순서가 곧 소비 순서가 되므로, **인자 평가 순서에 의존하지 않도록**
  두 값을 지역 변수로 먼저 뽑아 명시적으로 만든다.
- `HDBattle().init()`(`:34-41`)에서 `_rng` 를 **리셋하지 않는다** — 리셋 정책은 시드 도입 시 결정할 일이다.
  그 판단을 주석으로 남긴다.
- `magic_system.dart` 등 다른 파일의 `Random()` 사용도 함께 조사한다.
  이 이슈의 판정 기준은 `application/`·`domain/` 전체에서 `Random()` 직접 생성이 없어지는 것이다.

## 완료 판정 기준

- [ ] `grep -rn "Random()" hadar2026_app/lib/application/ hadar2026_app/lib/domain/` 가
      **필드 초기화 1줄(과 [P0-10](P0-10-wallclock-poison-damage.md) 의 기본 난수 1줄)을 제외하고 빈 결과**다
- [ ] `HDBattle().setRng(Random(42))` 로 고정한 뒤 같은 파티·같은 적·같은 명령으로 전투를 두 번 돌리면
      **양쪽의 전투 로그와 `result()` 가 완전히 같다**
- [ ] 시드를 42 → 43 으로 바꾸면 결과가 달라진다 (주입이 실제로 먹는다는 반대 증명)
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과
- [ ] 테스트 추가: `hadar2026_app/test/application/battle_determinism_test.dart` —
      `map_navigation_test.dart` 의 페이크 바인딩 패턴으로 `UiHost` 를 페이크(로그 수집)로 바인딩하고,
      `setRng(Random(42))` 두 회차의 **수집된 로그 리스트가 동일**함을 고정한다.
      `tearDown(HDHosts().reset)` 포함

## 하지 않을 것

- **`WorldRng` · `seed` · `step` · `rngCursor` 도입** — [BP-27](../../blueprint/27_runtime_engine.md) 소유, P1.
- [D-21](../../blueprint/_meta/DECISIONS.md) 의 `chance` 무커서 해시(`splitmix64`) 구현 — 같음.
- 시드를 세이브에 저장하기 — [P1-04](../deferred/P1-04-save-v2.md) 소관.
- 전투 수식·밸런스 변경. 값과 순서를 그대로 옮긴다 (`:478-479` 의 명시화는 순서 보존을 위한 것).
- 벽시계 독 피해 — [P0-10](P0-10-wallclock-poison-damage.md) 소관 (선행).
