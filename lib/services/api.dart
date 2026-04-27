import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:studently/config.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';
import 'package:http/http.dart' as http;

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
  Future<http.Response> get(String endpoint) async {
    logger.i("[$runtimeType] GET request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {
      final response = await http.get(url, headers: await _getAuthHeaders());

      logger.i("[$runtimeType] GET request Completed ${response.statusCode}");

      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] GET request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// POST
  /// ===============================
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    logger.i("[$runtimeType] POST request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {
      final response = await http.post(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );

      logger.i("[$runtimeType] POST request Completed ${response.statusCode}");

      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] POST request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// PATCH
  /// ===============================
  Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    logger.i("[$runtimeType] PATCH request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {
      final response = await http.patch(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );

      logger.i("[$runtimeType] PATCH request Completed ${response.statusCode}");

      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] PATCH request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DELETE
  /// ===============================
  Future<http.Response> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    logger.i("[$runtimeType] DELETE request to $endpoint Initiated");
    final url = Uri.parse("$_baseUrl$endpoint");
    try {
      final response = await http.delete(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      logger.i(
        "[$runtimeType] DELETE request Completed ${response.statusCode}",
      );
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] DELETE request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// PUT
  /// ===============================
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    logger.i("[$runtimeType] PUT request to $endpoint Initiated");
    final url = Uri.parse("$_baseUrl$endpoint");
    try {
      final response = await http.put(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      logger.i("[$runtimeType] PUT request Completed ${response.statusCode}");
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] PUT request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// MULTIPART UPLOAD
  /// ===============================
  Future<http.Response> multiPart({
    required File file,
    required Map<String, dynamic> metadata,
  }) async {
    logger.i("[$runtimeType] Multipart POST request Initiated");

    final url = Uri.parse("$_baseUrl/hub/resources/upload");

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] =
            'Bearer ${await authService.value.getIdToken()}'
        ..fields['metadata'] = jsonEncode(metadata)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      return _handleResponse(await http.Response.fromStream(response));
    } catch (e) {
      logger.e("[$runtimeType] Multipart request Failed: $e");
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

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] =
            'Bearer ${await authService.value.getIdToken()}'
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] File Upload Failed: $e");
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
    required Map<String, dynamic> metadata,
    String fieldName = 'file', // Customizable field name (default: 'file')
  }) async {
    logger.i("[$runtimeType] Multipart (bytes) request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");

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
          ),
        );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] Multipart (bytes) request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DOWNLOAD FILE
  /// ===============================
  Future<http.Response> downloadFile(String endpoint) async {
    logger.i("[$runtimeType] Download request $endpoint");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {
      final response = await http.get(url);

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] Download failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DOWNLOAD FROM EXTERNAL URL
  /// ===============================
  Future<http.Response> downloadFromUrl(String externalUrl) async {
    logger.i("[$runtimeType] Download from external URL: $externalUrl");

    try {
      final response = await http.get(Uri.parse(externalUrl));

      return _handleResponse(response);
    } catch (e) {
      logger.e("[$runtimeType] Download from external URL failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// RESPONSE HANDLER
  /// ===============================
  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      logger.e(
        "[$runtimeType] Request failed ${response.statusCode} body: ${response.body}",
      );

      throw Exception('Request failed with status: ${response.statusCode}');
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
}
