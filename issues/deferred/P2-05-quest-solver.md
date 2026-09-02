# P2-05 퀘스트 솔버 (2축 판정)

> **[보류 — DEFERRED]** 이 이슈는 **무거운 생성 파이프라인 노선**(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스)에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 경량 대체는 [S3-generation/](../S3-generation/) 이다 — 생성 타깃이 선언적 콘텐츠 팩이 아니라 **cm2 + 맵 JSON** 이다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: GATED
- **구간**: P2
- **규모**: L
- **선행**: P2-04
- **설계 근거**: [BP-34 §5](../../blueprint/34_headless_sim_and_solver.md) · [BP-34 §11](../../blueprint/34_headless_sim_and_solver.md) · [BP-35 §1.5.1](../../blueprint/35_ci_and_build.md) · [D-26](../../blueprint/_meta/DECISIONS.md)

## 문제

"이 퀘스트는 완주 가능한가" 를 기계가 답하지 못한다. 스키마가 유효하고 참조가 다 풀려도
목표에 도달하는 경로가 없을 수 있고, 시뮬레이터로 굴리는 것(P2-04)은 **경로를 찾아 주지 않는다** —
주어진 입력을 재생할 뿐이다.

그리고 **초판 설계가 실제로 틀린 답을 냈다**. BP-91(W-10)이 적발한 사례:
`deliver`/`acquire` 목표는 `item_gained`/`item_lost` 이벤트에 의존하는데 그 두 이벤트는 인벤토리
부재로 **현재 미발행**이다. 그런데 솔버는 그 퀘스트에 `PROVEN` 을 냈다. 정적 증명이 **실행
가능성을 보지 않았기 때문**이다. 이대로면 솔버는 "돌아가지 않는 콘텐츠" 를 통과시킨다.

또 하나의 위험이 반대 방향에 있다. BP-34 A-4 가 지적한 대로 초판의 인벤토리
`max(...)` 클램프는 **소비 누적을 잘라** 실제로는 가능한 전이를 잃는다 → 멀쩡한 콘텐츠에
`REFUTED` 를 낸다. **거짓 `REFUTED` 는 거짓 `PROVEN` 보다 나쁘다** — 거짓 `PROVEN` 은 다음 단계
(시뮬레이터·퍼징·플레이테스트)가 잡지만, 거짓 `REFUTED` 는 제작자에게 **존재하지 않는 결함을
고치라고 시킨다.** 반증에는 재생할 witness 가 없으므로 교차 검증(R-34-7)도 원리적으로 작동하지 않는다.

## 무엇을 할 것인가

형식적 정의·상태 추상화 규칙 A-0~A-10·탐색 알고리즘·최소 반례 산출은
[BP-34 §5](../../blueprint/34_headless_sim_and_solver.md) 에 있다. 여기서는 구현 단위와 판정 규약만 적는다.

**배치**: `tools/content_cli/lib/src/solver/` — `solver.dart` · `state_abstraction.dart` ·
`action_model.dart` · `search.dart` · `witness.dart`. **순수 Dart** 로 돈다(`dart run`, 서브프로세스 없음).
따라서 `packages/hadar_content/` 는 `package:flutter/foundation.dart` 조차 import 하지 않아야 한다
(BP-34 R-34-6 — `ChangeNotifier` 가 필요하면 `application/` 쪽 래퍼가 갖는다).

**판정은 2축이다** (D-26). 하나로 접지 않는다.

| 축 | 값 | 근거 |
|---|---|---|
| 모델 증명 | `PROVEN` / `REFUTED` / `UNKNOWN` | 상태 공간 탐색 |
| 실행 가능 | `SUPPORTED` / `UNSUPPORTED` | **이벤트 → 발행 지점 레지스트리** 대조 |

- 레지스트리(`content.index.json#eventPublishers`)는 **빌드가 생성**한다(BP-35 §1.5.1 소관).
  이 이슈는 그것을 **소비**한다. 이벤트 12종 각각에 현행 빌드의 발행 지점이 있는지 표시되며,
  없으면 `unpublished` 다.
- 솔버는 witness 경로가 소비하는 이벤트를 모아 레지스트리와 대조한다. 하나라도 `unpublished` 면
  `UNSUPPORTED`.
- **`PROVEN + UNSUPPORTED` 는 하드 게이트 통과가 아니다.** 커밋은 가능하되 그 팩은 "미활성" 으로
  표시되고 릴리스 게이트에서 차단된다. 마일스톤 진행 중 콘텐츠를 미리 만들어 두는 것은 허용하되
  배포는 막는 장치다.
- **폐기어를 쓰지 않는다**: `UNREACHABLE`→`REFUTED`, `INCONCLUSIVE`→`UNKNOWN`,
  `PROVEN_BY_WITNESS`→`PROVEN`(사유 `by_witness`).

**거짓 `REFUTED` 를 구조적으로 금지한다** (BP-34 §5.2.1 R-34-21)
- 추상화 축을 **S(안전) / O(과대근사) / U(불명)** 으로 분류하고, `REFUTED` 를 낼 수 있는 축은 **S·O 뿐**이다.
- 인벤토리는 `max(...)` 클램프가 아니라 **충분 상한 `cap(i) = Σ_consume(i) + maxHold(i)` 로 포화**시킨다.
  `cap(i) = ∞` 이고 그 아이템이 목표에 관여하면 `REFUTED` 를 주장하지 않고 **`UNKNOWN` 강등**한다.
