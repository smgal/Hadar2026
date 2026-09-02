# BP-92 · 부록: 참조 색인

> `상태: 참고` — 현황 조사·참조 자료. 사실 정본은 [`_meta/GROUND_TRUTH.md`](_meta/GROUND_TRUTH.md) 이며,
> 이 장의 **결론·권고는 1차 노선 기준**이라 [`issues/DECISION-LOG.md`](../issues/DECISION-LOG.md) 2차 판정이 우선한다.

> **문서 ID**: BP-92 · **상태**: 초안 · **선행 문서**: [BP-12](12_reference_designs.md)
> **독자**: 아키텍트 · 콘텐츠 저작자 · 외부 자료를 읽다가 용어가 막힌 사람
> **한 줄 요약**: [BP-12](12_reference_designs.md) 가 인용한 모든 참조원을 한 표로 색인하고, **남의 용어 ↔ 본 기획서 용어** 대응표를 제공한다.

---

## 92.1 이 부록의 사용법

이 문서는 두 가지 목적으로만 쓴다.

1. **역방향 조회** — "이 설계 왜 이렇게 됐지?" → 92.2 색인에서 참조원을 찾아 [BP-12](12_reference_designs.md) 의 해당 절로 간다.
2. **용어 번역** — 외부 문서(Creation Kit 위키, Ink 문법서, Yarn 문서 등)를 읽다가 "이게 우리 뭐에 해당하지?" → 92.4 대응표.

**이 문서는 결정을 내리지 않는다.** 모든 채택/기각 판정의 근거는 BP-12 에 있고, 확정 결정은 `_meta/DECISIONS.md` 에 있다.

> **D-18(SSoT 소유권) 상 이 부록의 지위**: 이 부록은 **용어 대응표의 SSoT** 다(BP-12 §12.1.1 이 이를 선언).
> 반대로 스키마 자체는 하나도 소유하지 않는다 — `Condition`/`Effect` 는 BP-21, `Quest`/`Stage`/`Objective` 는 BP-23,
> `Dialogue`/`Node`/`Choice` 는 BP-24, `Anchor` 는 BP-26, 세이브 v2 는 BP-25 소유다.
> 92.4 의 오른쪽 열은 **소유 장의 용어를 인용**할 뿐이며, 시그니처를 재정의하지 않는다.
> 소유 장과 이 표가 어긋나면 **소유 장이 이긴다** — 그때는 이 표를 고친다.

### 92.1.0 식별자 접두사

| 접두사 | 의미 | 비고 |
|---|---|---|
| `REF-01` ~ `REF-16` | 참조원 색인 번호 (92.2) | 개정 전 표기 `R01`~`R16` 에서 개칭 — 요구사항 ID `R-12-nn`(DECISIONS 규약 3)과 시각적으로 혼동됐다 |
| `VER-1` ~ `VER-7` | 검증 백로그 항목 (92.5.2) | 개정 전 표기 `V-1`~`V-7` 에서 개칭 |
| `R-12-nn` | **BP-12 가 도출한 요구사항** | 이 부록이 만드는 것이 아니라 인용하는 것 |
| `Q-12-n` | **BP-12 의 열린 질문** | 동상 |

### 92.1.1 신뢰도 등급 (BP-12 §12.1.4 와 동일)

| 등급 | 의미 | 설계 근거로 인용 가능? |
|---|---|---|
| **확인됨** | 본 레포 실측, 또는 널리 공개된 포맷·문법 수준의 사실 | ✅ 가능 |
| **부분확인** | 개념은 확실하나 세부(필드명·동작 순서·버전차)는 미검증 | ⚠ 개념 수준까지만 |
| **미확인** | 통념으로 알려져 있으나 이 기획 작업 중 근거를 확보하지 못함 | ❌ **인용 금지** (아래 예외 참조) |

> **예외 규칙 (개정에서 명문화)**: [미확인] 항목이라도 **① 그 항목에 의존하지 않는 독립 정당화가 함께 적혀 있고
> ② 등급이 본문에 명시돼 있으면**, "결정의 유일한 근거" 가 아닌 **보조 서술**로는 인용할 수 있다.
> REF-12(LLM 파이프라인 일반론)가 이 예외에 해당한다 — 전체가 [미확인] 이지만 P1~P5·F1~F6 각 항목이
> D-01/D-02 로 독립 정당화되므로 D-14/D-15 의 **체크리스트**로 쓴다.
> 이 예외 없이 문면 그대로 읽으면 92.3 REF-12 의 "그럼에도 설계에 쓰는 이유" 절이 규칙 위반이 된다. 규칙을 실무에 맞춘다.
>
> **금지선은 그대로다**: [미확인] 을 **유일한 근거**로 D-nn 을 세우거나, 등급 표기 없이 단정하는 것은 여전히 금지다.

### 92.1.2 분류(Category) 코드

| 코드 | 뜻 | 예 |
|---|---|---|
| **G** | 게임 (Game) — 완성된 상용 게임의 설계 | Skyrim, FNV, Witcher 3, DF |
| **E** | 엔진 / 프레임워크 (Engine) | RPG Maker MV/MZ |
| **T** | 저작 도구 (Tool) | Twine |
| **L** | 언어 / DSL (Language) | Ink, Yarn Spinner, Papyrus, cm2 |
| **P** | 관행 / 패턴 (Practice) — 특정 제품이 아닌 업계 일반 원리 | 데이터 드리븐 테이블, LLM 파이프라인, 퍼즐 솔버 검증 |
| **H** | 본 레포 자체 (Here) — 우리 코드가 곧 참조원인 경우 | mapEditor AI API, cm2 |

---

## 92.2 참조원 마스터 색인

