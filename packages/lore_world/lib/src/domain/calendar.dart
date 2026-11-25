import 'enums.dart';

/// 로어 달력(제11장 11.4). 1년 = 12개월 × 30일 = 360일.
///
/// 시계는 주입된다 — 이 패키지는 기계의 시각을 읽지 않는다. 걸음과 휴식과
/// 훈련이 시간을 민다.
class LoreCalendar {
  LoreCalendar({
    required this.year,
    this.month = 1,
    this.day = 1,
    this.hour = 0,
    this.minute = 0,
    this.second = 0,
  });

  /// 편마다 정해진 시작 시각.
  factory LoreCalendar.startOf(Episode episode) => switch (episode) {
    // 771년 3월 1일 09:00 — 원작에 달력이 없어 임의로 정한 값(1st/07 7.4).
    Episode.ep1 => LoreCalendar(year: 771, month: 3, day: 1, hour: 9),
    // 774년 1월 19일 10:10.
    Episode.ep2 => LoreCalendar(
      year: 774,
      month: 1,
      day: 19,
      hour: 10,
      minute: 10,
    ),
    // 673년 11월 27일 16:00.
    Episode.ep3 => LoreCalendar(year: 673, month: 11, day: 27, hour: 16),
  };

  int year;

  /// 1~12.
  int month;

  /// 1~30.
  int day;
  int hour;
  int minute;
  int second;

  static const int daysPerMonth = 30;
  static const int monthsPerYear = 12;
  static const int daysPerYear = daysPerMonth * monthsPerYear;
  static const int _secondsPerDay = 24 * 60 * 60;

  /// 그 해의 몇째 날인가(0~359). 저장 모델의 「일」.
  int get dayOfYear => (month - 1) * daysPerMonth + (day - 1);

  /// 0년 1월 1일 0시부터 센 초. 두 시각을 견주는 데만 쓴다.
  int get totalSeconds =>
      ((year * daysPerYear + dayOfYear) * 24 + hour) * 3600 +
      minute * 60 +
      second;

  /// 낮(7:00~17:59)인가.
  bool get isDaytime => hour >= 7 && hour < 18;

  /// 달이 뜨는 날(매달 10~20일)인가.
  bool get moonIsUp => day >= 10 && day <= 20;

  /// 시간을 민다. 음수는 무시한다.
  void advance({
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
  }) {
    final delta = days * _secondsPerDay + hours * 3600 + minutes * 60 + seconds;
    if (delta <= 0) return;
    _setFromTotal(totalSeconds + delta);
  }

  /// 다른 시각으로 맞춘다.
  void setTo(LoreCalendar other) => _setFromTotal(other.totalSeconds);

  void _setFromTotal(int total) {
    var t = total < 0 ? 0 : total;
    second = t % 60;
    t ~/= 60;
    minute = t % 60;
    t ~/= 60;
    hour = t % 24;
    t ~/= 24;
    final doy = t % daysPerYear;
    year = t ~/ daysPerYear;
    month = doy ~/ daysPerMonth + 1;
    day = doy % daysPerMonth + 1;
  }

  bool isAfter(LoreCalendar other) => totalSeconds > other.totalSeconds;

  LoreCalendar copy() => LoreCalendar(
    year: year,
    month: month,
    day: day,
    hour: hour,
    minute: minute,
    second: second,
  );

  Map<String, Object?> toJson() => {
    'year': year,
    'month': month,
    'day': day,
    'hour': hour,
    'minute': minute,
    'second': second,
  };

  factory LoreCalendar.fromJson(Map<String, Object?> json) {
    int n(String key, int fallback) {
      final v = json[key];
      return v is num ? v.toInt() : fallback;
    }

    final c = LoreCalendar(
      year: n('year', 0),
      month: n('month', 1).clamp(1, monthsPerYear),
      day: n('day', 1).clamp(1, daysPerMonth),
      hour: n('hour', 0).clamp(0, 23),
      minute: n('minute', 0).clamp(0, 59),
      second: n('second', 0).clamp(0, 59),
    );
    return c;
  }

