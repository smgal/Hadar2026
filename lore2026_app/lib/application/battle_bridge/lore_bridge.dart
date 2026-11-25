import 'package:lore_battle/lore_battle.dart' as lb;
import 'package:lore_battle_text/lore_battle_text.dart' as bt;
import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;

/// 두 세계 사이의 다리 — `lore_world`(인물·소지품)와 `lore_battle`(전투).
///
/// 두 패키지는 서로를 모른다. 같은 낱말(계열 · 무기 계통 · 물품 키)을 쓰기로
/// 했을 뿐이고, 그 낱말을 이쪽에서 저쪽으로 옮기는 것이 이 파일의 일이다.
///
/// * 들어갈 때 — [snapshotOf] 가 대원 한 명을 전투가 읽는 꼴로 푼다.
///   파생값(최대 HP · 방어력 · 무기 공격력)은 여기서 **이미 계산된 값**으로
///   넘어간다. 전투는 장비 칸도 아이템 표도 모른다.
/// * 나올 때 — [settlementOf] 가 전투의 정산을 세계의 정산 명령으로 바꾼다.
abstract final class LoreBridge {
  /// 전투 중에 쓸 수 있는 물품 · 크리스탈의 키.
  static Iterable<String> get battleItemKeys => lb.battleItems.keys;

  static lb.Family _family(Family f) => lb.Family.values.byName(f.name);
  static lb.WeaponKind _kind(WeaponKind k) => lb.WeaponKind.values.byName(k.name);
  static Family _familyBack(lb.Family f) => Family.values.byName(f.name);

  /// 들고 있는 무기가 **어떻게 닿는지** — 전투 무기 표의 키.
  ///
  /// 얼마나 센지는 [Member.weaponPower] 가 따로 넘어간다. 규격 문서
  /// (`packages/lore_battle/CONTRACT.md` §6)가 권하는 대응을 따른다.
  static String weaponKeyOf(Member m) {
    final natural = m.naturalWeapon;
    if (natural != null) return _naturalKeys[natural] ?? _itemKey(natural, m);
    final w = m.weapon;
    if (w == null || m.weaponKind == WeaponKind.bare) return 'unarmed';
    return _itemKey(w, m);
  }

  static String _itemKey(String item, Member m) {
    final key = _weaponKeys[item];
    if (key == null) return lb.defaultWeaponKeyFor(_kind(m.weaponKind));
    // 한손 베는 무기에 방패를 들면 자세가 달라진다.
    if (key == 'one_hand_slash' && m.shield != null && m.shieldPower > 0) {
      return 'sword_shield';
    }
    return key;
  }

  static const Map<String, String> _weaponKeys = {
    'weapon.short_sword': 'one_hand_slash',
    'weapon.gladius': 'one_hand_slash',
    'weapon.sabre': 'one_hand_slash',
    'weapon.scimitar': 'one_hand_slash',
    'weapon.falchion': 'one_hand_slash',
    'weapon.long_sword': 'long_sword',
    'weapon.flamberge': 'great_sword',
    'weapon.flame_sword': 'flame_sword',
    'weapon.club': 'club',
    'weapon.hand_axe': 'axe',
    'weapon.flail': 'mace',
    'weapon.mace': 'mace',
    'weapon.war_hammer': 'war_hammer',
    'weapon.battle_axe': 'battle_axe',
    'weapon.halberd': 'poleaxe',
    'weapon.dagger': 'dagger',
    'weapon.rapier': 'rapier',
    'weapon.short_spear': 'spear',
    'weapon.spear': 'spear',
    'weapon.trident': 'trident',
    'weapon.lance': 'lance',
    'weapon.lancer': 'lance',
    'weapon.poleaxe': 'halberd',
    'weapon.blowpipe': 'blowpipe',
    'weapon.shuriken': 'thrown',
    'weapon.javelin': 'thrown',
    'weapon.sling': 'sling',
    'weapon.bow': 'bow',
    'weapon.crossbow': 'crossbow',
    'weapon.arbalest': 'arbalest',
  };

