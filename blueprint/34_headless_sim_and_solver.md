# 헤드리스 시뮬레이터와 퀘스트 솔버

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-34 · **상태**: 초안 · **선행 문서**: [BP-20](20_target_architecture.md), [BP-23](23_quest_model.md), [BP-24](24_dialogue_model.md), [BP-25](25_world_state_and_save.md), [BP-26](26_entity_registry_and_anchors.md), [BP-27](27_runtime_engine.md)
> **독자**: 툴체인 구현자 · 런타임 구현자 · **한 줄 요약**: "AI 가 만든 퀘스트가 실제로 클리어 가능한가" 를
> 사람이 플레이하지 않고 증명하는 장치 — 화면 없이 게임을 구동하는 하네스, 입력 정책 3종, 상태 공간 솔버,
> 퍼징, 골든 트레이스 회귀. 그리고 **그 전부의 선결 과제인 이동·상호작용 코드 추출**.

**파이프라인 구획(D-01)**: 이 장은 **Build 구획의 검증 도구**다. LLM 을 부르지 않고, 네트워크를 쓰지 않으며,
난수는 전부 시드 기반이다. 다만 시뮬레이터는 **Runtime 구획의 코드를 그대로 재사용**한다 —
검증기와 런타임이 다른 시맨틱을 갖는 순간 이 장의 모든 증명이 무의미해지기 때문이다(D-12 의 "평가기를 그대로 import").

**이 장이 다루지 않는 것**:

| 주제 | 소관 |
|---|---|
| Quest / Dialogue / Anchor / Item 의 **데이터 스키마** | [BP-21](21_content_pack_spec.md), [BP-23](23_quest_model.md), [BP-24](24_dialogue_model.md), [BP-26](26_entity_registry_and_anchors.md) |
| `Condition` / `Effect` 의 op·do 목록 | **D-05 가 닫힌 집합으로 확정**. 여기서는 인용만 |
| `WorldState` 필드·직렬화·세이브 포맷 | [BP-25](25_world_state_and_save.md) |
| 런타임 클래스 공개 API·부팅 시퀀스·티어 0 삽입 | [BP-27](27_runtime_engine.md) |
| **정적** 린트 규칙(스키마·참조무결성·도달성·문체) | [BP-33](33_validation_and_lint.md) |
| CI 잡 배치·번들 빌드·결정론 해시 | [BP-35](35_ci_and_build.md) |
| 저널 화면·아이템 UI | [BP-41](41_journal_ui_spec.md), [BP-42](42_item_and_inventory.md) |

---

## 1. 문제 정의 — 스키마가 맞다고 클리어되는 것은 아니다

### 1.1 검증의 5계층 — 이 장은 L5 만 만든다

검증 계층 L1~L4 의 정의와 계층 간 관계는 [BP-33 §2.1](33_validation_and_lint.md) 소유다(D-18).
**이 장은 그중 L5(시뮬레이션)만 만든다.** 계층 정의를 여기서 재서술하지 않는다 —
초판이 L4 를 "앵커/맵 정합" 으로 적었으나 그것은 BP-33 의 `MAP` 주제 묶음이고,
BP-33 의 L4 는 "시맨틱·세계관" 이다. 두 뜻으로 읽히지 않도록 표를 삭제했다.

L1~L4 는 전부 **한 파일 안** 또는 **정적 참조 그래프** 안에서 답이 난다. L5 만이 "상태가 시간에 따라 변한다" 는
사실을 본다. 아래 세 가지 실패는 L1~L4 를 **전부 통과하면서** 게임을 막는다.

### 1.2 정적 검사가 잡지 못하는 실패 3가지

#### F-1 물리적 도달 불가 — 좌표는 유효하지만 갈 수가 없다

```jsonc
// anchors/FX_ROOM.json — L1~L4 전부 통과한다
{ "id": "anchor.fx.scholar", "kind": "actor", "actor": "npc.fx.scholar",
  "x": 3, "y": 1 }        // 맵 범위 안(OK), 타일이 talk(OK), actor id 존재(OK)
```

문제: `(3,1)` 을 둘러싼 네 칸이 전부 `HDTileAction.none`(벽)이라 **마주 설 자리가 없다**.
`HDTileProperties.isUnitPassable`(`hadar2026_app/lib/domain/map/tile_properties.dart:101`)은
`action.isInteractive` 인 타일을 통행 불가로 만들기 때문에, NPC 는 **인접한 통행 가능 칸에서만** 말을 걸 수 있다.
L4 의 "앵커-타일 정합" 검사는 *앵커가 놓인 칸* 만 보므로 이 상황을 통과시킨다.

같은 부류의 변종:

| 변종 | 설명 |
|---|---|
| F-1a | 퀘스트가 두 맵을 오가는데 두 맵을 잇는 `portal` 앵커가 **한 방향만** 있다 |
| F-1b | `portal.when` 이 요구하는 플래그를, 그 포탈 **너머의** NPC 만 세워 준다 |
| F-1c | `change_tile` Effect 로 길이 열리는데, 그 Effect 를 실행하는 앵커가 열린 뒤의 영역 안에 있다 |
| F-1d | `reach` 목표 좌표가 `water` 타일이고 파티에 `walkOnWater` 버프를 주는 경로가 없다 |

#### F-2 상태 순환 잠금 — 조건이 서로를 기다린다

```jsonc
// dialogue/dlg.fx.a.json  (NPC A)
"entry": [ {"when": {"op":"flag","id":"flag.fx.heard_rumor"}, "go": "n_tell"},
           {"when": {"op":"true"}, "go": "n_shrug"} ]
// n_tell 의 onEnter: [{"do":"set_flag","id":"flag.fx.knows_place"}]

// dialogue/dlg.fx.b.json  (NPC B)
"entry": [ {"when": {"op":"flag","id":"flag.fx.knows_place"}, "go": "n_gossip"},
           {"when": {"op":"true"}, "go": "n_busy"} ]
// n_gossip 의 onEnter: [{"do":"set_flag","id":"flag.fx.heard_rumor"}]
```

`flag.fx.heard_rumor` 를 세우려면 B 와 말해야 하고, B 가 말하려면 `flag.fx.knows_place` 가 필요하고,
그건 A 가 세우고, A 는 `heard_rumor` 를 요구한다. **어느 플래그도 최초 생산자가 없다.**

- L2 는 통과한다 — 플래그 id 는 양쪽에 실재한다.
- L3 도 통과한다 — 대화 그래프 자체는 두 개 다 `end` 에 닿는다(`n_shrug`/`n_busy` 경로).
- 잡히지 않는 이유: **"닿는다" 와 "그 상태에서 닿는다" 는 다른 질문**이다.

이 실패는 LLM 생성물에서 가장 흔하다. 집필 에이전트는 각 대화를 **따로** 쓰고, 각각은 완결적이다.

#### F-3 일회성 자원 소진 — 한 번 쓰면 되돌릴 수 없다

```jsonc
// anchors: container 앵커. BP-26 §2.3 에 따라 once 기본값 true
{ "id":"anchor.fx.chest", "kind":"container", "x":0,"y":4,
  "contents":[{"item":"item.fx.old_note","count":1}], "once": true }

// quest.fx.q1 stage s2: {"kind":"deliver","params":{"item":"item.fx.old_note","actor":"npc.fx.client"}}
// quest.fx.q2 stage s1: {"kind":"acquire","params":{"item":"item.fx.old_note"}}
```

상자는 하나, 메모도 하나. q1 을 먼저 완료하면 메모는 `take_item` 으로 사라지고 q2 는 **영구히** 막힌다.
[BP-23 §23.4.6](23_quest_model.md) 의 완료 래치는 *이미 충족된* 목표를 되감지 않을 뿐, *아직 시작 안 한* 퀘스트를 구해주지 않는다.

- L2 통과: `item.fx.old_note` 는 존재한다.
- L3 통과: 두 퀘스트 다 그래프상 완주 가능하다.
- 잡히지 않는 이유: **자원 회계는 전역·시간축 문제**다. 파일 단위 검사로는 원리적으로 안 보인다.

#### F-4 미발행 이벤트 의존 — 모델은 맞는데 **엔진이 그 신호를 내지 않는다** (D-26)

위 F-3 예시를 다시 보라. `acquire` / `deliver` 목표는 `item_gained` / `item_lost` 이벤트로만 진행한다
([BP-23 §23.11.2](23_quest_model.md) 의 매핑표). 그런데 D-20 말미가 못 박은 대로,
그 두 이벤트는 **인벤토리 시스템 부재로 현행 빌드에 발행 지점이 없다**([BP-42](42_item_and_inventory.md)가 만들 때까지).

- L1~L4 전부 통과한다 — 데이터는 완벽하다.
- **§5 의 모델 증명도 통과한다** — 콘텐츠 그래프상 완주 경로가 실재하기 때문이다.
- 그런데 **실제 게임에서는 목표가 영원히 0% 다.** 아무도 카운터를 올려주지 않는다.

초판 BP-34 의 솔버는 이 퀘스트에 `PROVEN` 을 냈다. **"돌아가지 않는 콘텐츠" 를 통과시킨 것이다.**
BP-91(엔드투엔드 예제)이 이 사례를 드러냈고, **D-26** 이 판정을 2축으로 나누어 중재했다.
그 두 번째 축("실행 가능")의 정의와 판정은 **이 장의 소유**이며 §5.10 이 확정한다.

### 1.3 네 실패의 공통 성질

| 실패 | 성질 | 이걸 잡는 유일한 방법 | 이 장의 담당 절 |
|---|---|---|---|
| F-1 | 콘텐츠 × **맵 지형**의 상호작용 | 통행 그래프 위에서 실제로 걸어보기 | §4.3.1 · §5.2 A-7 |
| F-2 | 콘텐츠 × **상태 순서**의 상호작용 | 상태 공간을 앞으로 탐색해 보기 | §5.4 · §5.8 |
| F-3 | 콘텐츠 × **자원 총량**의 상호작용 | 소비 경로를 포함한 전수 탐색 | §5.2 A-4 · §5.4 |
| **F-4** | 콘텐츠 × **현행 엔진의 능력**의 상호작용 | **경로가 소비하는 이벤트를 발행 지점 레지스트리와 대조** | **§5.10** |

넷 다 "파일 하나를 보고" 는 답이 안 나온다. **다른 파일과 다른 시각의 조합**이 문제다.
F-1~F-3 은 *콘텐츠끼리*의 조합이고, F-4 는 *콘텐츠와 코드*의 조합이다.
그래서 이 장의 도구는 *검사기*가 아니라 *실행기*여야 하며, 실행기조차 **현행 빌드가 무엇을 발행하는지**를 알아야 한다.

- **R-34-1** 콘텐츠 팩의 hard gate 에는 L5(실행 가능성)가 포함된다. L1~L4 통과는 필요조건일 뿐이다.
- **R-34-2** 시뮬레이터·솔버는 런타임과 **같은 `Condition`/`Effect` 평가기**를 쓴다(D-12). 재구현 금지.
- **R-34-20 (D-26)** 솔버 판정은 **2축**이다 — *모델 증명*(`PROVEN`/`REFUTED`/`UNKNOWN`)과
  *실행 가능*(`SUPPORTED`/`UNSUPPORTED`). 두 축을 하나로 접지 않는다. §5.1·§5.6·§5.10.

---

## 2. 선결 과제 — 현재 코드로는 헤드리스 구동이 **불가능하다**

이 절이 이 장에서 가장 중요하다. D-13 은 "이미 존재하는 이음매를 쓴다" 고 했지만,
그 이음매는 **절반만** 있다. 부록 B-3·B-4 가 나머지 절반이 없다는 증거다.

### 2.1 세 개의 장벽

| ID | 장벽 | 실측 근거 | 결과 |
|---|---|---|---|
| **BL-1** | 이동 판정과 타일 상호작용 트리거가 `presentation/` 의 **Bonfire 스프라이트 `update(dt)` 폴링 안**에 있다 | `lib/presentation/panels/player_sprite.dart:103`(`update`), `:193`·`:362`·`:405`(`checkTileEvent` 호출), `:286-296`(통행 판정), `:176-186`(`party.move` + `passTime`) | 포트를 페이크로 바꿔도 **파티가 한 칸도 못 움직인다**. 프레임 루프가 없으면 아무 일도 안 일어난다 |
| **BL-2** | `application/menu_flows.dart` 가 `dart:io` 를 쓰고 `exit(0)` 를 호출한다 | `menu_flows.dart:2`(import), `:504`·`:522`·`:540`(`exit(0)`) | 게임 오버·종료 확인 흐름이 **시뮬레이터 프로세스를 통째로 죽인다**. 배치 검증 중 한 시나리오가 프로세스를 내리면 나머지 결과가 사라진다 |
| **BL-3** | 전투·독 데미지가 시드 없는 `Random()` / 벽시계를 쓴다 | `battle.dart` 14곳, `menu_flows.dart:104`, `domain/party/player.dart:71` | 같은 입력을 두 번 돌려도 **같은 트레이스가 안 나온다** → 골든 회귀(§7)와 반례 재생(§5.8)이 성립하지 않는다 |

BL-3 의 대응은 이미 [BP-27 §9](27_runtime_engine.md)(DT-1 ~ DT-7, `WorldRng`)가 확정했다.
이 장은 **BL-1 과 BL-2** 의 설계를 확정한다.

### 2.2 P-1 — 이동·상호작용 루프를 `application/` 으로 추출

#### 2.2.1 현행 책임 목록 (`player_sprite.dart` 424줄 전수 분류)

| # | 줄 | 하는 일 | 성격 | 처분 |
|---|---|---|---|---|
| R-01 | `:108-113` | 스프라이트 픽셀 위치를 `party` 좌표에 스냅 | 표현 | **남김** |
| R-02 | `:117-118` | 카메라 추종 | 표현 | **남김** |
| R-03 | `:121-127` | Enter/E/가상버튼 눌림 폴링 | 장치 입력 | **남김**(단 소비처 변경) |
| R-04 | `:129-142` | 모드 전환 직후 확인키 래치(`justEnteredMapMode`) | 입력 규칙 | **남김**(장치 에지 검출) |
| R-05 | `:144-152` | 확인키 에지 → `_interactWithFacingTile()` | 디스패치 | **이관** |
| R-06 | `:154-161` | "이동 중이면 보간, 아니면 입력 검사" 분기 | 표현/규칙 혼재 | **분할** |
| R-07 | `:167-173`, `:210-219` | 픽셀 보간·축 스냅·누산기 | 표현 | **남김** |
| R-08 | `:176-179` | 도착 시 `party.move(dx,dy)` | **도메인** | **이관** |
| R-09 | `:181-186` | `mapType` 별 `passTime`(GROUND 2분 / 그 외 5초) | **도메인 규칙** | **이관** |
| R-10 | `:193` | `checkTileEvent(step-on)` — fire-and-forget | **애플리케이션** | **이관** |
| R-11 | `:201-204` | 스크립트 이동 완료 신호(`_scriptMoveCompleter`) | 계약 | **이관** |
| R-12 | `:223-228` | 이동 허용 게이트(`mode != map \|\| isScriptRunning`) | 혼재 | **분할**(§2.2.4) |
| R-13 | `:233-265` | 조이스틱/가상패드 → `(dx,dy)` | 장치 입력 | **남김** |
| R-14 | `:269` | `party.setFace(dx,dy)` | **도메인** | **이관** |
| R-15 | `:271-275`, `:319-334`, `:337-352` | `lastDirection` + run/idle 애니메이션 재생 | 표현 | **남김** |
| R-16 | `:278-297` | 맵 경계 검사 + `isUnitPassable(walkOnWater)` | **도메인 규칙** | **이관** |
| R-17 | `:299-310` | `MOVE: (x,y) id(n) [tag]` 디버그 print | 개발 편의 | **이관**(트레이스로) |
| R-18 | `:355-371` | 막힌 상호작용 타일 → `checkTileEvent(interaction)` + `_lastInteracted` 중복 가드 | **애플리케이션** | **이관** |
| R-19 | `:381-406` | 바라보는 타일 좌표 계산 → 상호작용 | **애플리케이션** | **이관** |
| R-20 | `:409-423` | `forceMove` — cm2 `Party::Move` 의 대상 | 계약 | **이관** |

**이관 12건**(R-05·R-08·R-09·R-10·R-11·R-12(일부)·R-14·R-16·R-17·R-18·R-19·R-20),
**잔류 8건**(R-01·R-02·R-03·R-04·R-06(일부)·R-07·R-13·R-15).
추출 후 `player_sprite.dart` 는 **424줄 → 약 150줄**이 된다(순수 렌더·보간·장치 입력).

#### 2.2.2 신규 클래스 `PartyMovementController`

```dart
// hadar2026_app/lib/application/movement/party_movement_controller.dart
//   허용 import: domain/*, application/*, application/ports/*
//   금지: flutter/material, bonfire, flame, dart:io, presentation/*, hd_game_main.dart

/// 방향 의도. 장치(키보드/가상패드/스크립트/시뮬레이터 정책)와 무관한 표현.
enum HDMoveIntent { none, up, down, left, right;
  int get dx => switch (this) { left => -1, right => 1, _ => 0 };
  int get dy => switch (this) { up => -1, down => 1, _ => 0 };
}

enum HDMoveOutcome {
  /// 한 칸 이동 완료. party 좌표가 바뀌었다.
  moved,
  /// 통행 불가 타일. 방향만 바뀌었다.
  blocked,
  /// 통행 불가 + isInteractive → 상호작용을 발화했다.
  interacted,
  /// 게이트가 닫혀 있어 아무것도 하지 않았다(스크립트 실행 중 등).
  refused,
  /// 맵이 없다 / 좌표가 맵 밖이다.
  invalid,
}

class HDMoveResult {
  final HDMoveOutcome outcome;
  final int dx, dy;
  final int fromX, fromY, toX, toY;
  final HDTileAction targetAction;   // 목적 칸의 액션 (트레이스가 그대로 기록)
  final int facedAfter;              // HDParty.faced 규약: 0 down/1 up/2 right/3 left
  final bool stepEventFired;         // step-on 디스패치가 실제로 돌았는가
  const HDMoveResult(...);
}

/// 파티 이동과 타일 상호작용의 **유일한 소유자**.
///
/// 이전에는 `HDPlayerSprite.update(dt)` 폴링 안에 흩어져 있었다
/// (`player_sprite.dart:103` 이하). 프레임 루프에 묶여 있는 한 헤드리스
/// 구동이 불가능하므로(BP-34 §2.1 BL-1) 규칙만 여기로 옮겼다.
/// 표현(보간·애니메이션·카메라)은 스프라이트에 그대로 남는다.
class PartyMovementController {
  static final PartyMovementController _instance = PartyMovementController._();
  factory PartyMovementController() => _instance;
  PartyMovementController._();

  HDParty get _party => HDGameSession().party;
  MapModel? get _map => HDGameSession().map;
  PartyMovementHost get _movement => HDHosts().movement;
  UiHost get _ui => HDHosts().ui;

  bool _busy = false;
  bool get isBusy => _busy;

  int? _lastInteractedX, _lastInteractedY;   // R-18 의 중복 가드

  /// 한 칸 이동을 시도한다. 호출자는 **프레임과 무관**하다.
  ///
  /// 사전조건: HDHosts().bind() 완료, 맵 로드됨.
  /// 사후조건(성공 시): party 좌표·faced 갱신 → passTime → step-on 디스패치 완료.
  /// 예외: GameReloadException 만 전파(세이브 로드가 루프를 되감는 신호).
  Future<HDMoveResult> step(HDMoveIntent intent, {bool fromScript = false});

  /// 바라보는 칸을 확인(Enter/E). 이동하지 않는다.
  Future<HDMoveResult> interactFacing();

  /// cm2 `Party::Move` 진입점. 기존 `HDPlayerSprite.forceMove` 대체.
  /// 통행 불가여도 **완료로 반환**한다(현행 `:374-377` 의 동작 보존).
  Future<HDMoveResult> scriptMove(int dx, int dy);

  /// 방향키를 뗐을 때 presentation 이 호출. 같은 타일 재상호작용을 재무장한다
  /// (현행 `:246-247` 의 `_lastInteracted = null`).
  void releaseInteractionLatch();

  void reset();   // 테스트 tearDown
}
```

`step()` 의 확정 실행 순서 — 현행 코드의 순서를 **바꾸지 않고** 위치만 옮긴다:

