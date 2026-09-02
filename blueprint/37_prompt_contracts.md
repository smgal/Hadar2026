# 프롬프트 계약·출력 스키마·검수 루브릭

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-37 · **상태**: 초안 · **선행 문서**: [BP-32](32_generation_harness.md) · [BP-21](21_content_pack_spec.md) · [BP-23](23_quest_model.md) · [BP-24](24_dialogue_model.md)
> **독자**: 프롬프트 작성자 · 하네스 구현자 · 검수 담당
> **한 줄 요약**: 그대로 복사해 `content_gen/prompts/` 에 넣고 쓸 수 있는 **실물 프롬프트 6종**, 에이전트 출력 JSON Schema 6종, 게임 콘텐츠용 검수 루브릭 8축.

**파이프라인 구획**([D-01](_meta/DECISIONS.md)): Authoring 전용. 이 문서의 어떤 것도 런타임에 존재하지 않는다.

**이 장이 SSoT 인 것**: 프롬프트 원문, 프롬프트 템플릿 변수 사전, 에이전트 출력 스키마
(`QuestOutline` / `QuestDraft` / `DialogueDraft` / `StringsDraft` / `CriticReport` / `StyleReport`),
Critic 루브릭 8축과 합격선, 프롬프트 버전 규약.

**이 장이 SSoT 가 아닌 것** — [D-18 소유권 표](_meta/DECISIONS.md)에 따라 링크만 한다:

| 대상 | 소유 |
|---|---|
| Condition/Effect DSL, ID 문법, 문자열 키 | [BP-21](21_content_pack_spec.md) |
| 톤 규정 `lore.tone`, 금기 `taboos`, 액터 `knowledge` | [BP-22](22_world_bible_model.md) |
| Quest/Stage/Objective 스키마, 티어 보상표 | [BP-23](23_quest_model.md) |
| Dialogue/Node/Choice 스키마, 길이 상한 수치 | [BP-24](24_dialogue_model.md) |
| 앵커 스키마 | [BP-26](26_entity_registry_and_anchors.md) |
| 파이프라인 단계·에이전트 역할·컨텍스트 예산 | [BP-32](32_generation_harness.md) |
| 린트 규칙 `QV-*`/`DV-*` | [BP-33](33_validation_and_lint.md) |
| 문체 규칙 원문 | [BP-43](43_content_style_guide.md) |

**아래 프롬프트가 참조하는 콘텐츠 스키마는 전부 위 문서 소유다.** 프롬프트 안에서는
`{{schema_quest}}` 처럼 **주입 변수**로 다루고, 프롬프트가 스키마를 다시 적지 않는다 —
스키마가 바뀌었는데 프롬프트만 옛것을 들고 있는 사고를 원천 차단한다.

---

## 37.1 프롬프트 계약의 원칙

### 37.1.1 6가지 원칙 (R-37-1 ~ R-37-6)

| # | 원칙 | 구현 |
|---|---|---|
| **R-37-1** | **출력 스키마 강제** | 모든 프롬프트는 JSON Schema 를 본문에 주입받고, "이 스키마를 만족하는 JSON 객체 하나만 출력" 을 요구한다. 구조화 출력 모드가 있으면 그것도 같이 건다 |
| **R-37-2** | **예시 제공** | 좋은 예 1개 + 나쁜 예 1개(왜 나쁜지 주석 포함). 좋은 예만 주면 모델이 형태만 베끼고 이유를 학습하지 못한다(§37.6) |
| **R-37-3** | **금지 목록 명시** | "하지 말 것" 을 열거한다. 이미 [BP-23 §23.12.3](23_quest_model.md)·[BP-24 §24.11.3](24_dialogue_model.md)에 있는 목록을 그대로 주입한다 |
| **R-37-4** | **자기수정 지시** | 실패 시 무엇을 어떻게 고치는지 프롬프트가 미리 규정한다. Repair 프롬프트(§37.3.6)는 **경로 단위 교체**만 시킨다 |
| **R-37-5** | **화이트리스트 우선** | 금지보다 강한 것은 애초에 안 주는 것이다. 등장 가능한 인물·장소·아이템 목록을 명시적으로 주고 "이 목록 밖은 없는 것으로 취급" 이라고 못박는다 |
| **R-37-6** | **역할 격리** | 한 프롬프트는 한 역할만 한다. "쓰고 검수까지" 를 한 호출에 시키지 않는다([BP-32 R-32-21](32_generation_harness.md)) |

### 37.1.2 프롬프트 파일 형식

`content_gen/prompts/<role>.<version>.md` — YAML front matter + 본문.

```yaml
---
role: planner                       # planner|writer_struct|writer_prose|critic|style_editor|repair
version: v1
outputSchema: schemas/quest_outline.schema.json
model:
  id: "<model-id>"                  # manifest 에 그대로 기록됨
  temperature: 0.7
  maxTokens: 8000
  responseFormat: json_object
requiredVars: [run_id, pack, order_intent, constraints, context_pack, schema_questoutline,
               tier_reward_table, existing_quest_index, few_shot_good, few_shot_bad]
changelog:
  - "v1 최초 작성"
---
```

- **R-37-7** `requiredVars` 에 나열된 변수가 하나라도 비면 하네스가 **호출 전에 실패**한다.
  프롬프트에 `{{…}}` 가 그대로 남은 채 모델에 가는 일은 없어야 한다.
- **R-37-8** front matter 의 `model` 은 하네스가 읽어 `manifest.models[]` 에 복사한다([BP-32 §32.7.2](32_generation_harness.md)).
  Orchestrator 는 모델을 고르지 않는다.
- **R-37-9** 본문 전체(front matter 포함)의 SHA-256 이 `manifest.prompts[].sha256` 이다.
  **한 글자만 바꿔도 버전을 올려야 한다**(§37.8).

### 37.1.3 템플릿 변수 사전 (확정)

| 변수 | 채우는 주체 | 내용 | 컨텍스트 블록 |
|---|---|---|---|
| `{{run_id}}` | Orchestrator | 실행 식별자 | — |
| `{{pack}}` | Orchestrator | 대상 팩 id | — |
| `{{order_intent}}` | 주문서 | 사람이 쓴 의도 1~3문장 | — |
| `{{constraints}}` | 주문서 | `constraints` 객체를 표로 렌더 | — |
| `{{context_pack}}` | Context Packer | `01_context/context_pack.md` 전문 | P0~P7 |
| `{{tone}}` | Context Packer | `lore.tone` + `lore.taboos` | P1 |
| `{{taboos}}` | Context Packer | 금기 목록만 | P1 |
| `{{speaker_voice}}` | Context Packer | 화자의 `_summary`,`_voice`,`traits` | P2 |
| `{{knowledge_whitelist}}` | Context Packer | 화자 `knowledge.knows` 로 좁힌 엔티티 목록 | P2 |
| `{{world_axes}}` | Context Packer | `axes` + 관련 `chronicle` | P3 |
| `{{adjacent_content}}` | Context Packer | 인접 퀘스트·대화 요약 | P4 |
| `{{existing_quest_index}}` | Context Packer | 전 퀘스트 1줄 요약 목록 | P6 |
| `{{catalog}}` | Context Packer | 사용 가능 아이템·인카운터·앵커 후보 | P7 |
| `{{schema_questoutline}}` | 하네스 | §37.4.1 스키마 | P0 |
| `{{schema_quest}}` | 하네스 | [BP-23](23_quest_model.md) 필드표 + §37.4.2 | P0 |
| `{{schema_dialogue}}` | 하네스 | [BP-24](24_dialogue_model.md) 필드표 + §37.4.3 | P0 |
| `{{schema_strings}}` | 하네스 | §37.4.4 | P0 |
| `{{schema_critic}}` | 하네스 | §37.4.5 | P0 |
| `{{schema_style}}` | 하네스 | §37.4.6 | P0 |
| `{{dsl_conditions}}` | 하네스 | [BP-21 §6.3](21_content_pack_spec.md) op 18종 표 | P0 |
| `{{dsl_effects}}` | 하네스 | [BP-21 §6.6](21_content_pack_spec.md) do 25종 표 | P0 |
| `{{objective_kinds}}` | 하네스 | [BP-23 §23.4.4](23_quest_model.md) params 스키마 | P0 |
| `{{tier_reward_table}}` | 하네스 | [BP-23 §23.9.3](23_quest_model.md) 티어 보상표 | P0 |
| `{{length_limits}}` | 하네스 | [BP-24 §24.5.5](24_dialogue_model.md) 길이 상한표 | P1 |
| `{{substitution_tokens}}` | 하네스 | 허용 치환 토큰 목록(§37.7.5) | P1 |
| `{{color_tags}}` | 하네스 | 허용 색상 태그(§37.7.6) | P1 |
| `{{forbidden_list}}` | 하네스 | 대상 에이전트용 "하지 말 것" 목록 | P0 |
| `{{few_shot_good}}` / `{{few_shot_bad}}` | 하네스 | §37.6 | P5 |
| `{{outline}}` | 2단계 산출물 | `QuestOutline` JSON | — |
| `{{draft_quest}}` / `{{draft_dialogue}}` | 3단계 A | 구조 JSON | — |
| `{{key_manifest}}` | 3단계 A | 채워야 할 키 목록 + 맥락 | — |
| `{{draft_strings}}` | 3단계 B | 문자열 JSON | — |
| `{{lint_findings}}` | 5단계 | `{ruleId, severity, path, message, hint}` 배열 | — |
| `{{trace_summary}}` | 6단계 | 솔버 완주 경로 요약 | — |
| `{{soft_warnings}}` | 5단계 | soft 경고만 | — |
| `{{rubric}}` | 하네스 | §37.5 루브릭 전문 | P0 |

---

## 37.2 공통 프리앰블

모든 LLM 프롬프트의 맨 앞에 **동일하게** 붙는다. 파일은 `content_gen/prompts/_preamble.v1.md`.

```markdown
당신은 1990년대 한국 RPG 「또 다른 지식의 성전(Hadar)」의 리메이크판 Hadar2026 의
콘텐츠 제작 파이프라인에서 동작하는 전문 에이전트다.

## 절대 규칙
1. 출력은 **JSON 객체 하나**뿐이다. 코드 블록 표시(```), 설명 문장, 사과, 인사말을 붙이지 않는다.
2. 주어진 JSON Schema 를 만족하지 못하는 출력은 즉시 폐기되고 당신은 다시 호출된다.
   스키마에 없는 필드를 추가하면 실패다(additionalProperties: false).
3. 목록으로 주어진 열거값(op, do, kind, role, trait, state …) 밖의 값을 **발명하지 않는다**.
   "적당해 보이는 새 값" 은 존재하지 않는 값이다.
4. 컨텍스트에 등장하지 않는 인물·장소·세력·아이템·사건을 **없는 것으로 취급**한다.
   필요하면 만들어 달라고 요청하는 필드가 따로 있다. 임의로 지어내지 않는다.
5. 당신은 자신의 산출물을 평가하지 않는다. 품질 평가는 별도의 검수 에이전트가 한다.
   출력에 "잘 만들었다", "이 부분이 특히 좋다" 같은 자평을 넣지 않는다.
6. 확신이 없으면 지어내지 말고, 스키마가 허용하는 `notes` / `openQuestions` 필드에 적는다.
   그 필드가 없으면 가장 보수적인 선택(기존 엔티티 재사용, 최소 규모)을 한다.

## 세계관 고정
- 시대는 검과 마법의 중세이며 유물 수준의 기술만 존재한다. 현대 문물은 없다.
- 고유명사는 원작 표기를 그대로 쓴다: Lord Ahn, Necromancer, LORE, MENACE, Ancient Evil,
  Red Antares, 또 다른 지식의 성전. 한글로 옮기거나 새 표기를 만들지 않는다.
- 기본 어투는 예스러운 존대다(「…하시오」, 「…이오」, 「…하더이다」).
- 파티(플레이어 일행)는 2인칭 복수로 부른다.

