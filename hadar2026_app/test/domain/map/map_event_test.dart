import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/domain/map/map_event.dart';

void main() {
  group('MapEvent.fromJson', () {
    test('parses dialogLines from RPG Maker code 401 entries', () {
      final ev = MapEvent.fromJson({
        'id': 7,
        'name': 'TALK_grocer',
        'x': 5,
        'y': 9,
        'pages': [
          {
            'list': [
              {
                'code': 401,
                'parameters': ['hello', 'welcome'],
              },
              {'code': 0, 'parameters': []},
            ],
          },
        ],
      });
      expect(ev.id, 7);
      expect(ev.type, 'TALK');
      expect(ev.dialogLines, ['hello', 'welcome']);
      expect(ev.hadarEvent, isNull);
    });

    test('parses hadarEvent extension when present', () {
      final ev = MapEvent.fromJson({
        'id': 1,
        'name': 'ENTER_cave',
        'x': 0,
        'y': 0,
        'hadarEvent': {
          'kind': 'warp',
          'payload': {'map': 'DEN1', 'x': 25, 'y': 44},
        },
      });
      expect(ev.hadarEvent, isNotNull);
      expect(ev.hadarEvent!.kind, 'warp');
      expect(ev.hadarEvent!.payload['map'], 'DEN1');
      expect(ev.hadarEvent!.payload['x'], 25);
    });

    test('hadarEvent without payload yields empty payload map', () {
      final ev = MapEvent.fromJson({
        'id': 2,
        'name': 'SIGN',
        'x': 0,
        'y': 0,
        'hadarEvent': {'kind': 'sign'},
      });
      expect(ev.hadarEvent!.kind, 'sign');
      expect(ev.hadarEvent!.payload, isEmpty);
    });
  });
}
