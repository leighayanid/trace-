import 'package:go_router/go_router.dart';

import '../features/projects/projects_screen.dart';
import '../features/settings/more_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

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
        builder: (context, state, navigationShell) =>
            TraceShell(navigationShell: navigationShell),
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
