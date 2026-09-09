import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_empty_state.dart';

/// Matches web `EmptyState` + `EmptyScoreboard` / `SearchEmpty` (card, no icon by default).
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    this.categoryName,
    this.searchQuery,
    this.onSeeAll,
    this.onClearSearch,
  });

  final String? categoryName;
  final String? searchQuery;
  final VoidCallback? onSeeAll;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final q = searchQuery?.trim();
    final isSearch = q != null && q.isNotEmpty;

    final String title;
    final String description;
    if (isSearch) {
      title = 'No patterns found';
      description =
          'Nothing matched “$q”. Try a designer name, a shorter word, or check the spelling.';
    } else if (categoryName != null) {
      title = 'No $categoryName patterns yet';
      description =
          'The rank board is empty in $categoryName. Browse everything, or be the first to add one.';
    } else {
      title = 'The rank board is waiting';
      description =
          'No patterns have been published yet. Submit one and it’ll show up here for the community to upvote.';
    }

    return AppEmptyState(
      title: title,
      description: description,
      action: isSearch
          ? EmptyStatePillButton(
              label: 'Back to rank board',
              filled: true,
              accent: true,
              onPressed: onClearSearch ?? () => context.go('/'),
            )
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (categoryName != null)
                  EmptyStatePillButton(
                    label: 'See all patterns',
                    filled: false,
                    onPressed: onSeeAll ?? () => context.go('/'),
                  ),
                EmptyStatePillButton(
                  label: 'Submit a pattern',
                  filled: true,
                  onPressed: () => context.go('/submit'),
                ),
              ],
            ),
    );
  }
}
