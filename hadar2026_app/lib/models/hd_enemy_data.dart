class HDEnemyData {
  final int id;
  final String name;
  final int strength;
  final int mentality;
  final int endurance;
  final int resistance;
  final int agility;
  final List<int> accuracy;
  final int ac;
  final int special;
  final int castLevel;
  final int specialCastLevel;
  final int level;

  const HDEnemyData({
    required this.id,
    required this.name,
    required this.strength,
    required this.mentality,
    required this.endurance,
    required this.resistance,
    required this.agility,
    required this.accuracy,
    required this.ac,
    required this.special,
    required this.castLevel,
    required this.specialCastLevel,
    required this.level,
  });
}

const List<HDEnemyData> enemyTable = [
  HDEnemyData(id: 0, name: 'Orc', strength: 8, mentality: 0, endurance: 8, resistance: 0, agility: 8, accuracy: [8, 0], ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 1),
  HDEnemyData(id: 1, name: 'Troll', strength: 9, mentality: 0, endurance: 6, resistance: 0, agility: 9, accuracy: [9, 0], ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 1),
  HDEnemyData(id: 2, name: 'Serpent', strength: 7, mentality: 3, endurance: 7, resistance: 0, agility: 11, accuracy: [11, 6], ac: 1, special: 1, castLevel: 1, specialCastLevel: 0, level: 1),
  HDEnemyData(id: 3, name: 'Earth Worm', strength: 3, mentality: 5, endurance: 5, resistance: 0, agility: 6, accuracy: [11, 7], ac: 1, special: 0, castLevel: 1, specialCastLevel: 0, level: 1),
  HDEnemyData(id: 4, name: 'Dwarf', strength: 10, mentality: 0, endurance: 10, resistance: 0, agility: 10, accuracy: [10, 0], ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 2),
  HDEnemyData(id: 5, name: 'Giant', strength: 15, mentality: 0, endurance: 13, resistance: 0, agility: 8, accuracy: [8, 0], ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 2),
  HDEnemyData(id: 6, name: 'Phantom', strength: 0, mentality: 12, endurance: 12, resistance: 0, agility: 0, accuracy: [0, 13], ac: 0, special: 0, castLevel: 2, specialCastLevel: 0, level: 2),
  HDEnemyData(id: 7, name: 'Wolf', strength: 7, mentality: 0, endurance: 11, resistance: 0, agility: 15, accuracy: [15, 0], ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 2),
  HDEnemyData(id: 8, name: 'Imp', strength: 8, mentality: 8, endurance: 10, resistance: 20, agility: 18, accuracy: [18, 10], ac: 2, special: 0, castLevel: 2, specialCastLevel: 0, level: 3),
  HDEnemyData(id: 9, name: 'Goblin', strength: 11, mentality: 0, endurance: 13, resistance: 0, agility: 13, accuracy: [13, 0], ac: 3, special: 0, castLevel: 0, specialCastLevel: 0, level: 3),
  HDEnemyData(id: 10, name: 'Python', strength: 9, mentality: 5, endurance: 10, resistance: 0, agility: 13, accuracy: [13, 6], ac: 1, special: 1, castLevel: 1, specialCastLevel: 0, level: 3),
  HDEnemyData(id: 11, name: 'Insects', strength: 6, mentality: 4, endurance: 8, resistance: 0, agility: 14, accuracy: [14, 15], ac: 2, special: 1, castLevel: 1, specialCastLevel: 0, level: 3),
  HDEnemyData(id: 12, name: 'Giant Spider', strength: 10, mentality: 0, endurance: 9, resistance: 0, agility: 20, accuracy: [13, 0], ac: 2, special: 1, castLevel: 0, specialCastLevel: 0, level: 4),
  HDEnemyData(id: 13, name: 'Gremlin', strength: 10, mentality: 0, endurance: 10, resistance: 0, agility: 20, accuracy: [20, 0], ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 4),
  HDEnemyData(id: 14, name: 'Buzz Bug', strength: 13, mentality: 0, endurance: 11, resistance: 0, agility: 15, accuracy: [15, 0], ac: 1, special: 1, castLevel: 0, specialCastLevel: 0, level: 4),
  HDEnemyData(id: 15, name: 'Salamander', strength: 12, mentality: 2, endurance: 13, resistance: 0, agility: 12, accuracy: [12, 10], ac: 3, special: 1, castLevel: 1, specialCastLevel: 0, level: 4),
  HDEnemyData(id: 16, name: 'Blood Bat', strength: 11, mentality: 0, endurance: 10, resistance: 0, agility: 5, accuracy: [15, 0], ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 5),
  HDEnemyData(id: 17, name: 'Giant Rat', strength: 13, mentality: 0, endurance: 18, resistance: 0, agility: 10, accuracy: [10, 0], ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 5),
  HDEnemyData(id: 18, name: 'Skeleton', strength: 10, mentality: 0, endurance: 19, resistance: 0, agility: 12, accuracy: [12, 0], ac: 3, special: 0, castLevel: 0, specialCastLevel: 0, level: 5),
  HDEnemyData(id: 19, name: 'Kelpie', strength: 8, mentality: 13, endurance: 8, resistance: 0, agility: 14, accuracy: [15, 17], ac: 2, special: 0, castLevel: 3, specialCastLevel: 0, level: 5),
  HDEnemyData(id: 20, name: 'Gazer', strength: 15, mentality: 8, endurance: 11, resistance: 0, agility: 20, accuracy: [15, 15], ac: 3, special: 0, castLevel: 2, specialCastLevel: 0, level: 6),
  HDEnemyData(id: 21, name: 'Ghost', strength: 0, mentality: 15, endurance: 10, resistance: 0, agility: 0, accuracy: [0, 15], ac: 0, special: 0, castLevel: 3, specialCastLevel: 0, level: 6),
  HDEnemyData(id: 22, name: 'Slime', strength: 5, mentality: 13, endurance: 5, resistance: 0, agility: 19, accuracy: [19, 19], ac: 2, special: 0, castLevel: 2, specialCastLevel: 0, level: 6),
  HDEnemyData(id: 23, name: 'Rock-Man', strength: 19, mentality: 0, endurance: 15, resistance: 0, agility: 10, accuracy: [10, 0], ac: 5, special: 0, castLevel: 0, specialCastLevel: 0, level: 6),
  HDEnemyData(id: 24, name: 'Kobold', strength: 9, mentality: 9, endurance: 9, resistance: 0, agility: 9, accuracy: [9, 9], ac: 2, special: 0, castLevel: 3, specialCastLevel: 0, level: 7),
  HDEnemyData(id: 25, name: 'Mummy', strength: 10, mentality: 10, endurance: 10, resistance: 0, agility: 10, accuracy: [10, 10], ac: 3, special: 1, castLevel: 2, specialCastLevel: 0, level: 7),
  HDEnemyData(id: 26, name: 'Devil Hunter', strength: 13, mentality: 10, endurance: 10, resistance: 0, agility: 10, accuracy: [10, 18], ac: 3, special: 2, castLevel: 2, specialCastLevel: 0, level: 7),
  HDEnemyData(id: 27, name: 'Crazy One', strength: 9, mentality: 9, endurance: 10, resistance: 0, agility: 5, accuracy: [5, 13], ac: 1, special: 0, castLevel: 3, specialCastLevel: 0, level: 7),
  HDEnemyData(id: 28, name: 'Ogre', strength: 19, mentality: 0, endurance: 19, resistance: 0, agility: 9, accuracy: [12, 0], ac: 4, special: 0, castLevel: 0, specialCastLevel: 0, level: 8),
  HDEnemyData(id: 29, name: 'Headless', strength: 10, mentality: 0, endurance: 15, resistance: 0, agility: 10, accuracy: [10, 0], ac: 3, special: 2, castLevel: 0, specialCastLevel: 0, level: 8),
  HDEnemyData(id: 30, name: 'Mud-Man', strength: 10, mentality: 0, endurance: 15, resistance: 0, agility: 10, accuracy: [10, 0], ac: 7, special: 0, castLevel: 0, specialCastLevel: 0, level: 8),
  HDEnemyData(id: 31, name: 'Hell Cat', strength: 10, mentality: 15, endurance: 11, resistance: 0, agility: 18, accuracy: [18, 16], ac: 2, special: 2, castLevel: 3, specialCastLevel: 0, level: 8),
  HDEnemyData(id: 32, name: 'Wisp', strength: 5, mentality: 16, endurance: 10, resistance: 0, agility: 20, accuracy: [20, 20], ac: 2, special: 0, castLevel: 4, specialCastLevel: 0, level: 9),
  HDEnemyData(id: 33, name: 'Basilisk', strength: 10, mentality: 15, endurance: 12, resistance: 0, agility: 20, accuracy: [20, 10], ac: 2, special: 1, castLevel: 2, specialCastLevel: 0, level: 9),
  HDEnemyData(id: 34, name: 'Sprite', strength: 0, mentality: 20, endurance: 2, resistance: 80, agility: 20, accuracy: [20, 20], ac: 0, special: 3, castLevel: 5, specialCastLevel: 0, level: 9),
  HDEnemyData(id: 35, name: 'Vampire', strength: 15, mentality: 13, endurance: 14, resistance: 20, agility: 17, accuracy: [17, 15], ac: 3, special: 1, castLevel: 2, specialCastLevel: 0, level: 9),
  HDEnemyData(id: 36, name: 'Molten Monster', strength: 8, mentality: 0, endurance: 20, resistance: 50, agility: 8, accuracy: [16, 0], ac: 3, special: 0, castLevel: 0, specialCastLevel: 0, level: 10),
  HDEnemyData(id: 37, name: 'Great Lich', strength: 10, mentality: 10, endurance: 11, resistance: 10, agility: 18, accuracy: [10, 10], ac: 4, special: 2, castLevel: 3, specialCastLevel: 0, level: 10),
  HDEnemyData(id: 38, name: 'Rampager', strength: 20, mentality: 0, endurance: 19, resistance: 0, agility: 19, accuracy: [19, 0], ac: 3, special: 0, castLevel: 0, specialCastLevel: 0, level: 10),
  HDEnemyData(id: 39, name: 'Mutant', strength: 0, mentality: 10, endurance: 15, resistance: 0, agility: 0, accuracy: [0, 20], ac: 3, special: 0, castLevel: 3, specialCastLevel: 0, level: 10),
  HDEnemyData(id: 40, name: 'Rotten Corpse', strength: 15, mentality: 15, endurance: 15, resistance: 60, agility: 15, accuracy: [15, 15], ac: 2, special: 2, castLevel: 3, specialCastLevel: 0, level: 11),
  HDEnemyData(id: 41, name: 'Gagoyle', strength: 10, mentality: 0, endurance: 20, resistance: 10, agility: 10, accuracy: [10, 0], ac: 6, special: 0, castLevel: 0, specialCastLevel: 0, level: 11),
  HDEnemyData(id: 42, name: 'Wivern', strength: 10, mentality: 10, endurance: 9, resistance: 30, agility: 20, accuracy: [20, 9], ac: 3, special: 2, castLevel: 3, specialCastLevel: 0, level: 11),
  HDEnemyData(id: 43, name: 'Grim Death', strength: 16, mentality: 16, endurance: 16, resistance: 50, agility: 16, accuracy: [16, 16], ac: 2, special: 2, castLevel: 3, specialCastLevel: 0, level: 12),
  HDEnemyData(id: 44, name: 'Griffin', strength: 15, mentality: 15, endurance: 15, resistance: 0, agility: 15, accuracy: [14, 14], ac: 3, special: 2, castLevel: 3, specialCastLevel: 0, level: 12),
  HDEnemyData(id: 45, name: 'Evil Soul', strength: 0, mentality: 20, endurance: 10, resistance: 0, agility: 0, accuracy: [0, 15], ac: 0, special: 3, castLevel: 4, specialCastLevel: 0, level: 12),
  HDEnemyData(id: 46, name: 'Cyclops', strength: 20, mentality: 0, endurance: 20, resistance: 10, agility: 20, accuracy: [20, 0], ac: 4, special: 0, castLevel: 0, specialCastLevel: 0, level: 13),
  HDEnemyData(id: 47, name: 'Dancing-Swd', strength: 15, mentality: 20, endurance: 6, resistance: 20, agility: 20, accuracy: [20, 20], ac: 0, special: 2, castLevel: 4, specialCastLevel: 0, level: 13),
  HDEnemyData(id: 48, name: 'Hydra', strength: 15, mentality: 10, endurance: 20, resistance: 40, agility: 18, accuracy: [18, 12], ac: 8, special: 1, castLevel: 3, specialCastLevel: 0, level: 13),
  HDEnemyData(id: 49, name: 'Stheno', strength: 20, mentality: 20, endurance: 20, resistance: 255, agility: 10, accuracy: [10, 10], ac: 255, special: 1, castLevel: 3, specialCastLevel: 0, level: 14),
  HDEnemyData(id: 50, name: 'Euryale', strength: 20, mentality: 20, endurance: 15, resistance: 255, agility: 10, accuracy: [15, 10], ac: 255, special: 2, castLevel: 3, specialCastLevel: 0, level: 14),
  HDEnemyData(id: 51, name: 'Medusa', strength: 15, mentality: 10, endurance: 16, resistance: 50, agility: 15, accuracy: [15, 10], ac: 4, special: 3, castLevel: 3, specialCastLevel: 0, level: 14),
  HDEnemyData(id: 52, name: 'Minotaur', strength: 15, mentality: 7, endurance: 20, resistance: 40, agility: 20, accuracy: [20, 15], ac: 10, special: 0, castLevel: 3, specialCastLevel: 0, level: 15),
  HDEnemyData(id: 53, name: 'Dragon', strength: 15, mentality: 7, endurance: 20, resistance: 50, agility: 18, accuracy: [20, 15], ac: 9, special: 2, castLevel: 4, specialCastLevel: 0, level: 15),
  HDEnemyData(id: 54, name: 'Dark Soul', strength: 0, mentality: 20, endurance: 40, resistance: 60, agility: 0, accuracy: [0, 20], ac: 0, special: 0, castLevel: 5, specialCastLevel: 0, level: 15),
  HDEnemyData(id: 55, name: 'Hell Fire', strength: 15, mentality: 20, endurance: 30, resistance: 30, agility: 15, accuracy: [15, 15], ac: 0, special: 3, castLevel: 5, specialCastLevel: 0, level: 16),
  HDEnemyData(id: 56, name: 'Astral Mud', strength: 13, mentality: 20, endurance: 25, resistance: 40, agility: 19, accuracy: [19, 10], ac: 9, special: 3, castLevel: 4, specialCastLevel: 0, level: 16),
  HDEnemyData(id: 57, name: 'Reaper', strength: 15, mentality: 20, endurance: 33, resistance: 70, agility: 20, accuracy: [20, 20], ac: 5, special: 1, castLevel: 3, specialCastLevel: 0, level: 17),
  HDEnemyData(id: 58, name: 'Crab God', strength: 20, mentality: 20, endurance: 30, resistance: 20, agility: 18, accuracy: [18, 19], ac: 7, special: 2, castLevel: 4, specialCastLevel: 0, level: 17),
  HDEnemyData(id: 59, name: 'Wraith', strength: 0, mentality: 24, endurance: 35, resistance: 50, agility: 15, accuracy: [0, 20], ac: 2, special: 3, castLevel: 4, specialCastLevel: 0, level: 18),
  HDEnemyData(id: 60, name: 'Death Skull', strength: 0, mentality: 20, endurance: 40, resistance: 80, agility: 0, accuracy: [0, 20], ac: 0, special: 2, castLevel: 5, specialCastLevel: 0, level: 18),
  HDEnemyData(id: 61, name: 'Draconian', strength: 30, mentality: 20, endurance: 30, resistance: 60, agility: 18, accuracy: [18, 18], ac: 7, special: 2, castLevel: 5, specialCastLevel: 1, level: 19),
  HDEnemyData(id: 62, name: 'Death Knight', strength: 35, mentality: 0, endurance: 35, resistance: 50, agility: 20, accuracy: [20, 0], ac: 6, special: 3, castLevel: 0, specialCastLevel: 1, level: 19),
  HDEnemyData(id: 63, name: 'Guardian-Lft', strength: 25, mentality: 0, endurance: 40, resistance: 70, agility: 20, accuracy: [18, 0], ac: 5, special: 2, castLevel: 0, specialCastLevel: 0, level: 20),
  HDEnemyData(id: 64, name: 'Guardian-Rgt', strength: 25, mentality: 0, endurance: 40, resistance: 40, agility: 20, accuracy: [20, 0], ac: 7, special: 2, castLevel: 0, specialCastLevel: 0, level: 20),
  HDEnemyData(id: 65, name: 'Mega-Robo', strength: 40, mentality: 0, endurance: 50, resistance: 0, agility: 19, accuracy: [19, 0], ac: 10, special: 0, castLevel: 0, specialCastLevel: 0, level: 21),
  HDEnemyData(id: 66, name: 'Ancient Evil', strength: 0, mentality: 20, endurance: 60, resistance: 100, agility: 18, accuracy: [0, 20], ac: 5, special: 0, castLevel: 6, specialCastLevel: 2, level: 22),
  HDEnemyData(id: 67, name: 'Lord Ahn', strength: 40, mentality: 20, endurance: 60, resistance: 100, agility: 35, accuracy: [20, 20], ac: 10, special: 3, castLevel: 5, specialCastLevel: 3, level: 23),
  HDEnemyData(id: 68, name: 'Frost Dragon', strength: 15, mentality: 7, endurance: 20, resistance: 50, agility: 18, accuracy: [20, 15], ac: 9, special: 2, castLevel: 4, specialCastLevel: 0, level: 24),
  HDEnemyData(id: 69, name: 'ArchiDraconian', strength: 30, mentality: 20, endurance: 30, resistance: 60, agility: 18, accuracy: [18, 18], ac: 7, special: 2, castLevel: 5, specialCastLevel: 1, level: 25),
  HDEnemyData(id: 70, name: 'Panzer Viper', strength: 35, mentality: 0, endurance: 40, resistance: 80, agility: 20, accuracy: [20, 0], ac: 9, special: 1, castLevel: 0, specialCastLevel: 0, level: 26),
  HDEnemyData(id: 71, name: 'Black Knight', strength: 35, mentality: 0, endurance: 35, resistance: 50, agility: 20, accuracy: [20, 0], ac: 6, special: 3, castLevel: 0, specialCastLevel: 1, level: 27),
  HDEnemyData(id: 72, name: 'ArchiMonk', strength: 20, mentality: 0, endurance: 50, resistance: 70, agility: 20, accuracy: [20, 0], ac: 5, special: 0, castLevel: 0, specialCastLevel: 0, level: 28),
  HDEnemyData(id: 73, name: 'ArchiMage', strength: 10, mentality: 19, endurance: 30, resistance: 70, agility: 10, accuracy: [10, 19], ac: 4, special: 0, castLevel: 6, specialCastLevel: 0, level: 29),
  HDEnemyData(id: 74, name: 'Neo-Necromancer', strength: 40, mentality: 20, endurance: 60, resistance: 100, agility: 30, accuracy: [20, 20], ac: 10, special: 3, castLevel: 6, specialCastLevel: 3, level: 30),
];
