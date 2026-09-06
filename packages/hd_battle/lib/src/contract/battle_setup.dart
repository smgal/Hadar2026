import '../rules/affinity.dart';
import '../rules/mitigation.dart';
import '../rules/preset.dart';
import '../rules/position.dart';
import 'battle_result_code.dart';

/// One party member as the battle sees them.
///
/// This is a snapshot taken when the battle starts. The battle never
/// reaches back into the RPG's own party object; everything it needs is
/// copied in here, and everything it changes comes back through
/// `BattleOutcome`.
///
/// Derived RPG values arrive already resolved — [ac] is the RPG's
/// `baseAc + equipmentAc`, [powOfWeapon] is the wielded item's attack
/// power, [weaponName] is the resolved display name. The battle does not
/// know about equipment slots or item tables.
///
/// [experience] is deliberately absent: levels never change mid-battle,
/// so the battle takes levels as input and reports experience gained as
/// output. Level-up is the RPG's job.
class CombatantSnapshot {
  const CombatantSnapshot({
    required this.slot,
    required this.name,
    this.characterClass = 0,
    this.strength = 0,
    this.mentality = 0,
    this.concentration = 0,
    this.endurance = 0,
    this.resistance = 0,
    this.agility = 0,
    this.luck = 0,
    this.ac = 0,
    required this.hp,
    required this.maxHp,
    this.sp = 0,
    this.maxSp = 0,
    this.esp = 0,
    this.maxEsp = 0,
    this.accuracyPhysical = 0,
    this.accuracyMagic = 0,
    this.accuracyEsp = 0,
    this.levelPhysical = 0,
    this.levelMagic = 0,
    this.levelEsp = 0,
    this.powOfWeapon = 1,
    this.weaponName = '',
    this.weaponKey = 'unarmed',
    this.weakTo = const <Element>{},
    this.dodgesBack = false,
    this.preset = PresetKind.aggressive,
    this.knownPresets = const <PresetKind>{},
    this.poison = 0,
    this.unconscious = 0,
    this.dead = 0,
    ArmourPieces? armour,
    int? rank,
  }) : armour = armour ?? const ArmourPieces(),
       rank = rank ?? (slot < 2 ? 1 : (slot < 4 ? 2 : 3));

  /// Party slot index (0..5). **This is the key that joins the two
  /// worlds** — `BattleOutcome` reports results under the same value, and
  /// the RPG finds the member to write back by it.
  final int slot;

  final String name;
  final int characterClass;

  final int strength;
  final int mentality;
  final int concentration;
  final int endurance;
  final int resistance;
  final int agility;
  final int luck;

  /// Total armour class, equipment already summed in.
  ///
  /// Still the single number the original defended with. [armour] is the
  /// per-slot split B2-08 added; when it is empty this value is used on
  /// its own, so an RPG that has not been taught the split yet behaves
  /// exactly as before.
  final int ac;

  /// Armour by slot, plus the shield's block chance (B2-08).
  ///
  /// Empty means "not split" — [effectiveArmour] then falls back to
  /// [ac].
  final ArmourPieces armour;

  /// The armour that subtracts from damage.
  int get effectiveArmour => armour.isEmpty ? ac : armour.worn;

  /// The shield's chance to stop a blow outright.
  int get shieldBlock => armour.shieldBlock;

  final int hp;
  final int maxHp;
  final int sp;
  final int maxSp;
  final int esp;
  final int maxEsp;

  final int accuracyPhysical;
  final int accuracyMagic;
  final int accuracyEsp;

  final int levelPhysical;
  final int levelMagic;
  final int levelEsp;

  /// Attack power of the wielded weapon (bare hand is 1).
  final int powOfWeapon;

  /// Display name of the wielded weapon. Carried for the view only; no
  /// rule reads it.
  final String weaponName;

  /// Which entry of the battle's own weapon table this is (B5-02).
  ///
  /// The split is deliberate: the RPG says **how hard** the weapon hits
  /// ([powOfWeapon], resolved from its own item table), and the battle
  /// says **how it reaches** — minimum and maximum distance, how the
  /// blow is delivered, whether it can charge. That way the battle can
  /// be balanced without dragging item data across the boundary, which
  /// is the same reason the enemy table lives here.
  ///
  /// Unknown keys fall back to bare hands rather than throwing; an RPG
  /// that has not been taught the table yet still fights.
  final String weaponKey;

  /// What this member is unusually vulnerable to (B5-06).
  ///
  /// Empty for most people — a party member is flesh and bone and has
  /// no strong opinion about slashing versus bludgeoning. Armour, a
  /// curse or a bloodline can put something here, and then the enemy
  /// can drive them back the same way they drive enemies back.
  final Set<Element> weakTo;

