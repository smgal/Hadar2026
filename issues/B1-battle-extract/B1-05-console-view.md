# B1-05 콘솔 view 와 fixture 러너 — 전투 한 판을 눈으로 본다

- **상태**: DONE
- **구간**: B1
- **규모**: M
- **선행**: [B1-04](B1-04-invert-call-direction.md)
- **설계 근거**: [MILESTONES §7](../MILESTONES.md)

## 문제

전투를 확인하려면 지금은 Flutter 앱을 띄우고 맵을 걸어 교전 지점까지 가야 한다.
그래서 반복이 느리고, 특정 상황(적 3종 + 파티 전멸 직전 등)을 재현할 방법이 없다.

## 왜 지금 해야 하는가

B2 의 확장 항목은 전부 **"돌려보고 판단" 이 완료 판정**이다. 판단할 도구가 이 이슈다.
그리고 콘솔이 표현 못 하는 것이 생기면 그것을 model 로 밀어넣게 되므로,
콘솔 view 는 **데모 수준이 아니라 완결된 것**이어야 한다.

## 무엇을 할 것인가

### `hd_battle_console/`

`cm2_script_sample/` 과 같은 모양의 순수 Dart 실행체.

```
dart run bin/battle.dart fixtures/orc_x3.json
```

- `BattleEvent` → 한국어 문장 조립을 **여기서** 한다. `HDNoun`(조사 처리)의 이식본도 여기 둔다.
  `hadar2026_app/lib/domain/text/noun.dart` 는 순수 Dart 라 그대로 옮길 수 있다.
- `pendingDecision` → 콘솔 메뉴 출력 → 키 입력 → `applyCommand`.
- 파티·적 상태를 매 턴 표로 출력한다 (hp/sp/esp·상태이상).

### fixture

파일 하나에 세 가지를 담은 JSON이다.

| 담는 것 | 왜 |
|---|---|
| `BattleSetup` (파티 스냅샷 + 적 키 목록) | 시작 상태 |
| 명령 열 (`BattleCommand` 순서) | 대화형 입력을 대신한다. 비어 있으면 사람이 직접 입력 |
| 난수 시드 | 결과를 결정적으로 만든다 |

셋이 고정되면 결과가 결정적이라, **같은 파일이 콘솔 시연용이자 회귀 테스트 입력**이 된다.
명령 열이 있으면 무인 재생(`--replay`)으로 돌고, 없으면 사람이 플레이한다.

## 완료 판정 기준

- [x] `dart run bin/battle.dart fixtures/<파일>` 로 전투 한 판이 **끝까지** 진행된다
- [x] 같은 fixture 를 `--replay` 로 두 번 돌리면 출력이 **완전히 같다**
- [x] 승리·패배·도주 fixture 가 각각 1개 있고, 종료 후 `BattleOutcome` 을 사람이 읽을 수 있게 출력한다
- [x] `packages/hd_battle` 에 한국어 문장 리터럴이 여전히 0개다 (B1-04 의 판정이 깨지지 않았다)
- [x] `hd_battle_console/pubspec.yaml` 에 `flutter` 항목이 없다

## 결과 (2026-09-04)

fixture 7개. 승리·전멸·도주가 모두 시연되고, 전부 두 번 재생해 출력이 같은 것을
`test/replay_test.dart` 와 CI 가 확인한다.

**출력 규약을 하나 정했다**: 원작에 없던 줄 앞에 `·` 를 붙인다. 원작이 조용히 지나가던 것
(독 피해는 로그가 **아예 없다** — `battle.dart:211-219`, 골드 획득, 턴 구분)이라 데모에서는
보여야 하는데, "원작과 같은 출력" 을 눈으로 볼 때 구분이 되어야 한다.
`test/view_test.dart` 가 어느 줄에 표시가 붙는지 고정한다.

**`heal.json` 이 B2-02 를 그대로 보여준다** — 치료를 40턴 시전하고 전멸한다.

실행 안내는 [`hd_battle_console/RUN.md`](../../hd_battle_console/RUN.md) 에 따로 뒀다 — 사람이 보는 문서다.

## 하지 않을 것

Flutter view(B4-01) · 그래픽·색상 연출 · 전투식 수정(B2) · 세이브·로드.
