# 규범적 설계 결정 (NORMATIVE DECISIONS) — 제작 에이전트 필독

> 이 파일은 **이미 확정된 결정**이다. 제작 에이전트는 이 결정을 전제로 문서를 **확장·상세화**하되
> 결정 자체를 바꾸지 말 것. 결정에 결함이 보이면 문서 본문에 "열린 질문(Open Question)" 으로 남기고
> 결정은 유지할 것. 모든 문서가 이 결정을 공유해야 SSoT 가 성립한다.

---

## D-01 3분할 파이프라인 (Authoring / Build / Runtime)

- **Authoring (오프라인, AI 사용)**: 사람+LLM 에이전트가 콘텐츠 소스를 만든다. 배포 전에만 동작.
- **Build (오프라인, AI 미사용)**: 소스를 검증·링크·최적화해 런타임 번들로 굽는다. 결정론적.
- **Runtime (게임 실행, AI 절대 없음)**: 구워진 번들을 결정론적으로 해석만 한다.
- 런타임에 LLM 호출·네트워크·비결정 난수 도입 금지. 난수는 시드 기반만 허용.
- 이 경계는 기획서 전체의 대전제다. 모든 장이 자신이 어느 구획에 속하는지 명시할 것.

## D-02 콘텐츠의 1차 표현은 "선언적 데이터"

- AI 생성 타깃은 **cm2 스크립트도 Dart 클래스도 아니고 JSON 데이터**다.
- 근거: cm2 는 미등록 함수가 조용히 0을 반환해 오분기하고(GROUND_TRUTH §9), 루프·함수가 없고,
  맵 전환 시 전역이 초기화된다. 정적 검증이 불가능한 언어는 LLM 생성물의 검수 대상으로 부적합하다.
- cm2/네이티브 Dart 스크립트는 **레거시 및 특수 연출용으로 존속**하되 신규 AI 콘텐츠는 데이터로만 만든다.

## D-03 Content Pack — 디렉토리 레이아웃 (확정)

소스(사람/AI 가 읽고 쓰는 것):

```
hadar2026_app/assets/content/
  pack.json                  # 매니페스트
  world/
    lore.json                # 세계관 축, 연대기
    factions.json
    places.json              # 장소(맵과 1:N), 지역 톤
  actors/
    <actor_id>.json          # NPC 1인 1파일
  items/
    items.json               # 아이템 카탈로그
  quests/
    <quest_id>.json          # 퀘스트 1개 1파일
  dialogue/
    <dialogue_id>.json       # 대화 그래프 1개 1파일
  anchors/
    <MAPNAME>.json           # 맵별 앵커: 엔티티 ↔ 좌표 바인딩
  strings/
    ko.json                  # 모든 표시 문자열 (문자열 키 → 텍스트)
```

빌드 산출물(런타임이 읽는 것, 생성물이므로 gitignore 하지 않고 커밋 — 재현 가능해야 함):

```
hadar2026_app/assets/content/build/
  content.bundle.json        # 전 콘텐츠 병합 + 정규화
  content.index.json         # 트리거 인덱스(맵/좌표/이벤트 → 핸들러), 역참조 인덱스
  content.lock.json          # 소스 해시, 스키마 버전, 빌드 결정론 증빙
```

- `pack.json` 필수 필드: `id`, `version`(semver), `schemaVersion`(정수), `title`, `dependsOn`(pack id 배열), `generatedBy`.
- 팩은 **합성 가능**해야 한다. 기본 팩 `core` + 생성 팩 `gen_ep1` 처럼 겹쳐 쓰는 것을 전제로 설계.

## D-04 ID 체계 (확정)

- 형식: `<type>.<pack>.<slug>` — 전부 소문자 snake_case. 예:
  `npc.core.lore_gate_guard`, `quest.gen_ep1.missing_scholar`, `item.core.rusty_key`,
  `dlg.gen_ep1.guard_intro`, `place.core.lore_castle`, `anchor.core.town1_gate_guard`
- 상태 키: `flag.<pack>.<domain>.<name>`, `var.<pack>.<domain>.<name>`.
  예: `flag.gen_ep1.quest.missing_scholar.met_client`, `var.core.party.reputation_lore`
- ID 는 **불변**이며 재사용 금지. 삭제된 ID 는 `pack.json#retiredIds` 에 남긴다.
- 레거시 정수 플래그(0~255)와의 다리: 빌드가 `content.lock.json` 에 `legacyFlagMap: {flagId: intIndex}` 를 생성.
  신규 콘텐츠는 정수를 직접 쓰지 않는다.
- 슬러그 규칙: 영문 소문자/숫자/언더스코어, 3~48자, 숫자로 시작 금지.

## D-05 Condition / Effect DSL (확정, 닫힌 집합)

**Condition** — 단일 JSON 객체, `op` 필드로 분기. 중첩 가능. 부작용 없음. 순수 함수.

```json
{"op":"and","args":[
  {"op":"flag","id":"flag.gen_ep1.quest.missing_scholar.met_client"},
  {"op":"not","arg":{"op":"has_item","id":"item.core.rusty_key"}},
  {"op":"var_cmp","id":"var.core.party.reputation_lore","cmp":">=","value":10}
]}
```

허용 op (v1 확정):
`true`, `false`, `and`, `or`, `not`,
`flag`(id), `var_cmp`(id, cmp ∈ {"==","!=","<","<=",">",">="}, value:int),
`has_item`(id, count?=1), `quest_state`(id, state ∈ {inactive,active,completed,failed}),
`quest_stage`(id, stage), `party_has_class`(classId), `party_level_cmp`(cmp, value),
`gold_cmp`(cmp, value), `map_is`(mapName), `visited`(placeId), `npc_state`(id, state),
`time_of_day`(value ∈ {day,night}), `chance`(percent) — **chance 는 시드 난수, 검증기에서 양 분기 모두 탐색**.

**Effect** — 배열. 순서대로 적용. `do` 필드로 분기.

허용 do (v1 확정):
`set_flag`(id), `clear_flag`(id), `set_var`(id, value), `add_var`(id, delta),
`give_item`(id, count?=1), `take_item`(id, count?=1), `add_gold`(delta), `add_food`(delta),
`start_quest`(id), `advance_quest`(id, stage), `complete_quest`(id), `fail_quest`(id),
`set_npc_state`(id, state), `warp`(map, x, y), `change_tile`(map?, x, y, tile),
`start_battle`(encounterId), `play_dialogue`(id), `journal`(entryKey), `heal_party`(percent),
`grant_exp`(amount), `set_encounter`(rate), `unlock_place`(id)

- 확장은 **스키마 버전을 올려야만** 가능. 임의 op/do 는 빌드 단계에서 하드 실패.
- 모든 op/do 는 런타임 평가기와 검증기가 **같은 Dart 구현**을 공유한다(D-12).

## D-06 Quest 모델 골격 (확정)

