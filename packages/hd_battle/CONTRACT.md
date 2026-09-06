# 모드 인계 규격 v3

**확정 2026-09-06** ([B6-99](../../issues/B6-battle-modernize/B6-99-contract-v3.md)).
v2 는 B5-99 가 얼렸고 B6(전투 메뉴 현대화, 9차 판정)이 다시 열었다.
여기서 벗어나는 변경은 새 판정을 받는다.

> **v2 에서 달라진 것** — 전부 B6 다. 규칙(B1·B2·B5)은 그대로고 **무엇을 언제 묻는지**가 바뀌었다.
>
> | 어디 | 무엇 | 왜 |
> |---|---|---|
> | `BattleAction` | 14개 → **10개**. `castSingle·castAll·castSpecial·heal·esp` 가 **`castSkill` 하나**로. `orders` 신설 | 최상위 메뉴 13줄 → 6줄 |
> | `SpellDecision` | `options: List<SkillOption>` — 범위(`SkillScope`) · 자원(`SkillResource`) · 비용 · 가용 | 한 목록에서 글자가 갈래를 말한다 |
> | `OrderDecision` | 신설. 리더의 지시(자동 전투 · 대열) — `ChooseAction` 으로 답한다 | 최상위에서 세 줄을 뺐다 |
> | 리더 | 슬롯 0 고정 → **의식 있는 최소 슬롯** | 슬롯 0 이 쓰러져도 대열·도망이 된다 |
> | `escape` | 슬롯 1~ 각자 → **리더의 파티 행동**. `gap × 15` 보너스, 실패하면 전원이 라운드를 잃는다 | 다섯이 굴리면 자동 성공이었다 |
> | 마법 13 · 16 | 13 은 **자기 무기 도포**, 16 은 **ESP** | 번호대가 아니라 성격으로 |
> | `Combatant.coating` · `EnemyInstance.paralyzed` | 신설 | 무기 도포 (독·마비·화염, 3 라운드) |
> | `BattleItemKind` | `coating` 추가 · `sp_tonic` | 바르는 병 · 마법 지수 회복 |
| `ItemUseDecision` / `ChooseItemUse` | 신설. 병을 고른 뒤 **바른다 / 던진다** | 묻는 것과 하는 것이 같아야 한다 |
> | `BattleEvent` | `WeaponCoated` · `CoatingExpired` · `EnemyStunned` · `EnemyLostTurn` · `CoatingResisted` · `VialThrown` · `MemberSpRestored`. `EscapeAttempted.gap` | |

> **v1 에서 달라진 것** — 전부 B5 다.
>
> | 어디 | 무엇 | 왜 |
> |---|---|---|
> | `BattleSetup` | `initialGap` · `enemyRanks` · `partyCapacity` | 위치와 정원 |
> | `CombatantSnapshot` | `rank` · `weaponKey` · `weakTo` · `dodgesBack` · `preset` · `knownPresets` | 대열 · 사거리 · 상성 · 상시 지시 |
> | `BattleOutcome` | `recruits` 가 **실제 슬롯**을 싣는다 (v1 은 `slot: -1`) | 정원을 전투 중에 판정하려면 |
> | `BattleEvent` | 12종 추가 | 사거리 · 진형 · 밀림 |

전투는 RPG 를 모른다. 아래 네 타입이 두 세계가 주고받는 전부다.

| 방향 | 타입 | |
|---|---|---|
| RPG → 전투 | `BattleSetup` | 개시 입력 |
| view ↔ model | `BattleCommand` / `BattleEvent` | 명령과 사실 |
| 전투 → RPG | `BattleOutcome` | 정산 결과 |

---

## 1. `BattleSetup` — 개시 입력

