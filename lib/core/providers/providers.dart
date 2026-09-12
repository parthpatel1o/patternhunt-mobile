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
      // Always send category so "all" is not treated as the API default (amigurumi).
      'category': (category == null || category == 'all') ? 'all' : category,
      'offset': offset,
      'limit': AppConstants.instance.scoreboardPageSize,
    };
    if (q != null && q!.isNotEmpty) map['q'] = q;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      other is PatternQuery &&
      other.category == category &&
      other.period == period &&
      other.q == q;

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
    if (current == null ||
        !current.hasMore ||
        current.nextOffset == null ||
        current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(arg, offset: current.nextOffset!);
      final seen = current.patterns.map((p) => p.id).toSet();
      final appended = next.patterns
          .where((p) => !seen.contains(p.id))
          .toList();
      state = AsyncData(
        PatternsPage(
          patterns: [...current.patterns, ...appended],
          hasMore: next.hasMore,
          nextOffset: next.nextOffset,
          rankOffset: current.rankOffset,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Optimistic vote update + re-sort (matches web `PatternGrid.onVoteChange`).
  /// Search results keep relevance order and are not re-sorted.
  void applyVote(
    String patternId, {
    required bool voted,
    required int voteCount,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [
      for (final pattern in current.patterns)
        if (pattern.id == patternId)
          pattern.copyWith(voted: voted, voteCount: voteCount)
        else
          pattern,
    ];
    final isSearch = arg.q != null && arg.q!.isNotEmpty;
    if (!isSearch) {
      sortPatternsByRank(updated);
    }
    state = AsyncData(current.copyWith(patterns: updated));
  }
}

/// Same ordering as web `sortByRank`: votes desc, then newer first.
void sortPatternsByRank(List<PatternCard> patterns) {
  patterns.sort((a, b) {
    if (b.voteCount != a.voteCount) return b.voteCount.compareTo(a.voteCount);
    final aCreated =
        DateTime.tryParse(a.createdAt)?.millisecondsSinceEpoch ?? 0;
    final bCreated =
        DateTime.tryParse(b.createdAt)?.millisecondsSinceEpoch ?? 0;
    return bCreated.compareTo(aCreated);
  });
}

final patternsProvider =
    AsyncNotifierProvider.family<PatternsNotifier, PatternsPage, PatternQuery>(
      PatternsNotifier.new,
    );

final patternDetailProvider = FutureProvider.family<PatternCard, String>((
  ref,
  id,
) async {
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/patterns/$id',
    map: (json) => PatternCard.fromJson(json as Map<String, dynamic>),
  );
});

final creatorProvider = FutureProvider.family<CreatorProfile, String>((
  ref,
  slug,
) async {
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/creators/$slug',
    map: (json) => CreatorProfile.fromJson(json as Map<String, dynamic>),
  );
});

int _defaultBoardFirst(String a, String b) {
  if (a == kDefaultBoardName) return -1;
  if (b == kDefaultBoardName) return 1;
  return 0;
}

final boardsProvider = FutureProvider<List<BoardSummary>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/boards',
    map: (json) {
      final boards = (json as List<dynamic>)
          .map((e) => BoardSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      boards.sort((a, b) => _defaultBoardFirst(a.name, b.name));
      return boards;
    },
  );
});

final boardsWithPatternsProvider = FutureProvider<List<BoardWithPatterns>>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/boards',
    query: {'withPatterns': 'true'},
    map: (json) {
      final groups = (json as List<dynamic>)
          .map((e) => BoardWithPatterns.fromJson(e as Map<String, dynamic>))
          .toList();
      groups.sort((a, b) => _defaultBoardFirst(a.board.name, b.board.name));
      return groups;
    },
  );
});

final myPatternsProvider = FutureProvider<List<PatternCard>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/me/patterns',
    map: (json) {
      return (json as List<dynamic>)
          .map((e) => PatternCard.fromJson(e as Map<String, dynamic>))
          .toList();
    },
  );
});

final insightsProvider = FutureProvider<DesignerInsights>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) throw StateError('Not logged in');
  final api = ref.watch(apiClientProvider);
  return api.getData(
    '/me/insights',
    map: (json) => DesignerInsights.fromJson(json as Map<String, dynamic>),
  );
});

final boardSaveOptionsProvider =
    FutureProvider.family<List<BoardSaveOption>, String>((
      ref,
      patternId,
    ) async {
      final session = ref.watch(sessionProvider);
      if (session == null) return [];
      final api = ref.watch(apiClientProvider);
      return api.getData(
        '/patterns/$patternId/save',
        map: (json) => (json as List<dynamic>)
            .map((e) => BoardSaveOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    });

void prefetchBoardSaveOptions(WidgetRef ref, String patternId) {
  if (ref.read(sessionProvider) == null) return;
  ref.read(boardSaveOptionsProvider(patternId));
}

void invalidatePatternSaveState(WidgetRef ref, String patternId) {
  ref.invalidate(patternDetailProvider(patternId));
  ref.invalidate(boardsWithPatternsProvider);
  ref.invalidate(boardsProvider);
  ref.invalidate(boardSaveOptionsProvider(patternId));
}
