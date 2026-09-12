import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_world/hd_world.dart' as hw;

/// Turns a fighting style into the key a battle looks its reach up by.
///
/// ## Why this is a translation and not a shared enum
///
/// The two packages divide the weapon deliberately: the world owns
/// **how hard** it hits and what shape it is, the battle owns **how it
/// reaches**. A shared enum would make one of them depend on the other
/// and put every future reach change in both.
///
/// So a style plus what the main hand actually is maps to a key here,
/// and this file is the only place that has to change when either side
/// grows a row.
///
/// ## The style alone is not enough
///
/// "One weapon, free hand" says nothing about whether it cuts, thrusts
/// or crushes, and the battle's table is keyed by that. So the main
/// hand's own kind and shape come along.
String weaponKeyFor({
  required hw.WeaponKind style,
  hw.ItemKind? mainHandKind,
  hw.WeaponShape? mainHandShape,
}) => switch (style) {
  hw.WeaponKind.unarmed => 'unarmed',

  // The one-weapon family is named by how the blow lands. A short spear
  // keeps its length whether or not the other hand carries anything.
  hw.WeaponKind.oneHanded ||
  hw.WeaponKind.torchbearer ||
  hw.WeaponKind.dualWield => _oneHandedKey(mainHandKind, mainHandShape),

  hw.WeaponKind.swordAndShield => mainHandShape == hw.WeaponShape.mace
      ? 'mace'
      : 'sword_shield',
  hw.WeaponKind.spearAndShield => 'spear',

  hw.WeaponKind.greatSword => 'great_sword',
  hw.WeaponKind.warHammer => 'war_hammer',
  hw.WeaponKind.longStaff => 'staff',

  // A hafted head thrusts if it is a spear and cuts if it is an axe.
  hw.WeaponKind.polearm => mainHandShape == hw.WeaponShape.axe
      ? 'poleaxe'
      : (mainHandKind == hw.ItemKind.slashWeapon ? 'poleaxe' : 'halberd'),

  hw.WeaponKind.lance => 'lance',
  hw.WeaponKind.bow => 'bow',
  hw.WeaponKind.crossbow => 'crossbow',
  hw.WeaponKind.arbalest => 'arbalest',
  hw.WeaponKind.thrown => 'thrown',
};

String _oneHandedKey(hw.ItemKind? kind, hw.WeaponShape? shape) {
  if (shape == hw.WeaponShape.spear) return 'spear';
  if (shape == hw.WeaponShape.mace) return 'mace';
  return switch (kind) {
    hw.ItemKind.slashWeapon => 'one_hand_slash',
    // A chopping weapon that is not a mace is an axe, and an axe cuts.
    hw.ItemKind.chopWeapon => 'one_hand_slash',
    hw.ItemKind.pierceWeapon => 'dagger',
    hw.ItemKind.bluntWeapon => 'club',
    hw.ItemKind.missileWeapon => 'thrown',
    // A summoned creature's attack is a natural weapon, not something
    // held: it claws or bites at arm's length, which is what bare hands
    // already describe. Named here rather than left to the fallback so
    // the choice is visible.
    hw.ItemKind.summonSingle || hw.ItemKind.summonMulti => 'unarmed',
    _ => 'unarmed',
  };
}

/// Whether the battle actually has a row for [key].
///
/// Called by a test rather than by the runtime: `weaponFor` already
/// falls back to bare hands, and a silent fallback is exactly what has
/// to be caught before shipping rather than in a fight.
bool battleKnowsWeapon(String key) => hb.weaponTable.containsKey(key);
