import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../encryption/encryptor.dart';

/// Handles the communication protocol between IoT devices and the phone application
class ProtocolClient {
  final String baseUrl;
  final Encryptor _encryptor;
  final http.Client _httpClient;
  final String? _apiKey;

  ProtocolClient({
    required this.baseUrl,
    required Encryptor encryptor,
    http.Client? httpClient,
    String? apiKey,
  })  : _encryptor = encryptor,
        _httpClient = httpClient ?? http.Client(),
        _apiKey = apiKey;

  /// Sends encrypted data to the specified endpoint
  Future<Either<String, Map<String, dynamic>>> sendSecureData({
    required String endpoint,
    required Map<String, dynamic> data,
    required String secretKey,
    Map<String, String>? headers,
  }) async {
    try {
      // Convert data to JSON string
      final jsonData = jsonEncode(data);
      
      // Encrypt the data
      final encryptedData = await _encryptor.encrypt(
        data: jsonData,
        secretKey: secretKey,
      );
      
      if (encryptedData.isLeft()) {
        return Left(encryptedData.getLeft().getOrElse(() => 'Encryption failed'));
      }
      
      // Prepare headers
      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        ...?headers,
      };
      
      // Send the encrypted data
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: requestHeaders,
        body: jsonEncode({'data': encryptedData.getRight().getOrElse(() => '')}),
      );
      
      if (response.statusCode != 200) {
        return Left('Request failed with status: ${response.statusCode}');
      }
      
      // Parse and return the response
      return Right(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      return Left('Protocol error: $e');
    }
  }

  /// Receives and decrypts data from the specified endpoint
  Future<Either<String, Map<String, dynamic>>> receiveSecureData({
    required String endpoint,
    required String secretKey,
    Map<String, String>? headers,
  }) async {
    try {
      // Prepare headers
      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        ...?headers,
      };
      
      // Send the request
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: requestHeaders,
      );
      
      if (response.statusCode != 200) {
        return Left('Request failed with status: ${response.statusCode}');
      }
      
      // Parse the response
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (!responseData.containsKey('data')) {
        return Left('Invalid response format: missing data field');
      }
      
      // Decrypt the data
      final decryptedData = await _encryptor.decrypt(
        encryptedData: responseData['data'] as String,
        secretKey: secretKey,
      );
      
      if (decryptedData.isLeft()) {
        return Left(decryptedData.getLeft().getOrElse(() => 'Decryption failed'));
      }
      
      // Parse and return the decrypted data
      return Right(jsonDecode(decryptedData.getRight().getOrElse(() => '{}')) as Map<String, dynamic>);
    } catch (e) {
      return Left('Protocol error: $e');
    }
  }

  /// Closes the HTTP client
  void dispose() {
    _httpClient.close();
  }

  /// Sends data to the specified endpoint
  Future<Either<String, Map<String, dynamic>>> send({
    required String path,
    required Map<String, dynamic> data,
    Map<String, String>? headers,
  }) async {
    try {
      // Prepare headers
      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        ...?headers,
      };
      
      // Send the data
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/$path'),
        headers: requestHeaders,
        body: jsonEncode(data),
      );
      
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left('Request failed with status: ${response.statusCode}');
      }
      
      // Parse and return the response
      return Right(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      return Left('Protocol error: $e');
    }
  }

  /// Fetches data from the specified endpoint
  Future<Either<String, Map<String, dynamic>>> fetch({
    required String path,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      // Build URI with query parameters
      final uri = Uri.parse('$baseUrl/$path').replace(
        queryParameters: queryParams,
      );
      
      // Prepare headers
      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        ...?headers,
      };
      
      // Send the request
      final response = await _httpClient.get(
        uri,
        headers: requestHeaders,
      );
      
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left('Request failed with status: ${response.statusCode}');
      }
      
      // Parse and return the response
      return Right(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      return Left('Protocol error: $e');
    }
  }

  /// Subscribes to a stream of data from the specified endpoint
  Stream<Either<String, Map<String, dynamic>>> subscribe(String topic) {
    // Create a StreamController to provide data
    final controller = StreamController<Either<String, Map<String, dynamic>>>();
    
    // Here we would typically set up a WebSocket or SSE connection
    // For now, this is a placeholder implementation
    // In a real implementation, we would connect to the server and stream data
    
    // Example simulated implementation:
    // Start a timer to simulate periodic updates
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      
      // Simulate receiving data
      controller.add(
        Right(<String, dynamic>{
          'timestamp': DateTime.now().toIso8601String(),
          'topic': topic,
          'data': {'value': DateTime.now().millisecondsSinceEpoch % 100},
        }),
      );
    });
    
    // Return the stream and handle disposal
    return controller.stream.asBroadcastStream(onCancel: (_) {
      controller.close();
    });
  }
}
