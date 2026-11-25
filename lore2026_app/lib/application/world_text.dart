import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as text;

import 'game_session.dart';

export 'package:lore_world_text/lore_world_text.dart' hide refusalLine;

/// 규칙의 결과를 문장으로 — 지금 판의 세계에서 이름을 찾는다.
///
/// 문장 자체는 `packages/lore_world_text` 가 갖는다. 앱에서는 세계를 매번
/// 넘기지 않도록 지금 세션의 것을 대 준다.
List<String> worldLines(Outcome outcome) =>
    text.outcomeLines(outcome, HDGameSession().party.world);

/// 거절 하나를 한 문장으로, 사람 이름을 넣어서.
String refusalLine(Refusal refusal) =>
    text.refusalLine(refusal, world: HDGameSession().party.world);
