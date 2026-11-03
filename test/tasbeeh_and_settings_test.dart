import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:islamic_daily_companion/core/models.dart';
import 'package:islamic_daily_companion/features/tasbeeh/tasbeeh_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('settings persistence round-trip', () {
    test('AppSettingsData survives toJson/fromJson', () {
      final s = AppSettingsData()
        ..cityName = 'Dubai'
        ..countryName = 'UAE'
        ..countryCode = 'AE'
        ..methodId = 'dubai'
        ..hanafi = false
        ..highLat = HighLatChoice.oneSeventh
        ..themeMode = 'dark'
        ..adjustments['fajr'] = 4
        ..onboardingDone = true;
      final back = AppSettingsData.fromJson(s.toJson());
      expect(back.cityName, 'Dubai');
      expect(back.countryCode, 'AE');
      expect(back.methodId, 'dubai');
      expect(back.hanafi, isFalse);
      expect(back.highLat, HighLatChoice.oneSeventh);
      expect(back.themeMode, 'dark');
      expect(back.adjustmentFor(PrayerId.fajr), 4);
      expect(back.adjustmentFor(PrayerId.isha), 0);
      expect(back.onboardingDone, isTrue);
    });

    test('AlertSettingsData survives toJson/fromJson', () {
      final a = AlertSettingsData()..masterEnabled = false;
      a.forPrayer(PrayerId.fajr).mode = AlertMode.beep;
      a.forPrayer(PrayerId.fajr).preAlertMinutes = 10;
      final back = AlertSettingsData.fromJson(a.toJson());
      expect(back.masterEnabled, isFalse);
      expect(back.forPrayer(PrayerId.fajr).mode, AlertMode.beep);
      expect(back.forPrayer(PrayerId.fajr).preAlertMinutes, 10);
      expect(back.forPrayer(PrayerId.isha).mode, AlertMode.vibrate);
    });

    test('DayTimes survives toJson/fromJson', () {
      final d = DayTimes(
        date: DateTime(2026, 11, 3),
        times: {
          for (final p in PrayerId.values)
            p: DateTime(2026, 11, 3, 5 + p.index, 15),
        },
        hijriDay: '23',
        hijriMonthName: 'Jumada al-Awwal',
        hijriYear: 1448,
      );
      final back = DayTimes.fromJson(d.toJson());
      expect(back.date, d.date);
      expect(back.timeFor(PrayerId.asr), d.timeFor(PrayerId.asr));
      expect(back.hijriFull, '23 Jumada al-Awwal 1448');
    });
  });

  group('tasbeeh logic', () {
    late TasbeehController c;

    setUpAll(() async {
      // GetStorage needs path_provider, which has no test implementation.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => '/tmp');
      // audioplayers has no test implementation; no-op its channels so the
      // target chime in tap flows does not raise MissingPluginException.
      for (final name in [
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers',
        'vibration',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
      }
      // Controllers use the DEFAULT GetStorage container (as in main.dart);
      // initialise it once here and erase between tests.
      await GetStorage.init();
    });

    setUp(() async {
      await GetStorage().erase();
      Get.testMode = true;
      c = TasbeehController();
      c.onInit();
    });

    tearDown(() {
      Get.reset();
    });

    test('post-prayer set: starts at SubhanAllah 33', () {
      c.startPostPrayerSet();
      expect(c.currentDhikrId.value, 'subhanallah');
      expect(c.target.value, 33);
      expect(c.setIndex.value, 0);
    });

    test('tapping to target auto-advances 33 → 33 → 34, then completes', () async {
      c.startPostPrayerSet();
      // Vibration/audio plugins are unavailable in tests; the controller
      // guards those calls, so taps still advance state.
      for (int i = 0; i < 33; i++) {
        await c.tap();
      }
      expect(c.currentDhikrId.value, 'alhamdulillah');
      expect(c.target.value, 33);
      expect(c.count.value, 0);
      for (int i = 0; i < 33; i++) {
        await c.tap();
      }
      expect(c.currentDhikrId.value, 'allahuakbar');
      expect(c.target.value, 34);
      for (int i = 0; i < 34; i++) {
        await c.tap();
      }
      expect(c.inSetMode.value, isFalse);
      // Daily records accumulated the whole set: 33+33+34 = 100 today.
      expect(c.todayTotal, 100);
      expect(c.countFor(TasbeehController.dateKey(DateTime.now()), 'subhanallah'), 33);
    });

    test('undo decrements count and daily record', () async {
      c.startPostPrayerSet();
      await c.tap();
      await c.tap();
      await c.tap();
      expect(c.count.value, 3);
      c.undo();
      expect(c.count.value, 2);
      expect(c.todayTotal, 2);
    });

    test('streak: consecutive days counted, gap breaks it', () {
      final now = DateTime.now();
      String key(DateTime d) => TasbeehController.dateKey(d);
      c.records.assignAll({
        key(now): {'subhanallah': 10},
        key(now.subtract(const Duration(days: 1))): {'subhanallah': 5},
        key(now.subtract(const Duration(days: 2))): {'subhanallah': 5},
        // day -3 missing = gap
        key(now.subtract(const Duration(days: 4))): {'subhanallah': 5},
      });
      expect(c.streak, 3);
      expect(c.lifetime, 25);
      expect(c.last7Days.length, 7);
      expect(c.last7Days.last.total, 10);
    });

    test('custom dhikr is added to the catalogue and persists', () {
      c.addCustomDhikr(const CustomDhikrData(
        id: 'custom_1',
        transliteration: 'Hasbunallah',
        translation: 'Allah is sufficient for us',
        arabic: '',
        target: 50,
      ));
      expect(c.catalogue.any((d) => d.id == 'custom_1'), isTrue);
      c.selectDhikr('custom_1');
      expect(c.target.value, 50);
      expect(c.inSetMode.value, isFalse);
    });
  });
}
