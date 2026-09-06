# 44. 적·아군 명세 — 분류 체계와 개체 특징 (Bestiary & Roster)

> **상태**: 2차 초안 (2026-09-06). 같은 날 오전의 1차 초안을 **전면 개정**했다 — 1차는 75행에
> 맞춰 race 11개를 만들었고, 2차는 **전통 RPG 의 분류를 가져와 75행이 그 안에 들어가게** 했다.
> B6 다음 트랙(B7)의 입력이다.
> **소유 주제**: 적의 분류(type → 계열 → 개체) · 역할·등급·용맹 · 개체 특징 · 적 preset ·
> **아군 직업 체계와 preset**. 이 주제로 다른 장과 어긋나면 이 장이 정본이다(D-18).

## 0. 왜 이 장이 필요한가

`packages/hd_battle` 은 적 75행을 **원작 바이너리에서 뽑은 능력치 표**로만 안다
(`data/enemy_table.dart`, C++ `EnemyData` 와 같은 열 11개 — 그 어디에도 "무엇인가" 는 없다).
그 위에 네 개의 **유도 규칙**이 얹혀 있다:

| 무엇 | 어떻게 정해지나 | 어디 |
|---|---|---|
| 싸우는 방식(preset) | `castLevel`·`special`·`agility`·`endurance` 로 추정 + 손으로 6종 | `rules/preset.dart` `enemyPreset` |
| 체질(물리 상성) | 손으로 쓴 이름 집합 4개 + 능력치 추정 | `rules/affinity.dart` `constitutionOf` |
| 무기(어떻게 닿는지) | 손으로 15종 + 힘으로 추정 | `rules/weapon.dart` `enemyWeaponKey` |
| 기본 열 | 힘·주문·민첩으로 추정 | `rules/position.dart` `defaultEnemyRank` |

추정이라 **틀린 곳이 눈에 보인다** (§5 에 전부 — 체질 18 · 방식 32 · 무기 38 · 열 14). 예:
`Dancing-Swd`(춤추는 검)가 **해충**이라 불과 찌르기에 약하다 — 체력 6·민첩 20 이 벌레처럼 보였다.
`Giant Rat`·`Blood Bat`·`Griffin`·`Hydra` 가 **장검을 든다** — 힘이 10 을 넘으면 장검이기 때문이다.
`Great Lich` 는 **살**이다 — 언데드 집합에 `lich` 는 있고 `great_lich` 는 없어서.

손으로 쓴 집합 세 개에는 **표에 없는 이름이 열네 개** 들어 있다 —
`constitutionOf` 9(`zombie` · `lich` · `gas_cloud` · `shadow` · `killer_bee` · `scorpion` · `ice_golem` ·
`fire_dragon` · `stone_golem`), `enemyWeapons` 4(`orc_soldier` · `lizard_man` · `centaur` · `knight`),
`namedEnemyPresets` 1(`knight`). 쓴 사람이 머릿속의 괴물 도감을 적었고 표와 대조하지 않았다.

플레이어에게 이것은 "저 검은 왜 불에 타지?", "쥐가 왜 장검을 휘두르지?" 다.
**행동은 되지만 설명이 안 된다.** 추정을 걷어내고 **개체마다 명세**하는 것이 이 장이다.

## 1. 분류의 원칙 — 이 게임에 맞춘 분류가 아니라, 전통 분류가 이 게임을 덮게

### 1.1 1차 초안이 틀린 세 가지

1. **축이 섞였다.** race 11개에 재료(부정형·정령), 모양(파충·곤충), 크기(거인), 도덕(마물)이
   한 층에 있었다. "파충·독물" 은 "언데드" 와 같은 층의 개념이 아니다 — 야수의 하위다.
2. **계열과 싸우는 방식을 한 층에 넣었다.** `class` 가 "고블린류" 이면서 동시에 "후방 시전" 이었다.
   그러면 **아종을 만들 수 없다** — "Orc (전사)" 와 "Orc (주술사)" 는 같은 계열에 다른 방식이다.
3. **75행에 맞춰 만들어 빈 칸이 없다.** 새 적을 만들 때 "어디에 넣지" 부터 다시 고민하게 된다.

### 1.2 채택 — 다섯 축, 전부 전통 RPG 에서 가져온 것

| 축 | 출처 | 값 | 무엇을 결정하나 |
|---|---|---|---|
| **type** (종류) | D&D 의 creature type 14종 | humanoid · giant · beast · monstrosity · aberration · ooze · fey · elemental · construct · dragon · undead · fiend · celestial · plant | **체질**(물리 상성) · **통하지 않는 것**(독·마비·정신) · 기본 원소 상성 · 기본 용맹 |
| **계열** (family) | type 안의 갈래 — 우리가 정한다 | 오크 · 소인 · 영체 · 시체 · 석상 … (지금 44개) | 이름·모습의 뿌리. **아종은 계열을 복사해 만든다** |
| **역할** (role) | D&D 4e 의 monster role 7종 | brute · soldier · skirmisher · artillery · controller · lurker · leader | **preset** · 무기 종류 · 기본 열 |
| **등급** (tier) | D&D 4e 의 minion / standard / elite / solo | 잡졸 · 일반 · 정예 · 단독 | 이름이 붙는지 · HP·보상의 배수 · 한 번에 몇이 나오나 |
| **용맹** (morale) | 고전 D&D 의 morale 판정을 3단으로 | 도망침 · 버팀 · 불퇴 | 언제 물러나는가. **지금 `coward` preset 이 하던 일** |

그리고 **개체**(named) — 이름이 붙은 것. 어느 축의 값이든 덮어쓴다. Stheno·Euryale, Guardian 한 쌍,
원작의 경비병 1~7 이 여기다.

**왜 D&D 인가.** 원작 자신이 그것을 쓰고 있었다 — Unity 포트의 `RACE` 열거
(인간·엘리멘탈·거인·골렘·용·천사·악마, `ObjTypes.cs:154`)는 D&D 14종의 **정확한 부분집합**이다
(humanoid · elemental · giant · construct · dragon · celestial · fiend). 플레이어에게만 붙어 있고
적에는 없었을 뿐이다. 그 일곱을 열넷으로 넓히는 것이지 새 체계를 들이는 것이 아니다.
그리고 14종이면 **어떤 판타지 괴물이라도 들어갈 자리가 있다** — 그것이 40년간 검증된 분류의 값이다.

