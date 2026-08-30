# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter/Dart remake of the classic Korean RPG "또 다른 지식의 성전 (Hadar)". The repo is a multi-package layout, not a single Flutter app.

- `hadar2026_app/` — the Flutter app (Bonfire/Flame engine, `window_manager` for desktop). Entry point `lib/main.dart`.
- `packages/cm2_script/` — standalone Dart package: parser + interpreter for the CM2 scripting language. Pulled in via local path dep.
- `cm2_script_sample/` — CUI demo exercising every cm2_script feature.
- `tools/` — Python scripts for converting/extracting legacy Hadar binary data (maps, enemies, sprites), plus `tools/mapEditor/` — a TypeScript/Vite web map editor (pnpm) that reads/writes `hadar2026_app/assets/maps/*.json` in place while preserving the full RPG Maker MV format (see `tools/mapEditor/README.md`).
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

# Map editor (web UI for assets/maps/*.json)
cd tools/mapEditor
pnpm install
pnpm dev        # http://localhost:5310 — edits hadar2026_app/assets in place
# AI-facing semantic REST API on the same server: GET /api/ai returns the full
# machine-readable guide (batch edits, events CRUD, passability, validate,
# preview.png). MCP wrapper: node tools/mapEditor/mcp/server.mjs (dev server must be running).
```

`flame` is pinned to `1.35.1` via `dependency_overrides` and `bonfire` is pinned to exactly `3.16.1` in `hadar2026_app/pubspec.yaml` — don't bump them casually. bonfire 3.17.x assumes flame 1.36+ (`RenderGameWidget(behavior:)`) and will not compile against flame 1.35.1.

## Architecture

### `lib/` is layered: domain / application / presentation

`hadar2026_app/lib/` was reorganized from a flat `models/ + views/ + game_components/ + scripting/` into:

- `domain/` — pure data + game rules. Allowed Flutter import: `foundation.dart` only (for `ChangeNotifier`). Subfolders: `party/`, `map/`, `battle/`, `magic/`, `lighting/`, `console/`, `window/`, plus `game_option.dart`.
- `application/` — use-cases that compose domain with a UI host. No `flutter/material`, no `bonfire`, no `flame`, and no import of `presentation/` or `hd_game_main.dart`. Contains `game_session.dart`, `menu_flows.dart`, `battle.dart`, `magic_system.dart`, `map_navigation.dart`, `tile_event_dispatcher.dart`, `save_manager.dart`, `select.dart`, `map_loader.dart`, `window_manager.dart` (the overlay window *stack*), `game_reload_exception.dart`, `scripting/` (CM2 adapter + native map scripts + `HDMapScriptContext`), and `ports/` (the abstract host interfaces application calls into — `UiHost`, `PartyMovementHost`, `AssetSource`, and `HDHosts`, the binding the shell fills in at boot).
- `presentation/` — Flutter/Bonfire-bound code: `host/` (`HDFlutterUiHost` + `HDBundleAssetSource`, the concrete adapters implementing every `application/ports/` interface), `input/` (`HDInputDispatcher`, `HDWindowKeyDispatcher`, `HDVirtualInputState`, `HDInputMode`), and `panels/` (the 6 panels + `world_map_renderer.dart` + `player_sprite.dart`).
- `lib/hd_game_main.dart` — thin facade that wires the layers together. Singleton, implements `UiHost` + `PartyMovementHost`, forwards both `HDGameSession` and `HDFlutterUiHost` change notifications. Existing `HDGameMain()` call sites and `ListenableBuilder(listenable: HDGameMain(), ...)` keep working unchanged.

When adding a class, pick the layer first. If a domain file ever imports `package:flutter/material.dart` or `package:bonfire/...`, that's a layering violation — push the rendering concern out into `presentation/` or the use-case into `application/`. Application code must not import `lib/presentation/...` **or `lib/hd_game_main.dart`** either — the facade pulls `flutter/material` plus the whole presentation layer in with it. Reach for a port instead: `HDHosts().ui` / `HDHosts().movement` for effects, `HDGameSession()` for session state.

Two greps keep this honest (both must come back empty):

```bash
cd hadar2026_app
grep -rn "^import.*presentation\|^import.*hd_game_main" lib/application/ lib/domain/
grep -rn "package:flutter/material\|package:bonfire\|package:flame" lib/application/ lib/domain/
```

Both greps run in CI (`.github/workflows/ci.yml`, "Check layering invariants"), so a violation fails the build rather than waiting to be noticed. The only Flutter import allowed under `application/`/`domain/` is `package:flutter/foundation.dart` (`ChangeNotifier`, `kIsWeb`, `kDebugMode`) — no `services`, no `dart:io`.

### Layout (fixed 800×480)
The UI is hand-laid out at fixed pixel coordinates by `lib/main.dart`, scaled with `FittedBox`. Constants live in `lib/hd_config.dart`. Three viewports + a mobile control strip:

- `HDMapViewport` (0,0 / 288×320) — Bonfire game world, camera locked to player.
- `HDConsolePanel` (288,0 / 512×320) — script dialogue + system logs.
- `HDStatusPanel` (0,320 / 800×160) — party HP/SP/ESP grid.
- `HDBottomControlPanel` — virtual D-pad + action buttons for mobile.
- `HDWindowLayer` — overlay stack (battle, magic, etc.) drawn on top of everything.

All five panel widgets live in `lib/presentation/panels/`. See `hadar2026_app/UI_SPEC.md` for the visual spec.

### Singleton-heavy core
Most subsystems are accessed as `Foo()` (factory returning a static instance): `HDGameMain`, `HDGameSession`, `HDFlutterUiHost`, `HDInputDispatcher`, `HDWindowKeyDispatcher`, `HDWindowManager`, `HDBattle`, `HDMenuFlows`, `HDTileEventDispatcher`, `HDMapNavigation`, `HDScriptEngine`, `HDNativeScriptRunner`, `HDSelect`, `HDSaveManager`, `HDHosts`. The codebase intentionally mirrors the original C++ globals — it's not a target for DI refactoring. What was cleaned up is *responsibility splitting*: `HDGameMain` shrank from ~1000 lines to ~185 by handing menu flow / map loading / tile dispatch / input routing / UI hosting / session state to dedicated singletons. New code should pick the right one rather than growing `HDGameMain` again.

`HDGameMain` extends `ChangeNotifier` and is still the source of truth for UI rebuilds (via `ListenableBuilder(listenable: HDGameMain(), …)`). It implements `UiHost` and forwards changes from both `HDFlutterUiHost` and `HDGameSession` (`addListener(notifyListeners)`), so a single listenable still drives the whole UI even though state lives in two layered singletons. `notifyListeners()` is wrapped in `Future.microtask` to avoid notifying during build.

The `UiHost` and `PartyMovementHost` interfaces (`application/ports/`) are the seam if you ever need a headless test driver, a CLI/MUD frontend, or an alternate Flutter layout — application code only ever calls `host.showMenu / showWindowMenu / showMessageWindow / addLog / waitForAnyKey / setHeader / clearLogs / beginNarrative / endNarrative / refresh / preloadAssets / animatePartyMove`, never the concrete `HDFlutterUiHost` or `HDGameMain`. To swap frontends, write a new adapter implementing the ports; nothing in `domain/` or `application/` changes.

`AssetSource` is the third port: every text asset read (map JSON, `MapInfos.json`, cm2 scripts) goes through `HDHosts().assets.loadString(path)`. `HDBundleAssetSource` implements it as "on-disk file wins on desktop, else `rootBundle`" — that override is what lets desktop runs pick up `tools/mapEditor` writes without a rebuild. Application code must never reach for `rootBundle` itself.

`HDHosts` (`application/ports/host_binding.dart`) is the composition root that carries those ports to the use-cases. `HDGameMain._internal()` calls `HDHosts().bind(ui: _host, movement: _host, assets: HDBundleAssetSource())` at boot; a test binds fakes and calls `HDHosts().reset()` in `tearDown`. Reading a port before `bind` throws a `StateError` naming the fix rather than failing later with a null.

`UiHost.refresh()` is a *pure repaint request* and is deliberately distinct from a session-changed notification: a map transition additionally clears the per-map progress scrollback (`HDGameMain._onSessionChanged`), whereas `refresh()` never does. Application code that mutates map state in place (tile overrides, map-type swaps, a restored save) must call `HDHosts().ui.refresh()`, not `HDGameSession().notifyListeners()`.

### Input modes
`HDGameMain.currentInputMode` resolves to one of `HDInputMode.{window, menu, dialogue, map}` in priority order. The global `HardwareKeyboard.instance` handler is registered by `HDInputDispatcher().registerGlobalHandler()`; every key flows through `HDInputDispatcher.process()` which dispatches by current mode (`HDGameMain.processKey()` is now a thin facade over it). Key bindings policy is documented in `docs/key_input_policy.md`:

- Move: arrows / WASD
- Confirm: Enter / E
- Menu/Cancel: Esc / Q / Space (Space opens main menu only on map mode)

Window-mode keys are dispatched by `HDWindowKeyDispatcher` (`presentation/input/`), which type-switches on the topmost visible window (`HDMessageWindow.close()`, `HDMagicSelectionWindow.moveCursor/confirm/cancel`). Domain window classes no longer carry their own `handleInput`, and the stack itself (`HDWindowManager`, in `application/`) holds no key handling — that split is what lets application code open a window without importing `presentation/`.

### Scripting: three event tiers per tile

Tile events are dispatched through a 3-tier priority chain in `HDTileEventDispatcher.check` → `_dispatchScripted`:

1. **native map script** — Dart class extending `HDMapScript` under `lib/application/scripting/maps/`, registered in `HDNativeScriptRunner.mapScriptFactory` (`'TOWN1' → Town1MapScript`, etc.). Lifecycle hooks: `onLoad/onUnload/onTalk/onSign/onEvent/onEnter`. **All four event hooks return `Future<bool>` — `true` means "handled, don't fall through".**
2. **cm2 paired script** — `.cm2` file under `hadar2026_app/assets/`, referenced from `MapInfos.json#cm2`. Loaded into `HDScriptEngine` on map entry. Signals processing via the `Event::Override()` builtin — without it, dispatch falls through to JSON. Convention: place `Event::Override()` at the top of the matched-tile handler block so it reads as a declarative "this block overrides JSON" annotation.
3. **JSON `MapEvent.dialogLines`** — static fallback emitted by the dispatcher when neither native nor cm2 handled the tile. The legacy RPG Maker `code=401` text is parsed; the optional `events[].hadarEvent: { kind, payload }` extension is parsed but not yet dispatched (placeholder for future warp/oneshot kinds).

