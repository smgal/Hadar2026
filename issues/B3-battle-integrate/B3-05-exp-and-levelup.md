# B3-05 경험치·레벨업 정산을 RPG 로 옮긴다

- **상태**: DONE (2026-09-06)
- **구간**: B3
- **규모**: S
- **선행**: [B3-02](B3-02-setup-and-settle.md)
- **설계 근거**: [DECISION-LOG 4차 판정](../DECISION-LOG.md)

## 문제

경험치가 **두 곳에서 따로** 더해지고, 레벨업이 전투 안에서 일어난다.

| 무엇 | 곳 |
|---|---|
| 처치 경험치 | `battle.dart:446` · `:494` — `p.experience += t.level * 10` |
| 승리 정산 경험치 | `battle.dart:276-286` — `totExp` 를 다시 더한다 |
| 레벨업 | `battle.dart:287` `p.checkLevelUp()` — **레포에서 유일한 호출처** |
| 레벨업 메시지 | `battle.dart:288-291` |

4차 판정: **전투 중에 레벨이 오르는 일은 없다.** level 은 개시 입력으로 받고,
전투는 경험치 총량만 돌려준다. 그러면 21단계 경험치 표(`player.dart:345-366`)와
`checkLevelUp()` 이 `hd_battle` 에서 **완전히 빠진다.**

## 무엇을 할 것인가

- 전투는 경험치를 **총량 하나**로만 보고한다. 처치 보너스와 승리 정산을 합친다.
- `checkLevelUp()` 호출과 레벨업 메시지를 전투 종료 후 RPG 쪽으로 옮긴다.
- 콘솔 view 는 "경험치 N 획득" 까지만 출력한다 — 레벨업은 RPG 의 일이므로 보여주지 않는다.

## 완료 판정 기준

- [ ] 경험치가 정확히 한 번만 더해진다 (처치 + 정산의 중복 없음)
- [ ] 전투 종료 후에 레벨업이 판정되고 메시지가 나온다
- [ ] `packages/hd_battle` 에 경험치 표가 없다 (`grep -rn "1500\|checkLevelUp" packages/hd_battle/lib` 가 빈 결과)
      → `hadar2026_app/test/application/exp_settle_test.dart`

## 결과 (2026-09-06)

`hadar2026_app/lib/application/battle_bridge/level_up.dart` — `settleLevelUps`.

### 실은 **레벨이 전혀 오르지 않고 있었다**

`checkLevelUp()` 을 부르는 곳이 레포에 하나뿐이었는데(`application/battle.dart:287`),
B3 가 전투를 새 model 로 옮기면서 그 파일이 죽은 코드가 됐다. 그 뒤로 경험치만
쌓였다. 착수 전 문서는 "두 곳에서 더한다" 는 옛 결함만 적고 있었고, **호출처가
사라진 쪽**은 적혀 있지 않았다.

### 갈라진 자리

| 무엇 | 어디 |
|---|---|
| 경험치 총량 (처치 + 승리 정산) | `packages/hd_battle` — 누적기 **하나** (`CombatantResult.experienceGained`) |
| `p.experience` 에 더하기 | `setup_assembly.dart` `applyOutcome` — **한 번** |
| 레벨 판정 · 메시지 | `level_up.dart` `settleLevelUps` — 정산 **뒤** |

순서가 중요하다 — `checkLevelUp()` 은 오르면 hp/sp/esp 를 최대로 채우므로,
`applyOutcome` 보다 먼저 부르면 회복분이 전투 결과로 덮인다.

### 이긴 전투에서만 올린다

지거나 도망친 전투에서도 처치 경험치는 들어간다. 그때 레벨을 올리지 않는 것은
원작과 같고, 경험치는 남아 있다가 **다음에 이길 때 함께** 오른다.
"레벨이 올랐다!" 와 "전멸했습니다" 가 잇달아 나오지도 않는다.

### 의식은 다시 따지지 않는다

규격이 이미 "의식 있는 사람에게만" 을 적용해 경험치를 나눠 놓았다. RPG 가 또
따지면 **막타를 넣고 쓰러진 사람**이 자기 몫을 못 받는다. 그래서 판정 조건은
`experienceGained > 0` 하나다.

## 완료 판정 기준 (충족)

- [x] 경험치가 정확히 한 번만 더해진다
- [x] 전투 종료 후에 레벨업이 판정되고 메시지가 나온다
- [x] `packages/hd_battle` 에 경험치 표가 없다 — `purity_test.dart` 가 지킨다
      (`grep -rn "1500\|checkLevelUp" packages/hd_battle/lib` 빈 결과)
- [x] `hadar2026_app/test/application/exp_settle_test.dart` (5개)

## 하지 않을 것

경험치 표·성장식 수정 · 레벨업 연출 · 전투 중 레벨업 지원.
