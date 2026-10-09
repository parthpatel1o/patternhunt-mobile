import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/features/home/home_screen.dart';

void main() {
  testWidgets(
    'initial rank-board failure uses recovery UI, not an empty state',
    (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RankBoardRecovery(onTryAgain: () => retried = true),
          ),
        ),
      );

      expect(find.text('We couldn’t load the rank board'), findsOneWidget);
      expect(
        find.text('Patterns are still there Please try again in a moment'),
        findsOneWidget,
      );
      expect(find.text('Nothing to show'), findsNothing);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    },
  );
}
