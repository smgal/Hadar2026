import '../hd_config.dart';

import 'package:flutter/foundation.dart';

class HDGameOption extends ChangeNotifier {
  HDGameOption();

  // Max flags / variables based on original specs
  List<bool> flags = List.filled(HDConfig.maxFlags, false);
  List<int> variables = List.filled(HDConfig.maxVariables, 0);

  // Name of the currently executing script or map file
  int mapType = 0; // 0: TOWN, 1: KEEP, 2: GROUND, 3: DEN
  String scriptFile = "";

  void refresh() {
    notifyListeners();
  }

  void reset() {
    flags = List.filled(HDConfig.maxFlags, false);
    variables = List.filled(HDConfig.maxVariables, 0);
    mapType = 0;
    scriptFile = "";
  }

  Map<String, dynamic> toJson() {
    return {
      'flags': flags,
      'variables': variables,
      'mapType': mapType,
      'scriptFile': scriptFile,
    };
  }

  factory HDGameOption.fromJson(Map<String, dynamic> json) {
    HDGameOption option = HDGameOption();
    if (json['flags'] != null) {
      option.flags = List<bool>.from(json['flags']);
      // pad just in case
      while (option.flags.length < HDConfig.maxFlags) {
        option.flags.add(false);
      }
    }
    if (json['variables'] != null) {
      option.variables = List<int>.from(json['variables']);
      while (option.variables.length < HDConfig.maxVariables) {
        option.variables.add(0);
      }
    }
    option.mapType = json['mapType'] ?? 0;
    option.scriptFile = json['scriptFile'] ?? "";
    return option;
  }
}
