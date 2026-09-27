import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/auth/designer_display_name.dart';

void main() {
  test('My Patterns designer name follows the requested fallback order', () {
    expect(
      designerDisplayName(
        profileDisplayName: 'Profile designer',
        userMetadata: const {'full_name': 'Metadata designer'},
        email: 'designer@example.com',
      ),
      'Profile designer',
    );
    expect(
      designerDisplayName(
        userMetadata: const {'full_name': 'Metadata designer'},
        email: 'designer@example.com',
      ),
      'Metadata designer',
    );
    expect(
      designerDisplayName(
        userMetadata: const {'name': 'Named designer'},
        email: 'designer@example.com',
      ),
      'Named designer',
    );
    expect(
      designerDisplayName(email: 'designer@example.com'),
      'designer@example.com',
    );
    expect(designerDisplayName(), 'Pattern Hunt designer');
  });
}