| # | 이름 | 분류 | 우리가 가져온 개념 | 명시적으로 버린 것 | 관련 BP 문서 | 신뢰도 |
|---|---|:--:|---|---|---|:--:|
| **REF-01** | RPG Maker MV / MZ | E | 이벤트 **페이지 = 조건별 변형**, 전역 switch/variable + 로컬 상태 2층 구조, 좌표 상호작용 단위 | `pages[].list[]` 명령 코드 인터프리터, 번호 스위치, 병렬/자동 트리거, 맵 안 대사 저장, **코드 101 을 `Node.header` 계보로 삼는 것** | [BP-12 §12.2](12_reference_designs.md), [BP-24](24_dialogue_model.md), [BP-26](26_entity_registry_and_anchors.md), [BP-28](28_migration_and_coexistence.md) | 확인됨 (우리 맵 JSON 이 이 포맷) · ⚠ 하위 **부분확인**: 코드 111/121/122/201 파라미터, `trigger` 접촉 계열 세분 |
| **REF-02** | Bethesda Radiant Quest (Skyrim / Fallout 4) | G | **Stage/Objective 분리 FSM**, 저널을 Stage 가 소유, **템플릿+슬롯(Alias)** 발상, **Story Manager** = 사건→퀘스트 중개자 | 런타임 Alias Fill, 무한 반복 퀘스트, Package(NPC AI), Stage 에 붙는 스크립트 조각 | [BP-12 §12.3](12_reference_designs.md), [BP-23](23_quest_model.md), [BP-32](32_generation_harness.md) | **확인됨(개념·명칭)** — Story Manager / Alias fill 검증 완료(VER-3 종결) · 하위 **부분확인**: Objective/Stage 필드 세부 |
| **REF-03** | Fallout: New Vegas (Obsidian) | G | **실패 가능 퀘스트**, 다중 해결 경로, 퀘스트 간 상호 배제, 조건이 보이는 선택지 | 대규모 진영 평판 매트릭스, 확률 스킬 체크, 전 NPC 살해 가능, 다중 엔딩 | [BP-12 §12.4](12_reference_designs.md), [BP-23](23_quest_model.md), [BP-34](34_headless_sim_and_solver.md) | 부분확인 |
| **REF-04** | The Witcher 3 (CD Projekt Red) | G | 퀘스트↔대화 **양방향 결합**(퀘스트가 대화를 부르고, 선택이 퀘스트를 진행), 조건부 씬 라우팅, 서술형 저널 | 퀘스트-대화 단일 그래프, 연출 타임라인, 시간 만료 퀘스트, 레벨 스케일 보상 | [BP-12 §12.5](12_reference_designs.md), [BP-23](23_quest_model.md), [BP-24](24_dialogue_model.md) | 부분확인 |
| **REF-05** | Ink (inkle) | L | **소스 → 컴파일 → 런타임 3분할**, 소진되는 선택지(`once`), 소스는 diff 가능한 텍스트, 재현성 | Ink 문법 전체, weave 자동 합류, tunnel, EXTERNAL 함수, ink 런타임 Dart 포팅 | [BP-12 §12.6](12_reference_designs.md), [BP-20](20_target_architecture.md), [BP-24](24_dialogue_model.md) | 확인됨 (문법·파이프라인 수준) |
| **REF-06** | Yarn Spinner | L | **이름 있는 Node 그래프**, **line ID / string table 분리**, `declare` 형 변수 선언 강제, 컴파일러 정적 검사 목록, 노드 태그 | Yarn 문법, 임의 `<<command>>` 디스패치, Unity 통합 계층, 런타임 타입 추론 | [BP-12 §12.7](12_reference_designs.md), [BP-21](21_content_pack_spec.md), [BP-24](24_dialogue_model.md), [BP-33](33_validation_and_lint.md) | 확인됨 (문법·워크플로 수준) / 정적검사 세부는 부분확인 |
| **REF-07** | Twine / Harlowe | T | **읽기 전용 그래프 시각화**, 문제 노드 색상 강조, 시작점 명시 강제 | 시각적 드래그 저작, 링크가 노드를 자동 생성하는 것, 스토리 포맷 다양성, HTML 단일 파일 배포 | [BP-12 §12.8](12_reference_designs.md), [BP-31](31_content_server_api.md), [BP-36](36_map_editor_extension.md) | **확인됨**(끊어진 링크 시각 표시 — VER-4 절반 종결) · 하위 **미확인**: 고립 노드 자동 분석 지원 여부 |
| **REF-08** | Papyrus (Bethesda 스크립트 언어) | L | **반면교사** — 스크립트를 데이터에 심으면 정적 검증이 불가능해진다. 세이브에 스크립트 상태를 담지 않기 | 스크립트 노선 자체. 신규 스크립트 언어 도입·확장, Effect 안의 스크립트 훅 | [BP-12 §12.9](12_reference_designs.md), [BP-25](25_world_state_and_save.md), [BP-28](28_migration_and_coexistence.md), [BP-52](52_risks.md) | 부분확인 / VM 지연 특성은 **미확인** |
| **REF-09** | 데이터 드리븐 밸런스 테이블 (라이브 서비스 일반) | P | 수치를 코드에서 분리, **CI 스키마·참조 무결성 검사**, diff 리뷰, **테이블 상속/오버라이드 = 팩 합성**, 분포 리포트 | 런타임 핫패치, 스프레드시트 소스, 텔레메트리 자동 밸런싱 | [BP-12 §12.10](12_reference_designs.md), [BP-21](21_content_pack_spec.md), [BP-35](35_ci_and_build.md), [BP-42](42_item_and_inventory.md) | 확인됨 (원리 수준) / 개별 회사 내부 툴은 **미확인** |
| **REF-10** | 퍼즐 검증 관행 (Zachtronics · Baba Is You 계열) | P | **"퀘스트는 퍼즐이다"** — 솔버로 완주 가능성 증명, generate→solve→통과분만 채택, 최소 재현 시퀀스, 난이도 부산물, 시드 퍼징 | 완전 상태 공간 탐색, 최적해 요구, 전투 정밀 시뮬레이션 | [BP-12 §12.11](12_reference_designs.md), [BP-34](34_headless_sim_and_solver.md), [BP-33](33_validation_and_lint.md) | 확인됨 (PCG 일반 원리) / 개별 게임 내부 솔버는 **미확인** |
| **REF-11** | Dwarf Fortress · Caves of Qud | G | **세계 먼저, 서사 나중** 순서. 손 뼈대 + 생성 세부의 층 분리(= 팩 경계 = 신뢰 경계). 모든 고유명사가 출처를 갖게 하기 | 런타임 세계 생성, 역사 시뮬레이션 엔진, 플레이마다 달라지는 콘텐츠, 무한 세계 | [BP-12 §12.12](12_reference_designs.md), [BP-22](22_world_bible_model.md), [BP-21](21_content_pack_spec.md) | 부분확인 · 하위 **미확인**: Caves of Qud 의 절차적 **퀘스트** 생성 범위(VER-6) |
| **REF-12** | LLM 기반 콘텐츠 파이프라인 (일반론) | P | 오프라인 배치 생성, 스키마 강제 출력, **다단계 분업**, 결정론적 검증 게이트, 사람 최종 승인, 실패 모드 F1~F6, 생성 출처 기록 | 런타임 LLM, LLM 검수만으로 게이트 통과, 단일 프롬프트 전체 생성, AI 가 파일 직접 쓰기 | [BP-12 §12.13](12_reference_designs.md), [BP-32](32_generation_harness.md), [BP-37](37_prompt_contracts.md), [BP-33](33_validation_and_lint.md) | **미확인 — 검증 필요** (구체 제품 사례 없음, 관찰 패턴의 일반화) |
| **REF-13** | Ultima / Wizardry / 1990년대 국산 RPG 계보 | G | **톤 상한** — 짧은 대사, 푯말을 서사 채널로, 화자 헤더 관습, "이동과 전투가 주역", 선택지 상한 | 현대 구어체·밈·이모지, 장문 독백, 음성 전제 리듬, 퀘스트 마커·미니맵, 키워드 자유 입력 대화 | [BP-12 §12.14](12_reference_designs.md), [BP-43](43_content_style_guide.md), [BP-41](41_journal_ui_spec.md) | 원작 Hadar 부분은 **확인됨**(레포 실측) / Ultima·Wizardry 세부는 부분확인 |
| **REF-14** | 본 레포 `tools/mapEditor` AI API | H | **콘텐츠 서버의 직접 선례** — 배치 편집(ops), `validate`, `preview.png`, 힌트 포함 에러 `{error, hint}`, MCP 래퍼, `GET /api/ai` 자기 문서화 | (없음 — 확장 대상) | [BP-31](31_content_server_api.md), [BP-36](36_map_editor_extension.md), [BP-30](30_toolchain_overview.md) | **확인됨** (GROUND_TRUTH §11 실측) |
| **REF-15** | 본 레포 `packages/cm2_script` (CM2 DSL) | H/L | **반면교사** — 침묵 실패(미등록 함수 → 0 반환), 루프·함수 부재, 맵 전환 시 전역 소실, `run()` 의 `.assign` 재실행 | AI 생성 타깃으로서의 cm2. 단 레거시·특수 연출용으로는 **존치**(D-10 티어 2) | [BP-12 §12.9](12_reference_designs.md), [BP-28](28_migration_and_coexistence.md), [BP-11](11_gap_analysis.md) | **확인됨** (GROUND_TRUTH §9 실측) |
| **REF-16** | 본 레포 `test/application/map_navigation_test.dart` | H | **헤드리스 하네스의 기존 선례** — in-memory `AssetSource` 페이크로 `MapInfos.json` → `MapModel` 전 경로를 파일시스템 없이 구동 | (없음 — 확장 대상) | [BP-34](34_headless_sim_and_solver.md), [BP-20](20_target_architecture.md) | **확인됨** (GROUND_TRUTH §3 실측) |

