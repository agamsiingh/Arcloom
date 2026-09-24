// App shell: theming, text scale, system UI styling and lifecycle handling.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/services.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

class ArcloomApp extends StatefulWidget {
  const ArcloomApp({super.key});
  @override
  State<ArcloomApp> createState() => _ArcloomAppState();
}

class _ArcloomAppState extends State<ArcloomApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final sv = Services.I;
    _lifecycle = AppLifecycleListener(
      onHide: () {
        sv.audio.pause();
        unawaited(sv.store.save()); // flush progress before the OS may kill us
      },
      onResume: () {
        sv.audio.resume();
        sv.store.touch(); // date may have changed (daily puzzle / streak display)
        unawaited(sv.ads.start()); // retry if ads could not start earlier (e.g. offline)
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.I.store,
      builder: (context, _) {
        final st = Services.I.data.settings;
        final hc = st.highContrast;
        final fixed = st.theme != 'system';
        final light = Palette.resolve(fixed ? st.theme : 'light', systemDark: false, highContrast: hc);
        final dark = Palette.resolve(fixed ? st.theme : 'dark', systemDark: true, highContrast: hc);
        return MaterialApp(
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
          home: const HomeScreen(),
        );
      },
    );
  }
}
