import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hd_battle/hd_battle.dart' as hb;

import 'hd_config.dart';
import 'presentation/panels/battle/battle_controller.dart';
import 'presentation/panels/battle/battle_screen.dart';

/// 전투 실험실 — 전투만 도는 별도 진입점 (B4-01).
///
/// ```bash
/// cd hadar2026_app
/// flutter run -t lib/battle_lab_main.dart              # 데스크톱
/// flutter run -d chrome -t lib/battle_lab_main.dart    # 브라우저
/// ```
///
/// ## 왜 게임과 따로인가
///
/// 전투를 손보려면 **전투만** 띄울 수 있어야 한다. 지도를 걷고 조우를
/// 만들어야 한 판을 볼 수 있으면 같은 상황을 두 번 만들 수 없고, 밸런스든
/// 재미든 판단할 수가 없다.
///
/// 그래서 콘솔이 쓰는 **그 fixture 파일 그대로** 읽는다
/// (`hd_battle_console/fixtures/` → `assets/battle/`, 저작은 한 곳).
/// RPG · 지도 · cm2 를 하나도 건드리지 않는다.
///
/// 화면 위젯(`HDBattleScreen`)은 게임 안에서 쓸 것과 같은 것이다 —
/// 여기서 다듬은 것이 그대로 B4-02 로 간다.
void main() {
  runApp(const BattleLabApp());
}

class BattleLabApp extends StatelessWidget {
  const BattleLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '전투 실험실',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'DungGeunMo',
      ),
      home: const _Lab(),
    );
  }
}

/// 색인 한 줄.
class _Entry {
  const _Entry({required this.path, required this.name, required this.note});

  final String path;
  final String name;
  final String note;
}

class _Lab extends StatefulWidget {
  const _Lab();

  @override
  State<_Lab> createState() => _LabState();
}

class _LabState extends State<_Lab> {
  List<_Entry>? _index;
  HDBattleController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    try {
      final raw = await rootBundle.loadString('assets/battle/index.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _index = [
          for (final e in list)
            _Entry(
              path: e['path'] as String,
              name: e['name'] as String? ?? e['path'] as String,
              note: e['note'] as String? ?? '',
            ),
        ];
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _open(_Entry entry) async {
    try {
      final raw = await rootBundle.loadString('assets/battle/${entry.path}');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // 명령 열은 무시한다 — 여기서는 사람이 직접 둔다.
      final setup = hb.BattleSetup.fromJson(
        json['setup'] as Map<String, dynamic>,
      );
      final controller = HDBattleController(setup)..start();
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _close() {
    _controller?.dispose();
    setState(() => _controller = null);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: HDConfig.gameScreenWidth,
            height: HDConfig.gameScreenHeight,
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'fixture 를 못 읽었다\n$_error\n\n'
            'hd_battle_console 에서 `dart run tool/make_fixtures.dart` 를 '
            '한 번 돌리면 assets/battle 이 채워진다.',
            style: const TextStyle(color: Color(0xFFFF8080), fontSize: 14),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller != null) {
      return HDBattleScreen(controller: controller, onExit: _close);
    }
    final index = _index;
    if (index == null) {
      return const Center(
        child: Text('불러오는 중…', style: TextStyle(color: Colors.white)),
      );
    }
    return _FixtureList(entries: index, onPick: _open);
  }
}

class _FixtureList extends StatelessWidget {
  const _FixtureList({required this.entries, required this.onPick});

  final List<_Entry> entries;
  final void Function(_Entry) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '전투 실험실 — 어느 판을 볼까',
            style: TextStyle(color: Color(0xFFFFFF00), fontSize: 18),
          ),
          const SizedBox(height: 2),
          const Text(
            'hd_battle_console 과 같은 fixture 다. 규칙은 packages/hd_battle.',
            style: TextStyle(color: Color(0xFF808080), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                // note 는 여러 줄이라 목록에서는 첫 줄만 쓴다.
                final summary = e.note.split('\n').first;
                return InkWell(
                  onTap: () => onPick(e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 210,
                          child: Text(
                            e.path,
                            style: const TextStyle(
                              color: Color(0xFF60A0FF),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 230,
                          child: Text(
                            e.name,
                            style: const TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF707070),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
