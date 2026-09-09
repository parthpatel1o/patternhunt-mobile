import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';
import '../../core/utils/slugify.dart';
import '../../shared/widgets/arrow_big_up_icon.dart';
import '../../shared/widgets/in_app_webview.dart';
import '../../shared/widgets/save_board_sheet.dart';
import 'hunt_demo_pattern.dart';
import 'hunt_storage.dart';

enum _HuntPhase { boot, setup, hunting, end }

enum _HuntGesture { swipe, photoTapRight, photoTapLeft, slideUp }

/// Match PatternHunt web HuntCard gesture thresholds (px / px·ms⁻¹).
const double _kSwipeThresholdPx = 88;
const double _kUpvoteThresholdPx = 100;
/// Web uses 0.55 px/ms; Flutter velocity is px/s → 550.
const double _kSwipeVelocityPxPerSec = 550;
const double _kUpvoteVelocityPxPerSec = 550;
const double _kUpvoteVelocityMinY = -36;
const int _kFlyMs = 280;
const int _kFlyUpMs = 360;
const int _kSnapMs = 220;
const int _kUpvotePopMs = 1400;

class HuntScreen extends ConsumerStatefulWidget {
  const HuntScreen({super.key});

  @override
  ConsumerState<HuntScreen> createState() => _HuntScreenState();
}

class _HuntScreenState extends ConsumerState<HuntScreen> {
  final _storage = HuntStorage();
  final PatternCard _demoPattern = createHuntDemoPattern();

  _HuntPhase _phase = _HuntPhase.boot;
  String _category = 'all';
  String _order = 'random';
  String _period = 'all';
  String _seed = '';
  List<PatternCard> _patterns = const [];
  int _pageOffset = 0;
  int _index = 0;
  int? _nextOffset;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  bool _tutorialSeen = false;
  int _tutorialStep = 0;
  bool _tutorialTransitioning = false;
  bool _tutorialFinishing = false;

  /// Snapshot when opening Filters mid-hunt so Cancel can restore without clearing the run.
  String? _setupCategory;
  String? _setupOrder;
  String? _setupPeriod;
  _HuntPhase? _phaseBeforeSetup;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final constants = AppConstants.instance;
    final results = await Future.wait<Object?>([
      _storage.readTutorialSeen(),
      _storage.readHuntRun(),
    ]);
    if (!mounted) return;

    _tutorialSeen = results[0]! as bool;
    final run = results[1] as HuntRun?;
    final profileCategory = ref
        .read(profileProvider)
        .valueOrNull
        ?.defaultCategorySlug;

    if (run != null) {
      _category = run.category;
      _order = run.order;
      _period = run.period;
      _seed = run.seed;
      final pageSize = constants.huntPageSize;
      final offset = (run.index ~/ pageSize) * pageSize;
      await _loadPage(offset: offset, targetAbsoluteIndex: run.index);
      return;
    }