```
Quest {
  id, title(stringKey), summary(stringKey), pack, act, tier,
  giver: actorId?, place: placeId?,
  prerequisites: Condition,
  stages: [ Stage ],
  onComplete: Effect[],
  onFail: Effect[],
  rewards: Effect[],
  failConditions: Condition?,      // 실패 가능 퀘스트만
  journal: { stageKey: stringKey } ,
  tags: [string]
}
Stage {
  id, index, title(stringKey), journal(stringKey),
  objectives: [ Objective ],       // 전부 충족해야 다음 stage (기본 AND)
  completion: "all"|"any",
  onEnter: Effect[], onExit: Effect[],
  next: stageId | "complete" | [ {when: Condition, go: stageId} ]   // 분기
}
Objective {
  id, kind, params, optional?:bool, hidden?:bool, counter?:{target:int}
}
```

Objective.kind 허용값(v1): `talk_to`(actorId), `reach`(placeId | map+x+y+radius), `acquire`(itemId,count),
`deliver`(itemId, actorId), `defeat`(encounterId|enemyId, count), `flag_set`(flagId),
`var_reach`(varId, value), `choose`(dialogueId, choiceId), `survive`(turns)

- 퀘스트는 **Stage 유한 상태 기계**이며, Stage 간 `next` 로 DAG 를 이룬다. 사이클 금지(빌드에서 검출).
- 퀘스트 상태: `inactive → active(stage n) → completed | failed`. 되돌리기 없음(디버그 커맨드 제외).

## D-07 Dialogue 모델 골격 (확정)

```
Dialogue {
  id, speaker: actorId, pack,
  entry: [ {when: Condition, go: nodeId} ],   // 위에서부터 첫 true (조건부 진입)
  nodes: { nodeId: Node }
}
Node {
  id, speaker?: actorId,        // 생략 시 Dialogue.speaker
  lines: [ stringKey ],         // 순서대로 출력, 페이지 넘김은 런타임이 처리
  header?: stringKey,
  onEnter: Effect[],
  choices?: [ Choice ],         // 없으면 next 로 진행
  next?: nodeId | "end"
}
Choice { text: stringKey, when?: Condition, effects?: Effect[], go: nodeId|"end", once?:bool }
```

- 대화는 **그래프**이며 종료 노드까지 도달 가능해야 한다(빌드에서 도달성 검사).
- 한 노드의 `lines` 총 길이는 콘솔 제약(13줄/페이지, GROUND_TRUTH §12)을 넘어도 되지만 빌드가 페이지 수를 경고한다.

## D-08 World State v2 & 저장 포맷 v2 (확정)

런타임 상태의 단일 저장소 `WorldState`:

```
WorldState {
  schemaVersion: int,
  contentVersion: {packId: version},   // 세이브-콘텐츠 호환 판정용
  flags: Set<String>,                  // 이름 있는 플래그
  vars: Map<String,int>,
  quests: Map<questId, {state, stage, counters:{objectiveId:int}, startedStep, updatedStep}>,
  inventory: Map<itemId, count>,
  npcStates: Map<actorId, String>,
  visited: Set<placeId>,
  journal: [ {questId, stageId, entryKey, atStep} ],
  seed: int,
  step: int                            // 논리 시각(월드 이벤트 처리마다 +1). 벽시계 금지.
}
```

- 세이브 v2 = 기존 `{version, party, gameSystem, gameOption, map}` + `worldState` + `currentMapName`.
- **v1 세이브 마이그레이션 필수**: `gameOption.flags/variables` 는 `legacyFlagMap` 역참조로 이름 공간에 흡수.
- 현재 저장 누락(네이티브 러너 flags/variables, 현재 맵 이름)은 v2 에서 **반드시 해소**된다.
- 콘텐츠 버전이 세이브보다 낮으면 로드 거부, 높으면 마이그레이션 규칙 적용(각 팩이 `migrations` 선언).

## D-09 앵커(Anchor) — 엔티티와 좌표의 분리 (확정)

- 현재는 대사가 맵 JSON 안 좌표에 박혀 있다(GROUND_TRUTH §4). AI 가 맵을 고치면 대사가 깨진다.
- 앞으로 맵 JSON 은 **지형과 배치**만, 콘텐츠 팩은 **의미**만 갖는다. 둘을 잇는 것이 앵커:

```
anchors/TOWN1.json = {
  "map": "TOWN1",
  "anchors": [
    {"id":"anchor.core.town1_gate_guard","kind":"actor","actor":"npc.core.lore_gate_guard","x":34,"y":12,"facing":"down"},
    {"id":"anchor.core.town1_notice","kind":"sign","dialogue":"dlg.core.town1_notice","x":30,"y":18},
    {"id":"anchor.core.town1_to_ground","kind":"portal","to":{"map":"GROUND1","x":50,"y":50},"x":50,"y":99}
  ]
}
```

- 앵커 kind: `actor`, `sign`, `portal`, `trigger`(step-on), `container`, `battle`.
- 맵 편집 시 앵커 좌표가 통행 규칙과 어긋나면(예: actor 앵커가 통행 가능 타일 위) 빌드가 실패한다.
- 맵 JSON 의 기존 `events[]` 는 **레거시 폴백**으로만 남고, 신규 콘텐츠는 앵커만 쓴다.

## D-10 디스패치 티어 재정의 (확정)

`HDTileEventDispatcher._dispatchScripted` 의 우선순위를 다음으로 바꾼다:

```
0. Content tier   — 해당 (map,x,y) 에 앵커가 있으면 ContentRuntime 이 처리하고 종료
1. native map script
2. cm2 paired script (Event::Override 로 handled 신호)
3. JSON dialogLines (레거시 폴백)
```

- Content tier 가 처리했으면 아래 티어로 내려가지 않는다(handled=true 반환).
- 기존 3티어의 동작은 앵커가 없는 맵에서 **그대로 보존**된다 → 무중단 점진 이관.
- 재진입 가드(`_isScriptRunning`) 는 유지하되 Content tier 는 **비동기 대화 그래프**를 돌리므로
  가드의 의미를 "한 번에 하나의 상호작용" 으로 문서화하고 테스트로 고정한다.

## D-11 신규 런타임 코드 배치 (확정, 계층 규칙 준수)

```
lib/domain/content/          # 순수 데이터 모델 + 평가기 (Flutter foundation 만 import)
  content_ids.dart           # ID 타입/검증
  condition.dart             # Condition 모델 + evaluate(WorldStateView)
  effect.dart                # Effect 모델 + apply(WorldStateMutator)
  quest.dart  stage.dart  objective.dart
  dialogue.dart  node.dart  choice.dart
  actor.dart  item.dart  place.dart  anchor.dart
  world_state.dart           # WorldState + 직렬화
lib/application/content/     # 유스케이스 (포트만 사용)
  content_repository.dart    # 번들 로드(AssetSource 경유) + 인덱스
  content_runtime.dart       # 앵커 → 대화/퀘스트 실행 진입점
  quest_runtime.dart         # 목표 판정/스테이지 전이
  dialogue_runtime.dart      # 노드 순회 + UiHost 출력
  trigger_index.dart         # (map,x,y,kind) → 핸들러 O(1) 조회
  world_event_bus.dart       # talk/enter/defeat/acquire 등 게임 이벤트 발행
```

