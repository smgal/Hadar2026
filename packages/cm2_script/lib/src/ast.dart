/// AST nodes for line-based scripts with if/else blocks.

abstract class ScriptStatement {}

class CommandStatement extends ScriptStatement {
  String command;
  List<String> args;

  /// 0-based source line this statement came from, or -1 when the
  /// statement was parsed from an expression fragment rather than a line
  /// (`parseCommand` on a nested `Not(Flag::IsSet(x))`). Tooling reads it;
  /// the engine never does.
  int line = -1;

  CommandStatement(this.command, this.args);

  @override
  String toString() => "$command(${args.join(', ')})";
}

class IfStatement extends ScriptStatement {
  String conditionFunc;
  List<String> conditionArgs;
  List<ScriptStatement> body;
  List<ScriptStatement> elseBody;

  /// 0-based source line of the `if`, or -1 when built by hand.
  int line = -1;

  /// 0-based source line of the matching `else`, or -1 when there is none.
  int elseLine = -1;

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
