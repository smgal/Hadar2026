# P1-13 퀘스트 저널 UI (800×480)

> **[보류 — DEFERRED]** 이 이슈는 **선언적 콘텐츠 팩 노선**에 속한다.
> 2026-09-01 2차 판정([DECISION-LOG](../DECISION-LOG.md))이 노선을 **sample-first + cm2** 로 바꾸면서 보류되었다.
> 원작은 퀘스트를 **플래그로** 표현하고(`assets/flag4ep1.cm2`), 그 방식이 이미 2,441줄 규모로 작동한다.
> 인벤토리·저널·선언적 모델은 **cm2 노선이 실제로 막힐 때** 그 지점에서 꺼내 쓴다.
> 설계는 [`blueprint/`](../../blueprint/00_README.md) 에 그대로 유효하게 남아 있다.

- **상태**: BLOCKED (P1-08 대기)
- **구간**: P1
- **규모**: M
- **선행**: P1-08
- **설계 근거**: [BP-41](../../blueprint/41_journal_ui_spec.md)(**소유 장** — 화면·행 배분·길이 예산·키 표·목업) · [BP-23 §23.10](../../blueprint/23_quest_model.md)(저널 데이터 모델·문구 생성) · [D-16-1](../../blueprint/_meta/DECISIONS.md)

## 문제

**"무엇을 해야 하는가" 를 확인할 화면이 없다.**

- 메인 메뉴 항목이 7개이고 임무·소지품이 없다.
  ```dart
  // hadar2026_app/lib/application/menu_flows.dart:34-43
  final choices = [
    "당신의 명령을 고르시오 ===>",
    "일행의 상황을 본다", "개인의 상황을 본다", "일행의 건강 상태를 본다",
    "마법을 사용한다", "초능력을 사용한다", "여기서 쉰다", "게임 선택 상황",
  ];
  ```
- 진행 정보는 콘솔 progress 레인으로 흘러가고 `HDConfig.maxProgressLines`(`hd_config.dart:58`) **200줄**이
  지나면 사라진다. 즉 퀘스트 목표가 스크롤백에 묻힌다.
- 오버레이 창 타입은 3종뿐이다 — `hadar2026_app/lib/presentation/input/window_key_dispatcher.dart:35-40` 의
  `_dispatch` 가 `HDMessageWindow`/`HDMagicSelectionWindow`/`HDSelectionWindow` 만 분기한다.
- 선택 창은 한 번에 6행만 보여준다 — `hadar2026_app/lib/domain/window/selection_window_data.dart:11`
  `final int maxVisibleItems = 6;` 이 **하드코딩**이라 메뉴에 항목을 추가하면 스크롤이 생긴다.

## 왜 지금 고쳐야 하는가

**AI 없이도 필요하다.** 저널이 없으면 퀘스트 상태가 **플레이어에게 관측 불가능**하다.
P1-08 이 상태 기계를 만들어도 화면이 없으면 저작자가 자기 퀘스트를 검증할 수 없고,
P1-16 의 "사람이 플레이해 완주" 판정이 "대사를 기억해서 완주" 가 된다.

MILESTONES §3 의 "퀘스트 저널에서 **진행 중 목표를 볼 수 있다**" 가 이 이슈의 직접 판정이다.

## 무엇을 할 것인가

**화면 스펙(행 배분·길이 상한·키 표·목업)은 [BP-41](../../blueprint/41_journal_ui_spec.md) 소유다. 재서술하지 않는다.**
신규 파일과 수정 지점의 정본 목록은 [BP-41 §41.10](../../blueprint/41_journal_ui_spec.md) 이다.

**신규 (5개)**

| 파일 | 타입 | 계층 |
|---|---|---|
| `hadar2026_app/lib/domain/window/journal_window_data.dart` | `HDJournalWindow extends HDWindow` + `HDJournalTab` + `HDJournalScreen` | `domain/` — `flutter/foundation` 만 |
| `packages/hadar_content/lib/journal_rows.dart` | `JournalListRow` · `JournalDetailView` · `JournalObjectiveRow` · `JournalPreviewRow` | 순수 Dart DTO. `hadar2026_app/lib/domain/content/journal_rows.dart` 는 배럴 |
| `hadar2026_app/lib/application/content/journal_presenter.dart` | `HDJournalPresenter`(싱글턴 + `reset()`) | `application/` — 정렬·필터·문구 자동 생성 |
| `hadar2026_app/lib/presentation/panels/journal_view.dart` | `HDJournalView` | `presentation/` |
| `hadar2026_app/lib/presentation/panels/tracker_bar.dart` | `HDTrackerBar` (512×24) | `presentation/` |

- **키 처리는 창 데이터가 갖지 않는다.** `HDJournalWindow` 는 표시 상태(`tab`/`cursor`/`scrollTop`/`screen`/`result`)만 보유한다 —
  기존 규약(`window_key_dispatcher` 가 타입 스위치로 라우팅)을 따른다.
- DTO 파일명은 **`journal_rows.dart`** 로 확정한다. 위젯이 `journal_view.dart` 라 이름이 겹치면 안 된다(BP-41 §41.10.2 주).
- 목록 미리보기 2행은 **빌드가 미리 잘라 굽는다**(R-41-14a) — 런타임에서 자르지 않는다.

