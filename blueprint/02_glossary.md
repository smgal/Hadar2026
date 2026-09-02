# 용어 사전

> `상태: 참고` — 현황 조사·참조 자료. 사실 정본은 [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md) 이며,
> 이 장의 **결론·권고는 1차 노선 기준**이라 [`issues/DECISION-LOG.md`](../issues/DECISION-LOG.md) 2차 판정이 우선한다.

> **문서 ID**: BP-02 · **상태**: 초안 · **선행 문서**: `_meta/DECISIONS.md`(D-01~D-27, **D-24 는 결번** — §17.7) · [BP-92](92_appendix_reference_index.md)
> **독자**: 이 기획서를 읽다가 용어가 막힌 사람 · 신규 참여자 · 구현자
> **한 줄 요약**: 이 기획서 22개 장에서 **실제로 쓰인** 용어 **176개**를 수집해 1~3문장 요약과 **정의처 링크**로 묶고, 혼동하기 쉬운 짝을 표로 갈라 둔다.

**이 문서의 성격 (D-18 준수)**

이 문서는 **정의하지 않는다. 가리킨다.** 각 항목의 요약은 "이 단어를 처음 본 사람이 문맥을 잡을 수 있는 정도" 까지만이며,
필드·시그니처·수치·알고리즘은 **정의처 열의 문서가 유일한 정본**이다.
이 문서와 정의처가 어긋나면 **정의처가 이긴다.** 이 문서를 근거로 구현하지 말 것.

**읽는 법**

- `정의처` 가 **D-nn** 이면 `_meta/DECISIONS.md` 의 확정 결정이다. 본문 장보다 상위다.
- `정의처` 가 **코드 경로**면 기획서가 만든 개념이 아니라 **현행 코드에 이미 있는 것**이다.
- `구별` 열은 **혼동하기 쉬운 것과의 경계**만 적는다. 자세한 짝 비교는 §4.

---

## 1. 파이프라인과 구획

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **Authoring 구획** | Authoring | 사람과 LLM 에이전트가 콘텐츠 소스를 만드는 오프라인 구획. 배포 전에만 동작한다 | D-01 | Build 와 달리 **비결정적**이어도 된다 |
| **Build 구획** | Build | 소스를 검증·링크·최적화해 런타임 번들로 굽는 오프라인 구획. **LLM 을 쓰지 않고 결정론적**이다 | D-01 | Authoring 과 달리 재실행 시 같은 바이트가 나와야 한다 |
| **Runtime 구획** | Runtime | 구워진 번들을 결정론적으로 **해석만** 하는 게임 실행 구획. LLM·네트워크·비시드 난수 금지 | D-01 | "런타임 생성" 은 이 기획에 존재하지 않는다(D-17) |
| **결정론** | determinism | 같은 입력·같은 시드로 같은 결과가 나오는 성질. 골든 회귀·shadow diff·솔버 재생이 전부 이것 위에 선다 | D-01 · [BP-35 §2](35_ci_and_build.md) | "재현 가능" 과 같은 뜻으로 쓴다. 벽시계·무시드 난수가 이것을 깨뜨린다(부록 C-4) |
| **8단계 파이프라인** | context→outline→draft→bind→lint→sim→critic→commit | 콘텐츠 생성의 확정된 8단계. **LLM 은 2·3·7 단계에서만** 쓰고 4~6·8 은 결정론적 프로그램이다 | D-14 · [BP-32 §32.3](32_generation_harness.md) | 검증 5계층(L1~L5)과 다르다 — 이쪽은 **생성 절차**, 저쪽은 **검사 깊이** |
| **정규 JSON** | canonical JSON | 산출물 직렬화 규약 10종(UTF-8, 키 사전순, 2칸 들여쓰기, `\n`, 정수만 등). 한 글자라도 다르면 결정론 위반 | [BP-35 §2.1](35_ci_and_build.md) | 소스 JSON 이 아니라 **빌드 산출물**에 적용된다 |

---

## 2. Content Pack · ID · 문자열

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **Content Pack** | Content Pack, 콘텐츠 팩 | AI/사람이 만드는 콘텐츠의 배포 단위. `assets/content/<pack>/` 아래 world·actors·items·quests·dialogue·anchors·strings 로 구성된다 | D-03 · [BP-21 §2](21_content_pack_spec.md) | 빌드 **산출물**(`content/build/`)과 다르다. 팩은 소스다 |
| **매니페스트** | `pack.json` | 팩의 신원 파일. `id`·`version`(semver)·`schemaVersion`(정수)·`title`·`dependsOn`·`generatedBy` 가 필수 | D-03 · [BP-21 §3](21_content_pack_spec.md) | `content.lock.json`(빌드 증빙)과 다르다 |
| **팩 합성** | pack composition, `dependsOn` | 기본 팩 `core` 위에 생성 팩 `gen_ep1` 을 겹쳐 쓰는 것. **빌드 시점에 해소**되고 런타임은 합쳐진 번들 하나만 본다 | D-03 · [BP-20 §3](20_target_architecture.md) | 런타임 오버레이가 아니다 |
| **스키마 버전** | `schemaVersion` | 팩 포맷의 정수 버전. **op/do/이벤트 이름을 늘리려면 반드시 올려야 한다** | D-03 · D-05 · D-20 | `version`(semver, 콘텐츠 내용의 버전)과 다르다 |
| **콘텐츠 버전** | `contentVersion` | 세이브가 기록하는 `{packId: version}` 맵. 세이브-콘텐츠 호환 판정에 쓴다 | D-08 · [BP-25](25_world_state_and_save.md) | `schemaVersion`(포맷)과 다르다 |
| **은퇴 ID** | `retiredIds` | 삭제된 ID 의 묘비. ID 는 불변이고 **재사용 금지**이므로 지운 것도 흔적을 남긴다 | D-04 · [BP-21 §4.6](21_content_pack_spec.md) | 격리(`quarantine/`)와 다르다 — 저쪽은 미커밋 산출물 |
| **진입점** | `entryPoints` | 이 팩이 월드에 붙는 지점. 여기에도 없고 다른 퀘스트가 참조하지도 않는 퀘스트는 **고아**로 경고된다 | [BP-21 §3.3](21_content_pack_spec.md) | 대화의 `entry`(조건부 진입 규칙)와 **다른 개념**이다 |
| **번들** | `content.bundle.json` | 전 콘텐츠를 병합·정규화한 런타임 산출물 | D-03 · [BP-35 §1](35_ci_and_build.md) | 소스 팩과 다르다. 이것만 `pubspec.yaml` 에 등록된다 |
| **인덱스** | `content.index.json` | 트리거 인덱스 + 역참조 인덱스 + 별칭 사전을 담은 산출물 | D-03 · [BP-26 §5](26_entity_registry_and_anchors.md) | `xref` 는 런타임이 읽지 않는다(툴 전용) |
| **락 파일** | `content.lock.json` | 소스 해시·스키마 버전·빌드 결정론 증빙·`legacyFlagMap`·`migration` 롤업을 담는 산출물 | D-03 · [BP-35 §1](35_ci_and_build.md) | `pubspec.lock` 과 무관하다 |
| **콘텐츠 ID** | `<type>.<pack>.<slug>` | 모든 엔티티의 불변 식별자. 전부 소문자 snake_case. 예 `npc.core.lore_gate_guard` | D-04 · [BP-21 §4](21_content_pack_spec.md) | 레거시 정수 인덱스와 다르다 |
| **상태 키** | `flag.<pack>.<domain>.<name>` / `var.…` | 이름 있는 플래그·변수의 키. 신규 콘텐츠는 정수를 직접 쓰지 않는다 | D-04 | 레거시 정수 플래그(0~255)와 구별 → §4 |
| **문자열 키** | `str.<pack>.<owner_type>.<owner_slug>.<slot>` | 모든 표시 문자열의 키. 한국어 텍스트는 `strings/ko.json` 에만 있다 | [BP-21 §5](21_content_pack_spec.md) | 인라인 한국어는 하드 게이트 위반(H-9) |
| **린트 정책** | `pack.json#lintPolicy` | 팩이 스스로 규칙을 강화(`promote`)하거나 만료부 유예(`demote`)하는 선언 | [BP-33 §5](33_validation_and_lint.md) | 개별 억제(`_lintIgnore`)와 다르다 — 이쪽은 팩 단위 |
| **콘텐츠 예산** | `contentBudget` | 길이·경고 밀도 등 팩이 선언하는 임계값 집합 | [BP-21](21_content_pack_spec.md) · [BP-33 §5.1](33_validation_and_lint.md) | 컨텍스트 예산(토큰)과 다르다 |

---

## 3. Condition / Effect DSL

> **소유는 [BP-21](21_content_pack_spec.md)** 이다(D-18). op·do 의 시그니처는 여기서 재서술하지 않는다.

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **Condition** | Condition | 단일 JSON 객체. `op` 로 분기하고 중첩 가능하며 **부작용 없는 순수 함수**다 | D-05 · [BP-21 §6](21_content_pack_spec.md) | Effect 는 배열이고 쓰기다 |
| **Effect** | Effect | 배열. `do` 로 분기하고 **순서대로** 적용된다 | D-05 · [BP-21 §6](21_content_pack_spec.md) | Condition 은 객체이고 읽기다 |
| **op** | `op` | Condition 의 연산 이름. **v1 닫힌 집합**이며 임의 추가는 빌드 하드 실패 | D-05 | `do`(Effect 쪽)와 짝이지만 집합이 다르다 |
| **do** | `do` | Effect 의 동작 이름. **v1 닫힌 집합** | D-05 | 위와 같음 |
| **닫힌 집합** | closed set | 확장하려면 `schemaVersion` 승격이 필요한 목록. op·do·월드 이벤트 이름·Objective kind 가 이에 해당 | D-05 · D-06 · D-20 | "권장 목록" 이 아니다. 밖의 값은 통과하지 못한다 |
| **`chance`** | `chance(percent)` | 확률 조건 op. **커서를 밀지 않는 무커서 해시**로 평가해 Condition 의 순수성을 지킨다. 정본 유도식은 `chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p` — **`step` 을 포함한다**(D-30) | D-21 · **D-30** · [BP-21 §6.5](21_content_pack_spec.md) · [BP-27 §9.2](27_runtime_engine.md) | `WorldRng`(커서 소비형)와 구별 → §15 X-04. 순수성은 **같은 스텝 안에서** 보장된다 — 세이브 전체에 걸쳐 고정되는 것이 **아니다** → §15 X-21 |
| **chanceKey** | `chanceKey` (형식 `<contextId>#<evalPath>`) | `chance` 노드의 **콘텐츠 상 위치를 가리키는 경로 문자열**. `contextId` = 평가를 요청한 최상위 엔티티 ID, `evalPath` = 그 안에서 해당 노드까지의 구조 경로 | **D-29a** · [BP-21 §6.5](21_content_pack_spec.md) (**소유**) | `chanceSeedId`(그 키의 빌드 시 해시 **정수**)와 **다른 개체**다 → §15 X-12. 폐기된 `siteId` 는 이 둘을 혼용한 이름이었다(§17.7) |
| **chanceSeedId** | `chanceSeedId` | `mix(hashString(chanceKey))` 로 **빌드가 한 번 계산해 번들에 굽는 정수**. 런타임은 `Condition.chanceSeedId` 를 읽기만 하고 문자열을 다시 해시하지 않는다 | **D-29a** · [BP-27](27_runtime_engine.md) (**형식·소비 소유**) · [BP-35](35_ci_and_build.md) (**생성 소유**) | 솔버에서는 이 값이 **분기 지점의 식별자** 역할을 한다(D-30 근거 3) |
| **evalPath** | `evalPath` | `chanceKey` 의 **뒷 세그먼트** — `contextId` 안에서 그 `chance` 노드까지의 구조적 경로. 예 `node.intro.entry[2].args[1]` | [BP-21 §6.5](21_content_pack_spec.md) | 독립 개념이 아니라 **`chanceKey` 의 구성 요소**다. BP-27 의 `<ownerId>#<path>` 표기는 세그먼트 이름이 어긋난 것이고 **정본은 BP-21 의 것**이다(D-29a 부수 정정) |
| **꼬리 호출 규칙** | tail-call rule | `play_dialogue` 뒤에 효과를 더 두거나 `warp`+`start_battle` 을 함께 쓰는 것을 금지하는 규칙 | `R-21-38` / `R-21-40`([BP-21](21_content_pack_spec.md)) | 하드 게이트 H-11 |
| **지연 효과** | `DeferredEffect` | `WorldStateMutator` 로 적용할 수 없는 do(맵 전환·전투 시작·대화 재생 등). 상호작용이 끝난 뒤 실행된다 | [BP-20 §4.2](20_target_architecture.md) · [BP-27](27_runtime_engine.md) | 즉시 효과(플래그·변수·인벤토리)와 구별 |
| **효과 브리지** | `HDEffectBridge` | 지연 효과를 실제 게임 시스템에 밀어 넣는 어댑터. CLI 는 대신 트레이스 기록용 sink 를 쓴다 | [BP-20 §4.2](20_target_architecture.md) | `EffectApplier`(즉시 효과 적용기)와 다르다 |

