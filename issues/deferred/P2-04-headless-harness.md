# P2-04 헤드리스 하네스 (`HeadlessUiHost` 등)

> **[보류 — DEFERRED]** 이 이슈는 **무거운 생성 파이프라인 노선**(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스)에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 경량 대체는 [S3-generation/](../S3-generation/) 이다 — 생성 타깃이 선언적 콘텐츠 팩이 아니라 **cm2 + 맵 JSON** 이다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: GATED
- **구간**: P2
- **규모**: L
- **선행**: P2-03
- **설계 근거**: [BP-34 §3](../../blueprint/34_headless_sim_and_solver.md) · [BP-34 §4](../../blueprint/34_headless_sim_and_solver.md) · [GROUND_TRUTH §3 · 부록 B-4 정정판](../../blueprint/_meta/GROUND_TRUTH.md) · [D-13](../../blueprint/_meta/DECISIONS.md)

## 문제

포트 3종은 이미 있지만 **그 포트를 채운 헤드리스 구현이 없다.** 지금 존재하는 페이크는
`AssetSource` 하나뿐이고, 그것도 테스트 파일 안의 private 클래스다 —
`hadar2026_app/test/application/map_navigation_test.dart:13` `class _FakeAssets implements AssetSource`.
그 테스트는 `:71` 에서 `HDHosts().bind(...)` 로 주입하고 `:78` 에서 `tearDown(HDHosts().reset)` 한다.
**이 패턴이 이미 있는 선례**이고, 이 이슈는 그것을 이름·대화·이동까지 확장하는 일이다.

`UiHost`(`lib/application/ports/ui_host.dart`, 97줄)는 추상 메서드 **11개**를 요구한다:
`showMenu`(`:13`) · `showWindowMenu`(`:26`) · `showMessageWindow`(`:38`) · `addLog`(`:44`) ·
`waitForAnyKey`(`:48`) · `clearLogs`(`:54`) · `setHeader`(`:63`) · `beginNarrative`(`:70`) ·
`endNarrative`(`:81`) · `refresh`(`:90`) · `preloadAssets`(`:96`).
**하나라도 빠지면 컴파일되지 않는다** — 부분 구현으로 시작할 수 없다.

하네스가 없으면 8단계 파이프라인의 6단계(sim)와 골든 트레이스 회귀가 성립하지 않는다.
스키마가 맞고 참조가 다 풀려도 "실제로 클리어되는가" 는 굴려 보지 않으면 알 수 없다.

**P0-16 에 대한 경성 의존**: `lib/application/menu_flows.dart:2` 가 `import 'dart:io';` 를 하고
`:504`·`:522`·`:540` 에서 `exit(0)` 를 호출한다. 게임 오버·종료 확인 흐름에 닿으면 **시뮬레이터
프로세스가 통째로 죽는다** — 배치 검증 중 한 시나리오가 프로세스를 내리면 나머지 결과가 전부 사라진다.
P0-16 이 이 3곳을 `UiHost` 의 종료 요청으로 바꾸지 않으면 이 이슈는 완성될 수 없다.
(부록 B-4 는 **정정판**이다 — "웹 빌드가 깨진다" 는 실빌드로 반증되었으므로 근거로 쓰지 않는다.
유효한 것은 계층 위반과 **헤드리스 프로세스 사망** 두 가지다.)

## 무엇을 할 것인가

11(+`requestQuit` 12)개 메서드별 구현 방침표와 `SimDriver`·`SimTrace` 포맷, 정책 3종의
인터페이스는 [BP-34 §3 · §4](../../blueprint/34_headless_sim_and_solver.md) 에 있다.

**배치가 두 조각으로 나뉘는 이유**(BP-34 §3.1): `application/` 은 `package:flutter/foundation.dart` 를
쓰고 그것은 `dart run` 에서 import 되지 않는다. 따라서 시뮬레이터는 **`flutter test` 프로세스**에 산다.

```
hadar2026_app/test/harness/
  headless_ui_host.dart        # UiHost 11개(+requestQuit) 전량 구현
  memory_asset_source.dart     # AssetSource. misses 를 기록(부록 A-1 류 검출)
  headless_movement_host.dart  # PartyMovementHost — animatePartyMove/showFacing/snapTo 즉시 완료
  sim_driver.dart  sim_policy.dart  sim_trace.dart  map_graph.dart
  harness_self_test.dart       # 하네스 자신의 테스트 (BP-34 §9 픽스처)
hadar2026_app/tool/sim_main.dart   # flutter test 진입점, --dart-define 으로 인자 수신
```

