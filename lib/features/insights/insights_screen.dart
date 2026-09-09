import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);

    return insightsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(insightsProvider),
                child: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/mine'),
                child: const Text('Back to My patterns'),
              ),
            ],
          ),
        ),
      ),
      data: (insights) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async => ref.invalidate(insightsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
            children: [
              Text(
                'How crocheters find and engage with your patterns.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final tileWidth = (width - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          label: 'Profile views',
                          value: insights.profileViewCount,
                          hint: 'People who opened your creator page',
                          icon: Icons.visibility_outlined,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          label: 'Total upvotes',
                          value: insights.totalUpvotes,
                          hint: 'Votes lifting you on the rank board',
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          label: 'Total saves',
                          value: insights.totalSaves,
                          hint: 'Crocheters who bookmarked your patterns',
                          icon: Icons.bookmark_outline,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _StatTile(
                          label: 'Store clicks',
                          value: insights.totalCtaClicks,
                          hint: 'Shoppers who tapped through to buy or download',
                          icon: Icons.open_in_new,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                'Pattern breakdown',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (insights.patterns.isEmpty)
                Text(
                  'Submit a pattern to start seeing insights here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                )
              else
                for (final pattern in insights.patterns) ...[
                  _PatternInsightCard(pattern: pattern),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
  });

  final String label;
  final int value;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: AppColors.foreground),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat.decimalPattern().format(value),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _PatternInsightCard extends StatelessWidget {
  const _PatternInsightCard({required this.pattern});

  final DesignerPatternInsight pattern;

  @override
  Widget build(BuildContext context) {
    final isPdfCta = pattern.isFree && pattern.hasPdf;
    final ctaCount = isPdfCta ? pattern.pdfDownloadCount : pattern.viewClickCount;
    final rankValue = pattern.isArchived || pattern.ranks.all == null ? '—' : '#${pattern.ranks.all}';
    DateTime? launched;
    try {
      launched = DateTime.parse(pattern.createdAt).toLocal();
    } catch (_) {}

    return Opacity(
      opacity: pattern.isArchived ? 0.8 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: pattern.imageUrl != null
                        ? CachedNetworkImage(imageUrl: pattern.imageUrl!, fit: BoxFit.cover)
                        : ColoredBox(
                            color: AppColors.background,
                            child: Center(
                              child: Text(
                                'No photo',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pattern.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (pattern.isArchived)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.muted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Archived',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: pattern.isFree ? 0.2 : 0.3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              pattern.isFree ? 'Free' : 'Paid',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: pattern.isFree ? AppColors.accent : AppColors.foreground,
                              ),
                            ),
                          ),
                          if (launched != null)
                            Text(
                              'Launched ${DateFormat('d MMM yyyy').format(launched)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCell(label: 'Upvotes', value: '${pattern.voteCount}')),
                const SizedBox(width: 6),
                Expanded(child: _MetricCell(label: 'Saves', value: '${pattern.saveCount}')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _MetricCell(
                    label: isPdfCta ? 'Downloads' : 'Store clicks',
                    value: '$ctaCount',
                    emphasize: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: _MetricCell(label: 'All-time rank', value: rankValue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.primary.withValues(alpha: 0.35) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize ? AppColors.accent.withValues(alpha: 0.25) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 0.4,
                  color: emphasize ? AppColors.foreground.withValues(alpha: 0.8) : AppColors.muted,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}
