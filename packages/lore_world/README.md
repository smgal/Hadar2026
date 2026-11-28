# lore_world — 로어 3부작의 RPG 규칙

순수 Dart. Flutter 도 `dart:io` 도 시계도 화면도 한국어도 없다. 세 편 모두
**제3부 체계**로 굴리고, 편(`Episode`)은 자료만 가른다(1탄 전용 계급·무기, 시작
달력, 동료 명부).

정본은 `SMG_GameDesignVault/LORE_TRILOGY/GameDesign/` 의 기획서다 — 제7장(캐릭터),
제9장(마법·초능력의 필드 쪽), 제10장(아이템·장비·상점), 제11장(필드·시간), 부록 B(저장),
제4장(등장인물), `1st/07` · `2nd/07`(시스템 적용). 부록 A 의 **버그는 옮기지 않았다** —
본문의 의도를 구현했다.

```bash
dart pub get && dart analyze && dart test     # 355개
```

## 네 가지 약속

| | |
|---|---|
| **독립** | Dart 표준 라이브러리 `dart:math`와 `dart:collection`만 쓴다 |
| **던지지 않는다** | 모든 명령이 `Outcome` 을 돌려준다. 거절은 닫힌 열거 `RefusalReason` 이다 |
| **파생값은 저장하지 않는다** | 최대 HP·MP, 방어력, 무기 공격력, 방패 방어력, 무기 계통, 상태 표시는 읽을 때 계산한다 |
| **난수는 주입한다** | `Random` 을 만들지 않는다. 필요한 명령이 `rng` 를 받는다 |

`test/purity_test.dart` 가 넷을 지킨다(한국어·emoji·`print`·`DateTime.now`·`throw` 포함).

## 한눈에

```dart
final created = createCharacter(CreationInput(
  name: 'Hero', gender: Gender.male, answers: [1,1,1,1,1,1,1,1,1,1],
  agility: 14, accuracy: 13, luck: 13,
  skills: [25, 0, 5, 0, 20, 10], classId: ClassId.paladin,
));
final world = LoreWorld.newGame(Episode.ep3, created.member!);

world.join(rosterEp3['canopus']!.build());          // 1~4번 빈자리로
final out = world.train(0, TrainingFacility.military, FighterSkill.slash);
if (out.isRefused) show(out.refusal!.reason);        // notEnoughExp …
for (final e in world.rest(6, rng: rng).events) { /* RestMember, LevelUp … */ }

final save = world.toJson();                          // 'version': 1
final back = LoreWorld.load(save);                    // .world, .issues
```

## 공개 API

자리 번호(`seat`)는 언제나 0~5 — 0 주인공, 1~4 동료, 5 보조 일원(`Seat.*`).

### 결과 — `contract/`

| 타입 | 한 줄 |
|---|---|
| `Outcome` | 명령의 결과. `ok` · `isRefused` · `refusal` · `reason` · `events` · `of<T>()` · `first<T>()` · `has<T>()` · `mapAction` · `encounterStarted` · `gameOver` · `toJson()` |
| `Refusal` | `reason` + 문장에 필요한 `seat` · `key` · `amount`(모자라는 양) |
| `RefusalReason` | 거절 이유(아래 표) |
| `StepInput` | 걸음의 입력: `mapKind` · `terrain` · `encounters` |
| `LoreEvent` | 일어난 일(sealed). `kind` · `toJson()` (아래 표) |
| `RestResult` | `noFood` `dead` `regainedConsciousness` `stillUnconscious` `unconsciousAndPoisoned` `poisoned` `fullyRecovered` `healed` |
| `HarmCause` | `poison` `lava` `battle` `other` |
| `DamageResult` | `none` `hurt` `fellUnconscious` `deeperUnconscious` `died` `deeperDead` |

