import '../data/enemy_data.dart';
import '../rules/affinity.dart';
import '../rules/preset.dart';
import 'battle_result_code.dart';
import 'vocabulary.dart';

/// The handover contract's version. `packages/lore_battle/CONTRACT.md`
/// is the document.
///
/// A fork of `hd_battle`'s v4, so it starts its own count: the skeleton
/// is that contract's, the content is the Lore trilogy's Part 3 system.
const String contractVersion = 'lore-1';

/// One party member as the battle sees them — **a Part 3 character**.
///
/// A snapshot taken when the battle starts. The battle never reaches
/// back into the RPG's own party object; everything it needs is copied
/// in here, and everything it changes comes back through
/// [BattleOutcome].
///
/// Derived values arrive already resolved — [ac] is base armour plus
/// what is worn, [weaponPower] is the wielded weapon's attack power
/// **for this class** (ch.10.2), [maxMp] is whatever the family's
/// formula gives. The battle knows no item table.
///
/// There is no `experience`: the level is an input and the experience
/// earned is an output. Levelling is the RPG's job, and in this system
/// it does not even follow from experience directly (ch.7.6).
class CombatantSnapshot {
  const CombatantSnapshot({
    required this.slot,
    required this.name,
    this.nameKey = '',
    this.family = Family.fighter,
    this.classId = ClassId.fighter,
    this.level = 1,
    this.strength = 0,
    this.mentality = 0,
    this.concentration = 0,
    this.endurance = 0,
    this.resistance = 0,
    this.agility = 0,
    this.accuracy = 0,
    this.luck = 0,
    this.skills = const <int>[0, 0, 0, 0, 0, 0],
    required this.hp,
    required this.maxHp,
    this.mp = 0,
    this.maxMp = 0,
    this.ac = 0,
    this.weaponPower = 5,
    this.weaponKind = WeaponKind.bare,
    this.shieldPower = 0,
    this.poison = 0,
    this.unconscious = 0,
    this.dead = 0,
    int? rank,
    this.weaponKey = 'unarmed',
    this.weaponName = '',
    this.weaponNameKey = '',
    bool? attacksAll,
    this.immuneToMindControl = false,
    this.weakTo = const <Element>{},
    this.dodgesBack = false,
    this.preset = PresetKind.aggressive,
    this.knownPresets = const <PresetKind>{},
  }) : rank = rank ?? (slot < 2 ? 1 : (slot < 4 ? 2 : 3)),
       attacksAll =
           attacksAll ??
           (family == Family.mage ||
               family == Family.golem ||
               family == Family.elemental);

  /// Party seat, 0..5. **This is the key that joins the two worlds** —
  /// [BattleOutcome] reports under the same value. Seat 5 is the
  /// assistant member ([assistantSeat]).
  final int slot;

  /// Display name, carried for the view. No rule reads it.
  ///
  /// May be empty when [nameKey] is set: an assistant the battle itself
  /// created (a summon, a persuaded enemy) has no name the model could
  /// write — the model holds no Korean — so it carries a key and the
  /// text package resolves it.
  final String name;

  /// A name the text package resolves, e.g. `summon.ifrit` or
  /// `enemy.3.orc_soldier`. Empty for ordinary members.
  final String nameKey;

  final Family family;

  /// Only meaningful next to [family] — see [ClassId].
  final int classId;

  /// One level. Part 3 has no physical/magic/ESP split.
  final int level;

  final int strength; // 체력
  final int mentality; // 정신력
  final int concentration; // 집중력
  final int endurance; // 인내력
  final int resistance; // 저항력
  final int agility; // 민첩성
  final int accuracy; // 정확성
  final int luck; // 행운

  /// Six skill values, 0..100, indexed by [SkillIndex]. What each slot
  /// means depends on [family].
  final List<int> skills;

  final int hp;
  final int maxHp;

  /// The one magic pool. Magic and ESP both spend from it.
  final int mp;
  final int maxMp;

  /// Armour class — base plus worn, already summed.
  final int ac;

  /// Attack power of the wielded weapon; 5 for bare hands. For an
  /// assistant, its natural weapon's power.
  final int weaponPower;

  /// Which skill the weapon is measured by.
  final WeaponKind weaponKind;

