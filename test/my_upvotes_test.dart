import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/upvotes/my_upvotes_screen.dart';

PatternCard _upvote(String id) => PatternCard(
  id: id,
  title: id,
  slug: id,
  imageUrls: const [],
  designerName: 'Designer',
  patternUrl: null,
  isFree: true,
  hasPdf: false,
  voteCount: 1,
  voted: true,
  createdAt: '2026-09-18T00:00:00.000Z',
  isArchived: false,
  saved: false,
);

class _TestUpvotesNotifier extends MyUpvotesNotifier {
  @override
  Future<PatternsPage> build() async => PatternsPage(
    patterns: [_upvote('first')],
    hasMore: true,
    nextOffset: 20,
    totalCount: 45,
  );
}

void main() {
  test('parses and preserves the API total during loading and retries', () {
    final page = PatternsPage.fromJson({
      'patterns': [],
      'hasMore': true,
      'nextOffset': 20,
      'totalCount': 45,
    });
    expect(page.totalCount, 45);
    expect(page.copyWith(loadingMore: true).totalCount, 45);
    expect(page.copyWith(loadMoreFailed: true).totalCount, 45);
  });

  test('loading pages preserves the total and accepts a refreshed total', () {
    final first = PatternsPage(
      patterns: [_upvote('first')],
      hasMore: true,
      nextOffset: 20,
      totalCount: 45,
    );
    final next = PatternsPage(
      patterns: [_upvote('second')],
      hasMore: true,
      nextOffset: 40,
    );
    expect(appendPatternPage(first, next).totalCount, 45);
    expect(
      appendPatternPage(first, next.copyWith(totalCount: 44)).totalCount,
      44,
    );
  });

  test('unvoting adjusts the total once and rollback restores it', () async {
    final container = ProviderContainer(
      overrides: [myUpvotesProvider.overrideWith(_TestUpvotesNotifier.new)],
    );
    addTearDown(container.dispose);
    await container.read(myUpvotesProvider.future);
    final notifier = container.read(myUpvotesProvider.notifier);
    notifier.applyVote('first', false, 0);
    expect(container.read(myUpvotesProvider).requireValue.totalCount, 44);
    notifier.applyVote('first', false, 0);
    expect(container.read(myUpvotesProvider).requireValue.totalCount, 44);
    notifier.applyVote('first', true, 1);
    final restored = container.read(myUpvotesProvider).requireValue;
    expect(restored.totalCount, 45);
    expect(restored.patterns.single.id, 'first');
  });

  testWidgets('header shows the total while more patterns remain unloaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myUpvotesProvider.overrideWith(_TestUpvotesNotifier.new),
          sessionProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: Scaffold(body: MyUpvotesScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('45 upvotes'), findsOneWidget);
    expect(find.text('1 upvote'), findsNothing);
    expect(find.text('Load more'), findsOneWidget);
  });

  test('My upvotes preserves backend upvote-time ordering', () {
    final ordered = [_upvote('newest'), _upvote('middle'), _upvote('oldest')];

    expect(ordered.map((pattern) => pattern.id), [
      'newest',
      'middle',
      'oldest',
    ]);
  });

  test('unvoting removes only that pattern from My upvotes', () {
    final remaining = removeUpvotedPattern([
      _upvote('first'),
      _upvote('remove'),
      _upvote('last'),
    ], 'remove');

    expect(remaining.map((pattern) => pattern.id), ['first', 'last']);
  });

  test('loading another page retains the existing upvotes', () {
    final first = PatternsPage(
      patterns: [_upvote('first')],
      hasMore: true,
      nextOffset: 20,
    );
    final second = PatternsPage(
      patterns: [_upvote('second')],
      hasMore: false,
      nextOffset: null,
    );

    final combined = appendPatternPage(first, second);

    expect(combined.patterns.map((pattern) => pattern.id), ['first', 'second']);
    expect(combined.hasMore, isFalse);
  });
}
