# 게임 진행 방식 변경점 총괄

> `상태: 보류` — **설계는 유효하나 현재 노선에서는 구현하지 않는다.**
> 지금 노선은 원작 방식(플래그 + cm2)의 **sample-first** 다 → [`issues/MILESTONES.md`](../issues/MILESTONES.md).
> 이 장이 필요해지는 신호는 [`issues/MILESTONES.md` §5](../issues/MILESTONES.md) 에 있다. **읽고 바로 구현하지 말 것.**

> **문서 ID**: BP-40 · **상태**: 초안 · **선행 문서**: [BP-27](27_runtime_engine.md), [BP-23](23_quest_model.md), [BP-25](25_world_state_and_save.md)
> **독자**: 게임 디자이너 · 런타임 구현자 · 검수 에이전트
> **한 줄 요약**: "지금의 게임 진행 방식에서 무엇이 바뀌어야 하는가" 에 대한 정면 답변 —
> D-16 의 필수 6개를 코드 수준까지 상세화하고, 원작 감성을 지키기 위해 **바꾸지 않을 것**을 먼저 못박는다.

**파이프라인 구획(D-01)**: 이 장은 **Runtime** 의 게임 규칙 변경을 다룬다. 콘텐츠 생성(Authoring)·빌드는 소관이 아니다.

**이 장이 다루지 않는 것**:
- 저널 화면의 픽셀 스펙 → [BP-41](41_journal_ui_spec.md)
- 아이템 카탈로그·인벤토리 규칙 → [BP-42](42_item_and_inventory.md)
- 텍스트 문체 → [BP-43](43_content_style_guide.md)
- Quest / Dialogue / WorldState 스키마 → [BP-23](23_quest_model.md) / [BP-24](24_dialogue_model.md) / [BP-25](25_world_state_and_save.md)
- 클래스 배치·훅 diff → [BP-27](27_runtime_engine.md) §7 (여기서는 **왜·무엇이 달라지는가**만 다룬다)

---

## 40.1 변경의 원칙

### 40.1.1 대전제 — 이 게임은 1993년 게임의 리메이크다

원작 "또 다른 지식의 성전" 의 조작감은 **아주 좁은 어휘**로 이루어져 있다.
방향키로 한 칸씩 움직이고, 마주 보고 확인키를 누르면 말을 걸고, 스페이스로 명령 메뉴를 연다.
화면에는 HUD 가 거의 없고, 콘솔에 글이 흘러간다.

퀘스트 시스템은 이 어휘에 **없던 개념**이다. 저널·목표 체크리스트·추적 마커는 전부 2000년대 이후의 관용구다.
따라서 이 장의 설계 기준은 "현대 RPG 처럼 만들기" 가 아니라 **"원작의 어휘를 최소한만 늘려 목표 추적을 성립시키기"** 다.

### 40.1.2 바꾸지 않는 것 (Freeze List)

아래는 **변경 금지**다. 이것들이 바뀌면 리메이크가 아니라 다른 게임이 된다.

| # | 동결 항목 | 실측 근거 | 왜 동결인가 |
|---|---|---|---|
| F-1 | 800×480 고정 픽셀 레이아웃 + `FittedBox` 스케일 | `hd_config.dart` `gameScreenWidth/Height`, `main.dart` | 화면 비율이 곧 원작의 인상. 반응형화하면 감성이 사라진다 |
| F-2 | 4방향 32px 격자 이동, 카메라 상시 플레이어 중심 | `HDConfig.tileSize=32`, `UI_SPEC.md` §2.1 | 대각선/부드러운 스크롤은 원작에 없다 |
| F-3 | 3뷰포트 구조(맵 288×320 / 대화 512×320 / 상태·진행 하단 160) | `hd_config.dart`, `main.dart` `Column>Row` | 레이아웃 개편은 전 패널 재작성 = 리스크 최대 |
| F-4 | 키 어휘: 이동 화살표·WASD / 확인 Enter·E / 취소·메뉴 Esc·Q·Space | `docs/key_input_policy.md`, `input_dispatcher.dart:118` | 새 전용 키(J, I, TAB 등) 추가 금지 (§40.4.4) |
| F-5 | 텍스트 중심 출력 — 대화는 콘솔에 흘러간다 | `console_panel.dart` `HDDialogPanel` | 말풍선·초상화 도입 금지 |
| F-6 | 전투 시스템(턴제, `maxEnemy` 3~7, 도주 판정) | `battle.dart` 538줄 | 퀘스트는 전투를 **호출**할 뿐 바꾸지 않는다 |
| F-7 | 마법/초능력 체계, `HDMagicSelectionWindow` | `magic_system.dart` 280줄 | 무관 |
| F-8 | 파티 6슬롯(5인 + 소환 1) 구조 | `party.dart` `List.generate(6, …)`, `status_panel.dart` `_summonSlotIndex=5` | 무관 |
| F-9 | `food`/`gold` 는 아이템이 아니라 파티 코어 값 | `PartyInventory{food,gold}`, D-05 가 `add_gold`/`add_food` 를 따로 둠 | 인벤토리화하면 원작의 "식량이 떨어지면 쉴 수 없다" 규칙이 흐려진다 |
| F-10 | 콘솔 진행 로그(`addLog(isDialogue:false)`)의 롤링 버퍼 방식 | `HDConfig.maxProgressLines=200` | 퀘스트 알림은 **이 레인을 재사용**한다. 새 알림 위젯을 만들지 않는다 |
| F-11 | 폰트 DungGeunMo 단일, `@X..@@` 색상 태그 규약 | `main.dart` `fontFamily:'DungGeunMo'`, `hd_text_utils.dart` `colorTable` | 무관 |
| F-12 | cm2 / 네이티브 맵 스크립트의 기존 동작 | D-10 이 Content tier 를 **위에** 얹기로 확정 | 기존 콘텐츠 무중단 |

### 40.1.3 변경을 승인하는 3가지 테스트

어떤 변경이 이 장에 들어오려면 세 질문에 전부 답해야 한다.

| 테스트 | 질문 | 실패 시 |
|---|---|---|
| **T-필요** | 이것이 없으면 D-06 의 **어떤 Objective kind 또는 Condition op 가 원리적으로 불가능한가**? 구체적으로 하나를 대라 | 1차 스코프에서 제외 |
| **T-최소** | 같은 목적을 **기존 어휘(기존 키·기존 패널·기존 `UiHost` 메서드)** 로 달성할 수 없는가? | 기존 어휘로 다시 설계 |
| **T-가역** | 콘텐츠 팩을 전부 비활성화했을 때 게임이 **변경 전과 똑같이** 동작하는가? | Freeze List 위반 — 반려 |

D-16 의 6개는 세 테스트를 전부 통과한다(§40.2 각 항목의 "왜 필수인가").
§40.5 의 선택 5종은 T-필요를 통과하지 못하거나 비용이 과다한 것들이다.

### 40.1.4 변경 예산

| 축 | 예산 | 근거 |
|---|---|---|
| 신규 메인 메뉴 항목 | **최대 2개** | 현행 7개 → 9개. `HDSelectionWindow.maxVisibleItems = 6` 을 이미 넘고 있어 스크롤이 걸린다(§40.4.3) |
| 신규 전역 키 | **0개** | F-4 |
| 신규 `UiHost` 포트 메서드 | **0개** | R-24-5(“출력은 현행 `UiHost` 인터페이스만”)와 일치 |
| 신규 오버레이 윈도우 클래스 | 최대 2개 (저널·소지품) | [BP-41](41_journal_ui_spec.md) / [BP-42](42_item_and_inventory.md) |
| 맵 화면 상시 HUD 추가 | **0px** | 맵 뷰포트는 288×320 뿐이다. 추적 표시는 진행 로그 패널로 (§40.3.4, [BP-41](41_journal_ui_spec.md) §6) |

---

## 40.2 D-16 의 필수 변경 6개 — 상세화

각 항목은 동일한 6개 절로 쓴다: **왜 필수인가 / 현행 동작 / 변경 후 동작 / 영향받는 코드 / 플레이어가 체감하는 차이 / 위험**.

---

### 40.2.1 C-1 퀘스트 저널 UI

#### 왜 필수인가

| 없으면 불가능해지는 것 | 근거 |
|---|---|
| **모든 `Objective` 가 플레이어에게 보이지 않는다** | D-06 의 Objective 는 9종 전부 "무엇을 해야 하는가" 를 전제한다. 화면에 없으면 플레이어는 `talk_to` 대상 NPC 를 알 수 없다 |
| `hidden:true` 목표의 의미가 사라진다 | BP-23 §23.10.4 는 `hidden` 을 "표시하지 않음" 으로 정의한다. 표시 자체가 없으면 `hidden` 은 no-op |
| `journal` stringKey 7종이 전부 죽는다 | BP-23 §23.10.2 의 `<questId>.title` / `.summary` / `.<stageId>.journal` / `.done` / `.failed` |
| `WorldState.journal`(append-only) 이 쓰기 전용 무덤이 된다 | [BP-25](25_world_state_and_save.md) §2.1 |

퀘스트가 3건을 넘는 순간 "지금 뭐 하던 중이었지" 가 게임을 멈춘다. 원작은 퀘스트가 **하나뿐**(Necromancer 봉쇄)이라 이 문제가 없었다.

#### 현행 동작

- 진행 중인 목표를 보여주는 화면이 **존재하지 않는다**. `grep -rn "quest" hadar2026_app/lib` 결과 **0건**(GROUND_TRUTH §10).
- 플레이어가 목표를 기억하는 유일한 수단은 콘솔 진행 로그 스크롤백(`HDDescriptionPanel`, 512×160, 최근 200줄).
  이 버퍼는 **맵 전환마다 비워진다**(`HDGameMain._onSessionChanged`) — 즉 다른 맵으로 가면 사라진다.

#### 변경 후 동작

- 메인 메뉴에 **"임무를 확인한다"** 항목 신설(§40.4.2).
- 선택 시 전용 오버레이 창(`HDJournalWindow`)이 열린다. 2단 깊이: **목록 → 상세**.
- 목록은 탭 3개(진행 중 / 완료 / 실패)를 ←→ 로 전환. 상세는 제목·요약·현재 단계 저널·목표 체크리스트.
- 창을 닫으면 정확히 이전 상태로 복귀. **게임 시간은 흐르지 않는다**(`HDGameSystem.passTime` 미호출).
- 픽셀·키·문자 수 상한은 전부 [BP-41](41_journal_ui_spec.md) 가 확정한다.

**반대 심문: 저널 화면이 콘솔(대화) 영역을 점유하면 진행 중이던 대화는 어떻게 되는가**

- **R-40-19 불변식**: **대화가 진행 중일 때는 저널·소지품을 열 수 없다.**
  초판은 "`showMainMenu` 이 이미 `beginNarrative`/`endNarrative` 로 감싸므로 안전"(RK-40-3) 이라고만 적었는데,
  그것은 "저널은 메인 메뉴에서만 열린다 → 메인 메뉴는 맵 모드에서만 열린다 → 대화 중에는 도달 불가" 라는
  **3단 추론을 독자에게 맡긴 것**이다. 불변식으로 못박는다.
- 실측 근거: Space/Esc/Q 를 메뉴로 해석하는 것은 `input_dispatcher.dart:118` 의 `_handleMap` **하나뿐**이고,
  `HDGameMain.currentInputMode` 는 `window > menu > dialogue > map` 우선순위(`hd_game_main.dart:159-164`)라
  대화 대기 중(`isWaitingForKey`)에는 `dialogue` 가 잡혀 `_handleMap` 에 도달하지 못한다.
- 따라서 **가려지는 것은 진행 중인 대화가 아니라 이미 닫힌 대화의 잔상**이다. 창을 닫으면
  `endNarrative()`(`menu_flows.dart:80`)가 원래 화면을 되돌리므로 별도 복원 로직이 필요 없다.
- **이 불변식은 티어 0 의 비동기 대화 그래프가 들어오면 깨질 수 있다** — "대화 중에 물건을 건넨다" 를
  원하게 되는 순간이 그 지점이다. 그때는 `beginNarrative` 중첩 규약이 선행이며, 1차 스코프에서는 그 문을 열지 않는다.
  회귀 1건은 [BP-42 T-42-7](42_item_and_inventory.md) / [BP-41 §41.10.7](41_journal_ui_spec.md) 이 받는다.

#### 영향받는 코드

