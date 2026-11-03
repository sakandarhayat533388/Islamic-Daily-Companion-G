import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — copied 1:1 from design-tokens.md (single source of truth).
class AppColors {
  // Light
  static const bgLight = Color(0xFFF7F5EF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const primaryLight = Color(0xFF0B6B3A);
  static const inkLight = Color(0xFF14201A);
  static const mutedLight = Color(0xFF5F6F66);
  static const dividerLight = Color(0xFFE4E1D8);
  static const primarySoftLight = Color(0xFFE3F0E7);

  // Dark
  static const bgDark = Color(0xFF0C1210);
  static const surfaceDark = Color(0xFF161E1A);
  static const primaryDarkMode = Color(0xFF35C26E);
  static const inkDark = Color(0xFFEDF3EE);
  static const mutedDark = Color(0xFF9DB0A4);
  static const dividerDark = Color(0xFF26322B);
  static const primarySoftDark = Color(0xFF1D2E24);

  // Shared
  static const primaryDark = Color(0xFF084F2B); // hero gradient end (both modes)
  static const gradientFoot = Color(0xFF063D20); // onboarding gradient foot
  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFFBF3D9); // warningSoft in tokens
  static const error = Color(0xFFB3261E);
}

/// Semantic colors resolved per brightness so widgets never hard-code hexes.
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color bg;
  final Color surface;
  final Color primary;
  final Color primarySoft;
  final Color ink;
  final Color muted;
  final Color divider;
  const SemanticColors({
    required this.bg,
    required this.surface,
    required this.primary,
    required this.primarySoft,
    required this.ink,
    required this.muted,
    required this.divider,
  });

  static SemanticColors of(BuildContext context) =>
      Theme.of(context).extension<SemanticColors>()!;

  @override
  SemanticColors copyWith({
    Color? bg,
    Color? surface,
    Color? primary,
    Color? primarySoft,
    Color? ink,
    Color? muted,
    Color? divider,
  }) =>
      SemanticColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        primary: primary ?? this.primary,
        primarySoft: primarySoft ?? this.primarySoft,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        divider: divider ?? this.divider,
      );

  @override
  SemanticColors lerp(SemanticColors? other, double t) => this;
}

/// Type scale from design-tokens.md. Arabic uses Amiri (Google Fonts).
class AppText {
  static TextStyle displayCountdown(TextStyle base) =>
      base.copyWith(fontSize: 48, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle displayCount(TextStyle base) =>
      base.copyWith(fontSize: 96, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle h1(TextStyle base) => base.copyWith(fontSize: 28, fontWeight: FontWeight.w700);
  static TextStyle h2(TextStyle base) => base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
  static TextStyle title(TextStyle base) => base.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
  static TextStyle body(TextStyle base) => base.copyWith(fontSize: 15, fontWeight: FontWeight.w400);
  static TextStyle bodyStrong(TextStyle base) => base.copyWith(
      fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle caption(TextStyle base) => base.copyWith(fontSize: 13, fontWeight: FontWeight.w400);
  static TextStyle micro(TextStyle base) =>
      base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6);
  static TextStyle arabicDisplay(Color color) =>
      GoogleFonts.amiri(fontSize: 40, fontWeight: FontWeight.w400, color: color, height: 1.6);
  static TextStyle arabicBody(Color color) =>
      GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.w400, color: color, height: 1.8);
}

class AppTheme {
  static const double screenMargin = 20;
  static const double cardRadius = 20;
  static const double heroRadius = 24;
  static const double buttonRadius = 14;
  static const double chipRadius = 13;

  static List<BoxShadow> cardShadow(Brightness b) => [
        BoxShadow(
          color: const Color(0xFF0A1F13).withValues(alpha: b == Brightness.dark ? 0.45 : 0.16),
          offset: const Offset(0, 8),
          blurRadius: 14,
        ),
      ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final sem = isDark
        ? const SemanticColors(
            bg: AppColors.bgDark,
            surface: AppColors.surfaceDark,
            primary: AppColors.primaryDarkMode,
            primarySoft: AppColors.primarySoftDark,
            ink: AppColors.inkDark,
            muted: AppColors.mutedDark,
            divider: AppColors.dividerDark,
          )
        : const SemanticColors(
            bg: AppColors.bgLight,
            surface: AppColors.surfaceLight,
            primary: AppColors.primaryLight,
            primarySoft: AppColors.primarySoftLight,
            ink: AppColors.inkLight,
            muted: AppColors.mutedLight,
            divider: AppColors.dividerLight,
          );
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: sem.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryLight,
        brightness: brightness,
        primary: sem.primary,
        surface: sem.surface,
        error: AppColors.error,
      ),
      extensions: [sem],
      dividerColor: sem.divider,
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: sem.ink,
      displayColor: sem.ink,
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: sem.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: sem.ink,
        titleTextStyle: AppText.h2(textTheme.titleLarge!),
      ),
      cardTheme: CardThemeData(
        color: sem.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: sem.divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sem.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: AppText.bodyStrong(textTheme.bodyMedium!),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sem.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: sem.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: AppText.bodyStrong(textTheme.bodyMedium!),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? sem.primary : sem.muted.withValues(alpha: 0.35)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

/// Subtle 8-point-star Islamic lattice painter (DESIGN_SPEC "Visual elevation").
/// Draws overlapping squares (rotated 45°) on a grid at very low opacity.
class StarLatticePainter extends CustomPainter {
  final Color color;
  final double cell;
  const StarLatticePainter({required this.color, this.cell = 56});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = cell * 0.30;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + ((y / cell).round().isOdd ? cell / 2 : 0), y);
        canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: r * 2), paint);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.7853981633974483);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarLatticePainter old) => old.color != color || old.cell != cell;
}

/// Crescent + Kaaba emblem used on Splash / Onboarding (gold crescent, dark cube, gold band).
class CrescentKaabaMark extends StatelessWidget {
  final double size;
  const CrescentKaabaMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final gold = Paint()..color = AppColors.gold;
    // Crescent: big gold circle minus offset dark circle (drawn in bg-agnostic way
    // using a gold ring instead so it works on any background).
    final crescentPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.48, s * 0.48), radius: s * 0.36));
    final cutPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.63, s * 0.38), radius: s * 0.30));
    final crescent = Path.combine(PathOperation.difference, crescentPath, cutPath);
    canvas.drawPath(crescent, gold);
    // Star
    final star = Paint()..color = AppColors.gold;
    canvas.drawCircle(Offset(s * 0.70, s * 0.30), s * 0.045, star);
    // Kaaba cube at crescent base
    final cubeRect = Rect.fromCenter(center: Offset(s * 0.44, s * 0.66), width: s * 0.30, height: s * 0.26);
    final cube = Paint()..color = const Color(0xFF101613);
    canvas.drawRRect(RRect.fromRectAndRadius(cubeRect, Radius.circular(s * 0.03)), cube);
    final band = Paint()..color = AppColors.gold;
    canvas.drawRect(Rect.fromLTWH(cubeRect.left, cubeRect.top + s * 0.055, cubeRect.width, s * 0.045), band);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