  /// Gives ground rather than take a killing blow (B5-07).
  ///
  /// A passive only some people have. When a blow would finish them and
  /// there is a rank behind to fall into, they step back instead.
  ///
  /// Two limits keep it from being an extra life:
  ///
  /// * **only they move**, never the formation — one evasion roll
  ///   should not reposition the whole party
  /// * **there has to be somewhere to go**, so it works from the front
  ///   and middle and stops working at the back
  ///
  /// Which means at most twice a battle, and each use leaves them
  /// further from anything their weapon can reach: alive, and useless
  /// until someone heals or the line moves. The limit falls out of the
  /// position rules rather than needing a counter of its own.
  final bool dodgesBack;

  /// The standing orders this member runs when told to act on their own
  /// (B5-08).
  ///
  /// The original's seventh menu entry — "tell the party to just
  /// attack" — is auto-battle with a single setting. This makes it a
  /// choice, and events lengthen [knownPresets] rather than opening a
  /// rule editor.
  final PresetKind preset;

  /// Which presets this member has learned. Selection only; there is no
  /// editor, which is deliberate — writing conditions is Final Fantasy
  /// XII's gambit screen and the most expensive thing in this track's
  /// UI budget.
  final Set<PresetKind> knownPresets;

  final int poison;
  final int unconscious;
  final int dead;

  /// Which rank this member stands in, 1 (front) to 3 (back) (B5-01).
  ///
  /// The party's formation is set **outside** the battle, the way
  /// Dragon Quest IV and V do it; inside a battle it only changes as a
  /// consequence of an action. Left unset it falls out of the slot —
  /// 0-1 front, 2-3 middle, 4-5 back — so an RPG that has not been
  /// taught about ranks yet still fields a sane formation.
  ///
  /// Melee belongs up front: with reach and [distanceBetween] as they
  /// are, a short weapon in the back rank cannot reach anything. That
  /// is the decision the formation screen is for.
  final int rank;

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'name': name,
    'characterClass': characterClass,
    'strength': strength,
    'mentality': mentality,
    'concentration': concentration,
    'endurance': endurance,
    'resistance': resistance,
    'agility': agility,
    'luck': luck,
    'ac': ac,
    'hp': hp,
    'maxHp': maxHp,
    'sp': sp,
    'maxSp': maxSp,
    'esp': esp,
    'maxEsp': maxEsp,
    'accuracyPhysical': accuracyPhysical,
    'accuracyMagic': accuracyMagic,
    'accuracyEsp': accuracyEsp,
    'levelPhysical': levelPhysical,
    'levelMagic': levelMagic,
    'levelEsp': levelEsp,
    'powOfWeapon': powOfWeapon,
    'weaponName': weaponName,
    'weaponKey': weaponKey,
    'weakTo': [for (final e in weakTo) e.name],
    'dodgesBack': dodgesBack,
    'preset': preset.name,
    'knownPresets': [for (final p in knownPresets) p.name],
    'poison': poison,
    'unconscious': unconscious,
    'dead': dead,
    'rank': rank,
    'armour': armour.toJson(),
  };

  factory CombatantSnapshot.fromJson(Map<String, dynamic> j) =>
      CombatantSnapshot(
        slot: j['slot'] as int,
        name: j['name'] as String? ?? '',
        characterClass: j['characterClass'] as int? ?? 0,
        strength: j['strength'] as int? ?? 0,
        mentality: j['mentality'] as int? ?? 0,
        concentration: j['concentration'] as int? ?? 0,
        endurance: j['endurance'] as int? ?? 0,
        resistance: j['resistance'] as int? ?? 0,
        agility: j['agility'] as int? ?? 0,
        luck: j['luck'] as int? ?? 0,
        ac: j['ac'] as int? ?? 0,
        hp: j['hp'] as int? ?? 0,
        maxHp: j['maxHp'] as int? ?? 0,
        sp: j['sp'] as int? ?? 0,
        maxSp: j['maxSp'] as int? ?? 0,
        esp: j['esp'] as int? ?? 0,
        maxEsp: j['maxEsp'] as int? ?? 0,
        accuracyPhysical: j['accuracyPhysical'] as int? ?? 0,
        accuracyMagic: j['accuracyMagic'] as int? ?? 0,
        accuracyEsp: j['accuracyEsp'] as int? ?? 0,
        levelPhysical: j['levelPhysical'] as int? ?? 0,
        levelMagic: j['levelMagic'] as int? ?? 0,
        levelEsp: j['levelEsp'] as int? ?? 0,
        powOfWeapon: j['powOfWeapon'] as int? ?? 1,
        weaponName: j['weaponName'] as String? ?? '',
        weaponKey: j['weaponKey'] as String? ?? 'unarmed',
        weakTo: {
          for (final n in (j['weakTo'] as List? ?? []))
            Element.values.firstWhere((e) => e.name == n),
        },
        dodgesBack: j['dodgesBack'] as bool? ?? false,
        preset: PresetKind.values.firstWhere(
          (p) => p.name == j['preset'],
          orElse: () => PresetKind.aggressive,
        ),
        knownPresets: {
          for (final n in (j['knownPresets'] as List? ?? []))
            PresetKind.values.firstWhere((p) => p.name == n),
        },
        poison: j['poison'] as int? ?? 0,
        unconscious: j['unconscious'] as int? ?? 0,
        dead: j['dead'] as int? ?? 0,
        rank: j['rank'] as int?,
        armour: j['armour'] == null
            ? null
            : ArmourPieces.fromJson(j['armour'] as Map<String, dynamic>),
      );
}

