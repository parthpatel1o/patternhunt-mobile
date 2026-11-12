import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/core/providers/rank_board_settings.dart';
import 'package:patternhunt_mobile/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RankBoardApi extends ApiClient {
  Object? defaultPeriod = 'month';
  int settingsReads = 0;
  final boardQueries = <Map<String, dynamic>>[];

  @override
  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async {
    switch (path) {
      case '/rank-board/settings':
        settingsReads++;
        if (defaultPeriod == null) throw ApiException('Unavailable');
        return map({'defaultPeriod': defaultPeriod});
      case '/patterns':
        boardQueries.add(query!);
        return map({'patterns': [], 'hasMore': false});
      default:
        throw StateError('Unexpected request: $path');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConstants.load);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'uses the last valid default across launches when the server fails',
    () async {
      final api = _RankBoardApi()..defaultPeriod = null;
      expect(await RankBoardSettings(api).refreshDefaultPeriod(), 'week');
      api.defaultPeriod = 'all';
      expect(await RankBoardSettings(api).refreshDefaultPeriod(), 'all');
      api.defaultPeriod = null;
      expect(await RankBoardSettings(api).refreshDefaultPeriod(), 'all');
      api.defaultPeriod = 'invalid';
      expect(await RankBoardSettings(api).refreshDefaultPeriod(), 'all');
    },
  );

  testWidgets('follows the default on open, return, resume and refresh', (
    tester,
  ) async {
    final api = _RankBoardApi();
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/other', builder: (_, _) => const Text('Other')),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.boardQueries.single['period'], 'month');

    router.go('/other');
    await tester.pumpAndSettle();
    api.defaultPeriod = 'all';
    router.go('/');
    await tester.pumpAndSettle();
    expect(api.boardQueries.last['period'], 'all');

    api.defaultPeriod = 'week';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.boardQueries.last['period'], 'week');

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    api.defaultPeriod = 'month';
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(api.boardQueries.last['period'], 'month');

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('All time')).style?.fontWeight,
      FontWeight.w800,
    );

    final settingsReads = api.settingsReads;
    api.defaultPeriod = 'week';
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(api.boardQueries.last['period'], 'all');
    expect(api.settingsReads, settingsReads);
  });

  testWidgets(
    'uses an explicit period on a focused board without fetching the default',
    (tester) async {
      final api = _RankBoardApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            sessionProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeScreen(initialPeriod: 'all', focusPatternId: 'pattern'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.settingsReads, 0);
      expect(api.boardQueries.first['period'], 'all');
      expect(api.boardQueries.first['pattern'], 'pattern');
    },
  );
}
