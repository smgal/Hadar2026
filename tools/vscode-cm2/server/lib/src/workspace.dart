import 'dart:io';

import 'package:path/path.dart' as p;

import 'index.dart';

/// A constant a script can read: `variable(NAME)` plus the `NAME.assign(v)`
/// that gave it a value, wherever in the include chain those live.
class ConstantDef {
  ConstantDef({
    required this.name,
    required this.file,
    required this.span,
    this.rawValue,
  });

  final String name;

  /// Absolute path of the file that declares it.
  final String file;
  final Span span;

  /// The literal on the right of `.assign`, or null when nothing assigns it.
  String? rawValue;

  num? get numberValue => rawValue == null ? null : num.tryParse(rawValue!);
}

/// What one file can see: its own names plus everything its includes bring.
class Scope {
  final Map<String, ConstantDef> constants = {};

  /// Includes that no search directory had.
  final List<IncludeUse> unresolved = [];

  bool get complete => unresolved.isEmpty;
}

/// One flag constant from a `flag*.cm2` file.
class FlagDef {
  FlagDef({required this.name, required this.number, required this.file, required this.span});

  final String name;
  final int number;
  final String file;
  final Span span;
}

/// Every flag name in the search directories, by number.
class FlagRegistry {
  final Map<int, List<FlagDef>> byNumber = {};
}

class _Cached {
  _Cached(this.modified, this.index);

  final DateTime modified;

  /// Null when the file could not be parsed; remembered so a broken sibling
  /// is not re-parsed on every keystroke.
  final Cm2Index? index;
}

/// Files on disk plus the live text of open documents. Includes resolve
/// against the document's own directory first, then [assetsDir].
class Workspace {
  Workspace({String assetsDir = ''}) {
    this.assetsDir = assetsDir;
  }

  String _assetsDir = '';
  String get assetsDir => _assetsDir;
  set assetsDir(String value) => _assetsDir = value.isEmpty ? '' : canonical(value);

  /// Every path this class stores or compares is absolute and normalized,
  /// so a relative `--assets` and a URI-derived path name the same file.
  static String canonical(String path) => p.normalize(p.absolute(path));

  final Map<String, Cm2Index> _openIndex = {};
  final Map<String, _Cached> _diskCache = {};

  /// Replaces the live text of [path]. Throws if the parser does; the
  /// caller decides what to tell the editor, and the previous index stays.
  void open(String path, String text) {
    _openIndex[canonical(path)] = Cm2Index.build(text);
  }

  void close(String path) {
    _openIndex.remove(canonical(path));
  }

  /// The index of [rawPath] — live if open, else from disk (cached by
  /// mtime). Null when the file is missing or cannot be parsed.
  Cm2Index? indexFor(String rawPath) {
    final path = canonical(rawPath);
    final live = _openIndex[path];
    if (live != null) return live;
    final file = File(path);
    if (!file.existsSync()) return null;
    final modified = file.lastModifiedSync();
    final cached = _diskCache[path];
    if (cached != null && cached.modified == modified) return cached.index;
    Cm2Index? index;
    try {
      index = Cm2Index.build(file.readAsStringSync());
    } catch (_) {
      index = null;
    }
    _diskCache[path] = _Cached(modified, index);
    return index;
  }

  /// Directories an `include("x.cm2")` in [fromPath] may refer to.
  List<String> searchDirs(String fromPath) {
    final dirs = <String>[canonical(p.dirname(fromPath))];
    if (assetsDir.isNotEmpty && assetsDir != dirs.first) dirs.add(assetsDir);
    return dirs;
  }

  String? resolveInclude(String fromPath, String include) {
    final rel = include.startsWith('assets/') ? include.substring('assets/'.length) : include;
    for (final dir in searchDirs(fromPath)) {
      final candidate = canonical(p.join(dir, rel));
      if (File(candidate).existsSync() || _openIndex.containsKey(candidate)) return candidate;
    }
    return null;
  }