**Per-map binding**: `MapInfos.json` entries carry optional `cm2` and `json` fields. Missing `json` falls back to `Map${id:03d}.json`. Missing `cm2` is allowed only if the map has a registered native script (otherwise the map has no dynamic scripting at all). Native maps without a paired cm2 keep the legacy "JSON dialogLines emitted alongside native" behaviour. Maps with neither native nor paired cm2 fall back to the legacy global cm2 chain (`startup.cm2` → ...) and don't fall through to JSON — preserves pre-migration cm2 dispatch.

**Why two scripting runtimes still**: cm2 is a hot-reloadable, data-driven DSL good for porting original Hadar scripts and for content authors. Native Dart is for typed, IDE-supported logic where cm2's expressivity falls short. New maps generally pick one — the 3-tier chain is the seam that lets them coexist.

#### CM2 gotchas
- **init vs run phase**: `loadFromString()` runs an **initialization phase** that executes `variable`, `include`, and `name.assign`. `run()` then **skips** `variable`/`include` but **re-executes** every `.assign`. So a `score.assign(0)` at the top of the main script will wipe runtime state every loop iteration. Put one-shot initial assignments inside an `include`d file.
- **silent failure modes**: Unregistered commands print "Unknown command" and are skipped; unregistered functions print "Unknown function" and **return 0**, which can silently mis-branch — watch for typos.
- **`Event::Override` is required** for cm2-paired maps to override JSON dialogue cleanly. If a cm2 handler does its work but forgets to call it, JSON gets re-emitted as a duplicate dialogue. For legacy global-cm2 maps (no `cm2` field in `MapInfos.json`), the dispatcher skips the JSON tier entirely so a missing call is harmless.
- **per-map cm2 load wipes engine globals**: `HDGameSession.loadMapFromFile` calls `HDScriptEngine().loadScript(cm2Path)` on map transitions, which clears `variables`/contexts. Globals are not preserved across maps in the new model — keep state in `HDNativeScriptRunner.flags`/`.variables` if it must survive.

