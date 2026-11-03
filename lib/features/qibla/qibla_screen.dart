import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get/get.dart';
import 'package:vibration/vibration.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';
import '../../core/prayer_engine.dart';
import '../../widgets/common_widgets.dart';

class QiblaController extends GetxController {
  final heading = Rxn<double>(); // device heading (degrees from north)
  final accuracy = Rxn<int>(); // platform accuracy value where available
  final hasSensor = Rxn<bool>();
  StreamSubscription<CompassEvent>? _sub;
  double? _filtered;
  bool _alignedFired = false;

  double get bearing {
    final s = Get.find<SettingsService>().settings.value;
    return PrayerEngine.qiblaBearing(s.lat, s.lng);
  }

  double get distanceKm {
    final s = Get.find<SettingsService>().settings.value;
    return PrayerEngine.distanceToMakkahKm(s.lat, s.lng);
  }

  bool get aligned {
    final h = heading.value;
    if (h == null) return false;
    var diff = (bearing - h).abs() % 360;
    if (diff > 180) diff = 360 - diff;
    return diff <= 3;
  }

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  Future<void> _listen() async {
    try {
      final events = FlutterCompass.events;
      if (events == null) {
        hasSensor.value = false;
        return;
      }
      hasSensor.value = true;
      _sub = events.listen(
        (e) {
          final h = e.heading;
          if (h == null) {
            hasSensor.value = false;
            return;
          }
          // Low-pass filter (circular) to kill needle jitter.
          if (_filtered == null) {
            _filtered = h;
          } else {
            var diff = ((h - _filtered! + 540) % 360) - 180;
            _filtered = (_filtered! + diff * 0.25 + 360) % 360;
          }
          heading.value = _filtered;
          accuracy.value = e.accuracy?.round();
          if (aligned && !_alignedFired) {
            _alignedFired = true;
            Vibration.vibrate(duration: 120);
          } else if (!aligned) {
            _alignedFired = false;
          }
        },
        onError: (_) => hasSensor.value = false,
      );
    } catch (_) {
      hasSensor.value = false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

/// S04 — Qibla. Compass dial custom-painted to the design; no-sensor fallback
/// shows the bearing card + a drawn map line (plan §6, spec S04.7).
class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(QiblaController());
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final s = Get.find<SettingsService>().settings.value;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qibla', style: AppText.h1(theme.textTheme.headlineMedium!)),
              const SizedBox(height: 2),
              Text('${s.cityName}, ${s.countryName}',
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.muted)),
              const SizedBox(height: 16),
              Obx(() {
                final sensor = c.hasSensor.value;
                final isAligned = c.aligned;
                final lowAccuracy =
                    c.accuracy.value != null && c.accuracy.value! < 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status chip
                    if (sensor != false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isAligned
                              ? sem.primary
                              : (lowAccuracy ? AppColors.goldSoft : sem.primarySoft),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAligned
                                  ? Icons.check_circle
                                  : lowAccuracy
                                      ? Icons.warning_amber_rounded
                                      : Icons.check,
                              size: 16,
                              color: isAligned
                                  ? Colors.white
                                  : (lowAccuracy
                                      ? const Color(0xFF8A6D14)
                                      : sem.primary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAligned
                                  ? 'You are facing the Qibla'
                                  : lowAccuracy
                                      ? 'Sensor accuracy: Low'
                                      : 'Sensor accuracy: High',
                              style: AppText.bodyStrong(theme.textTheme.bodyMedium!)
                                  .copyWith(
                                      color: isAligned
                                          ? Colors.white
                                          : (lowAccuracy
                                              ? const Color(0xFF8A6D14)
                                              : sem.primary),
                                      fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Compass or fallback
                    Center(
                      child: sensor == false
                          ? _NoSensorFallback(bearing: c.bearing)
                          : _CompassDial(controller: c),
                    ),
                    const SizedBox(height: 20),
                    // Info card
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Qibla bearing',
                            value:
                                '${c.bearing.round()}° (${PrayerEngine.cardinal(c.bearing)})',
                          ),
                          const RowDivider(),
                          _InfoRow(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Distance to Makkah',
                            value:
                                '${c.distanceKm.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} km',
                          ),
                          const RowDivider(),
                          _InfoRow(
                            icon: Icons.grid_view_rounded,
                            label: 'Kaaba coords',
                            value: '21.4225° N, 39.8262° E',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Calibration hint
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.all_inclusive_rounded,
                              color: Color(0xFF8A6D14), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Compass drifting? Move your phone in a figure 8 to calibrate.',
                              style: AppText.body(theme.textTheme.bodyMedium!)
                                  .copyWith(color: const Color(0xFF5C4A08), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconChip(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppText.body(theme.textTheme.bodyMedium!)
                    .copyWith(color: sem.muted)),
          ),
          Text(value, style: AppText.bodyStrong(theme.textTheme.bodyMedium!)),
        ],
      ),
    );
  }
}

class _CompassDial extends StatelessWidget {
  final QiblaController controller;
  const _CompassDial({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final heading = controller.heading.value ?? 0;
      final bearing = controller.bearing;
      return Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppColors.primaryDarkMode : AppColors.primaryLight)
                  .withValues(alpha: isDark ? 0.35 : 0.15),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _DialPainter(
            heading: heading,
            bearing: bearing,
            isDark: isDark,
            aligned: controller.aligned,
          ),
        ),
      );
    });
  }
}