---

## 4. 퀘스트

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **Quest** | Quest | 퀘스트 1건. `stages` 유한 상태 기계 + `prerequisites`/`rewards`/`journal`/`tags` 로 구성 | D-06 · [BP-23](23_quest_model.md) | 대화(Dialogue)와 별개 엔티티다 |
| **Stage** | Stage | 퀘스트의 한 단계. 여러 `objectives` 를 갖고 `next` 로 다음 stage 또는 `complete` 로 간다. Stage 간 관계는 **DAG**(사이클 금지) | D-06 · [BP-23 §23.4](23_quest_model.md) | Objective 와 구별 → §4 |
| **Objective** | Objective | Stage 안의 개별 목표. `kind`+`params`+선택적 `counter`/`optional`/`hidden` | D-06 · [BP-23 §23.4.3](23_quest_model.md) | Stage 의 하위 단위다 |
| **Objective kind** | `talk_to` `reach` `acquire` `deliver` `defeat` `flag_set` `var_reach` `choose` `survive` | 목표의 종류 **9종 닫힌 집합** | D-06 · [BP-23](23_quest_model.md) | 월드 이벤트 12종과 1:1 이 아니다 — 이벤트가 kind 를 **진행시킨다** |
| **누적형 목표** | 누적형 | `talk_to`/`deliver`/`defeat`/`choose`/`survive`. 월드 이벤트 1건 = 카운터 +1 | [BP-23 §23.4.4](23_quest_model.md) | 상태형과 구별 |
| **상태형 목표** | 상태형 | `reach`/`acquire`/`flag_set`/`var_reach`. 이벤트 수신 시 WorldState 를 다시 읽어 **절대값**으로 설정하고 stage 진입 시 1회 즉시 평가 | [BP-23 §23.4.4](23_quest_model.md) | 누적형과 구별 |
| **완료 래치** | Completion Latch | 목표 카운터가 `target` 에 닿으면 **고정**되어 어떤 이벤트로도 되감기지 않는 규칙. 상태 기계를 단조로 만들어 솔버의 종료를 보장한다 | [BP-23 §23.4.6](23_quest_model.md) | 되감김이 필요하면 `failConditions` 로 **명시**해야 한다 |
| **퀘스트 상태** | `inactive`/`active`/`completed`/`failed` | 퀘스트의 4상태. 되돌리기 없음(디버그 커맨드 제외) | D-06 | 맵의 이관 상태 4종과 이름이 다르니 혼동 주의 |
| **실패 가능 퀘스트** | missable | 되돌릴 수 없는 실수/불운으로 막힐 수 있는 퀘스트. `tags:["missable"]` 이면 솔버 `MISSABLE` 판정이 **정상 통과**가 된다 | [BP-23 §23.8](23_quest_model.md) · [BP-34 §5](34_headless_sim_and_solver.md) | D-16 의 선택 항목이라 1차 스코프 밖일 수 있다 |
| **tier** | `tier` | 퀘스트의 난이도·보상 등급. 적 레벨·보상 권장 범위와 대응표로 묶인다 | [BP-23 §23.9](23_quest_model.md) | `act`(서사 막)와 다르다 |
| **저널** | journal, "임무" | 퀘스트 진행 기록. `WorldState.journal` 은 append-only 이며 각 항목이 `atStep` 을 갖는다 | D-08 · [BP-41](41_journal_ui_spec.md) | 게임 안 표기는 **"임무"** 다(원작 감성, [BP-40 §40.6](40_gameplay_changes.md)) |

---

## 5. 대화

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **Dialogue** | Dialogue | 대화 그래프 1개. `speaker` + `entry`(조건부 진입) + `nodes` | D-07 · [BP-24](24_dialogue_model.md) | Quest 와 별개 엔티티. 퀘스트가 `play_dialogue` 로 부른다 |
| **Node** | Node | 대화의 한 노드. `lines`(문자열 키 배열) + 선택적 `header`/`onEnter`/`choices`/`next` | D-07 · [BP-24](24_dialogue_model.md) | RPG Maker MV 의 `page` 와 다르다 → §4 |
| **Choice** | Choice | 선택지. `text`(문자열 키) + 선택적 `when`/`effects`/`once` + `go` | D-07 · [BP-24](24_dialogue_model.md) | `Choice.id` 는 D-07 골격에 없으나 BP-24 가 추가했다(`choose` objective 가 참조하므로) |
| **entry** | `Dialogue.entry[]` | 조건부 진입 규칙 배열. **위에서부터 첫 true** 를 고른다 | D-07 | ⚠ MV `pages` 는 **번호가 가장 큰 것**을 고른다 — 이관 시 순서 반전 필요(부록 E-2) |
| **header** | `Node.header` | 대사 앞에 붙는 머리말 문자열 키. MV 계보가 아니라 **본 기획서의 독자 개념**이며 근거는 `tile_event_dispatcher.dart` 의 `setHeader('@B푯말에 써 있기를:')` | [BP-24](24_dialogue_model.md) · 부록 E-1 | MV `code 101` 은 header 가 아니다(표시 방식 지정) |
| **최대 깊이** | `maxDepth` | 대화 그래프 순회의 안전 상한. 무한 루프 방지 | [BP-24 §24.8](24_dialogue_model.md) | `kMaxDialogueSteps`(런타임 스텝 상한)와 별개 |
| **페이지** | page | 콘솔 1화면 분량. 콘솔은 13줄/페이지다 | `HDConfig.maxLinesPerPage`(코드) · [BP-24 §24.5](24_dialogue_model.md) | MV 의 `pages[]`(조건부 이벤트 페이지)와 **완전히 다른 것** |

---

## 6. 월드 상태와 세이브

> **소유는 [BP-25](25_world_state_and_save.md)** 다(D-18).

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **WorldState** | `WorldState` | 런타임 상태의 단일 저장소. flags·vars·quests·inventory·npcStates·visited·journal·seed·step 을 담는다 | D-08 · [BP-25 §2](25_world_state_and_save.md) | `HDGameOption`(레거시 정수 배열)과 구별 → §4 |
| **WorldStateView** | `WorldStateView` | **읽기 전용** 인터페이스. `ConditionEvaluator`·목표 판정·저널 UI 가 이것만 받는다 | [BP-25 §3.2](25_world_state_and_save.md) | Mutator 와 구별 → §4 |
| **WorldStateMutator** | `WorldStateMutator` | **쓰기 전용** 인터페이스. `EffectApplier` 만 받는다 | [BP-25 §3.3](25_world_state_and_save.md) | View 와 구별 → §4 |
| **논리 시각** | `step` | 월드 이벤트를 하나 처리할 때마다 1 증가하는 단조 증가 정수. **벽시계는 절대 쓰지 않는다** | **D-08a** · [BP-25 §2.4](25_world_state_and_save.md) | `rngCursor`(난수 소비 수)와 증가 시점이 다르다 → §4 |
| **시드** | `seed` | 월드 난수의 뿌리. 세이브에 저장된다 | D-08 · [BP-27](27_runtime_engine.md) | `step` 과 함께 `chance` 해시의 입력이 된다 |
| **난수 커서** | `rngCursor` | 난수를 몇 번 소비했는지 세는 카운터. 세이브에 저장되어 로드 후에도 수열이 이어진다 | [BP-25](25_world_state_and_save.md) · [BP-27 §9.2](27_runtime_engine.md) | `step` 과 다르다 → §4 |
| **WorldRng** | `WorldRng` | 시드 난수의 **유일한 소유자**. `seed` + `rngCursor` 로 재현되며 **Effect·전투 등 쓰기 경로 전용**이다 | [BP-27](27_runtime_engine.md) | Condition 은 절대 커서를 건드리지 않는다(D-21) |
| **세이브 v2 봉투** | envelope | 세이브 파일의 최상위 구조. 기존 `{version, party, gameSystem, gameOption, map}` 에 `worldState`·`currentMapName` 이 더해진다 | D-08 · [BP-25](25_world_state_and_save.md) | 필드명 전체의 정본은 BP-25 다. 다른 장은 링크만 |
| **mapDelta** | `mapDelta` | 맵 스냅샷을 원본 대비 **변경 칸만** 저장하는 방식. 부록 C-3(570 KB 문제)의 대응 | D-22 · [BP-25 §5.4](25_world_state_and_save.md) | 전체 스냅샷(옛 `map` 필드)과 구별 |
| **맵 base 종류** | `asset:<path>` / `generated` | 세이브 맵 항목의 출처 구분. `generated` 는 cm2 `Map::Init`/`Map::SetRow` 로 런타임 생성된 맵이라 델타 대상이 없어 **RLE 전체 스냅샷**을 쓴다 | **D-22** | 이 구분 없이는 실사용 cm2 8개에서 `mapDelta` 가 성립하지 않는다 |
| **레거시 플래그 다리** | `legacyFlagMap` | 이름 있는 플래그 ↔ 레거시 정수 인덱스(0~255) 대응표. 빌드가 `content.lock.json` 에 생성한다 | D-04 · [BP-28 §7](28_migration_and_coexistence.md) | 정본은 `WorldState`, 정수 쪽은 **파생 캐시**다(RK-28-2) |
| **마이그레이션** | `pack.json#migrations` | 콘텐츠 버전이 오를 때 기존 세이브를 옮기는 규칙 | D-08 · [BP-21](21_content_pack_spec.md) | 맵 **이관**(migration state)과 이름이 겹치니 주의 |
| **재시작 예외** | `GameReloadException` | 세이브 로드 성공 시 현재 실행 루프를 되감기 위해 던지는 예외. 스크립트 엔진은 이를 **조용히 무시**한다 | `lib/application/game_reload_exception.dart` | 에러가 아니다. 로그에 에러로 남기지 않는다 |

