import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/utils/slugify.dart';

void main() {
  test('matches the API creator slug for long designer names', () {
    expect(
      slugify("Who's Your Granny Creations (whosyourminicreations)"),
      'who-s-your-granny-creations-whosyourminicreation',
    );
  });
}
