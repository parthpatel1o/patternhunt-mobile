import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import 'recent_searches.dart';
import 'search_result_row.dart';

const _kTypeaheadLimit = 8;
const _kDebounce = Duration(milliseconds: 180);
const _kOpenDuration = Duration(milliseconds: 400);

/// The route supplies focus isolation and back handling only. All visible motion
/// belongs to the shared geometry below; there is no route-level fade.
Future<void> showPatternSearch(
  BuildContext context, {
  Rect? origin,
  double originScale = 1,
  ValueChanged<double>? onProgress,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlayBox = navigator.overlay!.context.findRenderObject() as RenderBox;
  final localOrigin = origin == null
      ? null
      : Rect.fromPoints(
          overlayBox.globalToLocal(origin.topLeft),
          overlayBox.globalToLocal(origin.bottomRight),
        );
  try {
    await navigator.push<void>(
      RawDialogRoute<void>(
        barrierDismissible: false,
        barrierLabel: 'Search',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        requestFocus: false,
        pageBuilder: (dialogContext, animation, secondaryAnimation) =>
            SearchOverlay(
              origin: localOrigin,
              originScale: originScale,
              onProgress: onProgress,
              onDismiss: () => Navigator.of(dialogContext).pop(),
            ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      ),
    );
  } finally {
    onProgress?.call(0);
  }
}

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({
    super.key,
    required this.onDismiss,
    this.origin,
    this.originScale = 1,
    this.onProgress,
  });

  final Rect? origin;
  final double originScale;
  final VoidCallback onDismiss;
  final ValueChanged<double>? onProgress;

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<String> _recents = const [];
  bool _started = false;
  bool _closing = false;
  double? _closingInset;
  Completer<void>? _keyboardHidden;
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: _kOpenDuration,
    reverseDuration: const Duration(milliseconds: 340),
  )..addListener(_reportProgress);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _motion.duration = Duration.zero;
      _motion.reverseDuration = Duration.zero;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted || _closing) return;
    try {
      await _motion.forward().orCancel;
      // Focus only after the morph has actually painted its final frame.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && !_closing) _focusNode.requestFocus();
    } on TickerCanceled {
      // A back press can reverse an opening search.
    }
  }

  void _reportProgress() => widget.onProgress?.call(_motion.value);

  @override
  void didChangeMetrics() {
    final hidden = View.of(context).viewInsets.bottom == 0;
    if (hidden && _keyboardHidden?.isCompleted == false) {
      _keyboardHidden!.complete();
    }
  }

  Future<void> _dismiss({VoidCallback? afterClose}) async {
    if (_closing) return;
    setState(() {
      _closing = true;
      // Freeze the results viewport while the keyboard retracts. The outer
      // surface and field never depend on keyboard height.
      _closingInset = MediaQuery.viewInsetsOf(context).bottom;
    });
    _debounce?.cancel();
    final keyboardVisible = View.of(context).viewInsets.bottom > 0;
    if (keyboardVisible) _keyboardHidden = Completer<void>();
    _focusNode.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    if (keyboardVisible) {
      // Hardware/floating keyboards may omit the final metrics notification.
      await _keyboardHidden!.future.timeout(
        const Duration(milliseconds: 650),
        onTimeout: () {},
      );
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await _motion
          .animateBack(
            0,
            duration: Duration(
              microseconds:
                  (_motion.reverseDuration!.inMicroseconds * _motion.value)
                      .round(),
            ),
            curve: Curves.easeInOutCubic,
          )
          .orCancel;
      if (!mounted) return;
      widget.onDismiss();
      afterClose?.call();
    } on TickerCanceled {
      // The owning navigator can be disposed during a transition.
    }
  }

  Future<void> _loadRecents() async {
    final list = await RecentSearches.load();
    if (mounted) setState(() => _recents = list);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    if (_keyboardHidden?.isCompleted == false) _keyboardHidden!.complete();
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
    _debounce?.cancel();
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
    if (patternId != null && patternId.isNotEmpty) {
      params['pattern'] = patternId;
    }

    _dismiss(
      afterClose: () => router.go(
        Uri(
          path: '/',
          queryParameters: params.isEmpty ? null : params,
        ).toString(),
      ),
    );
  }

  double _phase(double start, double end) =>
      ((_motion.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final inset = _closingInset ?? MediaQuery.viewInsetsOf(context).bottom;
    final start =
        widget.origin ??
        Rect.fromLTWH(size.width - 52, padding.top + 10, 36, 36);
    final panel = Rect.fromLTRB(
      10,
      padding.top + 10,
      size.width - 10,
      size.height - padding.bottom - 10,
    );
    final field = Rect.fromLTWH(
      panel.left + 68,
      panel.top + 12,
      panel.width - 80,
      48,
    );
    final patternsAsync = _query.isEmpty
        ? const AsyncValue<PatternsPage>.data(
            PatternsPage(patterns: [], hasMore: false, nextOffset: null),
          )
        : ref.watch(patternsProvider(PatternQuery(q: _query)));

    final results = RepaintBoundary(
      child: _SearchPanel(
        showHeader: false,
        controller: _controller,
        focusNode: _focusNode,
        query: _query,
        recents: _recents,
        patternsAsync: patternsAsync,
        onChanged: _onChanged,
        onClearField: _clearField,
        onClose: _dismiss,
        onSubmit: () => _commitToHome(),
        onApplyRecent: _applyRecent,
        onClearRecents: _clearRecents,
        onSeeAll: () => _commitToHome(),
        onResultTap: (pattern) => _commitToHome(
          q: _query.isNotEmpty ? _query : pattern.title,
          patternId: pattern.id,
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _dismiss();
      },
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          // A critically damped settle: fast response, no elastic bounce. All
          // stages are functions of one timeline, so reversal retraces the path.
          final morph = const Cubic(
            0.22,
            0.85,
            0.25,
            1,
          ).transform(_phase(0, .82));
          final reveal = Curves.easeInOutCubic.transform(_phase(.22, 1));
          final text = Curves.easeOut.transform(_phase(.42, .82));
          final controls = Curves.easeOut.transform(_phase(.55, .95));
          final pressScale = _closing
              ? 1.0
              : lerpDouble(
                  widget.originScale,
                  1,
                  Curves.easeOut.transform(_phase(0, .35)),
                )!;
          final pressedStart = Rect.fromCenter(
            center: start.center,
            width: start.width * pressScale,
            height: start.height * pressScale,
          );
          final rect = Rect.lerp(pressedStart, field, morph)!;
          final surface = Rect.lerp(rect, panel, reveal)!;
          final iconCenter = Offset.lerp(
            start.center,
            Offset(field.left + 23, field.center.dy),
            morph,
          )!;
          final iconSize = lerpDouble(20 * pressScale, 22, morph)!;

          return Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: ColoredBox(
                    color: AppColors.foreground.withValues(alpha: .18 * reveal),
                  ),
                ),
                Positioned.fromRect(
                  rect: surface,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(
                        lerpDouble(18, 22, reveal)!,
                      ),
                    ),
                  ),
                ),
                // Lay results out at their final size and reveal by clipping,
                // never squeeze/reflow a list inside the icon-sized surface.
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    panel.left,
                    field.bottom + 8,
                    panel.right,
                    panel.bottom,
                  ),
                  child: ClipRect(
                    clipper: _SearchRevealClipper(
                      surface.shift(-Offset(panel.left, field.bottom + 8)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(22),
                      ),
                      child: Transform.translate(
                        offset: Offset(0, -20 * (1 - reveal)),
                        child: IgnorePointer(
                          ignoring: _closing || _motion.value < 1,
                          child: ExcludeSemantics(
                            excluding: _closing || _motion.value < 1,
                            child: AnimatedPadding(
                              duration: AppMotion.reduced(context)
                                  ? Duration.zero
                                  : AppMotion.base,
                              curve: AppMotion.soft,
                              padding: EdgeInsets.only(
                                bottom: (inset - padding.bottom).clamp(
                                  0.0,
                                  (panel.bottom - field.bottom - 9).clamp(
                                    0.0,
                                    double.infinity,
                                  ),
                                ),
                              ),
                              child: results,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: Container(
                    key: const ValueKey('search-morph-field'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColors.card,
                        AppColors.background,
                        morph,
                      ),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(
                        lerpDouble(start.width / 2, 14, morph)!,
                      ),
                    ),
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: field.width,
                      maxWidth: field.width,
                      minHeight: 48,
                      maxHeight: 48,
                      child: IgnorePointer(
                        ignoring: _closing || _motion.value < 1,
                        child: ExcludeSemantics(
                          excluding: _closing || _motion.value < 1,
                          child: Opacity(
                            opacity: text,
                            child: Transform.translate(
                              offset: Offset(8 * (1 - text), 0),
                              child: _SearchField(
                                controller: _controller,
                                focusNode: _focusNode,
                                onChanged: _onChanged,
                                onSubmit: () => _commitToHome(),
                                onClearField: _clearField,
                                paintChrome: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: iconCenter.dx - iconSize / 2,
                  top: iconCenter.dy - iconSize / 2,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.search,
                      key: const ValueKey('search-shared-icon'),
                      size: iconSize,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                Positioned(
                  left: panel.left + 12,
                  top: field.top + 2,
                  child: IgnorePointer(
                    ignoring: controls < 1 || _closing,
                    child: Opacity(
                      opacity: controls,
                      child: Transform.translate(
                        offset: Offset(12 * (1 - controls), 0),
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: _dismiss,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Clips a fixed-layout results viewport to the same expanding surface.
class _SearchRevealClipper extends CustomClipper<Rect> {
  const _SearchRevealClipper(this.surface);

  final Rect surface;

  @override
  Rect getClip(Size size) {
    final bounds = Offset.zero & size;
    return surface.overlaps(bounds) ? surface.intersect(bounds) : Rect.zero;
  }

  @override
  bool shouldReclip(_SearchRevealClipper oldClipper) =>
      oldClipper.surface != surface;
}

/// Fullscreen search body shared by overlay + `/search` route.
class SearchExperience extends ConsumerStatefulWidget {
  const SearchExperience({super.key, this.onClose, this.autofocus = true});

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
    _debounce?.cancel();
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
    if (patternId != null && patternId.isNotEmpty) {
      params['pattern'] = patternId;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    router.go(
      Uri(
        path: '/',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _SearchPanel(
            controller: _controller,
            focusNode: _focusNode,
            query: _query,
            recents: _recents,
            patternsAsync: patternsAsync,
            onChanged: _onChanged,
            onClearField: _clearField,
            onClose:
                widget.onClose ??
                () {
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
            onResultTap: (pattern) => _commitToHome(
              q: _query.isNotEmpty ? _query : pattern.title,
              patternId: pattern.id,
            ),
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
    this.showHeader = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showHeader;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: onClose,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SearchField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmit: onSubmit,
                    onClearField: onClearField,
                  ),
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
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),
                  data: (page) {
                    final results = page.patterns
                        .take(_kTypeaheadLimit)
                        .toList();
                    if (results.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 36,
                                color: AppColors.muted.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No results for “$query”',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
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
                          ).animateSlideIn(
                            i,
                            reduced: AppMotion.reduced(context),
                          ),
                          if (i < results.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
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
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(40, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Clear all',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        for (final recent in recents)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            minVerticalPadding: 10,
            leading: const Icon(
              Icons.history_rounded,
              color: AppColors.muted,
              size: 22,
            ),
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
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
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
  Widget animateSlideIn(int index, {bool reduced = false}) {
    if (reduced) return this;
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

/// Shared field contents for the morphing nav search and the deep-link screen.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
    required this.onClearField,
    this.paintChrome = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClearField;
  final bool paintChrome;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return Container(
      height: 48,
      decoration: paintChrome
          ? BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            )
          : null,
      child: Row(
        children: [
          const SizedBox(width: 12),
          if (paintChrome)
            const Icon(Icons.search, size: 22, color: AppColors.accent)
          else
            const SizedBox(width: 22),
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
                hintText: 'Search Pattern Hunt',
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
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
