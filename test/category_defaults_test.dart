import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/constants/app_constants.dart';
import 'package:patternhunt_mobile/core/models/models.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rank board defaults to All categories and Past 7 days', () async {
    await AppConstants.load();

    expect(AppConstants.instance.defaultRankBoardCategory, 'all');
    expect(AppConstants.instance.defaultRankBoardPeriod, 'week');
    expect(AppConstants.instance.defaultHuntCategory, 'all');
    expect(kDefaultHuntPeriod, 'all');
  });

  test('profile reads the remembered rank-board category field', () {
    final profile = UserProfile.fromJson({
      'id': 'user-1',
      'isPatternDesigner': false,
      'lastRankBoardCategorySlug': 'wearables',
    });

    expect(profile.lastRankBoardCategorySlug, 'wearables');
  });

  test('remembered category wins for logged-in Rank Board and Hunt', () {
    expect(
      preferredRankBoardCategory(profileCategory: 'wearables', fallback: 'all'),
      'wearables',
    );
    expect(
      preferredRankBoardCategory(
        rememberedCategory: 'all',
        profileCategory: 'wearables',
        fallback: 'all',
      ),
      'all',
    );
  });
}
