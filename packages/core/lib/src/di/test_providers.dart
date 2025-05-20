import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import '../network/api_service.dart';
import '../network/protocol_client.dart';
import '../encryption/encryptor.dart';
import 'service_locator.dart';
import 'provider_scopes.dart';

/// Mock classes for testing
class MockApiService extends Mock implements ApiService {}
class MockEncryptor extends Mock implements Encryptor {}
class MockProtocolClient extends Mock implements ProtocolClient {}

/// Provider overrides for testing
class TestProviders {
  /// Creates test overrides for unit and widget testing
  static List<Override> get testOverrides {
    final mockApiService = MockApiService();
    final mockEncryptor = MockEncryptor();
    final mockProtocolClient = MockProtocolClient();
    
    return [
      // Override service locator
      serviceLocatorProvider.overrideWithValue(_createMockServiceLocator(
        mockApiService: mockApiService,
        mockEncryptor: mockEncryptor,
        mockProtocolClient: mockProtocolClient,
      )),
      
      // Override individual service providers
      apiServiceProvider.overrideWithValue(mockApiService),
      encryptorProvider.overrideWithValue(mockEncryptor),
      protocolClientProvider.overrideWithValue(mockProtocolClient),
      
      // Override feature flags for testing
      featureFlagsProvider.overrideWithValue({
        'enableAnalytics': false, // Disable analytics in tests
        'enableCloudSync': false, // Disable cloud sync in tests
        'enableDevMode': true,    // Enable dev mode in tests
        'enableBetaFeatures': true, // Enable beta features in tests
      }),
    ];
  }
  
  /// Creates a service locator with mock services for testing
  static ServiceLocator _createMockServiceLocator({
    required MockApiService mockApiService,
    required MockEncryptor mockEncryptor,
    required MockProtocolClient mockProtocolClient,
  }) {
    final serviceLocator = ServiceLocator.instance;
    
    // Use reflection to set private fields (not ideal but works for testing)
    // ignore: invalid_use_of_protected_member
    // Use setters that we'll define in the ServiceLocator class
    if (serviceLocator is TestableServiceLocator) {
      (serviceLocator as TestableServiceLocator).setApiService(mockApiService);
      (serviceLocator as TestableServiceLocator).setEncryptor(mockEncryptor);
      (serviceLocator as TestableServiceLocator).setProtocolClient(mockProtocolClient);
    }
    
    return serviceLocator;
  }
}

/// Create a test provider container for unit tests
ProviderContainer createTestContainer() {
  return ProviderContainer(
    overrides: TestProviders.testOverrides,
  );
}
