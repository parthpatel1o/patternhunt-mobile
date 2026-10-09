/// Match PatternHunt web `HuntShowFilter` helpers (`@patternhunt/core`).
library;

/// Unchecked by default. Upvoted patterns are always excluded.
const String kDefaultHuntShowFilter = 'unviewed';
const List<String> kHuntShowFilterValues = ['all', 'unviewed'];

bool huntShowIncludesViewed(String show) => show == 'all';
String toggleHuntShowViewed(String current) =>
    current == 'all' ? 'unviewed' : 'all';

/// Legacy voted/saved filters fall back to the unchecked default.
String normalizeHuntShowFilter(String? raw) =>
    raw == 'all' ? 'all' : kDefaultHuntShowFilter;
