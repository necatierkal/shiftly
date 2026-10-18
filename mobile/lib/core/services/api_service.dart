import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'local_storage_service.dart';

class ApiException implements Exception {
  final String message;
  final String code;

  ApiException(this.message, {this.code = 'API_ERROR'});

  @override
  String toString() => message;
}

class ApiService {
  final LocalStorageService _storage;
  late final String baseUrl;

  ApiService(this._storage) {
    if (kIsWeb) {
      baseUrl = AppConfig.defaultApiBaseUrl;
    } else {
      try {
        if (Platform.isAndroid) {
          baseUrl = AppConfig.emulatorApiBaseUrl;
        } else {
          baseUrl = AppConfig.defaultApiBaseUrl;
        }
      } catch (_) {
        baseUrl = AppConfig.defaultApiBaseUrl;
      }
    }
  }

  Map<String, String> _headers({bool needsAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (needsAuth) {
      final token = _storage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, bool needsAuth = true}) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _headers(needsAuth: needsAuth)).timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body, bool needsAuth = true}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(
            uri,
            headers: _headers(needsAuth: needsAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body, bool needsAuth = true}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(
            uri,
            headers: _headers(needsAuth: needsAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<dynamic> delete(String endpoint, {bool needsAuth = true}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.delete(uri, headers: _headers(needsAuth: needsAuth)).timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException('Sunucu geçersiz yanıt verdi.', code: 'INVALID_JSON');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    }

    String msg = 'Bir işlem hatası oluştu.';
    if (body is Map) {
      if (body['message'] != null) {
        msg = body['message'].toString();
      } else if (body['detail'] != null) {
        msg = body['detail'].toString();
      }
    }

    if (response.statusCode == 401) {
      throw ApiException('Oturum süreniz doldu. Lütfen tekrar giriş yapın.', code: 'UNAUTHORIZED');
    } else if (response.statusCode == 409) {
      throw ApiException(msg, code: 'CONFLICT');
    }

    throw ApiException(msg, code: 'HTTP_${response.statusCode}');
  }

  Never _handleNetworkError(dynamic error) {
    if (error is ApiException) {
      throw error;
    }
    // Spec rule: Don't show technical exceptions to users
    throw ApiException('Bağlantı kurulamadı. Lütfen internetinizi kontrol edin.', code: 'NETWORK_ERROR');
  }
}
