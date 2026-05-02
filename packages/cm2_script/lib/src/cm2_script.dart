import 'dart:async';
import 'dart:math';

import 'ast.dart';
import 'parser.dart' show parseScript, parseCommand;

typedef ScriptCommandHandler = Future<void> Function(
  CommandStatement stmt,
  ScriptEngine engine,
);

typedef ScriptFunctionHandler = dynamic Function(
  List<dynamic> args,
  ScriptEngine engine,
);

/// Loads included script fragments. [path] is as written in script (e.g. relative path);
/// caller resolves to actual file/bundle path.
typedef ScriptContentLoader = Future<String> Function(String path);

/// Pluggable script engine: parses line-based scripts, evaluates expressions,
/// and dispatches commands/functions via registration.
class ScriptEngine {
  ScriptEngine({
    ScriptContentLoader? contentLoader,
  }) : _contentLoader = contentLoader;

  ScriptContentLoader? _contentLoader;

  void setContentLoader(ScriptContentLoader? loader) {
    _contentLoader = loader;
  }

  final Map<String, dynamic> variables = {};
  List<ScriptStatement> currentScript = [];

  /// Named contexts: name -> (key -> value). Use Context::SetCurrent / Get / Set / Delete.
  final Map<String, Map<String, dynamic>> _contexts = {};
  String? _currentContextName;

  bool halted = false;

  /// Set by `Event::MarkHandled`. Reset to `false` at the start of every
  /// [run]. Hosts read this after a run to decide whether to fall through
  /// to a lower-priority event source (e.g. static JSON map events).
  bool handled = false;

  int scriptMode = 0;
  int targetX = -1;
  int targetY = -1;

  final Map<String, ScriptCommandHandler> _commands = {};
  final Map<String, ScriptFunctionHandler> _functions = {};

  void registerCommand(String name, ScriptCommandHandler handler) {
    _commands[name] = handler;
  }

  void registerFunction(String name, ScriptFunctionHandler handler) {
    _functions[name] = handler;
  }

  /// Parse [content] into statements without mutating engine state.
  static List<ScriptStatement> parse(String content) => parseScript(content);

  /// Clear variables and contexts; does not clear registered handlers.
  void clearRuntimeState() {
    variables.clear();
    _contexts.clear();
    _currentContextName = null;
    halted = false;
  }

  Future<void> loadFromString(String content) async {
    clearRuntimeState();
    currentScript = parseScript(content);
    await _executeRootInitialization();
  }

  Future<void> _executeRootInitialization() async {
    for (var stmt in currentScript) {
      if (stmt is CommandStatement) {
        if (stmt.command == 'variable' ||
            stmt.command == 'include' ||
            stmt.command.endsWith('.assign')) {
          await executeCommand(stmt);
        }
      }
    }
  }

  Future<void> run({void Function(Object error, StackTrace stack)? onError}) async {
    halted = false;
    handled = false;
    final statements = List<ScriptStatement>.from(currentScript);
    try {
      for (var stmt in statements) {
        if (stmt is CommandStatement) {
          if (stmt.command == 'variable' || stmt.command == 'include') continue;
        }
        await executeStatement(stmt);
        if (halted) break;
      }
    } catch (e, stack) {
      if (onError != null) {
        onError(e, stack);
      } else {
        // ignore: avoid_print
        print("ScriptEngine Error: $e\n$stack");
      }
    }
  }

  Future<void> executeStatement(ScriptStatement stmt) async {
    if (stmt is CommandStatement) {
      await executeCommand(stmt);
    } else if (stmt is IfStatement) {
      if (_toBool(_evaluateCondition(stmt))) {
        for (var step in stmt.body) {
          await executeStatement(step);
          if (halted) break;
        }
      } else if (stmt.elseBody.isNotEmpty) {
        for (var step in stmt.elseBody) {
          await executeStatement(step);
          if (halted) break;
        }
      }
    }
  }

