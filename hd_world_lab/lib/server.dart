import 'dart:convert';
import 'dart:io';

import 'package:hd_world/hd_world.dart';

import 'battle_run.dart';
import 'battle_session.dart';
import 'command_codec.dart';
import 'eligibility_view.dart';
import 'loadouts.dart';
import 'preview.dart';
import 'quest/flag_registry.dart';
import 'quest/quest_state.dart';
import 'text_tables.dart';

/// The HTTP surface over one [World].
///
/// ## Why an API and not only a console
///
/// A terminal is a poor place to try equipment on. Swapping a shield for
/// a torch and reading what changed wants a pointer and a side-by-side
/// view, so the model gets an HTTP door and two clients through it: a
/// page for hands, and plain JSON for scripts and agents.
///
/// The same shape serves both because the model already speaks in
/// commands and events. Nothing here holds a rule.
///
/// **Local only, and no authentication.** It reads and writes one
/// in-memory world on a developer's machine; it is not built to be
/// exposed.
class LabServer {
  LabServer({required this.root, World? world})
    : _world = world ?? buildSampleWorld();

  /// Directory holding the page and the specification.
  final Directory root;

  World _world;

  World get world => _world;

  /// Named equipment sets. In memory with the world, and lost with it —
  /// a loadout is a thing to compare with in one sitting, not an asset.
  /// `GET /api/loadouts` hands the whole book out for anyone who wants
  /// to keep one.
  final Loadouts _loadouts = Loadouts();

  /// 시나리오 진행. 세계와 나란히 있고 **서로를 모른다** — `hd_world` 는
  /// 플래그를 모르고 플래그는 장비를 모른다. 둘을 합치는 것은 읽는
  /// 쪽의 일이고, 여기서는 `GET /api/quest` 의 `granted` 가 그 자리다.
  QuestState _quest = QuestState();

  QuestState get quest => _quest;

  /// 지금 열려 있는 한 판. `POST /api/battle` 의 자동 판과 달리 물음마다
  /// 멈춰 서서 사람을 기다린다.
  final BattleSession _fight = BattleSession();

  HttpServer? _server;

  int get port => _server?.port ?? 0;

