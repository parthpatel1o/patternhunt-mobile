import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_empty_state.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(myPatternsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final isDesigner = profile?.isPatternDesigner ?? false;
    final insightsAsync = isDesigner ? ref.watch(insightsProvider) : null;
    final statsById = <String, DesignerPatternInsight>{};
    for (final p
        in insightsAsync?.valueOrNull?.patterns ??
            const <DesignerPatternInsight>[]) {
      statsById[p.id] = p;
    }

    return patternsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (patterns) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(myPatternsProvider);
            if (isDesigner) ref.invalidate(insightsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
            children: [
              if (patterns.isEmpty)
                AppEmptyState(
                  title: isDesigner
                      ? 'You haven’t submitted anything yet'
                      : 'Register as a designer in Profile to submit patterns.',
                  description: isDesigner
                      ? 'Submit a pattern and it will show up here. You can archive or delete it anytime.'
                      : 'Once you turn on designer mode, your published patterns will appear in this list.',
                  action: isDesigner
                      ? EmptyStatePillButton(
                          label: 'Submit a pattern',
                          filled: true,
                          onPressed: () => context.go('/submit'),
                        )
                      : EmptyStatePillButton(
                          label: 'Open Profile',
                          filled: false,
                          onPressed: () => context.go('/profile'),
                        ),
                )
              else
                for (final pattern in patterns) ...[
                  _MyPatternRow(
                    pattern: pattern,
                    insight: statsById[pattern.id],
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _MyPatternRow extends ConsumerWidget {
  const _MyPatternRow({required this.pattern, this.insight});

  final PatternCard pattern;
  final DesignerPatternInsight? insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = pattern.imageUrls.isNotEmpty ? pattern.imageUrls.first : null;
    final extraPhotos = (pattern.imageUrls.length - 1).clamp(0, 999);
    final saveCount = insight?.saveCount ?? 0;
    final ctaCount = pattern.isFree && pattern.hasPdf
        ? (insight?.pdfDownloadCount ?? 0)
        : (insight?.viewClickCount ?? 0);
    final rankLabel = pattern.isArchived || insight?.ranks.all == null
        ? null
        : '#${insight!.ranks.all} all time';
    DateTime? launched;
    try {
      launched = DateTime.parse(pattern.createdAt).toLocal();
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: pattern.isArchived
            ? AppColors.background.withValues(alpha: 0.8)
            : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: pattern.isArchived ? 0.7 : 1,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: cover != null
                              ? CachedNetworkImage(
                                  imageUrl: cover, fit: BoxFit.cover)
                              : ColoredBox(
                                  color: AppColors.background,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: AppColors.muted.withValues(alpha: 0.5),
                                  ),
                                ),
                        ),
                      ),
                      if (extraPhotos > 0)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+$extraPhotos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: pattern.isArchived ? 0.8 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              pattern.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                            ),
                            if (pattern.isArchived)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.muted.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Archived',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                    alpha: pattern.isFree ? 0.2 : 0.3),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                pattern.isFree ? 'Free' : 'Paid',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pattern.isFree
                                      ? AppColors.accent
                                      : AppColors.foreground,
                                ),
                              ),
                            ),
                            if (launched != null)
                              Text(
                                'Launched ${DateFormat('d MMM yyyy').format(launched)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            '${pattern.voteCount} ${pattern.voteCount == 1 ? 'upvote' : 'upvotes'}',
                            '$saveCount ${saveCount == 1 ? 'save' : 'saves'}',
                            pattern.isFree && pattern.hasPdf
                                ? '$ctaCount ${ctaCount == 1 ? 'download' : 'downloads'}'
                                : '$ctaCount ${ctaCount == 1 ? 'click' : 'clicks'}',
                            ?rankLabel,
                          ].join(' · '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/mine/${pattern.id}/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentForeground,
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _archive(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.card,
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    child: Text(
                      pattern.isArchived ? 'Unarchive' : 'Archive',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _delete(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: BorderSide(
                          color:
                              AppColors.destructive.withValues(alpha: 0.3)),
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    child: const Text(
                      'Delete',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).patch(
        '/me/patterns/${pattern.id}/archive',
        {'archived': !pattern.isArchived},
      );
      ref.invalidate(myPatternsProvider);
      ref.invalidate(insightsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete “${pattern.title}”?'),
        content: const Text(
            'This pattern will be deleted forever. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive),
            child: const Text('Delete pattern'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).delete('/me/patterns/${pattern.id}');
      ref.invalidate(myPatternsProvider);
      ref.invalidate(insightsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
