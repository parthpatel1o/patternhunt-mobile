import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';

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

void main() {
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
