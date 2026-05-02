import 'dart:async';

import '../domain/map/map_model.dart';
import '../domain/map/tile_properties.dart';
import '../domain/party/party.dart';
import '../application/game_session.dart';
import '../application/scripting/native_script_runner.dart';
import '../application/scripting/script_engine_adapter.dart';
import 'ports/ui_host.dart';

/// Dispatches a tile's action to one of three event sources, in priority
/// order:
///
///   1. **native map script** (`HDNativeScriptRunner`) — when the current
///      map has a registered Dart `HDMapScript`. JSON `dialogLines` for
///      the tile are emitted alongside the handler (legacy behaviour).
///   2. **cm2 paired script** — when `MapInfos.json#cm2` is set for the
///      current map. cm2 signals processing via `Event::MarkHandled`;
///      if it didn't handle the tile, fall through to JSON.
///   3. **JSON `MapEvent.dialogLines`** — static fallback.
///
/// Maps with neither a native nor a paired cm2 fall back to the legacy
/// global cm2 chain (`startup.cm2` → ...) and don't fall through to
/// JSON, preserving pre-migration behaviour.
///
/// Ambient terrain events (swamp/lava/water) are handled separately and
/// always run on the auto path, regardless of scripted dispatch.
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

      final bool isScriptedAction = isInteraction
          ? (action == HDTileProperties.ACTION_TALK ||
                action == HDTileProperties.ACTION_SIGN ||
                action == HDTileProperties.ACTION_ENTER)
          : (action == HDTileProperties.ACTION_EVENT ||
                action == HDTileProperties.ACTION_ENTER);

      if (isScriptedAction) {
        host.beginNarrative();
        narrativeOpened = true;
        host.clearLogs();
        await Future.delayed(Duration.zero);

        await _dispatchScripted(action, x, y, map, host);
      } else if (!isInteraction) {
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

  Future<void> _dispatchScripted(
    int action,
    int x,
    int y,
    MapModel map,
    UiHost host,
  ) async {
    final native = HDNativeScriptRunner();
    final cm2Path = HDGameSession().currentMapCm2Path;

    if (native.currentMapScript != null) {
      // Native map (legacy behaviour preserved): emit JSON dialogLines
      // for the tile alongside the native handler. The handler's
      // "handled" return value is the new wiring but at this tier nothing
      // downstream needs it yet — cm2 fallback for native maps is wired
      // in step 4 once a paired-cm2 native map exists.
      await _emitJsonDialog(map, x, y, host);
      await native.processMapEvent(action, x, y);
      return;
    }

    if (cm2Path != null) {
      // cm2-paired map (new model): cm2 first, JSON fallback when cm2
      // didn't mark the tile as handled.
      HDScriptEngine().setTargetPos(x, y);
      HDScriptEngine().setScriptMode(action);
      await HDScriptEngine().run();
      if (HDScriptEngine().handled) return;
      await _emitJsonDialog(map, x, y, host);
      return;
    }

    // Legacy maps (no native, no paired cm2): emit JSON dialogLines
    // and run the global cm2 chain alongside — matches the pre-migration
    // `processMapEvent` flow (JSON pre-emit + cm2 fallback) so static
    // event dialogue keeps showing on un-paired maps.
    await _emitJsonDialog(map, x, y, host);
    HDScriptEngine().setTargetPos(x, y);
    HDScriptEngine().setScriptMode(action);
    await HDScriptEngine().run();
  }

  Future<void> _emitJsonDialog(
    MapModel map,
    int x,
    int y,
    UiHost host,
  ) async {
    for (final ev in map.events) {
      if (ev.x == x && ev.y == y) {
        for (final line in ev.dialogLines) {
          if (line.isNotEmpty) {
            await host.addLog(line);
          }
        }
        return;
      }
    }
  }
}