/// The handover contract's version.
///
/// v1 was frozen at B2-99 and reopened by B5: position (`rank`,
/// `initialGap`), weapon reach, physical elements, presets and party
/// capacity all cross the boundary. B5-99 closed it again as v2.
/// `packages/hd_battle/CONTRACT.md` is the document.
const String contractVersion = 'v3';

/// Everything the battle needs to start.
///
/// Three things make a run reproducible: this object, the sequence of
/// `BattleCommand`s fed to it, and [seed]. A fixture file holds all
/// three, which is what lets one file be both a console demo and a
/// regression test input.
class BattleSetup {
  const BattleSetup({
    required this.party,
    required this.enemyKeys,
    required this.seed,
    this.mode = 0,
    this.consumables = const <String, int>{},
    this.initialGap,
    this.enemyRanks = const <int>[],
    this.partyCapacity = 6,
  });

  /// Party members, in slot order. Members that are absent from the
  /// party are simply not listed.
  final List<CombatantSnapshot> party;

  /// Enemy table keys, one entry per enemy instance. **Duplicates are
  /// expected** — `assets/L1_ep1d0.cm2:367-403` registers the same enemy
  /// seven times.
  final List<String> enemyKeys;

  /// Seeds the single `Random` the whole battle draws from.
  final int seed;

  /// What the party may use in this battle, as `key -> count`
  /// (B2-06).
  ///
  /// A **projection** of the backpack, not the backpack. The battle
  /// spends from this copy and reports the total in
  /// `BattleOutcome.consumedItems`; the RPG is the only thing that
  /// removes anything for real.
  final Map<String, int> consumables;

  /// How far apart the two sides start, 0 to [maxGap] (B5-01).
  ///
  /// Null lets [openingGap] read it off the two sides — the party only
  /// keeps its distance when it is plainly stronger. Set it when the
  /// encounter has an opinion: 0 for an ambush, 2 for spotting them
  /// across a hall.
  ///
  /// Real fights run three to four rounds (appendix W-1), so most
  /// encounters want 0 or 1 — a gap that takes two rounds to close
  /// would spend half the battle walking.
  final int? initialGap;

  /// How many slots the RPG's party has (B5-09).
  ///
  /// [party] lists who is actually sitting in them; the difference is
  /// how much room is left. The battle needs to know because it can
  /// **add** members mid-fight — mind control turns an enemy into a
  /// party member, and a summon walks one in — and "no room" has to be
  /// decidable while the fight is running, not afterwards.
  ///
  /// Empty slots are recomputed as the fight goes: a member dragged off
  /// by a superhuman caster (`departedSlots`) frees theirs.
  final int partyCapacity;

  /// Which rank each enemy stands in, parallel to [enemyKeys].
  ///
  /// Shorter than [enemyKeys] (or empty) means the rest fall back to
  /// [defaultEnemyRank] — what a creature is decides where it stands,
  /// so casters end up behind the brutes without anyone writing a
  /// formation out by hand for all 75 rows.
  final List<int> enemyRanks;

  /// The `Battle::Start(mode)` argument. Carried for the CM2 contract's
  /// sake; the original implementation never read it
  /// (`battle.dart:112` `Future<void> start(int mode)`), so no rule
  /// depends on it here either.
  final int mode;

  Map<String, dynamic> toJson() => {
    'party': [for (final c in party) c.toJson()],
    'enemyKeys': enemyKeys,
    'seed': seed,
    'mode': mode,
    'consumables': consumables,
    if (initialGap != null) 'initialGap': initialGap,
    'enemyRanks': enemyRanks,
    'partyCapacity': partyCapacity,
  };

