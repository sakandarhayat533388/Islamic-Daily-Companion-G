import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../home/home_screen.dart';
import '../prayer_times/prayer_times_screen.dart';
import '../qibla/qibla_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';

class ShellController extends GetxController {
  final index = 0.obs;
  void goTo(int i) => index.value = i;
}

/// Main shell: 4 tabs — Home | Prayer Times | Qibla | Tasbeeh.
/// Active tab carries the filled primarySoft pill behind its icon (spec).
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShellController());
    final theme = Theme.of(context);
    final sem = SemanticColors.of(context);
    final pages = const [
      HomeScreen(),
      PrayerTimesScreen(),
      QiblaScreen(),
      TasbeehScreen(),
    ];
    const tabs = [
      (Icons.home_rounded, 'Home'),
      (Icons.schedule_rounded, 'Prayer Times'),
      (Icons.explore_rounded, 'Qibla'),
      (Icons.toll_rounded, 'Tasbeeh'),
    ];
    return Obx(() {
      final current = controller.index.value;
      return Scaffold(
        body: IndexedStack(index: current, children: pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: sem.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, -4),
                blurRadius: 16,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (int i = 0; i < tabs.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => controller.goTo(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 4),
                              decoration: BoxDecoration(
                                color: current == i
                                    ? sem.primarySoft
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                tabs[i].$1,
                                size: 24,
                                color: current == i ? sem.primary : sem.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tabs[i].$2,
                              style: AppText.caption(theme.textTheme.bodyMedium!)
                                  .copyWith(
                                color: current == i ? sem.primary : sem.muted,
                                fontWeight: current == i
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
