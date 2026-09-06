# hd_battle

Hadar2026 의 전투 model. **순수 Dart** — Flutter 도, 화면도, 문자열도 없다.

## 실행 방법

**이 패키지 자체는 실행할 것이 없다** — `bin/` 이 없는 model 전용 패키지다.
화면이 없으니 전투를 "돌려 보는" 것은 view 쪽 두 곳에서 한다.

### 전투를 굴려 보기 — view 두 개

```bash
# 화면으로 (마우스 · 한 수 물리기 · 브라우저에서도 열린다)
cd ../../hadar2026_app
flutter run -t lib/battle_lab_main.dart
flutter run -d chrome -t lib/battle_lab_main.dart

# 터미널로 (기록·재생·시드·방침 자동 플레이)
cd ../../hd_battle_console
dart pub get
dart run bin/battle.dart                            # fixture 목록
dart run bin/battle.dart fixtures/rules/orc_x3.json # 대화형
```

**둘이 같은 fixture 를 읽는다.** 실행 안내는 [`hd_battle_console/RUN.md`](../../hd_battle_console/RUN.md).

### 이 패키지에서 돌리는 것 — 테스트와 실측 도구

```bash
dart pub get
dart test                    # 351개 — 규칙 · 규격 · 흐름 · 불변조건

# 수치를 직접 재는 도구. 사람이 전투를 칠 필요가 없다.
dart run tool/damage_band.dart    # 적↔아군 피해 대역 (부록 X-4 를 이걸로 만든다)
dart run tool/opening_gap.dart    # 적 75종의 초기 간격 분포 (부록 X-1)
dart run tool/target_share.dart   # 대열별 피격 비율 (부록 X-3)
dart run tool/escape_odds.dart    # 간격별 도망 성공률 (부록 Y-2)
```

세 도구는 표를 markdown 으로 찍는다 — `GROUND_TRUTH` 부록에 그대로 붙는다.
**밸런스는 이쪽으로 본다.** 플레이해서 재려고 하면 표본이 모자란다.

## 왜 별 패키지인가

전투를 RPG 에서 완전히 떼어 제약 없이 확장한 뒤 되붙이는 노선이다
([`issues/MILESTONES.md` §7](../../issues/MILESTONES.md) · [판정 이력](../../issues/DECISION-LOG.md)).
**B1(분리) · B2(확장) · B5(위치) · B6(메뉴 현대화)까지 완료**됐고, 모드 인계 규격은
[CONTRACT.md](CONTRACT.md) **v3** 로 확정됐다. B3(RPG 연결)는 4/5, B4(Flutter view)는
실험실 모드까지 왔다 — 남은 것은 B3-04 · B4-02 · B4-03 이다.

## 쓰는 법

model 은 아무것도 호출하지 않는다. 물어볼 것을 내놓고, 답을 받고, 한 걸음씩 나아간다.

```dart
final battle = Battle(setup);            // setup: BattleSetup (파티 스냅샷 + 적 키 + 시드)

while (!battle.isFinished) {
  final decision = battle.pendingDecision;
  if (decision == null) {
    render(battle.advance());            // List<BattleEvent>
  } else {
    render(battle.applyCommand(answer(decision)));
  }
}

apply(battle.outcome!);                  // BattleOutcome → RPG 가 반영
```

`BattleEvent` 는 **사실만** 담는다(행위자·대상·종류·수치). 문장·조사·언제 멈출지는
view 의 일이다 — 그래서 콘솔 view 와 Flutter view 가 이 패키지를 그대로 공유한다.

## 모드 인계

| 방향 | 타입 | 담는 것 |
|---|---|---|
| RPG → 전투 | `BattleSetup` | 파티 스냅샷 + 적 키 목록 + 난수 시드 |
| view ↔ model | `BattleCommand` / `BattleEvent` | 명령과 사실 |
| 전투 → RPG | `BattleOutcome` | 슬롯별 hp/sp/esp·상태이상 + 경험치 + 골드 + 소비 아이템 + 전투 밖 효과 요청 + 종료 코드 |

파티원별 결과의 키는 **파티 슬롯 인덱스**(`CombatantSnapshot.slot`, 0~5)다.
전투가 자기 테이블을 갖기 때문에, 이 인덱스가 두 세계를 잇는 유일한 고정점이다.

종료 코드의 정수값은 원작 cm2 스크립트와의 계약이다 — `evade 0 / win 1 / lose 2 / 미결 -1`
(`hadar2026_app/assets/const.cm2:53-55`).

## 재현성

난수는 `BattleSetup.seed` 로 만든 **하나의** 생성기에서만 나온다. 그래서

> 같은 개시 입력 + 같은 명령 열 + 같은 시드 → 같은 정산 결과

가 성립하고, 이것이 B1 의 완료 판정이다. **뽑는 순서도 계약**이다 — 원작의 평가 순서와
단축 평가(`&&` 가 뽑기를 건너뛰는 것)까지 그대로 옮겼다.

## 불변조건 4개

`test/flow/purity_test.dart` 와 CI 가 지킨다. 확장 항목이 바뀌어도 이 넷은 안 바뀐다.

- Flutter 의존 0 (`foundation.dart` 포함)
- 시드 없는 `Random()` 0
- 한국어 문장 0 — 표현은 전부 view 소유
- 경험치 표 0 — 레벨업은 RPG 가 판정한다

## 구조

```
lib/src/contract/   개시 입력 · 명령 · 이벤트 · 정산 결과 · 종료 코드
lib/src/data/       적 테이블 75행 (문자열 키, legacyId 보존)
lib/src/rules/      전투식 19개 + 난수 + 마법 카테고리 표
lib/src/model/      전투 상태기계 · 전투원 · 적 인스턴스
```

`lib/src/rules/` 의 각 함수 주석에 **원작 위치(`battle.dart:462` 등)와 원래 코드**가 붙어 있다.
이식이 맞는지 확인하려면 그 주석과 `test/rules/` 를 같이 본다.

## 규칙이 어디에 있는가

`lib/src/rules/` 의 각 파일 주석에 **원작 위치와 원래 코드**, 그리고 **우리가 정한 것은
왜 그렇게 정했는지**가 붙어 있다. C++ 은 정본이 아니므로(6차 판정) 값을 판단한 곳이 많고,
그 근거를 남기는 것이 Pascal 원본이 나올 때 대조할 유일한 방법이다.

| 파일 | 무엇 |
|---|---|
| `collapse.dart` · `condition.dart` | HP 0 의 한 규칙, 의식불명 누적값 |
| `cure.dart` | 치료 네 갈래와 조합표 |
| `attack_magic.dart` | 공격 마법 1~18, 특수 마법의 능력 감소 |
| `esp.dart` | 초능력 41~45 (영입 · 랜덤 효과표) |
| `enemy_ai.dart` · `superhuman.dart` | 적 행동 사다리, 소환·탈취 |
| `initiative.dart` | 행동 순서 |
| `battle_item.dart` · `mitigation.dart` · `affinity.dart` | 물건 · 부위별 방어구 · 속성 |
| `physical.dart` · `escape.dart` · `settle.dart` · `vitals.dart` | B1 이 그대로 옮긴 것 |

## 남은 것

**밸런스는 손대지 않았다.** `GROUND_TRUTH` 부록 U 가 두 문제를 기록해 뒀다 —
Black Knight 의 최대 피해 945, 마법이 물리를 압도. 둘 다 원작 수식을 옮긴 결과이고,
RPG 에 붙여서 플레이해 본 뒤 판단하기로 했다(7차 판정).

다음 구간은 [`issues/B3-battle-integrate/`](../../issues/B3-battle-integrate/).