/// Dial per DESIGN_SPEC "Qibla is a flagship screen": gradient metal ring,
/// ticks (gold at cardinals), Kaaba cube marker fixed relative to bearing,
/// gold needle with muted counter-tail, centre readout.
class _DialPainter extends CustomPainter {
  final double heading;
  final double bearing;
  final bool isDark;
  final bool aligned;
  const _DialPainter({
    required this.heading,
    required this.bearing,
    required this.isDark,
    required this.aligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final inkColor = isDark ? AppColors.inkDark : AppColors.inkLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final primaryColor = isDark ? AppColors.primaryDarkMode : AppColors.primaryLight;

    // Face
    canvas.drawCircle(center, radius - 4, Paint()..color = surfaceColor);
    // Gradient metal ring
    final ringRect = Rect.fromCircle(center: center, radius: radius - 3);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: aligned
            ? [primaryColor, primaryColor]
            : [primaryColor, AppColors.primaryDark],
      ).createShader(ringRect);
    canvas.drawCircle(center, radius - 6, ringPaint);

    double rad(double deg) => (deg - 90) * math.pi / 180;

    // Rotating dial: ticks + cardinals rotate by -heading.
    for (int d = 0; d < 360; d += 15) {
      final isCardinal = d % 90 == 0;
      final a = rad(d - heading);
      final outer = radius - 18;
      final inner = radius - (isCardinal ? 34 : 28);
      final tickPaint = Paint()
        ..color = isCardinal ? AppColors.gold : mutedColor.withValues(alpha: 0.6)
        ..strokeWidth = isCardinal ? 3 : 2;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(a), center.dy + inner * math.sin(a)),
        Offset(center.dx + outer * math.cos(a), center.dy + outer * math.sin(a)),
        tickPaint,
      );
    }
    const letters = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final a = rad(i * 90 - heading);
      final pos = Offset(center.dx + (radius - 52) * math.cos(a),
          center.dy + (radius - 52) * math.sin(a));
      final tp = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: letters[i] == 'W' ? AppColors.gold : mutedColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Kaaba marker on the ring at the bearing (rotates with the dial).
    final ka = rad(bearing - heading);
    final kPos = Offset(center.dx + (radius - 6) * math.cos(ka),
        center.dy + (radius - 6) * math.sin(ka));
    final cubeSize = 24.0;
    final cubeRect = Rect.fromCenter(center: kPos, width: cubeSize, height: cubeSize);
    canvas.drawRRect(
        RRect.fromRectAndRadius(cubeRect, const Radius.circular(4)),
        Paint()..color = const Color(0xFF101613));
    canvas.drawRect(
        Rect.fromLTWH(cubeRect.left, cubeRect.top + 5, cubeRect.width, 4),
        Paint()..color = AppColors.gold);

    // Gold needle pointing up (device heading) with muted counter-tail.
    final needle = Path()
      ..moveTo(center.dx, center.dy - 64)
      ..lineTo(center.dx + 11, center.dy)
      ..lineTo(center.dx - 11, center.dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = AppColors.gold);
    final tail = Path()
      ..moveTo(center.dx, center.dy + 40)
      ..lineTo(center.dx + 8, center.dy)
      ..lineTo(center.dx - 8, center.dy)
      ..close();
    canvas.drawPath(tail, Paint()..color = mutedColor.withValues(alpha: 0.55));
    canvas.drawCircle(center, 5, Paint()..color = surfaceColor);
    canvas.drawCircle(
        center,
        5,
        Paint()
          ..color = mutedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Centre readout: bearing degrees + cardinal.
    final readout = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '${bearing.round()}°\n',
          style: TextStyle(
              fontSize: 40, fontWeight: FontWeight.w700, color: inkColor),
        ),
        TextSpan(
          text: 'QIBLA · ${PrayerEngine.cardinal(bearing).toUpperCase()}',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: mutedColor),
        ),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    readout.paint(
        canvas, Offset(center.dx - readout.width / 2, center.dy + 52));
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.heading != heading || old.bearing != bearing || old.aligned != aligned;
}

