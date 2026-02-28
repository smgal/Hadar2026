import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/services.dart';
import '../game_components/hd_battle.dart';
import '../game_components/hd_select.dart';
import '../game_components/hd_game_main.dart';
import '../game_components/hd_player.dart';
import '../models/map_model.dart';
import '../hd_config.dart';

// Represents a single line or block in the script
abstract class ScriptStatement {}

class CommandStatement extends ScriptStatement {
  String command;
  List<String> args;
  CommandStatement(this.command, this.args);

  @override
  String toString() => "$command(${args.join(', ')})";
}

class IfStatement extends ScriptStatement {
  String conditionFunc;
  List<String> conditionArgs;
  List<ScriptStatement> body;
  List<ScriptStatement> elseBody; // Added elseBody

  IfStatement(
    this.conditionFunc,
    this.conditionArgs,
    this.body, [
    this.elseBody = const [],
  ]);

  @override
  String toString() =>
      "if ($conditionFunc(${conditionArgs.join(', ')})) {\n${body.join('\n')}\n} else {\n${elseBody.join('\n')}\n}";
}

class HDScriptEngine {
  static final HDScriptEngine _instance = HDScriptEngine._internal();
  factory HDScriptEngine() => _instance;
  HDScriptEngine._internal();

  Map<String, dynamic> variables = {};
  List<ScriptStatement> currentScript = [];

  // Basic parsing logic
  Future<void> loadScript(String assetPath) async {
    String content;
    // On Web, File(path).exists() throws an exception. We should use rootBundle for assets.
    try {
      if (!kIsWeb && await File(assetPath).exists()) {
        content = await File(assetPath).readAsString();
      } else {
        // For assets, rootBundle is the correct way on all platforms
        content = await rootBundle.loadString(assetPath);
      }
    } catch (e) {
      print("ScriptEngine: Failed to load $assetPath: $e");
      return;
    }

    variables.clear();
    _tileMap.clear();

    currentScript = _parse(content);
    HDGameMain().gameOption.scriptFile = assetPath;
    print(
      "ScriptEngine: Loaded ${currentScript.length} root statements from $assetPath",
    );

    // One-time initialization of root commands (variable, include, top-level assigns)
    await _executeRootInitialization();
  }

  void loadFromString(String content) {
    currentScript = _parse(content);
    _executeRootInitialization();
  }

  Future<void> _executeRootInitialization() async {
    for (var stmt in currentScript) {
      if (stmt is CommandStatement) {
        if (stmt.command == 'variable' ||
            stmt.command == 'include' ||
            stmt.command.endsWith('.assign')) {
          await _executeCommand(stmt);
        }
      }
    }
  }

  bool _halted = false;

  Future<void> run() async {
    _halted = false;
    final statements = List<ScriptStatement>.from(currentScript);
    try {
      for (var stmt in statements) {
        if (stmt is CommandStatement) {
          if (stmt.command == 'variable' || stmt.command == 'include') continue;
        }
        await executeStatement(stmt);
        if (_halted) break;
      }
    } on GameReloadException {
      // Silently stop
    } catch (e, stack) {
      print("ScriptEngine Error: $e\n$stack");
    }
  }

  // Execution Logic
  Future<void> executeStatement(ScriptStatement stmt) async {
    if (stmt is CommandStatement) {
      await _executeCommand(stmt);
    } else if (stmt is IfStatement) {
      if (await _evaluateCondition(stmt)) {
        for (var step in stmt.body) {
          await executeStatement(step);
          if (_halted) break;
        }
      } else if (stmt.elseBody.isNotEmpty) {
        for (var step in stmt.elseBody) {
          await executeStatement(step);
          if (_halted) break;
        }
      }
    }
  }

  // Helpers for flags and variables
  List<bool> get _flags => HDGameMain().gameOption.flags;
  List<int> get _variables => HDGameMain().gameOption.variables;

