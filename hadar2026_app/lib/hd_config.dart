class HDConfig {
  // --- Player Settings ---
  static const double playerMoveSpeed = 200.0; // Pixels per second

  // --- Map Settings ---
  static const double tileSize = 32.0;
  static const int mapHandicapMax = 4;

  // --- Display Settings ---
  static const double gameScreenWidth = 800.0;
  static const double gameScreenHeight = 480.0;
  static const double mapViewportWidth = 288.0;
  static const double mapViewportHeight = 320.0;
  static const double consoleWidth = 512.0;
  static const double consoleHeight = 320.0;
  static const double consoleFontSize = 14.0;
  static const double consoleLineHeight = 1.4;
  static const double statusPanelWidth = 800.0;
  static const double statusPanelHeight = 160.0;
  static const double statusFontSize = 14.0;
  static const double statusLineHeight = 1.2;

  // --- Scripting Settings ---
  static const int maxFlags = 256;
  static const int maxVariables = 256;
  static const int maxLinesPerPage = 14;

  // --- Asset Paths ---
  static const String mainSpriteSheet = 'lore_sprite_transparent.png';
  static const String mainTileSheet = 'lore_tile.bmp';
  static const String startupScript = 'assets/startup.cm2';
}
