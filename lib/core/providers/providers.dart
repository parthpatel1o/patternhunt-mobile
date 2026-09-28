import 'dart:async';

import 'package:flutter/foundation.dart';
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

final authenticatedProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider) != null,
);

/// Incremented when the user returns to the Home tab so its retained board
/// reloads in server order.
final homeReturnRefreshProvider = StateProvider<int>((ref) => 0);

/// Local mirror of the server's most recently used rank-board category. It
/// lets Home and Hunt agree immediately while the background PATCH completes.
final rememberedRankBoardCategoryProvider = StateProvider<String?>((ref) {
  ref.watch(sessionProvider);
  return null;
});

String preferredRankBoardCategory({
  String? rememberedCategory,
  String? profileCategory,
  required String fallback,
}) {
  return rememberedCategory ?? profileCategory ?? fallback;
}

void rememberRankBoardCategory(WidgetRef ref, String categorySlug) {
  if (ref.read(sessionProvider) == null) return;
  ref.read(rememberedRankBoardCategoryProvider.notifier).state = categorySlug;
  unawaited(
    ref
        .read(apiClientProvider)
        .updateRankBoardCategory(categorySlug)
        .catchError((_) {}),
  );
}

/// The authenticated, per-pattern state returned by `/me/pattern-state`.
/// A missing entry means we have not reconciled that pattern yet, so callers
/// should continue to use the values supplied with the pattern itself.
class PersonalPatternState {
  const PersonalPatternState({required this.voted, required this.saved});

  final bool voted;
  final bool saved;

  PersonalPatternState copyWith({bool? voted, bool? saved}) =>
      PersonalPatternState(
        voted: voted ?? this.voted,
        saved: saved ?? this.saved,
      );

  factory PersonalPatternState.fromJson(Map<dynamic, dynamic> json) =>
      PersonalPatternState(
        voted: json['voted'] as bool? ?? false,
        saved: json['saved'] as bool? ?? false,
      );
}