| 파일 | 변경 |
|---|---|
| `hadar2026_app/lib/application/menu_flows.dart:33` | `showMainMenu` 의 `choices` 에 1항목 추가 + `switch` 인덱스 이동 |
| `hadar2026_app/lib/application/menu_flows.dart` (신규 메서드) | `showQuestJournal()` |
| `hadar2026_app/lib/domain/window/journal_window_data.dart` | **신규** — `HDJournalWindow` |
| `hadar2026_app/lib/presentation/input/window_key_dispatcher.dart:35` | `_dispatch` type-switch 에 분기 1개 추가 |
| `hadar2026_app/lib/presentation/panels/window_view.dart:67` | `_buildContent` 에 분기 1개 추가 |
| `hadar2026_app/lib/application/content/journal_presenter.dart` | **신규** — `WorldState` → 표시 행 변환 |

`UiHost` 포트는 **건드리지 않는다**. 저널 창은 `HDWindowManager` 스택에 올라가므로 기존 `HDInputMode.window` 가 그대로 커버한다(`hd_game_main.dart:160`).

#### 플레이어가 체감하는 차이

| | 변경 전 | 변경 후 |
|---|---|---|
| 메인 메뉴 항목 수 | 7 | **9** (저널 1 + 소지품 1, §40.4.2) |
| "뭐 하던 중이었지" 해결법 | 없음 (기억 또는 되돌아가서 NPC 재대화) | 메뉴 → 임무 → 목록 |
| 퀘스트 진행 알림 | 없음 | 진행 로그에 `[임무] …` 1줄 (F-10 재사용) |
| 조작 부담 | — | 키 3번(Space → ↓×7 → Enter) 추가. `임무를 확인한다` 는 최종 메뉴의 **8번**이고 커서는 1에서 시작하므로 ↓ 7번이다(`moveCursor` 순환을 쓰면 ↑×2). **새 키는 없음** |

#### 위험

| ID | 위험 | 완화 |
|---|---|---|
| RK-40-1 | 저널이 원작에 없던 UI 라 이질감 | §40.6 의 연출 3종. 특히 "임무" 라는 어휘와 두루마리 톤 |
| RK-40-2 | 메뉴 항목 9개 → `maxVisibleItems=6` 초과로 스크롤 발생 | 이미 7개에서 초과 중(§40.4.3). 창 높이 공식(`60 + n*34`)을 고쳐 9행까지 펼치는 안은 [BP-41 §41.5.5](41_journal_ui_spec.md) 가 확정했다(좌표까지 그 장 소유) |
| RK-40-3 | 저널 창이 `beginNarrative()` 사이클과 충돌 | `showMainMenu` 이 이미 `beginNarrative`/`endNarrative` 로 감싸고 있으므로 그 안에서 열면 안전(`menu_flows.dart:48`, `:80`) |

---

### 40.2.2 C-2 인벤토리 / 아이템 시스템

#### 왜 필수인가

| 없으면 불가능해지는 것 | 근거 |
|---|---|
| `Objective.kind = acquire(itemId, count)` | D-06 |
| `Objective.kind = deliver(itemId, actorId)` | D-06 |
| `Condition op = has_item(id, count)` | D-05 |
| `Effect do = give_item / take_item` | D-05 |
| 이벤트 `item_gained` / `item_lost` | BP-23 §23.11.1 (12종 중 2종) |

즉 **닫힌 집합의 9 kind 중 2개, 18 op 중 1개, 22 do 중 2개, 12 이벤트 중 2개가 통째로 죽는다.**
"열쇠를 구해 문을 연다", "약초를 캐서 학자에게 전한다" 같은 가장 기본적인 퀘스트 골격이 표현 불가능하다.

#### 현행 동작

```dart
// hadar2026_app/lib/domain/party/party.dart:13
class PartyInventory {
  int food = 100;
  int gold = 500;
}
```

- 소지품은 **정수 2개가 전부**. 아이템 목록이 없다.
- 장비는 `HDPlayer.weapon / shield / armor` 각 **정수 ID 1개**(`player.dart`).
- 이름은 플레이스홀더다:
  ```dart
  // hadar2026_app/lib/domain/party/player.dart
  String getWeaponName() => weapon == 0 ? "맨손" : "무기$weapon";
  String getShieldName() => shield == 0 ? "없음" : "방패$shield";
  String getArmorName()  => armor  == 0 ? "평상복" : "갑옷$armor";
  ```
  `showCharacterStatus()` 가 이 값을 그대로 찍으므로 화면에 **"사용 무기 - 무기1"** 이 나온다(`menu_flows.dart`).
- `assets/maps/books.json`(1,506바이트, 무기 5종·갑옷 3종)이 존재하지만 **앱 코드에서 한 번도 로드되지 않는다**(GROUND_TRUTH §6).
- cm2 에는 아이템 커맨드가 **아예 없다**(GROUND_TRUTH §9 등록 커맨드 전량). 원작의 "열쇠" 는 `Flag::Set(GFD0_GET_KEY_FOR_D1)` 처럼 **플래그로 흉내** 내고 있다 — 플래그를 **세우는** 쪽은 `assets/L1_ep1d0.cm2:134` 이고 화면 표기는 같은 파일 `:131`(`@B[경비병이 가지고 있던 열쇠+1]@@`)이다. `assets/L1_ep1d1.cm2` 는 `:58`·`:31` 에서 **읽기만** 하며 `Flag::Set` 이 한 줄도 없다.

#### 변경 후 동작

- 파티 공용 인벤토리 = `WorldState.inventory: Map<itemId,int>`([BP-25](25_world_state_and_save.md) §2.1). 신설 저장소를 만들지 않는다.
- 장비는 개인 소유로 남되 정수 ID 대신 아이템 ID 를 가리킨다.
- 메인 메뉴에 **"소지품을 살핀다"** 항목 신설(§40.4.2). 여기서 사용·장착·설명 보기가 일어난다.
- `food`/`gold` 는 **아이템화하지 않는다**(F-9).
- 상세는 전부 [BP-42](42_item_and_inventory.md).

#### 선행 과제 — **전투식 변경이 장비의 선행 과제인 범위** (부록 H-1)

부록 **H-1** 이 실측으로 확정했다: `powOfShield`/`powOfArmor` 는 **어떤 전투 규칙도 읽지 않는 죽은 필드**이고,
방어를 결정하는 것은 **`ac` 하나뿐**이다.

```dart
// hadar2026_app/lib/application/battle.dart:513-514  (파티가 맞을 때)
int damage = (e.strength * e.level * (Random().nextInt(10) + 1)) ~/ 10;
damage -= (t.ac * t.level.physical * (Random().nextInt(10) + 1)) ~/ 10;
```

`grep -rn "powOfShield\|powOfArmor" hadar2026_app/lib/` 결과는 **대입 · 직렬화 · `getAttribute`/`changeAttribute` 뿐**이다.
즉 **갑옷·방패를 바꿔도 `ac` 를 건드리지 않는 한 게임은 아무 반응도 하지 않는다.**

| 장비 설계 | 전투식 변경이 선행인가 | 소유 |
|---|---|---|
| 무기 `power` → `powOfWeapon`(전투식이 읽는 유일한 무기 수치) | **아니오** | [BP-42 §4.3](42_item_and_inventory.md) |
| 갑옷 + 방패의 `ac` **합산** → `ac`(전투식이 읽는 유일한 방어 수치) | **아니오** | [BP-42 R-42-30](42_item_and_inventory.md) |
| 방패를 `ac` 와 **별개 축**으로(막기 확률·피해 상한) | **예** — `battle.dart:513-514` 변경 | 미배정 |
| 무기 종류(`weaponType` = `stab`/`wield`/`chop`)별 상성 | **예** — `battle.dart:439` 변경. 현재 `weaponType` 참조 0건 | 미배정 |
| 방어구 부위별 감쇠 · 마법 방어 | **예** | 미배정 |

- **R-40-21** **1차 스코프의 장비는 전투식을 한 줄도 바꾸지 않는다.**
  [BP-42](42_item_and_inventory.md) 가 `ac` 합산으로 방패에 의미를 주어 그 필요를 제거했다.
  Freeze List **F-6**(전투 시스템 동결)이 이 판단의 근거이며, 동결과 장비 도입이 양립한다는 것이 요점이다.
- **R-40-22** **그러나 위 표 아래 3줄을 원하는 순간 전투식 변경이 선행 과제가 되고, 그것은 F-6 해제를 뜻한다.**
  F-6 해제는 이 장이 승인하지 않았다 — 해제하려는 장은 T-필요/T-최소/T-가역(§40.1.3)을 다시 통과해야 하고,
  [BP-42 §7.2·§7.3](42_item_and_inventory.md) 의 밸런스 기준값(난수 전수 열거로 얻은 기댓값·확률)을
  **함께 재계산**해야 한다. 그 사실을 [BP-50](50_roadmap.md) 이 로드맵 항목으로 들고 있어야 한다.
- **R-40-23** `powOfArmor`/`powOfShield` 는 **폐기 예정 필드**로 표시한다([BP-42 R-42-32](42_item_and_inventory.md)).
  값을 넣어도 무해하지만 **"이 값이 방어를 올린다" 고 쓰지 않는다** — 그 서술이 §40.2.2 가 고치려는
  "화면에 적어 놓고 실제로는 아무것도 안 일어난다" 와 같은 종류의 거짓이다.

#### 영향받는 코드

| 파일 | 변경 |
|---|---|
| `lib/domain/party/player.dart` | `equippedWeapon/Shield/Armor: String?` 추가, `getWeaponName()` 을 카탈로그 조회로 교체 |
| `lib/application/menu_flows.dart` | 메뉴 항목 1개 + `showInventory()` 신규 |
| `lib/domain/content/world_state.dart` (신규, D-11) | `giveItem`/`takeItem` — **이벤트 발행 지점 단 한 곳**([BP-27](27_runtime_engine.md) §7.5) |
| `assets/content/items/items.json` (신규) | 초기 20종 카탈로그 ([BP-42](42_item_and_inventory.md) §7) |
| `assets/maps/books.json` | `assets/_legacy/` 로 이동, 폐기 예정 표시 (R-22-22) |

#### 플레이어가 체감하는 차이

| | 변경 전 | 변경 후 |
|---|---|---|
| 인물 상황 화면의 장비 | `무기1`, `방패0`, `갑옷1` | `단검`, `없음`, `가죽갑옷` |
| 소지품 확인 | 불가 (식량/황금만 "일행의 상황" 에서) | 전용 화면 |
| 열쇠·증표 | 존재하지 않음 (플래그로만 흉내) | 실제 아이템으로 보이고 세어진다 |
| 회복약 사용 | 불가 | 소지품 → 사용 |

#### 위험

| ID | 위험 | 완화 |
|---|---|---|
| RK-40-4 | 아이템이 생기면 상점을 기대하게 된다 | §40.5.4 에서 상점을 **1차 스코프 제외**로 판정하고, 아이템 획득처를 `quest_reward`/`chest`/`npc_gift` 로 한정 (R-22-21) |
| RK-40-5 | 정수 장비 ↔ 아이템 ID 이중 진실 | cm2 `Player::ChangeAttribute('weapon', n)` 호환을 위해 정수 필드는 유지하되 **표시는 아이템 ID 우선**([BP-42](42_item_and_inventory.md) §4) |
| RK-40-6 | 인벤토리 무한 증식으로 세이브 팽창 | 종류 상한 48종([BP-42 §2.4](42_item_and_inventory.md)). 48×34B ≈ 1.6KB — 무시 가능. 단 **버릴 수 없는 `quest`/`key`/`relic` 은 상한 밖**이다([BP-42 R-42-11](42_item_and_inventory.md)) — 상한이 자력 복구 불가 상태를 만들지 못하게 하는 조치이며, 실제 방어선은 빌드 린트다 |

---

### 40.2.3 C-3 조건부 대화

#### 왜 필수인가

| 없으면 불가능해지는 것 | 근거 |
|---|---|
| 퀘스트 의뢰 자체 | 의뢰인은 "수주 전 / 진행 중 / 완료 후" 세 상태에서 다른 말을 해야 한다. 같은 말만 하면 퀘스트를 받았는지 알 수 없다 |
| `Objective.kind = deliver` | 전달은 "가져왔는가" 를 대화가 판정해야 성립 |
| `Objective.kind = choose(dialogueId, choiceId)` | 선택지 자체가 없으면 불가 |
| `Dialogue.entry` 규칙 전량 | D-07 |

#### 현행 동작 (3티어 실측)

`HDTileEventDispatcher._dispatchScripted` 의 현재 우선순위(GROUND_TRUTH §4):

| 티어 | 조건 분기 가능? | 실측 |
|---|---|---|
| 네이티브 맵 스크립트 | **불가능** | `HDMapScript.isFlagSet` 이 `return false;` 스텁 (부록 A-3). 모든 조건이 항상 거짓 |
| cm2 페어링 | 가능하나 취약 | `Flag::IsSet` 은 동작하지만, 미등록 함수가 조용히 0 을 반환해 오분기(GROUND_TRUTH §9) |
| JSON `dialogLines` | **불가능** | `_emitJsonDialog` 는 좌표 일치 첫 이벤트의 대사를 **무조건** 순서대로 출력. 조건도 상태 참조도 없다(GROUND_TRUTH §4) |

