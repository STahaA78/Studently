import 'dart:io';
import 'dart:convert';
import 'package:studently/auth_service.dart';
import 'package:studently/logger.dart';
import 'package:http/http.dart' as http;

class ApiService {
  //Singleton
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;
  ApiService._internal() {
    logger.i("[$runtimeType] ApiService initialized");
  }
  //Configuration
  static const String _baseUrl = "localhost:8000";

  //Headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await authService.value.getIdToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }
  //Methods 

  // GET
  Future<http.Response> get(String endpoint) async {
    logger.i("[$runtimeType] GET request to $endpoint Initiated");
    final url = Uri.http(_baseUrl, endpoint);
    try {
      final response = await http.get(
        url,
        headers: await _getAuthHeaders(),
      );
      logger.i("[$runtimeType] GET request to $endpoint Completed with status code ${response.statusCode}");
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] GET request to $endpoint Failed: No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] GET request to $endpoint Failed with error: $e");
      throw Exception('Error occurred: $e');
    }
  }

  // POST
  // Multipart POST for file uploads
  Future<http.Response> multiPart({ required File file, required Map<String, dynamic> metadata }) async {
    logger.i("[$runtimeType] Multipart POST request Initiated");
    final url = Uri.http(_baseUrl, '/hub/resources/upload');
    try {
      var request = http.MultipartRequest('POST', url)
        ..fields['data'] = jsonEncode(metadata)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
    
      return _handleResponse(await http.Response.fromStream(response));
    } on SocketException {
      logger.e("[$runtimeType] Multipart POST request Failed: No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] Multipart POST request Failed with error: $e");
      throw Exception('Error occurred: $e');
    }
  }

  // Generic POST method
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    logger.i("[$runtimeType] POST request to $endpoint Initiated");
    final url = Uri.http(_baseUrl, endpoint);
    try {
      final response = await http.post(
        url,
        headers: await _getAuthHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      logger.i("[$runtimeType] POST request to $endpoint Completed with status code "+
          "${response.statusCode}");
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] POST request to $endpoint Failed: No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] POST request to $endpoint Failed with error: $e");
      throw Exception('Error occurred: $e');
    }
  }

  http.Response _handleResponse(http.Response response) {
    logger.i("[$runtimeType] Handling response with status code ${response.statusCode}");
    if (response.statusCode >= 200 && response.statusCode < 300) {
      logger.i("[$runtimeType] Handling Successful");
      return response;
    } else {
      logger.e("[$runtimeType] Handling Failed with status code ${response.statusCode} and body: ${response.body}");
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  }

  String getCompleteUrl(String endpoint) {
    logger.i("[$runtimeType] Constructing complete URL for endpoint: $endpoint");
    final completeUrl = "http://$_baseUrl$endpoint";
    logger.d("[$runtimeType] Complete URL: $completeUrl");
    return completeUrl;
  }

  Future<http.Response> downloadFile(String endpoint) async {
    logger.i("[$runtimeType] Download file request to $endpoint Initiated");
    final url = Uri.http(_baseUrl, endpoint);
    try {
      final response = await http.get(url);
      logger.i("[$runtimeType] Download file request to $endpoint Completed with status code ${response.statusCode}");
      return _handleResponse(response);
    } on SocketException {
      logger.e("[$runtimeType] Download file request to $endpoint Failed: No Internet connection");
      throw Exception('No Internet connection');
    } catch (e) {
      logger.e("[$runtimeType] Download file request to $endpoint Failed with error: $e");
      throw Exception('Error occurred: $e');
    }
  }
}