## 컨텍스트 블록 규약
주어진 컨텍스트는 다음 머리표로 구분된다. 지시가 "[A] 블록" 을 말하면 그 블록만 보라는 뜻이다.
  [S] 출력 스키마와 금칙   [T] 톤과 금기       [A] 인물의 지식과 목소리
  [W] 세계 축과 연대기     [N] 인접 콘텐츠     [E] 예시
  [I] 팩 전역 색인         [C] 사용 가능 카탈로그
```

- **R-37-10** 프리앰블은 역할별 프롬프트가 **덮어쓸 수 없다**. 역할 프롬프트가 프리앰블과
  모순되는 지시를 담으면 프롬프트 리뷰에서 반려한다.

---

## 37.3 에이전트별 프롬프트 전문

### 37.3.1 Planner — `content_gen/prompts/planner.v1.md`

```markdown
{{_preamble}}

# 역할: 기획 에이전트 (Planner)

당신은 주문서 한 건을 받아 **구현 가능한 퀘스트 설계도(QuestOutline)** 를 만든다.
대사를 쓰지 않는다. JSON 콘텐츠 파일을 만들지 않는다. 설계만 한다.

## 이번 주문
- 실행 식별자: {{run_id}}
- 대상 팩: {{pack}}
- 사람의 의도:
{{order_intent}}
- 제약:
{{constraints}}

## 참고 자료
{{context_pack}}

## 설계 절차 (이 순서로 생각하고, 결과만 JSON 으로 낸다)

1. **[I] 블록의 기존 퀘스트 목록을 먼저 읽는다.**
   이미 있는 이야기와 뼈대가 겹치면(같은 의뢰 구조, 같은 실종/배달/토벌 패턴에 이름만 다름)
   그 설계는 버리고 다른 각도를 찾는다. 겹침 여부는 `noveltyNote` 에 적는다.
2. **[W] 블록의 연대기(chronicle)에서 이 퀘스트가 놓일 시점을 정한다.**
   아직 일어나지 않은 사건(order 가 더 큰 사건)을 전제로 삼지 않는다.
3. **[A] 블록에서 등장인물을 고른다.** 기존 인물 재사용을 우선한다.
   새 인물이 꼭 필요하면 `newEntities` 에 이유와 함께 적는다. 개수 상한은 제약에 있다.
4. **비트(beat)를 3~9개로 짠다.** 비트 하나 = 플레이어가 겪는 한 장면이다.
   각 비트에 "플레이어가 무엇을 하는가" 와 "무엇을 알게 되는가" 를 모두 적는다.
   무엇을 알게 되는지 적을 수 없는 비트는 심부름일 뿐이므로 지운다.
5. **비트를 스테이지로 묶는다.** 스테이지는 저널 한 줄로 요약되는 단위다.
   스테이지마다 목표(objective)를 1~3개 붙인다. kind 는 아래 9개 중에서만 고른다.
   {{objective_kinds}}
6. **완주 가능성을 스스로 점검한다.** 각 목표에 대해 "이걸 달성할 방법이 세계 안에 실제로 있는가"
   를 확인한다. 열쇠가 필요하면 그 열쇠를 누가 주는지 설계에 있어야 한다.
   막히는 지점이 있으면 `openQuestions` 에 적는다.
7. **보상을 정한다.** 반드시 아래 티어 표에서 고른다. 표 밖의 숫자를 만들지 않는다.
{{tier_reward_table}}
8. **배치 힌트를 적는다.** 각 인물·트리거가 어느 맵의 어떤 성격의 자리에 있어야 하는지
   (`placementHints`). 정확한 좌표는 적지 않는다 — 좌표는 뒤 단계의 결정론 프로그램이 정한다.

## 금지 사항
{{forbidden_list}}
- 대사 원문을 쓰지 않는다. 비트 요약은 평서문 한두 줄로만.
- 문자열 키(str.…)를 만들지 않는다. 그것은 집필 에이전트의 일이다.
- 엔티티 ID 를 확정하지 않는다. 새 엔티티는 `slugHint` (영문 소문자·언더스코어)만 제안한다.
- 스테이지를 10개 이상 만들지 않는다. 목표를 스테이지당 4개 이상 두지 않는다.
- 이전 스테이지로 되돌아가는 흐름을 설계하지 않는다. 진행은 한 방향이다.
- 메인 퀘스트(tags 에 "main")에 실패 조건을 넣지 않는다.
- 확률에 의존해야만 진행되는 경로를 만들지 않는다.

## 좋은 예
{{few_shot_good}}

## 나쁜 예 (이렇게 하지 말 것)
{{few_shot_bad}}

## 출력
아래 스키마를 만족하는 JSON 객체 하나만 출력한다.
{{schema_questoutline}}
```

### 37.3.2 Writer 패스 A (구조) — `content_gen/prompts/writer_struct.v1.md`

```markdown
{{_preamble}}

# 역할: 집필 에이전트 — 구조 패스 (Writer / Structure)

당신은 승인된 설계도를 **퀘스트 JSON 과 대화 그래프 JSON** 으로 옮긴다.
이번 패스에서는 **한국어 문장을 한 글자도 쓰지 않는다.** 표시되는 모든 텍스트는
문자열 키(`str.…`)로만 참조한다. 실제 문장은 다음 패스에서 다른 호출이 채운다.

## 입력 설계도
{{outline}}

## 참고 자료
{{context_pack}}

## 사용 가능한 표현 수단 (이 밖의 것은 존재하지 않는다)
- 조건식 op:
{{dsl_conditions}}
- 효과 do:
{{dsl_effects}}
- 목표 kind 와 params:
{{objective_kinds}}

## 작성 절차

1. **퀘스트 파일부터 만든다.** 설계도의 스테이지를 그대로 옮긴다. 스테이지를 추가·삭제하지 않는다.
   - `journal` 맵은 **모든 스테이지 id 를 빠짐없이** 덮어야 한다.
   - `next` 가 배열이면 마지막 원소는 반드시 `{"when": {"op":"true"}, "go": …}` 이다.
   - `entryStage` 를 명시한다.
2. **대화 그래프를 만든다.** 설계도의 비트 중 "대화로 벌어지는 것" 마다 대화 파일 하나.
   - `entry` 는 위에서부터 첫 참이다. **마지막 원소에는 when 을 넣지 않는다**(기본 진입).
   - 진입 순서는 completed → failed → quest_stage 분기 → active → 기본 이다.
   - 선택지는 2~4개. **마지막 선택지는 조건 없이 항상 보이고 once 가 아니어야 한다**
     (플레이어가 Esc 로 빠져나갈 때 그 선택지가 골라지기 때문이다).
   - 모든 노드에서 "end" 까지 가는 길이 있어야 한다. 노드끼리만 맴도는 고리를 만들지 않는다.
3. **효과를 배치한다.**
   - `warp` / `start_battle` / `play_dialogue` 는 효과 배열의 **마지막에 하나만** 둔다.
     같은 배열에 둘 이상 넣지 않는다. 그 노드/선택지의 다음은 `"end"` 로 한다.
   - 퀘스트 시작은 `start_quest`, 진행은 `advance_quest`, 완료는 `complete_quest` 다.
     스테이지 전이를 플래그로 흉내내지 않는다.
4. **문자열 키를 만든다.** 규칙은 `str.<pack>.<owner_type>.<owner_slug>.<slot>` 이다.
   - 대사 줄: `str.{{pack}}.dlg.<대화슬러그>.node.<노드id>.line.<0부터 연속>`
   - 헤더:   `str.{{pack}}.dlg.<대화슬러그>.node.<노드id>.header`
   - 선택지: `str.{{pack}}.dlg.<대화슬러그>.choice.<노드id>.<선택지id>`
   - 퀘스트: `str.{{pack}}.quest.<퀘스트슬러그>.title` / `.summary` / `.stage.<스테이지id>.journal`
   - 번호는 0부터 시작해 **구멍 없이 연속**이어야 한다.
5. **신규 액터·아이템이 설계도에 있으면** 그 파일도 함께 만든다.
   액터의 `knowledge.knows` / `knowledge.unknown` 은 비워 둘 수 없다.
   그 인물이 알 리 없는 것을 `unknown` 에 반드시 적는다.

## 금지 사항
{{forbidden_list}}
- lines / text / header / title / summary / journal 에 한국어를 직접 쓰지 않는다. 키만 쓴다.
- 설계도에 없는 스테이지·목표·인물·아이템을 추가하지 않는다.
- 목록에 없는 op / do / kind 를 쓰지 않는다. 비슷해 보이는 이름을 지어내지 않는다.
- 다른 대화의 노드 id 를 `go` 로 가리키지 않는다. 대화를 넘길 때는 `play_dialogue` 를 쓴다.
- 대화 사이클을 만들 때는 반드시 탈출 선택지를 함께 둔다.
- 적은 이름이 아니라 인카운터 id 로 지정한다. 직접 적 번호를 쓸 때는 1~74 범위만 쓴다.

## 좋은 예
{{few_shot_good}}

## 나쁜 예 (이렇게 하지 말 것)
{{few_shot_bad}}

## 출력
아래 스키마를 만족하는 JSON 객체 하나만 출력한다.
`quest`, `dialogues`, `entities`, `keyManifest` 네 부분을 모두 채운다.
`keyManifest` 는 다음 패스가 문장을 채울 키 목록이며, 각 키마다 화자·상황·용도를 적는다.
{{schema_quest}}
{{schema_dialogue}}
```

### 37.3.3 Writer 패스 B (문장) — `content_gen/prompts/writer_prose.v1.md`

```markdown
{{_preamble}}

# 역할: 집필 에이전트 — 문장 패스 (Writer / Prose)

당신은 이미 확정된 대화 구조에 **한국어 문장만** 채운다.
구조는 건드리지 않는다. 키를 더하거나 빼지 않는다. 주어진 키 전부를 정확히 한 번씩 채운다.

## 채울 키 목록과 맥락
{{key_manifest}}

## 화자
{{speaker_voice}}

## 이 화자가 아는 것 (이 목록 밖의 고유명사를 입에 올리지 않는다)
{{knowledge_whitelist}}

## 톤 규정
{{tone}}

## 금기
{{taboos}}

## 길이 제한 (어기면 자동 반려된다)
{{length_limits}}

## 쓰는 방법

1. **한 줄은 한 호흡이다.** 화면 한 줄에 들어가야 하므로 짧게 끊는다.
   길어지면 줄을 나눈다 — 줄을 나누는 것은 허용되고, 한 줄을 늘이는 것은 허용되지 않는다.
2. **화자의 목소리를 지킨다.** 위 [화자] 항목의 말투 지침이 톤 규정보다 우선한다.
   무뚝뚝한 위병은 무뚝뚝하게, 취객은 말이 흐트러지게, 학자는 장황하지 않게 정확하게.
3. **아는 것만 말한다.** 위 화이트리스트에 없는 인물·장소·사건의 이름을 쓰지 않는다.
   플레이어만 아는 사실을 화자가 먼저 말하지 않는다.
   소문 수준으로만 아는 것은 단정하지 않는다 — 「…라 하더이다」, 「…라는 소문이오」 처럼 쓴다.
4. **선택지는 플레이어의 말이다.** 화자 말투가 아니라 파티가 할 법한 말로 쓴다.
   짧고, 무엇을 선택하는지 분명하게. 마지막 선택지는 대화를 끝내는 쪽으로 쓴다.
5. **저널은 3인칭 기록이다.** 대사체가 아니라 「…에게 …를 물었다」 같은 기록체로 쓴다.
6. **고유명사는 원작 표기 그대로.** 새로 만들지 않는다. 별칭이 필요하면 화이트리스트에 있는 것만.
7. **치환 토큰**은 아래 목록만 쓴다. 파티원 이름을 문장에 직접 박지 않는다.
{{substitution_tokens}}
8. **색상 태그**는 아래 목록만 쓰고, 연 태그는 같은 문자열 안에서 반드시 닫는다.
{{color_tags}}

