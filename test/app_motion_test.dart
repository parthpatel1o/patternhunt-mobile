import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/theme/app_motion.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

double _animatedScaleOf(WidgetTester tester, Finder child) {
  final scale = tester.widget<AnimatedScale>(
    find.ancestor(of: child, matching: find.byType(AnimatedScale)).first,
  );
  return scale.scale;
}

double _scaleOf(WidgetTester tester, Finder child) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: child, matching: find.byType(Transform)).first,
  );
  return transform.transform.getMaxScaleOnAxis();
}

void main() {
  group('AppPressable', () {
    testWidgets('compresses on press and settles back on release', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AppPressable(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 40, key: Key('body')),
          ),
        ),
      );

      final body = find.byKey(const Key('body'));
      expect(_animatedScaleOf(tester, body), closeTo(1.0, 0.001));

      final gesture = await tester.startGesture(tester.getCenter(body));
      await tester.pump();
      expect(_animatedScaleOf(tester, body), closeTo(AppMotion.pressScale, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_animatedScaleOf(tester, body), closeTo(1.0, 0.001));
      expect(taps, 1);
    });

    testWidgets('stays flat when reduced motion is on but still taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AppPressable(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 40, key: Key('body')),
          ),
          reduceMotion: true,
        ),
      );

      final body = find.byKey(const Key('body'));
      final gesture = await tester.startGesture(tester.getCenter(body));
      await tester.pump();
      expect(_animatedScaleOf(tester, body), closeTo(1.0, 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('AppEnter', () {
    testWidgets('fades in once and ends fully opaque', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppEnter(
            rise: 4,
            child: SizedBox(width: 50, height: 50, key: Key('body')),
          ),
        ),
      );

      Opacity opacity() => tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity().opacity, lessThan(0.2));

      await tester.pumpAndSettle();
      expect(opacity().opacity, closeTo(1.0, 0.001));
    });

    testWidgets('renders the child directly under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppEnter(
            rise: 4,
            child: SizedBox(width: 50, height: 50, key: Key('body')),
          ),
          reduceMotion: true,
        ),
      );

      expect(find.byType(Opacity), findsNothing);
      expect(find.byKey(const Key('body')), findsOneWidget);
    });
  });

  group('AppPop', () {
    testWidgets('overshoots when the trigger changes, then returns to 1', (
      tester,
    ) async {
      Widget build(int trigger) => _wrap(
        AppPop(
          trigger: trigger,
          child: const SizedBox(width: 24, height: 24, key: Key('icon')),
        ),
      );

      await tester.pumpWidget(build(0));
      final icon = find.byKey(const Key('icon'));
      // Nothing animates on first build.
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, icon), closeTo(1.0, 0.001));

      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(_scaleOf(tester, icon), greaterThan(1.05));

      await tester.pumpAndSettle();
      expect(_scaleOf(tester, icon), closeTo(1.0, 0.001));
    });

    testWidgets('does not pop under reduced motion', (tester) async {
      Widget build(int trigger) => _wrap(
        AppPop(
          trigger: trigger,
          child: const SizedBox(width: 24, height: 24, key: Key('icon')),
        ),
        reduceMotion: true,
      );

      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(_scaleOf(tester, find.byKey(const Key('icon'))), closeTo(1.0, 0.001));
    });
  });
}
