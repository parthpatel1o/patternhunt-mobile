import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  late final Dio _dio;
  Dio get dio => _dio;

  Future<T> getData<T>(String path, {Map<String, dynamic>? query, required T Function(dynamic json) map}) async {
    final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    final body = response.data;
    if (body == null || body['ok'] != true) {
      throw ApiException(body?['error'] as String? ?? 'Request failed');
    }
    return map(body['data']);
  }

  Future<void> patch(String path, Map<String, dynamic> data) async {
    final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
    final body = response.data;
    if (body == null || body['ok'] != true) {
      throw ApiException(body?['error'] as String? ?? 'Request failed');
    }
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    final body = response.data;
    if (body == null || body['ok'] != true) {
      throw ApiException(body?['error'] as String? ?? 'Request failed');
    }
    return (body['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> postMultipart(String path, FormData data) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
    final body = response.data;
    if (body == null || body['ok'] != true) {
      throw ApiException(body?['error'] as String? ?? 'Request failed');
    }
    return (body['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> delete(String path) async {
    final response = await _dio.delete<Map<String, dynamic>>(path);
    final body = response.data;
    if (body == null || body['ok'] != true) {
      throw ApiException(body?['error'] as String? ?? 'Request failed');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