```pseudo
Future<HDMoveResult> step(intent, {fromScript = false}):
    if _busy: return refused                                  # 재진입 금지(현행 _isProcessingMove 대응)
    if not fromScript and HDTileEventDispatcher().isScriptRunning: return refused   # R-12 의 규칙 절반
    map = HDGameSession().map; if map == null: return invalid
    _busy = true
    try:
        (dx, dy) = (intent.dx, intent.dy)
        _party.setFace(dx, dy)                                # R-14
        _movement.showFacing(_party.faced)                     # 표현 위임(신규 포트 메서드)
        (nx, ny) = (_party.x + dx, _party.y + dy)
        if out_of_bounds(map, nx, ny): passable = false        # R-16
        else: passable = HDTileProperties.isUnitPassable(
                             map.getUnit(nx, ny), walkOnWater: _party.walkOnWater)
        action = HDTileProperties.getUnitAction(map.getUnit(nx, ny))
        trace.emit(MoveAttempt(nx, ny, action))                # R-17 (print → 트레이스)

        if passable:
            _lastInteractedX = _lastInteractedY = null
            _party.isMoving = true
            await _movement.animatePartyMove(dx, dy)           # 표현만. 좌표를 만지지 않는다
            _party.move(dx, dy)                                # R-08 — 도메인 좌표 확정
            _party.isMoving = false
            passTimeForMapType()                               # R-09
            await HDTileEventDispatcher().check(               # R-10 — await 한다(더 이상 fire-and-forget 아님)
                map: map, party: _party, host: _ui,
                x: _party.x, y: _party.y, isInteraction: false)
            return moved(...)

        # 통행 불가
        if action.isInteractive and (_lastInteractedX != nx or _lastInteractedY != ny):
            _lastInteractedX = nx; _lastInteractedY = ny       # R-18
            await HDTileEventDispatcher().check(
                map: map, party: _party, host: _ui,
                x: nx, y: ny, isInteraction: true)
            return interacted(...)
        return blocked(...)
    finally:
        _busy = false
```

**동작이 바뀌는 지점 1개(의도된 변경)**:

| ID | 변경 | 이유 |
|---|---|---|
| CH-1 | step-on 디스패치가 fire-and-forget(`:193`) → `await` | 폴링 루프가 없어졌으므로 데드락 위험이 사라진다. 헤드리스가 "이벤트가 끝난 뒤" 를 관측할 수 있어야 트레이스가 성립한다 |

CH-1 은 실제 게임 동작에 영향이 있을 수 있으므로 T-34-4(회귀 테스트)로 고정한다.

**동작이 바뀌지 않지만 확인해야 할 지점 1개**: `party.move` 는 추출 전후 모두 **애니메이션 완료 후**에 불린다.
순서는 동일하고 **호출자만** 스프라이트(`player_sprite.dart:176`)에서 컨트롤러로 옮겨간다.
`HDFlutterUiHost.animatePartyMove` 의 뷰포트 없음 폴백(`flutter_ui_host.dart:293`)이
`party.move` 를 **한 번 더** 부르고 있으므로, 그 폴백을 제거하지 않으면 좌표가 두 칸 움직인다(§2.2.3 표).

#### 2.2.3 `PartyMovementHost` 포트의 역할 재정의

현재 `PartyMovementHost.animatePartyMove` 는 **좌표의 소유자**다 —
`HDFlutterUiHost.animatePartyMove`(`flutter_ui_host.dart:283-293`)가 `player.forceMove` 를 부르고,
그 안에서 `party.move` 가 일어난다. 뷰포트가 없으면 `HDGameSession().party.move(dx,dy)` 로 직접 폴백까지 한다.
**즉 포트가 도메인을 바꾼다.** 이것이 헤드리스 하네스에서 "이동은 되는데 타일 이벤트는 안 나는" 반쪽 상태의 원인이다.

재정의:

```dart
// hadar2026_app/lib/application/ports/movement_host.dart (변경 후)
/// 파티 이동의 **표현**만 담당한다. 도메인 좌표는 만지지 않는다.
///
/// 좌표의 소유자는 [PartyMovementController] 다. 이 포트는
/// "그렇게 움직인 것처럼 보이게 해 달라" 는 요청만 받는다.
abstract class PartyMovementHost {
  /// (dx,dy) 만큼의 타일 이동을 그린다. 애니메이션이 끝나면 완료한다.
  /// 헤드리스 호스트는 즉시 완료해도 된다.
  Future<void> animatePartyMove(int dx, int dy);

  /// 이동 없이 방향만 바뀐 경우의 표현 갱신. (신규)
  void showFacing(int faced);

  /// 워프 / 세이브 로드 후 표현을 도메인 좌표로 강제 동기화. (신규)
  void snapTo(int x, int y);
}
```

| 항목 | Before | After |
|---|---|---|
| `party.move` 호출자 | `HDPlayerSprite._moveTowardsTarget`(`:176`) 또는 `HDFlutterUiHost`(`:292`) | `PartyMovementController.step` 단 한 곳 |
| 통행 판정 | `HDPlayerSprite._checkInput`(`:286-296`) | `PartyMovementController.step` |
| step-on 디스패치 | `HDPlayerSprite`(`:193`) | `PartyMovementController.step` |
| 상호작용 디스패치 | `HDPlayerSprite`(`:362`, `:405`) | `PartyMovementController.{step,interactFacing}` |
| cm2 `Party::Move` | `script_engine_adapter.dart:432` → `HDHosts().movement.animatePartyMove` | `script_engine_adapter.dart:432` → `PartyMovementController().scriptMove` |
| 헤드리스에서 이동 | **불가능** | `HeadlessMovementHost` 가 즉시 완료 → 규칙은 그대로 실행 |

#### 2.2.4 게이트의 소유권 분할 (R-12)

현행 `_checkInput`(`:224-228`)은 `HDGameMain().currentInputMode != map || isScriptRunning` 로 게이트한다.
`currentInputMode` 는 창 스택 + 활성 메뉴 + 키 대기의 합성이고, 뒤 둘은 `presentation/` 상태다.
`application/` 이 이걸 읽으면 계층 위반이다.

> **확정 규칙 R-34-3**: **모드 게이트는 입력 소스(presentation / SimDriver)가, 규칙 게이트는 컨트롤러가 소유한다.**
> - 입력 소스는 "지금 맵 모드인가" 를 스스로 알고 있으므로, 아닐 때는 **의도를 보내지 않는다**.
> - 컨트롤러는 자신이 알 수 있는 것만 본다: `_busy`, `HDTileEventDispatcher().isScriptRunning`,
>   `ContentRuntime().isInteracting`([BP-27 §2.7](27_runtime_engine.md)).
>
> 헤드리스에서도 같은 판정이 성립한다 — `HeadlessUiHost` 는 자기 메뉴/키대기 상태를 알고 있으므로
> `SimDriver` 가 그것을 읽어 의도 발행 여부를 정한다(§3.5).

#### 2.2.5 before / after 코드 스케치

**Before** — `hadar2026_app/lib/presentation/panels/player_sprite.dart` (현행, 축약 인용)

```dart
@override
void update(double dt) {
  super.update(dt);
  if (!_isMoving) { /* :108-113 party 좌표로 스냅 */ }
  gameRef.camera.position = position + Vector2(16, 16);          // :118

  final mode = HDGameMain().currentInputMode;                    // :121  ← 앱 상태를 스프라이트가 읽는다
  bool isActionKeyPressed = HardwareKeyboard.instance
      .isLogicalKeyPressed(LogicalKeyboardKey.enter) || ...       // :122-127
  if (mode == HDInputMode.map && isActionKeyPressed) {
    if (!_actionPressed) { _actionPressed = true; _interactWithFacingTile(); }  // :144-148
  }
  if (_isMoving && _targetPosition != null) {
    if (!_isProcessingMove) { _isProcessingMove = true;
      _moveTowardsTarget(dt).then((_) => _isProcessingMove = false); }          // :154-158
  } else { _checkInput(); }                                                     // :160
}

Future<void> _moveTowardsTarget(double dt) async {
  // … 픽셀 누산·보간 …
  party.move((position.x / tileSize).round() - party.x, …);                     // :176-179  도메인
  HDGameMain().gameSystem.passTime(0, 2, 0, onTimeGoes: party.timeGoes);        // :181-186  도메인
  HDGameMain().checkTileEvent(party.x, party.y, isInteraction: false);          // :193      앱 (await 안 함)
  // …
}

Future<void> _checkInput() async {
  if ((mode != HDInputMode.map || HDGameMain().isScriptRunning) && …) return;   // :225-228
  // … 조이스틱 → dx,dy … party.setFace(dx, dy);                                 // :269
  if (!HDTileProperties.isUnitPassable(map.getUnit(nextX, nextY),
                                       walkOnWater: HDGameMain().party.walkOnWater))
    isPassable = false;                                                          // :290-295
  if (isPassable) { _isMoving = true; _targetPosition = …; }                     // :312-317
  else if (action.isInteractive && (_lastInteractedX != nextX || …)) {
    await HDGameMain().checkTileEvent(nextX, nextY, isInteraction: true);        // :362-366
  }
}
```

**After** — 같은 파일, 규칙이 전부 빠진 모습

```dart
import '../../application/movement/party_movement_controller.dart';

class HDPlayerSprite extends SimplePlayer with BlockMovementCollision {
  final HDParty party;
  final _controller = PartyMovementController();

  _Tween? _tween;                       // 픽셀 보간 상태 (R-07)

  @override
  void update(double dt) {
    super.update(dt);
    gameRef.camera.stop();
    gameRef.camera.position = position + Vector2(16, 16);        // R-02

    if (_tween != null) { _advanceTween(dt); return; }           // R-07: 보간만
    _syncPixelsToDomain();                                       // R-01: 워프/로드 후 스냅

    // R-03/R-13: 장치 → 의도. 규칙 판정은 하지 않는다.
    final intent = _pollMoveIntent();
    if (intent == HDMoveIntent.none) {
      _controller.releaseInteractionLatch();
      return;
    }
    if (_controller.isBusy) return;
    // 모드 게이트(R-34-3): 맵 모드가 아니면 애초에 보내지 않는다.
    if (HDGameMain().currentInputMode != HDInputMode.map) return;
    _controller.step(intent);            // await 하지 않는다 — 프레임을 붙잡지 않기 위해
  }

  /// PartyMovementHost 가 위임한 표현 요청. 좌표는 이미 컨트롤러가 정했다.
  Future<void> tweenBy(int dx, int dy) {
    _playRunAnimation(dx, dy);
    _tween = _Tween(from: position.clone(),
                    to: position + Vector2(dx * tileSize, dy * tileSize));
    return _tween!.done;
  }

  void showFacing(int faced) { lastDirection = _dirOf(faced); _playIdleAnimation(); }
  void snapTo(int x, int y) { _tween = null; position = Vector2(x * tileSize, y * tileSize); }
}
```

```dart
// hadar2026_app/lib/presentation/host/flutter_ui_host.dart (변경 후)
@override
Future<void> animatePartyMove(int dx, int dy) async {
  final player = _bonfireGame?.player;
  if (player is HDPlayerSprite) return player.tweenBy(dx, dy);   // party 를 만지지 않는다
  // 뷰포트 미부착(부팅 전/테스트) — 그릴 것이 없으므로 즉시 완료.
}

@override
void showFacing(int faced) {
  final player = _bonfireGame?.player;
  if (player is HDPlayerSprite) player.showFacing(faced);
}

@override
void snapTo(int x, int y) {
  final player = _bonfireGame?.player;
  if (player is HDPlayerSprite) player.snapTo(x, y);
}
```

```dart
// hadar2026_app/lib/presentation/input/input_dispatcher.dart (변경 후, _handleMap 말미)
// 이전: "Action (Enter/E) is handled by HDPlayerSprite for now" 라며 false 를 반환했다(:149-151).
if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.keyE) {
  PartyMovementController().interactFacing();      // 폴링 제거 → 이벤트 구동
  return true;
}
return false;
```

> **부수 효과(좋은 쪽)**: 확인키가 폴링에서 이벤트로 바뀌면서 `_actionPressed` / `justEnteredMapMode` 래치
> (`:129-152`)의 존재 이유가 절반 사라진다. 가상 버튼(터치)만 에지 검출이 필요하므로
> `HDVirtualInputState` 쪽에 1개만 남긴다.

#### 2.2.6 위험과 완화

| ID | 위험 | 완화 |
|---|---|---|
| RK-34-1 | `await` 로 바뀐 step-on 디스패치(CH-1)가 이동 응답성을 떨어뜨린다 | `step()` 을 `update` 에서 `await` 하지 않는다(위 스케치). 디스패치가 도는 동안 `_busy` 로 다음 입력만 막힌다 — 현행 `_isProcessingMove` 와 같은 체감 |
| RK-34-2 | 애니메이션 완료 대기(`animatePartyMove`)가 스프라이트 tween 과 어긋나 파티가 순간이동한다 | `tweenBy` 가 반환하는 `Future` 를 `_Tween.done` 으로 완료시키고, `_syncPixelsToDomain` 은 tween 중에는 돌지 않게 한다 |
| RK-34-3 | cm2 `Party::Move` 의 "막혀도 완료" 동작(`:374-377`)이 깨진다 | `scriptMove` 가 `blocked` 도 정상 완료로 반환. T-34-5 로 고정 |
| RK-34-4 | 추출 중 회귀를 눈치채지 못한다 | 추출 **전에** 골든 트레이스를 뜰 수 없다(하네스가 없으므로). 대신 위젯 없는 통합 테스트 6종(T-34-4)을 먼저 작성하고, 추출 후 같은 테스트가 통과하는지로 판정 |

### 2.3 P-2 — `exit(0)` 제거

| 위치 | 문맥 | 현행 |
|---|---|---|
| `menu_flows.dart:504` | `processGameOver(0)` — 사용자가 "예" 를 고름 | `if (!kIsWeb) exit(0); else 안내 로그` |
| `menu_flows.dart:522` | `processGameOver(1)` — 필드 전멸, 로드 거부 후 | `if (!kIsWeb) exit(0);` |
| `menu_flows.dart:540` | `processGameOver(2)` — 전투 전멸, 로드 거부 후 | `if (!kIsWeb) exit(0);` |

**설계**: `UiHost` 에 종료 요청을 추가하고, `dart:io` 를 `presentation/` 으로 밀어낸다.

```dart
// hadar2026_app/lib/application/ports/ui_host.dart (추가)
enum HDQuitReason {
  /// 메인 메뉴에서 사용자가 종료를 선택 (EXITCODE_BY_USER)
  byUser,
  /// 필드에서 파티 전멸 + 로드 거부 (EXITCODE_BY_ACCIDENT)
  byAccident,
  /// 전투에서 파티 전멸 + 로드 거부 (EXITCODE_BY_ENEMY)
  byEnemy,
}

abstract class UiHost {
  // … 기존 11개 …

  /// 셸에 종료를 **요청**한다. 종료 방법은 호스트가 정한다.
  ///
  /// 사후조건: 이 Future 가 완료되면 호출자는 더 이상 게임 루프를 진행하지
  /// 않는다. 호스트가 실제로 프로세스를 내릴 수도 있고(데스크톱),
  /// 안내만 하고 돌아올 수도 있고(웹), 제어 예외를 던질 수도 있다(헤드리스).
  Future<void> requestQuit(HDQuitReason reason);
}
```

```dart
// application/menu_flows.dart (변경 후) — import 'dart:io' 삭제, kIsWeb 분기 삭제
if (res == 2) {
  await _game.requestQuit(HDQuitReason.byUser);
}
```

호스트별 구현:

| 호스트 | 구현 |
|---|---|
| `HDFlutterUiHost` | `if (kIsWeb) { addLog('게임을 종료합니다. 브라우저 창을 닫아주세요.'); await waitForAnyKey(); } else { SystemNavigator.pop(); }` — `dart:io`/`services` 는 presentation 에서 합법 |
| `HeadlessUiHost` | `throw SimQuitSignal(reason)` — `GameReloadException` 과 같은 **제어 흐름 예외**. `SimDriver` 가 잡아 트레이스에 `quit` 이벤트를 남기고 시나리오를 정상 종료 |
| 향후 CLI/MUD 호스트 | 자기 셸의 종료 규약대로 |

부수 효과:

- `application/` 에서 `dart:io` import 가 **0건**이 된다 → [BP-35](35_ci_and_build.md) 가 D-23 의 CI 계층 grep
  (`dart:io` · `dart:html`)을 **같은 변경으로 함께** 넣을 수 있다. D-23 이 명시하듯 순서를 나누면 CI 가 즉시 빨개진다.
- `kIsWeb` 분기가 `application/` 에서 사라진다 — 플랫폼 지식이 presentation 으로 모인다.
- **웹 런타임 미확인 동작(부록 B-4-4)의 해소**: 빌드는 통과하지만 웹에서 `exit(0)` 가 실제로 어떻게 동작하는지는
  확인된 바 없다. `requestQuit` 로 감싸면 웹 경로가 `SystemNavigator.pop()`/안내 로그로 **명시**되므로
  미확인 영역 자체가 사라진다.

> ⚠️ **폐기된 근거 — 쓰지 말 것**: 초판 BP-34 는 "`dart:io` 때문에 `flutter build web` 이 깨질 수 있다" 를
> 근거의 하나로 들었다. **부록 B-4 의 정정으로 반증되었다** — `flutter build web --release` 실빌드가
> 성공했다(Flutter 3.41.4, exit 0, `build/web` 생성). 이 절의 주장은 그 근거 없이도 성립한다:
> **P-2 의 유효 근거는 (1) 계층 위반, (2) `exit(0)` 이 시뮬레이터 프로세스를 죽여 헤드리스를 파괴한다,
> (3) 웹 런타임 동작 미확인(B-4-4)** 세 가지다. 그중 (2)가 이 장의 직접 근거다.

### 2.4 P-3 — 결정론 (BP-27 §9 의 최소 집합)

이 장이 **반드시** 요구하는 것만 추린다. 나머지는 [BP-27 §9.3](27_runtime_engine.md) 의 DT 표를 따른다.

| 이 장의 기능 | 필요한 DT | 없으면 |
|---|---|---|
| 골든 트레이스 비교(§7) | DT-1(독 데미지), DT-2(전투 난수), DT-4(정렬 직렬화) | 같은 입력이 다른 트레이스를 낸다 → 게이트가 매번 빨갛다 |
| 반례 재생(§5.8) | DT-1, DT-2, DT-3 | 솔버가 낸 해를 시뮬레이터로 재현할 수 없다 → 교차 검증(§3.1) 붕괴 |
| 퍼징 시드 코퍼스(§6) | DT-1 ~ DT-4 | 실패 시드를 다시 돌려도 같은 실패가 안 난다 |
| 상태 해시(§5.2) | DT-4 | 같은 상태가 다른 해시를 갖는다 → 방문 집합이 무의미 |

- **R-34-4** BL-3(결정론) 해소는 §7 골든 회귀의 **전제**다. 해소 전에는 골든을 "이벤트 종류·순서" 까지만 비교하고
  수치(HP·데미지)는 정규화에서 제외한다(§7.2 의 `--relax-numeric` 모드).

### 2.5 선결 과제 없이 할 수 있는 것 / 없는 것

선결 과제는 크다. 그동안 손을 놓을 이유는 없다. **부분 하네스(Phase 0)** 가 이미 상당한 가치를 낸다.

| 검증 대상 | Phase 0 (선결 없음) | Phase 1 (P-1 완료) | Phase 2 (P-1+P-2+P-3) |
|---|---|---|---|
| 번들 로드 · 인덱스 구축 | ✅ | ✅ | ✅ |
| `Condition` 평가 (op 18종) | ✅ | ✅ | ✅ |
| `Effect` 적용 (do 25종, 즉시분) | ✅ | ✅ | ✅ |
| 대화 그래프 실행 · 선택지 분기 | ✅ | ✅ | ✅ |
| 대화 사이클 · `maxDepth` | ✅ | ✅ | ✅ |
| 퀘스트 스테이지 전이 · 완료 래치 | ✅ | ✅ | ✅ |
| 월드 이벤트 큐 · cascade 상한 | ✅ | ✅ | ✅ |
| 티어 0 디스패치 (좌표를 직접 지정) | ✅ | ✅ | ✅ |
| 세이브 v2 왕복 | ✅ | ✅ | ✅ |
| **F-2 상태 순환 잠금 검출** | ✅ (솔버는 추상 액션만 쓴다 — §5.3) | ✅ | ✅ |
| **F-3 자원 소진 검출** | ✅ | ✅ | ✅ |
| 파티 이동 1칸 | ❌ | ✅ | ✅ |
| `step_tile` / `enter` 자동 발화 | ❌ | ✅ | ✅ |
| **F-1 물리적 도달 불가 검출** | ⚠️ 통행 그래프만으로 정적 근사 가능(§4.3) — 조건부 간선은 못 봄 | ✅ | ✅ |
| `greedy` 정책 | ❌ | ✅ | ✅ |
| `random` 퍼징(랜덤 워크) | ❌ | ✅ | ✅ |
| 게임 오버 / 종료 흐름 | ❌ (프로세스가 죽음) | ❌ | ✅ |
| 전투를 낀 시나리오 | ⚠️ 승패를 주입하면 가능 | ⚠️ | ✅ |
| 골든 트레이스 회귀 | ⚠️ 수치 제외 | ⚠️ | ✅ |
| 반례 재생 (solve → sim) | ❌ | ⚠️ | ✅ |

> **핵심 통찰**: 솔버(§5)는 **추상 액션**("도달 가능한 앵커 하나를 발동한다")으로 동작하므로,
> 이동 시뮬레이션 없이도 F-2·F-3 을 잡는다. 즉 **가장 흔한 두 실패는 Phase 0 에서 이미 잡힌다.**
> P-1 이 추가로 사주는 것은 **F-1(지형과의 상호작용)** 과 **퍼징**이다.
> 이 사실이 로드맵의 순서를 정한다 — 솔버를 먼저 만들고, 이동 추출은 그다음이다.