- `domain/content/` 는 **파일 I/O·UiHost 를 절대 모른다**. 그래서 그대로 CLI 검증기에서 재사용된다(D-12).
- 싱글턴 관례를 따르되(`ContentRuntime()`), 테스트가 `reset()` 할 수 있어야 한다.

## D-12 툴체인 (확정)

1. **Content Server** — 기존 `tools/mapEditor` 의 dev 서버를 확장해 `/api/content/...` 를 추가.
   맵 API 와 같은 프로세스·같은 에러 규약(`{error, hint}`)·같은 배치 편집 철학. MCP 래퍼도 같은 서버를 감싼다.
2. **`hadar_content` CLI (Dart)** — `tools/content_cli/`. 서브커맨드:
   `build`, `validate`, `lint`, `sim`, `solve`, `diff`, `stats`, `migrate`, `new`.
   Dart 인 이유: `lib/domain/content/` 의 **평가기를 그대로 import** 해서 authoring 시맨틱과 런타임 시맨틱이 갈라지지 않게 하려고.
   (Flutter 의존이 없어야 하므로 domain/content 는 flutter/foundation 도 최소로.)
3. **MCP 서버** — 위 두 개를 AI 에이전트에게 노출. 도구 이름은 `content_*` 로 통일.
4. 원칙: **AI 는 파일을 직접 쓰지 않고 API/CLI 를 통해 쓴다.** 그래야 스키마 정규화·검증·되돌리기가 강제된다.

## D-13 헤드리스 하네스 (확정)

- `HeadlessUiHost implements UiHost` + `MemoryAssetSource implements AssetSource` + `ScriptedMovementHost`.
- `HDHosts().bind(...)` 로 주입 — **이미 존재하는 이음매**(GROUND_TRUTH §3, map_navigation_test.dart 선례).
- `SimDriver`: 정책(policy)에 따라 입력을 자동 생성. 정책 3종:
  `scripted`(주어진 입력 시퀀스), `greedy`(퀘스트 목표를 향해 탐색), `random`(시드 고정 퍼징).
- `QuestSolver`: WorldState 를 노드로 보는 상태 공간 탐색으로 **"이 퀘스트는 완주 가능한가"** 를 증명/반증.
- 산출물: 트레이스 JSON(모든 상호작용·상태 전이), 실패 시 최소 재현 시퀀스.

## D-14 생성 파이프라인 8단계 (확정)

```
1 context   컨텍스트 팩 구성 (world bible + 기존 콘텐츠 요약 + 스키마 + 스타일 가이드)
2 outline   기획 에이전트: 퀘스트 개요/비트/등장인물/장소 (스키마: QuestOutline)
3 draft     집필 에이전트: 대화 그래프 + 퀘스트 정의 + 문자열 (스키마 강제 JSON)
4 bind      바인딩: 앵커 배치, 맵 편집(맵 에디터 API), 아이템/적 참조 해소
5 lint      스키마·참조무결성·도달성·밸런스·문체 정적 검사
6 sim       헤드리스 시뮬레이션 + 솔버로 완주 증명, 회귀 골든 비교
7 critic    검수 에이전트: 서사 품질·톤·일관성·난이도 평가 (루브릭 점수 + 수정 지시)
8 commit    통과분만 팩에 반영, content.lock 갱신, 변경 요약 생성
```

- 각 단계의 입출력은 **파일**이며 재개 가능해야 한다. 실패는 그 단계에서 멈추고 다음으로 넘어가지 않는다.
- LLM 은 2, 3, 7 단계에서만 쓴다. 4~6, 8 은 결정론적 프로그램.

## D-15 품질 게이트 (확정 수치는 각 장에서 상세화)

- Hard gate(하나라도 실패 시 커밋 불가): 스키마 유효, 미해결 참조 0, 대화 도달 불가 노드 0,
  퀘스트 사이클 0, 솔버 완주 증명 성공, 앵커-통행 충돌 0, 문자열 키 누락 0, 결정론 재빌드 해시 일치.
- Soft gate(경고 + 검수 에이전트 판단): 문체 점수, 대사 길이 분포, 보상 밸런스, 중복도, 지역 톤 일치.
- CI 는 콘텐츠 변경 PR 에서 `hadar_content validate && hadar_content sim --all` 을 돌린다.

## D-16 게임 진행 방식 변경의 최소 집합 (확정 스코프)

AI 퀘스트를 성립시키기 위해 게임에 **반드시** 들어가야 하는 것:
1. **퀘스트 저널 UI** — 800x480 안에서. 메인 메뉴에 "임무" 항목 추가.
2. **인벤토리/아이템 시스템** — 현재 food/gold 뿐(GROUND_TRUTH §10). 퀘스트 아이템 없이는 `acquire/deliver` 목표가 불가능.
3. **조건부 대화** — 같은 NPC 가 상태에 따라 다른 말을 해야 한다. 현재 JSON 티어는 무조건 동일 출력.
4. **이름 있는 전역 상태** — 3중 분열(GROUND_TRUTH §8) 통합 + 세이브 v2.
5. **NPC 정체성** — 좌표가 아니라 actorId 로 식별. 이동/재배치에도 대화가 따라와야 함.
6. **월드 이벤트 버스** — 전투 승리/아이템 획득/입장 등이 퀘스트 목표를 자동 진행시키려면 필요.

선택(권장하되 1차 스코프 밖으로 둘 수 있음): 시간대, 평판, 동료 영입, 상점, 실패 가능 퀘스트.

## D-17 스코프 밖 (명시적 제외)

- 런타임 LLM, 온디바이스 추론, 서버 통신, 절차적 실시간 생성.
- 다국어(구조는 열어두되 ko 만 구현).
- 음성/이미지 생성.
- 기존 cm2 콘텐츠의 전면 재작성(공존 전략 D-10 으로 대체).

---

## 문서 규약 (모든 장 공통)

1. 언어는 **한국어**. 코드/식별자/스키마는 원문 그대로.
2. 각 문서 최상단에 메타 블록:
   ```
   > **문서 ID**: BP-21 · **상태**: 초안 · **선행 문서**: [BP-20](../20_target_architecture.md)
   > **독자**: 런타임 구현자 · **한 줄 요약**: …
   ```
3. 식별자 접두사: 요구사항 `R-<장번호>-<n>`, 결정 `D-<n>`(이 파일 것 인용), 갭 `G-<n>`,
   태스크 `T-<n>`, 리스크 `RK-<n>`, 열린 질문 `Q-<n>`.
