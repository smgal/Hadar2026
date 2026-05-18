import 'package:flutter/foundation.dart';
import 'player.dart';

class PartyPosition {
  int x = 0;
  int y = 0;
  int xPrev = 0;
  int yPrev = 0;
  int faced = 0; // 0: Down, 1: Up, 2: Right, 3: Left
  bool isMoving = false; // Flag to track if the party is currently moving between tiles
}

class PartyInventory {
  int food = 100;
  int gold = 500;
}

class PartyBuffs {
  int magicTorch = 0;
  int levitation = 0;
  int walkOnWater = 0;
  int walkOnSwamp = 0;
  int mindControl = 0;
  int penetration = 0;
  bool canUseEsp = false;
  bool canUseSpecialMagic = false;
}

class HDParty extends ChangeNotifier {
  @override
  void notifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        super.notifyListeners();
      }
    });
  }

  final PartyPosition _position = PartyPosition();
  final PartyInventory _inventory = PartyInventory();
  final PartyBuffs _buffs = PartyBuffs();

  int get x => _position.x;
  set x(int value) => _position.x = value;
  int get y => _position.y;
  set y(int value) => _position.y = value;
  int get xPrev => _position.xPrev;
  set xPrev(int value) => _position.xPrev = value;
  int get yPrev => _position.yPrev;
  set yPrev(int value) => _position.yPrev = value;
  int get faced => _position.faced;
  set faced(int value) => _position.faced = value;
  bool get isMoving => _position.isMoving;
  set isMoving(bool value) => _position.isMoving = value;

  int get food => _inventory.food;
  set food(int value) => _inventory.food = value;
  int get gold => _inventory.gold;
  set gold(int value) => _inventory.gold = value;

  int get magicTorch => _buffs.magicTorch;
  set magicTorch(int value) => _buffs.magicTorch = value;
  int get levitation => _buffs.levitation;
  set levitation(int value) => _buffs.levitation = value;
  int get walkOnWater => _buffs.walkOnWater;
  set walkOnWater(int value) => _buffs.walkOnWater = value;
  int get walkOnSwamp => _buffs.walkOnSwamp;
  set walkOnSwamp(int value) => _buffs.walkOnSwamp = value;
  int get mindControl => _buffs.mindControl;
  set mindControl(int value) => _buffs.mindControl = value;
  int get penetration => _buffs.penetration;
  set penetration(int value) => _buffs.penetration = value;
  bool get canUseEsp => _buffs.canUseEsp;
  set canUseEsp(bool value) => _buffs.canUseEsp = value;
  bool get canUseSpecialMagic => _buffs.canUseSpecialMagic;
  set canUseSpecialMagic(bool value) => _buffs.canUseSpecialMagic = value;

  int maxEnemy = 3;
  int encounter = 3;

  final List<HDPlayer> players = List.generate(6, (index) {
    var p = HDPlayer()..order = index;
    if (index == 0) {
      p.name = "슴갈";
      p.characterClass = 0; // Esper
      p.strength = 18;
      p.agility = 12;
      p.endurance = 15;
      p.mentality = 20;
      p.concentration = 20;
      p.hp = 150;
      p.maxHp = 150;
      p.sp = 100;
      p.maxSp = 100;
      p.esp = 100;
      p.maxEsp = 100;
      p.level.physical = 1;
      p.level.magic = 20;
      p.level.esp = 20;
      p.accuracy.physical = 15;
      p.accuracy.magic = 15;
      p.accuracy.esp = 15;

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
      p.level.physical = 1;
      p.level.esp = 1;
      p.accuracy.physical = 10;

      p.weapon = 1;
      p.powOfWeapon = 8;
      p.armor = 1;
      p.powOfArmor = 3;
      p.ac = 3;
    }
    return p;
  });

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
