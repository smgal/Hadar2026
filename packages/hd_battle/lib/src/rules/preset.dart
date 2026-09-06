import 'enemy_ai.dart';
import 'weapon.dart';

/// Standing orders (B5-08).
///
/// ## The enemy side already had one — it just had no name
///
/// `enemy_ai.dart` is 291 lines of exactly this: a dispatcher that
/// picks weapon, spell or special, and a casting ladder keyed off
/// `cast_level` 1-6. One preset, implicit, and every creature runs it.
/// Naming them is a refactor, not a rewrite.
///
/// ## The party side is a menu, not an editor
///
/// The original's seventh menu entry — "tell the party to just attack"
/// — is auto-battle with one setting. Presets turn that into a short
/// list each member can pick from, and events lengthen the list
/// (learning a fighting style). **There is no rule editor**: writing
/// conditions is Final Fantasy XII's gambit screen, which is the single
/// most expensive thing in this track's UI budget. Selection only, for
/// now.
///
/// ## Automatic has to be blind
///
/// If a preset is simply better than playing, the optimal move is to
/// stop playing. Dragon Quest IV's AI was disliked for being weak;
/// gambits went the other way and played the game for you. So a preset
/// is allowed to be strong on average and **is not allowed to choose
/// its target** — reading the board is what the player is for.
enum PresetKind {
  /// Swing at whatever is nearest. The original's auto-battle.
  aggressive,

  /// Hold the front, shield up.
  guardian,

  /// Stay back and cast.
  caster,

  /// Keep everyone standing before anything else.
  medic,

  /// Close, strike, and give ground when it turns.
  skirmisher,

  /// Leave when the odds are bad.
  coward,
}

/// A preset's disposition, in the terms the battle can actually read.
class Preset {
  const Preset({
    required this.kind,
    this.wantsFront = false,
    this.wantsBack = false,
    this.bracesWhenHurt = false,
    this.chargesWhenFar = false,
    this.healsBelowPercent = 0,
    this.fleesBelowLevelRatio = 0,
  });

  final PresetKind kind;

  /// Steps forward when there is room.
  final bool wantsFront;

  /// Gives ground when it can.
  final bool wantsBack;

  /// Sets itself once it has taken a beating.
  final bool bracesWhenHurt;

  /// Uses a charging weapon to close.
  final bool chargesWhenFar;

  /// Heals an ally under this share of their maximum.
  final int healsBelowPercent;

  /// Runs when the other side outlevels it by this ratio, as a
  /// percentage. Zero never runs.
  final int fleesBelowLevelRatio;
}

const Map<PresetKind, Preset> presets = {
  PresetKind.aggressive: Preset(
    kind: PresetKind.aggressive,
    wantsFront: true,
    chargesWhenFar: true,
  ),
  PresetKind.guardian: Preset(
    kind: PresetKind.guardian,
    wantsFront: true,
    bracesWhenHurt: true,
  ),
  PresetKind.caster: Preset(kind: PresetKind.caster, wantsBack: true),
  PresetKind.medic: Preset(
    kind: PresetKind.medic,
    wantsBack: true,
    healsBelowPercent: 50,
  ),
  PresetKind.skirmisher: Preset(
    kind: PresetKind.skirmisher,
    chargesWhenFar: true,
    wantsBack: true,
  ),
  PresetKind.coward: Preset(
    kind: PresetKind.coward,
    wantsBack: true,
    fleesBelowLevelRatio: 60,
  ),
};

Preset presetOf(PresetKind kind) => presets[kind]!;

/// Which preset a creature runs, read off what it is.
///
/// The 75-row table is generated from the original binary, so hand
/// assigning all of it is out. Derive the bulk and name the handful
/// worth naming — the same approach the affinity chart takes.
PresetKind enemyPreset({
  required String key,
  required int strength,
  required int agility,
  required int endurance,
  required int castLevel,
  required int specialCastLevel,
  required int level,
}) {
  final named = namedEnemyPresets[key];
  if (named != null) return named;
  if (specialCastLevel > 0) return PresetKind.caster;
  if (castLevel >= 4) return PresetKind.caster;
  if (castLevel > 0) return PresetKind.skirmisher;
  // Fast and fragile things dart in and out rather than trade blows.
  if (agility >= 15 && endurance <= 8) return PresetKind.skirmisher;
  if (strength <= 0) return PresetKind.caster;
  return PresetKind.aggressive;
}

/// Creatures whose behaviour is worth naming by hand.
const Map<String, PresetKind> namedEnemyPresets = {
  // Clever enough to leave when it is plainly losing. The event for it
  // already exists — `EnemyFled`, which B2-10's terror effect uses.
  'goblin': PresetKind.coward,
  'kobold': PresetKind.coward,
  'orc': PresetKind.aggressive,
  'knight': PresetKind.guardian,
  'black_knight': PresetKind.guardian,
  'death_knight': PresetKind.guardian,
};

/// Whether this creature should turn and run.
///
/// Reads the level difference rather than its own health, so a coward
/// that wandered into something far above it leaves early instead of
/// after it has already lost.
bool presetWantsToFlee({
  required Preset preset,
  required int myLevel,
  required int theirLevel,
}) {
  if (preset.fleesBelowLevelRatio <= 0) return false;
  if (theirLevel <= 0) return false;
  return myLevel * 100 < theirLevel * preset.fleesBelowLevelRatio;
}

/// Whether the preset wants to close, given what it is holding.
bool presetWantsToCharge({
  required Preset preset,
  required WeaponProfile weapon,
  required int distance,
}) =>
    preset.chargesWhenFar && weapon.canCharge && distance > weapon.longestReach;

/// The intent an enemy preset leans towards, before the original's own
/// dispatcher gets its say.
///
/// Deliberately a nudge and not a replacement: `chooseEnemyIntent` is
/// ported behaviour and stays in charge of the weapon-versus-magic
/// roll. The preset decides posture — where to stand, when to leave.
EnemyIntent? presetLean(Preset preset) => switch (preset.kind) {
  PresetKind.caster => EnemyIntent.cast,
  PresetKind.guardian => EnemyIntent.weapon,
  PresetKind.aggressive => EnemyIntent.weapon,
  _ => null,
};
