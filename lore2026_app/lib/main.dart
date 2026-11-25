import 'dart:async';

import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'application/dev/dev_mode.dart';
import 'application/title_flow.dart';
import 'hd_game_main.dart';
import 'hd_config.dart';
import 'presentation/panels/map_viewport.dart';
import 'presentation/panels/window_view.dart';
import 'presentation/panels/console_panel.dart';
import 'presentation/panels/input_panel.dart';
import 'presentation/panels/status_panel.dart';
import 'presentation/panels/bottom_control_panel.dart';
import 'presentation/panels/title_panel.dart';
import 'presentation/host/flutter_ui_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.fullScreen();
  await Flame.device.setLandscape();

  // Window Manager setup for Windows/Desktop
  try {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(816, 519), // Account for Windows borders (approx 16x39)
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "Lore Trilogy 2026",
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint("WindowManager not available on this platform");
  }

  // 개발자 모드 — 웹은 주소의 ?dev=1, 실행은 --dart-define=LORE_DEV=true
  await HDDevMode().init(
    query: Uri.base.queryParameters['dev'],
    define: const bool.fromEnvironment('LORE_DEV'),
  );

  runApp(const LoreApp());
}

class LoreApp extends StatelessWidget {
  const LoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '또 다른 지식의 성전 3부작',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        // Single embedded font for the entire UI. Widgets that don't
        // override TextStyle.fontFamily inherit this from the theme.
        fontFamily: 'DungGeunMo',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    HDGameMain().addListener(_onGameChanged);
    _initGame();
  }

  @override
  void dispose() {
    HDGameMain().removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() {
    if (HDGameMain().map == null && HDGameMain().hasPendingNavigation) {
      _loadPendingMap();
    }
    // 맵이 놓이면 곧바로 보여 준다. 그 맵의 시작 스크립트가 장면(재판 같은)을
    // 대사와 키 기다림으로 돌리는데, 끝날 때까지 기다렸다 보여 주면 그 장면이
    // 통째로 가려진다.
    if (!_ready && HDGameMain().map != null && mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _loadPendingMap() async {
    if (mounted) setState(() => _ready = false);
    await HDGameMain().navigateToPending();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _initGame() async {
    await HDGameMain().init();
    // 맵 없이 켜진다 — 제목 화면을 연다. 편을 고르면 편 스크립트가
    // `LoadScript` 로 첫 맵을 정하고, 위의 [_onGameChanged] 가 받아 옮긴다.
    if (HDGameMain().map == null && !HDGameMain().hasPendingNavigation) {
      unawaited(HDTitleFlow().run());
    }
    if (mounted) {
      setState(() {
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // **맵이 없는 것은 오류가 아니다.** 제목 화면과 캐릭터 만들기는 맵 없이
    // 돈다 — 그동안은 맵 자리에 제목 그림을 놓는다. 맵을 불러오다 실패한
    // 경우만 그 까닭을 같은 자리에 적는다.

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: HDConfig.gameScreenWidth,
                    height: HDConfig.gameScreenHeight,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            // Top row: map (left) + console (right).
                            Row(
                              children: [
                                SizedBox(
                                  width: HDConfig.mapViewportWidth,
                                  height: HDConfig.mapViewportHeight,
                                  child: ListenableBuilder(
                                    listenable: HDGameMain(),
                                    builder: (context, child) {
                                      final map = HDGameMain().map;
                                      if (map == null) {
                                        return HDTitlePanel(
                                          error: HDGameMain().errorMessage,
                                        );
                                      }
                                      return HDMapViewport(
                                        key: ValueKey(map),
                                        mapModel: map,
                                        party: HDGameMain().party,
                                      );
                                    },
                                  ),
                                ),
                                const HDDialogPanel(),
                              ],
                            ),
                            // Bottom row: status (under map) + description (under dialog).
                            Row(
                              children: const [
                                HDStatusPanel(),
                                HDDescriptionPanel(),
                              ],
                            ),
                          ],
                        ),
                        // Window Layer on top of everything
                        // 지도 칸을 덮는 이름 목록 — 1부의 적 목록(이름만). 원작은 지도 칸을 검게 지우고
                        // 이름을 생명력에 따른 색으로 쓴다 (LOREBATT.PAS:77 DisplayEnemies).
                        Positioned(
                          left: 0,
                          top: 0,
                          width: HDConfig.mapViewportWidth,
                          height: HDConfig.mapViewportHeight,
                          child: const IgnorePointer(child: HDNameListOverlay()),
                        ),
                        // 지도 화면을 덮는 막 — 컷신의 페이드와 섬광. 원작처럼 지도만
                        // 어두워지고 오른쪽 글 창은 그대로 보인다(「화면이 어두워지고
                        // 30분이 흐른다 → 그로부터 30분이 지났다.」). 검은 화면 전체에
                        // 쓰는 글은 편지 화면(`Letter::Show`)이 맡는다.
                        Positioned(
                          left: 0,
                          top: 0,
                          width: HDConfig.mapViewportWidth,
                          height: HDConfig.mapViewportHeight,
                          child: IgnorePointer(
                            child: ValueListenableBuilder<double>(
                              valueListenable: HDFlutterUiHost().screenCover,
                              builder: (context, cover, child) => cover <= 0
                                  ? const SizedBox.shrink()
                                  : Container(
                                      color: HDFlutterUiHost().screenCoverColor
                                          .withValues(alpha: cover.clamp(0, 1)),
                                    ),
                            ),
                          ),
                        ),
                        const HDWindowLayer(),
                      ],
                    ),
                  ),
                ),
              ),
              // 4. Mobile Bottom Control Panel
              const HDBottomControlPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
