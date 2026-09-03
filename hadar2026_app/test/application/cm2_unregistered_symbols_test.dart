import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/game_session.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';

/// Map::SetLightArea asks the host to repaint, so a host has to be bound
/// or the port throws and the engine aborts the rest of the script.
class _SilentUi implements UiHost {
  @override
  void refresh() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Unused implements PartyMovementHost, AssetSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used by these tests');
}

/// Runs [source] through the real adapter, returning the engine variables
/// so a function's value and a command's side effect can both be seen.
Future<List<int>> _run(String source) async {
  final engine = HDScriptEngine();
  await engine.loadFromString(source);
  await engine.run();
  return HDGameSession().gameOption.variables;
}

void main() {
  final party = HDGameSession().party;

  setUp(() {
    HDHosts().bind(ui: _SilentUi(), movement: _Unused(), assets: _Unused());
    party.magicTorch = 0;
    party.levitation = 0;
    party.walkOnWater = 0;
    party.walkOnSwamp = 0;
    party.mindControl = 0;
    HDGameSession().lightAreas.clear();
  });

  tearDown(HDHosts().reset);

  group('Party::CheckIf', () {
    test('reads the five buff fields in const.cm2 order', () async {
      party.magicTorch = 3;
      party.walkOnSwamp = 1;
      final vars = await _run('''
Variable::Set(0, Party::CheckIf(0))
Variable::Set(1, Party::CheckIf(1))
Variable::Set(2, Party::CheckIf(2))
Variable::Set(3, Party::CheckIf(3))
Variable::Set(4, Party::CheckIf(4))
''');
      expect(vars.sublist(0, 5), [1, 0, 0, 1, 0],
          reason: 'MAGICTORCH LEVITATION WALKONWATER WALKONSWAMP MINDCONTROL');
    });

    test('an index outside 0..4 returns 0 loudly', () async {
      final vars = await _run('Variable::Set(0, Party::CheckIf(9))');
      expect(vars[0], 0);
    });

    // THE REGRESSION THIS ISSUE EXISTS FOR. While Party::CheckIf was
    // unregistered, cm2 printed "Unknown function" and returned 0, so
    // L1_ep1d2.cm2:200's `Not(Party::CheckIf(CHECKIF_LEVITATION))` was
    // always true and the party fell off the cliff even while levitating.
    test('levitation now suppresses the cliff branch', () async {
      const cliff = '''
variable(fell)
fell.assign(0)
if (Not(Party::CheckIf(1)))
	Variable::Set(0, 1)
''';
      party.levitation = 0;
      expect((await _run(cliff))[0], 1, reason: 'no levitation -> falls');

      HDGameSession().gameOption.variables[0] = 0;
      party.levitation = 5;
      expect((await _run(cliff))[0], 0,
          reason: 'levitating -> the cliff branch must not run');
    });

    // The magic-torch pair at L1_ep1d4.cm2:45,51 — both branches used to
    // be wrong at once (the first never fired, the second always did).
    test('the magic-torch pair fires exactly one branch each way', () async {
      const pair = '''
if (Party::CheckIf(0))
	Variable::Set(0, 1)
if (Not(Party::CheckIf(0)))
	Variable::Set(1, 1)
''';
      party.magicTorch = 0;
      var vars = await _run(pair);
      expect([vars[0], vars[1]], [0, 1], reason: 'torch off');

      HDGameSession().gameOption.variables[0] = 0;
      HDGameSession().gameOption.variables[1] = 0;
      party.magicTorch = 4;
      vars = await _run(pair);
      expect([vars[0], vars[1]], [1, 0], reason: 'torch on');
    });

    // This is what a silent mis-branch looks like: an unregistered cm2
    // *function* prints "Unknown function" and returns 0, which is
    // indistinguishable from a legitimate false.
    test('a typo returns 0, quietly taking the wrong branch', () async {
      party.levitation = 5;
      final vars = await _run('Variable::Set(0, Party::CheckIff(1))');
      expect(vars[0], 0, reason: 'the party is levitating, yet this says no');
    });
  });

  group('Player::ApplyAttribute / ReviseAttribute', () {
    test('ApplyAttribute fills the 1-based player to full', () async {
      final p = party.players[0]
        ..maxHp = 150
        ..hp = 10
        ..maxSp = 100
        ..sp = 5
        ..maxEsp = 80
        ..esp = 0;
      await _run('Player::ApplyAttribute(1)');
      expect([p.hp, p.sp, p.esp], [150, 100, 80]);
    });

    // menace.cm2:54 calls ReviseAttribute(6) after zeroing the sixth
    // member's gear, to pull current values back under their maxima.
    test('ReviseAttribute clamps the 6th player and leaves the rest', () async {
      final sixth = party.players[5]
        ..maxHp = 40
        ..hp = 999
        ..maxSp = 20
        ..sp = 5;
      final first = party.players[0]..hp = 7;
      await _run('Player::ReviseAttribute(6)');
      expect(sixth.hp, 40);
      expect(sixth.sp, 5, reason: 'already under max, untouched');
      expect(first.hp, 7, reason: 'a different player is not touched');
    });

    test('a player index outside 1..6 is refused, not applied to slot 0',
        () async {
      final first = party.players[0]
        ..maxHp = 100
        ..hp = 1;
      await _run('Player::ApplyAttribute(0)');
      await _run('Player::ApplyAttribute(7)');
      expect(first.hp, 1);
    });
  });

  group('Map::SetLightArea / ResetLightArea', () {
    test('lights a rectangle and takes it back', () async {
      final areas = HDGameSession().lightAreas;
      // L1_ep1d1.cm2:331
      await _run('Map::SetLightArea(8,10, 14,15)');
      expect(areas.isLit(8, 10), isTrue);
      expect(areas.isLit(14, 15), isTrue);
      expect(areas.isLit(11, 12), isTrue);
      expect(areas.isLit(7, 10), isFalse);
      expect(areas.isLit(8, 16), isFalse);

      await _run('Map::ResetLightArea(8,10, 14,15)');
      expect(areas.isLit(11, 12), isFalse);
      expect(areas.count, 0);
    });

    // L1_ep1d4.cm2:73 resets exactly the 12,16,12,16 that :480 sets.
    test('the single-tile round trip from L1_ep1d4 works', () async {
      final areas = HDGameSession().lightAreas;
      await _run('Map::SetLightArea(12,16, 12,16)');
      expect(areas.isLit(12, 16), isTrue);
      await _run('Map::ResetLightArea(12,16, 12,16)');
      expect(areas.isLit(12, 16), isFalse);
    });

    test('a malformed call is refused rather than half-applied', () async {
      final areas = HDGameSession().lightAreas;
      await _run('Map::SetLightArea(1,2)');
      await _run('Map::SetLightArea(1,2, -3,4)');
      expect(areas.count, 0);
    });
  });

}
