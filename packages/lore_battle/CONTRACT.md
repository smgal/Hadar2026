# 모드 인계 규격 `lore-1`

`packages/hd_battle` 의 규격 **v4** 를 갈라 온 것이다(2026-11-11 결정: 「로어는 포크한다. 1·2·3부의
적 데이터는 번호가 다 다르므로 편마다 따로 둔다」). **뼈대는 hd_battle, 규칙의 내용은 로어 3부작의
제3부 시스템**이다. 정본은 기획서(`LORE_TRILOGY/GameDesign/` 제7·8·9·12장, 부록 A·E, `1st/` · `2nd/`
의 07·08장)이고, 아래 「장」 표기는 그 문서의 장 번호다.

전투는 RPG 를 모른다. 아래 네 타입이 두 세계가 주고받는 전부다.

| 방향 | 타입 | |
|---|---|---|
| RPG → 전투 | `BattleSetup` | 개시 입력 |
| view ↔ model | `BattleCommand` / `BattleEvent` | 명령과 사실 |
| 전투 → RPG | `BattleOutcome` | 정산 결과 |

---

## 0. hd_battle v4 에서 달라진 것

### 그대로 둔 것 (뼈대)

- 순수 Dart · Flutter 0 · 코드에 한국어/emoji 0 · 시드 있는 난수 하나 · 같은 입력이면 같은 결과
- `pendingDecision` / `applyCommand` / `advance()` 로 굴리는 상태 기계, 문자열 없는 `BattleEvent`
- 위치 = 각자의 `rank`(1~3) + 양측 공통 `gap`(0~2). `거리 = gap + (내 rank-1) + (상대 rank-1)`
- **사거리 밖은 벌점이지 무효가 아니다** — 무기 표(`weaponKey`), 가로채기, 대열 명령, 돌격, 버팀, 밀려남
- 한 라운드: 전원에게 먼저 묻고(리더 → 1열 → 2열 → 3열) 민첩 선제 순으로 해결
- 최상위 메뉴 여섯 줄, 기술 목록 하나(`SkillScope` · `SkillResource`), 하위 물음의 취소는 한 단계 위로,
  후보가 하나면 묻지 않는다
- 상시 지시(preset)와 자동 전투

### 바꾼 것 (내용)

| 어디 | hd_battle v4 | lore-1 |
|---|---|---|
| 인물 | 레벨 셋 · 정확성 셋 · SP/ESP 두 통 | **레벨 하나 · 정확성 하나 · 기술치 여섯 · MP 한 통** (7장) |
| 6번 자리 | 여느 파티원 | **보조 일원** — 명령을 묻지 않고 스스로 공격한다 (8.5) |
| 명중·피해 | 스침 배율(graze) · 면역 판정 | 8.5 · 8.6 의 식 그대로 (명중 굴림 → 편차 → 저항 % → 방어 감소 → 방패) |
| 기술 id | 1~45 | **`분류 × 100 + 단계`** (§4) |
| 마법 | 6종씩 × 레벨 구간 | 공격 10+10단계, 특수 10, 치료 10, 초능력 6, **소환 10** (9장) |
| 물건 | 치료약·병·결정 | 약초·약물 5종 + 크리스탈 7종 (§5). **무기 도포는 없앴다** |
| 화살 | 없음 | 쏘는 무기는 공격마다 1개 (`BattleSetup.arrows` → `BattleOutcome.arrowsUsed`) |
| 적 표 | 75행 하나, 이름(영문)을 model 이 가짐 | **편마다 하나** 75 · 75 · 74행. 이름은 `lore_battle_text` 에만 |
| 적별 덮어쓰기 | 없음 | `BattleSetup.enemyOverrides` + 이름 붙은 변형(`enemyVariantsFor`) |
| 전투 플래그 | 없음 | `canEscape` · `enemyActsFirst` · `attackUnconscious` |
| 경험치 | 처치 `레벨×10` + 승리 정산(표 번호³÷8) | 의식불명으로 만든 사람에게 `레벨³`, 마무리하면 행동 가능한 전원에게 다시 `레벨³`. **승리 정산 없음** |
| 금화 | `레벨×5` 합 | `레벨³ × max(방어,1)` 합 |
| 적의 쓰러짐 | 누적값을 넘어야 죽는다 | 의식불명 → 한 번 더 맞으면 죽음 (8.5 2단계) |
| 대원의 쓰러짐 | 죽으면 변화 없음 | 죽은 뒤 받은 피해도 죽음 수치에 쌓인다 (부활 비용이 그것으로 정해진다) |
| 정산 | `recruits` · `worldEffects` | `newAssistant` · `acLoss` · `arrowsUsed` · `enemies` |

### 없앤 것

`levelPhysical/Magic/Esp` · `accuracyPhysical/Magic/Esp` · `sp/esp` · `ArmourPieces` · `strikes` ·
`coatingSlots` · `evasionBonus` · `initiativeBonus` · `partyCapacity` · `recruits` · `worldEffects` ·
스침 배율과 면역 판정(`grazeScale` · `evasionOf` · `immunityFor` · `physicalPowerScale`) · 무기 도포 전부
(`Coating` · 병 3종 · `ItemUseDecision` · `ChooseItemUse` · 이벤트 6종) · 염력 굴림표 · 겁쟁이 preset 과
적의 자발적 도주 · `victoryExperience` · `rules/magic.dart`.

