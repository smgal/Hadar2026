# 퀘스트 저널·추적 UI 스펙 (800×480)

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-41 · **상태**: 초안 · **선행 문서**: [BP-40](40_gameplay_changes.md), [BP-23](23_quest_model.md), [BP-24](24_dialogue_model.md)
> **독자**: UI 구현자 · 콘텐츠 린트 구현자 · 검수 에이전트
> **한 줄 요약**: 800×480 고정 레이아웃 안에서 **실제로 구현 가능한** 임무 기록 화면을 픽셀·행·글자 수까지 확정한다.
> 신규 입력 모드 0개, 신규 `UiHost` 메서드 0개, 신규 전역 키 0개.

**파이프라인 구획(D-01)**: **Runtime** 이다. 다만 §4 의 길이 상한은 **Build 단계 린트**가 강제한다.

**이 장이 다루지 않는 것**:
- 왜 저널이 필요한가·메뉴 재설계의 근거 → [BP-40](40_gameplay_changes.md) §40.2.1, §40.4
- 저널에 들어갈 **문자열의 문체** → [BP-43](43_content_style_guide.md)
- `WorldState.journal` 의 데이터 모델·표시 규칙(계산식) → [BP-25](25_world_state_and_save.md) §2.2, [BP-23](23_quest_model.md) §23.10
- 소지품 화면 → [BP-42](42_item_and_inventory.md) §5 (프레임 규약만 이 장이 확정하고 내용은 그쪽)

---

## 41.1 현행 레이아웃 실측

### 41.1.1 `hd_config.dart` 상수 vs 실제 위젯 배치 vs `UI_SPEC.md`

`main.dart` 는 `SizedBox(800×480)` 안에 `Stack { Column { Row(맵, 대화), Row(상태, 진행) }, HDWindowLayer }` 을 놓는다.
따라서 각 영역의 좌표는 열거 순서에서 유도된다.

| 영역 | 위젯 클래스 | 파일 | 좌상단 | 크기 | `HDConfig` 상수 | `UI_SPEC.md` 기재 | 판정 |
|---|---|---|---|---|---|---|---|
| 맵 뷰포트 | `HDMapViewport` | `presentation/panels/map_viewport.dart` | (0, 0) | 288 × 320 | `mapViewportWidth/Height` | (0,0) 288×320 | ✅ 일치 |
| 대화 패널 | **`HDDialogPanel`** | `presentation/panels/console_panel.dart` | (288, 0) | 512 × 320 | `consoleWidth/Height` | "HDConsolePanel" (288,0) 512×320 | ⚠️ **클래스명 불일치** |
| 상태 패널 | `HDStatusPanel` | `presentation/panels/status_panel.dart` | (0, 320) | **288 × 160** | `statusPanelWidth/Height` | (0,320) **800×160** | ❌ **크기 불일치** |
| 진행 패널 | **`HDDescriptionPanel`** | `presentation/panels/input_panel.dart` | (288, 320) | 512 × 160 | `inputPanelWidth/Height` | **기재 없음** | ❌ **누락** |
| 창 층 | `HDWindowLayer` | `presentation/panels/window_view.dart` | (0, 0) | 800 × 480 (`StackFit.expand`) | — | **기재 없음** | ❌ **누락** |
| 모바일 컨트롤 | `HDBottomControlPanel` | `presentation/panels/bottom_control_panel.dart` | 800×480 **바깥** (`FittedBox` 밖, `Column` 하단) | 가변 폭 × 내부 234 | — | **기재 없음** | ❌ **누락** |

**`UI_SPEC.md` 의 3건 오류 (이 장이 정정)**

| # | `UI_SPEC.md` 서술 | 실측 | 정정 |
|---|---|---|---|
| U-1 | `HDStatusPanel` 은 (0,320) **800×160** | `statusPanelWidth = 288.0` (`hd_config.dart`), `status_panel.dart` 가 `HDConfig.statusPanelWidth` 사용 | 하단 160px 은 **288(상태) + 512(진행)** 두 패널이다 |
| U-2 | §3 "Interaction Key: **Space bar**" | `input_dispatcher.dart` `_handleMap` — Space 는 **메인 메뉴 열기**. 상호작용은 `HDPlayerSprite` 가 Enter/E 로 처리 | `docs/key_input_policy.md` 가 정본 |
| U-3 | 뷰포트가 "3개" | 실제 패널은 **4개 + 창 층 + 모바일 컨트롤** | 위 표 |

> **규범 R-41-1**: `UI_SPEC.md` 는 이 표로 갱신되어야 한다. 갱신 전까지 **이 장의 표가 정본**이다.

### 41.1.2 대화 패널 내부 예산 (BP-24 §24.5.1 재확인)

| 항목 | 값 | 출처 |
|---|---|---|
| 패널 | 512 × 320 | `HDConfig.consoleWidth/Height` |
| 패딩 | 좌우 16, 상하 8 | `console_panel.dart` `EdgeInsets.symmetric(horizontal:16, vertical:8)` |
| 내부 | **480 × 304** | — |
| 1행 높이 | **19.2px** | `consoleFontSize 16 × consoleLineHeight 1.2` |
| 섹션 간격 | 28.8px (1.5행) | `HDConfig.dialogSectionGap` |
| 본문 최대 | **13행** | `HDConfig.maxLinesPerPage = 13` |
| 줄바꿈 기준 폭 | 480px | `flutter_ui_host.dart` `_consoleWidth = consoleWidth − 32` |

### 41.1.3 진행 패널 내부 예산 (신규 실측 — BP-24 가 다루지 않은 영역)

| 항목 | 값 | 출처 |
|---|---|---|
| 패널 | 512 × 160 | `HDConfig.inputPanelWidth/Height` |
| 패딩 | 좌우 16, 상하 8 | `input_panel.dart` `ListView.builder(padding: EdgeInsets.symmetric(horizontal:16, vertical:8))` |
| 내부 | **480 × 144** | — |
| 표시 행 수 | 144 / 19.2 = **7.5행** | 스크롤 가능(`ListView`), 버퍼 200줄(`HDConfig.maxProgressLines`) |
| 자동 추종 | 바닥에 있을 때만 | `input_panel.dart` `_maybeFollowBottom` |

### 41.1.4 오버레이 창의 기하학 (실측)

`HDWindowWidget` 은 `Positioned(left: w.x, top: w.y, width: w.w, height: w.h)` 로 그리고,
`Container(border: Border.all(width: 2), padding: EdgeInsets.all(8))` 를 씌운다(`window_view.dart`).

```
내부 폭  = w − 2×2(테두리) − 2×8(패딩) = w − 20
내부 높이 = h − 2×2         − 2×8       = h − 20
```

| 창 | 기본 좌표 | 크기 | 높이 공식 | 출처 |
|---|---|---|---|---|
| `HDSelectionWindow` | (200, 100) — 인자로 재정의 가능 | 400 × 가변 | `60 + min(enabledCount, 6) × 34` | `domain/window/selection_window_data.dart` |
| `HDMessageWindow` | (288, 100) | **400 × 200** (고정) | 고정 | `HDConfig.messageWindow*` |
| `HDMagicSelectionWindow` | (288, 100) | 400 × 가변(초기 240) | `60 + min(n, 6) × 36` | `domain/window/magic_window_data.dart` |

- 메인 메뉴만 `x: 200`(`menu_flows.dart` `showWindowMenu(choices, x: 200)`), 나머지는 콘솔 정렬 `x: 288`.
- 스크롤 인디케이터 `▲`/`▼` 는 `window_view.dart` `_wrapWithScrollIndicators` 가 우측 4px 에 그린다.

---

## 41.2 저널 화면 설계 — 3안 비교와 권고

### 41.2.1 요구사항

| ID | 요구 | 근거 |
|---|---|---|
| R-41-2 | 활성 퀘스트 목록 + 선택 항목 상세를 볼 수 있어야 한다 | [BP-23](23_quest_model.md) §23.10.4 |
| R-41-3 | 완료·실패 아카이브를 볼 수 있어야 한다 | 동상 (`completed` 회색, `failed` 어두운 회색) |
| R-41-4 | 목표 체크리스트에 `[ ]` / `[v]` / `[3/5]` 를 표시 | 동상 |
| R-41-5 | 신규 전역 키 0개, 신규 `HDInputMode` 0개 | [BP-40](40_gameplay_changes.md) R-40-10, R-40-14 |
| R-41-6 | 열람 중 게임 상태가 변하지 않는다 (시간·이동·전투 없음) | [BP-40](40_gameplay_changes.md) Q-40-2 잠정 확정 |
| R-41-7 | 닫으면 직전 화면으로 완전 복귀 | — |

### 41.2.2 3안

#### A안 — 기존 메뉴/콘솔만으로 (신규 위젯 0)

`showWindowMenu(활성 퀘스트 목록)` → 선택 → `clearLogs()` + `addLog` 로 상세를 콘솔에 출력 → `waitForAnyKey()`.
[BP-27](27_runtime_engine.md) §7.2 의 스케치가 이 방식이다.

