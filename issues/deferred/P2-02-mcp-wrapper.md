# P2-02 MCP 래퍼

> **[보류 — DEFERRED]** 이 이슈는 **무거운 생성 파이프라인 노선**(콘텐츠 서버·MCP·솔버·퍼저·8단계 하네스)에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 경량 대체는 [S3-generation/](../S3-generation/) 이다 — 생성 타깃이 선언적 콘텐츠 팩이 아니라 **cm2 + 맵 JSON** 이다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: GATED
- **구간**: P2
- **규모**: M
- **선행**: P2-01
- **설계 근거**: [BP-31 §6](../../blueprint/31_content_server_api.md) · [BP-30 §3](../../blueprint/30_toolchain_overview.md) · [GROUND_TRUTH §11](../../blueprint/_meta/GROUND_TRUTH.md) · [D-12](../../blueprint/_meta/DECISIONS.md)

## 문제

P2-01 이 만드는 REST 표면을 에이전트가 **도구로** 쓸 수 없다. 맵 쪽에는 이미 래퍼가 있다 —
`tools/mapEditor/mcp/server.mjs`(259줄)가 `McpServer({ name: 'hadar-map-editor' })`(`:44`)에
`tool(name, description, shape, fn)` 헬퍼(`:47-56`)로 도구를 등록한다. 콘텐츠에는 그 대응물이 없다.

래퍼가 없으면 에이전트는 `curl` 상당의 자유 HTTP 호출을 하게 되고, 그것은 D-12 원칙 4 의
실질적 우회다 — 어떤 요청을 보냈는지 계약으로 고정되지 않으므로 서버가 유일한 쓰기 경로라는
보증이 형태만 남는다.

계승할 실측 사실:
- `tool()` 헬퍼는 예외를 `isError: true` 텍스트로 변환한다(`server.mjs:52-54`). `{error, hint}` 본문이
  그대로 에이전트에게 전달되므로 **자기 복구 루프가 이미 성립**한다.
- 첫 도구가 `get_guide` 이고 설명이 "다른 도구를 쓰기 전에 반드시 한 번 읽을 것"(`server.mjs:71-77`)이다.
  이 관례를 콘텐츠 쪽 `content_guide` 로 그대로 옮긴다.

## 무엇을 할 것인가

도구 28종의 REST 대응표는 [BP-31 §6.1](../../blueprint/31_content_server_api.md) 에 있다. 재서술하지 않는다.

| # | 파일 / 접합점 | 내용 |
|---|---|---|
| 1 | `tools/mapEditor/mcp/lib/http.mjs` (신규) | 기존 `server.mjs` 의 `api()`/`apiPng()` 를 **추출**해 두 서버가 공유 (BP-30 §5.1) |
| 2 | `tools/mapEditor/mcp/server.mjs` | 위 추출분을 import 로 대체. 도구 목록·동작은 **변경 없음**(회귀면 0 이 목표) |
| 3 | `tools/mapEditor/mcp/content_server.mjs` (신규) | `McpServer({ name: 'hadar-content' })`. `tool()` 헬퍼 형태를 그대로 복제, 첫 도구는 `content_guide` |
| 4 | 이미지 결과 도구 | `server.registerTool(...)` 직접 호출 방식을 따른다(기존 `preview` `:201-235`, `tile_image` `:237-256` 과 동일) |
| 5 | `tools/mapEditor/README.md` | 두 MCP 서버의 기동법. dev 서버(5310)가 먼저 떠 있어야 한다는 전제 명시 |

**규약 계승 3가지 (변경 금지)**
- 같은 프로세스가 아니라 **같은 dev 서버를 향하는 두 번째 래퍼**다. 서버를 새로 띄우지 않는다.
- 에러는 던져서 `isError` 텍스트로 반환. `{error, hint, code}` 를 가공하지 않고 원문을 넘긴다.
- `rev`/`ifRev` 는 도구 입력 스키마에 **그대로 노출**한다. 래퍼가 rev 를 숨기거나 자동 채우면
  P2-01 이 계승한 동시성 규약이 무의미해진다.

**D-27/D-28 반영**: 앵커 도구(`content_anchor_create` / `_move` / `content_anchors_edit`)는 맵 데이터를
바꾸지 않는다. `autoPlaceTile` 은 **사람이 명시할 때만** 참이 되는 옵션이고, `trigger`·`battle(step_on)`
앵커에는 놓을 타일이 없으므로 서버가 no-op 으로 응답한다(BP-36 R-36-22a). 래퍼는 그 응답을 감추지 않는다.

## 착수 조건

GATE-1 통과 + P2-01 완료.

**왜 그 전에는 안 되는가**: 래퍼는 REST 표면의 **1:1 사영**이다. 라우트가 확정되기 전에 도구를
쓰면 이름·인자·에러 코드를 두 번 정하게 되고, 도구 이름은 에이전트 프롬프트에 박히므로 바꾸는 비용이
라우트를 바꾸는 비용보다 크다. 그리고 래퍼의 유일한 소비자는 생성 파이프라인(P2-07)이다 —
GATE-1 이 P2 를 보류하면 소비자가 없는 도구 28종이 남는다.

## GATE-1 이 보류/취소로 판정되면

- **버려지는 것**: `content_*` 도구 28종 전부. 콘텐츠 쪽 소비자가 사라진다.
- **그래도 남는 값**: 1번 항목(`mcp/lib/http.mjs` 추출)만 남는다 — 기존 `server.mjs` 의 중복 제거이고
  콘텐츠와 무관하다. 취소 시 이 추출만 P2-09 로 이관해 처리한다. 나머지는 잔여 가치가 없으므로
  **파일을 남기지 말고 삭제**한다(쓰이지 않는 MCP 서버가 레포에 남으면 "있는데 왜 안 되나" 를 유발).

## 완료 판정 기준

**[잠정 — GATE-1 통과 시 확정]**

- [ ] `node tools/mapEditor/mcp/content_server.mjs` 가 도구 목록을 반환하고, 첫 도구가 `content_guide` 다
- [ ] 기존 `mcp/server.mjs` 의 도구 목록·응답이 추출 전후로 **동일하다**(스냅샷 비교)
- [ ] 서버가 4xx 를 반환하면 도구가 `isError: true` + `{error, hint}` 원문을 그대로 전달한다
- [ ] dev 서버가 꺼져 있을 때 도구가 "dev 서버를 먼저 띄우라" 는 지시를 담은 에러를 낸다
- [ ] 앵커 생성 도구 호출 후 대상 맵 파일의 `rev` 가 변하지 않는다

## 하지 않을 것

- 도구 안에 검증 로직을 넣는 것. 판정은 전부 서버·CLI 가 한다.
- 여러 REST 호출을 하나의 도구로 묶는 편의 도구. 배치는 `content_edit` 의 op 로 표현한다.
- 자체 dev 서버 기동·프로세스 관리.
- 원격 전송(stdio 외). localhost 전제를 유지한다.
