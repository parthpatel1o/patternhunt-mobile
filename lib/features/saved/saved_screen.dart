import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_empty_state.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardsWithPatternsProvider);

    return boardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (groups) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async => ref.invalidate(boardsWithPatternsProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (groups.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    child: AppEmptyState(
                      emoji: '📁',
                      title: 'No folders yet',
                      description:
                          'Bookmark patterns from the rank board, or create folders here to organize them.',
                      action: EmptyStatePillButton(
                        label: 'Browse the rank board',
                        filled: false,
                        onPressed: () => context.go('/'),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groups[index];
                        return _SavedFolderCard(
                          group: group,
                          onTap: () => context.push('/saved/${group.board.id}'),
                        );
                      },
                      childCount: groups.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SavedFolderCard extends StatelessWidget {
  const _SavedFolderCard({required this.group, required this.onTap});

  final BoardWithPatterns group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previews = group.patterns
        .expand((p) => p.imageUrls.take(1))
        .take(4)
        .toList();
    final countLabel = group.patterns.length == 1
        ? '1 pattern'
        : '${group.patterns.length} patterns';
    final tabBorder = AppColors.primaryForeground.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.38,
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 16),
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(
                    top: BorderSide(color: tabBorder),
                    left: BorderSide(color: tabBorder),
                    right: BorderSide(color: tabBorder),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: tabBorder),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: AppColors.card.withValues(alpha: 0.7),
                        child: previews.isEmpty
                            ? Center(
                                child: Text(
                                  'Empty folder',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.muted,
                                      ),
                                ),
                              )
                            : _FolderMosaic(previews: previews),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    group.board.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                  ),
                  Text(
                    countLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderMosaic extends StatelessWidget {
  const _FolderMosaic({required this.previews});

  final List<String> previews;

  /// Match web `SavedFolderCard`: 2-col grid, gap 6px; 1 image spans full width;
  /// 3 images put the first on its own row spanning both columns.
  @override
  Widget build(BuildContext context) {
    Widget tile(String url) {
      return ColoredBox(
        color: AppColors.background,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    Widget row(List<String> urls) {
      return Row(
        children: [
          for (var i = 0; i < urls.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: tile(urls[i])),
          ],
        ],
      );
    }

    if (previews.length == 1) {
      return tile(previews.first);
    }

    if (previews.length == 2) {
      return row(previews);
    }

    if (previews.length == 3) {
      return Column(
        children: [
          Expanded(child: tile(previews[0])),
          const SizedBox(height: 6),
          Expanded(child: row(previews.sublist(1))),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: row(previews.sublist(0, 2))),
        const SizedBox(height: 6),
        Expanded(child: row(previews.sublist(2, 4))),
      ],
    );
  }
}

