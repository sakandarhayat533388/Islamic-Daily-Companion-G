import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'core/app_services.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'core/prayer_controller.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/prayer_times/prayer_times_screen.dart';
import 'features/qibla/qibla_screen.dart';
import 'features/settings/adhan_alerts_screen.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/settings/calculation_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/main_shell.dart';
import 'widgets/common_widgets.dart';
import 'features/tasbeeh/tasbeeh_controller.dart';
import 'features/tasbeeh/tasbeeh_history_screen.dart';
import 'features/tasbeeh/tasbeeh_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Offline-first: Inter + Amiri are bundled under assets/fonts/; never
  // fetch fonts from the network at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  await GetStorage.init();

  // Services first (settings must exist before controllers read them).
  Get.put(SettingsService(), permanent: true);
  Get.put(LocationService(), permanent: true);
  final notifications = Get.put(NotificationService(), permanent: true);
  await notifications.initPlugin();
  Get.put(PrayerController(), permanent: true);
  Get.put(TasbeehController(), permanent: true);
  await notifications.registerDailyTopUp();

  runApp(const IslamicDailyCompanionApp());
}

class IslamicDailyCompanionApp extends StatelessWidget {
  const IslamicDailyCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsService>().settings;
    return Obx(() {
      final mode = switch (settings.value.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      return GetMaterialApp(
        title: 'Islamic Daily Companion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        initialRoute: '/splash',
        getPages: [
          GetPage(name: '/splash', page: () => const SplashScreen()),
          GetPage(name: '/onboarding', page: () => const OnboardingScreen()),
          GetPage(name: '/main', page: () => const MainShell()),
          GetPage(name: '/home', page: () => const HomeScreen()),
          GetPage(name: '/times', page: () => const PrayerTimesScreen()),
          GetPage(name: '/qibla', page: () => const QiblaScreen()),
          GetPage(name: '/tasbeeh', page: () => const TasbeehScreen()),
          GetPage(name: '/tasbeeh-history', page: () => const TasbeehHistoryScreen()),
          GetPage(name: '/settings', page: () => const SettingsScreen()),
          GetPage(name: '/settings/adhan', page: () => const AdhanAlertsScreen()),
          GetPage(name: '/settings/calculation', page: () => const CalculationScreen()),
        ],
      );
    });
  }
}

/// S00 — Splash: green? No — spec says plain bg with centred mark + name.
/// Loads fast, then routes by onboarding state (max ~1.5 s; never blocks).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      final done = Get.find<SettingsService>().settings.value.onboardingDone;
      Get.offAllNamed(done ? '/main' : '/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GreenGradientBody(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: const CrescentKaabaMark(size: 96),
                ),
                const SizedBox(height: 28),
                Text(
                  'Islamic Daily\nCompanion',
                  textAlign: TextAlign.center,
                  style: AppText.h1(theme.textTheme.headlineMedium!)
                      .copyWith(color: Colors.white, height: 1.25),
                ),
                const SizedBox(height: 14),
                Container(width: 56, height: 3, color: AppColors.gold),
                const SizedBox(height: 16),
                Text(
                  'Prayer Times  ·  Qibla  ·  Tasbeeh',
                  style: AppText.body(theme.textTheme.bodyMedium!)
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
