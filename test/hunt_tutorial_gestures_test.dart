import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyHuntApi extends ApiClient {
  @override
  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async => map({'patterns': [], 'hasMore': false});
}

final _panSurface = find
    .byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanStart != null,
    )
    .first;

Future<void> _swipe(WidgetTester tester, Offset direction) async {
  final surface = tester.element(_panSurface);
  final gesture = await tester.startGesture(tester.getCenter(_panSurface));
  await gesture.moveBy(direction * 30);
  await tester.pump(const Duration(milliseconds: 30));
  // Starting a real swipe must preserve the recognizer that owns this pointer.
  expect(tester.element(_panSurface), same(surface));
  await gesture.moveBy(direction * 190);
  await tester.pump(const Duration(milliseconds: 150));
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('tutorial accepts the first swipe while its hint is moving', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppConstants.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(null),
          apiClientProvider.overrideWithValue(_EmptyHuntApi()),
        ],
        child: const MaterialApp(home: HuntScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('1 of 5'), findsOneWidget);
    await _swipe(tester, const Offset(-1, 0));
    expect(find.text('2 of 5'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await _swipe(tester, const Offset(1, 0));
    expect(find.text('3 of 5'), findsOneWidget);

    final photo = tester.getRect(_panSurface);
    await tester.tapAt(Offset(photo.right - 50, photo.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4 of 5'), findsOneWidget);
    await tester.tapAt(Offset(photo.left + 50, photo.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('5 of 5'), findsOneWidget);
    await _swipe(tester, const Offset(0, -1));
    expect(find.text('5 of 5'), findsNothing);

    // Let the upvote stamp, exit, and tutorial handoff finish before disposal.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