  /// Names visible to [path]: its own declarations and, recursively, those
  /// of every file it includes. A name declared twice keeps the first.
  ///
  /// **An include inside a block counts the same as one at the top.** Its
  /// constants are visible to the whole file, although at run time they only
  /// exist after that branch has executed. This is the chosen default
  /// (2026-09-20): the per-quest include pattern of appendix L puts includes
  /// inside handler blocks on purpose, and flagging every read of their names
  /// would drown that pattern in warnings. Revisit only if a real script
  /// reads such a constant before its include ran.
  Scope scopeFor(String path, Cm2Index own) {
    final scope = Scope();
    _collect(canonical(path), own, scope, <String>{});
    return scope;
  }

  void _collect(String path, Cm2Index index, Scope scope, Set<String> visited) {
    if (!visited.add(path)) return;
    for (final decl in index.decls) {
      scope.constants.putIfAbsent(
        decl.name,
        () => ConstantDef(name: decl.name, file: path, span: decl.span),
      );
    }
    for (final write in index.writes) {
      final def = scope.constants[write.name];
      if (def != null && def.rawValue == null && !write.isAdd && def.file == path) {
        def.rawValue = write.rawValue;
      }
    }
    for (final inc in index.includes) {
      final resolved = resolveInclude(path, inc.path);
      if (resolved == null) {
        scope.unresolved.add(inc);
        continue;
      }
      final child = indexFor(resolved);
      if (child == null) {
        scope.unresolved.add(inc);
        continue;
      }
      _collect(resolved, child, scope, visited);
    }
  }

  /// Flag numbers with names, gathered from every `flag*.cm2` the file's
  /// search directories hold — including files the script does not include.
  /// That is the point: `menace.cm2` writes flag 10 by number without
  /// including `flag4ep1.cm2`, and 10 is `GFD1_WALL_REMOVER_USED` there.
  FlagRegistry flagRegistry(String fromPath) {
    final registry = FlagRegistry();
    final dirs = searchDirs(fromPath);
    final stepNames = _variableSlotNames(dirs);
    final seenFiles = <String>{};
    for (final dir in dirs) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      final files = d
          .listSync()
          .whereType<File>()
          .where((f) => isFlagFile(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        final path = canonical(f.path);
        if (!seenFiles.add(path)) continue;
        final index = indexFor(path);
        if (index == null) continue;
        final scope = Scope();
        _collect(path, index, scope, <String>{});
        for (final def in scope.constants.values) {
          if (def.file != path) continue;
          // `Flag::` and `Variable::` are different stores. A constant that
          // scripts pass to `Variable::Set/Get/Add` names a step slot, not a
          // flag, even when it lives in a flag file.
          if (stepNames.contains(def.name)) continue;
          final n = def.numberValue;
          if (n == null) continue;
          registry.byNumber
              .putIfAbsent(n.toInt(), () => [])
              .add(FlagDef(name: def.name, number: n.toInt(), file: path, span: def.span));
        }
      }
    }
    return registry;
  }

  /// Constant names any script in [dirs] hands to `Variable::*`.
  Set<String> _variableSlotNames(List<String> dirs) {
    final names = <String>{};
    for (final dir in dirs) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final f in d.listSync().whereType<File>()) {
        if (!f.path.endsWith('.cm2')) continue;
        final index = indexFor(f.path);
        if (index == null) continue;
        for (final call in index.calls) {
          if (!call.name.startsWith('Variable::') || call.args.isEmpty) continue;
          final arg = call.args.first.trim();
          if (Cm2Index.identifier.hasMatch(arg)) names.add(arg);
        }
      }
    }
    return names;
  }

  /// `flag4ep1.cm2`, `flag4quest1.cm2`, … — the files that name flags.
  static bool isFlagFile(String path) {
    final base = p.basename(path).toLowerCase();
    return base.startsWith('flag') && base.endsWith('.cm2');
  }
}