**왜 4e 의 role 인가.** 우리 `PresetKind` 여섯 개가 이미 그것의 어설픈 복사였다 —
aggressive = brute, guardian = soldier, skirmisher = skirmisher, caster = artillery, medic = leader.
빠진 것이 **controller**(독·기절·즉사·능력 저하로 싸우는 것 — 우리 표에 열두 행이 있는데 전부
caster 나 skirmisher 로 뭉개져 있다)와 **lurker**(숨어 치는 것 — 우리 규칙에 없다. 빈 칸으로 둔다).
그리고 `coward` 는 역할이 아니라 **용맹**이다 — 축이 달랐다.

### 1.3 축이 다르면 서로 덮어쓰지 않는다

두 가지가 지금 코드에서 뭉쳐 있어 값을 잃는다:

- **체질 ≠ 원소 상성.** `Frost Dragon` 을 코드는 체질 "원소" 로 잡아(냉기 저항을 넣으려고)
  **비늘을 잃었다** — 베기 저항·타격 약점이 사라지고 찌르기 약점이 생겼다. 명세에서는 체질 **갑각** +
  원소 **냉기 저항·불 약점**, 두 칸이다.
- **체질 ≠ 갑주.** `Lord Ahn`·`Black Knight`·`Minotaur` 의 갑각은 살이 아니라 **입은 것**이다.
  type 기본은 살, 개체가 갑각으로 덮어쓴다 — "판금을 입은 인간" 이 정확히 그 뜻이다.

### 1.4 아종의 표시

같은 계열의 아종은 **이름에 붙인다** — `Orc (전사)` 처럼 괄호 역할명, 또는 개체명(`경비병 1`).
화면은 이미 이름 색으로 상태를 말하고 있어(부록 V-4) 색을 더 쓸 자리가 없다.
**감춘 아종은 두지 않는다** — "왜 저 Orc 는 다르지" 를 만들지 않는 것이 이 장의 목적이다.

## 2. 개체 명세의 항목

| 항목 | 뜻 | 지금은 어디서 오나 |
|---|---|---|
| `type` · `family` · `named` | §1 의 세 층 | 없음 — 이 장이 정한다 |
| `role` · `tier` · `morale` | §1 의 세 축 | `enemyPreset` **추정** + `coward` → 명세로 |
| 능력치 11개 | 원작 표 그대로 | `enemy_table.dart` (건드리지 않는다) |
| 체질 | 물리 상성 6종 (살·언데드·부정형·갑각·해충·원소) | `constitutionOf` **추정** → type 기본 + 개체 덮어쓰기 |
| 통하지 않는 것 | 독 · 마비 · 정신 · 물리(저항 80+) | `affinity` 손 표 + `immunityFor` → type 기본 + 개체 |
| 원소 상성 | 약점 · 저항 (불·냉기·번개·힘·정신·독) | `enemyAffinities` 손 표 21종 → type·계열 기본 + 개체 |
| 무기 | 어떻게 닿는지 (`weaponKey`) | `enemyWeaponKey` **추정** → 역할·type 에서 |
| 기본 열 | 1~3 | `defaultEnemyRank` **추정** → 역할에서 |
| 특수 능력 | 독 · 기절 · 즉사 | `special` 1·2·3 (표) |
| 주문 사다리 | 1~6 · 초인 1~3 | `castLevel` · `specialCastLevel` (표) |
| **소환 대상** | 초인 1 이 부르는 것 | 지금은 `자기 id − 20 ± 3` 산술(부록 T-6) → **이름으로 명세** |
| 표시 이름 | 아종·개체의 괄호 이름 | 없음 → `hd_battle_text` 가 붙인다 |

## 3. 75행의 배치

능력치는 표 그대로다. **역할·등급·체질·무기·열·용맹은 이 장이 제안하는 값**이고, 지금 코드와 다른
곳은 §5 에 전부 있다. `★` 는 이름 붙은 개체(13), `?` 는 판정을 붙였지만 검토를 부탁하는 것(5).
HP 는 `endurance × level`.

### 인간형 (HUMANOID) · 14

말과 도구를 쓴다. 체질 **살**. 면역 없음. 용맹은 개체가 정한다 — 이 type 만 도망침·버팀·불퇴가 다 나온다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 오크 | Orc | 0 | 1 | 8 | brute | 잡졸 | 살 | — | club · 1열 | 버팀 | — | — |  |
| 오크 | Troll | 1 | 1 | 6 | brute | 잡졸 | 살 | — | club · 1열 | 버팀 | — | — | 원작 lv1·HP 6. 거인형 트롤이 아니라 오크 곁의 잡졸이다 |
| 소인 | Dwarf | 4 | 2 | 20 | soldier | 일반 | 살 | — | mace · 1열 | 버팀 | — | — |  |
| 소인 | Goblin | 9 | 3 | 39 | skirmisher | 일반 | 살 | — | dagger · 2열 | 도망침 | — | — |  |
| 소인 | Kobold | 24 | 7 | 63 | artillery | 일반 | 살 | — | dagger · 3열 | 도망침 | — | 단일/전체 |  |
| 인간 | Devil Hunter | 26 | 7 | 70 | controller | 일반 | 살 | — | halberd · 2열 | 버팀 | 기절 | 단일 | 기절 + 주문 2. 원작 유일의 "사냥꾼" 행 |
| 인간 | Crazy One | 27 | 7 | 70 | artillery | 일반 | 살 | — | unarmed · 3열 | 버팀 | — | 단일/전체 |  |
| 용인 | Draconian | 61 | 19 | 570 | leader | 정예 | 살 | — | great_sword · 3열 | 버팀 | 기절 | +동료치료 · 초인 1 | 초인 1 = 소환. 소환 대상 명세 필요(지금은 id-20±) |
| 용인 | ★ ArchiDraconian | 69 | 25 | 750 | leader | 단독 | 살 | — | great_sword · 3열 | 불퇴 | 기절 | +동료치료 · 초인 1 |  |
| 군주 | ★ Lord Ahn | 67 | 23 | 1380 | leader | 단독 | 갑각 | **물리** | great_sword · 3열 | 불퇴 | 즉사 | +동료치료 · 초인 3 | 갑각 = 갑주(개체 예외). 초인 3 |
| 기사 | ★ Black Knight | 71 | 27 | 945 | soldier | 단독 | 갑각 | — | great_sword · 1열 | 불퇴 | 즉사 | — · 초인 1 | 갑각 = 판금 갑주(개체 예외). 앞열 — 지금은 초인 1 때문에 3열 |
| 수도자 | ★ ArchiMonk | 72 | 28 | 1400 | brute | 단독 | 살 | — | staff · 1열 | 불퇴 | — | — | 지팡이. 지금은 힘 20 이라 미늘창 |
| 마법사 | ★ ArchiMage | 73 | 29 | 870 | artillery | 단독 | 살 | — | staff · 3열 | 불퇴 | — | 전부 |  |
| 마법사 | ? ★ Neo-Necromancer | 74 | 30 | 1800 | leader | 단독 | 갑각 | **물리** | staff · 3열 | 불퇴 | 즉사 | 전부 · 초인 3 | 살아 있는 강령술사로 본다(언데드 아님). 독·정신 면역은 개체 예외. 지금 코드는 언데드 |