4. 표·코드블록·스키마를 적극 사용. 산문 문단만으로 설계를 설명하지 말 것.
5. 코드 참조는 `hadar2026_app/lib/application/tile_event_dispatcher.dart:106` 처럼 경로+줄 형식.
6. 다른 장 참조는 상대 경로 링크. 같은 내용을 두 장에 복사하지 말고 **한 곳에 쓰고 링크**.
7. 각 장 말미에 "이 장이 확정한 것 / 다음 장으로 넘긴 것 / 열린 질문" 3절 요약.
8. 분량 목표: 각 장 **최소 250줄, 권장 350~600줄**. 얇은 장은 반려 대상.

---

# 결정 개정 이력

## D-08a (2026-08-30) — 벽시계 시각 제거, 논리 시각 `step` 도입
- **개정 사유**: D-08 초안의 `startedAt`/`updatedAt`/`at` 은 D-01(결정론)과 정면 충돌한다.
  벽시계를 세이브에 넣으면 동일 입력 재현이 불가능해지고, 헤드리스 시뮬레이터(D-13)의
  트레이스 비교와 골든 회귀(D-15)가 성립하지 않는다.
- **개정 내용**: `WorldState.step: int` 를 추가한다. 월드 이벤트를 하나 처리할 때마다 1 증가하는
  단조 증가 논리 시각이다. 퀘스트/저널의 시각 필드는 전부 이 `step` 을 기록한다
  (`startedStep`, `updatedStep`, `atStep`).
- **파급**: 표시용으로 실제 날짜가 필요하면 세이브 **메타데이터**(세이브 슬롯 정보)에만 두고,
  `WorldState` 안에는 절대 넣지 않는다. 세이브 메타는 결정론 해시 계산에서 제외한다.
- **관련**: BP-25 Q-25-1 제기 → 본 개정으로 종결. BP-27 의 `WorldRng` 는 `seed` + `step` 으로 재현.

## D-18 (2026-08-30) — SSoT 소유권 표 (문서 간 충돌 중재 규칙)

병렬 제작 중 같은 주제를 두 장이 다르게 정의하는 충돌이 실제로 발생했다. 아래 표가 **유일한 중재 근거**다.
소유 장이 정의하고, 나머지 장은 **링크만** 한다. 충돌 시 **소유 장이 항상 이긴다** —
비소유 장은 자기 서술을 지우고 링크로 대체할 것(소유 장을 고치는 것이 아니다).

| 주제 | 소유 장 | 비소유 장의 의무 |
|---|---|---|
| Condition/Effect DSL (op·do 전량) | **BP-21** | 이름만 인용, 시그니처 재서술 금지 |
| ID 문법·문자열 키 체계·팩 매니페스트 | **BP-21** | 링크 |
| 세계관·액터·아이템 카탈로그 **스키마** | **BP-22** | 링크 |
| Quest/Stage/Objective 스키마, 월드 이벤트 12종 이름 집합, 보상 티어표 | **BP-23** | 링크 |
| Dialogue/Node/Choice 스키마, 텍스트 길이 수치, UiHost 출력 호출 순서 | **BP-24** | 링크 |
| **세이브 포맷 v2 봉투 전체**(필드명·`mapDelta`·레거시 플래그 보관 위치), WorldState 필드, 마이그레이션 | **BP-25** | 링크. BP-20 §5.3 은 개요 한 문단 + 링크로 축소 |
| 앵커 스키마·트리거 인덱스·앵커/타일 정합 규칙 | **BP-26** | 링크 |
| **런타임 실행 경로**(디스패처 티어 0 삽입 코드, `pendingNavigation` 처리, `WorldRng`·`rngCursor` 소유자, 대화/퀘스트 루프) | **BP-27** | 링크. BP-20 §7.2 의 난수 서술은 BP-27 을 따른다 |
| 이관 상태 기계·cm2 공존·레거시 플래그 다리 | **BP-28** | 링크 |
| 검증 규칙 카탈로그 | **BP-33** | 링크 |
| 시뮬레이터·솔버·선결 리팩터링 범위 | **BP-34** | 링크 |
| CI·빌드 산출물 스키마 | **BP-35** | 링크 |
| 아이템 실제 데이터·인벤토리 게임 규칙·장비 마이그레이션 | **BP-42** | 링크 |
| 문체 규칙 | **BP-43** | 링크 |

## D-19 (2026-08-30) — `pendingNavigation` 은 명시적 설계 대상이다

검수에서 **BP-20·BP-28 이 `pendingNavigation` 을 한 번도 언급하지 않은 것**이 적발되었다.
`hadar2026_app/lib/application/tile_event_dispatcher.dart:99` 는
`endNarrative(autoFlush: HDScriptEngine().pendingNavigation == null)` 로 **narrative flush 를 cm2 엔진 내부 상태에 결합**해 두었다.

- 콘텐츠 티어(D-10 의 티어 0)가 Effect `warp` 를 실행하려면 **같은 지연 이동 메커니즘이 필요**하다.
- 따라서 `pendingNavigation` 은 cm2 엔진 소유가 아니라 **세션/런타임 공용 개념으로 승격**한다.
  이름·소유자·처리 시점은 **BP-27 이 확정**하고(D-18), BP-20/28/33/34 는 그것을 링크한다.
- 이 승격 없이는 D-10 의 "티어 0 이 처리했으면 아래로 내려가지 않는다" 규약이 맵 이동 시 성립하지 않는다.

## D-20 (2026-08-30) — 월드 이벤트 이름 집합 확정 (3파 분열 중재)

검수에서 **BP-23 / BP-25 / BP-27 이 서로 다른 이벤트 이름 집합을 각각 "닫힌 집합" 으로 선언**한 것이 적발되었다
(BP-23 12종 `talk`/`enter_place`/`dialogue_choice`… vs BP-25·BP-27 11종 `talked_to`/`entered_place`/`choice_made`…).
5개만 이름이 같고 그중 3개는 payload 도 달랐다. BP-23 의 objective 커버리지 증명이 이것 때문에 무너진다.

**D-18 에 따라 소유는 BP-23 이다.** 아래 12종이 **정본**이며 BP-25/27/33/34/42 는 이 표를 링크만 한다.
`talked_to`/`entered_place`/`choice_made` 같은 변형 이름은 **전량 폐기**한다.

> **payload 정의는 여기 두지 않는다.** 정본은 소유 장 [BP-23 §23.11.1](../23_quest_model.md) 의 12행 표다.
> (D-20a 의 교훈: 소유 장의 스키마를 결정 문서로 옮겨 적는 행위 자체가 오류원이다.
> 초판 D-20 은 12행 중 **9행의 payload 를 잘못 옮겨 적었고**, Q-52-7 로 적발되었다.)

