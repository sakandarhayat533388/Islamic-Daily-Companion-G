import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:home_widget/home_widget.dart';

import 'app_services.dart';
import 'models.dart';
import 'notification_service.dart';
import 'prayer_engine.dart';

/// Central prayer state: 30-day cache, today/tomorrow, 1-second countdown
/// ticker, widget data push and alert rescheduling (plan §3 triggers).
class PrayerController extends GetxController {
  static const _kCache = 'times_cache_v1';
  final _box = GetStorage();

  final today = Rxn<DayTimes>();
  final tomorrow = Rxn<DayTimes>();
  final yesterday = Rxn<DayTimes>();
  final cache = <DayTimes>[].obs;

  final nowTick = DateTime.now().obs;
  Timer? _timer;
  String _cacheKey = '';

  SettingsService get _settings => Get.find<SettingsService>();

  String _keyFor(AppSettingsData s) =>
      '${s.lat.toStringAsFixed(4)},${s.lng.toStringAsFixed(4)},${s.methodId},${s.hanafi},${s.highLat.name},${s.adjustments}';

  @override
  void onInit() {
    super.onInit();
    recalculate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      nowTick.value = n;
      // Midnight rollover: if the cached "today" is no longer today, rebuild.
      if (today.value != null &&
          (today.value!.date.year != n.year ||
              today.value!.date.month != n.month ||
              today.value!.date.day != n.day)) {
        recalculate();
      }
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  /// Rebuilds the 30-day cache when settings changed, else loads it from
  /// GetStorage. Always refreshes today/tomorrow/yesterday pointers.
  void recalculate({bool reschedule = true}) {
    final s = _settings.settings.value;
    final key = _keyFor(s);
    List<DayTimes>? days;
    if (key == _cacheKey && cache.isNotEmpty) {
      days = cache;
    } else {
      final stored = _box.read(_kCache);
      if (stored is Map && stored['key'] == key && stored['days'] is List) {
        try {
          days = (stored['days'] as List)
              .map((e) => DayTimes.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } catch (_) {
          days = null;
        }
      }
    }
    final now = DateTime.now();
    final startNeeded = DateTime(now.year, now.month, now.day - 1);
    final covers = days != null &&
        days.isNotEmpty &&
        !days.first.date.isAfter(startNeeded) &&
        !days.last.date.isBefore(DateTime(now.year, now.month, now.day + 6));
    if (!covers) {
      days = PrayerEngine.calculateRange(
        lat: s.lat,
        lng: s.lng,
        utcOffsetHours: s.utcOffsetHours,
        start: startNeeded,
        days: 31,
        method: s.method,
        hanafi: s.hanafi,
        highLat: s.highLat,
        adjustments: s.adjustments,
      );
      _box.write(_kCache, {
        'key': key,
        'days': days.map((d) => d.toJson()).toList(),
      });
    }
    _cacheKey = key;
    cache.assignAll(days);
    _pointAt(now);
    if (reschedule) {
      _rescheduleAndWidget();
    }
  }

  void _pointAt(DateTime now) {
    DayTimes? find(DateTime d) {
      for (final day in cache) {
        if (day.date.year == d.year && day.date.month == d.month && day.date.day == d.day) {
          return day;
        }
      }
      return null;
    }

    today.value = find(now);
    tomorrow.value = find(DateTime(now.year, now.month, now.day + 1));
    yesterday.value = find(DateTime(now.year, now.month, now.day - 1));
  }

  DayTimes? dayFor(DateTime date) {
    for (final day in cache) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    // Outside the cached window (month browsing) — compute on demand.
    final s = _settings.settings.value;
    return PrayerEngine.calculate(
      lat: s.lat,
      lng: s.lng,
      utcOffsetHours: s.utcOffsetHours,
      date: date,
      method: s.method,
      hanafi: s.hanafi,
      highLat: s.highLat,
      adjustments: s.adjustments,
    );
  }

  ({PrayerId current, PrayerId next, DateTime nextTime}) get currentNext {
    final t = today.value;
    if (t == null) {
      return (current: PrayerId.fajr, next: PrayerId.fajr, nextTime: DateTime.now());
    }
    return PrayerEngine.currentAndNext(t, nowTick.value, tomorrow: tomorrow.value);
  }

  double get progress {
    final t = today.value;
    if (t == null) return 0;
    return PrayerEngine.periodProgress(t, nowTick.value, yesterday: yesterday.value);
  }

  Duration get countdown => currentNext.nextTime.difference(nowTick.value);

  static String fmtCountdown(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _rescheduleAndWidget() async {
    try {
      if (Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>()
            .scheduleAll(_settings.settings.value, _settings.alerts.value);
      }
    } catch (_) {
      // Scheduling failures must never break the UI path.
    }
    await pushWidgetData();
  }

  /// Pushes next-prayer data to the Android home-screen widgets (S07).
  Future<void> pushWidgetData() async {
    try {
      final t = today.value;
      if (t == null) return;
      final cn = currentNext;
      final s = _settings.settings.value;
      final countdownMin = cn.nextTime.difference(DateTime.now());
      String two(int v) => v.toString().padLeft(2, '0');
      final countdownText =
          'in ${two(countdownMin.inHours)}:${two(countdownMin.inMinutes % 60)}';
      final timesLine = kAllMarkers
          .map((p) => '${p.label} ${fmtTime(t.timeFor(p))}')
          .join(' · ');
      await HomeWidget.saveWidgetData<String>('cityName', s.cityName);
      await HomeWidget.saveWidgetData<String>('hijriDate', t.hijriFull);
      await HomeWidget.saveWidgetData<String>('nextPrayerName', cn.next.label);
      await HomeWidget.saveWidgetData<String>(
          'nextPrayerTime', fmtTime(cn.nextTime));
      await HomeWidget.saveWidgetData<String>('countdownText', countdownText);
      await HomeWidget.saveWidgetData<String>('currentPrayerName', cn.current.label);
      await HomeWidget.saveWidgetData<String>('timesLine', timesLine);
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'com.islamic.dailycompanion.PrayerWidgetProvider',
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'com.islamic.dailycompanion.PrayerWidgetSmallProvider',
      );
    } catch (_) {
      // Widget is best-effort (e.g. non-Android test hosts).
    }
  }
}

/// Shared share-text builders (Home + month view).
String shareTextForDay(DayTimes day, AppSettingsData s) {
  final lines = [
    'Prayer times — ${s.cityName}, ${s.countryName}',
    '${day.date.day}/${day.date.month}/${day.date.year} · ${day.hijriFull}',
    for (final p in kAllMarkers) '${p.label}: ${PrayerController.fmtTime(day.timeFor(p))}',
    '· ${methodLabel(s.method)} method · ${s.hanafi ? 'Hanafi' : 'Standard'} Asr',
  ];
  return lines.join('\n');
}
