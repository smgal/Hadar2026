import 'package:hd_battle/hd_battle.dart';
import 'package:hd_battle_console/palette.dart';
import 'package:hd_battle_console/view.dart';
import 'package:hd_battle_text/hd_battle_text.dart';
import 'package:test/test.dart';

/// view 가 원작의 문장을 그대로 만드는지 본다.
///
/// 이 테스트가 존재하는 이유: 문장과 조사가 model 에서 view 로 넘어왔으므로,
/// 옮기는 과정에서 문구가 달라지지 않았다는 것을 어딘가에서 고정해야 한다.
void main() {
  BattleView viewFor({List<String> enemyKeys = const ['orc']}) {
    final battle = Battle(
      BattleSetup(
        party: const [
          CombatantSnapshot(
            slot: 0,
            name: '슴갈',
            hp: 150,
            maxHp: 150,
            weaponName: '단도',
            weaponKey: 'dagger',
          ),
          CombatantSnapshot(
            slot: 1,
            name: '유리',
            hp: 100,
            maxHp: 100,
            weaponName: '단도',
            weaponKey: 'dagger',
          ),
        ],
        enemyKeys: enemyKeys,
        seed: 1,
      ),
    );
    return BattleView(battle);
  }

  group('원작 문구 재현', () {
    test('물리 공격 명중 — battle.dart:482', () {
      expect(
        viewFor().render(const EnemyDamaged(0, 0, 7, DamageSource.physical)),
        ['슴갈은 단도로 Orc을 공격하여 7 데미지!'],
      );
    });

    test('빗나감 — battle.dart:451', () {
      expect(viewFor().render(const AttackMissed(0)), ['슴갈의 공격은 빗나갔다....']);
    });

    test('저지와 막음이 다른 문장이다 — battle.dart:456, :473', () {
      final view = viewFor();
      expect(view.render(const EnemyBlocked(0, 0, BlockKind.resisted)), [
        'Orc은 슴갈의 공격을 저지했다',
      ]);
      expect(view.render(const EnemyBlocked(0, 0, BlockKind.absorbed)), [
        '그러나 Orc은 슴갈의 공격을 막았다',
      ]);
    });

    test('붕괴 문장이 물리·마법에서 다르다 — battle.dart:492, :174', () {
      final view = viewFor();
      expect(view.render(const EnemyCollapsed(0, 0, DamageSource.physical)), [
        'Orc은 슴갈의 공격으로 치명상을 입었다',
      ]);
      // B2-04 이후 hp 0 은 사망이 아니라 붕괴다. 원작 문구
      // "죽었다" 를 "쓰러졌다" 로 바꾼 것이 그 반영이다.
      expect(view.render(const EnemyCollapsed(0, 0, DamageSource.spell)), [
        'Orc이 쓰러졌다.',
      ]);
    });

    test('마무리 일격은 원작 문구 그대로 — battle.dart:442', () {
      // 원작에는 있었지만 도달 불가였던 줄(부록 O-3). B2-04 가 살렸다.
      expect(viewFor().render(const EnemyFinished(0, 0)), [
        '슴갈은 의식불명 상태인 Orc을 가볍게 처치했다!',
      ]);
    });

    test('파티 독 줄에는 원작에 없던 표시가 붙는다', () {
      final view = viewFor();
      for (final event in <BattleEvent>[
        const MemberPoisonTick(0, 2),
        const MemberCollapsedFromPoison(0),
        const MemberDiedFromPoison(0),
      ]) {
        expect(view.render(event).single, startsWith(BattleView.added));
      }
    });

    test('적 공격 차단은 두 줄이다 — battle.dart:534-538', () {
      expect(viewFor().render(const MemberBlocked(0, 1, BlockKind.resisted)), [
        'Orc은 유리를 공격했다.',
        '그러나, 유리는 적의 공격을 저지했다.',
      ]);
    });

    test('마법 시전 — battle.dart:158', () {
      expect(viewFor().render(const SpellCast(0, 1)), ['슴갈은 마법 화살을 시전했다!']);
    });

    test('치료가 실제 회복량을 말한다 (B2-02)', () {
      // 원작 이식본은 `아군의 상처가 치료되었다.` 한 줄만 내고 HP 를
      // 건드리지 않았다(battle.dart:155). 이제 갈래별로 말한다.
      final view = viewFor();
      expect(view.render(const MemberHealed(0, 30)), ['슴갈의 상처가 30 회복되었다.']);
      expect(view.render(const MemberCured(1)), ['유리는 독에서 벗어났다.']);
      expect(view.render(const MemberRevived(1)), ['유리가 의식을 되찾았다.']);
      expect(view.render(const MemberResurrected(0)), [
        '슴갈이 되살아났다. 아직 의식은 없다.',
      ]);
      expect(view.render(const CureHadNoEffect(0, 19)), ['치료할 상처가 없었다.']);
    });

    test('전멸·도주 종료 문장 — battle.dart:256, :259', () {
      final view = viewFor();
      expect(view.render(const BattleEnded(BattleResultCode.lose)), [
        '파티가 전멸했습니다.',
      ]);
      expect(view.render(const BattleEnded(BattleResultCode.evade)), [
        '무사히 도망쳤다...',
      ]);
      expect(
        view.render(const BattleEnded(BattleResultCode.win)),
        isEmpty,
        reason: '승리는 경험치 줄이 대신한다',
      );
    });

    test('경험치 정산 — battle.dart:281', () {
      expect(viewFor().render(const ExperienceSettled(64)), [
        '전투에서 승리하여 경험치 64을 얻었다.',
      ]);
    });
  });

  group('적 등장 문장의 특성까지 그대로', () {
    test('같은 이름을 묶어 "이름 x N" 으로 만든다 — battle.dart:70-84', () {
      expect(
        viewFor(
          enemyKeys: ['orc', 'orc', 'wolf'],
        ).render(const EnemiesAppeared([0, 1, 2])),
        ['Orc x 2, Wolf 이 나타났다 !'],
      );
    });

    test('조사는 이름이 여럿이어도 첫 적 것을 쓴다', () {
      // 원작 `battle.dart:87` 이 `enemies.first.name.sub2` 를 쓴다.
      // 마지막 이름에 맞추지 않는 것이 원작의 특성이다.
      final line = viewFor(
        enemyKeys: ['giant', 'orc'],
      ).render(const EnemiesAppeared([0, 1])).single;
      expect(line, 'Giant, Orc 이 나타났다 !');
    });
  });

  group('원작에 없던 줄은 표시가 붙는다', () {
    test('독 피해·골드·턴 구분', () {
      final view = viewFor();
      for (final event in <BattleEvent>[
        const EnemyPoisonTick(0, 3),
        const GoldSettled(25),
        const RoundStarted(2),
      ]) {
        expect(view.render(event).single, startsWith(BattleView.added));
      }
    });

    test('원작에 있던 줄에는 붙지 않는다', () {
      final view = viewFor();
      for (final event in <BattleEvent>[
        const AttackMissed(0),
        const SpellCast(0, 1),
        const ExperienceSettled(1),
      ]) {
        expect(view.render(event).single, isNot(startsWith(BattleView.added)));
      }
    });
  });

  group('메뉴', () {
    test('전투 모드 메뉴는 여섯 줄이다 (B6-01)', () {
      final view = viewFor();
      final menu = view.actionMenu(
        const ActionDecision(0, [
          BattleAction.attack,
          BattleAction.castSkill,
          BattleAction.useItem,
          BattleAction.brace,
          BattleAction.escape,
          BattleAction.orders,
        ]),
      );
      expect(menu.split('\n'), [
        // B5: 머리글에 자기 열과 무기 사거리를 단다 — 무엇을 고를지가
        // 그 둘에 걸려 있는데 매번 외워 두라고 할 수는 없다.
        '슴갈의 전투 모드 1열 · 찌르기 0~1 · 간격 0 ===>',
        '  1) ⚔ 공격 — 단도로',
        '  2) ✨ 기술 — 마법과 초능력',
        '  3) 🎒 물건',
        '  4) 🛡 버팀 — 앞에 서서 막는다',
        '  5) 🏃 도망 — 일행 전체',
        '  6) ⚙ 지시 — 대열 · 자동 전투',
        '  0) 이 턴을 넘긴다',
      ]);
    });

    test('기술 목록은 하나이고 글자가 범위를 말한다 (B6-01)', () {
      final view = viewFor();
      final menu = view.spellMenu(
        const SpellDecision(0, [
          SkillOption(
            magicId: 1,
            scope: SkillScope.oneEnemy,
            resource: SkillResource.sp,
            cost: 1,
            affordable: true,
          ),
          SkillOption(
            magicId: 7,
            scope: SkillScope.allEnemies,
            resource: SkillResource.sp,
            cost: -1,
            affordable: true,
          ),
          SkillOption(
            magicId: 13,
            scope: SkillScope.selfWeapon,
            resource: SkillResource.sp,
            cost: 10,
            affordable: false,
          ),
          SkillOption(
            magicId: 45,
            scope: SkillScope.oneEnemy,
            resource: SkillResource.esp,
            cost: 20,
            affordable: true,
          ),
        ]),
      );
      final lines = menu.split('\n');
      expect(lines.first, '기술 ===>');
      expect(lines[1], contains('🎯 마법 화살'));
      expect(lines[1], contains('SP 1'));
      expect(lines[2], contains('💥 공기 폭풍'));
      expect(lines[2], contains('SP ~'), reason: '적마다 물어서 미리 못 안다');
      expect(lines[3], contains('🌀 독 바르기'));
      expect(lines[3], contains('(부족)'), reason: '못 써도 보인다');
      expect(lines[4], contains('🔮 염력'));
      expect(lines[4], contains('ESP 20'));
    });

    test('기술이 8줄을 넘으면 첫 화면은 범위 묶음이다', () {
      final view = viewFor();
      final many = SpellDecision(
        0,
        skillOptions(levelMagic: 20, levelEsp: 5, sp: 999, esp: 999),
      );
      final lines = view.menuFor(many).split('\n');
      expect(lines.first, '어떤 기술을 ===>');
      expect(lines[1], contains('🎯 한 명 공격'));
      expect(lines[1], contains('6'));
      expect(lines.length, lessThanOrEqualTo(9), reason: '묶음 7 + 머리글 + 취소');
      // 묶음 하나를 열면 그 안 목록만 보인다.
      final group = skillGroups(many.options)[1];
      final inner = view.spellMenu(many, group: group).split('\n');
      expect(inner.first, '💥 전체 공격 ===>');
      expect(inner.length, 6 + 2);
    });

    test('8줄 이하면 접지 않는다', () {
      final few = SpellDecision(
        0,
        skillOptions(levelMagic: 1, levelEsp: 0, sp: 999, esp: 999),
      );
      expect(viewFor().menuFor(few).split('\n').first, '기술 ===>');
    });

    test('도망은 일행 전체의 행동이다 (B6-04)', () {
      expect(viewFor().actionLabel(BattleAction.escape, 0), '🏃 도망 — 일행 전체');
    });
  });

  group('색 — 원작의 writeConsole 첫 인자를 그대로 옮겼다', () {
    // 원작의 모든 전투 메시지는 `writeConsole(색번호, ...)` 로 나갔다
    // (`REF_hadar/src/hadar/hd_base_extern.cpp:241`). 아래 기대값의
    // 출처는 전부 그 호출들이다.
    final view = viewFor();

    test('일행이 움직인 줄은 12번', () {
      // pc_player.cpp:1035 (빗나감) · :1064 (적 의식불명) · :1010 (치명타)
      expect(view.colorOf(const AttackMissed(0)), HDColor.lightRed);
      expect(
        view.colorOf(const EnemyCollapsed(0, 0, DamageSource.physical)),
        HDColor.lightRed,
      );
      expect(view.colorOf(const EnemyFinished(0, 0)), HDColor.lightRed);
    });

    test('적이 움직인 줄은 13번', () {
      // pc_enemy.cpp:704 (소환) · :852 (자가 치료) · :575 (독 공격 시도)
      expect(view.colorOf(const EnemySummoned(0, 0)), HDColor.lightMagenta);
      expect(view.colorOf(const EnemyHealedSelf(0, 10)), HDColor.lightMagenta);
      expect(
        view.colorOf(const EnemyAbilityUsed(0, EnemySpecialKind.poison, 0)),
        HDColor.lightMagenta,
      );
    });

    test('빗나감·저지·실패는 7번', () {
      // pc_enemy.cpp:309,325,334,579 · pc_player.cpp:1041,1052,1147
      expect(
        view.colorOf(const EnemyBlocked(0, 0, BlockKind.resisted)),
        HDColor.lightGray,
      );
      expect(view.colorOf(const SpellMissed(0, 1, 0)), HDColor.lightGray);
      expect(view.colorOf(const EscapeFailed(0)), HDColor.lightGray);
      expect(
        view.colorOf(const EnemyAbilityMissed(0, EnemySpecialKind.poison)),
        HDColor.lightGray,
      );
    });

    test('일행이 입은 피해는 5번, 상태가 나빠지면 4번', () {
      // pc_enemy.cpp:346 (피해) · :488 (갑옷 파괴) 는 5번,
      // :589 (중독) · :615 (의식불명) · :646 (사망) 은 4번이다.
      expect(
        view.colorOf(const MemberDamaged(0, 0, 30, DamageSource.physical)),
        HDColor.magenta,
      );
      expect(view.colorOf(const MemberArmourWorn(0, 0)), HDColor.magenta);
      expect(view.colorOf(const MemberPoisoned(0)), HDColor.red);
      expect(
        view.colorOf(const MemberStruckDown(0, killed: false)),
        HDColor.red,
      );
      expect(view.colorOf(const MemberDied(0)), HDColor.red);
    });

    test('치료 성공은 15번, 경험치는 14번, 금화는 15번', () {
      // pc_player.cpp:1963,1997,2036,2071 · :2160 · game_main.cpp:368
      expect(view.colorOf(const MemberHealed(0, 30)), HDColor.white);
      expect(view.colorOf(const MemberCured(0)), HDColor.white);
      expect(view.colorOf(const ExperienceSettled(100)), HDColor.yellow);
      expect(view.colorOf(const GoldSettled(50)), HDColor.white);
    });

    test('크게 좋은 일은 11번, 적이 겁먹고 달아나면 10번', () {
      // pc_player.cpp:1486 (영입) · :1890 (도주 성공) · :1618 (공포)
      expect(view.colorOf(const EnemyRecruited(0, 0)), HDColor.lightCyan);
      expect(view.colorOf(const EscapeSucceeded(0)), HDColor.lightCyan);
      expect(view.colorOf(const EnemyFled(0)), HDColor.lightGreen);
    });

    test('적이 입은 피해 줄은 7번이고 수치만 15번이다', () {
      // C++ 은 수치도 7번으로 내면서 `// 원래는 중간이 15번 색` 이라고
      // 스스로 적어 뒀다(pc_player.cpp:1074,1185). 원래 형태로 되돌렸다.
      expect(
        view.colorOf(const EnemyDamaged(0, 0, 7, DamageSource.physical)),
        HDColor.lightGray,
      );
      final coloured = BattleView(view.battle, ansi: const HDAnsi());
      expect(
        coloured
            .render(const EnemyDamaged(0, 0, 7, DamageSource.physical))
            .single,
        '\x1b[37m슴갈은 단도로 Orc을 공격하여 \x1b[97m7\x1b[37m 데미지!\x1b[0m',
      );
    });

    test('일행이 입은 피해 수치는 13번 — pc_enemy.cpp:346 의 `@D`', () {
      final coloured = BattleView(view.battle, ansi: const HDAnsi());
      expect(
        coloured
            .render(const MemberDamaged(0, 0, 30, DamageSource.physical))
            .single,
        '\x1b[35mOrc은 슴갈을 공격하여 \x1b[95m30\x1b[35m 데미지!\x1b[0m',
      );
    });

    test('한 이벤트가 두 색을 쓰는 유일한 자리 — 적의 공격을 막았을 때', () {
      // pc_enemy.cpp:324 은 13번, :325 는 7번이다.
      final coloured = BattleView(view.battle, ansi: const HDAnsi());
      final out = coloured.render(
        const MemberBlocked(0, 0, BlockKind.resisted),
      );
      expect(out.first, startsWith('\x1b[95m'));
      expect(out.last, startsWith('\x1b[37m'));
    });

    test('색을 끄면 예전과 똑같은 맨 문자열이 나온다', () {
      // view 를 그냥 만들면 색이 꺼져 있다 — 위의 모든 문구 테스트가
      // 그대로 통하는 이유다.
      expect(
        view
            .render(const MemberDamaged(0, 0, 30, DamageSource.physical))
            .single,
        'Orc은 슴갈을 공격하여 30 데미지!',
      );
    });

    test('메뉴 머리글은 12번, 항목은 7번, 취소는 8번', () {
      // hd_class_select.cpp:21 (머리글) · :27 (고를 수 있는 항목).
      final coloured = BattleView(view.battle, ansi: const HDAnsi());
      final menu = coloured
          .actionMenu(const ActionDecision(0, [BattleAction.attack]))
          .split('\n');
      expect(menu[0], startsWith('\x1b[91m'));
      expect(menu[1], startsWith('\x1b[37m'));
      expect(menu[2], startsWith('\x1b[90m'));
    });

    test('상태 표의 이름 색이 곧 상태다', () {
      final coloured = BattleView(view.battle, ansi: const HDAnsi());
      final table = coloured.statusTable();
      // 이 Orc 은 HP 8 이라 12번(밝은 빨강) 대역이다 — 20 이하.
      expect(table, contains('\x1b[91mOrc'));
      // 일행은 멀쩡하니 15번(하양).
      expect(table, contains('\x1b[97m슴갈'));
    });
  });
  _positionIsVisible();
}

