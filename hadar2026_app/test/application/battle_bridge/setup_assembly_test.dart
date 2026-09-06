import 'package:flutter_test/flutter_test.dart';
import 'package:hd_battle/hd_battle.dart' as hb;
import 'package:hadar2026_app/application/battle_bridge/setup_assembly.dart';
import 'package:hadar2026_app/application/battle_bridge/weapon_mapping.dart';
import 'package:hadar2026_app/domain/item/item_data.dart';
import 'package:hadar2026_app/domain/item/item_id.dart';
import 'package:hadar2026_app/domain/item/item_type.dart';
import 'package:hadar2026_app/domain/party/party.dart';

/// B3-02 · B3-03 — 두 세계를 잇는 다리. 전투는 RPG 를 모른다.
void main() {
  group('무기는 두 세계가 나눠 갖는다', () {
    test('RPG 는 얼마나 센지, 전투는 어떻게 닿는지', () {
      final party = HDParty();
      final p = party.players[0];
      final snapshot = snapshotOf(p);
      // 시작 파티는 단도를 든다.
      expect(snapshot.powOfWeapon, greaterThan(0), reason: 'RPG 가 정한다');
      expect(snapshot.weaponKey, 'dagger', reason: '전투 표의 키다');
    });

    test('원작 무기 10종이 전부 전투 표에 대응된다', () {
      // 대응이 빠지면 그 무기는 조용히 맨손이 된다 — 침묵 실패다.
      const names = [
        '맨손',
        '단도',
        '곤봉',
        '미늘창',
        '장검',
        '철퇴',
        '기병창',
        '도끼창',
        '삼지창',
        '화염검',
      ];
      for (final item in itemTable) {
        if (!names.contains(item.name)) continue;
        final key = weaponKeyOf(item.id);
        expect(isKnownWeaponKey(key), isTrue, reason: '${item.name} → $key');
        if (item.name != '맨손') {
          expect(key, isNot('unarmed'), reason: '${item.name} 이 맨손이 됐다');
        }
      }
    });

    test('모르는 무기는 던지지 않고 종류에서 유도된다', () {
      final key = weaponKeyOf(const HDItemId(HDItemType.chop, index: 99));
      expect(isKnownWeaponKey(key), isTrue);
    });

    test('빈 손은 맨손이다', () {
      expect(weaponKeyOf(null), 'unarmed');
      expect(weaponNameOf(null), '맨손');
    });
  });

  group('개시 입력', () {
    test('이름 없는 슬롯은 넘어가지 않는다', () {
      final party = HDParty();
      final setup = assembleSetup(
        party: party,
        enemyKeys: const ['orc'],
        seed: 1,
      );
      expect(setup.party.length, lessThan(party.players.length));
      expect(setup.party.every((c) => c.name.isNotEmpty), isTrue);
    });

    test('정원은 넘어간다 — 전투가 합류를 판정하려면 필요하다', () {
      final setup = assembleSetup(
        party: HDParty(),
        enemyKeys: const ['orc'],
        seed: 1,
      );
      expect(setup.partyCapacity, 6);
    });

    test('슬롯이 열로 풀린다 — 앞·중·뒤', () {
      final party = HDParty();
      expect(rankOf(party.players[0]), 1);
      expect(rankOf(party.players[2]), 2);
      expect(rankOf(party.players[5]), 3);
    });

    test('조립한 입력으로 전투가 실제로 끝까지 돈다', () {
      final battle = hb.Battle(
        assembleSetup(
          party: HDParty(),
          enemyKeys: const ['orc', 'orc'],
          seed: 3,
        ),
      );
      var guard = 0;
      while (!battle.isFinished && guard++ < 3000) {
        final d = battle.pendingDecision;
        if (d == null) {
          battle.advance();
          continue;
        }
        battle.applyCommand(switch (d) {
          hb.ActionDecision() => hb.ChooseAction(
            d.slot,
            hb.BattleAction.attack,
          ),
          hb.EnemyTargetDecision() => hb.ChooseEnemyTarget(
            d.slot,
            d.enemyIndices.first,
          ),
          _ => hb.CancelChoice(d.slot),
        });
      }
      expect(battle.isFinished, isTrue);
      expect(battle.outcome, isNotNull);
    });
  });

  group('정산 반영', () {
    test('슬롯별 상태가 정확히 한 번 되쓰인다', () {
      final party = HDParty();
      final before = party.players[0].hp;
      applyOutcome(
        party,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.win,
          combatants: [
            hb.CombatantResult(
              slot: 0,
              hp: 42,
              sp: 7,
              esp: 3,
              poison: 1,
              unconscious: 0,
              dead: 0,
              experienceGained: 100,
            ),
          ],
          goldGained: 15,
        ),
      );
      expect(before, isNot(42));
      expect(party.players[0].hp, 42);
      expect(party.players[0].poison, 1);
      expect(party.players[0].experience, 100);
    });

    test('골드가 더해진다', () {
      final party = HDParty();
      final before = party.gold;
      applyOutcome(
        party,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.win,
          combatants: [],
          goldGained: 15,
        ),
      );
      expect(party.gold, before + 15);
    });

    test('끌려간 슬롯은 비워진다 — 죽음이 아니라 부재다', () {
      final party = HDParty();
      expect(party.players[0].isValid(), isTrue);
      applyOutcome(
        party,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.lose,
          combatants: [],
          goldGained: 0,
          departedSlots: [0],
        ),
      );
      expect(party.players[0].isValid(), isFalse);
    });

    test('합류한 파티원이 그 슬롯에 들어간다', () {
      final party = HDParty();
      applyOutcome(
        party,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.win,
          combatants: [],
          goldGained: 0,
          recruits: [
            hb.CombatantSnapshot(slot: 5, name: 'Phantom', hp: 20, maxHp: 24),
          ],
        ),
      );
      expect(party.players[5].name.text, 'Phantom');
      expect(party.players[5].hp, 20);
    });

    test('레벨업은 하지 않는다 — 경험치만 더한다 (B3-05)', () {
      final party = HDParty();
      final level = party.players[0].level.physical;
      applyOutcome(
        party,
        const hb.BattleOutcome(
          resultCode: hb.BattleResultCode.win,
          goldGained: 0,
          combatants: [
            hb.CombatantResult(
              slot: 0,
              hp: 1,
              sp: 0,
              esp: 0,
              poison: 0,
              unconscious: 0,
              dead: 0,
              experienceGained: 999999,
            ),
          ],
        ),
      );
      expect(party.players[0].level.physical, level);
      expect(party.players[0].experience, 999999);
    });
  });
}
