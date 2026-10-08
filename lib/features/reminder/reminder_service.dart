import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../entries/entry_repository.dart' show dayKey;

/// The only notification TRACE ever sends: one ask, at a time the user chose,
/// for what they did that day.
///
/// Deliberately not a daily repeating alarm. A repeat would fire on days
/// already written down, and being reminded to record something you have
/// already recorded is the productivity nagging the brief rules out. Instead a
/// window of single reminders is armed a fortnight ahead, each day's dropped as
/// soon as that day has an entry, and the window is re-armed whenever the app
/// runs. If TRACE is not opened for two weeks the reminders run out — by then
/// a notification is not what is missing.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Days armed ahead. Android caps nothing here, iOS allows 64 pending
  /// notifications, and a fortnight is well inside both.
  static const horizon = 14;

  /// Reminder ids live in their own range so a cancel can never reach some
  /// other notification. `_idBase + n` is the reminder n days from the day the
  /// window was armed.
  static const _idBase = 1000;

  static const _payload = 'reminder';
  static const _channelId = 'daily_reminder';

  Future<void>? _ready;

  /// Runs when the user taps a reminder, whether the app was already open or
  /// the tap launched it. Set by the provider that owns this service, and
  /// settable after [ready] so the tap handler cannot be lost to call order.
  VoidCallback? onTap;

  /// Serialises arming. The window is re-armed on a setting change, on an
  /// entry being written and on resume, which can land close enough together
  /// for two passes to interleave and leave a slot cancelled but unscheduled.
  Future<void> _queue = Future<void>.value();

  /// What the armed window currently stands for. Entries are written and
  /// edited far more often than they change which *days* are recorded, and
  /// every such write reaches the scheduler, so an unchanged window is left
  /// alone rather than torn down and rebuilt.
  String? _armed;

  /// Prepares the plugin and the time zone database. Safe to call repeatedly;
  /// the work happens once.
  Future<void> ready() => _ready ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // Leaves tz.local as UTC, which would fire the reminder at the wrong
      // hour. Nothing else in TRACE depends on the time zone database, so the
      // rest of the app is unaffected.
      debugPrint('Reminder: could not resolve the local time zone ($e).');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_trace'),
        // Nothing is asked for at launch. Permission is requested when the
        // user switches the reminder on, where the ask has an obvious reason.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) onTap?.call();
      },
    );

    // A tap that launched the app cold does not reach the callback above.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch != null &&
        launch.didNotificationLaunchApp &&
        launch.notificationResponse?.payload == _payload) {
      onTap?.call();
    }
  }

  /// Asks for permission to notify. Returns whether TRACE may.
  ///
  /// Called only when the user turns the reminder on. Android 12 and below, and
  /// an already-granted iOS, answer true without showing anything.
  Future<bool> requestPermission() async {
    await ready();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  /// Whether the system would currently show a reminder. False once the user
  /// has turned TRACE's notifications off in system settings, which no amount
  /// of scheduling here can override.
  Future<bool> permitted() async {
    await ready();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.areNotificationsEnabled() ?? true;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  /// Replaces the armed window with one reminder at [time] on each of the next
  /// [horizon] days starting at [from], skipping the days in [skip] — the days
  /// already written down — and any time that has passed.
  Future<void> arm({
    required TimeOfDay time,
    required DateTime from,
    required Set<String> skip,
  }) {
    final signature = '${dayKey(from)} ${time.hour}:${time.minute} '
        '${(skip.toList()..sort()).join(',')}';

    return _serially(() async {
      if (signature == _armed) return;
      await ready();
      await _clear();
      // Set before scheduling, so a failure part-way through does not leave a
      // half-armed window recorded as complete.
      _armed = null;

      final mode = await _scheduleMode();
      final now = tz.TZDateTime.now(tz.local);

      for (var i = 0; i < horizon; i++) {
        // Day arithmetic, not 24-hour arithmetic: DateTime normalises an
        // overflowing day, and the clock changing does not shift the date.
        final day = DateTime(from.year, from.month, from.day + i);
        if (skip.contains(dayKey(day))) continue;

        final at = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );
        if (!at.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: _idBase + i,
          scheduledDate: at,
          title: 'What did you do today?',
          // No count, no streak, no scolding. The reminder states the ask and
          // how little answering it takes.
          body: 'A line is enough.',
          payload: _payload,
          notificationDetails: _details,
          androidScheduleMode: mode,
        );
      }

      _armed = signature;
    });
  }

  /// Takes down the armed window.
  Future<void> disarm() => _serially(() async {
        await ready();
        await _clear();
        _armed = null;
      });

  Future<void> _clear() async {
    for (var i = 0; i < horizon; i++) {
      await _plugin.cancel(id: _idBase + i);
    }
  }

  /// Exact where the system already allows it, inexact otherwise. The reminder
  /// is never worth a trip to system settings, so permission is not requested:
  /// an inexact alarm arrives in roughly the right part of the evening, which
  /// is enough for an ask about the day.
  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Daily reminder',
      channelDescription: 'A once-a-day ask for what you did.',
      // High so it appears when it arrives — the point is to catch the user
      // while they can still remember the day. One a day, at an hour they
      // picked, is the whole of TRACE's notifying.
      importance: Importance.high,
      priority: Priority.high,
      // No unread dot on the launcher icon. A record is not an inbox.
      channelShowBadge: false,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    ),
  );

  Future<void> _serially(Future<void> Function() work) {
    final next = _queue.then((_) => work());
    // Keeps the chain alive: an unhandled failure would otherwise poison every
    // later arm. A reminder that failed to schedule is re-armed on next launch.
    _queue = next.catchError((Object e) {
      debugPrint('Reminder: $e');
    });
    return _queue;
  }
}
