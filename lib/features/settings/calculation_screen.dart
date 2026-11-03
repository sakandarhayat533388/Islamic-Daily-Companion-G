import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/models.dart';
import '../../core/prayer_controller.dart';
import '../../widgets/common_widgets.dart';

/// Calculation settings: method list, Asr madhab, high-latitude rule and
/// per-prayer ± minute adjustments (plan S06 group 2, full editor).
class CalculationScreen extends StatelessWidget {
  const CalculationScreen({super.key});

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
        title: const Text('Calculation'),
      ),
      body: Obx(() {
        final s = settingsService.settings.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('Calculation method'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < kMethods.length; i++) ...[
                      ListTile(
                        title: Text(kMethods[i].label,
                            style: AppText.title(theme.textTheme.bodyMedium!)),
                        subtitle: Text(kMethods[i].authority,
                            style: AppText.caption(theme.textTheme.bodyMedium!)
                                .copyWith(color: sem.muted)),
                        trailing: s.method == kMethods[i].method
                            ? Icon(Icons.check_circle, color: sem.primary)
                            : null,
                        onTap: () {
                          settingsService.updateSettings(
                              (st) => st.methodId = kMethods[i].method.name);
                          prayers.recalculate();
                        },
                      ),
                      if (i < kMethods.length - 1)
                        Divider(height: 1, indent: 16, color: sem.divider),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Eyebrow('Asr calculation'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _RadioRow(
                      title: 'Hanafi',
                      subtitle: 'Shadow = twice the object\'s length',
                      selected: s.hanafi,
                      onTap: () {
                        settingsService
                            .updateSettings((st) => st.hanafi = true);
                        prayers.recalculate();
                      },
                    ),
                    Divider(height: 1, indent: 16, color: sem.divider),
                    _RadioRow(
                      title: 'Standard',
                      subtitle: 'Shafi\'i · Maliki · Hanbali — shadow = object\'s length',
                      selected: !s.hanafi,
                      onTap: () {
                        settingsService
                            .updateSettings((st) => st.hanafi = false);
                        prayers.recalculate();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Eyebrow('High-latitude rule'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < HighLatChoice.values.length; i++) ...[
                      _RadioRow(
                        title: HighLatChoice.values[i].label,
                        subtitle: switch (HighLatChoice.values[i]) {
                          HighLatChoice.auto =>
                            'Angle-based portion of the night (recommended)',
                          HighLatChoice.middleOfNight =>
                            'Fajr/Isha capped at the middle of the night',
                          HighLatChoice.oneSeventh =>
                            'Fajr/Isha within one-seventh of the night',
                          HighLatChoice.angleBased =>
                            'Portion of night from the twilight angles',
                        },
                        selected: s.highLat == HighLatChoice.values[i],
                        onTap: () {
                          settingsService.updateSettings(
                              (st) => st.highLat = HighLatChoice.values[i]);
                          prayers.recalculate();
                        },
                      ),
                      if (i < HighLatChoice.values.length - 1)
                        Divider(height: 1, indent: 16, color: sem.divider),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Eyebrow('Adjustments (minutes)'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < kAllMarkers.length; i++) ...[
                      _AdjustmentRow(prayer: kAllMarkers[i]),
                      if (i < kAllMarkers.length - 1) const RowDivider(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Adjustments shift a prayer\'s time by a few minutes to match your local mosque. They apply everywhere, including alerts.',
                style: AppText.caption(theme.textTheme.bodyMedium!)
                    .copyWith(color: sem.muted, height: 1.4),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return ListTile(
      title: Text(title, style: AppText.title(theme.textTheme.bodyMedium!)),
      subtitle: Text(subtitle,
          style: AppText.caption(theme.textTheme.bodyMedium!)
              .copyWith(color: sem.muted)),
      trailing: selected ? Icon(Icons.check_circle, color: sem.primary) : null,
      onTap: onTap,
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  final PrayerId prayer;
  const _AdjustmentRow({required this.prayer});

  @override
  Widget build(BuildContext context) {
    final settingsService = Get.find<SettingsService>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final value = settingsService.settings.value.adjustmentFor(prayer);
    void bump(int delta) {
      settingsService.updateSettings((st) {
        final next = (st.adjustmentFor(prayer) + delta).clamp(-30, 30);
        st.adjustments[prayer.name] = next;
      });
      Get.find<PrayerController>().recalculate();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          IconChip(Icons.access_time_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(prayer.label,
                style: AppText.title(theme.textTheme.bodyMedium!)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: sem.muted,
            onPressed: () => bump(-1),
          ),
          SizedBox(
            width: 52,
            child: Text(
              value == 0 ? '0' : (value > 0 ? '+$value' : '$value'),
              textAlign: TextAlign.center,
              style: AppText.bodyStrong(theme.textTheme.bodyMedium!),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: sem.muted,
            onPressed: () => bump(1),
          ),
        ],
      ),
    );
  }
}
