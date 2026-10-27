import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/text/app_copy.dart';
import 'package:patternhunt_mobile/shared/widgets/app_snack_bar.dart';
import 'package:patternhunt_mobile/shared/widgets/home_empty_state.dart';

void main() {
  test('single sentences omit their final full stop', () {
    expect(applySentencePunctuation('Upload failed.'), 'Upload failed');
    expect(applySentencePunctuation('Upload failed'), 'Upload failed');
    expect(applySentencePunctuation('Upload failed.  '), 'Upload failed  ');
    expect(applySentencePunctuation(''), '');
  });

  test('multiple sentences retain full stops, including across lines', () {
    expect(
      applySentencePunctuation('Upload failed. Please try again.'),
      'Upload failed. Please try again.',
    );
    expect(
      applySentencePunctuation('Check your email.\nOpen the link.'),
      'Check your email.\nOpen the link.',
    );
    expect(
      applySentencePunctuation('Upload failed. Please try again'),
      'Upload failed. Please try again.',
    );
    expect(
      applySentencePunctuation('Upload failed! Please try again.'),
      'Upload failed! Please try again.',
    );
    expect(
      applySentencePunctuation('Need help? Try again'),
      'Need help? Try again.',
    );
  });

  test('preserves meaningful dots and other punctuation', () {
    const text =
        'Email hello@example.com or visit https://example.com/v1.2 '
        'to download pattern.pdf (2.5 MB) Loading... Saving… Done!';
    expect(applySentencePunctuation(text), text);
    expect(
      applySentencePunctuation('Download pattern.pdf.'),
      'Download pattern.pdf',
    );
    expect(applySentencePunctuation('Loading...'), 'Loading...');
    expect(applySentencePunctuation('Saved!'), 'Saved!');
    expect(applySentencePunctuation('Try again?'), 'Try again?');
  });

  test('API errors follow the sentence-count rule', () {
    expect(ApiException('Upload failed.').message, 'Upload failed');
    expect(
      ApiException('Upload failed. Please try again.').message,
      'Upload failed. Please try again.',
    );
  });

  testWidgets('snack bars apply the rule to messages from any source', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                buildAppSnackBar(message: 'Upload failed. Please try again.'),
              ),
              child: const Text('Show message'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show message'));
    await tester.pumpAndSettle();
    expect(find.text('Upload failed. Please try again.'), findsOneWidget);
  });

  testWidgets('rank board empty-state descriptions punctuate both sentences', (
    tester,
  ) async {
    final cases = [
      (
        const HomeEmptyState(categoryName: 'Scarves'),
        'The rank board is empty in Scarves. Browse everything, or be the first to add one.',
      ),
      (
        const HomeEmptyState(categoryName: 'Scarves', freeOnly: true),
        'Nothing free is on the board in Scarves. Turn off Free only, or browse everything.',
      ),
      (
        const HomeEmptyState(freeOnly: true),
        'Nothing free is on the board right now. Turn off Free only to see paid patterns too.',
      ),
      (
        const HomeEmptyState(searchQuery: 'scarf'),
        'Nothing matched “scarf”. Try a designer name, a shorter word, or check the spelling.',
      ),
      (
        const HomeEmptyState(),
        'No patterns have been published yet. Submit one and it’ll show up here for the community to upvote.',
      ),
    ];
    for (final (widget, description) in cases) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text(description), findsOneWidget);
    }
  });
}
