import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/search/recent_searches.dart';
import 'package:patternhunt_mobile/features/search/search_overlay.dart';
import 'package:patternhunt_mobile/shared/widgets/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptySearch extends PatternsNotifier {
  @override
  Future<PatternsPage> build(PatternQuery query) async =>
      PatternsPage(patterns: [], hasMore: false, nextOffset: null);
}

Future<GoRouter> _mount(WidgetTester tester, {bool reduced = false}) async {
  SharedPreferences.setMockInitialValues({
    RecentSearches.prefsKey: ['Cardigan'],
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Center(child: Text('Home content')),
              ),
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
        sessionProvider.overrideWithValue(null),
        patternsProvider.overrideWith(_EmptySearch.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

final _field = find.byKey(const ValueKey('search-morph-field'));
final _icon = find.byKey(const ValueKey('search-shared-icon'));
bool _focused(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

void main() {
  testWidgets(
    'morph shares nav geometry, defers focus, and waits for keyboard on close',
    (tester) async {
      await _mount(tester);
      final source = tester.getRect(find.byKey(AppShell.searchButtonKey));
      final title = tester.getTopLeft(find.text('Pattern Hunt'));
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      expect(tester.getRect(_field), source);
      expect(tester.getCenter(_icon), source.center);
      expect(_focused(tester), isFalse);

      await tester.pump(); // Start the first animation tick.
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.getSize(_field).width, greaterThan(source.width));
      expect(_focused(tester), isFalse);
      expect(
        tester.getTopLeft(find.text('Pattern Hunt')).dx,
        lessThan(title.dx),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_focused(tester), isTrue);
      final openField = tester.getRect(_field);
      expect(tester.getCenter(_icon).dx, closeTo(openField.left + 23, .01));

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      tester.view.padding = const FakeViewPadding(top: 47);
      await tester.pumpAndSettle();
      expect(tester.getRect(_field), openField);
      final recentPosition = tester.getTopLeft(find.text('Cardigan'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_focused(tester), isFalse);
      expect(tester.getRect(_field), openField);
      expect(tester.getTopLeft(find.text('Cardigan')), recentPosition);

      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      await tester.pump();
      await tester.pump(); // Start the reverse ticker after keyboard dismissal.
      await tester.pump(const Duration(milliseconds: 170));
      expect(tester.getSize(_field).width, lessThan(openField.width));
      expect(tester.getSize(_field).width, greaterThan(source.width));
      await tester.pumpAndSettle();
      expect(find.byType(SearchOverlay), findsNothing);
      expect(tester.getRect(find.byKey(AppShell.searchButtonKey)), source);
      expect(tester.getTopLeft(find.text('Pattern Hunt')), title);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back interrupts opening and search can reopen without stale focus',
    (tester) async {
      await _mount(tester);
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SearchOverlay), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchOverlay), findsOneWidget);
      expect(_focused(tester), isTrue);
      // Outside tap uses exactly the same close path as the close button/back.
      await tester.tapAt(const Offset(2, 400));
      await tester.pumpAndSettle();
      expect(find.byType(SearchOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion keeps focus, recent search, clear and submit working',
    (tester) async {
      final router = await _mount(tester, reduced: true);
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(_focused(tester), isTrue);
      await tester.tap(find.text('Cardigan'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Cardigan',
      );
      expect(find.text('No results for “Cardigan”'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cable knit');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(SearchOverlay), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.queryParameters['q'],
        'Cable knit',
      );
      expect((await RecentSearches.load()).first, 'Cable knit');
      expect(tester.takeException(), isNull);
    },
  );
}
