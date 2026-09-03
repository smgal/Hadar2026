import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/party.dart';

const _dagger = HDItemId(HDItemType.stab, index: 1);
const _club = HDItemId(HDItemType.hit, index: 3);
const _shield = HDItemId(HDItemType.shield, index: 3);

void main() {
  group('HDParty backpack', () {
    test('starts empty at the original 20 slots', () {
      final party = HDParty();
      expect(party.itemCapacity, 20);
      expect(party.itemCount, 0);
      expect(party.itemAt(0), isNull);
      expect(party.itemAt(19), isNull);
      expect(() => party.itemAt(20), throwsRangeError);
    });

    test('give fills the first empty slot', () {
      final party = HDParty();
      expect(party.give(_dagger), isTrue);
      expect(party.give(_club), isTrue);
      expect(party.itemAt(0), _dagger);
      expect(party.itemAt(1), _club);
      expect(party.itemCount, 2);
    });

    // ObjParty.cs:424-439 -- a full backpack refuses the item instead of
    // dropping something to make room.
    test('a 21st give fails and leaves the 20 slots untouched', () {
      final party = HDParty();
      for (var i = 0; i < 20; i++) {
        expect(party.give(_dagger), isTrue, reason: 'slot $i');
      }
      expect(party.itemCount, 20);

      expect(party.give(_club), isFalse);
      expect(party.itemCount, 20);
      for (var i = 0; i < 20; i++) {
        expect(party.itemAt(i), _dagger, reason: 'slot $i');
      }
    });

    // The "first empty slot" rule is why the array is fixed-length: a hole
    // in the middle is refilled rather than everything shifting down
    // (ObjParty.cs:426-433).
    test('a freed middle slot is the one the next give uses', () {
      final party = HDParty();
      for (var i = 0; i < 5; i++) {
        party.give(_dagger);
      }
      party.give(_shield); // slot 5
      party.give(_club); // slot 6
      party.give(_club); // slot 7
      expect(party.itemAt(5), _shield);

      expect(party.take(_shield), isTrue);
      expect(party.itemAt(5), isNull);
      expect(party.itemAt(6), _club, reason: 'slot 6 must not shift down');
      expect(party.itemCount, 7);

      const marked = HDItemId(HDItemType.armor, index: 2);
      expect(party.give(marked), isTrue);
      expect(party.itemAt(5), marked);
      expect(party.itemAt(6), _club);
      expect(party.itemCount, 8);
    });

    test('take clears only the first matching slot', () {
      final party = HDParty();
      party.give(_dagger);
      party.give(_dagger);
      party.give(_club);

      expect(party.take(_dagger), isTrue);
      expect(party.itemAt(0), isNull);
      expect(party.itemAt(1), _dagger);
      expect(party.itemAt(2), _club);
      expect(party.itemCount, 2);
    });

    test('take of an item the party lacks is false and changes nothing', () {
      final party = HDParty();
      party.give(_dagger);
      expect(party.take(_shield), isFalse);
      expect(party.itemCount, 1);
      expect(party.itemAt(0), _dagger);
    });

    test('has stays true while a duplicate remains', () {
      final party = HDParty();
      party.give(_dagger);
      party.give(_dagger);
      expect(party.has(_dagger), isTrue);
      expect(party.itemCount, 2);

      expect(party.take(_dagger), isTrue);
      expect(party.has(_dagger), isTrue);
      expect(party.itemCount, 1);

      expect(party.take(_dagger), isTrue);
      expect(party.has(_dagger), isFalse);
      expect(party.itemCount, 0);
    });

    test('food and gold are untouched by item traffic', () {
      final party = HDParty();
      final food = party.food;
      final gold = party.gold;
      party.give(_dagger);
      party.take(_dagger);
      party.give(_shield);
      expect(party.food, food);
      expect(party.gold, gold);
    });

    test('notifies listeners on a successful give or take only', () async {
      final party = HDParty();
      var notified = 0;
      party.addListener(() => notified++);

      expect(party.give(_dagger), isTrue);
      expect(party.take(_dagger), isTrue);
      // notifyListeners() is wrapped in Future.microtask (party.dart:30-37),
      // so let the queue drain before counting.
      await Future<void>.delayed(Duration.zero);
      expect(notified, 2);

      expect(party.take(_dagger), isFalse); // nothing changed
      await Future<void>.delayed(Duration.zero);
      expect(notified, 2);
    });
  });
}
