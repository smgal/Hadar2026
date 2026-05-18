/// Console rendering mode. The base layer is always [progress]; an
/// [overlay] sits on top during dialogue / menu / system-result cycles.
enum HDConsoleViewMode { progress, overlay }

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

  /// Shows a popup window menu and resolves to the selected 1-based index,
  /// or 0 for cancel. [items] index 0 is the title; remaining entries are choices.
  ///
  /// [x] / [y] override the window's top-left position; null falls back
  /// to the host's default (console-aligned). The map-side main menu
  /// passes the legacy centred x to keep its current placement.
  Future<int> showWindowMenu(
    List<String> items, {
    int initialChoice = 1,
    int enabledCount = -1,
    int? x,
    int? y,
  });

  /// Shows a read-and-dismiss popup with [text] and resolves when the
  /// user closes it (Enter or Esc). Use this for signs and other
  /// one-shot messages — fixed size, no selection. For multi-page
  /// dialogue, use `addLog` + `waitForAnyKey` against the console.
  Future<void> showMessageWindow(String text, {int? x, int? y});

  /// Adds a line of text to the appropriate console pane.
  /// When [isDialogue] is true the text is treated as event/story output
  /// (auto-paginated, waits on overflow); otherwise it is a progress log
  /// (auto-scrolls).
  Future<void> addLog(String message, {bool isDialogue = true});

  /// Blocks until the user presses any non-directional key (or its virtual
  /// equivalent).
  Future<void> waitForAnyKey();

  /// Clears the dialogue/event log pane. Also clears the dialogue header
  /// (set via [setHeader]) so a new dialogue cycle starts without stale
  /// header text — the user-visible rule is "the header lives with the
  /// body it titles."
  void clearLogs();

  /// Sets the dialogue header line (top row of the dialogue panel).
  /// Pass an empty string to hide the header. Header text may include
  /// `@X..@@` color tags; conventionally `@B` (blue) is used.
  ///
  /// Cleared automatically whenever the body is cleared ([clearLogs] or
  /// page-flush after a long dialogue), so callers don't need to balance
  /// set/clear pairs around each Talk page.
  void setHeader(String text);

  /// Marks the start of a narrative cycle (dialogue, menu, system result).
  /// Keeps the overlay layer visible even when [events] briefly empties
  /// (e.g. between a page-flush PressAnyKey and the next dialogue line).
  ///
  /// Idempotent — re-entry within an active cycle is a no-op.
  void beginNarrative();

  /// Ends the current narrative cycle: clears events, hides the overlay,
  /// and optionally appends a single-line [summary] to the progress log
  /// (e.g. "일행은 6시간 휴식했다") so the cycle leaves a trace behind.
  ///
  /// When [autoFlush] is true (default), if events are still on screen at
  /// the moment of the call (e.g. a one-shot sign whose script never
  /// invoked `waitForAnyKey`), the host waits for one keypress before
  /// clearing them. This prevents messages from flashing away — the
  /// caller doesn't have to remember whether the script paused or not.
  Future<void> endNarrative({String? summary, bool autoFlush = true});

  /// One-time preload of any assets the host needs to render the world
  /// (sprite sheets, tile sheets, fonts, …). Called once during boot
  /// before the gameplay session starts. Headless / CLI hosts may
  /// implement this as a no-op.
  Future<void> preloadAssets();
}
