import 'package:flutter/material.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:islamic_daily_companion/core/app_services.dart';
import 'package:islamic_daily_companion/core/app_theme.dart';
import 'package:islamic_daily_companion/core/models.dart';
import 'package:islamic_daily_companion/core/prayer_controller.dart';
import 'package:islamic_daily_companion/core/prayer_engine.dart';
import 'package:islamic_daily_companion/features/home/home_screen.dart';
import 'package:islamic_daily_companion/features/shell/main_shell.dart';
import 'package:islamic_daily_companion/features/tasbeeh/tasbeeh_controller.dart';
import 'package:islamic_daily_companion/features/tasbeeh/tasbeeh_screen.dart';

/// Widget tests pump the REAL app theme (SubTrack lesson: never test a
/// themed screen under a bare MaterialApp theme).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // google_fonts must not fetch Inter/Amiri over HTTP inside tests.
    GoogleFonts.config.allowRuntimeFetching = false;
    // GetStorage needs path_provider, which has no test implementation.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '/tmp');
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'vibration',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
    // Controllers use the DEFAULT GetStorage container (as in main.dart).
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
    Get.testMode = true;
    Get.put(SettingsService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(PrayerController(), permanent: true);
    Get.put(TasbeehController(), permanent: true);
    Get.put(ShellController(), permanent: true);
  });

  tearDown(() async {
    await Get.delete<PrayerController>(force: true);
    Get.reset();
  });

  testWidgets('Home renders hero, times card, dua and tiles in design order',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Karachi, Pakistan'), findsOneWidget);
    expect(find.text("TODAY'S PRAYERS"), findsOneWidget);
    expect(find.text('Fajr'), findsWidgets);
    expect(find.text('Isha'), findsWidgets);
    expect(find.text('NEXT PRAYER'), findsOneWidget);
    expect(find.text('DAILY DUA'), findsOneWidget);
    expect(find.text('Qibla'), findsWidgets);
    expect(find.text('Tasbeeh'), findsWidgets);
    // The six prayer rows render their times in HH:mm form. The expected
    // Fajr value is computed for TODAY (a hardcoded '05:23' was only true
    // on 2026-11-03 and made this test date-brittle; golden-date accuracy
    // is covered by prayer_engine_test.dart).
    final s = AppSettingsData();
    final today = PrayerEngine.calculate(
      lat: s.lat,
      lng: s.lng,
      utcOffsetHours: s.utcOffsetHours,
      date: DateTime.now(),
      method: s.method,
      hanafi: s.hanafi,
      highLat: s.highLat,
      adjustments: s.adjustments,
    );
    expect(find.text(PrayerController.fmtTime(today.timeFor(PrayerId.fajr))),
        findsWidgets);
  });

  testWidgets('Tasbeeh renders and the ring tap increments the count',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const TasbeehScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SubhanAllah'), findsWidgets);
    expect(find.text('Tap the circle to count'), findsOneWidget);
    // The big ring numeral (fontSize 96) — stats elsewhere also show "0".
    Finder ringCount(String v) => find.byWidgetPredicate((w) =>
        w is Text && w.data == v && (w.style?.fontSize ?? 0) > 40);
    expect(ringCount('0'), findsOneWidget);

    await tester.tap(ringCount('0'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ringCount('1'), findsOneWidget);
    expect(Get.find<TasbeehController>().todayTotal, 1);
  });
}
