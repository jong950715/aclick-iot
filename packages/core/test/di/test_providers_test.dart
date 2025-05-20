import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:core/core.dart';

void main() {
  group('TestProviders Tests', () {
    test('testOverrides should include all necessary providers', () {
      // Act
      final overrides = TestProviders.testOverrides;
      
      // Assert - Check that all providers are included
      expect(
        overrides.where(
          (override) => override.toString().contains('apiServiceProvider'),
        ),
        isNotEmpty,
      );
      
      expect(
        overrides.where(
          (override) => override.toString().contains('encryptorProvider'),
        ),
        isNotEmpty,
      );
      
      expect(
        overrides.where(
          (override) => override.toString().contains('protocolClientProvider'),
        ),
        isNotEmpty,
      );
      
      expect(
        overrides.where(
          (override) => override.toString().contains('featureFlagsProvider'),
        ),
        isNotEmpty,
      );
    });
    
    test('createTestContainer should create container with test overrides', () {
      // Act
      final container = createTestContainer();
      
      // Assert - Check service providers return mock instances
      final apiService = container.read(apiServiceProvider);
      final encryptor = container.read(encryptorProvider);
      final protocolClient = container.read(protocolClientProvider);
      
      expect(apiService, isA<MockApiService>());
      expect(encryptor, isA<MockEncryptor>());
      expect(protocolClient, isA<MockProtocolClient>());
      
      // Check feature flags
      final featureFlags = container.read(featureFlagsProvider);
      
      expect(featureFlags['enableAnalytics'], isFalse);
      expect(featureFlags['enableCloudSync'], isFalse);
      expect(featureFlags['enableDevMode'], isTrue);
      expect(featureFlags['enableBetaFeatures'], isTrue);
    });
    
    test('test container services should be mocked correctly', () {
      // Arrange
      final container = createTestContainer();
      final mockApiService = container.read(apiServiceProvider) as MockApiService;
      
      when(mockApiService.get(endpoint: 'test')).thenAnswer(
        (_) async => const Right({'success': true})
      );
      
      // Act
      mockApiService.get(endpoint: 'test');
      
      // Assert
      verify(mockApiService.get(endpoint: 'test')).called(1);
    });
  });
}
