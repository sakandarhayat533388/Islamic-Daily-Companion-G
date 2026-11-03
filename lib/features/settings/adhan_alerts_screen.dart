import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/models.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_controller.dart';
import '../../widgets/common_widgets.dart';

/// S06b — Adhan & Alerts: master toggle, per-prayer sound + pre-alert,
/// exact-alarm state card, scheduling caption (DESIGN_SPEC S06b).
class AdhanAlertsScreen extends StatefulWidget {
  const AdhanAlertsScreen({super.key});

  @override
  State<AdhanAlertsScreen> createState() => _AdhanAlertsScreenState();
}

class _AdhanAlertsScreenState extends State<AdhanAlertsScreen> {
  bool? _exactGranted;

  @override
  void initState() {
    super.initState();
    _checkExact();
  }

  Future<void> _checkExact() async {
    final ok = await Get.find<NotificationService>().canScheduleExact();
    if (mounted) setState(() => _exactGranted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Get.find<SettingsService>();
    final prayers = Get.find<PrayerController>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('Adhan & Alerts'),
      ),
      body: Obx(() {
        final alerts = settingsService.alerts.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master card
              AppCard(
                child: Row(
                  children: [
                    const IconChip(Icons.notifications_active_outlined, gold: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adhan alerts',
                              style: AppText.title(theme.textTheme.bodyMedium!)),
                          Text('Play the Adhan at each prayer time',
                              style: AppText.caption(theme.textTheme.bodyMedium!)
                                  .copyWith(color: sem.muted)),
                        ],
                      ),
                    ),
                    Switch(
                      value: alerts.masterEnabled,
                      onChanged: (v) {
                        settingsService
                            .updateAlerts((a) => a.masterEnabled = v);
                        prayers.recalculate();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Per-prayer card
              Eyebrow('Per prayer'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < kFivePrayers.length; i++) ...[
                      _PrayerAlertRow(
                        prayer: kFivePrayers[i],
                        onChanged: prayers.recalculate,
                      ),
                      if (i < kFivePrayers.length - 1) const RowDivider(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Exact alarm state card
              if (_exactGranted == false)
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
                      Text(
                        'Without exact-alarm permission the Adhan may arrive a few minutes late.',
                        style: AppText.body(theme.textTheme.bodyMedium!)
                            .copyWith(color: const Color(0xFF5C4A08), height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          await Permission.scheduleExactAlarm.request();
                          await _checkExact();
                          prayers.recalculate();
                        },
                        child: Text('Allow exact alarms ›',
                            style: AppText.bodyStrong(theme.textTheme.bodyMedium!)
                                .copyWith(color: AppColors.primaryLight)),
                      ),
                    ],
                  ),
                )
              else if (_exactGranted == true)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sem.primarySoft,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: sem.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Exact alarms allowed',
                            style: AppText.body(theme.textTheme.bodyMedium!)
                                .copyWith(color: sem.primary)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Alerts are scheduled 7 days ahead and renew automatically.',
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
}

class _PrayerAlertRow extends StatelessWidget {
  final PrayerId prayer;
  final VoidCallback onChanged;
  const _PrayerAlertRow({required this.prayer, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final settingsService = Get.find<SettingsService>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final alert = settingsService.alerts.value.forPrayer(prayer);
    return SettingsRow(
      icon: Icons.notifications_outlined,
      title: prayer.label,
      subtitle: alert.mode == AlertMode.off
          ? 'Off'
          : (prayer == PrayerId.fajr && alert.mode == AlertMode.adhan
              ? 'Fajr Adhan · Voice 1'
              : alert.mode.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            alert.preAlertMinutes == 0
                ? 'Off'
                : '${alert.preAlertMinutes} min before',
            style: AppText.caption(theme.textTheme.bodyMedium!)
                .copyWith(color: sem.muted),
          ),
          Icon(Icons.chevron_right, size: 20, color: sem.muted),
        ],
      ),
      onTap: () => _showEditor(context, settingsService),
    );
  }

  void _showEditor(BuildContext context, SettingsService settingsService) {
    final current = settingsService.alerts.value.forPrayer(prayer);
    var mode = current.mode.obs;
    var pre = current.preAlertMinutes.obs;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${prayer.label} alert',
                    style: AppText.h2(Theme.of(context).textTheme.titleLarge!)),
                const SizedBox(height: 12),
                Text('Sound',
                    style: AppText.micro(Theme.of(context).textTheme.bodyMedium!)
                        .copyWith(color: SemanticColors.of(context).muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in AlertMode.values)
                      ChoiceChip(
                        label: Text(prayer == PrayerId.fajr && m == AlertMode.adhan
                            ? 'Fajr Adhan · Voice 1'
                            : m.label),
                        selected: mode.value == m,
                        onSelected: (_) => mode.value = m,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Remind me before',
                    style: AppText.micro(Theme.of(context).textTheme.bodyMedium!)
                        .copyWith(color: SemanticColors.of(context).muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mins in const [0, 5, 10, 15])
                      ChoiceChip(
                        label: Text(mins == 0 ? 'Off' : '$mins min'),
                        selected: pre.value == mins,
                        onSelected: (_) => pre.value = mins,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    settingsService.updateAlerts((a) {
                      final t = a.forPrayer(prayer);
                      t.mode = mode.value;
                      t.preAlertMinutes = pre.value;
                    });
                    onChanged();
                    Get.back();
                  },
                  child: const Text('Save'),
                ),
              ],
            )),
      ),
      isScrollControlled: true,
    );
  }
}
