import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'hunt_show_filter.dart';

class HuntRun {
  const HuntRun({
    required this.seed,
    required this.order,
    required this.category,
    required this.period,
    required this.show,
    required this.index,
  });

  final String seed;
  final String order;
  final String category;
  final String period;
  final String show;
  final int index;

  HuntRun copyWith({int? index}) {
    return HuntRun(
      seed: seed,
      order: order,
      category: category,
      period: period,
      show: show,
      index: index ?? this.index,
    );
  }
}

class HuntStorage {
  static const _tutorialSeenKey = 'hunt.tutorialSeen';
  static const _categoryKey = 'hunt.category';
  static const _orderKey = 'hunt.order';
  static const _periodKey = 'hunt.period';
  /// Bumped when show-filter defaults / shape changed (voted-only checkbox).
  static const _showKey = 'hunt.show.v5';
  static const _runSeedKey = 'hunt.run.seed';
  static const _runOrderKey = 'hunt.run.order';
  static const _runCategoryKey = 'hunt.run.category';
  static const _runPeriodKey = 'hunt.run.period';
  static const _runShowKey = 'hunt.run.show';
  static const _runIndexKey = 'hunt.run.index';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<bool> readTutorialSeen() async {
    return (await _preferences).getBool(_tutorialSeenKey) ?? false;
  }

  Future<void> writeTutorialSeen(bool seen) async {
    await (await _preferences).setBool(_tutorialSeenKey, seen);
  }

  Future<String?> readCategory() async {
    return (await _preferences).getString(_categoryKey);
  }

  Future<void> writeCategory(String category) async {
    await (await _preferences).setString(_categoryKey, category);
  }

  Future<String?> readOrder() async {
    return (await _preferences).getString(_orderKey);
  }

  Future<void> writeOrder(String order) async {
    await (await _preferences).setString(_orderKey, order);
  }

  Future<String?> readPeriod() async {
    return (await _preferences).getString(_periodKey);
  }

  Future<void> writePeriod(String period) async {
    await (await _preferences).setString(_periodKey, period);
  }

  Future<String> readShow() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_showKey);
    final show = normalizeHuntShowFilter(raw);
    // Persist migration so legacy saved-related values don't stick.
    if (raw != show) {
      await prefs.setString(_showKey, show);
    }
    return show;
  }

  Future<void> writeShow(String show) async {
    await (await _preferences).setString(
      _showKey,
      normalizeHuntShowFilter(show),
    );
  }

  Future<void> writePreferences({
    required String category,
    required String order,
    required String period,
    required String show,
  }) async {
    final preferences = await _preferences;
    await Future.wait([
      preferences.setString(_categoryKey, category),
      preferences.setString(_orderKey, order),
      preferences.setString(_periodKey, period),
      preferences.setString(_showKey, normalizeHuntShowFilter(show)),
    ]);
  }

  Future<HuntRun?> readHuntRun() async {
    final preferences = await _preferences;
    final seed = preferences.getString(_runSeedKey);
    final order = preferences.getString(_runOrderKey);
    final category = preferences.getString(_runCategoryKey);
    final period = preferences.getString(_runPeriodKey);
    final showRaw = preferences.getString(_runShowKey);
    final index = preferences.getInt(_runIndexKey);
    if (seed == null ||
        order == null ||
        category == null ||
        period == null ||
        index == null) {
      return null;
    }
    final show = normalizeHuntShowFilter(showRaw);
    return HuntRun(
      seed: seed,
      order: order,
      category: category,
      period: period,
      show: show,
      index: index,
    );
  }

  Future<void> writeHuntRun(HuntRun run) async {
    final preferences = await _preferences;
    await Future.wait([
      preferences.setString(_runSeedKey, run.seed),
      preferences.setString(_runOrderKey, run.order),
      preferences.setString(_runCategoryKey, run.category),
      preferences.setString(_runPeriodKey, run.period),
      preferences.setString(_runShowKey, normalizeHuntShowFilter(run.show)),
      preferences.setInt(_runIndexKey, run.index),
    ]);
  }

  Future<void> clearHuntRun() async {
    final preferences = await _preferences;
    await Future.wait([
      preferences.remove(_runSeedKey),
      preferences.remove(_runOrderKey),
      preferences.remove(_runCategoryKey),
      preferences.remove(_runPeriodKey),
      preferences.remove(_runShowKey),
      preferences.remove(_runIndexKey),
    ]);
  }
}

String createHuntSeed() {
  final random = Random.secure();
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final entropy = List.generate(
    12,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
  return '$timestamp$entropy';
}
