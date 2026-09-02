# S2-03 cm2 린터 — 침묵 실패를 빌드 시 잡는다

- **상태**: BLOCKED (S1-99 대기)
- **구간**: S2
- **규모**: M
- **선행**: [S1-99](../S1-sample-quest/S1-99-friction-log.md)
- **설계 근거**: [MILESTONES §3](../MILESTONES.md) · [`GROUND_TRUTH` §9 침묵 실패 · 부록 B-1 · F-0 · F-1](../../blueprint/_meta/GROUND_TRUTH.md) · [P0-14](../P0-foundation/P0-14-silent-out-of-range.md)

## 착수 조건

[S1-99 마찰 기록](../S1-sample-quest/S1-99-friction-log.md) 이 이 문제를 **실제로 겪었다고 확인**해야 한다.
겪지 않았으면 이 이슈는 `DROPPED` 다.

다음 중 하나가 기록되어 있어야 한다.
- cm2 를 썼는데 아무 일도 일어나지 않아 원인을 찾는 데 시간을 썼다
- 커맨드/함수 이름을 **기억이나 추측으로** 쓴 뒤 실행해 보고 고쳤다
- `On(x,y)` 좌표를 맵에서 눈으로 찾아 옮겨 적었고, 한 번 이상 틀렸다

## S1 이 겪지 않았다면

**사람은 `Map002.cm2` 를 옆에 열어 두고 베껴 쓴다.** 정답지가 있으면 미등록 심볼 오타는 거의 나지 않고,
나더라도 콘솔의 `Unknown command:` 출력을 즉시 본다(개발 중 터미널이 붙어 있으므로).
즉 **사람 저작에서는 이 문제가 작다.**

버려도 되는 근거는 없다 — 그러나 **근거의 출처가 S1 이 아니다.**
이 이슈의 근거는 S1 의 마찰이 아니라 **레포에 이미 박혀 있는 미등록 심볼 6종·9곳**(아래 §문제)이고,
그것을 만든 것은 AI 가 아니라 사람이다. 따라서 S1 에서 걸리지 않았어도
**AI 생성이 착수되는 순간([S3-04](../S3-generation/S3-04-minimal-validation.md))에는 필요**하다.
버리려면 S3 자체를 버려야 한다. `DROPPED` 대신 `BLOCKED (S3-01 대기)` 로 옮기는 것이 옳은 처리다.

## 문제

`packages/cm2_script/lib/src/cm2_script.dart` 의 두 기본 실패 양식:

```dart
print("Unknown command: $cmd");                      // :204  스킵
...
print("ScriptEngine: Unknown function $cmd");
return 0;                                            // :335-336  0 반환 → 조건문 오분기
```

**커맨드는 안 하고 끝나지만, 함수는 `0` 을 반환해 `if` 를 반대로 태운다.**
등록 심볼은 커맨드 **40종** / 함수 **12종**이다(`script_engine_adapter.dart:183~482` 와 `:503~574`, 부록 F-0 재확인).

### 40줄짜리 프로토타입 스캐너로 이미 6종·9곳이 잡힌다 (본인 실행)

| 종류 | 심볼 | 위치 | 실제 영향 |
|---|---|---|---|
| 함수 | **`Party::CheckIf`** | `L1_ep1d2.cm2:200` · `L1_ep1d4.cm2:45` · `:51` | **미등록 → 0 반환.** `:200` 의 `Not(Party::CheckIf(CHECKIF_LEVITATION))` 은 **항상 참** → 부양 마법을 켜도 절벽에서 떨어진다. `:45` 는 항상 거짓, `:51` 은 항상 참 |
| 커맨드 | `Map::SetLightArea` | `L1_ep1d1.cm2:331` · `L1_ep1d4.cm2:480` | 조용히 스킵 — 광원 연출 소실 |
| 커맨드 | `Map::ResetLightArea` | `L1_ep1d4.cm2:73` | 같음 |
| 커맨드 | `Player::ApplyAttribute` | `L1_ep1d0.cm2:580` | 스킵. 바로 위 `:577-579` 의 `Player::ChangeAttribute` 3줄이 **반영되지 않을 가능성** |
| 커맨드 | `Player::ReviseAttribute` | `menace.cm2:54` | 스킵 |
| 커맨드 | `GameOver` | `L1_ep1d0.cm2:441` | 스킵 — 강제 종료가 안 됨(바로 다음 `halt()` 만 듣는다) |

`Party::CheckIf` 는 특히 나쁘다 — `assets/const.cm2:36-46` 이 `CHECKIF_MAGICTORCH` ~ `CHECKIF_MINDCONTROL`
**상수 5개를 정의해 두었는데 함수가 없다.** 콘텐츠는 있다고 믿고 쓰고 있고, 게임은 조용히 반대로 분기한다.

### 이름을 붙인 플래그도 안전하지 않다

`assets/flag4ep1.cm2:42-43` 의 대입 이름 오타 1건([S2-01](S2-01-flag-registry.md) §문제 참조) —
등록된 이름이라 `cm2_script.dart:140` 의 경고조차 나오지 않는다.

