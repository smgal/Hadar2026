import 'dart:convert';
import 'dart:io';

import 'package:hd_world/hd_world.dart';

import 'battle_run.dart';
import 'command_codec.dart';
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

      case ('POST', '/api/command'):
      case ('POST', '/api/commands'):
        await _runCommands(request, batch: path.endsWith('commands'));
        return;

      case ('POST', '/api/reset'):
        _world = buildSampleWorld();
        await _json(response, HttpStatus.ok, {
          'reset': true,
          'state': _world.view.toJson(),
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
  'POST /api/command       apply one command',
  'POST /api/commands      apply several, all or nothing on a decode error',
  'POST /api/battle        run one fight and settle it onto the party',
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
