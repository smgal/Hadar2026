# CM2 Script — VS Code 확장

`assets/*.cm2` 를 쓸 때 편집기가 같이 봐 준다. 두 층이다.

| 층 | 무엇 | 어디 |
|---|---|---|
| 문법 | 색 구분 · 탭 들여쓰기 강제 · 접기 · 스니펫 | `syntaxes/` · `language-configuration.json` · `snippets/` |
| 언어 서버 | 빨간 줄(진단) · 자동 완성 · 마우스 도움말 · 정의로 이동 · 개요 | `server/` (순수 Dart) |

언어 서버는 게임이 쓰는 **같은 파서**(`packages/cm2_script`)로 읽고, 동사 표는
`server/lib/data/cm2_symbols.json` 한 곳이다. 앱의 시험
`hadar2026_app/test/application/scripting/cm2_symbols_snapshot_test.dart` 가
그 표가 실제 등록과 같은지 확인하므로, 편집기의 빨간 줄과 CI 의 감사는 같은 말을 한다.

## 설치 (개발용 — 이 레포를 그대로 연결)

```bash
cd tools/vscode-cm2
pnpm install                      # Node 의존성 (pnpm 11)
pnpm run build                    # dist/extension.js
pnpm run server:get               # server/ 의 dart pub get

# 에디터 확장 폴더에 링크 연결 (스크립트 1회 실행 권장)
pnpm run link                     # VS Code 및 Antigravity IDE 양쪽에 자동 연결
# 또는 개별 연결:
# pnpm run link:vscode            # VS Code 에만 연결
# pnpm run link:antigravity       # Antigravity IDE 에만 연결

# --- 수동 연결 시 (참고) ---
# macOS / Linux
# VS Code:          ln -s "$PWD" ~/.vscode/extensions/hadar2026.cm2-script-0.1.0
# Antigravity IDE:  ln -s "$PWD" ~/.antigravity-ide/extensions/hadar2026.cm2-script-0.1.0

# Windows PowerShell (관리자 권한 불필요한 Junction 권장)
# VS Code:
New-Item -ItemType Junction -Path "$HOME\.vscode\extensions\hadar2026.cm2-script-0.1.0" -Target "$PWD"
# Antigravity IDE:
New-Item -ItemType Junction -Path "$HOME\.antigravity-ide\extensions\hadar2026.cm2-script-0.1.0" -Target "$PWD"

# Windows CMD (관리자 권한 불필요한 Junction 권장)
# VS Code:          mklink /J "%USERPROFILE%\.vscode\extensions\hadar2026.cm2-script-0.1.0" "%CD%"
# Antigravity IDE:  mklink /J "%USERPROFILE%\.antigravity-ide\extensions\hadar2026.cm2-script-0.1.0" "%CD%"
```

> **Antigravity IDE 사용자 참고**: Antigravity IDE는 VS Code 기반이지만 전용 프로필 디렉터리(`~/.antigravity-ide/extensions`)를 사용합니다. 일반 `.vscode`에만 링크하면 Antigravity IDE에서 확장이 로드되지 않으므로, `pnpm run link` 또는 `.antigravity-ide` 경로로 연결해야 합니다.
>
> **Windows 주의**: `SymbolicLink`(`mklink /D`)는 관리자 권한이 필요하므로 일반 터미널에서는 권한 오류가 납니다. 위와 같이 관리자 권한이 필요 없는 **`Junction`(`mklink /J` 또는 `pnpm run link`)**을 사용하는 것이 좋습니다. 만약 이미 잘못 연결된 링크가 있다면 `Remove-Item "$HOME\.vscode\extensions\hadar2026.cm2-script-0.1.0"` (CMD는 `rmdir`)으로 먼저 지우고 다시 연결하세요.

에디터(VS Code 또는 Antigravity IDE)를 다시 시작하거나 **`Ctrl + Shift + P` -> `Developer: Reload Window`**를 실행하고 `.cm2` 파일을 열면 된다. 처음 열 때 서버가
`dart run bin/cm2_lsp.dart` 로 뜨느라 몇 초 걸린다. 빠르게 뜨게 하려면:

```bash
pnpm run server:build             # server/build/cm2_lsp (네이티브 실행 파일)
```

이 파일이 있으면 확장이 `dart run` 대신 그것을 쓴다. 서버 코드를 고치면 다시 만든다.

### 개발하면서 바로 보기

이 폴더를 VS Code 로 열고 F5 — 확장 개발 호스트가 `hadar2026_app/assets` 를 열어 준다.
`pnpm run watch` 를 켜 두면 클라이언트 쪽 수정이 바로 반영된다.
서버 쪽을 고쳤으면 명령 팔레트에서 **CM2: 언어 서버 다시 시작**.

## 설치 (배포용 — .vsix)

```bash
pnpm run package                  # build + server:build + vsce package
code --install-extension cm2-script-0.1.0.vsix
```

.vsix 에는 컴파일된 서버가 들어가므로 **만든 것과 같은 OS·CPU** 에서는 Dart SDK 없이 돈다.
다른 기계에서는 서버가 뜨지 않는다 — `dart run` 으로 넘어갈 수 없다. 서버의 pubspec 이
`../../../packages/*` 를 가리켜 설치 폴더에서는 풀리지 않기 때문이다. 그런 기계에서는
그 기계에서 `pnpm run server:build` 를 한 뒤 설정 `cm2.server.executable` 에 그 파일을 지정한다.
확장은 이 경우를 알아보고 그렇게 안내한다.

## 설정