  /// The shield's number, 1..5; 0 for none or unusable.
  final int shieldPower;

  /// Status counters at the start, cumulative as in ch.7.7.
  final int poison;
  final int unconscious;
  final int dead;

  /// Which rank they stand in, 1 (front) to 3 (back). Left unset it
  /// falls out of the seat — 0-1 front, 2-3 middle, 4-5 back.
  final int rank;

  /// Which row of the battle's weapon table this is — **how the weapon
  /// reaches**, where [weaponPower] says how hard it hits. Unknown keys
  /// fall back to bare hands.
  final String weaponKey;

  /// Display name of the weapon. No rule reads it. Hand over the
  /// resolved name — the menu reads "attack with {this}".
  final String weaponName;

  /// The weapon's name as a key, for an assistant the battle created
  /// (`natural.flame`). Same reason as [nameKey].
  final String weaponNameKey;

  /// Whether the assistant's automatic attack sweeps every enemy
  /// (ch.8.5). Derived from [family] when left out — mages, golems and
  /// elementals sweep — but **the fire spirit is an elemental that does
  /// not**, which is why this is a field and not a getter.
  final bool attacksAll;

  /// Crystal creatures and the Archangel cannot be taken by 정신 지배.
  final bool immuneToMindControl;

  /// What this member is unusually vulnerable to. Empty for most; the
  /// enemy drives them back through it the way the party drives enemies
  /// back.
  final Set<Element> weakTo;

  /// Gives ground rather than take a finishing blow, while there is a
  /// rank behind to fall into.
  final bool dodgesBack;

  /// The standing orders this member runs when the leader hands the
  /// round over, and the ones they have learned.
  final PresetKind preset;
  final Set<PresetKind> knownPresets;

  bool get isAssistant => slot == assistantSeat;

  /// The paladin — a fighter who casts cures (ch.7.3).
  bool get isPaladin => family == Family.fighter && classId == ClassId.paladin;

  /// Monks and assassins hit with a fixed coefficient instead of the
  /// weapon's power (ch.8.5).
  bool get usesFixedCoefficient =>
      family == Family.fighter &&
      (classId == ClassId.monk || classId == ClassId.assassin);

  /// Whether the mage family's skill list applies. Part 1's two special
  /// classes cast as mages do.
  bool get isCaster =>
      family == Family.mage ||
      classId == ClassId.esper ||
      classId == ClassId.demigod;

  int _skill(int index) =>
      (index >= 0 && index < skills.length) ? skills[index] : 0;

  /// The skill value the wielded weapon is measured by (ch.8.5 step 4).
  int get weaponSkill => switch (weaponKind) {
    WeaponKind.bare => _skill(SkillIndex.bare),
    WeaponKind.slash => _skill(SkillIndex.slash),
    WeaponKind.chop => _skill(SkillIndex.chop),
    WeaponKind.pierce => _skill(SkillIndex.pierce),
    WeaponKind.shoot => _skill(SkillIndex.shoot),
    WeaponKind.special => level * 5,
  };

  int get attackSkill => isCaster ? _skill(SkillIndex.attack) : 0;
  int get specialSkill => isCaster ? _skill(SkillIndex.special) : 0;
  int get espSkill => isCaster ? _skill(SkillIndex.esp) : 0;
  int get summonSkill => isCaster ? _skill(SkillIndex.summon) : 0;

  /// The paladin reads its second slot here (ch.7.3).
  int get cureSkill => isCaster
      ? _skill(SkillIndex.cure)
      : (isPaladin ? _skill(SkillIndex.paladinCure) : 0);

  int get shieldSkill =>
      family == Family.fighter ? _skill(SkillIndex.shield) : 0;