### 2.6 선결 과제 태스크

| ID | 내용 | 대상 파일 | 규모 | 선행 |
|---|---|---|---|---|
| T-34-1 | `PartyMovementController` 신설 + 12개 책임 이관 | `lib/application/movement/party_movement_controller.dart`(신규 ~220줄) | 중 | — |
| T-34-2 | `player_sprite.dart` 잔류분 재작성(424 → ~150줄) | `lib/presentation/panels/player_sprite.dart` | 중 | T-34-1 |
| T-34-3 | `PartyMovementHost` 에 `showFacing` / `snapTo` 추가, `animatePartyMove` 계약 변경 | `ports/movement_host.dart`, `host/flutter_ui_host.dart`, `hd_game_main.dart` | 소 | T-34-1 |
| T-34-4 | 이동·상호작용 통합 테스트 6종(추출 전 작성) | `test/application/movement/` | 중 | — |
| T-34-5 | cm2 `Party::Move` 를 `scriptMove` 로 배선 | `scripting/script_engine_adapter.dart:432` | 소 | T-34-1 |
| T-34-6 | 확인키를 폴링 → `HDInputDispatcher` 이벤트로 | `presentation/input/input_dispatcher.dart:149` | 소 | T-34-1 |
| T-34-7 | `UiHost.requestQuit` 추가, `exit(0)` 3곳 제거, `dart:io` import 제거 | `ports/ui_host.dart`, `application/menu_flows.dart`, `host/flutter_ui_host.dart` | 소 | — |
| T-34-8 | CI 계층 grep 에 `dart:io`/`dart:html` 추가 | `.github/workflows/ci.yml` | 소 | T-34-7 · [BP-35](35_ci_and_build.md) |

---

## 3. 하네스 구성요소

### 3.1 배치 — 왜 두 조각으로 나뉘는가

D-12 는 `hadar_content` CLI 를 **순수 Dart** 로 쓰라고 한다(`lib/domain/content/` 평가기를 그대로 import 하기 위해).
그런데 `application/` 은 `package:flutter/foundation.dart` 를 쓴다(`ChangeNotifier`). 이 패키지는
`dart run` 으로 실행되는 Dart VM 에서 **import 되지 않는다**. 따라서:

| 조각 | 위치 | 실행 방법 | 쓸 수 있는 것 | 성격 |
|---|---|---|---|---|
| **SimDriver** (통합 시뮬레이터) | `hadar2026_app/test/harness/` + `hadar2026_app/tool/sim_main.dart` | `flutter test` 프로세스 | `domain/` + `application/` **전부** | 느리지만 **진짜**. 런타임과 100% 같은 코드 |
| **QuestSolver** (추상 솔버) | `tools/content_cli/lib/src/solver/` | `dart run` | `domain/content/` 만 | 빠르지만 **추상**. 이동·UI 를 모른다 |

- **R-34-5** `hadar_content sim` 은 내부적으로 `flutter test` 를 **서브프로세스로 실행**하고
  트레이스 JSON 을 파일로 회수한다. CLI 는 얇은 래퍼다.
- **R-34-6** `hadar_content solve` 는 서브프로세스 없이 순수 Dart 로 돈다.
  따라서 `lib/domain/content/` 는 **`flutter/foundation.dart` 조차 import 하지 않아야 한다**(D-12 의 "최소로" 를 "0" 으로 확정).
  `ChangeNotifier` 가 필요하면 `application/` 쪽 래퍼가 갖는다.
- **R-34-7 (교차 검증 — `PROVEN` 전용)** 솔버가 낸 해(추상 액션열)는 **반드시 `SimDriver` 로 재생**해서
  실제로 완주되는지 확인한다. 재생 실패 = 추상화가 현실과 어긋났다는 뜻이며, **솔버의 버그로 취급**한다.
  **적용 범위는 `PROVEN` 뿐이다** — `REFUTED` 에는 재생할 witness 가 없으므로 이 규칙이 원리적으로 작동하지 않는다.
  `REFUTED` 쪽 검증은 **R-34-21**(§5.2.1 안전 방향 원칙) + **R-34-22**(§11.3 거짓 `REFUTED` 검출 절차)가 맡는다.

```
tools/content_cli/
  bin/hadar_content.dart
  lib/src/
    solver/ solver.dart  state_abstraction.dart  action_model.dart  search.dart  witness.dart
    sim/    sim_invoker.dart        # flutter test 서브프로세스 호출 + 트레이스 회수
    trace/  trace_model.dart  normalize.dart  golden.dart
hadar2026_app/
  test/harness/
    headless_ui_host.dart  memory_asset_source.dart  headless_movement_host.dart
    sim_driver.dart  sim_policy.dart  sim_trace.dart  map_graph.dart
  test/harness/harness_self_test.dart      # 하네스 자체의 자기 테스트 (§9)
  tool/sim_main.dart                       # flutter test 진입점 (--dart-define 으로 인자 수신)
```

### 3.2 `HeadlessUiHost implements UiHost`

11개(+`requestQuit` 로 12개) 메서드 전부의 구현 방침:

| 메서드 | 구현 | 트레이스 기록 | 정책 관여 |
|---|---|---|---|
| `showMenu(items, …)` | `policy.chooseMenu(SimMenuRequest(kind: console, …))` 반환값을 그대로 | `menu` 이벤트(제목·항목·선택) | **O** |
| `showWindowMenu(items, …)` | 동일. `kind: window` | `menu` | **O** |
| `showMessageWindow(text, …)` | 즉시 완료. 텍스트를 기록 | `message_window` | ✕ |
| `addLog(msg, isDialogue)` | 버퍼에 적재. 페이지 넘김을 흉내내지 않는다(래핑은 표현) | `log`(lane: dialogue/progress) | ✕ |
| `waitForAnyKey()` | 즉시 완료 + `keyWaitCount++` | `key_wait` | ✕ (정책은 관측만) |
| `clearLogs()` | 이벤트 버퍼 비우고 헤더 초기화(실제 호스트와 동일 규약) | `clear_logs` | ✕ |
| `setHeader(text)` | 필드 저장 | `header` | ✕ |
| `beginNarrative()` | `_narrative = true` (재진입은 no-op — 실제 호스트와 동일) | `narrative_begin` | ✕ |
| `endNarrative({summary, autoFlush})` | `_narrative = false`, `autoFlush` 값을 그대로 기록 | `narrative_end(autoFlush)` | ✕ |
| `refresh()` | `refreshCount++` 만 | ✕(노이즈이므로 집계만) | ✕ |
| `preloadAssets()` | **no-op** | ✕ | ✕ |
| `requestQuit(reason)` | `throw SimQuitSignal(reason)` | `quit(reason)` | ✕ |

```dart
// hadar2026_app/test/harness/headless_ui_host.dart
class SimQuitSignal implements Exception {          // 제어 흐름 예외 (GameReloadException 과 같은 성격)
  SimQuitSignal(this.reason);
  final HDQuitReason reason;
}

class HeadlessUiHost implements UiHost {
  HeadlessUiHost({required this.policy, required this.trace});

  final SimPolicy policy;
  final SimTrace trace;

  // --- 관측 가능한 상태 (SimDriver 의 모드 게이트가 읽는다 — R-34-3) ---
  bool get isMenuOpen => _menuDepth > 0;
  bool get isNarrativeActive => _narrative;
  int keyWaitCount = 0;
  int refreshCount = 0;

  final List<String> dialogueLines = [];   // 현재 페이지
  final List<String> progressLines = [];   // 누적
  String header = '';

  int _menuDepth = 0;
  bool _narrative = false;

  @override
  Future<int> showMenu(List<String> items,
      {int initialChoice = 1, int enabledCount = -1, bool clearLogs = true}) async {
    if (clearLogs) this.clearLogs();
    _menuDepth++;
    final n = enabledCount == -1 ? items.length - 1 : enabledCount;
    final req = SimMenuRequest(
      kind: SimMenuKind.console, title: items.first,
      choices: items.sublist(1), enabledCount: n, initialChoice: initialChoice);
    final choice = policy.chooseMenu(req);
    _menuDepth--;
    assert(choice >= 0 && choice <= n, 'policy returned out-of-range choice');
    trace.emit('menu', {'kind': 'console', 'title': items.first,
                        'choices': items.sublist(1), 'chosen': choice});
    return choice;
  }

  @override
  Future<int> showWindowMenu(List<String> items,
      {int initialChoice = 1, int enabledCount = -1, int? x, int? y}) async { /* 위와 동일, kind: window */ }

  @override
  Future<void> showMessageWindow(String text, {int? x, int? y}) async =>
      trace.emit('message_window', {'text': text});

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    (isDialogue ? dialogueLines : progressLines).add(message);
    trace.emit('log', {'lane': isDialogue ? 'dialogue' : 'progress', 'text': message});
  }

  @override
  Future<void> waitForAnyKey() async { keyWaitCount++; trace.emit('key_wait', const {}); }

  @override
  void clearLogs() { dialogueLines.clear(); header = ''; trace.emit('clear_logs', const {}); }

  @override
  void setHeader(String text) { header = text; trace.emit('header', {'text': text}); }

  @override
  void beginNarrative() {
    if (_narrative) return;                       // 실제 호스트와 같은 멱등 규약
    _narrative = true; trace.emit('narrative_begin', const {});
  }

  @override
  Future<void> endNarrative({String? summary, bool autoFlush = true}) async {
    _narrative = false;
    if (summary != null) progressLines.add(summary);
    trace.emit('narrative_end', {'autoFlush': autoFlush, 'summary': summary});
  }

  @override
  void refresh() => refreshCount++;

  @override
  Future<void> preloadAssets() async {}

  @override
  Future<void> requestQuit(HDQuitReason reason) async {
    trace.emit('quit', {'reason': reason.name});
    throw SimQuitSignal(reason);
  }
}
```

**설계 결정 3가지**:

| ID | 결정 | 이유 |
|---|---|---|
| HU-1 | `addLog` 는 줄바꿈/워드랩을 하지 않는다 | 랩은 `TextPainter` 를 쓰는 **표현**이다(`flutter_ui_host.dart:104-120`). 헤드리스가 흉내내면 폰트에 따라 트레이스가 흔들린다. 길이 검사는 [BP-33](33_validation_and_lint.md)/[BP-24 §24.5](24_dialogue_model.md) 소관 |
| HU-2 | `waitForAnyKey` 는 정책에 묻지 않는다 | "아무 키" 는 선택이 아니다. 다만 카운트를 남겨 §6 의 데드락 탐지가 쓴다 |
| HU-3 | 메뉴 반환값을 `assert` 로 범위 검사한다 | 정책 버그가 조용히 잘못된 분기를 타면 오탐이 된다(cm2 의 "미등록 함수 → 0 반환" 과 같은 실패 모드를 반복하지 않는다) |

### 3.3 `MemoryAssetSource implements AssetSource`

`test/application/map_navigation_test.dart:13-28` 의 `_FakeAssets` 를 **그대로 확장**한다.

```dart
// hadar2026_app/test/harness/memory_asset_source.dart
class MemoryAssetSource implements AssetSource {
  MemoryAssetSource(this.files);

  /// 에셋 경로 → 내용. 키는 번들 규약 그대로(`assets/maps/TOWN1.json`).
  final Map<String, String> files;

  /// 읽기 순서 기록. 로드 경로 회귀(부록 A-1, D-1)를 그대로 고정한다.
  final List<String> reads = [];
  final Set<String> misses = {};

  /// 디스크에서 실물 팩을 올려 채운다. CI 배치 검증이 쓴다.
  static Future<MemoryAssetSource> fromDisk(String root, {List<String> globs = const [
    'assets/maps/**.json', 'assets/content/build/*.json', 'assets/*.cm2',
  ]}) async { … }

  @override
  Future<String> loadString(String path) async {
    reads.add(path);
    final content = files[path];
    if (content == null) { misses.add(path); throw Exception('asset not found: $path'); }
    return content;
  }
}
```

- **R-34-8** `misses` 는 트레이스의 `meta.assetMisses` 로 나간다. 부록 A-1(존재하지 않는 `MapNNN.cm2` 를
  모든 맵에 부여) 같은 문제가 **소리 없이 지나가지 않게** 하는 장치다.
- `fromDisk` 는 파일 나열을 **정렬**해서 읽는다(BP-27 DT-6 와 같은 이유).

### 3.4 `HeadlessMovementHost implements PartyMovementHost`

§2.2.3 의 재정의를 전제로 하면 3줄짜리 클래스가 된다. 그것이 재정의가 옳다는 증거다.

```dart
// hadar2026_app/test/harness/headless_movement_host.dart
class HeadlessMovementHost implements PartyMovementHost {
  HeadlessMovementHost(this.trace);
  final SimTrace trace;

  int facing = 0;
  int animateCalls = 0;

  @override
  Future<void> animatePartyMove(int dx, int dy) async { animateCalls++; }   // 즉시 완료

  @override
  void showFacing(int faced) => facing = faced;

  @override
  void snapTo(int x, int y) => trace.emit('snap_to', {'x': x, 'y': y});
}
```

> **재정의 전이라면** 이 클래스는 `HDGameSession().party.move(dx,dy)` 를 직접 호출해야 하고
> (현행 `flutter_ui_host.dart:292` 의 폴백과 같은 짓), 그러면 통행 판정도 시간 경과도 타일 이벤트도 없이
> 파티가 벽을 통과한다. **이 3줄이 3줄인 것이 P-1 의 수익이다.**

### 3.5 `SimDriver`

```dart
// hadar2026_app/test/harness/sim_driver.dart
class SimConfig {
  final String scenarioId;
  final String startMap;              // MapInfos 의 이름
  final int startX, startY;
  final int seed;                     // WorldState.seed (BP-25 §2.1)
  final int maxSteps;                 // 스텝 예산 (기본 5000)
  final int maxWallSeconds;           // 벽시계 상한 (기본 120) — 트레이스에는 안 들어간다
  final int noProgressLimit;          // 진행 없음 판정 (기본 400)
  final List<String> goalQuestIds;    // 이 퀘스트들이 completed 면 성공 종료
  final bool stopOnQuit;              // SimQuitSignal 을 성공 종료로 볼 것인가
}

enum SimStopReason {
  goalsCompleted,     // 목표 퀘스트 전부 completed        → 성공
  scriptExhausted,    // scripted 정책의 입력 시퀀스 소진   → 성공(입력을 다 썼다)
  quitRequested,      // SimQuitSignal                    → 설정에 따라
  stepBudget,         // maxSteps 초과                     → 미확정
  noProgress,         // noProgressLimit 동안 상태 해시 불변 & 새 앵커 0 → 데드락 의심
  wallClockBudget,    // 시간 초과                          → 미확정
  questFailed,        // 목표 퀘스트가 failed              → 실패
  crashed,            // 예상 밖 예외                       → 실패
}

class SimResult {
  final SimStopReason stop;
  final SimTrace trace;
  final SimCoverage coverage;
  final String finalStateHash;
  final int steps;
}

class SimDriver {
  SimDriver({required this.config, required this.policy, required this.assets});

  Future<SimResult> run() async { … }
}
```

**실행 루프 (확정)**:

```pseudo
Future<SimResult> run():
    trace = SimTrace(config)
    ui    = HeadlessUiHost(policy: policy, trace: trace)
    move  = HeadlessMovementHost(trace)
    HDHosts().bind(ui: ui, movement: move, assets: assets)      # 기존 이음매 (GROUND_TRUTH §3)
    try:
        await ContentRuntime().boot()                          # BP-27 §3
        await HDGameSession().loadMapFromFile(config.startMap)
        placeParty(config.startX, config.startY)
        await ContentRuntime().onMapEntered(config.startMap, x, y)
        trace.emit('boot', {...})

        stepsSinceProgress = 0
        lastHash = ContentRuntime().state.contentHash()

        while trace.steps < config.maxSteps:
            if goalsSatisfied(): return SimResult(goalsCompleted, ...)
            if anyGoalQuestFailed(): return SimResult(questFailed, ...)

            # --- 모드 게이트 (R-34-3): 호스트 자신의 상태로 판정 ---
            if ui.isMenuOpen: continue     # 정책이 메뉴 안에서 답하므로 여기 오지 않는다

            intent = policy.chooseMove(SimWorldView(
                map: HDGameSession().map, party: HDGameSession().party,
                state: ContentRuntime().state.view,
                index: ContentRepository().triggers))

            match intent:
                case Move(d):     r = await PartyMovementController().step(d)
                case Interact:    r = await PartyMovementController().interactFacing()
                case OpenMenu:    await HDMenuFlows().showMainMenu()
                case Wait:        r = null
                case Stop:        return SimResult(scriptExhausted, ...)

            trace.emitMove(r)
            await WorldEventBus().drain()          # 이벤트가 남아 있으면 마저 흘린다
            trace.step++

            h = ContentRuntime().state.contentHash()
            if h == lastHash and not visitedNewAnchor():
                stepsSinceProgress++
                if stepsSinceProgress >= config.noProgressLimit:
                    return SimResult(noProgress, ...)
            else:
                stepsSinceProgress = 0; lastHash = h

        return SimResult(stepBudget, ...)
    on SimQuitSignal as q:
        return SimResult(quitRequested, ...)
    on GameReloadException:
        trace.emit('reload', {}); # 세이브 로드는 정상 흐름 — 루프를 다시 시작
        …
    on Object as e, StackTrace s:
        trace.emit('error', {'error': '$e', 'stack': shorten(s)})
        return SimResult(crashed, ...)
    finally:
        HDHosts().reset(); ContentRuntime().reset(); PartyMovementController().reset()
```

**종료 조건 요약표**:

| 조건 | 판정 | 종료 코드 기여(§8) |
|---|---|---|
| 목표 퀘스트 전부 `completed` | 성공 | 0 |
| `scripted` 입력 소진 | 성공(입력을 다 소비함) | 0 |
| `SimQuitSignal` & `stopOnQuit` | 성공 | 0 |
| 목표 퀘스트 `failed` | 실패 | 1 |
| 예상 밖 예외 | 실패 | 1 |
| `noProgress` | 실패(데드락 의심) | 1 |
| `maxSteps` / `maxWallSeconds` 초과 | **미확정** | 2 |

**스텝 예산 산정 근거**:

| 시나리오 | 권장 `maxSteps` | 근거 |
|---|---|---|
| 단위 대화 1건 | 200 | 대화 `maxDepth` 32([BP-24 §24.8.4](24_dialogue_model.md)) × 선택지 재방문 여유 |
| 퀘스트 1개 완주(`scripted`) | 1,500 | 100×100 맵 대각 이동 200칸 × 목표 5개 + 여유 |
| 퀘스트 1개 완주(`greedy`) | 5,000 | 경로 탐색 실패 시 탐험 모드 여유 |
| 퍼징 1시드 | 20,000 | §6.3 커버리지 목표에서 역산 |

### 3.6 `SimTrace` — 기록 포맷 (확정)

트레이스는 이 장의 **모든 산출물의 공통 통화**다. 골든 비교(§7), 반례 재생(§5.8), 커버리지(§6.3),
CI 리포트([BP-35](35_ci_and_build.md))가 전부 이 파일을 읽는다.

```jsonc
{
  "traceVersion": 1,
  "meta": {
    "scenarioId": "q.fx.lost_note.happy",
    "policy": "scripted",
    "seed": 20260830,
    "contentLockHash": "3f9a1c…",          // content.lock.json 의 해시 (§7.3 의 2×2 표가 쓴다)
    "packVersions": { "core": "1.0.0", "fx": "0.1.0" },
    "engineSchemaVersion": 2,               // WorldState.schemaVersion
    "startMap": "FX_ROOM", "startX": 2, "startY": 3,
    "assetMisses": [],                      // R-34-8
    "stop": "goalsCompleted",
    "steps": 27,
    "finalStateHash": "a71b0d…",
    "coverage": { "anchors": 4, "anchorsTotal": 4, "dialogueNodes": 9, "dialogueNodesTotal": 11,
                  "questStages": 2, "questStagesTotal": 2, "maps": 1, "places": 1 }
  },
  "events": [
    { "seq": 0,  "step": 0, "kind": "boot",
      "data": { "bundle": "assets/content/build/content.bundle.json", "anchorCount": 4 } },
    { "seq": 1,  "step": 0, "kind": "map_enter",
      "data": { "map": "FX_ROOM", "x": 2, "y": 3, "place": "place.fx.room" } },
    { "seq": 2,  "step": 1, "kind": "move",
      "data": { "outcome": "moved", "dx": 0, "dy": -1, "from": [2,3], "to": [2,2],
                "action": "move", "faced": 1 } },
    { "seq": 5,  "step": 3, "kind": "move",
      "data": { "outcome": "interacted", "dx": -1, "dy": 0, "from": [2,1], "to": [1,1],
                "action": "talk", "faced": 3 } },
    { "seq": 6,  "step": 3, "kind": "tier",
      "data": { "chosen": "content", "anchor": "anchor.fx.client", "x": 1, "y": 1 } },
    { "seq": 7,  "step": 3, "kind": "dialogue_enter",
      "data": { "dialogue": "dlg.fx.client", "entryIndex": 0, "node": "n_offer" } },
    { "seq": 8,  "step": 3, "kind": "log",
      "data": { "lane": "dialogue", "text": "며칠 전 학자에게 맡긴 기록이 있소." } },
    { "seq": 9,  "step": 3, "kind": "menu",
      "data": { "kind": "console", "title": "", "choices": ["맡겠소.", "관심 없소."], "chosen": 1 } },
    { "seq": 10, "step": 3, "kind": "dialogue_choice",
      "data": { "dialogue": "dlg.fx.client", "node": "n_offer", "choice": "c_accept" } },
    { "seq": 11, "step": 3, "kind": "effect",
      "data": { "do": "start_quest", "id": "quest.fx.lost_note", "applied": true } },
    // world_event 의 type 은 D-20 이 고정한 12종만 쓴다. payload 정본은 BP-23 §23.11.1 이며
    // 이 트레이스는 그것을 그대로 실어 나른다(재서술하지 않는다).
    { "seq": 12, "step": 3, "kind": "world_event",
      "data": { "type": "talk", "payload": { "actorId": "npc.fx.client",
                "dialogueId": "dlg.fx.client", "map": "FX_ROOM", "x": 1, "y": 1 } } },
    { "seq": 13, "step": 3, "kind": "quest_state",
      "data": { "quest": "quest.fx.lost_note", "state": "active", "stage": "s1",
                "counters": { "o_acquire_note": 0 } } },
    { "seq": 20, "step": 7, "kind": "state_snapshot",
      "data": { "hash": "9c02fe…", "flags": 1, "vars": 0, "inventory": { "item.fx.old_note": 1 } } },
    { "seq": 40, "step": 12, "kind": "quest_state",
      "data": { "quest": "quest.fx.lost_note", "state": "completed", "stage": null } }
  ]
}
```