| | 평가 |
|---|---|
| 신규 코드 | **0 위젯**. `menu_flows.dart` 에 메서드 1개 |
| 화면 | 대화 패널 512×320, 본문 13행 |
| 장점 | 구현 최소. 기존 어휘 100% 재사용. 원작 감성 최고 |
| 단점 | ① 목록과 상세를 **동시에** 볼 수 없다 ② 탭(완료/실패) 개념을 넣으면 메뉴가 3중첩된다 ③ 목록 항목이 `maxVisibleItems=6` 에 걸린다 ④ 진행률 `[3/5]` 는 되지만 체크박스 정렬이 흐트러진다(비례폭 반각 혼용) |
| R-41-3 | ❌ 아카이브가 3단 깊이로 밀린다 |

#### B안 — 전용 오버레이 창 `HDJournalWindow` (권고)

`HDWindowManager` 스택에 올라가는 전용 창. 내부에서 목록/상세 두 화면을 전환.

| | 평가 |
|---|---|
| 신규 코드 | 도메인 1(`HDJournalWindow`), 뷰 1(`HDJournalView`), 키 분기 1, 프레젠터 1 |
| 화면 | **512 × 400**, 내부 492 × 380 = **19행** |
| 장점 | ① 탭·목록·미리보기를 한 화면에 ② 기존 `HDInputMode.window` 로 자동 커버 ③ 소지품 창과 프레임 공유 ④ 열람 중 게임이 멈추는 것이 자연스럽다 |
| 단점 | 위젯 1개 신규. 창이 다소 크다(화면의 53%) |
| R-41-3 | ✅ 탭 1행으로 해결 |

#### C안 — 전체 화면 전환 (패널 교체)

`main.dart` 의 `Column` 을 통째로 저널 화면으로 대체.

| | 평가 |
|---|---|
| 신규 코드 | `main.dart` 분기 + 전체 화면 위젯 |
| 장점 | 공간이 800×480 전부 |
| 단점 | ① **Freeze List F-3 위반** — 3뷰포트 구조가 사라진다 ② `HDInputMode` 를 새로 만들어야 한다(창 스택 밖) ③ 맵이 사라져 "어디 있었지" 가 끊긴다 ④ 원작에 전체 화면 전환은 전투밖에 없다 |
| R-41-5 | ❌ 신규 입력 모드 필요 |

### 41.2.3 판정

| 기준 | A | B | C |
|---|---|---|---|
| R-41-2 목록+상세 | △ | ✅ | ✅ |
| R-41-3 아카이브 | ❌ | ✅ | ✅ |
| R-41-4 체크리스트 정렬 | △ | ✅ | ✅ |
| R-41-5 신규 모드/키 0 | ✅ | ✅ | ❌ |
| R-41-6 상태 불변 | ✅ | ✅ | ✅ |
| Freeze List 준수 | ✅ | ✅ | ❌ |
| 구현 비용 | 최소 | 중 | 대 |
| 원작 감성 | 최고 | 상 | 하 |

> **권고안 확정 — B안 (`HDJournalWindow`, 512×400, 화면 정중앙)**
>
> 근거: A안은 R-41-3 을 만족시키려면 메뉴 3중첩이 되어 오히려 깊이가 늘고([BP-40](40_gameplay_changes.md) F-4 정신 위반),
> C안은 Freeze List F-3 을 깬다. B안은 기존 창 스택·입력 모드·키 어휘를 **하나도 늘리지 않고** 요구를 전부 만족한다.

### 41.2.4 창 기하학 확정

| 항목 | 값 | 근거 |
|---|---|---|
| 좌상단 | **(144, 40)** | 정중앙: (800−512)/2 = 144, (480−400)/2 = 40 |
| 크기 | **512 × 400** | 대화 패널과 같은 폭 → 글자 수 예산 재사용 |
| 우하단 | (656, 440) | 800×480 안에 여백 40px 씩 |
| 내부 영역 | **492 × 380** | §41.1.4 공식 (`w−20`, `h−20`) |
| 본문 행 수 | **19행** | 380 ÷ 19.2 = 19.79 → 19 (잉여 15.2px 은 하단 여백) |
| 글꼴 | DungGeunMo 16pt, 행높이 1.2 | 대화 패널과 동일 |
| 한 행 폭 | **한글 30자 / 반각 60칸** | 492 ÷ 16 = 30.75 → 30 |
| 배경 | `Colors.black.withOpacity(0.8)` + 흰 테두리 2px | `window_view.dart` 기존 창 규약 그대로 |

> **소지품 창도 같은 기하학을 쓴다**(R-41-8). 두 창이 다른 크기면 "메뉴에서 다른 것을 골랐을 뿐인데 창이 튄다" 는 인상이 된다.

---

## 41.3 정보 구조

### 41.3.1 화면 2종 · 탭 3종

```
HDJournalWindow
├── 화면 1: 목록 (list)
│     ├── 탭 A: 진행 중  (state == active)
│     ├── 탭 B: 마친 일  (state == completed)
│     └── 탭 C: 못 마친 일 (state == failed)
└── 화면 2: 상세 (detail)   ← 목록에서 Enter
```

- `inactive` 퀘스트는 **어느 탭에도 나오지 않는다**(존재를 노출하면 안 됨).
- `mutex` 로 잠긴 퀘스트도 표시하지 않는다([BP-23](23_quest_model.md) §23.10.4).
- 탭 이동은 ←→ / A D. 순환(진행 중 ↔ 마친 일 ↔ 못 마친 일 ↔ 진행 중).

### 41.3.2 목록 화면 — 행 배분 (19행)

| 행 | 내용 | 비고 |
|---|---|---|
| 1 | 탭 행 + 우측 카운트 `(3/12)` | 현재 커서 / 이 탭의 총 건수 |
| 2 | 구분선 `─` × 60 | 반각 |
| 3 ~ 14 | **목록 항목 12행** | 초과 시 스크롤, `▲`/`▼` 인디케이터 |
| 15 | 구분선 | |
| 16 ~ 17 | 선택 항목 **미리보기 2행** (현재 단계 저널) | 커서 이동에 즉시 반응 — **런타임 재측정 없이** 미리 구워 둔 값을 바꿔 끼운다(R-41-14a) |
| 18 | (빈 행) | |
| 19 | 힌트 푸터 | |

### 41.3.3 상세 화면 — 행 배분 (19행)

| 행 | 내용 | `active` | `completed` | `failed` |
|---|---|---|---|---|
| 1 | 퀘스트 제목 | 흰색 | 회색 | 어두운 회색 |
| 2 | 구분선 | ✔ | ✔ | ✔ |
| 3 ~ 4 | 요약(`<questId>.summary`) 최대 2행 | ✔ | ✔ | ✔ |
| 5 | (빈) | | | |
| 6 | 현재 단계 제목 `> {stageTitle}` | ✔ | — | — |
| 7 ~ 9 | 단계 저널(`<questId>.<stageId>.journal`) 최대 3행 | ✔ | — | — |
| 6 ~ 7 | (완료/실패) 마무리 문구 `<questId>.done` / `.failed` 최대 2행 | — | ✔ | ✔ |
| 10 | (빈) | ✔ | | |
| 11 | 소제목 `해야 할 일` | ✔ | — | — |
| 12 ~ 17 | **목표 체크리스트 최대 6행** | ✔ | — | — |
| 8 ~ 17 | (완료/실패) 지나온 기록 최대 10행 — `WorldState.journal` 을 `atStep` 오름차순 | — | ✔ | ✔ |
| 18 | (빈) | ✔ | ✔ | ✔ |
| 19 | 힌트 푸터 | ✔ | ✔ | ✔ |

### 41.3.4 각 화면의 필드와 최대 표시 개수 (확정)

| 화면 | 필드 | 출처 | 최대 개수 | 초과 시 |
|---|---|---|---|---|
| 목록 | 퀘스트 제목 | `<questId>.title` | 1행 | 잘라내기(`…`) |
| 목록 | 단계 진행 `(2/4)` | `stage.index+1` / `quest.stages.length` | 1개 | — |
| 목록 | 항목 수 | `WorldState.quests` 필터 | **12행 표시 / 총 999건** | 스크롤 |
| 목록 | 미리보기 | 현재 단계 저널 첫 2행 | 2행 | 잘라내기 |
| 상세 | 요약 | `<questId>.summary` | 2행 | Hard 실패(빌드, §41.4.5) |
| 상세 | 단계 저널 | `<questId>.<stageId>.journal` | 3행 | Hard 실패 |
| 상세 | 목표 | `stage.objectives` 중 `hidden != true` | **6행** | 7번째부터 `… 외 {n}가지` 1행으로 접음 |
| 상세(완료/실패) | 지나온 기록 | `WorldState.journal` (questId 필터) | 10행 | 최근 10건만, 오름차순 |

> **목표 6행 근거**: `Stage.objectives` 는 스키마상 개수 제한이 없으나, 한 단계에 7개 이상의 목표를 두는 것은
> [BP-23](23_quest_model.md) §23.1.2 의 "표현력을 깎아 검증 가능성을 산다" 정신에 어긋난다.
> → 린트 **`JV-01`(Soft)**: 한 stage 의 non-hidden objective > 6 이면 경고.

### 41.3.5 정렬 순서 (결정론 필수)

| 탭 | 정렬 키 |
|---|---|
| 진행 중 | `QuestProgress.updatedStep` **내림차순** (최근 움직인 것이 위) → 동률이면 `questId` 사전순 |
| 마친 일 | `updatedStep` 내림차순 → 동률이면 `questId` 사전순 |
| 못 마친 일 | 동상 |

`updatedStep` 은 벽시계가 아니라 `WorldState.step` 스냅샷이므로(D-08a) 같은 세이브는 항상 같은 순서를 낳는다.

