import 'package:cm2_script/cm2_script.dart';
import 'package:hadar2026_app/application/ports/asset_source.dart';
import 'package:hadar2026_app/application/ports/host_binding.dart';
import 'package:hadar2026_app/application/ports/movement_host.dart';
import 'package:hadar2026_app/application/ports/ui_host.dart';
import 'package:hadar2026_app/application/scripting/script_engine_adapter.dart';

/// 「cm2 가 아는 동사」의 정의 한 곳. 감사 시험과 동사 표 시험이 같은 것을 본다.

/// 아무 일도 하지 않는 호스트. 어댑터를 만들 때 포트가 묶여 있어야 해서 쓴다.
class SilentHosts implements UiHost, PartyMovementHost, AssetSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void bindSilentHosts() {
  final silent = SilentHosts();
  HDHosts().bind(ui: silent, movement: silent, assets: silent);
}

/// 앱이 등록한 명령 + 엔진 내장 명령.
Set<String> knownCm2Commands() => {
      ...HDScriptEngine().registeredCommands,
      ...ScriptEngine.builtinCommands,
    };

/// 앱이 등록한 함수 + 엔진 내장 함수.
Set<String> knownCm2Functions() => {
      ...HDScriptEngine().registeredFunctions,
      ...ScriptEngine.builtinFunctions,
    };