**이벤트 kind 전량 (닫힌 집합, v1)**:

| kind | 발생 지점 | 필수 data 필드 | 골든 비교 대상 |
|---|---|---|---|
| `boot` | `SimDriver.run` 시작 | `bundle`, `anchorCount` | ✅ |
| `map_enter` | `ContentRuntime.onMapEntered` | `map`, `x`, `y`, `place?` | ✅ |
| `move` | `PartyMovementController.step` 반환 | `outcome`, `dx`, `dy`, `from`, `to`, `action`, `faced` | ✅ |
| `tier` | `HDTileEventDispatcher._dispatchScripted` 분기 | `chosen`(content\|native\|cm2\|json\|none), `anchor?` | ✅ |
| `dialogue_enter` | `DialogueRuntime.run` 진입 | `dialogue`, `entryIndex`, `node` | ✅ |
| `dialogue_node` | 노드 전이마다 | `dialogue`, `node`, `from?` | ✅ |
| `dialogue_choice` | 선택지 확정 | `dialogue`, `node`, `choice` | ✅ |
| `dialogue_exit` | 대화 종료 | `dialogue`, `lastNode`, `reachedEnd`, `nodesVisited` | ✅ |
| `log` | `UiHost.addLog` | `lane`, `text` | ✅ (텍스트는 §7.2 규칙에 따라) |
| `header` / `clear_logs` / `key_wait` / `narrative_begin` / `narrative_end` / `message_window` | `HeadlessUiHost` | 각각 | 부분(§7.2) |
| `menu` | `showMenu`/`showWindowMenu` | `kind`, `title`, `choices`, `chosen` | ✅ |
| `effect` | `EffectApplier.apply` 항목마다 | `do`, `id?`, `value?`, `applied` | ✅ |
| `world_event` | `WorldEventBus` 배달마다 | `type`(D-20 의 12종 중 하나), `payload`(그대로 전달) | ✅ |
| `quest_state` | `QuestRuntime` 상태 변화 | `quest`, `state`, `stage`, `counters` | ✅ |
| `battle` | `HDBattle` 시작/종료 | `encounter?`, `enemyIds`, `result`, `rounds` | ✅ (수치는 §7.2) |
| `warp` | 지연 `warp` 실행 | `toMap`, `x`, `y` | ✅ |
| `save` / `load` | `HDSaveManager` | `slot`, `stateHash` | ✅ |
| `snap_to` | `PartyMovementHost.snapTo` | `x`, `y` | ✅ |
| `state_snapshot` | N 스텝마다(기본 10) + 종료 시 | `hash`, 집계값 | 해시만 |
| `quit` | `requestQuit` | `reason` | ✅ |
| `error` | 예외 | `error`, `stack`(축약) | ✅ (메시지 정규화) |
| `budget_exhausted` | 예산 초과 | `kind`, `limit` | ✅ |

**불변식**:

| ID | 불변식 |
|---|---|
| TR-1 | `seq` 는 0부터 1씩 증가. 결번·중복 없음 |
| TR-2 | `step` 은 비감소. `WorldState.step`(D-08a) 과 같은 값 |
| TR-3 | 모든 `data` 는 JSON 원시값/배열/객체만. `DateTime`·부동소수 금지(결정론) |
| TR-4 | `dialogue_enter` 와 `dialogue_exit` 은 짝을 이룬다(중단 시 `dialogue_exit.reachedEnd=false`) |
| TR-5 | `narrative_begin`/`narrative_end` 도 짝. 중첩 깊이 1을 넘지 않는다(D-10 "한 번에 하나의 상호작용") |
| TR-6 | 트레이스는 **추가 전용**. 뒤로 돌아가 수정하지 않는다(스트리밍 기록 가능) |
| **TR-7** | `world_event.data.type` 은 **D-20 이 고정한 12종**(`talk`·`enter_place`·`step_tile`·`battle_won`·`item_gained`·`item_lost`·`flag_changed`·`var_changed`·`dialogue_choice`·`map_changed`·`gold_changed`·`party_rested`)만 허용한다. 그 밖의 값은 트레이스 스키마 위반(hard) |
| **TR-8** | `world_event.data.payload` 는 [BP-23 §23.11.1](23_quest_model.md) 의 정본 payload 를 **그대로 실어 나른다.** 하네스는 필드를 더하거나 이름을 바꾸지 않는다 |

> **이름 혼동 방지**: 트레이스의 `kind`(22종)와 월드 이벤트의 `type`(12종)은 **다른 축**이다.
> `quest_state` 는 트레이스 전용 kind 이며 **월드 이벤트가 아니다** — 초판이 `quest_state_changed` 라는
> 비정본 이름을 `world_event.type` 에 실었던 것을 D-20 에 맞춰 정정했다.
> 겹치는 이름은 `dialogue_choice` 하나뿐인데, 이것은 **같은 사건의 두 관점**이므로 의도된 것이다
> (트레이스 kind = "선택지가 확정되었다", 월드 이벤트 type = "그 사실이 퀘스트에 배달되었다").

- **R-34-9** 트레이스는 NDJSON 스트리밍(`.trace.ndjson`)으로도 쓸 수 있어야 한다 —
  크래시로 프로세스가 죽어도 직전까지가 남는다. 최종본만 `.trace.json` 으로 봉인한다.

---

## 4. 입력 정책 3종 (D-13)

### 4.1 공통 인터페이스

```dart
// hadar2026_app/test/harness/sim_policy.dart
sealed class SimIntent {}
class MoveIntent   extends SimIntent { final HDMoveIntent dir; }
class InteractIntent extends SimIntent {}
class OpenMenuIntent extends SimIntent {}
class WaitIntent   extends SimIntent {}
class StopIntent   extends SimIntent {}

class SimMenuRequest {
  final SimMenuKind kind;          // console | window
  final String title;
  final List<String> choices;      // 1-based 로 매핑됨 (UiHost 규약: items[0] 은 제목)
  final int enabledCount;
  final int initialChoice;
}

abstract class SimPolicy {
  String get name;

  /// 다음 행동. 0..N 의 결정을 내리기 위해 필요한 모든 정보는 [v] 에 있다.
  SimIntent chooseMove(SimWorldView v);

  /// 메뉴 선택. 반환값은 UiHost 규약대로 **1-based, 0 = 취소**.
  int chooseMenu(SimMenuRequest req);

  /// 트레이스 이벤트 관측(선택). greedy 가 목표 진행을 추적할 때 쓴다.
  void observe(SimTraceEvent e) {}
}
```

`SimWorldView` 는 **읽기 전용**이며 다음을 준다: 현재 맵(`MapModel`), 파티 좌표·방향·버프,
`WorldStateView`([BP-25 §3.2](25_world_state_and_save.md)), `TriggerIndex`,
활성 퀘스트의 미충족 목표 목록, 그리고 §4.3 의 `MapGraph`.

### 4.2 `scripted` — 주어진 입력 시퀀스

가장 단순하고 가장 많이 쓴다. 골든 회귀(§7)와 반례 재생(§5.8)의 기본 정책.

```pseudo
class ScriptedPolicy(script: List<ScriptStep>):
    cursor = 0
    chooseMove(v):
        if cursor >= len(script): return StopIntent
        s = script[cursor]
        if s.kind in {move, interact, menu_open, wait}:
            if s.kind != menu_open: cursor++          # menu 응답은 chooseMenu 가 소비
            return intentOf(s)
        return StopIntent
    chooseMenu(req):
        s = script[cursor]
        if s.kind != menu: fail("script desync: expected menu at #" + cursor +
                                ", got " + s.kind + " (menu title: " + req.title + ")")
        cursor++
        if s.choice is int:  return s.choice
        # 라벨 매칭 — 항목 순서가 바뀌어도 시나리오가 살아남는다
        i = indexOfChoiceLabel(req.choices, s.label)
        if i < 0: fail("script desync: label '" + s.label + "' not in " + req.choices)
        return i + 1
```

스크립트 표기(JSON, 사람이 쓰고 읽는다):

```jsonc
{ "scenarioId": "q.fx.lost_note.happy",
  "start": { "map": "FX_ROOM", "x": 2, "y": 3 },
  "seed": 20260830,
  "goals": ["quest.fx.lost_note"],
  "script": [
    {"move": "up"}, {"move": "up"},
    {"move": "left"},                       // (1,1) 이 talk 이므로 blocked → interacted
    {"menu": {"label": "맡겠소."}},           // 라벨 매칭 (인덱스 하드코딩 금지)
    {"move": "right"}, {"move": "right"},   // (3,1) 학자
    {"menu": {"label": "기록을 주시오."}},
    {"move": "left"}, {"move": "left"},
    {"menu": {"label": "여기 있소."}}
  ]
}
```

- **R-34-10** 스크립트의 메뉴 응답은 **라벨 매칭을 기본**으로 한다. 인덱스는 `{"menu": {"index": 2}}` 로만 허용하며
  린트가 경고한다 — 선택지 순서는 조건에 따라 바뀌므로([BP-24 §24.2.3](24_dialogue_model.md) `Choice.when`)
  인덱스 하드코딩은 조용한 오분기를 만든다.
- 스크립트 desync 는 **하드 실패**다. "그냥 첫 항목" 으로 넘어가면 시나리오가 다른 길을 걷고도 통과한다.

### 4.3 `greedy` — 목표를 향해 걷는다

#### 4.3.1 맵 통행 그래프 `MapGraph`

이 그래프가 F-1(물리적 도달 불가)을 잡는 자료구조다. **런타임과 같은 판정 함수를 쓴다.**

```dart
// hadar2026_app/test/harness/map_graph.dart  (솔버 쪽 사본은 tools/content_cli/lib/src/solver/)
class MapNode {                 // 통행 가능한 칸 하나
  final String map; final int x, y;
}
class MapEdge {
  final MapNode from, to;
  final MapEdgeKind kind;       // walk | interact | portal
  final Condition? guard;       // portal.when / 버프 요구 / change_tile 로 열리는 길
  final String? anchorId;       // interact/portal 이면 그 앵커
  final int facing;             // interact 일 때 마주보는 방향 (0 down/1 up/2 right/3 left)
}
```

**구축 알고리즘**:

```pseudo
function buildMapGraph(mapName, mapModel, buffs, index) -> MapGraph:
    G = empty
    # 1) 노드 — 통행 가능한 칸
    for (x, y) in mapModel:
        u = mapModel.getUnit(x, y)
        if HDTileProperties.isUnitPassable(u, walkOnWater: buffs.walkOnWater):   # 런타임과 동일 함수
            G.addNode(MapNode(mapName, x, y))

    # 2) walk 간선 — 4방향, 양방향
    for n in G.nodes:
        for d in [up, down, left, right]:
            m = MapNode(mapName, n.x + d.dx, n.y + d.dy)
            if G.hasNode(m): G.addEdge(n -> m, walk)

    # 3) interact 간선 — 통행 불가지만 "마주보고 확인" 으로 닿는 칸
    #    isUnitPassable 이 isInteractive 를 통행 불가로 만들기 때문에(tile_properties.dart:107)
    #    NPC/푯말/입구는 절대 노드가 되지 않는다. 인접 통행칸에서 가상 간선을 건다.
    for (x, y) in mapModel:
        a = HDTileProperties.getUnitAction(mapModel.getUnit(x, y))
        if not a.isInteractive: continue
        target = (mapName, x, y)
        for d in [up, down, left, right]:
            n = MapNode(mapName, x - d.dx, y - d.dy)
            if G.hasNode(n):
                G.addEdge(n -> target, interact, facing: d, anchorId: index.at(mapName, x, y)?.id)
        if noSuchNeighbor: G.markUnreachableInteractive(target)     # ← F-1 의 직접 검출

    # 4) water 조건부 간선 — walkOnWater 버프가 있으면 열리는 칸 (tile_properties.dart:111-113)
    for (x, y) where action == water and unit.ixTile == 56:
        G.addNode(node); G.addEdgesToNeighbors(guard: {"op":"var_cmp","id":"<buff.walkOnWater>","cmp":">","value":0})

    # 5) portal 간선 — 맵 간. 앵커가 소유한다(BP-26 §2.3)
    for a in index.forMap(mapName) where a.kind == portal:
        G.addEdge(anchorNode(a) -> MapNode(a.to.map, a.to.x, a.to.y), portal, guard: a.when, anchorId: a.id)

    # 6) change_tile 로 열리는 길 — Effect 역인덱스에서 (map,x,y) 를 바꾸는 효과를 찾아
    #    그 좌표에 "잠재 간선" 을 달고 guard 로 '그 효과가 실행되었는가' 를 건다
    for e in index.effectsOfKind("change_tile"):
        G.addPotentialEdge(e.map, e.x, e.y, guard: producedBy(e))
    return G
```

**전역 그래프**: 각 맵의 `MapGraph` 를 `portal` 간선으로 이어 하나의 `WorldGraph` 로 만든다.
`guard` 가 붙은 간선은 현재 `WorldState` 로 평가해 **열림/닫힘**이 정해지므로,
같은 그래프가 상태마다 다른 연결 성분을 갖는다. 이것이 §5.2 의 위치 추상화 근거다.

**BFS 경로 산출**:

```pseudo
function pathTo(G, state, from, targets) -> List<HDMoveIntent> | null:
    # 다중 목적지 BFS. guard 는 현재 상태로 평가해 닫힌 간선을 제외한다.
    frontier = [from]; prev = {}
    while frontier:
        n = frontier.pop_front()
        if n in targets: return reconstructIntents(prev, n)
        for e in G.edgesFrom(n):
            if e.guard != null and not ConditionEvaluator.evaluate(e.guard, state): continue
            if e.to not in prev: prev[e.to] = (n, e); frontier.push_back(e.to)
    return null
```

`interact` 간선은 경로의 **마지막 간선으로만** 허용한다(NPC 를 통과해 지나갈 수 없으므로).
경로를 의도열로 환원할 때 마지막 간선은 "그 방향으로 `step()`" 이 되고, 통행 불가 + `isInteractive` 이므로
`PartyMovementController` 가 자동으로 `interacted` 를 낸다 — 별도 `interactFacing` 이 필요 없다.

#### 4.3.2 목표 → 목적지 좌표 도출표

`greedy` 는 활성 퀘스트의 미충족 목표를 좌표로 바꿔야 한다. `Objective.kind`([BP-23 §23.4.4](23_quest_model.md)) 별로:

| kind | 목적지 도출 | 자료 |
|---|---|---|
| `talk_to` | `actor` 를 갖는 `kind:"actor"` 앵커 전부 | `TriggerIndex` + 엔티티 레지스트리 역참조([BP-26 §5](26_entity_registry_and_anchors.md)) |
| `reach` | `place` → `bindingsOf(placeId)` 의 좌표 / `map+x+y+radius` → 그 원 안의 통행 가능 칸 | `TriggerIndex.bindingsOf` |
| `acquire` | 그 `item` 을 주는 `give_item` Effect 를 가진 앵커·대화의 좌표 | Effect 역인덱스 |
| `deliver` | 대상 `actor` 앵커 (+ 선행으로 `acquire` 목적지) | 위 둘 |
| `defeat` | 그 `encounter` 를 갖는 `kind:"battle"` 앵커 / 해당 적이 나오는 인카운터 존 | `TriggerIndex` |
| `flag_set` | 그 flag 를 세우는 `set_flag` Effect 소유 앵커·대화 | Effect 역인덱스 |
| `var_reach` | 그 var 를 올리는 `set_var`/`add_var` 소유 앵커·대화 | Effect 역인덱스 |
| `choose` | 그 `dialogue` 를 여는 앵커 | `TriggerIndex` |
| `survive` | 전투 진입점(`battle` 앵커 또는 인카운터가 있는 맵의 아무 칸) | `TriggerIndex` |

> **역참조 인덱스가 여기서 값을 한다.** [BP-26 §5](26_entity_registry_and_anchors.md) 의
> `content.index.json#entities` 는 "이 플래그를 세우는 것은 무엇인가" 를 O(1) 로 답한다.
> 그것이 없으면 `greedy` 는 전체 콘텐츠를 매번 훑어야 한다.

#### 4.3.3 알고리즘

```pseudo
class GreedyPolicy:
    exploreQueue = []        # 미방문 앵커
    plan = []                # 남은 의도열
    stuckSites = set()       # 도달 실패로 포기한 목적지

    chooseMove(v):
        if plan not empty: return plan.pop_front()

        # 1) 활성 퀘스트의 미충족 목표를 우선순위대로
        objs = v.activeObjectives()                        # (questId, stageId, objective)
        objs.sortBy(questPriority, objectiveIndex)          # 결정적 정렬 — 시드 무관
        for o in objs:
            sites = resolveSites(o, v.index) - stuckSites
            if sites empty:
                trace.emit('solver_hint', {objective: o.id, reason: 'no producer'})
                continue
            p = pathTo(v.graph, v.state, v.partyNode, sites)
            if p == null:
                stuckSites.addAll(sites)
                trace.emit('solver_hint', {objective: o.id, reason: 'unreachable'})
                continue
            plan = p; return plan.pop_front()

        # 2) 목표가 다 막혔거나 없으면 탐험 — 미방문 앵커 중 가장 가까운 곳
        if exploreQueue empty: exploreQueue = unvisitedAnchors(v).sortedById()
        while exploreQueue:
            a = exploreQueue.pop_front()
            p = pathTo(v.graph, v.state, v.partyNode, {anchorNode(a)})
            if p != null: plan = p; return plan.pop_front()

        # 3) 아무 데도 갈 곳이 없다
        return StopIntent

    chooseMenu(req):
        # 목표에 기여하는 선택지를 고른다.
        goalIds = v.activeObjectiveReferencedIds()
        best = null; bestScore = -1
        for (i, c) in enumerate(req.choices):
            s = score(c)                                    # ↓
            if s > bestScore: bestScore = s; best = i + 1
        return best ?? 1

    score(choice):
        eff = choiceEffects(choice)                         # 대화 그래프에서 역조회
        ids = EffectApplier.referencedIds(eff)
        s = 3 * |ids ∩ goalIds|                             # 목표 기여
        s += 1 if eff contains start_quest of a goal quest
        s -= 5 if eff contains fail_quest / clear_flag of a goal id     # 자해 회피
        s -= 2 if choice.once and |ids ∩ goalIds| == 0                  # 소모 회피
        return s
```

**결정론 요구**: `sortBy` / `sortedById` / 동점 시 id 사전순 — 어디에도 해시 순서 의존이 없어야 한다.

**한계(명시)**: `greedy` 는 **완주 증명이 아니다**. 성공하면 "적어도 한 경로가 있다" 는 증거(witness)를 얻고,
실패하면 아무것도 증명하지 못한다. **증명은 §5 의 솔버가 한다.** `greedy` 의 값어치는
(a) 솔버 해의 재생 (b) 퍼징보다 깊이 들어가는 커버리지 (c) 사람이 읽을 수 있는 "정상 플레이" 트레이스 생성이다.

### 4.4 `random(seeded)` — 시드 고정 퍼징

```pseudo
class RandomPolicy(seed, weights):
    rng = SplitMix64(seed)          # BP-27 §9.2 의 WorldRng 와 같은 계열, 별도 스트림

    chooseMove(v):
        r = rng.nextInt(100)
        if r < weights.move:      return MoveIntent(dirs[rng.nextInt(4)])
        if r < weights.interact:  return InteractIntent()
        if r < weights.menu:      return OpenMenuIntent()
        return WaitIntent()

    chooseMenu(req):
        # 취소(0)도 후보에 넣는다 — 취소 경로에서 나는 버그가 많다
        return rng.nextInt(req.enabledCount + 1)
```