---

## 7. 앵커 · 엔티티 · 맵

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **앵커** | Anchor | 콘텐츠 엔티티(의미)와 맵 좌표(지형)를 잇는 바인딩. 맵 JSON 은 지형만, 팩은 의미만 갖고 앵커가 둘을 묶는다 | D-09 · [BP-26 §2](26_entity_registry_and_anchors.md) | 맵 JSON 의 `events[]` 는 **레거시 폴백**이다 |
| **앵커 kind** | `actor` `sign` `portal` `trigger` `container` `battle` | 앵커의 6종 분류. 각 kind 는 요구하는 `HDTileAction` 이 정해져 있다 | D-09 · [BP-26 §3.3](26_entity_registry_and_anchors.md) | Objective kind 와 무관한 별개 집합 |
| **앵커 우선순위** | `priority` | 같은 좌표+kind 에 앵커가 여럿일 때의 선택 순서. `when` 을 생략한 앵커가 2개 이상이면 빌드 하드 실패 | [BP-26 §4.4](26_entity_registry_and_anchors.md) | 같은 좌표의 **다른 kind** 는 자유롭게 공존한다(R-26-18) |
| **트리거 인덱스** | `TriggerIndex` | `(map, x, y, kind)` → 앵커를 **O(1)** 로 찾는 런타임 인덱스. 현행 `map.events` 선형 탐색을 대체한다 | [BP-26 §5](26_entity_registry_and_anchors.md) · [BP-20 §8.3](20_target_architecture.md) | 역참조 인덱스(`xref`)와 다르다 |
| **역참조 인덱스** | `xref` | "이 ID 를 누가 참조하는가" 를 담은 인덱스. **런타임이 읽지 않고** 린트·증분 검사·생성 컨텍스트가 쓴다 | [BP-26 §5](26_entity_registry_and_anchors.md) · R-35-22 | 예산 초과 시 가장 먼저 번들에서 빠지는 후보 |
| **별칭 사전** | `aliases` | 고유명사와 그 변형의 사전. 지식 범위 검사(Aho–Corasick)의 근거이며 **길이 내림차순 정렬**로 최장 일치를 전제한다 | [BP-22 §8.2](22_world_bible_model.md) · [BP-33 §8.2](33_validation_and_lint.md) | 사전에 없으면 검사가 **조용히 통과**한다(Q-22-7) |
| **place** | `place.<pack>.<slug>` | 콘텐츠상의 **장소**. 맵과 1:N 이며 지역 톤·위험도를 갖는다 | D-03 · [BP-22 §4](22_world_bible_model.md) | `map`(파일 단위 지형)과 구별 → §4 |
| **actor** | `npc.<pack>.<slug>` | NPC 의 정체성. 좌표가 아니라 **actorId 로 식별**되므로 이동·재배치에도 대화가 따라온다 | D-16-5 · [BP-22 §5](22_world_bible_model.md) | 앵커(`kind:"actor"`)는 그 actor 를 맵에 놓는 바인딩이다 |
| **item** | `item.<pack>.<slug>` | 아이템 카탈로그 항목 | D-03 · [BP-22 §6](22_world_bible_model.md) | 실제 인벤토리 게임 규칙은 [BP-42](42_item_and_inventory.md) 소유 |
| **인카운터** | `encounters.json` | 전투 조우 정의. 적은 **참조는 되지만 콘텐츠가 정의하지는 않는** 유일한 개념이다(하드코딩 테이블) | [BP-22 §7](22_world_bible_model.md) | 적 자체는 `enemy_data.dart` 의 **74종(id 1~74)**. id 0 은 소환 불가(부록 B-1) |
| **위험도** | `danger` (0..5) | 장소의 위험 등급. `encounterRate` 기본값(= `danger*2`)의 근거 | [BP-22 §4.6](22_world_bible_model.md) | 퀘스트 `tier` 와 다르다 |
| **region** | region 레이어(z5) | 맵 에디터의 6번째 레이어. 로더가 `ixEvent` 하위 바이트에 넣지만 **타일 액션 마스크는 상위 바이트만 본다** — 읽히기만 하고 아무 효과가 없다. **`trigger` 앵커용 200~255 예약안은 D-27 로 폐기**(§17.6) | 부록 **J-1**·**J-3** · D-27 | `objUpper`(z3, 통행 판정)와 다르다. 타일 액션의 실제 출처는 **3개뿐**(`events[]` 이름 접두사 / `ixObj1` B타일 대역 / `ixTile` A5 대역) |
| **activation** | `activation` | 앵커의 **발화 조건 선언**. `interact` \| `step_on` \| `both` 세 값이며 **트리거 인덱스 3단 키의 성분**이다. D-27 이후 이것이 발화 조건의 **유일한 선언**이고, 타일이 무엇이든 앵커는 발화한다 | [BP-26 §2.2·§4.1](26_entity_registry_and_anchors.md) (**소유**) | `HDTileAction` 이 **아니다** — 인덱스 3단 키가 초판에 `HDTileAction` 으로 적혀 있던 것을 정정한 결과다. 런타임 측 대응 타입은 `HDAnchorActivation`(`stepOn`/`interact` 2값)이며, `both` 를 **두 키로 펼치는 것은 빌드의 일**이다 |
| **트리거 인덱스 직접 조회** | trigger index direct lookup | 콘텐츠 티어가 **타일 액션 게이트보다 앞에서** `(map, x, y, activation)` 로 트리거 인덱스를 조회하고, 앵커가 있으면 타일 액션과 **무관하게** 처리하는 발화 방식. region 예약안을 대체한다 | **D-27** · [BP-26 §3.5](26_entity_registry_and_anchors.md) | 앵커가 맵 데이터에 **아무 표시도 남기지 않는다**는 점이 핵심. `map.events` 선형 탐색(레거시 폴백)과 다르다 |
| **HDAnchorActivation** | `HDAnchorActivation` | 티어 0 의 **질의 키**. `stepOn` / `interact` 두 값이며 `HDAnchorActivation.of(isInteraction: …)` 이 유일한 변환 지점이다. 타일 액션을 인자로 받지 않는다 | **D-27** · [BP-27 §2.0](27_runtime_engine.md) | `HDTileAction`(레거시 3티어의 분기 키)과 **다르다.** 티어 0 에서 `HDTileAction` 은 진단용 부가 정보일 뿐이다(R-27-16~18) |

---

## 8. 런타임 실행

> **소유는 [BP-27](27_runtime_engine.md)** 이다(D-18).

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **4티어 디스패치** | tier 0~3 | 타일 상호작용의 우선순위 사슬 — 0 Content / 1 native / 2 cm2 / 3 JSON. 위 티어가 처리하면 아래로 내려가지 않는다 | D-10 · [BP-28 §2](28_migration_and_coexistence.md) | 현행 코드는 **3티어**다(티어 0 이 없다) |
| **티어 0 / 콘텐츠 티어** | Content tier | 앵커가 있는 좌표에서 `ContentRuntime` 이 처리하는 최상위 티어 | D-10 | 앵커가 없는 맵에서는 조회 비용도 0(해시 미스) |
| **handled** | `bool handled` | 티어가 "내가 처리했다" 를 알리는 **공통 신호**. 티어별 특수 신호를 만들지 않는다 | `R-28-1`([BP-28](28_migration_and_coexistence.md)) | cm2 는 `Event::Override()` 로 이 신호를 세운다 |
| **pendingNavigation** | `pendingNavigation` | 맵 전환을 **예약**해 두는 자리. 현행은 cm2 엔진 소유이지만 D-19 로 **세션/런타임 공용 개념으로 승격**되었다 | **D-19** · [BP-27 §4.4](27_runtime_engine.md) · `tile_event_dispatcher.dart:99` | narrative flush 여부(`autoFlush`)가 이 값에 결합돼 있다 |
| **재진입 가드** | `_isScriptRunning` | "한 번에 하나의 상호작용" 을 보장하는 **유일한 상호배제 지점**. 티어 0 은 자체 가드를 두지 않는다 | D-10 · `R-28-2`([BP-28](28_migration_and_coexistence.md)) | 전역 bool 하나다(G-19) |
| **narrative 사이클** | `beginNarrative()` … `endNarrative()` | 콘솔 출력을 한 덩어리로 묶는 구간. **소유자는 디스패처**이며 `DialogueRuntime` 은 직접 부르지 않는다 | [BP-27 §5.2](27_runtime_engine.md) · `ports/ui_host.dart` | `refresh()`(순수 재그리기)와 구별 → §4 |
| **월드 이벤트** | world event | 게임 안 사건의 발행 단위. **D-20 이 12종을 정본으로 확정**했다 — `talk` `enter_place` `step_tile` `battle_won` `item_gained` `item_lost` `flag_changed` `var_changed` `dialogue_choice` `map_changed` `gold_changed` `party_rested`. **payload 의 정본은 [BP-23 §23.11.1](23_quest_model.md)** 이다(D-20a) | **D-20** · **D-20a** · [BP-23](23_quest_model.md)(소유) | 소문자 snake_case, **동사 과거형 금지**. 폐기된 변형은 §17.1 |
| **월드 이벤트 버스** | `WorldEventBus` | 위 이벤트를 발행·구독하는 배선. 전투 승리·아이템 획득 등이 퀘스트 목표를 자동 진행시키는 통로 | D-16-6 · [BP-27](27_runtime_engine.md) | 발행 지점이 아직 없는 이벤트는 **미발행**임을 각 장이 명시해야 한다(D-20) |
| **ContentRuntime** | `ContentRuntime` | 앵커 → 대화/퀘스트 실행의 진입점 | D-11 · [BP-27 §2](27_runtime_engine.md) | `ContentRepository`(번들 로드)와 다르다 |
| **onMapEntered** | `onMapEntered(mapName, x, y)` | 맵 진입 시 콘텐츠 런타임이 받는 훅 | [BP-27 §3](27_runtime_engine.md) | 부팅 시퀀스와 패치가 **이중 호출**을 만들 위험이 지적됐다(REVIEW_BP-27 F-11) |

---

## 9. 이관 · 레거시

