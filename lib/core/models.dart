import 'package:adhan/adhan.dart';

/// Prayer identifiers used across the app (Sunrise is a marker, not a prayer).
enum PrayerId { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerIdX on PrayerId {
  String get label => switch (this) {
        PrayerId.fajr => 'Fajr',
        PrayerId.sunrise => 'Sunrise',
        PrayerId.dhuhr => 'Dhuhr',
        PrayerId.asr => 'Asr',
        PrayerId.maghrib => 'Maghrib',
        PrayerId.isha => 'Isha',
      };
  String get arabic => switch (this) {
        PrayerId.fajr => 'الفجر',
        PrayerId.sunrise => 'الشروق',
        PrayerId.dhuhr => 'الظهر',
        PrayerId.asr => 'العصر',
        PrayerId.maghrib => 'المغرب',
        PrayerId.isha => 'العشاء',
      };
  bool get isPrayer => this != PrayerId.sunrise;
}

/// The five actual prayers, in order — used for alerts.
const List<PrayerId> kFivePrayers = [
  PrayerId.fajr,
  PrayerId.dhuhr,
  PrayerId.asr,
  PrayerId.maghrib,
  PrayerId.isha,
];

/// All six display rows, in order.
const List<PrayerId> kAllMarkers = [
  PrayerId.fajr,
  PrayerId.sunrise,
  PrayerId.dhuhr,
  PrayerId.asr,
  PrayerId.maghrib,
  PrayerId.isha,
];

enum AlertMode { adhan, beep, vibrate, silent, off }

extension AlertModeX on AlertMode {
  String get label => switch (this) {
        AlertMode.adhan => 'Full Adhan · Voice 1',
        AlertMode.beep => 'Beep',
        AlertMode.vibrate => 'Vibrate only',
        AlertMode.silent => 'Silent notification',
        AlertMode.off => 'Off',
      };
}

enum HighLatChoice { auto, middleOfNight, oneSeventh, angleBased }

extension HighLatChoiceX on HighLatChoice {
  String get label => switch (this) {
        HighLatChoice.auto => 'Auto',
        HighLatChoice.middleOfNight => 'Middle of the Night',
        HighLatChoice.oneSeventh => 'One-Seventh of the Night',
        HighLatChoice.angleBased => 'Angle Based',
      };
  HighLatitudeRule get rule => switch (this) {
        HighLatChoice.auto => HighLatitudeRule.twilight_angle,
        HighLatChoice.middleOfNight => HighLatitudeRule.middle_of_the_night,
        HighLatChoice.oneSeventh => HighLatitudeRule.seventh_of_the_night,
        HighLatChoice.angleBased => HighLatitudeRule.twilight_angle,
      };
}

/// User settings (plan §7 UserSettings). Stored in GetStorage as one JSON map.
class AppSettingsData {
  bool onboardingDone;
  String locationMode; // 'gps' | 'manual'
  double lat;
  double lng;
  double utcOffsetHours; // location's standard UTC offset
  String cityName;
  String countryName;
  String countryCode;
  String methodId; // CalculationMethod.name
  bool hanafi;
  HighLatChoice highLat;
  Map<String, int> adjustments; // PrayerId.name -> minutes
  String themeMode; // 'system' | 'light' | 'dark'

  AppSettingsData({
    this.onboardingDone = false,
    this.locationMode = 'gps',
    this.lat = 24.8607,
    this.lng = 67.0011,
    this.utcOffsetHours = 5.0,
    this.cityName = 'Karachi',
    this.countryName = 'Pakistan',
    this.countryCode = 'PK',
    this.methodId = 'karachi',
    this.hanafi = true,
    this.highLat = HighLatChoice.auto,
    Map<String, int>? adjustments,
    this.themeMode = 'system',
  }) : adjustments = adjustments ??
            {for (final p in PrayerId.values) p.name: 0};

  CalculationMethod get method =>
      CalculationMethod.values.firstWhere((m) => m.name == methodId,
          orElse: () => CalculationMethod.muslim_world_league);

  int adjustmentFor(PrayerId p) => adjustments[p.name] ?? 0;

