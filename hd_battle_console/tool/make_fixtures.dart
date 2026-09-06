import 'package:hd_battle/hd_battle.dart';
import 'dart:convert';
import 'dart:io';

import 'package:hd_battle_console/fixture.dart';
import 'package:hd_battle_console/runner.dart';

/// fixture 를 **만들고 명령 열까지 기록**한다.
///
///   dart run tool/make_fixtures.dart
///
/// 규칙이 바뀌어 난수 뽑는 순서가 달라지면 기록된 명령 열이 맞지 않게 된다.
/// 그때 이 한 줄이면 전부 되살아난다 — 예전에는 fixture 마다 손으로
/// `--record` 를 다시 돌려야 했다. 방침은 `Fixture.record` 에 들어 있다.
///
/// fixture 는 두 벌이다.
///
/// | 벌 | 목적 | 파티 |
/// |---|---|---|
/// | `fixtures/original/` | 원작 조우를 그대로 | 원작 시작 파티(2인) |
/// | `fixtures/rules/` | 규칙 하나씩 시연 | **5인 기본 파티** |
///
/// 실제 게임은 5인 + 소환수인데 예전 fixture 는 17개 중 14개가 2인이었다.
/// 그 차이가 크다 — 라운드가 절반이 되고, **적의 특수 능력이 2인에서는
/// 한 번도 발동하지 않는다**(`consciousPlayers > 3`).
/// 근거는 `blueprint/_meta/GROUND_TRUTH.md` 부록 W.
///
/// 파티는 `hadar2026_app/lib/domain/party/party.dart:189-238` 의 시작 파티다.
/// 파생값은 RPG 가 넘겨줄 형태로 이미 풀어 두었다 — `ac` 는
/// `baseAc + equipmentAc`(가죽 갑옷 ac 1), `powOfWeapon` 은 단도의 10.
CombatantSnapshot seumgal({int hp = 150}) => CombatantSnapshot(
  slot: 0,
  name: '슴갈',
  characterClass: 0,
  strength: 18,
  mentality: 20,
  concentration: 20,
  endurance: 15,
  agility: 12,
  ac: 6,
  hp: hp,
  maxHp: 150,
  sp: 100,
  maxSp: 100,
  esp: 100,
  maxEsp: 100,
  accuracyPhysical: 15,
  accuracyMagic: 15,
  accuracyEsp: 15,
  levelPhysical: 1,
  levelMagic: 20,
  levelEsp: 20,
  powOfWeapon: 10,
  weaponName: '단도',
  weaponKey: 'dagger',
);

CombatantSnapshot yuri({int hp = 100}) => CombatantSnapshot(
  slot: 1,
  name: '유리',
  characterClass: 2,
  strength: 10,
  endurance: 10,
  agility: 15,
  ac: 4,
  hp: hp,
  maxHp: 100,
  sp: 100,
  maxSp: 100,
  esp: 80,
  maxEsp: 80,
  accuracyPhysical: 10,
  levelPhysical: 1,
  levelEsp: 1,
  powOfWeapon: 10,
  weaponName: '단도',
  weaponKey: 'dagger',
);

/// 죽어 있는 유리. 복합 치료가 되살릴 대상이다.
CombatantSnapshot yuriDead() {
  final b = yuri();
  return CombatantSnapshot(
    slot: b.slot,
    name: b.name,
    characterClass: b.characterClass,
    strength: b.strength,
    endurance: b.endurance,
    agility: b.agility,
    ac: b.ac,
    hp: 0,
    maxHp: b.maxHp,
    sp: b.sp,
    maxSp: b.maxSp,
    esp: b.esp,
    maxEsp: b.maxEsp,
    accuracyPhysical: b.accuracyPhysical,
    levelPhysical: b.levelPhysical,
    levelEsp: b.levelEsp,
    powOfWeapon: b.powOfWeapon,
    weaponName: b.weaponName,
    weaponKey: b.weaponKey,
    poison: 2,
    unconscious: 4,
    dead: 1,
  );
}

/// 독에 걸린 유리. `poison` 은 턴마다 깎이는 양이다.
CombatantSnapshot yuriPoisoned({int hp = 100}) {
  final base = yuri(hp: hp);
  return CombatantSnapshot(
    slot: base.slot,
    name: base.name,
    characterClass: base.characterClass,
    strength: base.strength,
    endurance: base.endurance,
    agility: base.agility,
    ac: base.ac,
    hp: base.hp,
    maxHp: base.maxHp,
    sp: base.sp,
    maxSp: base.maxSp,
    esp: base.esp,
    maxEsp: base.maxEsp,
    accuracyPhysical: base.accuracyPhysical,
    levelPhysical: base.levelPhysical,
    levelEsp: base.levelEsp,
    powOfWeapon: base.powOfWeapon,
    weaponName: base.weaponName,
    weaponKey: base.weaponKey,
    poison: 3,
  );
}

