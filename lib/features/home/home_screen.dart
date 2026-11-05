import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:share_plus/share_plus.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/content_data.dart';
import '../../core/models.dart';
import '../../core/prayer_controller.dart';
import '../../core/prayer_engine.dart';
import '../../widgets/common_widgets.dart';
import '../onboarding/onboarding_screens.dart' show showCityPicker;
import '../shell/main_shell.dart';
import '../tasbeeh/tasbeeh_controller.dart';

/// S02 — Home. Content ORDER is locked by DESIGN_SPEC:
/// header → date → hero countdown → today's times → daily dua → quick tiles.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prayers = Get.find<PrayerController>();
    final settingsService = Get.find<SettingsService>();
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Pull to refresh = explicit GPS re-check (plan S02).
            if (settingsService.settings.value.locationMode == 'gps') {
              final loc = Get.find<LocationService>();
              final pos = await loc.currentPosition();
              if (pos != null) {
                settingsService.updateSettings((s) {
                  s.lat = pos.latitude;
                  s.lng = pos.longitude;
                });
                prayers.recalculate();
              }
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppTheme.screenMargin, 12, AppTheme.screenMargin, 20),
            child: Obx(() {
              final s = settingsService.settings.value;
              final today = prayers.today.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header row: location left, gear right.
                  Row(
                    children: [
                      Icon(Icons.location_on, color: sem.primary, size: 22),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => showCityPicker(context, (city) {
                            final defaults =
                                defaultsForCountry(city.countryCode);
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
                          child: Text(
                            '${s.cityName}, ${s.countryName}',
                            style: AppText.title(theme.textTheme.bodyMedium!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: sem.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.settings_outlined, color: sem.primary),
                          onPressed: () => Get.toNamed('/settings'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 2. Date line: Gregorian strong, Hijri caption beneath.
                  Text(
                    intl.DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style: AppText.bodyStrong(theme.textTheme.bodyMedium!),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    today != null ? today.hijriFull : '',
                    style: AppText.caption(theme.textTheme.bodyMedium!)
                        .copyWith(color: sem.muted),
                  ),
                  const SizedBox(height: 16),
                  // 3. Hero countdown card.
                  if (today != null) _HeroCard(prayers: prayers),
                  const SizedBox(height: 20),
                  // 4. Today's times card.
                  if (today != null)
                    _TodayTimesCard(prayers: prayers, settingsService: settingsService),
                  const SizedBox(height: 20),
                  // 5. Daily dua card.
                  _DailyDuaCard(),
                  const SizedBox(height: 20),
                  // 6. Quick tiles.
                  _QuickTiles(prayers: prayers),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final PrayerController prayers;
  const _HeroCard({required this.prayers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Obx(() {
      final cn = prayers.currentNext;
      final countdown = PrayerController.fmtCountdown(prayers.countdown);
      final progress = prayers.progress;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.heroRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [AppColors.primaryDark, AppColors.surfaceDark]
                : const [AppColors.primaryLight, AppColors.primaryDark],
          ),
          boxShadow: AppTheme.cardShadow(theme.brightness),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.heroRadius),
          child: CustomPaint(
            painter: StarLatticePainter(
                color: Colors.white.withValues(alpha: 0.07)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Text block (65%)
                  Expanded(
                    flex: 65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOW · ${cn.current.label.toUpperCase()}',
                          style: AppText.micro(theme.textTheme.bodyMedium!)
                              .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        Builder(builder: (_) {
                          final t = prayers.today.value!;
                          final beforeFajr = prayers.nowTick.value
                              .isBefore(t.timeFor(PrayerId.fajr));
                          final DateTime startedAt =
                              (cn.current == PrayerId.isha && beforeFajr)
                                  ? (prayers.yesterday.value
                                          ?.timeFor(PrayerId.isha) ??
                                      t.timeFor(PrayerId.isha))
                                  : t.timeFor(cn.current);
                          return Text(
                            '${cn.current.label} started ${PrayerController.fmtTime(startedAt)}',
                            style: AppText.caption(theme.textTheme.bodyMedium!)
                                .copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.75)),
                          );
                        }),
                        const SizedBox(height: 14),
                        Text(
                          'NEXT PRAYER',
                          style: AppText.micro(theme.textTheme.bodyMedium!)
                              .copyWith(color: AppColors.gold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              cn.next.label,
                              style: AppText.h1(theme.textTheme.headlineMedium!)
                                  .copyWith(color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              PrayerController.fmtTime(cn.nextTime),
                              style: AppText.bodyStrong(theme.textTheme.bodyMedium!)
                                  .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Countdown must always stay on ONE line: at 48px the
                        // 8 digits are wider than this 65% column on phones,
                        // so scale down to fit instead of wrapping mid-time.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            countdown,
                            maxLines: 1,
                            softWrap: false,
                            style: AppText.displayCountdown(
                                    theme.textTheme.displayLarge!)
                                .copyWith(color: Colors.white),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'remaining until ${cn.next.label}',
                            maxLines: 1,
                            softWrap: false,
                            style: AppText.caption(theme.textTheme.bodyMedium!)
                                .copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.75)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress ring (35%)
                  Expanded(
                    flex: 35,
                    child: Center(
                      child: SizedBox(
                        width: 104,
                        height: 104,
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: progress,
                            isDark: isDark,
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: const Size(34, 34),
                              painter: _MiniMarkPainter(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Gold progress ring on a white-8% track with a white end-dot (spec).
class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  const _RingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      final arc = Paint()
        ..color = isDark ? AppColors.primaryDarkMode : AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      final start = -math.pi / 2;
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius), start, sweep, false, arc);
      final endAngle = start + sweep;
      final dot = Offset(
          center.dx + radius * math.cos(endAngle), center.dy + radius * math.sin(endAngle));
      canvas.drawCircle(dot, 5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

/// Small crescent glyph inside the hero ring.
class _MiniMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final big = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.46, s * 0.5), radius: s * 0.36));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.62, s * 0.38), radius: s * 0.30));
    canvas.drawPath(Path.combine(PathOperation.difference, big, cut),
        Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TodayTimesCard extends StatelessWidget {
  final PrayerController prayers;
  final SettingsService settingsService;
  const _TodayTimesCard({required this.prayers, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return Obx(() {
      final today = prayers.today.value!;
      final cn = prayers.currentNext;
      final alerts = settingsService.alerts.value;
      final s = settingsService.settings.value;
      return AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Eyebrow("Today's prayers")),
                Text('${methodLabel(s.method)} method',
                    style: AppText.caption(theme.textTheme.bodyMedium!)
                        .copyWith(color: sem.muted)),
              ],
            ),
            const SizedBox(height: 6),
            for (final p in kAllMarkers) ...[
              _PrayerRow(
                prayer: p,
                time: today.timeFor(p),
                state: p == cn.current
                    ? _RowState.current
                    : p == cn.next
                        ? _RowState.next
                        : _RowState.normal,
                bellOn: p.isPrayer &&
                    alerts.masterEnabled &&
                    alerts.forPrayer(p).mode != AlertMode.off,
                onBellTap: p.isPrayer
                    ? () {
                        settingsService.updateAlerts((a) {
                          final cur = a.forPrayer(p);
                          cur.mode = cur.mode == AlertMode.off
                              ? AlertMode.adhan
                              : AlertMode.off;
                          if (!a.masterEnabled) a.masterEnabled = true;
                        });
                        prayers.recalculate();
                      }
                    : null,
              ),
              if (p != PrayerId.isha)
                Divider(height: 1, color: sem.divider.withValues(alpha: 0.6)),
            ],
          ],
        ),
      );
    });
  }
}

enum _RowState { current, next, normal }

class _PrayerRow extends StatelessWidget {
  final PrayerId prayer;
  final DateTime time;
  final _RowState state;
  final bool bellOn;
  final VoidCallback? onBellTap;
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.state,
    required this.bellOn,
    this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final isCurrent = state == _RowState.current;
    final isNext = state == _RowState.next;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? sem.primarySoft
            : isNext
                ? AppColors.goldSoft.withValues(alpha: 0.55)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              prayer.label,
              style: AppText.title(theme.textTheme.bodyMedium!).copyWith(
                color: (isCurrent || isNext) ? sem.primary : sem.ink,
                fontWeight: (isCurrent || isNext) ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (isCurrent)
            Expanded(
              flex: 3,
              child: Text('• now',
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.primary, fontWeight: FontWeight.w600)),
            )
          else
            const Expanded(flex: 3, child: SizedBox()),
          Text(
            PrayerController.fmtTime(time),
            style: AppText.bodyStrong(theme.textTheme.bodyMedium!).copyWith(
              color: (isCurrent || isNext) ? sem.primary : sem.ink,
              fontSize: 16,
            ),
          ),
          SizedBox(
            width: 44,
            child: prayer.isPrayer
                ? IconButton(
                    icon: Icon(
                      bellOn ? Icons.notifications_active : Icons.notifications_none,
                      color: bellOn ? sem.primary : sem.muted,
                      size: 22,
                    ),
                    onPressed: onBellTap,
                  )
                : const Center(child: Text('—', style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }
}

class _DailyDuaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final dua = duaForDay(DateTime.now());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('Daily dua', color: AppColors.gold)),
              IconButton(
                icon: Icon(Icons.share_outlined, color: sem.muted, size: 20),
                onPressed: () => Share.share('${dua.arabic}\n\n${dua.translation}'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              dua.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppText.arabicBody(sem.ink),
            ),
          ),
          const SizedBox(height: 8),
          Text(dua.translation,
              style: AppText.body(theme.textTheme.bodyMedium!)
                  .copyWith(color: sem.muted, height: 1.4)),
          const SizedBox(height: 4),
          Text(dua.source,
              style: AppText.caption(theme.textTheme.bodyMedium!)
                  .copyWith(color: sem.muted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _QuickTiles extends StatelessWidget {
  final PrayerController prayers;
  const _QuickTiles({required this.prayers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final s = Get.find<SettingsService>().settings.value;
    final bearing = PrayerEngine.qiblaBearing(s.lat, s.lng);
    final tasbeeh = Get.find<TasbeehController>();
    Widget tile(IconData icon, String label, String value, VoidCallback onTap,
        {bool gold = false}) {
      return Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          onTap: onTap,
          child: Column(
            children: [
              IconChip(icon, gold: gold),
              const SizedBox(height: 8),
              Text(label,
                  style: AppText.bodyStrong(theme.textTheme.bodyMedium!)),
              Text(value,
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.muted),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(Icons.explore_rounded, 'Qibla', '${bearing.round()}° ${PrayerEngine.cardinal(bearing)[0]}',
            () => Get.find<ShellController>().goTo(2)),
        const SizedBox(width: 12),
        Obx(() => tile(Icons.toll_rounded, 'Tasbeeh', '${tasbeeh.todayTotal} today',
            () => Get.find<ShellController>().goTo(3),
            gold: true)),
        const SizedBox(width: 12),
        tile(
            Icons.calendar_month_rounded,
            'This Month',
            intl.DateFormat('MMM yyyy').format(DateTime.now()),
            () => Get.find<ShellController>().goTo(1)),
      ],
    );
  }
}