---

## 1. `BattleSetup` — 개시 입력

```dart
const BattleSetup({
  required List<CombatantSnapshot> party,
  required List<String> enemyKeys,
  required int seed,
  int episode = 3,
  int mode = 0,
  Map<String, int> consumables = const {},
  int arrows = 0,
  int? initialGap,
  List<int> enemyRanks = const [],
  Map<int, EnemyOverride> enemyOverrides = const {},
  bool canEscape = true,
  bool enemyActsFirst = false,
  bool attackUnconscious = true,
})
```

| 항목 | 뜻 |
|---|---|
| `party` | 참가하는 일행. 빈 자리는 넣지 않는다. 자리 5 가 있으면 보조 일원이다 |
| `enemyKeys` | **그 편의** 적 표 키. 중복이 정상이다. 변형 키(§3)도 된다 |
| `seed` | 전투 전체가 뽑는 난수의 씨앗 |
| `episode` | 1 · 2 · 3. **적 표를 고른다.** 한 편에만 있는 규칙도 이것으로 갈린다(제1부의 「독」, 적 HP 배율, 적의 독 피해) |
| `mode` | 스크립트의 `Battle::Start(mode)` 인자. 어떤 규칙도 읽지 않는다 |
| `consumables` | 전투 중 쓸 수 있는 물건의 **투영** (`key → 개수`, §5). 가방 자체가 아니다 |
| `arrows` | 일행 공용 화살 |
| `initialGap` | 양측 간격 0~2. null 이면 `enemyActsFirst` 일 때 0, 아니면 민첩·레벨 차에서 유도 |
| `enemyRanks` | 적의 열. `enemyKeys` 와 평행하고, 짧으면 나머지는 종류에서 유도 |
| `enemyOverrides` | 적별 덮어쓰기. 키는 **`enemyKeys` 의 인덱스** (§3) |
| `canEscape` | false 면 도망 줄이 메뉴에 아예 나오지 않는다 (8.1 의 도주 불가 전투) |
| `enemyActsFirst` | 적 선공 — 첫 라운드에 일행 차례가 없다 (8.3) |
| `attackUnconscious` | 옵션 「의식 불명인 적까지 공격」(8.10). 켜면 의식불명인 적이 대상이 되고 치면 마무리, 끄면 건너뛴다 |

### `CombatantSnapshot` — 제3부 인물

```dart
const CombatantSnapshot({
  required int slot,
  required String name,
  String nameKey = '',
  Family family = Family.fighter,
  int classId = ClassId.fighter,      // 1
  int level = 1,
  int strength = 0, int mentality = 0, int concentration = 0, int endurance = 0,
  int resistance = 0, int agility = 0, int accuracy = 0, int luck = 0,
  List<int> skills = const [0, 0, 0, 0, 0, 0],
  required int hp, required int maxHp,
  int mp = 0, int maxMp = 0,
  int ac = 0,
  int weaponPower = 5,
  WeaponKind weaponKind = WeaponKind.bare,
  int shieldPower = 0,
  int poison = 0, int unconscious = 0, int dead = 0,
  int? rank,
  String weaponKey = 'unarmed',
  String weaponName = '',
  String weaponNameKey = '',
  bool? attacksAll,
  bool immuneToMindControl = false,
  Set<Element> weakTo = const {},
  bool dodgesBack = false,
  PresetKind preset = PresetKind.aggressive,
  Set<PresetKind> knownPresets = const {},
})
```

**`slot` 이 두 세계를 잇는 유일한 키다**(0~5). 0 주인공, 1~4 동료, **5 보조 일원**.
파생값은 RPG 가 **이미 풀어서** 넘긴다 — 전투는 장비도 아이템 표도 모른다.

