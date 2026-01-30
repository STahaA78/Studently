import 'dart:io';
import 'dart:convert';
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

  //Methods 

  // GET
  Future<http.Response> get(String endpoint) async {
    logger.i("[$runtimeType] GET request to $endpoint Initiated");
    final url = Uri.http(_baseUrl, endpoint);
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
  Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    logger.i("[$runtimeType] POST request to $endpoint Initiated");
    final url = Uri.http(_baseUrl, endpoint);
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );
      logger.i("[$runtimeType] POST request to $endpoint Completed with status code ${response.statusCode}");
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

}