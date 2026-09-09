/// Match PatternHunt web `HUNT_SHOW_*` / `HuntShowFilter` helpers.
library;

const String kDefaultHuntShowFilter = 'all';

const List<String> kHuntShowFilterValues = [
  'all',
  'unvoted',
  'unsaved',
  'unvoted_unsaved',
];

const List<({String value, String label})> kHuntShowChecks = [
  (value: 'voted', label: 'Show voted patterns'),
  (value: 'saved', label: 'Show saved patterns'),
];

bool isHuntShowFilter(String value) =>
    kHuntShowFilterValues.contains(value);

/// Map legacy / unknown stored values onto the current show filter set.
///
/// Old mobile values (`unvoted_saved`, bare `saved`) no longer match the API
/// semantics — treat them like an unknown default and use [kDefaultHuntShowFilter].
String normalizeHuntShowFilter(String? raw) {
  if (raw == null) return kDefaultHuntShowFilter;
  if (isHuntShowFilter(raw)) return raw;
  // Legacy: `unvoted_saved`, old checkbox-only `saved`, anything else.
  return kDefaultHuntShowFilter;
}

/// Checked = INCLUDE voted patterns.
bool huntShowHasVoted(String show) =>
    show == 'all' || show == 'unsaved';

/// Checked = INCLUDE saved patterns.
bool huntShowHasSaved(String show) =>
    show == 'all' || show == 'unvoted';

String composeHuntShowFilter({
  required bool showVoted,
  required bool showSaved,
}) {
  if (showVoted && showSaved) return 'all';
  if (!showVoted && showSaved) return 'unvoted';
  if (showVoted && !showSaved) return 'unsaved';
  return 'unvoted_unsaved';
}

String toggleHuntShowFilter(String current, String flag) {
  final nextVoted =
      flag == 'voted' ? !huntShowHasVoted(current) : huntShowHasVoted(current);
  final nextSaved =
      flag == 'saved' ? !huntShowHasSaved(current) : huntShowHasSaved(current);
  return composeHuntShowFilter(showVoted: nextVoted, showSaved: nextSaved);
}