// --- 5인 기본 파티 (B5-00) ------------------------------------------
//
// 실제 게임은 5인 + 소환수다. 규칙 시연 fixture 는 전부 이 파티를 쓴다.
// 역할이 갈려야 위치·사거리·대상 선택이 뜻을 가지므로 다섯을 다르게 만들었다.
//
// | 슬롯 | 이름 | 열 | 역할 |
// |---|---|---|---|
// | 0 | 슴갈 | 1 | 주인공. 만능, 마법 레벨이 높다 |
// | 1 | 유리 | 2 | 민첩. 회피와 선제 |
// | 2 | 방패병 | 1 | 전위. 방패로 막는다 |
// | 3 | 술사 | 3 | 후위. 마법 명중이 높다 |
// | 4 | 치유사 | 3 | 후위. 치료 전담 |
//
// **열이 곧 결정이다**(B5-01). 근접 무기는 뒷열에서 아무 데도 닿지 않으니
// 때리는 사람은 앞에 서야 하고, 앞에 서면 더 맞는다. 그 저울질이
// 전투 밖 대열 화면이 존재하는 이유다.

/// 방패를 든 전위. 슬롯을 받아 어느 자리에나 세울 수 있다.
CombatantSnapshot vanguard(int slot) => CombatantSnapshot(
  slot: slot,
  rank: 1, // 전위. 앞에 서는 것이 이 사람의 일이다
  name: '방패병',
  strength: 16,
  endurance: 16,
  agility: 9,
  luck: 8,
  ac: 8,
  armour: const ArmourPieces(body: 3, head: 1, leg: 1, shieldBlock: 40),
  hp: 160,
  maxHp: 160,
  sp: 20,
  maxSp: 20,
  esp: 20,
  maxEsp: 20,
  accuracyPhysical: 15,
  levelPhysical: 2,
  powOfWeapon: 20,
  weaponName: '장검',
  weaponKey: 'long_sword',
);

/// 철퇴를 든 전위. 타격 속성과 넉백 시연용이다.
CombatantSnapshot maceBearer(int slot) => CombatantSnapshot(
  slot: slot,
  rank: 1,
  name: '철퇴병',
  strength: 18,
  endurance: 16,
  agility: 9,
  luck: 8,
  ac: 8,
  armour: const ArmourPieces(body: 3, head: 1, leg: 1, shieldBlock: 40),
  hp: 160,
  maxHp: 160,
  accuracyPhysical: 16,
  levelPhysical: 2,
  powOfWeapon: 22,
  weaponName: '철퇴',
  weaponKey: 'mace',
);

/// 기병창을 든 사람. 돌격과 최소 사거리 시연용이다.
CombatantSnapshot lancer(int slot) => CombatantSnapshot(
  slot: slot,
  rank: 2,
  name: '창기병',
  strength: 16,
  endurance: 12,
  agility: 14,
  luck: 4,
  ac: 5,
  hp: 130,
  maxHp: 130,
  accuracyPhysical: 15,
  levelPhysical: 2,
  powOfWeapon: 24,
  weaponName: '기병창',
  weaponKey: 'lance',
);

/// 후위 술사. 마법 명중이 높고 몸이 약하다.
CombatantSnapshot caster(int slot) => CombatantSnapshot(
  slot: slot,
  rank: 3, // 후위. 몸이 약해서 앞에 서면 못 버틴다
  name: '술사',
  strength: 8,
  mentality: 20,
  concentration: 18,
  endurance: 9,
  agility: 11,
  luck: 6,
  ac: 3,
  hp: 90,
  maxHp: 90,
  sp: 260,
  maxSp: 260,
  esp: 80,
  maxEsp: 80,
  accuracyPhysical: 8,
  accuracyMagic: 19,
  accuracyEsp: 14,
  levelPhysical: 1,
  levelMagic: 14,
  levelEsp: 8,
  powOfWeapon: 6,
  weaponName: '지팡이',
  weaponKey: 'staff',
);

/// 후위 치유사. 치료 마법을 전부 고를 수 있는 마법 레벨.
CombatantSnapshot healer(int slot) => CombatantSnapshot(
  slot: slot,
  rank: 3, // 후위
  name: '치유사',
  strength: 9,
  mentality: 18,
  concentration: 20,
  endurance: 11,
  agility: 10,
  luck: 10,
  ac: 4,
  hp: 110,
  maxHp: 110,
  sp: 300,
  maxSp: 300,
  esp: 60,
  maxEsp: 60,
  accuracyPhysical: 9,
  accuracyMagic: 16,
  accuracyEsp: 12,
  levelPhysical: 1,
  levelMagic: 16,
  levelEsp: 6,
  powOfWeapon: 6,
  weaponName: '지팡이',
  weaponKey: 'staff',
);

