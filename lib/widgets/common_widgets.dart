import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Surface card with the design's soft shadow + divider border (radius 20).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.cardRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: sem.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: sem.divider),
        boxShadow: AppTheme.cardShadow(Theme.of(context).brightness),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Eyebrow group label used by Settings groups and card headers.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Text(
      text.toUpperCase(),
      style: AppText.micro(Theme.of(context).textTheme.bodyMedium!)
          .copyWith(color: color ?? sem.muted),
    );
  }
}

/// Tinted 40px icon chip that leads settings/list rows (DESIGN_SPEC).
class IconChip extends StatelessWidget {
  final IconData icon;
  final bool gold;
  const IconChip(this.icon, {super.key, this.gold = false});

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: gold ? AppColors.goldSoft : sem.primarySoft,
        borderRadius: BorderRadius.circular(AppTheme.chipRadius),
      ),
      child: Icon(icon,
          size: 20, color: gold ? const Color(0xFF8A6D14) : sem.primary),
    );
  }
}

/// Settings-style row: icon chip + title (+optional subtitle) + trailing.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool goldChip;
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.goldChip = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            IconChip(icon, gold: goldChip),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.title(theme.textTheme.bodyMedium!)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppText.caption(theme.textTheme.bodyMedium!)
                            .copyWith(color: sem.muted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class RowDivider extends StatelessWidget {
  const RowDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 68, right: 16),
      child: Divider(height: 1, thickness: 1, color: sem.divider),
    );
  }
}

/// Page dots for onboarding (gold/primary active).
class PageDots extends StatelessWidget {
  final int index;
  final int count;
  final bool onGreen;
  const PageDots({super.key, required this.index, this.count = 3, this.onGreen = false});

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index
                  ? (onGreen ? AppColors.gold : sem.primary)
                  : (onGreen ? Colors.white24 : sem.divider),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Gradient + star-lattice scaffold background for Splash/Onboarding.
class GreenGradientBody extends StatelessWidget {
  final Widget child;
  const GreenGradientBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark, AppColors.gradientFoot],
          stops: [0, 0.55, 1],
        ),
      ),
      child: CustomPaint(
        painter: StarLatticePainter(color: Colors.white.withValues(alpha: 0.07)),
        child: child,
      ),
    );
  }
}
