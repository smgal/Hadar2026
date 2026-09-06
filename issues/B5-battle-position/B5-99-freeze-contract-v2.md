# B5-99 규격 v2 확정 (구간 종료)

- **상태**: DONE
- **구간**: B5 — **종료 판정** ([_README](_README.md))
- **성격**: 판정
- **규모**: M
- **선행**: B5 전체

## 무엇을 할 것인가

`packages/hd_battle/CONTRACT.md` 를 **v2** 로 올린다. v1 은 지운다.

| 무엇 | 어디서 왔나 |
|---|---|
| `CombatantSnapshot.rank` · `BattleSetup.initialGap` | [B5-01](B5-01-rank-and-gap.md) |
| 무기의 사거리·공격 방식 (아군은 스냅샷, 적은 테이블) | [B5-02](B5-02-weapon-reach.md) |
| `Element` 에 베기/찌르기/타격 | [B5-06](B5-06-physical-elements.md) |
| preset 식별자 | [B5-08](B5-08-presets.md) |
| `BattleSetup.partyCapacity` · `recruits` 가 실제 슬롯 | [B5-09](B5-09-join-mid-battle.md) |

## 결과 (2026-09-05)

`packages/hd_battle/CONTRACT.md` 를 **v2** 로 올렸다. `contractVersion` 도 `'v2'` 다.

### v1 에서 달라진 것

| 어디 | 무엇 |
|---|---|
| `BattleSetup` | `initialGap` · `enemyRanks` · `partyCapacity` |
| `CombatantSnapshot` | `rank` · `weaponKey` · `weakTo` · `dodgesBack` · `preset` · `knownPresets` |
| `BattleOutcome` | `recruits` 가 **실제 슬롯**을 싣는다 (v1 은 `slot: -1`) |
| `BattleEvent` | 12종 추가 — 사거리 2 · 진형 3 · 밀림 4 · 기타 |

### 불변조건이 넷에서 다섯으로

`cm2_script` 의존 0 이 추가됐다 — preset 을 cm2 로 쓰고 싶은 유혹이 있었지만
model 이 스크립트 엔진에 결합되면 순수 Dart 가 아니게 된다. preset 은 전투가 읽는
**데이터**이고, cm2 는 RPG 쪽에서 그 값을 주고 고치는 데만 쓴다.

### 그리고 B5 가 더한 불변식 하나

> **사거리 밖은 벌점이지 무효가 아니다.**

세 곳에서 지켜진다 — 규칙(가로채기가 100% 가 안 된다) · 무기 표(모든 무기가 모든
거리에서 무언가는 한다) · 메뉴(못 할 것을 안 내놓는다).
`purity_test.dart` 가 **최대 거리에서 싸워도 피해가 난다**는 것을 끝까지 돌려 확인한다.

## 완료 판정 기준 — 자동 검증

B1·B2 가 세운 불변조건을 그대로 이어받는다.

- [x] `packages/hd_battle` 의 Flutter 의존 0 (CI + `purity_test.dart`)
- [x] 시드 없는 `Random()` 0
- [x] 코드에 한국어 문장 리터럴 0 (주석 제외)
- [x] 경험치 표 0
- [x] 재현성 — fixture 20개가 매번 확인
- [x] **확장 항목마다 5인 fixture 1개** — B5 것 넷을 새로 넣었다
      (`reach` · `knockback` · `formation` · `preset`)
- [x] `hd_battle` 이 `cm2_script` 에 의존하지 않는다

## 완료 판정 기준 — B5 고유

- [x] **헛턴이 나오는 경로가 하나도 없다** — `purity_test.dart` 가 최대 거리 전투를
      끝까지 돌려 확인한다
- [x] 새 대역표가 부록 X-4 에 실린다
- [x] 위치가 실제로 결정을 만든다 — 앞열이 뒷열의 3배를 맞는다 (부록 X-3, 400판 실측)

## 시연 판정 — 사람이 본다

콘솔에서 다음이 **읽히는가**:

1. 졸개를 밀어내면 뒤의 보스가 드러난다 — `fixtures/rules/knockback.json` ✅
2. 앞에 나온 사람이 실제로 더 맞는다 — 부록 X-3 ✅
3. 긴 무기와 짧은 무기가 서로 다른 간격을 원한다 — `fixtures/rules/formation.json` ✅
4. 대열 명령이 상쇄되는 것이 보인다 — `일행이 물러섰다, 적이 밀고 들어왔다 — 간격은 그대로 1` ✅

## 이 판정이 틀릴 수 있는 지점

- **3~4 라운드에 위치 기제가 안 들어갈 수 있다.** B5-01 의 초기 간격 실측이 첫 관문이다
- **DQ 의 무기 사다리가 표가 된다**(B5-02). 상점·드랍 설계가 3배가 될 수 있다
- **메뉴가 한 겹 깊어진다**(B5-06). 베기/찌르기/타격이 매 턴 물음이 된다
- **Pascal 이 나오면**(6차 판정) B5 는 대부분 우리 판단이라 대조할 것이 많다