/// Keeps personal fields fresh without making collection loading depend on a
/// second request. Each local mutation receives a generation; a reconciliation
/// response captured before that generation is deliberately ignored.
class PersonalStateNotifier
    extends StateNotifier<Map<String, PersonalPatternState>> {
  PersonalStateNotifier(this.ref) : super(const {});

  final Ref ref;
  // Keep visible IDs across account changes so an already mounted board can
  // reconcile for the new account without requiring a manual refresh.
  final Set<String> _knownIds = <String>{};
  final Map<String, int> _generations = <String, int>{};
  String? _accountId;
  int _sessionGeneration = 0;

  /// Personal state is valid only for the account that loaded it. Clear it
  /// before another account can render, and invalidate any reads already in
  /// flight so their responses cannot repopulate it afterwards.
  void updateAccount(Session? session) {
    updateAccountId(session?.user.id);
  }

  @visibleForTesting
  void updateAccountId(String? nextAccountId) {
    if (_accountId == nextAccountId) return;
    _accountId = nextAccountId;
    _sessionGeneration++;
    _generations.clear();
    state = const {};
  }

  void registerPatternIds(Iterable<String> patternIds) {
    final ids = patternIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    _knownIds.addAll(ids);
    if (ref.read(authenticatedProvider)) {
      // Intentionally unawaited: reconciliation must never block a board.
      unawaited(reconcile(ids));
    }
  }

  Future<void> reconcileLoaded() => reconcile(_knownIds);

  Future<void> reconcile(Iterable<String> patternIds) async {
    if (!ref.read(authenticatedProvider)) return;
    final accountIdAtRequest = _accountId;
    final sessionGenerationAtRequest = _sessionGeneration;
    final ids = patternIds.where((id) => id.isNotEmpty).toSet().toList();
    for (var start = 0; start < ids.length; start += 100) {
      // The API accepts at most 100 IDs per call.
      final chunk = ids.sublist(start, (start + 100).clamp(0, ids.length));
      final generationsAtRequest = <String, int>{
        for (final id in chunk) id: _generations[id] ?? 0,
      };
      try {
        final response = await ref
            .read(apiClientProvider)
            .post('/me/pattern-state', data: {'patternIds': chunk});
        if (_accountId != accountIdAtRequest ||
            _sessionGeneration != sessionGenerationAtRequest ||
            !ref.read(authenticatedProvider)) {
          return;
        }
        var next = state;
        var changed = false;
        for (final id in chunk) {
          // Do not let an older read overwrite a newer optimistic interaction.
          if ((_generations[id] ?? 0) != generationsAtRequest[id]) continue;
          final raw = response[id];
          if (raw is! Map) continue;
          final incoming = PersonalPatternState.fromJson(raw);
          if (next[id] != incoming) {
            next = {...next, id: incoming};
            changed = true;
          }
        }
        if (changed) state = next;
      } catch (_) {
        // This is best-effort data. Existing card values remain usable.
      }
    }
  }

  int optimisticallySetVote(String id, bool voted, {required bool saved}) {
    final generation = (_generations[id] ?? 0) + 1;
    _generations[id] = generation;
    state = {...state, id: PersonalPatternState(voted: voted, saved: saved)};
    return generation;
  }

  int optimisticallySetSaved(String id, bool saved, {required bool voted}) {
    final generation = (_generations[id] ?? 0) + 1;
    _generations[id] = generation;
    state = {...state, id: PersonalPatternState(voted: voted, saved: saved)};
    return generation;
  }

  void confirmVote(String id, int generation, bool voted, int voteCount) {
    if (_generations[id] != generation) return;
    final current = state[id];
    state = {
      ...state,
      id: PersonalPatternState(voted: voted, saved: current?.saved ?? false),
    };
  }

  void rollbackVote(
    String id,
    int generation,
    bool voted, {
    required bool saved,
  }) {
    if (_generations[id] != generation) return;
    _generations[id] = generation + 1;
    state = {...state, id: PersonalPatternState(voted: voted, saved: saved)};
  }

  void confirmSaved(String id, int generation, bool saved) {
    if (_generations[id] != generation) return;
    final current = state[id];
    state = {
      ...state,
      id: PersonalPatternState(voted: current?.voted ?? false, saved: saved),
    };
  }

  void rollbackSaved(
    String id,
    int generation,
    bool saved, {
    required bool voted,
  }) {
    if (_generations[id] != generation) return;
    _generations[id] = generation + 1;
    state = {...state, id: PersonalPatternState(voted: voted, saved: saved)};
  }
}

final personalStateProvider =
    StateNotifierProvider<
      PersonalStateNotifier,
      Map<String, PersonalPatternState>
    >((ref) {
      final notifier = PersonalStateNotifier(ref);
      ref.listen<Session?>(sessionProvider, (previous, next) {
        notifier.updateAccount(next);
        if (next != null) unawaited(notifier.reconcileLoaded());
      });
      notifier.updateAccount(ref.read(sessionProvider));
      return notifier;
    });

final personalPatternStateProvider =
    Provider.family<PersonalPatternState?, String>(
      (ref, patternId) => ref.watch(
        personalStateProvider.select((states) => states[patternId]),
      ),
    );

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
  const PatternQuery({
    this.category,
    this.period = 'all',
    this.q,
    this.freeOnly = false,
  });

  final String? category;
  final String period;
  final String? q;

  /// Match web `freeOnly` → query param `free=1`.
  final bool freeOnly;

  Map<String, dynamic> toQuery({int offset = 0}) {
    final map = <String, dynamic>{
      // The API owns launch-window eligibility and ranks those results by
      // all-time vote totals; the client must not re-filter them.
      'period': period,
      // Always send category so "all" is not treated as the API default (amigurumi).
      'category': (category == null || category == 'all') ? 'all' : category,
      'offset': offset,
      'limit': AppConstants.instance.scoreboardPageSize,
    };
    if (q != null && q!.isNotEmpty) map['q'] = q;
    if (freeOnly) map['free'] = '1';
    return map;
  }

  @override
  bool operator ==(Object other) =>
      other is PatternQuery &&
      other.category == category &&
      other.period == period &&
      other.q == q &&
      other.freeOnly == freeOnly;

  @override
  int get hashCode => Object.hash(category, period, q, freeOnly);
}

