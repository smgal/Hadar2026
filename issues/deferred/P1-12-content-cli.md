# P1-12 `hadar_content` CLI — build · validate · lint (L1~L3)

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-02 대기)
- **구간**: P1
- **규모**: L
- **선행**: P1-02
- **설계 근거**: [BP-33 §2~§7](../../blueprint/33_validation_and_lint.md)(**검증 규칙 카탈로그 소유 장**) · [BP-30 §5.1·§5.2·§6.1](../../blueprint/30_toolchain_overview.md) · [BP-35](../../blueprint/35_ci_and_build.md)(빌드 산출물 스키마) · [D-12 · D-15 · D-26](../../blueprint/_meta/DECISIONS.md)

## 문제

**콘텐츠 데이터에 대한 안전망이 0 이다.** 지금 데이터 오류가 어떻게 드러나는지:

- cm2 — 미등록 커맨드는 "Unknown command" 를 찍고 **스킵**, 미등록 함수는 "Unknown function" 을 찍고
  **0을 반환**해 조건문이 조용히 오분기한다(GROUND_TRUTH §9).
- 정상 심볼의 범위 밖 값 — `hadar2026_app/lib/application/scripting/script_engine_adapter.dart:362-391` 이
  `else` 없이 무시한다. `Flag::Set(300)` 은 로그조차 없다(부록 F-1).
- 맵 이름 — `hadar2026_app/lib/application/map_navigation.dart:43` 이 `Map$idStr.json` 으로 덮어써
  등록된 15개 중 7개가 존재하지 않는 파일로 해석된다(부록 D-1). 그런데
  `:63-68` 은 `cm2Path == null` 일 때만 에러를 반환하므로 **로드 실패가 성공으로 보고**된다(부록 D-2).
- 맵 JSON 이벤트 — 좌표 중복·도달 불가를 검사하는 코드가 없다.

즉 **모든 실패 양식이 침묵**이고, 발견 시점이 플레이 중으로 밀린다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 이것이 P1 에서 GATE-01 판정에 가장 직접적으로 영향을 주는 이슈다 —
MILESTONES §4 의 판정 규칙 중 한 행이 **"플레이에서야 드러난 오류가 검증이 잡은 것보다 많으면 P2 보류"** 다.
검증기가 없으면 그 측정 자체가 성립하지 않는다(분자가 0).

그리고 손 저작의 실제 비용 대부분이 **기계적 배선**(ID 연결, 좌표 찾기, 문자열 키)인데,
그 배선 오류를 잡는 것이 정확히 L1~L3 이다. 도구가 이것을 처리하지 못하면
GATE-01 은 "과반이 기계적 배선" 판정이 나와 P2 가 보류된다 — 즉 이 이슈의 완성도가 게이트 결과를 좌우한다.

## 무엇을 할 것인가

**규칙 카탈로그는 [BP-33 §4](../../blueprint/33_validation_and_lint.md) 소유다. 규칙 목록을 재서술하지 않는다.**

**범위 경계를 먼저 못박는다.**

| 계층 | 내용 | 이 이슈 | 근거 |
|---|---|---|---|
| **L1** | 스키마(구문) — JSON 파싱, 열거값, ID 문법 | **포함** | [BP-33 §4.1](../../blueprint/33_validation_and_lint.md) (30개) |
| **L2** | 참조 무결성 — 모든 ID 가 실재하는가, 팩 가시성 | **포함** | [BP-33 §4.2](../../blueprint/33_validation_and_lint.md) (26개) |
| **L3** | 그래프 구조 — 퀘스트 DAG·대화 도달성·종료 가능성 | **포함** | [BP-33 §4.3](../../blueprint/33_validation_and_lint.md) (20개) |
| L4 | 시맨틱·세계관 — 지식 범위, 보상 밸런스, 문체 | **범위 밖** | 손 저작에는 사람이 그 판단을 직접 한다 |
| **L5** | 시뮬레이션 — 완주 증명, 골든 비교 | **범위 밖 — P2** | [BP-33 §4.7](../../blueprint/33_validation_and_lint.md) · D-26 |