기본 가중치: `move 70 / interact 20 / menu 5 / wait 5`.
`move` 가 압도적인 이유는 이동이 대부분의 상태 전이(step-on, 인카운터, 앵커 도달)를 유발하기 때문이다.

**편향 완화 2가지**:

| ID | 문제 | 완화 |
|---|---|---|
| RP-1 | 순수 랜덤 워크는 시작점 근처에서 맴돈다(랜덤 워크의 회귀성) | 확률 `weights.persist`(기본 60%)로 **직전 방향을 유지**한다 — 실제 플레이어의 조작 패턴에도 가깝다 |
| RP-2 | 맵이 크면 앵커에 영영 안 닿는다 | `--fuzz-hint` 모드: 5% 확률로 `greedy` 의 `pathTo` 를 한 번 써서 임의 앵커로 점프하는 계획을 세운다. **기본은 꺼둔다**(순수 랜덤의 발견력을 지키기 위해) |

---

## 5. 퀘스트 솔버

### 5.1 형식적 정의 — 두 개의 독립된 질문 (D-26)

솔버는 **하나가 아니라 두 개의 질문**에 답한다. 초판은 이 둘을 하나로 접었고,
그 결과 "모델은 맞는데 엔진이 신호를 안 내는" 콘텐츠(§1.2 F-4)에 `PROVEN` 을 냈다.

| 축 | 질문 | 값 | 판정 근거 |
|---|---|---|---|
| **모델 증명** | 콘텐츠 그래프상 완주 경로가 존재하는가? | `PROVEN` / `REFUTED` / `UNKNOWN` | §5.2~§5.9 의 상태 공간 탐색 |
| **실행 가능** | 그 경로가 의존하는 **모든 월드 이벤트에 현행 빌드의 발행 지점이 있는가?** | `SUPPORTED` / `UNSUPPORTED` | §5.10 의 레지스트리 대조 |

**축 1 — 모델 증명**의 형식적 정의:

> 퀘스트 `q` 에 대해, 초기 월드 상태 `S₀` 에서 시작해 유한한 액션열
> `a₁ … aₙ` 이 존재하여 `quests[q].state == "completed"` 인 상태에 도달하는가?

- **존재하면** → `PROVEN`. 증인(witness)은 그 액션열이다.
- **존재하지 않음이 증명되면** → `REFUTED`. 반증은 "도달 집합에서 참이 된 적 없는 조건 원자" 다(§5.8).
- **예산 안에 답이 안 나오거나, 추상화가 안전 방향 원칙(§5.2.1)을 만족하지 못하면** → `UNKNOWN`(§5.9).
  **실패가 아니다.**

**축 2 — 실행 가능**의 형식적 정의는 §5.10 에 있다.

**폐기어 대조표** — 초판 BP-34 의 판정 이름은 정본이 아니다. 다른 장이 인용하고 있다면 아래로 읽는다.

| 초판(폐기) | 정본(D-26) | 비고 |
|---|---|---|
| `UNREACHABLE` | **`REFUTED`** | 의미 동일. 이름만 D-26 을 따른다 |
| `INCONCLUSIVE` | **`UNKNOWN`** | 의미 동일 + §5.2.1 의 "추상화 불충분" 사유가 추가됐다 |
| `PROVEN_BY_WITNESS` | `PROVEN`(승격 사유 `by_witness`) | 별도 판정값이 아니라 **`PROVEN` 의 하위 사유**다(§5.9) |
| `MISSABLE` | 유지 | 축 1 의 값이 아니라 **낙관/비관 조합의 파생 판정**이다(§5.6) |
| — | **`SUPPORTED` / `UNSUPPORTED`** | 신설. 축 2 (§5.10) |

### 5.2 상태 추상화 규칙 — 폭발을 막는 곳

`WorldState` 전체를 상태로 쓰면 즉시 폭발한다. `vars` 만 256개여도 `int` 값 공간이 무한이고,
좌표까지 넣으면 100×100 맵 하나에 10,000 배가 곱해진다.

> **지배 원칙 A-0**: **콘텐츠가 조건으로 읽는 것만 상태다.**
> 어떤 id 가 `Condition` 에도 `Objective.params` 에도 등장하지 않으면, 그 값은 게임의 진행에 영향을 줄 수 없다.
> 대상 집합은 `ConditionEvaluator.referencedIds` + `EffectApplier.referencedIds` +
> 목표 퀘스트의 `params` 로 **자동 산출**한다([BP-27 §2.4](27_runtime_engine.md)).

| ID | 규칙 | 근거 |
|---|---|---|
| **A-1** | `flags` → **참조되는 flag id 의 부분집합만** 비트벡터로. 미참조 플래그는 버린다 | A-0 |
| **A-2** | `vars` → 참조되는 var 만. **감산 Effect(`add_var` 의 음수 delta, 또는 더 작은 값으로의 `set_var`)가 없는 var** 만 버킷화한다. 버킷 경계는 그 var 가 등장하는 모든 `var_cmp.value`/`var_reach.value` 의 정렬 집합. **감산이 있으면 버킷화하지 않고** `[0, varCap]` 의 정확한 정수로 두며, `varCap > --max-numeric-domain`(기본 1024)이면 `UNKNOWN` 강등 | 버킷화는 감산이 있으면 bisimulation 이 아니다(§5.2.2 반례와 같은 구조) |
| **A-3** | `quests` → `(state, stage, counters)`. `counters` 는 `target` 으로 클램프(래치, [BP-23 §23.4.6](23_quest_model.md)). 목표 퀘스트와 그 선행/mutex 퀘스트만 포함 | INV-4 + 래치 |
| **A-4** | `inventory` → 참조 아이템만. 개수는 **충분 상한** `cap(i)` 로 포화(saturate)한다. `cap(i) = Σ_consume(i) + maxHold(i)` (§5.2.2 에서 정의·증명). `cap(i)` 가 무한이면 클램프하지 않고 그 아이템을 **`UNKNOWN` 강등 사유**로 표시한다 | §5.2.2 정리 T-1/T-2. 초판의 `max(...)` 클램프는 **거짓 `REFUTED`** 를 만든다 |
| **A-5** | `npcStates` → 참조되는 actor 만. 값은 그 actor 가 선언한 `states[]` 의 인덱스 | 유한 열거 |
| **A-6** | `visited` → 참조되는 place 만 | A-0 |
| **A-7** | **위치는 좌표가 아니라 "구역(region) id"** — 현재 `guard` 평가 결과로 열린 간선만 남긴 `WorldGraph` 의 **연결 성분 id**. 조건이 바뀌어 간선이 열리면 성분이 병합되고 region id 가 바뀐다 | 10,000 칸 → 보통 1~5 구역. F-1 을 잃지 않으면서 폭발만 제거 |
| **A-8** | `once` 소진 집합 — 발동된 `once` 앵커 id 의 비트벡터(F-3 검출에 필수) | [BP-26 §2.2](26_entity_registry_and_anchors.md) `once` |
| **A-9** | **제외**: `step`, `rngCursor`, `journal`, 파티 HP/SP/exp/level, food, 콘솔 로그, 맵 타일 오버라이드(단 A-7 의 guard 로 반영). **`gold` 는 `gold_cmp`/`add_gold` 에 등장하면 A-2 의 "감산 있는 var" 와 **정확히 같은 규칙**으로 다룬다(`add_gold(-n)` 이 감산이다) | 진행 판정에 쓰이지 않거나 다른 축으로 흡수됨 |
| **A-10** | **안전 방향 원칙** — 아래 §5.2.1. 위 규칙 중 bisimulation 을 증명하지 못하는 축이 목표에 관여하면 그 퀘스트는 **`REFUTED` 를 주장하지 않고 `UNKNOWN` 으로 강등**한다 | 거짓 `REFUTED` 를 구조적으로 불가능하게 만드는 유일한 장치 |

**상태 크기 실측 추정**(§9 픽스처 기준): flags 3 + vars 0 + quests 1 + inv 1 + npc 0 + visited 1 + region 1 + once 1
→ 이론적 상태 수 `2³ × 4(퀘스트 상태) × 2 × 2 × 2 × 2 = 512`. 실제 도달 가능 상태는 **20 내외**.

---

#### 5.2.1 안전 방향 원칙 (A-10) — 거짓 `REFUTED` 를 구조적으로 금지한다

추상화가 정보를 버리는 방향에는 **두 가지**가 있고, 둘의 위험도는 대칭이 아니다.

| 방향 | 정의 | 낳는 오류 | 검출 가능? |
|---|---|---|---|
| **과대근사(over-approximation)** | 구체 상태 여럿을 하나의 추상 상태로 **합친다**. 추상 전이 집합 ⊇ 구체 전이 집합의 상 | 거짓 `PROVEN` (없는 경로를 있다고 함) | **가능** — witness 를 `SimDriver` 로 재생하면 실패한다(R-34-7) |
| **과소근사(under-approximation)** | 추상화가 실제로 가능한 **전이를 잃는다** | **거짓 `REFUTED`** (있는 경로를 없다고 함) | **불가능** — 재생할 witness 자체가 없다(R-34-7 이 원리적으로 작동하지 않음) |

> **거짓 `REFUTED` 는 거짓 `PROVEN` 보다 나쁘다.** 거짓 `PROVEN` 은 다음 단계(시뮬레이터·퍼징·플레이테스트)가
> 잡아내는 반면, 거짓 `REFUTED` 는 **멀쩡한 콘텐츠를 반려하고 제작자에게 존재하지 않는 결함을 고치라고 시킨다.**
> 게다가 §5.8 의 반례 리포트가 "생산자가 없다" 같은 **그럴듯하지만 틀린 진단**을 붙이므로 추적이 매우 어렵다.

**R-34-21 (안전 방향 원칙, 확정)**

> 각 상태 축의 추상화 함수 `α` 는 다음 중 하나여야 한다.
> - **(S) 강한 이중모의(strong bisimulation)** — `α` 가 관측(조건 평가 결과)과 전이(Effect 적용 결과)를 **양방향으로 보존**한다.
>   이 축은 `PROVEN` 도 `REFUTED` 도 낼 수 있다.
> - **(O) 과대근사** — 전이를 잃지 않고 상태만 합친다. 이 축은 `PROVEN` 을 낼 수 있으나
>   그 `PROVEN` 은 **R-34-7 재생을 통과해야만** 확정된다. `REFUTED` 도 낼 수 있다(합쳐도 도달 못 하면 실제로도 못 한다).
> - **(U) 그 외** — 전이를 잃을 가능성이 있다. **이 축이 목표에 관여하면 판정은 `UNKNOWN` 이다.**
>   솔버는 `REFUTED` 를 **주장하지 않는다**.

**각 규칙의 분류 (증명 요지 포함)**:

| 규칙 | 분류 | 근거 |
|---|---|---|
| A-1 `flags` 부분집합 | **S** | 버린 flag 는 어떤 `Condition`·`Objective.params` 에도 등장하지 않으므로(A-0) 관측에 영향이 없고, 그 flag 를 바꾸는 Effect 는 다른 축을 바꾸지 않는다. 관측·전이 보존 |
| A-2 `var` 버킷(감산 없음) | **S** | 감산이 없으면 값은 단조 증가. 두 값이 같은 버킷이면 이후 모든 `var_cmp` 결과가 같고, 증가 전이는 버킷을 같은 방향으로만 옮긴다 |
| A-2 `var` 정확 정수(감산 있음) | **S** | 추상화가 아니다(값을 그대로 쓴다). 단 도메인이 `--max-numeric-domain` 을 넘으면 **U** 로 강등 |
| A-3 `quests` | **S** | `state`/`stage` 는 유한 열거. `counters` 는 래치로 `target` 상한이며 INV-4 가 그 이상을 만들지 않는다 — 클램프가 아니라 **런타임의 실제 동작**이다 |
| A-4 `inventory` 포화(§5.2.2) | **S** | 정리 T-1 이 증명한다. `cap` 이 무한이면 **U** |
| A-5 `npcStates` | **S** | 선언된 `states[]` 의 유한 열거를 그대로 쓴다 |
| A-6 `visited` | **S** | 추가 전용 집합의 부분집합. A-1 과 같은 논리 |
| A-7 `region` 성분 | **O** (조건부 **S**) | 같은 성분 안에서는 임의 이동이 가능하므로 "어디에 서 있는가" 가 관측을 바꾸지 않는다. **단 이동 횟수에 의존하는 목표**(`survive.turns`, `Quest.timeoutSteps`, `step_tile` 누적)가 있으면 **U** — 그 경우 해당 퀘스트는 `UNKNOWN` |
| A-8 `consumedOnce` | **S** | 추가 전용 비트벡터. 정확값 |
| A-9 제외 축 | **O** | 버린 축(HP·food·step 등)은 어떤 `Condition` 도 읽지 않으므로 관측을 바꾸지 않는다. 다만 **런타임에서는** 파티 전멸로 진행이 막힐 수 있으므로 과대근사다 → `PROVEN` 은 R-34-7 재생이 확정한다 |

**따라서 거짓 `REFUTED` 는 불가능하다.** 논증:

1. `REFUTED` 를 낼 수 있는 축은 **S 와 O 뿐**이다(R-34-21).
2. S 축은 정의상 전이를 잃지 않는다 — 구체 실행에 존재하는 모든 전이가 추상 공간에도 있다.
3. O 축도 전이를 잃지 않는다(상태를 합칠 뿐이다). 합친 결과 도달 집합은 **구체 도달 집합의 상을 포함**한다.
4. 즉 추상 도달 집합 ⊇ `α`(구체 도달 집합). 대우: 추상적으로 도달 불가 ⇒ **구체적으로도 도달 불가.**
5. U 축이 하나라도 목표에 관여하면 3번의 포함관계가 깨질 수 있으므로 판정을 `UNKNOWN` 으로 강등한다 —
   즉 **포함관계가 성립할 때만 `REFUTED` 를 말한다.** ∎

- **R-34-23** 솔버는 판정과 함께 **`abstractionClass`**(각 축의 S/O/U 분류)를 리포트에 낸다.
  `REFUTED` 리포트에 U 축이 하나라도 있으면 그것은 **솔버의 구현 버그**이며 CI 가 종료 코드 3(도구 내부 오류)으로 실패한다.

---

#### 5.2.2 인벤토리 충분 상한 — 정리와 증명

**초판이 틀린 이유(반례)**. 초판 A-4 는 `cap(i) = max(모든 요구의 count)` 였다.

| | 내용 |
|---|---|
| 퀘스트 A | `deliver(item.x, count:2)` → 완료 시 `take_item(item.x, 2)` |
| 퀘스트 B | `deliver(item.x, count:3)` → 완료 시 `take_item(item.x, 3)` |
| 초판 cap | `max(2,3) = 3` |
| 실제 게임 | `item.x` 를 5개 모으면 A(−2) 후 3개 남고 B(−3) 도 완주. **둘 다 가능** |
| 초판 추상 | 보유량이 3으로 잘리므로 A 먼저 → `3−2=1`(B 불가), B 먼저 → `3−3=0`(A 불가). **둘 다 불가로 판정** |
| 결과 | **거짓 `REFUTED`** |

**정의**. 아이템 `i` 에 대해:

```
consumeSites(i)  = i 를 소비하는 모든 사이트 (Effect `take_item(i,k)`, deliver 목표의 인도, 소비형 item.effects)
holdReqs(i)      = i 를 소비하지 않고 보유만 요구하는 모든 조건 (has_item(i,c), acquire 목표의 count)

Σ_consume(i) = Σ over s in consumeSites(i) of ( s.count × maxFirings(s) )
maxHold(i)   = max over r in holdReqs(i) of r.count        (없으면 0)

cap(i) = Σ_consume(i) + maxHold(i)
```

`maxFirings(s)` — 그 소비 사이트가 **유의미하게** 발동될 수 있는 최대 횟수:

| 사이트 성격 | `maxFirings` |
|---|---|
| `once` 앵커 / `once` 선택지 / 스테이지 `onExit` 등 1회성 | 1 |
| 카운터형 목표에 기여 (`counter.target = t`) | `t` (래치가 그 이상을 무의미하게 만든다) |
| 반복 발동 가능하고 카운터에도 기여하지 않음 | **∞** |

**정리 T-1 (충분 상한은 이중모의를 유도한다)**
`cap(i)` 가 유한이면 `α(n) = min(n, cap(i))` 는 아이템 `i` 축에 대해 강한 이중모의다.

- **(관측 보존)** 모든 보유 조건은 `has_item(i, c)` 꼴이고 `c ≤ maxHold(i) ≤ cap(i)`.
  `n ≥ cap(i)` 이면 `α(n) = cap(i) ≥ c` 이므로 진리값이 같다. `n < cap(i)` 이면 `α(n) = n` 으로 값이 보존된다. ∎
- **(전이 보존, 획득)** `give_item(i,k)`: 구체 `n → n+k`, 추상 `min(n,cap) → min(n+k,cap)`.
  `min` 은 단조이므로 `α(n+k) = min(α(n)+k, cap)`. 대응 성립. ∎
- **(전이 보존, 소비)** `take_item(i,k)` 를 사이트 `s` 에서 실행한다. 실행 후 남은 예산은
  `cap'(i) = Σ_consume(i) − k + maxHold(i) = cap(i) − k` 다(그 사이트의 발동 1회가 소진되었으므로).
  구체 `n → n−k`, 추상 `min(n,cap) → min(n,cap) − k`.
  `n ≥ cap` 이면 추상은 `cap − k = cap'`, 구체는 `n − k ≥ cap − k = cap'`.
  즉 **양쪽 모두 "남은 예산 이상" 을 유지**하며, 이후의 어떤 관측·전이도 이 둘을 구분하지 못한다.
  `n < cap` 이면 값이 그대로이므로 자명하다. ∎
- **(따라서)** `α` 는 관측과 전이를 양방향 보존한다 → **S 분류**. 거짓 `PROVEN` 도 거짓 `REFUTED` 도 낳지 않는다.

> **핵심 직관**: `cap` 은 "게임 전체에서 앞으로 필요할 수 있는 최대량" 이고, 소비할 때마다 **정확히 그만큼 줄어든다.**
> 그래서 포화는 "구분할 필요가 없어진 여분" 만 버린다. 초판의 `max(...)` 는 이 예산 개념이 없어서
> **아직 필요한 양까지 잘라냈다.**

**위 반례의 재계산**: `consumeSites = {A(2, 1회), B(3, 1회)}`, `holdReqs = {}`.
`cap = (2×1) + (3×1) + 0 = 5`. 보유 5 가 그대로 표현되므로 A → B 순서로 완주 경로가 발견된다. **`PROVEN`.** 정상.

**정리 T-2 (유한성 조건)**
`cap(i)` 는 `consumeSites(i)` 의 모든 사이트가 유한 `maxFirings` 를 가질 때에만 유한하다.
하나라도 ∞ 면 `cap(i) = ∞` 이며 클램프할 수 없다.

**규칙 A-4 의 완성형**:

| 상황 | 처리 |
|---|---|
| `cap(i)` 유한 | `min(n, cap(i))` 로 포화. **S 분류**. `PROVEN`·`REFUTED` 모두 주장 가능 |
| `cap(i) = ∞` **그리고** `i` 가 목표 퀘스트에 관여 | **`UNKNOWN` 강등**(R-34-21 U). `REFUTED` 를 주장하지 않는다 |
| `cap(i) = ∞` 이지만 목표와 무관 | A-0 로 상태에서 제외 |
| `cap(i)` 유한이지만 `> --max-numeric-domain`(기본 1024) | 예산 보호를 위해 **`UNKNOWN` 강등**. `REFUTED` 를 주장하지 않는다 |

- **R-34-24** `--relax-clamp <배수>`(기본 1) 은 모든 `cap` 을 배수만큼 늘려 재실행한다.
  §11.3 의 거짓 `REFUTED` 검출 절차가 쓰는 진단 도구이며, **판정을 뒤집는 데 쓰지 않는다** —
  배수를 올려 결과가 바뀌면 그것은 **`cap` 산출 코드의 버그**라는 뜻이고, 콘텐츠가 아니라 솔버를 고쳐야 한다.
- **R-34-25** 같은 예산 논리를 **`var`(A-2)와 `gold`(A-9)** 에 적용한다.
  감산이 있는 수치 축은 버킷화하지 않고 `[0, cap]` 정확값으로 두되,
  `cap = max(임계값) + Σ(모든 감산 사이트의 |delta| × maxFirings)` 이며, 무한하거나 도메인 상한을 넘으면 `UNKNOWN` 이다.

**해시 키**:

```pseudo
function stateKey(S) -> int64:
    parts = []
    parts += "F:" + join(sorted(S.flags), ",")
    parts += "V:" + join(sorted("k=b" for (k,b) in S.varBuckets), ",")
    parts += "Q:" + join(sorted("q:st:sg:" + join(sorted(counters)) for q in S.quests), ",")
    parts += "I:" + join(sorted("i=c" for (i,c) in S.invClamped), ",")
    parts += "N:" + join(sorted("a=s" for (a,s) in S.npcStates), ",")
    parts += "P:" + join(sorted(S.visited), ",")
    parts += "R:" + S.regionId
    parts += "O:" + join(sorted(S.consumedOnce), ",")
    return fnv1a64(join(parts, "|"))
```