  factory BattleSetup.fromJson(Map<String, dynamic> j) => BattleSetup(
    party: [
      for (final c in (j['party'] as List))
        CombatantSnapshot.fromJson(c as Map<String, dynamic>),
    ],
    enemyKeys: [for (final k in (j['enemyKeys'] as List)) k as String],
    seed: j['seed'] as int,
    mode: j['mode'] as int? ?? 0,
    consumables: <String, int>{
      for (final e
          in (j['consumables'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .entries)
        e.key as String: e.value as int,
    },
    initialGap: j['initialGap'] as int?,
    enemyRanks: [for (final r in (j['enemyRanks'] as List? ?? [])) r as int],
    partyCapacity: j['partyCapacity'] as int? ?? 6,
  );
}

/// Result reported for one party slot.
class CombatantResult {
  const CombatantResult({
    required this.slot,
    required this.hp,
    required this.sp,
    required this.esp,
    required this.poison,
    required this.unconscious,
    required this.dead,
    required this.experienceGained,
  });

  final int slot;
  final int hp;
  final int sp;
  final int esp;
  final int poison;
  final int unconscious;
  final int dead;

  /// Experience this member earned. Per-slot rather than one shared
  /// number because the original distributes it two different ways: kill
  /// bonuses go to the attacker (`battle.dart:446,494`) while the
  /// victory settlement goes to every conscious member
  /// (`battle.dart:286`).
  final int experienceGained;

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'hp': hp,
    'sp': sp,
    'esp': esp,
    'poison': poison,
    'unconscious': unconscious,
    'dead': dead,
    'experienceGained': experienceGained,
  };

  factory CombatantResult.fromJson(Map<String, dynamic> j) => CombatantResult(
    slot: j['slot'] as int,
    hp: j['hp'] as int,
    sp: j['sp'] as int,
    esp: j['esp'] as int,
    poison: j['poison'] as int? ?? 0,
    unconscious: j['unconscious'] as int? ?? 0,
    dead: j['dead'] as int? ?? 0,
    experienceGained: j['experienceGained'] as int? ?? 0,
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
    this.worldEffects = const <String>[],
    this.recruits = const <CombatantSnapshot>[],
    this.departedSlots = const <int>[],
  });

  final BattleResultCode resultCode;

  /// One entry per party slot that took part, keyed by
  /// [CombatantSnapshot.slot].
  final List<CombatantResult> combatants;

  final int goldGained;

  /// Items used up during the battle, as `key -> count`. The battle
  /// never touches the RPG's backpack; it reports what it spent and the
  /// RPG removes it. Always empty until B2-06 adds item use.
  final Map<String, int> consumedItems;

  /// Effects that belong outside the battle — the phenomenon and ESP
  /// spells whose result is a party buff, a map change or an information
  /// readout. The battle cannot carry them out, so it records the
  /// request and the RPG interprets it.
  final List<String> worldEffects;

  /// Party members the battle **added**, as ready-made snapshots.
  ///
  /// Mind control (magic 43) turns a whitelisted enemy into a party
  /// member (B2-10), and from B5-09 they keep fighting on this side for
  /// the rest of the battle. Each carries the **slot it was actually
  /// seated in**, so the RPG writes it back the way it writes back
  /// anyone else — B2-10 handed over `slot: -1` and left the RPG to
  /// find room, which made "no room" undecidable while the fight was
  /// still running.
  final List<CombatantSnapshot> recruits;

  /// Party slots the battle **lost**.
  ///
  /// A superhuman caster can pull a member over to the enemy side
  /// (B2-11). The RPG has to clear those slots — the member is gone, not
  /// merely dead, which is why this is separate from
  /// [CombatantResult.dead].
  final List<int> departedSlots;

  Map<String, dynamic> toJson() => {
    'resultCode': resultCode.wire,
    'combatants': [for (final c in combatants) c.toJson()],
    'goldGained': goldGained,
    'consumedItems': consumedItems,
    'worldEffects': worldEffects,
    'recruits': [for (final r in recruits) r.toJson()],
    'departedSlots': departedSlots,
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
    worldEffects: [
      for (final w in (j['worldEffects'] as List? ?? [])) w as String,
    ],
    recruits: [
      for (final r in (j['recruits'] as List? ?? []))
        CombatantSnapshot.fromJson(r as Map<String, dynamic>),
    ],
    departedSlots: [
      for (final d in (j['departedSlots'] as List? ?? [])) d as int,
    ],
  );
}
