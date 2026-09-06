# hd_battle_text

`hd_battle` 의 `BattleEvent` 를 **한국어 문장**으로 바꾼다. 순수 Dart —
Flutter 도 터미널도 모른다.

## 왜 따로 있나

`hd_battle` 은 **코드에 한국어 0** 이 불변조건이다(B1-04). 그래서 문장은 바깥에
있어야 하는데, 콘솔(`hd_battle_console`)과 Flutter view(B4)가 **같은 문장**을 써야
한다. 한쪽에 두면 다른 쪽이 900줄을 베낀다.

```
hd_battle          규칙과 이벤트 (한국어 0)
   ↑
hd_battle_text     문장과 조사          ← 여기
   ↑                    ↑
hd_battle_console  터미널 색·표    hadar2026_app  Flutter view (B4)
```

## 무엇이 있나

| | |
|---|---|
| `battleLines(event, names)` | 이벤트 하나 → 줄 목록 |
| `battleLineColor(event)` | 원작 `writeConsole` 의 색 번호 (부록 V) |
| `HDNoun` | 조사 — `은/는` `이/가` `을/를` `과/와` `으로/로` |
| `magicName` · `itemName` · `methodName` · `elementName` | 이름표 |

**이름은 호출자가 준다.** `BattleNames` 가 슬롯·적 번호를 이름으로 바꾸는 방법을
넘겨받는 인터페이스다 — 전투 model 을 이 패키지가 들고 있지 않아도 되게 하려고 그렇다.

## 원작에 없던 줄

앞에 `· ` 가 붙는다 (`addedMarker`). 독 피해·골드·턴 구분처럼 원작이 조용히
지나가던 것들이다.
