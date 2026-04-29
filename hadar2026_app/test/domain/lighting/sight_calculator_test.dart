import 'package:flutter_test/flutter_test.dart';

import 'package:hadar2026_app/domain/lighting/sight_calculator.dart';
import 'package:hadar2026_app/domain/party/party.dart';

HDParty _partyAt({
  required int hour,
  int min = 0,
  int day = 1,
  int magicTorch = 0,
}) {
  return HDParty()
    ..hour = hour
    ..min = min
    ..day = day
    ..magicTorch = magicTorch;
}

void main() {
  group('HDSightCalculator.sightRangeFor — daylight curve', () {
    test('full daylight (07:00–17:59) gives sight 5', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 12),
          mapName: 'GROUND1',
        ),
        5,
      );
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 17, min: 59),
          mapName: 'GROUND1',
        ),
        5,
      );
    });

    test('pre-dawn 05:59 = 1', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 5, min: 59),
          mapName: 'GROUND1',
        ),
        1,
      );
    });

    test('06:30 = 3 (dawn ramp)', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 6, min: 30),
          mapName: 'GROUND1',
        ),
        3,
      );
    });

    test('18:30 = 3 (dusk ramp)', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 18, min: 30),
          mapName: 'GROUND1',
        ),
        3,
      );
    });

    test('23:00 = 1 (deep night)', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 23),
          mapName: 'GROUND1',
        ),
        1,
      );
    });
  });

  group('HDSightCalculator.sightRangeFor — DEN forces sight 1', () {
    test('DEN map at noon still has sight 1', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 12),
          mapName: 'DEN1',
        ),
        1,
      );
    });
  });

  group('HDSightCalculator.sightRangeFor — magic torch', () {
    test('low-tier torch (1–2) raises night sight to 2', () {
      // 23:00 in dark → base 1; torch=1 → bumped to 2
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 23, magicTorch: 1),
          mapName: 'GROUND1',
        ),
        2,
      );
    });

    test('mid-tier torch (3+) raises night sight to 3', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 23, magicTorch: 3),
          mapName: 'GROUND1',
        ),
        3,
      );
    });

    test('torch never lowers daytime sight', () {
      expect(
        HDSightCalculator.sightRangeFor(
          party: _partyAt(hour: 12, magicTorch: 5),
          mapName: 'GROUND1',
        ),
        5,
      );
    });
  });

  group('HDSightCalculator.isInMoonlight', () {
    test('TOWN/CASTLE always returns true regardless of hour', () {
      expect(
        HDSightCalculator.isInMoonlight(
          party: _partyAt(hour: 23),
          mapName: 'TOWN1',
        ),
        true,
      );
      expect(
        HDSightCalculator.isInMoonlight(
          party: _partyAt(hour: 3),
          mapName: 'CASTLE_LORE',
        ),
        true,
      );
    });

    test('DEN always returns false', () {
      expect(
        HDSightCalculator.isInMoonlight(
          party: _partyAt(hour: 12),
          mapName: 'DEN1',
        ),
        false,
      );
    });

    test('high-tier torch (>4) at night turns moonlight on', () {
      expect(
        HDSightCalculator.isInMoonlight(
          party: _partyAt(hour: 23, magicTorch: 5),
          mapName: 'GROUND1',
        ),
        true,
      );
    });
  });

  group('HDSightCalculator.lightBitFor', () {
    test('full sight (>=5) returns 15', () {
      expect(
        HDSightCalculator.lightBitFor(
          mapX: 100,
          mapY: 100,
          playerX: 0,
          playerY: 0,
          sightRange: 5,
        ),
        15,
      );
    });

    test('player tile is fully lit at sight 1', () {
      expect(
        HDSightCalculator.lightBitFor(
          mapX: 5,
          mapY: 5,
          playerX: 5,
          playerY: 5,
          sightRange: 1,
        ),
        15,
      );
    });

    test('far tile outside the radius gets 0', () {
      expect(
        HDSightCalculator.lightBitFor(
          mapX: 0,
          mapY: 0,
          playerX: 10,
          playerY: 10,
          sightRange: 1,
        ),
        0,
      );
    });
  });
}