**이름 12종만 여기서 고정한다** (payload 는 BP-23 을 볼 것):
`talk` · `enter_place` · `step_tile` · `battle_won` · `item_gained` · `item_lost` ·
`flag_changed` · `var_changed` · `dialogue_choice` · `map_changed` · `gold_changed` · `party_rested`

- 이벤트 이름은 **소문자 snake_case, 동사 과거형 금지**(`talk`이지 `talked_to` 가 아니다).
- 새 이벤트 추가는 `schemaVersion` 승격을 요구한다.
- **발행 지점이 현재 코드에 없는 이벤트**(`item_gained`/`item_lost` 는 인벤토리 부재, `enter_place` 는 장소 개념 부재)는
  BP-42/BP-22 가 만들 때까지 **미발행**임을 각 장이 명시해야 한다. "덮는다" 는 주장은 발행 지점이 생긴 뒤에만 참이다.

## D-21 (2026-08-30) — `chance` op 은 커서를 밀지 않는다 (Condition 순수성 보전)

검수에서 **`chance` op 이 `WorldStateMutator.nextRandom` 을 호출해 `rngCursor` 를 전진시키는** 설계가 적발되었다.
이는 D-05 의 "Condition 은 부작용 없는 순수 함수" 를 정면으로 깨뜨리고,
`WorldStateView`/`WorldStateMutator` 분리의 근거 자체를 무효화하며, QuestSolver 가 성립하지 않게 만든다.

**확정**: `chance` 는 **무커서 해시**로 평가한다.

```
chance(p) := (splitmix64(seed, step, siteId) % 100) < p
```

- `siteId` = 그 `chance` 가 등장한 **콘텐츠 상의 위치**를 가리키는 빌드 시 결정 상수
  (예: `quest.core.x#stage2.objective1.when.args[0]`의 해시). 빌드가 부여하고 번들에 굽는다.
- 같은 `(seed, step, siteId)` 는 **항상 같은 결과** → Condition 은 순수하게 유지되고,
  같은 스텝 안에서 여러 번 평가해도 값이 흔들리지 않는다.
- 커서를 쓰는 난수(`WorldRng`)는 **Effect 와 전투 등 쓰기 경로 전용**이다. Condition 은 절대 커서를 건드리지 않는다.
- 솔버는 `chance` 를 **양 분기 모두 탐색**한다(D-13). `siteId` 덕분에 분기 지점 식별이 가능하다.
- 소유: DSL 정의는 BP-21, `splitmix64`/`WorldRng` 구현과 `siteId` 부여 규칙은 BP-27, 빌드 시 `siteId` 생성은 BP-35.

## D-22 (2026-08-30) — `mapDelta` 는 base 종류를 구분한다 (cm2 생성 맵 대응)

검수에서 **`mapDelta` 가 실사용 cm2 8개(`L1_ep1d0`~`d5_1`, `town1.cm2`)에서 성립하지 않는다**는 것이 적발되었다.
이 스크립트들은 `Map::Init` + `Map::SetRow` 로 맵을 **런타임에 생성**하므로 디스크에 원본이 없고, 델타를 뺄 대상이 없다.

**확정**: 세이브의 맵 항목은 `base` 종류를 명시한다.

| `base` | 조건 | 저장 내용 |
|---|---|---|
| `asset:<path>` | 맵이 `assets/maps/*.json` 에서 왔다 | 원본 대비 변경 칸만 (`[[x,y,field,value],…]`) |
| `generated` | `Map::Init`/`Map::SetRow` 로 만들어졌다 | 전체 스냅샷. 단 **칸당 5필드 배열 + RLE** 로 인코딩(현행 키 반복 JSON 금지) |

- `generated` 의 전체 스냅샷도 현행 포맷(`{"ixTile":…,"ixObj0":…}` 반복, 칸당 ~57B)을 **쓰지 않는다.**
  5개 정수 평행 배열 + 런렝스로 인코딩해 부록 C-3 의 570KB 문제를 완화한다.
- `currentMapName`(R-25-4) 은 `loadMapFromFile` 조기 반환 경로에서 **스테일해질 수 있다**(부록 D-2).
  따라서 이름은 **로드 성공이 확정된 뒤에만** 갱신하고, 미확정 상태에서는 `base: "generated"` 로 강등해 저장한다.
- 소유: BP-25. BP-27 은 `Map::Init`/`Map::SetRow` 실행 시 `base` 를 `generated` 로 표시하는 훅만 정의한다.

## D-23 (2026-08-30) — CI 계층 검사에 `dart:io`/`dart:html` 추가

`.github/workflows/ci.yml` 의 `check()` 헬퍼는 확장 가능한 구조다(`lib/application/ lib/domain/` 대상 `grep -rn -E`).
부록 B-4 근거로 세 번째 검사를 추가한다:

```bash
check "application/domain must not import dart:io or dart:html" \
  -E "^import 'dart:(io|html)'"
```

- **주의**: 현재 `hadar2026_app/lib/application/menu_flows.dart:2` 가 이 검사에 걸린다.
  따라서 이 검사 추가와 `exit(0)` 3곳 제거(BP-34 선결 과제)는 **같은 변경으로 함께** 가야 한다.
  먼저 추가하면 CI 가 즉시 빨개진다.
- 검수가 지적한 "ERE lookahead 문법 에러" 와 "`ci.yml:57` 하드코딩 경로" 문제 때문에
  **정규식에 lookahead 를 쓰지 말 것.** 위 형태처럼 단순 ERE 로 표현하라. 소유: BP-35.

## D-20a (2026-08-30) — `item_gained`/`item_lost` payload 정정

D-20 표의 `{itemId, count}` 는 메인이 옮겨 적으며 생긴 오기였다. **소유 장인 BP-23(§23.11.1, `23_quest_model.md:1164`)의
`{itemId, delta, total}` 가 정본**이다. D-20 표를 그에 맞춰 정정했다.

- `delta` = 이번 변화량(항상 양수, 방향은 이벤트 이름이 나타냄), `total` = 변화 후 소지 수량.
- `count` 단일 필드는 **"변화량인가 총량인가" 가 모호**해서 `acquire(itemId, count:3)` 목표의 판정을 흔든다.
  `total` 이 있어야 카운터형 목표가 이벤트 하나로 판정된다.
- 다른 변화 이벤트와 표기가 일관된다: `var_changed {varId, from, to}`, `gold_changed {from, to, delta}`.
- **교훈(D-18 보강)**: 소유 장의 정의를 다른 문서로 **옮겨 적는 행위 자체가 오류원**이다.
  D-18 의 "비소유 장은 링크만" 규칙은 결정 문서(`DECISIONS.md`)에도 적용된다 —
  이후 결정에서 소유 장의 스키마를 전재하지 말고 위치만 지정할 것.

## D-21a (2026-08-30) — `siteId` 는 BP-21 의 `<contextId>#<evalPath>` 와 동일 개념이다

