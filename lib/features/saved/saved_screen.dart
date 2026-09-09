import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Open a folder to see the patterns you’ve saved.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => _createBoard(context, ref),
                        icon: const Icon(Icons.create_new_folder_outlined,
                            size: 18),
                        label: const Text('New folder'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryForeground,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (groups.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 88),
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
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 88),
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

  Future<void> _createBoard(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New folder',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Name your folder, then bookmark patterns to add them here.',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 40,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.foreground,
                          ),
                      decoration: InputDecoration(
                        hintText: 'Folder name',
                        hintStyle: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post('/boards', data: {'name': name});
      ref.invalidate(boardsWithPatternsProvider);
      ref.invalidate(boardsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Created “$name”')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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

