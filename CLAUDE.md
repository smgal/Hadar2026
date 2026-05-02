# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter/Dart remake of the classic Korean RPG "또 다른 지식의 성전 (Hadar)". The repo is a multi-package layout, not a single Flutter app.

- `hadar2026_app/` — the Flutter app (Bonfire/Flame engine, `window_manager` for desktop). Entry point `lib/main.dart`.
- `packages/cm2_script/` — standalone Dart package: parser + interpreter for the CM2 scripting language. Pulled in via local path dep.
- `cm2_script_sample/` — CUI demo exercising every cm2_script feature.
- `tools/` — Python scripts for converting/extracting legacy Hadar binary data (maps, enemies, sprites).
- `REF_hadar/` (C++ original), `REF_UNITY_LoreEp1/` (Unity port), `REF_FLUTTER_lore2026/` (sibling Flutter port — git submodule). Read-only reference implementations; do not edit.

## Common commands

```bash
# Flutter app (run on connected device / desktop)
cd hadar2026_app
flutter pub get
flutter run

# Web build (matches the GitHub Actions deploy)
cd hadar2026_app
flutter build web --base-href "/Hadar2026/" --release

# cm2_script package tests
cd packages/cm2_script
dart pub get
dart test                          # all
dart test test/parser_test.dart    # single file

# CM2 scripting CUI sample
cd cm2_script_sample
dart pub get
dart run bin/run.dart
```

`flame` is pinned to `1.35.1` via `dependency_overrides` and `bonfire` is pinned to exactly `3.16.1` in `hadar2026_app/pubspec.yaml` — don't bump them casually. bonfire 3.17.x assumes flame 1.36+ (`RenderGameWidget(behavior:)`) and will not compile against flame 1.35.1.

## Architecture

### `lib/` is layered: domain / application / presentation

`hadar2026_app/lib/` was reorganized from a flat `models/ + views/ + game_components/ + scripting/` into:

- `domain/` — pure data + game rules. Allowed Flutter import: `foundation.dart` only (for `ChangeNotifier`). Subfolders: `party/`, `map/`, `battle/`, `magic/`, `lighting/`, `console/`, `window/`, plus `game_option.dart`.
- `application/` — use-cases that compose domain with a UI host. No `flutter/material`, no `bonfire`, no `flame`. Contains `game_session.dart`, `menu_flows.dart`, `battle.dart`, `magic_system.dart`, `map_navigation.dart`, `tile_event_dispatcher.dart`, `save_manager.dart`, `select.dart`, `map_loader.dart`, `scripting/` (CM2 adapter + native map scripts), and `ports/` (the abstract host interfaces application calls into — `UiHost`, `PartyMovementHost`).
- `presentation/` — Flutter/Bonfire-bound code: `host/` (`HDFlutterUiHost`, the concrete adapter implementing every `application/ports/` interface), `input/` (`HDInputDispatcher`, `HDVirtualInputState`, `HDInputMode`), `panels/` (the 6 panels + `world_map_renderer.dart` + `player_sprite.dart`), and `window_manager.dart`.
- `lib/hd_game_main.dart` — thin facade that wires the layers together. Singleton, implements `UiHost` + `PartyMovementHost`, forwards both `HDGameSession` and `HDFlutterUiHost` change notifications. Existing `HDGameMain()` call sites and `ListenableBuilder(listenable: HDGameMain(), ...)` keep working unchanged.

When adding a class, pick the layer first. If a domain file ever imports `package:flutter/material.dart` or `package:bonfire/...`, that's a layering violation — push the rendering concern out into `presentation/` or the use-case into `application/`. Application code must not import `lib/presentation/...` either; talk to a port instead.

### Layout (fixed 800×480)
The UI is hand-laid out at fixed pixel coordinates by `lib/main.dart`, scaled with `FittedBox`. Constants live in `lib/hd_config.dart`. Three viewports + a mobile control strip:

