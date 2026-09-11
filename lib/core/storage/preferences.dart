import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences about how the app looks, not what it records.
///
/// Deliberately kept out of the database: these describe this screen, not the
/// user's life. They are not exported, not synced, and not touched by
/// "Delete all data".
abstract final class PrefKeys {
  /// `system` | `light` | `dark` — [ThemeMode.name].
  static const themeMode = 'theme_mode';

  static const all = {themeMode};
}

/// Opened once in `main()`, before the first frame, so reads are synchronous
/// and the app never paints in the wrong theme first.
Future<SharedPreferencesWithCache> openPreferences() =>
    SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefKeys.all,
      ),
    );

final preferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError(
    'preferencesProvider is opened in main() and overridden there.',
  ),
);
