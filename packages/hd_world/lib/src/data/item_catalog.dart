import '../domain/capability.dart';
import '../domain/character_class.dart';
import '../domain/ids.dart';
import '../domain/item_def.dart';
import '../domain/item_kind.dart';
import '../domain/modifier.dart';

/// The items this package knows about, and the way to know about more.
///
/// ## A registry, not a constant
///
/// [ItemCatalog.builtIn] is the shipped table; [ItemCatalog.extend]
/// makes a new catalogue with rows added or replaced. Nothing in the
/// rules reaches for a global, so a test, a content pack or a balance
/// experiment can hand a different catalogue in and every rule follows
/// it. The predecessor put its table in a top-level `const` that
/// fifteen call sites read directly, which is why no rule could ever be
/// tested against different data.
class ItemCatalog {
  ItemCatalog(Iterable<ItemDef> defs)
    : _byRef = {for (final d in defs) d.ref: d};

  final Map<ItemRef, ItemDef> _byRef;

  /// Every row, in insertion order.
  Iterable<ItemDef> get all => _byRef.values;

  int get length => _byRef.length;

  /// The row for [ref], or null. **Null is an answer, not a failure** —
  /// a save naming an item this build does not have has to be reported,
  /// not defaulted to bare hands.
  ItemDef? operator [](ItemRef ref) => _byRef[ref];

  bool contains(ItemRef ref) => _byRef.containsKey(ref);

  Iterable<ItemDef> ofKind(ItemKind kind) =>
      all.where((d) => d.kind == kind);

  /// A catalogue with [defs] added, replacing any row with the same ref.
  ItemCatalog extend(Iterable<ItemDef> defs) =>
      ItemCatalog([..._byRef.values, ...defs]);

  /// The shipped table.
  static final ItemCatalog builtIn = ItemCatalog(_builtInDefs);
}

ItemDef _weapon(
  String key,
  ItemKind kind,
  WeaponShape shape,
  Hands hands,
  int power,
  int legacyIndex, {
  bool removable = true,
}) => ItemDef(
  ref: ItemRef('weapon.$key'),
  nameKey: 'item.weapon.$key',
  kind: kind,
  hands: hands,
  shape: shape,
  attackPower: power,
  removable: removable,
  legacyIndex: legacyIndex,
);

ItemDef _armour(
  String key,
  ItemKind kind,
  int defence,
  int legacyIndex, {
  List<Modifier> extra = const [],
  String annexKey = '',
}) => ItemDef(
  ref: ItemRef('${kind.name}.$key'),
  nameKey: 'item.${kind.name}.$key',
  kind: kind,
  modifiers: [
    if (defence != 0) Modifier.add(StatKey.defence, defence),
    ...extra,
  ],
  annexKey: annexKey,
  legacyIndex: legacyIndex,
);

