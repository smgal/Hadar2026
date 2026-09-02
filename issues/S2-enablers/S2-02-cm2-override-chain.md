# S2-02 cm2 override 체인 — 한 맵에 퀘스트 여러 개

- **상태**: BLOCKED (S1-99 대기)
- **구간**: S2
- **규모**: M
- **선행**: [S1-99](../S1-sample-quest/S1-99-friction-log.md)
- **설계 근거**: [MILESTONES §3](../MILESTONES.md) · [`GROUND_TRUTH` §4 3티어 디스패치 · §9 CM2 한계](../../blueprint/_meta/GROUND_TRUTH.md)

## 착수 조건

[S1-99 마찰 기록](../S1-sample-quest/S1-99-friction-log.md) 이 이 문제를 **실제로 겪었다고 확인**해야 한다.
겪지 않았으면 이 이슈는 `DROPPED` 다.

다음 중 하나가 기록되어 있어야 한다.
- 기존 맵(`Map002` 등)에 퀘스트를 얹으려다 **그 맵의 cm2 를 직접 편집**해야 했다
- 퀘스트 로직과 맵 상주 로직(`Map::SetStartPos` 등)이 한 파일에 섞여 어느 쪽이 무엇인지 헷갈렸다
- 퀘스트를 지우려면 파일 중간에서 블록을 골라내 지워야 했다

## S1 이 겪지 않았다면

**S1 은 새 맵(`Map016`)을 만든다.** 새 맵이면 `Map016.cm2` 를 통째로 소유하므로 공유 문제가 발생하지 않는다.
즉 S1 이 이 문제를 겪지 않는 것이 **정상**이고, 겪었다면 오히려 S1 이 기존 맵을 건드렸다는 뜻이다.

버려도 되는 근거: 퀘스트를 **맵 1개당 1개**로 제한하는 정책을 세우면 이 이슈는 영구히 필요 없다.
새 맵 생성은 [S3-03](../S3-generation/S3-03-map-generation.md) 이 API 로 자동화하므로 비용이 거의 0이다.
그 정책을 [DECISION-LOG](../DECISION-LOG.md) 에 명시하고 이 이슈를 `DROPPED` 하는 것이 정당한 선택지다.
**반대로 "기존 마을(`LORE_EP`)에 퀘스트를 붙인다" 가 목표에 들어오는 순간 이 이슈는 필수가 된다.**

## 문제

### cm2 는 맵당 정확히 1개다

`hadar2026_app/lib/application/game_session.dart:100-108`:

```dart
currentMapCm2Path = bundle.cm2Path;
if (bundle.cm2Path != null) {
  // ... 주석: 이것이 ScriptEngine.variables/contexts 를 지운다
  await HDScriptEngine().loadScript(_resolveCm2Asset(bundle.cm2Path!));
}
```

`String? currentMapCm2Path`(`:83`) — **단수**다. `HDMapNavigation` 도 `MapBundle.cm2Path` 하나만 만든다
(`map_navigation.dart:44` 기본값 `'Map$idStr.cm2'`, `:46` 이 `MapInfos.json#cm2` 로 덮어씀).
디스패처도 그 하나만 돌린다 — `tile_event_dispatcher.dart:140-144`.

→ 한 맵에 퀘스트 2개면 **같은 파일 안에 두 퀘스트의 `On(x,y)` 블록이 섞인다.**

### `include` 로는 안 된다 — 다만 이유가 통설과 다르다

`packages/cm2_script/lib/src/cm2_script.dart:99`:

```dart
for (var stmt in statements) {
  if (stmt is CommandStatement) {
    if (stmt.command == 'variable' || stmt.command == 'include') continue;
  }
```

이 필터는 **최상위(top-level) 문장에만** 걸린다. `if` 블록 안의 `include` 는 `IfStatement.body` 에 들어가므로
`executeStatement` → `executeCommand` → `_executeInclude`(`:209`) 로 **매 `run()` 마다 실행된다.**

**실측(엔진을 직접 구동해 확인)**: 중첩 `include` 는 매 `run()` 마다 재실행되고, 그 안의 `if` 블록도 평가되며,
그 안의 `Event::Override()` 도 `engine.handled = true` 를 정상 세팅한다. 즉 **per-tile 핸들러를 담을 수 있다.**

그런데도 쓸 수 없는 이유는 따로 있다.

