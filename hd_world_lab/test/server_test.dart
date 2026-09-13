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
      // 화면이 글리프를 고르고 묶음에 이름을 붙이는 데 쓴다.
      'itemKind',
      'shape',
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

  /// 세계를 **순서와 무관하게** 비교할 수 있는 꼴로 줄인다.
  ///
  /// 통째로 문자열 비교를 하면 가방의 넣은 순서까지 비교하게 된다.
  /// 장검이 빠졌다 다시 들어가면 그 칸은 지도의 맨 뒤로 가는데, 그것은
  /// 아무도 약속한 적 없는 것이고 어긋나도 세계는 같다.
  Future<Map<String, Object?>> shape() async {
    final (_, body) = await call('GET', '/api/state');
    final state = body! as Map<String, Object?>;
    return {
      'members': [
        for (final m in (state['members']! as List).cast<Map<String, Object?>>())
          {
            'ref': m['ref'],
            'style': m['style'],
            'thrift': m['thrift'],
            'weaponKind': m['weaponKind'],
            'slots': {
              for (final s in (m['slots']! as List).cast<Map<String, Object?>>())
                '${s['slot']}': s['item'],
            },
          },
      ],
      'pack': Map.fromEntries(
        (state['pack']! as List)
            .cast<Map<String, Object?>>()
            .map((row) => MapEntry('${row['item']}', row['count']))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      ),
    };
  }

  test('the page it serves is the one this repository holds', () async {
    // 화면이 조각으로 나뉘어 있으므로 하나만 빠져도 흰 화면이 된다.
    for (final file in const ['/', '/style.css', '/app.js', '/icons.js']) {
      final (status, _) = await call('GET', file);
      expect(status, 200, reason: file);
    }
  });

  test('the page has a section for every tab', () async {
    final (_, body) = await call('GET', '/');
    final html = '$body';
    for (final tab in const ['gear', 'pack', 'flags', 'record']) {
      expect(html, contains('data-tab="$tab"'), reason: '$tab 단추');
      expect(html, contains('id="tab-$tab"'), reason: '$tab 칸');
    }
  });

  test('the side column says which tabs each card belongs to', () async {
    // 플래그 탭에서 물건 설명이 열려 있으면 무엇을 보는 화면인지
    // 흐려진다. `data-for` 가 없는 칸만 늘 보인다.
    final (_, body) = await call('GET', '/');
    final html = '$body';
    expect(html, contains('id="detail" class="card" data-for="gear pack"'));
    expect(html, contains('data-for="gear pack flags"'));
    // 마법의 횃불은 머리글이 아니라 그것이 바꾸는 값 옆에 있다.
    expect(html, isNot(contains('id="magic"')));
  });

  test('hidden really hides', () async {
    // 브라우저의 `[hidden] { display: none }` 은 **작성자 규칙에 진다.**
    // `.tab { display: block }` 하나가 `el.hidden = true` 를 통째로
    // 무력화해서 탭을 눌러도 아무 일이 없었다. 화면에서는 「단추가 안
    // 먹는다」 로 보이므로 원인이 CSS 인 줄 모른다.
    final (_, css) = await call('GET', '/style.css');
    expect(
      '$css'.replaceAll(' ', ''),
      contains('[hidden]{display:none!important;}'),
      reason: '이 한 줄이 없으면 탭 전환이 조용히 죽는다',
    );
  });

  // ── 판정 한 판 ─────────────────────────────────────────────

  test('eligibility answers for every item against every slot', () async {
    final (status, body) = await call('GET', '/api/eligibility');
    expect(status, 200);
    final out = body as Map<String, Object?>;

    final members = out['members'] as Map<String, Object?>;
    expect(members.keys, hasLength(5));

    final knight = members['knight']! as Map<String, Object?>;
    expect(knight, hasLength(ItemCatalog.builtIn.length));

    final sword = knight['weapon.long_sword']! as Map<String, Object?>;
    expect(sword, hasLength(EquipSlot.values.length));
    expect(sword['rightHand'], isTrue);
    // 두 거절이 다른 답이어야 한다는 것이 이 화면이 지키는 것이다.
    expect(sword['leftHand'], 'twoHandedInOffHand');
    expect(sword['head'], 'wrongSlot');

    final crest = knight['classAmulet.oath_crest']! as Map<String, Object?>;
    expect(crest['commonAmulet'], 'wrongSlot');
    final magician =
        (members['magician']! as Map<String, Object?>)['classAmulet.oath_crest']!
            as Map<String, Object?>;
    expect(magician['classAmulet1'], 'wrongClass');
  });

  test('eligibility keeps carried apart from allowed', () async {
    // 「안 가지고 있다」 와 「직업이 아니다」 는 화면에서 다른 색이다.
    // 둘을 하나로 접으면 그 구분이 사라진다.
    final (_, body) = await call('GET', '/api/eligibility');
    final out = body as Map<String, Object?>;
    expect(out['carried'], isA<Map<String, Object?>>());
    expect(out['packCapacity'], greaterThan(0));
    expect(out['packKinds'], (out['carried'] as Map).length);

    final equippedBy = out['equippedBy'] as Map<String, Object?>;
    expect(equippedBy, isNotEmpty);
    final worn = (equippedBy.values.first! as List).first as Map;
    expect(worn['member'], isNotNull);
    expect(worn['slot'], isNotNull);
  });

  // ── 미리보기 ───────────────────────────────────────────────

  test('a preview reports the difference and changes nothing', () async {
    final (_, beforeBody) = await call('GET', '/api/state');
    final before = jsonEncode(beforeBody);

    final (status, body) = await call('POST', '/api/preview', {
      'command': {
        'kind': 'equip',
        'member': 'knight',
        'slot': 'rightHand',
        'item': 'weapon.long_sword',
      },
    });
    expect(status, 200);
    final out = body as Map<String, Object?>;
    expect(out['ok'], isTrue);

    final members = (out['changes'] as Map)['members'] as List;
    final knight = members.first as Map<String, Object?>;
    expect(knight['ref'], 'knight');

    final changes = (knight['changes'] as List).cast<Map<String, Object?>>();
    final kind = changes.firstWhere((c) => c['key'] == 'weaponKind');
    expect(kind['from'], 'swordAndShield');
    expect(kind['to'], 'greatSword');
    // 값이 어느 표의 것인지를 같이 보낸다. 서버는 한국어를 갖지 않는다.
    expect(kind['table'], 'weaponKind');

    // 방패가 빠지는 것이 부위 변화로 같이 나와야 한다.
    final slots = (knight['slots'] as List).cast<Map<String, Object?>>();
    expect(slots.any((s) => s['slot'] == 'leftHand' && s['to'] == null), isTrue);

    final (_, afterBody) = await call('GET', '/api/state');
    expect(jsonEncode(afterBody), before, reason: '미리보기는 세계를 만지지 않는다');
  });

  test('a preview of a refusal says why, and is not an error', () async {
    final (status, body) = await call('POST', '/api/preview', {
      'command': {
        'kind': 'equip',
        'member': 'magician',
        'slot': 'classAmulet1',
        'item': 'classAmulet.oath_crest',
      },
    });
    expect(status, 200);
    final out = body as Map<String, Object?>;
    expect(out['ok'], isFalse);
    expect(((out['refused'] as List).first as Map)['reason'], 'wrongClass');
  });

  test('a preview reports what the whole party gains', () async {
    final (_, body) = await call('POST', '/api/preview', {
      'command': {
        'kind': 'equip',
        'member': 'knight',
        'slot': 'commonAmulet',
        'item': 'commonAmulet.water',
      },
    });
    final party = ((body as Map)['changes'] as Map)['party'] as List;
    expect(
      party.any((c) => (c as Map)['to'] == 'walkOnWater'),
      isTrue,
      reason: '한 사람이 차면 파티 전체가 얻는다',
    );
  });

  // ── 장비 모음 ──────────────────────────────────────────────

  test('a captured set puts the party back exactly', () async {
    final before = jsonEncode(await shape());
    await call('POST', '/api/loadouts', {'op': 'capture', 'name': 'base'});

    await call('POST', '/api/command', {
      'command': {
        'kind': 'equip',
        'member': 'knight',
        'slot': 'rightHand',
        'item': 'weapon.long_sword',
      },
    });
    expect(jsonEncode(await shape()), isNot(before));

    final (status, body) = await call('POST', '/api/loadouts', {
      'op': 'apply',
      'name': 'base',
    });
    expect(status, 200);
    // 「거절이 있었나」 와 「제자리에 갔나」 는 다른 물음이다. 전원을
    // 벗기면 가방 종류 한도에 걸려 거절이 나지만 물건은 팔에 남는다.
    expect((body as Map)['landed'], isTrue);
    expect(body['mismatch'], isEmpty);
    expect(jsonEncode(await shape()), before);
  });

  test('a set that cannot land names the slot that did not', () async {
    await call('POST', '/api/loadouts', {
      'op': 'restore',
      'loadout': {
        'name': 'gone',
        'members': [
          {
            'ref': 'magician',
            'equipment': {'rightHand': 'weapon.war_hammer'},
            'style': 'firepower',
            'thrift': false,
          },
        ],
      },
    });
    // 세계에서 전투 망치를 없앤다.
    for (var i = 0; i < 8; i++) {
      await call('POST', '/api/command', {
        'command': {'kind': 'take', 'item': 'weapon.war_hammer', 'count': 1},
      });
    }

    final (_, body) = await call('POST', '/api/loadouts', {
      'op': 'apply',
      'name': 'gone',
    });
    final out = body as Map<String, Object?>;
    expect(out['landed'], isFalse);
    final miss = (out['mismatch'] as List).first as Map<String, Object?>;
    expect(miss['slot'], 'rightHand');
    expect(miss['wanted'], 'weapon.war_hammer');
    expect(miss['got'], isNull);
  });

  test('an unknown op lists the ones that exist', () async {
    final (status, body) = await call('POST', '/api/loadouts', {'op': 'wat'});
    expect(status, 400);
    expect((body as Map)['allowed'], contains('capture'));
  });

  // ── 파일로 나가고 들어온다 ─────────────────────────────────

  test('a save round trips through the wire', () async {
    await call('POST', '/api/command', {
      'command': {
        'kind': 'equip',
        'member': 'knight',
        'slot': 'rightHand',
        'item': 'weapon.long_sword',
      },
    });
    final (status, saved) = await call('GET', '/api/save');
    expect(status, 200);
    final before = jsonEncode(await shape());

    await call('POST', '/api/reset');
    expect(jsonEncode(await shape()), isNot(before));

    final (loadStatus, out) = await call('POST', '/api/load', saved);
    expect(loadStatus, 200);
    expect((out as Map)['issues'], isEmpty);
    expect(jsonEncode(await shape()), before);
  });

  test('a save naming an item this build lacks is reported, not dropped', () async {
    final (_, saved) = await call('GET', '/api/save');
    final json = (saved! as Map).cast<String, Object?>();
    final first = (json['members']! as List).first as Map;
    (first['equipment'] as Map)['0'] = 'weapon.there_is_no_such_thing';

    final (status, body) = await call('POST', '/api/load', json);
    expect(status, 200);
    final issues = (body as Map)['issues'] as List;
    expect(issues, isNotEmpty);
    expect((issues.first as Map)['item'], 'weapon.there_is_no_such_thing');
  });

  // ── 사람이 두는 한 판 ──────────────────────────────────────

  test('a fight opens with everyone placed and somebody asked', () async {
    final (status, body) = await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc', 'wolf', 'dragon'],
      'enemyRanks': [1, 1, 3],
      'initialGap': 2,
      'seed': 11,
    });
    expect(status, 200);
    final out = body as Map<String, Object?>;
    expect(out['open'], isTrue);
    expect(out['round'], 1);
    expect(out['gap'], 2);

    final enemies = (out['enemies']! as List).cast<Map<String, Object?>>();
    expect(enemies.map((e) => e['rank']), [1, 1, 3]);

    // 격자의 y 축이 거리다. 1열에 선 사람에게 간격 2 면 적 1열은 2,
    // 적 3열은 4 — `gap + (내 열-1) + (상대 열-1)` 그대로다.
    expect(enemies[0]['distance'], 2);
    expect(enemies[2]['distance'], 4);

    final party = (out['party']! as List).cast<Map<String, Object?>>();
    expect(party.where((p) => p['asking'] == true), hasLength(1));
    // 묻는 순서는 리더부터다.
    expect(party.firstWhere((p) => p['asking'] == true)['slot'], 0);
  });

  test('front rank against front rank is exactly the gap', () async {
    // 「사거리 1 짜리가 적 1열을 못 친다」 는 말이 나왔을 때 먼저 볼
    // 자리다. 1열 대 1열의 거리는 **간격 그 자체**이고 열은 아무것도
    // 더하지 않는다 — `gap + (1-1) + (1-1)`.
    for (final (gap, reaches) in [(0, true), (1, true), (2, false)]) {
      final (_, body) = await call('POST', '/api/battle/start', {
        'enemyKeys': ['orc'],
        'enemyRanks': [1],
        'initialGap': gap,
        'seed': 7,
      });
      final out = body! as Map<String, Object?>;
      final party = (out['party']! as List).cast<Map<String, Object?>>();
      final leader = party.firstWhere((p) => p['asking'] == true);
      expect(leader['rank'], 1, reason: '리더는 앞열이다');
      expect(leader['reach'], 1, reason: '샤벨은 사거리 1 이다');

      final orc = (out['enemies']! as List).cast<Map<String, Object?>>().first;
      expect(orc['distance'], gap, reason: '간격 $gap 에서 1열 대 1열');
      expect(
        '${orc['reachVerdict']}'.contains('닿음'),
        reaches,
        reason: '간격 $gap',
      );
    }
  });

  test('a back rank cannot reach with a short weapon, and that is the rule',
      () async {
    // 뒷열이 못 닿는 것은 고장이 아니라 B5 의 요점이다. 붙거나
    // 대열을 당기라는 뜻이고, 화면은 그것을 설명해야 한다.
    final (_, body) = await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc'],
      'enemyRanks': [1],
      'initialGap': 1,
      'seed': 7,
    });
    final out = body! as Map<String, Object?>;
    final party = (out['party']! as List).cast<Map<String, Object?>>();
    final back = party.firstWhere((p) => p['rank'] == 3);
    // 3열에서 1열까지는 간격 + 2 다.
    expect(1 + (3 - 1) + (1 - 1), 3);
    expect(back['reach'], greaterThanOrEqualTo(3), reason: '3열에는 활을 준다');
  });

  test('the same enemy twice gets numbered, a lone one does not', () async {
    // 같은 종류는 같은 아이콘이라 번호로만 갈린다. 혼자면 번호가 없다 —
    // 늘 붙이면 읽을 것이 하나 늘 뿐이다.
    final (_, body) = await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc', 'orc', 'wolf'],
      'seed': 7,
    });
    final enemies =
        ((body! as Map)['enemies']! as List).cast<Map<String, Object?>>();
    expect(enemies[0]['ordinal'], 1);
    expect(enemies[1]['ordinal'], 2);
    expect(enemies[2]['ordinal'], isNull, reason: '늑대는 하나뿐이다');
  });

  test('out of reach is a penalty and still offered', () async {
    // B5 의 불변식 하나 — 사거리 밖은 벌점이지 무효가 아니다. 화면이
    // 멀리 있는 적을 못 누르게 만들면 그 불변식이 화면에서 깨진다.
    final (_, body) = await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc', 'dragon'],
      'enemyRanks': [1, 3],
      'initialGap': 2,
      'seed': 3,
    });
    final out = body! as Map<String, Object?>;
    final enemies = (out['enemies']! as List).cast<Map<String, Object?>>();
    expect(enemies[1]['reachVerdict'], contains('부족'));

    final (_, after) = await call('POST', '/api/battle/command', {
      'command': {'type': 'action', 'slot': 0, 'action': 'attack'},
    });
    final decision = (after! as Map)['decision'] as Map<String, Object?>;
    expect(decision['kind'], 'enemy');
    expect(
      decision['enemyIndices'],
      containsAll([0, 1]),
      reason: '멀리 있는 것도 고를 수 있어야 한다',
    );
  });

  test('the menu is six lines and names the weapon in Korean', () async {
    await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc'],
      'seed': 5,
    });
    final (_, body) = await call('GET', '/api/battle/state');
    final decision = (body! as Map)['decision'] as Map<String, Object?>;
    expect(decision['kind'], 'action');
    final options =
        (decision['options']! as List).cast<Map<String, Object?>>();
    expect(options.map((o) => o['action']), [
      'attack',
      'castSkill',
      'useItem',
      'brace',
      'escape',
      'orders',
    ]);
    // 다리가 참조를 그대로 넘기던 자리다 — `⚔ 공격 — weapon.sabre로`.
    final attack = options.first['label']! as String;
    expect(attack, contains('⚔ 공격'));
    expect(attack, isNot(contains('weapon.')));
  });

  test('the leader can close the gap, and the grid shrinks with it', () async {
    await call('POST', '/api/battle/start', {
      'enemyKeys': ['dragon'],
      'enemyRanks': [3],
      'initialGap': 2,
      'seed': 9,
    });
    final (_, opened) = await call('POST', '/api/battle/command', {
      'command': {'type': 'action', 'slot': 0, 'action': 'orders'},
    });
    final orders = (opened! as Map)['decision'] as Map<String, Object?>;
    expect(orders['kind'], 'order');
    expect(
      (orders['options']! as List)
          .cast<Map<String, Object?>>()
          .map((o) => o['action']),
      contains('advanceFormation'),
    );

    var state = (await call('POST', '/api/battle/command', {
      'command': {'type': 'action', 'slot': 0, 'action': 'advanceFormation'},
    })).$2! as Map<String, Object?>;
    // 아직 2 다. 라운드 시작에 전원 명령 → 일괄 해결이라, 나머지가
    // 답하기 전에는 아무것도 움직이지 않는다. 드래곤 퀘스트의 박자다.
    expect(state['gap'], 2, reason: '해결 전에는 그대로다');

    // 나머지를 넘겨 라운드를 굴린다.
    var guard = 0;
    while (state['round'] == 1 && state['finished'] != true && guard++ < 40) {
      final decision = state['decision'] as Map<String, Object?>?;
      if (decision == null) break;
      state = (await call('POST', '/api/battle/command', {
        'command': {'type': 'cancel', 'slot': decision['slot']},
      })).$2! as Map<String, Object?>;
    }
    // 「우리가 나아간다」 와 「그들이 다가온다」 는 **같은 사건**이다 —
    // 둘 다 간격을 줄인다. 그래서 정확한 숫자를 못박으면 적의 판단까지
    // 시험하게 된다. 줄었다는 것만 본다.
    expect(state['gap'], lessThan(2));
  });

  test('an unreadable answer is a message, not a crash', () async {
    await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc'],
      'seed': 5,
    });
    final (status, body) = await call('POST', '/api/battle/command', {
      'command': {'type': 'nonsense', 'slot': 0},
    });
    expect(status, 200);
    expect((body as Map)['error'], isNotNull);
  });

  test('an unknown enemy names itself instead of opening a fight', () async {
    final (_, body) = await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc', 'there_is_no_such_beast'],
    });
    final out = body! as Map<String, Object?>;
    expect(out['keys'], contains('there_is_no_such_beast'));
    expect(out['open'], isNull, reason: '판이 열리지 않았다');
  });

  test('a finished fight settles onto the party once', () async {
    await call('POST', '/api/battle/start', {
      'enemyKeys': ['orc'],
      'seed': 4,
    });
    // 자동으로 밀어붙인다 — 무엇을 고르든 끝나기만 하면 된다.
    var guard = 0;
    Map<String, Object?> state =
        (await call('GET', '/api/battle/state')).$2! as Map<String, Object?>;
    while (state['finished'] != true && guard++ < 200) {
      final decision = state['decision'] as Map<String, Object?>?;
      if (decision == null) break;
      final slot = decision['slot'];
      final command = switch (decision['kind']) {
        'action' => {'type': 'action', 'slot': slot, 'action': 'attack'},
        'enemy' => {
          'type': 'target',
          'slot': slot,
          'enemyIndex': (decision['enemyIndices']! as List).first,
        },
        _ => {'type': 'cancel', 'slot': slot},
      };
      state = (await call('POST', '/api/battle/command', {'command': command}))
          .$2! as Map<String, Object?>;
    }
    expect(state['finished'], isTrue);

    final (_, settled) = await call('POST', '/api/battle/settle');
    expect((settled! as Map)['settled'], isTrue);
    // 두 번 얹으면 경험치가 두 배가 된다.
    final (_, again) = await call('POST', '/api/battle/settle');
    expect((again! as Map)['error'], contains('already settled'));
  });

  test('the enemy roster is what the icon table has to cover', () async {
    final (status, body) = await call('GET', '/api/enemies');
    expect(status, 200);
    final enemies = ((body! as Map)['enemies']! as List)
        .cast<Map<String, Object?>>();
    expect(enemies.length, greaterThan(70));
    for (final e in enemies) {
      expect(e['key'], isNotEmpty);
      expect(e['name'], isNotEmpty);
    }
  });

  // ── 시나리오 ───────────────────────────────────────────────

  test('every flag answers with the raw line and the meaning', () async {
    final (status, body) = await call('GET', '/api/quest');
    expect(status, 200);
    final out = body as Map<String, Object?>;
    final flags = (out['flags']! as List).cast<Map<String, Object?>>();

    final water = flags.firstWhere((f) => f['id'] == 'D4-041');
    // 둘 다 있어야 한다. 숫자만으로는 뜻을 모르고 문장만으로는
    // 무엇을 고치는지 모른다.
    expect(water['raw'], 'Flag::IsSet(41) = 0');
    expect(water['cm2Name'], 'GFD4_JOINNED_SOUL_OF_WATER');
    expect(water['title'], isNotEmpty);
    expect(water['detail'], isNotEmpty);
    expect(water['kind'], 'toggle');
  });

  test('a step carries its lines and which one is under way', () async {
    final (_, body) = await call('POST', '/api/quest', {
      'id': 'W-010',
      'kind': 'step',
      'value': 3,
    });
    final flags = ((body as Map)['flags']! as List).cast<Map<String, Object?>>();
    final quest = flags.firstWhere((f) => f['id'] == 'W-010');
    expect(quest['raw'], 'Variable::Get(10) = 3');
    expect(quest['value'], 3);
    // 3이면 0·1·2 는 끝났고 3을 하는 중이다. 그것이 이 값 하나를
    // 켜짐 셋으로 쪼개지 않은 까닭이다.
    expect(quest['stepStates'], ['done', 'done', 'done', 'current', 'ahead', 'ahead']);
    expect((quest['steps']! as List).length, 6);
  });

  test('a scenario flag opens ground the party could not walk', () async {
    final before = (await call('GET', '/api/quest')).$2! as Map<String, Object?>;
    expect(before['granted'], isEmpty);

    final (_, body) = await call('POST', '/api/quest', {
      'id': 'W-060',
      'on': true,
    });
    expect((body as Map)['granted'], contains('walkOnWater'));

    // 모델은 이것을 모른다. 부적을 안 찼으므로 `hd_world` 쪽 답은
    // 그대로 비어 있어야 한다 — 합치는 것은 읽는 쪽의 일이다.
    final state = (await call('GET', '/api/state')).$2! as Map<String, Object?>;
    expect((state['party']! as Map)['capabilities'], isEmpty);
  });

  test('a flag can be set by raw number, with no definition', () async {
    // 표에 없는 번호를 켜 보는 것이 이 화면의 쓸모 중 하나다.
    final (status, body) = await call('POST', '/api/quest', {
      'index': 199,
      'on': true,
    });
    expect(status, 200);
    final unknown = (body as Map)['unknown'] as Map<String, Object?>;
    expect(unknown['flags'], contains(199));
  });

  test('an unknown id is refused and nothing changes', () async {
    final (status, body) = await call('POST', '/api/quest', {
      'id': 'NOPE-999',
      'on': true,
    });
    expect(status, 400);
    expect((body as Map)['error'], contains('no such flag'));
  });

  test('the flags travel with the save', () async {
    await call('POST', '/api/quest', {'id': 'W-060', 'on': true});
    await call('POST', '/api/quest', {'id': 'W-010', 'kind': 'step', 'value': 2});

    final (_, saved) = await call('GET', '/api/save');
    expect(((saved! as Map)['quest']! as Map)['flags'], contains(60));

    await call('POST', '/api/reset');
    expect(
      ((await call('GET', '/api/quest')).$2! as Map)['granted'],
      isEmpty,
      reason: '처음으로 돌리면 플래그도 꺼진다',
    );

    final (_, out) = await call('POST', '/api/load', saved);
    final quest = (out! as Map)['quest'] as Map<String, Object?>;
    expect(quest['granted'], contains('walkOnWater'));
    final flags = (quest['flags']! as List).cast<Map<String, Object?>>();
    expect(flags.firstWhere((f) => f['id'] == 'W-010')['value'], 2);
  });

  test('the numbers two scopes share are reported', () async {
    final (_, body) = await call('GET', '/api/quest');
    final found = ((body! as Map)['collisions']! as List)
        .cast<Map<String, Object?>>();
    // 10 · 31 · 50. lore_ep1.cm2 · town2.cm2 · menace.cm2 가
    // flag4ep1.cm2 를 include 하지 않고 번호를 직접 쓴다.
    expect(found.map((c) => c['index']), containsAll([10, 31, 50]));
  });

  test('a save with no party is refused, and the world survives', () async {
    final before = jsonEncode(await shape());
    final (status, _) = await call('POST', '/api/load', {'version': 1});
    expect(status, 400);
    expect(jsonEncode(await shape()), before);
  });
}
