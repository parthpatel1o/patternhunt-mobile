import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/analytics/analytics.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class CreatorScreen extends ConsumerStatefulWidget {
  const CreatorScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends ConsumerState<CreatorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Analytics.trackCreatorView(ref.read(apiClientProvider), widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final creatorAsync = ref.watch(creatorProvider(widget.slug));

    return creatorAsync.when(
      loading: () => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [PatternCardSkeleton(), SizedBox(height: 12), PatternCardSkeleton()],
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (creator) {
        if (creator.name == null) {
          return const Scaffold(body: Center(child: Text('Creator not found')));
        }
        final countLabel = creator.patterns.length == 1
            ? '1 pattern on the rank board'
            : '${creator.patterns.length} patterns on the rank board';

        return Scaffold(
          body: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => ref.invalidate(creatorProvider(widget.slug)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Rank board'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.foreground,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            creator.name!,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 32,
                                ),
                          ),
                          if (creator.isFoundingMember)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: AppColors.foreground),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Founding member',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.foreground,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        countLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (creator.patterns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        const Text('🧶', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          'No live patterns',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${creator.name} doesn’t have any patterns on the rank board right now.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.foreground,
                          ),
                          child: const Text('Browse the rank board'),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < creator.patterns.length; i++) ...[
                    PatternCardWidget(
                      pattern: creator.patterns[i],
                      rank: creator.boardRanks[creator.patterns[i].id]?.all ?? (i + 1),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}
