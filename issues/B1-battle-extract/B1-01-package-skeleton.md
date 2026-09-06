# B1-01 `packages/hd_battle` 패키지 골격과 모드 인계 규격 초안

- **상태**: DONE
- **구간**: B1
- **규모**: M
- **선행**: 없음
- **설계 근거**: [MILESTONES §7](../MILESTONES.md) · [DECISION-LOG 4차 판정](../DECISION-LOG.md)

## 문제

전투 로직이 `hadar2026_app/lib/application/battle.dart`(**572줄**) 한 파일에 있고,
아래 5개에 직접 의존한다. 별도 실행으로 뗄 수 없는 상태다.

| 의존 | 위치 |
|---|---|
| `HDGameSession().party` | `battle.dart:31` `_party` getter |
| `HDMenuFlows().processGameOver(2)` | `battle.dart:257` |
| `HDMagicSystem.castBattleSpellUI` | `battle.dart:360` |
| `GameReloadException` | `battle.dart:241` |
| `ChangeNotifier` · `debugPrint` | `battle.dart:2,18` (`package:flutter/foundation.dart`) |

## 왜 지금 해야 하는가

B1 의 나머지 전부가 이 골격 위에 올라간다. 그리고 이 구간의 목적이
"제약을 잠시 끊어 더 나은 전투를 만드는 것" 이므로, 패키지 경계가 먼저 서야 한다.

## 무엇을 할 것인가

### 디렉토리 2개

| 새로 생기는 것 | 성격 | 실행 | 선례 |
|---|---|---|---|
| `packages/hd_battle/` | model. 라이브러리 | `dart test` | `packages/cm2_script/` |
| `hd_battle_console/` | view + control. 실행체 | `dart run bin/battle.dart <fixture>` | `cm2_script_sample/` |

`pubspec.yaml` 은 `packages/cm2_script/pubspec.yaml` 를 따른다 — `publish_to: none`,
`environment: sdk: ^3.10.0`, `dev_dependencies: test`. **Flutter 의존을 넣지 않는다.**

둘로 나누는 이유: `hd_battle` 이 공개 API 만 export 하면 콘솔 쪽이 `lib/src/` 에 손을 못 댄다.
한 디렉토리에 `lib/` + `bin/` 을 두면 `bin/` 이 내부를 직접 import 할 수 있어
"표현 로직이 model 에 0" 이 말로만 남는다.

### 모드 인계 규격 초안

`lib/src/contract/` 에 네 타입. **이 구간에서는 초안이고, 확정은 [B2-99](../B2-battle-expand/B2-99-freeze-contract.md) 다.**

| 타입 | 방향 | 담는 것 |
|---|---|---|
| `BattleSetup` | RPG → 전투 | 파티 스냅샷(이름·능력치·level·hp/sp/esp·장착 상태) + 적 키 목록 + 난수 시드 |
| `BattleCommand` | view → model | 대상 선택 · 마법 선택 · 도주 시도 · 아이템 사용 · 자동 전투 |
| `BattleEvent` | model → view | 구조화된 사실만 (행위자·대상·종류·수치). **문자열·조사 없음** |
| `BattleOutcome` | 전투 → RPG | 아래 표 |

`BattleOutcome` 이 담는 것 — 지금 전투가 `party` 를 **직접 고치고 있는 것들**이 그대로 목록이다:

| 항목 | 현재 직접 변경하는 위치 |
|---|---|
| 파티 슬롯별 hp/sp/esp·상태이상 최종값 | `battle.dart:527,558` 등 (`t.hp -= …`) |
| 획득 경험치 (총량 하나로 합산) | `battle.dart:286`(정산) + `:446`·`:494`(처치) — **지금 두 곳에서 따로 더해진다** |
| 획득 골드 | `battle.dart:294` |
| 소비한 아이템 | (없음 — B2-06 이 만든다) |
| 전투 밖 효과 요청 | (없음 — B2-01 이 만든다) |
| 종료 코드 | `battle.dart:33` `_battleResult` |

**파티원별 결과는 파티 슬롯 인덱스(`HDPlayer.order`, 0~5)로 키를 잡는다.**
전투가 자기 테이블을 갖기로 했으므로(4차 판정), 이 인덱스가 두 세계를 잇는 유일한 고정점이다.

`BattleSetup` / `BattleOutcome` 은 JSON 직렬화를 갖는다 — fixture 가 코드가 아니라 데이터여야
버리고 다시 만드는 비용이 없다.

## 완료 판정 기준

- [x] `cd packages/hd_battle && dart pub get && dart test` 가 통과한다 (테스트 0건이어도 무방)
- [x] `cd hd_battle_console && dart run bin/battle.dart` 가 실행되고 사용법을 출력한다
- [x] `packages/hd_battle/pubspec.yaml` 에 `flutter` 항목이 없다
- [x] 네 타입이 선언되고, `BattleSetup`·`BattleOutcome` 이 JSON 왕복(`toJson`→`fromJson`)을 통과한다
      → `packages/hd_battle/test/contract/round_trip_test.dart`

## 결과 (2026-09-04)

네 타입은 `BattleSetup`(+`CombatantSnapshot`) · `BattleCommand`(+`BattleDecision`) ·
`BattleEvent` · `BattleOutcome`(+`CombatantResult`) 로 만들었다.

**설계 중 하나 바뀐 것**: 경험치를 총량 하나가 아니라 **슬롯별**로 싣는다.
원작이 두 가지 분배를 쓴다는 것을 이식하면서 확인했다 — 처치 보너스는 공격자에게만
(`battle.dart:446`·`:494`), 승리 정산은 conscious 전원에게 전액(`:286`). 하나로 합치면
분배를 재현할 수 없다.

## 하지 않을 것

전투 로직 이식(B1-02·B1-03) · 규격 확정(B2-99) · RPG 쪽 변경(B3) · `application/battle.dart` 삭제(B4-03).
`hadar2026_app` 은 이 이슈에서 **한 줄도 고치지 않는다.**
