import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../core/content_data.dart';
import '../../widgets/common_widgets.dart';
import 'tasbeeh_controller.dart';

/// S05 — Tasbeeh, following DESIGN_SPEC order: header card → set progress →
/// big ring tap target → actions → footer stats.
class TasbeehScreen extends StatelessWidget {
  const TasbeehScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TasbeehController>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Tasbeeh',
                        style: AppText.h1(theme.textTheme.headlineMedium!)),
                  ),
                  IconButton(
                    icon: Icon(Icons.history_rounded, color: sem.muted),
                    onPressed: () => Get.toNamed('/tasbeeh-history'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Dhikr header card (tappable → picker)
              Obx(() {
                final d = c.currentDhikr;
                return AppCard(
                  onTap: () => _showPicker(context, c),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: StarLatticePainter(
                              color: sem.primary.withValues(alpha: 0.05),
                              cell: 44),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.transliteration,
                                    style: AppText.h2(theme.textTheme.titleLarge!)),
                                const SizedBox(height: 2),
                                Text(d.translation,
                                    style: AppText.caption(theme.textTheme.bodyMedium!)
                                        .copyWith(color: sem.muted)),
                                const SizedBox(height: 6),
                                Text('Tap header to change dhikr',
                                    style: AppText.caption(theme.textTheme.bodyMedium!)
                                        .copyWith(color: sem.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                          if (d.arabic.isNotEmpty)
                            Text(
                              d.arabic,
                              textDirection: TextDirection.rtl,
                              style: AppText.arabicDisplay(sem.primary)
                                  .copyWith(fontSize: 30),
                            ),
                          Icon(Icons.chevron_right, color: sem.muted),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 18),
              // Set progress
              Obx(() {
                if (!c.inSetMode.value) {
                  return Row(
                    children: [
                      Text('Free counting',
                          style: AppText.micro(theme.textTheme.bodyMedium!)
                              .copyWith(color: sem.muted)),
                      const Spacer(),
                      TextButton(
                        onPressed: c.startPostPrayerSet,
                        child: const Text('Start post-prayer set'),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POST-PRAYER SET · ${c.setIndex.value + 1} OF 3',
                      style: AppText.micro(theme.textTheme.bodyMedium!)
                          .copyWith(color: sem.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < kPostPrayerSet.length; i++) ...[
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: i < c.setIndex.value
                                    ? 1
                                    : i == c.setIndex.value
                                        ? c.count.value / c.target.value
                                        : 0,
                                minHeight: 7,
                                backgroundColor: sem.divider,
                                color: sem.primary,
                              ),
                            ),
                          ),
                          if (i < kPostPrayerSet.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SubhanAllah 33 · Alhamdulillah 33 · Allahu Akbar 34',
                      style: AppText.caption(theme.textTheme.bodyMedium!)
                          .copyWith(color: sem.muted),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 10),
              // Big count ring — the tap target
              Center(
                child: Obx(() {
                  final progress =
                      c.target.value == 0 ? 0.0 : c.count.value / c.target.value;
                  return GestureDetector(
                    onTap: c.tap,
                    child: Container(
                      width: 264,
                      height: 264,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sem.surface,
                        boxShadow: AppTheme.cardShadow(theme.brightness),
                      ),
                      child: CustomPaint(
                        painter: _TasbeehRingPainter(
                          progress: progress.clamp(0.0, 1.0),
                          isDark: theme.brightness == Brightness.dark,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${c.count.value}',
                                style: AppText.displayCount(
                                        theme.textTheme.displayLarge!)
                                    .copyWith(color: sem.ink),
                              ),
                              Text('of ${c.target.value}',
                                  style: AppText.body(theme.textTheme.bodyMedium!)
                                      .copyWith(color: sem.muted)),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _showTargetPicker(context, c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sem.primarySoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('Target ${c.target.value} ▾',
                                      style: AppText.bodyStrong(
                                              theme.textTheme.bodyMedium!)
                                          .copyWith(color: sem.primary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text('Tap the circle to count',
                    style: AppText.caption(theme.textTheme.bodyMedium!)
                        .copyWith(color: sem.muted)),
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: c.undo,
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      label: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () => _confirmReset(context, c),
                      child: OutlinedButton.icon(
                        onPressed: () => Get.snackbar(
                            'Reset', 'Press and hold to reset the count.',
                            snackPosition: SnackPosition.BOTTOM),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('Reset (hold)'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Footer stats
              Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(value: '${c.todayTotal}', label: 'Today'),
                      _Stat(
                          value: '${c.streak} days',
                          label: 'Streak',
                          gold: true),
                      _Stat(
                          value: c.lifetime
                              .toString()
                              .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                          label: 'Lifetime'),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, TasbeehController c) {
    Get.dialog(
      AlertDialog(
        title: const Text('Reset count?'),
        content: const Text(
            'This will undo the taps counted in the current session and remove them from today\'s history.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              c.resetCount();
              Get.back();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showTargetPicker(BuildContext context, TasbeehController c) {
    const targets = [33, 99, 100, 500, 1000];
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose target',
                style: AppText.h2(Theme.of(context).textTheme.titleLarge!)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in targets)
                  ChoiceChip(
                    label: Text('$t'),
                    selected: c.target.value == t,
                    onSelected: (_) {
                      c.setTarget(t);
                      Get.back();
                    },
                  ),
                ActionChip(
                  label: const Text('Custom…'),
                  onPressed: () async {
                    Get.back();
                    final v = await _customNumberDialog(context, 'Custom target');
                    if (v != null && v > 0) c.setTarget(v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, TasbeehController c) {
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Choose dhikr',
                      style: AppText.h2(Theme.of(context).textTheme.titleLarge!)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Get.back();
                    final created = await _customDhikrDialog(context);
                    if (created != null) {
                      c.addCustomDhikr(created);
                      c.selectDhikr(created.id);
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Custom'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const IconChip(Icons.auto_awesome_rounded),
                    title: const Text('Post-prayer set'),
                    subtitle: const Text('SubhanAllah 33 · Alhamdulillah 33 · Allahu Akbar 34'),
                    onTap: () {
                      c.startPostPrayerSet();
                      Get.back();
                    },
                  ),
                  const Divider(),
                  for (final d in c.catalogue)
                    ListTile(
                      title: Text(d.transliteration),
                      subtitle: Text(d.translation),
                      trailing: d.arabic.isEmpty
                          ? null
                          : Text(d.arabic,
                              textDirection: TextDirection.rtl,
                              style: AppText.arabicBody(
                                  SemanticColors.of(context).primary)),
                      selected: c.currentDhikrId.value == d.id && !c.inSetMode.value,
                      onTap: () {
                        c.selectDhikr(d.id);
                        Get.back();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<int?> _customNumberDialog(BuildContext context, String title) async {
    final ctrl = TextEditingController();
    return Get.dialog<int>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 250'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: int.tryParse(ctrl.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<CustomDhikrData?> _customDhikrDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final translationCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '100');
    return Get.dialog<CustomDhikrData>(
      AlertDialog(
        title: const Text('Custom dhikr'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Dhikr (transliteration)'),
              autofocus: true,
            ),
            TextField(
              controller: translationCtrl,
              decoration: const InputDecoration(labelText: 'Translation (optional)'),
            ),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Get.back(
                result: CustomDhikrData(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  transliteration: name,
                  translation: translationCtrl.text.trim(),
                  arabic: '',
                  target: int.tryParse(targetCtrl.text) ?? 100,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool gold;
  const _Stat({required this.value, required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return Column(
      children: [
        Text(value,
            style: AppText.h2(theme.textTheme.titleLarge!)
                .copyWith(color: gold ? AppColors.gold : sem.ink)),
        Text(label,
            style: AppText.caption(theme.textTheme.bodyMedium!)
                .copyWith(color: sem.muted)),
      ],
    );
  }
}

/// Thick progress ring, green arc with a gold tip dot (DESIGN_SPEC).
class _TasbeehRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  const _TasbeehRingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final track = Paint()
      ..color = (isDark ? AppColors.primarySoftDark : AppColors.primarySoftLight)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: isDark
              ? const [AppColors.primaryDarkMode, Color(0xFF7CE8A8)]
              : const [AppColors.primaryLight, Color(0xFF2FA84F)],
        ).createShader(rect);
      const start = -math.pi / 2;
      final sweep = 2 * math.pi * progress;
      canvas.drawArc(rect, start, sweep, false, arc);
      final end = start + sweep;
      final tip = Offset(
          center.dx + radius * math.cos(end), center.dy + radius * math.sin(end));
      canvas.drawCircle(tip, 7, Paint()..color = AppColors.gold);
      canvas.drawCircle(
          tip,
          7,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _TasbeehRingPainter old) =>
      old.progress != progress || old.isDark != isDark;
}
