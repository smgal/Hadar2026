import 'package:cm2_script/cm2_script.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptEngine - variables and built-in commands', () {
    test('variable() declares variable with 0', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('variable(x)\nvariable(y)');
      expect(engine.variables['x'], equals(0));
      expect(engine.variables['y'], equals(0));
    });

    test('.assign sets variable', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('variable(n)\nn.assign(42)');
      expect(engine.variables['n'], equals(42));
    });

    test('.add increments variable', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('variable(c)\nc.assign(10)\nc.add(5)');
      await engine.run();
      expect(engine.variables['c'], equals(15));
    });

    test('halt() stops run', () async {
      final engine = ScriptEngine();
      var executed = 0;
      engine.registerCommand('Count', (stmt, e) async {
        executed++;
      });
      await engine.loadFromString('''
variable(x)
Count()
halt()
Count()
Count()
''');
      await engine.run();
      expect(executed, equals(1));
      expect(engine.halted, isTrue);
    });
  });

  group('ScriptEngine - getVal / built-in functions', () {
    test('getVal returns string literal', () {
      final engine = ScriptEngine();
      expect(engine.getVal('"hello"'), equals('hello'));
    });

    test('getVal returns number', () {
      final engine = ScriptEngine();
      expect(engine.getVal('42'), equals(42));
      expect(engine.getVal('0'), equals(0));
    });

    test('getVal returns variable', () async {
      final engine = ScriptEngine();
      engine.variables['foo'] = 100;
      expect(engine.getVal('foo'), equals(100));
    });

    test('Not(0) returns 1, Not(1) returns 0', () {
      final engine = ScriptEngine();
      expect(engine.getVal('Not(0)'), equals(1));
      expect(engine.getVal('Not(1)'), equals(0));
    });

    test('Equal compares values', () {
      final engine = ScriptEngine();
      expect(engine.getVal('Equal(1, 1)'), equals(1));
      expect(engine.getVal('Equal(1, 2)'), equals(0));
      expect(engine.getVal('Equal("a", "a")'), equals(1));
      expect(engine.getVal('Equal("a", "b")'), equals(0));
    });

    test('Less compares numbers', () {
      final engine = ScriptEngine();
      expect(engine.getVal('Less(1, 2)'), equals(1));
      expect(engine.getVal('Less(2, 1)'), equals(0));
      expect(engine.getVal('Less(0, 0)'), equals(0));
    });

    test('Add sums numbers', () {
      final engine = ScriptEngine();
      expect(engine.getVal('Add(1, 2)'), equals(3));
      expect(engine.getVal('Add(10, 20, 30)'), equals(60));
    });

    test('And / Or', () {
      final engine = ScriptEngine();
      expect(engine.getVal('And(1, 1)'), equals(1));
      expect(engine.getVal('And(1, 0)'), equals(0));
      expect(engine.getVal('Or(0, 0)'), equals(0));
      expect(engine.getVal('Or(0, 1)'), equals(1));
    });

    test('ScriptMode returns engine.scriptMode', () {
      final engine = ScriptEngine();
      expect(engine.getVal('ScriptMode()'), equals(0));
      engine.scriptMode = 3;
      expect(engine.getVal('ScriptMode()'), equals(3));
    });

    test('JoinString concatenates args', () {
      final engine = ScriptEngine();
      expect(engine.getVal('JoinString("a", "b", "c")'), equals('abc'));
      engine.variables['x'] = 'X';
      expect(engine.getVal('JoinString("pre", x, "suf")'), equals('preXsuf'));
    });

    test('varName.Equal(val) compares variable to arg', () async {
      final engine = ScriptEngine();
      engine.variables['x'] = 5;
      expect(engine.getVal('Equal(x, 5)'), equals(1));
      expect(engine.getVal('Equal(x, 6)'), equals(0));
    });

    test('Random(n) returns int in range', () {
      final engine = ScriptEngine();
      for (var i = 0; i < 20; i++) {
        final r = engine.getVal('Random(10)');
        expect(r, isA<int>());
        expect((r as int) >= 0 && r < 10, isTrue);
      }
    });
  });

  group('ScriptEngine - Context', () {
    test('Context::SetCurrent and Context::GetCurrent', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('Context::SetCurrent("global")');
      await engine.run();
      expect(engine.getVal('Context::GetCurrent()'), equals('global'));
    });

    test('Context::Set and Context::Get on current context', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('''
Context::SetCurrent("a")
Context::Set("x", 1)
Context::Set("y", "hello")
''');
      await engine.run();
      expect(engine.getVal('Context::Get("x")'), equals(1));
      expect(engine.getVal('Context::Get("y")'), equals('hello'));
    });

    test('Context switch and separate key-value per context', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('''
Context::SetCurrent("first")
Context::Set("k", 10)
Context::SetCurrent("second")
Context::Set("k", 20)
Context::SetCurrent("first")
''');
      await engine.run();
      expect(engine.getVal('Context::Get("k")'), equals(10));
      expect(engine.getVal('Context::GetCurrent()'), equals('first'));
      // Same setup, end on second
      await engine.loadFromString('''
Context::SetCurrent("first")
Context::Set("k", 10)
Context::SetCurrent("second")
Context::Set("k", 20)
''');
      await engine.run();
      expect(engine.getVal('Context::Get("k")'), equals(20));
      expect(engine.getVal('Context::GetCurrent()'), equals('second'));
    });

    test('Context::Delete removes context', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('''
Context::SetCurrent("a")
Context::Set("x", 1)
Context::SetCurrent("b")
Context::Set("x", 2)
Context::Delete("a")
Context::SetCurrent("b")
''');
      await engine.run();
      expect(engine.getVal('Context::Get("x")'), equals(2));
      expect(engine.getVal('Context::GetCurrent()'), equals('b'));
    });
  });

  group('ScriptEngine - if/else execution', () {
    test('executes if body when condition true', () async {
      final engine = ScriptEngine();
      var talked = false;
      engine.registerCommand('Talk', (stmt, e) async {
        talked = true;
      });
      await engine.loadFromString('''
variable(x)
x.assign(1)
if (Equal(x, 1))
    Talk("yes")
''');
      await engine.run();
      expect(talked, isTrue);
    });

    test('executes else body when condition false', () async {
      final engine = ScriptEngine();
      var elseRun = false;
      engine.registerCommand('SayElse', (stmt, e) async {
        elseRun = true;
      });
      await engine.loadFromString('''
variable(x)
x.assign(0)
if (Equal(x, 1))
    Talk("yes")
else
    SayElse()
''');
      await engine.run();
      expect(elseRun, isTrue);
    });

    test('skips if body when condition false', () async {
      final engine = ScriptEngine();
      var talked = false;
      engine.registerCommand('Talk', (stmt, e) async {
        talked = true;
      });
      await engine.loadFromString('''
variable(x)
x.assign(0)
if (Equal(x, 1))
    Talk("yes")
''');
      await engine.run();
      expect(talked, isFalse);
    });
  });

  group('ScriptEngine - registered command and function', () {
    test('registered command is invoked', () async {
      final engine = ScriptEngine();
      var received = '';
      engine.registerCommand('Echo', (stmt, e) async {
        received = e.getVal(stmt.args.isNotEmpty ? stmt.args[0] : '').toString();
      });
      await engine.loadFromString('Echo("hello")');
      await engine.run();
      expect(received, equals('hello'));
    });

    test('registered function is invoked in expression', () async {
      final engine = ScriptEngine();
      engine.registerFunction('Double', (args, e) {
        if (args.isEmpty) return 0;
        final n = args[0] is num ? (args[0] as num).toInt() : 0;
        return n * 2;
      });
      engine.variables['x'] = 5;
      expect(engine.getVal('Double(5)'), equals(10));
      expect(engine.getVal('Double(x)'), equals(10));
    });
  });

  group('ScriptEngine - include (contentLoader)', () {
    test('include loads and runs content via contentLoader', () async {
      final engine = ScriptEngine(
        contentLoader: (path) async {
          if (path == 'inc.txt') return 'variable(loaded)\nloaded.assign(99)';
          throw Exception('Unknown: $path');
        },
      );
      await engine.loadFromString('''
variable(loaded)
include("inc.txt")
''');
      await engine.run();
      expect(engine.variables['loaded'], equals(99));
    });

    test('include without contentLoader does not throw', () async {
      final engine = ScriptEngine();
      await engine.loadFromString('include("missing.txt")');
      await engine.run();
      // include fails silently (logs), no exception
    });
  });

  group('ScriptEngine - clearRuntimeState', () {
    test('clearRuntimeState clears variables', () async {
      final engine = ScriptEngine();
      engine.variables['x'] = 1;
      engine.clearRuntimeState();
      expect(engine.variables, isEmpty);
      expect(engine.halted, isFalse);
    });
  });

  group('ScriptEngine.toBool', () {
    test('toBool converts num, string, bool', () {
      expect(ScriptEngine.toBool(0), isFalse);
      expect(ScriptEngine.toBool(1), isTrue);
      expect(ScriptEngine.toBool('0'), isFalse);
      expect(ScriptEngine.toBool('false'), isFalse);
      expect(ScriptEngine.toBool(''), isFalse);
      expect(ScriptEngine.toBool('x'), isTrue);
      expect(ScriptEngine.toBool(true), isTrue);
      expect(ScriptEngine.toBool(false), isFalse);
    });
  });
}