class PatternsNotifier extends FamilyAsyncNotifier<PatternsPage, PatternQuery> {
  @override
  Future<PatternsPage> build(PatternQuery query) {
    // Pattern payloads include viewer-specific voted/saved fields.
    ref.watch(sessionProvider.select((session) => session?.user.id));
    return _fetch(query, offset: 0);
  }

  Future<PatternsPage> _fetch(PatternQuery query, {required int offset}) async {
    final api = ref.read(apiClientProvider);
    final page = await api.getData(
      '/patterns',
      query: query.toQuery(offset: offset),
      map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
    );
    ref
        .read(personalStateProvider.notifier)
        .registerPatternIds(page.patterns.map((pattern) => pattern.id));
    return page;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMore ||
        current.nextOffset == null ||
        current.loadingMore) {
      return;
    }

    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final next = await _fetch(arg, offset: current.nextOffset!);
      state = AsyncData(appendPatternPage(current, next));
    } catch (_) {
      // Keep the existing board intact and expose a retryable pagination state.
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }

  /// Update the vote in place. The board computes new badge ranks without
  /// moving cards until the next server refresh.
  void applyVote(
    String patternId, {
    required bool voted,
    required int voteCount,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      applyRankBoardVote(
        current,
        patternId,
        voted: voted,
        voteCount: voteCount,
      ),
    );
  }
}

PatternsPage applyRankBoardVote(
  PatternsPage page,
  String patternId, {
  required bool voted,
  required int voteCount,
}) {
  return page.copyWith(
    patterns: [
      for (final pattern in page.patterns)
        if (pattern.id == patternId)
          pattern.copyWith(voted: voted, voteCount: voteCount)
        else
          pattern,
    ],
  );
}

/// Resolves a badge rank for the interactive rank board.
///
/// Free-only hides paid entries, so API ranks keep the meaningful gaps from
/// the full board.
int resolveRankBoardRank({
  required int rankOffset,
  required int index,
  required bool freeOnly,
  int? allTimeRank,
}) {
  final listRank = rankOffset + index + 1;
  return freeOnly ? allTimeRank ?? listRank : listRank;
}

/// Reassigns the visible rank slots by current vote totals without changing
/// the order of [page.patterns]. Server ranks and order return on refresh.
Map<String, int> rankBoardBadges(PatternsPage page, {required bool freeOnly}) {
  final patterns = page.patterns;
  final rankSlots = [
    for (var index = 0; index < patterns.length; index++)
      resolveRankBoardRank(
        rankOffset: page.rankOffset,
        index: index,
        freeOnly: freeOnly,
        allTimeRank: patterns[index].allTimeRank,
      ),
  ];
  if (freeOnly) rankSlots.sort();

  final rankedIndices = List<int>.generate(patterns.length, (index) => index);
  rankedIndices.sort((a, b) {
    final first = patterns[a];
    final second = patterns[b];
    final byVotes = second.voteCount.compareTo(first.voteCount);
    if (byVotes != 0) return byVotes;
    final firstCreated =
        DateTime.tryParse(first.createdAt)?.millisecondsSinceEpoch ?? 0;
    final secondCreated =
        DateTime.tryParse(second.createdAt)?.millisecondsSinceEpoch ?? 0;
    final byDate = secondCreated.compareTo(firstCreated);
    return byDate != 0 ? byDate : a.compareTo(b);
  });

  return {
    for (var rankIndex = 0; rankIndex < rankedIndices.length; rankIndex++)
      patterns[rankedIndices[rankIndex]].id: rankSlots[rankIndex],
  };
}

