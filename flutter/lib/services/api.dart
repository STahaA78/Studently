import 'dart:io';
import 'dart:convert';
import 'package:studently/logger.dart';
import 'package:http/http.dart' as http;

class ApiService {

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    logger.i("[$runtimeType] ApiService initialized");
  }

  /// Base URL
  static const String _baseUrl = "http://127.0.0.1:8000";

  /// ===============================
  /// GET
  /// ===============================
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {

    logger.i("[$runtimeType] GET request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
      );

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
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {

    logger.i("[$runtimeType] POST request to $endpoint Initiated");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: jsonEncode(body),
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
  /// MULTIPART
  /// ===============================
  Future<http.Response> multiPart({
    required File file,
    required Map<String, dynamic> metadata
  }) async {

    logger.i("[$runtimeType] Multipart POST request Initiated");

    final url = Uri.parse("$_baseUrl/hub/resources/upload");

    try {

      var request = http.MultipartRequest('POST', url)
        ..fields['data'] = jsonEncode(metadata)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      return _handleResponse(await http.Response.fromStream(response));

    } on SocketException {

      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');

    } catch (e) {

      logger.e("[$runtimeType] Multipart request Failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// DOWNLOAD
  /// ===============================
  Future<http.Response> downloadFile(String endpoint) async {

    logger.i("[$runtimeType] Download request $endpoint");

    final url = Uri.parse("$_baseUrl$endpoint");

    try {

      final response = await http.get(url);

      return _handleResponse(response);

    } on SocketException {

      logger.e("[$runtimeType] No Internet connection");
      throw Exception('No Internet connection');

    } catch (e) {

      logger.e("[$runtimeType] Download failed: $e");
      throw Exception('Error occurred: $e');
    }
  }

  /// ===============================
  /// RESPONSE HANDLER
  /// ===============================
  http.Response _handleResponse(http.Response response) {

    logger.i("[$runtimeType] Handling response ${response.statusCode}");

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