**`RefusalReason`** — 공통 `noSuchMember` `invalidSeat` `invalidAmount` `unknownItem` ·
생성 `emptyName` `nameTooLong` `invalidGender` `invalidAnswers` `invalidPointSplit`
`invalidSkillSplit` · 계급 `classRequirementNotMet` `classNotSelectable` `alreadyThatClass` ·
훈련 `notFighterFamily` `notMageFamily` `skillAtCap` `skillNotForClass` `notEnoughExp`
`espTrainingLocked` `notEnoughGoldForClassChange` · 돈과 한도 `notEnoughGold` `atLimit`
`notForSale` `wrongShop` · 장비 `notInBackpack` `slotOccupied` `classCannotUse`
`nothingEquipped` `backpackFull` · 병원·치료 `alreadyDead` `alreadyUnconscious`
`poisonSpreading` `noTreatmentNeeded` `targetNotCurable` `notPoisoned` `notUnconscious`
`notDead` `beyondRevival` · 물품 `noneOwned` `userCannotAct` `notMagicUser` `battleOnly` ·
마법 `casterCannotAct` `notMagicFamily` `spellLocked` `notEnoughMp` `espTooWeak` ·
일행 `partyFull` `cannotDismissProtagonist` · 걸음 `waterBlocked`.
기획서가 인용한 문구는 `outcome.dart` 의 각 값 주석에 있다.

**`LoreEvent`** —
`MemberJoined(seat)` · `AssistantSet(replaced, summoned)` · `MemberDismissed(seat, name, nameKey)` ·
`SeatsSwapped(a, b)` · `CompanionsHidden(seats, hidden)` ·
`SkillTrained(seat, skill, value, cost)` · `AllCoursesCompleted(seat, expMoved)` ·
`ClassChanged(seat, from, to)` · `ExpTrained(seats, expEach, hours)` · `ExpGained(seat, amount)` ·
`GoldGained(amount)` · `LevelUp(seat, level)` · `AbilityRaised(seat, ability, value)` ·
`Equipped` / `Unequipped` / `EquipmentDiscarded(seat, slot, key)` · `Purchased(key, count, cost)` ·
`HospitalTreated(seat, treatment, fee)` · `ItemUsed(key, remaining, consumed)` ·
`SpellCast(seat, key, mpSpent)` · `HpRestored(seat, amount, full)` · `MpRestored(seat, amount)` ·
`PoisonCured(seat)` · `Awakened(seat)` · `Revived(seat)` · `NoEffect(seat, reason)` ·
`TorchChanged(value, delta)` · `BuffsGranted(buffs)` · `BuffsExpired(buffs)` ·
`FoodCreated(added, total)` · `MindReadingStarted(steps)` · `MindReadingEnded()` ·
`MapActionNeeded(action, distance, seat)` · `StoryCrystalUsed(key)` ·
`RestMember(seat, result, amount, foodUsed)` · `MemberHarmed(seat, amount, result, cause)` ·
`EnteredSwamp(protected)` · `MemberPoisoned(seat)` · `EnteredLava()` ·
`EncounterStarted(enemyCount)` · `GameOver()`.

### 닫힌 열거 — `domain/enums.dart`

| 타입 | 값 |
|---|---|
| `Episode` | `ep1` `ep2` `ep3` (`number` 1·2·3, `fromNumber`) |
| `Gender` | `male` 0 · `female` 1 · `neutral` 2 (`wire`) |
| `Family` | `fighter` 0 · `mage` 1 · `elemental` 2 · `giant` 3 · `golem` 4 · `dragon` 5 · `unknown` 6 (`wire`) |
| `Ability` | `strength` `mentality` `concentration` `endurance` `resistance` `agility` `accuracy` `luck` (`index8` 0~7) |
| `WeaponKind` | `bare` `slash` `chop` `pierce` `shoot` `special` |
| `Condition` | `good` `poisoned` `unconscious` `dead` |
| `AttackMode` | `single` `all` |
| `EquipSlot` | `weapon` `shield` `armour` |
| `MapKind` | `town` `field` `cave` `fortress` |
| `Terrain` | `normal` `water` `swamp` `lava` `event` |
| `Treatment` | `wounds` `poison` `consciousness` `revival` |
| `TrainingFacility` | `military` `magicSchool` |
| `ShopKind` | `herb` `goods` |
| `FieldEsp` | `clairvoyance` `prophecy` `mindReading` `farSight` `telekinesis` |
| `FieldBuff` | `levitation` `waterWalk` `swampWalk` |
| `MapAction` | `showMap` `etherealMove` `terraform` `greatTerraform` `teleport` `revealHidden` `prophecy` `farSight` |
| `Seat` | 상수 `protagonist` 0 · `firstCompanion` 1 · `lastCompanion` 4 · `assistant` 5 · `count` 6, `isValid` `isCompanion` |

