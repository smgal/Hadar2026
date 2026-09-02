# S3-04 최소 검증 — 심볼 · 플래그 충돌 · 좌표 존재

- **상태**: BLOCKED (S2-03 대기)
- **구간**: S3
- **규모**: M
- **선행**: [S2-03](../S2-enablers/S2-03-cm2-linter.md)
- **설계 근거**: [MILESTONES §4](../MILESTONES.md) · [`GROUND_TRUTH` §9 · 부록 A-2 · D-1 · F-1](../../blueprint/_meta/GROUND_TRUTH.md) · [DECISION-LOG 2차 판정](../DECISION-LOG.md)

## 착수 조건

[S2-03](../S2-enablers/S2-03-cm2-linter.md) 이 `DONE` — **이 이슈는 린터를 재사용한다.** 없으면 실체가 없다.
S2-03 이 `DROPPED` 면 이 이슈도 `DROPPED` 이고, 그때 검증은 사람의 플레이 검수([S3-05](S3-05-pilot-batch.md))가 전부다.

## 문제

생성물은 **파일 4종**이다([S3-02](S3-02-generation-prompt.md) §10):
`flag4<quest>.cm2` · `<quest>.cm2` · 맵 편집 `ops` · `MapInfos` 항목.

이 중 무엇이 틀려도 **게임은 오류를 내지 않는다.**

| 틀린 것 | 런타임 반응 | 근거 |
|---|---|---|
| 미등록 함수 | `print` 후 **0 반환** → 오분기 | `cm2_script.dart:335-336` |
| 미등록 커맨드 | `print` 후 스킵 | `cm2_script.dart:204` |
| 범위 밖 플래그 인덱스 | **아무 일도 없고 로그도 없다** | 부록 F-1 |
| 범위 안이지만 남의 플래그 | 남의 상태를 켠다. 로그 없음 | [S2-01](../S2-enablers/S2-01-flag-registry.md) §문제 |
| cm2 파일 경로 오타 | 로드 실패가 **`print` 만** 남고 직전 스크립트가 그대로 남는다 | 부록 A-2 (`script_engine_adapter.dart:97`) |
| `MapInfos` 이름 해석 실패 | **성공으로 보고**하고 맵만 안 바뀐다 | 부록 D-2 |

즉 **"돌려 보니 되던데" 가 검증이 아니다.** 조용히 틀린 것은 플레이로도 안 보인다.

## 무엇을 할 것인가

### 1. `cm2_lint` 재사용 (새로 만들지 않는다)

[S2-03](../S2-enablers/S2-03-cm2-linter.md) 의 L1~L12 를 그대로 돌린다.
`--registry assets/flag_registry.json --map-dir assets/maps --json`.

### 2. 생성물 전용 추가 검사

| # | 검사 | 방법 | 심각도 |
|---|---|---|---|
| G1 | **플래그 충돌** — 생성물이 쓴 인덱스가 [S2-01](../S2-enablers/S2-01-flag-registry.md) 이 그 퀘스트에 배정한 것뿐인가 | `flag_alloc check` + 생성물의 사용 인덱스 집합 ⊆ 배정 집합 | error |
| G2 | **기존 파일 미변경** — 생성 전후로 기존 파일이 하나도 바뀌지 않았는가 | `git status --porcelain` 이 **신규(`??`)만** 보고. 수정(`M`)이 1건이라도 있으면 실패. 예외 2개: `assets/maps/MapInfos.json`, `assets/flag_registry.json` (항목 **추가만** — diff 가 삭제줄 0) | error |
| G3 | **새 맵이 이름으로 로드되는가** | `MapInfos.json` 항목에 `json` 필드 존재 + 그 파일 존재 + [S3-02](S3-02-generation-prompt.md) 가 지정한 `cm2` 파일 전부 존재. 부록 D-1 의 파손 유형을 정면으로 막는다 | error |
| G4 | **cm2 파일 경로 실존** | `MapInfos.json#cm2`(문자열/배열)의 각 항목이 `assets/` 에 있는가. 없으면 부록 A-2 의 침묵 누수 | error |
| G5 | **좌표 일치** | 생성 cm2 의 `On`/`OnArea` 전부가 [S3-03](S3-03-map-generation.md) 이 넘긴 좌표 목록 안에 있는가 (L8·L9 와 별개 — 목록 대조) | error |
| G6 | **필수 대사 존재** | 개요의 `completed_line` 이 생성 cm2 안에 실제로 있는가 (완료 상태 분기가 만들어졌는지) | warn |
| G7 | **플래그 3단계 기록** | 개요의 `beats` 3개에 대응하는 `Flag::Set` 이 각각 최소 1회 있는가 | error |
| G8 | **플래그 읽기 존재** | 배정된 각 플래그가 `Flag::Set` 뿐 아니라 `Flag::IsSet` 으로도 **읽히는가**. 쓰기만 있으면 그 플래그는 무의미하다 | warn |

