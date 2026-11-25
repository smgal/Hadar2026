import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lore_world/lore_world.dart';
import 'package:lore_world_text/lore_world_text.dart' as wt;
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';
import 'dev/dev_jump.dart';
import 'dev/dev_mode.dart';
import 'field_rules.dart';
import 'game_reload_exception.dart';
import 'game_session.dart';
import 'ports/host_binding.dart';
import 'ports/ui_host.dart';
import 'save_manager.dart';
import 'scripting/script_engine_adapter.dart';
import 'tile_event_dispatcher.dart';
import 'world_text.dart';

/// 제목 화면 — 편 고르기 · 캐릭터 만들기 · 이어 하기 · 끝난 뒤 돌아오기.
///
/// 세 편이 한 앱에 들어 있다. 편마다 따로 새로 시작하고, 인물과 진행은
/// 편끼리 이어지지 않는다(원작과 같다). **규칙은 세 편이 같다** — 제3부의
/// 시스템이다(기획서 `1st/07` · `2nd/07`).
///
/// 맵이 없는 동안 도는 흐름이라 화면은 맵 자리에 제목 그림을 놓는다
/// (`HDTitlePanel`). 글과 물음은 게임 중과 같은 창을 쓴다.
class HDTitleFlow {
  static final HDTitleFlow _instance = HDTitleFlow._internal();
  factory HDTitleFlow() => _instance;
  HDTitleFlow._internal();

  UiHost get _ui => HDHosts().ui;
  HDGameSession get _session => HDGameSession();

  bool _running = false;

  // 개발자 모드 줄 — 최종 배포 때 `HDDevMode.switchOnTitle` 을 끄면 켜고 끄는 줄이 사라진다.
  static const String devJumpLabel = '[개발] 시나리오 중간에서 시작';
  static const String devOnLabel = '[개발] 개발자 모드 켜기';
  static const String devOffLabel = '[개발] 개발자 모드 끄기';

  static const List<String> episodeTitles = [
    '제1부 「또 다른 지식의 성전」',
    '제2부 「다크 메이지 실리안 카미너스」',
    '제3부 「비전 속으로」',
  ];

