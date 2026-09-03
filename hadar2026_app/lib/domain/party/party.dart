import 'package:flutter/foundation.dart';
import '../item/item_id.dart';
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
  PartyInventory({this.capacity = defaultCapacity})
    : backpack = List<HDItemId?>.filled(capacity, null);

  int food = 100;
  int gold = 500;

  /// `ObjParty.cs:109` — `current_capacity_of_backpack = 20`.
  static const int defaultCapacity = 20;

  /// How many slots the backpack has. Final: the original serialises the
  /// value but has no way to raise it, and [backpack]'s length has to stay
  /// in step with it.
  final int capacity;

  /// Fixed-length slot array; `null` is an empty slot.
  ///
  /// A fixed array rather than a growing list because the original is one
  /// (`ObjParty.cs` `back_pack[]`) and three things depend on the slot
  /// index being stable: the equipment screen lists by index
  /// (`GameEventEquipment.cs:369-370`), taking one item must not shift the
  /// rest under the cursor, and saving it is then just a fixed-width array.
  ///
  /// The backpack is **party-wide**. The original has no per-character
  /// carrying, and six of these would not fit the 800x480 layout.
  final List<HDItemId?> backpack;

  /// Puts [id] in the first empty slot — `PutInBackpack`
  /// (`ObjParty.cs:424-439`). False when the backpack is full, in which
  /// case nothing is dropped to make room.
  bool give(HDItemId id) {
    for (var i = 0; i < backpack.length; i++) {
      if (backpack[i] == null) {
        backpack[i] = id;
        return true;
      }
    }
    return false;
  }

  /// Clears the first slot holding [id] — `RemoveFromBackpack`
  /// (`ObjParty.cs:446-461`). False if the party does not have one.
  bool take(HDItemId id) {
    for (var i = 0; i < backpack.length; i++) {
      if (backpack[i] == id) {
        backpack[i] = null;
        return true;
      }
    }
    return false;
  }

  /// Whether at least one [id] is in the backpack. The original has no
  /// such call; cm2's `Item::Has` needs it.
  bool has(HDItemId id) => backpack.contains(id);

  /// Occupied slots — `GetNumItemsInBackpack` (`ObjParty.cs:463-471`).
  int get count => backpack.where((slot) => slot != null).length;

  /// 슬롯 배열을 정수 배열로. 빈 칸은 -1.
  List<int> backpackToJson() => [for (final id in backpack) id?.wire ?? -1];

  /// v1 페이로드에는 이 키가 없다 — 그 경우 20칸이 전부 빈 채로 남는다.
  void backpackFromJson(dynamic raw) {
    for (var i = 0; i < backpack.length; i++) {
      backpack[i] = null;
    }
    if (raw is! List) return;
    for (var i = 0; i < backpack.length && i < raw.length; i++) {
      final wire = raw[i];
      if (wire is! num || wire < 0) continue;
      final id = HDItemId.tryFromWire(wire.toInt());
      if (id == null) {
        debugPrint(
          '[save] backpack slot $i holds $wire, which is not an item id — '
          'left empty',
        );
        continue;
      }
      backpack[i] = id;
    }
  }
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

  /// Backpack slots in total. See [PartyInventory.capacity].
  int get itemCapacity => _inventory.capacity;

  /// Backpack slots in use.
  int get itemCount => _inventory.count;

  /// The item in [slot], or null if that slot is empty. Throws
  /// [RangeError] for a slot outside 0..[itemCapacity]-1.
  HDItemId? itemAt(int slot) => _inventory.backpack[slot];

  /// Puts [id] in the first empty slot. False when the backpack is full —
  /// nothing is dropped and no listener is notified.
  bool give(HDItemId id) {
    if (!_inventory.give(id)) return false;
    notifyListeners();
    return true;
  }

  /// Removes one [id]. False if the party does not have one.
  bool take(HDItemId id) {
    if (!_inventory.take(id)) return false;
    notifyListeners();
    return true;
  }

  /// Whether the party carries at least one [id].
  bool has(HDItemId id) => _inventory.has(id);

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

      p.weapon = 1; // 단도 — powOfWeapon 은 여기서 유도된다
      p.armor = 1; // 가죽 갑옷
      p.powOfArmor = 5;
      p.baseAc = 5;
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
      p.armor = 1;
      p.powOfArmor = 3;
      p.baseAc = 3;
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
      // ---- v2 ----
      'backpack': _inventory.backpackToJson(),
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

    // v1 페이로드에는 'backpack' 이 없다 — 20칸이 전부 빈다.
    _inventory.backpackFromJson(json['backpack']);

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
