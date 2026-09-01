import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? category;
  String period = 'all';
  bool _categoryInitialized = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final constants = AppConstants.instance;

    if (!_categoryInitialized) {
      final session = ref.read(sessionProvider);
      if (session == null) {
        category ??= constants.defaultRankBoardCategory;
        _categoryInitialized = true;
      } else if (profile != null) {
        final defaultSlug = profile.defaultCategorySlug ?? constants.defaultUserCategory;
        category = defaultSlug == 'all' ? null : defaultSlug;
        _categoryInitialized = true;
      }
    }

    final query = PatternQuery(category: category, period: period);
    final patternsAsync = ref.watch(patternsProvider(query));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(patternsProvider(query)),
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in constants.rankPeriods)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: period == p.value,
                      onSelected: (_) => setState(() => period = p.value),
                      selectedColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: category == null,
                    onSelected: (_) => setState(() => category = null),
                    selectedColor: AppColors.primary,
                  ),
                ),
                for (final c in constants.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: category == c.slug,
                      onSelected: (_) => setState(() => category = c.slug),
                      selectedColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          patternsAsync.when(
            loading: () => Column(
              children: const [
                PatternCardSkeleton(),
                SizedBox(height: 12),
                PatternCardSkeleton(),
                SizedBox(height: 12),
                PatternCardSkeleton(),
              ],
            ),
            error: (e, _) => Center(child: Text('Could not load patterns\n$e', textAlign: TextAlign.center)),
            data: (patterns) {
              if (patterns.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: Text('No patterns yet. Check back soon!')),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < patterns.length; i++) ...[
                    RepaintBoundary(child: PatternCardWidget(pattern: patterns[i], rank: i + 1)),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
