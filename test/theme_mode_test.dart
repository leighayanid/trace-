import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trace/app/theme/theme_mode.dart';
import 'package:trace/core/storage/preferences.dart';

/// The theme choice survives a restart, and a missing or unreadable value
/// means "follow the device".
void main() {
  Future<ProviderContainer> launch() async {
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(await openPreferences()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to system', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    final app = await launch();

    expect(app.read(themeModeProvider), ThemeMode.system);
  });

  test('a choice persists across launches', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    final first = await launch();
    await first.read(themeModeProvider.notifier).select(ThemeMode.dark);
    expect(first.read(themeModeProvider), ThemeMode.dark);

    final second = await launch();
    expect(second.read(themeModeProvider), ThemeMode.dark);
  });

  test('an unreadable stored value falls back to system', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({PrefKeys.themeMode: 'sepia'});

    final app = await launch();

    expect(app.read(themeModeProvider), ThemeMode.system);
  });
}
