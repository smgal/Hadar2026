# P2-01 콘텐츠 서버 REST API

> **[보류 — DEFERRED]** 이 이슈는 **무거운 생성 파이프라인 노선**(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스)에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 경량 대체는 [S3-generation/](../S3-generation/) 이다 — 생성 타깃이 선언적 콘텐츠 팩이 아니라 **cm2 + 맵 JSON** 이다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: GATED
- **구간**: P2
- **규모**: L
- **선행**: GATE-01
- **설계 근거**: [BP-31](../../blueprint/31_content_server_api.md) · [GROUND_TRUTH §11 · 부록 H-4](../../blueprint/_meta/GROUND_TRUTH.md) · [D-12 · D-27 · D-28](../../blueprint/_meta/DECISIONS.md)

## 문제

콘텐츠 팩(`assets/content/**`)을 읽고 쓸 프로그램 경로가 없다. 맵은 이미 편집 가능하다 —
`tools/mapEditor/server/ai_api.ts`(828줄)가 `/api/ai/*` 로 배치 편집·이벤트 CRUD·`validate`·`preview.png` 를 제공한다.
그런데 퀘스트·대화·앵커·문자열에는 대응 라우트가 **하나도 없다.**

이것이 없으면:
- **8단계 파이프라인의 4단계(bind)가 성립하지 않는다.** 앵커 배치·참조 해소를 수행할 상대가 없다.
- D-12 원칙 4("AI 는 파일을 직접 쓰지 않는다")를 강제할 수단이 없다. 서버가 유일한 쓰기 경로여야 한다.
- 사람이 대화형으로 콘텐츠를 조회할 창구도 없다(에디터는 지형만 안다).

**계승 대상은 이미 실측되어 있다.**
- 에러 규약: `tools/mapEditor/server/util.ts:10-12` 의 `sendError(res, status, error, hint)` — 주석이
  "AI 가 스스로 복구할 수 있도록 error + hint 를 함께 보낸다" 라고 의도를 못박아 두었다.
- `rev`: `store.ts` 의 mtime 문자열 표현 + 409 응답 형태.
- 서버가 자기 사용법을 반환: `GET /api/ai` → `AI_GUIDE.md` 전문.

## 무엇을 할 것인가

설계 전문은 [BP-31](../../blueprint/31_content_server_api.md) 에 있다(33 라우트 §2.0 · 16종 op §3.2 ·
동시성 §4 · 에러 카탈로그 §5). 여기서는 구현 단위만 적는다.

| # | 파일 / 접합점 | 내용 |
|---|---|---|
| 1 | `tools/mapEditor/server/content_api.ts` (신규) | `handleContentApi(store, req, res, url, CONTENT_GUIDE_PATH)` |
| 2 | `tools/mapEditor/vite.config.ts` | 기존 `handleAiApi(...)` 호출 **직후**에 위 핸들러 삽입. 같은 프로세스·같은 포트(5310) |
| 3 | `server/util.ts` | 손대지 않는다. `sendError` 를 그대로 쓰고 `code`(영문 snake_case)만 상위집합으로 추가 |
| 4 | `server/store.ts` | `revOf` 재사용. `ifRev` 는 **선택 파라미터** — BP-31 §1.1 P6 이 "기존 `/api/ai/*` 쓰기 4곳은 요청의 rev 를 읽지 않는다" 를 실측으로 명시했다. 그 성질을 그대로 물려받되 `ifRev` 를 주면 검사한다 |
| 5 | 맵 파일 쓰기 | **새 직렬화 경로를 만들지 않는다.** 기존 `applyOps`(`ai_api.ts:217`)/`writeMapFile` 을 내부 호출 (BP-31 R-31-0) |
| 6 | 깊은 검증 | 서버는 **형태 검증만**. `validate`/`lint`/`sim`/`build` 는 `hadar_content` CLI subprocess 위임 (BP-31 §1.2 — Condition/Effect 평가기는 Dart 한 벌뿐) |
| 7 | 앵커 라우트 | 맵 데이터를 **바꾸지 않는다**. D-27/D-28 로 region 기반 기능은 전부 폐기 — 앵커는 `anchors/<MAP>.json` 만 건드리고, 타일 편집은 사람이 `autoPlaceTile` 로 명시 요청할 때만 |
| 8 | `tools/mapEditor/CONTENT_AI_GUIDE.md` (신규) | `GET /api/content` 가 `text/markdown` 으로 반환 |