---

## 41.4 텍스트 예산 — 저널용 길이 상한 확정

### 41.4.1 기준 계산

```
저널 창 내부 폭      = 512 − 2×2(테두리) − 2×8(패딩) = 492px
한글 1자(전각) 폭    = 16.0px            ← BP-24 §24.5.4
반각 1칸 폭          = 8.0px             ← 동상
한 행 = 492 ÷ 16 = 30.75  →  한글 30자 = 반각 60칸  (12px 잉여)
```

**모든 목업과 상한은 반각 60칸 기준으로 계산한다.**

### 41.4.2 목록 행 예산

```
[ > ][공백][제목 ……………………………………………][공백][(2/4)]
  1     1              52                   1     5      = 60칸
```

| 요소 | 반각 칸 | 한글 환산 |
|---|---|---|
| 커서 `>` + 공백 | 2 | 1자 |
| 진행 `(2/4)` + 앞 공백 | 6 | 3자 |
| **제목 예산** | **52** | **26자** |

| 대상 | **권고** | **경고(Soft)** | **에러(Hard)** | 근거 |
|---|---|---|---|---|
| 퀘스트 제목 (`<questId>.title`) | **≤ 18자** | 19 ~ 22자 | **> 22자** | 26자 예산에서 4자 여유. 단계 수가 두 자리(`(10/12)` = 7칸)가 되면 1자를 더 먹으므로 |

**검증**: [BP-23](23_quest_model.md) §23.2.2 의 예시 `quest.gen_ep1.jailed_companion` 의 한국어 제목을
"수감된 동료" (6자) 로 잡으면 여유가 크다. 자동 생성 제목이 길어지는 사고를 막기 위해 상한을 둔다.

### 41.4.3 목표 행 예산

```
[  ][(선택) ][[12/20]][공백][목표 문구 ……………………………]
  2     7        7       1              43            = 60칸
```

| 요소 | 반각 칸 | 최악 조건 |
|---|---|---|
| 들여쓰기 | 2 | 항상 |
| `(선택)` + 공백 | 7 | `optional: true` 일 때만 |
| 체크 `[12/20]` | 7 | `counter.target` 이 두 자리일 때. 보통은 `[ ]`/`[v]` 3칸, `[3/5]` 5칸 |
| 뒤 공백 | 1 | |
| **문구 예산** | **43** | **21.5자** |

| 대상 | **권고** | **경고** | **에러(Hard)** | 근거 |
|---|---|---|---|---|
| 목표 문구 (`<questId>.<stageId>.<objectiveId>.label`) | **≤ 16자** | 17 ~ 21자 | **> 21자** | 최악 접두 17칸을 뺀 43칸 = 21.5자. 접힘 금지(1행 강제) |

**자동 생성 템플릿 실측 검증** ([BP-23](23_quest_model.md) §23.10.3):

| kind | 예시 문구 | 한글 환산 | 판정 |
|---|---|---|---|
| `talk_to` | `로드안과 이야기한다` | 10자 | ✅ |
| `reach` | `로어성 (44,16) 부근으로 간다` | 한글 11 + 반각 9(=4.5) ≈ 15.5자 | ✅ |
| `acquire` | `문지기의 인장 1개를 구한다` | 14자 | ✅ |
| `deliver` | `로어 에일을 문지기에게 건넨다` | 15자 | ✅ |
| `defeat` | `Black Knight 3기를 쓰러뜨린다` | 반각 12(=6) + 한글 10 = 16자 | ✅ 경계 |
| `survive` | `40보 동안 버틴다` | 반각 2(=1) + 한글 8 = 9자 | ✅ |

> `defeat` 가 16자로 딱 걸린다. 적 이름이 `Neo-Necromancer`(15반각 = 7.5자) 면 `Neo-Necromancer 3기를 쓰러뜨린다` = 17.5자 → **경고 구간**.
> → **린트 `JV-02`(Soft)**: 자동 생성 문구가 17자를 넘으면 `label` 을 명시하라고 경고한다.

### 41.4.4 그 밖의 상한

| 대상 | 행 예산 | **권고** | **경고** | **에러(Hard)** | 근거 |
|---|---|---|---|---|---|
| 요약 (`.summary`) | 2행 | ≤ 40자 | 41 ~ 56자 | **> 56자** | 2 × 30 = 60자에서 4자 여유 |
| 단계 저널 (`.<stageId>.journal`) | 3행 | ≤ 60자 | 61 ~ 84자 | **> 84자** | 3 × 30 = 90자에서 6자 여유 |
| 단계 제목 (`.<stageId>.title`) | 1행 | ≤ 20자 | 21 ~ 26자 | **> 26자** | `> ` 접두 2칸 제외 58칸 = 29자, 3자 여유 |
| 완료 문구 (`.done`) | 2행 | ≤ 40자 | 41 ~ 56자 | **> 56자** | 요약과 동일 |
| 실패 문구 (`.failed`) | 2행 | ≤ 40자 | 41 ~ 56자 | **> 56자** | 동상 |
| 추적 바 1줄 (§41.6) | 1행 | ≤ 16자 | 17 ~ 20자 | **> 20자** | §41.6.4 계산 |
| **공백 없는 연속 구간(어절)** | — | ≤ 20자 | 21 ~ 29자 | **≥ 30자** | [BP-24](24_dialogue_model.md) §24.5.5 를 **그대로 승계**. 저널 폭(492)이 콘솔(480)보다 넓으므로 안전측 |

**"한글 환산 길이" 의 정의는 [BP-24](24_dialogue_model.md) §24.5.5 의 `weight(ch)` 계산을 그대로 쓴다.** 재정의하지 않는다.

### 41.4.5 초과 시 빌드 동작

| 위반 | ID | 등급 | 동작 |
|---|---|---|---|
| 제목 > 22자 | `JV-03` | **Hard** | `{error, hint}` — "임무 이름을 18자 안으로 줄이세요" + stringKey |
| 목표 문구 > 21자 | `JV-04` | **Hard** | "목표 문구는 한 행에 들어가야 합니다" |
| 요약 / `.done` / `.failed` > 56자 | `JV-05` | **Hard** | "2행을 넘습니다" |
| 단계 저널 > 84자 | `JV-06` | **Hard** | "3행을 넘습니다. 단계를 나누세요" |
| 단계 제목 > 26자 | `JV-07` | **Hard** | — |
| 어절 ≥ 30자 | `DV-08` | **Hard** | BP-24 규칙 재사용 (중복 정의 아님) |
| non-hidden objective > 6 | `JV-01` | Soft | 경고 |
| 자동 생성 문구 > 17자 | `JV-02` | Soft | "`label` 을 명시하세요" |

빌드는 [BP-24](24_dialogue_model.md) §24.5.6 과 동일하게 **wrapped 행 수를 미리 계산해 번들에 굽는다**(`_wrapJournal`).
런타임은 `TextPainter` 재측정을 하지 않는다 — 결정론 + 성능.

**목록 미리보기 2행은 어느 단계의 산물인가** — §41.3.2 가 "커서 이동에 즉시 반응" 이라 했으므로 답이 필요하다.

| 안 | 동작 | 문제 |
|---|---|---|
| 런타임이 자른다 | 커서가 움직일 때마다 현재 단계 저널을 2행으로 잘라 `…` 을 붙인다 | **`TextPainter` 재측정이 필요**하고, 위 "런타임은 재측정하지 않는다" 와 정면 충돌한다 |
| "첫 2행" 을 그대로 쓴다 | 빌드가 구운 3행 중 앞 2행만 그린다 | 3행짜리 저널의 2행에서 문장이 어중간하게 끊긴다. `…` 을 붙일 자리를 런타임이 다시 계산해야 한다 |
| **빌드가 미리 잘라 굽는다 (채택)** | `_wrapJournal` 이 **본문용 3행 배열**과 **미리보기용 2행 배열**을 **둘 다** 산출한다 | 번들이 약간 커진다(단계당 2행 문자열) |

- **R-41-14a** `_wrapJournal` 은 **단계마다 두 산출물**을 굽는다 — `journalLines`(최대 3행, 상세 화면용)와
  `previewLines`(정확히 2행, 목록 화면용, 2행을 넘치면 마지막 행 끝에 `…`).
  런타임의 커서 이동은 **미리 구워진 `previewLines` 를 바꿔 끼우는 것**이므로 재측정이 없고 결정론이 유지된다.
- **R-41-14b** `previewLines` 는 `journalLines` 의 **앞 2행이 아니다.** 2행 예산(60칸)에 맞춰 **다시 감싼 결과**이며,
  잘림 표시 `…`(1칸)이 예산 안에 들어간다. 두 산출물의 첫 행이 다를 수 있고, **그것이 정상이다.**
- **R-41-14c** DTO 는 `JournalPreviewRow { questId, lines }`(§41.10.2)로 받는다. 빌드 산출물이므로
  `domain/content/journal_rows.dart` 에 두고, 이 계약을 [BP-35](35_ci_and_build.md) 가 구현한다(§41.11.2).

---

## 41.5 키 조작

### 41.5.1 진입 경로

```
맵 모드에서 Space/Esc/Q
  → HDMenuFlows.showMainMenu()          [beginNarrative() 안]
     → showWindowMenu(9항목, x:200)
        → selected == 8
           → HDMenuFlows.showQuestJournal()
              → HDWindowManager().addWindow(HDJournalWindow(rows))
              → await window.result       (닫힘까지 대기)
              → HDWindowManager().removeWindow(window)
     → endNarrative()
```

