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

  /// Asks the rendering surface to redraw. Use after mutating session
  /// state in place (tile overrides, map-type swaps, a restored save)
  /// where no other notification would fire.
  ///
  /// Deliberately distinct from a *session-changed* notification: a map
  /// transition additionally resets the per-map progress scrollback,
  /// whereas [refresh] is a pure repaint request.
  void refresh();

  /// One-time preload of any assets the host needs to render the world
  /// (sprite sheets, tile sheets, fonts, …). Called once during boot
  /// before the gameplay session starts. Headless / CLI hosts may
  /// implement this as a no-op.
  Future<void> preloadAssets();

  /// Asks the player to type a short text (a character's name).
  ///
  /// The originals had the player assemble the name from an on-screen
  /// jamo table, which is what a 1995 DOS program without a Korean input
  /// method had to do. A text field does the same job; on a phone it
  /// raises the system keyboard. Returns null when cancelled.
  Future<String?> askText(
    String prompt, {
    int maxLength = 8,
    String initial = '',
  });

  /// Dims the whole screen to black ([out]) or back ([out] false). The
  /// originals use a fade only in cutscenes (부록 D.5).
  Future<void> fade({required bool out, int milliseconds = 600});

  /// One white flash over the whole screen.
  Future<void> flash({int milliseconds = 120});

  /// 검은 화면 한 장에 글을 보이고 키를 기다린다 — 오프닝 편지와 엔딩 글.
  /// [color] 는 원작 16색 번호(0~15), [mode] 는 `LETTER_*`(0 한 번에 ·
  /// 1 위로 흐름 · 2 번개). 게임 안의 대화 창과 달리 화면 전체를 쓴다.
  ///
  /// [pictures] 는 문단마다 왼쪽에 붙일 1부 인물 그림(`lore1_chara.png` 번호)이다.
  /// 줄마다 번호 목록, 없으면 null (1부 엔딩 「공헌한 인물」).
  Future<void> showLetter(
    List<String> paragraphs, {
    int color = 15,
    int mode = 0,
    List<List<List<int>>?>? pictures,
  });

  /// 지도 칸을 검게 덮고 이름 목록을 쓴다 — 1부의 적 목록(이름만, 생명력에 따른 색).
  /// [lines] 가 비면 걷는다. 색은 원작 16색 번호다.
  void showNameList(List<({String text, int color})> lines);
}
