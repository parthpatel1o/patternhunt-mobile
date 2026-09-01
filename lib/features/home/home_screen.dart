import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_pill.dart';
import '../../shared/widgets/home_empty_state.dart';
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

  String? _categoryLabel(AppConstants constants) {
    if (category == null) return null;
    return constants.categories.where((c) => c.slug == category).map((c) => c.name).firstOrNull;
  }

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
                for (var i = 0; i < constants.rankPeriods.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  FilterPill(
                    label: constants.rankPeriods[i].label,
                    selected: period == constants.rankPeriods[i].value,
                    showCheckmark: period == constants.rankPeriods[i].value,
                    onTap: () => setState(() => period = constants.rankPeriods[i].value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownMenu<String>(
            initialSelection: category ?? 'all',
            width: MediaQuery.sizeOf(context).width - 32,
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            dropdownMenuEntries: [
              const DropdownMenuEntry(value: 'all', label: 'All categories'),
              for (final c in constants.categories) DropdownMenuEntry(value: c.slug, label: c.name),
            ],
            onSelected: (value) => setState(() => category = value == 'all' ? null : value),
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
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Could not load patterns\n$e', textAlign: TextAlign.center),
              ),
            ),
            data: (patterns) {
              if (patterns.isEmpty) {
                return HomeEmptyState(categoryName: _categoryLabel(constants));
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
