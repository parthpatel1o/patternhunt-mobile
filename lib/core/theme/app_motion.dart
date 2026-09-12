import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One curve and three durations, mirroring the web `--ease-soft` / `--dur-*`
/// tokens so both apps feel like a single system.
///
/// Native rule of thumb: platform physics (sheets, route pushes, scroll) stay
/// as Flutter ships them. These tokens are for the motion we add on top —
/// press feedback, the save pop, toasts, and skeleton-to-content dissolves.
class AppMotion {
  const AppMotion._();

  /// Web `--ease-soft: cubic-bezier(0.22, 1, 0.36, 1)`.
  static const soft = Cubic(0.22, 1, 0.36, 1);

  /// Exits are quicker and ease-in so a dismissed surface clears promptly.
  static const exit = Curves.easeInCubic;

  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);

  /// Press depth. Small controls compress a little more than wide surfaces.
  static const pressScaleSmall = 0.94;
  static const pressScale = 0.97;

  /// True when the platform asks for reduced motion. Every animation added on
  /// top of platform physics must honor this.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Sheets and dialogs keep their platform slide/fade — this only retimes them
  /// onto the shared tokens so they match the toast and press feedback.
  static final surface = AnimationStyle(
    duration: base,
    curve: soft,
    reverseDuration: fast,
    reverseCurve: exit,
  );
}

/// Scale-on-press wrapper for controls that should answer the finger.
///
/// Deliberately unopinionated about painting: wrap an existing chip, pill, or
/// circle and it keeps its own ink, border, and shadows.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.haptic = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Depth of the press. 1.0 disables the scale but keeps the gestures.
  final double scale;

  /// Selection click on press down. Reserve for controls that change state.
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setDown(bool down) {
    if (!_enabled || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final scale = _down && _enabled && !reduced ? widget.scale : 1.0;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) {
        _setDown(true);
        if (widget.haptic && _enabled) HapticFeedback.selectionClick();
      },
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: scale,
        // Press down reads instantly; release settles on the soft curve.
        duration: _down ? AppMotion.fast : AppMotion.base,
        curve: _down ? Curves.easeOut : AppMotion.soft,
        child: widget.child,
      ),
    );
  }
}

/// Press scale for controls that keep their own Material ink.
///
/// [builder] receives a callback to hand to `InkWell.onHighlightChanged`, so the
/// ripple still fires and the tap stays with the ink well — wrapping an
/// `InkWell` in a second tap recognizer would lose the gesture arena instead.
class AppPressScale extends StatefulWidget {
  const AppPressScale({
    super.key,
    required this.builder,
    this.scale = AppMotion.pressScale,
  });

  final Widget Function(BuildContext context, ValueChanged<bool> onHighlight)
  builder;
  final double scale;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return AnimatedScale(
      scale: _down && !reduced ? widget.scale : 1.0,
      duration: _down ? AppMotion.fast : AppMotion.base,
      curve: _down ? Curves.easeOut : AppMotion.soft,
      child: widget.builder(context, (down) {
        if (_down == down) return;
        setState(() => _down = down);
      }),
    );
  }
}

/// One-shot fade (and optional rise) for content arriving after a skeleton or
/// an empty first frame. Mirrors web `.enter-fade` / `.enter-rise`.
///
/// Runs once per [key] change — not on every rebuild — so scrolling and filter
/// changes never re-animate content that is already on screen.
class AppEnter extends StatefulWidget {
  const AppEnter({
    super.key,
    required this.child,
    this.duration = AppMotion.base,
    this.rise = 0,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;

  /// Pixels to travel upward while fading in. 0 is a plain dissolve.
  final double rise;
  final Duration delay;

  @override
  State<AppEnter> createState() => _AppEnterState();
}

class _AppEnterState extends State<AppEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.soft,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        final t = _curved.value;
        return Opacity(
          opacity: t,
          child: widget.rise == 0
              ? child
              : Transform.translate(
                  offset: Offset(0, widget.rise * (1 - t)),
                  child: child,
                ),
        );
      },
      child: widget.child,
    );
  }
}

/// Brief scale pop, replayed whenever [trigger] changes. Used on the bookmark
/// icon so a save feels confirmed. Web equivalent: `.save-pop`.
class AppPop extends StatefulWidget {
  const AppPop({
    super.key,
    required this.trigger,
    required this.child,
    this.peak = 1.18,
  });

  /// Bump this to replay the pop. Nothing animates on the first build.
  final Object? trigger;
  final Widget child;
  final double peak;

  @override
  State<AppPop> createState() => _AppPopState();
}

class _AppPopState extends State<AppPop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: widget.peak,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: widget.peak,
        end: 1.0,
      ).chain(CurveTween(curve: AppMotion.soft)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(AppPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && !AppMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
