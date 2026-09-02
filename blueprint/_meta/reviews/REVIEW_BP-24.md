# 검수 보고서 — BP-24 대화 그래프 모델

- **검수자**: R5 · **대상 파일**: blueprint/24_dialogue_model.md (1331줄)
- **판정**: **수정 필요**
- **점수**: A3 B2 C2 D3 E3 F2 G5 = **20/35** (합격선 26 + 전 축 3점 이상 — B/C/F 가 2점이라 불합격)

> 이 문서는 **AI 가 생성할 대화 데이터의 스키마**이자, 기획서에서 **유일하게 실제 픽셀을 계산한 장**이다.
> §24.5.1 의 픽셀 예산은 `console_panel.dart` 레이아웃과 대조했을 때 **거의 완전히 정확**하고,
> `pageBudget = 13 − headerCost − menuCost` 도 실제 위젯 트리에서 재현된다. 이 부분은 높이 평가한다.
> 그러나 (1) **§24.3.3 의 "표준 패턴" 3종이 전부 자기 자신의 Hard 규칙 `DV-01` 을 위반**하고,
> (2) **런타임 규약이 BP-27 §5 와 6개 항목에서 정면 충돌**하며,
> (3) **선택지 메뉴 제목 행(`items[0]`)을 만드는 필드가 스키마에 없다**.
> (4) `pauseAfter` 필드의 의미가 §24.4.2 의 렌더 알고리즘과 모순된다.

---

## 0. 수행한 기계적 검사 (증거)

| # | 검사 | 결과 |
|---|---|---|
| 1 | 줄 수 (`wc -l`) | **1331줄** — 규약 최소 250줄 충족 |
| 2 | 코드 인용 검증 | **26곳** 직접 열어 대조 (§0.1). 정확 15 / 근사 6 / 오류 5 |
| 3 | 링크 검증 | 15개 상대 링크 전부 해소 (`21/22/23/25/26/27/28` 실재, `33/34/37/41/42/43/50` 은 OUTLINE 계획 파일 → 허용) |
| 4 | 식별자 검증 | §24.7.3 의 `do` 분류표 = 비차단 19 + 차단 3 = **22종**, D-05 목록과 **정확히 일치**. `op` 도 `not/flag/quest_state/quest_stage/has_item/true` 전부 D-05 안. **임의 추가·오탈자 0건** ✅ |
| 5 | 중복 검사 | Condition/Effect 정의는 BP-21 로 정확히 위임 ✅. 그러나 **§24.7.3 의 즉시/지연 효과 분류표가 BP-25 §4.4 와 완전히 같은 내용을 재수록**(F-08). 또 `dialogue_choice` 라는 이벤트 이름을 BP-23 과만 맞추고 BP-25/BP-27(`choice_made`)과 어긋남(F-07) |
| 6 | 미확정 표현 grep | `적절히`/`추후`/`등등`/`TBD`/`미정` → **0건** |

### 0.1 코드 인용 대조 (26곳)

| 문서 위치 | 주장 | 실측 | 판정 |
|---|---|---|---|
| :543 | 패딩 좌우 16 / 상하 8 | `padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)` `console_panel.dart:40` | ✅ **정확** |
| :545 | 본문 16pt, 행높이 1.2 | `HDConfig.consoleFontSize = 16.0`, `consoleLineHeight = 1.2` `hd_config.dart:16-17` | ✅ |
| :547 | 섹션 간격 28.8px = `dialogSectionGap` | `static const double dialogSectionGap = consoleFontSize * consoleLineHeight * 1.5;` `hd_config.dart:22-23` → 28.8 | ✅ **정확** |
| :548 | 헤더 블록 = 19.2 + 28.8 = 48px | `console_panel.dart:52-61` — 헤더 `Text.rich` 1행 + `SizedBox(height: dialogSectionGap)` | ✅ **정확** |
| :549 | 푸터 블록 = 28.8 + 19.2 = 48px, 항상 자리 차지 | `:68` `SizedBox(dialogSectionGap)` + `:129-141` `_Footer` — 대기 중이 아니어도 `SizedBox(height: 16*1.2)` 예약 | ✅ **정확** |
| :550 | 본문(헤더 없음) 256px → 13행, `maxLinesPerPage=13` 과 일치 | `hd_config.dart:48-52` 주석이 같은 계산("320 − 16 padding − 48 prompt area = ~256") | ✅ **정확** |
| :552 | 줄바꿈 기준 폭 480px = `consoleWidth − 32` | `static const double _consoleWidth = HDConfig.consoleWidth - 32.0;` `flutter_ui_host.dart:63-64` | ✅ **정확** |
| :475 | `console_panel.dart` `_BodyArea`: 대사 → `Spacer()` → `_MenuBlock` | `:88-96` 정확히 그 구조 | ✅ **정확** |
| :475 | `selection_window_data.dart`: `w=400`, 기본 `x=200,y=100` | `:23-25` `this.x = x ?? 200; this.y = y ?? 100; w = 400;` | ✅ **정확** |
| :478 | `maxVisibleItems = 6` | `:11` `final int maxVisibleItems = 6;` | ✅ **정확** |
| :479 | 렌더 게이트 `menu != null && HDGameMain.isScriptRunning` (`console_panel.dart:46`) | 실제 `:47` `final showMenu = menu != null && main.isScriptRunning;` (:46 은 `final menu = …`) | ⚠️ 1줄 오차 |
| :479 | `hd_game_main.dart:86` → `HDTileEventDispatcher().isScriptRunning` | `:86` `bool get isScriptRunning => HDTileEventDispatcher().isScriptRunning;` | ✅ **정확** |
| :480 | `HDSelect.run()` = `select.dart:37`, `clearLogs:false` | `:37` `_lastResult = await HDHosts().ui.showMenu(items, clearLogs: false);` | ✅ **정확** |
| :486 | `select.dart:31-35` 주석 *"keeps the menu visually attached to the dialogue line that prompted it"* | 주석은 `:33-36`, 문구는 **원문 그대로 일치** | ⚠️ 2줄 오차 / 인용문 ✅ |
| :393 | `beginNarrative` — 디스패처가 호출 (`tile_event_dispatcher.dart:64`) | 실제 `:62`. `:64` 는 `host.clearLogs();` | ❌ **줄 오류** (BP-27 §5.2 는 `:62`/`:64` 로 **정확히** 씀) |
| :399 | `endNarrative` (`tile_event_dispatcher.dart:98`) | `:98` `await host.endNarrative(` | ✅ **정확** |
| :509 / :679 | SIGN 헤더 `tile_event_dispatcher.dart:110` | 실제 `:116-118`. (HEAD 커밋본은 `:109`) | ❌ **줄 오류** (BP-27 은 `:117` 로 정확) |
| :682-685 | 인용한 dart 코드 블록 | `if (action == HDTileAction.sign) { host.setHeader('@B푯말에 써 있기를:'); }` 문자열까지 일치 | ✅ |
| :531 | `_emitJsonDialog` 주석 *"SIGN/TALK/ENTER all share the dialog area now"* | `:168-170` 주석 원문 일치 | ✅ |
| :528 | `showMessageWindow` 400×200 고정, "overlong messages clip rather than grow the box" | `hd_config.dart:36-42` 주석 원문 + `messageWindowWidth=400, Height=200` | ✅ **정확** |
| :579 | `addLog` 는 `events.length >= 13` 일 때만 flush | `flutter_ui_host.dart:120` `if (consoleLog.events.length >= _maxLinesPerPage)` (=13) | ✅ **정확** |
| :588 | `ui_host.dart` `clearLogs` 주석 *"Also clears the dialogue header … the header lives with the body it titles"* | `ui_host.dart:50-53` 원문 일치 | ✅ |
| :705 | "`UiHost` 에는 헤더 getter 가 없다" | `ui_host.dart` 는 `setHeader` 만 선언 ✅. (단 구현체 `HDFlutterUiHost.header` @77 과 `HDGameMain.dialogHeader` @94 는 존재 — 포트만 없다) | ✅ (보완 필요) |
| :599 | `HDTextUtils.splitToLines` 가 `text.split(' ')` 로 어절 단위만 끊음 | `hd_text_utils.dart:85` `final words = text.split(' ');`, `:113` `if (currentLineWidth + wordWidth > maxWidth && currentLineChildren.isNotEmpty)` — 첫 단어가 폭을 넘어도 개행하지 않음 | ✅ **정확** |
| :600 | 480px 초과 어절은 "줄이 나뉘지 않고 그대로 **넘쳐 잘린다**" | `console_panel.dart:92` 는 `Text.rich(...)` — **softWrap 기본값 true**. 한글은 ICU 가 음절 경계에서 끊으므로 **잘리는 게 아니라 위젯이 스스로 2행으로 접는다** → 결과는 `Column` 의 RenderFlex 오버플로/행 회계 붕괴 | ❌ **메커니즘 오류**(F-11) |
| :597 | 색상 태그 `@X`/`@@` 는 폭 0 (`hd_text_utils.dart` `_parseToChunks`) | `:213-232` 태그는 chunk 텍스트에서 제거됨 → `TextPainter` 폭 0 | ✅ |
| :1133-1145 | `L1_ep1d1.cm2` "지형변화 아이템" 블록 인용 | `assets/L1_ep1d1.cm2:29-52` — `FLAG_EVENT`/`On(13,13)`/`Not(Flag::IsSet(GFD0_GET_WALL_REMOVER))`/`Select::Add` 3개/`Map::ChangeTile(13,13,43)` ×4/`Flag::Set(GFD1_WALL_REMOVER_USED)` **전부 일치** | ✅ **정확** |
| :1170-1173 | 변환 예의 `"map": "D1"` | `MapInfos.json` 등록 이름 15개(Test/LORE_EP/MAP003/TOWN1/GROUND1/DEN1/DEN2/Template_TOWN/Prolog/Prolog_B1/Prolog_B2/Template_DUNGEON/LoreContinent/CastleLore/LastDitch)에 **`D1` 없음** | ❌ **F-12** |
| :1098 | 변환 대상 = Map002 18 + Map011 9 + Map010 8 + Map003 3 = 38건 | GROUND_TRUTH §6 실측표와 일치 (18+9+8+3 = 38) | ✅ |
| :164 | 로드안 대사 = `town1_map_script.dart:88` | `:88` 은 `isOn(45,8)` 블록의 `return true;`. `isOn(50,27)` 블록은 **`:91-95`** | ❌ **줄 오류 + 다른 분기** |
| :103 | 주점 = `town1_map_script.dart:66` 의 `isOn(23,30)` | 실제 `:67`. (그리고 이것은 `onSign` 핸들러 = 간판이지 주인이 아님 — 문서도 "간판 근처" 라고 씀) | ⚠️ 1줄 오차 |

