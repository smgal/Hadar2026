import '../contract/battle_setup.dart';
import 'enemy_data.dart';
import 'enemy_table_ep1.dart';
import 'enemy_table_ep2.dart';
import 'enemy_table_ep3.dart';

/// The three enemy tables, and how a key in a setup is resolved.
///
/// **One table per part, never merged.** The three parts number their
/// enemies differently — Part 1's 62 is a Draconian and Part 3's is a
/// revenant — and a key that appears in two of them (`draconian`,
/// `vampire`) names two different rows with different hit points. So a
/// key only means something next to an episode, and
/// `BattleSetup.episode` is what picks the table.

/// The table for [episode] (1, 2 or 3).
List<EnemyData> enemyTableFor(int episode) => switch (episode) {
  1 => enemyTableEp1,
  2 => enemyTableEp2,
  3 => enemyTableEp3,
  _ => throw ArgumentError('no enemy table for episode $episode'),
};

final Map<int, Map<String, EnemyData>> _byKey = {
  for (final episode in const [1, 2, 3])
    episode: {for (final e in enemyTableFor(episode)) e.key: e},
};

final Map<int, Map<int, EnemyData>> _byLegacyId = {
  for (final episode in const [1, 2, 3])
    episode: {for (final e in enemyTableFor(episode)) e.legacyId: e},
};

/// A row by key, or null.
EnemyData? enemyByKey(int episode, String key) => _byKey[episode]?[key];

/// A row by its original number — **1-based, as the documents print
/// it** — or null.
EnemyData? enemyByLegacyId(int episode, int legacyId) =>
    _byLegacyId[episode]?[legacyId];

/// A table row fielded under another name or with other numbers.
///
/// The original keeps loading one row and changing a field or two to
/// make a boss of it; the documents list each of those and ask the
/// remake to treat them as enemies in their own right. A variant is
/// that: a key of its own that resolves to a base row plus the override
/// the documents describe.
class EnemyVariant {
  const EnemyVariant(this.baseKey, this.override);

  final String baseKey;
  final EnemyOverride override;
}

/// Part 3 (ch.12.2 비고).
const Map<String, EnemyVariant> enemyVariantsEp3 = {
  // Draconian's numbers under a believer's name.
  'draconian_believer': EnemyVariant(
    'draconian',
    EnemyOverride(nameKey: 'draconian_believer'),
  ),
  // An Orc mage's row with a Troll's name and a higher level. **Only
  // the level changes** — hit points stay at the row's own 360.
  'troll_magic_user_lv5': EnemyVariant(
    'orc_magic_user',
    EnemyOverride(nameKey: 'troll_magic_user', level: 5, hp: 360),
  ),
  'troll_magic_user_lv6': EnemyVariant(
    'orc_magic_user',
    EnemyOverride(nameKey: 'troll_magic_user', level: 6, hp: 360),
  ),
  // Two bosses that are a row plus 분신.
  'dracon_emperor_17': EnemyVariant(
    'archdraconian',
    EnemyOverride(
      nameKey: 'dracon_emperor_17',
      abilities: {
        EnemyAbility.mindControl,
        EnemyAbility.armourBreak,
        EnemyAbility.summonAlly,
        EnemyAbility.clone,
      },
    ),
  ),
  'dracon_guardian_spirit': EnemyVariant(
    'draconian_king',
    EnemyOverride(
      nameKey: 'dracon_guardian_spirit',
      abilities: {
        EnemyAbility.mindControl,
        EnemyAbility.armourBreak,
        EnemyAbility.summonAlly,
        EnemyAbility.massDeath,
        EnemyAbility.healAll,
        EnemyAbility.clone,
      },
    ),
  ),
  // The trapped chests raise the level, and hit points follow it.
  'death_messenger_lv30': EnemyVariant(
    'death_messenger',
    EnemyOverride(level: 30),
  ),
  'cerberus_lv15': EnemyVariant('cerberus', EnemyOverride(level: 15)),
};