> **소유는 [BP-28](28_migration_and_coexistence.md)** 이다(D-18).

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **이관 상태** | `legacy` / `shadowed` / `migrated` / `frozen` | 맵 단위 4상태 기계. `anchors/<MAPNAME>.json#migration` 에 기록하고 `content.lock.json` 이 롤업한다 | [BP-28 §3](28_migration_and_coexistence.md) | 퀘스트 상태 4종과 다른 집합 |
| **legacy** | `legacy` | 콘텐츠 앵커 없음. 지금까지와 완전히 동일. 앵커 파일이 없으면 **자동으로** 이 상태 | [BP-28 §3.1](28_migration_and_coexistence.md) | 상태 미명시 앵커 파일은 빌드 실패(암묵 승격 금지) |
| **shadowed** | `shadowed` | 앵커는 있으나 실제 출력은 여전히 레거시. 콘텐츠 티어는 **드라이런**으로 트레이스만 남긴다 | [BP-28 §3.1](28_migration_and_coexistence.md) | 이 상태의 목적은 동등성 증명이다 |
| **migrated** | `migrated` | 콘텐츠 티어가 실제 출력을 담당. 레거시 훅은 남아 있으나 도달하지 않는다 | [BP-28 §3.1](28_migration_and_coexistence.md) | JSON 선-방출이 꺼진다 |
| **frozen** | `frozen` | 레거시 훅이 물리적으로 삭제됨. **되돌릴 수 없는 결정**이라 `migrated` 2주기 유지가 전제 | [BP-28 §3.1](28_migration_and_coexistence.md) · `R-28-9` | 롤백 대상이 아니다(RK-28-7) |
| **shadow 모드** | shadow | 콘텐츠 경로를 드라이런으로 돌리고 레거시 출력과 **트레이스를 대조**하는 검증 방식 | [BP-28 §4](28_migration_and_coexistence.md) | 골든 회귀와 다르다 — 이쪽은 **두 경로의 동시 비교** |
| **RecordingUiHost** | `RecordingUiHost` | 모든 `UiHost` 호출을 순서대로 적재하는 테스트용 호스트. **런타임 바이너리에 포함하지 않는다** | [BP-28 §4](28_migration_and_coexistence.md) · `R-28-6` | `HeadlessUiHost`(시뮬레이터용)와 목적이 다르다 |
| **킬 스위치** | kill switch | 콘텐츠 티어를 끄는 3단계 장치(전역/팩/맵). **맵 단위 강등이 1차 대응 수단** | [BP-28 §8.1](28_migration_and_coexistence.md) · `R-28-10` | 롤백(팩 되돌림)과 다르다 |
| **JSON 선-방출** | `legacyJsonPreEmit(mapName)` | 네이티브 맵에서 JSON 대사를 먼저 내보내는 레거시 동작. 런타임은 `content.lock.json#migration` 을 읽어 결정하며 **맵 이름 하드코딩 금지** | [BP-28](28_migration_and_coexistence.md) · `R-28-5` | 현행 코드는 무조건 선-방출한다 |
| **cm2** | CM2 | 원작 이식용 스크립트 DSL. 들여쓰기 블록, `if/else`, `name.method(args)`. **루프·함수 정의·산술이 없다**(튜링 완전이 아니다) | `packages/cm2_script/` · GROUND_TRUTH §9 · 부록 E-3 | 신규 AI 콘텐츠의 생성 타깃이 **아니다**(D-02) |
| **`Event::Override()`** | `Event::Override()` | cm2 가 "내가 처리했다" 를 알리는 내장 커맨드. 호출하지 않으면 JSON 대사가 중복 방출된다 | `script_engine_adapter.dart` · GROUND_TRUTH §4 | 티어 0~2 공통 신호 `handled` 의 cm2 표현 |
| **침묵 실패** | silent failure | cm2 의 대표 실패 양식 **2계열** — ① 미등록 심볼(오타) → 함수는 **0 반환**해 조용히 오분기 ② 정상 심볼인데 **범위 밖 인자** → 로그 없이 no-op | GROUND_TRUTH §9 · 부록 F-1 | 두 계열은 원인이 다르다. D-02·D-04 의 직접 근거 |
| **scriptMode** | `HDTileAction.scriptMode` | cm2 로 넘어가는 **와이어 값**(0~4). `assets/const.cm2` 의 `FLAG_MAP`/`FLAG_TALK`/`FLAG_SIGN`/`FLAG_EVENT`/`FLAG_ENTER` 와 대응 | `domain/map/tile_properties.dart` · `test/domain/map/tile_action_test.dart` | **`Enum.index` 가 아니다.** 절대 index 로 바꾸지 말 것 |
| **HDTileAction** | `enum HDTileAction` | 타일 액션 10종(`none` `talk` `sign` `event` `enter` `water` `swamp` `lava` `cliff` `move`). `isInteractive`/`isStepOn`/`debugTag` 를 갖는다 | `domain/map/tile_properties.dart` | 앵커 kind 와 대응 관계는 [BP-26 §3.3](26_entity_registry_and_anchors.md) |
| **MapBundle** | `MapBundle {mapName, json?, cm2Path?}` | 맵 이름 해석의 결과 묶음. `HDMapNavigation.loadByName(name)` 이 반환한다 | `application/map_navigation.dart` | ⚠ 현재 `json == null` 인데도 "성공" 으로 반환된다(부록 D-2) |

---

## 10. 툴체인

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **Content Server** | Content Server | 기존 맵 에디터 dev 서버를 **같은 프로세스로** 확장한 `/api/content/*` REST 서버 | D-12 · [BP-31](31_content_server_api.md) | 별도 인프라가 아니다 |
| **hadar_content CLI** | `hadar_content` | 순수 Dart CLI. `build` `validate` `lint` `sim` `solve` `diff` `stats` `migrate` `new`. **런타임 평가기를 그대로 import** 한다 | D-12 · [BP-30 §4](30_toolchain_overview.md) | Flutter 를 의존하지 않는다(`INV-20-04`) |
| **MCP 서버** | MCP wrapper | 위 둘을 AI 에이전트에게 노출하는 래퍼. 도구 이름은 `content_*` 로 통일. **자체 로직을 갖지 않는다** | D-12 · [BP-31 §6](31_content_server_api.md) | 기존 맵 도구 `map_*` 와 이름 공간이 다르다 |
| **배치 편집** | `ops` | 여러 편집을 한 요청에 담는 규약. 맵 API 의 `set/rect/fill/setCells/…` 철학을 콘텐츠 API 가 계승한다 | [BP-31 §3](31_content_server_api.md) · GROUND_TRUTH §11 | 트랜잭션 단위이자 되돌리기 단위 |
| **낙관적 잠금** | `rev` | 동시 편집 충돌을 감지하는 리비전 번호 | [BP-31 §4](31_content_server_api.md) | 파일 락이 아니다 |
| **힌트 포함 에러** | `{error, code, hint}` | 무엇이 틀렸는가 + **어떻게 고치는가**를 함께 내는 에러 규약. 맵 에디터 API 의 `{error, hint}` 를 계승 | [BP-31 §5](31_content_server_api.md) · GROUND_TRUTH §11 | AI 재시도 프롬프트가 이것을 그대로 먹는다 |
| **증분 캐시** | `.hadar_cache/` | 증분 검사용 캐시. 키는 `(파일 SHA-256, 규칙 카탈로그 버전, CLI 버전)` 삼중. **커밋하지 않는다** | [BP-33 §8.3](33_validation_and_lint.md) | 증분은 로컬·서버 응답용이고 CI 는 항상 `--full` |
| **자기기술 가이드** | `GET /api/content` | 서버가 스스로 반환하는 기계 가독 사용 설명. 기존 `GET /api/ai` 의 계승 | [BP-31 §7](31_content_server_api.md) | 문서 이중화를 줄이는 장치 |

---

