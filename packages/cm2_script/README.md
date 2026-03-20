# cm2_script

Minimal line-based script parser and interpreter for Dart:

- **AST**: `ScriptStatement`, `CommandStatement`, `IfStatement`
- **Parser**: `parseScript(content)`, `parseCommand(line)`
- **Engine**: `ScriptEngine` with `variables`, `run()`, `getVal()`, pluggable `registerCommand` / `registerFunction`
- **Built-ins**: `variable`, `.assign`, `.add`, `include` (via `contentLoader`), `halt`, `Context::SetCurrent`, `Context::Delete`, `Context::Set`, and expression functions `Not`, `Or`, `And`, `Equal`, `Less`, `Add`, `Random`, `ScriptMode`, `JoinString`, `Context::Get`, `Context::GetCurrent`, plus `*.Equal` on variables

Host apps register game-specific commands and functions. See `cm2_script_sample` or host adapters (e.g. `hadar2026_app` `HDScriptEngine`) for examples.

- **언어 매뉴얼**: [docs/cm2_script_manual.md](docs/cm2_script_manual.md) — CM2 스크립트 문법·예약 함수 레퍼런스.

---

## 제작 철학

- **최소 문법 지향**: 문법은 한 줄 명령 `명령(인자...)`, `if (식)` / `else` + 들여쓰기, 주석 `#` 수준만 제공한다.
- **일부 필수 기능은 내장**: 변수 선언/할당/증가, `include`, `halt`, 조건·수치·문자열 조합(JoinString) 등은 엔진이 책임진다.
- **그 외 기능은 모두 사용자 등록**: Talk, Map::*, Select::* 등 도메인별 명령/함수는 `registerCommand` / `registerFunction`으로만 제공한다.
- **기본 제공 기능 이외의 모든 동작 책임은 사용자에게**: 엔진은 내장 세트만 처리하고, 나머지 동작은 등록된 핸들러에 위임한다.

---

## 현재 실수하기 쉬운 부분

- **초기화 단계 vs run() 단계**: `loadFromString()` 시 **초기화 단계**에서만 `variable`, `include`, `이름.assign` 이 실행된다. `run()` 에서는 `variable`과 `include` 는 **건너뛰고**, `.assign` 은 **다시 실행**한다. 따라서 메인 스크립트 최상단에 `score.assign(0)` 을 두면, 초기화 후 퀴즈 등으로 쌓은 `score` 가 run() 루프에서 다시 0으로 덮어쓸 수 있다. “최초 1회만 실행되어야 하는” 할당은 `include()` 된 스크립트 안에 두는 등, run() 에서 다시 실행되지 않도록 배치해야 한다.
- **미등록 명령/함수**: 등록되지 않은 **명령**은 "Unknown command" 만 출력하고 **무시**되고, **함수**는 "Unknown function" 출력 후 **0** 을 반환한다. 스크립트 오타나 이름 잘못 시 의도와 다른 값(0)으로 분기할 수 있어 디버깅이 어렵다.
- **variables 직접 조작**: `engine.variables` 는 public 이므로 호스트가 직접 넣고 뺄 수 있다. 스크립트 변수와 호스트 상태를 구분해 둘지, 호스트가 변수를 주입할지 규칙을 정해 두는 것이 좋다.

---

## 나중에 수정될 부분

- **strict mode**: 미등록 명령/함수 호출 시 예외를 던지거나 명시적 실패로 처리하는 옵션.
- **const 기능**: 스크립트 상수 정의/참조.
- **context 기능**: 구현됨. (Context::SetCurrent, Delete, Set, Get, GetCurrent)

### Context 기능을 내장할 때 API 구성 (설계 초안)

context는 **2개 이상**을 두고, **어떤 context가 현재인지**를 바꾸면서, **현재 context 안에서만** 키–값을 다루는 구조가 의미 있다.

- **Context의 설정 / 전환 / 삭제** — “어떤 context를 쓰는가”
- **현재 context에 대한 key–value** — “그 context 안에서 무엇을 넣고 꺼내는가”

이름은 모두 **`Context::이름(...)`** 형식으로 통일한다.

| 구분 | API | 설명 |
|------|-----|------|
| **설정/전환** | `Context::SetCurrent(name)` | 이름이 `name` 인 context로 전환한다. 없으면 새로 만들고 그걸 현재로 둔다. (명령) |
| **설정/전환** | `Context::Delete(name)` | 이름이 `name` 인 context를 삭제한다. 현재 context를 지우면 “현재”는 비거나 기본값으로 둔다. (명령) |
| **key–value** | `Context::Set(key, value)` | **현재 context**에 `key` → `value` 를 넣는다. (명령) |
| **key–value** | `Context::Get(key)` | **현재 context**에서 `key` 에 대한 값을 반환한다. 없으면 `null` 또는 `0`. (함수) |
| **조회** | `Context::GetCurrent()` | 현재 context 이름을 반환한다. (함수) |

- 엔진 쪽: `Map<String, Map<String, dynamic>>` 로 “context 이름 → (키–값 맵)” 을 들고, “현재 context 이름” 하나를 가리키면 된다.
- 호스트는 `Context::SetCurrent("global")` 같은 식으로 초기 context를 정해 줄 수 있고, 스크립트는 `Context::SetCurrent("map")` 후 `Context::Set("x", 10)` / `Context::Get("x")` 로 쓸 수 있다.
- 키·context 이름의 의미는 호스트와의 약속으로 두고, 엔진은 “이름 붙은 context들의 전환 + 현재 context 안의 key–value”만 제공한다.

---

## Tests

```bash
cd packages/cm2_script
dart pub get
dart test
```

- `test/parser_test.dart`: `parseCommand`, `parseScript` (단일/여러 명령, 주석·빈 줄, if/else 파싱).
- `test/cm2_script_test.dart`: 변수/assign/add, halt, getVal·내장 함수(Not, Equal, Less, Add, And, Or, ScriptMode, JoinString, Random, Context::Get, Context::GetCurrent), Context::SetCurrent/Set/Delete, if/else 실행, 등록 커맨드·함수, include(contentLoader), clearRuntimeState, toBool.
