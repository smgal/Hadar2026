# W1-06 전투 다리 — `hd_world` → `hd_battle`

- **상태**: DONE (2026-09-09) · 규격 **v4**
- **구간**: W1 ([_README](_README.md))
- **규모**: M
- **선행**: [W1-03](W1-03-derived-values.md)

## 문제

두 모델이 서로를 모른다. 그것이 설계이고, 그래서 **이어 주는 것이 필요하다.**
`hd_battle` 의 `CombatantSnapshot` 은 파생값을 이미 풀어서 받는다 —
`powOfWeapon` · `weaponKey` · `armour` · `rank`. `hd_world` 의 `ResolvedStats` 가
그 값을 전부 갖고 있다.

## 무엇을 할 것인가

다리는 **어느 쪽 패키지에도 넣지 않는다.** 둘 다 아는 세 번째 것이다 —
`packages/hd_bridge` 또는 앱 쪽 `application/` 이다. 지금은 실험실이 임시로 갖는다.

| `hd_world` | → | `hd_battle` |
|---|---|---|
| `ResolvedStats[defence]` | | `armour` / `ac` |
| `ResolvedStats[shieldBlock]` | | `ArmourPieces.shieldBlock` |
| `ResolvedStats.attackPower` | | `powOfWeapon` |
| `ResolvedStats.weaponKind` | | `weaponKey` — **대응표가 필요하다** |
| `Member.style` | | `preset` |
| `ResolvedStats.immunities` | | 아직 받는 칸이 없다 |
| `ResolvedStats[coatingSlots]` | | 지금은 1 고정 |

## 무엇을 했나

`packages/hd_bridge` — 양쪽을 아는 세 번째 것이다. **`hd_world` 도 `hd_battle` 도
서로를 import 하지 않고**, CI 가 그것을 확인한다.

### 막힌 곳이 하나 있었다 — 원거리 무기가 전투에 없었다

전투 무기 표 12줄이 **전부 사거리 3 이하의 근접 무기**였다. 원작에는 쏘는 무기가
일곱 개 있는데(BP-45 §0) 우리 규칙에는 하나도 없어서, **활을 든 사냥꾼을 넘길 키가
없었다.**

그래서 표에 8줄을 더했다 — `bow`(1~3) · `crossbow`(0~3) · `arbalest`(2~3) ·
`thrown`(1~2) 넷과, 손 구성이 만드는 `one_hand_slash` · `sword_shield`(방패 치기) ·
`spear` · `war_hammer`(돌격) 넷.

### 손 구성이 만드는 것은 스냅샷으로 건넨다

단검 둘과 단검 하나는 **표의 같은 줄**이다 — 같은 방식, 같은 사거리. 다른 것은
손 구성이고, 전투는 두 손을 보지 않는다. 그래서 `strikes` · `coatingSlots` ·
`evasionBonus` · `initiativeBonus` 넷이 `CombatantSnapshot` 에 붙는다(규격 v4).

`Combatant.coating` 하나가 **`coatings` 목록**이 되었다. 쌍수가 칸을 둘 갖고,
화면이 이미 2 를 보이고 있었으므로 규칙이 그것을 지켜야 했다.

### 지시 7 → preset 6 의 손실을 적어 두었다

두 쌍이 접힌다 — 사격→시전자(거리는 지키지만 쏘는 대신 시전한다고 본다),
교란→치고빠짐(붙는 이유를 전투가 모른다). 둘 다 **서는 자리를 바꾸지 않으므로**
지금 전투가 preset 에서 읽는 것 전부에는 영향이 없다. BP-46 의 판단 규칙이
서면 그때 늘린다.

## 완료 판정 기준

- [x] `hd_world` 파티가 `BattleSetup` 이 되고 전투가 끝까지 돈다
- [x] `hd_world` 도 `hd_battle` 도 서로를 import 하지 않는다 (CI 가 확인)
- [x] 실험실에서 전투를 한 판 굴려 결과가 파티에 반영된다 (`POST /api/battle`)
- [x] 카탈로그의 모든 무기가 실제 표의 줄에 닿는다 (전수 테스트)
- [x] 빈 자리가 있어도 자리 번호가 밀리지 않는다