게다가 세이브를 한 번 불러오면 JSON 티어는 **영구 사망**한다 — `MapModel.toJson()` 이 `events` 를 저장하지 않기 때문(부록 C-1).

#### 변경 후 동작

- D-10 이 확정한 대로 **티어 0(Content tier)** 을 맨 위에 삽입한다. 앵커가 있는 좌표면 `ContentRuntime` 이 처리하고 종료.
- 대화는 `Dialogue.entry`(위에서부터 첫 `true`)로 진입 노드를 고른다(D-07, [BP-24](24_dialogue_model.md) §24.3).
- 표준 분기 패턴 3종은 [BP-24](24_dialogue_model.md) §24.3.3 이 확정: 퀘스트 3상태 / 스테이지 세분 / 첫 만남·재방문.
- **앵커가 없는 좌표는 기존 3티어가 그대로 돈다** — 무중단.

#### 영향받는 코드

| 파일 | 변경 |
|---|---|
| `lib/application/tile_event_dispatcher.dart` (180줄) | `_dispatchScripted` 맨 앞에 Content tier 조회 + `handled` 조기 반환 ([BP-27](27_runtime_engine.md) §4.2) |
| `lib/application/scripting/map_script.dart:41-48` | 스텁 `isFlagSet`/`setFlag` 를 `HDNativeScriptRunner` 로 위임 (부록 A-3 해소) |
| `lib/application/content/dialogue_runtime.dart` (신규) | 노드 순회 + `UiHost` 출력 |
| `lib/domain/map/map_model.dart:50` | `toJson`/`fromJson` 에서 `events` 는 계속 저장하지 않되, 세이브 v2 가 `currentMapName` 으로 원본을 재로드해 복원 (부록 C-1 해소, [BP-25](25_world_state_and_save.md) §5.3) |

#### 플레이어가 체감하는 차이

| | 변경 전 | 변경 후 |
|---|---|---|
| 같은 NPC 에 두 번 말 걸기 | 항상 같은 대사 | 상태가 바뀌었으면 다른 대사 |
| 선택지 | cm2 `Select::Run` 이 있는 맵에서만 | 모든 콘텐츠 대화에서 |
| 세이브 로드 후 NPC 대사 | **사라짐**(부록 C-1) | 정상 |

#### 위험

| ID | 위험 | 완화 |
|---|---|---|
| RK-40-7 | 티어 0 삽입이 기존 cm2 를 가로챈다 | 앵커가 **있는 좌표에서만** 개입. 앵커 파일이 없는 맵은 조회 비용도 0(`TriggerIndex` 해시 미스) |
| RK-40-8 | `_isScriptRunning` 재진입 가드와 비동기 대화 그래프의 충돌 | D-10 이 "한 번에 하나의 상호작용" 으로 의미 고정 + 테스트로 못박기로 이미 결정 |
| RK-40-9 | NPC 가 말이 많아져 원작 리듬이 깨짐 | [BP-24](24_dialogue_model.md) §24.5.5 의 길이 상한(1줄 45자 Hard, 노드 3페이지 Hard)이 이미 강제 |

---

### 40.2.4 C-4 이름 있는 전역 상태

#### 왜 필수인가

| 없으면 불가능해지는 것 | 근거 |
|---|---|
| `Condition op = flag(id)` / `var_cmp(id,…)` | D-05 는 **문자열 ID** 를 받는다. 현재는 0~255 정수뿐 |
| `quest_state` / `quest_stage` op | 퀘스트 상태를 담을 저장소가 없다 |
| 세이브 후 퀘스트 재개 | `HDNativeScriptRunner.flags/variables` 는 **저장되지 않는다**(GROUND_TRUTH §8) |
| 맵을 넘나드는 퀘스트 | `HDScriptEngine.variables` 는 맵 전환마다 전멸(GROUND_TRUTH §9) |

#### 현행 동작 — 3중 분열

| # | 저장소 | 타입 | 수명 | 세이브 |
|---|---|---|---|---|
| S1/S2 | `HDGameOption.flags` / `.variables` | `List<bool>(256)` / `List<int>(256)` | 프로세스 | **O** |
| S3/S4 | `HDNativeScriptRunner.flags` / `.variables` | `Map<int,bool>` / `Map<int,int>` | 프로세스 | **X** |
| S5 | `HDScriptEngine.variables` | cm2 엔진 내부 | **맵 하나** | **X** |

전부 이름 없는 정수 인덱스이고, 의미는 `assets/const.cm2` 나 주석에만 존재한다.
게다가 A-2(“cm2 로드 실패가 엔진 상태를 누수시킨다”)와 겹쳐, 실제로는 **이전 맵의 스크립트 상태가 남은 채** 다음 맵이 돈다.

#### 변경 후 동작

- 단일 저장소 `WorldState`([BP-25](25_world_state_and_save.md) §2)로 통합. 키는 `flag.<pack>.<domain>.<name>` / `var.<pack>.<domain>.<name>`(D-04).
- 세이브 v2 가 `worldState` + `legacy.nativeFlags/nativeVariables` + `currentMapName` 을 담는다([BP-25](25_world_state_and_save.md) §5.1).
- v1 세이브는 `legacyFlagMap` 역참조로 무손실 마이그레이션(D-08).
- 벽시계 대신 **논리 시각 `step`**(D-08a). 퀘스트/저널의 모든 시각 필드가 이것을 쓴다.

#### 영향받는 코드

| 파일 | 변경 |
|---|---|
| `lib/application/save_manager.dart:18` | v1 → v2 포맷([BP-27](27_runtime_engine.md) §7.3) |
| `lib/application/save_manager.dart:86` | `setNewMap` 직접 호출 → `loadMapFromFile` 경유 (부록 C-2 해소) |
| `lib/application/game_session.dart` | `currentMapName` 필드 신설 |
| `lib/application/scripting/script_engine_adapter.dart:362` 부근 | `Flag::Set` 이 `legacyFlagMap` 역참조로 `flag_changed` 도 발행 |
| `lib/domain/party/player.dart:71` | `DateTime.now()` 데미지 → `WorldRng` ([BP-27](27_runtime_engine.md) §9) |

#### 플레이어가 체감하는 차이

거의 없다 — **그게 목표다.** 다만 세 가지 버그가 사라진다.

1. 세이브·로드 후 네이티브 맵 스크립트가 죽어 있던 문제(부록 C-2)
2. 세이브·로드 후 JSON 대사가 전부 사라지던 문제(부록 C-1)
3. 세이브 파일 크기 570KB → 수 KB([BP-25](25_world_state_and_save.md) §5.4 `mapDelta`)

#### 위험

| ID | 위험 | 완화 |
|---|---|---|
| RK-40-10 | v1 세이브 마이그레이션 실패 | [BP-25](25_world_state_and_save.md) §6.5 가 사용자에게 보이는 동작까지 규정 |
| RK-40-11 | cm2 가 여전히 정수 플래그를 씀 → 이중 진실 | `gameOption` 을 v2 에 **병존**시키고 `legacyFlagMap` 으로 양방향 동기 ([BP-28](28_migration_and_coexistence.md)) |

---

### 40.2.5 C-5 NPC 정체성

#### 왜 필수인가

| 없으면 불가능해지는 것 | 근거 |
|---|---|
| `Objective.kind = talk_to(actorId)` | D-06. 좌표로는 "누구와" 를 표현할 수 없다 |
| `Condition op = npc_state(id, state)` | D-05 |
| `Effect do = set_npc_state(id, state)` | D-05 |
| 이벤트 `talk` 의 payload `{actorId, …}` | BP-23 §23.11.1 |
| 저널의 자동 문구 `{actorName}와(과) 이야기한다` | BP-23 §23.10.3 |

#### 현행 동작

- NPC 는 **좌표에만 존재한다**. `_emitJsonDialog` 는 `map.events` 를 선형 탐색해 `(x,y)` 가 일치하는 **첫 이벤트**의 대사를 출력한다(GROUND_TRUTH §4).
- cm2 도 마찬가지다 — `if (On(18,12))` 처럼 좌표 리터럴로 분기한다(`assets/L1_ep1d1.cm2`).
- 결과: **맵 에디터로 NPC 를 한 칸 옮기면 그 NPC 의 대사가 사라진다.**
  D-14 4단계(bind)에서 AI 가 맵을 편집하는 이상 이건 상시 발생하는 사고다.
- 게다가 좌표당 이벤트가 **1개만 유효**하므로, 같은 칸에 두 개의 의미를 둘 수 없다.

#### 변경 후 동작

- D-09 의 **앵커**가 `actorId ↔ (map,x,y)` 를 잇는다. 대사는 액터에 붙고, 좌표는 앵커 파일이 소유한다.
- NPC 를 옮기면 `anchors/<MAP>.json` 의 `x,y` 만 바뀐다. 대사·퀘스트·상태는 그대로 따라온다.
- 앵커 좌표가 통행 규칙과 어긋나면 **빌드가 실패**한다(D-09) — "말 걸 수 없는 NPC" 가 커밋되지 않는다.
- 액터 스키마·상태 집합은 [BP-22](22_world_bible_model.md) §5, 앵커는 [BP-26](26_entity_registry_and_anchors.md) 소관.

#### 영향받는 코드

| 파일 | 변경 |
|---|---|
| `lib/application/content/trigger_index.dart` (신규) | `(map,x,y,kind) → 핸들러` O(1) 조회 |
| `lib/application/tile_event_dispatcher.dart` | 티어 0 에서 위 인덱스 조회 |
| `tools/mapEditor/server/ai_api.ts` (828줄) | 앵커 CRUD 추가 ([BP-36](36_map_editor_extension.md)) |

#### 플레이어가 체감하는 차이

| | 변경 전 | 변경 후 |
|---|---|---|
| 저널의 목표 문구 | 표현 불가 | `문지기와 이야기한다` — **이름으로** 지시 |
| NPC 이름 헤더 | cm2 가 `SetHeader` 를 직접 쓴 곳만 | 액터가 있으면 항상 |
| 아직 이름을 모르는 NPC | 개념 없음 | `낯선 사내` → 만난 뒤 실명 ([BP-24](24_dialogue_model.md) §24.6.4) |

#### 위험

| ID | 위험 | 완화 |
|---|---|---|
| RK-40-12 | 맵 이름 해석이 깨져 있어 앵커 키가 안 맞는다 | **선결 과제**. 부록 D-1 — 등록된 15개 이름 중 **7개가 존재하지 않는 파일로 해석**된다. T-22-1(`MapInfos.json` 에 `json` 필드 추가 또는 폴백 우선순위 반전) 완료 전에는 앵커를 붙일 수 없다 |
| RK-40-13 | 좌표당 1개 제한이 앵커에도 전이 | 앵커는 리스트이므로 같은 좌표에 여러 kind 가능. 단 `actor` 는 좌표당 1개로 린트 |

---

### 40.2.6 C-6 월드 이벤트 버스

#### 왜 필수인가

| 없으면 불가능해지는 것 | 근거 |
|---|---|
| 목표의 **자동 진행** 전부 | BP-23 §23.11.2 매핑표 — 9 kind 가 전부 이벤트로만 진행된다 |
| `defeat` 목표 | 전투 승리를 퀘스트가 알 방법이 없다 |
| `reach` 목표 | 이동/맵 전환을 퀘스트가 알 방법이 없다 |
| `failConditions` 재평가 | 12 이벤트 전부가 실패 조건 재평가 트리거(BP-23 §23.11.2 `F` 열) |
| 헤드리스 트레이스(D-13) | 이벤트 로그가 곧 트레이스 JSON |

이벤트 버스가 없으면 "퀘스트 진행" 은 **대화 중에 명시적으로 `advance_quest` 를 부를 때만** 일어난다.
그러면 `defeat`/`acquire`/`reach` 는 전부 "그 뒤에 NPC 에게 돌아가서 말을 걸어야 인정" 이 되어, 목표 kind 가 사실상 `talk_to` 하나로 붕괴한다.

#### 현행 동작

- 이벤트 개념이 없다. 서브시스템 간 통지는 `ChangeNotifier` 로만 이루어지고, 이는 **"뭔가 바뀌었다"** 만 알릴 뿐 **무엇이** 는 알리지 않는다.
- 전투 승리 후 하는 일은 로그 출력과 exp/gold 가산뿐(`battle.dart:236-248`).
- 이동은 `presentation/panels/player_sprite.dart` 의 `update(dt)` 폴링 안에서 처리된다(부록 B-3) — `application/` 이 이동을 관측할 수 없다.

