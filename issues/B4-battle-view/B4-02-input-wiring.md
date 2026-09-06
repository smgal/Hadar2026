# B4-02 전투 입력을 배선한다

- **상태**: BLOCKED (B4-01 대기)
- **구간**: B4
- **규모**: M
- **선행**: [B4-01](B4-01-flutter-view.md)
- **설계 근거**: [docs/key_input_policy.md](../../docs/key_input_policy.md) · [CLAUDE.md 입력 모드 절](../../CLAUDE.md)

## 문제

전투 중 키 입력이 `HDWindowKeyDispatcher` 의 창 타입 분기를 타고 처리된다
(`presentation/input/window_key_dispatcher.dart:36-38` — `HDMessageWindow` ·
`HDMagicSelectionWindow` · `HDSelectionWindow`). 전투 전용 창이 없어서
전투 명령이 전부 범용 메뉴 창으로 표현되고 있다.

B2 가 아이템 사용·대상 선택·행동 순서 표시를 추가하면 이 배선으로는 부족하다.

## 무엇을 할 것인가

- 전투 창 타입을 추가하고 `HDWindowKeyDispatcher` 의 분기에 넣는다.
  **도메인 창 클래스는 `handleInput` 을 갖지 않는다** — 레포 규약이다(`CLAUDE.md`).
- 키 배정은 `docs/key_input_policy.md` 를 따른다 (이동 방향키/WASD · 확정 Enter/E · 취소 Esc/Q).
- 모바일 가상 입력(`bottom_control_panel.dart`)에서도 전투가 가능해야 한다.

## 완료 판정 기준

- [ ] 키보드만으로 전투 전 과정을 조작할 수 있다
- [ ] 가상 D-pad·액션 버튼으로도 전투 전 과정을 조작할 수 있다
- [ ] 전투 중 메인 메뉴가 열리지 않는다 (현재 동작 유지 — `input_dispatcher.dart:121` 의 `_handleMap` 만 연다)
- [ ] 키 배정이 `docs/key_input_policy.md` 와 일치한다 (어긋나면 문서를 먼저 고친다)

## 하지 않을 것

새 키 배정 정책 · 리매핑 UI · 전투 규칙 변경.
