class MapUnit {
  int ixTile;
  int ixObj0;
  int ixObj1;
  int shadow;
  int ixEvent;

  MapUnit({
    this.ixTile = 0,
    this.ixObj0 = 0,
    this.ixObj1 = 0,
    this.shadow = 0,
    this.ixEvent = 0,
  });

  factory MapUnit.fromJson(Map<String, dynamic> json) {
    return MapUnit(
      ixTile: json['ixTile'] ?? 0,
      ixObj0: json['ixObj0'] ?? 0,
      ixObj1: json['ixObj1'] ?? 0,
      shadow: json['shadow'] ?? 0,
      ixEvent: json['ixEvent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ixTile': ixTile,
      'ixObj0': ixObj0,
      'ixObj1': ixObj1,
      'shadow': shadow,
      'ixEvent': ixEvent,
    };
  }
}
