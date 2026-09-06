# B6-01 최상위 메뉴를 여섯 줄로 · 기술 목록을 하나로

- **상태**: DONE (2026-09-06)
- **구간**: B6
- **규모**: L
- **선행**: [B5-99](../B5-battle-position/B5-99-freeze-contract-v2.md) ✅ · [B4-01](../B4-battle-view/B4-01-flutter-view.md) ✅

## 문제

`BattleAction` 이 **메뉴 줄과 1:1** 이라, 마법의 갈래가 늘면 최상위 메뉴가 늘어난다.
지금 `castSingle` · `castAll` · `castSpecial` · `heal` · `esp` **다섯 줄이 전부 마법**이다.

그리고 그 나눔의 기준이 **번호대**다. `spellbook.dart` 의 `spellCategories` 를 보면
1~6 / 7~12 / 13~18 / 19~32 / 41~45 — 무엇을 하는지가 아니라 어디에 적혀 있는지로 갈렸다.

## 무엇을 할 것인가

### `BattleAction` 을 줄인다

| 없앤다 | 대신 |
|---|---|
| `castSingle` · `castAll` · `castSpecial` · `heal` · `esp` | **`castSkill` 하나** |

나머지(`attack` · `useItem` · `brace` · `charge` · `escape` · `autoBattle` ·
`advanceFormation` · `retreatFormation` · `skip`)는 그대로 둔다.
와이어 값은 **기존 값을 재활용하지 않는다** — 세이브와 fixture 가 읽으므로 새 값을 준다.

### `SpellDecision` 이 범위·자원을 함께 싣는다

model 은 emoji 를 모른다. **열거값**을 낸다.

```dart
enum SkillScope { oneEnemy, allEnemies, curse, oneAlly, allAllies, selfWeapon }
enum SkillResource { sp, esp }

class SkillOption {
  final int magicId;
  final SkillScope scope;
  final SkillResource resource;
  final int cost;        // 고정 비용. 가변이면 -1
  final bool affordable; // 지금 쓸 수 있는가
}
```

`SpellDecision.options` 가 `List<SkillOption>` 이 된다. 글자와 emoji 는
`hd_battle_text` 가 붙인다 — 한국어도 emoji 도 model 에 들어가지 않는다.

### 못 쓰는 기술도 **보여 준다**

지금은 `castableSpells` 가 아예 빼 버려서, 왜 안 보이는지 알 수 없었다.
목록에 두되 `affordable: false` 로 표시하고 고르면 거절한다.
**레벨이 모자라 아직 못 배운 것은 여전히 안 나온다** — 그건 존재하지 않는 것이다.

## 결과 (2026-09-06)

`packages/hd_battle/lib/src/contract/battle_command.dart` · `rules/spellbook.dart` ·
`model/battle.dart` `_actionOptions` / `_orderOptions` / `_skillsFor`.

```
⚔ 공격 — 단도로 · ✨ 기술 — 마법과 초능력 · 🎒 물건 · 🛡 버팀 · 🏃 도망 · ⚙ 지시
```

리더가 아니면 넷(+돌격). 지시는 **하위 메뉴**(`OrderDecision`)로 뺐다 — 자동 전투·
전진·후퇴를 최상위에 두면 리더 메뉴가 9줄이 된다. `BattleAction` 14 → 10.

`SkillOption` 이 범위·자원·비용·가용을 싣고, `hd_battle_text` 의 `skillLine` 이
`🎯 마법 화살    SP 1` 로 그린다. 못 쓰는 것은 `(부족)` 으로 어둡게 남는다.
정렬은 단일 → 전체 → 도포 → 저주 → 치료 → 초능력(`castableSkills`).

emoji 가 model 에 들어가지 않는 것은 `purity_test.dart` 가 새 규칙으로 지킨다.

### 8줄을 넘으면 범위로 한 번 접는다 (2026-09-06 추가)

실제로 굴려 보니 레벨 20 술사는 **37줄**이었다 — 한 목록의 값보다 비용이 컸다.
갈래를 되살리지는 않는다. **8줄을 넘을 때만** 첫 화면을 범위 묶음(≤7)으로 하고 두 번째가
그 안 목록이다. 초반 파티는 한 화면 그대로다. 규칙은 `hd_battle_text` 의
`skillListFolds` · `skillGroups` 한 곳에 있고 콘솔 · 게임 메뉴 · 실험실이 같이 쓴다.
**model 은 모른다** — 답은 여전히 `ChooseSpell` 하나라 규격은 그대로다.

```
어떤 기술을 ===>            🎯 한 명 공격 ===>
  1) 🎯 한 명 공격  6          1) 🎯 마법 화살    SP 1
  2) 💥 전체 공격  6           2) 🎯 마법 화구    SP 4
  3) 🌀 무기에 바르기  1        …
  4) ☠ 약화  0/4             ← 못 쓰는 것은 분수로
  5) 💚 한 명 치료  7
  6) 💞 모두 치료  7
  7) 🔮 초능력  6
```

## 완료 판정 기준

- [x] 최상위 메뉴가 **여섯 줄 이하**다 (조건부 항목 포함해서 8줄을 넘지 않는다)
- [x] 기술을 고르는 데 **한 단계**만 걸린다 (갈래 선택이 없다)
- [x] `SkillOption` 이 범위·자원·비용·가용을 싣는다
- [x] `hd_battle` 에 emoji 도 한국어도 없다 (`purity_test.dart` 유지)

## 하지 않을 것

마법의 **효과** 변경(B6-02 가 재분류만 한다) · 비용표 재설계 · 새 마법 추가.
