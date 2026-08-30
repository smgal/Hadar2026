import 'asset_source.dart';
import 'movement_host.dart';
import 'ui_host.dart';

/// Composition root for the application layer's host references.
///
/// `application/` code must never name a concrete presentation class. It
/// asks this binding for the ports it needs, and the shell (`HDGameMain`,
/// or a headless test driver) supplies the implementations once at boot
/// via [bind].
///
/// Kept as a singleton to match the rest of the codebase's `Foo()` shape.
/// A test that only exercises use-cases can call
/// `HDHosts().bind(ui: FakeUiHost(), movement: FakeMovementHost(),
/// assets: MapAssetSource({...}))` and `HDHosts().reset()` in `tearDown`.
class HDHosts {
  static final HDHosts _instance = HDHosts._internal();
  factory HDHosts() => _instance;
  HDHosts._internal();

  UiHost? _ui;
  PartyMovementHost? _movement;
  AssetSource? _assets;

  /// True once [bind] has supplied every port.
  bool get isBound => _ui != null && _movement != null && _assets != null;

  UiHost get ui {
    final value = _ui;
    if (value == null) {
      throw StateError(
        'HDHosts.ui read before bind(). The shell must call '
        'HDHosts().bind(...) during boot (see HDGameMain), and tests must '
        'bind a fake UiHost before exercising application code.',
      );
    }
    return value;
  }

  PartyMovementHost get movement {
    final value = _movement;
    if (value == null) {
      throw StateError(
        'HDHosts.movement read before bind(). See HDHosts.ui for details.',
      );
    }
    return value;
  }

  AssetSource get assets {
    final value = _assets;
    if (value == null) {
      throw StateError(
        'HDHosts.assets read before bind(). See HDHosts.ui for details.',
      );
    }
    return value;
  }

  void bind({
    required UiHost ui,
    required PartyMovementHost movement,
    required AssetSource assets,
  }) {
    _ui = ui;
    _movement = movement;
    _assets = assets;
  }

  /// Drops every binding. Intended for test `tearDown`.
  void reset() {
    _ui = null;
    _movement = null;
    _assets = null;
  }
}
