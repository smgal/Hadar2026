/// Optional Hadar-specific event extension carried in the JSON map's
/// `events[].hadarEvent` field. Parsed alongside the legacy RPG Maker
/// `pages[].list` so RPG Maker JSON stays compatible.
///
/// `kind` values:
/// - `"talk"` / `"sign"`: payload is ignored — the legacy `dialogLines`
///   already cover dialogue.
/// - `"warp"`: payload `{ "map": String, "x": int, "y": int }` —
///   teleports the party to (x, y) on the named map.
/// - `"oneshot"`: payload `{ "flag": int }` — fires once, then sets the
///   flag so subsequent visits skip the event.
class HadarEvent {
  final String kind;
  final Map<String, dynamic> payload;

  const HadarEvent({required this.kind, required this.payload});

  factory HadarEvent.fromJson(Map<String, dynamic> json) {
    return HadarEvent(
      kind: (json['kind'] as String?) ?? '',
      payload: (json['payload'] is Map<String, dynamic>)
          ? json['payload'] as Map<String, dynamic>
          : const {},
    );
  }
}

class MapEvent {
  final int id;
  final String name;
  final String note;
  final int x;
  final int y;
  List<String> dialogLines = [];
  HadarEvent? hadarEvent;

  // parsed type
  final String type; // e.g., "TALK", "ENTER", "EVENT"

  MapEvent({
    required this.id,
    required this.name,
    required this.note,
    required this.x,
    required this.y,
    List<String>? dialogLines,
    this.hadarEvent,
  }) : type = _parseTypeString(name) {
    if (dialogLines != null) {
      this.dialogLines = dialogLines;
    }
  }

  static String _parseTypeString(String name) {
    if (name.startsWith("TALK")) return "TALK";
    if (name.startsWith("ENTER")) return "ENTER";
    if (name.startsWith("EVENT") || name.startsWith("EVT")) return "EVENT";
    if (name.startsWith("NPC")) return "NPC";
    if (name.startsWith("SIGN")) return "SIGN";
    return "UNKNOWN";
  }

  factory MapEvent.fromJson(Map<String, dynamic> json) {
    final ev = MapEvent(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      note: json['note'] ?? '',
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      hadarEvent: json['hadarEvent'] is Map<String, dynamic>
          ? HadarEvent.fromJson(json['hadarEvent'] as Map<String, dynamic>)
          : null,
    );

    if (json['pages'] != null && (json['pages'] as List).isNotEmpty) {
      var page = json['pages'][0];
      if (page['list'] != null) {
        for (var item in page['list']) {
          if (item['code'] == 401 && item['parameters'] != null) {
            for (var param in item['parameters']) {
              if (param is String) {
                ev.dialogLines.add(param);
              }
            }
          }
        }
      }
    }

    return ev;
  }
}
