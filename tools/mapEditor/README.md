# Hadar 맵 에디터

`hadar2026_app/assets/maps/*.json` (RPG Maker MV 포맷)을 브라우저와 API로 읽고·수정하고·저장하는 웹 에디터. RPG Maker MV를 대체하는 게 아니라, 이 프로젝트가 실제로 쓰는 부분(레이어 타일·빛/그림자·지역·이벤트)만 사람과 AI 양쪽이 빠르게 편집하도록 만든 도구다.

## 문서

| 문서 | 대상 | 내용 |
|---|---|---|
| **이 파일** | 처음 보는 사람 | 실행 방법, 전체 그림 |
| [USER_MANUAL.md](USER_MANUAL.md) | 브라우저 UI로 직접 편집하는 사람 | 화면 구성, 도구·단축키, 문제 해결 |
| [API_MANUAL.md](API_MANUAL.md) + [openapi.yaml](openapi.yaml) | API/MCP로 제어하는 AI·스크립트 | OpenAPI 3.0.3 표준 스펙, 보는/검증하는 법 |
| [AI_GUIDE.md](AI_GUIDE.md) | 위와 동일 (AI 전용) | `GET /api/ai`가 그대로 반환하는 도메인 지식(레이어 의미·타일 규칙·빛 공식) — 스펙만으론 알 수 없는 "의미" 부분 |
| [DEVLOG.md](DEVLOG.md) | 이 도구를 다시 손볼 사람 | 요구사항 배경, 설계 이유, 알려진 문제, 개선 아이디어 |

## 실행

```bash
cd tools/mapEditor
pnpm install
pnpm dev        # http://localhost:5310
```

- 기본 대상은 `../../hadar2026_app/assets`. 다른 위치를 편집하려면 `HADAR_ASSETS=/path/to/assets pnpm dev`
- URL 파라미터로 초기 상태 지정 가능: `?map=TOWN1.json&night=1&light=1`

## 한눈에 보는 구조

이 서버는 같은 맵 파일에 대해 **세 가지 인터페이스**를 동시에 제공한다 — 사람이 브라우저로 그림을 그리는 동안 AI가 API로 다른 부분을 편집해도 두 쪽 다 실시간으로 반영된다(단, 동시에 같은 칸을 건드리면 충돌 — [DEVLOG.md](DEVLOG.md) "알려진 문제" 참고).

```
브라우저 UI ──PUT /api/map──┐
                            ├──▶ hadar2026_app/assets/maps/*.json (RPG Maker MV 원본 포맷)
AI / MCP ──POST /api/ai/*──┘
```

- **브라우저 UI**: 레이어별 팔레트, 붓/사각형/채우기/스포이드/지우개, 주간·야간 미리보기, 이벤트 편집기 — 사용법은 [USER_MANUAL.md](USER_MANUAL.md)
- **AI API** (`/api/ai/*`): 레이어 이름·타일 인덱스 단위의 시맨틱 편집, PNG 미리보기, 통행/무결성 검사 — 스펙은 [openapi.yaml](openapi.yaml), 도메인 지식은 [AI_GUIDE.md](AI_GUIDE.md)
- **MCP 서버** ([mcp/server.mjs](mcp/server.mjs)): 위 API를 감싼 도구 15종. dev 서버가 먼저 떠 있어야 함(`HADAR_EDITOR_URL`로 대상 지정)

Claude Code 등록 예 (`.mcp.json`):

```json
{
  "mcpServers": {
    "hadar-map-editor": {
      "command": "node",
      "args": ["tools/mapEditor/mcp/server.mjs"],
      "env": { "HADAR_EDITOR_URL": "http://localhost:5310" }
    }
  }
}
```

## RPG Maker MV 호환 보장

- **필드를 하나도 버리지 않는다.** 파싱한 JSON 객체를 그대로 유지하고 `data`/`events`/`width`/`height`/`displayName`만 제자리에서 수정한다.
- **MV가 저장하는 것과 동일한 줄 구조로 재직렬화**한다. 변경 없이 저장하면 원본과 바이트 단위로 동일 — 저장소의 맵 전부 라운드트립 검증 완료.
- 예외 하나: 이벤트 대사를 수정하면 첫 페이지의 커맨드 목록이 표준형으로 재구성된다. 자세한 내용은 [DEVLOG.md](DEVLOG.md#42-대사-편집이-이벤트-페이지의-list를-통째로-재구성) 참고.

## 주의

- 저장은 원본 파일을 바로 덮어쓴다. 저장소가 git 관리이므로 되돌리기는 git으로.
- API에 인증이 없다 — localhost 전용 로컬 개발 도구라는 전제. 자세한 한계는 [DEVLOG.md](DEVLOG.md#4-알려진-문제한계) 참고.
