# P0-14 범위 밖 인자가 조용히 무시된다 (`Flag::Set(300)` 등)

- **상태**: TODO
- **구간**: P0
- **규모**: S
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 F-1 · §9 침묵 실패 · B-1](../../blueprint/_meta/GROUND_TRUTH.md) · [D-04 ID 체계](../../blueprint/_meta/DECISIONS.md) · [BP-33 검증 규칙](../../blueprint/33_validation_and_lint.md)

## 문제

`hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362-392` — 범위 검사에 `else` 가 없다:

```dart
e.registerCommand('Flag::Set', (stmt, eng) async {
  final flagId = eng.getVal(stmt.args[0]);
  final idx = flagId is num ? flagId.toInt() : int.tryParse(flagId.toString()) ?? -1;
  if (idx >= 0 && idx < HDConfig.maxFlags) {
    flags()[idx] = true;
  }                          // ← :367  else 없음
});
```

같은 형태가 4곳(본인 확인):

| 커맨드 | 줄 | 가드 |
|---|---|---|
| `Flag::Set` | `:365-367` | `idx >= 0 && idx < HDConfig.maxFlags` |
| `Flag::Reset` | `:372-374` | 같음 |
| `Variable::Set` | `:379-381` | `idx < HDConfig.maxVariables` |
| `Variable::Add` | `:389-391` | 같음 |

`HDConfig.maxFlags` = 256, `maxVariables` = 256 (부록 §12).
**`Flag::Set(300)` 은 아무 일도 하지 않고 아무 로그도 남기지 않는다.**

읽기 쪽도 같다 — `:503-517`:

```dart
e.registerFunction('Flag::IsSet', (args, __) {
  final idx = (args.isNotEmpty && args[0] is num) ? (args[0] as num).toInt() : -1;
  if (idx >= 0 && idx < HDConfig.maxFlags) {
    return HDGameSession().gameOption.flags[idx] ? 1 : 0;
  }
  return 0;                  // ← :508  범위 밖도 "꺼짐" 과 같은 0
});
```

**즉 `Flag::IsSet(300)` 은 오타든 범위 초과든 "플래그가 꺼져 있다" 와 구별되지 않는다.**

같은 계열의 별건: `battle.dart:43-46` 의 `registerEnemy` — `<= 0` 가드로 침묵 반환.
그쪽은 [P0-15](P0-15-enemy-id-zero.md) 소관이다.

부록 F-1 이 강조한 구분: 이것은 **§9 의 "미등록 심볼 침묵 실패" 와 원인이 다른 별개 계열**이다.
전자는 오타로 생기고(`Unknown command` 는 그래도 출력된다), 후자는
**정상 문법·정상 심볼인데 값이 범위 밖**일 때 생긴다 — 출력이 아예 없다.

## 왜 지금 고쳐야 하는가

- [MILESTONES.md §2](../MILESTONES.md) 의 P0 완료 기준 6번: "범위 밖 인자(`Flag::Set(300)`, `Battle::RegisterEnemy(0)`)가
  **침묵하지 않는다**".
- [D-04](../../blueprint/_meta/DECISIONS.md)(이름 있는 상태 키)의 직접 근거다 — 정수 인덱스에는 "범위 밖" 이라는 실패 양식이 내재한다.
  P1 이 이름 키로 옮기더라도 **레거시 cm2 는 계속 정수를 쓴다**(BP-28 의 공존 기간).
- 지금 조용히 실패하는 cm2 스크립트가 실제로 있는지 알 수 없다. 로그를 켜야 **그 사실을 알 수 있게** 된다.

## 무엇을 할 것인가

`script_engine_adapter.dart` 만 손댄다. 4개 커맨드 + 2개 함수에 `else` 를 추가한다.

```diff
  if (idx >= 0 && idx < HDConfig.maxFlags) {
    flags()[idx] = true;
+ } else {
+   _warnOutOfRange('Flag::Set', idx, HDConfig.maxFlags);
  }
```

공통 헬퍼 하나를 같은 파일에 둔다:

```dart
/// Out-of-range integer args used to vanish silently (부록 F-1).
/// Content authors could not tell a typo from a working script.
void _warnOutOfRange(String symbol, int idx, int max) {
  print('ScriptEngine: [WARN] $symbol($idx) out of range [0, $max) — ignored');
}
```

읽기 쪽(`Flag::IsSet`·`Variable::Get`)은 **반환값을 바꾸지 않는다** — `0` 을 유지한다.
반환값을 바꾸면 기존 cm2 분기가 뒤집히므로 P0(순수 복구)의 범위를 넘는다. 경고만 추가한다.

### 로그 채널 선택

| 후보 | 장점 | 단점 |
|---|---|---|
| `print` | 파일 안의 기존 방식과 동일(`:97` 등이 이미 `print`) | 릴리즈 웹에서 콘솔에만 남는다. lint `avoid_print` info 가 늘어난다(CI 는 `--no-fatal-infos` 라 통과) |
| `HDHosts().ui.addLog(isDialogue: false)` | 플레이어/저작자가 게임 안에서 본다 | 저작 중 노이즈가 대화창을 덮을 수 있다. 커맨드 핸들러가 async 가 아닌 함수 쪽에서는 쓰기 어렵다 |
| 둘 다 | 개발 중 발견율이 가장 높다 | 구현량 증가 |

**권고: `print`.** 파일의 기존 관례와 같고, 저작 루프(데스크톱 실행)에서 즉시 보인다.
게임 내 노출은 [P1-12](../deferred/P1-12-content-cli.md)(`validate`)가 **정적으로** 잡는 것이 옳은 자리다.

## 완료 판정 기준

- [ ] `Flag::Set(300)` · `Flag::Reset(300)` · `Variable::Set(300, 1)` · `Variable::Add(300)` 각각이
      **경고 로그를 남긴다** (심볼명·인덱스·허용 범위 포함)
- [ ] `Flag::IsSet(300)` · `Variable::Get(300)` 이 경고를 남기고, **반환값은 여전히 `0`** 이다
- [ ] 범위 안 인자에서는 로그가 추가되지 않는다 (정상 경로 노이즈 없음)
- [ ] `flutter analyze --no-fatal-infos` · `flutter test` 통과
- [ ] 테스트 추가: `hadar2026_app/test/application/scripting/out_of_range_args_test.dart` —
      `map_navigation_test.dart` 의 페이크 바인딩 패턴으로 엔진을 구동하고,
      ① 범위 밖 `Flag::Set` 이 `gameOption.flags` 를 바꾸지 않음 ② 범위 안 인자는 정상 동작함을 고정한다.
      로그 문자열 자체는 고정하지 않는다 (구현 세부에 테스트를 묶지 않기 위해)

## 하지 않을 것

- `Flag::IsSet` 등 **읽기 함수의 반환값 변경**. 기존 cm2 분기를 뒤집는다.
- `maxFlags`/`maxVariables` 값 변경(256 → 다른 값).
- 미등록 커맨드/함수의 침묵 실패(부록 §9) — `packages/cm2_script` 소관이며 별건.
- `Battle::RegisterEnemy(0)` — [P0-15](P0-15-enemy-id-zero.md) 소관.
- 정수 인덱스를 이름 키로 바꾸기 — [D-04](../../blueprint/_meta/DECISIONS.md) · [P1-03](../deferred/P1-03-worldstate-unification.md) 소관.
- 정적 검증(`validate`) 도입 — [P1-12](../deferred/P1-12-content-cli.md) 소관.