### `Member` — `domain/member.dart`

저장하는 필드: `name` · `nameKey` · `rosterKey` · `gender` · `family` · `classId` · `level` ·
`abilities`(8) · `skills`(6) · `hp` · `mp` · `exp`(쓰지 않은 경험치) · `trainedExp`(누적 수련치) ·
`poison` · `unconscious` · `dead` · `weapon` · `shield` · `armour` · `baseAc` · `acPenalty` ·
`naturalWeapon` · `naturalPower` · `attackModeOverride` · `mindControlImmune` · `hidden`.

| 읽을 때 계산 | 식 |
|---|---|
| `maxHp` | 인내력 × 레벨 × 10 |
| `maxMp` | 마법사 정신력 × 레벨 × 10 · 전사 × 5 · 그 외 전투사 0 (계급 없는 보조 일원 × 10) |
| `ac` | `baseAc` + `armourPower` − `acPenalty` (0 이상) |
| `armourPower` | 갑옷 방어력. 계급이 못 입는 갑옷은 0 |
| `weaponPower` | 계급별 표. 맨손·쓸 수 없는 무기 5. `naturalPower` 가 있으면 그 값 |
| `shieldPower` | 방패 번호 1~5. 쓸 수 없으면 0 |
| `weaponKind` | 타고난 무기 `special`, 쓸 수 없는 무기 `bare` |
| `attackMode` | 마법사·고렘·정령 `all`, 나머지 `single`(덮어쓰기 가능) |
| `canAct` | 의식불명 0 · 죽음 0 · HP > 0 |
| `condition` | 죽음 > 의식불명 > 중독 > 좋음 |
| `unconsciousLimit` | 인내력 × 레벨 — 넘으면 죽는다 |
| `cureSkill` · `canUseCureMagic` · `hasMagicPool` · `classDef` | 계급에서 |

그 밖에 `ability(a)` / `setAbility(a, v)` 와 여덟 getter, `isDead` `isUnconscious`
`isPoisoned` `isPaladin` `isDemigod` `isFighterFamily` `isMageFamily`.
상태를 한 단계 바꾸는 기본 동작: `takeDamage(amount, {deadCap})` → `DamageResult` ·
`healHp(n)` · `restoreMp(n)` · `curePoison()` · `awaken()` · `revive()`.
`copy()` · `toJson()` · `Member.fromJson(map)`.

### `LoreWorld` — `model/world.dart`

`LoreWorld({required episode, …})` · `LoreWorld.newGame(episode, protagonist)`.

상태: `episode` · `seats`(6) · `gold` · `food` · `arrows` · `consumables` · `crystals` ·
`backpack`(장착 중인 것은 없다) · `calendar` · `torch` · `buffs` · `options` ·
`espTrainingUnlocked` · `specialMagicUnlocked`.

`seats`와 인벤토리 맵은 최신 값을 보여 주는 읽기 전용 컬렉션이다. 자리 변경은 일행 명령을 쓴다.
대본에서 보조 일원을 내보낼 때는 `removeAssistant()`를 쓴다.

| 읽기 | |
|---|---|
| `member(seat)` | 그 자리에 **지금 있는** 대원(비었거나 숨겨졌으면 null) |
| `protagonist` · `assistant` | 0번 · 5번 |
| `presentSeats` · `presentMembers` | 지금 있는 대원 |
| `commandSeats` | 0~4 중 행동 가능한 자리 |
| `firstFreeCompanionSeat` | 1~4 빈자리 중 가장 앞 |
| `seatOfRoster(key, {includeHidden})` · `hasRosterMember(key, {includeHidden})` | 「카노푸스가 일행에 있는가」 |
| `isGameOver` | 여섯 자리 전원이 행동 불가 |
| `average(Ability)` · `averageCommandLevel` | 도망·선제용 평균, 소환 문서의 레벨 |
| `countOf(key)` · `limitOf(key)` | 소지 개수 · 한도 |

규칙 없는 변화: `give(key, [n])`(실제로 늘어난 개수) · `take(key, [n])` ·
`giveLegacy(kind, legacyId, [n])` · `LoreWorld.legacyKey(kind, legacyId)` · `addGold` ·
`addFood` · `addArrows` · `setTorch`.

