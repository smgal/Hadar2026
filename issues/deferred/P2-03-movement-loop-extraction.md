# P2-03 이동·상호작용 루프를 `application/` 으로 추출

> **[보류 — DEFERRED]** 이 이슈는 **무거운 생성 파이프라인 노선**(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스)에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 경량 대체는 [S3-generation/](../S3-generation/) 이다 — 생성 타깃이 선언적 콘텐츠 팩이 아니라 **cm2 + 맵 JSON** 이다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: GATED
- **구간**: P2
- **규모**: L
- **선행**: GATE-01
- **설계 근거**: [BP-34 §2.2](../../blueprint/34_headless_sim_and_solver.md) · [GROUND_TRUTH 부록 B-3 · 부록 K](../../blueprint/_meta/GROUND_TRUTH.md) · [D-13](../../blueprint/_meta/DECISIONS.md)

## 문제

**막힌 것은 헤드리스 구동이다. 콘텐츠 발화는 막혀 있지 않다.** 이 구분이 이 이슈의 범위를 정한다.

이동 판정과 타일 상호작용 트리거가 Bonfire 스프라이트의 프레임 폴링 안에 있다 —
`hadar2026_app/lib/presentation/panels/player_sprite.dart`(424줄)의 `update(double dt)`(`:103`)가
`_checkInput()`(`:223`)과 `_moveTowardsTarget(dt)`(`:164`)을 호출하고, 그 안에서
도메인·애플리케이션 책임이 함께 실행된다:

| 줄 | 실제 코드 | 성격 |
|---|---|---|
| `:269` | `party.setFace(dx, dy)` | 도메인 |
| `:290` | `HDTileProperties.isUnitPassable(...)` | 도메인 규칙 |
| `:176` | `party.move(...)` | 도메인 좌표 확정 |
| `:183`·`:185` | `passTime(0,2,0)` / `passTime(0,0,5)` — 맵 종류별 경과 | 도메인 규칙 |
| `:193` | `HDGameMain().checkTileEvent(party.x, party.y, isInteraction: false)` | 애플리케이션 |
| `:362` | `await HDGameMain().checkTileEvent(nextX, nextY, isInteraction: true)` | 애플리케이션 |
| `:405` | `HDGameMain().checkTileEvent(targetX, targetY, isInteraction: true)` | 애플리케이션 |

→ 포트 3종(`UiHost`·`PartyMovementHost`·`AssetSource`)을 페이크로 갈아도 **파티가 한 칸도 움직이지 않는다.**
프레임 루프가 없으면 아무 일도 일어나지 않는다(BP-34 BL-1).

**부록 K 가 좁혀 준 것 — 이 이슈가 아닌 문제**

`checkTileEvent` 진입점 3개 중 **2개는 이미 타일 액션 선검사가 없다** — step-on(`:193`)과 확인키(`:405`).
콘텐츠 티어가 `(map, x, y)` 로 트리거 인덱스를 직접 조회하면 앵커가 맵에 표시를 남기지 않아도 발화하며,
D-27 의 전제는 **코드 변경 없이** 충족된다(부록 K-1). 게이트가 남은 것은 bump 경로 하나뿐이고
(`:359` `if (action.isInteractive)`) 그 제거는 **P0-18** 소관이다(부록 K-2, 1줄 수준).

→ **따라서 이 이슈는 "앵커를 발화시키기 위한" 작업이 아니다.** 목표는 오직 하나:
**이동·상호작용 판정을 프레임 루프 밖에서 호출할 수 있게 만드는 것.**
"게이트를 열어 콘텐츠가 발화되게 한다" 를 이 이슈의 근거로 쓰면 P0-18 과 범위가 겹치고,
부록 K 가 정정한 사실("발화는 이미 열려 있다")을 다시 흐리게 된다.