#### 변경 후 동작

- `WorldEventBus`(D-11)가 **12종 닫힌 집합**(BP-23 §23.11.1)을 발행한다.
- 발행은 **배치(batch)** 단위다. 한 상호작용이 끝날 때 큐를 드레인하고, 그 안에서 순서를 보존한다(BP-23 §23.11.3).
- `deliver` 는 같은 배치의 `talk` + `item_lost` 조합을 본다 — 그래서 배치 경계가 규범이다.
- Effect 가 유발한 이벤트도 같은 배치에 들어가며, 연쇄는 8회 상한으로 차단(BP-23 §23.3.4).

#### 영향받는 코드 (발행 지점 5곳 — [BP-27](27_runtime_engine.md) §7)

| 이벤트 | 발행 지점 | 현재 상태 |
|---|---|---|
| `battle_won` | `battle.dart:240` 승리 분기(`if (_battleResult == 1)`) | 훅 없음 → 추가 |
| `map_changed` / `enter_place` | `game_session.dart` `loadMapFromFile` | 훅 없음 → 추가 |
| `item_gained` / `item_lost` | `MutableWorldState.giveItem/takeItem` **단 한 곳** | 인벤토리 자체가 없음 → [BP-42](42_item_and_inventory.md) 가 신설 |
| `step_tile` | `tile_event_dispatcher.dart:41` | 진입점은 있으나 발행 없음 |
| `talk` / `dialogue_choice` | `ContentRuntime` / `DialogueRuntime` | 신규 |
| `gold_changed` | `battle.dart:261`, `add_gold` | 훅 없음 → 추가 |
| `party_rested` | `menu_flows.dart` `restHere` 완료 후 | 훅 없음 → 추가 |
| `flag_changed` / `var_changed` | Effect 적용 후 + cm2 `Flag::Set` 레거시 경로 | 신규 |

> **선결 과제(부록 B-3)**: `step_tile` 과 `reach` 목표는 이동을 관측해야 하는데,
> 이동 판정이 `presentation/panels/player_sprite.dart:103 update(dt)` 안에 있다.
> **이동·상호작용 루프를 `application/` 으로 추출**하는 작업이 C-6 의 전제다([BP-34](34_headless_sim_and_solver.md)).

#### 플레이어가 체감하는 차이

| | 변경 전 | 변경 후 |
|---|---|---|
| 적을 3기 잡았을 때 | 아무 일도 안 일어남 | `[임무] Black Knight 3기를 쓰러뜨린다 (3/3)` 이 진행 로그에 |
| 아이템을 주웠을 때 | — | 목표가 그 자리에서 완료 |
| 지역에 도착했을 때 | — | 단계가 자동 전이 |

**핵심 체감**: "NPC 에게 돌아가야만 인정" 이 사라진다. 이것이 §40.3 의 루프 변화의 실체다.

#### 위험

| ID | 위험 | 완화 |
|---|---|---|
| RK-40-14 | 이동마다 이벤트 발행 → 성능 | `step_tile` 은 `TriggerIndex` 해시 조회 1회 + 관심 퀘스트 0건이면 즉시 반환([BP-27](27_runtime_engine.md) §6.3) |
| RK-40-15 | 이동 루프 추출이 Bonfire 렌더와 얽힘 | 스프라이트는 **애니메이션만** 담당하고 판정은 application 이 갖는 형태로 분리. `PartyMovementHost` 포트가 이미 그 방향 |
| RK-40-16 | 전투 결과 코드가 cm2 상수와 정반대(부록 B-2) | `battle_won` 발행 전에 **어느 쪽을 정본으로 삼을지** 확정해야 한다([BP-27](27_runtime_engine.md) 결정 사항). 잘못 고르면 패배가 승리로 발행된다 |

---

### 40.2.7 6개의 의존 순서

```
                 [C-4 이름 있는 전역 상태]
                    │  WorldState / 세이브 v2
                    ├───────────────┬────────────────┐
                    ▼               ▼                ▼
        [C-2 아이템/인벤토리]  [C-5 NPC 정체성]   [C-6 월드 이벤트 버스]
                    │           (앵커/TriggerIndex)   │  ※ 선결: 이동 루프 추출(B-3)
                    │               │                │
                    └──────┬────────┴────────┬───────┘
                           ▼                 ▼
                  [C-3 조건부 대화]    (목표 자동 진행)
                           │                 │
                           └────────┬────────┘
                                    ▼
                          [C-1 퀘스트 저널 UI]
```

- **C-4 가 뿌리다.** 이름 있는 상태 없이는 나머지 다섯 개가 전부 정수 인덱스 위에 쌓인다.
- **C-1 이 맨 끝이다.** 저널은 나머지가 만들어 낸 상태를 **보여줄 뿐**이므로 가장 늦게 붙어야 한다.
- C-5 는 부록 D-1(맵 이름 해석 파손) 해결에, C-6 은 부록 B-3(이동 루프 위치)에 각각 막혀 있다.

---

## 40.3 플레이 루프 비교

### 40.3.1 현행 루프 (실측)

```
        ┌──────────────────────────────────────────────┐
        │                                              │
        ▼                                              │
  ┌───────────┐   방향키/WASD   ┌──────────────┐        │
  │  맵 모드   │───────────────▶│ 한 칸 이동    │        │
  │(map mode) │                │ passTime()   │        │
  └───────────┘                └──────┬───────┘        │
    │      │                          │                │
    │      │ Space/Esc/Q              ▼                │
    │      │                   ┌──────────────┐        │
    │      │                   │ 인카운터 판정 │──전투──┐│
    │      │                   └──────┬───────┘       ││
    │      │                          │ 없음           ││
    │      ▼                          ▼                ││
    │  ┌────────────┐          ┌──────────────┐        ││
    │  │ 메인 메뉴   │          │ step-on 타일  │        ││
    │  │ (7항목)    │          │ event/enter  │        ││
    │  └─────┬──────┘          └──────┬───────┘        ││
    │        │                        │                ││
    │        ▼                        ▼                ││
    │  상황/마법/휴식/저장      ┌──────────────┐         ││
    │                        │ 3티어 디스패치 │         ││
    │ Enter/E (마주보고)      │ native/cm2/  │         ││
    └───────────────────────▶│ JSON 대사     │         ││
                             └──────┬───────┘         ││
                                    │                  ││
                                    ▼                  ││
                             ┌──────────────┐          ││
                             │ 콘솔에 글이   │◀─────────┘│
                             │ 흘러간다      │  exp/gold │
                             └──────┬───────┘           │
                                    └───────────────────┘
```

**성질**: 완전한 **장소 주도(place-driven)** 루프다. 플레이어가 어디로 갈지는 게임이 알려주지 않는다.
목표는 오직 하나 — "Necromancer 를 봉쇄하라"(`assets/town2.cm2` 의 Lord Ahn 대사) — 이며,
그 사이의 모든 것은 탐색으로 스스로 발견해야 한다.

### 40.3.2 변경 후 루프

```
        ┌───────────────────────────────────────────────────────────┐
        │                                                           │
        ▼                                                           │
  ┌───────────┐   방향키/WASD   ┌──────────────┐                    │
  │  맵 모드   │───────────────▶│ 한 칸 이동    │                    │
  └───────────┘                │ passTime()   │                    │
    │   │   │                  │ ★ step +1    │                    │
    │   │   │                  └──────┬───────┘                    │
    │   │   │                         │                             │
    │   │   │                         ▼                             │
    │   │   │                  ┌──────────────┐   ★ step_tile /     │
    │   │   │                  │ 인카운터/타일 │──── map_changed ───┐│
    │   │   │                  └──────┬───────┘     발행           ││
    │   │   │ Enter/E                 │                            ││
    │   │   └────────────────────────▶│                            ││
    │   │                             ▼                            ││
    │   │                      ┌───────────────────┐               ││
    │   │                      │ ★ 티어0 Content   │               ││
    │   │                      │   앵커 있음?       │               ││
    │   │                      └──┬────────────┬───┘               ││
    │   │                     예  │            │ 아니오             ││
    │   │                         ▼            ▼                    ││
    │   │              ┌──────────────────┐  ┌────────────┐         ││
    │   │              │ 조건부 대화 그래프 │  │ 기존 3티어  │         ││
    │   │              │ entry → node …   │  │ (무변경)    │         ││
    │   │              └────────┬─────────┘  └─────┬──────┘         ││
    │   │                       │ ★ talk /         │                ││
    │   │                       │   dialogue_choice│                ││
    │   │                       └─────────┬────────┘                ││
    │   │                                 ▼                         ││
    │   │                        ┌──────────────────┐               ││
    │   │                        │ ★ WorldEventBus  │◀──────────────┘│
    │   │                        │   배치 드레인     │   battle_won   │
    │   │                        └────────┬─────────┘   item_gained  │
    │   │                                 │                          │
    │   │                                 ▼                          │
    │   │                        ┌──────────────────┐                │
    │   │                        │ ★ QuestRuntime   │                │
    │   │                        │ 목표 진행/단계 전이│                │
    │   │                        └────────┬─────────┘                │
    │   │                                 │                          │
    │   │                                 ▼                          │
    │   │                        ┌──────────────────┐                │
    │   │                        │ 진행 로그 1줄     │────────────────┘
    │   │                        │ [임무] … (2/3)   │
    │   │                        └──────────────────┘
    │   │ Space/Esc/Q
    │   ▼
    │ ┌─────────────────┐
    │ │ 메인 메뉴 (9항목) │
    │ └───┬─────────┬───┘
    │     │         │
    │     ▼         ▼
    │ ★ 임무    ★ 소지품
    │  (저널)    (인벤토리)
    └─────────────────────
```

### 40.3.3 무엇이 늘고 무엇이 사라지는가

| | 늘어나는 것 | 사라지는 것 |
|---|---|---|
| **플레이어 행동** | 저널 확인(메뉴 8번), 소지품 확인(메뉴 7번) | "메모장에 목표를 적어 두기" |
| **정보** | 현재 목표·진행률·완료 이력이 게임 안에 있음 | 목표를 **스스로 추론**하는 즐거움의 일부 |
| **피드백** | 목표 진행 시 진행 로그 1줄 | 무반응(아무 일도 안 일어남) |
| **NPC** | 상태별로 다른 대사, 이름 헤더 | "몇 번을 말 걸어도 똑같다" 는 정적인 감각 |
| **아이템** | 열쇠·증표·약초가 실제로 세어짐 | 플래그로 흉내 낸 소지품(`GFD0_GET_KEY_FOR_D1`) |
| **세이브** | 퀘스트/인벤토리/맵 이름 저장, 570KB→수 KB | 맵 전체 스냅샷 |
| **루프의 성질** | 목표 주도(goal-driven) 층이 **추가**됨 | — (장소 주도 층은 **그대로 남는다**) |

> **중요**: 이 표에 "탐색이 사라진다" 는 없다. 저널은 목표를 **알려주지만 길은 알려주지 않는다** —
> `reach` 목표의 저널 문구는 `{placeName}(으)로 간다` 이지 경로가 아니다(BP-23 §23.10.3).
> 미니맵도 목적지 마커도 넣지 않는다(§40.5 에서 판정).

### 40.3.4 "맵을 걷다 대화하고 싸운다" → "목표를 받고 추적하고 완료한다"

두 루프는 **대체 관계가 아니라 포함 관계**다.

```
변경 후 =  [기존 루프 전부]  +  [목표 층]

목표 층 =  수주(대화) → 추적(저널/진행 로그) → 진행(월드 이벤트) → 완료(보상)
                ▲                                        │
                └────────────── 후속 퀘스트 ───────────────┘
```

- 콘텐츠 팩을 비활성화하면 목표 층 전체가 사라지고 **기존 루프만 남는다**(T-가역, §40.1.3).
- 이것이 D-10 의 "앵커가 없는 맵에서는 기존 3티어가 그대로 보존" 과 같은 말이다.

### 40.3.5 앵커가 **조작 방식에 따라 다르게 발화한다** (부록 K — 플레이 체감 변경점)

D-27 이 region 예약을 폐기하고 **"콘텐츠 티어는 타일 비트를 거치지 않고 트리거 인덱스를 직접 조회한다"** 로
확정했다(근거: 부록 **J-1** — region 값은 `ixEvent` 하위 바이트에 들어가고 마스크는 상위 바이트만 보므로
**어떤 region 값도 타일 액션을 만들지 못한다**). 그 결과 **앵커는 맵 데이터에 아무 표시도 남기지 않는다.**

그런데 부록 **K** 가 새 사실을 확정했다 — `HDGameMain().checkTileEvent(...)` 를 부르는 곳은
`presentation/panels/player_sprite.dart` 에 **3개**뿐이고, **선검사(게이트)의 유무가 서로 다르다.**

