import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hd_world/hd_world.dart' as hw;

import 'consumables.dart';
import 'standing_order.dart';
import 'weapon_key.dart';

/// Builds a battle's opening input from a party.
///
/// ## Everything derived is resolved here, once
///
/// The battle takes numbers, not equipment: it has no slot table and no
/// item catalogue, by design. So this reads each member through
/// `resolveStats` and hands over the answers — worn armour, the shield's
/// block chance, how hard the weapon hits, which reach table to use.
///
/// ## The slot is the seat, not the position in a filtered list
///
/// A party is a roster of seats and some of them are empty. The slot a
/// battle uses is the **seat number**, so an absent member simply does
/// not come along and everyone else keeps the number they had. Shipped
/// scripts configure the sixth seat for somebody who joins later, so
/// renumbering would move that member.
///
/// The battle also derives the opening rank from the seat — front,
/// middle, back by pairs.
hb.BattleSetup toBattleSetup(
  hw.World world, {
  required List<String> enemyKeys,
  required int seed,
  int mode = 0,
  List<int> enemyRanks = const [],
  int? initialGap,
}) {
  final members = world.members;
  return hb.BattleSetup(
    party: [
      for (final (index, member) in members.indexed)
        if (member.isPresent)
          snapshotOf(member, index: index, catalog: world.catalog),
    ],
    enemyKeys: enemyKeys,
    enemyRanks: enemyRanks,
    seed: seed,
    mode: mode,
    initialGap: initialGap,
    consumables: heldConsumables(world.pack),
    // Empty seats are what the battle seats a recruit into, so the
    // capacity is the whole roster and not the head count.
    partyCapacity: members.length,
  );
}

/// One member, resolved.
hb.CombatantSnapshot snapshotOf(
  hw.Member member, {
  required int index,
  required hw.ItemCatalog catalog,
}) {
  final stats = hw.resolveStats(member: member, catalog: catalog);
  int at(hw.StatKey key) => stats[key];
  return hb.CombatantSnapshot(
    slot: index,
    name: member.name,
    characterClass: member.clazz.wire,
    strength: at(hw.StatKey.strength),
    mentality: at(hw.StatKey.mentality),
    concentration: at(hw.StatKey.concentration),
    endurance: at(hw.StatKey.endurance),
    resistance: at(hw.StatKey.resistance),
    agility: at(hw.StatKey.agility),
    luck: at(hw.StatKey.luck),
    // The battle keeps a single armour number for anything that arrives
    // without pieces; the pieces are what it prefers, so send both.
    ac: at(hw.StatKey.defence),
    armour: hb.ArmourPieces(
      body: at(hw.StatKey.defence),
      shieldBlock: at(hw.StatKey.shieldBlock),
    ),
    hp: member.hitPoints,
    maxHp: at(hw.StatKey.maxHitPoints),
    sp: member.spellPoints,
    maxSp: at(hw.StatKey.maxSpellPoints),
    esp: member.espPoints,
    maxEsp: at(hw.StatKey.maxEspPoints),
    accuracyPhysical: at(hw.StatKey.accuracyPhysical),
    accuracyMagic: at(hw.StatKey.accuracyMagic),
    accuracyEsp: at(hw.StatKey.accuracyEsp),
    levelPhysical: member.levels.physical,
    levelMagic: member.levels.magic,
    levelEsp: member.levels.esp,
    powOfWeapon: stats.attackPower,
    weaponName: member.at(hw.EquipSlot.rightHand)?.value ?? '',
    weaponKey: weaponKeyFor(
      style: stats.weaponKind,
      mainHandKind: stats.mainHandKind,
      mainHandShape: stats.mainHandShape,
    ),
    // BP-45: what the style adds beyond reach, resolved to numbers. The
    // battle never sees both hands, so it cannot work these out.
    strikes: stats.strikes,
    coatingSlots: at(hw.StatKey.coatingSlots),
    evasionBonus: at(hw.StatKey.evasion),
    initiativeBonus: at(hw.StatKey.initiative),
    preset: presetFor(member.style),
    knownPresets: knownPresetsFor(member.clazz),
    // The conditions the party walked in with. They are the world's —
    // poison decays with rest, not at the end of a fight — so they go
    // over and come back rather than being reset on either side.
    poison: member.poison,
    unconscious: member.unconscious,
    dead: member.dead,
  );
}