## 왜 지금 고쳐야 하는가

- [S3-04](../S3-generation/S3-04-minimal-validation.md) 는 **이 린터를 재사용**한다. 없으면 S3-04 의 실체가 없다.
- [S3-02](../S3-generation/S3-02-generation-prompt.md) 의 자기수정 루프는 **린터 출력을 그대로 프롬프트에 되먹인다.**
  따라서 출력 형식(`파일:줄: 규칙ID: 메시지`)이 프롬프트 계약의 일부다.
- 사람이 쓴 콘텐츠에서 이미 9곳이 나왔다. AI 는 사람보다 **더 그럴듯한 이름을 만든다**(`Map::SetLight`, `Flag::Toggle` 등).

## 검사 항목

| # | 규칙 | 무엇과 대조 | 심각도 |
|---|---|---|---|
| L1 | 미등록 커맨드 | `script_engine_adapter.dart` 의 `registerCommand` 40종 + 엔진 내장 7종(`variable`/`include`/`halt`/`Event::Override`/`Context::*`) | error |
| L2 | 미등록 함수 | `registerFunction` 12종 + 내장 11종(`Not`/`Or`/`And`/`Equal`/`Less`/`Add`/`Random`/`ScriptMode`/`JoinString`/`Context::Get`/`Context::GetCurrent`) | **error** (0 반환이 더 위험) |
| L3 | 정의 안 된 `variable` 사용 | 해당 파일 + `include` 로 도달하는 파일의 `variable(...)` 선언 집합 | error |
| L4 | 대입 대상 이름 ↔ 선언 이름 불일치 | 직전 `variable(X)` 와 `Y.assign(...)` 의 X≠Y (flag4ep1 오타 유형) | warn |
| L5 | 범위 밖 상수 인자 | `Flag::*`/`Variable::*` 인덱스 0~255 (`hd_config.dart:45-46`), `Battle::RegisterEnemy` **1~74**(부록 B-1: `battle.dart:44` 의 `<= 0` 가드로 0 은 영구 소환 불가) | error |
| L6 | 플래그 인덱스 충돌 | [S2-01](S2-01-flag-registry.md) 의 `flag_registry.json` — **같은 스캔 코드를 공유** | error |
| L7 | 생 숫자 플래그 | `Flag::*(정수리터럴)` — 레지스트리 이름을 쓰라는 지적 | warn (기존 40건은 화이트리스트) |
| L8 | `On(x,y)` 좌표가 맵 범위 안인가 | 맵 JSON 의 `width`/`height`. `OnArea(x1,y1,x2,y2)` 는 4좌표 전부 + `x1<=x2`,`y1<=y2` | error |
| L9 | **그 칸이 실제로 해당 액션 타일인가** | 맵 JSON 의 `objUpper`/`ground`/`events[]` 로 `HDTileAction` 을 계산해, 그 블록이 속한 `ScriptMode()` 분기(`FLAG_TALK`→talk, `FLAG_SIGN`→sign, `FLAG_ENTER`→enter, `FLAG_EVENT`→event)와 일치하는지 | **error** — 어긋나면 그 핸들러는 영원히 실행되지 않는다 |
| L10 | 들여쓰기 블록 구조 | 탭=8칸 환산(`parser.dart:_countIndent`). 탭/스페이스 혼용, `else` 의 들여쓰기가 대응 `if` 와 불일치, 빈 `if` 본문 | warn |
| L11 | `Event::Override()` 누락 | `MapInfos.json#cm2` 로 페어링된 맵의 각 `On`/`OnArea` 블록에 Override 가 없으면 JSON 대사가 중복 출력됨(§9) | warn |
| L12 | `include` 대상 파일 존재 | `assets/` 실물 (실패가 침묵하므로 — `cm2_script.dart:221-223`) | error |

L9 가 이 린터의 핵심 가치다. L1·L2 는 `grep` 으로도 되지만, **L9 는 cm2 와 맵 JSON 을 함께 읽어야만** 가능하다.

## 구현 위치 선택지

| 안 | 방식 | 장점 | 단점 |
|---|---|---|---|
| **(a) 순수 Dart CLI** (`packages/cm2_script` 의 파서 재사용) | `packages/cm2_script/bin/lint.dart` 또는 새 `packages/cm2_lint/`. `parseScript()` 로 AST 를 얻고, 등록 심볼 목록은 `script_engine_adapter.dart` 를 **정규식으로 추출**하거나 상수 목록으로 노출 | **파서가 곧 정본** — 들여쓰기·인자 분해 해석이 런타임과 100% 일치(L10 이 이 덕에 정확) · CI 가 이미 `dart test` 를 돌린다 · 서버 실행이 필요 없다 | 맵 JSON 파싱을 다시 써야 함(에디터에 이미 있는 것) · 등록 심볼 추출이 정규식이면 취약 |
| **(b) 맵 에디터 서버 (TS)** | `GET /api/ai/lint?file=Map016.cm2` 를 `ai_api.ts` 에 추가 | 맵 JSON 로더·타일 액션 분류(`palette`)·`{error,hint}` 규약이 **이미 있다** → L8·L9 가 거의 무료 · [S2-04](S2-04-map-editor-cm2-support.md) 와 코드 공유 | **cm2 파서를 TS 로 다시 구현**해야 한다 — 들여쓰기 규칙(탭=8)·인자 분해를 두 번 구현하면 두 해석이 갈라진다 · dev 서버가 떠 있어야 함 |