---

## 92.3 참조원별 상세 카드

> 각 카드는 "어디를 봐야 하는가 · 무엇이 확인됐고 무엇이 아닌가" 만 담는다. 판단은 BP-12 에.

### REF-01 · RPG Maker MV / MZ
- **왜 특별한가**: 다른 참조원은 "배울 것" 이지만 이건 **이미 우리 안에 있다.** `hadar2026_app/assets/maps/*.json` 이 MV 포맷이다.
- **확인됨**: `events[].pages[].conditions` 필드 구성(`switch1Id/switch1Valid/switch2*/variableId/variableValue/selfSwitchCh/actorId/itemId` + 각 `*Valid`), `pages`·`trigger`·`priorityType`·`moveRoute` 의 존재. — 근거: 본 레포 `assets/maps/Map003.json` 실측.
- **확인됨(명령 코드 실체 — 개정에서 정정)**: 레포 전 맵을 훑으면 실존 코드는 **`0`(38회, 리스트 종료) · `101`(25회) · `401`(31회)** 셋뿐이다(GROUND_TRUTH 부록 E).
  - **`401`** = 대사 본문 한 줄. 예: `['저에게 말고 윗분에게 말씀을 걸어 주세요.']`
  - **`101`** = **Show Text 명령의 표시 설정 레코드** = `[faceName, faceIndex, background, positionType]`
    (얼굴 그래픽 파일명 · 얼굴 인덱스 · 창 배경 종류 · 창 위치). **텍스트도 화자명도 담지 않는다.**
    실측값 `['', 0, 0, 2]` — 첫 요소가 빈 faceName 이다.
- **⚠ 초판 오류 정정 (F-01)**: 초판은 이 카드에서 `101`(헤더) 를 **"확인됨"** 목록에 넣고 92.4.2 에서 `Node.header` 에 대응시켰다. **오류였다.**
  - 화자 이름 표시는 MV 101 의 파라미터가 아니라 **MZ 에서 추가된 별개 기능**이다.
  - `Node.header` 는 **MV 계보가 아니라 본 기획서의 독자 개념**이며, 계보는 ① 원작 Hadar 의 푯말 헤더 관습
    (`hadar2026_app/lib/application/tile_event_dispatcher.dart:116-117` 의 `setHeader('@B푯말에 써 있기를:')`, REF-13)
    + ② Yarn Spinner 의 노드 헤더 메타데이터(REF-06) 두 갈래다.
  - **`map_event.dart:79` 가 `code == 401` 만 읽고 `101` 을 통째로 버리는 것은 결함이 아니라 의도적으로 옳은 동작**이다 — 우리에겐 얼굴 그림 시스템이 없다.
- **확인됨(선택 규칙 — VER-2 종결)**: 조건 만족 페이지가 여럿이면 MV 는 **번호가 가장 큰 페이지**를 고른다(뒤에서부터 탐색). 결정론적이다.
  **→ 본서 `Dialogue.entry[]`(위에서부터 첫 true)와 순서가 정반대다.** 92.4.2·92.4.7·92.5.2 VER-2 참조.
- **확인됨(우리 코드)**: `hadar2026_app/lib/domain/map/map_event.dart:75-88` 이 **`pages[0]` 만** 읽고 **`code == 401` 만** 수집한다. `conditions` 는 파싱조차 하지 않는다.
- **확인됨(우리 코드)**: `hadar2026_app/lib/application/tile_event_dispatcher.dart:166-178` 의 `_emitJsonDialog` 가 좌표 일치 **첫 이벤트에서 return** → 좌표당 이벤트 1개만 유효.
- **부분확인**: 명령 코드 `111`(조건 분기) / `121`(스위치 조작) / `122`(변수 조작) / `201`(장소 이동) 의 정확한 의미와 파라미터 배열 형태.
  **다만 이 넷은 우리 데이터에 0건**이므로(부록 E) 이관 대상 자산이 실제로 존재하지 않는다 — 미확인으로 남아도 설계 영향 없음(VER-1).
- **부분확인**: `page.trigger` 의 접촉 계열이 "플레이어 접촉" 과 "이벤트 접촉" 으로 나뉘는지 등 세분. 우리 데이터의 trigger 값은 0·1 뿐이다.
- **주의**: 초판은 페이지 선택 규칙을 **[미확인]** 으로 두고 "우리는 이 **모호함**을 피하려고 첫 true 로 못 박았다" 고 썼다.
  MV 는 모호하지 않았다 — 그 서술은 MV 의 성질이 아니라 **집필 시점의 미확인 상태**였다. 정정한다.
  R-12-1("배열 위에서부터 첫 true")은 유지하되, 그 이점은 "모호함 제거" 가 아니라 **읽는 순서와 평가 순서의 일치**다.

