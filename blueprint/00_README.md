# Hadar2026 — AI 콘텐츠 파이프라인 기획서

> **문서 ID**: BP-00 · **상태**: 확정 · **선행 문서**: 없음 (여기가 시작점)
> **독자**: 이 기획을 처음 보는 모든 사람 · **한 줄 요약**: 배포 전에 AI 로 맵·대화·퀘스트를 대량 생성하고,
> 실시간에는 AI 를 전혀 쓰지 않는 파이프라인을 만들기 위한 단일 진실 원천(SSoT).


> ## ⚠ 실행 노선이 바뀌었다 (2026-09-01)
>
> 이 기획서의 **설계**는 유효하다. 그러나 **실행 순서는 폐기되었다.**
> 착수 계획은 [`issues/`](../issues/README.md) 가 정본이며, 판정 근거는
> [`issues/DECISION-LOG.md`](../issues/DECISION-LOG.md) 의 **2차 판정**에 있다.
>
> 무엇이 바뀌었나: 이 기획서는 "퀘스트를 만들 수 있게 만드는 것" 부터 시작했지만,
> **원작 방식(`assets/flag4ep1.cm2` + `L1_ep1d0~d5_1.cm2`, 2,441줄)이 이미 작동한다.**
> 그래서 노선이 **sample-first + cm2** 로 바뀌었고, 선언적 콘텐츠 팩·인벤토리·저널·솔버는 **보류**되었다.
>
> - **여전히 정본**: [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md)(코드 실측 부록 A~M) · [`_meta/DECISIONS.md`](_meta/DECISIONS.md)(D-01~D-31)
> - **1차 노선 기준이라 참고만**: [BP-01](01_executive_summary.md) 경영요약 · [BP-50](50_roadmap.md) 로드맵 · [BP-51](51_task_breakdown.md) 태스크
> - **보류 노선의 설계**: BP-21~27(선언적 모델) · BP-31~34(서버·솔버·하네스) — 필요해질 때 꺼내 쓴다

---

## 이 문서 묶음이 무엇인가

Hadar2026 은 1990년대 한국 RPG **"또 다른 지식의 성전(Hadar)"** 의 Flutter 리메이크다.
이 기획서는 그 게임의 **맵·대화·퀘스트를 AI 로 미리 만들어 두는 생산 체계**를 설계한다.

**핵심 전제 하나만 기억하면 된다.**

> AI 는 **배포 전에만** 쓴다. 플레이어가 게임을 실행하는 동안에는 AI 가 **한 줄도 개입하지 않는다.**
> 게임은 구워진 데이터를 결정론적으로 해석만 한다.

이 전제에서 모든 설계가 파생된다. 자세한 이유는 [BP-20](20_target_architecture.md) §2.

## SSoT 규칙 — 이 문서 묶음을 다루는 법

1. **여기가 유일한 정본이다.** 설계에 관한 질문의 답은 이 디렉토리 안에 있다.
   코드 주석·채팅·기억과 충돌하면 **이 문서가 이긴다.**
2. **주제마다 소유 장이 하나씩 있다.** 소유 장이 정의하고, 나머지는 링크만 한다.
   소유권 표는 [`_meta/DECISIONS.md`](_meta/DECISIONS.md) 의 **D-18**.
3. **정의를 복사하지 마라.** 이 규칙을 어겨서 실제로 사고가 났다(D-20 초판이 payload 12행 중 9행을 잘못 옮겨 적었다).
   그래서 **D-25** 가 "결정 문서조차 스키마를 전재하지 않는다" 를 규칙으로 못박았다.
4. **코드 사실은 `_meta/GROUND_TRUTH.md` 가 정본이다.** 부록 A~K 의 실측 사실과 어긋나는 서술은 결함이다.
5. 문서를 고칠 때는 **소유 장을 고친다.** 참조하는 쪽을 고쳐서 맞추면 SSoT 가 깨진다.

## 읽는 순서