  Future<void> _executeCommand(CommandStatement stmt) async {
    final cmd = stmt.command;
    final args = stmt.args;

    if (cmd.endsWith('.assign')) {
      String varName = cmd.split('.')[0];
      if (!variables.containsKey(varName)) {
        print("Warning: Assigning to unregistered variable: $varName");
      }
      variables[varName] = _getVal(args[0]);
      return;
    }
    if (cmd.endsWith('.add')) {
      String varName = cmd.split('.')[0];
      if (!variables.containsKey(varName)) {
        print("Warning: Adding to unregistered variable: $varName");
      }
      var current = variables[varName] ?? 0;
      var inc = _getVal(args[0]);
      variables[varName] =
          (current is num ? current : 0) + (inc is num ? inc : 0);
      return;
    }

    switch (cmd) {
      case 'variable':
        variables[args[0]] = 0;
        break;
      case 'include':
        String path = _getVal(args[0]).toString();
        if (path.startsWith('"') && path.endsWith('"')) {
          path = path.substring(1, path.length - 1);
        }
        print("ScriptEngine: Including $path");
        await _executeInclude(path);
        break;
      case 'halt':
        _halted = true;
        break;
      case 'Talk':
        String text = _getVal(args[0]).toString();
        if (text.startsWith('"') && text.endsWith('"')) {
          text = text.substring(1, text.length - 1);
        }
        print("TALK: $text");
        await HDGameMain().addLog(text);
        break;
      case 'PressAnyKey':
        print("PressAnyKey...");
        await HDGameMain().waitForAnyKey();
        HDGameMain().clearLogs();
        break;
      case 'Map::Init':
        int w = int.parse(args[0]);
        int h = int.parse(args[1]);
        final newMap = MapModel();
        newMap.init(w, h);
        HDGameMain().setNewMap(newMap);
        _currentRow = 0;
        print("Map Init: ${w}x$h");
        break;
      case 'Map::SetTile':
        String char = args[0];
        if (char.startsWith('"') && char.endsWith('"')) {
          char = char.substring(1, char.length - 1);
        }
        int id = int.parse(args[1]);
        _tileMap[char] = id;
        break;
      case 'Map::SetRow':
        String rowStr = args[0];
        if (rowStr.startsWith('"') && rowStr.endsWith('"')) {
          rowStr = rowStr.substring(1, rowStr.length - 1);
        }
        final map = HDGameMain().map!;
        for (int x = 0; x < rowStr.length && x < map.width; x++) {
          String char = rowStr[x];
          int tileId = _tileMap[char] ?? 0;
          map.setTile(x, _currentRow, tileId);
        }
        _currentRow++;
        break;
      case 'Select::Init':
        HDSelect().init();
        break;
      case 'Select::Add':
        String text = _getVal(args[0]).toString();
        if (text.startsWith('"') && text.endsWith('"')) {
          text = text.substring(1, text.length - 1);
        }
        HDSelect().add(text);
        break;
      case 'Select::Run':
        await HDSelect().run();
        break;
      case 'LoadScript':
        String path = _getVal(args[0]).toString();
        if (path.startsWith('"') && path.endsWith('"')) {
          path = path.substring(1, path.length - 1);
        }
        print("Loading Script: $path");
        await loadScript('assets/$path');
        setScriptMode(0);
        // Load new script and run it
        await run();

        if (args.length >= 3) {
          int nx = (_getVal(args[1]) as num).toInt();
          int ny = (_getVal(args[2]) as num).toInt();
          HDGameMain().party.setPosition(nx, ny);
        }
        _halted = true;
        break;
      case 'Map::LoadFromFile':
        String path = _getVal(args[0]).toString();
        if (path.startsWith('"') && path.endsWith('"')) {
          path = path.substring(1, path.length - 1);
        }
        print("ScriptEngine: Loading map file $path");
        await HDGameMain().loadMapFromFile('assets/$path');
        break;
      case 'Battle::Init':
        HDBattle().init();
        break;
      case 'Battle::RegisterEnemy':
        int enemyId = (_getVal(args[0]) as num).toInt();
        HDBattle().registerEnemy(enemyId);
        break;
      case 'Battle::ShowEnemy':
        HDBattle().showEnemy();
        break;
      case 'Battle::Start':
        int mode = (_getVal(args[0]) as num).toInt();
        await HDBattle().start(mode);
        break;
      case 'Map::SetStartPos':
        int x = (_getVal(args[0]) as num).toInt();
        int y = (_getVal(args[1]) as num).toInt();
        HDGameMain().party.setPosition(x, y);
        break;
      case 'Map::ChangeTile':
        int cx = (_getVal(args[0]) as num).toInt();
        int cy = (_getVal(args[1]) as num).toInt();
        int tileId = (_getVal(args[2]) as num).toInt();
        HDGameMain().map?.setTile(cx, cy, tileId);
        break;
      case 'WarpPrevPos':
        HDGameMain().party.warpToPrev();
        break;
      case 'Flag::Set':
        String varName = args[0];
        int flagId = _getVal(varName);
        if (flagId >= 0 && flagId < HDConfig.maxFlags) {
          _flags[flagId] = true;
        }
        break;
      case 'Flag::Reset':
        int flagIdReset = _getVal(args[0]);
        if (flagIdReset >= 0 && flagIdReset < HDConfig.maxFlags) {
          _flags[flagIdReset] = false;
        }
        break;
      case 'Variable::Set':
        int idx = (_getVal(args[0]) as num).toInt();
        var val = _getVal(args[1]);
        if (idx >= 0 && idx < HDConfig.maxVariables) {
          _variables[idx] = (val as num).toInt();
        }
        break;
      case 'Variable::Add':
        int idxAdd = (_getVal(args[0]) as num).toInt();
        int inc = 1;
        if (args.length > 1) {
          inc = (_getVal(args[1]) as num).toInt();
        }
        if (idxAdd >= 0 && idxAdd < HDConfig.maxVariables) {
          _variables[idxAdd] += inc;
        }
        break;
      case 'PushString':
        String pushed = _getVal(args[0]).toString();
        if (pushed.startsWith('"') && pushed.endsWith('"')) {
          pushed = pushed.substring(1, pushed.length - 1);
        }
        _stringStack.add(pushed);
        break;
      case 'Player::ChangeAttribute':
        int pIdx = (_getVal(args[0]) as num).toInt() - 1;
        String attr = args[1].replaceAll('"', '');
        var valAttr = _getVal(args[2]);
        if (pIdx >= 0 && pIdx < HDGameMain().party.players.length) {
          HDGameMain().party.players[pIdx].changeAttribute(attr, valAttr);
        }
        break;
      case 'Enemy::ChangeAttribute':
        int eIdx = (_getVal(args[0]) as num).toInt() - 1;
        String attrEn = args[1].replaceAll('"', '');
        var valEn = _getVal(args[2]);
        if (eIdx >= 0 && eIdx < HDBattle().enemies.length) {
          HDBattle().enemies[eIdx].changeAttribute(attrEn, valEn);
        }
        break;
      case 'Player::AssignFromEnemyData':
        int pIdxEn = (_getVal(args[0]) as num).toInt() - 1;
        int enemyIdToAs = (_getVal(args[1]) as num).toInt();
        if (pIdxEn >= 0 && pIdxEn < HDGameMain().party.players.length) {
          HDGameMain().party.players[pIdxEn].assignFromEnemyData(enemyIdToAs);
        }
        break;
      case 'Party::PosX':
      case 'Party::PosY':
        break;
      case 'Party::PlusGold':
        int amount = (_getVal(args[0]) as num).toInt();
        HDGameMain().party.gold += amount;
        break;
      case 'Party::Move':
        int dx = (_getVal(args[0]) as num).toInt();
        int dy = (_getVal(args[1]) as num).toInt();

        // Find HDPlayer in the Bonfire map and force physical movement
        final game = HDGameMain().mapViewGameRef;
        if (game != null && game.player != null) {
          final playerComponent = game.player as HDPlayer;
          await playerComponent.forceMove(dx, dy);
        } else {
          // Fallback if headless/testing
          HDGameMain().party.move(dx, dy);
        }
        break;
      case 'Map::SetType':
        int type = (_getVal(args[0]) as num).toInt();
        HDGameMain().gameOption.mapType = type;
        // The original game clears tile overrides when the map type is set.
        HDGameMain().map?.tileOverrides.clear();
        HDGameMain().notifyListeners(); // Refresh visuals
        break;
      case 'Map::SetEncounter':
        int encounterId = (_getVal(args[0]) as num).toInt();
        int encounterRate = (_getVal(args[1]) as num).toInt();
        print(
          "Stub: Map::SetEncounter(encounterId: $encounterId, rate: $encounterRate)",
        );
        break;
      case 'DisplayMap':
      case 'DisplayStatus':
        HDGameMain().refresh();
        HDGameMain().gameOption.refresh();
        await Future.delayed(const Duration(milliseconds: 16));
        break;
      case 'Wait':
        int ms = (_getVal(args[0]) as num).toInt();
        await Future.delayed(Duration(milliseconds: ms));
        break;
      case 'TextAlign':
        int align = (_getVal(args[0]) as num).toInt();
        print("Stub: TextAlign(align: $align)");
        break;
      case 'Tile::CopyTile':
        int from = (_getVal(args[0]) as num).toInt();
        int to = (_getVal(args[1]) as num).toInt();
        final map = HDGameMain().map;
        if (map != null) {
          map.tileOverrides[to] = from;
          HDGameMain().mapVersion++;
          HDGameMain().notifyListeners();
        }
        break;
      case 'Tile::CopyToDefaultTile':
      case 'Tile::CopyToDefaultSprite':
        int typeToDflt = (_getVal(args[0]) as num).toInt();
        final map = HDGameMain().map;
        if (map != null) {
          map.tileOverrides.clear();
          HDGameMain().mapVersion++;
          HDGameMain().notifyListeners();
        }
        print("Stub: Tile::CopyToDefault(type: $typeToDflt)");
        break;
      default:
        print("Unknown command: $cmd");
    }
  }