### REF-02 · Bethesda Radiant
- **확인됨(개념·명칭)**: Quest / Quest Stage(번호) / Objective / Alias / Alias Fill Condition / Package 의 존재와 역할.
  **Story Manager** 라는 명칭과 "이벤트 데이터가 조건에 맞는 퀘스트를 깨우고 Alias 를 채운다" 는 동작도 확인됨 → **VER-3 종결**.
- **부분확인**: 각 레코드의 필드 세부와 디스패치 순서.
- **⚠ 구조 방향 정정 (개정)**: 초판은 "Stage 에 Objective 가 붙는다" 고 적었으나 **뒤집힌 서술**이었다.
  Bethesda 에서 **Objective 는 Quest 레벨의 독립 목록**이고 Stage 는 그 표시/완료 상태를 바꾼다.
  반면 **D-06 은 `Stage { objectives: [...] }` 로 Stage 하위에 nest** 한다 — **의도적 이탈**이며,
  그 대가는 **스테이지 간 목표 공유 불가**다. 상세는 [BP-12 §12.3.3.1](12_reference_designs.md), 제약의 소유는 [BP-23](23_quest_model.md).
- **우리 쪽 변환 요점**: Alias Fill 을 **런타임에서 빌드 시점(D-14 4단계 `bind`)으로 이동**. 이유는 D-01.
- **주의**: Alias 조건의 예시("레벨에 맞고 아직 클리어하지 않은 던전 하나")는 **설명용 가상 예시**이며 실제 퀘스트의 조건식이 아니다.

### REF-03 · Fallout: New Vegas
- **부분확인**: 다중 해결 경로, 퀘스트 실패 가능, 진영 평판의 존재, 대화 내 스킬 체크 표기.
- **설계 반영**: D-06 의 `failConditions` / `onFail` / `Stage.next[].when` 이 이미 이 형태를 표현할 수 있음을 **확인**한 것이 이 참조의 실질 기여. 평판은 D-16 에 의해 1차 스코프 밖(단, `var_cmp`/`add_var` 로 나중에 무손실 추가 가능).

### REF-04 · The Witcher 3 (CDPR)
- **부분확인**: 퀘스트가 그래프로 편집되고 노드 상당수가 대화 씬이라는 점, 조건부 씬 라우팅, 서술형 저널.
- **미확인**: 내부 퀘스트 편집 툴의 구체 구조·용어. 공개 자료가 제한적이므로 **개념 수준으로만** 인용.
  (초판 BP-12 §12.5.1 이 노드 타입 명칭을 괄호로 적었으나 확인되지 않아 **삭제**했다.)
- **설계 반영**: "퀘스트와 대화를 따로 만들면 어긋난다" 는 교훈 → 양방향 참조 무결성 Hard gate (R-12-2).

### REF-05 · Ink (inkle)
- **확인됨**: knot / stitch / weave / divert(`->`) / tunnel(`->k->`) / `VAR` / `LIST` / EXTERNAL 의 존재, `*`(한 번만) vs `+`(계속) 선택지 구분, 컴파일 결과가 JSON 이고 런타임 엔진이 그것만 해석한다는 파이프라인 형태.
- **설계 반영**: D-01 3분할의 선례. `Choice.once`(D-07)의 출처.
- **주의**: Ink 의 장점(작가 표현력)이 우리에겐 단점이 되는 구조 — BP-12 §12.6.3 의 대비표 참조.

### REF-06 · Yarn Spinner
- **확인됨**: 이름 붙은 노드 + 헤더 메타데이터 + 본문 구조, 점프·선택지·조건·변수 문법, 호스트로의 command 디스패치, **line ID 부여 및 string table 추출** 워크플로.
- **부분확인**: 컴파일러 정적 검사의 정확한 항목 목록과 버전별 차이(강타입 도입 시점 등).
- **설계 반영**: **BP-12 가 다룬 13개 참조원(§12.2~§12.14) 중** 우리 D-07 대화 모델과 가장 가깝다.
  (이 부록은 본 레포 자체를 포함해 REF-01~REF-16 **16개**를 색인하므로 셈이 다르다.)
  `strings/ko.json`(D-03)과 R-12-3(변수 선언 강제)의 직접 출처.
- **부분확인**: `<<command>>` 의 정적 검사 범위. **커맨드 시그니처를 프로젝트에 선언하면 일부 검사가 가능**하므로,
  "컴파일러가 유효성을 전혀 알 수 없다" 는 초판 서술은 과했다. 정확히는 **런타임 등록에 의존하는 부분이 남는다**.
  그 남는 부분이 우리가 `Effect.do` 를 닫힌 집합으로 못 박는 이유다.

### REF-07 · Twine / Harlowe
- **확인됨**: 패시지를 카드로 놓고 링크로 잇는 시각적 그래프 편집기라는 도구 성격, 링크 문법이 곧 간선.
- **확인됨**: 끊어진 링크의 시각적 표시(화살표 끝의 X). → **VER-4 절반 종결.**
- **미확인 — 검증 필요**: **자동 도달성(고립 노드) 분석이 기본 기능인지.** 우리 설계는 이 기능을 **직접 구현**(D-15 Hard gate)하므로 결론은 영향받지 않는다.

### REF-08 · Papyrus
- **확인됨(일반 성질, Papyrus 에 한정)**: 루프·재귀·함수를 갖는 범용 스크립트 언어에 대해 "이 퀘스트가 완주 가능한가" 를 정적으로 증명할 수 없다는 것.
- **⚠ 이 근거는 cm2(REF-15)에 전이되지 않는다 (부록 E-3, 개정 정정)**: cm2 는 루프도 함수 정의도 없어 **튜링 완전이 아니고**,
  상태 공간도 유한하다(`maxFlags 256`/`maxVariables 256`). 즉 원리적으로는 오히려 검증 가능하다.
  **D-02 는 유지되나 근거가 다르다** — 스키마 강제 출력 불가 · 부분 재생성 단위 부재 · 텍스트/부작용 혼재 · 침묵 실패
  (BP-12 §12.9.3 (a)~(d)). 초판이 "cm2 도 정적 검증 불가" 라고 쓴 것은 오류였다.
- **부분확인**: 스크립트 인스턴스 상태가 세이브에 함께 저장되어 모드 제거 시 죽은 참조가 남는 문제(모딩 커뮤니티에 널리 알려짐).
- **미확인 — 검증 필요**: VM 지연·큐잉으로 인한 타이밍 버그 특성.
- **설계 반영**: D-02 의 핵심 반증 사례. D-08 이 WorldState 에 **선언된 이름 있는 키만** 담는 이유.

