import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/item/item_names.dart';
import 'package:hadar2026_app/domain/party/player.dart';

void main() {
  group('legacy slot names', () {
    // What replaced "무기1"/"방패1"/"갑옷1". The index space is the C++
    // original's (hd_res_string.cpp:38-88) and shipped cm2 content writes it
    // with Player::ChangeAttribute, so pin the names as literals.
    test('weapon 0..9 are the original names', () {
      expect(
        [for (var i = 0; i < 10; i++) legacyWeaponName(i)],
        ['맨손', '단도', '곤봉', '미늘창', '장검', '철퇴', '기병창', '도끼창', '삼지창', '화염검'],
      );
    });

    test('shield and armor 0..5 are the original names', () {
      expect(
        [for (var i = 0; i < 6; i++) legacyShieldName(i)],
        ['없음', '가죽 방패', '청동 방패', '강철 방패', '은제 방패', '금제 방패'],
      );
      expect(
        [for (var i = 0; i < 6; i++) legacyArmorName(i)],
        ['평상복', '가죽 갑옷', '청동 갑옷', '강철 갑옷', '은제 갑옷', '금제 갑옷'],
      );
    });

    test('an index off the table falls back instead of going blank', () {
      expect(legacyWeaponName(10), '불확실한 무기');
      expect(legacyWeaponName(-1), '불확실한 무기');
      expect(legacyShieldName(6), '불확실한 방패');
      expect(legacyArmorName(99), '불확실한 갑옷');
    });
  });

  group('HDPlayer equipment names', () {
    test('read from the table, not from a "무기N" placeholder', () {
      final p = HDPlayer()
        ..weapon = 4
        ..shield = 5
        ..armor = 1;
      expect(p.getWeaponName(), '장검');
      expect(p.getShieldName(), '금제 방패');
      expect(p.getArmorName(), '가죽 갑옷');
    });

    test('an unequipped player reads as the index 0 rows', () {
      final p = HDPlayer();
      expect(p.getWeaponName(), '맨손');
      expect(p.getShieldName(), '없음');
      expect(p.getArmorName(), '평상복');
    });

    test('the party default weapon 1 is no longer "무기1"', () {
      // party.dart:104,126 start members at weapon = 1, which is what put
      // "무기1" on screen the moment the game opened.
      final p = HDPlayer()..weapon = 1;
      expect(p.getWeaponName(), '단도');
    });
  });
}