**부록 H-4 반영**: `ai_api.ts:592` 는 `MapInfos.json` 항목을 만들 때 이미 `json: file` 을 넣는다.
따라서 신규 맵 등록 경로는 **이미 올바르다.** 이 이슈가 만들 진단·수리 대상은 **기존 15개 엔트리뿐**이고,
그 엔드포인트는 P2-09(에디터 확장) 소관이다.

## 착수 조건

GATE-1 통과. 선행 이슈는 없지만 실질적으로 P1-01·P1-02·P1-10·P1-12 의 산출물에 의존한다.

**왜 그 전에는 안 되는가**: 이 API 의 표면은 콘텐츠 모델을 그대로 미러링한다 — 컬렉션 7종,
op 16종, 앵커 kind 별 필드가 전부 P1 이 확정하는 스키마에서 나온다. 스키마가 흔들리는 동안 서버를
쓰면 라우트를 두 번 쓰게 된다. 더 결정적인 것은 GATE-1 의 판정 방향이다 — 측정이 "시간의 과반이
기계적 배선" 으로 나오면 처방은 REST 서버가 아니라 **CLI·에디터 개선**이다([MILESTONES §4](../MILESTONES.md)).
같은 배선을 HTTP 로 한 겹 감싸면 배선 비용은 그대로이고 유지 대상만 늘어난다.

## GATE-1 이 보류/취소로 판정되면

- **버려지는 것**: 33 라우트 중 AI 전용 표면 — `GET /api/content/context`, `POST /sim`, `solve`,
  `strings/mint` 대량 발행, `X-Hadar-Actor` 헤더, 팩 단위 트랜잭션(2단계 커밋). MCP 전제 설계 전부.
- **그래도 남는 값**: `validate`/`lint`/`build` 를 CLI 로 위임하는 얇은 라우트는 **사람이 에디터에서
  누르는 버튼**의 백엔드로 그대로 쓸 수 있다. `GET /api/content/anchors/{map}` 진단도 사람용이다.
  취소 시 이 둘만 P2-09 쪽으로 옮겨 살린다.

## 완료 판정 기준

**[잠정 — GATE-1 통과 시 확정]**

- [ ] `pnpm dev` 한 프로세스에서 `/api/ai/*` 와 `/api/content/*` 가 **동시에** 응답한다
- [ ] 모든 4xx 응답이 `{error, hint}` 를 담고, `hint` 가 "다음에 보낼 요청" 을 지시한다
- [ ] 검증 실패한 배치 편집 후 대상 파일들의 `rev` 가 **전부 변하지 않는다**(부분 적용 없음)
- [ ] `ifRev` 불일치 시 409 + `currentRev` 를 반환한다
- [ ] 앵커 생성·이동·삭제 후 해당 맵 파일의 `rev` 가 변하지 않는다 (D-27)
- [ ] `GET /api/content` 가 `CONTENT_AI_GUIDE.md` 전문을 `text/markdown` 으로 반환한다
- [ ] `tools/mapEditor/server/__tests__/content_api.test.ts` — 라우트별 성공/실패 + 롤백을 고정

## 하지 않을 것

- 인증·권한. localhost 전용 dev 도구 전제를 맵 API 와 동일하게 유지한다.
- SSE 실시간 동기화. BP-36 §9.4 가 v1 밖으로 뺐다.
- Condition/Effect 평가기의 TypeScript 재구현. 서버는 형태만 본다.
- region 레이어 기반 편집·검증 기능. D-28 이 최종 기각했다.
- MCP 도구 등록 — P2-02.