  @override
  String toString() =>
      '$year-$month-$day ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}

/// 일행 공용 효과(부록 B.1). 0 이면 없는 것이다.
class FieldBuffs {
  FieldBuffs({
    this.levitation = 0,
    this.waterWalk = 0,
    this.swampWalk = 0,
    this.mindReadSteps = 0,
  });

  /// 마법·비행 부츠가 켤 때 넣는 값. 다음 휴식까지 간다.
  static const int full = 255;

  /// 필드 독심이 가는 걸음 수.
  static const int mindReadDuration = 3;

  int levitation;
  int waterWalk;

  /// 늪을 걸을 때마다 1 씩 준다.
  int swampWalk;

  /// 독심이 남은 걸음(0~3).
  int mindReadSteps;

  bool get canLevitate => levitation > 0;
  bool get canWalkOnWater => waterWalk > 0;
  bool get canWalkOnSwamp => swampWalk > 0;
  bool get isMindReading => mindReadSteps > 0;

  bool has(FieldBuff buff) => switch (buff) {
    FieldBuff.levitation => canLevitate,
    FieldBuff.waterWalk => canWalkOnWater,
    FieldBuff.swampWalk => canWalkOnSwamp,
  };

  void grant(FieldBuff buff) {
    switch (buff) {
      case FieldBuff.levitation:
        levitation = full;
      case FieldBuff.waterWalk:
        waterWalk = full;
      case FieldBuff.swampWalk:
        swampWalk = full;
    }
  }

  /// 휴식이 지우는 셋. 독심은 걸음으로만 준다.
  void expireOnRest() {
    levitation = 0;
    waterWalk = 0;
    swampWalk = 0;
  }

  Map<String, Object?> toJson() => {
    'levitation': levitation,
    'waterWalk': waterWalk,
    'swampWalk': swampWalk,
    'mindReadSteps': mindReadSteps,
  };

  factory FieldBuffs.fromJson(Map<String, Object?> json) {
    int n(String key) {
      final v = json[key];
      return v is num ? v.toInt().clamp(0, full) : 0;
    }

    return FieldBuffs(
      levitation: n('levitation'),
      waterWalk: n('waterWalk'),
      swampWalk: n('swampWalk'),
      mindReadSteps: n('mindReadSteps').clamp(0, mindReadDuration),
    );
  }
}

/// 게임 선택 상황(제11장 11.9). 원작과 달리 **전부 저장한다.**
class GameOptions {
  GameOptions({
    this.encounterTendency = 2,
    this.maxEnemies = 5,
    this.attackUnconscious = true,
    this.restHours = 6,
  });

  /// 전투 성향 1~5. 1 이 가장 잦고 5 가 가장 드물다.
  int encounterTendency;

  /// 한 번에 나오는 적의 최대치 3~8.
  int maxEnemies;

  /// 의식불명인 적까지 공격하는가.
  bool attackUnconscious;

  /// 마지막으로 고른 휴식 시간(1~24).
  int restHours;

  Map<String, Object?> toJson() => {
    'encounterTendency': encounterTendency,
    'maxEnemies': maxEnemies,
    'attackUnconscious': attackUnconscious,
    'restHours': restHours,
  };

  factory GameOptions.fromJson(Map<String, Object?> json) {
    int n(String key, int fallback, int lo, int hi) {
      final v = json[key];
      return (v is num ? v.toInt() : fallback).clamp(lo, hi);
    }

    return GameOptions(
      encounterTendency: n('encounterTendency', 2, 1, 5),
      maxEnemies: n('maxEnemies', 5, 3, 8),
      attackUnconscious: json['attackUnconscious'] != false,
      restHours: n('restHours', 6, 1, 24),
    );
  }
}
