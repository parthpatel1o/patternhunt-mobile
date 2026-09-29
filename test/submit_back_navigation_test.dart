import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/submit/submit_navigation.dart';
import 'package:patternhunt_mobile/shared/widgets/app_shell.dart';
import 'package:patternhunt_mobile/shared/widgets/submit_invite_card.dart';

Future<GoRouter> _mount(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Center(
                  child: SizedBox(width: 390, child: SubmitInviteCard()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => Center(
                  child: TextButton(
                    onPressed: () => openSubmit(context),
                    child: const Text('Submit from Profile'),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                builder: (context, state) => Center(
                  child: TextButton(
                    onPressed: () => openSubmit(context),
                    child: const Text('Submit from Mine'),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/submit',
                builder: (context, state) =>
                    const Center(child: Text('Submit form')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWithValue(null)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('rank board Submit returns to the exact board location', (
    tester,
  ) async {
    final router = await _mount(tester);
    router.go('/?q=cable%20knit&period=week');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Pattern'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/submit');
    expect(find.text('Submit form'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/?q=cable%20knit&period=week',
    );
    expect(find.text('Submit Pattern'), findsOneWidget);
  });

  testWidgets('Submit returns to Profile or Mine when opened there', (
    tester,
  ) async {
    final router = await _mount(tester);
    for (final (path, label) in [
      ('/profile', 'Submit from Profile'),
      ('/mine', 'Submit from Mine'),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, path);
    }
  });

  testWidgets('direct Submit link falls back to Profile', (tester) async {
    final router = await _mount(tester);
    router.go('/submit');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile');
  });
}