| 항목 | 비고 |
|---|---|
| `name` | 표시용. 어떤 규칙도 읽지 않는다. `nameKey` 가 있으면 비어 있어도 된다 |
| `nameKey` | 전투가 **스스로 만든** 보조 일원의 이름 키 (`summon.ifrit` · `enemy.3.orc_soldier`). model 은 한국어를 갖지 않으므로 키를 싣고, `lore_battle_text` 의 `memberDisplayName` 이 푼다 |
| `family` | `fighter` · `mage` · `elemental` · `giant` · `golem` · `dragon` · `unknown` |
| `classId` | **계열마다 따로 센다.** 전투사 1~7: 투사·기사·검사·사냥꾼·전투승·암살자·전사 / 마법사 1~7: 메이지·컨져러·주술사·위저드·강령술사·대마법사·타임워커 / 제1부 전용 8 에스퍼 · 9 반신반인 |
| `level` | 하나 |
| 능력치 8 | `strength` 체력 · `mentality` 정신력 · `concentration` 집중력 · `endurance` 인내력 · `resistance` 저항력 · `agility` 민첩성 · `accuracy` 정확성 · `luck` 행운 |
| `skills` | 기술치 여섯(0~100). 전투사: 베는·찍는·찌르는·쏘는·방패·맨손 / 마법사: 공격·변화·치료·특수·초자연·소환. **전사(7)는 둘째 칸이 치료 능력치다** |
| `hp` `maxHp` `mp` `maxMp` | MP 는 한 통 — 마법과 초능력이 같이 쓴다. `maxMp` 는 RPG 가 계열 공식으로 푼 값(마법사 정신×레벨×10, 전사 ×5) |
| `ac` | 방어력 = 기본 방어 + 갑옷. 전투 중 갑옷 파괴로 내려갈 수 있다 |
| `weaponPower` | 무기 공격력(맨손 5). **계급에 따라 다른 값**(10.2)을 RPG 가 풀어 넣는다. 보조 일원은 고유 무기의 공격력 |
| `weaponKind` | 어느 기술치로 재는가 — `bare` · `slash` · `chop` · `pierce` · `shoot` · `special`(보조 일원의 고유 무기, 기술치 대신 레벨×5) |
| `shieldPower` | 방패 번호 1~5, 없거나 못 쓰면 0. 전투사 계열만 막는다 |
| `poison` `unconscious` `dead` | 개시 시점의 상태. **누적 수치**다 (7.7) |
| `rank` | 열 1(앞)~3(뒤). 안 주면 자리에서 유도 (0-1 앞 · 2-3 중 · 4-5 뒤) |
| `weaponKey` | 전투 무기 표의 키 — **어떻게 닿는지**. 모르는 키는 맨손. §6 |
| `weaponName` | 표시용. **풀어 놓은 이름**을 넣는다 — 메뉴가 「공격 — 한 명의 적을 {이것}으로」 로 읽는다 |
| `weaponNameKey` | 전투가 만든 보조 일원의 무기 이름 키 (`natural.flame` · `breath.frost`) |
| `attacksAll` | 보조 일원의 자동 공격이 적 전원을 훑는가 (8.5). 안 주면 계열에서 유도(마법사·고렘·정령 = 전체). **불의 정령은 정령인데 단일**이라 필드로 둔다 |
| `immuneToMindControl` | 크리스탈 소환수·대천사장 — 적의 정신 지배에 면역 |
| `weakTo` `dodgesBack` `preset` `knownPresets` | hd_battle 의 위치 층 그대로. 보통은 기본값이면 된다 |

`experience` 는 **없다.** 레벨은 입력이고 경험치는 출력이다. 제3부는 경험치가 곧 레벨도 아니다(7.6).

편의 getter: `isAssistant` · `isPaladin` · `isCaster` · `usesFixedCoefficient` · `holdsMagic` ·
`weaponSkill` · `attackSkill` · `cureSkill` · `specialSkill` · `espSkill` · `summonSkill` · `shieldSkill`.

---

## 2. `BattleCommand` / `BattleEvent` — 진행 계약

model 은 `pendingDecision` 으로 물을 것을 내놓고, `applyCommand` 로 답을 받고, `advance()` 로 한 걸음
나아간다. 물어보는 것 여섯 가지:

| 질문 | 답 |
|---|---|
| `ActionDecision` | `ChooseAction` — 최상위 여섯 줄 |
| `OrderDecision` | `ChooseAction` — 리더의 지시 (자동 전투 · 전진 · 후퇴) |
| `EnemyTargetDecision` | `ChooseEnemyTarget` |
| `SpellDecision` | `ChooseSpell` — **한 목록**. 항목은 `SkillOption` |
| `ItemDecision` | `ChooseItem` |
| `AllyTargetDecision` | `ChooseAllyTarget` |

`CancelChoice` 는 어느 질문에나 답이 된다. 행동 메뉴에서 취소하면 그 턴을 쉰다(「잠시 주저했다」).
하위 물음에서 취소하면 행동 메뉴로 돌아온다. 같은 사람이 한 라운드에 8번 넘게 돌아오면 턴을 넘긴다.

```
attack · castSkill · useItem · [charge] · brace · [escape · orders]
```

- **6번 자리(보조 일원)에게는 아무것도 묻지 않는다.** 선제 순서 안에서 스스로 공격한다
- 리더 = 자리 0~4 가운데 행동 가능한 가장 낮은 자리. `escape` 는 `canEscape` 일 때만
- 전투사 계열(전사 제외)은 기술 목록이 비어 `castSkill` 줄이 없다. 전사는 치료만
- 적 대상 목록은 가까운 열부터. `attackUnconscious` 가 켜져 있으면 의식불명인 적이 그 뒤에 붙는다
  (특수 마법·초능력·영혼의 크리스탈은 서 있는 적만)
- `enemyActsFirst` 면 1라운드는 묻지 않고 적만 움직인다

### `SkillOption`

`magicId` · `category`(`SkillCategory`) · `tier` · `scope`(`SkillScope`) · `resource`(`SkillResource`) ·
`cost` · `perTarget` · `affordable`.