## 11. 검증 · 시뮬레이션 · 게이트

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **검증 5계층** | L1~L5 | L1 스키마 / L2 참조무결성 / L3 그래프 구조 / L4 시맨틱·세계관 / **L5 실행 가능성** | [BP-33 §2](33_validation_and_lint.md) · [BP-34 §1.1](34_headless_sim_and_solver.md) | L1~L4 는 정적, **L5 만 "상태가 시간에 따라 변한다"** 를 본다 |
| **하드 게이트** | Hard gate | 하나라도 실패하면 **커밋 불가**. 판정 근거가 항상 실행 가능한 검사이며 **우회 경로가 없다** | D-15 · [BP-53 §53.2](53_acceptance_criteria.md) | Critic 은 하드 게이트 판정 권한이 **없다**(R-37-14) |
| **소프트 게이트** | Soft gate | 경고 + 검수 에이전트/사람 판단 영역. 차단하지 않는다 | D-15 · [BP-37 §37.5.2](37_prompt_contracts.md) | 기계는 소프트 축을 **판정하지 않는다** — 수치만 제공 |
| **심각도** | ERROR / **RELEASE** / WARN / INFO | 검증 결과의 **4등급**. ERROR 는 커밋 차단(종료 코드 2), **RELEASE 는 커밋 통과·릴리스 차단**(D-26 신설), WARN 은 검수 입력, INFO 는 관찰 | [BP-33 §5.1](33_validation_and_lint.md) | 하드/소프트 게이트와 대응하지만 **같은 말은 아니다**. `RELEASE` 는 ERROR·WARN 과 **별개 열**이다 |
| **승격** | promote | WARN → ERROR. 배수 초과·`--strict`·반복 위반·팩 정책·blocking finding 5경로 | [BP-33 §5.2](33_validation_and_lint.md) | 강등(demote)은 원칙적으로 금지 |
| **억제** | `_lintIgnore` / suppression | 규칙을 개별로 끄는 장치. **사유가 없으면 억제되지 않고**, 솔버 쪽 suppression 은 **만료가 필수**다 | [BP-33 §5.3](33_validation_and_lint.md) · [BP-34 §11.4](34_headless_sim_and_solver.md) | L1·L2·`V-DET-*` 는 어떤 방법으로도 억제 불가 |
| **헤드리스 하네스** | headless harness | 화면 없이 게임을 구동하는 장치. `HeadlessUiHost` + `MemoryAssetSource` + `ScriptedMovementHost` 를 `HDHosts().bind(...)` 로 주입 | D-13 · [BP-34 §3](34_headless_sim_and_solver.md) | **신규 발명이 아니라 기존 포트 3종의 활용**이다(GROUND_TRUTH §3) |
| **SimDriver** | `SimDriver` | 정책에 따라 입력을 자동 생성하는 구동기 | D-13 · [BP-34 §4](34_headless_sim_and_solver.md) | 솔버와 다르다 — 이쪽은 **실제로 굴린다** |
| **입력 정책 3종** | `scripted` / `greedy` / `random` | 주어진 입력열 재생 / 목표를 향한 탐색 / **시드 고정 퍼징** | D-13 · [BP-34 §4](34_headless_sim_and_solver.md) | `greedy` 성공은 증명이 아니라 **증인(witness)** 이다 |
| **PartyMovementController** | `PartyMovementController` | 이동·상호작용 판정을 `presentation/` 에서 `application/` 으로 끌어낸 신규 클래스. 헤드리스의 **선결 과제** | [BP-34 §2.2.2](34_headless_sim_and_solver.md) · 부록 B-3 | `PartyMovementHost` 포트(애니메이션 위임)와 다르다 |
| **QuestSolver** | `QuestSolver` | `WorldState` 를 노드로 보는 상태 공간 탐색으로 "이 퀘스트는 완주 가능한가" 를 증명/반증한다 | D-13 · [BP-34 §5](34_headless_sim_and_solver.md) | 시뮬레이터와 다르다 — 이쪽은 **상태를 추상화**한다 |
| **솔버 판정 4종** | `PROVEN` / `UNREACHABLE` / `MISSABLE` / `INCONCLUSIVE` | 완주 증명 / 반증(**하드 게이트**) / 되돌릴 수 없는 실수 존재(소프트) / 예산 초과(**실패가 아님**) | [BP-34 §5](34_headless_sim_and_solver.md) | `INCONCLUSIVE` 를 실패로 읽는 것이 오탐 FP-3 이다. **D-26 이후 이 4종은 "모델 증명" 축의 값이며, 판정은 4종이 아니라 2축이다** → 다음 행 |
| **솔버 판정 2축** | 모델 증명 축 × 실행 가능 축 | D-26 이 확정한 구조. **모델 증명**(콘텐츠 그래프상 완주 경로가 있는가)과 **실행 가능**(그 경로가 현행 빌드에서 돌아가는가)은 **독립 축**이며 하나로 접지 않는다 | **D-26** · [BP-34 §5.1·§5.10](34_headless_sim_and_solver.md) | 접으면 "돌아가지 않는 콘텐츠" 가 통과한다 — BP-91 W-10 이 실제로 그렇게 되어 D-26 을 촉발했다 |
| **SUPPORTED / UNSUPPORTED** | `SUPPORTED` / `UNSUPPORTED` | **실행 가능 축**의 두 값. 완주 경로가 의존하는 **모든 월드 이벤트에 현행 빌드의 발행 지점이 존재하면** `SUPPORTED`, 하나라도 없으면 `UNSUPPORTED` | **D-26** · [BP-34 §5.10](34_headless_sim_and_solver.md) · [BP-33 §4.7](33_validation_and_lint.md) | `PROVEN`(모델 증명)과 **독립 축**이다 → §15 X-19. 판정 근거는 **발행 지점 레지스트리 대조**이며 상태 탐색이 아니다 |
| **발행 지점 레지스트리** | `eventPublishers` (`content.index.json`) | 이벤트 12종마다 현행 빌드에 발행 지점이 있는지를 `published`/`unpublished` 로 굽는 산출물. 솔버의 실행 가능 축이 이것과 대조한다 | **D-26** · [BP-35 §1.5.1](35_ci_and_build.md) (**생성 소유**) | 정본 입력은 선언 파일 `tools/content_cli/event_publishers.json` 이고 **코드 대조는 빌드가 아니라 CI** 가 한다(R-35-11e). 트리거 인덱스와 무관하다 |
| **RELEASE 심각도** | `RELEASE` | 심각도의 **네 번째 등급**(BP-33 신설). "콘텐츠는 정상이지만 그 콘텐츠가 쓰는 게임 기능이 아직 없다" — **커밋은 허용**되고 팩이 "미활성" 으로 표시되어 **릴리스 게이트에서 차단**된다 | **D-26** · [BP-33 §5.1](33_validation_and_lint.md) · `V-L5-007` | ERROR(커밋 차단)도 WARN(단순 경고)도 아니다. 종료 코드는 `0` 이며 `--gate=release` 에서만 `2`. CI 주석은 `::error` 가 아니라 `::notice` 로 낸다 |
| **modelVerdict / supportVerdict** | `modelVerdict` / `supportVerdict` | CI 리포트(`--format=ci`)가 **두 축을 각각** 출력하는 두 필드. 앞은 `PROVEN`/`REFUTED`/`UNKNOWN` 계열, 뒤는 `SUPPORTED`/`UNSUPPORTED` | [BP-33 §7.2](33_validation_and_lint.md) · R-33-54~57 | 두 필드를 하나로 합치거나 한쪽만 출력하면 D-26 이 막으려던 상태로 되돌아간다 |
| **증인 / 반례** | witness / counterexample | 완주 가능함을 보이는 **액션열** / 도달 집합에서 참이 된 적 없는 **조건 원자** | [BP-34 §5](34_headless_sim_and_solver.md) | witness 재생 실패 = 추상화 결함(FP-2) |
| **퍼징** | fuzzing | 시드 고정 랜덤 입력으로 크래시·데드락·계약 위반을 찾는 것 | D-13 · [BP-34 §6](34_headless_sim_and_solver.md) | 커버리지 미달은 소프트, **크래시 0 만 절대 기준** |
| **골든 트레이스** | golden trace | 헤드리스 시뮬레이션의 이벤트·상태 전이 시퀀스를 고정한 파일(JSON Lines). 회귀 검출의 기준선 | [BP-35 §6](35_ci_and_build.md) | 문자열 **키만** 싣고 한국어 텍스트는 싣지 않는다(R-35-36) |
| **골든 3종** | G-1 / G-2 / G-3 | 산출물 골든(커밋된 `build/*.json` 자체) / 진단 골든(고의 위반 픽스처의 리포트) / 트레이스 골든 | [BP-35 §6.1](35_ci_and_build.md) | G-1 은 별도 골든 파일을 만들지 않는다 — `git diff --exit-code` 가 비교자 |
| **커버리지 지표** | `anchorCoverage` 등 8종 | 방문한 앵커·노드·선택지·스테이지·맵·장소·`do`·`op` 의 비율. **전부 소프트** | [BP-34 §6.3](34_headless_sim_and_solver.md) | 하드로 걸면 무의미한 앵커 추가를 유발한다 |
| **델타 디버깅** | delta debugging | 실패 트레이스의 입력열을 이분 축소해 **최소 재현 시퀀스**를 찾는 절차 | [BP-34 §6](34_headless_sim_and_solver.md) | 오탐 처리 5단계의 2번째 |
| **오탐 3종** | FP-1 / FP-2 / FP-3 | 하네스 버그 / 추상화 과다 / 미확정을 실패로 오독 | [BP-34 §11.3](34_headless_sim_and_solver.md) | 판별은 자기 테스트 통과 여부 + witness 재생 여부로 |
| **불변식** | `INV-20-nn` | **자동 검증 수단을 반드시 갖는** 아키텍처 명제. 수단이 없는 명제는 불변식이 아니라 열망이다 | [BP-20 §9](20_target_architecture.md) | 요구사항(`R-nn-n`)과 다르다 |

---

## 12. 생성 하네스 · 프롬프트

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **컨텍스트 팩** | `context_pack.json` | 생성 에이전트에게 주는 자료 묶음. P0~P7 우선순위 블록으로 조립하고 **총 60,000 토큰** 예산 안에서 절단된다 | [BP-32 §32.5](32_generation_harness.md) | Content Pack(콘텐츠 배포 단위)과 **완전히 다른 것** |
| **주문서** | `orders/<orderId>.json` | 사람이 쓰는 생성 요구. `intent`·`constraints` 를 담고 HG-1 승인 대상이다 | [BP-32 §32.2.4](32_generation_harness.md) | outline(설계도)과 다르다 |
| **outline** | `outline.<questId>.json` | 2단계 산출물. 비트·등장인물·장소·스테이지 골격·신규 엔티티 요청 | [BP-32 §32.3](32_generation_harness.md) | 가장 싼 개입 지점(HG-2) |
| **에이전트 역할** | Planner / Writer / Binder / Critic / StyleEditor / Orchestrator | 하네스의 6역할. **권한 경계**가 각각 정의돼 있다 | [BP-32 §32.4](32_generation_harness.md) | Binder·Orchestrator 는 LLM 이 아니다 |
| **Critic** | Critic, 검수 에이전트 | 7단계의 LLM 검수자. 8축 루브릭으로 채점하고 findings 를 낸다. **Hard 항목 판정 권한 없음** | [BP-37 §37.5](37_prompt_contracts.md) | 이 기획서 자체의 검수 에이전트(`_meta/REVIEW_RUBRIC.md`)와 **다른 것** |
| **루브릭 8축** | `Q1_lore` … `Q8_integration` | 세계관 정합 / 목소리 / 서사 구조 / 명료성 / 밸런스 / 문체 / 참신성 / 통합성. **8개 고정** | [BP-37 §37.5.1](37_prompt_contracts.md) | 기획서 검수 루브릭 7축(A~G)과 다르다 |
| **verdict** | `pass` / `conditional` / `revise` | Critic 판정 3종. 산식은 `minAxis`·`total`·blocking finding 으로 결정된다 | [BP-37 §37.5.3](37_prompt_contracts.md) | **대부분이 `conditional` 로 나오는 것이 정상**이다(R-37-16) |
| **finding** | finding, `severity` | Critic 이 내는 개별 지적. `blocking`/`major`/`minor`. **blocking 이 하나라도 있으면 점수와 무관하게 `revise`** | [BP-37 §37.5](37_prompt_contracts.md) | 린트 진단(`V-*`)과 다르다 |
| **사람 승인 게이트** | HG-1 / HG-2 / HG-3 | 주문서 확정 / outline → draft / critic → commit. **HG-3 은 절대 위임하지 않는다** | [BP-32 §32.8](32_generation_harness.md) | HG-2 만 좁은 조건에서 자동 승인 가능 |
| **격리** | quarantine | 재시도 예산을 소진한 산출물을 `quarantine/<slug>/` 로 보내는 것. **삭제가 아니고, 배치를 멈추지도 않는다** | [BP-32 §32.6.4](32_generation_harness.md) | 슬러그는 재사용 금지 |
| **Repair** | Repair 되돌림 | 5단계 위반을 3단계로 되돌리는 것. **전체 재생성이 아니라** 위반 항목의 JSON Pointer + hint 만 준다 | `R-32-18`([BP-32](32_generation_harness.md)) | outline 되돌림(설계 결함)과 다르다 |
| **프롬프트 세트** | `promptSet` | 프롬프트 묶음의 버전 태그. 즉흥 수정 금지 — 고치려면 `prompts/*.v2.md` 를 만든다 | [BP-37 §37.8](37_prompt_contracts.md) | `rubricVersion`(채점표 버전)과 별개 |
| **실행 지표** | `runs.jsonl` | 실행 1건 = 1줄. `passRate`·`firstPassYield`·`hardPerQuest`·`rubricAvg`·`determinismMatch` 등을 적재 | [BP-32 §32.10](32_generation_harness.md) | 목표치는 [BP-53 §53.4](53_acceptance_criteria.md) 소유 |
| **재현성 매니페스트** | `manifest.json` | 실행의 단계·프롬프트 해시·승인 기록을 담아 **재개 가능**하게 만드는 파일 | [BP-32 §32.7](32_generation_harness.md) | `content.lock.json`(빌드 증빙)과 다르다 |

---

