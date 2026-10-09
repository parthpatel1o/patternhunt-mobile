import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

const huntViewBatchSize = 10;
const huntViewFlushInterval = Duration(seconds: 15);

typedef SendHuntViews = Future<void> Function(List<String> ids);

/// Per-account durable queue. Failed/unacknowledged batches stay on disk.
class HuntViewQueue {
  HuntViewQueue(this.userId, this._preferences, this._send) {
    _pending.addAll(_stored());
  }

  final String userId;
  final SharedPreferences _preferences;
  final SendHuntViews _send;
  final Set<String> _pending = {};
  Future<void> _writes = Future.value();
  Future<void>? _flight;
  Timer? _timer;
  String get _key => 'hunt.pendingViews.v1:$userId';

  List<String> _stored() => _preferences.getStringList(_key) ?? [];

  Set<String> get pendingIds => {..._pending, ..._stored()};

  void start() {
    _timer ??= Timer.periodic(huntViewFlushInterval, (_) => unawaited(flush()));
  }

  void record(String id) {
    _pending.add(id);
    _writes = _writes
        .then((_) async {
          _pending.addAll(_stored());
          await _preferences.setStringList(_key, _pending.toList());
        })
        .catchError((Object _) {});
    if (_pending.length >= huntViewBatchSize) unawaited(flush());
  }

  Future<void> flush() {
    if (_flight != null) return _flight!;
    final completer = Completer<void>();
    _flight = completer.future;
    unawaited(
      _drain().whenComplete(() {
        _flight = null;
        completer.complete();
      }),
    );
    return completer.future;
  }

  Future<void> _drain() async {
    try {
      await _writes;
      _pending.addAll(_stored());
      while (_pending.isNotEmpty) {
        final sent = _pending.take(100).toList();
        await _send(sent);
        // Serialize acknowledgements behind any views added during the request.
        _writes = _writes.then((_) async {
          _pending.addAll(_stored());
          _pending.removeAll(sent);
          await _preferences.setStringList(_key, _pending.toList());
        });
        await _writes;
      }
    } catch (_) {
      // Retry on the timer, app resume, the next page, or the next hunt.
    }
  }

  Future<void> stop() {
    _timer?.cancel();
    _timer = null;
    return flush();
  }
}