  /// 제목 화면을 돈다. 게임이 시작되면(맵으로 가는 길이 정해지면) 끝난다.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    _ui.beginNarrative();
    // 맵을 옮기는 도중에는 「맵도 없고 갈 곳도 없는」 순간이 있다 — 그때
    // 메뉴를 다시 열면 안 된다. 그래서 이동을 한 번이라도 요청했으면 끝낸다.
    final requestsAtStart = HDScriptEngine().navigationRequests;
    var initial = 3;
    try {
      while (_session.map == null &&
          HDScriptEngine().pendingNavigation == null &&
          HDScriptEngine().navigationRequests == requestsAtStart) {
        _ui.clearLogs();
        final dev = HDDevMode().enabled;
        final items = [
          '또 다른 지식의 성전 3부작',
          ...episodeTitles,
          '이전의 게임 계속하기',
          '이 게임 제작의 개요',
          if (dev) devJumpLabel,
          if (HDDevMode.switchOnTitle) dev ? devOffLabel : devOnLabel,
        ];
        final picked = await _ui.showWindowMenu(items, initialChoice: initial, x: 300, y: 90);
        initial = 3;
        if (HDDevMode.switchOnTitle && picked == items.length - 1) {
          // 켜면 바로 아래 줄에 「시나리오 중간에서 시작」이 생긴다 — 커서를 거기에 둔다.
          // 끄면 같은 자리에 「켜기」가 온다. 어느 쪽이든 여섯째 줄이다.
          await HDDevMode().setEnabled(!dev);
          initial = 6;
          continue;
        }
        switch (picked) {
          case 1 || 2 || 3:
            await startEpisode(picked);
          case 4:
            await _continueGame();
          case 5:
            await _showCredits();
          case 6 when dev:
            await HDDevJump().pickAndJump();
        }
      }
    } on GameReloadException {
      // 불러왔다 — 제목 화면을 접는다.
    } finally {
      _running = false;
      await _ui.endNarrative(autoFlush: false);
    }
  }

  Future<void> _continueGame() async {
    final labels = <String>[];
    final slots = <int>[];
    for (var i = 0; i < HDSaveManager.slotCount; i++) {
      final s = await HDSaveManager.summary(i);
      if (s == null) continue;
      slots.add(i);
      labels.add(
        '제${s.episode}부  ${s.name} · ${s.mapTitle} · '
        '${s.year}년 ${s.month}월 ${s.day}일',
      );
    }
    if (slots.isEmpty) {
      await _ui.addLog('저장된 데이타가 없습니다!');
      await _ui.waitForAnyKey();
      return;
    }
    final picked = await _ui.showWindowMenu([
      '불러 내고 싶은 게임을 선택하십시오.',
      ...labels,
    ]);
    if (picked <= 0) return;
    await _ui.addLog('저장했던 게임을 다시 불러옵니다');
    if (await HDSaveManager.loadGame(slots[picked - 1])) {
      _session.sessionId++;
      _ui.clearLogs();
    } else {
      await _ui.addLog('저장된 데이타가 없습니다!');
      await _ui.waitForAnyKey();
    }
  }

  Future<void> _showCredits() async {
    _ui.clearLogs();
    for (final line in const [
      '@E시나리오 & 프로그래밍 & 그래픽@@',
      '    : 안 영기',
      '@E배경 음악 & 음향 효과@@',
      '    : 국내외의 실력 있는 편곡자님들',
      '             ( 이름은 잘 모름 )',
      '@E도움을 주신 분@@',
      '    : 안 영훈',
      '',
      '제1부 「또 다른 지식의 성전」 1993',
      '제2부 「다크 메이지 실리안 카미너스」 1994',
      '제3부 「비전 속으로」 1995',
      '    제작 기간 : 1995년 2월 1일 저녁부터 2월 12일 새벽까지',
    ]) {
      await _ui.addLog(line);
    }
    await _ui.waitForAnyKey();
  }

  // ─────────────────────────────────────────────── 새로 시작하기

  /// [episode] 편을 새로 시작한다: 여는 글 → 캐릭터 만들기 → `FLAG_START`.
  Future<void> startEpisode(int episode) async {
    final ep = Episode.fromNumber(episode);
    final engine = HDScriptEngine();
    if (ep == null || !await engine.loadEpisode(episode)) {
      _ui.clearLogs();
      await _ui.addLog('${episodeTitles[(episode - 1).clamp(0, 2)]}은 아직 준비 중입니다.');
      await _ui.waitForAnyKey();
      return;
    }

    // 주인공이 아직 없다 — 여는 글이 `{주인공}` 을 쓰지 않도록 빈 세계에서 돈다.
    _session.party.world = LoreWorld(episode: ep);
    _session.gameOption.reset();
    _ui.clearLogs();
    await HDTileEventDispatcher().runExclusive(
      () => engine.runEpisode(HDScriptMode.opening),
    );

    final hero = await _createCharacter();
    if (hero == null) return; // 그만뒀다 — 제목 화면으로

    _session.sessionId++;
    _session.party.world = LoreWorld.newGame(ep, hero);
    _session.gameOption.reset();
    _session.timer = null;
    _session.party.notifyListeners();
    _ui.clearLogs();
    if (ep == Episode.ep1 && !await _pickInitialCompanionsEp1()) return;

    final requestsBefore = engine.navigationRequests;
    await HDTileEventDispatcher().runExclusive(
      () => engine.runEpisode(HDScriptMode.start),
    );
    if (engine.navigationRequests == requestsBefore) {
      // 스크립트가 어디로도 보내지 않았다 — 조용히 제목에 머무르면 멈춘
      // 것처럼 보이므로 알린다.
      await _ui.addLog('@C시작 지점이 정해지지 않았습니다 (episode.cm2 의 FLAG_START).@@');
      await _ui.waitForAnyKey();
    }
  }

  /// 제1부 생성의 마지막 단계 (1st/04 §4.2): 「당신과 동행하게 될 4명의 용사를
  /// 아래에서 골라 주십시오.」 — 열 명 중 넷을 2~5번에 앉힌다. 고를 때마다
  /// 그 사람의 능력치를 보이고 확인을 받는다. 아무도 고르지 않은 채 Esc 면
  /// 그만둔다(false — 제목 화면으로), 고르던 중의 Esc 는 처음부터 다시 고른다.
  Future<bool> _pickInitialCompanionsEp1() async {
    final world = _session.party.world;
    while (true) {
      _ui.clearLogs();
      await _ui.addLog('당신과 동행하게 될 4명의 용사를 아래에서 골라 주십시오.');
      final picked = <String>[];
      var restart = false;
      while (picked.length < 4) {
        final left = [
          for (final k in initialCompanionsEp1)
            if (!picked.contains(k)) k,
        ];
        final members = [for (final k in left) rosterEp1[k]!.build()];
        final choice = await _ui.showWindowMenu([
          '동행할 용사 (${picked.length + 1}/4)',
          for (final m in members)
            '${wt.memberName(m, episode: Episode.ep1)} — ${wt.className(m)}',
        ]);
        if (choice <= 0) {
          if (picked.isEmpty) return false;
          restart = true;
          break;
        }
        final m = members[choice - 1];
        final stats = [
          for (final a in Ability.values) '${wt.abilityName(a)} ${m.ability(a)}',
        ].join(' · ');
        _ui.clearLogs();
        await _ui.addLog(
          '${wt.memberName(m, episode: Episode.ep1)} (${wt.genderName(m.gender)} · ${wt.className(m)})',
        );
        await _ui.addLog(stats);
        final ok = await _ui.showWindowMenu(['이 사람을 일행에 참석시킬까요?', '예', '아니오']);
        if (ok == 1) picked.add(left[choice - 1]);
        _ui.clearLogs();
        await _ui.addLog('당신과 동행하게 될 4명의 용사를 아래에서 골라 주십시오.');
      }
      if (restart) continue;
      for (final k in picked) {
        world.join(rosterEp1[k]!.build());
      }
      _session.party.notifyListeners();
      _ui.clearLogs();
      return true;
    }
  }

  /// 주인공을 만든다 (제7장 7.5). 그만두면 null.
  Future<Member?> _createCharacter() async {
    // ① 이름
    String name;
    while (true) {
      final typed = await _ui.askText('당신의 이름 :', maxLength: maxNameWidth);
      if (typed == null) return null;
      name = typed.trim();
      if (name.isEmpty) continue;
      if (nameWidth(name) > maxNameWidth) {
        await _ui.showMessageWindow('이름은 한글 4자 또는 영문 8자까지입니다.');
        continue;
      }
      break;
    }

    // ② 성별
    final g = await _ui.showWindowMenu(['당신의 성별은?', '남성', '여성']);
    if (g <= 0) return null;
    final gender = g == 1 ? Gender.male : Gender.female;

    // ③ 성격 질문 열 개 — 질문마다 두 가지 판 중 하나가 나온다.
    _ui.clearLogs();
    await _ui.addLog('지금부터는 묻는 말에 대답을 해 주십시오. 그리고, 자신에게 맞는 답을 소신 있게 눌러 주십시오.');
    await _ui.waitForAnyKey();
    final variants = pickQuestionVariants(HDFieldRules().rng);
    final answers = <int>[];
    for (var i = 0; i < questionCount; i++) {
      _ui.clearLogs();
      await _ui.addLog('@E질문 ${i + 1} / $questionCount@@');
      await _ui.addLog(questionText(i, variants[i]));
      final picked = await _ui.showWindowMenu([
        '당신의 선택은?',
        ...questionChoices(i, variants[i]),
      ], x: 300, y: 250);
      if (picked <= 0) return null;
      answers.add(picked);
    }
    final preview = previewCreation(answers: answers, gender: gender);
    if (preview == null) return null;

    // ④ 민첩성 · 정확성 · 행운에 40점
    Future<void> showAbilities(List<int> three) async {
      _ui.clearLogs();
      const labels = ['체력', '정신력', '집중력', '인내력', '저항력'];
      for (var i = 0; i < 5; i++) {
        await _ui.addLog('${labels[i].padRight(4)} : ${preview.abilities[i]}');
      }
      await _ui.addLog('');
      await _ui.addLog('체력 지수 : ${preview.hp}    마법 지수 : ${preview.mp}    레벨 : 1');
      await _ui.addLog('계열 : ${familyName(preview.family)}');
      await _ui.addLog('');
      final left = freePoints - three.fold<int>(0, (a, b) => a + b);
      await _ui.addLog('남아 있는 지수 : $left');
      const three3 = ['민첩성', '정확성', '행운'];
      for (var i = 0; i < three.length; i++) {
        await _ui.addLog('${three3[i].padRight(4)} : ${three[i]}');
      }
    }

    late int agility, accuracy, luck;
    while (true) {
      await showAbilities(const []);
      // 나머지 둘이 각각 20 을 넘지 않으려면 지금 고르는 값에 하한이 생긴다.
      final a = await _pickNumber('민첩성에 줄 점수', 0, abilityCap);
      if (a == null) return null;
      await showAbilities([a]);
      final lo = (freePoints - a - abilityCap).clamp(0, abilityCap);
      final hi = (freePoints - a).clamp(0, abilityCap);
      final b = await _pickNumber('정확성에 줄 점수', lo, hi);
      if (b == null) continue;
      agility = a;
      accuracy = b;
      luck = freePoints - a - b;
      await showAbilities([agility, accuracy, luck]);
      final ok = await _ui.showWindowMenu(['이대로 하겠습니까?', '그렇습니다', '다시 나눈다']);
      if (ok == 1) break;
      if (ok <= 0) return null;
    }

    // ⑤ 계급과 기술치
    final choice = await _pickClassAndSkills(preview.family);
    if (choice == null) return null;

    // ⑥ 확인
    final sure = await _ui.showWindowMenu([
      '당신이 만든 캐릭터에 만족합니까?',
      '그렇습니다',
      '아닙니다',
    ]);
    if (sure != 1) return null;

    final result = createCharacter(
      CreationInput(
        name: name,
        gender: gender,
        answers: answers,
        agility: agility,
        accuracy: accuracy,
        luck: luck,
        skills: choice.$2,
        classId: choice.$1,
      ),
    );
    if (!result.ok) {
      debugPrint('[title] character creation refused: ${result.refusal}');
      await _ui.showMessageWindow('캐릭터를 만들지 못했습니다. 처음부터 다시 해 주십시오.');
      return null;
    }
    return result.member;
  }

  Future<int?> _pickNumber(String prompt, int lo, int hi) async {
    final picked = await _ui.showWindowMenu([
      '$prompt ($lo ~ $hi)',
      for (var n = lo; n <= hi; n++) '$n',
    ], initialChoice: ((hi - lo) ~/ 2) + 1, x: 300, y: 200);
    return picked <= 0 ? null : lo + picked - 1;
  }

  /// 계급을 고르고 기술치 60점을 나눈다. (계급 번호, 기술치 여섯).
  ///
  /// 원작은 여섯 기술치가 10 에서 시작하고 서로 점수를 옮기다 보면 조건이
  /// 맞는 계급이 밝아졌다. 여기서는 **계급을 먼저 고르고** 그 계급의 조건을
  /// 채운 뒤 남는 점수를 나눈다 — 닿는 결과는 같고 헛짚는 일이 없다.
  Future<(int, List<int>)?> _pickClassAndSkills(Family family) async {
    final classes = [
      for (final c in selectableClasses(family))
        if (c.requirements.fold<int>(0, (a, b) => a + b) <= skillPoints) c,
    ];
    while (true) {
      _ui.clearLogs();
      await _ui.addLog('당신의 계열은 @E${familyName(family)}@@입니다. 계급을 고르십시오.');
      final picked = await _ui.showWindowMenu([
        '계급을 고르십시오',
        for (final c in classes) classNameOf(family, c.id),
      ], x: 300, y: 120);
      if (picked <= 0) return null;
      final clazz = classes[picked - 1];
      final skills = List<int>.of(clazz.requirements);
      var left = skillPoints - skills.fold<int>(0, (a, b) => a + b);

      var restart = false;
      while (left > 0) {
        _ui.clearLogs();
        await _ui.addLog('@E${classNameOf(family, clazz.id)}@@ — 남은 점수 : $left');
        final trainable = [
          for (var i = 0; i < 6; i++)
            if (clazz.caps[i] > 0) i,
        ];
        final where = await _ui.showWindowMenu([
          '어느 기술에 점수를 더하겠습니까?',
          for (final i in trainable)
            '${skillNameOf(family, clazz.id, i).padRight(10)} ${skills[i]}',
          '계급을 다시 고른다',
        ], x: 300, y: 120);
        if (where <= 0 || where > trainable.length) {
          restart = true;
          break;
        }
        final add = left < 5 ? left : 5;
        skills[trainable[where - 1]] += add;
        left -= add;
      }
      if (!restart) return (clazz.id, skills);
    }
  }

  // ──────────────────────────────────────────────── 끝난 뒤

  static const String _endingsKey = 'lore2026_endings';

  /// 본 엔딩을 적고 종료 화면을 낸 뒤 제목으로 돌아간다. 엔딩의 글은
  /// 스크립트가 이미 냈다.
  Future<void> finishWithEnding(String which) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_endingsKey) ?? <String>[];
      final tag = 'ep${_session.episode}:$which';
      if (!seen.contains(tag)) {
        await prefs.setStringList(_endingsKey, [...seen, tag]);
      }
    } catch (e) {
      debugPrint('[title] could not record the ending: $e');
    }

    await _ui.fade(out: true);
    _ui.clearLogs();
    await _ui.fade(out: false, milliseconds: 200);
    await _ui.addLog('');
    await _ui.addLog('            @F<< The End >>@@');
    await _ui.addLog('');
    await _ui.addLog('@EYou must be a genius !!!@@');
    await _ui.waitForAnyKey();
    await returnToTitle();
  }

  /// 게임을 접고 제목 화면으로. [farewell] 이면 원작의 작별 인사를 낸다.
  Future<void> returnToTitle({bool farewell = false}) async {
    if (farewell) {
      _ui.clearLogs();
      await _ui.addLog('@EFeel your RPG imagination !!@@');
      await _ui.waitForAnyKey();
    }
    HDAudio().stopMusic();
    _session.resetToTitle();
    _ui.clearLogs();
    // 지금 도는 흐름(스크립트 · 메뉴)이 다 접힌 뒤에 제목 화면을 연다.
    unawaited(Future<void>.delayed(Duration.zero, run));
  }
}