부수 문제: `PartyMovementHost` 포트가 현재 **도메인 좌표의 소유자**다 —
`lib/presentation/host/flutter_ui_host.dart:283` `animatePartyMove` 가 `:288` 에서 `player.forceMove` 를
부르고, 뷰포트가 없으면 `:293` 에서 `HDGameSession().party.move(dx, dy)` 로 **직접 좌표를 바꾼다.**
포트가 표현이 아니라 도메인을 움직이고 있다.

## 무엇을 할 것인가

책임 20건의 전수 분류(이관 12 / 잔류 8)와 `step()` 의 확정 실행 순서, before/after 코드 스케치는
[BP-34 §2.2](../../blueprint/34_headless_sim_and_solver.md) 에 있다. 여기서는 접합점만 적는다.

**신규**
- `hadar2026_app/lib/application/movement/party_movement_controller.dart` — `PartyMovementController`
  (싱글턴). 공개 표면 4개: `step(HDMoveIntent, {fromScript})` · `interactFacing()` ·
  `scriptMove(dx, dy)` · `releaseInteractionLatch()` + `reset()`.

**`application/` 으로 옮길 것** (파일·메서드 단위)

| 출처 | 대상 |
|---|---|
| `player_sprite.dart:269` `party.setFace` | `PartyMovementController.step` |
| `player_sprite.dart:278-297` 경계 검사 + `isUnitPassable` | `PartyMovementController.step` |
| `player_sprite.dart:176-179` `party.move` | `PartyMovementController.step` (**유일한 호출자**) |
| `player_sprite.dart:181-186` `passTime` 분기 | `PartyMovementController.step` |
| `player_sprite.dart:193` step-on 디스패치 | `PartyMovementController.step` — **`await` 로 변경**(BP-34 CH-1) |
| `player_sprite.dart:355-371` bump 상호작용 + `_lastInteractedX/Y` 중복 가드 | `PartyMovementController` (`_lastInteracted*` 도 함께 이관) |
| `player_sprite.dart:381-406` `_interactWithFacingTile` | `PartyMovementController.interactFacing` |
| `player_sprite.dart:409-423` `forceMove` | `PartyMovementController.scriptMove` |

**`presentation/` 에 남길 것**: 픽셀 스냅(`:108-113`) · 카메라 추종(`:117-118`) · 확인키/가상버튼 폴링과
에지 검출(`:121-142`) · 픽셀 보간(`:167-173`, `:210-219`) · 조이스틱 → `(dx,dy)`(`:233-265`) ·
애니메이션(`:271-275`, `:319-352`). 424줄 → 약 150줄.

**게이트 소유권 분할** (BP-34 R-34-3): `HDGameMain().currentInputMode`(`:121`, `:224`)는 창 스택·메뉴·키
대기의 합성이고 뒤 둘은 `presentation/` 상태이므로 `application/` 이 읽으면 계층 위반이다.
→ **모드 게이트는 입력 소스**(맵 모드가 아니면 의도를 보내지 않는다), **규칙 게이트는 컨트롤러**
(`_busy` + `HDTileEventDispatcher().isScriptRunning` — `tile_event_dispatcher.dart:34-35` 에 이미 노출).

**`PartyMovementHost` 포트 재정의** (`lib/application/ports/movement_host.dart`, 현재 11줄)
- `animatePartyMove(dx, dy)` — 계약 변경: **표현만**. 도메인 좌표를 만지지 않는다.
- `showFacing(int faced)` / `snapTo(int x, int y)` — 신규(방향 전환 · 워프·로드 후 동기화).
- `flutter_ui_host.dart:293` 의 `party.move` **폴백 제거**. 남기면 좌표가 두 칸 움직인다.

**배선 변경**: cm2 `Party::Move` → `scripting/script_engine_adapter.dart` 의 `animatePartyMove` 호출을
`PartyMovementController().scriptMove` 로. 확인키는 폴링 → `HDInputDispatcher` 이벤트로.

