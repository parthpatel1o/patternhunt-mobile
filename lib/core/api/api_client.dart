import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.normalizedApiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
      // Avoid silent auth loss if the API host ever redirects again.
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = options.extra['accessToken'] as String? ?? await _accessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (options.data != null && options.headers['Content-Type'] == null) {
          options.headers['Content-Type'] = 'application/json';
        }
        handler.next(options);
      },
    ));
  }

  late final Dio _dio;
  Dio get dio => _dio;

  Future<String?> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    final session = await auth.getSession();
    return session?.accessToken ?? auth.currentSession?.accessToken;
  }

  Options _options({String? accessToken}) {
    return Options(extra: accessToken == null ? null : {'accessToken': accessToken});
  }

  Never _throwFromResponse(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final message = body['error'] as String?;
      if (message != null && message.isNotEmpty) {
        throw ApiException(message);
      }
    }
    if (response.statusCode == 401) {
      throw ApiException('Please log in.');
    }
    throw ApiException('Request failed (${response.statusCode ?? 'unknown'})');
  }

  Never _throwFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'] as String?;
      if (message != null && message.isNotEmpty) {
        throw ApiException(message);
      }
    }
    if (e.response?.statusCode == 401) {
      throw ApiException('Please log in.');
    }
    throw ApiException(e.message ?? 'Request failed');
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
    return _run(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        options: _options(accessToken: accessToken),
      );
      final body = response.data;
      if (response.statusCode == 401 || body == null || body['ok'] != true) {
        _throwFromResponse(response);
      }
      return map(body['data']);
    });
  }

  Future<void> patch(String path, Map<String, dynamic> data, {String? accessToken}) async {
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

  Future<Map<String, dynamic>> post(String path, {dynamic data, String? accessToken}) async {
    return _run(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: _options(accessToken: accessToken),
      );
      final body = response.data;
      if (response.statusCode == 401 || body == null || body['ok'] != true) {
        _throwFromResponse(response);
      }
      return (body['data'] as Map<String, dynamic>?) ?? {};
    });
  }

  Future<Map<String, dynamic>> postMultipart(String path, FormData data, {String? accessToken}) async {
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

  Future<void> delete(String path, {String? accessToken}) async {
    return _run(() async {
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
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
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