- `SkillScope` = `oneEnemy` · `allEnemies` · `curse` · `curseAll` · `oneAlly` · `allAllies` · `summon`
- `SkillResource` = `mp` · `esp`. **통은 하나다** — 둘 다 `mp` 에서 나간다. `esp` 는 「초능력」이라는
  갈래 표시로만 남았다
- `cost` 가 -1 이면 대상에 따라 달라진다(의식 돌림·부활). `perTarget` 이면 대상마다 낸다(전체 공격 마법 등)
- 못 쓰는 것도 목록에 남는다(`affordable: false`). 고르면 `NotEnoughSpellPoints` 로 거절하고 메뉴로 돌아온다

### `BattleEvent`

**문자열을 담지 않는다.** 80종이고 `lore_battle_text` 의 `battleLines` 가 전부를 문장으로 바꾼다.
적 인덱스는 전투 내내 고정이다 — 죽은 적도 줄을 남긴다(부록 E.2).

`EnemyClonesShifted` 는 분신 무리의 인덱스만 싣고 **어느 것이 진짜인지 말하지 않는다.** 다만 그 뒤에
오는 적 행동 이벤트의 `enemyIndex` 는 진짜의 것이므로, 행동한 줄을 강조하는 view 는 스스로 가려야 한다.

---

## 3. 적 — 편마다 표 하나

```dart
enemyTableEp1 / enemyTableEp2 / enemyTableEp3     // const List<EnemyData>, 75 / 75 / 74행
enemyTableFor(episode) · enemyByKey(episode, key) · enemyByLegacyId(episode, 번호)
enemyVariantsEp1 / Ep2 / Ep3 · enemyVariantsFor(episode) · resolveEnemy(episode, key)
```

- `key` 는 snake_case 이고 **그 편 안에서만** 유일하다. `legacyId` 는 원작 번호로 **기획서와 같이 1부터**다
- 이름은 model 에 없다 — `lore_battle_text` 의 `enemyName(episode, key)`

| 편 | 키의 모양 | 예 (번호) |
|---|---|---|
| 1 | 원작 영문 이름 | `orc`(1) · `serpent`(3) · `sprite`(35) · `death_knight`(63) · `neo_necromancer`(75) |
| 2 | 원작 한글 이름을 옮긴 것 | `orc`(1) · `great_snake`(3) · `fairy`(35) · `lizard_man`(59) · `mephistopheles`(75) |
| 3 | 원작 한글 이름을 옮긴 것 | `death_messenger`(1) · `orc_soldier`(19) · `kobold_king`(45) · `draconian_king`(59) · `lord_ahn`(73) |

`EnemyData` 의 필드: `key` · `legacyId` · `level` · `hp` · `strength` · `mentality` · `endurance` ·
`physicalResistance` · `magicResistance` · `agility` · `accuracyPhysical` · `accuracyMagic` · `ac` ·
`special`(`EnemySpecial`: none 0 · poison 1 · knockOut 2 · slay 3) · `castLevel`(0~6) ·
`abilities`(`Set<EnemyAbility>`, 제3부) · `superLevel`(초자연 등급 0~3, 제1·2부) · `persuadable` ·
`persuadeLevel` · `givesGold` · `endsTurnAfterHealAll` · `agedByCrystals`.

- HP = 인내 × 레벨 × **10**(제2·3부) 또는 × **1**(제1부) — 각 편 문서의 값 그대로이고 시험이 식과 맞춘다
- 제1·2부는 저항이 한 열이라 `physicalResistance` 와 `magicResistance` 에 같은 값이 들어 있다

### `EnemyOverride` — 적별 덮어쓰기

```dart
const EnemyOverride({
  String? nameKey, String? displayName,
  int? level, int? hp,
  int? strength, int? mentality, int? endurance,
  int? physicalResistance, int? magicResistance,
  int? agility, int? accuracyPhysical, int? accuracyMagic, int? ac,
  EnemySpecial? special, int? castLevel,
  Set<EnemyAbility>? abilities, int? superLevel,
  bool? persuadable, int? persuadeLevel,
  int? rewardLevel, int? rewardAc, bool? givesGold,
  int? poison, int? unconscious, int? dead,
})
```

전부 선택이고 null 은 「표대로」다. `mergedWith(other)` 로 겹친다(뒤가 이긴다).

- **`hp` 를 안 주면 레벨을 따른다** — `level` 이나 `endurance` 를 바꾸면 그 편의 식으로 다시 계산하고,
  둘 다 안 바꾸면 표의 값을 쓴다. 식이 주지 않을 값을 박으려면 `hp` 를 준다(「트롤매직유저」는 레벨만
  올리고 HP 360 을 그대로 쓴다)
- `abilities` 는 **통째로 바꾼다**
- `rewardLevel` · `rewardAc` 는 경험치·금화를 다른 수치로 줄 때(제1·2부의 「경험치·금 기준 N번」)
- `poison` · `unconscious` · `dead` 는 **이어 싸우는 전투**용 — `BattleOutcome.enemies[i].resume` 을
  그대로 넣으면 앞 전투의 피해가 남는다(12.4 반복 전투)

