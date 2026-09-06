# hd_battle_console

[`packages/hd_battle`](../packages/hd_battle/) 의 **view + control**. 순수 Dart 콘솔.

> **그냥 돌려보고 싶으면 → [RUN.md](RUN.md)** (실행 참고, 사람이 보는 것)

```bash
dart pub get
dart run bin/battle.dart                              # 사용법 + fixture 목록
dart run bin/battle.dart fixtures/town1_pair.json     # 대화형으로 플레이
dart run bin/battle.dart fixtures/orc_x3.json --replay
```

`flutter run` 이 아니라 `dart run` 이다. Flutter SDK 없이 돌고, 반복이 빠르다.

## 왜 model 과 별 패키지인가

`hd_battle` 이 공개 API 만 export 하므로, 이쪽에서 `lib/src/` 에 손을 댈 수 없다.
한 디렉토리에 `lib/` + `bin/` 을 두면 `bin/` 이 내부를 직접 import 할 수 있어서
"표현 로직이 model 에 0" 이 말로만 남는다.

**한국어 문장과 조사는 전부 이 패키지가 만든다.** `lib/view.dart` 가 `BattleEvent` 를
원작 문구로 바꾸고, `lib/noun.dart`(조사)와 `lib/magic_names.dart`(마법 이름표)를 쓴다.
색도 마찬가지다 — `lib/palette.dart` 가 원작의 16색 표와 `@` 색 표기를 담고,
`view.dart` 의 `colorOf` 가 이벤트마다 줄 색을 정한다. model 은 색을 모른다.

## fixture

파일 하나에 **전투 개시 입력 + 명령 열 + 난수 시드**를 담는다. 셋이 고정되면 결과가
결정적이라, 같은 파일이 **콘솔 시연용이자 회귀 테스트 입력**이 된다.

| fixture | 보는 것 |
|---|---|
| `town1_pair.json` | 기본 전투. `menu_flows.dart:92-93` 의 조우 |
| `orc_x3.json` | 가장 약한 행. 승리 경험치 바닥값 |
| `devil_hunter_x7.json` | 원작 조우(`L1_ep1d0.cm2`). 같은 적 7마리 |
| `wipe.json` | 종료 코드 2(전멸). 정산이 돌지 않는다 |
| `escape.json` | 종료 코드 0(도주) |
| `magic.json` | 마법이 공식 2개로 뭉쳐 있는 것 (B2-01) |
| `heal.json` | **치료가 HP 를 안 바꾸는 것** (B2-02) |

```bash
# 명령 열 다시 만들기 (규칙이나 시드를 바꾼 뒤)
dart run bin/battle.dart fixtures/orc_x3.json --record=attack --out=fixtures/orc_x3.json

# 새 fixture 의 뼈대 만들기
dart run tool/make_fixtures.dart
```

`--record` 방침: `attack` · `auto` · `escape` · `magic` · `magic-all` · `heal` · `esp`

## 출력 규약

줄 앞의 **`·` 는 원작에 없던 줄**이다 — 독 피해, 골드 획득, 턴 구분. 원작이 조용히
지나가던 것이라 데모에서는 보여야 하지만, "원작과 같은 출력" 을 눈으로 확인할 때
구분되어야 한다. `test/view_test.dart` 가 어느 줄에 표시가 붙는지 고정한다.

## 색

**지어낸 것이 아니라 원작에 있던 규격이다.** 근거와 표 전체는
[`GROUND_TRUTH` 부록 V](../blueprint/_meta/GROUND_TRUTH.md) 에 있다. 요약하면

- 16색 표 `hd_base_gfx.cpp:17-40` — 순서가 DOS 색 번호와 같아 **ANSI 16색과 1:1**
- 줄 단위 색 `writeConsole(색번호, ...)` — 원작의 모든 전투 줄이 색을 달고 나갔다
- 글자 단위 색 `@7`·`@B`·`@@` — `assets/*.cm2` 가 지금도 쓰고 있는 표기
- 이름 색이 곧 상태 — 적은 남은 체력, 일행은 상태(`enemyNameColor`·`conditionColor`)

터미널이면 저절로 켜지고 파이프면 꺼진다. `--color`·`--no-color`·`NO_COLOR` 로 바꾼다.
`view` 에 `HDAnsi.plain` 을 주면 표기만 떼고 맨 문자열이 나온다 — 테스트가 그 경로다.

C++ 에서 되돌린 것이 1건 있다. 일행이 준 피해 줄에 C++ 스스로
`// 원래는 중간이 15번 색` 이라고 적어 둔 자리다([6차 판정](../issues/DECISION-LOG.md)).

## 테스트

```bash
dart test
```

- `test/view_test.dart` — 원작 문구와 줄 색을 그대로 만드는지
- `test/palette_test.dart` — 16색 표·`@` 표기·이름 색 규칙이 원작과 같은지
- `test/replay_test.dart` — 모든 fixture 가 끝까지 돌고, 두 번 돌리면 출력이 같은지
