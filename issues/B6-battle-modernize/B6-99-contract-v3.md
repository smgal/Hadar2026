# B6-99 규격 v3 동결

- **상태**: DONE (2026-09-06)
- **구간**: B6
- **규모**: S
- **선행**: B6-01 ~ B6-06

## v2 → v3 에서 바뀐 것

| 무엇 | v2 | v3 |
|---|---|---|
| `BattleAction` | 14개 (마법 5갈래) | **10개** — `castSkill` 하나 |
| `SpellDecision` | `magicIds: List<int>` + `action` | `options: List<SkillOption>` — 범위·자원·비용·가용 |
| `escape` | 슬롯 1~ 각자 | **리더**만 · `gap` 보너스 |
| 리더 | 슬롯 0 고정 | 의식 있는 최소 슬롯 |
| `Combatant` | — | `coating: WeaponCoating?` |
| `BattleSetup.held` | 전투 키 | 그대로 (RPG 가 소비품 카탈로그로 대응) |
| 이벤트 | — | `WeaponCoated` · `CoatingExpired` · `EnemyParalyzed` · `EscapeFailed(party)` |

## 결과 (2026-09-06)

`CONTRACT.md` 머리글이 v3 이고 `contractVersion == 'v3'`. `purity_test.dart` 에
**emoji 0** 규칙이 더해졌다. 위 표의 항목이 전부 `CONTRACT.md` 「v2 에서 달라진 것」에 있다.

이번 v3 에 **넣지 않은 것**: `Enemy::ChangeAttribute` 의 적별 덮어쓰기(B3-01, 23곳) —
별개 판정. `worldEffects` 의 존폐(B3-04).

## 완료 판정 기준

- [x] `CONTRACT.md` 가 v3 을 적고 `contractVersion == 'v3'`
- [x] 위 표의 항목이 전부 `CONTRACT.md` 에 있다
- [x] `purity_test.dart` 통과 (Flutter · 한국어 · emoji · 시드 없는 난수 · 경험치 표 — 전부 0)