  /// Whether they hold magic points at all — what the magic potion
  /// checks (ch.10.5).
  bool get holdsMagic => isCaster || isPaladin;

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'name': name,
    'nameKey': nameKey,
    'family': family.name,
    'classId': classId,
    'level': level,
    'strength': strength,
    'mentality': mentality,
    'concentration': concentration,
    'endurance': endurance,
    'resistance': resistance,
    'agility': agility,
    'accuracy': accuracy,
    'luck': luck,
    'skills': skills,
    'hp': hp,
    'maxHp': maxHp,
    'mp': mp,
    'maxMp': maxMp,
    'ac': ac,
    'weaponPower': weaponPower,
    'weaponKind': weaponKind.name,
    'shieldPower': shieldPower,
    'poison': poison,
    'unconscious': unconscious,
    'dead': dead,
    'rank': rank,
    'weaponKey': weaponKey,
    'weaponName': weaponName,
    'weaponNameKey': weaponNameKey,
    'attacksAll': attacksAll,
    'immuneToMindControl': immuneToMindControl,
    'weakTo': [for (final e in weakTo) e.name],
    'dodgesBack': dodgesBack,
    'preset': preset.name,
    'knownPresets': [for (final p in knownPresets) p.name],
  };

  factory CombatantSnapshot.fromJson(Map<String, dynamic> j) =>
      CombatantSnapshot(
        slot: j['slot'] as int,
        name: j['name'] as String? ?? '',
        nameKey: j['nameKey'] as String? ?? '',
        family: Family.values.firstWhere(
          (f) => f.name == j['family'],
          orElse: () => Family.fighter,
        ),
        classId: j['classId'] as int? ?? ClassId.fighter,
        level: j['level'] as int? ?? 1,
        strength: j['strength'] as int? ?? 0,
        mentality: j['mentality'] as int? ?? 0,
        concentration: j['concentration'] as int? ?? 0,
        endurance: j['endurance'] as int? ?? 0,
        resistance: j['resistance'] as int? ?? 0,
        agility: j['agility'] as int? ?? 0,
        accuracy: j['accuracy'] as int? ?? 0,
        luck: j['luck'] as int? ?? 0,
        skills: [for (final s in (j['skills'] as List? ?? const [])) s as int],
        hp: j['hp'] as int? ?? 0,
        maxHp: j['maxHp'] as int? ?? 0,
        mp: j['mp'] as int? ?? 0,
        maxMp: j['maxMp'] as int? ?? 0,
        ac: j['ac'] as int? ?? 0,
        weaponPower: j['weaponPower'] as int? ?? 5,
        weaponKind: WeaponKind.values.firstWhere(
          (k) => k.name == j['weaponKind'],
          orElse: () => WeaponKind.bare,
        ),
        shieldPower: j['shieldPower'] as int? ?? 0,
        poison: j['poison'] as int? ?? 0,
        unconscious: j['unconscious'] as int? ?? 0,
        dead: j['dead'] as int? ?? 0,
        rank: j['rank'] as int?,
        weaponKey: j['weaponKey'] as String? ?? 'unarmed',
        weaponName: j['weaponName'] as String? ?? '',
        weaponNameKey: j['weaponNameKey'] as String? ?? '',
        attacksAll: j['attacksAll'] as bool?,
        immuneToMindControl: j['immuneToMindControl'] as bool? ?? false,
        weakTo: {
          for (final n in (j['weakTo'] as List? ?? const []))
            Element.values.firstWhere((e) => e.name == n),
        },
        dodgesBack: j['dodgesBack'] as bool? ?? false,
        preset: PresetKind.values.firstWhere(
          (p) => p.name == j['preset'],
          orElse: () => PresetKind.aggressive,
        ),
        knownPresets: {
          for (final n in (j['knownPresets'] as List? ?? const []))
            PresetKind.values.firstWhere((p) => p.name == n),
        },
      );
}

/// Changes to one enemy for this battle only.
///
/// The fixed battles in the design documents keep fielding rows that
/// are not quite the table's: a renamed Draconian, an Orc mage wearing
/// a Troll's name and a higher level, a boss with one more ability, a
/// copy of a party member. `hd_battle` had no way to say so
/// (`Enemy::ChangeAttribute` was ignored); this is that way.
///
/// Every field is optional and null means "as the table has it".
class EnemyOverride {
  const EnemyOverride({
    this.nameKey,
    this.displayName,
    this.level,
    this.hp,
    this.strength,
    this.mentality,
    this.endurance,
    this.physicalResistance,
    this.magicResistance,
    this.agility,
    this.accuracyPhysical,
    this.accuracyMagic,
    this.ac,
    this.special,
    this.castLevel,
    this.abilities,
    this.superLevel,
    this.persuadable,
    this.persuadeLevel,
    this.rewardLevel,
    this.rewardAc,
    this.givesGold,
    this.poison,
    this.unconscious,
    this.dead,
  });