### Map data
Maps live as `assets/maps/MapNNN.json` with a name index in `assets/maps/MapInfos.json`. `HDMapNavigation.loadByName(name)` (in `application/map_navigation.dart`) returns a `MapBundle { mapName, json?, cm2Path? }`: `name` → entry in `MapInfos.json` → resolves both the JSON map data and the optional cm2 path. Don't bypass the index.

Tile actions are the `HDTileAction` enum (`domain/map/tile_properties.dart`), which drives interaction dispatch in `HDTileEventDispatcher.check`. Ask the enum rather than restating a list of members — `isInteractive` (talk/sign/enter: faced-and-confirmed, and the set that blocks movement), `isStepOn` (event/enter), `debugTag`. Every `switch` over it is exhaustive, so adding an action surfaces each site that must handle it as a compile error.

**`HDTileAction.scriptMode` is a wire value, not an index.** 0–4 are handed to `HDScriptEngine.setScriptMode` and read back by cm2 scripts as `ScriptMode()`, compared against `FLAG_MAP`/`FLAG_TALK`/`FLAG_SIGN`/`FLAG_EVENT`/`FLAG_ENTER` in `assets/const.cm2`. They are declared explicitly on the enum and pinned by `test/domain/map/tile_action_test.dart` — never switch to `Enum.index`. The legacy `*.map` files are no longer used (deleted).