저장: `toJson()` · `LoreWorld.fromJson(map)` · `LoreWorld.load(source)` → `LoadResult(world, issues)` ·
`copy()`. `LoadIssue(kind, seat, key)`, `LoadIssueKind` = `notAMap` `newerVersion`
`unknownEpisode` `unknownItem` `unknownEquipment`. `loreSaveVersion` = 1.

`LoreCalendar`(`year` `month` `day` `hour` `minute` `second`, `startOf(episode)`, `advance`,
`setTo`, `isAfter`, `dayOfYear`, `isDaytime`, `moonIsUp`) · `FieldBuffs`(`levitation`
`waterWalk` `swampWalk` `mindReadSteps`, `has` `grant` `expireOnRest`) · `GameOptions`
(`encounterTendency` 1~5 · `maxEnemies` 3~8 · `attackUnconscious` · `restHours`).

### 명령 — `LoreWorld` 의 확장 메서드, 전부 `Outcome`

| 명령 | 하는 일 |
|---|---|
| **캐릭터 생성** (`rules/creation.dart`, 최상위 함수) | |
| `createCharacter(CreationInput)` → `CreationResult(refusal, member, preview)` | 답 10 + 성별 + 40점 + 기술치 60 + 계급 → `Member` |
| `previewCreation({answers, gender})` → `CreationPreview?` | 점수·능력치·계열·HP·MP |
| `scoreAnswers` · `decideFamily` · `applyGenderBonus` · `eligibleClassIds(family, skills)` · `pickQuestionVariants(rng)` · `nameWidth` | 낱개 규칙. `questionAbilities` · `scoreToAbility` 가 표 |
| **훈련** (`TrainingRules`) | |
| `visitSchool(seat, facility)` | 모든 분야가 상한이면 경험치 전부를 누적 수련치로 |
| `train(seat, facility, skill)` | 기술치 +1, 비용 15·10 × 기술치² |
| `trainingOptions(seat)` → `List<TrainingOption>` · `allCoursesCompleted(seat)` · `facilityFor(seat)` | 화면용 |
| `changeClass(seat, facility, classId)` · `classChangeOptions(seat)` | 전직(금 10000, 같은 계열) |
| `buyExpTraining(units)` | 금 1만 → 경험치 1만 + 1시간 (1~10) |
| `promoteAllToDemigod()` | 제1부: 일행 전원을 반신반인으로 |
| **장비** (`EquipmentRules`) | |
| `equip(seat, key)` · `checkEquip(seat, key)` · `checkUsable(member, key)` | 배낭 → 장착. 판정은 한 곳 |
| `unequip(seat, slot)` · `discardEquipped(seat, slot)` · `equippedIn(seat, slot)` | 해제 · 버림 |
| **상점** (`ShopRules`) | |
| `buyFood(packs)` 1~5 · `buyArrows(packs)` 1~10 · `buyEquipment(key)` · `buyConsumable(key, count, {shop})` 1~10 | |
| `isForSale(key)` · `priceOf(key)` | 그 편에서 파는가 · 값 |
| **병원** (`HospitalRules`) | |
| `hospitalTreat(seat, treatment)` · `hospitalFee(seat, treatment)` · `checkTreatment(member, t)` · `treatmentFee(member, t)` | 네 가지 치료 |
| **물품·크리스탈** (`ItemRules`) | |
| `useConsumable(key, {required user, target, distance, required rng})` | 물품 10종 |
| `consumableWouldBeWasted(key, {user, target})` | 쓰면 헛되이 사라지는가(확인 절차용) |
| `useCrystal(key, {required rng})` | 소환 · 에너지 · 이야기 크리스탈 |
| `hasBuff(buff)` · `isMindReading` · `startMindReading()` | |
| **필드 마법** (`MagicRules`) | |
| `castCure(caster, spell, {target})` · `availableCureSpells(seat)` | 치료 1~10 |
| `castChange(caster, spell, {distance})` · `checkChange(…)` · `availableChangeSpells(seat)` | 변화 1~10 |
| `castFieldEsp(caster, power)` · `checkFieldEsp(…)` · `fieldEspMp(member, power)` · `anyoneHasEsp(min)` | 투시 · 예언 · 독심 · 천리안 |
| **필드** (`FieldRules`) | |
| `rest(hours, {required rng, notAfter})` | 휴식 → 회복 · 횃불 · 효과 해제 · MP · **레벨업** · 시간 |
| `step(StepInput, {required rng})` | 한 걸음 → 중독 · 늪 · 용암 · 독심 · 조우 · 시간 |
| `sight(mapKind, {darknessZone})` → `Sight(radius, dimBeyond)` · `nightRadius(h, m)` | 시야 |
| **일행** (`PartyRules`) | |
| `join(member)` · `setAssistant(member, {summoned})` · `replace(seat, member)` | 합류 · 보조 일원 · 교체 |
| `dismiss(seat)` · `swapSeats(a, b)` · `hideCompanions()` · `restoreCompanions()` | |
| `assistantFromEnemy(EnemyStatBlock)` → `Member` | 적 → 보조 일원(7.8 의 표) |
| `settleBattle(BattleSettlement)` · `grantExp(amount, {to})` · `harm(seat, amount, {cause, deadCap})` | 전투 정산 · 보상 · 함정 |