## 13. 세계관 바이블

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **세계관 바이블** | world bible | `world/lore.json`·`factions.json`·`places.json` + `actors/` 로 이루어진 세계관 SSoT. 컨텍스트 팩의 원재료 | D-03 · [BP-22](22_world_bible_model.md) | 게임 데이터가 아니라 **생성·검증의 근거**다 |
| **지식 범위** | knowledge scope, `knowledge` | 액터가 **아는 것(`knows`)과 모르는 것(`unknown`)** 의 명시적 선언. BP-22 가 자기 문서의 "핵심" 으로 지목한 개념 | [BP-22 §5.4](22_world_bible_model.md) | 하드 게이트 H-12 의 대상. 별칭 사전 품질에 의존한다 |
| **연대기** | `chronicle` | 사건 목록과 `order`(시간축). 액터가 "아직 일어나지 않은 사건" 을 말하는지 판정하는 근거 | [BP-22 §2.3](22_world_bible_model.md) | 실제 날짜가 아니라 **순서**다 |
| **금기** | `taboos` | 세계관상 언급하면 안 되는 것들. `detect.keywords` 로 기계 검출한다 | [BP-22 §2.5](22_world_bible_model.md) | 문체 금칙(현대어·이모지)과 겹치지만 다른 축 |
| **말투 지침** | `_voice` | 액터의 어휘·리듬·태도를 프롬프트에 주입하기 위한 지시문. 예 "짧고 각지게. '…하시오' 체" | [BP-22 §5](22_world_bible_model.md) | Critic Q2 의 판정 기준이 된다 |
| **요약 / 톤 힌트** | `_summary` / `_toneHint` | 컨텍스트 팩에 실릴 압축 서술과 톤 지시 | [BP-22](22_world_bible_model.md) | `_promptNote` 는 그대로 실리는 보조 지시 |
| **고유명사 표기 정책** | `properNounStyle` | `latin_kept` 등. 원작대로 `Necromancer`·`Lord Ahn` 을 로마자로 유지할지 음차할지 | [BP-22 §3](22_world_bible_model.md) | 위반은 warn(별칭 사전 역매칭) |
| **분위기 태그** | `mood` | 장소·장면의 분위기 태그 집합 | [BP-22 §4](22_world_bible_model.md) | 닫힌 집합 여부가 자기모순으로 지적됐다(REVIEW_BP-22 S-05) |

---

## 14. 기존 코드 용어 (현행 레포에 이미 있는 것)

| 용어 | 원문/식별자 | 요약 | 정의처 | 구별 |
|---|---|---|---|---|
| **UiHost** | `UiHost` | 애플리케이션이 UI 에 대고 부르는 **추상 포트**. `showMenu`/`showWindowMenu`/`showMessageWindow`/`addLog`/`waitForAnyKey`/`clearLogs`/`setHeader`/`beginNarrative`/`endNarrative`/`refresh`/`preloadAssets` | `lib/application/ports/ui_host.dart` | 구현체 `HDFlutterUiHost`·`HeadlessUiHost`·`RecordingUiHost` 와 구별 |
| **PartyMovementHost** | `PartyMovementHost` | 파티 이동 **애니메이션 위임** 포트. 이동 판정의 소유자가 아니다 | `lib/application/ports/movement_host.dart` · 부록 B-3 | `PartyMovementController`(신설 예정, 판정 소유)와 구별 |
| **AssetSource** | `AssetSource` | 텍스트 자산 읽기 포트(`loadString(path)`). **모든 자산 읽기가 이것을 통과한다** | `lib/application/ports/asset_source.dart` | 애플리케이션이 `rootBundle` 을 직접 만지면 계층 위반 |
| **HDHosts** | `HDHosts` | 포트 3종을 담는 **합성 루트**. `bind(ui:, movement:, assets:)` / `reset()`. bind 전 접근은 `StateError` | `lib/application/ports/host_binding.dart` | DI 컨테이너가 아니다 — 싱글턴 관례를 그대로 쓴다 |
| **HDBundleAssetSource** | `HDBundleAssetSource` | "데스크톱은 디스크 파일 우선, 아니면 `rootBundle`" 구현. 맵 에디터 편집을 재빌드 없이 반영시키는 장치 | `lib/presentation/host/bundle_asset_source.dart` | ⚠ 이 폴백이 웹 전용 결함(부록 A-4)을 데스크톱에서 가린다 |
| **HDGameMain** | `HDGameMain` | 계층을 엮는 얇은 파사드. `ChangeNotifier` 이며 UI 재빌드의 단일 listenable | `lib/hd_game_main.dart` | **`application/` 은 이것을 import 하지 못한다**(계층 규칙) |
| **HDGameSession** | `HDGameSession` | 세션 상태(현재 맵·맵 버전 등)의 소유자 | `lib/application/game_session.dart` | 파사드가 이 변경을 UI 로 전달한다 |
| **HDTileEventDispatcher** | `HDTileEventDispatcher.check(...)` | 타일 상호작용의 게이트이자 티어 분배기. narrative 사이클의 소유자 | `lib/application/tile_event_dispatcher.dart` | 티어 0 이 여기에 삽입된다(D-10) |
| **HDScriptEngine** | `HDScriptEngine` | cm2 어댑터. `setTargetPos`/`setScriptMode`/`run()`/`handled`/`pendingNavigation` | `lib/application/scripting/script_engine_adapter.dart` | ⚠ 로드 실패 시 `clearRuntimeState()` 미도달(부록 A-2) |
| **HDNativeScriptRunner** | `HDNativeScriptRunner` | 네이티브 맵 스크립트의 팩토리·레지스트리. **실제 `flags`/`variables` 구현을 갖고 있다** | `lib/application/scripting/native_script_runner.dart` | 이 상태는 **세이브되지 않는다**(GROUND_TRUTH §7) |
| **HDMapScript** | `HDMapScript` | 네이티브 맵 스크립트의 기반 클래스. `onLoad`/`onUnload`/`onTalk`/`onSign`/`onEvent`/`onEnter` | `lib/application/scripting/map_script.dart` | ⚠ `isFlagSet`/`setFlag` 가 **빈 스텁**이라 모든 조건 분기가 false(부록 A-3) |
| **입력 모드** | `HDInputMode {window, menu, dialogue, map}` | 키 입력의 4모드. 우선순위로 해석된다 | `lib/presentation/input/` · `docs/key_input_policy.md` | 이관 상태·퀘스트 상태와 무관한 별개 4종 |
| **콘솔 뷰 모드** | `HDConsoleViewMode {progress, overlay}` | 콘솔 패널의 표시 모드 | `lib/application/ports/ui_host.dart` | 입력 모드와 다르다 |
| **`refresh()`** | `UiHost.refresh()` | **순수 재그리기 요청**. 세션 변경 알림이 아니다 | `ports/ui_host.dart` · CLAUDE.md | 세션 변경 알림과 구별 → §4 |
| **narrative flush** | `endNarrative({summary, autoFlush})` | narrative 구간을 닫으며 진행 스크롤백에 반영할지 결정하는 것. `autoFlush` 는 `pendingNavigation == null` 에 결합돼 있다 | `ports/ui_host.dart` · `tile_event_dispatcher.dart:99` | D-19 가 이 결합을 명시적 설계 대상으로 승격했다 |
| **800×480 고정 레이아웃** | 800×480 + `FittedBox` | 맵(0,0/288×320) · 콘솔(288,0/512×320) · 상태(0,320) · 하단 컨트롤 · `HDWindowLayer` 오버레이 | `lib/hd_config.dart` · `UI_SPEC.md` · [BP-41 §41.1](41_journal_ui_spec.md) | 저널 UI 는 이 안에서 **신규 입력 모드 0개**로 구현해야 한다 |
| **재진입 가드(코드)** | `_isProcessingMove` / `_isScriptRunning` | 이동 처리 중 가드 / 스크립트 실행 중 가드. 후자가 티어 상호배제의 유일 지점 | `player_sprite.dart` · `tile_event_dispatcher.dart` | 둘은 다른 변수다 |

---

## 15. 혼동 주의 쌍