| 설정 | 기본 | 뜻 |
|---|---|---|
| `cm2.server.dartPath` | `dart` | `dart run` 으로 띄울 때 쓸 dart |
| `cm2.server.executable` | (비움) | 컴파일된 서버 경로. 비우면 `server/build/cm2_lsp` → `dart run` 순 |
| `cm2.assetsDir` | (비움) | `include("...")` 를 찾을 폴더. 비우면 문서 폴더 → 작업 영역의 `hadar2026_app/assets` |
| `cm2.diagnostics.eventOverrideHint` | `true` | `On(x,y)` 블록에 `Event::Override()` 가 없으면 흐린 표시 |

## 진단 목록

| 코드 | 등급 | 잡는 것 |
|---|---|---|
| `unknown-command` · `unknown-function` | 오류 | 등록되지 않은 이름. 실행 중에는 건너뛰거나 0 을 돌려줘 조용히 어긋난다 |
| `undeclared-name` | 오류 / 경고 | `variable()` 로 선언하지 않은 이름을 값으로 씀. 같은 파일에 `.assign` 이 있으면 경고로 낮춤 (엔진이 그때 변수를 만들어 주므로) |
| `missing-parentheses` | 오류 | `if (Flag::IsSet)` 처럼 함수를 괄호 없이 씀. 이름 글자가 문자열로 넘어간다 |
| `malformed-argument` | 오류 | 쉼표 빠짐 · 밑줄 대신 하이픈 · 안 닫힌 괄호. 엔진은 그 글자를 문자열로 넘긴다 |
| `unclosed-condition` | 오류 | `if (On(1` — 조건이 닫히지 않음. 엔진은 거짓으로 본다 |
| `else-not-recognized` | 오류 | 위 if 와 들여쓰기가 다른 `else`. 아래 블록이 조건 없이 항상 실행된다 |
| `nested-variable` | 경고 | 블록 안의 `variable()`. 그 갈래가 돌 때마다 0 으로 되돌아간다 |
| `parse-error` / `analyzer-error` | 오류 | 파서나 검사기가 이 파일에서 멈춤. 이전 진단이 조용히 남는 대신 이것 하나가 뜬다 |
| `too-few-arguments` / `too-many-arguments` | 오류 / 경고 | 인자 수 |
| `unassigned-variable` + `assign-undeclared` | 경고 | `variable(X)` 와 `X.assign` 의 이름이 다름 (원작 `flag4ep1.cm2:42` 의 사고) |
| `unused-variable` | 흐림 | 선언만 있고 그 파일에서 읽지도 쓰지도 않음 |
| `top-level-assign-resets` | 경고 | 최상위 `.assign` 이 블록 안에서도 바뀌는 이름을 매번 되돌림 |
| `unknown-attribute` / `retired-attribute` | 오류 / 경고 | `Player::(Get\|Change)Attribute` 의 속성 이름 (`hd_world_legacy` 가 정본) |
| `flag-number-collision` / `flag-number-unnamed` / `flag-out-of-range` | 경고 / 안내 / 오류 | 생 숫자 플래그. 이름 있는 칸과 겹침 · 이름 없음 · 0~255 밖 |
| `flag-duplicate-number` | 경고 | `flag*.cm2` 안에서 같은 번호를 두 이름이 씀 (파일이 달라도 본다) |
| `battle-result-unread` | 경고 | `Battle::Start` 뒤에 `Battle::Result()` 를 읽지 않음 |
| `missing-event-override` | 흐림 | `On(x,y)` 블록에 `Event::Override()` 없음 |
| `include-not-found` | 오류 | include 파일을 못 찾음 |

블록 안의 `include("quest1.cm2")` 가 정의한 상수는 **파일 전체에서 보이는 것으로 친다**. 실행 중에는 그
갈래가 한 번 돌기 전까지 없는 이름이지만, 부록 L 의 「퀘스트마다 include 파일 하나」 패턴이 바로 그
형태라 경고를 달지 않기로 정했다 (2026-09-20). `analyzer_test.dart` 의 「정해 둔 기본값」 시험이 이 결정을 지킨다.
| `mixed-indent` / `indent-style-inconsistent` | 경고 / 흐림 | 탭·공백 혼용 (파서는 탭을 8칸으로 센다) |

## 명령줄 검사기

같은 진단을 편집기 없이 돌린다. AI 가 만든 스크립트를 실행 전에 훑거나 CI 에 넣을 때.

```bash
cd tools/vscode-cm2/server
dart run bin/cm2_lsp.dart --check --assets ../../../hadar2026_app/assets ../../../hadar2026_app/assets/*.cm2
# 오류가 하나라도 있으면 종료 코드 1
```

## 동사를 추가하거나 지웠을 때

1. 앱의 `script_engine_adapter.dart` 에 등록한다 (지금처럼).
2. `server/lib/data/cm2_symbols.json` 에 같은 이름을 넣는다 — `kind` · `params` · `doc`.
3. `cd hadar2026_app && flutter test test/application/scripting/cm2_symbols_snapshot_test.dart`
   가 두 목록이 같은지 본다. 어느 쪽이 빠졌는지 이름으로 말해 준다.

## 시험

```bash
cd tools/vscode-cm2/server
dart test          # 진단 하나하나(28) + stdio 로 실제 서버를 띄워 LSP 왕복(7)
```

파서 자체도 손봤다 (`packages/cm2_script`). 줄 끝 `# 주석` 을 문자열 밖에서 걷어내고,
닫히지 않은 `if (` 에서 예외를 내지 않는다. 출하 cm2 18개의 파싱 결과는 고치기 전과 같다
(파싱 트리를 통째로 비교했다). `Flag::Set(10) # 문(door)` 처럼 주석에 괄호가 있어도
이제 인자가 망가지지 않는다 — 이것은 편집기가 아니라 게임 실행에 영향을 주는 수정이다.
