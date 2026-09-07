import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 120),
        children: [
          _CategoryDropdown(
            value: category ?? 'all',
            entries: [
              (value: 'all', label: 'All categories'),
              for (final c in constants.categories) (value: c.slug, label: c.name),
            ],
            onChanged: (value) => setState(() => category = value == 'all' ? null : value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                for (final p in constants.rankPeriods)
                  ButtonSegment<String>(
                    value: p.value,
                    label: Text(
                      p.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              selected: {period},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) return;
                setState(() => period = selected.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppColors.primary;
                  return AppColors.card;
                }),
                foregroundColor: const WidgetStatePropertyAll(AppColors.foreground),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const BorderSide(color: AppColors.primaryStrong);
                  }
                  return const BorderSide(color: AppColors.border);
                }),
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
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
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Could not load patterns\n$e', textAlign: TextAlign.center),
              ),
            ),
            data: (page) {
              if (page.patterns.isEmpty) {
                return HomeEmptyState(categoryName: _categoryLabel(constants));
              }
              return Column(
                children: [
                  for (var i = 0; i < page.patterns.length; i++) ...[
                    RepaintBoundary(
                      child: PatternCardWidget(
                        pattern: page.patterns[i],
                        rank: i + 1,
                        rankPeriod: period,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (page.hasMore) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: page.loadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(),
                            )
                          : TextButton(
                              onPressed: () => ref.read(patternsProvider(query).notifier).loadMore(),
                              child: const Text('Load more'),
                            ),
                    ),
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

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  final String value;
  final List<({String value, String label})> entries;
  final ValueChanged<String> onChanged;

  String get _label =>
      entries.where((e) => e.value == value).map((e) => e.label).firstOrNull ?? 'All categories';

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.card),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(AppColors.accent.withValues(alpha: 0.18)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
      ),
      builder: (context, controller, child) {
        return Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  Icon(
                    controller.isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (final entry in entries)
          MenuItemButton(
            onPressed: () => onChanged(entry.value),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                entry.value == value ? AppColors.primary.withValues(alpha: 0.55) : Colors.transparent,
              ),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyle(
                      fontWeight: entry.value == value ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                if (entry.value == value)
                  const Icon(Icons.check, size: 18, color: AppColors.foreground),
              ],
            ),
          ),
      ],
    );
  }
}