- **R-34-11** 모든 집합·맵은 **정렬 후** 직렬화한다. 정렬하지 않으면 삽입 순서(= 플레이 경로)에 따라
  같은 상태가 다른 키를 갖는다(BP-27 V-4 와 같은 함정).
- **R-34-12** 해시 충돌 방어: 방문 집합은 `Map<int64, List<AbstractState>>` 로 두고 충돌 시 전체 비교한다.
  솔버가 "이미 봤다" 를 잘못 판단하면 **오탐(거짓 UNREACHABLE)** 이 나므로 여기서 아끼지 않는다.

### 5.3 액션 모델 — 대화를 원자로 축약한다

솔버의 액션은 "키 한 번" 이 아니라 **"지금 발동 가능한 앵커 하나를 끝까지 수행한다"** 이다.

```pseudo
function successors(S) -> List<(Action, AbstractState)>:
    out = []
    for a in allAnchors():
        if not reachable(S.regionId, a): continue               # A-7 로 O(1)
        if not ConditionEvaluator.evaluate(a.when, S.view): continue
        if a.once and a.id in S.consumedOnce: continue
        for outcome in enumerateOutcomes(a, S):                 # ↓ 대화 분기마다 하나
            S' = applyOutcome(S, outcome)
            if S' != S or outcome.movesRegion: out.add((Action(a, outcome), S'))
    return sortedDeterministically(out)                          # anchorId, outcomeId 순
```

**`enumerateOutcomes`** — 대화 그래프 하나를 **결정적으로 전개**해 종료 시점의 상태 델타 집합을 만든다:

```pseudo
function enumerateOutcomes(anchor, S) -> List<Outcome>:
    if anchor.kind != actor and anchor.kind != sign:
        return [Outcome(effects: anchor.effects ?? contentsToEffects(anchor))]

    d = resolveDialogue(anchor, S)                # entry 규칙: 위에서부터 첫 true (D-07)
    results = []
    stack = [(entryNode, deltaEmpty, visitedEmpty, depth 0)]
    while stack:
        (n, delta, visited, depth) = stack.pop()
        if depth > d.maxDepth (기본 32): results.add(Outcome(delta, truncated: true)); continue
        delta' = delta + node.onEnter.effects
        if node has no choices:
            if node.next == "end": results.add(Outcome(delta')); continue
            key = (node.next, delta'.signature)
            if key in visited: results.add(Outcome(delta', cycled: true)); continue   # ← 사이클 차단
            stack.push((node.next, delta', visited + key, depth+1))
        else:
            for c in node.choices:
                if c.when != null and not evaluate(c.when, S.view + delta'): continue  # 표시 안 되는 선택지
                if c.once and c.id in delta'.consumedChoices: continue
                stack.push((c.go, delta' + c.effects + consume(c), visited, depth+1))
    return dedupeBySignature(results)
```

**핵심**: 대화 **내부의 노드 전이는 상태 공간의 노드가 아니다.** 대화 하나는 상태 공간에서
"입구 상태 → 종료 델타 집합" 이라는 **하나의 분기 액션**으로 압축된다.
이것이 [BP-24 §24.8.3](24_dialogue_model.md) 이 허용한 대화 사이클을 상태 폭발 없이 다루는 방법이다(§5.7).

### 5.4 탐색 알고리즘

| 후보 | 채택 | 이유 |
|---|---|---|
| **BFS** | ✅ **기본** | 상태가 단조(§5.5)라 재방문 제거 효율이 매우 높고, 최단 witness 를 준다. 반례 최소화가 공짜 |
| **A\*** | ✅ **대안**(`--search astar`) | 상태 수가 큰 팩에서 목표 지향 탐색이 필요할 때. 휴리스틱은 아래 |
| **IDA\*** | ❌ | 메모리는 아끼지만 **상태 재생성 비용**이 크다. 여기서는 후속자 생성이 비싼 편(대화 전개) — 재탐색이 손해 |
| **DFS** | ❌ | 단조 공간에서 깊이 우선은 긴 무의미 경로에 빠지고 witness 가 길어진다 |

**A\* 휴리스틱** `h(S)` = 목표 퀘스트의 **남은 미충족 목표 수** + (현재 stage 이후 남은 stage 수).
목표 하나를 액션 하나가 충족하는 것이 보통이므로 대체로 admissible 하지만,
한 액션이 두 목표를 동시에 충족할 수 있어 **엄밀하게는 non-admissible** 이다.
따라서 A\* 모드는 **최적성을 보장하지 않는다**(witness 가 최단이 아닐 수 있다)고 명시하고,
반례 최소화가 필요할 때는 BFS 를 쓴다.

**가지치기**:

| ID | 이름 | 내용 | 안전성 |
|---|---|---|---|
| P-1 | 지배(dominance) | `S' ⊒ S`(플래그 상위집합 ∧ 카운터 ≥ ∧ 인벤 ≥ ∧ 같은 region ∧ 퀘스트 진행 ≥ ∧ `consumedOnce` **하위집합**) 이면 `S` 를 폐기 | **안전** — 단조성(§5.5) 하에서. 단 `consumedOnce` 는 방향이 반대임에 주의(적게 쓴 쪽이 우월) |
| P-2 | 무효 액션 | 델타가 공집합이고 region 도 안 바뀌면 후속자로 만들지 않는다 | 안전 |
| P-3 | 무관 액션 후순위 | 목표 퀘스트의 referencedIds 와 교집합이 0 인 액션은 우선순위 큐 뒤로 | **완전성 보존**(제거가 아니라 후순위). 예산 안에서만 영향 |
| P-4 | 실패 상태 | `failConditions` 가 참이면 그 가지를 종료 처리 | 낙관 모드에선 폐기, 비관 모드에선 반례 후보로 기록 |
| P-5 | 목표 무관 퀘스트 절단 | 목표 퀘스트가 `prerequisites`/`mutex` 로 참조하지 않는 다른 퀘스트는 상태에서 제외 | A-0 |

### 5.5 완료 래치가 종료를 보장하는 방식

[BP-23 §23.4.6](23_quest_model.md): *"`counter >= target` 이 된 순간 `target` 으로 고정하고 이후 낮추지 않는다."*

이것이 솔버에 주는 것:

1. **단조성** — `counters` 는 비감소. `quests[q].state` 는 `inactive → active → completed|failed` 로만 가고
   되돌아오지 않는다(INV-2). `visited` 는 추가 전용. `consumedOnce` 는 추가 전용.
2. **부분순서 정의 가능** — 위 성분들에 자연스러운 `⊑` 가 생긴다 → P-1 지배 가지치기가 **안전**해진다.
3. **종료 보장 논증**:
   - 각 상태 성분의 도메인이 유한하다(A-1~A-8 이 전부 유한 집합/유한 버킷/유한 열거로 만들었다).
   - 따라서 추상 상태 공간 `|Σ|` 가 유한하다.
   - 방문 집합이 있으므로 각 상태는 최대 1회 확장된다.
   - P-2 가 자기 루프(델타 공집합)를 제거한다.
   - ⇒ 탐색은 최대 `|Σ| × maxBranching` 회 확장 후 **반드시 종료**한다.
4. **래치가 없으면**: `flags` 가 `set/clear` 로 오르내려 상태가 비단조가 되고, P-1 이 불안전해지며,
   같은 상태를 다른 경로로 무한히 재방문할 수 있다. 종료는 방문 집합으로 여전히 보장되지만
   **탐색 폭이 지수적으로 커진다**. 래치는 성능이 아니라 **실용성**의 조건이다.

> ⚠️ **주의**: `flags` 자체는 래치되지 않는다(`clear_flag` 가 있다, D-05). 단조성이 깨지는 유일한 성분이다.
> 그래서 P-1 의 지배 판정은 **flags 를 상위집합 조건으로만** 쓰고, `clear_flag` 를 포함하는 팩에서는
> 솔버가 `--no-dominance` 로 자동 전환한다(경고 1줄). 이 자동 전환 여부는 리포트에 남긴다.

### 5.6 비결정 — 낙관·비관 양방향 탐색

| 원천 | 낙관(optimistic) | 비관(pessimistic) | 근거 |
|---|---|---|---|
| `chance(percent)` op | 유리한 분기 선택 가능 | 불리한 분기 강제 | D-05: *"chance 는 시드 난수, 검증기에서 **양 분기 모두 탐색**"* |
| 전투 승패(`start_battle`) | 승리 가정 | 패배 분기도 전개 | B-2 의 결과 코드 불일치는 [BP-27](27_runtime_engine.md) 이 정본을 정한다. 솔버는 그 정본을 따른다 |
| 랜덤 인카운터 | 발생하지 않음 | 이동마다 발생(자원 소모 상한 검사) | `Map::SetEncounter` / `HDParty.encounter` |
| 대화 선택지 | 전부 분기(플레이어 선택) | 전부 분기 | 선택은 난수가 아니라 자유도. 양쪽 모드 동일 |

**두 번 돌린다.**

| 모드 | 탐색 의미 | 성공의 뜻 |
|---|---|---|
| 낙관 | `∃` 경로 | "잘하면 깰 수 있다" |
| 비관 | `∀` 경로 (모든 비결정 분기에서 목표 도달) | "어떻게 굴러도 깰 수 있다" |

**판정 매트릭스**:

| 낙관 | 비관 | 판정 | 게이트 |
|---|---|---|---|
| 성공 | 성공 | `PROVEN` | 통과 |
| 성공 | 실패 | `MISSABLE` — 되돌릴 수 없는 실수/불운이 존재 | **Soft gate**. 리포트에 "어떤 분기에서 막히는가" 를 첨부하고 검수 에이전트(D-14 7단계)가 판단 |
| 실패 | (자동 실패) | `UNREACHABLE` | **Hard gate** — 커밋 불가(D-15) |
| 예산 초과 | — | `INCONCLUSIVE` | 경고 + 재시도(§5.9) |

`MISSABLE` 이 항상 나쁜 것은 아니다 — 실패 가능 퀘스트([BP-23 §23.8](23_quest_model.md))는 의도적으로 `MISSABLE` 이다.
그래서 퀘스트에 `"tags": ["missable"]` 가 있으면 `MISSABLE` 은 **정상 판정**으로 통과시킨다.

### 5.7 대화 사이클과 상태 폭발 방지

[BP-24 §24.8.3](24_dialogue_model.md) 은 대화 사이클을 **허용**한다("더 물어보기" → 원래 노드).
[BP-23](23_quest_model.md) 은 퀘스트 스테이지 사이클을 **금지**한다. 둘의 비대칭이 솔버 설계를 가른다.

| 층위 | 사이클 | 솔버의 처리 |
|---|---|---|
| 퀘스트 스테이지 | 금지(빌드가 검출) | 신경 쓸 것 없음 — DAG |
| 대화 노드 | 허용 | **§5.3 의 축약**: 대화를 원자 액션으로 만들어 노드를 상태 공간에서 제거 |
| 액션 반복 | 허용 | P-2(델타 공집합 제거) + 방문 집합 |

대화 전개 시 사이클 차단은 3중이다:

1. `visited` 키를 `(nodeId, delta.signature)` 로 잡는다 — 같은 노드라도 **델타가 다르면** 다른 방문이다.
   `once` 선택지를 소비하면 델타가 바뀌므로 [BP-24](24_dialogue_model.md) 의 "소모성 사이클" 이 자연스럽게 진행된다.
2. `maxDepth`(기본 32, [BP-24 §24.8.4](24_dialogue_model.md))를 넘으면 그 가지를 `truncated: true` 로 종료.
3. `dedupeBySignature` — 서로 다른 노드 경로가 같은 델타를 내면 하나로 합친다.
   대화 그래프가 아무리 복잡해도 **의미 있는 결과(outcome)의 수는 대개 2~5개**다.

`play_dialogue` 연쇄는 [BP-24 §24.7.4](24_dialogue_model.md) 대로 **꼬리 호출**이며 상한 4다.
솔버는 이를 하나의 액션 안에서 최대 4회까지 이어 붙여 전개한다.

### 5.8 반증 산출물 — 최소 반례

`UNREACHABLE` 이 났을 때 "안 된다" 만 말하면 쓸모가 없다. 생성 에이전트(D-14 3단계)가 **고칠 수 있는 형태**로 준다.

```pseudo
function explainUnreachable(q, reachableSet) -> Report:
    # 1) 막힌 지점 — 도달 집합에서 가장 멀리 간 스테이지
    blockedStage = argmax(stage.index for S in reachableSet where S.quests[q].active)
    # 2) 그 스테이지의 미충족 목표들
    unmet = [o for o in blockedStage.objectives if never satisfied in reachableSet]
    # 3) 각 목표를 조건 원자로 분해
    atoms = flatten(requiredAtoms(o) for o in unmet)          # flag/var/item/npcState/place/quest
    # 4) 도달 집합에서 한 번도 참이 되지 않은 원자
    missing = [a for a in atoms if not any(evaluate(a, S) for S in reachableSet)]
    # 5) 각 원자의 생산자 — Effect 역인덱스
    for a in missing:
        a.producers = index.producersOf(a)                     # set_flag / give_item / …
        a.diagnosis = "no_producer"        if a.producers empty
                 else "producer_unreachable" if all(not reachable(p) for p in a.producers)
                 else "producer_guarded"                        # 생산자는 닿지만 그 when 이 항상 거짓
    return Report(blockedStage, unmet, missing, witnessPrefix = shortestPathTo(blockedStage))
```

산출 JSON:

```jsonc
{
  "verdict": "unreachable",
  "quest": "quest.gen_ep1.missing_scholar",
  "mode": "optimistic",
  "blockedAt": { "stage": "s2", "stageIndex": 1, "title": "strings.q.missing_scholar.s2.title" },
  "unmetObjectives": [
    { "id": "o_deliver_note", "kind": "deliver",
      "params": { "item": "item.gen_ep1.old_note", "actor": "npc.core.lore_scholar" } }
  ],
  "missingAtoms": [
    { "kind": "has_item", "id": "item.gen_ep1.old_note",
      "diagnosis": "no_producer",
      "producers": [],
      "hint": "이 아이템을 주는 give_item Effect 가 팩 전체에 없습니다. container 앵커를 두거나 대화 노드의 onEnter 에 give_item 을 추가하세요." },
    { "kind": "flag", "id": "flag.gen_ep1.quest.missing_scholar.met_client",
      "diagnosis": "producer_guarded",
      "producers": ["dlg.gen_ep1.client_intro#n_offer"],
      "guardChain": [ {"op":"flag","id":"flag.gen_ep1.heard_rumor"} ],
      "hint": "생산자에 도달할 수는 있으나 그 진입 조건이 항상 거짓입니다. flag.gen_ep1.heard_rumor 의 생산자도 없습니다(순환 잠금 의심)." }
  ],
  "witnessPrefix": [
    {"anchor":"anchor.core.town1_gate_guard","outcome":"o0"},
    {"anchor":"anchor.core.town1_notice","outcome":"o0"}
  ],
  "search": { "algorithm": "bfs", "visited": 1204, "expanded": 1180,
              "maxDepth": 6, "elapsedMs": 412, "dominancePruned": 331 }
}
```

- **`diagnosis` 3종이 곧 수정 지시다**:
  `no_producer` → 생산자를 만들어라 / `producer_unreachable` → 길을 내라 / `producer_guarded` → 가드를 풀어라.
  F-2(순환 잠금)는 `producer_guarded` 가 **연쇄로** 나타나는 형태로 자동 진단된다.
- **R-34-13** 반례는 반드시 `witnessPrefix` 를 포함한다. 그 접두열을 `scripted` 정책으로 `SimDriver` 에 넣어
  **실제로 그 지점에서 막히는지 재생**해야 한다(R-34-7 교차 검증). 재생이 안 되면 솔버 버그다.

### 5.9 계산 예산과 타임아웃

| 예산 | 기본값 | 초과 시 |
|---|---|---|
| `--max-states` | 200,000 | `INCONCLUSIVE` |
| `--max-expansions` | 500,000 | `INCONCLUSIVE` |
| `--timeout` | 60초/퀘스트 | `INCONCLUSIVE` |
| `--max-memory` | 512MB | `INCONCLUSIVE` (프로세스가 죽기 전에 자진 중단) |
| 대화 전개 `maxDepth` | 32 ([BP-24](24_dialogue_model.md)) | 그 가지만 `truncated` |
| `play_dialogue` 연쇄 | 4 | 그 가지만 절단 |

**`INCONCLUSIVE` 의 취급 (확정)**:

| 상황 | 판정 | 게이트 |
|---|---|---|
| 낙관 모드 `INCONCLUSIVE` | 미확정 | **Hard gate 아님.** CI 경고 + 예산 2배로 1회 재시도 → 그래도 미확정이면 `needs-review` 라벨 |
| 비관 모드 `INCONCLUSIVE` | 미확정 | 경고만. 비관은 원래 soft gate |
| `greedy` 시뮬레이터가 그 퀘스트를 **실제로 완주**함 | `PROVEN_BY_WITNESS` 로 승격 | **통과** — 증인이 증명을 대신한다 |

> **핵심 원칙**: **미확정을 실패로 취급하지 않는다.** 예산 초과를 실패로 부르면 콘텐츠가 커질수록
> 게이트가 거짓 경보를 쏟아내고, 결국 사람이 게이트를 끄게 된다. 미확정은 **미확정으로 보고**하고,
> 증인(시뮬레이터 완주)이 있으면 통과시킨다. 이 규칙이 §11 의 FP-3 을 구조적으로 막는다.

---

## 6. 퍼징 — 시드 고정 랜덤 플레이

### 6.1 무엇을 찾는가

| ID | 결함 | 탐지 방법 |
|---|---|---|
| FZ-1 | 크래시 | 예상 밖 예외 → `SimStopReason.crashed`. `GameReloadException`/`SimQuitSignal` 은 제외 |
| FZ-2 | 데드락 | `noProgressLimit` 스텝 동안 상태 해시 불변 **&&** 새 앵커 방문 0 **&&** `keyWaitCount` 증가 없음 |
| FZ-3 | 프리즈(무한 대화) | `dialogue_enter` 후 `dialogue_exit` 이 `maxDepth` 안에 안 나옴 |
| FZ-4 | 계약 위반 | `assert` 발화: INV-1~7([BP-25 §2.2](25_world_state_and_save.md)), TR-1~6, "지연 효과 2개 이상"([BP-25 §4.4](25_world_state_and_save.md)), "narrative 중첩" |
| FZ-5 | 도달 불가 | 32시드 전부에서 한 번도 방문되지 않은 앵커/노드/스테이지 |
| FZ-6 | 자원 소진 | `inventory` 가 목표 아이템을 잃은 뒤 회복 경로 없음 → F-3 의 경험적 발견 |
| FZ-7 | 에셋 미스 | `MemoryAssetSource.misses` 가 비어 있지 않음(부록 A-1 류) |

### 6.2 절차

```pseudo
seeds = fixedCorpus(32) + regressionCorpus()        # 고정 32개 + 과거 실패 시드 전부
results = parallelMap(seeds, workers: 8, seed => {
    driver = SimDriver(config: fuzzConfig(seed), policy: RandomPolicy(seed), assets: pack)
    return driver.run()
})
report = aggregate(results)
for r in results where r.stop in {crashed, noProgress}:
    minimized = deltaDebug(r.trace)                  # §11 FP 처리 절차의 2단계
    writeRegressionFixture(seed, minimized)
```

- **고정 코퍼스**: 시드 32개는 **소스에 박아 둔다**(`0x00000001 … 0x0000FF00` 등 고정 수열).
  매번 새 시드를 뽑으면 CI 가 플레이키해진다. 새 시드는 야간 잡에서만 무작위로 추가한다.
- **회귀 코퍼스**: 실패한 시드는 `tools/content_cli/fixtures/regressions/seed_<hex>.json` 으로 영구 보존.
  고쳐진 뒤에도 계속 돈다.
- **델타 디버깅**: 실패 트레이스의 입력열을 이분 축소해 **최소 재현 시퀀스**를 찾는다.
  각 축소 후보를 `scripted` 로 재생해 같은 실패가 나는지 확인한다.

### 6.3 커버리지 지표와 목표치

| 지표 | 정의 | PR 게이트 | 야간 목표 |
|---|---|---|---|
| `anchorCoverage` | 방문한 앵커 / 전체 앵커 | ≥ 60% | ≥ 90% |
| `dialogueNodeCoverage` | 진입한 노드 / 전체 노드 | ≥ 50% | ≥ 75% |
| `choiceCoverage` | 선택된 선택지 / 표시 가능한 선택지 | ≥ 40% | ≥ 70% |
| `questStageCoverage` | 진입한 스테이지 / 전체 스테이지 | ≥ 70% | ≥ 95% |
| `mapCoverage` | 방문 맵 / 팩이 참조하는 맵 | 100% | 100% |
| `placeCoverage` | `visited` 에 든 place / 전체 place | ≥ 70% | ≥ 95% |
| `effectOpCoverage` | 실행된 `do` 종류 / 팩이 쓰는 `do` 종류 | ≥ 80% | 100% |
| `conditionOpCoverage` | 평가된 `op` 종류 / 팩이 쓰는 `op` 종류 | ≥ 80% | 100% |
| `crashCount` | FZ-1 건수 | **0** | **0** |
| `deadlockCount` | FZ-2 건수 | **0** | **0** |
| `assertViolations` | FZ-4 건수 | **0** | **0** |

