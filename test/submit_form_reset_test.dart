import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/features/submit/submit_screen.dart';
import 'package:patternhunt_mobile/shared/widgets/pattern_option_chip.dart';

class _LocalUploads extends HttpOverrides {}

class _SubmitApi extends ApiClient {
  _SubmitApi(this.uploadUrl, this.fail);
  final String uploadUrl;
  final bool fail;
  Map<String, dynamic>? submitted;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    String? accessToken,
  }) async {
    if (path == '/patterns/upload-urls') {
      return {
        'patternId': 'new-pattern',
        'images': [
          {
            'uploadUrl': uploadUrl,
            'key': 'cover.jpg',
            'contentType': 'image/jpeg',
          },
        ],
      };
    }
    submitted = Map<String, dynamic>.from(data as Map);
    if (fail) throw ApiException('Could not publish. Try again.');
    return {'patternId': 'new-pattern'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConstants.load);
  for (final fail in [false, true]) {
    testWidgets(
      'submission ${fail ? 'failure preserves' : 'success resets'} the retained form',
      (tester) async {
        final directory = await tester.runAsync(
          () => Directory.systemTemp.createTemp('submit-reset-'),
        );
        addTearDown(() => directory!.delete(recursive: true));
        final cover = File('${directory!.path}/cover.png');
        await tester.runAsync(
          () => cover.writeAsBytes(
            img.encodePng(img.Image(width: 32, height: 32)),
          ),
        );
        final server = await tester.runAsync(
          () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        );
        addTearDown(() => server!.close(force: true));
        await tester.runAsync(() async {
          server!.listen((request) async {
            await request.drain<void>();
            request.response.statusCode = HttpStatus.noContent;
            await request.response.close();
          });
        });
        final api = _SubmitApi('http://127.0.0.1:${server!.port}/upload', fail);
        const picker = MethodChannel('plugins.flutter.io/image_picker');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(picker, (_) async => [cover.path]);
        addTearDown(() => messenger.setMockMethodCallHandler(picker, null));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 2000);
        addTearDown(tester.view.reset);
        final router = GoRouter(
          initialLocation: '/submit',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => Scaffold(body: shell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (_, _) => const Text('Rank board'),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/submit',
                      builder: (_, _) => const SubmitScreen(),
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
            overrides: [
              sessionProvider.overrideWithValue(null),
              apiClientProvider.overrideWithValue(api),
              profileProvider.overrideWith(
                (_) async => const UserProfile(
                  id: 'designer',
                  role: 'designer',
                  isPatternDesigner: true,
                  displayName: 'Studio',
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.hintText == 'Tiny frog plushie',
        );
        final url = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'https://',
        );
        await tester.enterText(title, 'New test pattern');
        await tester.enterText(url, 'https://example.com/pattern');
        await tester.tap(find.text('Free'));
        final category = AppConstants.instance.categories.last;
        await tester.tap(find.text(category.name));
        await tester.runAsync(() async {
          await tester.tap(find.text('Add photos'));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
        expect(find.text('Cover'), findsOneWidget);
        await tester.ensureVisible(find.text('Publish pattern'));
        final publish = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Publish pattern'),
        );
        await tester.runAsync(
          () => HttpOverrides.runWithHttpOverrides(() async {
            publish.onPressed!();
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (api.submitted == null && DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }, _LocalUploads()),
        );
        await tester.pumpAndSettle();
        expect(api.submitted?['categorySlug'], category.slug);
        expect(api.submitted?['isFree'], isTrue);
        if (!fail) {
          expect(
            router
                .routeInformationProvider
                .value
                .uri
                .queryParameters['category'],
            category.slug,
          );
          expect(
            router
                .routeInformationProvider
                .value
                .uri
                .queryParameters['pattern'],
            'new-pattern',
          );
          router.go('/submit');
          await tester.pumpAndSettle();
        }
        expect(
          tester.widget<TextField>(title).controller!.text,
          fail ? 'New test pattern' : '',
        );
        expect(
          tester.widget<TextField>(url).controller!.text,
          fail ? 'https://example.com/pattern' : '',
        );
        expect(find.text('Cover'), fail ? findsOneWidget : findsNothing);
        final paid = tester.widget<PatternOptionChip>(
          find.widgetWithText(PatternOptionChip, 'Paid'),
        );
        expect(paid.selected, !fail);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
