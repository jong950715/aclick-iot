import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

/// Generic API service for handling HTTP requests
class ApiService {
  final String baseUrl;
  final http.Client _client;
  final Map<String, String> _defaultHeaders;

  ApiService({
    required this.baseUrl,
    http.Client? client,
    Map<String, String>? defaultHeaders,
  }) : _client = client ?? http.Client(),
       _defaultHeaders = defaultHeaders ?? {
         'Content-Type': 'application/json',
         'Accept': 'application/json',
       };

  /// Sends a GET request to the specified endpoint
  Future<Either<String, Map<String, dynamic>>> get({
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(
        queryParameters: queryParams,
      );
      
      final response = await _client.get(
        uri,
        headers: {..._defaultHeaders, ...?headers},
      );
      
      return _handleResponse(response);
    } catch (e) {
      return Left('Network error: $e');
    }
  }

  /// Sends a POST request to the specified endpoint
  Future<Either<String, Map<String, dynamic>>> post({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      
      final response = await _client.post(
        uri,
        headers: {..._defaultHeaders, ...?headers},
        body: jsonEncode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return Left('Network error: $e');
    }
  }

  /// Sends a PUT request to the specified endpoint
  Future<Either<String, Map<String, dynamic>>> put({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      
      final response = await _client.put(
        uri,
        headers: {..._defaultHeaders, ...?headers},
        body: jsonEncode(data),
      );
      
      return _handleResponse(response);
    } catch (e) {
      return Left('Network error: $e');
    }
  }

  /// Sends a DELETE request to the specified endpoint
  Future<Either<String, Map<String, dynamic>>> delete({
    required String endpoint,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint');
      
      final response = await _client.delete(
        uri,
        headers: {..._defaultHeaders, ...?headers},
      );
      
      return _handleResponse(response);
    } catch (e) {
      return Left('Network error: $e');
    }
  }

  /// Handles the HTTP response and returns a parsed result
  Either<String, Map<String, dynamic>> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return Right(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (e) {
        return Left('Failed to parse response: $e');
      }
    } else {
      return Left('Request failed with status: ${response.statusCode}');
    }
  }

  /// Closes the HTTP client
  void dispose() {
    _client.close();
  }
}