### 거인 (GIANT) · 3

덩치와 힘. 체질 **살**, 앞열 둔기. 면역 없음.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 거인 | Giant | 5 | 2 | 26 | brute | 일반 | 살 | — | club · 1열 | 버팀 | — | — |  |
| 거인 | Ogre | 28 | 8 | 152 | brute | 일반 | 살 | — | mace · 1열 | 버팀 | — | — |  |
| 거인 | Cyclops | 46 | 13 | 260 | brute | 일반 | 살 | — | club · 1열 | 버팀 | — | — |  |

### 야수 (BEAST) · 10

짐승. 무장 없음(맨몸: 이빨·발톱). 체질 **살**, 벌레 계열만 **해충**. 면역 없음. 원작에 짐승이 장검을 드는 행이 여덟 개 있었다 — 유도 규칙의 산물이다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 뱀 | Serpent | 2 | 1 | 7 | skirmisher | 잡졸 | 살 | — | unarmed · 2열 | 버팀 | 독 | 단일 |  |
| 뱀 | Python | 10 | 3 | 30 | skirmisher | 일반 | 살 | — | unarmed · 2열 | 버팀 | 독 | 단일 |  |
| 벌레 | Earth Worm | 3 | 1 | 5 | brute | 잡졸 | 해충 | — | unarmed · 1열 | 버팀 | — | 단일 | 표의 주문 1 은 그대로 둔다(뱉기) |
| 벌레 | Insects | 11 | 3 | 24 | skirmisher | 일반 | 해충 | — | unarmed · 2열 | 버팀 | 독 | 단일 |  |
| 벌레 | Giant Spider | 12 | 4 | 36 | skirmisher | 일반 | 해충 | — | unarmed · 2열 | 버팀 | 독 | — |  |
| 벌레 | Buzz Bug | 14 | 4 | 44 | brute | 일반 | 해충 | — | unarmed · 1열 | 버팀 | 독 | — |  |
| 늑대 | Wolf | 7 | 2 | 22 | skirmisher | 일반 | 살 | — | unarmed · 1열 | 버팀 | — | — |  |
| 설치류·박쥐 | Blood Bat | 16 | 5 | 50 | brute | 일반 | 살 | — | unarmed · 1열 | 버팀 | — | — | 민첩 5 는 표 값. 지금은 장검을 든다 |
| 설치류·박쥐 | Giant Rat | 17 | 5 | 90 | brute | 일반 | 살 | — | unarmed · 1열 | 버팀 | — | — | 지금은 장검을 든다 |
| 광포 짐승 | ? Rampager | 38 | 10 | 190 | brute | 일반 | 살 | — | unarmed · 1열 | 불퇴 | — | — | 이름이 정체를 말하지 않는다. 힘 20·민첩 19 의 돌격 짐승으로 둔다 |

### 괴물 (MONSTROSITY) · 9

전설의 짐승. 자연에 없는 것인데 짐승처럼 싸운다. 체질 **살** 기본, 비늘·갑각은 개체가 덮어쓴다. 여기가 개체 예외가 가장 많은 type 이다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 석화 파충 | Basilisk | 33 | 9 | 108 | controller | 일반 | 살 | — | unarmed · 2열 | 버팀 | 독 | 단일 |  |
| 괴조 | Griffin | 44 | 12 | 180 | skirmisher | 일반 | 살 | — | unarmed · 2열 | 버팀 | 기절 | 단일/전체 | 지금은 장검을 든다 |
| 다두 | Hydra | 48 | 13 | 260 | soldier | 정예 | 갑각 | — | unarmed · 1열 | 불퇴 | 독 | 단일/전체 | 갑각 = 비늘(개체 예외) |
| 고르곤 | ★ Stheno | 49 | 14 | 280 | controller | 정예 | 갑각 | **물리** | unarmed · 2열 | 불퇴 | 독 | 단일/전체 | ac 255 · 저항 255 — 물리가 안 통하는 연출용 개체. 셋이 한 무리 |
| 고르곤 | ★ Euryale | 50 | 14 | 210 | controller | 정예 | 갑각 | **물리** | unarmed · 2열 | 불퇴 | 기절 | 단일/전체 | ac 255 · 저항 255 |
| 고르곤 | ★ Medusa | 51 | 14 | 224 | controller | 정예 | 살 | — | unarmed · 2열 | 버팀 | 즉사 | 단일/전체 | 즉사 = 석화 |
| 미노타우로스 | Minotaur | 52 | 15 | 300 | soldier | 정예 | 갑각 | — | poleaxe · 1열 | 불퇴 | — | 단일/전체 | ac 10 = 갑주(개체 예외). 도끼창 |
| 거대 게 | ? ★ Crab God | 58 | 17 | 510 | leader | 정예 | 갑각 | — | unarmed · 3열 | 불퇴 | 기절 | +자기치료 | 게 껍질 = 갑각. 지금 코드는 살(ac 7). "신격" 인지 거대 게인지는 원작 문맥 필요 |
| 거대 뱀 | Panzer Viper | 70 | 26 | 1040 | soldier | 정예 | 갑각 | **물리** | unarmed · 1열 | 불퇴 | 독 | — | "Panzer" — 갑각은 이름이 말한다 |

### 이형 (ABERRATION) · 2

이 세계의 것이 아닌 이형. 정신 공격을 스스로 쓴다. 체질은 개체마다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 눈 | Gazer | 20 | 6 | 66 | controller | 일반 | 살 | — | unarmed · 2열 | 버팀 | — | 단일 | 눈에서 쏘는 것. 지금은 장검 |
| 변이체 | Mutant | 39 | 10 | 150 | artillery | 일반 | 부정형 | — | unarmed · 3열 | 버팀 | — | 단일/전체 |  |

### 부정형 (OOZE) · 3

베어도 소용없다. 체질 **부정형**. 면역 마비·정신.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 점액 | Slime | 22 | 6 | 30 | skirmisher | 일반 | 부정형 | 마비·정신 | unarmed · 2열 | 불퇴 | — | 단일 |  |
| 점액 | Astral Mud | 56 | 16 | 400 | artillery | 정예 | 부정형 | 마비·정신 | unarmed · 3열 | 불퇴 | 즉사 | +자기치료 |  |
| 진흙 | ? Mud-Man | 30 | 8 | 120 | soldier | 일반 | 부정형 | 마비·정신 | unarmed · 1열 | 불퇴 | — | — | ac 7 은 마른 진흙. 골렘(구조물) 로 볼 수도 있다 — 이름을 따라 부정형에 둔다 |

