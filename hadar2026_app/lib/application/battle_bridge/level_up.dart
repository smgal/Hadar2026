import 'package:hd_battle/hd_battle.dart' as hb;

import '../../domain/party/party.dart';
import '../../domain/party/player.dart';
import '../ports/ui_host.dart';

/// 전투가 끝난 뒤 레벨을 올린다 (B3-05).
///
/// ## 왜 전투 밖인가
///
/// 4차 판정: **전투 중에 레벨이 오르는 일은 없다.** 규격은 level 을 개시
/// 입력으로 받고 경험치 총량만 돌려준다. 그래서 21단계 경험치 표
/// (`player.dart:345-366`)와 `checkLevelUp()` 이 `packages/hd_battle` 에
/// 아예 없다 — `purity_test.dart` 가 그것을 지킨다.
///
/// 그 대신 **부르는 쪽이 여기밖에 없다.** B3 가 전투를 옮기면서
/// `application/battle.dart:287` 을 죽은 코드로 만들었고, 그때부터
/// 레벨이 전혀 오르지 않고 경험치만 쌓였다. 이 파일이 그 자리다.
Future<void> settleLevelUps(
  HDParty party,
  hb.BattleOutcome outcome,
  UiHost host,
) async {
  // **이긴 전투에서만 판정한다.** 지거나 도망친 전투에서도 처치 경험치는
  // 이미 들어가 있지만(`applyOutcome`), 원작은 그때 `checkLevelUp` 을
  // 부르지 않았다 — 경험치는 남아 있다가 다음에 이길 때 함께 오른다.
  // "레벨이 올랐다!" 와 "전멸했습니다" 가 잇달아 나오지 않는 이유이기도 하다.
  if (outcome.resultCode != hb.BattleResultCode.win) return;

  for (final result in outcome.combatants) {
    // 경험치를 못 받은 사람은 오를 일도 없다. 규격이 이미 "의식 있는
    // 사람에게만" 을 적용해 놓았으므로(`battle.dart` 의 `_settleWin`),
    // 여기서 또 의식을 따지면 **막타를 넣고 쓰러진 사람**의 레벨을
    // 빼앗게 된다.
    if (result.experienceGained <= 0) continue;
    final p = _bySlot(party, result.slot);
    if (p == null) continue;
    // `checkLevelUp` 은 오르면 hp/sp/esp 를 최대로 채운다. 그래서
    // **정산이 끝난 뒤**에 불러야 원작과 같다 — 순서가 바뀌면 회복분이
    // 전투 결과로 덮인다.
    if (!p.checkLevelUp()) continue;
    await host.addLog(
      '@E${p.name}${p.name.sub1} 전투 레벨이 ${p.level.physical}로 올랐다!',
      isDialogue: false,
    );
  }
}

HDPlayer? _bySlot(HDParty party, int slot) {
  for (final p in party.players) {
    if (p.order == slot) return p;
  }
  return null;
}
