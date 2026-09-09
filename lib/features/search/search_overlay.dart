import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import 'recent_searches.dart';
import 'search_result_row.dart';

const _kTypeaheadLimit = 8;
const _kDebounce = Duration(milliseconds: 180);
const _kOpenDuration = Duration(milliseconds: 340);

/// Opens the premium search overlay, optionally expanding from [origin] (search icon bounds).
Future<void> showPatternSearch(BuildContext context, {Rect? origin}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search',
    barrierColor: Colors.transparent,
    transitionDuration: _kOpenDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SearchOverlay(
        animation: animation,
        origin: origin,
        onDismiss: () => Navigator.of(dialogContext).maybePop(),
      );
    },
  );
}

/// Animated expand-from-icon search surface (web SearchDialog parity).
class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({
    super.key,
    required this.animation,
    required this.onDismiss,
    this.origin,
  });

  final Animation<double> animation;
  final Rect? origin;
  final VoidCallback onDismiss;

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey();
  Timer? _debounce;
  String _query = '';
  List<String> _recents = const [];
  bool _focusedOnce = false;
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _loadRecents();
    widget.animation.addStatusListener(_onAnimStatus);
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_focusedOnce) {
      _focusedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _loadRecents() async {
    final list = await RecentSearches.load();
    if (mounted) setState(() => _recents = list);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onAnimStatus);
    _curved.dispose();
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
    // Keep clear button responsive without waiting for debounce.
    setState(() {});
  }

  Future<void> _remember(String query) async {
    final next = await RecentSearches.remember(query);
    if (mounted) setState(() => _recents = next);
  }

  Future<void> _clearRecents() async {
    await RecentSearches.clear();
    if (mounted) setState(() => _recents = const []);
  }

  void _applyRecent(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value.trim());
    _remember(value);
  }

  void _clearField() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  /// Pop overlay then land on home board with `q` (+ optional focused pattern).
  void _commitToHome({String? q, String? patternId}) {
    final trimmed = (q ?? _controller.text).trim();
    if (trimmed.isNotEmpty) {
      unawaited(_remember(trimmed));
    }

    final router = GoRouter.of(context);
    final params = <String, String>{};
    if (trimmed.isNotEmpty) params['q'] = trimmed;
    if (patternId != null && patternId.isNotEmpty) params['pattern'] = patternId;

    Navigator.of(context).pop();
    router.go(
      Uri(path: '/', queryParameters: params.isEmpty ? null : params).toString(),
    );
  }

  Rect _startRect(Size size, EdgeInsets padding) {
    final origin = widget.origin;
    if (origin != null && origin.width > 0 && origin.height > 0) {
      return origin;
    }
    // Fallback: top-right circle roughly matching the AppBar search button.
    return Rect.fromCenter(
      center: Offset(size.width - 40, padding.top + 28),
      width: 36,
      height: 36,
    );
  }

  Rect _endRect(Size size, EdgeInsets padding, EdgeInsets viewInsets) {
    const inset = 10.0;
    final top = padding.top + inset;
    final bottom = viewInsets.bottom + inset;
    return Rect.fromLTRB(
      inset,
      top,
      size.width - inset,
      size.height - bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final start = _startRect(size, padding);
    final end = _endRect(size, padding, viewInsets);

    final patternsAsync = _query.isEmpty
        ? const AsyncValue<PatternsPage>.data(
            PatternsPage(patterns: [], hasMore: false, nextOffset: null),
          )
        : ref.watch(patternsProvider(PatternQuery(q: _query)));

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final t = _curved.value.clamp(0.0, 1.0);
        final rect = Rect.lerp(start, end, t)!;
        final radius = BorderRadius.circular(lerpDouble(18, 22, t) ?? 20);
        final contentOpacity = Curves.easeOut.transform(((t - 0.18) / 0.55).clamp(0.0, 1.0));

        return Stack(
          fit: StackFit.expand,
          children: [
            // Scrim + blur
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
                  child: ColoredBox(
                    color: AppColors.foreground.withValues(alpha: 0.45 * t),
                  ),
                ),
              ),
            ),
            // Expanding panel
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Material(
                color: AppColors.card,
                elevation: 16 * t,
                shadowColor: AppColors.accent.withValues(alpha: 0.35),
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Opacity(
                  opacity: contentOpacity,
                  child: _SearchPanel(
                    controller: _controller,
                    focusNode: _focusNode,
                    fieldKey: _fieldKey,
                    query: _query,
                    recents: _recents,
                    patternsAsync: patternsAsync,
                    onChanged: _onChanged,
                    onClearField: _clearField,
                    onClose: widget.onDismiss,
                    onSubmit: () => _commitToHome(),
                    onApplyRecent: _applyRecent,
                    onClearRecents: _clearRecents,
                    onSeeAll: () => _commitToHome(),
                    onResultTap: (pattern) =>
                        _commitToHome(q: _query.isNotEmpty ? _query : pattern.title, patternId: pattern.id),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fullscreen search body shared by overlay + `/search` route.
class SearchExperience extends ConsumerStatefulWidget {
  const SearchExperience({
    super.key,
    this.onClose,
    this.autofocus = true,
  });

  final VoidCallback? onClose;
  final bool autofocus;

  @override
  ConsumerState<SearchExperience> createState() => _SearchExperienceState();
}

class _SearchExperienceState extends ConsumerState<SearchExperience> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<String> _recents = const [];

  @override
  void initState() {
    super.initState();
    _loadRecents();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _loadRecents() async {
    final list = await RecentSearches.load();
    if (mounted) setState(() => _recents = list);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
    setState(() {});
  }

  Future<void> _remember(String query) async {
    final next = await RecentSearches.remember(query);
    if (mounted) setState(() => _recents = next);
  }

  Future<void> _clearRecents() async {
    await RecentSearches.clear();
    if (mounted) setState(() => _recents = const []);
  }

  void _applyRecent(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value.trim());
    _remember(value);
  }

  void _clearField() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _commitToHome({String? q, String? patternId}) {
    final trimmed = (q ?? _controller.text).trim();
    if (trimmed.isNotEmpty) {
      unawaited(_remember(trimmed));
    }

    final router = GoRouter.of(context);
    final params = <String, String>{};
    if (trimmed.isNotEmpty) params['q'] = trimmed;
    if (patternId != null && patternId.isNotEmpty) params['pattern'] = patternId;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    router.go(
      Uri(path: '/', queryParameters: params.isEmpty ? null : params).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patternsAsync = _query.isEmpty
        ? const AsyncValue<PatternsPage>.data(
            PatternsPage(patterns: [], hasMore: false, nextOffset: null),
          )
        : ref.watch(patternsProvider(PatternQuery(q: _query)));

    return Material(
      color: AppColors.card,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: _SearchPanel(
            controller: _controller,
            focusNode: _focusNode,
            query: _query,
            recents: _recents,
            patternsAsync: patternsAsync,
            onChanged: _onChanged,
            onClearField: _clearField,
            onClose: widget.onClose ?? () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
            onSubmit: () => _commitToHome(),
            onApplyRecent: _applyRecent,
            onClearRecents: _clearRecents,
            onSeeAll: () => _commitToHome(),
            onResultTap: (pattern) =>
                _commitToHome(q: _query.isNotEmpty ? _query : pattern.title, patternId: pattern.id),
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.recents,
    required this.patternsAsync,
    required this.onChanged,
    required this.onClearField,
    required this.onClose,
    required this.onSubmit,
    required this.onApplyRecent,
    required this.onClearRecents,
    required this.onSeeAll,
    required this.onResultTap,
    this.fieldKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey? fieldKey;
  final String query;
  final List<String> recents;
  final AsyncValue<PatternsPage> patternsAsync;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearField;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final ValueChanged<String> onApplyRecent;
  final VoidCallback onClearRecents;
  final VoidCallback onSeeAll;
  final ValueChanged<PatternCard> onResultTap;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  key: fieldKey,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search_rounded, size: 22, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          textInputAction: TextInputAction.search,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.foreground,
                              ),
                          // Override theme InputDecorationTheme — its focusedBorder
                          // is a 2px accent outline that shows as a dark purple ring.
                          decoration: const InputDecoration(
                            hintText: 'Search patterns or designers',
                            hintStyle: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: onChanged,
                          onSubmitted: (_) => onSubmit(),
                        ),
                      ),
                      if (hasText)
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: onClearField,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                icon: const Icon(Icons.close_rounded, color: AppColors.accent),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: query.isEmpty
              ? _RecentsBody(
                  recents: recents,
                  onApply: onApplyRecent,
                  onClearAll: onClearRecents,
                )
              : patternsAsync.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    children: const [
                      SearchResultRowSkeleton(),
                      SearchResultRowSkeleton(),
                      SearchResultRowSkeleton(),
                      SearchResultRowSkeleton(),
                    ],
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not search\n$e',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),
                  data: (page) {
                    final results = page.patterns.take(_kTypeaheadLimit).toList();
                    if (results.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 36, color: AppColors.muted.withValues(alpha: 0.7)),
                              const SizedBox(height: 12),
                              Text(
                                'No results for “$query”',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                      children: [
                        for (var i = 0; i < results.length; i++) ...[
                          SearchResultRow(
                            pattern: results[i],
                            query: query,
                            onTap: () => onResultTap(results[i]),
                          ).animateSlideIn(i),
                          if (i < results.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Divider(height: 1, color: AppColors.border),
                            ),
                        ],
                        const SizedBox(height: 8),
                        _SeeAllButton(query: query, onTap: onSeeAll),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RecentsBody extends StatelessWidget {
  const _RecentsBody({
    required this.recents,
    required this.onApply,
    required this.onClearAll,
  });

  final List<String> recents;
  final ValueChanged<String> onApply;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Search by pattern title or designer name',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(40, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        for (final recent in recents)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            minVerticalPadding: 10,
            leading: const Icon(Icons.history_rounded, color: AppColors.muted, size: 22),
            title: Text(
              recent,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            onTap: () => onApply(recent),
          ),
      ],
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'See all results for “$query”',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget animateSlideIn(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + (index * 28).clamp(0, 160)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: this,
    );
  }
}