### 이름으로 읽고 쓰기 — `rules/attributes.dart`

맵 스크립트가 쓰는 문이다.

```dart
int? readAttribute(Member member, String name);              // 모르는 이름이면 null
bool writeAttribute(Member member, String name, int value);  // 모르는 이름이면 false
void reviseMember(Member member, {bool fill = false});       // 여러 칸을 쓴 뒤의 정리
const List<String> memberAttributeNames;
```

이름: `strength` `mentality` `concentration` `endurance` `resistance` `agility` `accuracy`
`luck` `level` `hp` `mp` `exp` `poison` `unconscious` `dead` `class` `family` `gender` `ac`
`skill1`~`skill6`, 그리고 `trainedexp`(읽기·쓰기) · `maxhp` · `maxmp`(읽기만). 대소문자를
가리지 않는다.

- `class` 는 계급 번호, `family` · `gender` 는 `wire` 번호(없는 번호는 false).
- `ac` 는 파생값이다. 읽으면 계산된 방어력, **쓰면 `baseAc` 를 고쳐** 그 값이 되게 한다.
- **한 칸만 쓴다.** 다른 칸을 따라 고치지 않으므로 쓰는 순서가 상관없다. 다 쓴 뒤
  `reviseMember` 가 HP·MP 를 최대치 안으로 넣는다.
- 음수는 0(레벨은 1)으로, `skillN` 은 100 에서 멈춘다.

### 자료 — `data/`

| | |
|---|---|
| 계급 | `ClassId` · `FighterSkill` · `MageSkill` · `ClassDef` · `classTable` · `classOf(family, id)` · `selectableClasses` · `eligibleClasses` · `skillKey(family, classId, index)` · `fighterSkillKeys` · `mageSkillKeys` |
| 레벨 | `levelTable`(40) · `maxLevel` · `trainedExpForLevel` · `levelForTrainedExp` · `trainingCost` |
| 장비 | `WeaponDef` · `ShieldDef` · `ArmourDef` · `weaponTable` · `shieldTable` · `armourTable` · `…ByKey` · `…ByLegacyId` · `equipSlotOf` · `equipmentPrice` · `allEquipmentKeys` · `barePower` 5 · `stackLimit` 255 |
| 물품 | `ConsumableDef` · `ItemKey` · `consumableTable` · `CrystalDef` · `CrystalKey` · `crystalTable` · `SupplyKey` · `foodLimit` 255 · `arrowLimit` 65535 · `classChangeFee` · `expTrainingUnit` |
| 마법 | `SpellSchool` · `SpellDef` · `spellTable` · `spellByKey` · `spellAt(school, tier)` · `spellsOf` · `unlockedTiers` · `attackMagicMp` · `attackMagicDamage` · `summonMagicMp` · `summonLevel` · `telekinesisChoices` · `fieldEspKey` |
| 소환 | `Roll` · `SummonDef` · `summonPools`(10단계) · `otherDimensionCreatures` · `crystalDragon` · `crystalGolem` · `archangel` · `rollCrystalSummonOnField` · `rollCrystalSummonInBattle` · `buildSummon` · `summonByTier` |
| 명부 | `RosterEntry(key, episode, seat).build()` · `RosterSeat` · `rosterEp3` · `rosterEp1` · `rosterEp2` · `rosterOf(episode)` · `initialCompanionsEp1` |