/// 레벨을 올린 5인. 겁쟁이 preset 이 도망가는 것을 보려면 레벨 차가 있어야 한다.
List<CombatantSnapshot> veteranParty() => [
  for (final c in standardParty())
    CombatantSnapshot(
      slot: c.slot,
      rank: c.rank,
      name: c.name,
      strength: c.strength + 10,
      mentality: c.mentality,
      concentration: c.concentration,
      endurance: c.endurance,
      resistance: c.resistance,
      agility: c.agility,
      luck: c.luck,
      ac: c.ac,
      armour: c.armour,
      hp: c.maxHp * 2,
      maxHp: c.maxHp * 2,
      sp: c.sp,
      maxSp: c.maxSp,
      esp: c.esp,
      maxEsp: c.maxEsp,
      accuracyPhysical: c.accuracyPhysical,
      accuracyMagic: c.accuracyMagic,
      accuracyEsp: c.accuracyEsp,
      levelPhysical: 12,
      levelMagic: c.levelMagic,
      levelEsp: c.levelEsp,
      powOfWeapon: c.powOfWeapon,
      weaponName: c.weaponName,
      weaponKey: c.weaponKey,
      preset: c.slot == 2 ? PresetKind.guardian : PresetKind.aggressive,
    ),
];

/// 규칙 시연용 5인 기본 파티.
///
/// [replace] 로 특정 슬롯만 갈아끼운다 — 독에 걸린 유리, HP 를 깎은 슴갈처럼
/// 그 규칙을 보여주는 데 필요한 상태만 바꾸고 나머지 넷은 그대로 둔다.
List<CombatantSnapshot> standardParty({
  Map<int, CombatantSnapshot> replace = const {},
}) {
  final base = <CombatantSnapshot>[
    at(seumgal(), 0, rank: 1),
    at(yuri(), 1, rank: 2),
    vanguard(2),
    caster(3),
    healer(4),
  ];
  return [for (final c in base) replace[c.slot] ?? c];
}

/// 슬롯을 옮긴 사본. 2인용으로 만든 정의를 5인 파티에 끼울 때 쓴다.
CombatantSnapshot at(CombatantSnapshot c, int slot, {int? rank}) =>
    CombatantSnapshot(
      slot: slot,
      rank: rank ?? c.rank,
      name: c.name,
      characterClass: c.characterClass,
      strength: c.strength,
      mentality: c.mentality,
      concentration: c.concentration,
      endurance: c.endurance,
      resistance: c.resistance,
      agility: c.agility,
      luck: c.luck,
      ac: c.ac,
      armour: c.armour,
      hp: c.hp,
      maxHp: c.maxHp,
      sp: c.sp,
      maxSp: c.maxSp,
      esp: c.esp,
      maxEsp: c.maxEsp,
      accuracyPhysical: c.accuracyPhysical,
      accuracyMagic: c.accuracyMagic,
      accuracyEsp: c.accuracyEsp,
      levelPhysical: c.levelPhysical,
      levelMagic: c.levelMagic,
      levelEsp: c.levelEsp,
      powOfWeapon: c.powOfWeapon,
      weaponName: c.weaponName,
      weaponKey: c.weaponKey,
      weakTo: c.weakTo,
      poison: c.poison,
      unconscious: c.unconscious,
      dead: c.dead,
    );

// --- fixture 목록 ----------------------------------------------------

Map<String, Fixture> _originalFixtures() => {
  'fixtures/original/town1_pair.json': Fixture(
    name: '마을 조우 — Giant + Wolf',
    record: 'attack',
    note:
        'menu_flows.dart:92-93 의 테스트 전투. RegisterEnemy(5)·(7) 이다.\n'
        '그 줄의 주석은 "Skeleton"·"Slime" 이라고 적혀 있는데, 테이블에서\n'
        'legacyId 5·7 은 Giant·Wolf 다 — 주석이 틀렸다.\n'
        '**원작 시작 파티(2인) 그대로다.** 규칙 시연은 fixtures/rules/ 쪽이다.',
    setup: BattleSetup(
      party: [seumgal(), yuri()],
      enemyKeys: ['giant', 'wolf'],
      seed: 20260904,
    ),
  ),
  'fixtures/original/devil_hunter_x7.json': Fixture(
    name: '원작 조우 — Devil Hunter 일곱',
    record: 'attack',
    note:
        'assets/L1_ep1d0.cm2:367-403 이 legacyId 26 을 일곱 번 등록한다.\n'
        '같은 키를 중복으로 넣는 것이 정상이다.\n'
        '**원작 시작 파티(2인)로는 전멸한다** — 그것이 원작의 난이도다.',
    setup: BattleSetup(
      party: [seumgal(), yuri()],
      enemyKeys: List.filled(7, 'devil_hunter'),
      seed: 26,
    ),
  ),
};