### REF-09 · 데이터 드리븐 밸런스 테이블
- **확인됨(원리)**: 수치를 데이터로 분리 / 스키마·참조 무결성 CI 검사 / diff 리뷰 / 상속·오버라이드로 중복 제거.
- **미확인**: 특정 회사(Blizzard·Riot 등)의 **내부 툴 구조·명칭**. BP-12 는 회사명을 근거로 쓰지 않고 관행만 일반화했다.
- **우리 쪽 갭**: `hadar2026_app/lib/domain/battle/enemy_data.dart:33` 의 `enemyTable` 이 Dart 코드에 하드코딩,
  `assets/maps/books.json` 의 무기 데이터는 **아무 코드도 로드하지 않음**(GROUND_TRUTH §10, §6) → R-12-6.
- **수치 정정 (부록 B-1)**: 초판의 "76종" 은 오류. 테이블은 **75엔트리(id 0~74)** 이고,
  `hadar2026_app/lib/application/battle.dart:43-46` 의 `if (enemyTableId <= 0 …) return;` 가드로 **id 0 은 소환 불가**.
  → 콘텐츠가 참조 가능한 적은 **id 1~74, 74종**. `defeat` 목표의 `enemyId` 참조 무결성 검사는 이 범위로 구현할 것.

### REF-10 · 퍼즐 검증 관행
- **확인됨(원리)**: generate→solve→통과분만 채택 루프, 솔버가 난이도 추정치를 부산물로 준다는 점, 최소 재현 시퀀스로 반례를 축약하는 관행.
- **부분확인**: Zachtronics 류의 결정론적 replay 검증.
- **미확인**: Baba Is You 등 개별 게임의 내부 솔버 사용 여부·범위.
- **설계 반영**: **D-13 의 직접 출처.** 그리고 D-01(결정론)이 검증 가능성의 전제임을 밝힌 근거.

### REF-11 · Dwarf Fortress / Caves of Qud
- **부분확인**: DF 의 world gen 이 문명·인물·전쟁·유물의 역사를 시뮬레이션하고 legends 로 열람 가능하다는 점. Caves of Qud 가 손으로 쓴 뼈대와 절차적 세부를 섞는다는 점.
- **미확인 — 검증 필요 (VER-6)**: Caves of Qud 의 절차적 **퀘스트** 생성 범위(어디까지가 절차적이고 어디부터 손인지).
- **설계 반영**: D-03 이 `world/` 를 먼저 두는 이유, D-14 1단계 `context` 의 이유, R-12-7(팩 경계 = 신뢰 경계).

### REF-12 · LLM 콘텐츠 파이프라인 일반론
- **⚠ 전체가 [미확인 — 검증 필요]**: BP-12 §12.13 은 특정 제품·회사를 인용하지 않는다. 공개적으로 반복 관찰되는 패턴을 일반화한 서술이며, **구체 사례 근거가 없다.**
- **그럼에도 설계에 쓰는 이유**: 패턴 P1~P5 와 실패 모드 F1~F6 은 그 자체로 우리 검증 게이트 설계의 **체크리스트**로서 유용하고, 각 항목이 **우리 자체 논리(D-01, D-02)로도 독립 정당화**되기 때문. 즉 이 절이 통째로 틀려도 D-14/D-15 는 무너지지 않는다.
- **후속**: 구체 사례를 붙일지 여부는 **Q-12-6** (BP-12 §12.18).

### REF-13 · Ultima / Wizardry / 90년대 국산 RPG
- **확인됨(원작 Hadar, 레포 실측)**:
  - 푯말 전용 헤더 `'@B푯말에 써 있기를:'` — `hadar2026_app/lib/application/tile_event_dispatcher.dart:116-117`
    → **`Node.header` 의 진짜 계보 절반**(나머지 절반은 REF-06 Yarn 의 노드 헤더). MV 코드 101 이 **아니다**(부록 E-1)
  - 콘솔 13줄/페이지, 진행 스크롤백 200줄 — `HDConfig.maxLinesPerPage` / `maxProgressLines`
  - 인벤토리가 `food` / `gold` 정수 2개뿐, 장비는 정수 ID 1개씩(`"무기$weapon"` 플레이스홀더)
  - 적 **74종** 고정 테이블(테이블 75엔트리 중 id 0 은 소환 불가 — 부록 B-1), 랜덤 인카운터
  - 상호작용 4종 — `HDTileAction` 의 `talk` / `sign` / `event` / `enter`
  - 파티 이름 "슴갈"(에스퍼) / "유리"(초능력자)
- **부분확인**: Ultima 계열의 키워드 대화, Wizardry 계열의 텍스트 절제.
- **의도적으로 다루지 않은 것**: 다른 90년대 국산 RPG 개별 작품의 설계 세부 — 확인되지 않은 사실을 쓰지 않기 위해 **원작 Hadar 의 레포 실측 사실만** 톤 근거로 삼았다.

### REF-14 · 본 레포 mapEditor AI API
- **확인됨(GROUND_TRUTH §11)**: dev 서버 `http://localhost:5310`, `GET /api/ai` 가 가이드 전문 반환, MCP 래퍼 `mcp/server.mjs`, 배치 편집 `POST /api/ai/maps/{file}/edit`(ops: set/rect/fill/setCells/resize/setDisplayName), 이벤트 CRUD, `/validate`, `/passability`, `/preview.png`, `/palette`.
- **설계 반영**: D-12 가 "같은 프로세스·같은 에러 규약(`{error, hint}`)·같은 배치 편집 철학" 을 요구하는 근거. **콘텐츠 서버는 새 발명이 아니라 이 서버의 확장이다.**

