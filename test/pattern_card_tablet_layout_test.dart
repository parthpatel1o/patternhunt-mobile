import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/shared/widgets/pattern_card_widget.dart';
import 'package:patternhunt_mobile/shared/widgets/rank_board_viewport.dart';
import 'package:patternhunt_mobile/shared/widgets/skeleton_loader.dart';

final _pattern = PatternCard(
  id: 'tablet-pattern',
  title: 'A crochet pattern with a long name for testing the rank board',
  slug: 'tablet-pattern',
  designerName: 'A designer with a longer name',
  imageUrls: const [],
  patternUrl: 'https://example.com/pattern',
  isFree: false,
  hasPdf: false,
  voteCount: 1234,
  createdAt: '2026-10-09T00:00:00Z',
  isArchived: false,
  saved: false,
  voted: false,
);

Future<void> _mount(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
  bool skeleton = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWithValue(null)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: RankBoardViewport(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: skeleton
                  ? const PatternCardSkeleton()
                  : PatternCardWidget(
                      pattern: _pattern.copyWith(
                        voteCount: size.shortestSide < 600 ? 12 : 1234,
                      ),
                      rank: 1,
                      animateEntrance: false,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  for (final size in [
    const Size(600, 960),
    const Size(768, 1024),
    const Size(834, 1194),
    const Size(1024, 768),
    const Size(1194, 834),
    const Size(1366, 1024),
  ]) {
    testWidgets('tablet row bounds its gallery and fits details at $size', (
      tester,
    ) async {
      await _mount(tester, size);
      final image = tester.getRect(
        find.byKey(const ValueKey('tablet-pattern-gallery')),
      );
      expect(image.width, size.width >= 1024 ? 192 : 176);
      expect(image.height, image.width);
      final card = tester.getRect(
        find.byKey(const ValueKey('tablet-pattern-card')),
      );
      expect(card.height, lessThan(300));
      expect(card.width, lessThanOrEqualTo(1120));
      final title = tester.getRect(find.text(_pattern.title));
      final button = tester.getRect(
        find.widgetWithText(FilledButton, 'View Pattern'),
      );
      expect(title.left, greaterThanOrEqualTo(image.right));
      expect(button.right, lessThanOrEqualTo(card.right));
      expect(button.bottom, lessThanOrEqualTo(card.bottom));
      if (size.width >= 768) {
        expect(button.center.dy, closeTo(card.center.dy, 1));
      }
      expect(find.text('Launched 9 Oct 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('tablet loading card fits $size', (tester) async {
      await _mount(tester, size, skeleton: true);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('tablet-pattern-skeleton')))
            .height,
        lessThan(300),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('larger text keeps tablet actions inside the card', (
    tester,
  ) async {
    await _mount(tester, const Size(600, 960), textScale: 1.4);
    expect(tester.takeException(), isNull);
    final card = tester.getRect(
      find.byKey(const ValueKey('tablet-pattern-card')),
    );
    final actions = tester.getRect(
      find.widgetWithText(FilledButton, 'View Pattern'),
    );
    expect(actions.right, lessThanOrEqualTo(card.right));
    expect(actions.bottom, lessThanOrEqualTo(card.bottom));
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
  ]) {
    testWidgets(
      'phone card retains the original half-width geometry at $size',
      (tester) async {
        await _mount(tester, size);
        expect(find.byKey(const ValueKey('tablet-pattern-card')), findsNothing);
        expect(find.text('View'), findsOneWidget);
        final card = tester.getSize(find.byType(PatternCardWidget));
        expect(card.height, (size.width - 32) / 2 + 8);
        final gallery = tester.getSize(
          find
              .ancestor(
                of: find.text('No image'),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(gallery.width, (size.width - 32 - 4) / 2);
        expect(gallery.height, (size.width - 32) / 2 - 4);
        expect(find.text('Launched 9 Oct 2026'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
