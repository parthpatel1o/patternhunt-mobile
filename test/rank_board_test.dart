import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';

PatternCard _pattern({
  required String id,
  required int votes,
  required int rank,
  String createdAt = '2026-01-01T00:00:00.000Z',
}) {
  return PatternCard(
    id: id,
    title: id,
    slug: id,
    imageUrls: const [],
    designerName: 'Designer',
    patternUrl: null,
    isFree: true,
    hasPdf: false,
    voteCount: votes,
    voted: false,
    createdAt: createdAt,
    isArchived: false,
    saved: false,
    allTimeRank: rank,
  );
}

PatternsPage _page(
  List<PatternCard> patterns, {
  required bool hasMore,
  required int? nextOffset,
  int rankOffset = 0,
}) => PatternsPage(
  patterns: patterns,
  hasMore: hasMore,
  nextOffset: nextOffset,
  rankOffset: rankOffset,
);

void main() {
  test('voting updates all badges but keeps card positions until refresh', () {
    final page = _page(
      [
        _pattern(id: 'first', votes: 9, rank: 1),
        _pattern(id: 'second', votes: 8, rank: 2),
        _pattern(id: 'third', votes: 6, rank: 3),
        _pattern(
          id: 'fourth',
          votes: 5,
          rank: 4,
          createdAt: '2026-01-03T00:00:00.000Z',
        ),
        _pattern(
          id: 'fifth',
          votes: 5,
          rank: 5,
          createdAt: '2026-01-02T00:00:00.000Z',
        ),
      ],
      hasMore: false,
      nextOffset: null,
    );

    final upvoted = applyRankBoardVote(
      page,
      'fifth',
      voted: true,
      voteCount: 6,
    );
    expect(upvoted.patterns.map((pattern) => pattern.id), [
      'first',
      'second',
      'third',
      'fourth',
      'fifth',
    ]);
    expect(rankBoardBadges(upvoted, freeOnly: false), {
      'first': 1,
      'second': 2,
      'third': 4,
      'fourth': 5,
      'fifth': 3,
    });

    final unvoted = applyRankBoardVote(
      upvoted,
      'fifth',
      voted: false,
      voteCount: 5,
    );
    expect(unvoted.patterns.last.id, 'fifth');
    expect(rankBoardBadges(unvoted, freeOnly: false)['fifth'], 5);

    final refreshed = _page(
      [
        upvoted.patterns[0],
        upvoted.patterns[1],
        upvoted.patterns[4],
        upvoted.patterns[2],
        upvoted.patterns[3],
      ],
      hasMore: false,
      nextOffset: null,
    );
    expect(refreshed.patterns[2].id, 'fifth');
    expect(rankBoardBadges(refreshed, freeOnly: false)['fifth'], 3);
  });

  test('free-only board preserves server ranks with gaps', () {
    const ranks = [1, 3, 7];
    final resolved = [
      for (var index = 0; index < ranks.length; index++)
        resolveRankBoardRank(
          rankOffset: 0,
          index: index,
          freeOnly: true,
          allTimeRank: ranks[index],
        ),
    ];

    expect(resolved, [1, 3, 7]);
  });

  test('free-only vote exchanges existing rank slots without moving cards', () {
    final page = _page(
      [
        _pattern(id: 'first', votes: 10, rank: 1),
        _pattern(id: 'second', votes: 9, rank: 3),
        _pattern(id: 'third', votes: 8, rank: 7),
      ],
      hasMore: false,
      nextOffset: null,
    );
    final voted = applyRankBoardVote(page, 'third', voted: true, voteCount: 11);

    expect(voted.patterns.map((pattern) => pattern.id), [
      'first',
      'second',
      'third',
    ]);
    expect(rankBoardBadges(voted, freeOnly: true), {
      'first': 3,
      'second': 7,
      'third': 1,
    });
  });

  test('period cards retain the API all-time vote count', () {
    final pattern = PatternCard.fromJson({
      'id': 'weekly-pattern',
      'title': 'Weekly launch',
      'slug': 'weekly-launch',
      'imageUrls': <String>[],
      'designerName': 'Designer',
      'isFree': true,
      'hasPdf': false,
      'voteCount': 42,
      'createdAt': '2026-09-17T00:00:00.000Z',
    });

    expect(pattern.voteCount, 42);
  });

  test('focused board preloads rank 1 through a target at rank 43', () {
    final first = List.generate(
      20,
      (index) => _pattern(
        id: 'pattern-${index + 1}',
        votes: 100 - index,
        rank: index + 1,
      ),
    );
    final second = List.generate(
      20,
      (index) => _pattern(
        id: 'pattern-${index + 21}',
        votes: 80 - index,
        rank: index + 21,
      ),
    );
    final focused = List.generate(
      3,
      (index) => _pattern(
        id: 'pattern-${index + 41}',
        votes: 60 - index,
        rank: index + 41,
      ),
    );

    final board = combineFocusedBoardPages([
      _page(first, hasMore: true, nextOffset: 20),
      _page(second, hasMore: true, nextOffset: 40, rankOffset: 20),
      _page(focused, hasMore: true, nextOffset: 60, rankOffset: 40),
    ]);

    expect(board.rankOffset, 0);
    expect(board.patterns, hasLength(43));
    expect(
      board.patterns.indexWhere((pattern) => pattern.id == 'pattern-43'),
      42,
    );
    expect(
      resolveRankBoardRank(
        rankOffset: board.rankOffset,
        index: 42,
        freeOnly: false,
        allTimeRank: 43,
      ),
      43,
    );
  });

  test('focused board continues downward without duplicate patterns', () {
    final current = _page(
      [
        _pattern(id: 'pattern-41', votes: 3, rank: 41),
        _pattern(id: 'pattern-42', votes: 2, rank: 42),
        _pattern(id: 'pattern-43', votes: 1, rank: 43),
      ],
      hasMore: true,
      nextOffset: 60,
    );
    final next = _page(
      [
        _pattern(id: 'pattern-43', votes: 1, rank: 43),
        _pattern(id: 'pattern-44', votes: 0, rank: 44),
      ],
      hasMore: false,
      nextOffset: null,
      rankOffset: 40,
    );

    final appended = appendFocusedBoardPage(current, next);

    expect(appended.patterns.map((pattern) => pattern.id), [
      'pattern-41',
      'pattern-42',
      'pattern-43',
      'pattern-44',
    ]);
    expect(appended.rankOffset, 0);
    expect(appended.hasMore, isFalse);
  });

  test('retrying a normal pagination page does not duplicate patterns', () {
    final current = _page(
      [_pattern(id: 'one', votes: 2, rank: 1)],
      hasMore: true,
      nextOffset: 20,
    );
    final retriedPage = _page(
      [
        _pattern(id: 'one', votes: 2, rank: 1),
        _pattern(id: 'two', votes: 1, rank: 2),
      ],
      hasMore: false,
      nextOffset: null,
    );

    expect(
      appendPatternPage(
        current,
        retriedPage,
      ).patterns.map((pattern) => pattern.id),
      ['one', 'two'],
    );
  });
}
