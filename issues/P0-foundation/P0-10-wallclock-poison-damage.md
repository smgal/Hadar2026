# P0-10 독 데미지가 벽시계로 결정된다 — 재현 불가

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 C-4](../../blueprint/_meta/GROUND_TRUTH.md) · [D-08a 벽시계 제거·논리 시각 `step`](../../blueprint/_meta/DECISIONS.md) · [BP-27 `WorldRng`](../../blueprint/27_runtime_engine.md)

## 문제

`hadar2026_app/lib/domain/party/player.dart:69-72`:

```dart
void damagedByPoison() {
  // 20 ~ 39 damage
  damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));
}
```

**벽시계가 데미지를 결정한다.** 이것이 `lib/` 전체에서 `DateTime.now()` 를 쓰는 **유일한 지점**이다
(본인 확인: `grep -rn "DateTime.now()" lib/` 결과 1건).

호출 경로 — `lib/domain/party/party.dart:234-253`:

```dart
void timeGoes() {
  ...
  for (var player in players) {
    if (player.isValid()) {
      if (player.poison > 0) {
        player.poison++;
        if (player.poison > 10) {
          player.poison = 1;
          player.damagedByPoison();     // ← :249
        }
      }
    }
  }
```

`timeGoes` 는 `presentation/panels/player_sprite.dart:185` 의
`gameSystem.passTime(..., onTimeGoes: party.timeGoes)` 로 **이동마다** 불린다.
즉 독 상태에서는 걸음마다 20~39 의 재현 불가한 피해가 들어온다.

부가 문제: 이 코드는 `domain/` 에 있다. `domain/` 은 순수 규칙 계층이므로
**"현재 시각" 이라는 외부 세계를 참조하는 것 자체가 계층 취지에 어긋난다**(CI grep 은 잡지 않는다).

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 5번: "같은 시드·같은 입력으로 두 번 돌리면 전투 결과가 동일하다
  (**벽시계**·무시드 난수 제거)".
- [D-08a](../../blueprint/_meta/DECISIONS.md) 는 세이브에서 벽시계를 몰아내며 "벽시계를 넣으면 동일 입력 재현이 불가능해지고
  헤드리스 시뮬레이터의 트레이스 비교와 골든 회귀([D-15](../../blueprint/_meta/DECISIONS.md))가 성립하지 않는다" 를 근거로 삼았다.
  **이 코드가 바로 그 조건을 위반하는 실물**이다.
- [P0-11](P0-11-unseeded-random.md)(무시드 `Random()` 14곳)의 **선행**이다. 둘은 같은 주입 지점을 공유해야 한다.

## 무엇을 할 것인가

`domain/party/player.dart` 만 손댄다. 벽시계를 **주입 가능한 난수**로 바꾼다.

```diff
- void damagedByPoison() {
-   // 20 ~ 39 damage
-   damaged(20 + (DateTime.now().millisecondsSinceEpoch % 20));
- }
+ /// 20 ~ 39 damage. [rand] must produce a value in [0, 20).
+ /// The wall clock is deliberately NOT used here — it made poison
+ /// damage unreproducible (부록 C-4, D-08a).
+ void damagedByPoison(int Function(int max) rand) {
+   damaged(20 + rand(20));
+ }
```

호출부(`party.dart:249`)도 같은 함수를 위로 흘린다:

```diff
- void timeGoes() {
+ void timeGoes({int Function(int max)? rand}) {
+   final roll = rand ?? _defaultRand;
    ...
-         player.damagedByPoison();
+         player.damagedByPoison(roll);
```

- **`_defaultRand` 는 이 이슈에서 `Random().nextInt` 로 둔다.** 아직 시드를 도입하지 않는다 —
  그것은 [P0-11](P0-11-unseeded-random.md) 이 `Random()` 을 주입 가능하게 만드는 작업과 함께 간다.
  이 이슈의 성과는 **"벽시계 제거 + 주입 구멍 확보"** 두 가지다.
- `presentation/panels/player_sprite.dart:185` 의 `onTimeGoes: party.timeGoes` 는
  기명 인자가 옵셔널이므로 **호출부 변경 없이 컴파일된다**.
- `domain/` 은 `dart:math` 를 임포트해도 계층 규칙에 걸리지 않는다 (금지 목록은 material/bonfire/flame + `dart:io`).

## 완료 판정 기준

- [ ] `grep -rn "DateTime.now()" hadar2026_app/lib/` 가 **빈 결과**다
- [ ] `HDParty.timeGoes(rand: (max) => 7)` 처럼 고정 난수를 넘기면 독 피해가 **항상 27** 이다
- [ ] 기존 호출부(`player_sprite.dart:185`)는 수정 없이 컴파일된다
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과
- [ ] 테스트 추가: `hadar2026_app/test/domain/party/poison_damage_test.dart` —
      ① `rand` 를 고정하면 피해가 결정적임 ② `rand(20)` 의 경계값 0 과 19 에서 피해가 20 과 39 임
      ③ `poison` 카운터가 10 을 넘을 때만 피해가 발생함을 고정한다.
      기존 `test/domain/party/party_actions_test.dart` 와 같은 폴더에 둔다

## 하지 않을 것

- 시드 있는 RNG(`WorldRng`) 도입 — [P1](../MILESTONES.md) 소관이며 [BP-27](../../blueprint/27_runtime_engine.md) 이 소유한다.
- `battle.dart` 의 `Random()` 14곳 — [P0-11](P0-11-unseeded-random.md) 소관.
- 논리 시각 `step` 도입 — [D-08a](../../blueprint/_meta/DECISIONS.md) 가 `WorldState` 필드로 확정했고 [P1-03](../deferred/P1-03-worldstate-unification.md) 소관.
- 독 규칙 자체의 밸런스 변경(피해량·주기). 값은 그대로 둔다.
- `HDGameSystem.passTime` 의 시간 모델 변경.