Map<String, Fixture> _ruleFixtures() => {
  'fixtures/rules/orc_x3.json': Fixture(
    name: '기본 승리 — Orc 셋 (5인 파티)',
    record: 'attack',
    note:
        '가장 약한 행(legacyId 0). 승리 경험치가 바닥값 1인 것을 본다.\n'
        '**5인이면 2인일 때보다 라운드가 절반이다** (5 → 3, 부록 W-1).',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['orc', 'orc', 'orc'],
      seed: 11,
    ),
  ),
  'fixtures/rules/wipe.json': Fixture(
    name: '전멸 — Neo-Necromancer 대 빈사의 일행',
    record: 'attack',
    note:
        '종료 코드 2(전멸)와, 정산이 돌지 않는 것을 본다.\n'
        '원작은 여기서 processGameOver(2) 를 직접 불렀다(battle.dart:257).\n'
        '이제는 결과 코드만 넘긴다.',
    setup: BattleSetup(
      party: standardParty(
        replace: {
          0: seumgal(hp: 1),
          1: yuri(hp: 1),
          2: at(vanguard(2), 2),
          3: at(caster(3), 3),
          4: at(healer(4), 4),
        },
      ),
      enemyKeys: ['neo_necromancer'],
      seed: 3,
    ),
  ),
  'fixtures/rules/escape.json': Fixture(
    name: '도주 — Orc 한 마리 (B6-04)',
    record: 'escape',
    note:
        '도망은 **리더의 파티 행동**이다 — 의식 있는 사람 중 가장 낮은 슬롯이\n'
        '명령하고, 한 번 굴린다. 나머지는 그 라운드에 묻지 않는다.\n'
        '전에는 슬롯 1~4 가 각자 굴려 하나만 성공해도 전원 도주였다 — 다섯이\n'
        '굴리면 거의 언제나 성공했다. 종료 코드 0.',
    setup: BattleSetup(party: standardParty(), enemyKeys: ['orc'], seed: 1),
  ),
  'fixtures/rules/escape_gap.json': Fixture(
    name: '도주 — 간격을 벌린 뒤 달아난다 (B6-04)',
    record: 'attack,0=fallback',
    note:
        '**간격이 도망 확률을 만든다.** 리더가 두 라운드 물러서 간격을 2 로\n'
        '벌리면 달아나는 힘에 +30 이 붙는다 — `rand(20)` 보다 크다.\n'
        '이 fixture 는 후퇴만 기록한다(간격이 2 가 되면 후퇴 항목이 사라져\n'
        '공격으로 떨어진다). 직접 굴려서 `escape` 를 눌러 보면 성공률 차이가\n'
        '보인다: `--seed` 를 바꿔 몇 번 돌려 볼 것.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['wolf', 'wolf'],
      initialGap: 0,
      seed: 5,
    ),
  ),
  'fixtures/rules/coating.json': Fixture(
    name: '무기에 바르기 — 마비병 · 마법 13 (B6-03)',
    record: 'attack,0=item,2=coat',
    note:
        '**두 길이 한 곳으로 간다.** 슬롯 0(슴갈)은 마비병을 쓰고, 슬롯 2\n'
        '(방패병, 마법 지수 20)는 마법 13 「독 바르기」를 쓴다. 한 번 바른 뒤에는\n'
        '둘 다 그냥 싸운다 — 방침이 그렇게 되어 있다(발린 무기는 휘둘러야 값이 난다).\n'
        '3 라운드 동안 때릴 때마다: 독은 저항을 넘으면 묻고, 마비는 저항을 넘은\n'
        '뒤 50% 로 굳혀서 그 적의 **다음 턴을 지운다**. 이 시드에서 마비 2번,\n'
        '중독 3번이 나온다. 상태 표의 이름 옆에 `⚡마비 N` · `🟣독 N` 이 붙고\n'
        '라운드마다 줄어든다. 적을 Giant 둘 + Troll 로 둔 것은 5인 파티가 두 라운드에\n'
        '끝내 버리면 발린 무기를 휘두를 라운드가 없기 때문이다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['giant', 'giant', 'troll'],
      initialGap: 0,
      seed: 5,
      consumables: {'paralysis_vial': 1},
    ),
  ),
  'fixtures/rules/initiative.json': Fixture(
    name: '행동 순서가 민첩을 읽는다 (B2-05)',
    record: 'attack',
    note:
        '원작은 파티를 슬롯 순서로 다 돌린 뒤 적을 돌렸다 —\n'
        '`agility` 는 도주 판정에서만 읽혔다.\n'
        '이제 양쪽이 한 줄에 섞이고 `민첩 + random(10)` 으로 정렬된다.\n'
        'Wolf(민첩 15)와 Giant(민첩 8)를 같이 붙였다 — 순서가 턴마다 다르다.\n'
        '5인 파티라 한 라운드가 7턴이다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['wolf', 'giant'],
      seed: 6,
    ),
  ),
  'fixtures/rules/finishing_blow.json': Fixture(
    name: '마무리 일격 — 쓰러진 적을 다시 내리친다',
    record: 'attack',
    note:
        'B2-04 + B2-03. hp 0 은 사망이 아니라 **붕괴**(의식불명)이고,\n'
        '`unconscious` 는 불린이 아니라 **누적값**이다. 체력 x 레벨을\n'
        '넘어야 죽는다 — Orc 은 8 이다.\n'
        '앞사람이 쓰러뜨리면 같은 라운드 뒷사람이 다시 내리치고,\n'
        '누적이 임계값을 넘으면 그때 처치된다.\n'
        '원작에도 있던 문장인데 도달할 수 없었다(부록 O-3).\n'
        '**5인이면 같은 라운드에 뒤따르는 사람이 넷이라 훨씬 자주 나온다.**',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['orc', 'orc', 'orc'],
      seed: 2,
    ),
  ),
  'fixtures/rules/party_poison.json': Fixture(
    name: '파티 독 — B2-04 이 추가한 사망 경로',
    record: 'attack',
    note:
        '원작은 전투 중 파티의 독을 **아예 읽지 않았다**.\n'
        '붕괴가 회복 가능해지면서 파티가 죽을 길이 없어졌기 때문에\n'
        '독을 처리하게 했다 — 쓰러진 대상에게 독이 들어가면 사망한다.\n'
        '유리만 HP 5 에 독 3 으로 두었다. 나머지 넷은 멀쩡하다.',
    setup: BattleSetup(
      party: standardParty(replace: {1: yuriPoisoned(hp: 5)}),
      enemyKeys: ['orc'],
      seed: 4,
    ),
  ),
  'fixtures/rules/heal.json': Fixture(
    name: '치료 마법 — 실제로 회복한다 (B2-02)',
    record: 'attack,4=heal:21',
    note:
        '이식본은 메시지만 내고 HP 를 건드리지 않았다(battle.dart:154).\n'
        '이제 갈래가 넷이다 — 회복 · 독 제거 · 의식 돌림 · 부활.\n'
        '조합 순서가 중요하다: **독에 걸려 있으면 회복이 거부된다.**\n'
        '그래서 21(치료와 독제거)은 독을 먼저 지운다.\n'
        '치유사(마법 레벨 16)가 있어 전체 치료(26~32)까지 고를 수 있다.',
    setup: BattleSetup(
      party: standardParty(
        replace: {0: seumgal(hp: 40), 1: yuriPoisoned(hp: 30)},
      ),
      enemyKeys: ['orc', 'orc'],
      seed: 9,
    ),
  ),
  'fixtures/rules/cure_full.json': Fixture(
    name: '복합 치료 — 죽은 사람을 되살린다 (B2-02)',
    record: 'attack,4=heal:25',
    note:
        '25(한명 복합 치료)는 네 갈래를 순서대로 다 쓴다:\n'
        '부활 → 의식 돌림 → 독 제거 → 회복.\n'
        '부활은 **의식불명 상태로** 돌려놓으므로 의식 돌림이 뒤따라야 한다.\n'
        '의식 돌림 비용은 `10 x 의식불명 누적값`이라 깊이 쓰러졌으면 비싸다.\n'
        '유리가 죽어 있는 상태로 시작한다.',
    setup: BattleSetup(
      party: standardParty(replace: {1: yuriDead()}),
      enemyKeys: ['orc'],
      seed: 12,
    ),
  ),
  'fixtures/rules/magic.json': Fixture(
    name: '전체 공격 마법 — 마법마다 다르다 (B2-01)',
    record: 'attack,3=magic-all',
    note:
        '카테고리 경계가 정정되었다: 단일 1~6 · 전체 7~12 · 특수 13~18.\n'
        '피해 = `카테고리 내 순번² × 마법레벨 × 2` — 6번째가 1번째의 36배다.\n'
        '비용 = `(순번² × 마법레벨 + 1) / 2` 이고 **실제로 차감된다.**\n'
        '전체 마법은 적마다 비용을 물므로 중간에 마법 지수가 마를 수 있다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['orc', 'troll', 'wolf', 'goblin'],
      seed: 77,
    ),
  ),
  'fixtures/rules/debuff.json': Fixture(
    name: '특수 마법 13~18 — 능력을 깎는다 (B2-01)',
    record: 'attack,3=special:16',
    note:
        '특수 마법은 피해를 주지 않고 **적의 능력을 영구히 깎는다.**\n'
        '13 독(누적) · 14 기술 무력화 · 15 방어 무력화 · 16 능력 저하 ·\n'
        '17 마법 불능 · 18 탈 초인화.\n'
        '16(능력 저하)로 기록한다 — 레벨과 저항을 같이 깎는 것이 보인다.\n'
        'Phantom 은 물리력이 0 이라 전투가 길게 가고 효과가 쌓이는 것이 보인다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['phantom'],
      seed: 31,
    ),
  ),
  'fixtures/rules/items.json': Fixture(
    name: '전투 중 물건 (B2-06) — 마법이 없어도 할 일이 있다',
    record: 'attack,1=item',
    note:
        '원작 전투 메뉴에는 물건 항목이 **없었다**. 이 항목은 우리가 넣었다.\n'
        '약품은 마법과 같은 갈래(회복·해독·의식·소생)를 쓰고 조합 순서도 같다.\n'
        '결정은 속성 피해를 준다. **둘 다 마법 지수를 쓰지 않는다** —\n'
        '마법 레벨 0 인 유리도 쓸 수 있다는 것이 물건을 드는 이유다.',
    setup: BattleSetup(
      party: standardParty(
        replace: {0: seumgal(hp: 60), 1: yuriPoisoned(hp: 40)},
      ),
      enemyKeys: ['mummy', 'orc'],
      seed: 8,
      consumables: {'elixir': 3, 'fire_crystal': 2, 'potion': 2},
    ),
  ),
  'fixtures/rules/armour.json': Fixture(
    name: '부위별 감쇠와 방패 (B2-08)',
    record: 'attack',
    note:
        '원작 방어는 `ac` 하나였고 `powOfShield` 는 읽는 곳이 0곳이었다.\n'
        '이제 몸·머리·다리·장식은 **합쳐서 피해를 깎고**, 방패는\n'
        '**한 대를 통째로 막는 확률**로 따로 굴린다.\n'
        '방패를 든 방패병(막기 40%)과 안 든 넷을 같이 세웠다 —\n'
        '누가 덜 맞는지 상태 표에서 바로 보인다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['giant', 'giant'],
      seed: 14,
    ),
  ),
  'fixtures/rules/affinity.json': Fixture(
    name: '속성 상성 (B2-09) — 미라에게 불',
    record: 'attack,3=magic:2',
    note:
        '원작에 속성 개념이 **없다.** 우리가 넣은 것이고 얇게 유지했다 —\n'
        '이름이 분명한 마법만 속성을 갖고, 적 상성은 손으로 21종만 적었다.\n'
        '미라는 불에 약하고(x2) Salamander 는 불에 강하다(÷2).\n'
        '2(마법 화구, 화염)로 같은 마법을 둘에게 쏴서 차이를 본다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['mummy', 'salamander'],
      seed: 21,
    ),
  ),
  'fixtures/rules/enemy_ai.json': Fixture(
    name: '적 AI — 서로 치료하고 되살린다 (B2-07)',
    record: 'attack,4=heal:19',
    note:
        '적 행동이 `cast_level` 1~6 사다리다.\n'
        '레벨 4 이상은 체력이 1/3 아래로 떨어지면 **스스로를 치료**하고,\n'
        '레벨 5 이상은 무리가 상하면 **동료 전체를 치료**한다.\n'
        '치료는 죽은 동료의 `dead` 를 먼저 지우므로 **부활도 한다.**\n'
        'Wisp(cast_level 4) 하나를 붙였다 — 체력 1/3(30) 아래로 떨어지면\n'
        '**스스로를 36 회복한다.** 이 fixture 에서 세 번 나온다.\n'
        '일부러 마법을 쓰지 않는다 — 물리로만 갉으면 Wisp 이 임계값 언저리를\n'
        '오르내려서 자가 치료가 반복된다. 마법 한 방이면 그냥 죽는다\n'
        '(마법이 물리를 압도하는 문제, 부록 U-3).\n'
        '동료 전체 치료·부활은 `적 3마리 이상 + 무리 체력 1/3 이하` 라는 좁은\n'
        '조건이 겹쳐야 나오는데, Wisp 셋을 세우면 이쪽이 라운드당 150 을 쏴서\n'
        '5인 파티가 2라운드에 전멸한다. 그 조합은 단위 테스트가 고정한다\n'
        '(`test/rules/enemy_ai_test.dart`).',
    setup: BattleSetup(party: standardParty(), enemyKeys: ['wisp'], seed: 7),
  ),
  'fixtures/rules/preset.json': Fixture(
    name: 'preset — 겁쟁이는 도망가고 자동은 눈이 멀었다 (B5-08)',
    record: 'auto',
    note:
        '**적 쪽 preset 은 이미 있었다 — 이름이 없었을 뿐이다.**\n'
        '`enemy_ai.dart` 291줄이 그것이고, `cast_level` 1~6 사다리로 암묵적으로\n'
        '갈렸다. 이름을 붙여 쪼갠 것이라 재작성이 아니라 리팩터다.\n'
        '\n'
        'Goblin 은 겁쟁이 preset 이다 — **레벨 차가 크면 도망간다.**\n'
        '`EnemyFled` 이벤트가 이미 있어서(B2-10 의 염력 공포용) 새 이벤트가\n'
        '필요 없었고 조건만 붙였다. 자기 체력이 아니라 **레벨 차**를 읽으므로\n'
        '이미 진 뒤가 아니라 그 전에 떠난다.\n'
        '\n'
        '아군은 슬롯 0 이 자동 전투를 켠다. **자동은 평균적으로 강하되 눈이 멀었다** —\n'
        '대상을 고르지 않고 가장 가까운 것을 친다. 자동이 사람보다 잘 고르면\n'
        '최적 플레이가 "안 하는 것" 이 되고, 그게 FF12 갬빗이 간 길이다.\n'
        '**편집기는 없다.** 고르기만 있고, 이벤트로 고를 수 있는 목록이 길어진다.',
    setup: BattleSetup(
      party: veteranParty(),
      enemyKeys: ['goblin', 'goblin', 'orc'],
      initialGap: 0,
      seed: 44,
    ),
  ),
  'fixtures/rules/formation.json': Fixture(
    name: '이동 — 대열 전진 · 돌격 · 전진 방어 (B5-03)',
    record: 'attack,0=fallback,2=brace,1=charge',
    note:
        '세 가지 이동이 다 나온다.\n'
        '\n'
        '**대열 전진**은 슬롯 0(리더)만 낼 수 있고 **그 라운드에 공격하지**\n'
        '**않는다.** 행동 순서 안의 한 턴이 아니라 라운드 개시 단계라서\n'
        '민첩 선제(B2-05)를 건드리지 않는다. 양측 명령을 **더하고** 상한을\n'
        '거니까 난수가 없고, 서로 맞받으면 "간격은 그대로" 가 화면에 나온다.\n'
        '5인에서 리더의 턴은 전투 20행동 중 하나라 낼 만한 값이다.\n'
        '\n'
        '**돌격**은 앞으로 나서며 때린다. 별도 페널티가 필요 없다 —\n'
        '앞에 서면 열 가중 때문에 실제로 더 맞는다(B5-04).\n'
        '\n'
        '**전진 방어**는 방패 확률을 크게 올리고 **밀림 면역**이다.\n'
        '같은 라운드 두 번째 피격에는 훨씬 약해진다 — 없으면 무적이 된다.\n'
        '창기병(기병창, 사거리 2~3)이 돌격한다 — **붙는 순간 자기가 약해진다.**\n'
        '간격이 최대라 1라운드의 후퇴 명령은 메뉴에 안 나오고 공격으로 떨어진다.\n'
        '2라운드에 후퇴와 적의 전진이 맞받아 "간격은 그대로" 가 찍힌다.',
    setup: BattleSetup(
      party: standardParty(replace: {1: at(lancer(1), 1, rank: 2)}),
      enemyKeys: ['giant', 'giant'],
      initialGap: 2,
      seed: 33,
    ),
  ),
  'fixtures/rules/knockback.json': Fixture(
    name: '물리 속성과 넉백 — 타격이 줄을 민다 (B5-06)',
    record: 'attack,2=attack@0',
    note:
        '**속성이 무기가 아니라 공격 방식에 붙는다.** 무기에 박으면 적이 내\n'
        '속성에 강할 때 그 전투 내내 답이 없어서 전략이 아니라 벌금이 된다.\n'
        '\n'
        '살(43종)은 베기에 약하고 타격을 흡수한다. 언데드는 반대다 —\n'
        '베기·찌르기에 강하고 **타격에 약하다.** Skeleton 앞에서 장검이\n'
        '갑자기 안 듣는 것이 이 규칙이다.\n'
        '\n'
        '**약점을 타격으로 찌르면 한 열 밀려난다.** 밀어내는 것은 타격뿐이다 —\n'
        '모든 약점이 밀면 살(43종)에 베기가 통하는 것이 곧 상시 밀어내기가 되어\n'
        '위치를 계획할 수 없게 된다. 곤봉이 사람을 뒤로 넘기고 칼자국은 안 넘긴다는\n'
        '설명도 따로 필요 없다.\n'
        '\n'
        '방패병에게 철퇴를 들려 1열의 Skeleton 을 친다. 밀려난 Skeleton 뒤로\n'
        'ArchiMage 가 드러나고, 밀린 상대는 다음 피격에 추가 피해를 받는다\n'
        '(**순서가 아니라 상태**에 걸린 연계 — 민첩 선제와 충돌하지 않는다).',
    setup: BattleSetup(
      party: standardParty(replace: {2: at(maceBearer(2), 2, rank: 1)}),
      enemyKeys: ['skeleton', 'skeleton', 'archi_mage'],
      enemyRanks: [1, 1, 3],
      initialGap: 0,
      seed: 23,
    ),
  ),
  'fixtures/rules/reach.json': Fixture(
    name: '사거리와 대열 — 졸개 뒤의 보스 (B5-01)',
    // 전원이 3번(뒷열의 보스)을 노린다. 앞열이 살아 있는 동안은
    // 사거리가 모자라 벌점이 붙고 Orc 이 대신 맞는다.
    record: 'attack@3',
    note:
        '위치는 좌표가 아니라 정수 둘이다 — 각자의 **열**(1~3)과 양측 공통의\n'
        '**간격**(0~2). 거리 = 간격 + (내 열 - 1) + (상대 열 - 1).\n'
        'Archi-Mage 를 3열에, Orc 셋을 1열에 세우고 간격 1 에서 시작한다.\n'
        '앞열의 슴갈·방패병이 보스를 노리면 거리가 1+0+2 = 3 이라 2칸짜리\n'
        '사거리에 1칸 모자란다 — **명중이 깎이고 앞의 Orc 이 대신 맞는다.**\n'
        '\n'
        '**턴은 절대 사라지지 않는다.** 이것이 B5 의 유일한 불변식이다.\n'
        '사거리 밖이면 벌점이 붙을 뿐이고, 그래야 위치가 흔들려도 판이\n'
        '읽힌다. 목록에서 빼지 않는 이유이기도 하다 — 빈틈을 노려 보스를\n'
        '바로 치는 도박이 남아야 한다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['orc', 'orc', 'orc', 'archi_mage'],
      enemyRanks: [1, 1, 1, 3],
      initialGap: 1,
      seed: 19,
    ),
  ),
  'fixtures/rules/enemy_special.json': Fixture(
    name: '적 특수 능력 — 5인 파티에서 처음 켜진다 (B2-07)',
    record: 'attack',
    note:
        '특수 능력은 `random(50) < 민첩` 과 **의식 있는 파티원 4명 이상**을\n'
        '동시에 만족해야 나온다. **2인 파티로는 한 번도 안 나온다** —\n'
        '부록 W-2 가 그것을 실측했다(Basilisk 둘 상대로 2인 0회 / 5인 10회).\n'
        '독(1) · 기절(2) · 즉사(3) 세 종류이고, **행운이 막아 준다**\n'
        '(`random(20) < 행운`). 슴갈·유리는 행운이 0 이라 못 막고\n'
        '방패병(8)·치유사(10)는 가끔 막는다.',
    setup: BattleSetup(
      party: standardParty(),
      enemyKeys: ['basilisk', 'basilisk'],
      seed: 5,
    ),
  ),
};