D-21 이 도입한 `siteId` 와 BP-21 §6.5(`21_content_pack_spec.md:707`)의
`key = "<contextId>#<evalPath>"` 는 **같은 것의 두 이름**이었다(Q-52-4 로 적발).

- **정본 명칭·형식은 BP-21 의 것**이다(D-18: DSL 소유는 BP-21).
  `contextId` = 평가를 요청한 최상위 엔티티 ID, `evalPath` = 그 안에서 해당 `chance` 노드까지의 구조 경로.
  예: `"dlg.gen_ep1.guard_intro#node.intro.entry[2].args[1]"`.
- D-21 의 공식은 다음으로 읽는다:
  `chance(p) := (splitmix64(seed, step, hash("<contextId>#<evalPath>")) % 100) < p`
- `siteId` 라는 이름은 **폐기**한다. 이후 문서는 BP-21 의 명칭만 쓴다.
- BP-21 Q-21-3 이 제기한 "구조 경로를 쓰면 대화를 고칠 때 기존 세이브의 분기 결과가 바뀐다" 는
  **유효한 우려**다. v1 은 구조 경로로 가되, 선택 필드 `seedKey` 추가로 탈출구를 남긴다는 BP-21 의 판단을 승인한다.

## D-24 — (결번)

번호를 건너뛴 것은 조정자의 실수다. **재사용하지 않는다** — 이미 여러 문서가 D-25/D-26 을 인용하고 있어
번호를 당기면 참조가 전부 깨진다. 새 결정은 D-27 부터 붙인다.

## D-25 (2026-08-30) — 결정 문서는 스키마를 전재하지 않는다 (프로세스 규칙)

D-20(9행 오기)과 D-21(이름 중복)이 **같은 원인**에서 나왔다: 메인이 소유 장의 정의를 요약해 옮겨 적었다.

**이후 모든 결정은 다음을 지킨다.**
1. 결정 문서(`DECISIONS.md`)는 **판단·중재·우선순위**만 담는다. 필드 표·스키마·시그니처를 전재하지 않는다.
2. 소유 장을 가리킬 때는 **파일 경로 + 절 번호**로 지정한다. 내용을 재서술하지 않는다.
3. 이름 목록처럼 짧고 안정적인 것만 예외로 인용하되, **payload·타입·기본값은 절대 인용하지 않는다.**
4. 검수는 "결정 문서가 소유 장과 일치하는가" 가 아니라 **"결정 문서가 소유 장을 전재하고 있지 않은가"** 를 본다.

## D-26 (2026-08-30) — 솔버는 "모델상 증명" 과 "현행 빌드에서 실행 가능" 을 구분한다

BP-91(W-10)이 결정적 결함을 드러냈다: `deliver`/`acquire` 목표는 `item_gained`/`item_lost` 이벤트에 의존하는데
D-20 은 그 두 이벤트가 **인벤토리 부재로 현재 미발행**임을 명시한다. 그런데 솔버는 그 퀘스트에 `PROVEN` 을 냈다.
정적 증명이 **실행 가능성을 보지 않았기 때문**이다. 이대로면 솔버는 "돌아가지 않는 콘텐츠" 를 통과시킨다.

**확정**: 솔버 판정은 3값이 아니라 **2축**이다.

| 축 | 값 | 의미 |
|---|---|---|
| 모델 증명 | `PROVEN` / `REFUTED` / `UNKNOWN(타임아웃)` | 콘텐츠 그래프상 완주 경로가 존재하는가 |
| 실행 가능 | `SUPPORTED` / `UNSUPPORTED` | 그 경로가 의존하는 **모든 월드 이벤트에 현행 빌드의 발행 지점이 존재하는가** |

- 빌드는 **이벤트 → 발행 지점 레지스트리**를 생성한다. 발행 지점이 없는 이벤트는 `unpublished` 로 표시된다.
- 솔버는 경로가 소비하는 이벤트를 모아 이 레지스트리와 대조한다. 하나라도 `unpublished` 면 `UNSUPPORTED`.
- **`PROVEN + UNSUPPORTED` 는 하드 게이트 통과가 아니다.** 커밋은 가능하되 그 팩은 "미활성" 으로 표시되고,
  릴리스 게이트에서 차단된다. 마일스톤 진행 중 미리 콘텐츠를 만들어 두는 것을 허용하되 배포는 막는 장치다.
- 소유: 판정 축과 레지스트리 대조는 **BP-34**, 레지스트리 생성은 **BP-35**, 게이트 반영은 **BP-53**.
- 이 결정은 D-20 말미의 "미발행 이벤트" 조항을 **기계가 강제하는 형태로** 승격한 것이다.

## D-27 (2026-08-30) — 앵커는 타일 비트에 의존하지 않는다 (region 예약안 폐기)

부록 J-1 이 결정적 사실을 확정했다: **region 레이어 값은 타일 액션을 만들 수 없다.**
`map_loader.dart:44` 가 region(0~255)을 `ixEvent` 하위 바이트에 넣는데
`tile_properties.dart:187` 은 상위 바이트(`& 0x00FF0000`)만 보기 때문이다.
따라서 BP-26 의 **region 200~255 예약안은 폐기**한다 — 비용 문제가 아니라 **작동하지 않는다.**

**대신 확정하는 것**: 콘텐츠 티어는 **타일 비트를 거치지 않고 트리거 인덱스를 직접 조회**한다.

- `HDTileEventDispatcher.check` 는 현재 타일에서 `HDTileAction` 을 뽑아 그것이 scripted 인지로 분기한다
  (`tile_event_dispatcher.dart:51-61`). 콘텐츠 티어는 **이 게이트보다 앞에서** `(map, x, y)` 로
  트리거 인덱스를 조회하고, 앵커가 있으면 타일 액션과 **무관하게** 처리한다.
- 즉 앵커는 맵 데이터에 **아무 표시도 남기지 않아도 된다.** 이것이 D-09(의미와 좌표의 분리)의 논리적 귀결이다.
  맵 편집기가 지형만 바꾸고 콘텐츠 팩이 의미만 갖는다면, 의미가 지형 비트에 기생할 이유가 없다.
- **앵커-타일 정합 규칙은 런타임 요구가 아니라 린트 규칙(WARN)으로 강등**한다.
  actor 앵커가 통행 가능한 타일 위에 있으면 플레이어가 마주 볼 수 없어 **대화가 불가능**하므로 여전히 경고 대상이다.
  그러나 이는 **저작 품질 문제**이지 런타임 동작 조건이 아니다.
- portal 앵커도 마찬가지다. `enter` 타일 위에 두는 것이 자연스럽지만, 강제되지 않는다.

