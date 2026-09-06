# B6-06 콘솔 · Flutter view 에 적용

- **상태**: DONE (2026-09-06)
- **구간**: B6
- **규모**: M
- **선행**: B6-01 ~ B6-05

## 무엇을 할 것인가

두 view 가 **같은 것**을 보여야 한다. 그래서 글과 emoji 는 `hd_battle_text` 한 곳에 둔다.

| 무엇 | 어디 |
|---|---|
| `SkillScope` → emoji (🎯 💥 ☠ 💚 💞 🌀 🔮) | `hd_battle_text/menu_labels.dart` |
| 기술 한 줄 (`🎯 마법 화살    SP 1`) | 〃 |
| 못 쓰는 기술의 표시 (어둡게 + 이유) | 〃 |
| 도포 상태 (`🟣 독 2`) — 이름 옆에 | 상태 표 |
| 새 이벤트 문장 — 발랐다 · 풀렸다 · 마비됐다 · 도망 실패 | `battle_lines.dart` |

콘솔은 fixture 20개를 새 메뉴로 **다시 기록**한다(`make_fixtures.dart`) — 명령 열의
`BattleAction` 이 바뀌므로 옛 기록은 어긋난다. `record` 방침 이름도 새 메뉴에 맞춘다.

Flutter 는 `battle_screen.dart` 의 `_menuFor` 가 `SkillOption` 을 읽게 한다.
`battle_controller.dart` 는 안 바뀐다 — 물음·답의 형태가 같다.

## 결과 (2026-09-06)

글과 글자는 전부 `hd_battle_text` 에 있다 — `menu_labels.dart` 의 `scopeGlyph` ·
`skillLine` · `orderLabel` · `itemLine` · `coatingBadge`, `item_names.dart` 의
`coatingGlyph` · `coatingName`, `battle_lines.dart` 의 새 이벤트 6종.

- 콘솔: `view.dart` `spellMenu`/`orderMenu`, 상태 표 이름 옆 `🟣독 2`. `runner.dart` 의
  방침 이름은 그대로 두고 **범위 필터**로 바꿨다(`magic` = 🎯 SP, `heal` = 💚💞 …),
  `coat`·`skill` 추가. fixture **23개** 재기록(+`coating` · `escape_gap`).
- Flutter: `battle_runner.dart`(게임 안 메뉴) · `battle_screen.dart`(실험실) 둘 다 같은
  함수를 부른다. `battle_controller.dart` 는 안 바뀌었다.

## 완료 판정 기준

- [x] 콘솔 fixture 21개가 새 메뉴로 다시 기록되고 재생된다
- [x] 실험실에서 기술 목록이 emoji 와 함께 뜨고 고를 수 있다
- [x] 도포 상태가 두 view 모두에서 이름 옆에 보인다
- [x] 두 view 가 같은 문구를 쓴다 (한쪽에만 있는 문자열 0)
