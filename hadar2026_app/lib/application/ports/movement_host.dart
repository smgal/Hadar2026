/// Boundary for "move the party by N tiles, possibly with animation."
///
/// Lives next to [UiHost] because it's the same kind of seam: domain /
/// application code asks for an effect, the rendering surface decides
/// how to deliver it. A Bonfire-backed host plays the walk animation; a
/// headless / CLI host just bumps the domain coordinates.
abstract class PartyMovementHost {
  /// Move the party by [dx], [dy] tiles. Returns when any animation has
  /// completed and the domain coordinates are in sync.
  Future<void> animatePartyMove(int dx, int dy);
}