- `showMainMenu` 이 이미 `beginNarrative()`(`menu_flows.dart:48`) / `endNarrative()`(`:80`) 로 감싸고 있으므로,
  저널이 열리는 동안 진행 로그가 오버레이에 가려진 상태가 유지된다 — 별도 처리 불필요.
- 창이 스택에 올라간 순간 `HDGameMain.currentInputMode` 가 `window` 를 반환한다(`hd_game_main.dart:160`).

**반대 심문: 저널 화면이 콘솔(대화) 영역을 점유하면 진행 중이던 대화는 어떻게 되는가**

위 "별도 처리 불필요" 는 **3단 추론을 독자에게 맡긴 서술**이었다. 불변식으로 못박는다.

> **R-41-9a 불변식**: **대화가 진행 중일 때는 저널을 열 수 없다.** 소지품도 같다([BP-42 R-42-37b](42_item_and_inventory.md)).
> 따라서 "가려진 대화" 라는 상태가 애초에 만들어지지 않는다.

| 단 | 주장 | 실측 |
|---|---|---|
| ① | 저널은 **메인 메뉴에서만** 열린다 | §41.5.1 의 진입 경로가 유일하다. 다른 진입점을 만들지 않는다(R-41-9b) |
| ② | 메인 메뉴는 **`HDInputMode.map` 에서만** 열린다 | Space/Esc/Q 를 메뉴로 해석하는 것은 `input_dispatcher.dart:118` 의 `_handleMap` **하나뿐** |
| ③ | 대화 중에는 ②에 도달하지 못한다 | `currentInputMode` 가 `window > menu > dialogue > map` 우선순위(`hd_game_main.dart:159-164`)이고, 대화 대기 중에는 `isWaitingForKey` 로 `dialogue` 가 잡힌다 |

- **그럼에도 저널 창이 대화 패널을 덮는 것 자체는 사실이다.** 창은 (144,40)~(656,440) 이고
  대화 패널은 (288,0)~(800,320) 이므로 **가로 288~656 · 세로 40~320 이 겹친다** — 대화 패널 면적의 대부분이다.
  가려지는 것은 **진행 중인 대화가 아니라 이미 `beginNarrative()` 로 닫힌 대화의 잔상**이며,
  닫을 때 `endNarrative()` 가 원래 화면을 되돌린다.
- **R-41-9b** 저널의 진입점을 **메인 메뉴 8번 하나로 고정**한다. 맵 모드 전용 단축키(J 키 등)를 만들지 않는다 —
  만드는 순간 R-41-9a 의 ②단이 깨지고, [BP-40 §40.1.4](40_gameplay_changes.md) 의 "신규 전역 키 0" 예산도 깨진다.
- **R-41-9c** 이 불변식은 **티어 0 의 비동기 대화 그래프가 들어오면 깨질 수 있다.**
  "대화 중에 임무를 확인한다" 를 원하게 되는 순간이 그 지점이며, 그때는 `beginNarrative` 중첩 규약이 선행이다.
  본 장은 그 문을 열지 않고, 회귀 1건을 §41.10.7 에 추가한다.

### 41.5.2 새 입력 모드가 필요한가 — **아니오**

```dart
// hadar2026_app/lib/hd_game_main.dart:159
HDInputMode get currentInputMode {
  if (HDWindowManager().windows.isNotEmpty) return HDInputMode.window;
  if (activeMenu != null) return HDInputMode.menu;
  if (isWaitingForKey) return HDInputMode.dialogue;
  return HDInputMode.map;
}
```

| 질문 | 답 |
|---|---|
| 저널 창이 스택에 올라가는가? | 예 — `HDWindowManager().addWindow` |
| 그러면 모드는? | `HDInputMode.window` (최우선) |
| `_handleWindow` 가 무엇을 하는가? | `HDWindowKeyDispatcher().handleInput(event)` 위임 → 실패 시 Esc/Q 로 최상단 숨김 → **나머지 키 전부 소비** (`input_dispatcher.dart`) |
| 새 모드가 필요한가? | **아니오.** `HDInputMode` 는 **4개 그대로** |

> **R-41-9 확정**: `enum HDInputMode { map, dialogue, menu, window }` 는 변경하지 않는다.

### 41.5.3 `HDWindowKeyDispatcher` 에 추가할 분기

```dart
// hadar2026_app/lib/presentation/input/window_key_dispatcher.dart:35  (현행)
bool _dispatch(HDWindow window, dynamic event) {
  if (window is HDMessageWindow) return _handleMessage(window, event);
  if (window is HDMagicSelectionWindow) return _handleMagic(window, event);
  if (window is HDSelectionWindow) return _handleSelection(window, event);
  return false;
}
```

**변경 후 (분기 2개 추가)**

| 순서 | 타입 | 핸들러 | 신규 |
|---|---|---|---|
| 1 | `HDMessageWindow` | `_handleMessage` | |
| 2 | **`HDJournalWindow`** | **`_handleJournal`** | ★ [BP-41](41_journal_ui_spec.md) |
| 3 | **`HDInventoryWindow`** | **`_handleInventory`** | ★ [BP-42](42_item_and_inventory.md) §5 |
| 4 | `HDMagicSelectionWindow` | `_handleMagic` | |
| 5 | `HDSelectionWindow` | `_handleSelection` | |

- 신규 두 클래스는 `HDWindow` 를 **직접** 상속한다(`HDSelectionWindow` 를 상속하지 않는다).
  이유: `HDSelectionWindow` 의 `enabledCount`/`displayStartIndex` 시맨틱(1-based, 제목 행 포함)이 탭 구조와 맞지 않는다.
  상속하면 type-switch 순서에 숨은 의존이 생긴다.
- `HDWindow` 는 `domain/window/game_window.dart` 의 `ChangeNotifier` 이므로 `notifyListeners()` 로 재그림을 유발한다.

### 41.5.4 키 표 (`docs/key_input_policy.md` 준수)

| 키 | 목록 화면 | 상세 화면 | 정책상 근거 |
|---|---|---|---|
| ↑ / W | 커서 위 (순환) | 스크롤 위 (목표 6행 초과 시) | 기존 `_handleSelection` 과 동일 |
| ↓ / S | 커서 아래 (순환) | 스크롤 아래 | 동상 |
| ← / A | **이전 탭** | (없음) | 선택 창에서 미사용이던 어휘. 신규 키 아님 |
| → / D | **다음 탭** | (없음) | 동상 |
| Enter / E | **상세 열기** | **눈여겨 봄 지정/해제** (§41.6) | 확인 = "현재 창의 동작 확정" |
| Space | 상세 열기 | 눈여겨 봄 지정/해제 | 기존 창들이 Space 를 확인으로 취급(`_handleSelection`) |
| Esc / Q | **창 닫기** | **목록으로 복귀** | "창 닫기 (Cancel)" / "상위 단계로" |

**주의 — Space 의 이중 의미**: 맵 모드에서 Space 는 메인 메뉴 열기지만, 창 모드에서는 확인이다.
이는 기존 `_handleSelection` 이 이미 그러하므로 **새로 생기는 비일관성이 아니다**.

**깊이 검증**

```
맵 → 메인 메뉴(1) → 저널 목록(2) → 저널 상세(3)
```
최대 깊이 3. 현행 최대 깊이 4(`게임 선택 상황 → 순서 정렬 → 기준 → 대상`)보다 얕다. ✅

### 41.5.5 메인 메뉴 창 높이 확장 (BP-40 R-40-13 의 상세)

메뉴가 9항목이 되면 현행 공식으로는 6행에서 잘린다.

```dart
// 현행 — domain/window/selection_window_data.dart
final int maxVisibleItems = 6;
int displayCount = math.min(this.enabledCount, maxVisibleItems);
h = 60 + (displayCount * 34);
```

**변경안**

```dart
final int maxVisibleItems;          // 생성자 인자, 기본 6
HDSelectionWindow({
  …,
  int maxVisible = 6,
}) : maxVisibleItems = maxVisible, … {
  int displayCount = math.min(this.enabledCount, maxVisibleItems);
  h = 60 + (displayCount * 34);
}
```

| 호출처 | `maxVisible` | 결과 높이 | 하단 y | 판정 |
|---|---|---|---|---|
| 메인 메뉴 (`menu_flows.dart` `showMainMenu`) | **9** | `60 + 9×34 = 366` | 100 + 366 = **466** | ✅ ≤ 480 |
| `게임 선택 상황` (6항목) | 기본 6 | `60 + 6×34 = 264` | 364 | ✅ |
| 그 밖의 전부 | 기본 6 | 현행과 동일 | | ✅ 무변경 |

- `UiHost.showWindowMenu` 시그니처에 `int maxVisible = 6` 을 **추가**한다. 기존 호출은 전부 기본값으로 동작 → 무변경.
  ([BP-40](40_gameplay_changes.md) R-40-10 의 "신규 `UiHost` 메서드 0개" 는 지켜진다 — 메서드가 아니라 **선택 인자** 추가)
- 세로 여백: y=100, h=366 → 상 100 / 하 14. 빠듯하므로 **메인 메뉴만 `y: 70`** 으로 내린다(70+366 = 436, 상하 여백 70/44). → **R-41-10**

---

## 41.6 추적(tracking) 표시

### 41.6.1 제약

