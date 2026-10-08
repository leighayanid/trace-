import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/storage/preferences.dart';
import '../entries/entry_providers.dart';
import '../entries/entry_repository.dart' show dayKey;
import 'reminder_service.dart';

/// Whether the daily reminder is on, and when it fires.
@immutable
class Reminder {
  const Reminder({required this.on, required this.time});

  final bool on;

  /// Local wall-clock time. Defaults to 21:00: late enough that the day is
  /// mostly done, early enough to still be awake for it.
  final TimeOfDay time;

  static const defaultTime = TimeOfDay(hour: 21, minute: 0);

  /// `HH:mm`, zero-padded, as stored.
  String get stored =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// Reads `HH:mm` back, falling back to [defaultTime] rather than throwing on
  /// a value that is somehow unreadable.
  static TimeOfDay parse(String? value) {
    final parts = value?.split(':') ?? const [];
    if (parts.length != 2) return defaultTime;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return defaultTime;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return defaultTime;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService()
    ..onTap = () => ref.read(reminderTapProvider.notifier).raise();
});

/// A tapped reminder, waiting to be answered.
///
/// A signal rather than a navigation call: the tap can arrive before the shell
/// exists — a cold launch from the notification — so the shell reads it when it
/// mounts as well as listening for it.
class ReminderTap extends Notifier<bool> {
  @override
  bool build() => false;

  void raise() => state = true;

  /// True once per tap. Taking it clears the signal, so a rebuild cannot reopen
  /// Quick Add a second time.
  bool take() {
    if (!state) return false;
    state = false;
    return true;
  }
}

final reminderTapProvider = NotifierProvider<ReminderTap, bool>(ReminderTap.new);

/// The reminder setting, persisted on the device alongside the theme. Not
/// exported and not synced: it describes this phone, not the user's life.
class ReminderSetting extends Notifier<Reminder> {
  @override
  Reminder build() {
    final prefs = ref.watch(preferencesProvider);
    return Reminder(
      on: prefs.getBool(PrefKeys.reminderOn) ?? false,
      time: Reminder.parse(prefs.getString(PrefKeys.reminderTime)),
    );
  }

  /// Turns the reminder on, asking for permission to notify first. Returns
  /// false — and leaves the reminder off — if the system refuses, since a
  /// setting that says "on" while nothing can arrive is a lie.
  Future<bool> turnOn() async {
    if (!await ref.read(reminderServiceProvider).requestPermission()) {
      return false;
    }
    await _write(on: true);
    return true;
  }

  Future<void> turnOff() => _write(on: false);

  Future<void> selectTime(TimeOfDay time) => _write(time: time);

  Future<void> _write({bool? on, TimeOfDay? time}) async {
    final next = Reminder(
      on: on ?? state.on,
      time: time ?? state.time,
    );
    state = next;
    final prefs = ref.read(preferencesProvider);
    await prefs.setBool(PrefKeys.reminderOn, next.on);
    await prefs.setString(PrefKeys.reminderTime, next.stored);
  }
}

final reminderProvider =
    NotifierProvider<ReminderSetting, Reminder>(ReminderSetting.new);

/// Whether the system would let a reminder through. Re-read on every look at
/// the Reminder screen, because it can be revoked outside the app.
final reminderPermittedProvider = FutureProvider<bool>(
  (ref) => ref.watch(reminderServiceProvider).permitted(),
);

/// The days inside the armed window that already hold an entry.
///
/// Anchored to [currentDayProvider], so the window — and the scheduling that
/// follows it — moves on at midnight and on resume.
final _recordedDaysProvider = StreamProvider<Set<String>>((ref) {
  final from = ref.watch(currentDayProvider);
  final start = DateTime.parse(from);
  final to = dayKey(
    DateTime(start.year, start.month, start.day + ReminderService.horizon),
  );
  return ref
      .watch(databaseProvider)
      .watchEntriesBetween(from, to)
      .map((entries) => {for (final e in entries) e.date});
});

/// Keeps the armed reminders in step with the setting and with the record.
///
/// Watched for its effect, like auto-sync: every rebuild re-arms the window, so
/// writing today's first entry drops today's reminder, and deleting it brings
/// the reminder back.
final reminderSchedulerProvider = Provider<void>((ref) {
  final service = ref.watch(reminderServiceProvider);
  final reminder = ref.watch(reminderProvider);

  // Unconditional, and not only on the way to arming: initialising is also
  // what notices a tap that launched the app, which has to be picked up
  // whether or not there is anything left to schedule.
  service.ready();

  if (!reminder.on) {
    service.disarm();
    return;
  }

  // Until the first day of entries has loaded, arming would schedule a
  // reminder for a day that may already be written down. The stream settles
  // in milliseconds and the rebuild arms it then.
  final recorded = ref.watch(_recordedDaysProvider).value;
  if (recorded == null) return;

  service.arm(
    time: reminder.time,
    from: DateTime.parse(ref.watch(currentDayProvider)),
    skip: recorded,
  );
});
