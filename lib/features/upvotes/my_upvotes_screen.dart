import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class MyUpvotesScreen extends ConsumerWidget {
  const MyUpvotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upvotes = ref.watch(myUpvotesProvider);
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => ref.invalidate(myUpvotesProvider),
      child: upvotes.when(
        loading: () => const _UpvotesSkeletons(),
        error: (_, _) =>
            _UpvotesError(onRetry: () => ref.invalidate(myUpvotesProvider)),
        data: (page) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          children: [
            _UpvotesHeader(count: page.patterns.length),
            const SizedBox(height: 24),
            if (page.patterns.isEmpty)
              _UpvotesEmpty(onBrowse: () => context.go('/'))
            else
              for (var index = 0; index < page.patterns.length; index++) ...[
                PatternCardWidget(
                  key: ValueKey(page.patterns[index].id),
                  pattern: page.patterns[index],
                  rank: index + 1,
                  showRank: false,
                  animateEntrance: false,
                  onVoteChange: (patternId, voted, voteCount) => ref
                      .read(myUpvotesProvider.notifier)
                      .applyVote(patternId, voted, voteCount),
                ),
                const SizedBox(height: 12),
              ],
            if (page.hasMore || page.loadMoreFailed) ...[
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton(
                  onPressed: page.loadingMore
                      ? null
                      : () => ref.read(myUpvotesProvider.notifier).loadMore(),
                  child: Text(
                    page.loadingMore
                        ? 'Loading…'
                        : page.loadMoreFailed
                        ? 'Try again'
                        : 'Load more',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpvotesHeader extends StatelessWidget {
  const _UpvotesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    count == 1 ? '1 upvote' : '$count upvotes',
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.15,
      color: AppColors.muted,
    ),
  );
}

class _UpvotesSkeletons extends StatelessWidget {
  const _UpvotesSkeletons();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 88),
    children: const [
      PatternCardSkeleton(),
      SizedBox(height: 12),
      PatternCardSkeleton(),
      SizedBox(height: 12),
      PatternCardSkeleton(),
    ],
  );
}

class _UpvotesError extends StatelessWidget {
  const _UpvotesError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        child: Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ),
    ],
  );
}

class _UpvotesEmpty extends StatelessWidget {
  const _UpvotesEmpty({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    emoji: '⬆️',
    title: 'No upvotes yet',
    description: 'Upvote patterns you love and they’ll appear here.',
    action: EmptyStatePillButton(
      label: 'Browse the rank board',
      filled: false,
      onPressed: onBrowse,
    ),
  );
}