- 커버리지 **미달은 soft gate**(경고). 크래시·데드락·계약 위반은 **hard gate**.
- 이유: 커버리지는 맵 크기·앵커 밀도에 좌우되어 콘텐츠가 늘면 자연히 떨어진다.
  숫자를 hard 로 걸면 무의미한 앵커 추가로 게임하게 된다. **크래시 0 만 절대 기준**이다.
- `greedy` 정책 1회 실행을 퍼징 결과에 **합산**한다 — 랜덤이 못 닿는 깊은 앵커를 greedy 가 채운다.

---

## 7. 골든 트레이스 회귀

### 7.1 무엇을 고정하는가

```
tools/content_cli/golden/
  <scenarioId>.script.json     # 입력 (사람이 쓴다)
  <scenarioId>.trace.json      # 골든 (도구가 만든다, 커밋한다)
  <scenarioId>.meta.json       # { contentLockHash, acceptedBy, acceptedAtCommit, note }
```

시나리오는 최소 3종을 갖춘다: `happy`(정상 완주), `refuse`(퀘스트 거절 후 재수주), `alt`(분기 선택 다름).

### 7.2 정규화 규칙 (확정)

비교 전에 양쪽 트레이스에 같은 정규화를 적용한다.

| 항목 | 처리 | 이유 |
|---|---|---|
| `meta.contentLockHash` / `packVersions` | **비교에서 제외**(별도 축으로 씀, §7.3) | 콘텐츠가 바뀌면 당연히 바뀐다 |
| 벽시계·경과시간 | 트레이스에 **애초에 없다**(TR-3) | D-08a |
| 파일 절대경로 | 레포 루트 상대경로로 치환 | 머신 독립 |
| `refresh` 호출 | 기록하지 않음(집계만) | 렌더 요청은 순수 표현 |
| `log.text` | **비교한다**. 단 `--relax-strings` 면 `stringKey` 만 비교 | 문자열 수정이 골든을 깨는 건 정상이지만, 문체 다듬기 단계에서는 시끄럽다 |
| `log` 의 줄바꿈·공백 | 연속 공백 1칸으로, 양끝 트림 | 워드랩은 표현이며 헤드리스는 랩하지 않는다(HU-1) |
| `battle` 의 데미지·HP 수치 | `--relax-numeric` 이면 제외, 기본은 비교 | BL-3 해소 전에는 제외 필수(R-34-4) |
| `state_snapshot.hash` | **비교한다** | 상태 결정론의 핵심 증거 |
| `state_snapshot` 의 집계 수치 | 비교 | 값이 다르면 해시도 다르므로 중복이지만 **진단에 유용** |
| `error.stack` | 최상위 2프레임만 남기고 절단 | 줄 번호 변동에 흔들리지 않게 |
| `seq` | **재계산**(정규화 후 0부터) | 제외된 이벤트 때문에 결번이 생기므로 |
| `step` | 비교 | 논리 시각은 결정론의 일부 |

### 7.3 의도적 변경 vs 회귀 — 2×2 판정

이 표가 이 절의 핵심이다.

| `contentLockHash` | 정규화 트레이스 | 판정 | 조치 |
|---|---|---|---|
| 동일 | 동일 | ✅ 통과 | — |
| **동일** | **다름** | ❌ **엔진 회귀 — Hard fail** | 콘텐츠가 안 바뀌었는데 동작이 바뀜. 런타임 코드의 회귀이거나 비결정성 잔존 |
| 다름 | 동일 | ✅ 통과 | 골든의 `meta.contentLockHash` 만 갱신(자동, `--refresh-hash`) |
| 다름 | 다름 | ⚠️ **승인 필요** | `hadar_content sim --accept-golden <scenario>` 로 사람이 승인. diff 요약이 PR 본문에 첨부됨 |

- **R-34-14** 골든 승인은 **명시적 커맨드**로만 가능하다. `--accept-all` 은 제공하지 않는다 —
  한 번에 다 승인하면 회귀가 섞여 들어간다.
- **R-34-15** 승인 시 `meta.json` 에 `acceptedAtCommit` 을 기록한다. 리뷰어가 "이 골든이 어느 변경에서
  바뀌었는지" 를 즉시 볼 수 있어야 한다.
- diff 출력은 **첫 불일치 이벤트 3건 + 앞뒤 2건 문맥**만 낸다. 전체 diff 는 파일로 떨군다.

```
$ hadar_content sim --golden q.fx.lost_note.happy
GOLDEN MISMATCH  q.fx.lost_note.happy   (contentLockHash 동일 → 엔진 회귀)
  seq 9  expected  menu { choices: ["맡겠소.","관심 없소."], chosen: 1 }
         actual    menu { choices: ["맡겠소.","더 듣고 싶소.","관심 없소."], chosen: 1 }
  seq 10 expected  dialogue_choice { choice: "c_accept" }
         actual    dialogue_choice { choice: "c_accept" }
  → 선택지가 하나 늘었는데 콘텐츠 해시는 그대로입니다.
    Choice.when 평가가 바뀌었을 가능성이 큽니다(ConditionEvaluator 회귀?).
  full diff: build/sim/q.fx.lost_note.happy.diff.json
exit 1
```

---

## 8. CLI 인터페이스

D-12 가 확정한 `hadar_content` 의 세 서브커맨드. 전부 `tools/content_cli/bin/hadar_content.dart`.

### 8.1 공통 인자

| 인자 | 기본 | 의미 |
|---|---|---|
| `--pack <dir>` | `hadar2026_app/assets/content` | 소스 팩 루트 |
| `--bundle <file>` | `<pack>/build/content.bundle.json` | 빌드 산출물 |
| `--format text\|json` | `text` | 출력 형식 |
| `--out <dir>` | `build/sim` | 트레이스·리포트 출력 |
| `--jobs <n>` | CPU 코어 수 | 병렬도 |
| `--quiet` / `-v` | — | 로그 수준 |

### 8.2 `hadar_content sim`

```
hadar_content sim [--scenario <id>|--all] [--policy scripted|greedy|random]
                  [--seed <int>] [--max-steps <n>] [--timeout <sec>]
                  [--golden] [--accept-golden <id>] [--refresh-hash]
                  [--relax-numeric] [--relax-strings] [--trace-format json|ndjson]
```

| 출력 | 내용 |
|---|---|
| `text` | 시나리오별 1줄 요약 + 실패 상세 |
| `json` | `{ scenarios: [ {id, stop, steps, coverage, tracePath, goldenVerdict} ], summary: {...} }` |
| 파일 | `<out>/<scenarioId>.trace.json`, 실패 시 `.diff.json` |

```
$ hadar_content sim --all
  ✅ q.fx.lost_note.happy    scripted   27 steps  goals=1/1  golden=match
  ✅ q.fx.lost_note.refuse   scripted   19 steps  goals=1/1  golden=match
  ⚠️ q.fx.lost_note.alt      greedy    412 steps  goals=1/1  golden=accept-needed
  ❌ q.gen_ep1.scholar.happy scripted   88 steps  goals=0/1  stop=noProgress
3 passed, 1 needs-review, 1 failed
exit 1
```

### 8.3 `hadar_content solve`

```
hadar_content solve [--quest <id>|--all] [--mode optimistic|pessimistic|both]
                    [--search bfs|astar] [--max-states <n>] [--max-expansions <n>]
                    [--timeout <sec>] [--no-dominance] [--verify-witness]
                    [--explain]
```

| 옵션 | 의미 |
|---|---|
| `--mode both` (기본) | 낙관·비관 둘 다 → §5.6 매트릭스로 판정 |
| `--verify-witness` (기본 on) | 증인 액션열을 `sim` 서브프로세스로 재생해 교차 검증(R-34-7) |
| `--explain` | 반증 시 `missingAtoms` 진단 전문 출력(§5.8) |

```
$ hadar_content solve --all --explain
  ✅ quest.core.tutorial          PROVEN      opt=12 states  pes=12 states   40ms
  ⚠️ quest.gen_ep1.jailed_companion MISSABLE  opt=340        pes=blocked@s3  1.2s
       비관 모드 반례: c_insult 선택 시 npc.core.jailer 가 hostile 로 고정되어 s3 진입 불가
       (퀘스트에 tags:["missable"] 이 없습니다 — 의도라면 태그를 추가하세요)
  ❌ quest.gen_ep1.missing_scholar UNREACHABLE opt=1204 states, blocked@s2
       missing: has_item item.gen_ep1.old_note  (no_producer)
       → 이 아이템을 주는 give_item Effect 가 팩 전체에 없습니다.
  ⏱ quest.gen_ep1.grand_tour     INCONCLUSIVE opt=200000 states (예산 초과)
       greedy 시뮬레이터가 완주함 → PROVEN_BY_WITNESS 로 승격
1 proven, 1 promoted, 1 missable, 1 unreachable
exit 1
```

### 8.4 `hadar_content fuzz`

```
hadar_content fuzz [--seeds <n>|--seed-list <file>] [--steps <n>]
                   [--jobs <n>] [--minimize] [--coverage-report]
                   [--fail-on crash,deadlock,assert] [--regressions <dir>]
```

```
$ hadar_content fuzz --seeds 32 --steps 20000
  32 seeds · 8 jobs · 640,000 steps total · 6m12s
  crashes 0 · deadlocks 1 · assert violations 0
  ❌ deadlock  seed=0x0000A31C  step=8412
     최소 재현 12스텝 → fixtures/regressions/seed_0000a31c.json
     증상: dlg.gen_ep1.guard_loop 에서 dialogue_exit 없이 400스텝 정체
  coverage: anchors 91% · nodes 78% · choices 71% · stages 96% · effects 100% · conditions 92%
exit 1
```

### 8.5 종료 코드 (확정, 세 커맨드 공통)

| 코드 | 의미 | CI 처리 |
|---|---|---|
| `0` | 전부 통과 | 진행 |
| `1` | 검증 실패 — 반증·크래시·데드락·골든 회귀·계약 위반 | **Hard fail** |
| `2` | 미확정 — 예산/타임아웃 초과만 있고 실패는 없음 | 경고 + `needs-review` 라벨. 머지 차단 안 함 |
| `3` | 도구 내부 오류 — 번들 파싱 실패, 하네스 크래시, 서브프로세스 기동 실패 | **Hard fail**(도구를 먼저 고쳐야 함) |
| `4` | 사용법 오류 — 인자 오류, 시나리오 id 없음 | **Hard fail** |
| `5` | 승인 필요 — 골든 diff 가 콘텐츠 변경에서 비롯됨 | 리뷰 요청. 승인 후 재실행 |

---

## 9. 테스트 픽스처 — 최소 재현 월드

하네스가 옳게 동작하는지는 **하네스 자신을 테스트**해야 알 수 있다.
아래 픽스처는 `hadar2026_app/test/harness/fixtures/` 에 두고, `harness_self_test.dart` 가 이것으로 돈다.
동시에 [BP-91](91_appendix_worked_example.md) 의 축소판이며, 솔버·시뮬레이터·골든의 공통 스모크 대상이다.

**구성**: 5×5 맵 1개 · NPC 2명 · 푯말 1개 · 포탈 1개 · 아이템 1개 · 퀘스트 1개(스테이지 2개) · 대화 2개.

### 9.1 맵 — `assets/maps/FX_ROOM.json`

```jsonc
// 5x5. RPG Maker MV 6레이어, size=25 이므로 data 길이 150.
// layer0(ixTile, 0x600 감산 후): 전부 10(→ move). 단 (4,4)=64(→ enter, 포탈 타일)
// layer3(ixObj1): (1,1)=128, (3,1)=128 (→ talk),  (2,3)=112 (→ sign)
// 나머지 레이어 전부 0.
{
  "width": 5,
  "height": 5,
  "displayName": "하네스 시험실",
  "data": [
    1546,1546,1546,1546,1546, 1546,1546,1546,1546,1546, 1546,1546,1546,1546,1546,
    1546,1546,1546,1546,1546, 1546,1546,1546,1546,1600,

    0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0,

    0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0,

    0,0,0,0,0, 0,128,0,128,0, 0,0,0,0,0, 0,0,112,0,0, 0,0,0,0,0,

    0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0,

    0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0
  ],
  "events": []
}
```

> **좌표 검산**: 인덱스 = `y*5 + x`. `(1,1)` → 6, `(3,1)` → 8, `(2,3)` → 17, `(4,4)` → 24.
> layer3 은 `3*25=75` 부터 시작하므로 위 배열의 4번째 줄(75..99)에서 6·8·17번째가 각각 128·128·112다.
> layer0 의 24번째가 1600 → `1600-0x600 = 64` → `_getTileAction(64)` = `enter`.
> `events` 가 비었으므로 이 맵은 **레거시 JSON 티어를 전혀 쓰지 않는다** — 콘텐츠 티어만 검증된다.

### 9.2 맵 인덱스 — `assets/maps/MapInfos.json` (픽스처 전용)

```json
[
  null,
  { "id": 900, "name": "FX_ROOM", "json": "FX_ROOM.json" }
]
```

> **의도적으로 `json` 필드를 명시한다.** 부록 D-1 이 밝힌 대로, 이름이 인덱스에 등록되면
> `Map900.json` 으로 해석되어 **존재하지 않는 파일**을 읽는다. 픽스처는 T-22-1(명시 `json` 필드)을
> 선제 적용해 그 함정을 피하고, 동시에 **`json` 필드 경로가 실제로 동작함을 회귀 테스트한다**
> (`map_navigation_test.dart` 의 "honours the explicit json and cm2 overrides" 와 같은 계약).
> `cm2` 필드는 **없다** — 부록 A-1 의 "존재하지 않는 cm2 강제 부여" 가 고쳐졌음을 함께 고정한다.

### 9.3 팩 매니페스트 — `assets/content/pack.json`

```json
{
  "id": "fx",
  "version": "0.1.0",
  "schemaVersion": 1,
  "title": "하네스 자기 테스트 팩",
  "dependsOn": [],
  "generatedBy": "hand",
  "retiredIds": []
}
```

### 9.4 아이템 — `assets/content/items/items.json`

```json
{
  "schemaVersion": 1,
  "pack": "fx",
  "items": [
    { "id": "item.fx.old_note", "name": "str.fx.item.old_note.name",
      "description": "str.fx.item.old_note.desc", "stackable": false, "questItem": true }
  ]
}
```

### 9.5 액터 — `assets/content/actors/`

```json
// npc.fx.client.json
{ "schemaVersion": 1, "pack": "fx",
  "id": "npc.fx.client", "name": "str.fx.npc.client.name",
  "states": ["neutral", "grateful"], "defaultState": "neutral",
  "defaultDialogue": "dlg.fx.client" }
```

```json
// npc.fx.scholar.json
{ "schemaVersion": 1, "pack": "fx",
  "id": "npc.fx.scholar", "name": "str.fx.npc.scholar.name",
  "states": ["neutral"], "defaultState": "neutral",
  "defaultDialogue": "dlg.fx.scholar" }
```

### 9.6 앵커 — `assets/content/anchors/FX_ROOM.json`

```json
{
  "schemaVersion": 1,
  "pack": "fx",
  "map": "FX_ROOM",
  "anchors": [
    { "id": "anchor.fx.client",  "kind": "actor", "actor": "npc.fx.client",
      "x": 1, "y": 1, "facing": "down" },
    { "id": "anchor.fx.scholar", "kind": "actor", "actor": "npc.fx.scholar",
      "x": 3, "y": 1, "facing": "down" },
    { "id": "anchor.fx.notice",  "kind": "sign",
      "lines": ["str.fx.sign.notice"], "x": 2, "y": 3 },
    { "id": "anchor.fx.exit",    "kind": "portal",
      "to": { "map": "FX_ROOM", "x": 2, "y": 3, "facing": "down" },
      "x": 4, "y": 4,
      "when": { "op": "quest_state", "id": "quest.fx.lost_note", "state": "completed" },
      "lockedMessage": "str.fx.portal.locked" }
  ]
}
```

> 포탈의 `when` 이 "퀘스트 완료" 이므로, **솔버가 `guard` 간선을 다루는지**(§4.3.1 5번, §5.2 A-7)를
> 이 하나로 검증한다. 목적지를 같은 맵으로 둔 것은 픽스처를 단일 맵으로 유지하기 위함이다.

### 9.7 퀘스트 — `assets/content/quests/quest.fx.lost_note.json`

```json
{
  "schemaVersion": 1,
  "id": "quest.fx.lost_note",
  "pack": "fx",
  "title": "str.fx.q.lost_note.title",
  "summary": "str.fx.q.lost_note.summary",
  "act": 1,
  "tier": 1,
  "giver": "npc.fx.client",
  "prerequisites": { "op": "true" },
  "stages": [
    {
      "id": "s1", "index": 0,
      "title": "str.fx.q.lost_note.s1.title",
      "journal": "str.fx.q.lost_note.s1.journal",
      "completion": "all",
      "objectives": [
        { "id": "o_get_note", "kind": "acquire",
          "params": { "item": "item.fx.old_note", "count": 1 } }
      ],
      "onEnter": [], "onExit": [],
      "next": "s2"
    },
    {
      "id": "s2", "index": 1,
      "title": "str.fx.q.lost_note.s2.title",
      "journal": "str.fx.q.lost_note.s2.journal",
      "completion": "all",
      "objectives": [
        { "id": "o_deliver", "kind": "deliver",
          "params": { "item": "item.fx.old_note", "actor": "npc.fx.client", "count": 1 } }
      ],
      "onEnter": [], "onExit": [],
      "next": "complete"
    }
  ],
  "onComplete": [ { "do": "set_npc_state", "id": "npc.fx.client", "state": "grateful" } ],
  "onFail": [],
  "rewards": [ { "do": "add_gold", "delta": 50 } ],
  "journal": { "s1": "str.fx.q.lost_note.s1.journal", "s2": "str.fx.q.lost_note.s2.journal" },
  "tags": ["fixture"]
}
```

### 9.8 대화 — `assets/content/dialogue/`

```json
// dlg.fx.client.json
{
  "schemaVersion": 1,
  "id": "dlg.fx.client",
  "pack": "fx",
  "speaker": "npc.fx.client",
  "entry": [
    { "when": { "op": "quest_state", "id": "quest.fx.lost_note", "state": "completed" },
      "go": "n_thanks" },
    { "when": { "op": "and", "args": [
        { "op": "quest_stage", "id": "quest.fx.lost_note", "stage": "s2" },
        { "op": "has_item", "id": "item.fx.old_note", "count": 1 } ] },
      "go": "n_turn_in" },
    { "when": { "op": "quest_state", "id": "quest.fx.lost_note", "state": "active" },
      "go": "n_waiting" },
    { "when": { "op": "true" }, "go": "n_offer" }
  ],
  "nodes": {
    "n_offer": {
      "id": "n_offer",
      "lines": ["str.fx.dlg.client.offer"],
      "onEnter": [],
      "choices": [
        { "text": "str.fx.choice.accept", "go": "n_accepted",
          "effects": [ { "do": "start_quest", "id": "quest.fx.lost_note" } ] },
        { "text": "str.fx.choice.decline", "go": "end" }
      ]
    },
    "n_accepted": { "id": "n_accepted", "lines": ["str.fx.dlg.client.accepted"],
                    "onEnter": [], "next": "end" },
    "n_waiting":  { "id": "n_waiting",  "lines": ["str.fx.dlg.client.waiting"],
                    "onEnter": [], "next": "end" },
    "n_turn_in": {
      "id": "n_turn_in",
      "lines": ["str.fx.dlg.client.turn_in"],
      "onEnter": [],
      "choices": [
        { "text": "str.fx.choice.hand_over", "go": "n_thanks",
          "effects": [
            { "do": "take_item", "id": "item.fx.old_note", "count": 1 },
            { "do": "complete_quest", "id": "quest.fx.lost_note" }
          ] },
        { "text": "str.fx.choice.not_yet", "go": "end" }
      ]
    },
    "n_thanks": { "id": "n_thanks", "lines": ["str.fx.dlg.client.thanks"],
                  "onEnter": [], "next": "end" }
  }
}
```

```json
// dlg.fx.scholar.json
{
  "schemaVersion": 1,
  "id": "dlg.fx.scholar",
  "pack": "fx",
  "speaker": "npc.fx.scholar",
  "entry": [
    { "when": { "op": "and", "args": [
        { "op": "quest_stage", "id": "quest.fx.lost_note", "stage": "s1" },
        { "op": "not", "arg": { "op": "has_item", "id": "item.fx.old_note" } } ] },
      "go": "n_give" },
    { "when": { "op": "true" }, "go": "n_smalltalk" }
  ],
  "nodes": {
    "n_give": {
      "id": "n_give",
      "lines": ["str.fx.dlg.scholar.give"],
      "onEnter": [ { "do": "give_item", "id": "item.fx.old_note", "count": 1 } ],
      "next": "end"
    },
    "n_smalltalk": { "id": "n_smalltalk", "lines": ["str.fx.dlg.scholar.smalltalk"],
                     "onEnter": [], "next": "end" }
  }
}
```

