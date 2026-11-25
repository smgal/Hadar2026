import 'package:lore_battle/lore_battle.dart';
import 'package:lore_battle_text/lore_battle_text.dart';
import 'package:test/test.dart';

/// 이름만 돌려주는 가장 단순한 구현 — 대명사도 무기 계통도 모른다.
class _PlainNames implements BattleNames {
  @override
  HDNoun member(int slot) => HDNoun(slot == assistantSeat ? '이프리트' : '리라');

  @override
  HDNoun enemy(int index) => HDNoun(index == 0 ? '오크병사' : '드라코니안킹');

  @override
  String weapon(int slot) => '그라디우스';
}

/// 대명사와 무기 계통까지 아는 구현.
class _FullNames extends _PlainNames implements BattleNarration {
  _FullNames(this.kind);

  final WeaponKind kind;

  @override
  String pronoun(int slot) => '그녀';

  @override
  WeaponKind weaponKind(int slot) => kind;
}

/// 이벤트 종류마다 하나씩.
const List<BattleEvent> _oneOfEach = [
  EnemiesAppeared([0, 1]),
  RoundStarted(1),
  RoundStarted(1, enemyActsFirst: true),
  ActionSkipped(0),
  BattleEnded(BattleResultCode.win),
  BattleEnded(BattleResultCode.lose),
  BattleEnded(BattleResultCode.evade),
  AttackDeclared(0, 0),
  AttackMissed(0),
  OutOfArrows(0),
  AttackStrained(0, 0, 1),
  AttackIntercepted(0, 1, 0),
  FormationResolved(
    from: 1,
    to: 0,
    partyAdvanced: true,
    partyRetreated: false,
    enemyAdvanced: false,
    enemyRetreated: false,
  ),
  Charged(0, 1),
  Braced(0, 1),
  AttackerShovedBack(0, 0, 2),
  DodgedBack(0, 2),
  EnemyPushedBack(0, 2),
  EnemyCornered(0, 10),
  MemberPushedBack(0, 2),
  MemberCornered(0, 10),
  AffinityApplied(0, ElementKind.fire, AffinityKind.weak),
  AffinityApplied(0, ElementKind.blunt, AffinityKind.resisted),
  SpellCast(0, 101, enemyIndex: 0),
  SpellCast(0, 201, enemyIndex: 1),
  SpellCast(0, 302, enemyIndex: 0),
  SpellCast(0, 401),
  SpellCast(0, 502),
  SpellCast(0, 503, enemyIndex: 0),
  SpellCast(0, 601),
  NotEnoughSpellPoints(0),
  SpellMissed(0, 101, 0),
  EnemyBlocked(0, 0, BlockKind.resisted),
  EnemyBlocked(0, 0, BlockKind.absorbed),
  EnemyBlocked(0, 0, BlockKind.resisted, source: DamageSource.spell),
  EnemyBlocked(0, 0, BlockKind.absorbed, source: DamageSource.spell),
  EnemyDamaged(0, 0, 120, DamageSource.physical),
  EnemyDamaged(0, 0, 120, DamageSource.spell),
  EnemyCollapsed(0, 0, DamageSource.physical),
  EnemyCollapsed(0, 0, DamageSource.spell),
  EnemyFinished(0, 0),
  EnemyFinished(0, 0, flavour: 1),
  EnemyFinished(0, 0, flavour: 2),
  EnemyFinished(0, 0, flavour: 3),
  EnemyFinished(0, 0, source: DamageSource.spell),
  ExperienceGained(0, 27),
  DebuffApplied(0, 301, 0, DebuffDetail.specialRemoved),
  DebuffApplied(0, 302, 0, DebuffDetail.defenceLowered),
  DebuffApplied(0, 303, 0, DebuffDetail.abilityLowered),
  DebuffApplied(0, 304, 0, DebuffDetail.castingLowered),
  DebuffApplied(0, 304, 0, DebuffDetail.castingRemoved),
  DebuffApplied(0, 305, 0, DebuffDetail.superhumanLowered),
  DebuffApplied(0, 305, 0, DebuffDetail.superhumanRemoved),
  DebuffApplied(0, 300, 0, DebuffDetail.poisoned),
  DebuffFailed(0, 301, 0, resisted: true),
  DebuffFailed(0, 301, 0, resisted: false),
  MemberHealed(0, 60),
  MemberCured(0),
  MemberRevived(0),
  MemberResurrected(0),
  CureHadNoEffect(0),
  MemberMpRestored(0, 100),
  ItemUsed(0, ItemKey.flameCrystal),
  CrystalDidNotReact(0, ItemKey.darkCrystal, CrystalSilence.needsItsPair),
  CrystalDidNotReact(0, ItemKey.darkCrystal, CrystalSilence.wrongEnemy),
  EnemyAged(1),
  EnemySoulWithered(0, 100),
  PartyRestored(0),
  FusionUnleashed(0, 0),
  FusionUnleashed(0, 1),
  EnemyRecruited(0, 0),
  MindControlFailed(0, 0, MindControlFailure.immune),
  MindControlFailed(0, 0, MindControlFailure.outmatched),
  MindControlFailed(0, 0, MindControlFailure.unmoved),
  EspHadNoEffect(0, 504, 0),
  EnemyWeakened(0, WeakenedStat.resistance),
  EnemyWeakened(0, WeakenedStat.endurance),
  EnemyWeakened(0, WeakenedStat.agility),
  EnemyWeakened(0, WeakenedStat.accuracy),
  EnemyFled(0),
  EnemyPoisoned(0),
  EnemyStruckDown(0, 0),
  AssistantJoined(AssistantSource.summon, replaced: false),
  AssistantJoined(AssistantSource.crystal, replaced: true),
  AssistantJoined(AssistantSource.persuasion, replaced: false),
  EscapeAttempted(0),
  EscapeFailed(0),
  EscapeSucceeded(0),
  EnemyPoisonTick(0, 50),
  EnemyCollapsedFromPoison(0),
  EnemyDiedFromPoison(0),
  EnemyAttackMissed(0),
  EnemyAttackStrained(0, 0, 1),
  EnemyAttackIntercepted(0, 1, 0),
  ShieldBlocked(0, 0),
  MemberBlocked(0, 0, BlockKind.absorbed),
  MemberBlocked(0, 0, BlockKind.resisted),
  MemberBlocked(0, 0, BlockKind.resisted, source: DamageSource.spell),
  MemberBlocked(0, 0, BlockKind.absorbed, source: DamageSource.spell),
  MemberDamaged(0, 0, 38, DamageSource.physical),
  MemberDamaged(0, 0, 38, DamageSource.spell),
  MemberCollapsed(0),
  MemberDied(0),
  EnemyCastSpell(1, EnemySpellKind.lightning, 0),
  EnemyCastSpell(1, EnemySpellKind.fireStorm, -1),
  EnemySpellMissed(1, 0),
  EnemyHealedSelf(1, 100),
  EnemyHealedAlly(1, 0, 100),
  EnemyRevivedAlly(1, 0, fromDeath: true),
  EnemyAbilityUsed(0, EnemySpecial.poison, 0),
  EnemyAbilityUsed(0, EnemySpecial.slay, -1),
  EnemyAbilityMissed(0, EnemySpecial.knockOut),
  MemberEvadedAbility(0, EnemySpecial.slay),
  MemberAfflicted(0, EnemySpecial.poison),
  MemberAfflicted(0, EnemySpecial.knockOut),
  MemberAfflicted(0, EnemySpecial.slay),
  MemberAfflicted(0, EnemySpecial.poison, enemyIndex: 1, mass: true),
  MemberAfflicted(0, EnemySpecial.knockOut, enemyIndex: 1, mass: true),
  MemberAfflicted(0, EnemySpecial.slay, enemyIndex: 1, mass: true),
  ArmourBreakAttempted(1, 0, broken: true),
  ArmourBreakAttempted(1, 0, broken: false),
  EnemySummoned(1, 0),
  MemberAbducted(1, 5, 0),
  EnemyClonesShifted([0, 1]),
  MemberPoisonTick(0, 2),
  MemberCollapsedFromPoison(0),
  MemberDiedFromPoison(0),
  GoldSettled(216),
];

