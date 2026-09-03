import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/equipment_flow.dart';
import 'package:hadar2026_app/application/menu_flows.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/party.dart';
import 'package:hadar2026_app/domain/party/player.dart';

const _dagger = HDItemId(HDItemType.stab, index: 1); // 단도
const _longSword = HDItemId(HDItemType.wield, index: 6); // 장검
const _bareHand = HDItemId(HDItemType.wield, index: 0); // 맨손
const _goldShield = HDItemId(HDItemType.shield, index: 5);
const _leatherArmor = HDItemId(HDItemType.armor, index: 1);
const _crown = HDItemId(HDItemType.head, index: 10);
const _wingedShoes = HDItemId(HDItemType.leg, index: 4);
const _belt = HDItemId(HDItemType.ornament, index: 1);

/// Answers every showWindowMenu from a script written in advance, so a
/// whole three-step flow runs with no rendering surface at all.
class _ScriptedUi implements UiHost {
  _ScriptedUi(this.answers);

  final List<int> answers;
  final List<List<String>> menus = [];
  final List<String> lines = [];
  final List<String> messages = [];
  int _next = 0;

  @override
  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) async {
    menus.add(items);
    if (_next >= answers.length) return 0; // out of script -> cancel
    return answers[_next++];
  }

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async =>
      lines.add(message);

  @override
  Future<void> showMessageWindow(String text, {int? x, int? y}) async =>
      messages.add(text);

  @override
  Future<void> waitForAnyKey() async {}

  @override
  void clearLogs() {}

  @override
  void refresh() {}

  @override
  void beginNarrative() {}

  @override
  Future<void> endNarrative({String? summary, bool autoFlush = true}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Unused implements PartyMovementHost, AssetSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used by these tests');
}

/// Total items the party owns, wherever they sit. Every flow below must
/// leave this unchanged.
int _totalItems(HDParty party, List<HDPlayer> players) {
  var n = party.itemCount;
  for (final p in players) {
    for (final slot in HDEquipSlot.values) {
      if (p.equippedAt(slot) != null) n++;
    }
  }
  return n;
}

