import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_daily_companion/core/models.dart';
import 'package:islamic_daily_companion/core/prayer_engine.dart';

void main() {
  group('golden times — Karachi, 3 Nov 2026, Karachi method, Hanafi', () {
    final day = PrayerEngine.calculate(
      lat: 24.8607,
      lng: 67.0011,
      utcOffsetHours: 5,
      date: DateTime(2026, 11, 3),
      method: CalculationMethod.karachi,
      hanafi: true,
      highLat: HighLatChoice.auto,
      adjustments: const {},
    );

    void expectNear(PrayerId p, String hhmm) {
      final parts = hhmm.split(':');
      final expected = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final t = day.timeFor(p);
      final actual = t.hour * 60 + t.minute;
      expect((actual - expected).abs(), lessThanOrEqualTo(2),
          reason: '${p.label} expected ~$hhmm, got ${t.hour}:${t.minute}');
    }

    test('all six times within ±2 min of Aladhan reference', () {
      expectNear(PrayerId.fajr, '05:23');
      expectNear(PrayerId.sunrise, '06:40');
      expectNear(PrayerId.dhuhr, '12:16');
      expectNear(PrayerId.asr, '16:15');
      expectNear(PrayerId.maghrib, '17:51');
      expectNear(PrayerId.isha, '19:08');
    });

    test('hijri date matches the design mock (23 Jumada al-Awwal 1448)', () {
      expect(day.hijriDay, '23');
      expect(day.hijriYear, 1448);
      expect(day.hijriMonthName.toLowerCase(), contains('jumada'));
    });

    test('adjustments shift times minute-for-minute', () {
      final shifted = PrayerEngine.calculate(
        lat: 24.8607,
        lng: 67.0011,
        utcOffsetHours: 5,
        date: DateTime(2026, 11, 3),
        method: CalculationMethod.karachi,
        hanafi: true,
        highLat: HighLatChoice.auto,
        adjustments: const {'fajr': 5, 'isha': -3},
      );
      expect(
          shifted.timeFor(PrayerId.fajr).difference(day.timeFor(PrayerId.fajr)),
          const Duration(minutes: 5));
      expect(
          shifted.timeFor(PrayerId.isha).difference(day.timeFor(PrayerId.isha)),
          const Duration(minutes: -3));
    });
  });

  group('country defaults (plan §4)', () {
    test('PK → Karachi + Hanafi', () {
      final d = defaultsForCountry('PK');
      expect(d.method, CalculationMethod.karachi);
      expect(d.hanafi, isTrue);
    });
    test('IN/BD/AF → Karachi + Hanafi', () {
      for (final cc in ['IN', 'BD', 'AF']) {
        final d = defaultsForCountry(cc);
        expect(d.method, CalculationMethod.karachi, reason: cc);
        expect(d.hanafi, isTrue, reason: cc);
      }
    });
    test('SA → Umm Al-Qura + Standard', () {
      final d = defaultsForCountry('SA');
      expect(d.method, CalculationMethod.umm_al_qura);
      expect(d.hanafi, isFalse);
    });
    test('AE → Dubai + Standard', () {
      final d = defaultsForCountry('AE');
      expect(d.method, CalculationMethod.dubai);
      expect(d.hanafi, isFalse);
    });
    test('TR → Diyanet (turkey) + Standard', () {
      final d = defaultsForCountry('TR');
      expect(d.method, CalculationMethod.turkey);
      expect(d.hanafi, isFalse);
    });
    test('US/CA → ISNA + Standard', () {
      for (final cc in ['US', 'CA']) {
        expect(defaultsForCountry(cc).method, CalculationMethod.north_america,
            reason: cc);
      }
    });
    test('unknown → MWL + Standard', () {
      final d = defaultsForCountry('ZZ');
      expect(d.method, CalculationMethod.muslim_world_league);
      expect(d.hanafi, isFalse);
    });
  });

  group('qibla — Karachi', () {
    test('bearing ≈ 268°, distance ≈ 2,800 km', () {
      expect(PrayerEngine.qiblaBearing(24.8607, 67.0011).round(), 268);
      expect(PrayerEngine.distanceToMakkahKm(24.8607, 67.0011).round(),
          inInclusiveRange(2790, 2810));
      expect(PrayerEngine.cardinal(268), 'West');
    });
  });

  group('current/next logic', () {
    final day = PrayerEngine.calculate(
      lat: 24.8607,
      lng: 67.0011,
      utcOffsetHours: 5,
      date: DateTime(2026, 11, 3),
      method: CalculationMethod.karachi,
      hanafi: true,
      highLat: HighLatChoice.auto,
      adjustments: const {},
    );

    test('mid-afternoon: current Asr, next Maghrib', () {
      final cn = PrayerEngine.currentAndNext(day, DateTime(2026, 11, 3, 16, 30));
      expect(cn.current, PrayerId.asr);
      expect(cn.next, PrayerId.maghrib);
    });

    test('before Fajr: current Isha, next Fajr', () {
      final cn = PrayerEngine.currentAndNext(day, DateTime(2026, 11, 3, 4, 0));
      expect(cn.current, PrayerId.isha);
      expect(cn.next, PrayerId.fajr);
    });

    test('after Isha with tomorrow: next is tomorrow Fajr', () {
      final tomorrow = PrayerEngine.calculate(
        lat: 24.8607,
        lng: 67.0011,
        utcOffsetHours: 5,
        date: DateTime(2026, 11, 4),
        method: CalculationMethod.karachi,
        hanafi: true,
        highLat: HighLatChoice.auto,
        adjustments: const {},
      );
      final cn = PrayerEngine.currentAndNext(day, DateTime(2026, 11, 3, 21, 0),
          tomorrow: tomorrow);
      expect(cn.current, PrayerId.isha);
      expect(cn.next, PrayerId.fajr);
      expect(cn.nextTime.day, 4);
    });
  });

  group('high latitude sanity — London, June week', () {
    test('no null/absurd times for a full week', () {
      for (int i = 0; i < 7; i++) {
        final d = PrayerEngine.calculate(
          lat: 51.5074,
          lng: -0.1278,
          utcOffsetHours: 1,
          date: DateTime(2026, 6, 15 + i),
          method: CalculationMethod.muslim_world_league,
          hanafi: false,
          highLat: HighLatChoice.auto,
          adjustments: const {},
        );
        for (final p in PrayerId.values) {
          final t = d.timeFor(p);
          expect(t.hour, inInclusiveRange(0, 23), reason: '${p.label} day $i');
        }
        expect(d.timeFor(PrayerId.fajr).isBefore(d.timeFor(PrayerId.sunrise)),
            isTrue);
        expect(d.timeFor(PrayerId.maghrib).isBefore(d.timeFor(PrayerId.isha)),
            isTrue);
      }
    });
  });
}