---

## 1. 텍스트 길이 수치 재계산표 (요청 항목)

**재계산 전제(실측)**: 폰트 `DungGeunMo`(`main.dart:53` 테마 `fontFamily`), 16pt, 행높이 1.2 → **1행 19.2px**.
컨테이너 실효 폭 = `512 − 2(Border.all(width:1) 양쪽) − 32(padding) = **478px**`
(문서는 border 를 빼지 않고 480 을 씀 — `flutter_ui_host.dart:63` 의 `_consoleWidth` 도 480 이므로 **코드 자체가 2px 낙관적**).
실효 높이 = `320 − 2 − 16 = **302px**`.

| # | 문서가 제시한 값 | 재계산 값 | 근거 코드 | 판정 |
|---|---|---|---|---|
| 1 | 콘솔 내부 영역 **480 × 304** | **478 × 302** (테두리 1px×2 미차감) | `console_panel.dart:36-40` `Border.all(width:1)` + `EdgeInsets.symmetric(16,8)` | ⚠️ **2px 낙관** — 결론(13행/10행)은 불변이나, `splitToRawLines` 가 480 을 기준으로 끊으므로 **경계 문자열이 실제로는 1행 넘칠 수 있다** |
| 2 | 1행 높이 **19.2px** | 19.2 (16 × 1.2) | `hd_config.dart:16-17` | ✅ |
| 3 | 헤더 블록 **48px = 2.5행 → 3행 계상** | 48px = 2.5행 | `console_panel.dart:52-61` | ✅ |
| 4 | 푸터 블록 **48px** | 28.8 + 19.2 = 48px | `console_panel.dart:68` + `:138-140` | ✅ |
| 5 | 본문(헤더 없음) **256px → 13행** | 302 − 48 = **254px → floor(254/19.2) = 13행** | `HDConfig.maxLinesPerPage = 13` | ✅ **일치** |
| 6 | 본문(헤더 있음) **208px → 10행** | 254 − 48 = **206px → floor(206/19.2) = 10행** | 동상 | ✅ **일치** |
| 7 | `pageBudget = 13 − headerCost(3) − menuCost(1+선택지수)` | 헤더 있음 = 13−3 = 10 ✅ / 메뉴는 `_MenuBlock` 이 `items` 를 1행씩 그리고 `items[0]` 이 제목 → **1+N 행 정확** | `console_panel.dart:100-119`, `flutter_ui_host.dart:22-23` | ✅ **공식 자체는 정확** |
| 8 | `Q-24-2` "헤더 실측 2.5행이라 **0.5행이 낭비된다**" | **낭비 없음.** `floor((254−48)/19.2) = 10` 이고 `13 − 3 = 10` 으로 **정확히 같다**. 2.5행으로 계상해도 10.7행 → 10행 | 위 5·6행 | ❌ **오류** — `Q-24-2` 는 존재하지 않는 문제다. 닫아도 된다 |
| 9 | 한글 음절 ≈ **16.0px**, 480px 에 **30자** | DungGeunMo 는 한글 1em(=16px) 고정 → 30자 = 480px. **실효 폭 478 기준으로는 29자**가 안전 | `main.dart:48-53` | ⚠️ **경계값 1자 낙관** |
| 10 | 라틴 ≈ **8.0px 평균(비례폭)** | DungGeunMo 는 반각 **고정폭** 8px. "평균/비례폭" 서술이 부정확(결과 수치는 맞음) | 동상 | ⚠️ 서술 오류 |
| 11 | 공백 ≈ **4.4px** | **근거 없음.** 같은 표의 "반각 8px" 모델과 모순되며 문서 어디에도 측정 근거가 없다. DungGeunMo 의 space advance 는 반각(8px)이어야 자연스럽다 | — | ❌ **미근거 수치** |
| 12 | 대사 1줄 **권장 ≤28자** | 28자 = 448px ≤ 478 → **확실히 1행** | `splitToRawLines(_, 480, _)` | ✅ **타당** |
| 13 | 대사 1줄 **Hard >45자**, 근거 *"45자 초과는 **2행을 넘겨** 리듬이 깨짐"* | 45자 = 720px → **이미 2행**(30+15). 2행을 넘으려면 **60자 초과**(2×30) 필요 | 동상 | ❌ **근거가 산술적으로 틀림.** 임계값 45 를 유지하려면 근거를 "2행 이내로 묶는다"(즉 60자 이하)가 아니라 "1.5행 이상은 리듬이 깨진다"로 다시 써야 함 |
| 14 | 공백 없는 어절 **Hard ≥30자** | 30자 = 480px > 478px 실효 폭 → 개행 불가 구간 진입. **정확한 임계** | `hd_text_utils.dart:113-114` | ✅ **타당** (다만 결과는 "잘림" 아닌 "위젯 자체 접힘" — F-11) |
| 15 | 선택지 텍스트 **권장 ≤18 / Hard >24**, 근거 "480px(30자) 안에서 6자 여유" | 24 + 6 = 30 ✅ Hard 임계의 근거로는 정합. **권장 18 의 근거는 표에 없다**(12자 여유) | `_MenuBlock` 은 `Text.rich` 로 raw item 을 직접 렌더 — **`splitToRawLines` 를 통과하지 않는다** | ⚠️ Hard ✅ / 권장 근거 누락 |
| 16 | 선택지 제목 행 **≤26 / Hard >30자** | 30자 = 480px > 478 → **정확히 30자에서 이미 접힌다**. Hard 는 `>30` 이 아니라 `≥30` 이어야 함 | 동상 | ⚠️ **경계 오차 1자** |
| 17 | 헤더 텍스트 **≤20 / Hard >28자** | 헤더도 `Text.rich` 직접 렌더(`console_panel.dart:56-58`)라 29자부터 2행이 되어 `headerCost` 가 4행으로 깨진다. **28 Hard 는 안전 마진으로 타당** | `console_panel.dart:52-59` | ✅ **타당** (보수적) |
| 18 | 선택지 개수 Hard `>6`, "`maxVisibleItems=6` 과 정합" | `HDSelectionWindow.maxVisibleItems = 6`, `displayCount = min(enabledCount, 6)` — 선택지 6개는 `enabledCount=6` 이라 스크롤 없음 | `selection_window_data.dart:11,26` | ✅ **정확** |
| 19 | `showWindowMenu` 창 내부 "약 336px → 한글 21자" | 400 − 2×2(border) − 2×8(padding) − 2×8(row hpad) − 8(아이콘 간격) ≈ **356px → 22자** | `selection_window_data.dart:25` + `window_view.dart:56,59,183,191` | ⚠️ **약 20px 보수적** ("약" 이라 치명적이진 않음) |
| 20 | `lines[]` 항목 수 Hard `>12`, 근거 "항목당 최소 1행이므로 12행이면 13행 예산을 넘김" | 12행은 13행 예산 **안**이다. 13개여야 넘친다. 게다가 **헤더가 있으면 예산은 10행**이라 11개부터 넘친다 | 위 6행 | ❌ **근거 오류 + 헤더 케이스 미반영** |
| 21 | `maxDepth` **기본 32**(§24.2.1, §24.8.4) vs **권장 16**(§24.5.5) | 같은 문서 안에서 두 값이 다르고, 예시는 4/8/16 을 쓴다 | §24.2.1:64 / §24.5.5:616 / §24.8.4:921 | ❌ **내부 불일치** |

