import 'scripting/hd_script_engine.dart';

void main() async {
  final engine = HDScriptEngine();

  String testScript = """
variable(flag_map)
variable(count)

if (Equal(count, 0))
    Talk("Count is zero")
    halt()
    
if (On(10, 10))
    Talk("On 10,10")
""";

  engine.loadFromString(testScript);
  engine.variables['count'] = 0; // Initialize variable

  print("--- Starting Script Execution ---");
  await engine.run();
  print("--- Execution Finished ---");
}