**접합점**
- `HDHosts().bind(ui:, movement:, assets:)` 로 주입. 신규 이음매를 만들지 않는다.
- `HeadlessMovementHost` 는 **좌표를 만지지 않는다.** 좌표 소유자는 P2-03 의 `PartyMovementController` 다.
  이 순서가 뒤집히면 하네스는 "이동은 되는데 타일 이벤트는 안 나는" 반쪽 상태가 된다.
- 모드 게이트는 `SimDriver` 가 소유한다(BP-34 R-34-3) — `HeadlessUiHost.isMenuOpen` /
  `isNarrativeActive` 를 읽어 의도 발행 여부를 정한다.
- `SimQuitSignal` 은 `GameReloadException` 과 같은 성격의 제어 흐름 예외다. 하네스가 잡는다.
- `MemoryAssetSource.misses` 가 비어 있지 않으면 실패로 본다(FZ-7).

## 착수 조건

GATE-1 통과 + **P2-03 완료** + **P0-16 완료**.

**왜 그 전에는 안 되는가**: P2-03 이 끝나지 않으면 이동 판정이 프레임 루프 안에 있어 `SimDriver` 가
파티를 한 칸도 움직일 수 없다 — 포트만 페이크로 바꿔도 아무 일도 일어나지 않는다(BP-34 BL-1).
P0-16 이 끝나지 않으면 게임 오버 경로에 닿는 순간 프로세스가 죽어 배치 결과가 사라진다.
그리고 하네스의 소비자는 솔버(P2-05)·퍼저(P2-06)·파이프라인 6단계(P2-07)뿐이므로,
GATE-1 이 보류로 나오면 굴릴 콘텐츠가 없는 시뮬레이터가 남는다.

## GATE-1 이 보류/취소로 판정되면

- **버려지는 것**: `SimDriver` 의 `greedy`/`random` 정책, `SimTrace` 직렬화, `map_graph.dart`,
  `tool/sim_main.dart` 진입점, 배치 실행. 이것들은 "대량 콘텐츠를 자동으로 굴린다" 를 전제한다.
- **그래도 남는 값**:
  - `HeadlessUiHost` + `MemoryAssetSource` + `HeadlessMovementHost` 3종은 **일반 테스트 하네스**다.
    지금 `test/` 에 위젯 테스트가 0건이고 `HDMenuFlows`·`HDBattle`·`HDTileEventDispatcher` 가
    테스트되지 않는 이유가 "UI 를 띄워야 한다" 이므로, 이 3종만으로 그 셋을 테스트할 수 있다.
    `map_navigation_test.dart` 가 `AssetSource` 하나로 이미 증명한 방식의 확장이다.
  - `scripted` 정책(주어진 입력 시퀀스)은 **버그 재현 픽스처**로 값이 있다 — "이 순서로 누르면
    깨진다" 를 커밋할 수 있게 된다.
- 즉 취소 시에는 3종 호스트 + `scripted` 만 남기고 P1 의 테스트 인프라로 재분류한다.

## 완료 판정 기준

**[잠정 — GATE-1 통과 시 확정]**

- [ ] `HeadlessUiHost` 가 `UiHost` 의 **11개 메서드 전부**(+ P0-16 이 추가한 종료 요청)를 구현한다
- [ ] `flutter test test/harness/harness_self_test.dart` 가 BP-34 §9 픽스처(5×5 맵·NPC 2·퀘스트 1)로
      완주 트레이스를 만든다
- [ ] 게임 오버 경로를 태워도 **테스트 프로세스가 살아 있다**
- [ ] `MemoryAssetSource.misses` 가 비면 통과, 비지 않으면 실패로 보고된다
- [ ] 같은 시드·같은 정책으로 두 번 돌린 트레이스가 **바이트 단위로 같다**(P0-10·P0-11 선행 필요)
- [ ] `scripted` 정책으로 같은 입력열을 재생하면 같은 트레이스가 나온다
- [ ] 계층 grep 이 여전히 빈 결과다(하네스는 `test/` 에 있으므로 검사 대상 밖이지만 `application/` 을 오염시키지 않았음을 확인)

## 하지 않을 것

- 솔버(P2-05) · 퍼저(P2-06) · CLI 래퍼(`hadar_content sim`, P2-09).
- 렌더 검증·스크린샷 비교. 헤드리스에는 렌더가 없다.
- 콘솔 페이지 넘김·텍스트 래핑 재현. 래핑은 표현이며 `addLog` 는 버퍼에 적재만 한다.
- `exit(0)` 제거 자체 — P0-16.
- 이동 루프 추출 자체 — P2-03.
