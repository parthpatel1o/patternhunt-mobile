import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/providers.dart';

/// Removes data that must never be carried from one account on a device to
/// another. Authentication is signed out first, because Supabase also keeps
/// its session in SharedPreferences.
Future<void> signOutAndClearLocalData(WidgetRef ref) async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {
    // Supabase removes the local session before attempting its remote sign-out
    // request. A network failure must not keep data visible on this device.
  } finally {
    await clearStoredLocalData();
    _resetInMemoryAccountData(ref);
  }
}

/// Clears persistent app state and the image caches used to render patterns.
///
/// Keeping this separate makes the storage boundary straightforward to test
/// and ensures all logout entry points use the same cleanup.
Future<void> clearStoredLocalData({bool clearDiskImageCache = true}) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.clear();
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  if (clearDiskImageCache) {
    await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
  }
}

void _resetInMemoryAccountData(WidgetRef ref) {
  ref.read(personalStateProvider.notifier).updateAccount(null);
  ref.read(rememberedRankBoardCategoryProvider.notifier).state = null;
  ref.read(pendingSignupWelcomeProvider.notifier).state = false;
  ref.read(passwordRecoveryProvider.notifier).state = false;

  // These providers can have mounted, account-specific values while the
  // indexed tab shell is retained. Invalidate them before another account
  // gets a chance to render the old response.
  ref.invalidate(profileProvider);
  ref.invalidate(patternsProvider);
  ref.invalidate(patternDetailProvider);
  ref.invalidate(boardsProvider);
  ref.invalidate(boardsWithPatternsProvider);
  ref.invalidate(myPatternsProvider);
  ref.invalidate(myUpvotesProvider);
  ref.invalidate(insightsProvider);
  ref.invalidate(boardSaveOptionsProvider);
}