## 금지 사항
- 현대어·외래 신조어·이모지·영문 약어를 쓰지 않는다.
- 메타 표현(게임, 세이브, 플레이어, 레벨업, 퀘스트라는 단어 자체)을 대사에 쓰지 않는다.
  저널에서도 「임무」라 쓰고 「퀘스트」라 쓰지 않는다.
- 구조를 바꾸지 않는다. 노드·선택지·조건·효과에 손대지 않는다.
- 키를 추가·삭제·개명하지 않는다. 빈 문자열("")을 값으로 쓰지 않는다.
- 한 문장 안에 색 구간을 3개 넘게 넣지 않는다.
- 공백 없이 30자 이상 이어지는 구간을 만들지 않는다.
- 같은 표현을 여러 키에 반복하지 않는다. 반복 대사 풀은 서로 다른 내용이어야 한다.

## 좋은 예
{{few_shot_good}}

## 나쁜 예 (이렇게 하지 말 것)
{{few_shot_bad}}

## 출력
아래 스키마를 만족하는 JSON 객체 하나만 출력한다.
`strings` 의 키 집합은 위 [채울 키 목록] 과 **정확히 같아야 한다** — 하나라도 남거나 더하면 실패다.
{{schema_strings}}
```

### 37.3.4 Critic — `content_gen/prompts/critic.v1.md`

```markdown
{{_preamble}}

# 역할: 검수 에이전트 (Critic)

당신은 완성된 퀘스트 한 건을 채점하고 수정 지시를 낸다.
**당신은 내용을 고치지 않는다.** 고쳐 쓴 문장을 출력에 넣지 않는다.
무엇이 문제인지, 어느 단계로 되돌려야 하는지만 적는다.

## 채점 대상
### 퀘스트 정의
{{draft_quest}}
### 대화 그래프
{{draft_dialogue}}
### 문자열
{{draft_strings}}

## 기계 검사 결과 (이미 통과한 것 / 남은 경고)
- 하드 게이트: 전부 통과했다. **당신은 하드 게이트를 다시 판정하지 않는다.**
  스키마 위반·미해결 참조·도달 불가 노드·완주 불가는 이미 기계가 확인했다.
  그런 종류의 지적을 하지 마라. 당신의 관할이 아니다.
- 남은 소프트 경고:
{{soft_warnings}}
- 시뮬레이터가 찾은 완주 경로 요약:
{{trace_summary}}

## 참고 자료 (이 세계의 정본)
{{context_pack}}

## 채점 방법
{{rubric}}

### 채점 규칙
1. 축마다 0~5 정수로 준다. 소수점을 쓰지 않는다.
2. **모든 점수에 근거를 붙인다.** 근거는 대상 안의 구체적 위치(JSON Pointer 또는 문자열 키)와
   그 내용의 인용이어야 한다. "전반적으로", "다소" 같은 말로만 이루어진 근거는 무효다.
3. 3점은 "받아들일 만하다" 이고 4점은 "좋다" 이다. 결함이 없다는 이유만으로 5점을 주지 않는다.
   5점은 이 축에서 본보기로 삼을 만한 경우에만 준다.
4. 2점 이하를 준 축에는 **반드시** `requiredFixes` 항목이 하나 이상 있어야 한다.
5. 수정 지시마다 `returnToStage` 를 붙인다. 규칙:
   - 문장·어투·길이 문제 → `"7_style"` (문체 교정만으로 해결)
   - 대사 내용·화자 지식·정보 노출 순서 → `"3_prose"` (문장 패스 재작성)
   - 대화 구조·선택지 구성·효과 배치 → `"3_struct"` (구조 패스 재작성)
   - 퀘스트 설계·비트 구성·중복 서사·난이도·보상 → `"2_outline"` (설계 재작업)
   `returnToStage` 가 없는 지시는 하네스가 버린다.
6. 판정(`verdict`)은 아래 규칙으로 기계적으로 정한다. 감으로 정하지 않는다.
   - 모든 축 4점 이상이고 합계 34점 이상 → "pass"
   - 모든 축 3점 이상이고 합계 30점 이상 → "conditional"
   - 그 밖 → "revise"
7. 같은 문제를 여러 축에 중복해서 감점하지 않는다. 가장 본질적인 축 하나에만 반영하고
   나머지 축의 근거에는 언급만 한다.

## 특별히 주의해서 볼 것 (기계가 잡지 못하는 것들)
- **중복 서사**: [I] 블록의 기존 퀘스트와 뼈대가 같은가? 이름만 바뀐 같은 이야기인가?
- **동기 부재**: 플레이어가 왜 이 일을 해야 하는지 대사 안에 있는가? 보상 때문만은 아닌가?
- **목표 불명**: 저널만 읽고 다음에 어디로 가야 할지 알 수 있는가?
- **말투 균질화**: 모든 인물이 같은 리듬으로 말하고 있지 않은가?
- **지식 범위**: 이 인물이 이 시점에 알 수 없는 것을 말하고 있지 않은가?
- **정보 노출 순서**: 나중에 밝혀져야 할 것을 첫 대사에서 흘리고 있지 않은가?
- **고아 콘텐츠**: 이 퀘스트에 들어오는 입구가 실제로 있는가?
- **원작 톤**: 90년대 국산 RPG 의 건조하고 예스러운 결을 유지하는가?

## 금지 사항
- 대상 파일을 고쳐서 출력하지 않는다. 대안 문장을 예시로도 쓰지 않는다.
- 하드 게이트 항목(스키마, 참조, 도달성, 완주 가능성)을 지적하지 않는다.
- 점수 없이 산문만 쓰지 않는다.
- "전반적으로 훌륭하다" 같은 총평만 남기지 않는다. 총평은 `summary` 에 두 문장까지만.
- 취향 문제를 결함으로 올리지 않는다. 규정(톤·길이·지식 범위)에 근거가 없으면 `notes` 로 내린다.

## 출력
아래 스키마를 만족하는 JSON 객체 하나만 출력한다.
{{schema_critic}}
```

### 37.3.5 StyleEditor — `content_gen/prompts/style_editor.v1.md`

```markdown
{{_preamble}}

# 역할: 문체 교정 에이전트 (StyleEditor)

당신은 문자열만 다듬는다. **뜻을 바꾸지 않는다.**
사실·숫자·고유명사·정보의 양은 그대로 두고, 어투와 길이와 리듬만 고친다.

## 교정 대상 문자열
{{draft_strings}}

## 각 문자열의 화자와 상황
{{key_manifest}}

## 화자의 목소리
{{speaker_voice}}

## 톤 규정 (정본)
{{tone}}

## 금기
{{taboos}}

## 길이 제한
{{length_limits}}

## 교정 기준 (위반 항목만 고친다. 문제 없는 문장은 그대로 둔다)

1. **어투** — 예스러운 존대(「…하시오」, 「…이오」, 「…하더이다」)로 통일한다.
   화자 지침이 다른 어투를 지정한 경우(취객·아이·무뚝뚝한 위병)는 그 지침이 우선한다.
2. **현대어** — 현대 구어체, 외래 신조어, 영문 약어, 이모지, 시사·기술 용어를 제거한다.
   대체어가 없으면 문장을 다시 짠다.
3. **메타 표현** — 게임·플레이어·세이브·퀘스트·레벨 같은 말을 세계 안의 말로 바꾼다.
   (퀘스트 → 임무 / 일 / 부탁, 레벨 → 실력 / 경지)
4. **길이** — 한 줄 상한을 넘으면 **줄을 나눈다**. 뜻을 잘라내지 않는다.
   나눌 수 없으면 `unresolved` 에 사유와 함께 적고 원문을 유지한다.
5. **리듬** — 같은 종결어미가 세 번 이상 연달아 나오면 하나를 바꾼다.
   조사·접속사 반복도 마찬가지다.
6. **색상 태그** — 여는 태그는 같은 문자열 안에서 닫는다. 중첩하지 않는다.
   색 구간이 3개를 넘으면 줄인다. 헤더는 @B, 지문은 @7, 강조는 @E, 경고는 @C 만 쓴다.
7. **치환 토큰** — 파티원 이름이 문장에 직접 박혀 있으면 토큰으로 바꾼다.
   허용 토큰 목록 밖의 토큰은 만들지 않는다.
8. **선택지** — 플레이어의 말투로, 상한 글자수 안에서, 무엇을 고르는지 분명하게.

## 절대 하지 말 것
- 구조 파일(퀘스트·대화 JSON)을 건드리지 않는다. 당신 입력에 그것은 들어 있지도 않다.
- 키를 추가·삭제·개명하지 않는다.
- **고유명사를 바꾸거나 새로 만들지 않는다.** 교정 전후로 문장에 등장하는 고유명사 집합이
  달라지면 당신의 출력은 통째로 거부된다.
- 숫자(금액·개수·거리·인원)를 바꾸지 않는다.
- 정보를 더하거나 빼지 않는다. "더 재미있게" 하려고 새 사실을 넣지 않는다.
- 문제 없는 문장을 취향으로 고치지 않는다. 고친 문장마다 규정 근거를 대야 한다.

## 좋은 예
{{few_shot_good}}

## 나쁜 예 (이렇게 하지 말 것)
{{few_shot_bad}}

## 출력
아래 스키마를 만족하는 JSON 객체 하나만 출력한다.
`edits` 에는 **실제로 고친 키만** 넣는다. 고치지 않은 키는 넣지 않는다.
각 edit 에는 원문·교정문·근거 규정·적용한 기준 번호를 모두 적는다.
{{schema_style}}
```

### 37.3.6 Repair — `content_gen/prompts/repair.v1.md`

```markdown
{{_preamble}}

# 역할: 자기수정 (Repair)

검증기가 당신의 이전 출력에서 규칙 위반을 찾았다.
**전체를 다시 만들지 않는다.** 지적된 위치만 고친 교체값을 낸다.

## 이전 출력 (현재 상태)
{{draft_quest}}
{{draft_dialogue}}

## 검증기가 찾은 위반
아래 각 항목은 `ruleId`(규칙), `path`(JSON Pointer 로 지정된 위치),
`message`(무엇이 잘못됐는가), `hint`(어떻게 고치는가) 를 갖는다.
`hint` 가 있으면 그 지시를 그대로 따른다.

{{lint_findings}}

## 사용 가능한 표현 수단 (변하지 않았다)
{{dsl_conditions}}
{{dsl_effects}}
{{objective_kinds}}

## 고치는 방법

1. 위반 항목을 하나씩 처리한다. **`path` 가 가리키는 값만** 바꾼다.
2. 한 위반을 고치느라 다른 곳을 바꿔야 하면, 그 곳도 `patches` 에 함께 적고
   `reason` 에 "위반 X 를 고치기 위한 연쇄 수정" 이라고 밝힌다. 말없이 바꾸지 않는다.
3. 지적되지 않은 곳은 **손대지 않는다.** 개선하고 싶어도 참는다 —
   이미 검증을 통과한 부분이며, 바꾸면 다시 검증해야 한다.
4. 같은 규칙 위반이 여러 곳에 있으면 전부 고친다. 하나만 고치고 넘어가지 않는다.
5. 위반을 고칠 방법이 정말 없으면(설계 자체가 잘못된 경우) `unfixable` 에
   `path` 와 이유를 적는다. 억지로 얼버무리지 않는다 — 그 항목은 설계 단계로 되돌아간다.
6. 문자열 키를 새로 만들어야 하면 만들되, `newKeys` 에 목록을 적는다.
   그 키의 문장은 다음 문장 패스가 채운다. 여기서 한국어를 쓰지 않는다.

## 금지 사항
- 전체 파일을 다시 출력하지 않는다. `patches` 배열만 낸다.
- 위반과 무관한 리팩터링·개명·재배치를 하지 않는다.
- 지적된 규칙을 우회하려고 그 부분을 삭제하지 않는다.
  (예: 도달 불가 노드를 지적받았다고 그 노드를 지우면 이야기가 사라진다. 연결을 만들어라.)