### 요정 (FEY) · 4

요정·정령류의 작은 것. 빠르고 약하며 주문을 쓴다. 빛으로 된 것은 **부정형**. 도망침이 흔하다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 소요정 | Gremlin | 13 | 4 | 40 | skirmisher | 일반 | 살 | — | dagger · 2열 | 도망침 | — | — | 지금은 소인류 돌격 |
| 소요정 | Sprite | 34 | 9 | 18 | controller | 일반 | 부정형 | **물리** | unarmed · 3열 | 도망침 | 즉사 | +동료치료 | HP 18 · 저항 80 · 즉사 · 주문 5 — 유리 대포. 저항 80 이 물리 면역을 만든다 |
| 물요정 | Kelpie | 19 | 5 | 40 | artillery | 일반 | 살 | — | unarmed · 3열 | 버팀 | — | 단일/전체 | 지금은 야수 |
| 도깨비불 | Wisp | 32 | 9 | 90 | artillery | 일반 | 부정형 | — | unarmed · 3열 | 버팀 | — | +자기치료 |  |

### 정령 (ELEMENTAL) · 3

한 원소로 된 것. 체질 **원소**(베기 저항·찌르기 약점) + **자기 원소 저항·반대 원소 약점**. 면역 독·마비. 두 축이 다르다 — 체질은 물리, 원소는 마법.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 불 | Salamander | 15 | 4 | 52 | skirmisher | 일반 | 원소 | 독·마비 | unarmed · 2열 | 불퇴 | 독 | 단일 |  |
| 불 | Molten Monster | 36 | 10 | 200 | soldier | 일반 | 원소 | 독·마비 | unarmed · 1열 | 불퇴 | — | — | 지금 코드는 살·불 상성 없음 |
| 불 | Hell Fire | 55 | 16 | 480 | leader | 정예 | 원소 | 독·마비 | unarmed · 3열 | 불퇴 | 즉사 | +동료치료 |  |

### 구조물 (CONSTRUCT) · 6

만들어진 것. 체질 **갑각**(베기 안 듦·타격 약점). 면역 독·마비·정신. 용맹 **불퇴**.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 석상 | Rock-Man | 23 | 6 | 90 | soldier | 일반 | 갑각 | 독·마비·정신 | unarmed · 1열 | 불퇴 | — | — |  |
| 석상 | Gagoyle | 41 | 11 | 220 | soldier | 일반 | 갑각 | 독·마비·정신 | unarmed · 1열 | 불퇴 | — | — | D&D 는 정령으로 두지만 플레이어에게는 돌이다 |
| 움직이는 물건 | Dancing-Swd | 47 | 13 | 78 | skirmisher | 일반 | 갑각 | 독·마비·정신 | long_sword · 2열 | 불퇴 | 기절 | +자기치료 | 쇠다. 지금 코드는 해충·후방 시전. 표의 주문 4 는 의심스럽다 — 검이 주문을 쓴다 |
| 수호상 | ★ Guardian-Lft | 63 | 20 | 800 | soldier | 정예 | 갑각 | 독·마비·정신 | halberd · 1열 | 불퇴 | 기절 | — | 한 쌍 |
| 수호상 | ★ Guardian-Rgt | 64 | 20 | 800 | soldier | 정예 | 갑각 | 독·마비·정신 | halberd · 1열 | 불퇴 | 기절 | — | 한 쌍 |
| 기계 | Mega-Robo | 65 | 21 | 1050 | brute | 정예 | 갑각 | 독·마비·정신 | great_sword · 1열 | 불퇴 | — | — |  |

### 용 (DRAGON) · 3

비늘. 체질 **갑각** + 각자의 숨결 원소 상성. 용맹 불퇴.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 비룡 | Wivern | 42 | 11 | 99 | skirmisher | 일반 | 갑각 | — | unarmed · 2열 | 버팀 | 기절 | 단일/전체 | 지금은 파충·장검 |
| 용 | Dragon | 53 | 15 | 300 | artillery | 정예 | 갑각 | — | unarmed · 3열 | 불퇴 | 기절 | +자기치료 | 불 저항(숨결) |
| 용 | Frost Dragon | 68 | 24 | 480 | artillery | 정예 | 갑각 | — | unarmed · 3열 | 불퇴 | 기절 | +자기치료 | 갑각 + 냉기 저항·불 약점. 지금 코드는 체질을 "원소" 로 잡아 비늘을 잃는다 |

### 언데드 (UNDEAD) · 16

