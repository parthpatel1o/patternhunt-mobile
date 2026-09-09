import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';
import '../../shared/widgets/home_empty_state.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialQuery, this.focusPatternId});

  final String? initialQuery;
  final String? focusPatternId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? category;
  String period = 'all';
  String? searchQuery;
  bool _categoryInitialized = false;
  final _scrollController = ScrollController();

  bool get _isSearching => searchQuery != null && searchQuery!.isNotEmpty;

  bool get _singlePatternMode {
    final id = widget.focusPatternId;
    return _isSearching && id != null && id.isNotEmpty;
  }

  String? _categoryLabel(AppConstants constants) {
    if (category == null) return null;
    return constants.categories.where((c) => c.slug == category).map((c) => c.name).firstOrNull;
  }

  void _backToRankBoard() {
    context.go('/');
  }

  @override
  void initState() {
    super.initState();
    searchQuery = widget.initialQuery?.trim().isEmpty == true ? null : widget.initialQuery?.trim();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery) {
      final next = widget.initialQuery?.trim();
      searchQuery = (next == null || next.isEmpty) ? null : next;
      if (searchQuery != null) category = null;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_singlePatternMode || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      final query = PatternQuery(
        category: _isSearching ? null : category,
        period: period,
        q: searchQuery,
      );
      ref.read(patternsProvider(query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final constants = AppConstants.instance;

    if (!_categoryInitialized) {
      final session = ref.read(sessionProvider);
      if (_isSearching) {
        category = null;
        _categoryInitialized = true;
      } else if (session == null) {
        category ??= constants.defaultRankBoardCategory;
        _categoryInitialized = true;
      } else if (profile != null) {
        final defaultSlug = profile.defaultCategorySlug ?? constants.defaultUserCategory;
        category = defaultSlug == 'all' ? null : defaultSlug;
        _categoryInitialized = true;
      }
    }

    final query = PatternQuery(
      category: _isSearching ? null : category,
      period: period,
      q: searchQuery,
    );

    return RefreshIndicator(
      onRefresh: () async {
        if (_singlePatternMode) {
          ref.invalidate(patternDetailProvider(widget.focusPatternId!));
        } else {
          ref.invalidate(patternsProvider(query));
        }
      },
      color: AppColors.accent,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!_isSearching) ...[
            Text(
              'Discover crochet patterns ranked by the community.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
            ),
            const SizedBox(height: 14),
            _CategoryDropdown(
              value: category ?? 'all',
              entries: [
                (value: 'all', label: 'All categories'),
                for (final c in constants.categories) (value: c.slug, label: c.name),
              ],
              onChanged: (value) => setState(() => category = value == 'all' ? null : value),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in constants.rankPeriods) ...[
                  if (p != constants.rankPeriods.first) const SizedBox(width: 18),
                  _PeriodLink(
                    label: p.label,
                    selected: period == p.value,
                    onTap: () => setState(() => period = p.value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: _backToRankBoard,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_left, size: 20, color: AppColors.accent),
                      Text(
                        'Back to rank board',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Results for “$searchQuery”',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          if (_singlePatternMode)
            _buildSinglePatternResults(constants)
          else
            _buildSearchOrRankResults(query, constants),
        ],
      ),
    );
  }

  Widget _buildSinglePatternResults(AppConstants constants) {
    final patternAsync = ref.watch(patternDetailProvider(widget.focusPatternId!));
    return patternAsync.when(
      loading: () => const PatternCardSkeleton(),
      error: (_, _) => HomeEmptyState(
        categoryName: _categoryLabel(constants),
        searchQuery: searchQuery,
        onClearSearch: _backToRankBoard,
      ),
      data: (pattern) => PatternCardWidget(
        pattern: pattern,
        rank: 1,
        rankPeriod: period,
        showRank: false,
      ),
    );
  }

  Widget _buildSearchOrRankResults(PatternQuery query, AppConstants constants) {
    final patternsAsync = ref.watch(patternsProvider(query));
    return patternsAsync.when(
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
          return HomeEmptyState(
            categoryName: _categoryLabel(constants),
            searchQuery: searchQuery,
            onSeeAll: () => setState(() => category = null),
            onClearSearch: _backToRankBoard,
          );
        }
        return Column(
          children: [
            for (var i = 0; i < page.patterns.length; i++) ...[
              PatternCardWidget(
                pattern: page.patterns[i],
                rank: i + 1,
                rankPeriod: period,
                showRank: !_isSearching,
              ),
              const SizedBox(height: 12),
            ],
            if (page.loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}

class _PeriodLink extends StatelessWidget {
  const _PeriodLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.foreground : AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2.5,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.foreground,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
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
    final selectedIcon = categoryIcon(value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth;
        return MenuAnchor(
          crossAxisUnconstrained: false,
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.card),
            elevation: const WidgetStatePropertyAll(10),
            shadowColor: const WidgetStatePropertyAll(Color(0x383D2F4A)),
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(menuWidth, double.infinity)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          ),
          builder: (context, controller, child) {
            return SizedBox(
              width: menuWidth,
              child: Material(
                color: AppColors.card,
                elevation: 1.5,
                shadowColor: const Color(0x293D2F4A),
                shape: const StadiumBorder(
                  side: BorderSide(color: AppColors.border),
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
                  child: SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
                      child: Row(
                        children: [
                          Icon(selectedIcon, size: 16, color: AppColors.foreground),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.foreground,
                                  ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: controller.isOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    entry.value == value ? AppColors.primary : Colors.transparent,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  overlayColor: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.35)),
                  minimumSize: WidgetStatePropertyAll(Size(menuWidth - 12, 44)),
                ),
                child: Row(
                  children: [
                    Icon(
                      categoryIcon(entry.value),
                      size: 16,
                      color: entry.value == value ? AppColors.primaryForeground : AppColors.foreground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: entry.value == value ? AppColors.primaryForeground : AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
