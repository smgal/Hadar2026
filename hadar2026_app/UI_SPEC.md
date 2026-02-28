# Hadar 2026 UI Specification

## 1. Screen Dimensions
*   **Total Client Area**: 800 x 480 px
*   **Target Device Resolution**: Fixed 800x480 (Windows size approx 816x519 including borders)

## 2. Viewport Layout
The screen is divided into three main fixed areas:

### 2.1 HDMapViewport (Game World)
*   **Position**: (0, 0)
*   **Size**: 288 x 320 px
*   **Tile Specification**: 
    *   Base Tile Size: 32 x 32 px
    *   Visible Grid: 9 columns x 10 rows
*   **Camera Behavior**: 
    *   Always centers on the player character.
    *   Immediate snapping (no lazy/smooth movement).
    *   Ignores map boundaries (player stays at center even at map edges).
*   **Overlays**:
    *   Player coordinates shown at (4, 4) in `( X, Y)` format.

### 2.2 HDConsolePanel (Log area)
*   **Position**: (288, 0)
*   **Size**: 512 x 320 px
*   **Function**: Displays script dialogue (`Talk`), system logs, and user prompts.
*   **Style**: 
    *   White text on black background.
    *   Monospace font for system feel.
    *   Yellow "Press any key" prompt at the bottom during blocking waits.

### 2.3 HDStatusPanel (Character Info)
*   **Position**: (0, 320)
*   **Size**: 800 x 160 px
*   **Function**: Displays party members' HP, SP, ESP, and names.
*   **Design**: 
    *   Grid-based layout (Header: name, hp, sp, esp).
    *   Support for up to 6 party members.
    *   Blue gradient background for active slots, red text for reserved/empty slots.

## 3. Interaction
*   **Movement**: 4-way grid-based movement (32px per step).
*   **Interaction Key**: Space bar (Interacts with signs, talks to NPCs, enters doors).
