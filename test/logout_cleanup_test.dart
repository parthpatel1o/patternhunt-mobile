import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/auth/logout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout cleanup removes every value stored on the device', () async {
    SharedPreferences.setMockInitialValues({
      'hunt.run.seed': 'previous-account-run',
      'hunt.pendingViews.v1:previous-account': ['pattern-1'],
      'recent-searches': ['amigurumi'],
      'unrelated-local-value': true,
    });

    await clearStoredLocalData(clearDiskImageCache: false);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
  });
}