| # | A | B | 무엇이 다른가 |
|---|---|---|---|
| **X-01** | `UiHost.refresh()` | 세션 변경 알림(`HDGameSession.notifyListeners()`) | `refresh()` 는 **순수 재그리기**다. 세션 변경은 맵 전환 시 **per-map 진행 스크롤백을 지운다**. 타일 오버라이드·맵 타입 스왑·세이브 복원처럼 맵 상태를 제자리에서 바꾼 코드는 **`refresh()` 를 불러야** 한다 |
| **X-02** | 이름 있는 `flag.<pack>.…` | 레거시 정수 플래그 `0~255` | 이름 쪽은 "범위 밖" 이라는 실패 양식이 **없다**. 정수 쪽은 `Flag::Set(300)` 이 조용히 no-op 된다(부록 F-1). 신규 콘텐츠는 정수를 직접 쓰지 않고 `legacyFlagMap` 이 다리를 놓는다 |
| **X-03** | `place` | `map` | `place` 는 **의미**(장소·톤·위험도)이고 콘텐츠 팩 소유. `map` 은 **지형 파일**이고 맵 에디터 소유. 하나의 map 에 여러 place 가 들어갈 수 있다(1:N) |
| **X-04** | Condition `chance` | `WorldRng` | `chance` 는 **무커서 해시**라 커서를 밀지 않고 같은 스텝 안에서 항상 같은 값이다(D-21). `WorldRng` 는 **커서 소비형**이며 Effect·전투 등 쓰기 경로 전용이다. 이 구분이 Condition 의 순수성과 솔버 성립의 근거다 |
| **X-05** | Stage | Objective | Stage 는 퀘스트의 **단계**이고 `next` 로 DAG 를 이룬다. Objective 는 Stage **안의 목표**이며 `completion: all\|any` 로 묶인다. 진행률 계산식이 둘을 다르게 쓴다 |
| **X-06** | 하드 게이트 | Critic 판정 | 하드 게이트는 **기계 단독**이고 Critic 은 권한이 없다. Soft 축은 **기계가 판정하지 않는다**. 양방향으로 독립이며 어느 한쪽만 통과해도 실패다(R-37-14 · R-32-22) |
| **X-07** | 논리 시각 `step` | 난수 커서 `rngCursor` | `step` 은 **월드 이벤트 수**, `rngCursor` 는 **난수 소비 수**. 증가 시점이 달라 서로를 대체할 수 없다(REVIEW_BP-21 DR-01) |
| **X-08** | Content Pack | 컨텍스트 팩(`context_pack.json`) | 앞은 **게임에 실리는 콘텐츠**, 뒤는 **LLM 에게 주는 자료 묶음**. 한국어로 둘 다 "팩" 이라 가장 자주 헷갈린다 |
| **X-09** | `Dialogue.entry[]` | MV `pages[]` | `entry` 는 **위에서부터 첫 true**, MV `pages` 는 **번호가 가장 큰 것**. 이관 시 **순서를 반전**해야 한다(부록 E-2) |
| **X-10** | `Node.header` | MV `code 101` | `header` 는 본 기획서의 독자 개념(머리말 문자열). `code 101` 은 뒤따르는 `401` 들의 **표시 방식**(얼굴/배경/창 위치) 지정이며 텍스트를 담지 않는다(부록 E-1) |
| **X-11** | 맵 이관 상태 `migrated` | 세이브 `migrations` | 앞은 **맵 단위 4상태 기계**의 한 상태, 뒤는 **콘텐츠 버전 상승 시 세이브를 옮기는 규칙**. 둘 다 "마이그레이션" 으로 불러 혼동된다 |
| **X-12** | `chanceKey` (문자열 키) | `chanceSeedId` (빌드 상수) | **같은 개념의 두 이름이 아니라, 서로 다른 두 개체**다(D-29a). 앞은 `<contextId>#<evalPath>` 라는 **경로 문자열**이고 소유는 [BP-21 §6.5](21_content_pack_spec.md); 뒤는 그것을 `mix(hashString(...))` 로 **빌드가 한 번 해시해 번들에 굽는 정수**이고 소유는 [BP-27](27_runtime_engine.md)(생성은 [BP-35](35_ci_and_build.md)). **런타임은 정수만 섞는다** — 문자열을 다시 해시하지 않는다. 초판이 이 둘을 `siteId` 하나로 부른 것이 §17.7 의 사고였다. **Q-52-4 종결** |
| **X-21** | `chance` 의 **순수성** | `chance` 결과의 **영속성** | 순수성은 "**같은 스텝 안에서** 같은 조건을 몇 번 평가해도 같은 값" 이다(D-30 근거 2). **세이브 전체에 걸쳐 고정된다는 뜻이 아니다** — 유도식에 `step` 이 들어가므로 월드가 진행하면 같은 위치의 결과가 바뀐다. 결과를 영구히 고정하려면 Effect 의 `set_flag` 로 **래치**해야 한다(§15 X-22) |
| **X-22** | Condition `chance` | Effect `set_flag` 래치 | `chance` 는 **매 스텝 다시 굴려진다**. 따라서 플레이어가 나갔다 다시 들어오면 **재굴림(reroll)** 이 된다(D-30). 결과를 고정하는 것은 **상태 변경이므로 정의상 Effect 의 일**이다 — `chance` 로 분기한 뒤 `set_flag` 로 래치하고, 이후에는 `flag` op 로 읽는다. **Condition 만으로 영구 결과를 만들려는 설계는 하지 않는다.** [BP-33](33_validation_and_lint.md) 이 "`chance` 만으로 분기하고 래치가 없는 곳" 을 WARN 으로 잡는다 |
| **X-13** | Critic (콘텐츠 검수 에이전트) | 검수 에이전트 (이 기획서 검수) | 앞은 **게임 콘텐츠**를 8축(`Q1`~`Q8`)으로 채점. 뒤는 **기획서 문서**를 7축(A~G)으로 채점하며 `_meta/reviews/` 에 보고서를 쓴다 |
| **X-14** | 검증 5계층 L1~L5 | 8단계 파이프라인 | 앞은 **검사 깊이**, 뒤는 **생성 절차**. 5단계 lint 가 L1~L4 를, 6단계 sim 이 L5 를 돈다 |
| **X-15** | `entryPoints`(팩) | `entry`(대화) | 앞은 **팩이 월드에 붙는 지점**, 뒤는 **대화의 조건부 진입 규칙**. 이름만 닮았다 |
| **X-16** | 골든 회귀 | shadow diff | 앞은 **시간축 비교**(과거 골든 vs 현재). 뒤는 **경로 비교**(레거시 출력 vs 콘텐츠 드라이런). 둘 다 트레이스를 쓰지만 목적이 다르다 |
| **X-17** | `HDTileAction.scriptMode` | `Enum.index` | `scriptMode` 는 cm2 로 넘어가는 **와이어 값**이고 `const.cm2` 상수와 대응한다. index 로 바꾸면 조용히 깨진다 |
| **X-19** | `PROVEN` (모델 증명) | `SUPPORTED` (실행 가능) | **독립된 두 축**이다(D-26). `PROVEN` 은 "콘텐츠 그래프상 완주 경로가 존재" 이고 `SUPPORTED` 는 "그 경로가 소비하는 이벤트에 현행 빌드의 발행 지점이 있다" 다. **`PROVEN + UNSUPPORTED` 는 하드 게이트 통과가 아니다** — 커밋은 되지만 팩이 "미활성" 으로 표시되고 릴리스에서 차단된다(`RELEASE`, `V-L5-007`). 반대로 `SUPPORTED` 는 완주 가능성을 **전혀 말하지 않는다.** 한 축만 보고 "통과" 라고 쓰면 BP-91 W-10 의 결함이 재발한다 |
| **X-20** | `HDAnchorActivation` | `HDTileAction` | 앞은 **티어 0(콘텐츠) 의 질의 키**(`stepOn`/`interact`), 뒤는 **레거시 3티어의 분기 키**(talk/sign/enter/event/move 등). D-27 이후 앵커 발화는 타일 액션과 **무관**하며, 티어 0 에 넘어가는 `HDTileAction` 은 진단용 부가 정보다 |
| **X-18** | `MISSABLE` | `UNREACHABLE` | 앞은 "되돌릴 수 없는 실수/불운이 존재" → **소프트**. 뒤는 "어떤 경로로도 불가" → **하드, 커밋 불가**. `tags:["missable"]` 이면 `MISSABLE` 은 정상 통과 |

---

## 16. 표기 규약

| # | 규약 | 예 |
|---|---|---|
| **1** | 문서 본문은 **한국어**. 코드·식별자·스키마·JSON 키는 **원문 그대로** | "앵커(Anchor)", `pack.json`, `WorldState` |
| **2** | 한글/영문 병기는 **처음 등장할 때 한 번만**. 이후에는 한글 또는 영문 중 그 장이 택한 하나로 통일 | "완료 래치(Completion Latch)" → 이후 "완료 래치" |
| **3** | 코드 식별자는 백틱으로 감싼다. 클래스·enum·필드·메서드·파일명 전부 | `HDTileAction`, `pendingNavigation` |
| **4** | 코드 위치 참조는 **경로 + 줄** 형식 | `hadar2026_app/lib/application/tile_event_dispatcher.dart:106` |
| **5** | ID 인용은 접두사를 그대로 쓴다 — 요구사항 `R-<장번호>-<n>` · 결정 `D-<n>` · 갭 `G-<n>` · 태스크 `T-<n>` · 리스크 `RK-<n>` · 열린 질문 `Q-<n>` · 검증 규칙 `V-<계층>-<번호>` · 불변식 `INV-20-<n>` · 마일스톤 완료 판정 `G<마일스톤>-<n>` · 하드/소프트 게이트 `H-<n>`/`HC-<n>`/`S-<n>` · 수치 목표 `N-<n>` · 감수 리스크 `AR-<n>` | `R-33-9`, `D-20`, `RK-01`, `V-L4-002`, `G0-1`, `H-5`, `N-24` |
| **5a** | ⚠ **`G-<n>`(BP-11 의 결함)과 `G<n>-<n>`(BP-50 의 마일스톤 완료 판정)은 다른 것**이다. 전자는 하이픈이 접두사 바로 뒤, 후자는 마일스톤 번호 뒤에 온다 | `G-22`(결함) vs `G2-2`(M2 완료 판정) |
| **6** | 콘텐츠 ID·상태 키·문자열 키는 **소문자 snake_case**, 점(`.`)으로 세그먼트를 나눈다 | `npc.core.lore_gate_guard` |
| **7** | 월드 이벤트 이름은 **소문자 snake_case, 동사 과거형 금지** | `talk`(○) / `talked_to`(×) |
| **8** | 다른 장 참조는 **상대 경로 링크**. 같은 내용을 두 장에 복사하지 않는다(D-18) | `[BP-25](25_world_state_and_save.md)` |
| **9** | GROUND_TRUTH 부록은 `부록 A-1` 처럼 인용한다 | "부록 D-1", "부록 C-3" |
| **10** | 수치는 단위를 붙이고 비교 연산자를 명시한다 | "≤ 400 KB", "≥ 0.7", "< 3s" |

> **⚠ D-04 슬러그 규칙의 미해결점**: D-04 는 슬러그를 "영문 소문자/숫자/언더스코어, 3~48자" 로 정하면서
> 허용 문자에 점(`.`)을 넣지 않았는데, 자기 예시(`flag.gen_ep1.quest.missing_scholar.met_client`)는 점을 더 쓴다.
> **규칙이 세그먼트 단위인지 전체 문자열인지가 명시되지 않았다**(REVIEW_BP-92 RQ-1).
> 이 문서는 **세그먼트 단위**로 읽고 있으나, 정본 확정은 D-04 개정을 기다린다.

---

## 17. 폐기된 용어 — 다시 쓰지 말 것

병렬 제작 중 실제로 문서에 등장했다가 **중재 결정으로 폐기**된 이름들이다.
다시 쓰면 [BP-52 RK-32](52_risks.md)(병렬 제작의 정합성 붕괴)가 재발한다.

### 17.1 월드 이벤트 이름 (D-20 으로 전량 폐기)

BP-23 / BP-25 / BP-27 이 서로 다른 이름 집합을 각각 "닫힌 집합" 으로 선언한 충돌을 D-20 이 중재했다.
**소유는 [BP-23](23_quest_model.md)** 이며 아래 왼쪽은 **전량 폐기**다.

| 폐기 | 정본 | 비고 |
|---|---|---|
| `talked_to` | **`talk`** | 동사 과거형 금지 |
| `entered_place` | **`enter_place`** | 동상 |
| `choice_made` | **`dialogue_choice`** | payload 도 달랐다 |
| (BP-25/27 의 11종 집합 전체) | **D-20 의 12종** | 5개만 이름이 같았고 그중 3개는 payload 가 달랐다 |
| `item_gained`/`item_lost` payload `{itemId, count}` | **`{itemId, delta, total}`** | **D-20a** — `count` 는 "변화량인가 총량인가" 가 모호해 `acquire(itemId, count:3)` 판정을 흔든다. 정본은 [BP-23 §23.11.1](23_quest_model.md) |

> ⚠ **payload 는 D-20 표가 아니라 [BP-23 §23.11.1](23_quest_model.md) 을 보라.** D-20a 가 2행을 고쳤으나
> 나머지 **8행의 payload 가 여전히 소유 장과 다르다**(`talk`·`enter_place`·`step_tile`·`battle_won`·`var_changed`·`map_changed`·`gold_changed`·`party_rested`).
> 전수 대조표는 [BP-52 RK-32](52_risks.md) 의 잔여 리스크 절에 있다. **이름 12종만 D-20 이 정본이고, payload 는 BP-23 이 정본이다.**

### 17.2 벽시계 시각 필드 (D-08a 로 폐기)

| 폐기 | 정본 | 비고 |
|---|---|---|
| `startedAt` | **`startedStep`** | 벽시계를 세이브에 넣으면 재현이 불가능해진다 |
| `updatedAt` | **`updatedStep`** | 동상 |
| `at` (journal) | **`atStep`** | 동상 |

> ⚠ **D-08 본문에는 옛 이름이 아직 남아 있다.** D-08a 는 파급만 기술했고 필드명을 고치지 않았다
> (REVIEW_BP-25 RQ-25-B). 표시용 실제 날짜가 필요하면 **세이브 메타데이터**에만 두고
> `WorldState` 안에는 절대 넣지 않으며, 세이브 메타는 결정론 해시 계산에서 제외한다.