/// 위치를 눈으로 볼 수 있어야 위치로 작전을 짤 수 있다 (B5).
void _positionIsVisible() {
  BattleView positioned() {
    final battle = Battle(
      BattleSetup(
        party: const [
          CombatantSnapshot(
            slot: 0,
            name: '슴갈',
            hp: 150,
            maxHp: 150,
            rank: 1,
            weaponName: '단도',
            weaponKey: 'dagger',
          ),
          CombatantSnapshot(
            slot: 1,
            name: '술사',
            hp: 90,
            maxHp: 90,
            rank: 3,
            weaponName: '지팡이',
            weaponKey: 'staff',
          ),
        ],
        enemyKeys: const ['orc', 'archi_mage'],
        enemyRanks: const [1, 3],
        initialGap: 1,
        seed: 1,
      ),
    );
    battle.advance();
    return BattleView(battle);
  }

  group('상태 표가 위치를 보여준다', () {
    test('간격과 양쪽 대열이 한 줄에 그려진다', () {
      final table = positioned().statusTable();
      expect(table, contains('간격 1'));
      expect(table, contains('[1] 슴갈'));
      expect(table, contains('[3] 술사'));
      expect(table, contains('[3] ArchiMage'));
    });

    test('사람마다 열이 붙는다', () {
      final table = positioned().statusTable();
      expect(table, contains('1열'));
      expect(table, contains('3열'));
    });

    test('지금 누구에게 닿는지 알려준다 — 계산은 플레이어의 일이 아니다', () {
      final table = positioned().statusTable();
      // 단도(0~1)를 든 1열은 1열의 Orc(거리 1)에 닿고,
      // 지팡이(0~2)를 든 3열은 거리 3 이라 아무 데도 안 닿는다.
      expect(table, contains('닿음 1'));
      expect(table, contains('닿는 적 없음'));
    });
  });

  group('대상 선택이 거리와 벌점을 말해준다', () {
    test('닿는 적은 무엇으로 치는지까지', () {
      final menu = positioned().enemyTargetMenu(
        const EnemyTargetDecision(0, [0, 1]),
      );
      expect(menu, contains('닿음 · 찌르기'));
    });

    test('안 닿는 적은 몇 칸 모자란지와 값을', () {
      final menu = positioned().enemyTargetMenu(
        const EnemyTargetDecision(0, [0, 1]),
      );
      expect(menu, contains('칸 부족'));
      expect(menu, contains('명중 -'));
      expect(menu, contains('앞열이 대신'));
    });

    test('목록에서 빼지는 않는다 — 빈틈을 노리는 도박이 남아야 한다', () {
      final menu = positioned().enemyTargetMenu(
        const EnemyTargetDecision(0, [0, 1]),
      );
      expect(menu, contains('ArchiMage'));
    });
  });

  group('행동 메뉴 머리글이 자기 사거리를 단다', () {
    test('열과 무기 대역과 간격', () {
      final menu = positioned().actionMenu(
        const ActionDecision(0, [BattleAction.attack]),
      );
      expect(menu.split('\n').first, contains('1열'));
      expect(menu.split('\n').first, contains('찌르기 0~1'));
      expect(menu.split('\n').first, contains('간격 1'));
    });
  });

  group('한글 폭을 세어 표가 어긋나지 않는다', () {
    test('한글은 두 칸이다', () {
      expect(BattleView.displayWidth('슴갈'), 4);
      expect(BattleView.displayWidth('Orc'), 3);
      expect(BattleView.displayWidth('방패병'), 6);
    });

    test('채우면 화면 폭이 같아진다', () {
      expect(BattleView.displayWidth(BattleView.padDisplay('슴갈', 10)), 10);
      expect(BattleView.displayWidth(BattleView.padDisplay('Orc', 10)), 10);
    });
  });
}
