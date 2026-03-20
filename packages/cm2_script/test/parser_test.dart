import 'package:cm2_script/cm2_script.dart';
import 'package:test/test.dart';

void main() {
  group('parseCommand', () {
    test('parses command with no args', () {
      final stmt = parseCommand('foo()');
      expect(stmt, isA<CommandStatement>());
      expect((stmt as CommandStatement).command, equals('foo'));
      expect(stmt.args, isEmpty);
    });

    test('parses command with one string arg', () {
      final stmt = parseCommand('Talk("Hello")');
      expect((stmt as CommandStatement).command, equals('Talk'));
      expect(stmt.args, equals(['"Hello"']));
    });

    test('parses command with numeric args', () {
      final stmt = parseCommand('Map::Init(20, 15)');
      expect((stmt as CommandStatement).command, equals('Map::Init'));
      expect(stmt.args, equals(['20', '15']));
    });

    test('parses command with multiple args', () {
      final stmt = parseCommand('Add(1, 2, 3)');
      expect((stmt as CommandStatement).command, equals('Add'));
      expect(stmt.args, equals(['1', '2', '3']));
    });

    test('line without parens becomes command with no args', () {
      final stmt = parseCommand('variable');
      expect((stmt as CommandStatement).command, equals('variable'));
      expect(stmt.args, isEmpty);
    });
  });

  group('parseScript', () {
    test('parses empty content', () {
      final list = parseScript('');
      expect(list, isEmpty);
    });

    test('parses single command', () {
      final list = parseScript('halt()');
      expect(list.length, equals(1));
      expect(list[0], isA<CommandStatement>());
      expect((list[0] as CommandStatement).command, equals('halt'));
    });

    test('parses multiple top-level commands', () {
      final list = parseScript('''
variable(x)
variable(y)
halt()
''');
      expect(list.length, equals(3));
      expect((list[0] as CommandStatement).command, equals('variable'));
      expect((list[1] as CommandStatement).command, equals('variable'));
      expect((list[2] as CommandStatement).command, equals('halt'));
    });

    test('skips empty lines and comments', () {
      final list = parseScript('''
# comment
variable(a)

halt()
''');
      expect(list.length, equals(2));
      expect((list[0] as CommandStatement).command, equals('variable'));
      expect((list[1] as CommandStatement).command, equals('halt'));
    });

    test('parses if with body', () {
      final list = parseScript('''
if (Equal(x, 0))
    Talk("zero")
halt()
''');
      expect(list.length, equals(2));
      expect(list[0], isA<IfStatement>());
      final ifStmt = list[0] as IfStatement;
      expect(ifStmt.conditionFunc, equals('Equal'));
      expect(ifStmt.conditionArgs, equals(['x', '0']));
      expect(ifStmt.body.length, equals(1));
      expect(ifStmt.body[0], isA<CommandStatement>());
      expect((ifStmt.body[0] as CommandStatement).command, equals('Talk'));
      expect(list[1], isA<CommandStatement>());
      expect((list[1] as CommandStatement).command, equals('halt'));
    });

    test('parses if-else', () {
      final list = parseScript('''
if (Equal(n, 1))
    Talk("one")
else
    Talk("other")
''');
      expect(list.length, equals(1));
      expect(list[0], isA<IfStatement>());
      final ifStmt = list[0] as IfStatement;
      expect(ifStmt.elseBody.length, equals(1));
      expect((ifStmt.elseBody[0] as CommandStatement).command, equals('Talk'));
      expect((ifStmt.elseBody[0] as CommandStatement).args[0], equals('"other"'));
    });
  });
}
