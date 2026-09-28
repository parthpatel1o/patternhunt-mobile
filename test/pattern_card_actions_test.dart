import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/shared/widgets/pattern_card_widget.dart';

PatternCard _pattern({required bool hasPdf, String? patternUrl}) => PatternCard(
  id: 'pattern',
  title: 'A crochet pattern with a longer two-line title',
  slug: 'test-pattern',
  imageUrls: const [],
  designerName: 'Designer',
  patternUrl: patternUrl,
  isFree: true,
  hasPdf: hasPdf,
  voteCount: 12,
  voted: false,
  createdAt: '2026-01-01T00:00:00Z',
  isArchived: false,
  saved: false,
);

Future<void> _pumpCard(WidgetTester tester, PatternCard pattern) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWithValue(null)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: PatternCardWidget(
                pattern: pattern,
                rank: 1,
                animateEntrance: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('free PDF pattern keeps both Download and View actions', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _pattern(hasPdf: true, patternUrl: 'https://example.com/pattern'),
    );

    expect(find.text('Download'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF without a pattern link only offers Download', (
    tester,
  ) async {
    await _pumpCard(tester, _pattern(hasPdf: true));

    expect(find.text('Download'), findsOneWidget);
    expect(find.text('View'), findsNothing);
  });
}