죽은 것. 체질 **언데드**(베기·찌르기 저항·타격 약점). 면역 독·정신. 용맹 **불퇴**. 시체는 불에 약하다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 영체 | Phantom | 6 | 2 | 24 | artillery | 일반 | 언데드 | 독·정신 | unarmed · 3열 | 불퇴 | — | 단일 |  |
| 영체 | Ghost | 21 | 6 | 60 | artillery | 일반 | 언데드 | 독·정신 | unarmed · 3열 | 불퇴 | — | 단일/전체 |  |
| 영체 | Evil Soul | 45 | 12 | 120 | controller | 일반 | 언데드 | 독·정신 | unarmed · 3열 | 불퇴 | 즉사 | +자기치료 |  |
| 영체 | Dark Soul | 54 | 15 | 600 | leader | 정예 | 언데드 | 독·정신 | unarmed · 3열 | 불퇴 | — | +동료치료 |  |
| 영체 | Wraith | 59 | 18 | 630 | artillery | 정예 | 언데드 | 독·정신 | unarmed · 3열 | 불퇴 | 즉사 | +자기치료 |  |
| 영체 | Death Skull | 60 | 18 | 720 | leader | 정예 | 언데드 | 독·정신 · **물리** | unarmed · 3열 | 불퇴 | 기절 | +동료치료 |  |
| 시체 | Skeleton | 18 | 5 | 95 | soldier | 일반 | 언데드 | 독·정신 | long_sword · 1열 | 불퇴 | — | — |  |
| 시체 | Mummy | 25 | 7 | 70 | soldier | 일반 | 언데드 | 독·정신 | unarmed · 1열 | 불퇴 | 독 | 단일 | 불 약점 |
| 시체 | ? Headless | 29 | 8 | 120 | brute | 일반 | 언데드 | 독·정신 | long_sword · 1열 | 불퇴 | 기절 | — | 목 없는 것 = 언데드로 본다. 지금 코드는 살 |
| 시체 | Rotten Corpse | 40 | 11 | 165 | controller | 일반 | 언데드 | 독·정신 | unarmed · 2열 | 불퇴 | 기절 | 단일/전체 |  |
| 흡혈귀 | Vampire | 35 | 9 | 126 | skirmisher | 정예 | 언데드 | 독·정신 | unarmed · 2열 | 버팀 | 독 | 단일 | 지금 코드는 살 |
| 리치 | Great Lich | 37 | 10 | 110 | controller | 정예 | 언데드 | 독·정신 | staff · 3열 | 불퇴 | 기절 | 단일/전체 | 지금 코드는 살(집합에 great_lich 가 없음). 이름이 아니라 계열이다 |
| 사신 | Grim Death | 43 | 12 | 192 | controller | 일반 | 언데드 | 독·정신 | unarmed · 2열 | 불퇴 | 기절 | 단일/전체 | 지금 코드는 살 |
| 사신 | Reaper | 57 | 17 | 561 | controller | 정예 | 언데드 | 독·정신 | unarmed · 2열 | 불퇴 | 독 | 단일/전체 | 지금 코드는 살 |
| 죽은 기사 | Death Knight | 62 | 19 | 665 | soldier | 정예 | 언데드 | 독·정신 | great_sword · 1열 | 불퇴 | 즉사 | — · 초인 1 | 초인 1 = 소환. 앞열 — 지금은 3열 |
| 태고의 악 | ★ Ancient Evil | 66 | 22 | 1320 | leader | 단독 | 언데드 | 독·정신 · **물리** | unarmed · 3열 | 불퇴 | — | 전부 · 초인 2 | 초인 2 = 파티원 납치 |

### 악마 (FIEND) · 2

지옥의 것. 체질 **살**, 불 저항. 교활해서 도망칠 줄 안다.

| 계열 | 개체 | id | lv | HP | 역할 | 등급 | 체질 | 통하지 않는 것 | 무기·열 | 용맹 | 특수 | 주문 | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 소악마 | Imp | 8 | 3 | 30 | skirmisher | 일반 | 살 | — | unarmed · 2열 | 도망침 | — | 단일 |  |
| 지옥 짐승 | Hell Cat | 31 | 8 | 88 | skirmisher | 일반 | 살 | — | unarmed · 2열 | 버팀 | 기절 | 단일/전체 | 지금은 야수·장검 |

### 천상 (CELESTIAL) — 빈 칸

**빈 칸.** 천상의 것 — 원작 `RACE.ANGEL` 이 예약한 자리. 적으로 만나는 천사·정의의 화신이 여기 들어온다.

### 식물 (PLANT) — 빈 칸

**빈 칸.** 움직이는 식물·균류. 체질 부정형에 가깝고 불에 약하다. 숲 지역을 만들 때 첫 후보다.


**요약** — type 14 중 **12 에 채워졌고 2 가 비었다**(천상 · 식물). 계열 44 · 개체 13.
등급은 잡졸 4 · 일반 42 · 정예 22 · 단독 7. 역할은 brute 13 · soldier 14 · skirmisher 15 ·
artillery 12 · controller 12 · leader 9 · **lurker 0**.

## 4. 1차 초안에서 옮긴 것 — 검토 결과

이름이 말하는 정체를 능력치보다 앞에 두었다. 옮긴 행과 이유:

| 개체 | 1차 | 2차 | 왜 |
|---|---|---|---|
| Troll | 아인(오크·트롤) | 인간형·오크 (그대로) | 거인으로 옮기지 **않았다** — lv 1 · HP 6 이다. 원작의 트롤은 오크 곁의 잡졸이지 재생하는 거인이 아니다 |
| Kelpie | 야수 | **요정**·물요정 | 켈피는 물의 요정이다. "야수 아래 정령마" 는 자기모순이었다 |
| Gazer | 야수·괴조 | **이형**·눈 | 눈알 괴물은 짐승이 아니다. 주문 2·명중 [15,15] — 눈에서 쏜다 |
| Basilisk | 야수·괴조 | **괴물**·석화 파충 | 전설의 파충. 괴조와 한 줄에 있을 이유가 없었다 |
| Griffin | 야수·괴조 | **괴물**·괴조 | 합성 짐승은 monstrosity 다 |
| Wivern | 파충·비룡 | **용**·비룡 | 비룡은 용의 하위다 |
| Hydra | 파충·다두 | **괴물**·다두 | 전설의 다두 뱀 |
| Panzer Viper | 파충·뱀 | **괴물**·거대 뱀 | 갑각 뱀은 자연에 없다 |
| Minotaur | 거인·수인 거인 | **괴물**·미노타우로스 | 거인이 아니다. ac 10 은 갑주 |
| Rampager | 거인·광포한 것 | **야수**·광포 짐승 `?` | 이름이 정체를 말하지 않는다. 힘 20·민첩 19 의 돌격 짐승으로 두었다 |
| Gremlin | 소인·고블린류 | **요정**·소요정 | 그렘린은 장난치는 요정이다. 소인류가 아니다 |
| Wisp · Sprite | 정령·빛·요정 | **요정**·도깨비불 / 소요정 | 정령(한 원소로 된 것)이 아니다 |
| Hell Cat | 야수·고양이과 | **악마**·지옥 짐승 | 이름이 말한다. 주문 3·기절 — 짐승의 능력이 아니다 |
| Mutant | 부정형·변이체 | **이형**·변이체 | 변이체는 형태가 없는 것이 아니다. 힘 0·주문 3 이라 체질만 부정형 |
| Headless `?` | 인간 전사 `?` | **언데드**·시체 | 목 없는 것은 언데드로 본다 |
| Mud-Man `?` | 점액 `?` | **부정형**·진흙 | 이름을 따른다. ac 7 은 마른 진흙. 골렘으로 볼 여지를 `?` 로 남긴다 |
| Neo-Necromancer | 언데드·강령술사 | **인간형**·마법사 `?` | 강령술사는 산 사람이다. 독·정신 면역은 개체 예외로 준다. 지금 코드는 언데드로 다룬다 |
| Great Lich | ★ 개체 | 계열 **리치** (★ 아님) | "Great" 는 이름이 아니라 급이다. 한 행뿐이라 계열에 한 개체 |
| Crab God | 마물·신격 | **괴물**·거대 게 `?` ★ | 게 껍질은 갑각이다 — 지금 코드는 살. "신격" 이 원작 문맥에 있는지 확인이 필요하다 |
| Imp | 마물·소악마 | **악마**·소악마 | 마물이라는 잡동사니 범주를 없앴다 |
| Rock-Man · Gagoyle | 구조물·석상 | 구조물·석상 (그대로) | D&D 는 가고일을 정령으로 두지만 **플레이어에게는 돌**이다 — 타격에 약하고 독이 안 든다 |

