import 'package:flutter/foundation.dart';
import 'hd_player.dart';

class HDParty extends ChangeNotifier {
  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  int x = 0;
  int y = 0;
  int faced = 0; // 0: Down, 1: Up, 2: Right, 3: Left
  int maxEnemy = 3;
  int encounter = 3;

  int food = 100;
  int gold = 500;

  int year = 1;
  int month = 1;
  int day = 1;
  int hour = 12;
  int min = 0;
  int sec = 0;

  int magicTorch = 0;
  int levitation = 0;
  int walkOnWater = 0;
  int walkOnSwamp = 0;
  int mindControl = 0;
  int penetration = 0;
  bool canUseEsp = false;
  bool canUseSpecialMagic = false;
  bool isMoving = false; // Flag to track if the party is currently moving between tiles

  final List<HDPlayer> players = List.generate(6, (index) {
    var p = HDPlayer()..order = index;
    if (index == 0) {
      p.name = "슴갈";
      p.characterClass = 0; // Esper
      p.strength = 18;
      p.agility = 12;
      p.endurance = 15;
      p.hp = 150;
      p.maxHp = 150;
      p.sp = 50;
      p.maxSp = 50;
      p.esp = 20;
      p.maxEsp = 20;
      p.level[0] = 1;
      p.accuracy[0] = 15;

      p.weapon = 1; // Short Sword
      p.powOfWeapon = 12;
      p.armor = 1; // Leather Armor
      p.powOfArmor = 5;
      p.ac = 5;
    } else if (index == 1) {
      p.name = "유리";
      p.gender = 1;
      p.characterClass = 2; // Psychic
      p.strength = 10;
      p.agility = 15;
      p.endurance = 10;
      p.hp = 100;
      p.maxHp = 100;
      p.sp = 100;
      p.maxSp = 100;
      p.esp = 80;
      p.maxEsp = 80;
      p.level[0] = 1;
      p.level[2] = 1; // ESP level
      p.accuracy[0] = 10;

      p.weapon = 1;
      p.powOfWeapon = 8;
      p.armor = 1;
      p.powOfArmor = 3;
      p.ac = 3;
    }
    return p;
  });
  int xPrev = 0;
  int yPrev = 0;

  void setPosition(int newX, int newY) {
    xPrev = x;
    yPrev = y;
    x = newX;
    y = newY;
    notifyListeners();
  }

  void move(int dx, int dy) {
    xPrev = x;
    yPrev = y;
    x += dx;
    y += dy;

    // Update facing
    if (dy > 0) {
      faced = 0; // Down
    } else if (dy < 0) {
      faced = 1; // Up
    } else if (dx > 0) {
      faced = 2; // Right
    } else if (dx < 0) {
      faced = 3; // Left
    }

    notifyListeners();
  }

  void setFace(int dx, int dy) {
    if (dy > 0) {
      faced = 0; // Down
    } else if (dy < 0) {
      faced = 1; // Up
    } else if (dx > 0) {
      faced = 2; // Right
    } else if (dx < 0) {
      faced = 3; // Left
    }
    notifyListeners();
  }

  void warpToPrev() {
    x = xPrev;
    y = yPrev;
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'faced': faced,
      'maxEnemy': maxEnemy,
      'encounter': encounter,
      'food': food,
      'gold': gold,
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'min': min,
      'sec': sec,
      'magicTorch': magicTorch,
      'levitation': levitation,
      'walkOnWater': walkOnWater,
      'walkOnSwamp': walkOnSwamp,
      'mindControl': mindControl,
      'penetration': penetration,
      'canUseEsp': canUseEsp,
      'canUseSpecialMagic': canUseSpecialMagic,
      'xPrev': xPrev,
      'yPrev': yPrev,
      'players': players.map((p) => p.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    x = json['x'] ?? 0;
    y = json['y'] ?? 0;
    faced = json['faced'] ?? 0;
    maxEnemy = json['maxEnemy'] ?? 3;
    encounter = json['encounter'] ?? 3;
    food = json['food'] ?? 100;
    gold = json['gold'] ?? 500;
    year = json['year'] ?? 1;
    month = json['month'] ?? 1;
    day = json['day'] ?? 1;
    hour = json['hour'] ?? 12;
    min = json['min'] ?? 0;
    sec = json['sec'] ?? 0;
    magicTorch = json['magicTorch'] ?? 0;
    levitation = json['levitation'] ?? 0;
    walkOnWater = json['walkOnWater'] ?? 0;
    walkOnSwamp = json['walkOnSwamp'] ?? 0;
    mindControl = json['mindControl'] ?? 0;
    penetration = json['penetration'] ?? 0;
    canUseEsp = json['canUseEsp'] ?? false;
    canUseSpecialMagic = json['canUseSpecialMagic'] ?? false;
    xPrev = json['xPrev'] ?? 0;
    yPrev = json['yPrev'] ?? 0;

    if (json['players'] != null) {
      var pList = json['players'] as List;
      for (int i = 0; i < players.length && i < pList.length; i++) {
        players[i] = HDPlayer.fromJson(pList[i]);
      }
    }

    notifyListeners();
  }

  void passTime(int h, int m, int s) {
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

    timeGoes();
  }

  void timeGoes() {
    if (mindControl > 0) mindControl--;
    if (levitation > 0) levitation--;
    if (penetration > 0) penetration--;
    if (magicTorch > 0) {
      // magicTorch doesn't seem to decrement in original TimeGoes, 
      // but maybe it should? Original ObjParty.cs didn't have it in TimeGoes.
    }

    for (var player in players) {
      if (player.isValid()) {
        if (player.poison > 0) {
          player.poison++;
          if (player.poison > 10) {
            player.poison = 1;
            player.damagedByPoison();
          }
        }
      }
    }

    notifyListeners();
  }
}