1. **`tools/content_cli/`** 생성 — 트리는 [BP-30 §5.1](../../blueprint/30_toolchain_overview.md).
   - `pubspec.yaml` — `hadar_content` path dep + `args` + `crypto`.
     **`hadar2026_app` 을 의존하지 않는다**(R-30-18). 의존하는 순간 `flutter: sdk` 가 전이로 딸려온다(BP-30 §4.3 실측).
   - `bin/hadar_content.dart` — 서브커맨드 디스패치. 이 이슈는 **`build` · `validate` · `lint`(L1~L3만) · `new`** 4개.
     `sim`/`solve`/`diff`/`stats`/`migrate` 는 스텁으로 두고 "P2" 또는 "미구현" 을 명확히 출력한다.
   - `lib/loader.dart` — 소스 트리 → 메모리 모델. **`dart:io` 는 여기서만 쓴다.**
   - `lib/emitter.dart` — `content.bundle.json` · `content.index.json` · `content.lock.json` 직렬화.
     **결정론**: 같은 소스에서 두 번 빌드하면 바이트 단위로 동일해야 한다(D-15).
   - `lib/validate/schema.dart`(L1) · `link.dart`(L2) · `graph.dart`(L3) — 배치는 [BP-33 §2.3](../../blueprint/33_validation_and_lint.md).
   - `lib/format.dart` — [BP-21 §8](../../blueprint/21_content_pack_spec.md) 정규화(`--check-format`/`--fix-format`).
2. **평가기를 재구현하지 않는다.** L1 의 op/do 검사는 `packages/hadar_content` 의
   `Condition`/`Effect` 파서를 **그대로 호출**한다(D-12 · [BP-33 §9.2](../../blueprint/33_validation_and_lint.md)).
   L3 의 그래프 검사는 P1-08 이 만든 순수 함수(`quest_graph`)와 P1-07 의 `dialogue_graph` 를 재사용한다.
   이것이 "런타임과 검증기의 시맨틱 일치" 를 **구조적으로** 보장하는 유일한 장치다.
3. **`build` 산출물** — 스키마 정본은 [BP-35](../../blueprint/35_ci_and_build.md).
   - `content.index.json#triggers` — 3단 키가 `activation`(`interact`/`step_on`)이다(D-28 · [BP-26 §4.2](../../blueprint/26_entity_registry_and_anchors.md)).
     그 밖의 문자열이 나오면 **빌드 하드 실패**.
   - `content.lock.json#legacyFlagMap` — P1-03 의 다리가 읽는다(D-04).
   - `chanceSeedId` 굽기 — `chanceKey`(`<contextId>#<evalPath>`)를 해시해 정수로 굽는다(D-29a).
     런타임은 정수만 읽는다.
   - **이벤트 → 발행 지점 레지스트리** 생성(D-26). P1 에서는 **생성만** 한다 — 소비(솔버 2축 판정)는 P2 다.
     `item_gained`/`item_lost`/`enter_place` 가 `unpublished` 로 표시되는지 확인하는 용도로 쓴다(P1-09).
4. **맵 이름 검증은 파일 해석까지 확인한다** — [BP-21 §6.3 C14](../../blueprint/21_content_pack_spec.md) R-21-7.
   "이름이 `MapInfos.json` 에 있는가" 만 보면 **정확히 깨진 7개를 유효하다고 통과시킨다**(부록 D-1 의 역설).
   P0-01 이 데이터를 고치므로 검증기는 그 뒤 상태를 기준으로 하되, 검사 자체는 파일 존재까지 확인한다.