| 제약 | 근거 |
|---|---|
| 맵 뷰포트(288×320)에 **0px** 추가 | [BP-40](40_gameplay_changes.md) R-40-17, §40.6.2 |
| 상태 패널(288×160)에 **0px** 추가 | 6슬롯 그리드가 이미 `22px × 6 + 헤더` 로 꽉 참(`status_panel.dart` `Container(height: 22)`) |
| 대화 패널은 대화 전용 | 오버레이가 자주 덮으므로 상시 정보에 부적합 |
| 기본 상태에서 화면이 변경 전과 **동일** | T-가역의 시각 버전 |

### 41.6.2 3안

| 안 | 위치 | 폭 | 평가 |
|---|---|---|---|
| **가** 맵 뷰포트 하단 오버레이 1줄 | (0, 296)~(288, 320) | 288 − 8 = 280px → 16pt 로 **17자** | ❌ 맵 0px 원칙 위반. 17자는 목표 문구(16자 권고)를 겨우 담아 진행률조차 못 붙임 |
| **나** 상태 패널 한 칸 전용 | (0,320) 안 | 288 → 이름열 108px = **6자** | ❌ 6자로는 아무것도 못 쓴다. 6슬롯 그리드 파괴 |
| **다** 진행 로그 패널 상단 고정 1줄 | **(288, 320)~(800, 340)** | 512 − 32 = 480px → **30자** | ✅ 폭 충분. 의미상 "지금 진행 중인 일" 레인과 일치 |

### 41.6.3 권고안 확정 — **다안: `HDTrackerBar`**

| 항목 | 값 |
|---|---|
| 위치 | 진행 패널(`HDDescriptionPanel`, `input_panel.dart`) **상단 고정** |
| 크기 | **512 × 24** (좌상단 (288, 320)) — 20px 은 상하 여백 0.8px 뿐이라 §41.6.4 에서 24 로 정정(R-41-11b) |
| 표시 조건 | 플레이어가 저널 상세에서 **명시적으로 "눈여겨 봄" 을 지정한 퀘스트가 있을 때만** |
| 미지정 시 | 높이 **0px** — `if (tracked == null) return const SizedBox.shrink();` → 화면이 변경 전과 완전히 동일 |
| 대상 개수 | **1건** (Q-40-5 를 이 장에서 1건으로 확정 → R-41-11) |
| 자동 해제 | 그 퀘스트가 `completed` / `failed` 가 되는 순간 |
| 세이브 | `WorldState.vars["var.core.ui.tracked_quest_index"]` 가 아니라 **저장하지 않는다** (UI 선호이지 월드 상태가 아님). 재시작하면 해제 → **Q-41-3** |

**진행 패널 잔여 공간 영향**

| | 변경 전 | 추적 바 표시 중 |
|---|---|---|
| 패널 높이 | 160 | 160 |
| 추적 바 | 0 | **24** |
| 로그 영역 | 144 (패딩 제외) | **120** (= 160 − 24 − 2×8) |
| 표시 행 수 | 7.5행 | **6.25행** (120 ÷ 19.2) |

1행 남짓 줄어든다. 진행 로그는 스크롤 가능하고 200줄 버퍼를 유지하므로 정보 손실은 없다.

### 41.6.4 추적 바의 내용과 길이 예산

```
폭 = 512 − 2×16(패딩) = 480px  →  한글 30자 / 반각 60칸

[눈여겨 봄 ][· ][목표 문구 ……………………………………………][ (2/3)]
     11      3                   40                      6      = 60칸  (여유 0)
```

| 요소 | 반각 칸 | 비고 |
|---|---|---|
| `눈여겨 봄` (5자 = 10칸) + 공백 1 | **11** | `@E` 노랑 |
| `·` (전각 2칸) + 공백 1 | **3** | 구분자 |
| **목표 문구 예산** | **40칸 = 20자** | 가변 |
| 앞 공백 1 + 진행 `(2/3)` 5칸 | **6** | `counter.target > 1` 일 때만 |
| **합계** | **60** | = 480px |

> **예산 불일치 정정**: 초판의 ASCII 도해는 `10+2+1+37+1+5 = 56칸(여유 4)` 이었고 바로 아래 표는 `11+3+6+40 = 60칸` 이었다.
> 두 계산이 4칸 어긋나고 문구 예산도 37 vs 40 으로 달랐다. **표 쪽(60/40/20자)으로 통일했다** —
> 그쪽이 §41.4.4 의 "추적 바 1줄 Hard > 20자" 와 정합하기 때문이다.
> 도해를 따랐다면 Hard 상한이 18자여야 했고, 이 값은 린트 규칙 값이므로 어긋난 채 둘 수 없다.

- **JV-08** 추적 바 목표 문구: 권고 ≤ **16자** / 경고 **17~20자** / **Hard > 20자**(= 40칸).
  §41.4.4 의 값과 동일하며, 예산 총합 60칸에서 유도된다.
- **R-41-11a** `counter.target <= 1` 이면 `(2/3)` 6칸이 비므로 문구가 46칸(23자)까지 들어갈 수 있다.
  **그래도 상한은 20자로 고정한다** — 같은 목표 문구가 카운터 유무에 따라 다르게 잘리면
  빌드 시점의 길이 검사(§41.4.5)가 두 값을 가져야 하고, 저작자는 어느 쪽이 적용될지 모른다.
  남는 6칸은 **여백으로 둔다.**

| 대상 | 권고 | 경고 | Hard |
|---|---|---|---|
| 추적 바에 표시되는 목표 문구 | ≤ 16자 | 17 ~ 20자 | > 20자 (§41.4.4 와 동일 값 · JV-08) |

**바 높이 20px 의 상하 여백** — 1행이 19.2px 이므로 남는 것은 **0.8px** 이고, 좌우 패딩 16 은 전제하면서
상하는 사실상 0 이다. 같은 패널의 `ListView` 는 `vertical: 8` 패딩을 갖고 있어 **시각적으로 어긋난다.**

| 안 | 바 높이 | 로그 영역 | 표시 행 수 | 판정 |
|---|---|---|---|---|
| 20px (초판) | 20 | 124 | 6.45행 | 상하 여백 0.8px — 글자가 테두리에 붙는다 |
| **24px (채택)** | **24** | **120** | **6.25행** | 상하 각 2.4px. `§41.6.3` 의 표를 이 값으로 갱신한다 |
| 28px | 28 | 116 | 6.04행 | 여백은 넉넉하나 로그가 6행 아래로 내려간다 |

- **R-41-11b** 추적 바 높이는 **24px** 로 확정한다(`512 × 24`, 좌상단 (288, 320)).
  로그 영역은 160 − 24 − 2×8 = **120px** → 120 ÷ 19.2 = **6.25행**. 폭 예산(60칸)은 영향받지 않는다.

**무엇을 표시하는가**: 추적 퀘스트의 **현재 단계에서 미완료인 첫 non-hidden 목표** 하나.
전부 완료면 `{stageTitle} — 마무리` 를 표시한다.

### 41.6.5 목업

```
                                진행 패널 (288,320)-(800,480)
 ┌──────────────────────────────────────────────────────────┐ ← y=320
 │@E눈여겨 봄@@ · 문지기의 인장 1개를 구한다        (0/1)      │  24px  HDTrackerBar
 ├──────────────────────────────────────────────────────────┤ ← y=344
 │ 일행이 잠시 쉬었다.                                       │
 │ [임무] 수감된 동료 — 시작                                 │
 │ 늪에 발이 빠졌다.                                         │  120px HDDescriptionPanel
 │ [임무] 문지기의 인장 1개를 구한다 (0/1)                    │  (6.25행)
 │ 일행은 상자 속에서 약간의 금을 발견했다.                    │
 │ ▂▂▂▂▂                                                    │
 └──────────────────────────────────────────────────────────┘ ← y=480
```

---

## 41.7 알림

### 41.7.1 원칙

| 원칙 | 근거 |
|---|---|
| 새 알림 위젯을 만들지 않는다 | [BP-40](40_gameplay_changes.md) F-10, R-40-18 |
| `UiHost.addLog(msg, isDialogue: false)` 만 쓴다 | [BP-23](23_quest_model.md) §23.10.5 |
| 팝업·배너·효과음·화면 효과 없음 | [BP-40](40_gameplay_changes.md) §40.6.4 |
| 배치당 3줄 상한 | [BP-23](23_quest_model.md) §23.10.5 |

### 41.7.2 문구와 색상 (BP-23 §23.10.5 를 색상까지 확정)

| 사건 | 문구 | 색상 태그 | 줄 |
|---|---|---|---|
| 퀘스트 시작 | `@E[임무]@@ {title} — 시작` | `@E` 노랑 | 1 |
| 단계 전이 | `@E[임무]@@ {title} — {stageTitle}` | `@E` | 1 |
| 목표 진행(`target > 1`) | `@E[임무]@@ {label} ({c}/{t})` | `@E` | 1 |
| 목표 완료(`target == 1`) | `@E[임무]@@ {label} — 마침` | `@E` | 1 |
| 퀘스트 완료 | `@A[임무]@@ {title} — 완료` + 사례 요약 1줄 | `@A` 초록 | 2 |
| 퀘스트 실패 | `@C[임무]@@ {title} — 실패` | `@C` 빨강 | 1 |
| 배치 3줄 초과 | `@E[임무]@@ 외 {n}건 갱신` | `@E` | 1 |

