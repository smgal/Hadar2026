import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hadar2026_app/application/battle_bridge/setup_assembly.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/domain/item/consumable_data.dart';
import 'package:hadar2026_app/domain/item/item_lookup.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/party.dart';

/// B6-05 — 소비 아이템이 RPG 쪽에도 생겼다.
///
/// 전에는 전투에만 물건이 있었고(B2-06) 카탈로그에는 장비만 있어서
/// `held` 를 채울 수 없었다. 이제 가방 → `{전투 키: 개수}` → 전투 →
/// `consumedItems` → 가방, 한 바퀴가 돈다.
void main() {
  group('카탈로그', () {
    test('소비품은 어느 부위에도 못 간다', () {
      expect(HDItemType.consumable.equipSlot, isNull);
      expect(HDItemType.consumable.isEtc, isFalse, reason: '원작 범위 밖');
    });

    test('전투 키가 전부 전투 표에 있다 — 빠지면 그 물건은 조용히 안 쓰인다', () {
      for (final c in consumableTable) {
        expect(hb.battleItems.containsKey(c.battleKey), isTrue, reason: c.name);
      }
    });

    test('전투 표의 물건이 전부 카탈로그에 있다 — 반대 방향', () {
      for (final key in hb.battleItems.keys) {
        expect(consumableByBattleKey(key), isNotNull, reason: key);
      }
    });

    test('합친 조회가 소비품을 찾고, 생성 파일은 모른다', () {
      final id = consumableTable[5].id; // 독병
      expect(lookupItem(id)?.name, '독병');
      expect(consumableById(id)?.battleKey, 'poison_vial');
    });
  });

  group('가방 ↔ 전투', () {
    test('빈 파티는 전투에 아무것도 넘기지 않는다', () {
      expect(heldConsumables(HDParty()), isEmpty);
    });

    test('가방의 소비품이 전투 키별 개수로 투영된다', () {
      final party = HDParty();
      for (final id in startingBackpack()) {
        party.give(id);
      }
      final held = heldConsumables(party);
      expect(held['potion'], 3);
      expect(held['poison_vial'], 2);
      expect(held['fire_vial'], 1);
      expect(held.containsKey('fire_crystal'), isFalse, reason: '없는 것은 없다');
    });

    test('assembleSetup 이 가방을 읽는다 — 더는 빈 손이 아니다', () {
      final party = HDParty();
      for (final id in startingBackpack()) {
        party.give(id);
      }
      final setup = assembleSetup(party: party, enemyKeys: ['orc'], seed: 1);
      expect(setup.consumables['potion'], 3);
    });

    test('전투가 쓴 만큼 가방에서 빠진다 — _consume 은 더 비어 있지 않다', () {
      final party = HDParty();
      for (final id in startingBackpack()) {
        party.give(id);
      }
      final before = party.itemCount;
      applyOutcome(
        party,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.win,
          combatants: [],
          goldGained: 0,
          worldEffects: [],
          consumedItems: {'potion': 2, 'poison_vial': 1},
          recruits: [],
          departedSlots: [],
        ),
      );
      expect(party.itemCount, before - 3);
      expect(heldConsumables(party)['potion'], 1);
      expect(heldConsumables(party)['poison_vial'], 1);
    });
  });

  group('새 게임', () {
    test('세션의 파티는 바를 것과 마실 것을 들고 시작한다', () {
      final held = heldConsumables(HDGameSession().party);
      expect(held['potion'], greaterThanOrEqualTo(1));
      expect(held['poison_vial'], greaterThanOrEqualTo(1));
      expect(held['paralysis_vial'], greaterThanOrEqualTo(1));
      expect(held['fire_vial'], greaterThanOrEqualTo(1));
    });
  });
}