    // Least friction (web parity): jump straight into a random hunt.
    _category = profileCategory ?? constants.defaultHuntCategory;
    _order = constants.defaultHuntOrder;
    _period = 'all';
    await _startHunt();
  }

  Map<String, dynamic> _huntQuery(int offset) {
    return <String, dynamic>{
      'order': _order,
      if (_order == 'random') 'seed': _seed,
      if (_category != 'all') 'category': _category,
      'period': _period,
      'offset': offset,
      'limit': AppConstants.instance.huntPageSize,
    };
  }

  Future<_HuntPage> _fetchPage(int offset) {
    return ref
        .read(apiClientProvider)
        .getData(
          '/hunt',
          query: _huntQuery(offset),
          map: (json) {
            if (json is List) {
              return _HuntPage(
                patterns: json
                    .map(
                      (item) =>
                          PatternCard.fromJson(item as Map<String, dynamic>),
                    )
                    .toList(),
                hasMore: json.length == AppConstants.instance.huntPageSize,
                nextOffset: offset + json.length,
              );
            }
            final data = json as Map<String, dynamic>;
            final rawPatterns =
                (data['patterns'] ?? data['items']) as List<dynamic>? ??
                const [];
            return _HuntPage(
              patterns: rawPatterns
                  .map(
                    (item) =>
                        PatternCard.fromJson(item as Map<String, dynamic>),
                  )
                  .toList(),
              hasMore: data['hasMore'] as bool? ?? false,
              nextOffset: data['nextOffset'] as int?,
            );
          },
        );
  }

  Future<void> _loadPage({
    required int offset,
    required int targetAbsoluteIndex,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
      _phase = _HuntPhase.hunting;
    });
    try {
      final page = await _fetchPage(offset);
      if (!mounted) return;
      if (page.patterns.isEmpty) {
        setState(() {
          _patterns = const [];
          _phase = _HuntPhase.end;
        });
        return;
      }
      setState(() {
        _patterns = page.patterns;
        _pageOffset = offset;
        _index = (targetAbsoluteIndex - offset).clamp(
          0,
          page.patterns.length - 1,
        );
        _hasMore = page.hasMore;
        _nextOffset = page.nextOffset;
        _phase = _HuntPhase.hunting;
      });
      await _persistRun();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t load patterns to hunt.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startHunt() async {
    _seed = createHuntSeed();
    await _storage.writePreferences(
      category: _category,
      order: _order,
      period: _period,
    );
    if (!mounted) return;
    await _loadPage(offset: 0, targetAbsoluteIndex: 0);
  }

  Future<void> _persistRun() {
    return _storage.writeHuntRun(
      HuntRun(
        seed: _seed,
        order: _order,
        category: _category,
        period: _period,
        index: _pageOffset + _index,
      ),
    );
  }

  Future<void> _movePattern(int delta) async {
    if (_loading || _patterns.isEmpty) return;
    final next = _index + delta;
    if (next >= 0 && next < _patterns.length) {
      setState(() => _index = next);
      await _persistRun();
      return;
    }

    if (delta > 0 && _hasMore) {
      final offset = _nextOffset ?? (_pageOffset + _patterns.length);
      await _loadPage(offset: offset, targetAbsoluteIndex: offset);
      return;
    }
    if (delta < 0 && _pageOffset > 0) {
      final offset = (_pageOffset - AppConstants.instance.huntPageSize).clamp(
        0,
        _pageOffset,
      );
      await _loadPage(offset: offset, targetAbsoluteIndex: _pageOffset - 1);
      return;
    }
    if (delta > 0) {
      setState(() => _phase = _HuntPhase.end);
    }
  }

  void _showFilters() {
    setState(() {
      _phaseBeforeSetup = _phase;
      _setupCategory = _category;
      _setupOrder = _order;
      _setupPeriod = _period;
      _phase = _HuntPhase.setup;
    });
  }

  void _cancelFilters() {
    setState(() {
      if (_setupCategory != null) {
        _category = _setupCategory!;
        _order = _setupOrder!;
        _period = _setupPeriod!;
      }
      _setupCategory = null;
      _setupOrder = null;
      _setupPeriod = null;
      _phase = _phaseBeforeSetup ?? _HuntPhase.hunting;
      _phaseBeforeSetup = null;
    });
  }

  Future<void> _applyFilters() async {
    _setupCategory = null;
    _setupOrder = null;
    _setupPeriod = null;
    _phaseBeforeSetup = null;
    await _storage.clearHuntRun();
    if (!mounted) return;
    await _startHunt();
  }

  Future<void> _restart() async {
    await _storage.clearHuntRun();
    if (!mounted) return;
    _seed = createHuntSeed();
    await _loadPage(offset: 0, targetAbsoluteIndex: 0);
  }

  Future<void> _finishTutorial() async {
    if (_tutorialFinishing || _tutorialSeen) return;
    _tutorialFinishing = true;
    try {
      await _storage.writeTutorialSeen(true);
      if (mounted) {
        setState(() {
          _tutorialSeen = true;
          _tutorialStep = 0;
          _tutorialTransitioning = false;
        });
      }
    } finally {
      _tutorialFinishing = false;
    }
  }

  Future<void> _onTutorialGesture(_HuntGesture gesture) async {
    if (_tutorialSeen ||
        _tutorialFinishing ||
        _tutorialTransitioning ||
        _tutorialStep >= 4) {
      return;
    }

    const expectedGestures = <_HuntGesture>[
      _HuntGesture.swipe,
      _HuntGesture.photoTapRight,
      _HuntGesture.photoTapLeft,
      _HuntGesture.slideUp,
    ];
    if (gesture != expectedGestures[_tutorialStep]) return;

    _tutorialTransitioning = true;
    final delay = switch (_tutorialStep) {
      0 => const Duration(milliseconds: 280),
      1 || 2 => const Duration(milliseconds: 40),
      _ => const Duration(milliseconds: 1450),
    };
    await Future<void>.delayed(delay);
    if (!mounted || _tutorialSeen || _tutorialFinishing) return;

    setState(() => _tutorialStep++);
    if (_tutorialStep == 4) {
      // Persist early (web writes on last gesture) so refresh mid-handoff skips tutorial.
      unawaited(_storage.writeTutorialSeen(true));
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      if (!mounted || _tutorialFinishing) return;
      await _finishTutorial();
      return;
    }
    _tutorialTransitioning = false;
  }

  static const double _topBarHeight = 54;

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionProvider);
    ref.watch(profileProvider);

    // Tutorial owns the surface until completed, even if the deck finished loading
    // into empty/end/error in the background (matches web).
    final showTutorialSurface =
        !_tutorialSeen &&
        (_phase == _HuntPhase.hunting || _phase == _HuntPhase.end);

    final content = showTutorialSurface
        ? _buildHunting()
        : switch (_phase) {
            _HuntPhase.boot =>
              const Center(child: CircularProgressIndicator()),
            _HuntPhase.setup => _buildSetup(),
            _HuntPhase.hunting => _buildHunting(),
            _HuntPhase.end => _buildEnd(),
          };

    // In-body header (not Scaffold AppBar) so the swipe card can paint over it.
    // Stack paints content above the header; header stays tappable when the card
    // is centered because the card's layout box sits below the bar.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Header first (under card). Content paints above so swipes overlay chrome.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: _topBarHeight),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Material(
      color: AppColors.background,
      child: SizedBox(
        height: _topBarHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Hunting Patterns',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (_phase == _HuntPhase.setup)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: _cancelFilters,
                    tooltip: 'Close filters',
                    icon: const Icon(Icons.close_rounded),
                  ),
                )
              else if (_phase == _HuntPhase.hunting || _phase == _HuntPhase.end)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: _showFilters,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Filters'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setCategory(String value) async {
    setState(() => _category = value);
    await _storage.writeCategory(value);
  }

  Future<void> _setOrder(String value) async {
    setState(() => _order = value);
    await _storage.writeOrder(value);
  }

  Future<void> _setPeriod(String value) async {
    setState(() => _period = value);
    await _storage.writePeriod(value);
  }

  Widget _buildSetup() {
    final constants = AppConstants.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.foreground,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tweak category, board, or order — then keep hunting.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              _FilterGroup(
                label: 'Category',
                children: [
                  _choiceChip(
                    'All categories',
                    _category == 'all',
                    () => unawaited(_setCategory('all')),
                    icon: categoryIcon('all'),
                  ),
                  for (final category in constants.categories)
                    _choiceChip(
                      category.name,
                      _category == category.slug,
                      () => unawaited(_setCategory(category.slug)),
                      icon: categoryIcon(category.slug),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _FilterGroup(
                label: 'Rank board',
                children: [
                  for (final period in constants.rankPeriods)
                    _choiceChip(
                      period.label,
                      _period == period.value,
                      () => unawaited(_setPeriod(period.value)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _FilterGroup(
                label: 'Order',
                children: [
                  for (final order in constants.huntOrders)
                    _choiceChip(
                      order.label,
                      _order == order.value,
                      () => unawaited(_setOrder(order.value)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _loading ? null : _applyFilters,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Apply filters',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceChip(
    String label,
    bool selected,
    VoidCallback onSelected, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primaryForeground),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHunting() {
    // First visit: practice on the demo card before the real deck (web parity).
    if (!_tutorialSeen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: _HuntPatternCard(
          key: ValueKey(_demoPattern.id),
          pattern: _demoPattern,
          period: _period,
          tutorialMode: true,
          tutorialStep: _tutorialStep,
          onPreviousPattern: () {},
          onNextPattern: () {},
          onGesture: _onTutorialGesture,
          tutorial: _TutorialCoach(
            step: _tutorialStep,
            onSkip: _finishTutorial,
          ),
        ),
      );
    }

    if (_error != null && _patterns.isEmpty) {
      return _MessageState(
        title: 'Couldn’t start the hunt',
        message: _error!,
        primaryLabel: 'Try again',
        onPrimary: () => _loadPage(
          offset: _pageOffset,
          targetAbsoluteIndex: _pageOffset + _index,
        ),
        secondaryLabel: 'Change filters',
        onSecondary: _showFilters,
      );
    }
    if (_patterns.isEmpty || _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pattern = _patterns[_index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: _HuntPatternCard(
        key: ValueKey(pattern.id),
        pattern: pattern,
        period: _period,
        onPreviousPattern: () => _movePattern(-1),
        onNextPattern: () => _movePattern(1),
      ),
    );
  }

  Widget _buildEnd() {
    if (_patterns.isEmpty) {
      return _MessageState(
        title: 'Nothing to hunt here',
        message:
            'Try another category or rank board, or check back once more patterns are published.',
        primaryLabel: 'Change filters',
        onPrimary: _showFilters,
      );
    }
    return _MessageState(
      title: 'You’ve seen every pattern',
      message:
          'Hunt again with the same filters, or change category and order.',
      primaryLabel: 'Hunt again',
      onPrimary: _restart,
      secondaryLabel: 'Change filters',
      onSecondary: _showFilters,
    );
  }
}

class _HuntPage {
  const _HuntPage({
    required this.patterns,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<PatternCard> patterns;
  final bool hasMore;
  final int? nextOffset;
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.6,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: children),
      ],
    );
  }
}

class _HuntPatternCard extends ConsumerStatefulWidget {
  const _HuntPatternCard({
    super.key,
    required this.pattern,
    required this.period,
    required this.onPreviousPattern,
    required this.onNextPattern,
    this.onGesture,
    this.tutorial,
    this.tutorialMode = false,
    this.tutorialStep = 0,
  });

  final PatternCard pattern;
  final String period;
  final VoidCallback onPreviousPattern;
  final VoidCallback onNextPattern;
  final ValueChanged<_HuntGesture>? onGesture;
  final Widget? tutorial;
  final bool tutorialMode;
  final int tutorialStep;

  @override
  ConsumerState<_HuntPatternCard> createState() => _HuntPatternCardState();
}

class _HuntPatternCardState extends ConsumerState<_HuntPatternCard>
    with TickerProviderStateMixin {
  late bool _voted;
  late bool _saved;
  late int _voteCount;
  int _imageIndex = 0;
  bool _voting = false;
  bool _saving = false;
  bool _ctaLoading = false;
  bool _heartPop = false;
  bool _exiting = false;
  bool _flyingUp = false;
  bool _dragging = false;
  bool _swipeHintConsumed = false;
  bool _slideUpHintConsumed = false;

  double _dragX = 0;
  double _dragY = 0;
  double _upvoteDragProgress = 0;
  int? _axisLock; // null, 1 = x, 2 = y
  Offset? _panOrigin;

  late final AnimationController _swipeHintController;
  late final Animation<double> _swipeHintX;
  late final AnimationController _slideUpHintController;
  late final Animation<double> _slideUpHintY;

  bool get _isDemo =>
      widget.tutorialMode || isHuntDemoPattern(widget.pattern);

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  bool get _showSwipeHint =>
      widget.tutorialMode &&
      widget.tutorialStep == 0 &&
      !_dragging &&
      !_exiting &&
      !_swipeHintConsumed &&
      !_reduceMotion;

  bool get _showSlideUpHint =>
      widget.tutorialMode &&
      widget.tutorialStep == 3 &&
      !_dragging &&
      !_exiting &&
      !_slideUpHintConsumed &&
      !_heartPop &&
      !_reduceMotion;

  @override
  void initState() {
    super.initState();
    _voted = widget.pattern.voted;
    _saved = widget.pattern.saved;
    _voteCount = widget.pattern.voteCount;
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    // Matches web `hunt-tut-card-swipe`: 0 → -28px → +28px → 0.
    _swipeHintX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -28)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -28, end: 28)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 28, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_swipeHintController);
    _slideUpHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Matches web `hunt-tut-card-slide-up`: 0 → -36px → 0.
    _slideUpHintY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -36)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -36, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_slideUpHintController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncIdleHintAnimations();
    });
  }

  @override
  void didUpdateWidget(covariant _HuntPatternCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tutorialStep != widget.tutorialStep ||
        oldWidget.tutorialMode != widget.tutorialMode) {
      _syncIdleHintAnimations();
    }
  }

  @override
  void dispose() {
    _swipeHintController.dispose();
    _slideUpHintController.dispose();
    super.dispose();
  }

  void _stopSwipeHint() {
    if (_swipeHintController.isAnimating || _swipeHintController.value != 0) {
      _swipeHintController.stop();
      _swipeHintController.reset();
    }
  }

  void _stopSlideUpHint() {
    if (_slideUpHintController.isAnimating ||
        _slideUpHintController.value != 0) {
      _slideUpHintController.stop();
      _slideUpHintController.reset();
    }
  }

  void _syncIdleHintAnimations() {
    final swipeShouldRun = widget.tutorialMode &&
        widget.tutorialStep == 0 &&
        !_swipeHintConsumed &&
        !_reduceMotion;
    if (swipeShouldRun) {
      if (!_swipeHintController.isAnimating) {
        _swipeHintController.repeat();
      }
    } else {
      _stopSwipeHint();
    }

    final slideShouldRun = widget.tutorialMode &&
        widget.tutorialStep == 3 &&
        !_slideUpHintConsumed &&
        !_heartPop &&
        !_reduceMotion;
    if (slideShouldRun) {
      if (!_slideUpHintController.isAnimating) {
        _slideUpHintController.repeat();
      }
    } else {
      _stopSlideUpHint();
    }
  }

  void _showUpvotePop() {
    setState(() => _heartPop = true);
    HapticFeedback.mediumImpact();
    _syncIdleHintAnimations();
    Future<void>.delayed(const Duration(milliseconds: _kUpvotePopMs), () {
      if (mounted) {
        setState(() => _heartPop = false);
        _syncIdleHintAnimations();
      }
    });
  }

  Future<void> _toggleVote() async {
    if (_voting) return;

    if (_isDemo) {
      setState(() {
        if (!_voted) {
          _voted = true;
          _voteCount = (_voteCount + 1).clamp(0, 1 << 30);
        }
      });
      _showUpvotePop();
      return;
    }

    if (ref.read(sessionProvider) == null) {
      if (mounted) context.go('/profile');
      return;
    }
    final oldVoted = _voted;
    final oldCount = _voteCount;
    setState(() {
      _voting = true;
      _voted = !_voted;
      _voteCount = (_voteCount + (_voted ? 1 : -1)).clamp(0, 1 << 30);
    });
    _showUpvotePop();
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/patterns/${widget.pattern.id}/vote',
            query: widget.period == 'all' ? null : {'period': widget.period},
          );
      if (!mounted) return;
      setState(() {
        _voted = response['voted'] as bool? ?? _voted;
        _voteCount = (response['voteCount'] as num?)?.toInt() ?? _voteCount;
      });
      ref.invalidate(patternsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _voted = oldVoted;
          _voteCount = oldCount;
        });
        _showError(error.message);
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  /// Slide-up upvote — matches web `upvoteOnly` (upvote only, never unvote).
  Future<void> _upvoteFromSlideUp() async {
    if (_isDemo) {
      setState(() {
        if (!_voted) {
          _voted = true;
          _voteCount = (_voteCount + 1).clamp(0, 1 << 30);
        }
      });
      _showUpvotePop();
      return;
    }

    if (_voted) {
      _showUpvotePop();
      return;
    }

    if (ref.read(sessionProvider) == null) {
      if (mounted) context.go('/profile');
      return;
    }

    if (_voting) return;
    final oldVoted = _voted;
    final oldCount = _voteCount;
    setState(() {
      _voting = true;
      _voted = true;
      _voteCount = (_voteCount + 1).clamp(0, 1 << 30);
    });
    _showUpvotePop();
    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/patterns/${widget.pattern.id}/vote',
            query: widget.period == 'all' ? null : {'period': widget.period},
          );
      if (!mounted) return;
      setState(() {
        _voted = response['voted'] as bool? ?? _voted;
        _voteCount = (response['voteCount'] as num?)?.toInt() ?? _voteCount;
      });
      ref.invalidate(patternsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _voted = oldVoted;
          _voteCount = oldCount;
        });
        _showError(error.message);
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    if (ref.read(sessionProvider) == null) {
      if (mounted) context.go('/profile');
      return;
    }
    final oldSaved = _saved;
    setState(() {
      _saving = true;
      _saved = !_saved;
    });
    try {
      final api = ref.read(apiClientProvider);
      if (oldSaved) {
        await api.delete('/patterns/${widget.pattern.id}/save');
      } else {
        await api.post('/patterns/${widget.pattern.id}/save');
      }
      invalidatePatternSaveState(ref, widget.pattern.id);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _saved = oldSaved);
        _showError(error.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSaveSheet() async {
    await showSaveBoardSheet(context, ref, widget.pattern.id);
    if (mounted) setState(() => _saved = true);
  }

  Future<void> _onCta() async {
    final pattern = widget.pattern;
    final download = pattern.isFree && pattern.hasPdf;
    final api = ref.read(apiClientProvider);
    if (download) {
      setState(() => _ctaLoading = true);
      try {
        Analytics.trackPatternCta(api, pattern.id, 'pdf');
        final result = await api.getData(
          '/patterns/${pattern.id}/pdf',
          map: (json) => json as Map<String, dynamic>,
        );
        final url = result['url'] as String?;
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      } on ApiException catch (error) {
        if (mounted) _showError(error.message);
      } finally {
        if (mounted) setState(() => _ctaLoading = false);
      }
      return;
    }
    if (pattern.patternUrl != null) {
      Analytics.trackPatternCta(api, pattern.id, 'view');
      if (mounted) {
        await openInAppWebView(
          context,
          url: pattern.patternUrl!,
          title: pattern.title,
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _movePhoto(int delta) {
    final count = widget.pattern.imageUrls.length;
    if (count < 2) return;
    setState(() {
      _imageIndex = (_imageIndex + delta).clamp(0, count - 1);
    });
  }

  Future<void> _flyOff({required bool toNext}) async {
    if (_exiting) return;
    _exiting = true;
    if (widget.tutorialMode && widget.tutorialStep == 0) {
      _swipeHintConsumed = true;
      _stopSwipeHint();
    }
    widget.onGesture?.call(_HuntGesture.swipe);
    final width = MediaQuery.sizeOf(context).width;
    final targetX = toNext ? -width * 1.2 : width * 1.2;
    setState(() {
      _dragX = targetX;
      _dragY = _dragY * 0.35;
      _upvoteDragProgress = 0;
    });
    await Future<void>.delayed(const Duration(milliseconds: _kFlyMs));
    if (!mounted) return;

    if (widget.tutorialMode) {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _exiting = false;
      });
      return;
    }

    if (toNext) {
      widget.onNextPattern();
    } else {
      widget.onPreviousPattern();
    }
  }

  Future<void> _flyUpAndUpvote() async {
    if (_exiting) return;
    _exiting = true;
    _flyingUp = true;
    if (widget.tutorialMode && widget.tutorialStep == 3) {
      _slideUpHintConsumed = true;
      _stopSlideUpHint();
    }
    final height = MediaQuery.sizeOf(context).height;
    final lift = math.max(height * 0.55, 320.0);
    setState(() {
      _upvoteDragProgress = 1;
      _dragX = _dragX * 0.2;
      _dragY = -lift;
    });
    widget.onGesture?.call(_HuntGesture.slideUp);
    unawaited(_upvoteFromSlideUp());
    await Future<void>.delayed(const Duration(milliseconds: _kFlyUpMs - 30));
    if (!mounted) return;
    setState(() {
      _dragX = 0;
      _dragY = 0;
      _upvoteDragProgress = 0;
      _flyingUp = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: _kSnapMs));
    if (!mounted) return;
    _exiting = false;
  }

  void _snapBack() {
    setState(() {
      _dragX = 0;
      _dragY = 0;
      _upvoteDragProgress = 0;
    });
  }

  void _handlePhotoTap(bool right) {
    widget.onGesture?.call(
      right ? _HuntGesture.photoTapRight : _HuntGesture.photoTapLeft,
    );
    _movePhoto(right ? 1 : -1);
  }

  void _onPanStart(DragStartDetails details) {
    if (_exiting) return;
    _panOrigin = details.globalPosition;
    _axisLock = null;
    _stopSwipeHint();
    _stopSlideUpHint();
    setState(() {
      _dragging = true;
      _dragX = 0;
      _dragY = 0;
      _upvoteDragProgress = 0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_exiting || _panOrigin == null) return;

    final dx = details.globalPosition.dx - _panOrigin!.dx;
    final dy = details.globalPosition.dy - _panOrigin!.dy;

    if (_axisLock == null) {
      if (dx.abs() < 10 && dy.abs() < 10) return;
      _axisLock = dx.abs() > dy.abs() * 1.05 ? 1 : 2;
      if (_axisLock == 1 &&
          widget.tutorialMode &&
          widget.tutorialStep == 0) {
        _swipeHintConsumed = true;
      }
      if (_axisLock == 2 &&
          widget.tutorialMode &&
          widget.tutorialStep == 3) {
        _slideUpHintConsumed = true;
      }
    }

    // Tutorial: only the matching axis for the current practice step.
    if (widget.tutorialMode) {
      if (widget.tutorialStep == 0 && _axisLock != 1) return;
      if (widget.tutorialStep == 3 && _axisLock != 2) return;
      if (widget.tutorialStep == 1 || widget.tutorialStep == 2) return;
    }

    if (_axisLock == 1) {
      setState(() {
        _dragX = dx;
        _dragY = dy * 0.12;
        _upvoteDragProgress = 0;
      });
      return;
    }

    if (_axisLock == 2) {
      // Rubber-band downward; free travel upward toward upvote.
      final y = dy > 0 ? dy * 0.18 : dy;
      setState(() {
        _dragY = y;
        _dragX = dx * 0.08;
        _upvoteDragProgress =
            (-y / _kUpvoteThresholdPx).clamp(0.0, 1.0);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _dragging = false);
    if (_exiting) {
      _axisLock = null;
      _panOrigin = null;
      return;
    }

    final vx = details.velocity.pixelsPerSecond.dx;
    final vy = details.velocity.pixelsPerSecond.dy;
    final wasHorizontal = _axisLock == 1;
    final wasVertical = _axisLock == 2;
    _axisLock = null;
    _panOrigin = null;

    if (wasVertical) {
      if (widget.tutorialMode && widget.tutorialStep != 3) {
        _snapBack();
        _syncIdleHintAnimations();
        return;
      }

      final committedByDistance = -_dragY >= _kUpvoteThresholdPx;
      final committedByVelocity =
          vy <= -_kUpvoteVelocityPxPerSec && _dragY < _kUpvoteVelocityMinY;

      if (committedByDistance || committedByVelocity) {
        unawaited(_flyUpAndUpvote());
        return;
      }

      _snapBack();
      _syncIdleHintAnimations();
      return;
    }

    if (wasHorizontal) {
      if (widget.tutorialMode && widget.tutorialStep != 0) {
        _snapBack();
        _syncIdleHintAnimations();
        return;
      }

      final committedByDistance = _dragX.abs() >= _kSwipeThresholdPx;
      final committedByVelocity = vx.abs() >= _kSwipeVelocityPxPerSec &&
          vx.sign == (_dragX == 0 ? vx.sign : _dragX.sign);
      final toNext = _dragX < 0 || (_dragX == 0 && vx < 0);

      if (committedByDistance || committedByVelocity) {
        unawaited(_flyOff(toNext: toNext));
        return;
      }

      _snapBack();
      _syncIdleHintAnimations();
      return;
    }

    _snapBack();
    _syncIdleHintAnimations();
  }

  void _onPanCancel() {
    setState(() => _dragging = false);
    _axisLock = null;
    _panOrigin = null;
    if (!_exiting) {
      _snapBack();
      _syncIdleHintAnimations();
    }
  }

  Widget? _buildCardCoach() {
    if (!widget.tutorialMode) return null;
    // Match web hideCoach: hide cue while upvote feedback / drag progress shows.
    if (widget.tutorialStep == 3 &&
        (_heartPop || _voted || _upvoteDragProgress > 0.15)) {
      return null;
    }
    return switch (widget.tutorialStep) {
      1 => _HuntTutTapDotCoach(
          alignRight: true,
          reduceMotion: _reduceMotion,
        ),
      2 => _HuntTutTapDotCoach(
          alignRight: false,
          reduceMotion: _reduceMotion,
        ),
      3 => _HuntTutSlideUpCoach(reduceMotion: _reduceMotion),
      _ => null,
    };
  }

  (Color bg, Color fg) _rankBadgeColors(int rank) {
    return switch (rank) {
      1 => (AppColors.primaryStrong, AppColors.foreground),
      2 || 3 => (AppColors.primary, AppColors.foreground),
      _ => (AppColors.card, AppColors.muted),
    };
  }

  (Color bg, Color fg) _pricePillColors(int? rank) {
    final onPodium = rank != null && rank <= 3;
    if (onPodium) {
      return (
        AppColors.card,
        widget.pattern.isFree ? AppColors.accent : AppColors.foreground,
      );
    }
    return (
      AppColors.primary.withValues(alpha: widget.pattern.isFree ? 0.2 : 0.3),
      widget.pattern.isFree ? AppColors.accent : AppColors.foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.pattern;
    final images = pattern.imageUrls;
    final download = !_isDemo && pattern.isFree && pattern.hasPdf;
    final hasCta = !_isDemo && (download || pattern.patternUrl != null);
    // Match web HuntCard: rotate(deg) = x * 0.04
    final rotation = _dragX * 0.04 * (math.pi / 180);
    final cardCoach = _buildCardCoach();
    final rank = _isDemo ? null : pattern.allTimeRank;
    final periodLabel = AppConstants.instance.rankPeriods
            .where((p) => p.value == widget.period)
            .map((p) => p.label)
            .firstOrNull ??
        'All time';
    final rankColors = rank != null ? _rankBadgeColors(rank) : null;
    final (pillBg, pillFg) = _pricePillColors(rank);

    final card = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Container(
            clipBehavior:
                (_showSwipeHint || _showSlideUpHint) ? Clip.none : Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (images.length > 1) ...[
                          Row(
                            children: [
                              for (var index = 0;
                                  index < images.length;
                                  index++) ...[
                                if (index > 0) const SizedBox(width: 6),
                                Expanded(
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: index == _imageIndex
                                          ? AppColors.accent
                                          : AppColors.border,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        AspectRatio(
                          aspectRatio: 1,
                          child: _HuntGallery(
                            images: images,
                            imageIndex: _imageIndex,
                            heartPop: _heartPop,
                            upvoteDragProgress: _upvoteDragProgress,
                            onTapSide: _handlePhotoTap,
                            cardCoach: cardCoach,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_isDemo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  'Demo',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (rank != null && rankColors != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: rankColors.$1,
                                  borderRadius: BorderRadius.circular(999),
                                  border: rank > 3
                                      ? Border.all(color: AppColors.border)
                                      : null,
                                ),
                                child: Text(
                                  '#$rank $periodLabel',
                                  style: TextStyle(
                                    color: rankColors.$2,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: pillBg,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: rank != null && rank <= 3
                                    ? [
                                        BoxShadow(
                                          color: AppColors.accent
                                              .withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                pattern.isFree ? 'Free' : 'Paid',
                                style: TextStyle(
                                  color: pillFg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          pattern.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_isDemo)
                          Text(
                            pattern.designerName,
                            style: const TextStyle(
                              color: AppColors.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () => context
                                .push(creatorPath(pattern.designerName)),
                            child: Text(
                              pattern.designerName,
                              style: const TextStyle(
                                color: AppColors.foreground,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        if (_isDemo)
                          const Text(
                            'Try the gestures on this card — nothing is saved until you start hunting.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          )
                        else
                          Row(
                            children: [
                              _RoundActionButton(
                                tooltip: _saved ? 'Saved' : 'Save',
                                icon: _saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                                onPressed: _saving ? null : _toggleSave,
                                onLongPress:
                                    _saving ? null : _openSaveSheet,
                              ),
                              const SizedBox(width: 8),
                              _VoteButton(
                                voted: _voted,
                                voteCount: _voteCount,
                                busy: _voting,
                                onPressed: _toggleVote,
                              ),
                              if (hasCta) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: FilledButton(
                                      onPressed:
                                          _ctaLoading ? null : _onCta,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor:
                                            AppColors.accentForeground,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(
                                        _ctaLoading
                                            ? 'Loading…'
                                            : download
                                                ? 'Download'
                                                : 'View Pattern',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // Bottom tutorial sheet stays visible during upvote feedback (web behavior).
          if (widget.tutorial != null) widget.tutorial!,
        ],
    );

    if (_showSwipeHint) {
      return AnimatedBuilder(
        animation: _swipeHintX,
        builder: (context, child) {
          final x = _swipeHintX.value;
          final rot = (x / 28) * (3.5 * math.pi / 180);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(x, 0, 0, 1)
              ..rotateZ(rot),
            child: child,
          );
        },
        child: card,
      );
    }

    if (_showSlideUpHint) {
      return AnimatedBuilder(
        animation: _slideUpHintY,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(0, _slideUpHintY.value, 0, 1),
            child: child,
          );
        },
        child: card,
      );
    }

    final animMs = (!_dragging || _exiting)
        ? (_flyingUp ? _kFlyUpMs : (_exiting ? _kFlyMs : _kSnapMs))
        : 0;

    return AnimatedContainer(
      duration: Duration(milliseconds: animMs),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translateByDouble(_dragX, _dragY, 0, 1)
        ..rotateZ(rotation),
      transformAlignment: Alignment.center,
      child: card,
    );
  }
}

class _HuntGallery extends StatelessWidget {
  const _HuntGallery({
    required this.images,
    required this.imageIndex,
    required this.heartPop,
    required this.upvoteDragProgress,
    required this.onTapSide,
    this.cardCoach,
  });

  final List<String> images;
  final int imageIndex;
  final bool heartPop;
  final double upvoteDragProgress;
  final ValueChanged<bool> onTapSide;
  final Widget? cardCoach;

  static const _sparks = <(double, double, double, double)>[
    // dx, dy, delayMs, size
    (-42, -58, 0, 14),
    (48, -52, 40, 12),
    (-56, -18, 70, 10),
    (54, -12, 90, 12),
    (8, -78, 20, 16),
  ];

  @override
  Widget build(BuildContext context) {
    final showDragCue = upvoteDragProgress > 0.08 && !heartPop;
    final arrowSize = (2.75 + upvoteDragProgress * 2.5) * 16; // rem≈16

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: AppColors.primary.withValues(alpha: 0.15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              const Center(
                child: Text(
                  'No photo',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              )
            else
              for (var index = 0; index < images.length; index++)
                AnimatedOpacity(
                  opacity: index == imageIndex ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    // Cover is always square — fill the frame. Extra photos may be any ratio.
                    fit: index == 0 ? BoxFit.cover : BoxFit.contain,
                    alignment: Alignment.center,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final width = context.size?.width ?? 1;
                  if (details.localPosition.dx < width / 2) {
                    onTapSide(false);
                  } else {
                    onTapSide(true);
                  }
                },
              ),
            ),
            if (cardCoach != null)
              Positioned.fill(
                child: IgnorePointer(child: cardCoach!),
              ),
            if (showDragCue)
              IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.35 + upvoteDragProgress * 0.65,
                    child: Transform.translate(
                      offset: Offset(0, (1 - upvoteDragProgress) * 18),
                      child: Transform.scale(
                        scale: 0.85 + upvoteDragProgress * 0.35,
                        child: ArrowBigUpIcon(
                          size: arrowSize,
                          color: AppColors.accent,
                          filled: true,
                          strokeWidth: 2.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (heartPop)
              const IgnorePointer(
                child: _HuntUpvoteBurst(),
              ),
          ],
        ),
      ),
    );
  }
}

class _HuntUpvoteBurst extends StatefulWidget {
  const _HuntUpvoteBurst();

  @override
  State<_HuntUpvoteBurst> createState() => _HuntUpvoteBurstState();
}

class _HuntUpvoteBurstState extends State<_HuntUpvoteBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kUpvotePopMs),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Pop badge: scale in, hold, fade (matches hunt-upvote-pop).
        double badgeOpacity;
        double badgeScale;
        if (t < 0.10) {
          final p = t / 0.10;
          badgeOpacity = p;
          badgeScale = 0.7 + 0.38 * p;
        } else if (t < 0.72) {
          badgeOpacity = 1;
          badgeScale = 1.08 - 0.08 * ((t - 0.10) / 0.62);
        } else {
          badgeOpacity = 1 - ((t - 0.72) / 0.28);
          badgeScale = 1;
        }

        // Burst icon (0–900ms of 1400ms).
        final burstT = (t * _kUpvotePopMs / 900).clamp(0.0, 1.0);
        double burstOpacity;
        double burstScale;
        double burstY;
        if (burstT < 0.18) {
          final p = burstT / 0.18;
          burstOpacity = p;
          burstScale = 0.35 + 0.85 * p;
          burstY = -5 * p;
        } else if (burstT < 0.55) {
          final p = (burstT - 0.18) / 0.37;
          burstOpacity = 1;
          burstScale = 1.2 - 0.2 * p;
          burstY = -5 - 15 * p;
        } else {
          final p = (burstT - 0.55) / 0.45;
          burstOpacity = 1 - p;
          burstScale = 1 - 0.15 * p;
          burstY = -20 - 40 * p;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Transform.translate(
                offset: Offset(0, burstY),
                child: Opacity(
                  opacity: burstOpacity,
                  child: Transform.scale(
                    scale: burstScale,
                    child: const ArrowBigUpIcon(
                      size: 80,
                      color: AppColors.accent,
                      filled: true,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),
            for (final spark in _HuntGallery._sparks)
              _buildSpark(t, spark.$1, spark.$2, spark.$3, spark.$4),
            Center(
              child: Opacity(
                opacity: badgeOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: badgeScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: AppShadows.card,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ArrowBigUpIcon(
                          size: 20,
                          color: Colors.white,
                          filled: true,
                          strokeWidth: 2.25,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Upvoted',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpark(
    double t,
    double dx,
    double dy,
    double delayMs,
    double size,
  ) {
    final start = delayMs / _kUpvotePopMs;
    final end = start + 780 / _kUpvotePopMs;
    if (t < start) return const SizedBox.shrink();
    final local = ((t - start) / (end - start)).clamp(0.0, 1.0);
    final opacity = local < 0.2 ? local / 0.2 : 1 - ((local - 0.2) / 0.8);
    final scale = 0.4 + 0.3 * local;
    return Center(
      child: Transform.translate(
        offset: Offset(dx * local, dy * local),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: ArrowBigUpIcon(
              size: size,
              color: AppColors.accent,
              filled: true,
              strokeWidth: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.voted,
    required this.voteCount,
    required this.busy,
    required this.onPressed,
  });

  final bool voted;
  final int voteCount;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Match home pattern cards: accent fill when voted, white + accent outline otherwise.
    final bg = voted ? AppColors.accent : Colors.white;
    final fg = voted ? AppColors.accentForeground : AppColors.accent;
    final border = AppColors.accent;

    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: StadiumBorder(
            side: BorderSide(color: border),
          ),
        ),
        icon: ArrowBigUpIcon(
          size: 20,
          color: fg,
          filled: voted,
        ),
        label: Text(
          '$voteCount',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.card,
        shape: StadiumBorder(
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

/// Pulsing tap-dot coach — web `hunt-tut-tap-dot-a` / `hunt-tut-tap-dot-b`.
class _HuntTutTapDotCoach extends StatefulWidget {
  const _HuntTutTapDotCoach({
    required this.alignRight,
    required this.reduceMotion,
  });

  final bool alignRight;
  final bool reduceMotion;

  @override
  State<_HuntTutTapDotCoach> createState() => _HuntTutTapDotCoachState();
}

class _HuntTutTapDotCoachState extends State<_HuntTutTapDotCoach>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // 0/100% → scale 1 / opacity 0.4; 40% → scale 1.18 / opacity 1.
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_controller);
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _HuntTutTapDotCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.alignRight) const Spacer(),
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = widget.reduceMotion ? 0.5 : _pulse.value;
                final scale = 1 + 0.18 * t;
                final opacity = 0.4 + 0.6 * t;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.55),
                  border: Border.all(color: AppColors.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!widget.alignRight) const Spacer(),
      ],
    );
  }
}

/// Slide-up coach — web `hunt-tut-slide-up-heart` / `hunt-tut-slide-up-cue`.
class _HuntTutSlideUpCoach extends StatefulWidget {
  const _HuntTutSlideUpCoach({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_HuntTutSlideUpCoach> createState() => _HuntTutSlideUpCoachState();
}

class _HuntTutSlideUpCoachState extends State<_HuntTutSlideUpCoach>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _HuntTutSlideUpCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = widget.reduceMotion ? 0.5 : _pulse.value;
          // Heart: translateY 10→-14, scale 0.92→1.12, opacity 0.45→1
          final heartY = 10 - 24 * t;
          final heartScale = 0.92 + 0.20 * t;
          final heartOpacity = 0.45 + 0.55 * t;
          // Cue: translateY 6→-10, opacity 0.55→1
          final cueY = 6 - 16 * t;
          final cueOpacity = 0.55 + 0.45 * t;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: heartOpacity,
                child: Transform.translate(
                  offset: Offset(0, heartY),
                  child: Transform.scale(
                    scale: heartScale,
                    child: const ArrowBigUpIcon(
                      size: 56,
                      color: AppColors.accent,
                      filled: true,
                      strokeWidth: 2.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: cueOpacity,
                child: Transform.translate(
                  offset: Offset(0, cueY),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'SLIDE UP',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _tutorialMessages = <(String, String, String)>[
  (
    'Swipe to browse',
    'Swipe the card left for the next pattern, or right for the previous.',
    'Swipe the card to continue',
  ),
  (
    'Next photo',
    'Tap the right side of the image to see the next photo.',
    'Tap the right side to continue',
  ),
  (
    'Previous photo',
    'Tap the left side of the image to go back.',
    'Tap the left side to continue',
  ),
  (
    'Slide up to upvote',
    'Slide this card upward to upvote the pattern.',
    'Slide the card up to finish',
  ),
  (
    'Enjoy hunting patterns',
    '',
    '',
  ),
];

class _TutorialCoach extends StatelessWidget {
  const _TutorialCoach({required this.step, required this.onSkip});

  final int step;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final item = _tutorialMessages[step];
    final isPracticeStep = step < 4;

    if (!isPracticeStep) {
      return Positioned.fill(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(22),
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 104,
      child: Material(
        color: AppColors.accent.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(18),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${step + 1} of 4',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => unawaited(onSkip()),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              Text(
                item.$1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.$3,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
              if (secondaryLabel != null && onSecondary != null)
                TextButton(
                  onPressed: onSecondary,
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