- bisimulation 을 증명하지 못하는 축이 목표에 관여하면 그 퀘스트는 `UNKNOWN` 이다. **`UNKNOWN` 은 실패가 아니다.**
- `PROVEN` 은 **반드시 `SimDriver`(P2-04)로 witness 를 재생**해 확인한다(R-34-7). 재생 실패는
  콘텐츠 결함이 아니라 **솔버의 버그**로 취급한다.
- 오탐 처리 5단계(재생 → 최소화 → 분류 → 억제 → 기록)와 `suppressions.json` 을 함께 만든다.
  **만료 없는 억제는 금지**이며, 만료된 억제는 경고가 아니라 **실패**다(R-34-18).

`chance` 분기는 양방향으로 탐색한다 — `chanceSeedId` 가 분기 지점을 식별하고, 유도식은
`mix([seed, step, chanceSeedId])` 로 **`step` 을 포함**한다(D-30). 즉 같은 위치라도 스텝이 다르면
결과가 다르므로 솔버는 "이 분기는 언젠가 반대로 나온다" 를 낙관 방향으로 쓸 수 있다.

## 착수 조건

GATE-1 통과 + P2-04 완료 + `content.index.json#eventPublishers` 생성(P2-09 / BP-35 소관).

**왜 그 전에는 안 되는가**: `PROVEN` 판정은 witness 재생으로만 신뢰할 수 있고, 재생 상대가
`SimDriver` 다 — P2-04 없이는 솔버가 낸 답을 검증할 수단이 없고, 검증되지 않은 솔버는 있는 것이
없는 것보다 나쁘다(거짓 판정이 사람의 시간을 쓰게 만든다). 레지스트리가 없으면 축 2 를 계산할 수
없으므로 D-26 이 금지한 "하나로 접은 판정" 으로 되돌아간다. 그리고 솔버의 가치는 **콘텐츠 개수에
비례**한다 — 퀘스트 5개면 사람이 직접 플레이하는 것이 더 빠르고 정확하다.

## GATE-1 이 보류/취소로 판정되면

- **버려지는 것**: 상태 공간 탐색·최소 반례 산출·낙관/비관 양방향 탐색·`suppressions.json` 운용·
  `--knowledge-gated` 실험 모드. 전부 "대량 콘텐츠를 사람이 다 못 본다" 를 전제한다.
- **그래도 남는 값**:
  - **`eventPublishers` 레지스트리 대조**(축 2)는 솔버 없이도 값이 있다. "이 퀘스트가 쓰는
    이벤트에 발행 지점이 있는가" 는 `validate` 수준의 정적 검사이고, 손 저작 퀘스트에도
    같은 사고가 난다(D-26 을 낳은 W-10 은 손으로 만든 예제에서 나왔다). 취소 시 이 검사만
    P1-12 의 CLI `validate` 로 이관한다.
  - `cap(i)` 포화 정리와 "거짓 `REFUTED` 금지" 규율은 **문서상의 값**으로 남는다 — 나중에 누가
    비슷한 도구를 만들 때 같은 함정을 피한다.

## 완료 판정 기준

**[잠정 — GATE-1 통과 시 확정]**

- [ ] 판정 결과가 **2축**으로 출력된다. `PROVEN + UNSUPPORTED` 가 하드 게이트를 통과하지 않는다
- [ ] 발행 지점 없는 이벤트를 쓰는 퀘스트가 `UNSUPPORTED` 로 표시된다 — D-26 을 낳은 W-10 사례를
      회귀 픽스처로 고정
- [ ] `PROVEN` 인 퀘스트의 witness 를 `SimDriver` 로 재생하면 실제로 완주된다(R-34-7)
- [ ] **거짓 `REFUTED` 회귀 테스트**: 아이템을 여러 번 소비하는 퀘스트(총 소비량 > 1회 소지 상한)가
      `REFUTED` 가 **아니라** `PROVEN` 또는 `UNKNOWN` 으로 나온다
- [ ] `cap(i) = ∞` 인 아이템이 목표에 관여하면 판정이 `UNKNOWN` 으로 강등된다
- [ ] 예산 초과가 `UNKNOWN`(종료 코드 2)이고 머지를 막지 않는다
- [ ] 만료 없는 suppression 이 스키마 검사에서 거부되고, 만료된 suppression 이 실패로 보고된다
- [ ] `tools/content_cli/test/solver/` — 위 명제들을 픽스처로 고정

## 하지 않을 것

- 전투 난이도·서사 품질·문체 판정. 솔버는 "승리 가정" 으로 추상화한다(BP-34 L-2·L-3).
- 플레이어가 목표를 **찾아낼 수 있는가**(전지성 편향 L-1). `--knowledge-gated` 는 v1 에서 지표만.
- `eventPublishers` 레지스트리 **생성** — BP-35 / P2-09.
- 시뮬레이터·퍼저 구현 — P2-04 / P2-06.
- 소프트 축(문체·밸런스) 판정. 기계가 판정하지 않는다(P2-08 의 경계).