### 처음 보는 사람 (30분)
1. [BP-01 경영 요약](01_executive_summary.md) — 왜, 무엇을, 어떤 순서로
2. [BP-11 결함 분석](11_gap_analysis.md) §결론 — "지금 구조로 되는가?" 에 대한 답
3. [BP-20 목표 아키텍처](20_target_architecture.md) §1 그림 한 장
4. [BP-50 로드맵](50_roadmap.md) §마일스톤 표

### 구현을 시작하는 사람
1. [BP-51 태스크 분해](51_task_breakdown.md) §첫 10개 태스크
2. 담당 영역의 소유 장 (아래 지도 참조)
3. [BP-53 수용 기준](53_acceptance_criteria.md) — 무엇을 만족해야 "끝" 인가
4. [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md) — 손대기 전에 반드시

### 콘텐츠를 만드는 사람 (사람이든 AI 든)
1. [BP-43 문체 가이드](43_content_style_guide.md)
2. [BP-91 엔드투엔드 예제](91_appendix_worked_example.md) — 실물 하나를 통째로
3. [BP-31 콘텐츠 서버 API](31_content_server_api.md)
4. [BP-37 프롬프트 계약](37_prompt_contracts.md)

## 문서 지도

### 0. 총론
| 문서 | 내용 |
|---|---|
| [BP-00](00_README.md) | 이 문서 |
| [BP-01](01_executive_summary.md) | 경영 요약 — 판단과 근거 |
| [BP-02](02_glossary.md) | 용어 사전 216항목 · 혼동 주의 쌍 · **폐기된 용어** |

### 1. 현황 진단 — "지금 어떻게 되어 있는가"
| 문서 | 내용 |
|---|---|
| [BP-10](10_current_architecture_audit.md) | 현행 구조 정밀 감사 |
| [BP-11](11_gap_analysis.md) | 결함 34건 · **"AI 자동 생성이 가능한가" 에 대한 정면 답변** |
| [BP-12](12_reference_designs.md) | 타 게임/툴 13종 참조와 취사선택 |

### 2. 목표 아키텍처 — "무엇을 만들 것인가"
| 문서 | 소유 주제 |
|---|---|
| [BP-20](20_target_architecture.md) | 전체 그림 · 불변식 18개 |
| [BP-21](21_content_pack_spec.md) | **Condition/Effect DSL · ID 문법 · 문자열 키 · 팩 매니페스트** |
| [BP-22](22_world_bible_model.md) | **세계관·액터·아이템 카탈로그 스키마** |
| [BP-23](23_quest_model.md) | **퀘스트/스테이지/목표 스키마 · 월드 이벤트 12종 · 보상 티어** |
| [BP-24](24_dialogue_model.md) | **대화 그래프 스키마 · 텍스트 길이 수치** |
| [BP-25](25_world_state_and_save.md) | **월드 상태 · 세이브 v2 · 마이그레이션** |
| [BP-26](26_entity_registry_and_anchors.md) | **앵커 · 트리거 인덱스 · 앵커/타일 정합** |
| [BP-27](27_runtime_engine.md) | **런타임 실행 경로 · 난수 소유 · `pendingNavigation`** |
| [BP-28](28_migration_and_coexistence.md) | **이관 상태 기계 · cm2 공존** |

### 3. 툴과 하네스 — "어떻게 만들 것인가"
| 문서 | 소유 주제 |
|---|---|
| [BP-30](30_toolchain_overview.md) | 툴체인 전체 그림 |
| [BP-31](31_content_server_api.md) | 콘텐츠 서버 REST/MCP API |
| [BP-32](32_generation_harness.md) | 8단계 생성 파이프라인 · 에이전트 역할 6종 |
| [BP-33](33_validation_and_lint.md) | **검증 규칙 카탈로그** |
| [BP-34](34_headless_sim_and_solver.md) | **시뮬레이터 · 솔버 · 선결 리팩터링** |
| [BP-35](35_ci_and_build.md) | **빌드 산출물 · CI · 결정론** |
| [BP-36](36_map_editor_extension.md) | 맵 에디터 확장 |
| [BP-37](37_prompt_contracts.md) | 프롬프트 원문 · 출력 스키마 · 검수 루브릭 |

