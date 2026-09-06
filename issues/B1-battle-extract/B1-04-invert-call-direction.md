# B1-04 전투 진행의 호출 방향을 뒤집는다 (model 이 view 를 부르지 않게)

- **상태**: DONE
- **구간**: B1
- **규모**: L
- **선행**: [B1-03](B1-03-formula-port.md)
- **설계 근거**: [MILESTONES §7](../MILESTONES.md) · [CLAUDE.md 레이어 규약](../../CLAUDE.md)

## 문제

`HDBattle.start()`(`battle.dart:112-243`)는 model 이 아니라 **UI 를 직접 모는 코루틴**이다.
한 함수 안에서 전투 루프가 돌면서 view 를 `await` 로 호출하고 멈춰 선다.

| 호출 | 곳 |
|---|---|
| `_host.showWindowMenu(...)` | `battle.dart:104`(대상 선택) · `:327`(전투 모드 선택) |
| `_host.waitForAnyKey()` | `battle.dart:199` · `:230` · `:270` |
| `_host.addLog(...)` | **30곳** |
| `_host.clearLogs()` | `battle.dart:125,129,207,271,275,329,346,359,372` |

그리고 한국어 문장과 조사가 model 안에 박혀 있다 — `battle.dart:483`:

```dart
"${p.name}${p.name.sub1} $wName${wName.withJosa} ${t.name}${t.name.obj} 공격하여 $damage 데미지!"
```

이 상태로는 콘솔 view 와 Flutter view 가 **같은 model 을 공유할 수 없다.** 메시지 문장과
메뉴 순서가 model 소유이기 때문이다.

## 왜 지금 해야 하는가

[B1-05](B1-05-console-view.md)(콘솔 view)와 [B4-01](../B4-battle-view/B4-01-flutter-view.md)(Flutter view)이
같은 model 을 쓴다는 전제가 여기서 만들어진다. 4구간의 "model 무변경" 은 이 이슈의 결과물이다.

## 무엇을 할 것인가

`hd_battle` 은 `UiHost` 같은 것을 **모른다.** 대신 이렇게 노출한다.

| 노출 | 뜻 |
|---|---|
| `pendingDecision` | 지금 누구에게 무엇을 물어야 하는가 (`null` 이면 물을 것이 없다) |
| `applyCommand(BattleCommand)` | 답을 넣는다. 반환값은 그 결과로 발생한 `List<BattleEvent>` |
| `advance()` | 물을 것이 없을 때 전투를 한 걸음 진행시킨다. 반환값도 `List<BattleEvent>` |
| `outcome` | 종료 후의 `BattleOutcome`. 진행 중에는 `null` |

`BattleEvent` 는 **구조화된 사실만** 담는다 — 행위자·대상·종류·수치. 문자열을 만들지 않는다.
조사 처리(`HDNoun`)와 문장 조립은 view 의 일이다.

이 구간에서 **없어지는 의존 5개** ([B1-01](B1-01-package-skeleton.md) 의 표):

| 의존 | 처리 |
|---|---|
| `HDGameSession().party` | `BattleSetup` 으로 주입 |
| `HDMenuFlows().processGameOver(2)` | `BattleOutcome` 의 종료 코드로 승격. 전투는 게임오버를 실행하지 않는다 |
| `HDMagicSystem.castBattleSpellUI` | 마법 **선택 UI** 는 view 로 이동. model 은 `BattleCommand` 만 받는다 |
| `GameReloadException` | **버린다.** 전투 중 세이브·로드는 현재도 도달 불가다 — 메인 메뉴는 `presentation/input/input_dispatcher.dart:121` 의 `_handleMap` 에서만 열리고, 전투 중 입력 모드는 `window`/`dialogue` 다. `battle.dart:241` 의 catch 는 방어용 죽은 코드이므로 잃는 기능이 없다 |
| `ChangeNotifier` · `debugPrint` | 제거. 경고는 `BattleEvent` 로 낸다 |

## 완료 판정 기준

- [x] `grep -rn "package:flutter" packages/hd_battle/lib` 가 **빈 결과**다
- [x] `packages/hd_battle/lib` 안에 **한국어 문장 리터럴이 0개**다 (조사·메시지는 view 소유)
- [x] 전투 한 판이 `pendingDecision` → `applyCommand` → `advance` 반복만으로 끝까지 진행되고
      `outcome` 이 채워진다 → `packages/hd_battle/test/flow/full_battle_test.dart`
- [x] 파티 전멸 시 `outcome` 의 종료 코드가 패배이고, model 은 **아무 화면도 띄우지 않는다**
- [x] 종료 코드가 `evade 0 / win 1 / lose 2 / 미결 -1` 로 매핑 가능하다
      (`hadar2026_app/assets/const.cm2:53-55` 와 같은 의미. 실제 어댑터는 B3-01)

## 결과 (2026-09-04)

노출은 계획대로 `pendingDecision` / `applyCommand` / `advance` / `outcome` 이다.
`advance()` 한 번이 **한 걸음** — 파티원 한 명의 행동, 또는 적 한 마리의 차례.

의존 5개는 전부 끊겼다. `GameReloadException` 은 예상대로 **버려도 무해**했다.

**이식하면서 고친 잠복 결함 1건**: 원작은 명령표를 `List.generate(4, ...)` 로 만드는데
(`battle.dart:120`) 파티 슬롯은 **6칸**이다. 시작 파티가 2명이라 우연히 동작했고,
슬롯 4·5 에 사람이 있으면 `RangeError` 가 났다. 새 model 은 슬롯을 키로 쓰는 map 이라
이 경계가 없다. 규칙 변경이 아니라 크래시 제거다.

**불변조건 검사는 `test/flow/purity_test.dart` 가 갖는다** — Flutter 의존 0 · 시드 없는 난수 0 ·
한국어 0 · 경험치 표 0. 확장 항목이 바뀌어도 이 넷은 안 바뀐다(B2-99 가 그대로 물려받는다).

## 하지 않을 것

콘솔 view 구현(B1-05) · 전투식 수정(B2) · cm2 어댑터(B3-01) ·
`application/battle.dart` 삭제(B4-03).