- 사례 요약 예: `사례로 황금 250과 회복약 2개를 받았다.`
- 접두 `[임무]` 는 **고정 문자열**이다. `[퀘스트]`, `[QUEST]` 금지([BP-40](40_gameplay_changes.md) R-40-5).

### 41.7.3 오버레이 중 알림의 지연 (flush 규약)

문제: 대화 중(`beginNarrative()` 활성)에는 진행 패널이 아니라 대화 패널이 화면을 지배한다.

```dart
// hadar2026_app/lib/presentation/host/flutter_ui_host.dart
HDConsoleViewMode get viewMode =>
    (_narrativeActive || activeMenu != null || consoleLog.events.isNotEmpty)
    ? HDConsoleViewMode.overlay
    : HDConsoleViewMode.progress;
```

진행 로그는 **덮이지 않는다**(별도 패널이므로 계속 보인다). 하지만 대화 중에 퀘스트 알림이 끼어들면
플레이어의 시선이 분산되고, 대화가 끝난 뒤 알림이 스크롤 밖으로 밀릴 수 있다.

**확정 규약 R-41-12**

| 상황 | 동작 |
|---|---|
| `beginNarrative()` 활성 중 발생한 알림 | **큐에 쌓는다.** 즉시 출력하지 않는다 |
| `endNarrative()` 직후 | 큐를 **발생 순서 그대로** flush. 3줄 상한은 flush 시점에 적용 |
| narrative 밖(이동 중 등) | 즉시 출력 |
| 큐 상한 | 16건. 초과 시 오래된 것부터 폐기하고 `외 {n}건 갱신` 으로 표기 |

이 큐는 `application/content/` 에 두고, `UiHost` 포트에는 아무것도 추가하지 않는다.

### 41.7.4 하지 않는 것

| 제외 | 이유 |
|---|---|
| 퀘스트 시작 시 저널 자동 열기 | 플레이어의 흐름을 끊는다. 대신 진행 로그 1줄 |
| 알림 클릭 → 저널 이동 | 마우스 어휘가 원작에 없다 |
| 미확인 알림 배지(`!`) | 상시 HUD 금지(§41.6.1) |

---

## 41.8 ASCII 목업

> 목업은 **반각 60칸** = 한글 30자 = 492px 기준이다. 창 테두리(`│`)는 픽셀상 2px 테두리 + 8px 패딩에 대응한다.
> 각 행은 19.2px, 총 19행 = 364.8px, 창 내부 380px (잉여 15.2px 하단 여백).

### 41.8.1 목록 화면 — 진행 중 탭

```
        (144,40)                                        (656,40)
           ┌────────────────────────────────────────────────────────────┐
행1  19.2px│@F[진행 중]@@  마친 일   못 마친 일                  (2/5)    │
행2        │────────────────────────────────────────────────────────────│
행3        │  로어성의 소문                                      (1/2)    │
행4        │@F> 수감된 동료@@                                    (2/4)    │
행5        │  잃어버린 학자                                      (1/3)    │
행6        │  메너스의 금맥                                      (1/1)    │
행7        │  무기고의 약속                                      (3/3)    │
행8        │                                                            │
행9        │                                                            │
행10       │                                                            │
행11       │                                                            │
행12       │                                                            │
행13       │                                                            │
행14       │                                                            │
행15       │────────────────────────────────────────────────────────────│
행16       │@7수감소 병사에게서 인장을 얻어야 안으로 들어갈 수 있다.@@       │
행17       │@7문지기는 아직 이쪽을 의심하고 있다.@@                        │
행18       │                                                            │
행19       │@7↑↓ 고르기  ←→ 갈래  Enter 자세히  Esc 닫기@@                │
           └────────────────────────────────────────────────────────────┘
        (144,440)                                       (656,440)
```

- 커서 행은 `@F`(흰색) + `> ` 접두. 나머지는 기본 회색.
- 우측 `(2/4)` = 현재 단계 인덱스 / 총 단계 수.
- 항목이 12개를 넘으면 행3~14 가 스크롤되고 우측 4px 에 `▲`/`▼` 가 뜬다(`window_view.dart` 규약 재사용).

### 41.8.2 목록 화면 — 마친 일 탭 (아카이브)

```
           ┌────────────────────────────────────────────────────────────┐
행1        │ 진행 중   @F[마친 일]@@   못 마친 일                (1/3)    │
행2        │────────────────────────────────────────────────────────────│
행3        │@F> 무기고의 약속@@                                          │
행4        │@7  로어성의 소문@@                                          │
행5        │@7  들쥐 소탕@@                                              │
행6        │                                                            │
 …         │                                                            │
행15       │────────────────────────────────────────────────────────────│
행16       │@7무기고에서 무기를 하나 받았다.@@                             │
행17       │                                                            │
행18       │                                                            │
행19       │@7↑↓ 고르기  ←→ 갈래  Enter 자세히  Esc 닫기@@                │
           └────────────────────────────────────────────────────────────┘
```

- 완료 항목은 단계 표시(`(n/m)`)를 붙이지 않는다.
- 완료는 회색(`@7`), 커서 행만 흰색.

### 41.8.3 상세 화면 — `active`

```
           ┌────────────────────────────────────────────────────────────┐
행1        │@F수감된 동료@@                                     @E눈여겨 봄@@│
행2        │────────────────────────────────────────────────────────────│
행3        │@7수감소에 갇힌 이가 황금의 방패의 행방을 안다고 한다.@@         │
행4        │@7그를 만나려면 문지기를 지나야 한다.@@                        │
행5        │                                                            │
행6        │> 인장을 구한다                                              │
행7        │@7수감소 병사는 인장을 지닌 자만 들여보낸다.@@                  │
행8        │@7병사에게 술을 사 주면 마음이 풀릴지도 모른다.@@               │
행9        │                                                            │
행10       │                                                            │
행11       │해야 할 일                                                   │
행12       │  [v] 술집 주인과 이야기한다                                  │
행13       │  [ ] 로어 에일을 문지기에게 건넨다                            │
행14       │  [0/1] 문지기의 인장 1개를 구한다                             │
행15       │  (선택) [ ] 병사의 사연을 듣는다                              │
행16       │                                                            │
행17       │                                                            │
행18       │                                                            │
행19       │@7↑↓ 넘기기  Enter 눈여겨 봄  Esc 뒤로@@                       │
           └────────────────────────────────────────────────────────────┘
```

- 행1 우측의 `@E눈여겨 봄@@` 은 **추적 지정 중**일 때만. 미지정이면 빈칸.
- `[v]` 완료 / `[ ]` 미완료(target=1) / `[0/1]` 카운터(target>1) — [BP-23](23_quest_model.md) §23.10.4 규칙 그대로.
- `(선택)` 은 `optional:true`. `hidden:true` 는 **완료돼도 나오지 않는다**.

### 41.8.4 상세 화면 — `completed`

```
           ┌────────────────────────────────────────────────────────────┐
행1        │@7무기고의 약속@@                                            │
행2        │────────────────────────────────────────────────────────────│
행3        │@7로드안이 무기고에서 무기 하나를 가져가도록 허락했다.@@         │
행4        │                                                            │
행5        │                                                            │
행6        │@7무기고에서 단검을 받아 나왔다.@@                             │
행7        │                                                            │
행8        │@7지나온 기록@@                                              │
행9        │@7  로드안을 만났다.@@                                        │
행10       │@7  무기고에 들어갔다.@@                                      │
행11       │@7  단검을 골랐다.@@                                          │
행12       │                                                            │
 …         │                                                            │
행19       │@7Esc 뒤로@@                                                 │
           └────────────────────────────────────────────────────────────┘
```

- 완료/실패 상세에는 **목표 체크리스트를 그리지 않는다**([BP-23](23_quest_model.md) §23.10.4).
- `지나온 기록` = `WorldState.journal` 을 questId 로 묶고 `atStep` 오름차순, 최근 10건.

### 41.8.5 빈 상태

```
           ┌────────────────────────────────────────────────────────────┐
행1        │@F[진행 중]@@  마친 일   못 마친 일                  (0/0)    │
행2        │────────────────────────────────────────────────────────────│
행3        │                                                            │
 …         │                                                            │
행9        │@7             아직 맡은 일이 없다.@@                         │
 …         │                                                            │
행19       │@7←→ 갈래  Esc 닫기@@                                        │
           └────────────────────────────────────────────────────────────┘
```

- 콘텐츠 팩이 아예 없을 때도 같은 화면을 쓴다. `ContentRuntime().isReady == false` 여도 창은 열리고
  "아직 맡은 일이 없다." 를 보여준다 — [BP-27](27_runtime_engine.md) §7.2 의 초안(로그 1줄 후 즉시 복귀)보다 일관적이다. → **R-41-13**

### 41.8.6 전체 화면 위의 창 위치

```
   0                288                                              800
 0 ┌─────────────────┬──────────────────────────────────────────────────┐
   │                 │                                                  │
   │   HDMapViewport │            HDDialogPanel (대화)                   │
   │    288 × 320    │              512 × 320                           │
40 │      ┌──────────┴──────────────────────────────────┐               │
   │      │(144,40)                                     │               │
   │      │        HDJournalWindow  512 × 400           │               │
   │      │        내부 492 × 380 = 19행                 │               │
320├──────┤                                             ├───────────────┤
   │ 상태  │                                             │  진행 로그      │
   │288×160│                                            │  512 × 160    │
440│      └─────────────────────────────────────────────┘               │
480└─────────────────┴──────────────────────────────────────────────────┘
```