  Future<void> start({int port = 5330, String address = '127.0.0.1'}) async {
    _server = await HttpServer.bind(address, port);
    _server!.listen(_handle, onError: (Object _) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('access-control-allow-origin', '*')
      ..set('access-control-allow-headers', 'content-type')
      ..set('access-control-allow-methods', 'GET, POST, OPTIONS')
      ..set('cache-control', 'no-store');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final path = request.uri.path;
    try {
      if (path.startsWith('/api/')) {
        await _api(request, path);
        return;
      }
      await _static(request, path);
    } catch (error) {
      await _json(response, HttpStatus.internalServerError, {
        'error': '$error',
      });
    }
  }

  Future<void> _api(HttpRequest request, String path) async {
    final response = request.response;
    final method = request.method;

    switch ((method, path)) {
      case ('GET', '/api/guide'):
        await _text(response, 'text/markdown; charset=utf-8', _guide);
        return;

      case ('GET', '/api/state'):
        await _json(response, HttpStatus.ok, _world.view.toJson());
        return;

      case ('GET', '/api/catalog'):
        await _json(response, HttpStatus.ok, catalogJson());
        return;

      case ('GET', '/api/text'):
        await _json(response, HttpStatus.ok, textTablesJson());
        return;

      case ('GET', '/api/candidates'):
        final member = request.uri.queryParameters['member'];
        final slotName = request.uri.queryParameters['slot'];
        if (member == null || slotName == null) {
          await _json(response, HttpStatus.badRequest, {
            'error': 'member and slot are required',
          });
          return;
        }
        final slot = EquipSlot.values
            .where((s) => s.name == slotName)
            .firstOrNull;
        if (slot == null) {
          await _json(response, HttpStatus.badRequest, {
            'error': 'unknown slot',
            'allowed': [for (final s in EquipSlot.values) s.name],
          });
          return;
        }
        final refs = _world.candidates(MemberRef(member), slot);
        await _json(response, HttpStatus.ok, {
          'member': member,
          'slot': slot.name,
          'items': [for (final r in refs) r.value],
        });
        return;

      case ('GET', '/api/eligibility'):
        await _json(response, HttpStatus.ok, eligibilityJson(_world));
        return;

      // ── 사람이 두는 한 판 ────────────────────────────────
      //
      // `POST /api/battle` 는 끝까지 스스로 굴린다. 이쪽은 물음마다
      // 멈춘다. 둘 다 같은 `hd_battle` 을 쓰고 규칙은 그쪽에만 있다.

      case ('GET', '/api/enemies'):
        await _json(response, HttpStatus.ok, {'enemies': enemyRosterJson()});
        return;

      case ('GET', '/api/battle/state'):
        await _json(response, HttpStatus.ok, _fight.view());
        return;

      case ('POST', '/api/battle/start'):
        final body = await _body(request);
        final raw = body['enemyKeys'];
        final ranks = body['enemyRanks'];
        final gap = body['initialGap'];
        await _json(
          response,
          HttpStatus.ok,
          _fight.start(
            _world,
            enemyKeys: raw is List
                ? [for (final k in raw) '$k']
                : const ['orc', 'orc', 'wolf'],
            seed: body['seed'] is int
                ? body['seed']! as int
                : DateTime.now().millisecondsSinceEpoch % 100000,
            initialGap: gap is int ? gap : null,
            enemyRanks: ranks is List
                ? [for (final r in ranks) r is int ? r : 1]
                : null,
          ),
        );
        return;

      case ('POST', '/api/battle/command'):
        final body = await _body(request);
        final raw = body['command'];
        await _json(
          response,
          HttpStatus.ok,
          _fight.command(
            raw is Map ? raw.cast<String, Object?>() : body,
          ),
        );
        return;

      case ('POST', '/api/battle/settle'):
        final out = _fight.settleInto(_world);
        await _json(response, HttpStatus.ok, out);
        return;

      case ('POST', '/api/battle/abandon'):
        _fight.abandon();
        await _json(response, HttpStatus.ok, _fight.view());
        return;

      case ('GET', '/api/quest'):
        await _json(response, HttpStatus.ok, questJson(_quest));
        return;

      case ('POST', '/api/quest'):
        await _setFlag(request);
        return;

      case ('POST', '/api/command'):
      case ('POST', '/api/commands'):
        await _runCommands(request, batch: path.endsWith('commands'));
        return;

      case ('POST', '/api/preview'):
        final body = await _body(request);
        final raw = body['commands'] ?? body['command'] ?? body;
        final List<Object?> list = raw is List ? raw : [raw];
        final commands = <WorldCommand>[];
        for (final entry in list) {
          if (entry is! Map) {
            await _json(response, HttpStatus.badRequest, {
              'error': 'each command must be an object',
            });
            return;
          }
          try {
            commands.add(decodeCommand(entry.cast<String, Object?>()));
          } on DecodeFailure catch (failure) {
            await _json(response, HttpStatus.badRequest, failure.toJson());
            return;
          }
        }
        await _json(response, HttpStatus.ok, previewJson(_world, commands));
        return;

      case ('GET', '/api/save'):
        // `hd_world` 의 저장에 `quest` 를 하나 더 얹은 것이다.
        // `loadWorld` 는 모르는 칸을 지나치므로 옛 파일도 그대로 읽히고,
        // 이 파일도 `hd_world` 만 아는 쪽에서 읽힌다.
        await _json(response, HttpStatus.ok, {
          ...saveWorld(_world),
          'quest': _quest.toJson(),
        });
        return;

      case ('POST', '/api/load'):
        final body = await _body(request);
        final result = loadWorld(body);
        if (result.world.members.isEmpty) {
          // A file with no party is a mistake, not a world. Replacing
          // the live one with it would leave nothing to go back to.
          await _json(response, HttpStatus.badRequest, {
            'error': 'the save named no members; nothing was replaced',
            'issues': [for (final i in result.issues) i.toJson()],
          });
          return;
        }
        _world = result.world;
        // 시나리오도 같이 온다. 게임 쪽 세이브가 싣는 256칸 불린 배열도
        // 읽으므로 `gameOption` 을 그대로 넣어도 된다.
        final rawQuest = body['quest'] ?? body['gameOption'];
        _quest = rawQuest is Map
            ? QuestState.fromJson(rawQuest.cast<String, Object?>())
            : QuestState();
        await _json(response, HttpStatus.ok, {
          'loaded': true,
          'issues': [for (final i in result.issues) i.toJson()],
          'state': _world.view.toJson(),
          'quest': questJson(_quest),
        });
        return;

      case ('GET', '/api/loadouts'):
        await _json(response, HttpStatus.ok, _loadouts.toJson());
        return;

      case ('POST', '/api/loadouts'):
        await _loadoutOp(request);
        return;

      case ('POST', '/api/reset'):
        _world = buildSampleWorld();
        _quest = QuestState();
        await _json(response, HttpStatus.ok, {
          'reset': true,
          'state': _world.view.toJson(),
          'quest': questJson(_quest),
        });
        return;

      case ('POST', '/api/battle'):
        final body = await _body(request);
        final raw = body['enemyKeys'];
        final keys = raw is List
            ? [for (final k in raw) '$k']
            : const ['orc', 'orc', 'wolf'];
        final gap = body['initialGap'];
        await _json(
          response,
          HttpStatus.ok,
          runBattle(
            _world,
            enemyKeys: keys,
            seed: body['seed'] is int ? body['seed'] as int : 7,
            initialGap: gap is int ? gap : null,
          ),
        );
        return;

      case ('POST', '/api/magicLight'):
        final body = await _body(request);
        _world.magicLight = body['on'] == true;
        await _json(response, HttpStatus.ok, {
          'magicLight': _world.magicLight,
          'state': _world.view.toJson(),
        });
        return;
    }

    // An undocumented path answers with the list rather than falling
    // through to the page, so a mistyped call is visible immediately.
    await _json(response, HttpStatus.methodNotAllowed, {
      'error': 'no such endpoint',
      'method': method,
      'path': path,
      'endpoints': _endpoints,
    });
  }

  /// 플래그 한 칸을 세우거나 단계를 옮긴다.
  ///
  /// `id` 로도 받고 `index`+`kind` 로도 받는다. `id` 는 사람이 쓰라고
  /// 있는 것이고 번호는 게임이 쓰는 것인데, **둘 다 받아야 한다** —
  /// 레지스트리에 아직 없는 번호를 켜 보는 것이 이 화면의 쓸모 중
  /// 하나다.
  Future<void> _setFlag(HttpRequest request) async {
    final response = request.response;
    final body = await _body(request);

    if (body['op'] == 'reset') {
      _quest.reset();
      await _json(response, HttpStatus.ok, questJson(_quest));
      return;
    }

    final id = body['id'];
    var index = body['index'] is int ? body['index']! as int : -1;
    var kind = '${body['kind'] ?? ''}';

    if (id != null) {
      final def = flagRegistry.where((d) => d.id == '$id').firstOrNull;
      if (def == null) {
        await _json(response, HttpStatus.badRequest, {
          'error': 'no such flag id',
          'id': id,
        });
        return;
      }
      index = def.index;
      kind = def.kind.name;
    }

    if (index < 0 || index >= QuestState.size) {
      await _json(response, HttpStatus.badRequest, {
        'error': 'index must be 0..${QuestState.size - 1}, or give an id',
        'index': index,
      });
      return;
    }

    final ok = switch (kind) {
      'step' => _quest.setValue(index, switch (body['value']) {
        final int v => v,
        _ => _quest.value(index),
      }),
      _ => _quest.set(index, body['on'] == true),
    };

    if (!ok) {
      await _json(response, HttpStatus.badRequest, {
        'error': 'a step value cannot be negative',
        'index': index,
        'value': body['value'],
      });
      return;
    }

    await _json(response, HttpStatus.ok, questJson(_quest));
  }

  /// Capture, apply, restore or forget one named set.
  ///
  /// One endpoint with an `op` rather than four paths, because all four
  /// are the same noun and three of them carry the same single field.
  Future<void> _loadoutOp(HttpRequest request) async {
    final response = request.response;
    final body = await _body(request);
    final op = '${body['op'] ?? ''}';
    final name = '${body['name'] ?? ''}';

    switch (op) {
      case 'capture':
        if (name.isEmpty) {
          await _json(response, HttpStatus.badRequest, {
            'error': 'a captured set needs a name',
          });
          return;
        }
        final set = _loadouts.capture(_world, name);
        await _json(response, HttpStatus.ok, {
          'captured': set.toJson(),
          'loadouts': _loadouts.toJson()['loadouts'],
        });
        return;

      case 'restore':
        final raw = body['loadout'];
        if (raw is! Map) {
          await _json(response, HttpStatus.badRequest, {
            'error': 'restore needs a loadout object',
          });
          return;
        }
        final set = _loadouts.restore(raw.cast<String, Object?>());
        await _json(response, HttpStatus.ok, {
          'restored': set.toJson(),
          'loadouts': _loadouts.toJson()['loadouts'],
        });
        return;

      case 'delete':
        await _json(response, HttpStatus.ok, {
          'deleted': _loadouts.remove(name),
          'loadouts': _loadouts.toJson()['loadouts'],
        });
        return;

      case 'apply':
        final set = _loadouts[name];
        if (set == null) {
          await _json(response, HttpStatus.notFound, {
            'error': 'no such loadout',
            'name': name,
            'known': [for (final l in _loadouts.all) l.name],
          });
          return;
        }
        final events = <Map<String, Object?>>[];
        for (final command in set.plan(_world)) {
          for (final event in _world.apply(command)) {
            events.add(event.toJson());
          }
        }
        final mismatch = set.mismatch(_world);
        await _json(response, HttpStatus.ok, {
          'applied': set.name,
          // `landed` is the answer to "did it work"; `refused` is the
          // answer to "what did the model say on the way". They are not
          // the same question — see `Loadout.mismatch`.
          'landed': mismatch.isEmpty,
          'mismatch': mismatch,
          'events': events,
          'refused': events.where((e) => e['kind'] == 'refused').toList(),
          'state': _world.view.toJson(),
        });
        return;
    }

    await _json(response, HttpStatus.badRequest, {
      'error': 'unknown op',
      'op': op,
      'allowed': ['capture', 'apply', 'delete', 'restore'],
    });
  }

  Future<void> _runCommands(HttpRequest request, {required bool batch}) async {
    final response = request.response;
    final body = await _body(request);
    final List<Object?> raw;
    if (batch) {
      final list = body['commands'];
      if (list is! List) {
        await _json(response, HttpStatus.badRequest, {
          'error': 'commands must be a list',
        });
        return;
      }
      raw = list;
    } else {
      raw = [body['command'] ?? body];
    }

    final commands = <WorldCommand>[];
    for (final entry in raw) {
      if (entry is! Map) {
        await _json(response, HttpStatus.badRequest, {
          'error': 'each command must be an object',
        });
        return;
      }
      try {
        commands.add(decodeCommand(entry.cast<String, Object?>()));
      } on DecodeFailure catch (failure) {
        // Rejected before anything is applied, so a bad entry in a batch
        // cannot leave the world half changed.
        await _json(response, HttpStatus.badRequest, failure.toJson());
        return;
      }
    }

    final events = <Map<String, Object?>>[];
    for (final command in commands) {
      for (final event in _world.apply(command)) {
        events.add(event.toJson());
      }
    }
    await _json(response, HttpStatus.ok, {
      'events': events,
      'refused': events.where((e) => e['kind'] == 'refused').toList(),
      'state': _world.view.toJson(),
    });
  }

  Future<Map<String, Object?>> _body(HttpRequest request) async {
    final text = await utf8.decodeStream(request);
    if (text.trim().isEmpty) return const {};
    final decoded = jsonDecode(text);
    if (decoded is Map) return decoded.cast<String, Object?>();
    throw DecodeFailure('body must be a JSON object');
  }

  Future<void> _static(HttpRequest request, String path) async {
    final response = request.response;
    final relative = path == '/' ? 'index.html' : path.substring(1);
    // No traversal: a served path may not climb out of the directory.
    if (relative.contains('..')) {
      await _json(response, HttpStatus.forbidden, {'error': 'no'});
      return;
    }
    final file = File('${root.path}/$relative');
    if (!file.existsSync()) {
      await _json(response, HttpStatus.notFound, {
        'error': 'not found',
        'path': path,
        'endpoints': _endpoints,
      });
      return;
    }
    response.headers.contentType = switch (relative.split('.').last) {
      'html' => ContentType.html,
      'js' => ContentType('application', 'javascript', charset: 'utf-8'),
      'css' => ContentType('text', 'css', charset: 'utf-8'),
      'yaml' => ContentType('text', 'yaml', charset: 'utf-8'),
      'json' => ContentType.json,
      _ => ContentType.binary,
    };
    await response.addStream(file.openRead());
    await response.close();
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }

  Future<void> _text(
    HttpResponse response,
    String contentType,
    String body,
  ) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers.set('content-type', contentType)
      ..write(body);
    await response.close();
  }
}

