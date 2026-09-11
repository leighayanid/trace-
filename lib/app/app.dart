import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/theme.dart';
import 'theme/theme_mode.dart';

class TraceApp extends ConsumerStatefulWidget {
  const TraceApp({super.key});

  @override
  ConsumerState<TraceApp> createState() => _TraceAppState();
}

class _TraceAppState extends ConsumerState<TraceApp> {
  // Built once. Recreating the router on rebuild would drop navigation state.
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TRACE',
      debugShowCheckedModeBanner: false,
      theme: TraceTheme.light(),
      darkTheme: TraceTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // Switching themes cross-fades every token rather than cutting.
      themeAnimationDuration: TraceMotion.base,
      themeAnimationCurve: TraceMotion.standard,
      routerConfig: _router,
      builder: (context, child) =>
          _SystemBars(brightness: Theme.of(context).brightness, child: child!),
    );
  }
}

/// The status and navigation bars belong to the page, not to a chrome bar above
/// it: transparent, with icons that follow the app's theme.
///
/// Follows the *app's* brightness, not the device's — once the user picks a
/// theme the two can disagree, and dark icons on a dark page vanish.
class _SystemBars extends StatelessWidget {
  const _SystemBars({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final icons = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        systemNavigationBarIconBrightness: icons,
        // iOS names the bar's background, not its icons.
        statusBarBrightness: brightness,
      ),
      child: child,
    );
  }
}
