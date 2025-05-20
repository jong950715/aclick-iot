import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_service.dart';
import '../network/protocol_client.dart';
import '../encryption/encryptor.dart';

/// Service locator that manages global service instances
class ServiceLocator {
  /// Private constructor to prevent direct instantiation
  ServiceLocator._();
  
  /// Singleton instance
  static final ServiceLocator _instance = ServiceLocator._();
  
  /// Get the singleton instance
  static ServiceLocator get instance => _instance;
  
  /// Get a testable instance for unit tests
  static TestableServiceLocator get testableInstance => TestableServiceLocator._();
  
  /// Initialize the service locator
  static Future<void> initialize() async {
    // Pre-initialize any required services or resources
    // This would be called at app startup
    await instance._initializeServices();
  }
  
  // Services registry
  ApiService? _apiService;
  Encryptor? _encryptor;
  ProtocolClient? _protocolClient;
  
  /// API service getter with lazy initialization
  ApiService get apiService => _apiService ??= ApiService(
    baseUrl: 'https://api.example.com',
  );
  
  /// Encryptor service getter with lazy initialization
  Encryptor get encryptor => _encryptor ??= Encryptor();
  
  /// Protocol client getter with lazy initialization
  ProtocolClient get protocolClient => _protocolClient ??= ProtocolClient(
    baseUrl: 'https://iot.example.com',
    encryptor: encryptor,
  );
  
  /// Initialize all required services
  Future<void> _initializeServices() async {
    // Create instances if needed for startup
    // Could also load configuration, init resources, etc.
  }
  
  /// Reset all service instances (useful for testing)
  void reset() {
    _apiService = null;
    _encryptor = null;
    _protocolClient = null;
  }
}

/// Provider for the service locator
final serviceLocatorProvider = Provider<ServiceLocator>((ref) {
  return ServiceLocator.instance;
});

/// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) {
  return ref.read(serviceLocatorProvider).apiService;
});

/// Provider for Encryptor service
final encryptorProvider = Provider<Encryptor>((ref) {
  return ref.read(serviceLocatorProvider).encryptor;
});

/// Provider for Protocol client
final protocolClientProvider = Provider<ProtocolClient>((ref) {
  return ref.read(serviceLocatorProvider).protocolClient;
});

/// Extended version of ServiceLocator that exposes setters for testing
class TestableServiceLocator extends ServiceLocator {
  /// Private constructor to prevent direct instantiation
  TestableServiceLocator._() : super._();
  
  /// Set API service for testing
  void setApiService(ApiService service) {
    _apiService = service;
  }
  
  /// Set encryptor for testing
  void setEncryptor(Encryptor service) {
    _encryptor = service;
  }
  
  /// Set protocol client for testing
  void setProtocolClient(ProtocolClient client) {
    _protocolClient = client;
  }
}
