# P0-16 `application/` 이 `dart:io` 를 쓰고 `exit(0)` 를 호출한다

- **상태**: TODO
- **구간**: P0
- **규모**: M
- **선행**: 없음
- **설계 근거**: [`GROUND_TRUTH` 부록 B-4 (**정정판**)](../../blueprint/_meta/GROUND_TRUTH.md) · [D-23 CI 계층 검사](../../blueprint/_meta/DECISIONS.md) · [BP-34 헤드리스 하네스 선결 과제](../../blueprint/34_headless_sim_and_solver.md)

## ⚠ 근거 주의 — "웹 빌드가 깨진다" 는 반증되었다

부록 B-4 는 **정정판**이다. 초판의 "`dart:io` 때문에 웹 빌드가 깨져 있을 것" 이라는 추정은
`flutter build web --release` **실빌드로 반증**되었다(성공, exit code 0, `build/web` 산출).
**이 이슈에서 "웹 빌드 파손" 을 근거로 쓰지 않는다.**

유효한 근거는 셋이다:
1. **계층 위반** — CLAUDE.md 는 `application/` 의 `dart:io` 금지를 명시하지만 CI 가 잡지 않는다.
2. **헤드리스 하네스 파괴** — `exit(0)` 는 시뮬레이터 프로세스를 통째로 죽인다.
3. **[신규·미확인] 웹 런타임 동작** — 빌드는 되지만 웹에서의 실제 동작은 확인되지 않았다.

## 문제

`hadar2026_app/lib/application/menu_flows.dart:2`:

```dart
import 'dart:io';
```

`exit(0)` 호출 3곳(본인 확인 — 전부 `processGameOver` 안):

```dart
// :497-511  EXITCODE_BY_USER
int res = await _game.showWindowMenu(menu);
if (res == 2) {
  if (!kIsWeb) {
    exit(0);                    // ← :504
  } else {
    await _game.addLog("게임을 종료합니다. 브라우저 창을 닫아주세요.");
    await _game.waitForAnyKey();
  }
}
```

나머지 둘(`:521-523` EXITCODE_BY_ACCIDENT, `:539-541` EXITCODE_BY_ENEMY)은 같은 형태의
`if (!kIsWeb) { exit(0); }` 이고 `else` 가지가 없다.

### 본인 추가 확인 — 근거 3(웹 런타임)에 대한 정보

**3곳 모두 `if (!kIsWeb)` 로 감싸져 있다.** 따라서 웹에서 `exit(0)` 는 **호출되지 않는다**
(`:504` 는 `else` 가지에서 안내 메시지를, `:522`·`:540` 은 아무 것도 하지 않는다).
부록 B-4-4 가 우려한 "웹에서 `exit(0)` 가 호출될 때의 런타임 오류" 는 **가드로 이미 차단된 상태**로 보인다.
단 **브라우저에서 실제로 그 메뉴를 눌러 확인하지는 않았다 — 여전히 "미확인" 이다.**
그리고 `:522`·`:540` 의 웹 경로는 `else` 가 없어 **게임 오버 후 아무 일도 일어나지 않는다** — 별개의 UX 결함이다.

## 왜 지금 고쳐야 하는가

- [D-23](../../blueprint/_meta/DECISIONS.md) 이 CI 에 `dart:io`/`dart:html` 검사를 추가하기로 확정했고,
  **"이 검사 추가와 `exit(0)` 3곳 제거는 같은 변경으로 함께 가야 한다. 먼저 추가하면 CI 가 즉시 빨개진다"** 를 명시했다.
  즉 [P0-17](P0-17-ci-gates.md) 이 이 이슈에 의존한다.
- [BP-34](../../blueprint/34_headless_sim_and_solver.md) 의 헤드리스 시뮬레이터는 게임 오버를 **정상 종료 신호**로 받아야 한다.
  `exit(0)` 는 하네스 프로세스를 죽여 배치 실행을 불가능하게 만든다.
- CLAUDE.md 가 이미 규칙으로 선언한 것을 코드가 위반하고 있다. 문서와 코드의 불일치 자체가 비용이다.

## 무엇을 할 것인가

### 선택지 비교