그 밖에 **`?` 다섯** — Rampager · Mud-Man · Headless · Neo-Necromancer · Crab God — 은 판정을 붙여 두었다.
틀렸으면 그 행만 고친다. 표 구조는 바뀌지 않는다.

## 5. 지금 코드와 어긋나는 곳 — 전수

왼쪽이 플레이어가 지금 겪는 값, 오른쪽이 §3 이다. 네 표 모두 스크립트로 뽑았다(추정 함수를 직접 불러
비교). **이것이 "왜 저 놈은…" 의 목록이다.**

#### 체질 — 18건

| id | 이름 | 지금 | 명세 |
|---|---|---|---|
| 3 | Earth Worm | 살 | 해충 |
| 23 | Rock-Man | 살 | 갑각 |
| 29 | Headless | 살 | 언데드 |
| 30 | Mud-Man | 살 | 부정형 |
| 35 | Vampire | 살 | 언데드 |
| 36 | Molten Monster | 살 | 원소 |
| 37 | Great Lich | 살 | 언데드 |
| 41 | Gagoyle | 살 | 갑각 |
| 42 | Wivern | 살 | 갑각 |
| 43 | Grim Death | 살 | 언데드 |
| 47 | Dancing-Swd | 해충 | 갑각 |
| 57 | Reaper | 살 | 언데드 |
| 58 | Crab God | 살 | 갑각 |
| 63 | Guardian-Lft | 살 | 갑각 |
| 64 | Guardian-Rgt | 살 | 갑각 |
| 68 | Frost Dragon | 원소 | 갑각 |
| 71 | Black Knight | 살 | 갑각 |
| 74 | Neo-Necromancer | 언데드 | 갑각 |

#### 방식(역할) — 32건

| id | 이름 | 지금 preset | 명세 역할 |
|---|---|---|---|
| 3 | Earth Worm | skirmisher | brute 난폭자 |
| 4 | Dwarf | aggressive | soldier 병사 |
| 6 | Phantom | skirmisher | artillery 포병 |
| 7 | Wolf | aggressive | skirmisher 유격병 |
| 12 | Giant Spider | aggressive | skirmisher 유격병 |
| 13 | Gremlin | aggressive | skirmisher 유격병 |
| 18 | Skeleton | aggressive | soldier 병사 |
| 19 | Kelpie | skirmisher | artillery 포병 |
| 20 | Gazer | skirmisher | controller 통제자 |
| 21 | Ghost | skirmisher | artillery 포병 |
| 23 | Rock-Man | aggressive | soldier 병사 |
| 25 | Mummy | skirmisher | soldier 병사 |
| 26 | Devil Hunter | skirmisher | controller 통제자 |
| 27 | Crazy One | skirmisher | artillery 포병 |
| 30 | Mud-Man | aggressive | soldier 병사 |
| 33 | Basilisk | skirmisher | controller 통제자 |
| 36 | Molten Monster | aggressive | soldier 병사 |
| 37 | Great Lich | skirmisher | controller 통제자 |
| 39 | Mutant | skirmisher | artillery 포병 |
| 40 | Rotten Corpse | skirmisher | controller 통제자 |
| 41 | Gagoyle | aggressive | soldier 병사 |
| 43 | Grim Death | skirmisher | controller 통제자 |
| 47 | Dancing-Swd | caster | skirmisher 유격병 |
| 48 | Hydra | skirmisher | soldier 병사 |
| 49 | Stheno | skirmisher | controller 통제자 |
| 50 | Euryale | skirmisher | controller 통제자 |
| 51 | Medusa | skirmisher | controller 통제자 |
| 52 | Minotaur | skirmisher | soldier 병사 |
| 57 | Reaper | skirmisher | controller 통제자 |
| 63 | Guardian-Lft | aggressive | soldier 병사 |
| 64 | Guardian-Rgt | aggressive | soldier 병사 |
| 70 | Panzer Viper | aggressive | soldier 병사 |

#### 무기 — 38건

| id | 이름 | 지금 | 명세 |
|---|---|---|---|
| 0 | Orc | unarmed | club |
| 4 | Dwarf | long_sword | mace |
| 9 | Goblin | long_sword | dagger |
| 12 | Giant Spider | long_sword | unarmed |
| 13 | Gremlin | long_sword | dagger |
| 14 | Buzz Bug | long_sword | unarmed |
| 15 | Salamander | long_sword | unarmed |
| 16 | Blood Bat | long_sword | unarmed |
| 17 | Giant Rat | long_sword | unarmed |
| 20 | Gazer | long_sword | unarmed |
| 23 | Rock-Man | halberd | unarmed |
| 24 | Kobold | unarmed | dagger |
| 25 | Mummy | long_sword | unarmed |
| 30 | Mud-Man | long_sword | unarmed |
| 31 | Hell Cat | long_sword | unarmed |
| 35 | Vampire | long_sword | unarmed |
| 37 | Great Lich | long_sword | staff |
| 38 | Rampager | halberd | unarmed |
| 40 | Rotten Corpse | long_sword | unarmed |
| 41 | Gagoyle | long_sword | unarmed |
| 42 | Wivern | long_sword | unarmed |
| 43 | Grim Death | long_sword | unarmed |
| 44 | Griffin | long_sword | unarmed |
| 46 | Cyclops | halberd | club |
| 48 | Hydra | long_sword | unarmed |
| 49 | Stheno | halberd | unarmed |
| 50 | Euryale | halberd | unarmed |
| 51 | Medusa | long_sword | unarmed |
| 52 | Minotaur | long_sword | poleaxe |
| 55 | Hell Fire | long_sword | unarmed |
| 56 | Astral Mud | long_sword | unarmed |
| 57 | Reaper | long_sword | unarmed |
| 58 | Crab God | halberd | unarmed |
| 68 | Frost Dragon | long_sword | unarmed |
| 70 | Panzer Viper | great_sword | unarmed |
| 72 | ArchiMonk | halberd | staff |
| 73 | ArchiMage | long_sword | staff |
| 74 | Neo-Necromancer | great_sword | staff |

#### 기본 열 — 14건

