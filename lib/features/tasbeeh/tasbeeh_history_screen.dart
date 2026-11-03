import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/content_data.dart';
import '../../widgets/common_widgets.dart';
import 'tasbeeh_controller.dart';

/// S05b — Tasbeeh History: summary card, today-by-dhikr, last-7-days bars.
class TasbeehHistoryScreen extends StatelessWidget {
  const TasbeehHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TasbeehController>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('Tasbeeh History'),
      ),
      body: Obx(() {
        final todayKey = TasbeehController.dateKey(DateTime.now());
        final todayByDhikr = c.records[todayKey] ?? const <String, int>{};
        final entries = todayByDhikr.entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxRow = entries.isEmpty
            ? 1
            : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
        final week = c.last7Days;
        final maxBar = week.map((d) => d.total).fold(1, (a, b) => a > b ? a : b);
        String nameOf(String id) {
          if (id.startsWith('custom_')) {
            return c.customDhikr
                    .firstWhereOrNull((x) => x.id == id)
                    ?.transliteration ??
                'Custom dhikr';
          }
          return kBuiltinDhikr
                  .firstWhereOrNull((x) => x.id == id)
                  ?.transliteration ??
              id;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.todayTotal}',
                              style: AppText.h1(theme.textTheme.headlineMedium!)),
                          Text('Today · across all dhikr',
                              style: AppText.caption(theme.textTheme.bodyMedium!)
                                  .copyWith(color: sem.muted)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: AppColors.gold, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text('${c.streak}',
                                style: AppText.h1(theme.textTheme.headlineMedium!)
                                    .copyWith(color: AppColors.gold)),
                          ],
                        ),
                        Text('day streak',
                            style: AppText.caption(theme.textTheme.bodyMedium!)
                                .copyWith(color: sem.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Today by dhikr
              Eyebrow('Today by dhikr'),
              const SizedBox(height: 8),
              AppCard(
                child: entries.isEmpty
                    ? Text('No dhikr counted yet today.',
                        style: AppText.body(theme.textTheme.bodyMedium!)
                            .copyWith(color: sem.muted))
                    : Column(
                        children: [
                          for (final e in entries) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(nameOf(e.key),
                                      style: AppText.body(
                                          theme.textTheme.bodyMedium!)),
                                ),
                                Text('${e.value}',
                                    style: AppText.bodyStrong(
                                        theme.textTheme.bodyMedium!)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: e.value / maxRow,
                                minHeight: 5,
                                backgroundColor: sem.divider,
                                color: sem.primary,
                              ),
                            ),
                            if (e != entries.last) const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              // Last 7 days
              Eyebrow('Last 7 days'),
              const SizedBox(height: 8),
              AppCard(
                child: SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in week)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${d.total}',
                                  style: AppText.micro(
                                          theme.textTheme.bodyMedium!)
                                      .copyWith(color: sem.muted, fontSize: 9)),
                              const SizedBox(height: 4),
                              Container(
                                height: 96 * (d.total / maxBar),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: TasbeehController.dateKey(d.date) ==
                                          todayKey
                                      ? sem.primary
                                      : sem.primarySoft,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('E').format(d.date).substring(0, 1),
                                style: AppText.caption(
                                        theme.textTheme.bodyMedium!)
                                    .copyWith(color: sem.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('History is stored on this phone only.',
                    style: AppText.caption(theme.textTheme.bodyMedium!)
                        .copyWith(color: sem.muted)),
              ),
            ],
          ),
        );
      }),
    );
  }
}