/// ## The thirty-one weapons are the original's own list
///
/// Transcribed from `WEAPON_LIST`: seven cutting, seven chopping, seven
/// thrusting, three striking, seven missile. `attackPower` is the
/// original number.
///
/// **Two columns are ours**: how many hands, and what shape. The
/// original had neither, and the fighting style is read off exactly
/// those two — which is why widening the catalogue was worth doing
/// before touching any rule.
final List<ItemDef> _builtInDefs = [
  // bare hands, one per weapon class, so an empty grip still resolves
  _weapon(
    'fist_cut',
    ItemKind.slashWeapon,
    WeaponShape.blade,
    Hands.one,
    1,
    0,
    removable: false,
  ),
  _weapon(
    'fist_chop',
    ItemKind.chopWeapon,
    WeaponShape.axe,
    Hands.one,
    1,
    0,
    removable: false,
  ),
  _weapon(
    'fist_thrust',
    ItemKind.pierceWeapon,
    WeaponShape.blade,
    Hands.one,
    1,
    0,
    removable: false,
  ),
  _weapon(
    'fist_strike',
    ItemKind.bluntWeapon,
    WeaponShape.knuckle,
    Hands.one,
    1,
    0,
    removable: false,
  ),
  _weapon(
    'fist_shoot',
    ItemKind.missileWeapon,
    WeaponShape.thrown,
    Hands.one,
    1,
    0,
    removable: false,
  ),

  // cutting — one-handed up to the scimitar, two-handed above it
  _weapon('dagger', ItemKind.slashWeapon, WeaponShape.blade, Hands.one, 15, 1),
  _weapon('gladius', ItemKind.slashWeapon, WeaponShape.blade, Hands.one, 30, 2),
  _weapon('sabre', ItemKind.slashWeapon, WeaponShape.blade, Hands.one, 35, 3),
  _weapon(
    'new_moon_blade',
    ItemKind.slashWeapon,
    WeaponShape.blade,
    Hands.one,
    45,
    4,
  ),
  _weapon(
    'full_moon_blade',
    ItemKind.slashWeapon,
    WeaponShape.blade,
    Hands.two,
    50,
    5,
  ),
  _weapon(
    'long_sword',
    ItemKind.slashWeapon,
    WeaponShape.blade,
    Hands.two,
    60,
    6,
  ),
  _weapon(
    'flamberge',
    ItemKind.slashWeapon,
    WeaponShape.blade,
    Hands.two,
    70,
    7,
  ),

  // chopping — the hafted heads are two-handed, the hand tools are not
  _weapon(
    'small_hammer',
    ItemKind.chopWeapon,
    WeaponShape.mace,
    Hands.one,
    15,
    1,
  ),
  _weapon('hand_axe', ItemKind.chopWeapon, WeaponShape.axe, Hands.one, 35, 2),
  _weapon('flail', ItemKind.chopWeapon, WeaponShape.mace, Hands.one, 35, 3),
  _weapon('war_hammer', ItemKind.chopWeapon, WeaponShape.mace, Hands.two, 52, 4),
  _weapon('mace', ItemKind.chopWeapon, WeaponShape.mace, Hands.one, 60, 5),
  _weapon(
    'battle_axe',
    ItemKind.chopWeapon,
    WeaponShape.polearm,
    Hands.two,
    75,
    6,
  ),
  _weapon(
    'halberd',
    ItemKind.chopWeapon,
    WeaponShape.polearm,
    Hands.two,
    80,
    7,
  ),

  // thrusting
  _weapon('knife', ItemKind.pierceWeapon, WeaponShape.blade, Hands.one, 10, 1),
  _weapon(
    'cavalry_lance',
    ItemKind.pierceWeapon,
    WeaponShape.lance,
    Hands.two,
    35,
    2,
  ),
  _weapon(
    'short_spear',
    ItemKind.pierceWeapon,
    WeaponShape.spear,
    Hands.one,
    35,
    3,
  ),
  _weapon('rapier', ItemKind.pierceWeapon, WeaponShape.blade, Hands.one, 40, 4),
  _weapon(
    'trident',
    ItemKind.pierceWeapon,
    WeaponShape.polearm,
    Hands.two,
    60,
    5,
  ),
  _weapon('lancer', ItemKind.pierceWeapon, WeaponShape.lance, Hands.two, 80, 6),
  _weapon(
    'poleaxe',
    ItemKind.pierceWeapon,
    WeaponShape.polearm,
    Hands.two,
    90,
    7,
  ),

  // striking
  _weapon(
    'knuckle',
    ItemKind.bluntWeapon,
    WeaponShape.knuckle,
    Hands.one,
    5,
    1,
  ),
  _weapon('long_staff', ItemKind.bluntWeapon, WeaponShape.staff, Hands.two, 10, 2),
  _weapon('club', ItemKind.bluntWeapon, WeaponShape.mace, Hands.one, 25, 3),

  // missile
  _weapon(
    'blowpipe',
    ItemKind.missileWeapon,
    WeaponShape.blowpipe,
    Hands.one,
    10,
    1,
  ),
  _weapon(
    'shuriken',
    ItemKind.missileWeapon,
    WeaponShape.thrown,
    Hands.one,
    10,
    2,
  ),
  _weapon('sling', ItemKind.missileWeapon, WeaponShape.thrown, Hands.one, 20, 3),
  _weapon(
    'javelin',
    ItemKind.missileWeapon,
    WeaponShape.thrown,
    Hands.one,
    35,
    4,
  ),
  _weapon('bow', ItemKind.missileWeapon, WeaponShape.bow, Hands.two, 45, 5),
  _weapon(
    'crossbow',
    ItemKind.missileWeapon,
    WeaponShape.crossbow,
    Hands.two,
    55,
    6,
  ),
  _weapon(
    'arbalest',
    ItemKind.missileWeapon,
    WeaponShape.arbalest,
    Hands.two,
    70,
    7,
  ),

  // shields — defence doubles as the block percentage, five points each
  for (final row in const [
    ('none', 0),
    ('leather', 1),
    ('small_steel', 2),
    ('large_steel', 3),
    ('chromatic', 4),
    ('platinum', 5),
  ])
    ItemDef(
      ref: ItemRef('shield.${row.$1}'),
      nameKey: 'item.shield.${row.$1}',
      kind: ItemKind.shield,
      modifiers: [
        if (row.$2 != 0) ...[
          Modifier.add(StatKey.defence, row.$2),
          Modifier.add(StatKey.shieldBlock, row.$2 * 5),
        ],
      ],
      legacyIndex: row.$2,
    ),

  // body armour
  for (final row in const [
    ('plain_clothes', 0),
    ('leather', 1),
    ('bronze', 2),
    ('steel', 3),
    ('silver', 4),
    ('gold', 5),
  ])
    _armour(row.$1, ItemKind.bodyArmour, row.$2, row.$2),

  // helmets — the original shipped these with no numbers at all except
  // the hood's free-text rider, kept verbatim as a key
  for (final (i, key) in const [
    'none',
    'hood',
    'hunting_cap',
    'half_mask',
    'fedora',
    'leather_cap',
    'leather_helm',
    'dandy_hat',
    'bronze_helm',
    'plate_helm',
    'gold_crown',
  ].indexed)
    _armour(
      key,
      ItemKind.helmet,
      0,
      i,
      annexKey: key == 'hood' ? 'annex.att1_ac-1_str1' : '',
    ),

  // boots
  for (final (i, key) in const [
    'none',
    'cloth_shoes',
    'leather_shoes',
    'mesh_stockings',
    'winged_shoes',
    'scale_boots',
    'legs6',
    'legs7',
    'legs8',
    'legs9',
    'legsA',
  ].indexed)
    _armour(
      key,
      ItemKind.boots,
      0,
      i,
      annexKey: key == 'cloth_shoes' ? 'annex.int-2' : '',
    ),

  // the original's eleven ornaments, which are common amulets here
  for (final (i, key) in const [
    'none',
    'dandy_belt',
    'plain_ring',
    'silver_ring',
    'ruby_necklace',
    'fake_medal',
    'trinket6',
    'trinket7',
    'trinket8',
    'trinket9',
    'trinketA',
  ].indexed)
    ItemDef(
      ref: ItemRef('commonAmulet.$key'),
      nameKey: 'item.commonAmulet.$key',
      kind: ItemKind.commonAmulet,
      annexKey: key == 'dandy_belt' ? 'annex.str100' : '',
      legacyIndex: i,
    ),

  // common amulets that actually do something — one row per effect,
  // which is the shape a content author adds to
  ItemDef(
    ref: ItemRef('commonAmulet.ward'),
    nameKey: 'item.commonAmulet.ward',
    kind: ItemKind.commonAmulet,
    modifiers: [Modifier.percent(StatKey.defence, 10)],
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.hawk'),
    nameKey: 'item.commonAmulet.hawk',
    kind: ItemKind.commonAmulet,
    modifiers: [Modifier.add(StatKey.accuracyPhysical, 2)],
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.wind'),
    nameKey: 'item.commonAmulet.wind',
    kind: ItemKind.commonAmulet,
    modifiers: [Modifier.add(StatKey.evasion, 3)],
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.antidote'),
    nameKey: 'item.commonAmulet.antidote',
    kind: ItemKind.commonAmulet,
    immunities: {Ailment.poison},
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.waking'),
    nameKey: 'item.commonAmulet.waking',
    kind: ItemKind.commonAmulet,
    immunities: {Ailment.paralysis},
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.life'),
    nameKey: 'item.commonAmulet.life',
    kind: ItemKind.commonAmulet,
    modifiers: [Modifier.percent(StatKey.maxHitPoints, 10)],
  ),

  // the three that open ground. Common amulets: anyone may wear one.
  // What sets them apart is not who wears them but that the capability
  // reaches the whole party.
  ItemDef(
    ref: ItemRef('commonAmulet.water'),
    nameKey: 'item.commonAmulet.water',
    kind: ItemKind.commonAmulet,
    grants: {Capability.walkOnWater},
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.marsh'),
    nameKey: 'item.commonAmulet.marsh',
    kind: ItemKind.commonAmulet,
    grants: {Capability.walkOnSwamp},
  ),
  ItemDef(
    ref: ItemRef('commonAmulet.levitation'),
    nameKey: 'item.commonAmulet.levitation',
    kind: ItemKind.commonAmulet,
    grants: {Capability.levitate},
  ),

  // Things used up rather than worn (W1-06). The reference name after
  // the dot **is** the key the battle knows them by, so the bridge maps
  // them by stripping the prefix and a test pins that. Giving the
  // catalogue a `battleKey` field instead would put the battle's
  // vocabulary in this package, which is exactly what independence
  // forbids.
  //
  // `legacyIndex` is the position the previous model shipped, because
  // that number reaches saves and scripts.
  for (final (i, key) in const [
    'potion',
    'antidote',
    'elixir',
    'revive_charm',
    'sp_tonic',
    'poison_vial',
    'paralysis_vial',
    'fire_vial',
    'fire_crystal',
    'storm_crystal',
  ].indexed)
    ItemDef(
      ref: ItemRef('consumable.$key'),
      nameKey: 'item.consumable.$key',
      kind: ItemKind.consumable,
      legacyIndex: i,
    ),

  // a held light. One hand, and that is the entire price.
  ItemDef(
    ref: ItemRef('light.torch'),
    nameKey: 'item.light.torch',
    kind: ItemKind.light,
    grants: {Capability.carryLight},
  ),

  // class amulets — these change a rule rather than a number, so each
  // names the class that may wear it
  ItemDef(
    ref: ItemRef('classAmulet.oath_crest'),
    nameKey: 'item.classAmulet.oath_crest',
    kind: ItemKind.classAmulet,
    classMask: ClassMask({CharacterClass.knight}),
    modifiers: [Modifier.add(StatKey.shieldBlock, 10)],
  ),
  ItemDef(
    ref: ItemRef('classAmulet.quiver'),
    nameKey: 'item.classAmulet.quiver',
    kind: ItemKind.classAmulet,
    classMask: ClassMask({CharacterClass.hunter}),
    modifiers: [Modifier.add(StatKey.coatingSlots, 1)],
  ),
  ItemDef(
    ref: ItemRef('classAmulet.prayer_beads'),
    nameKey: 'item.classAmulet.prayer_beads',
    kind: ItemKind.classAmulet,
    classMask: ClassMask({CharacterClass.monk}),
    modifiers: [Modifier.add(StatKey.accuracyPhysical, 3)],
  ),
  ItemDef(
    ref: ItemRef('classAmulet.vow_seal'),
    nameKey: 'item.classAmulet.vow_seal',
    kind: ItemKind.classAmulet,
    classMask: ClassMask({CharacterClass.paladin}),
    modifiers: [Modifier.add(StatKey.defence, 2)],
  ),
  ItemDef(
    ref: ItemRef('classAmulet.venom_pouch'),
    nameKey: 'item.classAmulet.venom_pouch',
    kind: ItemKind.classAmulet,
    classMask: ClassMask({CharacterClass.assassin}),
    modifiers: [Modifier.add(StatKey.coatingSlots, 1)],
  ),
  ItemDef(
    ref: ItemRef('classAmulet.casting_seal'),
    nameKey: 'item.classAmulet.casting_seal',
    kind: ItemKind.classAmulet,
    classMask: ClassMask.type(ClassType.caster),
    modifiers: [Modifier.percent(StatKey.maxSpellPoints, 20)],
  ),
  ItemDef(
    ref: ItemRef('classAmulet.attunement_ring'),
    nameKey: 'item.classAmulet.attunement_ring',
    kind: ItemKind.classAmulet,
    classMask: ClassMask({CharacterClass.esper}),
    modifiers: [Modifier.add(StatKey.espCostRelief, 2)],
  ),
];