void main() {
  final names = _PlainNames();

  group('every event has a sentence and a colour', () {
    test('nothing throws, and every colour is one of the sixteen', () {
      for (final event in _oneOfEach) {
        final lines = battleLines(event, names);
        for (final line in lines) {
          expect(line, isNotEmpty, reason: '${event.runtimeType}');
        }
        expect(
          battleLineColor(event),
          inInclusiveRange(0, 15),
          reason: '${event.runtimeType}',
        );
      }
    });

    test('only what the original left silent produces no line', () {
      const silent = {
        // 원작도 문장이 없다.
        EnemyClonesShifted,
      };
      for (final event in _oneOfEach) {
        final lines = battleLines(event, names);
        if (lines.isNotEmpty) continue;
        final expected =
            silent.contains(event.runtimeType) ||
            // 승리·도망은 금화 줄과 도망 줄이 이미 말했다.
            (event is BattleEnded && event.code != BattleResultCode.lose) ||
            // 설득은 "적은 우리의 편이 되었다" 가 이미 말했다.
            (event is AssistantJoined &&
                event.source == AssistantSource.persuasion);
        expect(expected, isTrue, reason: '${event.runtimeType} is silent');
      }
    });
  });

  group('the original wording (appendix E.7)', () {
    String one(BattleEvent e, [BattleNames? n]) =>
        battleLines(e, n ?? names).single;

    test('a weapon blow', () {
      expect(one(const AttackDeclared(0, 0)), '리라는 그라디우스로 오크병사를 공격했다');
      expect(one(const AttackMissed(0)), '리라의 공격은 빗나갔다....');
      expect(
        one(const EnemyBlocked(0, 0, BlockKind.resisted)),
        '적은 리라의 공격을 저지했다',
      );
      expect(
        one(const EnemyBlocked(0, 0, BlockKind.absorbed)),
        '그러나, 적은 리라의 공격을 막았다',
      );
      expect(
        one(const EnemyDamaged(0, 0, 120, DamageSource.physical)),
        '적은 @F120@@만큼의 피해를 입었다',
      );
      expect(
        one(const EnemyCollapsed(0, 0, DamageSource.physical)),
        '적은 리라의 공격으로 의식불명이 되었다',
      );
      expect(one(const ExperienceGained(0, 27)), '리라는 @B27@@만큼 경험치를 얻었다!');
    });

    test('the verb follows the weapon kind and the pronoun is used', () {
      expect(
        one(const AttackDeclared(0, 0), _FullNames(WeaponKind.chop)),
        endsWith('내려쳤다'),
      );
      expect(
        one(const AttackDeclared(0, 0), _FullNames(WeaponKind.pierce)),
        endsWith('찔렀다'),
      );
      expect(
        one(const AttackDeclared(0, 0), _FullNames(WeaponKind.shoot)),
        endsWith('쏘았다'),
      );
      expect(
        one(const AttackMissed(0), _FullNames(WeaponKind.slash)),
        '그녀의 공격은 빗나갔다....',
      );
    });

    test('the four finishing lines', () {
      final lines = [
        for (var flavour = 0; flavour < 4; flavour++)
          one(EnemyFinished(0, 0, flavour: flavour)),
      ];
      expect(lines, [
        '리라의 무기가 오크병사의 심장을 꿰뚫었다',
        '오크병사의 머리는 리라의 공격으로 산산 조각이 났다',
        '적의 피가 사방에 뿌려졌다',
        '적은 비명과 함께 찢겨 나갔다',
      ]);
      expect(
        one(const EnemyFinished(0, 0, source: DamageSource.spell)),
        '리라의 마법은 적을 완전히 제거해 버렸다',
      );
    });

    test('attack magic', () {
      expect(
        one(const SpellCast(0, 101, enemyIndex: 0)),
        "리라는 '마법 화살'로 오크병사에게 공격했다",
      );
      expect(one(const NotEnoughSpellPoints(0)), '마법 지수가 부족했다');
      expect(one(const SpellMissed(0, 101, 1)), '그러나, 드라코니안킹을 빗나갔다');
      expect(
        one(const EnemyCollapsed(0, 0, DamageSource.spell)),
        '오크병사는 리라의 마법에 의해 의식불능이 되었다',
      );
    });

    test('special magic, ESP and summoning', () {
      expect(
        one(const SpellCast(0, 302, enemyIndex: 0)),
        '리라는 오크병사에게 한명 방어 무력화로 특수 공격을 했다',
      );
      expect(
        one(const SpellCast(0, 503, enemyIndex: 0)),
        '리라는 오크병사에게 공포 생성을 사용했다',
      );
      expect(one(const SpellCast(0, 502)), '리라는 모든 적에게 수소 핵융합을 사용했다');
      expect(one(const SpellCast(0, 601)), '리라는 불의 정령 소환을 시도했다');
      expect(one(const EnemyRecruited(0, 0)), '적은 우리의 편이 되었다');
      expect(
        one(const DebuffFailed(0, 301, 0, resisted: true)),
        '한명 기술 무력화 공격은 저지 당했다',
      );
    });

    test('the enemy turn', () {
      expect(one(const EnemyAttackMissed(0)), '오크병사는 빗맞추었다');
      expect(
        battleLines(
          const MemberDamaged(0, 0, 38, DamageSource.physical),
          names,
        ),
        ['@D리라는 오크병사에게 공격 받았다@@', '리라는 @D38@@만큼의 피해를 입었다'],
      );
      expect(battleLines(const ShieldBlocked(0, 0), names), [
        '@D오크병사는 리라를 공격했다@@',
        '그러나, 리라는 방패로 적의 공격을 막았다',
      ]);
      expect(
        one(const EnemyCastSpell(1, EnemySpellKind.lightning, 0)),
        "드라코니안킹은 리라에게 '번개'마법을 사용했다",
      );
      expect(
        one(const EnemyCastSpell(1, EnemySpellKind.fireStorm, -1)),
        "드라코니안킹은 일행 모두에게 '화염폭풍'마법을 사용했다",
      );
      expect(
        one(const EnemyAbilityUsed(0, EnemySpecial.poison, 0)),
        '오크병사는 리라에게 독 공격을 시도했다',
      );
      expect(
        one(const MemberEvadedAbility(0, EnemySpecial.slay)),
        '그러나, 리라는 죽음의 공격을 피했다',
      );
      expect(one(const MemberAfflicted(0, EnemySpecial.slay)), '리라는 죽었다 !!');
      expect(
        one(
          const MemberAfflicted(
            0,
            EnemySpecial.slay,
            enemyIndex: 1,
            mass: true,
          ),
        ),
        '리라는 드라코니안킹에 의해 급사 당했다.',
      );
      expect(one(const EnemySummoned(1, 0)), '드라코니안킹은 오크병사를 생성시켰다');
    });

    test('framing', () {
      expect(one(const EnemiesAppeared([0])), '적이 출현했다 !!!');
      expect(one(const GoldSettled(216)), '일행은 216개의 금을 얻었다.');
      expect(
        one(const BattleEnded(BattleResultCode.lose)),
        '일행은 모두 전투에서 패했다 !!',
      );
      expect(one(const ActionSkipped(0)), '리라는 잠시 주저했다');
      expect(one(const EscapeSucceeded(0)), '성공적으로 도망을 갔다');
    });

    test('lines the original did not have are marked', () {
      expect(one(const EnemyPoisonTick(0, 50)), startsWith(addedMarker));
      expect(one(const AttackStrained(0, 0, 1)), startsWith(addedMarker));
      expect(one(const MemberHealed(0, 60)), startsWith(addedMarker));
      // 원작에 있던 줄에는 붙지 않는다.
      expect(one(const AttackDeclared(0, 0)), isNot(startsWith(addedMarker)));
    });
  });

  group('colour markup', () {
    test('paintText and withDefaultColor', () {
      expect(paintText(TextColor.white, 30), '@F30@@');
      expect(paintText(TextColor.magenta, 'x'), '@5x@@');
      // 안쪽 @@ 가 바깥 색으로 되돌아간다.
      expect(
        withDefaultColor('적은 @F30@@만큼', TextColor.lightGray),
        '@7적은 @F30@7만큼',
      );
    });
  });

  group('a whole battle through the text', () {
    test('no raw key leaks into a line', () {
      const mage = CombatantSnapshot(
        slot: 0,
        name: '리라',
        family: Family.mage,
        level: 10,
        mentality: 18,
        concentration: 20,
        endurance: 12,
        accuracy: 19,
        agility: 15,
        luck: 10,
        skills: [100, 100, 100, 100, 100, 100],
        hp: 1200,
        maxHp: 1200,
        mp: 1800,
        maxMp: 1800,
      );
      final battle = Battle(
        const BattleSetup(
          party: [mage],
          enemyKeys: ['orc_soldier', 'troll_hunter', 'kobold_wizard'],
          seed: 5,
          initialGap: 0,
        ),
      );
      final names = LoreBattleNames(battle);
      final lines = <String>[];
      var round = 0;
      var guard = 0;
      while (!battle.isFinished && guard++ < 3000) {
        final d = battle.pendingDecision;
        final events = d == null
            ? battle.advance()
            : battle.applyCommand(switch (d) {
                ActionDecision() => ChooseAction(
                  d.slot,
                  BattleAction.castSkill,
                ),
                // 소환 → 전체 공격 → 단일 공격을 번갈아.
                SpellDecision() => ChooseSpell(
                  d.slot,
                  const [601, 202, 103][round++ % 3],
                ),
                EnemyTargetDecision() => ChooseEnemyTarget(
                  d.slot,
                  d.enemyIndices.first,
                ),
                _ => CancelChoice(d.slot),
              });
        for (final e in events) {
          lines.addAll(battleLines(e, names));
        }
      }
      expect(battle.isFinished, isTrue);
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line.contains('summon.'), isFalse, reason: line);
        expect(line.contains('enemy.'), isFalse, reason: line);
        expect(line.contains('natural.'), isFalse, reason: line);
        expect(line.contains('orc_soldier'), isFalse, reason: line);
      }
      // 소환수가 스스로 공격한 줄이 이름과 고유 무기로 나온다.
      expect(lines.any((l) => l.contains('화염으로')), isTrue);
    });
  });
}