### 17.3 세이브 봉투 (D-18 · D-22 로 폐기)

| 폐기 | 정본 | 비고 |
|---|---|---|
| 세이브 봉투의 `map`(전체 스냅샷) | **`mapDelta` + `base` 구분** | 부록 C-3 의 570 KB 문제. `generated` 는 RLE 전체 스냅샷 |
| `nativeScript`(BP-20 초판) | **`legacy.nativeFlags`** | BP-25 가 소유. BP-20 은 링크로 축소 |
| `envelope` 누락 서술 | **BP-25 의 봉투 정의 전체** | 비소유 장은 자기 서술을 지우고 링크로 대체 |

### 17.4 난수 규약 (D-21 · D-30 으로 폐기)

| 폐기 | 정본 | 비고 |
|---|---|---|
| `chance` 가 `WorldStateMutator.nextRandom` 을 호출해 커서를 전진 | **무커서 해시** `mix([seed, step, chanceSeedId])` | 커서 소비는 정의상 부작용이며 D-05 의 "순수 함수" 규정을 깬다 |
| `chance` 유도식에 **`step` 이 없는** 판본 — `splitmix64(seed ^ fnv1a64(chanceKey))` (BP-21 §6.5 초판, R-21-34) | **`chance(p) := (mix([seed, step, chanceSeedId]) % 100) < p`** | **D-30.** `step` 이 없으면 `chance` 가 확률이 아니라 **세이브마다 고정된 상수**가 된다 — 30% 대사가 그 세이브에서 영원히 나오거나 영원히 안 나온다. R-21-34 의 정확한 명제는 "같은 세이브·같은 위치·**같은 스텝**은 항상 같은 결과" 다 |
| 해시 함수 이름 `splitmix64` / `fnv1a64` (세 장에서 갈렸다) | **`mix`** | **D-30.** 정본은 [BP-27 §9.2](27_runtime_engine.md) 의 `mix` 다. 내부적으로 splitmix64 계열을 쓰되 **웹 정수 제약(32비트 2워드) 때문에 구현이 고정**된다 |
| "난수 소비 카운터를 사용하지 않음"(BP-20 §7.2 초판) | **`rngCursor` 채택**(BP-25 · BP-27) | BP-20 이 자기 규범을 철회했다 |

### 17.5 잘못된 사실 기반 서술 (부록으로 폐기)

이것들은 "용어" 가 아니라 **틀린 수치·주장**이지만, 재인용 전파 이력이 있어 여기 함께 둔다.

| 폐기된 서술 | 정정 | 근거 |
|---|---|---|
| 적 데이터 **76종** / **75종** | **74종(id 1~74)** — id 0 은 `<= 0` 가드로 소환 불가 | 부록 B-1 |
| cm2 등록 커맨드 **43** / 함수 **11** | **커맨드 40 / 함수 12** | 부록 F-0 |
| 색 태그 **18색** | **17색** | REVIEW_BP-10 F-06 |
| `ORIGIN.json` 은 사문 자산 | **정상 로드된다** — 미등록이라 이름 폴백이 살아 있다 | 부록 F-4 |
| cm2 는 튜링 완전이라 정적 검증 불가 | **튜링 완전이 아니다.** D-02 의 근거는 침묵 실패·전역 소거·`.assign` 재실행·스키마 부재다 | 부록 E-3 |
| MV `code 101` = 텍스트 헤더 | **표시 방식 지정**(얼굴/배경/창 위치). 텍스트를 담지 않는다 | 부록 E-1 |
| `Map002` 좌표 (30,20) 의 JSON 중복 출력 사례 | 그 사례는 **실제 데이터에 없다** | REVIEW_BP-10 F-02 |

### 17.6 타일 비트 재활용안 (D-27 로 폐기 · D-28 로 최종 기각)

| 폐기 | 정본 | 비고 |
|---|---|---|
| **`region 200~255 예약`** (BP-26 초판의 `trigger` 앵커 배치안) | **트리거 인덱스 직접 조회**(§7) | 부록 **J-1** — `map_loader.dart:44` 가 region(0~255)을 `ixEvent` **하위 바이트**에 넣는데 `tile_properties.dart:186-187` 은 **상위 바이트**(`& 0x00FF0000`)만 본다. **어떤 region 값도 타일 액션을 만들지 못한다.** 비용 문제가 아니라 **작동하지 않는다**(D-27) |
| **로더 승격안 (BP-26 T1)** — `ixEvent = (region >= 200) ? (0x00010000 \| region) : region` | 동상 | **D-28.** 이쪽은 **기술적으로 작동했다** — 오답이 아니라 살아 있는 대안이었다. 기각 근거는 **맵 편집 내구성**: region 승격은 앵커를 **다시 맵 데이터에 묶어** D-09(의미와 좌표의 분리)의 목적을 무너뜨린다. 누가 region 레이어를 지우면 트리거가 소실된다 |
| BP-26 `R-26-9` · `R-26-46~48` · `A-26-13` · §3.5 로더 수정안 · `T-26-1` | (전부 폐기) | **D-28.** `map_loader.dart` 는 **수정하지 않는다.** region 레이어는 계속 읽히되 계속 아무 효과가 없다 |
| 부록 **I-1** 의 "`Map001` (2,3) region=255 충돌" | **문제 자체가 소멸** | 예약하지 않으므로 충돌이 없다. 단 `Map001.json` 은 타일 액션 경계를 의도적으로 훑는 **테스트 픽스처**이므로 정리하지 말 것 |
| BP-91 `W-04`(region 승격 ↔ objUpper 충돌) | **해소 처리** | D-28 |

> ⚠ **`region` 이라는 용어 자체는 폐기가 아니다.** 맵 에디터의 z5 레이어는 계속 존재하고 계속 로드된다.
> 폐기된 것은 **"그 값이 콘텐츠 트리거를 만든다" 는 설계**다. `tools/mapEditor/AI_GUIDE.md` 의
> "region: 지역 ID (게임이 `ixEvent` 로 읽음)" 은 **"읽지만 아무 일도 하지 않는다"** 로 읽어야 한다(부록 J-1).

### 17.7 `siteId` — 두 개체를 혼용한 이름 (D-21a · D-29a 로 폐기)

| 폐기 | 정본 | 비고 |
|---|---|---|
| **`siteId`** | **`chanceKey`**(문자열 키, BP-21 §6.5) · **`chanceSeedId`**(빌드 상수 정수, BP-27) | **D-29a.** `siteId` 는 **서로 다른 두 개체를 같은 이름으로 불렀다.** 이제 각자 이름이 있으므로 이 이름은 쓰지 않는다 |
| BP-27 의 경로 문법 `<ownerId>#<path>` | **`<contextId>#<evalPath>`** | 세그먼트 이름이 어긋난 것이고 **정본은 BP-21 의 것**이다(D-18 · D-29a 부수 정정) |
| "`siteId` 와 `contextId#evalPath` 는 **같은 개념의 두 이름**이며 통합 미완(Q-52-4)" | **Q-52-4 종결** — 두 개체이고 각자 이름이 확정되었다 | 아래 교훈 참조 |

> **⚠ 교훈 — 이 문서가 실제로 사고를 일으킨 사례다.**
> D-29 는 **BP-02 의 요약**("같은 개념의 두 이름")을 근거로 `siteId` 를 전량 폐기하라고 지시했고,
> 그 결과 **빌드 상수에 이름이 없어졌다.** BP-27 이 계속 `siteId` 를 쓰고 있었던 것은 결정 위반이 아니라
> **결정의 공백**이었다. D-29a 가 이를 정정했다.
>
> 재발 방지 규범은 이 문서 머리말의 두 문장 그대로다 — **이 문서는 정의하지 않는다. 가리킨다.**
> 여기에 덧붙인다:
> 1. **요약을 근거로 결정을 내리지 않는다.** "같은 개념의 두 이름" 같은 **동일성 진단**은
>    두 정의처의 원문을 나란히 놓고 확인한 뒤에만 내린다. D-25 가 금지한 "전재" 의 사촌이다.
> 2. 이 문서의 `구별` 열이 "⚠ 이름 통합 미완" 처럼 **미해결 상태를 적을 때**는,
>    그 판단의 근거가 **요약이 아니라 정의처 대조**임을 함께 남긴다.
> 3. 요약과 정의처가 어긋나면 **정의처가 이긴다.** 이 문서를 근거로 구현하지도, 결정하지도 말 것.

### 17.8 결번 — 재사용 금지

| 번호 | 상태 | 비고 |
|---|---|---|
| **D-24** | **결번** | 조정자가 번호를 건너뛴 실수다. **재사용하지 않는다** — 이미 여러 문서가 D-25/D-26 을 인용하고 있어 번호를 당기면 참조가 전부 깨진다. 새 결정은 D-27 부터 붙였다 |
| **`V-MAP-017`** | **결번** | region 기반 맵 검사 규칙. D-27 로 삭제되었다([BP-33](33_validation_and_lint.md) 개정 2판). 맵 데이터 검사는 부록 J-3 의 **3개 출처**로 한정된다 |
| **BP-26 §3.5.1** | **결번** | region 예약 절. D-27 이후 §3.5 가 "폐기 이력 + 트리거 인덱스 직접 조회 계약" 으로 전면 재작성되었다 |

> **D-nn 결번을 여기 적어 두는 이유**: 결정 번호가 비어 있으면 다음 사람이 "누락된 결정을 찾아야 하나" 를 의심한다.
> **비어 있는 것이 정상이라는 사실 자체가 정보**다.

---

## 18. 관련 문서

| 찾는 것 | 문서 |
|---|---|
| 확정된 설계 결정 D-01~D-30 (**D-24 는 결번**, §17.8) | `_meta/DECISIONS.md` |
| 검증된 코드 사실과 잠복 버그 | `_meta/GROUND_TRUTH.md`(**부록 A~K**) — 특히 **H**(장비 필드 사망) · **J**(region 레이어 기능적 사망) · **K**(타일 이벤트 진입점 3개의 게이트 비대칭) |
| **남의 용어 ↔ 본 기획서 용어** 대응표(RPG Maker MV·Bethesda·Ink 등) | [BP-92 §92.4](92_appendix_reference_index.md) |
| 전체 JSON Schema 원문 | [BP-90](90_appendix_schemas.md) |
| 용어가 실제로 쓰이는 엔드투엔드 예제 | [BP-91](91_appendix_worked_example.md) |
| 마일스톤 M0~M6 의 정의·완료 판정 `G0-1`~`G6-5` | [BP-50](50_roadmap.md) |
| 태스크 `T-nnn` 의 분해·의존성 | [BP-51](51_task_breakdown.md) |
| 아이템·인벤토리 실데이터와 게임 규칙 | [BP-42](42_item_and_inventory.md) |
| 맵 에디터 확장(앵커 시각화·통행 검사) | [BP-36](36_map_editor_extension.md) |
| 리스크 등록부와 폐기 용어의 재발 위험 | [BP-52](52_risks.md) |
| 게이트·수치 목표의 통합 인덱스 | [BP-53](53_acceptance_criteria.md) |
