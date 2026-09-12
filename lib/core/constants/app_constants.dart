import 'dart:convert';

import 'package:flutter/services.dart';

/// Default saved-patterns folder. Matches web `DEFAULT_BOARD_NAME`.
const kDefaultBoardName = 'All';

class CategoryOption {
  const CategoryOption({required this.slug, required this.name});

  final String slug;
  final String name;
}

class RankPeriodOption {
  const RankPeriodOption({required this.value, required this.label});

  final String value;
  final String label;
}

class HuntOrderOption {
  const HuntOrderOption({required this.value, required this.label});

  final String value;
  final String label;
}

class AppConstants {
  AppConstants._({
    required this.categories,
    required this.rankPeriods,
    required this.huntOrders,
    required this.defaultHuntOrder,
    required this.defaultHuntCategory,
    required this.defaultRankBoardCategory,
    required this.defaultUserCategory,
    required this.maxPatternImages,
    required this.scoreboardPageSize,
    required this.huntPageSize,
    required this.imageOutputSize,
    required this.maxPdfBytes,
  });

  final List<CategoryOption> categories;
  final List<RankPeriodOption> rankPeriods;
  final List<HuntOrderOption> huntOrders;
  final String defaultHuntOrder;
  final String defaultHuntCategory;
  final String defaultRankBoardCategory;
  final String defaultUserCategory;
  final int maxPatternImages;
  final int scoreboardPageSize;
  final int huntPageSize;
  final int imageOutputSize;
  final int maxPdfBytes;

  static AppConstants? _instance;

  static AppConstants get instance {
    final value = _instance;
    if (value == null)
      throw StateError('AppConstants.load() must be called before use');
    return value;
  }

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/constants.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _instance = AppConstants._(
      categories: (json['categories'] as List<dynamic>)
          .map(
            (e) => CategoryOption(
              slug: e['slug'] as String,
              name: e['name'] as String,
            ),
          )
          .toList(),
      rankPeriods: (json['rankPeriods'] as List<dynamic>)
          .map(
            (e) => RankPeriodOption(
              value: e['value'] as String,
              label: e['label'] as String,
            ),
          )
          .toList(),
      huntOrders: (json['huntOrders'] as List<dynamic>? ?? const [])
          .map(
            (e) => HuntOrderOption(
              value: e['value'] as String,
              label: e['label'] as String,
            ),
          )
          .toList(),
      defaultHuntOrder: json['defaultHuntOrder'] as String? ?? 'random',
      defaultHuntCategory: json['defaultHuntCategory'] as String? ?? 'all',
      defaultRankBoardCategory: json['defaultRankBoardCategory'] as String,
      defaultUserCategory: json['defaultUserCategory'] as String,
      maxPatternImages: json['maxPatternImages'] as int,
      scoreboardPageSize: json['scoreboardPageSize'] as int? ?? 20,
      huntPageSize: json['huntPageSize'] as int? ?? 20,
      imageOutputSize: json['imageOutputSize'] as int,
      maxPdfBytes: json['maxPdfBytes'] as int,
    );
  }
}