| id | 이름 | 지금 | 명세 |
|---|---|---|---|
| 3 | Earth Worm | 2 | 1 |
| 9 | Goblin | 1 | 2 |
| 12 | Giant Spider | 1 | 2 |
| 13 | Gremlin | 1 | 2 |
| 19 | Kelpie | 2 | 3 |
| 24 | Kobold | 2 | 3 |
| 25 | Mummy | 2 | 1 |
| 27 | Crazy One | 2 | 3 |
| 37 | Great Lich | 2 | 3 |
| 47 | Dancing-Swd | 3 | 2 |
| 48 | Hydra | 2 | 1 |
| 52 | Minotaur | 2 | 1 |
| 62 | Death Knight | 3 | 1 |
| 71 | Black Knight | 3 | 1 |


세 가지가 읽힌다:

- **무기가 가장 많이 틀렸다(38).** 유도 규칙이 "힘 10 이상 = 장검" 이라 짐승 여덟, 언데드 여섯,
  괴물 여섯이 칼을 든다. 명세는 **type 이 무장을 정한다** — 짐승·괴물·용·부정형·정령은 맨몸이다.
- **역할(32)** 은 새 축이라 많이 다른 것이 당연하다. 눈여겨볼 것은 **controller 12 행이 전부 없던 것**이고,
  단독 등급의 기사 둘(Black Knight · Death Knight)이 **초인 1 때문에 3열**로 밀려 있던 것이다 —
  소환하는 기사라도 기사는 앞에 선다.
- **체질(18)** 중 1차 초안이 "지금 값이 맞다" 고 했던 여섯(Hydra · Stheno · Euryale · Minotaur ·
  Lord Ahn · Panzer Viper 의 갑각)은 그대로 맞다 — §3 에 **개체 예외**로 적혀 있어 표에서 사라졌다.
  새로 드러난 것은 Frost Dragon(비늘을 잃음), Crab God(게가 살), Wivern(비룡이 살), Earth Worm.

## 6. 창작으로 늘리기 — 빈 칸과 절차

75 는 상한이 아니라 **첫 채움**이다. 체계가 열어 둔 자리:

| 빈 칸 | 무엇 | 첫 후보 |
|---|---|---|
| type **천상** | 원작 `RACE.ANGEL` 이 예약한 자리. 적으로 만나는 천사·심판자 | 타락한 수호 천사(단독), 빛의 정령 기사(soldier) |
| type **식물** | 움직이는 식물·균류. 불에 약하고 정신이 안 통한다 | 나무 거인 트렌트(soldier), 독 포자 버섯(controller), 덩굴(lurker) |
| 역할 **lurker** | 숨었다가 치고 물러나는 것. 규칙이 없다 — B5 에 은신이 없다 | 그림자(undead·lurker), 암살자(humanoid·lurker). **규칙 하나가 필요하다**: 첫 라운드 표적 불가 |
| 얇은 계열 | 거인 3 · 악마 2 · 정령 3(불만) · 용 3 | 냉기·번개·땅 정령(계열 셋 추가) · 서큐버스·발록(악마) · 서리 거인 |
| 아종 | 같은 계열 다른 역할 | **Orc (주술사)** = 오크 + artillery · **Orc (대장)** = 오크 + leader + 정예 · **Skeleton (궁수)** = 시체 + artillery |

**새 적을 만드는 절차** — 네 칸만 정하면 나머지는 기본값이 채운다:

1. **type** 을 고른다 → 체질·면역·용맹 기본이 정해진다.
2. **계열**을 고르거나 새로 판다 → 이름의 뿌리. 아종이면 기존 계열을 복사한다.
3. **역할**을 고른다 → preset·무기 종류·열이 정해진다.
4. **등급**을 고른다 → 잡졸·일반이면 이름 없음, 정예·단독이면 이름을 붙인다.
5. 능력치 11개는 **같은 등급·같은 레벨의 이웃 행**을 복사해 시작한다. 체계가 이웃을 보여 준다.

이것은 S3(AI 생성) 이 적을 만들 때 쓰는 **스키마**이기도 하다 — 자유 서술이 아니라 다섯 축의 값을
채우는 일이 되고, 검증은 "type 에 없는 값" 을 잡는 일이 된다.

## 7. 아군 — 전통 RPG 의 직업 체계가 이 게임을 덮게

### 7.1 지금

`CombatantSnapshot.preset` 필드는 있지만(기본 `aggressive`) **RPG 가 값을 넣는 곳이 없고 고르는
화면도 없다.** 자동 전투에서 전원이 `aggressive` 로 돈다. 직업은 세 개다 —
`getClassName()` 의 에스퍼(0) · 싸이보그(1) · 초능력자(2). 시작 파티는 에스퍼 슴갈과 초능력자 유리,
싸이보그는 아직 아무도 아니다.

### 7.2 원작 시리즈에 이미 있는 체계

같은 시리즈의 Unity 포트(`REF_UNITY_LoreEp1/src_as_cs/ObjTypes.cs` · `ObjPlayer.cs`)에
Wizardry 계보의 완성된 체계가 있다. 이식 대상이다.

**직업 17** (`CLASS`) — 생성 가능한 기본 8 + 전직으로만 가는 상위 8:

| 기본 (1~8) | 상위 (9~16) | 갈래 (`CLASS_TYPE`) |
|---|---|---|
| 떠돌이 · 기사 · 사냥꾼 · 전투승 | 검사* | **물리** — SP 0 |
| 마법사 | 메이지 · 컨저러 · 주술사 · 위저드 · 강령술사 · 대마법사 · 타임워커 | **마법** — HP ×0.5 |
| 전사 (PALADIN) | — | **혼합 1** — 물리 + 치료 마법 |
| 암살자 | — | **혼합 2** — 물리 + 소환·특수 마법 |
| 에스퍼 | — (전직 불가) | **혼합 3** — 물리 + 초자연력 |

\* 검사는 상위이지만 물리 갈래 안의 전직이다. 혼합 셋은 HP ×0.8 · SP ×0.5.

**기술 12** (`SKILL_TYPE`) — 무기 5(베는·찍는·찌르는·타격·쏘는) + 방패 + 마법 5(공격·변화·치료·소환·특수) +
초자연력. **직업은 이 12칸의 최소·최대치로 정의된다**(`_CLASS_ABILITY[17][12][2]`) — 기사는 방패 20~60,
사냥꾼은 쏘는 무기 40~100, 전투승은 타격 40~100 만, 에스퍼는 초자연력 50~100 에 무기 0~40.
"이 직업이 무엇인가" 가 숫자로 있다.

**이 게임의 세 직업은 그 안에 들어간다**:

