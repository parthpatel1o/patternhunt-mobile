import 'dart:async';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

typedef ReadRetryDelay = Future<void> Function(Duration duration);

/// Retries only safe reads. Callers can inject a no-op delay in tests.
Future<T> retrySafeRead<T>(
  Future<T> Function() action, {
  ReadRetryDelay delay = Future<void>.delayed,
}) async {
  const delays = [Duration(milliseconds: 250), Duration(milliseconds: 500)];
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await action();
    } catch (error) {
      if (attempt == 2 || !_isTransientReadError(error)) rethrow;
      await delay(delays[attempt]);
    }
  }
  throw StateError('Unreachable');
}

bool _isTransientReadError(Object error) {
  if (error is ApiException) return error.transient;
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  if (status != null && status >= 500) return true;
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return true;
  }
  final message = '${error.message} ${error.error}'.toLowerCase();
  return message.contains('connection reset') ||
      message.contains('connection refused') ||
      message.contains('temporary failure') ||
      message.contains('dns') ||
      message.contains('timeout');
}

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.normalizedApiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
        headers: const {'Accept': 'application/json'},
        // Avoid silent auth loss if the API host ever redirects again.
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token =
              options.extra['accessToken'] as String? ?? await _accessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data != null && options.headers['Content-Type'] == null) {
            options.headers['Content-Type'] = 'application/json';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  Dio get dio => _dio;

  Future<String?> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    final session = await auth.getSession();
    return session?.accessToken ?? auth.currentSession?.accessToken;
  }

  Options _options({String? accessToken}) {
    return Options(
      extra: accessToken == null ? null : {'accessToken': accessToken},
    );
  }

  Options _readOptions({String? accessToken}) => Options(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    extra: accessToken == null ? null : {'accessToken': accessToken},
  );

  Never _throwFromResponse(Response<Map<String, dynamic>> response) {
    final message =
        _messageFromBody(response.data) ??
        (response.statusCode == 413
            ? 'Those files are too large to upload at once. Try fewer or smaller photos/PDF.'
            : null) ??
        (response.statusCode == 401 ? 'Please log in.' : null);
    throw ApiException(
      message ?? 'Request failed (${response.statusCode ?? 'unknown'})',
    );
  }

  Never _throwFromDio(DioException e) {
    final status = e.response?.statusCode;
    final message =
        _messageFromBody(e.response?.data) ??
        (status == 413
            ? 'Those files are too large to upload at once. Try fewer or smaller photos/PDF.'
            : null) ??
        (status == 401 ? 'Please log in.' : null) ??
        (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.sendTimeout
            ? 'Upload timed out. Try fewer or smaller photos.'
            : null);
    throw ApiException(message ?? e.message ?? 'Request failed');
  }

  String? _messageFromBody(dynamic data) {
    if (data is! Map) return null;
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      if (error.contains('FUNCTION_PAYLOAD_TOO_LARGE') ||
          error.contains('Payload Too Large')) {
        return 'Those files are too large to upload at once. Try fewer or smaller photos/PDF.';
      }
      return error;
    }
    if (error is Map) {
      final nested = error['message'] ?? error['code'];
      if (nested is String && nested.trim().isNotEmpty) {
        if (nested.contains('FUNCTION_PAYLOAD_TOO_LARGE') ||
            nested.contains('Payload Too Large')) {
          return 'Those files are too large to upload at once. Try fewer or smaller photos/PDF.';
        }
        return nested;
      }
      return 'Request failed';
    }
    return null;
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      _throwFromDio(e);
    }
  }

  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
    required T Function(dynamic json) map,
  }) async {
    try {
      return await retrySafeRead(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: query,
          options: _readOptions(accessToken: accessToken),
        );
        final body = response.data;
        if (response.statusCode == 401 || body == null || body['ok'] != true) {
          if (_isTimeoutStyleResponse(response)) {
            throw ApiException('Request timed out', transient: true);
          }
          _throwFromResponse(response);
        }
        return map(body['data']);
      });
    } on DioException catch (error) {
      _throwFromDio(error);
    }
  }

  bool _isTimeoutStyleResponse(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) return false;
    final error = data['error'];
    final text = error is Map
        ? '${error['code'] ?? ''} ${error['message'] ?? ''}'
        : '$error';
    final normalized = text.toLowerCase();
    return normalized.contains('timeout') || normalized.contains('timed_out');
  }

  Future<void> patch(
    String path,
    Map<String, dynamic> data, {
    String? accessToken,
  }) async {
    return _run(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        path,
        data: data,
        options: _options(accessToken: accessToken),
      );
      final body = response.data;
      if (response.statusCode == 401 || body == null || body['ok'] != true) {
        _throwFromResponse(response);
      }
    });
  }

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    String? accessToken,
  }) async {
    return _run(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: query,
        options: _options(accessToken: accessToken),
      );
      final body = response.data;
      if (response.statusCode == 401 || body == null || body['ok'] != true) {
        _throwFromResponse(response);
      }
      return (body['data'] as Map<String, dynamic>?) ?? {};
    });
  }

  /// Vote writes are explicit state, never a period-specific toggle.
  Future<Map<String, dynamic>> votePattern(String patternId, bool voted) {
    return post('/patterns/$patternId/vote', data: {'voted': voted});
  }

  Future<void> updateRankBoardCategory(String categorySlug) {
    return patch('/me/rank-board-category', {'categorySlug': categorySlug});
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    FormData data, {
    String? accessToken,
  }) async {
    return _run(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(
          contentType: 'multipart/form-data',
          extra: accessToken == null ? null : {'accessToken': accessToken},
        ),
      );
      final body = response.data;
      if (response.statusCode == 401 || body == null || body['ok'] != true) {
        _throwFromResponse(response);
      }
      return (body['data'] as Map<String, dynamic>?) ?? {};
    });
  }

  Future<void> delete(
    String path, {
    Map<String, dynamic>? query,
    String? accessToken,
  }) async {
    return _run(() async {
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
        queryParameters: query,
        options: _options(accessToken: accessToken),
      );
      final body = response.data;
      if (response.statusCode == 401 || body == null || body['ok'] != true) {
        _throwFromResponse(response);
      }
    });
  }
}

class ApiException implements Exception {
  ApiException(this.message, {this.transient = false});
  final String message;
  final bool transient;
  @override
  String toString() => message;
}
