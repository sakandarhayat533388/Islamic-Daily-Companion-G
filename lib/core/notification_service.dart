import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'models.dart';
import 'prayer_engine.dart';

/// WorkManager entry point — must be a top-level function. Tops the rolling
/// 7-day alert schedule back up once a day (plan §5).
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await GetStorageInit.ensure();
      final service = NotificationService();
      await service.initPlugin();
      await service.rescheduleFromStoredSettings();
    } catch (_) {
      // Background refresh is best-effort; the next app open re-schedules.
    }
    return true;
  });
}

/// Tiny helper so the dispatcher can init GetStorage without the full app.
class GetStorageInit {
  static Future<void> ensure() async {
    // GetStorage.init is idempotent for our purposes in a fresh isolate only
    // when the container path resolves; wrap so failures never crash the task.
    try {
      await GetStorage.init();
    } catch (_) {}
  }
}

/// Schedules prayer alerts with flutter_local_notifications (plan §5):
/// rolling 7 days × (5 prayers + enabled pre-alerts), exact alarms where the
/// OS permits, rescheduled on start / settings change / boot / timezone
/// change (native receivers live in AndroidManifest.xml).
class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'prayer_alerts';
  static const _channelName = 'Prayer Alerts';
  static const _preChannelId = 'prayer_pre_alerts';
  static const _preChannelName = 'Prayer Reminders';

  Future<void> initPlugin() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // Fall back to the device offset as a fixed location.
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    final android =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Adhan and prayer-time alerts',
        importance: Importance.max,
        playSound: true,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _preChannelId,
        _preChannelName,
        description: 'Gentle reminders a few minutes before a prayer',
        importance: Importance.high,
        playSound: true,
      ));
    }
    _ready = true;
  }

  Future<bool> requestPermissions() async {
    final android =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final notif = await android.requestNotificationsPermission() ?? false;
    await android.requestExactAlarmsPermission();
    return notif;
  }

  Future<bool> canScheduleExact() async {
    final android =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Used by the WorkManager dispatcher: reads persisted settings directly.
  Future<void> rescheduleFromStoredSettings() async {
    // Imported lazily to avoid a hard cycle in the background isolate.
    final settingsService = _StoredSettingsReader.read();
    if (settingsService == null) return;
    await scheduleAll(settingsService.$1, settingsService.$2);
  }

  /// Cancels everything and re-schedules the next 7 days.
  Future<void> scheduleAll(AppSettingsData s, AlertSettingsData a) async {
    await initPlugin();
    await plugin.cancelAll();
    if (!a.masterEnabled) return;

    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = DateTime.now();
    var id = 1000;
    for (int day = 0; day < 7; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final dt = PrayerEngine.calculate(
        lat: s.lat,
        lng: s.lng,
        utcOffsetHours: s.utcOffsetHours,
        date: date,
        method: s.method,
        hanafi: s.hanafi,
        highLat: s.highLat,
        adjustments: s.adjustments,
      );
      for (final p in kFivePrayers) {
        final alert = a.forPrayer(p);
        if (alert.mode == AlertMode.off) continue;
        final at = dt.timeFor(p);
        if (alert.preAlertMinutes > 0) {
          final preAt = at.subtract(Duration(minutes: alert.preAlertMinutes));
          if (preAt.isAfter(now)) {
            await _schedule(
              id: id++,
              title: '${p.label} in ${alert.preAlertMinutes} min',
              body: '${p.label} time is at ${_fmt(at)} in ${s.cityName}',
              at: preAt,
              alertMode: AlertMode.beep,
              scheduleMode: mode,
              preAlert: true,
            );
          }
        }
        if (at.isAfter(now)) {
          await _schedule(
            id: id++,
            title: 'It is time for ${p.label}',
            body: '${p.label} · ${_fmt(at)} · ${s.cityName}',
            at: at,
            alertMode: alert.mode,
            scheduleMode: mode,
            preAlert: false,
          );
        }
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required AlertMode alertMode,
    required AndroidScheduleMode scheduleMode,
    required bool preAlert,
  }) async {
    final details = _detailsFor(alertMode, preAlert: preAlert);
    await plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      details,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'prayer',
    );
  }

  NotificationDetails _detailsFor(AlertMode mode, {required bool preAlert}) {
    // NOTE on sounds: Android notification sounds must be raw resources.
    // res/raw/beep.wav and res/raw/adhan_1.wav ship in the app (beep.wav is a
    // generated license-free tone; adhan_1.wav is the SAME tone as a
    // placeholder — TODO(release): drop in a properly licensed Adhan
    // recording under the same resource name before release).
    AndroidNotificationDetails build({
      required bool sound,
      String? soundName,
      bool vibrate = false,
      Int64List? pattern,
      required Importance importance,
      required Priority priority,
    }) {
      return AndroidNotificationDetails(
        preAlert ? _preChannelId : _channelId,
        preAlert ? _preChannelName : _channelName,
        importance: importance,
        priority: priority,
        playSound: sound,
        sound: soundName == null
            ? null
            : RawResourceAndroidNotificationSound(soundName),
        enableVibration: vibrate,
        vibrationPattern: pattern,
        icon: '@mipmap/ic_launcher',
      );
    }

    switch (mode) {
      case AlertMode.adhan:
        return NotificationDetails(
          android: build(
            sound: true,
            soundName: 'adhan_1',
            importance: Importance.max,
            priority: Priority.max,
          ),
        );
      case AlertMode.beep:
        return NotificationDetails(
          android: build(
            sound: true,
            soundName: 'beep',
            importance: Importance.high,
            priority: Priority.high,
          ),
        );
      case AlertMode.vibrate:
        return NotificationDetails(
          android: build(
            sound: false,
            vibrate: true,
            pattern: Int64List.fromList([0, 400, 200, 400]),
            importance: Importance.high,
            priority: Priority.high,
          ),
        );
      case AlertMode.silent:
        return NotificationDetails(
          android: build(
            sound: false,
            importance: Importance.low,
            priority: Priority.low,
          ),
        );
      case AlertMode.off:
        return NotificationDetails(
          android: build(
            sound: false,
            importance: Importance.min,
            priority: Priority.min,
          ),
        );
    }
  }

  static String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Registers the daily WorkManager top-up (idempotent).
  Future<void> registerDailyTopUp() async {
    try {
      await Workmanager().initialize(notificationCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        'daily-alert-topup',
        'dailyAlertTopup',
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    } catch (_) {
      // WorkManager is a belt-and-braces top-up; app-open scheduling remains.
    }
  }
}

/// Reads settings JSON straight from GetStorage for the background isolate,
/// where the app's GetX registrations do not exist.
class _StoredSettingsReader {
  static (AppSettingsData, AlertSettingsData)? read() {
    try {
      // GetStorage needs init; the dispatcher called GetStorageInit.ensure().
      final box = GetStorage();
      final s = box.read('app_settings_v1');
      final a = box.read('alert_settings_v1');
      if (s is! Map) return null;
      final settings =
          AppSettingsData.fromJson(Map<String, dynamic>.from(s));
      final alerts = a is Map
          ? AlertSettingsData.fromJson(Map<String, dynamic>.from(a))
          : AlertSettingsData();
      return (settings, alerts);
    } catch (_) {
      return null;
    }
  }
}
