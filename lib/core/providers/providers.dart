import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/api_client.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession;
});

final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

final pendingSignupWelcomeProvider = StateProvider<bool>((ref) => false);

final authSignOutProvider = Provider<Future<void> Function()>((ref) {
  return () => Supabase.instance.client.auth.signOut();
});

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/me',
    accessToken: session.accessToken,
    map: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
  );
});

class PatternQuery {
  const PatternQuery({this.category, this.period = 'all', this.q});

  final String? category;
  final String period;
  final String? q;

  Map<String, dynamic> toQuery({int offset = 0}) {
    final map = <String, dynamic>{
      'period': period,
      'offset': offset,
      'limit': AppConstants.instance.scoreboardPageSize,
    };
    if (category != null && category != 'all') map['category'] = category;
    if (q != null && q!.isNotEmpty) map['q'] = q;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      other is PatternQuery && other.category == category && other.period == period && other.q == q;

  @override
  int get hashCode => Object.hash(category, period, q);
}

class PatternsNotifier extends FamilyAsyncNotifier<PatternsPage, PatternQuery> {
  @override
  Future<PatternsPage> build(PatternQuery query) {
    return _fetch(query, offset: 0);
  }

  Future<PatternsPage> _fetch(PatternQuery query, {required int offset}) async {
    final api = ref.read(apiClientProvider);
    return api.getData(
      '/patterns',
      query: query.toQuery(offset: offset),
      map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.nextOffset == null || current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(arg, offset: current.nextOffset!);
      final seen = current.patterns.map((p) => p.id).toSet();
      final appended = next.patterns.where((p) => !seen.contains(p.id)).toList();
      state = AsyncData(
        PatternsPage(
          patterns: [...current.patterns, ...appended],
          hasMore: next.hasMore,
          nextOffset: next.nextOffset,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final patternsProvider =
    AsyncNotifierProvider.family<PatternsNotifier, PatternsPage, PatternQuery>(PatternsNotifier.new);

final patternDetailProvider = FutureProvider.family<PatternCard, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  return api.getData('/patterns/$id', map: (json) => PatternCard.fromJson(json as Map<String, dynamic>));
});

final creatorProvider = FutureProvider.family<CreatorProfile, String>((ref, slug) async {
  final api = ref.watch(apiClientProvider);
  return api.getData('/creators/$slug', map: (json) => CreatorProfile.fromJson(json as Map<String, dynamic>));
});

final boardsProvider = FutureProvider<List<BoardSummary>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/boards',
    accessToken: session.accessToken,
    map: (json) {
      return (json as List<dynamic>).map((e) => BoardSummary.fromJson(e as Map<String, dynamic>)).toList();
    },
  );
});

final boardsWithPatternsProvider = FutureProvider<List<BoardWithPatterns>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/boards',
    query: {'withPatterns': 'true'},
    accessToken: session.accessToken,
    map: (json) {
      return (json as List<dynamic>).map((e) => BoardWithPatterns.fromJson(e as Map<String, dynamic>)).toList();
    },
  );
});

final myPatternsProvider = FutureProvider<List<PatternCard>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/me/patterns',
    accessToken: session.accessToken,
    map: (json) {
      return (json as List<dynamic>).map((e) => PatternCard.fromJson(e as Map<String, dynamic>)).toList();
    },
  );
});

void invalidatePatternSaveState(WidgetRef ref, String patternId) {
  ref.invalidate(patternDetailProvider(patternId));
  ref.invalidate(boardsWithPatternsProvider);
  ref.invalidate(boardsProvider);
  ref.invalidate(patternsProvider);
}