## 착수 조건

GATE-1 통과. 코드상 선행은 없지만 **P0-16**(`exit(0)` 제거)·**P0-18**(bump 게이트 비대칭)과 인접하다.

**왜 그 전에는 안 되는가**: 게임의 심장을 옮기는 작업이다 — `party.move` 의 호출자, 통행 판정,
시간 경과, 3개 디스패치 진입점이 한 커밋에서 위치를 바꾼다. 되돌리기 비용이 P2 중 가장 크고 회귀는
"걷다 보면 가끔 이상하다" 형태로 나와 테스트로 잡기 어렵다. 이 위험을 감수할 근거는 **하네스가 실제로
필요하다는 판정**뿐이며, GATE-1 전 착수는 소비자가 없는 상태에서 가장 위험한 리팩터링을 먼저 하는 것이다.

## GATE-1 이 보류/취소로 판정되면

- **버려지는 것**: `HeadlessMovementHost` 를 전제한 부분 — 포트에 추가하는 `showFacing`/`snapTo` 중
  헤드리스만 쓰는 경로, 트레이스 이벤트 발행, `SimDriver` 를 위한 `HDMoveResult` 의 상세 필드
  (`targetAction`, `stepEventFired`).
- **그래도 남는 값 — 이쪽이 더 크다**:
  - **이동 판정이 단위 테스트 가능해진다.** 지금은 통행 판정·시간 경과·step-on 디스패치를 검증하려면
    Bonfire 게임 위젯을 띄워야 하므로 사실상 테스트가 없다. `PartyMovementController.step()` 이
    `application/` 에 있으면 `test/application/movement/` 에서 페이크 포트로 호출할 수 있다.
    이 이득은 **AI 와 무관하다.**
  - `party.move` 의 호출자가 **하나로 줄어든다.** 지금은 스프라이트(`:176`)와
    `flutter_ui_host.dart:293` 두 곳이며, 후자는 뷰포트 유무에 따라 조용히 도메인을 바꾸는 잠재 버그다.
- 따라서 취소 판정이 나와도 이 이슈는 **`DROPPED` 가 아니라 P0/P1 로 재분류**하는 것이 맞다.
  단 그때는 규모를 줄인다 — 트레이스·`HDMoveResult` 상세 필드 없이 추출만 한다.

## 완료 판정 기준

**[잠정 — GATE-1 통과 시 확정]**

- [ ] `grep -rn "party\.move(" lib/` 의 결과가 `PartyMovementController` **한 곳**이다
- [ ] `grep -rn "checkTileEvent" lib/presentation/` 이 **빈 결과**다
- [ ] `flutter_ui_host.dart` 의 `animatePartyMove` 가 `party` 를 참조하지 않는다
- [ ] `player_sprite.dart` 가 200줄 이하이고 `HDTileProperties`·`passTime` 을 참조하지 않는다
- [ ] 계층 grep 2종(+`dart:io`)이 여전히 빈 결과다
- [ ] `test/application/movement/party_movement_controller_test.dart` — 페이크 포트로 6종 고정:
      통행 성공 / 벽 차단 / bump 상호작용 / 확인키 상호작용 / 스크립트 이동 / 재진입 거부
- [ ] step-on 이 `await` 로 바뀐 뒤에도 연속 이동 입력이 데드락하지 않는다(회귀, BP-34 CH-1)
- [ ] 사람이 플레이해 이동·대화·간판·입장이 추출 전과 같이 동작함을 확인

## 하지 않을 것

- **bump 게이트(`:359`) 제거** — P0-18 소관. 이 이슈는 게이트를 **위치만 옮기고 판정은 바꾸지 않는다.**
- 트리거 인덱스 선조회 삽입(P1-11) · `exit(0)` 제거(P0-16) · 결정론(P0-11).
- Bonfire/flame 버전 변경, 이동 애니메이션의 시각적 변경.
