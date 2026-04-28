class MapEvent {
  final int id;
  final String name;
  final String note;
  final int x;
  final int y;
  List<String> dialogLines = [];

  // parsed type
  final String type; // e.g., "TALK", "ENTER", "EVENT"

  MapEvent({
    required this.id,
    required this.name,
    required this.note,
    required this.x,
    required this.y,
    List<String>? dialogLines,
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
