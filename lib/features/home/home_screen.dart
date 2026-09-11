import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';
import '../../shared/widgets/home_empty_state.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialQuery,
    this.focusPatternId,
    this.initialCategory,
    this.initialPeriod,
  });

  final String? initialQuery;
  final String? focusPatternId;
  /// When set (e.g. after submit), force this category on the rank board.
  final String? initialCategory;
  final String? initialPeriod;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? category;
  String period = 'all';
  String? searchQuery;
  bool _categoryInitialized = false;
  final _scrollController = ScrollController();
  final _focusKey = GlobalKey();
  String? _focusId;
  PatternsPage? _focusedPage;
  bool _focusLoading = false;
  bool _focusLoadStarted = false;
  bool _showFocusEffect = false;
  bool _revealedFocus = false;
  int _revealAttempts = 0;

  bool get _isSearching => searchQuery != null && searchQuery!.isNotEmpty;

  bool get _singlePatternMode {
    final id = widget.focusPatternId;
    return _isSearching && id != null && id.isNotEmpty;
  }

  bool get _rankFocusMode => !_isSearching && _focusId != null;

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
    final forced = widget.initialCategory?.trim();
    if (forced != null && forced.isNotEmpty) {
      category = forced == 'all' ? null : forced;
      _categoryInitialized = true;
    }
    final forcedPeriod = widget.initialPeriod?.trim();
    if (forcedPeriod == 'all' || forcedPeriod == 'week' || forcedPeriod == 'month') {
      period = forcedPeriod!;
    }
    final focusId = widget.focusPatternId?.trim();
    if (!_isSearching && focusId != null && focusId.isNotEmpty) {
      _focusId = focusId;
    }
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
    if (widget.initialCategory != oldWidget.initialCategory) {
      final forced = widget.initialCategory?.trim();
      if (forced != null && forced.isNotEmpty) {
        setState(() {
          category = forced == 'all' ? null : forced;
          searchQuery = null;
          _categoryInitialized = true;
        });
      }
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
    if (pos.pixels < pos.maxScrollExtent - 400) return;
    if (_rankFocusMode) {
      _loadMoreFocused();
      return;
    }
    final query = PatternQuery(
      category: _isSearching ? null : category,
      period: period,
      q: searchQuery,
    );
    ref.read(patternsProvider(query).notifier).loadMore();
  }

  void _maybeStartFocusLoad() {
    if (_focusLoadStarted || !_rankFocusMode || !_categoryInitialized) return;
    _focusLoadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFocusedBoard();
    });
  }

  Future<void> _loadFocusedBoard() async {
    final id = _focusId;
    if (id == null || !mounted) return;
    setState(() => _focusLoading = _focusedPage == null);
    try {
      final page = await _fetchContainingPage(id);
      if (!mounted || _focusId != id) return;
      final found = page.patterns.any((pattern) => pattern.id == id);
      setState(() {
        _focusLoading = false;
        if (found) {
          _focusedPage = page;
        } else {
          _focusId = null;
          _focusedPage = null;
        }
      });
      if (found) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocusedPattern());
      }
    } catch (_) {
      if (!mounted || _focusId != id) return;
      setState(() {
        _focusLoading = false;
        _focusId = null;
        _focusedPage = null;
      });
    }
  }

  Future<PatternsPage> _fetchContainingPage(String patternId) async {
    final api = ref.read(apiClientProvider);
    final query = PatternQuery(category: category, period: period);
    PatternsPage? firstPage;
    try {
      final focused = await api.getData(
        '/patterns',
        query: {
          ...query.toQuery(),
          'pattern': patternId,
        },
        map: (json) => json as Map<String, dynamic>,
      );
      final page = PatternsPage.fromJson(focused);
      if (focused['found'] == true && page.patterns.any((pattern) => pattern.id == patternId)) {
        return page;
      }
      if (page.patterns.any((pattern) => pattern.id == patternId)) {
        return page;
      }
      // The API answered explicitly that this pattern is not on the board.
      if (focused.containsKey('found')) return page;
      firstPage = page;
    } catch (_) {
      firstPage = null;
    }

    // Older API ignores `pattern` and always returns the first page.
    final PatternsPage start = firstPage ??
        await api.getData(
          '/patterns',
          query: query.toQuery(),
          map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
        );
    if (start.patterns.any((pattern) => pattern.id == patternId)) {
      return start.copyWith(rankOffset: 0);
    }

    var offset = start.nextOffset ?? AppConstants.instance.scoreboardPageSize;
    var hasMore = start.hasMore;
    for (var i = 0; i < 40 && hasMore; i++) {
      final next = await api.getData(
        '/patterns',
        query: query.toQuery(offset: offset),
        map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
      );
      if (next.patterns.any((pattern) => pattern.id == patternId)) {
        return next.copyWith(rankOffset: offset);
      }
      if (!next.hasMore || next.nextOffset == null) break;
      offset = next.nextOffset!;
      hasMore = next.hasMore;
    }
    return start;
  }

  Future<void> _loadMoreFocused() async {
    final current = _focusedPage;
    if (current == null || !current.hasMore || current.nextOffset == null || current.loadingMore) {
      return;
    }
    setState(() => _focusedPage = current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(apiClientProvider).getData(
            '/patterns',
            query: PatternQuery(category: category, period: period).toQuery(offset: current.nextOffset!),
            map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
          );
      if (!mounted) return;
      final seen = current.patterns.map((pattern) => pattern.id).toSet();
      final appended = next.patterns.where((pattern) => !seen.contains(pattern.id)).toList();
      setState(() {
        _focusedPage = PatternsPage(
          patterns: [...current.patterns, ...appended],
          hasMore: next.hasMore,
          nextOffset: next.nextOffset,
          rankOffset: current.rankOffset,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _focusedPage = current.copyWith(loadingMore: false));
    }
  }

  Future<void> _revealFocusedPattern() async {
    if (!mounted || _revealedFocus || _focusId == null) return;
    final target = _focusKey.currentContext;
    if (target == null) {
      _revealAttempts += 1;
      if (_revealAttempts > 8) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocusedPattern());
      return;
    }
    _revealedFocus = true;
    try {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.32,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // Still flash the card even if it isn't in a scrollable yet.
    }
    if (!mounted) return;
    setState(() => _showFocusEffect = true);
  }

  void _onCategoryChanged(String value) {
    final next = value == 'all' ? null : value;
    if (_rankFocusMode) {
      context.go(_rankBoardLocation(category: next, period: period));
      return;
    }
    setState(() => category = next);
  }

  void _onPeriodChanged(String value) {
    if (_rankFocusMode) {
      context.go(_rankBoardLocation(category: category, period: value));
      return;
    }
    setState(() => period = value);
  }

  String _rankBoardLocation({required String? category, required String period}) {
    return Uri(
      path: '/',
      queryParameters: {
        'category': category ?? 'all',
        if (period != 'all') 'period': period,
      },
    ).toString();
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
    _maybeStartFocusLoad();

    final query = PatternQuery(
      category: _isSearching ? null : category,
      period: period,
      q: searchQuery,
    );

    return RefreshIndicator(
      onRefresh: () async {
        if (_singlePatternMode) {
          ref.invalidate(patternDetailProvider(widget.focusPatternId!));
        } else if (_rankFocusMode) {
          _revealedFocus = true;
          await _loadFocusedBoard();
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
              onChanged: _onCategoryChanged,
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
                    onTap: () => _onPeriodChanged(p.value),
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
          else if (_rankFocusMode)
            _buildFocusedBoard()
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
        return _patternColumn(page, showRank: !_isSearching);
      },
    );
  }

  Widget _buildFocusedBoard() {
    if (_focusLoading || _focusedPage == null) {
      return const Column(
        children: [
          PatternCardSkeleton(),
          SizedBox(height: 12),
          PatternCardSkeleton(),
          SizedBox(height: 12),
          PatternCardSkeleton(),
        ],
      );
    }
    return _patternColumn(_focusedPage!, showRank: true);
  }

  Widget _patternColumn(PatternsPage page, {required bool showRank}) {
    return Column(
      children: [
        for (var i = 0; i < page.patterns.length; i++) ...[
          PatternCardWidget(
            key: page.patterns[i].id == _focusId ? _focusKey : ValueKey(page.patterns[i].id),
            pattern: page.patterns[i],
            rank: page.rankOffset + i + 1,
            rankPeriod: period,
            showRank: showRank,
            highlight: _showFocusEffect && page.patterns[i].id == _focusId,
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
