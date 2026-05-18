import '../hd_game_main.dart';

class HDSelect {
  static final HDSelect _instance = HDSelect._internal();
  factory HDSelect() => _instance;
  HDSelect._internal();

  List<String> items = [];
  int selectedIndex = 0;
  bool isSelectionActive = false;
  int _lastResult = 0;

  void init() {
    print("Select::Init()");
    // 앞의 글자에서 엔터를 한 번 적용
    HDGameMain().addLog('');
    items.clear();
    selectedIndex = 0;
    isSelectionActive = false;
    _lastResult = 0;
  }

  void add(String text) {
    if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1);
    }
    print("Select::Add($text)");
    items.add(text);
  }

  Future<void> run() async {
    isSelectionActive = true;
    // Script-driven selections render at the bottom of the dialog body
    // (not a centred popup) — keeps the menu visually attached to the
    // dialogue line that prompted it. clearLogs:false so the prior
    // dialogue stays on screen above the choices.
    _lastResult = await HDGameMain().showMenu(items, clearLogs: false);
    isSelectionActive = false;
  }

  int result() {
    return _lastResult;
  }
}
