import 'package:flutter/foundation.dart';
import 'package:hd_battle/hd_battle.dart' as hb;

import '../../domain/item/consumable_data.dart';
import '../../domain/item/item_data.dart';
import '../../domain/item/item_type.dart';
import '../../domain/party/party.dart';
import '../../domain/party/player.dart';
import 'weapon_mapping.dart';

/// RPG 파티 → 전투 개시 입력 (B3-02 · B3-03).
///
/// **전투는 RPG 를 모른다.** 장비 슬롯도 아이템 표도 넘어가지 않고, 파생값은
/// 여기서 전부 풀어서 넘긴다 — 규격이 그렇게 정해져 있고
/// (`packages/hd_battle/CONTRACT.md`), 그 덕에 전투를 헤드리스로 돌릴 수 있다.
///
/// 반대 방향은 [applyOutcome] 이다.

/// 파티원 하나를 전투가 보는 모습으로.
hb.CombatantSnapshot snapshotOf(HDPlayer p) {
  final hand = p.equippedAt(HDEquipSlot.hand);
  return hb.CombatantSnapshot(
    slot: p.order,
    name: p.name.text,
    characterClass: p.characterClass,
    strength: p.strength,
    mentality: p.mentality,
    concentration: p.concentration,
    endurance: p.endurance,
    resistance: p.resistance,
    agility: p.agility,
    luck: p.luck,
    // `ac` 는 이미 baseAc + 장비분이다. 부위별 분해는 아래에서 따로 넘긴다.
    ac: p.ac,
    armour: _armourOf(p),
    hp: p.hp,
    maxHp: p.maxHp,
    sp: p.sp,
    maxSp: p.maxSp,
    esp: p.esp,
    maxEsp: p.maxEsp,
    accuracyPhysical: p.accuracy.physical,
    accuracyMagic: p.accuracy.magic,
    accuracyEsp: p.accuracy.esp,
    levelPhysical: p.level.physical,
    levelMagic: p.level.magic,
    levelEsp: p.level.esp,
    powOfWeapon: p.powOfWeapon,
    weaponName: weaponNameOf(hand),
    weaponKey: weaponKeyOf(hand),
    rank: rankOf(p),
    poison: p.poison,
    unconscious: p.unconscious,
    dead: p.dead,
  );
}

/// 부위별 방어구와 방패 (B2-08 → 규격).
///
/// 슬롯이 비어 있으면 빈 값을 주고, 그러면 전투가 `ac` 하나로 되돌아간다 —
/// 부위를 모르는 저장 파일에서 올라와도 그대로 싸워진다.
hb.ArmourPieces _armourOf(HDPlayer p) {
  int acAt(HDEquipSlot slot) {
    final id = p.equippedAt(slot);
    return id == null ? 0 : (itemById(id)?.param.ac ?? 0);
  }

  final shield = p.equippedAt(HDEquipSlot.handSub);
  final body = acAt(HDEquipSlot.armor);
  final head = acAt(HDEquipSlot.head);
  final leg = acAt(HDEquipSlot.leg);
  // 원작 Unity 포트의 ORNAMENT 자리는 이 레포에서 `etc` 다.
  final ornament = acAt(HDEquipSlot.etc);
  if (body == 0 && head == 0 && leg == 0 && ornament == 0 && shield == null) {
    return const hb.ArmourPieces();
  }
  return hb.ArmourPieces(
    body: body,
    head: head,
    leg: leg,
    ornament: ornament,
    // 방패의 방어도를 막을 확률로 읽는다. 원작에 이 개념이 없어서 B2-08 이
    // 만든 축이고, 값의 대응은 여기가 정한다.
    shieldBlock: shield == null
        ? 0
        : ((itemById(shield)?.param.ac ?? 0) * 5).clamp(0, hb.maxShieldBlock),
  );
}

/// 그 사람이 어느 열에 서는가 (B5-01).
///
/// **대열은 전투 밖에서 정한다** — 드래곤 퀘스트 IV·V 의 「대열」이다.
/// 아직 그 화면이 없으므로(B4) 슬롯 순서에서 유도한다: 0-1 앞 · 2-3 중 ·
/// 4-5 뒤. 근접 무기는 뒷열에서 아무 데도 닿지 않으므로 때리는 사람이
/// 앞에 오는 배치이고, 화면이 생기면 여기가 그 값을 읽게 된다.
int rankOf(HDPlayer p) => p.order < 2 ? 1 : (p.order < 4 ? 2 : 3);