/// Produces the contiguous, top-of-board list used for a focused pattern.
/// The current API returns this in one response; the old API fallback builds
/// it from successive downward pages. Rank badges must always begin at #1.
PatternsPage combineFocusedBoardPages(Iterable<PatternsPage> pages) {
  final combined = <PatternCard>[];
  final seen = <String>{};
  PatternsPage? last;
  for (final page in pages) {
    last = page;
    for (final pattern in page.patterns) {
      if (seen.add(pattern.id)) combined.add(pattern);
    }
  }
  if (last == null) {
    return const PatternsPage(patterns: [], hasMore: false, nextOffset: null);
  }
  return PatternsPage(
    patterns: combined,
    hasMore: last.hasMore,
    nextOffset: last.nextOffset,
    rankOffset: 0,
  );
}

/// Adds only newly encountered patterns for downward focused-board paging.
PatternsPage appendFocusedBoardPage(PatternsPage current, PatternsPage next) {
  return combineFocusedBoardPages([current, next]);
}

/// Appends a standard pagination page without repeating an item already shown.
PatternsPage appendPatternPage(PatternsPage current, PatternsPage next) {
  final seen = current.patterns.map((pattern) => pattern.id).toSet();
  final appended = next.patterns.where((pattern) => seen.add(pattern.id));
  return PatternsPage(
    patterns: [...current.patterns, ...appended],
    hasMore: next.hasMore,
    nextOffset: next.nextOffset,
    rankOffset: current.rankOffset,
  );
}

final patternsProvider =
    AsyncNotifierProvider.family<PatternsNotifier, PatternsPage, PatternQuery>(
      PatternsNotifier.new,
    );

final patternDetailProvider = FutureProvider.family<PatternCard, String>((
  ref,
  id,
) async {
  ref.watch(sessionProvider.select((session) => session?.user.id));
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

class MyUpvotesNotifier extends AsyncNotifier<PatternsPage> {
  final Map<String, (PatternCard pattern, int index)> _optimisticallyRemoved =
      {};

  @override
  Future<PatternsPage> build() async {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const PatternsPage(patterns: [], hasMore: false, nextOffset: null);
    }
    final api = ref.read(apiClientProvider);
    return api.getData(
      '/me/upvotes',
      map: (json) {
        if (json is Map<String, dynamic>) return PatternsPage.fromJson(json);
        final items = json is Map ? json['patterns'] ?? json['items'] : json;
        return PatternsPage(
          patterns: (items as List<dynamic>? ?? const [])
              .map((item) => PatternCard.fromJson(item as Map<String, dynamic>))
              .toList(),
          hasMore: false,
          nextOffset: null,
        );
      },
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

    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );
    try {
      final api = ref.read(apiClientProvider);
      final next = await api.getData(
        '/me/upvotes',
        query: {'offset': current.nextOffset},
        map: (json) => PatternsPage.fromJson(json as Map<String, dynamic>),
      );
      state = AsyncData(appendPatternPage(current, next));
    } catch (_) {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }

  /// PatternCardWidget reports both its optimistic mutation and any rollback.
  /// Preserve the original index so API ordering by upvote time stays intact.
  void applyVote(String patternId, bool voted, int voteCount) {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.patterns.indexWhere(
      (pattern) => pattern.id == patternId,
    );
    if (!voted && index >= 0) {
      _optimisticallyRemoved[patternId] = (current.patterns[index], index);
      state = AsyncData(
        current.copyWith(
          patterns: removeUpvotedPattern(current.patterns, patternId),
        ),
      );
      return;
    }
    final removed = _optimisticallyRemoved.remove(patternId);
    if (voted && removed != null) {
      final restored = removed.$1.copyWith(voted: true, voteCount: voteCount);
      final next = [...current.patterns];
      next.insert(removed.$2.clamp(0, next.length), restored);
      state = AsyncData(current.copyWith(patterns: next));
    }
  }
}

/// Keeps the API's upvote-time order while removing one optimistic unvote.
List<PatternCard> removeUpvotedPattern(
  List<PatternCard> patterns,
  String patternId,
) => patterns.where((pattern) => pattern.id != patternId).toList();

final myUpvotesProvider =
    AsyncNotifierProvider<MyUpvotesNotifier, PatternsPage>(
      MyUpvotesNotifier.new,
    );

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
