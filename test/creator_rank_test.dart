import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/models/models.dart';

Map<String, dynamic> patternJson(String id, {int? rank}) => {
  'id': id,
  'title': id,
  'slug': id,
  'imageUrls': <String>[],
  'designerName': 'Designer',
  'isFree': true,
  'hasPdf': false,
  'voteCount': 10,
  'createdAt': '2026-01-01T00:00:00Z',
  'allTimeRank': rank,
};

void main() {
  test('creator cards retain all-time board ranks with gaps', () {
    final creator = CreatorProfile.fromJson({
      'name': 'Designer',
      'patterns': [
        for (final rank in [3, 17, 43]) patternJson('$rank', rank: rank),
      ],
    });
    expect(creator.patterns.map(creator.allTimeRankFor), [3, 17, 43]);
  });

  test(
    'explicit all-time metadata wins; missing ranks are not list positions',
    () {
      final creator = CreatorProfile.fromJson({
        'name': 'Designer',
        'patterns': [patternJson('ranked', rank: 43), patternJson('missing')],
        'boardRanks': {
          'ranked': {'all': 17, 'week': 1, 'month': 2},
          'missing': {'week': 3},
        },
      });
      expect(creator.allTimeRankFor(creator.patterns.first), 17);
      expect(creator.allTimeRankFor(creator.patterns.last), isNull);
    },
  );
}