| 이유 | 근거 |
|---|---|
| `_executeInclude` 는 포함 파일의 **모든** 문장을 필터 없이 실행한다(`:218-220`). 최상위 `variable`/`.assign` 이 **매 상호작용마다 재실행**되어 상태를 지운다 | `cm2_script.dart:218-220` · [CLAUDE.md](../../CLAUDE.md) "init vs run phase" |
| 상호작용 1회마다 파일을 **다시 읽고 다시 파싱**한다(`_contentLoader` 는 `Future`) | `cm2_script.dart:209-224` |
| `include` 실패는 `print` 만 남기고 조용히 넘어간다 — 경로 오타가 "퀘스트가 아무 반응 없음" 으로 나타난다 | `cm2_script.dart:221-223` |
| CLAUDE.md 가 **"one-shot initial assignments 를 include 에 두라"** 를 규정한다. include 의 의미를 바꾸면 `L1_ep1d0.cm2:1-2` 의 `include("const.cm2")`·`include("flag4ep1.cm2")` 계약이 흔들린다 | [CLAUDE.md](../../CLAUDE.md) · `L1_ep1d0.cm2:1-2` |

## 왜 지금 고쳐야 하는가

- [S3-05](../S3-generation/S3-05-pilot-batch.md) 는 퀘스트 **3개**를 배치 생성한다. 3개가 서로 다른 새 맵을 쓰면 넘어가지만,
  같은 마을을 무대로 삼는 순간 세 AI 출력이 **한 파일을 동시에 편집**해야 한다.
- 퀘스트를 파일 단위로 격리하지 못하면 [S3-04](../S3-generation/S3-04-minimal-validation.md) 의
  "기존 파일 미변경" 검사가 성립하지 않는다 — 생성물이 항상 기존 파일을 수정하게 된다.

## 해법 선택지

| 안 | 방식 | 장점 | 단점 |
|---|---|---|---|
| **(a) 스크립트 목록 + 순차 run** | `HDScriptEngine` 이 `List<String> scripts` 를 들고 순서대로 `loadFromString`+`run`. `handled` 가 true 면 중단. `MapInfos.json#cm2` 가 배열도 받게 확장 | 파일당 퀘스트 1개로 **완전 격리** · 순서가 데이터에 명시 · 요소 1개면 현재 동작과 동일 · 린터가 목록을 읽어 검사 가능 | `HDScriptEngine` 에 파싱 캐시가 필요(맵당 N개 파싱) · `MapInfos.json` 스키마 확장 |
| **(b) `Quest::Run("...")` 커맨드 신설** | 맵 cm2 가 명시적으로 위임. 41번째 등록 커맨드 | 데이터 스키마 무변경 · 위임 지점이 스크립트에 보임 | **맵 cm2 를 매번 편집해야 한다** — 격리 목표 자체를 달성 못 함 · 재진입(퀘스트가 퀘스트를 호출) 가드 필요 |
| **(c) `run()` 에서 top-level `include` 재실행** | `cm2_script.dart:99` 의 필터에서 `'include'` 를 뺀다 | 1줄 변경 | **기존 콘텐츠 파손.** `L1_ep1d0.cm2:1-2` 가 매 상호작용마다 `const.cm2`+`flag4ep1.cm2` 를 재실행 → 34개 `.assign` 재실행(무해) + 파일 2개 재파싱(느림). 더 나쁜 것은 `L1_ep1d0.cm2:12` 의 `special_event.assign(0)` 류가 **최상위**라 이미 매 run 재실행되는데, include 까지 열면 CLAUDE.md 가 규정한 "include = 상태 보존 장소" 계약이 무너진다 → **기각** |
| **(d) 중첩 `include` (코드 0줄)** | `if (Equal(ScriptMode(), FLAG_TALK))` 안에 `include("quest_a.cm2")` 를 넣는다. 위 실측대로 동작한다 | **오늘 당장 된다** · 코드 변경 0 | 포함 파일의 최상위 `variable`/`.assign` 이 매번 재실행(상태 리셋) → 퀘스트 파일에 상수 정의를 못 둠 · 상호작용마다 파일 I/O · 실패 침묵 · 순서 제어가 들여쓰기 위치에 묻힘 |

### 권고: **(a) 스크립트 목록 + 순차 run**