5. **출력 포맷 3종** — 사람용(기본) · CI 용 · AI 재시도용([BP-33 §7](../../blueprint/33_validation_and_lint.md)).
   P1 은 **사람용과 CI 용 2종**만 구현한다. AI 재시도용(`--format=ai`)은 P2 에서 쓰이므로 뒤로 미룬다.
   에러에는 `{error, hint}` 형태로 **고치는 방법**을 함께 낸다 — `tools/mapEditor/server/ai_api.ts` 의 기존 규약을 따른다.
6. **CI** — 콘텐츠 변경 시 `hadar_content validate` 를 돌린다.
   `.github/workflows/ci.yml` 에 `content_cli` 잡을 추가(cm2_script 잡 형태 복제).
   `hadar_content sim --all` 은 **P2** 다.

## 완료 판정 기준

- [ ] `cd tools/content_cli && dart pub get` 이 **Flutter 없이** 성공하고 `grep -n "hadar2026_app" pubspec.yaml` 이 빈 결과다
- [ ] `dart run bin/hadar_content.dart build` 를 두 번 돌리면 산출물 3개가 **바이트 단위로 동일**하다 (결정론)
- [ ] `validate` 가 L1~L3 오류를 잡는다 — 각각 최소 1개 실증:
      깨진 열거값(L1) · 없는 아이템 ID 참조(L2) · 스테이지 사이클(L3)
- [ ] `validate` 가 존재하지 않는 맵 파일로 해석되는 `map_is`/`warp` 를 **오류로 보고**한다 (부록 D-1 계열)
- [ ] op/do 검사가 `packages/hadar_content` 의 파서를 호출한다 (CLI 안에 op/do 목록 하드코딩이 **없다**)
- [ ] `content.index.json#triggers` 의 3단 키가 `interact`/`step_on` 뿐이고, 다른 값은 빌드 실패다
- [ ] 발행 지점 레지스트리에 `item_gained`/`item_lost`/`enter_place` 가 `unpublished` 로 나타난다 (P1-05·P1-15 완료 전 상태)
- [ ] `sim`/`solve` 서브커맨드가 "P2 — 미구현" 을 명확히 출력하고 종료 코드가 0 이 아니다 (조용히 성공하지 않는다)
- [ ] **테스트 1**: `tools/content_cli/test/validate_l1_test.dart` — L1 규칙의 대표 케이스(스키마 위반 · ID 문법 위반 · 열거값 위반)
- [ ] **테스트 2**: `tools/content_cli/test/validate_l2_l3_test.dart` —
      참조 무결성(없는 ID·팩 가시성 위반)과 그래프 구조(퀘스트 사이클·대화 도달 불가 노드)
- [ ] **테스트 3**: `tools/content_cli/test/build_determinism_test.dart` —
      같은 소스 2회 빌드의 해시 일치. `chanceSeedId` 가 소스가 안 바뀌면 안 바뀐다는 것도 함께 고정
- [ ] **테스트 4**: `tools/content_cli/test/semantic_parity_test.dart` —
      **D-12 집행** — 같은 Condition JSON 을 CLI 와 `packages/hadar_content` 가 평가해 결과가 같다.
      평가기가 두 벌로 갈라지면 이 테스트가 먼저 깨진다

## 하지 않을 것

- **L4(시맨틱·세계관 38개)** — 지식 범위·보상 밸런스·문체 검사. 손 저작에서는 사람이 판단한다.
- **L5(시뮬레이션) · 솔버 · 퍼저 · 2축 판정** — **전부 P2**(D-26 · [BP-34](../../blueprint/34_headless_sim_and_solver.md)).
- **콘텐츠 서버 `/api/content/*` · MCP 래퍼 · 그래프 PNG** — **P2**([BP-31](../../blueprint/31_content_server_api.md)).
- `--format=ai` 재시도 출력 — P2 에서 쓰인다.
- autofix(`--fix`) — [BP-33 §6](../../blueprint/33_validation_and_lint.md) 은 P1 범위 밖. `--fix-format` 만 한다.
- 증분 검사·병렬화([BP-33 §8](../../blueprint/33_validation_and_lint.md)) — 팩 1~2개 규모에서는 불필요.
