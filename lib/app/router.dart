import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/projects/projects_screen.dart';
import '../features/settings/more_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';
import 'theme/theme.dart';

/// Route paths, referenced by name rather than by string literal at call sites.
abstract final class Routes {
  static const splash = '/splash';
  static const today = '/today';
  static const timeline = '/timeline';
  static const projects = '/projects';
  static const more = '/more';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) => NoTransitionPage(
          child: SplashScreen(
            onComplete: () => context.go(Routes.today),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => CustomTransitionPage(
          key: state.pageKey,
          transitionDuration: TraceMotion.settle,
          transitionsBuilder: _settle,
          child: TraceShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => TodayScreen(
                  // Reuses the shell's sheet rather than opening a second one.
                  onAddEntry: () => TraceShell.of(context)?.openQuickAdd(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.timeline,
                builder: (context, state) => const TimelineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.projects,
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The app arriving from the splash: it settles into view from a slight
/// magnification as it fades up out of the splash's dark field — the camera
/// finishing its pull-back. Pages pushed on top later still make it recede,
/// like any other page.
Widget _settle(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Reduced motion keeps the fade and drops the scale — by zeroing it rather
  // than branching, so the shell isn't remounted if the setting changes.
  final from = TraceMotion.reduced(context) ? 1.0 : 1.04;

  // `drive` rather than CurvedAnimation: this runs on every rebuild of the
  // route, and a driven tween holds no listener on the parent until used.
  return FadeTransition(
    opacity: animation.drive(
      CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    ),
    child: ScaleTransition(
      scale: animation.drive(
        Tween(
          begin: from,
          end: 1.0,
        ).chain(CurveTween(curve: TraceMotion.emphasizedDecelerate)),
      ),
      child: TracePageTransitionsBuilder.recede(
        secondaryAnimation,
        child: child,
      ),
    ),
  );
}