  Map<String, dynamic> toJson() => {
        'onboardingDone': onboardingDone,
        'locationMode': locationMode,
        'lat': lat,
        'lng': lng,
        'utcOffsetHours': utcOffsetHours,
        'cityName': cityName,
        'countryName': countryName,
        'countryCode': countryCode,
        'methodId': methodId,
        'hanafi': hanafi,
        'highLat': highLat.name,
        'adjustments': adjustments,
        'themeMode': themeMode,
      };

  factory AppSettingsData.fromJson(Map<String, dynamic> j) {
    final d = AppSettingsData();
    d.onboardingDone = j['onboardingDone'] as bool? ?? false;
    d.locationMode = j['locationMode'] as String? ?? 'gps';
    d.lat = (j['lat'] as num?)?.toDouble() ?? d.lat;
    d.lng = (j['lng'] as num?)?.toDouble() ?? d.lng;
    d.utcOffsetHours = (j['utcOffsetHours'] as num?)?.toDouble() ?? d.utcOffsetHours;
    d.cityName = j['cityName'] as String? ?? d.cityName;
    d.countryName = j['countryName'] as String? ?? d.countryName;
    d.countryCode = j['countryCode'] as String? ?? d.countryCode;
    d.methodId = j['methodId'] as String? ?? d.methodId;
    d.hanafi = j['hanafi'] as bool? ?? true;
    d.highLat = HighLatChoice.values.firstWhere((e) => e.name == j['highLat'],
        orElse: () => HighLatChoice.auto);
    final adj = j['adjustments'];
    if (adj is Map) {
      d.adjustments = {
        for (final p in PrayerId.values)
          p.name: (adj[p.name] as num?)?.toInt() ?? 0
      };
    }
    d.themeMode = j['themeMode'] as String? ?? 'system';
    return d;
  }
}

/// Per-prayer alert configuration (plan §7 AlertSettings).
class PrayerAlert {
  AlertMode mode;
  int preAlertMinutes; // 0 = off
  PrayerAlert({this.mode = AlertMode.adhan, this.preAlertMinutes = 0});

  Map<String, dynamic> toJson() =>
      {'mode': mode.name, 'pre': preAlertMinutes};
  factory PrayerAlert.fromJson(Map<String, dynamic> j) => PrayerAlert(
        mode: AlertMode.values.firstWhere((e) => e.name == j['mode'],
            orElse: () => AlertMode.adhan),
        preAlertMinutes: (j['pre'] as num?)?.toInt() ?? 0,
      );
}

class AlertSettingsData {
  bool masterEnabled;
  Map<String, PrayerAlert> perPrayer;
  AlertSettingsData({this.masterEnabled = true, Map<String, PrayerAlert>? perPrayer})
      : perPrayer = perPrayer ??
            {
              // Defaults mirror the S06b mock variety.
              PrayerId.fajr.name: PrayerAlert(mode: AlertMode.adhan, preAlertMinutes: 15),
              PrayerId.dhuhr.name: PrayerAlert(mode: AlertMode.adhan),
              PrayerId.asr.name: PrayerAlert(mode: AlertMode.adhan, preAlertMinutes: 10),
              PrayerId.maghrib.name: PrayerAlert(mode: AlertMode.adhan, preAlertMinutes: 5),
              PrayerId.isha.name: PrayerAlert(mode: AlertMode.vibrate),
            };

  PrayerAlert forPrayer(PrayerId p) =>
      perPrayer[p.name] ?? PrayerAlert(mode: AlertMode.off);

  Map<String, dynamic> toJson() => {
        'master': masterEnabled,
        'per': {for (final e in perPrayer.entries) e.key: e.value.toJson()},
      };

