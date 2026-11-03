import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/content_data.dart';

/// Tasbeeh settings (persisted separately from prayer settings).
class TasbeehPrefs {
  bool vibrationOnTap;
  bool soundAtTarget;
  bool keepScreenOn;
  TasbeehPrefs({
    this.vibrationOnTap = true,
    this.soundAtTarget = true,
    this.keepScreenOn = false,
  });
  Map<String, dynamic> toJson() => {
        'vibrationOnTap': vibrationOnTap,
        'soundAtTarget': soundAtTarget,
        'keepScreenOn': keepScreenOn,
      };
  factory TasbeehPrefs.fromJson(Map<String, dynamic> j) => TasbeehPrefs(
        vibrationOnTap: j['vibrationOnTap'] as bool? ?? true,
        soundAtTarget: j['soundAtTarget'] as bool? ?? true,
        keepScreenOn: j['keepScreenOn'] as bool? ?? false,
      );
}

class CustomDhikrData {
  final String id;
  final String transliteration;
  final String translation;
  final String arabic;
  final int target;
  const CustomDhikrData({
    required this.id,
    required this.transliteration,
    required this.translation,
    required this.arabic,
    required this.target,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'transliteration': transliteration,
        'translation': translation,
        'arabic': arabic,
        'target': target,
      };
  factory CustomDhikrData.fromJson(Map<String, dynamic> j) => CustomDhikrData(
        id: j['id'] as String,
        transliteration: j['transliteration'] as String? ?? '',
        translation: j['translation'] as String? ?? '',
        arabic: j['arabic'] as String? ?? '',
        target: (j['target'] as num?)?.toInt() ?? 33,
      );
  DhikrEntry toEntry() => DhikrEntry(
        id: id,
        arabic: arabic,
        transliteration: transliteration,
        translation: translation,
        defaultTarget: target,
      );
}

/// Tasbeeh state + persistence (plan §7 TasbeehRecord).
/// Storage layout in GetStorage:
///  - 'tasbeeh_records_v1': { 'yyyy-MM-dd': { dhikrId: count } }
///  - 'tasbeeh_custom_v1': [ CustomDhikrData json ]
///  - 'tasbeeh_prefs_v1': TasbeehPrefs json
class TasbeehController extends GetxController {
  static const _kRecords = 'tasbeeh_records_v1';
  static const _kCustom = 'tasbeeh_custom_v1';
  static const _kPrefs = 'tasbeeh_prefs_v1';
  final _box = GetStorage();

  final prefs = TasbeehPrefs().obs;
  final customDhikr = <CustomDhikrData>[].obs;
  final records = <String, Map<String, int>>{}.obs;

  /// Session state.
  final currentDhikrId = 'subhanallah'.obs;
  final count = 0.obs;
  final target = 33.obs;
  final setIndex = 0.obs; // position in post-prayer set, -1 = free mode
  final inSetMode = true.obs;

  // Lazily created on first chime: constructing AudioPlayer touches the
  // platform plugin immediately, which must not happen at controller init
  // (and breaks unit tests where the plugin is absent).
  AudioPlayer? _player;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void onInit() {
    super.onInit();
    final p = _box.read(_kPrefs);
    if (p is Map) prefs.value = TasbeehPrefs.fromJson(Map<String, dynamic>.from(p));
    final c = _box.read(_kCustom);
    if (c is List) {
      customDhikr.assignAll(c
          .map((e) => CustomDhikrData.fromJson(Map<String, dynamic>.from(e as Map))));
    }
    final r = _box.read(_kRecords);
    if (r is Map) {
      records.assignAll({
        for (final e in r.entries)
          e.key as String: {
            for (final inner in (e.value as Map).entries)
              inner.key as String: (inner.value as num).toInt(),
          },
      });
    }
    _applyWakelock();
  }

  // ----- catalogue -----
  List<DhikrEntry> get catalogue => [
        ...kBuiltinDhikr,
        ...customDhikr.map((c) => c.toEntry()),
      ];

  DhikrEntry get currentDhikr => catalogue.firstWhere(
        (d) => d.id == currentDhikrId.value,
        orElse: () => kBuiltinDhikr.first,
      );

  // ----- stats -----
  int countFor(String dateKeyStr, String dhikrId) =>
      records[dateKeyStr]?[dhikrId] ?? 0;

  int totalFor(String dateKeyStr) =>
      (records[dateKeyStr] ?? const {}).values.fold(0, (a, b) => a + b);

