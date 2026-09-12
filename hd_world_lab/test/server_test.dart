import 'dart:convert';
import 'dart:io';

import 'package:hd_world/hd_world.dart';
import 'package:hd_world_lab/server.dart';
import 'package:test/test.dart';

/// The HTTP surface, exercised the way a script or an agent would.
void main() {
  late LabServer server;
  late HttpClient client;
  late String base;

  setUp(() async {
    server = LabServer(root: Directory('web'));
    await server.start(port: 0);
    client = HttpClient();
    base = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<(int, Object?)> call(
    String method,
    String path, [
    Object? body,
  ]) async {
    final request = await client.openUrl(method, Uri.parse('$base$path'));
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    final decoded = text.isEmpty
        ? null
        : (response.headers.contentType?.mimeType == 'application/json'
              ? jsonDecode(text)
              : text);
    return (response.statusCode, decoded);
  }

  test('the state is five members with everything resolved', () async {
    final (status, body) = await call('GET', '/api/state');
    expect(status, 200);
    final state = body as Map<String, Object?>;
    expect((state['members'] as List).length, 5);
    final first = (state['members'] as List).first as Map<String, Object?>;
    expect(first['weaponKind'], isNot('unarmed'));
    expect((first['slots'] as List).length, 8);
  });

  test('the name tables cover every table the screen reads', () async {
    final (_, body) = await call('GET', '/api/text');
    final text = body as Map<String, Object?>;
    for (final table in const [
      'slot',
      'class',
      'weaponKind',
      'style',
      'stat',
      'capability',
      'ailment',
      'refusal',
      'item',
    ]) {
      expect(text[table], isNotNull, reason: table);
      expect((text[table] as Map).isNotEmpty, isTrue, reason: table);
    }
  });

  test('a two-handed weapon clears the off hand, over HTTP', () async {
    final (status, body) = await call('POST', '/api/command', {
      'command': {
        'kind': 'equip',
        'member': 'knight',
        'slot': 'rightHand',
        'item': 'weapon.long_sword',
      },
    });
    expect(status, 200);
    final out = body as Map<String, Object?>;
    final kinds = [
      for (final e in out['events'] as List) (e as Map)['kind'],
    ];
    expect(kinds, contains('offHandCleared'));
    expect(out['refused'], isEmpty);
    final knight = ((out['state'] as Map)['members'] as List).first as Map;
    expect(knight['weaponKind'], 'greatSword');
    expect(knight['offHandLocked'], isTrue);
  });

  test('a refusal is a 200 with a reason, and changes nothing', () async {
    final (status, body) = await call('POST', '/api/command', {
      'command': {
        'kind': 'equip',
        'member': 'magician',
        'slot': 'classAmulet1',
        'item': 'classAmulet.oath_crest',
      },
    });
    expect(status, 200);
    final out = body as Map<String, Object?>;
    expect((out['refused'] as List).length, 1);
    expect(
      ((out['refused'] as List).first as Map)['reason'],
      'wrongClass',
    );
    expect(
      server.world.pack.countOf(const ItemRef('classAmulet.oath_crest')),
      1,
    );
  });

  test('unreadable JSON is a 400 that names the field and the choices', () async {
    final (status, body) = await call('POST', '/api/command', {
      'command': {'kind': 'equip', 'member': 'knight', 'slot': 'elbow'},
    });
    expect(status, 400);
    final out = body as Map<String, Object?>;
    expect(out['field'], 'slot');
    expect(out['allowed'], contains('leftHand'));
  });

  test('an unknown command lists the ones that exist', () async {
    final (status, body) = await call('POST', '/api/command', {
      'command': {'kind': 'wear'},
    });
    expect(status, 400);
    expect((body as Map)['allowed'], contains('equip'));
  });

  test('a batch is decoded whole before anything is applied', () async {
    final before = server.world.view.toJson();
    final (status, _) = await call('POST', '/api/commands', {
      'commands': [
        {
          'kind': 'equip',
          'member': 'knight',
          'slot': 'head',
          'item': 'helmet.leather_helm',
        },
        {'kind': 'equip', 'member': 'knight', 'slot': 'nose'},
      ],
    });
    expect(status, 400);
    // The good first entry did not land either.
    expect(server.world.view.toJson().toString(), before.toString());
  });

  test('the offered list is what the command accepts', () async {
    final (_, body) = await call(
      'GET',
      '/api/candidates?member=knight&slot=leftHand',
    );
    final items = ((body as Map)['items'] as List).cast<String>();
    expect(items, contains('light.torch'));
    expect(items, isNot(contains('weapon.long_sword')));
    for (final ref in items) {
      final (_, out) = await call('POST', '/api/reset');
      expect(out, isNotNull);
      final (_, applied) = await call('POST', '/api/command', {
        'command': {
          'kind': 'equip',
          'member': 'knight',
          'slot': 'leftHand',
          'item': ref,
        },
      });
      expect((applied as Map)['refused'], isEmpty, reason: ref);
    }
  });

  test('three torches walk the sight radius up', () async {
    await call('POST', '/api/reset');
    // Only members with a one-handed weapon can take one.
    var radius = 0;
    for (final who in const ['knight', 'paladin']) {
      await call('POST', '/api/command', {
        'command': {
          'kind': 'equip',
          'member': who,
          'slot': 'leftHand',
          'item': 'light.torch',
        },
      });
    }
    final (_, body) = await call('GET', '/api/state');
    final party = (body as Map)['party'] as Map;
    expect(party['lightBearers'], 2);
    radius = party['sightInDarkness'] as int;
    expect(radius, 4);
    expect(party['moonlight'], isTrue);
  });

  test('a spell light is dimmer than one real torch', () async {
    await call('POST', '/api/reset');
    final (_, body) = await call('POST', '/api/magicLight', {'on': true});
    final party = ((body as Map)['state'] as Map)['party'] as Map;
    expect(party['sightInDarkness'], 2);
    expect(party['moonlight'], isFalse);
  });

  test('the guide, the page and the spec are all served', () async {
    final (guideStatus, guide) = await call('GET', '/api/guide');
    expect(guideStatus, 200);
    expect(guide as String, contains('refused'));
    expect((await call('GET', '/')).$1, 200);
    expect((await call('GET', '/openapi.yaml')).$1, 200);
  });

  test('a fight runs, settles onto the party, and reports reach', () async {
    await call('POST', '/api/reset');
    final (status, body) = await call('POST', '/api/battle', {
      'enemyKeys': ['orc', 'orc', 'wolf'],
      'seed': 7,
    });
    expect(status, 200);
    final out = body as Map<String, Object?>;
    expect(out['result'], anyOf('win', 'lose', 'escape'));
    expect(out['rounds'], greaterThan(0));
    expect(out['refused'], isEmpty);
    final members = (out['members'] as List).cast<Map<String, Object?>>();
    expect(members.length, 5);
    // The gap W1-06 closed: the hunter's bow reaches three ranks, and
    // before the missile rows existed it had no key at all.
    final hunter = members.firstWhere((m) => m['ref'] == 'hunter');
    expect(hunter['weaponKey'], 'bow');
    expect(hunter['reach'], 3);
    expect(
      members.any((m) => m['hitPointsAfter'] != m['hitPointsBefore']),
      isTrue,
      reason: 'a fight has to leave a mark',
    );
  });

  test('a mistyped path answers with the list, not with the page', () async {
    final (status, body) = await call('GET', '/api/statte');
    expect(status, 405);
    expect((body as Map)['endpoints'], isNotEmpty);
  });

  test('a path cannot climb out of the served directory', () async {
    final (status, _) = await call('GET', '/../pubspec.yaml');
    expect(status, anyOf(403, 404, 400));
  });
}
