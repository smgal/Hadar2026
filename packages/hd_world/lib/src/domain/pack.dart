import 'ids.dart';

/// What the party is carrying.
///
/// ## Shared, and counted
///
/// One pack for the whole party, as the original had it. Stacks are
/// counts rather than repeated rows, so a screen can show "치료약 x3"
/// without scanning.
///
/// [capacity] counts **distinct kinds**, not units. That is the rule
/// the original's twenty-slot pack actually implemented, and stating it
/// here stops the two readings from drifting.
class Pack {
  Pack({this.capacity = 24, Map<ItemRef, int>? counts})
    : _counts = {...?counts};

  final int capacity;
  final Map<ItemRef, int> _counts;

  /// Distinct kinds held.
  int get kindCount => _counts.length;

  bool get isFull => _counts.length >= capacity;

  Map<ItemRef, int> get counts => Map.unmodifiable(_counts);

  int countOf(ItemRef ref) => _counts[ref] ?? 0;

  bool has(ItemRef ref) => countOf(ref) > 0;

  Iterable<ItemRef> get refs => _counts.keys;

  /// Adds one. False only when a **new kind** would overflow the pack;
  /// adding to a stack that is already there always works.
  bool add(ItemRef ref, [int amount = 1]) {
    if (amount <= 0) return false;
    if (!_counts.containsKey(ref) && isFull) return false;
    _counts[ref] = countOf(ref) + amount;
    return true;
  }

  /// Removes one. False when there is none, and nothing changes.
  bool remove(ItemRef ref, [int amount = 1]) {
    final held = countOf(ref);
    if (amount <= 0 || held < amount) return false;
    if (held == amount) {
      _counts.remove(ref);
    } else {
      _counts[ref] = held - amount;
    }
    return true;
  }
}
