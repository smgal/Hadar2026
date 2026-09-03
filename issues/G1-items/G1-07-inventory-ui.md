# G1-07 소지품·장비 화면을 만든다 (800×480 안에서)

- **상태**: DONE
- **구간**: G1
- **규모**: L
- **선행**: [G1-03](G1-03-party-inventory.md) · [G1-04](G1-04-equipment-slots.md)
- **설계 근거**: [MILESTONES §1.5](../MILESTONES.md) · [`GROUND_TRUTH` §3 포트](../../blueprint/_meta/GROUND_TRUTH.md) · `hadar2026_app/UI_SPEC.md`
- **참고만**: [BP-42 §5](../../blueprint/42_item_and_inventory.md) — 19행 기준 목업은 보류 노선 산출물이다. **행 예산이 실제와 다르다**(아래 실측 참조).

## 문제

### 소지품을 볼 화면이 없다

현행 주 메뉴는 7항목이다 — `hadar2026_app/lib/application/menu_flows.dart:34-43`:
```dart
final choices = [
  "당신의 명령을 고르시오 ===>",
  "일행의 상황을 본다", "개인의 상황을 본다", "일행의 건강 상태를 본다",
  "마법을 사용한다", "초능력을 사용한다", "여기서 쉰다", "게임 선택 상황",
];
```
장비는 `showCharacterStatus()`(`:228-282`) 안에 **읽기 전용 2줄**로만 나온다(`:275`, `:277`).
바꿀 수단이 없다.

### 원작 화면은 800×480 에 안 들어간다

`REF_UNITY_LoreEp1/src_as_cs/GameEventEquipment.cs` 는 Unity uGUI 리스트뷰 2개를 좌우로 놓는다 —
현재 장비 패널 + `"BackpackListView"`(`:330`, `:369`) + 아이콘 스프라이트(`:328`) + 안내문 패널(`_DisplayGuideText`).
**흐름만 가져오고 배치는 다시 짜야 한다.**

원작 흐름(전부 직접 읽음):
1. 인물 선택 → 부위 선택(6칸) — `_ix_player`, `_ix_equipment`
2. 부위에 맞는 가방 항목만 필터 — `:334-360` 의 6분기 switch 가 `(type, detail)` 로 후보를 고른다
3. **장착** `:135-190` — 후보 선택 → 기존 장비를 `unequiped` 로 빼고 새것을 넣은 뒤, 새것은 가방에서 제거·기존것은 가방에 넣음(`:184-188`)
4. **해제** `:112-133` — 슬롯을 비우고 가방에 넣음. **맨손(`WEAPON` + index 0)은 해제 불가**(`:122`)
5. `UpdateScreen()` `:195-199`

## 왜 지금 고쳐야 하는가

- **재미** — MILESTONES §1.5 완료 기준: *"아이템을 소지·장비·해제할 수 있고 화면에서 목록을 본다."* 화면이 없으면 [G1-03](G1-03-party-inventory.md)·[G1-04](G1-04-equipment-slots.md)·[G1-05](G1-05-equipment-effect.md) 이 전부 **플레이어가 볼 수 없는 기능**이 된다.
- **부채 방지** — 3부위 화면을 만들고 나중에 6부위로 늘리면 커서·필터·목록을 다시 쓴다. [G1-04](G1-04-equipment-slots.md) 가 6부위를 처음부터 넣는 이유와 같다.

## 무엇을 할 것인가

### 기하학 실측 (`hd_config.dart` 직접 확인)

| 상수 | 값 | 줄 |
|---|---|---|
| `gameScreenWidth` × `gameScreenHeight` | 800 × 480 | `:10-11` |
| `consoleWidth` × `consoleHeight` | 512 × 320 | `:14-15` |
| `consoleFontSize` / `consoleLineHeight` | 16 / 1.2 | `:16-17` |
| `maxLinesPerPage` | **13** | `:52` |
| `messageWindow` x,y,w,h | 288, 100, 400 × 200 | `:39-42` |
| `HDSelectionWindow.maxVisibleItems` | **6** | `selection_window_data.dart:11` |

콘솔 폰트는 **고정폭이 아니다**(`console_panel.dart:6-10` 의 `TextStyle` 에 `fontFamily` 없음, 줄바꿈은
`lib/utils/hd_text_utils.dart:78` 이 픽셀 폭으로 계산). → **문자 수 기준 패딩은 근사값**이다([G1-06](G1-06-item-names.md) 참조).

### 판정: **새 위젯을 만들지 않는다** — 기존 두 수단을 조합한다

`showCharacterStatus()`(`menu_flows.dart:228-282`)가 이미 쓰는 패턴을 그대로 쓴다:
- **목록 표시** = `_game.clearLogs()` + `addLog()` 반복 + `waitForAnyKey()` → 콘솔 패널(512×320, 13행)
- **선택** = `_game.showWindowMenu(choices)` → `HDSelectionWindow`(6칸 스크롤, `moveCursor`)