**파급**
- BP-26: region 예약 절 삭제, 트리거 인덱스 직접 조회로 대체, 정합 규칙을 WARN 으로 강등. (소유)
- BP-27: `check()` 에 인덱스 선조회 경로를 삽입하는 코드 스케치 갱신. **step-on 도 타일 액션 없이 발화해야 한다.**
- BP-31/36: region 기반 편집·검증 기능 삭제. 에디터는 앵커를 **오버레이로만** 표시한다(맵 데이터 미변경).
- BP-33: 정합 규칙을 ERROR → WARN 으로 조정.
- 부록 I-1(Map001 (2,3) region=255 충돌)은 **무의미해진다** — 예약을 안 하므로 충돌도 없다.

**교훈**: "기존 데이터 필드를 재활용한다" 는 안은 그 필드가 **실제로 읽히는지** 확인하기 전에는 채택하면 안 된다.
AI_GUIDE 의 "게임이 ixEvent 로 읽음" 이라는 서술이 이 오해의 출발점이었다 — 읽기는 하지만 쓰이지 않는다.

## D-28 (2026-08-30) — region 승격안(BP-26 T1) 최종 기각, D-27 유지

BP-26 이 D-27 을 논의하면서도 §3.5 의 **region 승격 설계를 살아 있는 규칙으로 남겼다**(R-26-9, R-26-46~48, `A-26-13`).
이는 단순 누락이 아니라 **작동하는 대안**이었으므로 공정하게 비교한 뒤 기각한다.

**BP-26 T1 (로더 승격)**: `map_loader.dart` 를 고쳐
`ixEvent = (region >= 200) ? (0x00010000 | region) : region` 으로 승격시키면 region 트리거가 실제로 동작한다.
부록 J-1 이 지적한 비트 불일치는 이렇게 해소된다 — **기술적으로 가능하다.**

**그럼에도 기각하는 이유**

| # | 항목 | T1 (로더 승격) | D-27 (인덱스 직접 조회) |
|---|---|---|---|
| 1 | 코드 변경 | 로더 1곳 + 충돌 규칙 3개(R-26-46~48) + `Map001` 마이그레이션 | **없음.** 부록 K 가 step-on(`player_sprite.dart:193`)·확인키(`:405`)에 선검사가 없음을 실측 |
| 2 | 값 대역 예약 | 200~255 예약 필요 | 불필요 |
| 3 | objUpper 충돌 | 공존 금지 하드 규칙이 필요(`A-26-13`) | **발생하지 않음** — 앵커가 타일 비트를 쓰지 않으므로 |
| 4 | **맵 편집 내구성** | **깨진다.** 누가 region 레이어를 지우거나 값을 바꾸면 트리거가 소실된다 | **무영향.** 앵커가 맵 데이터에 흔적을 남기지 않는다 |
| 5 | 서버-런타임 판정 일치 | 서버가 타일 비트를 해석해야 하므로 이중 구현 위험(R-26-48 이 규정하려 한 것) | 인덱스가 단일 정본 |

**4번이 결정적이다.** D-09(의미와 좌표의 분리)의 목적 자체가 "맵을 고쳐도 콘텐츠가 깨지지 않게" 하는 것인데,
region 승격은 앵커를 **다시 맵 데이터에 묶는다.** 부록 D 가 보여준 것처럼 이 프로젝트의 맵 데이터는 이미
등록·해석이 어긋난 상태이고, 거기에 콘텐츠 트리거를 얹으면 같은 종류의 사고가 재발한다.

**확정**
- BP-26 의 R-26-9 · R-26-46 · R-26-47 · R-26-48 · `A-26-13` · §3.5 로더 수정안 · T-26-1 을 **전부 폐기**한다.
  폐기 사실과 이유를 문서에 남기고(삭제만 하지 말 것), `trigger` 앵커는 **트리거 인덱스 직접 조회**로만 발화한다.
- `map_loader.dart` 는 **수정하지 않는다.** region 레이어는 계속 읽히되 계속 아무 효과가 없다(부록 J).
- BP-91 `W-04`(region 승격 ↔ objUpper 충돌)는 **문제 자체가 소멸**하므로 해소 처리한다.
- 부록 I-1(`Map001` (2,3) region=255)도 **무의미**하다 — 예약하지 않으므로 충돌이 없다.

## D-29 (2026-08-30) — `siteId` 잔여 표기 정리 (D-21a 집행)

D-21a 가 `siteId` 를 폐기하고 BP-21 §6.5 의 `<contextId>#<evalPath>` 를 정본으로 확정했으나,
BP-21 만 이를 반영했고 **BP-02·BP-25 등이 여전히 `siteId` 를 쓰거나 "이름 통합 미완(Q-52-4)" 이라고 적고 있다.**

- 정본은 `<contextId>#<evalPath>` 다. `chance` 유도식은
  `chance(p) := (splitmix64(seed, step, hash("<contextId>#<evalPath>")) % 100) < p`.
- **Q-52-4 는 종결**이다. "통합 미완" 서술을 전부 "종결 — 정본은 BP-21 §6.5" 로 바꿀 것.
- BP-02 는 `siteId` 를 **폐기 용어 절로 이동**하고, 본 항목에는 정본 이름만 남긴다.

## D-29a (2026-08-30) — D-29 정정: 문자열 키와 빌드 상수는 **다른 것**이다

D-29 는 `siteId` 를 "`<contextId>#<evalPath>` 의 다른 이름" 으로 보고 전량 폐기를 지시했다. **이 판단은 과잉이었다.**
실제 두 문서를 대조하니 서로 다른 두 개체였다:

| 개체 | 정체 | 소유 | 초판 표기 |
|---|---|---|---|
| **문자열 키** | `chance` 노드의 콘텐츠 상 위치를 가리키는 경로 문자열 | BP-21 §6.5 | `<contextId>#<evalPath>` |
| **빌드 상수** | 그 키를 해시해 번들에 굽는 정수. 런타임이 읽는 값 | BP-27 (D-21 이 위임) | `siteId` |

D-21a·D-29 가 `siteId` 를 통째로 폐기하자 **빌드 상수에 이름이 없어졌다.** BP-27 은 그래서 그 이름을 계속 쓰고 있었고,
이는 결정 위반이 아니라 **결정의 공백**이었다.

**확정 (명명)**
- `chanceKey` — 문자열 키. 형식은 `<contextId>#<evalPath>`. **소유 BP-21 §6.5.**
- `chanceSeedId` — `mix(hashString(chanceKey))` 로 빌드가 계산해 번들에 굽는 정수. 런타임은 `Condition.chanceSeedId` 를 읽기만 한다. **소유 BP-27.**
- `siteId` 는 **여전히 폐기**다 — 두 개체를 가리키는 데 혼용되었기 때문이다. 이제 각자 이름이 있다.
- 유도식: `chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p` — 즉 해시는 **빌드가 한 번** 하고 런타임은 정수만 섞는다.

**부수 정정**: BP-27 의 경로 문법 `<ownerId>#<path>` 는 BP-21 의 `<contextId>#<evalPath>` 와
**세그먼트 이름이 어긋난다.** 정본은 BP-21 의 것이다(D-18).

