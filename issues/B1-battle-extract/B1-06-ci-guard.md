# B1-06 CI 가 `hd_battle` 의 Flutter 의존 0 을 강제한다

- **상태**: DONE
- **구간**: B1
- **규모**: S
- **선행**: [B1-01](B1-01-package-skeleton.md)
- **설계 근거**: [CLAUDE.md CI 절](../../CLAUDE.md) · [P0-17](../P0-foundation/P0-17-ci-gates.md)

## 문제

"model 은 안 바뀐다" 와 "표현 로직이 model 에 없다" 는 **말로는 지켜지지 않는다.**
레포는 이미 같은 문제를 grep 으로 풀었다 — `.github/workflows/ci.yml` 의
"Check layering invariants" 가 `application/`·`domain/` 의 `presentation` import 와
`flutter/material`·`bonfire`·`flame` 사용을 막는다.

`hd_battle` 은 그 검사 범위 밖의 새 패키지다.

## 왜 지금 해야 하는가

B1-04·B1-05 의 완료 판정이 grep 명제인데, 사람이 매번 돌릴 것을 기대할 수 없다.
패키지가 생긴 직후에 넣어야 위반이 쌓이기 전에 걸린다.

## 무엇을 할 것인가

`.github/workflows/ci.yml` 에 잡을 하나 추가한다.

불변조건 4개 — **Flutter 의존 0** · **시드 없는 난수 0** · **한국어 문장 0** · **경험치 표 0** —
의 판정은 `packages/hd_battle/test/flow/purity_test.dart` 가 갖는다. CI 는 그 테스트를 돌리고,
`package:flutter` 만 빠른 실패용 grep 으로 한 번 더 본다.

**왜 grep 세 줄이 아니라 테스트인가**: 각 수식의 주석이 원작 코드를 그대로 인용한다
(`damage -= (damage * Random().nextInt(50)) ~/ 100;`). 생 grep 은 그 주석을 오탐하고,
인용은 이식이 맞는지 확인하는 근거라 지울 수 없다. 테스트는 주석을 걷어낸 뒤 본다.
`package:flutter` 는 주석에 나오지 않으므로 grep 으로도 안전하다.

`hd_battle/lib` 의 주석은 **영어로 쓴다** — 한국어 0 검사에 걸리기 때문이고,
`packages/cm2_script` 와 `hadar2026_app/lib` 이 이미 영어 주석 관례다.

fixture 재생 검사도 같은 잡에 넣었다. fixture 는 시연 입력이자 회귀 테스트 입력이므로,
재생이 결정적이지 않으면 규칙이나 뽑기 순서가 바뀐 것이다.

## 완료 판정 기준

- [x] 불변조건 4개가 CI 에서 돌고, 현재 코드에서 **통과**한다
- [x] `packages/hd_battle` 과 `hd_battle_console` 의 `dart analyze` · `dart test` 가 CI 에서 돌아간다
- [x] `lib` 에 `package:flutter` 를 한 줄 넣으면 grep 과 테스트가 **모두 실패**한다
      (`lib/src/rules/rng.dart` 에 넣어 확인하고 되돌렸다)
- [x] fixture 7개가 CI 에서 재생되고, 두 번 재생한 출력이 같다

## 하지 않을 것

`hadar2026_app` 쪽 CI 변경 · `dart format` 게이트(레포가 아직 format-clean 이 아니다) ·
웹 빌드 스모크(P0-17).
