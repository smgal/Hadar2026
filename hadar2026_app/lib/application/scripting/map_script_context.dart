import '../../domain/map/map_model.dart';
import '../../domain/party/party.dart';
import '../game_session.dart';
import '../ports/host_binding.dart';

/// The API surface a native map script (`HDMapScript`) sees as `game`.
///
/// Native map scripts are an authoring surface, so this composes session
/// state and the `UiHost` port behind one object rather than making every
/// script reach for two singletons. It exists so map scripts never name
/// `HDGameMain` — which lives above the layering and drags
/// `flutter/material` plus the whole presentation layer in with it.
class HDMapScriptContext {
  const HDMapScriptContext();

  HDGameSession get _session => HDGameSession();

  HDParty get party => _session.party;
  MapModel? get map => _session.map;

  Future<void> addLog(String message, {bool isDialogue = true}) =>
      HDHosts().ui.addLog(message, isDialogue: isDialogue);

  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  }) => HDHosts().ui.showMenu(
    items,
    initialChoice: initialChoice,
    enabledCount: enabledCount,
    clearLogs: clearLogs,
  );

  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  }) => HDHosts().ui.showWindowMenu(
    items,
    initialChoice: initialChoice,
    enabledCount: enabledCount,
    x: x,
    y: y,
  );

  Future<void> showMessageWindow(String text, {int? x, int? y}) =>
      HDHosts().ui.showMessageWindow(text, x: x, y: y);

  Future<void> waitForAnyKey() => HDHosts().ui.waitForAnyKey();

  void clearLogs() => HDHosts().ui.clearLogs();

  void setHeader(String text) => HDHosts().ui.setHeader(text);

  void refresh() => HDHosts().ui.refresh();
}
