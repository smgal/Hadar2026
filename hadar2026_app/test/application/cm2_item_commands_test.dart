import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';
import 'package:hd_world/hd_world.dart';
import 'package:hd_world_legacy/hd_world_legacy.dart';

final _catalog = ItemCatalog.builtIn;
const _dagger = ItemRef('weapon.knife'); // 단도
const _leatherArmor = ItemRef('bodyArmour.leather'); // 가죽 갑옷
int _wire(ItemRef ref) => itemWireOf(ref, catalog: _catalog);

/// Runs [source] through the real adapter and returns the engine variables
/// the script wrote, so a function's return value can be observed.
Future<List<int>> _run(String source) async {
  final engine = HDScriptEngine();
  await engine.loadFromString(source);
  await engine.run();
  return HDGameSession().gameOption.variables;
}

void _emptyBackpack() {
  final party = HDGameSession().party;
  for (final ref in party.pack.refs.toList()) {
    party.take(ref, party.countOf(ref));
  }
}

void main() {
  setUp(_emptyBackpack);
  tearDown(_emptyBackpack);

  group('Item:: symbols', () {
    test('Give then Has reports 1', () async {
      final vars = await _run('''
Item::Give(${_wire(_dagger)})
Variable::Set(0, Item::Has(${_wire(_dagger)}))
''');
      expect(HDGameSession().party.has(_dagger), isTrue);
      expect(vars[0], 1);
    });

    test('Take then Has reports 0', () async {
      final vars = await _run('''
Item::Give(${_wire(_dagger)})
Item::Take(${_wire(_dagger)})
Variable::Set(0, Item::Has(${_wire(_dagger)}))
''');
      expect(HDGameSession().party.has(_dagger), isFalse);
      expect(vars[0], 0);
      expect(HDGameSession().party.itemCount, 0);
    });

    test('Has distinguishes between two different items', () async {
      final vars = await _run('''
Item::Give(${_wire(_leatherArmor)})
Variable::Set(0, Item::Has(${_wire(_leatherArmor)}))
Variable::Set(1, Item::Has(${_wire(_dagger)}))
''');
      expect(vars[0], 1);
      expect(vars[1], 0);
    });

    // THIS IS WHAT A SILENT MIS-BRANCH LOOKS LIKE. An unregistered cm2
    // *function* prints "Unknown function" and returns 0, so a typo turns
    // `if (Item::Has(key))` into a branch that never runs and
    // `if (Not(Item::Has(key)))` into one that always does. That is exactly
    // why Item::Has is registered with registerFunction and not
    // registerCommand -- and it is not hypothetical: Party::CheckIf is
    // unregistered today, which is why levitation does not stop cliff falls
    // (GROUND_TRUTH M-3).
    test('a typo in the symbol returns 0, quietly taking the wrong branch',
        () async {
      final vars = await _run('''
Item::Give(${_wire(_dagger)})
Variable::Set(0, Item::Hass(${_wire(_dagger)}))
''');
      expect(HDGameSession().party.has(_dagger), isTrue,
          reason: 'the party really does have it');
      expect(vars[0], 0, reason: 'but the mistyped call says otherwise');
    });

    test('an id off the catalog is refused and leaves the backpack alone',
        () async {
      final vars = await _run('''
Item::Give(999999)
Item::Give(-5)
Variable::Set(0, Item::Has(999999))
''');
      expect(HDGameSession().party.itemCount, 0);
      expect(vars[0], 0);
    });

    test('a full backpack refuses one more kind without dropping anything',
        () async {
      // 칸은 **종류**를 센다 — 같은 물건을 여러 개 넣는 것은 자리를 더
      // 먹지 않는다. 이전 모델은 20칸 배열이라 같은 단도가 20줄이었다.
      final party = HDGameSession().party;
      final fillers = _catalog.all
          .where((d) => itemWireOf(d.ref, catalog: _catalog) >= 0)
          .take(party.itemCapacity)
          .toList();
      for (final def in fillers) {
        party.give(def.ref);
      }
      expect(party.itemCount, party.itemCapacity);
      final absent = _catalog.all.firstWhere(
        (d) => !party.has(d.ref) && itemWireOf(d.ref, catalog: _catalog) >= 0,
      );
      await _run('Item::Give(${'\$'}{_wire(absent.ref)})');
      expect(party.itemCount, party.itemCapacity);
      expect(party.has(absent.ref), isFalse);
    });

    test('Take of an item the party lacks changes nothing', () async {
      await _run('Item::Take(${_wire(_dagger)})');
      expect(HDGameSession().party.itemCount, 0);
    });
  });

  group('assets/item4ep1.cm2', () {
    // The constants file is what scripts are supposed to use instead of raw
    // numbers -- bypassing the names is what makes collisions undetectable
    // (GROUND_TRUTH M-2). Cross-check it against the catalog so the two
    // cannot drift.
    test('names every catalog row with the right wire value', () {
      final source = File('assets/item4ep1.cm2').readAsStringSync();
      final assigns = RegExp(r'^(ITEM_\w+)\.assign\((\d+)\)', multiLine: true);
      final byName = {
        for (final m in assigns.allMatches(source))
          m.group(1)!: int.parse(m.group(2)!),
      };

      // 번호가 있는 행만 상수를 갖는다 — 부적과 새 무기는 이 빌드가
      // 만든 것이라 스크립트가 이름으로 부를 수 없다.
      final numbered = [
        for (final def in _catalog.all)
          if (itemWireOf(def.ref, catalog: _catalog) >= 0) def,
      ];
      expect(byName.length, numbered.length);
      expect(
        byName.values.toSet().length,
        byName.length,
        reason: 'no two constants may share a wire value',
      );
      for (final def in numbered) {
        expect(
          byName.values,
          contains(itemWireOf(def.ref, catalog: _catalog)),
          reason: '${def.ref.value} has no constant',
        );
      }
      expect(byName['ITEM_STAB_1'], _wire(_dagger));
      expect(byName['ITEM_ARMOR_1'], _wire(_leatherArmor));
    });

    test('every constant is declared before it is assigned', () {
      final source = File('assets/item4ep1.cm2').readAsStringSync();
      final declared = RegExp(r'^variable\((ITEM_\w+)\)', multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      final assigned = RegExp(r'^(ITEM_\w+)\.assign', multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      expect(assigned, declared);
    });
  });
}