  final List<String> _stringStack = [];

  String _popString(int count) {
    if (_stringStack.length < count) return "";
    var sub = _stringStack.sublist(_stringStack.length - count);
    _stringStack.removeRange(_stringStack.length - count, _stringStack.length);
    return sub.join("");
  }

  Future<void> _executeInclude(String path) async {
    String assetPath = 'assets/$path';
    String content;
    try {
      content = await rootBundle.loadString(assetPath);
    } catch (e) {
      print("ScriptEngine: Include failed for $path: $e");
      return;
    }
    List<ScriptStatement> extra = _parse(content);
    for (var stmt in extra) {
      await executeStatement(stmt);
    }
  }

  final Map<String, int> _tileMap = {};
  int _currentRow = 0;

  bool _toBool(dynamic val) {
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      if (val == "0" || val.toLowerCase() == "false" || val.isEmpty)
        return false;
      return true;
    }
    return val != null;
  }

  Future<bool> _evaluateCondition(IfStatement stmt) async {
    // Standardize the whole condition as a single evaluatable string
    String expr = stmt.conditionArgs.isEmpty
        ? stmt.conditionFunc
        : "${stmt.conditionFunc}(${stmt.conditionArgs.join(',')})";

    return _toBool(_getVal(expr));
  }

  int _currentScriptMode = 0;
  int _targetX = -1;
  int _targetY = -1;

  void setScriptMode(int mode) {
    _currentScriptMode = mode;
  }

  void setTargetPos(int x, int y) {
    _targetX = x;
    _targetY = y;
  }

  dynamic _getVal(String arg) {
    String trimmed = arg.trim();
    if (trimmed.isEmpty) return null;

    // 1. Literal String: "text"
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    // 2. Function Call: Name(...) or Name()
    if (trimmed.contains('(')) {
      var parsed = _parseCommand(trimmed);
      // Only treat as function if it actually parsed into command + args
      // and isn't just a string that happens to have a ( in it.
      if (parsed.command != trimmed) {
        return _invokeFunction(parsed.command, parsed.args);
      }
    }

    // 3. Numeric Literal
    if (num.tryParse(trimmed) != null) return num.parse(trimmed);

    // 4. Variable or Constant Lookup
    if (variables.containsKey(trimmed)) return variables[trimmed];

    // 5. Fallback for constants or literal unquoted strings
    return trimmed;
  }

  dynamic _invokeFunction(String cmd, List<String> rawArgs) {
    // RECURSIVE STEP: Evaluate all arguments before processing the function
    List<dynamic> args = rawArgs.map((a) => _getVal(a)).toList();

    switch (cmd) {
      // --- Logic and Arithmetic ---
      case 'Not':
        return _toBool(args.isNotEmpty ? args[0] : 0) ? 0 : 1;
      case 'Or':
        for (var a in args) if (_toBool(a)) return 1;
        return 0;
      case 'And':
        for (var a in args) if (!_toBool(a)) return 0;
        return 1;
      case 'Equal':
        if (args.length < 2) return 0;
        return args[0].toString() == args[1].toString() ? 1 : 0;
      case 'Less':
        if (args.length < 2) return 0;
        var v1 = args[0];
        var v2 = args[1];
        if (v1 is num && v2 is num) return v1 < v2 ? 1 : 0;
        return 0;
      case 'Add':
        num sum = 0;
        for (var a in args) if (a is num) sum += a;
        return sum;
      case 'Random':
        int max = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt()
            : 1;
        if (max <= 0) max = 1;
        return Random().nextInt(max);

      // --- Game State Queries ---
      case 'ScriptMode':
        return _currentScriptMode;
      case 'Flag::IsSet':
        int idx = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt()
            : -1;
        if (idx >= 0 && idx < HDConfig.maxFlags) {
          return HDGameMain().gameOption.flags[idx] ? 1 : 0;
        }
        return 0;
      case 'Variable::Get':
        int idx = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt()
            : -1;
        if (idx >= 0 && idx < HDConfig.maxVariables) {
          return HDGameMain().gameOption.variables[idx];
        }
        return 0;
      case 'On':
        if (args.length < 2) return 0;
        int x = (args[0] as num).toInt();
        int y = (args[1] as num).toInt();
        bool on = (_targetX != -1 && _targetY != -1)
            ? (_targetX == x && _targetY == y)
            : (HDGameMain().party.x == x && HDGameMain().party.y == y);
        return on ? 1 : 0;
      case 'OnArea':
        if (args.length < 4) return 0;
        int x1 = (args[0] as num).toInt();
        int y1 = (args[1] as num).toInt();
        int x2 = (args[2] as num).toInt();
        int y2 = (args[3] as num).toInt();
        int px = _targetX != -1 ? _targetX : HDGameMain().party.x;
        int py = _targetY != -1 ? _targetY : HDGameMain().party.y;
        return (px >= x1 && px <= x2 && py >= y1 && py <= y2) ? 1 : 0;

      // --- Data Retrieval ---
      case 'PopString':
        int count = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt()
            : 1;
        return _popString(count);
      case 'Battle::Result':
        return HDBattle().result();
      case 'Select::Result':
        return HDSelect().result();
      case 'Party::PosX':
        return HDGameMain().party.x;
      case 'Party::PosY':
        return HDGameMain().party.y;

      // --- Player Information ---
      case 'Player::GetName':
        int idx = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt() - 1
            : 0;
        if (idx >= 0 && idx < HDGameMain().party.players.length)
          return HDGameMain().party.players[idx].name;
        return "Unknown";
      case 'Player::GetGenderName':
        int idx = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt() - 1
            : 0;
        if (idx >= 0 && idx < HDGameMain().party.players.length)
          return HDGameMain().party.players[idx].getGenderName();
        return "Unknown";
      case 'Player::GetAttribute':
        if (args.length < 2) return 0;
        int pIdx = (args[0] as num).toInt() - 1;
        String attr = args[1].toString();
        if (pIdx >= 0 && pIdx < HDGameMain().party.players.length) {
          return HDGameMain().party.players[pIdx].getAttribute(attr);
        }
        return 0;
      case 'Player::IsAvailable':
        int idx = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt() - 1
            : 0;
        if (idx >= 0 && idx < HDGameMain().party.players.length) {
          return HDGameMain().party.players[idx].isValid() ? 1 : 0;
        }
        return 0;

      default:
        // If it's something like context.Equal(val), handle it manually if needed
        if (cmd.endsWith('.Equal')) {
          String varName = cmd.split('.').first;
          var v1 = _getVal(varName);
          var v2 = args.isNotEmpty ? args[0] : null;
          return v1.toString() == v2.toString() ? 1 : 0;
        }
        print("ScriptEngine: Unknown function $cmd");
        return 0;
    }
  }

  List<ScriptStatement> _parse(String content) {
    List<String> lines = content.split('\n');
    List<ScriptStatement> statements = [];

    _parseBlock(lines, 0, 0, statements);
    return statements;
  }

  int _parseBlock(
    List<String> lines,
    int currentLineIndex,
    int parentIndent,
    List<ScriptStatement> targetList,
  ) {
    int i = currentLineIndex;
    while (i < lines.length) {
      String line = lines[i];
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        i++;
        continue;
      }

      int indent = _countIndent(line);
      if (indent < parentIndent) return i;

      String trimmed = line.trim();

      if (trimmed.startsWith("if ") ||
          (trimmed.startsWith("if") && trimmed.contains("("))) {
        int startParen = trimmed.indexOf('(');
        String conditionContent = trimmed.substring(
          startParen + 1,
          trimmed.lastIndexOf(')'),
        );
        var parsedCond = _parseCommand(conditionContent);

        List<ScriptStatement> ifBody = [];
        int nextLineIdx = i + 1;
        int nextIndent = -1;

        while (nextLineIdx < lines.length &&
            (lines[nextLineIdx].trim().isEmpty ||
                lines[nextLineIdx].trim().startsWith('#'))) {
          nextLineIdx++;
        }

        if (nextLineIdx < lines.length) {
          nextIndent = _countIndent(lines[nextLineIdx]);
        }

        if (nextIndent > indent && nextIndent > parentIndent) {
          i = _parseBlock(lines, nextLineIdx, nextIndent, ifBody);
        } else {
          i = nextLineIdx;
        }

        List<ScriptStatement> elseBody = [];
        if (i < lines.length) {
          int elseLineIdx = i;
          while (elseLineIdx < lines.length &&
              (lines[elseLineIdx].trim().isEmpty ||
                  lines[elseLineIdx].trim().startsWith('#'))) {
            elseLineIdx++;
          }

          if (elseLineIdx < lines.length) {
            String nextLine = lines[elseLineIdx].trim();
            int elseLineIndent = _countIndent(lines[elseLineIdx]);
            if (nextLine == 'else' && elseLineIndent == indent) {
              int elseBodyIdx = elseLineIdx + 1;
              int elseIndent = -1;

              while (elseBodyIdx < lines.length &&
                  (lines[elseBodyIdx].trim().isEmpty ||
                      lines[elseBodyIdx].trim().startsWith('#'))) {
                elseBodyIdx++;
              }

              if (elseBodyIdx < lines.length) {
                elseIndent = _countIndent(lines[elseBodyIdx]);
              }

              if (elseIndent > indent && elseIndent > parentIndent) {
                i = _parseBlock(lines, elseBodyIdx, elseIndent, elseBody);
              } else {
                i = elseBodyIdx;
              }
            }
          }
        }

        targetList.add(
          IfStatement(parsedCond.command, parsedCond.args, ifBody, elseBody),
        );
        continue;
      } else {
        targetList.add(_parseCommand(trimmed));
        i++;
      }
    }
    return i;
  }

  CommandStatement _parseCommand(String line) {
    line = line.trim();
    int startParen = line.indexOf('(');
    if (startParen == -1) {
      return CommandStatement(line, []);
    }

    int lastParen = line.lastIndexOf(')');
    if (lastParen == -1 || lastParen <= startParen) {
      // Malformed or not a function call, return as-is
      return CommandStatement(line, []);
    }

    String cmd = line.substring(0, startParen).trim();
    String argsStr = line.substring(startParen + 1, lastParen);

    List<String> args = [];
    String buffer = "";
    bool inString = false;

    int parenDepth = 0;
    for (int j = 0; j < argsStr.length; j++) {
      String char = argsStr[j];
      if (char == '"') {
        inString = !inString;
        buffer += char;
      } else if (char == '(' && !inString) {
        parenDepth++;
        buffer += char;
      } else if (char == ')' && !inString) {
        parenDepth--;
        buffer += char;
      } else if (char == ',' && !inString && parenDepth == 0) {
        args.add(buffer.trim());
        buffer = "";
      } else {
        buffer += char;
      }
    }
    if (buffer.isNotEmpty) args.add(buffer.trim());

    return CommandStatement(cmd, args);
  }

  int _countIndent(String line) {
    int count = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        count++;
      } else if (line[i] == '\t') {
        count += 8; // Classic tab width
      } else {
        break;
      }
    }
    return count;
  }
}