## 열쇠 목록

원작의 1 부터 세는 번호는 `legacyId` 다(표의 순서 그대로). `LoreWorld.legacyKey('weapon', 6)`.

**무기 1~28** — 베는: `weapon.short_sword`(단검) `weapon.gladius` `weapon.sabre`
`weapon.scimitar`(신월도) `weapon.falchion`(인월도) `weapon.long_sword` `weapon.flamberge` ·
찍는: `weapon.club` `weapon.hand_axe` `weapon.flail` `weapon.war_hammer` `weapon.mace`(철퇴)
`weapon.battle_axe` `weapon.halberd` · 찌르는: `weapon.dagger`(단도) `weapon.lance`(기병창)
`weapon.short_spear` `weapon.rapier` `weapon.trident` `weapon.lancer`(랜서) `weapon.poleaxe`(도끼창) ·
쏘는: `weapon.blowpipe` `weapon.shuriken`(표창) `weapon.sling` `weapon.javelin` `weapon.bow`
`weapon.crossbow` `weapon.arbalest` · **29** `weapon.flame_sword`(제1부 전용).

**방패 1~5** — `shield.leather` `shield.small_steel` `shield.large_steel` `shield.chromatic`
`shield.platinum`.

**갑옷 1~11** — `armour.leather` `armour.ring_mail` `armour.chain_mail` `armour.scale`(미늘)
`armour.brigandine` `armour.cuir_bouilli` `armour.lamellar` `armour.plate` `armour.chromatic`
`armour.platinum` `armour.obsidian`(팔지 않는다).

**물품 1~10** — `item.hp_potion` `item.mp_potion` `item.antidote_herb` `item.awakening_herb`
`item.revival_herb` `item.summon_scroll` `item.big_torch` `item.seeing_orb` `item.flying_boots`
`item.warp_orb`.

**크리스탈 1~9** — `crystal.flame` `crystal.frost` `crystal.dark` `crystal.ebony`
`crystal.spirit` `crystal.summon` `crystal.energy` `crystal.chromatic` `crystal.ball`.

**물자** — `supply.gold` `supply.food` `supply.arrows`.

**계급** — `class.fighter` `class.knight` `class.swordsman` `class.hunter` `class.monk`
`class.assassin` `class.paladin` · `class.mage` `class.conjurer` `class.sorcerer` `class.wizard`
`class.necromancer` `class.archmage` `class.timewalker` · `class.esper`(8) `class.demigod`(9).

**기술치** — `skill.slash` `skill.chop` `skill.pierce` `skill.shoot` `skill.shield` `skill.bare` ·
`skill.attack` `skill.change` `skill.cure` `skill.special` `skill.esp` `skill.summon`.

**마법** — `magic.<이름>` 61개, `esp.<이름>` 9개(`spell_table.dart`). 변화 1~10:
`magic.magic_torch` `magic.beholder_eye` `magic.levitation` `magic.water_walk`
`magic.swamp_walk` `magic.ethereal_move` `magic.terraform` `magic.teleport`
`magic.create_food` `magic.great_terraform`. 치료 1~10: `magic.heal_one` `magic.antidote_one`
`magic.awaken_one` `magic.revive_one` `magic.full_cure_one` 와 `…_all`. 필드 초능력:
`esp.clairvoyance` `esp.prophecy` `esp.mind_reading` `esp.far_sight`.

**명부** (`Member.rosterKey`, 이름표는 `companion.<key>`)

| 편 | 동료 | 보조 일원 |
|---|---|---|
| 제3부 `rosterEp3` | `canopus` `alcor` `mizar` `antares_jr` `pollux` `altair` `vega` `algol` `proxima` `denebola` `capella` `becrux` | `draco_prisoner` |
| 제1부 `rosterEp1` | 초기 10: `hercules` `titan` `merlin` `betelgeuse` `genius_kie` `bellatrix` `regulus` `procyon` `arcturus` `algol` · 합류 5: `polaris` `rigel` `lore_hunter` `red_antares` `spica` | `mad_joe` `skeleton` `draconian` |
| 제2부 `rosterEp2` | `hercules` `titan` `merlin` `betelgeuse` `mercury` `polaris` `genius_kie` `regulus` | `mad_joe` `death_knight` |