  /// 보조 일원의 타고난 무기. 원소는 원소대로, 몸은 몸대로.
  static const Map<String, String> _naturalKeys = {
    'natural.flame': 'natural_fire',
    'natural.tidal_wave': 'natural_force',
    'natural.storm': 'natural_force',
    'natural.earthquake': 'natural_force',
    'natural.fangs': 'natural_pierce',
    'natural.tentacles': 'natural_blunt',
    'natural.claws': 'natural_slash',
    'natural.rock': 'natural_hurl',
    'natural.bone': 'natural_blunt',
    'natural.lightning': 'natural_lightning',
    'natural.clay': 'natural_blunt',
    'natural.bare_hands': 'natural_blunt',
    'natural.iron_fist': 'natural_blunt',
    'natural.attack': 'natural_slash',
    'breath.fire': 'natural_fire',
    'breath.cold': 'natural_ice',
    'breath.frost': 'natural_ice',
    'breath.lightning': 'natural_lightning',
    'breath.acid': 'natural_poison',
    'breath.poison': 'natural_poison',
    'breath.chlorine': 'natural_poison',
  };

  /// 대원 한 명 → 전투 참가자.
  static lb.CombatantSnapshot snapshotOf(
    Member m,
    int seat, {
    required Episode episode,
  }) {
    final natural = m.naturalWeapon;
    return lb.CombatantSnapshot(
      slot: seat,
      name: wt.memberName(m, episode: episode),
      nameKey: m.nameKey ?? '',
      family: _family(m.family),
      classId: m.classId,
      level: m.level,
      strength: m.strength,
      mentality: m.mentality,
      concentration: m.concentration,
      endurance: m.endurance,
      resistance: m.resistance,
      agility: m.agility,
      accuracy: m.accuracy,
      luck: m.luck,
      skills: List<int>.of(m.skills),
      hp: m.hp,
      maxHp: m.maxHp,
      mp: m.mp,
      maxMp: m.maxMp,
      ac: m.ac,
      weaponPower: m.weaponPower,
      weaponKind: _kind(m.weaponKind),
      shieldPower: m.shieldPower,
      poison: m.poison,
      unconscious: m.unconscious,
      dead: m.dead,
      weaponKey: weaponKeyOf(m),
      weaponName: wt.weaponNameOf(m),
      weaponNameKey: natural ?? '',
      attacksAll: m.attackMode == AttackMode.all,
      immuneToMindControl: m.mindControlImmune,
    );
  }

  /// 일행 전체를 전투의 개시 입력으로.
  static lb.BattleSetup setupOf(
    LoreWorld world, {
    required List<String> enemyKeys,
    required Map<int, lb.EnemyOverride> overrides,
    required int seed,
    bool canEscape = true,
    bool enemyActsFirst = false,
    int mode = 0,
  }) {
    return lb.BattleSetup(
      party: [
        for (final seat in world.presentSeats)
          snapshotOf(world.seats[seat]!, seat, episode: world.episode),
      ],
      enemyKeys: enemyKeys,
      seed: seed,
      episode: world.episode.number,
      mode: mode,
      consumables: {
        for (final key in battleItemKeys)
          if (world.countOf(key) > 0) key: world.countOf(key),
      },
      arrows: world.arrows,
      enemyOverrides: overrides,
      canEscape: canEscape,
      enemyActsFirst: enemyActsFirst,
      attackUnconscious: world.options.attackUnconscious,
    );
  }

