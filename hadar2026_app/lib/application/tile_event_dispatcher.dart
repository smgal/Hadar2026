import 'dart:async';

import '../domain/map/map_model.dart';
import '../domain/map/tile_properties.dart';
import '../domain/party/party.dart';
import '../application/scripting/native_script_runner.dart';
import '../application/scripting/script_engine_adapter.dart';
import 'ports/ui_host.dart';

/// Owns the script-running flag and dispatches a tile's action to:
/// - native map scripts (`HDNativeScriptRunner`), then
/// - the CM2 script engine as fallback, and
/// - internal engine events (swamp/lava/water).
///
/// Caller passes the current map, party, and a [UiHost]; this keeps the
/// dispatcher free of [HDGameMain] except for what it really needs.
class HDTileEventDispatcher {
  static final HDTileEventDispatcher _instance =
      HDTileEventDispatcher._internal();
  factory HDTileEventDispatcher() => _instance;
  HDTileEventDispatcher._internal();

  bool _isScriptRunning = false;
  bool get isScriptRunning => _isScriptRunning;

  Future<void> check({
    required MapModel? map,
    required HDParty party,
    required UiHost host,
    required int x,
    required int y,
    bool isInteraction = false,
  }) async {
    if (map == null) return;
    if (_isScriptRunning) return;

    _isScriptRunning = true;
    bool narrativeOpened = false;
    try {
      final action = HDTileProperties.getUnitAction(map.getUnit(x, y));

      // Talk / Sign / Enter / step-on Event paths run scripted dialogue —
      // wrap them in a narrative cycle so the overlay stays open across
      // the whole sequence (Talk → PressAnyKey → next Talk → …) without
      // flashing back to the progress base layer between pages.

      if (isInteraction) {
        if (action == HDTileProperties.ACTION_TALK ||
            action == HDTileProperties.ACTION_SIGN ||
            action == HDTileProperties.ACTION_ENTER) {
          host.beginNarrative();
          narrativeOpened = true;
          host.clearLogs();
          await Future.delayed(Duration.zero);

          await HDNativeScriptRunner().processMapEvent(action, x, y);
          if (HDNativeScriptRunner().currentMapScript == null) {
            HDScriptEngine().setTargetPos(x, y);
            HDScriptEngine().setScriptMode(action);
            await HDScriptEngine().run();
          }
        }
      } else {
        // Step-On (automatic) — script events
        if (action == HDTileProperties.ACTION_EVENT ||
            action == HDTileProperties.ACTION_ENTER) {
          host.beginNarrative();
          narrativeOpened = true;
          host.clearLogs();
          await Future.delayed(Duration.zero);

          await HDNativeScriptRunner().processMapEvent(action, x, y);
          if (HDNativeScriptRunner().currentMapScript == null) {
            HDScriptEngine().setTargetPos(x, y);
            HDScriptEngine().setScriptMode(action);
            await HDScriptEngine().run();
          }
        }

        // Ambient terrain events: these belong on the always-visible
        // progress base layer — they're the "you suddenly feel cold"
        // flavor messages that should flow with movement, not pop up an
        // overlay.
        if (action == HDTileProperties.ACTION_SWAMP) {
          await host.addLog("일행은 독이 있는 늪에 들어갔다 !!!", isDialogue: false);
        } else if (action == HDTileProperties.ACTION_LAVA) {
          await host.addLog("일행은 용암지대로 들어섰다 !!!", isDialogue: false);
        } else if (action == HDTileProperties.ACTION_WATER) {
          if (party.walkOnWater > 0) {
            party.walkOnWater--;
            party.notifyListeners();
          }
        }
      }
    } finally {
      if (narrativeOpened) {
        await host.endNarrative();
      }
      _isScriptRunning = false;
    }
  }
}
