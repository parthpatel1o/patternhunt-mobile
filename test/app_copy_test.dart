import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/text/app_copy.dart';

void main() {
  test('service messages follow the app punctuation style', () {
    expect(
      withoutSentenceFullStops('Upload failed. Please try again.'),
      'Upload failed Please try again',
    );
    expect(
      withoutSentenceFullStops('Check your email.\nOpen the link.'),
      'Check your email\nOpen the link',
    );
  });

  test('preserves meaningful dots and other punctuation', () {
    const text =
        'Email hello@example.com or visit https://example.com/v1.2 '
        'to download pattern.pdf (2.5 MB) Loading... Saving… Done!';
    expect(withoutSentenceFullStops(text), text);
  });
}