  int get todayTotal => totalFor(dateKey(DateTime.now()));

  int totalOn(DateTime d) => totalFor(dateKey(d));

  int get lifetime => records.values
      .expand((m) => m.values)
      .fold(0, (a, b) => a + b);

  /// Consecutive days with any count, ending today (or yesterday if today
  /// has none yet — a streak is not broken until the day ends).
  int get streak {
    var d = DateTime.now();
    if (totalOn(d) == 0) {
      d = d.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (totalOn(d) > 0) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Last 7 days totals, oldest → today.
  List<({DateTime date, int total})> get last7Days {
    final now = DateTime.now();
    return [
      for (int i = 6; i >= 0; i--)
        (
          date: DateTime(now.year, now.month, now.day - i),
          total: totalOn(DateTime(now.year, now.month, now.day - i)),
        ),
    ];
  }

  // ----- session actions -----
  void selectDhikr(String id, {int? withTarget}) {
    final entry = catalogue.firstWhere((d) => d.id == id,
        orElse: () => kBuiltinDhikr.first);
    currentDhikrId.value = entry.id;
    target.value = withTarget ?? entry.defaultTarget;
    count.value = 0;
    inSetMode.value = false;
    setIndex.value = -1;
  }

  void startPostPrayerSet() {
    inSetMode.value = true;
    setIndex.value = 0;
    final (id, t) = kPostPrayerSet[0];
    currentDhikrId.value = id;
    target.value = t;
    count.value = 0;
  }

  void setTarget(int t) => target.value = t;

  Future<void> tap() async {
    if (count.value >= target.value) return;
    count.value++;
    _record(currentDhikrId.value, 1);
    if (prefs.value.vibrationOnTap) {
      try {
        await Vibration.vibrate(duration: 18);
      } catch (_) {}
    }
    if (count.value >= target.value) {
      await _onTargetReached();
    }
  }

  Future<void> _onTargetReached() async {
    try {
      await Vibration.vibrate(duration: 160);
    } catch (_) {}
    if (prefs.value.soundAtTarget) {
      try {
        _player ??= AudioPlayer();
        // Fire-and-forget: play()'s future only completes when the platform
        // player confirms (and can stall for seconds on odd devices), so it
        // must never block the counting flow. Errors are swallowed.
        _player!.play(AssetSource('audio/beep.wav')).catchError((_) {});
      } catch (_) {}
    }
    if (inSetMode.value && setIndex.value >= 0) {
      if (setIndex.value < kPostPrayerSet.length - 1) {
        // Brief pause is handled by the UI; advance immediately here.
        setIndex.value++;
        final (id, t) = kPostPrayerSet[setIndex.value];
        currentDhikrId.value = id;
        target.value = t;
        count.value = 0;
      } else {
        inSetMode.value = false;
        setIndex.value = -1;
        // Only announce when a UI exists: Get.snackbar enqueues and its
        // overlay error surfaces asynchronously, so a try/catch cannot
        // guard it in non-UI contexts (unit tests, background).
        if (Get.context != null) {
          Get.snackbar('Set complete',
              'Post-prayer dhikr finished. Alhamdulillah.',
              snackPosition: SnackPosition.BOTTOM);
        }
      }
    }
  }

  void undo() {
    if (count.value <= 0) return;
    count.value--;
    _record(currentDhikrId.value, -1);
  }

  void resetCount() {
    if (count.value == 0) return;
    _record(currentDhikrId.value, -count.value);
    count.value = 0;
  }

  void _record(String dhikrId, int delta) {
    final key = dateKey(DateTime.now());
    final day = Map<String, int>.from(records[key] ?? const {});
    final next = (day[dhikrId] ?? 0) + delta;
    if (next <= 0) {
      day.remove(dhikrId);
    } else {
      day[dhikrId] = next;
    }
    records[key] = day;
    records.refresh();
    _box.write(_kRecords, {
      for (final e in records.entries) e.key: e.value,
    });
  }

  void addCustomDhikr(CustomDhikrData d) {
    customDhikr.add(d);
    _box.write(_kCustom, customDhikr.map((e) => e.toJson()).toList());
  }

  void updatePrefs(void Function(TasbeehPrefs p) fn) {
    fn(prefs.value);
    prefs.refresh();
    _box.write(_kPrefs, prefs.value.toJson());
    _applyWakelock();
  }

  Future<void> _applyWakelock() async {
    try {
      if (prefs.value.keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }
}