창은 맵·대화·상태·진행 네 패널을 **부분적으로** 덮는다. 좌우 144px, 상하 40px 이 남아
"게임이 뒤에 계속 있다" 는 감각이 유지된다(C안이 잃는 것).

---

## 41.9 폰트·색상

### 41.9.1 폰트

| 항목 | 값 | 출처 |
|---|---|---|
| 글꼴 | **DungGeunMo** (앱 전역 `ThemeData.fontFamily`) | `main.dart` |
| 크기 | 16.0 | `HDConfig.consoleFontSize` — 저널도 동일 |
| 행높이 | 1.2 | `HDConfig.consoleLineHeight` |
| 한글 자폭 | 16.0px (전각 고정) | 도트 글꼴이므로 고정폭 가정이 성립 |
| 라틴 자폭 | ≈ 8.0px 평균 | [BP-24](24_dialogue_model.md) §24.5.4 |

**규범 R-41-14**: 저널은 **전용 폰트 크기를 쓰지 않는다.** 작게 해서 더 담고 싶은 유혹이 있지만,
도트 글꼴을 16 이외 크기로 렌더하면 픽셀 격자가 깨져 원작 감성이 무너진다.

### 41.9.2 색상 태그 (`hd_text_utils.dart` `colorTable` 실측)

| 태그 | 값 | 색 | 저널에서의 용도 |
|---|---|---|---|
| `@F` | `0xFFFFFFFF` | 흰색 | **커서 행**, 활성 퀘스트 제목, 현재 탭 |
| `@7` | `0xFF808080` | 회색 | 본문(요약·저널·힌트), **완료 퀘스트 제목** |
| `@8` | `0xFF404040` | 진회색 | **실패 퀘스트 제목** |
| `@E` | `0xFFFFFF00` | 노랑 | `[임무]` 접두, `눈여겨 봄` 배지 |
| `@A` | `0xFF00FF00` | 초록 | 완료 알림, `[v]` 체크 |
| `@C` | `0xFFFF0000` | 빨강 | 실패 알림 |
| `@B` | `0xFF00FFFF` | 시안 | **저널에서 사용 금지** — [BP-24](24_dialogue_model.md) §24.6.5 가 대화 헤더 전용으로 예약 |
| 그 외 | — | — | 미사용 |

- `@@` 로 반드시 닫는다(`DV-07d` Hard 재사용).
- 색상 태그는 **`strings/ko.json` 안에만** 존재한다. 저널 UI 코드가 문자열에 태그를 덧붙이지 않는다 —
  예외는 **UI 구조 요소**(커서 `@F`, 탭, 체크박스, `[임무]` 접두)로, 이것들은 콘텐츠가 아니라 크롬이다. → **R-41-15**
- 색상 태그는 폭 계산에 잡히지 않는다(`_parseToChunks` 가 렌더 시 제거). 하지만 **문자열 길이에는 포함**되므로
  §41.4 의 상한은 [BP-24](24_dialogue_model.md) §24.5.5 의 `weight(ch) = 0` 규칙으로 계산한다.

### 41.9.3 창 크롬

| 요소 | 값 | 출처 |
|---|---|---|
| 배경 | `Colors.black.withOpacity(0.8)` | `window_view.dart` |
| 테두리 | 흰색 2px, `BorderRadius.circular(4)` | 동상 |
| 패딩 | `EdgeInsets.all(8)` | 동상 |
| 스크롤 인디케이터 | `Icons.keyboard_arrow_up/down`, 노랑, 18px, 우측 4px | `_wrapWithScrollIndicators` |

**기존 창과 동일한 크롬을 쓴다.** 저널만 다른 테두리·모서리를 쓰면 "다른 게임에서 온 창" 처럼 보인다.

---

## 41.10 신규 위젯·클래스 목록

### 41.10.1 `domain/window/` (신규 1)

| 파일 | 타입 | 내용 | 계층 규칙 |
|---|---|---|---|
| `journal_window_data.dart` | `HDJournalWindow extends HDWindow` | 표시 상태만 보유: `tab`, `cursor`, `scrollTop`, `screen`(list/detail), `Completer<void> result`. **키 처리 없음**(`window_key_dispatcher` 소관) | `flutter/foundation` 만 import ✅ |
| 〃 | `enum HDJournalTab { active, completed, failed }` | | ✅ |
| 〃 | `enum HDJournalScreen { list, detail }` | | ✅ |

### 41.10.2 `domain/content/` (신규 1 — D-11 목록에 추가 제안)

| 파일 | 타입 | 내용 |
|---|---|---|
| `journal_rows.dart` | `JournalListRow { questId, title, stageIndex, stageCount, state }` | 순수 DTO |
| 〃 | `JournalDetailView { title, summaryLines, stageTitle, journalLines, objectives, historyLines, state }` | |
| 〃 | `JournalObjectiveRow { label, done, counter, target, optional }` | |
| 〃 | `JournalPreviewRow { questId, lines }` | 목록 미리보기 2행 — **빌드가 미리 잘라 굽는다**(R-41-14a) |

> **파일명 주의**: 초판은 이 DTO 파일을 `journal_view.dart` 로 불렀는데 §41.10.4 의 **위젯**도 같은 이름이었다.
> 계층 규칙상 문제는 없으나 IDE 탭·import 별칭에서 혼동이 잦으므로 DTO 쪽을 **`journal_rows.dart`** 로 확정한다.

> D-11 이 열거한 `domain/content/` 파일 목록에 없는 신규 파일이다. **결정을 바꾸는 것이 아니라 추가**이며,
> `condition.dart` / `quest.dart` 와 같은 규칙(파일 I/O·`UiHost` 무지)을 따른다. → **Q-41-1**

### 41.10.3 `application/content/` (신규 1)

| 파일 | 타입 | 내용 |
|---|---|---|
| `journal_presenter.dart` | `HDJournalPresenter` (싱글턴, `reset()` 지원) | `WorldState` + `ContentRepository` → `JournalListRow[]` / `JournalDetailView`. **정렬·필터·문구 자동 생성**([BP-23](23_quest_model.md) §23.10.3 템플릿) 담당 |
| 〃 | `String? trackedQuestId` | 추적 대상 1건 (§41.6.3) |
| 〃 | `List<String> pendingNotices` | 알림 큐 (§41.7.3) |

### 41.10.4 `presentation/panels/` (신규 2)

| 파일 | 위젯 | 내용 |
|---|---|---|
| `journal_view.dart` | `HDJournalView` | `HDJournalWindow` 를 그리는 위젯. 목록/상세 두 레이아웃. `window_view.dart` `_buildContent` 에서 분기 호출 |
| `tracker_bar.dart` | `HDTrackerBar` | **512×24** 추적 바(R-41-11b). `input_panel.dart` 의 `Column` 최상단에 삽입. `Padding(vertical: 2)` 로 1행 19.2px 을 감싼다 |

### 41.10.5 기존 파일 수정 (6곳)

| 파일 | 줄 | 변경 |
|---|---|---|
| `presentation/panels/window_view.dart` | `_buildContent` | `if (window is HDJournalWindow) return HDJournalView(window: window);` 분기 1개 |
| `presentation/input/window_key_dispatcher.dart` | `_dispatch` | `_handleJournal` 분기 1개 + 핸들러 메서드 |
| `presentation/panels/input_panel.dart` | `build` | `ListView` 를 `Column [ HDTrackerBar, Expanded(ListView) ]` 로 감쌈 |
| `domain/window/selection_window_data.dart` | 생성자 | `int maxVisible = 6` 인자 추가 (§41.5.5) |
| `application/ports/ui_host.dart` | `showWindowMenu` | 선택 인자 `int maxVisible = 6` 추가 |
| `application/menu_flows.dart` | `showMainMenu` | 항목 추가 + `showQuestJournal()` 신규 |

### 41.10.6 계층 규칙 검증

```bash
cd hadar2026_app
grep -rn "^import.*presentation\|^import.*hd_game_main" lib/application/ lib/domain/
grep -rn "package:flutter/material\|package:bonfire\|package:flame" lib/application/ lib/domain/
```

| 신규 파일 | 위치 | import 하는 것 | 통과 |
|---|---|---|---|
| `journal_window_data.dart` | `domain/window/` | `game_window.dart`(→ `flutter/foundation`) | ✅ |
| `journal_rows.dart` (DTO) | `domain/content/` | 없음 | ✅ |
| `journal_presenter.dart` | `application/content/` | `domain/content/`, `ports/` | ✅ |
| `journal_view.dart` (위젯) | `presentation/panels/` | `flutter/material` 허용 영역 | ✅ |
| `tracker_bar.dart` | `presentation/panels/` | 동상 | ✅ |

### 41.10.7 테스트 계획

