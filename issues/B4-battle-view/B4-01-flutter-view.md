# B4-01 Flutter 전투 view 를 새로 만든다 (model 무변경)

- **상태**: DONE (2026-09-06 · 실험실 모드로 먼저)
- **구간**: B4
- **규모**: L
- **선행**: [B3-02](../B3-battle-integrate/B3-02-setup-and-settle.md)
- **설계 근거**: [MILESTONES §7](../MILESTONES.md) · [UI_SPEC.md](../../hadar2026_app/UI_SPEC.md)

## 문제

현재 전투 화면은 `presentation/panels/battle_overlay.dart`(**95줄**)가 전부다.
`map_viewport.dart:124` 에서 마운트되고, 하는 일은 `HDBattle().enemies` 를 읽어
적 이름과 `의식 있음/의식 불명/사망` 을 나열하는 것이다(`:44-52`).

`HDBattle()` 을 `ListenableBuilder` 로 직접 듣고(`:10`) 내부 필드
`enemies`·`selectedEnemyIndex` 를 직접 읽는다(`:14-15`). 새 model 은
`ChangeNotifier` 가 아니고 그런 필드를 노출하지 않으므로 **이 위젯은 쓸 수 없다.**

## 무엇을 할 것인가

- `BattleEvent` → 한국어 문장 조립을 **view 에서** 한다. 조사 처리는 기존
  `domain/text/noun.dart` 의 `HDNoun` 을 그대로 쓴다.
- `pendingDecision` → 기존 메뉴 UI(`UiHost.showWindowMenu`)로 물어보고 `BattleCommand` 로 답한다.
- B2 가 추가한 것들이 화면에 보여야 한다 — 상태이상 목록(B2-03) · 행동 순서(B2-05) ·
  아이템 사용(B2-06) · 속성(B2-09).
- 800×480 고정 레이아웃 안에서 한다. 좌표·색상 관례는 `UI_SPEC.md` 와 `hd_config.dart` 를 따른다.

## 결과 (2026-09-06) — **게임보다 실험실이 먼저다**

착수 계기가 바뀌었다. 원래는 "게임 안의 전투 화면" 이었는데, 실제로 걸린 문제는
**전투를 손보려면 전투만 띄울 수 있어야 한다**는 것이었다. 지도를 걷고 조우를
만들어야 한 판을 볼 수 있으면 같은 상황을 두 번 만들 수 없고, 밸런스든 재미든
판단할 수가 없다. 터미널로 5인 파티를 굴리는 것이 힘들다는 것이 그 신호였다.

그래서 **화면 위젯은 게임에 쓸 것 그대로 만들고, 진입점만 따로** 두었다.

```bash
cd hadar2026_app
flutter run -t lib/battle_lab_main.dart            # 데스크톱
flutter run -d chrome -t lib/battle_lab_main.dart  # 브라우저
flutter build web -t lib/battle_lab_main.dart --release
```

| 파일 | 무엇 |
|---|---|
| `presentation/panels/battle/battle_controller.dart` | 전투를 굴리는 상태. **되감기**가 여기 있다 |
| `presentation/panels/battle/battle_screen.dart` | 800×480 화면. 게임 안에서 쓸 것과 같은 위젯 |
| `battle_lab_main.dart` | fixture 목록 + 화면. RPG·지도·cm2 를 안 건드린다 |

### 콘솔 운전자와 뒤집혀 있다

`HDBattleRunner` 는 `await showWindowMenu` 로 **기다린다.** 위젯은 매 프레임 다시
그려지므로 그렇게 못 한다. 그래서 controller 는 `decision` 을 **상태로 내놓고**
위젯이 `choose` 로 답한다. `packages/hd_battle` 은 그대로다.

### 한 걸음씩 흘린다

라운드 하나를 한꺼번에 풀면 열 줄이 동시에 나타난다. 이벤트를 큐에 담아 두고
110ms 마다 하나씩 흘린다. **아직 안 흘린 줄이 있으면 물음을 감춘다** — 무슨 일이
있었는지 못 본 채로 다음 명령을 내리게 되면 안 된다. 로그를 누르면 남은 것을 다 흘린다.

### 되감기 — 이것이 실험실의 요점이다

전투는 **시드 + 명령 열**이면 완전히 재현된다. 그래서 「한 수 물리기」는 판을 새로
만들고 명령을 하나 적게 다시 먹이는 것으로 끝난다. 다른 수를 보려고 처음부터
다시 칠 필요가 없다.

### 문구·색은 한 줄도 여기서 만들지 않는다

「표현 격차 0」을 지키는 방법이 이것이다. 콘솔이 갖고 있던 것을
`hd_battle_text` 로 옮기고 **양쪽이 같은 것을 부른다.**

| 옮긴 것 | 어디로 |
|---|---|
| `enemyNameColor` · `conditionColor` | `src/status_colors.dart` |
| `actionLabel` · `attackMethodName` · `spellCategoryLabel` | `src/menu_labels.dart` |
| `reachVerdict`(닿음/N칸 부족·명중·앞열 대신) · `actionHeaderSuffix` | 〃 |

### fixture 는 저작이 한 곳이다

Flutter 의 asset 경로는 패키지 밖(`../`)을 못 가리킨다. 그래서
`dart run tool/make_fixtures.dart` 가 `hd_battle_console/fixtures/` 와
`hadar2026_app/assets/battle/` 에 **함께** 떨구고, 색인(`index.json`)도 같이 만든다.
어긋나면 `hd_battle_console/test/fixture_mirror_test.dart` 가 잡는다.

## 완료 판정 기준

- [x] `packages/hd_battle` 이 **한 줄도 바뀌지 않는다**
- [x] 콘솔 view 가 표현하는 것을 Flutter view 도 표현한다 — 대열·간격·열·닿는 적·
      거리와 사거리 부족·이름 색·상태·정산 결과. **문구는 공유본에서 온다**
- [x] 전투 한 판을 **끝까지 플레이할 수 있다** (`battle_screen_test.dart` 가 눌러서 끝낸다)
- [x] `battle_overlay.dart` 가 `HDBattle()` 을 참조하지 않는다 (B3-01 에서 이미)

### 아직 아닌 것

- **게임 안에서는 아직 옛 오버레이다.** 지도 위 전투를 이 화면으로 바꾸는 것이 B4-02.
- 키보드 입력 없음 — 실험실은 마우스로 누른다. 키 배선도 B4-02.
- 콘솔의 정산 표에 있는 `worldEffects` · `consumedItems` 는 화면에 없다 (B3-04 대상).

## 하지 않을 것

전투 규칙 변경 · 애니메이션·사운드 · 구 `application/battle.dart` 삭제(B4-03) ·
`UI_SPEC.md` 의 레이아웃 재설계.