### REF-15 · 본 레포 CM2 DSL
- **확인됨(GROUND_TRUTH §9)**: 들여쓰기 블록 + `if/else` + `name.method(args)`. **while/for·함수 정의·사용자 타입·문자열 조작 없음, 산술은 `Add` 만.** 미등록 커맨드 → "Unknown command" 후 스킵. 미등록 함수 → "Unknown function" 후 **0 반환**. `run()` 이 모든 `.assign` 을 매 실행 재실행. 맵 전환 시 `loadScript` 가 엔진 전역 소거.
- **설계 반영**: D-02 의 1차 근거. R-12-5(디버그 빌드에서 예외 승격).
- **⚠ 튜링 완전성으로 D-02 를 방어하지 말 것**(부록 E-3) — REF-08 카드 참조. 논거는 위 실측 4종 + 저작 표면의 부적합성이다.
- **네이티브 스크립트 티어의 실증 실패 (부록 A-3)**: cm2 옆의 또 다른 스크립트 티어인 네이티브 Dart 맵 스크립트는
  `hadar2026_app/lib/application/scripting/map_script.dart:41-48` 에서 `isFlagSet()` 가 `return false;` 만 하는 **미구현 스텁**이고
  `setFlag()` 는 빈 본문이다. `HDNativeScriptRunner` 에 실제 구현이 있으나 맵 스크립트는 자기 스텁을 호출한다.
  → **네이티브 티어의 모든 조건 분기가 항상 `false`. 한 번도 동작한 적이 없고, 아무도 알아채지 못했다.**
  선언적 데이터였다면 빌드 검증(D-15)이 즉시 잡았을 실패다 — **D-02 의 가장 강한 실증 사례.**
  → **R-12-14**: 네이티브 티어를 "특수 연출용" 으로 존속시키려면 A-3 수정이 선행돼야 한다. 인계: [BP-28](28_migration_and_coexistence.md).

### REF-16 · 본 레포 헤드리스 선례
- **확인됨(GROUND_TRUTH §3)**: `hadar2026_app/test/application/map_navigation_test.dart` 가 in-memory `AssetSource` 페이크를 `HDHosts().bind(...)` 로 주입해 `MapInfos.json` → `MapModel` 경로를 파일시스템 없이 구동. `tearDown` 에서 `HDHosts().reset()`.
- **설계 반영**: D-13 헤드리스 하네스가 **신규 발명이 아니라 기존 이음매의 확장**이라는 근거.
- **⚠ 그러나 포트만으로는 부족하다 (부록 B-3·B-4·C-4)**: 타일 상호작용의 트리거가 `application/` 이 아니라
  Bonfire 스프라이트의 `update(dt)` 폴링 안에 있고(`hadar2026_app/lib/presentation/panels/player_sprite.dart:103` 외 3곳에서
  `HDGameMain().checkTileEvent(...)` 직접 호출), `hadar2026_app/lib/application/menu_flows.dart` 는 `dart:io` 의 `exit(0)` 를 부르며,
  전투는 시드 없는 `Random()` 을 14곳에서 쓰고 독 데미지는 벽시계를 읽는다.
  → **"이동·상호작용 루프의 application 추출" 과 "시드 난수 도입" 이 D-13 의 선결 과제**다. 범위 소유는 [BP-34](34_headless_sim_and_solver.md)(D-18).

---

## 92.4 용어 대응표 (타 시스템 ↔ 본 기획서)

> 규칙: 왼쪽은 **남의 용어**, 오른쪽은 **본 기획서 용어**. `코드체` 는 스키마 필드명/식별자다.
> "≈" 는 대응은 되지만 시맨틱이 완전히 같지는 않다는 뜻. "✕" 는 대응물이 없다는 뜻(사유 열 참조).

### 92.4.1 상태 (플래그 · 변수)

| 출처 | 남의 용어 | 본서 용어 | 비고 |
|---|---|---|---|
| REF-01 MV | Switch (번호, 예 `switch1Id: 47`) | `flag.<pack>.<domain>.<name>` | **번호 → 이름.** D-04. 레거시 정수는 `content.lock.json#legacyFlagMap` 로만 연결 |
| REF-01 MV | Variable (번호) | `var.<pack>.<domain>.<name>` | 값은 정수 (D-08) |
| REF-01 MV | Self Switch (A~D, 이벤트 로컬) | ✕ → **Q-12-1** | 관례 `flag.<pack>.anchor.<id>.*` 또는 `Choice.once` / `npc_state` 로 근사 |
| REF-06 Yarn | `<<declare $x = 0>>` | 팩의 **상태 선언 목록** | R-12-3. 미선언 키 사용은 빌드 하드 실패 |
| REF-06 Yarn | `<<set $x to 1>>` | `Effect: {"do":"set_var","id":…,"value":1}` | D-05 |
| REF-05 Ink | `VAR` | `var.*` | ≈ |
| REF-05 Ink | `LIST` (상태 열거) | `npc_state` / `quest_state` | ≈ 부분 대응 |
| REF-08 Papyrus | 스크립트 프로퍼티 (세이브에 저장) | ✕ | **의도적 부재.** WorldState 는 선언된 키만 담는다 (D-08) |
| REF-15 cm2 | `Flag::Set(n)` / `Flag::IsSet(n)` | `set_flag` / `{"op":"flag"}` | 정수 n → 이름 있는 id |
| REF-15 cm2 | `HDGameOption.flags: List<bool>(256)` | `WorldState.flags: Set<String>` | v1→v2 마이그레이션 대상 (D-08) |
| REF-15 cm2 | `HDNativeScriptRunner.flags` (저장 안 됨) | `WorldState.flags` | **3중 분열의 통합** (D-16) |

### 92.4.2 대화

| 출처 | 남의 용어 | 본서 용어 | 비고 |
|---|---|---|---|
| REF-06 Yarn | Node | **`Node`** | 이름까지 동일 (D-07) |
| REF-05 Ink | knot | `Dialogue` 또는 `Node` | 입도에 따라 다름 |
| REF-05 Ink | stitch | `Node` | ≈ |
| REF-07 Twine | Passage | `Node` | ≈ |
| REF-05 Ink | divert `->` | `Node.next` | |
| REF-06 Yarn | `<<jump Node>>` | `Node.next` / `Choice.go` | |
| REF-07 Twine | `[[텍스트->대상]]` | `Choice {text, go}` | |
| REF-05 Ink | `*` (한 번만 쓰이는 선택지) | `Choice.once: true` | **직접 차용** |
| REF-05 Ink | `+` (계속 쓰이는 선택지) | `Choice.once` 생략(기본) | |
| REF-05 Ink | weave (자동 합류) | ✕ | 암묵적 제어 흐름 금지 — `go` 명시 강제 |
| REF-05 Ink | tunnel `->k->` | ✕ → **Q-12-3** | 빌드 시점 **인라인 전개** 권고 |
| REF-06 Yarn | line ID (`#line:xxxx`) | **`stringKey`** | R-12-4. 텍스트는 `strings/ko.json` |
| REF-06 Yarn | string table | `strings/ko.json` | D-03 |
| REF-06 Yarn | `<<command …>>` (호스트 호출) | `Effect` 닫힌 집합 | **열린 집합 → 닫힌 집합으로 축소** (D-05) |
| REF-05 Ink | EXTERNAL 함수 | `Effect` 닫힌 집합 | 동상 |
| REF-01 MV | `event.pages[]` (조건별 변형) | `Dialogue.entry[] {when, go}` | **위에서부터 첫 true** (R-12-1) |
| REF-01 MV | 코드 101 (텍스트 헤더) | `Node.header` | |
| REF-01 MV | 코드 401 (텍스트 한 줄) | `Node.lines[]` 의 한 원소 | 현재 유일하게 파싱되는 코드 |
| REF-04 CDPR | 조건부 씬 라우팅 | `Dialogue.entry[]` | ≈ |
| REF-13 원작 | `@B푯말에 써 있기를:` | `Node.header` 의 stringKey | 마크업 처리는 **Q-12-5** |