/// Part 1 (1st/08 8.1 "이름을 바꿔 쓰는 적").
///
/// `rewardLevel` / `rewardAc` are the level and armour class of the row
/// the original pays these by — the document's "경험치·금 기준 N번".
const Map<String, EnemyVariant> enemyVariantsEp1 = {
  'major_mummy': EnemyVariant(
    'mummy',
    EnemyOverride(nameKey: 'major_mummy', ac: 1),
  ),
  // Sprite's row at level 4 with hit points still worked out at 9.
  // Paid and persuaded as a Kelpie (row 20: level 5, armour 2).
  'sphinx': EnemyVariant(
    'sprite',
    EnemyOverride(
      nameKey: 'sphinx',
      level: 4,
      hp: 18,
      special: EnemySpecial.none,
      persuadable: true,
      persuadeLevel: 5,
      rewardLevel: 5,
      rewardAc: 2,
    ),
  ),
  // Paid as row 1 (level 1, armour 1).
  'camp_soldier': EnemyVariant(
    'mummy',
    EnemyOverride(
      nameKey: 'camp_soldier',
      special: EnemySpecial.none,
      castLevel: 0,
      rewardLevel: 1,
      rewardAc: 1,
    ),
  ),
  'zombie': EnemyVariant('vampire', EnemyOverride(nameKey: 'zombie')),
  'archi_gagoyle': EnemyVariant(
    'gagoyle',
    EnemyOverride(nameKey: 'archi_gagoyle'),
  ),
  // Level 8, hit points still the Hydra's 260; paid as row 34
  // (level 9, armour 2).
  'hydra_head': EnemyVariant(
    'hydra',
    EnemyOverride(
      nameKey: 'hydra_head',
      level: 8,
      hp: 260,
      rewardLevel: 9,
      rewardAc: 2,
    ),
  ),
  // The second head: level 10, paid as row 39 (level 10, armour 3).
  'hydra_head_2': EnemyVariant(
    'hydra',
    EnemyOverride(
      nameKey: 'hydra_head',
      level: 10,
      hp: 260,
      rewardLevel: 10,
      rewardAc: 3,
    ),
  ),
  'huge_dragon': EnemyVariant('dragon', EnemyOverride(nameKey: 'huge_dragon')),
  'dragon_tail': EnemyVariant(
    'rampager',
    EnemyOverride(nameKey: 'dragon_tail', ac: 8),
  ),
  // Keeps the Crab God's name. Paid as row 25 (level 7, armour 2).
  'crab_god_soldier': EnemyVariant(
    'crab_god',
    EnemyOverride(level: 7, hp: 210, rewardLevel: 7, rewardAc: 2),
  ),
  // Paid as row 1, which is also why it never calls reinforcements.
  'fake_necromancer': EnemyVariant(
    'archi_draconian',
    EnemyOverride(
      nameKey: 'necromancer',
      superLevel: 0,
      rewardLevel: 1,
      rewardAc: 1,
    ),
  ),
};

/// Part 2 (2nd/08 8.1 "이름을 바꿔 쓰는 적").
const Map<String, EnemyVariant> enemyVariantsEp2 = {
  // Three names over one row; paid as row 1 (level 1, armour 1).
  'soldier': EnemyVariant(
    'mummy',
    EnemyOverride(
      nameKey: 'soldier',
      special: EnemySpecial.none,
      castLevel: 0,
      rewardLevel: 1,
      rewardAc: 1,
    ),
  ),
  'guard': EnemyVariant(
    'mummy',
    EnemyOverride(
      nameKey: 'guard',
      special: EnemySpecial.none,
      castLevel: 0,
      rewardLevel: 1,
      rewardAc: 1,
    ),
  ),
  'bank_guard': EnemyVariant(
    'mummy',
    EnemyOverride(
      nameKey: 'bank_guard',
      special: EnemySpecial.none,
      castLevel: 0,
      rewardLevel: 1,
      rewardAc: 1,
    ),
  ),
  // The gang's leader keeps its name and hit points.
  'devil_hunter_boss': EnemyVariant(
    'devil_hunter',
    EnemyOverride(
      strength: 100,
      hp: 700,
      special: EnemySpecial.none,
      castLevel: 0,
    ),
  ),
  // The eighth wisp: endurance 30, so 2700 hit points.
  'wisp_eighth': EnemyVariant(
    'wisp',
    EnemyOverride(endurance: 30, castLevel: 6),
  ),
  'giant_cyclops': EnemyVariant(
    'cyclops',
    EnemyOverride(
      nameKey: 'giant_cyclops',
      strength: 60,
      physicalResistance: 80,
      magicResistance: 80,
    ),
  ),
  // Euryale's row under the Lizard Man's name — resistance and armour
  // 255, so weapons and attack magic do not touch it.
  'revived_lizard_man': EnemyVariant(
    'euryale',
    EnemyOverride(nameKey: 'lizard_man'),
  ),
  'last_guardian': EnemyVariant(
    'armored_viper',
    EnemyOverride(nameKey: 'last_guardian', superLevel: 1),
  ),
  'sirian_caminus': EnemyVariant(
    'mephistopheles',
    EnemyOverride(nameKey: 'sirian_caminus'),
  ),
  // The eight he splits into.
  'sirian_caminus_split': EnemyVariant(
    'mephistopheles',
    EnemyOverride(
      nameKey: 'sirian_caminus',
      physicalResistance: 255,
      magicResistance: 255,
    ),
  ),
};

/// The variants of [episode].
Map<String, EnemyVariant> enemyVariantsFor(int episode) => switch (episode) {
  1 => enemyVariantsEp1,
  2 => enemyVariantsEp2,
  3 => enemyVariantsEp3,
  _ => const <String, EnemyVariant>{},
};

/// Resolves a key from a setup: a table row, or a variant's base row
/// with its override. Null when the episode has neither.
({EnemyData data, EnemyOverride? override})? resolveEnemy(
  int episode,
  String key,
) {
  final row = enemyByKey(episode, key);
  if (row != null) return (data: row, override: null);
  final variant = enemyVariantsFor(episode)[key];
  if (variant == null) return null;
  final base = enemyByKey(episode, variant.baseKey);
  if (base == null) return null;
  return (data: base, override: variant.override);
}
