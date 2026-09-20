import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// One parameter of a cm2 verb as the table spells it.
class Cm2Param {
  Cm2Param(this.name, {required this.optional});

  final String name;
  final bool optional;

  /// `"..."` means "as many as you like".
  bool get isVariadic => name == '...';
}

/// A verb the engine or the app answers.
class Cm2Symbol {
  Cm2Symbol({
    required this.name,
    required this.kind,
    required this.params,
    required this.doc,
    this.builtin = false,
    this.example,
  });

  final String name;

  /// `command` (a statement on its own line) or `function` (yields a value).
  final String kind;
  final List<Cm2Param> params;
  final String doc;
  final bool builtin;
  final String? example;

  bool get isCommand => kind == 'command';
  bool get isVariadic => params.any((p) => p.isVariadic);
  int get minArgs => params.where((p) => !p.optional && !p.isVariadic).length;
  int? get maxArgs => isVariadic ? null : params.length;

  String get signature =>
      '$name(${params.map((p) => p.optional ? '${p.name}?' : p.name).join(', ')})';

  /// Markdown for hover and completion detail.
  String get markdown {
    final buf = StringBuffer()
      ..writeln('```cm2')
      ..writeln(signature)
      ..writeln('```')
      ..writeln()
      ..writeln(doc);
    if (example != null) {
      buf
        ..writeln()
        ..writeln('```cm2')
        ..writeln(example)
        ..writeln('```');
    }
    buf
      ..writeln()
      ..write(builtin ? '_cm2 내장 ${isCommand ? '명령' : '함수'}_' : '_앱이 등록한 ${isCommand ? '명령' : '함수'}_');
    return buf.toString();
  }
}

/// `이름.assign(값)` and friends — handled by suffix, not by name.
class Cm2MemberForm {
  Cm2MemberForm({required this.suffix, required this.signature, required this.doc});

  final String suffix;
  final String signature;
  final String doc;
}

/// The verbs a script may use. Loaded once from `cm2_symbols.json`.
class SymbolTable {
  SymbolTable._(this.commands, this.functions, this.memberForms, this.maxFlags);

  final Map<String, Cm2Symbol> commands;
  final Map<String, Cm2Symbol> functions;
  final List<Cm2MemberForm> memberForms;

  /// How many flag slots the game has (`HDConfig.maxFlags`). Carried in the
  /// JSON so the app's snapshot test can hold it against the real constant.
  final int maxFlags;

  Iterable<Cm2Symbol> get all => [...commands.values, ...functions.values];

  Cm2Symbol? command(String name) => commands[name];
  Cm2Symbol? function(String name) => functions[name];

  /// Either kind — hover does not care which one the cursor sits on.
  Cm2Symbol? any(String name) => commands[name] ?? functions[name];

  Cm2MemberForm? memberForm(String suffix) {
    for (final m in memberForms) {
      if (m.suffix == suffix) return m;
    }
    return null;
  }

  static SymbolTable fromJson(String text) {
    final doc = jsonDecode(text) as Map<String, dynamic>;
    final maxFlags = doc['maxFlags'] as int? ?? 256;
    // `{{maxFlag}}` in a doc string becomes the highest valid number, so the
    // hover text cannot drift from the constant it describes.
    String fill(String s) => s.replaceAll('{{maxFlag}}', '${maxFlags - 1}');
    final commands = <String, Cm2Symbol>{};
    final functions = <String, Cm2Symbol>{};
    for (final raw in (doc['symbols'] as List).cast<Map<String, dynamic>>()) {
      final params = (raw['params'] as List? ?? const [])
          .cast<String>()
          .map(
            (p) => p.endsWith('?')
                ? Cm2Param(p.substring(0, p.length - 1), optional: true)
                : Cm2Param(p, optional: false),
          )
          .toList();
      final symbol = Cm2Symbol(
        name: raw['name'] as String,
        kind: raw['kind'] as String,
        params: params,
        doc: fill(raw['doc'] as String? ?? ''),
        builtin: raw['builtin'] as bool? ?? false,
        example: raw['example'] as String?,
      );
      (symbol.isCommand ? commands : functions)[symbol.name] = symbol;
    }
    final memberForms = (doc['memberForms'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (m) => Cm2MemberForm(
            suffix: m['suffix'] as String,
            signature: m['signature'] as String,
            doc: fill(m['doc'] as String),
          ),
        )
        .toList();
    return SymbolTable._(commands, functions, memberForms, maxFlags);
  }

  /// Reads the table from [path] when given, else from this package's own
  /// `lib/data/cm2_symbols.json`. A compiled executable cannot resolve a
  /// `package:` URI, which is why the extension always passes `--symbols`.
  static Future<SymbolTable> load({String? path}) async {
    if (path != null && path.isNotEmpty) {
      return fromJson(await File(path).readAsString());
    }
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:cm2_lsp/data/cm2_symbols.json'),
    );
    if (uri == null) {
      throw StateError(
        'cm2_symbols.json 을 찾을 수 없다. --symbols <경로> 로 넘겨야 한다.',
      );
    }
    return fromJson(await File.fromUri(uri).readAsString());
  }
}