근거:
1. `presentation/panels/` 신규 위젯 0 · `presentation/input/` 신규 디스패치 0 → 계층 위반 위험이 없고 검토 면적이 작다.
2. `UiHost` 포트가 이미 `showWindowMenu`/`addLog`/`clearLogs`/`waitForAnyKey` 를 전부 갖고 있다(`GROUND_TRUTH` §3). **새 포트 메서드를 추가하지 않는다.**
3. 6칸 스크롤이 가방 20칸·부위 6칸에 충분하다.

주 메뉴에 8번째 항목 `"소지품을 본다"` 를 추가하고 `case 8:` 로 잇는다(`menu_flows.dart:54-78`).

### ASCII 목업

**(1) 소지품 목록 화면** — 콘솔 패널 13행. 가방 20칸을 6칸씩 넘긴다.

```
+---------------------------- 512 x 320 (13행) ----------------------------+
| ## 소지품                                        7 / 20                  |
|                                                                          |
|   1. 단검                    무기   공격 15                              |
|   2. 장검                    무기   공격 60                              |
|   3. 가죽 방패               방패   방어  1                              |
|   4. 강철 방패               방패   방어  3                              |
|   5. 가죽 갑옷               갑옷   방어  1                              |
|   6. 청동 투구               머리   -                                    |
|                                              ▼ 더 있음 (7/7)             |
|                                                                          |
| [Enter] 장비 화면   [ESC] 닫기                                           |
+--------------------------------------------------------------------------+
```

**(2) 장비 화면** — 인물 → 부위 → 후보. 각 단계가 `showWindowMenu` 한 번이다.

```
  1단계: 인물                    2단계: 부위 (6칸)              3단계: 후보 (그 부위만)
+---------------------+       +---------------------------+   +---------------------------+
| 누구의 장비인가     |       | 어느 부위를 바꾸는가      |   | 무엇을 채우는가           |
|  슴갈               |       |  손    - 단검             |   |  (비운다)                 |
|  유리               |       |  방패  - 없음             |   |  장검          공격 60    |
|                     |       |  갑옷  - 가죽 갑옷        |   |  철퇴          공격 60    |
+---------------------+       |  머리  - 없음             |   |  삼지창        공격 60    |
                              |  다리  - 없음             |   +---------------------------+
                              |  장식  - 없음             |
                              +---------------------------+
```

- 2단계 목록은 **현재 착용품 이름을 함께** 보여 준다 — 원작 `gui_text_current_equipment`(`:326`)의 역할.
- 3단계 첫 항목 `(비운다)` = 원작 `OnCurrentEquipmentRemove`(`:112-133`). **손 슬롯의 맨손은 이 항목이 빠진다**(`:122`).
- 3단계 후보는 `candidatesFor(slot)` 이 만든다 — 가방 20칸에서 `HDItemType.equipSlot == slot` 인 것만.

### 배치 계획

| 파일 | 변경 |
|---|---|
| `lib/application/menu_flows.dart` | `showMainMenu()` 에 항목 추가 · `showInventory()` · `showEquipment()` 신설 |
| `lib/application/equipment_flow.dart` (신설) | `candidatesFor(HDEquipSlot)` · `equipFromBackpack(...)` · `unequipToBackpack(...)` — **순수 함수**, 테스트 대상 |
| `lib/presentation/` | **변경 0** |
| `lib/application/ports/` | **변경 0** |

`application/` 은 `presentation/` 과 `hd_game_main.dart` 를 import 하지 않는다 — `menu_flows.dart` 는 이미
`_game`(`UiHost`)·`_session`(`HDGameSession`) 만 쓴다. 같은 규율을 유지한다.

## 완료 판정 기준