| 지금 | 원작 체계에서 | 근거 |
|---|---|---|
| 에스퍼 (슴갈) | **에스퍼** (혼합 3) — 이름이 같다 | 힘 18 · 마법 lv 20 · 초능력 lv 20 · 무기 있음. 원작 에스퍼보다 마법이 더 있어 **개체 예외** |
| 초능력자 (유리) | 에스퍼의 아종 — 초자연력 특화 | 초능력 80 · 마법 0 · 힘 10 |
| 싸이보그 | 물리 갈래 — 기사 또는 검사 | 이름만 있고 아무도 없다. 방패를 주면 기사, 아니면 검사 |

### 7.3 아군 preset — 역할 × 절약

적과 **같은 원리, 같은 표**다. 4e 는 플레이어에게도 역할을 준다 — defender · striker · controller · leader.
DQ 의 작전(가진 힘을 다해 / 목숨을 아껴 / MP 를 아껴 / 명령대로)은 그 위에 **절약** 한 축을 더한 것이다.
둘을 합치면:

| preset | 역할 | 무엇을 하나 | 지금 `PresetKind` |
|---|---|---|---|
| **방벽** | defender | 앞열, 맞으면 버팀, 밀리지 않음 | guardian |
| **돌격** | striker (근접) | 가까운 적을 무기로. 멀면 파고듦 | aggressive |
| **유격** | striker (기동) | 치고 물러남. 뒷열에 머무름 | skirmisher |
| **사격** | striker (원거리) | 뒷열에서 쏘는 무기 | **없음** — 쏘는 무기가 규칙에 없다 |
| **화력** | controller (공격 마법) | 공격 마법 우선, 전체 마법은 적이 셋 이상일 때 | caster |
| **교란** | controller (상태) | 무기 도포 · 능력 저하 · 염력 · 기술 무력화 우선 | **없음** |
| **치유** | leader | 절반 아래 동료 먼저, 없으면 공격 | medic |
| + **절약** (토글) | — | SP 절반 아래면 기술을 쓰지 않음 | 없음 |

preset 은 여전히 **대상을 고르지 않는다**(B5-08 의 원칙 — 판을 읽는 것은 플레이어의 일).
**각 preset 이 매 라운드 실제로 무엇을 고르는지**는 [BP-46](46_preset_logic.md) 이 문장으로 정한다.

### 7.4 직업 → 허용 preset

`_CLASS_ABILITY` 의 기술 칸에서 기계적으로 나온다 — 방패 최소 20 이상이면 방벽, 쏘는 무기가 있으면 사격,
공격 마법이 있으면 화력, 치료가 있으면 치유, 특수·초자연력이 있으면 교란:

| 직업 | 방벽 | 돌격 | 유격 | 사격 | 화력 | 교란 | 치유 | 주 preset |
|---|---|---|---|---|---|---|---|---|
| 떠돌이 | ○ | ○ | ○ | ○ | | | | 돌격 |
| 기사 | **○** | ○ | | | | | | 방벽 |
| 사냥꾼 | | ○ | ○ | **○** | | | | 사격 |
| 전투승 | | **○** | ○ | | | | | 돌격 (맨손) |
| 전사 | **○** | ○ | | ○ | | | ○ | 방벽 · 치유 |
| 암살자 | | ○ | **○** | ○ | | **○** | | 유격 · 교란 — **B6-03 의 도포가 이 직업의 것**이다 |
| 마법사 | | | | | **○** | ○ | ○ | 화력 |
| 에스퍼 | | ○ | ○ | | | **○** | | 교란 (염력) |
| 검사 | | **○** | ○ | | | | | 돌격 |
| 메이지 · 위저드 | | | | | **○** | ○ | ○ | 화력 |
| 컨저러 · 주술사 · 강령술사 · 대마법사 | | | | | ○ | ○ | **○** | 치유 (+소환 — **규칙 없음**) |
| 타임워커 | | | | | ○ | ○ | ○ | 전부 |
| — | | | | | | | | |
| 에스퍼 (슴갈) | | ○ | ○ | | ○ | **○** | ○ | 개체 예외 — 마법·초능력 둘 다 |
| 초능력자 (유리) | | ○ | | | | **○** | | |
| 싸이보그 | ○ | **○** | | | | | | 기사로 보면 방벽 |

**빈 칸이 여기서도 드러난다** — 사격(쏘는 무기 없음) · 소환(파티 소환 없음) · lurker(은신 없음).
이것이 "전통 체계로 덮는" 것의 값이다: 이 게임이 **무엇을 아직 안 갖고 있는지** 표가 말해 준다.
채울지는 별도 판정이지 지금 일이 아니다.

### 7.5 적과 아군이 같은 표를 쓴다

`Preset` 은 **역할 + 자세 + 절약**이 된다. `PresetKind` 여섯은 역할 일곱으로 바뀌고 `coward` 는
`morale` 로 나간다. 적의 controller 12 행과 아군의 교란 preset 이 **같은 코드**다. 그래서 B7 은
적을 먼저 하고, 아군은 표에 줄을 더한다.

## 8. 다음 — B7 트랙 (제안, 2차)

| | 무엇 | 규모 |
|---|---|---|
| B7-01 | `EnemySpec` — §2 항목 전부. 표 75행을 감싼다. **유도 규칙 4개와 허깨비 키 14개를 걷어낸다** | L |
| B7-02 | §3 의 `?` 다섯과 §4 의 이동을 사람이 검토해 확정. 이 장 개정 | M (검토) |
| B7-03 | 역할 7 · 등급 4 · 용맹 3 · 면역을 규칙이 명세에서 읽게. `PresetKind` → 역할, `coward` → 용맹. **controller** 규칙 신설 | M |
| B7-04 | 아종·개체 표시 이름(`hd_battle_text`) · **소환 대상 명세** · `Enemy::ChangeAttribute` 23곳을 **개체 등록**으로 흡수(경비병 1~7 = 인간·병사 계열의 개체) | M |
| B7-05 | 아군 — 직업 17 이식(`_CLASS_ABILITY`) · 세 직업의 대응 · preset 7 + 절약 · 선택 화면(실험실 먼저) | L |
| B7-06 | 창작 가이드 §6 를 S3 스키마로 — 빈 칸 첫 개체는 **선택** | S |
| B7-99 | 규격 v4 — `enemyKeys` 는 그대로(계열 키 = 지금 키). 개체 키·아종 키가 추가된다 | S |

**규격에 미치는 것**: `BattleSetup.enemyKeys` 는 그대로 쓸 수 있다. B3-01 이 미뤄 둔
`Enemy::ChangeAttribute` 판정이 B7-04 에서 자연히 풀린다 — cm2 가 능력치를 덮어쓰는 대신 **개체를 등록**한다.