void main() {
  group('candidatesFor', () {
    test('offers only what fits the body part', () {
      final party = HDParty();
      for (final id in [
        _dagger,
        _longSword,
        _goldShield,
        _leatherArmor,
        _crown,
        _wingedShoes,
        _belt,
      ]) {
        party.give(id);
      }

      List<HDItemId> idsFor(HDEquipSlot slot) => HDEquipmentFlow
          .candidatesFor(party, slot)
          .map((i) => party.itemAt(i)!)
          .toList();

      expect(idsFor(HDEquipSlot.hand), [_dagger, _longSword]);
      expect(idsFor(HDEquipSlot.handSub), [_goldShield]);
      expect(idsFor(HDEquipSlot.armor), [_leatherArmor]);
      expect(idsFor(HDEquipSlot.head), [_crown]);
      expect(idsFor(HDEquipSlot.leg), [_wingedShoes]);
      expect(idsFor(HDEquipSlot.etc), [_belt]);
    });

    test('armour never shows up as a helmet candidate', () {
      final party = HDParty()..give(_leatherArmor);
      expect(HDEquipmentFlow.candidatesFor(party, HDEquipSlot.head), isEmpty);
    });
  });

  group('equipFromBackpack', () {
    test('swapping conserves the item count', () {
      final party = HDParty()
        ..give(_dagger)
        ..give(_longSword);
      final p = HDPlayer();
      final before = _totalItems(party, [p]);

      expect(
        HDEquipmentFlow.equipFromBackpack(party, p, HDEquipSlot.hand, 0),
        isTrue,
      );
      expect(p.equippedAt(HDEquipSlot.hand), _dagger);
      expect(_totalItems(party, [p]), before);

      // Now wear the other one; the first must come back to the bag.
      final slot = HDEquipmentFlow
          .candidatesFor(party, HDEquipSlot.hand)
          .first;
      expect(
        HDEquipmentFlow.equipFromBackpack(party, p, HDEquipSlot.hand, slot),
        isTrue,
      );
      expect(p.equippedAt(HDEquipSlot.hand), _longSword);
      expect(party.has(_dagger), isTrue);
      expect(_totalItems(party, [p]), before);
    });

    test('a full backpack can still swap', () {
      final party = HDParty();
      for (var i = 0; i < party.itemCapacity; i++) {
        party.give(_dagger);
      }
      final p = HDPlayer();
      p.equipItem(HDEquipSlot.hand, _longSword);
      final before = _totalItems(party, [p]);

      expect(
        HDEquipmentFlow.equipFromBackpack(party, p, HDEquipSlot.hand, 0),
        isTrue,
      );
      expect(p.equippedAt(HDEquipSlot.hand), _dagger);
      expect(party.has(_longSword), isTrue);
      expect(_totalItems(party, [p]), before);
    });

    test('refuses the wrong body part and changes nothing', () {
      final party = HDParty()..give(_leatherArmor);
      final p = HDPlayer();
      expect(
        HDEquipmentFlow.equipFromBackpack(party, p, HDEquipSlot.head, 0),
        isFalse,
      );
      expect(p.equippedAt(HDEquipSlot.head), isNull);
      expect(party.itemAt(0), _leatherArmor);
    });

    test('an empty backpack slot is refused', () {
      final party = HDParty();
      expect(
        HDEquipmentFlow.equipFromBackpack(party, HDPlayer(),
            HDEquipSlot.hand, 3),
        isFalse,
      );
    });
  });

  group('unequipToBackpack', () {
    test('moves the item to the bag and conserves the count', () {
      final party = HDParty();
      final p = HDPlayer()..equipItem(HDEquipSlot.armor, _leatherArmor);
      final before = _totalItems(party, [p]);

      expect(
        HDEquipmentFlow.unequipToBackpack(party, p, HDEquipSlot.armor),
        isTrue,
      );
      expect(p.equippedAt(HDEquipSlot.armor), isNull);
      expect(party.itemAt(0), _leatherArmor);
      expect(_totalItems(party, [p]), before);
    });

    // GameEventEquipment.cs:122
    test('bare hands cannot be taken off', () {
      final party = HDParty();
      final p = HDPlayer()..equipItem(HDEquipSlot.hand, _bareHand);
      expect(
        HDEquipmentFlow.unequipToBackpack(party, p, HDEquipSlot.hand),
        isFalse,
      );
      expect(p.equippedAt(HDEquipSlot.hand), _bareHand);
      expect(party.itemCount, 0);
      expect(
        HDEquipmentFlow.canUnequip(party, p, HDEquipSlot.hand),
        isFalse,
      );
    });

    // Refusing beats dropping it on the floor.
    test('a full backpack refuses the unequip and keeps the item worn', () {
      final party = HDParty();
      for (var i = 0; i < party.itemCapacity; i++) {
        party.give(_dagger);
      }
      final p = HDPlayer()..equipItem(HDEquipSlot.armor, _leatherArmor);
      final before = _totalItems(party, [p]);

      expect(
        HDEquipmentFlow.unequipToBackpack(party, p, HDEquipSlot.armor),
        isFalse,
      );
      expect(p.equippedAt(HDEquipSlot.armor), _leatherArmor);
      expect(party.itemCount, 20);
      expect(_totalItems(party, [p]), before);
      expect(
        HDEquipmentFlow.canUnequip(party, p, HDEquipSlot.armor),
        isFalse,
      );
    });

    test('an empty slot is refused', () {
      expect(
        HDEquipmentFlow.unequipToBackpack(
            HDParty(), HDPlayer(), HDEquipSlot.leg),
        isFalse,
      );
    });
  });

  group('the menu flow end to end', () {
    late _ScriptedUi ui;

    void bind(List<int> answers) {
      ui = _ScriptedUi(answers);
      HDHosts().bind(ui: ui, movement: _Unused(), assets: _Unused());
    }

    tearDown(HDHosts().reset);

    test('picks a person, a part, then an item', () async {
      final party = HDGameSession().party;
      for (var i = 0; i < party.itemCapacity; i++) {
        final id = party.itemAt(i);
        if (id != null) party.take(id);
      }
      party.give(_crown);
      final player = party.players.first;
      player.unequip(HDEquipSlot.head);

      // person 1 -> part 4 (머리) -> item 1 -> Esc out of the part menu.
      bind([1, 4, 1, 0]);
      await HDMenuFlows().showEquipment();

      expect(player.equippedAt(HDEquipSlot.head), _crown);
      expect(party.has(_crown), isFalse);

      // The part menu lists all six body parts with what is on them.
      final partMenu = ui.menus[1];
      expect(partMenu.first, "어느 부위를 바꾸는가");
      expect(partMenu.length, 7);
      expect(partMenu[4], contains('머리'));

      // The candidate menu offered only the helmet.
      final itemMenu = ui.menus[2];
      expect(itemMenu.length, 2);
      expect(itemMenu[1], contains('황금 왕관'));

      player.unequip(HDEquipSlot.head);
    });

    // Inserting "소지품을 본다" renumbered the entries after it. Nothing
    // outside this switch hardcodes those indices, but a silent shift
    // would send "게임을 마침" to the wrong flow, so pin the order.
    test('the main menu keeps its numbering', () async {
      bind([0]); // cancel straight away
      await HDMenuFlows().showMainMenu();

      final menu = ui.menus.single;
      expect(menu, [
        "당신의 명령을 고르시오 ===>",
        "일행의 상황을 본다",
        "개인의 상황을 본다",
        "일행의 건강 상태를 본다",
        "마법을 사용한다",
        "초능력을 사용한다",
        "여기서 쉰다",
        "소지품을 본다",
        "게임 선택 상황",
      ]);
    });

    test('says so when a part has nothing to offer', () async {
      final party = HDGameSession().party;
      for (var i = 0; i < party.itemCapacity; i++) {
        final id = party.itemAt(i);
        if (id != null) party.take(id);
      }
      party.players.first.unequip(HDEquipSlot.leg);

      bind([1, 5, 0]); // person 1 -> 다리 -> (then cancel)
      await HDMenuFlows().showEquipment();

      expect(ui.messages.single, contains('다리'));
    });

    test('the inventory listing stays inside the 13-line console', () async {
      final party = HDGameSession().party;
      for (var i = 0; i < party.itemCapacity; i++) {
        final id = party.itemAt(i);
        if (id != null) party.take(id);
      }
      for (var i = 0; i < party.itemCapacity; i++) {
        party.give(_dagger);
      }

      bind([0]); // decline the equipment screen
      await HDMenuFlows().showInventory();

      // clearLogs() runs per page, so count the lines between headers.
      var page = 0;
      var count = 0;
      var worst = 0;
      for (final line in ui.lines) {
        if (line.startsWith('## 소지품')) {
          worst = count > worst ? count : worst;
          count = 0;
          page++;
        }
        count++;
      }
      worst = count > worst ? count : worst;
      expect(page, 4, reason: '20 items at 6 a page');
      expect(worst, lessThanOrEqualTo(13),
          reason: 'HDConfig.maxLinesPerPage');

      for (var i = 0; i < party.itemCapacity; i++) {
        final id = party.itemAt(i);
        if (id != null) party.take(id);
      }
    });
  });
}
