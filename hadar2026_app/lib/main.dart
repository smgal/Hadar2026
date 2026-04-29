import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'hd_game_main.dart';
import 'hd_config.dart';
import 'presentation/panels/map_viewport.dart';
import 'presentation/panels/window_view.dart';
import 'presentation/panels/console_panel.dart';
import 'presentation/panels/status_panel.dart';
import 'presentation/panels/bottom_control_panel.dart';

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
      title: "Hadar 2026",
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint("WindowManager not available on this platform");
  }

  runApp(const HadarApp());
}

class HadarApp extends StatelessWidget {
  const HadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hadar 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
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
    _initGame();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initGame() async {
    await HDGameMain().init();
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

    final errorMessage = HDGameMain().errorMessage;
    if (HDGameMain().map == null) {
      return Scaffold(
        body: Center(
          child: Text(
            errorMessage ?? "No Map Loaded",
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

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
                          Row(
                            children: [
                              // 1. Map Viewport
                              SizedBox(
                                width: HDConfig.mapViewportWidth,
                                height: HDConfig.mapViewportHeight,
                                child: ListenableBuilder(
                                  listenable: HDGameMain(),
                                  builder: (context, child) {
                                    final map = HDGameMain().map;
                                    if (map == null) return const SizedBox.shrink();
                                    return HDMapViewport(
                                      key: ValueKey(map),
                                      mapModel: map,
                                      party: HDGameMain().party,
                                    );
                                  },
                                ),
                              ),
                              // 2. Console Panel
                              const HDConsolePanel(),
                            ],
                          ),
                          // 3. Status Panel
                          const HDStatusPanel(),
                        ],
                      ),
                      // Window Layer on top of everything
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