### 3. 판정과 재시도 루프

```
생성 → cm2_lint + G1~G8
  ├─ error 0            → 통과. 사람 검수(S3-05)로 넘긴다
  └─ error ≥ 1
       ├─ 재시도 < 3     → 린터·검사 출력을 그대로 프롬프트에 되먹임(S3-02 §자기수정 루프) → 재생성
       └─ 재시도 == 3    → **사람 개입 지점 (아래)**
```

**사람 개입 지점 4개** (자동 폐기하지 않는다):

| 지점 | 무엇을 판단하는가 |
|---|---|
| 재시도 3회 후 error 잔존 | 프롬프트가 부족한가 / 개요가 모순인가 / 게임이 표현 못 하는 요구인가 |
| G1 위반이 "플래그가 더 필요" 인 경우 | 개수를 늘려 재배정할지 퀘스트를 줄일지 |
| G2 위반(기존 파일 수정 시도) | **즉시 중단.** 되돌리고 원인을 본다. 자동 재시도하지 않는다 |
| warn 만 남은 경우 | 통과시킬지 손볼지. warn 은 자동 재시도 대상이 아니다 |

`git` 이 안전망이다 — 검증 전에 커밋해 두고, G2 위반이면 `git checkout -- .` 로 되돌린다.

### 4. 실행 형태

`tools/quest_check.sh <quest_id>` — `cm2_lint` + `flag_alloc check` + `git status` + G3~G8 을 순서대로 돌리고
한 화면짜리 요약과 종료 코드를 낸다. **새 프레임워크를 만들지 않는다.**

## 완료 판정 기준

- [ ] `quest_check.sh S1` 이 S1 산출물(사람이 손으로 만든 것)에 대해 **통과**한다 — 검사가 정상 콘텐츠를 거짓 실패시키지 않는다
- [ ] 배정 밖 플래그 인덱스를 1개 심으면 G1 이 잡는다
- [ ] 기존 `Map002.cm2` 를 1줄 고치면 G2 가 잡고, `MapInfos.json` 에 항목을 **추가**하는 것은 통과한다
- [ ] `MapInfos` 항목의 `json` 필드를 지우면 G3 이 잡는다
- [ ] `cm2` 에 없는 파일명을 넣으면 G4 가 잡는다
- [ ] `On(x,y)` 를 좌표 목록에 없는 값으로 바꾸면 G5 가 잡는다
- [ ] `beats` 중 하나의 `Flag::Set` 을 지우면 G7 이 잡는다
- [ ] 재시도 3회 초과 시 종료 코드가 사람 개입을 요구하는 값(예: 2)이고, **파일을 지우지 않는다**
- [ ] 위 8개가 픽스처로 고정되어 있다

## 하지 않을 것 — 명시적 범위 밖

이 이슈는 **정적 검사와 재시도 루프**까지다. 아래는 전부 [deferred/](../deferred/) 노선이며 **끌어오지 않는다.**

| 하지 않는 것 | 왜 | 어디 |
|---|---|---|
| **솔버 · 완주 증명** — 퀘스트가 처음부터 끝까지 도달 가능한지 자동 증명 | 헤드리스 구동 자체가 막혀 있다(부록 B-3: 이동·상호작용이 Bonfire 스프라이트 `update(dt)` 안에 있다). 선결 과제가 이 이슈보다 크다 | [deferred/P2-05](../deferred/P2-05-quest-solver.md) · [P2-03](../deferred/P2-03-movement-loop-extraction.md) |
| **퍼저** — 무작위 입력으로 상태 공간 탐색 | 위와 같은 이유 + 결정론이 없다(부록 C-4: 시드 없는 `Random()` 14곳, 벽시계 독 데미지) | [deferred/P2-06](../deferred/P2-06-fuzzer.md) |
| **2축 판정** — 품질·안전을 별도 축으로 나눠 채점 | 축을 나눌 만큼 표본이 없다. 퀘스트 3개(S3-05)로는 축이 의미를 갖지 않는다 | [deferred/P2-07](../deferred/P2-07-generation-pipeline.md) |
| **헤드리스 하네스** | 부록 B-3 · B-4(`exit(0)`) | [deferred/P2-04](../deferred/P2-04-headless-harness.md) |
| **문체·자수 자동 검사** | [BP-43 §7.2](../../blueprint/43_content_style_guide.md) 의 12건. 문체는 사람이 본다 | — |
| **골든 회귀 테스트** | 결정론 부재(부록 C-4)가 선결 과제 | [P0-11](../P0-foundation/P0-11-unseeded-random.md) |

**완주 여부를 확인하는 것은 사람이 직접 플레이하는 것이다** — [S3-05](S3-05-pilot-batch.md).
그것이 이 구간의 의도된 검증 수단이고, 자동화는 "사람이 감당 못 하는 물량" 이 될 때 꺼낸다([MILESTONES §5](../MILESTONES.md)).
