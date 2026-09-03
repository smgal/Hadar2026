import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/item/item_data.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';

void main() {
  group('legacy name tables', () {
    // The C++ original's name lists (hd_res_string.cpp:38-88). These are the
    // index space HDPlayer.weapon/shield/armor still hold and that shipped
    // cm2 content writes with Player::ChangeAttribute, so drifting from them
    // renames items that saved games already point at.
    test('weapon names match hd_res_string.cpp character for character', () {
      expect(legacyWeaponNames, [
        '맨손',
        '단도',
        '곤봉',
        '미늘창',
        '장검',
        '철퇴',
        '기병창',
        '도끼창',
        '삼지창',
        '화염검',
      ]);
      expect(legacyUnknownWeaponName, '불확실한 무기');
    });

    test('shield names match hd_res_string.cpp', () {
      expect(legacyShieldNames, [
        '없음',
        '가죽 방패',
        '청동 방패',
        '강철 방패',
        '은제 방패',
        '금제 방패',
      ]);
      expect(legacyUnknownShieldName, '불확실한 방패');
    });

    test('armor names match hd_res_string.cpp except index 0', () {
      expect(legacyArmorNames, [
        // The one documented deviation: C++ says '없음', but the Unity port
        // and the current Dart (player.dart:93) both say '평상복'.
        '평상복',
        '가죽 갑옷',
        '청동 갑옷',
        '강철 갑옷',
        '은제 갑옷',
        '금제 갑옷',
      ]);
      expect(legacyUnknownArmorName, '불확실한 갑옷');
    });

    test('every legacy index resolves to a catalog row of the right kind', () {
      for (var i = 0; i < legacyWeaponNames.length; i++) {
        final item = itemById(legacyWeaponIds[i]);
        expect(item, isNotNull, reason: 'weapon $i');
        expect(item!.name, legacyWeaponNames[i]);
        expect(item.type.isWeapon, isTrue);
      }
      for (var i = 0; i < legacyShieldNames.length; i++) {
        final item = itemById(legacyShieldIds[i]);
        expect(item, isNotNull, reason: 'shield $i');
        expect(item!.name, legacyShieldNames[i]);
        expect(item.type, HDItemType.shield);
      }
      for (var i = 0; i < legacyArmorNames.length; i++) {
        final item = itemById(legacyArmorIds[i]);
        expect(item, isNotNull, reason: 'armor $i');
        expect(item!.name, legacyArmorNames[i]);
        expect(item.type, HDItemType.armor);
      }
    });
  });

  group('itemTable', () {
    // Stands in for the original's duplicate check, which logged an error at
    // registration time instead (ObjItem.cs:249-256).
    test('has no duplicate wire id', () {
      final wires = itemTable.map((i) => i.id.wire).toList();
      expect(wires.toSet().length, wires.length);
    });

    test('itemById finds every row and nothing else', () {
      for (final item in itemTable) {
        expect(itemById(item.id), same(item));
      }
      expect(itemById(const HDItemId(HDItemType.wield, index: 200)), isNull);
    });

    test('every kind has an index 0 "empty" row', () {
      for (final kind
          in HDItemType.values.where((t) => t != HDItemType.none)) {
        final empty = itemTable.where(
          (i) => i.type == kind && i.id.index == 0,
        );
        expect(empty.length, 1, reason: 'kind $kind');
        expect(empty.single.param.attaPow, lessThanOrEqualTo(1));
        expect(empty.single.param.ac, 0);
      }
    });

    test('detail is 0 throughout — kind already carries the classification',
        () {
      expect(itemTable.every((i) => i.id.detail == 0), isTrue);
    });

    test('shield and armor ac stay in 0..5', () {
      // The party starts at ac 3..5 (party.dart:108,130). books.json's 10/20
      // sat well outside that band, which is what GROUND_TRUTH H-2 asked to
      // be rescaled; taking the original's index 0..5 rows does it for free.
      final defensive = itemTable.where(
        (i) => i.type == HDItemType.shield || i.type == HDItemType.armor,
      );
      expect(defensive.length, 12);
      for (final item in defensive) {
        expect(item.param.ac, inInclusiveRange(0, 5), reason: item.name);
        expect(item.param.ac, item.id.index, reason: '${item.name} ac==index');
      }
    });

    test('carries 11 rows each for head / leg / ornament', () {
      for (final kind in [HDItemType.head, HDItemType.leg,
                          HDItemType.ornament]) {
        final rows = itemTable.where((i) => i.type == kind).toList();
        expect(rows.length, 11, reason: '$kind');
        expect(rows.map((i) => i.id.index).toSet(),
            {for (var i = 0; i <= 10; i++) i});
      }
    });

    test('keeps the three annex strings PROPS_LIST carries', () {
      final withAnnex = {
        for (final i in itemTable.where((i) => i.annex.isNotEmpty))
          i.name: i.annex,
      };
      expect(withAnnex, {
        '두건': 'ATT+1AC-1STR+1',
        '헝겊 신발': 'INT-2',
        '멋쟁이 혁띠': 'STR+100',
      });
    });

    test("keeps the original's unfinished prop names verbatim", () {
      // ObjItem.cs ships '다리6'..'다리A' and '장식6'..'장식A' unnamed.
      // Inventing names here would be content work, not a port.
      expect(itemTable.map((i) => i.name), containsAll(['다리6', '장식A']));
    });

    test('weapon powers come from the Unity table', () {
      int powerOf(String name) =>
          itemTable.firstWhere((i) => i.name == name).param.attaPow;
      expect(powerOf('단도'), 10);
      expect(powerOf('기병창'), 35);
      expect(powerOf('곤봉'), 25);
      expect(powerOf('장검'), 60);
      expect(powerOf('철퇴'), 60);
      expect(powerOf('삼지창'), 60);
      expect(powerOf('미늘창'), 80); // Unity calls this one 핼버드
      expect(powerOf('도끼창'), 90);
      // 화염검 has no weapon row in the Unity table at all; 10 is the summon
      // placeholder the original itself marked TODO (ObjItem.cs:603-611), not
      // a balanced value. Pinned so G1-05 cannot mistake it for one.
      expect(powerOf('화염검'), 10);
    });
  });
}