**요약**: 21개 수치 중 **정확·타당 11 / 경계·서술 오차 6 / 명백한 오류 4**.
핵심 공식(`pageBudget = 13 − 3 − (1+N)`)과 픽셀 예산 표는 **실제 위젯 트리에서 재현된다** — 이 장의 가장 큰 성과다.
틀린 것은 **근거 문장의 산술**(#13, #20)과 **미근거 수치**(#11), **불필요한 열린 질문**(#8)이다.

---

## 2. 그래프 제약 검증표 (요청 항목)

`DV-01`~`DV-32` 를 전수 추출해 **정의 위치 / 판정 알고리즘 유무 / 문서 자체 예시·패턴이 지키는지 / 실효**를 검증했다.

| ID | 제약 | 등급 | 정의 위치 | 알고리즘 | 문서 자체가 지키는가 | 실효 판정 |
|---|---|---|---|---|---|---|
| `DV-01` | `entry` 마지막 원소는 `when` **없음** | Hard | §24.3.1 :323 | §24.8.5 `if dlg.entry[-1].when != null` | ❌ **§24.3.3 패턴 A/B/C 3종 전부 `{"when":{"op":"true"}}` 를 마지막에 둠** — 자기 Hard 규칙 위반 | ❌ **F-01** |
| `DV-01b` | `when` 없는 원소가 마지막 이외 위치에 없음 | Hard | §24.3.1 :324 | §24.8.5 | ✅ | ✅ |
| `DV-01c` | 동일 조건 반복 | Soft | §24.3.2 표 | `detectEntryShadowing` (본문 없음) | ✅ | ⚠️ 알고리즘 미제시 |
| `DV-01d` | `quest_stage` 분기는 `quest_state(active)` 위에 | Soft | §24.3.2 표 | 동상 | ✅ 예시 2 가 정확히 준수 | ✅ 좋음 |
| `DV-02` | 도달 불가 노드 없음 | Hard | §24.8.1 | §24.8.5 3번 전방 BFS (`repeatPool` 을 루트에 포함 — **정확한 처리**) | ✅ | ✅ 우수 |
| `DV-03` | 모든 노드에서 `"end"` 도달 가능 | Hard | §24.8.1 | §24.8.5 4번 역방향 고정점 | ✅ | ✅ |
| `DV-04` | 모든 `Choice` 도달 가능 | Hard | §24.8.1 | §24.8.5 5번 `isAlwaysFalse` — **완전 SAT 안 함, 3패턴만** (스스로 명시 ✅) | ✅ | ⚠️ **`chance` 를 전혀 다루지 않음**(F-09) |
| `DV-05` | 표시 가능한 선택지 0개 금지 | Hard | §24.8.1 | §24.8.2 — 그런데 **런타임 `visible.isEmpty` 경로가 §24.4.2 에 여전히 있다** | ✅ | ⚠️ 구조적 보장(`DV-12`)과 방어 코드가 중복 |
| `DV-06` | 모든 stringKey 존재 | Hard | §24.8.1 | §24.8.5 1번 | ✅ | ✅ |
| `DV-06b` | 미지의 치환 토큰 | Hard | §24.6.4 :730 | `validateTokens` (본문 없음) | ✅ | ⚠️ |
| `DV-06c` | 본문에 한국어 직접 기입 패턴 검사 | Hard | §24.11.2 #5 | 없음 | ✅ | ⚠️ **정의 절 없음** — 표 한 칸에만 등장 |
| `DV-07` | 본문 이름 접두(`로드안:`) 검사 | Soft | §24.6.4 :714 | 없음 | ✅ | ⚠️ |
| `DV-07b` | `@B` 본문 사용 금지 | Soft | §24.6.5 | 없음 | ✅ | ⚠️ |
| `DV-07c` | `@E` 노드당 2회 | Soft | §24.6.5 | 없음 | ✅ | ⚠️ |
| `DV-07d` | 연 태그를 같은 문자열에서 `@@` 로 닫기 | Hard | §24.6.5 | 없음 | ✅ | ⚠️ 실제로는 `_parseToChunks` 가 sentinel 로 처리하므로(§24.6.5 스스로 인정) **Hard 로 둘 근거가 약함** |
| `DV-08` | 어절 ≥30자 | Hard | §24.5.6 | 폭 근사식 §24.5.5 | ✅ | ✅ 임계 정확 |
| `DV-08b` | **두 가지 규칙에 중복 배정** — §24.5.6 은 "선택지 텍스트 >24자", §24.8.2 는 "선택지 7개 이상" | Hard | §24.5.6 :636 / §24.8.2 :875 | 둘 다 존재 | — | ❌ **ID 충돌**(F-10) |
| `DV-09` | 대사 1줄 >45자 | Hard | §24.5.6 | 근거 산술 오류(§1 #13) | ✅ | ⚠️ |
| `DV-10` | 노드 본문 >3페이지 | Hard | §24.5.6 | **`pageBudget` 이 런타임 `menuCost` 에 의존** → 빌드가 페이지 수를 확정할 수 없음 | ✅ | ❌ **F-05** |
| `DV-11` | `pageBudget < 1` | Hard | §24.5.6 | 동상 — "최악의 경우(모든 선택지 표시)" 라는 명시가 없음 | ✅ | ❌ **F-05** |
| `DV-12` | 마지막 선택지는 무조건 표시 + `once` 아님 | Hard | §24.2.3 / §24.8.1 | §24.8.2 `validateChoiceFloor` — **완전** | ✅ 예시 2 `c_decline` 준수 | ✅ **우수 설계** (취소=마지막 매핑을 구조적으로 안전하게 만듦) |
| `DV-13` | `entry` ≤12개 | Soft | §24.3.1 | 없음 | ✅ (예시 2 는 6개) | ⚠️ |
| `DV-14` | `flag.<pack>.met.<slug>` 관례 | Soft | §24.3.3 C | 없음 | ✅ | ⚠️ |
| `DV-15` | 차단성 do 최대 1개 | Hard | §24.7.3 | `validateBlockingEffects` (본문 없음) | ✅ | ⚠️ BP-25 §4.4 는 **런타임이 첫 번째만 실행** 이라 규정 — 두 장이 같은 말을 두 곳에서 함 |
| `DV-16` | 차단성 do 는 배열 마지막 | Hard | §24.7.3 | 동상 | ✅ | ✅ |
| `DV-17` | 차단성 do 를 가진 노드/선택지의 다음은 `"end"` | Hard | §24.7.3 | 동상 | ⚠️ **§24.10.3 변환 예의 `c_use` 는 차단성 do 가 없으므로 무관** — 위반 없음 | ✅ |
| `DV-18` | `onEnter` 차단성 do → `lines` 1페이지 이내 | Hard | §24.7.3 | 동상 | ✅ | ⚠️ 역시 `pageBudget` 의존(F-05) |
| `DV-19` | `play_dialogue` 연쇄 ≤4 | Hard(런타임) | §24.7.4 | 런타임 카운터 | ✅ | ⚠️ BP-25 §4.4 는 지연 효과를 **"한 개만"** 실행 → **연쇄 4회가 성립하지 않는다**(F-03) |
| `DV-20` | 대화 간 사이클 검출 | Hard | §24.7.4 / §24.8.1 | §24.8.5 7번 `index.crossDialogueCycleCheck` (본문 없음) | ✅ | ⚠️ **`play_dialogue` 는 꼬리 호출이라 사이클이 곧 무한 루프는 아니다**(`DV-19` 가 이미 막음). Hard 로 금지할 근거가 약함 |
| `DV-21` | `nodes` 키 = `node.id` | Hard | §24.8.1 | §24.8.5 1번 | ✅ 예시 전부 준수 | ✅ |
| `DV-22` | `choices` + `next` 동시 선언 | Soft | §24.8.1 | 없음 | ✅ | ✅ |
| `DV-23` | 사이클에 소모성 간선 강제 | **Soft**(§24.8.3 표는 규칙, 의사코드는 `SOFT`) | §24.8.3 | Tarjan SCC — **의사코드 완전** | ✅ 예시 2 `c_ask_more.once` | ⚠️ §24.8.3 표는 "무한 루프 방지 2" 로 **강제**처럼 쓰고 의사코드는 SOFT — 등급 불일치 |
| `DV-24` | 탈출 불가 사이클 | Hard | §24.8.3 | 동상 | ✅ | ✅ **우수** |
| `DV-25` | `maxDepth` 범위 4~64 | Hard | §24.8.4 | — | ⚠️ 기본값 32 vs 권장 16 불일치(§1 #21) | ⚠️ |
| `DV-26` | `once` 노드가 `choices` 보유 | Soft | §24.9.2 | 없음 | ✅ | ⚠️ |
| `DV-27` | `once` 노드가 `entry` 의 유일 대상 | **Hard** | §24.9.2 | 없음 | ✅ 예시 1 은 `n_first`(once) 아래 `n_repeat` 기본 규칙 보유 | ✅ 좋은 규칙 |
| `DV-28` | `repeatPool` 1개면 경고 | Soft | §24.9.3 | 없음 | ✅ | ⚠️ |
| `DV-29` | `repeatPool` 노드에 상태 변경 `onEnter` 금지 | Soft | §24.9.3 | 없음 | ❌ **`pickRepeatNode` 자신이 매 호출마다 `ctx.vars[cursorVar]` 를 쓴다** → `var_changed` 이벤트 발생(BP-23 §23.11.1 #8). 규칙과 메커니즘이 모순 | ❌ **F-06** |
| `DV-30` | 지식 범위 위반(entry 조건 vs 본문 언급) | Soft | §24.11.2 #7 | 없음 (Q-24-7 에서 한계 인정 ✅) | ✅ | ⚠️ 정직 |
| `DV-31` | `pauseAfter:false` 체인 길이 ≤3 | **후보** | `Q-24-4` | — | — | ⚠️ 미확정 |
| `DV-32` | 마지막 선택지에 차단성 do | **후보** | `Q-24-5` | — | — | ⚠️ 미확정 |

**집계**: 정의된 40개 규칙(하위 문자 포함) 중
**판정 알고리즘이 의사코드로 제시된 것은 9개**(`DV-01/01b/02/03/04/05/12/23/24`),
나머지 31개는 **함수 이름만 있거나 표 한 줄**이다. `DV-06c`·`DV-07`~`DV-07d` 는 **정의 절조차 없다**.
축 E 의 핵심 약점이며, `hadar_content lint` 구현자가 이 문서만으로 40개를 열거할 수 없다.

---

## 3. 치명 결함

### F-01 §24.3.3 "표준 패턴" 3종이 전부 `DV-01`(Hard) 을 위반한다

§24.3.1 :323 — *"`entry` 의 **마지막 원소는 `when` 이 없어야** 한다 — `DV-01` **Hard**"*.
§24.8.5 검증 코드 — `if dlg.entry[-1].when != null: D += HARD("DV-01 no default entry")`.

그런데 §24.3.3 의 세 패턴은 전부 이렇게 끝난다:

```jsonc
{ "when": {"op":"true"}, "go": "n_offer" }     // 패턴 A :350
{ "when": {"op":"true"}, "go": "n_offer" }     // 패턴 B :365
{ "when": {"op":"true"}, "go": "n_repeat" }    // 패턴 C :378
```

`when` 이 **있으므로 셋 다 Hard 실패**한다. §24.11.3 프롬프트는 반대로 *"entry 의 마지막 원소에는 when 을 넣지 않는다"*
라고 정확히 쓰고, §24.2.4/§24.2.5 의 두 완전 예시도 `{ "go": "n_repeat" }` 로 올바르다.
**즉 문서 안에 두 관례가 공존하고, 하필 "표준 패턴" 이라 이름 붙은 쪽이 틀렸다.**

더 나쁜 것은 이것이 **BP-23 과 정반대 관례**라는 점이다. BP-23 `QV-06` 은 `next` 배열의
*"마지막 원소의 `when` 은 `{"op":"true"}` 여야 한다"* 를 Hard 로 요구한다. 같은 "기본 분기" 개념이
한 장에서는 **`when` 부재**, 다른 장에서는 **`when: true` 존재**로 정반대다.

**요구 조치**: (a) §24.3.3 세 패턴을 `{ "go": "…" }` 로 정정, (b) BP-23 `QV-06` 과 표현을 통일
(권장: **양쪽 다 `{"op":"true"}` 명시**를 택하면 스키마가 `when` optional 을 안 가져도 되어 더 단순하다.
반대로 부재를 택하면 `DV-01b` 가 필요 없다). 어느 쪽이든 **두 장이 같아야** 생성 에이전트가 헷갈리지 않는다.

### F-02 런타임 규약이 BP-27 §5 와 6개 항목에서 정면 충돌한다

BP-24 §24.4 는 이 장의 심장(§24.12.1 확정 항목 4·5·6·7·13)인데, **BP-27 §5.1~5.3 이 전부 다르게 규정**한다.

| 항목 | BP-24 | BP-27 | 충돌 |
|---|---|---|---|
| 선택지 렌더 | **`showMenu(items, clearLogs:false)`** (§24.4.3, 근거 4가지) | `picked = await host.showWindowMenu(items)` (`27:756`) | ❌ **정반대** |
| 취소(0) 처리 | **마지막 선택지를 고른 것과 동일** (`DV-12` 가 이를 안전하게 만듦) | `if picked == 0: nodeId = node.next ?? "end"` (`27:758-761`) | ❌ 정반대 |
| 이벤트 vs 효과 순서 | `dialogue_choice` 를 **effects 보다 먼저** (§24.7.2) | `EffectApplier.apply(...)` **다음** `publish(choice_made…)` (`27:768-769`) | ❌ 정반대 |
| 이벤트 이름 | `dialogue_choice` | `choice_made` | ❌ (F-07) |
| 페이지네이션 | **런타임이 `pageBudget` 으로 직접 끊고 매 페이지 `setHeader` 재호출** (§24.5.3) | `for key in node.lines: await host.addLog(...)` 뿐 — `addLog` 내부 flush 에 의존 (`27:735-736`) | ❌ **§24.5 전체가 무효화됨** |
| 메뉴 제목 행 | `resolveChoiceTitle(node, ctx)` — **정의도 필드도 없음**(F-04) | `node.promptKey ?? defaultPrompt` — **BP-24 스키마에 없는 필드** | ❌ |
| `once` 선택지 저장 | `WorldState.choicesTaken: Set<"dlgId#nodeId#choiceId">` (§24.9.1) | `state.setFlag(choiceOnceFlag(d.id, node.id, c))` — **플래그** (`27:747, 766`) | ❌ |

부수적으로, **BP-27 §5.2 는 `tile_event_dispatcher.dart` 줄 번호를 `:62`/`:64`/`:117`/`:98` 로 정확히 쓴다.**
BP-24 는 같은 지점을 `:64`/`:110` 으로 쓴다(§0.1) — 두 장이 서로 다른 실측을 갖고 있다는 증거다.

**요구 조치**: **BP-24 를 대화 런타임 규약의 SSoT 로 확정**하고(그쪽이 근거가 훨씬 두껍다) BP-27 §5 를 전면 정정하도록 전파.
특히 `showMenu` vs `showWindowMenu` 는 **콘텐츠 데이터가 아니라 런타임 1곳의 분기**이므로(§24.4.3 마지막) 조정이 쉽다.

### F-03 `play_dialogue` 연쇄 4회(`DV-19`)가 BP-25 의 "지연 효과 1개만 실행" 과 양립하지 않는다

- BP-24 §24.7.4: *"연쇄 상한: 한 상호작용에서 `play_dialogue` 연쇄 **4회**"* + `DV-20` 이 대화 간 사이클을 Hard 로 금지.
- BP-25 §4.4: *"지연 효과 … 현재 상호작용의 드레인 완료 후, **한 개만** 실행"*, 2개 이상이면 첫 번째만 + 경고.

BP-25 규약대로면 A → B 로 넘어간 시점에 **그 상호작용은 이미 끝났다.** B 가 다시 `play_dialogue(C)` 를 지연 큐에 넣으면
그것은 **새 상호작용**이므로 "한 상호작용에서 4회" 라는 상한이 걸릴 자리가 없다.
반대로 같은 상호작용 안에서 4회를 허용하려면 BP-25 의 "한 개만" 을 깨야 한다.

**요구 조치**: `DV-19` 를 "**한 타일 상호작용에서 시작된 대화 체인의 총 길이 4**" 로 정의하고,
그 카운터를 어디가 소유하는지(ContentRuntime) 명시. 또는 BP-25 쪽으로 통일.

### F-04 선택지 메뉴의 **제목 행(`items[0]`)을 만드는 필드가 스키마에 없다**

`UiHost.showMenu` 규약상 `items[0]` 은 제목이다(`ui_host.dart:11-12`, `flutter_ui_host.dart:23`,
`_MenuBlock._colorFor(0) → Colors.red`). §24.4.2 :456 은
```
items = [ resolveChoiceTitle(node, ctx) ] + [ strings.resolve(c.text) for c in visible ]
```
라고 쓰지만 **`resolveChoiceTitle` 은 어디에도 정의되지 않았고**, §24.2.2 Node 스키마 표에도
제목을 담을 필드가 없다. `header`? `lines` 의 마지막? 상수? — 알 수 없다.

동시에 §24.5.5 는 "선택지 제목 행(`items[0]`) ≤26자 / >30자 Hard" 라는 **길이 규칙만** 갖고 있어,
**존재하지 않는 필드에 린트를 걸어 둔 상태**다. BP-27 은 이 구멍을 `node.promptKey` 라는 임의 필드로 메웠다.

**요구 조치**: `Node.promptKey: stringKey?` (기본값 = `str.core.choice.default` 같은 상수)를
§24.2.2 스키마 표에 **필드로 추가**하고, `menuCost` 계산·`DV-11`·길이 규칙과 연결한다.
`menuCost = 1 + N` 의 그 "1" 이 바로 이 필드다 — 지금은 근거 없는 상수다.

### F-05 빌드 시점 길이 검사(`DV-10`/`DV-11`/`DV-18`)가 **런타임 값에 의존**해 판정 불가능하다

`pageBudget = 13 − headerCost − menuCost` 에서 `menuCost = 1 + visibleChoiceCount(node, ctx)` 이고,
`visibleChoiceCount` 는 각 `Choice.when` 을 **그 시점 WorldState 로 평가**해야 나온다(§24.4.2 6번).
그런데 `DV-10`("노드 본문 > 3페이지"), `DV-11`("`pageBudget < 1`"), `DV-18`("1페이지 이내")은 **빌드 Hard 게이트**다.

같은 노드가 상태에 따라 2페이지도 되고 4페이지도 된다. 문서는 어느 값을 쓰는지 말하지 않는다.
`DV-11` 설명의 괄호 *"(헤더 3 + 선택지 6 = 9, 본문 4행 이상)"* 만 **최악의 경우**를 암시할 뿐이다.

**요구 조치**: *"빌드는 `menuCost` 를 **`1 + len(node.choices)`(전부 표시되는 최악의 경우)** 로 계산한다"* 를
§24.5.2 에 한 줄 확정한다. 그러면 세 규칙 모두 정적으로 판정 가능해진다.
(런타임은 실제 표시 수로 더 넉넉한 예산을 쓰므로 안전 방향이다.)

### F-06 `pauseAfter:false` 의 정의가 §24.4.2 렌더 알고리즘과 모순된다

§24.2.2: *"`pauseAfter` … false 면 이 노드 끝에서 `waitForAnyKey()` 를 생략하고 **다음 노드로 곧장 이어 붙인다**"*.
그러나 §24.4.2 4번은 **모든 노드 진입 시 `ctx.host.clearLogs()`** 를 부른다.
`clearLogs` 는 본문과 헤더를 **둘 다 지운다**(`flutter_ui_host.dart:203-210`, `ui_host.dart:50-53`).
→ `pauseAfter:false` 로 넘어간 다음 노드가 즉시 앞 노드의 대사를 **지워 버린다.** "이어 붙인다" 가 불가능하다.

`Q-24-4` 는 "페이지 예산이 노드 경계를 넘는다" 는 **다른 문제**만 다루고 이 모순은 인지하지 못했다.

**요구 조치**: `renderNode` 에 `clearScreen: bool` 파라미터를 두고
*"이전 노드가 `pauseAfter:false` 였으면 `clearLogs`/`setHeader` 를 건너뛰고 `emitted` 를 이어받는다"* 로 알고리즘을 고친다.
그러면 `Q-24-4` 의 예산 누적 계산도 자연스럽게 따라온다.

### F-07 이벤트 이름 `dialogue_choice` 가 BP-25/BP-27 의 `choice_made` 와 다르다

§24.7.2 / §24.4.2 :464 는 `dialogue_choice` 를 발행한다(BP-23 §23.11.1 #9 와 일치).
BP-25 §4.2 의 닫힌 카탈로그는 `choice_made`, BP-27 `:769` 도 `choice_made`.
**BP-23+BP-24 vs BP-25+BP-27 로 진영이 갈렸다.** 상세는 `REVIEW_BP-23.md` F-02 참조.

**요구 조치**: 이벤트 카탈로그의 SSoT 를 한 장으로 확정. BP-24 는 이름을 인용만 하고 **정의하지 않아야** 한다.

---

## 4. 중요 결함

### F-08 §24.7.3 의 즉시/지연 효과 분류표가 BP-25 §4.4 와 완전 중복이다

두 표의 내용은 **일치**한다(비차단 19 + 차단 3 = 22, D-05 와 정확히 대응 ✅).
그러나 규약 6번("같은 내용을 두 장에 복사하지 말고 한 곳에 쓰고 링크")을 어긴다.
`do` 가 하나 늘어나면 두 곳을 고쳐야 하고, 지금 이미 `DV-19` vs "한 개만" 처럼 **파생 규칙이 갈라지기 시작했다**(F-03).

**요구 조치**: BP-25 §4.4 를 SSoT 로 두고 §24.7.3 은 **차단성 3종의 대화-측 처리(§24.7.3 규칙 `DV-15`~`DV-18`)만** 남긴다.

### F-09 `chance` op 가 대화 그래프에서 한 번도 다뤄지지 않는다

`Choice.when` / `EntryRule.when` 은 D-05 의 **모든 op** 를 받는다 — `chance(percent)` 포함.
그런데 BP-24 에서 `chance` 가 등장하는 곳은 §24.9.3 의 *"`chance` 난수를 쓰지 않는다"* 한 줄뿐이고,
그것은 `repeatPool` 내부 선택 방식에 대한 서술이다.

미정의 사항:
- `isAlwaysFalse`(§24.8.5)는 `chance(0)` 을 잡지 못한다 → `DV-04` 무력.
- `chance` 가 걸린 선택지의 **도달성**을 빌드가 어떻게 판정하는가.
- `DV-05`/`DV-12` 는 "마지막 선택지는 무조건 표시" 로 방어하지만, **중간 선택지가 전부 `chance` 면**
  플레이어가 같은 노드에서 매번 다른 메뉴를 본다 — `menuCost` 가 흔들려 F-05 를 악화시킨다.
- 솔버(BP-34)가 `chance` 분기를 양쪽 탐색하면 `maxDepth 32 × 선택지 조합`(§24.8.4)이 곱해져 폭발한다.
  §24.8.4 는 상한을 *"`maxDepth` × 표시 가능한 선택지 조합"* 이라고만 쓰고 **가지치기 규칙이 없다**.

**요구 조치**: v1 에서 `Choice.when`/`EntryRule.when` 의 **허용 op 를 부분집합으로 제한**(`chance` 제외)하거나,
허용한다면 `DV-` 규칙을 신설하고 솔버 예산 규칙을 BP-34 로 명시 위임한다.
**"대화 그래프는 사이클을 허용하는데 솔버가 상태 공간 폭발을 어떻게 막는가"** 에 대한 이 장의 답은
현재 `maxDepth 32` + `once` 소모성 간선뿐이며, **탐색 예산 상한이 어디에도 수치로 없다.**

### F-10 `DV-08b` 가 서로 다른 두 규칙에 배정되어 있다

- §24.5.6 :636 — "선택지 텍스트 > 24자 → `DV-08b` Hard"
- §24.8.2 :875 — `if len(node.choices) > 6: return HARD("DV-08b too many choices")`
- §24.11.2 #12 — "선택지 7개 이상 → `DV-08b` Hard"

**요구 조치**: 선택지 개수 규칙에 새 ID(예: `DV-33`)를 부여하고 §24.5.5 표의 "선택지 개수" 행과 연결.

### F-11 "공백 없는 어절은 **잘린다**" 는 메커니즘 서술이 틀렸다

§24.5.4 는 480px 를 넘는 어절이 *"줄이 나뉘지 않고 그대로 넘쳐 **잘린다**"* 고 쓴다.
실제 렌더는 `console_panel.dart:92` 의 `Text.rich(...)` 이고 **`softWrap` 기본값은 true** 다.
한국어는 ICU 줄바꿈이 음절 경계에서 끊으므로 **위젯이 스스로 2행으로 접는다.** 결과는:

- `consoleLog.events` 는 1줄로 세는데 화면은 2행을 먹는다 → **행 회계가 어긋나 `pageBudget` 이 깨진다**
- `_BodyArea` 의 `Column` 이 `Expanded` 안에서 넘치면 **RenderFlex 오버플로**(디버그 줄무늬 / 릴리스 클립)

즉 **위험은 실재하지만 원인과 증상이 다르다.** `DV-08` 의 hint 문구("여기에 공백을 넣으세요")는 여전히 맞다.
라틴 문자로만 이루어진 긴 토큰(URL 등)은 문서 서술대로 잘린다 — 두 경우를 나눠 써야 한다.

### F-12 §24.10.3 변환 예의 `"map": "D1"` 은 존재하지 않는 맵 이름이다

`MapInfos.json` 실측 등록 이름 15개에 `D1` 이 없다(§0.1). `L1_ep1d1.cm2` 는 **스크립트 파일명**이지 맵 이름이 아니다.
이 예시는 `DV-06`/BP-23 `QV-03` 참조 무결성에서 Hard 실패한다.
**§24.10.1 의 변환기 의사코드도 같은 문제를 낳는다** — `slug = mapName.lower() + "_" + x + "_" + y` 인데,
변환 대상 38건은 `Map002/Map003/Map010/Map011` 이고 그중 `Map010`/`Map011` 은
`MapInfos.json` 에 **등록조차 되어 있지 않다**(등록 이름은 `MAP003` 하나뿐).

**요구 조치**: 예시의 맵 이름을 실재 이름으로 교체하고, §24.10.1 에
*"`MapInfos.json` 에 없는 맵 파일은 변환 전에 등록(`registerAs`)해야 한다"* 를 선행 조건으로 명시.

### F-13 `WorldState` 확장 3종이 **어느 장에도 정의되어 있지 않다**

§24.9.1 은 `dialogueVisits: Set<"dlgId#nodeId">`, `choicesTaken: Set<"dlgId#nodeId#choiceId">`,
`repeatPool` 커서 변수를 도입하고 *"스키마 확정은 [BP-25]"* 라고 위임한다.
**BP-25 §2.1/§2.2/§5.1 을 grep 한 결과 세 필드 모두 존재하지 않는다.**
게다가 BP-27 은 `once` 를 **플래그**로 저장한다(F-02 표).

`once` 는 `DV-23`(소모성 사이클 강제)과 `DV-12`(마지막 선택지)의 근간이므로,
**저장 위치가 미정이면 사이클 탈출 보장 자체가 미정**이다.

**요구 조치**: BP-25 에 3필드 추가를 요청하고(전파 절), 그때까지 §24.9.1 에
"BP-25 미반영 — 확정 전까지 `once` 의 영속성은 보장되지 않음" 을 열린 질문으로 승격.

### F-14 `pickRepeatNode` 의사코드에 인덱스 범위 버그가 있다

```pseudo
pool = [ n for n in dlg.repeatPool if isEligible(n, ctx) ]   # 매번 필터링됨
i = ctx.vars[cursorVar] ?? 0
ctx.vars[cursorVar] = (i + 1) % len(pool)
return pool[i]                                                # ← i 가 len(pool) 이상일 수 있다
```
커서는 **이전 호출의 `pool` 길이**로 모듈로되는데, `isEligible`(= `once` 소진 등)로 풀이 줄면
`i >= len(pool)` 이 되어 **범위 초과**한다. `return pool[i % len(pool)]` 이어야 한다.

또한 이 함수는 **매 대화마다 `ctx.vars` 를 쓴다** → BP-23 §23.11.1 #8 `var_changed` 발행 →
모든 `var_reach` 목표와 `failConditions` 재평가. `DV-29`("`repeatPool` 노드에 상태 변경 `onEnter` 금지")의
취지와 정면으로 어긋난다. **커서를 `WorldState.vars` 가 아닌 이벤트를 내지 않는 별도 저장소에 두어야 한다**
(`Q-24-6` 이 오염 문제는 인지했으나 이벤트 발행 부작용은 놓쳤다).

### F-15 `maxDepth` 기본값이 문서 안에서 32 와 16 으로 갈린다

§24.2.1 :64 기본 32 / §24.8.4 :921 "기본 **32**" / §24.5.5 :616 "`maxDepth` **권장 16**" /
예시 1 은 8, 예시 2 는 16. §24.12.1 항목 15 는 "`maxDepth` 32" 로 확정 선언.
**요구 조치**: §24.5.5 행을 "기본 32 / 권장 8~16" 으로 정정.

### F-16 `lines[]` 가 비었고 `choices` 도 없는 노드의 동작이 미정의다

`lines` 기본값은 `[]`(§24.2.2), `next` 기본값은 `"end"`. 따라서
`{"id":"n_x"}` 만으로도 스키마상 유효한 노드가 만들어진다. §24.4.2 를 그대로 돌리면
`clearLogs()` → (헤더만) → 출력 0줄 → `pauseAfter:true` → **빈 화면에서 `waitForAnyKey()`**.
`DV-` 규칙 어느 것도 이를 잡지 않는다.

**요구 조치**: *"`lines` 가 비면 `pauseAfter` 를 강제로 false 로 본다"* 또는
*"`lines` 가 비었고 `onEnter` 도 비었으면 Hard"* 를 신설(`DV-34`).

---

## 5. 개선 제안 (선택)

- **S-01** `Q-24-1`(SIGN 기본 헤더의 이중 관리)의 더 나은 답: `tile_event_dispatcher.dart` 에
  `const String kSignHeader = '@B푯말에 써 있기를:';` 를 **공개 상수로 승격**하면
  `ContentRuntime` 이 같은 상수를 import 할 수 있다. 포트를 넓히지도(R-24-5 준수) 값을 복제하지도 않는다.
  application 계층 안이라 계층 규칙에도 걸리지 않는다.
- **S-02** `Q-24-2`(헤더 0.5행 낭비)는 §1 #8 에서 보였듯 **실재하지 않는 문제**다. 닫아도 된다.
- **S-03** §24.6.3 의사코드 :700 `ctx.inheritedHeader = host.currentHeader` 는
  **존재하지 않는 메서드 호출**이다(바로 아래에서 상수 방식으로 결정해 놓고 의사코드는 안 고침). 정리 필요.
- **S-04** §24.5.6 의 *"빌드가 wrapped 줄 수를 미리 계산해 `content.bundle.json` 에 `_wrap` 으로 굽는다"* 는 좋은 설계다.
  다만 `HDTextUtils.splitToLines` 는 `TextPainter` 실측을 쓰므로, 빌드(순수 Dart, Flutter 없음)와
  **같은 함수를 공유할 수 없다**. `Q-24-3` 이 위젯 테스트로 대조하겠다고 했는데,
  더 확실한 방법은 **폭 측정만 주입 가능한 함수로 리팩터링**(`splitToLines(text, maxWidth, measure)`)해
  `domain/` 에 내려 빌드와 런타임이 같은 코드를 쓰게 하는 것이다. BP-33/BP-35 에 태스크로 넘길 것.
- **S-05** §24.10.1 변환기는 **부록 C-1** 과 연결하면 가치가 커진다:
  `MapModel.toJson()` 이 `events` 를 저장하지 않아 **세이브 로드 후 JSON 대사 티어가 통째로 죽는다**.
  즉 38건을 콘텐츠 팩으로 옮기는 것은 "정리" 가 아니라 **현존 버그의 해결**이다. 이 근거를 §24.10 서두에 추가 권장.
- **S-06** §24.4.3 의 4가지 근거는 이 기획서에서 가장 잘 논증된 대목이다.
  다만 근거 4("렌더 게이트가 이미 맞다")는 **`showMenu` 를 쓸 때만 성립**하는 조건부 이점이므로,
  BP-27 과 조정할 때 이 근거를 먼저 제시하면 설득이 빠르다.

---

## 6. 잘된 점

- **픽셀 예산 표(§24.5.1)가 실측과 일치한다.** 패딩·섹션 간격·헤더 블록·푸터 블록·480px 줄바꿈 폭까지
  `console_panel.dart` / `hd_config.dart` / `flutter_ui_host.dart` 와 대조해 **7개 항목 전부 정확**했고,
  `304 − 48 = 256 → 13행` 이 `HDConfig.maxLinesPerPage = 13` 주석의 계산과 독립적으로 재현된다.
  기획서 전체에서 코드 사실에 가장 깊이 닿은 절이다.
- **`addLog` 의 내부 flush 를 신뢰하지 않기로 한 판단(§24.5.3)이 정확하다.**
  `flutter_ui_host.dart:120` 의 `events.length >= 13` 는 실제로 헤더·메뉴 높이를 모르며,
  헤더가 있으면 11~13번째 줄이 패널 밖으로 밀린다는 지적이 코드상 옳다.
  `clearLogs` 가 헤더까지 지우므로 페이지마다 `setHeader` 를 다시 불러야 한다는 것도 `ui_host.dart:50-53` 그대로다.
- **`showMenu` vs `showWindowMenu` 결정(§24.4.3)이 4가지 독립 근거로 논증**되고, 그중 3가지를 코드로 확인했다
  (`select.dart:33-37` 주석 원문, `hd_game_main.dart:86` 게이트, `selection_window_data.dart:11/25` 치수).
- **`DV-12`(마지막 선택지는 무조건 표시 + `once` 아님)는 우수한 구조적 설계**다.
  `showMenu` 의 취소=0 을 "마지막 선택지" 로 안전하게 매핑하면서 `DV-05`(선택지 0개)를 **동시에** 보장한다.
- **사이클 정책(§24.8.3)이 퀘스트 Stage 와 다르게 가는 이유를 명시**하고 Tarjan SCC + 탈출 간선 + 소모성 간선의
  3중 방지를 의사코드로 제시한 것이 좋다. `repeatPool` 원소를 BFS 루트에 포함시키는 처리(§24.8.5 3번)도 정확하다.
- **레거시 cm2 대응표(§24.10.2, 24행)** 는 `script_engine_adapter.dart` 등록 커맨드와 대조했을 때 누락·오탈자가 없고,
  §24.10.3 의 `L1_ep1d1.cm2` 인용은 **원문과 문자 단위로 일치**한다.
- **2단계 생성(구조 → 문장) 권장(§24.11.4)** 은 Hard 게이트/Soft 게이트 분리와 정확히 대응하는 실용적 제안이다.
- 식별자 검증 통과(D-05 `do` 22종 정확), 미확정 표현 0건, 링크 15개 전부 해소,
  메타 블록·ID 접두사·표/다이어그램 비중·말미 3절 요약 **규약 완전 준수**.

---

## 7. 다른 장에 전파해야 할 발견

| 대상 | 전파 내용 |
|---|---|
| **BP-27** | §5.1~5.3 의 `DialogueRuntime` 규약 6항목이 BP-24 와 충돌(F-02). 특히 (a) `showWindowMenu` → `showMenu(clearLogs:false)`, (b) 취소=마지막 선택지, (c) `dialogue_choice` 를 effects **앞**에서 발행, (d) 페이지네이션을 런타임이 직접 수행, (e) `node.promptKey` 는 BP-24 스키마에 없는 필드, (f) `once` 저장소. **BP-24 를 SSoT 로 정정 권장** |
| **BP-25** | (1) `WorldState` 에 `dialogueVisits`/`choicesTaken`/`repeatPool` 커서가 **없다**(F-13). (2) `choice_made` vs `dialogue_choice` 이름 충돌(F-07). (3) §4.4 "지연 효과 한 개만" 과 `DV-19` "연쇄 4회" 의 양립 불가(F-03). (4) `repeatPool` 커서를 `vars` 에 두면 `var_changed` 가 대화마다 발행됨(F-14) — 이벤트를 내지 않는 저장 구획이 필요 |
| **BP-23** | (1) "기본 분기" 표현이 정반대(`QV-06` = `{"op":"true"}` 존재 / `DV-01` = `when` 부재) — 통일 필요(F-01). (2) `choose` objective 가 참조하는 `Choice.id` 는 BP-24 가 **D-07 에 없던 필드로 신설**한 것이므로 BP-23 §23.4.3(8) 의 `QV-03` 검사가 그 필드에 의존함을 명시. (3) BP-23 §23.2.3 은 감옥문을 여는 주체를 `gate_warden`(`isOn(45,8)`)으로, BP-24 §24.2.5 는 `lord_ahn` 으로 배정 — **두 장의 워크드 예제가 어긋난다** |
| **BP-26** | 앵커 `kind` ↔ `HDTileAction` 매핑이 §24.10.1 변환기의 `tileActionAt(...)` 전제다. 또 §24.10.1 이 만드는 임시 액터 `npc.core.unknown_<slug>` 의 수명·정리 정책(`Q-24-8`)을 액터 레지스트리 쪽에서 받아야 한다 |
| **BP-33** | `DV-*` 40개 중 판정 알고리즘이 제시된 것은 9개뿐이고 `DV-06c`/`DV-07`~`DV-07d` 는 정의 절조차 없다(§2). **규칙 전수 표는 BP-24 가 만들어야** BP-33 이 CLI 를 설계할 수 있다 |
| **BP-34** | (1) 사이클 허용 그래프의 **솔버 탐색 예산이 수치로 없다**(§24.8.4 는 "`maxDepth` × 선택지 조합" 이라고만 씀). `maxDepth 32` × 최대 6선택지면 최악 6³² — 가지치기 규칙이 필요. (2) `chance` 를 조건에 쓴 대화의 탐색 규칙 부재(F-09) |
| **BP-35 / BP-33** | S-04 — 빌드의 줄바꿈 계산기와 런타임 `HDTextUtils.splitToLines` 가 **같은 코드를 공유할 수 없는 구조**(TextPainter 의존). 폭 측정 주입형으로 리팩터링하는 태스크 필요 |
| **BP-41** | `Q-24-2`(헤더 0.5행)는 재계산 결과 문제가 아니므로 BP-41 이 재검토할 필요가 없다 — 닫아도 된다 |

---

## 8. 결정 재검토 요청 (기록만 — 결정은 유지)

| ID | 대상 | 근거 |
|---|---|---|
| RR-24-1 | **D-07 `entry` 의 기본 규칙 표기** | D-07 은 `entry: [ {when: Condition, go: nodeId} ]` 로 `when` 을 필수처럼 적었다. BP-24 는 마지막 원소의 `when` **부재**를 Hard 로 요구하고, BP-23 `QV-06` 은 정반대로 `{"op":"true"}` **존재**를 Hard 로 요구한다. D-05/D-06/D-07 수준에서 "기본 분기의 표기법" 을 한 번만 정해 주면 두 장의 충돌이 사라진다 |
| RR-24-2 | **D-07 `Choice` 에 `id` 가 없다** | `choose` objective(D-06)가 `choiceId` 를 참조하려면 `Choice.id` 가 필수다. BP-24 가 이미 추가했고 타당하나, D-07 골격에 반영해 두어야 BP-90(JSON Schema 원문)이 갈라지지 않는다 |
| RR-24-3 | **D-05 `chance` 를 `Choice.when`/`EntryRule.when` 에서 허용할 것인가** | 허용하면 `DV-04` 도달성 판정과 솔버 예산이 동시에 무너진다(F-09). v1 에서 `when` 계열의 허용 op 를 부분집합으로 좁히는 세부 결정을 권장 |