**기존 수정 (6곳)** — 정본은 [BP-41 §41.10.5](../../blueprint/41_journal_ui_spec.md)

| 파일 | 지점 | 변경 |
|---|---|---|
| `presentation/panels/window_view.dart:67` | `_buildContent` | `HDJournalWindow` 분기 1개 |
| `presentation/input/window_key_dispatcher.dart:35-40` | `_dispatch` | `_handleJournal` 분기 1개 + 핸들러 |
| `presentation/panels/input_panel.dart` | `build` | `ListView` 를 `Column [ HDTrackerBar, Expanded(ListView) ]` 로 감쌈 |
| `domain/window/selection_window_data.dart:11` | 생성자 | `maxVisibleItems` 하드코딩 6 → **인자화**(기본 6). 메뉴 항목 추가로 스크롤이 생기는 것을 막는다 |
| `application/ports/ui_host.dart:26` | `showWindowMenu` | 선택 인자 `int maxVisible = 6` 추가 |
| `application/menu_flows.dart:34-43` | `showMainMenu` | 항목 추가 + `showQuestJournal()` 신규 |

**새 입력 모드를 만들지 않는다** — [BP-41 §41.5.2](../../blueprint/41_journal_ui_spec.md).
`HDInputMode.window` 로 충분하다. 진입 경로·키 표는 §41.5.1·§41.5.4 이고 `docs/key_input_policy.md` 를 준수한다.

**추적 바** — `HDTrackerBar` 다안 확정([BP-41 §41.6.3](../../blueprint/41_journal_ui_spec.md)).
알림 문구·색상은 §41.7.2, 오버레이 중 알림 지연(flush 규약)은 §41.7.3.
색상 태그는 `hd_text_utils.dart` 의 `colorTable` 실측 범위 안에서만 쓴다(§41.9.2).

**정렬 순서는 결정론이어야 한다**([BP-41 §41.3.5](../../blueprint/41_journal_ui_spec.md)) —
같은 `WorldState` 에서 같은 순서가 나와야 세이브 왕복·회귀 비교가 성립한다.

## 완료 판정 기준

- [ ] 메인 메뉴에 "임무" 항목이 있고, 선택하면 저널 창이 열린다 (플레이로 확인)
- [ ] 진행 중 퀘스트의 **현재 단계 목표**가 목록·상세 두 화면에서 보인다
- [ ] 탭 3종(진행 중 / 마친 일 / 실패)이 동작하고, 빈 상태에도 화면이 깨지지 않는다
- [ ] 메뉴 항목이 8개로 늘어도 스크롤이 생기지 않는다 (`maxVisible` 인자화가 동작)
- [ ] 추적 바가 512×24 이고 `input_panel` 최상단에 있으며, 맵 뷰포트·콘솔 좌표가 밀리지 않는다 (800×480 유지)
- [ ] 같은 `WorldState` 로 두 번 열면 목록 순서가 동일하다 (결정론)
- [ ] 대화 대기 중(`isWaitingForKey == true`)에 Space/Esc/Q 를 눌러도 저널이 **열리지 않는다**
- [ ] 계층 grep 2종 통과 — `journal_presenter.dart` 가 `presentation/` 을 import 하지 않는다
- [ ] **테스트 1**: `hadar2026_app/test/application/content/journal_presenter_test.dart` —
      페이크 `WorldState` → 정렬 순서·탭 필터·자동 문구 생성([BP-23 §23.10.3](../../blueprint/23_quest_model.md) 템플릿).
      `HDHosts().bind(...)` + `reset()` 패턴은 `test/application/map_navigation_test.dart:13-28`
- [ ] **테스트 2**: `hadar2026_app/test/presentation/input/journal_key_test.dart` —
      `HDWindowKeyDispatcher` 가 `HDJournalWindow` 를 `HDSelectionWindow` **보다 먼저** 잡는다
      (타입 스위치 순서 회귀 — `_dispatch` 의 `if` 순서가 바뀌면 깨진다)
- [ ] **테스트 3**: `hadar2026_app/test/presentation/input/journal_gate_test.dart` —
      **회귀** — 대화 대기 중 저널 진입 차단(R-41-9a). `input_dispatcher` 의 모드 우선순위가 바뀌면 이 테스트가 먼저 깨진다
- [ ] **테스트 4**: `packages/hadar_content/test/journal_budget_test.dart` —
      목록 행·목표 행·추적 바의 길이 예산 경계값([BP-41 §41.4](../../blueprint/41_journal_ui_spec.md))

## 하지 않을 것

- **소지품·장비 UI** — **P1-14**.
- 위젯 테스트로 실제 wrap 행 수를 검증하는 것(`journal_wrap_test.dart`) — 레포에 위젯 테스트 인프라가 없으므로
  P1 에서는 **길이 계산기 단위 테스트**로 대체한다. 위젯 테스트 도입은 별 이슈로 남긴다.
- 지도·미니맵·퀘스트 마커 — 범위 밖.
- 저널에서 퀘스트를 포기/재시작하는 기능 — 상태 기계에 되돌리기가 없다(D-06).
- 메인 메뉴 전면 재설계 — 항목 추가와 높이 확장([BP-41 §41.5.5](../../blueprint/41_journal_ui_spec.md))까지만.
- 다국어·폰트 교체 — `DungGeunMo` 고정.
