import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_screen.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_show_filter.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _HuntApi extends ApiClient {
  final viewed = <String>{};
  final voted = <String>{'pattern-0'};
  final queries = <Map<String, dynamic>>[];
  final viewCalls = <String>[];
  bool failViews = false;
  final viewBatches = <List<String>>[];

  @override
  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async {
    if (path != '/hunt') return map(null);
    queries.add(Map.of(query!));
    final offset = query['offset'] as int;
    final eligible = [
      for (var i = offset; i < 4; i++)
        if (!voted.contains('pattern-$i') &&
            (query['show'] == 'all' || !viewed.contains('pattern-$i')))
          i,
    ];
    final page = eligible.take(2).toList();
    return map({
      'patterns': [
        for (final i in page)
          {
            'id': 'pattern-$i',
            'title': 'Pattern $i',
            'slug': 'pattern-$i',
            'designerName': 'Designer',
            'imageUrls': <String>[],
            'isFree': true,
            'hasPdf': false,
            'voteCount': 0,
            'voted': false,
            'createdAt': '2026-10-09',
          },
      ],
      'hasMore': eligible.length > 2,
      'nextOffset': eligible.length > 2 ? page.last + 1 : null,
    });
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    String? accessToken,
  }) async {
    if (path == '/hunt/view') {
      if (failViews) throw Exception('offline');
      final ids = (data['patternIds'] as List).cast<String>();
      viewBatches.add(ids);
      viewed.addAll(ids);
      viewCalls.addAll(ids);
    }
    if (path.endsWith('/vote')) {
      final id = path.split('/')[2];
      voted.add(id);
      return {'voted': true, 'voteCount': 1};
    }
    if (path == '/me/pattern-state') {
      return {
        for (final id in data['patternIds'])
          id: {'voted': voted.contains(id), 'saved': false},
      };
    }
    return {};
  }
}

final _session = Session(
  accessToken: 'test',
  tokenType: 'bearer',
  user: User(
    id: 'me',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-09',
  ),
);

Future<void> _mount(WidgetTester tester, _HuntApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(512, 900);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(_session),
        profileProvider.overrideWith((ref) async => null),
        apiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: Scaffold(body: HuntScreen())),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _swipe(WidgetTester tester, Offset movement) async {
  final pan = find
      .byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.onPanStart != null,
      )
      .first;
  final gesture = await tester.startGesture(tester.getCenter(pan));
  await gesture.moveBy(movement * 0.1);
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.moveBy(movement);
  await tester.pump(const Duration(milliseconds: 150));
  await gesture.up();
  // Upvote animations have several successive stages.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConstants.load);
  setUp(
    () => SharedPreferences.setMockInitialValues({'hunt.tutorialSeen': true}),
  );

  test(
    'new checkbox defaults unchecked even when the old checkbox was checked',
    () async {
      SharedPreferences.setMockInitialValues({'hunt.show.v5': 'all'});
      expect(await HuntStorage().readShow(), 'unviewed');
      expect(huntShowIncludesViewed(kDefaultHuntShowFilter), isFalse);
      expect(normalizeHuntShowFilter('unvoted'), 'unviewed');
    },
  );

  testWidgets(
    'records visible cards, completes across pages, and replays viewed cards when checked',
    (tester) async {
      addTearDown(tester.view.reset);
      final api = _HuntApi();
      await _mount(tester, api);
      expect(api.viewed, isEmpty); // Small batches are kept locally.
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'hunt.pendingViews.v1:me',
        ),
        ['pattern-1'],
      );
      await _swipe(tester, const Offset(-220, 0));
      expect(api.viewed, isEmpty);
      await _swipe(tester, const Offset(-220, 0));
      expect(api.queries.last['offset'], 3); // Follow the server cursor.
      expect(api.viewed, {'pattern-1', 'pattern-2'});
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'hunt.pendingViews.v1:me',
        ),
        ['pattern-3'],
      );
      await _swipe(tester, const Offset(-220, 0));
      expect(find.text('Hunt complete'), findsOneWidget);
      expect(
        find.text('You’ve hunted through 3 patterns in this run'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, api);
      expect(find.text('Nothing to hunt here'), findsOneWidget);
      await tester.tap(find.text('Change filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show already viewed patterns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(api.queries.last['show'], 'all');
      expect(find.text('Pattern 1'), findsOneWidget);
      expect(find.text('Pattern 0'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, api);
      expect(api.queries.last['show'], 'all');
      expect(api.queries.last['offset'], 0);
      expect(find.text('Pattern 1'), findsOneWidget);
      expect(find.text('Pattern 0'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'upvoted cards can be revisited in the current hunt but are excluded on re-entry',
    (tester) async {
      addTearDown(tester.view.reset);
      final api = _HuntApi();
      await _mount(tester, api);
      await _swipe(tester, const Offset(0, -200));
      expect(api.voted, contains('pattern-1'));
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'hunt.pendingViews.v1:me',
        ),
        ['pattern-1', 'pattern-2'],
      );

      Finder frontCard(String id) => find.ancestor(
        of: find
            .byWidgetPredicate(
              (widget) =>
                  widget is GestureDetector && widget.onPanStart != null,
            )
            .first,
        matching: find.byKey(ValueKey(id)),
      );
      expect(frontCard('pattern-2'), findsOneWidget);
      await _swipe(tester, const Offset(220, 0));
      expect(frontCard('pattern-1'), findsOneWidget);
      await _swipe(tester, const Offset(-220, 0));
      expect(frontCard('pattern-2'), findsOneWidget);

      // Even with viewed cards enabled, upvoted cards are excluded from a new run.
      await HuntStorage().writeShow('all');
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, api);
      expect(api.queries.last['show'], 'all');
      expect(api.queries.last['offset'], 0);
      expect(frontCard('pattern-2'), findsOneWidget);
      expect(find.text('Pattern 1'), findsNothing);
      expect(find.text('Pattern 0'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('backgrounding flushes the current small batch', (tester) async {
    addTearDown(tester.view.reset);
    final api = _HuntApi();
    await _mount(tester, api);
    expect(api.viewBatches, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(api.viewBatches, [
      ['pattern-1'],
    ]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'unsent local views are hidden on re-entry even if sending fails',
    (tester) async {
      addTearDown(tester.view.reset);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hunt.pendingViews.v1:me', [
        'pattern-1',
        'pattern-2',
      ]);
      final api = _HuntApi()..failViews = true;
      await _mount(tester, api);
      expect(api.queries.map((query) => query['offset']), [0, 3]);
      expect(find.text('Pattern 1'), findsNothing);
      expect(find.text('Pattern 2'), findsNothing);
      expect(find.text('Pattern 3'), findsOneWidget);
      expect(api.viewed, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('tutorial and preload cards are not counted as viewed', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'hunt.tutorialSeen': false});
    final api = _HuntApi();
    await _mount(tester, api);
    expect(api.viewed, isEmpty);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(api.viewed, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'hunt.pendingViews.v1:me',
      ),
      ['pattern-1'],
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an old completed run does not restore its exhausted position', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await HuntStorage().writeShow('all');
    await HuntStorage().writeHuntRun(
      const HuntRun(
        seed: 'old',
        order: 'random',
        category: 'all',
        period: 'all',
        show: 'all',
        freeOnly: false,
        index: 99,
      ),
    );
    final api = _HuntApi()
      ..viewed.addAll(['pattern-1', 'pattern-2', 'pattern-3']);
    await _mount(tester, api);
    expect(api.queries.single['offset'], 0);
    expect(api.queries.single['seed'], isNot('old'));
    expect(find.text('Pattern 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