스크립트의 `Enemy::ChangeAttribute` 속성 이름과의 대응:

| 속성 | 필드 | 비고 |
|---|---|---|
| `name` | `displayName` | 글자 그대로의 이름. 이름표의 별칭을 쓰려면 `nameKey` |
| `level` | `level` | HP 가 따라 바뀐다(위) |
| `strength` · `mentality` · `endurance` | 같은 이름 | `endurance` 도 HP 를 다시 계산한다 |
| `resistance` | `physicalResistance` | 제1·2부는 저항이 하나였다 — 그 편의 스크립트는 `magicResistance` 도 같이 넣는다 |
| `magic_resistance` | `magicResistance` | |
| `agility` | `agility` | |
| `accuracy` | `accuracyPhysical` | |
| `magic_accuracy` | `accuracyMagic` | |
| `ac` | `ac` | |
| `special` | `special` | 숫자면 `EnemySpecial.fromWire(n)` — 0 없음 · 1 독 · 2 치명(기절) · 3 죽음, 그 밖은 없음 |
| `cast_level` | `castLevel` | 0~6 |

### 변형 (`enemyVariantsFor`)

원작은 다른 칸의 적을 불러와 이름·수치 몇 개를 바꿔 보스로 쓴다. 기획서가 「각각 별도의 적으로
만든다」고 한 것들을 **키 하나로** 부를 수 있게 해 둔 것이다. `enemyKeys` 에 그대로 쓴다.

- 제3부: `draconian_believer` · `troll_magic_user_lv5` · `troll_magic_user_lv6` · `dracon_emperor_17` ·
  `dracon_guardian_spirit` · `death_messenger_lv30` · `cerberus_lv15`
- 제1부: `major_mummy` · `sphinx` · `camp_soldier` · `zombie` · `archi_gagoyle` · `hydra_head` ·
  `hydra_head_2` · `huge_dragon` · `dragon_tail` · `crab_god_soldier` · `fake_necromancer`
- 제2부: `soldier` · `guard` · `bank_guard` · `devil_hunter_boss` · `wisp_eighth` · `giant_cyclops` ·
  `revived_lizard_man` · `last_guardian` · `sirian_caminus` · `sirian_caminus_split`

일행의 분신(제1·2부)처럼 전투마다 수치가 달라지는 적은 변형이 아니라 `enemyOverrides` 로 만든다.

---

## 4. 기술 id — `분류 × 100 + 단계`

| id | 분류 (`SkillCategory`) | 열리는 조건 | MP |
|---|---|---|---|
| 101~110 | `attackOne` 한 명 공격 | 공격 마법 능력치 ÷ 10 | `A × j² ÷ 10` (반올림) |
| 201~210 | `attackAll` 전체 공격 | 〃 | 〃, **적마다** |
| 300 | `special` 「독」 | **제1부만**, 특수 마법 10 이상 | 10 |
| 301~305 | `special` 한 명 | 특수 마법 능력치 ÷ 10 | 200 · 50 · 100 · 150 · 400 |
| 306~310 | `special` 모두 | 〃 | 같은 값, 적마다 |
| 401~405 | `cure` 한 명 | 치료 능력치 ÷ 10 (전사는 둘째 기술치) | 레벨×2 · 15 · 10×의식불명 수치 · 30×죽음 수치 · 합 |
| 406~410 | `cure` 모두 | 60 이상 | 같은 값, 대상마다 |
| 501 | `esp` 독심 | 초자연력 40 | 15 |
| 502 | `esp` 수소 핵융합 | 20 | 100 |
| 503 | `esp` 공포 생성 | 30 | 100 |
| 504 | `esp` 환상 생성 | 80 | 300 |
| 505 | `esp` 신진 대사 조절 | 90 | 500 |
| 506 | `esp` 유체 이탈 | 100 | 1000 |
| 601~610 | `summon` 소환 | 소환 마법 능력치 ÷ 10 | `S × j² ÷ 10` (반올림) — **미결 1** |

`skillId(category, tier)` · `categoryOfSkill(id)` · `tierOfSkill(id)` · `castableSkills(member, episode:)` ·
`skillOptions(member, mp:, episode:)`. 투시·예언·천리안은 전투에서 「쓸 수 없다」고만 하는 능력이라
목록에 없다(헛턴이 메뉴로 도달하면 안 된다).

마법사 계열(`family == mage`)과 제1부 전용 계급(8 · 9)만 마법사의 기술치 배열을 읽는다.

소환(601~610)과 소환의 크리스탈, 독심(501)은 **6번 자리를 채운다** — 있던 보조 일원은 덮어쓴다(7.8).
같은 라운드에 보조 일원이 아직 움직이지 않았으면 새로 온 쪽이 그 라운드에 한 번 공격한다.

---

## 5. 소모품 키

