import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/features/hunt/hunt_view_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saves views locally, deduplicates, and sends a single batch at ten views',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final batches = <List<String>>[];
      final queue = HuntViewQueue('me', prefs, (ids) async {
        batches.add(ids);
      });
      for (var i = 0; i < 9; i++) {
        queue.record('pattern-$i');
      }
      queue.record('pattern-0');
      await Future<void>.delayed(Duration.zero);
      expect(batches, isEmpty);
      expect(prefs.getStringList('hunt.pendingViews.v1:me'), hasLength(9));
      queue.record('pattern-9');
      await queue.flush();
      expect(batches, hasLength(1));
      expect(batches.single, hasLength(10));
      expect(queue.pendingIds, isEmpty);
    },
  );

  testWidgets('flushes at 15 seconds and sends remaining views on exit', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final batches = <List<String>>[];
    final queue = HuntViewQueue('me', prefs, (ids) async {
      batches.add(ids);
    });
    queue.start();
    queue.record('one');
    await tester.pump(const Duration(milliseconds: 14999));
    expect(batches, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(batches, [
      ['one'],
    ]);
    queue.record('two');
    await queue.stop();
    expect(batches.last, ['two']);
  });

  test('failed batches survive reopening without crossing accounts', () async {
    final prefs = await SharedPreferences.getInstance();
    final queue = HuntViewQueue('me', prefs, (ids) async {
      throw Exception('offline');
    });
    queue.record('one');
    await queue.stop();
    expect(prefs.getStringList('hunt.pendingViews.v1:me'), ['one']);
    final other = HuntViewQueue('other', prefs, (ids) async {});
    expect(other.pendingIds, isEmpty);
    final batches = <List<String>>[];
    final reopened = HuntViewQueue('me', prefs, (ids) async {
      batches.add(ids);
    });
    await reopened.flush();
    expect(batches, [
      ['one'],
    ]);
    expect(reopened.pendingIds, isEmpty);
  });

  test(
    'new views survive acknowledgement of an older in-flight batch',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final response = Completer<void>();
      final batches = <List<String>>[];
      final queue = HuntViewQueue('me', prefs, (ids) async {
        batches.add(ids);
        if (batches.length == 1) await response.future;
      });
      queue.record('one');
      final flushing = queue.flush();
      await Future<void>.delayed(Duration.zero);
      queue.record('two');
      expect(identical(queue.flush(), flushing), isTrue);
      response.complete();
      await flushing;
      expect(batches, [
        ['one'],
        ['two'],
      ]);
      expect(queue.pendingIds, isEmpty);
    },
  );

  test('restored queues are split into requests of at most 100', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'hunt.pendingViews.v1:me',
      List.generate(205, (i) => '$i'),
    );
    final sizes = <int>[];
    await HuntViewQueue('me', prefs, (ids) async {
      sizes.add(ids.length);
    }).flush();
    expect(sizes, [100, 100, 5]);
  });
}
