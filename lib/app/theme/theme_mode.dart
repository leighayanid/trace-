import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/preferences.dart';

/// Light, dark, or whatever the device says.
///
/// Defaults to [ThemeMode.system]: the app should match the phone until the
/// user says otherwise. An unreadable stored value falls back the same way
/// rather than throwing on launch.
class ThemeModeSetting extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(preferencesProvider).getString(PrefKeys.themeMode);
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref
        .read(preferencesProvider)
        .setString(PrefKeys.themeMode, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeSetting, ThemeMode>(
  ThemeModeSetting.new,
);
