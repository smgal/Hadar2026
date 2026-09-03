import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';
import 'package:hadar2026_app/domain/item/item_data.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';

const _dagger = HDItemId(HDItemType.stab, index: 1); // 단도
const _leatherArmor = HDItemId(HDItemType.armor, index: 1); // 가죽 갑옷

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
  for (var i = 0; i < party.itemCapacity; i++) {
    final id = party.itemAt(i);
    if (id != null) party.take(id);
  }
}

void main() {
  setUp(_emptyBackpack);
  tearDown(_emptyBackpack);

  group('Item:: symbols', () {
    test('Give then Has reports 1', () async {
      final vars = await _run('''
Item::Give(${_dagger.wire})
Variable::Set(0, Item::Has(${_dagger.wire}))
''');
      expect(HDGameSession().party.has(_dagger), isTrue);
      expect(vars[0], 1);
    });

    test('Take then Has reports 0', () async {
      final vars = await _run('''
Item::Give(${_dagger.wire})
Item::Take(${_dagger.wire})
Variable::Set(0, Item::Has(${_dagger.wire}))
''');
      expect(HDGameSession().party.has(_dagger), isFalse);
      expect(vars[0], 0);
      expect(HDGameSession().party.itemCount, 0);
    });

    test('Has distinguishes between two different items', () async {
      final vars = await _run('''
Item::Give(${_leatherArmor.wire})
Variable::Set(0, Item::Has(${_leatherArmor.wire}))
Variable::Set(1, Item::Has(${_dagger.wire}))
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
Item::Give(${_dagger.wire})
Variable::Set(0, Item::Hass(${_dagger.wire}))
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

    test('a full backpack refuses the 21st Give without dropping anything',
        () async {
      final party = HDGameSession().party;
      for (var i = 0; i < party.itemCapacity; i++) {
        party.give(_dagger);
      }
      await _run('Item::Give(${_leatherArmor.wire})');
      expect(party.itemCount, 20);
      expect(party.has(_leatherArmor), isFalse);
      for (var i = 0; i < party.itemCapacity; i++) {
        expect(party.itemAt(i), _dagger, reason: 'slot $i');
      }
    });

    test('Take of an item the party lacks changes nothing', () async {
      await _run('Item::Take(${_dagger.wire})');
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

      expect(byName.length, itemTable.length);
      expect(
        byName.values.toSet().length,
        byName.length,
        reason: 'no two constants may share a wire value',
      );
      for (final item in itemTable) {
        expect(
          byName.values,
          contains(item.id.wire),
          reason: '${item.name} (${item.id}) has no constant',
        );
      }
      expect(byName['ITEM_STAB_1'], _dagger.wire);
      expect(byName['ITEM_ARMOR_1'], _leatherArmor.wire);
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