| 키 | | 대상 | 효과 |
|---|---|---|---|
| `item.hp_potion` | 체력 회복약 | 쓰는 사람 | HP +1000 |
| `item.mp_potion` | 마법 회복약 | 쓰는 사람 | MP +1000. **마법사 계열·전사만** — 다른 사람의 목록에는 없다 |
| `item.antidote_herb` | 해독의 약초 | 쓰는 사람 | 중독 해제 |
| `item.awakening_herb` | 의식의 약초 | 고른 대원 | 의식 회복 (HP 최소 1) |
| `item.revival_herb` | 부활의 약초 | 고른 대원 | 부활 — 의식불명 상태로. 죽음 수치 10000 미만일 때 |
| `crystal.flame` | 화염의 크리스탈 | 적 1 | 32,500 고정. 명중 판정 없음, 마법 저항·방어 감소는 적용 |
| `crystal.frost` | 한파의 크리스탈 | 적 전체 | 각 20,000 고정 |
| `crystal.dark` + `crystal.ebony` | 다크 + 에보니 | 로드안 | **둘 다 있어야** 한다. 로드안(`agedByCrystals`)의 능력치·저항·명중·방어·레벨을 절반으로. 반응하지 않으면 소모하지 않는다 |
| `crystal.spirit` | 영혼의 크리스탈 | 적 1 | 남은 HP 를 절반으로 |
| `crystal.summon` | 소환의 크리스탈 | 6번 자리 | 크리스탈 드래곤(1/3) · 크리스탈 고렘(2/3), 레벨 30, 정신 지배 면역 |
| `crystal.energy` | 에너지 크리스탈 | 일행 전원 | 살아 있으면 의식 회복·HP 최대, 죽었으면 부활(HP 1) |

쓴 것은 `BattleOutcome.consumedItems` 에 `key → 개수` 로 돌아온다. **가방은 RPG 가 줄인다.**

---

## 6. 무기 표 (`weaponKey`)

**RPG 는 `weaponPower`(얼마나 센지)와 `weaponKind`(어느 기술치인지), 전투는 `weaponKey`(어떻게 닿는지).**
기획서에는 사거리가 없다 — 이 표는 hd_battle 의 위치 층이고, 다리(bridge)가 아이템을 키에 대응시킨다.
`defaultWeaponKeyFor(kind)` 가 계통만으로 고른 기본값을 준다.

| 제3부 무기 (10.2) | 권하는 키 |
|---|---|
| 맨손 | `unarmed` |
| 단검 · 그라디우스 · 샤벨 · 신월도 · 인월도 | `one_hand_slash` (방패를 들면 `sword_shield`) |
| 장검 / 프렘버그 | `long_sword` / `great_sword` |
| 곤봉 / 소형 도끼 / 프레일 · 철퇴 / 전투용 망치 | `club` / `axe` / `mace` / `war_hammer` |
| 양날 전투 도끼 / 핼버드 | `battle_axe` / `poleaxe` |
| 단도 / 레이피어 / 단창 / 삼지창 | `dagger` / `rapier` / `spear` / `trident` |
| 기병창 · 랜서 / 도끼창 | `lance` / `halberd` |
| 블로우 파이프 / 표창 · 투창 / 투석기 | `blowpipe` / `thrown` / `sling` |
| 활 / 석궁 / 아르발레스트 | `bow` / `crossbow` / `arbalest` |
| 보조 일원의 고유 무기 | `natural_slash` · `natural_pierce` · `natural_blunt`(0~2) · `natural_hurl` · `natural_fire` · `natural_ice` · `natural_lightning` · `natural_force` · `natural_poison`(0~4) |

---

## 7. `BattleOutcome` — 정산 결과

```dart
const BattleOutcome({
  required BattleResultCode resultCode,
  required List<CombatantResult> combatants,
  required int goldGained,
  Map<String, int> consumedItems = const {},
  int arrowsUsed = 0,
  CombatantSnapshot? newAssistant,
  List<int> departedSlots = const [],
  List<EnemyState> enemies = const [],
})

const CombatantResult({
  required int slot, required int hp, required int mp,
  required int poison, required int unconscious, required int dead,
  required int experienceGained,
  int acLoss = 0,
})

const EnemyState({
  required String key, required int hp, required int unconscious, required int dead,
  required bool left, required EnemyOverride resume,
})   // + bool get isDown
```

| 항목 | 뜻 |
|---|---|
| `resultCode` | `none -1` · `evade 0` · `win 1` · `lose 2` — wire 값은 hd_battle 과 같다 |
| `combatants` | **전투가 끝났을 때 차 있는 자리**마다 하나. `hp` `mp` `poison` `unconscious` `dead` `experienceGained` `acLoss` |
| `acLoss` | 갑옷 파괴로 잃은 방어력. **영구** — RPG 가 그만큼 내린다 |
| `goldGained` | 승리에서만 0 이 아니다. 쓰러뜨린 적마다 `레벨³ × max(방어,1)` |
| `consumedItems` | 쓴 약초·약물·크리스탈 |
| `arrowsUsed` | 쏜 화살 |
| `newAssistant` | 6번 자리에 **처음과 다른 이**가 앉아 있으면 그 전체 수치(소환수·크리스탈 소환수·설득된 적). HP·상태는 전투가 끝난 때의 값이고 `combatants` 의 자리 5 와 같다. 보조 일원은 전투 뒤에도 남는다(9.7) |
| `departedSlots` | 전투가 **비운** 자리 — 정신 지배가 보조 일원을 데려갔고 아무도 대신 오지 않았을 때 `[5]`. 죽음이 아니라 **부재**다 |
| `enemies` | 적 전원의 마지막 상태, 인덱스 순. 「이 적만 쓰러뜨려도 성공」 같은 사건 판정과 이어 싸우기(`resume`)에 쓴다 |

