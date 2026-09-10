/// Match PatternHunt web `HuntShowFilter` helpers (`@patternhunt/core`).
library;

/// Unchecked by default: hide patterns the user has already voted on.
const String kDefaultHuntShowFilter = 'unvoted';

const List<String> kHuntShowFilterValues = [
  'all',
  'unvoted',
];

/// Checked = include already-voted patterns (`all`).
bool huntShowIncludesVoted(String show) => show == 'all';

String toggleHuntShowVoted(String current) =>
    current == 'all' ? 'unvoted' : 'all';

/// Map legacy saved-related / unknown values onto the voted-only filter.
String normalizeHuntShowFilter(String? raw) {
  if (raw == 'all' || raw == 'unvoted') return raw!;
  // Legacy: `unsaved` meant voted were still included.
  if (raw == 'unsaved') return 'all';
  // Legacy: `unvoted_unsaved` / old mobile values / anything else → hide voted.
  return kDefaultHuntShowFilter;
}