| 항목 | 뜻 |
|---|---|
| `party: List<CombatantSnapshot>` | 참가하는 파티원. 빈 슬롯은 넣지 않는다 |
| `enemyKeys: List<String>` | 적 테이블 키. **중복이 정상**이다 (같은 적 여러 마리) |
| `seed: int` | 전투 전체가 뽑는 난수의 씨앗 |
| `mode: int` | cm2 `Battle::Start(mode)` 인자. **어떤 규칙도 읽지 않는다** |
| `consumables: Map<String,int>` | 전투 중 쓸 수 있는 물건의 **투영**. 가방 자체가 아니다 |
| `initialGap: int?` | 양측 간격 0~2. **null 이면 민첩·레벨 차에서 유도**한다 (기습 0 · 원거리 발견 2) |
| `enemyRanks: List<int>` | 적의 열. `enemyKeys` 와 평행하고, 짧으면 나머지는 종류에서 유도 |
| `partyCapacity: int` | RPG 파티 슬롯 수(기본 6). **빈 칸 = 정원 − 앉아 있는 사람** |

### `CombatantSnapshot`

**`slot` 이 두 세계를 잇는 유일한 키다** (0~5). 정산 결과가 같은 값으로 돌아온다.

파생값은 RPG 가 **이미 풀어서** 넘긴다 — 전투는 장비 슬롯도 아이템 표도 모른다.

| 항목 | 비고 |
|---|---|
| `name` | 빈 문자열이면 없는 슬롯 취급 |
| `strength` `mentality` `concentration` `endurance` `resistance` `agility` `luck` | 능력치 |
| `ac` | 방어 총합. `armour` 가 비어 있을 때만 쓰인다 |
| `armour: ArmourPieces` | 부위별 분해 + 방패 블록 %. 비어 있으면 `ac` 로 대체 |
| `hp` `maxHp` `sp` `maxSp` `esp` `maxEsp` | |
| `accuracyPhysical` `accuracyMagic` `accuracyEsp` | |
| `levelPhysical` `levelMagic` `levelEsp` | **전투 중 변하지 않는다** |
| `powOfWeapon` | 무기 공격력 (맨손 1). **RPG 가 얼마나 센지를 정한다** |
| `weaponKey` | 전투 무기 표의 키. **전투가 어떻게 닿는지를 정한다** — 모르는 키는 맨손 |
| `weaponName` | 표시용. 어떤 규칙도 읽지 않는다 |
| `rank` | 열 1(앞)~3(뒤). 안 주면 슬롯에서 유도 (0-1 앞 · 2-3 중 · 4-5 뒤) |
| `weakTo: Set<Element>` | 이 사람이 유독 약한 속성. 보통은 비어 있다 |
| `dodgesBack: bool` | 치명타를 맞으면 물러나 피하는 passive |
| `preset` `knownPresets` | 상시 지시와 배운 목록. **편집기는 없고 선택만 있다** |
| `poison` `unconscious` `dead` | 개시 시점의 상태. `unconscious` 는 **누적값** |

`experience` 는 **없다.** 레벨은 입력이고 경험치는 출력이다.

### 무기는 두 세계가 나눠 갖는다

**RPG 는 `powOfWeapon`(얼마나 센지), 전투는 `weaponKey`(어떻게 닿는지).**
그래서 전투를 조정할 때 아이템 데이터를 끌고 오지 않아도 되고, 적 테이블이 전투 안에
있는 것과 같은 이유다. 무기 표는 방식 1~2개를 담고, 각 방식이
(속성 · 사거리 하한~상한 · 위력 % · 돌격 가능)을 갖는다.

### 위치는 좌표가 아니다

```
거리 = gap + (내 rank - 1) + (상대 rank - 1)
```

정수 둘뿐이다. 그래서 격자 게임이 되지 않는다.
**포기한 것**: 측면 우회 · 한 열 안의 개별 위치 · 특정 적만 골라 밀어내기.

---

## 2. `BattleCommand` / `BattleEvent` — 진행 계약

model 은 `pendingDecision` 으로 물을 것을 내놓고, `applyCommand` 로 답을 받고,
`advance()` 로 한 걸음 나아간다. 물어보는 것 일곱 가지:

| 질문 | 답 |
|---|---|
| `ActionDecision` | `ChooseAction` — 최상위 여섯 줄 |
| `OrderDecision` | `ChooseAction` — 리더의 지시 (자동 전투 · 전진 · 후퇴) |
| `EnemyTargetDecision` | `ChooseEnemyTarget` |
| `SpellDecision` | `ChooseSpell` — **한 목록**. 항목은 `SkillOption` |
| `ItemDecision` | `ChooseItem` |
| `ItemUseDecision` | `ChooseItemUse` — 병을 무기에 바를지 적에게 던질지 |
| `AllyTargetDecision` | `ChooseAllyTarget` |