  factory AlertSettingsData.fromJson(Map<String, dynamic> j) {
    final d = AlertSettingsData();
    d.masterEnabled = j['master'] as bool? ?? true;
    final per = j['per'];
    if (per is Map) {
      d.perPrayer = {
        for (final p in kFivePrayers)
          p.name: per[p.name] is Map
              ? PrayerAlert.fromJson(Map<String, dynamic>.from(per[p.name] as Map))
              : d.perPrayer[p.name]!,
      };
    }
    return d;
  }
}

/// One day's calculated times (post-adjustment), wall-clock in the location's
/// timezone, plus its Hijri date string.
class DayTimes {
  final DateTime date; // local date (y/m/d only meaningful)
  final Map<PrayerId, DateTime> times;
  final String hijriDay;
  final String hijriMonthName;
  final int hijriYear;

  const DayTimes({
    required this.date,
    required this.times,
    required this.hijriDay,
    required this.hijriMonthName,
    required this.hijriYear,
  });

  DateTime timeFor(PrayerId p) => times[p]!;
  String get hijriFull => '$hijriDay $hijriMonthName $hijriYear';

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'times': {
          for (final e in times.entries) e.key.name: e.value.toIso8601String()
        },
        'hijriDay': hijriDay,
        'hijriMonthName': hijriMonthName,
        'hijriYear': hijriYear,
      };

  factory DayTimes.fromJson(Map<String, dynamic> j) => DayTimes(
        date: DateTime.parse(j['date'] as String),
        times: {
          for (final p in PrayerId.values)
            if ((j['times'] as Map)[p.name] != null)
              p: DateTime.parse((j['times'] as Map)[p.name] as String),
        },
        hijriDay: j['hijriDay'] as String? ?? '',
        hijriMonthName: j['hijriMonthName'] as String? ?? '',
        hijriYear: (j['hijriYear'] as num?)?.toInt() ?? 0,
      );
}

/// A city from the bundled offline dataset.
class CityEntry {
  final String name;
  final String country;
  final String countryCode;
  final double lat;
  final double lng;
  final double utc;
  const CityEntry({
    required this.name,
    required this.country,
    required this.countryCode,
    required this.lat,
    required this.lng,
    required this.utc,
  });
  String get display => '$name, $country';
  factory CityEntry.fromJson(Map<String, dynamic> j) => CityEntry(
        name: j['name'] as String,
        country: j['country'] as String,
        countryCode: j['countryCode'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        utc: (j['utc'] as num).toDouble(),
      );
}

/// Method metadata for settings lists.
class MethodInfo {
  final CalculationMethod method;
  final String label;
  final String authority;
  const MethodInfo(this.method, this.label, this.authority);
}

const List<MethodInfo> kMethods = [
  MethodInfo(CalculationMethod.karachi, 'Karachi', 'University of Islamic Sciences, Karachi'),
  MethodInfo(CalculationMethod.muslim_world_league, 'Muslim World League', 'Muslim World League'),
  MethodInfo(CalculationMethod.umm_al_qura, 'Umm Al-Qura, Makkah', 'Umm Al-Qura University, Makkah'),
  MethodInfo(CalculationMethod.north_america, 'ISNA (North America)', 'Islamic Society of North America'),
  MethodInfo(CalculationMethod.dubai, 'Dubai / Gulf', 'UAE — 18.2° / 18.2°'),
  MethodInfo(CalculationMethod.kuwait, 'Kuwait', 'Kuwait — 18° / 17.5°'),
  MethodInfo(CalculationMethod.qatar, 'Qatar', 'Qatar — modified Umm Al-Qura'),
  MethodInfo(CalculationMethod.egyptian, 'Egyptian', 'Egyptian General Authority of Survey'),
  MethodInfo(CalculationMethod.turkey, 'Diyanet (Türkiye)', 'Diyanet İşleri Başkanlığı'),
  MethodInfo(CalculationMethod.singapore, 'Singapore', 'MUIS, Singapore'),
  MethodInfo(CalculationMethod.moon_sighting_committee, 'Moonsighting Committee', 'Moonsighting Committee'),
  MethodInfo(CalculationMethod.tehran, 'Tehran', 'Institute of Geophysics, University of Tehran'),
];

String methodLabel(CalculationMethod m) => kMethods
    .firstWhere((i) => i.method == m,
        orElse: () => MethodInfo(m, 'Muslim World League', 'Muslim World League'))
    .label;
