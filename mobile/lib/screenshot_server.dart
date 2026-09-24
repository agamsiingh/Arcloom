// Dedicated screenshot capture server for automated raw screenshot generation.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/levels.dart';
import 'game/game_screen.dart';
import 'game/session.dart';
import 'services/progress.dart';
import 'services/services.dart';
import 'ui/daily_screen.dart';
import 'ui/game_dialogs.dart';
import 'ui/home_screen.dart';
import 'main.dart';

int currentScreenId = 1;
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> screenNotifier = ValueNotifier<int>(1);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final sv = await bootstrap();
  // Ensure ad-free and populate realistic progress for screenshots
  sv.data.adFree = true;
  sv.data.unlocked = 52;
  sv.data.hints = 8;
  sv.data.seenTips.addAll(List.generate(160, (i) => i + 1));
  
  // Set up some level progress
  for (var i = 1; i <= 51; i++) {
    sv.data.levels[i] = LevelRecord(stars: 3, score: 3200 + i * 45, wonAt: DateTime.now().millisecondsSinceEpoch);
  }
  
  // Daily progress
  final today = DateTime.now();
  final todayKey = dateKey(today);
  sv.data.daily.streak = 7;
  sv.data.daily.best = 14;
  
  // Start server on 8888
  startHttpServer();

  runApp(const ScreenshotApp());
}

void startHttpServer() async {
  try {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 8888);
    debugPrint('SCREENSHOT_SERVER: Listening on port 8888');
    server.listen((HttpRequest request) async {
      final uri = request.uri;
      final screenParam = uri.queryParameters['screen'];
      if (screenParam != null) {
        final id = int.tryParse(screenParam) ?? 1;
        screenNotifier.value = id;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('OK: screen $id');
        await request.response.close();
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('Current: ${screenNotifier.value}');
        await request.response.close();
      }
    });
  } catch (e) {
    debugPrint('SCREENSHOT_SERVER: Error: $e');
  }
}

class ScreenshotApp extends StatefulWidget {
  const ScreenshotApp({super.key});

  @override
  State<ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: screenNotifier,
      builder: (context, screenId, _) {
        final sv = Services.I;
        
        // Configure theme per screen
        if (screenId == 11) {
          sv.data.settings.theme = 'amoled';
        } else {
          sv.data.settings.theme = 'light';
        }

        // Configure mode per screen
        if (screenId == 9) {
          sv.data.settings.mode = 'zen';
        } else {
          sv.data.settings.mode = 'challenge';
        }

        return ListenableBuilder(
          listenable: sv.store,
          builder: (context, _) {
            final st = sv.data.settings;
            final hc = st.highContrast;
            final fixed = st.theme != 'system';
            final light = Palette.resolve(fixed ? st.theme : 'light', systemDark: false, highContrast: hc);
            final dark = Palette.resolve(fixed ? st.theme : 'dark', systemDark: true, highContrast: hc);

            Widget screenWidget;
            switch (screenId) {
              case 1:
                screenWidget = const HomeScreen();
                break;
              case 2:
                screenWidget = const GameScreen(args: GameArgs.level(1));
                break;
              case 3:
                screenWidget = const GameScreen(args: GameArgs.level(10));
                break;
              case 4:
                screenWidget = const GameScreen(args: GameArgs.level(50));
                break;
              case 5:
                screenWidget = const GameScreen(args: GameArgs.level(100));
                break;
              case 6:
                screenWidget = const GameScreen(args: GameArgs.level(150));
                break;
              case 7:
                // Daily Challenge gameplay
                screenWidget = GameScreen(args: GameArgs.daily(dateKey(DateTime.now())));
                break;
              case 8:
                // Level-complete / 3-star screen
                screenWidget = const _WinDialogMockScreen();
                break;
              case 9:
                // Zen Mode (level 28)
                screenWidget = const GameScreen(args: GameArgs.level(28));
                break;
              case 10:
                // Challenge Mode (level 35) with hearts & combo
                screenWidget = const _ChallengeModeMockScreen();
                break;
              case 11:
                // AMOLED Dark theme (level 50 or 65)
                screenWidget = const GameScreen(args: GameArgs.level(50));
                break;
              case 12:
                // Visually impressive special-mechanic level (level 66: color walls + rotators)
                screenWidget = const GameScreen(args: GameArgs.level(66));
                break;
              default:
                screenWidget = const HomeScreen();
            }

            return MaterialApp(
              key: ValueKey('screen-$screenId-${st.theme}'),
              title: 'arcloom',
              debugShowCheckedModeBanner: false,
              theme: light.toTheme(st.textScale),
              darkTheme: dark.toTheme(st.textScale),
              themeMode: fixed ? ThemeMode.light : ThemeMode.system,
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                final scale = (mq.textScaler.scale(1) * st.textScale).clamp(0.85, 1.6);
                final pal = context.pal;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: (pal.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: pal.bg,
                    systemNavigationBarIconBrightness: pal.dark ? Brightness.light : Brightness.dark,
                  ),
                  child: MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child!),
                );
              },
              home: screenWidget,
            );
          },
        );
      },
    );
  }
}

/// Helper screen to showcase the 3-star victory dialog cleanly
class _WinDialogMockScreen extends StatefulWidget {
  const _WinDialogMockScreen();

  @override
  State<_WinDialogMockScreen> createState() => _WinDialogMockScreenState();
}

class _WinDialogMockScreenState extends State<_WinDialogMockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showWinDialog(
        context,
        res: const Results(stars: 3, score: 4850, moves: 12, par: 12, timeMs: 18400, mistakes: 0, undoCount: 0, perfect: true),
        rec: const WinRecord(newBestScore: true, newBestStars: true, firstClear: false),
        isDaily: false,
        streak: 7,
        hasNext: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const GameScreen(args: GameArgs.level(10));
  }
}

/// Helper screen to showcase challenge mode with combo active
class _ChallengeModeMockScreen extends StatefulWidget {
  const _ChallengeModeMockScreen();

  @override
  State<_ChallengeModeMockScreen> createState() => _ChallengeModeMockScreenState();
}

class _ChallengeModeMockScreenState extends State<_ChallengeModeMockScreen> {
  @override
  Widget build(BuildContext context) {
    return const GameScreen(args: GameArgs.level(36));
  }
}