  /// 전투가 앉힌 보조 일원(소환 · 설득) → 세계의 대원.
  static Member memberFromSnapshot(lb.CombatantSnapshot s) {
    final natural = s.weaponNameKey.isEmpty ? null : s.weaponNameKey;
    final m = Member(
      // 소환수는 이름표 키로 두고(세계의 글이 푼다), 설득한 적은 전투 쪽
      // 이름표에만 있으므로 지금 풀어 둔다.
      name: s.name.isNotEmpty
          ? s.name
          : (s.nameKey.startsWith('summon.') ? '' : bt.resolveNameKey(s.nameKey)),
      nameKey: s.nameKey.isEmpty ? null : s.nameKey,
      gender: Gender.neutral,
      family: _familyBack(s.family),
      classId: s.classId,
      level: s.level,
      abilities: [
        s.strength,
        s.mentality,
        s.concentration,
        s.endurance,
        s.resistance,
        s.agility,
        s.accuracy,
        s.luck,
      ],
      skills: List<int>.of(s.skills),
      baseAc: s.ac,
      naturalWeapon: natural ?? 'natural.attack',
      naturalPower: s.weaponPower,
      attackModeOverride: s.attacksAll ? AttackMode.all : AttackMode.single,
      mindControlImmune: s.immuneToMindControl,
    );
    m
      ..hp = s.hp
      ..mp = s.mp
      ..poison = s.poison
      ..unconscious = s.unconscious
      ..dead = s.dead;
    return m;
  }

  /// 전투의 정산 → 세계의 정산 명령.
  static BattleSettlement settlementOf(lb.BattleOutcome o) => BattleSettlement(
    seats: [
      for (final c in o.combatants)
        SeatSettlement(
          c.slot,
          hp: c.hp,
          mp: c.mp,
          poison: c.poison,
          unconscious: c.unconscious,
          dead: c.dead,
          expGained: c.experienceGained,
          acLoss: c.acLoss,
        ),
    ],
    goldGained: o.goldGained,
    arrowsUsed: o.arrowsUsed,
    itemsUsed: o.consumedItems,
    newAssistant: o.newAssistant == null ? null : memberFromSnapshot(o.newAssistant!),
    assistantLost: o.departedSlots.contains(lb.assistantSeat),
  );

  /// 적 한 마리를 보조 일원으로 (`Party::SetAssistant("enemy", n)`) —
  /// 제7장 7.8 의 변환 규칙은 세계가 갖고 있다.
  static Member? assistantFromEnemyNumber(int episode, int legacyId) {
    final data = lb.enemyByLegacyId(episode, legacyId);
    if (data == null) return null;
    return assistantFromEnemy(
      EnemyStatBlock(
        nameKey: 'enemy.$episode.${data.key}',
        name: bt.enemyName(episode, data.key),
        level: data.level,
        strength: data.strength,
        mentality: data.mentality,
        endurance: data.endurance,
        agility: data.agility,
        physicalResist: data.physicalResistance,
        physicalAccuracy: data.accuracyPhysical,
        defence: data.ac,
      ),
    );
  }

  /// `Enemy::ChangeAttribute(n, "속성", 값)` 의 속성 → 덮어쓰기 한 칸.
  /// 모르는 속성이면 null.
  ///
  /// 제1·2부의 적 표는 저항이 하나뿐이라 `resistance` 가 두 저항을 함께
  /// 바꾼다.
  static lb.EnemyOverride? overrideFor(String attribute, int value, int episode) {
    return switch (attribute) {
      'level' => lb.EnemyOverride(level: value),
      'hp' => lb.EnemyOverride(hp: value),
      'strength' => lb.EnemyOverride(strength: value),
      'mentality' => lb.EnemyOverride(mentality: value),
      'endurance' => lb.EnemyOverride(endurance: value),
      'resistance' => episode == 3
          ? lb.EnemyOverride(physicalResistance: value)
          : lb.EnemyOverride(physicalResistance: value, magicResistance: value),
      'magic_resistance' => lb.EnemyOverride(magicResistance: value),
      'agility' => lb.EnemyOverride(agility: value),
      'accuracy' => lb.EnemyOverride(accuracyPhysical: value),
      'magic_accuracy' => lb.EnemyOverride(accuracyMagic: value),
      'ac' => lb.EnemyOverride(ac: value),
      'special' => lb.EnemyOverride(special: lb.EnemySpecial.fromWire(value)),
      'cast_level' => lb.EnemyOverride(castLevel: value.clamp(0, 6)),
      _ => null,
    };
  }
}
