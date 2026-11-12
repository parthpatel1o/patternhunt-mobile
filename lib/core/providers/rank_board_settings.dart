import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../constants/app_constants.dart';
import 'providers.dart';

final rankBoardSettingsProvider = Provider<RankBoardSettings>(
  (ref) => RankBoardSettings(ref.watch(apiClientProvider)),
);

String? parseRankBoardPeriod(Object? value) {
  return switch (value) {
    'week' => 'week',
    'month' => 'month',
    'all' => 'all',
    _ => null,
  };
}

class RankBoardSettings {
  RankBoardSettings(this._api);

  static const _cacheKey = 'rank_board_default_period';
  final ApiClient _api;
  String? _lastPeriod;
  Future<String>? _pending;

  Future<String> refreshDefaultPeriod() {
    return _pending ??= _loadDefaultPeriod().whenComplete(() {
      _pending = null;
    });
  }

  Future<String> _loadDefaultPeriod() async {
    final fallback = AppConstants.instance.defaultRankBoardPeriod;
    String? period;
    try {
      period = await _api
          .getData<String?>(
            '/rank-board/settings',
            map: (json) =>
                json is Map ? parseRankBoardPeriod(json['defaultPeriod']) : null,
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Older servers and offline launches can still load the board.
    }

    if (period != null) _lastPeriod = period;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (period != null) {
        await preferences.setString(_cacheKey, period);
      } else {
        _lastPeriod ??= parseRankBoardPeriod(preferences.getString(_cacheKey));
      }
    } catch (_) {
      // The in-memory value is still usable if device storage is unavailable.
    }
    return _lastPeriod ?? fallback;
  }
}