### 92.4.3 퀘스트

| 출처 | 남의 용어 | 본서 용어 | 비고 |
|---|---|---|---|
| REF-02 Radiant | Quest | `Quest` (D-06) | |
| REF-02 Radiant | Quest Stage (정수 번호) | `Stage {id, index}` | **id 가 정체성, index 는 정렬용** (D-04) |
| REF-02 Radiant | Objective | `Objective {id, kind, params}` | `optional` / `hidden` 동일 개념 |
| REF-02 Radiant | **Alias** (런타임에 채워지는 슬롯) | **`Objective.params` + `Anchor`** | **채우는 시점이 빌드로 이동** (D-01, D-14 `bind`) |
| REF-02 Radiant | Alias Fill Condition | D-14 4단계 `bind` 규칙 | 런타임 아님 |
| REF-02 Radiant | Package (NPC 행동) | ✕ | 우리 NPC 는 고정 배치 |
| REF-02 Radiant | Story Manager 이벤트 | `world_event_bus.dart` (D-11) | ≈ 개념 차용 |
| REF-02 Radiant | Stage 의 Papyrus fragment | `Stage.onEnter: Effect[]` | **코드 → 선언적 Effect 로 강등** |
| REF-03 FNV | 퀘스트 실패 | `Quest.failConditions` / `onFail` / 상태 `failed` | D-06 |
| REF-03 FNV | 진영 평판 | `var.core.party.reputation_<faction>` | D-16 선택 스코프 |
| REF-04 CDPR | 퀘스트 그래프 노드 = 씬 | `Stage.onEnter: [{do:"play_dialogue"}]` | D-05 |
| REF-04 CDPR | 선택이 퀘스트를 진행 | `Objective.kind: "choose"` | D-06 |
| REF-10 퍼즐 | 해답 존재 증명 | `QuestSolver` 완주 증명 | D-13, D-15 Hard gate |
| REF-10 퍼즐 | 최소 재현 입력 | 실패 시 최소 재현 시퀀스 | D-13 산출물 |

### 92.4.4 조건 · 효과

| 출처 | 남의 용어 | 본서 용어 | 비고 |
|---|---|---|---|
| REF-01 MV | `switch1Valid` + `switch1Id` | `{"op":"flag","id":…}` | |
| REF-01 MV | `variableId` + `variableValue` (이상) | `{"op":"var_cmp","cmp":">=", …}` | MV 는 "이상" 고정, 우리는 6종 비교자 |
| REF-01 MV | `itemValid` + `itemId` | `{"op":"has_item","id":…,"count":…}` | |
| REF-01 MV | `actorValid` + `actorId` | `{"op":"party_has_class"}` ≈ | 우리는 액터가 아니라 클래스 |
| REF-01 MV | 코드 111 (조건 분기) | `Choice.when` / `Stage.next[].when` | |
| REF-01 MV | 코드 201 (장소 이동) | `{"do":"warp","map":…,"x":…,"y":…}` | |
| REF-06 Yarn | `<<if>>` / `<<else>>` | `Condition` 중첩 (`and`/`or`/`not`) | D-05 |
| REF-08 Papyrus | 임의 스크립트 조건식 | ✕ | **금지.** 표현식 문자열도 금지 — 구조화 JSON 객체만 |
| REF-15 cm2 | `Event::Override()` | Content tier 의 `handled=true` | D-10 |
| REF-15 cm2 | `ScriptMode()` (0~4 와이어 값) | `HDTileAction.scriptMode` 유지 | 레거시 티어에서만. 신규는 `Anchor.kind` |

### 92.4.5 맵 · 배치

| 출처 | 남의 용어 | 본서 용어 | 비고 |
|---|---|---|---|
| REF-01 MV | `events[]` (좌표에 붙은 상호작용) | **`Anchor`** (D-09) | 좌표는 앵커가, 의미는 콘텐츠 팩이 |
| REF-01 MV | `event.x` / `event.y` | `Anchor.x` / `Anchor.y` | |
| REF-01 MV | `page.trigger` (확인키/접촉/자동/병렬) | `HDTileAction.isInteractive` vs `isStepOn` + `Anchor.kind` | 자동·병렬은 기각 |
| REF-01 MV | `event.note` | `tags[]` 로 흡수 | |
| REF-02 Radiant | Alias 가 가리키는 실제 대상 | `Anchor.actor` / `Anchor.to` | |
| REF-11 DF | world gen 의 장소 | `world/places.json` 의 `place.*` | 손으로 씀 |
| REF-14 mapEditor | 레이어 `objUpper`(z3, 통행 판정) | 앵커-통행 충돌 검사 입력 (D-09) | 빌드가 검사 |
| REF-14 mapEditor | 레이어 `region`(z5, `ixEvent`) | 타일 액션 판정 입력 | GROUND_TRUTH §11 |

### 92.4.6 파이프라인 · 도구

| 출처 | 남의 용어 | 본서 용어 | 비고 |
|---|---|---|---|
| REF-05 Ink | `.ink` 소스 | `assets/content/**/*.json` (소스) | D-03 |
| REF-05 Ink | inklecate (컴파일러) | `hadar_content build` (D-12) | |
| REF-05 Ink | `story.json` (컴파일 산출물) | `content.bundle.json` (D-03) | |
| REF-05 Ink | ink 런타임 | `ContentRuntime` (D-11) | |
| REF-06 Yarn | 컴파일러 정적 검사 | `hadar_content validate` / `lint` | D-15 |
| REF-07 Twine | 그래프 캔버스 | 콘텐츠 서버의 **읽기 전용** 그래프 뷰 | R-12-9 |
| REF-09 테이블 | 테이블 상속/오버라이드 | **팩 합성** `pack.json#dependsOn` | D-03 |
| REF-09 테이블 | 밸런스 diff 리뷰 | `hadar_content diff` + Git | D-12 |
| REF-10 퍼즐 | generate→solve 루프 | D-14 3~6단계 (`draft`→`sim`) | |
| REF-10 퍼즐 | 시드 퍼징 | `SimDriver` policy `random` | D-13 |
| REF-12 LLM | 스키마 강제 출력 | D-14 2·3단계의 출력 스키마 | BP-37 |
| REF-12 LLM | 생성 출처 기록 | `pack.json#generatedBy` | D-03 |
| REF-14 mapEditor | `GET /api/ai` (자기 문서화) | `GET /api/content/ai` (예정) | BP-31 |
| REF-14 mapEditor | `{error, hint}` 에러 규약 | 동일 규약 유지 | D-12 |
| REF-14 mapEditor | `POST …/edit` 의 `ops` 배치 | 콘텐츠 배치 편집 | D-12 |
| REF-16 하네스 | in-memory `AssetSource` 페이크 | `MemoryAssetSource` (D-13) | |
| REF-16 하네스 | `HDHosts().bind(...)` / `reset()` | 그대로 사용 | GROUND_TRUTH §3 |

