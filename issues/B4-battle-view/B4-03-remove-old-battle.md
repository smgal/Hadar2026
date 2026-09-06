# B4-03 구 전투 코드를 제거한다

- **상태**: BLOCKED (B4-01 · B4-02 대기)
- **구간**: B4
- **규모**: M
- **선행**: [B4-01](B4-01-flutter-view.md) · [B4-02](B4-02-input-wiring.md)
- **설계 근거**: [MILESTONES §7](../MILESTONES.md)

## 문제

B4-01·B4-02 가 끝나면 아래가 **아무도 쓰지 않는 코드**로 남는다.
두 개의 전투가 공존하면 다음 사람이 어느 쪽이 진짜인지 알 수 없다.

| 제거 대상 | 줄 |
|---|---|
| `lib/application/battle.dart` | 572 |
| `lib/domain/battle/enemy.dart` | 128 |
| `lib/domain/battle/enemy_data.dart` | 109 |
| `lib/application/magic_system.dart` 의 `castBattleSpellUI` | `:183-` |
| `lib/application/menu_flows.dart` 의 `showBattleMenu` | `:90-123` |
| `lib/presentation/panels/battle_overlay.dart` 의 구 구현 | 95 |

`test/application/defense_scale_test.dart` 는 **구 전투식의 대역표를 고정**하고 있으므로
같이 정리한다 — 단 부록 H-2 가 구 전투식 기준임이 [B2-99](../B2-battle-expand/B2-99-freeze-contract.md) 에서
이미 명시된 뒤여야 한다.

## 무엇을 할 것인가

- 위 목록을 지운다. `HDBattle()` 호출처 전부를 새 경로로 바꾼 뒤에 지운다
  (현재 호출처: `game_session.dart:101,151` · `menu_flows.dart:91-121` ·
  `script_engine_adapter.dart:360,363,365,368,509,753` · `battle_overlay.dart:10,12,14,15`).
- `domain/battle/battle_result.dart` 는 **남긴다** — cm2 와의 와이어 계약이고
  [B3-01](../B3-battle-integrate/B3-01-cm2-adapter.md) 의 어댑터가 쓴다.
- `magic.dart` 의 45종 이름표는 전투 밖(야영 마법)에서도 쓰이는지 확인한 뒤 판단한다
  (`magic_system.dart:29-` 의 `castSpell` 은 전투 밖 경로다).

## 완료 판정 기준

- [ ] `grep -rn "HDBattle()" hadar2026_app/lib` 가 빈 결과다
- [ ] `flutter analyze` 와 `flutter test` 가 통과한다
- [ ] `hadar2026_app/lib` 에 전투 규칙 계산식이 남아 있지 않다
- [ ] 웹 빌드(`flutter build web`)가 통과한다 — 새 패키지가 웹에서도 돈다
- [ ] `blueprint/_meta/GROUND_TRUTH.md` §10 과 부록 H 가 갱신되어, 삭제된 파일을 가리키지 않는다

## 하지 않을 것

`battle_result.dart` 삭제 · 세이브 포맷 변경 · 전투 규칙 변경.