| 진입점 | 줄 | 호출 | presentation 게이트 | D-27 성립? |
|---|---|---|---|---|
| **이동 완료(step-on)** | `:193` | `checkTileEvent(party.x, party.y, isInteraction: false)` | **없음** | ✅ **코드 변경 없이** |
| **확인키 상호작용** | `:405` | `checkTileEvent(targetX, targetY, isInteraction: true)` | **없음** | ✅ **코드 변경 없이** |
| **이동 차단 시 상호작용(bump)** | `:359` → `:362` | `checkTileEvent(nextX, nextY, isInteraction: true)` | **있음** — `if (action.isInteractive)` | ❌ **비대칭** |

**플레이어가 무엇을 겪는가**

- step-on 과 확인키는 선검사가 없으므로, 앵커를 `move`/`swamp` 같은 평범한 칸에 놓아도 **그대로 발화한다.**
  (BLOCK 칸에서 step-on 이 발화하지 않는 것은 "거부" 가 아니라 **호출 부재**다 — 그 칸으로 이동이 완료되지 않는다.)
- 그런데 `:359` 의 `if (action.isInteractive)` 는 **presentation 계층이 콘텐츠 발화 여부를 결정하는 유일한 지점**이다.
  → **벽을 향해 걸어 부딪히는 방식으로는** 통행 불가 타일(talk/sign/enter) 위의 앵커만 잡히고,
  **확인키로는** 같은 앵커가 잡힌다.
- 즉 **같은 앵커가 조작 방식에 따라 다르게 동작한다.** 원작 습관대로 "벽에 부딪혀 말 걸기" 를 쓰는 플레이어와
  "마주 보고 Enter" 를 쓰는 플레이어가 **다른 게임을 하게 된다** — 이것은 UI 문제가 아니라 진행 방식의 변경점이다.

| ID | 규범 |
|---|---|
| **R-40-24** | 이 비대칭은 **1줄 수준의 변경으로 해소한다** — `:359` 의 게이트를 제거하거나, 콘텐츠 인덱스 조회를 그 게이트보다 **앞세운다.** 코드 스케치는 [BP-27 Q-27-10](27_runtime_engine.md) 소유 |
| **R-40-25** | 해소 전까지 콘텐츠 저작 규칙: **앵커를 통행 가능한 칸에 두면 bump 로는 발화하지 않는다.** D-27 이 앵커-타일 정합을 WARN 으로 강등했으므로 빌드는 막지 않는다 — 그래서 **경고 문구가 이 사실을 말해야 한다**([BP-33](33_validation_and_lint.md)) |
| **R-40-26** | `:193` 의 호출은 **fire-and-forget** 이다(원문 주석: 다음 이동 프레임을 `update(dt)` 안에서 교착시키지 않기 위해). `await` 하지 않으므로 이동 프레임과 콘텐츠 실행이 겹칠 수 있고, **재진입 가드(`_isScriptRunning`)가 유일한 보호막**이다. 콘텐츠 티어가 step-on 에 붙으면 이 가드의 부하가 늘어난다 |
| **R-40-27** | `:360-367` 의 `_lastInteractedX/Y`(같은 누름 세션 안의 중복 상호작용 방지)도 **presentation 소유 상태**다. 콘텐츠 티어를 앞세울 때 이 상태를 어디에 둘지가 함께 결정되어야 한다 |

- **T-가역 재확인**: 위 3개 진입점은 **콘텐츠 팩이 없으면 아무 변화가 없다.** `:359` 의 게이트를 제거해도
  기존 3티어 디스패치는 `HDTileEventDispatcher.check` 안에서 `HDTileAction` 으로 다시 분기하므로(부록 J-3),
  **비앵커 칸의 동작은 그대로다.** 따라서 R-40-24 는 §40.1.3 의 T-가역을 통과한다.
- **부록 I-1 무효화 기록**: `Map001.json` (2,3) 의 `region=255` 충돌은 **무의미해졌다** — 예약을 하지 않으므로
  충돌도 없다. 다만 `Map001.json` 은 타일 액션 경계를 의도적으로 훑는 **테스트 픽스처**이므로 정리하지 말 것.

---

## 40.4 메인 메뉴 재설계

### 40.4.1 현행 메뉴 구조 (실측 — `application/menu_flows.dart` 544줄)

**1단계: 메인 메뉴** (`showMainMenu`, `menu_flows.dart:33`) — `showWindowMenu(choices, x: 200)`

| 인덱스 | 문구 | 호출 | 깊이 | 비고 |
|---|---|---|---|---|
| 0 | `당신의 명령을 고르시오 ===>` | — | — | 제목 행 |
| 1 | `일행의 상황을 본다` | `showPartyStatus()` | 1 | 좌표/식량/황금/버프 9줄 |
| 2 | `개인의 상황을 본다` | `showCharacterStatus()` | **2** | 인물 선택 → 2페이지 |
| 3 | `일행의 건강 상태를 본다` | `showHealthStatus()` | 1 | 중독/의식불명/죽음 표 |
| 4 | `마법을 사용한다` | `_selectPlayerForMagic()` | **3** | 인물 → 계열 → 주문 |
| 5 | `초능력을 사용한다` | `_selectPlayerForESP()` | **3** | 동상 |
| 6 | `여기서 쉰다` | `restHere()` | 1 | 즉시 실행 |
| 7 | `게임 선택 상황` | `selectGameOption()` | **2~3** | 아래 |

**2단계: 게임 선택 상황** (`selectGameOption`, `menu_flows.dart`)

| 인덱스 | 문구 | 호출 | 깊이 |
|---|---|---|---|
| 0 | `게임 선택 상황` | — | — |
| 1 | `난이도 조절` | `selectDifficulty()` | 3 (적 수 → 성향) |
| 2 | `정식 일행의 순서 정렬` | `_sortParty()` | 4 (기준 → 대상) |
| 3 | `일행에서 제외 시킴` | `_dismissPartyMember()` | 3 |
| 4 | `이전의 게임을 재개` | `selectLoadMenu()` | 3 (슬롯) |
| 5 | `현재의 게임을 저장` | `selectSaveMenu()` | 3 (슬롯) |
| 6 | `게임을 마침` | `processGameOver(0)` | 3 (확인) |

**실측 관찰**

| # | 사실 | 근거 |
|---|---|---|
| M-1 | 메인 메뉴 항목 7개 > `HDSelectionWindow.maxVisibleItems = 6` → **이미 스크롤이 걸려 있다** | `selection_window_data.dart` |
| M-2 | 메인 메뉴만 `x: 200`, 나머지 팝업은 기본값(콘솔 정렬 288) | `menu_flows.dart:52` 주석 |
| M-3 | 창 높이 = `60 + min(enabledCount, 6) * 34` — 7항목이어도 **6행분 높이**(264px) | `selection_window_data.dart` |
| M-4 | 최대 깊이는 4(순서 정렬) | 위 표 |
| M-5 | 모든 메뉴가 `showWindowMenu`(오버레이 창). 콘솔 인라인 메뉴(`showMenu`)는 cm2 `Select::Run` 전용 | `script_engine_adapter.dart` |
| M-6 | 취소는 전부 `0` 반환. `case 0: break;` 로 일관 | `menu_flows.dart:55` |

### 40.4.2 변경안 — 항목 2개 추가

| 인덱스 | 문구 | 신규 | 호출 | 깊이 |
|---|---|---|---|---|
| 0 | `당신의 명령을 고르시오 ===>` | | — | — |
| 1 | `일행의 상황을 본다` | | `showPartyStatus()` | 1 |
| 2 | `개인의 상황을 본다` | | `showCharacterStatus()` | 2 |
| 3 | `일행의 건강 상태를 본다` | | `showHealthStatus()` | 1 |
| 4 | `마법을 사용한다` | | `_selectPlayerForMagic()` | 3 |
| 5 | `초능력을 사용한다` | | `_selectPlayerForESP()` | 3 |
| 6 | `여기서 쉰다` | | `restHere()` | 1 |
| **7** | **`소지품을 살핀다`** | ★ | `showInventory()` | **2~3** |
| **8** | **`임무를 확인한다`** | ★ | `showQuestJournal()` | **2** |
| 9 | `게임 선택 상황` | | `selectGameOption()` | 2~3 |

**배치 근거**

| 결정 | 근거 |
|---|---|
| `게임 선택 상황` 을 **맨 아래로 유지** | 저장·종료가 가장 아래라는 손가락 기억. [BP-27](27_runtime_engine.md) §7.2 의 주의사항과 동일 |
| `소지품` 을 `임무` 보다 위 | 소지품은 사용 빈도가 높고(회복약), 임무는 확인 빈도가 낮다 |
| `소지품` 을 `여기서 쉰다` 바로 아래 | 둘 다 "자원 관리" 묶음 — 식량/휴식/소지품이 이웃 |
| 새 항목의 문구를 **동사형 평서**로 (`~한다`) | 기존 7개가 전부 `~본다`/`~사용한다`/`~쉰다` 형태. [BP-43](43_content_style_guide.md) §2.5 시스템 메시지 규칙 |
| `퀘스트`·`저널`·`인벤토리` 라는 말을 **쓰지 않는다** | §40.6.1 이질감 완화 1번 |

### 40.4.3 창 높이 문제 (M-1/M-3)

현행 공식은 6행에서 잘린다.

```dart
// hadar2026_app/lib/domain/window/selection_window_data.dart
final int maxVisibleItems = 6;
int displayCount = math.min(this.enabledCount, maxVisibleItems);
h = 60 + (displayCount * 34);       // 7항목 → 여전히 264px
```

9항목이 되면 스크롤 3행이 되어 `▲`/`▼` 인디케이터가 상시 표시된다(`window_view.dart` `_wrapWithScrollIndicators`).

| 안 | 내용 | 판정 |
|---|---|---|
| A | 그대로 둔다 (6행 + 스크롤) | **채택하지 않음** — 메인 메뉴에서 3항목이 숨는 것은 발견 가능성 문제 |
| B | 메인 메뉴에 한해 `maxVisibleItems` 를 9로 (창 높이 `60+9*34=366`) | **채택** — 좌표는 [BP-41 §41.5.5](41_journal_ui_spec.md) 소유 |
| C | 메뉴를 2단으로 재편(자주 쓰는 것 / 관리) | 기각 — 깊이가 늘어 F-4 의 정신에 어긋남 |

**B안 확정**: `HDSelectionWindow` 에 `maxVisible` 을 생성자 인자로 받게 하고(기본 6), 메인 메뉴만 9를 넘긴다.
높이는 `h = 60 + 9*34 = 366` 이고 **좌표·여백은 이 장이 정하지 않는다** — [BP-41 §41.5.5 / R-41-10](41_journal_ui_spec.md) 이 `y: 70`(하단 436, 상 70 / 하 44)으로 확정했다.
초판은 이 자리에 `y:100` → 우하단 (600, 466) 을 적어 두었으나, 그 값은 하단 여백이 14px 뿐이라 BP-41 이 폐기했다. **수치를 복사해 두면 두 장이 갈라진다(D-25 의 교훈)** — 링크만 남긴다.

### 40.4.4 키 조작 일관성 (`docs/key_input_policy.md` 준수)

| 동작 | 키 | 신규 키? | 근거 |
|---|---|---|---|
| 메인 메뉴 열기 | Space / Esc / Q | 아니오 | `input_dispatcher.dart` `_handleMap` |
| 항목 이동 | ↑↓ / W S | 아니오 | `window_key_dispatcher.dart` `_handleSelection` |
| 확정 | Enter / E / Space | 아니오 | 동상 |
| 취소·닫기 | Esc / Q | 아니오 | 동상 |
| **저널 탭 전환** | **← → / A D** | **아니오** (기존 방향키의 새 의미) | 선택 창에서 ←→ 는 현재 **미사용**. 새 키를 추가하지 않고 빈 어휘를 쓴다 |
| **소지품 카테고리 전환** | **← → / A D** | 아니오 | 동상 — 두 창이 같은 규칙 |

- 전용 단축키(J, I, TAB 등)는 **넣지 않는다**(F-4). 원작에 그런 어휘가 없다.
- 저널·소지품 창은 `HDWindowManager` 스택에 올라가므로 `HDInputMode` 는 **기존 4개 그대로**다.
  새 모드를 만들지 않는 이유와 `HDWindowKeyDispatcher` 분기 추가는 [BP-41](41_journal_ui_spec.md) §5 가 확정한다.

---

## 40.5 선택 변경 5종 — 비용·효용 판정

D-16 이 "권장하되 1차 스코프 밖으로 둘 수 있음" 으로 남긴 5개를 **각각 넣는다/뺀다로 판정**한다.

