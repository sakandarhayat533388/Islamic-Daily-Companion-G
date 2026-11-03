import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';

import 'models.dart';

/// Country → (method, madhab) defaults — plan §4 table, locked before code.
/// NOTE: the Dart `adhan` package has no JAKIM (Malaysia) or Kemenag
/// (Indonesia) parameter set; both map to Muslim World League here, the
/// documented fallback from plan §11 open item 1.
({CalculationMethod method, bool hanafi}) defaultsForCountry(String countryCode) {
  switch (countryCode.toUpperCase()) {
    case 'PK':
    case 'IN':
    case 'BD':
    case 'AF':
      return (method: CalculationMethod.karachi, hanafi: true);
    case 'SA':
      return (method: CalculationMethod.umm_al_qura, hanafi: false);
    case 'AE':
      return (method: CalculationMethod.dubai, hanafi: false);
    case 'KW':
      return (method: CalculationMethod.kuwait, hanafi: false);
    case 'QA':
      return (method: CalculationMethod.qatar, hanafi: false);
    case 'EG':
      return (method: CalculationMethod.egyptian, hanafi: false);
    case 'TR':
      return (method: CalculationMethod.turkey, hanafi: false);
    case 'SG':
      return (method: CalculationMethod.singapore, hanafi: false);
    case 'US':
    case 'CA':
      return (method: CalculationMethod.north_america, hanafi: false);
    case 'MY':
    case 'ID':
      return (method: CalculationMethod.muslim_world_league, hanafi: false);
    default:
      return (method: CalculationMethod.muslim_world_league, hanafi: false);
  }
}

/// Pure, offline prayer-time engine (plan §3). No I/O, fully unit-testable.
///
/// Times are computed with the location's UTC offset so results are the
/// location's wall-clock times on ANY device: the `adhan` package returns
/// UTC-labelled DateTimes whose clock reading equals local wall time when an
/// explicit utcOffset is passed; we re-wrap those readings as plain local
/// DateTimes (y/m/d h:m) which is exactly how the UI and scheduler treat them.
class PrayerEngine {
  static DayTimes calculate({
    required double lat,
    required double lng,
    required double utcOffsetHours,
    required DateTime date,
    required CalculationMethod method,
    required bool hanafi,
    required HighLatChoice highLat,
    required Map<String, int> adjustments,
  }) {
    final params = method.getParameters();
    params.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    params.highLatitudeRule = highLat.rule;
    final offset = Duration(
        minutes: (utcOffsetHours * 60).round());
    final pt = PrayerTimes(
      Coordinates(lat, lng),
      DateComponents(date.year, date.month, date.day),
      params,
      utcOffset: offset,
    );

    DateTime wall(DateTime t, PrayerId p) {
      final base = DateTime(date.year, date.month, date.day, t.hour, t.minute);
      return base.add(Duration(minutes: adjustments[p.name] ?? 0));
    }

    final times = <PrayerId, DateTime>{
      PrayerId.fajr: wall(pt.fajr, PrayerId.fajr),
      PrayerId.sunrise: wall(pt.sunrise, PrayerId.sunrise),
      PrayerId.dhuhr: wall(pt.dhuhr, PrayerId.dhuhr),
      PrayerId.asr: wall(pt.asr, PrayerId.asr),
      PrayerId.maghrib: wall(pt.maghrib, PrayerId.maghrib),
      PrayerId.isha: wall(pt.isha, PrayerId.isha),
    };

    final hijri = HijriCalendar.fromDate(DateTime(date.year, date.month, date.day));
    return DayTimes(
      date: DateTime(date.year, date.month, date.day),
      times: times,
      hijriDay: '${hijri.hDay}',
      hijriMonthName: hijri.longMonthName,
      hijriYear: hijri.hYear,
    );
  }

  /// A run of [days] DayTimes starting at [start] (30-day cache per plan §3).
  static List<DayTimes> calculateRange({
    required double lat,
    required double lng,
    required double utcOffsetHours,
    required DateTime start,
    required int days,
    required CalculationMethod method,
    required bool hanafi,
    required HighLatChoice highLat,
    required Map<String, int> adjustments,
  }) {
    return [
      for (int i = 0; i < days; i++)
        calculate(
          lat: lat,
          lng: lng,
          utcOffsetHours: utcOffsetHours,
          date: DateTime(start.year, start.month, start.day + i),
          method: method,
          hanafi: hanafi,
          highLat: highLat,
          adjustments: adjustments,
        ),
    ];
  }

  /// Qibla bearing (degrees from north) via the adhan Qibla class.
  static double qiblaBearing(double lat, double lng) =>
      Qibla(Coordinates(lat, lng)).direction;

  /// Great-circle distance to the Kaaba in km (Haversine).
  static double distanceToMakkahKm(double lat, double lng) {
    const kaabaLat = 21.4225241;
    const kaabaLng = 39.8261818;
    const r = 6371.0;
    final dLat = _rad(kaabaLat - lat);
    final dLng = _rad(kaabaLng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) * math.cos(_rad(kaabaLat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  static String cardinal(double bearing) {
    const names = [
      'North', 'North-East', 'East', 'South-East',
      'South', 'South-West', 'West', 'North-West',
    ];
    return names[((bearing + 22.5) / 45).floor() % 8];
  }

  /// Current + next prayer for a day, given [now] (wall-clock in location tz).
  /// Returns (current, next, nextTime). After Isha, next is tomorrow's Fajr —
  /// callers pass tomorrow's DayTimes as [tomorrow] for that case.
  static ({PrayerId current, PrayerId next, DateTime nextTime}) currentAndNext(
    DayTimes today,
    DateTime now, {
    DayTimes? tomorrow,
  }) {
    PrayerId current = PrayerId.isha; // before Fajr: current period is Isha
    PrayerId next = PrayerId.fajr;
    DateTime nextTime = today.timeFor(PrayerId.fajr);
    for (final p in kAllMarkers) {
      final t = today.timeFor(p);
      if (!now.isBefore(t)) {
        current = p;
      } else {
        next = p;
        nextTime = t;
        return (current: current, next: next, nextTime: nextTime);
      }
    }
    // All of today's markers have passed.
    if (tomorrow != null) {
      return (
        current: PrayerId.isha,
        next: PrayerId.fajr,
        nextTime: tomorrow.timeFor(PrayerId.fajr),
      );
    }
    return (current: PrayerId.isha, next: PrayerId.fajr, nextTime: nextTime);
  }

  /// Fraction of the current prayer period elapsed (0..1) for the hero ring.
  static double periodProgress(DayTimes today, DateTime now, {DayTimes? yesterday}) {
    final cn = currentAndNext(today, now, tomorrow: null);
    final start = cn.current == PrayerId.isha && now.isBefore(today.timeFor(PrayerId.fajr))
        ? (yesterday?.timeFor(PrayerId.isha) ??
            today.timeFor(PrayerId.fajr).subtract(const Duration(hours: 2)))
        : today.timeFor(cn.current);
    final total = cn.nextTime.difference(start).inSeconds;
    if (total <= 0) return 0;
    final done = now.difference(start).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }
}