| # | 안 | 장점 | 단점 |
|---|---|---|---|
| A | **`UiHost` 에 `quitGame()` 포트 메서드 추가** — `application/` 은 포트를 부르고, `presentation/host/HDFlutterUiHost` 가 `exit(0)`(데스크톱)/안내(웹)를 구현 | 3포트 계약과 일관된다. 하네스는 "종료 요청됨" 을 기록만 하면 된다. `kIsWeb` 분기도 presentation 으로 내려간다 | `UiHost` 인터페이스가 커진다. 페이크 구현 2곳(`map_navigation_test.dart` 의 `_UnusedUiHost` 는 `noSuchMethod` 라 영향 없음) |
| B | 예외를 던져 상위에서 처리 — `GameQuitException` | `GameReloadException` 선례와 같은 형태 | 예외를 잡는 곳이 `main.dart` 여야 하고, 잡지 않으면 크래시로 보인다 |
| C | `dart:io` 임포트만 조건부로 감추기 (`kIsWeb` + 조건부 임포트) | 최소 변경 | 계층 위반이 남는다. CI 검사([P0-17](P0-17-ci-gates.md))가 여전히 걸린다. **근거 1을 해결하지 못한다** |

### 권고안: **A**

1. `lib/application/ports/ui_host.dart` 의 `UiHost` 에 추가:

   ```dart
   /// Requests process termination. The host decides what that means:
   /// desktop exits, web shows a "close the tab" notice, a headless
   /// harness records the request and returns. `application/` must never
   /// call `dart:io`'s exit() itself (부록 B-4, D-23).
   Future<void> quitGame();
   ```

2. `lib/presentation/host/` 의 `HDFlutterUiHost` 에 구현을 두고, 거기서 `dart:io` 를 임포트한다
   (`presentation/` 은 금지 대상이 아니다). `kIsWeb` 분기와 `:506` 의 안내 메시지도 이쪽으로 옮긴다.
3. `menu_flows.dart` — `import 'dart:io';` 삭제, `exit(0)` 3곳을 `await _game.quitGame();` 으로 교체.
   `:521-523`·`:539-541` 의 `if (!kIsWeb)` 가드도 함께 제거한다 (분기가 호스트로 내려갔으므로).
4. `lib/hd_game_main.dart` 는 `UiHost` 를 구현하므로 **전달 메서드 1개를 추가**한다.
5. 웹 경로 결함(`:522`·`:540` 이후 아무 일도 없음)은 호스트의 웹 구현에서
   `:506` 과 같은 안내 메시지를 내보내 **3경로가 동일하게 동작**하도록 맞춘다.

## 완료 판정 기준

- [ ] `grep -rn "^import 'dart:io'" hadar2026_app/lib/application/ hadar2026_app/lib/domain/` 가 **빈 결과**다
- [ ] `grep -rn "exit(0)" hadar2026_app/lib/application/ hadar2026_app/lib/domain/` 가 **빈 결과**다
- [ ] 데스크톱(`flutter run -d macos`)에서 "게임을 끝낸다" 를 고르면 **프로세스가 종료된다** (회귀 없음)
- [ ] 게임 오버 3경로(`exitCode` 0·1·2) 모두에서 웹 실행 시 **안내 메시지가 나온다** — 침묵 없음
- [ ] `flutter build web --release` 가 여전히 성공한다 (반증된 근거를 되살리지 않기 위한 회귀 확인)
- [ ] 테스트 추가: `hadar2026_app/test/application/quit_flow_test.dart` —
      `map_navigation_test.dart` 의 페이크 바인딩 패턴으로 `quitGame()` 호출을 세는 페이크 `UiHost` 를 바인딩하고,
      `processGameOver(0/1/2)` 각 경로에서 **`quitGame` 이 정확히 1회 불림**을 고정한다.
      **이것이 헤드리스 하네스가 종료를 관측하는 방식의 최초 선례가 된다.**

## 하지 않을 것

- **"웹 빌드가 깨진다" 를 근거로 서술하는 것** — 실빌드로 반증됨(부록 B-4 정정판).
- CI 에 `dart:io` 검사 추가 — [P0-17](P0-17-ci-gates.md) 소관. **단 [D-23](../../blueprint/_meta/DECISIONS.md) 에 따라 같은 PR 로 묶어야 한다.**
- 이동·상호작용 루프의 `application/` 추출 — [P2-03](../deferred/P2-03-movement-loop-extraction.md) 소관(부록 B-3).
- `HeadlessUiHost` 구현 — [P2-04](../deferred/P2-04-headless-harness.md) 소관.
- 게임 오버 흐름·메뉴 문구의 재설계. 종료 경로 배선만 바꾼다.
- `dart:html` 사용 추가 (D-23 이 함께 금지한다).