### 권고: **(a) 순수 Dart CLI**

- 결정적 이유는 **파서 중복을 만들지 않는 것**이다. (b)는 cm2 파서를 두 벌 갖게 되고,
  그 순간 "린터는 통과하는데 게임은 다르게 동작" 이라는 최악의 실패가 가능해진다.
- 맵 JSON 은 읽기 전용 파싱이라 재구현 비용이 낮다. `hadar2026_app/lib/application/map_loader.dart` 의
  레이어 추출 규칙과 `domain/map/tile_properties.dart` 의 `getUnitAction` 을 **참조**하되,
  린터는 `packages/` 에 있어 앱을 의존할 수 없으므로 **규칙을 복제하고 테스트로 고정**한다
  (`test/domain/map/tile_action_test.dart` 가 이미 와이어 값을 고정하고 있다).
- 등록 심볼 목록은 정규식 추출이 아니라 **`script_engine_adapter.dart` 가 공개 상수로 노출**하게 한다
  (`const hdCommandNames = {...}` / `hdFunctionNames`). 등록과 목록이 갈라지지 않게 등록 루프가 그 집합을 소비한다.
- [S2-04](S2-04-map-editor-cm2-support.md) 의 에디터 오버레이는 이 CLI 를 **자식 프로세스로 호출**해 결과 JSON 을 그린다. 구현은 한 벌이다.

## 무엇을 할 것인가

1. `packages/cm2_lint/` — Dart 패키지. `cm2_script` 를 path 의존.
2. `bin/cm2_lint.dart` — `cm2_lint <assets_dir> [--map-dir <dir>] [--json] [--registry <path>]`.
   기본 출력은 `파일:줄: [L2] Unknown function: Party::CheckIf` 형태 한 줄씩. `--json` 은 기계 소비용.
3. `script_engine_adapter.dart` — 등록 심볼을 공개 상수 집합으로 노출(등록 루프가 그것을 소비).
4. `test/` — 위 L1~L12 각각에 **양성 1개 + 음성 1개** 픽스처.
5. CI 에 추가. 다만 **기존 9곳 때문에 즉시 red 가 되므로**, 첫 커밋은 `--baseline baseline.json` 으로
   현재 위반을 동결하고 **신규 위반만** 실패시킨다(`--no-fatal-infos` 와 같은 논리).

## 완료 판정 기준

- [ ] 현재 레포에 돌리면 **미등록 심볼 6종·9곳**을 정확히 그 목록으로 보고한다(위 표와 일치)
- [ ] `flag4ep1.cm2:43` 의 대입 이름 불일치를 L4 로 보고한다
- [ ] `Map002.cm2` 의 `On(30,20)`·`On(30,25)`·`On(30,28)`·`OnArea(23,21,23,22)` 를 `Map002.json` 과 대조해 L8·L9 판정을 낸다
- [ ] `Battle::RegisterEnemy(0)` 과 `(75)` 를 L5 error 로, `(5)` 를 통과로 판정한다
- [ ] 등록 심볼을 코드에서 1개 지우면 린터 결과가 **자동으로** 늘어난다(목록 하드코딩이 아님)
- [ ] baseline 을 걸면 현재 레포에서 종료 코드 0, 새 위반 1건을 넣으면 1
- [ ] `packages/cm2_lint/test/` 가 L1~L12 를 각각 고정한다

## 하지 않을 것

- **솔버·시뮬레이터가 아니다.** 정적 심볼·참조 검사까지다. 다음은 명시적으로 범위 밖:
  - 퀘스트가 완주 가능한지 · 플래그 순서가 도달 가능한지 · 데드락 탐지 → [deferred/P2-05](../deferred/P2-05-quest-solver.md)
  - 실행 경로 탐색 · 퍼징 → [deferred/P2-06](../deferred/P2-06-fuzzer.md)
  - 전투 밸런스 · 보상 적정성
- **런타임 동작 변경 없음.** 미등록 심볼을 예외로 바꾸는 것은 별건(런타임 침묵은 [P0-14](../P0-foundation/P0-14-silent-out-of-range.md)).
- **기존 위반 9곳을 고치지 않는다.** baseline 에 동결하고 별도 이슈로 넘긴다 —
  `Party::CheckIf` 는 실제 게임플레이 버그이므로 P0 백로그에 새로 올릴 대상이다.
- 문체·자수 검사([BP-43](../../blueprint/43_content_style_guide.md) §7.2 의 12건). 이 린터는 **심볼과 참조만** 본다.
- cm2 자동 수정(`--fix`).