| 테스트 | 위치 | 내용 |
|---|---|---|
| `journal_presenter_test.dart` | `test/application/content/` | 페이크 `WorldState` → 정렬 순서, 탭 필터, 자동 문구 생성. `HDHosts().bind(...)` 페이크 + `reset()` (선례: `test/application/map_navigation_test.dart`) |
| `journal_length_test.dart` | `test/domain/content/` | §41.4 의 상한 계산기(한글 환산 길이)가 경계값에서 맞는지 |
| `journal_key_test.dart` | `test/presentation/input/` | `HDWindowKeyDispatcher` 가 `HDJournalWindow` 를 `HDSelectionWindow` 보다 먼저 잡는지(타입 스위치 순서 회귀) |
| `journal_wrap_test.dart` | `test/presentation/` | 대표 문자열 20종의 실제 wrapped 행 수가 빌드 계산과 일치하는지 (위젯 테스트 — 현재 레포에 위젯 테스트가 없으므로 **첫 사례**) |
| `journal_gate_test.dart` | `test/presentation/input/` | **회귀 — 대화 대기 중(`isWaitingForKey == true`)에 Space/Esc/Q 를 넣어도 저널이 열리지 않는다**(R-41-9a). `input_dispatcher` 의 모드 우선순위가 바뀌면 이 테스트가 먼저 깨져야 한다 |
| `tracker_budget_test.dart` | `test/domain/content/` | 추적 바 예산 60칸 = 11 + 3 + 40 + 6 이 유지되는지, 목표 문구 21자가 Hard 로 잡히는지(JV-08) |

---

## 41.11 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 41.11.1 확정한 것

| ID | 확정 사항 |
|---|---|
| R-41-1 | `UI_SPEC.md` 의 3건 오류(U-1 상태 패널 크기, U-2 상호작용 키, U-3 패널 수)를 §41.1.1 표가 정정한다 |
| R-41-2~7 | 저널 요구사항 6개 |
| — | **권고안 B안 확정** — 전용 오버레이 창 `HDJournalWindow` |
| R-41-8 | 창 기하학 **(144, 40) 512 × 400**, 내부 492 × 380 = **19행**, 한 행 **한글 30자 / 반각 60칸**. 소지품 창도 같은 규약 |
| — | 화면 2종(목록/상세) × 탭 3종(진행 중/마친 일/못 마친 일). `inactive`·`mutex` 잠금은 미표시 |
| — | 목록 12행 + 미리보기 2행, 상세 목표 6행 + 초과 시 `… 외 {n}가지` |
| **R-41-14a~14c** | 목록 **미리보기 2행은 빌드가 미리 잘라 굽는다**(`previewLines`) — `journalLines` 의 앞 2행이 아니라 2행 예산에 맞춰 다시 감싼 별개 산출물이다. 런타임은 커서 이동 시 재측정하지 않고 값을 바꿔 끼운다(§41.4.5) |
| — | 정렬은 `updatedStep`(= `WorldState.step`) 내림차순 → `questId` 사전순. 결정론 보장 |
| **JV-03~07** | 길이 Hard 상한: 제목 22자 / 목표 문구 21자 / 요약·완료·실패 56자 / 단계 저널 84자 / 단계 제목 26자 |
| **JV-01/02** | Soft: objective > 6, 자동 생성 문구 > 17자 |
| R-41-9 | `HDInputMode` 는 **4개 그대로**. 새 모드 없음 |
| **R-41-9a~9c** | **불변식 — 대화가 진행 중일 때는 저널을 열 수 없다.** 진입점은 메인 메뉴 8번 **하나로 고정**하며 맵 모드 전용 단축키를 만들지 않는다. 티어 0 의 비동기 대화가 들어오면 `beginNarrative` 중첩 규약이 선행이다(§41.5.1) |
| — | `HDWindowKeyDispatcher._dispatch` 순서: message → **journal** → **inventory** → magic → selection. 신규 창은 `HDWindow` 직접 상속 |
| — | 키: ↑↓/WS 커서, ←→/AD 탭, Enter·E·Space 확인, Esc·Q 뒤로. **신규 전역 키 0개** |
| R-41-10 | 메인 메뉴는 `maxVisible: 9`, `y: 70`, `h: 366` (하단 436) |
| — | `UiHost.showWindowMenu` 에 선택 인자 `maxVisible = 6` 추가 (메서드 추가 아님) |
| — | **추적 표시 권고안: 다안 `HDTrackerBar`** — 진행 패널 상단 **512×24**, 미지정 시 0px |
| **R-41-11a·11b** | 추적 바 폭 예산 **60칸 = 11(`눈여겨 봄 `) + 3(`· `) + 40(목표 문구) + 6(` (2/3)`)**. 초판의 ASCII 도해 56칸은 오기였고 표 쪽으로 통일했다. 카운터가 없어도 문구 상한은 20자 고정. 바 높이는 **24px**(로그 영역 120px = 6.25행) |
| **JV-08** | 추적 바 목표 문구: 권고 ≤ 16자 / 경고 17~20자 / **Hard > 20자**(= 40칸). §41.4.4 와 같은 값 |
| R-41-11 | 추적 대상은 **1건** (BP-40 Q-40-5 종결) |
| R-41-12 | 알림은 narrative 중 **큐에 쌓고 `endNarrative()` 직후 flush**. 큐 상한 16건 |
| — | 알림 색상: 시작·진행 `@E`, 완료 `@A`, 실패 `@C`. 접두는 `[임무]` 고정 |
| R-41-13 | 콘텐츠 팩이 없어도 창은 열리고 "아직 맡은 일이 없다." 를 보여준다 |
| R-41-14 | 저널 전용 폰트 크기 금지 — 16pt 고정 |
| R-41-15 | 색상 태그는 문자열 파일 소유. 단 UI 크롬(커서·탭·체크박스·`[임무]`)은 예외 |
| — | 신규 파일 5개(도메인 2, 애플리케이션 1, 프레젠테이션 2), 기존 수정 **6곳**. 계층 grep 통과 논증 완료. DTO 파일명은 **`journal_rows.dart`**(위젯 `journal_view.dart` 와 구분) |

### 41.11.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| 소지품 창의 내부 레이아웃(프레임은 R-41-8 을 그대로 씀) | [BP-42](42_item_and_inventory.md) §5 |
| `JV-01` ~ `JV-07` 린트 규칙의 구현·에러 메시지 형식 | [BP-33](33_validation_and_lint.md) |
| 빌드가 굽는 `_wrapJournal` 사전 계산 — **`journalLines` 와 `previewLines` 두 산출물**(R-41-14a) | [BP-35](35_ci_and_build.md) |
| `JV-08`(추적 바 목표 문구 상한) 린트 구현 | [BP-33](33_validation_and_lint.md) |
| `UI_SPEC.md` 의 오류 3건 수정 작업(§41.1.1 이 정본이라고 선언했으므로 실제 파일 갱신 태스크가 필요하다 — 현재 어느 장의 태스크 목록에도 없다) | [BP-51](51_task_breakdown.md) |
| `journal_gate_test.dart` 회귀(R-41-9a)와 `tracker_budget_test.dart`(JV-08) | [BP-53](53_acceptance_criteria.md) |
| `HDJournalPresenter` 의 상세 API 시그니처 | [BP-27](27_runtime_engine.md) (§2 공개 API 표에 추가) |
| 저널 문자열의 문체(어미·존대·금칙어) | [BP-43](43_content_style_guide.md) |
| 위젯 테스트 도입(레포 최초) | [BP-53](53_acceptance_criteria.md) |

### 41.11.3 열린 질문

| ID | 질문 | 영향 |
|---|---|---|
| **Q-41-1** | `domain/content/journal_rows.dart` 를 D-11 파일 목록에 추가하는 것이 맞는가, 아니면 `quest.dart` 안의 뷰 헬퍼로 두는 것이 맞는가? 전자로 잠정 확정 | §41.10.2 |
| **Q-41-2** | 목록 12행은 너무 많은가? 원작 메뉴가 최대 6행이었음을 감안하면 8행이 감성상 자연스러울 수 있다. 다만 12행은 스크롤 빈도를 낮춘다 | §41.3.2 |
| **Q-41-3** | 추적 지정을 세이브에 넣을 것인가? 현재 "넣지 않는다"(UI 선호이지 월드 상태가 아님)로 확정했으나, 재시작 때마다 해제되는 것이 불편할 수 있다. 넣는다면 `WorldState` 가 아니라 **세이브 봉투(envelope)** 에 두어야 결정론 해시를 오염시키지 않는다 | §41.6.3 |
| **Q-41-4** | 도트 글꼴 DungGeunMo 의 한글 자폭이 정말 16.0px 고정인가? [BP-24](24_dialogue_model.md) Q-24-3 과 같은 질문이다. 위젯 테스트로 실측 필요 | §41.4 전체 |
| **Q-41-5** | `HDSelectionWindow` 의 `maxVisible` 확장이 스크롤 인디케이터 로직(`hasMoreAbove/Below`)과 어긋나지 않는가? 두 게터가 `maxVisibleItems` 를 참조하므로 인스턴스 필드화하면 자동으로 따라오지만, 회귀 테스트가 필요 | §41.5.5 |
| **Q-41-7** | `previewLines`(R-41-14a)를 굽는 비용이 번들에 얼마나 붙는가? 단계당 2행 × 60칸이므로 퀘스트 30개 × 단계 4개 기준 약 14KB(한글 UTF-8)로 추정되나 실측 전이다 | §41.4.5, [BP-35](35_ci_and_build.md) |
| **Q-41-6** | 완료/실패 상세의 "지나온 기록" 10건 상한이 `WorldState.journal` 의 전역 상한 500건([BP-25](25_world_state_and_save.md) §2.1)과 어떻게 상호작용하는가? 오래된 퀘스트의 기록이 앞에서 폐기되면 완료 상세가 비어 보일 수 있다 | §41.3.4 |
