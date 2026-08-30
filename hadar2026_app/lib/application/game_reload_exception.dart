/// Thrown to unwind the current run loop after a successful `loadGame`.
///
/// Lives in `application/` because it is pure control flow over the
/// session — the script engine and the battle loop both catch it and
/// stop silently, so it must never be logged as an error.
///
/// Re-exported from `hd_game_main.dart` so existing call sites that
/// import the facade keep compiling.
class GameReloadException implements Exception {
  final String message;
  GameReloadException([this.message = "Game reloaded"]);

  @override
  String toString() => 'GameReloadException: $message';
}
