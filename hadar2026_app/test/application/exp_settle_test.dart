import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hadar2026_app/application/battle_bridge/level_up.dart';
import 'package:hadar2026_app/application/battle_bridge/setup_assembly.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/domain/party/party.dart';

/// B3-05 — 경험치는 전투가 세고, 레벨은 RPG 가 올린다.
///
/// **이 갈라짐이 한동안 반쪽이었다.** B3 가 전투를 새 model 로 옮기면서
/// `application/battle.dart:287` 이 죽은 코드가 됐고, 그것이 레포에서
/// `checkLevelUp()` 을 부르는 **유일한 곳**이었다. 그때부터 경험치만 쌓이고
/// 레벨은 전혀 오르지 않았다.

class _Lines implements UiHost {
  final List<String> logs = [];

  @override
  Future<void> addLog(String message, {bool isDialogue = true}) async {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('정산은 화면에 줄만 찍는다. 부른 것: ${invocation.memberName}');
}

hb.CombatantResult resultFor(int slot, int exp, HDParty party) {
  final p = party.players[slot];
  return hb.CombatantResult(
    slot: slot,
    hp: p.hp,
    sp: p.sp,
    esp: p.esp,
    poison: 0,
    unconscious: 0,
    dead: 0,
    experienceGained: exp,
  );
}

hb.BattleOutcome outcomeOf(
  List<hb.CombatantResult> combatants, {
  hb.BattleResultCode code = hb.BattleResultCode.win,
}) => hb.BattleOutcome(
  resultCode: code,
  combatants: combatants,
  goldGained: 0,
  worldEffects: const [],
  consumedItems: const {},
  recruits: const [],
  departedSlots: const [],
);

void main() {
  late HDParty party;
  late _Lines host;

  setUp(() {
    party = HDParty();
    host = _Lines();
  });

  test('경험치는 정확히 한 번만 더해진다', () {
    final before = party.players[0].experience;
    applyOutcome(party, outcomeOf([resultFor(0, 500, party)]));
    expect(party.players[0].experience, before + 500);
  });

  // 표의 첫 문턱은 1500 이다 (`player.dart` 의 expTable).
  test('전투가 끝난 뒤에 레벨이 오르고 그 줄이 나온다', () async {
    final p = party.players[0];
    p.level.physical = 1;
    p.experience = 0;
    applyOutcome(party, outcomeOf([resultFor(0, 1500, party)]));
    expect(p.level.physical, 1, reason: '정산만으로는 아직 안 오른다');

    await settleLevelUps(party, outcomeOf([resultFor(0, 1500, party)]), host);
    expect(p.level.physical, 2);
    expect(host.logs.single, contains('전투 레벨이 2로 올랐다'));
  });

  test('오를 만큼 못 받았으면 아무 줄도 안 나온다', () async {
    party.players[0].level.physical = 1;
    party.players[0].experience = 10;
    await settleLevelUps(party, outcomeOf([resultFor(0, 10, party)]), host);
    expect(host.logs, isEmpty);
  });

  // 원작도 그랬다 — 진 전투에서는 `checkLevelUp` 을 부르지 않았다.
  // 처치 경험치는 남아 있다가 다음에 이길 때 함께 오른다.
  test('진 전투에서는 올리지 않는다 — 경험치는 남는다', () async {
    final p = party.players[0];
    p.level.physical = 1;
    p.experience = 0;
    final lost = outcomeOf([
      resultFor(0, 1500, party),
    ], code: hb.BattleResultCode.lose);
    applyOutcome(party, lost);
    await settleLevelUps(party, lost, host);
    expect(p.level.physical, 1);
    expect(p.experience, 1500, reason: '경험치는 그대로 남는다');
    expect(host.logs, isEmpty);

    // 다음에 이기면 그때 오른다.
    final won = outcomeOf([resultFor(0, 1, party)]);
    applyOutcome(party, won);
    await settleLevelUps(party, won, host);
    expect(p.level.physical, 2);
  });

  // 막타를 넣고 쓰러진 사람도 오른다 — 경험치를 줄지 말지는 규격이 이미
  // 정했으므로, RPG 가 여기서 의식을 다시 따지면 그 사람만 손해다.
  test('경험치를 받았으면 쓰러져 있어도 오른다', () async {
    final p = party.players[1];
    p.level.physical = 1;
    p.experience = 0;
    p.unconscious = 1;
    await settleLevelUps(party, outcomeOf([resultFor(1, 0, party)]), host);
    expect(p.level.physical, 1, reason: '경험치가 0 이면 볼 것도 없다');

    p.experience = 1500;
    await settleLevelUps(party, outcomeOf([resultFor(1, 1500, party)]), host);
    expect(p.level.physical, 2);
  });
}