  Future<void> executeCommand(CommandStatement stmt) async {
    final cmd = stmt.command;
    final args = stmt.args;

    if (cmd.endsWith('.assign')) {
      final varName = cmd.split('.')[0];
      if (!variables.containsKey(varName)) {
        // ignore: avoid_print
        print("Warning: Assigning to unregistered variable: $varName");
      }
      variables[varName] = getVal(args.isNotEmpty ? args[0] : '');
      return;
    }
    if (cmd.endsWith('.add')) {
      final varName = cmd.split('.')[0];
      if (!variables.containsKey(varName)) {
        // ignore: avoid_print
        print("Warning: Adding to unregistered variable: $varName");
      }
      final current = variables[varName] ?? 0;
      final inc = args.isNotEmpty ? getVal(args[0]) : 0;
      variables[varName] =
          (current is num ? current : 0) + (inc is num ? inc : 0);
      return;
    }

    switch (cmd) {
      case 'variable':
        if (args.isNotEmpty) variables[args[0]] = 0;
        break;
      case 'include':
        final path = _unwrapQuoted(getVal(args.isNotEmpty ? args[0] : '').toString());
        // ignore: avoid_print
        print("ScriptEngine: Including $path");
        await _executeInclude(path);
        break;
      case 'halt':
        halted = true;
        break;
      case 'Event::MarkHandled':
        handled = true;
        break;
      case 'Context::SetCurrent':
        if (args.isNotEmpty) {
          final name = getVal(args[0]).toString();
          final unwrapped = _unwrapQuoted(name);
          _contexts.putIfAbsent(unwrapped, () => {});
          _currentContextName = unwrapped;
        }
        break;
      case 'Context::Delete':
        if (args.isNotEmpty) {
          final name = _unwrapQuoted(getVal(args[0]).toString());
          _contexts.remove(name);
          if (_currentContextName == name) {
            _currentContextName = _contexts.isEmpty ? null : _contexts.keys.first;
          }
        }
        break;
      case 'Context::Set':
        if (_currentContextName != null && args.length >= 2) {
          final key = _unwrapQuoted(getVal(args[0]).toString());
          final value = getVal(args[1]);
          _contexts[_currentContextName]![key] = value;
        }
        break;
      default:
        final handler = _commands[cmd];
        if (handler != null) {
          await handler(stmt, this);
        } else {
          // ignore: avoid_print
          print("Unknown command: $cmd");
        }
    }
  }

  Future<void> _executeInclude(String path) async {
    if (_contentLoader == null) {
      // ignore: avoid_print
      print("ScriptEngine: Include failed (no contentLoader): $path");
      return;
    }
    try {
      final content = await _contentLoader!(path);
      final extra = parseScript(content);
      for (var stmt in extra) {
        await executeStatement(stmt);
      }
    } catch (e) {
      // ignore: avoid_print
      print("ScriptEngine: Include failed for $path: $e");
    }
  }

  static String _unwrapQuoted(String s) {
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  static bool toBool(dynamic val) {
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      if (val == "0" || val.toLowerCase() == "false" || val.isEmpty) {
        return false;
      }
      return true;
    }
    return val != null;
  }

  bool _toBool(dynamic val) => toBool(val);

  bool _evaluateCondition(IfStatement stmt) {
    final expr = stmt.conditionArgs.isEmpty
        ? stmt.conditionFunc
        : "${stmt.conditionFunc}(${stmt.conditionArgs.join(',')})";
    return _toBool(getVal(expr));
  }

  dynamic getVal(String arg) {
    final trimmed = arg.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    if (trimmed.contains('(')) {
      final parsed = parseCommand(trimmed);
      if (parsed.command != trimmed) {
        return invokeFunction(parsed.command, parsed.args);
      }
    }

    if (num.tryParse(trimmed) != null) return num.parse(trimmed);
    if (variables.containsKey(trimmed)) return variables[trimmed];
    return trimmed;
  }

  dynamic invokeFunction(String cmd, List<String> rawArgs) {
    final args = rawArgs.map((a) => getVal(a)).toList();

    switch (cmd) {
      case 'Not':
        return _toBool(args.isNotEmpty ? args[0] : 0) ? 0 : 1;
      case 'Or':
        for (final a in args) {
          if (_toBool(a)) return 1;
        }
        return 0;
      case 'And':
        for (final a in args) {
          if (!_toBool(a)) return 0;
        }
        return 1;
      case 'Equal':
        if (args.length < 2) return 0;
        return args[0].toString() == args[1].toString() ? 1 : 0;
      case 'Less':
        if (args.length < 2) return 0;
        final v1 = args[0];
        final v2 = args[1];
        if (v1 is num && v2 is num) return v1 < v2 ? 1 : 0;
        return 0;
      case 'Add':
        num sum = 0;
        for (final a in args) {
          if (a is num) sum += a;
        }
        return sum;
      case 'Random':
        var max = (args.isNotEmpty && args[0] is num)
            ? (args[0] as num).toInt()
            : 1;
        if (max <= 0) max = 1;
        return Random().nextInt(max);
      case 'ScriptMode':
        return scriptMode;
      case 'JoinString':
        return args.map((a) => a.toString()).join('');
      case 'Context::Get':
        if (_currentContextName == null) return null;
        if (args.isEmpty) return null;
        final key = _unwrapQuoted(args[0].toString());
        return _contexts[_currentContextName]![key] ?? null;
      case 'Context::GetCurrent':
        return _currentContextName ?? '';
      default:
        if (cmd.endsWith('.Equal')) {
          final varName = cmd.split('.').first;
          final v1 = getVal(varName);
          final v2 = args.isNotEmpty ? args[0] : null;
          return v1.toString() == v2.toString() ? 1 : 0;
        }
        final handler = _functions[cmd];
        if (handler != null) {
          return handler(args, this);
        }
        // ignore: avoid_print
        print("ScriptEngine: Unknown function $cmd");
        return 0;
    }
  }

}
