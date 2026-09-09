import 'dart:async';

import '../api/api_client.dart';

/// Shared fire-and-forget analytics that mirrors web API tracking.
///
/// Web PostHog is mostly autocapture; native mobile shares domain analytics
/// through these `/api/v1` endpoints so both clients stay consistent.
class Analytics {
  Analytics._();

  static void trackPatternCta(ApiClient api, String patternId, String kind) {
    unawaited(
      api.post('/patterns/$patternId/cta', data: {'kind': kind}).catchError((_) => <String, dynamic>{}),
    );
  }

  static void trackCreatorView(ApiClient api, String slug) {
    unawaited(
      api.post('/creators/$slug/view').catchError((_) => <String, dynamic>{}),
    );
  }
}
