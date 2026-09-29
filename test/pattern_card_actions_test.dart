import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';
import 'package:patternhunt_mobile/shared/widgets/pattern_card_widget.dart';

class _PdfApi extends ApiClient {
  final requested = <String>[];

  @override
  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async {
    requested.add(path);
    return map({'url': 'https://example.com/uploaded.pdf?signature=test'});
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    String? accessToken,
  }) async => {};
}

PatternCard _pattern({required bool hasPdf, String? patternUrl}) => PatternCard(
  id: 'pattern',
  title: 'A crochet pattern with a longer two-line title',
  slug: 'test-pattern',
  imageUrls: const [],
  designerName: 'Designer',
  patternUrl: patternUrl,
  isFree: true,
  hasPdf: hasPdf,
  voteCount: 12,
  voted: false,
  createdAt: '2026-01-01T00:00:00Z',
  isArchived: false,
  saved: false,
);

Future<void> _pumpCard(
  WidgetTester tester,
  PatternCard pattern, {
  ApiClient? api,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(null),
        if (api != null) apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: PatternCardWidget(
                pattern: pattern,
                rank: 1,
                animateEntrance: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('free PDF with pattern link offers only View', (tester) async {
    await _pumpCard(
      tester,
      _pattern(hasPdf: true, patternUrl: 'https://example.com/pattern'),
    );

    expect(find.text('Download'), findsNothing);
    expect(find.text('View'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('View on a free PDF card opens the uploaded PDF URL', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launched = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final api = _PdfApi();
    await _pumpCard(
      tester,
      _pattern(hasPdf: true, patternUrl: 'https://example.com/pattern'),
      api: api,
    );
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(api.requested, ['/patterns/pattern/pdf']);
    expect(launched, ['https://example.com/uploaded.pdf?signature=test']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pattern link without PDF still offers View', (tester) async {
    await _pumpCard(
      tester,
      _pattern(hasPdf: false, patternUrl: 'https://example.com/pattern'),
    );
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('PDF without a pattern link only offers Download', (
    tester,
  ) async {
    await _pumpCard(tester, _pattern(hasPdf: true));

    expect(find.text('Download'), findsOneWidget);
    expect(find.text('View'), findsNothing);
  });
}
