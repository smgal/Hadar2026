# hadar2026_app

Flutter/Dart remake of the classic Korean RPG **또 다른 지식의 성전 (Hadar)** — the player-facing app. Built on Bonfire/Flame for the tile world and `window_manager` for the desktop shell.

## Run

```bash
flutter pub get
flutter run            # device / desktop
```

Web build (matches the GitHub Actions deploy):

```bash
flutter build web --base-href "/Hadar2026/" --release
```

Tests (domain/unit):

```bash
flutter test                                 # all
flutter test test/domain/party/              # one folder
flutter test test/domain/console/text_utils_test.dart   # one file
```

`flame` is pinned to `1.35.1` and `bonfire` to exactly `3.16.1` in `pubspec.yaml` — bonfire 3.17.x is incompatible with flame 1.35.1 (`RenderGameWidget(behavior:)` mismatch). Don't bump them casually.

## Project layout

`lib/` is split by responsibility, not by file kind:

```
lib/
├─ main.dart, hd_config.dart
├─ hd_game_main.dart   thin facade tying the layers together (UiHost impl)
├─ domain/         data + game rules (no Flutter material/Bonfire)
├─ application/    use-cases (game_session, menu_flows, battle,
│                  map_navigation, tile_event_dispatcher, scripting, save)
├─ presentation/   Flutter/Bonfire-bound — host, input, panels, window manager
└─ utils/
```

When adding a class, pick the layer first. Importing `package:flutter/material.dart` from `domain/` is a layering violation — push the rendering concern out into `presentation/` instead.

See:
- [`UI_SPEC.md`](UI_SPEC.md) — fixed 800×480 panel layout
- [`task.md`](task.md) — ongoing MVC reorganization plan + checklist
- [`../CLAUDE.md`](../CLAUDE.md) — full architecture guide