### 4. 게임 변경 — "플레이가 어떻게 달라지는가"
| 문서 | 소유 주제 |
|---|---|
| [BP-40](40_gameplay_changes.md) | 진행 방식 변경점 총괄 |
| [BP-41](41_journal_ui_spec.md) | 저널/추적 UI (800×480) |
| [BP-42](42_item_and_inventory.md) | **아이템 데이터 · 인벤토리 규칙 · 장비 마이그레이션** |
| [BP-43](43_content_style_guide.md) | **문체 규칙** |

### 5. 실행
| 문서 | 내용 |
|---|---|
| [BP-50](50_roadmap.md) | 마일스톤 M0~M6 |
| [BP-51](51_task_breakdown.md) | 태스크 156개 · 의존 그래프 · 임계 경로 |
| [BP-52](52_risks.md) | 리스크 38건 · 감수 리스크 13건 |
| [BP-53](53_acceptance_criteria.md) | 수용 기준 · 수치 목표 73개 |

### 부록
| 문서 | 내용 |
|---|---|
| [BP-90](90_appendix_schemas.md) | JSON Schema 22개 원문 · 불일치 목록 |
| [BP-91](91_appendix_worked_example.md) | 퀘스트 1건의 기획→생성→검증→플레이 전 구간 실물 |
| [BP-92](92_appendix_reference_index.md) | 참조 색인 · 타 시스템 용어 대응 |

### 내부 자료 (`_meta/`)
기획서 본문이 아니라 **제작·검수 과정의 인프라**다. 그러나 `GROUND_TRUTH` 와 `DECISIONS` 는 본문만큼 중요하다.

| 파일 | 역할 |
|---|---|
| [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md) | **코드 실측 정본.** 부록 A~K 에 36개 항목 — 검증된 잠복 결함, 서술 정정, 집계 정정 |
| [`_meta/DECISIONS.md`](_meta/DECISIONS.md) | **확정 결정 D-01~D-31.** 개정 이력(D-08a·D-20a·D-21a·D-29a) 포함, D-24 결번 |
| [`_meta/OUTLINE.md`](_meta/OUTLINE.md) | 목차·배정표 |
| [`_meta/REVIEW_RUBRIC.md`](_meta/REVIEW_RUBRIC.md) | 검수 7축 채점표 |
| [`_meta/reviews/`](_meta/reviews/) | 장별 검수 보고서 |

## 이 기획서가 만들어진 방식

**제작 에이전트와 검수 에이전트를 분리**해 만들었다. 제작자가 쓰고, 별도 검수자가 코드를 직접 열어 대조하고,
그 지적을 제작자가 반영하는 순환을 돌렸다. 검수자는 문서를 고치지 않고 보고서만 쓴다.

이 방식이 실제로 잡아낸 것들:
- 존재하지 않는 RPG Maker 명령 의미를 사실처럼 서술한 것 (부록 E-1)
- "cm2 는 튜링 완전이라 검증 불가" 라는 **결론은 맞지만 근거가 틀린** 논증 (부록 E-3)
- 세 장이 월드 이벤트 이름을 각자 다르게 "닫힌 집합" 이라 선언한 것 (D-20)
- 조건식이 난수 커서를 밀어 **순수성을 깨뜨리는** 설계 (D-21)
- 문자열 키 정규식이 **자기 문서의 예시조차 통과 못 하는** 것 (BP-91 W-01)
- **메인(조정자) 자신의 오기** — 결정 문서가 소유 장 payload 를 9행 잘못 옮긴 것 (D-20a → D-25)

마지막 항목이 이 방식의 핵심이다. **조정자도 검수 대상이다.**

## 이 기획서를 유지하는 법

- 코드를 고쳤으면 `_meta/GROUND_TRUTH.md` 를 먼저 갱신한다.
- 설계를 바꿨으면 **소유 장**을 고치고, `_meta/DECISIONS.md` 에 개정 이력을 남긴다.
- 새 장을 추가하면 `_meta/OUTLINE.md` 와 이 문서의 지도를 갱신한다.
- 결정을 뒤집을 때는 **왜 초판이 틀렸는지**를 함께 남긴다. D-08a·D-20a·D-21a 가 그 형식의 예다.
