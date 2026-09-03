import 'package:flutter_test/flutter_test.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';

/// Serves scripts from a plain map, and throws for anything else — the
/// same seam map_navigation_test.dart uses.
class _FakeAssets implements AssetSource {
  _FakeAssets(this.files);
  final Map<String, String> files;

  @override
  Future<String> loadString(String path) async {
    final content = files[path];
    if (content == null) throw Exception('asset not found: $path');
    return content;
  }
}

class _Unused implements UiHost, PartyMovementHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  void bind(Map<String, String> files) => HDHosts()
      .bind(ui: _Unused(), movement: _Unused(), assets: _FakeAssets(files));

  tearDown(HDHosts().reset);

  group('HDScriptEngine.loadScript', () {
    test('a successful load fills currentScript and reports true', () async {
      bind({'assets/ok.cm2': 'Log("hello")\nLog("world")\n'});
      final loaded = await HDScriptEngine().loadScript('assets/ok.cm2');
      expect(loaded, isTrue);
      expect(HDScriptEngine().currentScript, isNotEmpty);
    });

    // The bug: loadScript returned before clearRuntimeState(), so the
    // previous map's script stayed resident. Since the dispatcher picks
    // the cm2 tier whenever currentMapCm2Path is non-null, that stale
    // script is what ran on the new map's tiles (GROUND_TRUTH A-2).
    test('a failed load leaves nothing of the previous script', () async {
      bind({'assets/ok.cm2': 'Log("hello")\n'});
      await HDScriptEngine().loadScript('assets/ok.cm2');
      expect(HDScriptEngine().currentScript, isNotEmpty);

      final loaded = await HDScriptEngine().loadScript('assets/missing.cm2');
      expect(loaded, isFalse);
      expect(HDScriptEngine().currentScript, isEmpty,
          reason: 'the previous map script must not survive');
    });

    test('reports false without throwing', () async {
      bind({});
      expect(await HDScriptEngine().loadScript('assets/nope.cm2'), isFalse);
    });
  });
}
