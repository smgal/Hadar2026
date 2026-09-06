# B3-02 개시 입력을 조립하고 정산 결과를 반영한다

- **상태**: DONE
- **구간**: B3
- **규모**: L
- **선행**: [B5-99](../B5-battle-position/B5-99-freeze-contract-v2.md) · [B3-01](B3-01-cm2-adapter.md)
- **설계 근거**: [DECISION-LOG 4차 판정](../DECISION-LOG.md) · `packages/hd_battle/CONTRACT.md`

## 문제

지금 전투는 RPG 상태를 **직접 고친다.**

| 무엇 | 곳 |
|---|---|
| hp 감소 | `battle.dart:479,527,558` 등 |
| 경험치 | `:286`(정산) + `:446`·`:494`(처치) — **두 곳에서 따로 더해진다** |
| 골드 | `:294` `_party.gold += …` |
| 파티 접근 | `:31` `HDGameSession().party` |

새 전투는 RPG 를 모르므로, 이 경로를 **조립(개시)과 반영(정산)** 두 지점으로 모아야 한다.

## 무엇을 할 것인가

- **개시**: `HDParty` → `BattleSetup` 조립기. 파티 슬롯 인덱스(`HDPlayer.order`)를 키로 싣고,
  장착 상태와 전투용 소비품은 **투영만** 넣는다(원본을 넘기지 않는다).
- **정산**: `BattleOutcome` → `HDParty` 반영기. 슬롯 인덱스로 되찾아 hp/sp/esp·상태이상을 쓰고,
  골드를 더하고, 소비 아이템을 가방에서 뺀다([B2-06](../B2-battle-expand/B2-06-battle-items.md) 이 목록만 보고한다).
- 경험치·레벨업은 [B3-05](B3-05-exp-and-levelup.md) 가 처리한다.
- 반영 후 `HDHosts().ui.refresh()` 를 부른다 — 세션 상태를 제자리에서 바꾼 경우의 레포 규약이다
  (`CLAUDE.md`: *"Application code that mutates map state in place … must call `refresh()`"*).
- 난수 시드는 개시 시점에 정한다. 세이브에 넣을지는 이 이슈에서 결정해 적는다.

## 완료 판정 기준

- [ ] 전투 후 파티의 hp/sp/esp·상태이상이 `BattleOutcome` 과 **정확히 일치**한다
- [ ] 골드와 소비 아이템이 정확히 한 번만 반영된다 (중복 반영 없음)
- [ ] 전투 model 이 `HDParty` 를 직접 참조하는 곳이 **0곳**이다
- [ ] 전투 중 파티 원본이 변경되지 않는다 — 정산 전에는 hp 가 그대로다
      → `hadar2026_app/test/application/battle_handoff_test.dart`

## 하지 않을 것

경험치·레벨업(B3-05) · 전투 밖 효과 요청(B3-04) · 속성(B3-03) · Flutter view(B4).


## 결과 (2026-09-05)

`battle_bridge/setup_assembly.dart` (조립·되쓰기) · `battle_runner.dart` (운전).

### 호출 방향이 뒤집혀 있다

예전 전투는 규칙 안에서 `_host.showMenu` 를 직접 불렀다 — 규칙과 화면이 한 함수에
섞여 있어 헤드리스로 돌릴 수 없었다. 새 model 은 물을 것이 있으면
`pendingDecision` 을 내놓고 기다린다.

`HDBattleRunner` 는 그 물음을 `UiHost` 메뉴로 옮기고 답을 `applyCommand` 로 돌려주는
**얇은 운전자**다. **규칙이 한 줄도 없다** — 테스트의 가짜 화면이 `showMenu` ·
`addLog` · `refresh` 말고 다른 것을 부르면 던지게 해서 그 사실을 고정한다.

문장은 `packages/hd_battle_text` 가 만든다. **콘솔과 앱이 같은 문장을 쓴다.**

### 정산은 끝나고 정확히 한 번

예전에는 진행 중에 RPG 상태를 직접 고쳤고 경험치를 두 곳에서 더했다 — 무엇이 언제
바뀌는지 추적할 수 없었다. 이제 `applyOutcome` 하나다.

테스트가 **정산 전에는 파티가 그대로**임을 확인한다.

### 레벨업은 하지 않는다

경험치만 더한다. 올릴지는 RPG 가 따로 판정한다([B3-05](B3-05-exp-and-levelup.md)).

## 완료 판정 기준

- [x] 전투 model 이 `HDParty` 를 직접 참조하는 곳이 0곳
- [x] 개시 입력이 파생값(`ac`·`armour`·`powOfWeapon`·`weaponKey`·`rank`)을 풀어서 넘긴다
- [x] 정산이 정확히 한 번 반영된다 — 상태·경험치·골드·이탈·합류
- [x] 화면 없이 전투가 끝까지 돈다 (가짜 `UiHost`)
      → `test/application/battle_bridge/` (28개)

## 남긴 것

**전투 밖 효과 요청**(`worldEffects`)은 아직 해석하지 않는다 —
[B3-04](B3-04-world-effects.md).
**전투 중 소비 아이템**은 가방에서 빼지 않는다 — 키 대응이 없다(B3-03 참조).