- [x] 주 메뉴에서 `"소지품을 본다"` 로 들어가 **가방 20칸의 내용이 이름·분류·수치와 함께** 보인다
- [x] 인물 → 부위 → 후보 3단계로 **6부위 전량**을 장착·해제할 수 있다
- [x] 후보 목록에 **그 부위에 맞는 아이템만** 나온다 (갑옷이 머리 후보에 안 나온다)
- [x] 장착 시 기존 장비가 **가방으로 돌아오고**, 새 장비는 가방에서 빠진다 (아이템 총 개수가 보존된다)
- [x] 손 슬롯의 맨손은 `(비운다)` 항목이 나오지 않는다
- [x] 장비를 바꾸면 개인 상황 화면(`menu_flows.dart:275-277`)의 이름이 즉시 바뀐다
- [x] 콘솔 13행(`hd_config.dart:52`)·선택창 6칸(`selection_window_data.dart:11`)을 **넘지 않는다** — 가방이 20칸 다 찬 상태에서 확인
- [x] `lib/presentation/` 과 `lib/application/ports/` 에 변경이 없다 (`git diff --stat`)
- [x] `application/` 계층 위반 grep 2종 통과
- [x] 테스트 추가: `hadar2026_app/test/application/equipment_flow_test.dart` —
      `test/application/map_navigation_test.dart:13-28` 의 페이크 바인딩 패턴을 그대로 따른다
      (`HDHosts().bind(ui: fakeUi, movement: fakeMove, assets: fakeAssets)` / `tearDown` 에서 `HDHosts().reset()`).
      페이크 `UiHost` 의 `showWindowMenu` 가 **미리 정한 선택 시퀀스**를 순서대로 돌려주게 만들어
      ① 부위별 후보 필터가 정확함
      ② 장착 왕복 후 **아이템 총 개수 보존**(가방 + 6슬롯)
      ③ 맨손 해제 거부
      ④ 가방이 꽉 찬 상태에서 해제하면 **아이템을 잃지 않고 거부**됨
      을 고정한다

## 하지 않을 것

- **신규 Flutter 위젯·신규 창 클래스** — `HDWindow` 파생을 추가하지 않는다(`domain/window/` 4종 그대로).
- **`UiHost` 포트 확장** — 기존 7종 메서드로 충분하다. 확장하면 헤드리스 하네스 계약이 커진다.
- 아이콘·스프라이트·설명문 패널 — 원작의 `icon_sprites`(`:328`)·`_DisplayGuideText` 는 800×480 에 자리가 없다.
- 드래그·마우스 조작(입력은 키보드/가상 D-pad 뿐 — `docs/key_input_policy.md`) · 아이템 정렬·검색·필터 토글 · 개인 소지 화면.
- 상점·무게·제작·강화·선언적 콘텐츠 팩·저널 UI.

## 구현 기록 (2026-09-03)

### 산출물

| 파일 | 변경 |
|---|---|
| `lib/application/equipment_flow.dart` | **신설.** `HDEquipmentFlow` — `candidatesFor` · `equipFromBackpack` · `unequipToBackpack` · `canUnequip` + 표시 문구 |
| `lib/application/menu_flows.dart` | 주 메뉴 8번째 항목 · `showInventory()` · `showEquipment()` |
| `test/application/equipment_flow_test.dart` | **신규.** 14개 테스트 |
| `lib/presentation/` · `lib/application/ports/` | **변경 0** (`git status` 확인) |

### 검증

- `flutter test` — 197개 전량 통과
- `flutter analyze --no-fatal-infos` — 77건, **기존과 동일**
- 계층 위반 grep 2종 — 빈 결과
- **행 예산**: 가방 20칸을 다 채운 상태로 `showInventory()` 를 돌려
  페이지당 최대 줄 수가 13 이하임을 테스트가 고정(4페이지 × 6칸)
- **선택창**: `HDSelectionWindow` 는 `h = 60 + min(항목수, 6) × 34` 라
  최대 264px. 주 메뉴가 8항목이 되어도 y=100 기준 364px 로 480 안에 든다

### 이슈 서술에서 벗어난 부분

- **소지품 화면에서 `[Enter] 장비 화면` 을 키로 구분하지 않는다.**
  `waitForAnyKey()` 는 Enter 와 Esc 를 구분해 주지 않으므로(포트를 늘리지 않는다는 규칙),
  목록을 다 보여 준 뒤 `showWindowMenu(["소지품", "장비를 바꾼다"])` 로 묻는다. Esc = 닫기.
- **부위 선택을 Esc 까지 반복한다.** 이슈의 3단계 그림은 1회성이지만, 여섯 칸을 채우려고
  메뉴를 여섯 번 여는 것은 번거롭다. 한 번 장착하면 부위 목록으로 돌아온다.
- **`HDEquipSlot` 의 한국어 이름을 domain 이 아니라 `equipment_flow.dart` 에 뒀다.**
  `HDItemType` 에 label 이 없는 것과 같은 이유 — 표시 문구는 흐름을 짜는 층의 것이다.
- **주 메뉴 번호가 밀렸다** — `"게임 선택 상황"` 이 7 → 8. 밖에서 이 번호를 박아 쓰는 곳은
  없음을 확인했고(`grep`), 조용한 재번호를 막는 테스트를 추가했다.

### 아이템 보존 규칙

교체는 **새 아이템을 가방에서 먼저 뺀 뒤** 기존 것을 넣는다 — 가방이 20칸 꽉 찬 상태에서도
교체가 되고 아이템이 사라지지 않는다. 해제는 가방에 자리가 없으면 **거부**한다(바닥에 버리지 않는다).
테스트가 세 경우 모두에서 "가방 + 6슬롯 총 개수" 불변을 고정한다.
