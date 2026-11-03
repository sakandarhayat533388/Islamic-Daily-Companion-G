import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/models.dart';
import '../../core/prayer_controller.dart';
import '../../widgets/common_widgets.dart';

class PrayerTimesController extends GetxController {
  final monthOffset = 0.obs;
  final selectedDay = Rxn<DateTime>();

  DateTime get visibleMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + monthOffset.value);
  }
}

/// S03 — Prayer Times, monthly. 6-column grid (Sunrise omitted per spec),
/// today highlighted, tap a day for its full detail (with Sunrise + bells).
class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PrayerTimesController());
    final prayers = Get.find<PrayerController>();
    final settingsService = Get.find<SettingsService>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Prayer Times',
                        style: AppText.h1(theme.textTheme.headlineMedium!)),
                  ),
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: sem.muted),
                    onPressed: () {
                      final today = prayers.today.value;
                      if (today != null) {
                        Share.share(shareTextForDay(
                            today, settingsService.settings.value));
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final month = c.visibleMonth;
                final daysInMonth =
                    DateTime(month.year, month.month + 1, 0).day;
                final s = settingsService.settings.value;
                final firstDay = prayers.dayFor(DateTime(month.year, month.month, 1));
                final lastDay =
                    prayers.dayFor(DateTime(month.year, month.month, daysInMonth));
                final hijriRange = firstDay != null && lastDay != null
                    ? (firstDay.hijriMonthName == lastDay.hijriMonthName
                        ? '${firstDay.hijriMonthName} ${firstDay.hijriYear}'
                        : '${firstDay.hijriMonthName} – ${lastDay.hijriMonthName} ${lastDay.hijriYear}')
                    : '';
                final now = DateTime.now();
                final selected = c.selectedDay.value;
                return Column(
                  children: [
                    // Month header card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => c.monthOffset.value--,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('MMMM yyyy').format(month),
                                    style: AppText.h2(theme.textTheme.titleLarge!),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(hijriRange,
                                      style: AppText.caption(
                                              theme.textTheme.bodyMedium!)
                                          .copyWith(color: sem.muted),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => c.monthOffset.value++,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Column headers
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          const SizedBox(width: 52, child: Eyebrow('Day')),
                          for (final p in const [
                            PrayerId.fajr,
                            PrayerId.dhuhr,
                            PrayerId.asr,
                            PrayerId.maghrib,
                            PrayerId.isha,
                          ])
                            Expanded(
                              child: Text(p.label.toUpperCase(),
                                  style: AppText.micro(
                                          theme.textTheme.bodyMedium!)
                                      .copyWith(color: sem.muted),
                                  textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Day rows
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: daysInMonth,
                        itemBuilder: (_, i) {
                          final date =
                              DateTime(month.year, month.month, i + 1);
                          final day = prayers.dayFor(date);
                          if (day == null) return const SizedBox.shrink();
                          final isToday = date.year == now.year &&
                              date.month == now.month &&
                              date.day == now.day;
                          return GestureDetector(
                            onTap: () => c.selectedDay.value = date,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 9),
                              decoration: BoxDecoration(
                                color:
                                    isToday ? sem.primarySoft : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 52,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? sem.primary
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${date.day}',
                                              style: AppText.bodyStrong(theme
                                                      .textTheme.bodyMedium!)
                                                  .copyWith(
                                                      color: isToday
                                                          ? Colors.white
                                                          : sem.ink),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('E')
                                              .format(date)
                                              .substring(0, 1),
                                          style: AppText.caption(
                                                  theme.textTheme.bodyMedium!)
                                              .copyWith(color: sem.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final p in const [
                                    PrayerId.fajr,
                                    PrayerId.dhuhr,
                                    PrayerId.asr,
                                    PrayerId.maghrib,
                                    PrayerId.isha,
                                  ])
                                    Expanded(
                                      child: Text(
                                        PrayerController.fmtTime(day.timeFor(p)),
                                        textAlign: TextAlign.center,
                                        style: AppText.body(
                                                theme.textTheme.bodyMedium!)
                                            .copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                          color: isToday ? sem.primary : sem.ink,
                                          fontWeight: isToday
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Selected day detail
                    if (selected != null)
                      _DayDetail(
                        date: selected,
                        onClose: () => c.selectedDay.value = null,
                      ),
                    // Footer summary card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: AppCard(
                        child: Row(
                          children: [
                            const IconChip(Icons.settings_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${methodLabel(s.method)} method · ${s.hanafi ? 'Hanafi' : 'Standard'} Asr',
                                    style: AppText.bodyStrong(
                                        theme.textTheme.bodyMedium!),
                                  ),
                                  Text(
                                    _adjustmentSummary(s),
                                    style: AppText.caption(
                                            theme.textTheme.bodyMedium!)
                                        .copyWith(color: sem.muted),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Get.toNamed('/settings/calculation'),
                              child: const Text('Edit ›'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  static String _adjustmentSummary(AppSettingsData s) {
    final nonZero = s.adjustments.entries.where((e) => e.value != 0).toList();
    if (nonZero.isEmpty) return '+0 min adjustments';
    return nonZero
        .map((e) =>
            '${PrayerId.values.firstWhere((p) => p.name == e.key).label} ${e.value >= 0 ? '+' : ''}${e.value}')
        .join(' · ');
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime date;
  final VoidCallback onClose;
  const _DayDetail({required this.date, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final prayers = Get.find<PrayerController>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final day = prayers.dayFor(date);
    if (day == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('EEEE, d MMMM').format(date)} · ${day.hijriFull}',
                    style:
                        AppText.bodyStrong(theme.textTheme.bodyMedium!),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final p in kAllMarkers)
                  SizedBox(
                    width: 96,
                    child: Row(
                      children: [
                        Text('${p.label} ',
                            style: AppText.caption(theme.textTheme.bodyMedium!)
                                .copyWith(color: sem.muted)),
                        Text(PrayerController.fmtTime(day.timeFor(p)),
                            style: AppText.bodyStrong(
                                theme.textTheme.bodyMedium!)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