  /// The name the text package should show instead of the row's own,
  /// as a key into its alias table (`draconian_believer`).
  final String? nameKey;

  /// A literal name, for an enemy only the RPG can name — the copy of a
  /// party member, say. Wins over [nameKey].
  final String? displayName;

  final int? level;

  /// Starting hit points. **Left out, they follow the level**: change
  /// [level] or [endurance] and hit points are recomputed from the
  /// episode's formula; change neither and the row's own are kept. Set
  /// it to pin a value the formula would not give — the documents'
  /// "Troll magic user" raises the level and keeps the old 360.
  final int? hp;

  final int? strength;
  final int? mentality;
  final int? endurance;
  final int? physicalResistance;
  final int? magicResistance;
  final int? agility;
  final int? accuracyPhysical;
  final int? accuracyMagic;
  final int? ac;
  final EnemySpecial? special;
  final int? castLevel;

  /// **Replaces** the row's set — list everything it should have.
  final Set<EnemyAbility>? abilities;
  final int? superLevel;
  final bool? persuadable;
  final int? persuadeLevel;

  /// The level and armour class experience and gold are worked out
  /// from, when they are not the creature's own. Parts 1 and 2 pay some
  /// renamed bosses by another row's numbers.
  final int? rewardLevel;
  final int? rewardAc;
  final bool? givesGold;

  /// Starting status, for a battle that resumes an earlier one — a
  /// repeated boss fight keeps the damage already done (ch.12.4).
  final int? poison;
  final int? unconscious;
  final int? dead;

  /// This override with [other] laid over it; [other] wins field by
  /// field.
  EnemyOverride mergedWith(EnemyOverride? other) {
    if (other == null) return this;
    return EnemyOverride(
      nameKey: other.nameKey ?? nameKey,
      displayName: other.displayName ?? displayName,
      level: other.level ?? level,
      hp: other.hp ?? hp,
      strength: other.strength ?? strength,
      mentality: other.mentality ?? mentality,
      endurance: other.endurance ?? endurance,
      physicalResistance: other.physicalResistance ?? physicalResistance,
      magicResistance: other.magicResistance ?? magicResistance,
      agility: other.agility ?? agility,
      accuracyPhysical: other.accuracyPhysical ?? accuracyPhysical,
      accuracyMagic: other.accuracyMagic ?? accuracyMagic,
      ac: other.ac ?? ac,
      special: other.special ?? special,
      castLevel: other.castLevel ?? castLevel,
      abilities: other.abilities ?? abilities,
      superLevel: other.superLevel ?? superLevel,
      persuadable: other.persuadable ?? persuadable,
      persuadeLevel: other.persuadeLevel ?? persuadeLevel,
      rewardLevel: other.rewardLevel ?? rewardLevel,
      rewardAc: other.rewardAc ?? rewardAc,
      givesGold: other.givesGold ?? givesGold,
      poison: other.poison ?? poison,
      unconscious: other.unconscious ?? unconscious,
      dead: other.dead ?? dead,
    );
  }

  Map<String, dynamic> toJson() => {
    if (nameKey != null) 'nameKey': nameKey,
    if (displayName != null) 'displayName': displayName,
    if (level != null) 'level': level,
    if (hp != null) 'hp': hp,
    if (strength != null) 'strength': strength,
    if (mentality != null) 'mentality': mentality,
    if (endurance != null) 'endurance': endurance,
    if (physicalResistance != null) 'physicalResistance': physicalResistance,
    if (magicResistance != null) 'magicResistance': magicResistance,
    if (agility != null) 'agility': agility,
    if (accuracyPhysical != null) 'accuracyPhysical': accuracyPhysical,
    if (accuracyMagic != null) 'accuracyMagic': accuracyMagic,
    if (ac != null) 'ac': ac,
    if (special != null) 'special': special!.name,
    if (castLevel != null) 'castLevel': castLevel,
    if (abilities != null) 'abilities': [for (final a in abilities!) a.name],
    if (superLevel != null) 'superLevel': superLevel,
    if (persuadable != null) 'persuadable': persuadable,
    if (persuadeLevel != null) 'persuadeLevel': persuadeLevel,
    if (rewardLevel != null) 'rewardLevel': rewardLevel,
    if (rewardAc != null) 'rewardAc': rewardAc,
    if (givesGold != null) 'givesGold': givesGold,
    if (poison != null) 'poison': poison,
    if (unconscious != null) 'unconscious': unconscious,
    if (dead != null) 'dead': dead,
  };