경험치는 **자리별**이다 — 의식불명으로 만든 사람 한 명에게, 마무리는 행동 가능한 전원에게.
레벨업은 전투가 판정하지 않는다.

---

## 8. RPG 가 해야 하는 일

1. `BattleSetup` 을 조립한다 — 파생값(`ac` · `weaponPower` · `maxMp` · `weaponName`)을 풀어 넣고, 아이템을
   `weaponKey` 로 대응시키고, 편(`episode`)과 전투 플래그를 넘긴다
2. `resultCode.wire` 를 스크립트에 노출한다
3. 자리별 상태를 되쓴다 (`hp` `mp` `poison` `unconscious` `dead`), `acLoss` 만큼 기본 방어를 내린다
4. 경험치를 더한다. 레벨업은 휴식 때의 일이다(7.6)
5. 금화를 더하고 `consumedItems` · `arrowsUsed` 를 가방에서 뺀다
6. `newAssistant` 가 있으면 6번 자리에 그대로 앉히고, `departedSlots` 의 자리를 비운다
7. 무작위 조우의 교전/도망 선택과 선공 판정(8.2)은 **전투 밖**이다 — 결과를 `enemyActsFirst` 로 넘긴다

---

## 9. 미결 — 고른 것과 그 이유

기획서가 정하지 않았거나 뼈대와 부딪혀서 **이 포크가 골라야 했던 것**들이다. 바꾸려면 여기부터 고친다.

