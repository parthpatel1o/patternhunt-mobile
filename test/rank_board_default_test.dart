import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RankBoardApi extends Fake implements ApiClient {
  String? defaultPeriod = 'month';
  int settingsReads = 0;
  final periods = <String>[];

  @override
  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async {
    if (path == '/rank-board/settings') {
      settingsReads++;
      if (defaultPeriod == null) throw ApiException('Settings unavailable');
      return map({'defaultPeriod': defaultPeriod});
    }

    expect(path, '/patterns');
    periods.add(query!['period'] as String);
    return map({
      'patterns': [],
      'hasMore': false,
      'nextOffset': null,
    });
  }
}

Future<void> _openBoard(
  WidgetTester tester,
  _RankBoardApi api, {
  String? initialPeriod,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        home: Scaffold(body: HomeScreen(initialPeriod: initialPeriod)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _refreshBoard(WidgetTester tester) async {
  final refresh = tester
      .widget<RefreshIndicator>(find.byType(RefreshIndicator))
      .onRefresh();
  await tester.pumpAndSettle();
  await refresh;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConstants.load);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('uses the shared default and checks it on refresh', (tester) async {
    final api = _RankBoardApi();
    await _openBoard(tester, api);
    expect(api.periods, ['month']);

    api.defaultPeriod = 'all';
    await _refreshBoard(tester);
    expect(api.settingsReads, 2);
    expect(api.periods.last, 'all');
  });

  testWidgets('keeps a manually selected period on refresh', (tester) async {
    final api = _RankBoardApi();
    await _openBoard(tester, api);

    await tester.tap(find.text('Past 7 days'));
    await tester.pumpAndSettle();
    expect(api.periods.last, 'week');

    api.defaultPeriod = 'all';
    await _refreshBoard(tester);
    expect(api.settingsReads, 1);
    expect(api.periods.last, 'week');
  });

  testWidgets('keeps an explicit All time link on refresh', (tester) async {
    final api = _RankBoardApi();
    await _openBoard(tester, api, initialPeriod: 'all');
    await _refreshBoard(tester);
    expect(api.settingsReads, 0);
    expect(api.periods, everyElement('all'));
    expect(api.periods, isNotEmpty);
  });

  testWidgets('uses the last known default when the setting is unavailable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'rankBoard.defaultPeriod': 'month'});
    final api = _RankBoardApi()..defaultPeriod = null;
    await _openBoard(tester, api);
    expect(api.periods, ['month']);
  });
}