  factory EnemyOverride.fromJson(Map<String, dynamic> j) => EnemyOverride(
    nameKey: j['nameKey'] as String?,
    displayName: j['displayName'] as String?,
    level: j['level'] as int?,
    hp: j['hp'] as int?,
    strength: j['strength'] as int?,
    mentality: j['mentality'] as int?,
    endurance: j['endurance'] as int?,
    physicalResistance: j['physicalResistance'] as int?,
    magicResistance: j['magicResistance'] as int?,
    agility: j['agility'] as int?,
    accuracyPhysical: j['accuracyPhysical'] as int?,
    accuracyMagic: j['accuracyMagic'] as int?,
    ac: j['ac'] as int?,
    special: j['special'] == null
        ? null
        : EnemySpecial.values.firstWhere((s) => s.name == j['special']),
    castLevel: j['castLevel'] as int?,
    abilities: j['abilities'] == null
        ? null
        : {
            for (final n in (j['abilities'] as List))
              EnemyAbility.values.firstWhere((a) => a.name == n),
          },
    superLevel: j['superLevel'] as int?,
    persuadable: j['persuadable'] as bool?,
    persuadeLevel: j['persuadeLevel'] as int?,
    rewardLevel: j['rewardLevel'] as int?,
    rewardAc: j['rewardAc'] as int?,
    givesGold: j['givesGold'] as bool?,
    poison: j['poison'] as int?,
    unconscious: j['unconscious'] as int?,
    dead: j['dead'] as int?,
  );
}

/// Everything the battle needs to start.
///
/// Three things make a run reproducible: this object, the sequence of
/// `BattleCommand`s fed to it, and [seed].
class BattleSetup {
  const BattleSetup({
    required this.party,
    required this.enemyKeys,
    required this.seed,
    this.episode = 3,
    this.mode = 0,
    this.consumables = const <String, int>{},
    this.arrows = 0,
    this.initialGap,
    this.enemyRanks = const <int>[],
    this.enemyOverrides = const <int, EnemyOverride>{},
    this.canEscape = true,
    this.enemyActsFirst = false,
    this.attackUnconscious = true,
  });

  /// Party members, in seat order. Empty seats are simply not listed.
  /// Seat 5, when present, is the assistant member.
  final List<CombatantSnapshot> party;

  /// Enemy keys **of this [episode]'s table**, one entry per enemy.
  /// Duplicates are expected. A key may also name one of the episode's
  /// variants (`enemyVariantsFor`) — a table row with an override
  /// already attached.
  final List<String> enemyKeys;

  /// Seeds the single generator the whole battle draws from.
  final int seed;

  /// Which part of the trilogy — 1, 2 or 3. **Selects the enemy
  /// table**, because the three parts number their enemies differently,
  /// and switches the few rules that are one part's alone.
  final int episode;

  /// The script's `Battle::Start(mode)` argument. No rule reads it.
  final int mode;

  /// What the party may use, as `key -> count` ([ItemKey]). A
  /// projection of the pack, not the pack: the battle spends from this
  /// copy and reports the total in [BattleOutcome.consumedItems].
  final Map<String, int> consumables;

  /// The party's shared arrows. A shooting weapon spends one per attack
  /// (ch.8.4); [BattleOutcome.arrowsUsed] reports how many went.
  final int arrows;

  /// How far apart the two sides start, 0..2. Null derives it — 0 when
  /// [enemyActsFirst], otherwise from the two sides' agility and level.
  final int? initialGap;

  /// Which rank each enemy stands in, parallel to [enemyKeys]. Shorter
  /// (or empty) means the rest are read off what the creature is.
  final List<int> enemyRanks;

  /// Per-enemy changes, keyed by **index into [enemyKeys]**.
  final Map<int, EnemyOverride> enemyOverrides;

  /// False for the battles that forbid running (ch.8.1). The escape
  /// line is then not offered at all.
  final bool canEscape;