// --- 만들고 기록한다 --------------------------------------------------

void main() {
  // 예전 위치의 fixture 를 지운다. 두 벌로 나뉘면서 자리가 바뀌었다.
  final root = Directory('fixtures');
  if (root.existsSync()) {
    for (final f in root.listSync().whereType<File>()) {
      if (f.path.endsWith('.json')) f.deleteSync();
    }
  }

  final fixtures = {..._originalFixtures(), ..._ruleFixtures()};
  var failed = 0;
  // 앱의 전투 실험실이 읽는 사본. 같은 파일을 두 곳에 두는 대신 **여기서
  // 함께 만든다** — Flutter 의 asset 경로는 패키지 밖(`../`)을 못 가리킨다.
  // 어긋나면 `test/fixture_mirror_test.dart` 가 잡는다.
  Directory(appFixtureRoot).createSync(recursive: true);

  fixtures.forEach((path, fixture) {
    final runner = BattleRunner(
      fixture: fixture,
      source: policy(fixture.record),
      sink: (_) {}, // 기록할 때는 출력하지 않는다
    );
    String status;
    try {
      final outcome = runner.run();
      final recorded = fixture.withCommands(runner.used);
      recorded.save(path);
      recorded.save(appMirror(path));
      status = '${runner.used.length}개 명령 · ${outcome.resultCode.name}';
    } catch (e) {
      fixture.save(path); // 명령 열 없이라도 남긴다
      fixture.save(appMirror(path));
      status = '기록 실패 — $e';
      failed++;
    }
    // ignore: avoid_print
    print('${path.padRight(44)} ${fixture.name}\n${" " * 44} $status');
  });

  // 앱의 실험실이 목록을 그리려면 무엇이 있는지 알아야 한다. asset 을
  // 훑는 대신 만들 때 색인을 함께 남긴다 — 이름·설명이 여기 있으니
  // 목록을 그리려고 21개를 다 열지 않아도 된다.
  File('$appFixtureRoot/index.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert([
      for (final e in fixtures.entries) {'path': e.key.replaceFirst('fixtures/', ''), 'name': e.value.name, 'note': e.value.note},
    ])}\n',
  );

  // ignore: avoid_print
  print('\n${fixtures.length}개 중 ${fixtures.length - failed}개 기록됨');
  if (failed > 0) exitCode = 1;
}
