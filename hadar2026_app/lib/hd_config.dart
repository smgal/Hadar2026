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
  static const double consoleFontSize = 16.0;
  static const double consoleLineHeight = 1.2;

  // Bottom-left: status panel sits under the map viewport (same width).
  static const double statusPanelWidth = 288.0;
  static const double statusPanelHeight = 160.0;
  static const double statusFontSize = 16.0;
  static const double statusLineHeight = 1.2;

  // Bottom-right: input panel for narrative-driven selection menus
  // (Select::Run, dialogue choices). Sized to mirror the console.
  static const double inputPanelWidth = 512.0;
  static const double inputPanelHeight = 160.0;

  // --- Scripting Settings ---
  static const int maxFlags = 256;
  static const int maxVariables = 256;

  /// Events page size for the narrative overlay. Sized to fit inside
  /// the 320×512 console panel given the current font: a 16pt line at
  /// height multiplier 1.2 occupies 19.2px, leaving ~256px of usable
  /// vertical space (320 minus 16 padding minus 48 prompt area).
  static const int maxLinesPerPage = 13;

  /// Rolling buffer for the always-visible progress base layer. Bigger
  /// than [maxLinesPerPage] so the player can scroll back through
  /// movement / ambient messages within the current map (the buffer is
  /// cleared on map transitions).
  static const int maxProgressLines = 200;

  // --- Asset Paths ---
  static const String mainSpriteSheet = 'lore_sprite_transparent.png';
  static const String mainTileSheet = 'lore_tile.bmp';
  static const String startupScript = 'assets/startup.cm2';
}