### 9.9 문자열 — `assets/content/strings/ko.json`

```json
{
  "str.fx.npc.client.name": "의뢰인",
  "str.fx.npc.scholar.name": "학자",
  "str.fx.item.old_note.name": "낡은 기록",
  "str.fx.item.old_note.desc": "잉크가 번진 양피지 한 장.",
  "str.fx.sign.notice": "이 방은 시험용이다. 아무것도 믿지 마라.",
  "str.fx.portal.locked": "문은 굳게 잠겨 있다.",
  "str.fx.q.lost_note.title": "잃어버린 기록",
  "str.fx.q.lost_note.summary": "의뢰인이 학자에게 맡긴 기록을 되찾아 준다.",
  "str.fx.q.lost_note.s1.title": "기록을 찾는다",
  "str.fx.q.lost_note.s1.journal": "학자에게서 낡은 기록을 받아야 한다.",
  "str.fx.q.lost_note.s2.title": "기록을 전한다",
  "str.fx.q.lost_note.s2.journal": "의뢰인에게 낡은 기록을 건네야 한다.",
  "str.fx.dlg.client.offer": "며칠 전 학자에게 맡긴 기록이 있소. 되찾아 주겠소?",
  "str.fx.dlg.client.accepted": "고맙소. 학자는 저 건너에 있소.",
  "str.fx.dlg.client.waiting": "아직인가 보구려.",
  "str.fx.dlg.client.turn_in": "그것이 내 기록이오?",
  "str.fx.dlg.client.thanks": "이 은혜는 잊지 않겠소.",
  "str.fx.dlg.scholar.give": "아, 그 기록 말이오. 여기 있소.",
  "str.fx.dlg.scholar.smalltalk": "요즘은 통 손님이 없구려.",
  "str.fx.choice.accept": "맡겠소.",
  "str.fx.choice.decline": "관심 없소.",
  "str.fx.choice.hand_over": "여기 있소.",
  "str.fx.choice.not_yet": "아직이오."
}
```

### 9.10 이 픽스처가 고정하는 것

| # | 자기 테스트 | 고정 대상 |
|---|---|---|
| S-01 | `MemoryAssetSource` 로 팩+맵이 파일시스템 없이 로드된다 | §3.3, `map_navigation_test.dart` 선례 확장 |
| S-02 | `HeadlessUiHost` 의 12개 메서드가 전부 호출되고 트레이스에 남는다 | §3.2 |
| S-03 | `(2,3)→(2,2)→(2,1)→←` 로 `anchor.fx.client` 와 상호작용된다 | P-1 이관 결과(§2.2), `interact` 간선(§4.3.1) |
| S-04 | `scripted` 해피패스가 27스텝 안에 `completed` 로 끝난다 | §4.2, §3.5 |
| S-05 | 같은 스크립트를 2회 돌리면 트레이스 해시가 같다 | 결정론(§2.4), BP-27 §9.4 |
| S-06 | `greedy` 가 스크립트 없이 같은 퀘스트를 완주한다 | §4.3 전체 |
| S-07 | 솔버가 `PROVEN` 을 내고 witness 를 `sim` 으로 재생하면 성공한다 | R-34-7 교차 검증 |
| S-08 | `dlg.fx.scholar` 의 `give_item` 을 지우면 솔버가 `no_producer` 로 반증한다 | §5.8, F-2/F-3 진단 |
| S-09 | `anchor.fx.scholar` 를 `(3,0)` 로 옮기고 주변을 막으면 `producer_unreachable` 이 난다 | F-1, §4.3.1 `markUnreachableInteractive` |
| S-10 | 포탈 `when` 이 거짓인 동안 region 이 나뉘고, 완료 후 병합된다 | A-7, guard 간선 |
| S-11 | `random` 시드 32개에서 크래시·데드락 0 | §6 |
| S-12 | 골든 트레이스가 콘텐츠 무변경 시 바이트 동일하다 | §7.3 2×2 표 |

---

## 10. 성능 목표

### 10.1 단위 목표

| 작업 | p50 | p95 | 상한(하드) | 근거 |
|---|---|---|---|---|
| 솔버: 퀘스트 1개 (`--mode both`) | 0.5s | 8s | 60s | §5.9. 픽스처는 40ms |
| 솔버: 상태 확장 1회 | 0.2ms | 1ms | — | 대화 전개가 지배적. 대화 노드 10개 기준 |
| 시뮬레이터: `scripted` 1시나리오 | 6s | 12s | 60s | `flutter test` 프로세스 기동 ~3.5s 가 고정비 |
| 시뮬레이터: `greedy` 1퀘스트 | 15s | 40s | 180s | BFS 경로 재계산 비용 포함 |
| 퍼징: 1시드 20,000스텝 | 40s | 90s | 300s | |
| 트레이스 정규화 + 비교 1건 | 30ms | 100ms | — | 이벤트 500건 기준 |

### 10.2 배치 목표

| 배치 | 규모 | 목표 | 방법 |
|---|---|---|---|
| `solve --all` | 퀘스트 50개 | **3분** | 8워커 병렬. 퀘스트 간 독립이므로 선형 확장 |
| `sim --all` (골든) | 시나리오 30개 | **4분** | `flutter test` 프로세스를 **재사용**한다 — 30번 띄우면 기동비만 105초 |
| `fuzz` (PR) | 4시드 × 2,000스텝 | **2분** | |
| `fuzz` (야간) | 32시드 × 20,000스텝 | **20분** | |

- **R-34-16** `sim --all` 은 **한 `flutter test` 프로세스 안에서 여러 시나리오를 순차 실행**한다.
  시나리오마다 `HDHosts().reset()` + 각 싱글턴의 `reset()` 으로 격리한다.
  이것이 성능 목표를 지키는 유일한 방법이며, 동시에 **모든 싱글턴이 `reset()` 을 가져야 하는 이유**다(D-11).

### 10.3 CI 예산

| 잡 | 트리거 | 예산 | 게이트 |
|---|---|---|---|
| `content-validate` (L1~L4) | 모든 PR | 1분 | Hard ([BP-33](33_validation_and_lint.md)) |
| `content-solve` | 콘텐츠 변경 PR | **3분** | Hard(`UNREACHABLE`), Soft(`MISSABLE`/`INCONCLUSIVE`) |
| `content-sim-golden` | 콘텐츠 **또는 런타임** 변경 PR | **4분** | Hard(엔진 회귀), 승인 필요(콘텐츠 변경) |
| `content-fuzz-smoke` | 모든 PR | **2분** | Hard(크래시/데드락) |
| `content-fuzz-full` | 야간 · 릴리스 전 | 20분 | 리포트만 |

**PR 총 예산 10분** — 기존 `hadar2026_app`(analyze+test) 잡과 병렬로 돈다. 잡 배치는 [BP-35](35_ci_and_build.md) 소관.

- **R-34-17** `content-sim-golden` 은 **런타임 코드 변경에도** 돈다. §7.3 의 "콘텐츠 동일 + 트레이스 다름 = 엔진 회귀"
  는 런타임 PR 에서만 의미가 있기 때문이다.

---

## 11. 한계와 오탐

### 11.1 솔버가 증명하지 못하는 것

| # | 증명 못 하는 것 | 왜 | 대안 |
|---|---|---|---|
| L-1 | **플레이어가 목표를 찾아낼 수 있는가** | 솔버는 전지적이다. 앵커 위치를 전부 안다. 실제 플레이어는 저널·대사의 힌트로만 안다 | `--knowledge-gated` 실험 모드(§11.2). v1 은 검수 에이전트(D-14 7단계)가 본다 |
| L-2 | **전투 난이도가 적절한가** | 솔버는 "승리 가정" 으로 추상화한다. HP·레벨·장비의 실제 밸런스는 보지 않는다 | [BP-23 §23.9.2](23_quest_model.md) 의 밸런스 린트 + 사람 플레이테스트 |
| L-3 | **서사가 재미있는가 / 톤이 맞는가** | 기계가 답할 질문이 아니다 | 검수 에이전트 루브릭([BP-37](37_prompt_contracts.md)) |
| L-4 | **텍스트가 자연스러운가 / 오탈자** | 트레이스는 stringKey 를 다룬다 | [BP-43](43_content_style_guide.md) 린트 |
| L-5 | **백트래킹 피로도** | 최단 경로 길이는 알지만 "지루한가" 는 모른다 | 소프트 지표: witness 경로의 총 이동 칸 수를 리포트에 낸다 |
| L-6 | **조작 실수로 인한 막힘** | 정책은 실수하지 않는다 | 비관 모드가 일부 대신한다(불리한 분기 강제) |
| L-7 | **성능·프레임드랍** | 헤드리스에는 렌더가 없다 | 별도 관심사 |
| L-8 | **추상화 밖의 상태가 만드는 잠금** | A-9 로 제외한 것(HP·food 고갈 등)이 실제로는 막을 수 있다 | 퍼징(§6)이 경험적으로 잡는다. 발견되면 A-9 를 수정 |

> **L-1(전지성 편향)이 가장 위험하다.** 솔버가 `PROVEN` 이라고 해도
> "학자가 어디 있는지 아무도 말해주지 않는" 퀘스트는 사람에게 클리어 불가다.
> 이것을 완화하는 소프트 지표를 §11.2 로 둔다.

### 11.2 `--knowledge-gated` (실험, v1 은 지표만)

액터/장소를 **알게 된 뒤에만** 목적지 후보에 넣는다.

```pseudo
known = set()
on dialogue line rendered:  known += actorIdsMentioned(line) + placeIdsMentioned(line)
on anchor visited:          known += anchor.actor / anchor.place
on journal entry added:     known += idsMentioned(entryKey)
resolveSites(o) = resolveSites(o) ∩ knownOrAdjacent(known)
```

`known` 판정이 문자열 매칭에 의존하므로 v1 에서는 **hard gate 로 쓰지 않는다.**
대신 `hintCoverage` = (목표 사이트 중 저널/대사에서 언급된 것의 비율)을 리포트에 낸다. 목표치 **≥ 80%**.

### 11.3 오탐 3종

| ID | 오탐 | 증상 | 판별 |
|---|---|---|---|
| **FP-1** | 하네스 버그 | 실제로는 되는데 시뮬레이터에서 안 됨 | §9 자기 테스트(S-01~S-12) 가 통과하는지 먼저 본다. 실패하면 **콘텐츠가 아니라 하네스 문제** |
| **FP-2** | 추상화 과다 | 솔버가 `UNREACHABLE` 인데 사람은 깬다 / 솔버 witness 가 재생 안 됨 | **R-34-7 교차 검증이 이걸 잡는다.** witness 재생 실패 = 추상화 결함. A-1~A-8 중 어느 규칙이 정보를 버렸는지 이분 탐색 |
| **FP-3** | 미확정을 실패로 오독 | 큰 팩에서 예산 초과가 실패로 보고됨 | §5.9 가 **판정을 분리**해 구조적으로 차단. 종료 코드 2 는 머지를 막지 않는다 |

### 11.4 오탐 처리 절차 (5단계, 확정)

```
1. 재생   실패 트레이스를 scripted 로 그대로 재생한다. 재생이 안 되면 → 비결정성 잔존(BL-3) → BP-27 §9 로
2. 최소화 델타 디버깅으로 입력열을 이분 축소한다. 최소 재현이 3스텝이면 대개 하네스 버그(FP-1)
3. 분류   자기 테스트 통과 여부 + witness 재생 여부로 FP-1/FP-2/FP-3/진짜 결함 을 가른다
4. 억제   진짜 결함이 아니면 suppression 에 등록한다 — 단 **만료 조건 필수**
5. 기록   suppression 은 이슈 번호와 만료를 갖는다. 만료된 억제는 CI 가 hard fail 시킨다
```

```jsonc
// tools/content_cli/suppressions.json
{
  "suppressions": [
    { "id": "SUP-001",
      "scope": "solve", "target": "quest.gen_ep1.grand_tour",
      "verdict": "INCONCLUSIVE",
      "reason": "상태 공간 34만 — A-2 var 버킷화 미적용 구간. T-34-21 에서 해소 예정",
      "issue": "#412",
      "expiresAtCommitCount": 200,        // 또는 expiresOnVersion: "0.4.0"
      "addedBy": "yk.ahn", "addedAtCommit": "9267416" }
  ]
}
```

- **R-34-18** 만료 없는 suppression 은 금지한다. CI 가 스키마로 강제한다.
  만료된 억제는 **경고가 아니라 실패**다 — 그래야 억제 목록이 썩지 않는다.
- **R-34-19** suppression 은 `verdict` 단위로만 건다. "이 퀘스트의 검증 전체를 끄기" 는 불가능하다.

---

## 12. 이 장이 확정한 것 / 다음 장으로 넘긴 것 / 열린 질문

### 12.1 확정한 것

| ID | 확정 |
|---|---|
| R-34-1 | 콘텐츠 hard gate 에 L5(실행 가능성)를 포함한다. L1~L4 통과는 필요조건일 뿐 |
| R-34-2 | 시뮬레이터·솔버는 런타임과 **같은 `Condition`/`Effect` 평가기**를 쓴다. 재구현 금지 |
| R-34-3 | 모드 게이트는 입력 소스가, 규칙 게이트는 `PartyMovementController` 가 소유한다 |
| R-34-4 | 결정론(BL-3) 해소 전에는 골든 비교에서 수치를 제외한다(`--relax-numeric`) |
| R-34-5 | `hadar_content sim` 은 `flutter test` 를 서브프로세스로 호출하고 트레이스를 회수한다 |
| R-34-6 | `lib/domain/content/` 는 `flutter/foundation.dart` 조차 import 하지 않는다(순수 Dart) |
| R-34-7 | 솔버의 witness 는 반드시 `SimDriver` 로 재생해 교차 검증한다. 재생 실패 = 솔버 버그 |
| R-34-8 | `MemoryAssetSource.misses` 를 트레이스에 싣는다(부록 A-1 류의 조용한 실패 방지) |
| R-34-9 | 트레이스는 NDJSON 스트리밍을 지원한다(크래시해도 직전까지 남는다) |
| R-34-10 | `scripted` 의 메뉴 응답은 **라벨 매칭이 기본**. 인덱스 하드코딩은 린트 경고 |
| R-34-11 | 상태 해시는 모든 집합·맵을 정렬 후 직렬화한다 |
| R-34-12 | 방문 집합은 해시 충돌 시 전체 비교한다(거짓 `UNREACHABLE` 방지) |
| R-34-13 | 반례는 `witnessPrefix` 를 포함하고 재생 가능해야 한다 |
| R-34-14 | 골든 승인은 시나리오 단위 명시 커맨드로만. `--accept-all` 없음 |
| R-34-15 | 골든 `meta.json` 에 `acceptedAtCommit` 기록 |
| R-34-16 | `sim --all` 은 한 프로세스에서 시나리오를 순차 실행하고 싱글턴 `reset()` 으로 격리한다 |
| R-34-17 | `content-sim-golden` 잡은 **런타임 변경 PR 에서도** 돈다 |
| R-34-18 | suppression 에는 만료가 필수. 만료된 억제는 hard fail |
| R-34-19 | suppression 은 `verdict` 단위. 검증 전체 끄기는 불가 |
| — | **선결 과제 확정**: P-1(이동·상호작용 추출, 12개 책임 이관, `PartyMovementHost` 재정의), P-2(`UiHost.requestQuit`, `exit(0)` 3곳 제거), P-3(BP-27 §9 의 DT-1~DT-4) |
| — | **하네스 4클래스 확정**: `HeadlessUiHost`(12메서드), `MemoryAssetSource`, `HeadlessMovementHost`(3메서드), `SimDriver`(+`SimConfig`/`SimResult`/`SimStopReason` 7값) |
| — | **`SimTrace` v1 확정**: 이벤트 kind 22종 닫힌 집합, 불변식 TR-1~6, `meta` 필드 |
| — | **정책 3종 확정**: `scripted`(라벨 매칭), `greedy`(MapGraph + 목적지 도출표 9종), `random`(가중치·편향 완화 2종) |
| — | **상태 추상화 A-0~A-9 확정**. 지배 원칙: "콘텐츠가 조건으로 읽는 것만 상태다" |
| — | **판정 5값 확정**: `PROVEN` / `PROVEN_BY_WITNESS` / `MISSABLE` / `UNREACHABLE` / `INCONCLUSIVE` |
| — | **종료 코드 6값 확정**(0/1/2/3/4/5) |
| — | **골든 2×2 판정표 확정**(콘텐츠 해시 × 트레이스) |
| — | **픽스처 확정**: 5×5 맵 · NPC 2 · 퀘스트 1 · 대화 2 · 자기 테스트 12건 |

### 12.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| 정적 린트 규칙 코드(`QV-*`/`DV-*`)와 이 장의 판정을 어떻게 한 리포트로 합칠지 | [BP-33](33_validation_and_lint.md) |
| CI 잡 정의(YAML), 캐시 전략, `flutter test` 프로세스 재사용의 구현, 콘텐츠 해시 산출 | [BP-35](35_ci_and_build.md) |
| 8단계 파이프라인의 6단계(`sim`)가 실패했을 때 3단계(`draft`)로 되돌리는 재시도 정책 | [BP-32](32_generation_harness.md) |
| 반례 리포트를 LLM 수정 지시로 바꾸는 프롬프트 계약 | [BP-37](37_prompt_contracts.md) |
| `hintCoverage`(§11.2) 를 검수 루브릭 항목으로 삼을지 | [BP-37](37_prompt_contracts.md) |
| `PartyMovementController` 추출의 태스크 순서·추정치(T-34-1 ~ T-34-8) | [BP-51](51_task_breakdown.md) |
| RK-34-1 ~ RK-34-4 의 리스크 등록 | [BP-52](52_risks.md) |
| 커버리지·성능 목표치를 수용 기준으로 승격 | [BP-53](53_acceptance_criteria.md) |
| 픽스처를 엔드투엔드 예제로 확장 | [BP-91](91_appendix_worked_example.md) |
| `SimTrace` JSON Schema 원문 | [BP-90](90_appendix_schemas.md) |

### 12.3 열린 질문

| ID | 질문 | 현재 입장 |
|---|---|---|
| Q-34-1 | `flutter test` 서브프로세스 호출(R-34-5)은 CLI 를 두 갈래로 만든다. `domain/content` 를 순수 Dart 로 지키면 **시뮬레이터도** 순수 Dart 로 만들 수 있을까? `application/` 이 `ChangeNotifier` 를 버리고 자체 리스너를 쓰면 가능하다 | v1 은 서브프로세스. `application/content/` 만이라도 순수 Dart 를 유지하면 장래에 통합 가능 |
| Q-34-2 | 비관 모드(`∀`)의 상태 공간은 낙관의 몇 배인가? `chance` op 가 많은 팩에서 예산을 초과하지 않을까 | 실측 필요. 초과하면 비관을 "목표 퀘스트가 참조하는 `chance` 만" 으로 좁힌다 |
| Q-34-3 | P-1 추출 중 회귀를 어떻게 확인하나 — 추출 **전에는** 하네스가 없어 골든을 뜰 수 없다 | T-34-4 의 통합 테스트 6종을 먼저 쓰고 그것으로 판정. 대안: 추출을 2단계로 나눠 1단계에서 `PartyMovementController` 를 만들되 스프라이트가 그것을 호출만 하게 하고, 2단계에서 폴링을 제거 |
| Q-34-4 | A-7(위치 = 연결 성분)이 `reach` 목표의 **정확한 좌표**를 잃는다. 같은 성분 안의 특정 칸에만 있는 목표는? | 성분 안에서는 항상 도달 가능하므로 손실이 없다. 단 `radius`가 있는 `reach` 는 별도 검사 필요 — 열린 채로 둔다 |
| Q-34-5 | `clear_flag` 가 있는 팩에서 지배 가지치기를 끄면(§5.5 주의) 예산이 얼마나 늘어나나 | 실측 필요. 심하면 "목표 퀘스트가 쓰는 flag 에는 `clear_flag` 금지" 를 린트 규칙으로 올린다([BP-33](33_validation_and_lint.md)) |
| Q-34-6 | 골든 트레이스를 커밋하면 레포가 얼마나 커지나(시나리오 30개 × 이벤트 500건) | 시나리오당 ~80KB 추정, 총 2.4MB. NDJSON + gzip 커밋을 검토 |
| Q-34-7 | `random` 정책이 메뉴에서 "게임 종료"를 고르면 `SimQuitSignal` 로 시나리오가 조기 종료된다. 퍼징 효율을 위해 그 항목만 제외해야 하나? | 제외하면 종료 경로의 버그를 못 잡는다. 절충: 5% 확률로만 허용하고, 종료 후 **같은 시드로 재시작**해 남은 스텝 예산을 소진 |
| Q-34-8 | 전투를 낀 시나리오에서 `WorldRng` 스트림 분기(BP-27 §9.2 `stream(label)`)를 어떻게 트레이스에 남길까 | `battle` 이벤트에 `rngCursorBefore/After` 를 넣는 안. 결정 보류 |