`CancelChoice` 는 어느 질문에나 답이 된다. **행동 메뉴에서 취소하면 그 턴을 쉰다.
하위 물음에서 취소하면 행동 메뉴로 돌아온다** — 턴을 잃지 않는다(B6-07). 같은 사람이
한 라운드에 8번 넘게 돌아오면 턴을 넘긴다(헤드리스 안전장치).

### 묻는 순서 — 리더, 그리고 앞열부터 (B6-07)

한 라운드에 **리더 → 1열 → 2열 → 3열**(같은 열은 슬롯 순)로 묻는다. 행동 **순서**(민첩
선제)는 이것과 무관하다. 적 대상 목록(`EnemyTargetDecision.enemyIndices`)은 가까운 열부터,
아군 대상 목록(`AllyTargetDecision.slots`)은 필요한 사람부터다. **후보가 하나면 묻지 않는다.**
단일 치료 마법(19~25)은 아이템처럼 대상을 묻는다.

### 최상위 메뉴는 여섯 줄이다 (B6-01)

```
attack · castSkill · useItem · [charge] · brace · [escape · orders]
```

대괄호는 조건부 — 돌격은 무기가, 도망·지시는 **리더**가. 리더는 의식 있는 사람 중
가장 낮은 슬롯이다.

### `SkillOption` 이 글자를 대신한다

model 은 emoji 도 한국어도 내지 않는다. `scope` 와 `resource` 를 열거값으로 내고,
view(`hd_battle_text`)가 글자를 붙인다 — 🎯 한 명 · 💥 전체 · ☠ 저주 · 💚 아군 ·
💞 일행 · 🌀 내 무기 · 🔮 초능력. **못 쓰는 것도 목록에 남는다**(`affordable: false`);
고르면 `NotEnoughSpellPoints` 로 거절한다.

**`BattleEvent` 는 문자열을 담지 않는다.** 행위자·대상·종류·수치만 넘기고 문장·조사·멈춤은
view 의 일이다. 그것이 콘솔 view 와 Flutter view 가 이 패키지를 그대로 공유하는 이유다.

---

## 3. `BattleOutcome` — 정산 결과

전투가 자기 밖에 남기는 전부다. RPG 는 이것을 **한 곳에서** 반영한다.

| 항목 | 뜻 |
|---|---|
| `resultCode` | `none -1` · `evade 0` · `win 1` · `lose 2` — **`assets/const.cm2:53-55` 와의 계약** |
| `combatants: List<CombatantResult>` | 슬롯별 `hp` `sp` `esp` `poison` `unconscious` `dead` `experienceGained` |
| `goldGained` | 승리에서만 0 이 아니다 |
| `consumedItems: Map<String,int>` | 쓴 물건. **가방은 RPG 가 줄인다** |
| `worldEffects: List<String>` | 전투 밖 효과 요청. 지금은 항상 비어 있다 → B3-04 |
| `recruits: List<CombatantSnapshot>` | 전투가 **더한** 파티원 (독심). **실제 앉은 슬롯**을 싣는다 (v1 은 -1 이었다) |
| `departedSlots: List<int>` | 전투가 **잃은** 슬롯 (탈취). 죽음이 아니라 **부재**다 |

### 경험치는 슬롯별이다

원작이 두 가지로 나눠 준다 — 붕괴시킨 사람에게 처치 보너스, 승리 정산은 의식 있는 전원에게 전액.
합치면 그 분배를 재현할 수 없다.

### 소환된 적은 계산에 들어가지 않는다

초자연 시전이 부른 적(B2-11)은 경험치도 골드도 주지 않는다. 매 턴 소환하는 적이
무한히 지불하게 되기 때문이다.

---

## 4. RPG 가 해야 하는 일 (B3 의 목록)