판정 기준은 §40.1.3 의 3테스트 + 아래 비용 축이다.

| 비용 축 | 의미 |
|---|---|
| 코드 | 신규/수정 파일 수, 계층 위반 위험 |
| UI | 800×480 안의 신규 화면·항목 |
| 콘텐츠 | 생성 에이전트가 추가로 알아야 할 스키마 |
| 검증 | 솔버·린트가 추가로 탐색해야 하는 상태 공간 |

---

### 40.5.1 시간대 (time of day) — **넣는다** ✅

| 항목 | 내용 |
|---|---|
| **판정** | **넣는다.** 단, 신규 구현이 아니라 **기존 구현의 노출**이다 |
| T-필요 | D-05 의 `time_of_day(value ∈ {day,night})` op 가 v1 닫힌 집합에 **이미 있다**. 빼면 op 하나가 죽는다 |
| T-최소 | 통과 — 새 규칙을 만들지 않는다 |
| T-가역 | 통과 |

**결정적 근거 — 이미 게임에 있다.**

```dart
// hadar2026_app/lib/domain/lighting/sight_calculator.dart:46
final inDark = isDen || !(gameSystem.hour >= 7 && gameSystem.hour < 17);
```

- `HDGameSystem { year, month, day, hour, min, sec }` 가 이미 존재하고 **세이브된다**(`save_manager.dart` `gameSystem`).
- 이동마다 시간이 흐른다 — `player_sprite.dart:183` 지상맵 2분 / 그 외 5초.
- 맵 뷰포트에 시각이 이미 표시된다(`map_viewport.dart:103`).
- 야간 시야 제한이 이미 동작한다(`sight_calculator.dart:20`, `:46`, `:74`).

**주의 — 같은 파일 안에 낮/밤 경계가 둘 있다** (신규 실측)

| 경계 | 줄 | 식 | 낮으로 다루는 시각 |
|---|---|---|---|
| **시야 거리 램프** | `:20-41` | `time = hour*100 + min` 을 600 / 620 / 640 / 700 / 1800 / 1820 / 1840 / 1900 로 계단 분기 | **06:00 ~ 19:00**(최대 시야 5 는 07:00~18:00) |
| **`inDark`**(횃불 발동 조건) | `:46` | `!(hour >= 7 && hour < 17)` | **07:00 ~ 17:00** |

즉 17:00~19:00 은 **시야 램프상 아직 밝은데 `inDark` 는 참**이다. 문서가 `time_of_day` 의 근거로 고른 것은 후자(`:46`)다.

**규범 (정정)**: 경계값을 두 곳에 복제하지 말고 `domain/system/` 에 게터를 두고 양쪽이 참조한다.
단 **"반드시 같은 식" 이라고 쓸 수 없다** — 참조할 원본이 둘이기 때문이다. 어느 쪽을 승격할지가 **Q-40-4** 이며,
결정 전에는 `isDaytime` 을 만들지 않는다. 아무 쪽이나 골라 만들면 "화면은 아직 밝은데 조건은 밤" 이 발생한다 —
이 장이 피하려던 바로 그 증상이다.

- **R-40-20** `isDaytime`(콘텐츠 조건용)과 `sightRamp`(렌더용)는 **이름을 분리**한다.
  하나로 합치려는 시도가 위 17:00~19:00 구간에서 반드시 어긋난다.

| 비용 축 | 비용 |
|---|---|
| 코드 | **`day` = `hour ∈ [7,17)`, 그 외 `night`** 한 줄. `ConditionEvaluator` 에 op 1개 |
| UI | **0** |
| 콘텐츠 | 액터의 `dialogueRouting` 에 시간 조건을 쓸 수 있다는 안내 1줄 |
| 검증 | 솔버가 낮/밤 두 분기를 탐색 → 상태 공간 ×2. **다만 시간은 이동으로 항상 진행하므로 도달 가능성이 깨지지 않는다** |

**제약 (Soft gate)**: 퀘스트의 **필수 경로**에 `time_of_day` 를 두면 안 된다(선택 분기·플레이버 전용).
밤에만 나타나는 NPC 가 필수 의뢰인이면 플레이어가 아침에 무한정 헤맬 수 있다. → 린트 `QV-40`(제안, [BP-33](33_validation_and_lint.md) 소관).

---

### 40.5.2 평판 (reputation) — **뺀다** ❌ (구조만 남긴다)

| 항목 | 내용 |
|---|---|
| **판정** | **1차 스코프 제외.** 단 `var.core.party.reputation_<faction>` 이라는 **변수 이름 규약만 예약**한다 |
| T-필요 | **실패.** 평판이 없어도 죽는 op 이 없다. `var_cmp` 는 이미 있고, 평판은 그 op 의 **한 가지 용법**일 뿐이다 |
| T-최소 | — |
| T-가역 | — |

**근거**

| 축 | 내용 |
|---|---|
| 표현력 | D-04 가 `var.core.party.reputation_lore` 를 예시로 들었고, D-05 의 `add_var`/`var_cmp` 로 **이미 표현 가능**하다. 별도 시스템이 아니다 |
| 진짜 비용 | 평판을 "시스템" 으로 만든다는 것은 ① 표시 UI ② 세력별 임계값 표 ③ 임계값 변화 시 **모든 NPC 대화의 재검토** ④ 상호 배타 퀘스트를 뜻한다 |
| 콘텐츠 폭발 | [BP-22](22_world_bible_model.md) §3.2 의 세력 관계 척도 × 세력 수 만큼 대화 분기가 곱해진다. 1차 팩의 대화 예산을 초과한다 |
| 검증 | 솔버의 상태 공간에 **연속값 축**이 하나 추가된다. `var_cmp` 임계 경계마다 분기 |

**예약하는 것**

| 항목 | 값 |
|---|---|
| 변수 ID 형식 | `var.core.party.reputation_<factionSlug>` |
| 값 범위 | −100 ~ +100 (0 = 중립) |
| 1차에서 허용 | `add_var` 로 값을 **적립하는 것까지만**. `var_cmp` 로 분기하는 것은 Soft 경고 |
| 표시 | **하지 않는다** (UI 0) |

이유: 값을 미리 쌓아 두면 2차에서 평판을 켤 때 **과거 플레이가 소급된다**. 반대로 나중에 도입하면 기존 세이브의 평판이 전부 0 이다.

---

### 40.5.3 동료 영입 — **부분 채택** ⚠️ (기존 기능의 재사용만)

| 항목 | 내용 |
|---|---|
| **판정** | **넣는다 — 단 신규 시스템 없이.** 영입은 `Effect` 가 아니라 **기존 cm2/네이티브 경로**로 처리하고, 퀘스트는 플래그로만 관측한다 |
| T-필요 | **부분 실패.** D-05 의 24개 `do` 에 `join_party` 가 **없다**. 닫힌 집합이므로 추가하려면 `schemaVersion` 승격이 필요하다(D-05) |
| T-최소 | 통과 — 원작 영입 로직이 이미 있다 |
| T-가역 | 통과 |

**실측 — 영입은 이미 게임에 있다**

| 사실 | 근거 |
|---|---|
| 파티 6슬롯 중 **4개가 비어 있다** | `party.dart` `List.generate(6, …)` — index 0 슴갈, 1 유리, 2~5 빈 슬롯 |
| 제외 기능이 있다 | `menu_flows.dart` `_dismissPartyMember()` |
| 순서 정렬이 있다 | `menu_flows.dart` `_sortParty()` |
| 원작 영입 이벤트가 스크립트에 있다 | `assets/town2.cm2` — Mad Joe(`"내가 당신들의 일행에 끼이면 안될까요 ?"`), Skeleton(`"그래서 당신들의 일행에 끼고싶소."`), Polaris 언급 |
| cm2 에 영입 커맨드가 있다 | `Player::AssignFromEnemyData` (GROUND_TRUTH §9) — 적 데이터로 파티원을 만든다 |

**결론**: 동료 영입은 **신규 기능이 아니라 미완성 기능**이다. 다만 `Effect` DSL 에 넣지는 않는다.

| 1차에서 하는 것 | 1차에서 안 하는 것 |
|---|---|
| 영입 이벤트는 기존 cm2/네이티브가 수행 | `join_party(actorId)` Effect **신설 금지** (D-05 닫힌 집합) |
| 퀘스트는 `set_flag` → `flag(id)` 조건으로 영입 여부만 관측 | `party_has_class(classId)` 이상의 파티 질의 |
| 저널 목표는 `flag_set` kind 로 표현 | 동료별 개인 퀘스트·호감도 |
| `party_has_class` op(D-05 에 이미 있음) 사용 | — |

**위험**: 영입된 동료의 **정체성이 actorId 와 연결되지 않는다**(파티원은 `HDPlayer`, NPC 는 `Actor`).
"동료가 된 뒤에도 그 NPC 가 원래 자리에 서 있다" 는 사고가 난다. → **Q-40-3**.
1차 완화: 영입 이벤트가 앵커를 `npc_state: "joined"` 로 바꾸고, 해당 액터 앵커는 그 상태에서 비활성화되도록 콘텐츠가 명시.

---

### 40.5.4 상점 — **뺀다** ❌

| 항목 | 내용 |
|---|---|
| **판정** | **1차 스코프 제외.** 아이템 획득처는 `quest_reward` / `chest` / `npc_gift` / `start_kit` / `hidden` 으로 한정 |
| T-필요 | **실패.** 상점 없이도 9 kind·18 op·22 do 중 죽는 것이 없다. `gold_cmp` 는 이미 다른 용도(통행료·뇌물)로 쓸 수 있다 |

**근거**

| 축 | 비용 |
|---|---|
| UI | **가장 큰 비용.** 매매 화면은 목록 + 가격 + 수량 + 소지금 + 확인의 5요소를 512×400 안에 넣어야 한다. 저널·소지품에 이어 **세 번째 신규 창** — §40.1.4 예산 초과 |
| 밸런스 | 상점이 생기는 순간 `value` 필드가 **게임 규칙**이 된다. 현재 `value` 는 BP-23 §23.9.4 의 **비교 전용 척도**일 뿐이다. 화폐 순환(전투 골드 15~450/회, 시작 500골드)을 새로 설계해야 한다 |
| 검증 | 솔버가 "골드를 모아서 산다" 라는 **무한 반복 경로**를 탐색하게 된다. `defeat` 로 골드를 무한 획득 가능하므로 상태 공간이 사실상 무한 |
| 콘텐츠 | 상점 재고·가격·세력별 할인이 [BP-22](22_world_bible_model.md) 스키마에 추가되어야 한다 |

**원작 근거로도 미완성이다.** `assets/town2.cm2` 에는 상점이 **주석 자리표시자**로만 있다:

```
Talk("### Grocery")
Talk("### Weapon_Shop")
Talk("### hospital")
Talk("### train_center")
```

즉 원작 이식 자체가 상점을 구현한 적이 없다. 1차에서 넣으면 그건 **이식이 아니라 신작**이다.

**대체 수단** (상점 없이 아이템 경제를 성립시키는 법)

| 필요 | 상점 없는 대체 |
|---|---|
| 회복약 보급 | 퀘스트 보상 `give_item` + 상자 앵커(D-09 `container`) |
| 장비 성장 | `assets/town2.cm2` 의 무기고 이벤트(`"들어가셔서 무기를 선택해 주십시오."`) — **선택형 지급**으로 이미 존재 |
| 골드 사용처 | `gold_cmp` 조건 + `add_gold(-n)` 효과로 통행료·정보료·뇌물 |

**2차 도입 시 선결 조건**: ① `value` 를 게임 규칙으로 승격 ② 골드 획득 상한 또는 상점 재고 유한화(솔버 종료성) ③ 매매 창 UI 예산 확보.

---

### 40.5.5 실패 가능 퀘스트 — **넣는다** ✅ (단 1차 콘텐츠에서는 사용 제한)

| 항목 | 내용 |
|---|---|
| **판정** | **런타임은 넣는다. 콘텐츠는 제한한다.** |
| T-필요 | **통과.** D-06 골격에 `failConditions`/`onFail` 이 이미 있고, `quest_state(id, "failed")` op 도 닫힌 집합 안에 있다. 빼면 스키마에 구현되지 않는 필드가 남는다 |
| T-최소 | 통과 — 저널의 "실패" 탭은 이미 §40.2.1 설계에 포함 |
| T-가역 | 통과 |

**이미 확정된 것** — [BP-23](23_quest_model.md) §23.8 이 전부 규정했다: 실패의 성질, `failConditions` 평가 시점(배치 종료 훅), 작성 규칙, `timeoutSteps`, 실패 전파표.
따라서 "구현 비용" 은 **런타임에 조건 재평가 1회를 추가하는 것**뿐이다.

