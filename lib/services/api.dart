import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:studently/config.dart';
import 'package:studently/services/analytics_service.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  /// Base URL from configuration
  static const String _baseUrl = AppConfig.apiBaseUrl;

  /// Singleton
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal() {
    logger.i("[$runtimeType] ApiService initialized");
  }

  /// ===============================
  /// AUTH HEADERS
  /// ===============================
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = authService.value.currentUser;

    if (user == null) {
      return {"Content-Type": "application/json"};
    }

    try {
      // Add timeout to prevent hanging on token fetch
      String? token;
      try {
        token = await user.getIdToken().timeout(const Duration(seconds: 10));
      } catch (e) {
        if (e is TimeoutException) {
          logger.w("[$runtimeType] getIdToken timed out after 10 seconds");
          token = null;
        } else {
          rethrow;
        }
      }

      if (token == null) {
        return {"Content-Type": "application/json"};
      }

      return {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };
    } catch (e) {
      logger.e("[$runtimeType] Error getting auth token: $e");
      return {"Content-Type": "application/json"};
    }
  }

  /// ===============================
  /// GET
  /// ===============================
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    bool allowNotModified = false,
  }) async {
    logger.i("[$runtimeType] GET request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    try {
      final requestHeaders = await _getAuthHeaders();
      if (headers != null) {
        requestHeaders.addAll(headers);
      }
      final response = await http.get(url, headers: requestHeaders);

      logger.i("[$runtimeType] GET request Completed ${response.statusCode}");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'GET',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success:
              (response.statusCode >= 200 && response.statusCode < 300) ||
              (allowNotModified && response.statusCode == 304),
          cacheResult:
              allowNotModified && response.statusCode == 304
                  ? 'not_modified'
                  : null,
        ),
      );

      return _handleResponse(response, allowNotModified: allowNotModified);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'GET',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: 'socket_exception',
        ),
      );
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] GET request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'GET',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// POST
  /// ===============================
  Future<http.Response> post(
    String endpoint, {
    dynamic body,
  }) async {
    logger.i("[$runtimeType] POST request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    try {
      final response = await http.post(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );

      logger.i("[$runtimeType] POST request Completed ${response.statusCode}");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'POST',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );

      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'POST',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: 'socket_exception',
        ),
      );
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] POST request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'POST',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// PATCH
  /// ===============================
  Future<http.Response> patch(
    String endpoint, {
    dynamic body,
  }) async {
    logger.i("[$runtimeType] PATCH request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    try {
      final response = await http.patch(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );

      logger.i("[$runtimeType] PATCH request Completed ${response.statusCode}");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'PATCH',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );

      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'PATCH',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: 'socket_exception',
        ),
      );
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] PATCH request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'PATCH',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DELETE
  /// ===============================
  Future<http.Response> delete(
    String endpoint, {
    dynamic body,
  }) async {
    logger.i("[$runtimeType] DELETE request to $endpoint Initiated");
    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    try {
      final response = await http.delete(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      logger.i(
        "[$runtimeType] DELETE request Completed ${response.statusCode}",
      );
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'DELETE',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'DELETE',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: 'socket_exception',
        ),
      );
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] DELETE request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'DELETE',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// PUT
  /// ===============================
  Future<http.Response> put(
    String endpoint, {
    dynamic body,
  }) async {
    logger.i("[$runtimeType] PUT request to $endpoint Initiated");
    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    try {
      final response = await http.put(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      logger.i("[$runtimeType] PUT request Completed ${response.statusCode}");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'PUT',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'PUT',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: 'socket_exception',
        ),
      );
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] PUT request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'PUT',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// MULTIPART UPLOAD
  /// ===============================
  Future<http.Response> multiPart({
    required String endpoint,
    required File file,
    required Map<String, dynamic> metadata,
  }) async {
    logger.i("[$runtimeType] Multipart POST request Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] =
            'Bearer ${await authService.value.getIdToken()}'
        ..fields['metadata'] = jsonEncode(metadata)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final materialized = await http.Response.fromStream(response);
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'POST',
          endpoint: normalizedEndpoint,
          statusCode: materialized.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success:
              materialized.statusCode >= 200 && materialized.statusCode < 300,
        ),
      );
      return _handleResponse(materialized);
    } catch (e) {
      logger.e("[$runtimeType] Multipart request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'POST',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// FILE UPLOAD
  /// ===============================
  Future<http.Response> uploadFile(
    String endpoint,
    List<int> bytes,
    String filename,
  ) async {
    logger.i("[$runtimeType] File Upload request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] =
            'Bearer ${await authService.value.getIdToken()}'
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );

      final streamedResponse = await request.send();

      final materialized = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'POST',
          endpoint: normalizedEndpoint,
          statusCode: materialized.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success:
              materialized.statusCode >= 200 && materialized.statusCode < 300,
        ),
      );

      return _handleResponse(materialized);
    } catch (e) {
      logger.e("[$runtimeType] File Upload Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'POST',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// MULTIPART WITH BYTES (Web-compatible)
  /// ===============================
  Future<http.Response> multiPartFromBytes({
    required String endpoint,
    required List<int> fileBytes,
    required String filename,
    Map<String, dynamic>? metadata,
    Map<String, String>? formFields,
    String fieldName = 'file', // Customizable field name (default: 'file')
  }) async {
    logger.i("[$runtimeType] Multipart (bytes) request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    MediaType inferImageMediaType(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.png')) return MediaType('image', 'png');
      if (lower.endsWith('.webp')) return MediaType('image', 'webp');
      if (lower.endsWith('.gif')) return MediaType('image', 'gif');
      if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
      if (lower.endsWith('.heic')) return MediaType('image', 'heic');
      if (lower.endsWith('.heif')) return MediaType('image', 'heif');
      return MediaType('image', 'jpeg');
    }

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] =
            'Bearer ${await authService.value.getIdToken()}'
        ..fields['metadata'] = jsonEncode(metadata)
        ..files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            fileBytes,
            filename: filename,
            contentType: inferImageMediaType(filename),
          ),
        );

      // Add additional form fields if provided
      if (formFields != null) {
        request.fields.addAll(formFields);
      }

      // Extract and add crop_data if present in metadata
      if (metadata != null && metadata.containsKey('cropData')) {
        request.fields['crop_data'] = metadata['cropData'].toString();
      }

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'POST',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] Multipart (bytes) request Failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'POST',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DOWNLOAD FILE
  /// ===============================
  Future<http.Response> downloadFile(String endpoint) async {
    logger.i("[$runtimeType] Download request $endpoint");

    final url = Uri.parse("$_baseUrl$endpoint");
    final stopwatch = Stopwatch()..start();
    final normalizedEndpoint = _normalizeEndpoint(endpoint);

    try {
      final response = await http.get(url);
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'GET',
          endpoint: normalizedEndpoint,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] Download failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'GET',
          endpoint: normalizedEndpoint,
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DOWNLOAD FROM EXTERNAL URL
  /// ===============================
  Future<http.Response> downloadFromUrl(String externalUrl) async {
    logger.i("[$runtimeType] Download from external URL: $externalUrl");
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http.get(Uri.parse(externalUrl));
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiRequest(
          method: 'GET',
          endpoint: 'external_download',
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
          success: response.statusCode >= 200 && response.statusCode < 300,
        ),
      );

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] Download from external URL failed: $e");
      stopwatch.stop();
      unawaited(
        AnalyticsService.logApiFailure(
          method: 'GET',
          endpoint: 'external_download',
          durationMs: stopwatch.elapsedMilliseconds,
          errorType: e.runtimeType.toString(),
        ),
      );
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// RESPONSE HANDLER
  /// ===============================
  http.Response _handleResponse(
    http.Response response, {
    bool allowNotModified = false,
  }) {
    if (response.statusCode == 304 && allowNotModified) {
      return response;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      var message = 'Request failed with status: ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'] ?? decoded['message'];
          if (detail != null && detail.toString().trim().isNotEmpty) {
            message = detail.toString();
          }
        } else if (response.body.trim().isNotEmpty) {
          message = response.body.trim();
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) {
          message = response.body.trim();
        }
      }
      logger.e(
        "[$runtimeType] Request failed ${response.statusCode} body: ${response.body}",
      );

      throw Exception(message);
    }
  }

  /// ===============================
  /// COMPLETE URL
  /// ===============================
  String getCompleteUrl(String endpoint) {
    final completeUrl = "$_baseUrl$endpoint";

    logger.d("[$runtimeType] Complete URL: $completeUrl");

    return completeUrl;
  }

  String _normalizeEndpoint(String endpoint) {
    final path = Uri.parse(endpoint).path;
    final normalized = path
        .replaceAll(
          RegExp(r'^/teachers/[^/]+/reviews/?$'),
          '/teachers/:id/reviews',
        )
        .replaceAll(RegExp(r'^/teachers/[^/]+/?$'), '/teachers/:id')
        .replaceAll(
          RegExp(r'^/hub/resources/[^/]+/?$'),
          '/hub/resources/:course',
        )
        .replaceAll(RegExp(r'^/users/[^/]+/status/?$'), '/users/:id/status')
        .replaceAll(
          RegExp(r'^/users/[^/]+/requests/?$'),
          '/users/:id/requests',
        );

    if (normalized.startsWith('/users/search')) {
      return '/users/search';
    }
    if (normalized.startsWith('/users/discover/interactions')) {
      return '/users/discover/interactions';
    }

    return normalized.isEmpty ? endpoint : normalized;
  }
}