- `HDMapViewport` (0,0 / 288×320) — Bonfire game world, camera locked to player.
- `HDConsolePanel` (288,0 / 512×320) — script dialogue + system logs.
- `HDStatusPanel` (0,320 / 800×160) — party HP/SP/ESP grid.
- `HDBottomControlPanel` — virtual D-pad + action buttons for mobile.
- `HDWindowLayer` — overlay stack (battle, magic, etc.) drawn on top of everything.

All five panel widgets live in `lib/presentation/panels/`. See `hadar2026_app/UI_SPEC.md` for the visual spec.

### Singleton-heavy core
Most subsystems are accessed as `Foo()` (factory returning a static instance): `HDGameMain`, `HDGameSession`, `HDFlutterUiHost`, `HDInputDispatcher`, `HDWindowManager`, `HDBattle`, `HDMenuFlows`, `HDTileEventDispatcher`, `HDMapNavigation`, `HDScriptEngine`, `HDNativeScriptRunner`, `HDSelect`, `HDSaveManager`. The codebase intentionally mirrors the original C++ globals — it's not a target for DI refactoring. What was cleaned up is *responsibility splitting*: `HDGameMain` shrank from ~1000 lines to ~185 by handing menu flow / map loading / tile dispatch / input routing / UI hosting / session state to dedicated singletons. New code should pick the right one rather than growing `HDGameMain` again.

`HDGameMain` extends `ChangeNotifier` and is still the source of truth for UI rebuilds (via `ListenableBuilder(listenable: HDGameMain(), …)`). It implements `UiHost` and forwards changes from both `HDFlutterUiHost` and `HDGameSession` (`addListener(notifyListeners)`), so a single listenable still drives the whole UI even though state lives in two layered singletons. `notifyListeners()` is wrapped in `Future.microtask` to avoid notifying during build.

The `UiHost` and `PartyMovementHost` interfaces (`application/ports/`) are the seam if you ever need a headless test driver, a CLI/MUD frontend, or an alternate Flutter layout — application code only ever calls `host.showMenu / addLog / waitForAnyKey / beginNarrative / endNarrative / preloadAssets / animatePartyMove`, never the concrete `HDFlutterUiHost` or `HDGameMain`. To swap frontends, write a new adapter implementing the ports; nothing in `domain/` or `application/` changes.

### Input modes
`HDGameMain.currentInputMode` resolves to one of `HDInputMode.{window, menu, dialogue, map}` in priority order. The global `HardwareKeyboard.instance` handler is registered by `HDInputDispatcher().registerGlobalHandler()`; every key flows through `HDInputDispatcher.process()` which dispatches by current mode (`HDGameMain.processKey()` is now a thin facade over it). Key bindings policy is documented in `docs/key_input_policy.md`:

- Move: arrows / WASD
- Confirm: Enter / E
- Menu/Cancel: Esc / Q / Space (Space opens main menu only on map mode)

Window-mode keys are dispatched by `HDWindowManager._dispatch`, which type-switches on the topmost window (`HDMessageWindow.close()`, `HDMagicSelectionWindow.moveCursor/confirm/cancel`). Domain window classes no longer carry their own `handleInput`.

### Scripting: three event tiers per tile

Tile events are dispatched through a 3-tier priority chain in `HDTileEventDispatcher.check` → `_dispatchScripted`:

1. **native map script** — Dart class extending `HDMapScript` under `lib/application/scripting/maps/`, registered in `HDNativeScriptRunner.mapScriptFactory` (`'TOWN1' → Town1MapScript`, etc.). Lifecycle hooks: `onLoad/onUnload/onTalk/onSign/onEvent/onEnter`. **All four event hooks return `Future<bool>` — `true` means "handled, don't fall through".**
2. **cm2 paired script** — `.cm2` file under `hadar2026_app/assets/`, referenced from `MapInfos.json#cm2`. Loaded into `HDScriptEngine` on map entry. Signals processing via the new `Event::MarkHandled()` builtin — without it, dispatch falls through to JSON.
3. **JSON `MapEvent.dialogLines`** — static fallback emitted by the dispatcher when neither native nor cm2 handled the tile. The legacy RPG Maker `code=401` text is parsed; the optional `events[].hadarEvent: { kind, payload }` extension is parsed but not yet dispatched (placeholder for future warp/oneshot kinds).