- 목록에 없는 op / do / kind 를 새로 쓰지 않는다.

## 출력
아래 스키마를 만족하는 JSON 객체 하나만 출력한다.

{
  "runId": "...",
  "patches": [
    { "path": "/dialogues/dlg_guard/nodes/n_ask/next",
      "op": "replace",
      "value": "n_answer",
      "ruleIds": ["DV-03"],
      "reason": "도달 불가 노드 n_answer 로 가는 간선을 만듦" }
  ],
  "newKeys": [],
  "unfixable": []
}

`op` 는 "replace" | "add" | "remove" 셋뿐이다.
`value` 는 "remove" 일 때 생략한다.
```

### 37.3.7 결정론 에이전트의 계약 (프롬프트 없음)

Binder 와 Orchestrator 는 LLM 이 아니므로 프롬프트가 없다. 대신 **입출력 계약**이 프롬프트를 대신한다.

| 에이전트 | 계약 문서 | 계약의 형태 |
|---|---|---|
| **Binder** | [BP-32 §32.3.4](32_generation_harness.md) + [BP-26 §2·§3](26_entity_registry_and_anchors.md) | 좌표 선택 규칙(R-32-36 사전순 최솟값), 앵커-타일 정합 판정표, `bind_report.json` |
| **Orchestrator** | [BP-32 §32.7.2](32_generation_harness.md) | `manifest.json` 스키마, 재시도·되돌림 예산표, ID 예약 규칙 |

- **R-37-11** 이 둘에 "프롬프트를 붙여 유연하게 만들자" 는 제안은 기각한다.
  결정론 단계에 LLM 이 들어가면 [BP-32 R-32-64](32_generation_harness.md) 의 재현 정의 ①이 깨진다.

---

## 37.4 출력 스키마 전문

모든 스키마는 `additionalProperties: false` 이며 `content_gen/prompts/schemas/` 에 파일로 둔다.

### 37.4.1 `QuestOutline` (Planner 출력)

```jsonc
{
  "$id": "https://hadar2026/schema/gen/quest_outline.schema.json",
  "type": "object",
  "required": ["runId", "pack", "slugHint", "titleKo", "premiseKo", "act", "tier",
               "giver", "place", "beats", "stages", "rewards", "newEntities",
               "placementHints", "noveltyNote"],
  "additionalProperties": false,
  "properties": {
    "runId":      { "type": "string", "description": "실행 식별자. 주문서에서 그대로 복사" },
    "pack":       { "type": "string", "description": "대상 팩 id" },
    "arcRef":     { "type": ["string","null"], "description": "아크 단위 생성 시 부모 아크 슬러그" },
    "slugHint":   { "type": "string", "pattern": "^[a-z][a-z0-9_]{2,47}$",
                    "description": "퀘스트 슬러그 제안. 최종 ID 확정은 Orchestrator 가 한다" },
    "titleKo":    { "type": "string", "maxLength": 30,
                    "description": "작업용 한국어 제목. 콘텐츠 파일이 아니므로 인라인 한국어 허용" },
    "premiseKo":  { "type": "string", "maxLength": 400,
                    "description": "이 퀘스트가 무슨 이야기인가 2~4문장" },
    "act":        { "type": "integer", "minimum": 1, "maximum": 9 },
    "tier":       { "type": "integer", "minimum": 1, "maximum": 5,
                    "description": "난이도·보상 등급. 보상은 이 값의 권장 범위에서만 고른다" },
    "giver":      { "type": ["string","null"], "description": "의뢰인 액터 id 또는 newEntities 의 slugHint" },
    "place":      { "type": ["string","null"], "description": "주 무대 place id" },
    "tags":       { "type": "array", "items": { "type": "string" }, "maxItems": 8 },

    "prerequisitesKo": { "type": "string", "maxLength": 200,
                         "description": "수주 조건을 말로 설명. 조건식 작성은 구조 패스의 일" },

    "beats": {
      "type": "array", "minItems": 3, "maxItems": 9,
      "description": "플레이어가 겪는 장면의 순서",
      "items": {
        "type": "object",
        "required": ["id", "whatPlayerDoes", "whatPlayerLearns", "where", "who"],
        "additionalProperties": false,
        "properties": {
          "id":               { "type": "string", "pattern": "^b[0-9]{1,2}$" },
          "whatPlayerDoes":   { "type": "string", "maxLength": 200, "description": "플레이어의 행동" },
          "whatPlayerLearns": { "type": "string", "maxLength": 200,
                                "description": "이 장면에서 새로 알게 되는 것. 비워 둘 수 없다" },
          "where":            { "type": "string", "description": "place id 또는 맵 이름" },
          "who":              { "type": "array", "items": { "type": "string" },
                                "description": "등장 액터 id 또는 slugHint" },
          "kind":             { "enum": ["talk","travel","search","fight","choice","reveal"] }
        }
      }
    },

    "stages": {
      "type": "array", "minItems": 1, "maxItems": 9,
      "items": {
        "type": "object",
        "required": ["idHint", "journalKo", "objectives", "beatRefs"],
        "additionalProperties": false,
        "properties": {
          "idHint":    { "type": "string", "pattern": "^[a-z][a-z0-9_]{2,31}$" },
          "journalKo": { "type": "string", "maxLength": 60, "description": "저널 한 줄(작업용 한국어)" },
          "beatRefs":  { "type": "array", "items": { "type": "string" },
                         "description": "이 스테이지가 덮는 beat id 들" },
          "completion":{ "enum": ["all","any"], "default": "all" },
          "objectives": {
            "type": "array", "minItems": 1, "maxItems": 3,
            "items": {
              "type": "object",
              "required": ["idHint", "kind", "targetHint", "reachableBecause"],
              "additionalProperties": false,
              "properties": {
                "idHint": { "type": "string", "pattern": "^o_[a-z0-9_]{1,29}$" },
                "kind":   { "enum": ["talk_to","reach","acquire","deliver","defeat",
                                     "flag_set","var_reach","choose","survive"] },
                "targetHint": { "type": "string",
                                "description": "대상 엔티티 id / slugHint / 좌표 성격 서술" },
                "reachableBecause": { "type": "string", "maxLength": 200,
                    "description": "이 목표를 달성할 방법이 세계 안에 실제로 있는 근거. 완주 증명의 재료" },
                "optional": { "type": "boolean", "default": false },
                "count":    { "type": "integer", "minimum": 1 }
              }
            }
          },
          "branchKo": { "type": ["string","null"], "maxLength": 200,
                        "description": "다음 스테이지가 갈리는 경우 그 조건을 말로" }
        }
      }
    },

    "rewards": {
      "type": "object",
      "required": ["grantExp", "addGold"],
      "additionalProperties": false,
      "properties": {
        "grantExp":  { "type": "integer", "minimum": 0, "description": "티어 권장 범위 안이어야 함" },
        "addGold":   { "type": "integer", "minimum": 0, "description": "티어 권장 범위 안이어야 함" },
        "addFood":   { "type": "integer", "minimum": 0 },
        "items":     { "type": "array", "items": { "type": "string" } },
        "reputation":{ "type": "integer", "minimum": 0 },
        "worldChangeKo": { "type": "string", "maxLength": 200,
                           "description": "완료로 세계가 어떻게 바뀌는가(onComplete 의 재료)" }
      }
    },

    "newEntities": {
      "type": "array", "maxItems": 8,
      "description": "새로 만들어야 하는 것. 여기 없는 것을 뒤 단계가 만들면 실패다",
      "items": {
        "type": "object",
        "required": ["type", "slugHint", "nameKo", "whyNeeded"],
        "additionalProperties": false,
        "properties": {
          "type":      { "enum": ["npc","item","place","dlg","enc"] },
          "slugHint":  { "type": "string", "pattern": "^[a-z][a-z0-9_]{2,47}$" },
          "nameKo":    { "type": "string", "maxLength": 30 },
          "whyNeeded": { "type": "string", "maxLength": 200,
                         "description": "기존 엔티티로 대체할 수 없는 이유" },
          "roleHint":  { "type": "string", "description": "npc 면 role 값 후보" },
          "knowsHint": { "type": "array", "items": { "type": "string" },
                         "description": "이 인물이 아는 것 후보" },
          "unknownHint": { "type": "array", "items": { "type": "string" },
                           "description": "이 인물이 모르는 것 후보. 비워 두지 말 것" }
        }
      }
    },

    "placementHints": {
      "type": "array",
      "description": "좌표가 아니라 '어떤 자리' 인지. 실제 좌표는 Binder 가 결정론적으로 정한다",
      "items": {
        "type": "object",
        "required": ["subject", "map", "placeKind"],
        "additionalProperties": false,
        "properties": {
          "subject":   { "type": "string", "description": "액터 slugHint 또는 트리거 이름" },
          "map":       { "type": "string", "description": "맵 이름(MapInfos 등록명)" },
          "placeKind": { "enum": ["gate","street","indoor","tavern","market","prison",
                                  "shrine","cave_entrance","deep","field","crossroad"] },
          "nearKo":    { "type": "string", "maxLength": 100, "description": "무엇 근처인지 말로" }
        }
      }
    },

    "noveltyNote":   { "type": "string", "maxLength": 300,
                       "description": "[I] 블록의 기존 퀘스트와 무엇이 다른지. 중복 검사의 근거" },
    "openQuestions": { "type": "array", "items": { "type": "string" }, "maxItems": 5,
                       "description": "확신이 없는 지점. 사람이 HG-2 에서 볼 것" }
  }
}
```

### 37.4.2 `QuestDraft` (Writer 패스 A 출력 — 퀘스트 부분)

```jsonc
{
  "$id": "https://hadar2026/schema/gen/quest_draft.schema.json",
  "type": "object",
  "required": ["runId", "quest", "dialogues", "entities", "keyManifest"],
  "additionalProperties": false,
  "properties": {
    "runId":  { "type": "string" },
    "quest":  { "$ref": "https://hadar2026/schema/quest.json",
                "description": "BP-23 의 Quest 스키마 전문을 그대로 만족해야 한다. 여기서 재정의하지 않는다" },
    "dialogues": {
      "type": "array",
      "items": { "$ref": "https://hadar2026/schema/dialogue.json",
                 "description": "BP-24 의 Dialogue 스키마" }
    },
    "entities": {
      "type": "object",
      "description": "outline.newEntities 로 승인된 것만. 그 밖의 신규 엔티티는 하드 실패",
      "additionalProperties": false,
      "properties": {
        "actors": { "type": "array", "items": { "$ref": "https://hadar2026/schema/actor.json" } },
        "items":  { "type": "array", "items": { "$ref": "https://hadar2026/schema/item.json" } },
        "encounters": { "type": "array", "items": { "$ref": "https://hadar2026/schema/encounter.json" } }
      }
    },
    "keyManifest": { "$ref": "#/$defs/keyManifest" },
    "notes": { "type": "array", "items": { "type": "string" }, "maxItems": 10,
               "description": "설계도와 달라진 점이 있으면 이유를 적는다" }
  },
  "$defs": {
    "keyManifest": {
      "type": "array",
      "description": "문장 패스가 채울 키 목록. 구조 패스가 만든 모든 stringKey 를 빠짐없이 담는다",
      "items": {
        "type": "object",
        "required": ["key", "slot", "speaker", "situationKo", "maxChars"],
        "additionalProperties": false,
        "properties": {
          "key":      { "type": "string", "description": "str.<pack>.<type>.<slug>.<slot>" },
          "slot":     { "enum": ["line","header","choice","title","summary","journal","name","desc"] },
          "speaker":  { "type": ["string","null"], "description": "화자 액터 id. 저널·제목은 null" },
          "situationKo": { "type": "string", "maxLength": 200,
                           "description": "이 문장이 나오는 상황. 문장 패스가 맥락을 알기 위한 유일한 단서" },
          "maxChars": { "type": "integer", "description": "이 슬롯의 글자수 상한(BP-24 §24.5.5 에서 유도)" },
          "audience": { "enum": ["party","self","crowd"], "default": "party" },
          "mustMention": { "type": "array", "items": { "type": "string" },
                           "description": "이 문장이 반드시 담아야 할 정보(엔티티 id 또는 사실)" },
          "mustNotMention": { "type": "array", "items": { "type": "string" },
                              "description": "이 시점에 흘리면 안 되는 것" }
        }
      }
    }
  }
}
```

### 37.4.3 `DialogueDraft` (대화만 재생성할 때)

```jsonc
{
  "$id": "https://hadar2026/schema/gen/dialogue_draft.schema.json",
  "type": "object",
  "required": ["runId", "dialogues", "keyManifest"],
  "additionalProperties": false,
  "properties": {
    "runId":     { "type": "string" },
    "dialogues": { "type": "array", "minItems": 1,
                   "items": { "$ref": "https://hadar2026/schema/dialogue.json" } },
    "keyManifest": { "$ref": "https://hadar2026/schema/gen/quest_draft.schema.json#/$defs/keyManifest" },
    "questRef":  { "type": "string", "description": "이 대화들이 붙는 퀘스트 id. 없으면 잡담 대화" },
    "notes":     { "type": "array", "items": { "type": "string" }, "maxItems": 10 }
  }
}
```

### 37.4.4 `StringsDraft` (Writer 패스 B 출력)

```jsonc
{
  "$id": "https://hadar2026/schema/gen/strings_draft.schema.json",
  "type": "object",
  "required": ["runId", "lang", "strings"],
  "additionalProperties": false,
  "properties": {
    "runId":   { "type": "string" },
    "lang":    { "const": "ko", "description": "v1 은 한국어만(D-17)" },
    "strings": {
      "type": "object",
      "description": "키 → 한국어 문장. 키 집합이 keyManifest 와 정확히 일치해야 한다",
      "propertyNames": { "pattern": "^str\\.[a-z][a-z0-9_]{2,31}\\." },
      "additionalProperties": { "type": "string", "minLength": 1, "maxLength": 1000,
                                "description": "빈 문자열 금지(BP-21 R-21-25). 1000자 초과는 하드 실패" }
    },
    "selfCheck": {
      "type": "object",
      "description": "모델이 스스로 확인한 결과. 거짓으로 채우면 다음 단계에서 드러난다",
      "additionalProperties": false,
      "properties": {
        "keyCountMatches":     { "type": "boolean", "description": "keyManifest 와 개수 일치" },
        "maxLineChars":        { "type": "integer", "description": "가장 긴 줄의 글자수" },
        "colorTagsBalanced":   { "type": "boolean" },
        "properNounsUsed":     { "type": "array", "items": { "type": "string" },
                                 "description": "사용한 고유명사 전량. 화이트리스트 대조에 쓰인다" },
        "tokensUsed":          { "type": "array", "items": { "type": "string" },
                                 "description": "사용한 치환 토큰 전량" }
      }
    },
    "unresolved": {
      "type": "array",
      "description": "길이 제한 등으로 처리하지 못한 키와 사유",
      "items": {
        "type": "object",
        "required": ["key", "reason"],
        "additionalProperties": false,
        "properties": { "key": { "type": "string" }, "reason": { "type": "string" } }
      }
    }
  }
}
```

### 37.4.5 `CriticReport` (Critic 출력)

```jsonc
{
  "$id": "https://hadar2026/schema/gen/critic_report.schema.json",
  "type": "object",
  "required": ["runId", "target", "scores", "total", "verdict", "findings", "summary"],
  "additionalProperties": false,
  "properties": {
    "runId":  { "type": "string" },
    "target": { "type": "string", "description": "채점 대상 퀘스트 id" },
    "rubricVersion": { "type": "string", "description": "§37.5 루브릭 버전. 예 'r1'" },

    "scores": {
      "type": "object",
      "description": "8축 각 0~5 정수. 축 이름은 §37.5.1 고정",
      "required": ["Q1_lore","Q2_voice","Q3_narrative","Q4_clarity",
                   "Q5_balance","Q6_style","Q7_novelty","Q8_integration"],
      "additionalProperties": false,
      "properties": {
        "Q1_lore":        { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q2_voice":       { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q3_narrative":   { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q4_clarity":     { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q5_balance":     { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q6_style":       { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q7_novelty":     { "type": "integer", "minimum": 0, "maximum": 5 },
        "Q8_integration": { "type": "integer", "minimum": 0, "maximum": 5 }
      }
    },
    "rationale": {
      "type": "object",
      "description": "축마다 근거 1~3문장. 반드시 대상 안의 구체적 위치를 인용",
      "additionalProperties": { "type": "string", "maxLength": 600 }
    },

    "total":   { "type": "integer", "minimum": 0, "maximum": 40 },
    "minAxis": { "type": "integer", "minimum": 0, "maximum": 5, "description": "축 최저점" },
    "verdict": { "enum": ["pass", "conditional", "revise"],
                 "description": "§37.5.3 의 규칙으로 기계적으로 결정" },

    "findings": {
      "type": "array", "maxItems": 20,
      "items": {
        "type": "object",
        "required": ["id", "axis", "severity", "path", "finding", "requiredFix", "returnToStage"],
        "additionalProperties": false,
        "properties": {
          "id":       { "type": "string", "pattern": "^CF-[0-9]{2}$" },
          "axis":     { "enum": ["Q1_lore","Q2_voice","Q3_narrative","Q4_clarity",
                                 "Q5_balance","Q6_style","Q7_novelty","Q8_integration"] },
          "severity": { "enum": ["blocking", "major", "minor"],
                        "description": "blocking 은 verdict 를 revise 로 강제한다" },
          "path":     { "type": "string",
                        "description": "JSON Pointer 또는 문자열 키. 위치 없는 지적은 무효" },
          "quote":    { "type": "string", "maxLength": 300, "description": "문제가 되는 원문 인용" },
          "finding":  { "type": "string", "maxLength": 400, "description": "무엇이 왜 문제인가" },
          "requiredFix": { "type": "string", "maxLength": 400,
                           "description": "무엇을 어떻게 바꿔야 하는가. 대안 문장을 쓰지는 않는다" },
          "returnToStage": { "enum": ["2_outline", "3_struct", "3_prose", "7_style"],
                             "description": "이 지적을 처리할 단계. 없으면 하네스가 버린다" }
        }
      }
    },

    "summary": { "type": "string", "maxLength": 400, "description": "총평 2문장 이내" },
    "notes":   { "type": "array", "items": { "type": "string" }, "maxItems": 10,
                 "description": "규정 근거가 없는 취향 의견. 하네스는 무시하고 사람만 읽는다" }
  }
}
```

### 37.4.6 `StyleReport` (StyleEditor 출력)

```jsonc
{
  "$id": "https://hadar2026/schema/gen/style_report.schema.json",
  "type": "object",
  "required": ["runId", "edits", "unchangedCount", "properNounCheck"],
  "additionalProperties": false,
  "properties": {
    "runId": { "type": "string" },
    "styleGuideVersion": { "type": "string", "description": "BP-43 문체 가이드 버전" },

    "edits": {
      "type": "array",
      "description": "실제로 고친 키만. 고치지 않은 키는 넣지 않는다",
      "items": {
        "type": "object",
        "required": ["key", "before", "after", "criterion", "reason"],
        "additionalProperties": false,
        "properties": {
          "key":       { "type": "string" },
          "before":    { "type": "string", "maxLength": 1000 },
          "after":     { "type": "string", "maxLength": 1000 },
          "criterion": { "enum": ["register","modern_word","meta_word","length",
                                  "rhythm","color_tag","token","choice_voice"],
                         "description": "§37.3.5 교정 기준 1~8 에 대응" },
          "reason":    { "type": "string", "maxLength": 200, "description": "규정 근거" },
          "beforeChars": { "type": "integer" },
          "afterChars":  { "type": "integer" }
        }
      }
    },

    "unchangedCount": { "type": "integer", "minimum": 0,
                        "description": "손대지 않은 키 수. edits + unchanged = 전체" },

    "properNounCheck": {
      "type": "object",
      "description": "교정 전후 고유명사 집합 비교. 불일치는 출력 전체 거부 사유(BP-32 R-32-40)",
      "required": ["before", "after", "identical"],
      "additionalProperties": false,
      "properties": {
        "before":    { "type": "array", "items": { "type": "string" } },
        "after":     { "type": "array", "items": { "type": "string" } },
        "identical": { "type": "boolean" }
      }
    },

    "unresolved": {
      "type": "array",
      "description": "규정 위반이지만 뜻을 바꾸지 않고는 고칠 수 없는 것",
      "items": {
        "type": "object",
        "required": ["key", "criterion", "reason"],
        "additionalProperties": false,
        "properties": {
          "key":       { "type": "string" },
          "criterion": { "type": "string" },
          "reason":    { "type": "string", "maxLength": 200 }
        }
      }
    }
  }
}
```

---

## 37.5 검수 루브릭 (Critic 채점표)

`_meta/REVIEW_RUBRIC.md`(이 기획서 자체의 검수 루브릭)를 선례로 삼되 **게임 콘텐츠용으로 재설계**했다.
기획서 루브릭은 "사실 정확성·구현 가능성" 을 본다. 게임 콘텐츠는 그것을 **기계가 이미 검사**하므로,
Critic 은 기계가 못 보는 축만 본다.

### 37.5.1 8축 정의 (루브릭 버전 `r1`)

| 축 | 이름 | 5점 | 3점 (합격 하한) | 0~1점 |
|---|---|---|---|---|
| **Q1** `lore` | **세계관 정합** | 연대기·세력·마법 규칙과 완전히 맞물리고, 기존 설정을 새로 조명한다 | 모순은 없으나 세계를 쓰지 않고 배경으로만 둔다 | 시대·기술 수준·세력 관계를 어긴다. 없는 설정을 사실처럼 쓴다 |
| **Q2** `voice` | **인물 목소리 일관성** | 인물마다 어휘·리듬·태도가 뚜렷이 구분되고 `_voice` 지침과 일치 | 인물 구분은 되나 몇 줄에서 흐트러진다 | 모든 인물이 같은 말투. `_voice` 무시 |
| **Q3** `narrative` | **서사 구조** | 동기 → 갈등 → 전환 → 결말이 분명하고, 전환점이 플레이어 선택과 연결된다 | 시작과 끝은 있으나 전환이 밋밋하다 | 심부름의 나열. 왜 하는지 없음 |
| **Q4** `clarity` | **명료성·플레이 가능성** | 저널만 읽어도 다음 행동이 명확. 힌트가 대사에 자연스럽게 있다 | 대체로 알 수 있으나 한 스테이지가 모호하다 | 어디로 가야 할지 알 수 없다. 저널이 상황을 안 담는다 |
| **Q5** `balance` | **난이도·보상 균형** | tier 대비 적 구성·보상·이동 거리가 모두 타당하고 팩 안에서 일관 | 권장 범위 안이나 체감이 다소 후하거나 박하다 | 티어와 무관한 적/보상. 이동 거리가 비합리적 |
| **Q6** `style` | **문체·톤** | 예스러운 존대가 자연스럽고 원작의 건조한 결을 유지 | 대체로 지키나 현대어가 한둘 섞인다 | 현대 구어체·메타 표현·이모지 |
| **Q7** `novelty` | **참신성·비중복** | 기존 퀘스트와 뼈대·소재·해결 방식이 모두 다르다 | 소재는 겹치나 해결 방식이 다르다 | 기존 퀘스트의 이름만 바꾼 재탕 |
| **Q8** `integration` | **통합성** | 기존 인물·장소·사건에 자연스럽게 접속하고, 세계를 실제로 바꾼다 | 접속점은 있으나 세계가 그대로다 | 고립. 아무도 이 퀘스트에 들어오지 않는다 |

- **R-37-12** 축 이름(`Q1_lore` 등)은 스키마 키이자 지표 키다. 바꾸면 `rubricVersion` 을 올린다.
- **R-37-13** 축은 **8개 고정**이다. 늘리면 채점이 흐려지고, 줄이면 F-13/F-16~F-20(§[BP-32 §32.9](32_generation_harness.md))이 새어 나간다.

### 37.5.2 하드 게이트와 소프트 게이트의 분리 (확정)

**이 표가 이 절의 핵심이다.** Critic 은 오른쪽만 본다.

| 검사 항목 | 게이트 | 판정 주체 | Critic 권한 |
|---|---|---|---|
| JSON Schema 유효성 | **Hard** | 3·5단계 (프로그램) | 없음 |
| 미해결 참조 0 | **Hard** | 5단계 `QV-03` | 없음 |
| 대화 도달 불가 노드 0 | **Hard** | 5단계 `DV-03` | 없음 |
| 퀘스트 스테이지 사이클 0 | **Hard** | 5단계 `QV-04` | 없음 |
| 문자열 키 누락 0 | **Hard** | 5단계 `DV-06` | 없음 |
| 인라인 한국어 0 | **Hard** | 5단계 (BP-21 R-21-21) | 없음 |
| 길이 상한 초과 0 | **Hard** | 5단계 `DV-08~10` | 없음 |
| 꼬리 호출 규칙 | **Hard** | 5단계 (BP-21 R-21-38/40) | 없음 |
| 앵커-통행 충돌 0 | **Hard** | 4단계 Binder | 없음 |
| 솔버 완주 증명 | **Hard** | 6단계 QuestSolver | 없음 |
| 결정론 재빌드 해시 일치 | **Hard** | 8단계 | 없음 |
| 지식 범위 — `unknown` 언급 | **Hard** | 5단계 (BP-22 §5.4) | 없음 |
| — | — | — | — |
| 세계관 정합(모순·시점) | **Soft** | **Critic Q1** | 전권 |
| 인물 목소리 | **Soft** | **Critic Q2** | 전권 |
| 서사 구조·동기 | **Soft** | **Critic Q3** | 전권 |
| 목표 명료성 | **Soft** | **Critic Q4** | 전권 |
| 보상 밸런스(권장 범위 안에서의 적정성) | **Soft** | **Critic Q5** + `QV-31~34` | 공동 |
| 문체·톤 | **Soft** | **Critic Q6** + StyleEditor | 공동 |
| 중복 서사 | **Soft** | **Critic Q7** | 전권 |
| 통합성·고아 콘텐츠 | **Soft** | **Critic Q8** + `entryPoints` 경고 | 공동 |

- **R-37-14** Critic 이 Hard 항목을 지적하면 하네스는 그 finding 을 **폐기하고 로그에 남긴다**.
  Critic 이 통과라 해도 Hard 게이트가 막으면 실패이며, 그 반대도 같다([BP-32 R-32-22](32_generation_harness.md)).
- **R-37-15** "Soft 인데 심각한 것" 을 위해 `severity: "blocking"` 이 있다. blocking finding 이
  하나라도 있으면 `verdict` 는 무조건 `revise` 다(점수와 무관).

### 37.5.3 합격선 (확정)

```
total   = Q1+Q2+Q3+Q4+Q5+Q6+Q7+Q8        (0~40)
minAxis = min(Q1..Q8)

verdict =
  "revise"      if  findings 에 severity=="blocking" 이 있다
  "pass"        if  minAxis >= 4 and total >= 34
  "conditional" if  minAxis >= 3 and total >= 30
  "revise"      otherwise
```

| verdict | 의미 | 하네스 동작 |
|---|---|---|
| `pass` | 그대로 커밋 가능 | 8단계 진입(HG-3 승인 필요) |
| `conditional` | 커밋 가능하되 `minor` findings 를 다음 배치에서 처리 | 8단계 진입 + findings 를 `TODO` 로 팩에 기록 |
| `revise` | 커밋 불가 | `returnToStage` 별로 되돌림. 2회째 `revise` 는 HG-3 사람 판단으로 |

- **R-37-16** `pass` 의 문턱(모든 축 ≥4, 총점 ≥34)은 **처음부터 높게 잡는다.**
  대부분이 `conditional` 로 나오는 것이 정상이며, 그것이 사람이 마지막에 봐야 할 이유다.
- **R-37-17** 합격선을 낮춰 처리량을 올리자는 요구는 기각한다. 처리량은 프롬프트 개선(§37.8)으로 올린다.
- **Q-37-1** 이 문턱값은 파일럿 전 추정치다. Critic 점수와 사람 채점의 상관을 측정한 뒤
  ±2점 범위에서 조정할 수 있다. 조정 시 `rubricVersion` 을 올린다.

### 37.5.4 Critic 채점 예시 (형식 참고)

```jsonc
{
  "runId": "20260830-gen_ep1-003",
  "target": "quest.gen_ep1.missing_scholar",
  "rubricVersion": "r1",
  "scores": { "Q1_lore": 4, "Q2_voice": 3, "Q3_narrative": 4, "Q4_clarity": 4,
              "Q5_balance": 4, "Q6_style": 3, "Q7_novelty": 4, "Q8_integration": 4 },
  "rationale": {
    "Q1_lore": "성전이 떠오른 시점(lore.core.temple_rises, order 800) 이후로 설정되어 있고, 위병이 그것을 소문으로만 언급한다. 연대기와 어긋나지 않는다.",
    "Q2_voice": "위병 대사(str.gen_ep1.npc.lore_gate_guard.about_scholar.0)는 지침대로 짧고 각지다. 그러나 학자의 아내(node intro line.2)가 위병과 같은 종결어미를 쓴다.",
    "Q6_style": "전반적으로 예스러운 존대를 지키나 str.gen_ep1.dlg.wife_plea.node.intro.line.1 의 '확인해 주세요'는 현대체다."
  },
  "total": 30, "minAxis": 3, "verdict": "conditional",
  "findings": [
    { "id": "CF-01", "axis": "Q2_voice", "severity": "major",
      "path": "str.gen_ep1.dlg.wife_plea.node.intro.line.2",
      "quote": "그 뒤로는 아무도 못 봤소이다.",
      "finding": "학자의 아내가 위병과 동일한 종결어미('…소이다')를 쓴다. 두 인물의 신분과 traits(위병 stern, 아내 grieving)가 다른데 말투가 구분되지 않는다.",
      "requiredFix": "아내의 대사를 슬픔이 배어나는 어투로 다시 쓴다. 위병의 각진 종결어미를 피한다.",
      "returnToStage": "3_prose" },
    { "id": "CF-02", "axis": "Q6_style", "severity": "minor",
      "path": "str.gen_ep1.dlg.wife_plea.node.intro.line.1",
      "quote": "확인해 주세요.",
      "finding": "현대 구어체 종결이 톤 규정(register: archaic_polite)을 벗어난다.",
      "requiredFix": "예스러운 존대로 교정한다.",
      "returnToStage": "7_style" }
  ],
  "summary": "세계관과 구조는 견고하다. 인물별 말투 구분이 약한 것이 유일한 실질 결함이다.",
  "notes": []
}
```

---

## 37.6 Few-shot 예시

실제 Hadar 세계관 소재를 쓴다. 프롬프트에 `{{few_shot_good}}` / `{{few_shot_bad}}` 로 주입된다.

### 37.6.1 좋은 출력 — 대화 구조 + 문장

**소재**: 로어성 남문 위병(`npc.core.lore_gate_guard`, traits `stern/loyal/weary`,
`knowledge.rumorOnly` 에 `npc.core.necromancer`)에게 실종된 학자의 행방을 묻는 대화.

```jsonc
// 구조 패스 출력 (발췌)
{
  "id": "dlg.gen_ep1.guard_about_scholar",
  "schemaVersion": 1,
  "pack": "gen_ep1",
  "speaker": "npc.core.lore_gate_guard",
  "kind": "talk",
  "entry": [
    { "when": { "op": "quest_state", "id": "quest.gen_ep1.missing_scholar", "state": "completed" },
      "go": "n_after" },
    { "when": { "op": "quest_stage", "id": "quest.gen_ep1.missing_scholar", "stage": "s2_ask_guard" },
      "go": "n_ask" },
    { "go": "n_idle" }
  ],
  "nodes": {
    "n_idle": { "id": "n_idle",
      "header": "str.gen_ep1.dlg.guard_about_scholar.node.n_idle.header",
      "lines": ["str.gen_ep1.dlg.guard_about_scholar.node.n_idle.line.0"],
      "next": "end" },
    "n_ask": { "id": "n_ask",
      "header": "str.gen_ep1.dlg.guard_about_scholar.node.n_ask.header",
      "lines": ["str.gen_ep1.dlg.guard_about_scholar.node.n_ask.line.0",
                "str.gen_ep1.dlg.guard_about_scholar.node.n_ask.line.1"],
      "choices": [
        { "id": "c_press",  "text": "str.gen_ep1.dlg.guard_about_scholar.choice.n_ask.c_press",
          "go": "n_detail" },
        { "id": "c_leave",  "text": "str.gen_ep1.dlg.guard_about_scholar.choice.n_ask.c_leave",
          "go": "end" }
      ] },
    "n_detail": { "id": "n_detail",
      "header": "str.gen_ep1.dlg.guard_about_scholar.node.n_detail.header",
      "lines": ["str.gen_ep1.dlg.guard_about_scholar.node.n_detail.line.0"],
      "onEnter": [
        { "do": "set_flag", "id": "flag.gen_ep1.quest.missing_scholar.heard_direction" },
        { "do": "advance_quest", "id": "quest.gen_ep1.missing_scholar", "stage": "s3_to_menace" }
      ],
      "next": "end" },
    "n_after": { "id": "n_after",
      "header": "str.gen_ep1.dlg.guard_about_scholar.node.n_after.header",
      "lines": ["str.gen_ep1.dlg.guard_about_scholar.node.n_after.line.0"],
      "next": "end" }
  },
  "maxDepth": 8,
  "tags": ["quest_hook"]
}
```

```jsonc
// 문장 패스 출력 (발췌)
{
  "str.gen_ep1.dlg.guard_about_scholar.node.n_idle.header":   "@B성문 위병",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_idle.line.0":   "성문은 해가 지면 닫히오. 그리 아시오.",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_ask.header":    "@B성문 위병",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_ask.line.0":    "학자 나리 말이오?",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_ask.line.1":    "사흘 전에 이 문을 나가셨소.",
  "str.gen_ep1.dlg.guard_about_scholar.choice.n_ask.c_press": "어느 쪽으로 갔소?",
  "str.gen_ep1.dlg.guard_about_scholar.choice.n_ask.c_leave": "알겠소. 수고하시오.",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_detail.header": "@B성문 위병",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_detail.line.0": "@BMENACE@@ 쪽 길로 접어드셨소. 요즘 그 길이 험하다 하더이다.",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_after.header":  "@B성문 위병",
  "str.gen_ep1.dlg.guard_about_scholar.node.n_after.line.0":  "그 나리는 무사하시오? 다행이구려."
}
```

**왜 좋은가** (프롬프트에 이 주석까지 함께 넣는다):

| 관찰 | 규정 근거 |
|---|---|
| `entry` 마지막 원소에 `when` 이 없다 → 어떤 상태에서도 대화가 열린다 | [BP-24 §24.3](24_dialogue_model.md) `DV-01` |
| `entry` 순서가 completed → 단계 분기 → 기본 | [BP-24 §24.11.3](24_dialogue_model.md) |
| 선택지 2개, 마지막(`c_leave`)이 조건 없이 항상 보이는 이탈로 | `DV-12` |
| 대사 한 줄이 모두 28자 이내, 한 노드 2줄 이하 | [BP-24 §24.5.5](24_dialogue_model.md) |
| `MENACE` 를 원작 로마자 표기 그대로, 색 태그를 열고 `@@` 로 닫음 | [BP-22 §2.4](22_world_bible_model.md) `properNounStyle: latin_kept` |
| 위병이 Necromancer 를 말하지 않는다 — `rumorOnly` 이므로 단정할 수 없고, 이 대화의 주제도 아니다 | [BP-22 §5.4](22_world_bible_model.md) |
| "그 길이 험하다 **하더이다**" — 직접 본 것이 아닌 정보를 전문 형식으로 | 소문 단정 금지 |
| 어투가 `stern`+`weary` 에 맞게 짧고 건조하며 사담이 없다 | 액터 `_voice` |
| 상태 변경(`advance_quest`)이 실제로 정보를 얻은 노드에만 있다 | [BP-24 §24.7](24_dialogue_model.md) |

### 37.6.2 나쁜 출력 — 같은 소재, 잘못 만든 경우

```jsonc
// ✗ 이렇게 하면 안 된다
{
  "id": "dlg.gen_ep1.guard_scholar",
  "speaker": "npc.core.lore_gate_guard",
  "entry": [
    { "when": { "op": "quest_active", "id": "quest.gen_ep1.missing_scholar" },   // ✗ 1
      "go": "n_ask" }
  ],                                                                            // ✗ 2
  "nodes": {
    "n_ask": {
      "id": "n_ask",
      "header": "성문 위병",                                                     // ✗ 3
      "lines": [
        "안녕하세요! 학자님을 찾고 계시는군요? 사실 저도 걱정하고 있었어요. 그분은 사흘 전에 네크로맨서가 지배하는 메너스 금광 지하 3층의 붉은 안타레스 동굴 쪽으로 가셨는데, 거기엔 고대의 악이 봉인되어 있다고 하죠. 참고로 지금 파티 레벨로는 좀 위험할 것 같아요!",  // ✗ 4 ✗ 5 ✗ 6 ✗ 7
        "슴갈 님, 조심하세요!"                                                    // ✗ 8
      ],
      "onEnter": [
        { "do": "play_dialogue", "id": "dlg.gen_ep1.wife_plea" },               // ✗ 9
        { "do": "give_item", "id": "item.gen_ep1.ancient_map" },                // ✗ 10
        { "do": "grant_exp", "amount": 50000 }                                  // ✗ 11
      ],
      "choices": [
        { "id": "c_ok", "text": "알겠어요",
          "when": { "op": "flag", "id": "flag.gen_ep1.quest.missing_scholar.met_client" },
          "go": "n_ask" }                                                       // ✗ 12 ✗ 13
      ]
    }
  }
}
```

| ✗ | 무엇이 잘못됐나 | 잡는 곳 |
|---|---|---|
| 1 | `quest_active` 는 존재하지 않는 op. 올바른 표현은 `{"op":"quest_state","id":…,"state":"active"}` | 5단계 스키마 (Hard) |
| 2 | `entry` 에 기본 규칙(조건 없는 마지막 원소)이 없다 → 퀘스트 밖에서는 대화가 열리지 않는다 | `DV-01` (Hard) |
| 3 | `header` 에 한국어를 직접 썼다. 문자열 키여야 한다 | [BP-21 R-21-21](21_content_pack_spec.md) (Hard) |
| 4 | 한 줄이 150자를 넘는다. 상한은 28자이며 줄을 나눠야 한다 | `DV-08` (Hard) |
| 5 | **지식 범위 위반** — 위병의 `unknown` 에 `npc.core.red_antares`, `place.core.antares_cave` 가 있다. 알 리 없는 것을 말한다 | [BP-22 §5.4](22_world_bible_model.md) (Hard) |
| 6 | `rumorOnly` 인 Necromancer 를 단정형으로 말한다("지배하는") | 소문 단정 (Soft) |
| 7 | "파티 레벨" 은 메타 표현. 세계 안의 말이 아니다 | `taboo.core.no_meta` (Soft) |
| 8 | 파티원 이름을 직접 박았다. 치환 토큰 `{p0.name}` 을 써야 한다 | `DV-06b` (Hard) |
| 9 | `play_dialogue` 가 효과 배열의 **마지막이 아니다**. 꼬리 호출 규칙 위반 | [BP-21 R-21-38](21_content_pack_spec.md) (Hard) |
| 10 | 대화 첫 노드에서 아무 조건 없이 아이템을 준다. 반복 대화로 무한 획득 가능 | `DV-15` / 솔버 (Hard) |
| 11 | tier 1 퀘스트에 exp 50,000 — 권장 범위 200~1,500 의 33배 | `QV-31` (Soft→Hard) |
| 12 | 유일한 선택지에 `when` 이 붙어 있다. 조건이 거짓이면 선택지 0개가 되어 진행 불가 | `DV-05`/`DV-12` (Hard) |
| 13 | 선택지가 자기 노드로 되돌아가는데 탈출로가 없다 → 무한 루프 | `DV-24` (Hard) |
| — | 어투가 현대 구어체("…군요", "…있었어요", "조심하세요") | Critic Q6 (Soft) |
| — | 위병의 `traits`(stern, weary)와 정반대의 수다스러운 목소리 | Critic Q2 (Soft) |

- **R-37-18** 나쁜 예는 **한 파일에 여러 종류의 실패를 몰아 넣는다**. 실패마다 별도 예시를 만들면
  컨텍스트 예산이 감당하지 못하고, 모델이 "이 예시와 정확히 같은 실수" 만 피하게 된다.
- **R-37-19** 나쁜 예의 주석 표는 프롬프트에 **함께** 실린다. 왜 나쁜지 없이 나쁜 예만 주면
  모델이 그 형태를 흉내낼 위험이 있다.

---

## 37.7 금칙과 가드레일

### 37.7.1 금칙 6종과 검출 방법 (확정)

| # | 금칙 | 구체적 증상 | 1차 방어(프롬프트) | 2차 검출(기계) | 3차(Critic) |
|---|---|---|---|---|---|
| **G-1** | **세계관 이탈** | 시대·기술 수준·세력 관계·마법 규칙 위반 | 프리앰블 "세계관 고정" + [W] 블록 주입 | `taboos.detect.keywords` 매칭, `chronicle.order` 시점 비교 | **Q1** |
| **G-2** | **현대어** | "확인해 주세요", "OK", 이모지, IT 용어 | 프리앰블 어투 지시 + `{{tone}}` 의 `forbidden` | 금칙어 사전 + 현대 종결어미 패턴(`~요$`, `~습니다$`) 정규식 | **Q6** |
| **G-3** | **고유명사 임의 창작** | 컨텍스트에 없는 지명·인명·조직명 | `{{knowledge_whitelist}}` 화이트리스트(R-37-5) | 바이블 표시명 + `_aliases` 사전 대조, 미등재 대문자 로마자·한자어 후보 추출 | **Q1** |
| **G-4** | **과도한 길이** | 한 줄 60자, 노드 5페이지, 선택지 30자 | `{{length_limits}}` 표 + "줄을 나눠라" 지시 | `DV-08`/`DV-09`/`DV-10` 글자수 계산 | — (Hard 로 충분) |
| **G-5** | **플레이어 이름 오용** | 대사에 "슴갈", "유리" 를 직접 기입 | `{{substitution_tokens}}` 목록 + 명시 금지 | 파티 기본 이름 문자열 매칭 + 허용 토큰 외 `{…}` 검출(`DV-06b`) | — |
| **G-6** | **원작 톤 위반** | 메타 농담, 4th wall, 밝은 코미디, 감상적 과잉 | 프리앰블 + `{{taboos}}` | `taboo.core.no_meta` 키워드(세이브·플레이어·게임) | **Q6 · Q3** |

### 37.7.2 G-1 세계관 이탈 — 검출 상세

```
① 금칙 키워드: lore.taboos[].detect.keywords 를 scope 별로 문자열 매칭
   severity: "hard" → 빌드 실패, "soft" → 경고
② 시점 검사: 대사에 등장한 lore.* 사건의 order 가
   현재 진행 지점(퀘스트 act 로 추정)보다 크면 경고
③ 지식 범위: 화자의 knowledge.unknown 에 있는 엔티티의 표시명/별칭이
   그 화자의 대사에 나타나면 하드 실패
④ 소문 단정: knowledge.rumorOnly 항목을 단정 종결("…이오", "…했소")으로 말하면 경고.
   전문 종결("…라 하더이다", "…라는 소문이오")은 통과
```

- **R-37-20** ③이 이 문서에서 가장 강한 자동 가드레일이다. 지식 범위를 선언하지 않은 액터는
  이 검사를 받지 못하므로, **`knowledge` 미선언 액터는 애초에 스키마가 거부**한다([BP-22 §5.1](22_world_bible_model.md) 필수 필드).

### 37.7.3 G-2 현대어 — 검출 상세

| 층 | 방법 | 예 |
|---|---|---|
| 어휘 | 금칙어 사전([BP-43](43_content_style_guide.md) 소유) | 휴대폰, 인터넷, 시스템, 업데이트, 스트레스 |
| 종결어미 | 정규식 | `요[.!?]?$`, `습니다[.!?]?$`, `할게[.!?]?$`, `했어[.!?]?$` |
| 문자 | 유니코드 범위 | 이모지(Emoji 블록), 전각 기호 남용 |
| 약어 | 정규식 | `\b(NPC|HP|MP|AI|OK|BGM)\b` (UI 문자열 `str.*.ui.*` 는 예외) |

- **R-37-21** 종결어미 정규식은 **경고**이지 하드 실패가 아니다. `allowedRegisters`
  (취객·아이 등)에 해당하는 화자는 예외이며, 그 예외는 액터 파일이 선언한다([BP-22 §2.4](22_world_bible_model.md)).

### 37.7.4 G-3 고유명사 임의 창작 — 검출 상세

```
사전 = ∪ { 엔티티의 표시명(strings 의 .name 값), 엔티티의 _aliases[] }
      ∪ { 원작 고정 표기: Lord Ahn, Necromancer, LORE, MENACE, Ancient Evil,
                          Red Antares, 또 다른 지식의 성전 }

후보 추출:
  ① 로마자 대문자로 시작하는 연속 토큰            → "Grimhold" 같은 창작 지명
  ② 「…성」「…촌」「…탑」「…단」「…교」로 끝나는 2~6자 한글 명사구
  ③ 「…의 …」 형태로 반복 등장하는 고유명사 후보

판정: 후보 ∉ 사전  →  하드 실패, hint 로 "바이블에 등재하거나 기존 이름을 쓰세요"
```

- **R-37-22** 이 검사가 StyleEditor 의 **고유명사 불변식**([BP-32 R-32-40](32_generation_harness.md))과
  같은 사전을 쓴다. 사전이 하나여야 "교정 중에 이름이 바뀌었다" 를 판정할 수 있다.
- **R-37-23** ②③은 오탐이 잦다(일반 명사 "성문", "관문"). 따라서 **경고**로 두고,
  ①만 하드 실패로 한다. 오탐이 나면 `_aliases` 에 등재하는 것으로 해소한다.

### 37.7.5 허용 치환 토큰 (`{{substitution_tokens}}` 내용)

```
{p0.name}    파티 1번 멤버 이름        {p0.class}   파티 1번 멤버 직업명
{p1.name}    파티 2번 멤버 이름        {p1.class}   파티 2번 멤버 직업명
{party.gold} 소지금                    {map.name}   현재 맵 표시명
{item.<id>}  아이템 표시명             {actor.<id>} 액터 표시명

- 위 목록 밖의 토큰은 만들지 않는다.
- {actor.<id>} / {item.<id>} 의 <id> 는 실재하는 엔티티 id 여야 한다.
- 토큰을 색상 태그 안에 넣을 수 있다: @B{actor.npc.core.lord_ahn}@@
- 파티원 이름을 문장에 직접 쓰지 않는다. 기본값("슴갈", "유리")도 마찬가지다.
```

### 37.7.6 허용 색상 태그 (`{{color_tags}}` 내용)

```
@B …@@   헤더·고유명사 강조 (기본)
@7 …@@   지문·설명
@E …@@   중요 강조
@C …@@   경고·위험

- 여는 태그는 같은 문자열 안에서 반드시 @@ 로 닫는다. 문자열 경계를 넘지 않는다.
- 중첩 금지. 색을 바꾸려면 닫고 다시 연다.
- 한 문자열에 색 구간 3개 초과 금지.
- 본문에 리터럴 @ 를 쓰지 않는다(종료 토큰과 충돌).
```

- 문법·균형·중첩 규칙의 SSoT 는 [BP-21 §5.5](21_content_pack_spec.md) 다. 위는 그 요약 주입본이다.

### 37.7.7 가드레일이 잡지 못하는 것

| 못 잡는 것 | 왜 | 대체 방어 |
|---|---|---|
| 문법적으로 옳지만 재미없는 대사 | 판정 기준이 없다 | Critic Q3 + 사람 HG-3 |
| 세계관과 모순되지 않지만 **아무것도 더하지 않는** 설정 | 모순이 아니므로 통과 | Critic Q1 3점 |
| 미묘한 말투 균질화 | 통계로만 보임 | Critic Q2 + `stats` 분포 리포트 |
| 이미 있는 이야기의 교묘한 변주 | 문자열 유사도로는 안 잡힘 | Critic Q7 + [I] 블록 |

---

## 37.8 프롬프트 버전 관리

### 37.8.1 버전 규약

- **R-37-24** 파일명이 곧 버전이다: `<role>.<version>.md`. 버전은 `v1`, `v2`, … 정수 증가.
  마이너 버전을 쓰지 않는다 — "조금만 바꿨다" 는 개념이 없다. 바뀌면 다른 프롬프트다.
- **R-37-25** 프롬프트 묶음(`promptSet`)은 **역할 6종 + 프리앰블 + 스키마 파일** 전체의 스냅샷이다.
  주문서의 `promptSet: "v1"` 은 `content_gen/prompts/` 의 `*.v1.md` 집합을 가리킨다.
  역할 하나만 바꿔도 **묶음 버전이 올라간다** — 그래야 지표를 묶음 단위로 비교할 수 있다.
- **R-37-26** 옛 버전 파일은 **삭제하지 않는다.** 과거 run 의 manifest 가 그 해시를 가리키고 있으므로,
  지우면 그 실행을 재구성할 수 없다.
- **R-37-27** `changelog` front matter 에 무엇을 왜 바꿨는지 한 줄씩 남긴다.

### 37.8.2 회귀 비교 절차 (프롬프트를 바꿀 때)

```
1. 대표 주문서 3건을 고른다 — 골든 오더(golden orders).
   ① 단순 사이드 퀘스트(신규 엔티티 0)  ② 신규 NPC 2인 포함  ③ 분기 있는 퀘스트
   골든 오더는 content_gen/orders/golden/ 에 고정하고 바꾸지 않는다.
2. 새 promptSet 으로 3건을 각각 3회씩(총 9회) 실행한다. 3회인 이유: LLM 분산을 보기 위해.
3. metrics/runs.jsonl 에서 아래 지표를 묶음별로 집계해 비교한다.
4. 승격 판정(§37.8.3)을 적용한다.
5. 승격되면 pack.json#generatedBy.promptVersion 을 새 값으로 쓰기 시작한다.
```

**비교표 양식**

| 지표 | v1 (9회) | v2 (9회) | 판정 |
|---|---|---|---|
| 첫 시도 통과율 `firstPassYield` | | | 높을수록 좋음 |
| 최초 lint Hard 위반 수 `firstLintHard` | | | 낮을수록 좋음 |
| Repair 라운드 `repairRounds` | | | 낮을수록 좋음 |
| 루브릭 총점 평균 `rubricAvg` | | | 높을수록 좋음 |
| 축 최저점 평균 `rubricMinAvg` | | | 높을수록 좋음 |
| `revise` 비율 | | | 낮을수록 좋음 |
| 호출 수 `callsPerQuest` | | | 낮을수록 좋음 |
| 총 토큰 `tokensPerQuest` | | | 낮을수록 좋음 |
| 사람 반려율 `humanRejectRate` | | | 낮을수록 좋음 |

### 37.8.3 승격 판정 (확정)

새 `promptSet` 은 아래를 **모두** 만족해야 기본값으로 승격된다.

```
① rubricAvg 가 낮아지지 않았다 (−0.5 이내는 동일로 본다)
② rubricMinAvg 가 낮아지지 않았다
③ firstLintHard 평균이 늘지 않았다
④ 아래 중 하나 이상이 뚜렷이 개선됐다:
     firstPassYield +0.1 이상 / repairRounds −0.3 이상 /
     callsPerQuest −1 이상 / revise 비율 −0.1 이상
⑤ 골든 오더 3건 모두가 최소 1회씩 8단계에 도달했다
```

- **R-37-28** ⑤가 없으면 "평균은 좋아졌는데 특정 유형을 아예 못 만든다" 를 놓친다.
- **R-37-29** 승격 실패한 버전도 파일은 남긴다(R-37-26). `changelog` 에 "승격 실패: 사유" 를 적는다.

### 37.8.4 프롬프트 변경이 콘텐츠에 미치는 영향

- **R-37-30** 프롬프트가 바뀌면 **이미 커밋된 콘텐츠는 재생성하지 않는다.**
  ID 는 불변이고([BP-21 §4.6](21_content_pack_spec.md)) 세이브 호환이 걸려 있다.
  새 프롬프트는 **새로 만드는 것부터** 적용한다.
- **R-37-31** 그 결과 한 팩 안에 서로 다른 `promptVersion` 으로 만든 콘텐츠가 섞인다.
  이것은 정상이며, `pack.json#generatedBy.promptVersion` 은 **가장 최근 값**을 담는다.
  퀘스트별 출처는 `quest.generatedBy`([BP-23 §23.2.1](23_quest_model.md))에 남는다.
- **Q-37-2** 오래된 프롬프트로 만든 콘텐츠를 언제 다시 만들지(또는 은퇴시킬지)의 기준은
  아직 없다. 팩이 커진 뒤 `stats` 로 품질 편차를 본 다음 정해야 한다.

---

## 37.9 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 37.9.1 확정한 것

1. **프롬프트 계약 원칙 6가지** — 스키마 강제, 예시 제공(좋은 것 + 나쁜 것), 금지 목록,
   자기수정 지시, 화이트리스트 우선, 역할 격리(R-37-1~6).
2. **프롬프트 파일 형식** — YAML front matter(`role`,`version`,`outputSchema`,`model`,`requiredVars`,`changelog`)
   + 본문. 전체 SHA-256 이 manifest 기록 대상(R-37-7~9).
3. **템플릿 변수 사전 34종** — 누가 채우고 어느 컨텍스트 블록에서 오는지(§37.1.3).
4. **공통 프리앰블** — 절대 규칙 6개 + 세계관 고정 + 컨텍스트 블록 머리표 규약(§37.2).
5. **실물 프롬프트 6종** — Planner / Writer 구조 / Writer 문장 / Critic / StyleEditor / Repair.
   각각 그대로 `content_gen/prompts/` 에 넣어 쓸 수 있는 원문(§37.3).
6. **결정론 에이전트는 프롬프트가 없다** — Binder·Orchestrator 는 입출력 계약이 프롬프트를 대신(R-37-11).
7. **출력 스키마 6종 전문** — `QuestOutline`, `QuestDraft`(+`keyManifest`), `DialogueDraft`,
   `StringsDraft`, `CriticReport`, `StyleReport`. 필드마다 설명 포함(§37.4).
8. **`keyManifest`** — 구조 패스와 문장 패스를 잇는 계약. `mustMention`/`mustNotMention` 으로
   정보 노출 순서를 통제(§37.4.2).
9. **검수 루브릭 8축** — Q1 세계관 / Q2 목소리 / Q3 서사 / Q4 명료성 / Q5 밸런스 / Q6 문체 /
   Q7 참신성 / Q8 통합성. 각 0~5점(§37.5.1).
10. **하드/소프트 게이트 분리표** — Critic 은 12개 Hard 항목에 **권한이 없고** 8개 Soft 축만 본다(§37.5.2).
11. **합격선** — `pass`(모든 축 ≥4, 총점 ≥34) / `conditional`(≥3, ≥30) / `revise`.
    `severity:"blocking"` 은 점수와 무관하게 `revise` 강제(§37.5.3).
12. **Few-shot 좋은 예 1 + 나쁜 예 1** — 실제 Hadar 소재(성문 위병 · 실종 학자)로,
    나쁜 예는 13종의 실패를 한 파일에 몰아 넣고 주석표를 함께 실음(§37.6).
13. **금칙 6종과 3층 방어** — 프롬프트(화이트리스트) → 기계 검출 → Critic. 각각의 검출 알고리즘(§37.7).
14. **허용 치환 토큰 8종 · 색상 태그 4종**(§37.7.5, §37.7.6).
15. **프롬프트 버전 관리** — 정수 버전, 묶음 단위 스냅샷, 삭제 금지, 골든 오더 3건 회귀 비교,
    5항목 승격 판정(§37.8).

### 37.9.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| 금칙어 사전 원문, 종결어미 규칙, 어투 예문 | [BP-43](43_content_style_guide.md) |
| `DV-06b`(토큰), `DV-07d`(색상 태그), `QV-31~34`(보상) 등 규칙의 정확한 판정식 | [BP-33](33_validation_and_lint.md) |
| `{{trace_summary}}` 의 정확한 형식(솔버 경로 요약을 어떻게 압축하는가) | [BP-34](34_headless_sim_and_solver.md) |
| `GET /api/content/context?for=` 가 반환하는 컨텍스트 블록의 직렬화 형식 | [BP-31](31_content_server_api.md) |
| `schemas/*.schema.json` 파일 배치와 `$ref` 해소(quest.json / dialogue.json 등 콘텐츠 스키마 전문) | [BP-90](90_appendix_schemas.md) |
| 루브릭 점수를 수용 기준(DoD)으로 승격 | [BP-53](53_acceptance_criteria.md) |
| few-shot 예시를 실제 완주 예제로 확장 | [BP-91](91_appendix_worked_example.md) |
| 프롬프트 작성·회귀 비교를 태스크로 분해 | [BP-51](51_task_breakdown.md) |

### 37.9.3 열린 질문

| ID | 질문 | 왜 지금 못 정하는가 |
|---|---|---|
| **Q-37-1** | 합격선(`pass` ≥34, `conditional` ≥30)이 적정한가 | Critic 점수와 사람 채점의 상관을 측정해야 한다. 파일럿 20건 이후 ±2 범위 조정 |
| **Q-37-2** | 옛 프롬프트로 만든 콘텐츠를 언제 재생성/은퇴시키는가 | 팩이 작아 편차가 안 보인다. `stats` 로 품질 편차를 본 뒤 |
| **Q-37-3** | 문장 패스를 **대화 단위**가 아니라 **화자 단위**로 묶으면 목소리 일관성이 오르는가 | 두 방식의 Q2 점수 비교가 필요. 골든 오더 회귀로 측정 가능 |
| **Q-37-4** | `keyManifest.mustNotMention` 을 모델이 실제로 지키는가 | 부정 지시의 준수율은 모델마다 다르다. 지키지 않으면 화이트리스트 축소로 대체해야 한다 |
| **Q-37-5** | Critic 을 서로 다른 모델 2개로 이중화할 가치 | [BP-32 Q-32-3](32_generation_harness.md)과 같은 질문. 비용 2배 대비 이득 미측정 |
| **Q-37-6** | 고유명사 검출 ②③(한글 명사구 패턴)의 오탐률이 실용 수준인가 | 실제 원작 대사 코퍼스(`assets/*.cm2`)에 돌려 봐야 안다. 오탐이 많으면 ①만 남긴다 |
| **Q-37-7** | 나쁜 예를 프롬프트에 넣는 것이 오히려 모방을 유발하지는 않는가 | 일반적으로 주석과 함께 주면 도움이 된다고 알려져 있으나 이 세팅에서 미검증. 골든 오더로 A/B 비교 가능 |
