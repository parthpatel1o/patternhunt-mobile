import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/pattern_card_widget.dart';

class BoardDetailScreen extends ConsumerWidget {
  const BoardDetailScreen({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardsWithPatternsProvider);

    return boardsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (groups) {
        BoardWithPatterns? group;
        for (final g in groups) {
          if (g.board.id == boardId) {
            group = g;
            break;
          }
        }
        if (group == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Folder not found')),
          );
        }

        final board = group.board;
        final patterns = group.patterns;
        final countLabel = patterns.length == 1
            ? '1 pattern in this folder'
            : '${patterns.length} patterns in this folder';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(boardsWithPatternsProvider),
            color: AppColors.accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded, size: 22),
                            label: const Text('All folders'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.muted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              iconSize: 22,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  board.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 32,
                                      ),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _deleteBoard(
                                  context,
                                  ref,
                                  board.id,
                                  board.name,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.muted,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                child: const Text('Delete folder'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            countLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                if (patterns.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      child: AppEmptyState(
                        emoji: '📁',
                        title: 'This folder is empty',
                        description:
                            'Bookmark a pattern and save it to “${board.name}”.',
                        action: EmptyStatePillButton(
                          label: 'Browse the rank board',
                          filled: true,
                          onPressed: () => context.go('/'),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pattern = patterns[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: PatternCardWidget(
                              pattern: pattern,
                              rank: index + 1,
                              showRank: false,
                            ),
                          );
                        },
                        childCount: patterns.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteBoard(
    BuildContext context,
    WidgetRef ref,
    String boardId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder'),
        content: Text('Are you sure you want to delete $name folder?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .delete('/boards', query: {'boardId': boardId});
      ref.invalidate(boardsWithPatternsProvider);
      ref.invalidate(boardsProvider);
      if (context.mounted) context.go('/saved');
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