const List<String> _endpoints = [
  'GET  /                  the equipment screen',
  'GET  /openapi.yaml      the specification',
  'GET  /api/guide         how to drive this, in prose',
  'GET  /api/state         the party, resolved',
  'GET  /api/catalog       every item, with names',
  'GET  /api/text          every name table',
  'GET  /api/candidates    what fits a slot right now',
  'GET  /api/eligibility   every item against every slot, for everybody',
  'GET  /api/quest         every flag: what it means and where it stands',
  'POST /api/quest         {id|index,kind} + {on} or {value}; {op:reset}',
  'POST /api/command       apply one command',
  'POST /api/commands      apply several, all or nothing on a decode error',
  'POST /api/preview       what a command would change, without changing it',
  'GET  /api/save          the world as a save file',
  'POST /api/load          replace the world with a save file',
  'GET  /api/loadouts      every named equipment set',
  'POST /api/loadouts      {op: capture|apply|delete|restore, name}',
  'POST /api/battle        run one fight to the end, choosing nothing',
  'GET  /api/enemies       every enemy this build knows',
  'GET  /api/battle/state  the open fight: the grid, and what it is asking',
  'POST /api/battle/start  open one — {enemyKeys, enemyRanks, initialGap, seed}',
  'POST /api/battle/command  answer what it asked',
  'POST /api/battle/settle   put the result onto the party',
  'POST /api/battle/abandon  throw the open fight away',
  'POST /api/magicLight    turn the spell light on or off',
  'POST /api/reset         a fresh sample party',
];

