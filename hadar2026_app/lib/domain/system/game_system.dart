import 'package:flutter/foundation.dart';

class HDGameSystem extends ChangeNotifier {
  int year = 1;
  int month = 1;
  int day = 1;
  int hour = 12;
  int min = 0;
  int sec = 0;

  void passTime(int h, int m, int s, {void Function()? onTimeGoes}) {
    sec += s;
    min += m;
    hour += h;

    while (sec >= 60) {
      sec -= 60;
      min++;
    }
    while (min >= 60) {
      min -= 60;
      hour++;
    }
    while (hour >= 24) {
      hour -= 24;
      day++;
    }
    while (day >= 365) {
      day -= 365;
      year++;
    }

    if (onTimeGoes != null) {
      onTimeGoes();
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'min': min,
      'sec': sec,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    year = json['year'] ?? 1;
    month = json['month'] ?? 1;
    day = json['day'] ?? 1;
    hour = json['hour'] ?? 12;
    min = json['min'] ?? 0;
    sec = json['sec'] ?? 0;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) super.notifyListeners();
    });
  }
}
