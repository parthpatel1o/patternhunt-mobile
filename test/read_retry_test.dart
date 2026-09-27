import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/api/api_client.dart';

DioException _dioError(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/patterns');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  Future<void> noDelay(Duration _) async {}

  test('timeout retries and then succeeds', () async {
    var attempts = 0;

    final value = await retrySafeRead(() async {
      attempts += 1;
      if (attempts == 1) {
        throw _dioError(DioExceptionType.receiveTimeout);
      }
      return 'loaded';
    }, delay: noDelay);

    expect(value, 'loaded');
    expect(attempts, 2);
  });

  test('HTTP 500 retries', () async {
    var attempts = 0;

    final value = await retrySafeRead(() async {
      attempts += 1;
      if (attempts == 1) {
        throw _dioError(DioExceptionType.badResponse, status: 500);
      }
      return 200;
    }, delay: noDelay);

    expect(value, 200);
    expect(attempts, 2);
  });

  test('HTTP 400 does not retry', () async {
    var attempts = 0;

    await expectLater(
      () => retrySafeRead(() async {
        attempts += 1;
        throw _dioError(DioExceptionType.badResponse, status: 400);
      }, delay: noDelay),
      throwsA(isA<DioException>()),
    );
    expect(attempts, 1);
  });

  test('three transient failures surface the final error', () async {
    var attempts = 0;

    await expectLater(
      () => retrySafeRead(() async {
        attempts += 1;
        throw _dioError(DioExceptionType.connectionTimeout);
      }, delay: noDelay),
      throwsA(isA<DioException>()),
    );
    expect(attempts, 3);
  });
}
