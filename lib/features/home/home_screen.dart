import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/category_dropdown.dart';
import '../../shared/widgets/home_empty_state.dart';
import '../../shared/widgets/pattern_card_widget.dart';
import '../../shared/widgets/rank_board_filter.dart';
import '../../shared/widgets/submit_invite_card.dart';
import '../../shared/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialQuery,
    this.focusPatternId,
    this.initialCategory,
    this.initialPeriod,
    this.initialFreeOnly = false,
  });

  final String? initialQuery;
  final String? focusPatternId;

  /// When set (e.g. after submit), force this category on the rank board.
  final String? initialCategory;
  final String? initialPeriod;

  /// Match web `?free=1` — free-only filter on the rank board.
  final bool initialFreeOnly;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? category;
  String period = 'all';
  bool freeOnly = false;
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
  double? _lastScrollExtent;

  bool get _isSearching => searchQuery != null && searchQuery!.isNotEmpty;

  bool get _singlePatternMode {
    final id = widget.focusPatternId;
    return _isSearching && id != null && id.isNotEmpty;
  }

  bool get _rankFocusMode => !_isSearching && _focusId != null;

  String? _categoryLabel(AppConstants constants) {
    if (category == null) return null;
    return constants.categories
        .where((c) => c.slug == category)
        .map((c) => c.name)
        .firstOrNull;
  }

  void _backToRankBoard() {
    context.go('/');
  }

  @override
  void initState() {
    super.initState();
    searchQuery = widget.initialQuery?.trim().isEmpty == true
        ? null
        : widget.initialQuery?.trim();
    final forced = widget.initialCategory?.trim();
    if (forced != null && forced.isNotEmpty) {
      category = forced == 'all' ? null : forced;
      _categoryInitialized = true;
    }
    final forcedPeriod = widget.initialPeriod?.trim();
    if (forcedPeriod == 'all' ||
        forcedPeriod == 'week' ||
        forcedPeriod == 'month') {
      period = forcedPeriod!;
    }
    freeOnly = widget.initialFreeOnly;
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
    if (widget.initialFreeOnly != oldWidget.initialFreeOnly) {
      setState(() => freeOnly = widget.initialFreeOnly);
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
      freeOnly: _isSearching ? false : freeOnly,
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
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _revealFocusedPattern(),
        );
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
    final query = PatternQuery(
      category: category,
      period: period,
      freeOnly: freeOnly,
    );
    PatternsPage? firstPage;
    try {
      final focused = await api.getData(
        '/patterns',
        query: {...query.toQuery(), 'pattern': patternId},
        map: (json) => json as Map<String, dynamic>,
      );
      final page = PatternsPage.fromJson(focused);
      if (focused['found'] == true &&
          page.patterns.any((pattern) => pattern.id == patternId)) {
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
    final PatternsPage start =
        firstPage ??
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
    if (current == null ||
        !current.hasMore ||
        current.nextOffset == null ||
        current.loadingMore) {
      return;
    }
    setState(() => _focusedPage = current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(apiClientProvider)
          .getData(
            '/patterns',
            query: PatternQuery(
              category: category,
              period: period,
              freeOnly: freeOnly,
            ).toQuery(offset: current.nextOffset!),
            map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
          );
      if (!mounted) return;
      final seen = current.patterns.map((pattern) => pattern.id).toSet();
      final appended = next.patterns
          .where((pattern) => !seen.contains(pattern.id))
          .toList();
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
    if (target == null ||
        !_isFocusLaidOut(target) ||
        !_scrollExtentSettled(target)) {
      _revealAttempts += 1;
      if (_revealAttempts > 24) {
        _beginPlaceHighlight();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealFocusedPattern(),
      );
      return;
    }

    final scrolled = await _smoothScrollToCenter(target);
    if (!mounted || _revealedFocus) return;
    if (!scrolled) {
      _revealAttempts += 1;
      if (_revealAttempts > 24) {
        _beginPlaceHighlight();
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _revealFocusedPattern(),
        );
      }
      return;
    }

    final settled = _focusKey.currentContext;
    if (settled == null || !settled.mounted) {
      _beginPlaceHighlight();
      return;
    }
    await _waitUntilScrollSettles(settled);
    if (!mounted || _revealedFocus) return;
    _beginPlaceHighlight();
  }

  void _beginPlaceHighlight() {
    if (!mounted || _revealedFocus) return;
    _revealedFocus = true;
    setState(() => _showFocusEffect = true);
  }

  bool _scrollExtentSettled(BuildContext target) {
    final position = Scrollable.maybeOf(target)?.position;
    if (position == null || !position.hasContentDimensions) return false;
    final extent = position.maxScrollExtent;
    final settled =
        _lastScrollExtent != null && (extent - _lastScrollExtent!).abs() < 1;
    _lastScrollExtent = extent;
    return settled;
  }

  bool _isFocusLaidOut(BuildContext target) {
    final object = target.findRenderObject();
    return object is RenderBox &&
        object.hasSize &&
        object.attached &&
        object.size.height > 1;
  }

  /// Smooth center scroll, like web `scrollIntoView({ behavior: "smooth", block: "center" })`.
  /// Duration grows with distance so a long drop doesn't snap.
  Future<bool> _smoothScrollToCenter(BuildContext target) async {
    final object = target.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached)
      return false;
    final viewport = RenderAbstractViewport.maybeOf(object);
    final scrollable = Scrollable.maybeOf(target);
    if (viewport == null || scrollable == null) return false;
    final position = scrollable.position;
    if (!position.hasContentDimensions) return false;

    final targetOffset = viewport
        .getOffsetToReveal(object, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final distance = (targetOffset - position.pixels).abs();
    if (distance < 12) return true;

    final ms = (480 + distance * 0.38).clamp(560.0, 1300.0).round();
    await position.animateTo(
      targetOffset,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeInOutCubic,
    );
    return true;
  }

  /// Don't start the place effect until the card is on screen and the scroll has stopped.
  Future<void> _waitUntilScrollSettles(BuildContext target) async {
    final position = Scrollable.maybeOf(target)?.position;
    if (position == null) return;
    final done = Completer<void>();
    var last = position.pixels;
    var stable = 0;
    var frames = 0;

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    void step() {
      if (!mounted || done.isCompleted) return;
      frames += 1;
      final now = position.pixels;
      final still = (now - last).abs() < 0.5;
      last = now;
      if (still && _focusVisibleEnough(target)) {
        stable += 1;
        if (stable >= 8) {
          finish();
          return;
        }
      } else {
        stable = 0;
      }
      if (frames > 90) {
        finish();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => step());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => step());
    await done.future;
  }

  bool _focusVisibleEnough(BuildContext target) {
    final box = target.findRenderObject();
    final scrollable = Scrollable.maybeOf(target);
    final scrollBox = scrollable?.context.findRenderObject();
    if (box is! RenderBox ||
        scrollBox is! RenderBox ||
        !box.hasSize ||
        !scrollBox.hasSize) {
      return false;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
    final bottom = top + box.size.height;
    final visible =
        (bottom.clamp(0.0, scrollBox.size.height) -
                top.clamp(0.0, scrollBox.size.height))
            .clamp(0.0, box.size.height);
    if (box.size.height <= 0) return false;
    return visible / box.size.height >= 0.45;
  }

  void _onCategoryChanged(String value) {
    final next = value == 'all' ? null : value;
    if (_rankFocusMode) {
      // Match web CategoryBar: category links do not carry freeOnly.
      context.go(
        _rankBoardLocation(category: next, period: period, freeOnly: false),
      );
      return;
    }
    setState(() {
      category = next;
      freeOnly = false;
    });
  }

  void _onPeriodChanged(String value) {
    if (_rankFocusMode) {
      context.go(
        _rankBoardLocation(
          category: category,
          period: value,
          freeOnly: freeOnly,
        ),
      );
      return;
    }
    setState(() => period = value);
  }

  void _onFreeOnlyChanged(bool value) {
    if (_rankFocusMode) {
      context.go(
        _rankBoardLocation(
          category: category,
          period: period,
          freeOnly: value,
        ),
      );
      return;
    }
    setState(() => freeOnly = value);
  }

  String _rankBoardLocation({
    required String? category,
    required String period,
    bool freeOnly = false,
  }) {
    return Uri(
      path: '/',
      queryParameters: {
        'category': category ?? 'all',
        if (period != 'all') 'period': period,
        if (freeOnly) 'free': '1',
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
        final defaultSlug =
            profile.defaultCategorySlug ?? constants.defaultUserCategory;
        category = defaultSlug == 'all' ? null : defaultSlug;
        _categoryInitialized = true;
      }
    }
    _maybeStartFocusLoad();

    final query = PatternQuery(
      category: _isSearching ? null : category,
      period: period,
      q: searchQuery,
      freeOnly: _isSearching ? false : freeOnly,
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
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
            ),
            const SizedBox(height: 14),
            CategoryDropdown(
              value: category ?? 'all',
              entries: [
                (value: 'all', label: 'All categories'),
                for (final c in constants.categories)
                  (value: c.slug, label: c.name),
              ],
              onChanged: _onCategoryChanged,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final p in constants.rankPeriods) ...[
                  if (p != constants.rankPeriods.first)
                    const SizedBox(width: 24),
                  _PeriodLink(
                    label: p.label,
                    selected: period == p.value,
                    onTap: () => _onPeriodChanged(p.value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
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
                      const Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: AppColors.accent,
                      ),
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          if (!_isSearching)
            // Sit just above the first card — matches web RankBoardFilter.
            Align(
              alignment: Alignment.centerRight,
              child: RankBoardFilter(
                freeOnly: freeOnly,
                onFreeOnlyChanged: _onFreeOnlyChanged,
              ),
            ),
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
    final patternAsync = ref.watch(
      patternDetailProvider(widget.focusPatternId!),
    );
    return patternAsync.when(
      loading: () => const PatternCardSkeleton(),
      error: (_, _) => HomeEmptyState(
        categoryName: _categoryLabel(constants),
        searchQuery: searchQuery,
        freeOnly: freeOnly,
        onClearSearch: _backToRankBoard,
        onClearFreeOnly: () => _onFreeOnlyChanged(false),
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
          child: Text(
            'Could not load patterns\n$e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (page) {
        if (page.patterns.isEmpty) {
          return AppEnter(
            rise: 4,
            child: HomeEmptyState(
              categoryName: _categoryLabel(constants),
              searchQuery: searchQuery,
              freeOnly: !_isSearching && freeOnly,
              onSeeAll: () => setState(() {
                category = null;
                freeOnly = false;
              }),
              onClearSearch: _backToRankBoard,
              onClearFreeOnly: () => _onFreeOnlyChanged(false),
            ),
          );
        }
        // One list-level dissolve after the skeleton — no per-card cascade.
        return AppEnter(
          rise: 4,
          child: _patternColumn(
            page,
            showRank: !_isSearching,
            animateEntrance: false,
            showSubmitInvite: !_isSearching,
            boardQuery: query,
            reorderOnVote: !_isSearching,
          ),
        );
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
    return _patternColumn(
      _focusedPage!,
      showRank: true,
      animateEntrance: false,
      showSubmitInvite: true,
      reorderOnVote: true,
    );
  }

  void _applyFocusedVote(
    String patternId, {
    required bool voted,
    required int voteCount,
  }) {
    final page = _focusedPage;
    if (page == null) return;
    final updated = [
      for (final pattern in page.patterns)
        if (pattern.id == patternId)
          pattern.copyWith(voted: voted, voteCount: voteCount)
        else
          pattern,
    ];
    sortPatternsByRank(updated);
    setState(() => _focusedPage = page.copyWith(patterns: updated));
  }

  Widget _patternColumn(
    PatternsPage page, {
    required bool showRank,
    bool animateEntrance = true,
    bool showSubmitInvite = false,
    PatternQuery? boardQuery,
    bool reorderOnVote = false,
  }) {
    return Column(
      children: [
        for (var i = 0; i < page.patterns.length; i++) ...[
          PatternCardWidget(
            key: page.patterns[i].id == _focusId
                ? _focusKey
                : ValueKey(page.patterns[i].id),
            pattern: page.patterns[i],
            // Match web PatternGrid: prefer board rank from the API so free-only
            // keeps real period/all-time positions instead of reindexing 1..n.
            rank: page.patterns[i].allTimeRank ?? (page.rankOffset + i + 1),
            rankPeriod: period,
            showRank: showRank,
            animateEntrance: animateEntrance,
            highlight: _showFocusEffect && page.patterns[i].id == _focusId,
            onVoteChange: reorderOnVote
                ? (patternId, voted, voteCount) {
                    if (_rankFocusMode) {
                      _applyFocusedVote(
                        patternId,
                        voted: voted,
                        voteCount: voteCount,
                      );
                    } else if (boardQuery != null) {
                      ref
                          .read(patternsProvider(boardQuery).notifier)
                          .applyVote(
                            patternId,
                            voted: voted,
                            voteCount: voteCount,
                          );
                    }
                  }
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (page.loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (showSubmitInvite && !page.hasMore)
          const SubmitInviteCard(),
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
    return AppPressable(
      onTap: onTap,
      haptic: true,
      scale: AppMotion.pressScaleSmall,
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
              duration: AppMotion.fast,
              curve: AppMotion.soft,
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
