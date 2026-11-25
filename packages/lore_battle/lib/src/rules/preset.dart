import 'weapon.dart';

/// Standing orders — what a member does when the leader hands the round
/// over.
///
/// ## The original has exactly one
///
/// The protagonist's ninth menu line, "일행에게 무조건 공격 할 것을
/// 지시", is auto-battle with a single setting: fighters swing at the
/// first enemy, mages throw their first attack spell if they can pay for
/// it (ch.8.4). `hd_battle` turned that one setting into a short list
/// each member picks from, and the fork keeps the list.
///
/// ## A menu, not an editor
///
/// Selection only. Writing conditions is Final Fantasy XII's gambit
/// screen, and a preset that is simply better than playing makes not
/// playing optimal. So a preset may be strong on average and **may not
/// choose its target** — it takes the first enemy standing, as the
/// original's did. Reading the board is what the player is for.
enum PresetKind {
  /// Swing at whatever is first. The original's auto-battle.
  aggressive,

  /// Hold the front, guard up once hurt.
  guardian,

  /// Stay back and cast.
  caster,

  /// Keep everyone standing before anything else.
  medic,

  /// Close, strike, and give ground when it turns.
  skirmisher,
}

/// A preset's disposition, in the terms the battle can actually read.
class Preset {
  const Preset({
    required this.kind,
    this.bracesWhenHurt = false,
    this.chargesWhenFar = false,
    this.castsWhenAble = true,
  });

  final PresetKind kind;

  /// Sets itself once it has lost half its hit points.
  final bool bracesWhenHurt;

  /// Uses a charging weapon to close.
  final bool chargesWhenFar;

  /// A caster under this preset throws its first attack spell when it
  /// can afford to (ch.8.4's rule for mages).
  final bool castsWhenAble;
}

const Map<PresetKind, Preset> presets = {
  PresetKind.aggressive: Preset(
    kind: PresetKind.aggressive,
    chargesWhenFar: true,
  ),
  PresetKind.guardian: Preset(
    kind: PresetKind.guardian,
    bracesWhenHurt: true,
    castsWhenAble: false,
  ),
  PresetKind.caster: Preset(kind: PresetKind.caster),
  PresetKind.medic: Preset(kind: PresetKind.medic, castsWhenAble: false),
  PresetKind.skirmisher: Preset(
    kind: PresetKind.skirmisher,
    chargesWhenFar: true,
  ),
};

Preset presetOf(PresetKind kind) => presets[kind]!;

/// Whether the preset wants to close, given what it is holding.
bool presetWantsToCharge({
  required Preset preset,
  required WeaponProfile weapon,
  required int distance,
}) =>
    preset.chargesWhenFar && weapon.canCharge && distance > weapon.longestReach;

/// Whether a caster on auto-battle throws a spell rather than swing.
///
/// Ch.8.4: attack skill of 10 or more, and **more magic points than the
/// skill value** — the original's own margin, which keeps an automatic
/// caster from spending its last points on a first-tier arrow.
bool autoCasts({
  required Preset preset,
  required int attackSkill,
  required int mp,
}) => preset.castsWhenAble && attackSkill >= 10 && mp > attackSkill;
