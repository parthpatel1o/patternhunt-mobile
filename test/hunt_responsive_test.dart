import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_screen.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_demo_pattern.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HuntApi extends ApiClient {
  _HuntApi({this.empty = false});
  final bool empty;
  @override
  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async => map({
    'patterns': [
      if (!empty)
        for (var i = 0; i < 2; i++)
          {
            'id': 'pattern-$i',
            'title':
                'A long crochet pattern name for testing tablet layouts $i',
            'slug': 'pattern-$i',
            'designerName': 'Crochet designer',
            'imageUrls': <String>[],
            'patternUrl': 'https://example.com/pattern',
            'isFree': false,
            'hasPdf': false,
            'voteCount': 5,
            'createdAt': '2026-10-08',
          },
    ],
    'hasMore': false,
  });
}

final _pan = find
    .byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanStart != null,
    )
    .first;

Future<void> _swipe(WidgetTester tester, double direction) async {
  final gesture = await tester.startGesture(tester.getCenter(_pan));
  await gesture.moveBy(Offset(30 * direction, 0));
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.moveBy(Offset(190 * direction, 0));
  await tester.pump(const Duration(milliseconds: 150));
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _mount(
  WidgetTester tester,
  Size size,
  bool tutorial, {
  double textScale = 1,
  bool empty = false,
}) async {
  SharedPreferences.setMockInitialValues({'hunt.tutorialSeen': !tutorial});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(null),
        apiClientProvider.overrideWithValue(_HuntApi(empty: empty)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: HuntScreen(),
          bottomNavigationBar: SizedBox(height: 80),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConstants.load);
  for (final tutorial in [false, true]) {
    for (final size in [
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(834, 1194),
      const Size(1194, 834),
      const Size(600, 768),
      const Size(512, 768),
    ]) {
      testWidgets(
        '${tutorial ? 'tutorial' : 'hunt'} fits $size and accepts a swipe',
        (tester) async {
          await _mount(tester, size, tutorial);
          expect(tester.takeException(), isNull);
          final deck = tester.getRect(
            find.byKey(const ValueKey('tablet-hunt-deck')),
          );
          expect(deck.width, lessThanOrEqualTo(480));
          if (tutorial) {
            final coach = tester.getRect(
              find
                  .ancestor(
                    of: find.text('1 of 5'),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            expect(deck.overlaps(coach), isFalse);
          } else {
            final actions = find.byTooltip('Save');
            for (final element in actions.evaluate()) {
              final rect = tester.getRect(find.byWidget(element.widget));
              expect(rect.bottom, lessThanOrEqualTo(size.height - 80));
            }
          }
          await _swipe(tester, -1);
          expect(tester.takeException(), isNull);
          if (tutorial) expect(find.text('2 of 5'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('rotating a tablet preserves the tutorial step and gestures', (
    tester,
  ) async {
    await _mount(tester, const Size(768, 1024), true);
    await _swipe(tester, -1);
    expect(find.text('2 of 5'), findsOneWidget);
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('2 of 5'), findsOneWidget);
    await _swipe(tester, 1);
    expect(find.text('3 of 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tablet completes the tutorial without hiding the action row', (
    tester,
  ) async {
    await _mount(tester, const Size(1024, 768), true);
    await _swipe(tester, -1);
    await _swipe(tester, 1);
    expect(find.text('3 of 5'), findsOneWidget);
    final photo = tester.getRect(
      find.byKey(const ValueKey('hunt-photo-$huntDemoPatternId')),
    );
    await tester.tapAt(Offset(photo.right - 30, photo.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4 of 5'), findsOneWidget);
    await tester.tapAt(Offset(photo.left + 30, photo.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('5 of 5'), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(_pan));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.moveBy(const Offset(0, -190));
    await tester.pump();
    await gesture.up();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('1 of 5'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scenario in [
    (const Size(390, 844), 1.0),
    (const Size(375, 667), 1.0),
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.4),
  ]) {
    testWidgets(
      'complete tutorial fits phone ${scenario.$1} at text scale ${scenario.$2}',
      (tester) async {
        await _mount(tester, scenario.$1, true, textScale: scenario.$2, empty: true);
        expect(tester.takeException(), isNull);
        await _swipe(tester, -1);
        expect(find.text('2 of 5'), findsOneWidget);
        await _swipe(tester, 1);
        expect(find.text('3 of 5'), findsOneWidget);
        var photo = tester.getRect(
          find.byKey(const ValueKey('hunt-photo-$huntDemoPatternId')),
        );
        await tester.tapAt(Offset(photo.right - 20, photo.center.dy));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('4 of 5'), findsOneWidget);
        await tester.tapAt(Offset(photo.left + 20, photo.center.dy));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('5 of 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final gesture = await tester.startGesture(tester.getCenter(_pan));
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 30));
        await gesture.moveBy(const Offset(0, -190));
        await tester.pump();
        await gesture.up();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
        }
        expect(find.text('1 of 5'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('phone keeps its full-width square photo layout', (tester) async {
    await _mount(tester, const Size(390, 900), false);
    expect(find.byKey(const ValueKey('tablet-hunt-deck')), findsNothing);
    final photo = tester.getRect(find.byType(AspectRatio).last);
    // 390 minus 24 deck padding, 24 photo padding, and the 2px card border.
    expect(photo.width, 340);
    expect(photo.height, 340);
    expect(tester.takeException(), isNull);
    await _swipe(tester, -1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