/// No-magnetometer fallback (spec S04.7): big bearing + drawn map line.
class _NoSensorFallback extends StatelessWidget {
  final double bearing;
  const _NoSensorFallback({required this.bearing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final s = Get.find<SettingsService>().settings.value;
    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              Eyebrow('No compass sensor on this device'),
              const SizedBox(height: 10),
              Text('Face ${bearing.round()}°',
                  style: AppText.displayCountdown(theme.textTheme.displayLarge!)
                      .copyWith(color: sem.primary, fontSize: 40)),
              Text('(${PrayerEngine.cardinal(bearing)})',
                  style: AppText.body(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.muted)),
              const SizedBox(height: 14),
              SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MapLinePainter(
                    fromLat: s.lat,
                    fromLng: s.lng,
                    bearing: bearing,
                    ink: sem.ink,
                    muted: sem.muted,
                  ),
                ),
              ),
              Text('Direction from ${s.cityName} to Makkah',
                  style: AppText.caption(theme.textTheme.bodyMedium!)
                      .copyWith(color: sem.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple equirectangular canvas map: a straight great-circle-intent line
/// from the user location to the Kaaba dot.
class _MapLinePainter extends CustomPainter {
  final double fromLat;
  final double fromLng;
  final double bearing;
  final Color ink;
  final Color muted;
  const _MapLinePainter({
    required this.fromLat,
    required this.fromLng,
    required this.bearing,
    required this.ink,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Offset proj(double lat, double lng) => Offset(
          (lng + 180) / 360 * size.width,
          (90 - lat) / 180 * size.height,
        );
    // graticule
    final grid = Paint()
      ..color = muted.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (int i = 1; i < 6; i++) {
      canvas.drawLine(Offset(size.width * i / 6, 0),
          Offset(size.width * i / 6, size.height), grid);
      canvas.drawLine(Offset(0, size.height * i / 6),
          Offset(size.width, size.height * i / 6), grid);
    }
    final from = proj(fromLat, fromLng);
    final to = proj(21.4225241, 39.8261818);
    canvas.drawLine(
        from,
        to,
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = 2.5);
    canvas.drawCircle(from, 6, Paint()..color = AppColors.primaryLight);
    // Kaaba dot
    canvas.drawRect(
        Rect.fromCenter(center: to, width: 12, height: 12),
        Paint()..color = const Color(0xFF101613));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