/// 전투 개시 입력 전부.
///
/// [enemyKeys] 는 cm2 `Battle::RegisterEnemy` 가 모아 준 것이다.
hb.BattleSetup assembleSetup({
  required HDParty party,
  required List<String> enemyKeys,
  required int seed,
  int mode = 0,
  List<int> enemyRanks = const [],
  Map<String, int> consumables = const {},
}) {
  return hb.BattleSetup(
    party: [
      for (final p in party.players)
        if (p.isValid()) snapshotOf(p),
    ],
    enemyKeys: enemyKeys,
    enemyRanks: enemyRanks,
    seed: seed,
    mode: mode,
    // 가방의 소비품을 `{전투 키: 개수}` 로 투영한다 (B6-05). 가방 자체는
    // 넘기지 않는다 — 전투가 쓴 것만 `consumedItems` 로 돌아온다.
    consumables: consumables.isNotEmpty ? consumables : heldConsumables(party),
    // 빈 슬롯이 몇 칸인지 전투가 알아야 정원을 판정한다 (B5-09).
    partyCapacity: party.players.length,
  );
}

/// 정산 결과를 파티에 되쓴다 (B3-02).
///
/// **정확히 한 번만** 반영한다. 예전 전투는 RPG 상태를 직접 고쳤고 경험치를
/// 두 곳에서 더했다 — 그래서 무엇이 언제 바뀌는지 추적할 수 없었다.
///
/// 레벨업은 여기서 하지 않는다(B3-05). 경험치는 더하고, 올릴지는 RPG 가
/// 따로 판정한다 — 규격이 그렇게 나눠 놓았다.
void applyOutcome(HDParty party, hb.BattleOutcome outcome) {
  for (final result in outcome.combatants) {
    final p = _bySlot(party, result.slot);
    if (p == null) continue;
    p.hp = result.hp;
    p.sp = result.sp;
    p.esp = result.esp;
    p.poison = result.poison;
    p.unconscious = result.unconscious;
    p.dead = result.dead;
    p.experience += result.experienceGained;
  }

  // 전투가 잃은 슬롯 — 죽음이 아니라 **부재**다. 되살릴 수 없고 자리를
  // 비워야 한다 (B2-11).
  for (final slot in outcome.departedSlots) {
    _bySlot(party, slot)?.name = '';
  }

  // 전투가 더한 파티원. 규격 v2 부터 **실제 앉은 슬롯**을 싣는다.
  for (final joined in outcome.recruits) {
    final p = _bySlot(party, joined.slot);
    if (p == null) continue;
    _fillFrom(p, joined);
  }

  party.gold += outcome.goldGained;
  outcome.consumedItems.forEach((key, count) {
    // 가방은 RPG 가 줄인다 — 전투는 무엇을 썼는지만 보고한다.
    _consume(party, key, count);
  });
}

HDPlayer? _bySlot(HDParty party, int slot) {
  for (final p in party.players) {
    if (p.order == slot) return p;
  }
  return null;
}

void _fillFrom(HDPlayer p, hb.CombatantSnapshot s) {
  p.name = s.name;
  p.strength = s.strength;
  p.mentality = s.mentality;
  p.endurance = s.endurance;
  p.resistance = s.resistance;
  p.agility = s.agility;
  p.baseAc = s.ac;
  p.hp = s.hp;
  p.maxHp = s.maxHp;
  p.accuracy.physical = s.accuracyPhysical;
  p.accuracy.magic = s.accuracyMagic;
  p.level.physical = s.levelPhysical;
  p.poison = s.poison;
  p.unconscious = s.unconscious;
  p.dead = s.dead;
}

/// 가방의 소비품을 전투 키별 개수로 (B6-05).
Map<String, int> heldConsumables(HDParty party) {
  final held = <String, int>{};
  for (var i = 0; i < party.itemCapacity; i++) {
    final id = party.itemAt(i);
    if (id == null) continue;
    final c = consumableById(id);
    if (c == null) continue;
    held[c.battleKey] = (held[c.battleKey] ?? 0) + 1;
  }
  return held;
}

/// 전투에서 쓴 물건을 가방에서 뺀다 (B6-05).
///
/// 전투 키 ↔ 아이템 대응은 `consumable_data.dart` 한 곳에 있다. 모르는 키는
/// 경고를 남긴다 — 조용히 넘어가면 가방이 줄지 않는데 전투는 썼다고 믿는다.
void _consume(HDParty party, String key, int count) {
  final c = consumableByBattleKey(key);
  if (c == null) {
    debugPrint('[battle] consumed "$key" x$count has no item — not removed');
    return;
  }
  for (var i = 0; i < count; i++) {
    if (!party.take(c.id)) {
      debugPrint('[battle] "$key" was spent but the pack had none left');
      return;
    }
  }
}
