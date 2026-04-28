/// Boundary between domain/application logic and the rendering surface.
///
/// Domain code that needs to print messages, wait for input, or pop a menu
/// should depend on this interface — never on a concrete UI class. A
/// headless test or an alternate frontend can supply its own implementation.
abstract class UiHost {
  /// Shows a menu and resolves to the selected 1-based index, or 0 for
  /// cancel. [items] index 0 is the title; remaining entries are choices.
  Future<int> showMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    bool clearLogs = true,
  });

  /// Adds a line of text to the appropriate console pane.
  /// When [isDialogue] is true the text is treated as event/story output
  /// (auto-paginated, waits on overflow); otherwise it is a progress log
  /// (auto-scrolls).
  Future<void> addLog(String message, {bool isDialogue = true});

  /// Blocks until the user presses any non-directional key (or its virtual
  /// equivalent).
  Future<void> waitForAnyKey();

  /// Clears the dialogue/event log pane.
  void clearLogs();
}
