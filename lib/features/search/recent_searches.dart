import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed recent search terms (web `recentSearches` parity).
class RecentSearches {
  RecentSearches._();

  static const prefsKey = 'search_recents_v1';
  static const maxItems = 8;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.unmodifiable(prefs.getStringList(prefsKey) ?? const []);
  }

  /// Remember a committed search (submit / see-all / result / recent tap).
  static Future<List<String>> remember(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(prefsKey) ?? <String>[];
    current.removeWhere((e) => e.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    final next = current.take(maxItems).toList();
    await prefs.setStringList(prefsKey, next);
    return List<String>.unmodifiable(next);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