**교훈**: "같은 개념의 두 이름" 이라는 진단은 **두 정의를 나란히 놓고 확인한 뒤에만** 내려야 한다.
D-29 는 BP-02 의 요약("같은 개념의 두 이름")을 근거로 삼았는데, 그 요약 자체가 부정확했다.
요약을 근거로 결정을 내리면 안 된다 — D-25 가 금지한 "전재" 의 사촌이다.

## D-30 (2026-08-30) — `chance` 는 `step` 을 시드에 포함한다 (BP-90 `I-06` 해소)

BP-90 이 두 장의 유도식이 **의미상 다르다**는 것을 적발했다(`I-06`, 심각도 높음):

| 출처 | 식 | `step` | 결과 |
|---|---|---|---|
| BP-21 §6.5 (R-21-34) | `splitmix64(seed ^ fnv1a64(chanceKey))` | **없음** | 같은 세이브·같은 위치는 **영원히** 같은 결과 |
| D-21 / BP-27 | `mix([seed, step, chanceSeedId])` | **있음** | 월드가 진행하면 같은 위치도 결과가 바뀜 |

표기 차이가 아니라 **게임 동작이 갈린다.** 판정한다.

**확정: `step` 을 포함한다.** 정본 유도식은
`chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p`

**근거**
1. `step` 이 없으면 `chance` 는 확률이 아니라 **세이브마다 고정된 상수**다. 30% 대사는 그 세이브에서 영원히
   나오거나 영원히 안 나온다. 작성자가 기대하는 동작이 아니다.
2. **순수성은 유지된다.** D-05/D-21 이 요구하는 것은 "조건 평가가 상태를 바꾸지 않는다" 이고,
   `step` 은 View 로 **읽는** 값이다. 같은 스텝 안에서 같은 조건을 몇 번 평가해도 같은 값이 나온다 —
   목표 판정이 배치 단위(BP-23)이므로 이것으로 충분하다.
3. 솔버는 어느 쪽이든 `chance` 를 **분기점으로 양쪽 탐색**한다(D-13). `chanceSeedId` 가 분기 지점을 식별한다.

**따라오는 규정**
- **BP-21 R-21-34("같은 세이브·같은 위치는 항상 같은 결과")를 개정**하라. 정확한 명제는
  "같은 세이브·같은 위치·**같은 스텝**은 항상 같은 결과" 다.
- **재굴림(reroll) 악용 주의**: `step` 이 들어가므로 플레이어가 나갔다 다시 들어와 `chance` 를 다시 굴릴 수 있다.
  **결과를 고정하고 싶으면 Effect 에서 `set_flag` 로 래치하라** — 래치는 상태 변경이므로 정의상 Effect 의 일이다.
  Condition 만으로 영구 결과를 만들려는 설계는 **하지 않는다.**
  BP-33 은 "`chance` 만으로 분기하고 래치가 없는 곳" 을 **WARN** 으로 잡을 것(BP-33 소관).
- **BP-35 는 `chanceSeedId` 를 굽는 규칙을 명시하라** — BP-90 이 지적한 대로 현재 BP-35 §1.4/§1.6 에
  생성 서술이 없다. 형식·소비는 BP-27, 생성은 BP-35(D-29a).
- 해시 함수 이름이 `splitmix64` / `fnv1a64` / `mix` 로 세 장에서 갈린다. **정본은 BP-27 §9.2 의 `mix`** 이며
  내부적으로 splitmix64 계열을 쓰되 **웹 정수 제약(32비트 2워드) 때문에 구현이 고정**된다. 다른 장은 `mix` 로 통일하라.

## D-31 (2026-08-30) — Effect `do` 집합을 22 → 25 로 확장 (BP-90 `I-20` 해소)

BP-90 `I-20` 이 **설계 모순**을 적발했다: 원작 소비품의 효과(SP 회복·해독·의식 회복·부활·버프 부여)에 대응하는
`do` 가 v1 22종에 **없다.** 그런데 BP-22 `R-22-18` 은 "`consumable` 이 `effects` 비면 하드 실패" 다.
→ **원작 아이템 시드 5개 이상이 자기 규칙에 걸려 빌드를 통과할 수 없다.**

D-05 는 `do` 집합을 닫힌 것으로 두고 확장에 `schemaVersion` 승격을 요구한다. **아직 릴리스 전이므로 지금 확장한다.**
"규칙을 느슨하게 해서 통과시킨다" 는 반대 방향은 채택하지 않는다 — 효과 없는 소비품을 허용하면
BP-42 가 이미 겪은 문제(관측 불가능한 소모품, `R-42-23a`)가 스키마 차원에서 재발한다.

**추가하는 3종** (총 **25종**, `schemaVersion` 1 → 2)

| `do` | 인자 | 의미 | 제약 |
|---|---|---|---|
| `restore` | `resource` ∈ {`sp`, `esp`}, `percent`, `target` | SP/ESP 회복 | HP 는 기존 `heal_party(percent)` 가 담당 — 중복 정의 금지 |
| `cure` | `status` ∈ {`poison`, `unconscious`, `dead`}, `target` | 상태 해제 | `HDPlayer.poison`/`unconscious`/`dead` 가 실제 존재하는 필드다 |
| `grant_buff` | `buff`, `turns` | 파티 버프 부여 | **`buff` 는 런타임이 실제로 읽는 것만 허용** — BP-42 §1.7 이 `PartyBuffs` 8종 중 살아 있는 것은 `magicTorch`·`walkOnWater`·`canUseEsp` **3종뿐**임을 확정했다. 나머지 5종을 지정하면 **빌드 하드 실패** |

**`target` 인자 공통 규약**: `all`(파티 전체) | `leader` | `slot:<0-5>` | `lowest:<resource>`.
정의는 **BP-21 소유**(DSL). BP-22/BP-42 는 링크만 한다(D-18/D-25).

**따라오는 규정**
- `grant_buff` 의 허용 buff 화이트리스트는 **BP-42 §1.7 의 실측**에 종속된다. 죽은 버프에 효과를 붙이는 것은
  D-31 이 막으려는 바로 그 문제다. `Effect` → `PartyBuffs` 다리를 놓는 태스크가 BP-51 에 필요하다(현재 어느 장도 소유하지 않음).
- BP-33 은 `grant_buff` 의 buff 화이트리스트 검사와 `restore`/`cure` 의 인자 열거 검사를 **L1** 에 추가하라.
- BP-90 은 `effect.schema.json` 에 3종을 반영하고 `I-20` 을 해소 처리하라.
- **`schemaVersion` 2 승격**을 BP-21 이 기록하라. 이것이 이 기획서 최초의 스키마 승격 사례이므로,
  BP-21 §7 의 승격 절차가 실제로 작동하는지 이 건으로 검증하라.
