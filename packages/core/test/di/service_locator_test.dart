import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:core/core.dart';

void main() {
  group('ServiceLocator Tests', () {
    setUp(() {
      // Reset the service locator before each test
      ServiceLocator.instance.reset();
    });

    test('Should initialize successfully', () async {
      // Act
      await ServiceLocator.initialize();
      
      // Assert
      expect(ServiceLocator.instance, isNotNull);
    });

    test('Should return the same instance for singleton services', () {
      // Arrange
      final serviceLocator = ServiceLocator.instance;
      
      // Act
      final apiService1 = serviceLocator.apiService;
      final apiService2 = serviceLocator.apiService;
      
      final encryptor1 = serviceLocator.encryptor;
      final encryptor2 = serviceLocator.encryptor;
      
      final protocolClient1 = serviceLocator.protocolClient;
      final protocolClient2 = serviceLocator.protocolClient;
      
      // Assert
      expect(apiService1, equals(apiService2));
      expect(encryptor1, equals(encryptor2));
      expect(protocolClient1, equals(protocolClient2));
    });

    test('Should create new instances after reset', () {
      // Arrange
      final serviceLocator = ServiceLocator.instance;
      final apiServiceBefore = serviceLocator.apiService;
      final encryptorBefore = serviceLocator.encryptor;
      final protocolClientBefore = serviceLocator.protocolClient;
      
      // Act
      serviceLocator.reset();
      final apiServiceAfter = serviceLocator.apiService;
      final encryptorAfter = serviceLocator.encryptor;
      final protocolClientAfter = serviceLocator.protocolClient;
      
      // Assert
      expect(apiServiceBefore, isNot(equals(apiServiceAfter)));
      expect(encryptorBefore, isNot(equals(encryptorAfter)));
      expect(protocolClientBefore, isNot(equals(protocolClientAfter)));
    });
  });

  group('Provider Tests', () {
    late ProviderContainer container;
    
    setUp(() {
      // Reset service locator
      ServiceLocator.instance.reset();
      
      // Create a fresh provider container for each test
      container = ProviderContainer();
    });
    
    tearDown(() {
      // Dispose the container after each test
      container.dispose();
    });
    
    test('serviceLocatorProvider should return the ServiceLocator instance', () {
      // Act
      final serviceLocator = container.read(serviceLocatorProvider);
      
      // Assert
      expect(serviceLocator, equals(ServiceLocator.instance));
    });
    
    test('Service providers should return the correct service instances', () {
      // Arrange
      final serviceLocator = ServiceLocator.instance;
      
      // Act
      final apiService = container.read(apiServiceProvider);
      final encryptor = container.read(encryptorProvider);
      final protocolClient = container.read(protocolClientProvider);
      
      // Assert
      expect(apiService, equals(serviceLocator.apiService));
      expect(encryptor, equals(serviceLocator.encryptor));
      expect(protocolClient, equals(serviceLocator.protocolClient));
    });
  });
}