**Per-map binding**: `MapInfos.json` entries carry optional `cm2` and `json` fields. Missing `json` falls back to `Map${id:03d}.json`. Missing `cm2` is allowed only if the map has a registered native script (otherwise the map has no dynamic scripting at all). Native maps without a paired cm2 keep the legacy "JSON dialogLines emitted alongside native" behaviour. Maps with neither native nor paired cm2 fall back to the legacy global cm2 chain (`startup.cm2` → ...) and don't fall through to JSON — preserves pre-migration cm2 dispatch.

**Why two scripting runtimes still**: cm2 is a hot-reloadable, data-driven DSL good for porting original Hadar scripts and for content authors. Native Dart is for typed, IDE-supported logic where cm2's expressivity falls short. New maps generally pick one — the 3-tier chain is the seam that lets them coexist.

#### CM2 gotchas
- **init vs run phase**: `loadFromString()` runs an **initialization phase** that executes `variable`, `include`, and `name.assign`. `run()` then **skips** `variable`/`include` but **re-executes** every `.assign`. So a `score.assign(0)` at the top of the main script will wipe runtime state every loop iteration. Put one-shot initial assignments inside an `include`d file.
- **silent failure modes**: Unregistered commands print "Unknown command" and are skipped; unregistered functions print "Unknown function" and **return 0**, which can silently mis-branch — watch for typos.
- **`Event::MarkHandled` is required** for cm2-paired maps to fall through to JSON correctly. If a cm2 handler does its work but forgets to mark, JSON gets re-emitted as a duplicate dialogue. For legacy global-cm2 maps (no `cm2` field in `MapInfos.json`), the dispatcher skips the JSON tier entirely so missing-mark is harmless.
- **per-map cm2 load wipes engine globals**: `HDGameSession.loadMapFromFile` calls `HDScriptEngine().loadScript(cm2Path)` on map transitions, which clears `variables`/contexts. Globals are not preserved across maps in the new model — keep state in `HDNativeScriptRunner.flags`/`.variables` if it must survive.

### Map data
Maps live as `assets/maps/MapNNN.json` with a name index in `assets/maps/MapInfos.json`. `HDMapNavigation.loadByName(name)` (in `application/map_navigation.dart`) returns a `MapBundle { mapName, json?, cm2Path? }`: `name` → entry in `MapInfos.json` → resolves both the JSON map data and the optional cm2 path. Don't bypass the index. Tile actions (`HDTileProperties.ACTION_TALK/SIGN/ENTER/EVENT/SWAMP/LAVA/WATER`) drive interaction dispatch in `HDTileEventDispatcher.check`. The legacy `*.map` files are no longer used (deleted).

### Save/load
`HDSaveManager.saveGame(slot)` / `loadGame(slot)`. Save files are `save_data_*.json` (gitignored). A successful load throws `GameReloadException` to unwind the current run loop — the script engine catches and silently stops on this exception, so do not log it as an error.

## Tests

`hadar2026_app/test/` holds domain/unit tests against the layered code (no widget tests yet). Run from `hadar2026_app/` with `flutter test`. Currently-covered areas: `domain/party/party_actions_test.dart`, `domain/lighting/sight_calculator_test.dart`, `domain/console/text_utils_test.dart`, `domain/console/console_log_test.dart`, `domain/map/map_event_test.dart`, `presentation/host/flutter_ui_host_test.dart`. cm2 engine has its own tests in `packages/cm2_script/test/` (run with `dart test`). New domain rules should land with a test in the matching subfolder.

## Deployment
Web is published to GitHub Pages by `.github/workflows/deploy_web.yml` (manual `workflow_dispatch`). It runs `flutter build web --base-href "/Hadar2026/" --release` in `hadar2026_app/` and pushes `build/web` via `peaceiris/actions-gh-pages@v3`. There is no CI for tests or analyze yet — run `flutter test` and `flutter analyze` locally before pushing.