/// Prose for whoever drives this without a browser.
///
/// The map editor in this repository serves the same thing at
/// `GET /api/ai`, for the same reason: a specification says what the
/// fields are and not what the domain means.
const String _guide = '''
# hd_world lab

One in-memory party, driven by commands. Everything derived — the
fighting style, the final numbers, what the party can walk on, how far
it sees in the dark — is computed on read. There is nothing to
invalidate and no order you have to call things in.

## The loop

    GET  /api/state                 what is true now
    GET  /api/candidates?member=&slot=   what would be accepted
    POST /api/command               change it

`POST /api/command` takes `{"command": {...}}` or the command object
itself. It answers with `events`, `refused` and the whole new `state`,
so one call is enough per change.

## Asking before doing

    GET  /api/eligibility           every item × every slot × everybody
    POST /api/preview               run it on a copy and diff

`/api/eligibility` is the whole board at once: for each member, for
each item, each slot is `true` or the reason it is not. Carried counts
come alongside rather than folded in, because "you own none" and "that
is not for your class" are different answers and a screen colours them
differently.

`/api/preview` takes the same body as `/api/command` and changes
nothing. It answers with `changes`, which lists only what differed —
per member the stats and slots, then the party, then the pack. Each
change carries the `table` its value belongs to, so a front end can
name it without the server holding any Korean.

## A fight, one choice at a time

    POST /api/battle/start    {enemyKeys, enemyRanks, initialGap, seed}
    GET  /api/battle/state    the grid, and what it is asking
    POST /api/battle/command  answer it
    POST /api/battle/settle   put the result onto the party

`POST /api/battle` runs a fight to the end answering everything with
"hit the nearest thing". This one stops at every question.

Position is two integers, not coordinates: each combatant has a **rank**
(1 front to 3 back) within its own side, and both sides share one
**gap** (0 to 2). So

    distance = gap + (mine - 1) + (theirs - 1)

and "we advance" and "they close" are the same event. Every enemy in the
view carries its `distance` from whoever is being asked, and the
`reachVerdict` for that distance.

**Out of reach is a penalty, not a void.** A weapon that cannot reach
still attacks, at worse accuracy and with a front-rank defender likely
to take the blow instead. Never build a client that hides the far
targets.

Answering does not step the fight. Orders are collected from everyone
and resolved together at the end of the round, so the gap a formation
order asks for only moves once the round resolves.

## The scenario

    GET  /api/quest                 every flag, what it means, where it stands
    POST /api/quest                 turn one on, or move a step

Two kinds, because the original has two. A **toggle** is `Flag::Set` and
answers yes or no. A **step** is `Variable::Add` and answers how far —
value 3 means one and two are done and three is under way, which is why
it is one number and not three toggles.

Every entry carries both halves: the raw line (`Flag::IsSet(41) = 1`)
and what it means in words. Neither is enough on its own — the number
cannot be read and the sentence cannot be edited.

A flag may `grant` a party capability. That is how a scenario widens
where the party can walk: walking on water used to come from an amulet
(while worn) or a spell (for so many tiles), and learning it in a story
is a third source that never runs out. `hd_world` does not know about
flags and must not; `granted` is where the two meet.

`collisions` lists numbers two scopes both use. The game only knows the
number, so `D1-010` and a bare `Flag::Set(10)` elsewhere are one cell.

## Sets, and files

    GET  /api/loadouts              the named sets
    POST /api/loadouts              {"op":"capture","name":"횃불 파티"}
                                    {"op":"apply","name":"횃불 파티"}
    GET  /api/save                  the world as a save file
    POST /api/load                  replace the world with one

Applying a set is an ordinary batch of commands, so it cannot reach a
state a player could not, and a piece that no longer fits comes back in
`refused` instead of being dropped quietly.

## Commands

    {"kind":"equip",     "member":"knight","slot":"leftHand","item":"light.torch"}
    {"kind":"unequip",   "member":"knight","slot":"leftHand"}
    {"kind":"swapHands", "member":"knight"}
    {"kind":"setStyle",  "member":"knight","style":"bulwark","thrift":true}
    {"kind":"give",      "item":"weapon.dagger","count":1}
    {"kind":"take",      "item":"weapon.dagger","count":1}
    {"kind":"reorder",   "order":["magician","knight"]}

Slots: rightHand leftHand body head legs commonAmulet classAmulet1
classAmulet2. The two hands are real slots, so a one-handed weapon may
go in either; a two-handed weapon shuts the off hand.

## Nothing throws

A rejected command comes back as an event of kind `refused` carrying a
`reason`, and the world is unchanged. The reasons are a closed list —
ask `GET /api/text` for the sentence that goes with each. `wrongSlot`
and `wrongClass` are deliberately different answers.

## What to try

* Put `weapon.long_sword` in a knight's right hand and watch the shield
  come off as `offHandCleared`. The off-hand slot then reports
  `locked`.
* Put `weapon.dagger` in the off hand beside `weapon.sabre`: the style
  becomes `dualWield` and `coatingSlots` goes to two. Try
  `weapon.hand_axe` instead and it is refused as `mismatchedPair`.
* Give three torches and equip them on three members with one-handed
  weapons. `sightInDarkness` walks 1, 3, 4, 5 and `moonlight` turns on
  at two. A two-handed weapon puts a torch out.
* Put `commonAmulet.water` on anybody: `capabilities` gains
  `walkOnWater` for the whole party. A second copy adds nothing.
* Offer `classAmulet.oath_crest` to the magician and read the reason.
''';