**소환수** — `summon.<이름>` 과 타고난 무기 `natural.<이름>` · `breath.<이름>` 은
`lore_battle` 의 소환 표와 **같은 철자**다(`natural.fangs` `natural.claws` `natural.bare_hands`
`breath.frost` … 설득한 적은 `natural.attack`). 이쪽에만 있는 것은 `summon.archangel` 하나다.

## 지도가 필요한 마법의 순서

이 패키지는 자격·MP·일행 공용 효과까지만 정하고 **무엇을 할지**를 `MapActionNeeded` 로
알린다.

1. 앱이 `checkChange` / `checkFieldEsp` 로 쓸 수 있는지 본다(바뀌는 것 없음).
2. 앱이 그 맵의 제한을 본다. 막힌 맵이면 여기서 그만 — MP 가 줄지 않는다.
3. 앱이 `castChange` / `castFieldEsp` 를 부른다. **MP 가 빠진다.**
4. 앱이 지도에서 실행한다. 특수 칸에 막혀 실패해도 MP 는 돌아오지 않는다(제9장 9.3).

수정 구슬·이동 구슬도 같다 — `useConsumable` 을 부르면 물품은 이미 쓰였다.

## 여기 없는 것

- **한국어** — `lore_world_text` 가 열쇠와 `LoreEvent` · `RefusalReason` 을 문장으로 바꾼다.
- **지도 · 플래그 · 위치 · 예약 시간 이벤트** — 앱과 스크립트의 것이다. 암흑 구역은
  `sight(…, darknessZone:)` 의 입력이고, 휴식이 예약 시각을 넘지 않게 하려면 `rest(…, notAfter:)`.
- **성마다 어느 시설이 있는가** — 콘텐츠다.
- **전투** — `lore_battle`. 전투 뒤에 `settleBattle` 로 되돌려 쓴다.
- **능력치를 올리는 이벤트**(7.9)와 제2부 석상의 능력치 판매(가격표 포함) — 명령으로 두지
  않았다. 스크립트가 `writeAttribute` 로 쓴다.

## 정한 것 (기획서가 열어 둔 곳)

「제안」은 받아들였고, 「결정 필요」와 기획서가 말하지 않는 곳은 가장 보수적인 쪽을 골랐다.

