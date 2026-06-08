// lib/data/services/api/api_client.dart
import 'package:http/http.dart' as http;
import 'package:user_onboarding/utils/timezone_helper.dart';

/// Shared HTTP client for all domain API services.
///
/// Owns the single source of truth for the backend base URL and the common
/// request headers, so each domain service only has to describe its endpoints.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  ApiClient._internal();

  static const String baseUrl =
      'https://health-ai-backend-i28b.onrender.com/api/health';

  Map<String, String> get headers {
    final timezoneInfo = TimezoneHelper.getTimezoneInfo();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Timezone-Offset': timezoneInfo['offset_minutes'].toString(),
      'X-Timezone-String': timezoneInfo['offset_string'],
    };
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> get(String path) =>
      http.get(_uri(path), headers: headers);

  Future<http.Response> post(String path, {Object? body}) =>
      http.post(_uri(path), headers: headers, body: body);

  Future<http.Response> put(String path, {Object? body}) =>
      http.put(_uri(path), headers: headers, body: body);

  Future<http.Response> patch(String path, {Object? body}) =>
      http.patch(_uri(path), headers: headers, body: body);

  Future<http.Response> delete(String path, {Object? body}) =>
      http.delete(_uri(path), headers: headers, body: body);
}
