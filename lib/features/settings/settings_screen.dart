import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/models.dart';
import '../../core/prayer_controller.dart';
import '../../core/prayer_engine.dart';
import '../../widgets/common_widgets.dart';
import '../onboarding/onboarding_screens.dart' show showCityPicker;
import '../tasbeeh/tasbeeh_controller.dart';

/// Hosted full Privacy Policy (Google Docs, owner-provided 2026-11-05).
/// The same URL is used in the Play Store listing.
const String kPrivacyPolicyUrl =
    'https://docs.google.com/document/d/1DPtRlJm8NEjXVqUBB2ros2Bw-C5_Ii3MGk77k4uqo3U/edit?usp=sharing';

/// S06 — Settings. Six groups in the locked spec order:
/// Location, Calculation, Adhan & Alerts, Tasbeeh, Appearance, About.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Get.find<SettingsService>();
    final prayers = Get.find<PrayerController>();
    final tasbeeh = Get.find<TasbeehController>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);

    Widget group(String label, List<Widget> rows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Eyebrow(label),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: rows),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    Widget chevronValue(String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: AppText.body(Theme.of(context).textTheme.bodyMedium!)
                    .copyWith(color: sem.muted)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 20, color: sem.muted),
          ],
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('Settings'),
      ),
      body: Obx(() {
        final s = settingsService.settings.value;
        final tp = tasbeeh.prefs.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. LOCATION
              group('Location', [
                SettingsRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  subtitle: '${s.cityName}, ${s.countryName}',
                  trailing: chevronValue(''),
                  onTap: () => showCityPicker(context, (city) {
                    final defaults = defaultsForCountry(city.countryCode);
                    settingsService.updateSettings((st) {
                      st.lat = city.lat;
                      st.lng = city.lng;
                      st.utcOffsetHours = city.utc;
                      st.cityName = city.name;
                      st.countryName = city.country;
                      st.countryCode = city.countryCode;
                      st.locationMode = 'manual';
                      st.methodId = defaults.method.name;
                      st.hanafi = defaults.hanafi;
                    });
                    Get.back();
                    prayers.recalculate();
                  }),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.my_location_outlined,
                  title: 'Mode',
                  subtitle: s.locationMode == 'gps' ? 'Auto (GPS)' : 'Manual city',
                  trailing: chevronValue(''),
                  onTap: () async {
                    final mode = await _pickMode(context, s.locationMode);
                    if (mode == null) return;
                    if (mode == 'gps') {
                      final loc = Get.find<LocationService>();
                      final pos = await loc.currentPosition();
                      if (pos == null) {
                        Get.snackbar('Location unavailable',
                            'GPS permission was not granted.',
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      final geo =
                          await loc.reverseGeocode(pos.latitude, pos.longitude);
                      final near =
                          loc.nearestCity(pos.latitude, pos.longitude);
                      final defaults =
                          defaultsForCountry(geo?.code ?? near?.countryCode ?? '');
                      settingsService.updateSettings((st) {
                        st.locationMode = 'gps';
                        st.lat = pos.latitude;
                        st.lng = pos.longitude;
                        st.utcOffsetHours =
                            DateTime.now().timeZoneOffset.inMinutes / 60.0;
                        st.cityName = geo?.city ?? near?.name ?? st.cityName;
                        st.countryName = geo?.country ?? near?.country ?? st.countryName;
                        st.countryCode = (geo?.code.isNotEmpty ?? false)
                            ? geo!.code
                            : (near?.countryCode ?? st.countryCode);
                        st.methodId = defaults.method.name;
                        st.hanafi = defaults.hanafi;
                      });
                    } else {
                      settingsService
                          .updateSettings((st) => st.locationMode = 'manual');
                    }
                    prayers.recalculate();
                  },
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.refresh_rounded,
                  title: 'Update now',
                  subtitle: 'Refresh location and times',
                  onTap: () async {
                    if (s.locationMode == 'gps') {
                      final loc = Get.find<LocationService>();
                      final pos = await loc.currentPosition();
                      if (pos != null) {
                        settingsService.updateSettings((st) {
                          st.lat = pos.latitude;
                          st.lng = pos.longitude;
                        });
                      }
                    }
                    prayers.recalculate();
                    Get.snackbar('Updated', 'Prayer times recalculated.',
                        snackPosition: SnackPosition.BOTTOM);
                  },
                ),
              ]),
              // 2. CALCULATION
              group('Calculation', [
                SettingsRow(
                  icon: Icons.calculate_outlined,
                  title: 'Method',
                  subtitle: methodLabel(s.method),
                  trailing: chevronValue(''),
                  onTap: () => Get.toNamed('/settings/calculation'),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.access_time_outlined,
                  title: 'Asr calculation',
                  subtitle: s.hanafi ? 'Hanafi' : 'Standard (Shafi\'i)',
                  trailing: chevronValue(''),
                  onTap: () => Get.toNamed('/settings/calculation'),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.public_outlined,
                  title: 'High-latitude rule',
                  subtitle: s.highLat.label,
                  trailing: chevronValue(''),
                  onTap: () => Get.toNamed('/settings/calculation'),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.tune_outlined,
                  title: 'Adjustments',
                  subtitle: _adjustmentLabel(s),
                  trailing: chevronValue(''),
                  onTap: () => Get.toNamed('/settings/calculation'),
                ),
              ]),
              // 3. ADHAN & ALERTS
              group('Adhan & Alerts', [
                SettingsRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Adhan & Alerts',
                  subtitle:
                      settingsService.alerts.value.masterEnabled ? 'On' : 'Off',
                  goldChip: true,
                  trailing: chevronValue(''),
                  onTap: () => Get.toNamed('/settings/adhan'),
                ),
                const RowDivider(),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      final status =
                          await Permission.ignoreBatteryOptimizations.request();
                      if (!status.isGranted) {
                        await openAppSettings();
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.battery_alert_outlined,
                            color: Color(0xFF8A6D14), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Adhan arriving late? Allow background running ›',
                            style: AppText.body(theme.textTheme.bodyMedium!)
                                .copyWith(color: const Color(0xFF5C4A08)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              // 4. TASBEEH
              group('Tasbeeh', [
                SettingsRow(
                  icon: Icons.vibration_rounded,
                  title: 'Vibration on tap',
                  trailing: Switch(
                    value: tp.vibrationOnTap,
                    onChanged: (v) =>
                        tasbeeh.updatePrefs((p) => p.vibrationOnTap = v),
                  ),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound at target',
                  trailing: Switch(
                    value: tp.soundAtTarget,
                    onChanged: (v) =>
                        tasbeeh.updatePrefs((p) => p.soundAtTarget = v),
                  ),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Keep screen on',
                  subtitle: 'While the Tasbeeh screen is open',
                  trailing: Switch(
                    value: tp.keepScreenOn,
                    onChanged: (v) =>
                        tasbeeh.updatePrefs((p) => p.keepScreenOn = v),
                  ),
                ),
              ]),
              // 5. APPEARANCE
              group('Appearance', [
                SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  subtitle: switch (s.themeMode) {
                    'light' => 'Light',
                    'dark' => 'Dark',
                    _ => 'System',
                  },
                  trailing: chevronValue(''),
                  onTap: () async {
                    final mode = await _pickTheme(context, s.themeMode);
                    if (mode != null) {
                      settingsService
                          .updateSettings((st) => st.themeMode = mode);
                    }
                  },
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.widgets_outlined,
                  title: 'Home-screen widget',
                  subtitle:
                      'Add from your launcher: long-press Home → Widgets → Islamic Daily Companion',
                ),
              ]),
              // 6. ABOUT
              group('About', [
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'How times are calculated',
                  trailing: chevronValue(''),
                  onTap: () => _showHowCalculated(context),
                ),
                const RowDivider(),
                SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  trailing: chevronValue(''),
                  onTap: () => _showPrivacy(context),
                ),
                const RowDivider(),
                const SettingsRow(
                  icon: Icons.badge_outlined,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
              ]),
              Center(
                child: Text(
                  'Adhan audio: placeholder tone in this build — a licensed recording will replace it before release.',
                  textAlign: TextAlign.center,
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.muted),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static String _adjustmentLabel(AppSettingsData s) {
    final nz = s.adjustments.entries.where((e) => e.value != 0).length;
    return nz == 0 ? '+0 min' : '$nz prayer(s) adjusted';
  }

  Future<String?> _pickMode(BuildContext context, String current) {
    return Get.bottomSheet<String>(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Auto (GPS)'),
              trailing: current == 'gps' ? const Icon(Icons.check) : null,
              onTap: () => Get.back(result: 'gps'),
            ),
            ListTile(
              title: const Text('Manual city'),
              trailing: current == 'manual' ? const Icon(Icons.check) : null,
              onTap: () => Get.back(result: 'manual'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickTheme(BuildContext context, String current) {
    return Get.bottomSheet<String>(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (id, label) in const [
              ('system', 'System'),
              ('light', 'Light'),
              ('dark', 'Dark'),
            ])
              ListTile(
                title: Text(label),
                trailing: current == id ? const Icon(Icons.check) : null,
                onTap: () => Get.back(result: id),
              ),
          ],
        ),
      ),
    );
  }

  void _showHowCalculated(BuildContext context) {
    final s = Get.find<SettingsService>().settings.value;
    Get.dialog(
      AlertDialog(
        title: const Text('How times are calculated'),
        content: SingleChildScrollView(
          child: Text(
            'Prayer times are calculated on this phone from the position of the sun — nothing is fetched from the internet.\n\n'
            '· Fajr and Isha begin when the sun drops to the angle set by your calculation method (currently ${methodLabel(s.method)}).\n'
            '· Sunrise and Maghrib are when the sun crosses the horizon.\n'
            '· Dhuhr is solar noon.\n'
            '· Asr begins when an object\'s shadow equals its length (Standard) or twice its length (Hanafi) — currently ${s.hanafi ? 'Hanafi' : 'Standard'}.\n\n'
            'Different regions follow different methods. If your mosque uses slightly different times, add a small adjustment in Settings → Calculation → Adjustments.\n\n'
            'Your location never leaves this phone.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Islamic Daily Companion is designed to be private by construction:\n\n'
            '· No account, no sign-up, no analytics, no ads.\n'
            '· Your location is used only on this phone to calculate prayer times and Qibla direction. It is never sent to any server.\n'
            '· Prayer times are calculated on-device; the app works fully offline.\n'
            '· Tasbeeh history and settings are stored only on this phone.\n'
            '· The app requests location, notification and exact-alarm permissions only for the features described above.\n\n'
            'The full Privacy Policy is published online and is the same one linked in the Play Store listing.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(kPrivacyPolicyUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Open full policy'),
          ),
        ],
      ),
    );
  }
}