| # | 항목 | 고른 것 |
|--:|---|---|
| 1 | 소환 마법의 MP(부록 A D1) | 제안대로 공격 마법과 같은 식 — 능력치 × j² ÷ 10 (`summonMagicMp`) |
| 2 | 안타레스 Jr.의 링 메일 | 원작 데이터 그대로 입고 온다. 마법사 계열이라 방어 효과 0 |
| 3 | 효과 없는 물품(10.5 · 부록 A #23) | 기획서가 문구를 정한 실패(마법사 계열이 아니다 · 이미 죽었다)와 죽음 수치 10000 이상의 부활은 **거절, 물품 유지**. 그 밖에 효과만 없는 경우는 원작대로 쓰이고 `NoEffect`. 화면이 먼저 `consumableWouldBeWasted` 로 묻는다 |
| 4 | 한도를 넘는 구입 | 이미 한도면 `atLimit`. 넘게 청하면 들어가는 만큼만 주고 **그만큼만 받는다** |
| 5 | 같은 계급으로의 전직 | 거절(`alreadyThatClass`) — 금 10000 을 헛되이 쓰지 않게 |
| 6 | 공중 부상·물 위·늪 위가 켜질 때의 값 | 255. 부록 B 의 범위 끝이고 원작 이식본이 쓰는 값 |
| 7 | 갑옷 파괴로 깎인 방어력 | `acPenalty` 에 쌓고, 갑옷을 갈아입거나 전직하면 0 (원작의 「다시 계산」) |
| 8 | 병원 상처 치료비의 반올림 | 반은 올린다 |
| 9 | 늪의 중독 | 지금 있는 대원 전원이 굴린다(죽은 사람도). 이미 중독이면 수치를 건드리지 않는다 |
| 10 | 배낭이 255 일 때의 해제 | 거절(`backpackFull`) — 장비가 사라지지 않게 |
| 11 | 내보낸 대원의 장비 | 함께 떠난다 |
| 12 | 자리 교환 | 두 자리 모두 사람이 있어야 한다 |
| 13 | 이벤트 칸·늪·용암으로의 걸음(11.4) | 원작대로 시간·조우 없음 |
| 14 | 물 위 걷기 · 조우 확률 · 용암 피해 | 세 편 모두 제3부 값(물에서 수치가 줄지 않는다, 1/(20×성향), ×10) |
| 15 | 지하 묘의 보조 일원(부록 A D15) | 원작대로 `hideCompanions` 는 1~4번만 숨긴다 |
| 16 | 식량 없이 쉬었을 때 | 회복만 없다. 횃불·효과 해제·MP·레벨업·시간은 그대로 |
| 17 | 에너지 크리스탈 | 산 사람은 의식 회복 + HP 최대(중독은 그대로), 죽은 사람은 HP 1 로 깨어난 채 부활 |
| 18 | 이름의 길이 | 폭 8 까지(한글 한 자 2, 영문 한 자 1) |
| 19 | 보조 일원의 레벨업 | 다른 대원처럼 휴식 때 판정한다. 누적 수련치는 합류 레벨의 필요치 |
| 20 | 에인션트 메이지의 MP | 나타날 때 정신력 × 레벨(9.7). 최대치는 마법사 식(× 10)이라 쉬면 더 찬다 |
| 21 | 제1부 초능력·특수 마법 해금(1st/07 7.4) | 제안대로 `espTrainingUnlocked`(초자연력 수련 잠금) · `specialMagicUnlocked`. 스크립트가 켠다 |
| 22 | **에스퍼**(1탄 전용) | 마법사 계열 8번. 고를 수 없고, 상한 50/50/50/50/100/0(마법은 초능력의 절반, 소환 없음). 레벨이 오를 때 `rand(20) < 행운` 이면 집중력 → 정확성 → 정신력 순으로 20 미만인 첫 능력치 +1. **「행운 판정」의 식은 기획서에 없다** |
| 23 | **반신반인**(1탄 전용) | 9번. 계열은 그대로, 상한 전부 100. 레벨이 오를 때마다 저항·행운을 뺀 여섯 능력치 +1(최대 20). 전투사 계열은 투사의 무기 열과 모든 장비, MP 는 두 계열 모두 × 10. **전투사 계열 반신반인은 마법 기술치가 없어 필드 마법을 쓰지 못한다** — 원작의 「마법·초능력 레벨 = 전투 레벨」을 기술치로 옮기는 규칙이 기획서에 없다 |
| 24 | **화염검**(1탄 전용) | 원작 값 그대로: 100,000 · 공격력 50(모든 계급) · 베는 무기 · 번호 29 · 제1부 상점에서만. 제3부 척도에서는 장검(60~70)보다 약하다 |
| 25 | 특수 마법 「독」(1탄 전용) | `magic.poison` 이름만 싣는다. 해금 기준·소모량이 기획서에 없다 |
| 26 | 제1부 합류 인물의 옮김 | 능력치·레벨·장비는 원작 그대로, 기술치는 계급 조건의 최소값, 기본 방어는 전투사 2 · 마법사 0, 합류 때 MP 0. 정확성 셋 중 그 계급이 주로 쓰는 것(전투사 무기 · 마법사 마법 · 에스퍼 초능력)을 쓴다. **리겔·로어 헌터는 사냥꾼이라 원작 장비 중 장검·방패가 효과가 없다**(로어 헌터의 철퇴는 된다) |
| 27 | 스피카의 기술치 | 원작 초능력 레벨 11 · 마법 레벨 6 을 레벨 × 5 로: 초자연 55, 공격·변화·치료 30 |
| 28 | 미친 조(제1부) | 제2부와 같이 계열 불명의 보조 일원 |
| 29 | `writeAttribute` | 한 칸만 쓰고 최대치에 맞추지 않는다(원작 스크립트의 「여러 줄 쓰고 한 번 정리」). `ac` 는 `baseAc` 를 고친다 |

제3부 동료 셋(카노푸스·미자르·프록시마)은 **원작 데이터의 기술치가 자기 계급의 조건에 못
미친다.** 고치지 않았고 `test/roster_test.dart` 가 이름을 남긴다.
