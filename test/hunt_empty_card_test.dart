import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_deck_layout.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_empty_card.dart';

void main() {
  for (final scenario in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.4),
    (const Size(768, 1024), 1.0),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets(
      'empty Hunt card fits ${scenario.$1} at text scale ${scenario.$2} and opens filters',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.$1;
        addTearDown(tester.view.reset);
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 54),
                  child: HuntDeckLayout(
                    cards: [
                      HuntEmptyCard(onChangeFilters: () => opened = true),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: const SizedBox(height: 80),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Nothing to hunt here'), findsOneWidget);
        final button = tester.getRect(
          find.widgetWithText(FilledButton, 'Change filters'),
        );
        expect(button.bottom, lessThanOrEqualTo(scenario.$1.height - 80));
        expect(button.height, greaterThanOrEqualTo(48));
        await tester.tap(find.text('Change filters'));
        expect(opened, isTrue);
      },
    );
  }
}
