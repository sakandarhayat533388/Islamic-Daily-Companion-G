import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/models.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_controller.dart';
import '../../core/prayer_engine.dart';
import '../../widgets/common_widgets.dart';

class OnboardingController extends GetxController {
  final page = 0.obs;
  final locating = false.obs;
  final pageController = PageController();

  SettingsService get _settings => Get.find<SettingsService>();
  LocationService get _location => Get.find<LocationService>();

  @override
  void onInit() {
    super.onInit();
    _location.loadCities();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  void goTo(int p) {
    page.value = p;
    pageController.animateToPage(p,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _applyLocation({
    required double lat,
    required double lng,
    required double utc,
    required String city,
    required String country,
    required String code,
    required String mode,
  }) {
    final defaults = defaultsForCountry(code);
    _settings.updateSettings((s) {
      s.lat = lat;
      s.lng = lng;
      s.utcOffsetHours = utc;
      s.cityName = city;
      s.countryName = country;
      s.countryCode = code;
      s.locationMode = mode;
      s.methodId = defaults.method.name;
      s.hanafi = defaults.hanafi;
    });
  }

  Future<void> useMyLocation() async {
    locating.value = true;
    try {
      await _location.loadCities();
      final pos = await _location.currentPosition();
      if (pos == null) {
        Get.snackbar('Location unavailable',
            'Permission was not granted. You can pick your city manually instead.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final geo = await _location.reverseGeocode(pos.latitude, pos.longitude);
      final near = _location.nearestCity(pos.latitude, pos.longitude);
      _applyLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        utc: DateTime.now().timeZoneOffset.inMinutes / 60.0,
        city: geo?.city ?? near?.name ?? 'Current location',
        country: geo?.country ?? near?.country ?? '',
        code: (geo?.code.isNotEmpty ?? false) ? geo!.code : (near?.countryCode ?? ''),
        mode: 'gps',
      );
      goTo(2);
    } finally {
      locating.value = false;
    }
  }

  void chooseCity(CityEntry city) {
    _applyLocation(
      lat: city.lat,
      lng: city.lng,
      utc: city.utc,
      city: city.name,
      country: city.country,
      code: city.countryCode,
      mode: 'manual',
    );
    Get.back(); // close picker
    goTo(2);
  }

  Future<void> finish() async {
    try {
      await Get.find<NotificationService>().requestPermissions();
    } catch (_) {}
    _settings.updateSettings((s) => s.onboardingDone = true);
    Get.find<PrayerController>().recalculate();
    Get.offAllNamed('/main');
  }

  void skip() {
    _settings.updateSettings((s) => s.onboardingDone = true);
    Get.find<PrayerController>().recalculate();
    Get.offAllNamed('/main');
  }
}

/// Shared manual city picker sheet (onboarding + settings reuse).
void showCityPicker(BuildContext context, void Function(CityEntry) onPick) {
  final location = Get.find<LocationService>();
  final query = ''.obs;
  Get.bottomSheet(
    Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search city or country',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
              onChanged: (v) => query.value = v.toLowerCase(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              final all = location.cities;
              final filtered = query.value.isEmpty
                  ? all
                  : all
                      .where((c) =>
                          c.name.toLowerCase().contains(query.value) ||
                          c.country.toLowerCase().contains(query.value))
                      .toList();
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(c.name),
                    subtitle: Text(c.country),
                    onTap: () => onPick(c),
                  );
                },
              );
            }),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(OnboardingController());
    return Scaffold(
      body: GreenGradientBody(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: c.pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _WelcomePage(),
                    _LocationPage(),
                    _ConfirmPage(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Obx(() => PageDots(index: c.page.value, onGreen: true)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sem.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final theme = Theme.of(context);
    const features = [
      (Icons.schedule_rounded, 'Prayer Times & Adhan', 'Accurate times for your city, with Adhan alerts.'),
      (Icons.explore_rounded, 'Qibla Direction', 'Compass pointing to the Kaaba, wherever you are.'),
      (Icons.toll_rounded, 'Digital Tasbeeh', 'Count your dhikr and keep your daily streak.'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CrescentKaabaMark(size: 72),
          const SizedBox(height: 16),
          Text('Never miss a prayer.',
              style: AppText.h1(theme.textTheme.headlineMedium!)
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 20),
          for (final f in features) ...[
            _Card(
              child: Row(
                children: [
                  IconChip(f.$1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$2, style: AppText.title(theme.textTheme.bodyMedium!)),
                        Text(f.$3,
                            style: AppText.caption(theme.textTheme.bodyMedium!)
                                .copyWith(color: SemanticColors.of(context).muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Works fully offline. No account needed.',
                    style: AppText.title(theme.textTheme.bodyMedium!)
                        .copyWith(color: const Color(0xFF5C4A08))),
                const SizedBox(height: 4),
                Text(
                  'Your location is calculated on this phone only and is never sent anywhere.',
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: const Color(0xFF5C4A08)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryLight,
            ),
            onPressed: () => c.goTo(1),
            child: const Text('Continue'),
          ),
          Center(
            child: TextButton(
              onPressed: c.skip,
              child: Text('Skip',
                  style: AppText.bodyStrong(theme.textTheme.bodyMedium!)
                      .copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPage extends StatelessWidget {
  const _LocationPage();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final theme = Theme.of(context);
    final settings = Get.find<SettingsService>().settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => c.goTo(0),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text('Where are you praying?',
              style: AppText.h1(theme.textTheme.headlineMedium!)
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            'Your location is used on this phone only, to calculate prayer times and Qibla direction. It is never sent anywhere.',
            style: AppText.body(theme.textTheme.bodyMedium!)
                .copyWith(color: Colors.white.withValues(alpha: 0.9), height: 1.45),
          ),
          const SizedBox(height: 24),
          _Card(
            child: Row(
              children: [
                const IconChip(Icons.location_on),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => Text(
                            '${settings.value.cityName}, ${settings.value.countryName}',
                            style: AppText.title(theme.textTheme.bodyMedium!),
                          )),
                      Text('Detected from GPS · you can change this anytime',
                          style: AppText.caption(theme.textTheme.bodyMedium!)
                              .copyWith(color: SemanticColors.of(context).muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryLight,
                ),
                onPressed: c.locating.value ? null : c.useMyLocation,
                child: c.locating.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Use my location'),
              )),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            onPressed: () => showCityPicker(context, c.chooseCity),
            child: const Text('Choose city manually'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmPage extends StatelessWidget {
  const _ConfirmPage();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final settingsService = Get.find<SettingsService>();
    final settings = settingsService.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => c.goTo(1),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text('Your settings — please confirm',
              style: AppText.h1(theme.textTheme.headlineMedium!)
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 20),
          _Card(
            child: Obx(() {
              final s = settings.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    label: 'Location',
                    value: '${s.cityName}, ${s.countryName}',
                    onChange: () => showCityPicker(context, (city) {
                      c.chooseCity(city);
                      c.page.value = 2;
                    }),
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Calculation method',
                    value: methodLabel(s.method),
                    caption: kMethods
                        .firstWhere((m) => m.method == s.method,
                            orElse: () => kMethods[1])
                        .authority,
                  ),
                  const Divider(height: 24),
                  Text('Asr calculation',
                      style: AppText.caption(theme.textTheme.bodyMedium!)
                          .copyWith(color: sem.muted)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: sem.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final hanafi in [true, false])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => settingsService.updateSettings(
                                  (st) => st.hanafi = hanafi),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: s.hanafi == hanafi
                                      ? sem.surface
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: s.hanafi == hanafi
                                      ? AppTheme.cardShadow(
                                          Theme.of(context).brightness)
                                      : null,
                                ),
                                child: Text(
                                  hanafi ? 'Hanafi' : 'Standard',
                                  textAlign: TextAlign.center,
                                  style: AppText.bodyStrong(
                                          theme.textTheme.bodyMedium!)
                                      .copyWith(
                                          color: s.hanafi == hanafi
                                              ? sem.primary
                                              : sem.muted),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.countryCode == 'PK'
                        ? 'This matches most mosques in Pakistan.'
                        : 'You can change this anytime in Settings.',
                    style: AppText.caption(theme.textTheme.bodyMedium!)
                        .copyWith(color: sem.muted),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconChip(Icons.notifications_active_outlined, gold: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adhan alerts',
                          style: AppText.title(theme.textTheme.bodyMedium!)),
                      const SizedBox(height: 2),
                      Text(
                        'So the Adhan plays on time even when the app is closed, allow notifications and exact alarms. If alerts ever arrive late, turn off battery optimisation for this app in system settings.',
                        style: AppText.caption(theme.textTheme.bodyMedium!)
                            .copyWith(color: sem.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('You can change all of this anytime in Settings.',
                style: AppText.caption(theme.textTheme.bodyMedium!)
                    .copyWith(color: Colors.white.withValues(alpha: 0.8))),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryLight,
            ),
            onPressed: c.finish,
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final VoidCallback? onChange;
  const _SummaryRow(
      {required this.label, required this.value, this.caption, this.onChange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.muted)),
              const SizedBox(height: 2),
              Text(value, style: AppText.title(theme.textTheme.bodyMedium!)),
              if (caption != null)
                Text(caption!,
                    style: AppText.caption(theme.textTheme.bodyMedium!)
                        .copyWith(color: sem.muted)),
            ],
          ),
        ),
        if (onChange != null)
          TextButton(onPressed: onChange, child: const Text('Change')),
      ],
    );
  }
}
