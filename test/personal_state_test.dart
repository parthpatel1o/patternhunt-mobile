import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';
import 'package:patternhunt_mobile/core/providers/providers.dart';

class _FakeApiClient extends ApiClient {
  final calls = <Map<String, dynamic>>[];
  final patches = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? response;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    String? accessToken,
  }) {
    calls.add({'path': path, 'data': data, 'query': query});
    return response?.future ?? Future.value(<String, dynamic>{});
  }

  @override
  Future<void> patch(
    String path,
    Map<String, dynamic> data, {
    String? accessToken,
  }) async {
    patches.add({'path': path, 'data': data});
  }
}

ProviderContainer _container(_FakeApiClient api) => ProviderContainer(
  overrides: [
    apiClientProvider.overrideWithValue(api),
    authenticatedProvider.overrideWithValue(true),
  ],
);

void main() {
  test('unvoted pattern upvote sends true without a period', () async {
    final api = _FakeApiClient();

    await api.votePattern('pattern', true);

    expect(api.calls.single['data'], {'voted': true});
    expect(api.calls.single['query'], isNull);
  });

  test('voted pattern removal sends false without a period', () async {
    final api = _FakeApiClient();

    await api.votePattern('pattern', false);

    expect(api.calls.single['data'], {'voted': false});
    expect(api.calls.single['query'], isNull);
  });

  test('Hunt swipe-up request is always an explicit true vote', () async {
    final api = _FakeApiClient();

    // `_upvoteFromSlideUp` calls this API helper with `true`.
    await api.votePattern('hunt-pattern', true);

    expect(api.calls.single['data'], {'voted': true});
    expect(api.calls.single['query'], isNull);
  });

  test('selecting All remembers the explicit all category', () async {
    final api = _FakeApiClient();

    await api.updateRankBoardCategory('all');

    expect(api.patches.single['path'], '/me/rank-board-category');
    expect(api.patches.single['data'], {'categorySlug': 'all'});
  });

  test(
    'stale reconciliation cannot overwrite a newer optimistic vote',
    () async {
      final api = _FakeApiClient()
        ..response = Completer<Map<String, dynamic>>();
      final container = _container(api);
      addTearDown(container.dispose);
      final notifier = container.read(personalStateProvider.notifier);

      notifier.registerPatternIds(['one']);
      final generation = notifier.optimisticallySetVote(
        'one',
        true,
        saved: false,
      );
      api.response!.complete({
        'one': {'voted': false, 'saved': false},
      });
      await Future<void>.delayed(Duration.zero);

      expect(generation, 1);
      expect(container.read(personalStateProvider)['one']!.voted, isTrue);
    },
  );

  test('pattern-state requests are chunked at 100 IDs', () async {
    final api = _FakeApiClient();
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(personalStateProvider.notifier);
    final ids = List.generate(201, (index) => 'pattern-$index');

    await notifier.reconcile(ids);

    expect(api.calls, hasLength(3));
    expect((api.calls[0]['data'] as Map)['patternIds'], hasLength(100));
    expect((api.calls[1]['data'] as Map)['patternIds'], hasLength(100));
    expect((api.calls[2]['data'] as Map)['patternIds'], hasLength(1));
    expect(
      api.calls.every((call) => call['path'] == '/me/pattern-state'),
      isTrue,
    );
  });

  test('logging out clears personal state', () {
    final api = _FakeApiClient();
    final container = _container(api);
    addTearDown(container.dispose);
    final notifier = container.read(personalStateProvider.notifier);

    notifier.updateAccountId('account-a');
    notifier.optimisticallySetVote('one', true, saved: true);
    notifier.updateAccountId(null);

    expect(container.read(personalStateProvider), isEmpty);
  });

  test(
    'an earlier account response cannot repopulate state after logout',
    () async {
      final api = _FakeApiClient()
        ..response = Completer<Map<String, dynamic>>();
      final container = _container(api);
      addTearDown(container.dispose);
      final notifier = container.read(personalStateProvider.notifier);

      notifier.updateAccountId('account-a');
      final pending = notifier.reconcile(['one']);
      notifier.updateAccountId(null);
      api.response!.complete({
        'one': {'voted': true, 'saved': true},
      });
      await pending;

      expect(container.read(personalStateProvider), isEmpty);
    },
  );
}