| # | 무엇 | 고른 것 | 근거 · 다른 선택지 |
|---:|---|---|---|
| 1 | 소환 마법의 MP | `소환 능력치 × j² ÷ 10` (반올림) | 원작은 0. 부록 A D1 의 제안대로 공격 마법과 같은 곡선 |
| 2 | 적의 특수 공격 발동 조건 | 「행동 가능한 적 4명 이상」을 그대로 둔다 | 8.6 본문이 그렇게 적는다. 부록 A #19 는 의도 불명확이라 한다 — 보스 단독전에서는 특수 공격이 나오지 않는다 |
| 3 | 도망 | **리더의 파티 행동.** `rand(50) > 리더 민첩성 + 간격×15` 면 실패, 실패하면 전원이 그 라운드를 잃는다 | 원작은 2~5번이 각자, 주인공은 못 한다(부록 A D20 의 막힘도 같이 풀린다). 식은 8.4, 간격 보너스는 hd_battle |
| 4 | 치료·약초·일부 크리스탈의 「즉시 실행」 | 행동 단계에서 다른 행동과 같이 실행 | 뼈대가 「전원에게 묻고 → 해결」이다. 무엇을 하는지는 같고 언제 하는지만 다르다 |
| 5 | 행동 순서 | 민첩성 + rand(10) 선제. 보조 일원도 그 순서에 낀다 | 원작은 번호 순 → 보조 일원 → 적. 소환수는 민첩 0 이라 대개 맨 뒤다 |
| 6 | 일행의 중독 피해 시점 | 라운드의 모든 차례가 끝난 뒤 한 번 | 원작은 일행 행동 뒤·적 행동 전. 선제 순서에서는 그 자리가 없다 |
| 7 | 승패 판정 시점 | 차례마다 | 원작은 적의 차례가 끝난 뒤에만 (부록 E.9) |
| 8 | 화살이 떨어졌을 때 | 공격하지 못한다(`OutOfArrows`) | 8.4 그대로. **「헛턴 없음」의 유일한 예외**다. 화살은 쏘는 공격에만 든다(부록 A #35 의 의도) |
| 9 | 분신 | 쓸 때마다 가짜를 되살리고 적 목록을 8칸까지 채운 뒤 진짜와 자리를 바꾼다. 가짜는 경험치·금화가 없고, 가짜만 남으면 승리다 | 8.6 은 「8칸을 채우고 매 차례 진짜의 위치를 옮긴다」까지만 적는다. 가짜의 경험치는 문서에 없다 — 되살아나는 것에 경험치를 주면 끝없이 번다 |
| 10 | 동료 소환의 상한 | 적 목록이 8칸이면 부르지 않는다 | 원작 화면이 8줄이다 |
| 11 | 불려 나온 적의 보상 | 경험치·금화를 준다 | 8.8 의 제외 목록(설득·분신·저승사자·넘어간 보조 일원)에 없다. hd_battle 은 반대였다 |
| 12 | 공포로 달아난 적 | 금화를 준다(경험치는 시전자에게) | 9.6 은 「전투에서 제거, 경험치 지급」까지. 금화는 문서에 없다 |
| 13 | 마법사 계열의 맨손 공격 | 기술치 여섯째 칸을 그대로 읽는다 — 마법사에게는 **소환 능력치**다 | 8.5 는 「맨손 → 맨손 기술치」만 적는다. 0 으로 두는 것이 다른 선택지 |
| 14 | 제1부 전용 계급(에스퍼 8 · 반신반인 9) | 마법사의 기술치 배열을 읽는다 | `1st/07` 이 「원작 규칙 그대로, 대응 없음」이라고만 한다 |
| 15 | 제1부의 「독」 | id 300, MP 10, 저항 `rand(100) < 마법 저항`, 명중 `rand(40) > 정확성`. 특수 마법이 열리면 목록 맨 앞에 | 「원작대로」(`1st/07` 7.5)인데 제3부 수치가 없어 원작 값을 썼다 |
| 16 | 적의 중독 피해 | 제1부 1, 제2·3부 50 | 부록 E.11. 제1부 적은 HP 가 열 배 작다 |
| 17 | 다크 + 에보니 | 반응하지 않으면 소모하지 않는다. HP 는 그대로 두고 수치만 절반. 73 · 74 둘 다 대상 | 9.8 은 「로드안이 아니면 반응하지 않는다」 |
| 18 | 영혼의 크리스탈 | 남은 HP 의 절반, 1 아래로는 내리지 않는다 | |
| 19 | 방어 무력화 | 방어 −1(물리 저항 31 이상이면 50%) **그리고** 두 저항 −10 | 9.5 의 문장 그대로. hd_battle 은 둘 중 하나였다 |
| 20 | 탈 초인화 | 제3부: 선언 순서상 가장 낮은 능력 하나 제거. 제1·2부: 등급 −1 | 부록 A #2 「가장 낮은 능력 하나 제거」 |
| 21 | 적 마법 등급 1 의 대상 | 자리에 있는 대원 중 무작위 — 쓰러진 사람일 수 있고 빈 칸은 아니다 | 8.6 본문. 부록 A #22 |
| 22 | 등급 5 · 6 의 자기 회복량 | `레벨 × 정신력 × 3` (등급 4 와 같게), 등급 6 의 전원 회복은 `× 2` | 8.6 은 등급 4 와 5 의 값만 적는다 |
| 23 | 적의 회복(전체 회복 · 등급 5 · 6) | 전부 단계 회복 — 죽음 → 의식불명 → 깨어남 | 부록 A.4 |
| 24 | 정신 지배 | 20% 굴림 뒤에 면역을 본다. 넘어간 보조 일원은 적 목록에 서고 금화는 없다 | 8.6 · 8.8 |
| 25 | 에인션트 나이트의 「갑옷 3±1」 | 방어력 3±1 로 읽는다 | 9.7 |
| 26 | 설득된 적의 HP | 최대치로 합류 | 7.8 의 표가 식만 적는다 |
| 27 | 자동 전투의 마법사 | 1단계 단일 공격 마법 | 부록 A #25 의 첫째 안 |
| 28 | 보조 일원의 사거리 | 고유 무기는 0~2 또는 0~4 로 넓게 | 명령을 못 내리는 자리가 사거리 벌점으로 턴을 깎이면 안 된다 |
| 29 | 위치 층의 수치 | hd_battle 값 그대로 — 사거리 벌점 정확성 −6 / −14, 가로채기 30 / 55%, 무기 방식 위력 %, 상성 ×2 · ÷2, 몰림 +50%, 비틀거림 +30%, 버팀 +45 / +12 %p, 대상 가중 | 기획서에 없는 층이다. **제3부 수치에 맞춰 다시 잰 적이 없다** |
| 30 | 적의 무기·열·상성 | 이름과 수치에서 유도 (`enemyWeaponKey` · `defaultEnemyRank` · `constitutionOf`) | 224행을 손으로 채우지 않았다 |

### 문서 사이의 어긋남 — 고르지 않고 남긴 것

- **제1부 적의 HP 규모.** `1st/08` 은 HP = 인내 × 레벨(오크 8)이라 하고, 일행은 제3부 시스템이라 첫 타격이
  수백이다. 표는 문서대로 두었고 배율은 `enemyHpScale(episode)` 한 곳이다. 기획 판단이 필요하다.
- 고르곤 세 자매의 보상 기준(부록 A D15)은 넣지 않았다.

---

## 10. 규격 밖의 불변조건

`test/flow/purity_test.dart` 가 지킨다.

- Flutter 의존 **0**, 이 레포의 다른 패키지 의존 **0**
- 시드 없는 `Random()` **0**
- 코드에 한국어 **0** · emoji **0** (주석은 예외)
- 레벨 표 **0** — 레벨업은 RPG 가 판정한다
- 헛턴 없음: 모든 무기가 모든 거리에서 무언가는 한다 · 가로채기는 100% 가 되지 않는다 · 메뉴는 못 할
  것을 내놓지 않는다(예외는 미결 8 의 화살뿐)

그리고 **재현성**: 같은 개시 입력 + 같은 명령 열 + 같은 시드 → 같은 정산 결과.