  /// An ambush, a failed pre-battle escape, or most fixed battles: the
  /// first round has no party phase (ch.8.3).
  final bool enemyActsFirst;

  /// The option "의식 불명인 적까지 공격" (ch.8.10), on by default. On,
  /// an unconscious enemy is a target and striking it finishes it; off,
  /// attacks pass over it.
  final bool attackUnconscious;

  Map<String, dynamic> toJson() => {
    'party': [for (final c in party) c.toJson()],
    'enemyKeys': enemyKeys,
    'seed': seed,
    'episode': episode,
    'mode': mode,
    'consumables': consumables,
    'arrows': arrows,
    if (initialGap != null) 'initialGap': initialGap,
    'enemyRanks': enemyRanks,
    'enemyOverrides': {
      for (final e in enemyOverrides.entries) '${e.key}': e.value.toJson(),
    },
    'canEscape': canEscape,
    'enemyActsFirst': enemyActsFirst,
    'attackUnconscious': attackUnconscious,
  };

  factory BattleSetup.fromJson(Map<String, dynamic> j) => BattleSetup(
    party: [
      for (final c in (j['party'] as List))
        CombatantSnapshot.fromJson(c as Map<String, dynamic>),
    ],
    enemyKeys: [for (final k in (j['enemyKeys'] as List)) k as String],
    seed: j['seed'] as int,
    episode: j['episode'] as int? ?? 3,
    mode: j['mode'] as int? ?? 0,
    consumables: <String, int>{
      for (final e
          in (j['consumables'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .entries)
        e.key as String: e.value as int,
    },
    arrows: j['arrows'] as int? ?? 0,
    initialGap: j['initialGap'] as int?,
    enemyRanks: [
      for (final r in (j['enemyRanks'] as List? ?? const [])) r as int,
    ],
    enemyOverrides: <int, EnemyOverride>{
      for (final e
          in (j['enemyOverrides'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .entries)
        int.parse(e.key as String): EnemyOverride.fromJson(
          e.value as Map<String, dynamic>,
        ),
    },
    canEscape: j['canEscape'] as bool? ?? true,
    enemyActsFirst: j['enemyActsFirst'] as bool? ?? false,
    attackUnconscious: j['attackUnconscious'] as bool? ?? true,
  );
}

/// Result reported for one party seat.
class CombatantResult {
  const CombatantResult({
    required this.slot,
    required this.hp,
    required this.mp,
    required this.poison,
    required this.unconscious,
    required this.dead,
    required this.experienceGained,
    this.acLoss = 0,
  });

  final int slot;
  final int hp;
  final int mp;
  final int poison;
  final int unconscious;
  final int dead;

  /// Experience this member earned. Per seat because the rule is per
  /// seat: knocking an enemy out pays the one who did it, finishing an
  /// unconscious one pays everyone still standing (ch.8.8).
  final int experienceGained;

  /// How much armour class 갑옷 파괴 took. **Permanent** — the RPG
  /// lowers the member's base armour by this.
  final int acLoss;

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'hp': hp,
    'mp': mp,
    'poison': poison,
    'unconscious': unconscious,
    'dead': dead,
    'experienceGained': experienceGained,
    'acLoss': acLoss,
  };

  factory CombatantResult.fromJson(Map<String, dynamic> j) => CombatantResult(
    slot: j['slot'] as int,
    hp: j['hp'] as int,
    mp: j['mp'] as int? ?? 0,
    poison: j['poison'] as int? ?? 0,
    unconscious: j['unconscious'] as int? ?? 0,
    dead: j['dead'] as int? ?? 0,
    experienceGained: j['experienceGained'] as int? ?? 0,
    acLoss: j['acLoss'] as int? ?? 0,
  );
}

/// Where one enemy stood when the battle ended.
///
/// Two uses, both the RPG's: an event that only needs one particular
/// enemy down can look for it here, and a battle that is fought again
/// "with the damage already done" (ch.12.4) feeds [resume] straight
/// back in as that enemy's override.
class EnemyState {
  const EnemyState({
    required this.key,
    required this.hp,
    required this.unconscious,
    required this.dead,
    required this.left,
    required this.resume,
  });

  /// The table key it was fielded under — the base row's, for a
  /// variant.
  final String key;

  final int hp;
  final int unconscious;
  final int dead;

  /// True when it is no longer on the field for a reason other than
  /// falling: it fled, it was persuaded, or it was a clone.
  final bool left;

  /// Its live numbers as an override.
  final EnemyOverride resume;

  /// Down or dead — what "defeated" means for an event.
  bool get isDown => unconscious > 0 || dead > 0 || hp <= 0;

  Map<String, dynamic> toJson() => {
    'key': key,
    'hp': hp,
    'unconscious': unconscious,
    'dead': dead,
    'left': left,
    'resume': resume.toJson(),
  };

  factory EnemyState.fromJson(Map<String, dynamic> j) => EnemyState(
    key: j['key'] as String,
    hp: j['hp'] as int,
    unconscious: j['unconscious'] as int? ?? 0,
    dead: j['dead'] as int? ?? 0,
    left: j['left'] as bool? ?? false,
    resume: EnemyOverride.fromJson(j['resume'] as Map<String, dynamic>),
  );
}

/// Everything the RPG has to apply after the battle.
///
/// The battle changes nothing outside itself. This object is the whole
/// of its effect, and the RPG applies it in one place.
class BattleOutcome {
  const BattleOutcome({
    required this.resultCode,
    required this.combatants,
    required this.goldGained,
    this.consumedItems = const <String, int>{},
    this.arrowsUsed = 0,
    this.newAssistant,
    this.departedSlots = const <int>[],
    this.enemies = const <EnemyState>[],
  });

  final BattleResultCode resultCode;

  /// One entry per seat that is **occupied when the battle ends**,
  /// keyed by [CombatantSnapshot.slot].
  final List<CombatantResult> combatants;

  /// `level³ × max(ac, 1)` over the fallen, on a win; zero otherwise.
  final int goldGained;

  /// Herbs, potions and crystals used up, as `key -> count`. The battle
  /// never touches the RPG's pack.
  final Map<String, int> consumedItems;

  /// Arrows loosed.
  final int arrowsUsed;

  /// Whoever sits in seat 5 now, **if it is not who started there** —
  /// a summon, a crystal creature or a persuaded enemy. A full stat
  /// block, so the RPG can seat it as it is; its hit points and status
  /// are the ones it ended the battle with (the same numbers as its
  /// entry in [combatants]).
  ///
  /// The assistant stays after the battle (ch.9.7), which is why this
  /// has to cross the boundary at all.
  final CombatantSnapshot? newAssistant;

  /// Seats the battle **emptied** — 정신 지배 took the assistant and
  /// nothing replaced it. An absence, not a death, which is why it is
  /// not in [combatants].
  final List<int> departedSlots;

  /// Every enemy's final state, in the battle's index order.
  final List<EnemyState> enemies;

  Map<String, dynamic> toJson() => {
    'resultCode': resultCode.wire,
    'combatants': [for (final c in combatants) c.toJson()],
    'goldGained': goldGained,
    'consumedItems': consumedItems,
    'arrowsUsed': arrowsUsed,
    if (newAssistant != null) 'newAssistant': newAssistant!.toJson(),
    'departedSlots': departedSlots,
    'enemies': [for (final e in enemies) e.toJson()],
  };

  factory BattleOutcome.fromJson(Map<String, dynamic> j) => BattleOutcome(
    resultCode: BattleResultCode.fromWire(j['resultCode'] as int),
    combatants: [
      for (final c in (j['combatants'] as List))
        CombatantResult.fromJson(c as Map<String, dynamic>),
    ],
    goldGained: j['goldGained'] as int? ?? 0,
    consumedItems: <String, int>{
      for (final e
          in (j['consumedItems'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .entries)
        e.key as String: e.value as int,
    },
    arrowsUsed: j['arrowsUsed'] as int? ?? 0,
    newAssistant: j['newAssistant'] == null
        ? null
        : CombatantSnapshot.fromJson(j['newAssistant'] as Map<String, dynamic>),
    departedSlots: [
      for (final d in (j['departedSlots'] as List? ?? const [])) d as int,
    ],
    enemies: [
      for (final e in (j['enemies'] as List? ?? const []))
        EnemyState.fromJson(e as Map<String, dynamic>),
    ],
  );
}