- 격리(파일당 퀘스트 1개)를 **실제로** 달성하는 유일한 안이다. (b)는 맵 파일 편집을 남기고, (d)는 퀘스트 파일에 상수를 못 둔다.
- 요소가 1개일 때 **현재와 완전히 같은 경로**가 되도록 만든다 — 이것이 회귀 방어의 핵심이다.
- `MapInfos.json` 의 `cm2` 는 문자열도 배열도 받는다(`map_navigation.dart:46` 이 이미 `info['cm2'] is String` 을 검사하므로
  `is List` 분기를 나란히 추가). 기존 데이터는 `cm2` 필드가 **하나도 없으므로**(부록 §6) 데이터 마이그레이션이 0이다.
- **(d)는 S1~S2 사이의 임시 우회로만 문서화**한다. S1 이 급히 필요하면 (d)로 넘기고, S2 에서 (a)로 대체한다.

### 기존 콘텐츠 회귀를 무엇이 막는가

1. **데이터 무변경**: `MapInfos.json` 에 `cm2` 필드가 지금 0개다(부록 §6). 배열 지원을 넣어도 읽히는 값이 없다.
2. **단일 요소 동일 경로**: `cm2Path` 단수 → `[cm2Path]` 로 감싸는 것이 유일한 변경. `handled` 검사는 마지막 요소 뒤에 한 번(현행과 동일).
3. **`clearRuntimeState` 시점 고정**: 목록의 **첫 요소 로드에서만** 초기화하고 이후 요소는 초기화하지 않는다.
   그러지 않으면 `const.cm2` 상수가 두 번째 퀘스트에서 사라진다. 이 규칙을 테스트로 못박는다.
4. **테스트**: `hadar2026_app/test/application/` 에 `map_navigation_test.dart`(in-memory `AssetSource` 페이크) 형태를 복사해
   ① `cm2` 문자열 1개 → 현행과 동일 ② 배열 2개 → 순서대로 실행 ③ 첫 요소가 `Event::Override()` → 두 번째 실행 안 됨 ④ 두 번째만 Override → JSON 폴백 없음, 을 고정한다.

## 무엇을 할 것인가

1. `domain/map/map_bundle.dart` — `String? cm2Path` → `List<String> cm2Paths`.
2. `application/map_navigation.dart:44-46` — `info['cm2']` 가 `String` 이면 1요소, `List` 면 그대로.
3. `application/game_session.dart:83,100-108` — `currentMapCm2Path` → `currentMapCm2Paths`. 로드는 첫 요소만 `clearRuntimeState`.
4. `application/scripting/script_engine_adapter.dart` — `runChain()` 추가: 목록을 순서대로 파싱·실행, `handled` 면 중단.
   파싱 결과는 맵 전환까지 캐시한다(상호작용마다 재파싱하지 않는다).
5. `application/tile_event_dispatcher.dart:140-144` — `run()` → `runChain()`.

## 완료 판정 기준

- [ ] `MapInfos.json` 의 `"cm2": ["Map016.cm2", "quest_Q1.cm2"]` 가 두 파일을 **그 순서로** 실행한다
- [ ] `"cm2": "Map016.cm2"`(문자열)이 변경 전과 **동일하게** 동작한다
- [ ] 앞 파일이 `Event::Override()` 를 부르면 뒤 파일이 **실행되지 않고** JSON 폴백도 없다
- [ ] 아무 파일도 Override 하지 않으면 JSON `dialogLines` 폴백이 **그대로** 나온다
- [ ] `const.cm2` 의 상수가 목록의 **두 번째 이후 파일에서도** 참조된다
- [ ] 상호작용 100회 후에도 파일 파싱 횟수가 맵 전환 횟수와 같다(재파싱 없음)
- [ ] `test/application/cm2_chain_test.dart` 가 위 6개를 고정한다

## 하지 않을 것

- cm2 언어에 함수·루프·모듈을 추가하는 것. 문법은 손대지 않는다(§9).
- `include` 의 의미 변경 — (c) 를 기각한 이유가 그것이다.
- 퀘스트 런타임·대화 런타임 도입 — [deferred/P1-07](../deferred/P1-07-dialogue-runtime.md) · [P1-08](../deferred/P1-08-quest-runtime.md) 소관.
- 네이티브 맵 스크립트 티어 변경. 이 이슈는 **cm2 티어 안**의 문제다.
- `HDScriptEngine.variables` 를 맵 전환에서 보존하는 것(§9 마지막 항목). 별건이다.