| 축 | 비용 |
|---|---|
| 코드 | 배치 드레인 종료 시 활성 퀘스트의 `failConditions` 평가 — [BP-27](27_runtime_engine.md) §6.2 |
| UI | 저널의 "실패" 탭 1개 (§40.2.1 에 포함) |
| 콘텐츠 | 실패 저널 문자열 `<questId>.failed` 필수화 |
| 검증 | 솔버가 **실패 회피 경로 존재**를 증명해야 한다 — 상태 공간이 유의미하게 커진다 |

**1차 콘텐츠 제한 (규범)**

| 규칙 | 내용 |
|---|---|
| R-40-1 | 1차 팩(`core`, `gen_ep1`)에서 **메인 라인 퀘스트는 실패 불가**여야 한다. `failConditions` 는 사이드 퀘스트에만 |
| R-40-2 | 실패 조건은 **플레이어가 사전에 알 수 있는 것**만. `timeoutSteps` 를 쓰면 저널 목표 문구에 남은 걸음이 보여야 한다 |
| R-40-3 | 실패가 **다른 퀘스트를 연쇄 실패**시키는 구성은 1차 금지 (BP-23 §23.7.4 자동 실패 전파 미사용) |
| R-40-4 | 실패 시 반드시 **대체 경로**가 있어야 한다 — 막다른 세이브 금지. 솔버가 검증 |

### 40.5.6 판정 요약

| 선택 항목 | 판정 | 한 줄 이유 |
|---|---|---|
| 시간대 | **넣는다** | 게임에 **이미 구현되어 있고** D-05 에 op 이 있다. 비용 ≈ 0 |
| 평판 | **뺀다** (이름 규약만 예약) | `var_cmp` 의 한 용법일 뿐. 시스템화 비용이 대화 예산을 초과 |
| 동료 영입 | **부분 채택** | 미완성 기존 기능. `Effect` 에 `join_party` 는 **넣지 않는다** |
| 상점 | **뺀다** | 신규 창 예산 초과 + 솔버 상태 공간 무한화. 원작도 자리표시자뿐 |
| 실패 가능 퀘스트 | **넣는다** (콘텐츠 제한) | 스키마에 이미 있음. 런타임 비용은 조건 재평가 1회 |

---

## 40.6 원작 대비 이질감 관리

저널과 목표 표시는 1990년대 한국 PC RPG 에 없던 요소다. 원작 플레이어가 "이건 원작이 아니다" 라고 느끼는 지점을 셋으로 나누고, 각각의 완화안을 확정한다.

| 이질감의 근원 | 왜 이질적인가 |
|---|---|
| 어휘 | "퀘스트", "저널", "인벤토리" 는 전부 외래어이자 2000년대 관용구 |
| 상시성 | 화면에 항상 떠 있는 목표 마커·미니맵·진행 바 |
| 자동성 | 목표가 저절로 체크되고 보상이 자동 지급되는 감각 |

### 40.6.1 완화 1 — 어휘를 원작의 말로 바꾼다 (Diegetic Naming)

원작 대사에서 실제로 쓰인 단어를 그대로 쓴다. `assets/town2.cm2` Lord Ahn 대사 실측:

> `"여기서 당신의 궁극적인 임무는 바로 'Necromancer 의 야심을 봉쇄 시키는 것'이라는 걸 명심해 두시오."`

**"임무"** 는 원작이 이미 쓴 말이다. 따라서:

| 현대 용어 | **채택 표기** | 근거 |
|---|---|---|
| Quest / 퀘스트 | **임무** | 위 원작 대사 |
| Journal / 저널 | **임무 기록** (메뉴 문구는 `임무를 확인한다`) | 원작 어휘 조합 |
| Objective | **해야 할 일** (목록 헤더) | 평이한 고유어 |
| Inventory | **소지품** | `menu_flows.dart` 가 이미 `남은 식량`/`남은 황금` 처럼 평이한 말을 씀 |
| Active / Completed / Failed | **진행 중 / 마친 일 / 못 마친 일** | 한자어 남용 회피, [BP-43](43_content_style_guide.md) §2 |
| Reward | **사례** 또는 **보답** | `assets/town2.cm2` 어투("Lord Ahn 님의 명령에 의해서 …드리겠습니다") |
| Tracking | **눈여겨 봄** (추적 지정 시 문구) | 신조어 회피 |

**규범 R-40-5**: 저널·소지품 화면과 진행 로그에 **"퀘스트", "저널", "인벤토리", "미션", "오브젝티브", "리워드" 를 쓰지 않는다.**
[BP-43](43_content_style_guide.md) §3 의 금칙에 기계 검사 규칙으로 넘긴다.

### 40.6.2 완화 2 — 상시 HUD 를 만들지 않는다 (Opt-in Surfacing)

| 원칙 | 구현 |
|---|---|
| 맵 뷰포트(288×320)에 **0px** 추가 | 목표 마커·미니맵·화살표 없음. 현재 표시되는 것은 좌표(4,4)와 시각뿐 |
| 상태 패널(288×160)에 **0px** 추가 | 6슬롯 그리드를 건드리지 않는다 |
| 목표는 **부를 때만** 나온다 | 메인 메뉴 → 임무 |
| 예외: 추적 바 | 플레이어가 저널에서 **명시적으로 "눈여겨 봄" 을 지정한 퀘스트 1건에 한해** 진행 로그 패널 상단에 1줄. 기본은 꺼짐 |

추적 바의 정확한 위치·픽셀·토글 방식은 [BP-41](41_journal_ui_spec.md) §6 이 확정한다.
핵심은 **기본 상태에서 화면이 변경 전과 1픽셀도 다르지 않다**는 것이다(T-가역의 시각적 버전).

### 40.6.3 완화 3 — 알림을 기존 문체로 흘려보낸다 (Log-native Feedback)

퀘스트 진행 알림은 **새 위젯을 만들지 않고**(F-10) 기존 진행 로그 레인을 쓴다.

| 사건 | 출력 | 문체 |
|---|---|---|
| 시작 | `[임무] {title} — 시작` | 명사 종결 |
| 단계 전이 | `[임무] {title} — {stageTitle}` | 동상 |
| 목표 진행 | `[임무] {label} ({c}/{t})` | 동상 |
| 완료 | `[임무] {title} — 완료` + 사례 요약 1줄 | 동상 |
| 실패 | `[임무] {title} — 실패` | 동상 |

- 호출은 `UiHost.addLog(msg, isDialogue: false)` — **기존 메서드 그대로**(BP-23 §23.10.5).
- 이 레인은 원작에서 `"일행은 상자 속에서 약간의 금을 발견했다."`, `"일행이 잠시 쉬었다."` 같은 문장이 흐르던 자리다.
  즉 **새로운 종류의 텍스트가 아니라 같은 자리에 한 줄 더**다.
- 배치당 3줄을 넘으면 `[임무] 외 {n}건 갱신` 으로 접는다(BP-23 §23.10.5) — 로그 폭주 방지.
- 팝업·효과음·화면 흔들림·페이드 **없음**. 원작에 그런 연출 어휘가 없다.

### 40.6.4 하지 않기로 한 연출 (명시적 제외)

| 제외 | 이유 |
|---|---|
| 퀘스트 시작 시 화면 중앙 배너 | 원작 어휘에 없음 |
| 목표 완료 효과음 / 진동 | 오디오 시스템 자체가 스코프 밖(D-17) |
| 미니맵·목적지 화살표 | 탐색이 이 게임의 핵심 재미(§40.3.3) |
| 대화 중 "[퀘스트]" 접두 표기 | 대화는 픽션, 저널은 메타 — 섞지 않는다 |
| NPC 머리 위 `!`/`?` 마커 | 맵 뷰포트 0px 원칙 위반(§40.6.2) |

---

## 40.7 호환성

### 40.7.1 기존 세이브 (v1)

| 항목 | 변경 후 동작 | 근거 |
|---|---|---|
| v1 파일 인식 | `version: 1` 이면 마이그레이션 경로 진입 | [BP-25](25_world_state_and_save.md) §6.1 |
| `gameOption.flags/variables`(256칸) | `legacyFlagMap` 역참조로 이름 공간에 흡수. 매핑 없는 인덱스는 **격리 보존** | [BP-25](25_world_state_and_save.md) §6.2, §6.4 |
| `map`(전체 스냅샷 ~570KB) | v2 에서 `mapDelta` 로 교체. v1 로드 시에는 스냅샷을 그대로 복원 후 다음 저장에서 델타화 | [BP-25](25_world_state_and_save.md) §5.4 |
| **`map.events` 누락** (부록 C-1) | v1 로드 시 **현행과 동일하게 대사가 사라진다**. `currentMapName` 이 없어 원본을 재로드할 수 없기 때문 | 부록 C-1 |
| **네이티브 맵 스크립트 미부착** (부록 C-2) | v1 로드는 맵 이름을 모르므로 **추론**한다: `gameOption.scriptFile`(예: `assets/Map004.cm2`)에서 id 를 뽑아 `MapInfos.json` 을 역조회 | [BP-25](25_world_state_and_save.md) §6.3 |
| `worldState` | 없음 → 빈 `WorldState`(퀘스트 0건)로 시작 | — |

**결론**: v1 세이브는 **로드된다**. 다만 그 세이브에는 퀘스트 진행이 없으므로,
콘텐츠 팩의 퀘스트는 전부 `inactive` 상태로 시작한다. 이미 지나간 지역의 퀘스트는 다시 받아야 한다.

**규범 R-40-6**: v1 로드 직후 진행 로그에 안내 1줄을 남긴다 —
`이전 형식의 기록을 옮겼다. 임무 기록은 비어 있다.` ([BP-25](25_world_state_and_save.md) §6.5 의 사용자 가시 동작과 정합)

### 40.7.2 기존 맵 데이터

| 항목 | 변경 후 동작 |
|---|---|
| `assets/maps/*.json` (RPG Maker MV 포맷) | **그대로 읽는다.** 포맷 변경 없음 |
| `events[]` 의 `dialogLines` (code=401) | **티어 3 레거시 폴백으로 존속**(D-10). 앵커가 없는 좌표에서 그대로 출력 |
| `events[].hadarEvent {kind,payload}` | 여전히 파싱만 되고 디스패치 안 됨. **앵커로 대체**하며 신규 콘텐츠는 쓰지 않는다 |
| 실제 이벤트가 있는 맵 (Map002 18개, Map003 3개, Map010 8개, Map011 9개) | 무변경. 앵커를 얹기 전까지 현행 동작 |
| 이벤트가 0개인 맵 (TOWN1/GROUND1/DEN1/DEN2/Map013/014/015) | 앵커의 **1차 이식 대상**. 잃을 것이 없다 |
| `assets/maps/books.json` | 코드가 읽지 않으므로 이동해도 무해. `assets/_legacy/` 로 (R-22-22) |

**선결 과제 (재확인)**: 부록 D-1 — `MapInfos.json` 등록 이름 15개 중 **7개가 존재하지 않는 파일로 해석**된다.
특히 TOWN1/GROUND1/DEN1/DEN2 는 **동명 파일이 있는데도** 인덱스에 등록되어 있다는 이유로 `Map004.json` 등으로 잘못 해석된다.
앵커 키가 맵 이름이므로(D-09), **T-22-1 완료 전에는 C-5 를 착수할 수 없다.**

### 40.7.3 기존 cm2 콘텐츠

| 항목 | 변경 후 동작 | 근거 |
|---|---|---|
| 등록 커맨드 **40종** / 함수 **12종** | **전부 유지.** 하나도 제거하지 않는다 | 부록 F-0 — `grep -c "e.registerCommand('" script_engine_adapter.dart` → 40, `registerFunction` → 12. BP-10 의 43/11 은 오류 |
| `Event::Override()` 시맨틱 | 유지. 단 티어 0 이 먼저 처리하면 cm2 는 아예 실행되지 않는다 | D-10 |
| `Flag::Set/IsSet`, `Variable::Set/Get` | 유지. 추가로 `legacyFlagMap` 역참조 시 `flag_changed`/`var_changed` 이벤트를 발행 | BP-23 §23.11.3 |
| `Battle::Result()` 의 값 매핑 | **위험 — 현재 Dart 와 cm2 상수가 정반대**(부록 B-2). 정본을 정하기 전에는 `battle_won` 을 발행할 수 없다 | 부록 B-2 |
| per-map cm2 로드가 엔진 전역을 날리는 문제 | **유지된다**(cm2 자체 규칙). 신규 상태는 `WorldState` 에 있으므로 영향 없음 | GROUND_TRUTH §9 |
| A-1/A-2 (존재하지 않는 cm2 경로 + 로드 실패 시 상태 누수) | **선결 과제.** 고치지 않으면 "cm2 티어가 항상 선택" 되어 티어 0 이후의 폴백 판정이 오작동 | 부록 A-1, A-2 |

