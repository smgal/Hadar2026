# lore_world_text

`packages/lore_world` 의 한국어 — 이름표와 문장. 규칙 패키지는 키와 닫힌 열거만 내고,
화면에 나갈 글은 전부 여기서 만든다.

```dart
final world = LoreWorld.newGame(Episode.ep3, hero);
outcomeLines(world.join(rosterEp3['vega']!.build()), world); // ['베가가 일행에 참가했다.']
refusalLine(const Refusal(RefusalReason.noneOwned, key: 'item.hp_potion')); // '하지만 체력 회복약이 없습니다.'
josa('알골', '으로/로');                                     // '알골로'
```

## 공개 함수

| 무엇 | 함수 |
|---|---|
| 조사 | `josa(word, '은/는')` · `particle(word, pair)` |
| 사람 | `memberName(member, episode:)` · `companionName(episode, key)` · `pronoun(gender)` · `genderName` |
| 계급 · 기술치 · 능력치 | `className(m)` · `classNameOf(family, id)` · `familyName` · `skillName(m, i, short:)` · `skillNameOf(family, id, i, short:)` · `abilityName` |
| 물건 · 마법 | `itemName(key)` · `weaponNameOf(m)` · `spellName(key)` · `nameOf(key)` · `nameWith(key, pair)` |
| 그 밖의 열거 | `conditionName` · `treatmentName` · `equipSlotName` · `fieldBuffName` |
| 성격 질문 | `personalityQuestions` · `questionText(i, variant)` · `questionChoices(i, variant)` · `questionIntro` |
| 결과 문장 | `outcomeLines(outcome, world)` · `eventLines(event, world)` · `refusalLine(refusal, world:)` · `noticeLine(text)` |

표: `companionNames` · `summonNames` · `classNames` · `skillNames` · `skillShortNames` · `itemNames` · `spellNames`.

## 지킨 것

- 모르는 키는 **키를 그대로** 돌려준다. 빈 글자가 되면 빠진 이름을 화면에서 찾을 수 없다.
- 기획서가 문구를 정해 둔 곳은 그 문구를 쓰고, 띄어쓰기·맞춤법만 고쳤다(원작자 허락).
  정해 두지 않아 지어 넣은 문장은 `lib/src/sentences.dart` 주석에 「지음」으로 표시했다.
- 성격 질문은 부록 C.6 원문에서 원작 화면의 줄바꿈을 없애고 오타를 고쳤다.
- 글자 색은 앱의 `@X…@@` 표기를 쓴다(경고 `C` 빨강 · 알림 `B` 하늘색 · 중요한 결과 `E` 노랑).
- `summonNames` 는 `packages/lore_battle_text` 의 같은 표와 철자가 같아야 한다. 두 패키지는 서로를
  모르므로 앱 쪽 시험이 맞춰 본다(아직 없음).

## 시험

```bash
dart pub get && dart analyze && dart test   # 24개
```