1. `BattleSetup` 을 조립한다 — 파생값(`ac`/`armour`/`powOfWeapon`/`weaponName`)을 풀어서 넣고,
   **아이템을 `weaponKey` 로 대응시키고 대열(`rank`)과 정원(`partyCapacity`)을 넘긴다**
2. `resultCode.wire` 를 cm2 `Battle::Result()` 로 노출한다
3. 슬롯별 상태를 되쓴다
4. **경험치를 적용하고 레벨업을 판정한다** — 전투는 판정하지 않는다
5. 골드를 더하고 `consumedItems` 를 가방에서 뺀다
6. `worldEffects` 를 해석한다 (B3-04)
7. `recruits` 를 그 슬롯에 그대로 앉히고 `departedSlots` 를 비운다
8. **전투 밖 대열 화면** — 누가 앞에 설지는 전투가 아니라 RPG 가 정한다 (B4)

---

## 5. 규격 밖의 불변조건

확장 항목이 바뀌어도 이 다섯은 바뀌지 않는다. `test/flow/purity_test.dart` 와 CI 가 지킨다.

- `packages/hd_battle` 의 Flutter 의존 **0** (`foundation.dart` 포함)
- 시드 없는 `Random()` **0**
- 코드에 한국어 **0** (주석은 예외 — 표시 텍스트가 아니다)
- 경험치 표 **0** — 레벨업은 RPG 가 판정한다
- `cm2_script` 의존 **0** — preset 은 전투가 읽는 데이터이고, cm2 는 RPG 쪽에서 그 값을
  주고 고치는 데만 쓴다
- 코드에 emoji **0** (B6) — 범위는 `SkillScope` 열거값이고 글자는 view 의 일이다

그리고 **재현성**: 같은 개시 입력 + 같은 명령 열 + 같은 시드 → 같은 정산 결과.
`hd_battle_console/fixtures/` 23개가 그것을 매번 확인한다.

### B5 가 더한 불변식 — **헛턴이 없다**

> **사거리 밖은 벌점이지 무효가 아니다.**

위치를 움직이는 것이 넷이고(대열 명령 · 돌격 · 넉백 · 회피 후퇴) 그중 둘은 명령을 낼 때
예측할 수 없다. 그래서 사거리 밖이 공격을 무효로 만들면 판이 흔들릴 때마다 턴이
사라진다 — DQ1 이 "고른 대상이 이미 죽었다" 로 실패한 것과 같은 방식이다.

이 불변식은 세 곳에서 지켜진다:

1. **규칙** — 사거리 밖은 명중이 깎이고 가까운 쪽이 대신 맞을 뿐이고,
   **가로채기 확률이 100% 가 되지 않는다**
2. **무기 표** — 모든 무기가 모든 거리에서 무언가는 할 수 있다 (긴 무기의 자루)
3. **메뉴** — 못 할 것은 내놓지 않는다 (돌격·대열 이동·정원이 찼을 때의 독심술)

---

## 6. 버전

`v3` — 2026-09-06 확정. 규격을 바꾸는 변경은 새 버전과 새 판정이 필요하다.

| | |
|---|---|
| v1 | B2-99, 2026-09-05. 전투 확장까지 |
| v2 | B5-99, 2026-09-05. **위치 · 무기 사거리 · 물리 속성 · preset · 정원** |
| **v3** | B6-99, 2026-09-06. **메뉴 6줄 · 기술 목록 하나 · 리더 · 파티 도망 · 무기 도포** |

바뀔 것으로 이미 아는 것:
- `worldEffects` 의 내용 형식 — 지금은 문자열이고 **모델에서 채우는 코드가 없다**. B3-04 가 존폐를 정한다
- **적별 덮어쓰기** — `Enemy::ChangeAttribute` 23곳이 기다린다(B3-01). 별개 판정
- **공격 방식 선택** — 지금은 거리에 맞는 것이 자동으로 뽑힌다. 메뉴를
  베기/찌르기/타격으로 가르면 `BattleCommand` 에 항목이 하나 는다
- **아군 소환 마법** — 자리를 만드는 기제(`partyCapacity`)는 들어갔고 마법이 아직 없다