**규범 R-40-7**: cm2 스크립트는 **아이템을 다루지 않는다.** 신규 커맨드(`Item::Give` 등)를 만들지 않는다.
근거: [BP-27](27_runtime_engine.md) §7.5 — 아이템 발행 지점은 `MutableWorldState` 단 한 곳이어야 한다.
cm2 가 필요하면 `Flag::Set` 으로 신호를 남기고, 콘텐츠 팩의 조건이 그것을 읽는다.

### 40.7.4 호환성 회귀 테스트 (제안)

| ID | 시나리오 | 기대 |
|---|---|---|
| CT-1 | 콘텐츠 팩 0개로 부팅 | 화면·메뉴 항목 수를 제외한 모든 동작이 변경 전과 동일 |
| CT-2 | v1 세이브 로드 → 즉시 v2 저장 → 재로드 | 파티·좌표·플래그가 보존, 파일 크기 < 50KB |
| CT-3 | 앵커 없는 맵에서 cm2 대화 | 티어 0 이 미스, 기존 cm2 가 그대로 실행 |
| CT-4 | 앵커 있는 좌표 | 티어 0 이 처리, cm2/JSON 이 **실행되지 않음** |
| CT-5 | 메인 메뉴 9항목 렌더 | 창이 480px 안에 들어감. **assert 할 좌표·높이는 [BP-41 §41.5.5](41_journal_ui_spec.md) 의 값**(`y=70, h=366` → 436)이며 이 장은 수치를 들고 있지 않는다 |

---

## 40.8 이 장이 확정한 것 / 넘긴 것 / 열린 질문

### 40.8.1 확정한 것

| ID | 확정 사항 |
|---|---|
| R-40-8 | **Freeze List 12항목**(§40.1.2)은 이번 변경에서 건드리지 않는다 |
| R-40-9 | 변경 승인은 **T-필요 / T-최소 / T-가역** 3테스트 통과가 조건이다(§40.1.3) |
| R-40-10 | 변경 예산: 신규 메뉴 항목 ≤ 2, 신규 전역 키 0, 신규 `UiHost` 메서드 0, 맵 HUD 0px (§40.1.4) |
| R-40-11 | D-16 의 6개는 **C-4(상태) → C-2/C-5/C-6 → C-3 → C-1** 순서로 착수한다(§40.2.7) |
| R-40-12 | 메인 메뉴는 7항목 → **9항목**. 신규는 7번 `소지품을 살핀다`, 8번 `임무를 확인한다`. `게임 선택 상황` 은 맨 아래 유지(§40.4.2) |
| R-40-13 | `HDSelectionWindow` 에 `maxVisible` 인자를 추가하고 메인 메뉴만 9를 쓴다(`h = 60+9*34 = 366`). **좌표는 [BP-41 §41.5.5](41_journal_ui_spec.md) 소유** (§40.4.3) |
| R-40-14 | 저널·소지품 창은 **새 `HDInputMode` 를 만들지 않는다**. 기존 `window` 모드 + `HDWindowKeyDispatcher` 분기 추가(§40.4.4) |
| R-40-15 | 탭·카테고리 전환은 **←→ / A D**(현재 선택 창에서 미사용인 어휘). 전용 단축키 금지(§40.4.4) |
| R-40-16 | 선택 5종 판정: 시간대 **채택**, 평판 **제외(이름 규약만 예약)**, 동료 영입 **부분 채택(Effect 신설 금지)**, 상점 **제외**, 실패 가능 퀘스트 **채택(1차 콘텐츠 제한 R-40-1~4)** (§40.5) |
| R-40-17 | 기본 상태에서 화면은 변경 전과 **동일**해야 한다. 추적 바는 명시 지정 시에만(§40.6.2) |
| R-40-18 | 퀘스트 알림은 `addLog(isDialogue:false)` 진행 로그 1줄. 팝업·효과음·배너 금지(§40.6.3) |
| **R-40-19** | **불변식 — 대화가 진행 중일 때는 저널·소지품을 열 수 없다.** `_handleMap` 하나만 Space/Esc/Q 를 메뉴로 해석하고 모드 우선순위가 `window > menu > dialogue > map` 이므로 실측상 참이다(§40.2.1) |
| **R-40-20** | `isDaytime`(콘텐츠 조건)과 `sightRamp`(렌더)는 **이름을 분리**한다. `sight_calculator.dart` 안에 낮/밤 경계가 **둘** 있으므로 하나로 합치려는 시도는 17:00~19:00 에서 반드시 어긋난다. 승격 대상 결정 전에는 만들지 않는다(§40.5.1, Q-40-4) |
| **R-40-21** | **1차 스코프의 장비는 전투식을 한 줄도 바꾸지 않는다.** 무기 `power`→`powOfWeapon`, 갑옷+방패 `ac` 합산→`ac` 는 전투식이 이미 읽는 두 자리다(부록 H-1, §40.2.2) |
| **R-40-22** | **방패 별개 축 · 무기 종류 상성 · 부위별 감쇠 · 마법 방어를 원하는 순간 전투식 변경이 선행 과제가 되고, 그것은 Freeze List F-6 해제를 뜻한다.** 해제하려는 장은 3테스트를 다시 통과하고 [BP-42 §7.2·§7.3](42_item_and_inventory.md) 의 밸런스 기준값을 함께 재계산해야 한다(§40.2.2) |
| **R-40-23** | `powOfArmor`/`powOfShield` 는 **폐기 예정 필드**다. 값을 넣어도 무해하지만 "이 값이 방어를 올린다" 고 쓰지 않는다(§40.2.2) |
| **R-40-24** | **부록 K 의 게이트 비대칭을 1줄 변경으로 해소한다** — `player_sprite.dart:359` 의 `if (action.isInteractive)` 를 제거하거나 콘텐츠 인덱스 조회를 그보다 앞세운다. 코드 스케치는 [BP-27 Q-27-10](27_runtime_engine.md) 소유(§40.3.5) |
| **R-40-25** | 해소 전까지의 저작 규칙: **통행 가능한 칸의 앵커는 bump 로 발화하지 않는다.** D-27 이 정합을 WARN 으로 강등했으므로 경고 문구가 이 사실을 말해야 한다(§40.3.5) |
| **R-40-26** | `player_sprite.dart:193`(step-on)은 **fire-and-forget** 이며 재진입 가드(`_isScriptRunning`)가 유일한 보호막이다. 콘텐츠 티어가 붙으면 그 가드의 부하가 늘어난다(§40.3.5) |
| **R-40-27** | `_lastInteractedX/Y`(같은 누름 세션의 중복 상호작용 방지)는 **presentation 소유 상태**다. 콘텐츠 조회를 앞세울 때 이 상태의 위치가 함께 결정되어야 한다(§40.3.5) |
| R-40-5 | 표시 문자열에 "퀘스트/저널/인벤토리/미션/오브젝티브/리워드" 금지. 원작 어휘 표(§40.6.1) 사용 |
| R-40-6 | v1 세이브 로드 직후 안내 1줄(§40.7.1) |
| R-40-7 | cm2 는 아이템을 다루지 않는다. 신규 아이템 커맨드 금지(§40.7.3) |
| — | 선결 과제 3건: **T-22-1**(맵 이름 해석, 부록 D-1) / **이동 루프 추출**(부록 B-3) / **`Battle::Result` 정본 확정**(부록 B-2) |
| — | **선행 과제 1건 추가**: 부록 K 의 bump 게이트 제거(R-40-24). 콘텐츠 티어를 step-on 이외의 경로로 발화시키려면 이것이 먼저다 |

> **ID 순서 주의**: 위 표는 **읽는 순서(문서 등장 순)** 로 정렬했고, 그래서 R-40-5·6·7 이 맨 아래에 온다.
> 이 세 규범은 §40.6~40.7 에서 정의되지만 번호가 앞자리라 초판에서 표 중간에 섞여 있었다 — 인용 시 혼동을 줄이려 뒤로 모았다.

### 40.8.2 다음 장으로 넘긴 것

| 넘긴 것 | 받는 장 |
|---|---|
| 저널 화면의 픽셀·ASCII 목업·문자 수 상한·키 처리·추적 바 위치 | [BP-41](41_journal_ui_spec.md) |
| `HDSelectionWindow.maxVisible` 확장의 정확한 스펙 | [BP-41](41_journal_ui_spec.md) §5.4 |
| 인벤토리 데이터 모델·아이템 20종 실데이터·장비 마이그레이션·소지품 화면 | [BP-42](42_item_and_inventory.md) |
| "임무/사례/해야 할 일" 등 원작 어휘의 문체 규범화와 금칙 린트 | [BP-43](43_content_style_guide.md) §3, §7 |
| `time_of_day` 를 `sight_calculator` 와 공유하는 `isDaytime` 배치. **두 경계 중 어느 쪽을 승격할지가 선행**(Q-40-4) | [BP-27](27_runtime_engine.md) (구현), [BP-33](33_validation_and_lint.md) (`QV-40` 제안) |
| **부록 K 의 bump 게이트 제거**(R-40-24)와 그때 `_lastInteractedX/Y`(R-40-27)를 어디에 둘지 | [BP-27 Q-27-10](27_runtime_engine.md) |
| **전투식 변경(F-6 해제)이 선행 과제가 되는 장비 설계 범위**(R-40-22)와 그 로드맵 위치 | [BP-42 §4.5](42_item_and_inventory.md), [BP-50](50_roadmap.md) |
| 통행 가능한 칸의 앵커에 대한 WARN 문구가 "bump 로는 발화하지 않는다" 를 말해야 한다(R-40-25) | [BP-33](33_validation_and_lint.md) |
| 실패 가능 퀘스트의 솔버 탐색 전략 | [BP-34](34_headless_sim_and_solver.md) |
| CT-1~CT-5 회귀 테스트의 구현 | [BP-35](35_ci_and_build.md), [BP-53](53_acceptance_criteria.md) |

### 40.8.3 열린 질문

| ID | 질문 | 영향 |
|---|---|---|
| **Q-40-1** | 메인 메뉴 9항목은 원작 감성상 너무 많은가? 원작은 8항목이었다는 기억이 있으나 검증되지 않았다. `REF_hadar/` 의 C++ 메뉴 정의를 확인해 항목 수 상한을 재검토할 것 | §40.4 전체 |
| **Q-40-2** | 저널 열람 중 게임 시간을 멈추는 것이 맞는가? `restHere` 는 시간을 쓰는데(`passTime`), "임무 기록을 본다" 는 순간이라고 볼지 몇 분이라고 볼지. 현재는 **멈춘다**로 확정했으나 원작 감성 논의 필요 | §40.2.1 |
| **Q-40-3** | 영입된 동료와 `actorId` 의 동일성을 어떻게 표현하는가? `HDPlayer` 에 `sourceActorId: String?` 을 두는 안 vs 콘텐츠가 `npc_state` 로만 관리하는 안 | §40.5.3 |
| **Q-40-4** | `sight_calculator.dart` 안의 **두 경계** — 시야 거리 램프(`:20-41`, 06:00~19:00)와 `inDark`(`:46`, 07:00~17:00) — 중 어느 쪽을 `isDaytime` 으로 승격하고, 나머지 하나는 별도 이름(`sightRamp`)으로 남길 것인가? 초판은 "같은 값" 으로 확정했으나 **참조할 원본이 둘이라는 사실을 놓쳤다**(§40.5.1 정정). **잠정**: `inDark`(07:00~17:00)를 `isDaytime` 으로 승격 — `time_of_day` 가 서사 조건이므로 "횃불이 필요한 시간" 과 일치하는 것이 콘텐츠 저작자의 직관에 가깝다. 램프는 `sightRamp` 로 렌더 전용 유지. **결정 전에는 `isDaytime` 을 만들지 않는다**(R-40-20) | §40.5.1 · [BP-27](27_runtime_engine.md) · [BP-33](33_validation_and_lint.md) |
| **Q-40-5** | 추적(눈여겨 봄) 대상은 1건인가 복수인가? [BP-41](41_journal_ui_spec.md) 이 1건으로 확정할 예정이나, 여러 퀘스트가 같은 지역에서 겹칠 때의 UX 미검증 | §40.6.2 |
| **Q-40-6** | v1 세이브의 맵 이름 추론(`gameOption.scriptFile` 역조회)은 부록 A-1 때문에 **항상 존재하지 않는 cm2 경로**를 보게 된다. 그래도 id 추출은 가능하지만, T-22-1 이후 규칙이 바뀌면 추론식도 바뀐다 | §40.7.1 |