### 92.4.7 역방향 조회 — 본서 용어 → 남의 용어

| 본서 용어 | 가장 가까운 외부 용어 | 참조원 |
|---|---|---|
| `Anchor` | MV `event` (좌표부) + Radiant `Alias` (대상부) | REF-01, REF-02 |
| `Node` | Yarn `Node` = Twine `Passage` ≈ Ink `stitch` | REF-06, REF-07, REF-05 |
| `Choice.once` | Ink `*` 선택지 | REF-05 |
| `Dialogue.entry[]` | MV `pages[]` 의 조건 선택 | REF-01 |
| `stringKey` | Yarn `line ID` + string table | REF-06 |
| `Stage` / `Objective` | Radiant `Quest Stage` / `Objective` | REF-02 |
| `Condition` (JSON op) | MV `page.conditions` 를 중첩 가능하게 일반화 | REF-01 |
| `Effect` (JSON do) | Yarn `<<command>>` 를 닫힌 집합으로 축소 | REF-06 |
| `content.bundle.json` | Ink `story.json` | REF-05 |
| `QuestSolver` | 퍼즐 솔버 | REF-10 |
| `SimDriver` | 결정론적 replay 하네스 | REF-10, REF-16 |
| 팩 합성 `dependsOn` | 밸런스 테이블 상속/오버라이드 | REF-09 |
| `world_event_bus` | Radiant Story Manager (개념) | REF-02 |
| Content tier (D-10 티어 0) | MV 이벤트 실행 + 조건 페이지 선택 | REF-01 |

---

## 92.5 신뢰도 요약 · 검증 백로그

### 92.5.1 등급별 집계

| 등급 | 참조원 |
|---|---|
| **확인됨** | REF-01(포맷·우리 코드), REF-05, REF-06(문법·워크플로), REF-09(원리), REF-10(원리), REF-13(원작 Hadar 부분), REF-14, REF-15, REF-16 |
| **부분확인** | REF-02, REF-03, REF-04, REF-06(정적검사 세부), REF-07, REF-08, REF-11, REF-13(Ultima·Wizardry 부분) |
| **미확인 — 검증 필요** | **REF-12 전체**, REF-01(다중 만족 페이지 선택 규칙), REF-07(자동 도달성 분석), REF-08(VM 지연 특성), REF-09(개별 회사 내부 툴), REF-10(개별 게임 내부 솔버), REF-11(Qud 절차적 퀘스트 범위) |

### 92.5.2 검증 백로그

| # | 검증할 것 | 왜 필요한가 | 지금 설계에 미치는 영향 |
|---|---|---|---|
| **VER-1** | MV 명령 코드 111/121/122/201 의 정확한 파라미터 | 레거시 맵 이관 도구를 만들 때 필요 | **낮음** — 우리는 인터프리터를 만들지 않기로 함(BP-12 §12.2.6) |
| **VER-2** | MV 의 다중 만족 페이지 선택 규칙 | 레거시 다중 페이지 맵이 생기면 필요 | **없음** — 현재 데이터에 다중 페이지 이벤트가 없고(모든 `*Valid`가 false), 우리 규칙은 "첫 true"로 별도 확정 |
| **VER-3** | Radiant Story Manager 의 정확한 동작 | `world_event_bus` 설계 참고 | **낮음** — 영감일 뿐, 스펙 근거 아님 |
| **VER-4** | Twine 의 자동 도달성 분석 지원 여부 | BP-12 §12.8 서술 정확도 | **없음** — 우리가 직접 구현(D-15) |
| **VER-5** | Papyrus 세이브 오염 / VM 지연 특성 | D-02·D-08 서술 강도 | **낮음** — D-02 는 우리 cm2 실측만으로도 성립 |
| **VER-6** | Caves of Qud 절차적 퀘스트 범위 | 손/생성 경계 설계 참고 | **낮음** — R-12-7 은 우리 팩 구조로 독립 정당화됨 |
| **VER-7** | **REF-12 전체 — 구체 LLM 파이프라인 사례** | BP-12 §12.13 이 통째로 [미확인] | **중간** — P1~P5·F1~F6 체크리스트가 D-14/D-15 의 구성 근거. 다만 각 항목이 D-01/D-02 로도 독립 정당화되므로 무너지지는 않음. → **Q-12-6** |

> **원칙 재확인**: 위 표의 "지금 설계에 미치는 영향" 이 **낮음/없음** 인 이유는, BP-12 가 [미확인] 항목을 **결론의 유일한 근거로 쓰지 않도록** 작성됐기 때문이다. 미확인 사실은 서술의 색을 입힐 뿐, 결정은 언제나 레포 실측(GROUND_TRUTH) 또는 확정 결정(DECISIONS)에 걸려 있다.

---

## 92.6 관련 문서

| 문서 | 이 부록과의 관계 |
|---|---|
| [BP-12](12_reference_designs.md) | **본체.** 모든 채택/기각 판정과 근거 |
| [BP-02](02_glossary.md) | 본 기획서 **내부** 용어 사전. 이 부록은 **외부→내부** 번역 담당 |
| [BP-11](11_gap_analysis.md) | 갭 목록. REF-01·REF-15 가 갭의 기술적 정체를 설명 |
| [BP-21](21_content_pack_spec.md) | REF-06·REF-09·REF-11 에서 온 팩 구조 |
| [BP-23](23_quest_model.md) | REF-02·REF-03·REF-04 |
| [BP-24](24_dialogue_model.md) | REF-05·REF-06·REF-07 |
| [BP-31](31_content_server_api.md), [BP-36](36_map_editor_extension.md) | REF-14 |
| [BP-33](33_validation_and_lint.md), [BP-34](34_headless_sim_and_solver.md) | REF-10·REF-16 |
| [BP-43](43_content_style_guide.md) | REF-13 |
| `_meta/GROUND_TRUTH.md` | REF-14·REF-15·REF-16 및 REF-01·REF-13 의 레포 실측 근거 |
| `_meta/DECISIONS.md` | D-01~D-17 확정 결정. 이 부록은 이를 바꾸지 않는다 |
