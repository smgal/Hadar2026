import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore2026_app/application/dev/dev_jump.dart';
import 'package:lore2026_app/application/dev/dev_mode.dart';
import 'package:lore2026_app/application/dev/dev_scenes.dart';
import 'package:lore2026_app/application/game_session.dart';
import 'package:lore2026_app/application/menu_flows.dart';
import 'package:lore2026_app/application/ports/host_binding.dart';
import 'package:lore2026_app/application/scripting/script_engine_adapter.dart';
import 'package:lore2026_app/application/title_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flow/fake_hosts.dart';

/// 개발자 모드 — 장면을 쌓는 규칙과, 제목 화면 · 주 메뉴에서 들어가는 길.
void main() {
  DevSceneBook book(int ep) => DevSceneBook.parse(File('assets/dev/ep$ep.json').readAsStringSync());

  group('쌓기', () {
    test('앞 장면의 플래그·변수가 이어지고, 나중 값이 앞 값을 덮는다', () {
      final s = book(1).resolve('1-37');
      expect(s.flags, containsAll(['ARMORY_USED', 'SKELETON_OFFERED', 'OEDIPUS_SPEAR', 'RIGEL_MET', 'SPICA_TAUGHT']));
      expect(s.vars['LORD_STAGE'], 6);
      expect(s.vars['GAIA_QUEST'], 6);
      expect(s.vars['WATERFIELD_QUEST'], 4);
      expect(s.level, 12);
      expect(s.unlock, containsAll(['esp', 'special_magic']));
    });

    test('「-이름」은 플래그를 끈다 — 2편 귀환 보고가 원정 기록을 지운다', () {
      final before = book(2).resolve('2-25');
      expect(before.flags, containsAll(['TRIP_ARRIVED', 'TRIP_PAPYRUS', 'TRIP_TEMPLE', 'TRIP_DIARY']));
      final after = book(2).resolve('2-26');
      expect(after.flags.intersection({'TRIP_ARRIVED', 'TRIP_PAPYRUS', 'TRIP_TEMPLE', 'TRIP_DIARY'}), isEmpty);
      expect(after.flags, contains('DOME_PAPYRUS_READ')); // 원정과 무관한 기록은 남는다
    });

    test('from 은 앞의 다른 장면에서 이어 쌓는다 — 반역 루트는 충성 루트를 거치지 않는다', () {
      final rebel = book(3).resolve('3-47');
      expect(rebel.vars['ALLEGIANCE'], 2);
      expect(rebel.vars.containsKey('LIGHT_BATTLES_WON'), isFalse);
      expect(rebel.hidden, isTrue);
    });

    test('예약은 그 장면에만 걸린다', () {
      expect(book(3).resolve('3-47').timer, [1, 1]);
      expect(book(3).resolve('3-48').timer, isNull);
    });

    test('주인공을 바꾼 장면 뒤의 본 줄기는 바꾸기 전 장면에서 이어진다', () {
      expect(book(3).resolve('3-35').hero['family'], 'mage');
      expect(book(3).resolve('3-36').hero['family'], 'fighter');
    });
  });

  group('세계 만들기', () {
    test('1편 반신반인 뒤 — 이름 있는 대원 전원이 반신반인, 레벨은 22 이상, 생명력이 가득', () {
      final world = HDDevJump.buildWorld(1, book(1).resolve('1-55'));
      final members = world.presentMembers;
      expect(members.length, 5); // 주인공 + 동료 넷 (드라코니안은 성문에서 즉사했다)
      for (final m in members) {
        expect(m.classId, ClassId.demigod);
        expect(m.level, greaterThanOrEqualTo(22));
        expect(m.hp, m.maxHp);
      }
      // 전투사 계열 주인공은 무기를 들었다
      expect(world.protagonist!.weapon, isNotNull);
    });

    test('3편 반역 직후 — 동료는 숨겨졌을 뿐 자리를 지킨다', () {
      final world = HDDevJump.buildWorld(3, book(3).resolve('3-47'));
      expect(world.presentMembers.length, 1);
      expect(world.seats.whereType<Member>().length, 5);
    });

    test('기술치는 「20 + 레벨 × 5」 — 레벨 12 마법사는 대마법사가 되어 변화 마법 80 (공간 이동)', () {
      final world = HDDevJump.buildWorld(1, book(1).resolve('1-37'));
      final merlin = world.seats[world.seatOfRoster('merlin')!]!;
      expect(merlin.family, Family.mage);
      expect(merlin.classId, ClassId.archmage);
      expect(merlin.skills[MageSkill.change], greaterThanOrEqualTo(80));
    });

    test('레벨 8 아래의 마법사는 계급을 그대로 둔다', () {
      final world = HDDevJump.buildWorld(1, book(1).resolve('1-19'));
      final merlin = world.seats[world.seatOfRoster('merlin')!]!;
      expect(merlin.classId, isNot(ClassId.archmage));
    });
  });

  group('메뉴', () {
    late ScriptedUi ui;
    final session = HDGameSession();
    final engine = HDScriptEngine();
    late int Function(List<String>) answer;

    setUp(() async {
      ui = ScriptedUi((items) => answer(items));
      HDHosts().bind(ui: ui, movement: InstantMovement(session.party.move), assets: DiskAssets());
      await session.init();
      session.resetToTitle();
      HDDevJump().forget();
    });

    tearDown(() {
      HDDevMode().enabled = false;
      HDDevMode().noEncounters = false;
      HDHosts().reset();
    });

    test('개발자 모드가 꺼져 있으면 제목 화면에는 「켜기」 줄만 있다', () async {
      HDDevMode().enabled = false;
      List<String>? title;
      // Esc 를 받으면 제목 메뉴를 다시 연다 — 두 번째에 멈춰 빠져나오지 않도록 막는다
      var calls = 0;
      answer = (items) {
        if (items.first.contains('3부작')) {
          title = items;
          if (++calls > 1) throw StateError('stop');
          return 0;
        }
        return 1;
      };
      await expectLater(HDTitleFlow().run(), throwsStateError);
      expect(title, isNot(contains(HDTitleFlow.devJumpLabel)));
      expect(title!.last, HDTitleFlow.devOnLabel);
    });

    test('제목 화면에서 켜면 바로 「시나리오 중간에서 시작」이 생기고, 다음 실행에도 켜져 있다', () async {
      SharedPreferences.setMockInitialValues({});
      HDDevMode().enabled = false;
      final titles = <List<String>>[];
      answer = (items) {
        if (items.first.contains('3부작')) {
          titles.add(items);
          if (titles.length == 1) return items.indexOf(HDTitleFlow.devOnLabel);
          if (titles.length == 2) return items.indexOf(HDTitleFlow.devOffLabel);
          throw StateError('stop');
        }
        return 0;
      };
      // 켜기 → 끄기 → 멈춤
      await expectLater(HDTitleFlow().run(), throwsStateError);
      expect(titles[1], contains(HDTitleFlow.devJumpLabel));
      expect(titles[1].last, HDTitleFlow.devOffLabel);
      expect(titles[2], isNot(contains(HDTitleFlow.devJumpLabel)));
      expect(HDDevMode().enabled, isFalse);

      // 다시 켜고 앱을 새로 띄운 것처럼 읽는다
      await HDDevMode().setEnabled(true);
      HDDevMode().enabled = false;
      await HDDevMode().init();
      expect(HDDevMode().enabled, isTrue);
    });

    test('제목 화면에서 끄면 「무작위 조우 끄기」도 풀린다', () async {
      SharedPreferences.setMockInitialValues({});
      HDDevMode().enabled = true;
      HDDevMode().noEncounters = true;
      await HDDevMode().setEnabled(false);
      expect(HDDevMode().noEncounters, isFalse);
    });

    test('제목 화면 → [개발] → 3편 → 2장 → 로드안 — 그 자리에 서고 확인할 것이 나온다', () async {
      HDDevMode().enabled = true;
      answer = (items) {
        final q = items.first;
        if (q.contains('3부작')) return items.indexWhere((t) => t.contains('[개발]'));
        if (q.contains('어느 편')) return 3;
        if (q.contains('장을 고르십시오')) return items.indexWhere((t) => t.startsWith('2장'));
        if (q.contains('2장')) return items.indexWhere((t) => t.startsWith('3-04'));
        return 1;
      };
      await HDTitleFlow().run();
      await engine.executePendingNavigation();

      expect(session.mapInfo?.name, 'E3_Lore');
      expect((session.party.x + 1, session.party.y + 1), (51, 31));
      expect(session.episode, 3);
      expect(session.gameOption.flag('PARDONED'), isTrue);
      expect(session.gameOption.variable('MAIN_STAGE'), 2);
      expect(ui.plainLines, contains('[개발] 3-04 로드안 — 원정 명령'));
      expect(ui.plainLines.any((l) => l.startsWith('확인할 것 : ')), isTrue);
    });

    test('2편 월식 장면 — 날짜 변수는 그 장면 시각의 20일 뒤', () async {
      final b = book(2);
      await HDDevJump().jump(b, '2-18');
      await engine.executePendingNavigation();
      final day = session.party.world.calendar.totalSeconds ~/ 86400;
      expect(session.gameOption.variable('ECLIPSE_DAY'), day + 20);
      expect(session.gameOption.variable('LORD_STAGE'), 8);
    });

    test('주 메뉴 → [개발] 개발자 메뉴 → 무작위 조우 끄기', () async {
      HDDevMode().enabled = true;
      await HDDevJump().jump(book(1), '1-26');
      await engine.executePendingNavigation();
      answer = (items) {
        if (items.first.contains('명령을 고르시오')) return items.indexWhere((t) => t.contains('[개발]'));
        if (items.first.contains('[개발] 무엇을')) return items.indexWhere((t) => t.startsWith('무작위 조우'));
        return 1;
      };
      await HDMenuFlows().showMainMenu();
      expect(HDDevMode().noEncounters, isTrue);
      expect(ui.plainLines, contains('[개발] 무작위 조우를 껐다.'));
    });
  });
}
