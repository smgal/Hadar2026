/// AST nodes for line-based scripts with if/else blocks.

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
  List<ScriptStatement> elseBody;

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