### Save/load
`HDSaveManager.saveGame(slot)` / `loadGame(slot)`. Save files are `save_data_*.json` (gitignored). A successful load throws `GameReloadException` to unwind the current run loop — the script engine catches and silently stops on this exception, so do not log it as an error.

## Tests

`hadar2026_app/test/` holds domain/unit tests against the layered code (no widget tests yet). Run from `hadar2026_app/` with `flutter test`. Currently-covered areas: `domain/party/party_actions_test.dart`, `domain/lighting/sight_calculator_test.dart`, `domain/console/text_utils_test.dart`, `domain/console/console_log_test.dart`, `domain/map/map_event_test.dart`, `domain/map/tile_action_test.dart`, `presentation/host/flutter_ui_host_test.dart`.

`test/application/map_navigation_test.dart` is the worked example of the headless seam: it binds a fake `AssetSource` serving maps from an in-memory `Map<String, String>` and drives the whole name → `MapInfos.json` → `MapModel` path with no asset bundle and no filesystem. Copy that shape to test `HDMenuFlows` / `HDBattle` / `HDTileEventDispatcher` — bind fakes via `HDHosts().bind(...)`, `HDHosts().reset()` in `tearDown`. cm2 engine has its own tests in `packages/cm2_script/test/` (run with `dart test`). New domain rules should land with a test in the matching subfolder.

## Deployment
Web is published to GitHub Pages by `.github/workflows/deploy_web.yml` (manual `workflow_dispatch`). It runs `flutter build web --base-href "/Hadar2026/" --release` in `hadar2026_app/` and pushes `build/web` via `peaceiris/actions-gh-pages@v3`. ## CI

`.github/workflows/ci.yml` runs on every push to `main`, every PR, and manual dispatch. Two jobs:

- **hadar2026_app** — `flutter analyze --no-fatal-infos`, `flutter test`, then the two layering greps above.
- **packages/cm2_script** — `dart analyze` (fatal on warnings), `dart test`.

`--no-fatal-infos` is deliberate: 77 pre-existing style infos (`constant_identifier_names`, `avoid_print`, `withOpacity` deprecations) would make the build red from day one. Errors and warnings *are* fatal, so new regressions still fail. Drop the flag once those infos are cleaned up.

There is no `dart format` gate yet — the repo is not format-clean (~20 files would change). Run a one-shot `dart format lib test` in both packages, then add `dart format --output=none --set-exit-if-changed lib test` to both jobs.
